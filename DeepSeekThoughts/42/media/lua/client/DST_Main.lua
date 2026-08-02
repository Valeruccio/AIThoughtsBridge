--[[
  Client: event-driven thoughts + rare calm ambient.
  Single inbox poll (throttled); UI draw is render-only.
  Session-only: combat flags, sticky, cooldowns reset on load (see onGameStart).
]]

local C = DSThoughts.Config

-- Dedicated-server process: no local thoughts UI/bridge
if isServer and isServer() and not (isClient and isClient()) then
    return
end

DSThoughts.CombatFlags = DSThoughts.CombatFlags or {
    in_combat_until = 0,
    took_hit_until = 0,
    landed_hit_until = 0,
    gunshot_until = 0,
    -- Edge damage fact (thought eligibility); separate from short awareness TTL
    last_damage_until = 0,
    last_damage_type = "",
    last_damage_amount = 0,
    damage_thought_pending = false,
}

DSThoughts.EventFlags = DSThoughts.EventFlags or {
    eating_until = 0,
    drinking_until = 0,
    loot_until = 0,
    first_kill_until = 0,
    session_kills = 0,
}

local sticky = {
    text = nil,
    startMs = 0,
    durationMs = 9000,
}

local lastThoughtAttemptMs = 0
local lastDigestKey = ""
local lastSoftAmbientMs = 0
local lastMediaLine = ""
local lastPollMs = 0
-- Deferred combat: bump flags immediately; collect once on next poll budget
local deferredCombatGap = nil
local lastCombatThoughtAt = 0
local COMBAT_THOUGHT_MIN_GAP = 120 -- hard floor between combat-deferred thoughts
-- Mode B client: waiting for host bridge reply (broadcast)
local netPending = false
local netLastRequestAt = 0
local netLastRequestId = nil

local function nowMs()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    if getTimestamp then
        return getTimestamp() * 1000
    end
    return (os.time() or 0) * 1000
end

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function digestKey(snap)
    local d = snap and snap.digest or {}
    return table.concat(d, "|")
end

local function sayThought(player, text, speaker)
    if not text or text == "" then return end
    if not player then
        player = getPlayer()
    end
    if not player then return end
    if #text > 220 then
        text = string.sub(text, 1, 217) .. "..."
    end
    -- Private thoughts: no speaker prefix (inner voice). Optional legacy prefix if provided & different.
    sticky.text = text
    sticky.startMs = nowMs()
    sticky.durationMs = math.floor((C.ThoughtDisplaySeconds or 9) * 1000)
    sticky.kind = "thought"
    -- ThinkAloud is local-only and can attract zombies — separate from dialogue flag
    if C.ThinkAloud and player.Say then
        pcall(function()
            player:Say(text)
        end)
    end
end

local function drawStickyThought()
    if not sticky.text then return end
    local player = getPlayer()
    if not player or player:isDead() then
        sticky.text = nil
        return
    end

    local elapsed = nowMs() - sticky.startMs
    if elapsed >= sticky.durationMs then
        sticky.text = nil
        return
    end

    local fadeMs = 1250
    local alpha = 1.0
    local remaining = sticky.durationMs - elapsed
    if remaining < fadeMs then
        alpha = remaining / fadeMs
    end

    local pn = player:getPlayerNum()
    local x = isoToScreenX(pn, player:getX(), player:getY(), player:getZ())
    local y = isoToScreenY(pn, player:getX(), player:getY(), player:getZ()) - 55
    -- Cool italic-feel thought color (distinct from warm dialogue)
    getTextManager():DrawStringCentre(UIFont.Medium, x, y, sticky.text, 0.72, 0.82, 1.0, alpha * 0.92)
end

local function drawHudOverlay()
    drawStickyThought()
    if DSThoughts.DialogueClient and DSThoughts.DialogueClient.drawSticky then
        DSThoughts.DialogueClient.drawSticky()
    end
end

local function logRequestState(snap, gapOverride)
    -- Always print — diagnostics for pacing/hook mismatches (game console + stdout)
    local sit = snap and snap.situation or {}
    local v = sit.vitals or {}
    local body = sit.body or {}
    local combat = sit.combat or {}
    local aff = snap and snap.affect or {}
    local meta = snap and snap.meta or {}
    local hooks = snap and snap.prompt_hooks or {}
    local ids = {}
    for i = 1, #hooks do
        ids[#ids + 1] = tostring(hooks[i].id) .. "(" .. tostring(hooks[i].priority or "?") .. ")"
    end
    local ch = snap and snap.character or {}
    print("[DST] ========================================================")
    print("[DST] REQUEST id=" .. tostring(snap and snap.request_id))
    print(
        "[DST] char="
            .. tostring(ch.forename or "?")
            .. " sex="
            .. ((ch.female and "F") or "M")
            .. " prof="
            .. tostring(ch.profession or "?")
    )
    print(
        "[DST] affect tier="
            .. tostring(aff.tier)
            .. " distress="
            .. tostring(aff.distress)
            .. " unhappy="
            .. tostring(aff.unhappy_level or (sit.moodles and sit.moodles.unhappy) or 0)
            .. "/4"
            .. " drunk="
            .. tostring(aff.drunk_level or (sit.moodles and sit.moodles.drunk) or 0)
            .. "/4"
            .. " sick="
            .. tostring(aff.sick_level or (sit.moodles and sit.moodles.sick) or 0)
            .. "/4"
            .. " fever="
            .. tostring(aff.feverish and "yes" or "no")
            .. " emo="
            .. tostring(snap and snap.emotion_phase)
            .. " acute="
            .. tostring(meta.acute)
            .. " gap="
            .. tostring(gapOverride)
    )
    print("[DST] hooks=" .. (#ids > 0 and table.concat(ids, ", ") or "(none)"))
    print(
        "[DST] combat took_hit="
            .. tostring(combat.took_hit)
            .. " in_combat="
            .. tostring(combat.in_combat)
            .. " landed="
            .. tostring(combat.landed_hit)
            .. " gun="
            .. tostring(combat.gunshot)
    )
    print(
        "[DST] body bites="
            .. tostring(body.bites or 0)
            .. " bleed="
            .. tostring(body.bleeding_parts or 0)
            .. " deep="
            .. tostring(body.deep or 0)
            .. " | knox="
            .. tostring(v.knox)
            .. " infection="
            .. tostring(v.infection_level)
            .. " health="
            .. tostring(v.health)
            .. " pain="
            .. tostring(v.pain)
    )
    local z = sit.zombies or {}
    print(
        "[DST] world "
            .. ((sit.indoors and "indoors") or "outdoors")
            .. " "
            .. tostring(sit.part_of_day or "?")
            .. " zeds v="
            .. tostring(z.visible or 0)
            .. " c="
            .. tostring(z.chasing or 0)
            .. " close="
            .. tostring(z.close or 0)
    )
    -- Mismatch hints (same logic as bridge diagnostics)
    local primary = hooks[1] and hooks[1].id or ""
    local inf = tonumber(v.infection_level) or 0
    if (v.knox or inf > 15) and primary == "took_damage" then
        print("[DST] DIAG! infection/knox present but primary hook=took_damage (combat TTL dominating)")
    end
    local ILLNESS_IDS = {
        illness_dread = true,
        infection_knox = true,
        sick_queasy = true,
        sick_feverish = true,
        sick_food = true,
        sick_cold = true,
    }
    if (v.knox or inf > 15) and not ILLNESS_IDS[primary] then
        local hasInf = false
        for i = 1, #hooks do
            if ILLNESS_IDS[hooks[i].id] then hasInf = true break end
        end
        if not hasInf then
            print("[DST] DIAG! knox/infection active but illness hook missing (cooloff/filter?)")
        end
    end
    if (tonumber(body.bites) or 0) > 0 and primary == "took_damage" then
        print("[DST] DIAG! bites>0 but hook=took_damage not wound_bite")
    end
    print("[DST] ========================================================")
end

local function consumeDamageThought(hooks)
    hooks = hooks or {}
    for i = 1, #hooks do
        if hooks[i].id == "took_damage" then
            DSThoughts.CombatFlags = DSThoughts.CombatFlags or {}
            DSThoughts.CombatFlags.damage_thought_pending = false
            DSThoughts.CombatFlags.last_damage_until = 0
            return
        end
    end
end

local function markRequestSent(snap, gapOverride)
    logRequestState(snap, gapOverride)
    local hooks = snap.prompt_hooks or {}
    local aff = snap.affect or {}
    consumeDamageThought(hooks)
    lastThoughtAttemptMs = nowMs()
    lastDigestKey = digestKey(snap)
    -- Advance topic arc
    pcall(function()
        local Arc = DSThoughts.TopicArc
        if not Arc then return end
        local topic = snap.arc_topic
        if (not topic or topic == "") and snap.situation and snap.situation.media and snap.situation.media.line then
            topic = Arc.mediaTopicId(snap.situation.media.line)
        end
        if not topic or topic == "" then return end
        local hasDead = false
        for i = 1, #hooks do
            if hooks[i].id == "topic_dead_end" then hasDead = true break end
        end
        Arc.noteSpoken(topic)
        if hasDead or Arc.shouldDeadEnd(topic) then
            Arc.enterCooloff(topic)
        end
    end)
    pcall(function()
        local hasMediaHook = false
        for i = 1, #hooks do
            local id = hooks[i].id
            if id == "media_react" or id == "media_watching" or id == "topic_dead_end" then
                hasMediaHook = true
                break
            end
        end
        if not hasMediaHook or not DSThoughts.Sensors then return end
        local m = snap.situation and snap.situation.media or nil
        if m and m.line and m.line ~= "" then
            DSThoughts.Sensors._reactedMediaLine = tostring(m.line)
        end
    end)
end

local function writeSnap(player, snap, gapOverride)
    if not snap then return false end
    local N = DSThoughts.Net
    local minGap = gapOverride
    if minGap == nil then
        minGap = C.MinSecondsBetweenThoughts or 18
    end

    -- Mode B: networked client → host bridge (everyone sees the same reply)
    if N and N.useServerProxy and N.useServerProxy() then
        if netPending then return false end
        local now = nowSec()
        if (now - (netLastRequestAt or 0)) < minGap then
            return false
        end
        local slim = N.slimSnapshot(snap)
        if not slim or not slim.request_id then return false end
        local ok = false
        pcall(function()
            sendClientCommand(N.MODULE, N.CMD_REQUEST, slim)
            ok = true
        end)
        if not ok then
            C.log("sendClientCommand failed")
            return false
        end
        netPending = true
        netLastRequestAt = now
        netLastRequestId = slim.request_id
        markRequestSent(snap, gapOverride)
        return true
    end

    -- SP / local bridge
    if not DSThoughts.Bridge then return false end
    if not DSThoughts.Bridge.canRequest(gapOverride) then
        return false
    end
    if DSThoughts.Bridge.writeRequest(snap) then
        markRequestSent(snap, gapOverride)
        return true
    end
    return false
end

local function flushDeferredCombat()
    if not deferredCombatGap then return end
    local gap = deferredCombatGap
    deferredCombatGap = nil
    local player = getPlayer()
    if not player or player:isDead() then return end
    if C.Enabled == false then return end
    if not DSThoughts.State then return end
    -- Hard anti-spam: combat hits must not narrate every swing
    if (nowSec() - (lastCombatThoughtAt or 0)) < COMBAT_THOUGHT_MIN_GAP then
        return
    end
    local snap = DSThoughts.State.collect(player)
    if not snap then return end
    local hooks = snap.prompt_hooks or {}
    if #hooks == 0 then
        return
    end
    gap = math.max(gap or 18, COMBAT_THOUGHT_MIN_GAP)
    if writeSnap(player, snap, gap) then
        lastCombatThoughtAt = nowSec()
    end
end

local function pollInboxThrottled()
    local N = DSThoughts.Net
    -- Mode B clients: thoughts arrive via OnServerCommand, not local inbox
    if N and N.useServerProxy and N.useServerProxy() then
        flushDeferredCombat()
        -- Unlock stale net pending
        if netPending and netLastRequestAt and (nowSec() - netLastRequestAt) > 180 then
            netPending = false
            C.log("Mode B pending timeout")
        end
        return
    end

    if not DSThoughts or not DSThoughts.Bridge then return end
    local now = nowMs()
    local pending = DSThoughts.Bridge._pending
    local interval = pending and (C.PollPendingMs or 500) or (C.PollIdleMs or 2000)
    if (now - lastPollMs) < interval then
        return
    end
    lastPollMs = now

    flushDeferredCombat()

    local player = getPlayer()
    if not player or player:isDead() then return end
    local thought = DSThoughts.Bridge.pollResponse()
    if thought and thought ~= "" then
        sayThought(player, thought, nil)
    end
end

local function onServerCommand(module, command, args)
    local N = DSThoughts.Net
    if not N or module ~= N.MODULE then return end
    args = args or {}
    if command == N.CMD_THOUGHT then
        netPending = false
        local player = getPlayer()
        local thought = args.thought
        -- Private thought: only show if for us (server already targets; ignore speaker prefix)
        if thought and thought ~= "" then
            sayThought(player, thought, nil)
        end
    elseif command == N.CMD_DIALOGUE_LINE then
        if DSThoughts.DialogueClient and DSThoughts.DialogueClient.onDialogueLine then
            DSThoughts.DialogueClient.onDialogueLine(args)
        end
    elseif command == N.CMD_DIALOGUE_ENDED then
        if DSThoughts.DialogueClient and DSThoughts.DialogueClient.onDialogueEnded then
            DSThoughts.DialogueClient.onDialogueEnded(args)
        end
    elseif command == N.CMD_DIALOGUE_ERROR then
        C.log("Dialogue error: " .. tostring(args.error))
    elseif command == N.CMD_ERROR then
        netPending = false
        C.log("Mode B error: " .. tostring(args.error) .. " id=" .. tostring(args.request_id))
        if DSThoughts.Bridge then
            DSThoughts.Bridge._lastStatus = {
                state = "error",
                detail = tostring(args.error or "error"),
            }
        end
    elseif command == N.CMD_STATUS then
        if DSThoughts.Bridge then
            DSThoughts.Bridge._lastStatus = {
                state = tostring(args.state or "unknown"),
                detail = tostring(args.detail or ""),
                provider = tostring(args.provider or ""),
                model = tostring(args.model or ""),
            }
        end
    end
end

local function resetSessionState()
    -- Session-only: cooldowns / edges / media reaction do not persist across load
    lastThoughtAttemptMs = 0
    lastSoftAmbientMs = 0
    lastDigestKey = ""
    lastMediaLine = ""
    lastPollMs = 0
    deferredCombatGap = nil
    lastCombatThoughtAt = 0
    sticky.text = nil
    netPending = false
    netLastRequestAt = 0
    netLastRequestId = nil
    if DSThoughts.Bridge then
        DSThoughts.Bridge._pending = false
        DSThoughts.Bridge._lastRequestAt = 0
        DSThoughts.Bridge._lastRequestId = nil
    end
    if DSThoughts.State then
        DSThoughts.State._prevSituation = nil
    end
    if DSThoughts.Sensors then
        DSThoughts.Sensors._reactedMediaLine = ""
        DSThoughts.Sensors._mediaCache = nil
    end
    if DSThoughts.PromptBuilder then
        DSThoughts.PromptBuilder._cooldownUntil = {}
    end
    if DSThoughts.TopicArc and DSThoughts.TopicArc.reset then
        DSThoughts.TopicArc.reset()
    end
    DSThoughts.EventFlags = {
        eating_until = 0,
        drinking_until = 0,
        loot_until = 0,
        first_kill_until = 0,
        session_kills = 0,
    }
    DSThoughts.CombatFlags = {
        in_combat_until = 0,
        took_hit_until = 0,
        landed_hit_until = 0,
        gunshot_until = 0,
        last_damage_until = 0,
        last_damage_type = "",
        last_damage_amount = 0,
        damage_thought_pending = false,
    }
end

local function onCreatePlayer(playerIndex, player)
    if player ~= getPlayer() then return end
    if C.refreshIoPaths then C.refreshIoPaths() end
    if DSThoughts.Settings then DSThoughts.Settings.load() end
    local snap = DSThoughts.State and DSThoughts.State.collect(player) or nil
    if snap and snap.character then
        local ch = snap.character
        C.log(
            "Character card ready: "
            .. tostring(ch.forename) .. " " .. tostring(ch.surname)
            .. " profession=" .. tostring(ch.profession)
            .. " female=" .. tostring(ch.female)
            .. " lang=" .. tostring(C.Language)
        )
    end
    lastThoughtAttemptMs = 0
    lastSoftAmbientMs = 0
    lastDigestKey = ""
end

local function onGameStart()
    local player = getPlayer()
    if not player then return end
    if C.refreshIoPaths then C.refreshIoPaths() end
    if DSThoughts.Settings then DSThoughts.Settings.load() end
    if DSThoughts.Sandbox and DSThoughts.Sandbox.apply then
        DSThoughts.Sandbox.apply()
    end
    if not DSThoughts or not DSThoughts.State then
        C.log("State module missing on game start")
        return
    end
    C.log("Game start — pacing module + throttled poll")
    resetSessionState()
end

local function onEveryOneMinute()
    local player = getPlayer()
    if not player or player:isDead() then return end
    if DSThoughts.DialogueClient and DSThoughts.DialogueClient.scanSituational then
        pcall(function()
            DSThoughts.DialogueClient.scanSituational(player)
        end)
    end
    if C.Enabled == false then return end
    if not DSThoughts or not DSThoughts.State then return end
    if DSThoughts.Sandbox and DSThoughts.Sandbox.apply then
        DSThoughts.Sandbox.apply()
    end

    local Pac = DSThoughts.Pacing
    if not Pac then return end

    local snap = DSThoughts.State.collect(player)
    if not snap then return end

    local meta = snap.meta or {}
    local maxP = meta.max_priority or 0
    local acute = Pac.resolveAcute(snap)
    local ids = Pac.hookIds(snap)
    local hooks = snap.prompt_hooks or {}
    local aff = snap.affect or {}
    local tier = aff.tier or "calm"
    local dkey = digestKey(snap)
    local now = nowMs()

    local mediaLine = ""
    local mediaFresh = false
    local mediaWatching = false
    pcall(function()
        local m = snap.situation and snap.situation.media or nil
        if not m then return end
        if m.line then mediaLine = tostring(m.line) end
        if m.fresh then mediaFresh = true end
        if m.active and m.in_range and mediaLine ~= "" then
            mediaWatching = true
        end
    end)
    if mediaLine == "" then
        lastMediaLine = ""
    end

    if mediaWatching then
        -- Cooloff: stay quiet at the set
        local cooling = false
        pcall(function()
            local Arc = DSThoughts.TopicArc
            if not Arc or mediaLine == "" then return end
            cooling = Arc.isCooling(Arc.mediaTopicId(mediaLine))
        end)
        if cooling then
            return
        end
        if ids["topic_dead_end"] then
            local gap = C.MinSecondsBetweenThoughts or 18
            if writeSnap(player, snap, gap) then
                lastMediaLine = mediaLine
                return
            end
            return
        end
        if ids["media_react"] and mediaFresh then
            local gap = C.MinSecondsBetweenThoughts or 18
            if writeSnap(player, snap, gap) then
                lastMediaLine = mediaLine
                return
            end
        elseif ids["media_watching"] or ids["media_react"] then
            local gap = C.MediaAmbientSeconds or 90
            if writeSnap(player, snap, gap) then
                lastMediaLine = mediaLine
                return
            end
        end
        return
    end

    if ids["veh_crash"] or ids["veh_stalled"] or ids["veh_wont_start"] or ids["veh_engine_start"] then
        local gap = Pac.gapForSnap(snap, ids["veh_crash"] and true or false)
        if writeSnap(player, snap, gap) then
            return
        end
    end

    -- No attested hooks → never invent a thought from sticky distress alone
    if acute or maxP >= 55 then
        if #hooks == 0 then
            return
        end
        local gap = Pac.gapForSnap(snap, acute)
        -- Persistent wound/illness: long gap even if acute
        if ids["illness_dread"] or ids["infection_knox"] or ids["wound_bite"] then
            gap = math.max(gap or 18, 240)
        elseif ids["sick_feverish"] then
            gap = math.max(gap or 18, 120)
        elseif ids["sick_queasy"] or ids["sick_food"] or ids["sick_cold"]
            or ids["bleed_worse"] or ids["wound_scratch"] or ids["wound_cut"] then
            gap = math.max(gap or 18, 160)
        elseif ids["took_damage"] or ids["in_combat"] or ids["gunshot_echo"] then
            gap = math.max(gap or 18, COMBAT_THOUGHT_MIN_GAP)
            if (nowSec() - (lastCombatThoughtAt or 0)) < COMBAT_THOUGHT_MIN_GAP then
                return
            end
        end
        if writeSnap(player, snap, gap) then
            if ids["took_damage"] or ids["in_combat"] or ids["gunshot_echo"] then
                lastCombatThoughtAt = nowSec()
            end
            return
        end
    end

    local calmGap = (C.CalmAmbientSeconds or 270) * 1000
    local minFloor = (C.MinSecondsBetweenThoughts or 18) * 1000
    if (now - lastThoughtAttemptMs) < minFloor then
        return
    end
    if (now - lastSoftAmbientMs) < calmGap then
        return
    end

    -- Calm ambient only with a real soft hook — never distress-without-hooks
    if #hooks == 0 then
        return
    end
    if tier == "calm" or (maxP > 0 and maxP < 55) then
        local m = snap.situation and snap.situation.moodles or {}
        local softDrift = (m.bored or 0) >= 2 or (m.unhappy or 0) >= 2
            or dkey ~= lastDigestKey
            or (now - lastSoftAmbientMs) >= calmGap
        if softDrift then
            local gap = C.CalmAmbientSeconds or 270
            if ids["veh_driving"] then
                gap = C.VehicleAmbientSeconds or 100
            end
            if writeSnap(player, snap, gap) then
                lastSoftAmbientMs = now
            end
        end
    end
end

local function bumpCombat(flag, seconds)
    local t = nowSec() + (seconds or 30)
    DSThoughts.CombatFlags = DSThoughts.CombatFlags or {}
    if flag == "in_combat" then
        DSThoughts.CombatFlags.in_combat_until = t
    elseif flag == "took_hit" then
        DSThoughts.CombatFlags.took_hit_until = t
        DSThoughts.CombatFlags.in_combat_until = t
    elseif flag == "landed_hit" then
        DSThoughts.CombatFlags.landed_hit_until = t
        DSThoughts.CombatFlags.in_combat_until = t
    elseif flag == "gunshot" then
        DSThoughts.CombatFlags.gunshot_until = t
        DSThoughts.CombatFlags.landed_hit_until = t
        DSThoughts.CombatFlags.in_combat_until = t
    end
end

local function deferCombatThought(gapSec)
    local g = math.max(gapSec or 90, COMBAT_THOUGHT_MIN_GAP)
    if deferredCombatGap == nil then
        deferredCombatGap = g
    else
        -- Stacking hits: keep the longer cooloff (anti-spam)
        deferredCombatGap = math.max(deferredCombatGap, g)
    end
end

local function bumpEvent(flag, seconds)
    local t = nowSec() + (seconds or 20)
    DSThoughts.EventFlags = DSThoughts.EventFlags or {}
    if flag == "eating" then
        DSThoughts.EventFlags.eating_until = t
    elseif flag == "drinking" then
        DSThoughts.EventFlags.drinking_until = t
    elseif flag == "loot" then
        DSThoughts.EventFlags.loot_until = t
    elseif flag == "first_kill" then
        DSThoughts.EventFlags.first_kill_until = t
    end
end

local function onWeaponHitXp(owner, weapon, hitObject, damage)
    local player = getPlayer()
    if not player or owner ~= player then return end
    local ranged = false
    pcall(function()
        if weapon and weapon.isRanged and weapon:isRanged() then
            ranged = true
        end
    end)
    if ranged then
        bumpCombat("gunshot", 20)
        deferCombatThought(90)
    else
        bumpCombat("landed_hit", 25)
        deferCombatThought(90)
    end
end

local function onHitZombie(zombie, wielder, bodyPart, weapon)
    local player = getPlayer()
    if not player or wielder ~= player then return end
    bumpCombat("landed_hit", 25)
end

local function onZombieDead(zombie)
    local player = getPlayer()
    if not player or player:isDead() then return end
    DSThoughts.EventFlags = DSThoughts.EventFlags or {}
    DSThoughts.EventFlags.session_kills = (DSThoughts.EventFlags.session_kills or 0) + 1
    if DSThoughts.EventFlags.session_kills == 1 then
        bumpEvent("first_kill", 45)
        deferCombatThought(90)
    end
end

local function onPlayerGetDamage(player, damageType, damage)
    local p = getPlayer()
    if not p or player ~= p then return end
    local dmg = tonumber(damage) or 0
    local dtype = ""
    pcall(function()
        if damageType ~= nil then
            dtype = tostring(damageType)
        end
    end)
    -- Knox / sickness HP ticks are NOT combat hits — illness hooks own that story
    local lower = string.lower(dtype)
    if lower:find("infect", 1, true)
        or lower:find("poison", 1, true)
        or lower:find("foodsick", 1, true)
        or lower:find("sickness", 1, true)
        or lower:find("disease", 1, true)
    then
        return
    end
    -- Tiny ticks (float noise) are not flinches
    if dmg > 0 and dmg < 0.05 then
        return
    end
    DSThoughts.CombatFlags = DSThoughts.CombatFlags or {}
    -- Edge fact for took_damage hook (~4s); consume-on-thought clears pending
    DSThoughts.CombatFlags.last_damage_until = nowSec() + 4
    DSThoughts.CombatFlags.last_damage_type = dtype
    DSThoughts.CombatFlags.last_damage_amount = dmg
    DSThoughts.CombatFlags.damage_thought_pending = true
    -- Short awareness TTL only (must not keep inventing hits for 30s)
    bumpCombat("took_hit", 8)
    deferCombatThought(120)
    -- Ally hurt dialogue when others are nearby
    if dmg >= 5 and DSThoughts.DialogueClient then
        local now = nowSec()
        DSThoughts._lastHurtDlgAt = DSThoughts._lastHurtDlgAt or 0
        if (now - DSThoughts._lastHurtDlgAt) >= 45 then
            local nearby = DSThoughts.DialogueClient.collectNearby(p, C.DialogueStartRadius or 8)
            if #nearby >= 1 then
                DSThoughts._lastHurtDlgAt = now
                local focusName = "Survivor"
                local focusFemale = false
                pcall(function()
                    local desc = p:getDescriptor()
                    if desc and desc.getForename then
                        focusName = tostring(desc:getForename() or focusName)
                    end
                    focusFemale = p:isFemale() and true or false
                end)
                local focusKey = tostring(p)
                if DSThoughts.Memory and DSThoughts.Memory.playerKey then
                    focusKey = DSThoughts.Memory.playerKey(p)
                end
                DSThoughts.DialogueClient.sendEvent("ally_hurt", {
                    focus_key = focusKey,
                    focus_name = focusName,
                    focus_female = focusFemale,
                    address_hint = "named",
                })
            end
        end
    end
end

local function onPlayerAttackFinished(playerObj, weapon)
    local player = getPlayer()
    if not player or playerObj ~= player then return end
    bumpCombat("in_combat", 8)
end

local function onEatFood(food, player)
    local p = getPlayer()
    if not p or player ~= p then return end
    bumpEvent("eating", 25)
    deferCombatThought(22)
end

local function onAddItem(item)
    -- Rare loot heuristic: weapons / literature / alarm clocks etc.
    pcall(function()
        local player = getPlayer()
        if not player or not item then return end
        local cat = ""
        if item.getDisplayCategory then cat = tostring(item:getDisplayCategory() or "") end
        local typ = ""
        if item.getType then typ = tostring(item:getType() or "") end
        local rare = false
        if item.isWeapon and item:isWeapon() then rare = true end
        if cat == "Weapon" or cat == "Literature" or cat == "Communication" then rare = true end
        if typ:find("Pistol") or typ:find("Shotgun") or typ:find("Rifle") or typ:find("Axe") then rare = true end
        if rare then
            bumpEvent("loot", 40)
            deferCombatThought(25)
        end
    end)
end

local function addEv(name, fn)
    if DSThoughts.B42 and DSThoughts.B42.addEvent then
        DSThoughts.B42.addEvent(name, fn)
        return
    end
    pcall(function()
        local ev = Events and Events[name]
        if ev and ev.Add then ev.Add(fn) end
    end)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnGameStart.Add(onGameStart)
Events.OnPlayerUpdate.Add(function(player)
    if player ~= getPlayer() then return end
    pollInboxThrottled()
end)
Events.EveryOneMinute.Add(onEveryOneMinute)
Events.OnPreUIDraw.Add(drawHudOverlay)
addEv("OnServerCommand", onServerCommand)

addEv("OnWeaponHitXp", onWeaponHitXp)
addEv("OnHitZombie", onHitZombie)
addEv("OnZombieDead", onZombieDead)
addEv("OnPlayerGetDamage", onPlayerGetDamage)
-- B42 may expose alternate damage hooks
addEv("OnPlayerGetDamageFromPlayer", onPlayerGetDamage)
addEv("OnPlayerAttackFinished", onPlayerAttackFinished)
addEv("OnEatFood", onEatFood)
addEv("OnEat", onEatFood)
addEv("OnEquipPrimary", function(player, item)
    if player ~= getPlayer() then return end
    onAddItem(item)
end)

-- Dialogue triggers: death / friendly fire / player kill / ally hurt
local function dlgKey(p)
    if DSThoughts.Memory and DSThoughts.Memory.playerKey then
        return DSThoughts.Memory.playerKey(p)
    end
    return tostring(p)
end

local function dlgName(p)
    local name = "Survivor"
    pcall(function()
        local desc = p:getDescriptor()
        if desc and desc.getForename then
            name = tostring(desc:getForename() or name)
            if desc.getSurname then
                local s = tostring(desc:getSurname() or "")
                if s ~= "" then name = name .. " " .. s end
            end
        end
    end)
    return name
end

local function dlgFemale(p)
    local f = false
    pcall(function() f = p:isFemale() and true or false end)
    return f
end

addEv("OnPlayerDeath", function(deadPlayer)
    local me = getPlayer()
    if not me or not deadPlayer then return end
    if not DSThoughts.DialogueClient then return end
    local nearby = DSThoughts.DialogueClient.collectNearby(me, C.DialogueStartRadius or 8)
    local dx = (deadPlayer:getX() or 0) - (me:getX() or 0)
    local dy = (deadPlayer:getY() or 0) - (me:getY() or 0)
    local nearDeath = (dx * dx + dy * dy) <= 144 -- 12 tiles
    if not nearDeath and deadPlayer ~= me then return end
    if deadPlayer == me then
        -- Others will report; skip self
        return
    end
    if #nearby < 1 and not nearDeath then return end
    DSThoughts.DialogueClient.sendEvent("player_died_near", {
        focus_key = dlgKey(deadPlayer),
        focus_name = dlgName(deadPlayer),
        focus_female = dlgFemale(deadPlayer),
        address_hint = "all",
    })
end)

addEv("OnWeaponHitCharacter", function(wielder, target, weapon, damage)
    local me = getPlayer()
    if not me or not DSThoughts.DialogueClient then return end
    if not target or not wielder then return end
    local targetIsPlayer = false
    pcall(function()
        if instanceof and instanceof(target, "IsoPlayer") then
            targetIsPlayer = true
        elseif DSThoughts.B42 and DSThoughts.B42.isPlayer and DSThoughts.B42.isPlayer(target) then
            targetIsPlayer = true
        elseif target.isLocalPlayer or target.getUsername then
            targetIsPlayer = true
        end
    end)
    if not targetIsPlayer then return end
    if target == me and wielder ~= me then
        DSThoughts.DialogueClient.sendEvent("friendly_fire", {
            focus_key = dlgKey(wielder),
            focus_name = dlgName(wielder),
            focus_female = dlgFemale(wielder),
            address_hint = "named",
        })
        DSThoughts.DialogueClient.sendEvent("ally_hurt", {
            focus_key = dlgKey(me),
            focus_name = dlgName(me),
            focus_female = dlgFemale(me),
            address_hint = "named",
        })
    elseif wielder == me and target ~= me then
        local dmg = tonumber(damage) or 0
        if dmg > 0 then
            DSThoughts._lastHitPlayerKey = dlgKey(target)
            DSThoughts._lastHitPlayerAt = nowSec()
            DSThoughts.DialogueClient.sendEvent("friendly_fire", {
                focus_key = dlgKey(target),
                focus_name = dlgName(target),
                focus_female = dlgFemale(target),
                address_hint = "named",
            })
        end
    end
end)

-- If we recently hit a player who then dies nearby → player_kill_player
addEv("OnPlayerDeath", function(deadPlayer)
    local me = getPlayer()
    if not me or not deadPlayer or deadPlayer == me then return end
    if not DSThoughts.DialogueClient then return end
    local hitKey = DSThoughts._lastHitPlayerKey
    local hitAt = DSThoughts._lastHitPlayerAt or 0
    if hitKey and hitKey == dlgKey(deadPlayer) and (nowSec() - hitAt) < 20 then
        DSThoughts.DialogueClient.sendEvent("player_kill_player", {
            focus_key = dlgKey(deadPlayer),
            focus_name = dlgName(deadPlayer),
            focus_female = dlgFemale(deadPlayer),
            address_hint = "void",
        })
    end
end)

C.log("Client module loaded (B42 + thoughts private + dialogue triggers)")
