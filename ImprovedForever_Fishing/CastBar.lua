-- The fishing bar: each cast of Fishing as a scene on the right of the
-- screen (the fishing view frames you low on the left, View.lua), in
-- place of the cast bar (the Immersion module's cast line, PlayerCast.Claim;
-- else the game's, faded).
--   The cast: from the rod's tip (left) the bobber flies out in an arc to
--   its spot (right), the line following it; landed, it bobs, rings
--   spreading round it on the water (seen from above), the line sagging and
--   swaying; the time gone a light setting off from the tip (lit with it)
--   along the line to the bobber, then round it. Over the bobber: your
--   lure (on, how long) or the best one in your bags to put on (R2 twice,
--   Fishing.lua).
--   A catch: a splash of the catch's colour (its best item's quality's),
--   the line snapping taut and lit, then reeled in, the bobber along it to
--   the tip; there a flash and each item flying out of it along an arc to
--   a row over the line, round in a ring of its quality's colour, the best
--   one first and biggest; over the row CAUGHT, NEW CATCH (first this
--   session) or RARE CATCH (rare and up: a glow beating behind it, held
--   longer), under it the best one's name. Then each flies on to its place
--   on the stringer down the screen's right (Panel.lua: F.RackSpot,
--   F.RackHit), shrinking to its size there.
--   A miss: the line going slack and grey, the bobber sinking, what got
--   away (the fish, grey) rising from it to the row, a red cross stamped
--   on it, "The fish got away"; nothing hooked yet ("No fish are
--   hooked."): the same with the bare bobber, "Nothing on the line yet".
--   Cast stopped with nothing come of it: the bobber reeled back in to the
--   tip.
-- While the fishing view is on, your other casts (a lure put on) go on it
-- too: the line drawn out from the tip as the cast fills, its icon at its
-- end, its name over the tip.
-- The cast's times can be secret: then no ring. The catch comes as its
-- loot (Session.lua: F.OnCatch, the same frame as the channel's end or
-- just after), a miss as the game's error line (F.OnEscape): the channel's
-- end waits WAIT seconds for one before reeling in. Our own frames only.
-- /if fishshow [miss | early | rare | cancel]: a cast and its end, made up.
local IF = ImprovedForever
local F = IF.Fishing

local FISHING = 7620
local W, H = 500, 240
local TIP_X, TIP_Y = 0, 80              -- (the rod's tip: the line's left end)
local BOB_X, BOB_Y = W - 70, 80         -- (the bobber's spot)
local SEGMENTS = 28
local SAG, SWAY = 12, 3
local FLIGHT = 0.65                     -- (the cast: how long)
-- (the time ring on the bobber's own ring, as the gamepad bar's cast ring
-- runs on a tile's border (GamepadBar.lua: RING_AT, its line and glow): the
-- round slot's ring (Round: 1.28 the icon) is drawn ~0.43 of its size out)
-- (in steps longer than its lines are thick: a line shorter than its
-- thickness isn't drawn)
local BOBBER, RING_STEPS = 28, 18
local RING_R = BOBBER * 1.28 * 0.43
local RING_LINE, RING_GLOW = 2.5, 4
local WAIT, REEL, OUT, IN_TIME = 0.9, 0.5, 0.6, 0.25
local CATCH_HOLD, RARE_HOLD, MISS_HOLD = 2.4, 3.4, 1.8
local FLY, FLY_STAGGER = 0.6, 0.08      -- (held: the catch flying to the stringer, Panel.lua)
local RARE = 3                          -- (rare and up)
local ROW_X, ROW_Y = W * 0.55, 165      -- (the catch's row: its middle)
local BIG, SMALL, ITEM_GAP, MAX_ITEMS = 44, 32, 12, 5
local LINE_COLOR = { 0.92, 0.9, 0.82 }
local GOLD, GREY, MISS = { 1, 0.82, 0 }, { 0.62, 0.62, 0.62 }, { 0.55, 0.7, 0.85 }
local LURE_COLOR = { 0.45, 0.85, 0.45 }
local MISS_TEXT = { 0.92, 0.5, 0.46 }    -- (a miss's words: a soft red)
local MISS_LINE = { 0.78, 0.42, 0.4 }    -- (and its line, its ripples: a quieter one)
local RING = "gamepad-actionbar-circleslot-frame"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAR = "Interface\\Cooldown\\star4"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local FISH_ICON = "Interface\\Icons\\INV_Misc_Fish_02"
-- (the bobber: the game's own model (world/goober/g_fishingbobber.m2) over
-- dark water; until it's loaded, or when it can't be, our drawing of it
-- (tools/make_fishing_icons.py); the time lit in the game's own channel
-- green, as its cast bar fills a channel)
local BOBBER_MODEL = 201000
local BOBBER_ART = "Interface\\AddOns\\ImprovedForever\\textures\\fishing_bobber"
local WATER_ART = "Interface\\AddOns\\ImprovedForever\\textures\\fishing_water"
local MODEL_VIEW, MODEL_FOV = math.rad(25), math.rad(30)   -- (seen from a little above)
local BOBBER_COLOR = { 0.1, 1, 0.15 }

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end
local function Clamp(x) return math.max(0, math.min(1, x)) end
local function Ease(x) x = Clamp(x) return 1 - (1 - x) ^ 3 end
local function Lerp(a, b, t) return a + (b - a) * t end

local bar = CreateFrame("Frame", "ImprovedForeverFishingBar", UIParent)
bar:SetSize(W, H)
bar:SetFrameStrata("MEDIUM")
bar:EnableMouse(false)
bar:Hide()

-- (on the right: from just right of the screen's middle, a bit under it;
-- clear of the stringer down the right edge, Panel.lua)
local function Place()
    local x = UIParent:GetWidth() * 0.5 + 30
    local rack = rawget(_G, "ImprovedForeverFishingLoot")
    local left = rack and rack:IsShown() and rack:GetLeft()
    if left then x = math.min(x, left * rack:GetEffectiveScale() / UIParent:GetEffectiveScale() - W - 10) end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, UIParent:GetHeight() * 0.33)
end

local function Shadowed(fs, color)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- A round icon: its picture cut round (its own border cut off), the game's
-- round slot's ring over it
local function Round(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = f:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(mask)
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetPoint("TOPLEFT", -size * 0.14, size * 0.14)
    f.ring:SetPoint("BOTTOMRIGHT", size * 0.14, -size * 0.14)
    f.ring:SetAtlas(RING)
    return f
end

-- (a spot in the bar: x, y from its bottom left; a scaled frame's offsets
-- are in its own scale: set its scale first)
local function At(region, x, y)
    local k = region.GetScale and region:GetScale() or 1
    if k <= 0 then k = 1 end
    region:ClearAllPoints()
    region:SetPoint("CENTER", bar, "BOTTOMLEFT", x / k, y / k)
end

---------------------------------------------------------------------------
-- Its parts
---------------------------------------------------------------------------
-- (over the rod's tip, from its left: the lure; over it another cast's
-- name, BarSpell)
local lureText = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)
lureText:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", TIP_X - 3, TIP_Y + 12)
lureText:SetJustifyH("LEFT")
local header = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormal"), GOLD)
header:SetPoint("BOTTOMLEFT", lureText, "TOPLEFT", 0, 3)

-- (the rod's tip: a small light)
local tip = bar:CreateTexture(nil, "ARTWORK")
tip:SetTexture(CIRCLE_MASK)
tip:SetSize(6, 6)
At(tip, TIP_X, TIP_Y)

-- (the line: a curve in straight steps, each a line and its faint glow)
local lineFrame = CreateFrame("Frame", nil, bar)
lineFrame:SetAllPoints()
local segs, glows = {}, {}
for i = 1, SEGMENTS do
    local glow = lineFrame:CreateLine(nil, "ARTWORK", nil, 1)
    glow:SetThickness(5)
    glow:SetTexture(WHITE)
    glow:SetBlendMode("ADD")
    local seg = lineFrame:CreateLine(nil, "ARTWORK", nil, 2)
    seg:SetThickness(1.5)
    seg:SetTexture(WHITE)
    segs[i], glows[i] = seg, glow
end
-- (the time gone, lit along the line from the tip toward the bobber, a
-- spark at its head)
-- (the time's colour: the bobber's icon's main one (the Immersion module's
-- icon colours, PlayerCast.IconColor), lifted a little toward white to
-- show on the dark water; else a warm gold. SetLitColor)
local LIT_COLOR = { 1, 0.85, 0.45 }
local litColor = LIT_COLOR
local lits, litGlows = {}, {}
for i = 1, SEGMENTS do
    local glow = lineFrame:CreateLine(nil, "ARTWORK", nil, 3)
    glow:SetThickness(3.5)
    glow:SetTexture(WHITE)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(LIT_COLOR[1], LIT_COLOR[2], LIT_COLOR[3], 0.25)
    local seg = lineFrame:CreateLine(nil, "ARTWORK", nil, 4)
    seg:SetThickness(1.5)
    seg:SetTexture(WHITE)
    seg:SetVertexColor(LIT_COLOR[1], LIT_COLOR[2], LIT_COLOR[3], 1)
    lits[i], litGlows[i] = seg, glow
end
-- (the bobber, its ripples, its time ring, a splash)
local bobber = Round(bar, BOBBER)
bobber:SetFrameLevel(lineFrame:GetFrameLevel() + 3)
-- (the time's head: over the bobber too, on its frame)
local spark = bobber:CreateTexture(nil, "OVERLAY", nil, 7)
spark:SetTexture("Interface\\Cooldown\\star4")
spark:SetBlendMode("ADD")
spark:SetSize(16, 16)
spark:SetVertexColor(LIT_COLOR[1], LIT_COLOR[2], LIT_COLOR[3])
-- (the water seen from above, the screen its surface: rings spreading out
-- round the bobber, under it)
local RIPPLES, RIPPLE_PERIOD = 3, 2.4
local WATER_COLOR = { 0.62, 0.8, 0.92 }
local ripples = {}
for i = 1, RIPPLES do
    local r = bar:CreateTexture(nil, "BORDER")
    r:SetAtlas(RING)
    r:SetBlendMode("ADD")
    r:SetAlpha(0)
    ripples[i] = r
end
-- (the time ring: a frame of its own on the bobber, over it and wider than
-- its ring (a line reaching past its frame isn't drawn), its lines placed
-- from its middle, as the gamepad bar's cast ring from its tile's)
local ringFrame = CreateFrame("Frame", nil, bobber)
ringFrame:SetSize(BOBBER * 2.4, BOBBER * 2.4)
ringFrame:SetPoint("CENTER")
ringFrame:SetFrameLevel(bobber:GetFrameLevel() + 2)
local ringLines, ringGlows = {}, {}
for i = 1, RING_STEPS do
    local g = ringFrame:CreateLine(nil, "OVERLAY", nil, 5)
    g:SetThickness(RING_GLOW)
    g:SetTexture(WHITE)
    g:SetBlendMode("ADD")
    ringGlows[i] = g
    local l = ringFrame:CreateLine(nil, "OVERLAY", nil, 6)
    l:SetThickness(RING_LINE)
    l:SetTexture(WHITE)
    l:SetBlendMode("ADD")
    ringLines[i] = l
end
local splash = bar:CreateTexture(nil, "OVERLAY")
splash:SetTexture(STAR)
splash:SetBlendMode("ADD")
splash:SetAlpha(0)
-- (a flash at the tip: a catch reeled in to it)
local tipFlash = bar:CreateTexture(nil, "OVERLAY")
tipFlash:SetTexture(STAR)
tipFlash:SetBlendMode("ADD")
tipFlash:SetAlpha(0)

-- (the catch: its items round in a row, a label over, the best one's name
-- under; a glow behind the best one, a rare one's)
local glow = bar:CreateTexture(nil, "BORDER")
glow:SetTexture(STAR)
glow:SetBlendMode("ADD")
glow:SetSize(BIG * 2.6, BIG * 2.6)
glow:SetAlpha(0)
local items = {}
local function Item(i)
    local it = items[i]
    if it then return it end
    it = Round(bar, i == 1 and BIG or SMALL)
    it:SetFrameLevel(bobber:GetFrameLevel() + 4)
    it.count = Shadowed(it:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
    it.count:SetPoint("BOTTOMRIGHT", 4, -2)
    it:Hide()
    items[i] = it
    return it
end
-- (a miss: what got away (the fish, or the bare bobber: nothing on it),
-- grey in a grey ring, a red cross on it)
local missIcon = Round(bar, BIG)
missIcon:SetFrameLevel(bobber:GetFrameLevel() + 4)
missIcon.icon:SetDesaturated(true)
missIcon.ring:SetVertexColor(GREY[1], GREY[2], GREY[3])
missIcon.cross = missIcon:CreateTexture(nil, "OVERLAY", nil, 2)
missIcon.cross:SetAtlas("common-icon-redx")
missIcon.cross:SetSize(BIG * 0.5, BIG * 0.5)
missIcon.cross:SetPoint("CENTER", missIcon, "BOTTOMRIGHT", -BIG * 0.12, BIG * 0.12)
missIcon:Hide()
local label = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
local title = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
title:SetWordWrap(false)
title:SetWidth(W - 40)

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- (the line from (x1, y1) to (x2, y2), sagging by sag at its middle (less
-- than 0: bowed up); upto: the share of it drawn from (x1, y1), 1 all)
local function DrawLine(x1, y1, x2, y2, sag, color, alpha, upto)
    if alpha <= 0 then
        lineFrame:Hide()
        return
    end
    lineFrame:Show()
    upto = upto or 1
    local px, py = x1, y1
    for i = 1, SEGMENTS do
        local u = upto * i / SEGMENTS
        local x, y = Lerp(x1, x2, u), Lerp(y1, y2, u) - sag * 4 * u * (1 - u)
        for _, l in ipairs({ segs[i], glows[i] }) do
            l:SetStartPoint("BOTTOMLEFT", bar, px, py)
            l:SetEndPoint("BOTTOMLEFT", bar, x, y)
        end
        segs[i]:SetVertexColor(color[1], color[2], color[3], alpha)
        glows[i]:SetVertexColor(color[1], color[2], color[3], 0.12 * alpha)
        px, py = x, y
    end
end

-- (the time gone along the line: on its curve as DrawLine's, from (x1, y1)
-- upto of the way; alpha 0: none)
local function CurveAt(x1, y1, x2, y2, sag, u)
    return Lerp(x1, x2, u), Lerp(y1, y2, u) - sag * 4 * u * (1 - u)
end

-- (where the line from the bobber at (bx, by) to the tip leaves the time
-- ring round it: how far along the curve from the bobber, a few steps in)
local function ExitU(bx, by, sag)
    local u0 = RING_R / math.max(1, BOB_X - TIP_X)
    for _ = 1, 3 do
        local ex, ey = CurveAt(bx, by, TIP_X, TIP_Y, sag, u0)
        local d = math.sqrt((ex - bx) ^ 2 + (ey - by) ^ 2)
        if d > 0 then u0 = u0 * RING_R / d end
    end
    return u0
end

-- (from, to: the stretch of the curve it runs on, 0 its start, 1 its end;
-- upto: the share of it drawn)
local function DrawLit(x1, y1, x2, y2, sag, upto, alpha, from, to)
    -- (steps of the curve's own length, only those reached, the last one
    -- partway: a short stretch drawn whole, not as many tiny steps the game
    -- won't draw)
    from, to = from or 0, to or 1
    upto = Clamp(upto)
    local n = math.ceil(SEGMENTS * upto)
    local px, py = CurveAt(x1, y1, x2, y2, sag, from)
    for i = 1, SEGMENTS do
        local pair = { lits[i], litGlows[i] }
        if i <= n and alpha > 0 then
            local u = from + (to - from) * math.min(i / SEGMENTS, upto)
            local x, y = CurveAt(x1, y1, x2, y2, sag, u)
            for _, l in ipairs(pair) do
                l:SetStartPoint("BOTTOMLEFT", bar, px, py)
                l:SetEndPoint("BOTTOMLEFT", bar, x, y)
                l:SetAlpha(alpha)
            end
            px, py = x, y
        else
            for _, l in ipairs(pair) do l:SetAlpha(0) end
        end
    end
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", bar, "BOTTOMLEFT", px, py)
    spark:SetAlpha(upto > 0 and upto < 1 and alpha * (0.75 + 0.25 * math.sin(GetTime() * 9)) or 0)
end

local function HideLit()
    tip:SetVertexColor(1, 1, 1, 1)
    tip:SetSize(6, 6)
    for i = 1, SEGMENTS do
        lits[i]:SetAlpha(0)
        litGlows[i]:SetAlpha(0)
    end
    spark:SetAlpha(0)
end

-- (the time ring round the bobber: share left, from its top clockwise)
-- (from `from` (an angle from its top, clockwise: where the line leaves it),
-- round over its top and back: so the time runs on from it onto the line;
-- its head, x and y, returned)
local function DrawRing(x, y, share, alpha, from)
    from = from or -math.pi / 2
    share = Clamp(share)
    local n = math.ceil(RING_STEPS * share)
    local hx, hy = x + math.sin(from) * RING_R, y + math.cos(from) * RING_R
    for i = 1, RING_STEPS do
        local l, g = ringLines[i], ringGlows[i]
        if i <= n and alpha > 0 then
            local a = from + (i - 1) / RING_STEPS * 2 * math.pi
            local b = from + math.min(i / RING_STEPS, share) * 2 * math.pi
            hx, hy = x + math.sin(b) * RING_R, y + math.cos(b) * RING_R
            for _, line in ipairs({ l, g }) do
                line:SetStartPoint("CENTER", ringFrame, math.sin(a) * RING_R, math.cos(a) * RING_R)
                line:SetEndPoint("CENTER", ringFrame, hx - x, hy - y)
                line:Show()
            end
            l:SetVertexColor(litColor[1], litColor[2], litColor[3], alpha)
            g:SetVertexColor(litColor[1], litColor[2], litColor[3], 0.25 * alpha)
        else
            l:Hide()
            g:Hide()
        end
    end
    return hx, hy
end

-- (the water round the bobber at (x, y): rings spreading out from under
-- it, each fading as it goes; strength: how much shows; kick: a splash's,
-- bigger and brighter; its colour between the water's and color)
local function DrawRipples(x, y, since, strength, color, kick)
    kick = kick or 0
    local r = (WATER_COLOR[1] + color[1]) / 2
    local g = (WATER_COLOR[2] + color[2]) / 2
    local b = (WATER_COLOR[3] + color[3]) / 2
    for i, ring in ipairs(ripples) do
        local q = ((since + (i - 1) * RIPPLE_PERIOD / RIPPLES) % RIPPLE_PERIOD) / RIPPLE_PERIOD
        local size = BOBBER * (1.3 + (1.9 + 1.5 * kick) * q)
        At(ring, x, y)
        ring:SetSize(size, size)
        ring:SetVertexColor(r, g, b)
        ring:SetAlpha(strength * (0.4 + 0.4 * kick) * (1 - q))
    end
end

-- (a burst at (x, y): q 0 to 1 of the way)
local function DrawSplash(x, y, q, color)
    if q <= 0 or q >= 1 then
        splash:SetAlpha(0)
        return
    end
    local size = BOBBER * (0.8 + 3 * Ease(q))
    At(splash, x, y)
    splash:SetSize(size, size)
    splash:SetVertexColor(color[1], color[2], color[3])
    splash:SetAlpha(0.95 * (1 - q))
end

-- (the game's bobber in it: a model scene of ours over the water, its
-- camera fitted to the model once it's loaded)
local scene, actor, modelReady
do
    local ok = pcall(function()
        scene = CreateFrame("ModelScene", nil, bobber)
        scene:SetSize(BOBBER * 1.5, BOBBER * 1.5)
        scene:SetPoint("CENTER", 0, 2)
        scene:SetFrameLevel(bobber:GetFrameLevel() + 1)
        scene:Hide()
        actor = scene:CreateActor()
    end)
    if not ok then scene, actor = nil, nil end
end

local function FitModel()
    local x0, y0, z0, x1, y1, z1 = actor:GetActiveBoundingBox()
    if not (x0 and x1) then return false end
    local size = math.max(x1 - x0, y1 - y0, z1 - z0, 0.01)
    local d = size * 0.5 / math.tan(MODEL_FOV / 2) * 1.2
    local ce, se = math.cos(MODEL_VIEW), math.sin(MODEL_VIEW)
    scene:SetCameraFieldOfView(MODEL_FOV)
    scene:SetCameraNearClip(0.01)
    scene:SetCameraFarClip(100)
    scene:SetCameraPosition((x0 + x1) / 2 - d * ce, (y0 + y1) / 2, (z0 + z1) / 2 + d * se)
    -- (forward, right, up: looking along +x, down a little)
    scene:SetCameraOrientationByAxisVectors(ce, 0, -se, 0, -1, 0, se, 0, ce)
    pcall(function()
        scene:SetLightVisible(true)
        scene:SetLightDirection(0.4, -0.5, -0.75)
        scene:SetLightAmbientColor(0.7, 0.7, 0.7)
        scene:SetLightDiffuseColor(0.9, 0.88, 0.82)
    end)
    return true
end

local function ModelLoaded()
    if modelReady or not pcall(function() modelReady = FitModel() end) then return end
    if modelReady and scene.wanted then
        bobber.icon:SetTexture(WATER_ART)
        scene:Show()
    end
end

-- (the bobber: the game's over the water, else ours)
local function ShowBobberModel(on)
    if not scene then on = false end
    if on and not modelReady and not scene.asked then
        scene.asked = true
        pcall(function()
            actor:SetScript("OnModelLoaded", ModelLoaded)
            actor:SetModelByFileID(BOBBER_MODEL)
        end)
        ModelLoaded()
    end
    local model = on and modelReady
    if scene then
        scene.wanted = on
        scene:SetShown(model or false)
    end
    if on then
        bobber.icon:SetTexture(model and WATER_ART or BOBBER_ART)
        bobber.icon:SetTexCoord(0, 1, 0, 1)
    end
    if actor then pcall(actor.SetDesaturation, actor, 0) end
end

local function DrawBobber(x, y, alpha, scale)
    bobber:SetScale(math.max(0.01, scale or 1))
    At(bobber, x, y)
    bobber:SetAlpha(alpha)
    bobber:SetShown(alpha > 0)
    if actor and scene:IsShown() then pcall(actor.SetAlpha, actor, alpha) end
end

---------------------------------------------------------------------------
-- The water's fish: what this water holds (the Fish Collection's index,
-- Book.lua: B.Here), seen from above under the surface, swimming round the
-- bobber; now and then one noticing the bait, nosing in to it, nudging it
-- and turning away. One you've caught in its colours, its icon on its back;
-- one you haven't a dark shape. Gone off in a flash when the cast ends.
---------------------------------------------------------------------------
local SCHOOL, FISH_LEN, FISH_ICON_SIZE = 8, 24, 15
local SWIM_R, SWIM_EDGE = 40, 62        -- (how far out they swim: least, most)
local NOTICE_IN, NOTICE_HOLD, NOTICE_OUT = 1.4, 0.8, 1.2
local DEEP = { 0.5, 0.64, 0.74 }        -- (one not caught yet: a pale shape under the water)
-- (wider than the bar: a line reaching past its frame isn't drawn, and they
-- swim out past its right edge)
local fishFrame = CreateFrame("Frame", nil, bar)
fishFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", -20, 20)
fishFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 120, -40)
fishFrame:SetFrameLevel(bar:GetFrameLevel())
local school = {}

local function NewFish()
    local f = {}
    f.shadow = fishFrame:CreateLine(nil, "BACKGROUND")
    f.shadow:SetTexture(CIRCLE_MASK)
    f.shadow:SetThickness(10)
    f.shadow:SetVertexColor(0, 0, 0, 0.35)
    f.tail = fishFrame:CreateLine(nil, "BORDER")
    f.tail:SetTexture(CIRCLE_MASK)
    f.tail:SetThickness(7)
    f.body = fishFrame:CreateLine(nil, "BORDER", nil, 1)
    f.body:SetTexture(CIRCLE_MASK)
    f.body:SetThickness(9)
    f.icon = fishFrame:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(FISH_ICON_SIZE, FISH_ICON_SIZE)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = fishFrame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(mask)
    return f
end

local function ShowFish(f, shown)
    for _, part in ipairs({ f.shadow, f.tail, f.body, f.icon }) do part:SetShown(shown) end
end

local function HideSchool()
    for _, f in ipairs(school) do ShowFish(f, false) end
end

-- (the school for a cast: the likeliest fish here, a few dark shapes when
-- the water's not known)
local function MakeSchool(s)
    local here = F.Book and F.Book.Here and F.Book.Here() or {}
    local caught = F.Collection and F.Collection() or {}
    local PC = IF.Interface and IF.Interface.PlayerCast
    s.school = {}
    local n = math.min(SCHOOL, #here > 0 and #here or 3)
    local start = math.random() * 2 * math.pi
    for i = 1, n do
        local f = school[i] or NewFish()
        school[i] = f
        local fish = here[i]
        f.id = fish and fish.id
        f.caught = f.id and caught[f.id] ~= nil
        local color = DEEP
        if f.caught then
            local icon = F.Book.Icon(f.id)
            f.icon:SetTexture(icon)
            local ok, c = pcall(function() return PC and PC.IconColor and PC.IconColor(icon) end)
            color = ok and c and { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7 } or { 0.35, 0.45, 0.5 }
        end
        f.color = color
        -- (spread round it, each at its own distance, half each way round)
        f.theta = start + (i - 1) * 2 * math.pi / n + 0.4 * (math.random() - 0.5)
        f.spin = (i % 2 == 0 and -1 or 1) * (0.3 + 0.3 * math.random())
        f.r = SWIM_R + (SWIM_EDGE - SWIM_R - 6) * ((i - 1) % 3) / 2 + 3 * math.random()
        f.phase = math.random() * 2 * math.pi
        f.heading = nil
        s.school[i] = f
    end
    for i = #s.school + 1, #school do ShowFish(school[i], false) end
    s.noticeAt, s.notice, s.lastNow = nil, nil, nil
end

-- (how far into its noticing of the bait a fish is: 0 not, 1 at it)
local function Noticing(s, now)
    if not s.notice then return 0 end
    local t = now - s.notice.at
    if t < NOTICE_IN then return Ease(t / NOTICE_IN) end
    if t < NOTICE_IN + NOTICE_HOLD then return 1 end
    return 1 - Ease((t - NOTICE_IN - NOTICE_HOLD) / NOTICE_OUT)
end

-- (the bait nudged by the one at it: 0 to 1, a few taps)
local function Nudge(s, now)
    if not s.notice then return 0 end
    local t = now - s.notice.at - NOTICE_IN
    if t < 0 or t > NOTICE_HOLD then return 0 end
    return math.max(0, math.sin(t / NOTICE_HOLD * 3 * math.pi))
end

-- (the school round (cx, cy): since, the time it's been in the water;
-- gone, 0 to 1 the way off it's swum (the cast ended))
local function DrawSchool(s, now, cx, cy, since, gone)
    if not s.school then return end
    local dt = s.lastNow and math.min(0.1, now - s.lastNow) or 0
    s.lastNow = now
    gone = gone or 0
    -- (one noticing the bait, now and then; none once it's ending)
    if gone == 0 then
        if s.notice and now - s.notice.at > NOTICE_IN + NOTICE_HOLD + NOTICE_OUT then s.notice = nil end
        s.noticeAt = s.noticeAt or (now + 1.5 + 1.5 * math.random())
        if not s.notice and now >= s.noticeAt then
            s.notice = { at = now, fish = s.school[math.random(#s.school)] }
            s.noticeAt = now + NOTICE_IN + NOTICE_HOLD + NOTICE_OUT + 1 + 3 * math.random()
        end
    end
    local come = Ease(since / 1.6)
    -- (swimming off: from however much of it showed)
    if gone == 0 then s.schoolAlpha = Clamp(since / 1.2) end
    local alpha = (s.schoolAlpha or 0) * (1 - Clamp(gone * 1.6))
    for i, f in ipairs(s.school) do
        local a = s.notice and s.notice.fish == f and Noticing(s, now) or 0
        f.theta = f.theta + f.spin * (1 - 0.85 * a) * (1 + 2.5 * gone) * dt
        local r = f.r + 5 * math.sin(now * 0.7 + f.phase)
        r = Lerp(r, RING_R + 9, a) + 30 * (1 - come) + 70 * Ease(gone)
        local x, y = cx + r * math.cos(f.theta), cy + r * math.sin(f.theta)
        -- (its heading: along its way, turned to the bait as it noses in)
        local vx, vy = x - (f.x or x), y - (f.y or y)
        if vx * vx + vy * vy < 1e-4 then
            local tangent = f.theta + (f.spin > 0 and 1 or -1) * math.pi / 2
            vx, vy = math.cos(tangent), math.sin(tangent)
        end
        local move = math.atan2(vy, vx)
        local bait = math.atan2(cy - y, cx - x)
        local want = math.atan2((1 - a) * math.sin(move) + a * math.sin(bait), (1 - a) * math.cos(move) + a * math.cos(bait))
        if not f.heading then
            f.heading = want
        else
            local d = (want - f.heading + math.pi) % (2 * math.pi) - math.pi
            f.heading = f.heading + d * math.min(1, dt * 6)
        end
        f.x, f.y = x, y
        local hx, hy = math.cos(f.heading), math.sin(f.heading)
        local half = FISH_LEN / 2
        local nx, ny, bx, by = x + hx * half, y + hy * half, x - hx * half, y - hy * half
        f.body:SetStartPoint("BOTTOMLEFT", bar, bx, by)
        f.body:SetEndPoint("BOTTOMLEFT", bar, nx, ny)
        f.shadow:SetStartPoint("BOTTOMLEFT", bar, bx + 3, by - 4)
        f.shadow:SetEndPoint("BOTTOMLEFT", bar, nx + 3, ny - 4)
        -- (its tail beating, faster as it noses in)
        local beat = math.sin(now * (6 + 6 * a + 6 * gone) + f.phase) * 0.55
        local th = f.heading + math.pi + beat
        f.tail:SetStartPoint("BOTTOMLEFT", bar, bx + hx * 2, by + hy * 2)
        f.tail:SetEndPoint("BOTTOMLEFT", bar, bx + math.cos(th) * 10, by + math.sin(th) * 10)
        local c = f.color
        local deep = f.caught and 0.85 or 0.4
        f.body:SetVertexColor(c[1], c[2], c[3], deep * alpha)
        f.tail:SetVertexColor(c[1], c[2], c[3], deep * 0.8 * alpha)
        f.shadow:SetVertexColor(0, 0, 0, 0.3 * alpha)
        f.icon:ClearAllPoints()
        f.icon:SetPoint("CENTER", bar, "BOTTOMLEFT", x, y)
        f.icon:SetAlpha(0.95 * alpha)
        ShowFish(f, alpha > 0)
        f.icon:SetShown(alpha > 0 and f.caught)
    end
end

---------------------------------------------------------------------------
-- The scene: S = { phase, at, ... }, or nil
---------------------------------------------------------------------------
local S

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

-- (the lure on the pole, else the best one to put on)
local function LureLine()
    local ok, has, left = pcall(GetWeaponEnchantInfo)
    if ok and has and not Secret(has) and not Secret(left) and type(left) == "number" then
        local m = math.max(1, math.floor(left / 60000 + 0.5))
        return ("Lure on  ·  %d min"):format(m), LURE_COLOR
    end
    local id = F.Lure and F.Lure()
    if id then
        local get = C_Item and C_Item.GetItemNameByID or GetItemInfo
        local name = get and get(id) or "a lure"
        return ("No lure  ·  %s twice: %s"):format(IF.GlyphText and IF.GlyphText("PADRTRIGGER", 14) or "R2", name),
            GREY
    end
    return "No lure", GREY
end

local function HideCatch()
    for _, it in ipairs(items) do it:Hide() end
    missIcon:Hide()
    tipFlash:SetAlpha(0)
    glow:SetAlpha(0)
    label:SetAlpha(0)
    title:SetAlpha(0)
end

local FadeNative
local function End()
    S = nil
    HideCatch()
    HideSchool()
    bar:Hide()
    if FadeNative then FadeNative() end
end

local function Begin(phase)
    -- (a catch still flying to the stringer: there now)
    if S and S.phase == "catch" and F.RackHit then F.RackHit() end
    S = { phase = phase, at = GetTime(), bx = TIP_X, by = TIP_Y }
    Place()
    HideCatch()
    HideSchool()
    splash:SetAlpha(0)
    bobber.icon:SetDesaturated(false)
    bobber.ring:SetVertexColor(1, 1, 1)
    header:SetText("")
    header:SetAlpha(1)
    lureText:SetAlpha(1)
    local text, color = LureLine()
    lureText:SetText(text)
    lureText:SetTextColor(color[1], color[2], color[3])
    bar:SetAlpha(0)
    bar:Show()
    -- (the game's cast bar faded at once, not a moment on: it'd flash)
    if FadeNative then FadeNative() end
    return S
end

-- (a cast's times, read whole: start and end, ms; else nil)
local function Times(startMs, endMs)
    if Secret(startMs) or Secret(endMs) or type(startMs) ~= "number" or type(endMs) ~= "number"
        or endMs <= startMs then
        return nil
    end
    return startMs, endMs
end

local function SetLitColor(texture, color)
    local PC = IF.Interface and IF.Interface.PlayerCast
    local ok, c = pcall(function() return PC and PC.IconColor and PC.IconColor(texture) end)
    if color then
        c = color
    elseif ok and c then
        c = { c[1] + (1 - c[1]) * 0.25, c[2] + (1 - c[2]) * 0.25, c[3] + (1 - c[3]) * 0.25 }
    else
        c = LIT_COLOR
    end
    litColor = c
    for i = 1, SEGMENTS do
        lits[i]:SetVertexColor(c[1], c[2], c[3], 1)
        litGlows[i]:SetVertexColor(c[1], c[2], c[3], 0.25)
    end
    spark:SetVertexColor(c[1], c[2], c[3])
end

-- Fishing cast: the bobber thrown out
function F.BarCast(startMs, endMs)
    local s = Begin("fishing")
    s.startMs, s.endMs = Times(startMs, endMs)
    ShowBobberModel(true)
    SetLitColor(BOBBER_ART, BOBBER_COLOR)
    MakeSchool(s)
end

-- The channel's end: waiting a moment for what came of it
function F.BarStop()
    if S and S.phase == "fishing" then
        S.phase, S.waitUntil = "waiting", GetTime() + WAIT
    end
end

-- A catch: { items = { { name, icon, quality, count, new }, ... } }
function F.BarCatch(catch)
    if not (catch and catch.items and #catch.items > 0) then return end
    local from = S and { S.bx, S.by } or { BOB_X, BOB_Y }
    local s = S and S.phase ~= "spell" and S or Begin("catch")
    s.phase, s.at, s.from = "catch", GetTime(), from
    bar:SetAlpha(1)
    local list = {}
    for _, item in ipairs(catch.items) do list[#list + 1] = item end
    table.sort(list, function(a, b)
        if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
        return (a.count or 0) > (b.count or 0)
    end)
    local best = list[1]
    s.color = QualityColor(best.quality)
    s.rare = (best.quality or 0) >= RARE
    s.hold = s.rare and RARE_HOLD or CATCH_HOLD
    s.count = math.min(#list, MAX_ITEMS)
    -- (the row: the best first, the rest after it, all centred)
    local wide = BIG + (s.count - 1) * (SMALL + ITEM_GAP)
    local x = ROW_X - wide / 2
    for i = 1, s.count do
        local it, item = Item(i), list[i]
        local size = i == 1 and BIG or SMALL
        local c = QualityColor(item.quality)
        it.id, it.size, it.target, it.arrived = item.id, size, nil, nil
        it.icon:SetTexture(item.icon or 134400)
        it.ring:SetVertexColor(c[1], c[2], c[3])
        it.count:SetText((item.count or 1) > 1 and item.count or "")
        it.toX, it.toY = x + size / 2, ROW_Y
        x = x + size + ITEM_GAP
        it:SetAlpha(0)
        it:Show()
    end
    for i = s.count + 1, #items do items[i]:Hide() end
    glow:SetVertexColor(s.color[1], s.color[2], s.color[3])
    if s.rare then
        label:SetText("RARE CATCH")
        label:SetTextColor(s.color[1], s.color[2], s.color[3])
    elseif best.new then
        label:SetText("NEW CATCH")
        label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        label:SetText("CAUGHT")
        label:SetTextColor(GREY[1], GREY[2], GREY[3])
    end
    title:SetText((best.name or "") .. ((best.count or 1) > 1 and ("  x" .. best.count) or ""))
    title:SetTextColor(s.color[1], s.color[2], s.color[3])
    At(label, ROW_X, ROW_Y + BIG / 2 + 14)
    At(title, ROW_X, ROW_Y - BIG / 2 - 16)
end

-- A miss: "escaped" (the fish got away) or "early" (nothing hooked yet),
-- the same scene but its words
function F.BarMiss(kind)
    local from = S and { S.bx, S.by } or { BOB_X, BOB_Y }
    local s = S and S.phase ~= "spell" and S or Begin("miss")
    s.phase, s.at, s.from = "miss", GetTime(), from
    s.hold = MISS_HOLD
    HideCatch()
    label:SetText("MISSED")
    label:SetTextColor(MISS_TEXT[1] * 0.8, MISS_TEXT[2] * 0.8, MISS_TEXT[3] * 0.8)
    title:SetText(kind == "early" and "Nothing on the line yet" or "The fish got away")
    title:SetTextColor(MISS_TEXT[1], MISS_TEXT[2], MISS_TEXT[3])
    At(label, ROW_X, ROW_Y + BIG / 2 + 14)
    At(title, ROW_X, ROW_Y - BIG / 2 - 16)
    -- (the fish that got away; nothing hooked: the bobber, bare)
    local bare = kind == "early"
    missIcon.icon:SetTexture(bare and BOBBER_ART or FISH_ICON)
    if bare then
        missIcon.icon:SetTexCoord(0, 1, 0, 1)
    else
        missIcon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    missIcon:SetAlpha(0)
    missIcon:Show()
end

-- Another cast while the fishing view is on (a lure put on)
function F.BarSpell(name, icon, startMs, endMs)
    local s = Begin("spell")
    s.startMs, s.endMs = Times(startMs, endMs)
    ShowBobberModel(false)
    bobber.icon:SetTexture(icon or 134400)
    bobber.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not pcall(header.SetText, header, name) then header:SetText("") end
end

function F.BarSpellDone()
    if S and S.phase == "spell" and not S.outAt then S.outAt = GetTime() end
end

---------------------------------------------------------------------------
-- Each frame, by phase
---------------------------------------------------------------------------
local SETTLE = 0.6                      -- (landed: the bobbing and swaying coming in)
local function Fishing(s, now, t)
    -- (thrown: the bobber along the line's own curve from the tip, the line
    -- drawn out behind it; landed: bobbing, the line swaying)
    local u = t / FLIGHT
    if u < 1 then
        local e = Ease(u)
        s.bx, s.by = Lerp(TIP_X, BOB_X, e), Lerp(TIP_Y, BOB_Y, e) - SAG * 4 * e * (1 - e)
        DrawLine(TIP_X, TIP_Y, BOB_X, BOB_Y, SAG, LINE_COLOR, 0.8, e)
    else
        local settle = Ease((t - FLIGHT) / SETTLE)
        s.bx, s.by = BOB_X, BOB_Y + math.sin((t - FLIGHT) * 2.2) * 2.5 * settle - 2.5 * Nudge(s, now)
        s.sag = SAG + math.sin(now * 0.9) * SWAY * settle
        -- (the line up to the time ring round the bobber, not into it: the
        -- curve's the same either way along)
        s.exitU = ExitU(s.bx, s.by, s.sag)
        DrawLine(TIP_X, TIP_Y, s.bx, s.by, s.sag, LINE_COLOR, 0.8, 1 - s.exitU)
    end
    DrawBobber(s.bx, s.by, 1)
    local landed = u >= 1
    DrawSplash(BOB_X, BOB_Y, landed and (t - FLIGHT) / 0.5 or 0, LINE_COLOR)
    DrawRipples(BOB_X, BOB_Y, t - FLIGHT, landed and Clamp((t - FLIGHT) / 0.4) or 0, LINE_COLOR,
        landed and math.max(Clamp(1 - (t - FLIGHT) / 0.8), 0.35 * Nudge(s, now)) or 0)
    if landed then DrawSchool(s, now, BOB_X, BOB_Y, t - FLIGHT, 0) end
    -- (the time gone, while it's waited for: one run, from the tip along
    -- the line to where it meets the bobber's ring, then round it; times
    -- kept secret: none)
    if landed and s.phase == "fishing" and s.startMs then
        local gone = Clamp((now * 1000 - s.startMs) / (s.endMs - s.startMs))
        local sag = s.sag or SAG
        local u0 = s.exitU or ExitU(s.bx, s.by, sag)
        local ex, ey = CurveAt(s.bx, s.by, TIP_X, TIP_Y, sag, u0)
        local exit = math.atan2(ex - s.bx, ey - s.by)
        local ringLen = 2 * math.pi * RING_R
        local lineShare = (BOB_X - TIP_X) * (1 - u0) / (ringLen + (BOB_X - TIP_X) * (1 - u0))
        local alpha = Clamp((t - FLIGHT) / 0.3)
        local along = Clamp(gone / lineShare)
        -- (the tip lit as the time sets off from it)
        tip:SetVertexColor(litColor[1], litColor[2], litColor[3], 1)
        tip:SetSize(gone > 0 and 8 or 6, gone > 0 and 8 or 6)
        DrawLit(TIP_X, TIP_Y, s.bx, s.by, sag, along, alpha, 0, 1 - u0)
        local round = Clamp((gone - lineShare) / (1 - lineShare))
        local hx, hy = DrawRing(s.bx, s.by, round, alpha, exit)
        if along >= 1 then
            spark:ClearAllPoints()
            spark:SetPoint("CENTER", bar, "BOTTOMLEFT", hx, hy)
            spark:SetAlpha(round < 1 and alpha * (0.75 + 0.25 * math.sin(now * 9)) or 0)
        end
    else
        DrawLit(TIP_X, TIP_Y, s.bx, s.by, s.sag or SAG, 0, 0)
        DrawRing(0, 0, 0, 0)
        tip:SetVertexColor(1, 1, 1, 1)
        tip:SetSize(6, 6)
    end
    bar:SetAlpha(Clamp(t / IN_TIME))
    if s.phase == "waiting" and now > s.waitUntil then
        s.phase, s.at, s.from = "reel", now, { s.bx, s.by }
    end
end

local function Reel(s, now, t)
    HideLit()
    -- (nothing came of it: the bobber back to the tip, the line with it)
    local p = Ease(t / REEL)
    s.bx, s.by = Lerp(s.from[1], TIP_X, p), Lerp(s.from[2], TIP_Y, p)
    DrawLine(TIP_X, TIP_Y, s.bx, s.by, SAG * (1 - p), LINE_COLOR, 0.8 * (1 - p))
    DrawBobber(s.bx, s.by, 1 - p, 1 - 0.4 * p)
    DrawRing(0, 0, 0, 0)
    DrawRipples(BOB_X, BOB_Y, 0, 0, LINE_COLOR)
    DrawSchool(s, now, BOB_X, BOB_Y, 99, Clamp(t / 0.7))
    if t > REEL then
        local f = (t - REEL) / (OUT / 2)
        bar:SetAlpha(1 - Clamp(f))
        if f >= 1 then End() end
    end
end

local PULL = 0.4                        -- (a catch: the line reeled in to the tip)
local function Catch(s, now, t)
    HideLit()
    local c, fx, fy = s.color, s.from[1], s.from[2]
    -- (a splash where it bit; the line snapping taut, lit in the catch's
    -- colour, and reeled in, the bobber along it to the tip)
    DrawSplash(fx, fy, t / 0.6, c)
    DrawRipples(fx, fy, t, Clamp(1 - t / 1.2), c, Clamp(1 - t / 0.9))
    DrawSchool(s, now, BOB_X, BOB_Y, 99, Clamp(t / 0.7))
    local k = Clamp(t / 0.15)
    local lit = { Lerp(LINE_COLOR[1], c[1], k), Lerp(LINE_COLOR[2], c[2], k), Lerp(LINE_COLOR[3], c[3], k) }
    local r = Ease((t - 0.1) / PULL)
    local bx, by = Lerp(fx, TIP_X, r), Lerp(fy, TIP_Y, r)
    DrawLine(TIP_X, TIP_Y, bx, by, SAG * (1 - k), lit, r < 1 and 0.9 or 0)
    DrawBobber(bx, by, Clamp(1 - (t - 0.1 - PULL * 0.7) / (PULL * 0.3)), 1 - 0.3 * r)
    DrawRing(0, 0, 0, 0)
    header:SetAlpha(Clamp(1 - t / 0.4))
    lureText:SetAlpha(Clamp(1 - t / 0.4))
    -- (landed at the tip: a flash there, then the catch out of it, each up
    -- to its spot in the row)
    local landed = 0.1 + PULL
    At(tipFlash, TIP_X, TIP_Y)
    local q = Clamp((t - landed) / 0.5)
    tipFlash:SetSize(BOBBER * (0.6 + 2 * Ease(q)), BOBBER * (0.6 + 2 * Ease(q)))
    tipFlash:SetVertexColor(c[1], c[2], c[3])
    tipFlash:SetAlpha(q > 0 and 0.9 * (1 - q) or 0)
    for i = 1, s.count do
        local it = items[i]
        local p = Ease((t - landed - (i - 1) * 0.1) / 0.55)
        local x = Lerp(TIP_X, it.toX, p)
        local y = Lerp(TIP_Y, it.toY, p) + 50 * 4 * p * (1 - p)
        it:SetScale(0.4 + 0.6 * p)
        At(it, x, y)
        it:SetAlpha(p > 0 and Clamp(p * 1.6) or 0)
    end
    -- (a rare one: a glow beating behind the best)
    local first = items[1]
    if s.rare and first then
        At(glow, first.toX, first.toY)
        glow:SetAlpha(Clamp((t - landed - 0.45) / 0.3) * (0.45 + 0.2 * math.sin(t * 4)))
    end
    local held = t - s.hold
    label:SetAlpha(Clamp((t - landed - 0.4) / 0.3) * Clamp(1 - held / 0.3))
    title:SetAlpha(Clamp((t - landed - 0.5) / 0.3) * Clamp(1 - held / 0.3))
    if held < 0 then return end
    -- (held: each flying on to its place on the stringer, shrinking to its
    -- size there; one not on it fading)
    local all = true
    for i = 1, s.count do
        local it = items[i]
        if it.target == nil then
            local x, y
            if F.RackSpot then x, y = F.RackSpot(it.id) end
            it.target = x and y and { x - bar:GetLeft(), y - bar:GetBottom() } or false
        end
        local p = Clamp((held - (i - 1) * FLY_STAGGER) / FLY)
        if it.target then
            local e = p * p * (3 - 2 * p)
            local tx, ty = it.target[1], it.target[2]
            it:SetScale(Lerp(1, (F.RACK_ICON or 22) / it.size, e))
            At(it, Lerp(it.toX, tx, e), Lerp(it.toY, ty, e) + 40 * 4 * e * (1 - e))
            it:SetAlpha(p < 1 and 1 or 0)
            if p >= 1 and not it.arrived then
                it.arrived = true
                if F.RackHit then F.RackHit(it.id) end
            end
        else
            it:SetAlpha(1 - p)
        end
        if p < 1 then all = false end
    end
    glow:SetAlpha(glow:GetAlpha() * Clamp(1 - held / 0.3))
    if all then
        if F.RackHit then F.RackHit() end
        End()
    end
end

local function Miss(s, now, t)
    HideLit()
    -- (the line slack and grey, the bobber sinking, a last ring)
    local fx, fy = s.from[1], s.from[2]
    local sink = Ease(t / 0.8)
    s.by = fy - 14 * sink
    DrawLine(TIP_X, TIP_Y, fx, s.by, Lerp(SAG, 46, Ease(t / 0.6)), MISS_LINE, 0.75 * (1 - 0.5 * sink))
    bobber.icon:SetDesaturated(true)
    if actor then pcall(actor.SetDesaturation, actor, 1) end
    DrawBobber(fx, s.by, 1 - sink)
    DrawRipples(fx, fy, t, Clamp(1 - t / 1.2), MISS_LINE, Clamp(1 - t / 0.9) * 0.6)
    DrawSchool(s, now, BOB_X, BOB_Y, 99, Clamp(t / 0.7))
    DrawRing(0, 0, 0, 0)
    DrawSplash(0, 0, 0, MISS)
    header:SetAlpha(Clamp(1 - t / 0.4))
    lureText:SetAlpha(Clamp(1 - t / 0.4))
    -- (what got away rising from the bobber to the row, wobbling; then the
    -- cross stamped on it)
    local p = Ease((t - 0.1) / 0.5)
    missIcon:SetScale(0.5 + 0.5 * p)
    At(missIcon, Lerp(fx, ROW_X, p) + 4 * math.sin(t * 14) * (1 - p), Lerp(fy, ROW_Y, p) + 30 * 4 * p * (1 - p))
    missIcon:SetAlpha(Clamp(p * 1.6))
    local c = Clamp((t - 0.6) / 0.2)
    missIcon.cross:SetAlpha(c)
    missIcon.cross:SetScale(1 + 0.8 * (1 - c))
    label:SetAlpha(Clamp((t - 0.45) / 0.3))
    title:SetAlpha(Clamp((t - 0.55) / 0.3))
    local f = (t - s.hold) / OUT
    bar:SetAlpha(1 - Clamp(f))
    if f >= 1 then End() end
end

local function Spell(s, now, t)
    HideLit()
    -- (the line drawn out from the tip as the cast fills, its icon at its end)
    local p = s.startMs and Clamp((now * 1000 - s.startMs) / (s.endMs - s.startMs)) or 1
    if s.outAt then p = 1 end
    s.bx, s.by = Lerp(TIP_X, BOB_X, p), TIP_Y
    DrawLine(TIP_X, TIP_Y, s.bx, s.by, 0, GOLD, 0.85)
    DrawBobber(s.bx, s.by, 1, 0.85)
    DrawRing(0, 0, 0, 0)
    DrawRipples(0, 0, 0, 0, GOLD)
    DrawSplash(0, 0, 0, GOLD)
    header:SetAlpha(1)
    lureText:SetAlpha(0)
    local f = s.outAt and (now - s.outAt) / (OUT / 2) or 0
    bar:SetAlpha(Clamp(t / IN_TIME) * (1 - Clamp(f)))
    if f >= 1 then End() end
end

local PHASES = { fishing = Fishing, waiting = Fishing, reel = Reel, catch = Catch, miss = Miss, spell = Spell }

bar:SetScript("OnUpdate", function()
    if not S then
        bar:Hide()
        return
    end
    local now = GetTime()
    if S.phase == "fishing" or S.phase == "spell" then lureText:SetAlpha(S.phase == "fishing" and 1 or 0) end
    local ok, err = pcall(PHASES[S.phase], S, now, now - S.at)
    if not ok then
        End()
        IF.Print("Fishing: the fishing bar stopped a cast after an error: " .. tostring(err))
    end
end)

---------------------------------------------------------------------------
-- The game's: the casts, the catch, the miss
---------------------------------------------------------------------------
local function On()
    return IF.db and F.Settings().bar and not F.EditMode() or false
end

local function IsFishing(spellID, name)
    if not Secret(spellID) and spellID == FISHING then return true end
    if Secret(name) or type(name) ~= "string" then return false end
    local fishing = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING)
    return fishing ~= nil and name == fishing
end

-- (ours: Fishing; with the fishing view on, any cast)
local function Ours(kind, spellID, name)
    if not On() then return false end
    if kind == "channel" then return IsFishing(spellID, name) end
    return F.ViewActive and F.ViewActive() or false
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    events:RegisterUnitEvent(e, "player")
end
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, _, _, startMs, endMs, _, _, spellID = UnitChannelInfo("player")
        if Ours("channel", spellID, name) then F.BarCast(startMs, endMs) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        F.BarStop()
    elseif event == "UNIT_SPELLCAST_START" then
        local name, _, texture, startMs, endMs, _, _, _, spellID = UnitCastingInfo("player")
        if Ours("cast", spellID, name) then F.BarSpell(name, texture, startMs, endMs) end
    else
        F.BarSpellDone()
    end
end)

F.OnCatch(function(catch)
    if On() then F.BarCatch(catch) end
end)
F.OnEscape(function(kind)
    if On() then F.BarMiss(kind) end
end)

-- (the cast line of the Immersion module leaves ours to us; without it,
-- the game's casting bar faded while ours shows)
IF.OnLogin(function()
    local PC = IF.Interface and IF.Interface.PlayerCast
    if PC and PC.Claim then PC.Claim(Ours) end
end)
local faded = false
FadeNative = function()
    if IF.Interface then return end
    local want = bar:IsShown() or (F.InMode and F.InMode()) or false
    if want ~= faded then
        faded = want
        IF.Focus.Fade(_G.PlayerCastingBarFrame, want)
    end
end
F.Watcher("fishing bar", 0.1, FadeNative)
F.OnMode(function() FadeNative() end)

-- Something showing on it now (a cast, its catch, its miss)
function F.BarBusy()
    return bar:IsShown()
end

function F.ApplyBar()
    if not On() then End() end
end

-- /if fishshow [miss | early | rare | cancel]: a cast and its end, made up
local SAMPLE = {
    { name = "Raw Brilliant Smallfish", icon = FISH_ICON, quality = 1, count = 2 },
    { name = "Oily Blackmouth", icon = FISH_ICON, quality = 1, count = 1 },
    { name = "Waterlogged Coin", icon = "Interface\\Icons\\INV_Misc_Coin_01", quality = 2, count = 1 },
}
IF.AddCommand("fishshow", function(args)
    local how = args[1]
    if how == "first" then
        return F.FirstCatch({ name = "Raw Brilliant Smallfish", icon = FISH_ICON, quality = 1,
            progress = "Added to your fishing book  ·  13 of 32 fish",
            where = (GetZoneText and GetZoneText() or "") .. "  ·  " .. date("%d %b %Y, %H:%M") })
    end
    local now = GetTime() * 1000
    F.BarCast(now, now + 6000)
    local after = C_Timer and C_Timer.After
    if not after then return end
    if how == "early" then
        after(1.5, function() F.BarMiss("early") end)
        after(4.5, function() F.BarStop() end)
    elseif how == "cancel" then
        after(3, function() F.BarStop() end)
    elseif how == "miss" then
        after(3, function()
            F.BarStop()
            F.BarMiss("escaped")
        end)
    else
        local list = {}
        for i, item in ipairs(SAMPLE) do
            list[i] = { name = item.name, icon = item.icon, quality = item.quality, count = item.count, new = i == 1 }
        end
        if how == "rare" then list[1] = { name = "Keefer's Angelfish", icon = FISH_ICON, quality = 3, count = 1 } end
        after(3, function()
            F.BarStop()
            F.BarCatch({ items = list })
        end)
    end
end, "[miss | early | rare | cancel]: a fishing cast and its end on the fishing bar, made up")
