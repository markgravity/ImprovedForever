-- Your health and power as two bars along the screen's bottom edge, the
-- power (mana, rage, energy...) on the edge and the health over it, sharing
-- each a line as the header's rule (the quest guide's, HeaderSlot.lua):
-- full from end to end, two halves out from the middle, each darkening
-- toward its end (lost draws them in from both ends to the middle).
-- * the health: the game's own fills (the reputation bar's green, turning
--   orange past half and red when low, red pulsing under URGENT), the
--   heals coming to you a striped band past its end;
-- * the power: in the game's colour of its kind (mana a lighter blue),
--   pulsing when mana is low; while you cast, the power the spell will take
--   a striped band at its end, the stripes drifting in.
-- The predictions' stripes are tools/make_bar_textures.py's.
-- Both ease to a new value, what's just lost staying as a pale trail, then
-- easing in after it. Where a fill stops reads at a glance: a bright cap
-- marks its edge, over a dark backing with a dim tint of its colour (how
-- far full goes) and notches at each quarter.
-- The health's line is always on while you're alive; the power's peeks:
-- shown in a fight or while your power isn't at rest (mana, energy short
-- of full; rage, runic power above none), faded out when it's at rest
-- again (the lines never show while dead or a ghost). Either one off: the
-- other alone on the edge.
-- Your health and power are secret in a fight: they go to the bars as
-- their max and value as they are (the bars work the fill out, never
-- compared here), the colours' strength from the game's percent through
-- curves, as the party cards' (PartyCards.lua). The heals coming and a
-- spell's cost go the same way, to bars of their own laid from the fill's
-- edge (DoesItDie's way: the game places them, so a secret moves them too).
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PlayerHealth = {}
IN.PlayerHealth = PlayerHealth

local LINE_H = IN.HP_H or 5
local POWER_H = IN.MP_H or 5
local GAP = -1                   -- (the two lines share one border row)
local FADE = 0.3
local HOLD = 0.8                 -- (whole again: shown this long before fading)
local TRAIL_DELAY = 0.4          -- (the trail waits this long, then eases in)
local WHITE = "Interface\\Buttons\\WHITE8x8"
local STRIPES = IF.TEX .. "ic_bar_stripes"
local STRIPE_TILE = 16           -- (the stripes' tile, px: a drift of it loops seamlessly)
local RIBBON_TIME = 1.2          -- (the cost's stripes: one tile's drift, seconds)
-- (the health's colours, plain: green, turning orange then red)
local GREEN = { 0.25, 0.9, 0.3 }
local ORANGE = { 1, 0.6, 0.1 }
local RED = { 0.95, 0.2, 0.15 }
local TRAIL = { 1, 0.93, 0.82, 0.55 }
-- (the predictions, striped bands, square: their base, their stripes)
local HEAL = { 0.45, 0.95, 0.5, 0.35 }
local HEAL_STRIPE = { 0.8, 1, 0.82, 0.85 }
local COST = { 0, 0, 0, 0.45 }          -- (a spell's cost: the fill darkened under its stripes)
local POWER_COLOR = { 0.3, 0.6, 1 }     -- (the power's, when the game has no colour for it: mana's)
-- (the game's mana blue (0, 0, 1) is near black on a thin line: a lighter one)
local OWN_COLORS = { MANA = POWER_COLOR }
-- (a fill's colour at its leading edge, against its middle: darker, never
-- see-through, so the trail under it stays hidden)
local EDGE = 0.55
local CAP_W = 2
-- (the empty part: a dark backing for contrast, a dim tint of the line's
-- colour showing how far full goes, notches at a quarter, half and three
-- quarters of each half)
local BACKING = 0.7
-- (the fishing skill line's look: a thin grey frame, 20 compartments, the
-- fill graded top to bottom, a soft glow at its end)
local COMPARTMENTS = 20
local FRAME = { 0.25, 0.25, 0.25 }
local GLOW_W = 48
-- (low mana: a pulse over the power's fill from LOW_MANA down)
local LOW_MANA = 0.25
local LOW_POINTS = { { 0, 1 }, { LOW_MANA, 1 }, { LOW_MANA + 0.001, 0 }, { 1, 0 } }
-- (the powers at rest when empty: out of a fight, the rest at full)
local RESTS_EMPTY = { RAGE = true, RUNIC_POWER = true }
-- (the colours over the green, by health left: orange from three quarters
-- to full at half, red from 40% to full at a quarter, the pulse under
-- URGENT)
local URGENT = 0.35
local ORANGE_POINTS = { { 0, 1 }, { 0.5, 1 }, { 0.75, 0 }, { 1, 0 } }
local RED_POINTS = { { 0, 1 }, { 0.25, 1 }, { 0.4, 0 }, { 1, 0 } }
local URGENT_POINTS = { { 0, 1 }, { URGENT, 1 }, { URGENT + 0.001, 0 }, { 1, 0 } }
-- (a track's layers: the trail under the fill, the heals past it, the
-- fill, the pulses and the cost over it, the notches)
local L_UNDER, L_HEAL, L_FILL, L_OVER, L_MARKS = 1, 2, 3, 4, 5
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

---------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------
-- (a layer frame of a track, over its own)
local function Layer(track, level, parent)
    local f = CreateFrame("Frame", nil, parent or track)
    f:SetAllPoints(track)
    f:SetFrameLevel(track:GetFrameLevel() + level)
    return f
end

-- A track: the frame the bars sit in, a dark backing under them for
-- contrast and a frame over them for the notches; what's sized by its
-- width (a half's) re-sized with it
local function Track(height)
    local t = CreateFrame("Frame", nil, holder)
    t:SetHeight(height)
    local back = t:CreateTexture(nil, "BACKGROUND", nil, 0)
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, BACKING)
    t.marks = Layer(t, L_MARKS)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local f = t.marks:CreateTexture(nil, "OVERLAY")
        f:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
        f:SetPoint(e[1])
        f:SetPoint(e[2])
        if e[3] then f:SetWidth(e[3]) end
        if e[4] then f:SetHeight(e[4]) end
    end
    t.notches = {}
    for i = 1, COMPARTMENTS - 1 do
        local n = t.marks:CreateTexture(nil, "OVERLAY", nil, 1)
        n:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
        n.at = i / COMPARTMENTS
        t.notches[i] = n
    end
    t.sized = {}
    t:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth() or 0
        if width <= 0 then return end
        local pixel = 768 / (select(2, GetPhysicalScreenSize()) or 768) / self:GetEffectiveScale()
        for _, n in ipairs(self.notches) do
            n:SetSize(2 * pixel, height - 2)
            n:ClearAllPoints()
            n:SetPoint("CENTER", self, "LEFT", n.at * width, 0)
        end
        for _, fn in ipairs(self.sized) do fn(width - 2) end
    end)
    return t
end

local line = Track(LINE_H)
local power = Track(POWER_H)

-- (a region tinted)
local function Tinted(region, color, alpha)
    region:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- (a fill's colour darkening toward its end, as the header's rule fades:
-- its colour at the middle, EDGE of it at the end, never see-through)
local function Grade(tex, _, color)
    if not (tex and tex.SetGradient and CreateColor) then return end
    local low = CreateColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65, 1)
    local high = CreateColor(math.min(1, color[1] * 1.15 + 0.04), math.min(1, color[2] * 1.15 + 0.04),
        math.min(1, color[3] * 1.15 + 0.04), 1)
    -- (the gradient must not undo the texture's own alpha: the colours' strength)
    local own = tex:GetAlpha()
    pcall(tex.SetGradient, tex, "VERTICAL", low, high)
    tex:SetAlpha(own)
end

-- (a colour lit toward white)
local function Lit(color, by)
    return { color[1] + (1 - color[1]) * by, color[2] + (1 - color[2]) * by, color[3] + (1 - color[3]) * by }
end

-- (a half's bar, full out from the middle)
local function Bar(track, left, level)
    local bar = CreateFrame("StatusBar", nil, track)
    bar:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return bar
end

-- (a bar laid from a fill's leading edge (its outer one: the left half
-- fills reversed), a half wide so it shares the line's scale: outward (the
-- heals coming) or back in over the fill (a spell's cost))
local function EdgeBar(track, fill, left, outward, level, parent)
    local bar = CreateFrame("StatusBar", nil, parent or track)
    local edge = left and "LEFT" or "RIGHT"
    local from = outward and (left and "RIGHT" or "LEFT") or edge
    bar:SetPoint("TOP" .. from, fill, "TOP" .. edge)
    bar:SetPoint("BOTTOM" .. from, fill, "BOTTOM" .. edge)
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    bar:SetReverseFill(outward == left)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    track.sized[#track.sized + 1] = function(half) bar:SetWidth(math.max(half, 1)) end
    return bar
end

-- (a colour over the fill (orange, red over the green), graded as it is)
local function Over(bar, fill, sub, left, color)
    local t = bar:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetAllPoints(fill)
    t:SetColorTexture(1, 1, 1, 1)
    t:SetAlpha(0)
    Grade(t, left, color)
    return t
end

-- (a bright cap on the fill's leading edge (its outer one: the left half
-- fills reversed), placed by the bar, so a secret value moves it too)
local function Cap(bar, fill, left, color)
    local c = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    c:SetPoint("TOPRIGHT", fill)
    c:SetPoint("BOTTOMRIGHT", fill)
    c:SetWidth(GLOW_W)
    c:SetColorTexture(1, 1, 1, 1)
    c:SetBlendMode("ADD")
    if c.SetGradient and CreateColor then
        c:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.22))
    end
    Tinted(c, color)
    return c
end

-- (the stripes, still over the whole track, tiling)
local function Stripes(parent, track, color, alpha)
    local s = parent:CreateTexture(nil, "OVERLAY")
    s:SetTexture(STRIPES, "REPEAT", "REPEAT")
    s:SetHorizTile(true)
    s:SetVertTile(true)
    s:SetPoint("TOPLEFT", track, "TOPLEFT", -STRIPE_TILE * 2, 0)
    s:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", STRIPE_TILE * 2, 0)
    Tinted(s, color, alpha)
    return s
end

-- (a frame clipping what's in it to a span (a bar's fill): the stripes lie
-- still and only show over the fill, so they never stretch as it moves;
-- DoesItDie's way, as its width may come from a secret)
local function Clip(parent, track, span, level)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetPoint("TOPLEFT", span)
    clip:SetPoint("BOTTOMRIGHT", span)
    clip:SetFrameLevel(track:GetFrameLevel() + level)
    clip:SetClipsChildren(true)
    return clip
end

-- (a pulse layer over a track's fills: its glows' strength the secret
-- curve's, the frame's alpha the pulse, never the holder's: it fades by
-- its own)
local function Pulse(track, low, time)
    local f = Layer(track, L_OVER)
    local g = f:CreateAnimationGroup()
    g:SetLooping("BOUNCE")
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(low)
    a:SetDuration(time)
    a:SetSmoothing("IN_OUT")
    return f, g
end

-- (a glow over a fill, its strength set by a curve)
local function Glow(layer, fill, r, g, b, a)
    local t = layer:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(fill)
    t:SetTexture(WHITE)
    t:SetBlendMode("ADD")
    t:SetVertexColor(r, g, b, a)
    t:SetAlpha(0)
    return t
end

local pulse, beat = Pulse(line, 0.15, 0.5)
local powerPulse, powerBeat = Pulse(power, 0.2, 0.6)

---------------------------------------------------------------------------
-- The two lines: two halves each, full out from the middle
---------------------------------------------------------------------------
-- (per line: its halves, the trail's value and when it eases in)
local healthLine = { halves = {}, trail = {} }
local powerLine = { halves = {}, trail = {} }
local halves, powerHalves = healthLine.halves, powerLine.halves

for i = 1, 1 do
    local left = false
    local h = { left = left }
    h.trail = Bar(line, left, L_UNDER)
    h.trail:SetStatusBarColor(TRAIL[1], TRAIL[2], TRAIL[3], TRAIL[4])
    h.bar = Bar(line, left, L_FILL)
    local fill = h.bar:GetStatusBarTexture()
    Grade(fill, left, GREEN)
    h.orange, h.red = Over(h.bar, fill, 1, left, ORANGE), Over(h.bar, fill, 2, left, RED)
    h.cap = Cap(h.bar, fill, left, { 0.85, 1, 0.85 })
    -- (the heals coming, from the fill's end on: a striped band, square)
    h.heal = EdgeBar(line, fill, left, true, L_HEAL)
    local healSpan = h.heal:CreateTexture(nil, "ARTWORK")
    healSpan:SetColorTexture(1, 1, 1, 1)
    Tinted(healSpan, HEAL)
    h.heal:SetStatusBarTexture(healSpan)
    Stripes(Clip(line, line, healSpan, L_HEAL), line, HEAL_STRIPE)
    h.alarm = Glow(pulse, fill, 1, 0.25, 0.2, 0.55)
    halves[i] = h

    local p = { left = left }
    p.trail = Bar(power, left, L_UNDER)
    p.trail:SetStatusBarColor(TRAIL[1], TRAIL[2], TRAIL[3], TRAIL[4])
    p.bar = Bar(power, left, L_FILL)
    p.bar:SetValue(0)
    local pfill = p.bar:GetStatusBarTexture()
    p.cap = Cap(p.bar, pfill, left, Lit(POWER_COLOR, 0.5))
    p.low = Glow(powerPulse, pfill, 0.75, 0.9, 1, 0.6)
    -- (a spell's cost, from the fill's end back in, clipped to the fill: a
    -- cost past what you have covers it all; a striped band, square, its
    -- stripes drifting in, toward where the mana goes)
    local clip = Clip(power, power, pfill, L_OVER)
    clip:Hide()
    p.costClip = clip
    p.cost = EdgeBar(power, pfill, left, false, L_OVER, clip)
    local span = p.cost:CreateTexture(nil, "ARTWORK")
    span:SetColorTexture(1, 1, 1, 1)
    Tinted(span, COST)
    p.cost:SetStatusBarTexture(span)
    local costStripes = Clip(clip, power, span, L_OVER)
    p.costStripes = Stripes(costStripes, power, Lit(POWER_COLOR, 0.5), 0.85)
    local drift = p.costStripes:CreateAnimationGroup()
    drift:SetLooping("REPEAT")
    local move = drift:CreateAnimation("Translation")
    move:SetOffset((left and 1 or -1) * STRIPE_TILE, 0)
    move:SetDuration(RIBBON_TIME)
    p.drift = drift
    powerHalves[i] = p
end

---------------------------------------------------------------------------
-- Curves: a colour's strength from your health or power percent
---------------------------------------------------------------------------
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

-- (made-up values while /if linetest runs: hp, hpMax, mp, mpMax, heal)
local demo

-- (the health's and the power's reads: value and max, percent by a curve)
local HEALTH = {
    Read = function()
        if demo then return demo.hp, demo.hpMax end
        return UnitHealth("player"), UnitHealthMax("player")
    end,
    Percent = function(c) return UnitHealthPercent("player", true, c) end,
}
local POWER = {
    Read = function()
        if demo then return demo.mp, demo.mpMax end
        return UnitPower("player"), UnitPowerMax("player")
    end,
    Percent = function(c) return UnitPowerPercent("player", nil, false, c) end,
}

-- (the heals coming to you, as they are (maybe secret, maybe nil))
local function IncomingHeals()
    if demo then return demo.heal end
    if not UnitGetIncomingHeals then return nil end
    local ok, v = pcall(UnitGetIncomingHeals, "player")
    if ok then return v end
    return nil
end

-- (a region's alpha from a curve of your health (or power) percent,
-- secret or not; the way it went, for /if lineprobe)
local function Shade(t, points, of)
    of = of or HEALTH
    -- (read whole, out of a fight: worked out here, never by the curve)
    local value, max = of.Read()
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
        return "whole"
    end
    local c = Curve(points)
    if not (c and pcall(function() t:SetAlpha(of.Percent(c)) end)) then
        t:SetAlpha(0)
        return "none"
    end
    return "curve"
end

---------------------------------------------------------------------------
-- Filling: the fill eased, the trail after (the loss shows past the fill as
-- it shrinks): never a comparison of the two, the bars' order does it
---------------------------------------------------------------------------
-- (a bar to a value, eased if asked; false when the value won't go)
local function To(bar, value, ease)
    if ease and SI and Try(bar.SetValue, bar, value, SI.ExponentialEaseOut) then return true end
    return Try(bar.SetValue, bar, value)
end

local function TrailTo(L, ease, empty)
    L.trail.at = nil
    for _, h in ipairs(L.halves) do
        if not To(h.trail, L.trail.value, ease) then h.trail:SetValue(empty) end
    end
end

-- (the heals coming to you, on the health's scale)
local function FillHeals(max)
    local coming = IncomingHeals()
    for _, h in ipairs(halves) do
        if not (Try(h.heal.SetMinMaxValues, h.heal, 0, max) and Try(h.heal.SetValue, h.heal, coming)) then
            h.heal:SetMinMaxValues(0, 1)
            h.heal:SetValue(0)
        end
    end
end

-- (the halves filled from your health as it is, the colours' strength;
-- eased: the trail follows after TRAIL_DELAY, else everything snaps)
local function Fill(ease)
    local value, max = HEALTH.Read()
    healthLine.trail.value = value
    for _, h in ipairs(halves) do
        local bar = h.bar
        if not (Try(bar.SetMinMaxValues, bar, 0, max) and To(bar, value, ease)) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            healthLine.trail.value = 1
        end
        if not ease and not Try(h.trail.SetMinMaxValues, h.trail, 0, max) then
            h.trail:SetMinMaxValues(0, 1)
        end
        h.how = Shade(h.orange, ORANGE_POINTS)
        Shade(h.red, RED_POINTS)
        Shade(h.alarm, URGENT_POINTS)
    end
    FillHeals(max)
    if ease then
        healthLine.trail.at = GetTime() + TRAIL_DELAY
    else
        TrailTo(healthLine, false, 1)
    end
end

-- (your power's kind, or nil (a secret))
local function PowerToken()
    if demo then return "MANA" end
    local ok, _, token = pcall(UnitPowerType, "player")
    if not ok or Secret(token) then return nil end
    return token
end

local function PowerColor(token)
    local c = PowerBarColor and PowerBarColor[token]
    return OWN_COLORS[token] or type(c) == "table" and c.r and { c.r, c.g, c.b } or POWER_COLOR
end

-- (the power's halves: its kind's colour on the fill, its value as it
-- is, eased on a change of it; its kind a secret: the last one kept)
local function FillPower(ease)
    local token = PowerToken() or powerHalves[1].token or "MANA"
    local value, max = POWER.Read()
    powerLine.trail.value = value
    for _, p in ipairs(powerHalves) do
        if p.token ~= token then
            p.token = token
            local color = PowerColor(token)
            Grade(p.bar:GetStatusBarTexture(), p.left, color)
            Tinted(p.cap, Lit(color, 0.5))
            Tinted(p.costStripes, Lit(color, 0.5), 0.85)
        end
        local bar = p.bar
        if not (Try(bar.SetMinMaxValues, bar, 0, max) and To(bar, value, ease)) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            powerLine.trail.value = 0
        end
        if not ease and not Try(p.trail.SetMinMaxValues, p.trail, 0, max) then
            p.trail:SetMinMaxValues(0, 1)
        end
        if not Try(p.cost.SetMinMaxValues, p.cost, 0, max) then p.cost:SetMinMaxValues(0, 1) end
        -- (low mana pulses; the other kinds run low by design)
        if token == "MANA" then
            Shade(p.low, LOW_POINTS, POWER)
        else
            p.low:SetAlpha(0)
        end
    end
    if ease then
        powerLine.trail.at = GetTime() + TRAIL_DELAY
    else
        TrailTo(powerLine, false, 0)
    end
end

---------------------------------------------------------------------------
-- A spell's cost while you cast it
---------------------------------------------------------------------------
local MANA_TYPE = Enum.PowerType and Enum.PowerType.Mana or 0

-- (a spell's cost in your power's kind, as it is (maybe secret); nil:
-- none known)
local function SpellCost(spellID, token)
    if not (spellID and C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, cost = pcall(function()
        for _, c in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if c.name == token or (token == "MANA" and c.type == MANA_TYPE) then return c.cost end
        end
    end)
    -- (never tested for truth: it may be a secret)
    if ok then return cost end
    return nil
end

-- (the cast being shown)
local casting = {}

-- (none: pass `false`; a cost, as it is, secret or not: never compared,
-- the bar takes it or doesn't)
local function ShowCost(cost)
    local some = Secret(cost) or type(cost) == "number"
    for _, p in ipairs(powerHalves) do
        if some and Try(p.cost.SetValue, p.cost, cost) then
            p.costClip:Show()
            if not p.drift:IsPlaying() then p.drift:Play() end
        else
            p.cost:SetValue(0)
            p.drift:Stop()
            p.costClip:Hide()
        end
    end
end

local function CastStart(castGUID, spellID)
    -- (kept only as a plain string: a secret one ends on any cast's end)
    casting.guid = (not Secret(castGUID) and type(castGUID) == "string") and castGUID or true
    ShowCost(SpellCost(spellID, PowerToken() or powerHalves[1].token or "MANA"))
end

-- (the cast over: its cost gone, or taken)
local function CastEnd(castGUID)
    if not casting.guid then return end
    if type(casting.guid) == "string" and not Secret(castGUID) and type(castGUID) == "string"
        and castGUID ~= casting.guid then
        return
    end
    casting.guid = nil
    ShowCost(false)
end

---------------------------------------------------------------------------
-- Showing: the lines peek
---------------------------------------------------------------------------
-- (wanted: in a fight or not at rest (read whole out of one))
local function PowerWanted()
    if demo or IF.InCombat() then return true end
    local value, max = POWER.Read()
    if Secret(value) or Secret(max) or type(value) ~= "number" or type(max) ~= "number" then return true end
    if max <= 0 then return false end
    local token = PowerToken()
    if not token then return true end
    if RESTS_EMPTY[token] then return value > 0 end
    return value < max
end

local function Wanted()
    if demo then return true end
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
    if healthLine.trail.at and now >= healthLine.trail.at then TrailTo(healthLine, true, 1) end
    if powerLine.trail.at and now >= powerLine.trail.at then TrailTo(powerLine, true, 0) end
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
        powerBeat:Stop()
        self:Hide()
    end
end)

-- (each line: true eases it, false snaps it, nil leaves it be, so one
-- line's change never snaps the other's ease and trail away)
local function Update(health, mp)
    if not PlayerHealth.on then return end
    -- (unseen: snap, so it doesn't ease from a stale value as it shows)
    local unseen = not holder:IsShown() or holder:GetAlpha() <= 0
    if health and unseen then health = false end
    if mp and (unseen or power:GetAlpha() <= 0) then mp = false end
    if PlayerHealth.health and health ~= nil then Fill(health) end
    if PlayerHealth.power and mp ~= nil then FillPower(mp) end
    local was = holder.wanted
    holder.wanted = Wanted()
    if holder.wanted then
        holder.holdUntil = nil
        holder:Show()
        if PlayerHealth.health and not beat:IsPlaying() then beat:Play() end
        if PlayerHealth.power and not powerBeat:IsPlaying() then powerBeat:Play() end
    elseif Flag(UnitIsDeadOrGhost, "player") then
        holder.holdUntil = nil
    elseif was then
        -- (whole and at rest again: held a moment, the trail done, then faded)
        holder.holdUntil = GetTime() + HOLD
    end
end

local POWER_CHANGE = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true }
local POWER_SNAP = { UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }
local CAST_END = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_SUCCEEDED = true }
local powerAt
local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
-- (an event this client hasn't: left out, not an error)
for _, e in ipairs(UF.POWER_EVENTS) do pcall(events.RegisterUnitEvent, events, e, "player") end
pcall(events.RegisterUnitEvent, events, "UNIT_HEAL_PREDICTION", "player")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
    events:RegisterUnitEvent(e, "player")
end
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event, _, castGUID, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if PlayerHealth.power and not demo then CastStart(castGUID, spellID) end
    elseif CAST_END[event] then
        if not demo then CastEnd(castGUID) end
    elseif event == "UNIT_HEAL_PREDICTION" then
        if PlayerHealth.on and PlayerHealth.health then FillHeals((select(2, HEALTH.Read()))) end
    elseif POWER_CHANGE[event] then
        -- (the two power events come together for one change: taken once)
        local now = GetTime()
        if now == powerAt then return end
        powerAt = now
        Update(nil, true)
    elseif event == "UNIT_HEALTH" then
        Update(true, nil)
    elseif event == "UNIT_MAXHEALTH" then
        Update(false, nil)
    elseif POWER_SNAP[event] then
        Update(nil, false)
    else
        -- (a fight's start or end, a load, dying or coming back: both snap)
        Update(false, false)
    end
end)

---------------------------------------------------------------------------
-- On while a setting is: the power on the edge, the health over it (alone:
-- on the edge)
---------------------------------------------------------------------------
local function Place(health, mp)
    line:SetShown(health)
    power:SetShown(mp)
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, mp and POWER_H + GAP or 0)
    line:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, mp and POWER_H + GAP or 0)
    power:ClearAllPoints()
    power:SetPoint("BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT")
    local h = (health and LINE_H or 0) + (mp and POWER_H or 0) + (health and mp and GAP or 0)
    holder:SetHeight(math.max(h, 1))
    if not health then beat:Stop() end
    if not mp then
        powerBeat:Stop()
        casting.guid = nil
        ShowCost(false)
    end
end

local function Watch()
    if not IF.db then return end
    IF.db.manaLog = nil         -- (the mana regen probe's log, done)
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
        holder.wanted, holder.holdUntil = false, nil
        healthLine.trail.at, powerLine.trail.at = nil, nil
        beat:Stop()
        powerBeat:Stop()
        holder:SetAlpha(0)
        holder:Hide()
    end
end

IN.Watcher("health line", 0.25, Watch)

function PlayerHealth.Apply()
    Watch()
end

---------------------------------------------------------------------------
-- /if linetest: the lines run through made-up values, a step every second
-- or two, each said in the chat with what to look for
---------------------------------------------------------------------------
local run = 0
local HP, MP = 1000, 1000

local function DemoStop(quiet)
    run = run + 1
    if not demo then return end
    demo = nil
    casting.guid = nil
    ShowCost(false)
    Update(false, false)
    if not quiet then IF.Print("Line test: done, the real values are back.") end
end

-- (a step's values, eased)
local function Set(hp, mp, heal)
    local easeH = hp ~= nil and hp ~= demo.hp
    local easeP = mp ~= nil and mp ~= demo.mp
    demo.hp, demo.mp = hp or demo.hp, mp or demo.mp
    if heal ~= nil then demo.heal = heal end
    Update(easeH or nil, easeP or nil)
    if heal ~= nil then FillHeals(demo.hpMax) end
end

local STEPS = {
    { 0, "full: two lines, the bright cap at each end, notches at 25/50/75%",
        function() Set(HP, MP, 0); Update(false, false) end },
    { 2, "mana -40%: a pale trail where it was, easing in after",
        function() Set(nil, 600) end },
    { 3, "casting (cost 25%): a striped band at the end of the mana, drifting in",
        function() casting.guid = true; ShowCost(250) end },
    { 2.5, "cast done: the cost taken",
        function() casting.guid = nil; ShowCost(false); Set(nil, 350) end },
    { 1.5, "mana coming back: the fill easing out",
        function() Set(nil, 500) end },
    { 2, "low mana (15%): the mana bar pulses",
        function() Set(nil, 150) end },
    { 3, "hit to 45% health: orange, a pale trail; a heal coming (30%): a green striped band past the fill",
        function() Set(450, nil, 300) end },
    { 3, "the heal lands: the band gone, the fill grown",
        function() Set(750, nil, 0) end },
    { 2.5, "health 20%: red, pulsing",
        function() Set(200) end },
    { 2.5, "casting with too little mana (cost 40% > 15%): the band over the whole mana fill",
        function() casting.guid = true; ShowCost(400) end },
    { 3, nil, function() DemoStop() end },
}

local function DemoStep(i, id)
    if id ~= run or not demo then return end
    local step = STEPS[i]
    if not step then return end
    if step[2] then IF.Print(("Line test %d: %s"):format(i, step[2])) end
    step[3]()
    local nextStep = STEPS[i + 1]
    if nextStep then C_Timer.After(nextStep[1], function() DemoStep(i + 1, id) end) end
end

function PlayerHealth.Test(arg)
    if arg == "stop" then return DemoStop() end
    if not PlayerHealth.on then
        IF.Print("Line test: turn the Health line or Power line on first (Interface tab).")
        return
    end
    DemoStop(true)
    demo = { hp = HP, hpMax = HP, mp = MP, mpMax = MP, heal = 0 }
    IF.Print("Line test: about 25 seconds. /if linetest stop to end it.")
    DemoStep(1, run)
end

IF.AddCommand("linetest", function(args) PlayerHealth.Test(args and args[1]) end,
    "[stop]: run the health and power lines through made-up values (trail, cost, heals, low)")

-- /if lineprobe: why the health bar shows the colour it does (secret
-- values said as <hidden>)
local function Said(v)
    if Secret(v) then return "<hidden>" end
    return tostring(v)
end

IF.AddCommand("lineprobe", function()
    local v, m = UnitHealth("player"), UnitHealthMax("player")
    local h = halves[2]
    IF.Print(("Line probe: health %s / %s, percent %s, colours by %s"):format(Said(v), Said(m),
        Said(select(2, pcall(UnitHealthPercent, "player", true))), tostring(h.how)))
    IF.Print(("  alpha: orange %s, red %s, urgent %s"):format(Said(h.orange:GetAlpha()),
        Said(h.red:GetAlpha()), Said(h.alarm:GetAlpha())))
    local c = Curve(RED_POINTS)
    if c and c.Evaluate then
        IF.Print(("  red curve at 0 / 0.5 / 1 / 100: %s / %s / %s / %s"):format(
            Said(select(2, pcall(c.Evaluate, c, 0))), Said(select(2, pcall(c.Evaluate, c, 0.5))),
            Said(select(2, pcall(c.Evaluate, c, 1))), Said(select(2, pcall(c.Evaluate, c, 100)))))
    else
        IF.Print("  no curve")
    end
end, ": why the health line shows the colour it does")
