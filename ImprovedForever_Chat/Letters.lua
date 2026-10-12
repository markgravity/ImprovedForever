-- Reading a letter drawn on the touchpad: the $P point-cloud recognizer
-- (Vatavu, Anthony & Wobbrock, "Gestures as Point Clouds", 2012). Each
-- drawing, one or more strokes, is resampled to N points, scaled to a unit
-- box and centred; it is matched point to point against each letter's
-- template the same way, the nearest one wins. Neither the order of the
-- strokes nor their direction counts, so a letter is read however it was
-- drawn. Short taps (the dot of an i or a j) are left out of the cloud and
-- looked at after. A word is its letters side by side (Letters.Split), each
-- read on its own. One stroke straight across the pad is no letter: to the
-- right a space, to the left a delete.
local IF = ImprovedForever

local Letters = {}
IF.Letters = Letters

local N = 32
local abs, sqrt, floor, huge = math.abs, math.sqrt, math.floor, math.huge

---------------------------------------------------------------------------
-- The letters, drawn on a 100 x 100 box, y down (as written on paper).
-- A template = { output, stroke, stroke... }; a stroke = parts in a row:
--   { "L", x, y, x, y... }               a line through the points
--   { "A", cx, cy, rx, ry, from, to }    an arc, in degrees (0 right, 90
--                                        down, 270 up), from -> to
-- The output is what goes in the text box. Shapes the same in both cases
-- (c, j, o, s, v, y...) have their templates in lower case; the others give
-- the case they were drawn in.
---------------------------------------------------------------------------
local TEMPLATES = {
    { "a", { { "A", 42, 64, 24, 30, 0, 360 } }, { { "L", 66, 34, 66, 100 } } },
    { "b", { { "L", 28, 0, 28, 100 } }, { { "A", 50, 72, 22, 28, 0, 360 } } },
    { "c", { { "A", 52, 50, 36, 46, 40, 320 } } },
    { "d", { { "A", 44, 72, 22, 28, 0, 360 } }, { { "L", 68, 0, 68, 100 } } },
    { "e", { { "L", 18, 55, 82, 55 }, { "A", 50, 55, 32, 42, 0, -320 } } },
    { "f", { { "A", 62, 22, 18, 20, -10, -180 }, { "L", 44, 22, 44, 100 } }, { { "L", 24, 46, 68, 46 } } },
    { "g", { { "A", 44, 36, 22, 28, 0, 360 } }, { { "L", 66, 10, 66, 82 }, { "A", 44, 82, 22, 18, 0, 160 } } },
    { "h", { { "L", 28, 0, 28, 100 } }, { { "L", 28, 62 }, { "A", 50, 62, 22, 22, 180, 360 }, { "L", 72, 62, 72, 100 } } },
    { "j", { { "L", 58, 20, 58, 82 }, { "A", 40, 82, 18, 18, 0, 170 } } },
    { "k", { { "L", 28, 0, 28, 100 } }, { { "L", 72, 40, 28, 72, 72, 100 } } },
    { "k", { { "L", 26, 0, 26, 100 } }, { { "L", 76, 0, 26, 58, 78, 100 } } },
    { "l", { { "L", 50, 0, 50, 100 } } },
    { "m", { { "L", 14, 40, 14, 100 } }, { { "L", 14, 58 }, { "A", 31, 58, 17, 18, 180, 360 }, { "L", 48, 58, 48, 100 } },
        { { "L", 48, 58 }, { "A", 65, 58, 17, 18, 180, 360 }, { "L", 82, 58, 82, 100 } } },
    { "n", { { "L", 26, 30, 26, 100 } }, { { "L", 26, 56 }, { "A", 50, 56, 24, 24, 180, 360 }, { "L", 74, 56, 74, 100 } } },
    { "o", { { "A", 50, 50, 36, 46, 0, 360 } } },
    { "p", { { "L", 28, 28, 28, 100 } }, { { "A", 50, 48, 22, 20, 0, 360 } } },
    { "p", { { "L", 24, 0, 24, 100 } }, { { "L", 24, 0, 50, 0 }, { "A", 50, 26, 26, 26, -90, 90 }, { "L", 50, 52, 24, 52 } } },
    { "q", { { "A", 44, 48, 22, 20, 0, 360 } }, { { "L", 66, 28, 66, 100 } } },
    { "r", { { "L", 32, 30, 32, 100 } }, { { "L", 32, 58 }, { "A", 54, 58, 22, 22, 180, 300 } } },
    { "s", { { "A", 50, 27, 26, 23, -30, -270 }, { "A", 50, 73, 26, 23, -90, 150 } } },
    { "t", { { "L", 46, 0, 46, 100 } }, { { "L", 18, 30, 76, 30 } } },
    { "t", { { "L", 46, 0, 46, 82 }, { "A", 62, 82, 16, 18, 180, 30 } }, { { "L", 22, 30, 72, 30 } } },
    { "u", { { "L", 24, 0, 24, 58 }, { "A", 50, 58, 26, 40, 180, 0 }, { "L", 76, 58, 76, 0 } } },
    { "v", { { "L", 18, 0, 50, 100, 82, 0 } } },
    { "w", { { "L", 8, 0, 29, 100, 50, 25, 71, 100, 92, 0 } } },
    { "x", { { "L", 20, 0, 80, 100 } }, { { "L", 80, 0, 20, 100 } } },
    { "y", { { "L", 20, 0, 52, 58 } }, { { "L", 82, 0, 34, 100 } } },
    { "y", { { "L", 24, 0, 24, 40 }, { "A", 50, 40, 26, 22, 180, 0 }, { "L", 76, 40, 76, 0 } },
        { { "L", 76, 0, 76, 84 }, { "A", 56, 84, 20, 16, 0, 170 } } },
    { "z", { { "L", 18, 0, 82, 0, 18, 100, 82, 100 } } },

    { "A", { { "L", 14, 100, 50, 0, 86, 100 } }, { { "L", 30, 62, 70, 62 } } },
    { "B", { { "L", 24, 0, 24, 100 } }, { { "L", 24, 0, 52, 0 }, { "A", 52, 24, 22, 24, -90, 90 }, { "L", 52, 48, 24, 48 } },
        { { "L", 24, 48, 56, 48 }, { "A", 56, 74, 24, 26, -90, 90 }, { "L", 56, 100, 24, 100 } } },
    { "D", { { "L", 24, 0, 24, 100 } }, { { "L", 24, 0, 40, 0 }, { "A", 40, 50, 38, 50, -90, 90 }, { "L", 40, 100, 24, 100 } } },
    { "E", { { "L", 80, 0, 22, 0, 22, 100, 80, 100 } }, { { "L", 22, 50, 68, 50 } } },
    { "F", { { "L", 80, 0, 22, 0, 22, 100 } }, { { "L", 22, 50, 68, 50 } } },
    { "G", { { "A", 52, 50, 36, 50, -40, -360 }, { "L", 88, 50, 58, 50 } } },
    { "H", { { "L", 20, 0, 20, 100 } }, { { "L", 80, 0, 80, 100 } }, { { "L", 20, 50, 80, 50 } } },
    { "I", { { "L", 25, 0, 75, 0 } }, { { "L", 50, 0, 50, 100 } }, { { "L", 25, 100, 75, 100 } } },
    { "L", { { "L", 24, 0, 24, 100, 80, 100 } } },
    { "M", { { "L", 10, 100, 18, 0, 50, 64, 82, 0, 90, 100 } } },
    { "N", { { "L", 20, 100, 20, 0, 80, 100, 80, 0 } } },
    { "Q", { { "A", 50, 48, 38, 46, 0, 360 } }, { { "L", 58, 72, 90, 100 } } },
    { "R", { { "L", 24, 0, 24, 100 } }, { { "L", 24, 0, 52, 0 }, { "A", 52, 26, 24, 26, -90, 90 }, { "L", 52, 52, 24, 52 } },
        { { "L", 44, 52, 80, 100 } } },
    { "T", { { "L", 8, 0, 92, 0 } }, { { "L", 50, 0, 50, 100 } } },
    { "y", { { "L", 14, 0, 50, 50, 86, 0 } }, { { "L", 50, 50, 50, 100 } } },
}

-- A line or a dot under a dot: an i; a j with one: still a j
local DOTTED = { l = "i", I = "i", j = "j" }

-- A template's strokes as points
local function Expand(template)
    local strokes = {}
    for s = 2, #template do
        local points = {}
        for _, part in ipairs(template[s]) do
            if part[1] == "L" then
                for i = 2, #part, 2 do points[#points + 1] = { x = part[i], y = part[i + 1] } end
            else
                local cx, cy, rx, ry, from, to = part[2], part[3], part[4], part[5], part[6], part[7]
                local steps = math.max(4, math.ceil(abs(to - from) / 10))
                for i = 0, steps do
                    local a = math.rad(from + (to - from) * i / steps)
                    points[#points + 1] = { x = cx + rx * math.cos(a), y = cy + ry * math.sin(a) }
                end
            end
        end
        strokes[#strokes + 1] = points
    end
    return strokes
end

---------------------------------------------------------------------------
-- $P
---------------------------------------------------------------------------
local function Dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end

local function PathLength(points)
    local d = 0
    for i = 2, #points do
        if points[i].id == points[i - 1].id then d = d + Dist(points[i - 1], points[i]) end
    end
    return d
end

-- N points spread evenly along the strokes (nil: they have no length)
local function Resample(points)
    local interval = PathLength(points) / (N - 1)
    if interval <= 0 then return nil end
    local pts = {}
    for i, p in ipairs(points) do pts[i] = { x = p.x, y = p.y, id = p.id } end
    local out = { { x = pts[1].x, y = pts[1].y, id = pts[1].id } }
    local walked = 0
    local i = 2
    while i <= #pts do
        local a, b = pts[i - 1], pts[i]
        if a.id == b.id then
            local d = Dist(a, b)
            if d > 0 and walked + d >= interval then
                local t = (interval - walked) / d
                local q = { x = a.x + t * (b.x - a.x), y = a.y + t * (b.y - a.y), id = b.id }
                out[#out + 1] = q
                table.insert(pts, i, q)
                walked = 0
            else
                walked = walked + d
            end
        end
        i = i + 1
    end
    -- (rounding: one short, or one over)
    while #out < N do
        local last = pts[#pts]
        out[#out + 1] = { x = last.x, y = last.y, id = last.id }
    end
    while #out > N do out[#out] = nil end
    return out
end

-- Scaled to a unit box (keeping its shape), centred on its centroid
local function Normalize(strokes)
    local points = {}
    for id, stroke in ipairs(strokes) do
        for _, p in ipairs(stroke) do points[#points + 1] = { x = p.x, y = p.y, id = id } end
    end
    if #points < 2 then return nil end
    points = Resample(points)
    if not points then return nil end
    local minX, minY, maxX, maxY = huge, huge, -huge, -huge
    for _, p in ipairs(points) do
        minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
        minY, maxY = math.min(minY, p.y), math.max(maxY, p.y)
    end
    local size = math.max(maxX - minX, maxY - minY)
    if size <= 0 then return nil end
    local cx, cy = 0, 0
    for _, p in ipairs(points) do
        p.x, p.y = (p.x - minX) / size, (p.y - minY) / size
        cx, cy = cx + p.x, cy + p.y
    end
    cx, cy = cx / N, cy / N
    for _, p in ipairs(points) do p.x, p.y = p.x - cx, p.y - cy end
    return points
end

-- Each point of a matched to the nearest free one of b, from a's point
-- start on, the earlier pairs weighing more; stops once past best
local function CloudDistance(a, b, start, best)
    local matched = {}
    local sum, i = 0, start
    repeat
        local min, index = huge, 1
        local ax, ay = a[i].x, a[i].y
        for j = 1, N do
            if not matched[j] then
                local dx, dy = ax - b[j].x, ay - b[j].y
                local d = dx * dx + dy * dy
                if d < min then min, index = d, j end
            end
        end
        matched[index] = true
        sum = sum + (1 - ((i - start + N) % N) / N) * sqrt(min)
        if sum >= best then return sum end
        i = i % N + 1
    until i == start
    return sum
end

local STEP = floor(N ^ 0.5)

local function GreedyCloudMatch(points, template, best)
    for i = 1, N, STEP do
        best = math.min(best, CloudDistance(points, template, i, best), CloudDistance(template, points, i, best))
    end
    return best
end

-- (templates' clouds, made once)
local clouds
local function Clouds()
    if not clouds then
        clouds = {}
        for _, template in ipairs(TEMPLATES) do
            local cloud = Normalize(Expand(template))
            if cloud then clouds[#clouds + 1] = { char = template[1], points = cloud } end
        end
    end
    return clouds
end

---------------------------------------------------------------------------
-- A drawing read
---------------------------------------------------------------------------
-- (a box round points)
local function Bounds(points, box)
    box = box or { minX = huge, minY = huge, maxX = -huge, maxY = -huge }
    for _, p in ipairs(points) do
        box.minX, box.maxX = math.min(box.minX, p.x), math.max(box.maxX, p.x)
        box.minY, box.maxY = math.min(box.minY, p.y), math.max(box.maxY, p.y)
    end
    return box
end

local function Length(stroke)
    local d = 0
    for i = 2, #stroke do d = d + Dist(stroke[i - 1], stroke[i]) end
    return d
end

-- One letter's strokes read: the letter, then the letters it was nearest,
-- nearest first: { { char, distance }... } (nil, {}: none)
local function ReadLetter(strokes)
    local all = Bounds({})
    for _, stroke in ipairs(strokes) do Bounds(stroke, all) end
    if all.minX == huge then return nil, {} end
    local size = math.max(all.maxX - all.minX, all.maxY - all.minY)
    -- (the dots: next to nothing, beside the rest)
    local lines, dots = {}, 0
    for _, stroke in ipairs(strokes) do
        local box = Bounds(stroke)
        local extent = math.max(box.maxX - box.minX, box.maxY - box.minY)
        if #strokes > 1 and (#stroke < 3 or extent < size * 0.15) then
            dots = dots + 1
        else
            lines[#lines + 1] = stroke
        end
    end
    if #lines == 0 then return nil, {} end
    local points = Normalize(lines)
    if not points then return nil, {} end
    local nearest = {}
    for _, cloud in ipairs(Clouds()) do
        local d = GreedyCloudMatch(points, cloud.points, nearest[cloud.char] or huge)
        if d < (nearest[cloud.char] or huge) then nearest[cloud.char] = d end
    end
    local ranked = {}
    for char, d in pairs(nearest) do ranked[#ranked + 1] = { char, d } end
    table.sort(ranked, function(a, b) return a[2] < b[2] end)
    local char = ranked[1] and ranked[1][1]
    if char and dots > 0 and DOTTED[char] then char = DOTTED[char] end
    return char, ranked
end

-- A stroke's reach across, a little wider each side (a line straight down
-- has none of its own)
local function Reach(stroke)
    local box = Bounds(stroke)
    local margin = math.max(math.max(box.maxX - box.minX, box.maxY - box.minY) * 0.04, 0.02)
    return box.minX - margin, box.maxX + margin, box
end

-- (a stroke touching one of a letter's: any two points within reach)
local function Touches(stroke, strokes, reach)
    local r2 = reach * reach
    for _, other in ipairs(strokes) do
        for _, p in ipairs(stroke) do
            for _, q in ipairs(other) do
                local dx, dy = p.x - q.x, p.y - q.y
                if dx * dx + dy * dy <= r2 then return true end
            end
        end
    end
    return false
end

-- A word's strokes as its letters, left to right. Letters are written side
-- by side: a stroke reaching over one already there, or touching it, is
-- part of it (the bar of a t, the second stroke of an x, the arches of an
-- m), one over two joins them (the bar of an H between its legs), one clear
-- of them all starts a letter. A dot
-- (an i's) on its own goes with the letter nearest it.
function Letters.Split(strokes)
    local groups = {}
    for _, stroke in ipairs(strokes) do
        local lo, hi, box = Reach(stroke)
        local extent = math.max(box.maxX - box.minX, box.maxY - box.minY)
        local hits = {}
        for i, g in ipairs(groups) do
            local overlap = math.min(hi, g.hi) - math.max(lo, g.lo)
            if (overlap > 0 and overlap >= 0.3 * math.min(hi - lo, g.hi - g.lo))
                or Touches(stroke, g.strokes, math.max(extent * 0.06, 0.03)) then
                hits[#hits + 1] = i
            end
        end
        local dot = #stroke < 3 or extent < 0.1
        if #hits == 0 then
            groups[#groups + 1] = { lo = lo, hi = hi, strokes = { stroke }, dots = dot and 1 or 0 }
        else
            local into = groups[hits[1]]
            into.strokes[#into.strokes + 1] = stroke
            into.lo, into.hi = math.min(into.lo, lo), math.max(into.hi, hi)
            into.dots = into.dots + (dot and 1 or 0)
            for k = #hits, 2, -1 do
                local g = table.remove(groups, hits[k])
                for _, s in ipairs(g.strokes) do into.strokes[#into.strokes + 1] = s end
                into.lo, into.hi = math.min(into.lo, g.lo), math.max(into.hi, g.hi)
                into.dots = into.dots + g.dots
            end
        end
    end
    -- (dots on their own: to the letter nearest)
    for i = #groups, 1, -1 do
        local g = groups[i]
        if g.dots == #g.strokes and #groups > 1 then
            local centre, best, nearest = (g.lo + g.hi) / 2, huge, nil
            for _, other in ipairs(groups) do
                if other ~= g and other.dots < #other.strokes then
                    local d = math.max(other.lo - centre, centre - other.hi, 0)
                    if d < best then best, nearest = d, other end
                end
            end
            if nearest then
                for _, s in ipairs(g.strokes) do nearest.strokes[#nearest.strokes + 1] = s end
                nearest.dots = nearest.dots + g.dots
                table.remove(groups, i)
            end
        end
    end
    table.sort(groups, function(a, b) return a.lo < b.lo end)
    local letters = {}
    for i, g in ipairs(groups) do letters[i] = g.strokes end
    return letters
end

-- strokes: { { { x, y }... }... }, y down, in the pad's own units (its
-- shape kept: 1 is as far across as up), as drawn: a letter or a word.
-- minSwipe: how far across a lone stroke goes to be a space / a delete.
-- Returns what to type (the letters read, " ", or "\b" for a delete; nil:
-- nothing read), then each letter's guesses, nearest first:
-- { { { char, distance }... }... }
function Letters.Read(strokes, minSwipe)
    -- One stroke straight across: a space (to the right) or a delete
    if #strokes == 1 then
        local stroke = strokes[1]
        local box = Bounds(stroke)
        local w, h = box.maxX - box.minX, box.maxY - box.minY
        if w >= minSwipe and h <= w * 0.3 and Length(stroke) <= w * 1.4 then
            return stroke[#stroke].x > stroke[1].x and " " or "\b", {}
        end
    end
    local text, guesses = {}, {}
    for _, letter in ipairs(Letters.Split(strokes)) do
        local char, ranked = ReadLetter(letter)
        if char then
            text[#text + 1] = char
            guesses[#guesses + 1] = ranked
        end
    end
    if #text == 0 then return nil, guesses end
    return table.concat(text), guesses
end
