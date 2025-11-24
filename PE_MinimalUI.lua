-- ##################################################
-- PE_MinimalUI.lua
-- PersonaEngine: "Tactical" minimal UI toggle
-- Hides almost everything except unit frames + minimap.
-- ##################################################

local PE = PE
if not PE or type(PE) ~= "table" then
    return
end

local MODULE = "MinimalUI"

PE.MinimalUI = PE.MinimalUI or {}
local MinimalUI = PE.MinimalUI

-- ---------------------------------------------------
-- Dev mode detection helper
-- ---------------------------------------------------
local function IsDevMode()
    -- Prefer a function if you have one
    if type(PE.IsDevMode) == "function" then
        return PE.IsDevMode()
    end
    -- Or a simple flag if you use that
    if type(PE.DEV_MODE) == "boolean" then
        return PE.DEV_MODE
    end
    return false
end

-- ---------------------------------------------------
-- List of frames to hide
--
-- You can COMMENT OUT any line whose frame you want to
-- KEEP. Leave your PersonaEngine icon OUT of this list
-- so it never gets hidden.
--
-- Key = global frame name (string, looked up in _G)
-- Value = description (for your own sanity)
-- ---------------------------------------------------
local FRAMES_TO_HIDE = {
    ---------------------------------------------------
    -- ACTION BARS / MAIN UI
    ---------------------------------------------------
    MainMenuBar             = "Main action bar + background",
    StatusTrackingBarManager= "XP / reputation bar cluster",
    MicroButtonAndBagsBar   = "Micro menu + bags bar",
    StanceBar               = "Stance / form bar",
    PetActionBarFrame       = "Default pet action bar",
    PossessBarFrame         = "Possess bar",
    OverrideActionBar       = "Override action bar (vehicles, etc.)",
    MultiBarBottomLeft      = "Bottom-left extra action bar",
    MultiBarBottomRight     = "Bottom-right extra action bar",
    MultiBarRight           = "Right-side action bar",
    MultiBarLeft            = "Second right-side action bar",
    --ZoneAbilityFrame        = "Zone ability button (special actions)",
    --ExtraActionBarFrame     = "Big extra action button",

    ---------------------------------------------------
    -- CHAT
    ---------------------------------------------------
    ChatFrame1              = "Primary chat window",
    ChatFrameMenuButton     = "Chat settings button",

    ---------------------------------------------------
    -- QUESTS / OBJECTIVES
    ---------------------------------------------------
    ObjectiveTrackerFrame   = "Quest / objective tracker",

    ---------------------------------------------------
    -- MISC TOP / BOTTOM BARS
    ---------------------------------------------------
    -- Comment these out if you like the status panels.
    -- MainStatusTrackingBarContainer = "Dragonflight status bar container",

    ---------------------------------------------------
    -- HUD / MISC FRAMES
    ---------------------------------------------------
    -- Add more here if you discover them:
    -- MinimapCluster        = "Minimap frame (KEEP THIS COMMENTED OUT if you want minimap visible)",
    -- PlayerFrame           = "Player unit frame (DO NOT HIDE if you want it visible)",
    -- TargetFrame           = "Target unit frame (DO NOT HIDE if you want it visible)",
    -- FocusFrame            = "Focus unit frame (DO NOT HIDE if you want it visible)",
    -- TargetFrameToT        = "Target-of-target frame (DO NOT HIDE if you want it visible)",
}

-- ---------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------
local function SafeSetShown(frame, show)
    if not frame or type(frame.IsShown) ~= "function" then
        return
    end
    if show then
        if frame:IsShown() ~= true and frame.Show then
            frame:Show()
        end
    else
        if frame:IsShown() and frame.Hide then
            frame:Hide()
        end
    end
end

local function ApplyHiddenState(hidden)
    for globalName in pairs(FRAMES_TO_HIDE) do
        local frame = _G[globalName]
        SafeSetShown(frame, not hidden)
    end
end

-- ---------------------------------------------------
-- Public API
-- ---------------------------------------------------
MinimalUI.hidden = MinimalUI.hidden or false

function MinimalUI:IsHidden()
    return self.hidden
end

function MinimalUI:Toggle()
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff4444[PersonaEngine:" .. MODULE .. "] Cannot toggle while in combat.|r")
        return
    end

    if IsDevMode() then
        print("|cffffcc00[PersonaEngine:" .. MODULE .. "] Dev mode active - minimal UI toggle disabled.|r")
        return
    end

    self.hidden = not self.hidden
    ApplyHiddenState(self.hidden)

    if self.hidden then
        print("|cff88ff88[PersonaEngine] Tactical HUD enabled (minimal UI).|r")
    else
        print("|cffffcc00[PersonaEngine] Full HUD restored.|r")
    end
end

-- Convenience alias for other modules:
function PE.ToggleMinimalUI()
    MinimalUI:Toggle()
end
