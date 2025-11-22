-- ##################################################
-- PE_CopporclangAlerts.lua
-- Special Copporclang-only alerts (Mongoose Fury full stacks)
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

local TARGET_CHARACTER_NAME = "Copporclang"

-- Retail right now: Mongoose Fury maxes at 5 stacks. If Blizz changes it,
-- adjust this value.
local MONGOOSE_FURY_FULL_STACKS = 5

-- SpellID for Mongoose Fury buff (double-check if you like, but this is current).
local MONGOOSE_FURY_SPELL_ID = 259388

-- Optional: your custom sound file. Replace with whatever path you actually use.
-- You can also set this to nil if you only want animation.
local ALERT_SOUND = "Interface\\AddOns\\PersonaEngine\\Media\\Max! Capacitors.ogg"

----------------------------------------------------
-- Personal "chat bubble" for Mongoose Fury stacks
----------------------------------------------------

local bubbleFrame
local lastShownStacks = 0

local function EnsureBubbleFrame()
    if bubbleFrame then return bubbleFrame end

    bubbleFrame = CreateFrame("Frame", "PE_CopporclangBubble", UIParent)
    bubbleFrame:SetSize(20, 20)
    bubbleFrame:SetPoint("CENTER", UIParent, "CENTER", -458, -146) -- move if you want

    -- Simple background
    local bg = bubbleFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.6) -- dark translucent

    -- Simple border-ish outline (fake)
    local border = bubbleFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(1, 1, 1, 0.15)

    -- Text
    bubbleFrame.text = bubbleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bubbleFrame.text:SetPoint("CENTER")
    bubbleFrame.text:SetText("0")

    bubbleFrame:Hide()
    return bubbleFrame
end

local function ShowMongooseBubble(stacks)
    local frame = EnsureBubbleFrame()

    -- Don’t spam updates if nothing changed
    if frame:IsShown() and stacks == lastShownStacks then
        return
    end
    lastShownStacks = stacks

    -- Copporclang-style line, very short
    if stacks and stacks > 0 then
        frame.text:SetText(string.format("%d", stacks))
        frame:Show()
    else
        frame:Hide()
    end
end

local function HideMongooseBubble()
    local frame = bubbleFrame
    if frame then
        frame:Hide()
    end
    lastShownStacks = 0
end


----------------------------------------------------
-- STATE
----------------------------------------------------

local alertedForCurrentBuff = false

local function IsCopporclang()
    local name = UnitName("player")
    return name == TARGET_CHARACTER_NAME
end

----------------------------------------------------
-- AURA HELPERS
----------------------------------------------------

local function GetMongooseFuryStacks()
    -- Retail-friendly: new aura APIs
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(MONGOOSE_FURY_SPELL_ID)
        if aura then
            return aura.applications or aura.charges or 0
        end
    end

    -- Fallback: use AuraUtil if available
    if AuraUtil and AuraUtil.FindAuraByName then
        local name, icon, count = AuraUtil.FindAuraByName("Mongoose Fury", "player", "HELPFUL")
        return count or 0
    end

    -- Old-school fallback: scan UnitAura
    local i = 1
    while true do
        local name, _, count, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellId == MONGOOSE_FURY_SPELL_ID or name == GetSpellInfo(MONGOOSE_FURY_SPELL_ID) then
            return count or 0
        end
        i = i + 1
    end

    return 0
end

----------------------------------------------------
-- EFFECT: what actually happens when full stacked
----------------------------------------------------

local function TriggerMongooseFullAlert()
    -- Safety: only Copporclang, only in combat
    if not IsCopporclang() then return end
    if not UnitAffectingCombat("player") then return end

    -- 1) Play sound (if configured)
    if ALERT_SOUND and PlaySoundFile then
		print("Mongoose Fury Maxed...")
		PlaySoundFile(ALERT_SOUND, "SFX")
	end

    -- 2) Trigger animation via PersonaEngine if you want
    -- Hook into your existing VFX/icon logic here.
    -- Example: flash the main PersonaEngine icon, *if* you have something like that:
    if PE.VFX and PE.VFX.FlashIcon then
        -- You can adjust params in PE_VFX.lua to taste (speed, alpha, etc.)
        PE.VFX.FlashIcon("MONGOOSE_FULL_ALERT")
    end

    -- 3) You could also make Copporclang say something here:
    -- if PE.Say then
    --     PE.Say("system", "MONGOOSE_FULL", "Max stacks online. Bite something important.")
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
        -- Once we know this isn't Copporclang, we can stop listening entirely.
        self:UnregisterAllEvents()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        alertedForCurrentBuff = false
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Left combat; next full-stack window can alert again.
        alertedForCurrentBuff = false
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat; reset so first full stack in this fight can alert.
        alertedForCurrentBuff = false
        return
    end

    if event == "UNIT_AURA" then
		if unit ~= "player" then return end

		local stacks = GetMongooseFuryStacks()

		-- Update personal bubble any time stacks change (in combat only)
		if UnitAffectingCombat("player") and stacks and stacks > 0 then
			ShowMongooseBubble(stacks)
		else
			HideMongooseBubble()
		end

		-- Existing full-stack alert logic
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

-- DEBUG: force test command
SLASH_PEMONGTEST1 = "/pemong"
SlashCmdList.PEMONGTEST = function()
    print("[PE] /pemong test triggered.")
    -- Optional: temporarily comment these two lines out while testing
    -- if not IsCopporclang() then print("[PE] Not Copporclang."); return end
    -- if not UnitAffectingCombat("player") then print("[PE] Not in combat."); return end

    TriggerMongooseFullAlert()
end


print("|cff00ff00[PersonaEngine]|r Copporclang alerts module loaded.")