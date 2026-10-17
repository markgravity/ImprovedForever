-- Game data every module may read: drops, vendors and quests from QuestieDB
-- (the Questie team's data addon, read through its LibQuestieDB API) when
-- it's installed, else from our copy of its Forever data (WorldData.lua,
-- made by tools/make_library_data.py); recipes from RecipeData.lua (made by
-- tools/make_library.py from the game's own tables) and from the recipes
-- seen whenever a profession window opens (the Wiki's LB.Learn).
-- The Wiki shows it as pages; the item verdict (ItemValue.lua) asks it
-- what an item is for. Every read guarded (its Forever data is new).
local _, IF = ...

local GD = {}
IF.GameData = GD

---------------------------------------------------------------------------
-- QuestieDB (LibQuestieDB) when installed (its data the newest), else our
-- copy of it, read through the same Get / GetAll; looked for once needed
---------------------------------------------------------------------------
-- "a|b||c" -> { "a", "b", "", "c" }
local function SplitRow(s)
    local out = {}
    for part in (s .. "|"):gmatch("(.-)|") do out[#out + 1] = part end
    return out
end

local function Ids(s)
    local list = {}
    for n in s:gmatch("%d+") do list[#list + 1] = tonumber(n) end
    return #list > 0 and list or nil
end

local function Text(s)
    return s ~= "" and s or nil
end

-- "12:40.5,80.3,40.9,80.7;40:..." -> { [12] = { { 40.5, 80.3 }, ... } }
local function Spawns(s)
    local spawns
    for zone, list in s:gmatch("(%d+):([^;]*)") do
        local points, x = {}, nil
        for v in list:gmatch("[^,]+") do
            if x then
                points[#points + 1] = { x, tonumber(v) }
                x = nil
            else
                x = tonumber(v)
            end
        end
        spawns = spawns or {}
        spawns[tonumber(zone)] = points
    end
    return spawns
end

local DECODE = {
    items = function(f)
        return { npcDrops = Ids(f[1]), objectDrops = Ids(f[2]), itemDrops = Ids(f[3]), vendors = Ids(f[4]),
            questRewards = Ids(f[5]), startQuest = tonumber(f[6]), relatedQuests = Ids(f[7]) }
    end,
    npcs = function(f)
        return { name = Text(f[1]), minLevel = tonumber(f[2]), maxLevel = tonumber(f[3]), rank = tonumber(f[4]),
            zoneID = tonumber(f[5]), subName = Text(f[6]), friendlyToFaction = Text(f[7]), spawns = Spawns(f[8]) }
    end,
    objects = function(f)
        return { name = Text(f[1]), zoneID = tonumber(f[2]), spawns = Spawns(f[3]) }
    end,
    quests = function(f)
        local objectives
        for line in (f[12] or ""):gmatch("[^~]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                objectives = objectives or {}
                objectives[#objectives + 1] = line
            end
        end
        return { name = Text(f[1]), questLevel = tonumber(f[2]), zoneOrSort = tonumber(f[3]),
            requiredLevel = tonumber(f[4]), startedBy = { Ids(f[5] or ""), Ids(f[6] or ""), Ids(f[7] or "") },
            finishedBy = { Ids(f[8] or ""), Ids(f[9] or "") }, preQuestSingle = Ids(f[10] or ""),
            nextQuestInChain = tonumber(f[11]), objectivesText = objectives, requiredRaces = tonumber(f[13]),
            requiredClasses = tonumber(f[14]), exclusiveTo = Ids(f[15] or "") }
    end,
}

-- One kind of our rows as an entity of LibQuestieDB's (rows decoded once read)
local function Entity(kind)
    local rows, decode, cache = IF.WorldData[kind] or {}, DECODE[kind], {}
    local function Row(id)
        local r = cache[id]
        if r == nil then
            local s = rows[id]
            r = s and decode(SplitRow(s)) or false
            cache[id] = r
        end
        return r or nil
    end
    return {
        Get = function(id, key)
            local r = Row(id)
            return r and r[key]
        end,
        GetAll = function(id, keys)
            local r = Row(id)
            if not r then return nil end
            local out = { n = #keys }
            for i, key in ipairs(keys) do out[i] = r[key] end
            return out
        end,
    }
end

local function Bundled()
    local data = IF.WorldData
    if not data then return nil end
    local zones = { private = { areaIdToUiMapId = data.areaToUi } }
    return {
        bundled = true, source = data.source,
        Item = Entity("items"), Npc = Entity("npcs"), Object = Entity("objects"), Quest = Entity("quests"),
        Support = { Get = function(name) return name == "ZoneDB" and zones or nil end },
    }
end

local qdb                      -- the library (or our copy); false: neither
function GD.Q()
    if qdb == nil then
        qdb = false
        local lib = _G.LibQuestieDB
        if lib and lib.RequireContract then
            local ok, pass = pcall(lib.RequireContract, 1)
            if ok and pass then qdb = lib end
        end
        if not qdb then qdb = Bundled() or false end
    end
    return qdb or nil
end

-- "found" (QuestieDB installed), "bundled" (ours: QuestieDB missing, or its
-- version doesn't fit) or "missing"
function GD.QStatus()
    local q = GD.Q()
    if not q then return "missing" end
    return q.bundled and "bundled" or "found"
end

function GD.Field(entity, id, key)
    local ok, v = pcall(entity.Get, id, key)
    return ok and v or nil
end

function GD.Fields(entity, id, keys)
    local ok, v = pcall(entity.GetAll, id, keys)
    if not ok or not v then return nil end
    local out = {}
    for i, key in ipairs(keys) do out[key] = v[i] end
    return out
end

-- Ours, whether QuestieDB is installed or not: its item -> quest links
-- are filled out from the quests' objectives (make_library_data.py)
local ours
local function Ours()
    if ours == nil then
        local Q = GD.Q()
        ours = (Q and Q.bundled and Q) or Bundled() or false
    end
    return ours or nil
end

-- An item's quests: the one it starts, the ones it's needed for
-- (objectives, source items, QuestieDB's relatedQuests) -> startQuest,
-- { questID } or nil
function GD.ItemQuests(itemID)
    local Q = GD.Q()
    if not Q then return nil end
    local starts, related = GD.Field(Q.Item, itemID, "startQuest"), GD.Field(Q.Item, itemID, "relatedQuests")
    local B = Ours()
    if B and B ~= Q then
        starts = starts or GD.Field(B.Item, itemID, "startQuest")
        local more = GD.Field(B.Item, itemID, "relatedQuests")
        if more then
            local seen, all = {}, {}
            for _, list in ipairs({ related or {}, more }) do
                for _, q in ipairs(list) do
                    if not seen[q] then
                        seen[q] = true
                        all[#all + 1] = q
                    end
                end
            end
            related = all
        end
    end
    return starts, related
end

-- Sold by a vendor somewhere (QuestieDB's, else ours)
function GD.SoldByVendor(itemID)
    local Q, B = GD.Q(), Ours()
    for _, db in ipairs({ Q, B ~= Q and B or nil }) do
        local vendors = db and GD.Field(db.Item, itemID, "vendors")
        if vendors and #vendors > 0 then return true end
    end
    return false
end

-- A quest field, QuestieDB's else ours
local function QuestField(questID, key)
    local Q = GD.Q()
    local v = Q and GD.Field(Q.Quest, questID, key)
    if v == nil then
        local B = Ours()
        v = B and B ~= Q and GD.Field(B.Quest, questID, key) or v
    end
    return v
end

function GD.QuestName(questID)
    return QuestField(questID, "name")
end

-- QuestieDB's race masks (its Enum.raceMaskById when installed): one bit a
-- race, the Skyborne past 32 bits (no 32-bit bit ops: plain arithmetic)
local RACE_MASK = { [1] = 1, [2] = 2, [3] = 4, [4] = 8, [5] = 16, [6] = 32, [7] = 64, [8] = 128,
    [9] = 256, [10] = 512, [11] = 1024, [22] = 2097152, [95] = 4294967296, [96] = 8589934592 }

local function HasBit(mask, bit)
    return mask and bit and math.floor(mask / bit) % 2 == 1 or false
end

local function RaceMask()
    local race = select(3, UnitRace("player"))
    local lib = _G.LibQuestieDB
    local masks = lib and lib.Enum and lib.Enum.raceMaskById
    return (masks and race and masks[race]) or RACE_MASK[race or 0]
end

local function Completed(questID)
    local log = C_QuestLog
    return log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(questID) or false
end
GD.Completed = Completed

-- A quest the character could still do: not done, its race and class,
-- and no quest it shuts out done already (one of a choice of two)
function GD.QuestOpen(questID)
    if Completed(questID) then return false end
    local races = QuestField(questID, "requiredRaces")
    local mine = RaceMask()
    if races and races > 0 and mine and not HasBit(races, mine) then return false end
    local classes = QuestField(questID, "requiredClasses")
    local class = select(3, UnitClass("player"))
    if classes and classes > 0 and class and not HasBit(classes, 2 ^ (class - 1)) then return false end
    for _, other in ipairs(QuestField(questID, "exclusiveTo") or {}) do
        if Completed(other) then return false end
    end
    -- (a quest QuestieDB doesn't know: unknown, not open)
    return QuestField(questID, "name") ~= nil
end

---------------------------------------------------------------------------
-- An NPC's quests by its name (the minimap's dots give only names): the
-- quests it starts and the ones it ends, from our copy of the data
-- (WorldData.lua), indexed once first asked
---------------------------------------------------------------------------
local npcQuests
local function NpcQuests()
    if npcQuests then return npcQuests end
    npcQuests = {}
    local data = IF.WorldData
    if not (data and data.quests and data.npcs) then return npcQuests end
    local names = {}
    local function Add(ids, questID, key)
        for id in ids:gmatch("%d+") do
            id = tonumber(id)
            if names[id] == nil then
                local row = data.npcs[id]
                names[id] = row and row:match("^([^|]+)") or false
            end
            local name = names[id]
            if name then
                local q = npcQuests[name] or { starts = {}, ends = {} }
                npcQuests[name] = q
                q[key][#q[key] + 1] = questID
            end
        end
    end
    -- (a quest row: name|level|zone|required level|started by NPCs|objects|
    -- items|finished by NPCs|...)
    for questID, row in pairs(data.quests) do
        local starts, ends = row:match("^[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)|[^|]*|[^|]*|([^|]*)")
        if starts then
            Add(starts, questID, "starts")
            Add(ends, questID, "ends")
        end
    end
    return npcQuests
end

local function InLog(questID)
    local log = C_QuestLog
    if log and log.GetLogIndexForQuestID then return log.GetLogIndexForQuestID(questID) ~= nil end
    return log and log.IsOnQuest and log.IsOnQuest(questID) or false
end

-- A quest the character can take now: open, not in the log, its level
-- reached and one of the quests before it done
local function Available(questID)
    if InLog(questID) or not GD.QuestOpen(questID) then return false end
    local level = QuestField(questID, "requiredLevel")
    if level and level > (UnitLevel("player") or 0) then return false end
    local before = QuestField(questID, "preQuestSingle")
    if type(before) == "table" and #before > 0 then
        for _, id in ipairs(before) do
            if Completed(id) then return true end
        end
        return false
    end
    return true
end

-- An NPC's ID by its name (a quest's objective gives only names): the first
-- of that name with a look (WorldData.lua's displays), else the first;
-- indexed once first asked
local npcByName
function GD.NpcByName(name)
    if not npcByName then
        npcByName = {}
        local data = IF.WorldData or {}
        local looks = data.displays or {}
        for id, row in pairs(data.npcs or {}) do
            local npc = row:match("^([^|]+)")
            local had = npc and npcByName[npc]
            if npc and (not had or (looks[id] and not looks[had]) or (not looks[had] and id < had)
                or (looks[id] and looks[had] and id < had)) then
                npcByName[npc] = id
            end
        end
    end
    return npcByName[name]
end

-- A quest's items (the ones it needs: our copy's items' related quests,
-- filled out from the quests' objectives), indexed once first asked ->
-- { itemID } or nil
local questItems
function GD.QuestItems(questID)
    if not questItems then
        questItems = {}
        local items = IF.WorldData and IF.WorldData.items or {}
        -- (an item row: NPC drops|object drops|item drops|vendors|quest
        -- rewards|starts quest|related quests)
        for itemID, row in pairs(items) do
            local related = row:match("^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)")
            for id in (related or ""):gmatch("%d+") do
                id = tonumber(id)
                questItems[id] = questItems[id] or {}
                table.insert(questItems[id], itemID)
            end
        end
    end
    return questItems[questID]
end

-- "end": an NPC a quest in the log is handed in to; "start": one with a
-- quest the character can take; nil: neither (or an NPC not known)
function GD.QuestNpc(name)
    local q = NpcQuests()[name]
    if not q then return nil end
    for _, id in ipairs(q.ends) do
        if InLog(id) then return "end" end
    end
    for _, id in ipairs(q.starts) do
        if Available(id) then return "start" end
    end
    return nil
end

---------------------------------------------------------------------------
-- Recipes: the bundled index (RecipeData.lua), the ones seen in game on
-- top (IF.db.recipesSeen); a row: { skillLine, makesItemID, makesCount,
-- taughtByItemID, reagent, count, ... }
---------------------------------------------------------------------------
-- A profession's own skill line (RecipeData.lua's: Cooking 185...) for
-- one the game reports: Forever's are its own (Cooking 2939, Mining 2946),
-- with the profession as their parent, else named after it
local SKILL_ALIASES = { [2939] = 185, [2946] = 186 }
local baseSkill = {}
local function Known(skill)
    return skill and IF.RecipeData and IF.RecipeData.skills[skill] ~= nil
end

function GD.BaseSkill(skill, parent)
    if Known(skill) or not skill then return skill end
    if Known(parent) then return parent end
    if baseSkill[skill] == nil then
        local found = SKILL_ALIASES[skill]
        local ui = C_TradeSkillUI
        local ok, info = pcall(ui and ui.GetProfessionInfoBySkillLineID, skill)
        if not found and ok and info then
            if Known(info.parentProfessionID) then found = info.parentProfessionID end
            local name = info.parentProfessionName or info.professionName
            for id, english in pairs(not found and name and IF.RecipeData.skills or {}) do
                if name:find(english, 1, true) then found = id end
            end
        end
        baseSkill[skill] = found or false
    end
    return baseSkill[skill] or skill
end

-- The recipes seen in the profession windows: { [spellID] = row } (kept in
-- the Wiki's settings before 0.5.0: moved over)
function GD.SeenRecipes()
    local db = IF.db
    if not db then return {} end
    if not db.recipesSeen then
        local old = db.library and db.library.recipes
        db.recipesSeen = old or {}
        if old then db.library.recipes = nil end
    end
    return db.recipesSeen
end

-- { rows, makes = { [item] = { spell } }, uses = same, teaches = { [recipe item] = spell } }
local index
function GD.Recipes()
    if index then return index end
    index = { rows = {}, makes = {}, uses = {}, teaches = {} }
    local bundled = IF.RecipeData and IF.RecipeData.recipes or {}
    for spell, row in pairs(bundled) do index.rows[spell] = row end
    for spell, row in pairs(GD.SeenRecipes()) do
        -- (what the game says wins; the profession and the recipe item as
        -- the bundle has them)
        local old = index.rows[spell]
        row[1] = old and old[1] or GD.BaseSkill(row[1])
        if old and (row[4] or 0) == 0 then row[4] = old[4] end
        index.rows[spell] = row
    end
    local function push(map, item, spell)
        local list = map[item]
        if not list then
            list = {}
            map[item] = list
        end
        list[#list + 1] = spell
    end
    for spell, row in pairs(index.rows) do
        if (row[2] or 0) > 0 then push(index.makes, row[2], spell) end
        if (row[4] or 0) > 0 then index.teaches[row[4]] = spell end
        for i = 5, #row, 2 do push(index.uses, row[i], spell) end
    end
    return index
end

-- After a recipe seen is added: the index built again when next asked
function GD.ResetRecipes()
    index = nil
end

-- The professions the character has: { [skill line, RecipeData.lua's] = rank }
local skills
function GD.PlayerSkills()
    if skills then return skills end
    skills = {}
    local names = {}
    for id, english in pairs(IF.RecipeData and IF.RecipeData.skills or {}) do names[english:lower()] = id end
    local function add(skill, rank, name)
        local base = skill and GD.BaseSkill(skill)
        if not Known(base) and name then base = names[name:lower()] end
        if Known(base) then skills[base] = math.max(skills[base] or 0, rank or 1) end
    end
    -- (the game's profession list where it has one, else the skill lines)
    if GetProfessions and GetProfessionInfo then
        for _, i in ipairs({ GetProfessions() }) do
            local ok, name, _, rank, _, _, _, line = pcall(GetProfessionInfo, i)
            if ok then add(line, rank, name) end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() or 0 do
            local ok, name, header, _, rank = pcall(GetSkillLineInfo, i)
            if ok and name and not header then add(nil, rank, name) end
        end
    end
    return skills
end

local skillEvents = CreateFrame("Frame")
for _, event in ipairs({ "SKILL_LINES_CHANGED", "TRADE_SKILL_LIST_UPDATE", "LEARNED_SPELL_IN_TAB" }) do
    pcall(skillEvents.RegisterEvent, skillEvents, event)
end
skillEvents:SetScript("OnEvent", function() skills = nil end)
