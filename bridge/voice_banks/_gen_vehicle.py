# -*- coding: utf-8 -*-
"""Generate vehicle_monologues.json — driving / start / stall / crash scraps."""
import json
from pathlib import Path

entries = []


def add(eid, tiers, tags, ru, en=None, gender="any", soft_dark=False, trait_bias=None):
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
    if trait_bias:
        e["trait_bias"] = trait_bias
    entries.append(e)


# Start / won't start
add("come_on_girl", ["uneasy", "scared", "calm"], ["vehicle", "start"],
    "Да ну же… ну заведись.")
add("key_rattle", ["uneasy", "calm"], ["vehicle", "start"],
    "Ключ дребезжит. Мотор молчит. Классика.")
add("battery_joke", ["uneasy", "calm"], ["vehicle", "start"],
    "Аккумулятор умер раньше меня. Нечестно.")
add("hotwire_prayer", ["uneasy", "scared"], ["vehicle", "hotwire"],
    "Провода как молитва. Только без бога.")
add("click_click", ["uneasy", "scared"], ["vehicle", "start"],
    "Щёлк. Щёлк. Тишина. Сука.")
add("sunday_soft", ["calm", "uneasy"], ["vehicle", "start"],
    "Тихонько… не орём на холостых.",
    trait_bias=["SundayDriver"])
add("demon_impatient", ["uneasy", "calm"], ["vehicle", "start"],
    "Ну же, железяка. Я не для стоянок.",
    trait_bias=["SpeedDemon"])
add("caught_smug", ["calm", "uneasy"], ["vehicle", "start"],
    "Завелась. Хоть кто-то сегодня слушается.")
add("roar_flinch", ["uneasy", "calm"], ["vehicle", "start"],
    "Рёв — и внутри ёкнуло. Тише можно было?",
    trait_bias=["SundayDriver"])
add("roar_yes", ["calm", "uneasy"], ["vehicle", "start"],
    "Рёв! Вот это разговор.",
    trait_bias=["SpeedDemon"])

# Driving ambient
add("road_empty", ["calm", "uneasy"], ["vehicle", "drive"],
    "Пустая дорога. Почти как раньше — почти.")
add("wheel_hum", ["calm"], ["vehicle", "drive"],
    "Гул под колёсами. Можно дышать.")
add("mirror_check", ["uneasy", "calm"], ["vehicle", "drive"],
    "Зеркало. Опять. Привычка сильнее страха.")
add("gas_soft", ["calm", "uneasy"], ["vehicle", "drive"],
    "Газ — чуть-чуть. Не геройствуем.",
    trait_bias=["SundayDriver"])
add("gas_more", ["calm", "uneasy"], ["vehicle", "drive"],
    "Ещё газку. Мир и так тормозит.",
    trait_bias=["SpeedDemon"])
add("brake_hate", ["uneasy", "calm"], ["vehicle", "drive"],
    "Тормоза в голове громче педали.",
    trait_bias=["SpeedDemon"])
add("slowpoke_curse", ["uneasy"], ["vehicle", "drive"],
    "Кто тут ползёт? А, это я. Сознательно.",
    trait_bias=["SundayDriver"])
add("speed_fix", ["calm", "uneasy"], ["vehicle", "drive"],
    "Скорость — единственный кайф, который ещё легален.",
    trait_bias=["SpeedDemon"])
add("cabin_smell", ["calm", "uneasy"], ["vehicle", "entered"],
    "Запах салона — пыль, бензин, чужая жизнь.")
add("seat_sink", ["calm"], ["vehicle", "entered"],
    "Сел. Сиденье помнит кого-то другого.")
add("keys_pocket", ["calm", "uneasy"], ["vehicle", "entered"],
    "Ключ в кармане греет сильнее надежды.")
add("radio_dead_car", ["calm", "uneasy"], ["vehicle", "drive"],
    "Радио молчит. Хорошо — меньше сирен в голове.")
add("wipers_ghost", ["calm"], ["vehicle", "drive"],
    "Дворники без дождя. Руки сами.")
add("lane_keep", ["uneasy", "calm"], ["vehicle", "drive"],
    "Держи полосу. Хотя полос уже нет.")
add("zombie_roadkill_no", ["uneasy", "scared"], ["vehicle", "drive"],
    "Не дави их специально. Шум — налог.")
add("bumper_kiss", ["scared", "uneasy"], ["vehicle", "drive"],
    "Бампер целует куст. Живы. Пока.")

# Stall / crash / repair
add("stalled_mid", ["scared", "panic", "uneasy"], ["vehicle", "stall"],
    "Заглохла. Посреди всего. Нет-нет-нет.")
add("stall_curse", ["scared", "uneasy"], ["vehicle", "stall"],
    "Мотор сдох на ходу. Руки на ключ — молись.")
add("stall_demon", ["scared", "uneasy"], ["vehicle", "stall"],
    "Только разогнался — и тишина. Предательство.",
    trait_bias=["SpeedDemon"])
add("crash_metal", ["panic", "death", "scared"], ["vehicle", "crash"],
    "Металл орёт. Тело тоже.")
add("crash_jolt", ["panic", "scared"], ["vehicle", "crash"],
    "Удар. Зубы клац. Мир качнулся.")
add("crash_sunday", ["scared", "panic"], ["vehicle", "crash"],
    "Я же тихонько… а оно всё равно.",
    trait_bias=["SundayDriver"])
add("hood_open_pray", ["uneasy", "calm"], ["vehicle", "repair"],
    "Капот открыт. Молитва гаечным ключом.")
add("grease_mood", ["calm", "uneasy"], ["vehicle", "repair"],
    "Смазь на пальцах. Хоть чем-то занят.")
add("battery_swap_hope", ["uneasy"], ["vehicle", "repair"],
    "Батарея… ну давай, оживи эту консерву.")
add("engine_guts", ["uneasy", "calm"], ["vehicle", "repair"],
    "Кишки мотора. Знакомо и противно.")
add("tire_hiss", ["uneasy", "scared"], ["vehicle", "repair"],
    "Шина шипит. Как змея под днищем.")
add("alarm_head", ["scared", "uneasy"], ["vehicle", "alarm"],
    "Сигналка орёт. Я её ненавижу сильнее упырей.")
add("park_quiet", ["calm"], ["vehicle", "drive"],
    "Заглушить? Или пусть урчит — как кот.")
add("fuel_worry", ["uneasy", "calm"], ["vehicle", "drive"],
    "Бензин в уме. Цифра меньше покоя.")
add("window_crack", ["uneasy"], ["vehicle", "drive"],
    "Форточка на щелку. Воздух и риск.")
add("backseat_ghost", ["calm", "uneasy"], ["vehicle", "entered"],
    "На заднем кто-то «есть». Пусто. Но есть.")
add("gear_grind", ["uneasy"], ["vehicle", "drive"],
    "Передача хрустнула. Прости, железяка.")
add("night_beams", ["calm", "uneasy"], ["vehicle", "drive"],
    "Фары режут тьму. Слишком заметно. Нужно.")
add("exit_fast", ["scared", "uneasy"], ["vehicle", "exit"],
    "Выскочить. Дверь. Ноги. Не думай.")
add("engine_tick", ["calm"], ["vehicle", "drive"],
    "Тикает остывая. Как часы после смены.")

out = Path(__file__).with_name("vehicle_monologues.json")
out.write_text(
    json.dumps({"version": 1, "monologues": entries}, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print(f"wrote {len(entries)} to {out}")
assert len(entries) >= 40
