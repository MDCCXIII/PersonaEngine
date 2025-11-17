-- PE_Slash.lua
-- Slash command registration & help registry for Persona Engine

local MODULE = "Slash"
local PE     = PE  -- capture global into local

if PE and PE.LogLoad then
    PE.LogLoad(MODULE)
end

------------------------------------------------------------
-- Local API references (perf + safety)
------------------------------------------------------------
local print          = print
local tonumber       = tonumber
local tostring       = tostring
local type           = type
local ipairs         = ipairs
local pairs          = pairs
local math_abs       = math.abs
local math_huge      = math.huge
local string_format  = string.format
local str_match      = string.match
local str_lower      = string.lower
local str_gsub       = string.gsub

local SlashCmdList   = SlashCmdList

------------------------------------------------------------
-- Slash Help Registry
------------------------------------------------------------
PE.SlashHelp = PE.SlashHelp or {}
local SlashHelp = PE.SlashHelp

local function RegisterSlashHelp(id, data)
    data.id    = id
    data.order = data.order or 100
    table.insert(SlashHelp, data)
end

local function PrintSlashHelp()
    if #SlashHelp == 0 then
        print("|cff66ccff[Persona]|r No registered commands in help registry.")
        return
    end

    table.sort(SlashHelp, function(a, b)
        if a.order == b.order then
            return (a.command or "") < (b.command or "")
        end
        return a.order < b.order
    end)

    print("|cff66ccff[PersonaEngine] Available commands:|r")
    for _, info in ipairs(SlashHelp) do
        local cmd = info.command or ""
        local aliasText = ""

        if info.aliases and #info.aliases > 0 then
            aliasText = " (aliases: " .. table.concat(info.aliases, ", ") .. ")"
        end

        print(("  |cffffff80%s|r%s"):format(cmd, aliasText))

        if info.description then
            print("   " .. info.description)
        end
        if info.usage then
            print("   |cffaaaaaaUsage: " .. info.usage .. "|r")
        end
    end
end

------------------------------------------------------------
-- /persona /pe (central dispatcher)
------------------------------------------------------------
SLASH_PERSONAENGINE1 = "/persona"
SLASH_PERSONAENGINE2 = "/pe"

SlashCmdList["PERSONAENGINE"] = function(msg)
    msg = msg or ""

    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd  = cmd and str_lower(cmd) or ""
    rest = rest or ""

    -- No subcommand or "config" -> toggle/open config
    if cmd == "" or cmd == "config" then
        if PE and PE.ToggleConfig then
            PE.ToggleConfig()
        elseif PE and PE.Log then
            PE.Log(1, "|cffff0000[PersonaEngine]|r Config UI not ready.")
        else
            print("|cffff0000[PersonaEngine]|r Config UI not ready.")
        end
        return
    end

    if cmd == "on" then
        SR_On = 1
        if PE and PE.Log then
            PE.Log("|cff00ff88[PersonaEngine]|r Speech engine |cff00ff00ON|r.")
        else
            print("|cff00ff88[PersonaEngine]|r Speech engine |cff00ff00ON|r.")
        end
        return
    end

    if cmd == "off" then
        SR_On = 0
        if PE and PE.Log then
            PE.Log("|cff00ff88[PersonaEngine]|r Speech engine |cffff0000OFF|r.")
        else
            print("|cff00ff88[PersonaEngine]|r Speech engine |cffff0000OFF|r.")
        end
        return
    end

    if cmd == "log" then
        local lvl = tonumber(rest)
        if not lvl then
            print("|cff66ccff[Persona]|r Usage: /pe log <0–5>")
            print("|cff66ccff[Persona]|r 0=NONE 1=ERROR 2=WARN 3=INFO 4=DEBUG 5=TRACE")
            print("|cff66ccff[Persona]|r Current:", tostring(PE_LogLevel))
            return
        end

        if lvl < 0 or lvl > 5 then
            print("|cffff0000[Persona] Invalid log level.|r Must be 0–5.")
            return
        end

        PE_LogLevel = lvl
        print("|cff66ccff[Persona]|r Log level set to", lvl)
        return
    end

    if cmd == "help" then
        PrintSlashHelp()
        return
    end

    -- Unknown subcommand
    print("|cff66ccff[Persona]|r Unknown subcommand: |cffffff80" .. cmd .. "|r")
    print("|cff66ccff[Persona]|r Try |cffffff80/pe help|r for a list of commands.")
end

RegisterSlashHelp("pe_main", {
    command     = "/pe",
    aliases     = { "/persona" },
    description = "Open Persona Engine config or control core behavior.",
    usage       = "/pe, /pe on, /pe off, /pe log <0–5>, /pe help",
    order       = 10,
})

------------------------------------------------------------
-- /pedev -- DevMode toggle
------------------------------------------------------------
SLASH_PEDEVMODE1 = "/pedev"

SlashCmdList["PEDEVMODE"] = function()
    PersonaEngineDB.DevMode = not PersonaEngineDB.DevMode

    local msg = "|cffffd200Developer Mode:|r "
        .. (PersonaEngineDB.DevMode and "|cff00ff00ON|r" or "|cffff0000OFF|r")

    if PE and PE.Log then
        PE.Log(msg)
    else
        print(msg)
    end
end

RegisterSlashHelp("pedev", {
    command     = "/pedev",
    description = "Toggle PersonaEngine developer mode for extra logs/features.",
    usage       = "/pedev",
    order       = 40,
})

------------------------------------------------------------
-- /brainsize -- Brain button scale
------------------------------------------------------------
local brainScales = { 0.9, 1.0, 1.1, 1.2, 1.5, 2.0 }

SLASH_PE_BRAINSIZE1 = "/brainsize"

SlashCmdList["PE_BRAINSIZE"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""

    local current = (PersonaEngineDB.button and PersonaEngineDB.button.scale) or 1.2

    -- No argument => cycle through presets
    if msg == "" then
        local idx      = 1
        local bestDiff = math_huge

        for i, s in ipairs(brainScales) do
            local d = math_abs(s - current)
            if d < bestDiff then
                bestDiff = d
                idx      = i
            end
        end

        idx = idx + 1
        if idx > #brainScales then
            idx = 1
        end

        local newScale = brainScales[idx]
        PersonaEngineDB.button.scale = newScale

        if PersonaEngineButton then
            PersonaEngineButton:SetScale(newScale)
        end

        local msgOut = string_format(
            "|cff00ff88Persona Engine button scale now %.1f (cycled)|r",
            newScale
        )

        if PE and PE.Log then
            PE.Log(msgOut)
        else
            print(msgOut)
        end

        return
    end

    -- Argument present => numeric scale
    local newScale = tonumber(msg)
    if not newScale then
        if PE and PE.Log then
            PE.Log(1, "|cffff5555/brainsize expects a number, e.g. /brainsize 1.3|r")
        else
            print("|cffff5555/brainsize expects a number, e.g. /brainsize 1.3|r")
        end
        return
    end

    if newScale <= 0 then
        local err = "|cffff5555Scale must be > 0, got: " .. msg .. "|r"
        if PE and PE.Log then
            PE.Log(1, err)
        else
            print(err)
        end
        return
    end

    PersonaEngineDB.button.scale = newScale

    if PersonaEngineButton then
        PersonaEngineButton:SetScale(newScale)
    end

    local msgOut = string_format(
        "|cff00ff88Persona Engine button scale now %.2f (manual)|r",
        newScale
    )

    if PE and PE.Log then
        PE.Log(msgOut)
    else
        print(msgOut)
    end
end

RegisterSlashHelp("brainsize", {
    command     = "/brainsize",
    description = "Cycle or set the Persona brain button size.",
    usage       = "/brainsize (cycle presets)\n/brainsize 1.3",
    order       = 60,
})

------------------------------------------------------------
-- /brainreset -- Reset brain button position/size
------------------------------------------------------------
SLASH_PE_BRAINRESET1 = "/brainreset"

SlashCmdList["PE_BRAINRESET"] = function()
    local d = PersonaEngine_ButtonDefaults or {}

    PersonaEngineDB.button.point    = d.point    or "TOPRIGHT"
    PersonaEngineDB.button.relPoint = d.relPoint or "TOPRIGHT"
    PersonaEngineDB.button.x        = d.x        or -150
    PersonaEngineDB.button.y        = d.y        or -170
    PersonaEngineDB.button.scale    = d.scale    or 1.2
    PersonaEngineDB.button.strata   = d.strata   or "MEDIUM"
    PersonaEngineDB.button.level    = d.level    or 5

    if PersonaEngineButton then
        PersonaEngineButton:ClearAllPoints()
        PersonaEngineButton:SetPoint(
            PersonaEngineDB.button.point,
            UIParent,
            PersonaEngineDB.button.relPoint,
            PersonaEngineDB.button.x,
            PersonaEngineDB.button.y
        )

        PersonaEngineButton:SetScale(PersonaEngineDB.button.scale or 1.0)
        PersonaEngineButton:SetFrameStrata(PersonaEngineDB.button.strata or "MEDIUM")

        local lvl = PersonaEngineDB.button.level
        if lvl then
            PersonaEngineButton:SetFrameLevel(lvl)
        end
    end

    local msgOut = "|cff00ff88Persona Engine button reset to defaults.|r"
    if PE and PE.Log then
        PE.Log(msgOut)
    else
        print(msgOut)
    end
end

RegisterSlashHelp("brainreset", {
    command     = "/brainreset",
    description = "Reset the Persona brain button to default position and size.",
    usage       = "/brainreset",
    order       = 61,
})

------------------------------------------------------------
-- /cloud9 -- Cloud9 debug panel
------------------------------------------------------------
SLASH_PE_CLOUD91 = "/cloud9"

SlashCmdList["PE_CLOUD9"] = function()
    if not Cloud9_CreateFrame or not Cloud9_DebugDump then
        if PE and PE.Log then
            PE.Log(1, "[Persona] Cloud9 panel not available.")
        else
            print("[Persona] Cloud9 panel not available.")
        end
        return
    end

    local frame = Cloud9_CreateFrame()
    -- frame is kept for side effects; no direct use needed here

    local text = Cloud9_DebugDump()
    if cloud9Edit then
        cloud9Edit:SetText(text)
        cloud9Edit:HighlightText(0, 0)
        cloud9Edit:SetFocus()
    end
end

RegisterSlashHelp("cloud9", {
    command     = "/cloud9",
    description = "Open the Cloud9 debug window with Persona button diagnostics.",
    usage       = "/cloud9",
    order       = 80,
})

------------------------------------------------------------
-- /petaint -- taint report + monitor
------------------------------------------------------------
SLASH_PE_TAINT1 = "/petaint"

SlashCmdList["PE_TAINT"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    msg = str_lower(msg or "")

    if not PE or not PE.Taint then
        print("|cff66ccff[Persona]|r Taint module not loaded.")
        return
    end

    if msg == "" or msg == "report" then
        if PE.Taint.DumpReport then
            PE.Taint.DumpReport()
        else
            print("|cff66ccff[Persona]|r Taint report function missing.")
        end
    elseif msg == "ui" or msg == "panel" or msg == "show" then
        if PE.Taint.ShowPanel then
            PE.Taint.ShowPanel()
        else
            print("|cff66ccff[Persona]|r Taint panel function missing.")
        end
    else
        print("|cff66ccff[Persona]|r /petaint usage:")
        print("  /petaint - print taint summary + recent entries")
        print("  /petaint report - same as above")
        print("  /petaint panel - open taint monitor UI")
    end
end

RegisterSlashHelp("petaint", {
    command     = "/petaint",
    description = "Show PersonaEngine taint summary or open the live taint monitor.",
    usage       = "/petaint\n/petaint report\n/petaint panel",
    order       = 90,
})

------------------------------------------------------------
-- /srtest -- Force SR line for testing
------------------------------------------------------------
SLASH_PE_SRTEST1 = "/srtest"

SlashCmdList["PE_SRTEST"] = function()
    if PE and PE.Log then
        PE.Log("|cff00ff88[/srtest] SR_On =", SR_On, "type(SR) =", type(SR))
    else
        print("|cff00ff88[/srtest] SR_On =", SR_On, "type(SR) =", type(SR))
    end

    if type(SR) ~= "function" then
        local msg = "|cffff5555[/srtest] SR engine function not available.|r"
        if PE and PE.Log then
            PE.Log(1, msg)
        else
            print(msg)
        end
        return
    end

    SR_On = 1

    SR({
        chance  = 1,
        phr     = {
            "[TEST] Synthetic voice box initialized — resonance stable, ego unstable.",
            "[TEST] Copporclang’s hyper-intelligent vocal manifold online. Expect unsolicited genius.",
            "[TEST] Phonic actuators calibrated. Articulating nonsense at machine precision.",
            "[TEST] Testing… testing… is this thing even on? Hello? Can anyone hear me, or is my inner monologue leaking again?",
        },
        channel = "SAY",
    })
end

RegisterSlashHelp("srtest", {
    command     = "/srtest",
    description = "Force a PersonaEngine SR test line (bypasses randomness).",
    usage       = "/srtest",
    order       = 70,
})

------------------------------------------------------------
-- Module registration
------------------------------------------------------------
if PE and PE.LogInit then
    PE.LogInit(MODULE)
end

if PE and PE.RegisterModule then
    PE.RegisterModule("Slash", {
        name  = "Slash Commands",
        class = "ui",
    })
end
