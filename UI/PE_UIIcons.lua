-- ##################################################
-- UI/PE_UIIcons.lua
-- Shared icon DB, autocomplete, and picker
-- ##################################################

local MODULE = "UIIcons"
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
-- Icon DB
----------------------------------------------------

local ICON_DB

local function AddTexture(iconList, tex, kindHint)
    if not tex then return end

    local texture = tex
    local name

    if type(tex) == "number" then
        -- FileID, treat the number as the name for searching
        name = tostring(tex)
    elseif type(tex) == "string" then
        -- Strip path + extension -> inv_sword_04
        local base = tex:match("([^\\/:]+)$") or tex
        name = base:gsub("%.blp$", ""):gsub("%.tga$", "")
    else
        name = tostring(tex)
    end

    local lower = string.lower(name or "")
    local kind  = kindHint or "OTHER"

    if lower:find("^inv_") then
        kind = "ITEM"
    elseif lower:find("^spell_") then
        kind = "SPELL"
    end

    local index = #iconList + 1

    local idStr = ""
    if type(texture) == "number" then
        idStr = tostring(texture)
    end

    -- Search blob: name, index, numeric texture ID
    local searchBlob = string.lower(table.concat({
        name or "",
        tostring(index),
        idStr,
    }, " "))

    table.insert(iconList, {
        index   = index,
        texture = texture,   -- file path or numeric ID
        name    = name,
        lower   = lower,
        kind    = kind,
        search  = searchBlob,
    })
end

local function BuildIconDB()
    if ICON_DB then
        return ICON_DB
    end

    local icons      = {}
    local usedModern = false

    ------------------------------------------------
    -- Modern APIs: GetMacroIcons / GetMacroItemIcons
    ------------------------------------------------

    if GetMacroIcons then
        local t = {}
        GetMacroIcons(t)
        for _, tex in ipairs(t) do
            AddTexture(icons, tex, "SPELL")
        end
        usedModern = true
    end

    if GetMacroItemIcons then
        local t = {}
        GetMacroItemIcons(t)
        for _, tex in ipairs(t) do
            AddTexture(icons, tex, "ITEM")
        end
        usedModern = true
    end

    ------------------------------------------------
    -- Legacy fallback
    ------------------------------------------------

    if not usedModern and GetNumMacroIcons and GetMacroIconInfo then
        if MacroFrame_LoadUI then
            MacroFrame_LoadUI()
        end

        local numIcons = GetNumMacroIcons()
        if (not numIcons or numIcons <= 0) and _G.NUM_MACRO_ICONS then
            numIcons = _G.NUM_MACRO_ICONS
        end

        if numIcons and numIcons > 0 then
            for i = 1, numIcons do
                local tex = GetMacroIconInfo(i)
                AddTexture(icons, tex)
            end
        end
    end

    ICON_DB = icons
    return ICON_DB
end

UI.BuildIconDB = BuildIconDB

----------------------------------------------------
-- Autocomplete under an edit box
----------------------------------------------------
-- UI.AttachIconAutocomplete(editBox, opts)
-- opts.parent       : frame (default parent)
-- opts.maxEntries   : number (default 8)
-- opts.onIconChosen : function(data)

function UI.AttachIconAutocomplete(editBox, opts)
    if not editBox then return nil end

    opts = opts or {}

    local parent       = opts.parent or editBox:GetParent() or UIParent
    local maxEntries   = opts.maxEntries or 8
    local onIconChosen = opts.onIconChosen

    local suggestionFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    suggestionFrame:SetPoint("TOPLEFT",  editBox, "BOTTOMLEFT",  0, -2)
    suggestionFrame:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -2)
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
    suggestionFrame:SetFrameLevel(editBox:GetFrameLevel() + 5)

    local suggestionButtons = {}
    local activeSuggestions = {}

    local function ApplyIconChoice(data)
        if not data then return end
        if onIconChosen then
            onIconChosen(data)
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
            btn:SetPoint("TOPLEFT",  suggestionFrame, "TOPLEFT",  4, -4)
            btn:SetPoint("TOPRIGHT", suggestionFrame, "TOPRIGHT", -4, -4)
        else
            btn:SetPoint("TOPLEFT",  suggestionButtons[index - 1], "BOTTOMLEFT",  0, -2)
            btn:SetPoint("TOPRIGHT", suggestionButtons[index - 1], "BOTTOMRIGHT", 0, -2)
        end

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(16, 16)
        btn.icon:SetPoint("LEFT", btn, "LEFT", 2, 0)

        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("LEFT",  btn.icon, "RIGHT", 4, 0)
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
        local text = editBox:GetText() or ""
        text = text:gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            suggestionFrame:Hide()
            return
        end

        local iconDB = BuildIconDB()
        wipe(activeSuggestions)

        local lower = string.lower(text)

        for _, data in ipairs(iconDB) do
            if data.search and data.search:find(lower, 1, true) then
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

    editBox:HookScript("OnTextChanged", function()
        RefreshSuggestions()
    end)

    suggestionFrame.Refresh = RefreshSuggestions
    return suggestionFrame
end

----------------------------------------------------
-- Icon picker popup window
----------------------------------------------------
-- UI.CreateIconPicker(opts) -> frame
-- opts.parent           : frame
-- opts.id               : string
-- opts.title            : string
-- opts.onIconChosen     : function(data)
-- opts.initialTexture   : number|string
-- opts.initialName      : string

function UI.CreateIconPicker(opts)
    opts = opts or {}

    local parent       = opts.parent or UIParent
    local titleText    = opts.title or "Choose an Icon:"
    local windowId     = opts.id or "IconPicker"
    local onIconChosen = opts.onIconChosen

    local f

    if UI.CreateWindow then
        f = UI.CreateWindow({
            id     = windowId,
            title  = titleText,
            width  = 520,
            height = 480,
            strata = "DIALOG",
            level  = 130,
        })
    else
        f = CreateFrame("Frame", "PersonaEngine_" .. windowId .. "Frame", parent, "BasicFrameTemplateWithInset")
        f:SetSize(520, 480)
        f:SetPoint("CENTER", UIParent, "CENTER", 40, 40)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(130)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop",  f.StopMovingOrSizing)

        local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if f.TitleBg then
            titleFS:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
        else
            titleFS:SetPoint("TOPLEFT", 10, -5)
        end
        titleFS:SetText(titleText)
        f.title = titleFS

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    end

    f:Hide()

    f._buttons          = {}
    f._filter           = "ALL"
    f._search           = ""
    f._selectedIconData = nil
    f._initialTexture   = opts.initialTexture
    f._initialName      = opts.initialName

    function f:SetInitialSelection(texture, name)
        self._initialTexture = texture
        self._initialName    = name
    end

    local filterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    filterLabel:SetText("Filter:")

    local filterDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
    filterDrop:SetPoint("LEFT", filterLabel, "RIGHT", -10, -4)

    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -210, -32)
    searchLabel:SetText("Search:")

    local searchEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchEdit:SetAutoFocus(false)
    searchEdit:SetHeight(20)
    searchEdit:SetPoint("LEFT",  searchLabel, "RIGHT", 6, 0)
    searchEdit:SetPoint("RIGHT", f, "RIGHT", -16, 0)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT", 12, -60)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 50)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    ------------------------------------------------
    -- Icon buttons
    ------------------------------------------------

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
            if type(data.texture) == "number" then
                header = string.format("%d (%d)", data.index or 0, data.texture)
            end

            GameTooltip:SetText(header, 1, 0.82, 0, true)
            GameTooltip:AddLine(data.name or "", 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        btn:SetScript("OnClick", function(selfBtn)
            f._selectedIconData = selfBtn._data
        end)

        return btn
    end

    local function ClearIconButtons()
        for _, b in ipairs(f._buttons) do
            b:Hide()
            b._data = nil
        end
    end

    local function RefreshIconGrid()
        local iconDB = BuildIconDB()
        ClearIconButtons()

        local filter = f._filter or "ALL"
        local search = string.lower(f._search or "")

        local filtered = {}

        for _, data in ipairs(iconDB) do
            local passFilter =
                (filter == "ALL") or
                (filter == "ITEM"  and data.kind == "ITEM") or
                (filter == "SPELL" and data.kind == "SPELL")

            if passFilter then
                if search == "" or (data.search and data.search:find(search, 1, true)) then
                    table.insert(filtered, data)
                end
            end
        end

        local cols     = 10
        local padX     = 4
        local padY     = 4
        local cellSize = 36
        local lastRowY = 0

        for i, data in ipairs(filtered) do
            local btn = f._buttons[i]
            if not btn then
                btn = NewIconButton(content)
                f._buttons[i] = btn
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

        for j = #filtered + 1, #f._buttons do
            f._buttons[j]:Hide()
            f._buttons[j]._data = nil
        end

        local height = math.abs(lastRowY) + cellSize + padY
        content:SetHeight(math.max(height, 1))
    end

    f.RefreshIcons = RefreshIconGrid

    ------------------------------------------------
    -- Filter dropdown
    ------------------------------------------------

    local function FilterDrop_OnClick(selfBtn)
        UIDropDownMenu_SetSelectedValue(filterDrop, selfBtn.value)
        f._filter = selfBtn.value or "ALL"
        RefreshIconGrid()
    end

    UIDropDownMenu_Initialize(filterDrop, function(selfDD, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text    = "All Icons"
        info.value   = "ALL"
        info.func    = FilterDrop_OnClick
        info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "ALL")
        UIDropDownMenu_AddButton(info, level)

        info.text    = "Items"
        info.value   = "ITEM"
        info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "ITEM")
        UIDropDownMenu_AddButton(info, level)

        info.text    = "Spells"
        info.value   = "SPELL"
        info.checked = (UIDropDownMenu_GetSelectedValue(selfDD) == "SPELL")
        UIDropDownMenu_AddButton(info, level)
    end)

    UIDropDownMenu_SetWidth(filterDrop, 120)
    UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")
    UIDropDownMenu_SetText(filterDrop, "All Icons")

    ------------------------------------------------
    -- Search box
    ------------------------------------------------

    searchEdit:SetScript("OnTextChanged", function(selfEdit)
        f._search = selfEdit:GetText() or ""
        RefreshIconGrid()
    end)

    ------------------------------------------------
    -- Okay / Cancel
    ------------------------------------------------

    local function ApplyIconChoice(data)
        if not data then return end
        if onIconChosen then
            onIconChosen(data)
        end
    end

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 22)
    okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    okBtn:SetText("Okay")

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("RIGHT", okBtn, "LEFT", -6, 0)
    cancelBtn:SetText("Cancel")

    okBtn:SetScript("OnClick", function()
        local data = f._selectedIconData

        -- If user never clicked, try to keep current icon instead of clearing
        if not data and f._initialTexture then
            local tex       = f._initialTexture
            local nameLower = f._initialName and string.lower(f._initialName) or nil
            local iconDB    = BuildIconDB()

            for _, d in ipairs(iconDB) do
                local matches =
                    (tex and d.texture == tex) or
                    (nameLower and d.lower == nameLower)

                if matches then
                    data = d
                    break
                end
            end
        end

        if data then
            ApplyIconChoice(data)
        end
        f:Hide()
    end)

    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    ------------------------------------------------
    -- OnShow: reset filters + build
    ------------------------------------------------

    f:SetScript("OnShow", function()
        BuildIconDB()

        f._selectedIconData = nil
        f._search           = ""

        UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")
        UIDropDownMenu_SetText(filterDrop, "All Icons")
        searchEdit:SetText("")

        RefreshIconGrid()
    end)

    return f
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Icons",
        class = "ui",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
