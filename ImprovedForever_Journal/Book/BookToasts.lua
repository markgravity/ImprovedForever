-- The book's cards in play, on Social Diary's toast (the copied
-- UI/Windows/Reunion/Toast.lua: a loose sheet laid at the top of the
-- screen, its heading in red capitals, a portrait, a name, a line or two):
--   a reunion: someone met on an earlier day joins my group, or is my
--     target: who they are, when and where we last met;
--   a moment: I grew stronger, fell, or found my first green, blue or
--     epic item (Journal.lua's J.OnFirst: never guessed from the cache).
-- One at a time, a while each (longer under the mouse); never in combat
-- (held until it's over), never the pad's (a click opens the book, a
-- right-click puts it away), no sound. Settings: the Journal tab's
-- Reunions and Moments.
local addonName, ns = ...
local IF = ImprovedForever
local Jn = IF.Journal

local Toast = ns.UI.Toast
local BD = ns.BookData

local SHOW = 7                 -- seconds a card stays
local HOVER = 3                -- ...and after the mouse leaves it
local AGAIN = 3600             -- a person's reunion no sooner than this after the last
local QUEUE_MOST = 4

local queue, host = {}, nil
local shownAt, over, overUntil = 0, false, 0
local greeted = {}             -- [name] = when their card last came up

local function On(key)
    return IF.db and Jn.Settings().enabled and Jn.Settings()[key]
end

local function Hide()
    if host then
        host:Hide()
        host.view:Hide()
    end
    Toast.showing = nil
end

-- (what the copied card asks of its queue, Queue.lua not copied)
function Toast.Dismiss() Hide() end
function Toast.Hover(on)
    over = on and true or false
    if not on then overUntil = GetTime() + HOVER end
end
function Toast.StopPlacing() end

local function Next()
    if Toast.showing or IF.InCombat() or #queue == 0 then return end
    local snap = table.remove(queue, 1)
    if not host then
        host = Toast.Build()
        -- (a click: their page, or the moment's day; a right-click: away)
        host.button:SetScript("OnClick", function(_, which)
            local shown = Toast.showing
            Hide()
            if which == "RightButton" or not shown or IF.InCombat() then return end
            if shown.guid then
                ns.UI.ShowJournal()
                ns.UI.YourDiary.OpenPerson(shown.guid)
            elseif shown.key then
                IF.JournalBook.Open(shown.key)
            end
        end)
    end
    local ok, err = pcall(host.Fill, host, snap)
    if not ok then return IF.Print("Journal: " .. tostring(err)) end
    Toast.showing = snap
    host:Show()
    host.view:Show()
    shownAt, over = GetTime(), false
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    if Toast.showing then
        if IF.InCombat() then return Hide() end
        local now = GetTime()
        if not over and now - shownAt > SHOW and now > overUntil then Hide() end
    else
        Next()
    end
end)

local function Push(snap)
    if #queue >= QUEUE_MOST then table.remove(queue, 1) end
    queue[#queue + 1] = snap
end

---------------------------------------------------------------------------
-- Reunions
---------------------------------------------------------------------------
-- A name as the journal keeps it (its first word: Forever's chat names
-- carry a surname)
local function Plain(name)
    name = ns.Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then name = Ambiguate(name, "none") end
    return name:match("^(%S+)") or name
end

local function Reunion(name, reason)
    if not (name and On("reunions")) then return end
    local p = Jn.People and Jn.People.Get(name)
    if not (p and p.days) then return end
    -- (when we last met: the latest day before today)
    local today, last, times = Jn.TodayKey(), nil, 0
    for key in pairs(p.days) do
        if key < today then
            times = times + 1
            if not last or key > last then last = key end
        end
    end
    if not last then return end
    if greeted[name] and time() - greeted[name] < AGAIN then return end
    greeted[name] = time()
    local lastZone
    local day = Jn.Day(last)
    for _, e in ipairs(day and day.events or {}) do
        for _, n in ipairs(e.group or {}) do
            if n == name and e.zone then lastZone = e.zone end
        end
        if (e.with == name or e.who == name) and e.zone then lastZone = e.zone end
    end
    Push({ guid = BD.Guid(name), reason = reason, name = name,
        record = { class = p.classToken, race = p.raceToken, level = p.level, sex = p.sex },
        guild = p.guild, timesMet = times, lastMet = Jn.KeyTime(last), lastZone = lastZone })
end

---------------------------------------------------------------------------
-- Moments
---------------------------------------------------------------------------
local function Moment(heading, name, stories, who, key)
    if not On("moments") then return end
    Push({ key = key or Jn.TodayKey(), name = name,
        text = { heading = heading, name = name, who = who and { who } or nil, stories = stories } })
end

local QUALITY_WORD = { [2] = "green", [3] = "blue", [4] = "epic" }

Jn.OnAdd(function(e)
    if e.k == "level" then
        local where = e.sub and e.zone and e.sub ~= e.zone and (e.sub .. ", " .. e.zone) or e.zone
        Moment("Grew stronger", "Level " .. (e.level or "?"), { "The road was making me stronger, one day at a time." },
            where and ("at " .. where))
    elseif e.k == "death" then
        Moment("A close call", e.by and ("Fell to " .. e.by) or "I fell",
            { e.sub and ("At " .. e.sub .. ". Not a day to be proud of.") or "Not a day to be proud of." })
    end
end)

-- (the first of a quality the journal ever kept: Journal.lua says when)
Jn.OnFirst(function(quality, e)
    local id = e.item or e.reward
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name = id and get(id)
    Moment("My first " .. QUALITY_WORD[quality] .. " item!", name or "Something fine",
        { e.k == "quest" and "A reward, for a task well done." or "Found on the road, and kept." })
end)

---------------------------------------------------------------------------
-- When someone is about
---------------------------------------------------------------------------
local inGroup = {}

local events = CreateFrame("Frame")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        local now = {}
        local raid = IsInRaid and IsInRaid()
        for i = 1, GetNumGroupMembers and GetNumGroupMembers() or 0 do
            local name = Plain(UnitName(raid and ("raid" .. i) or ("party" .. i)))
            if name then
                now[name] = true
                if not inGroup[name] then Reunion(name, "group") end
            end
        end
        inGroup = now
    elseif UnitIsPlayer and UnitIsPlayer("target") and not (UnitIsUnit and UnitIsUnit("target", "player")) then
        Reunion(Plain(UnitName("target")), "nearby")
    end
end)
