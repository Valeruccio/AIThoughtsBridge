# -*- coding: utf-8 -*-
"""Structured request diagnostics for AI Thoughts bridge terminal."""

from __future__ import annotations

import time
from typing import Any


def _num(v: Any, default: float | int | None = 0):
    try:
        if v is None:
            return default
        return float(v)
    except (TypeError, ValueError):
        return default


def _yes(v: Any) -> str:
    return "yes" if v else "no"


def _fmt_hooks(hooks: list) -> list[str]:
    lines = []
    for h in hooks or []:
        if not isinstance(h, dict):
            continue
        hid = h.get("id") or "?"
        pri = h.get("priority", "?")
        micro = str(h.get("micro") or "").strip()
        if len(micro) > 72:
            micro = micro[:69] + "..."
        lines.append(f"  [{pri:>3}] {hid}" + (f"  — {micro}" if micro else ""))
    if not lines:
        lines.append("  (none)")
    return lines


def _fmt_kv(d: dict | None, keys: list[str], indent: str = "  ") -> list[str]:
    d = d or {}
    parts = []
    for k in keys:
        if k in d and d[k] is not None:
            parts.append(f"{k}={d[k]}")
    if not parts:
        return [f"{indent}(empty)"]
    return [indent + "  ".join(parts)]


ILLNESS_IDS = frozenset({
    "illness_dread",
    "infection_knox",
    "sick_queasy",
    "sick_feverish",
    "sick_food",
    "sick_cold",
})


def _digest_has_infection_damage(digest: list) -> bool:
    for d in digest or []:
        s = str(d).lower()
        if "damage_type=infection" in s or "damage_type=infect" in s:
            return True
    return False


def diagnose_status(data: dict) -> list[tuple[str, str]]:
    """
    Return (level, message) rows.
    level: ok | note | warn
    """
    rows: list[tuple[str, str]] = []
    sit = data.get("situation") or {}
    vitals = sit.get("vitals") or {}
    body = sit.get("body") or {}
    combat = sit.get("combat") or {}
    moodles = sit.get("moodles") or {}
    digest = data.get("digest") or []
    hooks = [str(h.get("id")) for h in (data.get("prompt_hooks") or []) if isinstance(h, dict)]
    hook_set = set(hooks)
    primary = hooks[0] if hooks else ""

    knox = bool(vitals.get("knox"))
    infection = _num(vitals.get("infection_level"), 0) or 0
    sick = int(_num(moodles.get("sick"), 0) or 0)
    bites = int(_num(body.get("bites"), 0) or 0)
    scratches = int(_num(body.get("scratches"), 0) or 0)
    cuts = int(_num(body.get("cuts"), 0) or 0)
    took_hit = bool(combat.get("took_hit"))
    damage_fresh = bool(combat.get("damage_fresh"))
    dtype = str(combat.get("damage_type") or "").lower()
    has_illness = bool(hook_set & ILLNESS_IDS)
    symptoms = sick >= 1 or infection > 15
    skin = bites + scratches + cuts > 0

    # --- Infection tick misrouted as combat hit ---
    if primary == "took_damage" and (
        "infect" in dtype or _digest_has_infection_damage(digest)
    ):
        rows.append((
            "warn",
            "тик болезни попал в took_damage — должен идти в illness_*, не в «удар»",
        ))
    elif (knox or symptoms) and primary == "took_damage" and damage_fresh:
        rows.append((
            "note",
            "свежий урон важнее болезни в этом тике (took_damage выше illness) — ок, если это не INFECTION",
        ))

    # --- Knox / illness presence vs hooks ---
    if knox or symptoms:
        if has_illness:
            ids = ", ".join(sorted(hook_set & ILLNESS_IDS))
            rows.append(("ok", f"болезнь в фокусе: {ids}"))
        elif symptoms or skin:
            # Candidate would fire, but ranked hooks lack it → cooloff / trim
            rows.append((
                "note",
                f"болезнь на паузе (cooloff) — sick={sick} knox={_yes(knox)}; "
                "следующая мысль про симптомы после cooldown, не баг",
            ))
        elif knox and not symptoms and not skin:
            rows.append((
                "ok",
                "knox=да, симптомов ещё нет — молчим про заразу (как в PZ), не баг",
            ))

    if bites > 0 and "wound_bite" not in hook_set and primary == "took_damage":
        rows.append((
            "warn",
            f"есть укус (bites={bites}), но хук wound_bite не в фокусе — cooloff или приоритет боя",
        ))

    if primary == "took_damage" and not damage_fresh and not took_hit:
        rows.append((
            "warn",
            "хук took_damage без свежего damage_fresh — устаревший флаг",
        ))

    if primary in ILLNESS_IDS | {"wound_bite"} and damage_fresh and "infect" not in dtype:
        rows.append((
            "note",
            "illness/укус + свежий урон одновременно — промпт может смешать темы",
        ))

    unhappy = aff_level(data, "unhappy_level", "unhappy")
    if unhappy >= 3:
        rows.append(("ok", f"линза несчастья {unhappy}/4 активна (тон всех мыслей)"))
    drunk = aff_level(data, "drunk_level", "drunk")
    if drunk >= 2:
        rows.append(("ok", f"линза опьянения {drunk}/4 активна (тон всех мыслей)"))
    sick_n = aff_level(data, "sick_level", "sick")
    if sick_n >= 3:
        if has_illness:
            rows.append(("ok", f"лихорадка/болезнь в фокусе (sick={sick_n}/4)"))
        else:
            rows.append((
                "note",
                f"лихорадка sick={sick_n}/4 есть, но illness-хук на паузе (cooloff) — "
                "ухудшение стадии сбросит паузу",
            ))
    elif sick_n >= 1 and not has_illness:
        rows.append(("note", f"тошнота sick={sick_n}/4 без illness-хука (cooloff или другой фокус)"))

    if not rows:
        rows.append(("ok", "хуки в целом сходятся с сенсорами"))
    return rows


def aff_level(data: dict, aff_key: str, moodle_key: str) -> int:
    aff = data.get("affect") or {}
    m = ((data.get("situation") or {}).get("moodles")) or {}
    raw = aff.get(aff_key)
    if raw is None:
        raw = m.get(moodle_key)
    try:
        return max(0, min(4, int(raw or 0)))
    except (TypeError, ValueError):
        return 0


def aff_unhappy(data: dict) -> int:
    return aff_level(data, "unhappy_level", "unhappy")


# Back-compat for anything importing the old name
def diagnose_mismatches(data: dict) -> list[str]:
    return [f"[{lvl}] {msg}" for lvl, msg in diagnose_status(data)]


_LAST_REQUEST_MONO: float | None = None


def format_request_diagnostics(data: dict) -> str:
    """Multi-line structured dump for bridge terminal."""
    global _LAST_REQUEST_MONO
    now = time.monotonic()
    delta = None if _LAST_REQUEST_MONO is None else (now - _LAST_REQUEST_MONO)
    _LAST_REQUEST_MONO = now

    ch = data.get("character") or {}
    aff = data.get("affect") or {}
    meta = data.get("meta") or {}
    sit = data.get("situation") or {}
    vitals = sit.get("vitals") or {}
    body = sit.get("body") or {}
    combat = sit.get("combat") or {}
    moodles = sit.get("moodles") or {}
    zombies = sit.get("zombies") or {}
    media = sit.get("media") or data.get("media") or {}
    hooks = data.get("prompt_hooks") or []
    digest = data.get("digest") or []

    name = f"{ch.get('forename') or 'Survivor'} {ch.get('surname') or ''}".strip()
    sex = "F" if ch.get("female") else "M"
    kind = data.get("kind") or "thought"
    rid = data.get("request_id") or "?"

    lines: list[str] = []
    lines.append("")
    lines.append("=" * 64)
    lines.append(f"DST REQUEST  id={rid}")
    lines.append(f"  kind={kind}  lang={data.get('language') or '?'}  swear={data.get('swear_level') or '?'}")
    if delta is not None:
        flag = "  << FAST" if delta < 45 else ""
        lines.append(f"  since_prev={delta:.1f}s{flag}")
    else:
        lines.append("  since_prev=(first)")

    lines.append("CHARACTER")
    lines.append(
        f"  {name}  sex={sex}  profession={ch.get('profession') or '?'} "
        f"({ch.get('profession_label') or ''})"
    )
    traits = ch.get("traits") or []
    if traits:
        lines.append("  traits: " + ", ".join(str(t) for t in traits[:16]))
    else:
        lines.append("  traits: (none)")

    lines.append("AFFECT")
    drunk_lvl = aff.get("drunk_level")
    if drunk_lvl is None:
        drunk_lvl = moodles.get("drunk") or 0
    sick_lvl = aff.get("sick_level")
    if sick_lvl is None:
        sick_lvl = moodles.get("sick") or 0
    feverish = aff.get("feverish")
    if feverish is None:
        feverish = int(_num(sick_lvl, 0) or 0) >= 3 or int(_num(moodles.get("hyperthermia"), 0) or 0) >= 2
    lines.append(
        f"  tier={aff.get('tier') or '?'}  distress={_num(aff.get('distress')):.2f}  "
        f"stress01={_num(aff.get('stress01')):.2f}  panic01={_num(aff.get('panic01')):.2f}  "
        f"unhappy={aff.get('unhappy_level') if aff.get('unhappy_level') is not None else moodles.get('unhappy') or 0}/4  "
        f"drunk={drunk_lvl}/4"
    )
    lines.append(
        f"  sick={sick_lvl}/4  fever={_yes(feverish)}  "
        f"hyper={moodles.get('hyperthermia') or aff.get('hyperthermia_level') or 0}  "
        f"cold={_yes(aff.get('has_cold') or moodles.get('has_a_cold'))}  "
        f"knox={_yes(vitals.get('knox') or aff.get('knox'))}"
    )
    lines.append(
        f"  emotion={data.get('emotion_phase') or meta.get('emotion_phase') or '?'}  "
        f"acute={_yes(meta.get('acute'))}  max_priority={meta.get('max_priority') or 0}  "
        f"arc={data.get('arc_phase') or '-'}({data.get('arc_turns') or 0})"
    )

    lines.append("HOOKS")
    lines.extend(_fmt_hooks(hooks))

    lines.append("COMBAT FLAGS")
    lines.extend(
        _fmt_kv(
            combat,
            ["took_hit", "in_combat", "landed_hit", "gunshot", "damage_fresh", "damage_type"],
        )
    )

    lines.append("BODY / WOUNDS")
    lines.extend(
        _fmt_kv(
            body,
            ["bites", "scratches", "cuts", "deep", "fractures", "bleeding_parts", "burns"],
        )
    )

    lines.append("VITALS")
    lines.append(
        f"  health={vitals.get('health')}  knox={_yes(vitals.get('knox'))}  "
        f"infection={vitals.get('infection_level')}  pain={vitals.get('pain')}  "
        f"panic={vitals.get('panic')}  stress={vitals.get('stress')}  "
        f"drunk={vitals.get('drunkenness') if vitals.get('drunkenness') is not None else moodles.get('drunk')}"
    )

    lines.append("ILLNESS")
    sick_m = int(_num(moodles.get("sick"), 0) or 0)
    hyper_m = int(_num(moodles.get("hyperthermia"), 0) or 0)
    food_s = vitals.get("food_sickness")
    stage = "none"
    if sick_m >= 4 or hyper_m >= 3:
        stage = "fever_hard"
    elif sick_m >= 3 or hyper_m >= 2:
        stage = "fever"
    elif sick_m >= 1:
        stage = "queasy"
    elif aff.get("has_cold") or moodles.get("has_a_cold"):
        stage = "cold"
    lines.append(
        f"  stage={stage}  sick={sick_m}/4  hyperthermia={hyper_m}  "
        f"food_sickness={food_s}  cold={_yes(moodles.get('has_a_cold'))}  "
        f"feverish={_yes(feverish)}"
    )

    lines.append("MOODLES")
    mkeys = [
        "panic", "stressed", "pain", "sick", "bleeding", "injured", "tired",
        "hungry", "thirsty", "bored", "unhappy", "drunk", "has_a_cold", "hyperthermia",
    ]
    mparts = [f"{k}={moodles[k]}" for k in mkeys if moodles.get(k)]
    lines.append("  " + ("  ".join(mparts) if mparts else "(none elevated)"))

    lines.append("WORLD")
    place = "indoors" if sit.get("indoors") else "outdoors"
    lines.append(
        f"  {place}  {sit.get('part_of_day') or '?'}  hour={sit.get('hour')}  "
        f"zeds visible={zombies.get('visible')} chasing={zombies.get('chasing')} "
        f"close={zombies.get('close')}"
    )
    if media.get("active") or media.get("line"):
        line = str(media.get("line") or "")[:60]
        lines.append(
            f"  media={media.get('kind') or '?'} ch={media.get('channel') or '-'} "
            f"in_range={_yes(media.get('in_range'))} line=\"{line}\""
        )
    else:
        lines.append("  media=(none)")

    if digest:
        lines.append("DIGEST")
        for d in digest[:8]:
            lines.append(f"  - {d}")

    status = diagnose_status(data)
    lines.append("DIAG")
    mark = {"ok": "·", "note": "·", "warn": "!"}
    label = {"ok": "ok  ", "note": "note", "warn": "WARN"}
    for lvl, msg in status:
        lines.append(f"  {mark.get(lvl, '·')} [{label.get(lvl, lvl)}] {msg}")
    lines.append("=" * 64)
    return "\n".join(lines)


def print_request_diagnostics(data: dict) -> None:
    print(format_request_diagnostics(data), flush=True)


def format_llm_prompt_dump(
    system: str,
    user: str,
    *,
    attempt: int = 1,
    provider: str = "",
    model: str = "",
) -> str:
    """Pretty dump of the exact messages sent to the LLM (for prompt tuning)."""
    lines: list[str] = []
    lines.append("")
    lines.append("-" * 64)
    lines.append(f"LLM REQUEST  attempt={attempt}")
    if provider or model:
        lines.append(f"  provider={provider or '?'}  model={model or '?'}")
    lines.append("")
    lines.append("--- SYSTEM ---")
    sys_t = (system or "").rstrip()
    lines.append(sys_t if sys_t else "(empty)")
    lines.append("")
    lines.append("--- USER ---")
    usr_t = (user or "").rstrip()
    lines.append(usr_t if usr_t else "(empty)")
    lines.append("")
    lines.append("-" * 64)
    return "\n".join(lines)


def print_llm_prompt_dump(
    system: str,
    user: str,
    *,
    attempt: int = 1,
    provider: str = "",
    model: str = "",
) -> None:
    print(
        format_llm_prompt_dump(
            system,
            user,
            attempt=attempt,
            provider=provider,
            model=model,
        ),
        flush=True,
    )
