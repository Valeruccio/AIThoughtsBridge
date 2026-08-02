--[[
  Rank situation into EN prompt hooks + affect (distress/tier).
]]

DSThoughts = DSThoughts or {}
DSThoughts.PromptBuilder = DSThoughts.PromptBuilder or {}

local PB = DSThoughts.PromptBuilder
local H = nil

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function roundish(x)
    return math.floor((x or 0) * 100 + 0.5) / 100
end

local function normalizePanic(v)
    local x = tonumber(v) or 0
    if x > 1.5 then x = x / 100.0 end
    return clamp01(x)
end

function PB.computeAffect(situation)
    situation = situation or {}
    local m = situation.moodles or {}
    local v = situation.vitals or {}
    local z = situation.zombies or {}
    local body = situation.body or {}
    local combat = situation.combat or {}
    local env = situation.env or {}
    local comfort = situation.comfort or {}

    local panic_m = (m.panic or 0) / 4.0
    local stress_m = (m.stressed or 0) / 4.0
    local pain_m = (m.pain or 0) / 4.0
    local panic_v = normalizePanic(v.panic)
    local stress_v = normalizePanic(v.stress)

    local threat = 0
    threat = math.max(threat, math.min(1.0, (z.chasing or 0) / 3.0))
    threat = math.max(threat, math.min(1.0, (z.close or 0) / 2.0))
    threat = math.max(threat, math.min(0.85, (z.visible or 0) / 6.0))
    if env.fire_near then threat = math.max(threat, 0.75) end
    -- Only fresh edge damage spikes threat — sticky took_hit must not invent panic
    if combat.damage_fresh then threat = math.max(threat, 0.8) end
    if combat.gunshot then threat = math.max(threat, 0.55) end
    if combat.in_combat and ((z.chasing or 0) + (z.close or 0)) > 0 then
        threat = math.max(threat, 0.45)
    end

    local bleed = math.min(1.0, (body.bleeding_parts or 0) / 3.0)
    if (m.bleeding or 0) >= 2 then bleed = math.max(bleed, 0.55) end
    if (body.bites or 0) > 0 then threat = math.max(threat, 0.7) end
    -- Knox flag alone is hidden in PZ — sickness moodles / health drive fear
    if (m.sick or 0) >= 2 then threat = math.max(threat, 0.5) end
    if (m.sick or 0) >= 3 or (m.hyperthermia or 0) >= 2 then threat = math.max(threat, 0.62) end
    if (m.has_a_cold or 0) >= 2 then threat = math.max(threat, 0.35) end

    local health = tonumber(v.health) or 100
    if health <= 1.5 then health = health * 100 end
    local health_fear = 0
    if health < 60 then health_fear = (60 - health) / 60 end

    -- Comfort / food alone must not drive death tier
    local comfort_need = 0
    if not comfort.has_food then comfort_need = math.max(comfort_need, 0.22) end
    if not comfort.has_water then comfort_need = math.max(comfort_need, 0.28) end
    if (m.hungry or 0) >= 3 then comfort_need = math.max(comfort_need, 0.32) end
    if (m.thirsty or 0) >= 3 then comfort_need = math.max(comfort_need, 0.35) end
    comfort_need = math.min(0.45, comfort_need) -- hard cap → max uneasy from comfort alone

    local core = math.max(
        panic_m * 1.15,
        panic_v * 1.05,
        stress_m * 0.8,
        stress_v * 0.75,
        pain_m * 0.55,
        threat,
        bleed * 0.7,
        health_fear * 0.65
    )
    local distress = clamp01(math.max(core, comfort_need))

    -- Sealed in a vehicle: chase is scary but not "death" spam unless actually hit
    local inVeh = comfort.in_vehicle or (situation.vehicle and situation.vehicle.in_vehicle)
    if inVeh and not combat.damage_fresh and not env.fire_near and (body.bites or 0) == 0 then
        -- Cap chase-driven distress so we stay scared/uneasy, not death every tick
        local chaseHeavy = (z.chasing or 0) >= 1 or (z.close or 0) >= 1
        if chaseHeavy and bleed < 0.45 and health_fear < 0.45 then
            distress = math.min(distress, 0.58)
        end
    end

    local lethal_signal = threat >= 0.55
        or bleed >= 0.45
        or panic_m >= 0.7
        or panic_v >= 0.7
        or health_fear >= 0.55
        or (body.bites or 0) > 0
        or combat.damage_fresh
        or env.fire_near

    -- Soft chase while driving is not a lethal "death" signal by itself
    if inVeh and not combat.damage_fresh and not env.fire_near and (body.bites or 0) == 0 and bleed < 0.45 then
        if (z.chasing or 0) >= 1 or (z.close or 0) >= 1 then
            -- keep threat for scared, but don't treat as death-tier lethal alone
            if not (panic_m >= 0.7 or panic_v >= 0.7 or health_fear >= 0.55) then
                lethal_signal = false
            end
        end
    end

    local tier = "calm"
    if distress >= 0.9 and lethal_signal then
        tier = "death"
    elseif distress >= 0.75 and (lethal_signal or panic_m >= 0.5 or panic_v >= 0.5) then
        tier = "panic"
    elseif distress >= 0.55 then
        tier = "scared"
    elseif distress >= 0.3 then
        tier = "uneasy"
    end

    -- no_food / comfort-only: never death; cap at uneasy unless health critical
    if not lethal_signal and health_fear < 0.45 then
        if tier == "death" or tier == "panic" then
            tier = "uneasy"
            distress = math.min(distress, 0.48)
        end
    end

    return {
        stress01 = roundish(stress_v > 0 and stress_v or stress_m),
        panic01 = roundish(panic_v > 0 and panic_v or panic_m),
        distress = roundish(distress),
        tier = tier,
        -- Unhappiness / drunk color ALL thoughts (bridge emotional register)
        unhappy_level = math.max(0, math.min(4, tonumber(m.unhappy) or 0)),
        unhappy01 = roundish(normalizePanic(v.unhappy)),
        drunk_level = math.max(0, math.min(4, tonumber(m.drunk) or 0)),
        drunk01 = roundish(normalizePanic(v.drunkenness)),
        -- Illness / fever for logs + bridge lens
        sick_level = math.max(0, math.min(4, tonumber(m.sick) or 0)),
        hyperthermia_level = math.max(0, math.min(4, tonumber(m.hyperthermia) or 0)),
        feverish = ((tonumber(m.sick) or 0) >= 3)
            or ((tonumber(m.hyperthermia) or 0) >= 2)
            or false,
        has_cold = ((tonumber(m.has_a_cold) or 0) >= 1) or false,
        knox = v.knox and true or false,
    }
end

local function tryAdd(candidates, id, active)
    if not active then return end
    H = DSThoughts.PromptHooks
    local def = H and H.get and H.get(id) or nil
    if not def then return end
    table.insert(candidates, {
        id = id,
        priority = def.priority or 10,
        cooldown = def.cooldown or 60,
        micro = def.micro or id,
    })
end

function PB.candidatesFromSituation(sit)
    local c = {}
    if not sit then return c end
    local m = sit.moodles or {}
    local z = sit.zombies or {}
    local env = sit.env or {}
    local body = sit.body or {}
    local comfort = sit.comfort or {}
    local combat = sit.combat or {}
    local weather = sit.weather or {}
    local vitals = sit.vitals or {}

    tryAdd(c, "wound_bite", (body.bites or 0) > 0)
    tryAdd(c, "wound_scratch", (body.scratches or 0) > 0)
    tryAdd(c, "wound_cut", (body.cuts or 0) > 0)
    tryAdd(c, "wound_fracture", (body.fractures or 0) > 0)
    tryAdd(c, "wound_deep", (body.deep or 0) > 0)
    tryAdd(c, "bleed_worse", (body.bleeding_parts or 0) > 0 or (m.bleeding or 0) >= 1)

    local foodSick = tonumber(vitals.food_sickness) or 0
    local hasCold = (m.has_a_cold or 0) >= 1
    local sickLvl = tonumber(m.sick) or 0
    local hyper = tonumber(m.hyperthermia) or 0
    tryAdd(c, "sick_food", foodSick > 25)
    tryAdd(c, "sick_cold", hasCold and foodSick <= 25)
    -- Queasy without clear food cause (includes Knox symptom path)
    tryAdd(
        c,
        "sick_queasy",
        sickLvl >= 1 and sickLvl < 3 and foodSick <= 25 and not hasCold
    )
    tryAdd(
        c,
        "sick_feverish",
        sickLvl >= 3 or (hyper >= 2 and (vitals.knox or sickLvl >= 2))
    )
    -- Rising fever stage: clear cooloff so character actually reacts to worsening
    PB._lastSickLevel = PB._lastSickLevel or 0
    if sickLvl > (PB._lastSickLevel or 0) and sickLvl >= 3 then
        PB._cooldownUntil = PB._cooldownUntil or {}
        PB._cooldownUntil["sick_feverish"] = 0
        PB._cooldownUntil["illness_dread"] = 0
    end
    PB._lastSickLevel = sickLvl
    -- Hidden Knox: dread only with skin wound OR escalating sickness (player-visible cues)
    local skinWound = (body.bites or 0) > 0 or (body.scratches or 0) > 0 or (body.cuts or 0) > 0
    local illnessCue = sickLvl >= 2 or hyper >= 2
        or ((vitals.knox) and (tonumber(vitals.stress) or 0) > 0.5 and foodSick <= 25)
    tryAdd(c, "illness_dread", vitals.knox and (skinWound or illnessCue))

    -- Edge damage only — not sticky took_hit TTL
    tryAdd(c, "took_damage", combat.damage_fresh == true)
    tryAdd(c, "gunshot_echo", combat.gunshot)
    tryAdd(c, "landed_hit_melee", combat.landed_hit and not combat.gunshot)
    -- in_combat thought only with live zed pressure (never invent a hit from TTL alone)
    local zedPressure = ((z.chasing or 0) + (z.close or 0)) > 0
        or ((z.visible or 0) >= 2 and combat.in_combat)
    tryAdd(c, "in_combat", zedPressure and (combat.in_combat or combat.landed_hit or combat.gunshot)
        and not combat.damage_fresh)
    tryAdd(c, "fire_near", env.fire_near)
    tryAdd(c, "zeds_chasing", (z.chasing or 0) >= 1)
    tryAdd(c, "zeds_close", (z.close or 0) >= 1)
    tryAdd(c, "zeds_visible_crowd", (z.visible or 0) >= 3)
    tryAdd(c, "house_alarm", env.house_alarmed)
    tryAdd(c, "vehicle_alarm", comfort.vehicle_alarmed or (sit.vehicle and sit.vehicle.alarmed))

    local veh = sit.vehicle or {}
    tryAdd(c, "veh_crash", sit._veh_crash)
    tryAdd(c, "veh_stalled", sit._veh_stalled)
    tryAdd(c, "veh_wont_start", sit._veh_wont_start)
    tryAdd(c, "veh_engine_start", sit._veh_started)
    tryAdd(c, "veh_entered", sit._veh_entered)
    tryAdd(
        c,
        "veh_repair_fiddle",
        veh.hood_open == true or veh.fiddling == true
    )
    -- Ambient driving: driver + moving (or engine on) — low pri, cooldown handles rarity
    tryAdd(
        c,
        "veh_driving",
        veh.in_vehicle and veh.driver and (veh.engine_running or (veh.speed or 0) > 2)
            and not sit._veh_crash and not sit._veh_stalled
    )

    tryAdd(c, "moodle_panic_high", (m.panic or 0) >= 3)
    tryAdd(c, "moodle_pain", (m.pain or 0) >= 2)
    tryAdd(c, "moodle_bleeding", (m.bleeding or 0) >= 1)
    tryAdd(c, "moodle_injury", (m.injured or 0) >= 2)
    tryAdd(c, "moodle_thirst", (m.thirsty or 0) >= 2)
    tryAdd(c, "moodle_hunger", (m.hungry or 0) >= 2)
    tryAdd(c, "moodle_tired", (m.tired or 0) >= 2)
    tryAdd(c, "moodle_stress", (m.stressed or 0) >= 2)
    tryAdd(c, "moodle_unhappy", (m.unhappy or 0) >= 3)
    tryAdd(c, "moodle_bored", (m.bored or 0) >= 3)
    tryAdd(c, "moodle_heavy_load", (m.heavy_load or 0) >= 2)
    tryAdd(c, "moodle_hot", (m.hyperthermia or 0) >= 2 and not vitals.knox and sickLvl < 2)
    tryAdd(c, "moodle_cold_body", (m.hypothermia or 0) >= 2 or (m.windchill or 0) >= 2)

    local wc = comfort.wet_cause or "none"
    tryAdd(c, "wet_rain", (m.wet or 0) >= 1 and wc == "rain")
    tryAdd(c, "wet_sweat", (m.wet or 0) >= 1 and wc == "sweat")

    tryAdd(c, "smoker_craving", comfort.smoker and ((vitals.smoke_stress or 0) > 0.35 or (vitals.time_since_smoke or 0) > 4))
    tryAdd(c, "no_weapon_threat", (not comfort.has_weapon) and ((z.visible or 0) + (z.close or 0) + (z.chasing or 0)) > 0)
    tryAdd(c, "clothes_filthy", comfort.dirty_clothes)
    tryAdd(c, "clothes_bloody", comfort.bloody_clothes)
    tryAdd(c, "no_food", not comfort.has_food)
    tryAdd(c, "no_water", not comfort.has_water)

    local media = sit.media or {}
    local Arc = DSThoughts.TopicArc
    local mediaTopic = nil
    if media.line and media.line ~= "" then
        mediaTopic = Arc and Arc.mediaTopicId and Arc.mediaTopicId(media.line) or nil
    end
    local mediaCooling = mediaTopic and Arc and Arc.isCooling(mediaTopic)
    local mediaDead = mediaTopic and Arc and Arc.shouldDeadEnd(mediaTopic)

    if mediaCooling then
        -- Same show exhausted — silence, no media hooks
    elseif mediaDead and media.active and media.in_range then
        tryAdd(c, "topic_dead_end", true)
        if Arc and Arc.touch then Arc.touch(mediaTopic) end
    else
        tryAdd(
            c,
            "media_react",
            media.active and media.in_range and media.fresh and media.line and media.line ~= ""
        )
        tryAdd(
            c,
            "media_watching",
            media.active and media.in_range and media.watching and media.line and media.line ~= "" and not media.fresh
        )
        if mediaTopic and Arc and Arc.touch and media.active and media.in_range and media.line and media.line ~= "" then
            Arc.touch(mediaTopic)
        end
    end

    tryAdd(c, "corpse_near", env.corpse_near)
    tryAdd(c, "window_smashed", env.broken_window_near)
    tryAdd(c, "night_outdoors", (not sit.indoors) and sit.part_of_day == "night")
    tryAdd(c, "fog", weather.fog)
    tryAdd(c, "rain_outside", weather.rain and not sit.indoors)
    tryAdd(c, "dawn", sit.part_of_day == "dawn")
    tryAdd(c, "evening", sit.part_of_day == "evening")

    tryAdd(c, "well_fed", (m.food_eaten or 0) >= 1)
    tryAdd(c, "calm_indoors", sit.indoors and (z.visible or 0) == 0 and (z.chasing or 0) == 0 and not combat.in_combat)
    tryAdd(c, "clear_safeish", (z.visible or 0) == 0 and (z.chasing or 0) == 0 and not combat.in_combat and not env.fire_near)

    -- Full B41 trait EFFECT hooks (Catalog-driven)
    if DSThoughts.Catalog and DSThoughts.Catalog.appendTraitCandidates then
        DSThoughts.Catalog.appendTraitCandidates(c, sit, tryAdd)
    end

    -- Always available when not in acute threat — concrete outward seed set in build()
    local safeish = (z.chasing or 0) == 0 and not combat.took_hit and not env.fire_near
    -- Don't mind-wander over the TV: media hooks own that attention
    local mediaBusy = media.active and media.in_range and media.line and media.line ~= ""
    tryAdd(c, "mind_wander", safeish and not mediaBusy)

    tryAdd(c, "waking", sit._edge_wake)
    tryAdd(c, "falling_asleep", sit._edge_sleep)

    local ev = sit.events or {}
    tryAdd(c, "drunk_wave", ev.drunk or (m.drunk or 0) >= 2)
    tryAdd(c, "ammo_dry", ev.ammo_dry)
    tryAdd(c, "eating", ev.eating)
    tryAdd(c, "drinking", ev.drinking)
    tryAdd(c, "loot_find_rare", ev.loot_find_rare)
    tryAdd(c, "first_kill_session", ev.first_kill_session)
    tryAdd(c, "player_nearby", ev.player_nearby)

    return c
end

local WANDER_SEEDS = {
    "A scrap of life memory — beach, partner, dad advice, dumb job — not dust.",
    "Petty desire: cold soda, real coffee, clean sheets, a cigarette break.",
    "Zombie-movie riff or dark joke — one punchline, fresh wording.",
    "Wonder: anyone alive in this city? That car — will it start?",
    "Regret scrap: unsent text, unsaid thanks, old photo in the wallet.",
    "Half-song, whistle impulse, or stupid superstition (knock on wood).",
    "Profession-colored aside without gear checklist.",
}

local function pickWanderSeed()
    local n = #WANDER_SEEDS
    if n < 1 then return "A human scrap — memory or joke — invent fresh wording." end
    PB._wanderIdx = (PB._wanderIdx or (nowSec() % n)) + 1
    if PB._wanderIdx > n then PB._wanderIdx = 1 end
    local jump = (nowSec() + (PB._wanderIdx * 7)) % n
    return WANDER_SEEDS[jump + 1]
end

local BODY_MIRROR_IDS = {
    clothes_filthy = true,
    clothes_bloody = true,
    no_food = true,
    no_water = true,
    calm_indoors = true,
    clear_safeish = true,
}

local THREAT_IDS = {
    wound_bite = true,
    wound_scratch = true,
    wound_cut = true,
    bleed_worse = true,
    took_damage = true,
    fire_near = true,
    zeds_chasing = true,
    zeds_close = true,
    vehicle_alarm = true,
    house_alarm = true,
    gunshot_echo = true,
    moodle_panic_high = true,
    infection_knox = true,
    illness_dread = true,
    sick_feverish = true,
    sick_queasy = true,
    sick_food = true,
    wound_fracture = true,
    wound_deep = true,
    in_combat = true,
    moodle_bleeding = true,
    veh_crash = true,
    veh_stalled = true,
    veh_wont_start = true,
}

-- Persistent / spammy hooks: NEVER force-bypass cooldown
local NO_COOLOFF_BYPASS = {
    infection_knox = true,
    illness_dread = true,
    sick_feverish = true,
    sick_queasy = true,
    sick_food = true,
    sick_cold = true,
    wound_bite = true,
    wound_scratch = true,
    wound_cut = true,
    bleed_worse = true,
    wound_fracture = true,
    wound_deep = true,
    moodle_bleeding = true,
    moodle_injury = true,
    took_damage = true,
    in_combat = true,
    gunshot_echo = true,
    landed_hit_melee = true,
    player_nearby = true,
}

--- Apply cooldowns, sort, trim. Calm: prefer mind_wander over body-mirror stack.
function PB.rank(candidates, maxN, distress, tier)
    maxN = maxN or 5
    distress = distress or 0
    tier = tier or "calm"
    PB._cooldownUntil = PB._cooldownUntil or {}
    local now = nowSec()
    local filtered = {}
    local blockedThreat = {}

    for i = 1, #candidates do
        local h = candidates[i]
        local untilTs = PB._cooldownUntil[h.id] or 0
        if now >= untilTs then
            table.insert(filtered, h)
        elseif THREAT_IDS[h.id] or (h.priority or 0) >= 70 then
            table.insert(blockedThreat, h)
        end
    end

    -- Calm: drop body-mirror / laundry / empty-pack stack so mind can wander
    if (tier == "calm" or distress < 0.3) and distress < 0.55 then
        local kept = {}
        local mirror = {}
        for i = 1, #filtered do
            local h = filtered[i]
            if BODY_MIRROR_IDS[h.id] and h.id ~= "mind_wander" then
                table.insert(mirror, h)
            else
                table.insert(kept, h)
            end
        end
        -- at most one mirror hook, and only if no env/wander better options
        filtered = kept
        local hasWander = false
        for i = 1, #filtered do
            if filtered[i].id == "mind_wander" then
                hasWander = true
                break
            end
        end
        if not hasWander and #mirror > 0 then
            -- still skip mirror — wander injected in build()
        end
        maxN = math.min(maxN, 2)
    end

    table.sort(filtered, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    table.sort(blockedThreat, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)

    if #filtered == 0 and distress >= 0.55 and #blockedThreat > 0 then
        -- Soft chase must respect cooldown — never force-bypass every tick
        -- Persistent infection/wound hooks also must NOT bypass (fever spam)
        local picked = nil
        for i = 1, #blockedThreat do
            local h = blockedThreat[i]
            if h.id ~= "zeds_chasing" and h.id ~= "zeds_close" and h.id ~= "zeds_visible_crowd"
                and not NO_COOLOFF_BYPASS[h.id] then
                picked = h
                break
            end
        end
        if picked then
            table.insert(filtered, picked)
        end
    elseif #filtered == 0 and distress >= 0.55 then
        local best = nil
        for i = 1, #candidates do
            local h = candidates[i]
            if h.id == "zeds_chasing" or h.id == "zeds_close" then
                -- skip — on cooldown or would spam
            elseif NO_COOLOFF_BYPASS[h.id] then
                -- skip — persistent status, wait for real cooloff
            elseif (h.priority or 0) >= 60 and (not best or (h.priority or 0) > (best.priority or 0)) then
                best = h
            end
        end
        if best then table.insert(filtered, best) end
    end

    local out = {}
    local maxP = 0
    for i = 1, math.min(maxN, #filtered) do
        local h = filtered[i]
        local micro = h.micro
        if h.id == "mind_wander" then
            micro = pickWanderSeed()
        end
        table.insert(out, {
            id = h.id,
            priority = h.priority,
            micro = micro,
        })
        if (h.priority or 0) > maxP then maxP = h.priority or 0 end
        local cd = h.cooldown or 60
        if h.id == "mind_wander" then
            cd = math.max(cd, 270)
        elseif h.id == "zeds_chasing" or h.id == "zeds_close" then
            cd = math.max(cd, 180)
        elseif (h.priority or 0) < 20 then
            cd = math.max(cd, 200)
        end
        PB._cooldownUntil[h.id] = now + cd
    end

    local force = maxP >= 55
    -- Acute = lethal edges only (not soft chase at pri 93)
    local acute = maxP >= 95
    return out, maxP, force, acute
end

function PB.applyEdges(prev, curr)
    if not curr then return end
    curr._edge_wake = false
    curr._edge_sleep = false
    curr._veh_entered = false
    curr._veh_started = false
    curr._veh_stalled = false
    curr._veh_wont_start = false
    curr._veh_crash = false
    if not prev then return end

    local pb = prev.body or {}
    local cb = curr.body or {}
    if (cb.bites or 0) > (pb.bites or 0) then
        curr._new_bite = true
    end
    if (cb.bleeding_parts or 0) > (pb.bleeding_parts or 0) then
        curr._bleed_worse = true
    end

    local pc = prev.comfort or {}
    local cc = curr.comfort or {}
    if pc.asleep and not cc.asleep then
        curr._edge_wake = true
    end
    if (not pc.asleep) and cc.asleep then
        curr._edge_sleep = true
    end

    local pv = prev.vehicle or {}
    local cv = curr.vehicle or {}
    if (not pv.in_vehicle) and cv.in_vehicle then
        curr._veh_entered = true
    end
    if (not pv.engine_running) and cv.engine_running then
        curr._veh_started = true
    end
    -- Stalled: was running + moving, now dead engine while still inside
    if pv.engine_running and (not cv.engine_running) and cv.in_vehicle then
        if (pv.speed or 0) >= 8 then
            curr._veh_stalled = true
        end
    end
    -- Won't start: was cranking / trying, then stopped without catching
    if pv.engine_started and (not cv.engine_started) and (not cv.engine_running) and cv.in_vehicle then
        curr._veh_wont_start = true
    end
    -- Dead battery / non-working while driver + key/hotwire, still not running (soft signal)
    if cv.in_vehicle and cv.driver and (not cv.engine_running) and (not cv.engine_started) then
        local deadBatt = (cv.battery ~= nil and cv.battery < 0.05)
        local broken = not cv.engine_working
        if (deadBatt or broken) and (cv.key_in or cv.hotwired) and not pv.engine_running then
            -- only edge once when condition newly appears or after failed crank already set
            if deadBatt and ((pv.battery or 1) >= 0.05 or pv.engine_running) then
                curr._veh_wont_start = true
            elseif broken and pv.engine_working then
                curr._veh_wont_start = true
            end
        end
    end
    -- Crash: sharp speed collapse while still in vehicle
    if cv.in_vehicle and (pv.speed or 0) >= 22 and (cv.speed or 0) < 4 then
        curr._veh_crash = true
    end
end

function PB.buildDigest(sit, hooks, tier)
    local lines = {}
    if not sit then return lines end
    hooks = hooks or {}
    tier = tier or "calm"
    local hookSet = {}
    for i = 1, #hooks do
        hookSet[hooks[i].id] = true
    end

    local calm = (tier == "calm")
    table.insert(lines, (sit.indoors and "indoors" or "outdoors") .. " " .. tostring(sit.part_of_day or "?"))
    local w = sit.weather or {}
    if w.rain then table.insert(lines, "raining") end
    if w.fog then table.insert(lines, "fog") end
    if w.temp ~= nil then table.insert(lines, "temp=" .. tostring(w.temp)) end
    -- no dust/light bait — bridge VOICE BANK drives calm topics

    local media = sit.media or {}
    -- Include line for both fresh react and still-watching (LLM needs the show text)
    if media.active and media.in_range and media.line and media.line ~= "" then
        local kind = media.kind or "radio"
        local ch = media.channel or ""
        local line = tostring(media.line)
        if #line > 160 then line = string.sub(line, 1, 157) .. "..." end
        local tag = media.fresh and "media" or "media_still"
        table.insert(lines, tag .. "=" .. kind .. (ch ~= "" and ("/" .. ch) or "") .. ": " .. line)
    end

    local z = sit.zombies or {}
    if (z.visible or 0) > 0 or (z.chasing or 0) > 0 or (z.close or 0) > 0 or not calm then
        table.insert(lines, "zeds visible=" .. tostring(z.visible or 0) .. " chasing=" .. tostring(z.chasing or 0) .. " close=" .. tostring(z.close or 0))
    end
    local env = sit.env or {}
    if env.corpse_near then table.insert(lines, "corpse_near") end
    if env.broken_window_near then table.insert(lines, "broken_window_near") end
    if env.fire_near then table.insert(lines, "fire_near") end
    local c = sit.comfort or {}
    if c.wet_cause and c.wet_cause ~= "none" then
        table.insert(lines, "wet_cause=" .. tostring(c.wet_cause))
    end

    local veh = sit.vehicle or {}
    if veh.in_vehicle then
        local eng = veh.engine_running and "on" or "off"
        local mode = "riding"
        if veh.driver and veh.engine_running then
            mode = "driving"
        elseif veh.driver then
            mode = "driver_idle"
        end
        local bits = {
            "vehicle=" .. mode,
            "speed=" .. tostring(veh.speed or 0),
            "engine=" .. eng,
        }
        if veh.hotwired then bits[#bits + 1] = "hotwired" end
        if veh.key_in then bits[#bits + 1] = "key_in" end
        if veh.hood_open then bits[#bits + 1] = "hood_open" end
        if veh.parts_broken and #veh.parts_broken > 0 then
            bits[#bits + 1] = "broken=" .. table.concat(veh.parts_broken, ",")
        end
        table.insert(lines, table.concat(bits, " "))
    end

    -- Outfit / laundry / gear ONLY when those hooks are active — never as calm bait
    if hookSet["clothes_filthy"] or hookSet["clothes_bloody"] then
        if c.dirty_clothes then table.insert(lines, "dirty_clothes") end
        if c.bloody_clothes then table.insert(lines, "bloody_clothes") end
        if c.outfit and #c.outfit > 0 then
            table.insert(lines, "outfit=" .. table.concat(c.outfit, ", "))
        end
    end
    if hookSet["no_food"] or hookSet["no_water"] or hookSet["no_weapon_threat"] then
        if hookSet["no_food"] then table.insert(lines, "has_food=false") end
        if hookSet["no_water"] then table.insert(lines, "has_water=false") end
        if hookSet["no_weapon_threat"] then table.insert(lines, "has_weapon=false") end
    end

    local b = sit.body or {}
    -- Attested wound facts only when matching hooks are active
    if hookSet["bleed_worse"] or hookSet["moodle_bleeding"] then
        if (b.bleeding_parts or 0) > 0 then
            table.insert(lines, "bleed_parts=" .. tostring(b.bleeding_parts))
        end
    end
    if hookSet["wound_bite"] and (b.bites or 0) > 0 then
        table.insert(lines, "bites=" .. tostring(b.bites))
    end
    if hookSet["wound_scratch"] and (b.scratches or 0) > 0 then
        table.insert(lines, "scratches=" .. tostring(b.scratches))
    end
    if hookSet["wound_cut"] and (b.cuts or 0) > 0 then
        table.insert(lines, "cuts=" .. tostring(b.cuts))
    end
    if hookSet["wound_fracture"] and (b.fractures or 0) > 0 then
        table.insert(lines, "fractures=" .. tostring(b.fractures))
    end
    if hookSet["wound_deep"] and (b.deep or 0) > 0 then
        table.insert(lines, "deep_wounds=" .. tostring(b.deep))
    end
    -- Location-aware wound tokens for bridge Fact Card (primary only)
    local primary = b.primary
    if type(primary) == "table" and primary.part and primary.kind then
        local woundHooks = hookSet["wound_bite"] or hookSet["wound_scratch"] or hookSet["wound_cut"]
            or hookSet["wound_deep"] or hookSet["wound_fracture"] or hookSet["took_damage"]
            or hookSet["moodle_pain"] or hookSet["moodle_injury"] or hookSet["moodle_bleeding"]
            or hookSet["bleed_worse"]
        if woundHooks then
            table.insert(lines, "wound=" .. tostring(primary.kind) .. "_" .. tostring(primary.part))
            if b.severity and b.severity ~= "none" then
                table.insert(lines, "wound_severity=" .. tostring(b.severity))
            end
        end
    end
    local v = sit.vitals or {}
    local m = sit.moodles or {}
    if hookSet["sick_food"] then
        table.insert(lines, "food_sickness=" .. tostring(v.food_sickness or 0))
    end
    if hookSet["sick_cold"] then
        table.insert(lines, "has_cold=" .. tostring(m.has_a_cold or 0))
    end
    if hookSet["sick_queasy"] or hookSet["sick_feverish"] then
        table.insert(lines, "sick_level=" .. tostring(m.sick or 0))
        if (m.hyperthermia or 0) >= 1 then
            table.insert(lines, "hyperthermia=" .. tostring(m.hyperthermia))
        end
    end
    if hookSet["illness_dread"] or hookSet["infection_knox"] then
        table.insert(lines, "illness_suspicion=yes")
        if (m.sick or 0) >= 1 then
            table.insert(lines, "sick_level=" .. tostring(m.sick))
        end
    end
    local combat = sit.combat or {}
    if hookSet["took_damage"] and combat.damage_fresh then
        local dtype = tostring(combat.damage_type or "")
        if dtype ~= "" and dtype ~= "nil" then
            table.insert(lines, "damage_type=" .. dtype)
        else
            table.insert(lines, "damage=just_now")
        end
        if (combat.damage_amount or 0) > 0 then
            table.insert(lines, "damage_amount=" .. tostring(combat.damage_amount))
        end
    end
    if hookSet["in_combat"] then
        table.insert(lines, "zeds_engaged=yes")
    end
    if hookSet["gunshot_echo"] then
        table.insert(lines, "gunshot_echo=yes")
    end
    while #lines > 12 do
        table.remove(lines)
    end
    return lines
end

function PB.build(player, prevSituation, opts)
    opts = opts or {}
    local maxHooks = opts.max_hooks or 5
    local sit = DSThoughts.Sensors and DSThoughts.Sensors.collect(player) or nil
    if not sit then
        return {
            situation = nil,
            prompt_hooks = {},
            affect = { stress01 = 0, panic01 = 0, distress = 0, tier = "calm" },
            digest = {},
            max_priority = 0,
            force = false,
            acute = false,
        }
    end

    PB.applyEdges(prevSituation, sit)

    -- Attach trait ids so EFFECT hooks can fire (B42 TraitCollection-safe)
    sit.traits = sit.traits or {}
    pcall(function()
        if DSThoughts.B42 and DSThoughts.B42.collectTraitIds then
            sit.traits = DSThoughts.B42.collectTraitIds(player) or {}
            return
        end
        local traits = player:getTraits()
        if not traits then return end
        local ids = {}
        if traits.size and traits.get then
            for i = 0, traits:size() - 1 do
                local tid = traits:get(i)
                if tid then ids[#ids + 1] = tostring(tid) end
            end
        end
        sit.traits = ids
    end)

    local candidates = PB.candidatesFromSituation(sit)
    -- Edge bite only if not already present (avoid duplicate wound_bite in hooks)
    if sit._new_bite then
        local hasBite = false
        for i = 1, #candidates do
            if candidates[i].id == "wound_bite" then hasBite = true break end
        end
        if not hasBite then
            tryAdd(candidates, "wound_bite", true)
        end
    end
    if sit._bleed_worse then
        tryAdd(candidates, "bleed_worse", true)
    end

    local affect = PB.computeAffect(sit)
    local tier = affect.tier or "calm"
    if tier == "calm" then
        maxHooks = math.min(maxHooks, 2)
    end

    local hooks, maxP, force, acute = PB.rank(candidates, maxHooks, affect.distress or 0, tier)

    -- Driving past chasers: longer cooldown so cabin isn't a thought machine-gun
    -- NOTE: never name a local `until` — reserved word in Lua/Kahlua (breaks whole file load)
    pcall(function()
        local inVeh = (sit.comfort and sit.comfort.in_vehicle) or (sit.vehicle and sit.vehicle.in_vehicle)
        if not inVeh then return end
        PB._cooldownUntil = PB._cooldownUntil or {}
        local cdUntil = nowSec() + 180
        for i = 1, #hooks do
            local id = hooks[i].id
            if id == "zeds_chasing" or id == "zeds_close" then
                local cur = PB._cooldownUntil[id] or 0
                if cdUntil > cur then PB._cooldownUntil[id] = cdUntil end
            end
        end
    end)

    -- Guarantee a wander seed when calm and no strong hook won
    if tier == "calm" and (affect.distress or 0) < 0.35 then
        local media = sit.media or {}
        local mediaBusy = media.active and media.in_range and media.line and media.line ~= ""
        local hasStrong = false
        local hasWander = false
        for i = 1, #hooks do
            if (hooks[i].priority or 0) >= 50 then hasStrong = true end
            if hooks[i].id == "mind_wander" then hasWander = true end
        end
        -- Never inject mind_wander while sitting on TV/radio
        if not hasStrong and not hasWander and not mediaBusy then
            local wanderCdUntil = (PB._cooldownUntil and PB._cooldownUntil["mind_wander"]) or 0
            if nowSec() >= wanderCdUntil then
                table.insert(hooks, 1, {
                    id = "mind_wander",
                    priority = 16,
                    micro = pickWanderSeed(),
                })
                if #hooks > 2 then
                    while #hooks > 2 do table.remove(hooks) end
                end
                PB._cooldownUntil = PB._cooldownUntil or {}
                PB._cooldownUntil["mind_wander"] = nowSec() + 270
                maxP = math.max(maxP, 16)
            end
        elseif hasWander and not mediaBusy then
            for i = 1, #hooks do
                if hooks[i].id == "mind_wander" then
                    hooks[i].micro = pickWanderSeed()
                end
            end
            maxP = math.max(maxP, 16)
        end
    end

    local digest = PB.buildDigest(sit, hooks, tier)

    -- Topic arc + emotion phase for bridge / Mode B
    local Arc = DSThoughts.TopicArc
    local activeTopic = ""
    local media = sit.media or {}
    if media.active and media.in_range and media.line and media.line ~= "" and Arc and Arc.mediaTopicId then
        activeTopic = Arc.mediaTopicId(media.line)
    else
        for i = 1, #hooks do
            if hooks[i].id == "mind_wander" and Arc and Arc.innerTopicId then
                activeTopic = Arc.innerTopicId("wander")
                Arc.touch(activeTopic)
                break
            end
            if hooks[i].id == "topic_dead_end" and media.line and Arc then
                activeTopic = Arc.mediaTopicId(media.line)
                break
            end
        end
    end
    local emotion = "wander"
    if Arc and Arc.resolveEmotionPhase then
        emotion = Arc.resolveEmotionPhase(sit, hooks, affect)
    end
    local arcFields = (Arc and Arc.exportForSnapshot and Arc.exportForSnapshot(activeTopic)) or {}
    arcFields.emotion_phase = emotion

    return {
        situation = sit,
        prompt_hooks = hooks,
        affect = affect,
        digest = digest,
        max_priority = maxP,
        force = force,
        acute = acute,
        arc_topic = arcFields.arc_topic or activeTopic or "",
        arc_phase = arcFields.arc_phase or "",
        arc_turns = arcFields.arc_turns or 0,
        emotion_phase = emotion,
    }
end

if DSThoughts.Config and DSThoughts.Config.log then
    DSThoughts.Config.log("PromptBuilder loaded")
end
