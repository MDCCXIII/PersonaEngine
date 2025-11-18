-- ##################################################
-- UI/PE_UIMultilineEdit.lua
-- Scrollable multiline edit widget
-- ##################################################

local MODULE = "UIMultilineEdit"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

PE.UI = PE.UI or {}
local UI = PE.UI

--[[--------------------------------------------------------------------
UI.CreateMultilineEdit(parent, opts) -> scrollFrame, editBox

opts (all optional):

  name          : string   -- global name for scrollframe
  size          : { w, h } -- default size if no anchors
  point         : { p, rel, rp, x, y }
  point2        : { p, rel, rp, x, y } -- second anchor for stretching
  fontObject    : FontObject (default ChatFontNormal)
  textScale     : number   -- scale factor for font size (1.0 = unchanged)
  padding       : number   -- horizontal padding, default 20
  minHeight     : number   -- minimum edit height (default = scroll height)
  extraHeight   : number   -- extra buffer height to keep scrolling
  backdrop      : true|false|table
                  true/nil -> default backdrop
                  false    -> no backdrop
                  table    -> custom for SetBackdrop
  backdropColor : { r, g, b, a } (default 0,0,0,0.4)
  borderColor   : { r, g, b, a } (default 0.3,0.3,0.3,1)
  onFocusHighlight : boolean
                  true -> highlight all text on focus, Esc clears focus
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
    local template   = "UIPanelScrollFrameTemplate,BackdropTemplate"

    local scroll = CreateFrame("ScrollFrame", name, parent, template)

    -- Positioning
    if opts.point then
        scroll:SetPoint(unpack(opts.point))
    end
    if opts.point2 then
        scroll:SetPoint(unpack(opts.point2))
    end
    if not opts.point and not opts.point2 then
        scroll:SetSize(size[1], size[2])
    end

    ApplyDefaultBackdrop(scroll, opts)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(fontObject)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")

    scroll:SetScrollChild(edit)

    local function ResizeEdit()
        local w = math.max(0, scroll:GetWidth() - padding)
        edit:SetWidth(w)

        local scrollH = scroll:GetHeight()
        local minH    = opts.minHeight or scrollH
        local extraH  = opts.extraHeight or 0
        local targetH = math.max(minH, scrollH) + extraH

        edit:SetHeight(targetH)
        scroll:UpdateScrollChildRect()
    end

    scroll:SetScript("OnSizeChanged", function()
        ResizeEdit()
    end)

    edit:SetScript("OnTextChanged", function()
        scroll:UpdateScrollChildRect()
    end)

    if opts.onFocusHighlight then
        edit:SetScript("OnEditFocusGained", function(self)
            local text = self:GetText() or ""
            self:HighlightText(0, #text)
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
    end

    ApplyTextScale(edit, opts.textScale)

    ResizeEdit()

    return scroll, edit
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI MultilineEdit",
        class = "ui",
    })
end
