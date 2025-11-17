-- ##################################################
-- PE_SpellHooks.lua
-- Spell hooks (legacy) - now disabled in favor of macro-only FireBubble.
-- ##################################################

local PE = PE or {}
local MODULE = "SpellHooks"

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- Public marker so other code can know hooks are intentionally disabled.
PE.SpellHooks = PE.SpellHooks or {}
PE.SpellHooks.enabled = false

-- Legacy API shims (no-op) so any old callers don't explode.
-- These used to wire UNIT_SPELLCAST / cooldown / etc.
-- Now they are intentionally empty: PersonaEngine only speaks for
-- spells when explicitly invoked via PE.FireBubble(...) in macros.

function PE.SpellHooks.Init()
    -- Intentionally left blank.
    -- No events registered, no hooks created.
end

function PE.SpellHooks.OnSpellCast(...)
    -- Intentionally no-op.
end

function PE.SpellHooks.OnCooldownStart(...)
    -- Intentionally no-op.
end

function PE.SpellHooks.OnCooldownReady(...)
    -- Intentionally no-op.
end

-- If any old code calls Init on login, this keeps it harmless.
PE.SpellHooks.Init()

if PE.LogInit then
    PE.LogInit(MODULE)
end

PE.RegisterModule("SpellHooks", {
    name  = "Spell Hooks (macro-only mode)",
    class = "engine",
    notes = "Automatic spell trigger hooks disabled; use PE.FireBubble in macros.",
})
