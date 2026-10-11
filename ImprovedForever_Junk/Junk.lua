-- Junk: what the bags no longer need, by the core's verdict (ImprovedForever's
-- ItemValue.lua: quests in the log or still to start, the recipes of the
-- character's professions, auction prices, the class's armor and weapons,
-- soulbound or not) and the player's own word:
--   the game's junk coin on each junk bag slot (a texture of ours: nothing
--     written in the game's frames);
--   a vendor's Sell All Junk sells it too, after the game's greys (its
--     button lit while there is only ours to sell);
--   an ordinary item a quest needs says so in its tooltip, in orange:
--     "Needed for "Redridge Goulash"";
--   L2 + L3 on a bag item (watched, not taken; rebindable in the Controller
--     tab) marks it junk, or not junk: remembered for the character, by item.
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
-- Selling: with the vendor's Sell All Junk (the game sells its greys, then
-- ours go: what isn't grey), a few at a time
---------------------------------------------------------------------------
local function AtVendor()
    local merchant = _G.MerchantFrame
    return merchant and merchant:IsShown() or false
end

-- A bag the player keeps out of Sell All Junk (its settings menu)
local function Excluded(bag)
    local ok, out = pcall(function()
        if bag == 0 then
            return C_Container.GetBackpackSellJunkDisabled and C_Container.GetBackpackSellJunkDisabled()
        end
        local flag = Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
        return flag and C_Container.GetBagSlotFlag and C_Container.GetBagSlotFlag(bag, flag)
    end)
    return ok and out or false
end

-- Ours to sell: junk a vendor buys, not grey (the game's own), out of the
-- bags it sells from
function J.ToSell()
    return IV.Bags(function(e)
        return e.verdict == "junk" and e.sellable and e.quality > 0 and not Excluded(e.bag)
    end)
end

local selling                  -- { list, i, sold, worth }; nil: not under way
local blocked = false

local function SellNext()
    local s = selling
    if not s then return end
    if not AtVendor() or IF.InCombat() or blocked then
        selling = nil
    else
        local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
        local n = 0
        while s.i <= #s.list and n < SELL_BATCH do
            local e = s.list[s.i]
            s.i = s.i + 1
            local info = SlotInfo(e.bag, e.slot)
            if info and info.itemID == e.itemID and not info.isLocked then
                use(e.bag, e.slot)
                if blocked then break end
                s.sold, s.worth, n = s.sold + 1, s.worth + e.value, n + 1
            end
        end
        if s.i <= #s.list and not blocked then
            C_Timer.After(SELL_PAUSE, SellNext)
            return
        end
        selling = nil
    end
    if blocked and s.sold == 0 then
        IF.Print("the game doesn't let addons sell items here.")
    elseif s.sold > 0 then
        IF.Print("sold " .. s.sold .. (s.sold == 1 and " junk item" or " junk items") .. " for " .. IV.Money(s.worth))
    end
end

function J.SellJunk()
    if selling or IF.InCombat() or not AtVendor() then return end
    local list = J.ToSell()
    if #list == 0 then return end
    blocked = false
    selling = { list = list, i = 1, sold = 0, worth = 0 }
    SellNext()
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

-- Its binding, on the Controller tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "junkmark", label = "Mark Junk", group = "Bags", tab = "controller",
    icon = IF.TEX .. "ic_mod_junk", context = "bags", order = 22,
    tip = "Marks the bag item the cursor is on as junk, or no longer junk: sold with the vendor's Sell All"
        .. " Junk, offered first by the Destroy panel. Remembered for this character. Only while a bag is open;"
        .. " watched, not taken: the button keeps its own action.",
    accepts = B.NotDouble,
    specs = function() return J.Settings().mark and B.One(J.MarkKey()) or {} end,
    set = function(spec)
        J.Settings().mark = spec ~= nil
        if spec then J.SetMarkKey(spec) end
    end,
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
-- Why a bag item has its verdict: the item under the cursor, else the
-- first of an item id or link given
local function Why(msg)
    local bag, slot = J.FocusedSlot()
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
