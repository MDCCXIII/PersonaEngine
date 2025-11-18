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
-- Optional LDB object (for displays like Bazooka)
-- (No LibDBIcon registration → no minimap button)
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
-- Custom free-floating status button
----------------------------------------------------

local function PersonaEngine_CreateButton()
    if PersonaEngineButton then
        return PersonaEngineButton
    end

    local cfg = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)

    -- Base size & scale from config/defaults
    btn:SetSize(32, 32)
    btn:SetScale(cfg.scale or d.scale or 1.0)

    -- Strata & level from config/defaults
    local strata = cfg.strata or d.strata or "MEDIUM"
    btn:SetFrameStrata(strata)
    local lvl = cfg.level or d.level
    if lvl then
        btn:SetFrameLevel(lvl)
    else
        local parentLevel = (btn:GetParent() and btn:GetParent():GetFrameLevel()) or 0
        btn:SetFrameLevel(parentLevel + 1)
    end

    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    -- Position restore: free-floating near top-right
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
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    ------------------------------------------------
    -- Border texture with tweakable offset
    ------------------------------------------------
    local borderFrame = CreateFrame("Frame", nil, btn)
    borderFrame:SetAllPoints(btn)

    local border = borderFrame:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local offsetX = 10.5
    local offsetY = -10.1

    border:ClearAllPoints()
    border:SetPoint("CENTER", borderFrame, "CENTER", offsetX, offsetY)
    border:SetSize(btn:GetWidth() + 22, btn:GetHeight() + 22)
    btn.border = border

    ------------------------------------------------
    -- Optional highlight
    ------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    ------------------------------------------------
    -- Drag behavior (persist position)
    ------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        PersonaEngineDB.button.point    = point
        PersonaEngineDB.button.relPoint = relPoint
        PersonaEngineDB.button.x        = xOfs
        PersonaEngineDB.button.y        = yOfs
    end)

    ------------------------------------------------
    -- Tooltip + click
    ------------------------------------------------
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        PersonaEngine_Button_OnTooltip(GameTooltip)
    end)

    btn:SetScript("OnLeave", function()
