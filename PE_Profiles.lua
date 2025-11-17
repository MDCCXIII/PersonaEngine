-- ##################################################
-- PE_Profiles.lua
-- Profiles, SavedVariables, active profile helpers
-- ##################################################

local MODULE = "Profiles"

-- Root PE table should be defined in PE_Globals.lua
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

-- Namespace for profile helpers (no new globals)
PE.Profiles = PE.Profiles or {}
local Profiles = PE.Profiles

----------------------------------------------------
-- Defaults and bootstrapping
----------------------------------------------------

-- Canonical default key; must match PE_Globals.lua
Profiles.DEFAULT_PROFILE_KEY = Profiles.DEFAULT_PROFILE_KEY or "Copporclang_Default"
local DEFAULT_PROFILE_KEY = Profiles.DEFAULT_PROFILE_KEY

-- Ensure table exists
PersonaEngineDB.profiles          = PersonaEngineDB.profiles or {}
PersonaEngineDB.currentProfileKey = PersonaEngineDB.currentProfileKey or DEFAULT_PROFILE_KEY

-- If the builder exists and the default profile is missing, create it
if type(_G.PersonaEngine_BuildDefaultCopporclang) == "function"
   and not PersonaEngineDB.profiles[DEFAULT_PROFILE_KEY]
then
    PersonaEngineDB.profiles[DEFAULT_PROFILE_KEY] =
        _G.PersonaEngine_BuildDefaultCopporclang()
end

----------------------------------------------------
-- Public API (under PE.Profiles)
----------------------------------------------------

function Profiles.GetActiveProfileKey()
    -- Always fall back to our known default key
    return PersonaEngineDB.currentProfileKey or DEFAULT_PROFILE_KEY
end

function Profiles.GetActiveProfile()
    local key = Profiles.GetActiveProfileKey()
    local profiles = PersonaEngineDB.profiles or {}

    -- If profile is missing but we have a builder for the default, lazily create it
    if not profiles[key]
       and type(_G.PersonaEngine_BuildDefaultCopporclang) == "function"
       and key == DEFAULT_PROFILE_KEY
    then
        profiles[key] = _G.PersonaEngine_BuildDefaultCopporclang()
    end

    return profiles[key]
end

function Profiles.SetActiveProfile(key)
    local profiles = PersonaEngineDB.profiles or {}
    if profiles[key] then
        PersonaEngineDB.currentProfileKey = key
        if PE.Log then
            PE.Log("INFO", "|cff00ff88Persona Engine profile set to:|r " .. key)
        end
    else
        if PE.Log then
            PE.Log("WARN", "|cffff0000Persona Engine profile not found:|r " .. tostring(key))
        end
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Profile Manager",
        class = "data",
    })
end
