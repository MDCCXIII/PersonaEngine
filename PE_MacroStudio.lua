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

-- ---------------------------------------------------
-- Constants
-- ---------------------------------------------------

local MAX_MACRO_CHARS = 255

-- Blizzard macro API treats icon "1" as the question-mark icon in the icon list.
local DEFAULT_ICON_INDEX = 1

-- Expose for UI consumers
MS.DEFAULT_ICON_INDEX = DEFAULT_ICON_INDEX

-- ---------------------------------------------------
-- UTF-8 helpers (macro body clamp)
-- ---------------------------------------------------

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

-- ---------------------------------------------------
-- Default macro builder for an action
-- ---------------------------------------------------

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

-- ---------------------------------------------------
-- Icon index: build once, reuse everywhere
-- ---------------------------------------------------
-- This gives us:
--   * A unified list of macro icons (spell + item) like Blizzard’s picker
--   * Lookups by index / fileID / name substring
--   * Nerdy tooltip data for the icon picker

local iconIndex      -- array of { kind="SPELL"/"ITEM", macroIndex=<per-API index>, texture=<path|fileID>, fileID?, name, globalIndex }
local iconIndexBuilt = false

local function ExtractBaseName(texture)
    if type(texture) ~= "string" then
        return nil
    end
    local base = texture:match("([^\\/:]+)$") or texture
    base = base:match("(.+)%..+$") or base
    return base:lower()
end

local function AddIconRecord(list, kind, macroIndex, texture)
    if not texture then
        return
    end

    local rec = {
        kind       = kind,            -- "SPELL" / "ITEM"
        macroIndex = macroIndex,      -- index for GetMacroIconInfo / GetMacroItemIconInfo
        texture    = texture,         -- path or fileDataID
        name       = ExtractBaseName(texture),
    }

    -- Try to get a numeric fileID if the API returns one
    if type(texture) == "number" then
        rec.fileID = texture
    end

    table.insert(list, rec)
end

local function BuildIconIndex()
    if iconIndexBuilt then
        return
    end

    iconIndex = {}

    -- Spells / generic icons
    if GetNumMacroIcons and GetMacroIconInfo then
        local count = GetNumMacroIcons()
        for i = 1, count do
            local tex = GetMacroIconInfo(i)
            AddIconRecord(iconIndex, "SPELL", i, tex)
        end
    end

    -- Item icons
    if GetNumMacroItemIcons and GetMacroItemIconInfo then
        local count = GetNumMacroItemIcons()
        for i = 1, count do
            local tex = GetMacroItemIconInfo(i)
            AddIconRecord(iconIndex, "ITEM", i, tex)
        end
    end

    -- Stamp global index (1-based, across both spell+item list)
    for idx, rec in ipairs(iconIndex) do
        rec.globalIndex = idx
    end

    iconIndexBuilt = true
end

-- Public: return the full icon index (read-only)
function MS.GetIconIndex()
    BuildIconIndex()
    return iconIndex
end

-- Public: helper to find a “best” icon for a token
-- token: string or number (index, fileID, or partial name)
-- filterKind: nil / "ALL" / "SPELL" / "ITEM"
function MS.FindIconByToken(token, filterKind)
    if not token or token == "" then
        return nil
    end

    BuildIconIndex()

    token = tostring(token)
    local numToken = tonumber(token)
    local lcToken  = token:lower()

    local bestMatch = nil
    filterKind = filterKind or "ALL"

    for _, rec in ipairs(iconIndex) do
        if filterKind == "ALL" or filterKind == rec.kind then
            -- 1) Exact numeric hit: globalIndex, per-API index, or fileID
            if numToken then
                if rec.globalIndex == numToken or rec.macroIndex == numToken or rec.fileID == numToken then
                    return rec
                end
            end

            -- 2) Name substring hit
            if rec.name and rec.name:find(lcToken, 1, true) then
                bestMatch = bestMatch or rec
            else
                -- 3) Fallback: search inside fileID string
                local fid = rec.fileID and tostring(rec.fileID) or ""
                if fid ~= "" and fid:find(lcToken, 1, true) then
                    bestMatch = bestMatch or rec
                end
            end
        end
    end

    return bestMatch
end

-- ---------------------------------------------------
-- Save / update macro
-- ---------------------------------------------------

function MS.SaveMacro(macroName, macroBody, iconTexture)
    macroName = (macroName and macroName:match("^%s*(.-)%s*$")) or ""
    macroBody = macroBody or ""

    if macroName == "" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("PersonaEngine: Macro name required.", 1, 0.2, 0.2)
        end
        return
    end

    -- Enforce 255-char limit just in case
    macroBody = utf8safe_sub(macroBody, MAX_MACRO_CHARS)

    local icon = iconTexture or DEFAULT_ICON_INDEX

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

-- ---------------------------------------------------
-- Pickup a macro by name (for drag to bars)
-- ---------------------------------------------------

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

-- ---------------------------------------------------
-- Module registration
-- ---------------------------------------------------

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Macro Studio",
        class = "core",
    })
end

if PE.LogInit then
    PE.LogInit(MODULE)
end
