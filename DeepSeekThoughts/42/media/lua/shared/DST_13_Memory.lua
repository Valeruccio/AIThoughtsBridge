--[[
  Pairwise survivor memory — soft relationship crumbs for dialogue prompts.
  Persists via ModData on server (and SP host).
]]

DSThoughts = DSThoughts or {}
DSThoughts.Memory = DSThoughts.Memory or {}

local M = DSThoughts.Memory
local C = DSThoughts.Config

M.MODDATA_KEY = "DSThoughtsMemory"
M.MAX_TOPICS = 4
M.MAX_INCIDENTS = 6
M.REUNION_GAP_SEC = 600 -- 10 min apart → reunion-worthy

local function nowSec()
    return (getTimestamp and getTimestamp()) or (os and os.time and os.time()) or 0
end

local function store()
    local md = nil
    pcall(function()
        if ModData and ModData.getOrCreate then
            md = ModData.getOrCreate(M.MODDATA_KEY)
        end
    end)
    if not md then
        M._local = M._local or { pairs = {} }
        return M._local
    end
    md.pairs = md.pairs or {}
    return md
end

local function pairKey(a, b)
    a = tostring(a or "")
    b = tostring(b or "")
    if a == "" or b == "" or a == b then return nil end
    if a < b then
        return a .. "::" .. b
    end
    return b .. "::" .. a
end

function M.playerKey(player)
    local key = "unknown"
    pcall(function()
        if not player then return end
        if player.getUsername then
            local u = player:getUsername()
            if u and tostring(u) ~= "" then
                key = tostring(u)
                return
            end
        end
        if player.getOnlineID then
            key = "oid:" .. tostring(player:getOnlineID() or 0)
        end
    end)
    return key
end

function M.getPair(aKey, bKey)
    local pk = pairKey(aKey, bKey)
    if not pk then return nil end
    local s = store()
    return s.pairs[pk]
end

local function ensurePair(aKey, bKey)
    local pk = pairKey(aKey, bKey)
    if not pk then return nil, nil end
    local s = store()
    local row = s.pairs[pk]
    if not row then
        row = {
            a = aKey < bKey and aKey or bKey,
            b = aKey < bKey and bKey or aKey,
            met = 0,
            last_seen = 0,
            affinity = 0,
            last_topics = {},
            incidents = {},
        }
        s.pairs[pk] = row
    end
    return row, pk
end

--- Record that A and B interacted (dialogue or serious event).
function M.touch(aKey, bKey, opts)
    opts = opts or {}
    local row = ensurePair(aKey, bKey)
    if not row then return nil end
    local now = nowSec()
    row.met = (row.met or 0) + 1
    row.last_seen = now
    if opts.affinity_delta then
        local a = (row.affinity or 0) + opts.affinity_delta
        if a > 5 then a = 5 end
        if a < -5 then a = -5 end
        row.affinity = a
    end
    if opts.topic and opts.topic ~= "" then
        local topics = row.last_topics or {}
        table.insert(topics, 1, tostring(opts.topic))
        while #topics > M.MAX_TOPICS do
            table.remove(topics)
        end
        row.last_topics = topics
    end
    if opts.incident and opts.incident ~= "" then
        local inc = row.incidents or {}
        table.insert(inc, 1, { id = tostring(opts.incident), t = now })
        while #inc > M.MAX_INCIDENTS do
            table.remove(inc)
        end
        row.incidents = inc
    end
    pcall(function()
        if ModData and ModData.transmit then
            -- Global ModData sync: server/host only in B42 MP
            local isS = false
            pcall(function()
                isS = isServer and isServer()
            end)
            if isS or not (isClient and isClient()) then
                ModData.transmit(M.MODDATA_KEY)
            end
        end
    end)
    return row
end

function M.isReunion(aKey, bKey)
    local row = M.getPair(aKey, bKey)
    if not row then return false end
    if (row.met or 0) < 1 then return false end
    local gap = nowSec() - (row.last_seen or 0)
    return gap >= M.REUNION_GAP_SEC
end

--- Soft 2–3 lines for the dialogue prompt (never a biography dump).
function M.promptSoft(speakerKey, otherKeys)
    otherKeys = otherKeys or {}
    local lines = {}
    for i = 1, math.min(#otherKeys, 3) do
        local ok = otherKeys[i]
        if ok and ok ~= speakerKey then
            local row = M.getPair(speakerKey, ok)
            if not row or (row.met or 0) < 1 then
                lines[#lines + 1] = "vs " .. tostring(ok) .. ": first real contact — cautious, not a sitcom hello."
            else
                local aff = row.affinity or 0
                local tone = "neutral"
                if aff >= 2 then tone = "warmish"
                elseif aff <= -2 then tone = "wary/cold"
                end
                local topic = (row.last_topics and row.last_topics[1]) or ""
                local tip = "vs " .. tostring(ok) .. ": met " .. tostring(row.met)
                    .. "x, tone=" .. tone
                if topic ~= "" then
                    tip = tip .. ", last thread≈" .. tostring(topic)
                end
                local inc = row.incidents and row.incidents[1]
                if inc and inc.id then
                    tip = tip .. ", scar=" .. tostring(inc.id)
                end
                lines[#lines + 1] = tip
            end
        end
    end
    if #lines == 0 then
        return "No prior bonds on record — treat others as strangers with weight."
    end
    return table.concat(lines, " | ")
end

function M.affinityDeltaForTrigger(trigger)
    if trigger == "friendly_fire" then return -1 end
    if trigger == "player_kill_player" then return -3 end
    if trigger == "ally_hurt" or trigger == "illness_visible" then return 1 end
    if trigger == "player_died_near" then return 0 end
    if trigger == "reunion" or trigger == "aftershock_group" then return 1 end
    if trigger == "shared_danger" then return 1 end
    return 0
end

if C and C.log then
    C.log("Memory module loaded")
end
