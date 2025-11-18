-- ##################################################
-- PE_ConfigUI.lua
-- Persona Engine spell-bubble configuration UI
-- ##################################################

local MODULE = "ConfigUI"
local PE = PE
local UI = PE and PE.UI  -- widget collection (UIWindow, UILabeledEdit, etc.)

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Layout constants
----------------------------------------------------

-- These are mostly for the phrase area; window size is now driven by UI.CreateWindow
local PHRASE_SCROLL_WIDTH  = 400
local PHRASE_SCROLL_HEIGHT = 200

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
    -- Main window (via UI widget)
    ------------------------------------------------

    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id        = "Config",  -- logical ID for persistence
            title     = "Persona Engine – Artificer Config",
            width     = 700,
            height    = 750,
            minWidth  = 520,
            minHeight = 430,
            strata    = "DIALOG",
            level     = 100,
            -- point  = { "CENTER", UIParent, "CENTER", 0, 0 },
        })
    else
        -- Fallback: old-style frame if UI widgets somehow missing
        configFrame = CreateFrame("Frame", "PersonaEngineConfigFrame", UIParent, "BasicFrameTemplateWithInset")
        configFrame:SetSize(700, 750)
        configFrame:SetPoint("CENTER")
        configFrame:SetMovable(true)
        configFrame:EnableMouse(true)
        configFrame:RegisterForDrag("LeftButton")
        configFrame:SetScript("OnDragStart", configFrame.StartMoving)
        configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
        configFrame:SetFrameStrata("DIALOG")
        configFrame:SetFrameLevel(100)

        local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if configFrame.TitleBg then
            title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
        else
            title:SetPoint("TOPLEFT", 10, -5)
        end
        title:SetText("Persona Engine – Artificer Config")
        configFrame.title = title

        configFrame:Hide()
    end

    -- Backwards-compat alias for any external code that still expects this name
    if not _G["PersonaEngineConfigFrame"] then
        _G["PersonaEngineConfigFrame"] = configFrame
    end

    ------------------------------------------------
    -- Spell selector
    ------------------------------------------------

    local spellLabel, spellEdit
    if UI and UI.CreateLabeledEdit then
        spellLabel, spellEdit = UI.CreateLabeledEdit(configFrame, {
            label = "Spell name or ID:",
            width = 200,
            point = { "TOPLEFT", configFrame, "TOPLEFT", 16, -40 },
        })
    else
        spellLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spellLabel:SetPoint("TOPLEFT", 16, -40)
        spellLabel:SetText("Spell name or ID:")

        spellEdit = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
        spellEdit:SetSize(200, 20)
        spellEdit:SetPoint("LEFT", spellLabel, "RIGHT", 10, 0)
        spellEdit:SetAutoFocus(false)
    end

    configFrame.spellEdit = spellEdit

    local spellIcon = configFrame:CreateTexture(nil, "OVERLAY")
    spellIcon:SetSize(24, 24)
    spellIcon:SetPoint("LEFT", spellEdit, "RIGHT", 8, 0)

    local spellInfoText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellInfoText:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    spellInfoText:SetWidth(420)
    spellInfoText:SetJustifyH("LEFT")

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
                name,
                spellID,
                name
            )
            configFrame.macroEdit:SetText(macroText)
        end
    end

    local loadButton
    if UI and UI.CreateButton then
        loadButton = UI.CreateButton(configFrame, {
            text  = "Load",
            size  = { 70, 22 },
            point = { "LEFT", spellInfoText, "RIGHT", -70, 0 },
            onClick = LoadSpellByInput,
        })
    else
        loadButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
        loadButton:SetSize(70, 22)
        loadButton:SetPoint("LEFT", spellInfoText, "RIGHT", -70, 0)
        loadButton:SetText("Load")
        loadButton:SetScript("OnClick", LoadSpellByInput)
    end

    ------------------------------------------------
    -- Trigger dropdown
    ------------------------------------------------

    local triggerLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", spellInfoText, "BOTTOMLEFT", 0, -12)
    triggerLabel:SetText("When should Copporclang speak?")

    local triggerDrop = CreateFrame("Frame", "PersonaEngineTriggerDrop", configFrame, "UIDropDownMenuTemplate")
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

    local chanceLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanceLabel:SetPoint("TOPLEFT", triggerLabel, "BOTTOMLEFT", 0, -14)
    chanceLabel:SetText("Chance (1 in N):")

    local chanceEdit = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
    chanceEdit:SetSize(60, 20)
    chanceEdit:SetPoint("LEFT", chanceLabel, "RIGHT", 10, 0)
    chanceEdit:SetAutoFocus(false)
    chanceEdit:SetNumeric(true)
    chanceEdit:SetNumber(5)
    configFrame.chanceEdit = chanceEdit

    local enabledCheck
    if UI and UI.CreateCheckbox then
        enabledCheck = UI.CreateCheckbox(configFrame, {
            label   = "Enabled",
            point   = { "LEFT", chanceEdit, "RIGHT", 20, 0 },
            checked = true,
        })
    else
        enabledCheck = CreateFrame("CheckButton", nil, configFrame, "InterfaceOptionsCheckButtonTemplate")
        enabledCheck:SetPoint("LEFT", chanceEdit, "RIGHT", 20, 0)
        enabledCheck.Text:SetText("Enabled")
        enabledCheck:SetChecked(true)
    end
    configFrame.enabledCheck = enabledCheck

    ------------------------------------------------
    -- Channels
    ------------------------------------------------

    local chanLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanLabel:SetPoint("TOPLEFT", chanceLabel, "BOTTOMLEFT", 0, -14)
    chanLabel:SetText("Channels:")

    local chans = { "SAY", "YELL", "EMOTE", "PARTY", "RAID" }
    local chanChecks = {}
    local lastInRow
    local row2Anchor

    for i, chan in ipairs(chans) do
        local cb
        if UI and UI.CreateCheckbox then
            -- We still do custom layout, but use the widget constructor
            cb = UI.CreateCheckbox(configFrame, {
                label = chan,
                -- point filled in below
            })
        else
            cb = CreateFrame("CheckButton", nil, configFrame, "InterfaceOptionsCheckButtonTemplate")
            cb.Text:SetText(chan)
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
    -- Phrase editor
    ------------------------------------------------

    local phraseLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phraseLabel:SetPoint("TOPLEFT", chanLabel, "BOTTOMLEFT", 0, -36)
    phraseLabel:SetText("Phrases (one per line):")

    local scrollFrame, phraseEdit
    if UI and UI.CreateMultilineEdit then
        scrollFrame, phraseEdit = UI.CreateMultilineEdit(configFrame, {
            size  = { PHRASE_SCROLL_WIDTH, PHRASE_SCROLL_HEIGHT },
            point = { "TOPLEFT", phraseLabel, "BOTTOMLEFT", 0, -4 },
        })
    else
        scrollFrame = CreateFrame("ScrollFrame", "PersonaEnginePhraseScroll", configFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", phraseLabel, "BOTTOMLEFT", 0, -4)
        scrollFrame:SetSize(PHRASE_SCROLL_WIDTH, PHRASE_SCROLL_HEIGHT)

        phraseEdit = CreateFrame("EditBox", nil, scrollFrame)
        phraseEdit:SetMultiLine(true)
        phraseEdit:SetAutoFocus(false)
        phraseEdit:SetFontObject(ChatFontNormal)
        phraseEdit:SetWidth(PHRASE_SCROLL_WIDTH - 20)
        phraseEdit:SetHeight(PHRASE_SCROLL_HEIGHT)

        scrollFrame:SetScrollChild(phraseEdit)
    end

    configFrame.phraseEdit   = phraseEdit
    configFrame.phraseScroll = scrollFrame

    ------------------------------------------------
    -- Save button
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
        if n <= 0 then
            n = 1
        end
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

    local saveButton
    if UI and UI.CreateButton then
        saveButton = UI.CreateButton(configFrame, {
            text  = "Save Config",
            size  = { 120, 24 },
            point = { "BOTTOMLEFT", configFrame, "BOTTOMLEFT", 16, 16 },
            onClick = SaveCurrentConfig,
        })
    else
        saveButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
        saveButton:SetSize(120, 24)
        saveButton:SetPoint("BOTTOMLEFT", 16, 16)
        saveButton:SetText("Save Config")
        saveButton:SetScript("OnClick", SaveCurrentConfig)
    end

    configFrame.saveButton = saveButton

    ------------------------------------------------
    -- Macro snippet (for bubble macros)
    ------------------------------------------------

    local macroLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroLabel:SetPoint("BOTTOMLEFT", saveButton, "TOPLEFT", 0, 6)
    macroLabel:SetText("Macro snippet:")

    local macroEdit = CreateFrame("EditBox", nil, configFrame, "InputBoxTemplate")
    macroEdit:SetMultiLine(true)
    macroEdit:SetAutoFocus(false)
    macroEdit:SetFontObject(ChatFontNormal)
    macroEdit:SetSize(220, 40)
    macroEdit:SetPoint("LEFT", macroLabel, "RIGHT", 10, 0)
    macroEdit:SetJustifyH("LEFT")
    macroEdit:SetJustifyV("TOP")

    macroEdit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText(0, #self:GetText())
    end)

    macroEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    configFrame.macroEdit = macroEdit

    ------------------------------------------------
    -- Hint
    ------------------------------------------------

    local hint = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", -16, 16)
    hint:SetJustifyH("RIGHT")
    hint:SetWidth(280)
    hint:SetText(
        "Type a spell name or ID and click |cffffff00Load|r.\n" ..
        "Use the macro snippet to add Copporclang's quips to your own macros."
    )
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
