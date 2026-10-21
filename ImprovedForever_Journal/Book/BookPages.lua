-- The book's pages, ours, laid out as Social Diary's Your Diary and People
-- pages are (its UI/Journey/Left.lua and Page.lua, UI/Journal/People.lua
-- and Profile.lua, not copied): the Diary (green ribbon) the days down the
-- left page, the open one's paragraphs under it a rubric each (its words,
-- JournalWriter.lua), the open paragraph's plates on the right page as a
-- level's (BookData.lua into the copied UI/Journey/Caption.lua); the
-- Companions (red ribbon)
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
        row.aside:SetText(item.aside or "")
        local R = Style.RUBRIC
        Style.Shade(row.rule, "HORIZONTAL", R[1], R[2], R[3], 0.4, 0)
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
-- out beside it), the open day's words under its rubric with where the
-- time went; its plates on the right page, through the copied pipeline
-- as a level's are (UI/Journey/Caption.lua: one to three, their captions,
-- their margin's cards and leaders)
---------------------------------------------------------------------------
local diary = { open = nil, sel = 1 }
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

-- What stood out in a day, in a word or two beside its rubric
local function Aside(key, day)
    if key == Jn.TodayKey() then return "so far" end
    local bits, falls = {}, 0
    for _, ev in ipairs(day.events) do
        if ev.k == "death" then falls = falls + 1
        elseif ev.k == "level" then bits[#bits + 1] = "lv " .. (ev.level or "?")
        elseif ev.k == "duel" then bits[#bits + 1] = "a duel" end
    end
    if falls > 0 then table.insert(bits, 1, falls == 1 and "a fall" or (falls .. " falls")) end
    -- (a few at most: the rubric's rule runs on after them)
    return #bits > 0 and table.concat({ unpack(bits, 1, math.min(3, #bits)) }, ", ") or nil
end

-- The left page's items: the days, the open one's words and ledger
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
        items[#items + 1] = { title = Jn.DayTitle(key):upper(), aside = Aside(key, day), paraph = i, open = open,
            picked = i == diary.sel, height = open and OPEN_H or CLOSED,
            onClick = function() BP.OpenDay(key, true) end }
        rubrics[i] = #items
        if open then
            local paras = Jn.Write(key, day)
            for k, text in ipairs(paras or {}) do
                if k > 1 then items[#items + 1] = { height = PARA } end
                for _, line in ipairs(Lines(text, FONT.body, LINE_W)) do
                    items[#items + 1] = { text = line, font = FONT.body, height = UNIT }
                end
            end
            local zones = Jn.Zones(day)
            if #zones > 0 then items[#items + 1] = { height = 8 } end
            for _, name in ipairs(zones) do
                items[#items + 1] = { zone = name, time = Jn.Played(day.stats.zones[name]), height = UNIT }
            end
            local sig = Jn.Signature and Jn.Signature()
            if sig then items[#items + 1] = { text = sig, font = FONT.noteWritten, height = UNIT + 4 } end
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
-- The right page: the open day's plates, as a level's (debounced: they're
-- heavy)
---------------------------------------------------------------------------
local function DrawRight()
    local page = YourDiary.page
    if not page then return end
    for _, pool in ipairs(page.rightPools or {}) do pool:Begin() end
    page.links, page.sheets, page.moments = {}, {}, {}
    page.now, page.fights, page.ctx = ns.Now(), {}, {}
    page.nothing:Hide()
    local shown = 0
    local de = diary.open and BD.Use(diary.open)
    if de then
        local e = { kind = "level", key = diary.open, level = de.level, from = de.from, to = de.to, out = de.out,
            whole = true, deaths = {}, finds = {}, hunts = de.hunts }
        local ok, n = pcall(YourDiary.DrawPlates, e)
        if ok then shown = n or 0 else IF.Print("Journal: " .. tostring(n)) end
    end
    for i = shown + 1, #page.plates do page.plates[i]:Hide() end
    for _, pool in ipairs(page.rightPools or {}) do pool:Finish() end
    if shown == 0 then
        page.nothing:SetText(de and "Nothing of this day was kept on the map." or "Nothing written yet.")
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

-- A day opened: its words under its rubric, its plates on the right
function BP.OpenDay(key, now)
    if not key then return end
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

-- Left / right: the open day's words, a page at a time
function BP.DiaryTurn(step)
    local list = diary.list
    list:SetOffset((list.offset or 0) + step * math.max(1, (list.numRows or 20) - 4))
end

function BP.DiaryPages()
    return diary.sel, #(diary.keys or {})
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

-- Today, as it goes on: its words and plates again now and then while open
function BP.Changed()
    if not (ns.UI.JournalShowing and ns.UI.JournalShowing("journey")) then return end
    if diary.open ~= Jn.TodayKey() then return end
    RebuildDiary()
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
    diary.open = key
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
