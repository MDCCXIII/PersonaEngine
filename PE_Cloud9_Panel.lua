local MODULE = "Cloud9"
PE.LogLoad(MODULE)


------------------------------------------------------------
-- Cloud9 Debug Panel
------------------------------------------------------------
cloud9Frame = cloud9Frame or nil
cloud9Edit  = cloud9Edit  or nil

function Cloud9_CreateFrame()
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
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 }
    })
    cloud9Frame:SetBackdropColor(0, 0, 0, 0.85)

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

------------------------------------------------------------
-- Cloud9 Debug Text Formatter
------------------------------------------------------------
function Cloud9_DebugDump()
    local b   = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}
    local btn = PersonaEngineButton

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
    add(" point:",    b.point)
    add(" relPoint:", b.relPoint)
    add(" x:",        b.x, " y:", b.y)
    add(" scale:",    b.scale)
    add(" strata:",   b.strata)
    add(" level:",    b.level, "\n")

    add("Default Config (PersonaEngine_ButtonDefaults):")
    add(" point:",    d.point)
    add(" relPoint:", d.relPoint)
    add(" x:",        d.x, " y:", d.y)
    add(" scale:",    d.scale)
    add(" strata:",   d.strata)
    add(" level:",    d.level, "\n")

    if btn then
        local p, rt, rp, x, y = btn:GetPoint()
        add("Live Frame:")
        add(" frame point:",    p)
        add(" frame relPoint:", rp)
        add(" frame anchor:",   rt and rt:GetName() or tostring(rt))
        add(" frame x:",        x, " frame y:", y)
        add(" frame strata:",   btn:GetFrameStrata())
        add(" frame level :",   btn:GetFrameLevel())
        add(" frame scale :",   btn:GetScale())
    else
        add("Live Frame: NOT CREATED")
    end

    add("\n===== End =====")

    return table.concat(out)
end

PE.LogInit(MODULE)
PE.RegisterModule("Cloud9", {
    name  = "Cloud9 Debug Panel",
    class = "ui",
})
