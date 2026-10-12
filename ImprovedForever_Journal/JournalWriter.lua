-- The Journal written (Journal.lua keeps what happened): a day told in the
-- order it happened, in the words of someone who lives in this world (no
-- levels, experience or skill points: they wake, travel, fight, fall, earn
-- and spend). When they woke and lay down, the time of day as it turns, a
-- rest between: the realm's clock. Where a sentence can go more than one
-- way, the day picks (the same way each time it's read).
local IF = ImprovedForever

local J = IF.Journal
local BK = IF.Book

local Name, Names, Shorten, Plural, Coins = BK.Name, BK.Names, BK.Shorten, BK.Plural, BK.Coins

local REST = 3600              -- away this long between sessions: a rest, said
local STILL = 300              -- today's last session this recent: the day isn't over

---------------------------------------------------------------------------
-- Dates and times
---------------------------------------------------------------------------
-- "Monday, 12 October" (year: "12 October 2026")
function J.DayTitle(key, year)
    local t = J.KeyTime(key)
    if not t then return tostring(key) end
    if year then return tonumber(date("%d", t)) .. date(" %B %Y", t) end
    return date("%A, ", t) .. tonumber(date("%d", t)) .. date(" %B", t)
end

-- "October 2026"
function J.MonthTitle(key)
    local t = J.KeyTime(key)
    return t and date("%B %Y", t) or ""
end

-- 7800 -> "2h 10m"
function J.Played(seconds)
    local m = math.floor((seconds or 0) / 60)
    if m < 60 then return m .. "m" end
    return math.floor(m / 60) .. "h " .. (m % 60) .. "m"
end

-- A local time (epoch) on the realm's clock, minutes past midnight: by
-- how far apart the two clocks are now
local function RealmAt(t)
    local _, realm = J.Realm()
    local now = date("*t")
    local offset = realm - (now.hour * 60 + now.min)
    local at = date("*t", t)
    return (at.hour * 60 + at.min + offset) % 1440
end
J.RealmAt = RealmAt

local function Rm(e) return e.rm or RealmAt(e.t) end

-- A day's zones, the longest stayed first
function J.Zones(day)
    local names = {}
    for name in pairs(day.stats.zones or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b) return day.stats.zones[a] > day.stats.zones[b] end)
    return names
end

-- A day's events of these kinds, in order
function J.Events(day, ...)
    local want, out = {}, {}
    for i = 1, select("#", ...) do want[select(i, ...)] = true end
    for _, e in ipairs(day.events) do
        if want[e.k] then out[#out + 1] = e end
    end
    return out
end

-- A day in a line: "Westfall  ·  6 tasks  ·  47 slain"
-- How a day's growing is said under its title: "grew stronger", "grew
-- stronger twice"; nil: it didn't
function J.Grew(day)
    local n = #J.Events(day, "level")
    if n == 0 then return nil end
    return "grew stronger" .. (n == 2 and " twice" or n > 2 and (" " .. n .. " times") or "")
end

function J.DayLine(day)
    local s = day.stats
    return BK.Join({ J.Zones(day)[1], s.quests > 0 and Plural(s.quests, "task", "tasks") or nil,
        s.kills > 0 and (s.kills .. " slain") or nil, J.Grew(day) })
end

-- An elite, a rare, a boss, as someone who met one would say it
J.FEARSOME = { elite = "a fearsome brute", rareelite = "a rare and fearsome beast", rare = "a creature seldom seen",
    worldboss = "a terror of these lands" }

---------------------------------------------------------------------------
-- Words
---------------------------------------------------------------------------
-- One of several ways to say it, the same each time for the day
local function Pick(key, salt, options)
    local n = salt
    for i = 1, #key do n = n + key:byte(i) * i end
    return options[n % #options + 1]
end

-- A way of saying it the day hasn't used yet: each kind of phrase goes
-- round its words before any comes back (where it starts: the day's). The
-- turns are the page's, from the top (J.Write starts them anew)
local turns = {}
local function Vary(key, kind, options)
    local n = turns[kind]
    if not n then
        n = #kind
        for i = 1, #key do n = n + key:byte(i) * i end
    end
    n = n + 1
    turns[kind] = n
    return options[n % #options + 1]
end

local function Quest(name) return Name("“" .. (name or "a task") .. "”") end

-- An item's name, in its quality's ink
local Many                      -- (below: "Young Wolf" -> "Young Wolves")

local function ItemName(id, count)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, _, quality = get(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return "something"
    end
    local ink = BK.QUALITY_INK[quality or 1] or ""
    count = count or 1
    return (count > 1 and (count .. " ") or "") .. ink .. Many(name, count) .. "|r"
end

local TIMES = { [2] = "twice", [3] = "three times" }
local function Times(n) return n == 1 and "once" or TIMES[n] or (n .. " times") end

local NUMBERS = { "a", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "a dozen" }
local function Number(n) return NUMBERS[n] or tostring(n) end

-- "Young Wolf" -> "Young Wolves" (the last word, before any "of")
local SAME = { Vermin = true, Sheep = true, Deer = true, Fish = true, Kin = true, Meat = true, Cloth = true,
    Leather = true, Silk = true, Wool = true, Linen = true, Ore = true, Dust = true, Flesh = true, Blood = true,
    Ichor = true, Silt = true, Moss = true, Venom = true, Wood = true, Bread = true, Water = true, Milk = true,
    Cheese = true, Salt = true, Grain = true, Corn = true, Hay = true, Ash = true, Sand = true, Bark = true, Fur = true,
    Hair = true, Silver = true, Iron = true, Tin = true, Copper = true, Gold = true, Mithril = true, Thorium = true }
local IRREGULAR = { Wolf = "Wolves", Thief = "Thieves", Man = "Men", Woman = "Women", Elf = "Elves",
    Dwarf = "Dwarves", Mouse = "Mice", Wife = "Wives", Child = "Children", Foot = "Feet", Tooth = "Teeth" }
function Many(name, n)
    if n == 1 then return name end
    local head, tail = name:match("^(.-)( of .+)$")
    head, tail = head or name, tail or ""
    local start, last = head:match("^(.-)(%S+)$")
    if not last or SAME[last] or last:lower():match("fish$") or last:lower():match("sheep$") then return name end
    if IRREGULAR[last] then return start .. IRREGULAR[last] .. tail end
    if last:match("[^aeiouAEIOU]y$") then return start .. last:sub(1, -2) .. "ies" .. tail end
    if last:match("[sxz]$") or last:match("[cs]h$") then return start .. last .. "es" .. tail end
    return start .. last .. "s" .. tail
end

---------------------------------------------------------------------------
-- The time of day
---------------------------------------------------------------------------
local function Hour(rm) return math.floor(rm / 60) end

local function Part(rm)
    local h = Hour(rm)
    if h < 5 then return "night" elseif h < 12 then return "morning" elseif h < 17 then return "afternoon"
    elseif h < 21 then return "evening" end
    return "night"
end

-- A paragraph's start: the time of day if it has turned since the last
-- one, else a while later
local function When(key, salt, rm, before)
    local part, h = Part(rm), Hour(rm)
    if before and Part(before) == part then
        return Vary(key, "later", { "A while later, ", "After a short rest, ", "Later, ", "Some time after, ", "When I was ready, " })
    end
    if part == "morning" then return Vary(key, "morning", { "Later that morning, ", "Before noon, " }) end
    if part == "afternoon" then
        return h < 13 and "Toward noon, " or Vary(key, "afternoon", { "In the afternoon, ", "That afternoon, " })
    end
    if part == "evening" then return Vary(key, "evening", { "By evening, ", "As evening fell, " }) end
    return Vary(key, "night", { "Late that night, ", "Deep in the night, " })
end

local function Woke(key, rm)
    local h = Hour(rm)
    if h >= 4 and h < 7 then return "I was up before dawn" end
    if h >= 7 and h < 10 then return Pick(key, 25, { "I woke early", "I rose early" }) end
    if h >= 10 and h < 12 then return "I slept in; it was mid-morning by the time I stirred" end
    if h >= 12 and h < 17 then return "Half the day was gone before I woke" end
    if h >= 17 and h < 21 then return "I didn't stir until evening" end
    if h >= 21 then return "It was late in the evening when I set out" end
    return "Sleep wouldn't come, so I set out in the dead of night"
end

local function Again(rm)
    local part = Part(rm)
    return "I rested a while, and took up the road again "
        .. (part == "night" and "late at night" or ("in the " .. part)) .. "."
end

local function LayDown(key, rm, short)
    if short then return "I didn't stay out long; a few minutes, and I put the pen down." end
    local h = Hour(rm)
    if h < 5 then return "It was past midnight when I finally lay down." end
    if h >= 21 then return Pick(key, 26, { "Late in the evening I lay down to rest.", "I lay down late, tired." }) end
    if h >= 17 then return "I made camp as evening fell." end
    if h >= 12 then return "I put the pen down in the afternoon." end
    return "I put the pen down before noon."
end

---------------------------------------------------------------------------
-- What is worth telling: the day's highlights, in order. The rest (a
-- stray kill, coin, common finds, crafting) goes to the day's summary
---------------------------------------------------------------------------
local TOLD_MONEY = { sale = true, refund = true, letter = true, training = true }
local BIG = 10000              -- a merchant's or the mail's coin this much: told

local function Quality(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    return select(3, get(id)) or 1
end

local function Routine(e)
    local k = e.k
    if k == "create" or k == "skill" then return true end
    if k == "loot" then return Quality(e.item) < 3 end
    if k == "money" then return not TOLD_MONEY[e.src] and math.abs(e.amount) < BIG end
    return false
end

-- The money's lines: what it was for. first: the day's first thing
local function MoneySentence(key, e, first)
    local n = Name(Coins(math.abs(e.amount)))
    local gain = e.amount > 0
    if e.src == "sale" then
        local what = e.what and #e.what > 0 and Names(Shorten(e.what, 2)) or "wares"
        return (first and "Before anything else I went through my mail. " or "I went through my mail. ")
            .. "The auction house had sold my " .. what .. ", and " .. n .. " was waiting for me."
            .. (first and e.amount >= 10000 and " A good start." or "")
    elseif e.src == "refund" then
        return "Someone outbid me at the auction house; " .. n .. " came back to me by mail."
    elseif e.src == "letter" then
        return gain and ("A letter from " .. Name(e.from) .. " brought me " .. n .. ".")
            or ("I paid " .. n .. " for a parcel from " .. Name(e.from) .. ".")
    elseif e.src == "mail" then
        return gain and ("I collected " .. n .. " from my mail.") or ("I paid " .. n .. " on a parcel.")
    elseif e.src == "sell" then
        return Pick(key, 31, { "I sold my spoils to a merchant for ", "A merchant gave me " }) .. n
            .. Pick(key, 31, { ".", " for my spoils." })
    elseif e.src == "buy" then
        return gain and ("A merchant paid me " .. n .. ".") or ("I spent " .. n .. " at a merchant.")
    elseif e.src == "repair" then
        return "I paid " .. n .. " to have my gear mended."
    elseif e.src == "auction" then
        return gain and ("The auction house paid me " .. n .. ".") or ("I spent " .. n .. " at the auction house.")
    elseif e.src == "training" then
        return gain and ("I came by " .. n .. ".") or ("Lessons with my trainer cost me " .. n .. ".")
    end
    return gain and ("I came by " .. n .. ".") or ("I spent " .. n .. ".")
end

-- The foes of some hunts: { [name] = count }, their names (the most first),
-- how many, the place most of them fell
local function FoesOf(hunts)
    local foes, n, places = {}, 0, {}
    for _, h in ipairs(hunts) do
        n = n + (h.n or 0)
        for name, c in pairs(h.foes or {}) do foes[name] = (foes[name] or 0) + c end
        local p = h.sub or h.zone
        if p then places[p] = (places[p] or 0) + (h.n or 0) end
    end
    local names, place = {}, nil
    for name in pairs(foes) do names[#names + 1] = name end
    table.sort(names, function(a, b) return foes[a] > foes[b] end)
    for p, c in pairs(places) do
        if not place or c > places[place] then place = p end
    end
    return foes, names, n, place
end

-- "four Murloc Scouts and a Murloc Flesheater"
local function FoesWords(foes, names)
    local parts = {}
    for i = 1, math.min(2, #names) do parts[i] = Number(foes[names[i]]) .. " " .. Many(names[i], foes[names[i]]) end
    if #names > 2 then parts[#parts + 1] = "a few others" end
    return Names(parts)
end

-- The fights of a stretch, together: "I fought off four Murloc Scouts and
-- two Murloc Flesheaters", "Much of the afternoon went to fighting ..."
local function Fights(key, hunts, rm, here)
    local foes, n, places = {}, 0, {}
    for _, h in ipairs(hunts) do
        n = n + (h.n or 0)
        for name, c in pairs(h.foes or {}) do foes[name] = (foes[name] or 0) + c end
        local p = h.sub or h.zone
        if p then places[p] = (places[p] or 0) + (h.n or 0) end
    end
    if n == 0 then return nil end
    local names, place = {}, nil
    for name in pairs(foes) do names[#names + 1] = name end
    table.sort(names, function(a, b) return foes[a] > foes[b] end)
    for p, c in pairs(places) do
        if not place or c > places[place] then place = p end
    end
    local where = (place and place ~= here) and (" around " .. Name(place)) or ""
    if n <= 2 then
        local who = foes[names[1]] == 2 and ("a couple of " .. Many(names[1], 2))
            or Names({ BK.A_plain(names[1]), names[2] and BK.A_plain(names[2]) or nil })
        return "I had a brush with " .. who .. where .. "."
    end
    if n < 10 then
        local parts = {}
        for i = 1, math.min(2, #names) do parts[i] = Number(foes[names[i]]) .. " " .. Many(names[i], foes[names[i]]) end
        if #names > 2 then parts[#parts + 1] = "a few others" end
        return Pick(key, 51, { "I fought off ", "I cut down " }) .. Names(parts) .. where .. "."
    end
    local who = {}
    for i = 1, math.min(2, #names) do who[i] = Many(names[i], 2) end
    return "Much of the " .. Part(rm) .. " went to fighting " .. Names(who) .. where .. "; "
        .. Pick(key, 52, { n .. " of them fell to my blade.", "I lost count after " .. n .. "." })
end

-- The falls of a stretch, together
local function Deaths(key, list, here)
    local d = list[1]
    local place = d.sub or d.zone
    local where = (place and place ~= here) and ((d.sub and " near " or " in ") .. Name(place)) or ""
    local function who(name, named) return named and Name(name) or BK.A_(name) end
    if #list == 1 then
        -- (how I came back, when known: else a word on it)
        local after = d.revived == "player" and d.reviver and (Name(d.reviver) .. " brought me back.")
            or d.revived == "spirit" and "I woke at a spirit healer's side."
            or d.revived == "corpse" and Vary(key, "corpse", { "I made the long walk back to my body.",
                "I found my way back to my body and went on." })
            or Vary(key, "fell", { "Embarrassing.", "Not my finest hour.", "I'd rather not dwell on it.",
                "I picked myself up and went on." })
        return "I fell" .. where .. (d.by and (", " .. Pick(key, 39, { "cut down by ", "bested by " }) .. who(d.by, d.named)) or "")
            .. ". " .. after
    end
    local by, top = {}, nil
    for _, x in ipairs(list) do
        if x.by then
            by[x.by] = (by[x.by] or 0) + 1
            if not top or by[x.by] > by[top] then top = x.by end
        end
    end
    local named = false
    for _, x in ipairs(list) do if x.by == top then named = x.named end end
    return "I fell " .. Times(#list) .. where
        .. (top and (", " .. (by[top] == #list and "each time" or Times(by[top])) .. " at the hands of "
            .. (named and Name(top) or Many(top, by[top]))) or "")
        .. ". " .. Pick(key, 44, { "Not a day to be proud of.", "The spirit healers knew my face by then." })
end

local function Without(article)
    return (article:gsub("^[Tt]he ", ""):gsub("^[Aa]n? ", ""))
end

-- A sentence after a start ("That afternoon, at Lake Everstill, "): its
-- first word small, but "I"
local function Lead(lead, sentence)
    if not lead then return sentence end
    lead = lead:sub(1, 1):upper() .. lead:sub(2)
    if sentence:match("^I[ ']") or sentence:match("^|") then return lead .. sentence end
    return lead .. sentence:sub(1, 1):lower() .. sentence:sub(2)
end

local NUMBER_WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "a dozen" }

-- What a task asks, as someone would say it: "bring back ten Battleworn
-- Axes", "find the Lost Tools", "put down eight Murloc Scouts"
local function Goal(goal)
    local parts = {}
    for i = 1, math.min(2, #(goal or {})) do
        local what, how, need = goal[i][1], goal[i][2], goal[i][3] or 1
        if what then
            local many = need > 1 and ((NUMBER_WORDS[need] or need) .. " " .. Many(what, need))
            if how == "item" then
                parts[#parts + 1] = many and ("bring back " .. many) or ("find the " .. Without(what))
            elseif how == "monster" then
                parts[#parts + 1] = "put down " .. (many or BK.A_plain(what))
            else
                parts[#parts + 1] = (what:sub(1, 1):lower() .. what:sub(2)):gsub("[%.%s]+$", "")
            end
        end
    end
    return #parts > 0 and Names(parts) or nil
end

-- A task by who gave it: "Dockmaster Baren's “Selling Fish”"
-- A name said again: without its nickname (Remy "Two Times" -> Remy)
local function Short(name)
    local short = name:gsub('%s*["“].-["”]', "")
    return short ~= "" and short or name
end

local function QuestOf(e)
    if not e.giver then return Quest(e.name) end
    return Name(Short(e.giver)) .. "'s " .. Quest(e.name)
end

-- "a Medium Armor Kit" (in its quality's ink)
local function AnItem(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name = get(id)
    if not name then return ItemName(id) end
    return ((name:match("^[AEIOUaeiou]") and "an ") or "a ") .. ItemName(id)
end

-- How far it is from where the last thing happened: "here" (a few steps),
-- "near", "far" (or another map); nil: not known
local function Moved(ctx, e)
    local a = ctx.pos
    if not (a and e and e.x and a.x) then return nil end
    if a.map ~= e.map then return "far" end
    local d = math.sqrt((a.x - e.x) ^ 2 + (a.y - e.y) ^ 2)
    return d > 0.08 and "far" or d > 0.02 and "near" or "here"
end

-- A task named after the one it's carried to ("Eagan Peltskinner"): no
-- need to say it twice
local function NamedFor(quest, person)
    return quest and person and quest:lower() == person:lower()
end

-- Growing stronger, each class its own way
local GROWING = {
    WARRIOR = "my sword arm felt surer, my breath steadier", PALADIN = "the Light burned brighter within me",
    HUNTER = "my aim grew truer, my eyes sharper", ROGUE = "my hands felt quicker, my steps quieter",
    PRIEST = "the Light answered me more readily", SHAMAN = "the spirits spoke louder to me",
    MAGE = "the arcane came easier to my fingers", WARLOCK = "the shadows bent more willingly to my will",
    DRUID = "the wild stirred stronger in me",
}
-- A new standing with a people, as they'd see it
local STANDINGS = {
    Hated = "had come to hate me", Hostile = "had turned against me", Unfriendly = "had grown wary of me",
    Neutral = "no longer distrusted me", Friendly = "had come to think of me as a friend",
    Honored = "held me in honor now", Revered = "revered me", Exalted = "counted me as one of their own",
}
-- What growing this strong means
local MILESTONES = {
    [10] = "I was no longer the green recruit I had been", [20] = "These lands no longer felt new to me",
    [40] = "Perhaps it was time to think of a mount of my own",
    [60] = "I had grown as strong as anyone I knew; little now could stand against me",
}

-- A run of the same things (taken on, seen through, new lands...): one sentence
local RUNS = { accept = true, quest = true, loot = true, zone = true, discover = true, equip = true }

local function Sentence(key, list, i, ctx)
    local e = list[i]
    local k = e.k
    if RUNS[k] then
        local run, j = {}, i
        while list[j] and list[j].k == k do
            run[#run + 1] = list[j]
            j = j + 1
        end
        ctx.skip = #run - 1
        local names = {}
        if k == "accept" then
            -- (one giver, several tasks: together)
            local same = #run > 1
            for _, r in ipairs(run) do same = same and r.giver ~= nil and r.giver == run[1].giver end
            if same then
                for n, r in ipairs(run) do names[n] = Quest(r.name) end
                ctx.npc, ctx.met[run[1].giver] = run[1].giver, true
                return Name(run[1].giver) .. " had more than one task for me: " .. Names(Shorten(names, 3)) .. "."
            end
            -- (a message to carry: taken from one, handed straight to another)
            local handed, between = list[i + 1], 0
            if handed and handed.k == "ready" and handed.id == run[1].id then handed, between = list[i + 2], 1 end
            if #run == 1 and handed and handed.k == "quest" and handed.id == run[1].id and run[1].giver
                and handed.ender and handed.ender ~= run[1].giver then
                -- (where I took it: the place it was carried from)
                ctx.errand, ctx.skip, ctx.posFrom = handed, between, run[1]
                local giver, ender = run[1].giver, handed.ender
                local carry = NamedFor(run[1].name, ender) and ("to find " .. Name(ender))
                    or ("to " .. Name(ender) .. " with " .. Quest(run[1].name))
                local said
                if giver == ctx.npc then
                    said = Name(giver) .. " then sent me " .. carry .. "."
                elseif ctx.met[giver] then
                    said = "I went back to " .. Name(giver) .. ", who sent me "
                        .. (carry:match("^to find ") and carry or ("on " .. carry)) .. "."
                else
                    said = Name(giver) .. Vary(key, "send", { " sent me ", " asked me to go ", " needed someone to go " }) .. carry .. "."
                end
                ctx.met[giver], ctx.npc = true, giver
                return said
            end
            local out = {}
            for n, r in ipairs(run) do
                local goal, q = Goal(r.goal), Quest(r.name)
                local said
                if r.giver and r.giver ~= ctx.npc and ctx.met[r.giver] then
                    -- (one met before today, somewhere else: back to them)
                    said = "I went back to " .. Name(r.giver) .. ", who "
                        .. (goal and ("asked me to " .. goal .. ", for " .. q) or ("had another task for me: " .. q)) .. "."
                elseif r.giver and r.giver ~= ctx.npc and Moved(ctx, r) == "far" then
                    said = Vary(key, "over", { "I headed over to ", "I made my way to ", "I walked over to ", "I sought out " })
                        .. Name(r.giver) .. ", who "
                        .. (goal and ("needed help with " .. q .. ": to " .. goal) or ("asked for my help with " .. q)) .. "."
                elseif r.giver and r.giver == ctx.npc then
                    -- (the one just spoken of: no meeting them again)
                    said = Name(r.giver) .. Vary(key, "another", { " had another task for me: ", " asked something more of me: ",
                        " still had work for me: ", " had more work for me: " })
                        .. q .. (goal and (", to " .. goal) or "") .. "."
                elseif r.giver and goal then
                    said = Vary(key, "ask", { Name(r.giver) .. " asked me to " .. goal .. ", for " .. q .. ".",
                        "I met " .. Name(r.giver) .. ", who needed help with " .. q .. ": to " .. goal .. ".",
                        Name(r.giver) .. " needed someone to " .. goal .. ", for " .. q .. ".",
                        Name(r.giver) .. " was looking for help with " .. q .. ": to " .. goal .. "." })
                elseif r.giver then
                    said = Name(r.giver) .. " asked for my help with " .. q .. "."
                elseif goal then
                    said = "I took on " .. q .. ", to " .. goal .. "."
                else
                    said = "I took on " .. q .. "."
                end
                -- (another task taken on the spot: someone nearby)
                local by = n > 1 and Moved({ pos = run[n - 1] }, r)
                out[n] = n > 1 and Lead((by == "here" or by == nil) and "nearby, " or "then ", said) or said
                ctx.npc = r.giver
                if r.giver then ctx.met[r.giver] = true end
            end
            return table.concat(out, " ")
        elseif k == "quest" then
            -- (to one, several tasks: together)
            local same = #run > 1
            for _, r in ipairs(run) do same = same and r.ender ~= nil and r.ender == run[1].ender end
            local function thanks(list)
                local gifts, paid = {}, 0
                for _, r in ipairs(list) do
                    if r.reward then gifts[#gifts + 1] = AnItem(r.reward) end
                    paid = paid + (r.money or 0)
                end
                if paid > 0 then gifts[#gifts + 1] = Name(Coins(paid)) end
                return #gifts > 0 and Names(gifts) or nil
            end
            -- (to different people: one at a time, each its own sentence)
            if not same and #run > 1 then
                run = { run[1] }
                ctx.skip = 0
            end
            for n, r in ipairs(run) do names[n] = Quest(r.name) end
            local gift = thanks(run)
            local ender = run[1].ender
            if ender then
                -- (who then gave me more: in the same breath)
                local more, j = {}, i + #run
                while list[j] and list[j].k == "accept" and list[j].giver == ender do
                    more[#more + 1] = list[j]
                    j = j + 1
                end
                ctx.skip = ctx.skip + #more
                local moved = Moved(ctx, run[1])
                local metBefore = ctx.met[ender]
                ctx.npc, ctx.met[ender] = ender, true
                for _, r in ipairs(more) do ctx.met[r.giver] = true end
                local next = ""
                local also = (ctx.gaves or 0) > 0 and "also " or ""
                if #more > 0 then ctx.gaves = (ctx.gaves or 0) + 1 end
                if #more == 1 then
                    local goal = Goal(more[1].goal)
                    next = ", then " .. also .. Vary(key, "more", { "gave me another task: ", "had more work for me: ",
                        "asked one more thing of me: ", "set me to a new task: " }) .. Quest(more[1].name) .. (goal and (", to " .. goal) or "")
                elseif #more > 1 then
                    local tasks = {}
                    for n, r in ipairs(more) do tasks[n] = Quest(r.name) end
                    next = ", then " .. also .. Vary(key, "moreMany", { "asked more of me: ", "had several more tasks for me: " })
                        .. Names(Shorten(tasks, 3))
                end
                local thanked = (gift and format(Vary(key, "gift", { "thanked me with %s", "rewarded me with %s",
                        "pressed %s into my hands", "handed me %s for my trouble", "gave me %s in thanks", "saw me paid with %s" }), gift)
                    or Vary(key, "thanks", { "thanked me", "was glad of it", "thanked me warmly", "seemed relieved",
                        "gave me a grateful nod", "was pleased to see it done", "clasped my hand in thanks" }))
                    .. next .. "."
                -- (the errand's end: the one it was carried to)
                if ctx.errand == run[1] then
                    ctx.errand = nil
                    local sub = run[1].sub
                    if moved == "far" then
                        return Vary(key, "find", { "I made my way to ", "I set off to find ", "I sought out ", "I tracked down " })
                            .. Name(ender)
                            .. ((sub and sub ~= ctx.place) and (" at " .. Name(sub)) or "") .. ", who " .. thanked
                    end
                    ctx.noJoin = true
                    return Vary(key, "handed", { "When I handed it over, ", "When I passed it on, ", "As soon as I delivered it, ",
                        "Once I'd delivered it, " }) .. Name(ender) .. " " .. thanked
                end
                -- (back to the one who gave it, or to someone else)
                local back = (run[1].giver == nil or run[1].giver == ender) and " back to " or " to "
                if metBefore and moved == "far" and back == " back to " then
                    return "I went back to " .. Name(ender) .. " with " .. Names(Shorten(names, 3)) .. ", and "
                        .. Name(Short(ender)) .. " " .. thanked
                end
                ctx.handins = (ctx.handins or 0) + 1
                local verb = Vary(key, "bring", { "I brought ", "I took ", "I delivered ", "I carried ", "I returned " })
                if verb == "I returned " then back = " to " end
                return verb .. Names(Shorten(names, 3)) .. back .. Name(ender) .. ", who " .. thanked
            end
            return Pick(key, 33, { "I saw ", "I finished " }) .. Names(Shorten(names, 3)) .. Pick(key, 33, { " through", "" })
                .. (gift and (", and was rewarded with " .. gift) or "") .. "."
        elseif k == "loot" then
            for n, r in ipairs(run) do names[n] = ItemName(r.item, r.count) end
            return Pick(key, 34, { "Luck was with me: I found ", "A rare find came my way: " }) .. Names(Shorten(names, 3)) .. "."
        elseif k == "equip" then
            -- (a reward put on straight away)
            local prev = list[i - 1]
            local fromMail = false
            for _, p in ipairs(prev and prev.k == "post" and prev.parts or {}) do
                for _, it in ipairs(p.items or {}) do if it[1] == run[1].item then fromMail = true end end
            end
            if #run == 1 and prev and prev.k == "quest" and prev.reward == run[1].item then
                return Vary(key, "wear", { "I put it on at once.", "I wasted no time putting it on." })
            end
            if #run == 1 and fromMail then
                return "I put the " .. ItemName(run[1].item) .. " on at once."
            end
            for n, r in ipairs(run) do names[n] = ItemName(r.item) end
            return Vary(key, "newGear", { "I put on my new ", "I changed into my new " }) .. Names(Shorten(names, 3)) .. "."
        elseif k == "discover" then
            -- (the place I'm in, named already: not news)
            for _, r in ipairs(run) do
                if r.name ~= ctx.zone and r.name ~= ctx.place then names[#names + 1] = r.name end
            end
            if #names == 0 then return nil end
            return Pick(key, 36, { "I came upon ", "For the first time I saw ", "I found my way to " })
                .. Names(Shorten(names, 3)) .. "."
        elseif k == "zone" then
            -- (the land I'm in already, or just flown to: said)
            for _, r in ipairs(run) do
                if r.name ~= ctx.zone then names[#names + 1] = r.name end
            end
            if #names == 0 then return nil end
            ctx.zone, ctx.place = names[#names], names[#names]
            if #names == 1 then return Pick(key, 37, { "I made my way to ", "My road led to " }) .. Name(names[1]) .. "." end
            local last = table.remove(names)
            return "I passed through " .. Names(Shorten(names, 2)) .. " and came to " .. Name(last) .. "."
        end
    end
    if k == "fights" then
        local said = Fights(key, e.hunts, e.rm, ctx.place)
        ctx.place = select(4, FoesOf(e.hunts)) or ctx.place
        return said
    end
    if k == "deaths" then
        local said = Deaths(key, e.deaths, ctx.place)
        ctx.place = e.deaths[1].sub or e.deaths[1].zone or ctx.place
        return said
    end
    if k == "kill" then
        return Pick(key, 38, { "I also bested ", "I stood my ground against " }) .. Name(e.name) .. ", "
            .. (J.FEARSOME[e.class] or "a fearsome brute") .. "."
    end
    if k == "effort" then
        local g = e.goal
        local q = QuestOf(g)
        local said
        if e.by.k == "dive" then
            local place = e.by.sub or e.by.zone
            said = "I swam down into the depths" .. ((place and place ~= ctx.place) and (" of " .. Name(place)) or "")
                .. " and found the " .. Without(g.what) .. " for " .. q .. "."
            ctx.place = place or ctx.place
        else
            local foes, names, _, place = FoesOf(e.by.hunts)
            local where = (place and place ~= ctx.place) and (" around " .. Name(place)) or ""
            ctx.place = place or ctx.place
            said = Vary(key, "fight", { "I cut down ", "I fought ", "I hunted down ", "I put down " }) .. FoesWords(foes, names) .. where
                .. (g.how == "item" and (" to gather " .. Many(g.what, 2)) or "") .. " for " .. q .. "."
        end
        if e.deaths then
            local n = #e.deaths.deaths
            said = said .. " I fell " .. Times(n) .. " along the way, but managed it in the end."
        elseif g.k == "ready" and e.by.k ~= "dive" then
            said = said .. " " .. Vary(key, "gathered", { "Before long I had all I needed.", "It took a while, but I had what I came for.",
                "Soon enough, I had what was asked.", "In time, the work was done." })
        elseif g.k == "objective" then
            said = said .. " That part of the work was done."
        end
        return said
    end
    if k == "ready" then
        -- (handed in right after: said then)
        local nxt = list[i + 1]
        if nxt and nxt.k == "quest" and nxt.id == e.id then return nil end
        local q = QuestOf(e)
        local done = Vary(key, "report", { "; all that was left was to report back.", ", and I had only to report back.",
            "; now to report back.", ", and it was time to head back." })
        if e.what and e.how == "item" then
            return "With the " .. Many(Without(e.what), e.need or 1) .. " in hand, " .. q .. " was done" .. done
        end
        if e.what and e.how == "monster" then return "With enough " .. Many(e.what, 2) .. " dealt with, " .. q .. " was done" .. done end
        return "That settled " .. q .. done
    end
    if k == "objective" then
        if e.what and e.how == "item" then
            return "I had the " .. Many(Without(e.what), e.need or 1) .. " " .. Quest(e.name) .. " called for."
        end
        if e.what and e.how == "monster" then return "I had dealt with enough " .. Many(e.what, 2) .. " for " .. Quest(e.name) .. "." end
        return "Part of " .. Quest(e.name) .. " was done."
    end
    if k == "dive" then
        local place = e.sub or e.zone
        if place and place ~= ctx.place then
            ctx.place = place
            return Pick(key, 45, { "I dove deep into ", "I swam down into the depths of " }) .. Name(place) .. "."
        end
        return Pick(key, 45, { "I dove deep beneath the water.", "I swam down into the depths." })
    end
    if k == "level" then
        -- Growing stronger: what brought it on, how it felt (the class's
        -- own way), what it means at a milestone
        ctx.levels = (ctx.levels or 0) + 1
        if ctx.levels > 2 then return "And again; the road was making me stronger by the hour." end
        local feel = GROWING[e.class or select(2, UnitClass("player")) or ""] or "I was stronger than I had been"
        local prev = list[i - 1]
        local opener
        if ctx.levels == 2 then
            opener = "Before the day was out, I felt it again: "
        elseif prev and (prev.k == "effort" or prev.k == "fights" or prev.k == "deaths") then
            opener = "Somewhere in that fight, something in me changed: "
        elseif prev and (prev.k == "quest" or prev.k == "accept") then
            opener = Vary(key, "justThen", { "Just then, I felt it: ", "In that moment, I felt it: " })
        elseif prev and (prev.k == "discover" or prev.k == "dive" or prev.k == "zone") and (prev.sub or prev.name) then
            opener = "Standing in " .. Name(prev.k == "zone" and prev.name or prev.sub or prev.name) .. ", I felt it: "
        else
            opener = "I felt a change come over me: "
        end
        local said = ctx.levels == 2 and "Before the day was out, I felt it again, stronger still." or (opener .. feel .. ".")
        local level = tonumber(e.level)
        local milestone = level and MILESTONES[level]
        local lessons = level and level % 2 == 0
        if milestone and lessons then
            said = said .. " " .. milestone .. ", and my trainer would have new lessons waiting."
        elseif milestone then
            said = said .. " " .. milestone .. "."
        elseif lessons then
            said = said .. " My trainer would have new lessons waiting."
        end
        return said
    end
    if k == "post" then
        -- A visit to the mailbox: what each letter held, what I sent
        local clauses, letters, order, sent, gained = {}, {}, {}, {}, 0
        local function letter(from)
            if not letters[from] then
                letters[from] = { items = {}, money = 0 }
                order[#order + 1] = from
            end
            return letters[from]
        end
        -- (items in words: "5 Red Linen Bags", "a Short Bastard Sword")
        local function words(list)
            local names = {}
            for n, it in ipairs(list or {}) do names[n] = (it[2] or 1) > 1 and ItemName(it[1], it[2]) or AnItem(it[1]) end
            return names
        end
        local function items(list) return Names(Shorten(words(list), 3)) end
        for _, p in ipairs(e.parts) do
            if p.k == "money" then
                gained = gained + math.max(0, p.amount)
                local n = Name(Coins(math.abs(p.amount)))
                if p.src == "sale" then
                    clauses[#clauses + 1] = "the auction house had sold my "
                        .. (p.what and #p.what > 0 and Names(Shorten(p.what, 2)) or "wares") .. " for " .. n
                elseif p.src == "refund" then
                    clauses[#clauses + 1] = n .. " came back from an auction I'd been outbid on"
                elseif p.src == "letter" and p.from and p.amount > 0 then
                    local l = letter(p.from)
                    l.money = l.money + p.amount
                else
                    clauses[#clauses + 1] = p.amount > 0 and (n .. " was waiting for me") or ("I paid " .. n .. " on a parcel")
                end
            elseif p.k == "mail" then
                if p.kind == "won" then
                    clauses[#clauses + 1] = "the " .. items(p.items) .. " I'd won at auction had arrived"
                elseif p.kind == "expired" or p.kind == "removed" then
                    clauses[#clauses + 1] = "my " .. items(p.items) .. " came back from the auction house unsold"
                else
                    local l = letter(p.from or "someone")
                    for _, it in ipairs(p.items or {}) do
                        -- (the same item in several letters: counted together)
                        local same
                        for _, have in ipairs(l.items) do if have[1] == it[1] then same = have end end
                        if same then same[2] = (same[2] or 1) + (it[2] or 1) else l.items[#l.items + 1] = { it[1], it[2] or 1 } end
                    end
                end
            elseif p.k == "sent" then
                sent[#sent + 1] = p
            end
        end
        for _, from in ipairs(order) do
            local l = letters[from]
            local gifts = words(l.items)
            if l.money > 0 then gifts[#gifts + 1] = Name(Coins(l.money)) end
            gifts = Shorten(gifts, 4)
            if #gifts > 0 then clauses[#clauses + 1] = (from == "someone" and "someone" or Name(from)) .. " had sent me " .. Names(gifts) end
        end
        local out = {}
        if #clauses > 0 then
            local joined = #clauses == 1 and clauses[1]
                or (table.concat(clauses, "; ", 1, #clauses - 1) .. "; and " .. clauses[#clauses])
            ctx.noJoin = ctx.first or nil
            out[1] = (ctx.first and "Before anything else I went through my mail: "
                or Vary(key, "mail", { "I went through my mail: ", "I checked my mail: " })) .. joined .. "."
            if ctx.first and gained >= 10000 then out[#out + 1] = "A good start." end
        end
        for _, p in ipairs(sent) do
            local what = {}
            what = words(p.items)
            if p.money then what[#what + 1] = Name(Coins(p.money)) end
            out[#out + 1] = "I sent " .. Name(p.to or "a friend") .. (#what > 0 and (" " .. Names(what)) or " a letter") .. "."
        end
        return #out > 0 and table.concat(out, " ") or nil
    end
    if k == "lesson" then
        local spells, recipes = {}, {}
        for _, l in ipairs(e.learns) do
            -- (a spell's link in the chat's line: its name)
            local name = tostring(l.name):match("%[(.-)%]") or tostring(l.name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if l.recipe then recipes[#recipes + 1] = Many(name, 2) else spells[#spells + 1] = name end
        end
        local taught = {}
        if #spells > 0 then taught[#taught + 1] = Names(Shorten(spells, 3)) end
        if #recipes > 0 then taught[#taught + 1] = "to make " .. Names(Shorten(recipes, 3)) end
        local what = table.concat(taught, ", and ")
        local cost = e.cost and (" for " .. Name(Coins(e.cost))) or ""
        if e.trainer then
            ctx.npc = e.trainer
            return Vary(key, "trainer", { "I sought out ", "I went to see ", "I paid a visit to " }) .. Name(e.trainer)
                .. ", who taught me " .. what .. cost .. "."
        end
        return "I learned " .. what .. cost .. "."
    end
    if k == "bind" then
        return (e.inn and "I took a room at the inn and made " or "I made ") .. Name(e.to or "this place") .. " my home."
    end
    if k == "flightpath" then
        local place = e.sub or e.zone
        return (place and ("At " .. Name(place) .. ", the") or "The") .. " flight master agreed to carry me from then on."
    end
    if k == "party" then
        local m = e.members or {}
        if #m == 0 then return nil end
        if #m > 3 then return "I fell in with a band of " .. (NUMBER_WORDS[#m] or #m) .. ", " .. Name(m[1]) .. " among them." end
        local named = {}
        for n, name in ipairs(m) do named[n] = Name(name) end
        return Vary(key, "party", { "I fell in with ", "I joined up with " }) .. Names(named) .. "."
    end
    if k == "alone" then return Vary(key, "alone", { "We went our separate ways.", "After that, I went on alone." }) end
    if k == "duel" then
        local foe = Name(e.opponent or "someone")
        if e.fled then return e.won and (foe .. " fled from our duel.") or ("I yielded our duel to " .. foe .. ".") end
        return e.won and ("I bested " .. foe .. " in a duel.") or (foe .. " bested me in a duel.")
    end
    if k == "standing" then
        local said = STANDINGS[e.standing]
        return said and (Name(e.faction or "They") .. " " .. said .. ".") or nil
    end
    if k == "abandon" then
        return Vary(key, "abandon", { "I gave up on ", "I put aside " }) .. Quest(e.name) .. "."
    end
    if k == "instance" then return "I ventured into " .. Name(e.name) .. "." end
    if k == "hearth" then
        if e.to then ctx.zone = nil end
        return "My hearthstone carried me back" .. (e.to and (" to " .. Name(e.to)) or "") .. "."
    end
    if k == "flight" then
        if e.to then ctx.zone = e.to end
        local fare = ctx.fare[e]
        return "I flew " .. (e.from and ("from " .. Name(e.from) .. " ") or "") .. "to " .. Name(e.to or "somewhere")
            .. (fare and (", for " .. Name(Coins(fare))) or "") .. "."
    end
    if k == "money" then return MoneySentence(key, e, ctx.first) end
end

---------------------------------------------------------------------------
-- A day: when I woke and where; then a paragraph a stretch of doing
-- something somewhere (a break in it, another land or a new session starts
-- the next); the day's summary; when I lay down
---------------------------------------------------------------------------
local BREAK = 900              -- nothing for this long: a break, a new paragraph
local AWAY = 0.1               -- this far from the last thing done (map width): another paragraph
local LONG = 5                 -- sentences: past this, a new paragraph where I move on
-- What joins a sentence to the one before (not every one: "" none)
local CONNECTORS = { "Then ", "After that, ", "", "Next, ", "" }
-- What takes me away from the one I was talking to
local LEAVES = { effort = true, fights = true, deaths = true, dive = true, flight = true, hearth = true, zone = true,
    instance = true, discover = true, duel = true }
-- Money the mail brought (told with the visit to the mailbox)
-- (plain "mail": money while the mailbox seemed open, no letter matched to
-- it; a guess, not told as the mail's)
local MAIL_MONEY = { sale = true, refund = true, letter = true }
local CONNECTS = { accept = true, quest = true, effort = true, dive = true, fights = true, flight = true, hearth = true,
    zone = true, discover = true, instance = true, ready = true, money = true, lesson = true, bind = true, party = true,
    duel = true, flightpath = true, post = true }

local function Sessions(day)
    local list = {}
    for _, s in ipairs(day.sessions or {}) do list[#list + 1] = s end
    -- (what was kept before sessions were: a stretch of its own)
    local first = day.events[1]
    if first and (not list[1] or first.t < list[1].from - 30) then
        local last = day.events[#day.events]
        local upto = list[1] and list[1].from - 1 or last.t
        table.insert(list, 1, { from = first.t, rfrom = Rm(first), to = upto, rto = RealmAt(upto) })
    end
    return list
end

-- The stretches: { session, rest (a rest before it), events }
local function Episodes(day, sessions)
    local out, e = {}, 1
    local events = day.events
    for n, s in ipairs(sessions) do
        local upto = sessions[n + 1] and sessions[n + 1].from - 30 or math.huge
        local cur
        while events[e] and events[e].t < upto do
            local ev = events[e]
            local place = ev.zone or ev.name
            -- (a long way from the last thing done: somewhere else, another paragraph)
            local far = cur and cur.pos and ev.x and (cur.pos.map ~= ev.map
                or math.sqrt((cur.pos.x - ev.x) ^ 2 + (cur.pos.y - ev.y) ^ 2) > AWAY)
            if not cur or ev.t - cur.last > BREAK or (ev.k == "zone" and ev.name ~= cur.zone) or far then
                cur = { session = n, rest = not cur and n > 1 and s.from - sessions[n - 1].to > REST,
                    events = {}, zone = place }
                out[#out + 1] = cur
            end
            cur.events[#cur.events + 1] = ev
            cur.last = ev.t
            if ev.x then cur.pos = ev end
            if ev.k == "zone" or ev.k == "flight" then cur.zone = ev.to or ev.name or cur.zone end
            e = e + 1
        end
    end
    return out
end

-- A stretch's main place: its most named area, else its land
local function MainPlace(ep)
    local count, best = {}, nil
    for _, ev in ipairs(ep.events) do
        local p = ev.sub or ev.zone
        if p and ev.k ~= "zone" and ev.k ~= "flight" and ev.k ~= "hearth" then
            count[p] = (count[p] or 0) + 1
            if not best or count[p] > count[best] then best = p end
        end
    end
    return best or ep.zone
end

-- What a stretch tells, in order: its highlights, its fights and falls as
-- one each (where the first was), the fare said with its flight
local function Told(ep, ctx)
    local list, told, hunts, deaths = ep.events, {}, {}, {}
    for i, ev in ipairs(list) do
        if ev.k == "flight" then
            for _, j in ipairs({ i - 1, i + 1 }) do
                local m = list[j]
                if m and m.k == "money" and m.src == "flight" then
                    ctx.fare[ev] = -m.amount
                    break
                end
            end
        elseif ev.k == "hunt" then hunts[#hunts + 1] = ev
        elseif ev.k == "death" then deaths[#deaths + 1] = ev end
    end
    for _, ev in ipairs(list) do
        if ev.k == "hunt" then
            if ev == hunts[1] then told[#told + 1] = { k = "fights", hunts = hunts, t = ev.t, rm = Rm(ev) } end
        elseif ev.k == "death" then
            if ev == deaths[1] then told[#told + 1] = { k = "deaths", deaths = deaths, t = ev.t, rm = Rm(ev) } end
        elseif J.QUIET[ev.k] then
            -- (kept, not told)
        elseif ev.k == "mail" or ev.k == "sent" or ev.k == "money" and MAIL_MONEY[ev.src] then
            -- (one visit to the mailbox: one telling)
            local last = told[#told]
            -- (gear put on between letters: still the same visit)
            if last and last.k == "equip" and told[#told - 1] and told[#told - 1].k == "post" then last = told[#told - 1] end
            if last and last.k == "post" and ev.t - last.last < 600 then
                last.parts[#last.parts + 1] = ev
                last.last = ev.t
            else
                told[#told + 1] = { k = "post", parts = { ev }, t = ev.t, last = ev.t, rm = Rm(ev), x = ev.x, y = ev.y,
                    map = ev.map }
            end
        elseif ev.k == "learn" then
            -- (learned one after another, from one trainer or none: one lesson)
            local last = told[#told]
            if last and last.k == "lesson" and last.trainer == ev.trainer then
                last.learns[#last.learns + 1] = ev
            else
                local lesson = { k = "lesson", learns = { ev }, trainer = ev.trainer, t = ev.t, rm = Rm(ev), x = ev.x,
                    y = ev.y, map = ev.map }
                -- (its fee, paid just before)
                local fee = told[#told]
                if fee and fee.k == "money" and fee.src == "training" and fee.amount < 0 then
                    lesson.cost = -fee.amount
                    told[#told] = nil
                end
                told[#told + 1] = lesson
            end
        elseif ev.k == "money" and ev.src == "training" and told[#told] and told[#told].k == "lesson" then
            told[#told].cost = (told[#told].cost or 0) - ev.amount
        elseif not Routine(ev) and not (ev.k == "money" and ev.src == "flight") then
            told[#told + 1] = ev
        end
    end
    -- Fights (and the falls in them), a dive, then a task's objective done:
    -- one effort, what it was for
    -- (growing stronger as a task is handed in: the game says so first; told
    -- after it)
    for k = #told - 1, 2, -1 do
        -- (reported after the hand-in, before the next task the same one gave:
        -- after that task)
        local q = told[k - 1]
        if told[k].k == "level" and q.k == "quest" and q.ender then
            local last = k
            while told[last + 1] and told[last + 1].k == "accept" and told[last + 1].giver == q.ender do last = last + 1 end
            if last > k then table.insert(told, last, table.remove(told, k)) end
        end
    end
    for k = #told - 1, 1, -1 do
        if told[k].k == "level" then
            -- (the hand-in a moment after it, a task's end between perhaps)
            for m = k + 1, math.min(k + 2, #told) do
                local b = told[m]
                if b.k == "quest" and (b.t or 0) - (told[k].t or 0) <= 5 then
                    -- (after the tasks the same one gave next, too: one moment)
                    local last = m
                    while told[last + 1] and told[last + 1].k == "accept" and b.ender and told[last + 1].giver == b.ender do
                        last = last + 1
                    end
                    table.insert(told, last, table.remove(told, k))
                    break
                end
            end
        end
    end
    local merged, i = {}, 1
    while told[i] do
        local a, j = told[i], i + 1
        local deaths, grew
        if a.k == "fights" and told[j] and told[j].k == "deaths" then deaths, j = told[j], j + 1 end
        -- (stronger in the middle of it: told after the effort)
        if a.k == "fights" and told[j] and told[j].k == "level" then grew, j = told[j], j + 1 end
        local g = told[j]
        if (a.k == "fights" or a.k == "dive") and g and (g.k == "ready" or g.k == "objective") and g.what
            and (g.how == "item" or g.how == "monster" and a.k == "fights") then
            merged[#merged + 1] = { k = "effort", by = a, deaths = deaths, goal = g, t = a.t, rm = a.rm or Rm(a) }
            if grew then merged[#merged + 1] = grew end
            i = j + 1
        elseif grew then
            -- (no goal after it: as it was)
            merged[#merged + 1] = a
            i = i + 1
        else
            merged[#merged + 1] = a
            i = i + 1
        end
    end
    -- (a stray kill or two, for nothing: not a story, the summary's)
    local n = 0
    for _, h in ipairs(hunts) do n = n + (h.n or 0) end
    if n > 0 and n < 3 then
        for k = #merged, 1, -1 do
            if merged[k].k == "fights" then
                table.remove(merged, k)
                ctx.stray = ctx.stray + n
            end
        end
    end
    return merged
end

-- A skill as someone would say it: "with daggers", "at Tailoring"
local WEAPONS = { Daggers = "daggers", Swords = "swords", Axes = "axes", Maces = "maces", Staves = "a staff",
    Bows = "a bow", Guns = "guns", Crossbows = "a crossbow", Thrown = "thrown weapons", Unarmed = "my fists",
    Polearms = "polearms", ["Fist Weapons"] = "fist weapons", Wands = "a wand",
    ["Two-Handed Swords"] = "great swords", ["Two-Handed Axes"] = "great axes", ["Two-Handed Maces"] = "great maces" }
local function Skills(names)
    local with, at, guard = {}, {}, false
    for _, n in ipairs(names) do
        if n == "Defense" then guard = true
        elseif WEAPONS[n] then with[#with + 1] = WEAPONS[n] else at[#at + 1] = n end
    end
    local parts = {}
    if #with > 0 then parts[#parts + 1] = "handier with " .. Names(with) end
    if #at > 0 then parts[#parts + 1] = (#with > 0 and "" or "handier ") .. "at " .. Names(at) end
    if guard then parts[#parts + 1] = "steadier on my guard" end
    return table.concat(parts, ", and ")
end

-- The day's summary: the finds, what I made, the fights not told, the coin
-- (going: today, not over yet)
local function Summary(key, day, ctx, going)
    local out = {}
    local finds, made, skills = {}, {}, {}
    for _, e in ipairs(day.events) do
        if e.k == "loot" and Quality(e.item) < 3 then finds[#finds + 1] = ItemName(e.item, e.count)
        elseif e.k == "create" then made[#made + 1] = ItemName(e.item, e.count)
        elseif e.k == "skill" and not tContains(skills, e.name) then skills[#skills + 1] = e.name end
    end
    if #finds > 0 then out[#out + 1] = Pick(key, 61, { "Among my finds were ", "I came away with " }) .. Names(Shorten(finds, 3)) .. "." end
    if #made > 0 then
        out[#out + 1] = "I made " .. Names(Shorten(made, 3))
            .. (#skills > 0 and (", and I grew " .. Skills(skills)) or "") .. "."
    elseif #skills > 0 then
        out[#out + 1] = "I grew " .. Skills(skills) .. "."
    end
    if ctx.stray > 0 then out[#out + 1] = "Here and there I fought off a few more foes." end
    -- (what I gathered: herbs picked, ore mined, hides skinned, fish caught)
    local gathered = {}
    local GATHERED = { herb = "picked herbs", ore = "worked ore veins", hide = "skinned beasts", fish = "cast my line" }
    for spell, n in pairs(day.stats.gather or {}) do
        if GATHERED[spell] and n > 0 then gathered[#gathered + 1] = GATHERED[spell] .. " " .. Times(n) end
    end
    table.sort(gathered)
    if #gathered > 0 then out[#out + 1] = "Along the way I " .. Names(gathered) .. "." end
    local m = day.stats.money
    local net = m.earned - m.spent
    if m.earned + m.spent > 0 and net ~= 0 then
        local richer = net > 0 and (Name(Coins(net)) .. " richer") or ("poorer by " .. Name(Coins(-net)))
        out[#out + 1] = (going and ("So far, I'm " .. richer) or ("All told, I ended the day " .. richer)) .. "."
    end
    return out
end

-- What wasn't kept when it happened (older events, a quest window that
-- didn't say): its giver, its ender (QuestieDB's), its goal (the quest log's)
local function Fill(day)
    for _, e in ipairs(day.events) do
        if (e.k == "accept" or e.k == "quest" or e.k == "ready" or e.k == "objective") and e.id then
            if e.giver == nil then e.giver = J.Giver(e.id) end
            if e.k == "quest" and e.ender == nil then e.ender = J.Ender(e.id) end
            if e.k == "accept" and e.goal == nil then e.goal = J.Goal(e.id) end
            if (e.k == "ready" or e.k == "objective") and e.need == nil then
                -- (the count it asked: its accept's goal, the same objective)
                for _, a in ipairs(day.events) do
                    if a.k == "accept" and a.id == e.id and a.goal then
                        for _, g in ipairs(a.goal) do
                            if g[1] == e.what then e.need = g[3] end
                        end
                    end
                end
            end
        end
    end
end

function J.Write(key, day)
    Fill(day)
    wipe(turns)
    local sessions = Sessions(day)
    if #sessions == 0 then return { "Little happened worth writing down." } end
    local ctx = { fare = {}, first = true, stray = 0, met = {} }
    local paragraphs = {}
    local wake = sessions[1].rfrom
    local before                 -- the last paragraph's end (realm minutes)
    for _, ep in ipairs(Episodes(day, sessions)) do
        local told = Told(ep, ctx)
        if #told > 0 then
            local out = {}
            local place = MainPlace(ep)
            local lead
            if #paragraphs == 0 and not ctx.wake then
                -- The first: when I woke, where
                ctx.zone = ep.zone
                -- (where I woke: the stretch's first place)
                place = ep.events[1].sub
                local where = ""
                if place and ep.zone and place ~= ep.zone then
                    where = ", at " .. Name(place) .. " in " .. ep.zone
                elseif ep.zone then
                    where = Pick(key, 42, { ", in ", ", still in " }) .. Name(ep.zone)
                end
                out[1] = Woke(key, wake) .. (sessions[1].rested and ", well rested" or "") .. where .. "."
            elseif ctx.wake then
                -- (the waking, with nothing told yet: this paragraph opens with it)
                out[1], ctx.wake = ctx.wake, nil
                if place ~= ctx.place and told[1].k ~= "zone" and told[1].k ~= "flight" then
                    lead = (place == ep.zone and "in " or "at ") .. Name(place) .. ", "
                end
            else
                if ep.rest then out[1] = Again(Rm(ep.events[1])) end
                lead = (not ep.rest and When(key, 46 + #paragraphs, Rm(ep.events[1]), before) or "")
                -- (where, unless its first words say so: a new land, a flight)
                if place ~= ctx.place and told[1].k ~= "zone" and told[1].k ~= "flight" then
                    lead = lead .. (place == ep.zone and "in " or "at ") .. Name(place) .. ", "
                end
                if lead == "" then lead = nil end
            end
            ctx.place, ctx.gaves = place, 0
            local i, said = 1, 0
            while told[i] do
                ctx.skip = 0
                local ev = told[i]
                -- (a long paragraph: a new one where I move on)
                local here = ev.x and ev or ev.by and ev.by.x and ev.by
                if said >= LONG and not ctx.errand and CONNECTS[ev.k]
                    and (here and Moved(ctx, here) ~= "here" or said >= LONG + 2) then
                    paragraphs[#paragraphs + 1] = table.concat(out, " ")
                    out, said, lead = {}, 0, Pick(key, 90 + i, { "From there, ", "Then " })
                end
                local npc = ctx.npc
                ctx.posFrom, ctx.noJoin = nil, nil
                local sentence = Sentence(key, told, i, ctx)
                -- (where I am now: the last thing told's place)
                local at = ctx.posFrom or told[i + ctx.skip]
                at = at and (at.x and at or at.by and at.by.x and at.by) or nil
                if at then ctx.pos = at end
                if ctx.npc == npc and LEAVES[ev.k] then ctx.npc = nil end
                if sentence then
                    -- (what joins it to the one before: the day's first thing, a
                    -- task put aside for another, then, after that)
                    local join
                    if not lead and CONNECTS[ev.k] and not ctx.noJoin then
                        local goalID = ev.k == "effort" and ev.goal.id or (ev.k == "ready" or ev.k == "objective") and ev.id
                        if #paragraphs == 0 and said == 0 then
                            join = ev.k ~= "money" and "First, " or nil
                        elseif ctx.taken and goalID and goalID ~= ctx.taken then
                            join = Pick(key, 80 + i, { "Rather than start on it right away, ", "But first, " })
                        elseif said > 0 then
                            join = CONNECTORS[(said + #paragraphs) % #CONNECTORS + 1]
                            if join == "" then join = nil end
                        end
                    end
                    out[#out + 1] = Lead(lead or join, sentence)
                    lead = nil
                    said = said + 1
                    ctx.first = false
                    ctx.taken = ev.k == "accept" and ev.id or nil
                end
                i = i + 1 + ctx.skip
            end
            if #paragraphs == 0 and said == 0 then
                -- (only the waking: it opens the next paragraph instead)
                ctx.wake = out[1]
            else
                paragraphs[#paragraphs + 1] = table.concat(out, " ")
            end
            before = Rm(ep.events[#ep.events])
        end
    end
    if #paragraphs == 0 and ctx.wake then paragraphs[1], ctx.wake = ctx.wake, nil end
    if #paragraphs == 0 then
        local zone = J.Zones(day)[1]
        paragraphs[1] = Woke(key, wake) .. (zone and (", in " .. Name(zone)) or "") .. "."
    end
    -- The day's summary, and its end (today's, while it goes on: not yet)
    local last = sessions[#sessions]
    local going = key == J.TodayKey() and time() - (last.to or 0) < STILL
    local closing = Summary(key, day, ctx, going)
    if not going then
        closing[#closing + 1] = LayDown(key, last.rto or RealmAt(last.to), #sessions == 1 and (day.stats.played or 0) < 600)
    end
    if #closing > 0 then paragraphs[#paragraphs + 1] = table.concat(closing, " ") end
    return paragraphs
end

-- The journal so far, for its first page
function J.Summary(keys)
    if #keys == 0 then return "These pages are empty yet. The road will fill them." end
    local quests, kills, deaths, lands = 0, 0, 0, {}
    for _, key in ipairs(keys) do
        local day = J.Day(key)
        local s = day.stats
        quests, kills, deaths = quests + s.quests, kills + s.kills, deaths + s.deaths
        for zone in pairs(s.zones or {}) do lands[zone] = true end
        for _, e in ipairs(day.events) do
            if e.k == "zone" then lands[e.name] = true end
        end
    end
    local nLands = 0
    for _ in pairs(lands) do nLands = nLands + 1 end
    local parts = {}
    if quests > 0 then parts[#parts + 1] = "seen " .. Plural(quests, "task", "tasks") .. " through" end
    if kills > 0 then parts[#parts + 1] = "slain " .. Plural(kills, "foe", "foes") end
    if nLands > 0 then parts[#parts + 1] = "walked " .. Plural(nLands, "land", "lands") end
    if deaths > 0 then parts[#parts + 1] = "fallen " .. Times(deaths) end
    return "I began this journal on " .. J.DayTitle(keys[#keys], true) .. "."
        .. (#parts > 0 and (" In " .. Plural(#keys, "day", "days") .. " on the road I have " .. Names(parts) .. ".") or "")
end
