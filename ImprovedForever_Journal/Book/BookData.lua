-- A day of ours as the book's pages read a level of Social Diary's: its
-- road cut into stops and roads (from day.track, Journal.lua; before
-- there was one, from where things happened), its moments (a fall, a
-- level, a find, a hunt, someone met, a long stay, the longest road), its
-- plates (where they happened, grouped as Social Diary groups them), and
-- the lists its cards read (deaths, finds, hunts). Given as the names the
-- copied files look up: ns.Journey.For, ns.JourneyRecap.{Plates, Sheet,
-- Moments, Holds}, ns.db.characters.
local addonName, ns = ...
local IF = ImprovedForever
local J = IF.Journal

local BD = {}
ns.BookData = BD

---------------------------------------------------------------------------
-- Cutting the road (map units: 0 to 1 across the zone's map)
---------------------------------------------------------------------------
local R = 0.012                -- a stop: staying within this...
local DWELL = 180              -- ...this long (Social Diary's)...
local BUSY_DWELL = 30          -- ...or this long where something happened there
local GAP = 600                -- points this far apart in time: no road between
local JUMP = 0.15              -- nor this far apart on the map
local MOST = 64                -- a road's points at most
local STOP_YARDS = 40          -- a stop's spread drawn (the book's yards)

-- The day's points in order: the track where it was kept (it began
-- partway through a day, or not at all before there was one), and where
-- its events happened, all of it
local function Points(day)
    local pts = {}
    for _, p in ipairs(J.Track and J.Track(day) or {}) do pts[#pts + 1] = p end
    for _, e in ipairs(day.events) do
        if e.map and e.x and e.y and e.t then pts[#pts + 1] = { t = e.t, map = e.map, x = e.x, y = e.y } end
    end
    table.sort(pts, function(a, b) return a.t < b.t end)
    return pts
end

-- What happened at a stop, from the day's events in its time
local function Act(day, from, to)
    local act = { deaths = 0, combat = 0, questsIn = 0, questsOut = 0 }
    local subs = {}
    for _, e in ipairs(day.events) do
        if e.t and e.t >= from - 30 and e.t <= to + 30 then
            if e.k == "death" then act.deaths = act.deaths + 1
            elseif e.k == "hunt" then act.combat = act.combat + (e.n or 1) * 15
            elseif e.k == "kill" then act.combat = act.combat + 30
            elseif e.k == "accept" then act.questsIn = act.questsIn + 1
            elseif e.k == "quest" then act.questsOut = act.questsOut + 1 end
            if e.sub then subs[e.sub] = (subs[e.sub] or 0) + 1 end
        end
    end
    local sub, most = nil, 0
    for name, n in pairs(subs) do
        if n > most then sub, most = name, n end
    end
    return act, sub
end

-- The level at a time of the day
local function LevelAt(day, t)
    local level = day.stats.levelFrom or 1
    for _, e in ipairs(day.events) do
        if e.k == "level" and e.t <= t then level = e.level or level + 1 end
    end
    return level
end

-- A road's points, thinned to MOST, flat
local function Flat(list)
    local step = math.max(1, math.ceil(#list / MOST))
    local flat = {}
    for i = 1, #list, step do
        flat[#flat + 1], flat[#flat + 2] = list[i].x, list[i].y
    end
    local last = list[#list]
    if flat[#flat - 1] ~= last.x or flat[#flat] ~= last.y then flat[#flat + 1], flat[#flat + 2] = last.x, last.y end
    return flat
end

-- The day's segments: { kind = "stop" | "road", mapID, from, to, ... }
local function Segments(day)
    local pts = Points(day)
    local dwell = DWELL
    local segs, road = {}, nil
    local function CloseRoad()
        if road and #road.list >= 2 then
            local first, last = road.list[1], road.list[#road.list]
            segs[#segs + 1] = { kind = "road", mapID = road.map, from = first.t, to = last.t, pts = Flat(road.list),
                act = Act(day, first.t, last.t), levelFrom = LevelAt(day, first.t), levelTo = LevelAt(day, last.t) }
        end
        road = nil
    end
    local function OnRoad(p)
        local last = road and road.list[#road.list]
        if road and (road.map ~= p.map or p.t - last.t > GAP
            or math.sqrt((p.x - last.x) ^ 2 + (p.y - last.y) ^ 2) > JUMP) then
            CloseRoad()
        end
        road = road or { map = p.map, list = {} }
        road.list[#road.list + 1] = p
    end
    local i, n = 1, #pts
    while i <= n do
        local a = pts[i]
        -- (as long as it stays near where it began: a stop, if long enough)
        local sx, sy, k, j = a.x, a.y, 1, i
        while pts[j + 1] and pts[j + 1].map == a.map and pts[j + 1].t - pts[j].t <= GAP do
            local p = pts[j + 1]
            if math.sqrt((p.x - sx / k) ^ 2 + (p.y - sy / k) ^ 2) > R then break end
            sx, sy, k, j = sx + p.x, sy + p.y, k + 1, j + 1
        end
        local seconds = pts[j].t - a.t
        local busy = false
        if j > i and seconds >= BUSY_DWELL and seconds < dwell then
            local act = Act(day, a.t, pts[j].t)
            busy = act.deaths > 0 or act.combat >= 15 or act.questsIn + act.questsOut > 0
        end
        if j > i and (seconds >= dwell or busy) then
            local x, y = sx / k, sy / k
            OnRoad({ t = a.t, map = a.map, x = x, y = y })
            CloseRoad()
            local act, sub = Act(day, a.t, pts[j].t)
            segs[#segs + 1] = { kind = "stop", mapID = a.map, x = x, y = y, from = a.t, to = pts[j].t,
                seconds = seconds, r = STOP_YARDS, act = act, subZone = sub, levelFrom = LevelAt(day, a.t),
                levelTo = LevelAt(day, pts[j].t) }
            -- (the road on from it starts at its middle)
            road = { map = a.map, list = { { t = pts[j].t, map = a.map, x = x, y = y } } }
            i = j + 1
        else
            OnRoad(a)
            i = i + 1
        end
    end
    CloseRoad()
    return segs
end

---------------------------------------------------------------------------
-- People: our companions, by an id the book takes for a player's
---------------------------------------------------------------------------
local function Guid(name)
    return name and ("Player-IF-" .. name) or nil
end
BD.Guid = Guid

function BD.NameOf(guid)
    return type(guid) == "string" and guid:match("^Player%-IF%-(.+)$") or nil
end

-- Everyone met, as the book's characters ({ name, class, race, level })
function BD.People()
    local people = IF.charDB and IF.charDB.journal and IF.charDB.journal.people or {}
    local chars = ns.db.characters
    wipe(chars)
    for name, p in pairs(people) do
        chars[Guid(name)] = { name = name, class = p.classToken, race = p.raceToken, level = p.level,
            guild = p.guild, faction = p.faction }
    end
    return chars
end

-- The day's time together: a session a stretch someone was in my group,
-- from my joining a group (its members) to my leaving it, or from the
-- first event that names them to the last, no more than half an hour
-- apart; their seconds the time we were grouped
local TOGETHER_GAP = 1800
local function Sessions(day)
    local open, out = {}, {}
    local dayEnd = day.events[#day.events] and day.events[#day.events].t or 0
    local function Close(name, t)
        local s = open[name]
        if not s then return end
        s.endedAt = math.max(s.endedAt, t)
        open[name] = nil
    end
    local function Seen(name, e)
        local s = open[name]
        if s and e.t - s.endedAt > TOGETHER_GAP then Close(name, s.endedAt) s = nil end
        if not s then
            s = { startedAt = e.t, endedAt = e.t, participants = { [Guid(name)] = { seconds = 0 } }, name = name }
            open[name] = s
            out[#out + 1] = s
        end
        s.endedAt = e.t
        if not s.mapID and e.map and e.x then s.mapID, s.x, s.y = e.map, e.x, e.y end
    end
    for _, e in ipairs(day.events) do
        if e.k == "party" then
            for _, name in ipairs(e.members or {}) do Seen(name, e) end
        elseif e.k == "alone" then
            for name in pairs(open) do Close(name, e.t) end
        end
        for _, name in ipairs(e.group or {}) do Seen(name, e) end
    end
    -- (still grouped at the day's end: till then)
    for name, s in pairs(open) do s.endedAt = math.max(s.endedAt, dayEnd) end
    for _, s in ipairs(out) do
        s.participants[Guid(s.name)].seconds = math.max(60, s.endedAt - s.startedAt)
    end
    return out
end

---------------------------------------------------------------------------
-- Firsts: the first item of a quality the journal ever kept (Journal.lua
-- keeps them, set once), as Social Diary's find records, by day
---------------------------------------------------------------------------
local QUALITY_WHAT = { [2] = "uncommon", [3] = "rare", [4] = "epic" }

local function Link(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, link = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return link or ("item:" .. id)
end

local function FirstsOf(key)
    local out = {}
    for q, f in pairs(J.Firsts and J.Firsts() or {}) do
        if f.key == key and QUALITY_WHAT[q] then
            out[#out + 1] = { what = QUALITY_WHAT[q], rec = { link = Link(f.item), t = f.t, mapID = f.map, x = f.x,
                y = f.y, from = "loot" } }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Hunts: a task's drops and the kills they took, judged by Social Diary's
-- rules (its Hunts/Kind.lua, copied: bad luck, good luck, the drop rates
-- from QuestieDB where it's installed). The kills: those in the task's
-- land between taking it on and having them all; the creature, the one
-- slain most among them
---------------------------------------------------------------------------
local function ItemID(name)
    if not name then return nil end
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local id = get and get(name)
    return type(id) == "number" and id or nil
end

local function Hunts(day)
    local out = {}
    local since = {}           -- [quest id] = when I took it on (today)
    local foeIDs = day.stats.foeIDs or {}
    for _, e in ipairs(day.events) do
        if e.k == "accept" and e.id then since[e.id] = e.t end
        if e.k == "ready" and e.how == "item" and (e.need or 0) > 0 then
            local from = since[e.id] or day.events[1].t
            local kills, byName = 0, {}
            for _, h in ipairs(day.events) do
                if h.k == "hunt" and h.t >= from and h.t <= e.t and h.zone == e.zone then
                    kills = kills + (h.n or 1)
                    for name, n in pairs(h.foes or {}) do byName[name] = (byName[name] or 0) + n end
                end
            end
            local top, most = nil, 0
            for name, n in pairs(byName) do
                if n > most then top, most = name, n end
            end
            local npc = top and foeIDs[top]
            local looks = IF.WorldData and IF.WorldData.displays or {}
            local hunt = { kills = kills, need = e.need, shared = 0, item = e.what, title = e.name, questID = e.id,
                itemID = ItemID(e.what), npcID = npc, name = top, display = npc and looks[npc], t = e.t,
                mapID = e.map, x = e.x, y = e.y, level = day.stats.levelTo }
            if kills > 0 then
                if ns.Hunts.Rated then pcall(ns.Hunts.Rated, hunt) end
                out[#out + 1] = hunt
            end
        end
    end
    return out
end

-- Close calls: a fight left at a tenth of my health or less (Journal.lua's
-- "close"), as Social Diary keeps them
local function CloseCalls(day)
    local out = {}
    local foeIDs = day.stats.foeIDs or {}
    local looks = IF.WorldData and IF.WorldData.displays or {}
    for _, e in ipairs(day.events) do
        if e.k == "close" and e.map and e.x then
            local npc = e.by and foeIDs[e.by]
            local pct = math.max(1, math.min(15, e.health or 10))
            out[#out + 1] = { t = e.t, mapID = e.map, x = e.x, y = e.y, level = day.stats.levelTo, pct = pct,
                took = 100 - pct, seconds = 0, npcID = npc, name = e.by, rank = "normal", foes = 1,
                display = npc and looks[npc] }
        end
    end
    return out
end

-- Profession caps: a skill reaching its trainer's most (75, 150, 225, 300)
local CAPS = { [75] = true, [150] = true, [225] = true, [300] = true }
local function SkillCaps(day)
    local out = {}
    for _, e in ipairs(day.events) do
        if e.k == "skill" and CAPS[e.rank or 0] then
            out[#out + 1] = { t = e.t, mapID = e.map, x = e.x, y = e.y, level = day.stats.levelTo, name = e.name,
                rank = e.rank }
        end
    end
    return out
end

-- Duels, one after another with one player one series, as Social Diary's
local SERIES_GAP = 15 * 60
local function Duels(day)
    local out, last = {}, {}
    for _, e in ipairs(day.events) do
        if e.k == "duel" and e.opponent then
            local rec = last[e.opponent]
            if not (rec and e.t - rec.ended <= SERIES_GAP) then
                rec = { t = e.t, guid = Guid(e.opponent), mapID = e.map, x = e.x, y = e.y, subZone = e.sub, zone = e.zone }
                out[#out + 1] = rec
                last[e.opponent] = rec
            end
            local key = e.won and "won" or "lost"
            rec[key] = (rec[key] or 0) + 1
            rec.last, rec.ended = key, e.t
        end
    end
    return out
end

---------------------------------------------------------------------------
-- A day, read: the entry the pages draw
---------------------------------------------------------------------------
local cache = {}

function BD.Day(key)
    local day = J.Day(key)
    if not day then return nil end
    local stamp = #day.events .. ":" .. (day.trackN or 0)
    local c = cache[key]
    if c and c.stamp == stamp then return c end
    local segs = Segments(day)
    local first = day.events[1] and day.events[1].t or (day.sessions and day.sessions[1] and day.sessions[1].from) or time()
    local last = day.events[#day.events] and day.events[#day.events].t or first
    for _, s in ipairs(segs) do
        first, last = math.min(first, s.from), math.max(last, s.to)
    end
    local stats = day.stats
    local e = { kind = "level", key = key, level = stats.levelTo or stats.levelFrom or 1, from = first, to = last + 1,
        deaths = {}, finds = {}, hunts = {} }
    -- (the last level reached: the plate's pin, the level's out)
    for _, ev in ipairs(day.events) do
        if ev.k == "level" and ev.map then e.out = { level = ev.level, mapID = ev.map, x = ev.x, y = ev.y, at = ev.t } end
    end
    -- The journey the cards read
    local j = { key = key, segs = segs, deaths = {}, firsts = {}, hunts = Hunts(day), sessions = Sessions(day),
        closeCalls = CloseCalls(day), skillCaps = SkillCaps(day), duels = Duels(day) }
    local foeIDs = stats.foeIDs or {}
    local looks = IF.WorldData and IF.WorldData.displays or {}
    for _, ev in ipairs(day.events) do
        if ev.k == "death" and ev.map and ev.x then
            local npc = ev.by and foeIDs[ev.by]
            j.deaths[#j.deaths + 1] = { t = ev.t, mapID = ev.map, x = ev.x, y = ev.y, name = ev.by, npcID = npc,
                rank = ev.named and "elite" or "normal", display = npc and looks[npc] or nil }
        end
    end
    for _, f in ipairs(FirstsOf(key)) do j.firsts[#j.firsts + 1] = f end
    e.hunts = j.hunts
    c = { stamp = stamp, e = e, j = j, day = day }
    cache[key] = c
    return c
end

-- The stop holding a time on a map, else a point of its own
local function SegAt(j, t, mapID, x, y)
    for _, s in ipairs(j.segs) do
        if s.kind == "stop" and s.mapID == mapID and t >= s.from - 60 and t <= s.to + 60 then return s end
    end
    return { kind = "stop", mapID = mapID, x = x, y = y, from = t, to = t, seconds = 0, r = STOP_YARDS }
end

-- Its moments on a map ({ kind, mapID, x, y, t, ... })
local function Moments(c)
    local e, j, day = c.e, c.j, c.day
    local list = {}
    local function Add(m, map, x, y)
        if not (map and x and y) then return end
        m.mapID, m.x, m.y = map, x, y
        list[#list + 1] = m
    end
    for _, s in ipairs(j.sessions) do
        for guid, p in pairs(s.participants) do
            Add({ kind = "session", guid = guid, t = s.startedAt, session = s, seconds = p.seconds }, s.mapID, s.x, s.y)
        end
    end
    for _, d in ipairs(j.deaths) do
        local seg = SegAt(j, d.t, d.mapID, d.x, d.y)
        Add({ kind = "death", t = d.t, seg = seg }, d.mapID, d.x, d.y)
    end
    for _, ev in ipairs(day.events) do
        if ev.k == "level" then Add({ kind = "level", level = ev.level, t = ev.t, out = true }, ev.map, ev.x, ev.y) end
    end
    for _, f in ipairs(j.firsts) do
        Add({ kind = "find", what = f.what, find = f.rec, t = f.rec.t }, f.rec.mapID, f.rec.x, f.rec.y)
    end
    local H = ns.Hunts
    for _, h in ipairs(j.hunts) do
        local bad = H.BadLuck and select(2, pcall(H.BadLuck, j, h, false))
        local good = H.GoodLuck and select(2, pcall(H.GoodLuck, h))
        if bad == true then Add({ kind = "luck", hunt = h, t = h.t }, h.mapID, h.x, h.y)
        elseif good == true then Add({ kind = "fortune", hunt = h, t = h.t }, h.mapID, h.x, h.y) end
    end
    for _, call in ipairs(j.closeCalls) do Add({ kind = "close", call = call, t = call.t }, call.mapID, call.x, call.y) end
    for _, cap in ipairs(j.skillCaps) do Add({ kind = "skill", cap = cap, t = cap.t }, cap.mapID, cap.x, cap.y) end
    for _, duel in ipairs(j.duels) do Add({ kind = "duel", duel = duel, t = duel.t }, duel.mapID, duel.x, duel.y) end
    -- (the longest stays, one a map, and the longest road)
    local best, longest = {}, nil
    for _, s in ipairs(j.segs) do
        if s.kind == "stop" and s.seconds >= 600 and (not best[s.mapID] or s.seconds > best[s.mapID].seconds) then
            best[s.mapID] = s
        elseif s.kind == "road" and (not longest or (s.to - s.from) > (longest.to - longest.from)) then
            longest = s
        end
    end
    for _, s in pairs(best) do Add({ kind = "stay", t = s.from, seg = s, seconds = s.seconds }, s.mapID, s.x, s.y) end
    if longest then
        local pts = longest.pts
        local mid = math.floor(#pts / 4) * 2 + 1
        Add({ kind = "road", t = longest.from, seg = longest, seconds = longest.to - longest.from }, longest.mapID,
            pts[mid], pts[mid + 1])
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    return list
end

---------------------------------------------------------------------------
-- The plates: Social Diary's grouping (Core/JourneyRecap.lua's Plates),
-- copied: moments go into the first plate whose window they fit, the
-- most telling first; at most three, oldest first
---------------------------------------------------------------------------
local PLATES = { max = 3, inset = 0.8, window = 0.3 }
local RANK = { session = 1, fight = 1, note = 1, first = 1, find = 2, skill = 2, luck = 3, fortune = 3, close = 3,
    death = 3, arrive = 4, dungeon = 5, stay = 6, duel = 6.5, road = 7, level = 8 }
local LIGHT = { arrive = true, dungeon = true, stay = true, road = true, level = true, fortune = true, skill = true,
    duel = true }

local function Rank(m) return RANK[m.kind] or 9 end
local function ByTime(a, b) return a.t < b.t end

local function Fits(plate, m, w, h)
    if plate.mapID ~= m.mapID then return false end
    local x0, x1 = math.min(plate.x0, m.x), math.max(plate.x1, m.x)
    local y0, y1 = math.min(plate.y0, m.y), math.max(plate.y1, m.y)
    return x1 - x0 <= w * PLATES.inset and y1 - y0 <= h * PLATES.inset
end

local function Holds(plate, w, h)
    return plate.x1 - plate.x0 <= w * PLATES.inset and plate.y1 - plate.y0 <= h * PLATES.inset
end

local function Plates(list, cover)
    local moments = {}
    for i, m in ipairs(list) do moments[i] = m end
    table.sort(moments, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        return a.t < b.t
    end)
    local plates = {}
    for _, m in ipairs(moments) do
        local w, h = cover(m.mapID)
        w, h = w or PLATES.window, h or PLATES.window
        local into
        for _, plate in ipairs(plates) do
            if Fits(plate, m, w, h) then
                into = plate
                break
            end
        end
        if into then
            into.x0, into.x1 = math.min(into.x0, m.x), math.max(into.x1, m.x)
            into.y0, into.y1 = math.min(into.y0, m.y), math.max(into.y1, m.y)
            into.moments[#into.moments + 1] = m
            into.t = math.min(into.t, m.t)
        else
            local rank, shown = Rank(m), false
            for _, plate in ipairs(plates) do shown = shown or plate.mapID == m.mapID end
            local opens = m.kind ~= "level" and (rank < RANK.stay or (rank == RANK.stay and not shown))
            if opens or #plates == 0 then
                plates[#plates + 1] = { mapID = m.mapID, x0 = m.x, x1 = m.x, y0 = m.y, y1 = m.y,
                    t = m.t, rank = rank, moments = { m } }
            end
        end
    end
    table.sort(plates, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if #a.moments ~= #b.moments then return #a.moments > #b.moments end
        return a.t < b.t
    end)
    for i = #plates, PLATES.max + 1, -1 do plates[i] = nil end
    for _, plate in ipairs(plates) do
        plate.cx, plate.cy = (plate.x0 + plate.x1) / 2, (plate.y0 + plate.y1) / 2
        table.sort(plate.moments, ByTime)
        plate.light = true
        for _, m in ipairs(plate.moments) do plate.light = plate.light and LIGHT[m.kind] == true end
    end
    table.sort(plates, ByTime)
    return plates
end

---------------------------------------------------------------------------
-- What the copied files ask for, over the day being read (BD.Use)
---------------------------------------------------------------------------
local current

-- An entry's moments: the day's
local function MomentsFor()
    return current and current.moments or {}
end
BD.MomentsFor = MomentsFor

-- The day the pages read from now on (its key); its entry
function BD.Use(key)
    current = BD.Day(key)
    if not current then return nil end
    current.moments = current.moments or Moments(current)
    return current.e
end

function BD.Current() return current end

ns.Journey.For = function() return current and current.j or nil end
ns.Journey.List = function(j, list) return j and j[list] or {} end

ns.JourneyRecap.Holds = Holds
ns.JourneyRecap.Moments = function(_, e) return MomentsFor(e) end
ns.JourneyRecap.Plates = function(_, e, _, cover)
    if not current then return {} end
    return Plates(MomentsFor(e), cover)
end
ns.JourneyRecap.Sheet = function(_, mapID)
    local sheet = { mapID = mapID, stops = {}, roads = {}, flights = {}, dungeons = {}, pins = {}, meetings = {} }
    if not current then return sheet end
    for _, s in ipairs(current.j.segs) do
        if s.mapID == mapID then
            if s.kind == "stop" then sheet.stops[#sheet.stops + 1] = s else sheet.roads[#sheet.roads + 1] = s end
        end
    end
    for _, ev in ipairs(current.day.events) do
        if ev.k == "level" and ev.map == mapID and ev.x then
            sheet.pins[#sheet.pins + 1] = { level = ev.level, x = ev.x, y = ev.y, at = ev.t }
        end
    end
    for _, s in ipairs(current.j.sessions) do
        if s.mapID == mapID then
            sheet.meetings[#sheet.meetings + 1] = { kind = "session", t = s.startedAt, x = s.x, y = s.y, session = s,
                level = LevelAt(current.day, s.startedAt) }
        end
    end
    return sheet
end
