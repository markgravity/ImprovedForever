-- Junk: what the bags no longer need, by the core's verdict (ImprovedForever's
-- ItemValue.lua: quests in the log or still to start, the recipes of the
-- character's professions, auction prices, the class's armor and weapons,
-- soulbound or not) and the player's own word:
--   the game's junk coin on each junk bag slot (a texture of ours: nothing
--     written in the game's frames);
--   a vendor's Sell All Junk sells it too, after the game's greys (its
--     button lit while there is only ours to sell; 12 at most a press, all
--     of it bought back if need be, unless the player lets it sell all);
--   an ordinary item a quest needs says so in its tooltip, in orange:
--     "Needed for "Redridge Goulash"";
--   L2 + L3 on a bag item (watched, not taken; rebindable in the Bindings
--     tab) marks it junk, or not junk: remembered for the character, by item;
--     with the mouse its click does (Alt + right-click; or a key, on the bag
--     item under the mouse).
-- Never in combat.
local IF = ImprovedForever

local IV = IF.ItemValue
local J = {}
IF.Junk = J

local DEFAULT_MARK_KEY = "PADLTRIGGER+PADLSTICK"   -- one button, or "held+pressed" (L3 alone: bag clean-up)
local SELL_BATCH = 10          -- sold at a time, then a pause (the server's pace)
local SELL_PAUSE = 0.25

local DEFAULTS = {
    icons = true,              -- the junk coin on the bag slots
    sell = true,               -- the vendor's Sell All Junk sells ours too
    sellBuyback = true,        -- 12 at most a press: all of it can be bought back
    mark = true,               -- the mark press, while a bag is open
    tooltip = true,            -- item tooltips say which quest needs an ordinary item
}

function J.Settings()
    local s = IV.Settings()
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

local function SlotInfo(bag, slot)
    return C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
end

local function AnyBagOpen()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The junk coin on the bag slots (the game's own, bags-junkcoin, where its
-- JunkIcon sits)
---------------------------------------------------------------------------
local COIN_ATLAS = "bags-junkcoin"
local coins = setmetatable({}, { __mode = "k" })
local bagFrames = {}

local function Coin(button)
    local coin = coins[button]
    if coin then return coin end
    coin = button:CreateTexture(nil, "OVERLAY", nil, 6)
    if IF.HasAtlas(COIN_ATLAS) then
        coin:SetAtlas(COIN_ATLAS, true)
    else
        coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        coin:SetSize(14, 14)
    end
    coin:SetPoint("TOPLEFT", 1, 0)
    coin:Hide()
    coins[button] = coin
    return coin
end

local function UpdateCoins(frame)
    if not (frame and frame.EnumerateValidItems and frame:IsShown()) then return end
    local on = IF.db and J.Settings().icons
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
        local junk = on and bag and IV.IsJunk(bag, slot) or false
        if junk or coins[button] then Coin(button):SetShown(junk) end
    end
end

function J.RefreshBags()
    for _, frame in ipairs(bagFrames) do UpdateCoins(frame) end
end

local function HookBags()
    local frames = { _G.ContainerFrameCombinedBags }
    local count = NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 12) + 1)
    for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems then
            bagFrames[#bagFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", UpdateCoins)
        end
    end
end

---------------------------------------------------------------------------
-- Selling: the one seller (the vendor's Sell All Junk, after the game's
-- greys; the Destroy panel's Sell and Sell All), a few at a time. Each item
-- is judged again just before it goes (the core's verdict: still what it
-- was picked for), and counted sold only once its bag slot has emptied: a
-- request proves nothing (the vendor closes, the server says no). An item
-- whose data hasn't come yet stops the run, never waved through. At most
-- what the vendor's buyback keeps (12) a run, so all of it can be bought
-- back (sellBuyback; off: all at once).
---------------------------------------------------------------------------
local BUYBACK = BUYBACK_ITEMS_PER_PAGE or 12
local CONFIRM_WAIT = 1         -- s: still in its slot, unlocked, this long after: not sold
local CONFIRM_GIVE_UP = 5      -- s: still in its slot this long after, locked or not: not sold

local function AtVendor()
    local merchant = _G.MerchantFrame
    return merchant and merchant:IsShown() or false
end
J.AtVendor = AtVendor

-- A bag the player keeps out of Sell All Junk (its settings menu); the
-- game's answer missing (an error): kept out too
local function Excluded(bag)
    local ok, out = pcall(function()
        if bag == 0 then
            return C_Container.GetBackpackSellJunkDisabled and C_Container.GetBackpackSellJunkDisabled()
        end
        local flag = Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
        return flag and C_Container.GetBagSlotFlag and C_Container.GetBagSlotFlag(bag, flag)
    end)
    if not ok then return true end
    return out and true or false
end

-- The one rule: may the vendor have it? picked: the entry it was picked
-- by; now: its verdict again (IV.Judge); bulk: a sell-all (never from a bag
-- kept out of Sell All Junk). Junk or a vendor's (never kept, never one for
-- the auction house), still what it was picked for, with a price.
function J.MaySell(picked, now, bulk)
    if not (picked and now) or now.itemID ~= picked.itemID then return false end
    if now.verdict ~= "junk" and now.verdict ~= "vendor" then return false end
    if now.verdict ~= picked.verdict or not now.sellable then return false end
    return not (bulk and Excluded(now.bag))
end

-- Ours to sell: junk a vendor buys, not grey (the game's own), out of the
-- bags it sells from
function J.ToSell()
    return IV.Bags(function(e)
        return e.verdict == "junk" and e.quality > 0 and J.MaySell(e, e, true)
    end)
end

-- run: { list, i, bulk, what, done, sent = { pending sales }, sold, unsold,
-- refused, worth, left, stop ("vendor", "data", "buyback") }; nil: none under way
local run
local blocked = false
local ticker = CreateFrame("Frame")
ticker:Hide()

local function Plural(n, what)
    return n .. " " .. what .. (n == 1 and "" or "s")
end

local function Finish(r)
    run = nil
    ticker:Hide()
    if r.sold == 1 and r.one then
        local e = r.one
        IF.Print("sold " .. (e.link or "item") .. (e.count > 1 and (" x" .. e.count) or "") .. " for " .. IV.Money(r.worth))
    elseif r.sold > 0 then
        IF.Print("sold " .. Plural(r.sold, r.what) .. " for " .. IV.Money(r.worth))
    end
    if blocked and r.sold == 0 then
        IF.Print("the game doesn't let addons sell items here.")
    elseif r.unsold > 0 then
        IF.Print(Plural(r.unsold, r.what) .. " not taken by the vendor.")
    end
    if r.refused > 0 then
        IF.Print(Plural(r.refused, r.what) .. " not sold: kept now, or in a bag kept out of Sell All Junk.")
    end
    if blocked or r.left == 0 then
        -- (nothing else to say)
    elseif r.stop == "data" then
        IF.Print("an item's data hasn't come from the server yet: selling stopped, try again.")
    elseif r.stop == "buyback" then
        IF.Print(Plural(r.left, r.what) .. " left (the vendor buys back only the last " .. BUYBACK .. "): sell again.")
    else
        IF.Print(Plural(r.left, r.what) .. " not sold: the vendor's window closed.")
    end
    if r.done then r.done(r.sold) end
end

-- The sales sent, checked: gone from its slot (sold), or still there
-- (not); the run ends once none is pending and none is left to send
local function Check()
    local r = run
    if not r then
        ticker:Hide()
        return
    end
    local now = GetTime()
    for i = #r.sent, 1, -1 do
        local s = r.sent[i]
        local info = SlotInfo(s.bag, s.slot)
        if not info or info.itemID ~= s.itemID then
            r.sold, r.worth = r.sold + 1, r.worth + s.value
            if r.sold == 1 then r.one = s end
            table.remove(r.sent, i)
        elseif now - s.at > CONFIRM_GIVE_UP or (not info.isLocked and now - s.at > CONFIRM_WAIT) then
            r.unsold = r.unsold + 1
            table.remove(r.sent, i)
        end
    end
    if #r.sent == 0 and not r.sending then Finish(r) end
end
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    Check()
end)

local function SendNext()
    local r = run
    if not r then return end
    -- (the rest left where it is: what was sent is still checked)
    local function Stop(why)
        r.stop, r.left = why, r.left + (#r.list - r.i + 1)
        r.i = #r.list + 1
    end
    local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
    if not use or not AtVendor() or IF.InCombat() or blocked then Stop("vendor") end
    local n = 0
    while r.i <= #r.list and n < SELL_BATCH do
        local e = r.list[r.i]
        local info = SlotInfo(e.bag, e.slot)
        if info and info.itemID == e.itemID then
            if r.buyback and #r.sent + r.sold + r.unsold >= BUYBACK then
                Stop("buyback")
                break
            end
            local now = IV.Judge(e.bag, e.slot)
            if not now then
                -- (its data not here yet: no verdict, no sale)
                Stop("data")
                break
            end
            if info.isLocked then
                -- (moving, or already being sold: not now)
            elseif J.MaySell(e, now, r.bulk) then
                use(e.bag, e.slot)
                if blocked then break end
                r.sent[#r.sent + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID, link = now.link,
                    count = now.count, value = now.value, at = GetTime() }
                n = n + 1
            else
                r.refused = r.refused + 1
            end
        end
        r.i = r.i + 1
    end
    if r.i <= #r.list and not blocked then
        C_Timer.After(SELL_PAUSE, SendNext)
        return
    end
    r.sending = false
    ticker:Show()
end

-- Sells the entries of list (IV.Judge's) a vendor may have (J.MaySell).
-- opts: { bulk (a sell-all), what ("junk item"; "item"), done = fn(sold),
-- once the run is over }. Out of combat, at a vendor; one run at a time.
function J.Sell(list, opts)
    opts = opts or {}
    if run or IF.InCombat() or not AtVendor() or #list == 0 then return false end
    blocked = false
    run = { list = list, i = 1, bulk = opts.bulk, buyback = J.Settings().sellBuyback, what = opts.what or "item", done = opts.done, sent = {},
        sold = 0, unsold = 0, refused = 0, worth = 0, left = 0, sending = true }
    SendNext()
    return true
end

function J.SellJunk()
    if run or IF.InCombat() or not AtVendor() then return end
    J.Sell(J.ToSell(), { bulk = true, what = "junk item" })
end

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:SetScript("OnEvent", function(_, _, addon, fn)
    if type(addon) == "string" and addon:find("^ImprovedForever") and tostring(fn):find("UseContainerItem") then
        blocked = true
    end
end)

-- The vendor's Sell All Junk button: lit while there is ours to sell, even
-- with no grey (the game lights it only for greys)
local function UpdateSellButton()
    local button = _G.MerchantSellAllJunkButton
    if not button or IF.InCombat() or not (IF.db and J.Settings().sell) or button:IsEnabled() then return end
    if not button:IsShown() or #J.ToSell() == 0 then return end
    button:SetEnabled(true)
    if button.Icon then button.Icon:SetDesaturated(false) end
end

local function HookMerchant()
    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
        hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
            if J.Settings().sell then
                -- (after the game's own, which empties the greys first)
                C_Timer.After(SELL_PAUSE, J.SellJunk)
            end
        end)
    end
    if _G.MerchantFrame_Update then hooksecurefunc("MerchantFrame_Update", UpdateSellButton) end
end

---------------------------------------------------------------------------
-- Marking: the press on a bag item (watched, not taken)
---------------------------------------------------------------------------
function J.MarkKey()
    return IF.db and J.Settings().markKey or DEFAULT_MARK_KEY
end

function J.SetMarkKey(key)
    J.Settings().markKey = key ~= DEFAULT_MARK_KEY and key or nil
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- A shoulder or trigger held: a press of one button alone is another's
-- (L2 + L3 isn't L3)
local SHOULDERS = { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }
local function Modified()
    for _, key in ipairs(SHOULDERS) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- Its name: "L2 + L3"; glyphs too with size
function J.MarkKeyText(size)
    local held, pressed = Parts(J.MarkKey())
    local function one(key)
        return (size and (IF.GlyphText(key, size) .. " ") or "") .. IF.ButtonName(key)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

-- The bag slot the game's cursor is on: bag, slot (nil: none)
function J.FocusedSlot()
    local bag, slot
    pcall(function()
        local nav = _G.SmartNavigation
        local button = nav and nav.GetCurrentButton and nav:GetCurrentButton()
        for _, f in ipairs({ button, button and button:GetParent() }) do
            if f and f.GetBagID and f.GetID then
                local b, s = f:GetBagID(), f:GetID()
                if b and s and SlotInfo(b, s) then
                    bag, slot = b, s
                    return
                end
            end
        end
    end)
    return bag, slot
end

-- The item's mark flipped (junk / not junk), said in the chat
function J.Toggle(bag, slot)
    local e = IV.Toggle(bag, slot)
    if not e then return end
    local name = e.link or e.name or "item"
    if e.tag == "Quest" then
        IF.Print(name .. ": " .. e.why .. ", never junk while it is.")
        return e
    end
    if e.verdict == "junk" then
        IF.Print(name .. " is junk" .. (e.mark == "junk" and " (marked by you)" or "") .. ".")
    else
        IF.Print(name .. " is no longer junk" .. (e.mark == "keep" and " (kept by you)" or "") .. ".")
    end
    if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
    return e
end

local watcher = CreateFrame("Frame")
local wasDown = false
watcher:SetScript("OnUpdate", function()
    if not IF.db or not IsKeyDown then return end
    local destroy = IF.Destroy and IF.Destroy.panel and IF.Destroy.panel:IsShown()
    if not J.Settings().mark or IF.InCombat() or destroy then
        wasDown = false
        return
    end
    local held, pressed = Parts(J.MarkKey())
    local down = IsKeyDown(pressed) and (held and IsKeyDown(held) or (not held and not Modified()))
    -- The moment the combination is made, on a bag item
    if down and not wasDown and AnyBagOpen() then
        local bag, slot = J.FocusedSlot()
        if bag then J.Toggle(bag, slot) end
    end
    wasDown = down
end)

-- The mouse: a click on a bag item (Alt + right-click, its binding's
-- keyboard / mouse press; the core's Input.lua), or a key on the bag item
-- under it
local function MarkHovered(item)
    if not (item and item.bag) or IF.InCombat() or not SlotInfo(item.bag, item.slot) then return end
    J.Toggle(item.bag, item.slot)
end

-- Its binding, on the Bindings tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "junkmark", label = "Mark Junk", group = "Bags", tab = "bindings",
    icon = IF.TEX .. "ic_fn_junkmark", context = "bags", order = 22,
    desc = "Marks the bag item under the cursor as junk, or not",
    tip = "Marks the bag item the cursor is on as junk, or no longer junk: sold with the vendor's Sell All"
        .. " Junk, offered first by the Destroy panel. Remembered for this character. Only while a bag is open;"
        .. " watched, not taken: the button keeps its own action.",
    accepts = B.NotDouble,
    specs = function() return J.Settings().mark and B.One(J.MarkKey()) or {} end,
    set = function(spec)
        J.Settings().mark = spec ~= nil
        if spec then J.SetMarkKey(spec) end
    end,
    reset = function() J.Settings().mark = nil end,
    click = MarkHovered,
    defaultKey = "ALT-BUTTON2",
})

---------------------------------------------------------------------------
-- Item tooltips: the quest an ordinary item is kept for, in orange
-- ("Needed for "Redridge Goulash""): the meat, the cloth a quest asks for
-- (not the game's own quest items, which say so already, nor one a vendor
-- sells: bought again any time). A bag item's: the one under
-- the cursor, the Destroy panel's card, else the bags' first of it
---------------------------------------------------------------------------
local QUEST_CLASS = 12
local QUEST_COLOR = { 1, 0.5, 0.1 }

local function TipSlot(tooltip, itemID)
    local owner = tooltip:GetOwner()
    local DS = IF.Destroy
    if DS and owner == DS.panel then
        local e = DS.items and DS.items[DS.index]
        if e and e.itemID == itemID then return e.bag, e.slot end
    end
    if owner and owner.GetBagID and owner.GetID then
        local ok, bag = pcall(owner.GetBagID, owner)
        local info = ok and bag and SlotInfo(bag, owner:GetID())
        if info and info.itemID == itemID then return bag, owner:GetID() end
    end
    for _, e in ipairs(IV.Bags(function(e) return e.itemID == itemID end)) do return e.bag, e.slot end
end

local function TooltipQuest(tooltip, data)
    if not (IF.db and J.Settings().tooltip) then return end
    if tooltip ~= GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
    local itemID = data and data.id
    if not itemID or (issecretvalue and issecretvalue(itemID)) or type(itemID) ~= "number" then return end
    local classID = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(itemID))
    -- (the game's quest items say so already; one a vendor sells is no worry)
    if classID == QUEST_CLASS or IF.GameData.SoldByVendor(itemID) then return end
    local why
    local bag, slot = TipSlot(tooltip, itemID)
    local e = bag and IV.Judge(bag, slot)
    if e then
        why = e.tag == "Quest" and e.why or nil
    else
        why = IV.QuestReason(itemID, C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))
    end
    -- (one the game marks as a quest's: its own lines say so)
    if not why or why == "Needed for a quest" or why:find("^Starts ") then return end
    tooltip:AddLine(why, QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], true)
end

---------------------------------------------------------------------------
-- /if junk: how many marks; /if junk forget: every mark forgotten
---------------------------------------------------------------------------
-- Why a bag item has its verdict: the item under the cursor (the pad's,
-- else the mouse's), else the first of an item id or link given
local function Why(msg)
    local bag, slot = J.FocusedSlot()
    if not bag then
        local item = IF.Input.Hovered()
        if item and item.bag then bag, slot = item.bag, item.slot end
    end
    local id = tonumber((msg or ""):match("item:(%d+)") or (msg or ""):match("why%s+(%d+)"))
    if id then
        bag = nil
        for _, e in ipairs(IV.Bags(function(e) return e.itemID == id end)) do
            bag, slot = e.bag, e.slot
            break
        end
    end
    local e = bag and IV.Judge(bag, slot)
    if not e then return IF.Print("/if junk why <item link or id> (or with the cursor on a bag item)") end
    IF.Print((e.link or e.name) .. ": " .. e.verdict .. " - " .. (e.why or "") .. (e.mark and (" [your mark: " .. e.mark
        .. "]") or ""))
    local GD = IF.GameData
    local starts, related = GD.ItemQuests(e.itemID)
    local log = C_QuestLog
    local function state(q)
        local inLog = log and log.GetLogIndexForQuestID and (log.GetLogIndexForQuestID(q) or 0) > 0
        return (GD.QuestName(q) or "?") .. " (" .. q .. "): " .. (inLog and "in your log" or GD.Completed(q) and "done"
            or GD.QuestOpen(q) and "still to do" or "not for you")
    end
    if starts then IF.Print("  starts " .. state(starts)) end
    for i, q in ipairs(related or {}) do
        if i > 8 then
            IF.Print("  ... " .. (#related - 8) .. " more")
            break
        end
        IF.Print("  for " .. state(q))
    end
    if not starts and not related then IF.Print("  no quest knows it") end
end

IF.AddCommand("junk", function(args, msg)
    if args[1] == "why" then return Why(msg) end
    if args[1] == "forget" then
        IV.ClearMarks()
        IF.Print("every junk mark of this character forgotten.")
        return
    end
    local n = #IV.Bags(function(e) return e.verdict == "junk" end)
    IF.Print(n .. " junk " .. (n == 1 and "item" or "items") .. " in the bags; " .. IV.MarkCount()
        .. " marked by you (/if junk forget: forget them).")
end, "[forget | why <item>]: the junk in the bags, the marks; why an item is (not) junk")

IF.OnLogin(function()
    J.Settings()
    HookBags()
    HookMerchant()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            pcall(TooltipQuest, tooltip, data)
        end)
    end
    IV.OnChange(function()
        J.RefreshBags()
        if AtVendor() then UpdateSellButton() end
    end)
end)
