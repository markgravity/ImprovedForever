-- Journal: what the character does, kept a day at a time (this file), then
-- written as a diary (JournalWriter.lua) and read in the core's book
-- (JournalBook.lua). Kept per character, IF.charDB.journal:
--   { v = 1, days = { ["YYYY-MM-DD"] = day } }
--   day = { events = { { t, rm, k, ... } }, sessions = { { from, to, rfrom, rto } },
--     stats = { levelFrom, levelTo, xp, kills, deaths, quests, played,
--     money = { earned, spent }, foes = { [name] = count }, foeKinds (how many
--     names), foeIDs = { [name] = npc }, zones = { [name] = seconds } } }
-- Every event also has zone and sub (the land and the area in it) and
-- where on the map it happened (map, x, y: 0-1; none in an instance).
-- Days and times are the realm's clock (its calendar): a day's key, rm (an
-- event's realm time, minutes past midnight), a session's rfrom / rto; the
-- local time kept beside it (t, from, to: epoch seconds), to convert later.
-- An event's k: "level" (level), "accept" (id, name, giver, goal = { { what,
-- how, need } }: what the task asks), "quest" (id, name, giver, ender, xp,
-- money, reward: an item id), "zone" (name, map), "discover" (name, zone), "instance" (name),
-- "flight" (from, to), "hearth" (to), "hunt" (zone, sub, foes = { [name] =
-- count }, n, coin, last: kills one after another in a place), "kill" (name,
-- npc, class, level, zone: an elite, a rare, a boss), "death" (zone, sub,
-- map, x, y, by, named: an elite's or a rare's doing), "loot" / "create" (item, count), "skill" (name, rank),
-- "learn" (name), "ready" (id, name, what, how: a task done, the objective
-- that did it; to be handed in), "objective" (id, name, what, how: one of a
-- task's several; giver), "dive" (under water: the breath running), "money" (amount: + earned, - spent; src: "sale" (an
-- auction sold, by mail; what = { items }), "refund", "letter" (from), "mail",
-- "sell", "buy", "repair", "auction", "flight", "training", "other").
-- No combat log in Forever, nor nameplates: kills come from the experience
-- they give, a foe's rank from the target it was.
local IF = ImprovedForever

local J = {}
IF.Journal = J

-- A value the game hides from addons (Forever's secrets): never read
local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local MAX_EVENTS = 400         -- a day's events kept (its counts go on)
local MAX_FOES = 60            -- foes counted by name a day
local TICK = 10                -- the played time's step (seconds)
local SESSION_GAP = 300        -- away longer than this: a new session (a /reload isn't)
local HUNT_GAP = 600           -- kills this far apart (or elsewhere): another hunt
local HINT_FOR = 5             -- what a change in money is for, this long after it's known
local HEARTHSTONE = 8690       -- the hearthstone's spell (Forever's)
local NOTABLE = { elite = "Elite", rareelite = "Rare Elite", rare = "Rare", worldboss = "Boss" }
J.NOTABLE = NOTABLE

---------------------------------------------------------------------------
-- Settings: IF.db.journal = { enabled, levels, places, fights, loot,
-- minQuality, keepDays }
---------------------------------------------------------------------------
local DEFAULTS = { enabled = true, levels = true, places = true, fights = true, loot = true,
    minQuality = 2, keepDays = 365 }

function J.Settings()
    local s = IF.db.journal or {}
    IF.db.journal = s
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    -- (the event probe's logs, gone with it)
    IF.db.journalLog, IF.db.journalLogPrev = nil, nil
    return s
end

local function On(group)
    if not IF.db then return false end
    local s = J.Settings()
    return s.enabled and (group == nil or s[group])
end

---------------------------------------------------------------------------
-- The store
---------------------------------------------------------------------------
local function Store()
    local db = IF.charDB.journal or { v = 1, days = {} }
    IF.charDB.journal = db
    return db
end

-- The realm's clock: today's key, the minutes past midnight (its calendar;
-- before it's ready, the game time and the local date)
function J.Realm()
    local c = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if c and (c.year or 0) > 0 then
        return format("%04d-%02d-%02d", c.year, c.month, c.monthDay), c.hour * 60 + c.minute
    end
    local h, m = GetGameTime()
    return date("%Y-%m-%d"), (h or 0) * 60 + (m or 0)
end

function J.TodayKey()
    return (J.Realm())
end

local function RealmMinutes()
    return select(2, J.Realm())
end

-- A day's key as a time (its noon)
function J.KeyTime(key)
    local y, m, d = tostring(key):match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

-- A day's record (made for today when asked: kept from then on)
function J.Day(key)
    local days = Store().days
    key = key or J.TodayKey()
    local day = days[key]
    if not day and key == J.TodayKey() then
        local level = UnitLevel("player") or 1
        day = { events = {}, sessions = {}, stats = { levelFrom = level, levelTo = level, xp = 0, kills = 0, deaths = 0,
            quests = 0, played = 0, money = { earned = 0, spent = 0 }, foes = {}, foeIDs = {}, zones = {} } }
        days[key] = day
    end
    return day
end

-- The days written, the newest first
function J.Days()
    local keys = {}
    for key, day in pairs(Store().days) do
        if #day.events > 0 or (day.stats.played or 0) > 0 then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return a > b end)
    return keys
end

local listeners = {}
function J.OnChange(fn) listeners[#listeners + 1] = fn end

local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local function Zone()
    local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
    return zone ~= "" and zone or nil
end

local function Sub()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    return sub ~= "" and sub or nil
end

local function Add(kind, fields)
    local day = J.Day()
    if #day.events >= MAX_EVENTS then return end
    fields.t, fields.rm, fields.k = time(), RealmMinutes(), kind
    fields.zone = fields.zone or (kind ~= "flight" and kind ~= "hearth" and Zone() or nil)
    fields.sub = fields.sub or (kind ~= "flight" and kind ~= "hearth" and Sub() or nil)
    if fields.x == nil and kind ~= "flight" and kind ~= "hearth" then
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and not Secret(x) then
                fields.map = fields.map or map
                fields.x, fields.y = math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000
            end
        end
    end
    day.events[#day.events + 1] = fields
    Changed()
    return fields
end

-- The last event of a kind today matching fn, or nil
local function Last(kind, fn)
    local events = J.Day().events
    for i = #events, 1, -1 do
        local e = events[i]
        if e.k == kind and (not fn or fn(e)) then return e end
    end
end

-- The session going on (a new one after a while away), its end now
local function Session()
    local day = J.Day()
    day.sessions = day.sessions or {}
    local s = day.sessions[#day.sessions]
    local now, rm = time(), RealmMinutes()
    if not s or now - s.to > SESSION_GAP then
        s = { from = now, rfrom = rm }
        day.sessions[#day.sessions + 1] = s
    end
    s.to, s.rto = now, rm
end

-- Days past keepDays thrown away
local function Prune()
    local keep = J.Settings().keepDays or 0
    if keep <= 0 then return end
    local oldest = time() - keep * 86400
    local days = Store().days
    for key in pairs(days) do
        local t = J.KeyTime(key)
        if t and t < oldest then days[key] = nil end
    end
end

function J.Clear()
    wipe(Store().days)
    Changed()
end

function J.EventCount()
    local n = 0
    for _, day in pairs(Store().days) do n = n + #day.events end
    return n
end

---------------------------------------------------------------------------
-- Reading the game's messages: its own format strings made patterns, so
-- they read in any language ("%s dies, you gain %d experience.")
---------------------------------------------------------------------------

-- open: the start only (a message that may go on: rested bonus...)
local function Pattern(fmt, open)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%d?%$?([sd])", "\001%1")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\001s", "(.-)"):gsub("\001d", "(%%d+)")
    if open then return "^" .. p:gsub("%%%.$", "") end
    return "^" .. p .. "$"
end

local function Patterns(open, ...)
    local out = {}
    for i = 1, select("#", ...) do
        local p = Pattern(select(i, ...), open)
        if p then out[#out + 1] = p end
    end
    return out
end

local function Match(msg, patterns)
    if type(msg) ~= "string" or Secret(msg) then return nil end
    for _, p in ipairs(patterns) do
        local a, b = msg:match(p)
        if a then return a, b end
    end
end

local P = {}
local function BuildPatterns()
    P.kill = { Pattern(_G.COMBATLOG_XPGAIN_FIRSTPERSON, true) }
    -- (the start only: Forever's lines have no full stop)
    P.loot = Patterns(true, _G.LOOT_ITEM_SELF)
    P.pushed = Patterns(true, _G.LOOT_ITEM_PUSHED_SELF)
    P.create = Patterns(true, _G.LOOT_ITEM_CREATED_SELF)
    P.skill = Patterns(false, _G.SKILL_RANK_UP)
    P.discover = Patterns(false, _G.ERR_ZONE_EXPLORED_XP, _G.ERR_ZONE_EXPLORED)
    P.learn = Patterns(false, _G.ERR_LEARN_RECIPE_S, _G.ERR_LEARN_SPELL_S, _G.ERR_LEARN_ABILITY_S)
    P.sold = Patterns(false, _G.AUCTION_SOLD_MAIL_SUBJECT)
    P.outbid = Patterns(false, _G.AUCTION_OUTBID_MAIL_SUBJECT)
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("|Hitem:(%d+)")) or nil
end

local function Quality(id)
    if C_Item and C_Item.GetItemQualityByID then
        local q = C_Item.GetItemQualityByID(id)
        if q then return q end
    end
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    return select(3, get(id))
end

---------------------------------------------------------------------------
-- Levels and quests
---------------------------------------------------------------------------
local questNames = {}           -- [id] = name: as the quest log said it (a task handed in is gone from it)
local givers = {}               -- [id] = the one who gave the task (its accept's, else QuestieDB's)
local talking                   -- { name, at }: the one whose quest window was open last
local lastPushed                -- { id, at }: the item last given ("You receive item: ...")
local rewardFor                 -- { event, at }: a task just handed in, waiting for its reward

local function Talking()
    local name = UnitName("npc")
    if name and not Secret(name) and not UnitIsPlayer("npc") then talking = { name = name, at = GetTime() } end
end

local function Recent(what, within)
    return what and GetTime() - what.at < within and what or nil
end

-- A quest's giver (startedBy) or ender (finishedBy) in QuestieDB's data
local function QuestNpc(id, field)
    local GD = IF.GameData
    local Q = GD and GD.Q and GD.Q()
    local by = Q and GD.Field(Q.Quest, id, field)
    local npc = by and by[1] and by[1][1]
    return npc and GD.Field(Q.Npc, npc, "name") or nil
end

function J.Giver(id)
    if givers[id] == nil then givers[id] = QuestNpc(id, "startedBy") or false end
    return givers[id] or nil
end

function J.Ender(id)
    return QuestNpc(id, "finishedBy")
end

local function QuestName(id, index)
    local name = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if (not name or name == "") then name = questNames[id] end
    if (not name or name == "") and index and GetQuestLogTitle then name = GetQuestLogTitle(index) end
    if (not name or name == "") and IF.GameData and IF.GameData.Q then
        local Q = IF.GameData.Q()
        name = Q and IF.GameData.Field(Q.Quest, id, "name")
    end
    return name
end

local function LevelUp(level)
    if not On("levels") or Secret(level) then return end
    local day = J.Day()
    day.stats.levelTo = math.max(day.stats.levelTo or 0, tonumber(level) or UnitLevel("player"))
    Add("level", { level = level })
end

-- (Classic: index, id; later clients: id)
local function Accepted(a, b)
    if not On("levels") then return end
    local id, index = b or a, b and a or nil
    if Secret(id) or type(id) ~= "number" then return end
    local npc = Recent(talking, 120)
    givers[id] = npc and npc.name or J.Giver(id) or false
    Add("accept", { id = id, name = QuestName(id, index), zone = Zone(), giver = givers[id] or nil })
end

local function TurnedIn(id, xp, money)
    if not On("levels") or Secret(id) or type(id) ~= "number" then return end
    local day = J.Day()
    xp, money = not Secret(xp) and tonumber(xp) or 0, not Secret(money) and tonumber(money) or 0
    day.stats.quests = day.stats.quests + 1
    day.stats.xp = day.stats.xp + xp
    if money > 0 then J.Claim("quest", money) end
    local npc = Recent(talking, 60)
    local e = Add("quest", { id = id, name = QuestName(id), zone = Zone(), xp = xp > 0 and xp or nil,
        money = money > 0 and money or nil, giver = J.Giver(id),
        ender = npc and npc.name or QuestNpc(id, "finishedBy") })
    -- (its reward: the item given with it, just before or just after)
    local pushed = Recent(lastPushed, 3)
    if e and pushed then
        e.reward, lastPushed = pushed.id, nil
    elseif e then
        rewardFor = { event = e, at = GetTime() }
    end
end

-- A task's progress: the quest log read again as it changes; a task now
-- done (to be handed in: "ready"), one objective of several done
-- ("objective"), each with the objective that did it
local quests                   -- [id] = { done, fin = { [i] = finished } }; nil: not read yet

local function QuestLog()
    local C, out = C_QuestLog, {}
    if C and C.GetNumQuestLogEntries and C.GetInfo then
        for i = 1, C.GetNumQuestLogEntries() do
            local info = C.GetInfo(i)
            if info and not info.isHeader and (info.questID or 0) > 0 then
                out[#out + 1] = { id = info.questID, name = info.title, done = info.isComplete }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() do
            local title, _, _, header, _, complete, _, id = GetQuestLogTitle(i)
            if not header and id then out[#out + 1] = { id = id, name = title, done = complete } end
        end
    end
    for _, q in ipairs(out) do
        if C and C.IsComplete then q.done = C.IsComplete(q.id) else q.done = q.done == true or q.done == 1 end
        q.objs = C and C.GetQuestObjectives and C.GetQuestObjectives(q.id) or {}
    end
    return out
end

-- "Lost Tools: 1/1" -> "Lost Tools"; "Murloc Scout slain: 8/8" -> "Murloc Scout"
local function Objective(o)
    local text = tostring(o.text or "")
    text = text:gsub("^%d+%s*/%s*%d+%s*", ""):gsub(":?%s*%d+%s*/%s*%d+$", ""):gsub("%s+slain$", "")
    return text ~= "" and text or nil, o.type
end

-- What a task in the log asks: { { what, how, need } }, or nil (not in it)
function J.Goal(id)
    local C = C_QuestLog
    local ok, objs = pcall(function() return C and C.GetQuestObjectives and C.GetQuestObjectives(id) end)
    if not ok or type(objs) ~= "table" or #objs == 0 then return nil end
    local goal = {}
    for i, o in ipairs(objs) do
        local what, how = Objective(o)
        goal[i] = { what, how, o.numRequired or tonumber(tostring(o.text or ""):match("/%s*(%d+)")) }
    end
    return goal
end

local function ScanQuests()
    local ok, log = pcall(QuestLog)
    if not ok then return end
    local first = quests == nil
    local was = quests or {}
    quests = {}
    for _, q in ipairs(log) do
        if q.name and not Secret(q.name) then questNames[q.id] = q.name end
        local fin, last = {}, nil
        local before = was[q.id]
        for i, o in ipairs(q.objs) do
            fin[i] = o.finished and true or false
            if fin[i] and before and not before.fin[i] then last = o end
        end
        if before and not first and On("levels") then
            local what, how
            if last then what, how = Objective(last) end
            if q.done and not before.done then
                Add("ready", { id = q.id, name = q.name, what = what, how = how, giver = J.Giver(q.id) })
            elseif last and #q.objs > 1 then
                Add("objective", { id = q.id, name = q.name, what = what, how = how, giver = J.Giver(q.id) })
            end
        end
        -- (a task just taken: what it asks, on its accept)
        if not before and not first and #q.objs > 0 then
            local accept
            for i = #J.Day().events, 1, -1 do
                local ev = J.Day().events[i]
                if ev.k == "accept" and ev.id == q.id then accept = ev break end
            end
            if accept and not accept.goal then
                accept.goal = {}
                for i, o in ipairs(q.objs) do
                    local what, how = Objective(o)
                    accept.goal[i] = { what, how, o.numRequired or tonumber(tostring(o.text or ""):match("/%s*(%d+)")) }
                end
                Changed()
            end
        end
        quests[q.id] = { done = q.done and true or false, fin = fin }
    end
end

local scanPending = false
local function QuestLogChanged()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.5, function()
        scanPending = false
        ScanQuests()
    end)
end

-- Under water: the breath running out (once a place, a while)
local function Breath(timer)
    if timer ~= "BREATH" or not On("places") then return end
    local sub, last = Sub(), nil
    local events = J.Day().events
    for i = #events, 1, -1 do
        if events[i].k == "dive" then last = events[i] break end
    end
    if last and last.sub == sub and last.zone == Zone() and time() - last.t < HUNT_GAP then return end
    Add("dive", {})
end

---------------------------------------------------------------------------
-- Places: zones (the first visit of the day, the time in each), new
-- areas, instances, flights, the hearthstone
---------------------------------------------------------------------------
local here                     -- the zone the player is in
local flying                   -- the zone a flight began in

local function ZoneChanged()
    here = Zone()
    if not here or not On("places") then return end
    if not Last("zone", function(e) return e.name == here end) then
        Add("zone", { name = here, zone = here, map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") })
    end
end

local function EnteredWorld()
    ZoneChanged()
    if not On("places") then return end
    local inside, kind = IsInInstance()
    if inside and (kind == "party" or kind == "raid") then
        local name = GetInstanceInfo()
        local last = J.Day().events[#J.Day().events]
        if name and not (last and last.k == "instance" and last.name == name) then
            Add("instance", { name = name, kind = kind })
        end
    end
end

local function ControlChanged(event)
    if not On("places") then return end
    if event == "PLAYER_CONTROL_LOST" then
        C_Timer.After(0.5, function()
            if UnitOnTaxi("player") then flying = here or Zone() or "" end
        end)
    elseif flying then
        local from = flying
        flying = nil
        C_Timer.After(1, function()
            local to = Zone()
            if to then Add("flight", { from = from ~= "" and from or nil, to = to }) end
        end)
    end
end

local function SpellCast(unit, _, spell)
    if unit ~= "player" or Secret(spell) or spell ~= HEARTHSTONE or not On("places") then return end
    Add("hearth", { to = GetBindLocation and GetBindLocation() or nil })
end

---------------------------------------------------------------------------
-- Fights and deaths: a kill is the experience it gives ("Hogger dies, you
-- gain 120 experience."); its rank and id, the target it was
---------------------------------------------------------------------------
local targets = {}             -- [name] = { class, npc, level, at }
local lastFoe                  -- { name, at }: the last hostile target

local function NpcID(guid)
    if type(guid) ~= "string" or Secret(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return (kind == "Creature" or kind == "Vehicle") and tonumber(id) or nil
end

local function TargetChanged()
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitCanAttack("player", "target") then return end
    local name = UnitName("target")
    if not name or Secret(name) then return end
    local class = UnitClassification("target")
    targets[name] = { class = not Secret(class) and class or nil, npc = NpcID(UnitGUID("target")),
        level = not Secret(UnitLevel("target")) and UnitLevel("target") or nil, at = GetTime() }
    lastFoe = { name = name, at = GetTime() }
end

local function Killed(msg)
    local name, xp = Match(msg, P.kill)
    if not name or not On("fights") then return end
    local s = J.Day().stats
    s.kills = s.kills + 1
    s.xp = s.xp + (tonumber(xp) or 0)
    if not s.foes[name] and (s.foeKinds or 0) < MAX_FOES then
        s.foeKinds = (s.foeKinds or 0) + 1
        s.foes[name] = 0
    end
    if s.foes[name] then s.foes[name] = s.foes[name] + 1 end
    local seen = targets[name]
    if seen and seen.npc then s.foeIDs[name] = seen.npc end
    local notable = seen and NOTABLE[seen.class or ""]
    -- (an elite, a rare, a boss: a line of its own, not one of the hunt's)
    local hunt = not notable and J.Hunt()
    if not hunt and not notable then
        local sub = GetSubZoneText and GetSubZoneText() or ""
        hunt = Add("hunt", { zone = Zone(), sub = sub ~= "" and sub or nil, foes = {}, n = 0 })
    end
    if hunt then
        hunt.foes[name] = (hunt.foes[name] or 0) + 1
        hunt.n, hunt.last = hunt.n + 1, time()
    end
    if notable then
        Add("kill", { name = name, npc = seen.npc, class = seen.class, level = seen.level, zone = Zone() })
    else
        Changed()
    end
end

-- The hunt going on: the last one, if it's recent, here, and nothing but
-- its loot since; nil: a new one
function J.Hunt()
    local events = J.Day().events
    for i = #events, 1, -1 do
        local e = events[i]
        if e.k == "hunt" then return (time() - (e.last or e.t) < HUNT_GAP and e.zone == Zone()) and e or nil end
        if e.k ~= "loot" and e.k ~= "kill" then return nil end
    end
end

-- The foes a day counted, the most first
function J.FoeNames(day)
    local names = {}
    for name in pairs(day.stats.foes or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local na, nb = day.stats.foes[a], day.stats.foes[b]
        if na ~= nb then return na > nb end
        return a < b
    end)
    return names
end

local function Died()
    if not On("fights") then return end
    local s = J.Day().stats
    s.deaths = s.deaths + 1
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    local by = lastFoe and GetTime() - lastFoe.at < 120 and lastFoe.name or nil
    local sub = GetSubZoneText and GetSubZoneText() or nil
    local byClass = by and targets[by] and targets[by].class
    Add("death", { zone = Zone(), sub = sub ~= "" and sub or nil, map = map, x = x, y = y, by = by,
        named = byClass and byClass ~= "normal" and byClass ~= "trivial" and byClass ~= "minus" or nil })
end

---------------------------------------------------------------------------
-- Loot, gold, crafting
---------------------------------------------------------------------------
local money                    -- the gold carried, last seen

-- (Forever's loot lines: no full stop, the link's colour its quality,
-- "|cnIQ2:|Hitem:...|h[Name]|h|r", "x3" after it: read from the link)
local function Looted(msg)
    if not On("loot") or Secret(msg) or type(msg) ~= "string" then return end
    local pushed = Match(msg, P.pushed)
    local kind = Match(msg, P.create) and "create" or (pushed or Match(msg, P.loot)) and "loot"
    local id = kind and ItemID(msg)
    if not id then return end
    -- (an item given with a task handed in: its reward, told with it)
    if pushed then
        local waiting = Recent(rewardFor, 3)
        if waiting then
            waiting.event.reward, rewardFor = id, nil
            return Changed()
        end
        lastPushed = { id = id, at = GetTime() }
    end
    local count = tonumber(msg:match("|rx(%d+)")) or 1
    local quality = Quality(id) or tonumber(msg:match("|cnIQ(%d)"))
    if kind == "loot" and (quality or 0) < (J.Settings().minQuality or 2) then return end
    -- (the same item again today: counted on its line)
    local same = Last(kind, function(e) return e.item == id end)
    if same then
        same.count = (same.count or 1) + count
        return Changed()
    end
    Add(kind, { item = id, count = count })
end

-- Where money came from or went: the window open when it changed (the
-- mailbox, a merchant, the auction house, a flight master, a trainer), or
-- what said so just before (a letter taken, repairs, a quest's reward,
-- coin looted); what says so just after takes it back (J.Claim)
local open = {}                -- [window] = true
local hint                     -- { src, what, from, at }

local function Hint(h)
    h.at = GetTime()
    hint = h
end

local function Source(gain)
    if hint and GetTime() - hint.at < HINT_FOR then return hint end
    if open.mail then return { src = "mail" } end
    if open.merchant then return { src = gain and "sell" or "buy" } end
    if open.auction then return { src = "auction" } end
    if open.taxi then return { src = "flight" } end
    if open.trainer then return { src = "training" } end
    return { src = "other" }
end

-- Coin looted, a quest's reward: in the hunt's line, the quest's (not a
-- line of their own)
local function Absorb(src, amount)
    if src == "coin" then
        local hunt = J.Hunt()
        if hunt then hunt.coin = (hunt.coin or 0) + amount end
    end
end

-- What a change in money was for, said after it (the money's line, if it
-- has just been written, taken back) or before it (the next change's)
function J.Claim(src, amount)
    local events = J.Day().events
    local last = events[#events]
    if last and last.k == "money" and last.src == "other" and time() - last.t <= 2
        and (not amount or last.amount == amount) then
        table.remove(events)
        Absorb(src, last.amount)
        return Changed()
    end
    Hint({ src = src })
end

local function MoneyChanged()
    local now = GetMoney()
    if Secret(now) then return end
    local before = money
    money = now
    if not before or now == before or not On("loot") then return end
    local delta = now - before
    local m = J.Day().stats.money
    if delta > 0 then m.earned = m.earned + delta else m.spent = m.spent - delta end
    local h = Source(delta > 0)
    if h == hint then
        -- (a hint says what one change was for: each letter taken says so again)
        hint = nil
        if h.src == "quest" or h.src == "coin" then
            Absorb(h.src, delta)
            return Changed()
        end
    end
    -- (more of the same, one after another: one line)
    local events = J.Day().events
    local last = events[#events]
    if last and last.k == "money" and last.src == h.src and last.from == h.from and (last.amount > 0) == (delta > 0)
        and time() - last.t < 120 then
        last.amount = last.amount + delta
        if h.what then
            last.what = last.what or {}
            if not tContains(last.what, h.what) then last.what[#last.what + 1] = h.what end
        end
        return Changed()
    end
    Add("money", { amount = delta, src = h.src, from = h.from, what = h.what and { h.what } or nil })
end

-- A letter's money taken: an auction sold ("Auction successful: Linen
-- Cloth"), an outbid refund, a letter from someone
local function MailTaken(index)
    if not GetInboxHeaderInfo then return Hint({ src = "mail" }) end
    local _, _, sender, subject = GetInboxHeaderInfo(index)
    if Secret(sender) then sender = nil end
    local sold = Match(subject, P.sold)
    local refund = not sold and Match(subject, P.outbid)
    Hint({ src = sold and "sale" or refund and "refund" or sender and "letter" or "mail", what = sold or refund,
        from = not (sold or refund) and sender or nil })
end

local WINDOWS = {
    MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
    MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
    AUCTION_HOUSE_SHOW = { "auction", true }, AUCTION_HOUSE_CLOSED = { "auction", false },
    TAXIMAP_OPENED = { "taxi", true }, TAXIMAP_CLOSED = { "taxi", false },
    TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false },
}

local function System(msg)
    local skill, rank = Match(msg, P.skill)
    if skill and On("loot") then
        local same = Last("skill", function(e) return e.name == skill end)
        if same then
            same.rank = math.max(same.rank or 0, tonumber(rank) or 0)
            return Changed()
        end
        return Add("skill", { name = skill, rank = tonumber(rank) })
    end
    local area = Match(msg, P.discover)
    if area and On("places") then
        if not Last("discover", function(e) return e.name == area end) then
            Add("discover", { name = area, zone = Zone() })
        end
        return
    end
    local learned = Match(msg, P.learn)
    if learned and On("loot") then Add("learn", { name = learned }) end
end

---------------------------------------------------------------------------
-- Played time: a step at a time, in the day and the zone
---------------------------------------------------------------------------
local function Tick()
    if not On() then return end
    Session()
    local s = J.Day().stats
    s.played = (s.played or 0) + TICK
    if here then s.zones[here] = (s.zones[here] or 0) + TICK end
    s.levelTo = math.max(s.levelTo or 0, UnitLevel("player") or 0)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local HANDLERS = {
    PLAYER_LEVEL_UP = LevelUp,
    QUEST_ACCEPTED = Accepted,
    QUEST_TURNED_IN = TurnedIn,
    ZONE_CHANGED_NEW_AREA = ZoneChanged,
    PLAYER_ENTERING_WORLD = EnteredWorld,
    PLAYER_CONTROL_LOST = function() ControlChanged("PLAYER_CONTROL_LOST") end,
    PLAYER_CONTROL_GAINED = function() ControlChanged("PLAYER_CONTROL_GAINED") end,
    UNIT_SPELLCAST_SUCCEEDED = SpellCast,
    PLAYER_TARGET_CHANGED = TargetChanged,
    CHAT_MSG_COMBAT_XP_GAIN = Killed,
    PLAYER_DEAD = Died,
    CHAT_MSG_LOOT = Looted,
    PLAYER_MONEY = MoneyChanged,
    CHAT_MSG_SKILL = System,
    CHAT_MSG_SYSTEM = System,
    UI_INFO_MESSAGE = function(_, msg) System(msg) end,
    CHAT_MSG_MONEY = function() J.Claim("coin") end,
    QUEST_LOG_UPDATE = QuestLogChanged,
    QUEST_DETAIL = Talking, QUEST_PROGRESS = Talking, QUEST_COMPLETE = Talking, QUEST_GREETING = Talking,
    GOSSIP_SHOW = Talking,
    MIRROR_TIMER_START = Breath,
    PLAYER_LOGOUT = function() if On() then Session() end end,
}
for event, w in pairs(WINDOWS) do
    HANDLERS[event] = function() open[w[1]] = w[2] or nil end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if not IF.charDB then return end
    local fn = HANDLERS[event]
    if fn then fn(...) end
end)

IF.OnLogin(function()
    J.Settings()
    BuildPatterns()
    Prune()
    for _, day in pairs(Store().days) do
        for _, e in ipairs(day.events) do
            if e.k == "accept" and e.giver then givers[e.id] = e.giver end
        end
    end
    money = GetMoney()
    if Secret(money) then money = nil end
    here = Zone()
    if On() then Session() end
    for _, name in ipairs({ "TakeInboxMoney", "AutoLootMailItem" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, MailTaken) end
    end
    if type(RepairAllItems) == "function" then hooksecurefunc("RepairAllItems", function() Hint({ src = "repair" }) end) end
    for event in pairs(HANDLERS) do
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            events:RegisterUnitEvent(event, "player")
        else
            pcall(events.RegisterEvent, events, event)
        end
    end
    C_Timer.NewTicker(TICK, Tick)
end)
