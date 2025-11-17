-- ##################################################
-- PE_Cloud9_Panel.lua
-- Cloud9 Debug Panel (position / config inspector)
-- ##################################################

local MODULE = "Cloud9"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Optional namespace for programmatic access
PE.Cloud9 = PE.Cloud9 or {}
local Cloud9NS = PE.Cloud9

-- Local-only frame references (no new globals)
local cloud9Frame
local cloud9Edit

----------------------------------------------------
-- Cloud9 Debug Panel
----------------------------------------------------

function Cloud9_CreateFrame()
    -- Reuse existing frame if it already exists
    if cloud9Frame then
        cloud9Frame:Show()
        return cloud9Frame
    end

    cloud9Frame = CreateFrame("Frame", "PersonaEngine_Cloud9", UIParent, "BackdropTemplate")
    cloud9Frame:SetSize(450, 300)
    cloud9Frame:SetPoint("CENTER")
    cloud9Frame:SetMovable(true)
    cloud9Frame:EnableMouse(true)
    cloud9Frame:RegisterForDrag("LeftButton")
    cloud9Frame:SetScript("OnDragStart", cloud9Frame.StartMoving)
    cloud9Frame:SetScript("OnDragStop", cloud9Frame.StopMovingOrSizing)
    cloud9Frame:SetClampedToScreen(true)

    cloud9Frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    cloud9Frame:SetBackdropColor(0, 0, 0, 0.85)

    -- Scrollable edit box
    local scroll = CreateFrame("ScrollFrame", nil, cloud9Frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    cloud9Edit = CreateFrame("EditBox", nil, scroll)
    cloud9Edit:SetMultiLine(true)
    cloud9Edit:SetFontObject(ChatFontNormal)
    cloud9Edit:SetTextColor(1, 1, 1, 1)
    cloud9Edit:SetAutoFocus(false)
    cloud9Edit:EnableMouse(true)
    cloud9Edit:SetWidth(400)
    cloud9Edit:SetHeight(260)
    cloud9Edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scroll:SetScrollChild(cloud9Edit)

    local close = CreateFrame("Button", nil, cloud9Frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", cloud9Frame, "TOPRIGHT")

    return cloud9Frame
end

-- Also expose via namespace for internal callers, if any
Cloud9NS.CreateFrame = Cloud9_CreateFrame

----------------------------------------------------
-- Cloud9 Debug Text Formatter
----------------------------------------------------

function Cloud9_DebugDump()
    local db = rawget(_G, "PersonaEngineDB")
    local b  = (db and db.button) or {}
    local d  = _G.PersonaEngine_ButtonDefaults or {}
    local btn = _G.PersonaEngineButton

    local out = {}

    local function add(...)
        local t = {}
        local n = select("#", ...)
        for i = 1, n do
            t[i] = tostring(select(i, ...))
        end
        table.insert(out, table.concat(t, " ") .. "\n")
    end

    add("===== Persona Engine Debug: Cloud9 =====\n")

    add("Saved Config (PersonaEngineDB.button):")
    add("  point:",   b.point)
    add("  relPoint:", b.relPoint)
    add("  x:",       b.x, " y:", b.y)
    add("  scale:",   b.scale)
    add("  strata:",  b.strata)
    add("  level:",   b.level, "\n")

    add("Default Config (PersonaEngine_ButtonDefaults):")
    add("  point:",   d.point)
    add("  relPoint:", d.relPoint)
    add("  x:",       d.x, " y:", d.y)
    add("  scale:",   d.scale)
    add("  strata:",  d.strata)
    add("  level:",   d.level, "\n")

    if btn then
        local p, rt, rp, x, y = btn:GetPoint()
        add("Live Frame:")
        add("  frame point:",     p)
        add("  frame relPoint:",  rp)
        add("  frame anchor:",    rt and rt:GetName() or tostring(rt))
        add("  frame x:",         x, " frame y:", y)
        add("  frame strata:",    btn:GetFrameStrata())
        add("  frame level :",    btn:GetFrameLevel())
        add("  frame scale :",    btn:GetScale())
    else
        add("Live Frame: NOT CREATED")
    end

    add("\n===== End =====")

    return table.concat(out)
end

Cloud9NS.DebugDump = Cloud9_DebugDump

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Cloud9", {
        name  = "Cloud9 Debug Panel",
        class = "ui",
    })
end
