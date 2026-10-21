-- Your recent loot: up to four small tiles left of the bags' tile under
-- the spell diamonds (GamepadBar.lua's supplies), the newest nearest it;
-- the same item looted again grouped into its tile (its count summed, the
-- tile back to the front). Each the bar's tile, its border tinted as the
-- bags tint an item's (its quality from uncommon up, a quest item gold).
-- An item taken from the loot
-- window flies from its row there into the front tile (the window not
-- shown, autoloot: from the middle of the screen, where you stand), the
-- tile flashing in its colour as it lands. The mouse over one shows the
-- item's tooltip. In a group, what goes by a roll or the master looter
-- isn't counted (its slot clears whoever gets it). Kept until /reload.
-- The loot window is only read (its rows' places, GetLootSlotInfo),
-- never changed.
local IF = ImprovedForever
local IN = IF.Interface

local RL = {}
IN.RecentLoot = RL

local MAX = 4
local FLY = 0.65                 -- (a flight's time)
local STAGGER = 0.09             -- (between two items taken at once)
local ARC = 60                   -- (how high a flight bows up)
local LAND_FLASH, LAND_TIME = 0.6, 0.45
local FALLBACK_SIZE = 36         -- (a flight's start size without the loot window)
local POOR = { 0.62, 0.62, 0.62 }

local recent = {}                -- (newest first: { id, link, icon, quality, count })
local tiles = {}                 -- ({ tile, center })
local row

local function GB()
    local bar = IN.GamepadBar
    return bar and bar.BagTile and bar.SUPPLY and bar.Tile and bar.Mirror and bar.StandIn and bar or nil
end

local function QualityColor(q)
    if q == 0 then return POOR end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- (a point of a region, in UIParent's units)
local function Center(region)
    local ok, x, y = pcall(region.GetCenter, region)
    if not ok or not x then return nil end
    local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * k, y * k, region:GetWidth() * k
end

---------------------------------------------------------------------------
-- The tiles: the bar's own (its style's, GB.Tile), the supplies' size, in
-- a row left of the bags' tile; each one's border tinted as the bags tint
-- an item's: its quality's colour from uncommon up, a quest item's gold,
-- else as it is
---------------------------------------------------------------------------
local QUEST = { 1, 0.82, 0 }

-- (the border's tint, or nil: none)
local function BorderColor(e)
    if e.quest then return QUEST end
    if (e.quality or 1) < 2 then return nil end
    local c = BAG_ITEM_QUALITY_COLORS and BAG_ITEM_QUALITY_COLORS[e.quality]
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return QualityColor(e.quality)
end

local function Tiles(bar)
    if row then return end
    row = CreateFrame("Frame", nil, bar.BagTile:GetParent())
    row:SetSize(1, 1)
    for i = 1, MAX do
        local center = CreateFrame("Frame", nil, row)
        center:SetSize(1, 1)
        local b = bar.Tile(row, center, bar.SUPPLY, { 0, 0 })
        b:SetScript("OnReceiveDrag", nil)
        b:SetScript("OnMouseUp", nil)
        b:SetScript("OnDragStart", nil)
        b:SetScript("OnEnter", function(self)
            local e = self.entry
            if not (e and e.link) then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if pcall(GameTooltip.SetHyperlink, GameTooltip, e.link) then GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- (landing: the tile flashing in the item's colour, fading)
        local flash = CreateFrame("Frame", nil, b)
        flash:Hide()
        flash:SetScript("OnUpdate", function(self)
            local f = 1 - (GetTime() - self.at) / LAND_TIME
            if f <= 0 then
                b.flashFill:SetAlpha(0)
                self:Hide()
                return
            end
            b.flashFill:SetAlpha(LAND_FLASH * f)
        end)
        b.landFlash = flash
        b:Hide()
        tiles[i] = { tile = b, center = center }
    end
end

-- (the first a gap past the bags' tile's edge, the rest a step apart)
local function Place(bar)
    local step = bar.SUPPLY.width + bar.SUPPLY_GAP
    row:ClearAllPoints()
    row:SetPoint("CENTER", bar.BagTile, "CENTER")
    for i, t in ipairs(tiles) do
        t.center:ClearAllPoints()
        t.center:SetPoint("CENTER", row, "CENTER", -i * step, 0)
    end
end

local function On()
    return IF.db and IN.Settings().recentLoot and true or false
end

local function Refresh()
    local bar = GB()
    if not bar then return end
    Tiles(bar)
    Place(bar)
    row:SetShown(On() and bar.BagTile:IsShown())
    for i, t in ipairs(tiles) do
        local b, e = t.tile, recent[i]
        b.entry = e
        b:SetShown(e ~= nil)
        if e then
            local stand = bar.StandIn(e.icon)
            local text = e.count > 1 and tostring(e.count) or ""
            stand.Count = { IsShown = function() return true end, GetText = function() return text end }
            pcall(bar.Mirror, b, stand)
            local c = BorderColor(e)
            if c then b.border:SetVertexColor(c[1], c[2], c[3]) else b.border:SetVertexColor(1, 1, 1) end
        end
    end
end
RL.Refresh = Refresh

-- The row's left edge (its last tile's, in UIParent's units), or nil
-- while none shows: the cooldowns' lane ends before it (BuffTimeline.lua)
function RL.Left()
    if not (row and row:IsVisible()) then return nil end
    for i = #tiles, 1, -1 do
        local b = tiles[i].tile
        if b:IsShown() then
            local x, _, w = Center(b)
            return x and x - w / 2
        end
    end
end

-- (a quest item: as the loot window or bags say, else by its class)
local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local function IsQuest(item)
    if item.quest then return true end
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local ok, _, _, _, _, _, classID = pcall(get, item.id)
    return ok and classID == QUEST_CLASS or false
end

-- An item come in: grouped into its tile, or a new one, at the front
local function Add(item)
    for i, e in ipairs(recent) do
        if e.id == item.id then
            table.remove(recent, i)
            e.count = e.count + item.count
            e.link, e.icon, e.quality = item.link, item.icon or e.icon, item.quality or e.quality
            table.insert(recent, 1, e)
            return
        end
    end
    table.insert(recent, 1, { id = item.id, link = item.link, icon = item.icon, quality = item.quality,
        count = item.count, quest = IsQuest(item) })
    while #recent > MAX do table.remove(recent) end
end

local function Land(item)
    Add(item)
    Refresh()
    local t = tiles[1]
    if t and t.tile:IsShown() then
        local c = QualityColor(item.quality)
        t.tile.flashFill:SetVertexColor(c[1], c[2], c[3], 1)
        t.tile.landFlash.at = GetTime()
        t.tile.landFlash:Show()
    end
end

---------------------------------------------------------------------------
-- Flights: the item's icon from where it was to the front tile, bowing up
-- on the way, its size from its row's to the tile's
---------------------------------------------------------------------------
local pool, lastStart = {}, 0

local function Flight()
    local f = table.remove(pool)
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("DIALOG")
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetPoint("TOPLEFT", -3, 3)
    f.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    f.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.glow:SetBlendMode("ADD")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return f
end

local function Ease(t)
    return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end

local function Step(f)
    local t = (GetTime() - f.start) / FLY
    if t < 0 then
        f:SetAlpha(0)
        return
    end
    local target = tiles[1]
    local tx, ty, tw
    if row and row:IsShown() and target then
        tx, ty = Center(target.center)
        tw = GB() and GB().SUPPLY.width or FALLBACK_SIZE
    end
    if not tx or t >= 1 then
        f:SetScript("OnUpdate", nil)
        f:Hide()
        pool[#pool + 1] = f
        Land(f.item)
        return
    end
    f:Show()
    local e = Ease(t)
    local x = f.x + (tx - f.x) * e
    local y = f.y + (ty - f.y) * e + math.sin(math.pi * t) * ARC
    local size = f.size + (tw * 0.8 - f.size) * e
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    f:SetSize(size, size)
    f:SetAlpha(t < 0.85 and 1 or (1 - t) / 0.15)
end

local function Fly(item, from)
    -- (the tiles not to be seen (faded: fishing, the camp): straight in)
    local faded = row and IF.Focus.Faded(row:GetParent())
    if not (On() and row and row:IsVisible() and not faded) then
        Land(item)
        return
    end
    local f = Flight()
    f.item = item
    if from then
        f.x, f.y, f.size = from[1], from[2], from[3]
    else
        f.x, f.y, f.size = UIParent:GetWidth() / 2, UIParent:GetHeight() * 0.45, FALLBACK_SIZE
    end
    local now = GetTime()
    f.start = math.max(now, lastStart + STAGGER)
    lastStart = f.start
    f.icon:SetTexture(item.icon)
    local c = QualityColor(item.quality)
    f.glow:SetVertexColor(c[1], c[2], c[3], 0.6)
    f:SetSize(f.size, f.size)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", f.x, f.y)
    -- (shown, unseen until its turn: a hidden frame's OnUpdate never runs)
    f:SetAlpha(0)
    f:Show()
    f:SetScript("OnUpdate", Step)
end

---------------------------------------------------------------------------
-- The loot window: its slots read as it opens, its rows' places kept
-- while it's shown (a row is gone by the time its slot is cleared)
---------------------------------------------------------------------------
local slots, places = {}, {}

-- (an item that goes by a roll or the master looter: its slot cleared from
-- your window whoever gets it, so not counted)
local function Rolled(quality, locked)
    if locked then return true end
    if not (IsInGroup and IsInGroup()) then return false end
    local ok, method = pcall(GetLootMethod)
    if not ok or method == "freeforall" then return false end
    local threshold = GetLootThreshold and GetLootThreshold() or 2
    return (quality or 1) >= threshold
end

local function Snapshot()
    wipe(slots)
    local n = GetNumLootItems and GetNumLootItems() or 0
    for slot = 1, n do
        local ok, icon, _, quantity, _, quality, locked, quest = pcall(GetLootSlotInfo, slot)
        local link = ok and GetLootSlotLink(slot)
        local id = ItemID(link)
        if id and not Rolled(quality, locked) then
            slots[slot] = { id = id, link = link, icon = icon, quality = quality or 1,
                count = math.max(1, tonumber(quantity) or 1), quest = quest and true or false }
        end
    end
end

-- (each row's icon, by its slot: the game's list (its element frames), or
-- the older numbered buttons)
local function ReadPlaces()
    local loot = _G.LootFrame
    if not (loot and loot:IsVisible()) then return end
    pcall(function()
        local box = loot.ScrollBox
        if box and box.ForEachFrame then
            box:ForEachFrame(function(frame)
                local slot = frame.GetSlotIndex and frame:GetSlotIndex()
                local region = frame.Item or frame
                local x, y, w = Center(region)
                if type(slot) == "number" and x then places[slot] = { x, y, math.min(w, 48) } end
            end)
        end
    end)
    for i = 1, LOOTFRAME_NUMBUTTONS or 4 do
        local b = rawget(_G, "LootButton" .. i)
        if b and b:IsVisible() and type(b.slot) == "number" then
            local x, y, w = Center(b)
            if x then places[b.slot] = { x, y, math.min(w, 48) } end
        end
    end
end

local watch = CreateFrame("Frame")
watch:Hide()
local since = 0
watch:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.1 then return end
    since = 0
    ReadPlaces()
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "BAG_UPDATE_DELAYED",
    "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, slot)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        if event == "LOOT_READY" or not next(slots) then
            wipe(places)
            Snapshot()
        end
        watch:Show()
        ReadPlaces()
    elseif event == "LOOT_SLOT_CLEARED" then
        ReadPlaces()
        local item = slots[slot]
        slots[slot] = nil
        if item and On() then Fly(item, places[slot]) end
    elseif event == "LOOT_CLOSED" then
        watch:Hide()
        wipe(slots)
    else
        Refresh()
    end
end)

-- (placed and shown again now and then: the bags' tile comes, goes and
-- moves with the style and Edit Mode)
IN.Watcher("recent loot", 0.5, Refresh)

function RL.Apply()
    Refresh()
end

---------------------------------------------------------------------------
-- /if loottest [n | clear]: n items from your bags (3 by default, the
-- first twice: grouped) flown in as if taken from a loot window on the
-- left, one row each; clear: the row emptied
---------------------------------------------------------------------------
function RL.Test(arg)
    if arg == "clear" then
        wipe(recent)
        Refresh()
        IF.Print("Recent loot cleared.")
        return
    end
    if not On() then
        IF.Print("Recent loot is off: turn on Recent loot (experiment) in the Immersion tab first.")
        return
    end
    local n = math.max(1, math.min(tonumber(arg) or 3, 8))
    local items, seen = {}, {}
    local C = C_Container
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slotsIn = C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag) or 0
        for slot = 1, slotsIn do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            local id = ok and type(info) == "table" and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local qok, q = pcall(C.GetContainerItemQuestInfo, bag, slot)
                items[#items + 1] = { id = id, link = info.hyperlink, icon = info.iconFileID,
                    quality = info.quality or 1, count = 1,
                    quest = qok and type(q) == "table" and q.isQuestItem or false }
            end
        end
    end
    if #items == 0 then
        IF.Print("Recent loot test: no items in your bags to fly in.")
        return
    end
    -- (the rows of a loot window left of the middle)
    local x, top = UIParent:GetWidth() * 0.3, UIParent:GetHeight() * 0.6
    for i = 1, n do
        local item = items[(i - 1) % #items + 1]
        if i == n and n > 1 then item = items[1] end
        local copy = { id = item.id, link = item.link, icon = item.icon, quality = item.quality, count = 1,
            quest = item.quest }
        Fly(copy, { x, top - (i - 1) * 44, 36 })
    end
    local bar = GB()
    IF.Print(("Recent loot test: %d items flying in (bar %s, bags' tile %s, row %s)."):format(n,
        bar and "found" or "missing", bar and (bar.BagTile:IsVisible() and "shown" or "hidden") or "-",
        row and (row:IsVisible() and "shown" or "hidden") or "not made"))
end
