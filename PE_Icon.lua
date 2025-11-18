-- ##################################################
-- PE_Icon.lua
-- Minimap / DataBroker launcher + draggable status button
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
-- LDB / LibDBIcon integration (optional)
----------------------------------------------------

local LDB, Icon

if LibStub then
    LDB  = LibStub("LibDataBroker-1.1", true)
    Icon = LibStub("LibDBIcon-1.0", true)
end

-- LDB data source for displays (Bazooka, etc.)
local obj
if LDB then
    obj = LDB:NewDataObject("PersonaEngine", {
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

    if Icon then
        Icon:Register("PersonaEngine", obj, PersonaEngineDB.minimap or {})
    end
end

----------------------------------------------------
-- Custom free-floating status button
----------------------------------------------------

local function PersonaEngine_CreateButton()
    if PersonaEngineButton then
        return PersonaEngineButton
    end

    local cfg = PersonaEngineDB.button or {}
    local d   = PersonaEngine_ButtonDefaults or {}

    local btn = CreateFrame("Button", "PersonaEngineButton", UIParent)

    -- Base size & scale from config/defaults
    btn:SetSize(32, 32)
    btn:SetScale(cfg.scale or d.scale or 1.0)

    -- Strata & level from config/defaults
    local strata = cfg.strata or d.strata or "MEDIUM"
    btn:SetFrameStrata(strata)
    local lvl = cfg.level or d.level
    if lvl then
        btn:SetFrameLevel(lvl)
    else
        local parentLevel = (btn:GetParent() and btn:GetParent():GetFrameLevel()) or 0
        btn:SetFrameLevel(parentLevel + 1)
    end

    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    -- Position restore: free-floating in top-right-ish region
    btn:SetPoint(
        cfg.point or d.point or "TOPRIGHT",
        UIParent,
        cfg.relPoint or d.relPoint or "TOPRIGHT",
        cfg.x or d.x or 0,
        cfg.y or d.y or 0
    )

    ------------------------------------------------
    -- Icon texture
    ------------------------------------------------
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\PersonaEngine\\references\\persona_brain_icon.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    ------------------------------------------------
    -- Border texture with tweakable offset
    ------------------------------------------------
    local borderFrame = CreateFrame("Frame", nil, btn)
    borderFrame:SetAllPoints(btn)

    local border = borderFrame:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local offsetX = 10.5
    local offsetY = -10.1

    border:ClearAllPoints()
    border:SetPoint("CENTER", borderFrame, "CENTER", offsetX, offsetY)
    border:SetSize(btn:GetWidth() + 22, btn:GetHeight() + 22)
    btn.border = border

    ------------------------------------------------
    -- Optional highlight
    ------------------------------------------------
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    ------------------------------------------------
    -- Drag behavior (persist position)
    ------------------------------------------------
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

-- Slight delay so SavedVariables and globals are ready
if C_Timer and C_Timer.After then
    C_Timer.After(0.1, PersonaEngine_CreateButton)
else
    PersonaEngine_CreateButton()
end

----------------------------------------------------
-- Shared click + tooltip logic (global on purpose)
----------------------------------------------------

function PersonaEngine_Button_OnClick(self, button)
    if PersonaEngineDB.DevMode and PE.Log then
        PE.Log(5, "|cffffff00[Debug] Click detected: button =", button,
            "ctrl =", tostring(IsControlKeyDown()),
            "shift =", tostring(IsShiftKeyDown()),
            "alt =", tostring(IsAltKeyDown()))
    end

    -- DevMode Ctrl+Left: toggle perf panel
    if PersonaEngineDB.DevMode and IsControlKeyDown() and button == "LeftButton" then
        if _G.PersonaEngine_TogglePerfFrame then
            _G.PersonaEngine_TogglePerfFrame()
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
                    if PE.Log then
                        PE.Log(4, "|cff88ff88[Dev] scriptErrors = 0|r")
                    end
                else
                    SetCVar("scriptErrors", 1)
                    if PE.Log then
                        PE.Log(4, "|cffff8888[Dev] scriptErrors = 1|r")
                    end
                end
                ReloadUI()
                return
            elseif button == "RightButton" then
                if PE.Log then
                    PE.Log(4, "|cffffff00[Dev] Reloading UI...|r")
                end
                ReloadUI()
                return
            end
        end
        -- If DevMode is off, Shift does nothing special for now.
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
            local line = (#pool > 0 and pool[math.random(#pool)]) or "Speech module online."
            SendChatMessage(line, "SAY")
            if PE.Log then
                PE.Log("|cff00ff00Persona Engine Enabled|r")
            end
        else
            -- Engine disabled
            local offPool = PE_EngineOffLines or {}
            local line = (#offPool > 0 and offPool[math.random(#offPool)]) or "Speech module offline."
            SendChatMessage(line, "SAY")
            if PE.Log then
                PE.Log("|cffff0000Persona Engine Disabled|r")
            end

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
    if not tt or not tt.AddLine then
        return
    end

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

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Icon", {
        name  = "Minimap Icon",
        class = "ui",
    })
end
