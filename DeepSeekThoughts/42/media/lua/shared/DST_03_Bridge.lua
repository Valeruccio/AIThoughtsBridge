--[[
  File bridge: game <-> Python DeepSeek service via Zomboid/Lua/DeepSeekThoughts/
  Session-only: _pending / _lastRequestId reset on game start (see DST_Main).
]]

DSThoughts = DSThoughts or {}
DSThoughts.Bridge = DSThoughts.Bridge or {}

local B = DSThoughts.Bridge
local C = DSThoughts.Config

B._pending = false
B._lastRequestAt = 0
B._lastStatus = { state = "unknown", detail = "" }

-- Byte-safe JSON string escape (works with UTF-8; strips illegal control bytes)
local function escapeJsonString(s)
    s = tostring(s or "")
    local out = {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        local b = string.byte(ch)
        if ch == "\\" then
            out[#out + 1] = "\\\\"
        elseif ch == "\"" then
            out[#out + 1] = "\\\""
        elseif b == 8 then
            out[#out + 1] = "\\b"
        elseif b == 9 then
            out[#out + 1] = "\\t"
        elseif b == 10 then
            out[#out + 1] = "\\n"
        elseif b == 12 then
            out[#out + 1] = "\\f"
        elseif b == 13 then
            out[#out + 1] = "\\r"
        elseif b < 32 then
            out[#out + 1] = string.format("\\u%04x", b)
        else
            out[#out + 1] = ch
        end
    end
    return table.concat(out)
end

local function encodeNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        return "0"
    end
    local s = string.format("%.4f", n)
    s = s:gsub(",", ".")
    s = s:gsub("%.?0+$", "")
    if s == "" or s == "-" then s = "0" end
    return s
end

local function encode(value)
    local t = type(value)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return encodeNumber(value)
    elseif t == "string" then
        return "\"" .. escapeJsonString(value) .. "\""
    elseif t == "table" then
        local isArray = true
        local maxn = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
                break
            end
            if k > maxn then maxn = k end
        end
        if isArray and maxn == #value then
            local parts = {}
            for i = 1, #value do
                parts[#parts + 1] = encode(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(value) do
                parts[#parts + 1] = "\"" .. escapeJsonString(tostring(k)) .. "\":" .. encode(v)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function utf8FromCodepoint(code)
    if not code or code < 0 then return "?" end
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(
            0xC0 + math.floor(code / 64),
            0x80 + (code % 64)
        )
    elseif code < 0x10000 then
        return string.char(
            0xE0 + math.floor(code / 4096),
            0x80 + (math.floor(code / 64) % 64),
            0x80 + (code % 64)
        )
    end
    return "?"
end

local function extractJsonStringField(str, key)
    if not str or not key then return nil end
    local needle = "\"" .. key .. "\""
    local pos = string.find(str, needle, 1, true)
    if not pos then return nil end
    local colon = string.find(str, ":", pos + #needle, true)
    if not colon then return nil end
    local i = colon + 1
    while i <= #str do
        local ch = str:sub(i, i)
        if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
            break
        end
        i = i + 1
    end
    if str:sub(i, i) ~= "\"" then
        return nil
    end
    i = i + 1
    local out = {}
    while i <= #str do
        local ch = str:sub(i, i)
        if ch == "\\" then
            local n = str:sub(i + 1, i + 1)
            if n == "n" then
                out[#out + 1] = "\n"
                i = i + 2
            elseif n == "t" then
                out[#out + 1] = "\t"
                i = i + 2
            elseif n == "\"" or n == "\\" or n == "/" then
                out[#out + 1] = n
                i = i + 2
            elseif n == "u" then
                local hex = str:sub(i + 2, i + 5)
                local code = tonumber(hex, 16)
                out[#out + 1] = utf8FromCodepoint(code)
                i = i + 6
            else
                out[#out + 1] = n
                i = i + 2
            end
        elseif ch == "\"" then
            return table.concat(out)
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end
    return nil
end

local function extractJsonBoolField(str, key)
    if not str or not key then return nil end
    local needle = "\"" .. key .. "\""
    local pos = string.find(str, needle, 1, true)
    if not pos then return nil end
    local colon = string.find(str, ":", pos + #needle, true)
    if not colon then return nil end
    local rest = string.sub(str, colon + 1, colon + 20)
    if string.find(rest, "true", 1, true) then return true end
    if string.find(rest, "false", 1, true) then return false end
    return nil
end

local function decodeSimple(str)
    if not str or str == "" then return nil end
    local result = {}
    result.request_id = extractJsonStringField(str, "request_id")
    result.thought = extractJsonStringField(str, "thought")
    result.kind = extractJsonStringField(str, "kind")
    result.address_mode = extractJsonStringField(str, "address_mode")
    result.address_to = extractJsonStringField(str, "address_to")
    result.should_end = extractJsonBoolField(str, "should_end")
    if string.find(str, "\"error\"%s*:%s*null") then
        result.error = nil
    else
        result.error = extractJsonStringField(str, "error")
    end
    return result
end

local function clearInbox()
    local path = C.InboxRelPath
    local w = getFileWriter(path, true, false)
    if w then w:write(""); w:close() end
end

function B.writeRequest(snapshot)
    if not snapshot then return false end
    if C.refreshIoPaths then C.refreshIoPaths() end
    local json = encode(snapshot)
    local writer = getFileWriter(C.OutboxRelPath, true, false)
    if not writer then
        DSThoughts.Config.log("Failed to open outbox writer")
        return false
    end
    writer:write(json)
    writer:close()
    B._pending = true
    B._lastRequestAt = getTimestamp and getTimestamp() or os.time()
    B._lastRequestId = snapshot.request_id
    DSThoughts.Config.log("Request written: " .. tostring(snapshot.request_id))
    return true
end

function B.canRequest(minGapOverride)
    if B._pending then return false end
    local now = getTimestamp and getTimestamp() or os.time()
    local minGap = minGapOverride
    if minGap == nil then
        minGap = C.MinSecondsBetweenThoughts or 18
    end
    if (now - (B._lastRequestAt or 0)) < minGap then
        return false
    end
    return true
end

function B.readStatus()
    if C.refreshIoPaths then C.refreshIoPaths() end
    local reader = getFileReader(C.StatusRelPath, true)
    if not reader then
        B._lastStatus = { state = "offline", detail = "no status.txt" }
        return B._lastStatus
    end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    local raw = table.concat(lines, "\n")
    if raw == "" then
        B._lastStatus = { state = "offline", detail = "empty status" }
        return B._lastStatus
    end
    local state = extractJsonStringField(raw, "state") or "unknown"
    local detail = extractJsonStringField(raw, "detail") or ""
    local provider = extractJsonStringField(raw, "provider") or ""
    local model = extractJsonStringField(raw, "model") or ""
    B._lastStatus = {
        state = state,
        detail = detail,
        provider = provider,
        model = model,
    }
    return B._lastStatus
end

function B.pollResponseFull()
    if C.refreshIoPaths then C.refreshIoPaths() end
    local reader = getFileReader(C.InboxRelPath, true)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    local raw = table.concat(lines, "\n")
    if raw == "" then
        if B._pending then
            local now = getTimestamp and getTimestamp() or os.time()
            if B._lastRequestAt and (now - B._lastRequestAt) > 180 then
                B._pending = false
                DSThoughts.Config.log("Pending timeout — cleared (no inbox response)")
                B._lastStatus = { state = "timeout", detail = "no inbox response" }
            end
        end
        return nil
    end

    if not string.find(raw, "\"request_id\"", 1, true) then
        return nil
    end

    local data = decodeSimple(raw)
    if not data then
        DSThoughts.Config.log("Inbox JSON decode failed")
        return nil
    end

    local thought = data.thought
    if thought then
        thought = tostring(thought):gsub("^%s+", ""):gsub("%s+$", "")
        data.thought = thought
    end

    local idOk = (data.request_id and B._lastRequestId and data.request_id == B._lastRequestId)
    if not B._pending and not idOk then
        local now = getTimestamp and getTimestamp() or os.time()
        if B._lastRequestAt and (now - B._lastRequestAt) > 5 then
            clearInbox()
        end
        return nil
    end

    if data.error or not thought or thought == "" then
        if data.error then
            DSThoughts.Config.log("Bridge error: " .. tostring(data.error))
            B._lastStatus = { state = "error", detail = tostring(data.error) }
        else
            DSThoughts.Config.log("Empty thought from bridge — will retry later")
        end
        B._pending = false
        clearInbox()
        return nil
    end

    clearInbox()
    B._pending = false
    DSThoughts.Config.log("Thought received: " .. tostring(thought))
    return data
end

function B.pollResponse()
    local data = B.pollResponseFull()
    if not data then return nil end
    return data.thought
end
