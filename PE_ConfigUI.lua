-- ##################################################
-- PE_ConfigUI.lua
-- Persona Engine main config window + tabs
-- ##################################################

local MODULE = "ConfigUI"
local PE     = PE
local UI     = PE and PE.UI

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

local configFrame

local function BuildConfigFrame()
    if configFrame then
        return configFrame
    end

    ------------------------------------------------
    -- Window shell
    ------------------------------------------------
    if UI and UI.CreateWindow then
        configFrame = UI.CreateWindow({
            id        = "Config",
            title     = "Persona Engine – Config",
            width     = 700,
            height    = 750,
            minWidth  = 520,
            minHeight = 430,
            strata    = "DIALOG",
            level     = 100,
        })
    else
        configFrame = CreateFrame("Frame", "PersonaEngineConfigFrame", UIParent, "BasicFrameTemplateWithInset")
        configFrame:SetSize(700, 750)
        configFrame:SetPoint("CENTER")
        configFrame:SetFrameStrata("DIALOG")
        configFrame:SetFrameLevel(100)
        configFrame:SetMovable(true)
        configFrame:EnableMouse(true)
        configFrame:RegisterForDrag("LeftButton")
        configFrame:SetScript("OnDragStart", configFrame.StartMoving)
        configFrame:SetScript("OnDragStop",  configFrame.StopMovingOrSizing)

        local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if configFrame.TitleBg then
            title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
        else
            title:SetPoint("TOPLEFT", 10, -5)
        end
        title:SetText("Persona Engine – Config")
        configFrame.title = title
    end

    _G["PersonaEngineConfigFrame"] = configFrame

    ------------------------------------------------
    -- Tab pages
    ------------------------------------------------
    local macroPage   = CreateFrame("Frame", nil, configFrame)
    local settingsPage = CreateFrame("Frame", nil, configFrame)

    macroPage:SetPoint("TOPLEFT",     configFrame, "TOPLEFT",     8,  -60)
    macroPage:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -8,  8)

    settingsPage:SetPoint("TOPLEFT",     macroPage, "TOPLEFT", 0, 0)
    settingsPage:SetPoint("BOTTOMRIGHT", macroPage, "BOTTOMRIGHT", 0, 0)
    settingsPage:Hide()

    configFrame.macroPage    = macroPage
    configFrame.settingsPage = settingsPage

    local tabButtons = {}

    local function SetActivePage(idx)
        for i, btn in ipairs(tabButtons) do
            local show = (i == idx)
            if show then
                btn:LockHighlight()
                if btn.page then btn.page:Show() end
            else
                btn:UnlockHighlight()
                if btn.page then btn.page:Hide() end
            end
        end
    end

    local tab1 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab1:SetText("Macro Studio")
    tab1:SetHeight(20)
    tab1:SetWidth(tab1:GetTextWidth() + 24)
    tab1:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 12, -30)
    tab1.page = macroPage
    tab1:SetScript("OnClick", function() SetActivePage(1) end)
    tabButtons[1] = tab1

    local tab2 = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    tab2:SetText("Settings")
    tab2:SetHeight(20)
    tab2:SetWidth(tab2:GetTextWidth() + 24)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 6, 0)
    tab2.page = settingsPage
    tab2:SetScript("OnClick", function() SetActivePage(2) end)
    tabButtons[2] = tab2

    SetActivePage(1)

    -- Placeholder settings text
    local settingsLabel = settingsPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsLabel:SetPoint("TOPLEFT", 8, -8)
    settingsLabel:SetText("Persona Engine Settings (coming soon)")

    ------------------------------------------------
    -- Build Macro Studio tab via UI helper module
    ------------------------------------------------
    if UI and UI.BuildMacroStudioTab then
        UI.BuildMacroStudioTab(configFrame, macroPage)
    else
        local warn = macroPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warn:SetPoint("TOPLEFT", 8, -8)
        warn:SetText("|cffff0000Macro Studio UI module missing.|r")
    end

    return configFrame
end

----------------------------------------------------
-- Public API
----------------------------------------------------

function PE.ToggleConfig()
    local f = BuildConfigFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Config UI",
        class = "ui",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
