-- Library: everything known about an item, as a page of a book. R3 held on
-- an item (the bags, the loot window: watched, never bound; the auction
-- window: its own R3, AuctionBuy.lua) opens its page (LibraryPage.lua).
-- This file: what is known (the sources below), what is focused, the hold.
-- Drops, vendors, quests and recipes come from the core (GameData.lua:
-- QuestieDB when installed, else our copy of its Forever data; the game's
-- own recipe tables) and from the recipes seen whenever a profession
-- window opens (LB.Learn).
-- Never in combat.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C

local LB = {}
IF.Library = LB

LB.HOLD = 0.7                  -- R3 held this long: the Library
local SHOW_AFTER = 0.15        -- (a shorter press: the game's own R3, the ring not shown)
local TIP_KEPT = 1.5           -- an item's tooltip this recent still says what is focused
local MAX_LINES = 200          -- shown per source: creatures dropping cloth run to a thousand
local MAX_READ = 3000          -- (read per source, the nearest kept)
local SMALL_ZONE = 3            -- a zone with fewer: "Elsewhere"

local ICON = "Interface\\Icons\\"
local ICONS = {
    npc = ICON .. "INV_Misc_Head_Dragon_01", object = ICON .. "INV_Box_01",
    vendor = ICON .. "INV_Misc_Coin_02", quest = ICON .. "INV_Misc_Note_01", trainer = ICON .. "INV_Misc_Book_11",
    drops = ICON .. "INV_Misc_Bag_10", recipes = ICON .. "Trade_Engineering",
    auction = ICON .. "INV_Misc_Coin_01", none = ICON .. "INV_Misc_QuestionMark",
}
-- Ink on the page's parchment: an elite's rank, a hostile faction, a note
local INK = { rank = "|cff8a4b08", hostile = "|cff9c1c0c", faint = "|cff7a6650" }
LB.INK = INK
local RANKS = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }
local ROLES = { reward = "Reward", starts = "Starts the quest", objective = "Needed for it" }

---------------------------------------------------------------------------
-- Settings: IF.db.library = { enabled } (the recipes seen in a profession
-- window: the core's, GameData.lua)
---------------------------------------------------------------------------
function LB.Settings()
    local s = IF.db.library or {}
    IF.db.library = s
    if s.enabled == nil then s.enabled = true end
    return s
end

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

local function ItemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or ICONS.none
end

-- An item's id from an id or a link
local function ItemID(item)
    if type(item) == "number" then return item end
    if type(item) ~= "string" then return nil end
    return tonumber(item) or tonumber(item:match("item:(%d+)"))
end

---------------------------------------------------------------------------
-- QuestieDB, else our copy of it; the recipes: the core's (GameData.lua)
---------------------------------------------------------------------------
local GD = IF.GameData
local Field, Fields = GD.Field, GD.Fields
LB.Q, LB.QStatus = GD.Q, GD.QStatus

-- Zones: QuestieDB's are area ids; the map's are UiMap ids (its tables are
-- Lua source strings, the Forever overrides on top)
local areaToUi, uiToArea
local function LoadMap(zdb, name)
    local src = zdb and zdb.private and zdb.private[name]
    local ok, t = pcall(function()
        if type(src) == "string" then return assert(loadstring(src))() end
        return src
    end)
    return ok and type(t) == "table" and t or {}
end

local function ZoneMaps()
    if areaToUi then return end
    areaToUi, uiToArea = {}, {}
    local Q = LB.Q()
    local ok, zdb = pcall(function() return Q and Q.Support.Get("ZoneDB") end)
    if not ok or not zdb then return end
    for _, name in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
        for area, ui in pairs(LoadMap(zdb, name)) do areaToUi[area] = ui end
    end
    for _, name in ipairs({ "uiMapIdToAreaId", "uiMapIdToAreaIdOverride" }) do
        for ui, area in pairs(LoadMap(zdb, name)) do uiToArea[ui] = area end
    end
    for area, ui in pairs(areaToUi) do
        if ui ~= 0 and not uiToArea[ui] then uiToArea[ui] = area end
    end
end

local function ZoneName(area)
    local name = area and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
    return name or (area and area > 0 and ("zone " .. area)) or "Unknown zone"
end

local function PlayerArea()
    ZoneMaps()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return map and uiToArea[map], map
end

---------------------------------------------------------------------------
-- The sources: lists of lines, each { name, line, icon, quality, ... } or
-- { header, info }; what Cross does on one: go (a tab), item (its page),
-- spot (a waypoint: { area, x, y })
---------------------------------------------------------------------------
-- The nearest real spawn (instances are -1, -1): the player's zone's, else
-- the first
local function NearestSpawn(spawns, here)
    if type(spawns) ~= "table" then return nil end
    local best, bestArea
    local function first(area, points)
        for _, p in ipairs(points) do
            if p[1] and p[1] >= 0 then return { area = area, x = p[1], y = p[2] } end
        end
    end
    if here and spawns[here] then best = first(here, spawns[here]) end
    if best then
        -- (in the player's zone: the closest of them)
        ZoneMaps()
        local map = areaToUi[here]
        local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
        if pos then
            local px, py = pos:GetXY()
            local d = math.huge
            for _, p in ipairs(spawns[here]) do
                if p[1] and p[1] >= 0 then
                    local dx, dy = p[1] / 100 - px, p[2] / 100 - py
                    local dd = dx * dx + dy * dy
                    if dd < d then d, best = dd, { area = here, x = p[1], y = p[2] } end
                end
            end
        end
        return best
    end
    -- (elsewhere: the lowest zone id with one, so the same every time)
    for area, points in pairs(spawns) do
        if first(area, points) and (not bestArea or area < bestArea) then bestArea = area end
    end
    if bestArea then return first(bestArea, spawns[bestArea]) end
end

local function Levels(min, max)
    if not min or min <= 0 then return nil end
    if not max or max == min then return "Level " .. min end
    return "Level " .. min .. "-" .. max
end

local function Plural(n, one, many)
    return n .. " " .. (n == 1 and one or many)
end

-- (parts may have gaps: a nil or false one is left out, the rest kept)
local function Join(parts, sep)
    local out = {}
    for i = 1, table.maxn(parts) do
        local p = parts[i]
        if p and p ~= "" then out[#out + 1] = p end
    end
    return table.concat(out, sep or "  ·  ")
end

-- Lines grouped under their zone's header: the player's zone first, then the
-- zones with a level nearest the player's (unknown zones last); in a zone,
-- the nearest level first. At most MAX_LINES of them (lines.total: all)
local function ByZone(entries)
    local here = PlayerArea()
    local level = UnitLevel("player") or 1
    local zones, order = {}, {}
    for _, e in ipairs(entries) do
        local key = e.zone or 0
        if not zones[key] then
            zones[key] = {}
            order[#order + 1] = key
        end
        table.insert(zones[key], e)
    end
    local function far(e) return math.abs((e.level or level) - level) end
    local best = {}
    for key, list in pairs(zones) do
        table.sort(list, function(a, b)
            if far(a) ~= far(b) then return far(a) < far(b) end
            return (a.name or "") < (b.name or "")
        end)
        best[key] = far(list[1])
    end
    table.sort(order, function(a, b)
        if (a == here) ~= (b == here) then return a == here end
        if (a == 0) ~= (b == 0) then return b == 0 end
        if best[a] ~= best[b] then return best[a] < best[b] end
        return ZoneName(a) < ZoneName(b)
    end)
    -- A zone with only one or two: under "Elsewhere" at the end, its name
    -- on each (a page of headers otherwise)
    local groups, elsewhere = {}, {}
    for _, key in ipairs(order) do
        local list = zones[key]
        if key ~= 0 and (#list >= SMALL_ZONE or key == here) then
            groups[#groups + 1] = { header = ZoneName(key) .. (key == here and "  (here)" or ""), list = list }
        else
            for _, e in ipairs(list) do
                if key ~= 0 then e.line = Join({ ZoneName(key), e.line }) end
                elsewhere[#elsewhere + 1] = e
            end
        end
    end
    if #elsewhere > 0 then
        table.sort(elsewhere, function(a, b)
            if far(a) ~= far(b) then return far(a) < far(b) end
            return (a.name or "") < (b.name or "")
        end)
        groups[#groups + 1] = { header = #groups > 0 and "Elsewhere" or "Around the world", list = elsewhere }
    end
    local lines, shown = { total = #entries }, 0
    for _, g in ipairs(groups) do
        if shown >= MAX_LINES then break end
        lines[#lines + 1] = { header = g.header, info = #g.list }
        for _, e in ipairs(g.list) do
            if shown >= MAX_LINES then break end
            lines[#lines + 1] = e
            shown = shown + 1
        end
    end
    return lines
end

local NPC_KEYS = { "name", "minLevel", "maxLevel", "rank", "zoneID", "spawns", "subName", "friendlyToFaction" }

local function NpcEntry(Q, id, icon)
    local n = Fields(Q.Npc, id, NPC_KEYS)
    if not n or not n.name then return nil end
    local here = PlayerArea()
    local spot = NearestSpawn(n.spawns, here)
    local zone = n.zoneID or (spot and spot.area)
    local min, max = n.minLevel, n.maxLevel
    return {
        kind = "npc", id = id, icon = icon, quality = 1, zone = zone, spot = spot, spawns = n.spawns,
        name = n.name, plain = n.name, sub = n.subName,
        level = min and max and math.floor((min + max) / 2) or min,
        -- "Level 20 Elite - Cooking Supplies"
        line = Join({ Join({ Levels(min, max), RANKS[n.rank or 0] and (INK.rank .. RANKS[n.rank] .. "|r") }, " "),
            n.subName }, " - "),
        faction = n.friendlyToFaction,
    }
end

---------------------------------------------------------------------------
-- A creature's page: who it is, where it is (a line a zone: its spots, the
-- nearest one's waypoint), what it drops and sells (items, best first)
---------------------------------------------------------------------------
-- Where something spawns, a line a zone (its spots; the nearest one's
-- waypoint), the player's zone first
local function SpawnPlaces(spawns)
    local here = PlayerArea()
    local places = {}
    for area, points in pairs(spawns or {}) do
        local real = 0
        for _, pt in ipairs(points) do
            if pt[1] and pt[1] >= 0 then real = real + 1 end
        end
        local spot = NearestSpawn({ [area] = points }, area)
        places[#places + 1] = { kind = "place", zone = area, spot = spot, spawns = { [area] = points },
            plain = ZoneName(area),
            name = ZoneName(area) .. (area == here and "  (here)" or ""), icon = ICON .. "INV_Misc_Map_01",
            line = real > 0 and Plural(real, "spot", "spots") or "Inside an instance", here = area == here }
    end
    table.sort(places, function(a, b)
        if a.here ~= b.here then return a.here end
        return a.plain < b.plain
    end)
    return places
end

-- -> { id, name, entry (its list line, NpcEntry's), places = lines } or nil
function LB.Creature(npcID)
    local Q = LB.Q()
    local entry = Q and NpcEntry(Q, npcID, ICONS.npc)
    if not entry then return nil end
    return { id = npcID, name = entry.plain, entry = LB.Faction(entry),
        places = SpawnPlaces(Field(Q.Npc, npcID, "spawns")) }
end

-- A chest, a node: -> { id, name, how ("herb", "ore", "fish"; nil: a chest
-- or the like), places = lines } or nil
function LB.Thing(objectID)
    local Q = LB.Q()
    local o = Q and Fields(Q.Object, objectID, { "name", "spawns" })
    if not (o and o.name) then return nil end
    return { id = objectID, name = o.name, how = LB.Gathered(o.name), places = SpawnPlaces(o.spawns) }
end

-- What creatures drop and sell, what chests and nodes hold, what container
-- items hold: built once from the bundled data (items' npcDrops, objectDrops,
-- itemDrops and vendors read backwards)
local loot, holds, contents, wares, rewards
local function Backwards()
    if loot then return end
    loot, holds, contents, wares, rewards = {}, {}, {}, {}, {}
    local function add(map, ids, item)
        for id in (ids or ""):gmatch("%d+") do
            id = tonumber(id)
            map[id] = map[id] or {}
            table.insert(map[id], item)
        end
    end
    for item, row in pairs(IF.WorldData and IF.WorldData.items or {}) do
        local drops, objects, inside, sells, given = row:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
        add(rewards, given, item)
        add(loot, drops, item)
        add(holds, objects, item)
        add(contents, inside, item)
        add(wares, sells, item)
    end
end

-- Items as lines, the best quality first, then by name
local function ItemLines(ids)
    local lines = {}
    for _, id in ipairs(ids or {}) do
        local _, _, quality = ItemInfo(id)
        lines[#lines + 1] = { kind = "item", item = id, tip = id, icon = ItemIcon(id), quality = quality or 1,
            describe = true }
    end
    table.sort(lines, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return (ItemInfo(a.item) or "") < (ItemInfo(b.item) or "")
    end)
    return lines
end

function LB.Loot(npcID)
    Backwards()
    return ItemLines(loot[npcID])
end

function LB.Wares(npcID)
    Backwards()
    return ItemLines(wares[npcID])
end

function LB.Holds(objectID)
    Backwards()
    return ItemLines(holds[objectID])
end

-- What a container item (a box, a clam) holds
function LB.Contents(itemID)
    Backwards()
    return ItemLines(contents[itemID])
end

-- What a trainer teaches, as the items its recipes make: the recipes it
-- teaches (WorldData.lua's trainers), and the recipes that come with its
-- profession (its starters)
local taught
function LB.Teaches(npcID)
    local data, recipes = IF.WorldData, IF.RecipeData and IF.RecipeData.recipes
    if not (data and data.trainerSets and recipes) then return {} end
    if not taught then
        taught = {}
        local inSet = {}
        for set, list in ipairs(data.trainerSets) do
            inSet[set] = {}
            for id in list:gmatch("%d+") do inSet[set][#inSet[set] + 1] = tonumber(id) end
        end
        local function add(set, spell)
            for _, npc in ipairs(inSet[set] or {}) do
                taught[npc] = taught[npc] or {}
                table.insert(taught[npc], spell)
            end
        end
        for spell, set in pairs(data.trainers) do add(set, spell) end
        for spell, row in pairs(recipes) do
            if data.starters and data.starters[spell] and data.professionTrainers[row[1]] then
                add(data.professionTrainers[row[1]], spell)
            end
        end
    end
    -- (as the trainer's window has them: the lowest skill first; each line
    -- what it asks, "Requires Alchemy (25) · Level 35")
    local lines, seen = {}, {}
    for _, spell in ipairs(taught[npcID] or {}) do
        local row = recipes[spell]
        local make = row and row[2]
        if make and make > 0 and not seen[make] then
            seen[make] = true
            local rank = data.trainerSkill and data.trainerSkill[spell] or 1
            local level = data.trainerLevel and data.trainerLevel[spell]
            lines[#lines + 1] = { kind = "item", item = make, tip = make, icon = ItemIcon(make), rank = rank,
                line = Join({ "Requires " .. LB.SkillName(row[1]) .. " (" .. rank .. ")",
                    level and level > 1 and ("Level " .. level) }) }
        end
    end
    table.sort(lines, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return (ItemInfo(a.item) or "") < (ItemInfo(b.item) or "")
    end)
    return lines
end

-- What it's gathered from: an herb, a vein (NodeScan.lua's names), a fishing
-- pool; nil: a chest or another object
local FISHING = { "School of", "Pool", "Wreckage", "Debris", "Oil Spill", "Swarm" }
local function Gathered(name)
    local kind = IF.NodeScan and IF.NodeScan.Kind(name)
    if kind then return kind end
    for _, word in ipairs(FISHING) do
        if name:find(word, 1, true) then return "fish" end
    end
end
LB.Gathered = Gathered
local GATHER = {
    herb = { icon = ICON .. "Trade_Herbalism", line = "Herb" },
    ore = { icon = ICON .. "Trade_Mining", line = "Mining node" },
    fish = { icon = ICON .. "Trade_Fishing", line = "Fishing pool" },
}

-- Where it drops, by kind: { creatures, chests (chests and other objects),
-- herb, ore, fish (what is gathered), items (items it comes inside) }, each
-- a list of lines by zone (lines.total: all of them)
function LB.Drops(itemID)
    local Q = LB.Q()
    if not Q then return {} end
    local creatures, chests, gathered = {}, {}, { herb = {}, ore = {}, fish = {} }
    for _, id in ipairs(Field(Q.Item, itemID, "npcDrops") or {}) do
        if #creatures >= MAX_READ then break end
        local e = NpcEntry(Q, id, ICONS.npc)
        if e then creatures[#creatures + 1] = e end
    end
    -- (an object is often several ids with one name: one line a zone)
    local seen = {}
    for _, id in ipairs(Field(Q.Item, itemID, "objectDrops") or {}) do
        local o = Fields(Q.Object, id, { "name", "zoneID", "spawns" })
        if o and o.name then
            local spot = NearestSpawn(o.spawns, PlayerArea())
            local zone = o.zoneID or (spot and spot.area)
            local key = o.name .. "|" .. tostring(zone)
            local same = seen[key]
            if same then
                -- (the same thing under another id: its spawns too, for the map)
                for area, points in pairs(o.spawns or {}) do
                    local into = same.spawns[area] or {}
                    same.spawns[area] = into
                    for _, pt in ipairs(points) do into[#into + 1] = pt end
                end
            else
                local how = Gathered(o.name)
                local list = how and gathered[how] or chests
                if #list < MAX_READ then
                    local spawns = {}
                    for area, points in pairs(o.spawns or {}) do spawns[area] = { unpack(points) } end
                    local e = { kind = "object", how = how, id = id, quality = 1, name = o.name,
                        plain = o.name, zone = zone, spot = spot, spawns = spawns,
                        icon = how and GATHER[how].icon or ICONS.object, line = how and GATHER[how].line or nil }
                    list[#list + 1] = e
                    seen[key] = e
                end
            end
        end
    end
    local items = {}
    for _, id in ipairs(Field(Q.Item, itemID, "itemDrops") or {}) do
        items[#items + 1] = { kind = "item", item = id, tip = id, icon = ItemIcon(id) }
    end
    return { creatures = ByZone(creatures), chests = ByZone(chests), herb = ByZone(gathered.herb),
        ore = ByZone(gathered.ore), fish = ByZone(gathered.fish), items = items }
end

-- A person of the other faction, said in red on their line (they won't sell
-- or train)
function LB.Faction(e)
    local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
    if e.faction and not e.faction:find(mine) then
        e.line = Join({ e.line, INK.hostile .. (mine == "H" and "Alliance" or "Horde") .. "|r" })
    end
    return e
end

-- The trainers who teach a recipe, by zone (LibraryData.lua's, from
-- cMaNGOS); a recipe that comes with its profession: any of the profession's
-- trainers (second return: true then)
function LB.Trainers(spell, skill)
    local Q, data = LB.Q(), IF.WorldData
    if not (Q and data and data.trainerSets) then return {} end
    local set = data.trainers[spell]
    local starter = set == nil and data.starters and data.starters[spell] ~= nil
    if starter then set = skill and data.professionTrainers[skill] end
    local entries = {}
    for id in (set and data.trainerSets[set] or ""):gmatch("%d+") do
        local e = NpcEntry(Q, tonumber(id), ICONS.trainer)
        if e then entries[#entries + 1] = LB.Faction(e) end
    end
    return ByZone(entries), starter
end

-- Whether any vendor sells it (QuestieDB's Forever vendors; nil: no data)
function LB.Sold(itemID)
    local Q = LB.Q()
    if not (Q and itemID) then return nil end
    local vendors = Field(Q.Item, itemID, "vendors")
    return vendors ~= nil and next(vendors) ~= nil
end

-- The people it comes from, by zone: so far those who sell it (QuestieDB's
-- vendors)
function LB.People(itemID)
    local Q = LB.Q()
    if not Q then return nil end
    local entries = {}
    for _, id in ipairs(Field(Q.Item, itemID, "vendors") or {}) do
        if #entries >= MAX_READ then break end
        local e = NpcEntry(Q, id, ICONS.vendor)
        if e then entries[#entries + 1] = LB.Faction(e) end
    end
    return ByZone(entries)
end

-- A quest as a list line: its name, "Level 11 · Reward · Loch Modan" (role:
-- the item's part in it, a word for it, or nil)
local function QuestEntry(Q, id, role)
    local q = Fields(Q.Quest, id, { "name", "questLevel", "zoneOrSort" })
    if not q or not q.name then return nil end
    local zone = q.zoneOrSort and q.zoneOrSort > 0 and ZoneName(q.zoneOrSort) or nil
    return { kind = "quest", id = id, icon = ICONS.quest, quality = 1, name = q.name, role = role,
        line = Join({ q.questLevel and q.questLevel > 0 and ("Level " .. q.questLevel), ROLES[role] or role, zone }) }
end

-- A chest's, a node's line (an object that gives or takes a quest too)
local function ObjectEntry(Q, id)
    local o = Fields(Q.Object, id, { "name", "zoneID", "spawns" })
    if not (o and o.name) then return nil end
    local spot = NearestSpawn(o.spawns, PlayerArea())
    local how = Gathered(o.name)
    return { kind = "object", how = how, id = id, quality = 1, name = o.name, plain = o.name, spawns = o.spawns,
        zone = o.zoneID or (spot and spot.area), spot = spot, icon = how and GATHER[how].icon or ICONS.object,
        line = Join({ how and GATHER[how].line, (o.zoneID or (spot and spot.area)) and ZoneName(o.zoneID or spot.area) }) }
end

-- A quest's page: -> { id, name, level, required, zone, objectives = { text },
-- givers, enders (creatures, objects, items), before, after (quests),
-- rewards (items) } or nil
function LB.Quest(questID)
    local Q = LB.Q()
    local q = Q and Fields(Q.Quest, questID, { "name", "questLevel", "requiredLevel", "zoneOrSort", "startedBy",
        "finishedBy", "objectivesText", "preQuestSingle", "preQuestGroup", "nextQuestInChain" })
    if not (q and q.name) then return nil end
    local function who(by)
        local lines = {}
        for _, id in ipairs(by and by[1] or {}) do
            local e = NpcEntry(Q, id, ICONS.npc)
            if e then lines[#lines + 1] = LB.Faction(e) end
        end
        for _, id in ipairs(by and by[2] or {}) do lines[#lines + 1] = ObjectEntry(Q, id) end
        for _, id in ipairs(by and by[3] or {}) do
            lines[#lines + 1] = { kind = "item", item = id, tip = id, icon = ItemIcon(id), line = "Starts the quest" }
        end
        return lines
    end
    local before = {}
    for _, list in ipairs({ q.preQuestSingle or {}, q.preQuestGroup or {} }) do
        for _, id in ipairs(list) do before[#before + 1] = QuestEntry(Q, id, "Before it") end
    end
    Backwards()
    return {
        id = questID, name = q.name, level = q.questLevel, required = q.requiredLevel,
        zone = q.zoneOrSort and q.zoneOrSort > 0 and q.zoneOrSort or nil,
        objectives = q.objectivesText or {}, givers = who(q.startedBy), enders = who(q.finishedBy),
        before = before, after = q.nextQuestInChain and { QuestEntry(Q, q.nextQuestInChain, "After it") } or {},
        rewards = ItemLines(rewards[questID]),
    }
end

function LB.Quests(itemID)
    local Q = LB.Q()
    if not Q then return nil end
    local lines, seen = {}, {}
    local function add(id, role)
        if not id or seen[id] then return end
        seen[id] = true
        lines[#lines + 1] = QuestEntry(Q, id, role)
    end
    -- (the core's links: QuestieDB's, and the quests naming the item in
    -- their objectives: GameData.lua)
    local starts, related = GD.ItemQuests(itemID)
    add(starts, "starts")
    for _, id in ipairs(Field(Q.Item, itemID, "questRewards") or {}) do add(id, "reward") end
    for _, id in ipairs(related or {}) do add(id, "objective") end
    return lines
end

---------------------------------------------------------------------------
-- Recipes: the core's index (GameData.lua): the bundled ones, the ones seen
-- in game on top; a row: { skillLine, makesItemID, makesCount,
-- taughtByItemID, reagent, count, ... }
---------------------------------------------------------------------------
local Index, BaseSkill = GD.Recipes, GD.BaseSkill

local function SkillName(line)
    local ui = C_TradeSkillUI
    if ui and ui.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(ui.GetProfessionInfoBySkillLineID, line)
        if ok and info and info.professionName and info.professionName ~= "" then return info.professionName end
    end
    local names = IF.RecipeData and IF.RecipeData.skills
    return names and names[line] or "Profession"
end

local function SpellName(spell)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    if not name and GetSpellInfo then name = GetSpellInfo(spell) end
    -- (a spell the client hasn't loaded yet: asked for, named once it comes)
    if not name and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spell) end
    return name or ("recipe " .. spell)
end

-- A recipe's name: what it makes (the recipe is named after it), else its
-- spell's (an enchantment makes nothing)
local function RecipeName(line)
    return line.make and ItemInfo(line.make) or SpellName(line.spell)
end

-- A recipe line's name, as drawn (names come in late: worked out each time)
function LB.RecipeName(line)
    return RecipeName(line)
end

local function RecipeLine(spell, row, go)
    local make = (row[2] or 0) > 0 and row[2] or nil
    local taught = (row[4] or 0) > 0 and row[4] or nil
    local line = {
        kind = "recipe", spell = spell, skill = row[1], make = make, row = row, taught = taught,
        icon = make and ItemIcon(make) or ICONS.recipes, quality = 1, item = go, tip = make,
        getName = RecipeName,
    }
    line.name = RecipeName(line)
    return line, taught
end

-- A profession's recipes together, by name
local function Sorted(idx, spells)
    local list = {}
    for i, spell in ipairs(spells or {}) do
        list[i] = { spell = spell, skill = SkillName(idx.rows[spell][1]), name = SpellName(spell) }
    end
    table.sort(list, function(a, b)
        if a.skill ~= b.skill then return a.skill < b.skill end
        return a.name < b.name
    end)
    for i, e in ipairs(list) do list[i] = e.spell end
    return list
end

function LB.Recipes(itemID)
    local idx = Index()
    local lines = {}
    local made = Sorted(idx, idx.makes[itemID])
    if #made > 0 then
        lines[#lines + 1] = { header = "Made by", info = #made }
        for _, spell in ipairs(made) do
            local row = idx.rows[spell]
            -- (Cross: the recipe item that teaches it, if one does)
            local line, taught = RecipeLine(spell, row, nil)
            line.item = taught
            lines[#lines + 1] = line
        end
    end
    local used = Sorted(idx, idx.uses[itemID])
    if #used > 0 then
        lines[#lines + 1] = { header = "Used in", info = #used }
        for _, spell in ipairs(used) do
            local row = idx.rows[spell]
            lines[#lines + 1] = (RecipeLine(spell, row, (row[2] or 0) > 0 and row[2] or nil))
        end
    end
    -- A recipe item: the recipe it teaches
    for spell, row in pairs(idx.rows) do
        if row[4] == itemID then
            lines[#lines + 1] = { header = "Teaches", info = 1 }
            lines[#lines + 1] = (RecipeLine(spell, row, (row[2] or 0) > 0 and row[2] or nil))
            break
        end
    end
    return lines
end

-- A profession window's recipes, kept (Forever's own recipes, which the
-- bundled index, made from Classic Era's tables, may lack)
local learnedNow = {}
function LB.Learn()
    local ui = C_TradeSkillUI
    if not (ui and ui.GetAllRecipeIDs and IF.Tasks and IF.Tasks.Recipe) or not IF.db then return end
    local ok, ids = pcall(ui.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return end
    local store = GD.SeenRecipes()
    local changed = false
    for _, id in ipairs(ids) do
        if not learnedNow[id] then
            learnedNow[id] = true
            local r = IF.Tasks.Recipe(id)
            if r and (r.output or #r.reagents > 0) then
                local got, line, _, parent = pcall(ui.GetTradeSkillLineForRecipe, id)
                local bundled = IF.RecipeData and IF.RecipeData.recipes[id]
                local skill = bundled and bundled[1] or (got and BaseSkill(line, parent)) or 0
                local row = { skill, r.output or 0, r.makes or 1, bundled and bundled[4] or 0 }
                for _, g in ipairs(r.reagents) do
                    row[#row + 1] = g.itemID
                    row[#row + 1] = g.per
                end
                local old = store[id]
                if not old or table.concat(old, ",") ~= table.concat(row, ",") then
                    store[id] = row
                    changed = true
                end
            end
        end
    end
    if changed then GD.ResetRecipes() end
end

-- A creature's portrait, as the game draws one (the book's, Book.lua):
-- LB.Portrait(npcID, texture) -> true: drawn
LB.Portrait = IF.Book.Portrait

---------------------------------------------------------------------------
-- For the page (LibraryPage.lua): the helpers it shares, the waypoint
---------------------------------------------------------------------------
LB.ItemInfo, LB.ItemIcon, LB.ItemID, LB.ZoneName, LB.PlayerArea = ItemInfo, ItemIcon, ItemID, ZoneName, PlayerArea
LB.SkillName, LB.SpellName, LB.Join, LB.ICONS = SkillName, SpellName, Join, ICONS

function LB.SpotText(spot)
    if not spot then return nil end
    return ZoneName(spot.area) .. format("  %.1f, %.1f", spot.x, spot.y)
end

-- A waypoint at the line's nearest spawn (the map's own pin, tracked): true
-- when set
function LB.Waypoint(line)
    local spot = line.spot
    if not spot then return false end
    ZoneMaps()
    local map = areaToUi[spot.area]
    local point = map and map ~= 0 and UiMapPoint and UiMapPoint.CreateFromCoordinates(map, spot.x / 100, spot.y / 100)
    if point and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        return true
    end
    return false
end

-- A zone's (an area id's) world map, or nil
function LB.UiMap(area)
    ZoneMaps()
    local map = area and areaToUi[area]
    return map and map ~= 0 and map or nil
end

---------------------------------------------------------------------------
-- What is focused: the game's cursor (a bag slot, a loot slot), else the
-- item tooltip shown last (the cursor's own, a moment ago)
---------------------------------------------------------------------------
local lastTip
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip or (LB.panel and tooltip:GetOwner() == LB.panel) then return end
        pcall(function()
            local _, link = tooltip:GetItem()
            lastTip = { item = link or (data and data.id), at = GetTime() }
        end)
    end)
end

-- The item a button of the game's shows, whatever window it's in: an item
-- location, a link or an item it keeps, a list row's data (a recipe: what
-- it makes), a character slot, a merchant's item, a quest's reward; nil
local function ButtonItem(f)
    local ok, loc = pcall(function() return f.GetItemLocation and f:GetItemLocation() end)
    if ok and loc and loc.IsValid and loc:IsValid() and C_Item.GetItemLink then
        local link = C_Item.GetItemLink(loc)
        if link then return link end
    end
    for _, key in ipairs({ "itemLink", "link", "hyperlink" }) do
        if type(f[key]) == "string" and f[key]:find("item:") then return f[key] end
    end
    local item = f.item
    if type(item) == "table" and item.GetItemLink then
        local link = item:GetItemLink() or (item.GetItemID and item:GetItemID())
        if link then return link end
    end
    if type(f.itemID) == "number" and f.itemID > 0 then return f.itemID end
    if f.GetElementData then
        local okData, data = pcall(f.GetElementData, f)
        if okData and type(data) == "table" then
            local recipe = data.recipeInfo and data.recipeInfo.recipeID
            if recipe and C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
                local out = C_TradeSkillUI.GetRecipeOutputItemData(recipe)
                if out and (out.hyperlink or out.itemID) then return out.hyperlink or out.itemID end
            end
            if data.itemLink or data.itemID then return data.itemLink or data.itemID end
        end
    end
    local name = f.GetName and f:GetName() or ""
    if name:find("^Character%a+Slot$") and f.GetID then return GetInventoryItemLink("player", f:GetID()) end
    if name:find("^MerchantItem%d+ItemButton$") and f.GetID then
        local merchant = _G.MerchantFrame
        local buyback = merchant and merchant.selectedTab == 2
        return buyback and GetBuybackItemLink(f:GetID()) or (not buyback and GetMerchantItemLink(f:GetID()))
    end
    if f.objectType == "item" and f.type and f.GetID then
        local log = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
        return log and GetQuestLogItemLink(f.type, f:GetID()) or GetQuestItemLink(f.type, f:GetID())
    end
end

-- The game's window a button is in (the frame under UIParent holding it)
local function WindowOf(f)
    while f and f.GetParent do
        local parent = f:GetParent()
        if not parent or parent == UIParent then return f end
        f = parent
    end
end

-- -> the item (link), the frame it's on, where ("bags", "loot", "ui": any
-- other window of the game's, LB.originFrame)
function LB.Focused()
    local item, anchor, origin
    pcall(function()
        local nav = _G.SmartNavigation
        local button = nav and nav.GetCurrentButton and nav:GetCurrentButton()
        if not button then return end
        anchor = button
        local element = button:GetParent()
        local loot = _G.LootFrame
        if element and element.GetSlotIndex and loot and loot:IsShown() then
            local slot = element:GetSlotIndex()
            item = slot and GetLootSlotLink(slot)
            if item then origin = "loot" end
        end
        if not item then
            for _, f in ipairs({ button, element }) do
                if f and f.GetBagID and f.GetID then
                    local bag, slot = f:GetBagID(), f:GetID()
                    item = bag and slot and C_Container.GetContainerItemLink(bag, slot)
                    if item then
                        origin = "bags"
                        break
                    end
                end
            end
        end
        -- (any other window: the button, its parent, theirs)
        local f = button
        for _ = 1, 3 do
            if item or not f then break end
            local okItem, found = pcall(ButtonItem, f)
            if okItem and found then item, origin = found, "ui" end
            f = f.GetParent and f:GetParent()
        end
        LB.originFrame = WindowOf(button)
    end)
    if not item and lastTip and GetTime() - lastTip.at < TIP_KEPT then item, origin = lastTip.item, origin or "ui" end
    return item, anchor, origin
end

---------------------------------------------------------------------------
-- The hold: the game's press-and-hold ring on R3's glyph, beside the
-- focused slot, filling; a rumble rising with it (Vibration.lua)
---------------------------------------------------------------------------
local holdIcon = IF.HoldIcon(UIParent, 26)
holdIcon:SetFrameStrata("TOOLTIP")
holdIcon:SetKey("RS")
holdIcon:Hide()
local holdLabel = K.ChatText(holdIcon, 12, KC.focusText)
holdLabel:SetPoint("LEFT", holdIcon, "RIGHT", 2, 0)
holdLabel:SetText("Hold to Open Library")

-- p: 0 to 1; anchor: the frame it sits by (nil: the screen's middle)
function LB.HoldShow(p, anchor)
    holdIcon:ClearAllPoints()
    if anchor and anchor.GetRight and anchor:GetRight() then
        holdIcon:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
    else
        holdIcon:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
    end
    holdIcon:SetProgress(p)
    holdIcon:Show()
    if IF.Vibe then IF.Vibe.Hold(p) end
end

function LB.HoldHide(done)
    if not holdIcon:IsShown() then return end
    holdIcon:Hide()
    if IF.Vibe then
        if done then IF.Vibe.Confirm() else IF.Vibe.Hold(nil) end
    end
end

-- The progress of a hold begun at start: nil (too short to show yet), 0 to 1
function LB.HoldProgress(start)
    local held = GetTime() - start
    if held < SHOW_AFTER then return nil end
    return math.min(1, (held - SHOW_AFTER) / (LB.HOLD - SHOW_AFTER))
end

---------------------------------------------------------------------------
-- The bags and the loot window: R3 (alone: R2 + R3 is the Destroy panel's) watched,
-- never bound. The game's own R3 there turns its tooltips over on the
-- press: a hold that opens the Library turns them back.
---------------------------------------------------------------------------
local function AnyBagOpen()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then return true end
    end
    return false
end

local function LootOpen()
    local loot = _G.LootFrame
    return loot and loot:IsShown() or false
end

local MODIFIERS = { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }
local function Modified()
    for _, key in ipairs(MODIFIERS) do
        if IsKeyDown(key) then return true end
    end
    return false
end

local function TipsOff()
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return get and get("GamepadDisableTooltips") or false
end

local hold                     -- { start, item, anchor, origin, tips }; done: used, wait for the release
local watcher = CreateFrame("Frame")
local wasDown = false
local tipsBefore
watcher:SetScript("OnUpdate", function()
    if not IF.db or not IsKeyDown then return end
    -- (any window of the game's with the pad, the Library up too: another
    -- item into it; the Destroy panel, the auction window: their own R3)
    local uiFocus = IF.Binds and IF.Binds.InGame and not IF.Binds.InGame()
    local active = LB.Settings().enabled and not (LB.HasFocus and LB.HasFocus()) and not IF.InCombat()
        and (uiFocus or AnyBagOpen() or LootOpen()) and not (IF.Destroy and IF.Destroy.panel:IsShown())
        and not (IF.AuctionBuy and IF.AuctionBuy.window and IF.AuctionBuy.window:IsShown())
    local down = IsKeyDown("PADRSTICK")
    if not active or not down then
        if hold then LB.HoldHide() end
        hold = nil
        if not down then tipsBefore = TipsOff() end
        wasDown = down
        return
    end
    -- The moment it goes down (alone)
    if not hold and not wasDown then
        if Modified() then
            hold = { done = true }
        else
            local item, anchor, origin = LB.Focused()
            hold = { start = GetTime(), item = item, anchor = anchor,
                origin = origin or (LootOpen() and "loot" or AnyBagOpen() and "bags" or "ui"),
                done = item == nil }
        end
    end
    wasDown = down
    if not hold or hold.done then return end
    local p = LB.HoldProgress(hold.start)
    if not p then return end
    if p < 1 then return LB.HoldShow(p, hold.anchor) end
    hold.done = true
    LB.HoldHide(true)
    if tipsBefore ~= nil and TipsOff() ~= tipsBefore and IF.Destroy then IF.Destroy.SetTipsOff(tipsBefore) end
    LB.Open(hold.item, hold.origin)
end)

---------------------------------------------------------------------------
-- The mouse: Alt + click on an item (the bags, the loot window, a chat
-- link: anywhere the game's modified clicks reach; the core's Input.lua)
-- opens its page; so does a key binding, on the item under the mouse
---------------------------------------------------------------------------
-- Where an item clicked or under the mouse is: "bags", "loot", "chat", else
-- "ui" (another window of the game's: LB.originFrame)
local function MouseOrigin(item)
    if item.bag then return "bags" end
    local f = item.owner
    for _ = 1, 3 do
        if not f then break end
        if f.GetSlotIndex and LootOpen() then return "loot" end
        if f.editBox and f.AddMessage then return "chat" end
        f = f.GetParent and f:GetParent()
    end
    LB.originFrame = WindowOf(item.owner)
    return "ui"
end

local function OpenFromMouse(item)
    if not (item and item.link and LB.Settings().enabled) or IF.InCombat() then return end
    LB.Open(item.link, MouseOrigin(item))
end

IF.Input.AddItemClick({
    id = "library", button = "LeftButton", label = "Open in the Library",
    when = function(item) return LB.Settings().enabled and ItemID(item.link) ~= nil end,
    fn = OpenFromMouse,
})
IF.Actions.PressButton("ImprovedForeverLibraryHovered", function() OpenFromMouse(IF.Input.Hovered()) end)
_G["BINDING_NAME_CLICK ImprovedForeverLibraryHovered:LeftButton"] = "Open the item under the mouse"

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pendingRender, pendingLearn = false, false
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
pcall(events.RegisterEvent, events, "SPELL_DATA_LOAD_RESULT")
events:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(events.RegisterEvent, events, "TRADE_SKILL_LIST_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- (its bindings can't be cleared once combat starts)
        LB.Close()
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        if pendingLearn then return end
        pendingLearn = true
        C_Timer.After(1, function()
            pendingLearn = false
            LB.Learn()
        end)
    elseif LB.IsShown() and not pendingRender then
        -- (item names coming in: drawn again, once)
        pendingRender = true
        C_Timer.After(0.2, function()
            pendingRender = false
            LB.Render()
        end)
    end
end)
