--[[
  Mode B networking helpers — slim snapshots for server-proxy LLM.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Net = DSThoughts.Net or {}

local N = DSThoughts.Net
local C = DSThoughts.Config

N.MODULE = "DSThoughts"
N.CMD_REQUEST = "RequestThought"
N.CMD_THOUGHT = "Thought"
N.CMD_ERROR = "ThoughtError"
N.CMD_STATUS = "BridgeStatus"
N.CMD_DIALOGUE_EVENT = "DialogueEvent"
N.CMD_DIALOGUE_LINE = "DialogueLine"
N.CMD_DIALOGUE_ENDED = "DialogueEnded"
N.CMD_DIALOGUE_ERROR = "DialogueError"

N.MAX_DIGEST = 16
N.MAX_HOOKS = 5
N.MAX_TRAITS = 20

--- True when this process is a networked client (incl. listen-server host client).
function N.isNetworkedClient()
    local ok, res = pcall(function()
        return isClient and isClient()
    end)
    return ok and res and true or false
end

--- True when this process should talk to the local Python bridge (server / SP).
function N.ownsLocalBridge()
    local okS, isS = pcall(function()
        return isServer and isServer()
    end)
    local okC, isC = pcall(function()
        return isClient and isClient()
    end)
    -- Dedicated server
    if okS and isS and not (okC and isC) then
        return true
    end
    -- Singleplayer: neither client nor server flags (B41)
    if not (okC and isC) and not (okS and isS) then
        return true
    end
    -- Listen-server: server half owns the bridge (client half uses commands)
    if okS and isS then
        return true
    end
    return false
end

--- Use Mode B proxy path (send to server instead of local outbox).
function N.useServerProxy()
    return N.isNetworkedClient()
end

local function slimCharacter(ch)
    if not ch then return {} end
    local traits = ch.traits or {}
    local slimTraits = {}
    for i = 1, math.min(#traits, N.MAX_TRAITS) do
        slimTraits[i] = traits[i]
    end
    local tips = ch.traits_active or {}
    local slimTips = {}
    for i = 1, math.min(#tips, 5) do
        slimTips[i] = tips[i]
    end
    return {
        female = ch.female and true or false,
        forename = tostring(ch.forename or "Survivor"),
        surname = tostring(ch.surname or ""),
        profession = tostring(ch.profession or "unemployed"),
        profession_label = tostring(ch.profession_label or ""),
        profession_voice = tostring(ch.profession_voice or ""),
        traits = slimTraits,
        traits_voice = {}, -- server rebuilds from catalog if needed; keep wire small
        traits_active = slimTips,
        skills_notable = {},
    }
end

local function slimHooks(hooks)
    local out = {}
    if not hooks then return out end
    local n = math.min(#hooks, N.MAX_HOOKS)
    for i = 1, n do
        local h = hooks[i]
        if h then
            out[#out + 1] = {
                id = tostring(h.id or ""),
                priority = tonumber(h.priority) or 0,
                micro = tostring(h.micro or ""),
            }
        end
    end
    return out
end

local function slimDigest(digest)
    local out = {}
    if not digest then return out end
    local n = math.min(#digest, N.MAX_DIGEST)
    for i = 1, n do
        out[i] = tostring(digest[i])
    end
    return out
end

--- Compact payload for sendClientCommand (no heavy situation tables).
function N.slimSnapshot(snap)
    if not snap then return nil end
    local prompts = {}
    -- Server overwrites world_main from its own Prompts — do not trust client text
    prompts.world_main = ""
    return {
        schema = snap.schema or 4,
        language = snap.language or (C and C.Language) or "ru",
        swear_level = snap.swear_level or (C and C.SwearLevel) or "light",
        request_id = tostring(snap.request_id or ""),
        prompts = prompts,
        character = slimCharacter(snap.character),
        prompt_hooks = slimHooks(snap.prompt_hooks),
        digest = slimDigest(snap.digest),
        affect = snap.affect or { stress01 = 0, panic01 = 0, distress = 0, tier = "calm" },
        meta = {
            max_priority = (snap.meta and snap.meta.max_priority) or 0,
            force = (snap.meta and snap.meta.force) and true or false,
            acute = (snap.meta and snap.meta.acute) and true or false,
            emotion_phase = snap.emotion_phase or (snap.meta and snap.meta.emotion_phase) or "wander",
        },
        arc_topic = snap.arc_topic or "",
        arc_phase = snap.arc_phase or "",
        arc_turns = snap.arc_turns or 0,
        emotion_phase = snap.emotion_phase or "wander",
        -- Tiny situation crumbs for bank selection (optional)
        situation = {
            comfort = {
                in_vehicle = snap.situation and snap.situation.comfort and snap.situation.comfort.in_vehicle,
            },
            vehicle = snap.situation and snap.situation.vehicle and {
                in_vehicle = snap.situation.vehicle.in_vehicle,
            } or nil,
            media = snap.situation and snap.situation.media and {
                kind = snap.situation.media.kind,
                line = snap.situation.media.line,
                channel = snap.situation.media.channel,
                in_range = snap.situation.media.in_range,
                active = snap.situation.media.active,
            } or nil,
        },
    }
end

--- Slim dialogue event from client → server director.
function N.slimDialogueEvent(ev)
    if not ev then return nil end
    local nearby = {}
    local src = ev.nearby or {}
    for i = 1, math.min(#src, 6) do
        local n = src[i]
        if n then
            nearby[#nearby + 1] = {
                key = tostring(n.key or ""),
                name = tostring(n.name or "Survivor"),
                female = n.female and true or false,
                online_id = tonumber(n.online_id) or 0,
            }
        end
    end
    return {
        schema = 5,
        kind = "dialogue_event",
        trigger = tostring(ev.trigger or ""),
        request_id = tostring(ev.request_id or ""),
        focus_key = tostring(ev.focus_key or ""),
        focus_name = tostring(ev.focus_name or ""),
        focus_female = ev.focus_female and true or false,
        address_hint = tostring(ev.address_hint or ""),
        x = tonumber(ev.x) or 0,
        y = tonumber(ev.y) or 0,
        z = tonumber(ev.z) or 0,
        speaker_key = tostring(ev.speaker_key or ""),
        speaker_name = tostring(ev.speaker_name or ""),
        speaker_female = ev.speaker_female and true or false,
        speaker_online_id = tonumber(ev.speaker_online_id) or 0,
        character = slimCharacter(ev.character),
        affect = ev.affect or { stress01 = 0, panic01 = 0, distress = 0, tier = "calm" },
        language = ev.language or (C and C.Language) or "ru",
        swear_level = ev.swear_level or (C and C.SwearLevel) or "light",
        nearby = nearby,
        force = ev.force and true or false,
    }
end

function N.estimateArgsSize(args)
    -- Rough size guard without full JSON encode
    local n = 0
    local function walk(v, depth)
        if depth > 8 then return end
        local t = type(v)
        if t == "string" then
            n = n + #v
        elseif t == "number" or t == "boolean" then
            n = n + 8
        elseif t == "table" then
            for k, val in pairs(v) do
                n = n + #tostring(k)
                walk(val, depth + 1)
                if n > 20000 then return end
            end
        end
    end
    walk(args, 0)
    return n
end
