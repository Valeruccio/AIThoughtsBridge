#!/usr/bin/env python3
"""
Bridge for Project Zomboid mod «AI Thoughts» (character-first).

B42: prefers .txt bridge files (JSON body) for getFileWriter compatibility.
Watches:  <Zomboid>/Lua/DeepSeekThoughts/outbox/request.txt  (fallback request.json)
Writes:   <Zomboid>/Lua/DeepSeekThoughts/inbox/response.txt

Run while the game is open:
    .venv\\Scripts\\python.exe bridge\\deepseek_bridge.py
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import traceback
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

from llm_config import env_legacy_defaults, placeholder_key, resolve_llm
from dialogue_parse import parse_dialogue_payload
from diagnostics import print_llm_prompt_dump, print_request_diagnostics
from filters import (
    TOPIC_CLUSTERS,
    enforce_word_limit,
    hits_cluster,
    looks_like_meta_thought,
    thought_reject_reasons,
)

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")

# Windows consoles (cp1251) choke on arrows/emoji in print()
def _safe_stdout() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        except Exception:
            pass


_safe_stdout()


def safe_print(*args, **kwargs) -> None:
    try:
        print(*args, **kwargs)
    except UnicodeEncodeError:
        text = " ".join(str(a) for a in args)
        enc = getattr(sys.stdout, "encoding", None) or "utf-8"
        print(text.encode(enc, errors="replace").decode(enc, errors="replace"), **kwargs)

_ENV_KEY, _ENV_MODEL, _ENV_BASE = env_legacy_defaults()
# Legacy module-level names kept for any external refs / logs
API_KEY = _ENV_KEY
MODEL = _ENV_MODEL
BASE_URL = _ENV_BASE

ZOMBOID_USER = Path(os.getenv("ZOMBOID_USER_DIR") or (Path.home() / "Zomboid"))
IO_ROOT = ZOMBOID_USER / "Lua" / "DeepSeekThoughts"
# B42 primary (.txt); legacy .json kept as fallback for one release
OUTBOX = IO_ROOT / "outbox" / "request.txt"
OUTBOX_LEGACY = IO_ROOT / "outbox" / "request.json"
INBOX = IO_ROOT / "inbox" / "response.txt"
STATUS = IO_ROOT / "status.txt"
SETTINGS_TXT = IO_ROOT / "settings.txt"

RECENT_PATH = IO_ROOT / "recent_thoughts.txt"
RECENT_MAX = 12
POLL_SEC = 0.75
# request_id last-seen per IO root path
LAST_REQUEST_IDS: dict[str, str] = {}

VOICE_BANK_PATH = ROOT / "voice_banks" / "monologues.json"
CITATY_BANK_PATH = ROOT / "voice_banks" / "citaty_monologues.json"
COMBAT_BANK_PATH = ROOT / "voice_banks" / "combat_monologues.json"
VEHICLE_BANK_PATH = ROOT / "voice_banks" / "vehicle_monologues.json"
_VOICE_BANK_CACHE: list[dict] | None = None
_COMBAT_BANK_CACHE: list[dict] | None = None
_VEHICLE_BANK_CACHE: list[dict] | None = None
_VOICE_RECENT_IDS: list[str] = []

LANG_NAMES = {
    "en": "English",
    "ru": "Russian",
}

# Thin fallback only if Lua forgot prompts.world_main
FALLBACK_SYSTEM_PROMPT = """You are the INNER VOICE of a survivor in Knox County (Project Zomboid).
Goal: Generate ONE raw, first-person inner thought in the target language.
OUTPUT: thought text only — no quotes, meta, or thinking process.
PACING: Calm = 1 finished sentence (10–20 words); Panic = 2–7 broken fragments.
Respect gender grammar. No meta-game labels, lists, or mid-sentence cuts."""

FALLBACK_DIALOGUE_SYSTEM = """You speak ALOUD as one Knox Event survivor near other survivors.
ONE short spoken line. Output a single JSON object only.
Character first; mood/wounds/gender color the line — never force a template."""


def _load_bank_file(path: Path, label: str) -> list[dict]:
    if not path.exists():
        print(f"[bridge] {label} bank missing: {path}")
        return []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        items = list(raw.get("monologues") or [])
        print(f"[bridge] {label} bank loaded: {len(items)} monologues")
        return items
    except (OSError, json.JSONDecodeError) as e:
        print(f"[bridge] {label} bank load failed: {e}")
        return []


def load_voice_bank() -> list[dict]:
    """Calm/human bank = base monologues + curated citaty scraps."""
    global _VOICE_BANK_CACHE
    if _VOICE_BANK_CACHE is not None:
        return _VOICE_BANK_CACHE
    base = _load_bank_file(VOICE_BANK_PATH, "voice")
    citaty = _load_bank_file(CITATY_BANK_PATH, "citaty")
    _VOICE_BANK_CACHE = list(base) + list(citaty)
    if citaty:
        print(f"[bridge] voice+citaty total: {len(_VOICE_BANK_CACHE)}")
    return _VOICE_BANK_CACHE


def load_combat_bank() -> list[dict]:
    global _COMBAT_BANK_CACHE
    if _COMBAT_BANK_CACHE is not None:
        return _COMBAT_BANK_CACHE
    _COMBAT_BANK_CACHE = _load_bank_file(COMBAT_BANK_PATH, "combat")
    return _COMBAT_BANK_CACHE


def load_vehicle_bank() -> list[dict]:
    global _VEHICLE_BANK_CACHE
    if _VEHICLE_BANK_CACHE is not None:
        return _VEHICLE_BANK_CACHE
    _VEHICLE_BANK_CACHE = _load_bank_file(VEHICLE_BANK_PATH, "vehicle")
    return _VEHICLE_BANK_CACHE


def _hook_ids(data: dict) -> set[str]:
    return {str(h.get("id")) for h in (data.get("prompt_hooks") or [])}


def _want_combat_bank(hook_ids: set[str], tier: str) -> bool:
    if any(
        h.startswith("zeds_") or h in ("in_combat", "took_damage", "gunshot_echo", "landed_hit_melee")
        for h in hook_ids
    ):
        return True
    return tier in ("scared", "panic", "death")


def _in_vehicle(data: dict) -> bool:
    sit = data.get("situation") or {}
    veh = sit.get("vehicle") or {}
    comfort = sit.get("comfort") or {}
    return bool(veh.get("in_vehicle") or comfort.get("in_vehicle"))


def _want_vehicle_bank(hook_ids: set[str], data: dict) -> bool:
    """Vehicle voice only when actually in/working a car — not bare vehicle_alarm."""
    if _in_vehicle(data):
        return True
    # veh_* hooks (crash, driving, repair…) — exclude alarm ids
    if any(h.startswith("veh_") for h in hook_ids):
        return True
    return False


# Plain-English Focus lines (no [id:…] / ¶ / tech jargon)
FOCUS_PLAIN: dict[str, str] = {
    "vehicle_alarm": (
        "A car alarm / siren is screaming nearby, pulling every corpse toward the noise."
    ),
    "house_alarm": "A building alarm is howling nearby — a stupid loud beacon.",
    "zeds_chasing": (
        "A zombie is locked onto you from out of sight — chase pressure, not a crowd report."
    ),
    "zeds_close": "Dead are close — body/threat reaction, not a headcount.",
    "zeds_visible_crowd": "Too many dead in sight — pressure, not a tally.",
    "in_combat": "In a fight right now — hate/fear/body scrap.",
    "gunshot_echo": "A shot still ringing — shock or swagger, not a report.",
    "landed_hit_melee": "Just landed a hit — brief hate/relief scrap.",
    "bleed_worse": "Bleeding worse — body complaint, urgency.",
    "sick_feverish": "Feverish — heat, chills, heavy limbs.",
    "sick_queasy": "Queasy — stomach and head wrong.",
    "infection_knox": "Infection dread from a wound — suspicion only, no Knox name.",
    "illness_dread": "Illness dread creeping in.",
    "media_react": "React to what the radio/TV just said.",
    "media_watching": "Still near a broadcast — react to the line, not narrate watching.",
    "mind_wander": "Mind wandering — memory, joke, or small desire.",
    "desire_drink": "Want something cold to drink or a short rest.",
    "veh_crash": "Vehicle impact — metal scream, body jolt.",
    "veh_stalled": "Engine died mid-move — curse or hope at the key.",
    "veh_wont_start": "Car won't turn over.",
    "veh_engine_start": "Engine caught — relief or flinch at the roar.",
    "veh_entered": "Just got inside a vehicle cabin.",
    "veh_repair_fiddle": "Hands in a car's guts — wrench mood.",
    "veh_driving": "Behind the wheel — road and speed feel.",
    "no_weapon_threat": "Empty hands while threat is near.",
}

_PART_EN = {
    "left_hand": "left hand",
    "right_hand": "right hand",
    "hand": "hand",
    "left_forearm": "left forearm",
    "right_forearm": "right forearm",
    "left_upper_arm": "left upper arm",
    "right_upper_arm": "right upper arm",
    "chest": "chest",
    "abdomen": "abdomen",
    "neck": "neck",
    "head": "head",
    "groin": "groin",
    "left_thigh": "left thigh",
    "right_thigh": "right thigh",
    "left_shin": "left shin",
    "right_shin": "right shin",
    "left_foot": "left foot",
    "right_foot": "right foot",
}

_PAIN_HOOK_IDS = {
    "moodle_pain",
    "moodle_injury",
    "moodle_bleeding",
    "wound_scratch",
    "wound_cut",
    "wound_bite",
    "wound_deep",
    "wound_fracture",
    "took_damage",
    "bleed_worse",
}


def _sanitize_micro(text: str, *, clip_clause: bool = False) -> str:
    s = str(text or "").strip()
    for ch in ("¶", "↔", "∟", "«", "»"):
        s = s.replace(ch, " ")
    s = s.replace("—", "-").replace("–", "-").replace("…", "...")
    s = " ".join(s.split())
    if clip_clause and " - " in s:
        s = s.split(" - ", 1)[0].strip()
    if len(s) > 140:
        s = s[:137].rstrip() + "..."
    return s


def _body_blob(data: dict) -> dict:
    return ((data.get("situation") or {}).get("body")) or {}


def _primary_wound(data: dict) -> dict | None:
    body = _body_blob(data)
    primary = body.get("primary")
    if isinstance(primary, dict) and primary.get("kind") and primary.get("part"):
        return primary
    parts = body.get("parts") or []
    if isinstance(parts, list) and parts:
        p0 = parts[0]
        if isinstance(p0, dict) and p0.get("kind"):
            return p0
    for d in data.get("digest") or []:
        s = str(d)
        if s.startswith("wound="):
            token = s.split("=", 1)[1].strip()
            kinds = ("bite", "scratch", "cut", "deep", "fracture", "burn")
            for k in kinds:
                if token.startswith(k + "_"):
                    return {
                        "kind": k,
                        "part": token[len(k) + 1 :],
                        "bleeding": False,
                        "zombie_bite": k == "bite",
                    }
    return None


def _wound_severity(data: dict) -> str:
    body = _body_blob(data)
    sev = str(body.get("severity") or "").lower()
    if sev in ("minor", "moderate", "severe"):
        return sev
    for d in data.get("digest") or []:
        s = str(d)
        if s.startswith("wound_severity="):
            v = s.split("=", 1)[1].strip().lower()
            if v in ("minor", "moderate", "severe"):
                return v
    w = _primary_wound(data)
    if not w:
        if int(body.get("bites") or 0) > 0 or int(body.get("deep") or 0) > 0:
            return "severe"
        if int(body.get("scratches") or 0) > 0 or int(body.get("cuts") or 0) > 0:
            return "minor"
        return "none"
    kind = str(w.get("kind") or "")
    if kind in ("bite", "deep", "fracture"):
        return "severe"
    if kind == "scratch":
        return "minor"
    if kind in ("cut", "burn") or w.get("bleeding"):
        return "moderate"
    return "minor"


def _part_en(part: str) -> str:
    p = str(part or "body").lower()
    if p in _PART_EN:
        return _PART_EN[p]
    return p.replace("_", " ")


def wound_fact_lines(data: dict) -> list[str]:
    """Strict grounding lines for Fact Card — only attested locations."""
    w = _primary_wound(data)
    sev = _wound_severity(data)
    hooks = _hook_ids(data)
    if not w and sev == "none" and not (hooks & _PAIN_HOOK_IDS):
        return []
    lines: list[str] = []
    if w:
        kind = str(w.get("kind") or "wound")
        part = _part_en(str(w.get("part") or "body"))
        bleeding = bool(w.get("bleeding"))
        zombie_bite = bool(w.get("zombie_bite") or kind == "bite")
        if kind == "scratch":
            lines.append(f"Minor scratch on the {part} (light pain, not lethal).")
            lines.append(
                "NO deep wounds, NO internal pain, NO broken bones, "
                "NO pain in the side/ribs/chest unless listed here."
            )
            if not zombie_bite:
                lines.append("Not a zombie bite — do not invent a zed causing this scratch.")
        elif kind == "cut":
            lines.append(
                f"Cut/laceration on the {part}"
                + (" (bleeding)." if bleeding else " (stinging).")
            )
            lines.append("NO invented broken bones or internal injuries.")
        elif kind == "bite":
            lines.append(
                f"Bite wound on the {part}"
                + (" (bleeding, critical)." if bleeding else " (infection dread).")
            )
        elif kind == "deep":
            lines.append(
                f"Deep wound on the {part}" + (" (bleeding)." if bleeding else ".")
            )
        elif kind == "fracture":
            lines.append(f"Possible fracture / bone pain in the {part}.")
        elif kind == "burn":
            lines.append(f"Burn on the {part}.")
        else:
            lines.append(f"Injury on the {part} ({kind}).")
    elif hooks & _PAIN_HOOK_IDS or sev != "none":
        body = _body_blob(data)
        if int(body.get("scratches") or 0) > 0 or sev == "minor":
            lines.append("Minor scratch somewhere on the body (light sting).")
            lines.append(
                "NO deep wounds, NO internal pain, NO broken bones, "
                "NO pain in the side/ribs."
            )
        else:
            lines.append("General minor body pain / sting.")
            lines.append(
                "Do NOT invent a specific body part (side, ribs, chest, knee) unless listed."
            )
    return lines


def wound_focus_line(data: dict, hook_id: str = "") -> str:
    """Severity-aware Focus — no dying drama for minor scratches."""
    w = _primary_wound(data)
    sev = _wound_severity(data)
    hid = str(hook_id or "")
    if w:
        kind = str(w.get("kind") or "")
        part = _part_en(str(w.get("part") or "body"))
        if kind == "scratch" or sev == "minor":
            return (
                f"Sting of a minor scratch on the {part} — annoying distraction, keep focus. "
                "Not dying drama."
            )
        if kind == "bite":
            return f"Bite on the {part} — dread and urge to clean, not Knox by name."
        if kind == "cut":
            return f"Cut on the {part} stings — brief bitching, stay sharp."
        if kind in ("deep", "fracture"):
            return f"Serious {kind} on the {part} — real pain; finish the scrap cleanly."
    if hid == "moodle_bleeding" or hid == "bleed_worse":
        return "Bleeding nags — sticky wrongness, urgency without a medical lecture."
    if hid == "took_damage":
        return (
            "Just took a hit — one flinch/curse. "
            "Only name a body part if Fact Card lists it."
        )
    if sev in ("none", "minor") or hid in ("moodle_pain", "moodle_injury", "wound_scratch"):
        return "Sting of a minor wound — annoying distraction, keep focus. Not dying drama."
    return "Body complaint — brief, grounded in Fact Card only."


def reaction_level_line(data: dict) -> str | None:
    sev = _wound_severity(data)
    hooks = _hook_ids(data)
    if not (hooks & _PAIN_HOOK_IDS) and sev == "none":
        return None
    w = _primary_wound(data)
    if sev in ("none", "minor") or (w and str(w.get("kind")) == "scratch"):
        return (
            "Reaction level: Annoyance / minor sting. Do NOT act like dying. "
            "No side/ribs/chest/internal pain inventions."
        )
    if sev == "moderate":
        return "Reaction level: Real hurt, still functional — no melodrama death speech."
    return "Reaction level: Serious wound dread OK — still no invented extra injuries."


def humanize_focus(hook: dict | None, data: dict | None = None) -> str:
    """One plain English focus sentence — no [id: micro] brackets."""
    if not hook:
        return FOCUS_PLAIN["mind_wander"]
    hid = str(hook.get("id") or "").strip()
    data = data or {}
    if hid in _PAIN_HOOK_IDS:
        return wound_focus_line(data, hid)
    if hid in FOCUS_PLAIN:
        return FOCUS_PLAIN[hid]
    micro = _sanitize_micro(hook.get("micro") or hid or "mind wandering", clip_clause=True)
    if micro:
        return micro
    return FOCUS_PLAIN["mind_wander"]


def format_focus_line(hooks: list, data: dict | None = None) -> str:
    if not hooks:
        return FOCUS_PLAIN["mind_wander"]
    parts = [humanize_focus(h, data) for h in hooks[:2]]
    uniq: list[str] = []
    for p in parts:
        if p and p not in uniq:
            uniq.append(p)
    return "; ".join(uniq)


def _zed_counts(data: dict) -> tuple[int, int, int]:
    sit = data.get("situation") or {}
    z = sit.get("zombies") or {}
    digest = data.get("digest") or []

    def as_int(v, default=0) -> int:
        try:
            return int(v or 0)
        except (TypeError, ValueError):
            return default

    visible = as_int(z.get("visible"))
    chasing = as_int(z.get("chasing"))
    close = as_int(z.get("close"))
    # Fallback parse digest "zeds visible=N chasing=M close=K"
    for d in digest:
        s = str(d)
        if s.startswith("zeds ") or "chasing=" in s:
            m = re.search(
                r"visible\s*=\s*(\d+).*?chasing\s*=\s*(\d+).*?close\s*=\s*(\d+)",
                s,
            )
            if m:
                visible, chasing, close = int(m.group(1)), int(m.group(2)), int(m.group(3))
            break
    return visible, chasing, close


def build_fact_card_lines(data: dict, digest: list, tier: str, emo: str, hook_ids: set[str]) -> list[str]:
    """Human hard-limits; replace raw zeds= counts with plain facts."""
    facts: list[str] = []
    for d in digest:
        ds = str(d)
        if ds.startswith("temp="):
            continue
        if ds.startswith("zeds ") or ("chasing=" in ds and "visible=" in ds):
            continue  # replaced below
        if ds.startswith("wet_cause=") or ds in ("dirty_clothes", "bloody_clothes"):
            continue  # replaced by hygiene fact
        if ds.startswith("wound=") or ds.startswith("wound_severity=") or ds.startswith("scratches=") \
                or ds.startswith("cuts=") or ds.startswith("bites=") or ds.startswith("deep_wounds=") \
                or ds.startswith("fractures=") or ds.startswith("bleed_parts="):
            continue  # replaced by wound_fact_lines
        if (tier == "calm" or emo in ("dwell", "wander")) and (
            ds.startswith("outfit=")
            or ds.startswith("has_food=")
            or ds.startswith("has_water=")
            or ds.startswith("has_weapon=")
        ):
            continue
        facts.append(ds)

    if "vehicle_alarm" in hook_ids:
        facts.insert(0, "Loud car alarm / siren blaring nearby.")
    elif "house_alarm" in hook_ids:
        facts.insert(0, "Loud building alarm howling nearby.")

    visible, chasing, close = _zed_counts(data)
    if chasing >= 1 and visible <= 0:
        facts.append("A monster is chasing from out of sight (not visible yet).")
    elif chasing >= 1:
        facts.append(f"A monster is chasing (visible≈{visible}, close≈{close}).")
    elif close >= 1:
        facts.append("Dead are close.")
    elif visible >= 1:
        facts.append(f"Dead visible nearby ({visible}).")

    if _in_vehicle(data):
        facts.append("Survivor is inside a vehicle.")
    else:
        facts.append("Survivor is alone and on foot.")

    # Wound grounding (location-strict)
    for wf in wound_fact_lines(data):
        facts.append(wf)

    hygiene = _hygiene_state(data)
    if hygiene == "bloody":
        facts.append("Clothes/body stained with blood and dirt.")
    elif hygiene == "dirty":
        facts.append("Covered in dirt/sweat.")
    else:
        facts.append("Body and clothes are clean and dry.")

    # Deduplicate while preserving order
    out: list[str] = []
    seen: set[str] = set()
    for f in facts:
        key = f.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(f)
    return out[:12]


def sample_monologues(data: dict, n: int = 5) -> list[dict]:
    """Pick diverse bank lines for this request; adapt, never copy."""
    import random

    hook_ids = _hook_ids(data)
    ch = data.get("character") or {}
    affect = data.get("affect") or {}
    tier = (affect.get("tier") or "calm").lower()
    female = bool(ch.get("female"))
    gender = "female" if female else "male"
    profession = (ch.get("profession") or "").lower()
    traits = [str(t) for t in (ch.get("traits") or [])]
    trait_set = {t.lower() for t in traits}
    moodles = ((data.get("situation") or {}).get("moodles")) or {}
    unhappy_lvl = resolve_unhappy_level(data)
    # Soft-dark bank opens earlier when unhappiness is the voice lens
    allow_soft = (
        tier in ("death", "panic")
        or unhappy_lvl >= 2
        or "moodle_unhappy" in hook_ids
    )

    bank: list[dict] = []
    # Primary pool by situation
    if _want_combat_bank(hook_ids, tier):
        bank.extend(load_combat_bank())
    if _want_vehicle_bank(hook_ids, data):
        bank.extend(load_vehicle_bank())
    # Always include calm human bank as filler / calm path
    bank.extend(load_voice_bank())
    if not bank:
        return []

    want_tiers = {tier, "calm"}
    if _want_combat_bank(hook_ids, tier):
        want_tiers.update({"combat", "scared", "panic", "death", "uneasy"})
    if _want_vehicle_bank(hook_ids, data):
        want_tiers.update({"calm", "uneasy", "scared", "panic"})
    if "media_react" in hook_ids:
        want_tiers.add("media")
    if tier in ("scared", "panic", "death"):
        want_tiers.update({"scared", "panic", "death", "combat"})

    scored: list[tuple[float, dict]] = []
    recent_set = set(_VOICE_RECENT_IDS[-24:])
    for e in bank:
        if e.get("soft_dark") and not allow_soft:
            continue
        g = (e.get("gender") or "any").lower()
        if g not in ("any", gender):
            continue
        etiers = [str(t).lower() for t in (e.get("tiers") or ["calm"])]
        if not (set(etiers) & want_tiers):
            continue
        tags = {str(t).lower() for t in (e.get("tags") or [])}
        # Never leak car/engine scraps when not in a vehicle context
        if "vehicle" in tags and not _want_vehicle_bank(hook_ids, data):
            continue
        score = 1.0
        if tier in etiers:
            score += 2.0
        if "media" in etiers and "media_react" in hook_ids:
            score += 3.0
        if "combat" in etiers and any(
            x in hook_ids for x in ("zeds_chasing", "zeds_close", "in_combat", "took_damage")
        ):
            score += 2.5
        if "vehicle" in tags and _want_vehicle_bank(hook_ids, data):
            score += 2.5
        if any(h.startswith("veh_") for h in hook_ids) and "vehicle" in tags:
            score += 1.5
        bias = [str(p).lower() for p in (e.get("prof_bias") or [])]
        if profession and profession in bias:
            score += 1.5
        trait_bias = [str(t).lower() for t in (e.get("trait_bias") or [])]
        if trait_bias and any(t in trait_set for t in trait_bias):
            score += 2.0
        if e.get("id") in recent_set:
            score -= 5.0
        score += random.random() * 0.8
        scored.append((score, e))

    scored.sort(key=lambda x: x[0], reverse=True)
    picked: list[dict] = []
    seen_tags: set[str] = set()
    for _sc, e in scored:
        tags = set(str(t) for t in (e.get("tags") or []))
        if tags and tags <= seen_tags and len(picked) >= 2:
            continue
        picked.append(e)
        seen_tags |= tags
        if len(picked) >= n:
            break
    if len(picked) < n:
        for _sc, e in scored:
            if e in picked:
                continue
            picked.append(e)
            if len(picked) >= n:
                break

    for e in picked:
        eid = str(e.get("id") or "")
        if eid:
            _VOICE_RECENT_IDS.append(eid)
    del _VOICE_RECENT_IDS[:-40]
    return picked


def format_voice_bank_block(data: dict, lang: str) -> list[str]:
    tier = ((data.get("affect") or {}).get("tier") or "calm").lower()
    n = 1 if tier in ("scared", "panic", "death") else 2
    samples = sample_monologues(data, n=n)
    if not samples:
        return []
    hook_ids = _hook_ids(data)
    lines = ["", "VOICE (adapt tone, do not copy):"]
    for e in samples:
        text = (e.get(lang) or e.get("ru") or e.get("en") or "").strip()
        if not text:
            continue
        lines.append(f"- {text}")
    if _want_combat_bank(hook_ids, tier):
        # Chase nudge only when chase/combat is actually in focus — not mere scared+scratch
        if any(
            h.startswith("zeds_") or h in ("in_combat", "took_damage", "gunshot_echo", "landed_hit_melee")
            for h in hook_ids
        ):
            lines.append("CHASE: new angle (smell/face/stumble/hate) — never open with «Бегут».")
    if _want_vehicle_bank(hook_ids, data):
        lines.append("VEHICLE: car/road/engine tone OK if relevant.")
    return lines


def resolve_system_prompt(data: dict) -> str:
    """Universe framing from Lua prompts.world_main (thought or dialogue)."""
    prompts = data.get("prompts") or {}
    world = (prompts.get("world_main") or "").strip()
    kind = str(data.get("kind") or "thought").lower()
    if kind == "dialogue":
        base = world if world else FALLBACK_DIALOGUE_SYSTEM
        return (
            base
            + "\n\nCRITICAL OUTPUT RULE: Output ONLY one JSON object, no markdown fences, no preamble.\n"
            'Schema: {"text":"<spoken line>","address_mode":"void|all|named",'
            '"address_to":"<name or empty>","should_end":true|false}\n'
            "text = the spoken words only (no speaker name prefix). "
            "Never write Thinking Process, plans, or meta."
        )
    base = world if world else FALLBACK_SYSTEM_PROMPT
    return base + "\n\nCRITICAL OUTPUT RULE: Output ONLY the thought text. No preamble, no meta."


def load_recent_thoughts() -> list[str]:
    if not RECENT_PATH.exists():
        return []
    try:
        lines = [
            ln.strip()
            for ln in RECENT_PATH.read_text(encoding="utf-8", errors="ignore").splitlines()
        ]
        return [ln for ln in lines if ln][-RECENT_MAX:]
    except OSError:
        return []


def save_recent_thought(text: str) -> None:
    recent = load_recent_thoughts()
    recent.append(text.replace("\n", " ").strip())
    recent = recent[-RECENT_MAX:]
    try:
        ensure_dirs()
        RECENT_PATH.write_text("\n".join(recent) + "\n", encoding="utf-8")
    except OSError:
        pass


def load_game_settings() -> dict:
    out: dict[str, str] = {}
    if not SETTINGS_TXT.exists():
        return out
    try:
        for line in SETTINGS_TXT.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            key = k.strip()
            if key == "api_key":
                # Secrets belong in bridge_config.json / .env only
                continue
            out[key] = v.strip()
    except OSError:
        pass
    return out


def resolve_api_key() -> str:
    """Legacy helper — prefer resolve_llm() for full endpoint."""
    llm = current_llm()
    return llm.get("api_key") or ""


def current_llm() -> dict:
    return resolve_llm(
        env_api_key=API_KEY,
        env_model=MODEL,
        env_base_url=BASE_URL,
        game_api_key="",  # never read API keys from game settings
    )


def swear_instruction(level: str, lang: str) -> str:
    level = (level or "light").lower()
    lang = (lang or "en").lower()
    if lang == "ru":
        palette = "Russian curses when fitting (чёрт / блин / one блядь max for light)."
    else:
        palette = "English curses when fitting (damn / shit / one fuck max for light)."

    if level == "none":
        return "SWEARING: none."
    if level == "light":
        return f"SWEARING: light. At most one mild curse if it fits. {palette} Often clean."
    if level == "heavy":
        return f"SWEARING: heavy OK when irritated — still natural. {palette}"
    return f"SWEARING: medium. One strong curse OK if mood fits. {palette}"


def ensure_dirs(root: Path | None = None) -> None:
    base = root or IO_ROOT
    (base / "outbox").mkdir(parents=True, exist_ok=True)
    (base / "inbox").mkdir(parents=True, exist_ok=True)


def sanitize_json_text(raw: str) -> str:
    out = []
    for ch in raw:
        o = ord(ch)
        if o < 32 and ch not in "\t\n\r":
            continue
        out.append(ch)
    return "".join(out)


def write_status(state: str, detail: str = "", root: Path | None = None) -> None:
    base = root or IO_ROOT
    ensure_dirs(base)
    status_path = base / "status.txt"
    try:
        llm = current_llm()
        model_name = llm.get("model") or MODEL
        provider = llm.get("provider") or ""
    except Exception:
        model_name = MODEL
        provider = ""
    payload = {
        "state": state,
        "detail": detail,
        "provider": provider,
        "model": model_name,
        "ts": int(time.time()),
    }
    raw = json.dumps(payload, ensure_ascii=False, indent=2)
    tmp = status_path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as f:
        f.write(raw)
        f.flush()
        os.fsync(f.fileno())
    tmp.replace(status_path)
    # Legacy mirror for older Lua once
    try:
        legacy = base / "status.json"
        legacy.write_text(raw, encoding="utf-8")
    except OSError:
        pass


def write_response(
    request_id: str,
    thought: str | None,
    error: str | None = None,
    root: Path | None = None,
    *,
    kind: str = "thought",
    address_mode: str | None = None,
    address_to: str | None = None,
    should_end: bool | None = None,
) -> None:
    base = root or IO_ROOT
    ensure_dirs(base)
    inbox = base / "inbox" / "response.txt"
    payload: dict = {
        "request_id": request_id,
        "thought": thought or "",
        "error": error,
        "kind": kind or "thought",
    }
    if address_mode is not None:
        payload["address_mode"] = address_mode
    if address_to is not None:
        payload["address_to"] = address_to
    if should_end is not None:
        payload["should_end"] = bool(should_end)
    raw = json.dumps(payload, ensure_ascii=False)
    tmp = inbox.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8", newline="\n") as f:
        f.write(raw)
        f.flush()
        os.fsync(f.fileno())
    tmp.replace(inbox)
    try:
        (base / "inbox" / "response.json").write_text(raw, encoding="utf-8")
    except OSError:
        pass


def iter_io_roots() -> list[Path]:
    """Legacy flat root + per-player subfolders (Mode A client-local / split-screen)."""
    roots: list[Path] = []
    ensure_dirs(IO_ROOT)
    roots.append(IO_ROOT)
    try:
        if IO_ROOT.exists():
            for child in IO_ROOT.iterdir():
                if not child.is_dir():
                    continue
                if child.name in ("outbox", "inbox", "voice_banks"):
                    continue
                if (child / "outbox").is_dir() or (child / "outbox" / "request.txt").exists() or (child / "outbox" / "request.json").exists():
                    ensure_dirs(child)
                    roots.append(child)
    except OSError:
        pass
    return roots


def resolve_mood_level(data: dict, aff_key: str, moodle_key: str, vital_keys: tuple[str, ...]) -> int:
    """0–4 moodle-ish level from affect → moodle → vitals."""
    aff = data.get("affect") or {}
    sit = data.get("situation") or {}
    m = sit.get("moodles") or {}
    v = sit.get("vitals") or {}
    lvl = aff.get(aff_key)
    if lvl is None:
        lvl = m.get(moodle_key)
    try:
        n = int(lvl or 0)
    except (TypeError, ValueError):
        n = 0
    if n <= 0:
        x = 0.0
        for key in vital_keys:
            raw = v.get(key)
            try:
                x = float(raw or 0)
            except (TypeError, ValueError):
                continue
            if x > 0:
                break
        if x > 1.5:
            x = x / 100.0
        if x >= 0.75:
            n = 4
        elif x >= 0.55:
            n = 3
        elif x >= 0.35:
            n = 2
        elif x >= 0.15:
            n = 1
        else:
            n = 0
    return max(0, min(4, n))


def resolve_unhappy_level(data: dict) -> int:
    """0–4 moodle-ish unhappiness for voice coloring on every thought."""
    return resolve_mood_level(data, "unhappy_level", "unhappy", ("unhappy",))


def resolve_drunk_level(data: dict) -> int:
    """0–4 drunkenness for voice coloring on every thought."""
    return resolve_mood_level(
        data, "drunk_level", "drunk", ("drunkenness", "drunk", "intoxication")
    )


def _trait_blob(ch: dict) -> str:
    return " ".join(str(t).lower() for t in (ch.get("traits") or []))


def _has_trait(blob: str, *names: str) -> bool:
    cleaned = blob.replace("_", "")
    return any(n.lower().replace("_", "") in cleaned for n in names)


def _parse_temp_from_data(data: dict) -> float | None:
    sit = data.get("situation") or {}
    w = sit.get("weather") or {}
    if w.get("temp") is not None:
        try:
            return float(w.get("temp"))
        except (TypeError, ValueError):
            pass
    for d in data.get("digest") or []:
        s = str(d)
        if s.startswith("temp="):
            try:
                return float(s.split("=", 1)[1])
            except (TypeError, ValueError):
                return None
    return None


def _hygiene_state(data: dict) -> str:
    """clean | dirty | bloody — from comfort flags / wet_cause / digest."""
    sit = data.get("situation") or {}
    comfort = sit.get("comfort") or {}
    vitals = sit.get("vitals") or {}
    moodles = sit.get("moodles") or {}
    digest = [str(d) for d in (data.get("digest") or [])]

    dirty = bool(comfort.get("dirty_clothes"))
    bloody = bool(comfort.get("bloody_clothes"))
    wet_cause = str(comfort.get("wet_cause") or "none").lower()

    if "dirty_clothes" in digest:
        dirty = True
    if "bloody_clothes" in digest:
        bloody = True
    for d in digest:
        if d.startswith("wet_cause="):
            wet_cause = d.split("=", 1)[1].strip().lower() or wet_cause

    try:
        wetness = float(vitals.get("wetness") or 0)
    except (TypeError, ValueError):
        wetness = 0.0
    try:
        wet_moodle = int(moodles.get("wet") or 0)
    except (TypeError, ValueError):
        wet_moodle = 0

    if bloody:
        return "bloody"
    # Sweat / dirt on body or clothes
    if dirty or wet_cause == "sweat" or wet_moodle >= 1 or wetness > 10:
        return "dirty"
    return "clean"


def atmosphere_line(data: dict) -> str:
    """Human weather/time feel — no sweat wording when character is clean."""
    sit = data.get("situation") or {}
    w = sit.get("weather") or {}
    indoors = bool(sit.get("indoors"))
    place = "Indoors" if indoors else "Outdoors"
    pod = str(sit.get("part_of_day") or "").strip() or "?"
    parts: list[str] = [place, pod.capitalize() if pod != "?" else "?"]
    hygiene = _hygiene_state(data)
    clean = hygiene == "clean"
    nightish = pod in ("night", "evening", "dusk")

    temp = _parse_temp_from_data(data)
    if temp is not None:
        if temp >= 28:
            if clean:
                feel = "stuffy night air, burning thirst" if nightish else "stuffy air, burning thirst"
            else:
                feel = "stuffy, sticky sweat, burning thirst"
            parts.append(f"Very Hot {temp:.0f}C ({feel})")
        elif temp >= 22:
            if clean:
                feel = "stuffy night air" if nightish else "open air"
            else:
                feel = "heavy air, body sticky"
            parts.append(f"Warm {temp:.0f}C ({feel})")
        elif temp <= 5:
            parts.append(f"Very Cold {temp:.0f}C (shiver, numb fingers, breath-steam)")
        elif temp <= 12:
            parts.append(f"Cold {temp:.0f}C (chill on skin, stiff hands)")
        else:
            parts.append(f"Mild {temp:.0f}C")

    flags: list[str] = []
    digest = data.get("digest") or []
    if w.get("rain") or any(str(d) == "raining" for d in digest):
        flags.append("rain")
    if w.get("fog") or any(str(d) == "fog" for d in digest):
        flags.append("fog")
    if w.get("snow"):
        flags.append("snow")
    if flags:
        parts.append("+".join(flags))

    return "Atmosphere: " + ", ".join(parts)


def _mood_impulse_suffix(unhappy: int, drunk: int) -> str:
    bits: list[str] = []
    if unhappy >= 3:
        bits.append("heavy misery tints voice")
    elif unhappy >= 2:
        bits.append("flat grey mood")
    elif unhappy == 1:
        bits.append("slightly flat")
    if drunk >= 3:
        bits.append("drunk blur/bravado")
    elif drunk >= 2:
        bits.append("buzzed warmth")
    elif drunk == 1:
        bits.append("light buzz")
    return "; ".join(bits)


def dominant_impulse(data: dict) -> str:
    """One winning impulse — sex + trait/body/mood. No trait-ID dump."""
    ch = data.get("character") or {}
    affect = data.get("affect") or {}
    sit = data.get("situation") or {}
    m = sit.get("moodles") or {}
    body = sit.get("body") or {}
    tier = str(affect.get("tier") or "calm").lower()
    female = bool(ch.get("female"))
    sex = "Female" if female else "Male"
    blob = _trait_blob(ch)
    active = [str(t) for t in (ch.get("traits_active") or [])]
    prof_voice = (ch.get("profession_voice") or "").strip()
    prof_label = (ch.get("profession_label") or ch.get("profession") or "").strip()

    try:
        panic01 = float(affect.get("panic01") or 0)
    except (TypeError, ValueError):
        panic01 = 0.0
    threat = tier in ("scared", "panic", "death") or panic01 >= 0.55
    injured = int(m.get("injured") or 0) >= 1 or int(body.get("bites") or 0) > 0
    exhausted = int(m.get("tired") or 0) >= 2 or int(m.get("endurance") or 0) >= 2
    unhappy = resolve_unhappy_level(data)
    drunk = resolve_drunk_level(data)
    mood_bit = _mood_impulse_suffix(unhappy, drunk)

    def wrap(core: str) -> str:
        extra = f" | {mood_bit}" if mood_bit else ""
        return f"Dominant Impulse: {sex}, {core}{extra}."

    # 1) Hard constraints
    if _has_trait(blob, "deaf"):
        return wrap("Deaf — visual/vibration world only; never invent hearing")
    if _has_trait(blob, "illiterate") and any(
        x in " ".join(active).lower() for x in ("illiterate", "read", "book", "magazine")
    ):
        return wrap("Illiterate — never invent reading books/magazines")

    # 2) Threat + trait combos
    if threat and _has_trait(blob, "adrenalinejunkie"):
        return wrap("adrenaline junkie thriving on panic — wants to fight/run, highly reactive")
    if threat and _has_trait(blob, "desensitized"):
        return wrap("desensitized under threat — flat/dry underreact, not a scream")
    if threat and _has_trait(blob, "cowardly") and not _has_trait(blob, "desensitized"):
        return wrap("cowardly under threat — escape-first fear, body wants out")
    if threat and _has_trait(blob, "brave") and not _has_trait(blob, "desensitized"):
        return wrap("brave under threat — forward, downplays fear")
    if threat and _has_trait(blob, "pacifist"):
        return wrap("pacifist under violence — reluctant/guilty scraps")
    if threat and _has_trait(blob, "shorttemper"):
        return wrap("short temper under stress — snap/swear fuse short")
    if threat and _has_trait(blob, "brawler"):
        return wrap("brawler under threat — fight-first wording")
    if (not sit.get("indoors")) and _has_trait(blob, "agoraphobic"):
        return wrap("agoraphobic outdoors — open sky presses; wants walls/cover")
    if sit.get("indoors") and _has_trait(blob, "claustophobic", "claustrophobic"):
        return wrap("claustrophobic indoors — walls press; needs air/exits")

    # 3) Body fade
    if injured and exhausted:
        return wrap("injured and exhausted — body fading, complaint about limbs/breath")
    if injured and _has_trait(blob, "thinskinned", "hypercondriac"):
        return wrap("wounded and wound-anxious — pain and infection dread")
    if exhausted and tier in ("calm", "uneasy", "scared"):
        return wrap("exhausted body — heavy limbs, wants rest")

    # Always-on illiterate when no stronger impulse
    if _has_trait(blob, "illiterate"):
        return wrap("Illiterate survivor — never invent reading; habits through profession/mood")

    # 4) Top active trait tip
    if active:
        tip = active[0].replace("ACTIVE ", "").strip()
        if ":" in tip[:40]:
            tip = tip.split(":", 1)[1].strip()
        return wrap(tip[:140])

    # 5) Profession / mood fallback
    if prof_voice:
        return wrap(f"{prof_label or 'survivor'} perspective — {prof_voice[:100]}")
    if mood_bit:
        return wrap(f"ordinary survivor temper — {mood_bit}")
    if tier in ("panic", "death"):
        return wrap("raw fear/hate — breath and threat only")
    if tier == "scared":
        return wrap("scared — short hate/fear scraps")
    if tier == "uneasy":
        return wrap("uneasy — edged sarcasm or muttered curse")
    return wrap("calm wander — memory, joke, desire, or small regret")


def gender_lock_block(female: bool, lang: str) -> str:
    if female:
        if lang == "ru":
            return "GENDER LOCK: Female — Russian feminine forms only (я сделала / устала / сама)."
        return "GENDER LOCK: Female — self-image and body cues read as a woman."
    if lang == "ru":
        return "GENDER LOCK: Male — Russian masculine forms only (я сделал / устал / сам)."
    return "GENDER LOCK: Male — male survivor self-image."


def length_for_tier(tier: str) -> dict:
    budgets = {
        "calm": {
            "temp": 0.78,
            "max_words": 20,
            "max_chars": 140,
            "max_tokens": 90,
            "instruction": (
                "PACING: Calm — 1 finished reflective sentence (10–20 words). "
                "Memory, dark humor, or small desire."
            ),
        },
        "uneasy": {
            "temp": 0.82,
            "max_words": 16,
            "max_chars": 120,
            "max_tokens": 80,
            "instruction": (
                "PACING: Uneasy — one edged scrap (8–16 words). Finish cleanly."
            ),
        },
        "scared": {
            "temp": 0.92,
            "max_words": 12,
            "max_chars": 95,
            "max_tokens": 64,
            "instruction": (
                "PACING: Scared — short fear/hate scraps (5–12 words). Immediate body/threat."
            ),
        },
        "panic": {
            "temp": 1.0,
            "max_words": 7,
            "max_chars": 64,
            "max_tokens": 48,
            "instruction": (
                "PACING: Panic — broken urgent fragments (2–7 words). "
                "Fast verbs, interjections; no philosophy."
            ),
        },
        "death": {
            "temp": 1.05,
            "max_words": 6,
            "max_chars": 52,
            "max_tokens": 40,
            "instruction": (
                "PACING: Extreme — 2–6 raw scraps. One emotional hit. Finish it."
            ),
        },
    }
    return budgets.get(tier or "calm", budgets["calm"])


def build_user_prompt(data: dict, budget: dict) -> str:
    if str(data.get("kind") or "").lower() == "dialogue":
        return build_dialogue_user_prompt(data, budget)
    return build_thought_user_prompt(data, budget)


def build_dialogue_user_prompt(data: dict, budget: dict) -> str:
    lang = (data.get("language") or "en").lower()
    if lang not in ("ru", "en"):
        lang = "ru"
    lang_name = LANG_NAMES.get(lang, "Russian")
    ch = data.get("character") or {}
    dlg = data.get("dialogue") or {}
    female = bool(ch.get("female"))
    name = f"{ch.get('forename', 'Survivor')} {ch.get('surname', '')}".strip()
    profession = ch.get("profession") or "unemployed"
    prof_label = ch.get("profession_label") or profession
    prof_voice = ch.get("profession_voice") or ""
    traits_voice = ch.get("traits_voice") or []
    traits_active = ch.get("traits_active") or []

    lines = [
        f"OUTPUT LANGUAGE: {lang_name} ({lang}). Spoken line ONLY in this language.",
        "Reply with ONE JSON object only (see system schema).",
        "",
        f"YOU ARE SPEAKING: {name} ({'female' if female else 'male'})",
        gender_lock_block(female, lang),
        f"Profession: {prof_label} — {prof_voice}",
    ]
    if traits_active:
        lines.append("Trait effects (soft — do not name traits):")
        for tip in traits_active[:4]:
            lines.append(f"  * {tip}")
    if traits_voice:
        lines.append("Speech color (soft):")
        for tip in traits_voice[:8]:
            lines.append(f"  - {tip}")

    lines.append("")
    lines.append(f"TRIGGER: {dlg.get('trigger') or 'talk'}")
    if dlg.get("trigger_micro"):
        lines.append(f"Beat: {dlg.get('trigger_micro')}")
    lines.append(f"Turn {dlg.get('turn') or 1}/{dlg.get('max_turns') or 6}")
    if dlg.get("prefer_end"):
        lines.append("Prefer closing the beat (should_end true) unless something urgent remains.")

    hint = str(dlg.get("address_mode_hint") or "all")
    lines.append(f"Address hint: {hint}")
    if hint == "named" and dlg.get("address_to"):
        af = dlg.get("address_female")
        sex = "unknown"
        if af is True:
            sex = "female"
        elif af is False:
            sex = "male"
        lines.append(
            f"Preferred addressee: {dlg.get('address_to')} (sex={sex}) — "
            "use address_mode=named and match grammar to their gender."
        )
    elif hint == "void":
        lines.append("You may speak into the void (address_mode=void).")
    else:
        lines.append("You may address the group (address_mode=all) or one person if natural.")

    parts = dlg.get("participants") or []
    if parts:
        lines.append("People nearby:")
        for p in parts[:6]:
            sex = "female" if p.get("female") else "male"
            lines.append(f"  - {p.get('name')} ({sex}) key={p.get('key')}")

    mem = (dlg.get("memory_soft") or "").strip()
    if mem:
        lines.append("")
        lines.append(f"MEMORY (soft — do not greet as strangers if you already know them): {mem}")

    if dlg.get("casual") or dlg.get("quiet") or str(dlg.get("trigger") or "").startswith("smalltalk_"):
        lines.append("")
        lines.append("CASUAL SMALL TALK: low stakes. Joke, gripe, story, memory, dream, want, or question.")
        lines.append("Do NOT invent zombies attacking, dying, or emergency unless history already has it.")

    banter = dlg.get("banter") or {}
    if isinstance(banter, dict) and banter:
        lines.append("")
        lines.append("BANTER CARD (soft — character first, never force):")
        lines.append(f"  allowed_tone: {banter.get('allowed_tone') or 'neutral'}")
        nicks = banter.get("optional_nicknames") or []
        if nicks:
            lines.append("  optional_nicknames: " + ", ".join(str(n) for n in nicks[:3]))
            lines.append("  never_force_nickname: true — use at most ONE nickname if it fits this line.")
        else:
            lines.append("  optional_nicknames: (none)")
        lines.append("  gender_forms: match addressee")
        tone = str(banter.get("allowed_tone") or "")
        if tone == "roast":
            lines.append("  Tone allows a sharp tease or harsh nickname if natural to THIS character.")
        elif tone == "warm":
            lines.append("  Tone prefers warmth / praise over insults.")
        elif tone == "tease":
            lines.append("  Light tease OK; avoid cruel pile-on.")

    hist = dlg.get("history") or []
    if hist:
        lines.append("")
        lines.append("RECENT LINES (do not repeat; answer in turn):")
        for h in hist[-4:]:
            am = h.get("address_mode") or ""
            ato = h.get("address_to") or ""
            who = h.get("speaker") or "?"
            prefix = who
            if am == "named" and ato:
                prefix = f"{who}→{ato}"
            elif am == "all":
                prefix = f"{who}→all"
            elif am == "void":
                prefix = f"{who}(void)"
            lines.append(f'  {prefix}: "{h.get("text") or ""}"')

    lines.append("")
    lines.append(
        f"LENGTH: max ~{min(int(budget.get('max_words') or 22), 28)} words spoken. "
        "One breath. Human. No gear checklist."
    )
    lines.append(
        "Priority soft stack: character > memory > trigger > mood > gender grammar. Never force."
    )
    return "\n".join(lines)


def build_thought_user_prompt(data: dict, budget: dict) -> str:
    lang = (data.get("language") or "en").lower()
    if lang not in ("ru", "en"):
        lang = "ru"
    lang_name = LANG_NAMES.get(lang, "Russian")
    ch = data.get("character") or {}
    swear_level = data.get("swear_level") or load_game_settings().get("swear_level") or "light"
    affect = data.get("affect") or {}
    hooks = data.get("prompt_hooks") or []
    digest = data.get("digest") or []

    female = bool(ch.get("female"))
    name = f"{ch.get('forename', 'Survivor')} {ch.get('surname', '')}".strip()
    profession = ch.get("profession") or "unemployed"
    prof_label = ch.get("profession_label") or profession
    prof_voice = ch.get("profession_voice") or ""
    traits = ch.get("traits") or []
    tier = affect.get("tier") or "calm"

    # Boost swear for angry/stress traits
    effective_swear = swear_level
    trait_blob = " ".join(str(t).lower() for t in traits)
    if swear_level in ("light", "medium") and any(
        x in trait_blob
        for x in ("desensitized", "brawler", "adrenalinejunkie", "smoker", "shorttemper")
    ):
        if swear_level == "light":
            effective_swear = "medium"
        elif swear_level == "medium":
            effective_swear = "heavy"

    lines = [
        f"TARGET LANGUAGE: {lang_name} ({lang})",
        gender_lock_block(female, lang),
        "",
        "CHARACTER:",
        f"- Name: {name} | Sex: {'Female' if female else 'Male'} | "
        'Solo survivor (first person "I/me" only — no "we/us")',
        f"- Background: {prof_label}"
        + (f" (Perspective: {_sanitize_micro(prof_voice)})" if prof_voice else ""),
        "",
        "STATE & ATMOSPHERE:",
    ]

    # Focus — plain English, no [id: micro]
    lines.append(f"- Focus: {format_focus_line(hooks, data)}")

    lines.append(f"- {dominant_impulse(data)}")
    lines.append(
        f"- Mood/Panic: {tier} (Distress: {affect.get('distress', 0)}; "
        f"panic01={affect.get('panic01', 0)}; unhappy={resolve_unhappy_level(data)}/4; "
        f"drunk={resolve_drunk_level(data)}/4)"
    )
    lines.append(f"- {atmosphere_line(data)}")
    _rx = reaction_level_line(data)
    if _rx:
        lines.append(f"- {_rx}")

    # Fact card (hard grounding)
    emo = data.get("emotion_phase") or (data.get("meta") or {}).get("emotion_phase") or "wander"
    hook_id_set = {str(h.get("id")) for h in hooks}
    fact_lines = build_fact_card_lines(data, list(digest or []), tier, emo, hook_id_set)
    lines.append("- Fact Card (Hard Limits):")
    if fact_lines:
        for d in fact_lines:
            lines.append(f"  • {d}")
    else:
        lines.append("  • (sparse — stay abstract emotion; invent no wounds/items)")
    lines.append(
        "  Do NOT invent specific wounds, doors, weapons, or missing items unless listed above."
    )

    illness_hooks = {
        "infection_knox",
        "illness_dread",
        "sick_queasy",
        "sick_feverish",
        "wound_bite",
        "bleed_worse",
        "wound_scratch",
        "wound_cut",
    }
    if hook_id_set & illness_hooks:
        lines.append("")
        sev = _wound_severity(data)
        if "sick_feverish" in hook_id_set or "sick_queasy" in hook_id_set:
            lines.append(
                "FEVER ANGLE — pick ONE: body heat/chills | heavy limbs | swear at sickness | thin hope it passes. "
                "Forbidden: teeth/fangs, electric metaphors, naming Knox."
            )
        elif sev == "minor" or (
            _primary_wound(data) and str((_primary_wound(data) or {}).get("kind")) == "scratch"
        ):
            lines.append(
                "MINOR WOUND ANGLE — pick ONE: swear at the sting | annoyance | urge to clean/bandage. "
                "Forbidden: dying drama, side/ribs/chest pain, zombie-blame unless Fact Card says bite."
            )
        else:
            lines.append(
                "WOUND ANGLE — pick ONE: rage/swear | prayer/bargain | thin hope | urge to clean/bandage. "
                "Forbidden: teeth/fangs re-film, electric metaphors, doom-clock."
            )

    media = (data.get("situation") or {}).get("media") or data.get("media") or {}
    media_line = (media.get("line") or "").strip()
    in_range = bool(media.get("in_range") or media.get("active"))
    if media_line and in_range and ("media_react" in hook_id_set or "media_watching" in hook_id_set):
        lines.append("")
        ch_name = media.get("channel") or ""
        extra = (", " + ch_name) if ch_name else ""
        lines.append(
            f'MEDIA LINE ({media.get("kind") or "radio"}{extra}): "{media_line}"'
        )
        lines.append("React to what was said/played — do not narrate watching.")

    arc_phase = data.get("arc_phase") or ""
    lines.append("")
    lines.append(f"EMOTION PHASE: {emo} | ARC PHASE: {arc_phase or 'none'}")
    if arc_phase in ("dead_end", "cooloff"):
        lines.append("CLOSE THE TOPIC: shrug / boredom / enough / silence-impulse.")

    lines.append(budget["instruction"])
    lines.append(
        f"HARD CAP: <= {budget['max_words']} words, <= {budget['max_chars']} characters."
    )
    lines.append(swear_instruction(effective_swear, lang))

    recent = load_recent_thoughts()
    if recent:
        lines.append("")
        lines.append("RECENT THOUGHTS (DO NOT REPEAT TOPICS/MOTIFS):")
        for r in recent[-6:]:
            lines.append(f"- {r}")
        if any(hits_cluster(r, TOPIC_CLUSTERS["clothes"]) for r in recent[-6:]):
            lines.append(
                "TOPIC LOCK: Hygiene, body odor, dirty clothes, washing. "
                "Pick a completely different topic."
            )
        if any(hits_cluster(r, TOPIC_CLUSTERS["alive_gun"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Survival bravado / gun-belt punchlines — forbidden this turn.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["dust_light"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Dust / light-beam imagery — forbidden this turn.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["chase_run"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Chase run-openers — smell/face/stumble/hate instead.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["fever_heat"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Fever / inner-heat metaphors — swear/prayer/hope/clean instead.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["bite_teeth"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Teeth / bite-mechanics imagery — forbidden.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["electric_tech"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Electric / appliance metaphors — forbidden.")
        if any(hits_cluster(r, TOPIC_CLUSTERS["doom_clock"]) for r in recent[-6:]):
            lines.append("TOPIC LOCK: Doom-clock endings — forbidden.")

    lines.extend(format_voice_bank_block(data, lang))
    lines.append("")
    lines.append("Generate ONE thought matching the character, grammar, and current state:")
    return "\n".join(lines)


def extract_message_text(message) -> str:
    """Pull assistant text; prefer content. Avoid treating CoT reasoning as the thought."""
    if message is None:
        return ""

    def from_content(content) -> str:
        if isinstance(content, str) and content.strip():
            return content.strip()
        if isinstance(content, list):
            parts = []
            for block in content:
                if isinstance(block, dict):
                    t = block.get("text") or block.get("content")
                    if t:
                        parts.append(str(t))
                else:
                    t = getattr(block, "text", None) or getattr(block, "content", None)
                    if t:
                        parts.append(str(t))
            return "\n".join(parts).strip()
        return ""

    content = from_content(getattr(message, "content", None))
    if content and not looks_like_meta_thought(content):
        return content

    # Only use reasoning if content empty AND reasoning does not look like CoT dump
    for attr in ("reasoning", "reasoning_content", "thinking"):
        val = getattr(message, attr, None)
        if isinstance(val, str) and val.strip() and not looks_like_meta_thought(val):
            return val.strip()
    extra = getattr(message, "model_extra", None) or {}
    if isinstance(extra, dict):
        for key in ("reasoning", "reasoning_content", "thinking"):
            val = extra.get(key)
            if isinstance(val, str) and val.strip() and not looks_like_meta_thought(val):
                return val.strip()

    # Last resort: raw content even if meta (caller will reject/retry)
    return content


def completion_kwargs_for_llm(llm: dict, budget: dict, temperature: float) -> dict:
    """Build chat.completions.create kwargs; disable Ollama think-mode for empty-content models."""
    kwargs = {
        "model": llm["model"],
        "temperature": temperature,
        "max_tokens": int(budget["max_tokens"]),
    }
    provider = (llm.get("provider") or "").lower()
    base = (llm.get("base_url") or "").lower()
    # Gemma4 via Ollama: need think=false AND reasoning_effort=none or content stays empty / CoT leaks
    if provider == "ollama" or "11434" in base:
        kwargs["extra_body"] = {"think": False, "reasoning_effort": "none"}
        kwargs["max_tokens"] = max(int(budget["max_tokens"]), 120)
    elif provider in ("deepseek", "openai") or "deepseek" in base:
        # Anti-loop without bloating the prompt; skip for Ollama compatibility
        kwargs["frequency_penalty"] = 0.5
    return kwargs


def call_deepseek(data: dict) -> str:
    """Call active LLM. For dialogue kind, returns JSON string; use call_llm_result for structured."""
    result = call_llm_result(data)
    return result.get("thought") or ""


def call_llm_result(data: dict) -> dict:
    """Call active LLM; returns dict with thought (+ dialogue fields when kind=dialogue)."""
    llm = current_llm()
    api_key = (llm.get("api_key") or "").strip()
    if llm.get("requires_key") and placeholder_key(api_key):
        raise RuntimeError(
            "API key missing — set in Bridge Launcher, F9, or bridge/.env"
        )
    if not api_key:
        api_key = "local"

    model = llm["model"]
    base_url = llm["base_url"]
    timeout = float(llm.get("timeout") or 60.0)
    kind = str(data.get("kind") or "thought").lower()

    ch = data.get("character") or {}
    affect = data.get("affect") or {}
    tier = affect.get("tier") or "calm"
    budget = length_for_tier(tier)
    if kind == "dialogue":
        budget = dict(budget)
        budget["max_words"] = min(int(budget.get("max_words") or 22), 28)
        budget["max_chars"] = min(int(budget.get("max_chars") or 160), 180)
        budget["max_tokens"] = max(int(budget.get("max_tokens") or 80), 120)
        budget["instruction"] = "LENGTH: one spoken breath."

    emo = data.get("emotion_phase") or (data.get("meta") or {}).get("emotion_phase") or ""
    if kind != "dialogue":
        if emo == "spike":
            budget = dict(budget)
            budget["max_words"] = min(int(budget.get("max_words") or 20), 7)
            budget["max_chars"] = min(int(budget.get("max_chars") or 140), 64)
            budget["max_tokens"] = min(int(budget.get("max_tokens") or 90), 48)
            budget["instruction"] = (
                "PACING: spike — 2–7 broken fragments. Raw urgent scrap. Finish it."
            )
        elif emo == "numb":
            budget = dict(budget)
            budget["max_words"] = min(int(budget.get("max_words") or 20), 12)
            budget["instruction"] = (
                (budget.get("instruction") or "") + " Numb: flat, tired fear — not panic poetry."
            )
    hooks = data.get("prompt_hooks") or []
    hook_ids = ",".join(str(h.get("id")) for h in hooks)

    print(
        f"[bridge] provider={llm.get('provider')} model={model} kind={kind} "
        f"profession={ch.get('profession')} female={ch.get('female')} "
        f"hooks={hook_ids} distress={affect.get('distress')} tier={tier} "
        f"temp={budget['temp']} lang={data.get('language')}"
    )

    client = OpenAI(api_key=api_key, base_url=base_url, timeout=timeout)
    recent = load_recent_thoughts()
    system_prompt = resolve_system_prompt(data)
    base_user = build_user_prompt(data, budget)
    text = ""
    temperature = budget["temp"]
    dlg_fields = {
        "address_mode": "all",
        "address_to": "",
        "should_end": False,
    }
    hook_id_set = {str(h.get("id")) for h in hooks}
    arc_phase = str(data.get("arc_phase") or "")
    digest_list = list(data.get("situation_digest") or data.get("digest") or [])
    accepted = False
    last_reasons: list[str] = []

    for attempt in range(3):
        extra = ""
        if attempt > 0:
            if kind == "dialogue":
                extra = (
                    "\n\nRETRY: previous output invalid. "
                    'Return ONLY JSON: {"text":"...","address_mode":"all|void|named",'
                    '"address_to":"","should_end":false}'
                )
                if text:
                    extra += f"\nRejected: {text[:200]}"
            elif "begut_open" in last_reasons:
                extra = (
                    "\n\nRETRY: do NOT start with «Бегут» / «They're running». "
                    "NEW combat angle: smell, face, stumble, hate — from VOICE BANK."
                )
            elif "meta" in last_reasons:
                extra = (
                    "\n\nRETRY: previous draft was META/PLANNING (Thinking Process). "
                    "FORBIDDEN. Output ONE short first-person thought ONLY. "
                    "Russian if OUTPUT LANGUAGE is Russian. No English analysis."
                )
            elif "ungrounded_trauma" in last_reasons:
                extra = (
                    "\n\nRETRY: invented trauma (ribs/door/limb/weapon/fall) not in FACT CARD. "
                    "Only generic pain/curse OR facts listed. No body-part cinema."
                )
                if text:
                    extra += f"\nRejected draft: {text}"
            elif "wound_lane" in last_reasons or "topic_lock" in last_reasons:
                extra = (
                    "\n\nRETRY: wrong wound SEMANTICS (teeth/fever/electric/doom-clock). "
                    "Pick ONE only: swear, prayer, thin hope («пронесёт»), "
                    "or urge to disinfect/bandage NOW. No зубы, no жар, no ток/проводка."
                )
                if text:
                    extra += f"\nRejected draft: {text}"
            elif "fever_loop" in last_reasons:
                extra = (
                    "\n\nRETRY: fever metaphor locked. "
                    "Swear / prayer / hope / disinfect — no жар poetry."
                )
                if text:
                    extra += f"\nRejected draft: {text}"
            elif "repeat_motif" in last_reasons:
                extra = (
                    "\n\nRETRY: same MOTIF as a recent thought (paraphrase). "
                    "New skeleton — different verbs/objects/memory. Not a rewrap."
                )
                if text:
                    extra += f"\nRejected draft: {text}"
            else:
                extra = (
                    "\n\nRETRY: previous draft was CLICHÉ, REPEAT, BODY-MIRROR, "
                    "ACTION NARRATION, or TRUNCATED. "
                    "NEW outward topic (room/weather/memory/joke/nature). Finish the sentence."
                )
                if text:
                    extra += f"\nRejected draft: {text}"

        user_msg = base_user + extra
        print_llm_prompt_dump(
            system_prompt,
            user_msg,
            attempt=attempt + 1,
            provider=str(llm.get("provider") or ""),
            model=str(model or ""),
        )

        create_kwargs = completion_kwargs_for_llm(
            llm, budget, min(1.15, temperature + attempt * 0.08)
        )
        resp = client.chat.completions.create(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_msg},
            ],
            **create_kwargs,
        )
        raw_out = extract_message_text(resp.choices[0].message)
        raw_out = raw_out.replace("</s>", "").replace("<s>", "").strip()

        if kind == "dialogue":
            parsed = parse_dialogue_payload(raw_out)
            text = parsed.get("text") or ""
            text = enforce_word_limit(text, budget["max_words"], budget["max_chars"])
            dlg_fields = {
                "address_mode": parsed.get("address_mode") or "all",
                "address_to": parsed.get("address_to") or "",
                "should_end": bool(parsed.get("should_end")),
            }
            if not text:
                print(f"[bridge] empty dialogue (attempt {attempt + 1}), retrying...")
                last_reasons = ["empty"]
                continue
            last_reasons = thought_reject_reasons(
                text,
                recent,
                tier=tier,
                hook_ids=hook_id_set,
                arc_phase=arc_phase,
                digest=digest_list,
            )
            # Dialogue: only hard meta/cliche gates (keep speech freer)
            last_reasons = [r for r in last_reasons if r in ("meta", "cliche", "empty")]
            if not last_reasons:
                accepted = True
                break
            print(
                f"[bridge] retry dialogue (attempt {attempt + 1}) "
                f"rejected={','.join(last_reasons)}: {text}"
            )
            continue

        text = raw_out
        if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'“”":
            text = text[1:-1].strip()
        text = enforce_word_limit(text, budget["max_words"], budget["max_chars"])

        if not text:
            print(f"[bridge] empty model reply (attempt {attempt + 1}), retrying...")
            last_reasons = ["empty"]
            continue

        last_reasons = thought_reject_reasons(
            text,
            recent,
            tier=tier,
            hook_ids=hook_id_set,
            arc_phase=arc_phase,
            digest=digest_list,
        )
        if not last_reasons:
            accepted = True
            break
        print(
            f"[bridge] retry thought (attempt {attempt + 1}) "
            f"rejected={','.join(last_reasons)}: {text}"
        )

    if not accepted or not text:
        why = ",".join(last_reasons) if last_reasons else "empty"
        raise RuntimeError(
            f"thought_rejected:{why} — fail-closed after retries "
            "(no publish of bad draft)"
        )

    save_recent_thought(text)
    out = {"thought": text, "kind": kind}
    if kind == "dialogue":
        out.update(dlg_fields)
    return out


def resolve_outbox(base: Path) -> Path | None:
    """Prefer B42 .txt outbox; fall back to legacy .json."""
    txt = base / "outbox" / "request.txt"
    js = base / "outbox" / "request.json"
    if txt.exists():
        return txt
    if js.exists():
        return js
    return None


def process_request_file(root: Path | None = None) -> None:
    base = root or IO_ROOT
    outbox = resolve_outbox(base)
    root_key = str(base)
    if outbox is None:
        return
    try:
        raw_bytes = outbox.read_bytes()
    except OSError:
        return
    if not raw_bytes or not raw_bytes.strip():
        return

    if raw_bytes.startswith(b"\xff\xfe") or raw_bytes.startswith(b"\xfe\xff"):
        raw = raw_bytes.decode("utf-16", errors="ignore")
    else:
        raw = raw_bytes.decode("utf-8", errors="ignore")
    raw = sanitize_json_text(raw).strip()
    if not raw:
        return

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        bad = base / "bad_request.txt"
        try:
            bad.write_text(raw[:4000], encoding="utf-8")
        except OSError:
            pass
        print(f"[bridge] invalid JSON ({base.name}): {e}")
        write_response("unknown", None, f"invalid_json: {e}", root=base)
        outbox.write_text("", encoding="utf-8")
        return

    request_id = str(data.get("request_id") or "")
    last_id = LAST_REQUEST_IDS.get(root_key)
    if not request_id or request_id == last_id:
        return

    print_request_diagnostics(data)
    write_status("processing", request_id, root=base)
    try:
        result = call_llm_result(data)
        thought = result.get("thought") or ""
        write_response(
            request_id,
            thought,
            None,
            root=base,
            kind=str(result.get("kind") or data.get("kind") or "thought"),
            address_mode=result.get("address_mode"),
            address_to=result.get("address_to"),
            should_end=result.get("should_end"),
        )
        print(f"[bridge] thought: {thought}")
        write_status("ok", request_id, root=base)
    except Exception as e:
        err = f"{type(e).__name__}: {e}"
        print(f"[bridge] ERROR {err}")
        traceback.print_exc()
        write_response(request_id, None, err, root=base)
        write_status("error", err, root=base)
    finally:
        LAST_REQUEST_IDS[root_key] = request_id
        try:
            outbox.write_text("", encoding="utf-8")
        except OSError:
            pass


def main() -> int:
    ensure_dirs(IO_ROOT)
    llm = current_llm()
    if llm.get("requires_key") and placeholder_key(llm.get("api_key") or ""):
        print("ERROR: API key is missing for the active provider.")
        print(f"  Open Bridge Launcher and set the key, or use {ROOT / '.env'}")
        print(f"  Config: {llm.get('config_path')}")
        return 1

    settings = load_game_settings()
    print("AI Thoughts bridge (multi-provider)")
    print(f"  provider: {llm.get('provider')} ({llm.get('label')})")
    print(f"  model   : {llm.get('model')}")
    print(f"  base_url: {llm.get('base_url')}")
    print(f"  timeout : {llm.get('timeout')}s")
    print(f"  io_root : {IO_ROOT}")
    print(
        f"  settings: {SETTINGS_TXT} "
        f"(lang={settings.get('language')}, swear={settings.get('swear_level')})"
    )
    print("  Tip: change provider in Bridge Launcher -> Save (hot-reload on next thought).")
    write_status("idle", "watching", root=IO_ROOT)

    while True:
        try:
            for root in iter_io_roots():
                process_request_file(root)
        except Exception:
            traceback.print_exc()
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    sys.exit(main() or 0)
