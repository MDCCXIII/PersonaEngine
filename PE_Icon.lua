--TODO: we are not limited on space, why are we using cryptic, non-descriptive variable names
--TODO: at least if we are going to keep variables local instead of moving everything to globals then lets make local variables above the functions but below the headers so we can easily see and update values and know what the values are for if the variable names are descriptive in their naming convention 

-- ##################################################
-- PE_Icon.lua
-- Free-floating status button (no minimap LibDBIcon)
-- ##################################################

local MODULE = "Icon"
local PE = PE

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
-- Optional LDB object (no minimap icon)
----------------------------------------------------

local LDB
if LibStub then
    LDB = LibStub("LibDataBroker-1.1", true)
end

if LDB then
    LDB:NewDataObject("PersonaEngine", {
        type = "data source",
        text = "Persona Engine",
        icon = "Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga",

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

    local cfg = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)
    btn:SetSize(32, 32) --TODO: 32, 32 values should be moved to global variables so i have 1 solid and organized place to make uI updates, keep these values as defaults if global doesnt exist
    btn:SetScale(cfg.scale or d.scale or 1.2)

    btn:SetFrameStrata(cfg.strata or d.strata or "MEDIUM")
    btn:SetFrameLevel((cfg.level or d.level or 1))

    btn:SetClampedToScreen(true) --Spike: could we add a btn:SetClampedToMinimap and then toggle between screen and minimap clamp on alt + rightclick?
    btn:SetMovable(true) --TODO: hook this to a toggle option on alt + left click 
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    btn:SetPoint(
        cfg.point or d.point or "TOPRIGHT",
        UIParent,
        cfg.relPoint or d.relPoint or "TOPRIGHT",
        cfg.x or d.x or -150,
        cfg.y or d.y or -170
    )

    ------------------------------------------------
    -- Icon texture
    ------------------------------------------------
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(20, 20) --TODO: same here move this to global, keep these values as defaults if global doesnt exist
    icon:SetTexture("Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga") --TODO: for good measure, value into globals
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    ------------------------------------------------
    -- Border texture
    ------------------------------------------------
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("CENTER", 10.5, -10.1)
    border:SetSize(54, 54)
    btn.border = border

    ------------------------------------------------
    -- Highlight
    ------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    ------------------------------------------------
    -- Drag-save
    ------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
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

-- Delay spawn so globals are ready
if C_Timer and C_Timer.After then
    C_Timer.After(0.1, PersonaEngine_CreateButton)
else
    PersonaEngine_CreateButton()
end

----------------------------------------------------
-- Click Handler
----------------------------------------------------

function PersonaEngine_Button_OnClick(self, button)
    -- DevMode Ctrl+Left: performance/debug panel
    if PersonaEngineDB.DevMode and IsControlKeyDown() and button == "LeftButton" then
        --removed perf frame -- free keybind slot available
        return
    end
	
	--TODO: just go ahead and put in the checks for left/right clicks with alt ctrl and shift mods even if we are not currently using them yet...

    -- DevMode Shift-clicks: scriptErrors / reload
    if IsShiftKeyDown() and PersonaEngineDB.DevMode then
        if button == "LeftButton" then
            local cur = GetCVar("scriptErrors")
            SetCVar("scriptErrors", (cur == "1") and 0 or 1) --TODO: this doesnt notify lua errors on/off, lets use tooltip status kind of like we have for dev mode... only show if lua errors on, otherwise keep TT clean
            ReloadUI()
            return
        elseif button == "RightButton" then
            ReloadUI()
            return
        end
    end

    -- Normal behavior
    if button == "LeftButton" then
        if PE.ToggleConfig then
            PE.ToggleConfig()
        end
        return
    end

    if button == "RightButton" then
        local old = SR_On
        SR_On = (old == 1 and 0 or 1)

        if SR_On == 1 then
            local pool = PE_EngineOnLines or {}
            local line = (#pool > 0 and pool[math.random(#pool)]) or "Speech module online."
            SendChatMessage(line, "SAY") --this could potentially cause taint if used at the wrong time, however i have never yet had this cause issue for me
            if PE.Log then PE.Log("|cff00ff00Persona Engine Enabled|r") end
        else
            local offPool = PE_EngineOffLines or {}
            local line = (#offPool > 0 and offPool[math.random(#offPool)]) or "Speech module offline."
            SendChatMessage(line, "SAY")
            if PE.Log then PE.Log("|cffff0000Persona Engine Disabled|r") end

            local scaryPool = PE_EngineOffScaryLines or {}
            if #scaryPool > 0 and math.random(20) == 1 then
                local scary = scaryPool[math.random(#scaryPool)]
                SendChatMessage(scary, "SAY") --this could potentially cause taint if used at the wrong time, however i have never yet had this cause issue for me
            end
        end
        return
    end
end

----------------------------------------------------
-- Tooltip (restored full version) --TODO: stop putting these comments in code like this, the header is great and by all means feel free to put usage or comments but it's only (restored full version) until a few days goes by and then we dont even know the difference between restored or original
----------------------------------------------------

function PersonaEngine_Button_OnTooltip(tt)
    if not tt or not tt.AddLine then
        return
    end

    tt:ClearLines()
    tt:AddLine("Persona Engine", 1, 1, 1)
    tt:AddLine("|cff00ff88Tasu Copporclang's Personality Core|r") -- added first name to surname
    tt:AddLine(" ")

    tt:AddLine("|cffffffffLeft-click:|r Open control console", 0.8, 0.8, 0.8)
    tt:AddLine("|cffffffffRight-click:|r Toggle speech module", 0.8, 0.8, 0.8)

    if PersonaEngineDB.DevMode then
        tt:AddLine("|cffffff00[Developer Mode]|r", 1, 0.9, 0) --spike: is this still a thing? should be still... 
        tt:AddLine("|cffffffffCtrl+Left-click:|r Performance panel", 0.8, 0.8, 0.8) --TODO: perf is no longer a thing
        tt:AddLine("|cffffffffShift+Left-click:|r Toggle Lua errors & reload", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffShift+Right-click:|r Reload UI", 0.8, 0.8, 0.8)
    else
        tt:AddLine("|cffa0a0a0Shift-click: Dev features disabled|r")
    end

    tt:AddLine(" ")
    tt:AddLine("|cffffd200Warning: Button may emit stray ideas.|r")

    tt:Show()   -- <- the missing piece --TODO: this is what i mean about the comments like this, missing piece ???? what? (i only know what this comment is talking about because it was recent and still fresh in my mind...
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
