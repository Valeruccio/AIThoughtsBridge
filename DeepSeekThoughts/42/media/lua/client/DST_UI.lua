--[[
  Personal settings (F9): language, swear, display, enable, think-aloud.
  Server/sandbox and Bridge Launcher own the rest.
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"

DSThoughts = DSThoughts or {}
DSThoughts.UI = DSThoughts.UI or {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

local DSThoughtsPanel = ISCollapsableWindow:derive("DSThoughtsPanel")

function DSThoughtsPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local pad = 12
    local y = 40
    local labelW = 140
    local fieldX = pad + labelW
    local fieldW = self.width - fieldX - pad

    local function addLabel(text, yy)
        local lab = ISLabel:new(pad, yy, FONT_HGT_SMALL, text, 1, 1, 1, 1, UIFont.Small, true)
        lab:initialise()
        lab:instantiate()
        self:addChild(lab)
        return lab
    end

    addLabel("Язык", y)
    self.langCombo = ISComboBox:new(fieldX, y - 2, fieldW, 22, self, nil)
    self.langCombo:initialise()
    self.langCombo:addOption("Русский")
    self.langCombo:addOption("English")
    self:addChild(self.langCombo)
    y = y + 30

    addLabel("Мат", y)
    self.swearCombo = ISComboBox:new(fieldX, y - 2, fieldW, 22, self, nil)
    self.swearCombo:initialise()
    self.swearCombo:addOption("Нет")
    self.swearCombo:addOption("Лёгкий")
    self.swearCombo:addOption("Средний")
    self.swearCombo:addOption("Жёсткий")
    self:addChild(self.swearCombo)
    y = y + 30

    addLabel("Показ (сек)", y)
    self.displayEntry = ISTextEntryBox:new("9", fieldX, y - 2, fieldW, 22)
    self.displayEntry:initialise()
    self.displayEntry:instantiate()
    self.displayEntry:setOnlyNumbers(true)
    self:addChild(self.displayEntry)
    y = y + 34

    self.enableTick = ISTickBox:new(pad, y, 300, 20, "", self, nil)
    self.enableTick:initialise()
    self.enableTick:instantiate()
    self.enableTick:addOption("Мысли включены")
    self:addChild(self.enableTick)
    y = y + 24

    self.thinkAloudTick = ISTickBox:new(pad, y, 300, 20, "", self, nil)
    self.thinkAloudTick:initialise()
    self.thinkAloudTick:instantiate()
    self.thinkAloudTick:addOption("Думать вслух (может привлечь зомби)")
    self:addChild(self.thinkAloudTick)
    y = y + 32

    local btnW = 100
    self.saveBtn = ISButton:new(pad, y, btnW, 26, "Сохранить", self, DSThoughtsPanel.onSave)
    self.saveBtn:initialise()
    self.saveBtn:instantiate()
    self:addChild(self.saveBtn)

    self.closeBtn = ISButton:new(pad + btnW + 10, y, btnW, 26, "Закрыть", self, DSThoughtsPanel.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)

    self.hint = ISLabel:new(pad + (btnW + 10) * 2, y + 4, FONT_HGT_SMALL,
        "",
        0.75, 0.85, 0.7, 1, UIFont.Small, true)
    self.hint:initialise()
    self:addChild(self.hint)

    self:loadIntoControls()
end

function DSThoughtsPanel:loadIntoControls()
    local map = DSThoughts.Settings.load()
    local lang = map.language or "ru"
    if lang == "en" then
        self.langCombo.selected = 2
    else
        self.langCombo.selected = 1
    end

    local swear = map.swear_level or "light"
    local swearIdx = { none = 1, light = 2, medium = 3, heavy = 4 }
    self.swearCombo.selected = swearIdx[swear] or 2

    self.displayEntry:setText(tostring(map.display_seconds or "9"))
    self.enableTick:setSelected(1, map.enabled ~= "false" and map.enabled ~= "0")
    self.thinkAloudTick:setSelected(1, map.think_aloud == "true" or map.think_aloud == "1")
end

function DSThoughtsPanel:collectMap()
    local map = DSThoughts.Settings.load()
    local language = "ru"
    if self.langCombo.selected == 2 then language = "en" end

    local swearMap = { "none", "light", "medium", "heavy" }
    local swear = swearMap[self.swearCombo.selected] or "light"

    map.language = language
    map.swear_level = swear
    map.display_seconds = self.displayEntry:getText() or "9"
    map.enabled = self.enableTick:isSelected(1) and "true" or "false"
    map.think_aloud = self.thinkAloudTick:isSelected(1) and "true" or "false"
    -- Keep pacing / debug from file; not exposed in UI
    map.min_seconds_between = map.min_seconds_between or "18"
    map.debug = map.debug or "false"
    return map
end

function DSThoughtsPanel:onSave()
    local map = self:collectMap()
    if DSThoughts.Settings.save(map) then
        self.hint.name = "Сохранено"
    else
        self.hint.name = "Ошибка сохранения"
    end
end

function DSThoughtsPanel:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    DSThoughts.UI.instance = nil
end

function DSThoughtsPanel:close()
    self:onClose()
end

function DSThoughtsPanel:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "AI Thoughts"
    o.resizable = false
    return o
end

function DSThoughts.UI.toggle()
    if DSThoughts.UI.instance then
        DSThoughts.UI.instance:onClose()
        return
    end
    local w, h = 420, 260
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    local panel = DSThoughtsPanel:new(x, y, w, h)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    DSThoughts.UI.instance = panel
end

local function onKeyPressed(key)
    if key == Keyboard.KEY_F9 and getPlayer() then
        DSThoughts.UI.toggle()
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
Events.OnGameStart.Add(function()
    if DSThoughts.Settings then
        DSThoughts.Settings.load()
    end
end)
