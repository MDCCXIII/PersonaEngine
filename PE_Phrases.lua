-- PE_Phrases.lua
local MODULE = "Phrases"
PE.LogLoad(MODULE)


local PE      = PE
local Phrases = PE.Phrases

Phrases.registry = Phrases.registry or {}

------------------------------------------------
-- Static + dynamic definitions per phraseKey
------------------------------------------------

Phrases.registry["LOW_HEALTH"] = {
    static = {
        "Warning: structural integrity below %HP%%%!",
        "If I pass out, loot my blueprints first!",
        "Note: bleeding is *suboptimal* for productivity.",
    },
    dynamic = {
        "TECH_BABBLE_LOW",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}

Phrases.registry["ENEMY_TALK"] = {
    static = {
        "Did that hostile just talk trash at *me*?",
        "Hostile vocalization detected. Engaging sass subroutines.",
    },
    dynamic = {
        "TECH_SNIDE_ENEMY",
    },
    staticWeight  = 2,
    dynamicWeight = 1,
}

Phrases.registry["HEAL_INCOMING"] = {
    static = {
        "Ah, delicious %AMOUNT% healing from %SOURCE%.",
        "Reinforcements from %SOURCE%! Patch those leaks!",
    },
    dynamic = {
        "TECH_HEAL_GRATITUDE",
    },
    staticWeight  = 2,
    dynamicWeight = 1,
}

Phrases.registry["SELF_HEAL"] = {
    static = {
        "Self-repair protocol: restored %AMOUNT% health.",
        "Patched my own hull for %AMOUNT%. Diagnostics look… acceptable.",
    },
    dynamic = {
        "TECH_SELF_REPAIR",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}


Phrases.registry["FRIEND_WHISPER"] = {
    static = {
        "Incoming private transmission from %SENDER%.",
        "%SENDER% just pinged the Coppornet.",
    },
    staticWeight  = 1,
    dynamicWeight = 0,
}

Phrases.registry["NPC_TALK"] = {
    static = {
        "Background NPC chatter detected. Ignoring... mostly.",
        "Hey, you! Yes, you with the pre-baked dialogue.",
    },
    dynamic = {
        "TECH_IDLE_SNARK",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}

Phrases.registry["AFK_WARNING"] = {
    dynamic = {
        "TECH_IDLE_SNARK",
    },
    staticWeight  = 0,
    dynamicWeight = 1,
}

Phrases.registry["CHARACTER_IDLE"] = {
    static = {
        "Hmm... if I reverse the polarity of the kettle...",
        "Did someone tighten the bolts on reality again?",
        "Where did I put my non-explosive wrench? ...wait.",
    },
    dynamic = {
        "TECH_IDLE_SNARK",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}

Phrases.registry["ENTERING_COMBAT"] = {
    static = {
        "Hostiles detected! Deploying improvisational violence!",
        "CLANG-styled aggression protocol engaged!",
        "By the power of questionable engineering choices!",
    },
    dynamic = {
        "TECH_BABBLE_LOW",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}

Phrases.registry["CAUTION"] = {
    static = {
        "Careful! That’s how I blew up my *previous* voice box.",
        "That thing looks flammable. Perfect.",
    },
    dynamic = {
        "TECH_IDLE_SNARK",
    },
    staticWeight  = 1,
    dynamicWeight = 2,
}

Phrases.registry["MOUNT_X53_ROCKET"] = {
    static = {
        "Ever ridden on a missile?!?",
        "Rocket online! Warranty void.",
        "Who jammed my thrust port again?",
        "Prototyping death wish protocol.",
        "Two seats, zero regard for safety.",
        "Please keep arms, legs, and existential dread inside the rocket.",
        "If this explodes, call it a controlled field test.",
        "Passenger protocol: scream internally, smile externally.",
    },
    -- For now we borrow generic tech snark as a dynamic flavor.
    -- Later we can wire a dedicated rocket generator.
    dynamic = {
        "TECH_IDLE_SNARK",
    },
    staticWeight  = 3,  -- mostly the tailored rocket lines
    dynamicWeight = 1,  -- sometimes a more free-form snark line
}


------------------------------------------------
-- Selection helpers
------------------------------------------------

local function randFrom(t)
    return t[math.random(#t)]
end

local function chooseMode(entry)
    local sw = entry.staticWeight  or ((entry.static  and #entry.static  > 0) and 1 or 0)
    local dw = entry.dynamicWeight or ((entry.dynamic and #entry.dynamic > 0) and 0 or 0)

    local total = sw + dw
    if total <= 0 then
        if entry.static and #entry.static > 0 then return "static" end
        if entry.dynamic and #entry.dynamic > 0 then return "dynamic" end
        return nil
    end

    local roll = math.random() * total
    if roll <= sw then
        return "static"
    else
        return "dynamic"
    end
end

-- Public API: pick a fully built line for this phraseKey
function Phrases.PickLine(phraseKey, ctx, stateId, eventId)
    local entry = Phrases.registry[phraseKey]
    if not entry then return nil end

    local mode = chooseMode(entry)
    if not mode then return nil end

    local line

    if mode == "static" then
        local pool = entry.static
        if not pool or #pool == 0 then return nil end
        line = randFrom(pool)
    elseif mode == "dynamic" then
        local dynList = entry.dynamic
        if not dynList or #dynList == 0 then return nil end
        local genId = randFrom(dynList)
        local gen   = PE.DynamicPhrases[genId]
        if not gen then return nil end
        line = gen(ctx, stateId, eventId)
    end

    return line
end

PE.LogInit(MODULE)
PE.RegisterModule("Phrases", {
    name  = "Phrase Registry",
    class = "data",
})

