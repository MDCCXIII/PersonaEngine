-- ##################################################
-- UI/PE_UIMacroStudioTab.lua
-- Macro Studio tab contents for Persona Engine
-- ##################################################

local MODULE = "UIMacroStudioTab"
local PE     = PE

if not PE or type(PE) ~= "table" then
    return
end

PE.UI = PE.UI or {}
local UI = PE.UI

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Text styling (local to this tab)
----------------------------------------------------

local GLOBAL_FONT_SCALE = 1.0

local TEXT_STYLES = {
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
}

local function StyleText(widget, styleKey)
    if not widget or not styleKey then return end
    local style = TEXT_STYLES[styleKey]
    if not style then return end

    local template = style.template
    if template then
        widget:SetFontObject(template)
    end

    local font, size, flags = widget:GetFont()
    if font and size then
        widget:SetFont(font, size * (GLOBAL_FONT_SCALE or 1.0), flags)
    end

    local c = style.color
    if c then
        widget:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
end

----------------------------------------------------
-- Helpers
----------------------------------------------------

local function trim(s)
    if not s then return "" end
    return (s:match("^%s*(.-)%s*$"))
end

local function utf8len(s)
    if strlenutf8 then
        return strlenutf8(s or "")
    end
    return #(s or "")
end

local function GetActionByInput(input)
    if not input or input == "" then return nil end
    if not PE.ResolveActionFromInput then return nil end
    return PE.ResolveActionFromInput(input)
end

----------------------------------------------------
-- Trigger options
----------------------------------------------------

local TRIGGER_OPTIONS = {
    { value = "ON_CAST",     label = "On Cast" },
    { value = "ON_CD_START", label = "When ability goes on cooldown" },
}

local DEFAULT_TRIGGER = "ON_CAST"

local function FindTriggerLabel(value)
    for _, opt in ipairs(TRIGGER_OPTIONS) do
        if opt.value == value then
            return opt.label
        end
    end
    return "On Cast"
end

----------------------------------------------------
-- Main builder
----------------------------------------------------

-- UI.BuildMacroStudioTab(configFrame, pageFrame)
function UI.BuildMacroStudioTab(configFrame, page)
    page = page or configFrame

    local currentAction
    local currentTriggerValue = DEFAULT_TRIGGER

    ------------------------------------------------
    -- Macro name row
    ------------------------------------------------
    local macroNameLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroNameLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -4)
    macroNameLabel:SetText("Macro Name (Max 16 Characters):")
    StyleText(macroNameLabel, "LABEL")

    local macroNameEdit = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    macroNameEdit:SetAutoFocus(false)
    macroNameEdit:SetHeight(20)
    macroNameEdit:SetMaxLetters(16)
    macroNameEdit:SetPoint("LEFT",  macroNameLabel, "RIGHT", 8, 0)
    macroNameEdit:SetPoint("RIGHT", page, "RIGHT", -8, 0)

    configFrame.macroNameEdit = macroNameEdit

    ------------------------------------------------
    -- Icon / primary action row
    ------------------------------------------------
    local iconLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", macroNameLabel, "BOTTOMLEFT", 0, -18)
    iconLabel:SetText("Icon Name or ID:")
    StyleText(iconLabel, "LABEL")

    local loadButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    loadButton:SetSize(70, 22)
    loadButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -26)
    loadButton:SetText("Load")

    local iconHelp = CreateFrame("Button", nil, page)
    iconHelp:SetSize(16, 16)
    iconHelp:SetPoint("RIGHT", loadButton, "LEFT", -4, 0)
    local helpTex = iconHelp:CreateTexture(nil, "OVERLAY")
    helpTex:SetAllPoints()
    helpTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    local iconEdit = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    iconEdit:SetAutoFocus(false)
    iconEdit:SetHeight(20)
    iconEdit:SetPoint("LEFT",  iconLabel, "RIGHT", 8, 0)
    iconEdit:SetPoint("RIGHT", iconHelp,  "LEFT", -26, 0)

    local iconTexture = page:CreateTexture(nil, "OVERLAY")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("LEFT", iconEdit, "RIGHT", 4, 0)
    iconTexture:SetTexture(134400)

    local iconButton = CreateFrame("Button", nil, page)
    iconButton:SetSize(24, 24)
    iconButton:SetPoint("CENTER", iconTexture, "CENTER")
    iconButton:EnableMouse(true)

    configFrame.spellEdit          = iconEdit
    configFrame.iconTexture        = iconTexture
    configFrame.selectedIconTexture = 134400

    iconHelp:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Macro icon", 1, 1, 1, true)

		-- Icon-first behaviour
		GameTooltip:AddLine("• Type an icon texture name (e.g. |cffffff00inv_misc_bag_03|r) or a file ID.", 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("• Shift-click a spell or item to copy its ICON here.", 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("• Click |cffffff00Load|r to optionally pull trigger settings from that spell/item.", 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("• Click the icon to open the full icon selector.", 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("• Phrases are saved per |cffffff00macro name|r, not per spell.", 0.8, 0.8, 0.8, true)

		GameTooltip:Show()
	end)
	iconHelp:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)


    local iconInfoText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconInfoText:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -4)
    iconInfoText:SetWidth(420)
    iconInfoText:SetJustifyH("LEFT")
    StyleText(iconInfoText, "HINT")
    iconInfoText:SetText("|cffff2020No icon selected.|r")

    ------------------------------------------------
    -- Autocomplete + icon picker
    ------------------------------------------------
    if UI.AttachIconAutocomplete then
        UI.AttachIconAutocomplete(iconEdit, {
            parent = page,
            onIconChosen = function(data)
                configFrame.selectedIconTexture = data.texture or 134400
                iconTexture:SetTexture(configFrame.selectedIconTexture)
                iconEdit:SetText(data.name or "")
            end,
        })
    end

    local iconPicker
    if UI.CreateIconPicker then
        iconButton:SetScript("OnClick", function()
            if not iconPicker then
                iconPicker = UI.CreateIconPicker({
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
            iconPicker:Show()
        end)
    end

    ------------------------------------------------
    -- Trigger + chance + channels
    ------------------------------------------------
    local triggerLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", iconInfoText, "BOTTOMLEFT", 0, -18)
    triggerLabel:SetText("When should Copporclang speak?")
    StyleText(triggerLabel, "LABEL")

    local triggerDrop = CreateFrame("Frame", nil, page, "UIDropDownMenuTemplate")
    triggerDrop:SetPoint("LEFT", triggerLabel, "RIGHT", -10, -4)

    local triggerHelp = CreateFrame("Button", nil, page)
    triggerHelp:SetSize(16, 16)
    triggerHelp:SetPoint("LEFT", triggerDrop, "RIGHT", 4, 2)
    local triggerHelpTex = triggerHelp:CreateTexture(nil, "OVERLAY")
    triggerHelpTex:SetAllPoints()
    triggerHelpTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    triggerHelp:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("When to speak", 1, 1, 1, true)
        GameTooltip:AddLine("On Cast: roll when you fire the spell or use the item.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Cooldown Start: roll when the ability actually goes on cooldown.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    triggerHelp:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local function TriggerDrop_OnClick(selfBtn)
        currentTriggerValue = selfBtn.value or DEFAULT_TRIGGER
        UIDropDownMenu_SetSelectedValue(triggerDrop, currentTriggerValue)
        UIDropDownMenu_SetText(triggerDrop, selfBtn.arg1 or FindTriggerLabel(currentTriggerValue))
    end

    UIDropDownMenu_Initialize(triggerDrop, function(selfDD, level)
        for _, opt in ipairs(TRIGGER_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = opt.label
            info.value   = opt.value
            info.arg1    = opt.label
            info.func    = TriggerDrop_OnClick
            info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(triggerDrop, 180)
    UIDropDownMenu_SetSelectedValue(triggerDrop, DEFAULT_TRIGGER)
    UIDropDownMenu_SetText(triggerDrop, FindTriggerLabel(DEFAULT_TRIGGER))

    local chanceLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanceLabel:SetPoint("TOPLEFT", triggerLabel, "BOTTOMLEFT", 0, -16)
    chanceLabel:SetText("Chance (1 in N):")
    StyleText(chanceLabel, "LABEL")

    local chanceEdit = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    chanceEdit:SetAutoFocus(false)
    chanceEdit:SetNumeric(true)
    chanceEdit:SetMaxLetters(4)
    chanceEdit:SetSize(40, 20)
    chanceEdit:SetPoint("LEFT", chanceLabel, "RIGHT", 6, 0)
    chanceEdit:SetNumber(5)

    local enabledCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    enabledCheck:SetPoint("LEFT", chanceEdit, "RIGHT", 12, 0)
    enabledCheck.text:SetText("Enabled")
    StyleText(enabledCheck.text, "LABEL")
    enabledCheck:SetChecked(true)

    local channelsLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelsLabel:SetPoint("TOPLEFT", chanceLabel, "BOTTOMLEFT", 0, -14)
    channelsLabel:SetText("Channels:")
    StyleText(channelsLabel, "LABEL")

    local channelChecks = {}

    local function MakeChannelCheck(prev, text, token, xOffset)
		local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")

		if prev then
			local anchor = prev.text or prev
			cb:SetPoint("LEFT", anchor, "RIGHT", xOffset or 12, 0)
		else
			cb:SetPoint("LEFT", channelsLabel, "RIGHT", 8, 0)
		end

		cb.text:SetText(text)
		StyleText(cb.text, "LABEL")

		channelChecks[token] = cb
		return cb
	end


    local cbSAY   = MakeChannelCheck(nil,     "SAY",   "SAY")
	local cbYELL  = MakeChannelCheck(cbSAY,   "YELL",  "YELL")
	local cbEMOTE = MakeChannelCheck(cbYELL,  "EMOTE", "EMOTE")
	local cbPARTY = MakeChannelCheck(cbEMOTE, "PARTY", "PARTY")
	local cbRAID  = MakeChannelCheck(cbPARTY, "RAID",  "RAID")


    cbSAY:SetChecked(true)

    ------------------------------------------------
    -- Phrases multiline
    ------------------------------------------------
    local phrasesLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phrasesLabel:SetPoint("TOPLEFT", channelsLabel, "BOTTOMLEFT", 0, -18)
    phrasesLabel:SetText("Phrases (one per line):")
    StyleText(phrasesLabel, "LABEL")

    local phrasesBox, phrasesEdit
    if UI.CreateMultilineEdit then
        phrasesBox, phrasesEdit = UI.CreateMultilineEdit(page, {
            point  = { "TOPLEFT", phrasesLabel, "BOTTOMLEFT", 0, -4 },
            point2 = { "BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 160 },
            textScale = 1.0,
        })
    else
        phrasesBox = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        phrasesBox:SetPoint("TOPLEFT", phrasesLabel, "BOTTOMLEFT", 0, -4)
        phrasesBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 160)
        phrasesEdit = CreateFrame("EditBox", nil, phrasesBox)
        phrasesEdit:SetMultiLine(true)
        phrasesEdit:SetAutoFocus(false)
        phrasesEdit:SetFontObject(ChatFontNormal)
        phrasesEdit:SetWidth(phrasesBox:GetWidth())
        phrasesBox:SetScrollChild(phrasesEdit)
    end

       ------------------------------------------------
    -- Macro snippet + counter
    ------------------------------------------------
    -- Label sits under the phrases box, above the snippet editor
    local macroLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroLabel:SetPoint("TOPLEFT", phrasesBox, "BOTTOMLEFT", 0, -12)
    macroLabel:SetJustifyH("LEFT")
    StyleText(macroLabel, "LABEL")
    macroLabel:SetText("Macro snippet:")

    local macroBox, macroEdit
    if UI.CreateMultilineEdit then
        macroBox, macroEdit = UI.CreateMultilineEdit(page, {
            point  = { "TOPLEFT",  macroLabel, "BOTTOMLEFT", 0, -4 },
            -- leave 40px above the bottom for the buttons
            point2 = { "BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 40 },
            textScale = 1.0,
            minHeight = 40,
        })
    else
        macroBox = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        macroBox:SetPoint("TOPLEFT",  macroLabel, "BOTTOMLEFT", 0, -4)
        macroBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 40)

        macroEdit = CreateFrame("EditBox", nil, macroBox)
        macroEdit:SetMultiLine(true)
        macroEdit:SetAutoFocus(false)
        macroEdit:SetFontObject(ChatFontNormal)
        macroBox:SetScrollChild(macroEdit)
    end

    -- Counter lives inside the box, bottom-right
    local macroCounter = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    macroCounter:SetPoint("BOTTOMRIGHT", macroBox, "BOTTOMRIGHT", -6, 4)
    macroCounter:SetJustifyH("RIGHT")
    StyleText(macroCounter, "HINT")

    local function UpdateMacroCounter()
        local txt = macroEdit:GetText() or ""
        local n   = utf8len(txt)

        if n > 255 then
            local bytes = #txt
            while bytes > 0 and utf8len(txt) > 255 do
                bytes = bytes - 1
                txt   = string.sub(txt, 1, bytes)
            end
            macroEdit:SetText(txt)
            macroEdit:SetCursorPosition(utf8len(txt))
            n = utf8len(txt)
        end

        macroCounter:SetFormattedText("%d/255", n)
    end

    macroEdit:SetScript("OnTextChanged", UpdateMacroCounter)
    UpdateMacroCounter()


    configFrame.chanceEdit    = chanceEdit
    configFrame.enabledCheck  = enabledCheck
    configFrame.channelChecks = channelChecks
    configFrame.phrasesEdit   = phrasesEdit
    configFrame.macroEdit     = macroEdit

    ------------------------------------------------
    -- Load / apply config
    ------------------------------------------------
    local function ApplyConfigToWidgets(cfg)
        cfg = cfg or {}

        currentTriggerValue = cfg.trigger or DEFAULT_TRIGGER
        UIDropDownMenu_SetSelectedValue(triggerDrop, currentTriggerValue)
        UIDropDownMenu_SetText(triggerDrop, FindTriggerLabel(currentTriggerValue))

        local chance = tonumber(cfg.chance or 5) or 5
        if chance < 1 then chance = 1 end
        chanceEdit:SetNumber(chance)

        enabledCheck:SetChecked(cfg.enabled ~= false)

        local channels = cfg.channels or {}
        for token, cb in pairs(channelChecks) do
            cb:SetChecked(channels[token] and true or false)
        end

        local phrases = cfg.phrases or {}
        local lines = {}
        for _, line in ipairs(phrases) do
            if type(line) == "string" and line ~= "" then
                table.insert(lines, line)
            end
        end
        phrasesEdit:SetText(table.concat(lines, "\n"))
    end

    local function LoadConfigForCurrentAction()
		if not currentAction then
			iconInfoText:SetText("|cffff2020No icon selected.|r")
			ApplyConfigToWidgets(nil)
			return
		end

		local cfg = PE.GetOrCreateActionConfig(currentAction.kind, currentAction.id)

		-- Just explain where the ICON came from; phrases are still macro-based.
		if PE.FormatActionSummary then
			iconInfoText:SetFormattedText(
				"Icon from %s",
				PE.FormatActionSummary(currentAction)
			)
		else
			iconInfoText:SetFormattedText(
				"Icon from |cffffff00%s|r (ID %s)",
				tostring(currentAction.name or "?"),
				tostring(currentAction.id or "?")
			)
		end

		ApplyConfigToWidgets(cfg)
	end


    local function LoadActionByInput()
		local txt = trim(iconEdit:GetText())

		if not txt or txt == "" then
			-- Clear everything
			configFrame.selectedIconTexture = 134400
			iconTexture:SetTexture(134400)
			currentAction = nil
			iconInfoText:SetText("|cffff2020No icon selected.|r")
			ApplyConfigToWidgets(nil)
			return
		end

		-- 1) Numeric → treat as texture file ID
		local asNumber = tonumber(txt)
		if asNumber then
			configFrame.selectedIconTexture = asNumber
			iconTexture:SetTexture(asNumber)
			currentAction = nil
			iconInfoText:SetFormattedText("Icon file ID: |cffffff00%d|r", asNumber)
			ApplyConfigToWidgets(nil)
			return
		end

		-- 2) Try to resolve as a spell/item/emote via PE.ResolveActionFromInput
		local action = GetActionByInput(txt)

		-- If we got a usable action (spell/item), use its icon AND let it
		-- drive trigger logic; phrases still save per macro name.
		if action and action.kind ~= "emote" then
			currentAction = action

			configFrame.selectedIconTexture = action.icon or 134400
			iconTexture:SetTexture(configFrame.selectedIconTexture)

			LoadConfigForCurrentAction()
			return
		end

		-- 3) Fallback: treat the text as a texture path / icon name only.
		-- We don't try to validate the path here; WoW will just show a blank
		-- icon if it's bogus.
		configFrame.selectedIconTexture = nil
		iconTexture:SetTexture(txt)
		currentAction = nil

		iconInfoText:SetFormattedText("Icon texture: |cffffff00%s|r", txt)
		ApplyConfigToWidgets(nil)
	end

	loadButton:SetScript("OnClick", LoadActionByInput)


    ------------------------------------------------
    -- Read UI -> cfg
    ------------------------------------------------
    local function CollectConfigFromWidgets()
        if not currentAction then
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage("PersonaEngine: Load an action first.", 1, 0.2, 0.2)
            end
            return
        end

        local cfg = PE.GetOrCreateActionConfig(currentAction.kind, currentAction.id)

        cfg.trigger = currentTriggerValue or DEFAULT_TRIGGER

        local chance = tonumber(chanceEdit:GetText()) or tonumber(chanceEdit:GetNumber() or 0) or 0
        if chance < 1 then chance = 1 end
        cfg.chance = chance

        cfg.enabled  = enabledCheck:GetChecked() and true or false
        cfg.channels = cfg.channels or {}
        wipe(cfg.channels)
        for token, cb in pairs(channelChecks) do
            if cb:GetChecked() then
                cfg.channels[token] = true
            end
        end

        local text  = phrasesEdit:GetText() or ""
        local lines = {}
        for line in string.gmatch(text, "[^\r\n]+") do
            local t = trim(line)
            if t ~= "" then
                table.insert(lines, t)
            end
        end
        cfg.phrases = lines
        return cfg
    end

    ------------------------------------------------
    -- Macro helpers
    ------------------------------------------------
    local function BuildMacroBody(macroName)
        macroName = trim(macroName or "")
        local override = trim(macroEdit:GetText() or "")

        if override ~= "" then
            return override
        end

        if PE.MacroStudio and PE.MacroStudio.BuildDefaultMacroForAction and currentAction then
            return PE.MacroStudio.BuildDefaultMacroForAction(currentAction, macroName)
        end

        return string.format('/run PE.Say("%s")', macroName ~= "" and macroName or "PersonaMacro")
    end

    local function SaveCurrentConfig(opts)
        opts = opts or {}
        local doMacro = opts.doMacro
        local pickup  = opts.pickup

        local macroName = trim(macroNameEdit:GetText())
        if macroName == "" then
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage("PersonaEngine: Macro name required.", 1, 0.2, 0.2)
            end
            return
        end

        local cfg = CollectConfigFromWidgets()
        if not cfg then
            return
        end

        if doMacro and PE.MacroStudio and PE.MacroStudio.SaveMacro then
            local body    = BuildMacroBody(macroName)
            local iconTex = configFrame.selectedIconTexture or 134400
            local index, scope = PE.MacroStudio.SaveMacro(macroName, body, iconTex)
            if index and scope and PE.MacroStudio.SavePersonaConfig then
                PE.MacroStudio.SavePersonaConfig(scope, macroName, cfg)
                configFrame.currentMacroScope = scope
                configFrame.currentMacroIndex = index
            end

            if pickup and PE.MacroStudio.PickupMacroByName then
                PE.MacroStudio.PickupMacroByName(macroName)
            end
        end
    end

    ------------------------------------------------
    -- Macro browser
    ------------------------------------------------
    local macroBrowser

    local function EnsureMacroBrowser()
        if macroBrowser or not UI.CreateMacroBrowser then
            return macroBrowser
        end

        macroBrowser = UI.CreateMacroBrowser({
            parent = configFrame,
            title  = "Persona Engine – Macro Browser",
            onMacroClick = function(name, body, iconTex, meta)
                macroNameEdit:SetText(name or "")
                macroEdit:SetText(body or "")
                UpdateMacroCounter()

                if iconTex then
                    configFrame.selectedIconTexture = iconTex
                    iconTexture:SetTexture(iconTex)
                end

                if meta then
                    configFrame.currentMacroScope = meta.scope
                    configFrame.currentMacroIndex = meta.index
                end
            end,
        })

        return macroBrowser
    end

    ------------------------------------------------
    -- Bottom buttons
    ------------------------------------------------
    local saveCfgBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    saveCfgBtn:SetSize(120, 24)
    saveCfgBtn:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 4, 4)
    saveCfgBtn:SetText("Save Config")

    local browseBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    browseBtn:SetSize(90, 24)
    browseBtn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -260, 4)
    browseBtn:SetText("Browse...")

    local pickupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    pickupBtn:SetSize(80, 24)
    pickupBtn:SetPoint("LEFT", browseBtn, "RIGHT", 6, 0)
    pickupBtn:SetText("Pick Up")

    local saveMacroBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    saveMacroBtn:SetSize(110, 24)
    saveMacroBtn:SetPoint("LEFT", pickupBtn, "RIGHT", 6, 0)
    saveMacroBtn:SetText("Save as Macro")

    saveCfgBtn:SetScript("OnClick", function()
        SaveCurrentConfig({ doMacro = false })
    end)

    saveMacroBtn:SetScript("OnClick", function()
        SaveCurrentConfig({ doMacro = true, pickup = false })
    end)

    pickupBtn:SetScript("OnClick", function()
        SaveCurrentConfig({ doMacro = true, pickup = true })
    end)

    browseBtn:SetScript("OnClick", function()
        local b = EnsureMacroBrowser()
        if b then b:Show() end
    end)

    ------------------------------------------------
    -- Initial state
    ------------------------------------------------
    ApplyConfigToWidgets(nil)

    ------------------------------------------------
    -- ChatEdit_InsertLink helper for this tab
    ------------------------------------------------
    if ChatEdit_InsertLink then
        if not PE._OrigChatEdit_InsertLink then
            PE._OrigChatEdit_InsertLink = ChatEdit_InsertLink
            ChatEdit_InsertLink = function(text)
                if PE._OrigChatEdit_InsertLink(text) then
                    return true
                end

                if configFrame:IsShown()
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
        end
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Macro Studio UI",
        class = "ui",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
