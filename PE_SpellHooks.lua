-- ##################################################
-- PE_SpellHooks.lua
-- Spell hooks (legacy) - disabled in favor of macro-only FireBubble.
-- ##################################################

local MODULE = "SpellHooks"

-- Root PE table should be defined in PE_Globals.lua
local PE = PE
if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Public marker so other code can know hooks are intentionally disabled.
PE.SpellHooks = PE.SpellHooks or {}
local SpellHooks = PE.SpellHooks

SpellHooks.enabled = false

-- ##################################################
-- Legacy API shims (no-op)
-- These used to wire UNIT_SPELLCAST / cooldowns / etc.
-- Now they are intentionally empty: PersonaEngine only speaks
-- for spells when explicitly invoked via PE.FireBubble(...) in macros.
-- ##################################################

function SpellHooks.Init()
    -- Intentionally left blank.
    -- No events registered, no hooks created.
end

function SpellHooks.OnSpellCast(...)
    -- Intentionally no-op.
end

function SpellHooks.OnCooldownStart(...)
    -- Intentionally no-op.
end

function SpellHooks.OnCooldownReady(...)
    -- Intentionally no-op.
end

-- If any old code calls Init on login, this keeps it harmless.
SpellHooks.Init()

-- ##################################################
-- Module registration
-- ##################################################

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Spell Hooks (macro-only mode)",
        class = "engine",
        notes = "Automatic spell trigger hooks disabled; use PE.FireBubble in macros.",
    })
end
