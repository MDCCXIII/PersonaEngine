-- PE_EventConfig.lua
local MODULE = "EventConfig"
PE.LogLoad(MODULE)


local PE      = PE
local Config  = PE.Config
local Events  = PE.Events
local States  = PE.States
local Phrases = PE.Phrases

Config.stateEvents = Config.stateEvents or {}

-- Defaults, applied into PersonaEngineDB later if needed
local defaultStateEvents = {
    idle = {
        FRIEND_WHISPER = {
            enabled     = true,
            phraseKey   = "FRIEND_WHISPER", -- key into PE.Phrases
            cooldown    = nil,              -- use catalog default if nil
        },
        NPC_TALK = {
            enabled     = true,
            phraseKey   = "NPC_TALK",
        },
        AFK_WARNING = {
            enabled     = true,
            phraseKey   = "AFK_WARNING",
            cooldown    = 30,
        },
        CHARACTER_IDLE = {
            enabled     = true,
            phraseKey   = "CHARACTER_IDLE",
            cooldown    = 90,  -- one idle musing per 90s max
        },
    },
    combat = {
        LOW_HEALTH = {
            enabled     = true,
            phraseKey   = "LOW_HEALTH",
            cooldown    = 3,
        },
        ENEMY_TALK = {
            enabled     = true,
            phraseKey   = "ENEMY_TALK",
        },
        HEAL_INCOMING = {
            enabled     = true,
            phraseKey   = "HEAL_INCOMING",
			cooldown    = 2,
        },
		SELF_HEAL = {
            enabled     = true,
            phraseKey   = "SELF_HEAL",
            cooldown    = 12,
        },

        FRIEND_WHISPER = {
            enabled     = true,
            phraseKey   = "FRIEND_WHISPER",
            cooldown    = 15,
        },
		ENTERING_COMBAT = {
            enabled     = true,
            phraseKey   = "ENTERING_COMBAT",
            cooldown    = 10, -- in case combat toggles rapidly
        },
    },
}

-- Merge into SavedVariables tree
PersonaEngineDB.events = PersonaEngineDB.events or {}
local DB = PersonaEngineDB.events

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            applyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

DB.states   = DB.states   or {}
DB.state    = DB.state    or "idle"
DB.enabled  = (DB.enabled ~= false)

applyDefaults(DB.states, defaultStateEvents)

DB.healThreshold      = DB.healThreshold      or 0.10 -- 10% max HP for external heals
DB.selfHealThreshold  = DB.selfHealThreshold  or 0.15 -- 15% max HP for self-heals
DB.lowHealthThreshold = DB.lowHealthThreshold or 0.35  -- 35% default

Config.db = DB  -- runtime handle for other files

PE.LogInit(MODULE)
PE.RegisterModule("EventConfig", {
    name  = "Event Configuration",
    class = "data",
})