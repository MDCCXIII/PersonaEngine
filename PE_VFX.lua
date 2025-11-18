-- ##################################################
-- PE_VFX.lua
-- Visual tweaks for minimap button + custom status button
-- ##################################################

local MODULE = "VFX"
local PE = PE

if not PE or type(PE) ~= "table" then
    print("|cffff0000[PersonaEngine] ERROR: PE table missing in " .. MODULE .. "|r")
    return
end

if PE.LogLoad then
    PE.LogLoad(MODULE)
end

-- LibDBIcon may not exist in all environments
local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
if not Icon then
    if PE.Log then
        PE.Log(2, "[VFX] LibDBIcon-1.0 not found; minimap VFX disabled.")
    end
else
    ------------------------------------------------
    -- Make minimap button bigger and pushed outward
    ------------------------------------------------
    local function PersonaEngine_AdjustMinimapButton()
        local btn = Icon:GetMinimapButton("PersonaEngine")
        if not btn or not Minimap then
            return
        end

        -- Make the button itself bigger
        btn:SetScale(1.4)

        -- Get centers in screen coords
        local mx, my = Minimap:GetCenter()
        local bx, by = btn:GetCenter()
        if not (mx and my and bx and by) then
            return
        end

        local dx, dy = bx - mx, by - my
        if dx == 0 and dy == 0 then
            return
        end

        -- Direction from minimap center to button
        local angle = math.atan2(dy, dx)

        -- Radius of minimap and button in pixels
        local mr = Minimap:GetWidth() / 2
        local br = (btn:GetWidth() * btn:GetScale()) / 2

        -- Preserve "out from minimap" feel; tweak offset to taste
        local newDist = mr + br - 200

        local nx = math.cos(angle) * newDist
        local ny = math.sin(angle) * newDist

        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
    end

    -- Run once on load
    PersonaEngine_AdjustMinimapButton()

    -- Re-adjust when dragged
    do
        local btn = Icon:GetMinimapButton("PersonaEngine")
        if btn then
            btn:HookScript("OnDragStop", PersonaEngine_AdjustMinimapButton)
        end
    end

    local function PersonaEngine_SetupGlow()
        local btn = Icon:GetMinimapButton("PersonaEngine")
        if not btn then
            return
        end

        local tex = btn.icon
        if not tex then
            return
        end

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
                if not ag:IsPlaying() then
                    ag:Play()
                end
            else
                if ag:IsPlaying() then
                    ag:Stop()
                end
                tex:SetAlpha(1)
            end
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            PersonaEngine_AdjustMinimapButton()
            PersonaEngine_SetupGlow()
        end)
    else
        PersonaEngine_AdjustMinimapButton()
        PersonaEngine_SetupGlow()
    end
end

----------------------------------------------------
-- Icon Glow / Pulse Animation for PersonaEngineButton
----------------------------------------------------

local function PersonaEngine_SetupButtonVisuals()
    local btn = _G.PersonaEngineButton
    if not btn or not btn.icon then
        return
    end

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
