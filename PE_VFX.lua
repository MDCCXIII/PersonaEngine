-- ##################################################
-- PE_VFX.lua
-- Visual FX for the free-floating PersonaEngineButton
-- ##################################################

local MODULE = "VFX"
local PE     = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

----------------------------------------------------
-- Glow / brightness tuning knobs
--  - Adjust these to taste.
----------------------------------------------------

-- When SR_On == 1 (engine enabled), the icon will pulse
-- between these alpha levels over time.
local GLOW_ON_MAX_ALPHA        = 1.0   -- fully bright
local GLOW_ON_MIN_ALPHA        = 0.20  -- how dim the pulse gets

-- How fast the pulse animates (seconds)
local GLOW_FADE_OUT_DURATION   = 2.0   -- bright -> dim
local GLOW_FADE_IN_DURATION    = 2.0  -- dim -> bright
local GLOW_PAUSE_AT_MIN        = 0.5   -- optional pause at dim end

-- When SR_On == 0 (engine disabled), the icon is dim + static
local ICON_OFF_ALPHA           = 0.4
local ICON_ON_VERTEX_COLOR     = { r = 1.0, g = 1.0, b = 1.0 }
local ICON_OFF_VERTEX_COLOR    = { r = 0.4, g = 0.4, b = 0.4 }

----------------------------------------------------
-- Setup pulse animation on the free-floating button
----------------------------------------------------

local function PersonaEngine_SetupButtonVisuals()
    local btn = _G.PersonaEngineButton
    if not btn or not btn.icon then
        return
    end

    local tex = btn.icon

    ------------------------------------------------
    -- Create / configure animation group (once)
    ------------------------------------------------
    if not tex.PersonaEngineAG then
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("REPEAT")

        -- Fade from bright to dim
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(GLOW_ON_MAX_ALPHA)
        fadeOut:SetToAlpha(GLOW_ON_MIN_ALPHA)
        fadeOut:SetDuration(GLOW_FADE_OUT_DURATION)
        fadeOut:SetSmoothing("IN_OUT")

        -- Fade from dim back to bright
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(GLOW_ON_MIN_ALPHA)
        fadeIn:SetToAlpha(GLOW_ON_MAX_ALPHA)
        fadeIn:SetDuration(GLOW_FADE_IN_DURATION)
        fadeIn:SetSmoothing("IN_OUT")
        fadeIn:SetStartDelay(GLOW_PAUSE_AT_MIN)

        tex.PersonaEngineAG = ag
    end

    ------------------------------------------------
    -- Watch SR_On and start/stop the animation
    ------------------------------------------------
    if not btn.PersonaEngineWatcher then
        local watcher = CreateFrame("Frame", nil, btn)
        watcher:SetScript("OnUpdate", function()
            local ag = tex.PersonaEngineAG

            if SR_On == 1 then
                -- ON: bright + pulsing
                tex:SetVertexColor(
                    ICON_ON_VERTEX_COLOR.r,
                    ICON_ON_VERTEX_COLOR.g,
                    ICON_ON_VERTEX_COLOR.b
                )
                tex:SetAlpha(GLOW_ON_MAX_ALPHA)

                if ag and not ag:IsPlaying() then
                    ag:Play()
                end
            else
                -- OFF: dim, no animation
                if ag and ag:IsPlaying() then
                    ag:Stop()
                end

                tex:SetVertexColor(
                    ICON_OFF_VERTEX_COLOR.r,
                    ICON_OFF_VERTEX_COLOR.g,
                    ICON_OFF_VERTEX_COLOR.b
                )
                tex:SetAlpha(ICON_OFF_ALPHA)
            end
        end)
        btn.PersonaEngineWatcher = watcher
    end
end

----------------------------------------------------
-- Defer setup slightly so the button exists
----------------------------------------------------

if C_Timer and C_Timer.After then
    C_Timer.After(0.3, PersonaEngine_SetupButtonVisuals)
else
    PersonaEngine_SetupButtonVisuals()
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then
    PE.LogInit(MODULE)
end

if PE.RegisterModule then
    PE.RegisterModule("VFX", {
        name  = "Visual FX",
        class = "fx",
    })
end
