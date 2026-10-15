-- What a wheel of the player's own can be (its kind, picked when it's made
-- in the Wheels tab, WheelEditor.lua): slots they fill ("custom", chat
-- phrases), or one that fills itself as Consumables does: the quest items
-- in the bags, a shaman's totems, the trinkets that fit a slot. Each
-- builds ring entries (RingContent.lua's shape), in pages by group
-- (entries.groups, each with an optional label), and says what an empty
-- wheel shows (entries.empty). Contents change out of combat only (Ring.lua
-- rebuilds after the fight).
local IF = ImprovedForever

local KD = { ORDER = {}, BY_KEY = {} }
IF.WheelKinds = KD

local function Add(kind)
    KD.ORDER[#KD.ORDER + 1] = kind
    KD.BY_KEY[kind.key] = kind
end

-- A kind by its key (a wheel made before kinds: its own slots)
function KD.Get(key)
    return KD.BY_KEY[key or "custom"] or KD.BY_KEY.custom
end

-- The kinds this character can make, in order (kind.order)
function KD.Available()
    local list = {}
    for _, kind in ipairs(KD.ORDER) do
        if not (kind.builtIn or kind.hidden) and (not kind.available or kind.available()) then
            list[#list + 1] = kind
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

---------------------------------------------------------------------------
-- The bags
---------------------------------------------------------------------------
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

-- icon, classID, subclassID, equip location
local function ItemInstant(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInfo then
        local _, _, _, equipLoc, icon, classID, subclassID = getInfo(itemID)
        return icon, classID, subclassID, equipLoc
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

local function ItemSpell(itemID)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    return getSpell and getSpell(itemID)
end

local function ByLabel(a, b)
    return a.label < b.label
end

-- Every bag slot's item once: fn(itemID, bag, slot)
local function EachBagItem(fn)
    local seen = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            local itemID = ContainerItemID(bag, slot)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                fn(itemID, bag, slot)
            end
        end
    end
end

-- Groups (lists) cut to `max` slots in all, each group starting a page
-- (8 a slot): what fits
local function Paged(groups, max)
    local out, used = { groups = {} }, 0
    for _, group in ipairs(groups) do
        if #group > 0 and used < max then
            local kept = { label = group.label }
            for _, entry in ipairs(group) do
                if used + #kept >= max then break end
                kept[#kept + 1] = entry
                out[#out + 1] = entry
            end
            out.groups[#out.groups + 1] = kept
            used = used + math.ceil(#kept / 8) * 8
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Chat phrases ("phrase:<text>", or "phrase:<channel>|<text>" for one
-- said on a channel of its own): a slot's secure macro ("/p Thanks!"), so
-- a pick (a key press) sends it like a typed line, /say included (outdoors
-- it needs a key press, which this is). With no channel: the instance's
-- group (a battleground...), else the raid, else the party, else /say; the
-- macro is made when the rings are, so a group joined mid-fight is used
-- once it ends. The phrases the player adds (account wide) are the
-- Phrases list of a wheel of their own, mixed with anything else; on the
-- ring, D-pad up / down picks the channel while one is picked.
---------------------------------------------------------------------------
local PHRASE_ICON = "Interface\\GossipFrame\\GossipGossipIcon"
KD.PHRASE_ICON = PHRASE_ICON

-- A phrase as it can be sent: one line, no escape codes ("|" ends a chat
-- line in error), at most 200 letters; nil when nothing is left
function KD.CleanPhrase(text)
    text = tostring(text or ""):gsub("[%c|]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return text:sub(1, 200)
end

-- Where a phrase can go: "auto" (the group, else /say), or a channel of
-- its own, sent with the game's slash command (its first name)
KD.CHANNELS = {
    { key = "auto", label = "Group, else Say" },
    { key = "say", label = "Say", slash = "SLASH_SAY1", fallback = "/s" },
    { key = "party", label = "Party", slash = "SLASH_PARTY1", fallback = "/p" },
    { key = "raid", label = "Raid", slash = "SLASH_RAID1", fallback = "/ra" },
    { key = "guild", label = "Guild", slash = "SLASH_GUILD1", fallback = "/g" },
    { key = "yell", label = "Yell", slash = "SLASH_YELL1", fallback = "/y" },
    { key = "instance", label = "Instance", slash = "SLASH_INSTANCE_CHAT1", fallback = "/i" },
}
local CHANNEL = {}
for i, c in ipairs(KD.CHANNELS) do
    c.index = i
    CHANNEL[c.key] = c
end

-- A phrase's text and its channel ("auto" when it has none)
local function SplitPhrase(action)
    local body = type(action) == "string" and action:match("^phrase:(.+)$")
    if not body then return nil end
    local chan, text = body:match("^(%a+)|(.+)$")
    if chan and CHANNEL[chan] then return text, chan end
    return body, "auto"
end

function KD.PhraseText(action)
    return (SplitPhrase(action))
end

function KD.PhraseChannel(action)
    local _, chan = SplitPhrase(action)
    return chan
end

function KD.ChannelLabel(chan)
    return (CHANNEL[chan] or CHANNEL.auto).label
end

-- The action for a phrase said on chan ("auto": none)
function KD.MakePhrase(text, chan)
    text = KD.CleanPhrase(text)
    if not text then return nil end
    if chan and chan ~= "auto" and CHANNEL[chan] then return "phrase:" .. chan .. "|" .. text end
    return "phrase:" .. text
end

-- The command a phrase goes out with now ("/p"), from the game's own
-- slash commands (their first name)
local INSTANCE = LE_PARTY_CATEGORY_INSTANCE or 2
function KD.PhraseCommand()
    local inGroup = IsInGroup
    if inGroup and inGroup(INSTANCE) and _G.SLASH_INSTANCE_CHAT1 then return _G.SLASH_INSTANCE_CHAT1 end
    if IsInRaid and IsInRaid() then return _G.SLASH_RAID1 or "/ra" end
    if inGroup and inGroup() then return _G.SLASH_PARTY1 or "/p" end
    return _G.SLASH_SAY1 or "/s"
end

-- The channels the ring's D-pad up / down goes through on a page of
-- phrases: first each phrase's own ("Auto (Party)": the group's, else
-- /say, unless it has one), then one for all of them, with its command
function KD.RingChannels()
    local auto = KD.PhraseCommand()
    local where = "Say"
    for _, c in ipairs(KD.CHANNELS) do
        if c.slash and (_G[c.slash] or c.fallback) == auto then where = c.label end
    end
    local list = { { label = "Auto (" .. where .. ")" } }
    for _, c in ipairs(KD.CHANNELS) do
        if c.key ~= "auto" then list[#list + 1] = { label = c.label, command = _G[c.slash] or c.fallback } end
    end
    return list
end

-- Where it goes, for the editor: "your party"...
function KD.PhraseWhere()
    local inGroup = IsInGroup
    if inGroup and inGroup(INSTANCE) and _G.SLASH_INSTANCE_CHAT1 then return "your instance group" end
    if IsInRaid and IsInRaid() then return "your raid" end
    if inGroup and inGroup() then return "your party" end
    return "/say"
end

-- The command a phrase on chan goes out with now
function KD.ChannelCommand(chan)
    local c = CHANNEL[chan]
    if not c or chan == "auto" then return KD.PhraseCommand() end
    return _G[c.slash] or c.fallback
end

-- A phrase as a ring entry: its secure macro
function KD.PhraseEntry(action)
    local text, chan = SplitPhrase(action)
    text = KD.CleanPhrase(text)
    if not text then return nil end
    return { label = text, icon = PHRASE_ICON, type = "macro", value = KD.ChannelCommand(chan) .. " " .. text,
        action = KD.MakePhrase(text, chan), phrase = text }
end

-- The phrases the player added (account wide), newest first
local MAX_SAVED = 40
function KD.SavedPhrases()
    IF.db.phrases = IF.db.phrases or {}
    return IF.db.phrases
end

function KD.SavePhrase(action)
    if not KD.PhraseText(action) then return end
    local saved = KD.SavedPhrases()
    for i = #saved, 1, -1 do
        if saved[i] == action then table.remove(saved, i) end
    end
    table.insert(saved, 1, action)
    while #saved > MAX_SAVED do table.remove(saved) end
end

-- What a phrase's card says under it: where it goes
local function PhraseSub(chan)
    return chan == "auto" and "Said to the group, else /say" or ("Said in " .. KD.ChannelLabel(chan))
end

-- The picker's list of them: "Add a phrase" (the editor's box: typed, and
-- its channel), then the player's own
KD.PHRASES = { key = "phrases", label = "Phrases", entries = function()
    local entries = { { add = true, name = "+ Add a phrase", icon = PHRASE_ICON,
        sub = "Type one (a keyboard), and pick its channel" } }
    local seen = {}
    for _, action in ipairs(KD.SavedPhrases()) do
        local text, chan = SplitPhrase(action)
        if text and not seen[action] then
            seen[action] = true
            entries[#entries + 1] = { action = action, name = text, icon = PHRASE_ICON, sub = PhraseSub(chan) }
        end
    end
    return entries
end }

-- Custom wheels and phrase wheels: their ring entries change with the group
local lastCommand
local function CommandChanged()
    local now = KD.PhraseCommand()
    if now == lastCommand then return false end
    lastCommand = now
    return true
end

---------------------------------------------------------------------------
-- Custom: the slots the player fills (MyWheels.lua's own wheels before
-- kinds)
---------------------------------------------------------------------------
Add({
    key = "custom", order = 1, label = "Your own", slots = true, max = 8, typed = true,
    events = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }, changed = CommandChanged,
    lists = function()
        local lists = {}
        for i, list in ipairs(IF.Actions.CATALOG) do lists[i] = list end
        lists[#lists + 1] = KD.PHRASES
        return lists
    end,
    info = "A wheel of your own: spells, items, macros, emotes or chat phrases in any slot.",
    about = "An empty wheel: pick a spell, an item, a macro, an emote or a chat phrase for each slot.",
})

-- (phrases go on a wheel of the player's own now, from its Phrases list; a
-- wheel of this kind made before still works, none is made anymore)
Add({
    key = "phrases", order = 3, label = "Chat phrases", name = "Chat", slots = true, max = 16, typed = true,
    hidden = true,
    events = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }, changed = CommandChanged,
    lists = function() return { KD.PHRASES } end,
    info = "Phrases said with a flick of the stick: to your instance group, raid or party, else /say."
        .. " Add your own (Square, or + Add a phrase; a keyboard). Two pages of eight.",
    about = "A wheel of chat phrases you add, said to your group, else /say.",
})

---------------------------------------------------------------------------
-- Quest items: the ones in the bags with a use for a quest (a quest item,
-- one the game marks for a quest, or one the game data ties to a quest in
-- the log); then the ones that start a quest. Used as any item (a secure
-- "item" slot), in combat too.
---------------------------------------------------------------------------
local function InLog(questID)
    local log = C_QuestLog
    if log and log.GetLogIndexForQuestID then return (log.GetLogIndexForQuestID(questID) or 0) > 0 end
    return log and log.IsOnQuest and log.IsOnQuest(questID) or false
end

local function Done(questID)
    local log = C_QuestLog
    return log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(questID) or false
end

-- The game data's quests for an item (QuestieDB, else the core's copy),
-- asked once an item: startQuest, { questID } (false: none)
local itemQuests = {}
local function GameDataQuests(itemID)
    local cached = itemQuests[itemID]
    if cached == nil then
        local GD = IF.GameData
        local starts, related
        if GD and GD.ItemQuests then
            local ok, a, b = pcall(GD.ItemQuests, itemID)
            if ok then starts, related = a, b end
        end
        cached = { starts = starts, related = related }
        itemQuests[itemID] = cached
    end
    return cached.starts, cached.related
end

-- "use" (a use for a quest), "starts" (starts one not done), or nil
local function QuestUse(itemID, bag, slot, classID)
    local info = C_Container and C_Container.GetContainerItemQuestInfo
        and C_Container.GetContainerItemQuestInfo(bag, slot)
    local spell = ItemSpell(itemID)
    if spell then
        if classID == 12 or (info and (info.isQuestItem or info.questID)) then return "use" end
        local _, related = GameDataQuests(itemID)
        for _, questID in ipairs(related or {}) do
            if InLog(questID) then return "use" end
        end
    end
    -- (a quest's first item: opened with a use, as from the bags)
    if info and info.questID and not info.isActive and not Done(info.questID) then return "starts" end
    if classID == 12 and not (info and info.questID) then
        local starts = GameDataQuests(itemID)
        local GD = IF.GameData
        if starts and not InLog(starts) and not Done(starts) and (not (GD and GD.QuestOpen) or GD.QuestOpen(starts)) then
            return "starts"
        end
    end
end

local function BuildQuestItems(wheel)
    local use, starts = {}, { label = "Starts a quest" }
    EachBagItem(function(itemID, bag, slot)
        local icon, classID = ItemInstant(itemID)
        local how = QuestUse(itemID, bag, slot, classID)
        if how then
            local list = how == "use" and use or starts
            list[#list + 1] = { label = ItemName(itemID), icon = icon, count = ItemCount(itemID),
                type = "item", value = "item:" .. itemID, action = "item:" .. itemID }
        end
    end)
    table.sort(use, ByLabel)
    table.sort(starts, ByLabel)
    local entries = Paged({ use, starts }, wheel.max or IF.MAX_SLOTS)
    entries.empty = "No quest items in your bags"
    return entries
end

-- (built in: the Quest Items wheel, in place of Buffs; a wheel of this
-- kind made before still works, none is made anymore)
Add({
    key = "quest", order = 2, label = "Quest items", name = "Quest Items", max = 24, builtIn = true,
    events = { "QUEST_LOG_UPDATE" },
    info = "Fills itself from your bags: the items with a use for a quest, then the ones that start a quest."
        .. " An item leaves once its quest is done. Nothing to set here but its hotkey.",
    about = "Fills itself from your bags with the items a quest has you use, and the ones that start a"
        .. " quest. Usable in combat; updates after a fight.",
    build = BuildQuestItems,
})
IF.RingBuilders.quest = function() return BuildQuestItems({ max = IF.MAX_SLOTS }) end

---------------------------------------------------------------------------
-- Totems (shamans): the totem spells in the spellbook, a page an element
-- (Earth, Fire, Water, Air), cast as any spell (its highest rank). Every
-- rank's spell ID, from Forever's own tables (1.60.1: SpellTotems' Earth /
-- Fire / Water / Air Totem, the shaman's SkillLineAbility; no Fire Nova
-- Totem there), in the order they're learned.
---------------------------------------------------------------------------
local TOTEMS = {
    { label = "Earth", spells = {
        { 8071, 8154, 8155, 10406, 10407, 10408 },              -- Stoneskin Totem
        { 2484 },                                               -- Earthbind Totem
        { 5730, 6390, 6391, 6392, 10427, 10428 },               -- Stoneclaw Totem
        { 8075, 8160, 8161, 10442, 25361 },                     -- Strength of Earth Totem
        { 8143 },                                               -- Tremor Totem
        { 425874 },                                             -- Decoy Totem
    } },
    { label = "Fire", spells = {
        { 3599, 6363, 6364, 6365, 10437, 10438 },               -- Searing Totem
        { 8181, 10478, 10479 },                                 -- Frost Resistance Totem
        { 8190, 10585, 10586, 10587 },                          -- Magma Totem
        { 8227, 8249, 10526, 16387 },                           -- Flametongue Totem
    } },
    { label = "Water", spells = {
        { 5394, 6375, 6377, 10462, 10463 },                     -- Healing Stream Totem
        { 5675, 10495, 10496, 10497 },                          -- Mana Spring Totem
        { 8166 },                                               -- Poison Cleansing Totem
        { 8184, 10537, 10538 },                                 -- Fire Resistance Totem
        { 8170 },                                               -- Disease Cleansing Totem
        { 16190, 17354, 17359 },                                -- Mana Tide Totem
    } },
    { label = "Air", spells = {
        { 8177 },                                               -- Grounding Totem
        { 6495 },                                               -- Sentry Totem
        { 8512, 10613, 10614 },                                 -- Windfury Totem
        { 10595, 10600, 10601 },                                -- Nature Resistance Totem
        { 15107, 15111, 15112 },                                -- Windwall Totem
        { 8835, 10627, 25359 },                                 -- Grace of Air Totem
    } },
}
-- spell ID -> element (its index), the totem's place in it
local TOTEM_OF = {}
for element, info in ipairs(TOTEMS) do
    for place, ranks in ipairs(info.spells) do
        for _, spellID in ipairs(ranks) do TOTEM_OF[spellID] = { element = element, place = place } end
    end
end

local function BuildTotems(wheel)
    local groups = {}
    for element, info in ipairs(TOTEMS) do groups[element] = { label = info.label } end
    local seen = {}
    for _, spell in ipairs(IF.GetSpellbookSpells and IF.GetSpellbookSpells() or {}) do
        local totem = spell.spellID and TOTEM_OF[spell.spellID]
        if totem and not seen[spell.name] then
            seen[spell.name] = true
            -- (its highest rank known, as a cast by name gives)
            local _, _, best = IF.SpellInfo(spell.name)
            local spellID = best or spell.spellID
            local group = groups[totem.element]
            group[#group + 1] = { label = spell.name, icon = spell.icon, type = "spell", value = spell.name,
                spellID = spellID, action = "spell:" .. spellID, place = totem.place }
        end
    end
    for _, group in ipairs(groups) do
        table.sort(group, function(a, b) return a.place < b.place end)
    end
    local entries = Paged(groups, wheel.max or 32)
    entries.empty = "No totems learned yet"
    return entries
end

Add({
    key = "totems", order = 4, label = "Totems", name = "Totems", max = 32,
    available = function()
        local _, class = UnitClass("player")
        return class == "SHAMAN"
    end,
    info = "Fills itself from your spellbook: your totems, a page an element (Earth, Fire, Water, Air),"
        .. " each at its highest rank. Turn the pages with the D-pad left / right.",
    about = "Your totems from the spellbook, a page an element: Earth, Fire, Water, Air. New ones join"
        .. " as you learn them.",
    build = BuildTotems,
})

---------------------------------------------------------------------------
-- Gear: the items in the bags that fit an equipment slot (trinket 1 / 2;
-- the other trinket slot's too, to swap them over), their cooldowns on the
-- wheel. A pick equips it there: not a secure action, so the slot's own
-- secure macro does nothing ("") and the pick is seen afterwards (Ring.lua:
-- entry.equip, KD.Equip). In combat the game won't change trinkets: the
-- pick waits for the fight's end (shown on the wheel), as ItemRack does.
---------------------------------------------------------------------------
local GEAR = {
    [13] = { label = "Trinket 1", other = 14, fits = { INVTYPE_TRINKET = true } },
    [14] = { label = "Trinket 2", other = 13, fits = { INVTYPE_TRINKET = true } },
}
KD.GEAR = GEAR

-- [inventory slot] = itemID: picked in combat, equipped once it ends
local pending = {}

function KD.IsPending(equip)
    return equip ~= nil and pending[equip.slot] == equip.item
end

local function InFight()
    return IF.InCombat() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

local function ContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then return C_Container.GetContainerItemLink(bag, slot) end
    return GetContainerItemLink and GetContainerItemLink(bag, slot)
end

local function FindInBags(itemID)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            if ContainerItemID(bag, slot) == itemID then return bag, slot end
        end
    end
end

-- Puts it on now (out of combat): picked up from the bags (or the other
-- slot) and put down on the slot, as dragging it would; whatever the slot
-- won't take goes back
local function PutOn(itemID, invSlot)
    if GetInventoryItemID("player", invSlot) == itemID then return end
    if CursorHasItem and CursorHasItem() then
        IF.Print(GEAR[invSlot].label .. ": let go of the item you hold first.")
        return
    end
    local pickBag = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    local bag, slot = FindInBags(itemID)
    local other = GEAR[invSlot].other
    if bag and pickBag and PickupInventoryItem then
        pickBag(bag, slot)
        PickupInventoryItem(invSlot)
    elseif other and GetInventoryItemID("player", other) == itemID and PickupInventoryItem then
        PickupInventoryItem(other)
        PickupInventoryItem(invSlot)
    else
        local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
        if equip then equip(itemID, invSlot) end
    end
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
end

-- A gear slot picked on a wheel ({ item, slot }): on now, else after the fight
function KD.Equip(equip)
    if not (equip and equip.item and GEAR[equip.slot]) then return end
    local gear = GEAR[equip.slot]
    if GetInventoryItemID("player", equip.slot) == equip.item then
        -- (picked what it wears: nothing waits any more)
        pending[equip.slot] = nil
        return
    end
    if InFight() then
        pending[equip.slot] = equip.item
        IF.Print(gear.label .. ": " .. ItemName(equip.item) .. " goes on once the fight is over.")
        return
    end
    pending[equip.slot] = nil
    PutOn(equip.item, equip.slot)
end

-- The fight over: the picks that waited (a moment apart, each swap done)
local queue = CreateFrame("Frame")
queue:RegisterEvent("PLAYER_REGEN_ENABLED")
queue:SetScript("OnEvent", function()
    local delay = 0
    for invSlot, itemID in pairs(pending) do
        C_Timer.After(delay, function()
            if pending[invSlot] ~= itemID or InFight() then return end
            pending[invSlot] = nil
            PutOn(itemID, invSlot)
        end)
        delay = delay + 0.3
    end
end)

local function BuildGear(invSlot, wheel)
    local gear = GEAR[invSlot]
    local list = {}
    local wearing = GetInventoryItemID("player", invSlot)
    local function add(itemID, link, where)
        local icon = select(1, ItemInstant(itemID))
        list[#list + 1] = { label = ItemName(itemID), icon = icon, type = "macro", value = "",
            action = "item:" .. itemID, tip = link or ("item:" .. itemID), cooldownItem = itemID,
            equip = { item = itemID, slot = invSlot }, where = where }
    end
    EachBagItem(function(itemID, bag, slot)
        local _, _, _, equipLoc = ItemInstant(itemID)
        if equipLoc and gear.fits[equipLoc] and itemID ~= wearing then add(itemID, ContainerItemLink(bag, slot)) end
    end)
    local otherID = gear.other and GetInventoryItemID("player", gear.other)
    if otherID and otherID ~= wearing then
        add(otherID, GetInventoryItemLink and GetInventoryItemLink("player", gear.other), GEAR[gear.other].label)
    end
    table.sort(list, ByLabel)
    local entries = Paged({ list }, wheel.max or 24)
    entries.empty = "No other trinkets in your bags"
    return entries
end

for invSlot, order in pairs({ [13] = 5, [14] = 6 }) do
    local gear = GEAR[invSlot]
    Add({
        key = "trinket" .. (invSlot - 12), order = order, label = gear.label, name = gear.label, max = 24,
        events = { "PLAYER_EQUIPMENT_CHANGED" },
        info = "Fills itself from your bags: the trinkets you can put on as " .. gear.label .. ", and the one"
            .. " in the other slot to swap them. A pick puts it on; in combat it goes on once the fight is over.",
        about = "Swaps your " .. gear.label .. ": the trinkets in your bags, their cooldowns shown. Picked in"
            .. " combat, one goes on once the fight is over.",
        build = function(wheel) return BuildGear(invSlot, wheel) end,
    })
end

---------------------------------------------------------------------------
-- Changes a kind waits for (beyond the bags and the spellbook, which
-- Ring.lua already watches): the rings rebuilt when a wheel of that kind
-- exists (in combat, after it)
---------------------------------------------------------------------------
local watch = CreateFrame("Frame")
local watching = {}
for _, kind in ipairs(KD.ORDER) do
    for _, event in ipairs(kind.events or {}) do
        watching[event] = watching[event] or {}
        watching[event][kind.key] = true
        watch:RegisterEvent(event)
    end
end
watch:SetScript("OnEvent", function(_, event)
    local MW = IF.MyWheels
    if not (IF.db and IF.charDB and MW) then return end
    for key in pairs(watching[event] or {}) do
        local kind = KD.BY_KEY[key]
        if (kind.builtIn or MW.HasKind(key)) and (not kind.changed or kind.changed(event)) then
            IF.RefreshRings()
            return
        end
    end
end)
