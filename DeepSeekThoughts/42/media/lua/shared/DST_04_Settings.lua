--[[
  Persistent settings: Zomboid/Lua/DeepSeekThoughts/settings.txt
  API keys live ONLY in the Python bridge (bridge_config.json / .env).
]]

DSThoughts = DSThoughts or {}
DSThoughts.Settings = DSThoughts.Settings or {}

local S = DSThoughts.Settings
local C = DSThoughts.Config

S.RelPath = "DeepSeekThoughts/settings.txt"

S.defaults = {
    language = "ru",
    swear_level = "light", -- none | light | medium | heavy
    display_seconds = "9",
    min_seconds_between = "18",
    enabled = "true",
    think_aloud = "false",
    debug = "false",
}

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function S.applyToConfig(map)
    if not map then return end
    if map.language and map.language ~= "" then
        local lang = map.language
        if lang ~= "ru" and lang ~= "en" then
            lang = "ru"
        end
        C.Language = lang
        map.language = lang
    end
    if map.display_seconds then
        local n = tonumber(map.display_seconds)
        if n then
            if n < 3 then n = 3 end
            if n > 60 then n = 60 end
            C.ThoughtDisplaySeconds = n
            map.display_seconds = tostring(n)
        end
    end
    if map.min_seconds_between then
        local n = tonumber(map.min_seconds_between)
        if n then
            local floor = math.max(18, math.floor((C.ThoughtDisplaySeconds or 9) * 2))
            if n < floor then n = floor end
            if n > 300 then n = 300 end
            C.MinSecondsBetweenThoughts = n
            map.min_seconds_between = tostring(n)
        end
    end
    if map.swear_level and map.swear_level ~= "" then
        local ok = { none = true, light = true, medium = true, heavy = true }
        if ok[map.swear_level] then
            C.SwearLevel = map.swear_level
        else
            C.SwearLevel = "light"
            map.swear_level = "light"
        end
    end
    if map.enabled ~= nil then
        C.Enabled = (map.enabled == "true" or map.enabled == true or map.enabled == "1")
    end
    if map.think_aloud ~= nil then
        C.ThinkAloud = (map.think_aloud == "true" or map.think_aloud == true or map.think_aloud == "1")
    end
    if map.debug ~= nil then
        C.Debug = (map.debug == "true" or map.debug == true or map.debug == "1")
    end
end

function S.load()
    local map = {}
    for k, v in pairs(S.defaults) do
        map[k] = v
    end
    local reader = getFileReader(S.RelPath, true)
    if reader then
        local line = reader:readLine()
        while line do
            local key, val = string.match(line, "^([%w_]+)%s*=%s*(.*)$")
            if key then
                -- Ignore legacy api_key lines; secrets belong in the bridge only
                if key ~= "api_key" then
                    map[key] = trim(val)
                end
            end
            line = reader:readLine()
        end
        reader:close()
    end
    S.applyToConfig(map)
    S.cache = map
    return map
end

function S.save(map)
    map = map or S.cache or S.defaults
    local writer = getFileWriter(S.RelPath, true, false)
    if not writer then
        C.log("Failed to save settings")
        return false
    end
    local keys = {
        "language",
        "swear_level",
        "display_seconds",
        "min_seconds_between",
        "enabled",
        "think_aloud",
        "debug",
    }
    for _, k in ipairs(keys) do
        local v = map[k]
        if v == nil then v = S.defaults[k] end
        writer:write(k .. "=" .. tostring(v) .. "\n")
    end
    writer:close()
    S.cache = map
    S.applyToConfig(map)
    C.log("Settings saved (lang=" .. tostring(map.language) .. ", swear=" .. tostring(map.swear_level) .. ")")
    return true
end

function S.get(key)
    if not S.cache then S.load() end
    return (S.cache and S.cache[key]) or S.defaults[key]
end
