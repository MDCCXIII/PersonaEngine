-- PE_Perf.lua
-- Performance tools retired in favor of Titan Panel.
local MODULE = "Perf"
PE.LogLoad(MODULE)


function PersonaEngine_TogglePerfFrame()
    PE.Log("|cff00ff88[PersonaEngine]|r Performance metrics are now handled by Titan Panel. Perf panel toggle is retired for now until we can specifically monitor self.")
end

PE.LogInit(MODULE)
PE.RegisterModule("Perf", {
    name  = "Performance Panel",
    class = "ui",
    ok    = false,
    notes = "Disabled: awaiting refactor / TitanPanel used instead.",
})
