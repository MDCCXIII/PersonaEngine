-- ##################################################
-- AR/PE_ARScanner.lua
-- Unit + tooltip scanner for AR HUD
-- ##################################################

local PE = PE
local AR = PE and PE.AR
if not AR then return end

AR.Scanner = AR.Scanner or {}
local Scanner = AR.Scanner

Scanner.units = Scanner.units or {}

function Scanner.Init()
    -- Register events through the core so we don’t create extra frames
    AR.RegisterEvent("PLAYER_TARGET_CHANGED")
    AR.RegisterEvent("NAME_PLATE_UNIT_ADDED")
    AR.RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    AR.RegisterEvent("MODIFIER_STATE_CHANGED")
end

function Scanner.OnEvent(event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        Scanner:UpdateUnit("target")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        Scanner:UpdateUnit(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        Scanner:RemoveUnit(unit)
    elseif event == "MODIFIER_STATE_CHANGED" then
        -- alt expanded view, etc. Could notify AR.State
    end
end

function Scanner:UpdateUnit(unitID)
    -- Build a compact record (later we add tooltip, level, faction, etc.)
    local guid = UnitGUID(unitID)
    if not guid then return end

    local data = Scanner.units[guid] or {}
    data.unit = unitID
    data.guid = guid
    data.name = UnitName(unitID)
    data.hostile = UnitIsEnemy("player", unitID) or false
    data.friendly = UnitIsFriend("player", unitID) or false
    data.level = UnitLevel(unitID)

    -- TODO: pull tooltip info into data.tooltip

    data.lastSeen = GetTime()
    Scanner.units[guid] = data
end

function Scanner:RemoveUnit(unitID)
    local guid = UnitGUID(unitID)
    if guid then
        Scanner.units[guid] = nil
    end
end

function Scanner.BuildSnapshot()
    -- Return a simple sorted list for HUD.
    local snapshot = {}

    for guid, data in pairs(Scanner.units) do
        -- scoring heuristic
        local score = 0
        if data.unit == "target" then score = score + 100 end
        if data.hostile then score = score + 20 end
        if data.level and data.level > UnitLevel("player") then
            score = score + 5
        end

        table.insert(snapshot, {
            guid = guid,
            unit = data.unit,
            score = score,
            data  = data,
        })
    end

    table.sort(snapshot, function(a,b) return a.score > b.score end)
    return snapshot
end
