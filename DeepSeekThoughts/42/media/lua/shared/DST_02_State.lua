--[[
  Character card + situation + ranked prompt hooks (schema 4).
]]

DSThoughts = DSThoughts or {}
DSThoughts.State = DSThoughts.State or {}

local S = DSThoughts.State
local C = DSThoughts.Config
local Cat = DSThoughts.Catalog

S._prevSituation = nil

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function collectTraits(player)
    local ids = {}
    local voices = {}
    pcall(function()
        if DSThoughts.B42 and DSThoughts.B42.collectTraitIds then
            ids = DSThoughts.B42.collectTraitIds(player) or {}
        else
            local traits = player:getTraits()
            if not traits then return end
            for i = 0, traits:size() - 1 do
                local tid = traits:get(i)
                if tid then
                    table.insert(ids, tostring(tid))
                end
            end
        end
        if Cat and Cat.traitVoice then
            for i = 1, #ids do
                table.insert(voices, Cat.traitVoice(ids[i]))
            end
        end
    end)
    return ids, voices
end

local function collectSkills(player)
    local notable = {}
    if not Cat or not Cat.SKILL_PERKS or not Perks then
        return notable
    end
    for i = 1, #Cat.SKILL_PERKS do
        local name = Cat.SKILL_PERKS[i]
        local perk = Perks[name]
        if perk then
            local lvl = 0
            pcall(function()
                lvl = player:getPerkLevel(perk) or 0
            end)
            if lvl >= 2 then
                local tip = Cat.skillVoice and Cat.skillVoice(name) or nil
                table.insert(notable, {
                    id = name,
                    level = lvl,
                    voice = tip,
                })
            end
        end
    end
    table.sort(notable, function(a, b)
        return (a.level or 0) > (b.level or 0)
    end)
    if #notable > 6 then
        local trimmed = {}
        for i = 1, 6 do
            trimmed[i] = notable[i]
        end
        notable = trimmed
    end
    return notable
end

local function slimSituation(sit)
    if not sit then return nil end
    -- Drop heavy moodle table from wire? Keep compact fields for bridge digest rebuild
    return {
        indoors = sit.indoors,
        part_of_day = sit.part_of_day,
        hour = sit.hour,
        weather = sit.weather,
        zombies = sit.zombies,
        env = sit.env,
        comfort = {
            dirty_clothes = sit.comfort and sit.comfort.dirty_clothes,
            bloody_clothes = sit.comfort and sit.comfort.bloody_clothes,
            has_food = sit.comfort and sit.comfort.has_food,
            has_water = sit.comfort and sit.comfort.has_water,
            has_weapon = sit.comfort and sit.comfort.has_weapon,
            wet_cause = sit.comfort and sit.comfort.wet_cause,
            smoker = sit.comfort and sit.comfort.smoker,
            in_vehicle = sit.comfort and sit.comfort.in_vehicle,
            asleep = sit.comfort and sit.comfort.asleep,
            outfit = sit.comfort and sit.comfort.outfit,
        },
        vehicle = sit.vehicle,
        body = sit.body,
        combat = sit.combat,
        media = sit.media,
        moodles = sit.moodles,
        events = sit.events,
        vitals = {
            health = sit.vitals and sit.vitals.health,
            stress = sit.vitals and sit.vitals.stress,
            panic = sit.vitals and sit.vitals.panic,
            pain = sit.vitals and sit.vitals.pain,
            wetness = sit.vitals and sit.vitals.wetness,
            knox = sit.vitals and sit.vitals.knox,
            infection_level = sit.vitals and sit.vitals.infection_level,
            smoke_stress = sit.vitals and sit.vitals.smoke_stress,
        },
    }
end

--- opts.force_ambient: always include soft hooks even if low priority
function S.collect(player, opts)
    if not player then return nil end
    opts = opts or {}

    local female = false
    pcall(function()
        female = player:isFemale() and true or false
    end)

    local forename = "Survivor"
    local surname = ""
    local profession = "unemployed"
    pcall(function()
        local desc = player:getDescriptor()
        if not desc then return end
        if desc.getForename then
            forename = tostring(desc:getForename() or forename)
        end
        if desc.getSurname then
            surname = tostring(desc:getSurname() or "")
        end
    end)
    if DSThoughts.B42 and DSThoughts.B42.collectProfessionId then
        profession = DSThoughts.B42.collectProfessionId(player) or profession
    else
        pcall(function()
            local desc = player:getDescriptor()
            if desc and desc.getProfession then
                profession = tostring(desc:getProfession() or profession)
            end
        end)
    end

    local traitIds, traitVoices = collectTraits(player)
    if (#traitIds == 0) and C and C.log then
        pcall(function()
            local n1, n2 = -1, -1
            if player.getTraits and player:getTraits() and player:getTraits().size then
                n1 = player:getTraits():size()
            end
            if player.getCharacterTraits and player:getCharacterTraits() and player:getCharacterTraits().size then
                n2 = player:getCharacterTraits():size()
            end
            C.log("Traits empty after collect (getTraits.size=" .. tostring(n1)
                .. " getCharacterTraits.size=" .. tostring(n2) .. ") — no probe (B42-safe)")
        end)
    end
    local skills = collectSkills(player)

    local profLabel = profession
    local profVoice = ""
    if Cat then
        profLabel = Cat.professionLabel(profession)
        profVoice = Cat.professionVoice(profession)
    end

    local lang = C.Language or "ru"
    if lang ~= "en" and lang ~= "ru" then
        lang = "ru"
    end

    local built = {
        situation = nil,
        prompt_hooks = {},
        affect = { stress01 = 0, panic01 = 0, distress = 0, tier = "calm" },
        digest = {},
        max_priority = 0,
        force = false,
        acute = false,
    }
    if DSThoughts.PromptBuilder and DSThoughts.PromptBuilder.build then
        built = DSThoughts.PromptBuilder.build(player, S._prevSituation, {
            max_hooks = opts.max_hooks or 5,
        })
    end

    if built.situation then
        S._prevSituation = built.situation
    end

    local traitsActive = {}
    if Cat and Cat.activeTraitTips and built.situation then
        -- Prefer trait list attached during build (same frame)
        local ids = (built.situation.traits and #built.situation.traits > 0) and built.situation.traits or traitIds
        traitsActive = Cat.activeTraitTips(ids, built.situation) or {}
    end

    local snapshot = {
        schema = 4,
        language = lang,
        prompts = {
            world_main = (DSThoughts.Prompts and DSThoughts.Prompts.WorldMain) or "",
        },
        character = {
            female = female,
            forename = forename,
            surname = surname,
            profession = profession,
            profession_label = profLabel,
            profession_voice = profVoice,
            traits = traitIds,
            traits_voice = traitVoices,
            traits_active = traitsActive,
            skills_notable = skills,
        },
        situation = slimSituation(built.situation),
        prompt_hooks = built.prompt_hooks or {},
        digest = built.digest or {},
        affect = built.affect or { stress01 = 0, panic01 = 0, distress = 0, tier = "calm" },
        meta = {
            max_priority = built.max_priority or 0,
            force = built.force and true or false,
            acute = built.acute and true or false,
            emotion_phase = built.emotion_phase or "wander",
        },
        arc_topic = built.arc_topic or "",
        arc_phase = built.arc_phase or "",
        arc_turns = built.arc_turns or 0,
        emotion_phase = built.emotion_phase or "wander",
        swear_level = C.SwearLevel or "light",
        request_id = tostring(nowSec()) .. "-" .. tostring(ZombRand(100000)),
    }

    return snapshot
end

C.log("State module loaded (schema 4)")
