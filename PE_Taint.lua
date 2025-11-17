-- ##################################################
-- PE_Taint.lua
-- Live taint monitoring + on-demand taint report
-- ##################################################

local PE = PE
local MODULE = "Taint"

if PE.LogLoad then
    PE.LogLoad(MODULE)
else
    -- Failsafe
    if PE.Log then PE.Log(4, "[PersonaEngine] Loading Taint module...") end
end

local Taint = PE.Taint or {}
PE.Taint = Taint

Taint.logs    = Taint.logs or {}
Taint.maxLogs = 200

----------------------------------------------------
-- Internal logging
----------------------------------------------------
local function Taint_AddLog(event, addon, info)
    local ts   = date("%H:%M:%S")
    addon      = addon or "UNKNOWN"
    info       = info or ""

    local entry = {
        time  = ts,
        event = event,
        addon = tostring(addon),
        info  = tostring(info),
    }

    table.insert(Taint.logs, 1, entry) -- newest first
    if #Taint.logs > Taint.maxLogs then
        table.remove(Taint.logs)       -- drop oldest
    end

    if PE.Log then
        if addon == "PersonaEngine" or info:find("PersonaEngine") then
            PE.Log(1, "[TAINT]", event, addon, info)
        else
            PE.Log(4, "[TAINT]", event, addon, info)
        end
    end
end

----------------------------------------------------
-- Event listener for taint-related events
----------------------------------------------------
local frame = CreateFrame("Frame")
Taint.frame = frame

frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("MACRO_ACTION_BLOCKED")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    -- arg1 = addon, arg2 = func/info (varies by event)
    Taint_AddLog(event, arg1, arg2)
end)

----------------------------------------------------
-- Runtime scan of PE namespace for "suspicious" links
----------------------------------------------------
local protectedFuncs = {
    "CastSpell", "CastSpellByName", "UseAction", "UseItem", "UseInventoryItem",
    "PickupSpell", "PickupItem", "PickupPetAction",
    "SpellStopCasting", "SpellStopTargeting", "SpellTargetUnit",
    "TargetUnit", "TargetNearest", "TargetEnemy", "TargetFriend",
    "FocusUnit", "ClearFocus",
}

local protectedTemplates = {
    "SecureActionButtonTemplate",
    "SecureHandlerStateTemplate",
    "SecureHandlerAttributeTemplate",
    "SecureUnitButtonTemplate",
}

local function Taint_ScanPersonaNamespace()
    local results = {
        funcRefs   = {},
        frames     = {},
        templates  = {},
    }

    -- 1) Check if any PE fields reference protected functions
    for key, value in pairs(PE) do
        for _, fname in ipairs(protectedFuncs) do
            if value == _G[fname] then
                table.insert(results.funcRefs, ("PE.%s -> %s"):format(tostring(key), fname))
            end
        end

        -- 2) Frame protection check
        if type(value) == "table" and type(value.GetObjectType) == "function" then
            local ok, objType = pcall(value.GetObjectType, value)
            if ok and objType then
                local isProtected = false

                if type(value.IsProtected) == "function" then
                    local ok2, prot = pcall(value.IsProtected, value)
                    if ok2 and prot then
                        isProtected = true
                    end
                end

                if isProtected then
                    table.insert(results.frames,
                        ("PE.%s is a protected %s frame"):format(tostring(key), tostring(objType)))
                end
            end
        end
    end

    -- 3) Look for direct global template references (paranoia)
    for _, tmpl in ipairs(protectedTemplates) do
        if _G[tmpl] then
            table.insert(results.templates, tmpl)
        end
    end

    return results
end

----------------------------------------------------
-- Public: dump taint report to chat
----------------------------------------------------
function Taint.DumpReport()
    local prefix = "|cff66ccff[PersonaEngine:Taint]|r "

    -- 1) Summary of blocked/forbidden actions
    local total  = #Taint.logs
    local peHits = 0

    for _, e in ipairs(Taint.logs) do
        if e.addon == "PersonaEngine" or e.info:find("PersonaEngine") then
            peHits = peHits + 1
        end
    end

    print(prefix .. "Taint log entries:", total, "(PersonaEngine-related:", peHits .. ")")

    if total == 0 then
        print(prefix .. "No taint events recorded this session.")
    else
        print(prefix .. "Most recent taint events:")
        for i = 1, math.min(5, total) do
            local e = Taint.logs[i]
            print(("  [%s] %s - %s (%s)"):format(
                e.time, e.event, e.addon, e.info))
        end
    end

    -- 2) Scan the PE namespace for suspicious links
    local scan = Taint_ScanPersonaNamespace()

    if #scan.funcRefs == 0 and #scan.frames == 0 then
        print(prefix .. "No protected function references or protected frames detected inside PE.")
    else
        if #scan.funcRefs > 0 then
            print(prefix .. "Suspicious PE references to protected functions:")
            for _, line in ipairs(scan.funcRefs) do
                print("  " .. line)
            end
        end

        if #scan.frames > 0 then
            print(prefix .. "Protected frames inside PE (verify these are safe):")
            for _, line in ipairs(scan.frames) do
                print("  " .. line)
            end
        end
    end
end

----------------------------------------------------
-- Simple scrollable taint monitor panel
----------------------------------------------------
local monitorFrame, monitorScroll, monitorEditBox

local function Taint_BuildTextBlob()
    local out = {}

    for i, e in ipairs(Taint.logs) do
        out[#out+1] = ("[%s] %s - %s (%s)"):format(
            e.time, e.event, e.addon, e.info)
    end

    if #out == 0 then
        out[1] = "No taint events captured yet this session."
    end

    return table.concat(out, "\n")
end

local function Taint_EnsureMonitorFrame()
    if monitorFrame then
        return monitorFrame
    end

    monitorFrame = CreateFrame("Frame", "PersonaEngine_TaintMonitor", UIParent, "BackdropTemplate")
    monitorFrame:SetSize(500, 320)
    monitorFrame:SetPoint("CENTER")
    monitorFrame:SetMovable(true)
    monitorFrame:EnableMouse(true)
    monitorFrame:RegisterForDrag("LeftButton")
    monitorFrame:SetScript("OnDragStart", monitorFrame.StartMoving)
    monitorFrame:SetScript("OnDragStop", monitorFrame.StopMovingOrSizing)
    monitorFrame:SetClampedToScreen(true)

    monitorFrame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 },
    })
    monitorFrame:SetBackdropColor(0, 0, 0, 0.9)

    local title = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("PersonaEngine - Taint Monitor")

    monitorScroll = CreateFrame("ScrollFrame", nil, monitorFrame, "UIPanelScrollFrameTemplate")
    monitorScroll:SetPoint("TOPLEFT", 10, -24)
    monitorScroll:SetPoint("BOTTOMRIGHT", -30, 10)

    monitorEditBox = CreateFrame("EditBox", nil, monitorScroll)
    monitorEditBox:SetMultiLine(true)
    monitorEditBox:SetFontObject(ChatFontNormal)
    monitorEditBox:SetAutoFocus(false)
    monitorEditBox:EnableMouse(true)
    monitorEditBox:SetWidth(450)

    monitorEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    monitorScroll:SetScrollChild(monitorEditBox)

    local close = CreateFrame("Button", nil, monitorFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", monitorFrame, "TOPRIGHT")

    return monitorFrame
end

local function Taint_RefreshMonitor()
    if not monitorFrame or not monitorEditBox then
        return
    end

    local text = Taint_BuildTextBlob()
    monitorEditBox:SetText(text)
    monitorEditBox:HighlightText(0, 0)
    monitorScroll:SetVerticalScroll(0)
end

function Taint.ShowPanel()
    local f = Taint_EnsureMonitorFrame()
    f:Show()
    Taint_RefreshMonitor()
end

----------------------------------------------------
-- Hook: refresh monitor whenever a taint log is added
----------------------------------------------------
local oldAddLog = Taint_AddLog
Taint_AddLog = function(event, addon, info)
    oldAddLog(event, addon, info)
    if monitorFrame and monitorFrame:IsShown() then
        Taint_RefreshMonitor()
    end
end

if PE.LogInit then
    PE.LogInit(MODULE)
else
    if PE.Log then PE.Log(4, "[PersonaEngine] Taint module initialized.") end
end

PE.RegisterModule("Taint", {
    name  = "Taint Monitor",
    class = "dev",
})
