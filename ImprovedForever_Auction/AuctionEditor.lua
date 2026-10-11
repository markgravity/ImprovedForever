-- The Auction tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- the auction window on top (off: every auction feature off), the price
-- scans and what is kept of them, selling (the price it starts at, the
-- duration), what uses the prices. Auction.lua and AuctionBuy.lua (and its
-- tabs) do the work.
local IF = ImprovedForever

local menu = IF.Menu
local A = IF.Auction
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff


local function S()
    return A.Settings()
end

-- A choice of values: { { value, name }... } on a setting's key
local function Choice(key, label, choices)
    local byValue = {}
    for _, c in ipairs(choices) do byValue[c[1]] = c end
    return {
        value = function() return tostring(S()[key]) end,
        text = function()
            local c = byValue[S()[key]]
            return c and c[2] or tostring(S()[key])
        end,
        options = function()
            local list = {}
            for _, c in ipairs(choices) do
                list[#list + 1] = { action = tostring(c[1]), name = c[2] }
            end
            return list
        end,
        choose = function(action)
            for _, c in ipairs(choices) do
                if tostring(c[1]) == action then
                    S()[key] = c[1]
                    menu.Toast(label .. ": " .. c[2])
                end
            end
        end,
    }
end

local function Ago(at)
    if not at then return "never" end
    local s = math.max(0, time() - at)
    if s < 3600 then return math.floor(s / 60) .. " min ago" end
    if s < 86400 then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / 86400) .. " days ago"
end

local ITEMS = {
    Item({
        key = "buy", group = "auction", label = "Auction window",
        tip = "Opens over the auction house, used with the pad, its tabs down the right (the right stick up / down): Buy (the left"
            .. " stick picks the category, L1 / R1 and L2 / R2 the next two levels, L3 the filters), Sell (your"
            .. " bags sorted for profit), Auctions (yours, to cancel) and Tasks. Off: the game's own window, and every"
            .. " auction feature off (no scan, no prices in tooltips, for junk or in the Destroy panel).",
    }, OnOff(function() return S().buy end, function(on) S().buy = on end, "Auction window")),
    Item({
        key = "scan", group = "scan", label = "Scan on open",
        tip = "Reads every auction as the auction house opens, and keeps each item's lowest and market price"
            .. " for the day. The server allows one full scan in 15 minutes; it takes a few seconds.",
    }, OnOff(function() return S().scan end, function(on) S().scan = on end, "Scan on open")),
    Item({
        key = "data", group = "scan", label = "Price data",
        tip = "Prices kept for this realm. Scan now needs the auction house open (also /if scan).",
        text = function()
            if not A.Available() then return "|cffff7a5cNo auction house on this client|r" end
            local n, at = A.Stats()
            local scanning, read, total = A.Scanning()
            return n .. " items priced|nLast scan: " .. Ago(at)
                .. (scanning and ("|n|cff9fd8e2Scanning" .. (total and (" " .. read .. " / " .. total) or "...") .. "|r") or "")
        end,
        value = function() end,
        options = function()
            return {
                { action = "scan", name = "Scan now" },
                { action = "clear", name = menu.IsArmed("auction:clear") and "|cffff7a5cAgain to clear|r"
                    or "Clear this realm's prices" },
            }
        end,
        choose = function(action)
            if action == "scan" then
                local ok, why = A.CanScan()
                if ok then A.Scan() end
                menu.Toast(ok and "Scanning the auction house..." or ("Scan: " .. why), not ok, ok and 1.8 or 3)
            elseif menu.IsArmed("auction:clear") then
                menu.Disarm()
                A.Clear()
                menu.Toast("Prices cleared", true)
            else
                menu.Arm("auction:clear")
                menu.Toast("Choose it again to clear this realm's prices", true, 4)
            end
        end,
    }),
    Item({
        key = "keepDays", group = "scan", label = "Keep prices",
        tip = "How long each day's prices are kept. Older ones go at login.",
    }, Choice("keepDays", "Keep prices", {
        { 14, "14 days" }, { 30, "30 days" }, { 60, "60 days" }, { 90, "90 days" },
    })),
    Item({
        key = "pricing", group = "sell", label = "Start at",
        tip = "The price the Sell tab suggests first; Triangle goes through the others. With none listed,"
            .. " the market price; with nothing known, three times what a vendor pays. A price you set by"
            .. " hand for an item comes first next time (Your last price).",
    }, Choice("pricing", "Start at", {
        { "undercut", "Undercut the lowest" }, { "match", "Match the lowest" },
        { "market", "Market price (its usual)" },
    })),
    Item({
        key = "undercut", group = "sell", label = "Undercut by",
        tip = "How far under the lowest price anyone else asks. Your own lowest is matched, never undercut.",
    }, Choice("undercut", "Undercut by", {
        { "1", "1 copper" }, { "100", "1 silver" }, { "1%", "1%" }, { "5%", "5%" },
    })),
    Item({
        key = "vendorFloor", group = "sell", label = "Vendor floor",
        tip = "Never suggests less than a vendor pays for it, after the auction house's cut.",
    }, OnOff(function() return S().vendorFloor end, function(on) S().vendorFloor = on end, "Vendor floor")),
    Item({
        key = "duration", group = "sell", label = "Duration",
        tip = "How long auctions run: longer costs a bigger deposit. Changing it while selling sets it here too.",
    }, Choice("duration", "Duration", {
        { 1, IF.Auction.Durations()[1] }, { 2, IF.Auction.Durations()[2] }, { 3, IF.Auction.Durations()[3] },
    })),
    Item({
        key = "chartDays", group = "sell", label = "Chart",
        tip = "The days the price chart shows, and the market price is taken over.",
    }, Choice("chartDays", "Chart", {
        { 7, "Last 7 days" }, { 14, "Last 14 days" }, { 30, "Last 30 days" },
    })),
}

ITEMS[#ITEMS + 1] = Item({
    key = "tooltip", group = "use", label = "Tooltips",
    tip = "Item tooltips show its usual auction price and the latest lowest (and a bag stack's worth).",
}, OnOff(function() return S().tooltip end, function(on) S().tooltip = on end, "Tooltips"))
ITEMS[#ITEMS + 1] = Item({
    key = "destroy", group = "use", label = "Junk",
    tip = "What sells for more at the auction house than to a vendor (unless next to nothing either way)"
        .. " is never marked junk, and the Destroy panel shows each item's auction worth.",
}, OnOff(function() return S().destroy end, function(on)
    S().destroy = on
    IF.ItemValue.Changed()
end, "Junk"))

ITEMS[#ITEMS + 1] = Item({
    key = "upgradeBags", group = "upgrades", label = "Bag arrows",
    tip = "A green arrow on a bag item better than what you wear in its slot: scored by its stats for"
        .. " your class and talents (else its item level), only what you can wear. The Buy window marks"
        .. " them too (its filters, L3). The Destroy panel never offers one.",
}, OnOff(function() return IF.Upgrades.Settings().bags end, function(on)
    IF.Upgrades.Settings().bags = on
    IF.Upgrades.Refresh()
end, "Bag arrows"))

ITEMS[#ITEMS + 1] = Item({
    key = "tasksTracker", group = "tasks", label = "Tasks panel",
    tip = "A Tasks panel on top of the quest tracker (the game stacks it there, the tracker made shorter), in its look: each task (a recipe's More options,"
        .. " Triangle, in a profession window: Add Task) with its reagents for all its crafts, had and needed,"
        .. " where from. With the tracker focused, L2 moves into it: Cross opens a recipe, Square crafts."
        .. " The auction house's Tasks tab and a vendor's (Triangle) buy what is missing.",
}, OnOff(function() return S().tasksTracker end, function(on)
    S().tasksTracker = on
    IF.Tasks.RenderTracker()
end, "Tasks panel"))

local GROUPS = {
    { key = "auction", label = "Auction house" },
    { key = "scan", label = "Prices" },
    { key = "sell", label = "Selling" },
    { key = "use", label = "Using prices" },
    { key = "upgrades", label = "Upgrades" },
    { key = "tasks", label = "Tasks" },
}

IF.AuctionEditor = IF.SettingsPage({ key = "auction", label = "Auction", module = "auction", order = 60 }, GROUPS, ITEMS)
