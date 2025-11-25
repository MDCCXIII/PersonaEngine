-- ##################################################
-- PE_CopporclangAlerts.lua
-- Special Copporclang-only alerts (Mongoose Fury stacks)
-- ##################################################

local MODULE = "CopporclangAlerts"
local PE     = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

----------------------------------------------------
-- CONFIG
----------------------------------------------------

local TARGET_CHARACTER_NAME     = "Copporclang"
local MONGOOSE_FURY_FULL_STACKS = 5          -- max stacks
local MONGOOSE_FURY_SPELL_ID    = 259388     -- Mongoose Fury buff

local ALERT_SOUND = "Interface\\AddOns\\PersonaEngine\\Media\\Max! Capacitors.ogg"

----------------------------------------------------
-- PHRASE SETS
----------------------------------------------------

local PHRASE_SETS = {
    {
        id = "FucksToGive",
        name = "Fucks To Give (Reversed)",
        lines = {
            [0] = "Oh wait, everyone calm down, I found my fucking marbles, let's just think about this for a while...",
            [1] = "Tasu, I'm running out of fucks to give! I've only got 4 left.",
            [2] = "There goes another, down to 3 fucks now...",
            [3] = "Complacency was never an option, 2 fucks remaining...",
            [4] = "I'm really on my final straw, Tasu.",
            [5] = "That's it! I got no more fucks left, let's fucking go!!!",
        },
    },
    {
        id = "CapacitorCharge",
        name = "Capacitor Charge",
        lines = {
            [0] = "Systems cooled. Charges vented. We can think again... briefly.",
            [1] = "Charge routine started. I've still got four clean swings in me.",
            [2] = "Voltage rising. Three charges left before we go nuclear.",
            [3] = "Two charges remaining. This is where smart people disengage.",
            [4] = "Final charge primed. Try not to whiff this one.",
            [5] = "All charges spent! Dump everything into something expensive!",
        },
    },
}

----------------------------------------------------
-- STATE
----------------------------------------------------

local alertedForCurrentBuff   = false
local currentStacks           = 0
local currentPhraseSetIndex   = nil

local function IsCopporclang()
    local name = UnitName("player")
    return name == TARGET_CHARACTER_NAME
end

----------------------------------------------------
-- AURA HELPERS
----------------------------------------------------

local function GetMongooseFuryStacks()
    -- New aura API
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(MONGOOSE_FURY_SPELL_ID)
        if aura then
            return aura.applications or aura.charges or 0
        end
    end

    -- AuraUtil helper
    if AuraUtil and AuraUtil.FindAuraByName then
        local name, _, count = AuraUtil.FindAuraByName("Mongoose Fury", "player", "HELPFUL")
        return count or 0
    end

    -- Old-school UnitAura scan
    local i = 1
    while true do
        local name, _, count, _, _, _, _, _, _, spellId =
            UnitAura("player", i, "HELPFUL")
        if not name then
            break
        end
        if spellId == MONGOOSE_FURY_SPELL_ID or name == GetSpellInfo(MONGOOSE_FURY_SPELL_ID) then
            return count or 0
        end
        i = i + 1
    end

    return 0
end

----------------------------------------------------
-- FULL-STACK EFFECT
----------------------------------------------------

local function TriggerMongooseFullAlert()
    if not IsCopporclang() then return end
    if not UnitAffectingCombat("player") then return end

    if ALERT_SOUND and PlaySoundFile then
        PlaySoundFile(ALERT_SOUND, "SFX")
    end

    if PE.VFX and PE.VFX.FlashIcon then
        PE.VFX.FlashIcon("MONGOOSE_FULL_ALERT")
    end
end

----------------------------------------------------
-- PHRASE / BUBBLE LOGIC
----------------------------------------------------

local function PickPhraseSetIndex()
    local n = #PHRASE_SETS
    if n == 0 then
        return nil
    end
    return math.random(1, n)
end

local function SayInBubble(text)
    if PE and PE.Bubble and PE.Bubble.Say then
        PE.Bubble.Say(text or "")
    end
end

-- Handle transitions from prevStacks -> newStacks
local function HandleStackTransition(prevStacks, newStacks)
    -- Normalize
    prevStacks = prevStacks or 0
    newStacks  = newStacks or 0

    -- No change → nothing to do
    if newStacks == prevStacks then
        return
    end

    -- Reaching 0: play the [0] line once, then clear set and hide bubble
    if newStacks == 0 then
        if prevStacks > 0 and currentPhraseSetIndex then
            local set  = PHRASE_SETS[currentPhraseSetIndex]
            local line = set and set.lines[0]
            if line and line ~= "" then
                SayInBubble(line)
            else
                SayInBubble("")
            end
        else
            SayInBubble("")
        end
        currentPhraseSetIndex = nil
        return
    end

    -- Having stacks (1..5)
    if prevStacks == 0 or not currentPhraseSetIndex then
        currentPhraseSetIndex = PickPhraseSetIndex()
    end

    local set = currentPhraseSetIndex and PHRASE_SETS[currentPhraseSetIndex]
    if not set then
        return
    end

    local line = set.lines[newStacks]
    if line and line ~= "" then
        SayInBubble(line)
    end
end

----------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", function(self, event, unit, ...)
    if not IsCopporclang() then
        self:UnregisterAllEvents()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        alertedForCurrentBuff = false
        currentStacks         = 0
        currentPhraseSetIndex = nil
        SayInBubble("")
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: collapse to 0 stacks
        if currentStacks > 0 then
            HandleStackTransition(currentStacks, 0)
        else
            SayInBubble("")
        end
        alertedForCurrentBuff = false
        currentStacks         = 0
        currentPhraseSetIndex = nil
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat; allow a new full-stack alert
        alertedForCurrentBuff = false
        return
    end

    if event == "UNIT_AURA" then
        if unit ~= "player" then
            return
        end

        local stacks = GetMongooseFuryStacks()

        -- Treat "no buff" or "not in combat" as 0 for persona purposes
        if not UnitAffectingCombat("player") then
            stacks = 0
        end

        -- Handle bubble + phrase logic
        HandleStackTransition(currentStacks, stacks)
        currentStacks = stacks

        -- Full-stack alert (sound/VFX)
        if stacks >= MONGOOSE_FURY_FULL_STACKS and UnitAffectingCombat("player") then
            if not alertedForCurrentBuff then
                alertedForCurrentBuff = true
                TriggerMongooseFullAlert()
            end
        else
            alertedForCurrentBuff = false
        end
    end
end)

----------------------------------------------------
-- /pemong debug command
----------------------------------------------------

SLASH_PEMONGTEST1 = "/pemong"
SlashCmdList.PEMONGTEST = function()
    print("[PersonaEngine] /pemong test triggered.")
    TriggerMongooseFullAlert()
end

print("|cff00ff00[PersonaEngine]|r Systems Initializing...")
