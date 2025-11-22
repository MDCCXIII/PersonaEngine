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

-- Path to your speech-bubble PNG
local BUBBLE_TEXTURE_PATH = "Interface\\AddOns\\PersonaEngine\\Media\\PE_SpeechBubble"

----------------------------------------------------
-- Defaults
----------------------------------------------------

local DEFAULTS = {
    enabled        = true,
    maxWidth       = 260,  -- pixel width cap
    padding        = 12,   -- base padding (horizontal)
    -- Position relative to PlayerFrame's BOTTOMRIGHT
    offsetX        = -40,  -- negative = bubble left of portrait
    offsetY        = 40,
    bgColor        = { 1, 1, 1, 0.85 },  -- white w/ alpha
    textColor      = { 0, 0, 0, 1.0 },   -- black
    wrapChars      = 50,                 -- char limit per line for wrapping
    displaySeconds = 3,                  -- how long a message stays before fading out
}

local frame
local bubbleTex
local textFS
local isConfigMode = false

-- For lifetime handling
local hideToken = 0
local lastText  = nil

----------------------------------------------------
-- Settings helpers
----------------------------------------------------

local function copyColor(src, def)
    if type(src) ~= "table" then src = {} end

    local r = tonumber(src[1])
    local g = tonumber(src[2])
    local b = tonumber(src[3])
    local a = tonumber(src[4])

    if not r or not g or not b then
        r, g, b, a = def[1], def[2], def[3], def[4]
    else
        a = a or def[4]
    end

    return { r, g, b, a }
end

local function GetSettings()
    PE.db = PE.db or PersonaEngineDB or {}
    PE.db.settings = PE.db.settings or {}
    PE.db.settings.bubble = PE.db.settings.bubble or {}

    local s = PE.db.settings.bubble

    -- Simple scalar defaults
    if s.enabled == nil then s.enabled = DEFAULTS.enabled end
    if not s.maxWidth then s.maxWidth = DEFAULTS.maxWidth end
    if not s.padding then s.padding = DEFAULTS.padding end
    if s.offsetX == nil then s.offsetX = DEFAULTS.offsetX end
    if s.offsetY == nil then s.offsetY = DEFAULTS.offsetY end
    if not s.wrapChars then s.wrapChars = DEFAULTS.wrapChars end
    if not s.displaySeconds then s.displaySeconds = DEFAULTS.displaySeconds end

    -- Robust color defaults
    s.bgColor   = copyColor(s.bgColor,   DEFAULTS.bgColor)
    s.textColor = copyColor(s.textColor, DEFAULTS.textColor)

    return s
end

----------------------------------------------------
-- Word-wrap helper
----------------------------------------------------

local function WrapToCharLimit(text, limit)
    if not text or limit <= 0 then return text end

    local out = {}
    local lineLen = 0

    for chunk in text:gmatch("%S+%s*") do
        local len = #chunk
        if lineLen + len > limit and lineLen > 0 then
            table.insert(out, "\n")
            lineLen = 0
        end
        table.insert(out, chunk)
        lineLen = lineLen + len
    end

    local result = table.concat(out)
    result = result:gsub("%s+\n", "\n")
    return result
end

----------------------------------------------------
-- Frame creation / rebuild
----------------------------------------------------

local function CreateBubbleFrame()
    local settings = GetSettings()
    local parent   = PlayerFrame or UIParent

    -- Reuse existing frame if it exists, otherwise create
    if not frame then
        frame = _G["PE_PersonaBubbleFrame"]
    end
    if not frame then
        frame = CreateFrame("Frame", "PE_PersonaBubbleFrame", parent)
    else
        frame:SetParent(parent)
    end

    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    -- Anchor: bubble stays attached by its BOTTOMRIGHT to the portrait area,
    -- and grows left as it gets wider.
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",
        settings.offsetX, settings.offsetY)

    -- Bubble texture (includes tail)
    if not bubbleTex then
        bubbleTex = frame:CreateTexture(nil, "BACKGROUND")
    end
    bubbleTex:ClearAllPoints()
    bubbleTex:SetAllPoints(frame)

    -- Try to use the custom speech bubble art
    bubbleTex:SetTexture(BUBBLE_TEXTURE_PATH)

    -- If that failed (wrong path / missing file), fall back to a generic box
    if not bubbleTex:GetTexture() then
        bubbleTex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    end

    ------------------------------------------------
    -- TEXT: use bigger vertical padding so text sits
    -- down inside the oval, not on the very top edge
    ------------------------------------------------
    -- *** DO NOT TOUCH THESE LINES (per user request) ***
    local padX = (settings.padding or 12) + 50
    local padY = (settings.padding + 12) + 15   -- << tweak this if you want more/less headroom

    if not textFS then
        textFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    textFS:SetJustifyH("LEFT")
    textFS:SetJustifyV("TOP")
    textFS:SetWordWrap(true)
    textFS:ClearAllPoints()
    textFS:SetPoint("TOPLEFT",  frame, "TOPLEFT",  padX, -padY)
    textFS:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padX, -padY)

    -- Dragging (config mode only)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if isConfigMode then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        if not isConfigMode then return end
        self:StopMovingOrSizing()

        local settings = GetSettings()
        local parent   = PlayerFrame or UIParent
        local scale    = self:GetEffectiveScale() / parent:GetEffectiveScale()

        -- Save offset from parent's BOTTOMRIGHT
        local right   = self:GetRight()   * scale
        local bottom  = self:GetBottom()  * scale
        local pRight  = parent:GetRight() * scale
        local pBottom = parent:GetBottom()* scale

        settings.offsetX = right - pRight
        settings.offsetY = bottom - pBottom

        Bubble.Reanchor()
    end)

    frame:Hide()
end

----------------------------------------------------
-- Fade animations
----------------------------------------------------

local function EnsureAnimations()
    if not frame then return end

    if not frame.fadeIn then
        local ag = frame:CreateAnimationGroup("PEBubbleFadeIn")
        local a  = ag:CreateAnimation("Alpha")
        a:SetOrder(1)
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
        a:SetDuration(0.15)

        ag:SetScript("OnPlay", function()
            frame:SetAlpha(0)
            frame:Show()
        end)

        frame.fadeIn = ag
    end

    if not frame.fadeOut then
        local ag = frame:CreateAnimationGroup("PEBubbleFadeOut")
        local a  = ag:CreateAnimation("Alpha")
        a:SetOrder(1)
        a:SetFromAlpha(1)
        a:SetToAlpha(0)
        a:SetDuration(0.20)

        ag:SetScript("OnFinished", function()
            frame:Hide()
            frame:SetAlpha(1)
        end)

        frame.fadeOut = ag
    end
end

local function PlayFadeInIfNeeded()
    if not frame then return end
    EnsureAnimations()

    -- If already visible and not fully hidden, don't spam fade-in
    if frame:IsShown() then
        if frame.fadeOut then frame.fadeOut:Stop() end
        return
    end

    if frame.fadeOut then frame.fadeOut:Stop() end
    if frame.fadeIn then
        frame.fadeIn:Play()
    else
        frame:Show()
    end
end

local function PlayFadeOut()
    if not frame then return end
    EnsureAnimations()

    if frame.fadeIn then frame.fadeIn:Stop() end
    if frame.fadeOut then
        frame.fadeOut:Play()
    else
        frame:Hide()
    end
end

----------------------------------------------------
-- Lifetime scheduling
----------------------------------------------------

local function ScheduleAutoHide(seconds)
    if not frame then return end
    seconds = seconds or 0
    hideToken = hideToken + 1
    local myToken = hideToken

    if seconds <= 0 then
        -- immediate
        PlayFadeOut()
        return
    end

    C_Timer.After(seconds, function()
        if hideToken ~= myToken then
            return -- superseded by a newer message
        end
        PlayFadeOut()
    end)
end

----------------------------------------------------
-- Internal: resize to match text
----------------------------------------------------

local function ResizeToText()
    if not frame or not textFS then return end
    local settings = GetSettings()

    -- Must match the padX/padY logic in CreateBubbleFrame
    -- *** DO NOT TOUCH THESE LINES (per user request) ***
    local padX = (settings.padding or 12) + 50
    local padY = (settings.padding + 12) + 20 -- must match CreateBubbleFrame

    frame:SetWidth(settings.maxWidth)
    textFS:SetWidth(settings.maxWidth - padX * 2)

    local h = textFS:GetStringHeight()

    -- Add generous vertical margin so text never touches the top/edges
    frame:SetHeight(h + padY * 2)
end

----------------------------------------------------
-- Public API
----------------------------------------------------

function Bubble.RefreshAppearance()
    if not frame or not bubbleTex or not textFS then return end
    local settings = GetSettings()

    local bg = settings.bgColor or DEFAULTS.bgColor
    local br, bgc, bb, ba = bg[1], bg[2], bg[3], bg[4]
    bubbleTex:SetVertexColor(br, bgc, bb, ba)

    local tc = settings.textColor or DEFAULTS.textColor
    textFS:SetTextColor(tc[1], tc[2], tc[3], tc[4])
end

function Bubble.Reanchor()
    if not frame then return end
    local settings = GetSettings()
    local parent   = PlayerFrame or UIParent

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",
        settings.offsetX or DEFAULTS.offsetX,
        settings.offsetY or DEFAULTS.offsetY)
end

function Bubble.Say(text)
    local settings = GetSettings()

    -- Disabled → hide and bail
    if not settings.enabled then
        if frame then
            hideToken = hideToken + 1 -- cancel any pending hides
            PlayFadeOut()
        end
        lastText = nil
        return
    end

    if isConfigMode then
        -- Don't clobber the config preview
        return
    end

    if not frame or not textFS then
        CreateBubbleFrame()
    end

    -- Empty text = request to hide now
    if not text or text == "" then
        hideToken = hideToken + 1 -- cancel future hides
        lastText  = nil
        PlayFadeOut()
        return
    end

    local wrapped = WrapToCharLimit(text, settings.wrapChars or DEFAULTS.wrapChars)

    -- If text didn't actually change, just refresh timer and bail
    if wrapped == lastText and frame and frame:IsShown() then
        ScheduleAutoHide(settings.displaySeconds or DEFAULTS.displaySeconds)
        return
    end

    lastText = wrapped

    textFS:SetText(wrapped)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()

    PlayFadeInIfNeeded()
    ScheduleAutoHide(settings.displaySeconds or DEFAULTS.displaySeconds)
end

function Bubble.SetEnabled(isEnabled)
    local settings = GetSettings()
    settings.enabled = not not isEnabled

    if not settings.enabled and frame then
        hideToken = hideToken + 1
        PlayFadeOut()
    end
end

----------------------------------------------------
-- Config preview: /pebubble
----------------------------------------------------

function Bubble.ShowConfigPreview()
    if not frame or not textFS then
        CreateBubbleFrame()
    end

    local settings = GetSettings()
    isConfigMode   = true
    frame:EnableMouse(true)

    local previewText = "PersonaEngine Bubble\n\nDrag me where you want me."
    previewText = WrapToCharLimit(previewText, settings.wrapChars or DEFAULTS.wrapChars)

    textFS:SetText(previewText)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()

    -- Cancel any auto-hide, show and keep it up until user turns config off
    hideToken = hideToken + 1
    PlayFadeInIfNeeded()

    print("|cff00ff00[PersonaEngine]|r Bubble config mode: drag the bubble, then release to save position. Type /pebubble off to exit.")
end

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
