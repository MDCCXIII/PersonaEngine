-- ##################################################
-- PE_Perf.lua
-- Performance tools retired in favor of Titan Panel.
-- ##################################################

local MODULE = "Perf"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

-- Optional logging hooks
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- ##################################################
-- Public API (used by DevMode click on the brain button)
-- ##################################################

function PersonaEngine_TogglePerfFrame()
    if PE.Log then
        PE.Log(
            "INFO",
            "|cff00ff88[PersonaEngine]|r Performance metrics are now handled by Titan Panel.",
            "Perf panel toggle is retired until we implement self-only monitoring."
        )
    else
        print("|cff00ff88[PersonaEngine]|r Perf panel disabled; Titan Panel handles performance.")
    end
end

-- ##################################################
-- Module registration
-- ##################################################

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Perf", {
        name  = "Performance Panel",
        class = "ui",
        ok    = true,
        notes = "Disabled: Titan Panel used instead; awaiting refactor for self-only monitoring.",
    })
end
