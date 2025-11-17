-- PE_Chat.lua
local MODULE = "Chat"
PE.LogLoad(MODULE)

local PE = PE
if not PE then
    print("|cffff0000[PersonaEngine] PE_Chat.lua loaded without PE core!|r")
    return
end

-- Local handle to profile system (if available)
local Profiles = PE.Profiles

local f = CreateFrame("Frame", "PersonaEngineChatFrame")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_YELL")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_MONSTER_SAY")
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")

local playerName = UnitName("player")

local function mapEventToProfileKey(event, msg, author, ...)
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
end

local function PersonaEngine_HandleChatEvent(self, event, msg, author, ...)
    -- Respect global mute
    if not PE or not PE.CanSpeak or not PE.CanSpeak() then
        return
    end

    -- Don't react to our own speeches (unless we decide otherwise later)
    local shortAuthor = author and author:match("([^%-]+)")
    if shortAuthor == playerName and not event:match("MONSTER") then
        return
    end

    -- Get active profile via namespaced API first, then optional legacy global
    local profile
    if Profiles and Profiles.GetActiveProfile then
        profile = Profiles.GetActiveProfile()
    elseif _G.PersonaEngine_GetActiveProfile then
        profile = _G.PersonaEngine_GetActiveProfile()
    end

    if not profile or not profile.chatReactions then
        return
    end

    local key = mapEventToProfileKey(event, msg, author, ...)
    if not key then
        return
    end

    local cfg = profile.chatReactions[key]
    if not cfg or not cfg.phrases or #cfg.phrases == 0 then
        return
    end

    local channel = cfg.channel or key
    local chance  = cfg.chance or 10

    -- Special case: whisper replies
    if key == "WHISPER_IN" and cfg.reply and event == "CHAT_MSG_WHISPER" then
        local target = shortAuthor
        if not target then
            return
        end
        if math.random(chance) ~= 1 then
            return
        end

        local phrase = cfg.phrases[math.random(#cfg.phrases)]
        if PE.InflectMaybe then
            phrase = PE.InflectMaybe(phrase, "CHAT_WHISPER_REPLY", nil, { sender = target })
        end

        -- Direct whisper needs a target; we use the base API here.
		if not PE.CanSpeak() then return end
        SendChatMessage(phrase, "WHISPER", nil, target)
        return
    end

    -- Normal outward reactions (SAY, YELL, PARTY, etc.)
    SR({
        chance  = chance,
        phr     = cfg.phrases,
        channel = channel,
        eventId = "CHAT_REACTION_" .. key,
        ctx     = { sender = shortAuthor, message = msg },
    })
end

f:SetScript("OnEvent", PersonaEngine_HandleChatEvent)

PE.LogInit(MODULE)
PE.RegisterModule("Chat", {
    name  = "Chat Reactions",
    class = "engine",
})
