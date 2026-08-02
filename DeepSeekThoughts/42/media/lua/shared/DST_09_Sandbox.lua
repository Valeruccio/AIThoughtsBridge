--[[
  Apply sandbox options (B42 SandboxVars preferred; getSandboxOptions fallback).
]]

DSThoughts = DSThoughts or {}
DSThoughts.Sandbox = DSThoughts.Sandbox or {}

local SB = DSThoughts.Sandbox
local C = DSThoughts.Config

function SB.apply()
    pcall(function()
        local B42 = DSThoughts.B42
        local function sv(key, default)
            if B42 and B42.sandboxValue then
                return B42.sandboxValue("DeepSeekThoughts", key, default)
            end
            return default
        end

        local en = sv("Enabled", nil)
        if en ~= nil then
            C.Enabled = en and true or false
        end
        local de = sv("DialogueEnabled", nil)
        if de ~= nil then
            C.DialogueEnabled = de and true or false
        end
        local daz = sv("DialogueAttractsZombies", nil)
        if daz ~= nil then
            C.DialogueAttractsZombies = daz and true or false
        end
        local st = sv("SmallTalkEnabled", nil)
        if st ~= nil then
            C.SmallTalkEnabled = st and true or false
        end

        local bh = sv("BanterHeat", nil)
        if bh ~= nil then
            local v = tostring(bh)
            if v == "1" or v == "soft" then
                C.BanterHeat = "soft"
            elseif v == "3" or v == "spicy" then
                C.BanterHeat = "spicy"
            else
                C.BanterHeat = "normal"
            end
        end

        -- Fallback when SandboxVars not populated yet
        if not getSandboxOptions then return end
        local opts = getSandboxOptions()
        if not opts then return end
        local function opt(name)
            if opts.getOptionByName then
                return opts:getOptionByName(name)
            end
            return nil
        end
        if en == nil then
            local o = opt("DeepSeekThoughts.Enabled")
            if o and o.getValue then C.Enabled = o:getValue() and true or false end
        end
        if de == nil then
            local o = opt("DeepSeekThoughts.DialogueEnabled")
            if o and o.getValue then C.DialogueEnabled = o:getValue() and true or false end
        end
        if daz == nil then
            local o = opt("DeepSeekThoughts.DialogueAttractsZombies")
            if o and o.getValue then C.DialogueAttractsZombies = o:getValue() and true or false end
        end
        if st == nil then
            local o = opt("DeepSeekThoughts.SmallTalkEnabled")
            if o and o.getValue then C.SmallTalkEnabled = o:getValue() and true or false end
        end
        if bh == nil then
            local o = opt("DeepSeekThoughts.BanterHeat")
            if o and o.getValue then
                local v = tostring(o:getValue() or "normal")
                if v == "1" or v == "soft" then C.BanterHeat = "soft"
                elseif v == "3" or v == "spicy" then C.BanterHeat = "spicy"
                else C.BanterHeat = "normal" end
            end
        end
    end)
end
