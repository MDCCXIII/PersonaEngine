-- ##################################################
-- PE_Icon.lua
-- Free-floating status button (no minimap LibDBIcon)
-- ##################################################

local MODULE = "Icon"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if not PersonaEngineDB or type(PersonaEngineDB) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PersonaEngineDB missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Optional LDB object (no minimap icon)
----------------------------------------------------

local LDB
if LibStub then
    LDB = LibStub("LibDataBroker-1.1", true)
end

if LDB then
    LDB:NewDataObject("PersonaEngine", {
        type = "data source",
        text = "Persona Engine",
        icon = "Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga",

        OnClick = function(frame, button)
            if _G.PersonaEngine_Button_OnClick then
                _G.PersonaEngine_Button_OnClick(frame, button)
            end
        end,

        OnTooltipShow = function(tt)
            if _G.PersonaEngine_Button_OnTooltip then
                _G.PersonaEngine_Button_OnTooltip(tt)
            end
        end,
    })
end

----------------------------------------------------
-- Free-floating status button
----------------------------------------------------

local function PersonaEngine_CreateButton()
    if PersonaEngineButton then
        return PersonaEngineButton
    end

    local cfg = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)
    btn:SetSize(32, 32)
    btn:SetScale(cfg.scale or d.scale or 1.2)

    btn:SetFrameStrata(cfg.strata or d.strata or "MEDIUM")
    btn:SetFrameLevel((cfg.level or d.level or 1))

    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    btn:SetPoint(
        cfg.point or d.point or "TOPRIGHT",
        UIParent,
        cfg.relPoint or d.relPoint or "TOPRIGHT",
        cfg.x or d.x or -150,
        cfg.y or d.y or -170
    )

    ------------------------------------------------
    -- Icon texture
    ------------------------------------------------
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    ------------------------------------------------
    -- Border texture
    ------------------------------------------------
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("CENTER", 10.5, -10.1)
    border:SetSize(54, 54)
    btn.border = border

    ------------------------------------------------
    -- Highlight
    ------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    ------------------------------------------------
    -- Drag-save
    ------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PersonaEngineDB.button.point    = point
        PersonaEngineDB.button.relPoint = relPoint
        PersonaEngineDB.button.x        = x
        PersonaEngineDB.button.y        = y
    end)

    ------------------------------------------------
    -- Tooltip + click
    ------------------------------------------------
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        PersonaEngine_Button_OnTooltip(GameTooltip)
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", PersonaEngine_Button_OnClick)

    return btn
end

-- Delay spawn so globals are ready
if C_Timer and C_Timer.After then
    C_Timer.After(0.1, PersonaEngine_CreateButton)
else
    PersonaEngine_CreateButton()
end

----------------------------------------------------
-- Click Handler
----------------------------------------------------

function PersonaEngine_Button_OnClick(self, button)
    if button == "LeftButton" then
        if PE.ToggleConfig then
            PE.ToggleConfig()
        end
        return
    end

    if button == "RightButton" then
        local old = SR_On
        SR_On = (old == 1 and 0 or 1)

        if SR_On == 1 then
            SendChatMessage("Speech module online!", "SAY")
        else
            SendChatMessage("Speech module offline.", "SAY")
        end
        return
    end
end

----------------------------------------------------
-- Tooltip
----------------------------------------------------

function PersonaEngine_Button_OnTooltip(tt)
    tt:ClearLines()
    tt:AddLine("Persona Engine", 1, 1, 1)
    tt:AddLine(" ")
    tt:AddLine("Left-click: Open Config", 0.8, 0.8, 0.8)
    tt:AddLine("Right-click: Toggle Speech", 0.8, 0.8, 0.8)
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Icon", {
        name  = "Free-floating Icon",
        class = "ui",
    })
end
