-- The collection: every thing you've fished up, kept per character
-- (IF.charDB.fishingCollection[itemID] = { first, last, count, zones =
-- { [zone name] = count }, name, icon, quality }), for the fishing book
-- (Book.lua) and the first-catch cinematic (FirstCatch.lua). Filled from
-- each catch as Session.lua reads it (F.Collect, before the catch is told
-- to anyone: a first one comes marked firstEver); the session's catches
-- from before there was a collection put in once, not as first ever.
local IF = ImprovedForever
local F = IF.Fishing

local function Store()
    IF.charDB.fishingCollection = IF.charDB.fishingCollection or {}
    return IF.charDB.fishingCollection
end

-- The collection (nil before login)
function F.Collection()
    return IF.charDB and Store() or nil
end

-- (where you are: the zone, and the subzone when there is one)
local function Where()
    local zone = GetZoneText and GetZoneText() or nil
    local sub = GetSubZoneText and GetSubZoneText() or nil
    if zone == "" then zone = nil end
    if sub == "" or sub == zone then sub = nil end
    return zone, sub
end

-- A catch's items into the collection; each marked firstEver when it's new
-- to it
function F.Collect(catch)
    if not (IF.charDB and catch) then return end
    local store = Store()
    local now = time()
    local zone, sub = Where()
    for _, item in ipairs(catch.items or {}) do
        if item.id then
            local c = store[item.id]
            if not c then
                c = { first = now, count = 0, zones = {}, firstZone = zone, firstSub = sub }
                store[item.id] = c
                item.firstEver = true
            end
            c.name, c.icon, c.quality = item.name, item.icon, item.quality
            c.count = c.count + (item.count or 1)
            c.last = now
            if zone then c.zones[zone] = (c.zones[zone] or 0) + (item.count or 1) end
        end
    end
end

-- (once: the session's catches from before)
IF.OnLogin(function()
    local store = Store()
    local session = IF.charDB.fishingSession
    if IF.charDB.fishingCollectionFilled or not session then
        IF.charDB.fishingCollectionFilled = true
        return
    end
    for id, item in pairs(session.items or {}) do
        if not store[id] then
            store[id] = { first = item.first or session.start, last = item.last, count = item.count or 1, zones = {},
                name = item.name, icon = item.icon, quality = item.quality }
        end
    end
    IF.charDB.fishingCollectionFilled = true
end)
