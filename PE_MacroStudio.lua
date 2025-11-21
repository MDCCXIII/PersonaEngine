-- ##################################################
-- PE_MacroStudio.lua
-- Persona Engine macro helpers (save / pickup / persona config)
-- ##################################################

local MODULE = "MacroStudio"
local PE     = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

PE.MacroStudio = PE.MacroStudio or {}
local MS = PE.MacroStudio

local MAX_MACRO_CHARS       = 255
local MAX_MACRO_NAME_CHARS  = 16
local DEFAULT_ICON_ID       = 134400 -- question mark


----------------------------------------------------
-- UTF-8 helpers (name/body safety)
----------------------------------------------------

local function utf8len(s)
    if strlenutf8 then
        return strlenutf8(s)
    end
    return #s
end

local function utf8safe_sub(s, maxChars)
    if not s then return "" end
    if utf8len(s) <= maxChars then
        return s
    end

    -- Fallback: trim bytes until utf8 counter is happy
    local bytes = #s
    while bytes > 0 and utf8len(s) > maxChars do
        bytes = bytes - 1
        s = string.sub(s, 1, bytes)
    end
    return s
end


----------------------------------------------------
-- Macro DB root (persona config keyed by macro)
----------------------------------------------------

local function EnsureMacroDB()
    PersonaEngineDB          = PersonaEngineDB or {}
    PersonaEngineDB.macros   = PersonaEngineDB.macros or {}

    local root = PersonaEngineDB.macros
    root.global    = root.global    or {}
    root.character = root.character or {}

    return root
end

local function NormalizeScope(scope)
    if scope == "global" or scope == "character" then
        return scope
    end
    return "character"
end


----------------------------------------------------
-- Scope helpers
----------------------------------------------------

local function GetScopeFromIndex(index)
    if not index or index <= 0 or not GetNumMacros then
        return nil, nil
    end

    local numGlobal, numChar = GetNumMacros()
    if index <= numGlobal then
        return "global", index
    end

    return "character", index - numGlobal
end

local function ResolveMacroRef(ref)
    if not ref then return end

    local index, name
    local t = type(ref)

    if t == "number" then
        index = ref
        name  = select(1, GetMacroInfo(index))
    elseif t == "string" then
        name  = ref
        index = GetMacroIndexByName(name)
    else
        return
    end

    if not index or index <= 0 or not name or name == "" then
        return
    end

    local scope = select(1, GetScopeFromIndex(index))
    return index, scope, name
end

MS.ResolveMacroRef = ResolveMacroRef


----------------------------------------------------
-- Default macro builder for an action
----------------------------------------------------
-- Builds a macro body that calls PE.Say("macroName") and
-- performs the underlying action (spell/item/emote).

function MS.BuildDefaultMacroForAction(action, macroName)
    if not action then
        return ""
    end

    macroName = utf8safe_sub(macroName or "MyMacro", MAX_MACRO_NAME_CHARS)
    if macroName == "" then
        macroName = "MyMacro"
    end

    local sayLine = string.format('/run PE.Say("%s")', macroName)

    if action.kind == "spell" then
        return string.format(
            "#showtooltip %s\n%s\n/cast %s",
            action.name or "",
            sayLine,
            action.name or ""
        )
    elseif action.kind == "item" then
        return string.format(
            "#showtooltip item:%d\n%s\n/use item:%d",
            action.id or 0,
            sayLine,
            action.id or 0
        )
    elseif action.kind == "emote" then
        return string.format(
            "%s\n/e %s",
            sayLine,
            tostring(action.name or "")
        )
    end

    -- Fallback: generic macro that just speaks
    return sayLine .. "\n"
end


----------------------------------------------------
-- Save / update macro (returns index + scope)
----------------------------------------------------
-- Returns: index, scope ("global"/"character"), slotIndexWithinScope

function MS.SaveMacro(macroName, macroBody, iconTexture)
    macroName  = (macroName and macroName:match("^%s*(.-)%s*$")) or ""
    macroName  = utf8safe_sub(macroName, MAX_MACRO_NAME_CHARS)
    macroBody  = utf8safe_sub(macroBody or "", MAX_MACRO_CHARS)

    if macroName == "" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("PersonaEngine: Macro name required.", 1, 0.2, 0.2)
        end
        return
    end

    local icon = iconTexture or DEFAULT_ICON_ID

    local numGlobal, numChar, maxGlobal, maxChar = GetNumMacros()

    -- Update existing macro if it already exists
    local index = GetMacroIndexByName(macroName)
    if index and index > 0 then
        EditMacro(index, macroName, icon, macroBody)

        local scope, slotIndex = GetScopeFromIndex(index)
        if PE.Log then
            PE.Log(3, "MacroStudio: Updated macro", macroName, "(" .. (scope or "?") .. ")")
        end
        return index, scope, slotIndex
    end

    -- New macro: prefer character, fall back to global if needed
    local useCharacter = true
    if numChar >= maxChar and numGlobal < maxGlobal then
        useCharacter = false
    elseif numChar >= maxChar and numGlobal >= maxGlobal then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("PersonaEngine: Macro storage full.", 1, 0.2, 0.2)
        end
        return
    end

    CreateMacro(macroName, icon, macroBody, useCharacter)
    index = GetMacroIndexByName(macroName)

    local scope, slotIndex = GetScopeFromIndex(index)
    if PE.Log then
        PE.Log(
            3,
            "MacroStudio: Created macro",
            macroName,
            useCharacter and "(character)" or "(global)"
        )
    end

    return index, scope, slotIndex
end


----------------------------------------------------
-- Persona config binding per macro
----------------------------------------------------
-- Persist a reference from (scope, macroName) -> per-action cfg table.
-- cfg is typically the same table returned by PE.GetOrCreateActionConfig.

function MS.SavePersonaConfig(scope, macroName, cfg)
    if not cfg or not macroName or macroName == "" then
        return
    end

    scope = NormalizeScope(scope)
    local root = EnsureMacroDB()

    root[scope][macroName] = cfg

    if PE.Log then
        PE.Log(4, "MacroStudio: Bound persona config to macro", scope, macroName)
    end
end

-- Resolve what PE.Say should actually speak for a given macro.
-- Returns: kind, id, cfg (or nil if not configured)

function MS.GetSpeakPayload(ref)
    local index, scope, name = ResolveMacroRef(ref)
    if not index or not scope or not name then
        return
    end

    local root = EnsureMacroDB()
    local cfg  = root[scope] and root[scope][name]
    if not cfg then
        return
    end

    local kind = cfg._kind or cfg.actionKind
    local id   = cfg._id   or cfg.actionId
    if not kind or not id then
        return
    end

    return kind, id, cfg
end


----------------------------------------------------
-- Pickup a macro by name (for drag to bars)
----------------------------------------------------

function MS.PickupMacroByName(macroName)
    macroName = macroName or ""
    if macroName == "" then
        return
    end

    local index = GetMacroIndexByName(macroName)
    if not index or index <= 0 then
        if PE.Log then
            PE.Log(2, "MacroStudio: Macro not found for pickup:", macroName)
        end
        return
    end

    PickupMacro(index)
end


----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Macro Studio",
        class = "core",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
