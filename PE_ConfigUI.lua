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
        template  = "GameFontHighlight",
        sizeOffset = 0,
        color     = { 1.0, 0.96, 0.41, 1.0 }, -- gold
    },
    HEADER = {
        template  = "GameFontNormalLarge",
        sizeOffset = 0,
        color     = { 1.0, 0.82, 0.0, 1.0 },
    },
    LABEL = {
        template  = "GameFontNormal",
        sizeOffset = 0,
        color     = { 0.90, 0.90, 0.90, 1.0 },
    },
    HINT = {
        template  = "GameFontHighlightSmall",
        sizeOffset = 0,
        color     = { 0.75, 0.75, 0.75, 1.0 },
    },
    EMPHASIS = {
        template  = "GameFontHighlight",
        sizeOffset = 0,
        color     = { 1.0, 1.0, 1.0, 1.0 },
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
-- Action lookup wrapper (spell / item / emote)
----------------------------------------------------

local function GetActionByInput(input)
    if not input or input == "" then return nil end
    if not PE or not PE.ResolveActionFromInput then return nil end
    return PE.ResolveActionFromInput(input)
end

----------------------------------------------------
-- Icon database (for suggestions + picker)
----------------------------------------------------

local function BuildIconDB()
    if not GetNumMacroIcons or not GetMacroIconInfo then
        return {}
    end

    local icons = {}
    local numIcons = GetNumMacroIcons()
    for i = 1, numIcons do
        local tex = GetMacroIconInfo(i)
        if tex and tex ~= "" then
            local name = tex:match("([^\\]+)$") or tex
            local lower = string.lower(name)
            local kind = "OTHER"
            if lower:find("^inv_") then
                kind = "ITEM"
            elseif lower:find("^spell_") then
                kind = "SPELL"
            end
            table.insert(icons, {
                index   = i,
                texture = tex,
                name    = name,   -- e.g. INV_Misc_Bag_03
                lower   = lower,  -- lowercase for search
                kind    = kind,
            })
        end
    end

    return icons
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
            id      = "Config",
            title   = "Persona Engine \226\128\147 Config",
            width   = 700,
            height  = 750,
            minWidth  = 520,
            minHeight = 430,
            strata  = "DIALOG",
            level   = 100,
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
    -- Icon / primary-action row
    ------------------------------------------------

    local spellLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", macroNameLabel, "BOTTOMLEFT", 0, -18)
    spellLabel:SetText("Icon Name or ID:")
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
    spellEdit:SetPoint("LEFT",  spellLabel,  "RIGHT",  8, 0)
    spellEdit:SetPoint("RIGHT", loadButton,  "LEFT",  -26, 0)

    -- Icon texture + clickable overlay
    local spellIcon = actionPage:CreateTexture(nil, "OVERLAY")
    spellIcon:SetSize(24, 24)
    spellIcon:SetPoint("LEFT", spellEdit, "RIGHT", 4, 0)
    spellIcon:SetTexture(134400) -- default question mark

    -- Clickable button on top of icon
    local iconButton = CreateFrame("Button", nil, actionPage)
    iconButton:SetSize(24, 24)
    iconButton:SetPoint("CENTER", spellIcon, "CENTER")
    iconButton:EnableMouse(true)

    ------------------------------------------------
    -- Info icon for the row
    ------------------------------------------------

    local spellHelp = CreateFrame("Button", nil, actionPage)
    spellHelp:SetSize(16, 16)
    spellHelp:SetPoint("RIGHT", loadButton, "LEFT", -4, 0)

    local helpTex = spellHelp:CreateTexture(nil, "OVERLAY")
    helpTex:SetAllPoints()
    helpTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    spellHelp:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Choosing an icon", 1, 1, 1, true)
        GameTooltip:AddLine("• Type an icon name like |cffffff00inv_misc_bag_03|r or a file ID.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Or Shift+Left-click a spell, item, or macro to copy its icon.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Click |cffffff00Load|r to pull icon and primary action from text.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("• Or click the icon to open the full icon picker.", 0.8, 0.8, 0.8, true)
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

    ------------------------------------------------
    -- Icon suggestions dropdown (below Icon Name or ID)
    ------------------------------------------------

    local iconDB            = nil
    local suggestionFrame   = CreateFrame("Frame", nil, actionPage, "BackdropTemplate")
    suggestionFrame:SetPoint("TOPLEFT",  spellEdit, "BOTTOMLEFT", 0, -2)
    suggestionFrame:SetPoint("TOPRIGHT", spellEdit, "BOTTOMRIGHT", 0, -2)
    suggestionFrame:SetHeight(1)
    suggestionFrame:Hide()

    suggestionFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    local suggestionButtons = {}
    local activeSuggestions = {}

    local function ApplyIconChoice(data)
        if not data then return end
        configFrame.selectedIconTexture = data.texture
        spellIcon:SetTexture(data.texture or 134400)
        if spellEdit and not spellEdit:HasFocus() then
            spellEdit:SetText(data.name or "")
        else
            spellEdit:SetText(data.name or "")
        end
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
        if not spellEdit or not suggestionFrame then return end

        local text = spellEdit:GetText() or ""
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

    spellEdit:SetScript("OnTextChanged", function()
        RefreshSuggestions()
    end)

    ------------------------------------------------
    -- Primary action tracking
    ------------------------------------------------

    local currentAction -- { kind, id, name, icon }

    local function LoadActionByInput()
        if not PE.GetOrCreateActionConfig then
            spellInfoText:SetText("|cffff2020Action config system not ready.|r")
            return
        end

        local txt = spellEdit:GetText()
        if not txt or txt == "" then
            spellInfoText:SetText("|cffff2020No icon / action provided.|r")
            spellIcon:SetTexture(134400)
            currentAction = nil
            return
        end

        local action = GetActionByInput(txt)
        if not action then
            spellInfoText:SetText("|cffff2020Unknown spell/item/emote for primary action.|r")
            -- Still allow icon suggestions / manual icon
            return
        end

        currentAction = action

        -- Seed icon from the action if user hasn't chosen a custom one
        if not configFrame.selectedIconTexture then
            spellIcon:SetTexture(action.icon or 134400)
        end

        local summary = PE.FormatActionSummary and PE.FormatActionSummary(action) or string.format(
            "Primary action: |cffffff00%s|r (%s:%s)",
            tostring(action.name or "?"),
            tostring(action.kind or "?"),
            tostring(action.id or "?")
        )

        spellInfoText:SetText(summary)

        -- Pull config from DB (per-action) to seed UI
        local cfg = PE.GetOrCreateActionConfig(action.kind, action.id)

        local triggerModes = PE.TRIGGER_MODES or {
            ON_PRESS       = "On Button Press",
            ON_CAST        = "On Cast",
            ON_CD          = "When Cooldown Starts",
            ON_READY       = "When Cooldown Ready",
            ON_BUFF_ACTIVE = "While Buff Is Active",
            ON_NOT_GCD     = "When GCD Is Free",
        }

        UIDropDownMenu_SetSelectedValue(configFrame.triggerDrop, cfg.trigger)
        UIDropDownMenu_SetText(
            configFrame.triggerDrop,
            triggerModes[cfg.trigger] or triggerModes.ON_CAST or "On Cast"
        )

        configFrame.chanceEdit:SetNumber(cfg.chance or 10)

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
                if i < #cfg.phrases then
                    buf = buf .. "\n"
                end
            end
        end
        configFrame.phraseEdit:SetText(buf)

        -- Macro snippet: build default using current macro name (if any)
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
    -- Icon picker window
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

        -- Filter dropdown
        local filterLabel = iconPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        filterLabel:SetPoint("TOPLEFT", iconPickerFrame, "TOPLEFT", 12, -32)
        filterLabel:SetText("Filter:")
        StyleText(filterLabel, "LABEL")

        local filterDrop = CreateFrame("Frame", "PersonaEngine_IconFilterDrop", iconPickerFrame, "UIDropDownMenuTemplate")
        filterDrop:SetPoint("LEFT", filterLabel, "RIGHT", -10, -4)

        -- Search box
        local searchLabel = iconPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        searchLabel:SetPoint("TOPRIGHT", iconPickerFrame, "TOPRIGHT", -210, -32)
        searchLabel:SetText("Search:")
        StyleText(searchLabel, "LABEL")

        local searchEdit = CreateFrame("EditBox", nil, iconPickerFrame, "InputBoxTemplate")
        searchEdit:SetAutoFocus(false)
        searchEdit:SetHeight(20)
        searchEdit:SetPoint("LEFT",  searchLabel, "RIGHT", 6, 0)
        searchEdit:SetPoint("RIGHT", iconPickerFrame, "RIGHT", -16, 0)

        -- Scroll + grid
        local scroll = CreateFrame("ScrollFrame", "PersonaEngine_IconPickerScroll", iconPickerFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",  iconPickerFrame, "TOPLEFT",  12, -60)
        scroll:SetPoint("BOTTOMRIGHT", iconPickerFrame, "BOTTOMRIGHT", -30, 50)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(1, 1)
        scroll:SetScrollChild(content)

        iconPickerFrame._buttons = {}
        iconPickerFrame._filter  = "ALL"
        iconPickerFrame._search  = ""
        iconPickerFrame._selectedIconData = nil

        local function NewIconButton(parent)
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(36, 36)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()

            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

            btn:SetScript("OnEnter", function(selfBtn)
                if not GameTooltip or not selfBtn._data then return end
                local data = selfBtn._data
                GameTooltip:SetOwner(selfBtn, "ANCHOR_CURSOR")

                local fileId
                if C_Texture and C_Texture.GetFileIDFromPath and data.texture then
                    fileId = C_Texture.GetFileIDFromPath(data.texture)
                end

                local header = string.format("%d%s%s",
                    data.index or 0,
                    fileId and ("  " .. tostring(fileId)) or "",
                    ""
                )
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
            local search = iconPickerFrame._search or ""
            search = string.lower(search)

            local filtered = {}
            for _, data in ipairs(iconDB) do
                local passFilter = (filter == "ALL")
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

        -- Filter dropdown init
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

        -- Buttons Okay / Cancel
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
            iconPickerFrame._search = ""
            searchEdit:SetText("")
            UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")
            UIDropDownMenu_SetText(filterDrop, "All Icons")
            iconPickerFrame._filter = "ALL"
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

    local triggerLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", spellInfoText, "BOTTOMLEFT", 0, -12)
    triggerLabel:SetText("When should Copporclang speak?")
    StyleText(triggerLabel, "LABEL")

    local triggerDrop = CreateFrame("Frame", "PersonaEngineTriggerDrop", actionPage, "UIDropDownMenuTemplate")
    triggerDrop:SetPoint("LEFT", triggerLabel, "RIGHT", -10, -4)

    -- "?" help
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
        GameTooltip:AddLine(" • Eligible every time the macro runs.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" • Ignores cooldown and resource checks.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" • Still respects chance and rate limiting.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)
        GameTooltip:AddLine("On Cast:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" • Only if the action would actually cast now.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" • Not on cooldown, and usable (resources/range).", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)
        GameTooltip:AddLine("When Cooldown Starts:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" • Fires once when the action goes from ready → on cooldown.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)
        GameTooltip:AddLine("When Cooldown Ready:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" • Fires once when the action goes from on cooldown → ready.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)
        GameTooltip:AddLine("While Buff Is Active:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" • Eligible only while this spell's buff is on you or your pet.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ", 0, 0, 0, false)
        GameTooltip:AddLine("When GCD Is Free:", 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" • Eligible only while the global cooldown is currently free.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    triggerHelp:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local function TriggerDrop_OnClick(selfBtn)
        UIDropDownMenu_SetSelectedValue(triggerDrop, selfBtn.value)
    end

    UIDropDownMenu_Initialize(triggerDrop, function(selfDD, level)
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
            info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == key)
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
    -- Phrase editor
    ------------------------------------------------

    local phraseLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phraseLabel:SetPoint("TOPLEFT", chanLabel, "BOTTOMLEFT", 0, -36)
    phraseLabel:SetText("Phrases (one per line):")
    StyleText(phraseLabel, "LABEL")

    local phraseScroll, phraseEdit

    if UI and UI.CreateMultilineEdit then
        local PHRASE_BOTTOM_OFFSET = 180
        phraseScroll, phraseEdit = UI.CreateMultilineEdit(actionPage, {
            name   = "PersonaEnginePhraseScroll",
            point  = { "TOPLEFT", phraseLabel, "BOTTOMLEFT", -4, -6 },
            point2 = { "BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -10, PHRASE_BOTTOM_OFFSET },
            fontObject   = ChatFontNormal,
            textScale    = GLOBAL_FONT_SCALE,
            padding      = 20,
            minHeight    = 200,
            extraHeight  = 600,
            backdrop     = true,
            outerBottomPad = 12,
        })
    else
        phraseScroll = CreateFrame("ScrollFrame", "PersonaEnginePhraseScroll", actionPage, "UIPanelScrollFrameTemplate,BackdropTemplate")
        phraseScroll:SetPoint("TOPLEFT",     phraseLabel, "BOTTOMLEFT", -4, -6)
        phraseScroll:SetPoint("BOTTOMRIGHT", actionPage,  "BOTTOMRIGHT", -10, 130)

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
    -- Macro snippet area
    ------------------------------------------------

    local MAX_MACRO_CHARS = 255

    local macroScroll, macroEdit
    if UI and UI.CreateMultilineEdit then
        local PHRASE_MACRO_GAP = -14
        macroScroll, macroEdit = UI.CreateMultilineEdit(actionPage, {
            point   = { "TOPLEFT", configFrame.phraseScroll, "BOTTOMLEFT", 0, PHRASE_MACRO_GAP },
            point2  = { "BOTTOMRIGHT", actionPage, "BOTTOMRIGHT", -10, 40 },
            fontObject   = ChatFontNormal,
            textScale    = GLOBAL_FONT_SCALE,
            padding      = 20,
            minHeight    = 60,
            extraHeight  = 140,
            backdrop     = true,
            onFocusHighlight = true,
        })
    else
        macroScroll = CreateFrame("ScrollFrame", nil, actionPage, "UIPanelScrollFrameTemplate,BackdropTemplate")
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

    local macroCountLabel = actionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    macroCountLabel:SetPoint("LEFT", macroLabel, "RIGHT", 8, 0)
    macroCountLabel:SetText(string.format("0/%d", MAX_MACRO_CHARS))
    StyleText(macroCountLabel, "HINT")
    configFrame.macroCountLabel = macroCountLabel

    macroEdit:HookScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local len  = (strlenutf8 and strlenutf8(text)) or #text
        if len > MAX_MACRO_CHARS then
            local trimmed = text
            while len > MAX_MACRO_CHARS and trimmed ~= "" do
                trimmed = trimmed:sub(1, -2)
                len = (strlenutf8 and strlenutf8(trimmed)) or #trimmed
            end
            self:SetText(trimmed)
            self:SetCursorPosition(len or MAX_MACRO_CHARS)
        end
        if macroCountLabel then
            macroCountLabel:SetFormattedText("%d/%d", len, MAX_MACRO_CHARS)
        end
    end)

    ------------------------------------------------
    -- Macro Studio buttons (bottom-right)
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
    -- Macro browser popup
    ------------------------------------------------

    if UI and UI.CreateMacroBrowser then
        configFrame.macroBrowser = UI.CreateMacroBrowser({
            parent = configFrame,
            title  = "PersonaEngine \226\128\147 Macro Picker",
            onMacroClick = function(name, body, icon, meta)
                if macroNameEdit then macroNameEdit:SetText(name or "") end
                if macroEdit     then macroEdit:SetText(body or "") end
                configFrame.currentMacroName  = name
                configFrame.currentMacroScope = meta and meta.scope or nil
                configFrame.currentMacroIndex = meta and meta.index or nil
                -- Seed icon from the macro we just picked, if user hasn't chosen one
                if icon and icon ~= "" and not configFrame.selectedIconTexture then
                    configFrame.selectedIconTexture = icon
                    spellIcon:SetTexture(icon)
                end
            end,
        })
    end

    ------------------------------------------------
    -- Save current config (action -> macro binding)
    ------------------------------------------------

    local function SaveCurrentConfig()
        if not currentAction then
            spellInfoText:SetText("|cffff2020Pick a valid primary action with |cffffff00Load|r first.|r")
            return
        end

        if not PE.GetOrCreateActionConfig then
            spellInfoText:SetText("|cffff2020Action config system not ready.|r")
            return
        end

        local macroName = macroNameEdit and macroNameEdit:GetText() or ""
        if macroName == "" then
            spellInfoText:SetText("|cffff2020Macro name required.|r")
            return
        end

        -- Per-action config (also used as cfg table we bind to macro)
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
            cfg.phrases = { "…internal monologue buffer overflow…" }
        end

        -- Metadata for macro binding
        cfg._kind = currentAction.kind
        cfg._id   = currentAction.id

        -- Save macro body + ensure macro exists
        local macroBody = configFrame.macroEdit and configFrame.macroEdit:GetText() or ""
        if PE.MacroStudio and macroBody ~= "" then
            local iconTexture = configFrame.selectedIconTexture
                               or (currentAction and currentAction.icon)
                               or 134400
            local index, scope = PE.MacroStudio.SaveMacro(macroName, macroBody, iconTexture)
            if scope then configFrame.currentMacroScope  = scope end
            if index then configFrame.currentMacroIndex  = index end
        end

        -- Bind this macro to this action config (macro-scoped persona DB)
        if PE.MacroStudio and PE.MacroStudio.SavePersonaConfig then
            local scope = configFrame.currentMacroScope or "character"
            PE.MacroStudio.SavePersonaConfig(scope, macroName, cfg)
        end

        -- Refresh macro browser to pick up icon/name changes
        if configFrame.macroBrowser and configFrame.macroBrowser.Refresh then
            configFrame.macroBrowser:Refresh()
        end

        spellInfoText:SetText((spellInfoText:GetText() or "") .. " |cff20ff20Saved.|r")
    end

    ------------------------------------------------
    -- Button scripts
    ------------------------------------------------

    saveMacroBtn:SetScript("OnClick", function()
        SaveCurrentConfig()
    end)

    pickupMacroBtn:SetScript("OnClick", function()
        -- Ensure what we pick up matches the editor
        SaveCurrentConfig()

        local macroName = macroNameEdit and macroNameEdit:GetText() or ""
        if macroName == "" then return end

        if PE.MacroStudio and PE.MacroStudio.PickupMacroByName then
            PE.MacroStudio.PickupMacroByName(macroName)
        end
    end)

    browseMacroBtn:SetScript("OnClick", function()
        local browser = configFrame.macroBrowser
        if browser and browser.Refresh then
            browser:Refresh()
            browser:Show()
        end
    end)

    --------------------------------------------------
    -- Save button (bottom-left) - same Save behavior
    --------------------------------------------------

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
-- ChatEdit_InsertLink hook (icon / spell link → icon box)
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

            -- If our config is open and icon box focused, capture links
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
    else
        if PE.Log then
            PE.Log(2, "ChatEdit_InsertLink not available; icon link capture disabled.")
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
