-- ##################################################
-- PE_ConfigUI.lua
-- Persona Engine spell-bubble configuration UI
-- ##################################################

local MODULE = "ConfigUI"
local PE     = PE
local UI     = PE and PE.UI -- shorthand for widgets

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Text style / theme
----------------------------------------------------

-- Global knob: bump this to resize *all* config text
local GLOBAL_FONT_SCALE = 1.0 -- e.g. 0.9, 1.0, 1.1

local TEXT_STYLES = {
    TITLE = {
        template   = "GameFontHighlight",
        sizeOffset = 0,
        color      = { 1.0, 0.96, 0.41, 1.0 }, -- gold
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
        local newSize = size * scale + sizeOffset
        widget:SetFont(font, newSize, flags)
    end

    if color then
        widget:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

----------------------------------------------------
-- Spell / action lookup wrappers
----------------------------------------------------

local function GetSpellInfoByInput(input)
    if not input or input == "" then return end

    local spellID = tonumber(input)
    local name, icon, id

    -- Dragonflight API
    if C_Spell and C_Spell.GetSpellInfo then
        if spellID then
            local info = C_Spell.GetSpellInfo(spellID)
            if info then
                return info.name, info.iconID, info.spellID
            end
        else
            local info = C_Spell.GetSpellInfo(input)
            if info then
                return info.name, info.iconID, info.spellID
            end
        end
    end

    -- Classic GetSpellInfo fallback
    if GetSpellInfo then
        if spellID then
            name, _, icon = GetSpellInfo(spellID)
            id = spellID
        else
            name, _, icon, _, _, _, id = GetSpellInfo(input)
        end
        if name then
            return name, icon, id
        end
    end

    return nil
end

-- Action lookup wrapper (spell / item / emote)
local function GetActionByInput(input)
    -- Guard: if PE_Actions.lua didn't load for some reason
    if not PE or not PE.ResolveActionFromInput then
        return nil
    end
    return PE.ResolveActionFromInput(input)
end

----------------------------------------------------
-- Config frame construction
----------------------------------------------------

local configFrame

local function BuildConfigFrame()
    if configFrame then return end

    ------------------------------------------------
    -- Main window via UI widget (persistent + resizable)
    ------------------------------------------------
    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id       = "Config",
            title    = "Persona Engine \226\128\147 Config",
            width    = 700,
            height   = 750,
            minWidth = 520,
            minHeight= 430,
            strata   = "DIALOG",
            level    = 100,
        })

        if configFrame.title then
            StyleText(configFrame.title, "TITLE")
        end
    else
        -- Fallback: simple frame if widgets are missing
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
        title:SetText("Persona Engine \226\128\147 Config")
        configFrame.title = title
        StyleText(title, "TITLE")

        configFrame:Hide()
    end

    -- Backwards-compat alias
    if not _G["PersonaEngineConfigFrame"] then
        _G["PersonaEngineConfigFrame"] = configFrame
    end

    ------------------------------------------------
    -- Tabs & pages
    ------------------------------------------------
    local tabButtons = {}

    local actionPage = CreateFrame("Frame", nil, configFrame)
    actionPage:SetPoint("TOPLEFT",     configFrame, "TOPLEFT",     8,  -60)
    actionPage:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -8,  8)

    local settingsPage = CreateFrame("Frame", nil, configFrame)
    settingsPage:SetPoint("TOPLEFT",     actionPage, "TOPLEFT",     0, 0)
    settingsPage:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", 0, 0)
    settingsPage:Hide()

    local function SetActivePage(index)
        for i, tab in ipairs(tabButtons) do
            if i == index then
                tab:LockHighlight()
                if tab.page then tab.page:Show() end
            else
                tab:UnlockHighlight()
                if tab.page then tab.page:Hide() end
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

    local tab2 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab2:SetText("Settings")
    tab2:SetHeight(20)
    tab2:SetWidth(tab2:GetTextWidth() + 24)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 6, 0)
    tab2.page = settingsPage
    tab2:SetScript("OnClick", function() SetActivePage(2) end)

    tabButtons[1] = tab1
    tabButtons[2] = tab2

    SetActivePage(1)

    -- Placeholder Settings page content
    local settingsLabel = settingsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsLabel:SetPoint("TOPLEFT", 8, -8)
    settingsLabel:SetText("Persona Engine Settings (coming soon)")
    StyleText(settingsLabel, "HEADER")

    ------------------------------------------------
    -- ACTION PAGE CONTENT
    ------------------------------------------------

    ------------------------------------------------
    -- Macro name row (top-most)
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
    macroNameEdit:SetPoint("RIGHT", actionPage,     "RIGHT", -8, 0)
    configFrame.macroNameEdit = macroNameEdit

    ------------------------------------------------
    -- Spell / action selector row
    ------------------------------------------------
    local spellLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", macroNameLabel, "BOTTOMLEFT", 0, -18)
    spellLabel:SetText("Action name or ID:")
    StyleText(spellLabel, "LABEL")

    local spellEdit = CreateFrame("EditBox", nil, actionPage, "InputBoxTemplate")
    spellEdit:SetAutoFocus(false)
    spellEdit:SetHeight(20)
    configFrame.spellEdit = spellEdit

    local loadButton = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    loadButton:SetSize(70, 22)
    loadButton:SetPoint("TOPRIGHT", actionPage, "TOPRIGHT", -4, -2)
    loadButton:SetText("Load")

    -- Between label and Load
    spellEdit:ClearAllPoints()
    spellEdit:SetPoint("LEFT",  spellLabel, "RIGHT", 8, 0)
    spellEdit:SetPoint("RIGHT", loadButton, "LEFT", -26, 0)

    local spellIcon = actionPage:CreateTexture(nil, "OVERLAY")
    spellIcon:SetSize(24, 24)
    spellIcon:SetPoint("LEFT", spellEdit, "RIGHT", 4, 0)

    -- Info icon for "How do I load stuff?"
    local spellHelp = CreateFrame("Button", nil, actionPage)
    spellHelp:SetSize(16, 16)
    spellHelp:SetPoint("RIGHT", loadButton, "LEFT", -4, 0)

    local helpTex = spellHelp:CreateTexture(nil, "OVERLAY")
    helpTex:SetAllPoints()
    helpTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    spellHelp:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Loading an action", 1, 1, 1, true)
        GameTooltip:AddLine("\226\128\162 Type a spell, item, or emote name or ID.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("\226\128\162 Or Shift+Left-click it from your spellbook, action bar, or bags.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("\226\128\162 Then click |cffffff00Load|r to pull it into the Macro Studio.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    spellHelp:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local spellInfoText = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellInfoText:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    spellInfoText:SetWidth(420)
    spellInfoText:SetJustifyH("LEFT")
    StyleText(spellInfoText, "HINT")

    local currentAction -- { kind, id, name, icon }

    local function LoadActionByInput()
        if not PE.GetOrCreateActionConfig then
            spellInfoText:SetText("|cffff2020Action config system not ready.|r")
            return
        end

        local txt = spellEdit:GetText()
        if not txt or txt == "" then
            spellInfoText:SetText("|cffff2020No action provided.|r")
            spellIcon:SetTexture(nil)
            currentAction = nil
            return
        end

        local action = GetActionByInput(txt)
        if not action then
            spellInfoText:SetText("|cffff2020Unknown spell/item/emote.|r")
            spellIcon:SetTexture(nil)
            currentAction = nil
            return
        end

        currentAction = action
        spellIcon:SetTexture(action.icon or nil)

        local summary = PE.FormatActionSummary and PE.FormatActionSummary(action)
            or string.format(
                "Configuring |cffffff00%s|r (%s:%s)",
                tostring(action.name or "?"),
                tostring(action.kind or "?"),
                tostring(action.id   or "?")
            )

        spellInfoText:SetText(summary)

        -- Pull config from DB
        local cfg = PE.GetOrCreateActionConfig(action.kind, action.id)

        -- Trigger dropdown
        local triggerModes = PE.TRIGGER_MODES or {
            ON_PRESS      = "On Button Press",
            ON_CAST       = "On Cast",
            ON_CD         = "When Cooldown Starts",
            ON_READY      = "When Cooldown Ready",
            ON_BUFF_ACTIVE= "While Buff Is Active",
            ON_NOT_GCD    = "When GCD Is Free",
        }

        UIDropDownMenu_SetSelectedValue(configFrame.triggerDrop, cfg.trigger)
        UIDropDownMenu_SetText(
            configFrame.triggerDrop,
            triggerModes[cfg.trigger] or triggerModes.ON_CAST or "On Cast"
        )

        -- Chance
        configFrame.chanceEdit:SetNumber(cfg.chance or 10)

        -- Channels
        local chanCfg = cfg.channels or {}
        configFrame.channelCheckboxes.SAY  :SetChecked(chanCfg.SAY)
        configFrame.channelCheckboxes.YELL :SetChecked(chanCfg.YELL)
        configFrame.channelCheckboxes.EMOTE:SetChecked(chanCfg.EMOTE)
        configFrame.channelCheckboxes.PARTY:SetChecked(chanCfg.PARTY)
        configFrame.channelCheckboxes.RAID :SetChecked(chanCfg.RAID)

        -- Enabled
        configFrame.enabledCheck:SetChecked(cfg.enabled ~= false)

        -- Phrases
        local buf = ""
        if cfg.phrases then
            for i, line in ipairs(cfg.phrases) do
                buf = buf .. line
                if i < #cfg.phrases then
                    buf = buf .. "\n"
                end
            end
        end
        configFrame.phraseEdit:SetText(buf)

        -- Macro snippet, using PE.Say (delegated to MacroStudio)
        if configFrame.macroEdit and PE.MacroStudio and PE.MacroStudio.BuildDefaultMacroForAction then
            local macroText = PE.MacroStudio.BuildDefaultMacroForAction(action)
            if macroText and macroText ~= "" then
                configFrame.macroEdit:SetText(macroText)
            end
        end
    end

    loadButton:SetScript("OnClick", LoadActionByInput)

    ------------------------------------------------
    -- Trigger dropdown
    ------------------------------------------------
    local triggerLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", spellInfoText, "BOTTOMLEFT", 0, -12)
    triggerLabel:SetText("When should Copporclang speak?")
    StyleText(triggerLabel, "LABEL")

    local triggerDrop = CreateFrame("Frame", "PersonaEngineTriggerDrop", actionPage, "UIDropDownMenuTemplate")
    triggerDrop:SetPoint("LEFT", triggerLabel, "RIGHT", -10, -4)

    -- Small "?" help button explaining trigger modes
    local triggerHelp = CreateFrame("Button", nil, actionPage)
    triggerHelp:SetSize(16, 16)
    triggerHelp:SetPoint("LEFT", triggerDrop, "RIGHT", 4, 3)

    local tex = triggerHelp:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    triggerHelp:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Trigger modes", 1, 1, 1, true)

        GameTooltip:AddLine("On Button Press:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Eligible every time the macro runs.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Ignores cooldown and resource checks.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Still respects chance and rate limiting.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)

        GameTooltip:AddLine("On Cast:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Only eligible if the spell would actually cast now.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Not on cooldown, and usable (resources, range, etc.).", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)

        GameTooltip:AddLine("When Cooldown Starts:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Fires once when the action goes from ready \226\134\146 on cooldown.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Good for “rocket boosters online!” lines.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)

        GameTooltip:AddLine("When Cooldown Ready:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Fires once when the action goes from on cooldown \226\134\146 ready.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Great for “Dash is back, captain.” reminders.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)

        GameTooltip:AddLine("While Buff Is Active:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Eligible only while this spell's buff is on you or your pet.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Great for “while Bestial Wrath is up” commentary.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)

        GameTooltip:AddLine("When GCD Is Free:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" \226\128\162 Eligible only when the global cooldown is currently free.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" \226\128\162 Helps avoid double chatter while you spam on cooldown.", 0.8, 0.8, 0.8, true)

        GameTooltip:Show()
    end)
    triggerHelp:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local function TriggerDrop_OnClick(self)
        UIDropDownMenu_SetSelectedValue(triggerDrop, self.value)
    end

    UIDropDownMenu_Initialize(triggerDrop, function(self, level)
        local triggerModes = PE.TRIGGER_MODES or {
            ON_PRESS = "On Button Press",
            ON_CAST  = "On Cast",
            ON_READY = "When Cooldown Ready",
            ON_CD    = "When Cooldown Starts",
        }

        local info = UIDropDownMenu_CreateInfo()
        for key, label in pairs(triggerModes) do
            info.text    = label
            info.value   = key
            info.func    = TriggerDrop_OnClick
            info.checked = (UIDropDownMenu_GetSelectedValue(self) == key)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(triggerDrop, 190)
    UIDropDownMenu_SetSelectedValue(triggerDrop, "ON_CAST")
    UIDropDownMenu_SetText(
        triggerDrop,
        (PE.TRIGGER_MODES and PE.TRIGGER_MODES["ON_CAST"]) or "On Cast"
    )

    configFrame.triggerDrop = triggerDrop

    ------------------------------------------------
    -- Chance + enabled
    ------------------------------------------------
    local chanceLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanceLabel:SetPoint("TOPLEFT", triggerLabel, "BOTTOMLEFT", 0, -14)
    chanceLabel:SetText("Chance (1 in N):")
    StyleText(chanceLabel, "LABEL")

    local chanceEdit = CreateFrame("EditBox", nil, actionPage, "InputBoxTemplate")
    chanceEdit:SetSize(60, 20)
    chanceEdit:SetPoint("LEFT", chanceLabel, "RIGHT", 10, 0)
    chanceEdit:SetAutoFocus(false)
    chanceEdit:SetNumeric(true)
    chanceEdit:SetNumber(5)
    configFrame.chanceEdit = chanceEdit

    local enabledCheck
    if UI and UI.CreateCheckbox then
        enabledCheck = UI.CreateCheckbox(actionPage, {
            label  = "Enabled",
            point  = { "LEFT", chanceEdit, "RIGHT", 20, 0 },
            checked= true,
        })
    else
        enabledCheck = CreateFrame("CheckButton", nil, actionPage, "InterfaceOptionsCheckButtonTemplate")
        enabledCheck:SetPoint("LEFT", chanceEdit, "RIGHT", 20, 0)
        enabledCheck.Text:SetText("Enabled")
        enabledCheck:SetChecked(true)
    end
    configFrame.enabledCheck = enabledCheck
    if enabledCheck.Text then
        StyleText(enabledCheck.Text, "LABEL")
    end

    ------------------------------------------------
    -- Channels
    ------------------------------------------------
    local chanLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanLabel:SetPoint("TOPLEFT", chanceLabel, "BOTTOMLEFT", 0, -14)
    chanLabel:SetText("Channels:")
    StyleText(chanLabel, "LABEL")

    local chans = { "SAY", "YELL", "EMOTE", "PARTY", "RAID" }
    local chanChecks = {}
    local lastInRow
    local row2Anchor

    for i, chan in ipairs(chans) do
        local cb
        if UI and UI.CreateCheckbox then
            cb = UI.CreateCheckbox(actionPage, { label = chan })
        else
            cb = CreateFrame("CheckButton", nil, actionPage, "InterfaceOptionsCheckButtonTemplate")
            cb.Text:SetText(chan)
            StyleText(cb.Text, "LABEL")
        end

        if i == 1 then
            cb:SetPoint("LEFT", chanLabel, "RIGHT", 10, 0)
        elseif i <= 3 then
            cb:SetPoint("LEFT", lastInRow, "RIGHT", 70, 0)
        elseif i == 4 then
            cb:SetPoint("TOPLEFT", chanLabel, "BOTTOMLEFT", 10, -6)
            row2Anchor = cb
        else
            cb:SetPoint("LEFT", row2Anchor, "RIGHT", 70, 0)
        end

        cb:SetChecked(chan == "SAY")
        chanChecks[chan] = cb
        lastInRow = cb
    end

    configFrame.channelCheckboxes = chanChecks

    ------------------------------------------------
    -- Phrase editor: shared multiline widget
    ------------------------------------------------
    local phraseLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phraseLabel:SetPoint("TOPLEFT", chanLabel, "BOTTOMLEFT", 0, -36)
    phraseLabel:SetText("Phrases (one per line):")
    StyleText(phraseLabel, "LABEL")

    local phraseScroll, phraseEdit
    if UI and UI.CreateMultilineEdit then
        local PHRASE_BOTTOM_OFFSET = 180 -- try 160 / 180 / 200 to taste

        phraseScroll, phraseEdit = UI.CreateMultilineEdit(actionPage, {
            name        = "PersonaEnginePhraseScroll",
            point       = { "TOPLEFT",     phraseLabel, "BOTTOMLEFT", -4, -6 },
            point2      = { "BOTTOMRIGHT", actionPage,  "BOTTOMRIGHT", -10, PHRASE_BOTTOM_OFFSET },
            fontObject  = ChatFontNormal,
            textScale   = GLOBAL_FONT_SCALE,
            padding     = 20,
            minHeight   = 200,
            extraHeight = 600,
            backdrop    = true,
            outerBottomPad = 12, -- spacing between Phrase and Macro
        })
    else
        -- Fallback: basically original implementation
        phraseScroll = CreateFrame("ScrollFrame", "PersonaEnginePhraseScroll", actionPage, "UIPanelScrollFrameTemplate,BackdropTemplate")
        phraseScroll:SetPoint("TOPLEFT", phraseLabel, "BOTTOMLEFT", -4, -6)
        phraseScroll:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -10, 130)

        phraseEdit = CreateFrame("EditBox", nil, phraseScroll)
        phraseEdit:SetMultiLine(true)
        phraseEdit:SetAutoFocus(false)
        phraseEdit:SetFontObject(ChatFontNormal)
        phraseEdit:SetJustifyH("LEFT")
        phraseEdit:SetJustifyV("TOP")
        phraseScroll:SetScrollChild(phraseEdit)

        local function SizePhraseEdit()
            local w = math.max(0, phraseScroll:GetWidth() - 20)
            phraseEdit:SetWidth(w)
            phraseEdit:SetHeight(800)
            phraseScroll:UpdateScrollChildRect()
        end

        phraseScroll:SetScript("OnSizeChanged", SizePhraseEdit)
        phraseEdit:SetScript("OnTextChanged", function()
            phraseScroll:UpdateScrollChildRect()
        end)

        SizePhraseEdit()
    end

    StyleText(phraseEdit, "EMPHASIS", { scale = GLOBAL_FONT_SCALE })
    configFrame.phraseEdit  = phraseEdit
    configFrame.phraseScroll= phraseScroll

    ------------------------------------------------
    -- Macro snippet: shared multiline widget near bottom
    ------------------------------------------------
    local MAX_MACRO_CHARS = 255

    local macroScroll, macroEdit
    if UI and UI.CreateMultilineEdit then
        local PHRASE_MACRO_GAP = -14

        macroScroll, macroEdit = UI.CreateMultilineEdit(actionPage, {
            point       = { "TOPLEFT",     configFrame.phraseScroll, "BOTTOMLEFT", 0, PHRASE_MACRO_GAP },
            point2      = { "BOTTOMRIGHT", actionPage,               "BOTTOMRIGHT", -10, 40 },
            fontObject  = ChatFontNormal,
            textScale   = GLOBAL_FONT_SCALE,
            padding     = 20,
            minHeight   = 60,
            extraHeight = 140,
            backdrop    = true,
            onFocusHighlight = true,
        })
    else
        macroScroll = CreateFrame("ScrollFrame", nil, actionPage, "UIPanelScrollFrameTemplate,BackdropTemplate")
        macroScroll:SetPoint("BOTTOMLEFT",  actionPage, "BOTTOMLEFT",  4, 40)
        macroScroll:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -10, 40)
        macroScroll:SetHeight(60)

        macroEdit = CreateFrame("EditBox", nil, macroScroll)
        macroEdit:SetMultiLine(true)
        macroEdit:SetAutoFocus(false)
        macroEdit:SetFontObject(ChatFontNormal)
        macroEdit:SetJustifyH("LEFT")
        macroEdit:SetJustifyV("TOP")
        macroScroll:SetScrollChild(macroEdit)

        local function SizeMacroEdit()
            local w = math.max(0, macroScroll:GetWidth() - 20)
            macroEdit:SetWidth(w)
            macroEdit:SetHeight(200)
            macroScroll:UpdateScrollChildRect()
        end

        macroScroll:SetScript("OnSizeChanged", SizeMacroEdit)
        macroEdit:SetScript("OnTextChanged", function()
            macroScroll:UpdateScrollChildRect()
        end)
        macroEdit:SetScript("OnEditFocusGained", function(self)
            self:HighlightText(0, #self:GetText())
        end)
        macroEdit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        SizeMacroEdit()
    end

    local macroLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroLabel:SetPoint("BOTTOMLEFT", macroScroll, "TOPLEFT", 4, 2)
    macroLabel:SetText("Macro snippet:")
    StyleText(macroLabel, "LABEL")

    StyleText(macroEdit, "EMPHASIS", { scale = GLOBAL_FONT_SCALE })
    configFrame.macroEdit = macroEdit

    -- Character counter: "0/255"
    local macroCountLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    macroCountLabel:SetPoint("LEFT", macroLabel, "RIGHT", 8, 0)
    macroCountLabel:SetText(string.format("0/%d", MAX_MACRO_CHARS))
    StyleText(macroCountLabel, "HINT")
    configFrame.macroCountLabel = macroCountLabel

    -- Enforce max length + live counter
    macroEdit:HookScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local len  = (strlenutf8 and strlenutf8(text)) or #text

        if len > MAX_MACRO_CHARS then
            -- Trim down to max. For safety with UTF-8, shrink until in range.
            -- (Most macro text will be ASCII, but this protects against multibyte.)
            local trimmed = text
            while len > MAX_MACRO_CHARS and trimmed ~= "" do
                trimmed = trimmed:sub(1, -2)
                len     = (strlenutf8 and strlenutf8(trimmed)) or #trimmed
            end
            self:SetText(trimmed)
            self:SetCursorPosition(len or MAX_MACRO_CHARS)
        end

        if macroCountLabel then
            macroCountLabel:SetFormattedText("%d/%d", len, MAX_MACRO_CHARS)
        end
    end)

    ------------------------------------------------
    -- Macro studio buttons (bottom-right)
    ------------------------------------------------
    local saveMacroBtn = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    saveMacroBtn:SetSize(120, 22)
    saveMacroBtn:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -4, 8)
    saveMacroBtn:SetText("Save as Macro")

    local pickupMacroBtn = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    pickupMacroBtn:SetSize(90, 22)
    pickupMacroBtn:SetPoint("RIGHT", saveMacroBtn, "LEFT", -6, 0)
    pickupMacroBtn:SetText("Pick Up")

    local browseMacroBtn = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    browseMacroBtn:SetSize(90, 22)
    browseMacroBtn:SetPoint("RIGHT", pickupMacroBtn, "LEFT", -6, 0)
    browseMacroBtn:SetText("Browse...")

    ------------------------------------------------
    -- Macro browser popup (created once)
    ------------------------------------------------
    if UI and UI.CreateMacroBrowser then
        configFrame.macroBrowser = UI.CreateMacroBrowser({
            parent       = configFrame,
            title        = "PersonaEngine \226\128\147 Macro Picker",
            onMacroClick = function(name, body, icon)
                if macroNameEdit then macroNameEdit:SetText(name or "") end
                if macroEdit     then macroEdit:SetText(body or "")    end
            end,
        })
    end

    ------------------------------------------------
    -- Button scripts
    ------------------------------------------------
    saveMacroBtn:SetScript("OnClick", function()
        if not (PE and PE.MacroStudio and configFrame.macroEdit) then return end

        local macroName = macroNameEdit and macroNameEdit:GetText() or ""
        local body      = configFrame.macroEdit:GetText() or ""
        local icon      = currentAction and currentAction.icon or nil

        PE.MacroStudio.SaveMacro(macroName, body, icon)
    end)

    pickupMacroBtn:SetScript("OnClick", function()
        if not (PE and PE.MacroStudio and configFrame.macroEdit) then return end

        local macroName = macroNameEdit and macroNameEdit:GetText() or ""
        if macroName == "" then return end

        -- Auto-save current macro body before pickup
        local body = configFrame.macroEdit:GetText() or ""
        local icon = currentAction and currentAction.icon or nil

        if body ~= "" then
            PE.MacroStudio.SaveMacro(macroName, body, icon)
        end

        PE.MacroStudio.PickupMacroByName(macroName)
    end)

    browseMacroBtn:SetScript("OnClick", function()
        local browser = configFrame.macroBrowser
        if browser and browser.Refresh then
            browser:Refresh()
            browser:Show()
        end
    end)

    --------------------------------------------------
    -- Save button (bottom-left) - saves config + macro
    --------------------------------------------------
    local function SaveCurrentConfig()
        if not currentAction then
            spellInfoText:SetText("|cffff2020Pick a valid action first.|r")
            return
        end
        if not PE.GetOrCreateActionConfig then
            spellInfoText:SetText("|cffff2020Action config system not ready.|r")
            return
        end

        local cfg = PE.GetOrCreateActionConfig(currentAction.kind, currentAction.id)
        if not cfg then
            spellInfoText:SetText("|cffff2020Failed to get config for action.|r")
            return
        end

        -- Trigger
        cfg.trigger = UIDropDownMenu_GetSelectedValue(configFrame.triggerDrop) or "ON_CAST"

        -- Chance
        local n = configFrame.chanceEdit:GetNumber()
        if n <= 0 then n = 1 end
        cfg.chance = n

        -- Enabled
        cfg.enabled = configFrame.enabledCheck:GetChecked() and true or false

        -- Channels
        cfg.channels = {}
        for chan, cb in pairs(configFrame.channelCheckboxes) do
            if cb:GetChecked() then
                cfg.channels[chan] = true
            end
        end
        if not next(cfg.channels) then
            cfg.channels.SAY = true
        end

        -- Phrases
        cfg.phrases = {}
        local txt = configFrame.phraseEdit:GetText() or ""
        for line in string.gmatch(txt, "[^\r\n]+") do
            line = strtrim(line)
            if line ~= "" then
                table.insert(cfg.phrases, line)
            end
        end
        if #cfg.phrases == 0 then
            cfg.phrases = { "\226\128\166internal monologue buffer overflow\226\128\166" }
        end

        -- Macro save: keep Macro Studio as the source of truth
        if PE.MacroStudio and configFrame.macroEdit and configFrame.macroNameEdit then
            local macroName = configFrame.macroNameEdit:GetText() or ""
            local body      = configFrame.macroEdit:GetText() or ""
            if macroName ~= "" and body ~= "" then
                local icon = currentAction and currentAction.icon or nil
                PE.MacroStudio.SaveMacro(macroName, body, icon)
            end
        end

        -- Visual confirmation
        spellInfoText:SetText((spellInfoText:GetText() or "") .. " |cff20ff20Saved.|r")
    end

    local saveButton = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    saveButton:SetSize(120, 24)
    saveButton:SetPoint("BOTTOMLEFT", actionPage, "BOTTOMLEFT", 4, 4)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", SaveCurrentConfig)
    configFrame.saveButton = saveButton
end

----------------------------------------------------
-- Public toggle API
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
-- ChatEdit_InsertLink hook (spell link → spell box)
----------------------------------------------------
do
    if ChatEdit_InsertLink then
        if not PE._OrigChatEdit_InsertLink then
            PE._OrigChatEdit_InsertLink = ChatEdit_InsertLink
        end

        local Orig_ChatEdit_InsertLink = PE._OrigChatEdit_InsertLink

        ChatEdit_InsertLink = function(text)
            -- Let the default handler try first
            if Orig_ChatEdit_InsertLink(text) then
                return true
            end

            -- If our config is open and spell box focused, capture spell links
            if configFrame
                and configFrame:IsShown()
                and configFrame.spellEdit
                and configFrame.spellEdit:HasFocus()
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
    else
        if PE.Log then
            PE.Log(2, "ChatEdit_InsertLink not available; spell link capture disabled.")
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
