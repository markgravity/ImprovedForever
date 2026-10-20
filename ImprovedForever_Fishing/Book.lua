-- What the Fish Collection (CollectionWindow.lua) knows: what can be fished
-- up and where (the core's FishingData.lua: Classic's loot, Forever's items
-- and zones), decoded once, and your collection (Collection.lua).
local IF = ImprovedForever
local F = IF.Fishing

local B = {}
F.Book = B

local D = IF.FishingData or { items = {}, zones = {}, areas = {} }

-- (a row's catches: item, chance in %, the event it's caught in or 0)
local function Catches(text)
    local list = {}
    for id, chance, event in (text or ""):gmatch("(%d+):([%d%.e%-]+):(%d+)") do
        list[#list + 1] = { id = tonumber(id), chance = tonumber(chance), event = tonumber(event) }
    end
    return list
end

-- { items = { [id] = { id, name, quality, kind } }, where = { [id] = { { place, chance, event, area (the
-- zone's: a subzone's its zone's) } } } }
local index
function B.Index()
    if index then return index end
    index = { items = {}, where = {} }
    for id, row in pairs(D.items) do
        local name, quality, kind = row:match("^(.*)|(%d+)|(%a+)$")
        index.items[id] = { id = id, name = name or ("Item " .. id), quality = tonumber(quality) or 1,
            kind = kind or "other" }
    end
    local function Where(place, text, area)
        for _, c in ipairs(Catches(text)) do
            index.where[c.id] = index.where[c.id] or {}
            table.insert(index.where[c.id], { place = place, chance = c.chance, event = c.event, area = area })
        end
    end
    for area, row in pairs(D.zones) do
        local name, text = row:match("^(.-)|(.*)$")
        Where(name, text, area)
    end
    for _, row in pairs(D.areas or {}) do
        local name, zone, text = row:match("^(.-)|(%d+)|(.*)$")
        Where(name, text, tonumber(zone))
    end
    return index
end

-- The fish this water holds, where you are, likeliest first: the subzone's
-- own catches and the zone's (out of season ones left out), and every fish
-- you've caught in this zone (the data's lists are Classic's, not always
-- whole): { { id, chance } }
local known = {}
local function Known(zone, sub)
    local key = zone .. "|" .. sub
    if known[key] then return known[key] end
    local idx = B.Index()
    local best = {}
    for id, list in pairs(idx.where) do
        local item = idx.items[id]
        if item and item.kind == "fish" then
            for _, w in ipairs(list) do
                if w.event == 0 and w.place ~= "" and (w.place == sub or w.place == zone) then
                    best[id] = math.max(best[id] or 0, w.chance)
                end
            end
        end
    end
    known[key] = best
    return best
end

function B.Here()
    local zone = GetZoneText and GetZoneText() or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local chance = {}
    for id, c in pairs(Known(zone, sub)) do chance[id] = c end
    local items = B.Index().items
    for id, c in pairs(B.Collection()) do
        local item = items[id]
        if item and item.kind == "fish" and c.zones and c.zones[zone] then
            chance[id] = chance[id] or 0
        end
    end
    local list = {}
    for id, c in pairs(chance) do list[#list + 1] = { id = id, chance = c } end
    table.sort(list, function(x, y)
        if x.chance ~= y.chance then return x.chance > y.chance end
        return x.id < y.id
    end)
    return list
end

function B.Collection()
    return F.Collection and F.Collection() or {}
end

function B.Icon(id)
    local get = C_Item and C_Item.GetItemIconByID or GetItemIcon
    local ok, icon = pcall(get, id)
    return ok and icon or 134400
end

-- /if fishbook: the Fish Collection
IF.AddCommand("fishbook", function() B.Open() end, ": the Fish Collection")
