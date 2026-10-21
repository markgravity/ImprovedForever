-- The focused (super-tracked) quest's way, as a film's guide would show it,
-- in the header's place under the top of the screen (HeaderSlot.lua) in the
-- look of the camp's summary header (the Camp module's Scene.lua): the
-- gold rule fading out to both sides, under it the quest's name big in its
-- Morpheus, the yards left small and white under that (another zone's way
-- in: the waypoint's words small in gold last), and standing on the rule
-- the arrow: a cut gem lying on its side, seen from low behind (in
-- perspective, its faces lit, its edges the cast line's diamond's: a line
-- and a wider glow), hovering, turning as you do toward where the quest
-- leads next (its next waypoint, else its place on your zone's map, else
-- on its own zone's), coloured by how far off that way you're headed
-- (green on it, yellow, orange, red turned away). Brighter while you're
-- headed its way. In a fight only the gem, small and plain, so the
-- fight has your eyes (the same while the game names a zone you enter);
-- the target, a zone's name or a level up take its place in turn
-- (HeaderSlot.lua); gone when there's nothing to point at (no
-- focused quest, another continent, an instance), on a flight, while an
-- NPC talks (NpcDialog.lua), and once you're there.
-- Only read: the quest log's waypoints and map POIs, the player's map
-- position and facing. The game's own in-world marker (SuperTrackedFrame)
-- is left as it is.
local IF = ImprovedForever
local IN = IF.Interface

local QA = {}
IN.QuestArrow = QA
local HS = IN.HeaderSlot

-- (the diamond, a cut gem lying on its side, its point ahead: its girdle's
-- reach ahead and behind its middle, its half width, its top's height over
-- the girdle and its bottom's depth under it; how high its girdle hovers
-- over the ground, how far it bobs (on the screen))
local AHEAD, BEHIND, HALF, UP, DOWN = 44, 16, 18, 11, 15
local HOVER, BOB = DOWN + 6, 1.5
-- (seen from low behind, as the game's camera sees the ground, the view on
-- the gem's middle: its tilt down, its distance (less is a stronger
-- perspective: the point ahead small and far, the back near and wide))
local TILT, VIEW = math.rad(28), 110
-- (its faces lit from above, behind, a little left)
local LIGHT = { -0.35, 0.85, -0.4 }
local EDGE, EDGE_GLOW = 2.5, 4          -- (the cast line's diamond's)
-- (its colour by how far off the way you're headed: the game's colours of
-- a monster's level, Module.lua's LEVEL_COLORS: green on it, yellow, orange,
-- red turned away from it)
local WAY_COLORS = IN.LEVEL_COLORS
local WHITE = "Interface\\Buttons\\WHITE8x8"
-- (the header's look and place, HeaderSlot.lua's)
local FONT, HEADER_GOLD = HS.FONT, HS.GOLD
local NAME_SIZE, WORDS_SIZE, YARDS_SIZE = HS.NAME_SIZE, HS.WORDS_SIZE, HS.SMALL_SIZE
local RULE_W, RULE_Y, NAME_GAP = HS.RULE_W, HS.RULE_Y, HS.NAME_GAP
local ARRIVED = 8                       -- (yards: there)
local ON_COURSE = math.rad(20)          -- (headed its way within this)
local TURN = 10                         -- (how fast it turns to a new angle)
local FADE = 4                          -- (and fades in and out)
local POLL = 0.1                        -- (the player's place read this often)
-- (in a fight: the gem alone, this big, plain (its faces: no edges, glow,
-- shadow or bob), the header gone)
local CALM_SIZE = 0.6

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function Number(v)
    return type(v) == "number" and not Secret(v)
end

---------------------------------------------------------------------------
-- The frame: under the top, in the middle
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "ImprovedForeverQuestArrow", UIParent)
frame:SetSize(260, 120)
frame:SetFrameStrata("LOW")
frame:EnableMouse(false)
frame:SetAlpha(0)
frame:Hide()


---------------------------------------------------------------------------
-- The diamond, a gem: its girdle a diamond (point, right, back, left), a
-- point over it and one under it, eight faces each a triangle (a texture
-- whose corners are moved, SetVertexOffset: its fourth corner on its
-- third), those facing the view drawn, lit by how they face the light; its
-- shadow on the ground; its edges the cast line's diamond's, round the
-- girdle and up and down to its points
---------------------------------------------------------------------------
local VERTEX = Enum and Enum.VertexIndex or {}
local UL, LL, UR, LR = VERTEX.UpperLeft or 1, VERTEX.LowerLeft or 2, VERTEX.UpperRight or 3, VERTEX.LowerRight or 4

local function Plane(layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    return t
end

local shadow = Plane("BACKGROUND", 0)
shadow:SetVertexColor(0, 0, 0, 0.45)
local faces = {}
for i = 1, 8 do faces[i] = Plane("ARTWORK", 1) end
local canBend = shadow.SetVertexOffset ~= nil

local function Line(sub, thickness)
    local l = frame:CreateLine(nil, "OVERLAY", nil, sub)
    l:SetThickness(thickness)
    l:SetTexture(WHITE)
    l:SetBlendMode("ADD")
    return l
end
-- (the girdle's four edges, with their glow; then the edges up to the top
-- point and down to the bottom one, thin)
local girdle, glows, ridges = {}, {}, {}
for i = 1, 4 do
    glows[i] = Line(1, EDGE_GLOW)
    girdle[i] = Line(2, EDGE)
end
for i = 1, 8 do ridges[i] = Line(2, 1.2) end

-- `region` moved onto four points (from the frame's middle, y up): placed
-- on their middle, as big as they span, each corner pulled onto its point
local function Corners(region, ulx, uly, urx, ury, lrx, lry, llx, lly)
    local l, r = math.min(ulx, urx, lrx, llx), math.max(ulx, urx, lrx, llx)
    local b, t = math.min(uly, ury, lry, lly), math.max(uly, ury, lry, lly)
    local w, h = math.max(r - l, 1), math.max(t - b, 1)
    local mx, my = (l + r) / 2, (b + t) / 2
    region:ClearAllPoints()
    region:SetPoint("CENTER", frame, "CENTER", mx, my)
    region:SetSize(w, h)
    region:SetVertexOffset(UL, ulx - (mx - w / 2), uly - (my + h / 2))
    region:SetVertexOffset(UR, urx - (mx + w / 2), ury - (my + h / 2))
    region:SetVertexOffset(LR, lrx - (mx + w / 2), lry - (my - h / 2))
    region:SetVertexOffset(LL, llx - (mx - w / 2), lly - (my - h / 2))
end

-- A point about the gem (x right, y up, z ahead, from its middle) on the
-- screen, from the gem's middle: seen from VIEW back, TILT down
local SIN_T, COS_T = math.sin(TILT), math.cos(TILT)
local function Project(x, y, z)
    local depth = VIEW + z * COS_T - y * SIN_T
    local k = VIEW / math.max(depth, 1)
    return x * k, (y * COS_T + z * SIN_T) * k
end
-- (where the view is; the gem's middle on the screen, over the rule (the
-- ground's middle under it))
local CAM_Y, CAM_Z = VIEW * SIN_T, -VIEW * COS_T
local _, GROUND_Y = Project(0, -HOVER, 0)
local RAISE = -GROUND_Y

local function Normalize(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len == 0 then return 0, 1, 0 end
    return x / len, y / len, z / len
end
local LX, LY, LZ = Normalize(LIGHT[1], LIGHT[2], LIGHT[3])

-- (its girdle, flat, before turning: point, right, back, left)
local GIRDLE = { { 0, AHEAD }, { HALF, 0 }, { 0, -BEHIND }, { -HALF, 0 } }
-- (its points: the girdle's four, then the top, then the bottom)
local TOP, BOTTOM = 5, 6
local world, screen = {}, {}
for i = 1, 6 do world[i], screen[i] = {}, {} end

-- (its middle on the rule)
frame:SetPoint("CENTER", UIParent, "TOP", 0, -RULE_Y)

-- The diamond turned `angle` (clockwise from straight ahead), `bob` up
-- (screen), `bright` 0 to 1 (headed its way), in `color`, `size` times as
-- big about the rule's middle, `plain` 0 to 1 (in a fight: no glow, no
-- shadow, no edges: its faces alone)
local function Draw(angle, bob, bright, color, size, plain)
    local cr, cg, cb = color[1], color[2], color[3]
    local c, s = math.cos(angle), math.sin(angle)
    for i, p in ipairs(GIRDLE) do
        local w = world[i]
        w[1], w[2], w[3] = p[1] * c + p[2] * s, 0, -p[1] * s + p[2] * c
    end
    world[TOP][1], world[TOP][2], world[TOP][3] = 0, UP, 0
    world[BOTTOM][1], world[BOTTOM][2], world[BOTTOM][3] = 0, -DOWN, 0
    local up = RAISE + bob
    for i = 1, 6 do
        local x, y = Project(world[i][1], world[i][2], world[i][3])
        screen[i][1], screen[i][2] = x * size, (y + up) * size
    end
    -- (each face: a girdle edge and the top or bottom point; drawn while it
    -- faces the view)
    local facing = {}
    for f = 1, 8 do
        local i = (f - 1) % 4 + 1
        local tip = f <= 4 and TOP or BOTTOM
        local a, b, t = world[i], world[i % 4 + 1], world[tip]
        local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
        local vx, vy, vz = t[1] - a[1], t[2] - a[2], t[3] - a[3]
        local nx, ny, nz = Normalize(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
        -- (outward: away from the gem's middle)
        local ox, oy, oz = (a[1] + b[1] + t[1]) / 3, (a[2] + b[2] + t[2]) / 3, (a[3] + b[3] + t[3]) / 3
        if nx * ox + ny * oy + nz * oz < 0 then nx, ny, nz = -nx, -ny, -nz end
        local shown = nx * (0 - ox) + ny * (CAM_Y - oy) + nz * (CAM_Z - oz) > 0
        facing[f] = shown
        local face = faces[f]
        if canBend and shown then
            local lit = math.max(0, nx * LX + ny * LY + nz * LZ)
            local shade = (0.25 + 0.75 * lit) * (0.8 + 0.2 * bright)
            local sa, sb, st = screen[i], screen[i % 4 + 1], screen[tip]
            Corners(face, sa[1], sa[2], sb[1], sb[2], st[1], st[2], st[1], st[2])
            face:SetVertexColor(cr * shade, cg * shade, cb * shade, 0.95)
            face:Show()
        else
            face:Hide()
        end
    end
    if canBend then
        -- (its shadow: the girdle dropped onto the ground, a little wider,
        -- fainter as it rises)
        local sp = {}
        for i = 1, 4 do
            local x, y = Project(world[i][1] * 1.1, -HOVER, world[i][3] * 1.1)
            sp[i] = { x * size, (y + RAISE) * size }
        end
        Corners(shadow, sp[1][1], sp[1][2], sp[2][1], sp[2][2], sp[3][1], sp[3][2], sp[4][1], sp[4][2])
        shadow:SetAlpha(0.4 * (1 - (bob + BOB) / (4 * BOB)) * (1 - plain))
    end
    local glowA = (0.3 + 0.35 * bright) * (1 - plain)
    for i = 1, 4 do
        local a, b = screen[i], screen[i % 4 + 1]
        for _, l in ipairs({ girdle[i], glows[i] }) do
            l:SetStartPoint("CENTER", frame, a[1], a[2])
            l:SetEndPoint("CENTER", frame, b[1], b[2])
        end
        girdle[i]:SetVertexColor(cr, cg, cb, 1 - plain)
        glows[i]:SetVertexColor(cr, cg, cb, glowA)
    end
    -- (an edge to a point shown while a face beside it is; the one up to
    -- the girdle's point, the way, brightest)
    for r = 1, 8 do
        local i = (r - 1) % 4 + 1
        local top = r <= 4
        local base = top and 0 or 4
        local before = (i + 2) % 4 + 1
        local ridge = ridges[r]
        if facing[base + i] or facing[base + before] then
            local a, t = screen[i], screen[top and TOP or BOTTOM]
            ridge:SetStartPoint("CENTER", frame, t[1], t[2])
            ridge:SetEndPoint("CENTER", frame, a[1], a[2])
            local alpha = (top and 0.55 or 0.3) * (i == 1 and (1 + bright) / 1.4 or 0.7)
            -- (pale: the colour half toward white)
            ridge:SetVertexColor((1 + cr) / 2, (1 + cg) / 2, (1 + cb) / 2, math.min(1, alpha) * (1 - plain))
            ridge:Show()
        else
            ridge:Hide()
        end
    end
end
if not canBend then shadow:Hide() end

---------------------------------------------------------------------------
-- The header: the diamond standing on the rule (the slot's,
-- HeaderSlot.lua); under it the quest's name big, the yards small and white
-- under that, then the waypoint's words (another zone's way in) small in
-- gold
---------------------------------------------------------------------------
-- (its parts, each with its own alpha: gone in a fight, and while
-- another has the header's place)
local headerParts = {}

local function Text(font, size, r, g, b)
    local s = HS.Text(frame, font, size, r, g, b)
    headerParts[#headerParts + 1] = { region = s, alpha = 1 }
    return s
end

local title = Text(FONT, NAME_SIZE, HEADER_GOLD[1], HEADER_GOLD[2], HEADER_GOLD[3])
title:SetPoint("TOP", frame, "CENTER", 0, -NAME_GAP)
title:SetWidth(2 * RULE_W)
local distance = Text(GameFontHighlight and GameFontHighlight:GetFont(), YARDS_SIZE, 1, 1, 1)
distance:SetPoint("TOP", title, "BOTTOM", 0, -4)
local words = Text(GameFontNormal and GameFontNormal:GetFont(), WORDS_SIZE, 1, 0.82, 0)
words:SetPoint("TOP", distance, "BOTTOM", 0, -4)
words:SetWidth(2 * RULE_W)


---------------------------------------------------------------------------
-- Where the quest leads: its next waypoint (maybe in another zone), else
-- its place on the player's map, else on its own zone's. Read again only when the quest log, the
-- focus or the zone changes.
---------------------------------------------------------------------------
local target        -- { quest, map, x, y, source, text } or false
local dirty = true

local function OnPlayerMap(q, map)
    if C_QuestLog.GetNextWaypointForMap then
        local x, y = C_QuestLog.GetNextWaypointForMap(q, map)
        if Number(x) and Number(y) then return x, y, "waypoint on map" end
    end
    local quests = C_QuestLog.GetQuestsOnMap and C_QuestLog.GetQuestsOnMap(map)
    for _, info in ipairs(type(quests) == "table" and quests or {}) do
        if Number(info.questID) and info.questID == q and Number(info.x) and Number(info.y) then return info.x, info.y, "map POI" end
    end
end

local function Find()
    local q = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    if not Number(q) or q == 0 then return false end
    local name = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
    local here = C_Map.GetBestMapForUnit("player")
    if not Number(here) then here = nil end
    local map, x, y, source
    if C_QuestLog.GetNextWaypoint then
        map, x, y = C_QuestLog.GetNextWaypoint(q)
        source = "next waypoint"
    end
    if not (Number(map) and Number(x) and Number(y)) and here then
        x, y, source = OnPlayerMap(q, here)
        map = here
    end
    -- (its place on its own zone's map, another zone's)
    local own = GetQuestUiMapID and GetQuestUiMapID(q)
    if not (Number(x) and Number(y)) and Number(own) and own ~= 0 and own ~= here then
        x, y, source = OnPlayerMap(q, own)
        map = own
        if source then source = source .. " (its zone)" end
    end
    if not (Number(map) and Number(x) and Number(y)) then return false end
    local text = source == "next waypoint" and map ~= here and C_QuestLog.GetNextWaypointText
        and C_QuestLog.GetNextWaypointText(q)
    if type(text) ~= "string" or text == "" or Secret(text) then text = nil end
    return { quest = q, map = map, x = x, y = y, source = source, name = name, text = text }
end

local function Target()
    if dirty then
        dirty = false
        target = Find()
    end
    return target
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "SUPER_TRACKING_CHANGED", "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED", "PLAYER_ENTERING_WORLD", "QUEST_WATCH_LIST_CHANGED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function() dirty = true end)

---------------------------------------------------------------------------
-- The way: yards east and north from the player to the target, in the
-- world, the axes measured on the player's map (its right is east, its
-- down south), so no world convention is assumed
---------------------------------------------------------------------------
local probe

local function World(map, x, y)
    local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
    if not (pos and Number(continent)) then return nil end
    local wx, wy = pos:GetXY()
    if not (Number(wx) and Number(wy)) then return nil end
    return continent, wx, wy
end

local function Axis(map, x1, y1, x2, y2)
    local _, ax, ay = World(map, x1, y1)
    local _, bx, by = World(map, x2, y2)
    if not (ax and bx) then return nil end
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return nil end
    return dx / len, dy / len
end

-- yards east, yards north, or nil
local function Way(t)
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    if not (Number(px) and Number(py)) then return nil end
    local pc, pwx, pwy = World(map, px, py)
    local tc, twx, twy = World(t.map, t.x, t.y)
    if not (pc and tc) or pc ~= tc then return nil end
    local ex, ey = Axis(map, 0.4, 0.5, 0.6, 0.5)
    local sx, sy = Axis(map, 0.5, 0.4, 0.5, 0.6)
    if not (ex and sx) then return nil end
    local dx, dy = twx - pwx, twy - pwy
    return dx * ex + dy * ey, -(dx * sx + dy * sy)
end

---------------------------------------------------------------------------
-- Shown, turned, faded
---------------------------------------------------------------------------
local shown = { angle = nil, alpha = 0, goal = 0, on = 0, calm = 0, parts = 1 }
local since = POLL
local broken

local function Quiet()
    if UnitOnTaxi("player") or UnitIsDeadOrGhost("player") then return true end
    local dialog = ImprovedForeverNpcDialog
    return dialog and dialog:IsShown()
end

-- (the angle to turn to: clockwise from straight ahead, in radians)
local goalAngle, yards

local function Read()
    goalAngle, yards = nil, nil
    if not IN.Settings().questArrow or Quiet() then return end
    local t = Target()
    if not t then return end
    local east, north = Way(t)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not east or not Number(facing) then return end
    yards = math.sqrt(east * east + north * north)
    -- bearing clockwise from north; facing turns anticlockwise from north
    goalAngle = math.atan2(east, north) + facing
    if probe then
        probe = nil
        IF.Print(("Quest arrow: quest %d from %s, map %d (%.3f, %.3f), %d yds, bearing %.0f, facing %.0f, turn %.0f")
            :format(t.quest, t.source, t.map, t.x, t.y, yards, math.deg(math.atan2(east, north)) % 360,
                math.deg(facing) % 360, math.deg(goalAngle) % 360))
    end
    if yards < ARRIVED then goalAngle = nil end
    title:SetText(t.name or "")
    words:SetText(t.text or "")
    local yd = math.floor(yards + 0.5)
    local text = yd < 1000 and tostring(yd) or (AbbreviateNumbers and AbbreviateNumbers(yd) or tostring(yd))
    distance:SetText(IN_GAME_NAVIGATION_RANGE and IN_GAME_NAVIGATION_RANGE:format(text) or (text .. " yds"))
end

-- (the colour `off` radians off the way: between the colours, 0 to pi)
local wayColor = { 1, 1, 1 }
local function WayColor(off)
    local n = #WAY_COLORS
    local at = math.min(1, off / math.pi) * (n - 1)
    local i = math.min(n - 1, math.floor(at) + 1)
    local f = at - (i - 1)
    local a, b = WAY_COLORS[i], WAY_COLORS[i + 1]
    for k = 1, 3 do wayColor[k] = a[k] + (b[k] - a[k]) * f end
    return wayColor
end

-- (the game's zone or subzone name across the top as you enter one: read,
-- never touched)
local function ZoneText()
    for _, f in ipairs({ ZoneTextFrame, SubZoneTextFrame }) do
        if f and f:IsVisible() and f:GetAlpha() > 0.05 then return true end
    end
    return false
end

-- (a to b the short way round)
local function Turn(a, b, k)
    local d = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + d * k
end

frame:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since >= POLL then
        since = 0
        -- (one error said once, then no more reading: an error each tick
        -- floods the game's error handler, whose popup taints the pad's focus)
        if not broken then
            local ok, err = pcall(Read)
            if not ok then
                broken, goalAngle = true, nil
                IF.Print("Immersion: the quest arrow stopped after an error: " .. tostring(err))
            end
        end
    end
    shown.goal = goalAngle and 1 or 0
    local k = math.min(1, elapsed * FADE)
    shown.alpha = shown.alpha + (shown.goal - shown.alpha) * k
    if goalAngle then
        shown.angle = shown.angle and Turn(shown.angle, goalAngle, math.min(1, elapsed * TURN)) or goalAngle
        local off = math.abs((shown.angle + math.pi) % (2 * math.pi) - math.pi)
        local on = off < ON_COURSE and 1 or 0
        shown.on = shown.on + (on - shown.on) * k
    end
    -- (in a fight: plain and small, the header gone, eased)
    local fight = IF.InCombat() and 1 or 0
    -- (the header's place ours or not (HeaderSlot.lua): spinning down to
    -- nothing as another comes, back after)
    local banner = IN.ZoneBanner
    -- (plain too while the game's own zone name shows over it)
    local plain = (fight == 1 or (ZoneText() and not (banner and banner.On()))) and 1 or 0
    local calm = shown.calm + (plain - shown.calm) * k
    if math.abs(calm - plain) < 0.005 then calm = plain end
    shown.calm = calm
    local present = HS.Presence("quest")
    local gem = present
    local parts = (1 - calm) * present
    if parts ~= shown.parts then
        shown.parts = parts
        for _, part in ipairs(headerParts) do
            part.region:SetAlpha(part.alpha * parts)
            part.region:SetShown(parts > 0.01)
        end
    end
    if shown.angle then
        local breath = math.sin(GetTime() * 2.5) * (1 - calm)
        local off = math.abs((shown.angle + math.pi) % (2 * math.pi) - math.pi)
        local size = (1 + (CALM_SIZE - 1) * calm) * math.max(0.001, gem)
        Draw(shown.angle + (1 - gem) * math.pi, BOB * breath, shown.on * (0.8 + 0.2 * breath), WayColor(off),
            size, calm)
    end
    frame:SetAlpha(shown.alpha)
    if shown.alpha < 0.01 and shown.goal == 0 then
        frame:SetAlpha(0)
        shown.angle = nil
    end
end)

-- (the header's place: wanted while there's a way to show, its rule while
-- not plain)
HS.Add("quest", 1, {
    wants = function() return frame:IsShown() and goalAngle ~= nil end,
    rule = function() return shown.calm < 0.5 end,
})

---------------------------------------------------------------------------
-- On with the setting; ticking only while on
---------------------------------------------------------------------------
function QA.Apply()
    if not IF.db then return end
    local on = IN.Settings().questArrow and true or false
    dirty = true
    frame:SetShown(on)
    if not on then
        shown.alpha, shown.angle = 0, nil
        frame:SetAlpha(0)
    end
end

-- /if arrowprobe: where the arrow points and from what, once
function QA.Probe()
    dirty = true
    local t = Target()
    if not t then
        IF.Print("Quest arrow: no focused quest with a place (waypoint or map POI) found.")
        return
    end
    probe = true
    Read()
    if probe then
        probe = nil
        IF.Print(("Quest arrow: quest %d from %s, map %d, but no way to it (another continent, an instance, "
            .. "facing unknown, or quiet)"):format(t.quest, t.source, t.map))
    end
end

IF.OnLogin(QA.Apply)
