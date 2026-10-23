-- Your recent loot: only what is worth a look, each marked by its badge:
-- an upgrade for what you wear (the green arrow), an item that starts a
-- quest (!), a recipe for your professions (a book), a find worth more at
-- the auction house (a coin), a rare or better (its ring), a mount, pet
-- or toy not learned yet (a horse), a bag that opens (a key). Anything
-- else flies to the bags' tile and is gone. Up to four small tiles left of
-- the bags' tile under the spell diamonds (GamepadBar.lua's supplies), the
-- newest nearest it;
-- the same item looted again grouped into its tile (its count summed, the
-- tile back to the front). Each the bar's tile, its border tinted as the
-- bags tint an item's (its quality from uncommon up, a quest starter gold).
-- An item taken from the loot
-- window flies from its row there into the front tile (the window not
-- shown, autoloot: from the middle of the screen, where you stand), the
-- tile flashing in its colour as it lands. The mouse over one shows the
-- item's tooltip. In a group, what goes by a roll or the master looter
-- isn't counted (its slot clears whoever gets it). Kept until /reload.
-- The loot window is only read (its rows' places, GetLootSlotInfo),
-- never changed. Focus (a binding, Other: unbound until set; a key too):
-- the pad on the tiles: the D-pad left / right picks one (its tooltip up,
-- the cursor on it), X uses it (an upgrade worn, a quest's start read),
-- Square shows it in the bags, R3 turns the tooltip's compare on or off
-- (an item to wear), Circle gives the pad back. A click uses one, a right
-- click shows it in the bags.
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
local QUEST_ATLAS = "QuestNormal"
-- (a kind's badge texture, for the ones with no art of the game's own)
local BADGES = {
    recipe = "Interface\\Icons\\INV_Misc_Book_09",
    auction = "Interface\\MoneyFrame\\UI-GoldIcon",
    collect = "Interface\\Icons\\Ability_Mount_RidingHorse",
    open = "Interface\\Icons\\INV_Misc_Key_03",
}

-- (the border's tint, or nil: none)
local function BorderColor(e)
    if e.kind == "quest" then return QUEST end
    if (e.quality or 1) < 2 then return nil end
    local c = BAG_ITEM_QUALITY_COLORS and BAG_ITEM_QUALITY_COLORS[e.quality]
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return QualityColor(e.quality)
end

local FindInBags                 -- (below)
local RevealEntry, AfterUse      -- (below)

local function Tiles(bar)
    if row then return end
    row = CreateFrame("Frame", nil, bar.BagTile:GetParent())
    row:SetSize(1, 1)
    for i = 1, MAX do
        local center = CreateFrame("Frame", nil, row)
        center:SetSize(1, 1)
        local b = bar.Tile(row, center, bar.SUPPLY, { 0, 0 })
        b:SetScript("OnReceiveDrag", nil)
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
        -- (its use: the game's secure item button over the tile, set to the
        -- item's bag slot out of combat: a use is protected, and the pad
        -- press clicks it, Bind. A right click shows it in the bags.)
        local use = CreateFrame("Button", "ImprovedForeverRecentUse" .. i, b, "SecureActionButtonTemplate")
        use:SetAllPoints(b)
        use:SetFrameLevel(b:GetFrameLevel() + 10)
        -- (both registered, acting on the release: a pad press by an override
        -- binding sends the game's key-down setting's side, else nothing runs)
        use:RegisterForClicks("AnyDown", "AnyUp")
        use:SetAttribute("useOnKeyDown", false)
        use:SetScript("OnEnter", function()
            local f = b:GetScript("OnEnter")
            if f then f(b) end
        end)
        use:SetScript("OnLeave", function()
            local f = b:GetScript("OnLeave")
            if f then f(b) end
        end)
        use:HookScript("OnClick", function(_, button)
            if button == "RightButton" then RevealEntry(b.entry) else AfterUse(b.entry) end
        end)
        b.use = use
        -- (its badge: the upgrade arrow, or the quest's !)
        b.upArrow = IF.Upgrades and IF.Upgrades.Arrow(b, "BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        local bang = b:CreateTexture(nil, "OVERLAY", nil, 4)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(QUEST_ATLAS) then
            bang:SetAtlas(QUEST_ATLAS, true)
        else
            bang:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            bang:SetSize(16, 16)
        end
        bang:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        bang:Hide()
        b.questBang = bang
        local badge = b:CreateTexture(nil, "OVERLAY", nil, 4)
        badge:SetSize(14, 14)
        badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        badge:Hide()
        b.badge = badge
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

local combatPending

local function Refresh()
    local bar = GB()
    if not bar then return end
    -- (the tiles hold secure buttons: shown, hidden and placed out of
    -- combat only, else after it)
    if IF.InCombat() then
        combatPending = true
        return
    end
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
            if b.upArrow then b.upArrow:SetShown(e.kind == "upgrade") end
            b.questBang:SetShown(e.kind == "quest")
            local art = BADGES[e.kind]
            if art then b.badge:SetTexture(art) end
            b.badge:SetShown(art ~= nil)
        end
        -- (its use aimed at the item's bag slot: out of combat only)
        if not IF.InCombat() and b.use then
            local bag, slot
            if e then bag, slot = FindInBags(e.id) end
            local value = bag and (bag .. " " .. slot) or nil
            if b.use.slotValue ~= value then
                b.use.slotValue = value
                b.use:SetAttribute("type1", value and "macro" or nil)
                b.use:SetAttribute("macrotext", value and ("/use " .. value) or nil)
            end
        end
    end
end
RL.Refresh = Refresh

local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if combatPending then
        combatPending = nil
        Refresh()
    end
end)

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

-- What makes an item worth a tile: "upgrade" (better than what is worn),
-- "quest" (starts a quest not yet taken or done), or nil: not shown
local function Done(questID)
    local log = C_QuestLog
    return log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(questID) or false
end

local function InLog(questID)
    local log = C_QuestLog
    return log and log.GetLogIndexForQuestID and log.GetLogIndexForQuestID(questID) and true or false
end

local function StartsQuest(id)
    local GD = IF.GameData
    if not (GD and GD.ItemQuests) then return false end
    local ok, starts = pcall(GD.ItemQuests, id)
    if not (ok and starts) then return false end
    if InLog(starts) or Done(starts) then return false end
    return not GD.QuestOpen or GD.QuestOpen(starts) and true or false
end

-- (a bag slot holding the item, newest stack last found: nil while it hasn't come)
function FindInBags(id)
    local C = C_Container
    if not (C and C.GetContainerNumSlots) then return nil end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.itemID == id then return bag, slot, info end
        end
    end
end

-- (a mount, a pet or a toy the character hasn't learned: the tooltip's
-- "Already known" says; a toy by the toy box)
local MOUNT_CLASS, PET_SUB, MOUNT_SUB = 15, 2, 5
local function IsNewCollectible(id, bag, slot, classID, subclassID)
    local toys = C_ToyBox
    if toys and toys.GetToyInfo and toys.GetToyInfo(id) then
        return not (PlayerHasToy and PlayerHasToy(id))
    end
    if classID ~= MOUNT_CLASS or (subclassID ~= PET_SUB and subclassID ~= MOUNT_SUB) then return false end
    local tips = C_TooltipInfo
    if not (tips and tips.GetBagItem) then return true end
    local ok, data = pcall(tips.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or not data.lines then return true end
    for _, line in ipairs(data.lines) do
        if ITEM_SPELL_KNOWN and line.leftText == ITEM_SPELL_KNOWN then return false end
    end
    return true
end

-- What makes an item worth a tile, once it is in the bags (the verdict
-- of ItemValue.lua is by bag slot): "quest" (starts one not yet taken or
-- done), "upgrade", "recipe" (for the character's professions, not
-- known), "auction" (worth clearly more there than to a vendor),
-- "collect" (a mount, pet or toy to learn), "open" (a bag that opens),
-- "rare" (blue or better), or nil: not shown, flown to the bags' tile
local function Kind(item)
    if StartsQuest(item.id) then return "quest" end
    local bag, slot, info = FindInBags(item.id)
    if not bag then return nil, true end
    local IV = IF.ItemValue
    local e = IV and IV.Judge and IV.Judge(bag, slot)
    if not e then return nil, true end
    if e.tag == "Upgrade" then return "upgrade" end
    if e.tag == "Recipe" and e.verdict == "keep" then return "recipe" end
    local _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(item.id)
    if IsNewCollectible(item.id, bag, slot, classID, subclassID) then return "collect" end
    if e.verdict == "auction" then return "auction" end
    if info and info.hasLoot then return "open" end
    if (item.quality or e.quality or 1) >= 3 then return "rare" end
end

-- An item come in: grouped into its tile, or a new one, at the front
local function Add(item)
    for i, e in ipairs(recent) do
        if e.id == item.id then
            table.remove(recent, i)
            e.count = e.count + item.count
            e.link, e.icon, e.quality, e.kind = item.link, item.icon or e.icon, item.quality or e.quality,
                item.kind or e.kind
            table.insert(recent, 1, e)
            return
        end
    end
    table.insert(recent, 1, { id = item.id, link = item.link, icon = item.icon, quality = item.quality,
        count = item.count, kind = item.kind })
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

-- (an item that goes to the bags' tile: the tile flashing white once)
local function Pulse()
    local bt = GB() and GB().BagTile
    if bt and bt.flashFill then
        bt.flashFill:SetVertexColor(1, 1, 1, 1)
        bt.flashFill:SetAlpha(LAND_FLASH * 0.6)
        C_Timer.After(0.15, function() bt.flashFill:SetAlpha(0) end)
    end
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
    local tx, ty, tw
    if f.item.kind then
        local target = tiles[1]
        if row and row:IsShown() and target then
            tx, ty = Center(target.center)
            tw = GB() and GB().SUPPLY.width or FALLBACK_SIZE
        end
    else
        local bt = GB() and GB().BagTile
        if bt and bt:IsVisible() then tx, ty, tw = Center(bt) end
    end
    if not tx or t >= 1 then
        f:SetScript("OnUpdate", nil)
        f:Hide()
        pool[#pool + 1] = f
        if f.item.kind then
            Land(f.item)
        else
            Pulse()
        end
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
    -- (the tiles not to be seen (faded: fishing, the camp): straight in;
    -- an item for the bags' tile only flies when that is seen)
    local faded = row and IF.Focus.Faded(row:GetParent())
    local seen = On() and row and row:IsVisible() and not faded
    if not seen then
        if item.kind then Land(item) end
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
-- Items taken, waiting to be in the bags (their verdict is by bag slot):
-- { item, from, at }; dropped if they never come (full bags)
local pending = {}
local PENDING_TIME = 2

local function Process()
    local i = 1
    while i <= #pending do
        local p = pending[i]
        local kind, wait = Kind(p.item)
        if wait and GetTime() - p.at < PENDING_TIME then
            i = i + 1
        else
            table.remove(pending, i)
            p.item.kind = kind
            Fly(p.item, p.from)
        end
    end
end

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
        local ok, icon, _, quantity, _, quality, locked = pcall(GetLootSlotInfo, slot)
        local link = ok and GetLootSlotLink(slot)
        local id = ItemID(link)
        if id and not Rolled(quality, locked) then
            slots[slot] = { id = id, link = link, icon = icon, quality = quality or 1,
                count = math.max(1, tonumber(quantity) or 1) }
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
        if item and On() then pending[#pending + 1] = { item = item, from = places[slot], at = GetTime() } end
    elseif event == "LOOT_CLOSED" then
        watch:Hide()
        wipe(slots)
    else
        Process()
        Refresh()
    end
end)

-- (placed and shown again now and then: the bags' tile comes, goes and
-- moves with the style and Edit Mode)
IN.Watcher("recent loot", 0.5, function()
    Process()
    Refresh()
end)

function RL.Apply()
    Refresh()
end

---------------------------------------------------------------------------
-- /if loottest [n | clear]: n items from your bags (3 by default, the
-- first twice: grouped) flown in as if taken from a loot window on the
-- left, one row each, each taken for the next kind in turn (the last for
-- the bags' tile) whatever it is; clear: the row emptied
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
                items[#items + 1] = { id = id, link = info.hyperlink, icon = info.iconFileID,
                    quality = info.quality or 1, count = 1 }
            end
        end
    end
    if #items == 0 then
        IF.Print("Recent loot test: no items in your bags to fly in.")
        return
    end
    -- (the rows of a loot window left of the middle; the kinds in turn,
    -- the last one for the bags' tile, whatever each item is)
    local KINDS = { "upgrade", "quest", "recipe", "auction", "rare", "collect", "open" }
    local x, top = UIParent:GetWidth() * 0.3, UIParent:GetHeight() * 0.6
    for i = 1, n do
        local item = items[(i - 1) % #items + 1]
        local copy = { id = item.id, link = item.link, icon = item.icon, quality = item.quality, count = 1 }
        if not (i == n and n > 1) then copy.kind = KINDS[(i - 1) % #KINDS + 1] end
        Fly(copy, { x, top - (i - 1) * 44, 36 })
    end
    local bar = GB()
    IF.Print(("Recent loot test: %d items flying in (bar %s, bags' tile %s, row %s)."):format(n,
        bar and "found" or "missing", bar and (bar.BagTile:IsVisible() and "shown" or "hidden") or "-",
        row and (row:IsVisible() and "shown" or "hidden") or "not made"))
end

---------------------------------------------------------------------------
-- Use, show in the bags
---------------------------------------------------------------------------
local function Forget(e)
    for i, other in ipairs(recent) do
        if other == e then
            table.remove(recent, i)
            break
        end
    end
    Refresh()
end

-- (a use done: the item gone from the bags a moment after (used up, a
-- quest's read away): its tile too)
function AfterUse(e)
    if not e then return end
    C_Timer.After(0.5, function()
        if not FindInBags(e.id) then Forget(e) end
    end)
end

-- (a pulse of ours on the item's bag button: a texture of ours, nothing
-- written in the game's frames)
local pulse = CreateFrame("Frame")
pulse:Hide()
pulse.tex = pulse:CreateTexture(nil, "OVERLAY", nil, 6)
pulse.tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
pulse.tex:SetBlendMode("ADD")
pulse.tex:SetVertexColor(1, 0.85, 0.3)
pulse:SetScript("OnUpdate", function(self)
    local t = GetTime() - self.at
    if t > 3 or not self.button:IsVisible() then
        self:Hide()
        self.tex:Hide()
        return
    end
    self.tex:SetAlpha(0.5 + 0.5 * math.sin(t * 8))
end)

local function BagButton(bag, slot)
    local frames = { _G.ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame:IsShown() and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do
                if button.GetBagID and button:GetBagID() == bag and button:GetID() == slot then return button end
            end
        end
    end
end

function RevealEntry(e)
    if not e or IF.InCombat() then return end
    local bag, slot = FindInBags(e.id)
    if not bag then return Forget(e) end
    local function Light()
        local button = BagButton(bag, slot)
        if not button then return end
        pulse.button, pulse.at = button, GetTime()
        pulse.tex:ClearAllPoints()
        pulse.tex:SetPoint("CENTER", button, "CENTER")
        pulse.tex:SetSize(button:GetWidth() * 1.8, button:GetHeight() * 1.8)
        pulse.tex:SetParent(button)
        pulse.tex:Show()
        pulse:Show()
    end
    if BagButton(bag, slot) then return Light() end
    pcall(OpenAllBags)
    C_Timer.After(0.15, Light)
end


---------------------------------------------------------------------------
-- The pad: focus on the tiles
---------------------------------------------------------------------------
local focused, sel, compare = false, 1, false
local cursor, legend

-- (the game's prompts: { key, glyph, text })
local LEGEND = {
    { glyph = "DPAD_LR", text = "Select" }, { "PAD1", "A", "Use" }, { "PAD3", "X", "Show in bag" },
    { "PAD2", "B", "Exit" },
}
local LEGEND_WEAR = {
    { glyph = "DPAD_LR", text = "Select" }, { "PAD1", "A", "Use" }, { "PAD3", "X", "Show in bag" },
    { "PADRSTICK", "RS", "Compare" }, { "PAD2", "B", "Exit" },
}

local function Shown()
    local n = 0
    for i = 1, MAX do
        if recent[i] then n = i end
    end
    return n
end

-- (the picked one's tooltip, with the game's compare when asked for and
-- there is something to compare with)
local function Show()
    local e = recent[sel]
    local t = tiles[sel]
    GameTooltip:Hide()
    if cursor then
        if e and t then cursor:Point(t.tile) else cursor:Hide() end
    end
    if not (e and e.link and t) then return end
    GameTooltip:SetOwner(t.tile, "ANCHOR_TOP")
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, e.link) then return end
    GameTooltip:Show()
    if compare and IsEquippableItem and IsEquippableItem(e.link) and GameTooltip_ShowCompareItem then
        pcall(GameTooltip_ShowCompareItem, GameTooltip)
    end
    if legend then
        -- (left of the row: past its last tile)
        local last = tiles[Shown()]
        legend:ClearAllPoints()
        legend:SetPoint("RIGHT", (last and last.tile) or t.tile, "LEFT", -14, 0)
        legend:Set(IsEquippableItem and IsEquippableItem(e.link) and LEGEND_WEAR or LEGEND)
    end
end

-- (the pad's buttons: override bindings to buttons of ours, out of combat,
-- while the game has the pad (as PartyPad.lua's); each acts on its release.
-- X is the picked tile's own secure button: a use is protected)
local owner = CreateFrame("Frame")
local PRESS = { PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD2 = "B", PAD3 = "X", PADRSTICK = "R3" }
local padButtons = {}
local Press

local function Bind(on)
    if IF.InCombat() then return false end
    ClearOverrideBindings(owner)
    if on then
        for key, name in pairs(PRESS) do
            local b = padButtons[name]
            if not b then
                b = CreateFrame("Button", "ImprovedForeverRecentPad" .. name, UIParent)
                b:RegisterForClicks("AnyUp")
                b:SetScript("OnClick", function() Press(name) end)
                padButtons[name] = b
            end
            SetOverrideBindingClick(owner, true, key, b:GetName())
        end
        local t = tiles[sel]
        if t and t.tile.use then SetOverrideBindingClick(owner, true, "PAD1", t.tile.use:GetName()) end
    end
    return true
end

local function Leave()
    if not focused then return end
    focused = false
    Bind(false)
    GameTooltip:Hide()
    if cursor then cursor:Hide() end
    if legend then legend:Set(nil) end
end

function Press(name)
    if not focused then return end
    if name == "B" then return Leave() end
    local n = Shown()
    if n == 0 then return Leave() end
    if name == "LEFT" then sel = math.min(n, sel + 1)
    elseif name == "RIGHT" then sel = math.max(1, sel - 1)
    elseif name == "X" then return RevealEntry(recent[sel])
    elseif name == "R3" then compare = not compare end
    Bind(true)
    Show()
end

local function Build()
    if cursor then return true end
    local bar = GB()
    if not (bar and row) then return false end
    cursor = IF.Focus.Cursor(row)
    legend = IF.InputLegend(row)
    return true
end

-- Focus on the tiles, or back (the binding: the pad's, a key's). soon: from
-- a touchpad corner's double tap, a window (the bags the first tap opened)
-- still closing: asked again for a moment until the game has the pad
local wanted
function RL.Focus(soon)
    if focused then return Leave() end
    if not (IF.db and On()) or IF.InCombat() then return end
    if not IF.Binds.InGame() then
        if soon then wanted = GetTime() + 2 end
        return
    end
    wanted = nil
    Refresh()
    if not (row and row:IsVisible()) or Shown() == 0 then
        IF.Print("Recent loot: nothing to pick yet.")
        return
    end
    if not Build() then return end
    focused, sel = true, 1
    Bind(true)
    Show()
end

-- (the pad given back when the game takes it, a fight, or nothing left)
IN.Watcher("recent loot pad", 0.2, function()
    if wanted and not focused then
        if GetTime() > wanted then
            wanted = nil
        elseif IF.Binds.InGame() then
            RL.Focus()
        end
    end
    if not focused then return end
    if IF.InCombat() or not IF.Binds.InGame() or not (row and row:IsVisible()) or Shown() == 0 then
        return Leave()
    end
    -- (the game binds its own keys as priority overrides again as its
    -- windows come and go, the last set wins: ours set again when a key
    -- isn't running ours)
    local t = tiles[sel]
    local want = t and t.tile.use and ("CLICK " .. t.tile.use:GetName() .. ":LeftButton")
    local ok, now = pcall(GetBindingAction, "PAD1", true)
    if want and not (ok and now == want) then Bind(true) end
    if sel > Shown() then
        sel = Shown()
        Show()
    end
end)

-- (the touchpad's corner: its action's button, Actions.lua)
IF.Actions.PressButton("ImprovedForeverRecentLootFocus", function() RL.Focus(true) end)

function RL.Key()
    return IF.db and IN.Settings().recentLootKey or nil
end

-- (its press, watched, not taken over: a button, or one held + one pressed
-- ("PADLTRIGGER+PAD4"); the buttons keep their own actions too)
local keyWatch = CreateFrame("Frame")
local wasDown = false
keyWatch:SetScript("OnUpdate", function()
    local key = RL.Key()
    -- (only while the game has the gamepad's focus, Binds.lua)
    if not key or not IsKeyDown or (IF.Menu and IF.Menu.IsOpen()) or not IF.Binds.InGame() then
        wasDown = false
        return
    end
    local held, pressed = key:match("^(.-)%+(.+)$")
    pressed = pressed or key
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held)) or false
    -- (the moment the combination is made)
    if down and not wasDown and not focused then RL.Focus() end
    wasDown = down
end)

IF.Binds.Add({
    id = "recentloot", label = "Recent loot", group = "Other",
    icon = IF.TEX .. "ic_addon", context = "world", order = 37,
    desc = "Puts the pad on your recent loot tiles",
    tip = "Puts the pad on the recent loot tiles (the setting on): left / right picks one, X uses it, "
        .. "Square shows it in your bags, R3 turns the compare tooltip on or off, Circle gives the pad back. "
        .. "Watched only: the buttons keep their own actions too.",
    accepts = IF.Binds.NotDouble,
    specs = function() return IF.Binds.One(RL.Key()) end,
    set = function(spec) IN.Settings().recentLootKey = spec or false end,
    run = function(down) if down then RL.Focus() end end,
    -- (its default: unbound for now; a double tap on the touchpad's bottom
    -- right corner was one, Touchpad.lua's DOUBLE_DEFAULTS)
    reset = function()
        IN.Settings().recentLootKey = false
    end,
})
