-- ##################################################
-- UI/PE_UIMacroBrowser.lua
-- Popup window listing account + character macros
-- ##################################################

local MODULE = "UIMacroBrowser"
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
-- Constants (fallbacks if globals missing)
----------------------------------------------------

local MAX_ACCOUNT = _G.MAX_ACCOUNT_MACROS    or 120
local MAX_CHAR    = _G.MAX_CHARACTER_MACROS  or 18

----------------------------------------------------
-- Macro Browser
----------------------------------------------------
-- UI.CreateMacroBrowser(opts)
--   opts.parent
--   opts.onMacroClick(name, body, icon, meta { index, scope })
--   opts.title

function UI.CreateMacroBrowser(opts)
    opts = opts or {}

    local parent    = opts.parent or UIParent
    local titleText = opts.title or "PersonaEngine – Macro Picker"

    local f = CreateFrame("Frame", "PersonaEngine_MacroBrowserFrame", parent, "BasicFrameTemplateWithInset")
    f:SetSize(500, 420)
    f:SetPoint("CENTER", UIParent, "CENTER", 40, 20)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(120)
    f:Hide()

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

    ------------------------------------------------
    -- Tabs + usage text
    ------------------------------------------------

    f.currentScope = "global"
    local tabButtons = {}

    local function SetScope(scope)
        f.currentScope = scope
        for key, btn in pairs(tabButtons) do
            if key == scope then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
        if f.Refresh then
            f:Refresh()
        end
    end

    local tabGeneral = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tabGeneral:SetSize(80, 20)
    tabGeneral:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -26)
    tabGeneral:SetText("General")
    tabGeneral:SetScript("OnClick", function() SetScope("global") end)
    tabButtons.global = tabGeneral

    local tabChar = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tabChar:SetSize(120, 20)
    tabChar:SetPoint("LEFT", tabGeneral, "RIGHT", 6, 0)
    local charName = UnitName("player") or "Character"
    tabChar:SetText(charName)
    tabChar:SetScript("OnClick", function() SetScope("character") end)
    tabButtons.character = tabChar

    local usageFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    usageFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -28)
    usageFS:SetJustifyH("RIGHT")
    f.usageText = usageFS

    ------------------------------------------------
    -- Scroll grid
    ------------------------------------------------

    local scroll = CreateFrame("ScrollFrame", "PersonaEngine_MacroBrowserScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     10, -54)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30,  30)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    f._buttons = {}

    local function ClearButtons()
        for _, b in ipairs(f._buttons) do
            b:Hide()
        end
        wipe(f._buttons)
    end

    local function NewButton(parentFrame)
        local btn = CreateFrame("Button", nil, parentFrame)
        btn:SetSize(40, 40)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()

        btn.nameFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.nameFS:SetPoint("LEFT", btn, "RIGHT", 6, 0)
        btn.nameFS:SetJustifyH("LEFT")
        btn.nameFS:SetWidth(320)

        return btn
    end

    ------------------------------------------------
    -- Refresh
    ------------------------------------------------

    function f:Refresh()
        ClearButtons()

        local numGlobal, numChar = GetNumMacros()
        numGlobal = numGlobal or 0
        numChar   = numChar   or 0

        local scope = self.currentScope or "global"
        local used, maxSlots, indexStart, indexEnd

        if scope == "character" then
            used      = numChar
            maxSlots  = MAX_CHAR
            indexStart = MAX_ACCOUNT + 1
            indexEnd   = MAX_ACCOUNT + MAX_CHAR
        else
            scope      = "global"
            used       = numGlobal
            maxSlots   = MAX_ACCOUNT
            indexStart = 1
            indexEnd   = MAX_ACCOUNT
        end

        if self.usageText then
            local label = (scope == "global") and "General" or charName
            self.usageText:SetFormattedText("%s: %d/%d", label, used or 0, maxSlots or 0)
        end

        local cols      = 2
        local colWidth  = 240
        local rowHeight = 44
        local row       = 0
        local col       = 0
        local lastRowBottom = 0

        for index = indexStart, indexEnd do
            local name, iconTexture = GetMacroInfo(index)
            if name and name ~= "" then
                local btn = NewButton(content)
                table.insert(self._buttons, btn)

                col = col + 1
                if col > cols then
                    col = 1
                    row = row + 1
                elseif row == 0 then
                    row = 1
                end

                local x = (col - 1) * colWidth
                local y = -((row - 1) * rowHeight)

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
                btn.icon:SetTexture(iconTexture or 134400)
                btn.nameFS:SetText(name)

                btn.macroIndex = index
                btn.macroName  = name
                btn.scope      = scope

                btn:SetScript("OnEnter", function(selfBtn)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:SetText(name, 1, 1, 1, true)
                    local bodyText = GetMacroBody(selfBtn.macroIndex) or ""
                    if bodyText ~= "" then
                        GameTooltip:AddLine(" ", 0, 0, 0, false)
                        GameTooltip:AddLine(bodyText, 0.8, 0.8, 0.8, true)
                    end
                    GameTooltip:Show()
                end)

                btn:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)

                btn:RegisterForDrag("LeftButton")
                btn:SetScript("OnDragStart", function(selfBtn)
                    PickupMacro(selfBtn.macroIndex)
                end)
                btn:SetScript("OnDragStop", function() end)

                btn:SetScript("OnClick", function(selfBtn)
                    local bodyText = GetMacroBody(selfBtn.macroIndex) or ""
                    local tex      = selfBtn.icon:GetTexture()

                    if type(opts.onMacroClick) == "function" then
                        opts.onMacroClick(
                            selfBtn.macroName,
                            bodyText,
                            tex,
                            { index = selfBtn.macroIndex, scope = selfBtn.scope }
                        )
                    end
                    f:Hide()
                end)

                lastRowBottom = y - rowHeight
            end
        end

        local height = math.abs(lastRowBottom) + rowHeight + 6
        content:SetHeight(math.max(height, 1))
    end

    SetScope("global")

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
