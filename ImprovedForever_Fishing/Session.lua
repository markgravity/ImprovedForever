-- The fishing session: from the pole put in hand to it put away, what it
-- caught (each item, how many, its quality and icon), how many casts,
-- catches and fish that got away, when each began. Read by the session's
-- panel and the fishing bar (Panel.lua, CastBar.lua) through
-- F.Session(); told of each change through F.OnChange(fn), of each catch
-- through F.OnCatch(fn(catch)) and each miss through F.OnEscape(fn(kind)).
-- Kept per character (IF.charDB.fishingSession): a /reload or a pole put
-- away and back within RESUME seconds goes on with the same session.
local IF = ImprovedForever
local F = IF.Fishing

local RESUME = 15 * 60
local FISHING = 7620

local session
local listeners, catchers, escapers = {}, {}, {}

function F.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- fn(catch): catch = { items = { { id, name, icon, quality, count (this
-- catch's), new (first this session) }, ... }, at (GetTime) }
function F.OnCatch(fn)
    catchers[#catchers + 1] = fn
end

-- fn(kind): "escaped" (the fish got away), "early" (nothing hooked yet)
function F.OnEscape(fn)
    escapers[#escapers + 1] = fn
end

local function Changed()
    if IF.charDB then IF.charDB.fishingSession = session end
    for _, fn in ipairs(listeners) do pcall(fn, session) end
end

-- The session: { start, active, last (time of its last cast or catch),
-- casts, catches, escapes, items = { [id] = { id, name, icon, quality, count,
-- first, last } }, newest (the last catch's item id), newestAt (GetTime) },
-- or nil (none yet)
function F.Session()
    return session
end

-- (a pole in hand: a session going, resumed if the last one was lately)
local function Begin()
    local now = time()
    if session and session.active then return end
    if not (session and session.last and now - session.last <= RESUME) then
        session = { start = now, last = now, casts = 0, catches = 0, escapes = 0, items = {} }
    end
    session.active = true
    Changed()
end

local function Finish()
    if not (session and session.active) then return end
    session.active = false
    Changed()
end

local function FishingName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING)
    return name or (GetSpellInfo and GetSpellInfo(FISHING)) or "Fishing"
end

local function ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- (a fishing loot window: each item in it, once per window)
local looted = false
local function Loot()
    if looted or not (IsFishingLoot and IsFishingLoot()) then return end
    looted = true
    if not (session and session.active) then Begin() end
    local now = time()
    local caught = false
    local catch = { items = {}, at = GetTime() }
    for slot = 1, GetNumLootItems() or 0 do
        local ok, icon, name, quantity, _, quality = pcall(GetLootSlotInfo, slot)
        local id = ok and ItemID(GetLootSlotLink(slot))
        if id and name then
            local item = session.items[id]
            local count = math.max(1, tonumber(quantity) or 1)
            catch.items[#catch.items + 1] = { id = id, name = name, icon = icon, quality = quality or 1,
                count = count, new = item == nil }
            if not item then
                item = { id = id, name = name, icon = icon, quality = quality or 1, count = 0, first = now }
                session.items[id] = item
            end
            item.count = item.count + count
            item.last = now
            session.newest, session.newestAt = id, GetTime()
            caught = true
        end
    end
    if caught then
        session.catches = session.catches + 1
        session.last = now
        Changed()
        for _, fn in ipairs(catchers) do pcall(fn, catch) end
    end
end

-- (the game's error line: the fish got away, or nothing hooked yet; read
-- from its event and from the error line itself, once)
local escapedAt = 0
local function Escape(message)
    if (issecretvalue and issecretvalue(message)) or type(message) ~= "string" then return end
    local kind = (message == ERR_FISH_ESCAPED and "escaped") or (message == ERR_FISH_NOT_HOOKED and "early") or nil
    if not kind or GetTime() - escapedAt < 0.5 then return end
    escapedAt = GetTime()
    if not (session and session.active) then Begin() end
    if kind == "escaped" then session.escapes = (session.escapes or 0) + 1 end
    session.last = time()
    Changed()
    for _, fn in ipairs(escapers) do pcall(fn, kind) end
end

-- Probe: the events around a cast, a catch and a miss, in IF.db.fishingLog
-- (a fresh log each session, written on /reload)
local logStarted
local function Log(text)
    if not IF.db then return end
    if not logStarted then
        logStarted = true
        IF.db.fishingLog = { date("%H:%M:%S") }
    end
    local log = IF.db.fishingLog
    if #log < 300 then log[#log + 1] = ("%.2f %s"):format(GetTime() % 1000, text) end
end
local function Shown(v)
    if issecretvalue and issecretvalue(v) then return "<hidden>" end
    return tostring(v)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:RegisterEvent("UI_INFO_MESSAGE")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
events:SetScript("OnEvent", function(_, event, a1, a2, spellID)
    if session and session.active then
        local fishing = IsFishingLoot and IsFishingLoot()
        Log(table.concat({ event, Shown(a1), Shown(a2), Shown(spellID), "fishingLoot=" .. tostring(fishing) }, " "))
    end
    if event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
        Escape(a2)
        Escape(a1)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if F.PoleEquipped() then Begin() else Finish() end
    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        Loot()
    elseif event == "LOOT_CLOSED" then
        looted = false
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" and type(spellID) ~= "nil" then
        if issecretvalue and issecretvalue(spellID) then return end
        local name = type(spellID) == "number" and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        if name and name == FishingName() then
            if not (session and session.active) then Begin() end
            session.casts = session.casts + 1
            session.last = time()
            Changed()
        end
    end
end)

-- (the error line's own lines: whatever event brings them)
if UIErrorsFrame and hooksecurefunc then
    hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, message)
        if session and session.active then Log("UIErrorsFrame " .. Shown(message)) end
        Escape(message)
    end)
end

IF.OnLogin(function()
    session = IF.charDB and IF.charDB.fishingSession or nil
    if session then session.active = false end
    if F.PoleEquipped() then Begin() else Changed() end
end)

-- /if fishreset: a new session now
IF.AddCommand("fishreset", function()
    session = nil
    if F.PoleEquipped() then Begin() else Changed() end
    IF.Print("Fishing: a new session.")
end, ": start a new fishing session")
