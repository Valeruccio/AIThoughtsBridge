--[[
  AI Thoughts — shared config (Build 42).
  Session defaults; IO paths refreshed for SP vs local multi-player.
  Bridge files use .txt (JSON body) — B42 getFileWriter-friendly.
]]

DSThoughts = DSThoughts or {}
DSThoughts.Config = DSThoughts.Config or {}

local C = DSThoughts.Config

-- Overridden by settings.txt / UI / sandbox
C.Language = "ru"
C.SwearLevel = "light"
C.Enabled = true
-- Private sticky by default; thoughts never broadcast to other players in Mode B
C.ThinkAloud = false
-- MP Mode: "B" = host bridge (default). "A" unused.
C.MpMode = "B"
-- Spoken dialogue between nearby players (Mode B / MP)
C.DialogueEnabled = true
C.DialogueAttractsZombies = true
C.DialogueHearRadius = 12
C.DialogueStartRadius = 8
C.DialogueMaxTurns = 6
C.DialogueTurnGapSec = 10
C.DialogueCooloffSec = 240
C.DialogueSoundRadius = 18
C.DialogueDisplaySeconds = 8
-- Quiet small talk (never attracts zombies)
C.SmallTalkEnabled = true
C.BanterHeat = "normal" -- soft | normal | spicy
C.SmallTalkMinutes = 10 -- group cooloff minutes for casual
C.SmallTalkMaxTurns = 3
C.SmallTalkTurnGapSec = 7

-- Display sticky duration
C.ThoughtDisplaySeconds = 9
-- Absolute floor between thoughts (must be >= 2x display)
C.MinSecondsBetweenThoughts = 18
-- Calm mind_wander cadence (~4–5 min)
C.CalmAmbientSeconds = 270
-- Soft driving ambient
C.VehicleAmbientSeconds = 100
-- Soft chase (on foot)
C.ChaseSeconds = 80
-- Soft chase while in a vehicle (much rarer — shell of metal)
C.ChaseVehicleSeconds = 120
-- While still near TV/radio: extra comment cadence (same show OK)
C.MediaAmbientSeconds = 90
-- Hear TV/radio thoughts only within this many tiles of a powered device
C.MediaHearRadius = 8
-- Media sensor cache TTL (seconds)
C.MediaScanCacheSeconds = 2.5
-- Inbox poll while waiting for bridge
C.PollPendingMs = 500
-- Inbox poll when idle
C.PollIdleMs = 2000

-- Relative paths under Zomboid/Lua/ (refreshed by refreshIoPaths)
-- B42: prefer .txt extensions for getFileWriter; payload remains JSON text.
C.OutboxRelPath = "DeepSeekThoughts/outbox/request.txt"
C.InboxRelPath = "DeepSeekThoughts/inbox/response.txt"
C.StatusRelPath = "DeepSeekThoughts/status.txt"
C.IoRootRel = "DeepSeekThoughts"

C.SettingsKeyName = "F9"
-- Force nearby dialogue (default Home). Client keycode; override via settings later if needed.
C.ForceDialogueKey = "HOME"
C.ForceDialogueCooloffSec = 5
C.Debug = false

--- Sanitize folder segment for per-player IO
local function sanitizeTag(s)
    s = tostring(s or "local")
    s = s:gsub("[^%w%-_]", "_")
    if s == "" then s = "local" end
    if #s > 48 then s = string.sub(s, 1, 48) end
    return s
end

--- Player tag for IO isolation (split-screen / MP client-local).
function C.playerIoTag()
    local tag = "local"
    pcall(function()
        if getCurrentUserProfileName then
            local n = getCurrentUserProfileName()
            if n and tostring(n) ~= "" then
                tag = tostring(n)
                return
            end
        end
        local player = getPlayer and getPlayer() or nil
        if player and player.getUsername then
            local u = player:getUsername()
            if u and tostring(u) ~= "" then
                tag = tostring(u)
                return
            end
        end
        if player and player.getDisplayName then
            local d = player:getDisplayName()
            if d and tostring(d) ~= "" then
                tag = tostring(d)
            end
        end
    end)
    return sanitizeTag(tag)
end

--- Mode B / SP host: always flat DeepSeekThoughts/ root for the Python bridge.
--- Per-player dirs are unused in Mode B (server-proxy).
function C.refreshIoPaths()
    local root = "DeepSeekThoughts"
    -- Optional legacy split only if explicitly enabled (Mode A leftover; off by default)
    if C.UsePerPlayerIo then
        local usePlayerDir = false
        pcall(function()
            if isClient and isClient() and not (isServer and isServer()) then
                usePlayerDir = true
            end
            if getNumActivePlayers and getNumActivePlayers() > 1 then
                usePlayerDir = true
            end
        end)
        if usePlayerDir then
            root = "DeepSeekThoughts/" .. C.playerIoTag()
        end
    end
    C.IoRootRel = root
    C.OutboxRelPath = root .. "/outbox/request.txt"
    C.InboxRelPath = root .. "/inbox/response.txt"
    C.StatusRelPath = root .. "/status.txt"
end

-- Mode B default: one shared outbox on the host
C.UsePerPlayerIo = false

C.refreshIoPaths()

function DSThoughts.Config.log(msg)
    if C.Debug then
        print("[DeepSeekThoughts] " .. tostring(msg))
    end
end
