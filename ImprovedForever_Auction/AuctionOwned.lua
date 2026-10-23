-- The auction house window's Auctions tab (AuctionBuy.lua's window): the
-- player's own auctions, each with what it asks, how long it has left and
-- whether it is still the lowest (Auction.lua's prices: "Undercut" when
-- someone asks less), sold ones first (their money waits in the mail).
-- The D-pad picks; Square held cancels: a "Hold to Cancel" bar fills while
-- held (the row says what cancelling costs; the deposit is lost), and once full letting go
-- cancels (the server wants a hardware event: the release is one).
-- Triangle looks again; the picked one's tooltip beside the window.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local A = IF.Auction
local AH = C_AuctionHouse
local BY = IF.AuctionBuy
local SC = IF.AuctionScene

local OW = { key = "auctions", label = "Auctions", icon = "Interface\\Icons\\INV_Scroll_03" }
IF.AuctionOwned = OW

local ROW_H = 46
local LIST_W = 620                 -- (the list in the page's middle)
local CHEAP, DEAR, SOLD_C, UNDER = { 0.55, 0.85, 0.55 }, { 0.92, 0.55, 0.5 }, { 0.56, 0.85, 0.56 }, { 0.92, 0.55, 0.5 }
local SOLD = Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
local BANDS = { [0] = "Short", [1] = "Medium", [2] = "Long", [3] = "Very long" }

local Glyph = function(key, size) return BY.Glyph(key, size) end

local f, rows, summary, message
local auctions = {}
local sel, top = 1, 1
local loading = false
local holding                      -- { id, start }: Square held on an auction
local freeTop = false              -- the wheel scrolled the list (the pick out of view, kept)

local function AuctionTip(a)
    if a.itemLink then
        GameTooltip:SetHyperlink(a.itemLink)
    elseif GameTooltip.SetItemKey then
        GameTooltip:SetItemKey(a.itemKey.itemID, a.itemKey.itemLevel, a.itemKey.itemSuffix)
    end
end

local function TimeLeft(a)
    local s = a.timeLeftSeconds
    if s and s > 0 then
        local h = math.floor(s / 3600)
        local m = math.floor((s % 3600) / 60)
        if h >= 1 then return h .. " h " .. (m > 0 and (m .. " min") or "") end
        return math.max(1, m) .. " min"
    end
    return a.timeLeft and BANDS[a.timeLeft] or ""
end

local function Unit(a)
    local price = a.buyoutAmount or a.bidAmount
    return price and price / math.max(1, a.quantity) or nil
end

-- Someone asks less (the latest lowest seen today), or nil
local function Undercut(a)
    if a.status == SOLD then return nil end
    local unit = Unit(a)
    local day, lowest = A.Latest(a.itemKey.itemID)
    if unit and day == A.Today() and lowest and lowest < unit - 0.5 then return lowest end
end

function OW.Query()
    if not A.IsOpen() then return end
    loading = true
    AH.QueryOwnedAuctions({ { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } })
end

local function Loaded()
    loading = false
    auctions = AH.GetOwnedAuctions() or {}
    -- Sold first (to collect), then by name
    table.sort(auctions, function(a, b)
        if (a.status == SOLD) ~= (b.status == SOLD) then return a.status == SOLD end
        local ia = AH.GetItemKeyInfo(a.itemKey)
        local ib = AH.GetItemKeyInfo(b.itemKey)
        return (ia and ia.itemName or "") < (ib and ib.itemName or "")
    end)
    sel = math.max(1, math.min(sel, #auctions))
end

-- The page, in the scene's look (AuctionScene.lua): no panels. Over the
-- list a line of what's up, sold and undercut; the auctions down the
-- page's middle, each a bare row (its icon in the square ring, its name,
-- how long it has left and its price each under it, its price on the
-- right, a capsule under that: sold, undercut, against its usual price),
-- the picked one in a soft gold light; "Hold to Cancel" along the bottom.
function OW.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    summary = SC.Text(f, 12, SC.CREAM, SC.BODY)
    summary:SetPoint("TOP", 0, -14)
    message = SC.Text(f, 12, { 1, 0.72, 0.45 }, SC.BODY)
    message:SetPoint("TOP", summary, "BOTTOM", 0, -4)
    local rule = SC.Rule(f, LIST_W, false, 0.5)
    rule:SetPoint("TOP", 0, -50)
    local box = K.NewFrame("Frame", nil, f)
    box:SetPoint("TOP", rule, "BOTTOM", 0, -6)
    box:SetPoint("BOTTOM", 0, 36)
    box:SetWidth(LIST_W)
    f.empty = SC.Text(box, 13, SC.GREY, SC.BODY)
    f.empty:SetPoint("CENTER")
    rows = {}
    -- (room under the rows for the hold line)
    for i = 1, math.floor((BY.H - 56 - 36 - 56) / ROW_H) do
        local r = SC.Row(box, ROW_H - 4, 30)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT", box, "RIGHT", 0, 0)
        r:SetScript("OnClick", function(self)
            if self.index then
                sel = self.index
                holding = nil
                BY.Render()
            end
        end)
        BY.Hover(r, function(self)
            local a = self.index and auctions[self.index]
            if not a then return false end
            AuctionTip(a)
        end)
        rows[i] = r
    end
    -- (the wheel scrolls the list, the pick left where it is)
    local wheel = { box }
    for _, r in ipairs(rows) do wheel[#wheel + 1] = r end
    BY.Wheel(wheel, function(dir)
        freeTop = true
        top = math.max(1, math.min(math.max(1, #auctions - #rows + 1), top + dir))
        BY.Render()
    end)
    -- "Hold to Cancel", along the bottom (AuctionScene.lua's hold line;
    -- held down with the mouse too)
    f.hold = SC.HoldLine(box)
    f.hold:SetPoint("BOTTOMLEFT", 60, 6)
    f.hold:SetPoint("BOTTOMRIGHT", -60, 6)
    f.hold.onDown = function() BY.MouseDown("X") end
    f.hold.onUp = function() BY.MouseUp("X") end
    return f
end

-- An auction's capsule: sold, undercut (and by how much), cancelling's
-- cost while held, else its price against its usual one
local function Tag(a, unit)
    if a.status == SOLD then return { "SOLD", SOLD_C } end
    if holding and holding.id == a.auctionID then
        return { "CANCELLING COSTS " .. A.Money(holding.cost), UNDER }
    end
    local lower = Undercut(a)
    if lower then return { "UNDERCUT  " .. A.Money(lower), UNDER } end
    local usual = A.MarketPrice(a.itemKey.itemID)
    local pct = usual and usual > 0 and unit and math.floor((unit / usual - 1) * 100 + 0.5)
    if pct and pct <= -5 then return { -pct .. "% BELOW USUAL", CHEAP } end
    if pct and pct >= 5 then return { pct .. "% ABOVE USUAL", DEAR } end
end

function OW.Render()
    if not f then return end
    local n = #auctions
    sel = math.max(1, math.min(sel, math.max(1, n)))
    local shown = #rows
    if not freeTop then
        if sel < top then top = sel end
        if sel > top + shown - 1 then top = sel - shown + 1 end
    end
    top = math.max(1, math.min(top, math.max(1, n - shown + 1)))
    local active, sold, worth, undercut = 0, 0, 0, 0
    for _, a in ipairs(auctions) do
        if a.status == SOLD then sold = sold + 1 else active = active + 1 end
        worth = worth + (a.buyoutAmount or a.bidAmount or 0)
        if Undercut(a) then undercut = undercut + 1 end
    end
    summary:SetText(active .. " up  |cff7d776a·|r  " .. sold .. " sold"
        .. (sold > 0 and " |cff9d917a(money in the mail)|r" or "")
        .. "  |cff7d776a·|r  worth " .. A.Money(worth)
        .. (undercut > 0 and ("  |cff7d776a·|r  |cffeb8c80" .. undercut .. " undercut|r") or ""))
    message:SetText(OW.message or "")
    f.empty:SetShown(n == 0)
    f.empty:SetText(loading and "Loading..." or "No auctions of yours")
    for i, r in ipairs(rows) do
        local index = top + i - 1
        local a = auctions[index]
        r:SetShown(a ~= nil)
        if a then
            r.index = index
            local info = AH.GetItemKeyInfo(a.itemKey)
            local unit = Unit(a)
            local isSold = a.status == SOLD
            local parts = {}
            if not isSold then parts[#parts + 1] = TimeLeft(a) .. " left" end
            if a.quantity > 1 and unit then parts[#parts + 1] = a.quantity .. " × " .. A.Money(unit) end
            r:Fill({
                icon = info and info.iconFileID, quality = info and info.quality, count = a.quantity,
                name = info and info.itemName or "...", line = table.concat(parts, "  ·  "),
                price = A.Money(a.buyoutAmount or a.bidAmount or 0), tag = Tag(a, unit),
            })
            r:Lit(index == sel, true)
        end
    end
    OW.RenderHold()
    -- The picked one's tooltip, beside the window
    local a = not BY.TipsOff() and auctions[sel]
    if BY.Hovering() then
        return
    elseif a then
        GameTooltip:SetOwner(BY.window, "ANCHOR_NONE")
        BY.PlaceTip()
        AuctionTip(a)
        GameTooltip:Show()
        BY.Compare()
    elseif GameTooltip:GetOwner() == BY.window then
        GameTooltip:Hide()
    end
end

-- The hold line (as far as the hold has come; the held row's capsule
-- says what cancelling costs: Tag)
function OW.RenderHold()
    if not rows then return end
    local a = auctions[sel]
    f.hold:SetShown(a ~= nil and a.status ~= SOLD)
    f.hold:SetHold(BY.HoldProgress(holding and holding.start), "X", "Cancel")
end

-- The picked auction's item (R3 held: its Wiki page)
function OW.FocusedItem()
    local a = auctions[sel]
    return a and (a.itemLink or (a.itemKey and a.itemKey.itemID))
end

-- A hold under way (the window rumbles with it; nil: none)
function OW.HoldProgress()
    if f and f:IsShown() and holding then return BY.HoldProgress(holding.start) end
end

function OW.Update()
    if holding then OW.RenderHold() end
end

function OW.Hints()
    local a = auctions[sel]
    local parts = {}
    if a and a.status ~= SOLD then
        parts[#parts + 1] = Glyph("X") .. " Hold to Cancel"
    end
    parts[#parts + 1] = Glyph("DPAD_UD") .. " Move"
    parts[#parts + 1] = Glyph("Y") .. " Refresh"
    parts[#parts + 1] = Glyph("B") .. " Close"
    return table.concat(parts, "   ")
end

-- The mouse's buttons in the legend's place (the hold box cancels)
function OW.MouseHints()
    return { { "Refresh", function() BY.Press("Y") end } }
end

-- Square held: the hold starts on the picked auction (one that can be)
local function CancelStart()
    local a = auctions[sel]
    if not a or a.status == SOLD or IF.InCombat() then return end
    if AH.CanCancelAuction and not AH.CanCancelAuction(a.auctionID) then
        OW.message = "That one can't be cancelled"
        return
    end
    holding = { id = a.auctionID, start = GetTime(), cost = AH.GetCancelCost and AH.GetCancelCost(a.auctionID) or 0 }
    OW.message = nil
end

-- Square let go (a hardware event): full, cancelled; short of it, nothing
function OW.Release(name)
    if name ~= "X" or not holding then return end
    local h = holding
    holding = nil
    if BY.HoldProgress(h.start) >= 1 and not IF.InCombat() then
        OW.message = "Cancelling..."
        AH.CancelAuction(h.id)
        BY.HoldDone()
    end
    BY.Render()
end

function OW.Press(name, fast)
    -- (anything else pressed while holding: the hold dropped)
    if holding and name ~= "X" then holding = nil end
    if name == "UP" or name == "DOWN" then
        freeTop = false
        sel = math.max(1, math.min(#auctions, sel + (name == "UP" and -1 or 1) * (fast and 5 or 1)))
        OW.message = nil
    elseif name == "Y" then
        OW.message = nil
        OW.Query()
    elseif name == "X" then
        CancelStart()
    else
        return name ~= "B"
    end
    BY.Render()
    return true
end

function OW.Show()
    f:Show()
    OW.message = nil
    OW.Query()
end

function OW.Hide()
    if f then f:Hide() end
    holding = nil
    if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED",
    "ITEM_KEY_ITEM_INFO_RECEIVED", "AUCTION_HOUSE_CLOSED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_CLOSED" then
        auctions, OW.message, holding = {}, nil, nil
        return
    end
    if not (f and f:IsShown()) then return end
    if event == "OWNED_AUCTIONS_UPDATED" then
        Loaded()
    elseif event == "AUCTION_CANCELED" then
        OW.message = "|cff5fd35fCancelled|r"
        OW.Query()
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        OW.Query()
    end
    BY.Render()
end)

BY.AddPage(OW)
