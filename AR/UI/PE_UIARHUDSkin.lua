local MODULE = "AR HUD Skin"
-- ##################################################
-- AR/UI/PE_UIARHUDSkin.lua
-- Visual “skin” for the AR HUD.
-- All artwork, fonts, and layout live here so logic
-- in PE_UIARHUD.lua can stay clean.
-- ##################################################

-- Make sure we have the PE namespace
local PE = _G.PE
if not PE then
    -- Core didn't build PE yet; fail gracefully.
    print("|cffff0000[PersonaEngine] AR HUD Skin: PE missing at load.|r")
    return
end

-- Make sure PE.AR exists even if ARCore hasn't created it yet
PE.AR = PE.AR or {}
local AR = PE.AR

AR.HUDSkin = AR.HUDSkin or {}
local Skin = AR.HUDSkin

Skin.frames = Skin.frames or {}

------------------------------------------------------
-- Utility helpers
------------------------------------------------------

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ColorForHealth(p)
    p = Clamp01(p or 0)
    -- green -> yellow -> red
    local r, g
    if p >= 0.5 then
        -- 0.5-1.0: yellow to green
        local t = (p - 0.5) * 2
        r = 1.0
        g = 0.5 + 0.5 * t
    else
        -- 0-0.5: red to yellow
        local t = p * 2
        r = 1.0
        g = 0.0 + 0.5 * t
    end
    return r, g, 0.1
end

local function ColorForPower(data)
    local pt = data.powerType or "MANA"
    pt = string.upper(pt)

    -- Basic mapping: tweak later if you want.
    if pt == "MANA" then
        return 0.2, 0.5, 1.0
    elseif pt == "ENERGY" then
        return 1.0, 0.85, 0.1
    elseif pt == "FOCUS" then
        return 1.0, 0.5, 0.2
    elseif pt == "RAGE" or pt == "FURY" then
        return 0.9, 0.1, 0.1
    else
        -- fallback: teal
        return 0.1, 0.9, 0.7
    end
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

    if data.isCasting and data.currentCastName then
        -- Prefer showing cast info when casting
        local castLine = string.format("Cast: %s", data.currentCastName)
        if line1 then
            return castLine .. " |cFF808080•|r " .. line1
        else
            return castLine
        end
    end

    if line1 and line2 then
        return line1 .. " |cFF808080•|r " .. line2
    end

    return line1 or ""
end

------------------------------------------------------
-- Frame factory
------------------------------------------------------

local function CreateARFrame(index)
    local name = "PE_ARHUD_Frame" .. index
    local f = CreateFrame("Frame", name, UIParent)
    f.peIsARHUD = true
    f:SetSize(150, 120)
    f:Hide()

    --------------------------------------------------
    -- Central ring backing
    --------------------------------------------------
    local center = CreateFrame("Frame", nil, f)
    center:SetSize(90, 90)
    center:SetPoint("CENTER", f, "CENTER", 0, 6)
    f.center = center

    local ring = center:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints()
    ring:SetTexture("Interface\\BUTTONS\\UI-Quickslot")
    ring:SetAlpha(0.25)
    f.ring = ring

    --------------------------------------------------
    -- Left vertical bar (Health)
    --------------------------------------------------
    local healthBar = CreateFrame("StatusBar", nil, center)
    healthBar:SetSize(14, 80)
    healthBar:SetPoint("CENTER", center, "CENTER", -40, 0)
    healthBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)
    healthBar:SetOrientation("VERTICAL")
    f.healthBar = healthBar

    local healthBG = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBG:SetAllPoints()
    healthBG:SetColorTexture(0, 0, 0, 0.6)
    f.healthBG = healthBG

    --------------------------------------------------
    -- Right vertical bar (Power)
    --------------------------------------------------
    local powerBar = CreateFrame("StatusBar", nil, center)
    powerBar:SetSize(14, 80)
    powerBar:SetPoint("CENTER", center, "CENTER", 40, 0)
    powerBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
    powerBar:SetOrientation("VERTICAL")
    f.powerBar = powerBar

    local powerBG = powerBar:CreateTexture(nil, "BACKGROUND")
    powerBG:SetAllPoints()
    powerBG:SetColorTexture(0, 0, 0, 0.6)
    f.powerBG = powerBG

    --------------------------------------------------
    -- Threat glow (outer ring-ish)
    --------------------------------------------------
    local threat = center:CreateTexture(nil, "BORDER")
    threat:SetSize(110, 100)
    threat:SetPoint("CENTER", center, "CENTER", 0, 0)
    threat:SetTexture("Interface\\BUTTONS\\UI-Quickslot")
    threat:SetBlendMode("ADD")
    threat:SetAlpha(0)
    f.threatGlow = threat

    --------------------------------------------------
    -- LEFT data line: name + compact info
    --------------------------------------------------
    local leftLine = f:CreateTexture(nil, "ARTWORK")
    leftLine:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    leftLine:SetSize(90, 2)
    leftLine:SetPoint("RIGHT", center, "LEFT", -8, 20)
    f.leftLine = leftLine

    local leftElbow = f:CreateTexture(nil, "ARTWORK")
    leftElbow:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    leftElbow:SetSize(2, 18)
    leftElbow:SetPoint("TOP", leftLine, "RIGHT", 0, 0)
    f.leftElbow = leftElbow

    local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("RIGHT", leftLine, "LEFT", -4, 12)
    nameText:SetJustifyH("RIGHT")
    nameText:SetText("")
    f.nameText = nameText

    local compactText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    compactText:SetPoint("RIGHT", leftLine, "LEFT", -4, 0)
    compactText:SetJustifyH("RIGHT")
    compactText:SetText("")
    f.compactText = compactText

    --------------------------------------------------
    -- RIGHT data line: expanded / tooltip info (Alt)
    --------------------------------------------------
    local rightLine = f:CreateTexture(nil, "ARTWORK")
    rightLine:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    rightLine:SetSize(90, 2)
    rightLine:SetPoint("LEFT", center, "RIGHT", 8, 10)
    f.rightLine = rightLine

    local rightElbow = f:CreateTexture(nil, "ARTWORK")
    rightElbow:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    rightElbow:SetSize(2, 18)
    rightElbow:SetPoint("BOTTOM", rightLine, "LEFT", 0, 0)
    f.rightElbow = rightElbow

    local detailText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailText:SetPoint("LEFT", rightLine, "RIGHT", 4, 0)
    detailText:SetWidth(200)
    detailText:SetJustifyH("LEFT")
    detailText:SetWordWrap(false)
    detailText:SetText("")
    f.detailText = detailText

    return f
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

    --------------------------------------------------
    -- Health bar
    --------------------------------------------------
    local hp = Clamp01(data.hpPct or 0)
    frame.healthBar:SetValue(hp)
    local hr, hg, hb = ColorForHealth(hp)
    frame.healthBar:SetStatusBarColor(hr, hg, hb)

    --------------------------------------------------
    -- Power bar
    --------------------------------------------------
    local pp = Clamp01(data.powerPct or 0)
    frame.powerBar:SetValue(pp)
    local pr, pg, pb = ColorForPower(data)
    frame.powerBar:SetStatusBarColor(pr, pg, pb)

    --------------------------------------------------
    -- Threat glow
    --------------------------------------------------
    local threat = data.threat or 0
    if threat and threat >= 2 then
        local a = (threat == 3) and 0.8 or 0.5
        frame.threatGlow:SetVertexColor(1.0, 0.2, 0.1, a)
        frame.threatGlow:SetAlpha(a)
    else
        frame.threatGlow:SetAlpha(0)
    end

    --------------------------------------------------
    -- Name + compact info (left)
    --------------------------------------------------
    frame.nameText:SetText(data.name or "Unknown Target")
    frame.compactText:SetText(BuildCompactLine(data) or "")

    --------------------------------------------------
    -- Detail text (right) – only for target + expanded
    --------------------------------------------------
    if ctx.role == "target" and ctx.expanded then
        frame.detailText:SetText(BuildDetailText(data) or "")
        frame.rightLine:Show()
        frame.rightElbow:Show()
    else
        frame.detailText:SetText("")
        frame.rightLine:Hide()
        frame.rightElbow:Hide()
    end

    --------------------------------------------------
    -- Basic ring tint: hostile/friendly and casting
    --------------------------------------------------
    local r, g, b = 0.3, 0.8, 1.0 -- default soft cyan
    if data.hostile then
        r, g, b = 1.0, 0.2, 0.2
    elseif not data.friendly then
        r, g, b = 1.0, 0.8, 0.2
    else
        r, g, b = 0.2, 1.0, 0.4
    end

    if data.isCastingInterruptible then
        r, g, b = 1.0, 1.0, 0.2
    end

    frame.ring:SetVertexColor(r, g, b, 0.35)

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
if PE.RegisterModule then
    PE.RegisterModule("AR HUD Skin", {
        name  = "AR HUD Skin",
        class = "AR HUD",
    })
end
