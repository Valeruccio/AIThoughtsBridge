--[[
  Client: detect serious dialogue triggers and send DialogueEvent to host.
  Also helpers to render dialogue lines + optional zombie-attracting Say.
]]

DSThoughts = DSThoughts or {}
DSThoughts.DialogueClient = DSThoughts.DialogueClient or {}

local DC = DSThoughts.DialogueClient
local C = DSThoughts.Config

-- Dedicated server process: no client dialogue
if isServer and isServer() and not (isClient and isClient()) then
    return
end

DC._lastTriggerAt = DC._lastTriggerAt or {}
DC._inDialogue = false
DC._sticky = DC._sticky or { text = nil, startMs = 0, durationMs = 8000, kind = "dialogue" }

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function nowMs()
    if getTimeInMillis then return getTimeInMillis() end
    return nowSec() * 1000
end

local function triggerCooling(id, sec)
    local t = DC._lastTriggerAt[id] or 0
    return (nowSec() - t) < (sec or 60)
end

local function markTrigger(id)
    DC._lastTriggerAt[id] = nowSec()
end

local function charName(player)
    local name = "Survivor"
    pcall(function()
        local desc = player:getDescriptor()
        if not desc then return end
        if desc.getForename then
            name = tostring(desc:getForename() or name)
            if desc.getSurname then
                local s = tostring(desc:getSurname() or "")
                if s ~= "" then name = name .. " " .. s end
            end
        end
    end)
    return name
end

local function playerKey(player)
    if DSThoughts.Memory and DSThoughts.Memory.playerKey then
        return DSThoughts.Memory.playerKey(player)
    end
    local k = "unknown"
    pcall(function()
        if player.getUsername then
            local u = player:getUsername()
            if u and u ~= "" then k = tostring(u) return end
        end
        if player.getOnlineID then
            k = "oid:" .. tostring(player:getOnlineID() or 0)
        end
    end)
    return k
end

local function onlineId(player)
    local id = 0
    pcall(function()
        if player.getOnlineID then id = player:getOnlineID() or 0 end
    end)
    return id
end

local function isFemale(player)
    local f = false
    pcall(function() f = player:isFemale() and true or false end)
    return f
end

--- Collect nearby living players within start radius.
function DC.collectNearby(player, radius)
    radius = radius or (C.DialogueStartRadius or 8)
    local out = {}
    if not player then return out end
    local px, py = player:getX(), player:getY()
    local r2 = radius * radius
    pcall(function()
        if not getOnlinePlayers then return end
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            local o = players:get(i)
            if o and o ~= player and not o:isDead() then
                local dx = (o:getX() or 0) - px
                local dy = (o:getY() or 0) - py
                if (dx * dx + dy * dy) <= r2 then
                    out[#out + 1] = {
                        key = playerKey(o),
                        name = charName(o),
                        female = isFemale(o),
                        online_id = onlineId(o),
                        player = o,
                    }
                end
            end
        end
    end)
    return out
end

function DC.canNetwork()
    local N = DSThoughts.Net
    if not N or not N.useServerProxy then return false end
    return N.useServerProxy()
end

function DC.sendEvent(trigger, opts)
    opts = opts or {}
    if C.Enabled == false or C.DialogueEnabled == false then return false end
    if not DC.canNetwork() then return false end
    local player = getPlayer()
    if not player or player:isDead() then return false end

    local def = DSThoughts.Dialogue and DSThoughts.Dialogue.triggerDef and DSThoughts.Dialogue.triggerDef(trigger)
    local cool = (def and def.cooloff) or 90
    local coolKey = trigger .. ":" .. tostring(opts.focus_key or "")
    if triggerCooling(coolKey, cool) then return false end

    local nearby = DC.collectNearby(player, C.DialogueStartRadius or 8)
    if #nearby < 1 and not opts.allow_solo then
        return false
    end

    local snap = nil
    pcall(function()
        if DSThoughts.State and DSThoughts.State.collect then
            snap = DSThoughts.State.collect(player)
        end
    end)

    local rid = "de_" .. tostring(nowMs()) .. "_" .. tostring(ZombRand and ZombRand(9999) or math.random(9999))
    local ev = {
        trigger = trigger,
        request_id = rid,
        focus_key = opts.focus_key or "",
        focus_name = opts.focus_name or "",
        focus_female = opts.focus_female and true or false,
        address_hint = opts.address_hint or "",
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        speaker_key = playerKey(player),
        speaker_name = charName(player),
        speaker_female = isFemale(player),
        speaker_online_id = onlineId(player),
        character = snap and snap.character or nil,
        affect = snap and snap.affect or nil,
        language = C.Language or "ru",
        swear_level = C.SwearLevel or "light",
        nearby = nearby,
    }

    local N = DSThoughts.Net
    local slim = N.slimDialogueEvent and N.slimDialogueEvent(ev) or ev
    local ok = false
    pcall(function()
        sendClientCommand(N.MODULE, N.CMD_DIALOGUE_EVENT, slim)
        ok = true
    end)
    if ok then
        markTrigger(coolKey)
        C.log("DialogueEvent " .. tostring(trigger))
    end
    return ok
end

function DC.showLine(displayText)
    if not displayText or displayText == "" then return end
    if #displayText > 240 then
        displayText = string.sub(displayText, 1, 237) .. "..."
    end
    DC._sticky.text = displayText
    DC._sticky.startMs = nowMs()
    DC._sticky.durationMs = math.floor((C.DialogueDisplaySeconds or 8) * 1000)
    DC._sticky.kind = "dialogue"
end

function DC.drawSticky()
    if not DC._sticky.text then return end
    local player = getPlayer()
    if not player or player:isDead() then
        DC._sticky.text = nil
        return
    end
    local elapsed = nowMs() - DC._sticky.startMs
    if elapsed >= DC._sticky.durationMs then
        DC._sticky.text = nil
        return
    end
    local fadeMs = 1100
    local alpha = 1.0
    local remaining = DC._sticky.durationMs - elapsed
    if remaining < fadeMs then
        alpha = remaining / fadeMs
    end
    local pn = player:getPlayerNum()
    local x = isoToScreenX(pn, player:getX(), player:getY(), player:getZ())
    local y = isoToScreenY(pn, player:getX(), player:getY(), player:getZ()) - 78
    -- Warm spoken-line color (distinct from cool thought blue)
    getTextManager():DrawStringCentre(UIFont.Medium, x, y, DC._sticky.text, 1.0, 0.86, 0.55, alpha)
end

--- Apply DialogueLine from server: subtitle + optional Say/world sound.
function DC.onDialogueLine(args)
    args = args or {}
    DC._inDialogue = true
    local display = args.display or args.text or ""
    DC.showLine(display)

    local player = getPlayer()
    if not player then return end

    local quiet = args.quiet and true or false
    local trigger = tostring(args.trigger or "")
    if quiet or (DSThoughts.Banter and DSThoughts.Banter.isSmallTalkTrigger and DSThoughts.Banter.isSmallTalkTrigger(trigger)) then
        -- Quiet small talk: subtitle only, never Say / addSound
        return
    end

    local myId = onlineId(player)
    local speakerId = tonumber(args.speaker_online_id) or 0
    local isSpeaker = (speakerId ~= 0 and speakerId == myId)
        or (args.speaker_key and args.speaker_key == playerKey(player))

    local attracts = args.attracts_zombies
    if attracts == nil then
        attracts = C.DialogueAttractsZombies ~= false
    end

    if isSpeaker and attracts then
        local text = tostring(args.text or "")
        if #text > 200 then text = string.sub(text, 1, 197) .. "..." end
        pcall(function()
            if player.Say then
                player:Say(text)
            end
        end)
        local r = C.DialogueSoundRadius or 18
        local vol = (DSThoughts.Dialogue and DSThoughts.Dialogue.SOUND_VOLUME) or 60
        if DSThoughts.B42 and DSThoughts.B42.attractZombies then
            DSThoughts.B42.attractZombies(player, r, vol)
        else
            pcall(function()
                if addSound then
                    addSound(player, player:getX(), player:getY(), player:getZ(), r, vol)
                end
            end)
        end
    end
end

function DC.onDialogueEnded(args)
    DC._inDialogue = false
    C.log("DialogueEnded " .. tostring(args and args.reason))
end

--- Periodic soft scans: shared danger, illness, aftershock, reunion.
function DC.scanSituational(player)
    if not player or player:isDead() then return end
    if not DC.canNetwork() then return end
    if C.DialogueEnabled == false then return end

    local nearby = DC.collectNearby(player, C.DialogueStartRadius or 8)
    if #nearby < 1 then return end

    -- Shared danger: zombies very close
    pcall(function()
        if not DSThoughts.Sensors or not DSThoughts.Sensors.collectSituation then return end
        -- Use last situation from State if available
    end)
    local sit = nil
    pcall(function()
        if DSThoughts.State and DSThoughts.State._prevSituation then
            sit = DSThoughts.State._prevSituation
        elseif DSThoughts.Sensors and DSThoughts.Sensors.collect then
            sit = DSThoughts.Sensors.collect(player)
        end
    end)
    if sit and sit.zombies then
        local close = tonumber(sit.zombies.close or 0) or 0
        local chasing = tonumber(sit.zombies.chasing or 0) or 0
        if close >= 1 or chasing >= 2 then
            DC.sendEvent("shared_danger", {})
        end
    end

    -- Illness / panic on a nearby ally
    for i = 1, #nearby do
        local o = nearby[i].player
        if o then
            pcall(function()
                local bd = o:getBodyDamage()
                if bd and bd.isInfected and bd:isInfected() then
                    DC.sendEvent("illness_visible", {
                        focus_key = nearby[i].key,
                        focus_name = nearby[i].name,
                        focus_female = nearby[i].female,
                        address_hint = "named",
                    })
                end
            end)
            pcall(function()
                local pan = 0
                if DSThoughts.B42 and DSThoughts.B42.getPanic then
                    pan = DSThoughts.B42.getPanic(o) or 0
                else
                    local stats = o:getStats()
                    if stats and stats.getPanic then
                        pan = stats:getPanic() or 0
                    end
                end
                if pan >= 70 then
                    DC.sendEvent("moral_panic", {
                        focus_key = nearby[i].key,
                        focus_name = nearby[i].name,
                        focus_female = nearby[i].female,
                        address_hint = "named",
                    })
                end
            end)
            -- Reunion
            if DSThoughts.Memory and DSThoughts.Memory.isReunion then
                if DSThoughts.Memory.isReunion(playerKey(player), nearby[i].key) then
                    DC.sendEvent("reunion", {
                        focus_key = nearby[i].key,
                        focus_name = nearby[i].name,
                        focus_female = nearby[i].female,
                        address_hint = "named",
                    })
                end
            end
        end
    end

    -- Aftershock: combat just ended
    local combat = DSThoughts.CombatFlags or {}
    local now = nowSec()
    if (combat.in_combat_until or 0) > 0 and (combat.in_combat_until or 0) < now
        and (now - (combat.in_combat_until or 0)) < 25 then
        DC.sendEvent("aftershock_group", {})
    end

    -- Quiet small talk (rare, calm only)
    DC.trySmallTalk(player, nearby, sit)
end

--- Calm gates + rare topic roll for quiet small talk.
function DC.trySmallTalk(player, nearby, sit)
    if C.SmallTalkEnabled == false then return end
    if C.DialogueEnabled == false then return end
    if not DSThoughts.Banter then return end
    if DC._inDialogue then return end
    nearby = nearby or DC.collectNearby(player, C.DialogueStartRadius or 8)
    if #nearby < 1 then return end

    -- Local cooloff between small-talk attempts
    DC._lastSmallTalkAttempt = DC._lastSmallTalkAttempt or 0
    local minGap = ((C.SmallTalkMinutes or 10) * 60) / 2 -- try at most twice per cooloff window
    if minGap < 90 then minGap = 90 end
    if (nowSec() - DC._lastSmallTalkAttempt) < minGap then return end

    -- Combat / zombies gate
    local combat = DSThoughts.CombatFlags or {}
    local now = nowSec()
    if (combat.in_combat_until or 0) > now then return end
    if sit and sit.zombies then
        local close = tonumber(sit.zombies.close or 0) or 0
        local chasing = tonumber(sit.zombies.chasing or 0) or 0
        if close >= 1 or chasing >= 1 then return end
    end

    -- Stress / panic gate from last snapshot
    local panic01 = 0
    local stress01 = 0
    local traits = {}
    local profession = "unemployed"
    pcall(function()
        if not DSThoughts.State or not DSThoughts.State.collect then return end
        local snap = DSThoughts.State.collect(player)
        if not snap then return end
        local aff = snap.affect or {}
        panic01 = tonumber(aff.panic01) or 0
        stress01 = tonumber(aff.stress01) or 0
        if snap.character then
            traits = snap.character.traits or {}
            profession = snap.character.profession or profession
        end
    end)
    if panic01 >= 0.35 then return end
    if stress01 >= 0.55 then return end

    -- Context boosts
    local boost = 0
    pcall(function()
        if sit and sit.comfort and sit.comfort.in_vehicle then boost = boost + 12 end
        if sit and sit.indoors then boost = boost + 6 end
        if sit and sit.events and sit.events.eating then boost = boost + 8 end
    end)

    if not DSThoughts.Banter.rollChance(boost) then
        DC._lastSmallTalkAttempt = nowSec() -- soft fail also spaces attempts
        return
    end

    -- Affinity vs first nearby for tone/topic
    local focus = nearby[1]
    local affinity = 0
    pcall(function()
        if DSThoughts.Memory and DSThoughts.Memory.getPair then
            local row = DSThoughts.Memory.getPair(playerKey(player), focus.key)
            if row then affinity = tonumber(row.affinity) or 0 end
        end
    end)

    local topic = DSThoughts.Banter.pickTopic(traits, profession, affinity, true)
    if not topic or not topic.id then return end

    DC._lastSmallTalkAttempt = nowSec()
    DC.sendEvent(topic.id, {
        focus_key = focus.key,
        focus_name = focus.name,
        focus_female = focus.female,
        address_hint = topic.address or "all",
    })
end

C.log("DialogueClient loaded")
