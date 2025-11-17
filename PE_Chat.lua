-- PE_Chat.lua
-- Chat reaction engine for Persona Engine

local PE = PE          -- global table provided by PE_Globals.lua
local MODULE = "Chat"

if PE and PE.LogLoad then
    PE.LogLoad(MODULE)
end

------------------------------------------------
-- Local API references (perf + safety)
------------------------------------------------
local CreateFrame      = CreateFrame
local UnitName         = UnitName
local SendChatMessage  = SendChatMessage
local math_random      = math.random
local string_match     = string.match

------------------------------------------------
-- Frame + events
------------------------------------------------
local chatFrame = CreateFrame("Frame", "PersonaEngineChatFrame")

chatFrame:RegisterEvent("CHAT_MSG_SAY")
chatFrame:RegisterEvent("CHAT_MSG_YELL")
chatFrame:RegisterEvent("CHAT_MSG_PARTY")
chatFrame:RegisterEvent("CHAT_MSG_RAID")
chatFrame:RegisterEvent("CHAT_MSG_GUILD")
chatFrame:RegisterEvent("CHAT_MSG_WHISPER")

chatFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
chatFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
chatFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")

local playerName = UnitName("player")

------------------------------------------------
-- Helpers
------------------------------------------------
local function GetShortName(fullName)
    if not fullName then
        return nil
    end
    -- Strip realm suffix; fall back to original if no match
    local short = string_match(fullName, "([^%-]+)")
    return short or fullName
end

local function mapEventToProfileKey(event)
    if event == "CHAT_MSG_SAY" then
        return "SAY"
    elseif event == "CHAT_MSG_YELL" then
        return "YELL"
    elseif event == "CHAT_MSG_PARTY" then
        return "PARTY"
    elseif event == "CHAT_MSG_RAID" then
        return "RAID"
    elseif event == "CHAT_MSG_GUILD" then
        return "GUILD"
    elseif event == "CHAT_MSG_WHISPER" then
        return "WHISPER_IN"
    elseif event == "CHAT_MSG_MONSTER_SAY" then
        return "NPC_SAY"
    elseif event == "CHAT_MSG_MONSTER_YELL" then
        return "NPC_YELL"
    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        return "NPC_EMOTE"
    end
    return nil
end

------------------------------------------------
-- Core handler
------------------------------------------------
local function PersonaEngine_HandleChatEvent(self, event, msg, author, ...)
    -- Guard: core table / permission helper must exist
    if not PE or not PE.CanSpeak or not PE.CanSpeak() then
        return
    end

    -- Don't react to our own chat (except monsters, which aren't us anyway)
    local shortAuthor = GetShortName(author)
    if shortAuthor == playerName and not string_match(event or "", "MONSTER") then
        return
    end

    -- Profiles are owned by the core; if missing, bail quietly
    if not PersonaEngine_GetActiveProfile then
        return
    end

    local profile = PersonaEngine_GetActiveProfile()
    if not profile or not profile.chatReactions then
        return
    end

    local key = mapEventToProfileKey(event)
    if not key then
        return
    end

    local cfg = profile.chatReactions[key]
    if not cfg then
        return
    end

    local phrases = cfg.phrases
    if type(phrases) ~= "table" or #phrases == 0 then
        return
    end

    local chance = tonumber(cfg.chance) or 10
    if chance < 1 then
        -- Degenerate config; never trigger instead of spamming
        return
    end

    local channel = cfg.channel or key

    ------------------------------------------------
    -- Special case: reply to whispers
    ------------------------------------------------
    if key == "WHISPER_IN" and cfg.reply and event == "CHAT_MSG_WHISPER" then
        local target = shortAuthor
        if not target then
            return
        end

        if math_random(chance) ~= 1 then
            return
        end

        local phrase = phrases[math_random(#phrases)]

        -- Optional inflection pass
        if PE.InflectMaybe then
            phrase = PE.InflectMaybe(phrase, "CHAT_WHISPER_REPLY", nil, {
                sender  = target,
                message = msg,
            })
        end

        if phrase and phrase ~= "" then
            -- Direct whisper reply bypasses SR wrapper
            SendChatMessage(phrase, "WHISPER", nil, target)
        end
        return
    end

    ------------------------------------------------
    -- Normal outward reactions (SAY, YELL, PARTY, etc.)
    ------------------------------------------------
    if not SR then
        -- SR engine not available; fail gracefully
        return
    end

    SR({
        chance  = chance,
        phr     = phrases,
        channel = channel,
        eventId = "CHAT_REACTION_" .. key,
        ctx     = {
            sender  = shortAuthor,
            message = msg,
        },
    })
end

chatFrame:SetScript("OnEvent", PersonaEngine_HandleChatEvent)

------------------------------------------------
-- Module registration
------------------------------------------------
if PE then
    if PE.LogInit then
        PE.LogInit(MODULE)
    end

    if PE.RegisterModule then
        PE.RegisterModule("Chat", {
            name  = "Chat Reactions",
            class = "engine",
        })
    end
end
