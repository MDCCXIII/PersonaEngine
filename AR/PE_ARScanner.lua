-- ##################################################
-- AR/PE_ARScanner.lua
-- Unit + tooltip scanner for AR HUD
-- ##################################################
local MODULE = "AR Scanner"
local PE = PE
local AR = PE and PE.AR
if not AR then return end

AR.Scanner = AR.Scanner or {}
local Scanner = AR.Scanner

Scanner.units   = Scanner.units or {}
Scanner.tooltip = Scanner.tooltip or nil

------------------------------------------------------
-- Internal helpers
------------------------------------------------------

local function EnsureTooltip()
    if Scanner.tooltip then
        return Scanner.tooltip
    end

    -- Hidden tooltip we can scrape safely
    local tt = CreateFrame("GameTooltip", "PE_ARHiddenTooltip", UIParent, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    Scanner.tooltip = tt
    return tt
end

local function BuildTooltipForUnit(unitID, data)
    local tt = EnsureTooltip()
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetUnit(unitID)

    local tooltip = {
        header    = data.name or UnitName(unitID) or "",
        subHeader = nil,
        lines     = {},
        tags      = {
            isPlayer     = UnitIsPlayer(unitID) or false,
            isQuestGiver = false,
            isVendor     = false,
            isTrainer    = false,
        },
    }

    -- Read first few lines off our hidden tooltip
    for i = 1, 6 do
        local fs = _G["PE_ARHiddenTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text ~= "" then
            if i == 1 then
                tooltip.header = text
            elseif i == 2 then
                tooltip.subHeader = text
            else
                table.insert(tooltip.lines, text)

                -- Very crude tag inference, we can refine later.
                if text:find("Quest", 1, true) then
                    tooltip.tags.isQuestGiver = true
                end
                if text:find("Vendor", 1, true) or text:find("Merchant", 1, true) then
                    tooltip.tags.isVendor = true
                end
                if text:find("Trainer", 1, true) then
                    tooltip.tags.isTrainer = true
                end
            end
        end
    end

    return tooltip
end

local function UpdateCastInfo(unitID, data)
    local name, _, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unitID)
    if not name then
        name, _, _, startTime, endTime, _, notInterruptible = UnitChannelInfo(unitID)
    end

    if name then
        data.isCasting              = true
        data.currentCastName        = name
        data.castEndTimeMS          = endTime
        data.castNotInterruptible   = not notInterruptible
        data.isCastingInterruptible = not notInterruptible
    else
        data.isCasting              = false
        data.currentCastName        = nil
        data.castEndTimeMS          = nil
        data.castNotInterruptible   = false
        data.isCastingInterruptible = false
    end
end

------------------------------------------------------
-- Scanner lifecycle
------------------------------------------------------

function Scanner.Init()
    -- Register events through the core so we don’t create extra frames
    AR.RegisterEvent("PLAYER_TARGET_CHANGED")
    AR.RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    AR.RegisterEvent("NAME_PLATE_UNIT_ADDED")
    AR.RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    AR.RegisterEvent("MODIFIER_STATE_CHANGED")
    AR.RegisterEvent("UNIT_FACTION")
    AR.RegisterEvent("UNIT_FLAGS")
    AR.RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    AR.RegisterEvent("UNIT_SPELLCAST_START")
    AR.RegisterEvent("UNIT_SPELLCAST_STOP")
    AR.RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    AR.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
end

function Scanner.OnEvent(event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        Scanner:UpdateUnit("target")

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitExists("mouseover") then
            Scanner:UpdateUnit("mouseover")
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        Scanner:UpdateUnit(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        Scanner:RemoveUnit(unit)

    elseif event == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if key == "LALT" or key == "RALT" or key == "ALT" then
            local was = AR.expanded
            AR.expanded = (down == 1) or IsAltKeyDown()
            if was ~= AR.expanded and AR.HUD and AR.HUD.Refresh then
                AR.HUD.Refresh("MODIFIER_STATE_CHANGED")
            end
        end

    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" or event == "UNIT_THREAT_LIST_UPDATE" then
        local unit = ...
        if unit and UnitGUID(unit) then
            Scanner:UpdateUnit(unit)
        end

    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
        local unit = ...
        if unit and UnitGUID(unit) then
            Scanner:UpdateUnit(unit)
        end
    end
end

------------------------------------------------------
-- Unit tracking
------------------------------------------------------

function Scanner:UpdateUnit(unitID)
    if not unitID or not UnitExists(unitID) then
        return
    end

    local guid = UnitGUID(unitID)
    if not guid then
        return
    end

    local data = Scanner.units[guid] or {}

    data.unit   = unitID
    data.guid   = guid
    data.name   = UnitName(unitID)
    data.level  = UnitLevel(unitID)

    data.isPlayer   = UnitIsPlayer(unitID) or false
    data.hostile    = UnitIsEnemy("player", unitID) or false
    data.friendly   = UnitIsFriend("player", unitID) or false
    data.reaction   = UnitReaction("player", unitID) or 4
    data.classif    = UnitClassification(unitID) or "normal"
    data.creature   = UnitCreatureType(unitID)
    data.faction    = UnitFactionGroup(unitID)
    data.isPet      = UnitIsUnit(unitID, "pet") or UnitIsOtherPlayersPet(unitID) or false

    data.isTarget    = UnitIsUnit(unitID, "target") or false
    data.isMouseover = UnitIsUnit(unitID, "mouseover") or false

    -- Boss / elite flags
    data.isBoss  = (data.classif == "worldboss")
    data.isElite = (data.classif == "elite" or data.classif == "rareelite")

    -- Casting info
    UpdateCastInfo(unitID, data)

    -- Tooltip snapshot
    data.tooltip  = BuildTooltipForUnit(unitID, data)
    data.lastSeen = GetTime()

    Scanner.units[guid] = data
end

function Scanner:RemoveUnit(unitID)
    if not unitID then return end
    local guid = UnitGUID(unitID)
    if guid then
        Scanner.units[guid] = nil
    end
end

------------------------------------------------------
-- Snapshot for HUD
------------------------------------------------------

function Scanner.BuildSnapshot()
    -- Return a simple sorted list for HUD.
    local snapshot = {}
    local playerLevel = UnitLevel("player") or 0
    local now = GetTime()

    for guid, data in pairs(Scanner.units) do
        -- prune very old entries
        if data.lastSeen and (now - data.lastSeen) > 30 then
            Scanner.units[guid] = nil
        else
            local score = 0

            -- hard priority: target > mouseover > others
            if data.isTarget then
                score = score + 300
            elseif data.isMouseover then
                score = score + 200
            end

            if data.hostile then score = score + 30 end
            if data.isBoss then score = score + 40 end
            if data.isElite then score = score + 15 end
            if data.isCastingInterruptible then score = score + 20 end

            if data.level and data.level > playerLevel + 2 then
                score = score + 5
            elseif data.level and data.level < playerLevel - 3 then
                score = score - 5
            end

            table.insert(snapshot, {
                guid  = guid,
                unit  = data.unit,
                score = score,
                data  = data,
            })
        end
    end

    table.sort(snapshot, function(a, b)
        return a.score > b.score
    end)

    return snapshot
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

PE.LogInit(MODULE)
PE.RegisterModule("AR Scanner", {
    name  = "AR Scanner",
    class = "AR HUD",
})