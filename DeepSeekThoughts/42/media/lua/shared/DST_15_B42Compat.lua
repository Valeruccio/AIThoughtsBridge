--[[
  Build 42 compatibility helpers — CharacterStat, traits, sound, sandbox.
  Soft fallbacks so Sensors/State keep working across B42 patches.
]]

DSThoughts = DSThoughts or {}
DSThoughts.B42 = DSThoughts.B42 or {}

local B42 = DSThoughts.B42

function B42.normalizeTraitId(id)
    id = tostring(id or "")
    id = id:gsub("^[^:]+:", "") -- strip registry namespace if present
    -- B42 enums often UPPER_SNAKE → catalog PascalCase (ADRENALINE_JUNKIE → AdrenalineJunkie)
    if id:match("^[A-Z0-9_]+$") then
        local lower = id:lower()
        id = lower:gsub("_(%w)", function(c)
            return c:upper()
        end):gsub("^%l", string.upper):gsub("_", "")
    end
    return id
end

--- Map B42 CharacterProfession / legacy string → catalog profession id
function B42.normalizeProfessionId(id)
    if id == nil then return "unemployed" end
    local raw = tostring(id)
    -- Object userdata: prefer getName()
    if type(id) == "userdata" or (type(id) == "table" and id.getName) then
        pcall(function()
            if id.getName then
                raw = tostring(id:getName() or raw)
            elseif id.toString then
                raw = tostring(id:toString() or raw)
            end
        end)
    end
    raw = raw:gsub("^[^:]+:", "")
    local lower = string.lower(raw):gsub("[%s%-]+", "_")
    local compact = lower:gsub("_", "")
    local map = {
        unemployed = "unemployed",
        fireofficer = "fireofficer",
        fire_officer = "fireofficer",
        policeofficer = "policeofficer",
        police_officer = "policeofficer",
        parkranger = "parkranger",
        park_ranger = "parkranger",
        constructionworker = "constructionworker",
        construction_worker = "constructionworker",
        securityguard = "securityguard",
        security_guard = "securityguard",
        carpenter = "carpenter",
        burglar = "burglar",
        chef = "chef",
        repairman = "repairman",
        farmer = "farmer",
        fisherman = "fisherman",
        doctor = "doctor",
        veteran = "veteran",
        nurse = "nurse",
        lumberjack = "lumberjack",
        fitnessinstructor = "fitnessInstructor",
        fitness_instructor = "fitnessInstructor",
        burgerflipper = "burgerflipper",
        burger_flipper = "burgerflipper",
        electrician = "electrician",
        engineer = "engineer",
        metalworker = "metalworker",
        metal_worker = "metalworker",
        mechanics = "mechanics",
        mechanic = "mechanics",
        tailor = "tailor",
        smither = "smither",
        blacksmith = "smither",
        rancher = "rancher",
    }
    return map[lower] or map[compact] or compact or "unemployed"
end

--- Profession id for prompts (B42 getCharacterProfession + legacy getProfession)
function B42.collectProfessionId(player)
    local profession = "unemployed"
    if not player then return profession end
    pcall(function()
        local desc = player.getDescriptor and player:getDescriptor() or nil
        if not desc then return end
        local obj = nil
        if desc.getCharacterProfession then
            obj = desc:getCharacterProfession()
        end
        if (obj == nil or obj == "") and desc.getProfession then
            obj = desc:getProfession()
        end
        if obj ~= nil and obj ~= "" then
            profession = B42.normalizeProfessionId(obj)
        end
    end)
    if profession == "" then
        profession = "unemployed"
    end
    return profession
end

--- Collect trait id strings from a player (B42 CharacterTraits + legacy fallbacks).
--- Never probe via HasTrait(String) / CharacterTrait[string] — that floods console on B42.13+.
function B42.collectTraitIds(player)
    local out = {}
    local seen = {}
    if not player then return out end

    local function push(t)
        if not t then return end
        local id = nil
        if type(t) == "string" then
            id = B42.normalizeTraitId(t)
        else
            pcall(function()
                if t.getName then
                    id = B42.normalizeTraitId(tostring(t:getName()))
                elseif t.getType then
                    id = B42.normalizeTraitId(tostring(t:getType()))
                elseif t.toString then
                    id = B42.normalizeTraitId(tostring(t:toString()))
                else
                    id = B42.normalizeTraitId(tostring(t))
                end
            end)
            if (not id or id == "" or id:find("userdata", 1, true)) then
                pcall(function()
                    id = B42.normalizeTraitId(tostring(t))
                end)
            end
        end
        if not id or id == "" then return end
        -- Drop java noise
        if id:find("TraitCollection", 1, true) or id:find("CharacterTraits", 1, true)
            or id:find("CharacterTrait", 1, true) then
            return
        end
        local key = string.lower(id)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = id
    end

    local function scanJavaList(list)
        if not list then return end
        pcall(function()
            if list.size and list.get then
                local n = list:size() or 0
                -- Cap: avoid pathological loops
                if n > 256 then n = 256 end
                for i = 0, n - 1 do
                    local ok, v = pcall(function()
                        return list:get(i)
                    end)
                    if ok and v ~= nil then
                        push(v)
                    end
                end
            end
        end)
        pcall(function()
            if list.iterator then
                local it = list:iterator()
                local guard = 0
                while it and it.hasNext and it:hasNext() and guard < 256 do
                    push(it:next())
                    guard = guard + 1
                end
            end
        end)
    end

    local function scanCharacterTraits(ct)
        if not ct then return end
        -- B42.13+: CharacterTraits.getKnownTraits() -> List<CharacterTrait>
        pcall(function()
            if ct.getKnownTraits then
                scanJavaList(ct:getKnownTraits())
            end
        end)
        if #out > 0 then return end
        -- Map<CharacterTrait, Boolean> of active traits
        pcall(function()
            if not ct.getTraits then return end
            local map = ct:getTraits()
            if not map then return end
            if map.entrySet then
                local set = map:entrySet()
                local it = set and set.iterator and set:iterator() or nil
                local guard = 0
                while it and it.hasNext and it:hasNext() and guard < 256 do
                    local e = it:next()
                    guard = guard + 1
                    local on = true
                    pcall(function()
                        if e.getValue then on = e:getValue() and true or false end
                    end)
                    if on then
                        local key = nil
                        pcall(function()
                            if e.getKey then key = e:getKey() end
                        end)
                        push(key)
                    end
                end
            end
        end)
        if #out > 0 then return end
        -- Iterator on CharacterTraits itself
        pcall(function()
            if ct.iterator then
                local it = ct:iterator()
                local guard = 0
                while it and it.hasNext and it:hasNext() and guard < 256 do
                    push(it:next())
                    guard = guard + 1
                end
            end
        end)
    end

    -- Primary B42 path
    pcall(function()
        if player.getCharacterTraits then
            scanCharacterTraits(player:getCharacterTraits())
        end
    end)
    if #out > 0 then return out end

    pcall(function()
        if player.characterTraits then
            scanCharacterTraits(player.characterTraits)
        end
    end)
    if #out > 0 then return out end

    -- Legacy / descriptor lists (may be ArrayList of traits)
    pcall(function()
        if player.getTraits then
            scanJavaList(player:getTraits())
        end
    end)
    if #out > 0 then return out end

    pcall(function()
        local desc = player.getDescriptor and player:getDescriptor() or nil
        if not desc then return end
        if desc.getCharacterTraits then
            scanCharacterTraits(desc:getCharacterTraits())
        end
        if #out == 0 and desc.getTraits then
            scanJavaList(desc:getTraits())
        end
    end)

    return out
end

--- True if player has trait by catalog/Pascal name.
--- B42.13+: never call HasTrait(String) or CharacterTrait[str] (ResourceLocation spam).
function B42.playerHasTraitName(player, name)
    if not player or not name then return false end
    local want = string.lower(B42.normalizeTraitId(name):gsub("%s+", ""))
    local list = B42.collectTraitIds(player)
    for i = 1, #list do
        local t = string.lower(B42.normalizeTraitId(list[i]):gsub("%s+", ""))
        if t == want then return true end
    end
    return false
end

function B42.hasTrait(playerOrList, name)
    local want = string.lower(B42.normalizeTraitId(name):gsub("%s+", ""))
    local list = playerOrList
    if type(playerOrList) ~= "table" then
        list = B42.collectTraitIds(playerOrList)
    end
    for i = 1, #(list or {}) do
        local t = string.lower(B42.normalizeTraitId(list[i]):gsub("%s+", ""))
        if t == want then return true end
    end
    return false
end

local function readStat(stats, getters)
    if not stats then return nil end
    for i = 1, #getters do
        local name = getters[i]
        -- Kahlua: method may be non-nil userdata; never call without pcall
        local ok, val = pcall(function()
            local fn = stats[name]
            if fn ~= nil then
                return fn(stats)
            end
            return nil
        end)
        if ok and val ~= nil then
            return tonumber(val)
        end
    end
    return nil
end

local function readCharacterStat(player, statConst)
    if not player or not statConst then return nil end
    local v = nil
    pcall(function()
        local stats = player.getStats and player:getStats() or nil
        if stats and stats.get then
            v = stats:get(statConst)
            return
        end
    end)
    if v ~= nil then return tonumber(v) end
    pcall(function()
        if player.getCharacterStat then
            v = player:getCharacterStat(statConst)
        end
    end)
    return v ~= nil and tonumber(v) or nil
end

local function readField(stats, field)
    if not stats or not field then return nil end
    local v = nil
    pcall(function()
        v = stats[field]
    end)
    return v ~= nil and tonumber(v) or nil
end

--- Unified B42/B41 stat read: CharacterStat → legacy getter → public field.
function B42.getStat(player, opts)
    opts = opts or {}
    if not player then return opts.default or 0 end
    local v = nil
    if opts.character_stat and CharacterStat then
        local cs = CharacterStat[opts.character_stat]
        if cs then
            v = readCharacterStat(player, cs)
        end
    end
    if v ~= nil then return v end
    local stats = nil
    pcall(function() stats = player:getStats() end)
    if opts.getters then
        v = readStat(stats, opts.getters)
    end
    if v ~= nil then return v end
    if opts.field then
        v = readField(stats, opts.field)
    end
    if v ~= nil then return v end
    return opts.default or 0
end

--- Panic 0..100-ish (game scale) with CharacterStat fallback.
function B42.getPanic(player)
    return B42.getStat(player, {
        character_stat = "PANIC",
        getters = { "getPanic" },
        field = "Panic",
        default = 0,
    })
end

function B42.getStress(player)
    return B42.getStat(player, {
        character_stat = "STRESS",
        getters = { "getStress" },
        field = "stress",
        default = 0,
    })
end

--- Nicotine withdrawal / former StressFromCigarettes.
function B42.getNicotineWithdrawal(player)
    return B42.getStat(player, {
        character_stat = "NICOTINE_WITHDRAWAL",
        getters = { "getStressFromCigarettes", "getNicotineWithdrawal" },
        field = "stressFromCigarettes",
        default = 0,
    })
end

function B42.getIntoxication(player)
    return B42.getStat(player, {
        character_stat = "INTOXICATION",
        getters = { "getDrunkenness", "getIntoxication" },
        field = "Drunkenness",
        default = 0,
    })
end

function B42.getHunger(player)
    return B42.getStat(player, {
        character_stat = "HUNGER",
        getters = { "getHunger" },
        field = "hunger",
        default = 0,
    })
end

function B42.getThirst(player)
    return B42.getStat(player, {
        character_stat = "THIRST",
        getters = { "getThirst" },
        field = "thirst",
        default = 0,
    })
end

function B42.getFatigue(player)
    return B42.getStat(player, {
        character_stat = "FATIGUE",
        getters = { "getFatigue" },
        field = "fatigue",
        default = 0,
    })
end

function B42.getEndurance(player)
    return B42.getStat(player, {
        character_stat = "ENDURANCE",
        getters = { "getEndurance" },
        field = "endurance",
        default = 1,
    })
end

function B42.getPain(player)
    return B42.getStat(player, {
        character_stat = "PAIN",
        getters = { "getPain" },
        field = "Pain",
        default = 0,
    })
end

function B42.getBoredom(player)
    return B42.getStat(player, {
        character_stat = "BOREDOM",
        getters = { "getBoredom" },
        field = "boredom",
        default = 0,
    })
end

function B42.getUnhappiness(player)
    return B42.getStat(player, {
        character_stat = "UNHAPPINESS",
        getters = { "getUnhappyness", "getUnhappiness" },
        field = nil,
        default = 0,
    })
end

function B42.getWetness(player)
    local v = nil
    if CharacterStat and CharacterStat.WETNESS then
        v = readCharacterStat(player, CharacterStat.WETNESS)
    end
    if v ~= nil then return v end
    pcall(function()
        local body = player:getBodyDamage()
        if body and body.getWetness then
            v = body:getWetness()
        end
    end)
    return tonumber(v) or 0
end

--- Safe Events.X.Add — missing events must not spam console via failed pcall.
function B42.addEvent(eventName, handler)
    if not eventName or not handler or not Events then return false end
    local ok = false
    pcall(function()
        local ev = Events[eventName]
        if ev and ev.Add then
            ev.Add(handler)
            ok = true
        end
    end)
    return ok
end

--- Attract zombies with world sound (quiet dialogues should NOT call this).
function B42.attractZombies(player, radius, volume)
    if not player then return end
    radius = radius or 18
    volume = volume or 60
    local ok = false
    pcall(function()
        if player.addWorldSoundUnlessInvisible then
            player:addWorldSoundUnlessInvisible(radius, volume, false)
            ok = true
        end
    end)
    if ok then return end
    pcall(function()
        if addSound then
            addSound(player, player:getX(), player:getY(), player:getZ(), radius, volume)
        end
    end)
end

--- True if object looks like an IsoPlayer.
function B42.isPlayer(obj)
    if not obj then return false end
    local yes = false
    pcall(function()
        if instanceof and instanceof(obj, "IsoPlayer") then
            yes = true
            return
        end
        if obj.getUsername or obj.isLocalPlayer then
            yes = true
        end
    end)
    return yes
end

--- Read sandbox option: SandboxVars first, then getSandboxOptions.
function B42.sandboxValue(pageKey, optionKey, default)
    local v = nil
    pcall(function()
        if SandboxVars and SandboxVars[pageKey] then
            local t = SandboxVars[pageKey]
            if t and t[optionKey] ~= nil then
                v = t[optionKey]
            end
        end
    end)
    if v ~= nil then return v end
    pcall(function()
        if not getSandboxOptions then return end
        local opts = getSandboxOptions()
        if not opts or not opts.getOptionByName then return end
        local opt = opts:getOptionByName(pageKey .. "." .. optionKey)
        if opt and opt.getValue then
            v = opt:getValue()
        end
    end)
    if v ~= nil then return v end
    return default
end

if DSThoughts.Config and DSThoughts.Config.log then
    DSThoughts.Config.log("B42 compat loaded")
end
