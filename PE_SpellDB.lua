local MODULE = "SpellDB"
PE.LogLoad(MODULE)


-- ##################################################
-- Persona Engine - Spell Config DB
-- ##################################################

if not PE then
    PE = {}
end

local addonName = ...

-- Shared enums/defaults under PE namespace
PE.TRIGGER_MODES = PE.TRIGGER_MODES or {
    ON_CAST  = "On Cast",
    ON_READY = "When Cooldown Ready",
    ON_CD    = "When Cooldown Starts",
}

PE.SPELL_DEFAULT_CONFIG = PE.SPELL_DEFAULT_CONFIG or {
    trigger  = "ON_CAST",        -- key into TRIGGER_MODES
    chance   = 5,                -- 1 in N
    channels = { SAY = true },   -- channel => bool
    phrases  = { "Default artificer mumbling..." },
    enabled  = true,
}

local function InitRoot()
    PersonaEngineDB = PersonaEngineDB or {}
    PersonaEngineDB.spells = PersonaEngineDB.spells or {}  -- [spellID] = config table
end

local function ApplyDefaults(cfg)
    local defaults = PE.SPELL_DEFAULT_CONFIG
    for k, v in pairs(defaults) do
        if cfg[k] == nil then
            if type(v) == "table" then
                local t = {}
                for k2, v2 in pairs(v) do
                    t[k2] = v2
                end
                cfg[k] = t
            else
                cfg[k] = v
            end
        end
    end
end

function PE.GetOrCreateSpellConfig(spellID)
    if not spellID then return end
    InitRoot()
    local spells = PersonaEngineDB.spells
    spells[spellID] = spells[spellID] or {}
    local cfg = spells[spellID]
    ApplyDefaults(cfg)
    return cfg
end

function PE.SpellConfigPairs()
    InitRoot()
    return pairs(PersonaEngineDB.spells)
end

-- Make sure DB exists on addon load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= addonName then return end
    InitRoot()
end)

PE.LogInit(MODULE)
PE.RegisterModule("SpellDB", {
    name  = "Spell Database",
    class = "data",
})
