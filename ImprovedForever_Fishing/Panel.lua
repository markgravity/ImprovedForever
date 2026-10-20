-- The fishing session as a fish stringer (Session.lua), in the fishing
-- bar's look (CastBar.lua): while a pole is in hand, down the right of the
-- screen from under the minimap to the bottom (over the Interface module's
-- gamepad bar while it shows; with the fishing view on it's faded, View.lua).
-- A rope tied on the minimap's rim, hanging the whole way down, bowed, a
-- wave running down it, its end swinging; on it, one under another in the
-- order first caught, each thing caught this session on a short string out
-- to the left, round in a ring of its quality's colour (a rare one a glow
-- behind it), its name in that colour and how many beside it. Its end
-- tied off in a knot, frayed, the session's casts, catches, misses and
-- time beside it. On a soft shadow, no box.
-- A catch: the fishing bar's items fly here, each to its place on the rope
-- (F.RackSpot, F.RackHit); without the bar, at once. Each knocked swinging
-- as it lands, its count gold a moment (something new without the bar
-- slides down the rope from its top first), the rope swaying. Faded in and
-- out.
local IF = ImprovedForever
local F = IF.Fishing

local WIDTH, HEAD_H = 300, 10
local FOOT_H, FRAY_LEN = 36, 14         -- (under the rope: its frayed end, the numbers)
local CORD_X = WIDTH - 14               -- (the cord: in from the right)
local CORD_SEGMENTS = 48
local SPACING, STRING, ICON = 46, 18, 32
local TIE_ANGLE = math.rad(40)          -- (the rope tied on the minimap's rim: this far round from its bottom)
local BOW, WAVE, WAVES = 14, 5, 1.3     -- (the rope: bowed left, a wave running down it, how many along it)
local REACH = math.rad(55)              -- (each string out to the left, from straight down)
local MARGIN_X, OVER_BAR, LOW, UNDER_MAP = 24, 16, 40, 12
local FADE, SLIDE, WAIT_MAX = 0.3, 0.45, 8
local IDLE, KICK = math.rad(4), math.rad(26)
local CORD_COLOR = { 0.72, 0.6, 0.42 }
local LINE_COLOR = { 0.92, 0.9, 0.82 }
local GOLD, GREY = { 1, 0.82, 0 }, { 0.62, 0.62, 0.62 }
local RARE = 3
local RING = "gamepad-actionbar-circleslot-frame"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAR = "Interface\\Cooldown\\star4"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Clamp(x) return math.max(0, math.min(1, x)) end
local function Ease(x) x = Clamp(x) return 1 - (1 - x) ^ 3 end

local panel = CreateFrame("Frame", "ImprovedForeverFishingLoot", UIParent)
panel:SetFrameStrata("LOW")
panel:SetSize(WIDTH, HEAD_H)
panel:SetAlpha(0)
panel:Hide()

-- (a soft shadow behind it: the game's level-up one, stretched, in two
-- halves meeting in the middle, the upper one upside down: fading out at
-- its top as at its bottom)
local SHADOW = "LevelUp-Shadow-Lower"
local function Shadow(upper)
    local t = panel:CreateTexture(nil, "BACKGROUND")
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(SHADOW)
    if upper and info and info.file then
        t:SetTexture(info.file)
        t:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.bottomTexCoord, info.topTexCoord)
    else
        t:SetAtlas(SHADOW)
    end
    t:SetPoint(upper and "TOPLEFT" or "BOTTOMLEFT", panel, upper and "TOPLEFT" or "BOTTOMLEFT", -30, upper and 40 or -24)
    t:SetPoint(upper and "BOTTOMRIGHT" or "TOPRIGHT", panel, "RIGHT", MARGIN_X + 10, 0)
    t:SetAlpha(0.75)
    return t
end
Shadow(true)
Shadow(false)

local function Shadowed(fs, color)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

-- (a spot in the panel: x, y from its top left)
local function At(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", panel, "TOPLEFT", x, y)
end

-- (by the rope's end, left of its knot: the session's numbers)
local stats = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)
stats:SetJustifyH("RIGHT")

-- (the rope: tied on the minimap's rim, hanging the whole way down; each
-- step a shadow, its body (a little lighter and darker in turn, as a
-- rope's twist) and a light along it; a knot where it's tied)
local cordFrame = CreateFrame("Frame", nil, panel)
cordFrame:SetAllPoints()
local cord = {}
for i = 1, CORD_SEGMENTS do
    local function Strand(level, thickness, r, g, b, a)
        local l = cordFrame:CreateLine(nil, "ARTWORK", nil, level)
        l:SetThickness(thickness)
        l:SetTexture(WHITE)
        l:SetVertexColor(r, g, b, a)
        return l
    end
    local shade = i % 2 == 0 and 0.85 or 1
    cord[i] = {
        Strand(0, 6, 0, 0, 0, 0.35),
        Strand(1, 3.5, CORD_COLOR[1] * shade, CORD_COLOR[2] * shade, CORD_COLOR[3] * shade, 1),
        Strand(2, 1, 1, 0.92, 0.75, 0.45),
    }
end
-- (its end, swinging with it: tied off in a knot, frayed strands under it)
local endKnot = {}
for i, size in ipairs({ 12, 7 }) do
    local t = cordFrame:CreateTexture(nil, "OVERLAY", nil, i)
    t:SetTexture(CIRCLE_MASK)
    t:SetSize(size, size)
    endKnot[i] = t
end
endKnot[1]:SetVertexColor(CORD_COLOR[1] * 0.8, CORD_COLOR[2] * 0.8, CORD_COLOR[3] * 0.8)
endKnot[2]:SetVertexColor(1, 0.92, 0.75, 0.5)
local FRAYS = { -0.5, -0.2, 0.05, 0.3, 0.55 }   -- (each strand's turn off the rope's line)
local frays = {}
for i = 1, #FRAYS do
    local l = cordFrame:CreateLine(nil, "ARTWORK", nil, 1)
    l:SetThickness(1.5)
    l:SetTexture(WHITE)
    l:SetVertexColor(CORD_COLOR[1], CORD_COLOR[2], CORD_COLOR[3], 0.85)
    frays[i] = l
end
local knot = panel:CreateTexture(nil, "OVERLAY")
knot:SetTexture(CIRCLE_MASK)
knot:SetSize(9, 9)
knot:SetVertexColor(CORD_COLOR[1] * 0.8, CORD_COLOR[2] * 0.8, CORD_COLOR[3] * 0.8)
local cordLength, sway, wave, maxHung = SPACING, 0, WAVE, 6
local tieX, tieY = CORD_X, 0            -- (the knot, in the panel's units from its top left)

-- (the rope's point u of the way down (0 the knot, 1 its end): from the
-- knot over to its line, bowed left, a wave running down it and its end
-- swinging, all more the lower)
local function RopeAt(u, now)
    local over = 1 - (1 - math.min(1, u * 4)) ^ 2
    local x = tieX + (CORD_X - tieX) * over - BOW * math.sin(math.pi * u)
        + wave * u * math.sin(2 * math.pi * WAVES * u - now * 1.6) + sway * u * u
    return x, tieY + (-HEAD_H - cordLength - tieY) * u
end

-- (the rope's point d down from the head's line)
local function CordAt(d)
    local top, bottom = tieY, -HEAD_H - cordLength
    local y = -HEAD_H - d
    return (RopeAt(Clamp((top - y) / math.max(1, top - bottom)), GetTime())), y
end

local function DrawCord(now)
    local px, py = RopeAt(0, now)
    for i = 1, CORD_SEGMENTS do
        local x, y = RopeAt(i / CORD_SEGMENTS, now)
        for _, l in ipairs(cord[i]) do
            l:SetStartPoint("TOPLEFT", panel, px, py)
            l:SetEndPoint("TOPLEFT", panel, x, y)
        end
        px, py = x, y
    end
    At(knot, tieX, tieY)
    -- (its end: the knot, the frayed strands out of it along the rope's
    -- last step, each a little apart, stirring; the numbers beside it)
    local ex, ey = RopeAt(1, now)
    local bx, by = RopeAt(1 - 1 / CORD_SEGMENTS, now)
    local a = math.atan2(ey - by, ex - bx)
    for _, t in ipairs(endKnot) do At(t, ex, ey) end
    for i, l in ipairs(frays) do
        local turn = a + FRAYS[i] + 0.06 * math.sin(now * 2 + i)
        local len = FRAY_LEN * (0.75 + 0.25 * ((i * 7) % 4) / 3)
        l:SetStartPoint("TOPLEFT", panel, ex, ey)
        l:SetEndPoint("TOPLEFT", panel, ex + math.cos(turn) * len, ey + math.sin(turn) * len)
    end
    stats:ClearAllPoints()
    stats:SetPoint("RIGHT", panel, "TOPLEFT", ex - 16, ey - FRAY_LEN / 2)
end

-- (the knot: on the minimap's rim, lower right; else the panel's top)
local function Tie()
    local map = rawget(_G, "Minimap")
    local mx, my
    if map then mx, my = map:GetCenter() end
    local left, top = panel:GetLeft(), panel:GetTop()
    if not (mx and my and left and top) then
        tieX, tieY = CORD_X, 0
        return
    end
    local k = map:GetEffectiveScale() / panel:GetEffectiveScale()
    local r = map:GetWidth() / 2 * k
    tieX = mx * k + r * math.sin(TIE_ANGLE) - left
    tieY = my * k - r * math.cos(TIE_ANGLE) - top
end

-- (more than it holds: how many more, at its end)
local more = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)

-- A catch on the cord: its string, its icon round in a ring, its name and
-- count to its left; a glow behind a rare one
local hung = {}
local function Hung(i)
    local h = hung[i]
    if h then return h end
    h = CreateFrame("Frame", nil, panel)
    h:SetSize(ICON, ICON)
    h:SetFrameLevel(cordFrame:GetFrameLevel() + 2)
    h.string = cordFrame:CreateLine(nil, "ARTWORK", nil, -1)
    h.string:SetThickness(1)
    h.string:SetTexture(WHITE)
    h.string:SetVertexColor(LINE_COLOR[1], LINE_COLOR[2], LINE_COLOR[3], 0.7)
    h.glow = panel:CreateTexture(nil, "BORDER")
    h.glow:SetTexture(STAR)
    h.glow:SetBlendMode("ADD")
    h.glow:SetSize(ICON * 2.4, ICON * 2.4)
    h.glow:SetPoint("CENTER", h)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetAllPoints()
    h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = h:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(h.icon)
    h.icon:AddMaskTexture(mask)
    h.ring = h:CreateTexture(nil, "OVERLAY")
    h.ring:SetPoint("TOPLEFT", -ICON * 0.14, ICON * 0.14)
    h.ring:SetPoint("BOTTOMRIGHT", ICON * 0.14, -ICON * 0.14)
    h.ring:SetAtlas(RING)
    h.count = Shadowed(h:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
    h.count:SetPoint("RIGHT", h, "LEFT", -8, 0)
    h.name = Shadowed(h:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    h.name:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
    h.name:SetJustifyH("RIGHT")
    h.name:SetWordWrap(false)
    h.name:SetWidth(WIDTH - 110)
    h.phase = i * 1.3
    hung[i] = h
    return h
end

local function Minutes(seconds)
    local m = math.floor(math.max(0, seconds) / 60)
    if m < 60 then return m .. " min" end
    return ("%dh %02dm"):format(math.floor(m / 60), m % 60)
end

local function Session()
    return F.Session and F.Session() or nil
end

-- (each item of a catch: when it reached here, new, still on its way
-- (from the bar, by a time); and when the cord was last knocked)
local hits, knockAt = {}, nil

-- (the session's numbers; what it caught, in the order first caught, the
-- latest kept on once the cord is full)
local function Draw()
    local s = Session()
    if not s then return end
    local ended = s.active and time() or (s.last or time())
    local parts = { ("%d casts"):format(s.casts or 0), ("%d caught"):format(s.catches or 0) }
    if (s.escapes or 0) > 0 then parts[#parts + 1] = ("%d got away"):format(s.escapes) end
    parts[#parts + 1] = Minutes(ended - (s.start or ended))
    stats:SetText(table.concat(parts, "  ·  "))
    local list = {}
    for _, item in pairs(s.items or {}) do list[#list + 1] = item end
    table.sort(list, function(a, b)
        if (a.first or 0) ~= (b.first or 0) then return (a.first or 0) < (b.first or 0) end
        return (a.id or 0) < (b.id or 0)
    end)
    local from = math.max(1, #list - maxHung + 1)
    local n = #list - from + 1
    for k = 1, n do
        local h, item = Hung(k), list[from + k - 1]
        local c = QualityColor(item.quality)
        h.id, h.at = item.id, k * SPACING - SPACING / 2
        h.icon:SetTexture(item.icon or 134400)
        h.ring:SetVertexColor(c[1], c[2], c[3])
        h.glow:SetVertexColor(c[1], c[2], c[3])
        h.rare = (item.quality or 0) >= RARE
        h.name:SetText(item.name or "")
        h.name:SetTextColor(c[1], c[2], c[3])
        h.count:SetText("×" .. item.count)
        h:Show()
        h.string:Show()
    end
    for k = n + 1, #hung do
        hung[k].id = nil
        hung[k]:Hide()
        hung[k].string:Hide()
        hung[k].glow:SetAlpha(0)
    end
    more:ClearAllPoints()
    more:SetPoint("TOPRIGHT", panel, "TOPLEFT", CORD_X - 30, -HEAD_H - n * SPACING - 4)
    more:SetText(from > 1 and ("+%d more"):format(from - 1) or (#list == 0 and "Nothing caught yet" or ""))
end

-- (from under the minimap down to over the gamepad bar, by its top; with
-- the fishing view on, to the bottom; the cord the whole way)
local function Place()
    local GB = IF.Interface and IF.Interface.GamepadBar
    local top = GB and GB.Rect and select(4, GB.Rect())
    local bottom = top and (top / UIParent:GetEffectiveScale() + OVER_BAR) or 230
    if F.ViewActive and F.ViewActive() then bottom = LOW end
    local screen = UIParent:GetTop() or UIParent:GetHeight()
    local under = screen - 290
    local map = rawget(_G, "MinimapCluster") or rawget(_G, "Minimap")
    local mb = map and map:GetBottom()
    if mb then under = mb * map:GetEffectiveScale() / UIParent:GetEffectiveScale() - UNDER_MAP end
    if bottom == panel.bottom and under == panel.under then return end
    panel.bottom, panel.under = bottom, under
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -MARGIN_X, under - screen)
    panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MARGIN_X, bottom)
    cordLength = math.max(SPACING, under - bottom - HEAD_H - FOOT_H)
    maxHung = math.max(1, math.floor((cordLength - 20) / SPACING))
end
F.RACK_ICON = ICON

local function Wanted()
    local s = Session()
    return F.panelOn and s and s.active and not F.EditMode() or false
end

-- (a catch on the cord swaying: a little always; knocked by a catch of it,
-- swinging out and settling; on its way from the bar: new, not there yet;
-- new without the bar: sliding down the cord to its place first)
local function Swing(h, now)
    local hit = h.id and hits[h.id]
    local since = hit and not hit.pending and now - hit.at or nil
    local angle = REACH + IDLE * math.sin(now * 1.3 + h.phase)
    local d, alpha = h.at, 1
    if hit then
        if hit.pending then
            alpha = hit.new and 0 or 1
        else
            local s = since
            if hit.new and not hit.flown then
                local p = Ease(s / SLIDE)
                d = h.at * p
                alpha = Clamp(s / 0.15)
                s = s - SLIDE
            end
            if s > 0 then angle = angle + KICK * math.exp(-2.4 * s) * math.sin(7 * s) end
        end
    end
    local ax, ay = CordAt(d)
    local reach = STRING + ICON / 2
    local x, y = ax - math.sin(angle) * reach, ay - math.cos(angle) * reach
    At(h, x, y)
    h.string:SetStartPoint("TOPLEFT", panel, ax, ay)
    h.string:SetEndPoint("TOPLEFT", panel, x + math.sin(angle) * ICON / 2, y + math.cos(angle) * ICON / 2)
    h:SetAlpha(alpha)
    h.string:SetAlpha(alpha)
    h.glow:SetAlpha(h.rare and alpha * (0.35 + 0.15 * math.sin(now * 3 + h.phase)) or 0)
    -- (its count gold a moment after its catch)
    local g = since and since >= 0 and Clamp(1 - (since - 0.6) / 0.6) or 0
    h.count:SetTextColor(1, 1 - 0.18 * g, 1 - g)
end

local function Tick(self, elapsed)
    local goal = Wanted() and 1 or 0
    local a = self:GetAlpha()
    if a ~= goal then
        a = goal > a and math.min(goal, a + elapsed / FADE) or math.max(goal, a - elapsed / FADE)
        self:SetAlpha(a)
    end
    if a <= 0 and goal == 0 then self:Hide() return end
    local now = GetTime()
    -- (one on its way too long (the bar gone): there now)
    for _, hit in pairs(hits) do
        if hit.pending and now > hit.deadline then hit.pending, hit.at = false, now end
    end
    -- (the cord swaying, knocked by a catch)
    local since = knockAt and now - knockAt
    sway = 4 * math.sin(now * 0.8)
    wave = WAVE
    if since and since > 0 then
        local k = math.exp(-1.8 * since)
        sway = sway + 12 * k * math.sin(5 * since)
        wave = wave + 10 * k
    end
    Tie()
    DrawCord(now)
    for _, h in ipairs(hung) do
        if h:IsShown() then Swing(h, now) end
    end
end

-- (an error each frame would flood the game's error handler: stopped, said once)
panel:SetScript("OnUpdate", function(self, elapsed)
    local ok, err = pcall(Tick, self, elapsed)
    if not ok then
        self:SetScript("OnUpdate", nil)
        IF.Print("Fishing: the session's stringer stopped after an error: " .. tostring(err))
    end
end)

local function Update()
    if not Wanted() then return end
    Place()
    Draw()
    panel:Show()
end

-- (a catch: each item on its way from the bar (F.RackHit as it lands),
-- else here now)
F.OnCatch(function(catch)
    local now = GetTime()
    local bar = F.Settings().bar and not F.EditMode()
    wipe(hits)
    for _, item in ipairs(catch and catch.items or {}) do
        if item.id then
            hits[item.id] = { new = item.new, pending = bar, flown = bar, at = now, deadline = now + WAIT_MAX }
        end
    end
    if not bar then knockAt = now end
end)

-- Where an item hangs (or will), in the screen's units (UIParent's), or
-- nil: not on the cord
-- The stringer's tally at its foot, while it shows (Chat.lua sits over it)
function F.RackTally()
    return panel:IsVisible() and stats:IsShown() and stats or nil
end

function F.RackSpot(id)
    if not (panel:IsShown() and panel:GetAlpha() > 0) then return nil end
    for _, h in ipairs(hung) do
        if h:IsShown() and h.id == id then
            local x, y = h:GetCenter()
            if not x then return nil end
            local k = h:GetEffectiveScale() / UIParent:GetEffectiveScale()
            return x * k, y * k
        end
    end
end

-- An item flown in from the bar: knocked swinging there now (nil: every
-- one still on its way)
function F.RackHit(id)
    local now = GetTime()
    for key, hit in pairs(hits) do
        if hit.pending and (id == nil or key == id) then hit.pending, hit.at = false, now end
    end
    knockAt = now
end

---------------------------------------------------------------------------
-- On while the setting is
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    F.panelOn = F.Settings().panel and true or false
    -- (its time and place kept up)
    Update()
end

F.Watcher("fishing panel", 1, Watch)
F.OnChange(function() Update() end)

F.ApplyPanel = Watch
