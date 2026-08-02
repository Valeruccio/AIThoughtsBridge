--[[
  Mode B server: host bridge for private thoughts + spoken dialogue director.
  Thoughts → requesting player only. Dialogues → nearby players, one turn at a time.
]]

DSThoughts = DSThoughts or {}

if not (isServer and isServer()) then
    return
end

local C = DSThoughts.Config
local N = DSThoughts.Net
local D = DSThoughts.Dialogue
local Mem = DSThoughts.Memory

local QUEUE_MAX = 8
local GLOBAL_COOLDOWN = 8
local PER_PLAYER_WINDOW = 600
local PER_PLAYER_MAX = 12
local PENDING_TIMEOUT = 180

local thoughtQueue = {}
local dialogueQueue = {}
local busy = false
local busySince = 0
local busyRequestId = nil
local busySpeaker = ""
local busyKind = "thought" -- thought | dialogue
local busyOnlineId = 0
local busyPlayer = nil
local busySessionId = nil
local lastJobAt = 0
local playerHits = {}

-- Active dialogue sessions by id
local sessions = {}
local groupCooloff = {} -- group_key -> until
local sessionSeq = 0

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function applySandbox()
    if DSThoughts.Sandbox and DSThoughts.Sandbox.apply then
        DSThoughts.Sandbox.apply()
    end
end

local function log(msg)
    print("[DeepSeekThoughts:Server] " .. tostring(msg))
end

local function playerName(player)
    local name = "Survivor"
    pcall(function()
        if player.getUsername then
            local u = player:getUsername()
            if u and u ~= "" then name = tostring(u) return end
        end
        local desc = player.getDescriptor and player:getDescriptor() or nil
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

local function charName(player)
    local name = "Survivor"
    pcall(function()
        local desc = player.getDescriptor and player:getDescriptor() or nil
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

local function onlineId(player)
    local id = 0
    pcall(function()
        if player.getOnlineID then
            id = player:getOnlineID() or 0
        end
    end)
    return id
end

local function playerKey(player)
    if Mem and Mem.playerKey then
        return Mem.playerKey(player)
    end
    return tostring(onlineId(player))
end

local function isFemale(player)
    local f = false
    pcall(function()
        f = player:isFemale() and true or false
    end)
    return f
end

local function findPlayerByOnlineId(oid)
    oid = tonumber(oid) or 0
    if oid == 0 then return nil end
    local found = nil
    pcall(function()
        if not getOnlinePlayers then return end
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and onlineId(p) == oid then
                found = p
                return
            end
        end
    end)
    return found
end

local function findPlayerByKey(key)
    key = tostring(key or "")
    if key == "" then return nil end
    local found = nil
    pcall(function()
        if not getOnlinePlayers then return end
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and playerKey(p) == key then
                found = p
                return
            end
        end
    end)
    return found
end

local function rateOk(player)
    local id = onlineId(player)
    local now = nowSec()
    local slot = playerHits[id]
    if not slot or (now - (slot.t0 or 0)) > PER_PLAYER_WINDOW then
        playerHits[id] = { t0 = now, count = 0 }
        slot = playerHits[id]
    end
    if (slot.count or 0) >= PER_PLAYER_MAX then
        return false
    end
    slot.count = (slot.count or 0) + 1
    return true
end

local function sendTo(player, command, args)
    pcall(function()
        if sendServerCommand and player then
            sendServerCommand(player, N.MODULE, command, args)
        end
    end)
end

local function broadcastNear(x, y, z, radius, command, args, extraKeys)
    radius = radius or (C.DialogueHearRadius or 12)
    local r2 = radius * radius
    local want = {}
    if extraKeys then
        for i = 1, #extraKeys do
            want[tostring(extraKeys[i])] = true
        end
    end
    pcall(function()
        if not getOnlinePlayers or not sendServerCommand then return end
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                local send = want[playerKey(p)] == true
                if not send then
                    local dx = (p:getX() or 0) - (x or 0)
                    local dy = (p:getY() or 0) - (y or 0)
                    if (dx * dx + dy * dy) <= r2 then
                        send = true
                    end
                end
                if send then
                    sendServerCommand(p, N.MODULE, command, args)
                end
            end
        end
    end)
end

local function playerInActiveDialogue(player)
    local key = playerKey(player)
    for _, sess in pairs(sessions) do
        if sess and sess.phase ~= "cooloff" then
            for i = 1, #(sess.participants or {}) do
                if sess.participants[i].key == key then
                    return true, sess
                end
            end
        end
    end
    return false, nil
end

local function enrichThoughtSnapshot(data, speaker)
    data = data or {}
    data.schema = 4
    data.kind = "thought"
    data.prompts = data.prompts or {}
    if DSThoughts.Prompts and DSThoughts.Prompts.WorldMain then
        data.prompts.world_main = DSThoughts.Prompts.WorldMain
    else
        data.prompts.world_main = data.prompts.world_main or ""
    end
    if DSThoughts.Catalog and data.character and data.character.traits then
        local voices = {}
        local traits = data.character.traits
        for i = 1, #traits do
            local tip = DSThoughts.Catalog.traitVoice and DSThoughts.Catalog.traitVoice(traits[i])
            if tip then voices[#voices + 1] = tip end
        end
        data.character.traits_voice = voices
    end
    data._mp_speaker = speaker
    data.emotion_phase = data.emotion_phase or "wander"
    return data
end

local function enrichDialogueSnapshot(item)
    local sess = sessions[item.session_id]
    local speakerPart = item.speaker_part or {}
    local data = item.data or {}
    data.schema = 5
    data.kind = "dialogue"
    data.request_id = item.request_id
    data.prompts = data.prompts or {}
    if DSThoughts.Prompts and DSThoughts.Prompts.DialogueMain then
        data.prompts.world_main = DSThoughts.Prompts.DialogueMain
    end
    if DSThoughts.Catalog and data.character and data.character.traits then
        local voices = {}
        local traits = data.character.traits or {}
        for i = 1, #traits do
            local tip = DSThoughts.Catalog.traitVoice and DSThoughts.Catalog.traitVoice(traits[i])
            if tip then voices[#voices + 1] = tip end
        end
        data.character.traits_voice = voices
    end

    local otherKeys = {}
    local partsOut = {}
    if sess then
        for i = 1, #(sess.participants or {}) do
            local p = sess.participants[i]
            partsOut[#partsOut + 1] = {
                key = p.key,
                name = p.name,
                female = p.female and true or false,
            }
            if p.key ~= speakerPart.key then
                otherKeys[#otherKeys + 1] = p.key
            end
        end
    end

    local memorySoft = ""
    if Mem and Mem.promptSoft then
        memorySoft = Mem.promptSoft(speakerPart.key, otherKeys)
    end

    local tdef = D and D.triggerDef and D.triggerDef(sess and sess.trigger or item.trigger)
    local hist = {}
    if sess then
        local h = sess.history or {}
        local start = math.max(1, #h - 3)
        for i = start, #h do
            hist[#hist + 1] = h[i]
        end
    end

    local addressHint = (sess and sess.address_hint) or "all"
    local addressTo = ""
    local addressFemale = nil
    local targetKey = ""
    if addressHint == "named" and sess and sess.focus_key and sess.focus_key ~= speakerPart.key then
        for i = 1, #partsOut do
            if partsOut[i].key == sess.focus_key then
                addressTo = partsOut[i].name
                addressFemale = partsOut[i].female
                targetKey = partsOut[i].key
                break
            end
        end
    end
    if targetKey == "" and #otherKeys > 0 then
        targetKey = otherKeys[1]
        for i = 1, #partsOut do
            if partsOut[i].key == targetKey then
                addressTo = addressTo ~= "" and addressTo or partsOut[i].name
                addressFemale = partsOut[i].female
                break
            end
        end
    end

    local affinity = 0
    if Mem and Mem.getPair and speakerPart.key and targetKey ~= "" then
        local row = Mem.getPair(speakerPart.key, targetKey)
        if row then affinity = tonumber(row.affinity) or 0 end
    end

    local speakerTraits = (data.character and data.character.traits) or {}
    local profession = (data.character and data.character.profession) or "unemployed"
    local targetTraits = {}
    pcall(function()
        local tp = findPlayerByKey(targetKey)
        if not tp then return end
        if DSThoughts.B42 and DSThoughts.B42.collectTraitIds then
            targetTraits = DSThoughts.B42.collectTraitIds(tp) or {}
            return
        end
        local desc = tp:getDescriptor()
        if not desc or not desc.getTraits then return end
        local tr = desc:getTraits()
        if not tr then return end
        for i = 0, tr:size() - 1 do
            targetTraits[#targetTraits + 1] = tostring(tr:get(i))
        end
    end)

    local banterCard = nil
    if DSThoughts.Banter and DSThoughts.Banter.buildCard then
        banterCard = DSThoughts.Banter.buildCard({
            topic = (sess and sess.trigger) or item.trigger,
            speaker_traits = speakerTraits,
            profession = profession,
            affinity = affinity,
            target_traits = targetTraits,
            target_female = addressFemale,
        })
    end

    local isQuiet = (sess and sess.quiet) or (D and D.isQuietTrigger and D.isQuietTrigger(sess and sess.trigger or item.trigger))

    data.dialogue = {
        trigger = (sess and sess.trigger) or item.trigger or "",
        trigger_micro = (tdef and tdef.micro) or "",
        address_mode_hint = addressHint,
        address_to = addressTo,
        address_female = addressFemale,
        participants = partsOut,
        history = hist,
        memory_soft = memorySoft,
        turn = (sess and (sess.turn_i or 0) + 1) or 1,
        max_turns = (sess and sess.max_turns) or (C.DialogueMaxTurns or 6),
        prefer_end = sess and ((sess.turn_i or 0) + 1) >= ((sess.max_turns or 6) - 1),
        quiet = isQuiet and true or false,
        casual = isQuiet and true or false,
        banter = banterCard,
    }
    data.prompt_hooks = {
        {
            id = data.dialogue.trigger,
            priority = (tdef and tdef.priority) or 70,
            micro = data.dialogue.trigger_micro,
        },
    }
    data.emotion_phase = data.emotion_phase or "wander"
    return data
end

local function forceFlatIo()
    if C.refreshIoPaths then
        C.IoRootRel = "DeepSeekThoughts"
        C.OutboxRelPath = "DeepSeekThoughts/outbox/request.txt"
        C.InboxRelPath = "DeepSeekThoughts/inbox/response.txt"
        C.StatusRelPath = "DeepSeekThoughts/status.txt"
    end
end

local function startJob(item)
    if not DSThoughts.Bridge or not DSThoughts.Bridge.writeRequest then
        log("Bridge module missing")
        if item.kind == "dialogue" then
            -- drop
        elseif item.player then
            sendTo(item.player, N.CMD_ERROR, { error = "bridge_missing", request_id = item.request_id })
        end
        return false
    end
    forceFlatIo()
    local snap
    if item.kind == "dialogue" then
        snap = enrichDialogueSnapshot(item)
    else
        snap = enrichThoughtSnapshot(item.data, item.speaker)
        snap.request_id = item.request_id
    end
    if not DSThoughts.Bridge.writeRequest(snap) then
        log("writeRequest failed")
        if item.player then
            sendTo(item.player, N.CMD_ERROR, { error = "write_failed", request_id = item.request_id })
        end
        return false
    end
    busy = true
    busySince = nowSec()
    busyRequestId = item.request_id
    busySpeaker = item.speaker or ""
    busyKind = item.kind or "thought"
    busyOnlineId = item.online_id or 0
    busyPlayer = item.player
    busySessionId = item.session_id
    lastJobAt = nowSec()
    log("job started kind=" .. tostring(busyKind) .. " id=" .. tostring(busyRequestId) .. " speaker=" .. tostring(busySpeaker))
    return true
end

local function tryStartNext()
    if busy then return end
    if C.Enabled == false then
        thoughtQueue = {}
        dialogueQueue = {}
        return
    end
    if (nowSec() - lastJobAt) < GLOBAL_COOLDOWN then
        return
    end
    local item = nil
    if C.DialogueEnabled ~= false and #dialogueQueue > 0 then
        item = table.remove(dialogueQueue, 1)
    elseif #thoughtQueue > 0 then
        item = table.remove(thoughtQueue, 1)
    end
    if not item then return end
    if not startJob(item) then
        lastJobAt = nowSec()
    end
end

local function endSession(sess, reason)
    if not sess then return end
    sess.phase = "cooloff"
    reason = tostring(reason or "ended")
    local cool = C.DialogueCooloffSec or (D and D.COOLOFF_SEC) or 240
    if sess.quiet or (DSThoughts.Banter and DSThoughts.Banter.isSmallTalkTrigger and DSThoughts.Banter.isSmallTalkTrigger(sess.trigger)) then
        cool = (C.SmallTalkMinutes or 10) * 60
    end
    -- Bridge/timeout failures: short cooloff so Home / next talk works again
    if reason == "bridge_error" or reason == "timeout" or reason == "force_restart" then
        cool = 3
    end
    sess.cooloff_until = nowSec() + cool
    if sess.group_key and sess.group_key ~= "" then
        groupCooloff[sess.group_key] = sess.cooloff_until
    end
    -- Drop queued turns for this session (avoids zombie jobs after bridge_error)
    local sid = sess.id
    if sid and #dialogueQueue > 0 then
        local kept = {}
        for i = 1, #dialogueQueue do
            local it = dialogueQueue[i]
            if it and it.session_id ~= sid then
                kept[#kept + 1] = it
            end
        end
        dialogueQueue = kept
    end
    local keys = {}
    for i = 1, #(sess.participants or {}) do
        keys[#keys + 1] = sess.participants[i].key
    end
    broadcastNear(sess.x, sess.y, sess.z, C.DialogueHearRadius or 12, N.CMD_DIALOGUE_ENDED, {
        session_id = sess.id,
        reason = reason,
        trigger = sess.trigger,
    }, keys)
    sessions[sess.id] = nil
    log("dialogue ended id=" .. tostring(sess.id) .. " reason=" .. reason)
end

local function queueDialogueTurn(sess, speakerPart, character, affect, language, swear)
    if not sess or not speakerPart then return end
    sessionSeq = sessionSeq + 1
    local rid = "dlg_" .. tostring(sess.id) .. "_" .. tostring(sessionSeq)
    local player = findPlayerByKey(speakerPart.key)
    dialogueQueue[#dialogueQueue + 1] = {
        kind = "dialogue",
        request_id = rid,
        session_id = sess.id,
        speaker = speakerPart.name,
        speaker_part = speakerPart,
        online_id = speakerPart.online_id or 0,
        player = player,
        trigger = sess.trigger,
        data = {
            language = language or C.Language or "ru",
            swear_level = swear or C.SwearLevel or "light",
            character = character or {
                female = speakerPart.female,
                forename = speakerPart.name,
                surname = "",
                profession = "unemployed",
                traits = {},
            },
            affect = affect or { stress01 = 0.4, panic01 = 0.3, distress = 0.4, tier = "tense" },
        },
    }
    tryStartNext()
end

local function scheduleNextTurn(sess)
    if not sess then return end
    local gap = C.DialogueTurnGapSec or (D and D.TURN_GAP_SEC) or 10
    if sess.quiet then
        gap = C.SmallTalkTurnGapSec or (DSThoughts.Banter and DSThoughts.Banter.SMALLTALK_TURN_GAP) or 7
    end
    sess.next_turn_at = nowSec() + gap
    sess.awaiting_next = true
end

local function buildParticipantsFromEvent(args, reporter)
    local parts = {}
    local seen = {}
    local function add(key, name, female, oid)
        key = tostring(key or "")
        if key == "" or seen[key] then return end
        seen[key] = true
        parts[#parts + 1] = {
            key = key,
            name = tostring(name or "Survivor"),
            female = female and true or false,
            online_id = tonumber(oid) or 0,
        }
    end
    if reporter then
        add(playerKey(reporter), charName(reporter), isFemale(reporter), onlineId(reporter))
    end
    if args.speaker_key and args.speaker_key ~= "" then
        add(args.speaker_key, args.speaker_name, args.speaker_female, args.speaker_online_id)
    end
    local nearby = args.nearby or {}
    for i = 1, #nearby do
        local n = nearby[i]
        if n then
            add(n.key, n.name, n.female, n.online_id)
        end
    end
    -- Also pull anyone currently in start radius on server
    pcall(function()
        if not getOnlinePlayers or not reporter then return end
        local r = C.DialogueStartRadius or (D and D.START_RADIUS) or 8
        local px, py = reporter:getX(), reporter:getY()
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and not p:isDead() then
                local dx = (p:getX() or 0) - px
                local dy = (p:getY() or 0) - py
                if (dx * dx + dy * dy) <= (r * r) then
                    add(playerKey(p), charName(p), isFemale(p), onlineId(p))
                end
            end
        end
    end)
    return parts
end

local function findActiveSessionNear(x, y, participants)
    for _, sess in pairs(sessions) do
        if sess and sess.phase ~= "cooloff" then
            local r = (C.DialogueHearRadius or 12) + 2
            if D and D.inRadius and D.inRadius(sess.x, sess.y, x, y, r) then
                return sess
            end
            -- Overlapping participant
            local set = {}
            for i = 1, #(sess.participants or {}) do
                set[sess.participants[i].key] = true
            end
            for i = 1, #(participants or {}) do
                if set[participants[i].key] then
                    return sess
                end
            end
        end
    end
    return nil
end

local function pickFirstSpeaker(parts, args, trigger)
    local focus = tostring(args.focus_key or "")
    local reporterKey = tostring(args.speaker_key or "")
    if trigger == "friendly_fire" or trigger == "player_kill_player" then
        -- Prefer the non-focus (aggressor/reporter) or focus victim next
        for i = 1, #parts do
            if parts[i].key == reporterKey then return parts[i] end
        end
    end
    if trigger == "ally_hurt" or trigger == "illness_visible" or trigger == "moral_panic" then
        for i = 1, #parts do
            if parts[i].key == reporterKey then return parts[i] end
        end
    end
    if focus ~= "" then
        for i = 1, #parts do
            if parts[i].key ~= focus then return parts[i] end
        end
    end
    return parts[1]
end

local function onDialogueEvent(player, args)
    applySandbox()
    if C.Enabled == false or C.DialogueEnabled == false then
        return
    end
    if type(args) ~= "table" then return end
    local trigger = tostring(args.trigger or "")
    if trigger == "" or not (D and D.triggerDef and D.triggerDef(trigger)) then
        sendTo(player, N.CMD_DIALOGUE_ERROR, { error = "bad_trigger", trigger = trigger })
        return
    end
    local force = args.force and true or false
    local isSmall = DSThoughts.Banter and DSThoughts.Banter.isSmallTalkTrigger and DSThoughts.Banter.isSmallTalkTrigger(trigger)
    if isSmall and C.SmallTalkEnabled == false and not force then
        return
    end
    if not rateOk(player) then
        sendTo(player, N.CMD_DIALOGUE_ERROR, { error = "rate_limit" })
        return
    end

    local parts = buildParticipantsFromEvent(args, player)
    if #parts < 2 then
        return -- need someone to talk to / with
    end

    local keys = {}
    for i = 1, #parts do keys[i] = parts[i].key end
    local gk = (D and D.groupKey and D.groupKey(keys)) or table.concat(keys, "|")
    local now = nowSec()
    if (not force) and groupCooloff[gk] and now < groupCooloff[gk] then
        return
    end
    if force then
        groupCooloff[gk] = nil
        log("force dialogue trigger=" .. trigger)
    end

    local x = tonumber(args.x) or (player.getX and player:getX()) or 0
    local y = tonumber(args.y) or (player.getY and player:getY()) or 0
    local z = tonumber(args.z) or (player.getZ and player:getZ()) or 0

    local existing = findActiveSessionNear(x, y, parts)
    if existing then
        if force then
            endSession(existing, "force_restart")
            -- fall through and open a fresh session
        elseif isSmall then
            -- Do not inject quiet smalltalk into a serious beat; drop it
            return
        else
            -- Enqueue interrupt event for later turn; do not parallel LLM
            existing.pending_events = existing.pending_events or {}
            if #existing.pending_events < 4 then
                existing.pending_events[#existing.pending_events + 1] = {
                    trigger = trigger,
                    focus_key = args.focus_key,
                }
            end
            -- Merge new participants
            local seen = {}
            for i = 1, #existing.participants do
                seen[existing.participants[i].key] = true
            end
            for i = 1, #parts do
                if not seen[parts[i].key] then
                    existing.participants[#existing.participants + 1] = parts[i]
                end
            end
            log("dialogue event queued mid-session trigger=" .. trigger)
            return
        end
    end

    -- Soft reunion upgrade (never hijack small talk)
    if (not isSmall) and Mem and Mem.isReunion then
        local rk = playerKey(player)
        for i = 1, #parts do
            if parts[i].key ~= rk and Mem.isReunion(rk, parts[i].key) then
                if trigger ~= "player_kill_player" and trigger ~= "friendly_fire" and trigger ~= "player_died_near" then
                    trigger = "reunion"
                    args.focus_key = parts[i].key
                    args.focus_name = parts[i].name
                    args.focus_female = parts[i].female
                    args.address_hint = "named"
                end
                break
            end
        end
    end

    local first = pickFirstSpeaker(parts, args, trigger)
    if not first then return end
    local focusKey = tostring(args.focus_key or "")
    if focusKey == "" and isSmall and #parts >= 2 then
        -- Prefer a non-speaker focus for named small talk
        for i = 1, #parts do
            if parts[i].key ~= first.key then
                focusKey = parts[i].key
                break
            end
        end
    end
    local addressHint = args.address_hint
    if not addressHint or addressHint == "" then
        addressHint = (D and D.addressHintForTrigger and D.addressHintForTrigger(trigger, focusKey ~= "")) or "all"
    end

    local maxTurns = C.DialogueMaxTurns or 6
    if isSmall then
        maxTurns = C.SmallTalkMaxTurns or (DSThoughts.Banter and DSThoughts.Banter.SMALLTALK_MAX_TURNS) or 3
    end

    sessionSeq = sessionSeq + 1
    local sess = D.newSession({
        id = "s" .. tostring(sessionSeq) .. "_" .. tostring(now),
        trigger = trigger,
        topic_seed = trigger,
        participants = parts,
        first_speaker_key = first.key,
        focus_key = focusKey,
        address_hint = addressHint,
        group_key = gk,
        max_turns = maxTurns,
        x = x, y = y, z = z,
        seed = sessionSeq,
    })
    sess.next_speaker_key = first.key
    sess.quiet = isSmall and true or false
    sessions[sess.id] = sess

    -- Memory touch for all pairs with speaker
    if Mem and Mem.touch then
        local delta = 0
        if isSmall and DSThoughts.Banter and DSThoughts.Banter.affinityDeltaForTopic then
            delta = DSThoughts.Banter.affinityDeltaForTopic(trigger) or 0
        elseif Mem.affinityDeltaForTrigger then
            delta = Mem.affinityDeltaForTrigger(trigger) or 0
        end
        for i = 1, #parts do
            if parts[i].key ~= first.key then
                Mem.touch(first.key, parts[i].key, {
                    topic = trigger,
                    incident = trigger,
                    affinity_delta = delta,
                })
            end
        end
    end

    log("dialogue session start id=" .. sess.id .. " trigger=" .. trigger .. " quiet=" .. tostring(sess.quiet) .. " first=" .. first.name)
    queueDialogueTurn(sess, first, args.character, args.affect, args.language, args.swear_level)
end

local function onThoughtRequest(player, args)
    applySandbox()
    if C.Enabled == false then
        sendTo(player, N.CMD_ERROR, { error = "disabled", request_id = args and args.request_id })
        return
    end
    if type(args) ~= "table" then
        sendTo(player, N.CMD_ERROR, { error = "bad_args" })
        return
    end
    local rid = tostring(args.request_id or "")
    if rid == "" then
        sendTo(player, N.CMD_ERROR, { error = "no_request_id" })
        return
    end
    -- Suppress calm thoughts during active dialogue (allow panic spikes)
    local inDlg = playerInActiveDialogue(player)
    if inDlg then
        local aff = args.affect or {}
        local panic = tonumber(aff.panic01) or 0
        local tier = tostring(aff.tier or "")
        if panic < 0.7 and tier ~= "panic" and tier ~= "critical" then
            sendTo(player, N.CMD_ERROR, { error = "dialogue_active", request_id = rid })
            return
        end
    end
    if not rateOk(player) then
        sendTo(player, N.CMD_ERROR, { error = "rate_limit", request_id = rid })
        return
    end
    if N.estimateArgsSize and N.estimateArgsSize(args) > 12000 then
        sendTo(player, N.CMD_ERROR, { error = "payload_too_large", request_id = rid })
        return
    end
    if #thoughtQueue >= QUEUE_MAX then
        sendTo(player, N.CMD_ERROR, { error = "queue_full", request_id = rid })
        return
    end
    local speaker = playerName(player)
    pcall(function()
        local ch = args.character
        if ch and ch.forename then
            speaker = tostring(ch.forename)
            if ch.surname and tostring(ch.surname) ~= "" then
                speaker = speaker .. " " .. tostring(ch.surname)
            end
        end
    end)
    thoughtQueue[#thoughtQueue + 1] = {
        kind = "thought",
        request_id = rid,
        data = args,
        speaker = speaker,
        online_id = onlineId(player),
        player = player,
    }
    log("thought queued id=" .. rid .. " speaker=" .. speaker .. " q=" .. tostring(#thoughtQueue))
    tryStartNext()
end

local function deliverThought(thought)
    local payload = {
        request_id = busyRequestId,
        thought = thought,
        speaker = busySpeaker,
        private = true,
    }
    local target = busyPlayer or findPlayerByOnlineId(busyOnlineId)
    if target then
        sendTo(target, N.CMD_THOUGHT, payload)
        log("private thought → " .. tostring(busySpeaker))
    else
        log("thought orphaned (player gone) id=" .. tostring(busyRequestId))
    end
end

local function deliverDialogueLine(resp)
    local sess = sessions[busySessionId]
    local text = resp.thought or ""
    local addressMode = tostring(resp.address_mode or "all")
    if addressMode ~= "void" and addressMode ~= "all" and addressMode ~= "named" then
        addressMode = "all"
    end
    local addressTo = tostring(resp.address_to or "")
    local shouldEnd = resp.should_end and true or false

    if not sess then
        log("dialogue response without session")
        return
    end

    sess.turn_i = (sess.turn_i or 0) + 1
    sess.phase = (sess.turn_i <= 1) and "open" or "build"
    sess.last_speaker_key = (busySpeaker and "") -- set below
    local speakerPart = nil
    for i = 1, #(sess.participants or {}) do
        if sess.participants[i].name == busySpeaker or sess.participants[i].key == (resp._speaker_key or "") then
            speakerPart = sess.participants[i]
            break
        end
    end
    -- Prefer online id match from busy
    if busyOnlineId and busyOnlineId ~= 0 then
        for i = 1, #(sess.participants or {}) do
            if sess.participants[i].online_id == busyOnlineId then
                speakerPart = sess.participants[i]
                break
            end
        end
    end
    if speakerPart then
        sess.last_speaker_key = speakerPart.key
    end

    -- Resolve address_to name → key for next turn
    local addressKey = ""
    if addressMode == "named" and addressTo ~= "" then
        for i = 1, #(sess.participants or {}) do
            local p = sess.participants[i]
            if p.name == addressTo or p.key == addressTo then
                addressKey = p.key
                addressTo = p.name
                break
            end
        end
        if addressKey == "" then
            -- fuzzy: use focus
            addressKey = sess.focus_key or ""
            if addressKey ~= "" then
                for i = 1, #sess.participants do
                    if sess.participants[i].key == addressKey then
                        addressTo = sess.participants[i].name
                        break
                    end
                end
            end
        end
    end

    sess.history = sess.history or {}
    sess.history[#sess.history + 1] = {
        speaker = (speakerPart and speakerPart.name) or busySpeaker,
        text = text,
        address_mode = addressMode,
        address_to = addressTo,
    }

    if Mem and Mem.touch and speakerPart then
        local delta = 0
        if sess.quiet and DSThoughts.Banter and DSThoughts.Banter.affinityDeltaForTopic then
            delta = DSThoughts.Banter.affinityDeltaForTopic(sess.trigger) or 0
        end
        -- Named roast/praise affinity hits the addressee harder
        if addressKey ~= "" and delta ~= 0 then
            Mem.touch(speakerPart.key, addressKey, {
                topic = sess.trigger,
                affinity_delta = delta,
            })
        else
            for i = 1, #sess.participants do
                local o = sess.participants[i]
                if o.key ~= speakerPart.key then
                    Mem.touch(speakerPart.key, o.key, {
                        topic = sess.trigger,
                        affinity_delta = 0,
                    })
                end
            end
        end
    end

    local display = text
    if D and D.formatDisplayLine then
        display = D.formatDisplayLine(
            (speakerPart and speakerPart.name) or busySpeaker,
            text,
            addressMode,
            addressTo
        )
    end

    local keys = {}
    for i = 1, #(sess.participants or {}) do
        keys[#keys + 1] = sess.participants[i].key
    end

    local quiet = sess.quiet and true or false
    if D and D.isQuietTrigger and D.isQuietTrigger(sess.trigger) then
        quiet = true
    end

    local payload = {
        session_id = sess.id,
        request_id = busyRequestId,
        text = text,
        display = display,
        speaker = (speakerPart and speakerPart.name) or busySpeaker,
        speaker_key = speakerPart and speakerPart.key or "",
        speaker_online_id = speakerPart and speakerPart.online_id or busyOnlineId,
        address_mode = addressMode,
        address_to = addressTo,
        trigger = sess.trigger,
        turn = sess.turn_i,
        quiet = quiet,
        attracts_zombies = (not quiet) and (C.DialogueAttractsZombies ~= false),
        x = sess.x,
        y = sess.y,
        z = sess.z,
    }
    broadcastNear(sess.x, sess.y, sess.z, C.DialogueHearRadius or 12, N.CMD_DIALOGUE_LINE, payload, keys)
    log("dialogue line turn=" .. tostring(sess.turn_i) .. " quiet=" .. tostring(quiet) .. " " .. tostring(payload.speaker))

    if D.shouldEndSession(sess, shouldEnd) then
        endSession(sess, shouldEnd and "llm_end" or "max_turns")
        return
    end

    -- Pick next speaker
    local nextPart = D.pickNextSpeaker(sess, addressMode, addressKey)
    if not nextPart then
        endSession(sess, "no_speaker")
        return
    end
    sess.next_speaker_key = nextPart.key
    -- Pending higher-priority event may steal focus
    if sess.pending_events and #sess.pending_events > 0 then
        local ev = table.remove(sess.pending_events, 1)
        if ev and ev.trigger then
            sess.trigger = ev.trigger
            if ev.focus_key and ev.focus_key ~= "" then
                sess.focus_key = ev.focus_key
            end
            sess.address_hint = D.addressHintForTrigger(ev.trigger, sess.focus_key ~= "")
        end
    else
        sess.address_hint = addressMode
        if addressMode == "named" then
            sess.focus_key = addressKey
        end
    end
    sess._pending_next = nextPart
    scheduleNextTurn(sess)
end

local function tickDialogueSessions()
    local now = nowSec()
    for id, sess in pairs(sessions) do
        if sess and sess.awaiting_next and sess.next_turn_at and now >= sess.next_turn_at then
            sess.awaiting_next = false
            local nextPart = sess._pending_next
            sess._pending_next = nil
            if not nextPart then
                endSession(sess, "no_next")
            else
                -- Refresh live character if possible
                local p = findPlayerByKey(nextPart.key)
                if not p or (p.isDead and p:isDead()) then
                    -- Skip dead / gone
                    local alt = D.pickNextSpeaker(sess, "all", "")
                    if not alt or alt.key == sess.last_speaker_key then
                        endSession(sess, "participants_gone")
                    else
                        queueDialogueTurn(sess, alt, nil, nil, nil, nil)
                    end
                else
                    local ch = {
                        female = isFemale(p),
                        forename = charName(p),
                        surname = "",
                        profession = "unemployed",
                        traits = {},
                    }
                    pcall(function()
                        local desc = p:getDescriptor()
                        if desc and desc.getForename then
                            ch.forename = tostring(desc:getForename() or ch.forename)
                            if desc.getSurname then
                                ch.surname = tostring(desc:getSurname() or "")
                            end
                        end
                        if DSThoughts.B42 and DSThoughts.B42.collectProfessionId then
                            ch.profession = DSThoughts.B42.collectProfessionId(p) or ch.profession
                        elseif desc and desc.getProfession then
                            ch.profession = tostring(desc:getProfession() or ch.profession)
                        end
                        if DSThoughts.B42 and DSThoughts.B42.collectTraitIds then
                            ch.traits = DSThoughts.B42.collectTraitIds(p) or {}
                        end
                    end)
                    -- Update coords to speaker
                    sess.x = p:getX() or sess.x
                    sess.y = p:getY() or sess.y
                    queueDialogueTurn(sess, nextPart, ch, nil, nil, nil)
                end
            end
        end
        -- Distance break
        if sess and sess.phase ~= "cooloff" and #(sess.participants or {}) >= 2 then
            local aliveNear = 0
            for i = 1, #sess.participants do
                local p = findPlayerByKey(sess.participants[i].key)
                if p and not p:isDead() then
                    local r = (C.DialogueHearRadius or 12) + 4
                    if D.inRadius(sess.x, sess.y, p:getX(), p:getY(), r) then
                        aliveNear = aliveNear + 1
                    end
                end
            end
            if aliveNear < 2 and (sess.turn_i or 0) > 0 and not sess.awaiting_next and not busy then
                endSession(sess, "dispersed")
            end
        end
    end
end

local function pollBridge()
    tickDialogueSessions()
    if not busy then
        tryStartNext()
        return
    end
    if not DSThoughts.Bridge or not DSThoughts.Bridge.pollResponseFull then
        -- Fallback
        if DSThoughts.Bridge and DSThoughts.Bridge.pollResponse then
            local thought = DSThoughts.Bridge.pollResponse()
            if thought and thought ~= "" then
                if busyKind == "dialogue" then
                    deliverDialogueLine({ thought = thought, address_mode = "all", should_end = false })
                else
                    deliverThought(thought)
                end
                busy = false
                busyRequestId = nil
                busySpeaker = ""
                busyKind = "thought"
                busyOnlineId = 0
                busyPlayer = nil
                busySessionId = nil
                tryStartNext()
            end
        end
        return
    end
    forceFlatIo()

    if busySince > 0 and (nowSec() - busySince) > PENDING_TIMEOUT then
        local timedOutId = busyRequestId
        log("job timeout id=" .. tostring(timedOutId))
        if DSThoughts.Bridge then
            DSThoughts.Bridge._pending = false
        end
        if busyKind == "thought" and busyPlayer then
            sendTo(busyPlayer, N.CMD_ERROR, { error = "timeout", request_id = timedOutId })
        elseif busyKind == "dialogue" and busySessionId and sessions[busySessionId] then
            endSession(sessions[busySessionId], "timeout")
        end
        busy = false
        busyRequestId = nil
        busySpeaker = ""
        busyKind = "thought"
        busyOnlineId = 0
        busyPlayer = nil
        busySessionId = nil
        tryStartNext()
        return
    end

    local resp = DSThoughts.Bridge.pollResponseFull()
    if not resp then
        return
    end

    -- Bridge rejected / empty: unlock queue and kill stuck dialogue session
    if resp.error or not resp.thought or resp.thought == "" then
        log("bridge job failed kind=" .. tostring(busyKind)
            .. " err=" .. tostring(resp.error or "empty"))
        if busyKind == "thought" and busyPlayer then
            sendTo(busyPlayer, N.CMD_ERROR, {
                error = "bridge_error",
                request_id = busyRequestId,
                detail = tostring(resp.error or "empty"),
            })
        elseif busyKind == "dialogue" and busySessionId and sessions[busySessionId] then
            endSession(sessions[busySessionId], "bridge_error")
        end
        busy = false
        busyRequestId = nil
        busySpeaker = ""
        busyKind = "thought"
        busyOnlineId = 0
        busyPlayer = nil
        busySessionId = nil
        tryStartNext()
        return
    end

    if busyKind == "dialogue" then
        deliverDialogueLine(resp)
    else
        deliverThought(resp.thought)
    end
    busy = false
    busyRequestId = nil
    busySpeaker = ""
    busyKind = "thought"
    busyOnlineId = 0
    busyPlayer = nil
    busySessionId = nil
    tryStartNext()
end

local function onClientCommand(module, command, player, args)
    if module ~= N.MODULE then return end
    if command == N.CMD_REQUEST then
        onThoughtRequest(player, args)
    elseif command == N.CMD_DIALOGUE_EVENT then
        onDialogueEvent(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnGameStart.Add(applySandbox)
Events.OnServerStarted.Add(function()
    applySandbox()
    log("Mode B server ready (private thoughts + dialogue director)")
end)

local lastPollMs = 0
local function nowMs()
    if getTimeInMillis then return getTimeInMillis() end
    return nowSec() * 1000
end

Events.OnTick.Add(function()
    local t = nowMs()
    if (t - lastPollMs) < 400 then return end
    lastPollMs = t
    pollBridge()
end)

log("DST_Server Mode B + Dialogue loaded")
