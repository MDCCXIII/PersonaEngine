-- Persona Engine core

local MODULE = "Core"
PE.LogLoad(MODULE)

-- Expects these globals from PE_Globals.lua:
-- SR_On   - 1 = speech enabled, 0 = muted
-- lastP   - last phrase spoken (for de-dupe)
-- P       - phrase pieces table
-- PE      - addon namespace table

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

function PE.CanSpeak(cfg)
    if SR_On ~= 1 then return false end

    local rt = PE.Runtime

    -- Hard AFK gate
    if rt and rt._isAFK then return false end

    -- AFK exit cooldown
    if rt and rt._afkReleaseAt and rt._afkReleaseAt > 0 then
        local now = GetTime()
        if now < rt._afkReleaseAt then
            return false
        end
    end

    -- Soft idle mute: if no activity in N seconds, be quiet
    local idleTimeout = 45  -- seconds; later we can make this configurable
    if rt and rt.lastActivityAt and idleTimeout > 0 then
        local now = GetTime()
        if (now - rt.lastActivityAt) > idleTimeout then
            return false
        end
    end

    if cfg and cfg.enabled == false then return false end

    return true
end



----------------------------------------------------
-- Persona Engine - Channel Resolver
----------------------------------------------------
-- For automated/event-driven speech we route "unsafe" SAY/YELL
-- into group channels or EMOTE where appropriate.

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

    -- Solo: in combat, SAY/YELL from addons are flaky / partially protected.
    -- In that specific case, fall back to EMOTE so Copporclang still
    -- appears to react without causing blocked actions.
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

----------------------------------------------------
-- Persona Engine - Unified Send Helper
----------------------------------------------------
-- opts:
--   opts.cfg           - optional spell config (for .enabled)
--   opts.bypassResolve - true = don't remap channel (used by FireBubble)
--   opts.eventId       - optional abstract event id for inflection context
--   opts.ctx           - optional context table for inflection

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

-- Expose safe send helper to other modules (EventEngine, etc.)
PE.SendPersonaMessage = PE_SendPersonaMessage

----------------------------------------------------
-- Persona Engine — Core SR Logic
----------------------------------------------------

function SR(a)
    if not a then
        return
    end

    local chan   = a.channel or "SAY"
    local chance = a.chance or 10
    local pool   = a.phr

    if not PE.CanSpeak() then
        return
    end

    if not pool or #pool == 0 then
        return
    end

    if math.random(chance) ~= 1 then
        return
    end

    local line = PE.SelectLine and PE.SelectLine(pool) or PE_SelectLine(pool)
    if not line then
        return
    end

    PE_SendPersonaMessage(line, chan, {
        eventId = a.eventId or "SR_MACRO",
        ctx     = a.ctx,
    })
end

----------------------------------------------------
-- Phrase Builder / Combo Engine
----------------------------------------------------

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
-- Delayed send helper (for reaction-style FireBubble lines)
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
        -- Re-check speech permission at fire time in case user toggled things
        if PE.CanSpeak and not PE.CanSpeak(o and o.cfg) then
            return
        end
        PE_SendPersonaMessage(l, ch, o)
    end)
end

----------------------------------------------------
-- Persona Engine - Bubble Macro Helper
----------------------------------------------------
-- Usage:
--   #showtooltip Freezing Trap
--   /run PE.FireBubble(187650)
--   /cast Freezing Trap
--
-- Optional 2nd arg:
--   isReactionOverride = true  → always delayed “reaction”
--   isReactionOverride = false → always immediate “action”
--   nil                     → use cfg.reactionChance (if present)

function PE.FireBubble(spellID, isReactionOverride)
    if not spellID then
        return
    end

    if not PersonaEngineDB or not PersonaEngineDB.spells then
        return
    end

    local cfg = PersonaEngineDB.spells[spellID]
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

    -- Choose channel (prioritize SAY, then YELL, then EMOTE, then first)
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

    -- Decide which phrase system to use
    local line
    local ctx     = cfg.ctx or {}
    local eventId = cfg.eventId or ("BUBBLE_" .. tostring(spellID))

    if cfg.phraseKey and PE.Phrases and PE.Phrases.PickLine then
        -- Use the static+dynamic phrase engine
        line = PE.Phrases.PickLine(cfg.phraseKey, ctx, nil, eventId)
    else
        -- Legacy per-spell phrase list
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
            bypassResolve = true,
            eventId      = eventId,
            ctx          = ctx,
        },
        delay
    )
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("Core", {
    name  = "Core Systems",
    class = "core",
})
