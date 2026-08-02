--[[
  Topic arcs: open → build → dead_end → cooloff.
  Covers media arguments, inner obsession, Mode B shared thread.
  Session-only (reset on game start).
]]

DSThoughts = DSThoughts or {}
DSThoughts.TopicArc = DSThoughts.TopicArc or {}

local A = DSThoughts.TopicArc

A.MAX_TURNS = {
    media = 3,
    inner = 2,
    mp = 3,
}

A.COOLOFF_SEC = {
    media = 360, -- 6 min
    inner = 480, -- 8 min
    mp = 300, -- 5 min
}

-- Active arcs by topic_id
A._arcs = A._arcs or {}
-- Emotion spike tracking
A._lastSpikeAt = 0
A._emotionPhase = "wander"

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function simpleHash(s)
    s = tostring(s or "")
    local h = 0
    for i = 1, math.min(#s, 80) do
        h = (h * 31 + string.byte(s, i)) % 1000003
    end
    return tostring(h)
end

function A.reset()
    A._arcs = {}
    A._lastSpikeAt = 0
    A._emotionPhase = "wander"
end

function A.mediaTopicId(line)
    return "media:" .. simpleHash(line)
end

function A.innerTopicId(cluster)
    return "inner:" .. tostring(cluster or "wander")
end

function A.mpTopicId()
    return "mp:shared"
end

local function kindFromId(topicId)
    if not topicId then return "inner" end
    if string.sub(topicId, 1, 6) == "media:" then return "media" end
    if string.sub(topicId, 1, 3) == "mp:" then return "mp" end
    return "inner"
end

function A.get(topicId)
    if not topicId then return nil end
    return A._arcs[topicId]
end

function A.isCooling(topicId)
    local arc = A.get(topicId)
    if not arc then return false end
    if arc.phase ~= "cooloff" then return false end
    return nowSec() < (arc.cooloff_until or 0)
end

--- Open or continue arc for stimulus. Returns arc table.
function A.touch(topicId, opts)
    opts = opts or {}
    local kind = kindFromId(topicId)
    local maxTurns = opts.max_turns or A.MAX_TURNS[kind] or 3
    local now = nowSec()
    local arc = A._arcs[topicId]
    if arc and arc.phase == "cooloff" and now < (arc.cooloff_until or 0) then
        return arc
    end
    if arc and arc.phase == "cooloff" and now >= (arc.cooloff_until or 0) then
        A._arcs[topicId] = nil
        arc = nil
    end
    if not arc then
        arc = {
            topic_id = topicId,
            kind = kind,
            phase = "open",
            turns = 0,
            max_turns = maxTurns,
            cooloff_until = 0,
            opened_at = now,
        }
        A._arcs[topicId] = arc
        return arc
    end
    -- Already open/build: keep
    if arc.phase == "dead_end" then
        -- waiting for noteSpoken to cooloff
        return arc
    end
    return arc
end

--- True if this topic should force a closing scrap instead of continuing.
function A.shouldDeadEnd(topicId)
    local arc = A.get(topicId)
    if not arc then return false end
    if arc.phase == "cooloff" and nowSec() < (arc.cooloff_until or 0) then
        return false -- blocked entirely
    end
    if arc.phase == "dead_end" then
        return true
    end
    return (arc.turns or 0) >= (arc.max_turns or 3)
end

--- Call when a thought about this topic was successfully requested/shown.
function A.noteSpoken(topicId)
    local arc = A.touch(topicId)
    if not arc then return nil end
    if arc.phase == "cooloff" and nowSec() < (arc.cooloff_until or 0) then
        return arc
    end
    arc.turns = (arc.turns or 0) + 1
    local maxT = arc.max_turns or 3
    if arc.turns >= maxT then
        if arc.phase ~= "cooloff" then
            arc.phase = "dead_end"
        end
        -- After dead_end speech, enter cooloff on next note or immediately if already dead_end spoken
        if arc.turns > maxT then
            local kind = arc.kind or kindFromId(topicId)
            arc.phase = "cooloff"
            arc.cooloff_until = nowSec() + (A.COOLOFF_SEC[kind] or 360)
        end
    elseif arc.turns == 1 then
        arc.phase = "open"
    else
        arc.phase = "build"
    end
    return arc
end

--- Force cooloff after dead_end thought was emitted.
function A.enterCooloff(topicId)
    local arc = A.get(topicId) or A.touch(topicId)
    if not arc then return end
    local kind = arc.kind or kindFromId(topicId)
    arc.phase = "cooloff"
    arc.cooloff_until = nowSec() + (A.COOLOFF_SEC[kind] or 360)
    return arc
end

function A.snapshotFields(topicId)
    local arc = topicId and A.get(topicId) or nil
    if not arc then
        return {
            arc_topic = "",
            arc_phase = "",
            arc_turns = 0,
        }
    end
    return {
        arc_topic = arc.topic_id or "",
        arc_phase = arc.phase or "",
        arc_turns = arc.turns or 0,
    }
end

--- Apply server-synced Mode B arc (host authority).
function A.applyRemote(fields)
    if not fields or not fields.arc_topic or fields.arc_topic == "" then return end
    local id = tostring(fields.arc_topic)
    A._arcs[id] = {
        topic_id = id,
        kind = kindFromId(id),
        phase = tostring(fields.arc_phase or "open"),
        turns = tonumber(fields.arc_turns) or 0,
        max_turns = A.MAX_TURNS.mp or 3,
        cooloff_until = tonumber(fields.arc_cooloff_until) or 0,
        opened_at = nowSec(),
    }
end

-- --- Emotion phases ---

local SPIKE_HOOKS = {
    took_damage = true,
    wound_bite = true,
    veh_crash = true,
    fire_near = true,
    gunshot_echo = true,
    media_react = true,
    waking = true,
    bleed_worse = true,
    ammo_dry = true,
    eating = true,
    drinking = true,
    loot_find_rare = true,
    first_kill_session = true,
    distant_gunfire = true,
}

function A.markSpike()
    A._lastSpikeAt = nowSec()
    A._emotionPhase = "spike"
end

function A.resolveEmotionPhase(sit, hooks, affect)
    local now = nowSec()
    local ids = {}
    for i = 1, #(hooks or {}) do
        local id = hooks[i].id
        if id then ids[id] = true end
        if SPIKE_HOOKS[id] then
            A._lastSpikeAt = now
        end
    end
    local since = now - (A._lastSpikeAt or 0)
    local distress = (affect and affect.distress) or 0
    local tier = (affect and affect.tier) or "calm"
    local z = sit and sit.zombies or {}
    local softChase = ((z.chasing or 0) >= 1 or (z.close or 0) >= 1)
        and not ids["took_damage"] and not ids["fire_near"]

    if since <= 15 and A._lastSpikeAt > 0 then
        A._emotionPhase = "spike"
    elseif since <= 90 and A._lastSpikeAt > 0 then
        A._emotionPhase = "aftershock"
    elseif softChase and distress >= 0.45 then
        A._emotionPhase = "numb"
    elseif tier == "calm" or distress < 0.3 then
        A._emotionPhase = "wander"
    else
        A._emotionPhase = "dwell"
    end
    return A._emotionPhase
end

function A.exportForSnapshot(topicId)
    local f = A.snapshotFields(topicId)
    f.emotion_phase = A._emotionPhase or "wander"
    return f
end
