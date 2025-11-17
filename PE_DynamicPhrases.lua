-- ##################################################
-- PE_DynamicPhrases.lua
-- Dynamic phrase generators wired to sentence engine
-- ##################################################

local PE = PE
if not PE then
    print("|cffff0000[PersonaEngine] PE_DynamicPhrases.lua loaded without PE core!|r")
    return
end

local MODULE = "DynamicPhrases"
if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Ensure the dynamic phrase table exists under PE
local Dyn = PE.DynamicPhrases or {}
PE.DynamicPhrases = Dyn

----------------------------------------------------
-- LOW_HEALTH dynamic
----------------------------------------------------
Dyn["TECH_BABBLE_LOW"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("panic_low_hp", ctx or {})
end

----------------------------------------------------
-- ENEMY_TALK dynamic
----------------------------------------------------
Dyn["TECH_SNIDE_ENEMY"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("snide_enemy", ctx or {})
end

----------------------------------------------------
-- AFK / IDLE dynamic
----------------------------------------------------
Dyn["TECH_IDLE_SNARK"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("idle_snark", ctx or {})
end

----------------------------------------------------
-- HEAL_INCOMING dynamic
----------------------------------------------------
Dyn["TECH_HEAL_GRATITUDE"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("heal_gratitude", ctx or {})
end

----------------------------------------------------
-- SELF_HEAL dynamic
----------------------------------------------------
Dyn["TECH_SELF_REPAIR"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("self_heal", ctx or {})
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("DynamicPhrases", {
        name  = "Dynamic Phrase Generators",
        class = "engine",
    })
end
