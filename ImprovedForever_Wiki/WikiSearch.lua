-- The Wiki's search: a page of its book (Book.lua: a page with a field)
-- where a name is typed (the pad's letters on the page, or the keyboard),
-- what the Wiki knows by that name listed under it: items (WikiItems.lua,
-- Forever's own item tables), creatures, quests, chests and nodes (the
-- core's WorldData.lua). Cross on one opens its page; Circle back. Triangle
-- on any page of the Wiki opens it (WikiPage.lua), the last search typed in
-- it again.
-- L3 (the mouse: Filters) opens its filters, a dropdown as the auction
-- window's (the core's Dropdown.lua): what kind, an item's rarities, type,
-- its weapon or armor type, slot, and the level; only the choices that
-- find something. A filter alone (nothing typed) lists everything it lets
-- through.
-- Never in combat.
local IF = ImprovedForever

local LB = IF.Wiki
local BK = IF.Book

local MIN_TYPED = 2               -- (a letter alone: half of everything)
local PER_KIND = 60               -- shown of each kind, the best first
local ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local KINDS = {
    { "item", "Items" }, { "npc", "Creatures" }, { "quest", "Quests" }, { "object", "Chests and Nodes" },
}
local KIND_NAMES = {}
for _, k in ipairs(KINDS) do KIND_NAMES[k[1]] = k[2] end

-- Item classes in the order the filters show them (Enum.ItemClass), their
-- names when the client has none
local CLASS_ORDER = { 2, 4, 0, 7, 9, 1, 5, 6, 11, 12, 13, 15 }
local CLASS_NAMES = { [0] = "Consumable", [1] = "Container", [2] = "Weapon", [4] = "Armor", [5] = "Reagent",
    [6] = "Projectile", [7] = "Trade Goods", [9] = "Recipe", [11] = "Quiver", [12] = "Quest", [13] = "Key",
    [15] = "Miscellaneous" }
-- Slots (inventory types; a robe is a chest's), in the paper doll's order,
-- the game's names for them (INVTYPE_*), else these
local SLOTS = {
    { 1, "HEAD", "Head" }, { 2, "NECK", "Neck" }, { 3, "SHOULDER", "Shoulder" }, { 16, "CLOAK", "Back" },
    { 5, "CHEST", "Chest" }, { 4, "BODY", "Shirt" }, { 19, "TABARD", "Tabard" }, { 9, "WRIST", "Wrist" },
    { 10, "HAND", "Hands" }, { 6, "WAIST", "Waist" }, { 7, "LEGS", "Legs" }, { 8, "FEET", "Feet" },
    { 11, "FINGER", "Finger" }, { 12, "TRINKET", "Trinket" }, { 13, "WEAPON", "One-Hand" },
    { 21, "WEAPONMAINHAND", "Main Hand" }, { 22, "WEAPONOFFHAND", "Off Hand" }, { 17, "2HWEAPON", "Two-Hand" },
    { 14, nil, "Shield" }, { 23, "HOLDABLE", "Held In Off-hand" }, { 15, "RANGED", "Ranged" },
    { 25, "THROWN", "Thrown" }, { 28, "RELIC", "Relic" },
    { 24, "AMMO", "Ammo" }, { 18, "BAG", "Bag" },
}
local SLOT_SAME = { [20] = 5, [26] = 15 }      -- (a robe: a chest; a gun: ranged)
-- The level filter's ranges
local LEVELS = { { "mine" }, { 1, 10 }, { 11, 20 }, { 21, 30 }, { 31, 40 }, { 41, 50 }, { 51, 60 } }
-- The filters only an item has (its rarity apart: several ticked)
local ITEM_ONLY = { class = true, sub = true, slot = true }

local function ClassName(class)
    local get = C_Item and C_Item.GetItemClassInfo or GetItemClassInfo
    local name = get and get(class)
    return (name and name ~= "") and name or CLASS_NAMES[class] or ("Type " .. class)
end

local function SubName(class, sub)
    local get = C_Item and C_Item.GetItemSubClassInfo or GetItemSubClassInfo
    local name = get and get(class, sub)
    return (name and name ~= "") and name or nil
end

local slotName = {}
for _, s in ipairs(SLOTS) do slotName[s[1]] = s end
local function SlotName(slot)
    local s = slotName[slot]
    if not s then return "Slot " .. slot end
    local name = s[2] and _G["INVTYPE_" .. s[2]]
    return (type(name) == "string" and name ~= "") and name or s[3]
end

local function LevelName(level)
    if level[1] == "mine" then return "Up to My Level (" .. (UnitLevel("player") or 1) .. ")" end
    return "Level " .. level[1] .. "–" .. level[2]
end

local function QualityName(q)
    return (BK.QUALITY_INK[q] or "") .. (BK.QUALITY_NAMES[q] or ("Quality " .. q)) .. "|r"
end

---------------------------------------------------------------------------
-- What can be found: every name once, in lower case without its
-- punctuation ("Hogger's Claw" -> "hoggers claw"), what the filters ask of
-- it, built the first time
---------------------------------------------------------------------------
local function Plain(s)
    s = s:lower():gsub("’", ""):gsub("'", ""):gsub("%p", " "):gsub("%s+", " ")
    return strtrim(s)
end

local index                       -- { { kind, id, name, plain, lo, hi (its levels), item's quality, class, sub, slot } }
local function Index()
    if index then return index end
    index = {}
    local data = IF.WorldData or {}
    -- (one a name and where it is, the lowest id kept; an item: one a name
    -- and kind, the one the Wiki knows something of first)
    local seen = {}
    local function add(e, where, known)
        if not e.name or e.name == "" then return end
        e.plain = Plain(e.name)
        local key = e.kind .. "|" .. e.plain .. "|" .. (where or "")
        local old = seen[key]
        if old then
            if (known and not old.known) or (known == old.known and e.id < old.id) then
                old.id, old.name, old.known = e.id, e.name, known
            end
            return
        end
        e.known = known
        seen[key] = e
        index[#index + 1] = e
    end
    local items = data.items or {}
    for id, row in pairs(IF.WikiItems and IF.WikiItems.items or {}) do
        local name, q, ilvl, req, class, sub, slot = row:match("^([^|]*)|(%d*)|(%d*)|(%d*)|(%d*)|(%d*)|(%d*)")
        if name then
            q, ilvl, req, class, sub, slot = tonumber(q) or 1, tonumber(ilvl) or 0, tonumber(req) or 0,
                tonumber(class) or 15, tonumber(sub) or 0, tonumber(slot) or 0
            slot = SLOT_SAME[slot] or slot
            -- (its level: the one it asks, else its own)
            local level = req > 0 and req or ilvl > 0 and ilvl or nil
            add({ kind = "item", id = id, name = name, quality = q, req = req, class = class, sub = sub,
                slot = slot > 0 and slot or nil, lo = level, hi = level },
                table.concat({ q, class, sub, slot }, ","), items[id] ~= nil)
        end
    end
    for id, row in pairs(data.npcs or {}) do
        local name, lo, hi, zone = row:match("^([^|]*)|([^|]*)|([^|]*)|[^|]*|([^|]*)")
        lo = tonumber(lo)
        add({ kind = "npc", id = id, name = name, lo = lo, hi = tonumber(hi) or lo }, zone, false)
    end
    for id, row in pairs(data.objects or {}) do
        local name, zone = row:match("^([^|]*)|([^|]*)")
        add({ kind = "object", id = id, name = name }, zone, false)
    end
    for id, row in pairs(data.quests or {}) do
        local name, level, zone = row:match("^([^|]*)|([^|]*)|([^|]*)")
        level = tonumber(level)
        level = level and level > 0 and level or nil
        add({ kind = "quest", id = id, name = name, lo = level, hi = level }, (level or "") .. "|" .. (zone or ""), false)
    end
    return index
end

-- How well a name fits what's typed (lower: better), or nil: not at all.
-- The name itself, then one starting with it, a word of it starting with
-- it, anywhere in it, then every word typed starting a word of it
local function Fit(plain, typed, words)
    if plain == typed then return 0 end
    local at = plain:find(typed, 1, true)
    if at == 1 then return 1 end
    if at then return plain:sub(at - 1, at - 1) == " " and 2 or 3 end
    if #words < 2 then return nil end
    local spaced = " " .. plain
    for _, w in ipairs(words) do
        if not spaced:find(" " .. w, 1, true) then return nil end
    end
    return 4
end

-- What the name typed finds: { { e, fit } }; too little typed: everything
-- (second return true), for the filters alone
local function Match(text)
    local typed = Plain(text or "")
    local out = {}
    if #typed < MIN_TYPED then
        for i, e in ipairs(Index()) do out[i] = { e = e, fit = 0 } end
        return out, true
    end
    local words = {}
    for w in typed:gmatch("%S+") do words[#words + 1] = w end
    for _, e in ipairs(Index()) do
        local fit = Fit(e.plain, typed, words)
        if fit then out[#out + 1] = { e = e, fit = fit } end
    end
    return out, false
end

---------------------------------------------------------------------------
-- The filters: LB.searchFilters = { kind, quality ({ [quality] = true },
-- none: any), class, sub, slot, level (one of LEVELS) }, kept while the
-- game runs
---------------------------------------------------------------------------
local function Filters()
    LB.searchFilters = LB.searchFilters or {}
    return LB.searchFilters
end

local function AnyFilter(f)
    for _ in pairs(f) do return true end
    return false
end

-- Whether e gets through the filters (skip: the ones left out of it)
local NONE = {}
local function Pass(e, f, skip)
    skip = skip or NONE
    if f.kind and not skip.kind and e.kind ~= f.kind then return false end
    if f.quality and not skip.quality and not f.quality[e.quality] then return false end
    for key in pairs(ITEM_ONLY) do
        if f[key] ~= nil and not skip[key] and e[key] ~= f[key] then return false end
    end
    local level = not skip.level and f.level
    if level then
        if not e.lo then return false end
        local lo, hi = level[1], level[2]
        if lo == "mine" then lo, hi = 1, UnitLevel("player") or 1 end
        if e.hi < lo or e.lo > hi then return false end
    end
    return true
end

-- The filters in words: "Rare · Two-Handed Swords · Level 21–30"; nil: none
local function Summary(f)
    local parts = {}
    if f.kind then parts[#parts + 1] = KIND_NAMES[f.kind] end
    if f.quality then
        local names = {}
        for q = 0, 7 do
            if f.quality[q] then names[#names + 1] = QualityName(q) end
        end
        parts[#parts + 1] = table.concat(names, ", ")
    end
    if f.sub then parts[#parts + 1] = SubName(f.class, f.sub) or ClassName(f.class)
    elseif f.class then parts[#parts + 1] = ClassName(f.class) end
    if f.slot then parts[#parts + 1] = SlotName(f.slot) end
    if f.level then parts[#parts + 1] = LevelName(f.level) end
    return #parts > 0 and LB.Join(parts) or nil
end

-- A found one as a list line (an item: its rarity and type, the level it
-- asks; its name and icon come in late: asked for)
local function Line(e)
    if e.kind == "item" then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(e.id) end
        local kind = (BK.QUALITY_INK[e.quality] or "") .. (BK.QUALITY_NAMES[e.quality] or "") .. "|r"
            .. " " .. (SubName(e.class, e.sub) or ClassName(e.class))
        return { kind = "item", item = e.id, tip = e.id, name = e.name, icon = LB.ItemIcon(e.id),
            line = LB.Join({ kind, e.req > 1 and ("Requires Level " .. e.req) }) }
    end
    return LB.Entry(e.kind, e.id)
end

---------------------------------------------------------------------------
-- The search's page: its field, what it found under it
---------------------------------------------------------------------------
local Search = setmetatable({}, { __index = LB.PageClass })
Search.__index = Search

function Search:field()
    return { text = self.text, hint = "Type a name..." }
end

-- What's typed and the filters let through, by kind (the best first)
function Search:refresh()
    local f = Filters()
    local open = not self.everything or AnyFilter(f)
    local found = { item = {}, npc = {}, quest = {}, object = {} }
    local total = 0
    if open then
        for _, m in ipairs(self.matched) do
            if Pass(m.e, f) then
                local list = found[m.e.kind]
                list[#list + 1] = m
                total = total + 1
            end
        end
    end
    -- (nothing typed: by level, then name)
    local typed = not self.everything
    local lines = {}
    for _, kind in ipairs(KINDS) do
        local list = found[kind[1]]
        table.sort(list, function(a, b)
            if typed then
                if a.fit ~= b.fit then return a.fit < b.fit end
                if #a.e.plain ~= #b.e.plain then return #a.e.plain < #b.e.plain end
            elseif (a.e.lo or 999) ~= (b.e.lo or 999) then
                return (a.e.lo or 999) < (b.e.lo or 999)
            end
            if a.e.plain ~= b.e.plain then return a.e.plain < b.e.plain end
            return a.e.id < b.e.id
        end)
        local section = {}
        for i = 1, math.min(#list, PER_KIND) do section[#section + 1] = Line(list[i].e) end
        if #section > 0 then
            lines[#lines + 1] = { header = kind[2], info = #list > #section and (#section .. " of " .. #list) or #list }
            for _, l in ipairs(section) do lines[#lines + 1] = l end
        end
    end
    self.total = open and total or nil
    self.lines = lines
    self.views = {}
end

function Search:typed(text)
    self.text = text
    LB.lastSearch = text
    self.matched, self.everything = Match(text)
    self:refresh()
end

function Search:heading()
    local owned = ""
    if self.total then
        owned = self.total == 0 and "Nothing found" or (self.total == 1 and "1 found" or (self.total .. " found"))
    elseif (self.text or "") ~= "" then
        owned = "Type " .. MIN_TYPED .. " letters or more"
    end
    return { icon = ICON, round = false, title = "",
        kind = Summary(Filters()) or "Items, creatures, quests, chests and nodes", owned = owned, chapter = "Search" }
end

function Search:notes()
    if self.total == 0 then
        return { "Nothing in these pages goes by that name" .. (AnyFilter(Filters()) and " with these filters" or "")
            .. ". A part of it will do: “silk” finds Silk Cloth and Bolt of Silk Cloth." }, nil, {}
    end
    if not self.total then
        return { "Look up anything these pages know by its name: an item, a creature, a quest, a chest or a"
            .. " plant. A part of it will do. Or choose a filter, a weapon's type, a rarity, a level, and"
            .. " find all it lets through." }, nil, {}
    end
    return {}, nil, self.lines
end

function Search:about() return nil end

---------------------------------------------------------------------------
-- The filters (L3): a section a filter, a choice each that finds something
-- (with the others on; the type's with its own subtype and slot off, as
-- choosing it clears them). Each pick searches again at once
---------------------------------------------------------------------------
-- (a kind counted with the items' filters off: choosing another clears them)
local SKIPS = { kind = { kind = true, quality = true, class = true, sub = true, slot = true }, quality = { quality = true }, class = { class = true, sub = true, slot = true },
    sub = { sub = true, slot = true }, slot = { slot = true }, level = { level = true } }
local LEVEL_ONLY = {}
for i, level in ipairs(LEVELS) do LEVEL_ONLY[i] = { level = level } end

-- How many each choice finds: { [key] = { [value] = n } } (level: by its
-- index in LEVELS)
local function Counts(search)
    local f, counts = Filters(), {}
    for key in pairs(SKIPS) do counts[key] = {} end
    for _, m in ipairs(search.matched) do
        local e = m.e
        for key, skip in pairs(SKIPS) do
            if Pass(e, f, skip) then
                local c = counts[key]
                if key == "level" then
                    if e.lo then
                        for i, only in ipairs(LEVEL_ONLY) do
                            if Pass(e, only) then c[i] = (c[i] or 0) + 1 end
                        end
                    end
                elseif e[key] ~= nil then
                    c[e[key]] = (c[e[key]] or 0) + 1
                end
            end
        end
    end
    return counts
end

-- A choice made (the type's subtype and slot with it; a kind other than
-- items: the items' filters off; an item's filter: the kind back to any
-- unless items)
local function Choose(key, value)
    local f = Filters()
    if key == "quality" then
        local set = f.quality or {}
        set[value] = not set[value] or nil
        f.quality = next(set) and set or nil
    else
        f[key] = value
    end
    if key == "class" then f.sub, f.slot = nil, nil end
    if key == "kind" and value and value ~= "item" then
        f.quality = nil
        for k in pairs(ITEM_ONLY) do f[k] = nil end
    end
    if (ITEM_ONLY[key] or key == "quality") and f.kind and f.kind ~= "item" then f.kind = nil end
end

function Search:filter()
    return { text = "Filters", build = function() return self:filterEntries() end }
end

-- The dropdown's entries
function Search:filterEntries()
    local f, counts = Filters(), Counts(self)
    local entries = {}
    -- (a section: its title and choices, when one finds something; an
    -- "any" choice first, value nil)
    local function section(title, key, choices, check)
        local list = {}
        for _, c in ipairs(choices) do
            local value, name, n = c[1], c[2], c[3]
            local chosen
            if check then chosen = f.quality and f.quality[value] or false
            else chosen = f[key] == value end
            if (n or 0) > 0 or chosen then
                list[#list + 1] = { kind = check and "checkbox" or "radio", text = name, selected = chosen,
                    key = key .. ":" .. tostring(value), select = function()
                        Choose(key, value)
                        self:refresh()
                    end }
            end
        end
        if #list == 0 then return end
        if not check then
            table.insert(list, 1, { kind = "radio", text = choices.any, selected = f[key] == nil, key = key .. ":any",
                select = function()
                    Choose(key, nil)
                    self:refresh()
                end })
        end
        if #entries > 0 then entries[#entries + 1] = { kind = "divider" } end
        entries[#entries + 1] = { kind = "title", text = title }
        for _, e in ipairs(list) do entries[#entries + 1] = e end
    end
    local kinds = { any = "Everything" }
    for _, k in ipairs(KINDS) do kinds[#kinds + 1] = { k[1], k[2], counts.kind[k[1]] } end
    section("Kind", "kind", kinds)
    local qualities = {}
    for q = 0, 7 do
        if BK.QUALITY_NAMES[q] then qualities[#qualities + 1] = { q, QualityName(q), counts.quality[q] } end
    end
    section("Rarity |cff9d917a(none ticked: any)|r", "quality", qualities, true)
    local levels = { any = "Any Level" }
    for i, level in ipairs(LEVELS) do levels[#levels + 1] = { level, LevelName(level), counts.level[i] } end
    section("Level", "level", levels)
    local classes = { any = "Any Type" }
    for _, class in ipairs(CLASS_ORDER) do classes[#classes + 1] = { class, ClassName(class), counts.class[class] } end
    section("Type", "class", classes)
    if f.class then
        local subs = { any = "Any " .. ClassName(f.class) }
        for sub, n in pairs(counts.sub) do subs[#subs + 1] = { sub, SubName(f.class, sub) or ("Type " .. sub), n } end
        table.sort(subs, function(a, b) return a[2] < b[2] end)
        section(ClassName(f.class) .. " Type", "sub", subs)
        if f.class == 2 or f.class == 4 then
            local slots = { any = "Any Slot" }
            for _, slot in ipairs(SLOTS) do
                slots[#slots + 1] = { slot[1], SlotName(slot[1]), counts.slot[slot[1]] }
            end
            section("Slot", "slot", slots)
        end
    end
    return entries
end

-- Triangle on a page of the Wiki: the search, what was typed last in it
function LB.Search()
    local book = LB.book
    if IF.InCombat() or not book:IsShown() then return end
    local p = setmetatable({ tab = "notes", views = {} }, Search)
    p:typed(LB.lastSearch or "")
    book:Push(p)
end
