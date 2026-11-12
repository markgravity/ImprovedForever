-- The spells you chose (the Immersion tab's Spell tracker: your list, per character, each tracked as it
-- is set: "ready" or "until"): a notice, a card in
-- the Immersion look (Card.lua) to the right of your character, when one of them is ready again (its
-- cooldown over) or its buff is used up (Lightning Shield's charges gone: the aura is gone, and you had
-- it); or, tracked "until", the spell's own card from its cast, its time running down, till it is ready.
-- A few seconds, one under another. In a fight Forever keeps auras and cooldown numbers secret: a
-- cooldown then runs on our own timer from your cast (readable), its length the one read out of a
-- fight, else the spell's base one; a buff used up in a fight is told when it ends. Setting
-- spellTracker; the list in IF.charDB.spellTracker.
local IF = ImprovedForever
local IN = IF.Interface

local ST = {}
IN.SpellTracker = ST

local OFFSET_X, OFFSET_Y = 230, -10      -- (from the screen's middle: right of your character)
local GAP = 10
local MAX_SPELLS, MAX_CARDS = 30, 4
local GCD_MAX = 1.6                      -- (a cooldown no longer than this is the global one)
local HOLD = 4                          -- (seconds a notice stays)
local READY, GONE, COOL = { 0.45, 0.9, 0.5 }, { 0.9, 0.3, 0.25 }, { 1, 0.62, 0.2 }

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
function ST.Ids()
    local d = IF.charDB
    if not d then return {} end
    d.spellTracker = d.spellTracker or {}
    d.spellTracker.ids = d.spellTracker.ids or {}
    return d.spellTracker.ids
end
ST.MAX = MAX_SPELLS

local function SpellName(id)
    local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    local ok, name = pcall(get, id)
    return ok and not Secret(name) and type(name) == "string" and name or nil
end
ST.SpellName = SpellName

local function SpellIcon(id)
    local ok, icon
    if C_Spell and C_Spell.GetSpellTexture then
        ok, icon = pcall(C_Spell.GetSpellTexture, id)
    end
    return ok and icon or select(3, GetSpellInfo(id))
end

-- How a spell (by name) is tracked: nil (not), "ready" (a notice when it is ready again), "until" (its
-- card from the cast, its time running down, till it is ready) or "missing" (a notice when its buff is
-- gone: Lightning Shield's charges used up)
function ST.Mode(name)
    for _, id in ipairs(ST.Ids()) do
        if SpellName(id) == name then
            local modes = IF.charDB and IF.charDB.spellTracker and IF.charDB.spellTracker.modes
            return modes and modes[name] or "ready"
        end
    end
    return nil
end

-- Set how a spellbook spell ({ name, spellID }) is tracked: "off", "ready", "until" or "missing"
function ST.SetMode(spell, mode)
    local ids = ST.Ids()
    for i = #ids, 1, -1 do
        if SpellName(ids[i]) == spell.name then table.remove(ids, i) end
    end
    local d = IF.charDB.spellTracker
    d.modes = d.modes or {}
    if mode == "off" then
        d.modes[spell.name] = nil
    elseif #ids < MAX_SPELLS then
        ids[#ids + 1] = spell.spellID
        d.modes[spell.name] = mode
    end
end

---------------------------------------------------------------------------
-- What is going on, per tracked spell (by name: a rank is the spell)
---------------------------------------------------------------------------
local state = {}     -- name -> { id, cd = { start, length }, present = bool|nil, goneAt = time|nil }
local lengths = {}   -- name -> its cooldown's length read out of a fight

local function Get(name, id)
    local s = state[name]
    if not s then
        s = { id = id }
        state[name] = s
    end
    s.id = id
    return s
end

-- Its cooldown read whole (out of a fight only): start, duration, or nil
local function ReadCooldown(id)
    if IF.InCombat() or not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(info) ~= "table" then return nil end
    local start, duration = info.startTime, info.duration
    if Secret(start) or Secret(duration) or type(start) ~= "number" or type(duration) ~= "number" then return nil end
    return start, duration
end

local function BaseLength(id)
    if not GetSpellBaseCooldown then return nil end
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    if not ok or Secret(ms) or type(ms) ~= "number" or ms <= GCD_MAX * 1000 then return nil end
    return ms / 1000
end

-- What is on you now, by name; nil when the game won't tell (a fight)
local function Helpful()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get or IF.InCombat() then return nil end
    local names = {}
    for i = 1, 80 do
        local ok, aura = pcall(get, "player", i, "HELPFUL")
        if not ok then return nil end
        if not aura then break end
        local name = aura.name
        if Secret(name) then return nil end
        if type(name) == "string" then names[name] = true end
    end
    return names
end

-- The notices showing: { name, id, kind = "ready" | "gone", until }. A spell's cooldown over, or its buff
-- used up, is told once, a few seconds, one card each, one under another. The same again replaces it.
local notices = {}
local function Push(name, id, kind)
    local now = GetTime()
    for i = #notices, 1, -1 do
        if notices[i].name == name then table.remove(notices, i) end
    end
    notices[#notices + 1] = { name = name, id = id, kind = kind, untilAt = now + HOLD }
    while #notices > MAX_CARDS do table.remove(notices, 1) end
end

local function LookAuras()
    local names = Helpful()
    if not names then return end
    local now = GetTime()
    for _, id in ipairs(ST.Ids()) do
        local name = SpellName(id)
        if name then
            local s = Get(name, id)
            if names[name] then
                s.present, s.goneAt = true, nil
            elseif s.present then
                -- (you had it, it is gone: used up)
                s.present, s.goneAt = false, now
                if ST.Mode(name) == "missing" then Push(name, id, "gone") end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "PLAYER_ENTERING_WORLD" then
        wipe(state)
        return
    end
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
        pcall(LookAuras)
        return
    end
    if Secret(spellID) or type(spellID) ~= "number" then return end
    local name = SpellName(spellID)
    if not name then return end
    for _, id in ipairs(ST.Ids()) do
        if SpellName(id) == name then
            local s = Get(name, id)
            s.goneAt = nil      -- (cast again: it is back)
            for i = #notices, 1, -1 do
                if notices[i].name == name then table.remove(notices, i) end
            end
            -- (its length: read whole out of a fight, else learnt before, else the spell's base one)
            local start, duration = ReadCooldown(spellID)
            local length = (duration and duration > GCD_MAX and duration) or lengths[name] or BaseLength(spellID)
            if length then
                lengths[name] = length
                s.cd = { start = (duration and duration > GCD_MAX) and start or GetTime(), length = length }
            end
        end
    end
end)

---------------------------------------------------------------------------
-- The cards
---------------------------------------------------------------------------
local cards = {}
for i = 1, MAX_CARDS do cards[i] = IN.Card.New("ImprovedForeverSpellTracker" .. i, { seamless = true }) end

local function Left(t)
    if t >= 60 then return math.ceil(t / 60) .. " min" end
    return math.ceil(t) .. " sec"
end

local function Content(item)
    local c = item.kind == "ready" and READY or (item.kind == "gone" and GONE or COOL)
    local lines
    if item.kind == "cd" then
        lines = {
            { lt = item.name, lr = c[1], lg = c[2], lb = c[3], rt = Left(item.left), rr = 0.8, rg = 0.8, rb = 0.8 },
            { lt = "Cooldown", lr = 0.78, lg = 0.78, lb = 0.78 },
        }
    else
        lines = {
            { lt = item.name, lr = c[1], lg = c[2], lb = c[3] },
            { lt = item.kind == "ready" and "Ready" or "Missing", lr = 0.78, lg = 0.78, lb = 0.78 },
        }
    end
    return {
        key = item.name .. "|" .. item.kind,
        sig = item.name .. "|" .. item.kind .. "|" .. (item.left and math.ceil(item.left) or ""),
        lines = lines, tint = c,
        portrait = function(tex) IN.Card.Icon(tex, SpellIcon(item.id)) end,
    }
end

-- The cards now: the notices still within their time, and (a spell tracked "until") each cooldown running.
-- A cooldown ends as it runs out (ours, from your cast; out of a fight the game's own word, a reset or a
-- shorter one ends it too): told Ready ("ready"), or its card just goes ("until")
local list = {}
local function Active()
    local now = GetTime()
    wipe(list)
    for i = #notices, 1, -1 do
        if notices[i].untilAt <= now then table.remove(notices, i) end
    end
    for _, n in ipairs(notices) do list[#list + 1] = n end
    for _, id in ipairs(ST.Ids()) do
        local name = SpellName(id)
        local s = name and state[name]
        if s and s.cd then
            local start, duration = ReadCooldown(id)
            if start and duration then
                if duration > GCD_MAX then
                    s.cd = { start = start, length = duration }
                elseif now - s.cd.start > 1 then
                    s.cd.start = -1e9       -- (over)
                end
            end
            local left = s.cd.start + s.cd.length - now
            if left <= 0 then
                s.cd = nil
                if ST.Mode(name) == "ready" then Push(name, id, "ready") end
            elseif ST.Mode(name) == "until" then
                list[#list + 1] = { name = name, id = id, kind = "cd", left = left }
            end
        end
    end
    return list
end

local placed = {}
local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    -- (the buffs looked at now and then out of a fight, as a safety for a missed event)
    since = since + elapsed
    if since >= 1 then
        since = 0
        if IF.db and IN.Settings().spellTracker ~= false then pcall(LookAuras) end
    end
    if IF.db and IF.db.spellLog then IF.db.spellLog = nil end     -- (the probe's log, cleared once)
    local list = (IF.db and IN.Settings().spellTracker ~= false) and Active() or {}
    local above
    for i = 1, MAX_CARDS do
        local card, item = cards[i], list[i]
        local content = item and Content(item) or nil
        -- (under the one before it showing, else at the place right of your character)
        local want = above and above.panel or false
        if placed[i] ~= want then
            placed[i] = want
            card.panel:ClearAllPoints()
            if want then
                card.panel:SetPoint("TOPLEFT", want, "BOTTOMLEFT", 0, -GAP)
            else
                card.panel:SetPoint("TOPLEFT", UIParent, "CENTER", OFFSET_X, OFFSET_Y)
            end
        end
        card:Update(elapsed, content)
        if card:Active() then above = card end
    end
end)
