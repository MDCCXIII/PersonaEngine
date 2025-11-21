-- ##################################################
-- PE_MacroStudio.lua
-- Persona Engine macro helpers (save / pickup / defaults)
-- ##################################################

local MODULE = "MacroStudio"
local PE = PE

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
local DEFAULT_ICON_ID       = 134400 -- question-mark icon

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
    if not s then
        return ""
    end
    if utf8len(s) <= maxChars then
        return s
    end

    -- fallback: trim bytes until the utf8 counter is happy
    local bytes = #s
    while bytes > 0 and utf8len(s) > maxChars do
        bytes = bytes - 1
        s = string.sub(s, 1, bytes)
    end
    return s
end

----------------------------------------------------
-- Default macro builder for an action
----------------------------------------------------

function MS.BuildDefaultMacroForAction(action)
    if not action then
        return ""
    end

    if action.kind == "spell" then
        return string.format(
            "#showtooltip %s\n" ..
            "/run PE.Say(\"spell\", %d)\n" ..
            "/cast %s",
            action.name or "",
            action.id or 0,
            action.name or ""
        )
    elseif action.kind == "item" then
        return string.format(
            "#showtooltip item:%d\n" ..
            "/use item:%d\n" ..
            "/run PE.Say(\"item\", %d)",
            action.id or 0,
            action.id or 0,
            action.id or 0
        )
    elseif action.kind == "emote" then
        return string.format(
            "/e %s\n" ..
            "/run PE.Say(\"emote\", \"%s\")",
            tostring(action.name or ""),
            tostring(action.name or "")
        )
    end

    -- Fallback: treat as generic action
    return string.format(
        "#showtooltip %s\n" ..
        "/run PE.Say(\"%s\", %s)\n",
        tostring(action.name or "?"),
        tostring(action.kind or "spell"),
        tostring(action.id or "?")
    )
end

----------------------------------------------------
-- Save / update macro
----------------------------------------------------

function MS.SaveMacro(macroName, macroBody, iconTexture)
    macroName = (macroName and macroName:match("^%s*(.-)%s*$")) or ""
    macroName = utf8safe_sub(macroName, MAX_MACRO_NAME_CHARS)

    macroBody = macroBody or ""
    macroBody = utf8safe_sub(macroBody, MAX_MACRO_CHARS)

    if macroName == "" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("PersonaEngine: Macro name required.", 1, 0.2, 0.2)
        end
        return
    end

    local icon = iconTexture or DEFAULT_ICON_ID

    local index = GetMacroIndexByName(macroName)
    if index and index > 0 then
        -- Update existing macro (prefer character-specific if it exists that way already)
        EditMacro(index, macroName, icon, macroBody)
        if PE.Log then
            PE.Log(3, "MacroStudio: Updated macro", macroName)
        end
        return
    end

    local numGlobal, numChar = GetNumMacros()
    local maxGlobal = MAX_GLOBAL_MACROS or 120
    local maxChar   = MAX_CHARACTER_MACROS or 18

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

    if PE.Log then
        PE.Log(
            3,
            "MacroStudio: Created macro",
            macroName,
            useCharacter and "(character)" or "(global)"
        )
    end
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
