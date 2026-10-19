-- Your health as a bar along the screen's bottom edge, over the experience
-- line (XPBar.lua) and drawn as it is: a dark track in a thin grey frame,
-- cut in 10 by notches, the game's own fills (the reputation bar's green,
-- turning orange past half and red when low, red pulsing under URGENT), a
-- glow at the fill's ends, a pale trail showing the health just lost, then
-- easing in after it. Full from end to end, two halves out from the middle:
-- health lost draws them in from both ends to the middle. Its bottom border is the experience line's top one;
-- on the screen's edge when that line isn't shown.
-- It peeks: shown in a fight and while you're hurt, faded out a moment
-- after you're whole again out of a fight (never while dead or a ghost).
-- Your health is secret in a fight: it goes to the bar as its max and value
-- as it is (the bars work the fill out, never compared here), the colours'
-- strength from the game's percent through curves, as the party cards'
-- (PartyCards.lua).
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PlayerHealth = {}
IN.PlayerHealth = PlayerHealth

local LINE_H = 5
local COMPARTMENTS = 10
local FRAME = { 0.25, 0.25, 0.25 }      -- (its frame's and notches' grey, the experience line's)
local FADE = 0.3
local HOLD = 0.8                 -- (whole again: shown this long before fading)
local TRAIL_DELAY = 0.4          -- (the trail waits this long, then eases in)
local FILL = "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green-Camelot"
local ORANGE = "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Orange-Camelot"
local RED = "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Red-Camelot"
local TRAIL = { 1, 0.93, 0.82, 0.55 }
local GLOW = { 0.6, 1, 0.6 }
-- (the colours over the green, by health left: orange from three quarters
-- to full at half, red from 40% to full at a quarter, the pulse under
-- URGENT)
local URGENT = 0.35
local ORANGE_POINTS = { { 0, 1 }, { 0.5, 1 }, { 0.75, 0 }, { 1, 0 } }
local RED_POINTS = { { 0, 1 }, { 0.25, 1 }, { 0.4, 0 }, { 1, 0 } }
local URGENT_POINTS = { { 0, 1 }, { URGENT, 1 }, { URGENT + 0.001, 0 }, { 1, 0 } }

local Try, Flag = UF.Try, UF.Flag
local SI = Enum.StatusBarInterpolation
local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local line = CreateFrame("Frame", "ImprovedForeverPlayerHealth", UIParent)
line:SetFrameStrata("BACKGROUND")
line:SetHeight(LINE_H)
line:SetAlpha(0)
line:Hide()

local bg = line:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.7)

-- (the low pulse's own frame, over the fills: its glows' strength the
-- secret curve's, the frame's alpha the pulse, never the line's: the line
-- fades by its own)
local pulse = CreateFrame("Frame", nil, line)
pulse:SetAllPoints()
pulse:SetFrameLevel(line:GetFrameLevel() + 3)
local beat = pulse:CreateAnimationGroup()
beat:SetLooping("BOUNCE")
local fade = beat:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.1)
fade:SetDuration(0.5)
fade:SetSmoothing("IN_OUT")

-- (over the fills: the glows at the fill's ends, the notches, the frame)
local over = CreateFrame("Frame", nil, line)
over:SetAllPoints()
over:SetFrameLevel(line:GetFrameLevel() + 4)

local function Bar(left, level)
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetPoint(left and "TOPLEFT" or "TOPRIGHT")
    bar:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", line, "BOTTOM")
    bar:SetFrameLevel(line:GetFrameLevel() + level)
    bar:SetReverseFill(left)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return bar
end

local function Over(bar, atlas, sub)
    local t = bar:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetAllPoints(bar:GetStatusBarTexture())
    t:SetAtlas(atlas)
    t:SetAlpha(0)
    return t
end

-- (two halves, full out from the middle; each a trail under its fill)
local halves = {}
for i = 1, 2 do
    local left = i == 1
    local h = {}
    h.trail = Bar(left, 1)
    h.trail:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    h.trail:SetStatusBarColor(TRAIL[1], TRAIL[2], TRAIL[3], TRAIL[4])
    h.bar = Bar(left, 2)
    h.bar:SetStatusBarTexture(FILL)
    local fill = h.bar:GetStatusBarTexture()
    h.orange, h.red = Over(h.bar, ORANGE, 1), Over(h.bar, RED, 2)
    -- (the glow at its outer end)
    local glow = over:CreateTexture(nil, "ARTWORK")
    glow:SetSize(48, LINE_H - 2)
    glow:SetPoint(left and "LEFT" or "RIGHT", fill, left and "LEFT" or "RIGHT")
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetBlendMode("ADD")
    if glow.SetGradient and CreateColor then
        local clear, lit = CreateColor(GLOW[1], GLOW[2], GLOW[3], 0), CreateColor(GLOW[1], GLOW[2], GLOW[3], 0.45)
        glow:SetGradient("HORIZONTAL", left and lit or clear, left and clear or lit)
    end
    -- (the pulse's red over it)
    local alarm = pulse:CreateTexture(nil, "OVERLAY")
    alarm:SetAllPoints(fill)
    alarm:SetColorTexture(1, 0.25, 0.2, 0.55)
    alarm:SetBlendMode("ADD")
    alarm:SetAlpha(0)
    h.alarm = alarm
    halves[i] = h
end

for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
    local t = over:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
    t:SetPoint(e[1])
    t:SetPoint(e[2])
    if e[3] then t:SetWidth(e[3]) end
    if e[4] then t:SetHeight(e[4]) end
end

-- (the notches: two screen pixels wide, re-placed as the width changes)
local notches = {}
local function Notches()
    local width = line:GetWidth()
    if not width or width <= 0 then return end
    local pixel = 768 / (select(2, GetPhysicalScreenSize()) or 768) / line:GetEffectiveScale()
    for i = 1, COMPARTMENTS - 1 do
        local t = notches[i]
        if not t then
            t = over:CreateTexture(nil, "OVERLAY", nil, 1)
            t:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
            notches[i] = t
        end
        t:SetSize(2 * pixel, LINE_H - 2)
        t:ClearAllPoints()
        t:SetPoint("CENTER", line, "LEFT", i * width / COMPARTMENTS, 0)
    end
end
line:SetScript("OnSizeChanged", Notches)
line:HookScript("OnShow", Notches)

-- (over the experience line, sharing its top border; else on the edge)
local function Place()
    local xp = ImprovedForeverXPLine
    local on = xp and xp:IsShown() and xp or nil
    if line.on == on and line.placed then return end
    line.on, line.placed = on, true
    line:ClearAllPoints()
    if on then
        line:SetPoint("BOTTOMLEFT", on, "TOPLEFT", 0, -1)
        line:SetPoint("BOTTOMRIGHT", on, "TOPRIGHT", 0, -1)
    else
        line:SetPoint("BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT")
    end
end
Place()

local curves = {}
local function Curve(points)
    if curves[points] ~= nil then return curves[points] or nil end
    curves[points] = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, c = pcall(function()
            local made = C_CurveUtil.CreateCurve()
            made:SetType(Enum.LuaCurveType.Linear)
            for _, p in ipairs(points) do made:AddPoint(p[1], p[2]) end
            return made
        end)
        if ok then curves[points] = c end
    end
    return curves[points] or nil
end

-- (a texture's alpha from a curve of your health percent, secret or not)
local function Shade(t, points)
    local c = Curve(points)
    if not (c and pcall(function() t:SetAlpha(UnitHealthPercent("player", true, c)) end)) then
        t:SetAlpha(0)
    end
end

-- (the health the trail eases to, and when)
local trail = {}

local function TrailTo(ease)
    trail.at = nil
    for _, h in ipairs(halves) do
        local t = h.trail
        if not (ease and SI and Try(t.SetValue, t, trail.value, SI.ExponentialEaseOut))
            and not Try(t.SetValue, t, trail.value) then
            t:SetValue(1)
        end
    end
end

-- (the halves filled from your health as it is, the colours' strength; eased:
-- the trail follows after TRAIL_DELAY, else everything snaps)
local function Fill(ease)
    local value, max = UnitHealth("player"), UnitHealthMax("player")
    trail.value = value
    for _, h in ipairs(halves) do
        local bar = h.bar
        if not (Try(bar.SetMinMaxValues, bar, 0, max) and Try(bar.SetValue, bar, value)) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            trail.value = 1
        end
        if not ease and not Try(h.trail.SetMinMaxValues, h.trail, 0, max) then
            h.trail:SetMinMaxValues(0, 1)
        end
        Shade(h.orange, ORANGE_POINTS)
        Shade(h.red, RED_POINTS)
        Shade(h.alarm, URGENT_POINTS)
    end
    if ease then
        trail.at = GetTime() + TRAIL_DELAY
    else
        TrailTo(false)
    end
end

-- (wanted: alive, and in a fight or hurt (read whole out of one))
local function Wanted()
    if Flag(UnitIsDeadOrGhost, "player") then return false end
    if IF.InCombat() then return true end
    local value, max = UnitHealth("player"), UnitHealthMax("player")
    if Secret(value) or Secret(max) or type(value) ~= "number" or type(max) ~= "number" then return true end
    return max > 0 and value < max
end

line:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if trail.at and now >= trail.at then TrailTo(true) end
    local goal = (self.wanted or (self.holdUntil and now < self.holdUntil)) and 1 or 0
    local a = self:GetAlpha()
    if a ~= goal then
        a = goal > a and math.min(goal, a + elapsed / FADE) or math.max(goal, a - elapsed / FADE)
        self:SetAlpha(a)
    end
    if a <= 0 and goal == 0 then
        beat:Stop()
        self:Hide()
    end
end)

local function Update(ease)
    if not PlayerHealth.on then return end
    Fill(ease)
    local was = line.wanted
    line.wanted = Wanted()
    if line.wanted then
        line.holdUntil = nil
        line:Show()
        if not beat:IsPlaying() then beat:Play() end
    elseif Flag(UnitIsDeadOrGhost, "player") then
        line.holdUntil = nil
    elseif was then
        -- (whole again: held a moment, the trail done, then faded)
        line.holdUntil = GetTime() + HOLD
    end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event)
    -- (only a change of health eases: a new max, a load or coming back snap)
    Update(event == "UNIT_HEALTH")
end)

---------------------------------------------------------------------------
-- On while the setting is
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    Place()
    local on = IN.Settings().hpLine and not UF.EditMode()
    if on ~= PlayerHealth.on then
        PlayerHealth.on = on
        if on then
            Update(false)
        else
            line.wanted, line.holdUntil, trail.at = false, nil, nil
            beat:Stop()
            line:SetAlpha(0)
            line:Hide()
        end
    end
end

IN.Watcher("health line", 0.25, Watch)

function PlayerHealth.Apply()
    Watch()
end
