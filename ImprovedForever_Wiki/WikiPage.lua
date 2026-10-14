-- The Wiki's page (Wiki.lua knows what is shown): a page of the core's
-- book (ImprovedForever's Book.lua: Forever's spellbook window). The item is
-- the page's title (its icon in the spellbook's frame), under the rule its
-- notes: what a traveller wrote about it, then an entry a subject (where it
-- is found, its people, what it's crafted from, what it's a reagent for, its
-- quests): Cross opens that list. A list: the creatures, objects and people
-- by zone (Cross: a waypoint at the nearest spawn; a container: its page),
-- the recipes by profession (Cross: the other item's page), the quests;
-- Circle goes back to the notes, then to the item before. A creature's, a
-- chest's, a quest's page likewise. LB.Page(kind, id) is a page for any book
-- (the Journal's too).
-- Never in combat.
local IF = ImprovedForever

local A = IF.Auction
local BY = IF.AuctionBuy
local LB = IF.Wiki
local BK = IF.Book

---------------------------------------------------------------------------
-- The lists' words and icons
---------------------------------------------------------------------------
-- The lists: what they're about (the page's top right), their entry's icon
local ICON = "Interface\\Icons\\"
local LISTS = {
    creatures = "Creatures", gathering = "Gathering", containers = "Containers", people = "People",
    trainers = "Trainers",
    profession = "Profession", quests = "Quests",
}
-- (their entry in the notes)
local ENTRY_NAMES = LISTS
-- A profession's own icon (Craft, Reagent: the profession of their first recipe)
-- A gathering's own icon, its gatherers, how they gather
local GATHERING = {
    herb = { icon = ICON .. "Trade_Herbalism", people = "Herbalists", verb = "pick it from", short = "Picked from",
        nodes = "plants" },
    ore = { icon = ICON .. "Trade_Mining", people = "Miners", verb = "take it from", short = "Mined from",
        nodes = "veins" },
    fish = { icon = ICON .. "Trade_Fishing", people = "Fishermen", verb = "draw it from", short = "Fished from",
        nodes = "pools" },
}
local PROFESSION_ICONS = {
    [164] = ICON .. "Trade_BlackSmithing", [165] = ICON .. "Trade_LeatherWorking", [171] = ICON .. "Trade_Alchemy",
    [185] = ICON .. "INV_Misc_Food_15", [186] = ICON .. "Trade_Mining", [197] = ICON .. "Trade_Tailoring",
    [202] = ICON .. "Trade_Engineering", [333] = ICON .. "Trade_Engraving", [129] = ICON .. "Spell_Holy_SealOfSacrifice",
}
local LIST_ICONS = {
    creatures = ICON .. "INV_Misc_Bone_HumanSkull_01", chests = ICON .. "INV_Box_02",
    people = ICON .. "INV_Misc_GroupLooking", quests = ICON .. "INV_Misc_Note_01",
}

-- An item's quality, in an ink that reads on parchment (the book's)
local QUALITY_INK, QUALITY_NAMES = BK.QUALITY_INK, BK.QUALITY_NAMES

local function Glyph(key, size) return IF.GlyphText(key, size) end

---------------------------------------------------------------------------
-- The notes: written from what is known (a traveller's words, a section a
-- subject, each with a link to its list)
---------------------------------------------------------------------------
local Count, Plural, Names, Name = BK.Count, BK.Plural, BK.Names, BK.Name
local Capital, A_plain, A_, Coins, Shorten = BK.Capital, BK.A_plain, BK.A_, BK.Coins, BK.Shorten

local function ItemName(id)
    local name = LB.ItemInfo(id)
    return name and Name(name) or "another item"
end

local PEOPLE = {
    [164] = "Blacksmiths", [165] = "Leatherworkers", [171] = "Alchemists", [185] = "Cooks", [186] = "Miners",
    [197] = "Tailors", [202] = "Engineers", [333] = "Enchanters", [129] = "Those trained in first aid",
}

-- Who works these recipes: "Tailors and blacksmiths"
local function People(list)
    local seen, names = {}, {}
    for _, l in ipairs(list or {}) do
        local who = PEOPLE[l.skill]
        if who and not seen[who] then
            seen[who] = true
            names[#names + 1] = #names == 0 and who or who:lower()
        end
    end
    local text = Names(names)
    return text ~= "" and text or "Craftsmen"
end

-- A recipe's reagents in words: "2 Linen Cloth and 1 Coarse Thread"
local function ReagentWords(row)
    local parts = {}
    for i = 5, #(row or {}), 2 do parts[#parts + 1] = row[i + 1] .. " " .. ItemName(row[i]) end
    return Names(parts)
end

-- What each section of a list holds: { [header] = { lines } }
local function Sections(lines)
    local out, section = {}, ""
    for _, l in ipairs(lines or {}) do
        if l.header then
            section = l.header
        else
            out[section] = out[section] or {}
            table.insert(out[section], l)
        end
    end
    return out
end

-- Recipes under their profession's header (the index keeps them in
-- profession order): prefix ("Made with "), lines (added to)
local function ByProfession(list, prefix, lines)
    local header
    lines = lines or {}
    for _, l in ipairs(list or {}) do
        if not header or header.skill ~= l.skill then
            header = { header = (prefix or "") .. LB.SkillName(l.skill), info = 0, skill = l.skill }
            lines[#lines + 1] = header
        end
        header.info = header.info + 1
        lines[#lines + 1] = l
    end
    return lines
end

local function Signature()
    if UnitFactionGroup("player") == "Horde" then return "— from the journal of a Horde field scout" end
    return "— from the field notes of the Explorers' League"
end

-- A list's entries (its headers left out), and how many there are in all
local function Entries(lines)
    local out = {}
    for _, l in ipairs(lines or {}) do
        if not l.header then out[#out + 1] = l end
    end
    return out
end

local function Total(lines)
    return math.max(Count(lines), lines and lines.total or 0)
end

-- A list by zone read back: its zones' names (three at most), the entry in
-- the player's zone and that zone
local function Places(lines)
    local zones, here, hereZone, section = {}, nil, nil, nil
    for _, l in ipairs(lines or {}) do
        if l.header then
            section = l.header
            local zone = section:gsub("  %(here%)", "")
            if section ~= "Elsewhere" and section ~= "Around the world" and #zones < 3 then
                zones[#zones + 1] = Name(zone)
            end
            if section:find("%(here%)") then hereZone = zone end
        elseif not here and hereZone and section and section:find("%(here%)") then
            here = l
        end
    end
    return zones, here, hereZone
end

-- The names in a list, each once (a node is in several zones)
local function Unique(lines)
    local seen, names = {}, {}
    for _, l in ipairs(Entries(lines)) do
        if not seen[l.plain] then
            seen[l.plain] = true
            names[#names + 1] = l.plain
        end
    end
    return names
end

-- What is written about it, a traveller's words (not a list), by subject:
-- { creatures, chests, gathering, items, here, people, profession, quests,
-- trainers, worth } (each a list of sentences; here: hereFrom, the subject
-- the place to look is in)
local function Said(p)
    local t = p.tabs
    local said = { creatures = {}, chests = {}, gathering = {}, items = {}, here = {}, people = {},
        profession = {}, quests = {}, trainers = {}, worth = {}, contents = {} }

    -- Where it is found: creatures, chests and the like, herbs, veins and
    -- pools, containers
    local drops = p.drops or {}
    local creatures, chests = Total(drops.creatures), Total(drops.chests)
    local zones, here, hereZone = Places(drops.creatures)
    if creatures > 0 then
        table.insert(said.creatures, (creatures == 1 and "A single creature is known to drop it" or
            (creatures .. " creatures are known to drop it"))
            .. (#zones > 0 and (", most readily in " .. Names(zones)) or "") .. ".")
    end
    if chests > 0 then
        local first = Entries(drops.chests)[1]
        table.insert(said.chests, chests == 1 and ("It can be found in " .. A_(first.plain) .. ".")
            or ("It turns up in " .. chests .. " chests and the like, " .. A_(first.plain) .. " among them."))
    end
    for _, how in ipairs({ "herb", "ore", "fish" }) do
        local names = Unique(drops[how])
        if #names > 0 then
            table.insert(said.gathering, GATHERING[how].people .. " " .. GATHERING[how].verb .. " "
                .. Names(Shorten(names, 3)) .. ".")
        end
    end
    local items = {}
    for _, l in ipairs(drops.items or {}) do items[#items + 1] = ItemName(l.item) end
    if #items > 0 then table.insert(said.items, "It also turns up inside " .. Names(Shorten(items, 3)) .. ".") end
    said.hereFrom = here and "creatures"
    if not here then
        local _, there, thereZone = Places(drops.chests)
        here, hereZone = there, thereZone
        said.hereFrom = here and "chests"
    end
    if here then
        table.insert(said.here, "Here in " .. Name(hereZone) .. ", look for " .. Name(here.plain or here.name)
            .. (here.level and (", around level " .. here.level) or "") .. ".")
    end
    local total = creatures + chests + Total(drops.herb) + Total(drops.ore) + Total(drops.fish) + #items

    -- Who sells it
    local sellers = Entries(t.people)
    if #sellers > 0 then
        local v = sellers[1]
        table.insert(said.people, Name(v.plain or v.name) .. (v.sub and (" (" .. v.sub .. ")") or "")
            .. " sells it" .. (v.zone and (" in " .. LB.ZoneName(v.zone)) or "")
            .. (#sellers > 1 and ("; " .. Plural(#sellers - 1, "other merchant does", "other merchants do") .. " too")
                or "") .. ".")
    elseif total > 0 then
        table.insert(said.people, "No merchant is known to sell it.")
    end

    -- Crafted from, a reagent for, taught
    local made, teaches, used = p.recipes["Made by"], p.recipes["Teaches"], p.recipes["Used in"]
    local making, using
    -- (its reagents and where it's learnt: the recipe's block under the notes)
    if made then
        making = People(made) .. (#made == 1 and " make it" or (" know " .. #made .. " ways to make it"))
    end
    if used then
        local first = used[1].make
        using = (#used == 1 and first) and (" to make " .. ItemName(first))
            or (" in " .. Plural(#used, "recipe", "recipes") .. (first and (", " .. ItemName(first) .. " among them") or ""))
    end
    if making and using and People(made) == People(used) then
        -- (the same hands: one sentence)
        table.insert(said.profession, making .. ", and use it" .. using .. ".")
    else
        if making then table.insert(said.profession, making .. ".") end
        if using then table.insert(said.profession, People(used) .. " use it" .. using .. ".") end
    end
    if teaches and teaches[1] then table.insert(said.profession, "Studied, it teaches " .. Name(teaches[1].name) .. ".") end

    -- Its trainers (the recipe that makes it): "It comes with Alchemy: any
    -- of its 25 trainers starts you on it", "24 trainers teach it, Milla
    -- Fairancora in Darnassus among them"
    local trainers = Entries(t.trainers)
    if #trainers > 0 then
        local first = trainers[1]
        local who = Name(first.plain) .. (first.zone and first.zone > 0 and (" in " .. LB.ZoneName(first.zone)) or "")
        if p.starter then
            table.insert(said.trainers, "It comes with " .. LB.SkillName(made[1].skill) .. " itself: "
                .. (#trainers == 1 and who or ("any of its " .. #trainers .. " trainers, " .. who .. " among them,"))
                .. " starts you on it.")
        else
            table.insert(said.trainers, #trainers == 1 and ("Only " .. who .. " teaches it.")
                or (#trainers .. " trainers teach it, " .. who .. " among them."))
        end
    end

    -- Quests: one sentence a role, a few named
    local roles = { starts = {}, reward = {}, objective = {} }
    for _, l in ipairs(t.quests or {}) do
        if roles[l.role] then table.insert(roles[l.role], "“" .. l.name .. "”") end
    end
    if #roles.starts > 0 then
        table.insert(said.quests, "Reading it begins the quest " .. Names(Shorten(roles.starts, 1)) .. ".")
    end
    if #roles.reward > 0 then
        table.insert(said.quests, "It is given as the reward for " .. Names(Shorten(roles.reward, 3)) .. ".")
    end
    if #roles.objective > 0 then
        table.insert(said.quests, Names(Shorten(roles.objective, 3)) .. (#roles.objective == 1 and " calls" or " call")
            .. " for it.")
    end

    -- What it holds (a container item)
    local inside = t.contents or {}
    if #inside > 0 then
        local names = {}
        for i = 1, math.min(2, #inside) do names[i] = ItemName(inside[i].item) end
        table.insert(said.contents, "Opened, it yields " .. (#inside == 1 and names[1]
            or (Plural(#inside, "item", "items") .. ", " .. Names(names) .. " among them")) .. ".")
    end

    -- Its worth
    local usual = A and A.MarketPrice(p.id, A.Settings().chartDays)
    local sell = select(11, LB.ItemInfo(p.id))
    if usual then
        table.insert(said.worth, "At the auction house it usually fetches " .. Name(Coins(usual))
            .. (sell and sell > 0 and ("; a merchant pays " .. Name(Coins(sell))) or "") .. ".")
    elseif sell and sell > 0 then
        table.insert(said.worth, "A merchant would pay " .. Name(Coins(sell)) .. " for it.")
    end
    return said
end

-- Sentences of these subjects, one paragraph
local function Paragraph(said, ...)
    local out = {}
    for _, key in ipairs({ ... }) do
        for _, sentence in ipairs(said[key] or {}) do out[#out + 1] = sentence end
    end
    return #out > 0 and table.concat(out, " ") or nil
end

-- The notes: { paragraph, ... }; where it is found and who sells it, then
-- what is made of it and its worth
local function Notes(p)
    local said = Said(p)
    local paragraphs = {}
    paragraphs[#paragraphs + 1] = Paragraph(said, "creatures", "chests", "gathering", "items", "here", "people")
    paragraphs[#paragraphs + 1] = Paragraph(said, "contents", "profession", "quests", "worth")
    if #paragraphs == 0 then
        paragraphs[1] = "Little is written of it yet. Perhaps a traveller will add to these pages one day."
    end
    return paragraphs
end


-- Who works a list of recipes, for a subtitle: verb "Made" -> "Made by
-- Alchemists", "Made by Tailors and blacksmiths", "Made by 4 professions",
-- "Made with First Aid" (no people of its own)
local FIRST_AID = 129
local function Workers(verb, list)
    local seen, n = {}, 0
    for _, l in ipairs(list or {}) do
        if l.skill and not seen[l.skill] then
            seen[l.skill] = true
            n = n + 1
        end
    end
    if n > 2 then return verb .. " by " .. n .. " professions" end
    if n == 1 and seen[FIRST_AID] then return verb .. " with " .. LB.SkillName(FIRST_AID) end
    return verb .. " by " .. People(list)
end

-- The quests' roles in a few words: "Rewarded from 7 tasks", "Rewarded
-- from 2 tasks, needed for 1"
local function QuestRoles(quests)
    local n = { reward = 0, objective = 0, starts = 0 }
    for _, l in ipairs(quests or {}) do
        if n[l.role] then n[l.role] = n[l.role] + 1 end
    end
    -- (the entry's title says "Quests": "tasks" here)
    local parts = {}
    if n.reward > 0 then parts[#parts + 1] = "rewarded from " .. Plural(n.reward, "task", "tasks") end
    if n.objective > 0 then
        parts[#parts + 1] = "needed for " .. (#parts > 0 and n.objective or Plural(n.objective, "task", "tasks"))
    end
    if n.starts > 0 then parts[#parts + 1] = "starts " .. (n.starts == 1 and "one" or n.starts) end
    local text = table.concat(parts, ", ")
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- The notes' entries: one a list that has something (Cross: that list)
local function Subjects(p)
    local t, lines = p.tabs, {}
    local function add(key, line, icon)
        lines[#lines + 1] = { go = key, icon = icon or LIST_ICONS[key], name = ENTRY_NAMES[key], line = line }
    end
    -- What drops it, who sells it: the entry's line says how they come by
    -- it, in a word other than its title's ("Creatures: Dropped by 247
    -- foes"), or the one there is ("Dropped by Hogger")
    local drops = p.drops or {}
    local function some(verb, lines, noun)
        local n = Total(lines)
        return verb .. " " .. (n == 1 and Entries(lines)[1].plain or (n .. " " .. noun))
    end
    -- (only one: its face, once known)
    local function face(list)
        local only = Total(list) == 1 and Entries(list)[1]
        lines[#lines].portrait = only and only.kind == "npc" and only.id or nil
    end
    if Total(drops.creatures) > 0 then
        add("creatures", some("Dropped by", drops.creatures, "foes"))
        face(drops.creatures)
    end
    -- Gathering: herbs, veins, pools ("Mined from Copper Vein and 2 more",
    -- "Picked from Peacebloom, fished from School of Fish")
    local gathered, gatherIcon = {}, nil
    for _, kind in ipairs({ "herb", "ore", "fish" }) do
        local names = Unique(drops[kind])
        if #names > 0 then
            gathered[#gathered + 1] = GATHERING[kind].short:lower() .. " "
                .. (#names == 1 and names[1] or (names[1] .. " and " .. (#names - 1) .. " more"))
            gatherIcon = gatherIcon or GATHERING[kind].icon
        end
    end
    if #gathered > 0 then add("gathering", Capital(table.concat(gathered, ", ")), gatherIcon) end
    -- Containers: chests, and the items it comes inside ("Found in 14
    -- chests and 5 items", "Opened from Battered Box")
    local chests, items = Unique(drops.chests), drops.items or {}
    if #chests > 0 or #items > 0 then
        local text
        local chestCount = #Entries(drops.chests)
        if #items == 0 then
            text = #chests == 1 and ("Found in " .. A_plain(chests[1])) or ("Found in " .. chestCount .. " chests")
        elseif #chests == 0 then
            text = "Opened from " .. (#items == 1 and (LB.ItemInfo(items[1].item) or "an item") or (#items .. " items"))
        else
            text = "Found in " .. Plural(chestCount, "chest", "chests") .. " and " .. Plural(#items, "item", "items")
        end
        add("containers", text, #chests > 0 and LIST_ICONS.chests or LB.ItemIcon(items[1].item))
    end
    if Count(t.people) > 0 then
        add("people", some("Sold by", t.people, "vendors"))
        face(t.people)
    end
    -- Profession: made by, used by, taught ("Made by Tailors, used by
    -- cooks", "Used by Cooks and engineers")
    local made, used, teaches = p.recipes["Made by"], p.recipes["Used in"], p.recipes["Teaches"]
    local crafts = {}
    local making, using = made and Workers("Made", made), used and Workers("Used", used)
    if making and using and making:sub(5) == using:sub(5) then
        -- (the same hands: "Made and used by Tailors")
        crafts[1] = "Made and used" .. making:sub(5)
    else
        crafts[#crafts + 1] = making
        crafts[#crafts + 1] = using
    end
    if teaches and teaches[1] then crafts[#crafts + 1] = "Teaches " .. LB.SkillName(teaches[1].skill) end
    if #crafts > 0 then
        for i = 2, #crafts do crafts[i] = crafts[i]:sub(1, 1):lower() .. crafts[i]:sub(2) end
        local first = (made or used or teaches)[1]
        add("profession", table.concat(crafts, ", "), PROFESSION_ICONS[first.skill])
    end
    if Count(t.quests) > 0 then add("quests", QuestRoles(t.quests)) end
    return lines
end

-- A merged list's section: its title, then a list's entries (one by zone
-- read flat: each entry names its zone)
local function Section(into, title, lines)
    local entries, zone = {}, nil
    for _, l in ipairs(lines or {}) do
        if l.header then
            zone = (l.header ~= "Elsewhere" and l.header ~= "Around the world") and l.header:gsub("  %(here%)", "") or nil
        else
            if zone then l.line = LB.Join({ zone, l.line }) end
            entries[#entries + 1] = l
        end
    end
    if #entries == 0 then return end
    into[#into + 1] = { header = title, info = #entries }
    for _, l in ipairs(entries) do into[#into + 1] = l end
end

-- A creature's page: its places, what it drops and sells
-- Item classes, in the order a page shows them (Enum.ItemClass); the rest
-- after these
local CLASS_ORDER = { 2, 4, 0, 7, 9, 12, 1, 5, 3, 6, 11, 13, 15 }

-- Items by their class: { { class, name, lines } }, in CLASS_ORDER (each
-- list as given: the best first)
local function ByClass(lines)
    local groups, byClass = {}, {}
    for _, l in ipairs(lines) do
        local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local _, itemType, _, _, _, class = get(l.item)
        class = class or 15
        local g = byClass[class]
        if not g then
            g = { class = class, name = itemType or "Miscellaneous", lines = {} }
            byClass[class] = g
            groups[#groups + 1] = g
        end
        table.insert(g.lines, l)
    end
    local rank = {}
    for i, class in ipairs(CLASS_ORDER) do rank[class] = i end
    table.sort(groups, function(a, b) return (rank[a.class] or 99) < (rank[b.class] or 99) end)
    return groups
end

-- Items a page lists by class: a list a class ("loot2", "wares4"), titled
-- with the class's name
local function Grouped(p, what, lines)
    p.tabs, p.titles, p.groups = p.tabs or {}, p.titles or {}, p.groups or {}
    p.tabs[what] = lines
    p.groups[what] = ByClass(lines)
    for _, g in ipairs(p.groups[what]) do
        g.key = what .. g.class
        p.tabs[g.key] = g.lines
        p.titles[g.key] = g.name
    end
end

-- What a page's item groups say: an entry a class ("Hogger's Trophy and 11
-- more"; Cross, that class's list)
local function GroupEntries(p, what)
    local entries = {}
    for _, g in ipairs(p.groups and p.groups[what] or {}) do
        local best = LB.ItemInfo(g.lines[1].item)
        entries[#entries + 1] = { go = g.key, icon = LB.ItemIcon(g.lines[1].item), name = g.name,
            line = best and (best .. (#g.lines > 1 and (" and " .. (#g.lines - 1) .. " more") or ""))
                or Plural(#g.lines, "item", "items") }
    end
    return entries
end

-- A creature's page (p.npc) or a chest's, a node's (p.object): where it is,
-- what it drops, sells, teaches (a trainer: what its recipes make), holds
local LOOTS = {
    npc = { { "loot", "Loot" }, { "wares", "Wares" }, { "teaches", "Teaches", flat = true } },
    object = { { "holds", "Loot" } },
}
local function BuildCreature(p)
    p.creature = p.npc and LB.Creature(p.npc) or LB.Thing(p.object)
    p.tabs, p.titles, p.groups = {}, {}, {}
    if p.npc then
        Grouped(p, "loot", LB.Loot(p.npc))
        Grouped(p, "wares", LB.Wares(p.npc))
        Grouped(p, "teaches", LB.Teaches(p.npc))
    else
        Grouped(p, "holds", LB.Holds(p.object))
    end
    p.views = {}
end

-- What is written about a creature, a chest, a node, by subject ({ places,
-- loot, wares, teaches, holds })
local function CreatureSaid(p)
    local c, t = p.creature, p.tabs
    local said = { places = {}, loot = {}, wares = {}, teaches = {}, holds = {} }
    if not c then return said end
    local zones, inside = {}, false
    for _, l in ipairs(c.places) do
        if l.spot then zones[#zones + 1] = l.plain else inside = true end
    end
    if #zones > 0 then
        table.insert(said.places, Name(c.name) .. " is found in " .. Names(Shorten(zones, 3)) .. ".")
    elseif inside then
        table.insert(said.places, Name(c.name) .. " dwells inside an instance.")
    end
    local function some(key, verb)
        local n = #(t[key] or {})
        if n == 0 then return end
        local names = {}
        for i = 1, math.min(2, n) do names[i] = ItemName(t[key][i].item) end
        table.insert(said[key], "It " .. verb .. " " .. (n == 1 and names[1]
            or (Plural(n, "item", "items") .. ", " .. Names(names) .. " among them")) .. ".")
    end
    some("loot", "is known to drop")
    some("wares", "sells")
    some("teaches", "teaches the making of")
    some("holds", c.how and "yields" or "holds")
    return said
end

local function CreatureNotes(p)
    local text = Paragraph(CreatureSaid(p), "places", "loot", "wares", "teaches", "holds")
    return { text or "Little is written of it yet. Perhaps a traveller will add to these pages one day." }
end

-- A list's own paragraph, on top of it: what the notes say of its subject
local ABOUT = {
    creatures = { "creatures" }, gathering = { "gathering" }, containers = { "chests", "items" },
    people = { "people" }, profession = { "profession" }, quests = { "quests" }, trainers = { "trainers" },
}
local function About(p, key)
    if p.creature or p.questInfo then return nil end   -- (a creature's, a chest's, a quest's page: no lists)
    local said = Said(p)
    local keys = { unpack(ABOUT[key] or {}) }
    -- (where to look, with the subject it's in)
    if said.hereFrom == "creatures" and key == "creatures" or said.hereFrom == "chests" and key == "containers" then
        keys[#keys + 1] = "here"
    end
    return Paragraph(said, unpack(keys))
end

-- Its sections: where it is (a zone a line: Cross, a waypoint), what it
-- drops, what it sells (every item: Cross, its page)
local function CreatureLines(p)
    local lines = {}
    local function section(title, list, count)
        if #list == 0 then return end
        lines[#lines + 1] = { header = title, info = count or #list }
        for _, l in ipairs(list) do lines[#lines + 1] = l end
    end
    section("Locate", p.creature and p.creature.places or {})
    -- (by class, an entry each; a trainer's teachings: every item)
    for _, what in ipairs(LOOTS[p.npc and "npc" or "object"]) do
        local items = p.tabs[what[1]] or {}
        section(what[2], what.flat and items or GroupEntries(p, what[1]), #items)
    end
    return lines
end

-- A quest's page: who gives it and takes it back, what it rewards, the
-- quests before and after it
local function BuildQuest(p)
    p.questInfo = LB.Quest(p.quest)
    p.tabs, p.views = {}, {}
end

-- Its notes: what the quest asks, in its own words, then who and what
local function QuestNotes(p)
    local q, out = p.questInfo, {}
    if #q.objectives > 0 then out[#out + 1] = "“" .. table.concat(q.objectives, " ") .. "”" end
    local said = {}
    local giver, ender = q.givers[1], q.enders[1]
    if giver then
        local name = giver.plain or LB.ItemInfo(giver.item) or "an item"
        said[#said + 1] = (giver.kind == "item" and ("Reading " .. Name(name) .. " begins it")
            or (Name(name) .. (giver.zone and giver.zone > 0 and (" in " .. LB.ZoneName(giver.zone)) or "") .. " gives it"))
            .. (ender and ender.plain and ender.plain ~= giver.plain and ("; " .. Name(ender.plain) .. " takes it back") or "") .. "."
    elseif ender and ender.plain then
        said[#said + 1] = Name(ender.plain) .. " takes it back."
    end
    if #q.rewards > 0 then
        local names = {}
        for i = 1, math.min(2, #q.rewards) do names[i] = ItemName(q.rewards[i].item) end
        said[#said + 1] = "Completing it rewards " .. (#q.rewards == 1 and names[1]
            or (Plural(#q.rewards, "item", "items") .. ", " .. Names(names) .. " among them")) .. "."
    end
    if q.before[1] then said[#said + 1] = "It follows " .. Name("“" .. q.before[1].name .. "”") .. "." end
    if q.after[1] then said[#said + 1] = Name("“" .. q.after[1].name .. "”") .. " comes next." end
    if #said > 0 then out[#out + 1] = table.concat(said, " ") end
    if #out == 0 then out[1] = "Little is written of it yet. Perhaps a traveller will add to these pages one day." end
    return out
end

-- Its sections: where it begins, rewards, the chain (Cross: their pages;
-- Square: a giver on the map)
local function QuestLines(p)
    local q, lines = p.questInfo, {}
    local function section(title, list)
        if #list == 0 then return end
        lines[#lines + 1] = { header = title, info = #list }
        for _, l in ipairs(list) do lines[#lines + 1] = l end
    end
    -- (where it begins: who gives it, the item that starts it; who takes it
    -- back is in the notes)
    section("Giver", q.givers)
    section("Rewards", q.rewards)
    local chain = {}
    for _, l in ipairs(q.before) do chain[#chain + 1] = l end
    for _, l in ipairs(q.after) do chain[#chain + 1] = l end
    section("Chain", chain)
    return lines
end

local function Build(p)
    if p.quest then return BuildQuest(p) end
    if p.npc or p.object then return BuildCreature(p) end
    local id = p.id
    p.recipes = Sections(LB.Recipes(id))
    p.drops = LB.Drops(id)
    local d = p.drops
    local gathering = {}
    Section(gathering, "Herbs", d.herb)
    Section(gathering, "Mining", d.ore)
    Section(gathering, "Fishing", d.fish)
    local containers = {}
    Section(containers, "Chests", d.chests)
    Section(containers, "Items", d.items)
    local profession = ByProfession(p.recipes["Made by"], "Made with ")
    ByProfession(p.recipes["Used in"], "Used in ", profession)
    if p.recipes["Teaches"] then Section(profession, "Teaches", p.recipes["Teaches"]) end
    p.tabs = {
        creatures = d.creatures or {}, gathering = gathering, containers = containers,
        people = LB.People(id), quests = LB.Quests(id), profession = profession,
    }
    -- (a container item: what it holds, by class)
    Grouped(p, "contents", LB.Contents(id))
    -- (the trainers of the recipe that makes it: its Learning entry's list)
    local made = p.recipes["Made by"]
    p.tabs.trainers = {}
    if made and not made[1].taught then p.tabs.trainers, p.starter = LB.Trainers(made[1].spell, made[1].skill) end
    p.views = {}
end

-- An item a profession makes: its recipe's sections under the notes, as a
-- list's (the first recipe's, when there are several): its reagents (Cross:
-- their pages), where it's learnt (the recipe item: its page; a trainer)
local function Recipe(p)
    local made = p.recipes["Made by"]
    if not made then return {} end
    local first, lines = made[1], {}
    local row = first.row or {}
    if #row > 4 then
        lines[#lines + 1] = { header = "Reagents", info = #made > 1 and ("1 of " .. #made .. " recipes") or nil }
        for i = 5, #row, 2 do
            lines[#lines + 1] = { kind = "item", item = row[i], tip = row[i], line = "× " .. row[i + 1] .. " needed" }
        end
    end
    lines[#lines + 1] = { header = "Learning" }
    if first.taught then
        lines[#lines + 1] = { kind = "item", item = first.taught, tip = first.taught, line = "Teaches the recipe" }
    else
        -- (its trainers: Cross, their list; one: their face; none known: just said)
        local trainers = Entries(p.tabs.trainers)
        local who = #trainers == 1 and trainers[1].plain or (#trainers .. " trainers")
        local text = #trainers == 0 and "Teaches the recipe"
            or p.starter and ("Comes with the profession, from " .. who) or ("Taught by " .. who)
        lines[#lines + 1] = { kind = "trainer", icon = PROFESSION_ICONS[first.skill],
            name = LB.SkillName(first.skill) .. " Trainer", line = text,
            go = #trainers > 0 and "trainers" or nil, portrait = #trainers == 1 and trainers[1].id or nil }
    end
    return lines
end

---------------------------------------------------------------------------
-- A page: its data (Build), and what the book asks of it (Book.lua)
---------------------------------------------------------------------------
local Page = {}
Page.__index = Page

-- (a chest, a node: what it is)
local THING_KIND = { herb = "Herb", ore = "Mining node", fish = "Fishing pool" }

function Page:heading()
    local p = self
    local chapter = LISTS[p.tab] or p.titles and p.titles[p.tab] or "Field Notes"
    if p.questInfo then
        local q = p.questInfo
        return { icon = LB.ICONS.quest, round = true, title = q.name,
            kind = LB.Join({ q.level and q.level > 0 and ("Level " .. q.level .. " Quest") or "Quest",
                q.required and q.required > 1 and ("Requires Level " .. q.required) }),
            owned = q.zone and LB.ZoneName(q.zone) or "", chapter = "Field Notes" }
    end
    if p.creature then
        local c = p.creature
        local zones = {}
        for _, l in ipairs(c.places) do zones[#zones + 1] = l.plain end
        return { icon = p.npc and LB.ICONS.npc or (c.how and GATHERING[c.how].icon or LB.ICONS.object),
            round = true, portrait = p.npc, title = c.name,
            kind = p.npc and c.entry.line or THING_KIND[c.how] or "Chest",
            owned = #zones == 0 and ""
                or ("Found in " .. zones[1] .. (#zones > 1 and (" and " .. (#zones - 1) .. " more") or "")),
            chapter = chapter }
    end
    local name, link, quality, level, need, itemType, subType, _, _, _, sell = LB.ItemInfo(p.id)
    p.link = p.link or link
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(p.id) end
    local q = quality or 1
    local carried = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(p.id, true) or 0
    return {
        icon = LB.ItemIcon(p.id), round = false, title = name or ("Item " .. p.id),
        kind = LB.Join({ (QUALITY_INK[q] or "") .. (QUALITY_NAMES[q] or "") .. "|r"
            .. ((subType or itemType) and (" " .. (subType or itemType)) or ""),
            level and level > 1 and ("Item Level " .. level), need and need > 1 and ("Requires Level " .. need) }),
        owned = LB.Join({ carried > 0 and ("You carry " .. carried) or "You carry none",
            sell and sell > 0 and ("sells for " .. (A and A.Money(sell) or GetCoinTextureString(sell))) }),
        chapter = chapter,
    }
end

-- The notes: the paragraphs, who wrote them, the recipe's sections, then the
-- entries (under "See Also" after those)
function Page:notes()
    local p = self
    if p.creature then return CreatureNotes(p), Signature(), CreatureLines(p) end
    if p.questInfo then return QuestNotes(p), Signature(), QuestLines(p) end
    local lines = Recipe(p)
    -- (a container item: what it holds, an entry a class)
    local contents = GroupEntries(p, "contents")
    if #contents > 0 then
        lines[#lines + 1] = { header = "Contents", info = #p.tabs.contents }
        for _, l in ipairs(contents) do lines[#lines + 1] = l end
    end
    local subjects = Subjects(p)
    if #lines > 0 and #subjects > 0 then lines[#lines + 1] = { header = "See Also" } end
    for _, l in ipairs(subjects) do lines[#lines + 1] = l end
    return Notes(p), Signature(), lines
end

function Page:list(key)
    return self.tabs and self.tabs[key] or {}
end

function Page:about(key)
    return About(self, key)
end

-- Cross on an entry: another item's, creature's or quest's page (in the
-- book it's in), a place on the map
function Page:activate(line, book)
    if line.item then return book:Push(LB.Page("item", line.item)) end
    if line.kind == "npc" or line.kind == "object" then return book:Push(LB.Page(line.kind, line.id)) end
    if line.kind == "quest" then return book:Push(LB.Page("quest", line.id)) end
    if line.kind == "place" then return LB.ShowOnMap(line, book) end
end

-- Square: the entry on the map (a creature, a person, a chest, a node, a
-- place: WikiMap.lua)
function Page:alt(line, book)
    if line.spot then LB.ShowOnMap(line, book) end
end

function Page:verb(line)
    return (line.item or line.kind == "npc" or line.kind == "object" or line.kind == "quest") and "Open"
        or line.kind == "place" and "Show on Map" or nil
end

function Page:altVerb(line)
    return (line.kind == "npc" or line.kind == "object") and line.spot and "Show on Map" or nil
end

-- A creature's, a chest's, a place's tooltip: its name, title, where
function Page:tip(line, book)
    if not (line.kind == "npc" or line.kind == "object" or line.kind == "place") then return false end
    book:PlaceTip()
    GameTooltip:SetText(line.plain or "")
    if line.sub then GameTooltip:AddLine("<" .. line.sub .. ">", 1, 1, 1) end
    if line.spot then GameTooltip:AddLine(LB.SpotText(line.spot), 1, 1, 1) end
    -- (with the mouse: a click on a place, a right-click on the others)
    local how = IF.Input.Pad() and (Glyph(line.kind == "place" and "A" or "X", 16) .. " ")
        or (line.kind == "place" and "Click: " or "Right-click: ")
    GameTooltip:AddLine(how .. "Show on Map", 0.6, 0.6, 0.6)
    GameTooltip:Show()
    return true
end

-- A page of the Wiki, for its own book or another's (the Journal's):
-- kind "item" (an id or a link), "npc", "object" or "quest"; nil: nothing
-- known of it
function LB.Page(kind, id)
    if not id then return nil end
    local p
    if kind == "quest" then
        p = { quest = id }
    elseif kind == "npc" or kind == "object" then
        p = { npc = kind == "npc" and id or nil, object = kind == "object" and id or nil }
    else
        local item = LB.ItemID(id)
        if not item then return nil end
        p = { id = item, link = type(id) == "string" and id or nil }
    end
    setmetatable(p, Page)
    Build(p)
    if p.quest and not p.questInfo or (p.npc or p.object) and not p.creature then return nil end
    p.tab = "notes"
    return p
end

---------------------------------------------------------------------------
-- The Wiki's book: opened from the bags, the loot window, any window of
-- the game's, the auction window (L2 / R2 between them: Book.lua)
---------------------------------------------------------------------------
-- (the auction window: ours, not in the game's row; it leaves L2 / R2 to
-- the Wiki while it's up)
local function AuctionBehind()
    local w = LB.origin == "auction" and IF.AuctionBuy and IF.AuctionBuy.window
    return w and w:IsShown() and w or nil
end

local book = BK.New({
    name = "ImprovedForeverWiki", title = "Wiki", portrait = "Interface\\Icons\\INV_Misc_Book_09",
    other = AuctionBehind,
    label = function(f) return f == AuctionBehind() and "Auction House" or nil end,
    onHide = function()
        if LB.origin == "auction" and BY and BY.Render then BY.Render() end
    end,
})
LB.book = book
-- (whose tooltips are the Wiki's: Wiki.lua's focus leaves them out)
LB.panel = book.panel

function LB.HasFocus() return book:HasFocus() end
function LB.IsShown() return book:IsShown() end
function LB.Render() book:Render() end
function LB.Close() book:Close() end
function LB.Back() book:Back() end
function LB.Behind() return book:Behind() end
function LB.OpenList(key) book:OpenList(key) end
function LB.Push(item) book:Push(LB.Page("item", item)) end
function LB.PushQuest(questID) book:Push(LB.Page("quest", questID)) end
-- kind: "npc" (a creature, a person) or "object" (a chest, a node)
function LB.PushCreature(kind, id) book:Push(LB.Page(kind, id)) end

-- focus: "wiki" or "window"
function LB.SetFocus(focus)
    book:SetFocus(focus == "wiki" and "ours" or "window")
end

-- Out of the way while the map is up (WikiMap.lua), its pages kept; back
-- once it's closed (in combat: gone)
function LB.Suspend() book:Suspend() end
function LB.Resume() book:Resume() end

-- item: an id or a link; origin: "bags", "loot", "ui", "auction" (where it's
-- opened from; "ui": LB.originFrame, Wiki.lua's)
function LB.Open(item, origin)
    if IF.InCombat() or not LB.ItemID(item) then return end
    LB.origin = origin
    book:Open(LB.Page("item", item),
        { dim = origin ~= "auction", extra = origin == "ui" and { LB.originFrame } or nil })
end
