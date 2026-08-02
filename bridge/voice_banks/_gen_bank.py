# -*- coding: utf-8 -*-
"""One-shot generator for monologues.json — run then delete if desired."""
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


# CALM memory / regret / romance
add("beach_jenny_m", ["calm"], ["memory", "regret", "romance"],
    "Вот бы снова с Дженни на том пляже… эээх.",
    "Back on that beach with Jenny… damn.", "male")
add("johnny_car_f", ["calm"], ["memory", "regret", "romance"],
    "Было классно там с Джонни в его тачке… дорога, скорость, секс, дайнеры… эээх.",
    "Johnny and that car… road, speed, sex, diners… damn.", "female")
add("wife_miss_m", ["calm"], ["memory", "regret", "romance"],
    "Жена моя… как же тебя не хватает.", "God, I miss my wife.", "male")
add("husband_miss_f", ["calm"], ["memory", "regret", "romance"],
    "Муж мой… где ты сейчас, а?", "Where are you now, love?", "female")
add("dad_food", ["calm", "uneasy"], ["memory", "advice"],
    "Как говорил отец — держись поближе к еде.", "Dad said: stay close to the food.")
add("mom_keys", ["calm"], ["memory"], "Мама всегда кричала: ключи на крючок! А я… ну да.")
add("first_paycheck", ["calm"], ["memory"],
    "Первая зарплата. Пиво. Глупый и счастливый. Кажется, это был другой человек.")
add("highschool_dance", ["calm"], ["memory", "romance"],
    "Выпускной. Ужасный костюм. И всё равно улыбался как дурак.")
add("ex_voicemail", ["calm"], ["memory", "regret"],
    "До сих пор помню её голос на автоответчике. Смешно, да?")
add("camping_trip", ["calm"], ["memory"],
    "Тот кемпинг без зомби. Комары были главным врагом. Золотые времена.")
add("church_coffee", ["calm"], ["memory"],
    "Церковный кофе был дрянь. А я бы сейчас выпил ведро.")
add("brother_bet", ["calm"], ["memory", "joke"],
    "Брат спорил, что я не доживу до тридцати. Очко ему… почти.")
add("sister_ok", ["calm", "media"], ["memory"],
    "Сестра… лишь бы она жива. Остальное мелочи.")
add("dog_name", ["calm"], ["memory", "regret"],
    "Барни. Ты бы облаял всю эту орду. Не хватает тебя, псина.")
add("wedding_song", ["calm"], ["memory", "romance"],
    "Та песня на свадьбе… почему она сейчас в голове?")
add("almost_quit_job", ["calm"], ["memory", "regret"],
    "Чуть не уволился за неделю до всего. Ха. Планы.")
add("last_normal_friday", ["calm"], ["memory"],
    "Последняя нормальная пятница. Бары. Сплетни. Никто не знал.")
add("teacher_crush", ["calm"], ["memory", "joke"],
    "В школе влюблялся в учительницу. Сейчас бы она меня укусила. Ирония.")
add("grandma_soup", ["calm"], ["memory"], "Бабушкин борщ. Не выживание — религия.")
add("old_apartment", ["calm"], ["memory"],
    "Старая квартира. Соседи сверху. Теперь бы обнял даже их.")

# CALM jokes / media / whimsy
add("rob_supermarket", ["calm"], ["joke", "wish"],
    "Всегда хотел ограбить супермаркет. Ну… технически сейчас можно.")
add("guns_love", ["calm", "combat"], ["joke", "guns"],
    "Пушки, пушки… как же я люблю пушки.",
    prof_bias=["policeofficer", "veteran", "securityguard"])
add("dress_look", ["calm"], ["joke", "outfit"],
    "Ого, женское платье. Как я в нём буду выглядеть?", gender="male")
add("car_start", ["calm", "uneasy"], ["wish", "car"],
    "Интересно, та тачка заведётся?")
add("anyone_alive", ["calm", "uneasy"], ["wonder"],
    "Интересно, есть кто живой в этом городе… или лучше не надо.")
add("walk_or_die", ["calm", "uneasy"], ["joke"],
    "Прогулка или смерть? Подбрасываю монетку в голове.")
add("zombie_movie_wrong", ["calm"], ["joke", "zombie_media"],
    "В кино бегали быстрее. Обман рекламы.")
add("headshot_rules", ["calm", "combat"], ["joke", "zombie_media"],
    "Правило номер один: в голову. Спасибо, Голливуд… иногда.")
add("dawn_of", ["calm"], ["zombie_media"],
    "«Рассвет мертвецов». Не думал, что буду жить в сиквеле.")
add("shopping_cart_armor", ["calm"], ["joke"],
    "Тележка из магазина — броня бедняка. Модно.")
add("canned_beans_poem", ["calm"], ["joke", "food"], "Ода банке фасоли. Сонеты позже.")
add("toilet_paper_war", ["calm"], ["joke", "memory"],
    "Люди дрались за туалетную бумагу. Теперь за патроны. Прогресс.")
add("gps_useless", ["calm"], ["joke"], "GPS говорит: сверните… в ад. Понял, спасибо.")
add("influencer_dead", ["calm"], ["joke"], "Интересно, блогеры тоже стали… контентом.")
add("netflix_and", ["calm"], ["joke", "memory"],
    "Netflix and chill. Теперь просто chill и не умереть.")
add("diet_starts", ["calm"], ["joke"],
    "Диета «конец света» работает. Талия рада, душа нет.")
add("monday_forever", ["calm"], ["joke"],
    "Вечный понедельник. Даже апокалипсис не отменил.")
add("horoscope", ["calm"], ["joke"],
    "Гороскоп: сегодня вас могут съесть. Вау, точность.")
add("lottery_ticket", ["calm"], ["memory", "joke"],
    "Лотерейный билет в кармане. Джекпот уже не тот.")
add("selfie_stick", ["calm"], ["joke"], "Селфи-палка. Идеальное оружие… для стыда.")

# CALM body / desire
add("shave_itch_m", ["calm"], ["body", "joke"],
    "Как бы лобок побрить — чешется ужасно.", gender="male")
add("legs_shave_f", ["calm"], ["body", "joke"],
    "Ноги бы побрить. Апокалипсис — не оправдание чесаться.", gender="female")
add("cold_shower_miss", ["calm"], ["wish", "body"],
    "Холодный душ. Просто душ. Я не прошу пятизвёздочный спа.")
add("deodorant_fantasy", ["calm"], ["wish", "body"],
    "Дезодорант. Один пшик — и я снова человек.")
add("pizza_dream", ["calm"], ["wish", "food"],
    "Пицца. Горячая. Сыр тянется. Мозг, хватит пытать.")
add("cigarette_break", ["calm", "uneasy"], ["wish"],
    "Перекур без сирены. Роскошь королей.")
add("coffee_real", ["calm"], ["wish", "food"],
    "Настоящий кофе, не этот… бурп из банки.")
add("clean_sheets", ["calm"], ["wish"], "Чистые простыни. Я готов убить за это. Почти.")
add("toothpaste", ["calm"], ["wish", "body"],
    "Зубная паста со вкусом мяты, а не отчаяния.")
add("haircut", ["calm"], ["body", "joke"],
    "Стрижка. Выгляжу как куст, переживший ураган.")

# UNEASY
add("zombie_looks_boss", ["uneasy", "combat", "scared"], ["zombie", "joke"],
    "Этот упырь похож на моего начальника. Даже улучшение.")
add("zombie_looks_neighbor", ["uneasy", "combat"], ["zombie", "joke"],
    "Сосед с третьего. Узнал по халату. Привет… нет.")
add("zombie_looks_ex", ["uneasy", "combat"], ["zombie", "regret"],
    "Бывшая? Серьёзно? Вселенная троллит.")
add("better_not_know", ["uneasy", "calm"], ["wonder"],
    "Лучше не знать, кто ещё жив. Надежда кусается.")
add("infected_yet", ["uneasy", "scared"], ["fear", "body"],
    "Интересно, я уже заражён… или ещё нет?")
add("branch_snap", ["uneasy", "scared"], ["fear"],
    "Ветка хрустнула — и я замер. Даже не дыши.")
add("wet_foreheads", ["uneasy", "scared", "combat"], ["fear", "zombie"],
    "Слышу их — даже мокрые лбы хлюпают. Хоть бы один споткнулся.")
add("smell_mold", ["uneasy", "scared"], ["fear"],
    "Вонь уже в горле, как плесень. Мелькни ещё, падла.")
add("window_wrong", ["uneasy"], ["fear"], "Окно слишком тихое. Окна так не бывают.")
add("footsteps_mine", ["uneasy"], ["fear"],
    "Шаги. Мои? Чужие? Сердце, заткнись, я считаю.")
add("mirror_avoid", ["uneasy", "calm"], ["fear", "body"],
    "В зеркало лучше не смотреть. Там кто-то уставший.")
add("fever_check", ["uneasy"], ["fear", "body"],
    "Лоб горячий или мне кажется? Кажется. Наверное. Блин.")
add("door_half", ["uneasy"], ["fear"], "Дверь приоткрыта. Кто-то вышел… или ждёт.")
add("quiet_too_quiet", ["uneasy"], ["fear"],
    "Слишком тихо. В кино так перед прыжком.")
add("blood_trail", ["uneasy"], ["fear"], "Кровавый след. Свежий. Не мой. Пока.")
add("car_alarm_memory", ["uneasy"], ["memory", "fear"],
    "Автосигнализация в голове играет сама. Спасибо, нервы.")
add("map_lies", ["uneasy", "calm"], ["joke"],
    "Карта врёт. Или город съехал с катушек.")
add("radio_static_fear", ["uneasy", "media"], ["fear", "media"],
    "Шум в эфире. Как будто кто-то дышит между станциями.")
add("shadow_hat", ["uneasy"], ["fear"], "Тень в шляпе. Человек? Или уже нет.")
add("count_ammo_mind", ["uneasy", "combat"], ["guns"],
    "Считаю патроны в уме. Цифры утешают хуже молитвы.",
    prof_bias=["policeofficer", "veteran"])

# SCARED / PANIC / DEATH
add("nightmare_short", ["scared", "panic"], ["fear"], "Ну и кошмар!")
add("dont_breathe", ["scared", "panic"], ["fear"], "Не дыши. Не сейчас. Потом.")
add("teeth_close", ["scared", "panic", "death"], ["fear", "zombie"],
    "Зубы слишком близко. Нет-нет-нет.")
add("run_legs", ["scared", "panic"], ["fear"], "Ноги, работайте. Просто работайте.")
add("hate_them", ["scared", "combat", "panic"], ["hate"],
    "Ненавижу. Каждого. Особенно этого.")
add("please_not_today", ["scared", "uneasy"], ["fear"], "Только не сегодня. Ну же.")
add("soft_dark_enough", ["death", "scared"], ["soft_dark", "regret"],
    "Может, хватит… просто хватит.", soft_dark=True)
add("soft_dark_empty", ["death"], ["soft_dark"],
    "Пусто. Как будто выключили свет внутри.", soft_dark=True)
add("soft_dark_maybe", ["death", "scared"], ["soft_dark"],
    "Может, пора… закончить? Мимолётная дрянь мысли.", soft_dark=True)
add("soft_dark_joke", ["death", "calm"], ["soft_dark", "joke"],
    "Конец света, а я всё ещё прокрастинирую умирать.", soft_dark=True)
add("bleed_warm", ["scared", "death"], ["fear", "body"],
    "Тепло и мокро. Это плохо. Это очень плохо.")
add("vision_tunnel", ["panic", "death"], ["fear"], "Туннель вместо мира. Держись.")
add("name_out_loud", ["scared", "panic"], ["fear"],
    "Имя. Скажи своё имя. Ты ещё ты.")
add("gun_jam_fear", ["scared", "combat"], ["guns", "fear"],
    "Только не клин. Только не сейчас.")
add("crowd_numbers", ["scared", "panic"], ["fear", "zombie"],
    "Их слишком много. Математика против меня.")

# COMBAT
add("trip_please", ["combat", "scared"], ["hate", "zombie"], "Споткнись уже, падаль.")
add("ugly_attractive", ["combat", "calm"], ["zombie", "joke"],
    "Этот зомби без одежды… выглядел вполне себе. Мозг, серьёзно?")
add("she_was_pretty", ["combat"], ["zombie", "joke"],
    "Она выглядела привлекательно. До того как… ну.", gender="male")
add("he_was_handsome", ["combat"], ["zombie", "joke"],
    "Красавчик был. Жаль, зубы теперь не для улыбок.", gender="female")
add("swing_count", ["combat"], ["joke"],
    "Раз. Два. Три. Как в зале, только ставки выше.")
add("cop_habit", ["combat", "calm"], ["memory"],
    "Привычка кричать «полиция!» ещё жива. Смешно.",
    prof_bias=["policeofficer"])
add("badge_ghost", ["combat", "calm"], ["memory", "regret"],
    "Жетон в кармане. Власть закончилась раньше патронов.",
    prof_bias=["policeofficer"])
add("veteran_breath", ["combat", "scared"], ["memory"],
    "Дыши как учили. Старый рефлекс лучше нового страха.",
    prof_bias=["veteran"])
add("kitchen_knife_romance", ["combat", "calm"], ["joke"],
    "Кухонный нож — мой новый роман. Токсичный.")
add("reload_prayer", ["combat"], ["guns"],
    "Перезарядка как молитва. Короткая. Громкая.")

# MEDIA
add("media_liar", ["media", "calm", "uneasy"], ["media", "joke"],
    "Эфир врёт красиво. Как всегда.")
add("media_miss_hosts", ["media", "calm"], ["media", "memory"],
    "Ведущий ещё жив в моей голове. Глупо.")
add("media_commercial", ["media", "calm"], ["media", "joke"],
    "Реклама в апокалипсисе. Капитализм не сдаётся.")
add("media_weather", ["media", "calm"], ["media"],
    "Погода по ящику. Как будто это главное.")
add("media_music", ["media", "calm"], ["media", "memory"],
    "Музыка из динамика — и на секунду мир нормальный.")
add("media_emergency", ["media", "uneasy", "scared"], ["media", "fear"],
    "Экстренный тон. Спасибо, я уже в курсе.")
add("media_argue", ["media", "calm"], ["media"],
    "Да ну вас. Вы там не видите того, что вижу я.")
add("media_believe", ["media", "uneasy"], ["media"],
    "А вдруг они правы? А вдруг нет?")
add("media_volume", ["media", "uneasy"], ["media", "fear"],
    "Громко. Слишком громко для мёртвых ушей снаружи.")
add("media_static_joke", ["media", "calm"], ["media", "joke"],
    "Шумы эфира — лучший стендап сезона.")

# MORE calm fill
more = [
    ("ice_cream_truck", ["calm"], ["memory"], "Машина с мороженым. Мелодия до сих пор в кости."),
    ("library_fine", ["calm"], ["joke", "memory"], "Просроченные книги в библиотеке. Штраф уже не взыщут."),
    ("gym_membership", ["calm"], ["joke"], "Абонемент в зал. Самый дорогой бумажный труп."),
    ("plant_died", ["calm"], ["joke", "regret"], "Комнатный цветок я убил ещё до орды. Тренировка."),
    ("neighbor_bbq", ["calm"], ["memory"], "Запах чужого барбекю по воскресеньям. Жестоко вспоминать."),
    ("train_delay", ["calm"], ["memory", "joke"], "Поезд опаздывал на двадцать минут. Какой милый кризис."),
    ("password_123", ["calm"], ["joke"], "Пароль был 123456. Цифровая цивилизация заслужила конец."),
    ("spam_email", ["calm"], ["joke"], "Спам обещал увеличить… всё. Теперь спам молчит. Победа."),
    ("office_cake", ["calm"], ["memory"], "Офисный торт «с днём рождения». Картон и радость."),
    ("traffic_jam_miss", ["calm"], ["memory", "joke"], "Пробка. Я скучаю по злости на светофор."),
    ("beach_jenny_alt", ["calm"], ["memory", "romance"], "Дженни смеялась громче волн. Глупо. Красиво."),
    ("johnny_diner_f", ["calm"], ["memory", "romance"], "Джонни заказывал мне панкейки в три ночи. Святой грешник."),
    ("ring_finger", ["calm"], ["regret", "romance"], "Кольцо жмёт. Или это совесть."),
    ("kid_laugh", ["calm"], ["memory", "regret"], "Детский смех во дворе. Редко вспоминаю — больно."),
    ("fishing_lie", ["calm"], ["memory", "joke"], "Рыба была вот такая. Ложь выживает дольше рыбы."),
    ("concert_ticket", ["calm"], ["memory"], "Билет на концерт. Дата прошла. Группа… кто знает."),
    ("soda_can_cold", ["calm"], ["wish", "food"], "Холодная кола. Банка потеет. Я тоже, но от другого."),
    ("board_game_night", ["calm"], ["memory"], "Вечер настолок. Кто-то читерил. Мир был справедлив иначе."),
    ("umbrella_left", ["calm"], ["joke"], "Зонт дома. Классика. Дождь и характер не меняются."),
    ("socks_pair", ["calm"], ["joke"], "Парные носки — редкий лут эндгейма."),
    ("church_bell", ["calm"], ["memory"], "Колокол. Раньше звал. Теперь просто звук."),
    ("taxi_smell", ["calm"], ["memory"], "Запах такси: ёлка и чужие тайны."),
    ("midnight_fries", ["calm"], ["memory", "food"], "Картошка фри в полночь. Цивилизация в бумажном кульке."),
    ("photo_wallet", ["calm"], ["memory", "regret"], "Фото в кошельке. Улыбки как из другого вида."),
    ("new_years_kiss", ["calm"], ["memory", "romance"], "Поцелуй в Новый год. Хлопушки. Обещания. Ложь приятная."),
    ("rain_on_tin", ["calm"], ["memory"], "Дождь по жести. Усыпляло лучше таблеток."),
    ("cat_judge", ["calm"], ["joke", "memory"], "Кот смотрел с осуждением. Был прав."),
    ("subway_busker", ["calm"], ["memory"], "Музыкант в метро. Шляпа с мелочью. Искусство без Wi‑Fi."),
    ("cheap_wine", ["calm"], ["memory", "joke"], "Дешёвое вино казалось хорошим. Оптимизм алкоголя."),
    ("park_bench", ["calm"], ["memory"], "Скамейка в парке. Кормить голубей. Глупая роскошь."),
    ("vending_jam", ["calm"], ["joke", "memory"], "Автомат заело чипсы. Тогда это было трагедией."),
    ("escalator_fear", ["calm"], ["joke"], "Эскалатор ломался — и мир казался хрупким. Ха."),
    ("airport_goodbye", ["calm"], ["memory", "regret"], "Прощание в аэропорту. Чемоданы. «Увидимся»."),
    ("text_unsent", ["calm"], ["regret"], "Неотправленное сообщение. Курсор мигал. Я струсил."),
    ("laundry_quarter", ["calm"], ["joke", "memory"], "Четвертак для стиралки. Экономика простого счастья."),
    ("comic_issue", ["calm"], ["memory", "joke"], "Недочитанный комикс. Клиффхэнгер навсегда."),
    ("bike_chain", ["calm"], ["memory"], "Цепь велосипеда. Смазка. Свобода на двух колёсах."),
    ("skate_scar", ["calm"], ["memory", "joke"], "Шрам от скейта. Доказательство, что я был глупым и живым."),
    ("mall_fountain", ["calm"], ["memory"], "Фонтан в молле. Желания за монетки. Инфляция мечты."),
    ("food_court", ["calm"], ["memory", "food"], "Фуд-корт. Выбор из десяти зол. Рай."),
    ("storm_power", ["calm"], ["memory"], "Гроза вырубила свет — и все стали добрее на час."),
    ("flashlight_batteries", ["calm", "uneasy"], ["joke"], "Батарейки. Всегда заканчиваются в худший момент. Закон."),
    ("whistle_tune", ["calm"], ["joke"], "Свистнуть бы мотив… и не привлечь орду. Компромисс."),
    ("card_deck", ["calm"], ["joke"], "Колода карт. Пасьянс против безумия. Счёт 0:1."),
    ("dice_luck", ["calm"], ["joke"], "Кубик в кармане. Удача — хобби для оптимистов."),
    ("crosswalk_button", ["calm"], ["joke", "memory"], "Кнопка перехода. Ждал зелёный. Милый ритуал."),
    ("elevator_music", ["calm", "media"], ["memory", "joke"], "Музыка в лифте. Пытка вежливостью."),
    ("hold_music", ["media", "calm"], ["media", "joke"], "Музыка ожидания на линии. Ад уже был придуман."),
    ("sports_score", ["calm", "media"], ["memory", "joke"], "Счёт матча. Кто выиграл — уже не важно. Или важно слишком."),
    ("lottery_dream_house", ["calm"], ["wish", "joke"], "Выиграл бы — купил дом у моря. Море подождёт."),
    ("learn_guitar", ["calm"], ["regret", "wish"], "Всё хотел выучить гитару. Струны есть. Времени… было."),
    ("spanish_class", ["calm"], ["memory", "joke"], "Два года испанского. Помню «hola» и панику."),
    ("drive_thru", ["calm"], ["memory", "food"], "Окошко драйв-thru. «И картошку?» — да. Всегда да."),
    ("hotel_ice", ["calm"], ["memory"], "Лёд из автомата в отеле. Роскошь щёлкающих кубиков."),
    ("minibar_guilt", ["calm"], ["memory", "joke"], "Мини-бар. Вина и стыд по прайсу."),
    ("sunday_paper", ["calm"], ["memory"], "Воскресная газета. Кроссворд. Мир решаемый."),
    ("comic_villain", ["calm", "combat"], ["zombie_media", "joke"], "Злодей в комиксах хотя бы монологил. Эти только жуют."),
    ("slow_zombies_thank", ["calm", "combat"], ["zombie_media", "joke"], "Слава богу, они медленные. Голливуд хотя бы это угадал."),
    ("bite_rules_argue", ["uneasy", "scared"], ["zombie_media", "fear"], "Укус — конец? Или лотерея? Не хочу проверять."),
    ("safehouse_fantasy", ["calm"], ["wish"], "Безопасный дом. Забор. Тишина. Сон без ножа под подушкой."),
    ("garden_tomato", ["calm"], ["wish", "food"], "Свои помидоры. Красные. Настоящие. Мечта фермера-любителя."),
    ("hot_water_bottle", ["calm"], ["wish"], "Тёплая грелка. Звучит жалко. Звучит идеально."),
    ("birthday_candle", ["calm"], ["memory", "regret"], "Свеча на торте. Загадал глупое. Исполнилось чужое."),
    ("apology_unsaid", ["calm"], ["regret"], "Так и не извинился. Теперь аудитория — вороны."),
    ("thank_you_unsaid", ["calm"], ["regret"], "Не сказал «спасибо». Мелочь. Тяжёлая."),
    ("enemy_forgiven", ["calm"], ["regret", "joke"], "Простил бы того урода из школы. Наверное. Почти."),
    ("clock_tick_miss", ["calm"], ["memory"], "Тиканье часов. Сейчас время измеряется шорохами."),
    ("dance_kitchen", ["calm"], ["memory", "romance"], "Танцевали на кухне босиком. Музыка из телефона."),
    ("stupid_bravery", ["combat", "scared"], ["joke"], "Глупая храбрость — мой основной навык. И минус."),
    ("inventory_tetris", ["calm"], ["joke"], "Тетрис в рюкзаке. Побеждаю пространство, проигрываю жизнь."),
    ("noise_budget", ["uneasy", "calm"], ["joke"], "Бюджет шума на сегодня исчерпан. Шёпот только."),
    ("lucky_sock", ["calm", "combat"], ["joke"], "Счастливый носок. Наука выживания."),
    ("knock_wood", ["uneasy", "calm"], ["joke"], "Постучать по дереву. Суеверие дешевле патронов."),
    ("city_skyline", ["calm"], ["wonder"], "Силуэт города. Красивый труп."),
    ("highway_empty", ["calm", "uneasy"], ["wonder"], "Пустое шоссе. Мечта водителя. Кошмар пешехода."),
    ("billboard_smile", ["calm"], ["joke"], "Биллборд всё ещё улыбается. Профессионал."),
    ("church_lock", ["calm", "uneasy"], ["wonder"], "Церковь на замке. Даже богу выходной?"),
    ("school_yard", ["calm"], ["memory", "regret"], "Школьный двор. Мел. Крик. Эхо."),
    ("gas_station_beef", ["calm"], ["memory", "food"], "Вяленое мясо с заправки. Гурманы бы плакали. Я — нет."),
    ("map_coffee_stain", ["calm"], ["joke"], "Карта в кофейных пятнах. Навигация по пятнам."),
    ("whiskey_one", ["calm"], ["wish", "joke"], "Один глоток виски. Для храбрости. Или для честности."),
    ("lullaby_wrong", ["calm", "scared"], ["memory"], "Колыбельная сама всплыла. Голос мамы. Держись."),
    ("end_title_card", ["calm", "death"], ["zombie_media", "joke"], "Титры бы уже пошли. Я всё ещё в кадре. Ошибка монтажа."),
    ("sunrise_shift", ["calm"], ["memory"], "Смена до рассвета. Кофе и тупые шутки. Почти семья."),
    ("mechanic_hands", ["calm"], ["memory"], "Руки в мазуте — честнее любого галстука."),
    ("cook_knife_miss", ["calm"], ["memory", "food"], "Настоящая кухня. Запахи. Не банки."),
    ("farm_morning", ["calm"], ["memory"], "Утро на ферме. Туман и работа. Проще, чем это."),
    ("final_girl_m", ["calm", "scared"], ["zombie_media", "joke"], "Финальная девушка выживает. Я не девушка. Проблема."),
    ("final_girl_f", ["calm", "scared"], ["zombie_media"], "Финальная девушка. Ок. Давайте по канону."),
    ("perfume_ghost_m", ["calm"], ["memory", "romance"], "Её духи в лифте. Призрак нормальной жизни."),
    ("cologne_ghost_f", ["calm"], ["memory", "romance"], "Его одеколон на куртке. Глупо держать."),
    ("three_days_beard", ["calm"], ["body", "joke"], "Борода трёх дней. Стиль «не выбирал»."),
    ("makeup_smudge_f", ["calm"], ["body", "joke"], "Тушь размазалась ещё в прошлой жизни."),
    ("hospital_smell", ["uneasy", "calm"], ["memory", "fear"], "Запах больницы вспоминается сам. Спасибо, мозг."),
    ("badge_number", ["calm"], ["memory"], "Номер жетона наизусть. Личность в цифрах."),
    ("boss_email", ["calm", "uneasy"], ["memory", "joke"], "Письмо от босса «срочно». Срочность переоценена."),
]

gender_map = {
    "beach_jenny_alt": "male",
    "johnny_diner_f": "female",
    "final_girl_m": "male",
    "final_girl_f": "female",
    "perfume_ghost_m": "male",
    "cologne_ghost_f": "female",
    "three_days_beard": "male",
    "makeup_smudge_f": "female",
}
prof_map = {
    "sunrise_shift": ["policeofficer", "securityguard", "fireofficer"],
    "mechanic_hands": ["mechanic"],
    "cook_knife_miss": ["chef", "burgerflipper"],
    "farm_morning": ["farmer"],
    "hospital_smell": ["nurse", "doctor"],
    "badge_number": ["policeofficer"],
}

for eid, tiers, tags, ru in more:
    add(
        eid,
        tiers,
        tags,
        ru,
        gender=gender_map.get(eid, "any"),
        prof_bias=prof_map.get(eid),
    )

out = Path(__file__).with_name("monologues.json")
out.write_text(
    json.dumps({"version": 1, "monologues": entries}, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print(f"wrote {len(entries)} to {out}")
assert len(entries) >= 100, len(entries)
ids = [e["id"] for e in entries]
assert len(ids) == len(set(ids)), "duplicate ids"
