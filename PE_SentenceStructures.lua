-- PE_SentenceStructures.lua
local MODULE = "Sentences"
PE.LogLoad(MODULE)


local PE         = PE
local Structures = PE.Structures
local Words      = PE.Words

----------------------------------------------------
-- Templates
----------------------------------------------------

Structures.templates = {
    simple = {
        "{prefix} {verb} the {object}{punct}",
        "{prefix} {object} requires {adjective} {noun}{punct}",
    },
    excited = {
        "{prefix_upper}! {verb_upper}! THE {object_upper}{punct}",
    },

    -- Low HP: panicky Copporclang, no explicit % numbers
    panic_low_hp = {
        "{prefix} {line}{punct}",
        "{prefix} {line} {ending}{punct}",
    },

    -- Enemy talking trash
    snide_enemy = {
        "{prefix} that {enemyAdj} {enemyNoun} just said '{quote}'{punct}",
        "{exclamation} hostile vocalization from {enemyNoun}. {conclusion}{punct}",
    },

    -- AFK / idle snark
    idle_snark = {
        "{prefix} AFK protocol engaged. {conclusion}{punct}",
        "{prefix} strategic idling online. {ending}{punct}",
    },

    -- External heals: gratitude / appreciation, no raw heal numbers
    heal_gratitude = {
        "{prefix} {line}{punct}",
        "{prefix} {line}{punct}",
    },

    -- Self-heals: bragging / smug
    self_heal = {
        "{prefix} {line}{punct}",
        "{prefix} {line}{punct}",
    },
}

----------------------------------------------------
-- Word pools
----------------------------------------------------

Words.simple = {
    prefix    = {"Behold,", "Observe,", "Witness this,", "Hypothesis:"},
    verb      = {"calibrating", "reversing", "supercharging", "underclocking"},
    object    = {"flux conduit", "rat-powered turbine", "quantum kettle"},
    adjective = {"volatile", "questionable", "non-ethical"},
    noun      = {"engineering", "experimentation", "wizardry"},
}

Words.excited = {
    prefix    = {"Behold,", "Observe,", "Witness this,", "Hypothesis:"},
    verb      = {"calibrating", "reversing", "supercharging", "underclocking"},
    object    = {"flux conduit", "rat-powered turbine", "quantum kettle"},
    adjective = {"volatile", "questionable", "non-ethical"},
    noun      = {"engineering", "experimentation", "wizardry"},
}

-- Low-HP panic
Words.panic = {
    prefix = {
        "Warning!",
        "ALERT!",
        "Diagnostic shriek:",
        "This is fine. Probably.",
    },
    line = {
        "vital systems are filing formal complaints.",
        "my squishy bits are exceeding recommended stab levels.",
        "structural integrity is in the ‘do not sneeze on me’ range.",
        "I am currently held together by tape, hope, and poor decisions.",
        "battle plan downgraded from ‘victory’ to ‘survive-ish’.",
    },
    ending = {
        "Recommend: fewer incoming pointy objects.",
        "Note to self: stop tanking with the face.",
        "Add this to the ‘suboptimal experiments’ list.",
    },
}

-- Enemy talking
Words.enemy = {
    prefix     = {"Observe:", "Hypothesis:", "Note:", "Data point:"},
    enemyAdj   = {"loud", "overconfident", "flammable-looking", "loot-rich"},
    enemyNoun  = {"meatbag", "target", "trash mob", "future test subject"},
    conclusion = {
        "Retaliation strongly advised.",
        "Sass subroutines warming up.",
        "Scheduling revenge in the next global cooldown.",
        "Proposal: reduce them to their component loot.",
    },
}

-- Idle / AFK snark
Words.idle = {
    prefix = {
        "Status:",
        "Diagnostics:",
        "Report:",
        "Mental note:",
    },
    conclusion = {
        "brain processes redirected to daydreaming.",
        "gears spinning, thoughts optional.",
        "entering low-power nonsense mode.",
        "productivity measured in imaginary inventions.",
    },
    ending = {
        "Do not disturb the genius.",
        "This totally counts as research.",
        "If I’m still, I’m plotting.",
    },
}

-- External healing: gratitude / appreciation
Words.heal = {
    prefix = {
        "Gratitude subroutine:",
        "Support log:",
        "Healing analysis:",
    },
    line = {
        "{source} just upgraded my odds of surviving my own ideas.",
        "{source} proved that medical science beats duct tape. Usually.",
        "logging {source} as ‘preferred damage sponge enabler’.",
        "new theory: {source} actually wants me alive. Suspicious.",
        "remind me to not explode {source}'s workshop. Today.",
    },
    conclusion = {
        "Future experiments will now include ‘not dying’.",
        "Vitality levels restored to ‘recklessly confident’.",
        "Updating threat table: hug {source}, then the enemy.",
    },
}

-- Self-healing: bragging
Words.self_heal = {
    prefix = {
        "Self-maintenance log:",
        "Automated repair report:",
        "Personal miracle file:",
    },
    line = {
        "patched myself up with scrap parts and sheer stubbornness.",
        "confirmed: I am my own best healer and worst patient.",
        "repaired critical systems with only minor screaming.",
        "healing achieved using science, panic, and one stolen bandage.",
        "turns out my warranty is ‘fix it yourself’. And I did.",
    },
    ending = {
        "Note: still cheaper than hiring help.",
        "Confidence restored to dangerously high levels.",
        "Adding ‘field medic’ to my absurd resume.",
    },
}

----------------------------------------------------
-- Helpers
----------------------------------------------------

local function W(group, key)
    local tbl = Words[group]
    if not tbl then return "" end
    local pool = tbl[key]
    if not pool or #pool == 0 then return "" end
    return pool[math.random(#pool)]
end

----------------------------------------------------
-- Unified sentence builder
----------------------------------------------------
-- templateId: key into Structures.templates
-- ctx: optional context (hpPercent, message, sourceName, amount, ...)

function PE.BuildSentence(templateId, ctx)
    ctx = ctx or {}

    local pool = Structures.templates[templateId]
    if not pool or #pool == 0 then return "" end

    local tpl = pool[math.random(#pool)]

    if templateId == "simple" or templateId == "excited" then
        local group = (templateId == "simple") and "simple" or "excited"

        tpl = tpl
            :gsub("{prefix}",       W(group, "prefix"))
            :gsub("{verb}",         W(group, "verb"))
            :gsub("{object}",       W(group, "object"))
            :gsub("{adjective}",    W(group, "adjective"))
            :gsub("{noun}",         W(group, "noun"))
            :gsub("{prefix_upper}", string.upper(W(group, "prefix")))
            :gsub("{verb_upper}",   string.upper(W(group, "verb")))
            :gsub("{object_upper}", string.upper(W(group, "object")))

    elseif templateId == "panic_low_hp" then
        tpl = tpl
            :gsub("{prefix}",  W("panic", "prefix"))
            :gsub("{line}",    W("panic", "line"))
            :gsub("{ending}",  W("panic", "ending"))

    elseif templateId == "snide_enemy" then
        local quote = ctx.message or "unintelligible noise"

        tpl = tpl
            :gsub("{prefix}",      W("enemy", "prefix"))
            :gsub("{enemyAdj}",    W("enemy", "enemyAdj"))
            :gsub("{enemyNoun}",   W("enemy", "enemyNoun"))
            :gsub("{conclusion}",  W("enemy", "conclusion"))
            :gsub("{exclamation}", W("enemy", "prefix"))
            :gsub("{quote}",       quote)

    elseif templateId == "idle_snark" then
        tpl = tpl
            :gsub("{prefix}",     W("idle", "prefix"))
            :gsub("{conclusion}", W("idle", "conclusion"))
            :gsub("{ending}",     W("idle", "ending"))

    elseif templateId == "heal_gratitude" then
        local src = ctx.sourceName or "someone"
        local line = W("heal", "line") or ""
        line = line:gsub("{source}", src)

        tpl = tpl
            :gsub("{prefix}",     W("heal", "prefix"))
            :gsub("{line}",       line)
            :gsub("{conclusion}", W("heal", "conclusion"))

    elseif templateId == "self_heal" then
        local line = W("self_heal", "line") or ""

        tpl = tpl
            :gsub("{prefix}",     W("self_heal", "prefix"))
            :gsub("{line}",       line)
            :gsub("{ending}",     W("self_heal", "ending"))
    end

    if tpl:find("{punct}", 1, true) then
        local punct = PE.RandomPunct and PE.RandomPunct() or "!"
        tpl = tpl:gsub("{punct}", punct)
    end

    return tpl
end

PE.LogInit(MODULE)
PE.RegisterModule("Sentences", {
    name  = "Sentence Structures",
    class = "engine",
})

