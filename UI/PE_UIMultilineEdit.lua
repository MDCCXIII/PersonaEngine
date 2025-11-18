-- ##################################################
-- UI/PE_UIMultilineEdit.lua
-- Scrollable multiline edit boxes
-- ##################################################

local MODULE = "UIMultilineEdit"
local PE = PE

if not PE or type(PE) ~= "table" then return end

PE.UI = PE.UI or {}
local UI = PE.UI

-- Returns: scrollFrame, editBox
-- opts:
--   size       (table) { w, h }
--   point      (table) { point, relFrame, relPoint, x, y }
--   fontObject (FontObject)
function UI.CreateMultilineEdit(parent, opts)
    opts = opts or {}

    local size       = opts.size or { 300, 150 }
    local point      = opts.point
    local fontObject = opts.fontObject or ChatFontNormal

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    if point then
        scroll:SetPoint(unpack(point))
    end
    scroll:SetSize(size[1], size[2])

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(fontObject)
    edit:SetWidth(size[1] - 20)
    edit:SetHeight(size[2])
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")

    scroll:SetScrollChild(edit)

    return scroll, edit
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI MultilineEdit",
        class = "ui",
    })
end
