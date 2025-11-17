-- ##################################################
-- PE_EventCatalog.lua
-- Default event bindings per state -> SavedVariables
-- ##################################################

local PE = PE
if not PE then
    print("|cffff0000[PersonaEngine] PE_EventCatalog.lua loaded without PE core!|r")
    return
end

local MODULE = "EventCatalog"
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

local Config = PE.Config or {}
PE.Config = Config

local pairs = pairs

-- State → Event → config defaults
-- These defaults are merged into PersonaEngineDB.events.states
Config.stateEvents = Config.stateEvents or {}

local defaultStateEvents = {
    idle = {
        FRIEND_WHISPER = {
            enabled  = true,
            phraseKey = "FRIEND_WHISPER",
            cooldown = nil, -- use catalog/global default if nil
        },
        NPC_TALK = {
            enabled  = true,
            phraseKey = "NPC_TALK",
        },
        AFK_WARNING = {
            enabled  = true,
            phraseKey = "AFK_WARNING",
        },
    },

    combat = {
        LOW_HEALTH = {
            enabled  = true,
            phraseKey = "LOW_HEALTH",
            cooldown = 20,
        },
        ENEMY_TALK = {
            enabled  = true,
            phraseKey = "ENEMY_TALK",
        },
        HEAL_INCOMING = {
            enabled  = true,
            phraseKey = "HEAL_INCOMING",
        },
        FRIEND_WHISPER = {
            enabled  = true,
            phraseKey = "FRIEND_WHISPER",
            cooldown = 15,
        },
        -- FIXED: this was a full event-definition blob; we only want state binding here
        SELF_HEAL = {
            enabled  = true,
            phraseKey = "SELF_HEAL",
            cooldown = 12, -- matches prior defaultCooldown intent
        },
    },
}

-- ##################################################
-- Merge defaults into SavedVariables
-- ##################################################

if not PersonaEngineDB then
    print("|cffff0000[PersonaEngine] PersonaEngineDB is nil in PE_EventCatalog.lua!|r")
    return
end

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

DB.states  = DB.states or {}
DB.state   = DB.state or "idle"
DB.enabled = (DB.enabled ~= false) -- default true

applyDefaults(DB.states, defaultStateEvents)

-- expose DB handle via PE.Config for other modules
Config.db = DB

-- ##################################################
-- Module registration
-- ##################################################

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("EventCatalog", {
        name  = "Event Catalog",
        class = "data",
    })
end
