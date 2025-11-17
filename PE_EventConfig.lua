-- ##################################################
-- PE_EventConfig.lua
-- Persona Engine - Event Configuration & Defaults
-- ##################################################

local MODULE = "EventConfig"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Ensure config container exists on PE (field only, no new global symbol)
PE.Config = PE.Config or {}
local Config = PE.Config

-- Other subsystems may be used later by this module; keep local handles ready
PE.Events  = PE.Events  or {}
PE.States  = PE.States  or {}
PE.Phrases = PE.Phrases or {}

-- Optional local references (not strictly needed here, but safe)
local Events  = PE.Events
local States  = PE.States
local Phrases = PE.Phrases

----------------------------------------------------
-- Default per-state event configuration
----------------------------------------------------
-- These are logical defaults that get merged into
-- PersonaEngineDB.events.* so user changes persist.
----------------------------------------------------

Config.stateEvents = Config.stateEvents or {}

local defaultStateEvents = {
    idle = {
        FRIEND_WHISPER = {
            enabled   = true,
            phraseKey = "FRIEND_WHISPER", -- key into PE.Phrases
            cooldown  = nil,              -- use catalog default if nil
        },
        NPC_TALK = {
            enabled   = true,
            phraseKey = "NPC_TALK",
        },
        AFK_WARNING = {
            enabled   = true,
            phraseKey = "AFK_WARNING",
            cooldown  = 30,
        },
        CHARACTER_IDLE = {
            enabled   = true,
            phraseKey = "CHARACTER_IDLE",
            cooldown  = 90,               -- one idle musing per 90s max
        },
    },

    combat = {
        LOW_HEALTH = {
            enabled   = true,
            phraseKey = "LOW_HEALTH",
            cooldown  = 3,
        },
        ENEMY_TALK = {
            enabled   = true,
            phraseKey = "ENEMY_TALK",
        },
        HEAL_INCOMING = {
            enabled   = true,
            phraseKey = "HEAL_INCOMING",
            cooldown  = 2,
        },
        SELF_HEAL = {
            enabled   = true,
            phraseKey = "SELF_HEAL",
            cooldown  = 12,
        },
        FRIEND_WHISPER = {
            enabled   = true,
            phraseKey = "FRIEND_WHISPER",
            cooldown  = 15,
        },
        ENTERING_COMBAT = {
            enabled   = true,
            phraseKey = "ENTERING_COMBAT",
            cooldown  = 10,               -- in case combat toggles rapidly
        },
    },
}

----------------------------------------------------
-- Merge defaults into SavedVariables
----------------------------------------------------

-- PersonaEngineDB is created / owned by PE_Globals.lua.
-- Here we only work under its tree, no new global names.
PersonaEngineDB.events = PersonaEngineDB.events or {}
local DB = PersonaEngineDB.events

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            applyDefaults(dst[k], v)
        else
            if dst[k] == nil then
                dst[k] = v
            end
        end
    end
end

DB.states   = DB.states   or {}
DB.state    = DB.state    or "idle"
DB.enabled  = (DB.enabled ~= false)      -- default: true

applyDefaults(DB.states, defaultStateEvents)

-- Thresholds for health-based events
DB.healThreshold      = DB.healThreshold      or 0.10 -- 10% max HP (incoming heals)
DB.selfHealThreshold  = DB.selfHealThreshold  or 0.15 -- 15% max HP (self-heals)
DB.lowHealthThreshold = DB.lowHealthThreshold or 0.35 -- 35% max HP

-- Expose runtime handle for other modules
Config.db = DB

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Event Configuration",
        class = "data",
    })
end
