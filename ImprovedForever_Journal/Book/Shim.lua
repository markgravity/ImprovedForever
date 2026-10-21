-- The ground the book stands on. Book/ holds Social Diary's look, copied
-- (MIT, LICENSE-SocialDiary.md): its paper, ink, plates, cards and book,
-- each file as it was but for what the header of each says was changed.
-- They read what Social Diary's own core gives them (ns.Setting, ns.On,
-- ns.Journey...); this file gives the same names over our Journal instead,
-- before any of them loads. Our data comes in through BookData.lua.
local addonName, ns = ...
local IF = ImprovedForever

ns.UI = ns.UI or {}

---------------------------------------------------------------------------
-- Settings: the book's own, fixed (no settings page of theirs)
---------------------------------------------------------------------------
ns.db = { settings = {
    flatSheets = false,   -- paper with its turn, shadow and lift
    revealMap = false,    -- only the areas explored (no unexplored overlay data)
    bookStack = false,    -- the pages under the open ones, a still stack
    frontRead = true,     -- no introduction: straight to the diary
}, characters = {}, diary = {} }

function ns.Setting(key)
    return ns.db.settings[key]
end

function ns.BufferDays() return 30 end
ns.DAY = 86400
ns.diaryShared = false
ns.OwnCharacters = {}
ns.ownGUID = UnitGUID and UnitGUID("player") or nil

function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    IF.Print(msg)
end

function ns.DebugOn() return false end
function ns.RegisterStore() end

---------------------------------------------------------------------------
-- Time, secrets, identity
---------------------------------------------------------------------------
function ns.Now()
    return GetServerTime()
end

function ns.DayStart(t)
    local d = date("*t", t or ns.Now())
    d.hour, d.min, d.sec = 0, 0, 0
    return time(d)
end

local issecretvalue = issecretvalue

function ns.IsSecret(value)
    if not issecretvalue then return false end
    return issecretvalue(value)
end

-- `value` when it's safe to use, else `fallback`
function ns.Plain(value, fallback)
    if issecretvalue and issecretvalue(value) then return fallback end
    return value
end

function ns.SafeGUID(guid)
    local plain = ns.Plain(guid)
    if type(plain) ~= "string" or plain:sub(1, 7) ~= "Player-" then return nil end
    return plain
end

function ns.MapName(mapID)
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and ns.Plain(info.name) or nil
end

---------------------------------------------------------------------------
-- Events: the game's through a frame of ours, the book's own by name
---------------------------------------------------------------------------
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end)

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        -- (the book's own messages are SD_*: not the game's)
        if not event:find("^SD_") then pcall(events.RegisterEvent, events, event) end
    end
    local list = handlers[event]
    list[#list + 1] = fn
end

function ns.Fire(event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end

---------------------------------------------------------------------------
-- People and the diary: ours (JournalPeople.lua) where the book asks
---------------------------------------------------------------------------
ns.Characters = {}
function ns.Characters.Get(id) return ns.db.characters[id] end
function ns.Characters.Name(id)
    local c = ns.db.characters[id]
    return c and c.name or (type(id) == "string" and not id:find("^Player%-") and id) or nil
end
function ns.Characters.FullName(id) return ns.Characters.Name(id) end

ns.Diary = {}
function ns.Diary.Get(id) return ns.db.characters[id] end
function ns.Diary.Count() return 0 end
function ns.Diary.IsDiary(id) return ns.db.characters[id] ~= nil end

ns.People = {}
ns.Sessions = {}
function ns.Sessions.Duration(s) return s and ((s.to or s.from or 0) - (s.from or 0)) or 0 end

---------------------------------------------------------------------------
-- The road: points as BookData.lua hands them over (flat x, y, x, y...)
---------------------------------------------------------------------------
ns.Journey = {}
function ns.Journey.Points(seg) return seg.pts or {} end
function ns.Journey.MapYards() return nil end
function ns.Journey.FightIndex() return {} end
function ns.Journey.FightWho() return nil end
function ns.Journey.For() return nil end
function ns.Journey.CountedOn() return nil end
function ns.Journey.List() return {} end
function ns.ProjectMapPos() return nil end
-- (their features' lists and moments, registered as they load: the lists
-- are BookData.lua's, made from our days; nothing to register)
function ns.Journey.RegisterList() end
function ns.Journey.Append() end
ns.JourneyCapture = { On = function() return true end }
ns.JourneyRecap = { MainActivity = function() return nil end, RegisterMoment = function() end,
    LevelAt = function() return nil end }
ns.CreatureNames = { Note = function() end, Of = function(_, _, name) return name end }
function ns.Where() return nil end
function ns.IsAddOnLoaded(name)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    return loaded and loaded(name) or false
end

---------------------------------------------------------------------------
-- An item's quality from its link
---------------------------------------------------------------------------
ns.Timeline = {}
local QUALITY_COLOUR = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}
function ns.Timeline.Quality(link)
    if type(link) ~= "string" then return nil end
    local quality = link:match("|cn[^:|]-IQ(%d+):")
    if quality then return tonumber(quality) end
    local colour = link:match("|c%x%x(%x%x%x%x%x%x)")
    return colour and QUALITY_COLOUR[colour:lower()] or nil
end

---------------------------------------------------------------------------
-- The kinds whose Kind.lua isn't copied (Deaths', Firsts', Duels': they
-- register with Social Diary's own timeline); Hunts', Close calls' and
-- Profession caps' are (their rules: bad and good luck, a cap reached)
---------------------------------------------------------------------------
ns.Deaths = {}
ns.Firsts = {}
ns.Duels = { COUNT = { won = "won", lost = "lost", fled = "fled", they_fled = "theyFled" } }
function ns.Duels.Balance(c)
    local up = (c.won or 0) + (c.theyFled or 0)
    local down = (c.lost or 0) + (c.fled or 0)
    if up ~= down then return up > down and "won" or "lost" end
    return (c.last == "won" or c.last == "they_fled") and "won" or "lost"
end
function ns.Deaths.List(j) return j and j.deaths or {} end
function ns.Deaths.LookUp() return nil end
function ns.Firsts.List(j) return j and j.firsts or {} end
function ns.Duels.List(j) return j and j.duels or {} end
