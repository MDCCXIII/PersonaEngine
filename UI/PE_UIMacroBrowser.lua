-- ##################################################
-- UI/PE_UIMacroBrowser.lua
-- Popup window listing all macros with icons
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

----------------------------------------------------
-- Macro Browser widget
----------------------------------------------------
-- UI.CreateMacroBrowser(opts) -> frame
--   opts.parent        : parent frame (default UIParent)
--   opts.onMacroClick  : function(name, body, icon) called on left-click
--   opts.title         : window title (optional)

function UI.CreateMacroBrowser(opts)
    opts = opts or {}

    local parent = opts.parent or UIParent
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

    -- Close / minimize button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- Explicit Minimize button (alternative to clicking an icon)
    local miniBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    miniBtn:SetSize(80, 20)
    miniBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    miniBtn:SetText("Hide")
    miniBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    ------------------------------------------------
    -- Scrollable icon grid
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

        local cols = 2
        local padX = 8
        local padY = 6

        local colWidth = 240
        local rowHeight = 44

        local row = 0
        local col = 0

        local lastRowBottom = 0

        for index = 1, total do
            local name, iconTexture, body, isLocal, isChar = GetMacroInfo(index)
            if name and name ~= "" then
                local btn = NewButton(content)
                table.insert(f._buttons, btn)

                col = (col + 1)
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
                btn.nameFS:SetText(string.format("%s%s", name, isChar and " |cffaaaaaa(Char)|r" or ""))

                btn.macroIndex = index
                btn.macroName = name

                btn:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
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
                    -- Nothing fancy; cursor logic stays with Blizzard.
                end)

                btn:SetScript("OnClick", function(self)
                    local bodyText = GetMacroBody(self.macroIndex) or ""
                    local tex = self.icon:GetTexture()
                    if type(opts.onMacroClick) == "function" then
                        opts.onMacroClick(self.macroName, bodyText, tex)
                    end
                    -- Clicking a macro hides the popup (per spec)
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

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Macro Browser",
        class = "ui",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
