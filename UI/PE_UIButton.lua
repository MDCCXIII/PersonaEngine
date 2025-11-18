-- ##################################################
-- UI/PE_UIButton.lua
-- Button widgets
-- ##################################################

local MODULE = "UIButton"
local PE = PE

if not PE or type(PE) ~= "table" then return end

PE.UI = PE.UI or {}
local UI = PE.UI

-- Returns: button
-- opts:
--   text    (string)
--   size    (table) { w, h }
--   point   (table) { point, relFrame, relPoint, x, y }
--   onClick (function)
function UI.CreateButton(parent, opts)
    opts = opts or {}

    local text    = opts.text or "Button"
    local size    = opts.size or { 80, 22 }
    local point   = opts.point
    local onClick = opts.onClick

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(size[1], size[2])

    if point then
        btn:SetPoint(unpack(point))
    end

    btn:SetText(text)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "UI Button",
        class = "ui",
    })
end
