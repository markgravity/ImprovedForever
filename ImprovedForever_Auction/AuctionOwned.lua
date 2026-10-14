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

local OW = { key = "auctions", label = "Auctions", icon = "Interface\\Icons\\INV_Scroll_03" }
IF.AuctionOwned = OW

local ROW_H = 44
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

function OW.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    summary = K.ChatText(f, 12, KC.cream2)
    summary:SetPoint("TOPLEFT", 22, -34)
    message = K.ChatText(f, 12, KC.warn)
    message:SetPoint("TOPRIGHT", -26, -34)
    message:SetJustifyH("RIGHT")
    local box = BY.Panel(f, 0.4)
    box:SetPoint("TOPLEFT", 14, -54)
    box:SetPoint("BOTTOMRIGHT", -16, 36)
    f.empty = K.ChatText(box, 13, KC.grey)
    f.empty:SetPoint("CENTER")
    rows = {}
    local width = BY.W - 30 - 12
    -- (room under the rows for the hold box)
    for i = 1, math.floor((BY.H - 54 - 36 - 12 - 44) / ROW_H) do
        local r = K.NewFrame("Button", nil, box)
        r:SetSize(width, ROW_H - 4)
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        if not BY.Atlas(r.bg, "Looting_ItemCard_BG") then r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
        r.focus = BY.FocusStroke(r)
        r.icon = BY.ItemIcon(r, 34)
        r.icon:SetPoint("LEFT", 6, 0)
        r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -2)
        r.name:SetWidth(330)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.sub = K.ChatText(r, 11, KC.help)
        r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 2)
        r.time = K.ChatText(r, 12, KC.cream2)
        r.time:SetPoint("LEFT", r, "LEFT", 400, 0)
        r.price = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.price:SetPoint("TOPRIGHT", -12, -6)
        r.state = K.ChatText(r, 11, KC.help)
        r.state:SetPoint("BOTTOMRIGHT", -12, 5)
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
    -- "Hold to Cancel", at the bottom (AuctionBuy.lua's hold box; held
    -- down with the mouse too)
    f.hold = BY.HoldBox(box)
    f.hold:SetPoint("BOTTOMLEFT", 8, 8)
    f.hold:SetPoint("BOTTOMRIGHT", -8, 8)
    f.hold.onDown = function() BY.MouseDown("X") end
    f.hold.onUp = function() BY.MouseUp("X") end
    return f
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
    summary:SetText(active .. " up  ·  " .. sold .. " sold" .. (sold > 0 and " |cff9d917a(money in the mail)|r" or "")
        .. "  ·  worth " .. A.Money(worth)
        .. (undercut > 0 and ("  ·  |cffff7a5c" .. undercut .. " undercut|r") or ""))
    message:SetText(OW.message or "")
    f.empty:SetShown(n == 0)
    f.empty:SetText(loading and "Loading..." or "No auctions of yours")
    local fr, fg, fb = BY.FocusColor()
    for i, r in ipairs(rows) do
        local index = top + i - 1
        local a = auctions[index]
        r:SetShown(a ~= nil)
        if a then
            r.index = index
            local info = AH.GetItemKeyInfo(a.itemKey)
            local c = info and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
            r.icon:SetTexture(info and info.iconFileID or 134400)
            r.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
            r.count:SetText(a.quantity > 1 and a.quantity or "")
            r.name:SetText(info and info.itemName or "...")
            r.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
            local unit = Unit(a)
            r.sub:SetText(a.quantity > 1 and unit and (A.Money(unit) .. " each") or "")
            local isSold = a.status == SOLD
            r.time:SetText(isSold and "" or TimeLeft(a))
            r.price:SetText(A.Money(a.buyoutAmount or a.bidAmount or 0))
            local lower = Undercut(a)
            if isSold then
                r.state:SetText("|cff5fd35fSold|r")
            elseif lower then
                r.state:SetText("|cffff7a5cUndercut: " .. A.Money(lower) .. " each|r")
            else
                r.state:SetText(BY.Deal(a.itemKey.itemID, unit))
            end
            local on = index == sel
            r.focus:SetShown(on)
            r.focus:SetVertexColor(fr, fg, fb)
        end
    end
    OW.RenderHold()
    -- The picked one's tooltip, under the tabs
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

-- The hold box (as far as the hold has come); the held row: what
-- cancelling costs
function OW.RenderHold()
    if not rows then return end
    local a = auctions[sel]
    f.hold:SetShown(a ~= nil and a.status ~= SOLD)
    f.hold:SetHold(BY.HoldProgress(holding and holding.start), "X", "Cancel")
    if not holding then return end
    for _, r in ipairs(rows) do
        local a = r:IsShown() and auctions[r.index]
        if a and a.auctionID == holding.id then
            r.state:SetText("|cffff7a5cCancelling costs " .. A.Money(holding.cost) .. "|r")
        end
    end
end

-- The picked auction's item (R3 held: its Library page)
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
