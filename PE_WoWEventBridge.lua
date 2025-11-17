-- ##################################################
-- PE_WoWEventBridge.lua
-- Bridges Blizzard events into PersonaEngine events
-- ##################################################

local MODULE = "EventBridge"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

-- Safe logging wrapper
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Local API upvalues (perf + no new globals)
----------------------------------------------------
local CreateFrame               = CreateFrame
local GetTime                   = GetTime
local UnitAffectingCombat       = UnitAffectingCombat
local UnitHealth                = UnitHealth
local UnitHealthMax             = UnitHealthMax
local UnitIsAFK                 = UnitIsAFK
local UnitGUID                  = UnitGUID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitIsUnit 				= UnitIsUnit


----------------------------------------------------
-- Runtime container
----------------------------------------------------
PE.Runtime = PE.Runtime or {}
local Runtime = PE.Runtime

Runtime.state      = Runtime.state      or "idle"
Runtime.cooldowns  = Runtime.cooldowns  or {}
Runtime._wasAFK    = Runtime._wasAFK    or false
Runtime._isAFK     = Runtime._isAFK     or false
Runtime._afkReleaseAt = Runtime._afkReleaseAt or 0
Runtime.lastActivityAt = Runtime.lastActivityAt or GetTime()

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

-- NEW: events used for activity tracking
f:RegisterEvent("PLAYER_STARTED_MOVING")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_SPELLCAST_SENT")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_YELL")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_GUILD")

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

----------------------------------------------------
-- Activity tracker: called whenever we know the
-- player did something “real” (moved, cast, etc.)
----------------------------------------------------
local function Persona_RegisterActivity()
    local now = GetTime()
    Runtime.lastActivityAt = now
end

-- Schedule first idle window after load; we’ll reset again on login.
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
	
	if Runtime._isAFK then 
		return 
	end

    local now = GetTime()
    if now < idleNextAt then
        return
    end

    -- Time's up: ask EventEngine to try CHARACTER_IDLE
    if Runtime.TriggerEvent then
        Runtime.TriggerEvent("CHARACTER_IDLE", {})
    end

    -- Whether or not it actually spoke (cooldown may block),
    -- schedule the next window.
    Persona_ScheduleNextIdle()
end

f:SetScript("OnUpdate", Persona_IdleOnUpdate)

----------------------------------------------------
-- AFK transition handler
----------------------------------------------------
local function HandleAFKChange()
    local isAFK  = UnitIsAFK("player") and true or false
    local wasAFK = Runtime._isAFK or false

    -- Update flags so PE.CanSpeak sees the correct state
    Runtime._isAFK  = isAFK
    Runtime._wasAFK = isAFK

    if isAFK and not wasAFK then
        -- NOT AFK → AFK: hard mute, clear any cooldown
        Runtime._afkReleaseAt = 0

        -- Optional: AFK_WARNING event (muted anyway while _isAFK)
        if Runtime.TriggerEvent then
            Runtime.TriggerEvent("AFK_WARNING", {})
        end

    elseif (not isAFK) and wasAFK then
        -- AFK → NOT AFK: start a short “no talking” window
        Runtime._afkReleaseAt = GetTime() + 2
    end
end



----------------------------------------------------
-- Main event handler
----------------------------------------------------
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Persona_OnLogin()
        Persona_RegisterActivity()

    elseif event == "PLAYER_REGEN_DISABLED" then
        Runtime.state = "combat"
        Persona_RegisterActivity()

    elseif event == "PLAYER_REGEN_ENABLED" then
        Runtime.state = "idle"
        Persona_RegisterActivity()

    elseif event == "PLAYER_STARTED_MOVING" then
        Persona_RegisterActivity()

    elseif event == "PLAYER_TARGET_CHANGED" then
        Persona_RegisterActivity()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit = ...
        if unit == "player" then
            Persona_RegisterActivity()
        end

    elseif event == "CHAT_MSG_SAY"
        or event == "CHAT_MSG_YELL"
        or event == "CHAT_MSG_PARTY"
        or event == "CHAT_MSG_GUILD"
        or event == "CHAT_MSG_WHISPER" then

        local msg, sender = ...
        if sender and UnitIsUnit(sender, "player") then
            Persona_RegisterActivity()
        end
    end
	
	if event == "PLAYER_LOGIN" then
        -- Seed state on login
        if Runtime.SetState then
            if UnitAffectingCombat("player") then
                Runtime.SetState("combat")
            else
                Runtime.SetState("idle")
            end
        end

        -- Reset idle scheduling cleanly on login
        Persona_ScheduleNextIdle()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        if Runtime.SetState then
            Runtime.SetState("combat")
        end

        if Runtime.TriggerEvent then
            Runtime.TriggerEvent("ENTERING_COMBAT", {})
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat
        if Runtime.SetState then
            Runtime.SetState("idle")
        end

        Persona_ScheduleNextIdle()

    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit ~= "player" then
            return
        end

        local hp  = UnitHealth("player")
        local max = UnitHealthMax("player")
        if max <= 0 then
            return
        end

        local pct = hp / max

        local threshold = 0.35
        if PE.Config and PE.Config.db and PE.Config.db.lowHealthThreshold then
            threshold = PE.Config.db.lowHealthThreshold
        end

        if pct <= threshold and Runtime.TriggerEvent then
            Runtime.TriggerEvent("LOW_HEALTH", {
                hpPercent = pct,
                hp        = hp,
                maxHp     = max,
            })
        end

    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...

        if Runtime.TriggerEvent then
            Runtime.TriggerEvent("FRIEND_WHISPER", {
                message = msg,
                sender  = sender,
            })
        end

    elseif event == "CHAT_MSG_MONSTER_SAY"
        or event == "CHAT_MSG_MONSTER_YELL"
    then
        local msg, sender = ...

        if Runtime.TriggerEvent then
            Runtime.TriggerEvent("NPC_TALK", {
                message = msg,
                sender  = sender,
                channel = (event == "CHAT_MSG_MONSTER_YELL") and "YELL" or "SAY",
            })
        end

    elseif event == "PLAYER_FLAGS_CHANGED" then
        local unit = ...
        if unit == "player" then
            HandleAFKChange()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent,
              _, srcGUID, srcName, srcFlags,
              _, dstGUID, dstName, dstFlags,
              _, spellId, spellName, _, amount =
            CombatLogGetCurrentEventInfo()

        if subevent ~= "SPELL_HEAL" and subevent ~= "SPELL_PERIODIC_HEAL" then
            return
        end

        local playerGUID = UnitGUID("player")
        if dstGUID ~= playerGUID then
            return
        end

        local maxHP = UnitHealthMax("player")
        if maxHP <= 0 then
            return
        end

        amount = amount or 0
        local frac = amount / maxHP

        local cfg = (PE.Config and PE.Config.db) and PE.Config.db or {}
        local healThreshold     = cfg.healThreshold     or 0.10 -- external
        local selfHealThreshold = cfg.selfHealThreshold or 0.15 -- self

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

            if Runtime.TriggerEvent then
                Runtime.TriggerEvent("SELF_HEAL", {
                    sourceName = srcName,
                    amount     = amount,
                    spellId    = spellId,
                    spellName  = spellName,
                })
            end
        else
            -- Only react to meaningful external heals
            if frac < healThreshold then
                return
            end

            if Runtime.TriggerEvent then
                Runtime.TriggerEvent("HEAL_INCOMING", {
                    sourceName = srcName,
                    amount     = amount,
                    spellId    = spellId,
                    spellName  = spellName,
                })
            end
        end
    end
end)

----------------------------------------------------
-- Module registration
----------------------------------------------------
if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "WoW Event Bridge",
        class = "engine",
    })
end
