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

-- (Quest items: WheelKinds.lua adds its own)
IF.RingBuilders = {
    consumables = BuildConsumables,
    emotes = BuildEmotes,
}
