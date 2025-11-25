-- ##################################################
-- PE_Actions.lua
-- Generic action resolver (spell / item / emote) +
-- per-action config DB (macro-safe).
-- ##################################################

local MODULE = "Actions"

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
-- Action type enums
-- ##################################################

PE.ActionTypes = PE.ActionTypes or {
    SPELL = "spell",
    ITEM  = "item",
    EMOTE = "emote",
}

local ActionTypes = PE.ActionTypes

-- ##################################################
-- Utility: action keys (stable identifiers)
-- ##################################################

local function MakeActionKey(kind, id)
    if not kind or not id then return nil end
    return tostring(kind) .. ":" .. tostring(id)
end

local function ParseActionKey(key)
    if type(key) ~= "string" then return end
    local kind, id = key:match("^([^:]+):(.+)$")
    if not kind or not id then return end
    return kind, id
end

PE.MakeActionKey  = PE.MakeActionKey  or MakeActionKey
PE.ParseActionKey = PE.ParseActionKey or ParseActionKey

-- ##################################################
-- Spell / item resolvers
-- ##################################################

-- Spell resolver that works on both DF API and classic GetSpellInfo.
local function ResolveSpell(input)
    if not input or input == "" then
        return
    end

    local num = tonumber(input)
    local name, icon, spellID

    -- Dragonflight-style C_Spell API
    if C_Spell and C_Spell.GetSpellInfo then
        if num then
            local info = C_Spell.GetSpellInfo(num)
            if info then
                return {
                    kind  = ActionTypes.SPELL,
                    id    = info.spellID,
                    name  = info.name,
                    icon  = info.iconID,
                }
            end
        else
            local info = C_Spell.GetSpellInfo(input)
            if info then
                return {
                    kind  = ActionTypes.SPELL,
                    id    = info.spellID,
                    name  = info.name,
                    icon  = info.iconID,
                }
            end
        end
    end

    -- Classic GetSpellInfo fallback
    if GetSpellInfo then
        if num then
            name, _, icon = GetSpellInfo(num)
            spellID = num
        else
            name, _, icon, _, _, _, spellID = GetSpellInfo(input)
        end

        if name then
            return {
                kind  = ActionTypes.SPELL,
                id    = spellID or name,
                name  = name,
                icon  = icon,
            }
        end
    end

    -- Unknown spell
    return
end

local function ResolveItem(input)
    if not input or input == "" then
        return
    end

    local num = tonumber(input)
    local name, icon, itemID

    if num then
        name, _, _, _, _, _, _, _, _, icon = GetItemInfo(num)
        itemID = num
    else
        name, _, _, _, _, _, _, _, _, icon, _, _, _, _, itemID = GetItemInfo(input)
    end

    if name then
        return {
            kind  = ActionTypes.ITEM,
            id    = itemID or name,
            name  = name,
            icon  = icon,
        }
    end

    return
end

-- ##################################################
-- Public resolver: spell / item / emote
-- ##################################################

local function ResolveActionFromInput(input)
    if not input then return end
    input = strtrim(input)
    if input == "" then return end

    -- First try spell or item
    local action

    -- If it's numeric, try spell ID then item ID
    if tonumber(input) then
        action = ResolveSpell(input)
        if not action then
            action = ResolveItem(input)
        end
    else
        -- Named: spell name, then item name
        action = ResolveSpell(input)
        if not action then
            action = ResolveItem(input)
        end
    end

    if action then
        return action
    end

    -- Fallback: treat as emote token (macro: /e <token>)
    local token = string.lower(input)

    return {
        kind  = ActionTypes.EMOTE,
        id    = token,
        name  = token,
        icon  = nil, -- emotes don't have an icon
    }
end

PE.ResolveActionFromInput = PE.ResolveActionFromInput or ResolveActionFromInput

-- Small helper for UI: pretty label like "Spell: Kill Command (ID 34026)".
local function FormatActionSummary(action)
    if not action then return "" end
    local kindLabel = (action.kind == ActionTypes.SPELL and "Spell")
        or (action.kind == ActionTypes.ITEM and "Item")
        or (action.kind == ActionTypes.EMOTE and "Emote")
        or "Action"

    local idText = tostring(action.id or "?")
    local nameText = tostring(action.name or idText)

    return string.format("%s: |cffffff00%s|r (ID %s)", kindLabel, nameText, idText)
end

PE.FormatActionSummary = PE.FormatActionSummary or FormatActionSummary

-- ##################################################
-- Per-action config DB
-- ##################################################

local function InitRoot()
    -- PersonaEngineDB root is declared as a SavedVariable in PersonaEngine.toc
    PersonaEngineDB = PersonaEngineDB or {}
    PersonaEngineDB.actions = PersonaEngineDB.actions or {}   -- [actionKey] = cfg
end

-- Apply defaults using SPEL_DEFAULT_CONFIG if present,
-- otherwise provide a minimal safe fallback.
local function ApplyDefaults(cfg)
    local defaults = PE.SPELL_DEFAULT_CONFIG or {
        trigger  = "ON_CAST",
        chance   = 5,
        channels = { SAY = true },
        phrases  = {},
        enabled  = true,
    }

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

-- Public: get or create config for a resolved action.
-- kind: "spell" | "item" | "emote"
-- id:   numeric (spells/items) or string (emotes)
function PE.GetOrCreateActionConfig(kind, id)
    if not kind or not id then return end
    InitRoot()

    local key = MakeActionKey(kind, id)
    if not key then return end

    local actions = PersonaEngineDB.actions
    local cfg = actions[key]

    if type(cfg) ~= "table" then
        cfg = {}
        actions[key] = cfg
    end

    ApplyDefaults(cfg)

    -- Attach some readonly metadata for convenience
    cfg._key  = key
    cfg._kind = kind
    cfg._id   = id

    return cfg
end

-- Iterator for debug / future UI pages
function PE.ActionConfigPairs()
    InitRoot()
    return pairs(PersonaEngineDB.actions)
end

-- Convenience: fetch config directly by key ("spell:34026", etc.)
function PE.GetActionConfigByKey(key)
    if not key then return end
    InitRoot()
    local actions = PersonaEngineDB.actions
    local cfg = actions[key]
    if type(cfg) ~= "table" then
        local kind, id = ParseActionKey(key)
        if not kind or not id then return end
        return PE.GetOrCreateActionConfig(kind, id)
    end
    return cfg
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
-- Legacy/compat helpers (spell-only wrappers)
-- ##################################################

-- Old API used by ConfigUI and possibly other modules.
-- This simply scopes configs into the generic action table
-- using kind = "spell".
function PE.GetOrCreateSpellConfig(spellID)
    if not spellID then return end
    return PE.GetOrCreateActionConfig(ActionTypes.SPELL, spellID)
end

function PE.GetSpellConfigByID(spellID)
    if not PersonaEngineDB or not PersonaEngineDB.actions or not PE.MakeActionKey then
        return nil
    end
    local key = PE.MakeActionKey(ActionTypes.SPELL, spellID)
    return PersonaEngineDB.actions[key]
end


-- ##################################################
-- Module registration
-- ##################################################

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Action Resolver / DB",
        class = "data"
    })
end
