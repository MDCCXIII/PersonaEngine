-- ##################################################
-- PE_Core.lua
-- Persona Engine core: chat helpers, macro API, bubbles
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

----------------------------------------------------
-- Chat Rate Limiter
----------------------------------------------------

-- Prevents macro spam from tripping server throttles.
local RATE_WINDOW   = 8      -- seconds in sliding window
local RATE_MAX_MSGS = 5      -- max messages per window

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
-- Speech Permission Helper
----------------------------------------------------

-- Central gate used by all speech paths.
-- cfg is optional; if provided, its .enabled flag is honored.
-- NOTE: Macro-only design: no AFK / idle runtime gating here.
function PE.CanSpeak(cfg)
    -- Global toggle (icon, slash, etc.)
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

local function PE_GetMacroState()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return "combat"
    end
    return "idle"
end

PE.GetMacroState = PE_GetMacroState

----------------------------------------------------
-- Channel Resolver
----------------------------------------------------

-- For automated/event-driven speech we *used* to remap SAY/YELL.
-- For macro-only chatter this is still nice for SR() calls.
-- FireBubble can explicitly bypass this resolver.
local function PE_ResolveChannel(channel)
    channel = channel or "SAY"

    if channel == "EMOTE" then
        return "EMOTE"
    end

    -- Instance group → prefer INSTANCE_CHAT over SAY/YELL
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if channel == "SAY" or channel == "YELL" then
            return "INSTANCE_CHAT"
        end
        return channel
    end

    -- Raid → prefer RAID
    if IsInRaid and IsInRaid() then
        if channel == "SAY" or channel == "YELL" then
            return "RAID"
        end
        return channel
    end

    -- Party → prefer PARTY
    if IsInGroup and IsInGroup() then
        if channel == "SAY" or channel == "YELL" then
            return "PARTY"
        end
        return channel
    end

    -- Solo fallback: in combat, map SAY/YELL → EMOTE
    local inGroup  = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

    if not inGroup and inCombat and (channel == "SAY" or channel == "YELL") then
        return "EMOTE"
    end

    return channel
end

----------------------------------------------------
-- Phrase Selection Helper
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

-- Expose in case other modules want it
PE.SelectLine = PE.SelectLine or PE_SelectLine

----------------------------------------------------
-- Unified Send Helper
----------------------------------------------------

-- opts:
--   opts.cfg          - optional spell config (for .enabled)
--   opts.bypassResolve- true = don't remap channel (used by FireBubble)
--   opts.eventId      - optional event id for inflection context
--   opts.ctx          - optional context table for inflection

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

-- Expose safe send helper
PE.SendPersonaMessage = PE_SendPersonaMessage

----------------------------------------------------
-- Delayed send helper (for reaction-style lines)
----------------------------------------------------

local function PE_SchedulePersonaMessage(text, channel, opts, delay)
    delay = delay or 0

    if delay <= 0 or not (C_Timer and C_Timer.After) then
        -- Immediate send (or no timer available)
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

    local line = (PE.SelectLine and PE.SelectLine(pool)) or PE_SelectLine(pool)
    if not line then
        return
    end

    PE_SendPersonaMessage(line, chan, {
        eventId = event,
        ctx     = ctx,
    })
end

-- 2) phraseKey-based speech using phrase engine (if present)
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
    local line    = PE.Phrases.PickLine(phraseKey, ctx, stateId, eventId)

    if not line or line == "" then
        return
    end

    PE_SendPersonaMessage(line, channel, {
        cfg          = cfg,
        eventId      = eventId,
        ctx          = ctx,
        bypassResolve= spec.bypassResolve,
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
        cfg          = spec.cfg,
        eventId      = spec.eventId or "LITERAL",
        ctx          = spec.ctx,
        bypassResolve= spec.bypassResolve,
    })
end

-- 4) Spell bubble helper (shared by FireBubble and Speak)
local function PE_SpeakSpellBubble(spellID, isReactionOverride, explicitCfg)
    if not spellID then
        return
    end
    if not PersonaEngineDB or not PersonaEngineDB.spells then
        return
    end

    local cfg = explicitCfg or PersonaEngineDB.spells[spellID]
    if not cfg then
        return
    end

    -- Global + per-spell enable flags
    if not PE.CanSpeak(cfg) then
        return
    end

    -- Chance check
    local chance = cfg.chance or 10
    if chance < 1 then
        chance = 1
    end
    if math.random(chance) ~= 1 then
        return
    end

    -- Choose channel (prioritize SAY, then YELL, then EMOTE)
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

    -- Decide phrase source: phraseKey engine vs static phrases
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
    -- Action vs reaction (optional delay)
    ------------------------------------------------
    local delay = 0

    if isReactionOverride == true then
        -- Force reaction-style delay
        local minD = cfg.reactionDelayMin or 1.0
        local maxD = cfg.reactionDelayMax or 2.5
        if maxD < minD then
            maxD = minD
        end
        delay = minD + math.random() * (maxD - minD)

    elseif isReactionOverride == false then
        delay = 0

    else
        -- No override → probabilistic reaction
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

-- Usage examples:
--   /run PE.Speak(187650)           -- spell bubble (by ID)
--   /run PE.Speak(187650, true)     -- force reaction delay
--   /run PE.Speak("ENTER_COMBAT")   -- phraseKey or literal
--   /run PE.Speak("Hi there", { channel="EMOTE" })
--   /run PE.Speak({ phr={...}, channel="SAY" }) -- SR-style pool

function PE.Speak(...)
    local argc = select("#", ...)
    if argc == 0 then
        return
    end

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
    local first  = select(1, ...)
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
-- Macro usage helpers (small utility)
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

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Core", {
        name  = "Core Systems",
        class = "core",
    })
end
