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
function PersonaEngine_BuildDefaultCopporclang()
    return {
        name = "Copporclang (Default)",

        meta = {
            race   = "Gnome",
            class  = "HUNTER",
            spec   = 3,                -- Survival
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
        rocket.reactionChance    = rocket.reactionChance    or 0.5
        rocket.reactionDelayMin  = rocket.reactionDelayMin  or 1.0
        rocket.reactionDelayMax  = rocket.reactionDelayMax  or 2.5

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
