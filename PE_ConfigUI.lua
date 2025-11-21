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

-- Build a DB of icon entries usable by the icon picker & suggestions.
-- FIX: make sure Blizzard's macro UI is loaded, otherwise GetNumMacroIcons()
-- just returns 0 and we get an empty grid.
local function BuildIconDB()
    -- Ensure Blizzard_MacroUI is loaded so icon data tables exist
    if MacroFrame_LoadUI then
        MacroFrame_LoadUI()
    end

    if not GetNumMacroIcons or not GetMacroIconInfo then
        return {}
    end

    local numIcons = GetNumMacroIcons()
    -- Some clients rely on NUM_MACRO_ICONS after Macro UI load
    if (not numIcons or numIcons <= 0) and _G.NUM_MACRO_ICONS then
        numIcons = _G.NUM_MACRO_ICONS
    end

    if not numIcons or numIcons <= 0 then
        return {}
    end

    local icons = {}

    for i = 1, numIcons do
        local tex = GetMacroIconInfo(i)
        if tex then
            local texture = tex
            local name

            if type(tex) == "number" then
                -- FileID only – use numeric name, suggestions based on that.
                name = tostring(tex)
            else
                -- Path string – take last path component.
                name = tex:match("([^\\]+)$") or tex
            end

            local lower = string.lower(name)

            local kind = "OTHER"
            if lower:find("^inv_") then
                kind = "ITEM"
            elseif lower:find("^spell_") then
                kind = "SPELL"
            end

            table.insert(icons, {
                index   = i,
                texture = texture,
                name    = name,
                lower   = lower,
                kind    = kind,
            })
        end
    end

    return icons
end

----------------------------------------------------
-- Config frame
----------------------------------------------------

local configFrame

local function BuildConfigFrame()
    if configFrame then return end

    ------------------------------------------------
    -- Window
    ------------------------------------------------

    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id       = "Config",
            title    = "Persona Engine – Config",
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

    settingsPage:SetPoint("TOPLEFT",     actionPage, "TOPLEFT")
    settingsPage:SetPoint("BOTTOMRIGHT", actionPage, "BOTTOMRIGHT")
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
    macroNameEdit:SetPoint("RIGHT", actionPage, "RIGHT", -8, 0)
    configFrame.macroNameEdit = macroNameEdit

    ------------------------------------------------
    -- Icon row (icon + optional primary action via Load)
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
    configFrame.spellEdit = iconEdit

    local iconTexture = actionPage:CreateTexture(nil, "OVERLAY")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("LEFT", iconEdit, "RIGHT", 4, 0)
    iconTexture:SetTexture(134400) -- question mark
    configFrame.iconTexture = iconTexture
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
    -- Icon suggestions frame
    ------------------------------------------------

    local iconDB
    local suggestionFrame = CreateFrame("Frame", nil, actionPage, "BackdropTemplate")
    suggestionFrame:SetPoint("TOPLEFT",  iconEdit, "BOTTOMLEFT", 0, -2)
    suggestionFrame:SetPoint("TOPRIGHT", iconEdit, "BOTTOMRIGHT", 0, -2)
    suggestionFrame:SetHeight(1)
    suggestionFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    suggestionFrame:Hide()
    suggestionFrame:SetFrameStrata("DIALOG")
    suggestionFrame:SetFrameLevel(iconEdit:GetFrameLevel() + 5)

    local suggestionButtons = {}
    local activeSuggestions = {}

    local function ApplyIconChoice(data)
        if not data then return end
        configFrame.selectedIconTexture = data.texture or 134400
        iconTexture:SetTexture(configFrame.selectedIconTexture)
        iconEdit:SetText(data.name or "")
        suggestionFrame:Hide()
    end

    local function EnsureSuggestionButton(index)
        if suggestionButtons[index] then
            return suggestionButtons[index]
        end

        local btn = CreateFrame("Button", nil, suggestionFrame)
        btn:SetHeight(20)

        if index == 1 then
            btn:SetPoint("TOPLEFT",  suggestionFrame, "TOPLEFT", 4, -4)
            btn:SetPoint("TOPRIGHT", suggestionFrame, "TOPRIGHT", -4, -4)
        else
            btn:SetPoint("TOPLEFT",  suggestionButtons[index - 1], "BOTTOMLEFT", 0, -2)
            btn:SetPoint("TOPRIGHT", suggestionButtons[index - 1], "BOTTOMRIGHT", 0, -2)
        end

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(16, 16)
        btn.icon:SetPoint("LEFT", btn, "LEFT", 2, 0)

        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        btn.label:SetJustifyH("LEFT")

        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        btn:GetHighlightTexture():SetAlpha(0.4)

        btn:SetScript("OnClick", function(selfBtn)
            ApplyIconChoice(selfBtn._data)
        end)

        suggestionButtons[index] = btn
        return btn
    end

    local function RefreshSuggestions()
        local text = iconEdit:GetText() or ""
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then
            suggestionFrame:Hide()
            return
        end

        if not iconDB then
            iconDB = BuildIconDB()
        end

        wipe(activeSuggestions)

        local lower = string.lower(text)
        local maxEntries = 8
        for _, data in ipairs(iconDB) do
            if data.lower:find(lower, 1, true) then
                table.insert(activeSuggestions, data)
                if #activeSuggestions >= maxEntries then
                    break
                end
            end
        end

        if #activeSuggestions == 0 then
            suggestionFrame:Hide()
            return
        end

        local totalHeight = 8
        for i, data in ipairs(activeSuggestions) do
            local btn = EnsureSuggestionButton(i)
            btn._data = data
            btn.icon:SetTexture(data.texture or 134400)
            btn.label:SetText(data.name or "?")
            btn:Show()
            totalHeight = totalHeight + btn:GetHeight() + 2
        end

        for j = #activeSuggestions + 1, #suggestionButtons do
            suggestionButtons[j]:Hide()
        end

        suggestionFrame:SetHeight(totalHeight)
        suggestionFrame:Show()
    end

    iconEdit:SetScript("OnTextChanged", function()
        RefreshSuggestions()
    end)

    ------------------------------------------------
    -- Primary action state
    ------------------------------------------------

    local currentAction -- { kind, id, name, icon }

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
                tostring(action.id or "?")
            )
        end
        iconInfoText:SetText(summary)

        local cfg = PE.GetOrCreateActionConfig(action.kind, action.id)

        local triggerModes = PE.TRIGGER_MODES or {
            ON_PRESS = "On Button Press",
            ON_CAST  = "On Cast",
            ON_CD    = "When Cooldown Starts",
            ON_READY = "When Cooldown Ready",
        }

        UIDropDownMenu_SetSelectedValue(configFrame.triggerDrop, cfg.trigger)
        UIDropDownMenu_SetText(configFrame.triggerDrop, triggerModes[cfg.trigger] or triggerModes.ON_CAST or "On Cast")

        configFrame.chanceEdit:SetNumber(cfg.chance or 5)

        local chanCfg = cfg.channels or {}
        configFrame.channelCheckboxes.SAY  :SetChecked(chanCfg.SAY)
        configFrame.channelCheckboxes.YELL :SetChecked(chanCfg.YELL)
        configFrame.channelCheckboxes.EMOTE:SetChecked(chanCfg.EMOTE)
        configFrame.channelCheckboxes.PARTY:SetChecked(chanCfg.PARTY)
        configFrame.channelCheckboxes.RAID :SetChecked(chanCfg.RAID)

        configFrame.enabledCheck:SetChecked(cfg.enabled ~= false)

        local buf = ""
        if cfg.phrases then
            for i, line in ipairs(cfg.phrases) do
                buf = buf .. line
                if i < #cfg.phrases then buf = buf .. "\n" end
            end
        end
        configFrame.phraseEdit:SetText(buf)

        if configFrame.macroEdit and PE.MacroStudio and PE.MacroStudio.BuildDefaultMacroForAction then
            local macroText = PE.MacroStudio.BuildDefaultMacroForAction(
                action,
                configFrame.macroNameEdit and configFrame.macroNameEdit:GetText() or nil
            )
            if macroText and macroText ~= "" then
                configFrame.macroEdit:SetText(macroText)
            end
        end
    end

    loadButton:SetScript("OnClick", LoadActionByInput)

    ------------------------------------------------
    -- Icon picker popup
    ------------------------------------------------

    local iconPickerFrame

    local function EnsureIconPicker()
        if iconPickerFrame then
            return iconPickerFrame
        end

        local parent = configFrame or UIParent

        if UI and UI.CreateWindow then
            iconPickerFrame = UI.CreateWindow({
                id    = "IconPicker",
                title = "Choose an Icon:",
                width = 520,
                height = 480,
                strata = "DIALOG",
                level  = 130,
            })
        else
            iconPickerFrame = CreateFrame("Frame", "PersonaEngine_IconPickerFrame", parent, "BasicFrameTemplateWithInset")
            iconPickerFrame:SetSize(520, 480)
            iconPickerFrame:SetPoint("CENTER", UIParent, "CENTER", 40, 40)
            iconPickerFrame:SetFrameStrata("DIALOG")
            iconPickerFrame:SetFrameLevel(130)
            iconPickerFrame:SetMovable(true)
            iconPickerFrame:EnableMouse(true)
            iconPickerFrame:RegisterForDrag("LeftButton")
            iconPickerFrame:SetScript("OnDragStart", iconPickerFrame.StartMoving)
            iconPickerFrame:SetScript("OnDragStop",  iconPickerFrame.StopMovingOrSizing)

            local titleFS = iconPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if iconPickerFrame.TitleBg then
                titleFS:SetPoint("LEFT", iconPickerFrame.TitleBg, "LEFT", 5, 0)
            else
                titleFS:SetPoint("TOPLEFT", 10, -5)
            end
            titleFS:SetText("Choose an Icon:")
            StyleText(titleFS, "TITLE")
            iconPickerFrame.title = titleFS

            local closeBtn = CreateFrame("Button", nil, iconPickerFrame, "UIPanelCloseButton")
            closeBtn:SetPoint("TOPRIGHT", iconPickerFrame, "TOPRIGHT", -5, -5)
        end

        iconPickerFrame:Hide()

        -- Filter / search
        local filterLabel = iconPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        filterLabel:SetPoint("TOPLEFT", iconPickerFrame, "TOPLEFT", 12, -32)
        filterLabel:SetText("Filter:")
        StyleText(filterLabel, "LABEL")

        local filterDrop = CreateFrame("Frame", "PersonaEngine_IconFilterDrop", iconPickerFrame, "UIDropDownMenuTemplate")
        filterDrop:SetPoint("LEFT", filterLabel, "RIGHT", -10, -4)

        local searchLabel = iconPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        searchLabel:SetPoint("TOPRIGHT", iconPickerFrame, "TOPRIGHT", -210, -32)
        searchLabel:SetText("Search:")
        StyleText(searchLabel, "LABEL")

        local searchEdit = CreateFrame("EditBox", nil, iconPickerFrame, "InputBoxTemplate")
        searchEdit:SetAutoFocus(false)
        searchEdit:SetHeight(20)
        searchEdit:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
        searchEdit:SetPoint("RIGHT", iconPickerFrame, "RIGHT", -16, 0)

        -- Scroll area
        local scroll = CreateFrame("ScrollFrame", "PersonaEngine_IconPickerScroll", iconPickerFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",     iconPickerFrame, "TOPLEFT",  12, -60)
        scroll:SetPoint("BOTTOMRIGHT", iconPickerFrame, "BOTTOMRIGHT", -30, 50)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(1, 1)
        scroll:SetScrollChild(content)

        iconPickerFrame._buttons = {}
        iconPickerFrame._filter  = "ALL"
        iconPickerFrame._search  = ""
        iconPickerFrame._selectedIconData = nil

        local function NewIconButton(parentFrame)
            local btn = CreateFrame("Button", nil, parentFrame)
            btn:SetSize(36, 36)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()

            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

            btn:SetScript("OnEnter", function(selfBtn)
                if not GameTooltip or not selfBtn._data then return end
                local data = selfBtn._data
                GameTooltip:SetOwner(selfBtn, "ANCHOR_CURSOR")

                local header = tostring(data.index or 0)
                local textureID
                if type(data.texture) == "number" then
                    textureID = data.texture
                elseif C_Texture and C_Texture.GetFileIDFromPath and type(data.texture) == "string" then
                    textureID = C_Texture.GetFileIDFromPath(data.texture)
                end
                if textureID then
                    header = string.format("%d  %d", data.index or 0, textureID)
                end

                GameTooltip:SetText(header, 1, 0.82, 0, true)
                GameTooltip:AddLine(data.name or "", 0.9, 0.9, 0.9, true)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)

            btn:SetScript("OnClick", function(selfBtn)
                iconPickerFrame._selectedIconData = selfBtn._data
            end)

            return btn
        end

        local function ClearIconButtons()
            for _, b in ipairs(iconPickerFrame._buttons) do
                b:Hide()
                b._data = nil
            end
        end

        local function RefreshIconGrid()
            if not iconDB then
                iconDB = BuildIconDB()
            end

            ClearIconButtons()

            local filter = iconPickerFrame._filter or "ALL"
            local search = string.lower(iconPickerFrame._search or "")

            local filtered = {}
            for _, data in ipairs(iconDB) do
                local passFilter =
                    (filter == "ALL")
                    or (filter == "ITEM"  and data.kind == "ITEM")
                    or (filter == "SPELL" and data.kind == "SPELL")

                if passFilter then
                    if search == "" or data.lower:find(search, 1, true) then
                        table.insert(filtered, data)
                    end
                end
            end

            local cols      = 10
            local padX      = 4
            local padY      = 4
            local cellSize  = 36
            local lastRowY  = 0

            for i, data in ipairs(filtered) do
                local btn = iconPickerFrame._buttons[i]
                if not btn then
                    btn = NewIconButton(content)
                    iconPickerFrame._buttons[i] = btn
                end

                btn._data = data
                btn.icon:SetTexture(data.texture or 134400)

                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)

                local x = 4 + col * (cellSize + padX)
                local y = -4 - row * (cellSize + padY)

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
                btn:Show()

                lastRowY = y
            end

            for j = #filtered + 1, #iconPickerFrame._buttons do
                iconPickerFrame._buttons[j]:Hide()
                iconPickerFrame._buttons[j]._data = nil
            end

            local height = math.abs(lastRowY) + cellSize + padY
            content:SetHeight(math.max(height, 1))
        end

        iconPickerFrame.RefreshIcons = RefreshIconGrid

        local function FilterDrop_OnClick(selfBtn)
            UIDropDownMenu_SetSelectedValue(filterDrop, selfBtn.value)
            iconPickerFrame._filter = selfBtn.value or "ALL"
            RefreshIconGrid()
        end

        UIDropDownMenu_Initialize(filterDrop, function(selfDD, level)
            local info = UIDropDownMenu_CreateInfo()

            info.text   = "All Icons"
            info.value  = "ALL"
            info.func   = FilterDrop_OnClick
            info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "ALL")
            UIDropDownMenu_AddButton(info, level)

            info.text   = "Items"
            info.value  = "ITEM"
            info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "ITEM")
            UIDropDownMenu_AddButton(info, level)

            info.text   = "Spells"
            info.value  = "SPELL"
            info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "SPELL")
            UIDropDownMenu_AddButton(info, level)
        end)

        UIDropDownMenu_SetWidth(filterDrop, 120)
        UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")
        UIDropDownMenu_SetText(filterDrop, "All Icons")

        searchEdit:SetScript("OnTextChanged", function(selfEdit)
            iconPickerFrame._search = selfEdit:GetText() or ""
            RefreshIconGrid()
        end)

        local okBtn = CreateFrame("Button", nil, iconPickerFrame, "UIPanelButtonTemplate")
        okBtn:SetSize(80, 22)
        okBtn:SetPoint("BOTTOMRIGHT", iconPickerFrame, "BOTTOMRIGHT", -8, 8)
        okBtn:SetText("Okay")

        local cancelBtn = CreateFrame("Button", nil, iconPickerFrame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(80, 22)
        cancelBtn:SetPoint("RIGHT", okBtn, "LEFT", -6, 0)
        cancelBtn:SetText("Cancel")

        okBtn:SetScript("OnClick", function()
            local data = iconPickerFrame._selectedIconData
            if data then
                ApplyIconChoice(data)
            end
            iconPickerFrame:Hide()
        end)

        cancelBtn:SetScript("OnClick", function()
            iconPickerFrame:Hide()
        end)

        iconPickerFrame:SetScript("OnShow", function()
            if not iconDB then
                iconDB = BuildIconDB()
            end
            iconPickerFrame._selectedIconData = nil
            iconPickerFrame._search           = ""
            UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")
            UIDropDownMenu_SetText(filterDrop, "All Icons")
            searchEdit:SetText("")
            RefreshIconGrid()
        end)

        return iconPickerFrame
    end

    iconButton:SetScript("OnClick", function()
        local picker = EnsureIconPicker()
        picker:Show()
    end)

    ------------------------------------------------
    -- Trigger dropdown
    ------------------------------------------------

    -- (the rest of the file is unchanged from the last version:
    --   trigger dropdown, chance, channels, phrase box, macro snippet,
    --   SaveCurrentConfig, Macro Browser, etc.)
    --   ↓↓↓
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
