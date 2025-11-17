-- PE_Profile_Copporclang.lua
-- Static definition of Copporclang's default profile
local MODULE = "Profile_Copporclang"
PE.LogLoad(MODULE)


function PersonaEngine_BuildDefaultCopporclang()
    return {
        name = "Copporclang (Default)",
        meta = {
            race    = "Gnome",
            class   = "HUNTER",
            spec    = 3, -- Survival
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
                chance  = 2,
                reply   = true,
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

-- ##################################################
-- Copporclang Persona Profile - Spell Overrides
-- ##################################################

PersonaEngineDB.spells = PersonaEngineDB.spells or {}

-- X-53 Touring Rocket (spellID 75973)
PersonaEngineDB.spells[75973] = PersonaEngineDB.spells[75973] or {}

local rocket = PersonaEngineDB.spells[75973]

-- Static overrides (merge without nuking user values)
rocket.enabled        = (rocket.enabled ~= false)
rocket.chance         = rocket.chance or 3
rocket.phraseKey      = "MOUNT_X53_ROCKET"
rocket.channels       = rocket.channels or { SAY = true }
rocket.reactionChance = rocket.reactionChance or 0.5
rocket.reactionDelayMin = rocket.reactionDelayMin or 1.0
rocket.reactionDelayMax = rocket.reactionDelayMax or 2.5
rocket.eventId        = "MOUNT_X53_ROCKET"


PE.LogInit(MODULE)
PE.RegisterModule("Profile_Copporclang", {
    name  = "Copporclang Persona Profile",
    class = "data",
})
