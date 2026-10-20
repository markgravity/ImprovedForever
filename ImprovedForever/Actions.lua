-- Actions a press, a touchpad corner or a wheel's slot can hold: a game
-- action ("spell:<id>", "item:<id>", "macro:<name>", "emote:<token>") or an
-- interface window ("map", "bags"...: the game's own button for it, clicked).
local _, IF = ...

local AC = {}
IF.Actions = AC

-- Emotes a slot can take (the slash command is "/" .. token)
-- { token, name }: each with its own icon in the radial menu's style
-- (textures/ic_emote_<token>, tools/make_emote_icons.py)
IF.EMOTES = {
    { "wave", "Wave" }, { "hello", "Hello" }, { "thank", "Thank" },
    { "cheer", "Cheer" }, { "dance", "Dance" }, { "laugh", "Laugh" },
    { "bow", "Bow" }, { "roar", "Roar" }, { "bye", "Bye" },
    { "clap", "Clap" }, { "cry", "Cry" }, { "flex", "Flex" },
    { "kiss", "Kiss" }, { "kneel", "Kneel" }, { "lol", "Lol" },
    { "no", "No" }, { "yes", "Yes" }, { "point", "Point" },
    { "rude", "Rude" }, { "salute", "Salute" }, { "sit", "Sit" },
    { "sleep", "Sleep" }, { "shy", "Shy" }, { "train", "Train" },
    { "chicken", "Chicken" }, { "thanks", "Thanks" }, { "followme", "Follow me" },
    { "charge", "Charge" }, { "attacktarget", "Attack target" },
    { "healme", "Heal me" }, { "oom", "Out of mana" }, { "flee", "Flee" },
}
local EMOTE_NAME, EMOTE_ICONS = {}, {}
for _, emote in ipairs(IF.EMOTES) do
    EMOTE_NAME[emote[1]] = emote[2]
    emote[3] = IF.TEX .. "ic_emote_" .. emote[1]
    EMOTE_ICONS[emote[1]] = emote[3]
end
IF.EMOTE_ICON = "Interface\\GossipFrame\\GossipGossipIcon"
function IF.SpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then return info.name, info.iconID, info.spellID end
        return nil
    end
    if GetSpellInfo then
        local name, _, icon, _, _, _, spellID = GetSpellInfo(spell)
        return name, icon, spellID
    end
end

function IF.ItemNameByID(id)
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    return getName and getName(id)
end

function IF.ItemIconByID(id)
    local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return getIcon and getIcon(id)
end

-- An action's name and icon (nil for one that no longer exists)
local function Parse(action)
    return (action or ""):match("^(%a+):(.+)$")
end

function IF.ActionInfo(action)
    local kind, value = Parse(action)
    if kind == "spell" then
        local name, icon = IF.SpellInfo(tonumber(value))
        return name, icon
    elseif kind == "item" then
        local id = tonumber(value)
        return IF.ItemNameByID(id) or ("item:" .. value), IF.ItemIconByID(id)
    elseif kind == "macro" then
        local name, icon = GetMacroInfo(value)
        return name, icon
    elseif kind == "emote" then
        return EMOTE_NAME[value] or value, EMOTE_ICONS[value] or IF.EMOTE_ICON
    end
end

-- The game's windows an action can open: the game's own button for it (the
-- first that exists in this client; only windows with one are offered).
-- Named and drawn as Forever's own radial menu shows them (its
-- gamepad-radial-icon-* art, the first this client has), else an icon.
local R = "gamepad-radial-icon-"
local WINDOWS = {
    -- (the radial's first page)
    { key = "character", label = "Character", radial = { R .. "character" },
        icon = "Interface\\Icons\\INV_Chest_Cloth_17", buttons = { "CharacterMicroButton" } },
    { key = "professions", label = "Professions", radial = { R .. "professions" },
        icon = "Interface\\Icons\\Trade_BlackSmithing", buttons = { "ProfessionMicroButton" } },
    { key = "bags", label = "Bags", radial = { R .. "bags" },
        icon = "Interface\\Icons\\INV_Misc_Bag_08", buttons = { "MainMenuBarBackpackButton", "BagsBarBackpackButton" } },
    { key = "spellbook", label = "Spellbook", radial = { R .. "spellbook" },
        icon = "Interface\\Icons\\INV_Misc_Book_09", buttons = { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
    { key = "gamemenu", label = "Game Menu", radial = { R .. "gamemenu" },
        icon = "Interface\\Icons\\INV_Misc_Gear_01", buttons = { "MainMenuMicroButton" } },
    { key = "questlog", label = "Quest & Maps", radial = { R .. "quests" },
        icon = "Interface\\Icons\\INV_Misc_Book_08", buttons = { "QuestLogMicroButton" } },
    { key = "talents", label = "Talents", radial = { R .. "talents" },
        icon = "Interface\\Icons\\Ability_Marksmanship", buttons = { "TalentMicroButton", "PlayerSpellsMicroButton" } },
    -- (its second)
    { key = "shop", label = "Shop", radial = { R .. "shop", R .. "store" },
        icon = "Interface\\Icons\\WoW_Store", buttons = { "StoreMicroButton" } },
    { key = "legacy", label = "Legacy", radial = { R .. "legacy" },
        icon = "Interface\\Icons\\Achievement_General", buttons = { "LegacyMicroButton", "LegacySystemMicroButton" } },
    { key = "groupfinder", label = "Group Finder", radial = { R .. "groupfinder", R .. "lfg", R .. "dungeonfinder" },
        icon = "Interface\\Icons\\INV_Misc_Eye_01", buttons = { "LFGMicroButton", "LFDMicroButton", "GroupFinderMicroButton" } },
    { key = "collections", label = "Collections", radial = { R .. "collections" },
        icon = "Interface\\Icons\\Ability_Mount_RidingHorse", buttons = { "CollectionsMicroButton" } },
    { key = "minimap", label = "Minimap Settings", radial = { R .. "minimap", R .. "minimapsettings", R .. "tracking" },
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        buttons = { "MiniMapTrackingButton", "MiniMapTracking", "MinimapTrackingButton" } },
    { key = "buffs", label = "View Buffs", radial = { R .. "buffs", R .. "viewbuffs", R .. "auras" },
        icon = "Interface\\Icons\\Spell_Holy_WordFortitude", buttons = { "BuffFrameCollapseAndExpandButton" } },
    { key = "social", label = "Social", radial = { R .. "social", R .. "friends" },
        icon = "Interface\\Icons\\INV_Misc_GroupLooking", buttons = { "SocialsMicroButton", "FriendsMicroButton", "QuickJoinToastButton" } },
    { key = "guild", label = "Communities", radial = { R .. "communities", R .. "guild" },
        icon = "Interface\\Icons\\INV_BannerPVP_02", buttons = { "CommunitiesMicroButton", "GuildMicroButton" } },
    -- (its third)
    { key = "calendar", label = "Calendar", radial = { R .. "calendar" },
        icon = "Interface\\Icons\\INV_Misc_Note_02", buttons = { "GameTimeFrame", "CalendarMicroButton" } },
    { key = "clock", label = "Clock", radial = { R .. "clock", R .. "stopwatch" },
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", buttons = { "TimeManagerClockButton" } },
    { key = "pvp", label = "PvP", radial = { R .. "pvp" },
        icon = "Interface\\Icons\\Ability_DualWield", buttons = { "PVPMicroButton", "HonorMicroButton" } },
    -- (ours; macroIcon: the game's icon nearest ours, for a crossbar slot's
    -- macro, which can't show a texture of an addon: Native.lua)
    { key = "nodes", label = "Minimap labels", ours = true, desc = "Shows / hides names beside the minimap's dots", icon = IF.TEX .. "ic_fn_labels",
        macroIcon = "Interface\\Icons\\INV_Misc_Flower_02", buttons = { "ImprovedForeverNodeScan" } },
    -- (the map's own button: opened with the pad's press, closed with its
    -- release, shown as the peek map, PeekMap.lua; the touchpad's map
    -- corner opens it the same way)
    { key = "peekmap", label = "Peek map", ours = true, desc = "Opens the map, see-through", icon = IF.TEX .. "ic_fn_peekmap",
        macroIcon = "Interface\\Icons\\INV_Misc_Map_01", buttons = { "WorldMapMicroButton", "MiniMapWorldMapButton", "QuestLogMicroButton" } },
    { key = "journal", label = "Journal", ours = true, desc = "Opens the Journal", icon = IF.TEX .. "ic_mod_journal",
        macroIcon = "Interface\\Icons\\INV_Misc_Book_09", buttons = { "ImprovedForeverJournalToggle" } },
    { key = "icmenu", label = "Improved Forever panel", ours = true, desc = "Opens this settings panel", icon = IF.TEX .. "ic_addon",
        macroIcon = "Interface\\Icons\\INV_Misc_Gear_01", buttons = { "ImprovedForeverMenuToggle" } },
    -- (other modules' windows: each there with its module)
    { key = "wiki", label = "Wiki", ours = true, desc = "Opens the Wiki on its search", icon = IF.TEX .. "ic_mod_wiki",
        macroIcon = "Interface\\Icons\\INV_Misc_Book_09", buttons = { "ImprovedForeverWikiToggle" } },
    { key = "fishcollection", label = "Fish Collection", ours = true, desc = "Opens the Fish Collection",
        icon = IF.TEX .. "ic_mod_fishing", macroIcon = "Interface\\Icons\\Trade_Fishing",
        buttons = { "ImprovedForeverFishCollectionToggle" } },
    { key = "destroy", label = "Destroy", ours = true, desc = "Opens the Destroy panel", icon = IF.TEX .. "ic_mod_destroy",
        macroIcon = "Interface\\Icons\\INV_Misc_Bag_08", buttons = { "ImprovedForeverDestroyToggle" } },
    -- (its press runs /reload itself: a /click to a button of ours is
    -- lost on key-down presses, the button answering only its release)
    { key = "reload", label = "Reload", ours = true, desc = "Reloads the interface (/reload)", macro = "/reload",
        icon = IF.TEX .. "ic_fn_reload", macroIcon = "Interface\\Icons\\Spell_Nature_Reincarnation", buttons = { "ImprovedForeverReload" } },
    -- (no longer offered; kept for what holds it already)
    { key = "map", label = "World Map", hidden = true, icon = "Interface\\Icons\\INV_Misc_Map_01",
        buttons = { "WorldMapMicroButton", "MiniMapWorldMapButton", "QuestLogMicroButton" } },
    { key = "achievements", label = "Achievements", hidden = true, icon = "Interface\\Icons\\INV_Misc_Note_01",
        buttons = { "AchievementMicroButton" } },
}

-- A window's art: the radial menu's, else its icon
local function WindowIcon(action)
    for _, atlas in ipairs(action.radial or {}) do
        if IF.HasAtlas(atlas) then return atlas end
    end
    return action.icon
end

-- The Reload action's button: a press (or a corner) clicks it
-- A button a window of ours opens from (a key binding, a /click of a
-- press, a wheel or a corner): fn once a press. Registered for both edges,
-- a /click sending one of them; a key binding's sends both: acted on the
-- press, its release let go.
function AC.PressButton(name, fn)
    local b = CreateFrame("Button", name, UIParent)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(self, _, down)
        if down then
            self.pressed = true
        elseif self.pressed then
            self.pressed = false
            return
        end
        fn()
    end)
    return b
end

AC.PressButton("ImprovedForeverReload", function() ReloadUI() end)

local ACTION_BY_KEY = {}
for _, action in ipairs(WINDOWS) do
    ACTION_BY_KEY[action.key] = action
end

-- Holds something (not "none")
function AC.IsBound(key)
    return key ~= nil and key ~= "none"
end

local function ActionButton(key)
    local action = ACTION_BY_KEY[key]
    for _, name in ipairs(action and action.buttons or {}) do
        local button = _G[name]
        if type(button) == "table" and button.Click then
            return name
        end
    end
end

-- "none" first, then every action this client has a button for.
function AC.Windows()
    local list = { "none" }
    for _, action in ipairs(WINDOWS) do
        if not action.hidden and ActionButton(action.key) then
            list[#list + 1] = action.key
        end
    end
    return list
end

-- An action: an interface window ("map"...), or "spell:<id>",
-- "item:<id>", "macro:<name>" (IF.ActionInfo), or "none"
local function IsGameAction(key)
    return type(key) == "string" and key:find(":", 1, true) ~= nil
end

function AC.Icon(key)
    if IsGameAction(key) then
        return select(2, IF.ActionInfo(key))
    end
    local action = ACTION_BY_KEY[key]
    return action and WindowIcon(action)
end

-- What the secure click runs for a region's action, or nil
function AC.Macro(key)
    if IsGameAction(key) then
        local kind, value = key:match("^(%a+):(.+)$")
        if kind == "spell" then
            local name = IF.ActionInfo(key)
            return name and ("/cast " .. name)
        elseif kind == "item" then
            return "/use item:" .. value
        elseif kind == "macro" then
            local _, _, body = GetMacroInfo(value)
            return body
        end
        return nil
    end
    local action = ACTION_BY_KEY[key]
    if action and action.macro then return action.macro end
    local name = ActionButton(key)
    return name and ("/click " .. name)
end

-- The windows a press or a corner can open, for the picker: the game's
-- (ours = false), or our own (ours = true: the minimap labels, the peek map,
-- this panel)
function AC.InterfaceEntries(ours)
    local entries = {}
    for _, key in ipairs(AC.Windows()) do
        if key ~= "none" and (ACTION_BY_KEY[key].ours or false) == (ours or false) then
            entries[#entries + 1] = { action = key, name = AC.Label(key), icon = AC.Icon(key), sub = ACTION_BY_KEY[key].desc }
        end
    end
    return entries
end

-- One of ours (its own list in the picker)
function AC.IsOurs(key)
    local action = ACTION_BY_KEY[key]
    return action ~= nil and action.ours == true
end

-- The icon for a macro of an action: its game icon where its own is an
-- addon's texture (macroIcon), else its own
function AC.MacroIcon(key)
    local action = ACTION_BY_KEY[key]
    if action then return action.macroIcon or action.icon end
    return AC.Icon(key)
end

function AC.Label(key)
    if IsGameAction(key) then
        return IF.ActionInfo(key) or key
    end
    local action = ACTION_BY_KEY[key]
    if not action then
        return "Nothing"
    end
    return ActionButton(key) and action.label or (action.label .. " (not in this client)")
end


-- Every active spell in the spellbook, once per name, in book order:
--   { name, icon, tab, spellID }
function IF.GetSpellbookSpells()
    local spells, seen = {}, {}
    local function add(name, icon, tab, spellID)
        if name and not seen[name] then
            seen[name] = true
            spells[#spells + 1] = { name = name, icon = icon, tab = tab, spellID = spellID }
        end
    end
    if GetNumSpellTabs and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() or 0 do
            local tabName, _, offset, numSlots = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
                local itemType, spellID = GetSpellBookItemInfo(index, "spell")
                if itemType == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(index, "spell")) then
                    add(GetSpellBookItemName(index, "spell"), GetSpellBookItemTexture(index, "spell"), tabName, spellID)
                end
            end
        end
    elseif C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.offSpecID then
                for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                    if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive then
                        add(item.name, item.iconID, info.name, item.spellID)
                    end
                end
            end
        end
    end
    return spells
end

local function ItemName(id)
    return (IF.ActionInfo("item:" .. id))
end

local function ItemIcon(id)
    return select(2, IF.ActionInfo("item:" .. id))
end

---------------------------------------------------------------------------
-- What a slot can take (the picker's lists): spells by spellbook tab,
-- usable items in the bags and equipped, macros, emotes
---------------------------------------------------------------------------
local function SpellEntries()
    local entries, lastTab = {}, nil
    for _, spell in ipairs(IF.GetSpellbookSpells()) do
        if spell.spellID then
            if spell.tab ~= lastTab then
                entries[#entries + 1] = { header = spell.tab or "Spells" }
                lastTab = spell.tab
            end
            entries[#entries + 1] = { action = "spell:" .. spell.spellID, name = spell.name, icon = spell.icon }
        end
    end
    return entries
end

local function ItemSpell(id)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    return getSpell and getSpell(id)
end

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function ContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(bag, slot) end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

local function ItemEntries()
    local entries, seen = {}, {}
    local function add(id)
        if id and not seen[id] and ItemSpell(id) then
            seen[id] = true
            entries[#entries + 1] = { action = "item:" .. id, name = ItemName(id) or ("item:" .. id), icon = ItemIcon(id) }
        end
    end
    entries[#entries + 1] = { header = "Equipped" }
    for slot = 1, 19 do
        add(GetInventoryItemID("player", slot))
    end
    if #entries == 1 then entries[1] = nil end
    local before = #entries
    entries[#entries + 1] = { header = "Bags" }
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            add(ContainerItemID(bag, slot))
        end
    end
    if #entries == before + 1 then entries[#entries] = nil end
    return entries
end

local function MacroEntries()
    local entries = {}
    local global, perChar = GetNumMacros()
    local groups = {
        { "General macros", 1, global },
        { "Character macros", (MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + perChar },
    }
    for _, group in ipairs(groups) do
        if group[3] >= group[2] then
            entries[#entries + 1] = { header = group[1] }
            for index = group[2], group[3] do
                local name, icon = GetMacroInfo(index)
                if name then
                    entries[#entries + 1] = { action = "macro:" .. name, name = name, icon = icon }
                end
            end
        end
    end
    return entries
end

local function EmoteEntries()
    local entries = {}
    for _, emote in ipairs(IF.EMOTES) do
        entries[#entries + 1] = { action = "emote:" .. emote[1], name = emote[2], icon = emote[3] or IF.EMOTE_ICON, sub = "/" .. emote[1] }
    end
    return entries
end

local SPELLS = { key = "spells", label = "Spells", entries = SpellEntries }
local ITEMS = { key = "items", label = "Items", entries = ItemEntries }
local MACROS = { key = "macros", label = "Macros", entries = MacroEntries }
local EMOTES = { key = "emotes", label = "Emotes", entries = EmoteEntries }
AC.CATALOG = { SPELLS, ITEMS, MACROS, EMOTES }

-- /if windows: each window an action can open, the button it would click
-- and the art it shows (the radial menu's, or not found in this client)
IF.AddCommand("windows", function()
    for _, action in ipairs(WINDOWS) do
        local art
        for _, atlas in ipairs(action.radial or {}) do
            if IF.HasAtlas(atlas) then art = atlas break end
        end
        IF.Print(action.label .. ": " .. (ActionButton(action.key) or "|cffff7a5cno button|r")
            .. (action.radial and ("  art: " .. (art or "|cffff7a5cnone|r")) or "")
            .. (action.hidden and "  (not offered)" or ""))
    end
end, ": the windows an action can open, in this client")

