--[[
  Single pacing authority: gap + acute + soft-chase.
  Session-only state lives elsewhere; this module is pure decision logic.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Pacing = DSThoughts.Pacing or {}

local P = DSThoughts.Pacing
local C = DSThoughts.Config

function P.hookIds(snap)
    local hooks = snap and snap.prompt_hooks or {}
    local ids = {}
    for i = 1, #hooks do
        local h = hooks[i]
        if h and h.id then
            ids[h.id] = true
        end
    end
    return ids
end

local function inVehicle(snap)
    local c = snap and snap.situation and snap.situation.comfort or {}
    local v = snap and snap.situation and snap.situation.vehicle or {}
    return c.in_vehicle or v.in_vehicle or false
end

function P.isSoftChase(ids)
    ids = ids or {}
    local hasChase = ids["zeds_chasing"] or ids["zeds_close"]
    if not hasChase then return false end
    if ids["in_combat"] or ids["took_damage"] or ids["gunshot_echo"] then return false end
    if ids["fire_near"] or ids["bleed_worse"] or ids["wound_bite"] or ids["veh_crash"] then
        return false
    end
    return true
end

--- True acute: hit / fire / crash / death-panic — never soft chase alone.
function P.isTrueAcute(snap)
    local aff = snap and snap.affect or {}
    local distress = aff.distress or 0
    local maxP = (snap and snap.meta and snap.meta.max_priority) or 0
    local ids = P.hookIds(snap)
    if P.isSoftChase(ids) then
        return false
    end
    if distress >= 0.75 then return true end
    if maxP >= 95 then return true end
    if ids["took_damage"] or ids["bleed_worse"] or ids["fire_near"] or ids["wound_bite"]
        or ids["wound_scratch"] or ids["wound_cut"] or ids["illness_dread"]
        or ids["sick_feverish"] then
        return true
    end
    if ids["veh_crash"] then return true end
    return false
end

function P.gapForSnap(snap, acute)
    local minFloor = C.MinSecondsBetweenThoughts or 18
    if minFloor < 18 then minFloor = 18 end

    local aff = snap and snap.affect or {}
    local tier = aff.tier or "calm"
    local distress = aff.distress or 0
    local maxP = (snap and snap.meta and snap.meta.max_priority) or 0
    local ids = P.hookIds(snap)
    local emo = (snap and snap.emotion_phase) or (snap and snap.meta and snap.meta.emotion_phase) or "wander"
    local hasCombat = ids["in_combat"] or ids["took_damage"] or ids["gunshot_echo"]
    local hasVehEvent = ids["veh_engine_start"] or ids["veh_wont_start"] or ids["veh_stalled"]
    local softChase = P.isSoftChase(ids)
    local hasIllness = ids["illness_dread"] or ids["infection_knox"] or ids["sick_feverish"]
        or ids["sick_queasy"] or ids["sick_food"] or ids["sick_cold"]

    if ids["topic_dead_end"] then
        return math.max(minFloor, 30)
    end

    if emo == "spike" or ids["ammo_dry"] or ids["eating"] or ids["drinking"] or ids["loot_find_rare"] then
        -- Hits are not spike spam — took_damage has its own long gap below
        if ids["took_damage"] or ids["in_combat"] then
            return math.max(minFloor, 120)
        end
        return math.max(12, math.min(18, minFloor))
    end
    if emo == "aftershock" then
        return math.max(minFloor, 28)
    end
    if emo == "numb" or softChase then
        if inVehicle(snap) then
            return C.ChaseVehicleSeconds or 120
        end
        if distress >= 0.55 then
            return (C.ChaseSeconds or 80) + 20
        end
        return (C.ChaseSeconds or 80) + 30
    end

    if softChase then
        if inVehicle(snap) then
            return C.ChaseVehicleSeconds or 120
        end
        if distress >= 0.55 then
            return C.ChaseSeconds or 80
        end
        return (C.ChaseSeconds or 80) + 15
    end

    -- Combat hit commentary: rare, not every swing
    if ids["took_damage"] then
        return math.max(minFloor, 120)
    end
    if ids["in_combat"] or ids["gunshot_echo"] or ids["landed_hit_melee"] then
        return math.max(minFloor, 90)
    end
    if hasIllness then
        if ids["sick_feverish"] then
            return math.max(minFloor, 120)
        end
        return math.max(minFloor, 180)
    end

    if acute or ids["veh_crash"] or tier == "death" or tier == "panic" or distress >= 0.75 then
        if hasCombat then
            return math.max(minFloor, 90)
        end
        return math.max(18, math.min(25, minFloor + 5))
    end
    if ids["bleed_worse"] or ids["fire_near"] then
        return math.max(minFloor, 60)
    end
    if tier == "scared" or hasCombat then
        return 22
    end
    if ids["zeds_visible_crowd"] and distress < 0.55 then
        return 75
    end
    if emo == "dwell" or tier == "uneasy" or maxP >= 55 then
        return math.max(minFloor, 55)
    end
    if hasVehEvent then
        return 22
    end
    if ids["veh_driving"] or ids["veh_entered"] then
        return C.VehicleAmbientSeconds or 100
    end
    return C.CalmAmbientSeconds or 270
end

--- Normalize acute flag (soft chase never acute).
function P.resolveAcute(snap)
    local meta = snap and snap.meta or {}
    local acute = P.isTrueAcute(snap) or meta.acute
    local ids = P.hookIds(snap)
    if acute and P.isSoftChase(ids) then
        acute = false
    end
    return acute
end
