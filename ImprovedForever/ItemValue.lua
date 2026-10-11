-- The item verdict: what a bag item is for, the one answer every module
-- asks (Junk's bag marks, vendor selling and Destroy panel; the auction
-- window's Sell tab). A verdict, in this order:
--   keep: marked "keep" by the player; needed for a quest in the log (a
--     junk mark doesn't count while it is: marked junk only once done), or
--     for one the character can still do (not done, its race and class,
--     not shut out by a choice made: QuestieDB, GameData.lua), or one it
--     starts; an upgrade (Upgrades.lua); a container, a reagent,
--     ammunition, a key; a reagent, a recipe or a tool for a profession
--     the character has, or its class's tool (RecipeData.lua); can't be sold;
--   junk: marked "junk" by the player; grey; gear and odds and ends that
--     are white (or green and bound) and unusable for the class, of an
--     armor type it doesn't wear, low level or cheap;
--   auction: worth clearly more at the auction house (its usual price,
--     after the cut: the Auction module's scans) than a vendor pays;
--   unknown: could be auctioned, never priced there yet;
--   vendor: anything else a vendor buys (food, trade goods...).
-- The player's marks are the character's own (IF.charDB.junkMarks: by
-- item id), so a mistaken verdict stays put once corrected.
local _, IF = ...

local IV = {}
IF.ItemValue = IV

IV.PROFIT_SHARE = 1.25         -- "worth more": over a vendor's pay by a quarter (and MinProfit)

local DEFAULTS = {
    auto = true,               -- the verdict marks junk by itself (off: greys and the player's marks only)
}

function IV.Settings()
    local db = IF.db
    db.junk = db.junk or {}
    local s = db.junk
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

---------------------------------------------------------------------------
-- Thresholds: they scale with the player's level (white gear sells for
-- about its level squared in copper, and a few levels matter more early on)
---------------------------------------------------------------------------
local function PlayerLevel()
    return math.max(1, UnitLevel("player") or 1)
end

-- A stack worth less than this (copper) is "Cheap": 1 silver at level 10,
-- 9 at 30, 36 at 60 (never under 20 copper)
function IV.Cheap()
    local level = PlayerLevel()
    return math.max(20, level * level)
end

-- At or under this item level is "Low level": a quarter of the player's
-- level under it (at least 3): 7 at level 10, 23 at 30, 45 at 60
function IV.LowLevel()
    local level = PlayerLevel()
    return level - math.max(3, math.ceil(level / 4))
end

-- "Worth more at the auction house" by at least this much (copper): 2
-- silver at level 10, 18 at 30
function IV.MinProfit()
    local level = PlayerLevel()
    return math.max(100, 2 * level * level)
end

---------------------------------------------------------------------------
-- Auction prices: the Auction module's, when loaded (Auction.lua sets it):
-- { price = fn(itemID) -> what one sells for after the cut, or nil;
--   counts = fn() -> whether prices weigh in the verdict (its settings) }
---------------------------------------------------------------------------
local auction
function IV.UseAuction(def)
    auction = def
    IV.Changed()
end

local function AuctionNet(itemID, count, forced)
    if not auction or not (forced or auction.counts()) then return nil end
    local unit = auction.price(itemID)
    return unit and math.floor(unit * count) or nil
end

---------------------------------------------------------------------------
-- The player's marks: by item id, the character's own
---------------------------------------------------------------------------
local function Marks()
    local db = IF.charDB
    if not db then return {} end
    db.junkMarks = db.junkMarks or {}
    return db.junkMarks
end

-- "junk", "keep" or nil
function IV.MarkOf(itemID)
    return itemID and Marks()[itemID] or nil
end

-- mark: "junk", "keep" or nil (the verdict's own again)
function IV.Mark(itemID, mark)
    if not itemID then return end
    Marks()[itemID] = mark
    IV.Changed()
end

function IV.MarkCount()
    local n = 0
    for _ in pairs(Marks()) do n = n + 1 end
    return n
end

function IV.ClearMarks()
    wipe(Marks())
    IV.Changed()
end

---------------------------------------------------------------------------
-- Quests: what the log needs (its objectives' items), what QuestieDB says
-- an item is for
---------------------------------------------------------------------------
local questNeeds   -- { [lowercased objective text] = quest title }

local function QuestNeeds()
    if questNeeds then return questNeeds end
    questNeeds = {}
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetInfo and log.GetQuestObjectives) then return questNeeds end
    for i = 1, log.GetNumQuestLogEntries() or 0 do
        local info = log.GetInfo(i)
        if info and not info.isHeader and info.questID then
            for _, objective in ipairs(log.GetQuestObjectives(info.questID) or {}) do
                if objective.type == "item" and objective.text then
                    questNeeds[objective.text:lower()] = info.title or "a quest"
                end
            end
        end
    end
    return questNeeds
end

local function InLog(questID)
    local log = C_QuestLog
    if log and log.GetLogIndexForQuestID then return (log.GetLogIndexForQuestID(questID) or 0) > 0 end
    return log and log.IsOnQuest and log.IsOnQuest(questID) or false
end

local function Done(questID)
    local log = C_QuestLog
    return log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(questID) or false
end

local function QuestTitle(questID)
    local log = C_QuestLog
    local title = log and log.GetTitleForQuestID and log.GetTitleForQuestID(questID)
    title = title or (IF.GameData and IF.GameData.QuestName(questID))
    return title and ("\"" .. title .. "\"") or "a quest"
end

-- Why the item is kept for a quest, or nil
local function QuestReason(itemID, name, bag, slot)
    if bag and C_Container and C_Container.GetContainerItemQuestInfo then
        local q = C_Container.GetContainerItemQuestInfo(bag, slot)
        if q and q.questID and not Done(q.questID) then return "Starts " .. QuestTitle(q.questID) end
        if q and q.isQuestItem and q.isActive ~= false then return "Needed for a quest" end
    end
    if name then
        local lower = name:lower()
        for text, title in pairs(QuestNeeds()) do
            if text:find(lower, 1, true) then return "Needed for \"" .. title .. "\"" end
        end
    end
    local GD = IF.GameData
    if not GD then return nil end
    local starts, related = GD.ItemQuests(itemID)
    if starts and not InLog(starts) and GD.QuestOpen(starts) then return "Starts " .. QuestTitle(starts) end
    for _, q in ipairs(related or {}) do
        if InLog(q) then return "Needed for " .. QuestTitle(q) end
    end
    -- (a quest still to do: not done, for this race and class)
    for _, q in ipairs(related or {}) do
        if GD.QuestOpen(q) then return "For " .. QuestTitle(q) .. ", a quest still to do" end
    end
end

-- An item anywhere (the loot window, a link): the quest it's kept for, or nil
function IV.QuestReason(itemID, name)
    return itemID and QuestReason(itemID, name) or nil
end

---------------------------------------------------------------------------
-- Professions: a reagent or a recipe for one the character has
---------------------------------------------------------------------------
local function SkillName(skill)
    local names = IF.RecipeData and IF.RecipeData.skills
    return names and names[skill] or "profession"
end

-- The profession of the character's that uses the item, or nil
local function UsedBy(itemID)
    local GD = IF.GameData
    if not GD then return nil end
    local idx, mine = GD.Recipes(), GD.PlayerSkills()
    for _, spell in ipairs(idx.uses[itemID] or {}) do
        local row = idx.rows[spell]
        if row and mine[row[1]] then return row[1] end
    end
end

-- A tool (a skinning knife, a mining pick, a fishing pole; a class's own:
-- a shaman's totems, Thieves' Tools): for one of the character's
-- professions or its class -> true, its profession's name; a tool for
-- someone else -> false; not a tool -> nil
local FISHING_POLE, FISHING = 20, 356
local function Tool(itemID, classID, subclassID)
    local data = IF.RecipeData
    local GD = IF.GameData
    if not (data and GD) then return nil end
    local lines = data.tools and data.tools[itemID]
    if not lines and classID == 2 and subclassID == FISHING_POLE then lines = { FISHING } end
    if lines then
        local mine = GD.PlayerSkills()
        for _, line in ipairs(lines) do
            if mine[line] then return true, SkillName(line) end
        end
        return false
    end
    local mask = data.classTools and data.classTools[itemID]
    if mask then
        local class = select(3, UnitClass("player"))
        return class ~= nil and math.floor(mask / 2 ^ (class - 1)) % 2 == 1
    end
end

-- A recipe item: the profession it teaches for, whether the character has it
local function Teaches(itemID)
    local GD = IF.GameData
    if not GD then return nil end
    local idx = GD.Recipes()
    local spell = idx.teaches[itemID]
    local row = spell and idx.rows[spell]
    if not row then return nil end
    return row[1], GD.PlayerSkills()[row[1]] ~= nil
end

---------------------------------------------------------------------------
-- The tooltip: a red line (a class, an armor or weapon type the character
-- can't use; its level apart: that only means "later"), "Already known"
---------------------------------------------------------------------------
local MIN_LEVEL = ITEM_MIN_LEVEL and ("^" .. ITEM_MIN_LEVEL:gsub("%%d", "%%d+") .. "$")

local function IsRed(c)
    return c and c.r and c.r > 0.9 and c.g < 0.2 and c.b < 0.2 or false
end

-- (by link: the same item reads the same until the character changes:
-- a level, a skill, a spell learned)
local tipCache = {}
local function Tip(bag, slot, link)
    local hit = link and tipCache[link]
    if hit then return hit[1], hit[2] end
    local red, known = false, false
    local tips = C_TooltipInfo
    local ok, data = false, nil
    if tips and tips.GetBagItem then ok, data = pcall(tips.GetBagItem, bag, slot) end
    if not ok or type(data) ~= "table" or not data.lines then return false, false end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text and ITEM_SPELL_KNOWN and text == ITEM_SPELL_KNOWN then known = true end
        if text and text ~= "" and (IsRed(line.leftColor) or IsRed(line.rightColor))
            and not (MIN_LEVEL and text:match(MIN_LEVEL)) and text ~= ITEM_SPELL_KNOWN then
            red = true
        end
    end
    if link then tipCache[link] = { red, known } end
    return red, known
end

-- Each class's armor (cloth 1, leather 2, mail 3, plate 4): its first,
-- then from level 40 the heavier one it learns (Upgrades.lua's)
local CLASS_ARMOR = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2 }, DRUID = { 2 }, MAGE = { 1 }, PRIEST = { 1 }, WARLOCK = { 1 },
}
-- The slots where the armor type counts (a cloak is cloth for everyone)
local ARMOR_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

-- Armor lighter than the class wears from now on (cloth for a warrior)
local function NotMyArmor(classID, subclassID, equipLoc)
    if classID ~= 4 or not ARMOR_SLOTS[equipLoc or ""] or not subclassID or subclassID < 1 or subclassID > 4 then
        return false
    end
    local _, class = UnitClass("player")
    local list = CLASS_ARMOR[class]
    if not list then return false end
    local main = (#list > 1 and PlayerLevel() >= 40) and list[2] or list[1]
    return subclassID < main
end

---------------------------------------------------------------------------
-- The verdict
---------------------------------------------------------------------------
-- Item classes always kept: containers, reagents, projectiles, quivers,
-- quest items, keys (recipes: by their profession, below)
local KEEP_CLASS = { [1] = true, [5] = true, [6] = true, [11] = true, [12] = true, [13] = true }
-- Spares: consumables (food, potions...) and trade goods (cloth, herbs...),
-- the things kept for later: sold, never junk by themselves
local SPARE_CLASS = { [0] = true, [7] = true }

-- 10350 -> "1 [gold] 3 [silver] 50 [copper]", with the game's coin icons
local COINS = {
    { 10000, "Interface\\MoneyFrame\\UI-GoldIcon" },
    { 100, "Interface\\MoneyFrame\\UI-SilverIcon" },
    { 1, "Interface\\MoneyFrame\\UI-CopperIcon" },
}
function IV.Money(copper)
    copper = math.floor(copper or 0)
    local parts = {}
    for _, coin in ipairs(COINS) do
        local n = math.floor(copper / coin[1])
        copper = copper - n * coin[1]
        if n > 0 then parts[#parts + 1] = n .. " |T" .. coin[2] .. ":0:0:2:0|t" end
    end
    return #parts > 0 and table.concat(parts, " ") or ("0 |T" .. COINS[3][2] .. ":0:0:2:0|t")
end
local Money = IV.Money

local cache = {}               -- "bag:slot" -> { key, entry }

-- A bag slot's verdict -> entry { bag, slot, itemID, link, name, icon,
-- quality, count, vendor (one's pay), value (the stack's), sellable,
-- bound, auctionable, ah (the stack after the cut, or nil), verdict, why,
-- tag (short: "Junk", "Unusable", "Low level", "Cheap", "Common",
-- "Marked"...), rank (lower goes first), spare, mark }; nil: empty, or
-- the game hasn't sent its data yet.
-- opts: { count (a stack counted together), auction (true: the auction
-- house is the question, prices weigh in whatever the settings) }
function IV.Judge(bag, slot, opts)
    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then return nil end
    local count = (opts and opts.count) or info.stackCount or 1
    local forced = opts and opts.auction or false
    local key = info.itemID .. ":" .. count .. (forced and ":a" or "")
    local hit = cache[bag .. ":" .. slot]
    if hit and hit.key == key then return hit.entry end

    local id = info.itemID
    local name, link, quality, itemLevel, minLevel, _, _, _, equipLoc, _, sellPrice, classID, subclassID, bindType =
        ItemInfo(id)
    if not name then
        -- (asked for: judged once it comes, GET_ITEM_INFO_RECEIVED)
        IV.waiting = true
        return nil
    end
    quality = quality or info.quality or 1
    local vendor = (not info.hasNoValue) and sellPrice or 0
    local bound = info.isBound or false
    local auctionable = not bound and bindType ~= 4 and quality >= 1
    if forced and C_AuctionHouse and C_AuctionHouse.IsSellItemValid and ItemLocation then
        local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
        auctionable = loc:IsValid() and C_AuctionHouse.IsSellItemValid(loc, false) or false
    end
    local e = {
        bag = bag, slot = slot, itemID = id, link = info.hyperlink or link, name = name, icon = info.iconFileID,
        quality = quality, count = count, vendor = vendor, value = vendor * count, sellable = vendor > 0,
        bound = bound, auctionable = auctionable, mark = IV.MarkOf(id), rank = 5, spare = SPARE_CLASS[classID] or false,
    }
    local function done(verdict, why, tag, rank)
        e.verdict, e.why, e.tag, e.rank = verdict, why, tag or e.tag, rank or e.rank
        cache[bag .. ":" .. slot] = { key = key, entry = e }
        return e
    end

    if e.mark == "keep" then return done("keep", "Kept by you", "Marked") end
    -- (a quest's item before the player's junk mark: never junk while needed)
    local quest = QuestReason(id, name, bag, slot)
    if quest then return done("keep", quest, "Quest") end
    if e.mark == "junk" then return done("junk", "Marked as junk by you", "Marked", 0) end
    if IF.Upgrades and e.link and IF.Upgrades.IsUpgrade(e.link, bag, slot, true) then
        local _, needLevel = IF.Upgrades.Gain(e.link, bag, slot, true)
        return done("keep", needLevel and ("An upgrade for you at level " .. needLevel) or "An upgrade for you",
            "Upgrade")
    end
    if quality == 0 then return done("junk", "Grey: worth only what a vendor pays", "Junk", 0) end
    if KEEP_CLASS[classID] then return done("keep", "Kept: a container, reagent, ammunition or key", "Kept") end
    if vendor == 0 and not auctionable then return done("keep", "Can't be sold", "Kept") end

    e.ah = auctionable and AuctionNet(id, count, forced) or nil
    local profit = e.ah and e.ah > e.value * IV.PROFIT_SHARE and e.ah - e.value >= IV.MinProfit()
    local function sell(tag, rank)
        if profit then
            return done("auction", "About " .. Money(e.ah - e.value) .. " more at the auction house than from a vendor",
                tag, rank)
        end
        if auctionable and not e.ah and (forced or (auction and auction.counts() and quality >= 2)) then
            return done("unknown", "Not seen at the auction house yet", tag, rank)
        end
        if vendor == 0 then return done("keep", "Can't be sold to a vendor", tag, rank) end
        if not auctionable then return done("vendor", "Can't be auctioned: a vendor pays " .. Money(e.value), tag, rank) end
        if e.ah and e.ah > e.value then
            return done("vendor", "Only about " .. Money(e.ah - e.value) .. " more at the auction house", tag, rank)
        end
        return done("vendor", "A vendor pays " .. Money(e.value), tag, rank)
    end

    -- A recipe: kept for a profession the character has and doesn't know it yet
    if classID == 9 then
        local skill, mine = Teaches(id)
        local _, known = Tip(bag, slot, e.link)
        if known then
            if bound and IV.Settings().auto then return done("junk", "A recipe you already know", "Known", 2) end
            return sell("Known", 2)
        end
        if mine then return done("keep", "A recipe for your " .. SkillName(skill), "Recipe") end
        return sell("Recipe", 4)
    end
    -- A reagent the character's professions use
    if classID ~= 2 and classID ~= 4 then
        local skill = UsedBy(id)
        if skill then return done("keep", "Used by your " .. SkillName(skill), "Reagent") end
    end
    -- A tool: kept for the character's professions or class; another's sold,
    -- never junk by itself
    local tool, toolFor = Tool(id, classID, subclassID)
    if tool then return done("keep", "A tool" .. (toolFor and (" for your " .. toolFor) or " of yours"), "Tool") end
    if tool == false then return sell("Tool", 4) end
    if e.spare then return sell("Common", 4) end
    if classID ~= 2 and classID ~= 4 and classID ~= 15 then return sell("Common", 4) end
    -- Gear and odds and ends with a use of their own (a Hearthstone...): kept
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if getSpell and getSpell(id) then return done("keep", "Has a use", "Kept") end

    local tag, rank
    if classID == 15 and subclassID == 0 and quality == 1 then
        tag, rank = "Junk", 0
    elseif (classID == 2 or classID == 4) and Tip(bag, slot, e.link) then
        tag, rank = "Unusable", 1
    elseif NotMyArmor(classID, subclassID, equipLoc) then
        tag, rank = "Not your armor", 1
    else
        local level = (minLevel and minLevel > 1) and minLevel or itemLevel
        if classID ~= 15 and level and level > 0 and level <= IV.LowLevel() then
            tag, rank = "Low level", 2
        elseif e.value < IV.Cheap() then
            tag, rank = "Cheap", 3
        else
            tag, rank = "Common", 4
        end
    end
    -- Junk by itself: white ones up to cheap; green ones unusable or
    -- outlevelled, once bound (no buyer but a vendor); never one worth
    -- more at the auction house
    local auto = IV.Settings().auto
    local junk = auto and not profit and vendor > 0
        and ((quality == 1 and rank <= 3) or (quality == 2 and rank <= 2 and not auctionable))
    if junk then
        local why = {
            Junk = "Junk: worth only what a vendor pays",
            Unusable = "You can't use it",
            ["Not your armor"] = "Lighter armor than you wear",
            ["Low level"] = "Too low level for you",
            Cheap = "Worth next to nothing",
        }
        return done("junk", why[tag] or tag, tag, rank)
    end
    return sell(tag, rank)
end

function IV.IsJunk(bag, slot)
    local e = IV.Judge(bag, slot)
    return e and e.verdict == "junk" or false
end

-- Every bag (the reagent bag too): a list of entries; filter(entry): kept
function IV.Bags(filter)
    local list = {}
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 1))
    for bag = 0, last do
        local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local e = IV.Judge(bag, slot)
            if e and (not filter or filter(e)) then list[#list + 1] = e end
        end
    end
    return list
end

-- The player's word on a bag item, flipped: junk becomes not junk, anything
-- else junk; a mark only where the verdict wouldn't say so by itself ->
-- its entry after
function IV.Toggle(bag, slot)
    local e = IV.Judge(bag, slot)
    if not e then return nil end
    -- (a quest's item: never marked junk while needed)
    if e.tag == "Quest" then return e end
    local wasJunk, marks = e.verdict == "junk", Marks()
    marks[e.itemID] = nil
    wipe(cache)
    local again = IV.Judge(bag, slot)
    if not again or (again.verdict == "junk") == wasJunk then marks[e.itemID] = wasJunk and "keep" or "junk" end
    IV.Changed()
    return IV.Judge(bag, slot)
end

---------------------------------------------------------------------------
-- Changes: the verdicts forgotten, the listeners told (a moment later:
-- events come many at once)
---------------------------------------------------------------------------
local listeners, queued = {}, false

function IV.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function IV.Changed()
    wipe(cache)
    questNeeds = nil
    if queued then return end
    queued = true
    C_Timer.After(0.1, function()
        queued = false
        for _, fn in ipairs(listeners) do fn() end
    end)
end

IF.OnLogin(function()
    if IF.Upgrades and IF.Upgrades.OnChange then IF.Upgrades.OnChange(IV.Changed) end
    local f = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED",
        "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function(_, event)
        -- (item data arrives all the time: only when one was missing)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if not IV.waiting then return end
            IV.waiting = false
        elseif event ~= "BAG_UPDATE_DELAYED" and event ~= "QUEST_LOG_UPDATE" then
            -- (the character changed: its tooltips read again)
            wipe(tipCache)
        end
        IV.Changed()
    end)
end)
