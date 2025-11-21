-- ##################################################
-- PE_Core.lua
-- Persona Engine core helpers + unified Speak API
-- ##################################################

local MODULE = "Core"

local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] PE_Core.lua loaded without PE core!|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

local lastP

----------------------------------------------------
-- Chat rate limiter (anti-spam safety)
----------------------------------------------------

local RATE_WINDOW_SECONDS = 8   -- sliding window length
local RATE_MAX_MESSAGES   = 5   -- allowed messages per window

local function PE_CanSendMessage()
    local now = GetTime()
    PE._rateState = PE._rateState or { windowStart = 0, count = 0 }
    local st = PE._rateState

    if now - (st.windowStart or 0) > RATE_WINDOW_SECONDS then
        st.windowStart = now
        st.count = 0
    end

    if st.count >= RATE_MAX_MESSAGES then
        return false
    end

    st.count = st.count + 1
    return true
end

----------------------------------------------------
-- Speech permission gate
----------------------------------------------------
-- Central gate used by all speech paths.
-- cfg is optional; if provided, its .enabled flag is honored.

function PE.CanSpeak(cfg)
    -- Global toggle (minimap/brain button, slash, etc.)
    if SR_On ~= 1 then
        return false
    end

    -- Per-spell explicit disable
    if cfg and cfg.enabled == false then
        return false
    end

    return true
end

----------------------------------------------------
-- Macro state helper (context only)
----------------------------------------------------

local function PE_GetMacroState()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return "combat"
    end
    return "idle"
end

PE.GetMacroState = PE.GetMacroState or PE_GetMacroState

----------------------------------------------------
-- Channel resolver
----------------------------------------------------

local function PE_ResolveChannel(channel)
    channel = channel or "SAY"

    if channel == "EMOTE" then
        return "EMOTE"
    end

    -- Instance group: prefer INSTANCE_CHAT
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if channel == "SAY" or channel == "YELL" then
            return "INSTANCE_CHAT"
        end
        return channel
    end

    -- Raid: prefer RAID
    if IsInRaid() then
        if channel == "SAY" or channel == "YELL" then
            return "RAID"
        end
        return channel
    end

    -- Party: prefer PARTY
    if IsInGroup() then
        if channel == "SAY" or channel == "YELL" then
            return "PARTY"
        end
        return channel
    end

    -- Solo + combat: SAY/YELL become EMOTE
    local inGroup  = IsInGroup() or IsInRaid()
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

    if not inGroup and inCombat and (channel == "SAY" or channel == "YELL") then
        return "EMOTE"
    end

    return channel
end

----------------------------------------------------
-- Phrase selection helper
----------------------------------------------------

local function PE_SelectLine(pool)
    if not pool or #pool == 0 then
        return nil
    end

    local line = pool[math.random(#pool)]

    -- Simple de-dupe if the pool has variety
    if #pool > 1 and line == lastP then
        line = pool[math.random(#pool)]
    end

    lastP = line
    return line
end

PE.SelectLine = PE.SelectLine or PE_SelectLine

----------------------------------------------------
-- Unified send helper
----------------------------------------------------
-- opts:
--   opts.cfg           - optional spell config (.enabled honored)
--   opts.bypassResolve - true = don't remap channel (FireBubble only)
--   opts.eventId       - optional event id for inflection
--   opts.ctx           - optional context table

local function PE_SendPersonaMessage(text, channel, opts)
    if not text or text == "" then
        return
    end

    if not PE.CanSpeak(opts and opts.cfg) then
        return
    end

    if not PE_CanSendMessage() then
        return
    end

    local outChan = channel or "SAY"
    if not (opts and opts.bypassResolve) then
        outChan = PE_ResolveChannel(outChan)
    end

    if PE.InflectMaybe then
        text = PE.InflectMaybe(text, opts and opts.eventId, nil, opts and opts.ctx)
    end

    if PE.Log then
        PE.Log(4, "[Persona] sending via", outChan, "text:", text)
    end

    local ok, err = pcall(SendChatMessage, text, outChan)
    if not ok and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000[Persona] SendChatMessage failed:|r " .. tostring(err)
        )
    end
end

PE.SendPersonaMessage = PE.SendPersonaMessage or PE_SendPersonaMessage

----------------------------------------------------
-- Delayed send helper (reaction lines)
----------------------------------------------------

local function PE_SchedulePersonaMessage(text, channel, opts, delay)
    delay = delay or 0

    if delay <= 0 or not (C_Timer and C_Timer.After) then
        PE_SendPersonaMessage(text, channel, opts)
        return
    end

    local l  = text
    local ch = channel
    local o  = opts

    C_Timer.After(delay, function()
        -- Re-check speech permission at fire time
        if PE.CanSpeak and not PE.CanSpeak(o and o.cfg) then
            return
        end
        PE_SendPersonaMessage(l, ch, o)
    end)
end

----------------------------------------------------
-- Trigger modes + runtime state
----------------------------------------------------

-- Shared label map (also consumed by ConfigUI)
--[[
This table defines the triggers we talked about in the dumps:

* ON_PRESS:
  - Every macro call is eligible.
  - Ignores cooldown / resources; pure personality.

* ON_CAST:
  - Only if the action would actually cast right now.
  - Not on cooldown, and IsUsableSpell/IsUsableItem says "yes".

* ON_CD:
  - Fires once when cooldown starts (ready -> on cooldown).

* ON_READY:
  - Fires once when cooldown finishes (on cooldown -> ready).

* ON_BUFF_ACTIVE:
  - Eligible only while this spell's buff is active on you or your pet.

* ON_NOT_GCD:
  - Eligible only when the global cooldown is currently free.
  - Good for avoiding chatter on heavy GCD spam.
]]
PE.TRIGGER_MODES = PE.TRIGGER_MODES or {
  ON_PRESS       = "On Button Press",
  ON_CAST        = "On Cast",
  ON_CD          = "When Cooldown Starts",
  ON_READY       = "When Cooldown Ready",
  ON_BUFF_ACTIVE = "While Buff Is Active",
  ON_NOT_GCD     = "When GCD Is Free",
}

-- Runtime space for per-action cooldown tracking and press windows.
local Runtime = PE.Runtime or {}
PE.Runtime = Runtime

Runtime.cooldownState = Runtime.cooldownState or {}
Runtime.pressState     = Runtime.pressState     or {}

local cooldownState = Runtime.cooldownState
local pressState    = Runtime.pressState


----------------------------------------------------
-- Cooldown + usability helpers
----------------------------------------------------

-- Returns: onCD:boolean, remaining:number (seconds)
local function PE_GetActionCooldown(kind, id)
    if not kind or not id then
        return false, 0
    end

    kind = type(kind) == "string" and string.lower(kind) or kind

    -- Spells
    if kind == "spell" and GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(id)
        if not start or start == 0 or duration == 0 or enabled == 0 then
            return false, 0
        end

        local now       = GetTime and GetTime() or 0
        local remaining = math.max(0, (start + duration) - now)
        if remaining <= 0.01 then
            return false, 0
        end

        return true, remaining
    end

    -- Items
    if kind == "item" and GetItemCooldown then
        local start, duration, enabled = GetItemCooldown(id)
        if not start or start == 0 or duration == 0 or enabled == 0 then
            return false, 0
        end

        local now       = GetTime and GetTime() or 0
        local remaining = math.max(0, (start + duration) - now)
        if remaining <= 0.01 then
            return false, 0
        end

        return true, remaining
    end

    -- Emotes / unknown: no cooldown
    return false, 0
end

-- Returns: eligible:boolean
local function PE_IsActionCastEligible(kind, id)
    kind = type(kind) == "string" and string.lower(kind) or kind

    local onCD = select(1, PE_GetActionCooldown(kind, id))
    if onCD then
        return false
    end

    -- Resource / usability checks where we can
    if kind == "spell" and IsUsableSpell then
        local usable = IsUsableSpell(id)
        if not usable then
            return false
        end
    elseif kind == "item" and IsUsableItem then
        local usable = IsUsableItem(id)
        if not usable then
            return false
        end
    end

    return true
end

----------------------------------------------------
-- Extra helpers: global cooldown + buff checks
----------------------------------------------------

local function PE_IsGlobalCooldownActive()
  if not GetSpellCooldown then
    return false
  end

  -- 61304 is the standard "global cooldown" token spell.
  local start, duration, enabled = GetSpellCooldown(61304)
  if not start or start == 0 or duration == 0 or enabled == 0 then
    return false
  end

  local now = GetTime and GetTime() or 0
  if (start + duration) <= now + 0.01 then
    return false
  end

  return true
end

-- Simple "does this spell's buff exist on player or pet?" helper.
local function PE_IsActionBuffActive(kind, id)
  if kind ~= "spell" or not GetSpellInfo then
    return false
  end

  local spellName = GetSpellInfo(id)
  if not spellName or spellName == "" then
    return false
  end

  local function HasAuraOn(unit)
    if not unit then
      return false
    end

    -- Retail-style AuraUtil
    if AuraUtil and AuraUtil.FindAuraByName then
      local auraName = AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")
      return auraName ~= nil
    elseif UnitAura then
      -- Classic-style UnitAura
      for i = 1, 40 do
        local name = UnitAura(unit, i, "HELPFUL")
        if not name then
          break
        end
        if name == spellName then
          return true
        end
      end
    end

    return false
  end

  if HasAuraOn("player") then
    return true
  end
  if UnitExists and UnitExists("pet") and HasAuraOn("pet") then
    return true
  end

  return false
end


-- Per-press window: treat closely-timed PE.Say calls as one "decision"
local PRESS_WINDOW_SECONDS = 0.10

local function BeginPressWindow()
    local now = GetTime and GetTime() or 0
    local ps  = pressState

    if not ps.lastTime or (now - ps.lastTime) > PRESS_WINDOW_SECONDS then
        ps.lastTime = now
        ps.spoke    = false
    end
end

local function HasSpokenThisPress()
    return not not pressState.spoke
end

local function MarkSpokeThisPress()
    pressState.spoke = true
end

-- Trigger gate: decides if this PE.Say call is eligible *before* chance
local function PE_ShouldSpeakForTrigger(kind, id, cfg)
  if not kind or not id or not cfg then
    return false
  end

  kind = type(kind) == "string" and string.lower(kind) or kind

  local trigger = cfg.trigger or "ON_CAST"
  trigger = string.upper(trigger or "ON_CAST")

  -- Backwards-compat alias mapping
  if trigger == "ON_CD_START" then
    trigger = "ON_CD"
  elseif trigger == "ON_CD_READY" or trigger == "ON_COOLDOWN_READY" then
    trigger = "ON_READY"
  elseif trigger == "ON_BUFF" then
    trigger = "ON_BUFF_ACTIVE"
  elseif trigger == "ON_GCD_FREE" then
    trigger = "ON_NOT_GCD"
  end

  ------------------------------------------------
  -- ON_PRESS: always eligible; we still keep cooldown state up to date
  ------------------------------------------------
  if trigger == "ON_PRESS" then
    local onCD = select(1, PE_GetActionCooldown(kind, id))
    local key = tostring(kind) .. ":" .. tostring(id)
    local st = cooldownState[key]

    if not st then
      st = { wasOnCD = onCD }
      cooldownState[key] = st
    else
      st.wasOnCD = onCD
    end

    return true
  end

  ------------------------------------------------
  -- Everything else needs cooldown state
  ------------------------------------------------
  local onCD = select(1, PE_GetActionCooldown(kind, id))
  local key = tostring(kind) .. ":" .. tostring(id)
  local st  = cooldownState[key]
  local baseline = false

  if not st then
    st = { wasOnCD = onCD }
    cooldownState[key] = st
    baseline = true
  end

  local shouldSpeak = false

  if trigger == "ON_CAST" then
    -- Only if it looks like it *would* cast right now.
    shouldSpeak = PE_IsActionCastEligible(kind, id)
    st.wasOnCD = onCD

  elseif trigger == "ON_CD" then
    -- "When Cooldown Starts": first transition ready -> on cooldown
    if not baseline and st.wasOnCD == false and onCD then
      shouldSpeak = true
    end
    st.wasOnCD = onCD

  elseif trigger == "ON_READY" then
    -- "When Cooldown Ready": first transition on CD -> ready
    if not baseline and st.wasOnCD == true and not onCD then
      shouldSpeak = true
    end
    st.wasOnCD = onCD

  elseif trigger == "ON_BUFF_ACTIVE" then
    -- Only eligible while this spell's buff is active on you or your pet.
    shouldSpeak = PE_IsActionBuffActive(kind, id)
    st.wasOnCD = onCD

  elseif trigger == "ON_NOT_GCD" then
    -- Only eligible when global cooldown is currently free.
    local gcdActive = PE_IsGlobalCooldownActive()
    shouldSpeak = not gcdActive
    st.wasOnCD = onCD

  else
    -- Unknown / future trigger types: treat as ON_CAST for safety
    shouldSpeak = PE_IsActionCastEligible(kind, id)
    st.wasOnCD = onCD
  end

  return shouldSpeak
end


----------------------------------------------------
-- Internal helpers for unified Speak() API
----------------------------------------------------

-- 1) SR-style phrase pool
local function PE_SpeakPool(spec)
    if not spec then
        return
    end

    local chan   = spec.channel or "SAY"
    local chance = spec.chance or 10
    local pool   = spec.phr
    local ctx    = spec.ctx
    local event  = spec.eventId or "SR_MACRO"

    if not PE.CanSpeak() then
        return
    end

    if not pool or #pool == 0 then
        return
    end

    if chance < 1 then
        chance = 1
    end

    if math.random(chance) ~= 1 then
        return
    end

    local line = PE.SelectLine and PE.SelectLine(pool) or PE_SelectLine(pool)
    if not line then
        return
    end

    PE_SendPersonaMessage(line, chan, {
        eventId = event,
        ctx     = ctx,
    })
end

-- 2) phraseKey-based speech
local function PE_SpeakPhraseKey(phraseKey, spec)
    if not phraseKey then
        return
    end
    if not PE.Phrases or not PE.Phrases.PickLine then
        return
    end

    spec = spec or {}
    local chance = spec.chance or 10
    if chance < 1 then
        chance = 1
    end

    if math.random(chance) ~= 1 then
        return
    end

    local channel = spec.channel or "SAY"
    local cfg     = spec.cfg
    local ctx     = spec.ctx or {}
    local stateId = spec.stateId or (PE_GetMacroState and PE_GetMacroState() or "idle")
    ctx.stateId   = ctx.stateId or stateId
    local eventId = spec.eventId or ("PHRASE_" .. tostring(phraseKey))

    local line = PE.Phrases.PickLine(phraseKey, ctx, stateId, eventId)
    if not line or line == "" then
        return
    end

    PE_SendPersonaMessage(line, channel, {
        cfg           = cfg,
        eventId       = eventId,
        ctx           = ctx,
        bypassResolve = spec.bypassResolve,
    })
end

-- 3) literal text
local function PE_SpeakLiteral(text, spec)
    if not text or text == "" then
        return
    end

    spec = spec or {}
    local chance = spec.chance or 10
    if chance < 1 then
        chance = 1
    end

    if math.random(chance) ~= 1 then
        return
    end

    local channel = spec.channel or "SAY"

    PE_SendPersonaMessage(text, channel, {
        cfg           = spec.cfg,
        eventId       = spec.eventId or "LITERAL",
        ctx           = spec.ctx,
        bypassResolve = spec.bypassResolve,
    })
end

----------------------------------------------------
-- 4) Action bubble helper (spell / item / emote)
-- used by FireBubble, Speak, and PE.Say
----------------------------------------------------

local function PE_SpeakActionBubble(kind, id, isReactionOverride, explicitCfg)
    if not kind or not id then
        return
    end
    if not PersonaEngineDB then
        return
    end

    -- normalize kind to lower
    if type(kind) == "string" then
        kind = string.lower(kind)
    end

    local cfg = explicitCfg

    -- Preferred: new actions DB
    if not cfg and PersonaEngineDB.actions and PE.MakeActionKey then
        local key = PE.MakeActionKey(kind, id)
        cfg = PersonaEngineDB.actions[key]
    end

    -- Legacy fallback: old spell table if this is a spell
    if not cfg and kind == "spell" and PersonaEngineDB.spells then
        cfg = PersonaEngineDB.spells[id]
    end

    if not cfg then
        return
    end

    if not PE.CanSpeak(cfg) then
        return
    end

    ------------------------------------------------
    -- Trigger gate (ON_PRESS / ON_CAST / ON_CD / ON_READY)
    ------------------------------------------------
    if not PE_ShouldSpeakForTrigger(kind, id, cfg) then
        return
    end

    ------------------------------------------------
    -- Per-press window: only one line can "win" each press
    ------------------------------------------------
    BeginPressWindow()

    -- If something already spoke this press, bail early.
    if HasSpokenThisPress() then
        return
    end

    ------------------------------------------------
    -- Chance gate
    ------------------------------------------------
    local chance = cfg.chance or 10
    if chance < 1 then
        chance = 1
    end
    if math.random(chance) ~= 1 then
        -- Important: failed chance does *not* consume the press.
        -- This matches the dump design where KC can fail, but Dash
        -- still gets a shot in the same macro.
        return
    end

    ------------------------------------------------
    -- Channel selection
    -- (prefer SAY/YELL/EMOTE; then first enabled)
    ------------------------------------------------
    local channel = "SAY"

    if cfg.channels and next(cfg.channels) then
        if cfg.channels.SAY then
            channel = "SAY"
        elseif cfg.channels.YELL then
            channel = "YELL"
        elseif cfg.channels.EMOTE then
            channel = "EMOTE"
        else
            for ch, on in pairs(cfg.channels) do
                if on then
                    channel = ch
                    break
                end
            end
        end
    end

    ------------------------------------------------
    -- Context build
    ------------------------------------------------
    local baseCtx = cfg.ctx or {}
    local ctx     = {}

    for k, v in pairs(baseCtx) do
        ctx[k] = v
    end

    local stateId = PE_GetMacroState and PE_GetMacroState() or "idle"
    ctx.stateId    = stateId
    ctx.actionKind = kind
    ctx.actionId   = id

    if kind == "spell" then
        ctx.spellID = id
    elseif kind == "item" then
        ctx.itemID = id
    elseif kind == "emote" then
        ctx.emoteToken = id
    end

    local eventId = cfg.eventId or ("BUBBLE_" .. tostring(kind) .. "_" .. tostring(id))

    ------------------------------------------------
    -- Phrase selection
    ------------------------------------------------
    local line

    if cfg.phraseKey and PE.Phrases and PE.Phrases.PickLine then
        line = PE.Phrases.PickLine(cfg.phraseKey, ctx, stateId, eventId)
    else
        local phrases = cfg.phrases
        if not phrases or #phrases == 0 then
            return
        end
        line = PE_SelectLine(phrases)
    end

    if not line or line == "" then
        return
    end

    ------------------------------------------------
    -- We are officially the winner for this press
    ------------------------------------------------
    MarkSpokeThisPress()

    ------------------------------------------------
    -- Action vs reaction (optional delay)
    ------------------------------------------------
    local delay = 0

    if isReactionOverride == true then
        -- Forced reaction
        local minD = cfg.reactionDelayMin or 1.0
        local maxD = cfg.reactionDelayMax or 2.5
        if maxD < minD then
            maxD = minD
        end
        delay = minD + math.random() * (maxD - minD)

    elseif isReactionOverride == false then
        delay = 0

    else
        -- Probabilistic reaction
        local rc = cfg.reactionChance or 0
        if rc > 0 and math.random() < rc then
            local minD = cfg.reactionDelayMin or 1.0
            local maxD = cfg.reactionDelayMax or 2.5
            if maxD < minD then
                maxD = minD
            end
            delay = minD + math.random() * (maxD - minD)
        end
    end

    -- Macros choose SAY/YELL/etc.; bypass resolver
    PE_SchedulePersonaMessage(
        line,
        channel,
        {
            cfg           = cfg,
            bypassResolve = true,
            eventId       = eventId,
            ctx           = ctx,
        },
        delay
    )
end

-- Spell-only wrapper, used by PE.Speak and legacy FireBubble
local function PE_SpeakSpellBubble(spellID, isReactionOverride, explicitCfg)
    if not spellID then
        return
    end
    return PE_SpeakActionBubble("spell", spellID, isReactionOverride, explicitCfg)
end

----------------------------------------------------
-- Short macro helper: PE.Say(...)
----------------------------------------------------
-- New canonical usage:
--   /run PE.Say("MyMacroName")
--   /run PE.Say(37)   -- macro index
--
-- PE.Say now looks up persona config by macro (name/index),
-- then routes through the same action bubble logic as before.

function PE.Say(ref)
    if not (PE.MacroStudio and PE.MacroStudio.GetSpeakPayload) then
        return
    end

    local kind, id, cfg = PE.MacroStudio.GetSpeakPayload(ref)
    if not kind or not id or not cfg then
        return
    end

    return PE_SpeakActionBubble(kind, id, nil, cfg)
end

----------------------------------------------------
-- Public Spell Bubble API (legacy name)
----------------------------------------------------

function PE.FireBubble(spellID, isReactionOverride)
    return PE_SpeakSpellBubble(spellID, isReactionOverride, nil)
end

----------------------------------------------------
-- Unified Macro API: PE.Speak(...)
----------------------------------------------------

function PE.Speak(...)
    local argc = select("#", ...)
    if argc == 0 then
        return
    end

    -- Single argument
    if argc == 1 then
        local spec = select(1, ...)
        local t    = type(spec)

        if t == "number" then
            -- spellID bubble
            return PE_SpeakSpellBubble(spec, nil, nil)

        elseif t == "string" then
            -- phraseKey or literal
            if PE.Phrases and PE.Phrases.registry and PE.Phrases.registry[spec] then
                return PE_SpeakPhraseKey(spec, nil)
            else
                return PE_SpeakLiteral(spec, nil)
            end

        elseif t == "table" then
            -- explicit table
            if spec.spellID then
                return PE_SpeakSpellBubble(spec.spellID, spec.isReactionOverride, spec.cfg or spec)
            end
            if spec.phraseKey then
                return PE_SpeakPhraseKey(spec.phraseKey, spec)
            end
            if spec.text then
                return PE_SpeakLiteral(spec.text, spec)
            end
            if spec.phr then
                return PE_SpeakPool(spec)
            end
        end

        return
    end

    -- Two or more arguments
    local first  = select(1, ...)
    local second = select(2, ...)
    local t1     = type(first)

    if t1 == "number" then
        -- spellID, isReactionOverride
        return PE_SpeakSpellBubble(first, second, nil)

    elseif t1 == "string" then
        -- phraseKey or literal with options table
        if type(second) == "table" or second == nil then
            if PE.Phrases and PE.Phrases.registry and PE.Phrases.registry[first] then
                return PE_SpeakPhraseKey(first, second)
            else
                return PE_SpeakLiteral(first, second)
            end
        end
    end

    -- silently ignore junk
end

----------------------------------------------------
-- Legacy Public APIs (compat)
----------------------------------------------------

-- SR pool function
function SR(a)
    return PE_SpeakPool(a)
end

-- Phrase combiner
function SetP(i, t)
    if type(t) == "table" then
        P[i] = t[math.random(#t)]
    else
        P[i] = t
    end
end

function SpeakP(c, h, n)
    if not PE.CanSpeak() then
        return
    end

    c = c or 10
    if math.random(c) ~= 1 then
        return
    end

    h = h or "SAY"
    n = n or 2

    local s = ""
    for i = 1, n do
        s = s .. (P[i] or "")
    end

    if s ~= "" then
        PE_SendPersonaMessage(s, h, { eventId = "SPEAKP" })
    end
end

----------------------------------------------------
-- Macro usage helper
----------------------------------------------------

PE.Macros = PE.Macros or {}
local Macros = PE.Macros

function Macros.GetUsage()
    local numGlobal, numChar, maxGlobal, maxChar = GetNumMacros()
    return {
        globalUsed = numGlobal,
        globalFree = maxGlobal - numGlobal,
        globalMax  = maxGlobal,
        charUsed   = numChar,
        charFree   = maxChar - numChar,
        charMax    = maxChar,
    }
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("Core", {
    name  = "Core Systems",
    class = "core",
})