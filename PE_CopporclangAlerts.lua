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

-- Retail right now: Mongoose Fury maxes at 5 stacks. If Blizz changes it,
-- adjust this value.
local MONGOOSE_FURY_FULL_STACKS = 5

-- SpellID for Mongoose Fury buff.
local MONGOOSE_FURY_SPELL_ID    = 259388

-- Optional: your custom sound file. Replace with whatever path you actually use.
-- Set to nil if you only want bubble + VFX.
local ALERT_SOUND = "Interface\\AddOns\\PersonaEngine\\Media\\Max! Capacitors.ogg"

----------------------------------------------------
-- PHRASE SETS
-- Each set has entries for stacks 0..5.
-- Once a set is chosen at transition 0 -> 1, it is used until we go back to 0.
----------------------------------------------------

local PHRASE_SETS = {
    {
        id = "FucksToGive",
        name = "Fucks To Give (Reversed)",
        lines = {
            -- 0 stacks (reset)
            [0] = "Oh wait, everyone calm down, I found my fucking marbles, let's just think about this for a while...",
            -- 1–5 stacks; conceptually 5 - stacks “fucks left”
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

local function IsCopporclang()
    local name = UnitName("player")
    return name == TARGET_CHARACTER_NAME
end

-- For full-stack “special alert” logic
local alertedForCurrentBuff = false

-- For bubble phrase logic
local currentPhraseSetIndex = nil      -- which set we're using this 0→5 run
local lastStacksForPhrase   = 0        -- last stack count we actually spoke about

----------------------------------------------------
-- AURA HELPERS
----------------------------------------------------

local function GetMongooseFuryStacks()
    -- New-style aura API
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(MONGOOSE_FURY_SPELL_ID)
        if aura then
            return aura.applications or aura.charges or 0
        end
    end

    -- AuraUtil helper if present
    if AuraUtil and AuraUtil.FindAuraByName then
        local name, icon, count = AuraUtil.FindAuraByName("Mongoose Fury", "player", "HELPFUL")
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
-- PHRASE LOGIC
----------------------------------------------------

local function PickNewPhraseSetIndex()
    if #PHRASE_SETS == 0 then
        return nil
    end
    -- Simple RNG pick. If you later want weighting, do it here.
    return math.random(1, #PHRASE_SETS)
end

-- Return the text to show for a given stack count, or nil if nothing changed.
-- Handles:
--  - Selecting a phrase set at 0 -> 1
--  - Keeping that set while stacks > 0
--  - Playing the [0] line once when falling back to 0, then clearing the set
local function GetPhraseForStacks(stacks)
    stacks = stacks or 0

    -- Avoid spamming when nothing changed
    if stacks == lastStacksForPhrase then
        return nil
    end

    -- Dropped back to 0 stacks
    if stacks == 0 then
        local text
        if currentPhraseSetIndex then
            local set = PHRASE_SETS[currentPhraseSetIndex]
            if set and set.lines[0] then
                text = set.lines[0]
            end
        end
        currentPhraseSetIndex = nil
        lastStacksForPhrase   = 0
        return text or "" -- empty string will just hide the bubble
    end

    -- We have stacks (1–5)
    if lastStacksForPhrase == 0 then
        -- This is the transition 0 -> 1: pick a new set.
        currentPhraseSetIndex = PickNewPhraseSetIndex()
    end

    lastStacksForPhrase = stacks

    if not currentPhraseSetIndex then
        return nil
    end

    local set = PHRASE_SETS[currentPhraseSetIndex]
    if not set or not set.lines then
        return nil
    end

    return set.lines[stacks]
end

----------------------------------------------------
-- BUBBLE UPDATE
----------------------------------------------------

local function UpdateMongooseBubble(stacks)
    -- Outside combat we treat this as 0 stacks for bubble purposes.
    if not UnitAffectingCombat("player") then
        stacks = 0
    end

    local text = GetPhraseForStacks(stacks)
    if text == nil then
        -- No change, nothing to say.
        return
    end

    if not (PE and PE.Bubble and PE.Bubble.Say) then
        return
    end

    PE.Bubble.Say(text)
end

----------------------------------------------------
-- FULL-STACK EFFECT (sound + VFX)
----------------------------------------------------

local function TriggerMongooseFullAlert()
    -- Safety: only Copporclang, only in combat
    if not IsCopporclang() then
        return
    end
    if not UnitAffectingCombat("player") then
        return
    end

    -- 1) Play sound (if configured)
    if ALERT_SOUND and PlaySoundFile then
        PlaySoundFile(ALERT_SOUND, "SFX")
    end

    -- 2) Trigger animation via PersonaEngine VFX
    if PE.VFX and PE.VFX.FlashIcon then
        PE.VFX.FlashIcon("MONGOOSE_FULL_ALERT")
    end

    -- 3) Optional: also send a line via PE.Say if you want public flavor text.
    -- if PE.Say then
    --     PE.Say("system", "MONGOOSE_FULL",
    --         "Maximum stacks achieved. Strong suggestion: bite something dangerous.")
    -- end
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
    -- Hard gate: never do anything for other characters
    if not IsCopporclang() then
        self:UnregisterAllEvents()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        alertedForCurrentBuff = false
        currentPhraseSetIndex = nil
        lastStacksForPhrase   = 0
        UpdateMongooseBubble(0)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Left combat; reset both full-stack alert and phrase cycle.
        alertedForCurrentBuff = false
        currentPhraseSetIndex = nil
        lastStacksForPhrase   = 0
        UpdateMongooseBubble(0)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat; next full stack and phrase set are fresh.
        alertedForCurrentBuff = false
        -- Keep bubble off until we actually have stacks.
        return
    end

    if event == "UNIT_AURA" then
        if unit ~= "player" then
            return
        end

        local stacks = GetMongooseFuryStacks()

        -- Update bubble text for stacks
        UpdateMongooseBubble(stacks)

        -- Full-stack special alert
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
-- DEBUG: force test command
----------------------------------------------------

SLASH_PEMONGTEST1 = "/pemong"
SlashCmdList.PEMONGTEST = function()
    print("[PersonaEngine] /pemong test triggered.")

    -- For testing you can comment these two out:
    -- if not IsCopporclang() then print("[PE] Not Copporclang."); return end
    -- if not UnitAffectingCombat("player") then print("[PE] Not in combat."); return end

    TriggerMongooseFullAlert()
end

print("|cff00ff00[PersonaEngine]|r Copporclang alerts module loaded.")
