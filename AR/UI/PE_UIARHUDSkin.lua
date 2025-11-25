-- ##################################################
-- AR/UI/PE_UIARHUDSkin.lua
-- Visual “skin” for the AR HUD.
-- All artwork, fonts, and layout live here so logic
-- can stay clean in PE_UIARHUD.lua.
-- ##################################################
local MODULE = "AR HUD Skin"
local PE = PE
local AR = PE and PE.AR
if not AR then return end

AR.HUDSkin = AR.HUDSkin or {}
local Skin = AR.HUDSkin

Skin.frames = Skin.frames or {}

------------------------------------------------------
-- Helpers
------------------------------------------------------

local function CreateARFrame(index)
    local name = "PE_ARHUD_Frame" .. index
    local f = CreateFrame("Frame", name, UIParent)
    f.peIsARHUD = true -- mark so plate-hiding logic ignores us
    f:SetSize(140, 40)
    f:Hide()

    -- === RING TEXTURE ===
    -- This is the main thing you’ll swap later to a custom cyber bracket.
    local ring = f:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture("Interface\\BUTTONS\\UI-Quickslot") -- placeholder
    ring:SetAlpha(0.4)
    f.ring = ring

    -- === HEADER (name) ===
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetPoint("BOTTOM", f, "TOP", 0, 2)
    header:SetJustifyH("CENTER")
    header:SetText("")
    f.header = header

    -- === SUBLINE (level / type) ===
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", f, "BOTTOM", 0, -2)
    sub:SetJustifyH("CENTER")
    sub:SetText("")
    f.sub = sub

    -- === DETAIL (Alt-expanded info for target) ===
    local detail = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detail:SetPoint("TOP", sub, "BOTTOM", 0, -2)
    detail:SetJustifyH("CENTER")
    detail:SetText("")
    f.detail = detail

    return f
end

local function GetBaseColor(data, ctx)
    local isPrimary = ctx.isPrimary
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

local function BuildDetailText(data)
    local tt = data.tooltip
    if not tt then
        return ""
    end

    local line1 = tt.subHeader
    if not line1 and tt.lines and tt.lines[1] then
        line1 = tt.lines[1]
    end

    local line2 = tt.lines and tt.lines[2] or nil

    if line1 and line2 then
        return line1 .. " |cFF808080•|r " .. line2
    end

    return line1 or ""
end

------------------------------------------------------
-- Public Skin API
------------------------------------------------------

function Skin.GetFrame(index)
    if not Skin.frames[index] then
        Skin.frames[index] = CreateARFrame(index)
    end
    return Skin.frames[index]
end

-- ctx = {
--   role      = "target" | "mouseover",
--   isPrimary = boolean,
--   expanded  = boolean (Alt, and only for target)
-- }
function Skin.Apply(frame, plate, entry, ctx)
    local data = entry.data
    if not frame or not plate or not data then
        return
    end

    frame:SetParent(plate)
    frame:SetAllPoints(plate)

    -- Colors
    local r, g, b = GetBaseColor(data, ctx)
    frame.ring:SetVertexColor(r, g, b, 0.9)

    -- Texts
    frame.header:SetText(data.name or "Unknown Target")
    frame.sub:SetText(BuildCompactLine(data) or "")

    if ctx.role == "target" and ctx.expanded then
        frame.detail:SetText(BuildDetailText(data))
    else
        frame.detail:SetText("")
    end

    frame:Show()
end

function Skin.Hide(frame)
    if frame then
        frame:Hide()
    end
end

function Skin.HideAll()
    for _, f in pairs(Skin.frames) do
        f:Hide()
    end
end


PE.LogInit(MODULE)
PE.RegisterModule("AR HUD Skin", {
    name  = "AR HUD Skin",
    class = "AR HUD",
})