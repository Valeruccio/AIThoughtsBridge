# -*- coding: utf-8 -*-
"""Thought quality filters for AI Thoughts bridge (testable)."""

from __future__ import annotations

BANNED_SUBSTR = [
    # RU
    "сердце в горле",
    "сердце прыгнуло",
    "сердце ёкнуло",
    "лишь вопрос времени",
    "кажется пронесло",
    "надо двигаться дальше",
    "тишина давит",
    "ещё один день",
    "еще один день",
    "мир погрузился",
    "танец смерти",
    "призраки прошлого",
    "хрупкая надежда",
    "главное выжить",
    "в этом мире",
    "остается только",
    "остаётся только",
    "адреналин ударил",
    "реальность ударила",
    "нужно сосредоточиться",
    # Physiological fear tropes / survivor melodrama
    "ноги ватн",
    "вцементир",
    "руки дрож",
    "сердце колол",
    "сердце колотит",
    "замер как",
    "живой человек",
    # EN
    "heart in my throat",
    "heart skipped",
    "only a matter of time",
    "that was close",
    "keep moving",
    "silence presses",
    "another day",
    "dance of death",
    "ghosts of the past",
    "fragile hope",
    "must survive",
    "adrenaline surged",
    "reality set in",
    "i need to focus",
    "in this world",
    "legs like jelly",
    "cemented to the floor",
    "hands shaking",
    "heart pounding",
    "another living",
]

TOPIC_CLUSTERS = {
    "clothes": [
        "футболк", "форма", "рубашк", "шляп", "кепк", "одежд", "липнет", "выжми", "выжимай",
        "shirt", "uniform", "hat", "cap", "sweat", "пот ", "крови", "blood on",
    ],
    "alive_gun": [
        "живой", "жива", "ствол", "при стволе", "на поясе", "still alive", "still breathing",
        "и то хлеб", "на том спасибо",
    ],
    "dust_light": [
        "пыль", "пылью", "луче", "луч ", "солнечн", "солнца", "dust", "sunbeam", "shaft of light",
        "в полоске", "кружится",
    ],
    "chase_run": [
        "бегут", "бежит", "бегом", "за мной", "твари бегут", "они бегут", "бегут ко мне",
        "they're running", "running at me", "chasing me",
    ],
    # Semantic lanes for post-wound spam (lock on repeat, all tiers)
    "fever_heat": [
        "жар", "жаром", "жара", "изнутри", "перегрет", "горю", "горит", "горят щек",
        "горят щёк", "щеки горят", "щёки горят", "температур", "fever", "burning up",
        "from inside", "overheated",
    ],
    "bite_teeth": [
        "зуб", "зубы", "зуба", "зубов", "зубам", "клык", "клыки", "челюст",
        "укуси", "укусил", "укусили", "прокуси", "прокусил", "впились", "впился",
        "teeth", "tooth", "fangs", "bitten", "bite ", "jaw",
    ],
    "electric_tech": [
        "ток", "током", "вырубить", "выруби", "трансформатор", "розетк", "электр",
        "проводк", "замыкани", "заискр", "кипятильник", "счетчик", "счётчик",
        "печк", "печки", "fuse", "wiring", "kettle", "meter", "voltage", "circuit",
    ],
    "doom_clock": [
        "время пошло", "это конец", "скоро погас", "уже труп", "я труп", "я уже труп",
        "сейчас труп", "the end", "i'm dead", "im dead", "already dead",
    ],
}

# Persistent wound/infection focus — these hooks must not re-tell bite mechanics
# NOTE: took_damage is NOT here — ordinary hits use pain/anger, not Knox lanes
INFECTION_HOOKS = frozenset({
    "infection_knox",
    "illness_dread",
    "sick_queasy",
    "sick_feverish",
    "wound_bite",
    "bleed_worse",
})

# Under bite/dread hooks: these lanes are wrong (appliance fever metaphors, teeth)
INFECTION_FORBIDDEN_LANES = frozenset({
    "fever_heat",
    "bite_teeth",
    "electric_tech",
})

# Real fever/sickness moodles: body heat language is ALLOWED (still ban teeth + electric)
FEVER_SYMPTOM_HOOKS = frozenset({
    "sick_feverish",
    "sick_queasy",
    "moodle_hot",
    "sick_food",
    "sick_cold",
})

DREAD_NO_FEVER_METAPHOR = frozenset({
    "infection_knox",
    "illness_dread",
    "wound_bite",
    "bleed_worse",
})

# Specific trauma claims that require matching digest/hook evidence
_TRAUMA_BODY = (
    "ребер", "рёбер", "ребра", "рёбра", "грудин", "грудь", "груди",
    "позвон", "позвоноч", "лопатк", "ключиц",
    "колен", "лодыжк", "голен", "бедро", "бедр ",
    "плеч", "локте", "запяст", "пальц",
    "ribs", "rib ", "sternum", "chest hit", "spine", "shoulder",
    "knee", "ankle", "thigh", "elbow", "wrist",
)
_TRAUMA_SCENE = (
    "дверью", "дверью в", "дверь в", "дверь ударил", "ударило двер",
    "кулаком", "прикладом", "пулей", "дробью", "нож", "топором",
    "споткнул", "упал", "упала", "упало", "споткнулась",
    "door hit", "hit by door", "bullet", "bayonet", "stumbled", "tripped",
)

# Lanes that lock on repeat at any tier
ALWAYS_LOCK_LANES = frozenset({
    "fever_heat",
    "bite_teeth",
    "electric_tech",
    "doom_clock",
    "chase_run",
})

META_THOUGHT_MARKERS = (
    "thinking process",
    "plan for inner voice",
    "constraint checklist",
    "the user wants me",
    "analyze the request",
    "drafting candidate",
    "execution",
    "confidence score",
    "system prompt",
    "i will generate",
    "output language",
    "hard rules",
    "voice bank",
    "focus react",
)

_TRUNC_TAIL_WORDS = {
    # Conjunctions / incomplete openers only — NOT content words like «это»
    "как", "а", "и", "но", "что", "чтобы", "если", "когда", "потому", "или",
    "не", "ни", "да", "уж", "ну", "вот",
    "and", "or", "but", "if", "when", "that", "to", "the", "a", "an",
    "with", "for", "of", "as", "so", "because",
}

# Function words — dropped before motif fingerprint
_STOPWORDS = _TRUNC_TAIL_WORDS | {
    "это", "тот", "та", "те",
    "меня", "мне", "мной", "мой", "моя", "мое", "моё", "мои",
    "уже", "еще", "ещё", "сам", "сама", "они", "он", "она", "оно",
    "этот", "эта", "эти", "этой", "этом", "того", "том", "тем",
    "был", "была", "было", "были", "будет", "быть",
    "есть", "нет", "для", "при", "под", "над", "без", "про", "через",
    "все", "всё", "всего", "всех", "теперь", "сейчас", "потом",
    "очень", "просто", "только", "даже", "рядом", "снова", "опять",
    "значит", "типа", "короче", "блин", "чёрт", "черт", "блядь", "блять",
    "from", "with", "this", "that", "have", "has", "was", "were", "been",
    "will", "just", "only", "into", "onto", "about", "then", "than",
    "my", "me", "i", "im", "i'm", "its", "it's", "the", "a", "an",
}

_STEM_SUFFIXES = (
    "ями", "ами", "ого", "ему", "ому", "ыми", "ими",
    "ах", "ях", "ов", "ев", "ей", "ой", "ая", "ые", "ие", "ую", "юю",
    "ам", "ям", "ом", "ем", "ии", "ью", "ий", "ый",
    "ть", "ти", "ла", "ли", "ло",
    "ing", "ers", "ied", "ies", "ed", "es", "ly",
)


def norm(text: str) -> str:
    t = (text or "").lower().replace("ё", "е")
    for ch in ".,—–-!?…:;\"'()[]{}«»<>":
        t = t.replace(ch, " ")
    return " ".join(t.split())


def _stem_token(w: str) -> str:
    w = (w or "").lower().replace("ё", "е")
    if len(w) <= 4:
        return w
    for suf in _STEM_SUFFIXES:
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            w = w[: -len(suf)]
            break
    if len(w) > 7:
        return w[:7]
    return w


def content_stems(text: str) -> list[str]:
    """Content-bearing stems for motif fingerprint (RU/EN light stem)."""
    out: list[str] = []
    for w in norm(text).split():
        if w in _STOPWORDS or len(w) < 3:
            continue
        if w.isdigit():
            continue
        out.append(_stem_token(w))
    return out


def motif_bigrams(stems: list[str]) -> set[str]:
    return {f"{stems[i]}+{stems[i + 1]}" for i in range(len(stems) - 1)}


def thought_motif_repeat(text: str, recent: list[str], window: int = 10) -> bool:
    """
    Motif fingerprint: same meaning skeleton under different wrapping.
    Catches «голыми руками… яиц набрал» paraphrases that Jaccard misses.
    """
    stems = content_stems(text)
    if len(stems) < 2:
        return False
    bigrams = motif_bigrams(stems)
    stem_set = set(stems)
    for prev in (recent or [])[-window:]:
        pstems = content_stems(prev)
        if len(pstems) < 2:
            continue
        pbig = motif_bigrams(pstems)
        pset = set(pstems)
        shared_bi = bigrams & pbig
        shared_st = stem_set & pset
        # Two shared content bigrams = same motif
        if len(shared_bi) >= 2:
            return True
        # One strong bigram + enough stem overlap
        if len(shared_bi) >= 1 and len(shared_st) >= 3:
            return True
        # Dense stem overlap without needing bigrams
        if len(shared_st) >= 4:
            return True
        union = stem_set | pset
        if union and (len(shared_st) / len(union)) >= 0.42:
            return True
    return False


def thought_too_similar(text: str, recent: list[str]) -> bool:
    n = norm(text)
    if not n:
        return True
    words = set(n.split())
    if not words:
        return True
    if thought_motif_repeat(text, recent):
        return True
    for prev in recent:
        p = norm(prev)
        if not p:
            continue
        if n == p:
            return True
        if len(n) > 20 and (n[:35] == p[:35] or n in p or p in n):
            return True
        pw = set(p.split())
        if not pw:
            continue
        overlap = len(words & pw) / max(1, len(words | pw))
        # Slightly tighter than before (0.45 let egg-paraphrase through at 0.41)
        if overlap >= 0.38:
            return True
    return False


def hits_cluster(text: str, markers: list[str]) -> bool:
    n = norm(text)
    for m in markers:
        if norm(m) in n:
            return True
    return False


def lanes_hit(text: str) -> set[str]:
    """Which semantic lanes fire in this scrap."""
    hit: set[str] = set()
    for name, markers in TOPIC_CLUSTERS.items():
        if hits_cluster(text, markers):
            hit.add(name)
    return hit


def thought_topic_locked(text: str, recent: list[str], tier: str) -> bool:
    window = recent[-8:] if recent else []
    if not window:
        return False
    text_lanes = lanes_hit(text)
    # Always-lock lanes: one use in recent window → no rewrap
    for name in text_lanes & ALWAYS_LOCK_LANES:
        if any(name in lanes_hit(r) for r in window):
            return True
    if (tier or "calm") not in ("calm", "uneasy"):
        return False
    for name, markers in TOPIC_CLUSTERS.items():
        if name in ALWAYS_LOCK_LANES:
            continue
        if name not in text_lanes:
            continue
        if any(hits_cluster(r, markers) for r in window):
            return True
    return False


def thought_infection_bad_lane(text: str, hook_ids: set[str] | None) -> bool:
    """
    Under bite/dread: ban teeth + electric + fever-appliance metaphors.
    Under sick_feverish / queasy: body heat OK; still ban teeth + electric.
    """
    hooks = hook_ids or set()
    if not (hooks & INFECTION_HOOKS):
        return False
    hit = lanes_hit(text)
    forbidden: set[str] = {"bite_teeth", "electric_tech"}
    # Body fever language allowed when fever/sickness symptom hooks are active
    if not (hooks & FEVER_SYMPTOM_HOOKS):
        forbidden.add("fever_heat")
    return bool(hit & forbidden)


def _digest_blob(digest: list[str] | None, hook_ids: set[str] | None) -> str:
    parts = list(digest or [])
    if hook_ids:
        parts.extend(sorted(hook_ids))
    return " ".join(str(p).lower() for p in parts)


def thought_ungrounded_trauma(
    text: str,
    hook_ids: set[str] | None = None,
    digest: list[str] | None = None,
) -> bool:
    """
    Reject invented body-part / door / weapon trauma when FACTS do not support it.
    Generic pain/curse without a specific body part is OK under took_damage.
    """
    n = norm(text)
    if not n:
        return False
    hooks = hook_ids or set()
    blob = _digest_blob(digest, hooks)

    has_body_claim = any(tok in n for tok in _TRAUMA_BODY)
    has_scene_claim = any(tok in n for tok in _TRAUMA_SCENE)

    if not has_body_claim and not has_scene_claim:
        return False

    # Evidence in digest / hooks
    body_ok = any(
        k in blob
        for k in (
            "bites=",
            "scratches=",
            "cuts=",
            "fractures=",
            "deep_wounds=",
            "bleed_parts=",
            "wound_bite",
            "wound_scratch",
            "wound_cut",
            "wound_fracture",
            "wound_deep",
            "bleed_worse",
        )
    )
    # Named body part in damage_type (rare)
    damage_names_limb = any(
        x in blob
        for x in ("arm", "leg", "hand", "foot", "torso", "head", "neck", "groin")
    )
    fall_ok = "fall" in blob or "damage_type=fall" in blob.replace(" ", "")
    door_ok = "door" in blob or "veh_crash" in blob or "vehicle=" in blob
    gun_ok = "gunshot" in blob or "bullet" in blob

    if has_scene_claim:
        # "ни ножа / нет палки" is inventory emptiness, not a stabbing claim
        neg_weapon = any(
            x in n
            for x in (
                "ни нож",
                "нет нож",
                "без нож",
                "ни палк",
                "нет палк",
                "без палк",
                "no knife",
                "no stick",
                "без оружия",
                "нет оружия",
            )
        )
        if any(x in n for x in ("двер", "door")) and not door_ok:
            return True
        if any(x in n for x in ("пул", "дроб", "bullet", "прикла")) and not gun_ok:
            return True
        if any(x in n for x in ("споткнул", "упал", "упала", "упало", "stumbled", "tripped")) and not fall_ok:
            return True
        if any(x in n for x in ("кулак", "нож", "топор")) and not body_ok and not neg_weapon:
            return True

    if has_body_claim and not body_ok and not damage_names_limb:
        # took_damage with no wound facts: generic pain only — specific ribs/chest = invent
        return True

    return False


# Back-compat alias used by older tests
def thought_fever_on_infection(text: str, recent: list[str], hook_ids: set[str] | None) -> bool:
    return thought_infection_bad_lane(text, hook_ids)


def thought_starts_begut(text: str) -> bool:
    t = (text or "").strip()
    while t and t[0] in "«\"'“”":
        t = t[1:].lstrip()
    t = t.lower()
    return (
        t.startswith("бегут")
        or t.startswith("they're running")
        or t.startswith("they are running")
    )


def thought_has_banned(text: str) -> bool:
    n = norm(text)
    for b in BANNED_SUBSTR:
        if norm(b) in n:
            return True
    return False


def looks_like_meta_thought(text: str) -> bool:
    n = norm(text)
    if not n:
        return True
    for m in META_THOUGHT_MARKERS:
        if m in n:
            return True
    if n.startswith("plan ") or n.startswith("thinking ") or n.startswith("step "):
        return True
    return False


def last_sentence_end(s: str) -> int:
    best = -1
    for i, ch in enumerate(s):
        if ch in ".!?…":
            best = i
    return best


def looks_truncated(text: str) -> bool:
    t = (text or "").strip()
    if not t:
        return True
    last = t.split()[-1].lower().strip(".,!?;:…\"'«»")
    if last in _TRUNC_TAIL_WORDS:
        return True
    if t[-1] in ",;:-—–":
        return True
    return False


def enforce_word_limit(text: str, max_words: int = 25, max_chars: int = 160) -> str:
    text = (text or "").strip().replace("\n", " ")
    if not text:
        return text

    words = text.split()
    if len(words) > max_words:
        candidate = " ".join(words[:max_words]).rstrip(" ,;:")
        end = last_sentence_end(candidate)
        if end >= 8:
            text = candidate[: end + 1].strip()
        else:
            text = candidate
            if not text.endswith((".", "!", "?", "…")):
                text = text.rstrip(" ,;:") + "."

    if len(text) > max_chars:
        cut = text[:max_chars]
        end = last_sentence_end(cut)
        if end >= 8:
            text = cut[: end + 1].strip()
        else:
            text = cut.rsplit(" ", 1)[0].rstrip(" ,;:")
            if text and text[-1] not in ".!?…":
                text += "."

    return text.strip()


def looks_like_lecture(text: str) -> bool:
    """Reject list-y / colon-lecture machine voice."""
    t = (text or "").strip()
    if not t:
        return True
    if t.count(":") >= 2:
        return True
    if t.count(";") >= 2:
        return True
    # Numbered or bulleted scraps
    n = norm(t)
    if n.startswith("1 ") or n.startswith("1)") or n.startswith("- "):
        return True
    return False


def dead_end_opens_argument(text: str) -> bool:
    """Reject closing scraps that reopen debate."""
    n = norm(text)
    if not n:
        return True
    reopen = (
        "но ведь",
        "а что если",
        "maybe we",
        "what if",
        "however",
        "с другой стороны",
        "нужно понять",
        "we should",
        "i should consider",
    )
    for r in reopen:
        if r in n:
            return True
    # Too many question marks = keeps poking the topic
    if (text or "").count("?") >= 2:
        return True
    return False


def thought_reject_reasons(
    text: str,
    recent: list[str],
    tier: str = "calm",
    hook_ids: set[str] | None = None,
    arc_phase: str = "",
    digest: list[str] | None = None,
) -> list[str]:
    """Return list of reject reasons (empty = accept)."""
    reasons: list[str] = []
    if not (text or "").strip():
        reasons.append("empty")
        return reasons
    if looks_like_meta_thought(text):
        reasons.append("meta")
    if thought_has_banned(text):
        reasons.append("cliche")
    if thought_too_similar(text, recent):
        reasons.append("repeat_motif")
    if looks_truncated(text):
        reasons.append("truncated")
    if thought_topic_locked(text, recent, tier):
        reasons.append("topic_lock")
    if thought_infection_bad_lane(text, hook_ids):
        reasons.append("wound_lane")
    if thought_ungrounded_trauma(text, hook_ids, digest):
        reasons.append("ungrounded_trauma")
    if thought_starts_begut(text):
        reasons.append("begut_open")
    if looks_like_lecture(text):
        reasons.append("lecture")
    if arc_phase in ("dead_end", "cooloff") and dead_end_opens_argument(text):
        reasons.append("dead_end_reopen")
    return reasons
