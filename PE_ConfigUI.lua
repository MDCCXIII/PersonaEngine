-- ##################################################
-- PE_ConfigUI.lua
-- Persona Engine configuration UI (macro-centric)
-- ##################################################

local MODULE = "ConfigUI"
local PE     = PE
local UI     = PE and PE.UI

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Text styling
----------------------------------------------------

local GLOBAL_FONT_SCALE = 1.0

local TEXT_STYLES = {
    TITLE = {
        template   = "GameFontHighlight",
        sizeOffset = 0,
        color      = { 1.0, 0.96, 0.41, 1.0 },
    },
    HEADER = {
        template   = "GameFontNormalLarge",
        sizeOffset = 0,
        color      = { 1.0, 0.82, 0.0, 1.0 },
    },
    LABEL = {
        template   = "GameFontNormal",
        sizeOffset = 0,
        color      = { 0.90, 0.90, 0.90, 1.0 },
    },
    HINT = {
        template   = "GameFontHighlightSmall",
        sizeOffset = 0,
        color      = { 0.75, 0.75, 0.75, 1.0 },
    },
    EMPHASIS = {
        template   = "GameFontHighlight",
        sizeOffset = 0,
        color      = { 1.0, 1.0, 1.0, 1.0 },
    },
}

local function StyleText(widget, styleKey, overrides)
    if not widget or not styleKey then return end
    local style = TEXT_STYLES[styleKey]
    if not style then return end

    overrides = overrides or {}

    local template   = overrides.template   or style.template
    local sizeOffset = overrides.sizeOffset or style.sizeOffset or 0
    local scale      = overrides.scale      or GLOBAL_FONT_SCALE or 1.0
    local color      = overrides.color      or style.color

    if template then
        widget:SetFontObject(template)
    end

    local font, size, flags = widget:GetFont()
    if font and size then
        widget:SetFont(font, size * scale + sizeOffset, flags)
    end

    if color then
        widget:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

----------------------------------------------------
-- Local helpers
----------------------------------------------------

local function GetActionByInput(input)
    if not input or input == "" then return nil end
    if not PE.ResolveActionFromInput then return nil end
    return PE.ResolveActionFromInput(input)
end

----------------------------------------------------
-- Config frame
----------------------------------------------------

local configFrame
local currentAction -- { kind, id, name, icon }

local function BuildConfigFrame()
    if configFrame then return end

    ------------------------------------------------
    -- Window
    ------------------------------------------------

    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id        = "Config",
            title     = "Persona Engine – Config",
            width     = 700,
            height    = 750,
            minWidth  = 520,
            minHeight = 430,
            strata    = "DIALOG",
            level     = 100,
        })
        if configFrame.title then
            StyleText(configFrame.title, "TITLE")
        end
    else
        configFrame = CreateFrame("Frame", "PersonaEngineConfigFrame", UIParent, "BasicFrameTemplateWithInset")
        configFrame:SetSize(700, 750)
        configFrame:SetPoint("CENTER")
        configFrame:SetFrameStrata("DIALOG")
        configFrame:SetFrameLevel(100)
        configFrame:SetMovable(true)
        configFrame:EnableMouse(true)
        configFrame:RegisterForDrag("LeftButton")
        configFrame:SetScript("OnDragStart", configFrame.StartMoving)
        configFrame:SetScript("OnDragStop",  configFrame.StopMovingOrSizing)

        local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if configFrame.TitleBg then
            title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
        else
            title:SetPoint("TOPLEFT", 10, -5)
        end
        title:SetText("Persona Engine – Config")
        StyleText(title, "TITLE")
        configFrame.title = title

        configFrame:Hide()
    end

    if not _G["PersonaEngineConfigFrame"] then
        _G["PersonaEngineConfigFrame"] = configFrame
    end

    ------------------------------------------------
    -- Tabs
    ------------------------------------------------

    local actionPage   = CreateFrame("Frame", nil, configFrame)
    local settingsPage = CreateFrame("Frame", nil, configFrame)

    actionPage:SetPoint("TOPLEFT",     configFrame, "TOPLEFT",     8,  -60)
    actionPage:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -8,  8)

    settingsPage:SetPoint("TOPLEFT",     actionPage, "TOPLEFT", 0, 0)
    settingsPage:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", 0, 0)
    settingsPage:Hide()

    local tabButtons = {}

    local function SetActivePage(idx)
        for i, btn in ipairs(tabButtons) do
            if i == idx then
                btn:LockHighlight()
                if btn.page then btn.page:Show() end
            else
                btn:UnlockHighlight()
                if btn.page then btn.page:Hide() end
            end
        end
    end

    local tab1 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab1:SetText("Macro Studio")
    tab1:SetHeight(20)
    tab1:SetWidth(tab1:GetTextWidth() + 24)
    tab1:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 12, -30)
    tab1.page = actionPage
    tab1:SetScript("OnClick", function() SetActivePage(1) end)
    tabButtons[1] = tab1

    local tab2 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab2:SetText("Settings")
    tab2:SetHeight(20)
    tab2:SetWidth(tab2:GetTextWidth() + 24)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 6, 0)
    tab2.page = settingsPage
    tab2:SetScript("OnClick", function() SetActivePage(2) end)
    tabButtons[2] = tab2

    SetActivePage(1)

    local settingsLabel = settingsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsLabel:SetPoint("TOPLEFT", 8, -8)
    settingsLabel:SetText("Persona Engine Settings (coming soon)")
    StyleText(settingsLabel, "HEADER")

    ------------------------------------------------
    -- Macro name row
    ------------------------------------------------

    local macroNameLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroNameLabel:SetPoint("TOPLEFT", actionPage, "TOPLEFT", 8, -4)
    macroNameLabel:SetText("Macro Name (Max 16 Characters):")
    StyleText(macroNameLabel, "LABEL")

    local macroNameEdit = CreateFrame("EditBox", nil, actionPage, "InputBoxTemplate")
    macroNameEdit:SetAutoFocus(false)
    macroNameEdit:SetHeight(20)
    macroNameEdit:SetMaxLetters(16)
    macroNameEdit:SetPoint("LEFT",  macroNameLabel, "RIGHT", 8, 0)
    macroNameEdit:SetPoint("RIGHT", actionPage,      "RIGHT", -8, 0)
    configFrame.macroNameEdit = macroNameEdit

    ------------------------------------------------
    -- Icon / primary action row
    ------------------------------------------------

    local iconLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", macroNameLabel, "BOTTOMLEFT", 0, -18)
    iconLabel:SetText("Icon Name or ID:")
    StyleText(iconLabel, "LABEL")

    local loadButton = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    loadButton:SetSize(70, 22)
    loadButton:SetPoint("TOPRIGHT", actionPage, "TOPRIGHT", -4, -26)
    loadButton:SetText("Load")

    local iconHelp = CreateFrame("Button", nil, actionPage)
    iconHelp:SetSize(16, 16)
    iconHelp:SetPoint("RIGHT", loadButton, "LEFT", -4, 0)
    local helpTex = iconHelp:CreateTexture(nil, "OVERLAY")
    helpTex:SetAllPoints()
    helpTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    local iconEdit = CreateFrame("EditBox", nil, actionPage, "InputBoxTemplate")
    iconEdit:SetAutoFocus(false)
    iconEdit:SetHeight(20)
    iconEdit:SetPoint("LEFT",  iconLabel, "RIGHT", 8, 0)
    iconEdit:SetPoint("RIGHT", iconHelp,  "LEFT", -26, 0)
    configFrame.spellEdit = iconEdit      -- used by ChatEdit_InsertLink hook

    local iconTexture = actionPage:CreateTexture(nil, "OVERLAY")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("LEFT", iconEdit, "RIGHT", 4, 0)
    iconTexture:SetTexture(134400) -- question mark
    configFrame.iconTexture        = iconTexture
    configFrame.selectedIconTexture = 134400

    local iconButton = CreateFrame("Button", nil, actionPage)
    iconButton:SetSize(24, 24)
    iconButton:SetPoint("CENTER", iconTexture, "CENTER")
    iconButton:EnableMouse(true)

    iconHelp:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Icon & primary action", 1, 1, 1, true)
        GameTooltip:AddLine("• Type an icon name like |cffffff00inv_misc_bag_03|r or a file ID.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Shift-click a spell or item into this box to copy its name.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Click |cffffff00Load|r to bind a primary spell or item.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Click the icon to open the full icon selector.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    iconHelp:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local iconInfoText = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconInfoText:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -4)
    iconInfoText:SetWidth(420)
    iconInfoText:SetJustifyH("LEFT")
    StyleText(iconInfoText, "HINT")
    iconInfoText:SetText("|cffff2020No icon / action provided.|r")

    ------------------------------------------------
    -- Icon suggestions (via UI.AttachIconAutocomplete)
    ------------------------------------------------

    if UI and UI.AttachIconAutocomplete then
        UI.AttachIconAutocomplete(iconEdit, {
            parent = actionPage,
            onIconChosen = function(data)
                configFrame.selectedIconTexture = data.texture or 134400
                iconTexture:SetTexture(configFrame.selectedIconTexture)
                iconEdit:SetText(data.name or "")
            end,
        })
    end

    ------------------------------------------------
    -- Primary action state + load button
    ------------------------------------------------

    local function LoadActionByInput()
        local txt = iconEdit:GetText()
        if not txt or txt == "" then
            iconInfoText:SetText("|cffff2020No icon / action provided.|r")
            currentAction = nil
            return
        end

        local action = GetActionByInput(txt)

        -- Only treat as primary spell/item. Unknown / emote input becomes "icon only".
        if not action or (action.kind == "emote") then
            currentAction = nil
            iconInfoText:SetText("|cffffff00Icon selected.|r No spell or item bound as a primary action.")
            return
        end

        currentAction = action

        if not configFrame.selectedIconTexture then
            configFrame.selectedIconTexture = action.icon or 134400
            iconTexture:SetTexture(configFrame.selectedIconTexture)
        end

        local summary = PE.FormatActionSummary and PE.FormatActionSummary(action)
        if not summary then
            summary = string.format(
                "Spell/Item: |cffffff00%s|r (ID %s)",
                tostring(action.name or "?"),
                tostring(action.id   or "?")
            )
        end
        iconInfoText:SetText(summary)
    end

    loadButton:SetScript("OnClick", LoadActionByInput)

    ------------------------------------------------
    -- Icon picker popup (via UI.CreateIconPicker)
    ------------------------------------------------

    local iconPickerFrame

    iconButton:SetScript("OnClick", function()
        if not UI or not UI.CreateIconPicker then
            return
        end
        if not iconPickerFrame then
            iconPickerFrame = UI.CreateIconPicker({
                parent = configFrame,
                id     = "IconPicker",
                title  = "Choose an Icon:",
                onIconChosen = function(data)
                    configFrame.selectedIconTexture = data.texture or 134400
                    iconTexture:SetTexture(configFrame.selectedIconTexture)
                    iconEdit:SetText(data.name or "")
                end,
            })
        end
        iconPickerFrame:Show()
    end)
end

----------------------------------------------------
-- Public toggle
----------------------------------------------------

function PE.ToggleConfig()
    BuildConfigFrame()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

----------------------------------------------------
-- ChatEdit_InsertLink hook for icon box
----------------------------------------------------

do
    if ChatEdit_InsertLink then
        if not PE._OrigChatEdit_InsertLink then
            PE._OrigChatEdit_InsertLink = ChatEdit_InsertLink
        end
        local Orig = PE._OrigChatEdit_InsertLink

        ChatEdit_InsertLink = function(text)
            if Orig(text) then
                return true
            end

            if configFrame and configFrame:IsShown()
               and configFrame.spellEdit and configFrame.spellEdit:HasFocus()
            then
                local name = text:match("%[(.+)%]")
                if name then
                    configFrame.spellEdit:SetText(name)
                    configFrame.spellEdit:HighlightText(0, -1)
                    return true
                end
            end

            return false
        end
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("ConfigUI", {
        name  = "Config UI",
        class = "ui",
    })
end
