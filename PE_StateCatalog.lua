-- ##################################################
-- PE_StateCatalog.lua
-- Persona Engine - State Catalog
-- ##################################################

local MODULE = "StateCatalog"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    -- Hard fail early; if this happens, load order / globals are broken.
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

-- Log that we’re starting to load this module
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Ensure PE.States exists (field on PE, not a new global)
PE.States = PE.States or {}
local States = PE.States

-- ##################################################
-- Canonical State Catalog
-- ##################################################
-- priority: higher = more dominant state when multiple are true
-- duration: optional, seconds; runtime is responsible for enforcing
--           and clearing timed states like `leaving_combat`.
States.catalog = {
    idle = {
        id          = "idle",
        description = "Out of combat, not doing anything intense.",
        priority    = 10,
    },

    combat = {
        id          = "combat",
        description = "Player is in combat.",
        priority    = 100,
    },

    leaving_combat = {
        id          = "leaving_combat",
        description = "Short window immediately after combat ends.",
        priority    = 80,
        duration    = 5,  -- seconds; handled by runtime
    },
}

-- Finished initializing this module
if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "State Catalog",
        class = "data",
    })
end
