-- ##################################################
-- PE_Icon.lua
-- Free-floating status button (no minimap LibDBIcon)
-- ##################################################

local MODULE = "Icon"
local PE     = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if not PersonaEngineDB or type(PersonaEngineDB) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PersonaEngineDB missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- UI constants for this module
----------------------------------------------------

local ICON_SIZE           = { w = 32, h = 32 }
local ICON_INNER_SIZE     = { w = 20, h = 20 }
local ICON_TEXTURE        = "Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga"
local ICON_BORDER_SIZE    = 54
local ICON_BORDER_OFFSETX = 10.5
local ICON_BORDER_OFFSETY = -10.1

----------------------------------------------------
-- Optional LDB object (for broker displays only)
-- No LibDBIcon usage → no minimap button.
----------------------------------------------------

local LDB
if LibStub then
    LDB = LibStub("LibDataBroker-1.1", true)
end

if LDB then
    LDB:NewDataObject("PersonaEngine", {
        type = "data source",
        text = "Persona Engine",
        icon = ICON_TEXTURE,

        OnClick = function(frame, button)
            if _G.PersonaEngine_Button_OnClick then
                _G.PersonaEngine_Button_OnClick(frame, button)
            end
        end,

        OnTooltipShow = function(tt)
            if _G.PersonaEngine_Button_OnTooltip then
                _G.PersonaEngine_Button_OnTooltip(tt)
            end
        end,
    })
end

----------------------------------------------------
-- Free-floating status button
----------------------------------------------------

local function PersonaEngine_CreateButton()
    if PersonaEngineButton then
        return PersonaEngineButton
    end

    local buttonConfig    = PersonaEngineDB.button or {}
    local buttonDefaults  = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)
    btn:SetSize(ICON_SIZE.w, ICON_SIZE.h)
    btn:SetScale(buttonConfig.scale or buttonDefaults.scale or 1.2)

    btn:SetFrameStrata(buttonConfig.strata or buttonDefaults.strata or "MEDIUM")
    btn:SetFrameLevel(buttonConfig.level or buttonDefaults.level or 1)

    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    btn:SetPoint(
        buttonConfig.point    or buttonDefaults.point    or "TOPRIGHT",
        UIParent,
        buttonConfig.relPoint or buttonDefaults.relPoint or "TOPRIGHT",
        buttonConfig.x        or buttonDefaults.x        or -150,
        buttonConfig.y        or buttonDefaults.y        or -170
    )

    ------------------------------------------------
    -- Icon texture
    ------------------------------------------------
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(ICON_INNER_SIZE.w, ICON_INNER_SIZE.h)
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    ------------------------------------------------
    -- Border texture
    ------------------------------------------------
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("CENTER", ICON_BORDER_OFFSETX, ICON_BORDER_OFFSETY)
    border:SetSize(ICON_BORDER_SIZE, ICON_BORDER_SIZE)
    btn.border = border

    ------------------------------------------------
    -- Highlight
    ------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    ------------------------------------------------
    -- Drag-save (Alt+Drag)
    ------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then
            self:StartMoving()
        end
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PersonaEngineDB.button.point    = point
        PersonaEngineDB.button.relPoint = relPoint
        PersonaEngineDB.button.x        = x
        PersonaEngineDB.button.y        = y
    end)

    ------------------------------------------------
    -- Tooltip + click
    ------------------------------------------------
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        PersonaEngine_Button_OnTooltip(GameTooltip)
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", PersonaEngine_Button_OnClick)

    return btn
end

-- Delay spawn so SavedVariables and globals are ready
if C_Timer and C_Timer.After then
    C_Timer.After(0.1, PersonaEngine_CreateButton)
else
    PersonaEngine_CreateButton()
end

----------------------------------------------------
-- Click Handler
--  - Unmodified Left/Right: world interaction (reserved)
--  - Shift: config & engine toggle
--  - Ctrl: dev tools (Lua errors / reload), DevMode only
--  - Alt: used for dragging; no click actions
----------------------------------------------------

function PersonaEngine_Button_OnClick(self, button)
    local alt   = IsAltKeyDown()
    local ctrl  = IsControlKeyDown()
    local shift = IsShiftKeyDown()

    -- ALT is layout/drag only; no actions on release
    if alt then
        return
    end

    -- Developer shortcuts (Ctrl+click), only when DevMode enabled
    if PersonaEngineDB.DevMode and ctrl then
        if button == "LeftButton" then
            local cur = GetCVar("scriptErrors")
            if cur == "1" then
                SetCVar("scriptErrors", 0)
                if PE.Log then PE.Log(4, "[PersonaEngine] Lua errors: OFF") end
            else
                SetCVar("scriptErrors", 1)
                if PE.Log then PE.Log(4, "[PersonaEngine] Lua errors: ON") end
            end
            ReloadUI()
            return
        elseif button == "RightButton" then
            if PE.Log then PE.Log(4, "[PersonaEngine] Reloading UI (dev shortcut)") end
            ReloadUI()
            return
        end
    elseif not PersonaEngineDB.DevMode and ctrl then
		if button == "LeftButton" then
			-- Placeholder behavior; safe to replace later
            SendChatMessage("Copporclang peers at the surroundings, gears whirring.", "SAY")
		elseif button == "RightButton" then
			if PE and PE.MinimalUI and PE.MinimalUI.Toggle then
				PE.MinimalUI:Toggle()
			elseif PE and PE.ToggleMinimalUI then
				PE.ToggleMinimalUI()
			end
			return
		end
	
	end

    -- Config / Engine control (Shift+click)
    if shift then
        if button == "LeftButton" then
            if PE.ToggleConfig then
                PE.ToggleConfig()
            end
            return
        elseif button == "RightButton" then
            -- Toggle speech engine (SR_On) with flavor text
            local wasOn = (SR_On == 1)
            local nowOn = not wasOn
            SR_On       = nowOn and 1 or 0

            if nowOn then
                local pool = PE_EngineOnLines or {}
                local line = (#pool > 0 and pool[math.random(#pool)]) or "Speech module online."
                SendChatMessage(line, "SAY")
                if PE.Log then PE.Log("|cff00ff00Persona Engine Enabled|r") end
            else
                local offPool = PE_EngineOffLines or {}
                local line = (#offPool > 0 and offPool[math.random(#offPool)]) or "Speech module offline."
                SendChatMessage(line, "SAY")
                if PE.Log then PE.Log("|cffff0000Persona Engine Disabled|r") end

                local scaryPool = PE_EngineOffScaryLines or {}
                if #scaryPool > 0 and math.random(20) == 1 then
                    local scary = scaryPool[math.random(#scaryPool)]
                    SendChatMessage(scary, "SAY")
                end
            end
            return
        end
    end

    -- Unmodified clicks: world interaction (reserved for your future logic)
    if button == "LeftButton" then
        -- Primary world interaction hook
        if PE.WorldInteractPrimary then
            PE.WorldInteractPrimary()
        else
            -- Placeholder behavior; safe to replace later
            SendChatMessage("Copporclang peers at the surroundings, gears whirring.", "SAY")
        end
        return
    elseif button == "RightButton" then
        -- Secondary world interaction hook
        if PE.WorldInteractSecondary then
            PE.WorldInteractSecondary()
        else
            -- Placeholder behavior; safe to replace later
            SendChatMessage("Copporclang adjusts some invisible dials in the air.", "SAY")
        end
        return
    end
end

----------------------------------------------------
-- Tooltip
----------------------------------------------------

function PersonaEngine_Button_OnTooltip(tt)
    if not tt or not tt.AddLine then
        return
    end

    tt:ClearLines()
    tt:AddLine("Persona Engine", 1, 1, 1)
    tt:AddLine("|cff00ff88Copporclang's Personality Core|r")
    tt:AddLine(" ")

    -- World interaction summary
    tt:AddLine("|cffffffffLeft-click:|r World interaction (primary)", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffffffRight-click:|r World interaction (secondary)", 0.8, 0.8, 0.8)

    tt:AddLine(" ")
    tt:AddLine("|cffffffffShift+Left-click:|r Open control console", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffffffShift+Right-click:|r Toggle speech module", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffffffAlt+Drag:|r Move icon", 0.8, 0.8, 0.8)

    if PersonaEngineDB.DevMode then
        tt:AddLine(" ")
        tt:AddLine("|cffffff00[Developer Mode]|r", 1, 0.9, 0)

        local luaOn = (GetCVar("scriptErrors") == "1")
        local luaText = luaOn and "|cff00ff00Lua errors: ON|r" or "|cffff0000Lua errors: OFF|r"
        tt:AddLine(luaText)

        tt:AddLine("|cffffffffCtrl+Left-click:|r Toggle Lua errors & reload", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffCtrl+Right-click:|r Reload UI", 0.8, 0.8, 0.8)
    else
		tt:AddLine(" ")
        tt:AddLine("|cffff0000[Developer Mode]|r", 1, 0.9, 0)

        local luaOn = (GetCVar("scriptErrors") == "1")
        local luaText = luaOn and "|cff00ff00Lua errors: ON|r" or "|cffff0000Lua errors: OFF|r"
        tt:AddLine(luaText)

        tt:AddLine("|cffffffffCtrl+Left-click:|r ...", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffCtrl+Right-click:|r Toggle Minimal UI", 0.8, 0.8, 0.8)
	
	end
	

    tt:AddLine(" ")
    tt:AddLine("|cffffd200Warning: Button may emit stray ideas.|r")

    tt:Show()
end

----------------------------------------------------
-- Keybind-facing world interaction function
-- This gives you a third path, separate from left/right click.
----------------------------------------------------

function PE.WorldInteractBinding()
    -- Called from a keybinding, e.g. via Bindings.xml:
    -- <Binding name="PE_WORLD_INTERACT" header="PersonaEngine">
    --   PE.WorldInteractBinding()
    -- </Binding>

    if PE.WorldInteract then
        -- If you define a single general handler, use that
        PE.WorldInteract()
        return
    end

    if PE.WorldInteractPrimary then
        PE.WorldInteractPrimary()
        return
    end

    -- Fallback placeholder
    -- SendChatMessage("Copporclang taps the world with a curious wrench.", "SAY")
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Icon", {
        name  = "Free-floating Icon",
        class = "ui",
    })
end
