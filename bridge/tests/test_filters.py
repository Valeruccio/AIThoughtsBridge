# -*- coding: utf-8 -*-
"""Unit tests for bridge thought filters."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "bridge"))

from filters import (  # noqa: E402
    dead_end_opens_argument,
    enforce_word_limit,
    looks_like_lecture,
    looks_like_meta_thought,
    thought_fever_on_infection,
    thought_has_banned,
    thought_motif_repeat,
    thought_reject_reasons,
    thought_starts_begut,
    thought_too_similar,
    thought_topic_locked,
)


def test_banned_ru():
    assert thought_has_banned("Сердце в горле, надо бежать")


def test_banned_en():
    assert thought_has_banned("Only a matter of time now")


def test_machine_phrases():
    assert thought_has_banned("Адреналин ударил в кровь")
    assert thought_has_banned("Reality set in hard")


def test_natural_kak_budto_allowed():
    # Common spoken Russian — must not trip cliche ban (broke MP dialogues)
    assert not thought_has_banned(
        "Ноги гудят, как будто весь день по крышам лазил. Мелани, ты как?"
    )


def test_physio_fear_cliches_banned():
    assert thought_has_banned("Ноги ватные — не идут.")
    assert thought_has_banned("Сердце колотится как бешеное.")
    assert thought_has_banned("Живой человек рядом...")
    assert thought_has_banned("Hands shaking, heart pounding.")


def test_meta_reject():
    assert looks_like_meta_thought("Plan for inner voice: draft candidates")
    assert looks_like_meta_thought("OUTPUT LANGUAGE: Russian")
    assert not looks_like_meta_thought("Пахнет гнилью — ближе, чем хотелось бы.")


def test_begut_start():
    assert thought_starts_begut("Бегут ко мне снова")
    assert thought_starts_begut("They're running at me")
    assert not thought_starts_begut("Гнилой запах — снова они.")


def test_topic_lock_clothes():
    recent = ["Рубашка липнет от пота"]
    assert thought_topic_locked("Эта футболка опять мокрая", recent, "calm")


def test_topic_lock_chase():
    recent = ["Они бегут за мной"]
    assert thought_topic_locked("Бегут снова", recent, "scared")


def test_topic_lock_fever_all_tiers():
    recent = ["Жар уже не от рук — от всего тела. Значит, время пошло."]
    assert thought_topic_locked(
        "Жар уже не от беготни — изнутри, как замыкание.",
        recent,
        "scared",
    )


def test_similarity():
    recent = ["Тишина в доме давит странно"]
    assert thought_too_similar("Тишина в доме давит странно", recent)


def test_motif_egg_paraphrase():
    a = (
        "Голыми руками рядом с этим… блин, даже лопату не взял. "
        "Как в детстве — яиц набрал, а драться нечем."
    )
    b = "Голыми руками, блин, как в той драке в школе — яиц набрал, а бить нечем."
    assert thought_motif_repeat(b, [a])
    assert thought_too_similar(b, [a])


def test_fever_appliance_first_pass_blocked():
    assert thought_fever_on_infection(
        "Жар изнутри, как старая проводка, что вот-вот заискрит.",
        [],
        {"infection_knox"},
    )


def test_teeth_lane_blocked_on_infection():
    assert thought_fever_on_infection(
        "Блядь, больно! Зубы в руке… чистый ток, только вырубить нельзя.",
        [],
        {"wound_bite"},
    )
    reasons = thought_reject_reasons(
        "Блядь, больно! Зубы в руке… чистый ток, только вырубить нельзя.",
        [],
        tier="panic",
        hook_ids={"wound_bite"},
    )
    assert "wound_lane" in reasons


def test_took_damage_allows_pain_heat():
    """Ordinary hits may say рука горит / зубы клацнули — not Knox lanes."""
    reasons = thought_reject_reasons(
        "Блин, больно-то как… сука, рука онемела.",
        [],
        tier="panic",
        hook_ids={"took_damage"},
    )
    assert "wound_lane" not in reasons
    reasons2 = thought_reject_reasons(
        "Чёрт... как приложило, аж зубы клацнули.",
        [],
        tier="panic",
        hook_ids={"took_damage"},
    )
    assert "wound_lane" not in reasons2


def test_fever_second_pass_blocked():
    recent = ["Кровь на руках — и внутри уже жар, чёрт."]
    assert thought_topic_locked(
        "Блин, жар… щёки горят, как от печки. Это конец.",
        recent,
        "scared",
    )


def test_infection_hope_ok():
    reasons = thought_reject_reasons(
        "Блядь… ну пронесёт, да? Спирта бы на рану.",
        ["Кровь на руках — и внутри уже жар, чёрт."],
        tier="scared",
        hook_ids={"infection_knox"},
    )
    assert "wound_lane" not in reasons
    assert "fever_loop" not in reasons
    assert "topic_lock" not in reasons


def test_prayer_eto_not_truncated():
    from filters import looks_truncated

    assert not looks_truncated("Господи, только не это.")
    assert looks_truncated("Господи, только не")


def test_ungrounded_ribs_rejected():
    from filters import thought_ungrounded_trauma

    assert thought_ungrounded_trauma(
        "Вот это дало по рёбрам… Чёрт.",
        hook_ids={"took_damage"},
        digest=["damage=just_now", "outdoors day"],
    )
    reasons = thought_reject_reasons(
        "Ударило дверью в бок...",
        [],
        tier="panic",
        hook_ids={"took_damage"},
        digest=["damage=just_now"],
    )
    assert "ungrounded_trauma" in reasons


def test_generic_hit_ok_without_body_part():
    reasons = thought_reject_reasons(
        "Блин, задело… Сука.",
        [],
        tier="panic",
        hook_ids={"took_damage"},
        digest=["damage=just_now"],
    )
    assert "ungrounded_trauma" not in reasons


def test_bite_fact_allows_arm_mention_not_required():
    """With wound_bite + bites fact, prayer/hope OK (no teeth lane)."""
    reasons = thought_reject_reasons(
        "Господи, только бы не зараза... Заживёт ведь?",
        [],
        tier="scared",
        hook_ids={"wound_bite", "illness_dread"},
        digest=["bites=1", "illness_suspicion=yes"],
    )
    assert "ungrounded_trauma" not in reasons
    assert "wound_lane" not in reasons
    assert "truncated" not in reasons


def test_enforce_word_limit_sentence_safe():
    long = " ".join(["слово"] * 40) + ". Конец."
    out = enforce_word_limit(long, max_words=10, max_chars=200)
    assert len(out.split()) <= 12
    assert out


def test_enforce_trunc_hanging():
    text = "Я думаю что"
    out = enforce_word_limit(text, max_words=25, max_chars=160)
    assert out


def test_lecture_reject():
    assert looks_like_lecture("First: stay calm. Second: move.")
    assert not looks_like_lecture("Пахнет гнилью — ближе, чем хотелось бы.")


def test_dead_end_reopen():
    assert dead_end_opens_argument("Но ведь они всё равно придут, а что если?")
    assert not dead_end_opens_argument("Ладно, хватит об этом.")
