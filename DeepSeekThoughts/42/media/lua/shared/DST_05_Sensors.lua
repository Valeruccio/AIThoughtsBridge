--[[
  Raw situation sensors for Build 42 (client/shared).
  Returns a plain table — no prompt text here.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Sensors = DSThoughts.Sensors or {}

local Sen = DSThoughts.Sensors

local function round2(n)
    if n == nil then return 0 end
    return math.floor(n * 100 + 0.5) / 100
end

local function moodleLevel(player, names)
    local moodles = player:getMoodles()
    if not moodles then return 0 end
    for i = 1, #names do
        local name = names[i]
        local mt = nil
        if MoodleType then
            mt = MoodleType[name]
            if not mt and MoodleType.FromString then
                pcall(function() mt = MoodleType.FromString(name) end)
            end
            if not mt and MoodleType.fromString then
                pcall(function() mt = MoodleType.fromString(name) end)
            end
        end
        if mt then
            local ok, lvl = pcall(function()
                return moodles:getMoodleLevel(mt) or 0
            end)
            if ok and lvl and lvl > 0 then return lvl end
        end
    end
    return 0
end

--- Map 0..1 (or 0..100) vital to moodle-ish 0..4 when MoodleType fails on B42
local function vitalAsMoodle(v, highIsBad)
    local n = tonumber(v) or 0
    if n > 1.5 then n = n / 100 end -- 0..100 scale
    if not highIsBad then
        -- endurance: 1 = fine
        n = 1 - math.min(1, math.max(0, n))
    end
    n = math.min(1, math.max(0, n))
    if n < 0.15 then return 0 end
    if n < 0.35 then return 1 end
    if n < 0.55 then return 2 end
    if n < 0.75 then return 3 end
    return 4
end

local function collectMoodles(player, vitals)
    local m = {
        hungry = moodleLevel(player, { "Hungry" }),
        thirsty = moodleLevel(player, { "Thirsty", "Thirst" }),
        tired = moodleLevel(player, { "Tired" }),
        stressed = moodleLevel(player, { "Stressed", "Stress" }),
        panic = moodleLevel(player, { "Panic" }),
        pain = moodleLevel(player, { "Pain" }),
        bored = moodleLevel(player, { "Bored" }),
        unhappy = moodleLevel(player, { "Unhappy" }),
        wet = moodleLevel(player, { "Wet" }),
        sick = moodleLevel(player, { "Sick" }),
        has_a_cold = moodleLevel(player, { "HasACold", "Cold" }),
        drunk = moodleLevel(player, { "Drunk" }),
        endurance = moodleLevel(player, { "Endurance" }),
        heavy_load = moodleLevel(player, { "HeavyLoad" }),
        bleeding = moodleLevel(player, { "Bleeding" }),
        injured = moodleLevel(player, { "Injured" }),
        hyperthermia = moodleLevel(player, { "Hyperthermia" }),
        hypothermia = moodleLevel(player, { "Hypothermia" }),
        windchill = moodleLevel(player, { "Windchill" }),
        food_eaten = moodleLevel(player, { "FoodEaten" }),
    }
    -- B42: MoodleType often missing — fill from vitals so illness/pain hooks still fire
    if vitals then
        if (m.panic or 0) == 0 then m.panic = vitalAsMoodle(vitals.panic, true) end
        if (m.stressed or 0) == 0 then m.stressed = vitalAsMoodle(vitals.stress, true) end
        if (m.pain or 0) == 0 then m.pain = vitalAsMoodle(vitals.pain, true) end
        if (m.hungry or 0) == 0 then m.hungry = vitalAsMoodle(vitals.hunger, true) end
        if (m.thirsty or 0) == 0 then m.thirsty = vitalAsMoodle(vitals.thirst, true) end
        if (m.tired or 0) == 0 then m.tired = vitalAsMoodle(vitals.fatigue, true) end
        if (m.bored or 0) == 0 then m.bored = vitalAsMoodle(vitals.boredom, true) end
        if (m.unhappy or 0) == 0 then m.unhappy = vitalAsMoodle(vitals.unhappy, true) end
        if (m.wet or 0) == 0 then m.wet = vitalAsMoodle(vitals.wetness, true) end
        local fs = tonumber(vitals.food_sickness) or 0
        if (m.sick or 0) == 0 and fs > 5 then
            m.sick = vitalAsMoodle(fs > 1.5 and (fs / 100) or fs, true)
        end
        -- Knox without food sickness: rising stress + infection flag → mild sick cue
        if (m.sick or 0) == 0 and vitals.knox and (tonumber(vitals.stress) or 0) > 0.4 then
            m.sick = math.max(1, vitalAsMoodle(vitals.stress, true))
        end
        if (m.drunk or 0) == 0 then
            m.drunk = vitalAsMoodle(vitals.drunkenness, true)
        end
    end
    return m
end

local function collectVitals(player)
    local vitals = {
        health = 100,
        hunger = 0,
        thirst = 0,
        fatigue = 0,
        endurance = 1,
        stress = 0,
        panic = 0,
        pain = 0,
        wetness = 0,
        boredom = 0,
        unhappy = 0,
        food_sickness = 0,
        infection_level = 0,
        knox = false,
        smoke_stress = 0,
        time_since_smoke = 0,
        drunkenness = 0,
    }
    local B = DSThoughts and DSThoughts.B42 or nil
    -- Each field isolated: one missing B42 getter must not abort the rest
    if B and B.getHunger then
        vitals.hunger = round2(B.getHunger(player) or 0)
        vitals.thirst = round2(B.getThirst(player) or 0)
        vitals.fatigue = round2(B.getFatigue(player) or 0)
        vitals.endurance = round2(B.getEndurance(player) or 1)
        vitals.pain = round2(B.getPain(player) or 0)
        vitals.stress = round2(B.getStress(player) or 0)
        vitals.panic = round2(B.getPanic(player) or 0)
        vitals.smoke_stress = round2(B.getNicotineWithdrawal(player) or 0)
        vitals.boredom = round2(B.getBoredom(player) or 0)
        vitals.unhappy = round2(B.getUnhappiness(player) or 0)
        vitals.wetness = round2(B.getWetness(player) or 0)
        if B.getIntoxication then
            vitals.drunkenness = round2(B.getIntoxication(player) or 0)
        end
    else
        local stats = nil
        pcall(function() stats = player:getStats() end)
        local function one(getter, default)
            local v = default
            pcall(function()
                if stats and stats[getter] then
                    v = stats[getter](stats) or default
                end
            end)
            return round2(v)
        end
        vitals.hunger = one("getHunger", 0)
        vitals.thirst = one("getThirst", 0)
        vitals.fatigue = one("getFatigue", 0)
        vitals.endurance = one("getEndurance", 1)
        vitals.pain = one("getPain", 0)
        vitals.stress = one("getStress", 0)
        vitals.panic = one("getPanic", 0)
    end
    pcall(function()
        if player.getTimeSinceLastSmoke then
            vitals.time_since_smoke = round2(player:getTimeSinceLastSmoke() or 0)
        end
    end)
    pcall(function()
        local body = player:getBodyDamage()
        if not body then return end
        if body.getOverallBodyHealth then
            vitals.health = round2(body:getOverallBodyHealth() or 100)
        end
        if body.getWetness and (not B or not B.getWetness) then
            vitals.wetness = round2(body:getWetness() or 0)
        end
        if body.getBoredomLevel and (vitals.boredom or 0) == 0 then
            vitals.boredom = round2(body:getBoredomLevel() or 0)
        end
        if body.getUnhappynessLevel and (vitals.unhappy or 0) == 0 then
            vitals.unhappy = round2(body:getUnhappynessLevel() or 0)
        end
        if body.getFoodSicknessLevel then
            vitals.food_sickness = round2(body:getFoodSicknessLevel() or 0)
        end
        if body.getInfectionLevel then
            vitals.infection_level = round2(body:getInfectionLevel() or 0)
        end
        if body.IsInfected then
            vitals.knox = body:IsInfected() and true or false
        elseif body.isInfected then
            vitals.knox = body:isInfected() and true or false
        end
    end)
    return vitals
end

local function bodyPartKey(bp)
    local key = "body"
    pcall(function()
        local t = nil
        if bp.getType then
            t = bp:getType()
        end
        if t ~= nil then
            local s = tostring(t)
            -- BodyPartType.Hand_R → Hand_R
            s = s:gsub("^.*%.", ""):gsub("^BodyPartType%.", "")
            key = s
        end
    end)
    return key
end

local function normalizePartKey(raw)
    raw = tostring(raw or "body")
    local map = {
        Hand_L = "left_hand",
        Hand_R = "right_hand",
        ForeArm_L = "left_forearm",
        ForeArm_R = "right_forearm",
        UpperArm_L = "left_upper_arm",
        UpperArm_R = "right_upper_arm",
        Torso_Upper = "chest",
        Torso_Lower = "abdomen",
        Neck = "neck",
        Head = "head",
        Groin = "groin",
        UpperLeg_L = "left_thigh",
        UpperLeg_R = "right_thigh",
        LowerLeg_L = "left_shin",
        LowerLeg_R = "right_shin",
        Foot_L = "left_foot",
        Foot_R = "right_foot",
    }
    if map[raw] then return map[raw] end
    -- already normalized / unknown
    local lower = string.lower(raw):gsub("%s+", "_")
    return lower
end

local function collectWounds(player)
    local w = {
        bites = 0,
        scratches = 0,
        cuts = 0,
        deep = 0,
        fractures = 0,
        bleeding_parts = 0,
        burns = 0,
        parts = {},
        primary = nil,
        severity = "none",
        pain_max = 0,
    }
    pcall(function()
        local body = player:getBodyDamage()
        if not body then return end
        if body.getNumPartsBleeding then
            w.bleeding_parts = body:getNumPartsBleeding() or 0
        end
        local parts = body:getBodyParts()
        if not parts then return end
        local ranked = {}
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            if bp then
                local bitten = bp.bitten and bp:bitten()
                local scratched = bp.scratched and bp:scratched()
                local cut = bp.isCut and bp:isCut()
                local deep = bp.deepWounded and bp:deepWounded()
                local frac = bp.getFractureTime and (bp:getFractureTime() or 0) > 0
                local burn = bp.getBurnTime and (bp:getBurnTime() or 0) > 0
                local bleeding = bp.bleeding and bp:bleeding()
                if bleeding and (not body.getNumPartsBleeding) then
                    w.bleeding_parts = w.bleeding_parts + 1
                end
                if bitten then w.bites = w.bites + 1 end
                if scratched then w.scratches = w.scratches + 1 end
                if cut then w.cuts = w.cuts + 1 end
                if deep then w.deep = w.deep + 1 end
                if frac then w.fractures = w.fractures + 1 end
                if burn then w.burns = w.burns + 1 end

                local kind = nil
                local rank = 0
                if bitten then
                    kind = "bite"
                    rank = 90
                elseif deep then
                    kind = "deep"
                    rank = 80
                elseif frac then
                    kind = "fracture"
                    rank = 75
                elseif cut then
                    kind = "cut"
                    rank = 50
                elseif scratched then
                    kind = "scratch"
                    rank = 30
                elseif burn then
                    kind = "burn"
                    rank = 40
                end
                if kind then
                    local pain = 0
                    pcall(function()
                        if bp.getPain then pain = tonumber(bp:getPain()) or 0 end
                    end)
                    if pain > (w.pain_max or 0) then
                        w.pain_max = pain
                    end
                    local part = normalizePartKey(bodyPartKey(bp))
                    ranked[#ranked + 1] = {
                        part = part,
                        kind = kind,
                        bleeding = bleeding and true or false,
                        pain = pain,
                        -- scratch/cut alone are not bites — do not invent zombie blame
                        zombie_bite = (kind == "bite"),
                        _rank = rank + math.min(20, pain),
                    }
                end
            end
        end
        table.sort(ranked, function(a, b)
            return (a._rank or 0) > (b._rank or 0)
        end)
        for i = 1, math.min(6, #ranked) do
            local e = ranked[i]
            e._rank = nil
            w.parts[#w.parts + 1] = e
        end
        if #w.parts > 0 then
            w.primary = w.parts[1]
        end
        -- Severity for prompt grounding
        if (w.bites or 0) > 0 or (w.deep or 0) > 0 or (w.fractures or 0) > 0
            or (w.bleeding_parts or 0) >= 2 then
            w.severity = "severe"
        elseif (w.cuts or 0) > 0 or (w.bleeding_parts or 0) >= 1 or (w.burns or 0) > 0
            or (w.pain_max or 0) >= 40 then
            w.severity = "moderate"
        elseif (w.scratches or 0) > 0 or (w.pain_max or 0) > 0 then
            w.severity = "minor"
        else
            w.severity = "none"
        end
    end)
    return w
end

local function weatherInfo()
    local out = {
        rain = false,
        fog = false,
        snow = false,
        temp = nil,
        daylight = nil,
    }
    pcall(function()
        local climate = getClimateManager and getClimateManager() or nil
        if not climate then return end
        if climate.getRainIntensity then
            out.rain = climate:getRainIntensity() > 0.1
        elseif climate.getPrecipitationIntensity then
            out.rain = climate:getPrecipitationIntensity() > 0.1
        end
        if climate.getFogIntensity then
            out.fog = climate:getFogIntensity() > 0.2
        end
        if climate.getSnowStrength then
            out.snow = climate:getSnowStrength() > 0.05
        end
        if climate.getTemperature then
            out.temp = round2(climate:getTemperature())
        end
        if climate.getDayLightStrength then
            out.daylight = round2(climate:getDayLightStrength())
        end
    end)
    return out
end

local function partOfDay()
    local gt = getGameTime and getGameTime() or nil
    if not gt then return "day", 12 end
    local hour = gt:getHour() or 12
    local part = "day"
    if hour >= 22 or hour < 5 then
        part = "night"
    elseif hour < 8 then
        part = "dawn"
    elseif hour >= 18 then
        part = "evening"
    end
    return part, hour
end

local function scanNearSquares(player, radius)
    local flags = {
        fire_near = false,
        corpse_near = false,
        broken_window_near = false,
        house_alarmed = false,
    }
    pcall(function()
        local sq = player:getSquare()
        local cell = getCell and getCell() or (player.getCell and player:getCell()) or nil
        if not sq or not cell then return end
        local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
        for dx = -radius, radius do
            for dy = -radius, radius do
                local s = cell:getGridSquare(px + dx, py + dy, pz)
                if s then
                    if s.haveFire and s:haveFire() then
                        flags.fire_near = true
                    end
                    pcall(function()
                        if s.getDeadBody and s:getDeadBody() then
                            flags.corpse_near = true
                        end
                    end)
                    pcall(function()
                        local objs = nil
                        if s.getStaticMovingObjects then
                            objs = s:getStaticMovingObjects()
                        end
                        if objs then
                            for i = 0, objs:size() - 1 do
                                local o = objs:get(i)
                                if o and instanceof(o, "IsoDeadBody") then
                                    flags.corpse_near = true
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local objs = s:getObjects()
                        if not objs then return end
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o then
                                if instanceof(o, "IsoFire") then
                                    local perm = false
                                    if o.isPermanent then perm = o:isPermanent() end
                                    if not perm then flags.fire_near = true end
                                end
                                if instanceof(o, "IsoBrokenGlass") then
                                    flags.broken_window_near = true
                                end
                                if instanceof(o, "IsoWindow") then
                                    if (o.isSmashed and o:isSmashed())
                                        or (o.isDestroyed and o:isDestroyed())
                                        or (o.isGlassRemoved and o:isGlassRemoved()) then
                                        flags.broken_window_near = true
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        if s.getBuilding then
                            local b = s:getBuilding()
                            if b and b.getDef then
                                local def = b:getDef()
                                if def and def.isAlarmed and def:isAlarmed() then
                                    flags.house_alarmed = true
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
    return flags
end

local function zombieCounts(player)
    local z = { visible = 0, chasing = 0, close = 0 }
    pcall(function()
        local stats = player:getStats()
        if not stats then return end
        if stats.getNumVisibleZombies then
            z.visible = stats:getNumVisibleZombies() or 0
        end
        if stats.getNumChasingZombies then
            z.chasing = stats:getNumChasingZombies() or 0
        end
        if stats.getNumVeryCloseZombies then
            z.close = stats:getNumVeryCloseZombies() or 0
        end
    end)
    return z
end

local function itemDisplayName(item)
    if not item then return nil end
    local name = nil
    pcall(function()
        if item.getDisplayName then
            name = item:getDisplayName()
        elseif item.getName then
            name = item:getName()
        elseif item.getType then
            name = item:getType()
        end
    end)
    if name and name ~= "" then
        return tostring(name)
    end
    return nil
end

local function partBroken(v, partId, threshold)
    threshold = threshold or 30
    local broken = false
    pcall(function()
        local part = v:getPartById(partId)
        if part and part.getCondition then
            broken = (part:getCondition() or 100) < threshold
        end
    end)
    return broken
end

--- Vehicle snapshot (B41 BaseVehicle) + edge flags applied later in PromptBuilder
local function collectVehicle(player)
    local vinfo = {
        in_vehicle = false,
        driver = false,
        engine_running = false,
        engine_started = false,
        engine_working = true,
        engine_quality = nil,
        speed = 0,
        hotwired = false,
        key_in = false,
        headlights = false,
        siren = false,
        battery = nil,
        alarmed = false,
        hood_open = false,
        fiddling = false,
        parts_broken = {},
    }
    pcall(function()
        local v = player:getVehicle()
        local seated = v ~= nil
        if not v and player.getUseableVehicle then
            v = player:getUseableVehicle()
        end
        if not v then return end
        vinfo.in_vehicle = seated and true or false
        if seated then
            if v.isDriver then
                vinfo.driver = v:isDriver(player) and true or false
            elseif v.getDriver then
                local d = v:getDriver()
                vinfo.driver = d == player
            end
        end
        if v.isEngineRunning then
            vinfo.engine_running = v:isEngineRunning() and true or false
        end
        if v.isEngineStarted then
            vinfo.engine_started = v:isEngineStarted() and true or false
        end
        if v.isEngineWorking then
            vinfo.engine_working = v:isEngineWorking() and true or false
        end
        if v.getEngineQuality then
            vinfo.engine_quality = v:getEngineQuality()
        end
        if v.getCurrentSpeedKmHour then
            vinfo.speed = math.floor((v:getCurrentSpeedKmHour() or 0) + 0.5)
        end
        if v.isHotwired then
            vinfo.hotwired = v:isHotwired() and true or false
        end
        if v.isKeysInIgnition then
            vinfo.key_in = v:isKeysInIgnition() and true or false
        elseif v.getCurrentKey then
            vinfo.key_in = v:getCurrentKey() ~= nil
        end
        if v.getHeadlightsOn then
            vinfo.headlights = v:getHeadlightsOn() and true or false
        end
        if v.isAlarmed then
            vinfo.alarmed = v:isAlarmed() and true or false
        end
        if v.getSirenStartTime then
            local t = v:getSirenStartTime() or 0
            vinfo.siren = t > 0
        end
        if v.getBatteryCharge then
            vinfo.battery = tonumber(string.format("%.2f", v:getBatteryCharge() or 0))
        end
        pcall(function()
            local hood = v:getPartById("EngineDoor")
            if hood and hood.getDoor then
                local door = hood:getDoor()
                if door and door.isOpen then
                    vinfo.hood_open = door:isOpen() and true or false
                end
            end
        end)
        local broken = {}
        if partBroken(v, "Engine", 35) then broken[#broken + 1] = "engine" end
        if partBroken(v, "Battery", 25) then broken[#broken + 1] = "battery" end
        if partBroken(v, "EngineDoor", 20) then broken[#broken + 1] = "hood" end
        if partBroken(v, "TireFrontLeft", 15) or partBroken(v, "TireFrontRight", 15) then
            broken[#broken + 1] = "tire"
        end
        vinfo.parts_broken = broken
        -- Outside fiddling: usable vehicle with hood open or broken guts
        if (not seated) and (vinfo.hood_open or #broken > 0) then
            vinfo.fiddling = true
        end
    end)
    return vinfo
end

local function comfortInventory(player)
    local c = {
        dirty_clothes = false,
        bloody_clothes = false,
        has_food = false,
        has_water = false,
        has_weapon = false,
        has_cigarettes = false,
        smoker = false,
        in_vehicle = false,
        vehicle_alarmed = false,
        asleep = false,
        outfit = {},
    }
    pcall(function()
        c.in_vehicle = player:getVehicle() ~= nil
    end)
    pcall(function()
        c.asleep = player:isAsleep() and true or false
    end)
    pcall(function()
        -- B42.13+: never HasTrait(String) — use CharacterTraits list via B42.hasTrait
        if DSThoughts.B42 and DSThoughts.B42.hasTrait then
            c.smoker = DSThoughts.B42.hasTrait(player, "Smoker") and true or false
        end
    end)
    pcall(function()
        c.has_weapon = player:getPrimaryHandItem() ~= nil
    end)

    local inv = nil
    pcall(function() inv = player:getInventory() end)
    if inv then
        pcall(function()
            if inv.containsTypeRecurse then
                c.has_food = inv:containsTypeRecurse("Food") and true or false
            elseif inv.containsType then
                c.has_food = inv:containsType("Food") and true or false
            end
        end)
        pcall(function()
            if inv.containsTypeRecurse then
                c.has_cigarettes = inv:containsTypeRecurse("Cigarettes") and true or false
            end
        end)
        -- B42: never chain it:isWaterSource() and it:getUsedDelta() — getUsedDelta may be nil
        pcall(function()
            local items = inv.getItems and inv:getItems() or nil
            if not items or not items.size then return end
            for i = 0, items:size() - 1 do
                if c.has_water then break end
                local it = items:get(i)
                if not it then
                    -- skip
                else
                    local isWater = false
                    pcall(function()
                        if it.isWaterSource then
                            isWater = it:isWaterSource() and true or false
                        elseif it.canStoreWater then
                            isWater = it:canStoreWater() and true or false
                        end
                    end)
                    if not isWater then
                        pcall(function()
                            if it.getFluidContainer then
                                local fc = it:getFluidContainer()
                                if fc and fc.getAmount and (fc:getAmount() or 0) > 0 then
                                    isWater = true
                                end
                            end
                        end)
                    end
                    if isWater then
                        local okAmount = true
                        pcall(function()
                            if it.getUsedDelta then
                                okAmount = (it:getUsedDelta() or 0) > 0
                            elseif it.getFluidAmount then
                                okAmount = (it:getFluidAmount() or 0) > 0
                            elseif it.getFluidContainer then
                                local fc = it:getFluidContainer()
                                if fc and fc.getAmount then
                                    okAmount = (fc:getAmount() or 0) > 0
                                end
                            end
                        end)
                        if okAmount then
                            c.has_water = true
                        end
                    end
                end
            end
        end)
    end

    pcall(function()
        local worn = player:getWornItems()
        if not worn or not worn.size then return end
        local outfit = {}
        for i = 0, worn:size() - 1 do
            local item = nil
            pcall(function()
                if worn.getItemByIndex then
                    item = worn:getItemByIndex(i)
                elseif worn.get then
                    item = worn:get(i)
                end
            end)
            if item then
                local blood = 0
                local dirt = 0
                pcall(function()
                    if item.getBloodLevel then blood = item:getBloodLevel() or 0 end
                end)
                pcall(function()
                    if item.getDirtyness then dirt = item:getDirtyness() or 0 end
                end)
                if blood > 0.12 then c.bloody_clothes = true end
                if dirt > 0.25 or blood > 0.12 then c.dirty_clothes = true end
                if #outfit < 4 then
                    local nm = itemDisplayName(item)
                    if nm then
                        outfit[#outfit + 1] = nm
                    end
                end
            end
        end
        c.outfit = outfit
    end)

    pcall(function()
        local v = player:getVehicle()
        if v and v.isAlarmed and v:isAlarmed() then
            c.vehicle_alarmed = true
        end
    end)
    return c
end

local function wetCause(rain, indoors, wetness, enduranceMoodle)
    if (wetness or 0) <= 5 and (enduranceMoodle or 0) <= 0 then
        return "none"
    end
    if rain and not indoors then return "rain" end
    if rain and indoors then return "rain" end
    if (enduranceMoodle or 0) >= 1 then return "sweat" end
    if (wetness or 0) > 10 then return "sweat" end
    return "none"
end

local function trimMediaLine(s, maxLen)
    maxLen = maxLen or 160
    s = tostring(s or "")
    if #s > maxLen then
        return string.sub(s, 1, maxLen - 3) .. "..."
    end
    return s
end

local function getZomboidRadioInst()
    local zr = nil
    pcall(function()
        if getZomboidRadio then
            zr = getZomboidRadio()
        elseif ZomboidRadio and ZomboidRadio.getInstance then
            zr = ZomboidRadio.getInstance()
        end
    end)
    return zr
end

--- Use getChannelsList() (ArrayList). Prefer Map:get(freq) — do NOT Lua-index HashMap.
local function getRadioChannelsList()
    local list = nil
    pcall(function()
        local zr = getZomboidRadioInst()
        if not zr or not zr.getScriptManager then return end
        local mgr = zr:getScriptManager()
        if not mgr then return end
        if mgr.getChannelsList then
            list = mgr:getChannelsList()
        end
    end)
    return list
end

local function readChannelLine(rc)
    if not rc then return nil, "", false end
    local line, name, isTv = nil, "", false
    pcall(function()
        if rc.getLastAiredLine then
            line = rc:getLastAiredLine()
        end
        if rc.GetName then
            name = tostring(rc:GetName() or "")
        end
        if rc.IsTv then
            isTv = rc:IsTv() and true or false
        end
    end)
    if line and tostring(line) ~= "" then
        return tostring(line), name, isTv
    end
    return nil, name, isTv
end

local function mediaFromChannel(rc, fallbackIsTv)
    local line, name, isTv = readChannelLine(rc)
    if not line then return nil end
    if fallbackIsTv then isTv = true end
    return {
        kind = isTv and "tv" or "radio",
        line = trimMediaLine(line, 160),
        channel = name or "",
        active = true,
    }
end

local function findChannelByFreq(freq)
    if freq == nil then return nil end
    local want = tonumber(freq)
    local found = nil

    -- B42-safe: Java Map.get(Integer) — Kahlua can call :get(), not map[freq]
    pcall(function()
        local zr = getZomboidRadioInst()
        if not zr or not zr.getScriptManager then return end
        local mgr = zr:getScriptManager()
        if not mgr or not mgr.getChannels then return end
        local map = mgr:getChannels()
        if not map or not map.get then return end
        if want ~= nil then
            found = map:get(want)
            if not found and math.floor(want) ~= want then
                found = map:get(math.floor(want))
            end
        end
        if not found then
            found = map:get(freq)
        end
    end)
    if found then return found end

    local list = getRadioChannelsList()
    if not list or not list.size then return nil end
    pcall(function()
        local n = list:size()
        for i = 0, n - 1 do
            local rc = list:get(i)
            if rc and rc.GetFrequency then
                local f = rc:GetFrequency()
                if f == freq or (want ~= nil and tonumber(f) == want) then
                    found = rc
                    return
                end
            end
        end
    end)
    return found
end

local function deviceIsOn(deviceData)
    if not deviceData then return false end
    local on = false
    local known = false
    pcall(function()
        if deviceData.getIsTurnedOn then
            known = true
            on = deviceData:getIsTurnedOn() and true or false
        elseif deviceData.isTurnedOn then
            known = true
            on = deviceData:isTurnedOn() and true or false
        end
    end)
    -- If we cannot tell, treat as OFF (avoid stale media spam)
    if not known then return false end
    return on
end

local function deviceLooksLikeMedia(deviceData)
    if not deviceData then return false end
    local ok = false
    pcall(function()
        if deviceData.getIsTelevision and deviceData:getIsTelevision() then
            ok = true
            return
        end
        if deviceData.isTelevision and deviceData:isTelevision() then
            ok = true
            return
        end
        -- Radios / wave devices: channel + power APIs present
        if deviceData.getChannel and (deviceData.getIsTurnedOn or deviceData.isTurnedOn) then
            ok = true
        end
    end)
    return ok
end

local function isMediaWorldObject(o)
    if not o or not o.getDeviceData then return false end
    local yes = false
    pcall(function()
        if instanceof then
            if instanceof(o, "IsoTelevision") or instanceof(o, "IsoRadio") or instanceof(o, "IsoWaveSignal") then
                yes = true
                return
            end
        end
        -- B42 furniture sometimes lacks exact class match — DeviceData is enough
        if deviceLooksLikeMedia(o:getDeviceData()) then
            yes = true
        end
    end)
    return yes
end

--- Proximity already proven — do NOT require global GetPlayerIsListening
--- (that flag stays true after you walk away from the set).
local function tryDeviceMedia(deviceData)
    if not deviceData then return nil end
    if not deviceIsOn(deviceData) then return nil end
    local out = nil
    pcall(function()
        local chan = nil
        if deviceData.getChannel then
            chan = deviceData:getChannel()
        end
        local isTv = false
        if deviceData.getIsTelevision then
            isTv = deviceData:getIsTelevision() and true or false
        elseif deviceData.isTelevision then
            isTv = deviceData:isTelevision() and true or false
        end

        local channelName = ""
        local zr = getZomboidRadioInst()
        if zr and chan and zr.getChannelName then
            pcall(function()
                channelName = tostring(zr:getChannelName(chan) or "")
            end)
        end

        if chan ~= nil then
            local rc = findChannelByFreq(chan)
            local m = mediaFromChannel(rc, isTv)
            if m then
                out = m
                if channelName ~= "" and (not out.channel or out.channel == "") then
                    out.channel = channelName
                end
                return
            end
        end
    end)
    return out
end

local function deviceWorldPos(dev)
    local x, y, z = nil, nil, nil
    pcall(function()
        if dev.getX and dev.getY then
            x, y = dev:getX(), dev:getY()
            if dev.getZ then z = dev:getZ() end
            return
        end
        if dev.getSquare then
            local sq = dev:getSquare()
            if sq then
                x, y, z = sq:getX(), sq:getY(), sq:getZ()
            end
        end
    end)
    return x, y, z
end

--- Registered wave devices (B42-friendly fallback when square instanceof misses).
local function scanRegisteredDevices(player, radius)
    local found = nil
    pcall(function()
        local zr = getZomboidRadioInst()
        if not zr or not zr.getDevices then return end
        local sq = player:getSquare()
        if not sq then return end
        local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
        radius = radius or 8
        local r2 = radius * radius
        local devices = zr:getDevices()
        if not devices or not devices.size then return end
        for i = 0, devices:size() - 1 do
            if found and found.line ~= "" then return end
            local dev = devices:get(i)
            if not dev then
                -- skip
            else
                local dx, dy, dz = deviceWorldPos(dev)
                local inRange = false
                if dx ~= nil and dy ~= nil then
                    local ddx = dx - px
                    local ddy = dy - py
                    local sameZ = (dz == nil) or (dz == pz)
                    inRange = sameZ and ((ddx * ddx + ddy * ddy) <= r2)
                end
                if inRange and dev.getDeviceData then
                    local m = tryDeviceMedia(dev:getDeviceData())
                    if m and m.line ~= "" then
                        found = m
                        found.in_range = true
                        return
                    end
                end
            end
        end
    end)
    return found
end

local function scanNearbyMediaDevices(player, radius)
    local found = nil
    pcall(function()
        local sq = player:getSquare()
        local cell = getCell and getCell() or nil
        if not sq or not cell then return end
        local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
        radius = radius or 8
        for dx = -radius, radius do
            for dy = -radius, radius do
                if found and found.line ~= "" then return end
                local s = cell:getGridSquare(px + dx, py + dy, pz)
                if s and s.getObjects then
                    local objs = s:getObjects()
                    for oi = 0, objs:size() - 1 do
                        local o = objs:get(oi)
                        if o and isMediaWorldObject(o) then
                            local m = tryDeviceMedia(o:getDeviceData())
                            if m and m.line ~= "" then
                                found = m
                                found.in_range = true
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
    if found and found.line ~= "" then return found end
    return scanRegisteredDevices(player, radius)
end

local function scanMedia(player)
    local media = { kind = "", line = "", channel = "", active = false, fresh = false, in_range = false }
    pcall(function()
        local Cfg = DSThoughts and DSThoughts.Config or nil
        local radius = (Cfg and Cfg.MediaHearRadius) or 8
        local ttl = (Cfg and Cfg.MediaScanCacheSeconds) or 2.5
        local now = (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
        local sq = player:getSquare()
        local cacheKey = ""
        if sq then
            cacheKey = tostring(sq:getX()) .. "," .. tostring(sq:getY()) .. "," .. tostring(sq:getZ())
        end

        Sen._mediaCache = Sen._mediaCache or { key = "", at = 0, found = nil }
        local cache = Sen._mediaCache
        local found = nil

        if cache.key == cacheKey and cache.at and (now - cache.at) < ttl then
            found = cache.found
        else
            -- Hands / worn radio first (always "in range")
            local hands = {}
            local primary = player:getPrimaryHandItem()
            local secondary = player:getSecondaryHandItem()
            if primary then hands[#hands + 1] = primary end
            if secondary then hands[#hands + 1] = secondary end
            for i = 1, #hands do
                local it = hands[i]
                if it and it.getDeviceData then
                    local m = tryDeviceMedia(it:getDeviceData())
                    if m and m.line ~= "" then
                        found = m
                        found.in_range = true
                        break
                    end
                end
            end

            if not found or found.line == "" then
                found = scanNearbyMediaDevices(player, radius)
            end
            cache.key = cacheKey
            cache.at = now
            cache.found = found
        end

        if found and found.line and found.line ~= "" and found.in_range then
            media = found
            media.active = true
            media.in_range = true
            Sen._reactedMediaLine = Sen._reactedMediaLine or ""
            media.fresh = (found.line ~= "" and found.line ~= Sen._reactedMediaLine)
            media.watching = true
        else
            media = { kind = "", line = "", channel = "", active = false, fresh = false, in_range = false, watching = false }
        end
    end)
    return media
end

--- Full situation table
function Sen.collect(player)
    if not player then return nil end

    local indoors = false
    pcall(function()
        indoors = player:isOutside() == false
    end)

    local vitals = collectVitals(player)
    local moodles = collectMoodles(player, vitals)
    local wounds = collectWounds(player)
    local weather = weatherInfo()
    local part, hour = partOfDay()
    local env = scanNearSquares(player, 2)
    local zombies = zombieCounts(player)
    local comfort = comfortInventory(player)
    comfort.wet_cause = wetCause(weather.rain, indoors, vitals.wetness, moodles.endurance)
    local vehicle = collectVehicle(player)
    comfort.in_vehicle = vehicle.in_vehicle
    if vehicle.alarmed then
        comfort.vehicle_alarmed = true
    end
    local media = scanMedia(player)

    -- combat TTL flags set by Main
    local combat = DSThoughts.CombatFlags or {}
    local ev = DSThoughts.EventFlags or {}
    local now = (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0

    local ammoDry = false
    pcall(function()
        local w = player:getPrimaryHandItem()
        if not w then return end
        if w.isRanged and w:isRanged() then
            local rounds = nil
            if w.getCurrentAmmoCount then
                rounds = w:getCurrentAmmoCount()
            end
            if rounds ~= nil and rounds <= 0 then
                ammoDry = true
            end
        end
    end)

    -- Rising edge + hysteresis: arm at <=8 tiles, clear only when all others >12
    local playerNearbyEdge = false
    pcall(function()
        local Sens = DSThoughts.Sensors
        if not getOnlinePlayers then return end
        local players = getOnlinePlayers()
        if not players then
            Sens._hadPlayerNearby = false
            return
        end
        local px, py = player:getX(), player:getY()
        local anyClose = false -- <= 8
        local anyInsideHyst = false -- <= 12
        for i = 0, players:size() - 1 do
            local o = players:get(i)
            if o and o ~= player and not o:isDead() then
                local dx = (o:getX() or 0) - px
                local dy = (o:getY() or 0) - py
                local d2 = dx * dx + dy * dy
                if d2 <= 64 then
                    anyClose = true
                    anyInsideHyst = true
                elseif d2 <= 144 then
                    anyInsideHyst = true
                end
            end
        end
        local had = Sens._hadPlayerNearby and true or false
        if anyClose and not had then
            playerNearbyEdge = true
            Sens._hadPlayerNearby = true
        elseif not anyInsideHyst then
            Sens._hadPlayerNearby = false
        end
    end)

    local situation = {
        indoors = indoors,
        part_of_day = part,
        hour = hour,
        weather = weather,
        zombies = zombies,
        env = {
            fire_near = env.fire_near,
            corpse_near = env.corpse_near,
            broken_window_near = env.broken_window_near,
            house_alarmed = env.house_alarmed,
        },
        comfort = comfort,
        vehicle = vehicle,
        body = wounds,
        moodles = moodles,
        vitals = vitals,
        media = media,
        combat = {
            in_combat = (combat.in_combat_until or 0) > now,
            took_hit = (combat.took_hit_until or 0) > now,
            landed_hit = (combat.landed_hit_until or 0) > now,
            gunshot = (combat.gunshot_until or 0) > now,
            -- Edge damage for took_damage hook (consume clears pending)
            damage_fresh = (combat.last_damage_until or 0) > now
                and combat.damage_thought_pending == true,
            damage_type = tostring(combat.last_damage_type or ""),
            damage_amount = tonumber(combat.last_damage_amount) or 0,
        },
        events = {
            ammo_dry = ammoDry,
            eating = (ev.eating_until or 0) > now,
            drinking = (ev.drinking_until or 0) > now,
            loot_find_rare = (ev.loot_until or 0) > now,
            first_kill_session = (ev.first_kill_until or 0) > now,
            player_nearby = playerNearbyEdge,
            drunk = (moodles.drunk or 0) >= 2,
        },
    }
    return situation
end

if DSThoughts.Config and DSThoughts.Config.log then
    DSThoughts.Config.log("Sensors loaded")
end
