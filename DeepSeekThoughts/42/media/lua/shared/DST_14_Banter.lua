--[[
  Quiet small-talk topics + character banter lexicon (RU/EN).
  Soft biases only — never force nicknames every line.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Banter = DSThoughts.Banter or {}

local B = DSThoughts.Banter
local C = DSThoughts.Config

B.SMALLTALK_MAX_TURNS = 3
B.SMALLTALK_TURN_GAP = 7
B.BASE_ROLL_CHANCE = 20 -- percent per calm scan when gates pass

--- Topic pool for quiet casual talk.
B.Topics = {
    {
        id = "smalltalk_joke",
        weight = 12,
        address = "all",
        micro = "Casual joke or wry crack — short, human, not a stand-up set.",
    },
    {
        id = "smalltalk_gripe",
        weight = 11,
        address = "all",
        micro = "Quiet gripe / bitching about weather, feet, food, boredom — not a crisis.",
    },
    {
        id = "smalltalk_story",
        weight = 9,
        address = "all",
        micro = "Tiny wild story scrap from before or yesterday — one breath, not a novel.",
    },
    {
        id = "smalltalk_memory",
        weight = 10,
        address = "all",
        micro = "A memory slipping out loud — soft, specific, unfinished is OK.",
    },
    {
        id = "smalltalk_dream",
        weight = 8,
        address = "all",
        micro = "A dream or 'what if' spoken aloud — wishful, not planning tactics.",
    },
    {
        id = "smalltalk_want",
        weight = 10,
        address = "all",
        micro = "A want: cigarette, hot shower, real coffee, silence, a bed — spoken casually.",
    },
    {
        id = "smalltalk_observe",
        weight = 10,
        address = "all",
        micro = "Casual remark about place/weather/loot vibe — not a gear checklist.",
    },
    {
        id = "smalltalk_ask",
        weight = 11,
        address = "named",
        micro = "A real question to one person nearby — curiosity or check-in, not interrogation.",
    },
    {
        id = "smalltalk_praise",
        weight = 8,
        address = "named",
        needs = "praise",
        micro = "Genuine compliment or warm nickname — soft, character-true.",
    },
    {
        id = "smalltalk_roast",
        weight = 7,
        address = "named",
        needs = "roast",
        micro = "Tease or harsh nickname — only if tone allows; never empty cruelty spam.",
    },
}

function B.isSmallTalkTrigger(id)
    id = tostring(id or "")
    return string.sub(id, 1, 10) == "smalltalk_"
end

local function hasTrait(traits, name)
    if DSThoughts.B42 and DSThoughts.B42.hasTrait then
        return DSThoughts.B42.hasTrait(traits, name)
    end
    if not traits then return false end
    local want = string.lower(tostring(name))
    for i = 1, #traits do
        local t = string.lower(tostring(traits[i] or ""))
        if t == want or t:gsub(" ", "") == want:gsub(" ", "") then
            return true
        end
        if t:gsub("%s+", "") == want:gsub("%s+", "") then
            return true
        end
    end
    return false
end

local function heatLevel()
    local h = (C and C.BanterHeat) or "normal"
    h = string.lower(tostring(h))
    if h ~= "soft" and h ~= "normal" and h ~= "spicy" then
        h = "normal"
    end
    return h
end

--- How willing is this speaker to roast vs praise?
--- Returns roastBias 0..1, praiseBias 0..1
function B.speakerToneBias(speakerTraits, profession, affinity)
    local traits = speakerTraits or {}
    local roast = 0.25
    local praise = 0.35
    local aff = tonumber(affinity) or 0

    if hasTrait(traits, "Desensitized") then roast = roast + 0.25 end
    if hasTrait(traits, "ShortTemper") or hasTrait(traits, "Short Temper") then roast = roast + 0.22 end
    if hasTrait(traits, "Brawler") then roast = roast + 0.12 end
    if hasTrait(traits, "Smoker") then roast = roast + 0.08 end
    if hasTrait(traits, "Illiterate") then roast = roast + 0.1 end

    if hasTrait(traits, "Lucky") then praise = praise + 0.15 end
    if hasTrait(traits, "Pacifist") then
        praise = praise + 0.18
        roast = roast - 0.2
    end
    if hasTrait(traits, "Brave") and aff >= 1 then praise = praise + 0.1 end

    local prof = string.lower(tostring(profession or ""))
    if prof == "doctor" or prof == "nurse" or prof == "priest" or prof == "parkranger" then
        praise = praise + 0.12
        roast = roast - 0.08
    end
    if prof == "burglar" or prof == "criminal" or prof == "metalworker" then
        roast = roast + 0.08
    end

    if aff <= -2 then
        roast = roast + 0.25
        praise = praise - 0.2
    elseif aff >= 2 then
        praise = praise + 0.2
        roast = roast - 0.15
    end

    local heat = heatLevel()
    if heat == "soft" then
        roast = roast * 0.45
        praise = praise + 0.1
    elseif heat == "spicy" then
        roast = roast + 0.2
    end

    if roast < 0 then roast = 0 end
    if praise < 0 then praise = 0 end
    if roast > 1 then roast = 1 end
    if praise > 1 then praise = 1 end
    return roast, praise
end

--- Allowed tone for this pair under current heat.
function B.allowedTone(speakerTraits, profession, affinity)
    local roast, praise = B.speakerToneBias(speakerTraits, profession, affinity)
    local heat = heatLevel()
    local roastGate = 0.45
    if heat == "soft" then roastGate = 0.7 end
    if heat == "spicy" then roastGate = 0.32 end

    if roast >= roastGate and roast >= praise then
        return "roast"
    end
    if praise >= 0.4 and praise > roast then
        return "warm"
    end
    if roast >= 0.35 then
        return "tease"
    end
    return "neutral"
end

local NICKS_RU = {
    obese_m = { "Жиртрест", "Толстяк" },
    obese_f = { "Жируха", "Пончик" },
    thin_m = { "Дрищ", "Дистрофик", "Худыш" },
    thin_f = { "Худышка", "Спичка" },
    dumb_m = { "Тупорез", "Дурак" },
    dumb_f = { "Дура", "Тупорезка" },
    strong_m = { "Крепыш", "Красавчик", "Молодец" },
    strong_f = { "Крепышка", "Красавица", "Молодец" },
    smart_m = { "Умница", "Голова" },
    smart_f = { "Умница", "Головушка" },
    unfit_m = { "Задыхала", "Развалюха" },
    unfit_f = { "Задыхалка", "Развалюха" },
    weak_m = { "Хлюпик", "Слабак" },
    weak_f = { "Хлюпик", "Слабачка" },
}

local NICKS_EN = {
    obese_m = { "Lardass", "Big guy" },
    obese_f = { "Chubster", "Big girl" },
    thin_m = { "Beanpole", "Twig" },
    thin_f = { "Twiggy", "Stick" },
    dumb_m = { "Dimwit", "Dummy" },
    dumb_f = { "Dimwit", "Dummy" },
    strong_m = { "Tank", "Handsome", "Champ" },
    strong_f = { "Tough cookie", "Gorgeous", "Champ" },
    smart_m = { "Brainiac", "Smartass" },
    smart_f = { "Brainiac", "Smart cookie" },
    unfit_m = { "Wheezer", "Couch potato" },
    unfit_f = { "Wheezer", "Couch potato" },
    weak_m = { "Softie", "Weakling" },
    weak_f = { "Softie", "Weakling" },
}

local function pickLang()
    local lang = (C and C.Language) or "ru"
    if lang == "en" then return NICKS_EN end
    return NICKS_RU
end

local function addNick(out, pool, key, maxN)
    if #out >= maxN then return end
    local list = pool[key]
    if not list or #list == 0 then return end
    local idx = 1
    if ZombRand then
        idx = ZombRand(#list) + 1
    else
        idx = (math.random(#list))
    end
    local n = list[idx]
    for i = 1, #out do
        if out[i] == n then return end
    end
    out[#out + 1] = n
end

--- Build 0–2 optional nicknames aimed at target (soft suggestion for LLM).
function B.nicknamesForTarget(targetTraits, targetFemale, tone)
    local traits = targetTraits or {}
    local female = targetFemale and true or false
    local pool = pickLang()
    local out = {}
    local maxN = 2
    local sex = female and "_f" or "_m"

    local wantRoast = (tone == "roast" or tone == "tease")
    local wantPraise = (tone == "warm" or tone == "praise")

    if wantRoast then
        if hasTrait(traits, "Obese") or hasTrait(traits, "Overweight") then
            addNick(out, pool, "obese" .. sex, maxN)
        end
        if hasTrait(traits, "Underweight") or hasTrait(traits, "VeryUnderweight")
            or hasTrait(traits, "Very Underweight") or hasTrait(traits, "Emaciated") then
            addNick(out, pool, "thin" .. sex, maxN)
        end
        if hasTrait(traits, "Illiterate") then
            addNick(out, pool, "dumb" .. sex, maxN)
        end
        if hasTrait(traits, "Unfit") or hasTrait(traits, "OutOfShape") or hasTrait(traits, "Out of Shape") then
            addNick(out, pool, "unfit" .. sex, maxN)
        end
        if hasTrait(traits, "Feeble") or hasTrait(traits, "Weak") then
            addNick(out, pool, "weak" .. sex, maxN)
        end
    end

    if wantPraise or (tone == "neutral" and heatLevel() == "soft") then
        if hasTrait(traits, "Strong") or hasTrait(traits, "Athletic") or hasTrait(traits, "Fit") or hasTrait(traits, "Stout") then
            addNick(out, pool, "strong" .. sex, maxN)
        end
        if hasTrait(traits, "FastLearner") or hasTrait(traits, "Fast Learner") then
            addNick(out, pool, "smart" .. sex, maxN)
        end
    end

    return out
end

--- Build BANTER CARD table for dialogue snapshot.
function B.buildCard(opts)
    opts = opts or {}
    local tone = opts.tone or B.allowedTone(opts.speaker_traits, opts.profession, opts.affinity)
    -- Cap roast if topic isn't roast
    local topic = tostring(opts.topic or "")
    if topic == "smalltalk_praise" then
        if tone == "roast" then tone = "warm" end
    elseif topic == "smalltalk_roast" then
        if tone == "warm" or tone == "neutral" then
            local roastBias = select(1, B.speakerToneBias(opts.speaker_traits, opts.profession, opts.affinity))
            if roastBias < 0.35 then
                tone = "tease"
            else
                tone = "roast"
            end
        end
    elseif B.isSmallTalkTrigger(topic) and topic ~= "smalltalk_roast" then
        if tone == "roast" and heatLevel() ~= "spicy" then
            tone = "tease"
        end
    end

    local nicks = B.nicknamesForTarget(opts.target_traits, opts.target_female, tone)
    if heatLevel() == "soft" and tone == "roast" then
        nicks = {}
        tone = "tease"
    end

    return {
        allowed_tone = tone,
        optional_nicknames = nicks,
        never_force_nickname = true,
        gender_forms = "match_addressee",
        casual = true,
        heat = heatLevel(),
    }
end

--- Weighted topic pick; filters roast/praise by tone gate.
function B.pickTopic(speakerTraits, profession, affinity, preferNamed)
    local tone = B.allowedTone(speakerTraits, profession, affinity)
    local roastBias = select(1, B.speakerToneBias(speakerTraits, profession, affinity))
    local praiseBias = select(2, B.speakerToneBias(speakerTraits, profession, affinity))

    local pool = {}
    local total = 0
    for i = 1, #B.Topics do
        local t = B.Topics[i]
        local w = t.weight or 1
        if t.needs == "roast" then
            if tone ~= "roast" and tone ~= "tease" then
                w = 0
            elseif roastBias < 0.35 then
                w = 0
            else
                w = w * (0.5 + roastBias)
            end
        elseif t.needs == "praise" then
            if praiseBias < 0.3 then
                w = 0
            else
                w = w * (0.5 + praiseBias)
            end
        end
        if preferNamed and t.address == "named" then
            w = w * 1.25
        end
        if w > 0 then
            pool[#pool + 1] = { t = t, w = w }
            total = total + w
        end
    end
    if total <= 0 or #pool == 0 then
        return B.Topics[1]
    end
    local r = 0
    if ZombRand then
        r = ZombRand(math.floor(total * 100)) / 100
    else
        r = math.random() * total
    end
    local acc = 0
    for i = 1, #pool do
        acc = acc + pool[i].w
        if r <= acc then
            return pool[i].t
        end
    end
    return pool[#pool].t
end

function B.affinityDeltaForTopic(topicId)
    if topicId == "smalltalk_roast" then return -1 end
    if topicId == "smalltalk_praise" then return 1 end
    if topicId == "smalltalk_ask" or topicId == "smalltalk_joke" then return 0 end
    return 0
end

function B.rollChance(boost)
    boost = tonumber(boost) or 0
    local base = B.BASE_ROLL_CHANCE + boost
    if base > 55 then base = 55 end
    if base < 5 then base = 5 end
    local roll = 100
    if ZombRand then
        roll = ZombRand(100)
    else
        roll = math.random(0, 99)
    end
    return roll < base
end

if C and C.log then
    C.log("Banter module loaded")
end
