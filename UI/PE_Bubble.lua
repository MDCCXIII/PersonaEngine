-- ##################################################
-- UI\PE_Bubble.lua
-- PersonaEngine on-screen "speech bubble"
-- ##################################################

local MODULE = "Bubble"
local PE     = PE

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
    displaySeconds = 2.3,                -- base time; extra added per characters
}

local frame
local bubbleTex
local textFS
local isConfigMode = false

-- Lifetime + queue
local hideToken   = 0   -- cancels pending hide timers
local lastText    = nil -- last wrapped text actually shown
local pendingText = nil -- raw text queued to show after current finishes

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
-- Display-time helper: 2.3s + 0.3s per 10 characters
----------------------------------------------------

local function ComputeDisplaySecondsForText(text)
    local settings = GetSettings()
    local base     = settings.displaySeconds or DEFAULTS.displaySeconds -- 2.3 by default
    local per10    = 0.3

    if not text or text == "" then
        return base
    end

    local len   = #text    -- ASCII-safe; your lines are plain text
    local units = math.ceil(len / 10)

    return base + (units * per10)
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
-- Lifetime scheduling (no animations, just Show/Hide)
----------------------------------------------------

local function CancelAutoHide()
    hideToken = hideToken + 1
end

-- Internal helper: show a given raw text *right now* and schedule its hide
local function ShowMessageNow(rawText)
    if not rawText or rawText == "" then
        return
    end

    if not frame or not textFS then
        CreateBubbleFrame()
    end

    local settings = GetSettings()
    local wrapped  = WrapToCharLimit(rawText, settings.wrapChars or DEFAULTS.wrapChars)

    lastText = wrapped

    textFS:SetText(wrapped)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()

    frame:Show()

    CancelAutoHide()
    local secs = ComputeDisplaySecondsForText(wrapped)
    -- schedule hiding / advancing queue
    hideToken = hideToken + 1
    local myToken = hideToken

    C_Timer.After(secs, function()
        if hideToken ~= myToken then
            return -- superseded by newer message / manual cancel
        end

        -- If there's a pending message, show ONLY the latest and drop the rest.
        if pendingText and pendingText ~= "" then
            local nextText = pendingText
            pendingText    = nil
            ShowMessageNow(nextText) -- recurse into the next message
        else
            -- No more pending messages; fully hide.
            lastText = nil
            if frame then
                frame:Hide()
            end
        end
    end)
end

----------------------------------------------------
-- Internal: resize to match text
----------------------------------------------------

function ResizeToText()
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
        CancelAutoHide()
        lastText    = nil
        pendingText = nil
        if frame then
            frame:Hide()
        end
        return
    end

    -- Don't let combat chatter stomp the config preview
    if isConfigMode then
        return
    end

    if not frame or not textFS then
        CreateBubbleFrame()
    end

    -- Empty text = explicit hide request (and clear queue)
    if not text or text == "" then
        CancelAutoHide()
        lastText    = nil
        pendingText = nil
        if frame then
            frame:Hide()
        end
        return
    end

    -- If nothing is currently shown, display immediately.
    if not frame:IsShown() then
        pendingText = nil  -- clear any stale queued message
        ShowMessageNow(text)
        return
    end

    -- If something is already on screen:
    -- we only care about the *latest* attempt.
    pendingText = text
    -- current bubble will finish, then ShowMessageNow(pendingText) will fire
end

function Bubble.SetEnabled(isEnabled)
    local settings = GetSettings()
    settings.enabled = not not isEnabled

    if not settings.enabled and frame then
        CancelAutoHide()
        lastText    = nil
        pendingText = nil
        frame:Hide()
    end
end

----------------------------------------------------
-- Config preview: /pebubble (with optional test lines)
----------------------------------------------------

function Bubble.ShowConfigPreview(numLines)
    if not frame or not textFS then
        CreateBubbleFrame()
    end

    local settings = GetSettings()
    isConfigMode   = true
    frame:EnableMouse(true)

    -- Optional numeric argument: how many "1234567890" chunks to show
    numLines = tonumber(numLines) or 1
    if numLines < 1 then numLines = 1 end
    if numLines > 20 then numLines = 20 end

    local chunk     = "1234567890"
    local testBlock = chunk:rep(numLines)

    local previewText = "PersonaEngine Bubble\n\n" .. testBlock
    previewText = WrapToCharLimit(previewText, settings.wrapChars or DEFAULTS.wrapChars)

    textFS:SetText(previewText)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()

    -- Config mode: no auto-hide; user dismisses with /pebubble off
    CancelAutoHide()
    lastText    = nil
    pendingText = nil
    frame:Show()

    print(string.format(
        "|cff00ff00[PersonaEngine]|r Bubble config mode: %d test chunk(s). Drag the bubble, then release to save position. Type /pebubble off to exit.",
        numLines
    ))
end

SLASH_PEBUBBLE1 = "/pebubble"
SlashCmdList.PEBUBBLE = function(msg)
    local raw     = msg or ""
    local trimmed = strtrim(raw)

    if trimmed:lower() == "off" then
        isConfigMode = false
        CancelAutoHide()
        if frame then
            frame:EnableMouse(false)
            frame:Hide()
        end
        print("|cff00ff00[PersonaEngine]|r Bubble config mode disabled.")
        return
    end

    -- If they passed a number, use it as testLines; otherwise default to 1
    local numLines = tonumber(trimmed) or 1
    Bubble.ShowConfigPreview(numLines)
end
