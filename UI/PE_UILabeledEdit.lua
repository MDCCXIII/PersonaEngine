-- ##################################################
-- UI/PE_UILabeledEdit.lua
-- Labeled single-line edit boxes
-- ##################################################

local MODULE = "UILabeledEdit"
local PE = PE

if not PE or type(PE) ~= "table" then return end

PE.UI = PE.UI or {}
local UI = PE.UI

-- Returns: labelFontString, editBox
-- opts:
--   label  (string)
--   width  (number)
--   height (number)
--   point  (table) { point, relFrame, relPoint, x, y }
--   xOffset, yOffset (number)
--   numeric (bool)
function UI.CreateLabeledEdit(parent, opts)
    opts = opts or {}

    local labelText  = opts.label or "Label"
    local editWidth  = opts.width  or 200
    local editHeight = opts.height or 20
    local point      = opts.point

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if point then
        label:SetPoint(unpack(point))
    end
    label:SetText(labelText)

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(editWidth, editHeight)
    edit:SetAutoFocus(false)
    edit:SetPoint("LEFT", label, "RIGHT", opts.xOffset or 10, opts.yOffset or 0)

    if opts.numeric then
        edit:SetNumeric(true)
    end

    return label, edit
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI LabeledEdit",
        class = "ui",
    })
end
