-- ##################################################
-- AR/UI/PE_UIARHUD.lua
-- Visual AR HUD renderer (rings, lines, etc.)
-- Hides Blizzard nameplate visuals while keeping
-- the underlying frames alive for anchoring.
-- Shows HUD ONLY for target and mouseover.
-- ##################################################

local PE = PE
local AR = PE and PE.AR
if not AR then return end

AR.HUD = AR.HUD or {}
local HUD = AR.HUD

local frames = {}
local MAX_FRAMES = 2 -- target + mouseover max

-- Set this to false if you ever want Blizzard nameplates visible again.
local HIDE_BASE_NAMEPLATES = true

------------------------------------------------------
-- Frame factory
------------------------------------------------------

local function CreateARFrame(index)
    local name = "PE_ARHUD_Frame" .. index
    local f = CreateFrame("Frame", name, UIParent)
    f.peIsARHUD = true -- mark so we don't hide ourselves
    f:SetSize(140, 40)
    f:Hide()

    -- Simple “ring” texture approximating a cyber overlay.
    -- You can later swap this to a custom texture in Media/.
    local ring = f:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture("Interface\\BUTTONS\\UI-Quickslot")
    ring:SetAlpha(0.4)
    f.ring = ring

    -- Header above the ring (name)
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetPoint("BOTTOM", f, "TOP", 0, 2)
    header:SetJustifyH("CENTER")
    header:SetText("")
    f.header = header

    -- Subline below (level / type)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", f, "BOTTOM", 0, -2)
    sub:SetJustifyH("CENTER")
    sub:SetText("")
    f.sub = sub

    return f
end

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
-- Small helpers for AR look
------------------------------------------------------

local function GetBaseColor(data, isPrimary)
    -- Friendly / neutral / hostile coloring
    local r, g, b = 0.3, 0.8, 1.0 -- default: soft cyan

    if data.hostile then
        r, g, b = 1.0, 0.2, 0.2
    elseif not data.friendly then
        r, g, b = 1.0, 0.8, 0.2
    else
        r, g, b = 0.2, 1.0, 0.4
    end

    if isPrimary then
        g = math.min(1, g + 0.2)
        b = math.min(1, b + 0.2)
    end

    return r, g, b
end

local function BuildCompactLine(data)
    local level = data.level or "??"

    if data.isPlayer then
        return string.format("Lv%s Player", level)
    end

    local creature = data.creature or ""
    return string.format("Lv%s %s", level, creature)
end

------------------------------------------------------
-- HUD lifecycle
------------------------------------------------------

function HUD.Init()
    -- Create frames for target + mouseover
    for i = 1, MAX_FRAMES do
        frames[i] = CreateARFrame(i)
    end

    -- Ensure any existing plates are stripped when we log in / reload
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
    for _, f in ipairs(frames) do
        f:Hide()
    end
end

------------------------------------------------------
-- Main refresh
------------------------------------------------------

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

    -- Draw them: frame1 = target, frame2 = mouseover
    for i = 1, MAX_FRAMES do
        local f = frames[i]
        local entry = ordered[i]
        if f and entry then
            local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(entry.unit)
            local data  = entry.data
            if plate and data then
                HideBasePlateVisuals(plate)

                f:SetParent(plate)
                f:SetAllPoints(plate)
                f:Show()

                local r, g, b = GetBaseColor(data, i == 1)
                f.ring:SetVertexColor(r, g, b, 0.9)

                f.header:SetText(data.name or "Unknown Target")
                f.sub:SetText(BuildCompactLine(data) or "")
            else
                f:Hide()
            end
        elseif f then
            f:Hide()
        end
    end
end
