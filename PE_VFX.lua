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
local GLOW_FADE_IN_DURATION    = 2.0   -- dim -> bright
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

        -- Order 1: fade from bright to dim
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetOrder(1)
        fadeOut:SetFromAlpha(GLOW_ON_MAX_ALPHA)
        fadeOut:SetToAlpha(GLOW_ON_MIN_ALPHA)
        fadeOut:SetDuration(GLOW_FADE_OUT_DURATION)
        fadeOut:SetSmoothing("IN_OUT")

        -- Order 2: pause at dim (if desired) by doing a no-op alpha animation
        if GLOW_PAUSE_AT_MIN > 0 then
            local pause = ag:CreateAnimation("Alpha")
            pause:SetOrder(2)
            pause:SetFromAlpha(GLOW_ON_MIN_ALPHA)
            pause:SetToAlpha(GLOW_ON_MIN_ALPHA)
            pause:SetDuration(GLOW_PAUSE_AT_MIN)
        end

        -- Order 3: fade from dim back to bright
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetOrder(3)
        fadeIn:SetFromAlpha(GLOW_ON_MIN_ALPHA)
        fadeIn:SetToAlpha(GLOW_ON_MAX_ALPHA)
        fadeIn:SetDuration(GLOW_FADE_IN_DURATION)
        fadeIn:SetSmoothing("IN_OUT")

        tex.PersonaEngineAG = ag
    end

    ------------------------------------------------
    -- Watch SR_On and start/stop the animation
    -- IMPORTANT: we do NOT touch alpha while the
    -- animation is running; we only adjust color
    -- and alpha when OFF.
    ------------------------------------------------
    if not btn.PersonaEngineWatcher then
        local watcher = CreateFrame("Frame", nil, btn)
        local lastSR  = nil

        watcher:SetScript("OnUpdate", function()
            local ag = tex.PersonaEngineAG
            local sr = (SR_On == 1)

            if sr ~= lastSR then
                lastSR = sr

                if sr then
                    -- Turn ON: set color, let animation control alpha
                    tex:SetVertexColor(
                        ICON_ON_VERTEX_COLOR.r,
                        ICON_ON_VERTEX_COLOR.g,
                        ICON_ON_VERTEX_COLOR.b
                    )

                    -- Start at max alpha and let fadeOut run
                    tex:SetAlpha(GLOW_ON_MAX_ALPHA)

                    if ag and not ag:IsPlaying() then
                        ag:Play()
                    end
                else
                    -- Turn OFF: stop animation and set static dim state
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
