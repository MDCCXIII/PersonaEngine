-- ##################################################
-- PE_EventEngine.lua
-- Persona Engine - Event Runtime / Dispatcher
-- ##################################################

local MODULE = "EventEngine"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

-- Safe logging wrappers (optional)
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

local function Log(...)
    if PE.Log then
        PE.Log("INFO", ...)
    end
end

----------------------------------------------------
-- Local handles to subsystems (no new globals)
----------------------------------------------------

PE.Events  = PE.Events  or {}
PE.States  = PE.States  or {}
PE.Config  = PE.Config  or {}
PE.Phrases = PE.Phrases or {}
PE.Runtime = PE.Runtime or {}

local Events  = PE.Events
local States  = PE.States
local Config  = PE.Config
local Phrases = PE.Phrases
local Runtime = PE.Runtime

-- Ensure config DB exists (EventConfig should have created this)
Config.db = Config.db or PersonaEngineDB and PersonaEngineDB.events or {}

Runtime.state      = Runtime.state or (Config.db and Config.db.state) or "idle"
Runtime.cooldowns  = Runtime.cooldowns or {}

----------------------------------------------------
-- Delayed speak for event-driven reactions
-- 1–2 second random delay, re-checking permissions
----------------------------------------------------

local function SpeakLineWithDelay(line, eventId, stateId, ctx)
    if not line or line == "" then
        return
    end

    -- Default 1.0–2.0 second random delay
    local delay = 1 + math.random()

    -- If C_Timer is not available for some reason, just speak immediately
    if not C_Timer or not C_Timer.After then
        if PE.CanSpeak and not PE.CanSpeak(ctx and ctx.cfg) then
            return
        end
        SendChatMessage(line, "SAY")
        return
    end

    local payloadLine = line
    local payloadCtx  = ctx

    C_Timer.After(delay, function()
        -- Double-check speech permission at the moment we fire
        if PE.CanSpeak and not PE.CanSpeak(payloadCtx and payloadCtx.cfg) then
            return
        end

        -- Later we can route per-event/channel; for now SAY is fine
        SendChatMessage(payloadLine, "SAY")
    end)
end

----------------------------------------------------
-- Configuration & metadata helpers
----------------------------------------------------

local function getEventConfig(stateId, eventId)
    if not Config or not Config.db then
        return nil
    end
    local states = Config.db.states or {}
    local sCfg = states[stateId]
    if not sCfg then
        return nil
    end
    return sCfg[eventId]
end

local function getEventMeta(eventId)
    local events = PE.Events
    if not events or not events.catalog then
        return nil
    end
    return events.catalog[eventId]
end

local function isEventEnabled(stateId, eventId)
    if not Config or not Config.db then
        return false
    end

    if Config.db.enabled == false then
        return false
    end

    local ecfg = getEventConfig(stateId, eventId)
    if not ecfg then
        return false
    end

    if ecfg.enabled == false then
        return false
    end

    return true
end

----------------------------------------------------
-- Cooldown system
----------------------------------------------------

local function checkCooldown(eventId)
    local now = GetTime()

    local meta   = getEventMeta(eventId) or {}
    local dbCfg  = nil
    local stateId = Runtime.state

    local stateCfg = getEventConfig(stateId, eventId)
    if stateCfg then
        dbCfg = stateCfg.cooldown
    end

    local cd = dbCfg or meta.defaultCooldown or 0
    if cd <= 0 then
        return true
    end

    local last = Runtime.cooldowns[eventId] or 0
    if (now - last) < cd then
        return false
    end

    Runtime.cooldowns[eventId] = now
    return true
end

----------------------------------------------------
-- State control
----------------------------------------------------

function Runtime.SetState(stateId)
    if Runtime.state == stateId then
        return
    end

    Runtime.state = stateId

    if Config and Config.db then
        Config.db.state = stateId -- persist to SavedVariables
    end

    Log("PersonaEngine state ->", stateId)
end

----------------------------------------------------
-- Core trigger called by WoW hooks
----------------------------------------------------

-- ctx is a free-form context table, expected fields:
--   cfg         - event/speech config (for PE.CanSpeak)
--   hpPercent   - numeric 0–1, used for %HP%
--   sourceName  - used for %SOURCE%
--   amount      - used for %AMOUNT%
--   sender      - used for %SENDER%
function Runtime.TriggerEvent(eventId, ctx)
    local stateId = Runtime.state or "idle"

    if not isEventEnabled(stateId, eventId) then
        return
    end

    if not checkCooldown(eventId) then
        return
    end

    if PE.CanSpeak and not PE.CanSpeak(ctx and ctx.cfg) then
        return
    end

    local ecfg = getEventConfig(stateId, eventId)
    local phraseKey = (ecfg and ecfg.phraseKey) or eventId

    if not Phrases or not Phrases.PickLine then
        return
    end

    local line = Phrases.PickLine(phraseKey, ctx, stateId, eventId)
    if not line or line == "" then
        return
    end

    -- Simple context substitutions for static tokens
    if ctx then
        if ctx.hpPercent then
            line = line:gsub("%%HP%%", string.format("%.0f", ctx.hpPercent * 100))
        end
        if ctx.sourceName then
            line = line:gsub("%%SOURCE%%", ctx.sourceName)
        end
        if ctx.amount then
            line = line:gsub("%%AMOUNT%%", tostring(ctx.amount))
        end
        if ctx.sender then
            line = line:gsub("%%SENDER%%", ctx.sender)
        end
    end

    -- Optional: run through inflection system
    if PE.InflectMaybe then
        line = PE.InflectMaybe(line, eventId, stateId, ctx)
        if not line or line == "" then
            return
        end
    end

    -- Event-driven chatter: speak with a small delay
    SpeakLineWithDelay(line, eventId, stateId, ctx)
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Event Engine",
        class = "engine",
    })
end
