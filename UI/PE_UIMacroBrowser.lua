-- ##################################################
-- UI/PE_UIMacroBrowser.lua
-- Popup windows:
--   * Macro Browser (existing)
--   * Icon Picker (new, macro-icon style grid)
-- ##################################################

local MODULE = "UIMacroBrowser"
local PE = PE

if not PE or type(PE) ~= "table" then
    return
end

PE.UI = PE.UI or {}
local UI = PE.UI

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-----------------------------------------------------
-- Macro Browser widget (unchanged)
-----------------------------------------------------
-- UI.CreateMacroBrowser(opts) -> frame
-- opts.parent      : parent frame (default UIParent)
-- opts.onMacroClick: function(name, body, iconTexture) called on left-click
-- opts.title       : window title (optional)

function UI.CreateMacroBrowser(opts)
    opts = opts or {}
    local parent    = opts.parent or UIParent
    local titleText = opts.title or "PersonaEngine – Macros"

    local f = CreateFrame("Frame", "PersonaEngine_MacroBrowserFrame", parent, "BasicFrameTemplateWithInset")
    f:SetSize(500, 420)
    f:SetPoint("CENTER", UIParent, "CENTER", 40, 20)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(120)
    f:Hide()

    -- Title
    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if f.TitleBg then
        titleFS:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
    else
        titleFS:SetPoint("TOPLEFT", 10, -5)
    end
    titleFS:SetText(titleText)
    f.title = titleFS

    -- Close
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- Explicit Hide button (alternative)
    local miniBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    miniBtn:SetSize(80, 20)
    miniBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    miniBtn:SetText("Hide")
    miniBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    ------------------------------------------------
    -- Scrollable list (2-column, icons + names)
    ------------------------------------------------

    local scroll = CreateFrame("ScrollFrame", "PersonaEngine_MacroBrowserScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 30)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    f._buttons = {}

    local function ClearButtons()
        for _, b in ipairs(f._buttons) do
            b:Hide()
            b:SetScript("OnEnter", nil)
            b:SetScript("OnLeave", nil)
            b:SetScript("OnClick", nil)
            b:SetScript("OnDragStart", nil)
            b:SetScript("OnDragStop", nil)
        end
        wipe(f._buttons)
    end

    local function NewButton(parent)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(40, 40)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()

        btn.nameFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.nameFS:SetPoint("LEFT", btn, "RIGHT", 6, 0)
        btn.nameFS:SetJustifyH("LEFT")
        btn.nameFS:SetWidth(320)

        return btn
    end

    function f:Refresh()
        ClearButtons()

        local numGlobal, numChar = GetNumMacros()
        local total = numGlobal + numChar

        local cols        = 2
        local padX        = 8
        local padY        = 6
        local colWidth    = 240
        local rowHeight   = 44
        local row, col    = 0, 0
        local lastRowBottom = 0

        for index = 1, total do
            local name, iconTexture = GetMacroInfo(index)
            if name and name ~= "" then
                local btn = NewButton(content)
                table.insert(f._buttons, btn)

                col = col + 1
                if col > cols then
                    col = 1
                    row = row + 1
                elseif row == 0 then
                    row = 1
                end

                local x = (col - 1) * colWidth
                local y = -((row - 1) * rowHeight)

                btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
                btn.icon:SetTexture(iconTexture or 134400)
                btn.nameFS:SetText(string.format("%s%s", name, ""))

                btn.macroIndex = index
                btn.macroName  = name

                btn:SetScript("OnEnter", function(self)
                    if not GameTooltip then
                        return
                    end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(name, 1, 1, 1, true)

                    local bodyText = GetMacroBody(self.macroIndex) or ""
                    if bodyText ~= "" then
                        GameTooltip:AddLine(" ", 0, 0, 0, false)
                        GameTooltip:AddLine(bodyText, 0.8, 0.8, 0.8, true)
                    end
                    GameTooltip:Show()
                end)

                btn:SetScript("OnLeave", function()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)

                btn:RegisterForDrag("LeftButton")
                btn:SetScript("OnDragStart", function(self)
                    PickupMacro(self.macroIndex)
                    -- Do NOT hide the popup; user may drop multiple times.
                end)
                btn:SetScript("OnDragStop", function()
                    -- nothing special
                end)

                btn:SetScript("OnClick", function(self)
                    local bodyText = GetMacroBody(self.macroIndex) or ""
                    local tex      = self.icon:GetTexture()
                    if type(opts.onMacroClick) == "function" then
                        opts.onMacroClick(self.macroName, bodyText, tex)
                    end
                    -- Clicking a macro hides the popup (per original spec)
                    f:Hide()
                end)

                lastRowBottom = y - rowHeight
            end
        end

        local height = math.abs(lastRowBottom) + rowHeight + padY
        content:SetHeight(math.max(height, 1))
    end

    return f
end

-----------------------------------------------------
-- Icon Picker widget (new)
-----------------------------------------------------
-- UI.CreateIconPicker(opts) -> frame
-- opts.parent       : parent frame (default UIParent)
-- opts.onIconChosen : function(info) called when user presses "Okay"
--                      info has fields:
--                        info.texture     (path or fileID)
--                        info.fileID      (may be nil on some clients)
--                        info.name        ("inv_misc_bag_03" style, lower-cased)
--                        info.kind        ("SPELL"/"ITEM")
--                        info.globalIndex (1-based across both lists)
-- opts.title        : optional window title

function UI.CreateIconPicker(opts)
    opts = opts or {}
    local parent    = opts.parent or UIParent
    local titleText = opts.title or "Choose an Icon"

    local MS = PE.MacroStudio

    local f = CreateFrame("Frame", "PersonaEngine_IconPickerFrame", parent, "BasicFrameTemplateWithInset")
    f:SetSize(520, 500)
    f:SetPoint("CENTER", UIParent, "CENTER", 60, 40)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(130)
    f:Hide()

    -- Title
    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if f.TitleBg then
        titleFS:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
    else
        titleFS:SetPoint("TOPLEFT", 10, -5)
    end
    titleFS:SetText(titleText)
    f.title = titleFS

    -- Close button (top-right)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- Filter dropdown: All / Items / Spells
    local filterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
    filterLabel:SetText("Filter:")

    local filterDrop = CreateFrame("Frame", "PersonaEngine_IconPickerFilterDrop", f, "UIDropDownMenuTemplate")
    filterDrop:SetPoint("LEFT", filterLabel, "RIGHT", 0, -2)
    f.filterDrop = filterDrop
    f.filter     = "ALL"

    local function FilterDrop_OnClick(self)
        UIDropDownMenu_SetSelectedValue(filterDrop, self.value)
        f.filter = self.value or "ALL"
        if f.Refresh then
            f:Refresh()
        end
    end

    UIDropDownMenu_Initialize(filterDrop, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.func = FilterDrop_OnClick

        info.text   = "All Icons"
        info.value  = "ALL"
        info.checked = (f.filter == "ALL")
        UIDropDownMenu_AddButton(info, level)

        info.text   = "Items"
        info.value  = "ITEM"
        info.checked = (f.filter == "ITEM")
        UIDropDownMenu_AddButton(info, level)

        info.text   = "Spells"
        info.value  = "SPELL"
        info.checked = (f.filter == "SPELL")
        UIDropDownMenu_AddButton(info, level)
    end)

    UIDropDownMenu_SetWidth(filterDrop, 110)
    UIDropDownMenu_SetSelectedValue(filterDrop, "ALL")

    -- Search box (bottom left)
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "PersonaEngine_IconPickerSearch", f, "InputBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetAutoFocus(false)
    f.searchBox = searchBox

    -- Okay / Cancel buttons (bottom right)
    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 20)
    okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -100, 8)
    okBtn:SetText("Okay")

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 20)
    cancelBtn:SetPoint("RIGHT", okBtn, "RIGHT", 90, 0)
    cancelBtn:SetText("Cancel")

    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Scrollable icon grid (macro icon style)
    local scroll = CreateFrame("ScrollFrame", "PersonaEngine_IconPickerScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -52)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 40)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    f._iconButtons   = {}
    f._iconSelection = nil

    local function ClearIconButtons()
        for _, b in ipairs(f._iconButtons) do
            b:Hide()
            b:SetScript("OnEnter", nil)
            b:SetScript("OnLeave", nil)
            b:SetScript("OnClick", nil)
        end
        wipe(f._iconButtons)
    end

    local function NewIconButton(parent)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(32, 32)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()

        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        return btn
    end

    -- Build filtered, searched list of icon records
    local function BuildFilteredIconList()
        local result = {}
        if not MS or not MS.GetIconIndex then
            return result
        end

        local allIcons = MS.GetIconIndex()
        local filter   = f.filter or "ALL"

        local query = searchBox:GetText() or ""
        query = query:lower()
        if query == "" then
            query = nil
        end

        for _, rec in ipairs(allIcons) do
            if filter == "ALL" or rec.kind == filter then
                if not query then
                    table.insert(result, rec)
                else
                    local hit = false

                    if rec.name and rec.name:find(query, 1, true) then
                        hit = true
                    end

                    if not hit and rec.fileID then
                        if tostring(rec.fileID):find(query, 1, true) then
                            hit = true
                        end
                    end

                    if not hit and rec.globalIndex then
                        if tostring(rec.globalIndex):find(query, 1, true) then
                            hit = true
                        end
                    end

                    if hit then
                        table.insert(result, rec)
                    end
                end
            end
        end

        return result
    end

    function f:Refresh()
        ClearIconButtons()

        local icons = BuildFilteredIconList()

        local cols      = 10
        local size      = 32
        local pad       = 6
        local rowHeight = size + pad

        local lastRowBottom = 0

        for i, rec in ipairs(icons) do
            local btn = NewIconButton(content)
            table.insert(f._iconButtons, btn)

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)

            local x = col * (size + pad)
            local y = -(row * (size + pad))

            btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
            btn.icon:SetTexture(rec.texture or rec.fileID or 134400)
            btn:Show()

            btn.iconInfo = rec

            btn:SetScript("OnEnter", function(self)
                if not GameTooltip then
                    return
                end

                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")

                local name  = rec.name or "?"
                local idx   = rec.globalIndex or 0
                local fid   = rec.fileID or "?"

                GameTooltip:SetText(name, 1, 1, 1)
                GameTooltip:AddLine(string.format("Index: |cffffff00%d|r", idx), 0.9, 0.9, 0.9)
                GameTooltip:AddLine(string.format("Texture ID: |cffffd200%s|r", tostring(fid)), 0.9, 0.9, 0.9)
                GameTooltip:AddLine(string.format("Kind: |cff80ff80%s|r", rec.kind or "?"), 0.9, 0.9, 0.9)
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)

            btn:SetScript("OnClick", function(self)
                f._iconSelection = self.iconInfo
            end)

            lastRowBottom = y - rowHeight
        end

        local height = math.abs(lastRowBottom) + rowHeight + pad
        content:SetHeight(math.max(height, 1))
    end

    -- Live search
    searchBox:SetScript("OnTextChanged", function()
        if f:IsShown() then
            f:Refresh()
        end
    end)

    -- Okay button applies selection
    okBtn:SetScript("OnClick", function()
        local info = f._iconSelection
        if info and type(opts.onIconChosen) == "function" then
            opts.onIconChosen(info)
        end
        f:Hide()
    end)

    -- Simple helper: open & refresh
    function f:Open()
        self._iconSelection = nil
        self:Show()
        self:Refresh()
    end

    return f
end

-----------------------------------------------------
-- Module registration
-----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Macro Browser + Icon Picker",
        class = "ui",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
