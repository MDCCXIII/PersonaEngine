-- ##################################################
-- PE_WoWEventBridge.lua
-- Bridges Blizzard events into PersonaEngine events
-- ##################################################

local MODULE  = "EventBridge"
local PE      = PE
local Runtime = PE.Runtime

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

Runtime.state      = Runtime.state or "idle"
Runtime.cooldowns  = Runtime.cooldowns or {}
Runtime._wasAFK    = Runtime._wasAFK or false

----------------------------------------------------
-- Event frame
----------------------------------------------------
local f = CreateFrame("Frame")
Runtime.eventFrame = f

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_MONSTER_SAY")
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

----------------------------------------------------
-- Idle scheduler: random CHARACTER_IDLE musings
-- Fires between ~90s and ~10min of idle time
----------------------------------------------------
local idleNextAt = nil

local function Persona_ScheduleNextIdle()
    local now = GetTime()
    -- random interval between 90s (1.5min) and 600s (10min)
    idleNextAt = now + math.random(90, 600)
end

-- Schedule first idle window after login
Persona_ScheduleNextIdle()

local function Persona_IdleOnUpdate(self, elapsed)
    if not idleNextAt then
        return
    end

    -- Only care when actually idle and not in combat
    if UnitAffectingCombat("player") then
        return
    end

    if Runtime.state ~= "idle" then
        return
    end

    local now = GetTime()
    if now < idleNextAt then
        return
    end

    -- Time's up: ask EventEngine to try CHARACTER_IDLE
    Runtime.TriggerEvent("CHARACTER_IDLE", {})

    -- Whether or not it actually spoke (cooldown may block),
    -- schedule the next window.
    Persona_ScheduleNextIdle()
end

f:SetScript("OnUpdate", Persona_IdleOnUpdate)

----------------------------------------------------
-- AFK transition handler
----------------------------------------------------
local function HandleAFKChange()
    local isAFK  = UnitIsAFK("player")
    local wasAFK = Runtime._wasAFK or false

    if isAFK and not wasAFK then
        -- Transition: NOT AFK → AFK
        Runtime.TriggerEvent("AFK_WARNING", {})
    end

    Runtime._wasAFK = isAFK
end

----------------------------------------------------
-- Main event handler
----------------------------------------------------
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if UnitAffectingCombat("player") then
            Runtime.SetState("combat")
        else
            Runtime.SetState("idle")
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        Runtime.SetState("combat")
        Runtime.TriggerEvent("ENTERING_COMBAT", {})

    elseif event == "PLAYER_REGEN_ENABLED" then
        Runtime.SetState("idle")
        Persona_ScheduleNextIdle()

    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit ~= "player" then return end

        local hp  = UnitHealth("player")
        local max = UnitHealthMax("player")
        if max <= 0 then return end

        local pct = hp / max

        local threshold = 0.35
        if PE and PE.Config and PE.Config.db and PE.Config.db.lowHealthThreshold then
            threshold = PE.Config.db.lowHealthThreshold
        end

        if pct <= threshold then
            Runtime.TriggerEvent("LOW_HEALTH", {
                hpPercent = pct,
                hp        = hp,
                maxHp     = max,
            })
        end

    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        Runtime.TriggerEvent("FRIEND_WHISPER", {
            message = msg,
            sender  = sender,
        })

    elseif event == "CHAT_MSG_MONSTER_SAY" or event == "CHAT_MSG_MONSTER_YELL" then
        local msg, sender = ...
        Runtime.TriggerEvent("NPC_TALK", {
            message = msg,
            sender  = sender,
            channel = (event == "CHAT_MSG_MONSTER_YELL") and "YELL" or "SAY",
        })

    elseif event == "PLAYER_FLAGS_CHANGED" then
        local unit = ...
        if unit == "player" then
            HandleAFKChange()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags, _,
              spellId, spellName, _, amount =
            CombatLogGetCurrentEventInfo()

        if subevent ~= "SPELL_HEAL" and subevent ~= "SPELL_PERIODIC_HEAL" then
            return
        end

        local playerGUID = UnitGUID("player")
        if dstGUID ~= playerGUID then
            return
        end

        local maxHP = UnitHealthMax("player")
        if maxHP <= 0 then return end

        amount = amount or 0
        local frac = amount / maxHP

        local cfg = (PE and PE.Config and PE.Config.db) and PE.Config.db or {}
        local healThreshold     = cfg.healThreshold     or 0.10  -- external
        local selfHealThreshold = cfg.selfHealThreshold or 0.15  -- self

        local isSelf = (srcGUID == playerGUID)

        if isSelf then
            -- Ignore passive/self periodic ticks (leech, auras)
            if subevent == "SPELL_PERIODIC_HEAL" then
                return
            end
            -- Only big self-heals
            if frac < selfHealThreshold then
                return
            end

            Runtime.TriggerEvent("SELF_HEAL", {
                sourceName = srcName,
                amount     = amount,
                spellId    = spellId,
                spellName  = spellName,
            })
        else
            -- Only react to meaningful external heals
            if frac < healThreshold then
                return
            end

            Runtime.TriggerEvent("HEAL_INCOMING", {
                sourceName = srcName,
                amount     = amount,
                spellId    = spellId,
                spellName  = spellName,
            })
        end
    end
end)

----------------------------------------------------
-- Module registration
----------------------------------------------------
if PE.LogInit then
    PE.LogInit(MODULE)
end

PE.RegisterModule("EventBridge", {
    name  = "WoW Event Bridge",
    class = "engine",
})
