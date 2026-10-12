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
function J.DayLine(day)
    local s = day.stats
    return BK.Join({ J.Zones(day)[1], s.quests > 0 and Plural(s.quests, "task", "tasks") or nil,
        s.kills > 0 and (s.kills .. " slain") or nil })
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

local function Quest(name) return Name("“" .. (name or "a task") .. "”") end

-- An item's name, in its quality's ink
local function ItemName(id, count)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, _, quality = get(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return "something"
    end
    local ink = BK.QUALITY_INK[quality or 1] or ""
    return ((count or 1) > 1 and (count .. " ") or "") .. ink .. name .. "|r"
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
local function Many(name, n)
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
    if before and Part(before) == part then return Pick(key, salt, { "A while later, ", "After a short rest, ", "Later, " }) end
    if part == "morning" then return Pick(key, salt, { "Later that morning, ", "Before noon, " }) end
    if part == "afternoon" then return h < 13 and "Toward noon, " or Pick(key, salt, { "In the afternoon, ", "That afternoon, " }) end
    if part == "evening" then return Pick(key, salt, { "By evening, ", "As evening fell, " }) end
    return Pick(key, salt, { "Late that night, ", "Deep in the night, " })
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
        return "I fell" .. where .. (d.by and (", " .. Pick(key, 39, { "cut down by ", "bested by " }) .. who(d.by, d.named)) or "")
            .. ". " .. Pick(key, 40, { "Embarrassing.", "Not my finest hour.", "I came to at a spirit healer's side." })
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
                parts[#parts + 1] = what:sub(1, 1):lower() .. what:sub(2)
            end
        end
    end
    return #parts > 0 and Names(parts) or nil
end

-- A task by who gave it: "Dockmaster Baren's “Selling Fish”"
local function QuestOf(e)
    return e.giver and (Name(e.giver) .. "'s " .. Quest(e.name)) or Quest(e.name)
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

-- A run of the same things (taken on, seen through, new lands...): one sentence
local RUNS = { accept = true, quest = true, loot = true, learn = true, zone = true, discover = true }

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
                    said = Name(giver) .. Pick(key, 76, { " sent me ", " asked me to go " }) .. carry .. "."
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
                    said = Pick(key, 77 + n, { "I headed over to ", "I made my way to " }) .. Name(r.giver) .. ", who "
                        .. (goal and ("needed help with " .. q .. ": to " .. goal) or ("asked for my help with " .. q)) .. "."
                elseif r.giver and r.giver == ctx.npc then
                    -- (the one just spoken of: no meeting them again)
                    said = Name(r.giver) .. Pick(key, 75 + n, { " had another task for me: ", " asked something more of me: " })
                        .. q .. (goal and (", to " .. goal) or "") .. "."
                elseif r.giver and goal then
                    said = Pick(key, 70 + n, { Name(r.giver) .. " asked me to " .. goal .. ", for " .. q .. ".",
                        "I met " .. Name(r.giver) .. ", who needed help with " .. q .. ": to " .. goal .. "." })
                elseif r.giver then
                    said = Name(r.giver) .. " asked for my help with " .. q .. "."
                elseif goal then
                    said = "I took on " .. q .. ", to " .. goal .. "."
                else
                    said = "I took on " .. q .. "."
                end
                out[n] = n > 1 and Lead(n == 2 and "then " or "after that, ", said) or said
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
                    next = ", then " .. also .. "gave me another task: " .. Quest(more[1].name) .. (goal and (", to " .. goal) or "")
                elseif #more > 1 then
                    local tasks = {}
                    for n, r in ipairs(more) do tasks[n] = Quest(r.name) end
                    next = ", then asked more of me: " .. Names(Shorten(tasks, 3))
                end
                local thanked = (gift and (Pick(key, 72, { "thanked me with ", "rewarded me with " }) .. gift) or "thanked me")
                    .. next .. "."
                -- (the errand's end: the one it was carried to)
                if ctx.errand == run[1] then
                    ctx.errand = nil
                    local sub = run[1].sub
                    if moved == "far" then
                        return Pick(key, 78, { "I made my way to ", "I set off to find " }) .. Name(ender)
                            .. ((sub and sub ~= ctx.place) and (" at " .. Name(sub)) or "") .. ", who " .. thanked
                    end
                    return Pick(key, 79, { "When I handed it over, ", "When I passed it on, " }) .. Name(ender) .. " " .. thanked
                end
                -- (back to the one who gave it, or to someone else)
                local back = (run[1].giver == nil or run[1].giver == ender) and " back to " or " to "
                if metBefore and moved == "far" and back == " back to " then
                    return "I went back to " .. Name(ender) .. " with " .. Names(Shorten(names, 3)) .. ", and "
                        .. Name(ender) .. " " .. thanked
                end
                return "I brought " .. Names(Shorten(names, 3)) .. back .. Name(ender) .. ", who " .. thanked
            end
            return Pick(key, 33, { "I saw ", "I finished " }) .. Names(Shorten(names, 3)) .. Pick(key, 33, { " through", "" })
                .. (gift and (", and was rewarded with " .. gift) or "") .. "."
        elseif k == "loot" then
            for n, r in ipairs(run) do names[n] = ItemName(r.item, r.count) end
            return Pick(key, 34, { "Luck was with me: I found ", "A rare find came my way: " }) .. Names(Shorten(names, 3)) .. "."
        elseif k == "learn" then
            for n, r in ipairs(run) do names[n] = r.name end
            return "I learned " .. Names(Shorten(names, 3)) .. "."
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
            said = Pick(key, 73, { "I cut down ", "I fought " }) .. FoesWords(foes, names) .. where
                .. (g.how == "item" and (" to gather " .. Many(g.what, 2)) or "") .. " for " .. q .. "."
        end
        if e.deaths then
            local n = #e.deaths.deaths
            said = said .. " I fell " .. Times(n) .. " along the way, but managed it in the end."
        elseif g.k == "ready" and e.by.k ~= "dive" then
            said = said .. " " .. Pick(key, 74, { "Before long I had all I needed.", "It took a while, but I had what I came for." })
        elseif g.k == "objective" then
            said = said .. " That part of the work was done."
        end
        return said
    end
    if k == "ready" then
        local q = QuestOf(e)
        local done = Pick(key, 43, { "; all that was left was to report back.", ", and I had only to report back." })
        if e.what and e.how == "item" then return "With the " .. Without(e.what) .. " in hand, " .. q .. " was done" .. done end
        if e.what and e.how == "monster" then return "With enough " .. Many(e.what, 2) .. " dealt with, " .. q .. " was done" .. done end
        return "That settled " .. q .. done
    end
    if k == "objective" then
        if e.what and e.how == "item" then return "I had the " .. Without(e.what) .. " " .. Quest(e.name) .. " called for." end
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
        ctx.levels = (ctx.levels or 0) + 1
        if ctx.levels > 1 then return "And stronger still." end
        return Pick(key, 41, { "I felt stronger than the day before.", "I could feel myself growing stronger." })
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
-- What joins a sentence to the one before (not every one: "" none)
local CONNECTORS = { "Then ", "After that, ", "", "Next, ", "" }
local CONNECTS = { accept = true, quest = true, effort = true, dive = true, fights = true, flight = true, hearth = true,
    zone = true, discover = true, instance = true, ready = true, money = true }

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
            if not cur or ev.t - cur.last > BREAK or (ev.k == "zone" and ev.name ~= cur.zone) then
                cur = { session = n, rest = not cur and n > 1 and s.from - sessions[n - 1].to > REST,
                    events = {}, zone = place }
                out[#out + 1] = cur
            end
            cur.events[#cur.events + 1] = ev
            cur.last = ev.t
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
        elseif not Routine(ev) and not (ev.k == "money" and ev.src == "flight") then
            told[#told + 1] = ev
        end
    end
    -- Fights (and the falls in them), a dive, then a task's objective done:
    -- one effort, what it was for
    local merged, i = {}, 1
    while told[i] do
        local a, j = told[i], i + 1
        local deaths
        if a.k == "fights" and told[j] and told[j].k == "deaths" then deaths, j = told[j], j + 1 end
        local g = told[j]
        if (a.k == "fights" or a.k == "dive") and g and (g.k == "ready" or g.k == "objective") and g.what
            and (g.how == "item" or g.how == "monster" and a.k == "fights") then
            merged[#merged + 1] = { k = "effort", by = a, deaths = deaths, goal = g, t = a.t, rm = a.rm or Rm(a) }
            i = j + 1
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
        end
    end
end

function J.Write(key, day)
    Fill(day)
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
            if #paragraphs == 0 then
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
                out[1] = Woke(key, wake) .. where .. "."
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
                local npc = ctx.npc
                ctx.posFrom = nil
                local sentence = Sentence(key, told, i, ctx)
                -- (where I am now: the last thing told's place)
                local at = ctx.posFrom or told[i + ctx.skip]
                at = at and (at.x and at or at.by and at.by.x and at.by) or nil
                if at then ctx.pos = at end
                if ctx.npc == npc and ev.k ~= "accept" and ev.k ~= "quest" then ctx.npc = nil end
                if sentence then
                    -- (what joins it to the one before: the day's first thing, a
                    -- task put aside for another, then, after that)
                    local join
                    if not lead and CONNECTS[ev.k] and not sentence:match("^When ") then
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
            paragraphs[#paragraphs + 1] = table.concat(out, " ")
            before = Rm(ep.events[#ep.events])
        end
    end
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
