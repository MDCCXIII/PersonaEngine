-- ##################################################
-- PE_Profile_Copporclang.lua
-- Static definition of Copporclang's default profile
-- ##################################################

local MODULE = "Profile_Copporclang"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    -- We still define the builder below if you want, but
    -- nothing else in this file will run safely without PE.
end

if PE and PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Default Copporclang persona profile
-- (used by PE_Profiles as the canonical default)
----------------------------------------------------
-- NOTE: This is intentionally a global so legacy code
-- can call it. Long-term you can move this under PE.Profiles.
----------------------------------------------------

function PersonaEngine_BuildDefaultCopporclang()
    local profile = {
        name = "Copporclang (Default)",

        meta = {
            race   = "Gnome",
            class  = "HUNTER",
            spec   = 3,              -- Survival
            dialect = "ArtificerGnome",
        },

        combat = {
            onEnter = {
                chance  = 5,
                channel = "SAY",
                phrases = {
                    "Systems hot; targets optional.",
                    "Re-initializing combat subroutines.",
                    "Safety protocols… skipped.",
                },
            },
            onExit = {
                chance  = 5,
                channel = "SAY",
                phrases = {
                    "Threat neutralized. Probably.",
                    "Logging results: excessive overkill.",
                },
            },
        },

        chatReactions = {
            SAY = {
                chance  = 20,
                channel = "SAY",
                phrases = {
                    "Processing social data… response inconclusive.",
                    "Attempting small talk… please stand by.",
                },
            },
            PARTY = {
                chance  = 15,
                channel = "PARTY",
                phrases = {
                    "Affirmative, party cohesion at 60%.",
                    "Squad status: mostly not dead.",
                },
            },
            WHISPER_IN = {
                chance = 2,
                reply  = true,
                phrases = {
                    "Private channel acknowledged.",
                    "You have reached Copporclang's primary cortex.",
                },
            },
            NPC_SAY = {
                chance  = 5,
                channel = "SAY",
                phrases = {
                    "Noted, large talking threat object.",
                    "Villain monologue detected; adjusting expectations.",
                },
            },
            NPC_YELL = {
                chance  = 5,
                channel = "YELL",
                phrases = {
                    "Yelling improves nothing, you know.",
                },
            },
        },
    }

    ------------------------------------------------
    -- Copporclang personality extensions
    -- (used by PE_Mood / PE_PersonaLanguage)
    ------------------------------------------------

    profile.personality = profile.personality or {}

    -- Emotional gravity: Copporclang tends to bounce back to
    -- "elated_excited" (happy chaos goblin) over time.
    profile.personality.moodBias = {
        moodKey  = "elated_excited",
        strength = 0.7,   -- 0 = no bias, 1 = very sticky
    }

    -- Spiritual flavor: tends to swear by hunt-themed “lords”
    -- (used by {lord} in PersonaLanguage).
    profile.personality.lordBias = {
        category = "hunt", -- see PL.Lords in PE_PersonaLanguage.lua
        strength = 0.6,
    }

    -- Lexicon synonyms that reskin global words into
    -- Copporclang-voice: genius, obnoxious, overconfident,
    -- overtechnical, joyful sadist/masochist, loves food & inventions.
    profile.personality.synonyms = {
        ------------------------------------------------
        -- “Positive” verbs (engineering mania)
        ------------------------------------------------
        love = {
            "am irrationally excited about",
            "am unhealthily invested in",
            "would absolutely patent if I could",
            "consider a perfectly valid experiment",
        },
        enjoy = {
            "find disturbingly satisfying",
            "consider recreational science",
            "file under ‘fun with consequences’",
        },
        savor = {
            "take meticulous notes on",
            "slowly disassemble with a smile",
            "document in excruciating detail",
        },
        relish = {
            "cackle over like a mad artificer",
            "enthusiastically overengineer",
            "treat as a personal playground",
        },

        ------------------------------------------------
        -- “Negative” verbs (sadistic/masochistic humor)
        ------------------------------------------------
        hate = {
            "would happily throw into a grinder",
            "secretly scheduled for destructive testing",
            "despise in a very professional way",
            "have added to the ‘things to explode’ list",
        },
        despise = {
            "want to stress-test until it screams",
            "would like to meet with a sledgehammer",
            "consider a design flaw in the universe",
        },
        dread = {
            "am scientifically curious and morally concerned about",
            "know will hurt and want to do anyway",
            "file under ‘necessary suffering’",
        },
        regret = {
            "marked as ‘worth it’ in my pain log",
            "absolutely would do again for the data",
            "have already repeated twice for confirmation",
        },

        ------------------------------------------------
        -- Nouns: fights, problems, events (engineer framing)
        ------------------------------------------------
        fight = {
            "field test",
            "live-fire experiment",
            "combat trial run",
            "unsupervised QA session",
        },
        chance = {
            "glorious opportunity for overengineering",
            "perfectly good excuse to push my luck",
            "statistically questionable, morally correct idea",
        },
        moment = {
            "high-risk iteration window",
            "tiny slice of controlled chaos",
            "Beautiful Disaster v1.0",
        },
        opportunity = {
            "grant proposal to the gods of chaos",
            "invitation to press the big red button",
            "open beta for pain and progress",
        },

        mess = {
            "data-rich failure state",
            "unexpected but highly educational outcome",
            "bug report from reality itself",
        },
        disaster = {
            "catastrophic success in the wrong direction",
            "full-spectrum QA failure",
            "legendary teachable moment",
        },
        headache = {
            "long-term maintenance project",
            "pending refactor of my life choices",
            "recurring issue in the meatware layer",
        },
        situation = {
            "multi-variable engineering puzzle",
            "low-budget apocalypse demo",
            "test environment with feelings",
        },

        ------------------------------------------------
        -- Comments (“this is good/bad/etc.”)
        -- Note: these phrase-keys are here for future expansion
        -- if you add phrase-level synonym logic.
        ------------------------------------------------
        ["This feels good"] = {
            "This benchmark is deeply satisfying",
            "These numbers are offensively beautiful",
            "The results are illegal in three kingdoms",
        },
        ["This is going great"] = {
            "Everything is on fire in exactly the right way",
            "The failure rate is within acceptable entertainment margins",
            "The experiment has not yet been banned, success",
        },
        ["I could get used to this"] = {
            "I should not get used to this, but I absolutely will",
            "I’m going to automate this and regret it later",
            "This is dangerously close to a lifestyle",
        },

        ["This is a mess"] = {
            "This is a crime against best practices and I love it",
            "This is not a bug, it’s emergent behavior",
            "This is how legends and error logs are born",
        },
        ["This is getting out of hand"] = {
            "This has migrated from ‘issue’ to ‘feature film’",
            "We have achieved exponential nonsense",
            "Even my disaster plans need disaster plans",
        },
        ["I did not sign up for this. Well… maybe I did."] = {
            "I definitely signed up for this and added snacks",
            "I literally volunteered for this chaos",
            "Pretty sure this was in the fine print I wrote myself",
        },

        ["Just another day"] = {
            "Just another bug report from the universe",
            "Just another QA ticket in the cosmic backlog",
            "Just another perfectly good way to get hurt",
        },
        ["Same old routine"] = {
            "Same old loop: idea, explosion, iteration",
            "Same routine: test, break, laugh, repeat",
            "Same daily quest: throw science at the problem",
        },
        ["Business as usual"] = {
            "Business as usual: unsafe, inefficient, delightful",
            "Par for the course, off the rails, on brand",
            "Standard operating chaos",
        },

        ------------------------------------------------
        -- Adverbs (tone)
        ------------------------------------------------
        ["so much"] = {
            "to a clinically concerning degree",
            "more than any responsible adult should",
            "with every unstable neuron I’ve got",
        },
        ["as usual"] = {
            "according to the worst-case design spec",
            "per my completely misused blueprint",
            "like the patch notes warned, probably",
        },
        ["for now"] = {
            "until I press something I shouldn’t",
            "pending catastrophic reevaluation",
            "until QA (me) files a complaint",
        },

        ------------------------------------------------
        -- Food & joy flavor
        ------------------------------------------------
        ["This turned out better than expected"] = {
            "This turned out tastier than the recipe promised",
            "This came out crispier than my last invention’s warranty",
            "This is good enough to serve with sauce and a disclaimer",
        },
        ["This is surprisingly pleasant"] = {
            "This is suspiciously pleasant, I don’t trust it",
            "This feels like free food—something is wrong",
            "This is almost relaxing, therefore a trap",
        },
    }

    return profile
end

----------------------------------------------------
-- Copporclang Persona Profile - Spell Overrides
-- ##################################################
do
    -- We only touch SavedVariables if the root exists
    local db = rawget(_G, "PersonaEngineDB")

    if type(db) ~= "table" then
        print("|cffff0000[PersonaEngine] WARNING: PersonaEngineDB missing; Copporclang spell overrides not applied.|r")
    else
        db.spells = db.spells or {}

        -- X-53 Touring Rocket (spellID 75973)
        db.spells[75973] = db.spells[75973] or {}
        local rocket = db.spells[75973]

        -- Static overrides (merge without nuking user values)

        -- enabled: default true, unless explicitly false
        rocket.enabled = (rocket.enabled ~= false)

        -- Default 1-in-3 chance if not set
        rocket.chance = rocket.chance or 3

        -- Phrase key to look up in your phrase catalog
        rocket.phraseKey = rocket.phraseKey or "MOUNT_X53_ROCKET"

        -- Default channel config if missing
        rocket.channels = rocket.channels or { SAY = true }

        -- Reaction timing when triggered by EventEngine
        rocket.reactionChance   = rocket.reactionChance   or 0.5
        rocket.reactionDelayMin = rocket.reactionDelayMin or 1.0
        rocket.reactionDelayMax = rocket.reactionDelayMax or 2.5

        -- Logical event id (for EventEngine / catalog mapping)
        rocket.eventId = rocket.eventId or "MOUNT_X53_ROCKET"
    end
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE and PE.LogInit then
    PE.LogInit(MODULE)
end

if PE and PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Copporclang Persona Profile",
        class = "data",
    })
end
