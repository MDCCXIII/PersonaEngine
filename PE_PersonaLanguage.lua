-- ##################################################
-- PE_PersonaLanguage.lua
-- Mood-aware sentence templates, pronouns, and "lord" referents
-- ##################################################

local MODULE = "PersonaLanguage"
local PE = PE

if not PE then
    print("|cffff0000[PersonaEngine] PE_PersonaLanguage.lua loaded without PE core!|r")
    return
end

if PE.LogLoad then PE.LogLoad(MODULE) end

PE.PersonaLanguage = PE.PersonaLanguage or {}
local PL = PE.PersonaLanguage

local Mood      = PE.Mood
local Runtime   = PE.Runtime or {}
PE.Runtime      = Runtime

local random = math.random

----------------------------------------------------
-- Lexicons (global + mood overrides)
----------------------------------------------------

PL.LexiconGlobal = {
    interjection = {
        "Well", "Hey", "Huh", "Right", "Fine", "Seriously",
    },
    interjection_positive = {
        "Yes", "Nice", "Perfect", "Beautiful",
    },
    interjection_negative = {
        "Damn", "Seriously", "Ugh", "You’ve got to be kidding",
    },

    comment_positive = {
        "This feels good",
        "This is going great",
        "I could get used to this",
    },
    comment_negative = {
        "This is a mess",
        "This is getting out of hand",
        "I did not sign up for this. Well… maybe I did.",
    },
    comment_neutral = {
        "Just another day",
        "Same old routine",
        "Business as usual",
    },

    adverb_emphatic = {
        "so much", "more than anything", "without holding back",
    },
    adverb_grim = {
        "as usual", "because of course it does", "and that’s just perfect",
    },
    adverb_neutral = {
        "for now", "more or less", "apparently",
    },

    noun_positive = {
        "fight", "chance", "moment", "opportunity",
    },
    noun_problem = {
        "mess", "disaster", "headache", "situation",
    },
    noun_event = {
        "day", "skirmish", "episode", "quest",
    },

    verb_positive = {
        "love", "enjoy", "savor", "relish",
    },
    verb_negative = {
        "hate", "despise", "dread", "regret",
    },
    verb_neutral_present = {
        "suppose", "guess", "figure",
    },
    verb_sarcastic_past = {
        "wanted", "wished for", "totally asked for",
    },
}

PL.LexiconMoodOverrides = {
    angry_anxious = {
        interjection = { "Damn", "Seriously", "Oh come on", "You’ve got to be kidding" },
        adverb_grim  = { "as if it couldn’t get worse", "because of course it does", "right on schedule" },
    },
    happy_calm = {
        interjection = { "Nice", "Good", "Alright", "Not bad at all" },
        comment_positive = {
            "This turned out better than expected",
            "This is surprisingly pleasant",
        },
    },
    elated_excited = {
        interjection = { "Yes!", "Ha!", "Let’s go!", "This is it!" },
        noun_positive = { "rush", "thrill", "glorious mess", "perfect chaos" },
    },
}

----------------------------------------------------
-- State clauses
----------------------------------------------------

PL.StateClauses = {
    IN_COMBAT = {
        "In the thick of battle",
        "With everything trying to kill me",
        "Under a rain of spells and screaming",
    },
    OUT_OF_COMBAT = {
        "Between fights",
        "While things are mercifully quiet",
        "In this fleeting calm",
    },
    LOW_HEALTH = {
        "Barely standing",
        "One bad hit from faceplanting",
        "With my health hanging by a thread",
    },
    RESTING = {
        "Feet up for a moment",
        "Taking a breath",
        "While pretending everything is fine",
    },
    DEFAULT = {
        "At this particular moment",
        "For reasons unclear,",
        "By some miracle,",
    },
}

----------------------------------------------------
-- Pronouns: general + recognized
----------------------------------------------------

PL.PronounsGeneral = {
    subject = { "they", "someone", "that one" },
    object  = { "them", "that one", "that poor soul" },
    possessive = { "their", "someone’s", "that fool’s" },
}

PL.PronounsRecognized = {
    male = {
        subject   = { "he" },
        object    = { "him" },
        possessive= { "his" },
    },
    female = {
        subject   = { "she" },
        object    = { "her" },
        possessive= { "her", "hers" },
    },
    neutral = {
        subject   = { "they" },
        object    = { "them" },
        possessive= { "their", "theirs" },
    },
    objectlike = {
        subject   = { "it" },
        object    = { "it" },
        possessive= { "its" },
    },
}

-- Simple helper; you can later expand with per-NPC/category overrides
local function RandFrom(t)
    if not t or #t == 0 then return nil end
    return t[random(#t)]
end

local function GetPronoun(slotType, context)
    context = context or {}

    local cat = context.pronounCategory
    local allowGeneral = (context.allowGeneralFallback ~= false)

    if cat and PL.PronounsRecognized[cat]
        and PL.PronounsRecognized[cat][slotType]
        and #PL.PronounsRecognized[cat][slotType] > 0
    then
        return RandFrom(PL.PronounsRecognized[cat][slotType])
    end

    if allowGeneral and PL.PronounsGeneral[slotType] then
        return RandFrom(PL.PronounsGeneral[slotType])
    end

    -- Hard fallback
    if slotType == "subject" then
        return "they"
    elseif slotType == "object" then
        return "them"
    else
        return "their"
    end
end

----------------------------------------------------
-- Lord's "pronouns" / divine referents
----------------------------------------------------

PL.Lords = {
    light = {
        names = {
            "The Light",
            "The Dawnward One",
            "The Holy Star",
        },
    },
    shadow = {
        names = {
            "The Forgotten Shadow",
            "The Veiled One",
            "The Pale Whisper",
        },
    },
    nature = {
        names = {
            "The Dreaming One",
            "The Wildmother",
            "The Verdant Heart",
        },
    },
    ancient = {
        names = {
            "The Old Ones",
            "The Deep Listener",
            "The Sleeper Beneath",
        },
    },
    element = {
        names = {
            "The Tidemother",
            "The Ember Father",
            "The Stormwatcher",
        },
    },
    hunt = {
        names = {
            "The Eternal Hunt",
            "The Beastlord",
            "The Unerring Arrow",
        },
    },
}

-- Merge helper
local function MergeAllLordNames(excludeCategory)
    local all = {}
    for cat, data in pairs(PL.Lords) do
        if cat ~= excludeCategory then
            for _, name in ipairs(data.names or {}) do
                table.insert(all, name)
            end
        end
    end
    return all
end

local function GetLordBias()
    local pers = nil
    if PE.Profiles and PE.Profiles.GetActiveProfile then
        local profile = PE.Profiles.GetActiveProfile()
        if profile then
            pers = profile.personality
        end
    end
    pers = pers or {}
    local lb = pers.lordBias or {}
    local cat = lb.category or "light"
    local strength = lb.strength or 0.0
    if not PL.Lords[cat] then
        cat = "light"
    end
    return cat, math.max(0, math.min(1, strength))
end

local function GetLordName(flag)
    local cat, strength = GetLordBias()
    if flag == "R" then
        return RandFrom(PL.Lords[cat].names)
    elseif flag == "G" then
        return RandFrom(MergeAllLordNames(nil))
    elseif flag == "ALT" then
        return RandFrom(MergeAllLordNames(cat))
    end

    -- Default: weighted bias
    if random() < strength then
        return RandFrom(PL.Lords[cat].names)
    else
        return RandFrom(MergeAllLordNames(nil))
    end
end

----------------------------------------------------
-- Profile synonyms (per-character flavor)
----------------------------------------------------
-- profile.personality.synonyms = {
--   ["love"] = { "adore", "am all about" },
--   ["hate"] = { "can’t stand", "am so done with" },
-- }

local function ApplySynonym(word)
    if not PE.Profiles or not PE.Profiles.GetActiveProfile then
        return word
    end
    local profile = PE.Profiles.GetActiveProfile()
    if not profile then return word end

    local pers = profile.personality or {}
    local map  = pers.synonyms or {}

    local list = map[word]
    if not list or #list == 0 then
        return word
    end

    -- 50% chance to swap; UI can later make this configurable
    if random() < 0.5 then
        return RandFrom(list) or word
    end

    return word
end

----------------------------------------------------
-- Mood templates
----------------------------------------------------
-- A simple set to start; you can add more and refine later.

PL.Templates = {
    angry_anxious = {
        "{interjection_negative}! {state_clause}, and I {verb_negative} every {noun_event}{punct}",
        "{interjection_negative}! {comment_negative}{punct}",
        "{state_clause}. Another {noun_problem}, just what I {verb_sarcastic_past}{punct}",
    },
    angry_bored = {
        "{interjection_negative}. {state_clause}. {comment_negative}{punct}",
    },
    angry_calm = {
        "{interjection}. {state_clause}. I {verb_negative} this, but at least I’m calm about it{punct}",
    },
    irritable_anxious = {
        "{interjection_negative}. {state_clause}. {comment_negative}{punct}",
    },
    indifferent_neutral = {
        "{comment_neutral}{punct}",
        "Just another {noun_event}, {adverb_neutral}{punct}",
        "I {verb_neutral_present} it’s {noun_event}, I guess{punct}",
    },
    grateful_calm = {
        "{interjection_positive}. {state_clause}. {comment_positive}{punct}",
    },
    happy_anxious = {
        "{interjection_positive}! {state_clause}. I {verb_positive} this, even if it’s worrying{punct}",
    },
    happy_calm = {
        "{interjection_positive}. {state_clause}. {comment_positive}{punct}",
    },
    elated_excited = {
        "{interjection_positive}! {state_clause}, and I {verb_positive} every second of it{punct}",
        "Another {noun_positive}? {interjection_positive}, let’s {verb_positive} it{punct}",
        "By {lord}, this is fantastic{punct}",
    },
}

-- Fallback if no template for bucket
PL.TemplatesFallback = {
    "{state_clause}. {comment_neutral}{punct}",
}

----------------------------------------------------
-- Slot resolution
----------------------------------------------------

local function ResolveLexiconWord(slotName, moodKey)
    local moodLex = PL.LexiconMoodOverrides[moodKey] or {}
    local pool = moodLex[slotName] or PL.LexiconGlobal[slotName]
    local word = nil
    if pool and #pool > 0 then
        word = RandFrom(pool)
    end
    if not word then
        -- crude emergency fallback
        return ""
    end
    return ApplySynonym(word)
end

local function ResolveStateClause(stateId)
    local list = PL.StateClauses[stateId] or PL.StateClauses.DEFAULT
    return RandFrom(list) or ""
end

local function ResolvePunct()
    if PE.RandomPunct then
        return PE.RandomPunct()
    end
    local opts = { "!", ".", "!!", "?!", "..." }
    return RandFrom(opts) or "!"
end

-- Build pronoun context from runtime info (you can expand this later)
local function GetPronounContext()
    -- Simple version: if we have a last NPC speaker, treat as recognized neutral
    local ctx = {}
    local npcName = Runtime.lastNPCSpeaker or Runtime.lastNPCSeen

    if npcName then
        ctx.referentName = npcName
        ctx.pronounCategory = "neutral"    -- You can later infer from user overrides
    end

    return ctx
end

----------------------------------------------------
-- Template expansion
----------------------------------------------------
-- This supports:
--  {slot}
--  {prn_subj}, {prn_obj}, {prn_pos}
--  {prn_subj:R}, {prn_subj:G} (R = recognized-only, G = general-only)
--  {lord}, {lord:R}, {lord:G}, {lord:ALT}
----------------------------------------------------

function PL.BuildSentenceForMood(moodKey, stateId, ctx)
    ctx = ctx or {}

    local templates = PL.Templates[moodKey] or PL.TemplatesFallback
    if not templates or #templates == 0 then
        templates = PL.TemplatesFallback
    end

    local tpl = templates[random(#templates)]
    local pronounCtxBase = GetPronounContext()

    local replacements = {}

    -- Pre-handle state_clause and punct (since they appear in most templates)
    if tpl:find("{state_clause}", 1, true) then
        replacements["state_clause"] = ResolveStateClause(stateId)
    end
    if tpl:find("{punct}", 1, true) then
        replacements["punct"] = ResolvePunct()
    end

    for raw in tpl:gmatch("{(.-)}") do
        if replacements[raw] then
            -- already handled
        else
            local token = raw
            local name, flag = token:match("^(.-):([A-Z]+)$")
            name = name or token

            if name == "prn_subj" or name == "prn_obj" or name == "prn_pos" then
                local slotType = (name == "prn_subj") and "subject"
                              or (name == "prn_obj") and "object"
                              or "possessive"
                local pctx = {}
                for k,v in pairs(pronounCtxBase or {}) do pctx[k] = v end

                if flag == "R" then
                    pctx.allowGeneralFallback = false
                elseif flag == "G" then
                    pctx = {} -- force general
                end

                replacements[raw] = GetPronoun(slotType, pctx)

            elseif name == "lord" then
                replacements[raw] = GetLordName(flag)

            elseif name == "state_clause" or name == "punct" then
                -- already filled

            else
                -- generic lexicon slot
                replacements[raw] = ResolveLexiconWord(name, moodKey)
            end
        end
    end

    local out = tpl:gsub("{(.-)}", function(key)
        return replacements[key] or ("{"..key.."}")
    end)

    return out
end

----------------------------------------------------
-- High-level helper: build sentence using CURRENT mood
----------------------------------------------------

function PL.BuildPersonaSentence(stateId, ctx)
    local moodKey = Mood and Mood.GetBucketKey and Mood.GetBucketKey() or "indifferent_neutral"
    return PL.BuildSentenceForMood(moodKey, stateId, ctx)
end

----------------------------------------------------
-- Optional helper: speak it directly via PersonaEngine core
----------------------------------------------------

function PL.SayPersona(stateId, channel, cfg, ctx)
    if not PE.SendPersonaMessage then return end
    local line = PL.BuildPersonaSentence(stateId, ctx)
    if not line or line == "" then return end

    PE.SendPersonaMessage(line, channel or "SAY", {
        cfg     = cfg,
        eventId = stateId or "PERSONA_GENERIC",
        ctx     = ctx,
    })
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then PE.LogInit(MODULE) end
if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Persona Language",
        class = "engine",
    })
end
