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
    maxWidth       = 260,  -- pixel width cap (clamped below)
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

-- Multi-line state
local lines      = {}   -- { { text = "...", expireAt = number }, ... }
local maxLines   = 5    -- max visible lines in the bubble
local updateTick = 0

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
    -- Clamp maxWidth so bad saved values can't create screen-wide marshmallows
    if s.maxWidth < 180 or s.maxWidth > 420 then
        s.maxWidth = DEFAULTS.maxWidth
    end

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
-- Wrap at spaces when possible, but also break over-long "words"
-- (e.g. long digit strings) so they don't force an ultra-wide bubble.
----------------------------------------------------

local function WrapToCharLimit(text, limit)
    if not text or limit <= 0 then return text end

    local linesOut = {}

    -- Handle existing newlines by wrapping each logical line separately
    for logicalLine in tostring(text):gmatch("([^\n]*)\n?") do
        if logicalLine == "" and #linesOut > 0 then
            -- preserve explicit blank line
            table.insert(linesOut, "")
        elseif logicalLine ~= "" then
            local outParts = {}
            local lineLen  = 0

            for rawWord in logicalLine:gmatch("%S+") do
                local word = rawWord
                local wlen = #word

                -- If the word itself is longer than the limit, hard-break it
                while wlen > limit do
                    local chunk = word:sub(1, limit)
                    word        = word:sub(limit + 1)
                    wlen        = #word

                    if lineLen > 0 then
                        table.insert(outParts, "\n")
                        lineLen = 0
                    end

                    table.insert(outParts, chunk)
                end

                if wlen > 0 then
                    -- If this word would overflow the current line, wrap first
                    if lineLen > 0 and (lineLen + 1 + wlen) > limit then
                        table.insert(outParts, "\n")
                        lineLen = 0
                    end

                    if lineLen > 0 then
                        table.insert(outParts, " ")
                        lineLen = lineLen + 1
                    end

                    table.insert(outParts, word)
                    lineLen = lineLen + wlen
                end
            end

            table.insert(linesOut, table.concat(outParts))
        end
    end

    return table.concat(linesOut, "\n")
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

    local len   = #text
    local units = math.ceil(len / 10)

    return base + (units * per10)
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

    -- Count logical lines to give extra breathing room
    local text      = textFS:GetText() or ""
    local lineCount = 1
    for _ in text:gmatch("\n") do
        lineCount = lineCount + 1
    end

    local extraYPerLine = 4
    local extraY        = math.max(0, lineCount - 1) * extraYPerLine

    -- Add vertical margin so text never hugs the top/bottom edges
    frame:SetHeight(h + padY * 2 + extraY)
end

----------------------------------------------------
-- Frame creation / rebuild
----------------------------------------------------

local function UpdateLinesDisplay()
    if not frame or not textFS then return end

    if #lines == 0 then
        frame:Hide()
        return
    end

    local parts = {}
    for i = 1, #lines do
        table.insert(parts, lines[i].text)
    end

    textFS:SetText(table.concat(parts, "\n"))
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()
    frame:Show()
end

local function OnBubbleUpdate(self, elapsed)
    if isConfigMode then
        return -- don't auto-expire in config preview
    end

    if #lines == 0 then
        self:Hide()
        return
    end

    updateTick = updateTick + elapsed
    if updateTick < 0.1 then
        return
    end
    updateTick = 0

    local now     = GetTime()
    local changed = false

    -- Cull expired lines from oldest to newest
    for i = #lines, 1, -1 do
        if lines[i].expireAt <= now then
            table.remove(lines, i)
            changed = true
        end
    end

    if changed then
        if #lines == 0 then
            self:Hide()
            return
        end
        UpdateLinesDisplay()
    end
end

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

    frame:SetScript("OnUpdate", OnBubbleUpdate)
    frame:Hide()
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
        wipe(lines)
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

    -- Empty text = explicit hide request (and clear lines)
    if not text or text == "" then
        wipe(lines)
        if frame then
            frame:Hide()
        end
        return
    end

    local wrapped = WrapToCharLimit(text, settings.wrapChars or DEFAULTS.wrapChars)
    local now     = GetTime()
    local secs    = ComputeDisplaySecondsForText(wrapped)

    -- Insert new line at bottom
    table.insert(lines, {
        text     = wrapped,
        expireAt = now + secs,
    })

    -- Enforce max lines (oldest first)
    while #lines > maxLines do
        table.remove(lines, 1)
    end

    UpdateLinesDisplay()
end

function Bubble.SetEnabled(isEnabled)
    local settings = GetSettings()
    settings.enabled = not not isEnabled

    if not settings.enabled and frame then
        wipe(lines)
        frame:Hide()
    end
end

----------------------------------------------------
-- Config preview: /pebubble (with optional test lines)
-- Now uses one "1234567890" per *line* (not a single huge word),
-- so wrapping and sizing stay sane.
----------------------------------------------------

function Bubble.ShowConfigPreview(numLines)
    if not frame or not textFS then
        CreateBubbleFrame()
    end

    local settings = GetSettings()
    isConfigMode   = true
    frame:EnableMouse(true)

    numLines = tonumber(numLines) or 1
    if numLines < 1 then numLines = 1 end
    if numLines > 20 then numLines = 20 end

    local chunk = "1234567890"
    local testLines = {}
    for i = 1, numLines do
        table.insert(testLines, chunk)
    end

    local testBlock   = table.concat(testLines, "\n")
    local previewText = "PersonaEngine Bubble\n\n" .. testBlock

    -- We still run it through the wrapper so we can see realistic behavior.
    previewText = WrapToCharLimit(previewText, settings.wrapChars or DEFAULTS.wrapChars)

    -- Config preview uses its own text, independent of `lines`
    textFS:SetText(previewText)
    ResizeToText()
    Bubble.RefreshAppearance()
    Bubble.Reanchor()

    wipe(lines)
    frame:Show()

    print(string.format(
        "|cff00ff00[PersonaEngine]|r Bubble config mode: %d test line(s). Drag the bubble, then release to save position. Type /pebubble off to exit.",
        numLines
    ))
end

SLASH_PEBUBBLE1 = "/pebubble"
SlashCmdList.PEBUBBLE = function(msg)
    local raw     = msg or ""
    local trimmed = strtrim(raw)

    if trimmed:lower() == "off" then
        isConfigMode = false
        if frame then
            frame:EnableMouse(false)
            frame:Hide()
        end
        print("|cff00ff00[PersonaEngine]|r Bubble config mode disabled.")
        return
    end

    local numLines = tonumber(trimmed) or 1
    Bubble.ShowConfigPreview(numLines)
end
