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
local MAX_FRAMES = 5

------------------------------------------------------
-- Frame factory
------------------------------------------------------

local function CreateARFrame(index)
    local name = "PE_ARHUD_Frame" .. index
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(140, 40)
    f:Hide()

    -- Simple “ring” texture approximating a cyber overlay.
    local ring = f:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture("Interface\\BUTTONS\\UI-Quickslot") -- placeholder ring
    ring:SetAlpha(0.35)
    f.ring = ring

    -- Header above the ring (name)
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetPoint("BOTTOM", f, "TOP", 0, 2)
    header:SetJustifyH("CENTER")
    header:SetText("")
    f.header = header

    -- Subline below (compact info) – visible in both modes
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", f, "BOTTOM", 0, -2)
    sub:SetJustifyH("CENTER")
    sub:SetText("")
    f.sub = sub

    -- Extra detail line (only in expanded mode, mostly for your target)
    local detail = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detail:SetPoint("TOP", sub, "BOTTOM", 0, -2)
    detail:SetJustifyH("CENTER")
    detail:SetText("")
    f.detail = detail

    return f
end

------------------------------------------------------
-- Helpers
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
        -- Slight boost for the main target
        g = math.min(1, g + 0.2)
        b = math.min(1, b + 0.2)
    end

    if data.isBoss then
        r, g, b = 1.0, 0.4, 1.0
    elseif data.isElite then
        r, g, b = 1.0, 0.6, 0.3
    end

    if data.isCastingInterruptible then
        -- Interruptible cast: go “warning” yellow
        r, g, b = 1.0, 1.0, 0.2
    end

    return r, g, b
end

local function BuildCompactLine(data)
    -- Quick descriptor for compact mode
    if data.isPlayer then
        local level = data.level or "??"
        local faction = data.faction or ""
        return string.format("Lv%s %s", level, faction)
    end

    local level = data.level or "??"
    local creature = data.creature or ""
    if data.isBoss then
        return string.format("Boss • Lv%s %s", level, creature)
    elseif data.isElite then
        return string.format("Elite • Lv%s %s", level, creature)
    else
        return string.format("Lv%s %s", level, creature)
    end
end

local function GetDetailLines(data)
    local tooltip = data.tooltip
    if not tooltip then
        return nil, nil
    end

    local line1 = tooltip.subHeader or tooltip.lines[1]
    local line2 = tooltip.lines and tooltip.lines[2] or nil

    return line1, line2
end

------------------------------------------------------
-- HUD lifecycle
------------------------------------------------------

function HUD.Init()
    -- Create a small pool of frames that can be anchored to nameplates
    for i = 1, MAX_FRAMES do
        frames[i] = CreateARFrame(i)
    end

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

    local expanded = AR.IsExpanded()

    -- Simple rule for now:
    --  * snapshot[1] is the primary (usually your target)
    --  * Up to MAX_FRAMES entries shown
    for i, entry in ipairs(snapshot) do
        if i > MAX_FRAMES then break end

        local f = frames[i]
        local data = entry.data
        local isPrimary = (i == 1)

        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(entry.unit)
        if plate and data then
            f:SetParent(plate)
            f:SetAllPoints(plate)
            f:Show()

            -- Color the ring
            local r, g, b = GetBaseColor(data, isPrimary)
            f.ring:SetVertexColor(r, g, b, 0.8)

            -- Text: header is always just tooltip header or name
            local tooltip = data.tooltip
            local headerText = (tooltip and tooltip.header) or data.name or "Unknown Target"
            f.header:SetText(headerText)

            -- Sub line: compact descriptor
            f.sub:SetText(BuildCompactLine(data) or "")

            -- Detail line(s) only in expanded view,
            -- and primarily for your main target so it doesn’t get too noisy.
            if expanded and isPrimary then
                local d1, d2 = GetDetailLines(data)
                if d1 and d2 then
                    f.detail:SetText(d1 .. " |cFF808080•|r " .. d2)
                elseif d1 then
                    f.detail:SetText(d1)
                else
                    f.detail:SetText("")
                end
            else
                f.detail:SetText("")
            end
        else
            f:Hide()
        end
    end

    -- Hide any unused frames
    local count = math.min(#snapshot, MAX_FRAMES)
    for i = count + 1, MAX_FRAMES do
        frames[i]:Hide()
    end
end
