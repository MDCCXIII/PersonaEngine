-- ##################################################
-- AR/UI/PE_UIARHUD.lua
-- Visual AR HUD renderer (rings, lines, etc.)
-- ##################################################

local PE = PE
local AR = PE and PE.AR
if not AR then return end

AR.HUD = AR.HUD or {}
local HUD = AR.HUD

local frames = {}

function HUD.Init()
    -- Create a small pool of frames that can be anchored to nameplates
    for i = 1, 5 do
        local f = CreateFrame("Frame", "PE_ARHUD_Frame"..i, UIParent)
        f:Hide()
        frames[i] = f
        -- TODO: add ring textures + fontstrings here
    end

    -- Poll or event-driven updates:
    AR.RegisterEvent("PLAYER_TARGET_CHANGED")
    AR.RegisterEvent("NAME_PLATE_UNIT_ADDED")
    AR.RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

function HUD.OnEvent(event, ...)
    -- For now just trigger a refresh
    HUD.Refresh(event, ...)
end

function HUD.HideAll()
    for _, f in ipairs(frames) do
        f:Hide()
    end
end

function HUD.Refresh(reason)
    if not AR.IsEnabled() then
        HUD.HideAll()
        return
    end

    local snapshot = AR.GetCurrentSnapshot()
    if not snapshot or #snapshot == 0 then
        HUD.HideAll()
        return
    end

    -- Simple: only display top N entries, later add overlap tests, compact/expanded logic
    for i, entry in ipairs(snapshot) do
        local f = frames[i]
        if not f then break end

        local plate = C_NamePlate.GetNamePlateForUnit(entry.unit)
        if plate then
            f:SetParent(plate)
            f:SetAllPoints(plate)
            f:Show()

            -- TODO: color ring based on entry.data.hostile/friendly/etc.
            -- TODO: set text based on compact / expanded mode
        else
            f:Hide()
        end
    end

    -- Hide any unused frames
    for i = #snapshot + 1, #frames do
        frames[i]:Hide()
    end
end
