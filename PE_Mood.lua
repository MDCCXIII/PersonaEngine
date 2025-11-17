-- ##################################################
-- PE_Mood.lua
-- Mood engine: 2D mood vector, buckets, bias, persistence, decay
-- ##################################################

local MODULE = "Mood"
local PE = PE

if not PE then
    print("|cffff0000[PersonaEngine] PE_Mood.lua loaded without PE core!|r")
    return
end

if PE.LogLoad then PE.LogLoad(MODULE) end

PE.Mood = PE.Mood or {}
local Mood = PE.Mood

local Runtime  = PE.Runtime or {}
PE.Runtime     = Runtime

----------------------------------------------------
-- SavedVariables schema
----------------------------------------------------
-- Stored under:
-- PersonaEngineDB.moodByProfile[profileKey] = {
--   x = number, y = number, lastLogout = timestamp
-- }

local function EnsureDBRoot()
    PersonaEngineDB = PersonaEngineDB or {}
    PersonaEngineDB.moodByProfile = PersonaEngineDB.moodByProfile or {}
end

----------------------------------------------------
-- Mood buckets (2D -> label)
-- x axis: angry(-) <-> happy(+)
-- y axis: anxious(-) <-> calm(+)
-- We'll name the combos based on quadrant.
----------------------------------------------------

Mood.BUCKETS = {
    -- x < -0.33 (angry-ish)
    { id = "angry_anxious",    xMin = -1.0, xMax = -0.33, yMin = -1.0, yMax = -0.33 },
    { id = "angry_bored",      xMin = -1.0, xMax = -0.33, yMin = -0.33, yMax = 0.33 },
    { id = "angry_calm",       xMin = -1.0, xMax = -0.33, yMin = 0.33, yMax = 1.0 },

    -- x mid (-0.33..0.33)
    { id = "irritable_anxious",  xMin = -0.33, xMax = 0.33, yMin = -1.0, yMax = -0.33 },
    { id = "indifferent_neutral",xMin = -0.33, xMax = 0.33, yMin = -0.33, yMax = 0.33 },
    { id = "grateful_calm",      xMin = -0.33, xMax = 0.33, yMin = 0.33, yMax = 1.0 },

    -- x > 0.33 (happy-ish)
    { id = "happy_anxious",    xMin = 0.33, xMax = 1.0, yMin = -1.0, yMax = -0.33 },
    { id = "happy_calm",       xMin = 0.33, xMax = 1.0, yMin = -0.33, yMax = 0.33 },
    { id = "elated_excited",   xMin = 0.33, xMax = 1.0, yMin = 0.33, yMax = 1.0 },
}

-- Canonical representative vectors for each bucket (for bias, etc.)
Mood.VECTORS = {
    angry_anxious       = { x = -0.8, y = -0.8 },
    angry_bored         = { x = -0.8, y = -0.2 },
    angry_calm          = { x = -0.8, y =  0.6 },

    irritable_anxious   = { x = -0.2, y = -0.8 },
    indifferent_neutral = { x =  0.0, y =  0.0 },
    grateful_calm       = { x =  0.2, y =  0.6 },

    happy_anxious       = { x =  0.6, y = -0.6 },
    happy_calm          = { x =  0.6, y =  0.2 },
    elated_excited      = { x =  0.8, y =  0.8 },
}

local DEFAULT_BUCKET = "indifferent_neutral"

----------------------------------------------------
-- Helpers
----------------------------------------------------

local function Clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

local function GetProfileKey()
    if PE.Profiles and PE.Profiles.GetActiveProfileKey then
        return PE.Profiles.GetActiveProfileKey()
    end
    return "DEFAULT"
end

local function GetProfilePersonality()
    if not PE.Profiles or not PE.Profiles.GetActiveProfile then
        return nil
    end
    local profile = PE.Profiles.GetActiveProfile()
    if not profile then return nil end
    profile.personality = profile.personality or {}
    return profile.personality
end

----------------------------------------------------
-- Mood bias (preferred attitude)
----------------------------------------------------
-- profile.personality.moodBias = {
--   moodKey = "grateful_calm",
--   strength = 0.0..1.0
-- }

local function GetBiasVector()
    local pers = GetProfilePersonality()
    local bias = pers and pers.moodBias
    if not bias or not bias.moodKey then
        return Mood.VECTORS[DEFAULT_BUCKET], 0.0
    end
    local vec = Mood.VECTORS[bias.moodKey] or Mood.VECTORS[DEFAULT_BUCKET]
    local strength = Clamp(bias.strength or 0.0, 0.0, 1.0)
    return vec, strength
end

----------------------------------------------------
-- Runtime vector
----------------------------------------------------

Runtime.mood = Runtime.mood or { x = 0.0, y = 0.0 }

function Mood.GetVector()
    return Runtime.mood
end

----------------------------------------------------
-- Bucket classification
----------------------------------------------------

function Mood.GetBucketKey()
    local m = Runtime.mood or { x = 0, y = 0 }
    for _, b in ipairs(Mood.BUCKETS) do
        if m.x >= b.xMin and m.x <= b.xMax and m.y >= b.yMin and m.y <= b.yMax then
            return b.id
        end
    end
    return DEFAULT_BUCKET
end

----------------------------------------------------
-- State deltas (to be tuned later / extended)
-- stateId strings are up to you; these are examples.
----------------------------------------------------

Mood.StateDeltas = {
    IN_COMBAT    = { x =  0.25, y =  0.15 },
    OUT_OF_COMBAT= { x = -0.10, y = -0.05 },
    LOW_HEALTH   = { x =  0.30, y = -0.30 },
    RESTING      = { x = -0.15, y =  0.20 },
    MOUNTING     = { x =  0.10, y =  0.10 },
}

----------------------------------------------------
-- Apply state delta with bias gravity
----------------------------------------------------

local function ApplyDeltaWithBias(dx, dy)
    local m = Runtime.mood
    local bx, by, bStrength

    do
        local biasVec, strength = GetBiasVector()
        bx, by, bStrength = biasVec.x, biasVec.y, strength
    end

    -- Vector from current mood to bias
    local vx, vy = bx - m.x, by - m.y
    -- Dot product to see if delta moves toward or away from bias
    local dot = vx * dx + vy * dy

    local scale = 1.0
    if dot < 0 then
        -- Moving away from preferred mood → resist
        scale = 1.0 - bStrength
    elseif dot > 0 then
        -- Moving toward preferred mood → slightly assist
        scale = 1.0 + (bStrength * 0.3)
    end

    m.x = Clamp(m.x + dx * scale, -1.0, 1.0)
    m.y = Clamp(m.y + dy * scale, -1.0, 1.0)
end

function Mood.ApplyStateDelta(stateId)
    if not stateId then return end
    local d = Mood.StateDeltas[stateId]
    if not d then return end
    ApplyDeltaWithBias(d.x or 0, d.y or 0)
end

----------------------------------------------------
-- Persistence + decay between sessions
----------------------------------------------------

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function ApplyDecay(mood, dtSeconds)
    local hours = (dtSeconds or 0) / 3600
    if hours <= 0 then return end

    local biasVec, strength = GetBiasVector()
    local targetX, targetY = biasVec.x, biasVec.y

    -- How strongly we snap back toward bias with time away.
    -- 0–8h: gradual, 8h+ : fully at bias.
    local t = Clamp(hours / 8.0, 0.0, 1.0)

    mood.x = Lerp(mood.x, targetX, t)
    mood.y = Lerp(mood.y, targetY, t)
end

local function LoadForActiveProfile()
    EnsureDBRoot()
    local key = GetProfileKey()
    local store = PersonaEngineDB.moodByProfile[key]

    if not store then
        -- Start at bias vector
        local biasVec = (select(1, GetBiasVector()))
        store = {
            x = biasVec.x,
            y = biasVec.y,
            lastLogout = time(),
        }
        PersonaEngineDB.moodByProfile[key] = store
    end

    local now = time()
    local dt  = now - (store.lastLogout or now)

    Runtime.mood.x = Clamp(store.x or 0.0, -1.0, 1.0)
    Runtime.mood.y = Clamp(store.y or 0.0, -1.0, 1.0)

    ApplyDecay(Runtime.mood, dt)
end

local function SaveForActiveProfile()
    EnsureDBRoot()
    local key = GetProfileKey()
    local m = Runtime.mood or { x = 0, y = 0 }

    PersonaEngineDB.moodByProfile[key] = {
        x = Clamp(m.x, -1.0, 1.0),
        y = Clamp(m.y, -1.0, 1.0),
        lastLogout = time(),
    }
end

----------------------------------------------------
-- Public helpers
----------------------------------------------------

function Mood.DebugPrint()
    if not PE.Log then return end
    local m = Runtime.mood
    PE.Log(3, "[Mood] vec:", string.format("(%.2f, %.2f)", m.x, m.y),
                 "bucket:", Mood.GetBucketKey())
end

----------------------------------------------------
-- Event wiring: load/save
----------------------------------------------------

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGOUT")

    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "PersonaEngine" then
            local ok, err = pcall(LoadForActiveProfile)
            if not ok and PE.Log then
                PE.Log(1, "[Mood] Load failed:", err)
            end
        elseif event == "PLAYER_LOGOUT" then
            local ok, err = pcall(SaveForActiveProfile)
            if not ok and PE.Log then
                PE.Log(1, "[Mood] Save failed:", err)
            end
        end
    end)
end

----------------------------------------------------
-- Module registration
----------------------------------------------------

if PE.LogInit then PE.LogInit(MODULE) end
if PE.RegisterModule then
    PE.RegisterModule(MODULE, {
        name  = "Mood Engine",
        class = "engine",
    })
end
