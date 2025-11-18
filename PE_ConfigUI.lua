-- ##################################################
-- PE_ConfigUI.lua
-- Persona Engine spell-bubble configuration UI
-- ##################################################

local MODULE = "ConfigUI"
local PE     = PE
local UI     = PE and PE.UI  -- shorthand for widgets

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
local GLOBAL_FONT_SCALE = 1.0   -- e.g. 0.9, 1.0, 1.1

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
-- Spell lookup wrapper
----------------------------------------------------

local function GetSpellInfoByInput(input)
    if not input or input == "" then
        return
    end

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

----------------------------------------------------
-- Config frame construction
----------------------------------------------------

local configFrame

local function BuildConfigFrame()
    if configFrame then
        return
    end

    ------------------------------------------------
    -- Main window via UI widget (persistent + resizable)
    ------------------------------------------------

    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id       = "Config",
            title    = "Persona Engine – Artificer Config",
            width    = 700,
            height   = 750,
            minWidth = 520,
            minHeight = 430,
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
        configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)

        local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if configFrame.TitleBg then
            title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
        else
            title:SetPoint("TOPLEFT", 10, -5)
        end
        title:SetText("Persona Engine – Artificer Config")
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
    actionPage:SetPoint("TOPLEFT",     configFrame, "TOPLEFT", 8,  -60)
    actionPage:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -8, 8)

    local settingsPage = CreateFrame("Frame", nil, configFrame)
    settingsPage:SetPoint("TOPLEFT",     actionPage, "TOPLEFT", 0, 0)
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
    tab1:SetText("Action Phrases & Macros")
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
    -- Spell selector row
    ------------------------------------------------

    local spellLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", actionPage, "TOPLEFT", 8, -4)
    spellLabel:SetText("Spell name or ID:")
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
    spellEdit:SetPoint("RIGHT", loadButton, "LEFT", -32, 0)

    local spellIcon = actionPage:CreateTexture(nil, "OVERLAY")
    spellIcon:SetSize(24, 24)
    spellIcon:SetPoint("LEFT", spellEdit, "RIGHT", 4, 0)

    local spellInfoText = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellInfoText:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    spellInfoText:SetWidth(420)
    spellInfoText:SetJustifyH("LEFT")
    StyleText(spellInfoText, "HINT")

    local currentSpellID

    local function LoadSpellByInput()
        if not PE.GetOrCreateSpellConfig then
            spellInfoText:SetText("|cffff2020Spell config system not ready.|r")
            return
        end

        local txt = spellEdit:GetText()
        if not txt or txt == "" then
            spellInfoText:SetText("|cffff2020No spell provided.|r")
            spellIcon:SetTexture(nil)
            currentSpellID = nil
            return
        end

        local name, icon, spellID = GetSpellInfoByInput(txt)
        if not name then
            spellInfoText:SetText("|cffff2020Unknown spell.|r")
            spellIcon:SetTexture(nil)
            currentSpellID = nil
            return
        end

        currentSpellID = spellID
        spellIcon:SetTexture(icon)
        spellInfoText:SetText(string.format("Configuring |cffffff00%s|r (ID %d)", name, spellID))

        local cfg = PE.GetOrCreateSpellConfig(spellID)

        -- Trigger dropdown
        local triggerModes = PE.TRIGGER_MODES or {
            ON_CAST  = "On Cast",
            ON_READY = "When Cooldown Ready",
            ON_CD    = "When Cooldown Starts",
        }

        UIDropDownMenu_SetSelectedValue(configFrame.triggerDrop, cfg.trigger)
        UIDropDownMenu_SetText(
            configFrame.triggerDrop,
            triggerModes[cfg.trigger] or "On Cast"
        )

        -- Chance
        configFrame.chanceEdit:SetNumber(cfg.chance or 10)

        -- Channels
        local chanCfg = cfg.channels or {}
        configFrame.channelCheckboxes.SAY:SetChecked(   chanCfg.SAY   )
        configFrame.channelCheckboxes.YELL:SetChecked(  chanCfg.YELL  )
        configFrame.channelCheckboxes.EMOTE:SetChecked( chanCfg.EMOTE )
        configFrame.channelCheckboxes.PARTY:SetChecked( chanCfg.PARTY )
        configFrame.channelCheckboxes.RAID:SetChecked(  chanCfg.RAID  )

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

        -- Macro snippet
        if configFrame.macroEdit then
            local macroText = string.format(
                "#showtooltip %s\n/run PE.FireBubble(%d)\n/cast %s",
                name, spellID, name
            )
            configFrame.macroEdit:SetText(macroText)
        end
    end

    loadButton:SetScript("OnClick", LoadSpellByInput)

    ------------------------------------------------
    -- Trigger dropdown
    ------------------------------------------------

    local triggerLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", spellInfoText, "BOTTOMLEFT", 0, -12)
    triggerLabel:SetText("When should Copporclang speak?")
    StyleText(triggerLabel, "LABEL")

    local triggerDrop = CreateFrame("Frame", "PersonaEngineTriggerDrop", actionPage, "UIDropDownMenuTemplate")
    triggerDrop:SetPoint("LEFT", triggerLabel, "RIGHT", -10, -4)

    local function TriggerDrop_OnClick(self)
        UIDropDownMenu_SetSelectedValue(triggerDrop, self.value)
    end

    UIDropDownMenu_Initialize(triggerDrop, function(self, level)
        local triggerModes = PE.TRIGGER_MODES or {
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

    UIDropDownMenu_SetWidth(triggerDrop, 170)
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
            label = "Enabled",
            point = { "LEFT", chanceEdit, "RIGHT", 20, 0 },
            checked = true,
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

    local chans       = { "SAY", "YELL", "EMOTE", "PARTY", "RAID" }
    local chanChecks  = {}
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
        phraseScroll, phraseEdit = UI.CreateMultilineEdit(actionPage, {
            name        = "PersonaEnginePhraseScroll",
            point       = { "TOPLEFT",     phraseLabel, "BOTTOMLEFT", -4, -6 },
            point2      = { "BOTTOMRIGHT", actionPage,  "BOTTOMRIGHT", -10, 130 },
            fontObject  = ChatFontNormal,
            textScale   = GLOBAL_FONT_SCALE,
            padding     = 20,
            minHeight   = 200,
            extraHeight = 600,
            backdrop    = true,
        })
    else
        -- Fallback: basically your original implementation
        phraseScroll = CreateFrame(
            "ScrollFrame", "PersonaEnginePhraseScroll", actionPage,
            "UIPanelScrollFrameTemplate,BackdropTemplate"
        )
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
    configFrame.phraseEdit   = phraseEdit
    configFrame.phraseScroll = phraseScroll

    ------------------------------------------------
    -- Macro snippet: shared multiline widget near bottom
    ------------------------------------------------

    local macroScroll, macroEdit

    if UI and UI.CreateMultilineEdit then
        macroScroll, macroEdit = UI.CreateMultilineEdit(actionPage, {
            point       = { "BOTTOMLEFT",  actionPage, "BOTTOMLEFT", 4, 40 },
            point2      = { "BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -10, 40 },
            fontObject  = ChatFontNormal,
            textScale   = GLOBAL_FONT_SCALE,
            padding     = 20,
            minHeight   = 60,
            extraHeight = 140,
            backdrop    = true,
            onFocusHighlight = true,
        })
    else
        macroScroll = CreateFrame(
            "ScrollFrame", nil, actionPage,
            "UIPanelScrollFrameTemplate,BackdropTemplate"
        )
        macroScroll:SetPoint("BOTTOMLEFT",  actionPage, "BOTTOMLEFT", 4, 40)
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

    ------------------------------------------------
    -- Save button (bottom-left)
    ------------------------------------------------

    local function SaveCurrentConfig()
        if not currentSpellID then
            spellInfoText:SetText("|cffff2020Pick a valid spell first.|r")
            return
        end

        if not PE.GetOrCreateSpellConfig then
            spellInfoText:SetText("|cffff2020Spell config system not ready.|r")
            return
        end

        local cfg = PE.GetOrCreateSpellConfig(currentSpellID)
        if not cfg then
            spellInfoText:SetText("|cffff2020Failed to get config for spell.|r")
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
            cfg.phrases = { "…internal monologue buffer overflow…" }
        end

        -- Visual confirmation
        spellInfoText:SetText((spellInfoText:GetText() or "") .. " |cff20ff20Saved.|r")
    end

    local saveButton = CreateFrame("Button", nil, actionPage, "UIPanelButtonTemplate")
    saveButton:SetSize(120, 24)
    saveButton:SetPoint("BOTTOMLEFT", actionPage, "BOTTOMLEFT", 4, 4)
    saveButton:SetText("Save Config")
    saveButton:SetScript("OnClick", SaveCurrentConfig)
    configFrame.saveButton = saveButton

    ------------------------------------------------
    -- Hint (bottom-right)
    ------------------------------------------------

    local hint = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -4, 4)
    hint:SetJustifyH("RIGHT")
    hint:SetWidth(280)
    hint:SetText(
        "Type a spell name or ID and click |cffffff00Load|r.\n" ..
        "Use the macro snippet to add Copporclang's quips to your own macros."
    )
    StyleText(hint, "HINT")
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
            if configFrame and configFrame:IsShown()
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
