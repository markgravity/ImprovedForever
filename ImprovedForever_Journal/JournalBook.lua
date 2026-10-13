-- The Journal read: the core's book (ImprovedForever's Book.lua), as the
-- Library's. Its first page is the journal so far and a line a day (the
-- newest first, under their month); Cross opens a day: what I wrote of it
-- (JournalWriter.lua), then an entry a subject (quests, places, foes,
-- spoils, crafting), each opening its list. In a list Cross opens a quest's,
-- a creature's or an item's Library page in the same book (with the
-- Library), or a place on the map; Circle goes back.
-- Opened with /if journal, its key binding, or a wheel / the touchpad (the
-- core's windows of ours: ImprovedForeverJournalToggle).
-- Never in combat.
local IF = ImprovedForever

local J = IF.Journal
local BK = IF.Book

local ICON = "Interface\\Icons\\"
local DAY_ICON = ICON .. "INV_Scroll_03"
local LISTS = { quests = "Quests", places = "Places", foes = "Foes", spoils = "Spoils", crafting = "Crafting",
    people = "Companions" }
local LIST_ICONS = {
    quests = ICON .. "INV_Misc_Note_01", places = ICON .. "INV_Misc_Map_01",
    foes = ICON .. "INV_Misc_Bone_HumanSkull_01", spoils = ICON .. "INV_Misc_Bag_10",
    crafting = ICON .. "Trade_BlackSmithing",
}
local ICONS = {
    zone = ICON .. "INV_Misc_Map_01", area = ICON .. "INV_Misc_Spyglass_02", instance = ICON .. "INV_Misc_Key_03",
    flight = ICON .. "Ability_Mount_Wyvern_01", hearth = ICON .. "INV_Misc_Rune_01",
    foe = ICON .. "INV_Misc_Bone_HumanSkull_01", death = ICON .. "Ability_Rogue_FeignDeath",
    skill = ICON .. "INV_Misc_Book_11", learn = ICON .. "INV_Scroll_05",
    dive = ICON .. "Spell_Shadow_DemonBreath", letter = ICON .. "INV_Letter_15", gain = ICON .. "INV_Misc_Coin_02", spend = ICON .. "INV_Misc_Coin_04",
}
-- A money line's source, in a few words
local MONEY_SRC = {
    sale = "Sold at auction", refund = "Auction refund", letter = "A letter", mail = "From the mail",
    sell = "Sold to a merchant", buy = "Bought from a merchant", repair = "Repairs", auction = "Auction house",
    flight = "Flight", training = "Training",
}

local Plural, Join = BK.Plural, BK.Join

local book                     -- (below)
local JB = {}
IF.JournalBook = JB

---------------------------------------------------------------------------
-- The map: a place, where I fell (the book steps aside while it's up)
---------------------------------------------------------------------------
local away, hooked = false, false

local function ShowMap(map, x, y)
    if IF.InCombat() or not map then return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    if not (OpenWorldMap and WorldMapFrame) then return end
    if x and y and UiMapPoint and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    if not hooked then
        hooked = true
        WorldMapFrame:HookScript("OnHide", function()
            if not away then return end
            away = false
            book:Resume()
        end)
    end
    away = true
    book:Suspend()
    OpenWorldMap(map)
end

-- (a zone's map: where the day's visit to it was)
local function ZoneMap(day, name)
    for _, e in ipairs(day.events) do
        if e.k == "zone" and e.name == name and e.map then return e.map end
    end
end

---------------------------------------------------------------------------
-- A day's lists, made from what was kept
---------------------------------------------------------------------------
local function Section(lines, title, entries)
    if #entries == 0 then return end
    lines[#lines + 1] = { header = title, info = #entries }
    for _, e in ipairs(entries) do lines[#lines + 1] = e end
end

local function Lists(day)
    local L = {}
    -- Quests: finished, then taken on
    local finished, done, taken = {}, {}, {}
    for _, e in ipairs(J.Events(day, "quest")) do
        finished[e.id] = true
        done[#done + 1] = { kind = "quest", id = e.id, name = e.name or ("Quest " .. e.id), icon = LIST_ICONS.quests,
            line = Join({ e.zone, e.money and BK.Coins(e.money) }) }
    end
    for _, e in ipairs(J.Events(day, "accept")) do
        if not finished[e.id] then
            taken[#taken + 1] = { kind = "quest", id = e.id, name = e.name or ("Quest " .. e.id),
                icon = LIST_ICONS.quests, line = e.zone }
        end
    end
    -- (done, not yet handed in today: what did it)
    local ready = {}
    for _, e in ipairs(J.Events(day, "ready")) do
        if not finished[e.id] then
            ready[#ready + 1] = { kind = "quest", id = e.id, name = e.name or ("Quest " .. e.id), icon = LIST_ICONS.quests,
                line = Join({ e.what, e.sub or e.zone }) }
        end
    end
    L.quests = {}
    Section(L.quests, "Finished", done)
    Section(L.quests, "To Report", ready)
    Section(L.quests, "Taken On", taken)

    -- Places: the lands (the longest stayed first), new areas, instances,
    -- the road between
    local lands, found, inside, road = {}, {}, {}, {}
    for _, name in ipairs(J.Zones(day)) do
        lands[#lands + 1] = { kind = "zone", round = true, icon = ICONS.zone, name = name, map = ZoneMap(day, name),
            line = J.Played(day.stats.zones[name]) .. " here" }
    end
    for _, e in ipairs(J.Events(day, "discover")) do
        found[#found + 1] = { kind = "area", round = true, icon = ICONS.area, name = e.name, line = e.zone }
    end
    for _, e in ipairs(J.Events(day, "instance")) do
        inside[#inside + 1] = { kind = "instance", round = true, icon = ICONS.instance, name = e.name,
            line = e.kind == "raid" and "Raid" or "Dungeon" }
    end
    for _, e in ipairs(J.Events(day, "dive")) do
        road[#road + 1] = { kind = "dive", round = true, icon = ICONS.dive, name = e.sub or e.zone or "Under water",
            line = "Dove" .. (e.sub and e.zone and (" in " .. e.zone) or "") }
    end
    for _, e in ipairs(J.Events(day, "flight", "hearth")) do
        road[#road + 1] = e.k == "flight"
            and { kind = "flight", round = true, icon = ICONS.flight, name = e.to, line = e.from and ("Flew from " .. e.from) or "Flew" }
            or { kind = "hearth", round = true, icon = ICONS.hearth, name = e.to or "Home", line = "Hearthstone" }
    end
    L.places = {}
    Section(L.places, "Lands", lands)
    Section(L.places, "Discovered", found)
    Section(L.places, "Instances", inside)
    Section(L.places, "Travels", road)

    -- Foes: the hardest, every foe by count, where I fell
    local hardest, foes, deaths = {}, {}, {}
    for _, e in ipairs(J.Events(day, "kill")) do
        hardest[#hardest + 1] = { kind = e.npc and "npc" or "foe", id = e.npc, round = true, icon = ICONS.foe,
            name = e.name, line = Join({ BK.Capital(J.FEARSOME[e.class] or "a fearsome brute"), e.zone }) }
    end
    for _, name in ipairs(J.FoeNames(day)) do
        local npc = day.stats.foeIDs and day.stats.foeIDs[name]
        foes[#foes + 1] = { kind = npc and "npc" or "foe", id = npc, round = true, icon = ICONS.foe, name = name,
            line = "Slain " .. (day.stats.foes[name] == 1 and "once" or (day.stats.foes[name] .. " times")) }
    end
    for _, e in ipairs(J.Events(day, "death")) do
        deaths[#deaths + 1] = { kind = "death", round = true, icon = ICONS.death, name = e.sub or e.zone or "Somewhere",
            map = e.map, x = e.x, y = e.y,
            line = Join({ e.sub and e.zone, e.by and ("Slain by " .. e.by), date("%H:%M", e.t) }) }
    end
    L.foes = {}
    Section(L.foes, "The Hardest", hardest)
    Section(L.foes, "Slain", foes)
    Section(L.foes, "Where I Fell", deaths)

    -- Spoils: loot, what I made, coin earned and spent
    local loot, made, coin = {}, {}, {}
    for _, e in ipairs(J.Events(day, "money")) do
        local what = e.what and table.concat(e.what, ", ") or e.from
        coin[#coin + 1] = { kind = "money", round = true, icon = e.amount > 0 and ICONS.gain or ICONS.spend,
            name = (e.amount > 0 and "+ " or "− ") .. BK.Coins(math.abs(e.amount)),
            line = Join({ MONEY_SRC[e.src], what, date("%H:%M", e.t) }) }
    end
    for _, e in ipairs(J.Events(day, "loot")) do
        loot[#loot + 1] = { kind = "item", item = e.item, tip = e.item, describe = (e.count or 1) == 1,
            line = (e.count or 1) > 1 and ("× " .. e.count) or nil }
    end
    for _, e in ipairs(J.Events(day, "create")) do
        made[#made + 1] = { kind = "item", item = e.item, tip = e.item, line = "Made × " .. (e.count or 1) }
    end
    -- (from the mail, sent by mail)
    local mailed, sent = {}, {}
    local MAILED = { won = "Won at auction", expired = "Back unsold", removed = "Back unsold" }
    for _, e in ipairs(J.Events(day, "mail")) do
        for _, it in ipairs(e.items or {}) do
            mailed[#mailed + 1] = { kind = "item", item = it[1], tip = it[1],
                line = Join({ MAILED[e.kind] or (e.from and ("From " .. e.from)), (it[2] or 1) > 1 and ("× " .. it[2]) or nil }) }
        end
    end
    for _, e in ipairs(J.Events(day, "sent")) do
        for _, it in ipairs(e.items or {}) do
            sent[#sent + 1] = { kind = "item", item = it[1], tip = it[1], line = "Sent to " .. (e.to or "a friend") }
        end
        if #(e.items or {}) == 0 then
            sent[#sent + 1] = { kind = "letter", round = true, icon = ICONS.letter, name = e.to or "A friend",
                line = Join({ "A letter", e.money and BK.Coins(e.money) }) }
        end
    end
    L.spoils = {}
    Section(L.spoils, "Loot", loot)
    Section(L.spoils, "From the Mail", mailed)
    Section(L.spoils, "Sent", sent)
    Section(L.spoils, "Made", made)
    Section(L.spoils, "Coin", coin)

    -- Crafting: skills risen, what I learned
    local skills, learned = {}, {}
    for _, e in ipairs(J.Events(day, "skill")) do
        skills[#skills + 1] = { kind = "skill", round = true, icon = ICONS.skill, name = e.name,
            line = "Rose to " .. (e.rank or "?") }
    end
    for _, e in ipairs(J.Events(day, "learn")) do
        learned[#learned + 1] = { kind = "learn", round = true, icon = ICONS.learn, name = e.name, line = "Learned" }
    end
    L.crafting = {}
    Section(L.crafting, "Skills", skills)
    Section(L.crafting, "Learned", learned)
    return L
end

-- The day's entries: one a list that has something, its line what it holds
local function Subjects(day, L)
    local s, lines = day.stats, {}
    local function add(key, line)
        if BK.Count(L[key]) > 0 then
            lines[#lines + 1] = { go = key, icon = LIST_ICONS[key], name = LISTS[key], line = line }
        end
    end
    local finished, ready = #J.Events(day, "quest"), BK.Count(L.quests)
    ready = ready - finished
    add("quests", Join({ finished > 0 and ("Finished " .. finished), ready > 0 and (ready .. " more under way") }, ", "))
    local zones = J.Zones(day)
    add("places", zones[1] and (zones[1] .. (#zones > 1 and (" and " .. (#zones - 1) .. " more") or "")) or "On the road")
    add("foes", Join({ s.kills > 0 and (s.kills .. " slain"), s.deaths > 0 and Plural(s.deaths, "death", "deaths") }, ", "))
    local loot = J.Events(day, "loot", "create", "mail")
    local firstID = loot[1] and (loot[1].item or loot[1].items and loot[1].items[1] and loot[1].items[1][1])
    local first = firstID and (C_Item and C_Item.GetItemInfo or GetItemInfo)(firstID)
    local m = s.money
    local net = m.earned - m.spent
    add("spoils", first and (first .. (#loot > 1 and (" and " .. (#loot - 1) .. " more") or ""))
        or #loot > 0 and Plural(#loot, "item", "items")
        or (net >= 0 and "Earned " or "Spent ") .. BK.Coins(math.abs(net)))
    local skill = J.Events(day, "skill")[1]
    add("crafting", skill and (skill.name .. " " .. (skill.rank or "")) or "Recipes learned")
    return lines
end

---------------------------------------------------------------------------
-- Pages: the journal's first, a day's
---------------------------------------------------------------------------
-- Cross on a day's entry: its Library page (in this book), a place on the map
local function Open(line, bk)
    local LB = IF.Library
    if line.kind == "zone" or line.kind == "death" then return ShowMap(line.map, line.x, line.y) end
    if not (LB and LB.Page) then return end
    if line.kind == "quest" then return bk:Push(LB.Page("quest", line.id)) end
    if line.kind == "npc" then return bk:Push(LB.Page("npc", line.id)) end
    if line.item then return bk:Push(LB.Page("item", line.item)) end
end

local function Verb(line)
    if (line.kind == "zone" or line.kind == "death") and line.map then return "Show on Map" end
    if IF.Library and IF.Library.Page and (line.kind == "quest" or line.kind == "npc" or line.item) then
        return "Open"
    end
end

local Day = {}
Day.__index = Day

local EMPTY = { events = {}, stats = { levelFrom = 1, levelTo = 1, xp = 0, kills = 0, deaths = 0, quests = 0, played = 0,
    money = { earned = 0, spent = 0 }, foes = {}, foeIDs = {}, zones = {} } }

local function DayPage(key)
    return setmetatable({ key = key }, Day)
end

function Day:day() return J.Day(self.key) or EMPTY end

function Day:heading()
    local day = self:day()
    local s, zones = day.stats, J.Zones(day)
    return {
        icon = DAY_ICON, title = J.DayTitle(self.key),
        kind = Join({ s.played > 0 and (J.Played(s.played) .. " on the road"), J.Grew(day) }),
        owned = BK.Names({ unpack(zones, 1, math.min(3, #zones)) }) .. (#zones > 3 and (" and " .. (#zones - 3) .. " more") or ""),
        chapter = LISTS[self.tab] or "Diary",
    }
end

function Day:notes()
    local day = self:day()
    return J.Write(self.key, day), J.Signature(), Subjects(day, Lists(day))
end

function Day:list(key) return Lists(self:day())[key] or {} end
function Day:activate(line, bk) Open(line, bk) end
function Day:verb(line) return Verb(line) end

local Contents = {}
Contents.__index = Contents

function Contents:heading()
    local keys = J.Days()
    return {
        icon = ICON .. "INV_Misc_Book_11", title = UnitName("player") or "",
        kind = Join({ UnitRace("player"), UnitClass("player") }, " "),
        owned = #keys == 0 and "Nothing written yet"
            or (Plural(#keys, "day", "days") .. " written since " .. J.DayTitle(keys[#keys], true)),
        chapter = self.tab == "people" and "Companions" or "Journal",
    }
end

-- Companions: everyone I've had dealings with (talk overheard alone isn't
-- enough), the best known first
local COMPANION = ICON .. "INV_Misc_GroupLooking"

-- Someone's face: their race's icon for their gender, else their class's,
-- else the group's: the game's own atlases (GetRaceAtlas, GetClassAtlas, as
-- the chat shows players), each only if this client has it
local function Avatar(p)
    if not p then return COMPANION end
    local race = p.raceToken and p.raceToken:lower()
    if race == "scourge" then race = "undead" end
    local gender = p.sex == 3 and "female" or p.sex == 2 and "male" or nil
    if race and gender and GetRaceAtlas then
        for _, hiRez in ipairs({ true, false }) do
            local ok, atlas = pcall(GetRaceAtlas, race, gender, hiRez)
            if ok and atlas and IF.HasAtlas(atlas) then return "atlas:" .. atlas end
        end
    end
    if p.classToken and GetClassAtlas then
        local ok, atlas = pcall(GetClassAtlas, p.classToken:lower())
        if ok and atlas and IF.HasAtlas(atlas) then return "atlas:" .. atlas end
    end
    return COMPANION
end
local function Companions()
    local list = {}
    local PE = J.People
    if not PE then return list end
    local people = IF.charDB and IF.charDB.journal and IF.charDB.journal.people or {}
    for name, p in pairs(people) do
        local n = p.n or {}
        local dealt = (n.grouped or 0) > 0 or (n.talks or 0) > 0 or (n.emotesIn or 0) + (n.emotesOut or 0) > 0
            or (n.trades or 0) + (n.gifts or 0) + (n.sent or 0) + (n.duels or 0) + (n.revivedMe or 0) > 0
        if dealt then list[#list + 1] = { name = name, p = p, score = PE.Score(p) } end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    return list
end

local Person = {}
Person.__index = Person

local function PersonPage(name)
    return setmetatable({ name = name }, Person)
end

function Person:heading()
    local p = J.People and J.People.Get(self.name) or {}
    return {
        icon = Avatar(p), round = true, title = self.name,
        kind = Join({ p.race, p.class }, " "),
        owned = Join({ p.guild and ("‹" .. p.guild .. "›"), p.dayCount and Plural(p.dayCount, "day", "days") .. " met" }),
        chapter = "Companion",
    }
end

function Person:notes()
    local p = J.People and J.People.Get(self.name) or {}
    -- (the days we met: their pages)
    local keys, lines = {}, {}
    for key in pairs(p.days or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return a > b end)
    if #keys > 0 then lines[1] = { header = "Days We Met", info = #keys } end
    for _, key in ipairs(keys) do
        if J.Day(key) then
            lines[#lines + 1] = { kind = "day", key = key, icon = DAY_ICON, name = J.DayTitle(key), line = J.DayLine(J.Day(key)) }
        end
    end
    return J.PersonStory(self.name), nil, lines
end

function Person:activate(line, bk)
    if line.key then bk:Push(DayPage(line.key)) end
end

function Person:verb(line) return line.key and "Read" or nil end

function Contents:list(key)
    if key ~= "people" then return {} end
    local lines = {}
    for _, c in ipairs(Companions()) do
        local p = c.p
        lines[#lines + 1] = { kind = "person", person = c.name, round = true, icon = Avatar(p), name = c.name,
            line = Join({ Join({ p.race, p.class }, " "), p.last and ("last seen " .. date("%d %b", p.last)) }) }
    end
    return lines
end

function Contents:notes()
    local keys, lines, header = J.Days(), {}, nil
    -- (the people of the road, first)
    local companions = #Companions()
    if companions > 0 then
        lines[1] = { go = "people", icon = COMPANION, name = "Companions",
            line = Plural(companions, "person", "people") .. " met on the road" }
    end
    for _, key in ipairs(keys) do
        local month = J.MonthTitle(key)
        if not header or header.header ~= month then
            header = { header = month, info = 0 }
            lines[#lines + 1] = header
        end
        header.info = header.info + 1
        lines[#lines + 1] = { kind = "day", key = key, icon = DAY_ICON,
            name = J.DayTitle(key) .. (key == J.TodayKey() and "  (today)" or ""), line = J.DayLine(J.Day(key)) }
    end
    return { J.Summary(keys) }, nil, lines
end

function Contents:activate(line, bk)
    if line.key then return bk:Push(DayPage(line.key)) end
    if line.person then return bk:Push(PersonPage(line.person)) end
end

function Contents:verb(line) return (line.key or line.person) and "Read" or nil end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------
book = BK.New({ name = "ImprovedForeverJournal", title = "Journal", portrait = ICON .. "INV_Misc_Book_11",
    notes = "Diary", empty = "Nothing was written here." })
JB.book = book

-- key: a day's ("YYYY-MM-DD"; nil: the journal's first page)
function JB.Open(key)
    if IF.InCombat() then return IF.Print("Not in combat.") end
    book:Open(setmetatable({}, Contents))
    if key then book:Push(DayPage(key)) end
end

function JB.Toggle()
    if book:IsShown() then return book:Close() end
    JB.Open()
end

-- (what happened today: drawn again while it's read, once a moment)
local pending = false
local function Redraw()
    if not book:IsShown() or pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        book:Render()
    end)
end
J.OnChange(Redraw)

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", Redraw)

-- The press that opens it: a key binding, a wheel's or the touchpad's
-- (the core's windows of ours, Actions.lua)
local toggle = CreateFrame("Button", "ImprovedForeverJournalToggle", UIParent)
toggle:SetScript("OnClick", function() JB.Toggle() end)
_G["BINDING_NAME_CLICK ImprovedForeverJournalToggle:LeftButton"] = "Toggle Journal"
