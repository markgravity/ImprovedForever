-- The fishing bar: each cast of Fishing as a scene on the right of the
-- screen (the fishing view frames you low on the left, View.lua), in
-- place of the cast bar (the Interface module's cast line, PlayerCast.Claim;
-- else the game's, faded).
--   The cast: from the rod's tip (left) the bobber flies out in an arc to
--   its spot (right), the line following it; landed, it bobs, rings
--   spreading round it on the water, the line sagging and swaying; round
--   the bobber a thin ring drains with the time left. Over the tip:
--   "Fishing", your lure (on, how long) or the best one in your bags to put
--   on (R2 twice, Fishing.lua).
--   A catch: a splash of the catch's colour (its best item's quality's),
--   the line snapping taut and lit, then the catch reeled in: each item
--   flying from the bobber along an arc to a row over the line, round in a
--   ring of its quality's colour, the best one first and biggest; over the
--   row CAUGHT, NEW CATCH (first this session) or RARE CATCH (rare and up:
--   a glow beating behind it, held longer), under it the best one's name.
--   A miss: the line going slack and grey, the bobber sinking, "The fish
--   got away". Nothing hooked yet ("No fish are hooked."): a line by the
--   bobber, the cast going on. Cast stopped with nothing come of it: the
--   bobber reeled back in to the tip.
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
local FLIGHT, ARC = 0.65, 80            -- (the cast: how long, how high)
local BOBBER, RING_R, RING_STEPS = 28, 22, 40
local WAIT, REEL, OUT, IN_TIME = 0.9, 0.5, 0.6, 0.25
local CATCH_HOLD, RARE_HOLD, MISS_HOLD, NOTE_HOLD = 3, 4.5, 1.8, 1.8
local RARE = 3                          -- (rare and up)
local ROW_X, ROW_Y = W * 0.55, 165      -- (the catch's row: its middle)
local BIG, SMALL, ITEM_GAP, MAX_ITEMS = 44, 32, 12, 5
local LINE_COLOR = { 0.92, 0.9, 0.82 }
local GOLD, GREY, MISS = { 1, 0.82, 0 }, { 0.62, 0.62, 0.62 }, { 0.55, 0.7, 0.85 }
local LURE_COLOR = { 0.45, 0.85, 0.45 }
local RING = "gamepad-actionbar-circleslot-frame"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAR = "Interface\\Cooldown\\star4"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local FISH_ICON = "Interface\\Icons\\INV_Misc_Fish_02"

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

-- (on the right: from just right of the screen's middle, a bit under it)
local function Place()
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", UIParent:GetWidth() * 0.5 + 30, UIParent:GetHeight() * 0.33)
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
-- (over the tip: "Fishing", the lure)
local header = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormal"), GOLD)
header:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", TIP_X, TIP_Y + 30)
local lureText = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)
lureText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)

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

-- (the bobber, its ripples, its time ring, a splash)
local bobber = Round(bar, BOBBER)
bobber:SetFrameLevel(lineFrame:GetFrameLevel() + 3)
local ripples = {}
for i = 1, 2 do
    local r = bar:CreateTexture(nil, "BORDER")
    r:SetAtlas(RING)
    r:SetBlendMode("ADD")
    r:SetAlpha(0)
    ripples[i] = r
end
local ringFrame = CreateFrame("Frame", nil, bar)
ringFrame:SetAllPoints()
ringFrame:SetFrameLevel(bobber:GetFrameLevel() + 2)
local ringLines = {}
for i = 1, RING_STEPS do
    local l = ringFrame:CreateLine(nil, "OVERLAY")
    l:SetThickness(2)
    l:SetTexture(WHITE)
    l:SetBlendMode("ADD")
    ringLines[i] = l
end
local splash = bar:CreateTexture(nil, "OVERLAY")
splash:SetTexture(STAR)
splash:SetBlendMode("ADD")
splash:SetAlpha(0)

-- (a line by the bobber: nothing hooked yet)
local note = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), MISS)

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
local label = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
local title = Shadowed(bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
title:SetWordWrap(false)
title:SetWidth(W - 40)

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- (the line from (x1, y1) to (x2, y2), sagging by sag at its middle)
local function DrawLine(x1, y1, x2, y2, sag, color, alpha)
    if alpha <= 0 then
        lineFrame:Hide()
        return
    end
    lineFrame:Show()
    local px, py = x1, y1
    for i = 1, SEGMENTS do
        local u = i / SEGMENTS
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

-- (the time ring round the bobber: share left, from its top clockwise)
local function DrawRing(x, y, share, alpha)
    local n = math.floor(RING_STEPS * Clamp(share) + 0.5)
    for i = 1, RING_STEPS do
        local l = ringLines[i]
        if i <= n and alpha > 0 then
            local a, b = (i - 1) / RING_STEPS * 2 * math.pi, i / RING_STEPS * 2 * math.pi
            l:SetStartPoint("BOTTOMLEFT", bar, x + math.sin(a) * RING_R, y + math.cos(a) * RING_R)
            l:SetEndPoint("BOTTOMLEFT", bar, x + math.sin(b) * RING_R, y + math.cos(b) * RING_R)
            l:SetVertexColor(LINE_COLOR[1], LINE_COLOR[2], LINE_COLOR[3], 0.7 * alpha)
            l:Show()
        else
            l:Hide()
        end
    end
end

-- (rings spreading on the water round (x, y), one every period)
local function DrawRipples(x, y, since, strength, color)
    for i, r in ipairs(ripples) do
        local q = ((since + (i - 1) * 0.9) % 1.8) / 1.8
        local size = BOBBER * (1 + 1.6 * q)
        At(r, x, y - 3)
        r:SetSize(size, size * 0.45)
        r:SetVertexColor(color[1], color[2], color[3])
        r:SetAlpha(strength * 0.45 * (1 - q))
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

local function DrawBobber(x, y, alpha, scale)
    bobber:SetScale(math.max(0.01, scale or 1))
    At(bobber, x, y)
    bobber:SetAlpha(alpha)
    bobber:SetShown(alpha > 0)
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
    glow:SetAlpha(0)
    label:SetAlpha(0)
    title:SetAlpha(0)
end

local function End()
    S = nil
    HideCatch()
    note:SetAlpha(0)
    bar:Hide()
end

local function Begin(phase)
    S = { phase = phase, at = GetTime(), bx = TIP_X, by = TIP_Y }
    Place()
    HideCatch()
    note:SetAlpha(0)
    splash:SetAlpha(0)
    bobber.icon:SetDesaturated(false)
    bobber.ring:SetVertexColor(1, 1, 1)
    header:SetText(PROFESSIONS_FISHING or "Fishing")
    header:SetAlpha(1)
    lureText:SetAlpha(1)
    local text, color = LureLine()
    lureText:SetText(text)
    lureText:SetTextColor(color[1], color[2], color[3])
    bar:SetAlpha(0)
    bar:Show()
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

-- Fishing cast: the bobber thrown out
function F.BarCast(startMs, endMs)
    local s = Begin("fishing")
    s.startMs, s.endMs = Times(startMs, endMs)
    local ok, icon = pcall(C_Spell.GetSpellTexture, FISHING)
    bobber.icon:SetTexture(ok and icon or FISH_ICON)
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

-- A miss: "escaped" (the fish got away; the cast over) or "early"
-- (nothing hooked yet: a line by the bobber, the cast going on)
function F.BarMiss(kind)
    if kind == "early" and S and (S.phase == "fishing" or S.phase == "waiting") then
        note:SetText("Nothing on the line yet")
        S.noteAt = GetTime()
        return
    end
    local from = S and { S.bx, S.by } or { BOB_X, BOB_Y }
    local s = S and S.phase ~= "spell" and S or Begin("miss")
    s.phase, s.at, s.from = "miss", GetTime(), from
    s.hold = MISS_HOLD
    HideCatch()
    label:SetText("MISSED")
    label:SetTextColor(GREY[1], GREY[2], GREY[3])
    title:SetText(kind == "early" and "Nothing on the line yet" or "The fish got away")
    title:SetTextColor(MISS[1], MISS[2], MISS[3])
    At(label, ROW_X, ROW_Y + 14)
    At(title, ROW_X, ROW_Y - 8)
end

-- Another cast while the fishing view is on (a lure put on)
function F.BarSpell(name, icon, startMs, endMs)
    local s = Begin("spell")
    s.startMs, s.endMs = Times(startMs, endMs)
    bobber.icon:SetTexture(icon or 134400)
    if not pcall(header.SetText, header, name) then header:SetText("") end
end

function F.BarSpellDone()
    if S and S.phase == "spell" and not S.outAt then S.outAt = GetTime() end
end

---------------------------------------------------------------------------
-- Each frame, by phase
---------------------------------------------------------------------------
local function Fishing(s, now, t)
    -- (thrown: in an arc from the tip; landed: bobbing)
    local u = t / FLIGHT
    local sway = math.sin(now * 0.9) * SWAY
    if u < 1 then
        local e = Ease(u)
        s.bx, s.by = Lerp(TIP_X, BOB_X, e), Lerp(TIP_Y, BOB_Y, e) + ARC * 4 * e * (1 - e)
        DrawLine(TIP_X, TIP_Y, s.bx, s.by, 0, LINE_COLOR, 0.8)
    else
        s.bx, s.by = BOB_X, BOB_Y + math.sin((t - FLIGHT) * 2.2) * 2.5
        DrawLine(TIP_X, TIP_Y, s.bx, s.by, SAG * Ease((u - 1) * 2) + sway, LINE_COLOR, 0.8)
    end
    DrawBobber(s.bx, s.by, 1)
    local landed = u >= 1
    DrawSplash(BOB_X, BOB_Y, landed and (t - FLIGHT) / 0.5 or 0, LINE_COLOR)
    DrawRipples(BOB_X, BOB_Y, t - FLIGHT, landed and Clamp((t - FLIGHT) / 0.4) or 0, LINE_COLOR)
    -- (the time left, while it's waited for)
    local share = 0
    if s.phase == "fishing" then
        share = s.startMs and Clamp((s.endMs - now * 1000) / (s.endMs - s.startMs)) or 1
    end
    DrawRing(s.bx, s.by, share, landed and Clamp((t - FLIGHT) / 0.3) or 0)
    -- (nothing hooked yet: a line by the bobber, fading)
    local n = s.noteAt and now - s.noteAt
    if n and n < NOTE_HOLD then
        At(note, BOB_X, BOB_Y + RING_R + 18 + 6 * Ease(n / 0.4))
        note:SetAlpha(Clamp(n / 0.2) * Clamp((NOTE_HOLD - n) / 0.5))
    else
        note:SetAlpha(0)
    end
    bar:SetAlpha(Clamp(t / IN_TIME))
    if s.phase == "waiting" and now > s.waitUntil then
        s.phase, s.at, s.from = "reel", now, { s.bx, s.by }
    end
end

local function Reel(s, now, t)
    -- (nothing came of it: the bobber back to the tip, the line with it)
    local p = Ease(t / REEL)
    s.bx, s.by = Lerp(s.from[1], TIP_X, p), Lerp(s.from[2], TIP_Y, p)
    DrawLine(TIP_X, TIP_Y, s.bx, s.by, SAG * (1 - p), LINE_COLOR, 0.8 * (1 - p))
    DrawBobber(s.bx, s.by, 1 - p, 1 - 0.4 * p)
    DrawRing(0, 0, 0, 0)
    DrawRipples(BOB_X, BOB_Y, 0, 0, LINE_COLOR)
    note:SetAlpha(0)
    if t > REEL then
        local f = (t - REEL) / (OUT / 2)
        bar:SetAlpha(1 - Clamp(f))
        if f >= 1 then End() end
    end
end

local function Catch(s, now, t)
    local c, fx, fy = s.color, s.from[1], s.from[2]
    -- (a splash; the line snapping taut, lit in the catch's colour, gone)
    DrawSplash(fx, fy, t / 0.7, c)
    DrawRipples(fx, fy, t, Clamp(1 - t / 1.2), c)
    local lit = { Lerp(LINE_COLOR[1], c[1], Clamp(t / 0.15)), Lerp(LINE_COLOR[2], c[2], Clamp(t / 0.15)),
        Lerp(LINE_COLOR[3], c[3], Clamp(t / 0.15)) }
    DrawLine(TIP_X, TIP_Y, fx, fy, SAG * (1 - Ease(t / 0.15)), lit, Clamp(1 - (t - 0.25) / 0.45))
    DrawBobber(fx, fy, Clamp(1 - t / 0.2), 1 + 0.3 * Ease(t / 0.2))
    DrawRing(0, 0, 0, 0)
    note:SetAlpha(0)
    header:SetAlpha(Clamp(1 - t / 0.4))
    lureText:SetAlpha(Clamp(1 - t / 0.4))
    -- (the catch reeled in: each from the bobber up to its spot in the row)
    for i = 1, s.count do
        local it = items[i]
        local p = Ease((t - 0.15 - (i - 1) * 0.1) / 0.55)
        local x = Lerp(fx, it.toX, p)
        local y = Lerp(fy, it.toY, p) + 50 * 4 * p * (1 - p)
        it:SetScale(0.5 + 0.5 * p)
        At(it, x, y)
        it:SetAlpha(p > 0 and Clamp(p * 1.6) or 0)
    end
    -- (a rare one: a glow beating behind the best)
    local first = items[1]
    if s.rare and first then
        At(glow, first.toX, first.toY)
        glow:SetAlpha(Clamp((t - 0.6) / 0.3) * (0.45 + 0.2 * math.sin(t * 4)))
    end
    label:SetAlpha(Clamp((t - 0.55) / 0.3))
    title:SetAlpha(Clamp((t - 0.65) / 0.3))
    local f = (t - s.hold) / OUT
    bar:SetAlpha(1 - Clamp(f))
    if f >= 1 then End() end
end

local function Miss(s, now, t)
    -- (the line slack and grey, the bobber sinking, a last ring)
    local fx, fy = s.from[1], s.from[2]
    local sink = Ease(t / 0.8)
    s.by = fy - 14 * sink
    DrawLine(TIP_X, TIP_Y, fx, s.by, Lerp(SAG, 46, Ease(t / 0.6)), MISS, 0.75 * (1 - 0.5 * sink))
    bobber.icon:SetDesaturated(true)
    DrawBobber(fx, s.by, 1 - sink)
    DrawRipples(fx, fy, t, Clamp(1 - t / 1.2), MISS)
    DrawRing(0, 0, 0, 0)
    DrawSplash(0, 0, 0, MISS)
    note:SetAlpha(0)
    header:SetAlpha(Clamp(1 - t / 0.4))
    lureText:SetAlpha(Clamp(1 - t / 0.4))
    label:SetAlpha(Clamp((t - 0.2) / 0.3))
    title:SetAlpha(Clamp((t - 0.3) / 0.3))
    local f = (t - s.hold) / OUT
    bar:SetAlpha(1 - Clamp(f))
    if f >= 1 then End() end
end

local function Spell(s, now, t)
    -- (the line drawn out from the tip as the cast fills, its icon at its end)
    local p = s.startMs and Clamp((now * 1000 - s.startMs) / (s.endMs - s.startMs)) or 1
    if s.outAt then p = 1 end
    s.bx, s.by = Lerp(TIP_X, BOB_X, p), TIP_Y
    DrawLine(TIP_X, TIP_Y, s.bx, s.by, 0, GOLD, 0.85)
    DrawBobber(s.bx, s.by, 1, 0.85)
    DrawRing(0, 0, 0, 0)
    DrawRipples(0, 0, 0, 0, GOLD)
    DrawSplash(0, 0, 0, GOLD)
    note:SetAlpha(0)
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

-- (the cast line of the Interface module leaves ours to us; without it,
-- the game's casting bar faded while ours shows)
IF.OnLogin(function()
    local PC = IF.Interface and IF.Interface.PlayerCast
    if PC and PC.Claim then PC.Claim(Ours) end
end)
local faded = false
F.Watcher("fishing bar", 0.1, function()
    if IF.Interface then return end
    local want = bar:IsShown()
    if want ~= faded then
        faded = want
        IF.Focus.Fade(_G.PlayerCastingBarFrame, want)
    end
end)

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
