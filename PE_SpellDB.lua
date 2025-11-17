-- ##################################################
-- PE_SpellDB.lua
-- Persona Engine - Spell Config DB
-- ##################################################

local MODULE = "SpellDB"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- addonName provided by the addon loader via "..."
local addonName = ...

-- ##################################################
-- Shared enums/defaults under PE namespace
-- ##################################################

PE.TRIGGER_MODES = PE.TRIGGER_MODES or {
    ON_CAST = "On Cast",
    ON_READY = "When Cooldown Ready",
    ON_CD   = "When Cooldown Starts",
}

PE.SPELL_DEFAULT_CONFIG = PE.SPELL_DEFAULT_CONFIG or {
    trigger  = "ON_CAST",  -- key into TRIGGER_MODES
    chance   = 5,          -- 1 in N
    channels = { SAY = true }, -- channel => bool
    phrases  = { "Default artificer mumbling..." },
    enabled  = true,
}

-- ##################################################
-- SavedVariables helpers
-- ##################################################

local function InitRoot()
    -- PersonaEngineDB root is declared in PE_Globals.lua as a SavedVariable.
    PersonaEngineDB        = PersonaEngineDB or {}
    PersonaEngineDB.spells = PersonaEngineDB.spells or {} -- [spellID] = config table
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

-- ##################################################
-- Public API
-- ##################################################

function PE.GetOrCreateSpellConfig(spellID)
    if not spellID then
        return
    end

    InitRoot()

    local spells = PersonaEngineDB.spells

    -- Ensure we have a table (guard against accidental corruption)
    local cfg = spells[spellID]
    if type(cfg) ~= "table" then
        cfg = {}
        spells[spellID] = cfg
    end

    ApplyDefaults(cfg)
    return cfg
end

function PE.SpellConfigPairs()
    InitRoot()
    return pairs(PersonaEngineDB.spells)
end

-- ##################################################
-- Ensure DB exists at addon load
-- ##################################################

do
    if CreateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(_, event, name)
            if event ~= "ADDON_LOADED" or name ~= addonName then
                return
            end
            InitRoot()
        end)
    end
end

-- ##################################################
-- Module registration
-- ##################################################

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Spell Database",
        class = "data",
    })
end
