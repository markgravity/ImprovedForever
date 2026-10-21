-- The book's pages, ours, laid out as Social Diary's Your Diary and People
-- pages are (its UI/Journey/Left.lua and Page.lua, UI/Journal/People.lua
-- and Profile.lua, not copied): the Diary (green ribbon) the days down the
-- left page a rubric each, the open one's zones under it; the open day on
-- the right page, a page at a time, in pictures: a stretch of it a page,
-- a line of its words (JournalWriter.lua) over its plate and cards as a
-- level's (BookData.lua into the copied UI/Journey/Caption.lua), a plate
-- more its own page; the Companions (red ribbon)
-- everyone met down the left page, one's page on the right: their
-- portrait, our story of them, the days we met. The pad: BookPad.lua.
local addonName, ns = ...
local IF = ImprovedForever
local Jn = IF.Journal

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local YourDiary = ns.UI.YourDiary
local BD = ns.BookData
local BOOK = J.BOOK
local LEFT_X, LEFT_W, RIGHT_X, RIGHT_W = BOOK.LEFT_X, BOOK.LEFT_W, BOOK.RIGHT_X, BOOK.RIGHT_W
local TOP, RIGHT_H, BOOK_H = BOOK.TOP, BOOK.RIGHT_H, BOOK.BOOK_H
local SCROLLBAR_WIDTH = ns.UI.SCROLLBAR_WIDTH or 12
local LEADERS, LEDGER = YourDiary.LEADERS, YourDiary.LEDGER
local Handout, NewNote, EnsurePools = YourDiary.Handout, YourDiary.NewNote, YourDiary.EnsurePools

local BP = {}
ns.BookPages = BP

-- The left page's measure (Look.lua's HEAD and ENTRY)
local HEAD = { name = 22, who = 54, rule = 76, ruleW = 60, list = 90, bottom = 34 }
local UNIT, INDENT, PARA, CLOSED, OPEN_H, AFTER = 17, 13, 8, 19, 22, 12
local LINE_W = LEFT_W - SCROLLBAR_WIDTH - 2 - INDENT
local PARAPHS = { Style.LAPIS, Style.RUBRIC }

---------------------------------------------------------------------------
-- Words laid in lines: a list item a line (a list item is shown whole or
-- not at all, and a paragraph runs taller than the page), a name's ink
-- carried over a line's end
---------------------------------------------------------------------------
local measure
local function Lines(text, font, width)
    measure:SetFontObject(font)
    local words, out = {}, {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local line, ink = {}, nil
    local start = nil
    local function Flush()
        if #line == 0 then return end
        out[#out + 1] = (start or "") .. table.concat(line, " ") .. (ink and "|r" or "")
        line, start = {}, ink
    end
    for _, word in ipairs(words) do
        line[#line + 1] = word
        measure:SetText(table.concat(line, " "))
        if #line > 1 and (measure:GetUnboundedStringWidth() or 0) > width then
            line[#line] = nil
            Flush()
            line[1] = word
        end
        for code in word:gmatch("|[cr]%x*") do
            ink = code:sub(2, 2) == "c" and code:sub(1, 10) or nil
        end
    end
    Flush()
    return out
end


---------------------------------------------------------------------------
-- The left page's rows: a rubric, a line of words, a zone in the ledger
---------------------------------------------------------------------------
local function Dots(row, room)
    if not BP.dotW then
        measure:SetFontObject(FONT.small)
        measure:SetText(LEDGER.dot:rep(20))
        local w = (measure:GetUnboundedStringWidth() or 0) / 20
        BP.dotW = w > 0 and w or nil
    end
    if not BP.dotW or room < BP.dotW then return "" end
    return LEDGER.dot:rep(math.floor(room / BP.dotW))
end

local function BuildRow(list)
    local row = CreateFrame("Button", nil, list)
    row.text = Style.Text(row, FONT.body)
    row.text:SetPoint("TOPLEFT", INDENT, 0)
    row.text:SetWidth(LINE_W + 4)
    row.text:SetWordWrap(false)
    row.header = Style.Text(row, FONT.headingRubric)
    row.paraph = row:CreateTexture(nil, "ARTWORK")
    row.paraph:SetSize(6, 6)
    row.paraph:SetRotation(math.pi / 4)
    row.paraph:SetPoint("CENTER", row.header, "LEFT", -INDENT / 2 - 1, 0)
    row.aside = Style.Text(row, FONT.small)
    row.aside:SetPoint("LEFT", row.header, "RIGHT", 7, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    -- (the open day's rubric marked as a reader marks a line: a pale wash
    -- of rubric under it, fading along)
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetPoint("TOPLEFT", 0, 0)
    row.wash:SetPoint("BOTTOMRIGHT", 0, 1)
    row.wash:Hide()
    row.zone = Style.Text(row, FONT.small)
    row.zone:SetPoint("LEFT", INDENT, 0)
    row.zone:SetWordWrap(false)
    row.time = Style.Text(row, FONT.small)
    row.time:SetPoint("RIGHT", -LEDGER.right, 0)
    row.time:SetJustifyH("RIGHT")
    row.dots = Style.Text(row, FONT.small)
    row.dots:SetPoint("RIGHT", row.time, "LEFT", -LEDGER.gap, 0)
    row.dots:SetJustifyH("RIGHT")
    row.dots:SetWordWrap(false)
    row.dots:SetAlpha(LEDGER.dotAlpha)
    -- (the pad's cursor on the picked rubric or person)
    row.cursor = IF.Focus.Cursor(row)
    row:SetScript("OnClick", function(self) if self.item and self.item.onClick then self.item.onClick(self.item) end end)
    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not (item and item.title) then return end
        local R = Style.RUBRIC
        Style.Shade(self.rule, "HORIZONTAL", R[1], R[2], R[3], 0.7, 0)
    end)
    row:SetScript("OnLeave", function(self)
        local item = self.item
        if not (item and item.title) then return end
        local R = Style.RUBRIC
        Style.Shade(self.rule, "HORIZONTAL", R[1], R[2], R[3], 0.4, 0)
    end)
    return row
end

local function UpdateRow(row, item)
    local isTitle, isZone = item.title ~= nil, item.zone ~= nil
    row.header:SetShown(isTitle)
    row.paraph:SetShown(isTitle)
    row.rule:SetShown(isTitle)
    row.aside:SetShown(isTitle)
    row.wash:SetShown(isTitle and item.open == true)
    row.text:SetShown(item.text ~= nil)
    row.zone:SetShown(isZone)
    row.time:SetShown(isZone)
    row.dots:SetShown(isZone)
    if isTitle then
        row.header:ClearAllPoints()
        row.header:SetPoint("BOTTOMLEFT", INDENT + (item.indent and 10 or 0), item.open and 6 or 4)
        row.header:SetFontObject(item.person and FONT.strong or FONT.headingRubric)
        row.header:SetText(item.title)
        local paraph = PARAPHS[item.paraph % 2 == 1 and 1 or 2]
        row.paraph:SetColorTexture(paraph[1], paraph[2], paraph[3], 1)
        row.paraph:SetSize(item.open and 8 or 6, item.open and 8 or 6)
        row.aside:SetText(item.aside or "")
        local R = Style.RUBRIC
        Style.Shade(row.rule, "HORIZONTAL", R[1], R[2], R[3], item.open and 0.7 or 0.4, 0)
        -- (the open day stands out; the others a contents list, quieter)
        row.header:SetAlpha((item.open or item.person) and 1 or 0.72)
        if item.open then Style.Shade(row.wash, "HORIZONTAL", R[1], R[2], R[3], 0.13, 0) end
        row.rule:ClearAllPoints()
        row.rule:SetPoint("LEFT", row.aside, "RIGHT", 6, 0)
        row.rule:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    elseif isZone then
        row.zone:SetWidth(0)
        row.zone:SetText(item.zone)
        row.time:SetText(item.time or "")
        local rowW = LEFT_W - SCROLLBAR_WIDTH - 2
        local nameW = row.zone:GetUnboundedStringWidth() or 0
        local most = math.floor(LEDGER.nameMax * (rowW - INDENT))
        if nameW > most then
            row.zone:SetWidth(most)
            nameW = most
        end
        local timeW = row.time:GetUnboundedStringWidth() or 0
        row.dots:SetText(Dots(row, rowW - INDENT - nameW - timeW - LEDGER.right - 2 * LEDGER.gap))
    elseif item.text then
        row.text:SetFontObject(item.font or FONT.body)
        row.text:SetText(item.text)
    end
    -- (the pad's place: on this one)
    if item.picked and BP.PadOn and BP.PadOn() then row.cursor:Point(row.header:IsShown() and row.header or row) else row.cursor:Hide() end
end

-- The character at the top of a left page
local function Header(page, parent)
    page.name = Style.Text(parent, FONT.title)
    page.name:SetPoint("TOPLEFT", LEFT_X, -HEAD.name)
    page.who = Style.Text(parent, FONT.faded)
    page.who:SetPoint("TOPLEFT", LEFT_X, -HEAD.who)
    page.rule = parent:CreateTexture(nil, "ARTWORK")
    page.rule:SetSize(HEAD.ruleW, 1)
    page.rule:SetPoint("TOPLEFT", LEFT_X, -HEAD.rule)
    local INK = Style.INK
    Style.Shade(page.rule, "HORIZONTAL", INK[1], INK[2], INK[3], Style.HAIRLINE or 0.5, 0)
end

local function List(parent)
    local list = J.List(parent, UNIT, 48, BuildRow, UpdateRow, LEFT_W, "TOPLEFT", LEFT_X, -HEAD.list)
    list:SetNumRows(math.floor((BOOK_H - HEAD.list - HEAD.bottom) / UNIT))
    return list
end

---------------------------------------------------------------------------
-- The Diary, laid out as Social Diary's Your Diary, a day of ours where it
-- has a level: the days down the left page a rubric each (what stood
-- out beside it), the open day's ledger of where the time went under its
-- rubric; the day itself on the right page, a page at a time (DayPages)
---------------------------------------------------------------------------
local diary = { open = nil, sel = 1, leaf = 1 }
BP.diary = diary

local FillHeader = function()
    local name = ns.Plain(UnitName("player")) or ""
    diary.name:SetFontObject(FONT.title)
    diary.name:SetText(name:upper())
    local level, race, class = ns.Plain(UnitLevel("player")), ns.Plain(UnitRace("player")), ns.Plain(UnitClass("player"))
    local parts = {}
    if type(level) == "number" and level > 0 then parts[#parts + 1] = "Level " .. level end
    if type(race) == "string" then parts[#parts + 1] = race end
    if type(class) == "string" then parts[#parts + 1] = class end
    diary.who:SetText(table.concat(parts, " "))
end

-- Beside a rubric: "so far" on today's, as Social Diary's level being
-- played; the recap under the open one tells the rest
local function Aside(key)
    if key == Jn.TodayKey() then return "so far" end
    return nil
end

-- The open day's recap, as Social Diary recaps a level under its rubric:
-- a line in faded ink (the levels, the land, the time on the road), its
-- own paragraphs (UI/Journey/Text/Prose.lua's Text.Lines: where the time
-- went, who was there, the firsts, the close calls, the slow hunts) over
-- the day's entry (BookData.lua), and a line of ours (tasks done, foes cut
-- down, falls)
local JText = ns.UI.JourneyText
local function Recap(key, day)
    local de = BD.Use(key)
    local c = BD.Current()
    if not (de and c) then return {} end
    local j, stats = c.j, day.stats
    local out = {}
    -- The opening
    local from, to = stats.levelFrom, stats.levelTo or stats.levelFrom
    local zones = Jn.Zones(day)
    local bits = {}
    if from and to and to > from then bits[1] = "Level " .. from .. " to " .. to
    elseif to then bits[1] = "Level " .. to end
    if zones[1] then bits[#bits + 1] = (#bits > 0 and "mostly in " or "Mostly in ") .. zones[1] end
    local opening = table.concat(bits, ", ")
    local played = stats.played or 0
    if played >= 60 then
        local spoken = JText.Spoken(played)
        opening = opening ~= "" and (opening .. "; " .. spoken .. " on the road.") or (JText.Capital(spoken) .. " on the road.")
    elseif opening ~= "" then
        opening = opening .. "."
    end
    if opening ~= "" then out[#out + 1] = { text = opening, font = FONT.faded } end
    -- Social Diary's paragraphs
    local stops = {}
    for _, s in ipairs(j.segs) do
        if s.kind == "stop" and s.seconds >= 300 then stops[#stops + 1] = s end
    end
    table.sort(stops, function(a, b) return a.seconds > b.seconds end)
    for i = #stops, 4, -1 do stops[i] = nil end
    table.sort(stops, function(a, b) return a.from < b.from end)
    local e = { kind = "level", level = to or 1, known = true, seconds = played, stops = {}, flights = {},
        people = {}, fights = {}, finds = {}, closeCalls = j.closeCalls, skillCaps = j.skillCaps, hunts = {},
        fortunes = {}, places = {} }
    for i, s in ipairs(stops) do
        local act = s.act or {}
        local main = act.combat >= 30 and "fighting" or (act.questsIn + act.questsOut > 0) and "questing" or nil
        e.stops[i] = { seg = s, seconds = s.seconds, main = main }
    end
    local together = {}
    for _, sess in ipairs(j.sessions) do
        for guid, p in pairs(sess.participants) do together[guid] = (together[guid] or 0) + p.seconds end
    end
    for guid, seconds in pairs(together) do e.people[#e.people + 1] = { guid = guid, seconds = seconds } end
    table.sort(e.people, function(a, b) return a.seconds > b.seconds end)
    for _, f in ipairs(j.firsts) do e.finds[#e.finds + 1] = { kind = f.what, rec = f.rec } end
    for _, m in ipairs(c.moments or {}) do
        if m.kind == "luck" then e.hunts[#e.hunts + 1] = m.hunt
        elseif m.kind == "fortune" then e.fortunes[#e.fortunes + 1] = m.hunt end
    end
    local ok, lines = pcall(JText.Lines, e, ns.Now(), {})
    for _, text in ipairs(ok and lines or {}) do out[#out + 1] = { text = text } end
    -- Ours: what was done and what it cost
    local quests, foes, falls = 0, 0, 0
    for _, ev in ipairs(day.events) do
        if ev.k == "quest" then quests = quests + 1
        elseif ev.k == "hunt" then foes = foes + (ev.n or 0)
        elseif ev.k == "kill" then foes = foes + 1
        elseif ev.k == "death" then falls = falls + 1 end
    end
    local said = {}
    if quests > 0 then said[#said + 1] = quests == 1 and "one task done" or (quests .. " tasks done") end
    if foes > 0 then said[#said + 1] = foes .. " foes cut down" end
    if falls > 0 then said[#said + 1] = falls == 1 and "one fall" or (falls .. " falls") end
    if #said > 0 then
        local text = table.concat(said, ", ")
        out[#out + 1] = { text = JText.Capital(text) .. "." }
    end
    return out
end

-- The left page's items: the days, the open one's recap and ledger
local function DiaryItems()
    local items, rubrics = {}, {}
    local keys = Jn.Days()
    diary.keys = keys
    local month
    for i, key in ipairs(keys) do
        local m = Jn.MonthTitle(key)
        if m ~= month then
            month = m
            items[#items + 1] = { text = m, font = FONT.small, height = UNIT + (i > 1 and 8 or 0) }
        end
        local open = key == diary.open
        local day = Jn.Day(key)
        if open and i > 1 then items[#items + 1] = { height = OPEN_H - UNIT } end
        items[#items + 1] = { title = Jn.DayTitle(key):upper(), aside = Aside(key), paraph = i, open = open,
            picked = i == diary.sel, height = open and OPEN_H or CLOSED,
            onClick = function() BP.OpenDay(key, true) end }
        rubrics[i] = #items
        if open then
            for k, para in ipairs(Recap(key, day)) do
                if k > 1 then items[#items + 1] = { height = PARA } end
                for _, line in ipairs(Lines(para.text, para.font or FONT.body, LINE_W)) do
                    items[#items + 1] = { text = line, font = para.font or FONT.body, height = UNIT }
                end
            end
            items[#items + 1] = { height = 8 }
            for _, name in ipairs(Jn.Zones(day)) do
                items[#items + 1] = { zone = name, time = Jn.Played(day.stats.zones[name]), height = UNIT }
            end
            items[#items + 1] = { height = AFTER }
        end
    end
    return items, rubrics
end

local function RebuildDiary()
    local items, rubrics = DiaryItems()
    diary.items, diary.rubrics = items, rubrics
    diary.list:SetData(items, true)
    local at = rubrics[diary.sel]
    if at then
        local offset, rows = diary.list.offset or 0, diary.list.numRows or 20
        if at <= offset or at > offset + rows - 6 then diary.list:SetOffset(math.max(0, at - 2)) end
    end
end

---------------------------------------------------------------------------
-- The right page: the open day, a page at a time, told in pictures. The
-- day's paragraphs (Jn.Write) go in stretches, each from when its first
-- paragraph begins to when the next stretch's does, those on one map
-- together while their cards stay few (PAGE.cards); each stretch's plates
-- (BD.Stretch: its moments, the tasks done, the foes, the falls...) drawn
-- through the copied pipeline (UI/Journey/Caption.lua), their headings by
-- hand ours (the time of day, the place: p.heading). A plate with much in
-- its margin has a page of its own, in one of four shapes in turn (ALONE),
-- its caption one short sentence of the writer's (p.say); quieter ones
-- share a page, two or three, on Social Diary's own pages for them
-- (Look.lua's LAYOUT, by their weights: LayoutFor), their captions its
-- own; a rich one followed by a quiet print takes it in (FL, F+L).
-- A page's foot: its number, the time of day it begins, its land.
---------------------------------------------------------------------------
-- The words `x` in and `unit` a line; the page's foot `foot` up from its
-- end (the legend at its right); a plate `plate` tall under its caption,
-- its cards in a row of three under it; a stretch's cards at most `cards`
-- (guessed from its events) before the next paragraph is a page of its own.
local PAGE = { x = 12, unit = 17, foot = 30, top = 40, plate = 262, row = 318, cards = 5 }
-- A plate with `rich` cards or more has a page of its own; quieter ones
-- share one while their cards come to no more than `shared[n]` for n
-- plates.
local SHARE = { rich = 3, shared = { [2] = 4, [3] = 3 } }
local WORDS_W = RIGHT_W - 2 * PAGE.x
local BOTTOM = RIGHT_H - PAGE.foot
local FOUR, LOST = { "tl", "tr", "bl", "br" }, { "tl", "tr", "bl" }
local Plate = ns.UI.JourneyPlate

-- The plate's slot: its caption over it and its cards in a row under it
-- (`top`, tried first), else the caption under it and the cards beside
-- that (where the words will not stay to a line), as Look.lua's LAYOUT[1]
local function Slot()
    local row = {}
    for i = 1, 3 do row[i] = { x = 10 + (i - 1) * 150, y = PAGE.row, w = 142, limit = BOTTOM } end
    return { x = 10, y = 0, w = 444, h = 354, t = -1.2, pad = 10, pc = 28, corners = LOST, lift = "br",
        cap = { x = 16, y = 372, w = 260, limit = BOTTOM }, notes = { x = 300, y = 368, w = 150, limit = BOTTOM },
        top = { x = 10, y = PAGE.top, w = 444, h = PAGE.plate, t = -1.2, pad = 10, pc = 28, corners = LOST,
            lift = "br", cap = { x = 16, y = -2, w = 434 }, row = row } }
end

-- A page of one plate, in turn: its caption over it and its cards in a
-- row under it (Slot); the plate tall at the left, its caption and cards
-- down the right; the same the other way round, flush right; the caption
-- and cards across the top, the plate under them. `narrow`: its heading
-- the place alone, the time of day in its words.
local ALONE = {
    { key = "top", Slot },
    { key = "left", narrow = true, function()
        return { x = 8, y = -2, w = 270, h = 440, t = -1.3, pad = 8, pc = 24, corners = FOUR,
            cap = { x = 292, y = 16, w = 166, limit = BOTTOM } }
    end },
    { key = "right", narrow = true, function()
        return { x = 190, y = -2, w = 268, h = 440, t = 1.4, pad = 8, pc = 24, corners = LOST, lift = "br",
            cap = { x = 12, y = 24, w = 164, limit = BOTTOM, align = "RIGHT" } }
    end },
    { key = "bottom", function()
        return { x = 10, y = 186, w = 444, h = 300, t = 1.1, pad = 10, pc = 28, corners = LOST, lift = "br",
            cap = { x = 16, y = 4, w = 270, limit = 176 }, notes = { x = 300, y = 0, w = 156, limit = 176 } }
    end },
}

-- The art box every plate must hold in: the two-plate page's smaller
-- (Look.lua's LAYOUT[2]), so a plate holds on any page of one or two
local function Cover(mapID) return Plate.Cover(mapID, 244, 200) end

-- The cards a plate's margin would hold, guessed from its moments: a
-- task, a find, each; its foes two at most; a fall, a close call, a
-- duel, a hunt's luck one each; someone met each
local ONE = { death = true, close = true, duel = true, luck = true, fortune = true }
local function Weight(p)
    local n, foes, once, people = 0, {}, {}, {}
    for _, m in ipairs(p.moments or {}) do
        if m.kind == "quest" or m.kind == "find" or m.kind == "skill" then n = n + 1
        elseif m.kind == "foes" then for name in pairs(m.foes or {}) do foes[name] = true end
        elseif ONE[m.kind] then once[m.kind] = true
        elseif m.kind == "session" and m.guid then people[m.guid] = true end
    end
    local f = 0
    for _ in pairs(foes) do f = f + 1 end
    for _ in pairs(once) do n = n + 1 end
    for _ in pairs(people) do n = n + 1 end
    return n + math.min(2, f)
end

-- A plate's caption ours where the page gave it one (p.heading, p.say)
local plateHeading, plateCaption = JText.PlateHeading, JText.PlateCaption
function JText.PlateHeading(p, ...)
    if p.heading then return p.heading, p.heading, nil end
    return plateHeading(p, ...)
end
function JText.PlateCaption(p, ...)
    if p.say then return p.say end
    return plateCaption(p, ...)
end

-- The writer's sentences, in order (a name's ink closed where it opened)
local CLOSE_QUOTE = "\226\128\157"
local function Sentences(text, out)
    for s in (text .. " "):gmatch("(.-[%.!?])%s+") do
        if s:sub(1, 3) == CLOSE_QUOTE and #out > 0 then
            out[#out] = out[#out] .. CLOSE_QUOTE
            s = s:sub(4)
        end
        s = s:gsub("^%s+", "")
        if s ~= "" then
            local _, opened = s:gsub("|c", "")
            local _, closed = s:gsub("|r", "")
            if opened > closed then s = s .. "|r" end
            out[#out + 1] = s
        end
    end
    return out
end

-- What only says when: never the page's sentence
local WHEN = { "^I rested a while", "^The new day found", "^Midnight came" }

-- The page's one sentence: the first that holds to a line, else the
-- shortest
local function OneLine(texts)
    local all = {}
    for _, text in ipairs(texts) do Sentences(text, all) end
    measure:SetFontObject(FONT.body)
    local best, bestW
    for _, s in ipairs(all) do
        local when = false
        for _, pat in ipairs(WHEN) do when = when or s:match(pat) ~= nil end
        if not when then
            measure:SetText(s)
            local w = measure:GetUnboundedStringWidth() or 0
            if w <= WORDS_W - 10 then return s end
            if not bestW or w < bestW then best, bestW = s, w end
        end
    end
    return best or all[1]
end

-- "Half past six in the evening, Balnir Farmstead": when a stretch began
-- and where it went on most; and each alone
local function Heading(day, from, to)
    local count, place = {}, nil
    for _, ev in ipairs(day.events) do
        if ev.t >= from and ev.t < to then
            local p = ev.sub or ev.zone
            if p and ev.k ~= "zone" and ev.k ~= "flight" and ev.k ~= "hearth" then
                count[p] = (count[p] or 0) + 1
                if not place or count[p] > count[place] then place = p end
            end
        end
    end
    local when = Jn.Clock and Jn.RealmAt and from > 0 and Jn.Clock(Jn.RealmAt(from)) or nil
    when = when and (when:sub(1, 1):upper() .. when:sub(2)) or nil
    if when and place then return when .. ", " .. place, when, place end
    return when or place or "Later", when, place
end

-- The cards a stretch of events would show, guessed: its tasks, its foes
-- (two at most), a fall
local function Cards(day, from, to)
    local quests, foes, fell = 0, {}, false
    for _, ev in ipairs(day.events) do
        if ev.t >= from and ev.t < to then
            if ev.k == "quest" then quests = quests + 1
            elseif ev.k == "death" then fell = true
            elseif ev.k == "hunt" then for name in pairs(ev.foes or {}) do foes[name] = true end
            elseif ev.k == "kill" and ev.name then foes[ev.name] = true end
        end
    end
    local n = 0
    for _ in pairs(foes) do n = n + 1 end
    return quests + math.min(2, n) + (fell and 1 or 0)
end

-- The open day's pages, worked out once while the day stays as it is
-- (today's: and every ten minutes, its words saying it goes on)
local plans = {}
local function DayPages(key)
    local day = Jn.Day(key)
    if not day then return nil end
    local stamp = #day.events .. ":" .. (day.trackN or 0)
    if key == Jn.TodayKey() then stamp = stamp .. ":" .. math.floor(time() / 600) end
    local plan = plans[key]
    if plan and plan.stamp == stamp then return plan end
    local de = BD.Use(key)
    plan = { stamp = stamp, pages = {} }
    plans[key] = plan
    local paras, meta = Jn.Write(key, day)
    paras, meta = paras or {}, meta or {}
    -- (the day's road too, before its first event and after its last)
    local first = de and de.from or day.events[1] and day.events[1].t or 0
    local last = day.events[#day.events] and day.events[#day.events].t or first
    local stop = math.max(last + 60, de and de.to or 0)
    -- (when each paragraph begins, never before the one before it)
    local idx, starts, at = {}, {}, first
    for i in ipairs(paras) do
        if i ~= meta.summary then
            local t = meta.starts and meta.starts[i]
            if type(t) == "number" and t > at then at = t end
            idx[#idx + 1], starts[#idx + 1] = i, at
        end
    end
    local function MapIn(from, to)
        for _, ev in ipairs(day.events) do
            if ev.t >= from and ev.t < to and ev.map then return ev.map end
        end
    end
    local scenes, cur = {}, nil
    for n, i in ipairs(idx) do
        local to = starts[n + 1] or stop
        local map = MapIn(starts[n], to)
        if cur and (not map or not cur.map or map == cur.map) and Cards(day, cur.from, to) <= PAGE.cards then
            cur.map = cur.map or map
        else
            cur = { from = starts[n], texts = {}, map = map }
            scenes[#scenes + 1] = cur
        end
        cur.texts[#cur.texts + 1] = paras[i]
    end
    if #scenes == 0 then scenes[1] = { from = first, texts = { meta.summary and paras[meta.summary] or "" } } end
    -- Every plate of the day in order, each with its stretch, its heading
    -- and how much its margin holds
    local units = {}
    for k, sc in ipairs(scenes) do
        sc.to = math.max(sc.from, scenes[k + 1] and scenes[k + 1].from or stop)
        sc.moments, sc.plates, sc.hunts = BD.Stretch(sc.from, sc.to, Cover)
        sc.say = OneLine(sc.texts)
        sc.heading = Heading(day, sc.from, sc.to)
        for n, p in ipairs(sc.plates) do
            local full, when, place = Heading(day, n == 1 and sc.from or p.t, sc.to)
            units[#units + 1] = { plate = p, scene = sc, first = n == 1, weight = Weight(p), full = full,
                when = when, place = place }
        end
        if #sc.plates == 0 then plan.pages[#plan.pages + 1] = { scene = sc } end
    end
    -- Into pages: a rich plate alone, in the next of ALONE's shapes; the
    -- quieter ones two or three to a page where Social Diary has a page
    -- that holds them, else alone too
    local i, turn = 1, 0
    local LayoutFor = YourDiary.LayoutFor
    while units[i] do
        local u = units[i]
        local group = { u }
        if u.weight < SHARE.rich then
            local total = u.weight
            for k = i + 1, math.min(#units, i + 2) do
                local v = units[k]
                local limit = SHARE.shared[#group + 1]
                if v.weight >= SHARE.rich or total + v.weight > limit then break end
                local plates = {}
                for g, w in ipairs(group) do plates[g] = w.plate end
                plates[#plates + 1] = v.plate
                if not LayoutFor(plates) then break end
                group[#group + 1], total = v, total + v.weight
            end
        end
        -- (a rich plate and a quiet one after it: Social Diary's FL, the
        -- quiet one's print tucked into the rich one's row where all of its
        -- margin goes in the row beside it, F+L; else the print under the
        -- rich one's caption)
        local v = units[i + 1]
        if u.weight >= SHARE.rich and v and v.weight <= 1 and v.plate.light then
            local _, key = LayoutFor({ u.plate, v.plate })
            if key == "FL" then group[2] = v end
        end
        local pg = { units = group, scene = u.scene, plate = u.plate }
        if #group == 2 and group[1].weight >= SHARE.rich then
            u.plate.heading, u.plate.say = u.full, u.first and u.scene.say or nil
            v.plate.heading, v.plate.say = nil, nil
        elseif #group == 1 then
            turn = turn % #ALONE + 1
            local shape = ALONE[turn]
            pg.shape = shape
            local p = u.plate
            if shape.narrow and u.place then
                local say = u.first and u.scene.say or nil
                p.heading = u.place
                p.say = u.when and (u.when:sub(1, 1):upper() .. u.when:sub(2) .. (say and (". " .. say) or ".")) or say
            else
                p.heading, p.say = u.full, u.first and u.scene.say or nil
            end
        else
            -- (Social Diary's own captions: "Tirisfal Glades, Monday",
            -- "Forty minutes later", a few words of what it shows)
            for _, w in ipairs(group) do w.plate.heading, w.plate.say = nil, nil end
        end
        plan.pages[#plan.pages + 1] = pg
        i = i + #group
    end
    return plan
end

-- The page's foot: "half past eight in the morning · Tirisfal Glades" in
-- the middle, the page arrows in its corners
local function Foot(pg, n, of)
    local foot = diary.foot
    diary.back:SetShown(pg ~= nil and n > 1)
    diary.on:SetShown(pg ~= nil and n < of)
    if not pg then return foot:SetText("") end
    local bits = {}
    local t = pg.plate and pg.plate.t or pg.scene.from
    if t and t > 0 and Jn.Clock and Jn.RealmAt then bits[#bits + 1] = (Jn.Clock(Jn.RealmAt(t))) end
    local mapID = pg.plate and pg.plate.mapID or pg.scene.map
    local land = mapID and JText.MapName(mapID)
    if land then bits[#bits + 1] = land end
    foot:SetText(table.concat(bits, " \194\183 "))
end

local function DrawRight()
    local page = YourDiary.page
    if not page then return end
    for _, pool in ipairs(page.rightPools or {}) do pool:Begin() end
    diary.wordPool:Begin()
    page.links, page.sheets, page.moments = {}, {}, {}
    page.now, page.fights, page.ctx = ns.Now(), {}, {}
    page.nothing:Hide()
    local plan = diary.open and DayPages(diary.open)
    local pages = plan and plan.pages or {}
    diary.leaf = math.max(1, math.min(diary.leaf or 1, #pages))
    diary.pages = #pages
    local pg = pages[diary.leaf]
    local shown = 0
    local de = pg and pg.plate and BD.Use(diary.open)
    if de then
        -- (its stretches' time, moments and hunts together)
        local from, to, moments, hunts, plates, seen = math.huge, 0, {}, {}, {}, {}
        for k, u in ipairs(pg.units) do
            local sc = u.scene
            plates[k] = u.plate
            from, to = math.min(from, sc.from), math.max(to, sc.to)
            if not seen[sc] then
                seen[sc] = true
                for _, m in ipairs(sc.moments) do moments[#moments + 1] = m end
                for _, h in ipairs(sc.hunts) do hunts[#hunts + 1] = h end
            end
        end
        table.sort(moments, function(a, b) return a.t < b.t end)
        local layout, pattern
        if #plates == 1 then
            layout, pattern = { pg.shape[1]() }, "F"
        else
            layout, pattern = YourDiary.LayoutFor(plates)
            if not layout then layout, pattern = YourDiary.LAYOUT[#plates], "" end
        end
        -- (the level reached, its pin: on the page it was reached in)
        local out = de.out and de.out.at and de.out.at >= from and de.out.at < to and de.out or nil
        local e = { kind = "level", key = diary.open, level = de.level, from = from, to = to, out = out,
            whole = true, deaths = {}, finds = {}, hunts = hunts, moments = moments,
            plates = plates, layout = layout, pattern = pattern }
        local ok, n = pcall(YourDiary.DrawPlates, e)
        if ok then shown = n or 0 else IF.Print("Journal: " .. tostring(n)) end
    elseif pg then
        -- (nothing of it on a map: its heading and words alone)
        local y = 0
        local items = { { text = pg.scene.heading, font = FONT.noteWritten, height = PAGE.unit + 6 } }
        for _, line in ipairs(Lines(pg.scene.say or "", FONT.body, WORDS_W)) do items[#items + 1] = { text = line } end
        for _, it in ipairs(items) do
            local fs = diary.wordPool:Next()
            fs:SetFontObject(it.font or FONT.body)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", page.right, "TOPLEFT", PAGE.x, -y)
            fs:SetText(it.text)
            y = y + (it.height or PAGE.unit)
        end
    end
    for i = shown + 1, #page.plates do page.plates[i]:Hide() end
    for _, pool in ipairs(page.rightPools or {}) do pool:Finish() end
    diary.wordPool:Finish()
    Foot(pg, diary.leaf, #pages)
    if not pg then
        page.nothing:SetText("Nothing written yet.")
        page.nothing:Show()
    end
end
BP.Redraw = DrawRight


local drawAt = 0
local timer = CreateFrame("Frame")
timer:Hide()
timer:SetScript("OnUpdate", function(self)
    if GetTime() < drawAt then return end
    self:Hide()
    DrawRight()
end)

local function DrawSoon()
    drawAt = GetTime() + 0.18
    timer:Show()
end

-- A day opened: its ledger under its rubric, its pages on the right (at
-- the first, for another day)
function BP.OpenDay(key, now)
    if not key then return end
    if key ~= diary.open then diary.leaf = 1 end
    diary.open = key
    for i, k in ipairs(diary.keys or Jn.Days()) do
        if k == key then diary.sel = i end
    end
    RebuildDiary()
    if now then DrawRight() else DrawSoon() end
end

-- The pad: up / down the days (each opened as it's reached)
function BP.DiaryMove(step)
    local keys = diary.keys or Jn.Days()
    local i = math.max(1, math.min(#keys, diary.sel + step))
    if i == diary.sel then return end
    Style.PlaySound("pageTurn")
    BP.OpenDay(keys[i])
end

-- Left / right: the open day's pages
function BP.DiaryTurn(step)
    local plan = diary.open and DayPages(diary.open)
    local n = plan and #plan.pages or 0
    local leaf = math.max(1, math.min(n, (diary.leaf or 1) + step))
    if n == 0 or leaf == diary.leaf then return end
    diary.leaf = leaf
    Style.PlaySound("pageTurn")
    DrawRight()
end

-- The open day's page, and how many it has
function BP.DiaryPages()
    local plan = diary.open and DayPages(diary.open)
    return diary.leaf or 1, plan and #plan.pages or 0
end

local function BuildDiary(container)
    local page = { parent = container, plates = {}, sheets = {}, moments = {}, mode = "plates", links = {} }
    YourDiary.page = page
    Header(diary, container)
    diary.list = List(container)
    page.right = CreateFrame("Frame", nil, container)
    page.right:SetPoint("TOPLEFT", RIGHT_X, -TOP)
    page.right:SetSize(RIGHT_W, RIGHT_H)
    page.leaders = CreateFrame("Frame", nil, page.right)
    page.leaders:SetAllPoints(page.right)
    page.leaders:SetFrameLevel(page.right:GetFrameLevel() + LEADERS.level)
    local function Stroke()
        local t = page.leaders:CreateTexture(nil, "OVERLAY")
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end
    page.leaderPool = Handout(Stroke)
    page.dotPool = Handout(Stroke)
    page.headingPool = Handout(function()
        local text = Style.Text(page.right, FONT.noteWritten)
        text:SetWordWrap(true)
        return text
    end)
    page.captionPool = Handout(function()
        local text = Style.Text(page.right, FONT.body)
        text:SetWordWrap(true)
        text:SetSpacing(2)
        return text
    end)
    page.notePool = Handout(NewNote)
    EnsurePools()
    page.nothing = Style.Text(page.right, FONT.faded)
    page.nothing:SetPoint("TOPLEFT", 40, -60)
    page.nothing:SetWidth(RIGHT_W - 80)
    page.nothing:Hide()
    diary.wordPool = Handout(function()
        local text = Style.Text(page.right, FONT.body)
        text:SetWidth(WORDS_W + 8)
        text:SetWordWrap(false)
        return text
    end)
    -- (the page's corners turn it: big enough to hit, a little more round
    -- them than the words show)
    -- (the page turned in its corners: a large « and » in ink, in the
    -- title's face, darker under the mouse, a little more round them than
    -- they show)
    local function Arrow(glyph, step)
        local b = CreateFrame("Button", nil, page.right)
        b:SetSize(36, 32)
        b.label = Style.Text(b, FONT.title)
        b.label:SetPoint("CENTER", 0, 2)
        b.label:SetText(glyph)
        local I, S = Style.INK, Style.INK_STRONG
        b.label:SetTextColor(I[1], I[2], I[3])
        b:SetHitRectInsets(-8, -8, -6, -6)
        b:SetScript("OnEnter", function() b.label:SetTextColor(S[1], S[2], S[3]) end)
        b:SetScript("OnLeave", function() b.label:SetTextColor(I[1], I[2], I[3]) end)
        b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 1, 1) end)
        b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER", 0, 2) end)
        b:SetScript("OnClick", function() BP.DiaryTurn(step) end)
        return b
    end
    diary.back = Arrow("\194\171", -1)
    diary.back:SetPoint("BOTTOMLEFT", page.right, "TOPLEFT", 6, -(RIGHT_H + 6))
    diary.on = Arrow("\194\187", 1)
    diary.on:SetPoint("BOTTOMRIGHT", page.right, "TOPLEFT", RIGHT_W - 12, -(RIGHT_H + 6))
    diary.foot = Style.Text(page.right, FONT.small)
    diary.foot:SetPoint("BOTTOM", page.right, "TOPLEFT", RIGHT_W / 2, -(RIGHT_H - 6))
    -- (the wheel turns the pages)
    page.right:EnableMouseWheel(true)
    page.right:SetScript("OnMouseWheel", function(_, delta) BP.DiaryTurn(delta > 0 and -1 or 1) end)
    diary.page = page
end

local function RefreshDiary()
    BD.People()
    FillHeader()
    local keys = Jn.Days()
    diary.keys = keys
    if not diary.open or not Jn.Day(diary.open) then diary.open = keys[1] end
    if diary.open then BP.OpenDay(diary.open, true) else RebuildDiary() DrawRight() end
end

-- Today, as it goes on: its pages again now and then while open (on the
-- last one still, where it was being read)
function BP.Changed()
    if not (ns.UI.JournalShowing and ns.UI.JournalShowing("journey")) then return end
    if diary.open ~= Jn.TodayKey() then return end
    -- (as drawn last: the plan is made again as the day grows)
    local atEnd = (diary.leaf or 1) >= (diary.pages or 0)
    RebuildDiary()
    if atEnd then diary.leaf = math.huge end
    DrawSoon()
end

---------------------------------------------------------------------------
-- The Companions
---------------------------------------------------------------------------
local people = { sel = 1 }
BP.people = people

local function PeopleItems()
    local items = {}
    local list = IF.JournalBook.Companions()
    people.list = list
    for i, c in ipairs(list) do
        local p = c.p
        items[#items + 1] = { title = c.name, person = true, paraph = i, picked = i == people.sel,
            aside = table.concat({ p.race or "", p.class or "" }, " "):gsub("^%s+", ""), height = CLOSED + 2,
            onClick = function() BP.OpenPerson(i) end }
    end
    if #items == 0 then
        items[1] = { text = "No one yet.", font = FONT.faded, height = UNIT }
    end
    return items
end

local function PersonRight()
    local c = people.list and people.list[people.sel]
    local r = people.right
    r:SetShown(c ~= nil)
    if not c then return end
    local p = c.p
    Style.SetPersonHeading(r, { race = p.raceToken, class = p.classToken, sex = p.sex }, c.name,
        table.concat({ p.race or "", p.class or "", p.guild and ("<" .. p.guild .. ">") or "" }, " "))
    -- (our story of them, and the days we met, a line each)
    local lines = {}
    for _, para in ipairs(Jn.PersonStory(c.name) or {}) do
        for _, line in ipairs(Lines(para, FONT.body, RIGHT_W - 40)) do lines[#lines + 1] = { text = line } end
        lines[#lines + 1] = { gap = true }
    end
    local keys = {}
    for key in pairs(p.days or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return a > b end)
    if #keys > 0 then lines[#lines + 1] = { rubric = "DAYS WE MET" } end
    for _, key in ipairs(keys) do
        if Jn.Day(key) then lines[#lines + 1] = { day = key, text = Jn.DayTitle(key) } end
    end
    people.lines = lines
    local y = 90
    r.rows = r.rows or {}
    local n = 0
    for _, l in ipairs(lines) do
        if y > RIGHT_H - 30 then break end
        if l.gap then
            y = y + PARA
        else
            n = n + 1
            local fs = r.rows[n]
            if not fs then
                fs = Style.Link(r, FONT.body, function(self) if self.day then BP.ToDay(self.day) end end)
                r.rows[n] = fs
            end
            fs.day = l.day
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -y)
            fs.label:SetFontObject(l.rubric and FONT.headingRubric or FONT.body)
            fs:SetText(l.rubric or l.text)
            fs:Show()
            y = y + UNIT + (l.rubric and 6 or 0)
        end
    end
    for i = n + 1, #r.rows do r.rows[i]:Hide() end
end

function BP.OpenPerson(i)
    if not (people.list and people.list[i]) then return end
    people.sel = i
    people.listFrame:SetData(PeopleItems(), true)
    PersonRight()
end

function BP.PeopleMove(step)
    local n = #(people.list or {})
    local i = math.max(1, math.min(n, people.sel + step))
    if i == people.sel or n == 0 then return end
    Style.PlaySound("pageTurn")
    BP.OpenPerson(i)
    local list = people.listFrame
    local offset, rows = list.offset or 0, list.numRows or 20
    if i <= offset or i > offset + rows - 2 then list:SetOffset(math.max(0, i - 3)) end
end

-- A day a companion was met: the Diary, open at it
function BP.ToDay(key)
    diary.open, diary.leaf = key, 1
    J.TurnTo("journey")
    BP.OpenDay(key, true)
end

-- (a plate clicked: Social Diary opens the zone's whole map on the page,
-- its Full.lua, not copied; nothing yet)
function YourDiary.OpenFull() end

-- (a name in a note on a plate: their page)
function YourDiary.OpenPerson(guid)
    local name = BD.NameOf(guid)
    if not name then return end
    J.TurnTo("people")
    for i, c in ipairs(people.list or IF.JournalBook.Companions()) do
        if c.name == name then BP.OpenPerson(i) end
    end
end

local function BuildPeople(container)
    local head = Style.Text(container, FONT.page)
    head:SetPoint("TOPLEFT", LEFT_X, -20)
    head:SetText("Companions")
    people.count = Style.Text(container, FONT.small)
    people.count:SetPoint("TOPLEFT", LEFT_X, -HEAD.who)
    people.listFrame = List(container)
    local r = CreateFrame("Frame", nil, container)
    r:SetPoint("TOPLEFT", RIGHT_X + 8, -(TOP + 8))
    r:SetSize(RIGHT_W - 16, RIGHT_H - 16)
    Style.PersonHeading(r, r, RIGHT_W - 16, 20)
    people.right = r
end

local function RefreshPeople()
    BD.People()
    local items = PeopleItems()
    people.sel = math.max(1, math.min(people.sel, #(people.list or {})))
    items = PeopleItems()
    people.count:SetText(#people.list == 1 and "1 person met" or (#people.list .. " people met"))
    people.listFrame:SetData(items, true)
    PersonRight()
end

---------------------------------------------------------------------------
-- Registered with the copied book (UI/Journal/Pages.lua)
---------------------------------------------------------------------------
J.RegisterPage("journey", {
    order = 10, leaf = 1, buildOrder = 10,
    ribbon = { colour = "green", label = "Diary" },
    build = function(container)
        measure = measure or Style.Text(container, FONT.body)
        measure:Hide()
        BuildDiary(container)
    end,
    refresh = RefreshDiary,
})

J.RegisterPage("people", {
    order = 20, leaf = 2, buildOrder = 20,
    ribbon = { colour = "red", label = "Companions" },
    build = function(container)
        measure = measure or Style.Text(container, FONT.body)
        measure:Hide()
        BuildPeople(container)
    end,
    refresh = RefreshPeople,
})

-- (what the copied book calls on pages of Social Diary's not copied)
ns.UI.Entry = ns.UI.Entry or { Refresh = function() end }
J.RefreshIntroLabel = function() end
J.RefreshList = function() if ns.UI.JournalShowing("people") then RefreshPeople() end end
J.RefreshProfile = function() end
J.RefreshTimelineList = function() end
J.EndEdit = function() end
J.StackCounts = J.StackCounts or function() return 2, 0 end
