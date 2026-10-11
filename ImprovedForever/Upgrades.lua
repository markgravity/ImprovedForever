-- Upgrades, adapted from Easy Controller - Forever's "better items"
-- (moust4ki, MIT License, see LICENSE-EasyController.md): an item better
-- than what is equipped in its slot gets the game's green arrow: on the
-- bag buttons, and in the Buy window (AuctionBuy.lua). Better: a higher
-- score from the item's stats (damage per second, strength, agility,
-- stamina, intellect, spirit, armor, attack and spell power), weighed for
-- the class, and for a hybrid by the talent tree with the most points
-- (healer, tank or damage); the item level when the client gives no stats.
-- Only what the character can wear: no red line in its tooltip (armor
-- type, weapon skill, class), its level reached, and the class's main
-- armor type or the type already worn in that slot (no cloth for a
-- warrior). Rings, trinkets and one-hand weapons are compared with the
-- weaker of the two; a two-hand weapon with both hands.
-- The arrows are textures of ours on the bag buttons: nothing written in
-- the game's frames. The Destroy panel never offers an upgrade.
local _, IF = ...

local UP = {}
IF.Upgrades = UP

local ARMOR = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
UP.ARROW_ATLAS = "bags-greenarrow"

local DEFAULTS = {
    bags = true,       -- arrows on the bag buttons (the Buy window's: its Upgrades filter)
}

function UP.Settings()
    local db = IF.db
    db.upgrades = db.upgrades or {}
    local settings = db.upgrades
    for k, v in pairs(DEFAULTS) do
        if settings[k] == nil then settings[k] = v end
    end
    return settings
end

-- Where each kind of item goes (inventory slots)
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- What a worn two-hand weapon takes the place of
local ONE_HAND = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
}
-- The slots where the armor type counts (a cloak is cloth for everyone)
local ARMOR_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}
-- Each class's armor (cloth 1, leather 2, mail 3, plate 4): its first, then
-- from level 40 the heavier one it learns
local CLASS_ARMOR = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2 }, DRUID = { 2 }, MONK = { 2 }, DEMONHUNTER = { 2 },
    MAGE = { 1 }, PRIEST = { 1 }, WARLOCK = { 1 }, DEATHKNIGHT = { 4 }, EVOKER = { 3 },
}

local function ItemInfo(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then return get(item) end
end

local function SubclassOf(item)
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    return get and select(7, get(item))
end

local function ItemLevel(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local level = C_Item.GetDetailedItemLevelInfo(link)
        if level then return level end
    end
    return select(4, ItemInfo(link)) or 0
end

---------------------------------------------------------------------------
-- The score of an item: its stats, weighed for the class (for leveling:
-- what makes the character hit, heal or hold the hardest first)
---------------------------------------------------------------------------
local STAT = {
    str = { "ITEM_MOD_STRENGTH_SHORT" }, agi = { "ITEM_MOD_AGILITY_SHORT" },
    sta = { "ITEM_MOD_STAMINA_SHORT" }, int = { "ITEM_MOD_INTELLECT_SHORT" }, spi = { "ITEM_MOD_SPIRIT_SHORT" },
    ap = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT" },
    rap = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    sp = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
    heal = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
    armor = { "RESISTANCE0_NAME" },
}
local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
-- dps: a melee weapon's damage per second, rdps: a ranged weapon's (bows,
-- guns, crossbows, thrown, wands)
local SCALES = {
    WARRIOR = { dps = 3, rdps = 0.5, str = 1, agi = 0.6, sta = 0.5, ap = 0.5, armor = 0.01 },
    WARRIOR_TANK = { dps = 1, sta = 1, str = 0.6, agi = 0.5, armor = 0.04 },
    ROGUE = { dps = 3, rdps = 0.5, agi = 1, str = 0.5, sta = 0.4, ap = 0.5 },
    HUNTER = { dps = 0.5, rdps = 3, agi = 1, int = 0.3, sta = 0.5, ap = 0.3, rap = 0.5 },
    MAGE = { rdps = 1, int = 1, sp = 1, sta = 0.6, spi = 0.4 },
    WARLOCK = { rdps = 1, int = 0.8, sp = 1, sta = 0.8, spi = 0.4 },
    PRIEST = { rdps = 1, int = 1, sp = 0.9, heal = 0.6, spi = 0.8, sta = 0.5 },
    PALADIN = { dps = 2.5, str = 1, int = 0.5, sta = 0.5, agi = 0.4, ap = 0.4 },
    PALADIN_HEAL = { int = 1, heal = 0.8, sp = 0.4, spi = 0.4, sta = 0.4 },
    PALADIN_TANK = { dps = 1, sta = 1, str = 0.6, int = 0.3, armor = 0.03 },
    SHAMAN = { dps = 2.5, str = 0.8, agi = 0.7, int = 0.5, sta = 0.5, ap = 0.4 },
    SHAMAN_CASTER = { int = 1, sp = 0.9, heal = 0.5, spi = 0.4, sta = 0.5 },
    DRUID = { agi = 0.9, str = 0.9, sta = 0.6, ap = 0.4, int = 0.3 },
    DRUID_CASTER = { int = 1, sp = 0.9, heal = 0.5, spi = 0.6, sta = 0.4 },
}
-- The talent tree with the most points, for the classes it changes
local TREE_SCALE = {
    WARRIOR = { [3] = "WARRIOR_TANK" },
    PALADIN = { [1] = "PALADIN_HEAL", [2] = "PALADIN_TANK" },
    SHAMAN = { [1] = "SHAMAN_CASTER", [3] = "SHAMAN_CASTER" },
    DRUID = { [1] = "DRUID_CASTER", [3] = "DRUID_CASTER" },
}

-- The client's list of an item's stats (nil: none in this client)
local function GetStats()
    return C_Item and C_Item.GetItemStats or GetItemStats
end

-- The talent tree with the most points
local function MainTree()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, spec = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and type(spec) == "number" and spec > 0 then return spec end
    end
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local best, bestPoints = nil, 0
    for i = 1, GetNumTalentTabs() or 0 do
        -- Classic: name, icon, points...; later clients: id, name, text, icon, points...
        local info = { GetTalentTabInfo(i) }
        local points = type(info[1]) == "number" and info[5] or info[3]
        if type(points) == "number" and points > bestPoints then best, bestPoints = i, points end
    end
    return best
end

-- The class's weights
local function Scale()
    local _, class = UnitClass("player")
    local tree = MainTree()
    local variant = tree and TREE_SCALE[class] and TREE_SCALE[class][tree]
    return SCALES[variant or class]
end

-- An item's score (nil: no stats from the client)
local function Score(link, scale)
    local get = GetStats()
    if not (get and link and scale) then return nil end
    local ok, stats = pcall(get, link)
    if not ok or type(stats) ~= "table" then return nil end
    local score = 0
    for key, weight in pairs(scale) do
        for _, name in ipairs(STAT[key] or {}) do
            score = score + (tonumber(stats[name]) or 0) * weight
        end
    end
    local dps = tonumber(stats[DPS])
    if dps then
        local equipLoc = select(9, ItemInfo(link))
        local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN"
        score = score + dps * (ranged and (scale.rdps or 0) or (scale.dps or 0))
    end
    return score
end

-- (level: the one it is worn at; now by default)
local function MainArmor(level)
    local _, class = UnitClass("player")
    local list = CLASS_ARMOR[class]
    if not list then return nil end
    level = level or UnitLevel("player") or 1
    return (#list > 1 and level >= 40) and list[2] or list[1]
end

local function IsRed(color)
    if type(color) ~= "table" then return false end
    local r, g, b
    if color.GetRGB then r, g, b = color:GetRGB() else r, g, b = color.r, color.g, color.b end
    return r and r > 0.9 and g < 0.2 and b < 0.2 or false
end

-- "Requires Level %d": the one red line that only means "later"
local MIN_LEVEL = ITEM_MIN_LEVEL and ("^" .. ITEM_MIN_LEVEL:gsub("%%d", "%%d+") .. "$")

-- Wearable: the game writes in red what the character can't use (its
-- tooltip: of a bag slot, else of the link); later: its level apart
local function Wearable(link, bag, slot, later)
    local tips = C_TooltipInfo
    if not tips then return true end
    local ok, data
    if bag and tips.GetBagItem then
        ok, data = pcall(tips.GetBagItem, bag, slot)
    elseif tips.GetHyperlink then
        ok, data = pcall(tips.GetHyperlink, link)
    end
    if not ok or type(data) ~= "table" or not data.lines then return true end
    for _, line in ipairs(data.lines) do
        local levelLine = later and MIN_LEVEL and line.leftText and line.leftText:match(MIN_LEVEL)
        if not levelLine and (IsRed(line.leftColor) or IsRed(line.rightColor)) then return false end
    end
    return true
end

-- Better than what is equipped there; and whether that can't be told yet
-- (the game hasn't sent its data): false, true; then its gain (percent)
-- and the level it needs when above the character's. bag / slot: a bag
-- item's. later: one of a higher level counts too (an upgrade once
-- reached), else it is never one.
-- (UP.Explain: why, line by line)
local trace
local function T(msg)
    if trace then trace[#trace + 1] = msg end
end

local function Compare(link, bag, slot, later)
    local name, _, _, _, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = ItemInfo(link)
    if not name then return false, true, T("item data not loaded yet") end
    local slots = SLOTS[equipLoc]
    if not slots then return false, nil, T("not worn in a slot (" .. tostring(equipLoc) .. ")") end
    local level = UnitLevel("player") or 1
    local needLevel = (reqLevel or 0) > level and reqLevel or nil
    if needLevel and not later then return false, nil, T("needs level " .. reqLevel) end
    if equipLoc == "INVTYPE_WEAPON" and not (CanDualWield and CanDualWield()) then slots = { 16 } end
    local getInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    -- A shield or an off-hand item worn: a one-hand weapon is weighed
    -- against the weapon only
    if equipLoc == "INVTYPE_WEAPON" and #slots == 2 and getInstant then
        local off = GetInventoryItemLink("player", 17)
        local offLoc = off and select(4, getInstant(off))
        if offLoc == "INVTYPE_SHIELD" or offLoc == "INVTYPE_HOLDABLE" then slots = { 16 } end
    end
    -- A two-hand weapon worn holds both hands: a one-hand weapon, a shield or
    -- an off-hand item has to beat it whole
    local mainHand = GetInventoryItemLink("player", 16)
    if mainHand and getInstant and select(4, getInstant(mainHand)) == "INVTYPE_2HWEAPON" and ONE_HAND[equipLoc] then
        slots = { 16 }
    end
    -- The score when the client gives stats, else the item level
    local scale = Scale()
    local byScore = scale ~= nil and Score(link, scale) ~= nil
    T(byScore and "scored by stats for your class" or "scored by item level (no stats or no weights)")
    local function Measure(l)
        if not l then return 0 end
        -- (a worn item not cached yet isn't an empty slot: told later)
        if not ItemInfo(l) then return nil end
        if byScore then return Score(l, scale) end
        return ItemLevel(l)
    end
    -- The weaker of what is worn there (nothing: anything is better); a
    -- two-hand weapon takes both hands' place
    local weakest, worn
    for _, s in ipairs(slots) do
        local equipped = GetInventoryItemLink("player", s)
        local v = Measure(equipped)
        if v == nil then return false, true end
        if not weakest or v < weakest then weakest, worn = v, equipped end
    end
    if equipLoc == "INVTYPE_2HWEAPON" and byScore then
        local offHand = Measure(GetInventoryItemLink("player", 17))
        if offHand == nil then return false, true end
        weakest = weakest + offHand
    end
    if classID == ARMOR and ARMOR_SLOTS[equipLoc] and subclassID and subclassID >= 1 and subclassID <= 4 then
        local wornType = worn and SubclassOf(worn)
        if subclassID ~= MainArmor(needLevel) and subclassID ~= wornType then
            return false, nil, T("not your armour type")
        end
    end
    -- Clearly better: a score above by a little more than nothing
    local new, old = Measure(link), weakest or 0
    T(format("this %.1f, worn %.1f (%s)", new or 0, old, worn or "nothing"))
    if byScore then
        local margin = math.max(0.5, old * 0.02)
        if new <= old + margin then
            -- Scores alike, never lower: the item level decides (on an empty
            -- slot, a score of nothing only for armour, as plain white pieces)
            if new < old - 1e-6 then return false, nil, T("lower score") end
            if not worn and new == 0 and not ARMOR_SLOTS[equipLoc] then return false, nil, T("no stats, empty slot") end
            if ItemLevel(link) <= (worn and ItemLevel(worn) or 0) then
                return false, nil, T("about the same score, not a higher item level")
            end
        end
    elseif new <= old then
        return false, nil, T("not a higher item level")
    end
    if not Wearable(link, bag, slot, needLevel ~= nil) then return false, nil, T("a red line in its tooltip (can't use)") end
    T("an upgrade")
    -- How much better: a share of what is worn (nothing worn: none to tell)
    return true, false, (worn and old > 0) and (new - old) / old * 100 or nil, needLevel
end

-- Kept until the gear, the level or the talents change
local cache = {}   -- key -> { better, gain, needLevel }
UP.waiting = false

local function Check(link, bag, slot, later)
    local key = (bag and (link .. "@" .. bag .. ":" .. slot) or link) .. (later and "#later" or "")
    local known = cache[key]
    if known then return known end
    local better, unknown, gain, needLevel = Compare(link, bag, slot, later)
    if unknown then
        UP.waiting = true
        return nil
    end
    known = { better = better and true or false, gain = gain, needLevel = needLevel }
    cache[key] = known
    return known
end

-- An upgrade now (false, true: not known yet). later: or once its level
-- is reached (an auction's)
function UP.IsUpgrade(link, bag, slot, later)
    if not link then return false end
    local c = Check(link, bag, slot, later)
    if not c then return false, true end
    return c.better
end

-- An upgrade's gain over what is worn, in percent (nil: not an upgrade, an
-- empty slot, or not known yet), and the level it needs (nil: reached)
function UP.Gain(link, bag, slot, later)
    local c = link and Check(link, bag, slot, later)
    if not (c and c.better) then return nil end
    return c.gain, c.needLevel
end

-- An auction group's (an item key): its plain item (no random stats);
-- one of a higher level counts (an upgrade once reached)
function UP.IsUpgradeKey(itemKey)
    local link = select(2, ItemInfo(itemKey.itemID))
    if not link then
        UP.waiting = true
        return false, true
    end
    return UP.IsUpgrade(link, nil, nil, true)
end

function UP.GainKey(itemKey)
    local link = select(2, ItemInfo(itemKey.itemID))
    if not link then return nil end
    return UP.Gain(link, nil, nil, true)
end

-- Why an item is an upgrade or not: lines to print (/if upgrade)
function UP.Explain(link, later)
    trace = {}
    local ok = pcall(Compare, link, nil, nil, later)
    local lines = trace
    trace = nil
    if not ok then lines[#lines + 1] = "error comparing" end
    return lines
end

-- A bag item's (off or not: an upgrade is kept)
function UP.IsBagUpgrade(bag, slot)
    local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
    return link and UP.IsUpgrade(link, bag, slot) or false
end

---------------------------------------------------------------------------
-- The arrows on the bag buttons
---------------------------------------------------------------------------
local arrows = setmetatable({}, { __mode = "k" })
local bagFrames = {}
local listeners = {}

function UP.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- An arrow of ours, hidden: at a frame's bottom right (a bag button), or
-- placed as asked
function UP.Arrow(parent, point, relative, relativePoint, x, y)
    local arrow = parent:CreateTexture(nil, "OVERLAY", nil, 4)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(UP.ARROW_ATLAS) then
        arrow:SetAtlas(UP.ARROW_ATLAS, true)
    else
        -- Our own triangle, pointing up, in green
        arrow:SetTexture("Interface\\AddOns\\ImprovedForever\\textures\\ic_tri")
        arrow:SetTexCoord(0, 1, 1, 0)
        arrow:SetVertexColor(0.25, 1, 0.25)
        arrow:SetSize(14, 14)
    end
    arrow:SetPoint(point or "BOTTOMRIGHT", relative or parent, relativePoint or point or "BOTTOMRIGHT", x or -1, y or 1)
    arrow:Hide()
    return arrow
end

local function UpdateArrows(frame)
    if not (frame and frame.EnumerateValidItems and frame:IsShown()) then return end
    local on = IF.db and UP.Settings().bags
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
        local link = on and bag and C_Container.GetContainerItemLink(bag, slot)
        local better = link and UP.IsUpgrade(link, bag, slot) or false
        local arrow = arrows[button]
        if better and not arrow then
            arrow = UP.Arrow(button)
            arrows[button] = arrow
        end
        if arrow then arrow:SetShown(better) end
    end
end

function UP.Refresh()
    wipe(cache)
    UP.waiting = false
    for _, frame in ipairs(bagFrames) do UpdateArrows(frame) end
    for _, fn in ipairs(listeners) do fn() end
end

local function HookBags()
    local frames = { _G.ContainerFrameCombinedBags }
    local count = NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 12) + 1)
    for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems then
            bagFrames[#bagFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", UpdateArrows)
        end
    end
end

IF.OnLogin(function()
    HookBags()
    local f = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
        "GET_ITEM_INFO_RECEIVED", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function(_, event)
        -- An item's data arrived: only when one was missing (a moment later:
        -- they come many at once)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if not UP.waiting or UP.queued then return end
            UP.queued = true
            C_Timer.After(0.2, function()
                UP.queued = false
                UP.Refresh()
            end)
            return
        end
        UP.Refresh()
        -- A level gained: the game may still give the old one right now
        if event == "PLAYER_LEVEL_UP" then C_Timer.After(1, UP.Refresh) end
    end)
end)
