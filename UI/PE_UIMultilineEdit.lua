-- ##################################################
-- UI/PE_UIMultilineEdit.lua
-- Scrollable multiline edit boxes (shared widget)
-- ##################################################

local MODULE = "UIMultilineEdit"
local PE = PE

if not PE or type(PE) ~= "table" then
    return
end

PE.UI = PE.UI or {}
local UI = PE.UI

--[[--------------------------------------------------------------------
UI.CreateMultilineEdit(parent, opts) → scrollFrame, editBox

opts (all optional):
  name         : string   -- frame name for the scroll frame
  size         : { w, h } -- fallback size if no anchors
  point        : { p, rel, rp, x, y }        -- primary anchor
  point2       : { p, rel, rp, x, y }        -- secondary anchor (for stretch)
  fontObject   : FontObject (default ChatFontNormal)
  textScale    : number   -- scale applied to edit font (e.g. 1.0, 0.9, 1.1)
  padding      : number   -- horizontal padding inside scroll (default 20)
  minHeight    : number   -- minimum edit height (default: scroll height)
  extraHeight  : number   -- extra height (used to keep scrollable buffer)
  backdrop     : table|true|false
                - true/nil → default PersonaEngine chat-style backdrop
                - table    → custom backdrop for SetBackdrop
                - false    → no backdrop
  backdropColor: {r,g,b,a} for SetBackdropColor (default 0,0,0,0.4)
  borderColor  : {r,g,b,a} for SetBackdropBorderColor (default 0.3,0.3,0.3)
  onFocusHighlight : boolean
                - if true, highlight all text on focus + Esc clears focus
----------------------------------------------------------------------]]

local function ApplyDefaultBackdrop(scroll, opts)
    if not scroll.SetBackdrop then return end

    local bd = opts.backdrop
    if bd == false then
        return
    end

    if bd == true or bd == nil then
        bd = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true,
            tileSize = 16,
            edgeSize = 16,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        }
    end

    scroll:SetBackdrop(bd)

    local bcol = opts.backdropColor or { 0, 0, 0, 0.4 }
    local ecol = opts.borderColor   or { 0.3, 0.3, 0.3, 1 }

    scroll:SetBackdropColor(bcol[1], bcol[2], bcol[3], bcol[4] or 1)
    scroll:SetBackdropBorderColor(ecol[1], ecol[2], ecol[3], ecol[4] or 1)
end

local function ApplyTextScale(widget, scale)
    if not widget or not scale or scale == 1 then
        return
    end

    local font, size, flags = widget:GetFont()
    if font and size then
        widget:SetFont(font, size * scale, flags)
    end
end

function UI.CreateMultilineEdit(parent, opts)
    opts = opts or {}

    local size       = opts.size or { 300, 150 }
    local fontObject = opts.fontObject or ChatFontNormal
    local padding    = opts.padding or 20
    local name       = opts.name
    local template   = "UIPanelScrollFrameTemplate"

    -- We add BackdropTemplate here so any caller can get the border for free.
    template = template .. ",BackdropTemplate"

    local scroll = CreateFrame("ScrollFrame", name, parent, template)

    -- Positioning
    if opts.point then
        scroll:SetPoint(unpack(opts.point))
    end
    if opts.point2 then
        scroll:SetPoint(unpack(opts.point2))
    end

    -- Fallback static size if no anchors were given
    if not opts.point and not opts.point2 then
        scroll:SetSize(size[1], size[2])
    end

    -- Backdrop / border
    ApplyDefaultBackdrop(scroll, opts)

    -- Edit box
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(fontObject)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")

    scroll:SetScrollChild(edit)

    -- Dynamic sizing: keep edit width in sync with scroll width, and give it
    -- a tall enough height to always have a scrollable region.
    local function ResizeEdit()
        local w = math.max(0, scroll:GetWidth() - padding)
        edit:SetWidth(w)

        local scrollH  = scroll:GetHeight()
        local minH     = opts.minHeight or scrollH
        local extraH   = opts.extraHeight or 0
        local targetH  = math.max(minH, scrollH) + extraH

        edit:SetHeight(targetH)
        scroll:UpdateScrollChildRect()
    end

    scroll:SetScript("OnSizeChanged", function()
        ResizeEdit()
    end)

    edit:SetScript("OnTextChanged", function()
        scroll:UpdateScrollChildRect()
    end)

    -- Optional focus behaviour
    if opts.onFocusHighlight then
        edit:SetScript("OnEditFocusGained", function(self)
            local text = self:GetText() or ""
            self:HighlightText(0, #text)
        end)

        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
    end

    -- Optional per-widget text scaling
    ApplyTextScale(edit, opts.textScale)

    -- Initial layout
    ResizeEdit()

    return scroll, edit
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI MultilineEdit",
        class = "ui",
    })
end
