local MODULE = "Inflections"
PE.LogLoad(MODULE)


local PE = PE

----------------------------------------------------
-- Spongebob mock casing
----------------------------------------------------

function PE.Inflect_Mock(s)
    local out = {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        if math.random() < 0.5 then
            ch = string.upper(ch)
        else
            ch = string.lower(ch)
        end
        table.insert(out, ch)
    end
    return table.concat(out)
end

----------------------------------------------------
-- 1337-speak / Artificer-Glyph mode
----------------------------------------------------
-- Each key = lowercase letter
-- Each value = list of possible replacements

PE.LeetMap = PE.LeetMap or {
    a = {"a", "@", "4"},
    e = {"e", "3"},
    i = {"i", "1", "!"},
    o = {"o", "0"},
    s = {"s", "5"},
    t = {"t", "7"},
    g = {"g", "9"},
    l = {"l", "1", "|"},
}

local function PE_RandFrom(t)
    return t[math.random(#t)]
end

function PE.Inflect_Leet(s)
    local map = PE.LeetMap or {}
    return (s:gsub(".", function(c)
        local lower = c:lower()
        local options = map[lower]
        if not options then
            return c
        end

        local rep = PE_RandFrom(options)

        -- Preserve capitalization when replacement is alphabetic
        if c:upper() == c and c:lower() ~= c then
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

local puncts = {"!", "!!", "!?", "?!", "...", "??", ""}

function PE.RandomPunct()
    return puncts[math.random(#puncts)]
end

----------------------------------------------------
-- Central inflection router
----------------------------------------------------
-- line      : base text
-- eventId   : optional abstract event id (LOW_HEALTH, HEAL_INCOMING, etc.)
-- stateId   : optional state ("combat", "idle", ...)
-- ctx       : optional context table

function PE.InflectMaybe(line, eventId, stateId, ctx)
    if not line or line == "" then
        return line
    end

    -- Stronger distortion for certain events
    if eventId == "LOW_HEALTH" then
        if math.random() < 0.6 then
            return PE.Inflect_Leet(line)
        end
        return line
    elseif eventId == "HEAL_INCOMING" then
        if math.random() < 0.3 then
            return PE.Inflect_Mock(line)
        end
        return line
    end

    -- General chatter: light seasoning
    local roll = math.random()
    if roll < 0.10 then
        return PE.Inflect_Mock(line)
    elseif roll < 0.15 then
        return PE.Inflect_Leet(line)
    end

    return line
end

PE.LogInit(MODULE)
PE.RegisterModule("Inflections", {
    name  = "Inflection Engine",
    class = "engine",
})