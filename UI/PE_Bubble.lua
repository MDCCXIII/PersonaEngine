-- ##################################################
-- UI\PE_Bubble.lua
-- PersonaEngine on-screen "speech bubble"
-- ##################################################

local MODULE = "Bubble"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

PE.Bubble = PE.Bubble or {}
local Bubble = PE.Bubble

-- --------------------------------------------------
-- Defaults (can be overridden by DB settings)
-- --------------------------------------------------
local DEFAULTS = {
    enabled   = true,
    maxWidth  = 260,
    padding   = 12,
    -- Position is relative to UIParent bottom-left
    offsetX   = 500,
    offsetY   = 350,
    bgColor   = { 1, 1, 1, 0.8 },  -- white, slightly transparent
    textColor = { 0, 0, 0, 1.0 },  -- black text
}

local frame, textFS, tailTex
local isConfigMode = false

-- Small helper to get settings table safely
local function GetSettings()
    PE.db = PE.db or PersonaEngineDB or {}
    PE.db.settings = PE.db.settings or {}
    PE.db.settings.bubble = PE.db.settings.bubble or {}

    local s = PE.db.settings.bubble

    -- Fill missing fields with defaults (non-destructive)
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for i, x in ipairs(v) do copy[i] = x end
                s[k] = copy
            else
                s[k] = v
            end
        end
    end

    return s
end

-- --------------------------------------------------
-- Frame creation
-- --------------------------------------------------
local function CreateBubbleFrame()
    if frame then return end

    local settings = GetSettings()
    local parent = UIParent

    frame = CreateFrame("Frame", "PE_PersonaBubbleFrame", parent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:SetMovable(true)

    -- Simple rounded-ish bubble using tooltip background/border.
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    local bgR, bgG, bgB, bgA = unpack(settings.bgColor)
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    -- Anchor relative to UIParent using saved offsets
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", settings.offsetX, settings.offsetY)

    -- Tail texture (little rectangle standing in for a tail);
    -- you can swap this out for custom art later.
    tailTex = frame:CreateTexture(nil, "BACKGROUND")
    tailTex:SetTexture("Interface\\CHATFRAME\\ChatFrameBackground")
    tailTex:SetWidth(18)
    tailTex:SetHeight(18)
    tailTex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, -8)
    tailTex:SetVertexColor(bgR, bgG, bgB, bgA)

    -- Text
    textFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    textFS:SetJustifyH("LEFT")
    textFS:SetJustifyV("TOP")

    local txtR, txtG, txtB, txtA = unpack(settings.textColor)
    textFS:SetTextColor(txtR, txtG, txtB, txtA)

    textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", settings.padding, -settings.padding)
    textFS:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -settings.padding, -settings.padding)
    textFS:SetWordWrap(true)

    -- Dragging: only active in config mode
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if isConfigMode then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        if not isConfigMode then return end
        self:StopMovingOrSizing()

        -- Save position relative to UIParent
        local settings = GetSettings()
        local parent = UIParent
        local scale = self:GetEffectiveScale() / parent:GetEffectiveScale()

        local left   = self:GetLeft() * scale
        local bottom = self:GetBottom() * scale
        local pLeft  = parent:GetLeft() * scale
        local pBottom= parent:GetBottom() * scale

        settings.offsetX = left - pLeft
        settings.offsetY = bottom - pBottom

        Bubble.Reanchor()
    end)

    frame:Hide()
end

-- --------------------------------------------------
-- Internal: Resize to current text
-- --------------------------------------------------
local function ResizeToText()
    if not frame or not textFS then return end
    local settings = GetSettings()

    frame:SetWidth(settings.maxWidth)
    textFS:SetWidth(settings.maxWidth - settings.padding * 2)

    local h = textFS:GetStringHeight()
    frame:SetHeight(h + settings.padding * 2)

    if tailTex then
        tailTex:ClearAllPoints()
        tailTex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, -8)
    end
end

-- --------------------------------------------------
-- Public API
-- --------------------------------------------------

function Bubble.RefreshAppearance()
    if not frame then return end
    local settings = GetSettings()

    local bgR, bgG, bgB, bgA = unpack(settings.bgColor)
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    if tailTex then
        tailTex:SetVertexColor(bgR, bgG, bgB, bgA)
    end

    local txtR, txtG, txtB, txtA = unpack(settings.textColor)
    textFS:SetTextColor(txtR, txtG, txtB, txtA)
end

function Bubble.Reanchor()
    if not frame then return end
    local settings = GetSettings()
    local parent = UIParent

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT",
        settings.offsetX or DEFAULTS.offsetX,
        settings.offsetY or DEFAULTS.offsetY)
end

-- Main entry: show a line of persona text in the bubble
function Bubble.Say(text)
    local settings = GetSettings()
    if not settings.enabled then
        if frame then frame:Hide() end
        return
    end

    if isConfigMode then
        -- Don’t stomp over the config preview
        return
    end

    if not frame then
        CreateBubbleFrame()
    end

    if not text or text == "" then
        frame:Hide()
        return
    end

    textFS:SetText(text)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()
    frame:Show()
end

-- Enable/disable from settings UI
function Bubble.SetEnabled(isEnabled)
    local settings = GetSettings()
    settings.enabled = not not isEnabled
    if not settings.enabled and frame then
        frame:Hide()
    end
end

-- --------------------------------------------------
-- Config Preview: /pebubble
-- --------------------------------------------------

function Bubble.ShowConfigPreview()
    local settings = GetSettings()

    if not frame then
        CreateBubbleFrame()
    end

    isConfigMode = true
    frame:EnableMouse(true)

    textFS:SetText("PersonaEngine Bubble\n\nDrag me where you want me.")
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()
    frame:Show()

    print("|cff00ff00[PersonaEngine]|r Bubble config mode: drag the bubble, then release to save position.")
end

-- Slash command: /pebubble
SLASH_PEBUBBLE1 = "/pebubble"
SlashCmdList.PEBUBBLE = function(msg)
    if msg and msg:lower() == "off" then
        isConfigMode = false
        if frame then
            frame:EnableMouse(false)
        end
        print("|cff00ff00[PersonaEngine]|r Bubble config mode disabled.")
        return
    end

    Bubble.ShowConfigPreview()
end
