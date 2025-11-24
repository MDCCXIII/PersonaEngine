-- ##################################################
-- PE_Slash.lua
-- Slash commands (/pe) including DevMode toggle
-- ##################################################

local MODULE = "Slash"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] PE_Slash.lua loaded without PE core!|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

local function SetDevMode(enabled)
    PersonaEngineDB = PersonaEngineDB or {}
    PersonaEngineDB.DevMode = not not enabled

    local state = PersonaEngineDB.DevMode and "ON" or "OFF"
    print("|cff66ccff[PersonaEngine]|r Dev Mode: " .. state)
end

local function ToggleDevMode()
    PersonaEngineDB = PersonaEngineDB or {}
    SetDevMode(not PersonaEngineDB.DevMode)
end

SLASH_PERSONAENGINE1 = "/pe"

SlashCmdList["PERSONAENGINE"] = function(msg)
    msg = tostring(msg or "")
    msg = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "dev" or msg == "dev toggle" or msg == "devmode" or msg == "dev t" then
        ToggleDevMode()
    elseif msg == "dev on" then
        SetDevMode(true)
    elseif msg == "dev off" then
        SetDevMode(false)
    else
        print("|cff66ccff[PersonaEngine]|r Commands:")
        print("  /pe dev on|off|toggle")
    end
end

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Slash / DevMode",
        class = "core",
    })
end
