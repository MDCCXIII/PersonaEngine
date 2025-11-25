-- ##################################################
-- AR/UI/PE_UIARHUD.lua
-- AR HUD logic: decides *who* gets a HUD and *when*.
-- All visuals delegated to AR.HUDSkin.
-- ##################################################
local MODULE = "AR HUD"
local PE = _G.PE
local AR = PE and PE.AR
if not AR then return end

AR.HUD = AR.HUD or {}
local HUD = AR.HUD

local Skin = AR.HUDSkin -- may be nil if skin file not loaded
local MAX_FRAMES = 2    -- target + mouseover max

-- Set this to false if you ever want Blizzard nameplates visible again.
local HIDE_BASE_NAMEPLATES = true

------------------------------------------------------
-- Nameplate hiding helpers
------------------------------------------------------

local function HideBasePlateVisuals(plate)
    if not HIDE_BASE_NAMEPLATES or not plate then
        return
    end

    -- Try the default UnitFrame first (Dragonflight/Retail)
    local uf = plate.UnitFrame or plate.unitFrame
    if uf and uf.SetAlpha then
        uf:SetAlpha(0)
    end

    -- Hide any direct regions on the plate that aren't AR HUD bits
    local regions = { plate:GetRegions() }
    for _, region in ipairs(regions) do
        if region and not region.peIsARHUD and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    -- Hide direct child frames that aren't AR HUD frames
    local numChildren = plate:GetNumChildren()
    for i = 1, numChildren do
        local child = select(i, plate:GetChildren())
        if child and not child.peIsARHUD and child.SetAlpha then
            child:SetAlpha(0)
        end
    end
end

local function ApplyHideAllBaseNameplates()
    if not HIDE_BASE_NAMEPLATES or not C_NamePlate or not C_NamePlate.GetNamePlates then
        return
    end

    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in ipairs(plates) do
        HideBasePlateVisuals(plate)
    end
end

------------------------------------------------------
-- HUD lifecycle
------------------------------------------------------

function HUD.Init()
    -- Nothing to create here; frames come from HUDSkin
    ApplyHideAllBaseNameplates()

    -- Event-driven updates
    AR.RegisterEvent("PLAYER_TARGET_CHANGED")
    AR.RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    AR.RegisterEvent("NAME_PLATE_UNIT_ADDED")
    AR.RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

function HUD.OnEvent(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
        HideBasePlateVisuals(plate)
    end

    HUD.Refresh(event, ...)
end

function HUD.HideAll()
    if Skin and Skin.HideAll then
        Skin.HideAll()
    end
end

------------------------------------------------------
-- Main refresh
------------------------------------------------------

function HUD.Refresh(reason)
    if not AR.IsEnabled() or not Skin or not Skin.GetFrame then
        HUD.HideAll()
        return
    end

    local snapshot = AR.GetCurrentSnapshot()
    if not snapshot or #snapshot == 0 then
        HUD.HideAll()
        return
    end

    local expanded = AR.IsExpanded and AR.IsExpanded()

    -- Pick out just target and mouseover entries.
    local targetEntry, mouseEntry

    for _, entry in ipairs(snapshot) do
        local data = entry.data
        if data then
            if data.isTarget and not targetEntry then
                targetEntry = entry
            elseif data.isMouseover and not mouseEntry and not data.isTarget then
                -- avoid double-using same unit if mouseover == target
                mouseEntry = entry
            end
        end
    end

    local ordered = {}
    if targetEntry then table.insert(ordered, targetEntry) end
    if mouseEntry then table.insert(ordered, mouseEntry) end

    -- frame1 = target, frame2 = mouseover
    for i = 1, MAX_FRAMES do
        local entry = ordered[i]
        local frame = Skin.GetFrame(i)

        if entry and frame then
            local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(entry.unit)
            local data  = entry.data
            if plate and data then
                HideBasePlateVisuals(plate)

                local role = (i == 1) and "target" or "mouseover"
                local ctx = {
                    role      = role,
                    isPrimary = (i == 1),
                    expanded  = (role == "target") and expanded,
                }

                Skin.Apply(frame, plate, entry, ctx)
            else
                Skin.Hide(frame)
            end
        elseif frame then
            Skin.Hide(frame)
        end
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("AR HUD", {
    name  = "AR HUD",
    class = "AR HUD",
})