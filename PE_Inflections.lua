-- ##################################################
-- PE_Inflections.lua
-- Mock casing, 1337-speak, panic punctuation, router
-- ##################################################

local PE = PE
if not PE then
    print("|cffff0000[PersonaEngine] PE_Inflections.lua loaded without PE core!|r")
    return
end

local MODULE = "Inflections"
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Upvalues for speed / clarity
local random  = math.random
local upper   = string.upper
local lower   = string.lower
local gsub    = string.gsub
local insert  = table.insert
local concat  = table.concat

----------------------------------------------------
-- Spongebob mock casing
----------------------------------------------------

function PE.Inflect_Mock(s)
    if not s or s == "" then
        return s
    end

    local out = {}

    for i = 1, #s do
        local ch = s:sub(i, i)
        if random() < 0.5 then
            ch = upper(ch)
        else
            ch = lower(ch)
        end
        insert(out, ch)
    end

    return concat(out)
end

----------------------------------------------------
-- 1337-speak / Artificer-Glyph mode
----------------------------------------------------
-- Each key = lowercase letter
-- Each value = list of possible replacements

PE.LeetMap = PE.LeetMap or {
    a = { "a", "@", "4" },
    e = { "e", "3" },
    i = { "i", "1", "!" },
    o = { "o", "0" },
    s = { "s", "5" },
    t = { "t", "7" },
    g = { "g", "9" },
    l = { "l", "1", "|" },
}

local function RandFrom(t)
    return t[random(#t)]
end

function PE.Inflect_Leet(s)
    if not s or s == "" then
        return s
    end

    local map = PE.LeetMap or {}

    return (gsub(s, ".", function(c)
        local opts = map[lower(c)]
        if not opts then
            return c
        end

        local rep = RandFrom(opts)

        -- Preserve capitalization when replacement is alphabetic
        if upper(c) == c and lower(c) ~= c then
            if rep:match("%a") then
                rep = rep:upper()
            end
        end

        return rep
    end))
end

----------------------------------------------------
-- Random panic punctuation
----------------------------------------------------

local puncts = { "!", "!!", "!?", "?!", "...", "??", "" }

function PE.RandomPunct()
    return puncts[random(#puncts)]
end

----------------------------------------------------
-- Central inflection router
----------------------------------------------------
-- line    : base text
-- eventId : optional abstract event id (LOW_HEALTH, HEAL_INCOMING, etc.)
-- stateId : optional state ("combat", "idle", ...)
-- ctx     : optional context table (currently unused here)
----------------------------------------------------

function PE.InflectMaybe(line, eventId, stateId, ctx)
    if not line or line == "" then
        return line
    end

    -- Stronger distortion for certain events
    if eventId == "LOW_HEALTH" then
        if random() < 0.6 then
            return PE.Inflect_Leet(line)
        end
        return line

    elseif eventId == "HEAL_INCOMING" then
        if random() < 0.3 then
            return PE.Inflect_Mock(line)
        end
        return line
    end

    -- General chatter: light seasoning
    local roll = random()
    if roll < 0.10 then
        return PE.Inflect_Mock(line)
    elseif roll < 0.15 then
        return PE.Inflect_Leet(line)
    end

    return line
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("Inflections", {
        name  = "Inflection Engine",
        class = "engine",
    })
end
