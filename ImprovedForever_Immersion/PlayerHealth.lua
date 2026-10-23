-- Your health and power as two bars along the screen's bottom edge, the
-- power (mana, rage, energy...) on the edge and the health over it, sharing
-- each a 1px line as the header's rule (the quest guide's, HeaderSlot.lua):
-- full from end to end, two halves out from the middle, each fading out
-- toward its end (lost draws them in from both ends to the middle).
-- * the health: the game's own fills (the reputation bar's green, turning
--   orange past half and red when low, red pulsing under URGENT), a pale
--   trail showing the health just lost, then easing in after it;
-- * the power: the unit frames' fill of its kind (UnitFrames.lua), easing
--   to a new value, in the game's colour of it.
-- The health's line is always on while you're alive; the power's peeks:
-- shown in a fight or while your power isn't at rest (mana, energy short
-- of full; rage, runic power above none), faded out when it's at rest
-- again (the lines never show while dead or a ghost). Either one off: the
-- other alone on the edge.
-- Your health and power are secret in a fight: they go to the bars as
-- their max and value as they are (the bars work the fill out, never
-- compared here), the health colours' strength from the game's percent
-- through curves, as the party cards' (PartyCards.lua).
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PlayerHealth = {}
IN.PlayerHealth = PlayerHealth

local LINE_H = IN.HP_H or 5
local POWER_H = IN.MP_H or 5
local FADE = 0.3
local HOLD = 0.8                 -- (whole again: shown this long before fading)
local TRAIL_DELAY = 0.4          -- (the trail waits this long, then eases in)
-- (the health's colours, plain: green, turning orange then red)
local GREEN = { 0.25, 0.9, 0.3 }
local ORANGE = { 1, 0.6, 0.1 }
local RED = { 0.95, 0.2, 0.15 }
local TRAIL = { 1, 0.93, 0.82, 0.55 }
local POWER_COLOR = { 0, 0, 1 }         -- (the power's, when the game has no colour for it: mana's)
-- (the powers at rest when empty: out of a fight, the rest at full)
local RESTS_EMPTY = { RAGE = true, RUNIC_POWER = true }
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

-- (both lines in one frame: it peeks, they're placed in it)
local holder = CreateFrame("Frame", "ImprovedForeverPlayerHealth", UIParent)
holder:SetFrameStrata("BACKGROUND")
holder:SetPoint("BOTTOMLEFT")
holder:SetPoint("BOTTOMRIGHT")
holder:SetHeight(LINE_H)
holder:SetAlpha(0)
holder:Hide()
PlayerHealth.holder = holder

-- A track: a bare frame the bars sit in
local function Track(height)
    local t = CreateFrame("Frame", nil, holder)
    t:SetHeight(height)
    return t
end

local line = Track(LINE_H)
local power = Track(POWER_H)

-- (the low pulse's own frame, over the fills: its glows' strength the
-- secret curve's, the frame's alpha the pulse, never the holder's: it
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

local function Bar(track, left, level)
    local bar = CreateFrame("StatusBar", nil, track)
    bar:SetPoint(left and "TOPLEFT" or "TOPRIGHT")
    bar:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", track, "BOTTOM")
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    bar:SetReverseFill(left)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return bar
end

local function Over(bar, sub, color)
    local t = bar:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetAllPoints(bar:GetStatusBarTexture())
    t:SetColorTexture(color[1], color[2], color[3], 1)
    t:SetAlpha(0)
    return t
end

-- (a line's fill faded out toward its end, as the header's rule: its
-- colour at RULE_ALPHA at the middle, to nothing at the end)
local RULE_ALPHA = 0.9
local function Fade(tex, left, color, alpha)
    if not (tex and tex.SetGradient and CreateColor) then return end
    local a = (alpha or 1) * RULE_ALPHA
    local clear, lit = CreateColor(color[1], color[2], color[3], 0), CreateColor(color[1], color[2], color[3], a)
    -- (the gradient must not undo the texture's own alpha: the colours' strength)
    local own = tex:GetAlpha()
    pcall(tex.SetGradient, tex, "HORIZONTAL", left and clear or lit, left and lit or clear)
    tex:SetAlpha(own)
end

-- (two halves each, full out from the middle; the health's each a trail
-- under its fill)
local halves, powerHalves = {}, {}
for i = 1, 2 do
    local left = i == 1
    local h = {}
    h.trail = Bar(line, left, 1)
    h.trail:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    Fade(h.trail:GetStatusBarTexture(), left, TRAIL, TRAIL[4])
    h.bar = Bar(line, left, 2)
    h.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local fill = h.bar:GetStatusBarTexture()
    h.orange, h.red = Over(h.bar, 1, ORANGE), Over(h.bar, 2, RED)
    Fade(fill, left, GREEN)
    -- (the pulse's red over it)
    local alarm = pulse:CreateTexture(nil, "OVERLAY")
    alarm:SetAllPoints(fill)
    alarm:SetColorTexture(1, 0.25, 0.2, 0.55)
    alarm:SetBlendMode("ADD")
    alarm:SetAlpha(0)
    h.alarm = alarm
    halves[i] = h

    local p = { left = left }
    p.bar = Bar(power, left, 2)
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    powerHalves[i] = p
end

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
    -- (health read whole, out of a fight: worked out here, never by the curve)
    local value, max = UnitHealth("player"), UnitHealthMax("player")
    if not (Secret(value) or Secret(max)) and type(value) == "number" and type(max) == "number" and max > 0 then
        local x, alpha = value / max, points[#points][2]
        for i = 2, #points do
            local p, q = points[i - 1], points[i]
            if x <= q[1] then
                alpha = p[2] + (q[2] - p[2]) * (x - p[1]) / math.max(q[1] - p[1], 0.0001)
                break
            end
        end
        t:SetAlpha(math.min(math.max(alpha, 0), 1))
        return
    end
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

-- (your power's kind, or nil (a secret))
local function PowerToken()
    local ok, _, token = pcall(UnitPowerType, "player")
    if not ok or Secret(token) then return nil end
    return token
end

-- (the power's halves: its kind's colour on the fill, its value as
-- it is, eased on a change of it; its kind a secret: the last one kept)
local function FillPower(ease)
    local token = PowerToken() or powerHalves[1].token or "MANA"
    local c = PowerBarColor and PowerBarColor[token]
    local color = type(c) == "table" and c.r and { c.r, c.g, c.b } or POWER_COLOR
    local value, max = UnitPower("player"), UnitPowerMax("player")
    for _, p in ipairs(powerHalves) do
        local bar = p.bar
        if p.token ~= token then
            p.token = token
            Fade(bar:GetStatusBarTexture(), p.left, color)
        end
        if not Try(bar.SetMinMaxValues, bar, 0, max) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
        elseif not (ease and SI and Try(bar.SetValue, bar, value, SI.ExponentialEaseOut))
            and not Try(bar.SetValue, bar, value) then
            bar:SetValue(0)
        end
    end
end

-- (wanted: in a fight or not at rest (read whole out of one))
local function PowerWanted()
    if IF.InCombat() then return true end
    local value, max = UnitPower("player"), UnitPowerMax("player")
    if Secret(value) or Secret(max) or type(value) ~= "number" or type(max) ~= "number" then return true end
    if max <= 0 then return false end
    local token = PowerToken()
    if not token then return true end
    if RESTS_EMPTY[token] then return value > 0 end
    return value < max
end

local function Wanted()
    if Flag(UnitIsDeadOrGhost, "player") then return false end
    -- (the health's line always on while alive; the power's peeks)
    return PlayerHealth.health or (PlayerHealth.power and PowerWanted()) or false
end

-- (the power's own fade: with the health's line always on, it peeks alone)
local function PowerGoal()
    return (not PlayerHealth.health or PowerWanted()) and 1 or 0
end

holder:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if trail.at and now >= trail.at then TrailTo(true) end
    local goal = (self.wanted or (self.holdUntil and now < self.holdUntil)) and 1 or 0
    local a = self:GetAlpha()
    if a ~= goal then
        a = goal > a and math.min(goal, a + elapsed / FADE) or math.max(goal, a - elapsed / FADE)
        self:SetAlpha(a)
    end
    local pa, pg = power:GetAlpha(), PowerGoal()
    if pa ~= pg then
        power:SetAlpha(pg > pa and math.min(pg, pa + elapsed / FADE) or math.max(pg, pa - elapsed / FADE))
    end
    if a <= 0 and goal == 0 then
        beat:Stop()
        self:Hide()
    end
end)

local function Update(ease, easePower)
    if not PlayerHealth.on then return end
    if PlayerHealth.health then Fill(ease) end
    if PlayerHealth.power then FillPower(easePower) end
    local was = holder.wanted
    holder.wanted = Wanted()
    if holder.wanted then
        holder.holdUntil = nil
        holder:Show()
        if PlayerHealth.health and not beat:IsPlaying() then beat:Play() end
    elseif Flag(UnitIsDeadOrGhost, "player") then
        holder.holdUntil = nil
    elseif was then
        -- (whole and at rest again: held a moment, the trail done, then faded)
        holder.holdUntil = GetTime() + HOLD
    end
end

local POWER_CHANGE = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true }
local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
-- (an event this client hasn't: left out, not an error)
for _, e in ipairs(UF.POWER_EVENTS) do pcall(events.RegisterUnitEvent, events, e, "player") end
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event)
    -- (only a change of health or power eases: a new max or kind, a load
    -- or coming back snap)
    Update(event == "UNIT_HEALTH", POWER_CHANGE[event] or false)
end)

---------------------------------------------------------------------------
-- On while a setting is: the power on the edge, the health over it
-- sharing its top border (alone: on the edge)
---------------------------------------------------------------------------
local function Place(health, mp)
    line:SetShown(health)
    power:SetShown(mp)
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, mp and POWER_H + 2 or 0)
    line:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, mp and POWER_H + 2 or 0)
    power:ClearAllPoints()
    power:SetPoint("BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT")
    local h = (health and LINE_H or 0) + (mp and POWER_H or 0) + (health and mp and 2 or 0)
    holder:SetHeight(math.max(h, 1))
    if not health then beat:Stop() end
end

local function Watch()
    if not IF.db then return end
    local s = IN.Settings()
    local edit = UF.EditMode()
    local health, mp = s.hpLine and not edit or false, s.mpLine and not edit or false
    if health == PlayerHealth.health and mp == PlayerHealth.power then return end
    PlayerHealth.health, PlayerHealth.power = health, mp
    PlayerHealth.on = health or mp
    Place(health, mp)
    if PlayerHealth.on then
        Update(false, false)
    else
        holder.wanted, holder.holdUntil, trail.at = false, nil, nil
        beat:Stop()
        holder:SetAlpha(0)
        holder:Hide()
    end
end

IN.Watcher("health line", 0.25, Watch)

function PlayerHealth.Apply()
    Watch()
end
