-- PE_DynamicPhrases.lua
local MODULE = "DynamicPhrases"
PE.LogLoad(MODULE)


local PE  = PE
local Dyn = PE.DynamicPhrases

-- LOW_HEALTH dynamic
Dyn["TECH_BABBLE_LOW"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("panic_low_hp", ctx or {})
end

-- ENEMY_TALK dynamic
Dyn["TECH_SNIDE_ENEMY"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("snide_enemy", ctx or {})
end

-- AFK/idle dynamic
Dyn["TECH_IDLE_SNARK"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("idle_snark", ctx or {})
end

-- HEAL_INCOMING dynamic
Dyn["TECH_HEAL_GRATITUDE"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("heal_gratitude", ctx or {})
end

-- SELF_HEAL dynamic
Dyn["TECH_SELF_REPAIR"] = function(ctx, stateId, eventId)
    return PE.BuildSentence("self_heal", ctx or {})
end

PE.LogInit(MODULE)
PE.RegisterModule("DynamicPhrases", {
    name  = "Dynamic Phrase Generators",
    class = "engine",
})
