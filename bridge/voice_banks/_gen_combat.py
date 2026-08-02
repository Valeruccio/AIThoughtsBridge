# -*- coding: utf-8 -*-
"""Generate combat_monologues.json — anti-Begut chase scraps."""
import json
from pathlib import Path

entries = []


def add(eid, tiers, tags, ru, en=None, gender="any", soft_dark=False, prof_bias=None):
    e = {
        "id": eid,
        "tiers": tiers,
        "tags": tags,
        "gender": gender,
        "soft_dark": soft_dark,
        "ru": ru,
    }
    if en:
        e["en"] = en
    if soft_dark:
        e["soft_dark"] = True
    if prof_bias:
        e["prof_bias"] = prof_bias
    entries.append(e)


# Hate / smell / faces — NO «бегут»
add("rot_breath", ["scared", "combat", "uneasy"], ["smell", "hate"],
    "Вонь гнилого рта уже в ноздрях. Мелькни ещё, падла.")
add("wet_jaw", ["scared", "combat"], ["smell", "hate"],
    "Челюсть хлюпает. Хоть бы зубы себе выбил об асфальт.")
add("looks_boss", ["uneasy", "combat", "scared"], ["zombie", "joke"],
    "Этот упырь похож на начальника. Даже улучшение.")
add("looks_neighbor", ["uneasy", "combat"], ["zombie", "joke"],
    "Сосед в халате. Узнал. Привет… нет.")
add("looks_ex", ["uneasy", "combat"], ["zombie", "regret"],
    "Бывшая? Серьёзно? Вселенная троллит.")
add("stumble_please", ["combat", "scared"], ["hate", "joke"],
    "Споткнись уже, падаль. Хоть раз.")
add("pack_shadow", ["scared", "uneasy"], ["fear"],
    "Тени слишком близко. Считай шаги — свои, не их.")
add("ammo_count", ["combat", "scared"], ["guns"],
    "Патроны в уме. Цифры утешают хуже молитвы.",
    prof_bias=["policeofficer", "veteran"])
add("finger_straight", ["combat", "scared"], ["guns", "memory"],
    "Палец прямее совести. Старая привычка.",
    prof_bias=["veteran", "policeofficer"])
add("hate_them", ["scared", "combat", "panic"], ["hate"],
    "Ненавижу. Каждого. Особенно этого.")
add("teeth_close", ["scared", "panic", "death"], ["fear"],
    "Зубы слишком близко. Нет-нет-нет.")
add("dont_breathe", ["scared", "panic"], ["fear"],
    "Не дыши. Не сейчас. Потом.")
add("legs_work", ["scared", "panic"], ["fear", "body"],
    "Ноги, работайте. Просто работайте.")
add("vision_tunnel", ["panic", "death"], ["fear"],
    "Туннель вместо мира. Держись.")
add("crowd_math", ["scared", "panic"], ["fear"],
    "Их слишком много. Математика против меня.")
add("gun_jam", ["scared", "combat"], ["guns", "fear"],
    "Только не клин. Только не сейчас.")
add("one_more_head", ["combat", "scared"], ["guns", "swagger"],
    "Ещё один. В голову.",
    prof_bias=["veteran", "policeofficer"])
add("reload_prayer", ["combat"], ["guns"],
    "Перезарядка как молитва. Короткая. Громкая.")
add("axe_rhythm", ["combat"], ["hate"],
    "Ритм удара. Раз. Два. Как дрова — только злее.",
    prof_bias=["lumberjack"])
add("knife_romance", ["combat"], ["joke"],
    "Кухонный нож — мой новый роман. Токсичный.")
add("smell_stairwell", ["scared", "combat"], ["smell"],
    "Воняет как после драки в подъезде. Только эти прут толпой.")
add("sarge_face", ["combat", "scared"], ["zombie", "memory"],
    "Тупой взгляд — как у старшины. Тот же ноль в глазах.",
    prof_bias=["veteran"])
add("fallujah_dogs", ["scared", "death"], ["memory", "hate"],
    "Как те псы — только гнилые.",
    prof_bias=["veteran"])
add("baghdad_slow", ["scared", "death"], ["memory", "joke"],
    "Как там — только медленнее.",
    prof_bias=["veteran"])
add("empty_hands", ["scared", "uneasy"], ["fear"],
    "Пустые руки рядом с мертвецами — голый неправильный холод.")
add("stone_please", ["scared"], ["wish"],
    "Хоть бы камень под ногами. Что угодно твёрдое.")
add("heart_drum", ["scared", "panic"], ["body"],
    "Сердце отбивает марш. Заткнись, я считаю.")
add("spit_hate", ["combat", "scared"], ["hate"],
    "Плевать. Сдохни уже.")
add("pack_press", ["uneasy", "scared"], ["fear"],
    "Давят числом. Как очередь в ад.")
add("whisper_budget", ["uneasy"], ["fear", "joke"],
    "Бюджет шума на сегодня исчерпан.")
add("window_wrong", ["uneasy"], ["fear"],
    "Окно слишком тихое. Так не бывает.")
add("blood_trail_not_mine", ["uneasy", "scared"], ["fear"],
    "Кровавый след. Свежий. Не мой. Пока.")
add("door_half", ["uneasy"], ["fear"],
    "Дверь приоткрыта. Кто-то вышел… или ждёт.")
add("infected_yet", ["uneasy", "scared"], ["fear", "body"],
    "Уже заражён… или ещё нет?")
add("better_not", ["uneasy", "calm"], ["wonder"],
    "Лучше не знать, кто ещё жив.")
add("nightmare_short", ["scared", "panic"], ["fear"],
    "Ну и кошмар!")
add("please_not_today", ["scared", "uneasy"], ["fear"],
    "Только не сегодня. Ну же.")
add("name_out_loud", ["scared", "panic"], ["fear"],
    "Имя. Скажи своё имя. Ты ещё ты.")
add("soft_dark_enough", ["death", "scared"], ["soft_dark"],
    "Может, хватит… просто хватит.", soft_dark=True)
add("soft_dark_empty", ["death"], ["soft_dark"],
    "Пусто. Как будто выключили свет внутри.", soft_dark=True)
add("bleed_warm", ["scared", "death"], ["fear", "body"],
    "Тепло и мокро. Это плохо.")
add("cop_habit", ["combat"], ["memory", "joke"],
    "Хочется крикнуть «полиция». Смешно.",
    prof_bias=["policeofficer"])
add("badge_ghost", ["combat", "scared"], ["memory"],
    "Жетон в кармане. Власть кончилась раньше патронов.",
    prof_bias=["policeofficer"])
add("veteran_breath", ["combat", "scared"], ["memory"],
    "Дыши как учили. Старый рефлекс лучше нового страха.",
    prof_bias=["veteran"])
add("swing_count", ["combat"], ["joke"],
    "Раз. Два. Три. Как в зале, только ставки выше.")
add("ugly_pretty", ["combat"], ["zombie", "joke"],
    "Без одежды… мозг, серьёзно?")
add("she_pretty", ["combat"], ["zombie", "joke"],
    "Красивая была. До.", gender="male")
add("he_handsome", ["combat"], ["zombie", "joke"],
    "Красавчик. Жаль, зубы не для улыбок.", gender="female")
add("tar_shadow", ["scared", "uneasy"], ["fear"],
    "Тень в шляпе. Человек? Или уже нет.")
add("map_lies", ["uneasy"], ["joke"],
    "Карта врёт. Или город съехал с катушек.")
add("radio_static", ["uneasy", "media"], ["fear"],
    "Шум между станциями. Как чужое дыхание.")
add("car_alarm_head", ["uneasy"], ["memory", "fear"],
    "Сигнализация в голове сама. Спасибо, нервы.")
add("fever_check", ["uneasy"], ["fear", "body"],
    "Лоб горячий или кажется? Кажется. Наверное.")
add("mirror_avoid", ["uneasy"], ["fear"],
    "В зеркало лучше не смотреть.")
add("footsteps_mine", ["uneasy"], ["fear"],
    "Шаги. Мои? Чужие?")
add("quiet_jump", ["uneasy"], ["fear"],
    "Слишком тихо. В кино так перед прыжком.")
add("pack_rats", ["scared", "combat"], ["hate", "joke"],
    "Как тараканы из-под плинтуса — только зубастые.")
add("drill_targets", ["scared", "combat"], ["memory", "hate"],
    "Как на учениях — только мишени в штатском.",
    prof_bias=["veteran"])
add("hound_tail", ["scared", "death"], ["hate"],
    "Гончие на хвосте. Сука.")
add("two_wont_quit", ["scared", "death"], ["hate"],
    "Эти двое не отстанут. Сердце как отбой.")
add("spit_world", ["death", "scared"], ["hate"],
    "Гори оно всё.")
add("ex_in_horde", ["uneasy", "combat"], ["zombie", "joke"],
    "Бывшая в этой орде? Чёрт, даже мёртвые достают.")
add("no_smell_pack", ["scared", "death"], ["fear", "joke"],
    "Стая без запаха. Хуже.")
add("faster_damn", ["death", "panic"], ["fear"],
    "Чёрт, быстрее!")
add("cold_on_heart", ["death", "scared"], ["fear", "body"],
    "На сердце — холод.")
add("no_command", ["scared", "combat"], ["hate"],
    "Стая без команды. Терпеть не могу.")
add("burn_it", ["death", "scared"], ["hate"],
    "Сдохните уже.")
add("jaw_double", ["scared", "death"], ["body"],
    "В глазах двоится. Держись.")
add("vomit_threat", ["scared"], ["body", "joke"],
    "Сейчас рвота — только этого не хватало.")
add("scope_show", ["scared", "combat"], ["guns", "hate"],
    "Покажу, что значит попасть под прицел.",
    prof_bias=["veteran", "policeofficer"])
add("breakfast_late", ["uneasy", "combat"], ["joke", "hate"],
    "Как будто я им завтрак проспал.")
add("earth_shake", ["scared", "combat"], ["fear"],
    "Земля будто дрожит от их торопливости.")
add("waterhole", ["combat", "scared"], ["joke"],
    "Как стадо к водопою. Только я — вода.")
add("formation", ["combat", "scared"], ["memory", "joke"],
    "Как рота на построение. Без командира.",
    prof_bias=["veteran"])
add("three_left", ["death", "scared"], ["fear"],
    "Три твари. Всё, хана?")
add("blood_drums", ["death", "scared"], ["body"],
    "Кровь стучит. Громче мыслей.")
add("shoot_or_bolt", ["death", "combat"], ["guns"],
    "Стрелять или рвать когти?")
add("wont_quit", ["death", "scared"], ["hate"],
    "Не отстанут. Сука.")
add("first_shot_lie", ["scared", "combat"], ["guns"],
    "После первого выстрела не сдохнут. Знаю.")
add("minefield_naked", ["scared"], ["fear"],
    "Безоружный — как голый на минном поле.")
add("hate_running_me", ["death", "scared"], ["hate", "body"],
    "Ненавижу, когда ноги решают за меня.")
add("iraq_echo", ["scared", "death"], ["memory"],
    "Будто снова там. Только другие монстры.",
    prof_bias=["veteran"])
add("afghan_bite", ["scared", "combat"], ["memory", "joke"],
    "Там стреляли. Тут кусают. Обмен хуже.",
    prof_bias=["veteran"])
add("patrol_worse", ["scared"], ["memory", "smell"],
    "Гнилое дыхание. Хуже любого патруля.",
    prof_bias=["veteran", "policeofficer"])
add("plinth_rats", ["combat", "scared"], ["hate"],
    "Зубастые из щелей. Давите их.")
add("no_trip", ["combat", "scared"], ["hate"],
    "Даже не спотыкаются, твари.")
add("show_me", ["combat"], ["hate", "swagger"],
    "Ну давай. Покажи зубы.")
add("keep_count", ["combat", "scared"], ["fear"],
    "Считай их. Потом себя.")
add("door_slam_wish", ["scared", "uneasy"], ["wish"],
    "Хоть бы дверь. Любая дверь.")
add("glass_edge", ["scared", "uneasy"], ["fear"],
    "Стекло под ногами. Шум — смертный грех.")
add("alley_trap", ["scared"], ["fear"],
    "Переулок жмёт. Выход один — сквозь них.")
add("roof_wish", ["scared", "uneasy"], ["wish"],
    "Крыша. Лестница. Что угодно выше зубов.")
add("siren_head", ["scared", "uneasy"], ["fear"],
    "В ушах сирена, которой нет.")
add("grip_slip", ["combat", "scared"], ["body"],
    "Руки потные. Хват врёт.")
add("last_clip", ["combat", "death"], ["guns"],
    "Последний магазин. Не думай.")
add("bayonet_mind", ["combat"], ["memory"],
    "Штык в голове — привычка сильнее страха.",
    prof_bias=["veteran"])
add("civvies_wrong", ["scared", "combat"], ["fear"],
    "Одежда гражданская. Глаза — нет.")
add("wedding_ring_zed", ["uneasy", "combat"], ["regret"],
    "Кольцо на гнилом пальце. Не смотри.")
add("kid_shoe", ["scared", "uneasy"], ["fear", "regret"],
    "Детский кед. Мозг, заткнись.")
add("laugh_wrong", ["scared", "combat"], ["joke"],
    "Хочется ржать. Плохой момент.")
add("prayer_half", ["scared", "death"], ["fear"],
    "Молитва на половине слова. Хватит.")
add("spit_copper", ["combat"], ["body"],
    "Медь во рту. Знакомо.")
add("shoulder_check", ["combat", "scared"], ["body"],
    "Плечо ноет. Потом разберёмся.")
add("crowd_push", ["panic", "scared"], ["fear"],
    "Давят. Воздуха нет.")
add("exit_left", ["scared", "uneasy"], ["fear"],
    "Выход слева. Наверное. Наверное.")
add("bite_lottery", ["uneasy", "scared"], ["fear"],
    "Укус — лотерея. Не хочу билет.")
add("desensitized_note", ["combat", "scared"], ["joke"],
    "Должен бы орать. Внутри — тишина.",
    prof_bias=["veteran"])

out = Path(__file__).with_name("combat_monologues.json")
out.write_text(
    json.dumps({"version": 1, "monologues": entries}, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print(f"wrote {len(entries)} to {out}")
assert len(entries) >= 80
