--[[
  Dialogue director helpers — sessions, turn order, trigger defs.
  Server owns session state; shared module is pure logic + constants.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Dialogue = DSThoughts.Dialogue or {}

local D = DSThoughts.Dialogue
local C = DSThoughts.Config

D.START_RADIUS = 8
D.HEAR_RADIUS = 12
D.MAX_TURNS = 6
D.COOLOFF_SEC = 240
D.TURN_GAP_SEC = 10
D.SOUND_RADIUS = 18
D.SOUND_VOLUME = 60

--- Trigger definitions: priority for starting; micro for LLM soft bias.
D.Triggers = {
    player_died_near = {
        priority = 96,
        cooloff = 180,
        micro = "Someone just died nearby — shock, grief, blame, or hard numbness. Spoken aloud.",
    },
    ally_hurt = {
        priority = 90,
        cooloff = 90,
        micro = "Ally is badly hurt — concern, panic, or cold practicality. Spoken aloud.",
    },
    illness_visible = {
        priority = 82,
        cooloff = 150,
        micro = "Someone looks sick / infected — fear of contagion or forced care. Spoken aloud.",
    },
    shared_danger = {
        priority = 88,
        cooloff = 60,
        micro = "Zombies on the group — short urgent callout, not a speech.",
    },
    friendly_fire = {
        priority = 94,
        cooloff = 120,
        micro = "Hit by / hit a living ally — anger, apology, or threat. Spoken aloud.",
    },
    player_kill_player = {
        priority = 98,
        cooloff = 300,
        micro = "A survivor killed another — horror, justification, or cold acceptance.",
    },
    reunion = {
        priority = 70,
        cooloff = 300,
        micro = "Recognize someone you already know — no stranger-greeting; shared history.",
    },
    plan_critical = {
        priority = 72,
        cooloff = 120,
        micro = "Pressure plan callout — door, vehicle, exit. Short and human.",
    },
    aftershock_group = {
        priority = 68,
        cooloff = 100,
        micro = "Fight just ended — shaky relief or grim check-in with the group.",
    },
    ammo_check_group = {
        priority = 60,
        cooloff = 180,
        micro = "Ammo worry shared with nearby survivors — not a status report.",
    },
    loot_dispute = {
        priority = 65,
        cooloff = 200,
        micro = "Valuable loot in sight of two people — greed, joke, or claim.",
    },
    moral_panic = {
        priority = 78,
        cooloff = 90,
        micro = "Someone is panicking hard while others watch — calm them or snap.",
    },
    -- Quiet small talk (never attracts zombies; short arc)
    smalltalk_joke = {
        priority = 48, cooloff = 600, quiet = true,
        micro = "Casual joke or wry crack — short, human, not a stand-up set.",
    },
    smalltalk_gripe = {
        priority = 46, cooloff = 600, quiet = true,
        micro = "Quiet gripe about weather, feet, food, boredom — not a crisis.",
    },
    smalltalk_story = {
        priority = 45, cooloff = 600, quiet = true,
        micro = "Tiny wild story scrap — one breath, not a novel.",
    },
    smalltalk_memory = {
        priority = 47, cooloff = 600, quiet = true,
        micro = "A memory slipping out loud — soft, specific.",
    },
    smalltalk_dream = {
        priority = 44, cooloff = 600, quiet = true,
        micro = "A dream or 'what if' spoken aloud — wishful, not tactics.",
    },
    smalltalk_want = {
        priority = 46, cooloff = 600, quiet = true,
        micro = "A casual want: cigarette, shower, coffee, silence, a bed.",
    },
    smalltalk_observe = {
        priority = 45, cooloff = 600, quiet = true,
        micro = "Casual remark about place/weather — not a gear checklist.",
    },
    smalltalk_ask = {
        priority = 50, cooloff = 600, quiet = true,
        micro = "A real question to one nearby person — curiosity, not interrogation.",
    },
    smalltalk_praise = {
        priority = 49, cooloff = 600, quiet = true,
        micro = "Warm compliment or soft nickname — character-true.",
    },
    smalltalk_roast = {
        priority = 48, cooloff = 600, quiet = true,
        micro = "Tease or harsh nickname if tone allows — never empty cruelty spam.",
    },
}

function D.isQuietTrigger(id)
    local def = D.Triggers[id]
    if def and def.quiet then return true end
    if DSThoughts.Banter and DSThoughts.Banter.isSmallTalkTrigger then
        return DSThoughts.Banter.isSmallTalkTrigger(id)
    end
    return false
end

function D.triggerDef(id)
    return D.Triggers[id]
end

function D.dist2(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

function D.inRadius(ax, ay, bx, by, r)
    r = r or D.HEAR_RADIUS
    return D.dist2(ax, ay, bx, by) <= (r * r)
end

--- Stable group key from sorted participant keys.
function D.groupKey(keys)
    if not keys or #keys == 0 then return "empty" end
    local copy = {}
    for i = 1, #keys do
        copy[i] = tostring(keys[i])
    end
    table.sort(copy)
    return table.concat(copy, "|")
end

--- Soft next-speaker pick: addressed first, else round-robin with mild weights.
function D.pickNextSpeaker(session, addressMode, addressKey)
    if not session or not session.participants then return nil end
    local parts = session.participants
    if #parts == 0 then return nil end

    if addressMode == "named" and addressKey and addressKey ~= "" then
        for i = 1, #parts do
            if parts[i].key == addressKey and parts[i].key ~= session.last_speaker_key then
                return parts[i]
            end
        end
    end

    -- Prefer focus target from trigger (hurt / killer / etc.)
    local focus = session.focus_key
    if focus and focus ~= "" and focus ~= session.last_speaker_key then
        for i = 1, #parts do
            if parts[i].key == focus then
                return parts[i]
            end
        end
    end

    local start = (session.rr_index or 0) % #parts
    for off = 1, #parts do
        local i = ((start + off - 1) % #parts) + 1
        local p = parts[i]
        if p.key ~= session.last_speaker_key then
            session.rr_index = i
            return p
        end
    end
    -- Solo / same speaker only
    return parts[1]
end

function D.shouldEndSession(session, llmShouldEnd)
    if not session then return true end
    if llmShouldEnd then return true end
    if (session.turn_i or 0) >= (session.max_turns or D.MAX_TURNS) then
        return true
    end
    if session.phase == "dead_end" or session.phase == "cooloff" then
        return true
    end
    return false
end

function D.newSession(opts)
    opts = opts or {}
    local maxTurns = opts.max_turns or (C and C.DialogueMaxTurns) or D.MAX_TURNS
    return {
        id = opts.id or ("dlg_" .. tostring(opts.seed or 1)),
        trigger = opts.trigger or "shared_danger",
        topic_seed = opts.topic_seed or opts.trigger or "talk",
        participants = opts.participants or {},
        history = {},
        phase = "open",
        turn_i = 0,
        max_turns = maxTurns,
        cooloff_until = 0,
        last_speaker_key = "",
        next_speaker_key = opts.first_speaker_key or "",
        focus_key = opts.focus_key or "",
        address_hint = opts.address_hint or "all",
        rr_index = 0,
        pending_events = {},
        group_key = opts.group_key or "",
        x = opts.x or 0,
        y = opts.y or 0,
        z = opts.z or 0,
    }
end

--- Build soft address hint for first turn from trigger.
function D.addressHintForTrigger(trigger, hasFocus)
    if DSThoughts.Banter and DSThoughts.Banter.isSmallTalkTrigger and DSThoughts.Banter.isSmallTalkTrigger(trigger) then
        if trigger == "smalltalk_ask" or trigger == "smalltalk_praise" or trigger == "smalltalk_roast" then
            return hasFocus and "named" or "named"
        end
        return "all"
    end
    if trigger == "friendly_fire" or trigger == "player_kill_player" or trigger == "reunion" then
        return hasFocus and "named" or "all"
    end
    if trigger == "player_died_near" or trigger == "shared_danger" or trigger == "aftershock_group" then
        return "all"
    end
    if trigger == "ally_hurt" or trigger == "illness_visible" or trigger == "moral_panic" then
        return hasFocus and "named" or "all"
    end
    return "all"
end

function D.formatDisplayLine(speaker, text, addressMode, addressTo)
    local line = tostring(text or "")
    local sp = tostring(speaker or "Survivor")
    if addressMode == "named" and addressTo and addressTo ~= "" then
        return sp .. " → " .. tostring(addressTo) .. ": " .. line
    elseif addressMode == "void" then
        return sp .. " (void): " .. line
    elseif addressMode == "all" then
        return sp .. " → all: " .. line
    end
    return sp .. ": " .. line
end

if C and C.log then
    C.log("Dialogue director helpers loaded")
end
