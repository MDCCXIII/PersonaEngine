-- PE_EventEngine.lua
local MODULE = "EventEngine"
PE.LogLoad(MODULE)


local PE      = PE
local Events  = PE.Events
local States  = PE.States
local Config  = PE.Config
local Phrases = PE.Phrases
local Runtime = PE.Runtime

Runtime.state     = Runtime.state or Config.db.state or "idle"
Runtime.cooldowns = Runtime.cooldowns or {}

local function Log(...)
    if PE.Log then PE.Log("INFO", ...) end
end

------------------------------------------------
-- Delayed speak for event-driven reactions
-- (1–2 second random delay)
------------------------------------------------
local function SpeakLineWithDelay(line, eventId, stateId, ctx)
    if not line or line == "" then return end

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

    local payloadLine  = line
    local payloadCtx   = ctx

    C_Timer.After(delay, function()
        -- Double-check speech permission at the moment we fire
        if PE.CanSpeak and not PE.CanSpeak(payloadCtx and payloadCtx.cfg) then
            return
        end

        -- Later we can route per-event/channel; for now SAY is fine
        SendChatMessage(payloadLine, "SAY")
    end)
end



local function getEventConfig(stateId, eventId)
    local states = Config.db.states or {}
    local sCfg   = states[stateId]
    if not sCfg then return nil end
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
    if Config.db.enabled == false then return false end
    local ecfg = getEventConfig(stateId, eventId)
    if not ecfg then return false end
    if ecfg.enabled == false then return false end
    return true
end

local function checkCooldown(eventId)
    local now     = GetTime()
    local meta    = getEventMeta(eventId) or {}
    local dbCfg   = nil
    local stateId = Runtime.state
    local stateCfg = getEventConfig(stateId, eventId)
    if stateCfg then dbCfg = stateCfg.cooldown end

    local cd = dbCfg or meta.defaultCooldown or 0
    if cd <= 0 then return true end

    local last = Runtime.cooldowns[eventId] or 0
    if (now - last) < cd then
        return false
    end
    Runtime.cooldowns[eventId] = now
    return true
end

function Runtime.SetState(stateId)
    if Runtime.state == stateId then return end
    Runtime.state = stateId
    Config.db.state = stateId -- persist
    Log("PersonaEngine state ->", stateId)
end

-- Core trigger called by WoW hooks
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

    local ecfg      = getEventConfig(stateId, eventId)
    local phraseKey = ecfg and ecfg.phraseKey or eventId

    local line = Phrases.PickLine(phraseKey, ctx, stateId, eventId)
    if not line or line == "" then
        return
    end

    -- simple context substitutions for static tokens
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
    
            -- Optional: run through inflection system
		if PE.InflectMaybe then
			line = PE.InflectMaybe(line, eventId, stateId, ctx)
		end

		-- Event-driven chatter: speak with a small delay
		SpeakLineWithDelay(line, eventId, stateId, ctx)
    end
end

PE.LogInit(MODULE)
PE.RegisterModule("EventEngine", {
    name  = "Event Engine",
    class = "engine",
})

