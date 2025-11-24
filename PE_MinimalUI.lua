-- ##################################################
-- PE_MinimalUI.lua
-- PersonaEngine: "Tactical" minimal UI toggle
-- Hides almost everything: action bars, bags, chat,
-- buffs, quest tracker, etc.
-- Leaves: minimap, Titan Panel, unit frames, PE icon.
-- ##################################################

local PE = PE
if not PE or type(PE) ~= "table" then
    return
end

local MODULE = "MinimalUI"

PE.MinimalUI = PE.MinimalUI or {}
local MinimalUI = PE.MinimalUI

------------------------------------------------------
-- Dev mode detection helper
------------------------------------------------------
local function IsDevMode()
    if type(PE.IsDevMode) == "function" then
        return PE.IsDevMode()
    end
    if type(PE.DEV_MODE) == "boolean" then
        return PE.DEV_MODE
    end
    return false
end

------------------------------------------------------
-- ALLOW LIST (these survive tactical mode)
------------------------------------------------------
local ALLOWED = {
    MinimapCluster     = true,
    PlayerFrame        = true,
    PetFrame           = true,
    TargetFrame        = true,
    TargetFrameToT     = true,
    FocusFrame         = true,
    PersonaEngineButton = true,
}

local function AllowedByPrefix(name)
    if not name then return false end
    -- Titan Panel bars & plugins
    if name:match("^TitanPanel") then
        return true
    end
    return false
end

local function IsAllowedFrame(frame)
    if not frame or frame == UIParent or frame == WorldFrame then
        return true
    end
    local name = frame:GetName()
    if not name then
        return false
    end
    if ALLOWED[name] or AllowedByPrefix(name) then
        return true
    end
    return false
end

------------------------------------------------------
-- FRAMES TO HIDE (explicit lists)
------------------------------------------------------

-- Blizzard action bars
local BLIZZARD_ACTION_BARS = {
    "MainMenuBar",              -- main bar + art
    "MainMenuBarArtFrame",
    "MainMenuBarBorder",
    "MainMenuBarOverlayFrame",

    "StatusTrackingBarManager", -- XP / rep bundle

    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",

    "StanceBar",
    "StanceBarFrame",

    "PetActionBarFrame",
    "PetActionBar",

    "PossessBarFrame",
    "ZoneAbilityFrame",
    "ExtraActionBarFrame",
}

-- Override / vehicle bar (green health bar stuff)
local OVERRIDE_BAR_FRAMES = {
    "OverrideActionBar",
    "OverrideActionBarHealthBar",
    "OverrideActionBarHealthBarBG",
    "OverrideActionBarExpBar",
    "OverrideActionBarExpBarBG",
    "OverrideActionBarEndCapL",
    "OverrideActionBarEndCapR",
    "OverrideActionBarMicroMenu",
    "OverrideActionBarButton",
    "OverrideActionBarBg",
}

-- Blizzard bags + micro menu
local BLIZZARD_BAGS_AND_MICRO = {
    "MicroButtonAndBagsBar",     -- classic micro menu + bag bar
    "MainMenuBarBackpackButton",
    "MainMenuBarBackpackFrame",
    "MainMenuBarBagButtons",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",

    -- New reagent bag + DF containers
    "ReagentBag0Slot",
    "MicroMenuContainer",
    "BagBar",
    "BagBarContainer",
    "EditModeMicroMenuContainer",
    "EditModeBagBarContainer",
}

-- Chat dock (just the main dock + button)
local CHAT_FRAMES = {
    "GeneralDockManager",   -- dock that owns ChatFrame1 etc.
    "ChatFrame1",           -- your main chat window
    "ChatFrameMenuButton",  -- little chat cog/button
    "QuickJoinToastButton", -- communities popup
}

-- Buffs / debuffs / temp enchants
local BUFF_AND_AURA_FRAMES = {
    "BuffFrame",
    "DebuffFrame",
    "TemporaryEnchantFrame",
    "BuffFrameContainer",
    "DebuffFrameContainer",
}

-- Misc HUD we don't want in tactical view
local MISC_HUD_FRAMES = {
    "ObjectiveTrackerFrame", -- quest tracker
}

-- Popular bar-addon frames (Bartender / Dominos / ElvUI)
local ADDON_ACTION_BARS = {
    -- Bartender4
    "BT4Bar1", "BT4Bar2", "BT4Bar3", "BT4Bar4",
    "BT4Bar5", "BT4Bar6", "BT4Bar7", "BT4Bar8",
    "BT4Bar9", "BT4Bar10",
    "BT4PetBar", "BT4StanceBar",
    "BT4BagBar", "BT4MicroMenu",

    -- Dominos
    "DominosBar1", "DominosBar2", "DominosBar3", "DominosBar4",
    "DominosBar5", "DominosBar6", "DominosBar7", "DominosBar8",
    "DominosBar9", "DominosBar10",
    "DominosPetBar", "DominosClassBar", "DominosPossessBar",
    "DominosVehicleBar", "DominosExtraBar", "DominosZoneAbility",
    "DominosBagBar",

    -- ElvUI
    "ElvUI_Bar1", "ElvUI_Bar2", "ElvUI_Bar3", "ElvUI_Bar4",
    "ElvUI_Bar5", "ElvUI_Bar6", "ElvUI_Bar7", "ElvUI_Bar8",
    "ElvUI_Bar9", "ElvUI_Bar10",
    "ElvUI_PetBar", "ElvUI_StanceBar",
    "ElvUI_BagBar",
}

-- Combine into one flat list of names
local FRAMES_TO_HIDE = {}

local function AddList(list)
    for _, name in ipairs(list) do
        table.insert(FRAMES_TO_HIDE, name)
    end
end

AddList(BLIZZARD_ACTION_BARS)
AddList(OVERRIDE_BAR_FRAMES)
AddList(BLIZZARD_BAGS_AND_MICRO)
AddList(CHAT_FRAMES)
AddList(BUFF_AND_AURA_FRAMES)
AddList(MISC_HUD_FRAMES)
AddList(ADDON_ACTION_BARS)

------------------------------------------------------
-- Internal helpers
------------------------------------------------------
local function SafeHide(frame)
    if frame and frame.Hide then
        frame:Hide()
    end
end

local function SafeShow(frame)
    if frame and frame.Show then
        frame:Show()
    end
end

-- Remember original shown/hidden state so we don't
-- resurrect things Blizzard had hidden.
local originalVisibility = setmetatable({}, { __mode = "k" })

-- Broad patterns to catch bar/pet/micro/button junk
local BAR_NAME_PATTERNS = {
    "^BT4",              -- any Bartender frame or button
    "ActionBar",         -- Blizzard action bar bits (containers)
    "ActionButton",      -- individual action buttons (incl. bar 6)
    "MultiBar",          -- multibar containers/buttons

    "MicroMenu",         -- micro menu containers
    "MicroButton",       -- individual micro buttons

    "BagBar",            -- bag bar containers
    "BagSlot",           -- individual bag slots
    "BackpackButton",    -- any backpack button variants
    "ReagentBag",        -- reagent bag slot/buttons

    "Bar6",              -- anything explicitly tied to "bar 6"
    "PetBar",            -- pet bar containers
    "PetActionButton",   -- pet action buttons
}

local function ShouldPatternHide(name)
    if not name then return false end
    for _, pat in ipairs(BAR_NAME_PATTERNS) do
        if name:match(pat) then
            return true
        end
    end
    return false
end

local function MarkFrame(frame, hidden)
    if not frame then return end
    if hidden then
        if originalVisibility[frame] == nil and frame.IsShown then
            originalVisibility[frame] = frame:IsShown()
        end
        SafeHide(frame)
    else
        local wasShown = originalVisibility[frame]
        if wasShown ~= nil then
            if wasShown then
                SafeShow(frame)
            else
                SafeHide(frame)
            end
            originalVisibility[frame] = nil
        end
    end
end

local function ApplyHiddenState(hidden)
    -- 1) Explicitly listed frames and pattern matches across _G
    for _, globalName in ipairs(FRAMES_TO_HIDE) do
        local frame = _G[globalName]
        MarkFrame(frame, hidden)
    end

    for name, frame in pairs(_G) do
        if type(frame) == "table" and frame.GetObjectType then
            if ShouldPatternHide(name) then
                MarkFrame(frame, hidden)
            end
        end
    end

    -- 2) Sweep all top-level UIParent children:
    --    anything NOT in the allow list also gets hidden.
    local children = { UIParent:GetChildren() }
    for _, frame in ipairs(children) do
        if not IsAllowedFrame(frame) then
            MarkFrame(frame, hidden)
        end
    end
end

------------------------------------------------------
-- Public API
------------------------------------------------------
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

-- Convenience alias for your icon handler
function PE.ToggleMinimalUI()
    MinimalUI:Toggle()
end
