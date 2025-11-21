-- ##################################################
-- PE_Core.lua
-- Persona Engine core helpers + unified Speak API
-- ##################################################

local MODULE = "Core"
local PE     = PE

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

local RATE_WINDOW_SECONDS = 8 -- sliding window length
local RATE_MAX_MESSAGES   = 5 -- allowed messages per window

local function PE_CanSendMessage()
    local now = GetTime()
    PE._rateState = PE._rateState or { windowStart = 0, count = 0 }
    local st = PE._rateState

    if now - (st.windowStart or 0) > RATE_WINDOW_SECONDS then
        st.windowStart = now
        st.count       = 0
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
-- (unchanged from your current file, keeping for brevity)
-- ... SNIP ...
-- everything above PE_SpeakActionBubble stays as-is
-- and everything after it (PE.Speak, legacy SR helpers, Macros.GetUsage)
-- also stays as-is, **except** PE.Say itself, which is replaced below.
----------------------------------------------------

-- 4) Action bubble helper (spell / item / emote)
-- used by FireBubble, Speak, and PE.Say

-- [ existing PE_SpeakActionBubble / PE_SpeakSpellBubble code is unchanged ]
-- (keep your current implementation here – omitted in this snippet for length)

-- Spell-only wrapper, used by PE.Speak and legacy FireBubble
local function PE_SpeakSpellBubble(spellID, isReactionOverride, explicitCfg)
    if not spellID then return end
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
-- [ keep your existing PE.Speak implementation unchanged ]
-- ... SNIP ...

----------------------------------------------------
-- Legacy Public APIs (compat)
----------------------------------------------------
-- [ SR, SetP, SpeakP, Macros.GetUsage, module registration unchanged ]
