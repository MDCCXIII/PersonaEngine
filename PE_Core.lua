-- Persona Engine core
local MODULE = "Core"
PE.LogLoad(MODULE)

-- Expects these globals from PE_Globals.lua:
-- SR_On  - 1 = speech enabled, 0 = muted
-- lastP  - last phrase spoken (for de-dupe)
-- P      - phrase pieces table
-- PE     - addon namespace table

----------------------------------------------------
-- Persona Engine - Chat Rate Limiter
----------------------------------------------------
-- Prevents addon-driven messages from tripping WoW's
-- chat throttle.

local RATE_WINDOW   = 8   -- seconds in a sliding window
local RATE_MAX_MSGS = 5   -- max messages allowed in that window

local function PE_CanSendMessage()
    local now = GetTime()
    PE._rateState = PE._rateState or { windowStart = 0, count = 0 }
    local st = PE._rateState

    if now - (st.windowStart or 0) > RATE_WINDOW then
        st.windowStart = now
        st.count = 0
    end

    if st.count >= RATE_MAX_MSGS then
        return false
    end

    st.count = st.count + 1
    return true
end

----------------------------------------------------
-- Persona Engine - Speech Permission Helper
----------------------------------------------------
-- Central gate used by all speech paths.
-- cfg is optional; if provided, its .enabled flag is honored.
-- NOTE: Macro-only design: no AFK / idle runtime gating here.

function PE.CanSpeak(cfg)
    -- Global toggle (slash command, minimap button, etc.)
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
-- Macro State Helper (for speech context)
----------------------------------------------------
-- Very simple: just "combat" vs "idle" for now.
-- This never drives automatic speech, only informs
-- phrase selection for macros.

local function PE_GetMacroState()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return "combat"
    end
    return "idle"
end
PE.GetMacroState = PE_GetMacroState

----------------------------------------------------
-- Persona Engine - Channel Resolver
----------------------------------------------------
-- For automated/event-driven speech we *used* to remap
-- SAY/YELL into safer channels. For macro-only chatter
-- this is still useful for non-bubble SR() calls.
-- FireBubble can explicitly bypass this resolver.

local function PE_ResolveChannel(channel)
    channel = channel or "SAY"

    if channel == "EMOTE" then
        return "EMOTE"
    end

    -- Instance group → prefer INSTANCE_CHAT over SAY/YELL
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if channel == "SAY" or channel == "YELL" then
            return "INSTANCE_CHAT"
        end
        return channel
    end

    -- Raid → prefer RAID
    if IsInRaid() then
        if channel == "SAY" or channel == "YELL" then
            return "RAID"
        end
        return channel
    end

    -- Party → prefer PARTY
    if IsInGroup() then
        if channel == "SAY" or channel == "YELL" then
            return "PARTY"
        end
        return channel
    end

    -- Solo fallback:
    -- With macro-only usage this is less critical, but we keep the
    -- EMOTE safety for non-bubble SR() calls.
    local inGroup  = IsInGroup() or IsInRaid()
    local inCombat = UnitAffectingCombat("player")

    if not inGroup and inCombat and (channel == "SAY" or channel == "YELL") then
        return "EMOTE"
    end

    -- Otherwise, honor the requested channel.
    return channel
end

----------------------------------------------------
-- Persona Engine - Phrase Selection Helper
----------------------------------------------------

local function PE_SelectLine(pool)
    if not pool or #pool == 0 then return nil end

    local line = pool[math.random(#pool)]

    -- Simple de-dupe if the pool has variety
    if #pool > 1 and line == lastP then
        line = pool[math.random(#pool)]
    end

    lastP = line
    return line
end

-- Expose in case other modules want it
PE.SelectLine = PE.SelectLine or PE_SelectLine

----------------------------------------------------
-- Persona Engine - Unified Send Helper
----------------------------------------------------
-- opts:
--   opts.cfg          - optional spell config (for .enabled)
--   opts.bypassResolve- true = don't remap channel (used by FireBubble)
--   opts.eventId      - optional abstract event id for inflection context
--   opts.ctx          - optional context table for inflection

local function PE_SendPersonaMessage(text, channel, opts)
    if not text or text == "" then return end
    if not PE.CanSpeak(opts and opts.cfg) then return end
    if not PE_CanSendMessage() then return end

    local outChan = channel or "SAY"
    if not (opts and opts.bypassResolve) then
        outChan = PE_ResolveChannel(outChan)
    end

    if PE.InflectMaybe then
        text = PE.InflectMaybe(text, opts and opts.eventId, nil, opts and opts.ctx)
    end

    -- Debug-level trace of what we're trying to send
    if PE.Log then
        PE.Log(4, "[Persona] sending via", outChan, "text:", text)
    end

    local ok, err = pcall(SendChatMessage, text, outChan)
    if not ok then
        -- Soft-fail to default chat, but do not raise an error
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff0000[Persona] SendChatMessage failed:|r " .. tostring(err)
            )
        end
    end
end

-- Expose safe send helper in case other systems need it
PE.SendPersonaMessage = PE_SendPersonaMessage

----------------------------------------------------
-- Delayed send helper (for reaction-style lines)
----------------------------------------------------

local function PE_SchedulePersonaMessage(text, channel, opts, delay)
    delay = delay or 0

    if delay <= 0 or not (C_Timer and C_Timer.After) then
        -- Immediate send or no timer available
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
-- Internal helpers for unified Speak() API
----------------------------------------------------

-- 1) SR-style phrase pool (legacy, but routed through a helper)

local function PE_SpeakPool(spec)
    if not spec then return end

    local chan   = spec.channel or "SAY"
    local chance = spec.chance or 10
    local pool   = spec.phr
    local ctx    = spec.ctx
    local event  = spec.eventId or "SR_MACRO"

    if not PE.CanSpeak() then return end
    if not pool or #pool == 0 then return end
    if math.random(chance) ~= 1 then return end

    local line = PE.SelectLine and PE.SelectLine(pool) or PE_SelectLine(pool)
    if not line then return end

    PE_SendPersonaMessage(line, chan, {
        eventId = event,
        ctx     = ctx,
    })
end

-- 2) phraseKey-based speech using the new static+dynamic engine

local function PE_SpeakPhraseKey(phraseKey, spec)
    if not phraseKey then return end
    if not PE.Phrases or not PE.Phrases.PickLine then
        return
    end

    spec = spec or {}

    local chance  = spec.chance or 10
    if chance < 1 then chance = 1 end
    if math.random(chance) ~= 1 then return end

    local channel = spec.channel or "SAY"
    local cfg     = spec.cfg
    local ctx     = spec.ctx or {}
    local stateId = spec.stateId or (PE_GetMacroState and PE_GetMacroState() or "idle")
    ctx.stateId   = ctx.stateId or stateId

    local eventId = spec.eventId or ("PHRASE_" .. tostring(phraseKey))

    local line = PE.Phrases.PickLine(phraseKey, ctx, stateId, eventId)
    if not line or line == "" then return end

    PE_SendPersonaMessage(line, channel, {
        cfg          = cfg,
        eventId      = eventId,
        ctx          = ctx,
        bypassResolve= spec.bypassResolve, -- optional override
    })
end

-- 3) literal text (direct string) speech

local function PE_SpeakLiteral(text, spec)
    if not text or text == "" then return end

    spec = spec or {}

    local chance  = spec.chance or 10
    if chance < 1 then chance = 1 end
    if math.random(chance) ~= 1 then return end

    local channel = spec.channel or "SAY"

    PE_SendPersonaMessage(text, channel, {
        cfg          = spec.cfg,
        eventId      = spec.eventId or "LITERAL",
        ctx          = spec.ctx,
        bypassResolve= spec.bypassResolve,
    })
end

-- 4) Spell bubble helper extracted so both FireBubble and Speak() can share it.

local function PE_SpeakSpellBubble(spellID, isReactionOverride, explicitCfg)
    if not spellID then return end
    if not PersonaEngineDB or not PersonaEngineDB.spells then return end

    local cfg = explicitCfg or PersonaEngineDB.spells[spellID]
    if not cfg then return end

    -- Global + per-spell enable flags
    if not PE.CanSpeak(cfg) then return end

    -- Chance check
    local chance = cfg.chance or 10
    if chance < 1 then chance = 1 end
    if math.random(chance) ~= 1 then return end

    -- Choose channel (prioritize SAY, then YELL, then EMOTE, then first flag)
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

    -- Build context with macro-state info
    local baseCtx = cfg.ctx or {}
    local ctx     = {}

    for k, v in pairs(baseCtx) do
        ctx[k] = v
    end

    local stateId = PE_GetMacroState and PE_GetMacroState() or "idle"
    ctx.stateId   = stateId
    ctx.spellID   = spellID
    ctx.spellCfg  = cfg

    local eventId = cfg.eventId or ("BUBBLE_" .. tostring(spellID))

    -- Decide which phrase system to use
    local line
    if cfg.phraseKey and PE.Phrases and PE.Phrases.PickLine then
        -- Use the static+dynamic phrase engine
        line = PE.Phrases.PickLine(cfg.phraseKey, ctx, stateId, eventId)
    else
        -- Legacy per-spell phrase list
        local phrases = cfg.phrases
        if not phrases or #phrases == 0 then return end
        line = PE_SelectLine(phrases)
    end

    if not line or line == "" then return end

    ------------------------------------------------
    -- Action vs reaction (optional delay)
    ------------------------------------------------
    local delay = 0

    if isReactionOverride == true then
        -- Force reaction-style delay
        local minD = cfg.reactionDelayMin or 1.0
        local maxD = cfg.reactionDelayMax or 2.5
        if maxD < minD then maxD = minD end
        delay = minD + math.random() * (maxD - minD)
    elseif isReactionOverride == false then
        delay = 0
    else
        -- No override → probabilistic reaction
        local rc = cfg.reactionChance or 0
        if rc > 0 and math.random() < rc then
            local minD = cfg.reactionDelayMin or 1.0
            local maxD = cfg.reactionDelayMax or 2.5
            if maxD < minD then maxD = minD end
            delay = minD + math.random() * (maxD - minD)
        end
    end

    -- FireBubble bypasses resolver so macros can use true SAY/YELL/etc.
    PE_SchedulePersonaMessage(
        line,
        channel,
        {
            cfg          = cfg,
            bypassResolve= true,
            eventId      = eventId,
            ctx          = ctx,
        },
        delay
    )
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
-- Usage patterns:
--   1) Spell bubble:
--        /run PE.Speak(187650)
--        /run PE.Speak(187650, true) -- force reaction
--
--   2) phraseKey:
--        /run PE.Speak("ENTERING_COMBAT")
--        /run PE.Speak("ENTERING_COMBAT", { channel="SAY", chance=5 })
--
--   3) literal text:
--        /run PE.Speak("Behold my questionable engineering.")
--        /run PE.Speak("Hi", { channel="EMOTE" })
--
--   4) explicit table:
--        /run PE.Speak({ phraseKey="LOW_HEALTH", channel="SAY" })
--        /run PE.Speak({ text="Raw text!", channel="YELL" })
--        /run PE.Speak({ phr={ "a", "b" }, channel="SAY" }) -- SR-style pool

function PE.Speak(...)
    local argc = select("#", ...)
    if argc == 0 then return end

    -- Single argument
    if argc == 1 then
        local spec = select(1, ...)
        local t = type(spec)

        if t == "number" then
            -- Treat as spellID bubble
            return PE_SpeakSpellBubble(spec, nil, nil)
        elseif t == "string" then
            -- Try phraseKey first, then literal
            if PE.Phrases and PE.Phrases.registry and PE.Phrases.registry[spec] then
                return PE_SpeakPhraseKey(spec, nil)
            else
                return PE_SpeakLiteral(spec, nil)
            end
        elseif t == "table" then
            -- Explicit table spec
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
    local first = select(1, ...)
    local second = select(2, ...)
    local t1 = type(first)

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

    -- If we get here, nothing matched; fail silently.
end

----------------------------------------------------
-- Legacy Public APIs (kept for compatibility)
----------------------------------------------------
-- These now route through the same internal helpers.

-- Core SR Logic (pool-based random speech)
function SR(a)
    return PE_SpeakPool(a)
end

-- Phrase Builder / Combo Engine
function SetP(i, t)
    if type(t) == "table" then
        P[i] = t[math.random(#t)]
    else
        P[i] = t
    end
end

function SpeakP(c, h, n)
    if not PE.CanSpeak() then return end
    c = c or 10
    if math.random(c) ~= 1 then return end

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
-- Persona Engine - Macro usage helpers
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
