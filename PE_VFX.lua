-- PersonaEngine_Visuals.lua
-- Visual tweaks for the minimap button (size, glow, etc.)
local MODULE = "VFX"
PE.LogLoad(MODULE)


local Icon = LibStub("LibDBIcon-1.0", true)


if not Icon then return end

-- ##################################################
-- Make PersonaEngine minimap button bigger but still hug the border
-- ##################################################

local function PersonaEngine_AdjustMinimapButton()
    local btn = Icon:GetMinimapButton("PersonaEngine")
    if not btn or not Minimap then return end

    -- Make the button itself bigger
    btn:SetScale(1.4)  -- tweak this: 1.2, 1.3, 1.4, etc.

    -- Get centers in screen coords
    local mx, my = Minimap:GetCenter()
    local bx, by = btn:GetCenter()
    if not (mx and my and bx and by) then return end

    local dx, dy = bx - mx, by - my
    if dx == 0 and dy == 0 then return end

    -- Direction from minimap center to button
    local angle = math.atan2(dy, dx)

    -- Radius of minimap and button in pixels
    local mr = Minimap:GetWidth() / 2            -- minimap radius
    local br = (btn:GetWidth() * btn:GetScale()) / 2  -- button radius (scaled)

    -- Where should the button center be so the edge touches the minimap edge?
    -- Slight inset so it doesn't visually "float" outside the ring
    local newDist = mr + br - 200   -- increase/decrease this 2px fudge as desired

    local nx = math.cos(angle) * newDist
    local ny = math.sin(angle) * newDist

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
end

-- Run once on load (or when this file executes)
PersonaEngine_AdjustMinimapButton()

-- If the user drags the icon, re-adjust after LibDBIcon updates its pos
local btn = Icon:GetMinimapButton("PersonaEngine")
if btn then
    btn:HookScript("OnDragStop", PersonaEngine_AdjustMinimapButton)
end


local function PersonaEngine_SetupGlow()
    local btn = Icon:GetMinimapButton("PersonaEngine")
    if not btn then return end

    local tex = btn.icon
    if not tex then return end

    local ag = tex:CreateAnimationGroup()
    ag:SetLooping("REPEAT")

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(0.6)
    fadeOut:SetSmoothing("IN_OUT")

    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.3)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.6)
    fadeIn:SetSmoothing("IN_OUT")
    fadeIn:SetStartDelay(0.6)

    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        if SR_On == 1 then
            if not ag:IsPlaying() then ag:Play() end
        else
            if ag:IsPlaying() then ag:Stop() end
            tex:SetAlpha(1)
        end
    end)
end

-- Run after everything is created
C_Timer.After(0.5, function()
    PersonaEngine_AdjustMinimapButton()
    PersonaEngine_SetupGlow()
end)

-- ##################################################
-- Icon Glow / Pulse Animation when SR_On == 1
-- ##################################################

-- Visuals: dark when off, flashing when on, for the custom button

local function PersonaEngine_SetupButtonVisuals()
    local btn = _G.PersonaEngineButton
    if not btn or not btn.icon then return end

    local tex = btn.icon

    -- Create animation group once
    if not tex.PersonaEngineAG then
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("REPEAT")

        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.3)
        fadeOut:SetDuration(0.5)
        fadeOut:SetSmoothing("IN_OUT")

        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0.3)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.5)
        fadeIn:SetSmoothing("IN_OUT")
        fadeIn:SetStartDelay(0.5)

        tex.PersonaEngineAG = ag
    end

    if not btn.PersonaEngineWatcher then
        local watcher = CreateFrame("Frame", nil, btn)
        watcher:SetScript("OnUpdate", function()
            local ag = tex.PersonaEngineAG

            if SR_On == 1 then
                -- ON: bright + flashing
                tex:SetVertexColor(1, 1, 1)
                tex:SetAlpha(1)
                if ag and not ag:IsPlaying() then
                    ag:Play()
                end
            else
                -- OFF: dim, no animation
                if ag and ag:IsPlaying() then
                    ag:Stop()
                end
                tex:SetVertexColor(0.4, 0.4, 0.4)
                tex:SetAlpha(0.4)
            end
        end)
        btn.PersonaEngineWatcher = watcher
    end
end

-- Run after UI has created the button
C_Timer.After(0.3, PersonaEngine_SetupButtonVisuals)

PE.LogInit(MODULE)
PE.RegisterModule("VFX", {
    name  = "Visual FX",
    class = "fx",
})