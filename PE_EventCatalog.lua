-- PE_EventCatalog.lua
local MODULE = "EventCatalog"
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
            phraseKey   = "FRIEND_WHISPER",
            cooldown    = nil, -- use catalog default if nil
        },
        NPC_TALK = {
            enabled     = true,
            phraseKey   = "NPC_TALK",
        },
        AFK_WARNING = {
            enabled     = true,
            phraseKey   = "AFK_WARNING",
        },
    },
    combat = {
        LOW_HEALTH = {
            enabled     = true,
            phraseKey   = "LOW_HEALTH",
            cooldown    = 20,
        },
        ENEMY_TALK = {
            enabled     = true,
            phraseKey   = "ENEMY_TALK",
        },
        HEAL_INCOMING = {
            enabled     = true,
            phraseKey   = "HEAL_INCOMING",
        },
        FRIEND_WHISPER = {
            enabled     = true,
            phraseKey   = "FRIEND_WHISPER",
            cooldown    = 15,
        },
		SELF_HEAL = {
			id              = "SELF_HEAL",
			category        = "combat",
			description     = "Player performs a significant self-heal.",
			payload         = { "amount", "spellId", "spellName" },
			defaultCooldown = 12,
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

DB.states  = DB.states  or {}
DB.state   = DB.state   or "idle"
DB.enabled = (DB.enabled ~= false)

applyDefaults(DB.states, defaultStateEvents)

Config.db = DB  -- runtime handle for other files

PE.LogInit(MODULE)
PE.RegisterModule("EventCatalog", {
    name  = "Event Catalog",
    class = "data",
})