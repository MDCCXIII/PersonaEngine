-- ##################################################
-- UI/PE_UICheckbox.lua
-- Checkbox widgets
-- ##################################################

local MODULE = "UICheckbox"
local PE = PE

if not PE or type(PE) ~= "table" then return end

PE.UI = PE.UI or {}
local UI = PE.UI

-- Returns: checkButton
-- opts:
--   label   (string)
--   point   (table) { point, relFrame, relPoint, x, y }
--   checked (bool)
function UI.CreateCheckbox(parent, opts)
    opts = opts or {}

    local point   = opts.point
    local label   = opts.label or "Checkbox"
    local checked = opts.checked

    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    if point then
        cb:SetPoint(unpack(point))
    end
    cb.Text:SetText(label)
    if checked ~= nil then
        cb:SetChecked(checked)
    end

    return cb
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Checkbox",
        class = "ui",
    })
end
