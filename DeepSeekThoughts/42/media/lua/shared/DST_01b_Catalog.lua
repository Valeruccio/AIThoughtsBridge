--[[
  B41 character voice catalog — English speech biases + EFFECT lines for the bridge.
  Trait type ids from IsoGameCharacter.CharacterTraits + MainCreationMethods (incl. engine typos).
]]

DSThoughts = DSThoughts or {}
DSThoughts.Catalog = DSThoughts.Catalog or {}

local Cat = DSThoughts.Catalog

Cat.PROFESSION_VOICE = {
    unemployed = "Unemployed civilian — no craft jargon; plain everyday thoughts.",
    fireofficer = "Fire officer — practical, direct, hazard-aware; checks exits and smoke habits.",
    policeofficer = "Police officer — clipped situational talk; threat assessment, not melodrama.",
    parkranger = "Park ranger — outdoorsy, patient, notices terrain and weather.",
    constructionworker = "Construction worker — blunt hands-on talk; tools, weight, jobsite grit.",
    securityguard = "Security guard — night-shift fatigue; routine checks, suspicious sounds.",
    carpenter = "Carpenter — measures twice; wood, edges, how things are built.",
    burglar = "Burglar — quiet, opportunistic; locks, noise, easy exits.",
    chef = "Chef — food/smell/cookware instincts; kitchen discipline even in chaos.",
    repairman = "Repairman — fix-it mind; broken things annoy; makeshift solutions.",
    farmer = "Farmer — seasonal, bodily fatigue; crops, animals, weather schedule.",
    fisherman = "Fisherman — patience, water, lines; quiet waiting voice.",
    doctor = "Doctor — clinical calm under mess; wounds as problems to treat.",
    veteran = "War veteran — flat competence; Desensitized tone if present; no greenhorn panic.",
    nurse = "Nurse — caretaking register; vitals, cleanliness, practical comfort.",
    lumberjack = "Lumberjack — axe/work-muscle talk; big swings, timber, sweat.",
    fitnessInstructor = "Fitness instructor — body metrics, breath, form; pep without poetry.",
    burgerflipper = "Burger flipper — greasy-shift slang; fry oil, rush, cheap humor.",
    electrician = "Electrician — wires, power, shorts; careful with wrong switches.",
    engineer = "Engineer — systems thinker; jury-rigs, payloads, improvised devices.",
    metalworker = "Metalworker — heat, weld, slag; heavy industry grit.",
    mechanics = "Mechanic — engines, grease under nails; listening to machines.",
}

--[[
  Full B41 TRAIT_VOICE (positive + negative + profession/free + removed-but-present slots).
  Keys must match player:getTraits() / HasTrait() strings.
]]
Cat.TRAIT_VOICE = {
    -- ===== POSITIVE / SELECTABLE =====
    AdrenalineJunkie = "Adrenaline Junkie: EFFECT faster move at Strong/Extreme panic — thrives on spikes; restless when quiet.",
    Athletic = "Athletic: EFFECT +4 Fitness, faster run, less endurance loss — body-proud stamina; hates feeling slow.",
    BaseballPlayer = "Baseball Player: EFFECT +1 Long Blunt — sports muscle memory; bats, swings, competitive scraps.",
    Brave = "Brave: EFFECT ~70% panic (not phobias/night terrors) — faces risk head-on; downplays fear.",
    Brawler = "Brawler: EFFECT +1 Axe +1 Long Blunt — fight-first; likes closing distance.",
    Cook = "Cook: EFFECT +2 Cooking recipes — food-minded; invents meals from scraps.",
    Dextrous = "Dextrous: EFFECT 50% inventory transfer time — nimble fingers; handling ease.",
    EagleEyed = "Eagle Eyed: EFFECT wider FOV / faster visibility — notices distant details; visual first.",
    FastHealer = "Fast Healer: EFFECT milder new wound severity — shrugs injury; bounce-back confidence.",
    FastLearner = "Fast Learner: EFFECT 130% XP (not Str/Fit) — quick mental notes; picks patterns fast.",
    FastReader = "Fast Reader: EFFECT 130% reading speed — comfortable with text when relevant.",
    FirstAid = "First Aider: EFFECT +1 First Aid — bandage / pressure / CPR habit.",
    Fit = "Fit: EFFECT +2 Fitness — capable physically; less complain about exertion.",
    Fishing = "Angler: EFFECT +1 Fishing, make/fix rods — bait, water, waiting patience.",
    Formerscout = "Former Scout: EFFECT +1 First Aid +1 Fishing +1 Foraging — tracking, preparedness.",
    Gardener = "Gardener: EFFECT +1 Farming — plants, soil, seasons in mental inventory.",
    Graceful = "Graceful: EFFECT ~60% footstep radius — soft footfalls; dislikes clumsiness.",
    Gymnast = "Gymnast: EFFECT +1 Lightfooted +1 Nimble — balance and body control.",
    Handy = "Handy: EFFECT +1 Carpentry +1 Maintenance, stronger/faster builds — DIY confidence.",
    Herbalist = "Herbalist: EFFECT medicinal plants / poultices — bitter teas, forage remedies.",
    Hiker = "Hiker: EFFECT +1 Foraging +1 Trapping — trail thinking; pack, route, boots.",
    Hunter = "Hunter: EFFECT Aiming/Sneak/Short Blade etc. — stalk-and-wait; game, rifles, silence.",
    Inconspicuous = "Inconspicuous: EFFECT 50% chance to be spotted — low profile; prefers not being noticed.",
    IronGut = "Iron Gut: EFFECT 50% food illness chance / shorter — unfazed by bad food; gut jokes OK.",
    Jogger = "Runner: EFFECT +1 Sprinting — runner's breath and pace talk.",
    KeenHearing = "Keen Hearing: EFFECT 200% perception — sound-first; soft noises behind register early.",
    LightEater = "Light Eater: EFFECT 75% hunger rate — small appetite; food less urgent.",
    LowThirst = "Low Thirst: EFFECT 50% thirst rate — drinks less; thirst rarely dominates.",
    Lucky = "Lucky: EFFECT better loot / repair odds — half-believes odds bend their way.",
    Mechanics = "Amateur Mechanic: EFFECT +1 Mechanics, common/heavy repairs — car sense; engines.",
    NeedsLessSleep = "Wakeful: EFFECT -30% fatigue gain, +10% sleep efficiency — night shifts feel normal.",
    NightVision = "Cat's Eyes: EFFECT +20% night vision — darkness less scares; night confidence.",
    Nutritionist = "Nutritionist: EFFECT sees nutrition on any food — food as fuel math.",
    Organized = "Organized: EFFECT 130% container capacity — order-loving; messy spaces irritate.",
    Outdoorsman = "Outdoorsy: EFFECT resists cold/catching cold / tree scratches — weather is just weather.",
    Resilient = "Resilient: EFFECT slower zombification / fewer colds — toughs sickness; stubborn body.",
    SpeedDemon = "Speed Demon: EFFECT faster gear shifts, higher top speed — impatient pedal-joy; hates crawling.",
    Stout = "Stout: EFFECT +2 Strength — solid build; can carry more.",
    Strong = "Strong: EFFECT +4 Strength, +40% knockback — power confidence; lifting easy.",
    Tailor = "Sewer: EFFECT +1 Tailoring — needle-and-thread; torn cloth is a fix.",
    ThickSkinned = "Thick Skinned: EFFECT harder for bites/scratches to break skin — tough hide talk.",
    SelfDefenseClass = "Self Defense Class: hand-to-hand / close combat familiarity.",
    PlaysFootball = "Plays Football: athletic scrap memory; field, hits, teamwork jokes.",
    Patient = "Patient: less quick to anger — steadier temper under petty stress.",
    HeavyDrinker = "Hardened Drinker: EFFECT resists drunkenness — alcohol barely dents them.",

    -- ===== NEGATIVE / SELECTABLE =====
    Agoraphobic = "Agoraphobic: EFFECT panic rises outdoors — open sky wrong; wants walls/cover.",
    AllThumbs = "All Thumbs: EFFECT 400% transfer time — fumbles; hates fiddly tasks.",
    Asthmatic = "Asthmatic / Short of Breath: EFFECT faster endurance loss — breath awareness; exertion scares lungs.",
    Claustophobic = "Claustrophobic: EFFECT panic rises indoors — walls press; needs air/exits.",
    Clumsy = "Clumsy: EFFECT louder footsteps — expects to knock things; self-scolding.",
    Conspicuous = "Conspicuous: EFFECT 200% chance to be spotted — feels watched; noisy presence.",
    Cowardly = "Cowardly: EFFECT 200% panic (not phobias) — scared-first; wants escape routes.",
    Deaf = "Deaf: EFFECT no hearing / no radio overhead chatter — visual/vibration only; NEVER invent hearing.",
    Disorganized = "Disorganized: EFFECT 70% container capacity — mental clutter; loses where stuff is.",
    Feeble = "Feeble: EFFECT -2 Strength — weak arms; strain easily.",
    HardOfHearing = "Hard of Hearing: EFFECT smaller perception / muffled sound — misses quiet sounds.",
    HeartyAppitite = "Hearty Appetite: EFFECT 150% hunger — always hungry; food wants loud.",
    Hemophobic = "Fear of Blood: EFFECT panic on first aid / stress when bloody — blood freezes them.",
    HighThirst = "High Thirst: EFFECT +100% thirst — mouth dry often; water thoughts recur.",
    Illiterate = "Illiterate: EFFECT cannot read books/magazines — NEVER bookish phrases or written flex.",
    Insomniac = "Restless Sleeper: EFFECT poor sleep recovery — tired-but-wired; sleep dread.",
    NeedsMoreSleep = "Sleepyhead: EFFECT +30% fatigue, -10% sleep efficiency — lids heavy; wants bed.",
    Obese = "Obese: EFFECT slow, very low endurance, trip/fall risk — weight and breath color movement.",
    ["Out of Shape"] = "Out of Shape: EFFECT -2 Fitness — short wind; body complaints.",
    OutOfShape = "Out of Shape: EFFECT -2 Fitness — short wind; body complaints.",
    Overweight = "Overweight: EFFECT slower run, worse endurance, trip risk — extra weight annoyance.",
    Pacifist = "Pacifist: EFFECT less weapon XP — violence-averse; killing sits wrong.",
    ProneToIllness = "Prone to Illness: EFFECT faster zombification / more colds — worries about catching sick.",
    ShortSighted = "Short Sighted: EFFECT blur past ~4 tiles (glasses help) — squints at far details.",
    SlowHealer = "Slow Healer: EFFECT worse new wound severity — injuries feel lasting.",
    SlowLearner = "Slow Learner: EFFECT 70% XP — needs things repeated; less abstract.",
    SlowReader = "Slow Reader: EFFECT 70% reading speed — text is effort; avoids bookish flex.",
    Smoker = "Smoker: EFFECT stress rises without cigarettes; smoking calms — nicotine edge.",
    SundayDriver = "Sunday Driver: EFFECT slow accel, ~30 km/h cap — cautious wheel; «тихонько»; hates reckless gas.",
    Thinskinned = "Thin-skinned: EFFECT easier for attacks to break skin — cuts feel worse; fragile skin.",
    ThinSkinned = "Thin-skinned: EFFECT easier for attacks to break skin — cuts feel worse; fragile skin.",
    Underweight = "Underweight: EFFECT weaker melee, trip risk — light frame; cold/fragile self-sense.",
    Unfit = "Unfit: EFFECT -4 Fitness — very unfit; movement is punishment.",
    Unlucky = "Unlucky: EFFECT worse loot / repair odds — expects things to go wrong.",
    ["Very Underweight"] = "Very Underweight: EFFECT much weaker melee / more trips — gaunt; hunger/cold bite hard.",
    VeryUnderweight = "Very Underweight: EFFECT much weaker melee / more trips — gaunt; hunger/cold bite hard.",
    Weak = "Weak: EFFECT -2 Strength — strength doubts; heavy things feel impossible.",
    WeakStomach = "Weak Stomach: EFFECT 200% food illness — nausea-prone; food and gore turn stomach.",
    Hypercondriac = "Hypochondriac: EFFECT may invent infection symptoms from scratches — infection dread loops.",
    ShortTemper = "Short Tempered: EFFECT quick to anger — snap, swear, short fuse under stress.",
    LightDrinker = "Light Drinker: EFFECT gets drunk fast — alcohol hits hard.",
    Brooding = "Brooding: EFFECT recovers slower from bad moods — grey moods stick.",

    -- ===== PROFESSION / FREE / ADAPTIVE =====
    Axeman = "Ax-pert: EFFECT faster axe swings — axe feels natural; chopping rhythm.",
    Burglar = "Burglar: EFFECT can hotwire; better window force — entry know-how; criminal calm.",
    Cook2 = "Keen Cook (chef): pro kitchen habits; knife and heat comfort.",
    Desensitized = "Desensitized: EFFECT no panic (except nightmares) — flat affect; dry underreact.",
    Emaciated = "Emaciated: EFFECT very low strength/endurance, fall damage — starvation hollow.",
    Marksman = "Marksman: EFFECT gun accuracy/reload — sight picture; gun calm.",
    Mechanics2 = "Vehicle Knowledge (mechanic): all vehicle repairs — cars as puzzles.",
    NightOwl = "Night Owl: EFFECT alert while sleeping / night natural — days feel wrong.",
    Nutritionist2 = "Nutritionist (fitness pro): food-science voice.",
    Injured = "Injured (adaptive): body damage colors every scrap — pain and limitation.",
}

Cat.PROFESSION_LABEL = {
    unemployed = "Unemployed",
    fireofficer = "Fire Officer",
    policeofficer = "Police Officer",
    parkranger = "Park Ranger",
    constructionworker = "Construction Worker",
    securityguard = "Security Guard",
    carpenter = "Carpenter",
    burglar = "Burglar",
    chef = "Chef",
    repairman = "Repairman",
    farmer = "Farmer",
    fisherman = "Fisherman",
    doctor = "Doctor",
    veteran = "Veteran",
    nurse = "Nurse",
    lumberjack = "Lumberjack",
    fitnessInstructor = "Fitness Instructor",
    burgerflipper = "Burger Flipper",
    electrician = "Electrician",
    engineer = "Engineer",
    metalworker = "Metalworker",
    mechanics = "Mechanic",
}

Cat.SKILL_VOICE = {
    Strength = "strong-body framing",
    Fitness = "cardio/fitness framing",
    Sprinting = "sprint-escape mind",
    Lightfoot = "quiet-step mind",
    Nimble = "dodge/footwork mind",
    Sneak = "stealth wording",
    Axe = "axe familiarity",
    Blunt = "long blunt comfort",
    SmallBlunt = "short club comfort",
    LongBlade = "blade comfort",
    SmallBlade = "knife comfort",
    Spear = "reach-weapon mind",
    Maintenance = "weapon care habit",
    Woodwork = "carpentry framing",
    Cooking = "kitchen framing",
    Farming = "farm framing",
    Doctor = "medical framing",
    Electricity = "electrical framing",
    MetalWelding = "welding framing",
    Mechanics = "auto-mechanic framing",
    Tailoring = "sewing framing",
    Aiming = "marksmanship mind",
    Reloading = "reload discipline",
    Fishing = "angling framing",
    Trapping = "trapper framing",
    PlantScavenging = "foraging eye",
}

Cat.SKILL_PERKS = {
    "Strength", "Fitness",
    "Sprinting", "Lightfoot", "Nimble", "Sneak",
    "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear", "Maintenance",
    "Woodwork", "Cooking", "Farming", "Doctor", "Electricity", "MetalWelding", "Mechanics", "Tailoring",
    "Aiming", "Reloading",
    "Fishing", "Trapping", "PlantScavenging",
}

-- Aliases: same trait, different string forms across builds / lists
Cat.TRAIT_ALIASES = {
    OutOfShape = { "OutOfShape", "Out of Shape" },
    VeryUnderweight = { "VeryUnderweight", "Very Underweight" },
    ThinSkinned = { "ThinSkinned", "Thinskinned" },
    Thinskinned = { "Thinskinned", "ThinSkinned" },
}

function Cat.traitSetFromList(ids)
    local set = {}
    if not ids then return set end
    for i = 1, #ids do
        set[tostring(ids[i])] = true
    end
    return set
end

function Cat.hasTrait(idsOrSet, id)
    if not idsOrSet or not id then return false end
    local aliases = Cat.TRAIT_ALIASES[id]
    local check = function(x)
        if idsOrSet[x] == true then return true end
        -- Array form (legacy); set form has string keys and # == 0
        for i = 1, #idsOrSet do
            if tostring(idsOrSet[i]) == x then return true end
        end
        return false
    end
    if aliases then
        for i = 1, #aliases do
            if check(aliases[i]) then return true end
        end
        return false
    end
    return check(id)
end

--- Situation-active trait tips (EFFECT currently biting). Max 6.
function Cat.activeTraitTips(traitIds, sit)
    local out = {}
    if not traitIds or not sit then return out end
    local set = Cat.traitSetFromList(traitIds)
    local has = function(id) return Cat.hasTrait(set, id) end

    local indoors = sit.indoors
    local z = sit.zombies or {}
    local m = sit.moodles or {}
    local env = sit.env or {}
    local comfort = sit.comfort or {}
    local combat = sit.combat or {}
    local body = sit.body or {}
    local weather = sit.weather or {}
    local veh = sit.vehicle or {}
    local vitals = sit.vitals or {}
    local threat = (z.chasing or 0) + (z.close or 0) + (z.visible or 0) > 0
    local bloody = comfort.bloody_clothes or (body.bleeding_parts or 0) > 0 or combat.took_hit
    local wounded = combat.took_hit or (body.bites or 0) > 0 or (body.deep or 0) > 0 or (m.injured or 0) >= 1
    local inVeh = comfort.in_vehicle or veh.in_vehicle
    local night = sit.part_of_day == "night"
    local hungry = (m.hungry or 0) >= 1
    local thirsty = (m.thirsty or 0) >= 1
    local tired = (m.tired or 0) >= 1
    local panicked = (m.panic or 0) >= 2
    local sick = (m.sick or 0) >= 1
    local heavy = (m.heavy_load or 0) >= 1
    local unhappy = (m.unhappy or 0) >= 2
    local stressed = (m.stressed or 0) >= 2
    local exert = tired or heavy or (m.hyperthermia or 0) >= 1
    local weatherHarsh = weather.rain or weather.fog or (m.hypothermia or 0) >= 1 or (m.windchill or 0) >= 1

    local function add(tip)
        if #out >= 6 then return end
        table.insert(out, tip)
    end

    -- Always-on hard constraints
    if has("Deaf") then
        add("ACTIVE Deaf: no sound world — never invent hearing zombies/radio chatter.")
    end
    if has("Illiterate") then
        add("ACTIVE Illiterate: never invent reading books/magazines/skill manuals.")
    end

    -- Phobias / panic style
    if has("Agoraphobic") and indoors == false then
        add("ACTIVE Agoraphobic outdoors: open sky presses panic — wants walls/cover.")
    end
    if has("Claustophobic") and indoors == true then
        add("ACTIVE Claustrophobic indoors: walls press — needs air/exits.")
    end
    if has("Hemophobic") and bloody then
        add("ACTIVE Fear of Blood: gore/blood — aversion and stress, not clinical calm.")
    end
    if has("Desensitized") and (threat or combat.in_combat or panicked) then
        add("ACTIVE Desensitized: threat but flat affect — dry underreact, not screaming.")
    end
    if has("Cowardly") and (threat or panicked) and not has("Desensitized") then
        add("ACTIVE Cowardly: threat spikes fear — escape-first wording.")
    end
    if has("Brave") and threat and not has("Desensitized") then
        add("ACTIVE Brave: threat without melodrama — forward, downplays fear.")
    end
    if has("AdrenalineJunkie") and panicked then
        add("ACTIVE Adrenaline Junkie: high panic feels like fuel — restless thrill.")
    end
    if has("Pacifist") and (combat.in_combat or combat.landed_hit or combat.gunshot or combat.took_hit) then
        add("ACTIVE Pacifist: violence sits wrong — reluctant/guilty scraps.")
    end
    if has("ShortTemper") and (stressed or combat.in_combat or unhappy) then
        add("ACTIVE Short Temper: snap/swear fuse short under stress.")
    end
    if has("Patient") and (stressed or unhappy) then
        add("ACTIVE Patient: steadier temper — less snap, more grit.")
    end
    if has("Brooding") and unhappy then
        add("ACTIVE Brooding: grey mood sticks — slow to shake bad feelings.")
    end
    if has("Hypercondriac") and (wounded or sick or (body.bites or 0) > 0) then
        add("ACTIVE Hypochondriac: scratch/illness → infection dread loops.")
    end

    -- Senses
    if has("KeenHearing") and threat then
        add("ACTIVE Keen Hearing: sound-first — soft steps/behind early.")
    end
    if has("HardOfHearing") and threat then
        add("ACTIVE Hard of Hearing: world muffled — unsure about quiet threats.")
    end
    if has("NightVision") and night then
        add("ACTIVE Cat's Eyes at night: darkness less scary.")
    end
    if has("ShortSighted") and (threat or not indoors) then
        add("ACTIVE Short Sighted: far blur — squints at distant shapes.")
    end
    if has("EagleEyed") and threat then
        add("ACTIVE Eagle Eyed: spots distant shapes first.")
    end

    -- Stealth / noise
    if has("Conspicuous") and threat then
        add("ACTIVE Conspicuous: feels too visible — spotted-easily dread.")
    end
    if has("Inconspicuous") and threat then
        add("ACTIVE Inconspicuous: low-profile habit — hopes they don't see.")
    end
    if has("Clumsy") and (threat or heavy) then
        add("ACTIVE Clumsy: loud/awkward — self-scolds for noise/fumbling.")
    end
    if has("Graceful") and threat then
        add("ACTIVE Graceful: quiet-step self-image — hates clumsy noise.")
    end
    if has("AllThumbs") and (comfort.has_weapon or heavy) then
        add("ACTIVE All Thumbs: fiddly handling feels cursed.")
    end
    if has("Dextrous") and heavy then
        add("ACTIVE Dextrous: hands feel quick — sorting/handling ease.")
    end

    -- Body / weight / fitness
    if has("Asthmatic") and exert then
        add("ACTIVE Asthmatic: lungs complain — exertion frightens breath.")
    end
    if (has("Obese") or has("Overweight") or has("Unfit") or has("OutOfShape")) and (exert or heavy) then
        add("ACTIVE weight/fitness negative: body complains hard about movement/load.")
    end
    if (has("Underweight") or has("VeryUnderweight") or has("Emaciated") or has("Feeble") or has("Weak")) and (heavy or hungry or (m.hypothermia or 0) >= 1) then
        add("ACTIVE frail/underweight: body too light/weak for this.")
    end
    if (has("Strong") or has("Stout") or has("Athletic") or has("Fit")) and (heavy or exert or combat.in_combat) then
        add("ACTIVE strong/fit body: confidence about strength/stamina.")
    end

    -- Hunger / thirst / sleep / smoke
    if has("Smoker") and ((vitals.smoke_stress or 0) > 0.35 or (vitals.time_since_smoke or 0) > 4 or stressed) then
        add("ACTIVE Smoker: nicotine itch / stress without a cigarette.")
    end
    if has("HeartyAppitite") and hungry then
        add("ACTIVE Hearty Appetite: hunger loud — food wants dominate.")
    end
    if has("LightEater") and hungry then
        add("ACTIVE Light Eater: hungry but milder — food less dramatic.")
    end
    if has("HighThirst") and thirsty then
        add("ACTIVE High Thirst: mouth desert — water urgency.")
    end
    if has("LowThirst") and thirsty then
        add("ACTIVE Low Thirst: thirsty but less dramatic.")
    end
    if (has("NeedsMoreSleep") or has("Insomniac")) and tired then
        add("ACTIVE Sleepyhead/Restless Sleeper: sleep debt biting.")
    end
    if has("NeedsLessSleep") and (tired or night) then
        add("ACTIVE Wakeful: less crushed by tiredness / night OK.")
    end
    if has("NightOwl") and night then
        add("ACTIVE Night Owl: night feels natural — days would feel wrong.")
    end

    -- Wounds / illness / gut
    if has("Thinskinned") and wounded then
        add("ACTIVE Thin-skinned: wounds feel worse / skin fails easily.")
    end
    if has("ThickSkinned") and combat.took_hit then
        add("ACTIVE Thick Skinned: shrugs the hit — tough hide.")
    end
    if has("SlowHealer") and wounded then
        add("ACTIVE Slow Healer: injuries feel lasting.")
    end
    if has("FastHealer") and wounded then
        add("ACTIVE Fast Healer: bounce-back confidence about the wound.")
    end
    if has("WeakStomach") and (sick or bloody) then
        add("ACTIVE Weak Stomach: nausea from food/gore.")
    end
    if has("IronGut") and sick then
        add("ACTIVE Iron Gut: shrugs food sickness better than most.")
    end
    if has("ProneToIllness") and sick then
        add("ACTIVE Prone to Illness: sickness sticks / infection dread.")
    end
    if has("Resilient") and sick then
        add("ACTIVE Resilient: toughs the illness — stubborn body.")
    end

    -- Weather / outdoors
    if has("Outdoorsman") and indoors == false and weatherHarsh then
        add("ACTIVE Outdoorsy: weather is just weather — less drama.")
    end

    -- Vehicles / crime / guns / axe
    if has("SundayDriver") and inVeh then
        add("ACTIVE Sunday Driver: cautious wheel — hates reckless gas.")
    end
    if has("SpeedDemon") and inVeh then
        add("ACTIVE Speed Demon: impatient pedal-joy — hates crawling.")
    end
    if (has("Mechanics") or has("Mechanics2") or has("Burglar")) and inVeh then
        add("ACTIVE mechanic/burglar car sense: engines, hotwire, jury-rigs.")
    end
    if has("Marksman") and (combat.gunshot or combat.in_combat) then
        add("ACTIVE Marksman: gun calm — sight picture, not panic spray.")
    end
    if has("Axeman") and (combat.landed_hit or combat.in_combat) then
        add("ACTIVE Ax-pert: axe rhythm feels natural.")
    end
    if has("Brawler") and combat.in_combat then
        add("ACTIVE Brawler: fight-first close-in scrap.")
    end

    -- Luck / learning / org (soft)
    if has("Unlucky") and (threat or unhappy) then
        add("ACTIVE Unlucky: expects things to go wrong.")
    end
    if has("Lucky") and not threat then
        add("ACTIVE Lucky: half-believes odds bend their way.")
    end
    if has("Disorganized") and indoors then
        add("ACTIVE Disorganized: mental clutter — where did I put that?")
    end
    if has("Organized") and indoors then
        add("ACTIVE Organized: messy spaces irritate — wants order.")
    end
    if has("Nutritionist") or has("Nutritionist2") then
        if hungry then add("ACTIVE Nutritionist: food as fuel math.") end
    end
    if has("Cook") or has("Cook2") then
        if hungry then add("ACTIVE Cook: invents meals / kitchen fantasy.") end
    end

    return out
end

--- Append situational trait_* candidates via tryAdd(c, id, active)
function Cat.appendTraitCandidates(c, sit, tryAdd)
    if not sit or not tryAdd then return end
    local traits = sit.traits or {}
    local set = Cat.traitSetFromList(traits)
    local has = function(id) return Cat.hasTrait(set, id) end
    local m = sit.moodles or {}
    local z = sit.zombies or {}
    local body = sit.body or {}
    local comfort = sit.comfort or {}
    local combat = sit.combat or {}
    local weather = sit.weather or {}
    local veh = sit.vehicle or {}
    local media = sit.media or {}
    local vitals = sit.vitals or {}
    local threat = ((z.chasing or 0) + (z.close or 0) + (z.visible or 0)) > 0
    local bloody = comfort.bloody_clothes or (body.bleeding_parts or 0) > 0 or combat.took_hit
    local wounded = combat.took_hit or (body.bites or 0) > 0 or (body.deep or 0) > 0 or (m.injured or 0) >= 1
    local inVeh = comfort.in_vehicle or veh.in_vehicle
    local night = sit.part_of_day == "night"
    local exert = (m.tired or 0) >= 1 or (m.heavy_load or 0) >= 1 or (m.hyperthermia or 0) >= 1
    local weatherHarsh = weather.rain or weather.fog or (m.hypothermia or 0) >= 1 or (m.windchill or 0) >= 1
    local combatAny = combat.in_combat or combat.landed_hit or combat.gunshot or combat.took_hit

    tryAdd(c, "trait_deaf", has("Deaf") and (threat or media.active))
    tryAdd(c, "trait_illiterate", has("Illiterate"))
    tryAdd(c, "trait_agoraphobic", has("Agoraphobic") and sit.indoors == false)
    tryAdd(c, "trait_claustrophobic", has("Claustophobic") and sit.indoors == true)
    tryAdd(c, "trait_hemophobic", has("Hemophobic") and bloody)
    tryAdd(c, "trait_desensitized", has("Desensitized") and (threat or combat.in_combat or (m.panic or 0) >= 2))
    tryAdd(c, "trait_cowardly", has("Cowardly") and (threat or (m.panic or 0) >= 2) and not has("Desensitized"))
    tryAdd(c, "trait_brave", has("Brave") and threat and not has("Desensitized"))
    tryAdd(c, "trait_pacifist", has("Pacifist") and combatAny)
    tryAdd(c, "trait_adrenaline", has("AdrenalineJunkie") and (m.panic or 0) >= 2)
    tryAdd(c, "trait_short_temper", has("ShortTemper") and ((m.stressed or 0) >= 2 or combatAny or (m.unhappy or 0) >= 2))
    tryAdd(c, "trait_patient", has("Patient") and ((m.stressed or 0) >= 2 or (m.unhappy or 0) >= 2))
    tryAdd(c, "trait_brooding", has("Brooding") and (m.unhappy or 0) >= 2)
    tryAdd(c, "trait_hypochondriac", has("Hypercondriac") and (wounded or (m.sick or 0) >= 1 or (body.bites or 0) > 0))
    tryAdd(c, "trait_keen_hearing", has("KeenHearing") and threat)
    tryAdd(c, "trait_hard_hearing", has("HardOfHearing") and threat)
    tryAdd(c, "trait_night_vision", has("NightVision") and night)
    tryAdd(c, "trait_short_sighted", has("ShortSighted") and (threat or not sit.indoors))
    tryAdd(c, "trait_eagle_eyed", has("EagleEyed") and threat)
    tryAdd(c, "trait_conspicuous", has("Conspicuous") and threat)
    tryAdd(c, "trait_inconspicuous", has("Inconspicuous") and threat)
    tryAdd(c, "trait_clumsy", has("Clumsy") and (threat or (m.heavy_load or 0) >= 1))
    tryAdd(c, "trait_graceful", has("Graceful") and threat)
    tryAdd(c, "trait_all_thumbs", has("AllThumbs") and (comfort.has_weapon or (m.heavy_load or 0) >= 1))
    tryAdd(c, "trait_dextrous", has("Dextrous") and (m.heavy_load or 0) >= 1)
    tryAdd(c, "trait_asthmatic", has("Asthmatic") and exert)
    tryAdd(c, "trait_unfit_body", (has("Obese") or has("Overweight") or has("Unfit") or has("OutOfShape")) and (exert or (m.heavy_load or 0) >= 1))
    tryAdd(c, "trait_frail_body", (has("Underweight") or has("VeryUnderweight") or has("Emaciated") or has("Feeble") or has("Weak")) and ((m.heavy_load or 0) >= 1 or (m.hungry or 0) >= 1 or (m.hypothermia or 0) >= 1))
    tryAdd(c, "trait_strong_body", (has("Strong") or has("Stout") or has("Athletic") or has("Fit")) and ((m.heavy_load or 0) >= 1 or exert or combatAny))
    tryAdd(c, "trait_hearty_appetite", has("HeartyAppitite") and (m.hungry or 0) >= 1)
    tryAdd(c, "trait_light_eater", has("LightEater") and (m.hungry or 0) >= 1)
    tryAdd(c, "trait_high_thirst", has("HighThirst") and (m.thirsty or 0) >= 1)
    tryAdd(c, "trait_low_thirst", has("LowThirst") and (m.thirsty or 0) >= 1)
    tryAdd(c, "trait_smoker", has("Smoker") and ((vitals.smoke_stress or 0) > 0.35 or (vitals.time_since_smoke or 0) > 4 or (m.stressed or 0) >= 2))
    tryAdd(c, "trait_sleepyhead", (has("NeedsMoreSleep") or has("Insomniac")) and (m.tired or 0) >= 1)
    tryAdd(c, "trait_wakeful", has("NeedsLessSleep") and ((m.tired or 0) >= 1 or night))
    tryAdd(c, "trait_night_owl", has("NightOwl") and night)
    tryAdd(c, "trait_thin_skinned", has("Thinskinned") and wounded)
    tryAdd(c, "trait_thick_skinned", has("ThickSkinned") and combat.took_hit)
    tryAdd(c, "trait_slow_healer", has("SlowHealer") and wounded)
    tryAdd(c, "trait_fast_healer", has("FastHealer") and wounded)
    tryAdd(c, "trait_weak_stomach", has("WeakStomach") and ((m.sick or 0) >= 1 or bloody))
    tryAdd(c, "trait_iron_gut", has("IronGut") and (m.sick or 0) >= 1)
    tryAdd(c, "trait_prone_illness", has("ProneToIllness") and (m.sick or 0) >= 1)
    tryAdd(c, "trait_resilient", has("Resilient") and (m.sick or 0) >= 1)
    tryAdd(c, "trait_outdoorsman", has("Outdoorsman") and sit.indoors == false and weatherHarsh)
    tryAdd(c, "trait_sunday_driver", has("SundayDriver") and inVeh)
    tryAdd(c, "trait_speed_demon", has("SpeedDemon") and inVeh)
    tryAdd(c, "trait_car_handy", (has("Mechanics") or has("Mechanics2") or has("Burglar")) and inVeh)
    tryAdd(c, "trait_marksman", has("Marksman") and (combat.gunshot or combat.in_combat))
    tryAdd(c, "trait_axeman", has("Axeman") and (combat.landed_hit or combat.in_combat))
    tryAdd(c, "trait_brawler", has("Brawler") and combat.in_combat)
    tryAdd(c, "trait_unlucky", has("Unlucky") and (threat or (m.unhappy or 0) >= 2))
    tryAdd(c, "trait_lucky", has("Lucky") and not threat)
    tryAdd(c, "trait_disorganized", has("Disorganized") and sit.indoors)
    tryAdd(c, "trait_organized", has("Organized") and sit.indoors)
    tryAdd(c, "trait_nutritionist", (has("Nutritionist") or has("Nutritionist2")) and (m.hungry or 0) >= 1)
    tryAdd(c, "trait_cook", (has("Cook") or has("Cook2")) and (m.hungry or 0) >= 1)
    tryAdd(c, "trait_slow_learner", has("SlowLearner"))
    tryAdd(c, "trait_fast_learner", has("FastLearner") and not threat)
    tryAdd(c, "trait_slow_reader", has("SlowReader"))
    tryAdd(c, "trait_fast_reader", has("FastReader") and not threat)
    tryAdd(c, "trait_light_drinker", has("LightDrinker"))
    tryAdd(c, "trait_heavy_drinker", has("HeavyDrinker"))
end

function Cat.professionVoice(id)
    if DSThoughts.B42 and DSThoughts.B42.normalizeProfessionId then
        id = DSThoughts.B42.normalizeProfessionId(id)
    end
    return Cat.PROFESSION_VOICE[id] or ("Civilian role: " .. tostring(id))
end

function Cat.professionLabel(id)
    if DSThoughts.B42 and DSThoughts.B42.normalizeProfessionId then
        id = DSThoughts.B42.normalizeProfessionId(id)
    end
    return Cat.PROFESSION_LABEL[id] or tostring(id)
end

function Cat.traitVoice(id)
    if DSThoughts.B42 and DSThoughts.B42.normalizeTraitId then
        id = DSThoughts.B42.normalizeTraitId(id)
    end
    return Cat.TRAIT_VOICE[id] or ("Trait " .. tostring(id) .. " colors their habits.")
end

function Cat.skillVoice(id)
    return Cat.SKILL_VOICE[id]
end

if DSThoughts.Config and DSThoughts.Config.log then
    DSThoughts.Config.log("Catalog loaded (full B41 traits)")
end
