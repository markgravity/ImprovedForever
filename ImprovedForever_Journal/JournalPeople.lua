-- The people of the journal: everyone met on the road, kept per character
-- (IF.charDB.journal.people[name]), and the day's dealings with them (as the
-- day's events, Journal.lua): talk in /say, whispers and party chat (short
-- snippets of both sides), emotes aimed at me or by me, trades, time and
-- deeds in a group, who brought whom back, letters, duels.
--   person = { class, classToken, race, raceToken, raceID, sex, guild, level, realm, first = { day, zone,
--     sub, t }, last (time), dayCount, days = { [key] = true } (the last
--     few), heard (their last line overheard), n = { grouped (seconds),
--     quests, kills, allyDeaths, revivedMe, talks, lines, mine, whispersIn,
--     whispersOut, emotesIn, emotesOut, trades, gifts, sent, duels, heard,
--     seen }, log = { { k, t, day, dir, text } }: our last dealings, the newest
--     last: "emote", "talk" (text: its first line), "trade", "group", "revive",
--     "gift", "sent", "duel" }
-- Who someone is comes from their chat line (its GUID), the group, the
-- target; never a nameplate.
local IF = ImprovedForever

local J = IF.Journal
local I = J.Internal

local PE = {}
J.People = PE

local MAX_PEOPLE = 400         -- kept; the least known go first
local MAX_DAYS = 30            -- days remembered per person (their count goes on)
local SNIPPET = 140            -- a line kept this long at most
local TALK_GAP = 120           -- quiet this long (seconds): the talk is over
local MAX_SAID = 8             -- lines kept a talk
local NEAR = 60                -- my /say line this soon after theirs: to them
local MAX_TALKS = 150          -- talks kept a day (a chatty day leaves room for the rest)
local MAX_ALOUD = 20           -- my lines to no one, kept a day

-- Room left today for another of these (talk, aloud)
local function Room(kind, max)
    local s = J.Day().stats
    s.social = s.social or {}
    if (s.social[kind] or 0) >= max then return false end
    s.social[kind] = (s.social[kind] or 0) + 1
    return true
end

---------------------------------------------------------------------------
-- The people kept
---------------------------------------------------------------------------
local function People()
    local db = I.Store()
    db.people = db.people or {}
    return db.people
end

local function Me()
    return UnitName("player")
end

-- A name from the chat ("Rice-Banshee" on my realm: "Rice")
-- Whether a name is plain text: valid UTF-8, no control bytes (Forever's
-- emote events can carry a garbled sender)
local function Readable(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local len = c < 0x20 and 0 or c < 0x80 and 1 or c >= 0xC2 and c < 0xE0 and 2 or c >= 0xE0 and c < 0xF0 and 3
            or c >= 0xF0 and c < 0xF5 and 4 or 0
        if len == 0 then return false end
        for k = 1, len - 1 do
            local b = s:byte(i + k)
            if not b or b < 0x80 or b > 0xBF then return false end
        end
        i = i + len
    end
    return true
end

local function Clean(name)
    if not name or I.Secret(name) or name == "" then return nil end
    if not Readable(name) then return nil end
    -- (a protected name, "|K...|k" (Battle.net), or one with the game's codes
    -- in it: not something to keep or show)
    if name:find("|", 1, true) or name:find("[%z\1-\31]") then return nil end
    if Ambiguate then name = Ambiguate(name, "none") end
    return name
end

-- How well I know someone: more for what we did together than for talk
-- overheard
function PE.Score(p)
    local n = p.n or {}
    return (n.grouped or 0) / 300 + (n.talks or 0) * 3 + (n.whispersIn or 0) + (n.whispersOut or 0)
        + (n.emotesIn or 0) + (n.emotesOut or 0) + (n.trades or 0) * 3 + (n.gifts or 0) * 3 + (n.sent or 0) * 2
        + (n.quests or 0) * 2 + (n.revivedMe or 0) * 3 + (n.duels or 0) * 2 + (n.heard or 0) * 0.1 + (n.seen or 0) * 0.05
end

local function Prune(people)
    local names = {}
    for name in pairs(people) do names[#names + 1] = name end
    if #names <= MAX_PEOPLE then return end
    table.sort(names, function(a, b)
        local sa, sb = PE.Score(people[a]), PE.Score(people[b])
        if sa ~= sb then return sa < sb end
        return (people[a].last or 0) < (people[b].last or 0)
    end)
    for i = 1, #names - MAX_PEOPLE do people[names[i]] = nil end
end

-- Someone kept (made, the first time they're met)
function PE.Get(name, make)
    if not name then return nil end
    local people = People()
    local p = people[name]
    if not p and make then
        p = { first = { day = J.TodayKey(), zone = I.Zone(), sub = I.Sub(), t = time() }, n = {}, days = {} }
        people[name] = p
        Prune(people)
    end
    return p
end

local function Count(p, what, by)
    p.n[what] = (p.n[what] or 0) + (by or 1)
end

-- A dealing remembered, for their page (the last few)
local MAX_LOG = 12
local function Log(p, kind, fields)
    fields = fields or {}
    fields.k, fields.t, fields.day = kind, time(), J.TodayKey()
    p.log = p.log or {}
    p.log[#p.log + 1] = fields
    while #p.log > MAX_LOG do table.remove(p.log, 1) end
end
PE.Log = Log

-- Seen today
local function Seen(p)
    p.last = time()
    local key = J.TodayKey()
    if p.days[key] then return end
    p.days[key] = true
    p.dayCount = (p.dayCount or 0) + 1
    local keys = {}
    for k in pairs(p.days) do keys[#keys + 1] = k end
    if #keys > MAX_DAYS then
        table.sort(keys)
        for i = 1, #keys - MAX_DAYS do p.days[keys[i]] = nil end
    end
end

-- Who they are: from a chat line's GUID, or a unit (the group, the target)
local function FromGUID(p, guid)
    if not guid or I.Secret(guid) or not GetPlayerInfoByGUID then return end
    local ok, class, classToken, race, raceToken, sex, _, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok or not class or I.Secret(class) then return end
    p.class, p.classToken, p.race, p.raceToken, p.sex = class, classToken, race, raceToken, sex
    if realm and realm ~= "" then p.realm = realm end
end

local function FromUnit(p, unit)
    if not UnitExists(unit) then return end
    local class, token = UnitClass(unit)
    local race, raceToken, raceID = UnitRace(unit)
    local level = UnitLevel(unit)
    if class and not I.Secret(class) then p.class, p.classToken = class, token end
    if race and not I.Secret(race) then p.race, p.raceToken, p.raceID = race, raceToken, raceID end
    if level and not I.Secret(level) and level > 0 then p.level = level end
    local sex = UnitSex and UnitSex(unit)
    if sex and not I.Secret(sex) then p.sex = sex end
    local guild = GetGuildInfo and GetGuildInfo(unit)
    if guild and not I.Secret(guild) then p.guild = guild end
end

---------------------------------------------------------------------------
-- The group: who's with me (each event I keep while grouped names them),
-- time together, their falls and growing, who invited me
---------------------------------------------------------------------------
local function Units()
    local list = {}
    local raid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, n do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        local name = Clean(UnitName(unit))
        if name and name ~= Me() then list[#list + 1] = { name = name, unit = unit } end
    end
    return list
end

function PE.Companions()
    local names = {}
    for _, u in ipairs(Units()) do names[#names + 1] = u.name end
    if #names == 0 then return nil end
    table.sort(names)
    return names
end

local invite                   -- { name, at }: who asked me to join them
function PE.InvitedBy()
    local r = I.Recent(invite, 120)
    return r and r.name or nil
end

function PE.Revived(name)
    local p = PE.Get(Clean(name), true)
    if p then
        Count(p, "revivedMe")
        Seen(p)
        Log(p, "revive")
    end
end

local state = {}               -- [name] = { dead, level }: each companion as last seen
local function Group(step)
    for _, u in ipairs(Units()) do
        local p = PE.Get(u.name, true)
        FromUnit(p, u.unit)
        Seen(p)
        if step then Count(p, "grouped", step) end
        local was = state[u.name]
        if not was then Log(p, "group") end
        local dead = UnitIsDeadOrGhost(u.unit) and true or false
        local level = p.level
        if was then
            if dead and not was.dead then Count(p, "allyDeaths") end
            if level and was.level and level > was.level and I.On("levels") then
                I.Add("ally_level", { who = u.name, level = level })
            end
        end
        state[u.name] = { dead = dead, level = level }
    end
end

-- Deeds done together: counted for each companion
local function Together(what)
    for _, u in ipairs(Units()) do
        local p = PE.Get(u.name, true)
        Count(p, what)
    end
end

---------------------------------------------------------------------------
-- Talk: a line from someone, or from me to them; a talk goes on while lines
-- keep coming (a short snippet of each)
---------------------------------------------------------------------------
local talks = {}               -- [name] = { event, last, channel }: the talk going on

local function Snip(text)
    if not text or I.Secret(text) then return nil end
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if #text > SNIPPET then text = text:sub(1, SNIPPET - 1) .. "…" end
    return text
end

local function Talk(name, channel, mine, text)
    if not I.On() then return end
    local line = Snip(text)
    if not name or not line then return end
    local p = PE.Get(name, true)
    Seen(p)
    local open = talks[name]
    local now = time()
    if not open or now - open.last > TALK_GAP or open.channel ~= channel or not open.event then
        if not Room("talk", MAX_TALKS) then return end
        open = { event = I.Add("talk", { with = name, channel = channel, lines = 0, mine = 0, said = {} }),
            channel = channel }
        talks[name] = open
        Count(p, "talks")
        Log(p, "talk", { channel = channel, text = line, dir = mine and "out" or "in" })
    end
    open.last = now
    local e = open.event
    if not e then return end
    e.lines = e.lines + 1
    if mine then
        e.mine = e.mine + 1
        Count(p, "mine")
    else
        Count(p, "lines")
    end
    if #e.said < MAX_SAID then e.said[#e.said + 1] = { mine and 1 or 0, line } end
    I.Changed()
end

-- Whom my line in /say (or party chat) is to: the one I was just talking
-- with, else my target if it's a player
local function Partner(channel)
    local best, at
    for name, t in pairs(talks) do
        if t.channel == channel and time() - t.last < NEAR and (not at or t.last > at) then best, at = name, t.last end
    end
    if best then return best end
    if channel == "say" and UnitIsPlayer("target") then return Clean(UnitName("target")) end
end

-- A line in /say (/yell, a /e emote line): to me (my name in it, a talk
-- going on, my target, my group), else just heard
local function Heard(channel, text, sender, guid)
    local name = Clean(sender)
    if not name then return end
    if name == Me() then
        local to = Partner(channel == "yell" and "say" or channel)
        if to then return Talk(to, "say", true, text) end
        if I.On() and Snip(text) and Room("aloud", MAX_ALOUD) then I.Add("aloud", { text = Snip(text) }) end
        return
    end
    local p = PE.Get(name, true)
    FromGUID(p, guid)
    Seen(p)
    Count(p, "heard")
    p.heard = Snip(text) or p.heard
    local me = Me()
    local toMe = (me and type(text) == "string" and not I.Secret(text) and text:lower():find(me:lower(), 1, true))
        or talks[name] and time() - talks[name].last < TALK_GAP
        or UnitIsPlayer("target") and Clean(UnitName("target")) == name
        or UnitInParty and UnitInParty(name)
    if toMe then Talk(name, "say", false, text) end
end

---------------------------------------------------------------------------
-- Emotes: at me, or mine at someone ("Rice waves at you.", "You wave at
-- Rice."); the rest only heard
---------------------------------------------------------------------------
local function Emote(text, sender, guid)
    -- (who: by the line's GUID, as the chat itself shows players; the sender
    -- only if it's readable)
    local byGUID
    if guid and not I.Secret(guid) and GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, gname, realm = pcall(GetPlayerInfoByGUID, guid)
        if ok and gname and not I.Secret(gname) then byGUID = Clean(gname) end
    end
    local name = byGUID or Clean(sender)
    -- (neither: the name the line begins with, "Samia Arkanistra sighs at you.")
    if not name and type(text) == "string" and not I.Secret(text) then
        local lead = text:match("^(.-)%s+%l")
        if lead and lead ~= "You" and lead:match("^%u") then name = Clean(lead) end
    end
    if not text or I.Secret(text) or not I.On() then return end
    -- (a line that begins "You ...": mine, whatever the sender says)
    if text:match("^You%s") then name = Me() end
    if not name then return end
    if name == Me() then
        -- (at whom: my target, else anyone seen lately whose name it says)
        local target = UnitIsPlayer("target") and Clean(UnitName("target"))
        if not (target and text:find(target, 1, true)) then
            target = nil
            for who, p in pairs(People()) do
                if (p.last or 0) > time() - 600 and #who > 2 and text:find(who, 1, true)
                    and (not target or #who > #target) then
                    target = who
                end
            end
        end
        if target then
            local p = PE.Get(target, true)
            Seen(p)
            Count(p, "emotesOut")
            Log(p, "emote", { dir = "out", text = Snip(text) })
            I.Add("emote", { with = target, dir = "out", text = Snip(text) })
        end
        return
    end
    local p = PE.Get(name, true)
    FromGUID(p, guid)
    Seen(p)
    local me = Me()
    local lower = text:lower()
    if lower:find("%f[%a]you%f[%A]") or lower:find("%f[%a]your%f[%A]") or (me and lower:find(me:lower(), 1, true)) then
        Count(p, "emotesIn")
        Log(p, "emote", { dir = "in", text = Snip(text) })
        I.Add("emote", { with = name, dir = "in", text = Snip(text) })
    else
        Count(p, "heard")
    end
end

---------------------------------------------------------------------------
-- Trades: what went each way, kept once it's done
---------------------------------------------------------------------------
local trade                    -- { with, gave, got, gaveMoney, gotMoney } while the window is open

local function TradeItems(info, link)
    local list = {}
    for i = 1, 6 do
        local name, _, count = info(i)
        local id = I.ItemID(link(i))
        if name and id then list[#list + 1] = { id, count or 1 } end
    end
    return list
end

local function TradeRead()
    if not trade then return end
    pcall(function()
        trade.gave = TradeItems(GetTradePlayerItemInfo, GetTradePlayerItemLink)
        trade.got = TradeItems(GetTradeTargetItemInfo, GetTradeTargetItemLink)
        local mine, theirs = GetPlayerTradeMoney(), GetTargetTradeMoney()
        trade.gaveMoney = not I.Secret(mine) and mine > 0 and mine or nil
        trade.gotMoney = not I.Secret(theirs) and theirs > 0 and theirs or nil
    end)
end

local function TradeDone()
    if not trade or not I.On("loot") then return end
    TradeRead()
    local t = trade
    trade = nil
    local p = PE.Get(t.with, true)
    if p then
        Count(p, "trades")
        Log(p, "trade")
        Seen(p)
    end
    -- (the money that changed hands: the trade's, not a line of its own)
    J.Claim("trade")
    I.Add("trade", { with = t.with, gave = t.gave, got = t.got, gaveMoney = t.gaveMoney, gotMoney = t.gotMoney })
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local tradeDone                -- the game's "Trade complete." line
local events = CreateFrame("Frame")
local HANDLERS = {
    CHAT_MSG_SAY = function(text, sender, _, _, _, _, _, _, _, _, _, guid) Heard("say", text, sender, guid) end,
    CHAT_MSG_YELL = function(text, sender, _, _, _, _, _, _, _, _, _, guid) Heard("yell", text, sender, guid) end,
    CHAT_MSG_EMOTE = function(text, sender, _, _, _, _, _, _, _, _, _, guid) Heard("say", text, sender, guid) end,
    CHAT_MSG_TEXT_EMOTE = function(text, sender, _, _, _, _, _, _, _, _, _, guid) Emote(text, sender, guid) end,
    CHAT_MSG_WHISPER = function(text, sender, _, _, _, _, _, _, _, _, _, guid)
        local name = Clean(sender)
        local p = PE.Get(name, true)
        if not p then return end
        FromGUID(p, guid)
        Count(p, "whispersIn")
        Talk(name, "whisper", false, text)
    end,
    CHAT_MSG_WHISPER_INFORM = function(text, target)
        local name = Clean(target)
        local p = PE.Get(name, true)
        if not p then return end
        Count(p, "whispersOut")
        Talk(name, "whisper", true, text)
    end,
    CHAT_MSG_PARTY = function(text, sender, _, _, _, _, _, _, _, _, _, guid)
        local name = Clean(sender)
        if name == Me() then
            local to = Partner("party")
            if to then Talk(to, "party", true, text) end
            return
        end
        local p = PE.Get(name, true)
        if not p then return end
        FromGUID(p, guid)
        Talk(name, "party", false, text)
    end,
    PARTY_INVITE_REQUEST = function(name)
        name = Clean(name)
        if name then invite = { name = name, at = GetTime() } end
    end,
    GROUP_ROSTER_UPDATE = function() Group() end,
    PLAYER_TARGET_CHANGED = function()
        if not UnitIsPlayer("target") or not I.On() then return end
        local name = Clean(UnitName("target"))
        if not name or name == Me() then return end
        local p = PE.Get(name, true)
        FromUnit(p, "target")
        Count(p, "seen")
        Seen(p)
    end,
    QUEST_TURNED_IN = function() Together("quests") end,
    CHAT_MSG_COMBAT_XP_GAIN = function() Together("kills") end,
    TRADE_SHOW = function()
        local name = Clean(UnitName("NPC"))
        trade = name and { with = name } or nil
    end,
    TRADE_PLAYER_ITEM_CHANGED = TradeRead,
    TRADE_TARGET_ITEM_CHANGED = TradeRead,
    TRADE_MONEY_CHANGED = TradeRead,
    TRADE_ACCEPT_UPDATE = TradeRead,
    UI_INFO_MESSAGE = function(_, msg)
        if tradeDone and msg == tradeDone then TradeDone() end
    end,
    TRADE_CLOSED = function()
        -- (closed: done, else let go a moment later, the done line may come after)
        C_Timer.After(1, function() trade = nil end)
    end,
}
HANDLERS.CHAT_MSG_PARTY_LEADER = HANDLERS.CHAT_MSG_PARTY

events:SetScript("OnEvent", function(_, event, ...)
    if not IF.charDB or not I.On() then return end
    local fn = HANDLERS[event]
    if fn then fn(...) end
end)

-- Letters and duels kept by the journal: counted for the one they were with
J.OnAdd(function(e)
    local name = e.k == "duel" and e.opponent or e.k == "mail" and e.kind == "letter" and e.from
        or e.k == "sent" and e.to or e.k == "money" and e.src == "letter" and e.from or nil
    local p = PE.Get(Clean(name), name ~= nil)
    if not p then return end
    Count(p, e.k == "duel" and "duels" or e.k == "sent" and "sent" or "gifts")
    Log(p, e.k == "duel" and "duel" or e.k == "sent" and "sent" or "gift", { won = e.won })
    Seen(p)
end)

IF.OnLogin(function()
    tradeDone = _G.ERR_TRADE_COMPLETE
    for event in pairs(HANDLERS) do pcall(events.RegisterEvent, events, event) end
    Group()
    C_Timer.NewTicker(10, function()
        if I.On() and IsInGroup and IsInGroup() then Group(10) end
    end)
end)
