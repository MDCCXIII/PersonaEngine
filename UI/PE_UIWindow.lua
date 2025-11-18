-- ##################################################
-- UI/PE_UIWindow.lua
-- Generic window widget (moveable, resizable, persistent)
-- ##################################################

local MODULE = "UIWindow"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

PE.UI = PE.UI or {}
local UI = PE.UI

local DB_ROOT_KEY = "UIWindows"

local function GetWindowStore(id)
    PersonaEngineDB = PersonaEngineDB or {}
    PersonaEngineDB[DB_ROOT_KEY] = PersonaEngineDB[DB_ROOT_KEY] or {}
    PersonaEngineDB[DB_ROOT_KEY][id] = PersonaEngineDB[DB_ROOT_KEY][id] or {}
    return PersonaEngineDB[DB_ROOT_KEY][id]
end

local function SaveGeometry(frame)
    if not frame or not frame._uiWindowId then return end
    if not frame:GetPoint(1) then return end

    local store = GetWindowStore(frame._uiWindowId)

    local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
    store.point    = point
    store.relPoint = relPoint
    store.x        = xOfs
    store.y        = yOfs

    local w, h = frame:GetSize()
    store.width  = w
    store.height = h
end

local function RestoreGeometry(frame)
    if not frame or not frame._uiWindowId then return end
    local storeRoot = PersonaEngineDB and PersonaEngineDB[DB_ROOT_KEY]
    local store = storeRoot and storeRoot[frame._uiWindowId]
    if not store then return end

    if store.width and store.height then
        frame:SetSize(store.width, store.height)
    end

    if store.point and store.relPoint and store.x and store.y then
        frame:ClearAllPoints()
        frame:SetPoint(store.point, UIParent, store.relPoint, store.x, store.y)
    end
end

-- spec fields:
-- id        (string, required)  unique logical ID (e.g. "Config")
-- title     (string)            window title text
-- width     (number)            default width
-- height    (number)            default height
-- minWidth  (number)
-- minHeight (number)
-- strata    (string)            e.g. "DIALOG"
-- level     (number)
-- template  (string)            frame template (default BasicFrameTemplateWithInset)
-- point     (table)             { point, relFrame, relPoint, x, y }
function UI.CreateWindow(spec)
    assert(type(spec) == "table" and spec.id, "UI.CreateWindow: spec.id is required")

    local id       = spec.id
    local frameName = "PersonaEngine_" .. id .. "Frame"
    local template = spec.template or "BasicFrameTemplateWithInset"

    local f = CreateFrame("Frame", frameName, UIParent, template)
    f._uiWindowId = id

    local defaultW = spec.width  or 460
    local defaultH = spec.height or 430

    f:SetSize(defaultW, defaultH)

    if spec.point then
        -- { point, relativeTo, relativePoint, xOfs, yOfs }
        f:SetPoint(unpack(spec.point))
    else
        f:SetPoint("CENTER")
    end

    f:SetFrameStrata(spec.strata or "DIALOG")
    f:SetFrameLevel(spec.level or 100)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetResizable(true)

    local minW = spec.minWidth  or 360
    local minH = spec.minHeight or 260

    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, spec.maxWidth or 1200, spec.maxHeight or 900)
    end

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveGeometry(self)
    end)

    f:SetScript("OnSizeChanged", function(self, width, height)
        -- clamp for older clients
        if width < minW or height < minH then
            width  = math.max(width,  minW)
            height = math.max(height, minH)
            self:SetSize(width, height)
        end
        SaveGeometry(self)
    end)

    f:SetScript("OnShow", function(self)
        if not self._geometryRestored then
            self._geometryRestored = true
            RestoreGeometry(self)
        end
    end)

    -- Title
    local titleText = (spec.title or id)
    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if f.TitleBg then
        titleFS:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
    else
        titleFS:SetPoint("TOPLEFT", 10, -5)
    end
    titleFS:SetText(titleText)
    f.title = titleFS

    -- Resize handle
    local resizeButton = CreateFrame("Button", nil, f)
    resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeButton:SetSize(16, 16)

    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
            local hl = self:GetHighlightTexture()
            if hl then hl:Show() end
        end
    end)

    resizeButton:SetScript("OnMouseUp", function(self)
        f:StopMovingOrSizing()
        local hl = self:GetHighlightTexture()
        if hl then hl:Hide() end
        SaveGeometry(f)
    end)

    f:Hide()
    return f
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Window",
        class = "ui",
    })
end
