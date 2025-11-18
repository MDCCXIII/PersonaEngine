-- ##################################################
-- PE_NPCMemory.lua
-- Track NPC names from targets and monster chat
-- ##################################################

local MODULE = "NPCMemory"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] PE_NPCMemory.lua loaded without PE core!|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

PE.NPCMemory = PE.NPCMemory or {}
local NPC     = PE.NPCMemory

local Runtime = PE.Runtime or {}
PE.Runtime    = Runtime

----------------------------------------------------
-- SavedVariables schema
----------------------------------------------------
-- PersonaEngineDB.npc = {
--   known = {
--     ["Jaina Proudmoore"] = {
--        count    = 12,
--        lastSeen = timestamp,
--        lastZone = "Stormwind City",
--     },
--   },
-- }

local function EnsureNPCDB()
    PersonaEngineDB       = PersonaEngineDB or {}
    PersonaEngineDB.npc   = PersonaEngineDB.npc or {}
    local root            = PersonaEngineDB.npc
    root.known            = root.known or {}
    return root
end

local function TouchNPC(name)
    if not name or name == "" then
        return
    end

    local root  = EnsureNPCDB()
    local known = root.known
    local entry = known[name]
    local now   = time()
    local zone  = GetRealZoneText() or ""

    if not entry then
        entry = {
            count    = 0,
            lastSeen = now,
            lastZone = zone,
        }
        known[name] = entry
    end

    entry.count    = (entry.count or 0) + 1
    entry.lastSeen = now
    entry.lastZone = zone

    Runtime.lastNPCSeen = name
end

----------------------------------------------------
-- Event handlers
----------------------------------------------------

local function OnTargetChanged()
    if not UnitExists("target") then
        return
    end
    if UnitIsPlayer("target") then
        return
    end

    local name = UnitName("target")
    TouchNPC(name)
end

local function OnMonsterChat(event, msg, sender, ...)
    if sender and sender ~= "" then
        TouchNPC(sender)
        Runtime.lastNPCSpeaker = sender
    end
end

----------------------------------------------------
-- Public API
----------------------------------------------------

function NPC.GetKnown()
    local root = EnsureNPCDB()
    return root.known
end

function NPC.GetLastSeenNPC()
    return Runtime.lastNPCSeen
end

function NPC.GetLastSpeaker()
    return Runtime.lastNPCSpeaker
end

----------------------------------------------------
-- Wire events
----------------------------------------------------

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    f:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            OnTargetChanged()
        else
            OnMonsterChat(event, ...)
        end
    end)
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "NPC Memory",
        class = "data",
    })
end
