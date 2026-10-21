-- What goes on each ring. Every builder returns a list of entries:
--   { label, icon, count?, type = "spell"|"item"|"macro", value, spellID?, macroName?,
--     action? (the slot's action, for the editor) }
-- A wheel's slots hold actions: "spell:<id>", "item:<id>", "macro:<name>",
-- "emote:<token>" or "phrase:<text>" (WheelKinds.lua); Emotes keeps
-- its here, the player's own wheels in MyWheels.lua, Consumables fills
-- itself from the bags, Quest items too (WheelKinds.lua).
local IF = ImprovedForever

local MAX_SLOTS = 24 -- three pages of eight
IF.MAX_SLOTS = MAX_SLOTS

local DEFAULT_EMOTES = { "wave", "hello", "thank", "cheer", "dance", "laugh", "bow", "roar" }

local SpellInfo, ItemNameByID, ItemIconByID = IF.SpellInfo, IF.ItemNameByID, IF.ItemIconByID

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function Parse(action)
    return (action or ""):match("^(%a+):(.+)$")
end

-- An action as a ring entry, or nil (a macro deleted...)
function IF.ActionEntry(action)
    local kind, value = Parse(action)
    if kind == "phrase" then
        return IF.WheelKinds and IF.WheelKinds.PhraseEntry(action)
    end
    local name, icon = IF.ActionInfo(action)
    if not name then
        return nil
    end
    if kind == "spell" then
        return { label = name, icon = icon, type = "spell", value = name, spellID = tonumber(value) }
    elseif kind == "item" then
        return { label = name, icon = icon, type = "item", value = "item:" .. value }
    elseif kind == "macro" then
        local _, _, body = GetMacroInfo(value)
        return body and { label = name, icon = icon, type = "macro", value = body, macroName = value }
    elseif kind == "emote" then
        return { label = name, icon = icon, type = "macro", value = "/" .. value }
    end
end

-- A wheel's slots (holes allowed) as ring entries, in slot order
function IF.SlotEntries(slots, max)
    local entries = {}
    for i = 1, max do
        local entry = slots[i] and IF.ActionEntry(slots[i])
        if entry then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

---------------------------------------------------------------------------
-- Emotes (account) slots
---------------------------------------------------------------------------

function IF.GetEmoteSlots()
    if not IF.db.emoteSlots then
        IF.ResetEmoteSlots()
    end
    return IF.db.emoteSlots
end

function IF.ResetEmoteSlots()
    local slots = {}
    for i, token in ipairs(DEFAULT_EMOTES) do
        slots[i] = "emote:" .. token
    end
    IF.db.emoteSlots = slots
end

-- Consumable subclasses (item class 0) in display order; others go last.
-- Consumable subclasses: 1 potion, 2 elixir, 3 flask, 4 scroll, 5 food &
-- drink, 7 bandage. Food and drink lead, then potions, bandages and scrolls.
local SUBCLASS_ORDER = { [5] = 1, [1] = 2, [7] = 3, [4] = 4, [2] = 5, [3] = 6 }
-- The first page's kinds (the rest go on the next)
local FIRST_PAGE = { [5] = true, [1] = true, [7] = true, [4] = true }

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function ContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

local function ItemInstant(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInfo then
        local _, _, _, _, icon, classID, subclassID = getInfo(itemID)
        return icon, classID, subclassID
    end
end

local function ItemName(itemID)
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    return getName and getName(itemID) or ("item:" .. itemID)
end

local function ItemCount(itemID)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(itemID) or 0
end

-- A consumable's stat values, short, for its slot ("2148 HP\n2934 Mana",
-- "+25 Agi"), read from its Use: line; nil when it has none we know
local STAT_SHORT = {
    stamina = "Sta", spirit = "Spi", strength = "Str", agility = "Agi", intellect = "Int",
    armor = "Armor", ["attack power"] = "AP", ["ranged attack power"] = "RAP",
    ["spell damage"] = "Spell", ["healing"] = "Heal", ["maximum health"] = "Max HP",
    ["health"] = "Max HP", ["mana"] = "Max Mana", ["defense"] = "Def",
}
local USE = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
local MAX_STAT_LINES = 2
-- Each value in its kind's colour (health green, mana blue, as the unit
-- frames' bars; a buff orange)
local STAT_COLOR = { hp = "ff40ff40", mana = "ff59b3ff", energy = "ffffe633", rage = "ffff4d4d", buff = "ffff9933" }
local function Colored(kind, text)
    return "|c" .. STAT_COLOR[kind] .. text .. "|r"
end

-- "455-585" or "2148" before a word ("health"), or nil
local function Amount(text, word)
    local low, high = text:match("(%d+) to (%d+) " .. word)
    if low then return low .. "-" .. high end
    return text:match("(%d+) " .. word)
end

-- "your stamina and spirit" -> "Sta/Spi"
local function StatNames(subject)
    subject = subject:gsub("^your ", ""):gsub("^the target's ", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local names = {}
    for name in (subject .. " and "):gmatch("(.-) and ") do
        name = name:gsub("^your ", ""):gsub(" resistance$", " res")
        names[#names + 1] = STAT_SHORT[name] or name:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end)
    end
    return table.concat(names, "/")
end

local function ParseStat(text)
    text = text:lower()
    local parts = {}
    local hp = Amount(text, "health") or text:match("heals (%d+) damage")
    local mana = Amount(text, "mana")
    if hp and not text:match("increases [%a' ]-health by") then parts[#parts + 1] = Colored("hp", hp .. " HP") end
    if mana and not text:match("increases [%a' ]-mana by") then parts[#parts + 1] = Colored("mana", mana .. " Mana") end
    for _, word in ipairs({ "energy", "rage" }) do
        local amount = Amount(text, word)
        if amount then parts[#parts + 1] = Colored(word, amount .. " " .. word:gsub("^%a", string.upper)) end
    end
    -- (an elixir, a scroll: "Increases Agility by 25"; "by up to 20")
    for subject, amount in text:gmatch("increases ([%a' ]-) by [upto ]*(%d+)") do
        parts[#parts + 1] = Colored("buff", "+" .. amount .. " " .. StatNames(subject))
    end
    -- (well fed: "...and gain 12 Stamina and Spirit for 15 min")
    for amount, subject in text:gmatch("gain (%d+) ([%a ]-) for") do
        parts[#parts + 1] = Colored("buff", "+" .. amount .. " " .. StatNames(subject))
    end
    for i = #parts, MAX_STAT_LINES + 1, -1 do parts[i] = nil end
    return #parts > 0 and table.concat(parts, "\n") or nil
end

-- (by item: false once read with nothing to show; not kept while the
-- tooltip isn't loaded yet)
local statCache = {}
local function ConsumableStat(bag, slot, itemID)
    if statCache[itemID] ~= nil then return statCache[itemID] or nil end
    local tips = C_TooltipInfo
    local ok, data = false, nil
    if tips and tips.GetBagItem then ok, data = pcall(tips.GetBagItem, bag, slot) end
    if not ok or type(data) ~= "table" or not data.lines or #data.lines < 2 then return nil end
    local use = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and text:sub(1, #USE) == USE then use[#use + 1] = text:sub(#USE + 1) end
    end
    local stat = ParseStat(table.concat(use, " "))
    statCache[itemID] = stat or false
    return stat
end

local function BuildConsumables()
    local seen, items = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            local itemID = ContainerItemID(bag, slot)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                local icon, classID, subclassID = ItemInstant(itemID)
                if classID == 0 then
                    table.insert(items, {
                        label = ItemName(itemID),
                        icon = icon,
                        count = ItemCount(itemID),
                        type = "item",
                        value = "item:" .. itemID,
                        order = SUBCLASS_ORDER[subclassID] or 99,
                        subclass = subclassID,
                        -- (its values on the slot, under the icon)
                        stat = ConsumableStat(bag, slot, itemID),
                    })
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.label < b.label
    end)
    for i = #items, MAX_SLOTS + 1, -1 do
        items[i] = nil
    end
    -- Pages by kind: food, drink, potions, bandages and scrolls first, the rest after
    local first, rest = {}, {}
    for _, item in ipairs(items) do
        local list = FIRST_PAGE[item.subclass] and first or rest
        list[#list + 1] = item
    end
    items.groups = {}
    if #first > 0 then items.groups[#items.groups + 1] = first end
    if #rest > 0 then items.groups[#items.groups + 1] = rest end
    return items
end

local function BuildEmotes()
    return IF.SlotEntries(IF.GetEmoteSlots(), 8)
end

IF.BuildConsumables = BuildConsumables

-- Improved Forever's own windows: each one whose module is here (its
-- button made: Actions.lua), opened by a /click of it
local PANELS = { "icmenu", "journal", "wiki", "fishcollection", "destroy" }
local function BuildPanels()
    local AC = IF.Actions
    local here = {}
    for _, key in ipairs(AC.Windows()) do here[key] = true end
    local entries = {}
    for _, key in ipairs(PANELS) do
        local macro = here[key] and AC.Macro(key)
        if macro then
            entries[#entries + 1] = { label = AC.Label(key), icon = AC.Icon(key), type = "macro", value = macro,
                action = key }
        end
    end
    return entries
end

-- (Quest items: WheelKinds.lua adds its own)
IF.RingBuilders = {
    consumables = BuildConsumables,
    emotes = BuildEmotes,
    panels = BuildPanels,
}
