--[[
  EN micro-prompt catalog: emotion scraps, not fact instructions.
]]

DSThoughts = DSThoughts or {}
DSThoughts.PromptHooks = DSThoughts.PromptHooks or {}

local H = DSThoughts.PromptHooks

H.Defs = {
    wound_bite = {
        priority = 98, cooldown = 200,
        micro = "Bitten — swear, pray, hope it passes, or clean the wound NOW. Never narrate teeth/fangs.",
    },
    bleed_worse = {
        priority = 96, cooldown = 90,
        micro = "Warm wet spreading — hate the leak; bandage impulse OK. Not a fever essay.",
    },
    took_damage = {
        priority = 95, cooldown = 150,
        micro = "Got hurt just now — one flinch/curse. ONLY generic pain unless FACTS name a wound type. Never invent ribs/door/limb.",
    },
    fire_near = {
        priority = 94, cooldown = 60,
        micro = "Heat licking too close — lungs tight, everything smells like ending.",
    },
    zeds_chasing = {
        priority = 93, cooldown = 180,
        micro = "Dead locked on you — hate/fear scrap about THEM (smell, faces, stumble). Smell, face, stumble — not a running report.",
    },
    vehicle_alarm = {
        priority = 92, cooldown = 120,
        micro = "Siren screaming — fury at the noise, every corpse invited.",
    },
    house_alarm = {
        priority = 91, cooldown = 180,
        micro = "Alarm howling — ears ring, stupid beacon rage.",
    },
    gunshot_echo = {
        priority = 90, cooldown = 90,
        micro = "Shot still ringing — swagger or ringing-ear shock, not a report.",
    },
    veh_crash = {
        priority = 92, cooldown = 45,
        micro = "Impact — metal scream, body jolt; raw scrap, not a crash report.",
    },
    veh_stalled = {
        priority = 78, cooldown = 60,
        micro = "Engine died mid-move — curse, hope, hands on the key.",
    },
    veh_wont_start = {
        priority = 75, cooldown = 50,
        micro = "Won't turn over — dead battery joke or desperate «come on».",
    },
    veh_engine_start = {
        priority = 70, cooldown = 55,
        micro = "She caught — relief, smugness, or SundayDriver flinch at the roar.",
    },
    veh_entered = {
        priority = 48, cooldown = 80,
        micro = "Inside the cabin — smell of seats, keys, road hope.",
    },
    veh_repair_fiddle = {
        priority = 40, cooldown = 100,
        micro = "Hands in the guts of a car — wrench prayer, grease mood.",
    },
    veh_driving = {
        priority = 20, cooldown = 120,
        micro = "Behind the wheel — road, speed feel, driver-trait voice. Not inventory.",
    },

    wound_fracture = {
        priority = 88, cooldown = 90,
        micro = "Bone lies — weight on that limb feels like betrayal.",
    },
    wound_deep = {
        priority = 86, cooldown = 90,
        micro = "Open meat — ugly private fear under the sting.",
    },
    wound_scratch = {
        priority = 87, cooldown = 160,
        micro = "Scratch — sting and worry; clean impulse OK. Do not invent bite or fever.",
    },
    wound_cut = {
        priority = 87, cooldown = 160,
        micro = "Cut/laceration — sharp wet wrongness; bandage urge. Not a fever essay.",
    },
    zeds_close = {
        priority = 85, cooldown = 120,
        micro = "Rot-breath close — hate the smell, no room for clever. Not a running report.",
    },
    zeds_visible_crowd = {
        priority = 82, cooldown = 120,
        micro = "Too many dead shapes — numbers chew the nerves.",
    },
    moodle_panic_high = {
        priority = 48, cooldown = 160,
        micro = "Panic shredding thoughts into scraps and noise.",
    },
    -- Alias kept for bridge filters; prefer illness_dread / sick_* in candidates
    infection_knox = {
        priority = 84, cooldown = 480,
        micro = "Sick dread after a wound — swear, pray, hope it passes, or disinfect. No Knox label. Ban teeth/fever/electric metaphors.",
    },
    illness_dread = {
        priority = 84, cooldown = 480,
        micro = "Something wrong after a scratch/bite or rising sickness — pray/swear/hope/disinfect. Never name Knox. Ban teeth/fever-appliance metaphors.",
    },
    sick_food = {
        priority = 72, cooldown = 240,
        micro = "Food/water sickness — gut revolt, regret that meal. Not zombie fever lore.",
    },
    sick_cold = {
        priority = 68, cooldown = 300,
        micro = "Catching a cold — sniffle/ache irritation. Ordinary illness voice.",
    },
    sick_queasy = {
        priority = 80, cooldown = 360,
        micro = "Queasy/nauseous — stomach wrong, weak. Symptom only; no invented wound story.",
    },
    sick_feverish = {
        priority = 83, cooldown = 160,
        micro = "Fever / hard sickness — heat, chills, weakness, dread. Body heat OK. Ban electric/wiring metaphors and invented wounds.",
    },
    in_combat = {
        priority = 50, cooldown = 180,
        micro = "Zeds still on you — one mean scrap max, then silence. Not hit-by-hit. Do not invent a body hit.",
    },
    landed_hit_melee = {
        priority = 76, cooldown = 35,
        micro = "You connected — ugly satisfaction or ringing shock.",
    },

    moodle_pain = {
        priority = 48, cooldown = 160,
        micro = "Pain owns a lane — sharp, dull, bitching.",
    },
    moodle_bleeding = {
        priority = 48, cooldown = 160,
        micro = "Bleeding mood — sticky wrongness you can't joke away.",
    },
    moodle_injury = {
        priority = 48, cooldown = 160,
        micro = "Body not whole — it keeps reminding you.",
    },
    moodle_thirst = {
        priority = 48, cooldown = 160,
        micro = "Mouth dust-dry — thirst as irritation, not inventory line.",
    },
    moodle_hunger = {
        priority = 48, cooldown = 160,
        micro = "Hollow gut rude — hunger as mood, not checklist.",
    },
    moodle_tired = {
        priority = 48, cooldown = 160,
        micro = "Lids heavy — sleep debt collecting interest.",
    },
    wet_rain = {
        priority = 56, cooldown = 150,
        micro = "Rain soak — cold collar, slick hands, weather nags.",
    },
    wet_sweat = {
        priority = 54, cooldown = 100,
        micro = "Sweat-slick shirt from work — sticky and petty.",
    },
    smoker_craving = {
        priority = 55, cooldown = 150,
        micro = "Nicotine itch under the ribs — restless fingers.",
    },
    -- Situational trait effects (B41 full set) — fire when the trait is "on"
    trait_agoraphobic = {
        priority = 61, cooldown = 90,
        micro = "Agoraphobic outdoors — open sky wrong; wants walls/cover. Panic flavor, not a trait name.",
    },
    trait_claustrophobic = {
        priority = 61, cooldown = 90,
        micro = "Claustrophobic indoors — walls press; needs air/exit. Panic flavor, not a trait name.",
    },
    trait_hemophobic = {
        priority = 66, cooldown = 80,
        micro = "Fear of Blood — gore/blood on scene turns stomach/stress. Aversion, not clinical.",
    },
    trait_desensitized = {
        priority = 50, cooldown = 100,
        micro = "Desensitized — threat present but flat affect; dry underreact, no greenhorn scream.",
    },
    trait_cowardly = {
        priority = 60, cooldown = 75,
        micro = "Cowardly — fear spikes; escape-first scraps. Not brave talk.",
    },
    trait_brave = {
        priority = 48, cooldown = 90,
        micro = "Brave — faces it; downplays fear. Forward wording.",
    },
    trait_pacifist = {
        priority = 58, cooldown = 90,
        micro = "Pacifist — violence sits wrong; reluctant/guilty scrap about hurting.",
    },
    trait_deaf = {
        priority = 52, cooldown = 120,
        micro = "Deaf — visual/vibration only. NEVER invent hearing zombies or radio chatter.",
    },
    trait_hard_hearing = {
        priority = 46, cooldown = 100,
        micro = "Hard of Hearing — world muffled; unsure about quiet threats.",
    },
    trait_keen_hearing = {
        priority = 47, cooldown = 90,
        micro = "Keen Hearing — sound-first; soft steps/behind register early.",
    },
    trait_night_vision = {
        priority = 44, cooldown = 140,
        micro = "Cat's Eyes at night — darkness less scary; visual confidence.",
    },
    trait_short_sighted = {
        priority = 44, cooldown = 120,
        micro = "Short Sighted — far blur; squints at distant shapes.",
    },
    trait_eagle_eyed = {
        priority = 45, cooldown = 110,
        micro = "Eagle Eyed — spots distant shapes first; visual confidence.",
    },
    trait_adrenaline = {
        priority = 56, cooldown = 80,
        micro = "Adrenaline Junkie — high panic feels like fuel; restless thrill edge.",
    },
    trait_short_temper = {
        priority = 55, cooldown = 90,
        micro = "Short Temper — snap/swear fuse short; anger scrap, not a lecture.",
    },
    trait_patient = {
        priority = 40, cooldown = 140,
        micro = "Patient — steadier temper under petty stress; grit not snap.",
    },
    trait_brooding = {
        priority = 42, cooldown = 160,
        micro = "Brooding — grey mood sticks; slow to shake bad feeling.",
    },
    trait_hypochondriac = {
        priority = 62, cooldown = 80,
        micro = "Hypochondriac — scratch/illness sparks infection dread loops.",
    },
    trait_asthmatic = {
        priority = 54, cooldown = 100,
        micro = "Asthmatic — lungs complain; exertion frightens breath.",
    },
    trait_conspicuous = {
        priority = 48, cooldown = 100,
        micro = "Conspicuous — feels too visible; spotted-easily dread.",
    },
    trait_inconspicuous = {
        priority = 46, cooldown = 100,
        micro = "Inconspicuous — low-profile habit; hopes they don't see.",
    },
    trait_clumsy = {
        priority = 44, cooldown = 110,
        micro = "Clumsy — loud/awkward; self-scolds for noise or fumbling.",
    },
    trait_graceful = {
        priority = 42, cooldown = 120,
        micro = "Graceful — quiet-step self-image; hates clumsy noise.",
    },
    trait_all_thumbs = {
        priority = 40, cooldown = 140,
        micro = "All Thumbs — fiddly handling feels cursed.",
    },
    trait_dextrous = {
        priority = 38, cooldown = 160,
        micro = "Dextrous — hands feel quick; sorting ease.",
    },
    trait_unfit_body = {
        priority = 50, cooldown = 100,
        micro = "unfit/overweight body — movement/load feels punishing.",
    },
    trait_frail_body = {
        priority = 50, cooldown = 100,
        micro = "frail/underweight — body too light/weak for this.",
    },
    trait_strong_body = {
        priority = 40, cooldown = 120,
        micro = "strong/fit — confidence about strength/stamina.",
    },
    trait_hearty_appetite = {
        priority = 50, cooldown = 120,
        micro = "Hearty Appetite — hunger loud; food wants dominate.",
    },
    trait_light_eater = {
        priority = 42, cooldown = 140,
        micro = "Light Eater — hungry but milder; food less dramatic.",
    },
    trait_high_thirst = {
        priority = 50, cooldown = 100,
        micro = "High Thirst — mouth desert; water urgency.",
    },
    trait_low_thirst = {
        priority = 40, cooldown = 140,
        micro = "Low Thirst — thirsty but less dramatic.",
    },
    trait_smoker = {
        priority = 55, cooldown = 120,
        micro = "Smoker — nicotine itch / stress without a cigarette.",
    },
    trait_sleepyhead = {
        priority = 52, cooldown = 120,
        micro = "Sleepyhead/Restless Sleeper — sleep debt biting; lids heavy or wired-tired.",
    },
    trait_wakeful = {
        priority = 40, cooldown = 160,
        micro = "Wakeful — less crushed by tiredness; night shifts OK.",
    },
    trait_night_owl = {
        priority = 42, cooldown = 160,
        micro = "Night Owl — night feels natural; days would feel wrong.",
    },
    trait_thin_skinned = {
        priority = 55, cooldown = 90,
        micro = "Thin-skinned — wound feels worse; fragile skin dread.",
    },
    trait_thick_skinned = {
        priority = 45, cooldown = 100,
        micro = "Thick Skinned — shrugs the hit; tough hide talk.",
    },
    trait_slow_healer = {
        priority = 50, cooldown = 110,
        micro = "Slow Healer — injuries feel lasting; anxious about wounds.",
    },
    trait_fast_healer = {
        priority = 42, cooldown = 120,
        micro = "Fast Healer — bounce-back confidence about the wound.",
    },
    trait_weak_stomach = {
        priority = 54, cooldown = 100,
        micro = "Weak Stomach — nausea from food/gore.",
    },
    trait_iron_gut = {
        priority = 42, cooldown = 140,
        micro = "Iron Gut — shrugs food sickness; gut jokes OK.",
    },
    trait_prone_illness = {
        priority = 54, cooldown = 100,
        micro = "Prone to Illness — sickness sticks; infection dread.",
    },
    trait_resilient = {
        priority = 44, cooldown = 120,
        micro = "Resilient — toughs the illness; stubborn body talk.",
    },
    trait_outdoorsman = {
        priority = 42, cooldown = 140,
        micro = "Outdoorsy — weather is just weather; less drama about wet/cold.",
    },
    trait_sunday_driver = {
        priority = 53, cooldown = 90,
        micro = "Sunday Driver — cautious wheel; hates reckless gas; «тихонько».",
    },
    trait_speed_demon = {
        priority = 53, cooldown = 90,
        micro = "Speed Demon — impatient pedal-joy; hates crawling.",
    },
    trait_car_handy = {
        priority = 48, cooldown = 100,
        micro = "mechanic/burglar car sense — engines, hotwire, jury-rigs.",
    },
    trait_marksman = {
        priority = 50, cooldown = 90,
        micro = "Marksman — gun calm; sight picture, not panic spray.",
    },
    trait_axeman = {
        priority = 48, cooldown = 100,
        micro = "Ax-pert — axe rhythm feels natural.",
    },
    trait_brawler = {
        priority = 48, cooldown = 90,
        micro = "Brawler — fight-first close-in scrap.",
    },
    trait_unlucky = {
        priority = 40, cooldown = 160,
        micro = "Unlucky — expects things to go wrong.",
    },
    trait_lucky = {
        priority = 28, cooldown = 200,
        micro = "Lucky — half-believes odds bend their way.",
    },
    trait_disorganized = {
        priority = 36, cooldown = 180,
        micro = "Disorganized — mental clutter; where did I put that?",
    },
    trait_organized = {
        priority = 34, cooldown = 180,
        micro = "Organized — messy spaces irritate; wants order.",
    },
    trait_nutritionist = {
        priority = 40, cooldown = 140,
        micro = "Nutritionist — food as fuel math.",
    },
    trait_cook = {
        priority = 40, cooldown = 140,
        micro = "Cook — invents meals / kitchen fantasy from scraps.",
    },
    trait_slow_learner = {
        priority = 22, cooldown = 300,
        micro = "Slow Learner — needs things simple/repeated; less abstract flex.",
    },
    trait_fast_learner = {
        priority = 22, cooldown = 300,
        micro = "Fast Learner — quick mental notes when calm.",
    },
    trait_slow_reader = {
        priority = 20, cooldown = 360,
        micro = "Slow Reader — text is effort; avoid bookish flex.",
    },
    trait_fast_reader = {
        priority = 20, cooldown = 360,
        micro = "Fast Reader — comfortable with text when relevant.",
    },
    trait_light_drinker = {
        priority = 24, cooldown = 300,
        micro = "Light Drinker — alcohol hits hard if relevant; else ignore.",
    },
    trait_heavy_drinker = {
        priority = 24, cooldown = 300,
        micro = "Hardened Drinker — alcohol barely dents them if relevant.",
    },
    trait_illiterate = {
        priority = 30, cooldown = 300,
        micro = "Illiterate — never invent reading books/magazines.",
    },
    moodle_sick = {
        priority = 48, cooldown = 160,
        micro = "World tilting — gut or head turning traitor.",
    },
    no_weapon_threat = {
        priority = 64, cooldown = 60,
        micro = "Empty hands near dead — naked wrong feeling, not gear advice.",
    },

    clothes_filthy = {
        priority = 38, cooldown = 420,
        micro = "Own stink briefly registers — then mind should leave the body; one wry note max, not a laundry essay.",
    },
    clothes_bloody = {
        priority = 40, cooldown = 420,
        micro = "Blood smell on cloth — one ugly note then LOOK AWAY to room/world/joke. Not a shirt report.",
    },
    moodle_heavy_load = {
        priority = 44, cooldown = 160,
        micro = "Pack drags shoulders — every step a quiet complaint.",
    },
    moodle_hot = {
        priority = 42, cooldown = 180,
        micro = "Overheating — air too thick, temper shorter.",
    },
    moodle_cold_body = {
        priority = 43, cooldown = 180,
        micro = "Cold in the muscles — jaw tight, fingers stupid.",
    },
    moodle_unhappy = {
        priority = 40, cooldown = 200,
        micro = "Unhappiness itself is loud — grey self-pity or hollow scrap. Soft dark only, no how-to. Tone also comes from MOOD LENS on other hooks.",
    },
    moodle_bored = {
        priority = 36, cooldown = 240,
        micro = "Boredom itch — monotony louder than danger; stupid joke OK.",
    },
    no_food = {
        priority = 35, cooldown = 320,
        micro = "Empty stomach future — craving fantasy (real food memory) beats packing checklist.",
    },
    no_water = {
        priority = 36, cooldown = 300,
        micro = "Dry mouth future — think of a cold drink that used to exist, not inventory.",
    },
    moodle_stress = {
        priority = 48, cooldown = 160,
        micro = "Nerves wound tight — edged sarcasm or muttered curse.",
    },

    corpse_near = {
        priority = 32, cooldown = 240,
        micro = "A body nearby — pity, numbness, or ugly joke; not a field report.",
    },
    window_smashed = {
        priority = 30, cooldown = 240,
        micro = "Broken glass — someone came through; uneasy scrap.",
    },
    night_outdoors = {
        priority = 28, cooldown = 300,
        micro = "Night outside — ears work harder; soft unease.",
    },
    fog = {
        priority = 26, cooldown = 300,
        micro = "Fog eats distance — shapes arrive late and wrong.",
    },
    rain_outside = {
        priority = 24, cooldown = 240,
        micro = "Rain on the world — drumming nag, weather mood.",
    },
    dawn = {
        priority = 22, cooldown = 400,
        micro = "Dawn grey — tiny hope or another clock tick.",
    },
    evening = {
        priority = 21, cooldown = 400,
        micro = "Evening dropping — less light, more edge.",
    },

    calm_indoors = {
        priority = 14, cooldown = 240,
        micro = "Safe indoors — mind wanders: light, dust, a useless object, a half-song, a dumb joke. NOT clothes.",
    },
    well_fed = {
        priority = 10, cooldown = 280,
        micro = "Stomach quiet — gratitude as a joke or a memory of a real meal.",
    },
    clear_safeish = {
        priority = 9, cooldown = 240,
        micro = "No teeth in your face — look OUT: weather, room, nature, memory, joke. Ban shirt/hat/gun status.",
    },
    mind_wander = {
        priority = 16, cooldown = 270,
        micro = "Memory, regret, joke, or desire — one fresh human scrap.",
    },
    media_react = {
        priority = 72, cooldown = 75,
        micro = "Something new on the air — gut reaction, one angle.",
    },
    media_watching = {
        priority = 58, cooldown = 90,
        micro = "Still on the show — short aside, then let it go.",
    },
    waking = {
        priority = 52, cooldown = 120,
        micro = "Waking wrong — sleep crust, world already rude.",
    },

    topic_dead_end = {
        priority = 74, cooldown = 200,
        micro = "Topic exhausted — shrug, boredom, enough; close it. No new argument.",
    },
    drunk_wave = {
        priority = 57, cooldown = 140,
        micro = "Alcohol itself is loud — warm blur, stupid confidence or sad honesty. Tone also comes from DRUNK LENS on other hooks.",
    },
    ammo_dry = {
        priority = 88, cooldown = 50,
        micro = "Click empty — cold stomach, hands already hunting pockets.",
    },
    eating = {
        priority = 45, cooldown = 90,
        micro = "Food hitting the mouth — relief, grease, or regret mid-chew.",
    },
    drinking = {
        priority = 44, cooldown = 90,
        micro = "Water/drink down the throat — animal gratitude.",
    },
    loot_find_rare = {
        priority = 64, cooldown = 120,
        micro = "Found something that matters — small greedy spark, keep it quiet.",
    },
    first_kill_session = {
        priority = 70, cooldown = 180,
        micro = "First dead down today — ugly relief, hands still buzzing.",
    },
    player_nearby = {
        priority = 63, cooldown = 150,
        micro = "Another living person close — hope, suspicion, awkward body.",
    },
    falling_asleep = {
        priority = 34, cooldown = 180,
        micro = "Sliding toward sleep — body surrendering whether mind agrees.",
    },
}

function H.get(id)
    return H.Defs[id]
end

if DSThoughts.Config and DSThoughts.Config.log then
    local n = 0
    for _ in pairs(H.Defs) do n = n + 1 end
    DSThoughts.Config.log("PromptHooks loaded (" .. tostring(n) .. ")")
end
