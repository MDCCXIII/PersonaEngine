-- PE_StateCatalog.lua
local MODULE = "StateCatalog"
PE.LogLoad(MODULE)


local PE     = PE
local States = PE.States

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
        duration    = 5,   -- seconds, handled by runtime (not yet wired)
    },
}

PE.LogInit(MODULE)
PE.RegisterModule("StateCatalog", {
    name  = "State Catalog",
    class = "data",
})
