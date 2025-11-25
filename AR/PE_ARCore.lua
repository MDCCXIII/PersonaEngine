local MODULE = "AR Core"
-- ##################################################
-- AR/PE_ARCore.lua
-- PersonaEngine: Augmented Reality HUD core
-- Standalone-friendly, optional feature module.
-- ##################################################

local PE = _G.PE
if not PE or type(PE) ~= "table" then
    -- Allow clean removal / standalone experiments.
    return
end

local MODULE = "ARCore"

PE.AR = PE.AR or {}
local AR = PE.AR

------------------------------------------------------
-- State
------------------------------------------------------

AR.enabled     = true   -- runtime toggle
AR.initialized = false
AR.expanded    = false  -- compact vs expanded HUD

------------------------------------------------------
-- Local helpers
------------------------------------------------------

local function SafeCall(fn, ...)
    if type(fn) == "function" then
        return pcall(fn, ...)
    end
end

------------------------------------------------------
-- Public API
------------------------------------------------------

function AR.IsEnabled()
    return AR.enabled and AR.initialized
end

function AR.SetEnabled(flag)
    AR.enabled = not not flag

    if AR.enabled and AR.initialized and AR.HUD and AR.HUD.Refresh then
        AR.HUD.Refresh("ENABLE_TOGGLE")
    elseif not AR.enabled and AR.HUD and AR.HUD.HideAll then
        AR.HUD.HideAll()
    end
end

function AR.IsExpanded()
    return AR.expanded and AR.enabled and AR.initialized
end

-- For other systems to query a “snapshot” of what AR sees
function AR.GetCurrentSnapshot()
    if not AR.IsEnabled() or not AR.Scanner or not AR.Scanner.BuildSnapshot then
        return nil
    end
    return AR.Scanner.BuildSnapshot()
end

------------------------------------------------------
-- Init / event wiring
------------------------------------------------------

local frame

local function OnEvent(self, event, ...)
    if not AR.enabled then return end

    if event == "PLAYER_LOGIN" then
        -- Initialize scanner + HUD lazily
        SafeCall(AR.Scanner and AR.Scanner.Init)
        SafeCall(AR.HUD     and AR.HUD.Init)
        AR.initialized = true
    end

    -- Pass other events down to scanner/HUD as they care
    SafeCall(AR.Scanner and AR.Scanner.OnEvent, event, ...)
    SafeCall(AR.HUD     and AR.HUD.OnEvent, event, ...)
end

local function CreateEventFrame()
    if frame then return end

    frame = CreateFrame("Frame", "PE_ARCoreFrame", UIParent)
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("PLAYER_LOGIN") -- Scanner/HUD can ask ARCore to register more via helper
end

function AR.RegisterEvent(evt)
    if not frame then
        CreateEventFrame()
    end
    frame:RegisterEvent(evt)
end

-- Kick off
CreateEventFrame()

----------------------------------------------------
-- Module registration
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("AR Core", {
    name  = "AR Core Systems",
    class = "AR HUD",
})