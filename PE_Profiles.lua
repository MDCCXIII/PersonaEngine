-- PE_Profiles.lua
-- Profiles, SavedVariables, active profile helpers
local MODULE = "Profiles"
PE.LogLoad(MODULE)


-- Make sure DB + profiles table exist, even if globals haven't run yet
PersonaEngineDB = PersonaEngineDB or {}
PersonaEngineDB.profiles = PersonaEngineDB.profiles or {}

local DEFAULT_PROFILE_KEY = "Copporclang_Default"

-- If the builder exists and the default profile is missing, create it
if PersonaEngine_BuildDefaultCopporclang
   and not PersonaEngineDB.profiles[DEFAULT_PROFILE_KEY] then
    PersonaEngineDB.profiles[DEFAULT_PROFILE_KEY] = PersonaEngine_BuildDefaultCopporclang()
end

function PersonaEngine_GetActiveProfileKey()
    -- always fall back to our known default key
    return PersonaEngineDB.currentProfileKey or DEFAULT_PROFILE_KEY
end

function PersonaEngine_GetActiveProfile()
    local key = PersonaEngine_GetActiveProfileKey()
    local profiles = PersonaEngineDB.profiles or {}

    -- If profile is missing but we have a builder for the default, lazily create it
    if not profiles[key]
       and PersonaEngine_BuildDefaultCopporclang
       and key == DEFAULT_PROFILE_KEY then
        profiles[key] = PersonaEngine_BuildDefaultCopporclang()
    end

    return profiles[key]
end

function PersonaEngine_SetActiveProfile(key)
    local profiles = PersonaEngineDB.profiles or {}
    if profiles[key] then
        PersonaEngineDB.currentProfileKey = key
        PE.Log("|cff00ff88Persona Engine profile set to:|r " .. key)
    else
        PE.Log("|cffff0000Persona Engine profile not found:|r " .. tostring(key))
    end
end


PE.LogInit(MODULE)
PE.RegisterModule("Profiles", {
    name  = "Profile Manager",
    class = "data",
})
