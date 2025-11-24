-- ##################################################
-- PE_Globals.lua
-- Central root namespace, logging, SavedVariables,
-- module registration, and startup reporting
-- ##################################################

if not PE then
    PE = {}
end

----------------------------------------------------
-- Logging Level + core logger
----------------------------------------------------

PE_LogLevel = PE_LogLevel or 3
-- Levels:
-- 0 NONE, 1 ERROR, 2 WARN, 3 INFO, 4 DEBUG, 5 TRACE

local function PersonaEngine_Log(levelOrMsg, ...)
    if not PE_LogLevel then
        PE_LogLevel = 3
    end

    local lvl
    local parts = {}

    if type(levelOrMsg) == "number" then
        lvl = levelOrMsg
    else
        lvl = 3
        if levelOrMsg ~= nil then
            table.insert(parts, levelOrMsg)
        end
    end

    if lvl > PE_LogLevel or lvl == 0 then
        return
    end

    for i = 1, select("#", ...) do
        local v = select(i, ...)
        table.insert(parts, tostring(v))
    end

    if #parts == 0 then
        return
    end

    local final  = table.concat(parts, " ")
    local tstamp = date("%H:%M:%S")

    local colors = {
        [1] = "|cffff0000", -- ERROR
        [2] = "|cffff8800", -- WARN
        [3] = "|cff00ff00", -- INFO
        [4] = "|cff66ccff", -- DEBUG
        [5] = "|cffff00ff", -- TRACE
    }

    local prefix = colors[lvl] or "|cffffffff"
    print(prefix .. "[Persona " .. tstamp .. "]|r " .. final)
end

PE.Log = PE.Log or PersonaEngine_Log

----------------------------------------------------
-- Module load/init logging helpers
----------------------------------------------------

function PE.LogLoad(module)
    PE.Log(4, ("|cff00ff88[PersonaEngine]|r Loading %s ..."):format(tostring(module)))
end

function PE.LogInit(module)
    PE.Log(4, ("|cff00ff88[PersonaEngine]|r %s initialized."):format(tostring(module)))
end

----------------------------------------------------
-- Top-of-file module log
----------------------------------------------------

local MODULE = "Globals"
PE.LogLoad(MODULE)

----------------------------------------------------
-- Expected module list (lint only)
----------------------------------------------------

-- Keep this aligned with PersonaEngine.toc for now.
PE.ExpectedModules = {
    "Globals",
    "Core",
    "NPCMemory",
    "VFX",
    "Icon",
    "ConfigUI",
}

----------------------------------------------------
-- Module Registry + Load Metadata
----------------------------------------------------

PE.Modules      = PE.Modules or {}
PE._loadStarted = PE._loadStarted or (debugprofilestop and debugprofilestop() or nil)

function PE.RegisterModule(id, info)
    if type(id) ~= "string" then
        return
    end

    info        = info or {}
    info.id     = id
    info.name   = info.name or id
    info.class  = info.class or "core"
    info.ok     = (info.ok ~= false)
    info.loadedAt = debugprofilestop and debugprofilestop() or nil

    PE.Modules[id] = info
end

----------------------------------------------------
-- Startup Report (fired once at PLAYER_LOGIN)
----------------------------------------------------

local function PersonaEngine_ReportStatus()
    local mods       = PE.Modules or {}
    local total      = 0
    local okCount    = 0
    local badCount   = 0
    local byClass    = {}

    for _, m in pairs(mods) do
        total = total + 1

        if m.ok == false then
            badCount = badCount + 1
        else
            okCount = okCount + 1
        end

        local class = m.class or "other"
        byClass[class] = byClass[class] or { total = 0, bad = 0 }
        byClass[class].total = byClass[class].total + 1
        if m.ok == false then
            byClass[class].bad = byClass[class].bad + 1
        end
    end

    ------------------------------------------------
    -- LINT: missing expected modules
    ------------------------------------------------
    local missing    = {}
    local registered = {}

    for id in pairs(mods) do
        registered[id] = true
    end

    for _, id in ipairs(PE.ExpectedModules or {}) do
        if not registered[id] then
            table.insert(missing, id)
            mods[id] = {
                id    = id,
                name  = id,
                class = "unknown",
                ok    = false,
                notes = "Module never registered (missing PE.RegisterModule?)",
            }
            badCount = badCount + 1
            total    = total + 1
        end
    end

    ------------------------------------------------
    -- Class summary text
    ------------------------------------------------
    local classBits = {}
    for cls, count in pairs(byClass) do
        table.insert(classBits, string.format("%s:%d", cls, count.total))
    end
    table.sort(classBits)

    local classSummary = (#classBits > 0) and table.concat(classBits, ", ") or "none"

    local elapsed = nil
    if PE._loadStarted and debugprofilestop then
        elapsed = debugprofilestop() - PE._loadStarted
    end

    local prefix = "|cff66ccff[PersonaEngine]|r "

    ------------------------------------------------
    -- Final output formatting
    ------------------------------------------------
    if badCount == 0 then
        local summary = string.format(
            "Copporclang's persona core online: %d subsystems active (%s).",
            total,
            classSummary
        )
        if elapsed then
            summary = summary .. string.format(" Boot time: %.1f ms.", elapsed)
        end

        print(prefix .. summary .. " All gears spinning; any explosions are absolutely intentional.")

        for _, m in pairs(mods) do
            if m.ok and m.notes then
                print(string.format(" %s (%s): %s", m.name, m.class, m.notes))
            end
        end
    else
        local summary = string.format(
            "Persona core online with %d/%d subsystems cooperating; %d are sulking.",
            okCount,
            total,
            badCount
        )
        if elapsed then
            summary = summary .. string.format(" Boot time: %.1f ms.", elapsed)
        end

        print(prefix .. summary .. " System will improvise with duct tape and optimism.")

        for _, m in pairs(mods) do
            if m.ok == false then
                print(string.format(
                    " |cffff5555%s|r (%s): %s",
                    m.name,
                    m.class,
                    m.notes or "No diagnostics."
                ))
            end
        end
    end
end

----------------------------------------------------
-- Fire report after addon load
----------------------------------------------------

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")

    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "PersonaEngine" then
            self._addonLoaded = true
            return
        end

        if event == "PLAYER_LOGIN" and self._addonLoaded and not self._reported then
            self._reported = true
            local ok, err = pcall(PersonaEngine_ReportStatus)
            if not ok then
                print("|cff66ccff[PersonaEngine]|r Status check exploded: |cffff5555" ..
                    tostring(err) .. "|r")
            end
        end
    end)
end

----------------------------------------------------
-- Namespaces (always created)
----------------------------------------------------

PE.Events         = PE.Events or {}
PE.States         = PE.States or {}
PE.Config         = PE.Config or {}
PE.Phrases        = PE.Phrases or {}
PE.Runtime        = PE.Runtime or {}
PE.DynamicPhrases = PE.DynamicPhrases or {}
PE.Structures     = PE.Structures or {}
PE.Words          = PE.Words or {}

----------------------------------------------------
-- SavedVariables bootstrap
----------------------------------------------------

PersonaEngineDB                    = PersonaEngineDB or {}
PersonaEngineDB.DevMode            = PersonaEngineDB.DevMode or false
PersonaEngineDB.profiles           = PersonaEngineDB.profiles or {}
PersonaEngineDB.currentProfileKey  = PersonaEngineDB.currentProfileKey or "Copporclang_Default"

-- Minimap settings (legacy; kept in case we re-add a minimap button later)
PersonaEngineDB.minimap = PersonaEngineDB.minimap or { hide = false }

-- Free-floating icon defaults
PersonaEngine_ButtonDefaults = {
    point    = "TOPRIGHT",
    relPoint = "TOPRIGHT",
    x        = -150,
    y        = -170,
    scale    = 1.2,
    strata   = "MEDIUM",
    level    = 1,
}

PersonaEngineDB.button = PersonaEngineDB.button or {}

----------------------------------------------------
-- Dev mode check
----------------------------------------------------

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

-- Central dev-mode helper (used by other modules)
function PE.IsDevMode()
    return PersonaEngineDB and PersonaEngineDB.DevMode == true
end


----------------------------------------------------
-- Legacy SR fields (until fully replaced)
----------------------------------------------------

SR_On = SR_On or 1
P     = P     or {}
lastP = lastP or nil

----------------------------------------------------
-- Voice Lines (loaded once)
----------------------------------------------------

PE_EngineOnLines = PE_EngineOnLines or {
    "Speech module online and dangerously opinionated!",
    "Vocal actuator recalibrated - intrusive thoughts now audible.",
    "Copporclang's voice core humming at optimal nonsense.",
    "Verbal processors spun up. Deploying quips.",
}

PE_EngineOffLines = PE_EngineOffLines or {
    "Silencing vocal subroutines. Enjoy the quiet while it lasts.",
    "Speech module powering down - thoughts reverting to internal.",
    "Muting chatter. Engineering continues silently... probably.",
    "Talky-bit disengaged. Only clangs and whirs from here.",
}

PE_EngineOffScaryLines = PE_EngineOffScaryLines or {
    "ERROR: Voice core still transmitting AFTER shutdown. That's... bad.",
    "Warning: residual chatter detected in a deactivated speech module.",
    "Glitch detected: muted channel still echoing. Did you hear that?",
}

----------------------------------------------------
-- Bottom-of-file Init + Register
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("Globals", {
    name  = "Global Systems",
    class = "core",
})
