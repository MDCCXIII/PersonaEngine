-- PE_Icon.lua -- used to be PE_Minimap.lua
local MODULE = "Icon"
PE.LogLoad(MODULE)

-- ##################################################
-- Minimap / DataBroker launcher
-- ##################################################
-- LDB object + custom draggable button near minimap

-- PE_Icon.lua -- used to be PE_Minimap.lua
-- LDB object + custom draggable button near minimap

local LDB, Icon

-- LibStub is only available if some library addon (or another Ace addon)
-- loaded it. When PersonaEngine is running solo, LibStub may be nil.
if LibStub then
    LDB  = LibStub("LibDataBroker-1.1", true)
    Icon = LibStub("LibDBIcon-1.0", true) -- optional; safe even if missing
else
    LDB, Icon = nil, nil
end


-- Create LDB object so LDB displays (Bazooka, etc.) can still use it
local obj
if LDB then
    obj = LDB:NewDataObject("PersonaEngine", {
        type = "data source",
        text = "Persona Engine",
        icon = "Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga",
        OnClick = function(frame, button)
            PersonaEngine_Button_OnClick(frame, button) -- we’ll define this below
        end,
        OnTooltipShow = function(tt)
            PersonaEngine_Button_OnTooltip(tt) -- also defined below
        end,
    })
end

------------------------------------------------
-- Custom button (free position, proper scale)
------------------------------------------------

local function PersonaEngine_CreateButton()
    if PersonaEngineButton then return PersonaEngineButton end

    local cfg = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)

    -- Size + scale from config
    btn:SetSize(32, 32)
    btn:SetScale(cfg.scale or d.scale or 1.0)

    -- Strata & level from config (fall back to defaults)
    local strata = cfg.strata or d.strata or "MEDIUM"
    btn:SetFrameStrata(strata)

    local lvl = cfg.level or d.level
    if lvl then
        btn:SetFrameLevel(lvl)
    else
        btn:SetFrameLevel((btn:GetParent():GetFrameLevel() or 0) + 1)
    end

    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    -- Position restore
    btn:SetPoint(
        cfg.point or d.point or "TOPRIGHT",
        UIParent,
        cfg.relPoint or d.relPoint or "TOPRIGHT",
        cfg.x or d.x or 0,
        cfg.y or d.y or 0
    )

    --------------------------------------------------
    -- Icon texture
    --------------------------------------------------
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    --------------------------------------------------
	-- Border texture with adjustable offsets
	--------------------------------------------------

	-- Create a container that always matches the button
	local borderFrame = CreateFrame("Frame", nil, btn)
	borderFrame:SetAllPoints(btn)

	-- Now apply offsets to the actual border texture
	local border = borderFrame:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	-- Desired offsets:
	local offsetX = 10.5      -- tweak these
	local offsetY = -10.1     -- tweak these

	border:ClearAllPoints()
	border:SetPoint("CENTER", borderFrame, "CENTER", offsetX, offsetY)

	-- Make border auto-scale by matching the button size
	border:SetSize(btn:GetWidth() + 22, btn:GetHeight() + 22)

	btn.border = border

    --------------------------------------------------
    -- Optional highlight
    --------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    --------------------------------------------------
    -- Drag behavior
    --------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()

        PersonaEngineDB.button.point    = point
        PersonaEngineDB.button.relPoint = relPoint
        PersonaEngineDB.button.x        = xOfs
        PersonaEngineDB.button.y        = yOfs
    end)

    --------------------------------------------------
    -- Tooltip + click
    --------------------------------------------------
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


C_Timer.After(0.1, PersonaEngine_CreateButton)



------------------------------------------------
-- Shared click + tooltip logic
------------------------------------------------

function PersonaEngine_Button_OnClick(self, button)
	if PersonaEngineDB.DevMode then
		PE.Log(5,"|cffffff00[Debug] Click detected: button =", button, 
		  "ctrl =", tostring(IsControlKeyDown()), 
		  "shift =", tostring(IsShiftKeyDown()),
		  "alt =", tostring(IsAltKeyDown()))
	end

	-- DevMode Ctrl+Left: toggle perf panel
    if PersonaEngineDB.DevMode and IsControlKeyDown() and button == "LeftButton" then
        if PersonaEngine_TogglePerfFrame then
            PersonaEngine_TogglePerfFrame()
        end
        return
    end

    -- DevMode shift-clicks
    if IsShiftKeyDown() then
        if PersonaEngineDB.DevMode then
            if button == "LeftButton" then
                local cur = GetCVar("scriptErrors")
                if cur == "1" then
                    SetCVar("scriptErrors", 0)
                    PE.Log(4,"|cff88ff88[Dev] scriptErrors = 0|r")
                else
                    SetCVar("scriptErrors", 1)
                    PE.Log(4,"|cffff8888[Dev] scriptErrors = 1|r")
                end
                ReloadUI()
                return
            elseif button == "RightButton" then
                PE.Log(4,"|cffffff00[Dev] Reloading UI...|r")
                ReloadUI()
                return
            end
        end
        -- If DevMode is off, Shift does nothing for now
    end

    -- Normal clicks
    if button == "LeftButton" then
        if PE and PE.ToggleConfig then
            PE.ToggleConfig()
        end
	elseif button == "RightButton" then
		local wasOn = (SR_On == 1)
		local nowOn = not wasOn

		-- Toggle core flag
		SR_On = nowOn and 1 or 0

		if nowOn then
			-- Engine enabled
			local pool = PE_EngineOnLines or {}
			local line = pool[math.random(#pool)] or "Speech module online."
			SendChatMessage(line, "SAY")

			PE.Log("|cff00ff00Persona Engine Enabled|r")
		else
			-- Engine disabled
			local offPool = PE_EngineOffLines or {}
			local line = offPool[math.random(#offPool)] or "Speech module offline."
			SendChatMessage(line, "SAY")

			PE.Log("|cffff0000Persona Engine Disabled|r")

			-- Rare spooky glitch line - in lore: shutdown failed
			local scaryPool = PE_EngineOffScaryLines or {}
			if #scaryPool > 0 and math.random(20) == 1 then
				local scary = scaryPool[math.random(#scaryPool)]
				SendChatMessage(scary, "SAY")
			end
		end
	end
	end

function PersonaEngine_Button_OnTooltip(tt)
    if not tt or not tt.AddLine then return end

    tt:ClearLines()
    tt:AddLine("Persona Engine", 1, 1, 1)
    tt:AddLine("|cff00ff88Copporclang's Personality Core|r")
    tt:AddLine(" ")

    tt:AddLine("|cffffffffLeft-click:|r Open control console", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffffffRight-click:|r Toggle speech module", 0.8, 0.8, 0.8)

    if PersonaEngineDB.DevMode then
        tt:AddLine("|cffffff00[Developer Mode]|r", 1, 0.9, 0)
		tt:AddLine("|cffffffffCtrl+Left-click:|r Performance panel", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffShift+Left-click:|r Toggle Lua errors & reload", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffShift+Right-click:|r Reload UI", 0.8, 0.8, 0.8)
    else
        tt:AddLine("|cffa0a0a0Shift-click: Dev features disabled|r")
    end

    tt:AddLine(" ")
    tt:AddLine("|cffffd200Warning: Button may emit stray ideas.|r")

    tt:Show()
end

PE.LogInit(MODULE)
PE.RegisterModule("Icon", {
    name  = "Minimap Icon",
    class = "ui",
})
