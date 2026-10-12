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
-- Kept for later, not told yet (quiet: they never break a hunt or a story):
-- "bank", "meal" (kind), "close" (by: a fight nearly lost), "achievement"
-- (id, name), "abandon" (id, name: a task given up) is told; and in stats:
-- rep = { [faction] = gained }, honor, gather = { herb, ore, hide, fish = casts }, combat
-- (seconds), fights, talents (points spent), talked = { [name] = true },
-- walked (map widths), mounted, swum (seconds). Told too: "lesson" parts
-- ("learn": name, spell, recipe, trainer), "equip" (item, slot), "bind"
-- (to), "flightpath", "party" (members) / "alone", "duel" (opponent, won),
-- "standing" (faction, standing), "mail" (from, subject, kind: "won", "expired",
-- "removed", "sold", "outbid", "letter"; items = { { id, count } }: what I
-- took from a letter), "sent" (to, subject, money, items). A death also keeps how I came back
-- (revived: "spirit", "corpse", "player"; reviver). A session keeps how it
-- began: level, money, rested, inn, zone, sub.
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
-- Kinds kept but not told: a hunt goes on over them, the story skips them
J.QUIET = { bank = true, meal = true, close = true, achievement = true, mailbox = true }
-- The gathering spells, by name (each rank its own id): herbs, ore, hides, fish
local GATHER_SPELLS = { 1235236, 2575, 8613, 7620 }
local GATHER_KINDS = { "herb", "ore", "hide", "fish" }   -- (theirs, in that order)
local MEAL_SPELLS = { 433, 430 }          -- Food, Drink

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
        -- (how I set out: rested, at an inn, where, how strong, how rich)
        local rested = GetXPExhaustion and GetXPExhaustion()
        local money = GetMoney()
        s = { from = now, rfrom = rm, level = UnitLevel("player"), zone = Zone(), sub = Sub(),
            rested = rested and not Secret(rested) and rested > 0 or nil,
            inn = IsResting and IsResting() or nil, money = not Secret(money) and money or nil }
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
    P.learnRecipe = Patterns(false, _G.ERR_LEARN_RECIPE_S)
    P.learn = Patterns(false, _G.ERR_LEARN_SPELL_S, _G.ERR_LEARN_ABILITY_S, _G.ERR_LEARN_PASSIVE_S)
    P.bind = Patterns(false, _G.ERR_DEATHBIND_SUCCESS_S)
    P.flightpath = _G.ERR_NEWTAXIPATH
    P.duelWon = Patterns(false, _G.DUEL_WINNER_KNOCKOUT)
    P.duelFled = Patterns(false, _G.DUEL_WINNER_RETREAT)
    P.repUp = Patterns(false, _G.FACTION_STANDING_INCREASED)
    P.repDown = Patterns(false, _G.FACTION_STANDING_DECREASED)
    P.standing = Patterns(false, _G.FACTION_STANDING_CHANGED)
    P.sold = Patterns(false, _G.AUCTION_SOLD_MAIL_SUBJECT)
    P.won = Patterns(false, _G.AUCTION_WON_MAIL_SUBJECT)
    P.coin = Patterns(true, _G.YOU_LOOT_MONEY, _G.LOOT_MONEY_SPLIT)
    P.expired = Patterns(false, _G.AUCTION_EXPIRED_MAIL_SUBJECT)
    P.removed = Patterns(false, _G.AUCTION_REMOVED_MAIL_SUBJECT)
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
local turnedIn                  -- (below: tasks given up)
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
    Add("level", { level = tonumber(level), class = select(2, UnitClass("player")) })
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
    turnedIn[id] = time()
    local npc = Recent(talking, 60)
    local e = Add("quest", { id = id, name = QuestName(id), zone = Zone(), xp = xp > 0 and xp or nil,
        money = money > 0 and money or nil, giver = J.Giver(id),
        ender = npc and npc.name or QuestNpc(id, "finishedBy") })
    -- (its reward: the item given with it, just before or just after)
    local pushed = Recent(lastPushed, 3)
    if e and pushed then
        e.reward, lastPushed = pushed.id, nil
        -- (kept as loot a moment ago: it's the reward's now)
        local events = J.Day().events
        for k = #events, math.max(1, #events - 5), -1 do
            if events[k] == pushed.event then table.remove(events, k) break end
        end
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
    text = text:gsub("[%.%s]+$", "")
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
            local what, how, need
            if last then
                what, how = Objective(last)
                need = last.numRequired
            end
            if q.done and not before.done then
                Add("ready", { id = q.id, name = q.name, what = what, how = how, need = need, giver = J.Giver(q.id) })
            elseif last and #q.objs > 1 then
                Add("objective", { id = q.id, name = q.name, what = what, how = how, need = need, giver = J.Giver(q.id) })
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

local spellNames                -- [name] = gathering's kind ("herb"...) or "meal" (the known spells' names: any rank)
local function SpellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not name and GetSpellInfo then name = GetSpellInfo(id) end
    return name
end

local lastMeal = 0
local function SpellCast(unit, _, spell)
    if unit ~= "player" or Secret(spell) or not On() then return end
    if spell == HEARTHSTONE then
        if On("places") then Add("hearth", { to = GetBindLocation and GetBindLocation() or nil }) end
        return
    end
    if not spellNames then
        spellNames = {}
        for i, id in ipairs(GATHER_SPELLS) do local n = SpellName(id) if n then spellNames[n] = GATHER_KINDS[i] end end
        for _, id in ipairs(MEAL_SPELLS) do local n = SpellName(id) if n then spellNames[n] = "meal" end end
    end
    local name = SpellName(spell)
    local what = name and spellNames[name]
    if what and what ~= "meal" then
        local stats = J.Day().stats
        stats.gather = stats.gather or {}
        stats.gather[what] = (stats.gather[what] or 0) + 1
    elseif what == "meal" and GetTime() - lastMeal > 600 then
        lastMeal = GetTime()
        Add("meal", { kind = name })
    end
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
        if e.k ~= "loot" and e.k ~= "kill" and not J.QUIET[e.k] then return nil end
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

-- How I came back from a death: a spirit healer, my body, someone's spell
local reviver                  -- { name, at }: who offered to bring me back
local spiritHealed             -- accepted the spirit healer's offer

local function Revived()
    local d = Last("death")
    if not d or d.revived or time() - d.t > 1800 then return end
    local by = Recent(reviver, 120)
    d.revived = by and "player" or spiritHealed and "spirit" or "corpse"
    d.reviver = by and by.name or nil
    reviver, spiritHealed = nil, nil
    Changed()
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
local open = {}                -- [window] = who it's with (or true): the windows open now

-- (Forever's loot lines: no full stop, the link's colour its quality,
-- "|cnIQ2:|Hitem:...|h[Name]|h|r", "x3" after it: read from the link)
local function Looted(msg)
    if not On("loot") or Secret(msg) or type(msg) ~= "string" then return end
    local pushed = Match(msg, P.pushed)
    local kind = Match(msg, P.create) and "create" or (pushed or Match(msg, P.loot)) and "loot"
    local id = kind and ItemID(msg)
    if not id then return end
    -- (taken from a letter: the mail's, not loot)
    if pushed and open.mail then return end
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
    local e = Add(kind, { item = id, count = count })
    -- (given, not looted: a task's reward perhaps, told with it if so)
    if pushed and lastPushed and lastPushed.id == id then lastPushed.event = e end
end

-- Where money came from or went: the window open when it changed (the
-- mailbox, a merchant, the auction house, a flight master, a trainer), or
-- what said so just before (a letter taken, repairs, a quest's reward,
-- coin looted); what says so just after takes it back (J.Claim)
local hint                     -- { src, what, from, at }

local function Hint(h)
    h.at = GetTime()
    hint = h
end

local function Source(gain)
    if hint and GetTime() - hint.at < HINT_FOR then
        if hint.src == "repair" and type(open.merchant) == "string" then hint.from = hint.from or open.merchant end
        if hint.src == "buy" and type(open.merchant) == "string" then hint.from = hint.from or open.merchant end
        return hint
    end
    local function who(w) return type(w) == "string" and w or nil end
    -- (a merchant, a trainer, a flight master first: the mailbox may not say
    -- it has closed)
    if open.merchant then return { src = gain and "sell" or "buy", from = who(open.merchant) } end
    if open.trainer then return { src = "training", from = who(open.trainer) } end
    if open.taxi then return { src = "flight", from = who(open.taxi) } end
    if open.auction then return { src = "auction" } end
    if open.mail then return { src = "mail" } end
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
        if h.src == "quest" or h.src == "coin" or h.src == "postage" then
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

-- The mailbox read as it changes: what's gone from a letter was taken (its
-- items, its money), whatever took it (the game's mail window, the pad's)
local MAX_ATTACH = 16
local inbox                     -- { { from, subject, money, items = { [id] = count } } } as last read

local function MailKind(subject)
    if Match(subject, P.sold) then return "sold", Match(subject, P.sold) end
    if Match(subject, P.won) then return "won", Match(subject, P.won) end
    if Match(subject, P.expired) then return "expired", Match(subject, P.expired) end
    if Match(subject, P.removed) then return "removed", Match(subject, P.removed) end
    if Match(subject, P.outbid) then return "outbid", Match(subject, P.outbid) end
    return "letter"
end

local function ReadInbox()
    if not (GetInboxNumItems and GetInboxHeaderInfo) then return nil end
    local list = {}
    local ok = pcall(function()
        for i = 1, GetInboxNumItems() do
            local _, _, sender, subject, money, _, _, hasItem = GetInboxHeaderInfo(i)
            if Secret(sender) then sender = nil end
            if Secret(subject) then subject = nil end
            local items = {}
            if hasItem and GetInboxItem then
                for a = 1, MAX_ATTACH do
                    local name, id, _, count = GetInboxItem(i, a)
                    if name and not Secret(id) then
                        id = id or (GetInboxItemLink and ItemID(GetInboxItemLink(i, a)))
                        if id then items[id] = (items[id] or 0) + (count or 1) end
                    end
                end
            end
            list[#list + 1] = { from = sender, subject = subject,
                money = not Secret(money) and money or 0, items = items }
        end
    end)
    return ok and list or nil
end

-- A letter's money, said by the mail (its money line, if just written, given
-- the letter's sender and kind; else the next change's)
local function MailMoney(m, amount)
    local kind, what = MailKind(m.subject)
    local src = kind == "sold" and "sale" or kind == "outbid" and "refund" or m.from and "letter" or "mail"
    local events = J.Day().events
    for k = #events, math.max(1, #events - 3), -1 do
        local e = events[k]
        if e.k == "money" and time() - e.t <= 5 and e.amount == amount then
            -- (said already, by the money's own hook: as it is)
            if e.src ~= "mail" then return end
            e.src, e.from, e.what = src, kind == "letter" and m.from or nil, what and { what } or e.what
            return Changed()
        end
    end
    Hint({ src = src, from = kind == "letter" and m.from or nil, what = what })
end

local function InboxChanged()
    local now = ReadInbox()
    if not now then return end
    local was = inbox
    inbox = now
    if not was or not On("loot") then return end
    -- (each letter as it was, against the same letter now: by sender and subject)
    local used = {}
    for _, m in ipairs(was) do
        local same
        for j, n in ipairs(now) do
            if not used[j] and n.from == m.from and n.subject == m.subject then
                same, used[j] = n, true
                break
            end
        end
        local taken = {}
        for id, count in pairs(m.items) do
            local left = same and same.items[id] or 0
            if count > left then taken[#taken + 1] = { id, count - left } end
        end
        local money = m.money - (same and same.money or 0)
        if money > 0 then MailMoney(m, money) end
        if #taken > 0 then
            local kind, what = MailKind(m.subject)
            -- (more from the same letter, a moment later: on its line)
            local last = J.Day().events[#J.Day().events]
            if last and last.k == "mail" and last.from == m.from and last.subject == m.subject and time() - last.t < 60 then
                for _, it in ipairs(taken) do last.items[#last.items + 1] = it end
                Changed()
            else
                Add("mail", { from = m.from, subject = m.subject, kind = kind, what = what, items = taken })
            end
            -- (kept as loot a moment ago: it was the letter's)
            local events = J.Day().events
            for k = #events, math.max(1, #events - 12), -1 do
                local e = events[k]
                if e.k == "loot" and time() - e.t <= 10 then
                    for _, it in ipairs(taken) do
                        if e.item == it[1] then table.remove(events, k) break end
                    end
                end
            end
        end
    end
end

-- A letter sent: to whom, with what (read as it goes; kept once it's gone)
local sending
local function Sending(to, subject)
    if not On("loot") or Secret(to) then return end
    local items = {}
    pcall(function()
        for a = 1, MAX_ATTACH do
            local name, id, _, count = GetSendMailItem(a)
            if name and not Secret(id) then items[#items + 1] = { id, count or 1 } end
        end
    end)
    local money = GetSendMailMoney and GetSendMailMoney() or 0
    sending = { to = to, subject = not Secret(subject) and subject or nil,
        money = not Secret(money) and money > 0 and money or nil, items = items, at = GetTime() }
    -- (the money that leaves with it: the letter's, not a line of its own)
    Hint({ src = "postage" })
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
    local recipe = Match(msg, P.learnRecipe)
    local learned = recipe or Match(msg, P.learn)
    if learned and On("loot") then return J.Learned(learned, nil, recipe ~= nil) end
    local home = Match(msg, P.bind)
    if home and On("places") then return Add("bind", { to = home, inn = IsResting and IsResting() or nil }) end
    if type(msg) == "string" and not Secret(msg) and P.flightpath and msg == P.flightpath and On("places") then
        return Add("flightpath", {})
    end
    local a, b = Match(msg, P.duelWon)
    if a and On("fights") then
        local me = UnitName("player")
        return Add("duel", { won = a == me, opponent = a == me and b or a })
    end
    a, b = Match(msg, P.duelFled)
    if a and On("fights") then
        local me = UnitName("player")
        return Add("duel", { won = b ~= me, opponent = b == me and a or b, fled = true })
    end
end

-- A spell, an ability or a recipe learned: the chat's line, the game's
-- event (once: the same name a moment apart is the same lesson); at a
-- trainer, who taught it
function J.Learned(name, spell, recipe)
    if not name or Secret(name) or not On("loot") then return end
    -- (the chat's line names it with a link: "|cff71d5ff|Hspell:...|h[Parry]|h|r")
    name = name:match("%[(.-)%]") or name
    local same = Last("learn", function(e) return e.name == name and time() - e.t < 5 end)
    if same then
        same.spell, same.recipe = same.spell or spell, same.recipe or recipe or nil
        return
    end
    local trainer = open.trainer
    Add("learn", { name = name, spell = spell, recipe = recipe or nil,
        trainer = type(trainer) == "string" and trainer or nil })
end

-- Reputation: a little at a time, counted; a new standing, kept
local function Faction(msg)
    if not On("levels") then return end
    local faction, amount = Match(msg, P.repUp)
    local sign = 1
    if not faction then
        faction, amount = Match(msg, P.repDown)
        sign = -1
    end
    if faction then
        local rep = J.Day().stats
        rep.rep = rep.rep or {}
        rep.rep[faction] = (rep.rep[faction] or 0) + sign * (tonumber(amount) or 0)
        return
    end
    local standing, name = Match(msg, P.standing)
    if standing then Add("standing", { faction = name, standing = standing }) end
end

---------------------------------------------------------------------------
-- More of the day: gear put on, company kept, fights' length, close calls,
-- the bank, tasks given up, talents, who I talked to
---------------------------------------------------------------------------
local worn = {}                -- [slot] = item id, as last seen
local settled = false          -- (the first moments after login: gear as it was)

local function Equipped(slot)
    if not On("loot") or not slot or Secret(slot) then return end
    local id = GetInventoryItemID("player", slot)
    if Secret(id) then return end
    local was = worn[slot]
    worn[slot] = id
    if not settled or not id or id == was then return end
    local _, _, quality = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
    if (quality or 2) < 2 then return end
    Add("equip", { item = id, slot = slot })
end

local party = {}               -- [name] = true: the group as last seen
local function Roster()
    if not On() then return end
    local now, list = {}, {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, n do
        local unit = (IsInRaid and IsInRaid()) and ("raid" .. i) or ("party" .. i)
        local name = UnitName(unit)
        if name and not Secret(name) and name ~= UnitName("player") then now[name] = true end
    end
    for name in pairs(now) do if not party[name] then list[#list + 1] = name end end
    local had = next(party) ~= nil
    party = now
    if #list > 0 then
        table.sort(list)
        Add("party", { members = list })
    elseif had and next(now) == nil then
        Add("alone", {})
    end
end

-- A fight: how long; how close it came (the least health in it)
local fightStart, lowest
local function Combat(on)
    if not On("fights") then return end
    if on then
        fightStart, lowest = GetTime(), 1
        return
    end
    if not fightStart then return end
    local s = J.Day().stats
    s.combat = (s.combat or 0) + math.floor(GetTime() - fightStart)
    s.fights = (s.fights or 0) + 1
    fightStart = nil
    if lowest and lowest < 0.15 and not UnitIsDeadOrGhost("player")
        and not Last("close", function(e) return time() - e.t < 300 end) then
        Add("close", { by = lastFoe and GetTime() - lastFoe.at < 120 and lastFoe.name or nil,
            health = math.floor(lowest * 100) })
    end
end

local function Health(unit)
    if unit ~= "player" or not fightStart then return end
    local hp, max = UnitHealth("player"), UnitHealthMax("player")
    if Secret(hp) or Secret(max) or not max or max <= 0 then return end
    lowest = math.min(lowest or 1, hp / max)
end

-- A task given up: gone from the log, not handed in
turnedIn = {}                  -- [id] = time handed in (QUEST_TURNED_IN)
local function Removed(id)
    if Secret(id) or type(id) ~= "number" or not On("levels") then return end
    C_Timer.After(1, function()
        if turnedIn[id] and time() - turnedIn[id] < 5 then return end
        Add("abandon", { id = id, name = QuestName(id) })
    end)
end

local function Achieved(id)
    if Secret(id) or not On() then return end
    local _, name = GetAchievementInfo and GetAchievementInfo(id)
    Add("achievement", { id = id, name = name })
end

local function Points(change)
    if Secret(change) or (tonumber(change) or 0) >= 0 or not On() then return end
    local s = J.Day().stats
    s.talents = (s.talents or 0) - change
end

local function Spoke()
    Talking()
    local name = talking and talking.name
    if not name or not On() then return end
    local s = J.Day().stats
    s.talked = s.talked or {}
    local n = 0
    for _ in pairs(s.talked) do n = n + 1 end
    if n < 60 then s.talked[name] = true end
end

---------------------------------------------------------------------------
-- Played time: a step at a time, in the day and the zone (and how I got
-- about: on foot, mounted, swimming)
---------------------------------------------------------------------------
local lastPos
local function Tick()
    if not On() then return end
    Session()
    local s = J.Day().stats
    s.played = (s.played or 0) + TICK
    if here then s.zones[here] = (s.zones[here] or 0) + TICK end
    s.levelTo = math.max(s.levelTo or 0, UnitLevel("player") or 0)
    if IsMounted and IsMounted() then s.mounted = (s.mounted or 0) + TICK end
    if IsSwimming and IsSwimming() then s.swum = (s.swum or 0) + TICK end
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    if x and not Secret(x) and not (UnitOnTaxi and UnitOnTaxi("player")) then
        if lastPos and lastPos.map == map then
            local d = math.sqrt((x - lastPos.x) ^ 2 + (y - lastPos.y) ^ 2)
            if d < 0.2 then s.walked = (s.walked or 0) + d end
        end
        lastPos = { map = map, x = x, y = y }
    else
        lastPos = nil
    end
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
    -- (coin looted, "You loot 47 Copper"; not Forever's "You gained: 47", any money)
    CHAT_MSG_MONEY = function(msg)
        if Match(msg, P.coin) then J.Claim("coin") end
    end,
    QUEST_LOG_UPDATE = QuestLogChanged,
    QUEST_DETAIL = Talking, QUEST_PROGRESS = Talking, QUEST_COMPLETE = Talking, QUEST_GREETING = Talking,
    GOSSIP_SHOW = Spoke,
    MIRROR_TIMER_START = Breath,
    LEARNED_SPELL_IN_TAB = function(spell)
        if not Secret(spell) then J.Learned(SpellName(spell), spell) end
    end,
    NEW_RECIPE_LEARNED = function(recipe)
        if Secret(recipe) then return end
        local info = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipe)
        J.Learned(info and info.name or SpellName(recipe), recipe, true)
    end,
    CHAT_MSG_COMBAT_FACTION_CHANGE = Faction,
    CHAT_MSG_COMBAT_HONOR_GAIN = function()
        if not On("fights") then return end
        local s = J.Day().stats
        s.honor = (s.honor or 0) + 1
    end,
    PLAYER_EQUIPMENT_CHANGED = Equipped,
    MAIL_INBOX_UPDATE = InboxChanged,
    MAIL_SEND_SUCCESS = function()
        local sent = Recent(sending, 30)
        sending = nil
        if sent then
            sent.at = nil
            Add("sent", sent)
        end
    end,
    GROUP_ROSTER_UPDATE = Roster,
    PLAYER_REGEN_DISABLED = function() Combat(true) end,
    PLAYER_REGEN_ENABLED = function() Combat(false) end,
    UNIT_HEALTH = Health,
    QUEST_REMOVED = Removed,
    ACHIEVEMENT_EARNED = Achieved,
    CHARACTER_POINTS_CHANGED = Points,
    BANKFRAME_OPENED = function() if On() then Add("bank", {}) end end,
    RESURRECT_REQUEST = function(name)
        if name and not Secret(name) then reviver = { name = name, at = GetTime() } end
    end,
    CONFIRM_XP_LOSS = function() spiritHealed = true end,
    PLAYER_ALIVE = function() if not UnitIsDeadOrGhost("player") then Revived() end end,
    PLAYER_UNGHOST = Revived,
    HEARTHSTONE_BOUND = function()
        if On("places") and not Last("bind", function(e) return time() - e.t < 5 end) then
            Add("bind", { to = GetBindLocation and GetBindLocation() or nil })
        end
    end,
    PLAYER_LOGOUT = function() if On() then Session() end end,
}
-- (a window opened: who it's with, the merchant, the trainer, the flight master)
for event, w in pairs(WINDOWS) do
    HANDLERS[event] = function()
        if w[1] == "mail" then
            -- (the inbox as it was when opened; what's gone by the time it closes)
            if w[2] then
                inbox = ReadInbox()
                if On() then Add("mailbox", { letters = inbox and #inbox or nil }) end
            else
                InboxChanged()
                inbox = nil
            end
        end
        if not w[2] then open[w[1]] = nil return end
        if w[1] ~= "mail" and open.mail then
            InboxChanged()
            open.mail, inbox = nil, nil
        end
        local name = UnitName("npc")
        open[w[1]] = name and not Secret(name) and name or true
    end
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
    if type(SendMail) == "function" then hooksecurefunc("SendMail", Sending) end
    -- (bought from a merchant: what)
    if type(BuyMerchantItem) == "function" then
        hooksecurefunc("BuyMerchantItem", function(index)
            local link = GetMerchantItemLink and GetMerchantItemLink(index)
            local name = link and not Secret(link) and link:match("%[(.-)%]")
            Hint({ src = "buy", what = name })
        end)
    end
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if not Secret(id) then worn[slot] = id end
    end
    C_Timer.After(10, function() settled = true end)
    Roster()
    for event in pairs(HANDLERS) do
        if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_HEALTH" then
            events:RegisterUnitEvent(event, "player")
        else
            pcall(events.RegisterEvent, events, event)
        end
    end
    C_Timer.NewTicker(TICK, Tick)
end)
