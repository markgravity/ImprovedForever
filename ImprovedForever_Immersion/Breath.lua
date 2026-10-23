-- Your breath under water as water in the player frame: the avatar and its
-- background covered in blue (darker deeper down, a slow shimmer over it),
-- bubbles rising through it, a rippling surface. The breath left is the
-- ring round the card, in place of the experience's (XPBar.lua, XP.Air).
-- The game's breath bar is drawn at 0 while it shows (IF.Focus.Fade). The
-- other mirror timers (fatigue, feigned death) stay the game's.
-- A secret timer (in a fight) can't be worked with: the ring then stays full.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local Breath = {}
IN.Breath = Breath

local INSET = 4                 -- (the avatar's own, UnitFrames.lua)
local WATER = { 0.12, 0.42, 1, 0.5 }
local SURFACE = { 0.55, 0.8, 1, 0.9 }

local a = UF.player.avatar
local water = CreateFrame("StatusBar", nil, a)
water:SetPoint("TOPLEFT", INSET, -INSET)
water:SetPoint("BOTTOMRIGHT", -INSET, INSET)
water:SetFrameLevel(a.model:GetFrameLevel() + 1)
water:SetOrientation("VERTICAL")
water:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
water:SetMinMaxValues(0, 1)
water:SetValue(1)
water:Hide()

-- (darker deeper down: the fill's own gradient)
do
    local tex = water:GetStatusBarTexture()
    local ok = pcall(function()
        tex:SetGradient("VERTICAL", CreateColor(0.02, 0.15, 0.6, 0.65), CreateColor(0.25, 0.6, 1, 0.4))
    end)
    if not ok then water:SetStatusBarColor(WATER[1], WATER[2], WATER[3], WATER[4]) end
end

-- (a frame on the water's fill: bubbles and ripples live in it, cut off at
-- the surface as it drops; anchored to the fill, so a secret level is fine)
local body = CreateFrame("Frame", nil, water)
body:SetPoint("TOPLEFT", water:GetStatusBarTexture(), "TOPLEFT")
body:SetPoint("BOTTOMRIGHT", water:GetStatusBarTexture(), "BOTTOMRIGHT")
body:SetClipsChildren(true)

-- (the surface: a bright line along the water's top, rippling in short
-- steps that rise and fall in turn)
local STEPS = 16
local ripples = {}
for i = 1, STEPS do
    local t = body:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
    t:SetHeight(2)
    ripples[i] = t
end

-- (bubbles: small circles rising from the bottom, swaying, fading near the top)
local BUBBLES = 9
local bubbles = {}
for i = 1, BUBBLES do
    local t = body:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    t:SetVertexColor(0.8, 0.93, 1, 1)
    local size = 3 + (i * 7) % 5
    t:SetSize(size, size)
    bubbles[i] = { tex = t, x = (i * 37) % 100 / 100, y = (i * 53) % 100 / 100, speed = 12 + (i * 11) % 16,
        phase = i * 1.7 }
end

-- (the water rising as you go under and draining as you surface: its
-- level eased to 1 / 0; shown while above 0)
-- (the level it eases to: 1 head under, a random 48 to 62% at the surface, always above the name band (about the card's bottom 40%)
-- (a new one each time you reach it), 0 out of the water)
local rise, level = 0, 0
local SURFACE_LO, SURFACE_HI = 0.48, 0.62
local surfaceLevel, atSurface
local EASE = 4

local function Animate(now, dt)
    local want = level
    if math.abs(want - rise) < 0.005 then
        rise = want
    else
        rise = rise + (want - rise) * math.min(1, dt * EASE)
    end
    if rise <= 0 then
        water:Hide()
        return
    end
    water:Show()
    water:SetValue(rise)
    local w, h = a:GetWidth() - 2 * INSET, a:GetHeight() - 2 * INSET
    local step = w / STEPS
    for i, t in ipairs(ripples) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", body, "TOPLEFT", (i - 1) * step, math.sin(now * 2.2 + i * 0.7) * 1.5)
        t:SetWidth(step + 0.5)
        t:SetAlpha(0.6 + 0.4 * math.sin(now * 1.3 + i))
    end
    for _, b in ipairs(bubbles) do
        b.y = b.y + b.speed * dt / h
        if b.y > 1 then b.y, b.x = 0, (b.x + 0.37) % 1 end
        local sway = math.sin(now * 2 + b.phase) * 3
        b.tex:ClearAllPoints()
        b.tex:SetPoint("CENTER", body, "BOTTOMLEFT", b.x * w + sway, b.y * h)
        b.tex:SetAlpha(0.55 * (1 - b.y * 0.5))
    end
    -- (a slow shimmer: the water's depth of colour swelling and fading)
    water:SetAlpha(0.85 + 0.15 * math.sin(now * 1.1))
end

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- The game's mirror timers' frames, faded while the breath is the only one
local function Natives()
    local list = { _G.MirrorTimerContainer }
    for i = 1, 3 do list[#list + 1] = _G["MirrorTimer" .. i] end
    return list
end

-- The breath timer's value and max, and how many timers run: nil when no
-- breath
local function Read()
    if not GetMirrorTimerInfo then return nil end
    local breath, count
    count = 0
    for i = 1, 3 do
        local ok, timer, value, max, scale = pcall(GetMirrorTimerInfo, i)
        if ok and timer and timer ~= "" and (Secret(timer) or timer ~= "UNKNOWN") then
            count = count + 1
            if not Secret(timer) and timer == "BREATH" then
                -- (the info's value is the start's: the progress is the live one)
                local live = GetMirrorTimerProgress and select(2, pcall(GetMirrorTimerProgress, timer))
                breath = { live ~= nil and live or value, max, scale }
            end
        end
    end
    if not breath then return nil, count end
    return breath, count
end

-- The model swimming while you do: the game's swim animations (41 idle,
-- 42 swimming), the stand (0) after. A model loading resets it, so it's
-- set again then.
local SWIM_IDLE, SWIM, STAND = 41, 42, 0
local pose

local function Moving()
    if not GetUnitSpeed then return false end
    local ok, speed = pcall(GetUnitSpeed, "player")
    if not ok or Secret(speed) or type(speed) ~= "number" then return false end
    return speed > 0
end

local function Pose(want, force)
    if not force and want == pose then return end
    pose = want
    if a.model:IsShown() and a.model.SetAnimation then pcall(a.model.SetAnimation, a.model, want, 0) end
end

local function Swimming(on)
    local swim = on and IsSwimming and IsSwimming() or false
    Pose(swim and (Moving() and SWIM or SWIM_IDLE) or STAND)
end

a.model:HookScript("OnModelLoaded", function()
    if pose and pose ~= STAND and a.model.SetAnimation then pcall(a.model.SetAnimation, a.model, pose, 0) end
end)

local function Update()
    local on = IN.Settings().breath and not UF.EditMode()
    Swimming(on)
    local breath, count
    if on then breath, count = Read() end
    -- (the water's level: head under, at the surface, out)
    local swimming = on and ((IsSwimming and IsSwimming()) or (IsSubmerged and IsSubmerged())) or false
    -- (IsSubmerged is true at the surface too: the head under is the breath
    -- timer draining (its scale below 0; refilling at the surface)
    local submerged = false
    if breath and not Secret(breath[3]) and type(breath[3]) == "number" then submerged = breath[3] < 0 end
    if submerged then
        level, atSurface = 1, false
    elseif swimming then
        if not atSurface then
            atSurface = true
            surfaceLevel = SURFACE_LO + math.random() * (SURFACE_HI - SURFACE_LO)
        end
        level = surfaceLevel
    else
        level, atSurface = 0, false
    end
    if not breath then
        if IN.XPBar then IN.XPBar.Air(nil) end
        for _, f in ipairs(Natives()) do IF.Focus.Fade(f, false) end
        return
    end
    local XP = IN.XPBar
    if XP then
        local ok, share = pcall(function()
            local v, m = breath[1], breath[2]
            if Secret(v) or Secret(m) or type(v) ~= "number" or type(m) ~= "number" or m <= 0 then return 1 end
            return math.min(1, math.max(0, v / m))
        end)
        XP.Air(ok and share or 1)
    end
    -- (the game's bar only while it's the one to show)
    for _, f in ipairs(Natives()) do IF.Focus.Fade(f, count == 1) end
end

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", function(self, elapsed)
    if not IF.db then return end
    since = since + elapsed
    if since < 0.03 then return end
    local dt = since
    since = 0
    local ok, err = pcall(function()
        Update()
        if level > 0 or rise > 0 then Animate(GetTime(), dt) end
    end)
    if not ok then
        self:SetScript("OnUpdate", nil)
        IF.Print("Immersion: breath stopped after an error: " .. tostring(err))
    end
end)

Breath.Apply = Update
