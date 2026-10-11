-- The auction house window's Sell tab (AuctionBuy.lua's window): down the
-- left everything in the bags that can be sold, sorted for profit:
--   Sell here: worth clearly more at the auction house (its usual price,
--     after the cut) than a vendor pays;
--   No price yet: never seen at the auction house (no scan has priced it);
--   Sell to a vendor: worth no more here than a vendor pays (or too
--     little to bother), or can't be auctioned at all (bound);
--   Keep: needed for a quest in the log (an objective's item, an item
--     that starts or belongs to one), or an upgrade (Upgrades.lua).
-- Stacks of the same item are one line. On the right the picked one: its
-- price chart (AuctionChart.lua), one price (suggested, Auction.lua), the
-- receipt (duration, deposit, profit).
-- The D-pad: up / down picks (L2 / R2 by section), left / right the price
-- (held: faster); L1 / R1 the duration; Triangle the suggestions; Cross
-- held posts: a "Hold to Sell" bar under the receipt fills while it is
-- held, and once full letting go posts (posting wants a hardware event: the
-- release is one; a timer isn't). A price the server warns about: asked in
-- a popup (AuctionConfirm.lua).
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local A = IF.Auction
local AH = C_AuctionHouse
local BY = IF.AuctionBuy

local ST = { key = "sell", label = "Sell", icon = "Interface\\Icons\\INV_Misc_Coin_01" }
IF.AuctionSellTab = ST

local LEFT_W = 430
local ROW_H = 36
local SEARCH_AFTER = 0.35          -- resting on an item this long: its listings looked up
local PROFIT_SHARE = 1.25          -- "worth more": over a vendor's pay by a quarter...
local DURATIONS = A.Durations()

local SECTIONS = {
    { key = "profit", label = "Sell here", color = "|cff5fd35f" },
    { key = "unknown", label = "No price yet", color = "|cffc9a25a" },
    { key = "vendor", label = "Sell to a vendor", color = "|cffd8ccb0" },
    { key = "keep", label = "Keep", color = "|cffff7a5c" },
}

local Glyph = function(key, size) return BY.Glyph(key, size) end

local function S()
    return A.Settings()
end

-- ...and by at least this much (copper): 2 silver at level 10, 18 at 30
local function MinProfit()
    local level = math.max(1, UnitLevel("player") or 1)
    return math.max(100, 2 * level * level)
end

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

---------------------------------------------------------------------------
-- What the quests in the log need: the items their objectives name
---------------------------------------------------------------------------
local questNeeds   -- { [lowercased objective text] = quest title }

local function QuestNeeds()
    if questNeeds then return questNeeds end
    questNeeds = {}
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetInfo and log.GetQuestObjectives) then return questNeeds end
    for i = 1, log.GetNumQuestLogEntries() or 0 do
        local info = log.GetInfo(i)
        if info and not info.isHeader and info.questID then
            for _, objective in ipairs(log.GetQuestObjectives(info.questID) or {}) do
                if objective.type == "item" and objective.text then
                    questNeeds[objective.text:lower()] = info.title or "a quest"
                end
            end
        end
    end
    return questNeeds
end

-- The quest an item is needed for (its title), or nil
local function QuestFor(name, bag, slot)
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local q = C_Container.GetContainerItemQuestInfo(bag, slot)
        if q and (q.isQuestItem or q.questID) then return "a quest" end
    end
    if not name then return nil end
    name = name:lower()
    for text, title in pairs(QuestNeeds()) do
        if text:find(name, 1, true) then return title end
    end
end

---------------------------------------------------------------------------
-- The bags, sorted: entries { key, bag, slot, loc, itemID, link, name,
-- icon, quality, count, vendor (a unit), commodity, itemLevel, auction (can
-- be auctioned), section, why }
---------------------------------------------------------------------------
local entries, lines = {}, {}

local function Classify(e)
    local quest = QuestFor(e.name, e.bag, e.slot)
    if quest then return "keep", "Needed for " .. (quest == "a quest" and quest or ("\"" .. quest .. "\"")) end
    if e.link and IF.Upgrades and IF.Upgrades.IsUpgrade(e.link, e.bag, e.slot, true) then
        local _, needLevel = IF.Upgrades.Gain(e.link, e.bag, e.slot, true)
        return "keep", needLevel and ("An upgrade for you at level " .. needLevel) or "An upgrade for you"
    end
    local vendor = (e.vendor or 0) * e.count
    if not e.auction then
        return "vendor", "Can't be auctioned"
    end
    local unit = A.UnitNet(e.itemID)
    if not unit then return "unknown", "Not seen at the auction house yet" end
    local net = unit * e.count
    if net > vendor * PROFIT_SHARE and net - vendor >= MinProfit() then
        return "profit", "About " .. A.Money(net - vendor) .. " more than a vendor pays"
    end
    if vendor >= net then return "vendor", "A vendor pays " .. A.Money(vendor) .. ", here about " .. A.Money(net) end
    return "vendor", "Only about " .. A.Money(net - vendor) .. " more here than from a vendor"
end

local function Scan()
    local byKey, list = {}, {}
    -- (the reagent bag too: the slot past the four bags)
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 1))
    for bag = 0, last do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local auction = loc:IsValid() and AH.IsSellItemValid(loc, false) or false
                local name, _, quality, _, _, _, _, _, _, _, vendor = ItemInfo(info.itemID)
                vendor = (not info.hasNoValue) and vendor or 0
                if auction or (vendor or 0) > 0 then
                    local status = auction and AH.GetItemCommodityStatus(loc)
                    local commodity = status == Enum.ItemCommodityStatus.Commodity
                    -- (gear one by one: each its own stats; the rest by item)
                    local key = commodity and ("c" .. info.itemID) or (info.stackCount or 1) > 1 and ("i" .. info.itemID)
                        or (bag .. ":" .. slot)
                    local e = byKey[key]
                    if e then
                        e.count = e.count + (info.stackCount or 1)
                    else
                        e = {
                            key = key, bag = bag, slot = slot, loc = loc, itemID = info.itemID, link = info.hyperlink,
                            name = name or (info.hyperlink and info.hyperlink:match("%[(.-)%]")),
                            icon = info.iconFileID, quality = quality or info.quality, count = info.stackCount or 1,
                            stack = info.stackCount or 1, vendor = vendor or 0, auction = auction, commodity = commodity,
                            itemLevel = (auction and not commodity and C_Item.GetCurrentItemLevel)
                                and C_Item.GetCurrentItemLevel(loc) or nil,
                        }
                        byKey[key] = e
                        list[#list + 1] = e
                    end
                end
            end
        end
    end
    for _, e in ipairs(list) do e.section, e.why = Classify(e) end
    -- By section, then the most worth first
    local order = {}
    for i, sec in ipairs(SECTIONS) do order[sec.key] = i end
    local function Worth(e)
        local unit = A.UnitNet(e.itemID)
        return math.max((unit or 0) * e.count, e.vendor * e.count)
    end
    table.sort(list, function(a, b)
        if a.section ~= b.section then return order[a.section] < order[b.section] end
        local wa, wb = Worth(a), Worth(b)
        if wa ~= wb then return wa > wb end
        return (a.name or "") < (b.name or "")
    end)
    entries = list
    -- The lines: each section's name, then its items
    lines = {}
    for _, sec in ipairs(SECTIONS) do
        local count, total = 0, 0
        for _, e in ipairs(list) do
            if e.section == sec.key then count, total = count + 1, total + Worth(e) end
        end
        if count > 0 then
            lines[#lines + 1] = { header = sec, count = count, total = total }
            for _, e in ipairs(list) do
                if e.section == sec.key then lines[#lines + 1] = { entry = e } end
            end
        end
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local f, rows, listBox, left
local sel = 1                 -- the line picked (an item's)
local top = 1
local P                       -- the picked item's sale: { entry, price, preset, presetLabel, presets,
                              -- picked, touched, duration, qty, listings, lowestNow, searching,
                              -- searched, warn, pending, message }
local listingsCache = {}      -- entry key -> listings, this visit

local function Entry()
    local line = lines[sel]
    return line and line.entry
end

local function VisibleRows()
    return math.floor((BY.H - 30 - 40) / ROW_H)
end

function ST.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()

    -- Left: the list
    local listW = BY.W - 14 - 12 - LEFT_W - 16
    listBox = BY.Panel(f, 0.4)
    listBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30)
    listBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 36)
    listBox:SetWidth(listW)
    rows = {}
    local width = listW - 12
    for i = 1, VisibleRows() do
        local r = K.NewFrame("Button", nil, listBox)
        r:SetSize(width, ROW_H - 4)
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.focus = BY.FocusStroke(r)
        r.icon = BY.ItemIcon(r, 26)
        r.icon:SetPoint("LEFT", 6, 0)
        r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 0, 0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r, "RIGHT", -110, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.value = K.ChatText(r, 11, KC.cream2)
        r.value:SetPoint("RIGHT", -8, 0)
        r.value:SetJustifyH("RIGHT")
        r.header = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.header:SetPoint("LEFT", 6, -4)
        r.headerInfo = K.ChatText(r, 11, KC.help)
        r.headerInfo:SetPoint("RIGHT", -8, -4)
        r.rule = r:CreateTexture(nil, "ARTWORK")
        r.rule:SetHeight(1)
        r.rule:SetPoint("BOTTOMLEFT", 0, 2)
        r.rule:SetPoint("BOTTOMRIGHT", 0, 2)
        r.rule:SetColorTexture(0.45, 0.38, 0.25, 0.8)
        r:SetScript("OnClick", function(self)
            if self.line and self.line.entry then
                sel = self.lineIndex
                ST.Pick()
            end
        end)
        rows[i] = r
    end
    f.empty = K.ChatText(listBox, 13, KC.grey)
    f.empty:SetPoint("CENTER")
    f.empty:SetText("Nothing in the bags to sell")

    -- Right: the picked item
    left = BY.Panel(f, 0.4)
    left:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -30)
    left:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 36)
    left:SetWidth(LEFT_W)
    left.icon = BY.ItemIcon(left, 40)
    left.icon:SetPoint("TOPLEFT", 14, -14)
    left.count = left:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    left.count:SetPoint("BOTTOMRIGHT", left.icon, "BOTTOMRIGHT", -1, 1)
    left.name = left:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    left.name:SetPoint("TOPLEFT", left.icon, "TOPRIGHT", 10, -2)
    left.name:SetPoint("RIGHT", left, "RIGHT", -14, 0)
    left.name:SetJustifyH("LEFT")
    left.name:SetWordWrap(false)
    left.why = K.ChatText(left, 11, KC.help)
    left.why:SetPoint("BOTTOMLEFT", left.icon, "BOTTOMRIGHT", 10, 2)
    left.why:SetPoint("RIGHT", left, "RIGHT", -14, 0)
    left.why:SetJustifyH("LEFT")
    left.chart = IF.AuctionChart.New(left, "Yours")
    left.chart:SetPoint("TOPLEFT", 10, -66)
    left.chart:SetPoint("TOPRIGHT", -10, -66)
    left.chart:SetHeight(140)
    -- The price, its suggestion, the market: big, centred up and down
    -- between the chart and the receipt (a group sized to what it shows)
    -- (the lowest and usual prices under the chart, as the Buy tab's)
    left.info = K.ChatText(left, 12, KC.cream2)
    left.info:SetPoint("TOPLEFT", left.chart, "BOTTOMLEFT", 0, -8)
    left.info:SetPoint("TOPRIGHT", left.chart, "BOTTOMRIGHT", 0, -8)
    left.info:SetJustifyH("CENTER")
    left.mid = K.NewFrame("Frame", nil, left)
    left.mid:SetPoint("TOPLEFT", left.info, "BOTTOMLEFT", 0, -4)
    left.mid:SetPoint("TOPRIGHT", left.info, "BOTTOMRIGHT", 0, -4)
    left.group = K.NewFrame("Frame", nil, left.mid)
    left.group:SetPoint("LEFT")
    left.group:SetPoint("RIGHT")
    left.group:SetPoint("CENTER")
    left.price = K.Text(left.group, 26, KC.title)
    left.price:SetPoint("TOP", 0, 0)
    left.leftArrow = K.Text(left.group, 26, KC.focus)
    left.leftArrow:SetPoint("RIGHT", left.price, "LEFT", -12, 0)
    left.leftArrow:SetText("‹")
    left.rightArrow = K.Text(left.group, 26, KC.focus)
    left.rightArrow:SetPoint("LEFT", left.price, "RIGHT", 12, 0)
    left.rightArrow:SetText("›")
    left.preset = K.ChatText(left.group, 16, KC.dimGold)
    left.preset:SetPoint("TOP", left.price, "BOTTOM", 0, -8)
    left.warn = K.ChatText(left.group, 14, KC.warn)
    left.warn:SetPoint("TOP", left.preset, "BOTTOM", 0, -10)
    left.warn:SetWidth(LEFT_W - 28)
    left.warn:SetJustifyH("CENTER")
    left.warn:SetWordWrap(true)
    left.vendorOnly = K.ChatText(left.mid, 15, KC.cream)
    left.vendorOnly:SetPoint("CENTER")
    left.vendorOnly:SetWidth(LEFT_W - 40)
    left.vendorOnly:SetJustifyH("CENTER")
    -- The receipt
    -- The hold status, at the bottom (AuctionBuy.lua's hold box)
    local hold = BY.HoldBox(left)
    hold:SetPoint("BOTTOMLEFT", 14, 12)
    hold:SetPoint("BOTTOMRIGHT", -14, 12)
    left.hold = hold
    local receipt = K.NewFrame("Frame", nil, left)
    receipt:SetPoint("BOTTOMLEFT", hold, "TOPLEFT", 8, 10)
    receipt:SetPoint("BOTTOMRIGHT", hold, "TOPRIGHT", -8, 10)
    receipt:SetHeight(18 * 3 + 7)
    left.receipt = receipt
    left.mid:SetPoint("BOTTOM", receipt, "TOP", 0, 6)
    left.lines = {}
    for i = 1, 3 do
        local y = -(i - 1) * 18 - (i == 3 and 7 or 0)
        local big = i == 3
        local label = K.ChatText(receipt, big and 13 or 12, big and KC.cream or KC.help)
        label:SetPoint("TOPLEFT", 0, y)
        local value = K.ChatText(receipt, big and 13 or 12, big and KC.title or KC.cream)
        value:SetPoint("TOPRIGHT", 0, y)
        left.lines[i] = { label = label, value = value }
    end
    local rule = receipt:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -37)
    rule:SetPoint("TOPRIGHT", 0, -37)
    rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)
    return f
end

---------------------------------------------------------------------------
-- The picked item's sale
---------------------------------------------------------------------------
local function Suggest()
    local price, presets, warn, key = A.Suggest(P.entry.itemID, P.listings, P.entry.vendor)
    P.presets, P.warn = presets, warn
    if P.touched and not P.presetLabel then return end
    local picked
    for _, p in ipairs(presets) do
        if p.key == (P.picked or key) then picked = p end
    end
    if picked then
        P.price, P.preset, P.presetLabel = picked.price, picked.key, picked.label
    else
        P.price, P.preset, P.presetLabel = price, key, "Vendor price × 3"
    end
end

-- A price's step: about 1-10 % of it, in a round coin
local function Step(price)
    local step = 1
    while step * 100 <= price do step = step * 10 end
    if AH.SupportsCopperValues and not AH.SupportsCopperValues() then step = math.max(step, 100) end
    return step
end

local function Search()
    local e = P.entry
    P.searching, P.pending = true, nil
    A.Search(e.itemID, e.commodity, e.itemLevel, function(listings)
        if not P or P.entry ~= e then return end
        P.searching, P.searched = false, true
        if listings then listingsCache[e.key] = listings end
        P.listings = listings or P.listings
        P.lowestNow = P.listings and P.listings[1] and P.listings[1].unit
        Suggest()
        if not listings then P.warn = "No answer from the auction house: prices from history" end
        BY.Render()
    end)
end

-- The picked item (R3 held: its Library page)
function ST.FocusedItem()
    local e = P and P.entry
    return e and (e.link or e.itemID)
end

-- A new item picked: its sale set up (looked up after a moment's rest)
function ST.Pick()
    local e = Entry()
    if not e then
        P = nil
        return BY.Render()
    end
    if P and P.entry.key == e.key then
        P.entry = e
        return BY.Render()
    end
    local want = S().quantity
    P = {
        entry = e, duration = S().duration,
        qty = want == "one" and 1 or want == "stack" and math.min(e.stack, e.count) or e.count,
        listings = listingsCache[e.key], pickedAt = GetTime(),
    }
    P.lowestNow = P.listings and P.listings[1] and P.listings[1].unit
    P.searched = P.listings ~= nil
    if e.auction then Suggest() end
    BY.Render()
end

local function Posted()
    local e = P.entry
    IF.Print("posted " .. P.qty .. " × " .. (e.link or e.name or "item") .. " at " .. A.Money(P.price)
        .. " each (" .. DURATIONS[P.duration] .. ").")
    P.message = "|cff5fd35fPosted|r"
    listingsCache[e.key] = nil
end

-- From a press (the server wants a hardware event for these)
-- The item still where it was (nothing moved in the bags meanwhile)
local function StillThere(e)
    return P and P.entry == e and e.loc:IsValid() and C_Item.GetItemID(e.loc) == e.itemID
end

-- Posting, from the popup's Cross (the server wants a hardware event); a
-- price the server warns about: a second popup, its Cross posts it
local function DoPost(e)
    if not StillThere(e) or IF.InCombat() then return end
    local duration, qty, price = P.duration, P.qty, P.price
    local needsConfirm
    if e.commodity then
        needsConfirm = AH.PostCommodity(e.loc, duration, qty, price)
    else
        needsConfirm = AH.PostItem(e.loc, duration, qty, nil, price)
    end
    if not needsConfirm then return Posted() end
    P.pending = true
    IF.AuctionConfirm.Show({
        title = "Price warning", over = BY.window,
        icon = e.icon, count = qty, name = e.name or "item", quality = e.quality,
        sub = "|cffff7a5cThe auction house warns about this price|r",
        lines = { { "Price each", A.Money(price) }, { "Duration", DURATIONS[duration] } },
        total = { "Post it anyway?", A.Money(price * qty) },
        accept = "Post anyway",
        onAccept = function()
            if not StillThere(e) then return end
            P.pending = nil
            if e.commodity then
                AH.ConfirmPostCommodity(e.loc, duration, qty, price)
            else
                AH.ConfirmPostItem(e.loc, duration, qty, nil, price)
            end
            Posted()
            BY.Render()
        end,
        onCancel = function()
            if P then P.pending = nil end
            BY.Render()
        end,
    })
end

-- Cross held: the bar fills; full, letting go posts (from the release: a
-- hardware event)
local function CanPost()
    local e = P and P.entry
    return e and e.auction and not IF.InCombat() and StillThere(e) and not P.pending
end

local function HoldProgress()
    return BY.HoldProgress(P and P.holdStart)
end

local function RenderHold()
    if left and left.hold then left.hold:SetHold(HoldProgress(), "A", "Sell") end
end

-- A hold under way (the window rumbles with it; nil: none)
function ST.HoldProgress()
    if f and f:IsShown() and P and P.holdStart then return HoldProgress() end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Deposit()
    local e = P.entry
    if not e.loc:IsValid() then return nil end
    if e.commodity then return AH.CalculateCommodityDeposit(e.itemID, P.duration, P.qty) end
    return AH.CalculateItemDeposit(e.loc, P.duration, P.qty)
end

local function RenderList()
    local shown = #rows
    sel = math.max(1, math.min(sel, #lines))
    if sel < top then top = sel end
    if sel > top + shown - 1 then top = sel - shown + 1 end
    -- (a section's name kept in view above its first item)
    if top > 1 and lines[top - 1] and lines[top - 1].header and sel == top then top = top - 1 end
    top = math.max(1, math.min(top, math.max(1, #lines - shown + 1)))
    f.empty:SetShown(#lines == 0)
    local fr, fg, fb = BY.FocusColor()
    for i, r in ipairs(rows) do
        local index = top + i - 1
        local line = lines[index]
        r:SetShown(line ~= nil)
        if line then
            r.line, r.lineIndex = line, index
            local isHeader = line.header ~= nil
            r.header:SetShown(isHeader)
            r.headerInfo:SetShown(isHeader)
            r.rule:SetShown(isHeader)
            r.icon:SetShown(not isHeader)
            r.icon.border:SetShown(not isHeader)
            r.count:SetShown(not isHeader)
            r.name:SetShown(not isHeader)
            r.value:SetShown(not isHeader)
            if isHeader then
                r.bg:SetColorTexture(0, 0, 0, 0)
                r.focus:Hide()
                r.header:SetText(line.header.color .. line.header.label:upper() .. "|r")
                r.headerInfo:SetText(line.count .. (line.count == 1 and " item" or " items")
                    .. (line.header.key ~= "keep" and ("  ·  " .. A.Money(line.total)) or ""))
            else
                local e = line.entry
                local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality or 1]
                r.bg:SetColorTexture(0, 0, 0, 0.35)
                r.icon:SetTexture(e.icon or 134400)
                r.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
                r.count:SetText(e.count > 1 and e.count or "")
                r.name:SetText(e.name or ("item " .. e.itemID))
                r.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
                local unit = A.UnitNet(e.itemID)
                if e.section == "profit" or (e.section == "keep" and unit) then
                    r.value:SetText("≈ " .. A.Money(unit * e.count))
                elseif e.section == "unknown" then
                    r.value:SetText("|cff9d917a?|r")
                else
                    r.value:SetText(e.vendor > 0 and ("vendor " .. A.Money(e.vendor * e.count)) or "")
                end
                local on = index == sel
                r.focus:SetShown(on)
                r.focus:SetVertexColor(fr, fg, fb)
            end
        end
    end
end

local function RenderLeft()
    local e = P and P.entry
    left:SetShown(e ~= nil)
    if not e then return end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality or 1]
    left.icon:SetTexture(e.icon or 134400)
    left.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
    left.count:SetText(e.count > 1 and e.count or "")
    left.name:SetText(e.name or ("item " .. e.itemID))
    left.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    local sec
    for _, s in ipairs(SECTIONS) do
        if s.key == e.section then sec = s end
    end
    left.why:SetText(sec.color .. sec.label .. "|r  ·  " .. e.why)
    left.chart:Draw({ itemID = e.itemID, lowestNow = P.lowestNow, price = e.auction and P.price or nil,
        searching = P.searching })
    local sale = e.auction
    for _, part in ipairs({ left.price, left.leftArrow, left.rightArrow, left.preset, left.info, left.receipt,
        left.hold }) do
        part:SetShown(sale)
    end
    left.vendorOnly:SetShown(not sale)
    if not sale then
        left.vendorOnly:SetText("Can't be auctioned (bound).|nA vendor pays " .. A.Money(e.vendor * e.count)
            .. (e.count > 1 and (" for all " .. e.count) or "") .. ".")
        left.warn:SetText("")
        return
    end
    left.price:SetText(A.Money(P.price) .. (P.qty > 1 and "|cff9d917a/each|r" or ""))
    left.preset:SetText(P.presetLabel or "Your own price")
    local fr, fg, fb = BY.FocusColor()
    left.leftArrow:SetTextColor(fr, fg, fb)
    left.rightArrow:SetTextColor(fr, fg, fb)
    local market = A.MarketPrice(e.itemID)
    local parts = {}
    if P.searching then
        parts[#parts + 1] = "Checking the auction house..."
    elseif P.lowestNow then
        parts[#parts + 1] = "Lowest now " .. A.Money(P.lowestNow)
    elseif P.searched then
        parts[#parts + 1] = "None listed now"
    end
    if market then parts[#parts + 1] = "usually " .. A.Money(market) end
    left.info:SetText(table.concat(parts, "   ·   "))
    left.warn:SetText(P.message or P.warn or "")
    -- The group's height: what it shows, so it sits in the middle
    local warnH = left.warn:GetText() ~= "" and (10 + left.warn:GetStringHeight()) or 0
    left.group:SetHeight(left.price:GetStringHeight() + 8 + left.preset:GetStringHeight() + warnH)
    local total = P.price * P.qty
    local deposit = Deposit()
    local lines3 = {
        { "Duration", "|cffc9a25a‹|r " .. DURATIONS[P.duration] .. " |cffc9a25a›|r" },
        { "Deposit |cff9d917a(back if sold)|r", deposit and A.Money(deposit) or "?" },
        { "Profit |cff9d917a(" .. P.qty .. " × after " .. math.floor(A.Cut() * 100) .. "% cut)|r",
            A.Money(total * (1 - A.Cut())) },
    }
    for i, l in ipairs(left.lines) do
        l.label:SetText(lines3[i][1])
        l.value:SetText(lines3[i][2])
    end
    RenderHold()
end

local function RenderTip()
    local e = P and P.entry
    if not e or BY.TipsOff() then
        if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(BY.window, "ANCHOR_NONE")
    BY.PlaceTip()
    GameTooltip:SetBagItem(e.bag, e.slot)
    GameTooltip:Show()
    BY.Compare()
end

function ST.Render()
    if not f then return end
    RenderList()
    RenderLeft()
    RenderTip()
end

function ST.Hints()
    local e = P and P.entry
    local parts = {}
    if e and e.auction then
        parts[#parts + 1] = Glyph("A") .. " Hold to Sell"
        parts[#parts + 1] = Glyph("DPAD_LR") .. " Price"
        parts[#parts + 1] = Glyph("LB") .. " " .. Glyph("RB") .. " Duration"
        parts[#parts + 1] = Glyph("Y") .. " Suggested"
    end
    parts[#parts + 1] = Glyph("DPAD_UD") .. " Item"
    parts[#parts + 1] = Glyph("LT") .. " " .. Glyph("RT") .. " Section"
    parts[#parts + 1] = Glyph("B") .. " Close"
    return table.concat(parts, "   ")
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- The next item line up / down (headers skipped); by section: the first
-- item of the next / previous section
local function Move(dir)
    local i = sel
    repeat
        i = i + dir
    until i < 1 or i > #lines or lines[i].entry
    if lines[i] then sel = i end
end

local function MoveSection(dir)
    local i = sel
    if dir > 0 then
        repeat i = i + 1 until i > #lines or lines[i].header
        if lines[i] then sel = i + 1 end
    else
        -- back to this section's header, then the one before it
        repeat i = i - 1 until i < 1 or lines[i].header
        repeat i = i - 1 until i < 1 or lines[i].header
        if i >= 1 then sel = i + 1 end
    end
end

function ST.Press(name, fast)
    -- (anything else pressed while holding: the hold dropped)
    if P and P.holdStart and name ~= "A" then P.holdStart = nil end
    if name == "UP" or name == "DOWN" then
        Move(name == "UP" and -1 or 1)
        ST.Pick()
        return true
    elseif name == "LT" or name == "RT" then
        MoveSection(name == "RT" and 1 or -1)
        ST.Pick()
        return true
    end
    local e = P and P.entry
    if not e or not e.auction then return name ~= "B" end
    if name == "LEFT" or name == "RIGHT" then
        local step = Step(P.price) * (fast and 10 or 1)
        local price = math.floor((P.price + (name == "RIGHT" and 1 or -1) * step) / step + 0.5) * step
        P.price = A.Round(math.max(price, 1))
        P.preset, P.presetLabel, P.picked, P.touched = nil, nil, nil, true
        -- (kept: its next sale starts at it)
        A.SetMyPrice(e.itemID, P.price)
    elseif name == "LB" or name == "RB" then
        P.duration = math.max(1, math.min(#DURATIONS, P.duration + (name == "RB" and 1 or -1)))
        -- (kept: the next sale starts at it)
        S().duration = P.duration
    elseif name == "Y" then
        if P.presets and #P.presets > 0 then
            local at = 0
            for i, p in ipairs(P.presets) do
                if p.key == P.preset then at = i end
            end
            local p = P.presets[at % #P.presets + 1]
            P.preset, P.presetLabel, P.price, P.picked = p.key, p.label, p.price, p.key
        end
    elseif name == "A" then
        if CanPost() then
            P.holdStart = GetTime()
            P.message = nil
            BY.Render()
        end
        return true
    else
        return name ~= "B"
    end
    P.message = nil
    BY.Render()
    return true
end

-- Cross let go: full, posted (the release: a hardware event); short of it,
-- nothing
function ST.Release(name)
    if name ~= "A" or not (P and P.holdStart) then return end
    local full = HoldProgress() >= 1
    P.holdStart = nil
    if full and CanPost() then
        DoPost(P.entry)
        BY.HoldDone()
    end
    BY.Render()
end

-- A moment's rest on an item: its listings looked up (once a visit)
function ST.Update(now)
    -- (the hold bar filling)
    if P and P.holdStart then RenderHold() end
    if not P or P.searching or P.searched or not P.entry.auction then return end
    if now - P.pickedAt >= SEARCH_AFTER then
        Search()
        BY.Render()
    end
end

function ST.Refresh()
    questNeeds = nil
    local key = P and P.entry.key
    Scan()
    -- The same item kept picked (or the line where it was)
    for i, line in ipairs(lines) do
        if line.entry and line.entry.key == key then sel = i end
    end
    if not Entry() then Move(1) end
    if not Entry() then Move(-1) end
    if P and Entry() and Entry().key == key then
        P.entry = Entry()
        -- (fewer than it was set to: what is left)
        P.qty = math.min(P.qty, P.entry.count)
    else
        P = nil
        ST.Pick()
    end
end

function ST.Show()
    f:Show()
    sel, top = 1, 1
    ST.Refresh()
    if not Entry() then Move(1) end
    P = nil
    ST.Pick()
end

function ST.Hide()
    if f then f:Hide() end
    if P then P.holdStart = nil end
    if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_POST_WARNING" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_CLOSED" then
        wipe(listingsCache)
        P = nil
        return
    end
    if event == "AUCTION_HOUSE_POST_WARNING" then
        -- Ours to confirm (our popup), not the game's dialog (after its own
        -- handler); (the event comes during the post call itself)
        if f and f:IsShown() then
            C_Timer.After(0, function()
                if StaticPopup_Hide then StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING") end
            end)
        end
        return
    end
    if event == "QUEST_LOG_UPDATE" then questNeeds = nil end
    if f and f:IsShown() then
        ST.Refresh()
        BY.Render()
    end
end)

if IF.Upgrades then
    IF.Upgrades.OnChange(function()
        if f and f:IsShown() then
            ST.Refresh()
            BY.Render()
        end
    end)
end

BY.AddPage(ST)
