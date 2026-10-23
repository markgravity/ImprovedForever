-- The auction house window: over the game's own as it opens (the game's
-- window hidden behind it), used with the pad. It is a scene, in
-- Immersion's look (AuctionScene.lua): no frame of its own, in the
-- screen's middle under the header (the auctioneer's), the world dimmed,
-- black bars at the top and bottom (the legend in the bottom one), the HUD
-- faded. Its pages' names in a row along its top, in Morpheus (the right
-- stick up / down moves through them):
-- Buy (this file), Sell (AuctionSellTab.lua), Auctions (AuctionOwned.lua).
-- Buy: three levels of category (the game's own, AuctionCategories): the
-- main ones down the left (the left stick up / down), the second along
-- the top (L1 / R1), the third under it (L2 / R2), "All" first in each.
-- What is listed is a grid of big
-- tiles (the D-pad moves), each with its name, lowest price and tags: how it
-- compares to its usual one (Auction.lua), its upgrade; the picked one's tooltip beside the window, with the
-- versions listed under it (gear with random stats: each one's stats and
-- lowest price). L3 opens the filters (usable only, up to my level,
-- lowest quality, upgrades: marked with the game's green arrow or only
-- them, Upgrades.lua; sort). Beside the list the picked item's screen (a
-- moment after it is picked): its price chart (AuctionChart.lua), and for
-- goods sold by the unit (commodities) a quantity and its cost, for the
-- rest its auctions one by one. Cross goes into it (Cross held buys: a
-- "Hold to Buy" bar, full, letting go buys; the categories' buttons still
-- change them); Circle comes back to the list, and from it closes the
-- auction house. R3 (a click) shows / hides the tooltips (with what is
-- worn in the item's place beside them).
-- With the Immersion module and its "Auction house scene" switch on only
-- (IF.auctionScene, Module.lua); else AuctionBuyClassic.lua's classic look runs instead.
local IF = ImprovedForever
if not IF.auctionScene then return end

local K = IF.ConfigKit
local KC = K.C
local A = IF.Auction
local AH = C_AuctionHouse
local SC = IF.AuctionScene

local BY = {}
IF.AuctionBuy = BY

local W, H = 920, 600                -- the other pages'
local TAB_H = 56                       -- the pages' names along the top, over every page
-- The Buy page: the main categories down the left, what is for sale as a
-- grid of big tiles (name, price, tags) in the middle, the item's screen
-- beside it (under the pages' names: BUY_H is the page's, not the window's)
local COLS, GRID_X, GRID_Y = 4, 150, 156 -- the grid's columns and its tiles' pitch
local GRID_LEFT = 14                   -- (room for the cursor at the first column's left)
local CELL_W, CELL_H = 128, 152
-- Three columns, apart as the first-time tour's: the categories, the grid,
-- the picked item's screen (a preview of it; Cross goes into it)
local RULE_X = 230                     -- the standing gold rule, from the window's left
local SIDE_W = RULE_X - 40             -- the names left of it, right-aligned
local MAIN_X = RULE_X + 40             -- the grid column's left
local MAIN_W = GRID_LEFT + COLS * GRID_X
local PREVIEW_GAP, PREVIEW_W = 30, 340
local PREVIEW_X = MAIN_X + MAIN_W + PREVIEW_GAP
local BUY_W, BUY_H = PREVIEW_X + PREVIEW_W + 16, 612
local CONTENT_TOP = -108
local CONTENT_H = BUY_H - 108 - 36
local GRID_ROWS = math.floor(CONTENT_H / GRID_Y)
local PER = COLS * GRID_ROWS           -- tiles shown
local SIDE_TOP = 70                    -- the main categories (the names' first row)
local SIDE_PITCH = 30
local PREVIEW_AFTER = 0.3          -- resting on an item this long: its screen beside the list
local SIDE_ROWS = 12
local STICK_ON, STICK_OFF = 0.6, 0.3
local REPEAT_DELAY, REPEAT_EVERY, FAST_AFTER = 0.35, 0.1, 1.5
local QUERY_DELAY = 0.3               -- categories moved through quickly: one query at the end
local BUY_TIMEOUT = 10                -- a buy the server hasn't answered by then: given up

local QUALITY_FILTERS = {             -- Enum.AuctionHouseFilter, from poor up
    [0] = 6, [1] = 7, [2] = 8, [3] = 9, [4] = 10, [5] = 11,
}
local QUALITY_NAMES = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary" }

-- A quality's name in its colour
local function QualityName(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, QUALITY_NAMES[q]) or QUALITY_NAMES[q]
end

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local function Glyph(key, size)
    return IF.GlyphText(key, size or 22)
end

local FocusColor = IF.UI.FocusColor

local function S()
    return A.Settings()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local win = IF.UI.Window("ImprovedForeverAuctionBuy", W, H)
-- (in the auction house's place: our side windows sit beside it, as
-- beside the game's panels: ImprovedForever's Focus.lua)
IF.Focus.AlongTop(win)
BY.window = win
local titleText = win.titleText

-- The pages, one at a time, picked with their names along the window's
-- top (the right stick up / down): Buy (this file's), Sell
-- (AuctionSellTab.lua), Auctions (AuctionOwned.lua). A page of another
-- file: BY.AddPage(page), page = { key, label, icon, Build(parent) ->
-- frame, Show(), Hide(), Render(), Press(name, fast) -> handled (Circle
-- unhandled: the auction house closes), Hints() -> the legend's text }.
-- Each is under the names (the other pages' in pageHost, W x H).
local buyPage = K.NewFrame("Frame", nil, win)
buyPage:SetPoint("TOPLEFT", 0, -TAB_H)
buyPage:SetPoint("BOTTOMRIGHT")
local pageHost = K.NewFrame("Frame", nil, win)
pageHost:SetPoint("TOPLEFT", 0, -TAB_H)
pageHost:SetPoint("BOTTOMRIGHT")
BY.tab = "buy"
BY.TABS = { { key = "buy", label = "Buy", icon = "Interface\\Icons\\INV_Misc_Bag_10" } }

function BY.AddPage(page)
    BY.TABS[#BY.TABS + 1] = page
end

---------------------------------------------------------------------------
-- The mouse (IF.Input: the look follows the input used last): no legend,
-- a row of the game's buttons in the window's bottom band instead (a
-- page's MouseHints() -> { { label, fn } }), each list scrolled with the
-- wheel, a row under the mouse its tooltip, the hold boxes held down with
-- the button
---------------------------------------------------------------------------
local function Mouse()
    return not IF.Input.Pad()
end
BY.Mouse = Mouse

-- The wheel over frames: fn(dir), -1 up, 1 down
function BY.Wheel(frames, fn)
    for _, frame in ipairs(frames) do
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta) fn(delta > 0 and -1 or 1) end)
    end
end

-- A row under the mouse: its tooltip (fn(row) sets GameTooltip; false:
-- none), the picked one's back as it leaves
function BY.Hover(row, fn)
    row:HookScript("OnEnter", function(self)
        if not Mouse() then return end
        BY.hover = self
        GameTooltip:SetOwner(BY.window, "ANCHOR_NONE")
        BY.PlaceTip()
        if fn(self) == false then return GameTooltip:Hide() end
        GameTooltip:Show()
        BY.Compare()
    end)
    row:HookScript("OnLeave", function(self)
        if BY.hover ~= self then return end
        BY.hover = nil
        if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
        BY.Render()
    end)
    -- (a modified click: its item's binding, as an item's anywhere else:
    -- Alt + click, the Wiki; Binds.lua)
    row:HookScript("OnClick", function(self, button)
        if not (Mouse() and BY.hover == self) then return end
        local _, link = GameTooltip:GetItem()
        if link then IF.Binds.RunClick(button, { link = link, owner = self }) end
    end)
end

-- A row's tooltip up (the picked one's waits)
function BY.Hovering()
    local row = BY.hover
    return row ~= nil and Mouse() and row:IsVisible() and row:IsMouseOver()
end

-- A small button of the game's (with the mouse): label, fn on a click
function BY.Button(parent, label, fn, width)
    local b = K.NewFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 90, 22)
    b:SetText(label)
    b:SetScript("OnClick", function() fn() end)
    return b
end

-- A ‹ or › over a text arrow, for the mouse: fn(fast) (Shift held: fast)
function BY.ArrowButton(parent, arrow, fn)
    local b = K.NewFrame("Button", nil, parent)
    b:SetSize(32, 36)
    b:SetPoint("CENTER", arrow, "CENTER", 0, 0)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function() fn(IsShiftKeyDown()) end)
    return b
end

-- A number typed with the keyboard (with the mouse), in place of a big
-- one: onSet(n) as it's entered
function BY.NumberBox(parent, width, onSet)
    local e = K.NewFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 70, 30)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetMaxLetters(6)
    e:SetJustifyH("CENTER")
    local function Set(self)
        local n = tonumber(self:GetText())
        if n then onSet(n) end
    end
    e:SetScript("OnEnterPressed", function(self)
        Set(self)
        self:ClearFocus()
    end)
    e:SetScript("OnEditFocusLost", Set)
    e:Hide()
    return e
end

local Panel, FocusStroke = IF.UI.Panel, IF.UI.FocusStroke

-- A badge: a small rounded pill with a short text (a price against its
-- usual one, an upgrade's gain). badge:Set(text, color) (nil: hidden)
local BADGE_COLORS = {
    good = { 0.16, 0.48, 0.18 }, bad = { 0.58, 0.16, 0.1 }, plain = { 0.3, 0.26, 0.19 },
    upgrade = { 0.13, 0.33, 0.58 }, later = { 0.36, 0.22, 0.52 },
}
local function Badge(parent, size)
    local b = K.NewFrame("Frame", nil, parent)
    b:SetHeight((size or 11) + 6)
    b.box = K.Box(b, 4, nil, "ARTWORK")
    b.box:SetPoints(b)
    b.text = K.ChatText(b, size or 11, KC.white, "OVERLAY")
    b.text:SetPoint("CENTER", 0, 0)
    function b:Set(text, color)
        self:SetShown(text ~= nil)
        if not text then return end
        self.text:SetText(text)
        self.box:SetColors(BADGE_COLORS[color] or BADGE_COLORS.plain, 0.95)
        self:SetWidth(self.text:GetStringWidth() + 12)
    end
    b:Hide()
    return b
end

-- The badges' icons (tools/make_badge_icons.py): white, on the pill's colour
local BADGE_PRICE = "|T" .. K.TEX .. "ic_badge_price:0:0:0:0|t "
local BADGE_UP = "|T" .. K.TEX .. "ic_badge_up:0:0:0:0|t "

-- Its price against its usual one, as a badge: the tag and "-23%" (good),
-- "+38%" (dear), "+2%" (about usual); nil: no usual price known
local function DealBadge(itemID, price)
    local usual = A.MarketPrice(itemID)
    if not usual or usual <= 0 or not price or price <= 0 then return nil end
    local pct = math.floor((price / usual - 1) * 100 + 0.5)
    local text = BADGE_PRICE .. (pct > 0 and "+" or "") .. pct .. "%"
    if pct <= -5 then return text, "good" end
    if pct >= 5 then return text, "bad" end
    return text, "plain"
end

-- An upgrade's gain as a badge: the arrow and "+12%" (nothing worn: "New");
-- one of a higher level in purple
local function GainBadge(isUpgrade, gain, needLevel)
    if not isUpgrade then return nil end
    local text = BADGE_UP .. (gain and ("+" .. math.max(1, math.floor(gain + 0.5)) .. "%") or "New")
    return text, needLevel and "later" or "upgrade"
end

---------------------------------------------------------------------------
-- The main categories, down the left
---------------------------------------------------------------------------
-- As the first-time tour's list (Immersion's Onboarding.lua): no panel, a
-- gold rule standing, fading out at both ends, the names right-aligned left
-- of it (the chosen one gold), a small diamond on the rule above them with
-- the chosen one's picture
local SCENE = { gold = SC.GOLD }
do
local RULE_TOP, RULE_BOTTOM = 20, BUY_H - 50
local sideRule = SC.Rule(buyPage, RULE_BOTTOM - RULE_TOP, true)
sideRule:SetPoint("TOP", buyPage, "TOPLEFT", RULE_X, -RULE_TOP)
local sideMark = SC.Diamond(buyPage, 26)
-- (fixed, above the first name, as the tour's: only its picture changes)
sideMark:SetPoint("CENTER", buyPage, "TOPLEFT", RULE_X, -(SIDE_TOP - 30))
sideMark:Hide()
SCENE.mark, SCENE.icon = sideMark, sideMark.icon
end

local side = K.NewFrame("Frame", nil, buyPage)
side:SetPoint("TOPLEFT", 0, -SIDE_TOP + 30)
side:SetSize(SIDE_W, SIDE_ROWS * SIDE_PITCH + 30)
-- Each main category's picture, for the diamond (by its name)
local CATEGORY_ICONS = {
    Weapons = "INV_Sword_04", Armor = "INV_Chest_Chain_03", Containers = "INV_Misc_Bag_08",
    Consumables = "INV_Potion_54", ["Trade Goods"] = "INV_Fabric_Wool_01", Ammo = "INV_Ammo_Arrow_02",
    Recipes = "INV_Misc_Book_09", ["Quest Items"] = "INV_Misc_Note_01", Miscellaneous = "INV_Misc_Gem_Variety_01",
}
local sideRows = {}
for i = 1, SIDE_ROWS do
    local r = K.NewFrame("Button", nil, side)
    r:SetSize(SIDE_W - 12, 28)
    r:SetPoint("TOPRIGHT", -12, -30 - (i - 1) * SIDE_PITCH)
    r.text = SC.Text(r, 16, SC.GREY, SC.BODY)
    r.text:SetAllPoints()
    r.text:SetJustifyH("RIGHT")
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.index then BY.SetMain(self.index) end
    end)
    local hover = r:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", -20, 0)
    hover:SetPoint("BOTTOMRIGHT", 6, 0)
    hover:SetColorTexture(1, 1, 1, 1)
    if not pcall(hover.SetGradient, hover, "HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.08)) then
        hover:SetAlpha(0.05)
    end
    sideRows[i] = r
end

---------------------------------------------------------------------------
-- The second and third levels, along the top: a row of chips each, its
-- bumper / trigger glyphs at the ends, the chosen one lit and kept in view
---------------------------------------------------------------------------
-- (inset: as much off each end, its middle the grid's)
local function TopBar(y, leftKey, rightKey, onClick, inset)
    local bar = SC.Chips(buyPage, leftKey, rightKey, onClick)
    bar:SetPoint("TOPLEFT", MAIN_X + (inset or 0), y)
    bar:SetWidth(MAIN_W - 2 * (inset or 0))
    return bar
end

-- (the second's: room at its right end for the filter and refresh icons)
local bar2 = TopBar(-20, "LB", "RB", function(i) BY.SetSub(i) end, 56)
local bar3 = TopBar(-58, "LT", "RT", function(i) BY.SetSubSub(i) end)

---------------------------------------------------------------------------
-- The content (the list), the legend
---------------------------------------------------------------------------

local content = K.NewFrame("Frame", nil, buyPage)
content:SetPoint("TOPLEFT", MAIN_X, CONTENT_TOP)
content:SetSize(MAIN_W, CONTENT_H)

local emptyText = K.ChatText(content, 13, KC.grey)
emptyText:SetPoint("CENTER")

local function ItemIcon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", t, -1, 1)
    border:SetPoint("BOTTOMRIGHT", t, 1, -1)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    t.border = border
    return t
end

-- A row of items (the browse list's, an item's auctions): the icon (the
-- upgrade arrow on it), the name, a second line (how many, item level) with
-- the badges after it, the price on the right. row:Fill({ icon, quality,
-- name, line, price, upgrade, gain = { text, color }, deal = { text, color } })
local function ItemRow(parent, width, height, nameW)
    local r = K.NewFrame("Button", nil, parent)
    r:SetSize(width, height)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if not Atlas(r.bg, "Looting_ItemCard_BG") then r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
    r.focus = FocusStroke(r)
    r.icon = ItemIcon(r, 34)
    r.icon:SetPoint("LEFT", 6, 0)
    r.upgrade = IF.Upgrades.Arrow(r, "BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -7)
    r.name:SetWidth(nameW)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    -- (its line kept clear of the row's bottom: the badges on it stay inside the ring)
    r.qty = K.ChatText(r, 11, KC.help)
    r.qty:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 50, 10)
    r.price = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.price:SetPoint("TOPRIGHT", -12, -7)
    r.gain = Badge(r, 11)
    r.deal = Badge(r, 11)
    function r:Fill(o)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.quality or 1]
        self.icon:SetTexture(o.icon or 134400)
        self.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
        self.name:SetText(o.name or "...")
        self.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
        self.price:SetText(o.price or "")
        -- (the name: all the room up to the price, however wide the row)
        local priceW = (o.price and o.price ~= "") and (self.price:GetStringWidth() + 8) or 0
        self.name:SetWidth(math.max(40, self:GetWidth() - 50 - 12 - priceW))
        self.upgrade:SetShown(o.upgrade and true or false)
        self.gain:Set(o.gain and o.gain[1], o.gain and o.gain[2])
        self.deal:Set(o.deal and o.deal[1], o.deal and o.deal[2])
        -- The badges after the second line's text (upgrade, price)
        self.qty:SetText(o.line or "")
        local x = (o.line and o.line ~= "") and (self.qty:GetStringWidth() + 8) or 0
        for _, badge in ipairs({ self.gain, self.deal }) do
            if badge:IsShown() then
                badge:ClearAllPoints()
                badge:SetPoint("LEFT", self.qty, "LEFT", x, 0)
                x = x + badge:GetWidth() + 6
            end
        end
    end
    return r
end

-- One tile of the grid, the scene's own: no card, no frame, nothing behind
-- it but the dimmed world. The item's icon in the spell diamonds' ring
-- (Immersion's gamepad bar) turned upright to a square, cut to its rounded
-- opening, on a soft shadow; its name
-- under it in its quality's colour; its lowest price under that in
-- Morpheus (the coins' pictures); then what sets it apart on a small
-- capsule of its colour: an upgrade and its gain, else how far from its
-- usual price. How many are up in small at the icon's corner, the game's
-- upgrade arrow at the other. The one the pad is on: its icon grows and a
-- soft gold light comes up behind it, the game's cursor at its left
-- (Focus.lua); the others step back a little.
-- cell:Fill({ icon, quality, name, itemID, price, count, upgrade, gain,
-- needLevel }), cell:Lit(on, dim) (dim: picked, the pad elsewhere)
local GridCell
do
    local ICON, GROW, HOVER, EASE = 54, 1.2, 1.07, 0.1
    local STEP_BACK = 0.78                 -- (the others' alpha while one is lit)
    -- (the gamepad bar's square slot ring, its opening about 0.88 of it
    -- across: a little over the icon's edge, hugging it)
    local RING, RING_SCALE = "gamepad-actionbar-squareslot-border-normal", 1.12
    local GOLD = SC.GOLD
    local COINS = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon",
        "Interface\\MoneyFrame\\UI-CopperIcon" }
    -- (soft, as the header's lines: the price cream, the tags muted)
    local PRICE = { 1, 0.94, 0.82 }
    local CHEAP, DEAR = { 0.55, 0.85, 0.55 }, { 0.92, 0.55, 0.5 }
    local UPGRADE, LATER = { 0.5, 0.75, 1 }, { 0.78, 0.62, 1 }

    -- A price in short: its two largest coins (from 100 gold, the gold alone)
    local function Price(copper)
        local coins = { math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }
        local parts = {}
        for i, n in ipairs(coins) do
            if n > 0 or (i == 3 and #parts == 0) then
                parts[#parts + 1] = n .. "|T" .. COINS[i] .. ":13:13:2:0|t"
                if #parts == 2 or (i == 1 and n >= 100) then break end
            elseif #parts > 0 then
                break
            end
        end
        return table.concat(parts, " ")
    end

    -- A soft round light (or shadow): circles one in another, each faint,
    -- so it is brightest in its middle and fades to nothing at its edge.
    -- light:SetLight(r, g, b, a), light:SetSize(n)
    local RINGS = 7
    local function Soft(parent, layer, sublevel)
        local light = { parts = {} }
        for i = 1, RINGS do
            local t = parent:CreateTexture(nil, layer, nil, sublevel)
            t:SetTexture(K.TEX .. "ic_dot")
            light.parts[i] = t
        end
        function light:SetPoint(...)
            for _, t in ipairs(self.parts) do t:SetPoint(...) end
        end
        function light:SetSize(n)
            for i, t in ipairs(self.parts) do t:SetSize(n * i / RINGS, n * i / RINGS) end
        end
        function light:SetLight(r, g, b, a)
            for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a / RINGS) end
        end
        return light
    end

    -- What sets it apart, a word or two and its colour: its upgrade and the
    -- gain (one of a higher level: for later), else how far from its usual
    -- price (about usual: nothing)
    local function Words(o)
        if o.upgrade then
            local gain = o.gain and ("+" .. math.max(1, math.floor(o.gain + 0.5)) .. "%") or "new"
            return "UPGRADE " .. gain .. (o.needLevel and " LATER" or ""), o.needLevel and LATER or UPGRADE
        end
        local usual = o.itemID and A.MarketPrice(o.itemID)
        local pct = usual and usual > 0 and o.price and o.price > 0
            and math.floor((o.price / usual - 1) * 100 + 0.5) or nil
        if pct and pct <= -5 then return -pct .. "% BELOW USUAL", CHEAP end
        if pct and pct >= 5 then return pct .. "% ABOVE USUAL", DEAR end
    end

    function GridCell(parent)
        local cell = K.NewFrame("Button", nil, parent)
        cell:SetSize(CELL_W, CELL_H)
        -- (all of it in the body: its alpha steps back, the cell's own fades in)
        local body = K.NewFrame("Frame", nil, cell)
        body:SetAllPoints()
        cell.body = body
        cell.light = Soft(body, "BACKGROUND", 0)
        cell.light:SetPoint("CENTER", cell, "TOP", 0, -42)
        cell.shadow = Soft(body, "BACKGROUND", 1)
        cell.shadow:SetPoint("CENTER", cell, "TOP", 0, -46)
        cell.shadow:SetLight(0, 0, 0, 0.7)
        cell.icon = body:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("CENTER", cell, "TOP", 0, -42)
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        -- (cut to the ring's rounded opening, the gamepad bar's square mask)
        cell.mask = body:CreateMaskTexture()
        cell.mask:SetAtlas("SquareMask")
        cell.mask:SetPoint("CENTER", cell.icon, "CENTER")
        cell.icon:AddMaskTexture(cell.mask)
        cell.ring = body:CreateTexture(nil, "OVERLAY", nil, -1)
        cell.ring:SetPoint("CENTER", cell.icon, "CENTER")
        if not Atlas(cell.ring, RING) then cell.ring:Hide() end
        cell.upgrade = IF.Upgrades.Arrow(body, "TOPLEFT", cell.icon, "TOPLEFT", -6, 6)
        cell.count = body:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        cell.count:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", 6, -4)
        cell.name = SC.Text(body, 12, nil, SC.BODY)
        cell.name:SetPoint("TOP", cell, "TOP", 0, -80)
        cell.name:SetSize(CELL_W - 8, 28)
        cell.name:SetWordWrap(true)
        cell.name:SetJustifyV("TOP")
        cell.price = SC.Text(body, 17, PRICE)
        cell.price:SetPoint("TOP", cell, "TOP", 0, -108)
        -- (the tag: small capitals on a capsule of its colour, its round ends
        -- the halves of a disc)
        cell.badge = K.NewFrame("Frame", nil, body)
        cell.badge:SetHeight(16)
        cell.badge:SetPoint("TOP", cell.price, "BOTTOM", 0, -5)
        cell.badge.parts = {}
        for i, coords in ipairs({ { 0, 0.5 }, false, { 0.5, 1 } }) do
            local t = cell.badge:CreateTexture(nil, "BACKGROUND")
            if coords then
                t:SetTexture(K.TEX .. "ic_dot")
                t:SetTexCoord(coords[1], coords[2], 0, 1)
                t:SetSize(8, 16)
                t:SetPoint(i == 1 and "LEFT" or "RIGHT")
            else
                t:SetColorTexture(1, 1, 1, 1)
                t:SetPoint("TOPLEFT", 8, 0)
                t:SetPoint("BOTTOMRIGHT", -8, 0)
            end
            cell.badge.parts[i] = t
        end
        cell.tag = SC.Text(cell.badge, 9, nil, SC.BODY)
        cell.tag:SetPoint("CENTER", 0, 0)

        -- The icon's size, its light and the step back, eased toward where
        -- they're going (lit, hovered, neither)
        cell.size, cell.goal, cell.alpha, cell.alphaGoal = 1, 1, 1, 1
        local function Apply(self)
            local n = ICON * self.size
            self.icon:SetSize(n, n)
            self.mask:SetSize(n, n)
            self.ring:SetSize(n * RING_SCALE, n * RING_SCALE)
            self.shadow:SetSize(n * 1.9)
            local glow = math.max(0, (self.size - 1) / (GROW - 1))
            self.light:SetSize(n * 2.6)
            self.light:SetLight(GOLD[1], GOLD[2], GOLD[3], 0.55 * glow)
            body:SetAlpha(self.alpha)
        end
        Apply(cell)
        cell:SetScript("OnUpdate", function(self, dt)
            if self.size == self.goal and self.alpha == self.alphaGoal then return end
            local k = math.min(1, dt / EASE)
            self.size = self.size + (self.goal - self.size) * k
            self.alpha = self.alpha + (self.alphaGoal - self.alpha) * k
            if math.abs(self.goal - self.size) < 0.003 then self.size = self.goal end
            if math.abs(self.alphaGoal - self.alpha) < 0.01 then self.alpha = self.alphaGoal end
            Apply(self)
        end)
        local function Goal(self)
            self.goal = self.lit and (self.dim and HOVER or GROW) or (self.hovered and HOVER or 1)
            self.alphaGoal = (self.lit or self.hovered or not self.others) and 1 or STEP_BACK
        end
        cell:SetScript("OnEnter", function(self)
            self.hovered = Mouse()
            Goal(self)
        end)
        cell:SetScript("OnLeave", function(self)
            self.hovered = false
            Goal(self)
        end)

        function cell:Fill(o)
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.quality or 1]
            local r, g, b = c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6
            self.icon:SetTexture(o.icon or 134400)
            self.upgrade:SetShown(o.upgrade and true or false)
            local n = o.count or 0
            self.count:SetText(n > 1 and (n >= 1000 and (math.floor(n / 100) / 10 .. "k") or n) or "")
            self.name:SetText(o.name or "...")
            -- (poor and common names in a light grey: their own is too dark to read)
            if (o.quality or 1) <= 1 then self.name:SetTextColor(0.9, 0.9, 0.9) else self.name:SetTextColor(r, g, b) end
            self.price:SetText(o.price and o.price > 0 and Price(o.price) or "bid only")
            local word, color = Words(o)
            self.badge:SetShown(word ~= nil)
            if word then
                self.tag:SetText(word)
                self.tag:SetTextColor(color[1], color[2], color[3])
                for _, t in ipairs(self.badge.parts) do t:SetVertexColor(color[1] * 0.35, color[2] * 0.35, color[3] * 0.35, 0.75) end
                self.badge:SetWidth(self.tag:GetStringWidth() + 16)
            end
        end

        -- on: the one picked; dim: picked, the pad elsewhere (the filters
        -- open); others: one of the grid is lit, this one steps back
        function cell:Lit(on, dim, others)
            self.lit, self.dim, self.others = on, dim, others
            Goal(self)
            local cursorOn = on and not dim and IF.Input.Pad()
            if cursorOn and not self.cursor then self.cursor = IF.Focus.Cursor(body) end
            if self.cursor then
                if cursorOn then self.cursor:Point(self.icon) else self.cursor:Hide() end
            end
        end
        return cell
    end
end

-- The browse results, as a grid: COLS across, GRID_ROWS down (the pick
-- kept in view; BY.top is the first shown, always the start of a row)
local listRows = {}
for i = 1, PER do
    local r = GridCell(content)
    -- (the grid centred in its column, under the pages' names)
    r:SetPoint("TOPLEFT", (MAIN_W - (COLS - 1) * GRID_X - CELL_W) / 2 + ((i - 1) % COLS) * GRID_X,
        -math.floor((i - 1) / COLS) * GRID_Y - 4)
    r:SetScript("OnClick", function(self)
        if self.index then
            BY.index = self.index
            BY.Render()
        end
    end)
    listRows[i] = r
end

-- (in the bottom bar: AuctionScene.lua)
local legend = SC.Legend()

---------------------------------------------------------------------------
-- The filters (L3): a dropdown as Improved Quest Tracker's (styled as the
-- game's own Menu: its background, titles, radio and check ticks,
-- dividers, the buttons along its bottom), at the content's top right. The
-- D-pad moves, Cross picks, Circle / L3 close (searching again if changed).
---------------------------------------------------------------------------
local DD_ROW, DD_INSET, DD_PAD = 20, { left = 8, top = 8, right = 8, bottom = 15 }, 20

local function Radio(text, key, value)
    return { kind = "radio", text = text,
        isSelected = function() return S()[key] == value end,
        onSelect = function() S()[key] = value end }
end
local function Check(text, key)
    return { kind = "checkbox", text = text,
        isSelected = function() return S()[key] end,
        onSelect = function() S()[key] = not S()[key] end }
end

local ENTRIES = {
    { kind = "title", text = "Filters" },
    Check("Usable only", "buyUsable"),
    Check("Up to my level", "buyMyLevel"),
    { kind = "divider" },
    { kind = "title", text = "Quality |cff9d917a(none ticked: any)|r" },
}
-- (any number ticked; none: any quality)
for q = 0, 5 do
    ENTRIES[#ENTRIES + 1] = { kind = "checkbox", text = QualityName(q),
        isSelected = function() return S().buyQualities[q] end,
        onSelect = function() S().buyQualities[q] = not S().buyQualities[q] or nil end }
end
for _, e in ipairs({
    { kind = "divider" },
    { kind = "title", text = "Upgrades" },
    Radio("Don't show", "buyUpgrades", "off"),
    Radio("Mark with an arrow", "buyUpgrades", "mark"),
    Radio("Upgrades only", "buyUpgrades", "only"),
    { kind = "divider" },
    { kind = "title", text = "Sort" },
    Radio("Price, lowest first", "buySort", "price"),
    Radio("Name", "buySort", "name"),
}) do ENTRIES[#ENTRIES + 1] = e end

local function Selectable(entry)
    return entry and (entry.kind == "radio" or entry.kind == "checkbox")
end

local filterBox = K.NewFrame("Frame", nil, buyPage)
filterBox:SetFrameLevel(win:GetFrameLevel() + 30)
-- Two icons at the right end of the second categories' row: the game's
-- filter icon (the menu under it) and refresh (what is listed looked up
-- again, in place, then the open item's auctions); grey, cream under the
-- mouse, the filters' gold while open (Render)
local function IconButton(atlases, tip, fn, lit)
    local b = K.NewFrame("Button", nil, buyPage)
    b:SetSize(24, 26)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(18, 18)
    for _, name in ipairs(atlases) do
        if Atlas(b.icon, name) then break end
    end
    b:SetScript("OnClick", fn)
    function b:Tint(hover)
        local c = (lit and lit()) and SC.GOLD or hover and SC.CREAM or SC.GREY
        self.icon:SetVertexColor(c[1], c[2], c[3])
    end
    b:SetScript("OnEnter", function(self)
        self:Tint(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:Tint(false)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    b:Tint(false)
    return b
end
local filterWord = IconButton({ "gamepad-hud-icon-filter", "UI-QuestTrackerButton-Filter" }, "Filters",
    function() BY.Press("LS") end, function() return filterBox:IsShown() end)
filterWord:SetPoint("LEFT", bar2, "RIGHT", 4, 0)
filterWord.refresh = IconButton({ "UI-RefreshButton", "common-icon-rotateright" }, "Refresh",
    function() BY.Refresh() end)
filterWord.refresh:SetPoint("LEFT", filterWord, "RIGHT", 2, 0)
filterBox:SetPoint("TOPRIGHT", filterWord, "BOTTOMRIGHT", 0, -6)
filterBox:EnableMouse(true)
filterBox:Hide()
do
    local bg = filterBox:CreateTexture(nil, "BACKGROUND", nil, -8)
    if not Atlas(bg, "common-dropdown-bg") then bg:SetColorTexture(0.05, 0.04, 0.03, 0.95) end
    bg:SetPoint("TOPLEFT", -10, 3)
    bg:SetPoint("BOTTOMRIGHT", 10, -3)
    bg:SetAlpha(0.925)
end
local ddHint = filterBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
ddHint:SetPoint("BOTTOMLEFT", DD_INSET.left, 6)
ddHint:SetJustifyH("LEFT")

local ddRows = {}
do
    local width, height, previous = 0, DD_INSET.top, nil
    for i, entry in ipairs(ENTRIES) do
        local row = K.NewFrame("Button", nil, filterBox)
        row.index, row.entry = i, entry
        if entry.kind == "divider" then
            row:SetHeight(13)
            local divider = row:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("LEFT")
            divider:SetPoint("RIGHT")
            divider:SetHeight(13)
            divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
        else
            row:SetHeight(DD_ROW)
        end
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetBlendMode("ADD")
        row.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.highlight:Hide()
        local text = row:CreateFontString(nil, "ARTWORK", entry.kind == "title" and "GameFontNormal" or "GameFontHighlight")
        text:SetHeight(DD_ROW)
        text:SetJustifyH("LEFT")
        text:SetText(entry.text or "")
        local contentWidth = text:GetStringWidth()
        if entry.kind == "radio" or entry.kind == "checkbox" then
            local radio = entry.kind == "radio"
            local tick = row:CreateTexture(nil, "ARTWORK")
            if not Atlas(tick, radio and "common-dropdown-tickradial" or "common-dropdown-ticksquare") then
                tick:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            end
            tick:SetSize(16, 16)
            tick:SetPoint("LEFT", radio and -3 or 0, 0)
            row.check = row:CreateTexture(nil, "OVERLAY")
            if not Atlas(row.check, radio and "common-dropdown-icon-radialtick-yellow" or "common-dropdown-icon-checkmark-yellow") then
                row.check:SetColorTexture(1, 0.82, 0, 1)
            end
            row.check:SetSize(radio and 16 or 14, radio and 16 or 14)
            if radio then
                row.check:SetPoint("TOPLEFT", tick, "TOPLEFT")
            else
                row.check:SetPoint("CENTER", tick, "CENTER", 2, 1)
            end
            text:SetPoint("LEFT", tick, "RIGHT", radio and 1 or 7, radio and 0 or 1)
            contentWidth = contentWidth + 16 + 7
            row:SetScript("OnClick", function(self)
                BY.filterRow = self.index
                BY.PickFilter()
            end)
        else
            text:SetPoint("LEFT")
            row:EnableMouse(false)
        end
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
        else
            row:SetPoint("TOPLEFT", DD_INSET.left, -DD_INSET.top)
        end
        row:SetPoint("RIGHT", -DD_INSET.right, 0)
        width = math.max(width, contentWidth)
        height = height + row:GetHeight()
        ddRows[i] = row
        previous = row
    end
    filterBox.baseWidth = width + DD_PAD + DD_INSET.left + DD_INSET.right
    filterBox.baseHeight = height + DD_INSET.bottom + 16
end

-- The next selectable entry up / down from the focused one (wrapping)
local function MoveFilterFocus(step)
    local n = #ENTRIES
    local i = BY.filterRow or 0
    for _ = 1, n do
        i = i + step
        if i < 1 then i = n elseif i > n then i = 1 end
        if Selectable(ENTRIES[i]) then
            BY.filterRow = i
            return
        end
    end
end

---------------------------------------------------------------------------
-- The item (Cross): a box over the content: chart, then buying
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Hold to act (buying, selling, cancelling: no popups): a button held
-- fills a bar; full, letting go does it (these want a hardware event: the
-- release is one, a timer isn't). The box: the game's footer box, the
-- button and "Hold to <verb>", the bar filling; the rumble with it
---------------------------------------------------------------------------
BY.HOLD_TIME = 1.2

function BY.HoldProgress(start)
    if not start then return 0 end
    return math.min(1, (GetTime() - start) / BY.HOLD_TIME)
end

-- A gold bar over a frame from its left, as far as the hold has come
function BY.HoldFill(frame, inset)
    local fill = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    inset = inset or 3
    fill:SetPoint("TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMLEFT", inset, inset)
    fill:SetWidth(1)
    fill:Hide()
    function fill:SetProgress(p)
        self:SetShown(p > 0)
        self:SetWidth(math.max(1, (frame:GetWidth() - 2 * inset) * p))
        self:SetColorTexture(1, 0.82, 0, p >= 1 and 0.6 or 0.35)
    end
    return fill
end

function BY.HoldBox(parent)
    local hold = K.NewFrame("Frame", nil, parent)
    hold:SetHeight(34)
    hold.bg = hold:CreateTexture(nil, "BACKGROUND")
    hold.bg:SetAllPoints()
    if not Atlas(hold.bg, "gamepad-footer-slot-bg") then hold.bg:SetColorTexture(0.05, 0.04, 0.03, 0.92) end
    hold.fill = BY.HoldFill(hold)
    hold.border = hold:CreateTexture(nil, "BORDER")
    hold.border:SetAllPoints()
    Atlas(hold.border, "gamepad-footer-slot-frameneutral")
    -- (the game's hold button: the glyph in its ring, "Hold to ...")
    hold.icon = IF.HoldIcon(hold, 22)
    hold.text = hold:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hold.text:SetPoint("LEFT", hold.icon, "RIGHT", 4, 0)
    -- (the mouse: held down on it as the pad's button, hold.onDown /
    -- hold.onUp; lit under it)
    hold:EnableMouse(true)
    hold.lit = hold:CreateTexture(nil, "HIGHLIGHT")
    hold.lit:SetAllPoints()
    hold.lit:SetColorTexture(1, 0.9, 0.6, 0.08)
    hold:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.onDown then self.onDown() end
    end)
    hold:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.onUp then self.onUp() end
    end)
    -- p: 0 to 1; key: the button's glyph key; verb: "Buy"...; extra
    -- (optional): after it ("· 1 silver": what it costs)
    function hold:SetHold(p, key, verb, extra)
        local full = p >= 1
        self.fill:SetProgress(p)
        self.icon:SetKey(key)
        self.icon:SetProgress(p)
        -- (with the mouse no glyph: the box itself is held)
        local pad = IF.Input.Pad()
        self.icon:SetShown(pad)
        self.text:SetText((full and "Release to " or "Hold to ") .. verb
            .. (extra and ("  |cffd8ccb0·|r  " .. extra) or ""))
        -- (the icon and the words centred together)
        local iconW = pad and (self.icon:GetWidth() + 4) or 0
        local w = iconW + self.text:GetStringWidth()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("LEFT", self, "CENTER", -w / 2, 0)
        self.text:ClearAllPoints()
        self.text:SetPoint("LEFT", self, "CENTER", -w / 2 + iconW, 0)
        self.text:SetTextColor(1, full and 1 or 0.82, full and 0.6 or 0)
    end
    return hold
end

local holdVibing, holdWasFull = false, false

-- A hold done (let go full: the action made): the confirm thump, the
-- hold's rumble let go without stopping it
function BY.HoldDone()
    holdVibing, holdWasFull = false, false
    if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
end

-- The feel of a hold, every update: the rumble rising with it (Vibration.lua),
-- a click once full; nil: none under way (still)
function BY.HoldFeel(p)
    if p then
        local full = p >= 1
        if full and not holdWasFull then PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) end
        holdWasFull = full
        if IF.Vibe then IF.Vibe.Hold(p) end
        holdVibing = true
    elseif holdVibing then
        if IF.Vibe then IF.Vibe.Hold(nil) end
        holdVibing, holdWasFull = false, false
    end
end

-- The item's screen, in the scene's look (no panel behind it): its icon
-- in the square ring at the top, its name in Morpheus under it, how many
-- are for sale; under a gold rule the lowest price now and the usual one,
-- the price chart (AuctionChart.lua); then the quantity (commodities) or
-- the auctions one by one (items), the picked one in a soft gold light;
-- "Hold to Buy" and what it costs along the bottom. Every part spans the
-- screen, so it fits any width (the Buy tab's column, the Tasks tab's).
-- Its parts in V.
local detail = K.NewFrame("Frame", nil, buyPage)
detail:SetFrameLevel(win:GetFrameLevel() + 20)
detail:SetAllPoints(content)
detail:Hide()

local V = {}
local AUCTION_ROWS, AUCTION_H = 8, 46     -- (made; as many shown as fit)
local D, DetailPress, HoldPrice
do
    V.icon = SC.RingIcon(detail, 50)
    V.icon:SetPoint("TOP", 0, -10)
    V.upgrade = IF.Upgrades.Arrow(detail, "TOPLEFT", V.icon, "TOPLEFT", -6, 6)
    V.name = SC.Text(detail, 20)
    V.name:SetPoint("TOP", V.icon, "BOTTOM", 0, -12)
    V.name:SetPoint("LEFT", 10, 0)
    V.name:SetPoint("RIGHT", -10, 0)
    V.name:SetWordWrap(true)
    V.name:SetJustifyH("CENTER")
    V.sub = SC.Text(detail, 11, SC.GREY, SC.BODY)
    V.sub:SetPoint("TOP", V.name, "BOTTOM", 0, -4)
    V.rule = SC.Rule(detail, 300, false, 0.6)
    V.rule:SetPoint("TOP", V.sub, "BOTTOM", 0, -10)

    -- The lowest price now and the usual one, side by side: a small grey
    -- label over each, the price in Morpheus
    local function Price()
        local label = SC.Text(detail, 9, SC.GREY, SC.BODY)
        label:SetPoint("TOP", V.rule, "BOTTOM", 0, -10)
        local value = SC.Text(detail, 17, { 1, 0.94, 0.82 })
        value:SetPoint("TOP", label, "BOTTOM", 0, -3)
        return label, value
    end
    V.lowLabel, V.low = Price()
    V.usualLabel, V.usual = Price()
    V.lowLabel:SetText("LOWEST NOW")
    V.usualLabel:SetText("USUALLY")
    -- (each in the middle of its half: RenderDetail, as wide as the screen
    -- is; how far the lowest is from the usual under it)
    V.deal = SC.Capsule(detail)
    V.deal:SetPoint("TOP", V.low, "BOTTOM", 0, -4)

    V.chart = IF.AuctionChart.New(detail, "Pay")
    -- (bare, as the rest: no box round it)
    V.chart:SetBackdropColor(0, 0, 0, 0)
    V.chart:SetBackdropBorderColor(0, 0, 0, 0)
    V.chart:SetPoint("TOP", V.low, "BOTTOM", 0, -24)
    V.chart:SetPoint("LEFT", 4, 0)
    V.chart:SetPoint("RIGHT", -4, 0)
    V.chart:SetHeight(110)

    -- The auctions: a row each, nothing behind it but a faint rule under
    -- it; its icon in the ring, its own name (a random suffix's "of the
    -- Owl"), its item level and stack under it, its price on the right,
    -- what sets it apart on a capsule under that. The picked one in a soft
    -- gold light, the game's cursor at its left while the screen has the pad
    V.rows = {}
    for i = 1, AUCTION_ROWS do
        local r = K.NewFrame("Button", nil, detail)
        r:SetHeight(AUCTION_H - 4)
        r.band = SC.Band(r)
        r.icon = SC.RingIcon(r, 28)
        r.icon:SetPoint("LEFT", 12, 0)
        r.upgrade = IF.Upgrades.Arrow(r, "TOPLEFT", r.icon, "TOPLEFT", -5, 5)
        r.price = SC.Text(r, 15, { 1, 0.94, 0.82 })
        r.price:SetPoint("TOPRIGHT", -10, -6)
        r.name = SC.Text(r, 12, nil, SC.BODY)
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, 1)
        r.name:SetPoint("RIGHT", r.price, "LEFT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.line = SC.Text(r, 10, SC.GREY, SC.BODY)
        r.line:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, -1)
        r.tag = SC.Capsule(r, 14, 8)
        r.tag:SetPoint("BOTTOMRIGHT", -10, 4)
        r.rule = SC.Rule(r, 300, false, 0.15)
        r.rule:SetPoint("TOP", r, "BOTTOM", 0, -2)
        local hover = r:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.04)
        -- on: the picked one; active: the screen has the pad
        function r:Lit(on, active)
            self.band:SetLight(on and (active and 0.18 or 0.08) or 0)
            local cursorOn = on and active and IF.Input.Pad()
            if cursorOn and not self.cursor then self.cursor = IF.Focus.Cursor(self) end
            if self.cursor then
                if cursorOn then self.cursor:Point(self) else self.cursor:Hide() end
            end
        end
        V.rows[i] = r
    end
    -- More auctions above / below those shown: small grey words over the
    -- first row / under the last
    V.moreUp = SC.Text(detail, 10, SC.GREY, SC.BODY)
    V.moreDown = SC.Text(detail, 10, SC.GREY, SC.BODY)

    -- A commodity's quantity: big in Morpheus, centred between the chart
    -- and the hold line, gold arrows either side; its steps in the legend
    V.qtyMid = K.NewFrame("Frame", nil, detail)
    V.qtyMid:SetPoint("TOP", V.chart, "BOTTOM", 0, -6)
    V.qtyMid:SetPoint("LEFT")
    V.qtyMid:SetPoint("RIGHT")
    V.qtyGroup = K.NewFrame("Frame", nil, V.qtyMid)
    V.qtyGroup:SetPoint("LEFT")
    V.qtyGroup:SetPoint("RIGHT")
    V.qtyGroup:SetHeight(40)
    V.qtyGroup:SetPoint("CENTER")
    V.qty = SC.Text(V.qtyGroup, 32, { 1, 0.94, 0.82 })
    V.qty:SetPoint("TOP", 0, 0)
    V.qtyLeft = SC.Text(V.qtyGroup, 30, SC.GOLD)
    V.qtyLeft:SetPoint("RIGHT", V.qty, "LEFT", -16, 0)
    V.qtyLeft:SetText("‹")
    V.qtyRight = SC.Text(V.qtyGroup, 30, SC.GOLD)
    V.qtyRight:SetPoint("LEFT", V.qty, "RIGHT", 16, 0)
    V.qtyRight:SetText("›")
    V.qtyLabel = SC.Text(V.qtyGroup, 11, SC.GREY, SC.BODY)
    V.qtyLabel:SetPoint("TOP", V.qty, "BOTTOM", 0, -6)

    V.hold = SC.HoldLine(detail)
    V.hold:SetPoint("BOTTOMLEFT", 10, 10)
    V.hold:SetPoint("BOTTOMRIGHT", -10, 10)
    V.status = SC.Text(detail, 12, { 1, 0.72, 0.45 }, SC.BODY)
    V.status:SetPoint("BOTTOM", V.hold, "TOP", 0, 8)
    V.status:SetPoint("LEFT", 10, 0)
    V.status:SetPoint("RIGHT", -10, 0)
    V.status:SetWordWrap(true)
    V.qtyMid:SetPoint("BOTTOM", V.hold, "TOP", 0, 24)

    -- With the mouse: the arrows clicked, the quantity typed, the auctions
    -- looked up again with the refresh icon over the grid (BY.Refresh)
    V.qtyEdit = BY.NumberBox(V.qtyGroup, 80, function(n)
        if not D then return end
        local avail = 0
        for _, l in ipairs(D.listings or {}) do avail = avail + l.count - (l.own or 0) end
        D.qty = math.max(1, math.min(math.max(1, avail), n))
        D.state, D.quote, D.message = nil, nil, nil
        BY.Render()
    end)
    V.qtyEdit:SetPoint("CENTER", V.qty, "CENTER", 0, 0)
    V.qtyLeftButton = BY.ArrowButton(V.qtyGroup, V.qtyLeft, function(fast) DetailPress("LEFT", fast) end)
    V.qtyRightButton = BY.ArrowButton(V.qtyGroup, V.qtyRight, function(fast) DetailPress("RIGHT", fast) end)
end

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
BY.main, BY.sub, BY.subsub = 1, 1, 1   -- 1 in the top bars: "All"
BY.index, BY.top = 1, 1
BY.results = {}

local function Mains()
    local list = {}
    for _, cat in ipairs(_G.AuctionCategories or {}) do
        -- (the WoW Token has its own window)
        if not (cat.HasFlag and cat:HasFlag("WOW_TOKEN_FLAG")) then list[#list + 1] = cat end
    end
    return list
end

local function Subs(cat)
    return cat and cat.subCategories or {}
end

-- The chosen categories, deepest last
local function Chosen()
    local main = Mains()[BY.main]
    local sub = BY.sub > 1 and Subs(main)[BY.sub - 1] or nil
    local subsub = sub and BY.subsub > 1 and Subs(sub)[BY.subsub - 1] or nil
    return main, sub, subsub
end

local function Names(cat)
    local names = { "All" }
    for _, c in ipairs(Subs(cat)) do names[#names + 1] = c.name end
    return names
end

---------------------------------------------------------------------------
-- Browsing
---------------------------------------------------------------------------
local queryToken = 0

local function SendQuery()
    if not A.IsOpen() then return end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
        BY.queryWaiting = true
        return
    end
    BY.queryWaiting = false
    local main, sub, subsub = Chosen()
    local cat = subsub or sub or main
    local filters = {}
    if cat and cat.implicitFilter then filters[#filters + 1] = cat.implicitFilter end
    local s = S()
    if s.buyUsable then filters[#filters + 1] = Enum.AuctionHouseFilter.UsableOnly end
    for q = 0, 5 do
        if s.buyQualities[q] then filters[#filters + 1] = QUALITY_FILTERS[q] end
    end
    local sorts = s.buySort == "name"
        and { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
            { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
        or { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
            { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
    AH.SendBrowseQuery({
        searchString = BY.search or "", sorts = sorts, filters = filters,
        itemClassFilters = cat and cat.filters or nil,
        minLevel = 0, maxLevel = s.buyMyLevel and UnitLevel("player") or 0,
    })
    A.lastQuery = "browse"
    BY.searching = true
    BY.Render()
end

-- After the categories settle; keep: the same list again (after buying), its place kept
function BY.Query(keep)
    if not keep then BY.results, BY.allResults, BY.index, BY.top = {}, {}, 1, 1 end
    -- (a new list: its tiles fade in as it comes)
    BY.freshList = not keep
    BY.searching = true
    queryToken = queryToken + 1
    local token = queryToken
    C_Timer.After(QUERY_DELAY, function()
        if token == queryToken and win:IsShown() then SendQuery() end
    end)
    BY.Render()
end

function BY.SetMain(i)
    local n = #Mains()
    if n == 0 then return end
    BY.main = (i - 1) % n + 1
    BY.sub, BY.subsub = 1, 1
    BY.detailFocus = false
    BY.Query()
end

function BY.SetSub(i)
    local names = Names((Chosen()))
    BY.sub = (i - 1) % #names + 1
    BY.subsub = 1
    BY.Query()
end

function BY.SetSubSub(i)
    local _, sub = Chosen()
    local names = Names(sub)
    if #names <= 1 then return end
    BY.subsub = (i - 1) % #names + 1
    BY.Query()
end

-- What is shown of what came: with "Upgrades only", the upgrades (those
-- not known yet join as their data come)
function BY.FilterResults()
    local all = BY.allResults or {}
    if S().buyUpgrades ~= "only" then
        BY.results = all
        return
    end
    local list = {}
    for _, result in ipairs(all) do
        if BY.GroupUpgrade(result.itemKey) then list[#list + 1] = result end
    end
    BY.results = list
end

-- A new list come: its tiles fade in one after another, along the rows
local function PlayTiles()
    for i, r in ipairs(listRows) do
        -- (each over a quarter second, the next a moment after)
        if r:IsShown() then SC.FadeIn(r, 0.25, (i - 1) * 0.025) end
    end
end

local function ResultsIn()
    BY.allResults = AH.GetBrowseResults() or {}
    BY.FilterResults()
    BY.searching = false
    -- Only upgrades, and few among what came: the rest asked for
    if S().buyUpgrades == "only" and #BY.results < PER and AH.HasFullBrowseResults
        and not AH.HasFullBrowseResults() then
        AH.RequestMoreBrowseResults()
        A.lastQuery = "browse"
    end
    BY.AfterBrowse()
    BY.Render()
    if BY.freshList and BY.tab == "buy" then
        BY.freshList = false
        PlayTiles()
    end
end

-- Near the end of what has come: the next part asked for (at: the row
-- reached, the pick's or the wheel's)
local function MoreIfNeeded(at)
    if (at or BY.index) > #BY.results - 10 and AH.HasFullBrowseResults and not AH.HasFullBrowseResults() then
        -- (with only upgrades shown, few of what came may show)
        AH.RequestMoreBrowseResults()
    end
end

local function KeyInfo(result)
    return result and AH.GetItemKeyInfo(result.itemKey)
end

-- Its lowest against its usual price: "-23%" (green) / "+15%" (red), or ""
local function Deal(itemID, price)
    local usual = A.MarketPrice(itemID)
    if not usual or usual <= 0 or not price then return "" end
    local pct = math.floor((price / usual - 1) * 100 + 0.5)
    if pct <= -5 then return "|cff5fd35f" .. pct .. "%|r" end
    if pct >= 5 then return "|cffff7a5c+" .. pct .. "%|r" end
    return "|cff9d917a" .. (pct > 0 and "+" or "") .. pct .. "%|r"
end

---------------------------------------------------------------------------
-- An item: D = { result, info, itemID, commodity, listings, row, qty,
-- searching, state (nil, "quote": waiting for the price, "confirm":
-- priced, its popup up, "buying"), quote (unit, total), message }
---------------------------------------------------------------------------
-- (D: declared with the item's screen, above)
-- Auctions bought this visit (auctionID -> true): never offered again, a
-- list that comes back still holding one (the server's a moment behind)
local boughtIDs = {}

-- What qty of a commodity costs from the listings, cheapest first (nil: not that many)
local function Cost(qty)
    local left, total = qty, 0
    for _, l in ipairs(D.listings or {}) do
        local take = math.min(left, l.count - (l.own or 0))
        if take > 0 then
            total = total + take * l.unit
            left = left - take
        end
        if left <= 0 then break end
    end
    return left <= 0 and total or nil
end

local function Available()
    local n = 0
    for _, l in ipairs(D.listings or {}) do n = n + l.count - (l.own or 0) end
    return n
end

local function Auctions()
    local list = {}
    for _, l in ipairs(D.listings or {}) do
        if l.own < l.count then list[#list + 1] = l end
    end
    return list
end

---------------------------------------------------------------------------
-- The versions listed: a group (one item key) can hold auctions of the
-- same item with different stats (random "of the ..." suffixes). Each
-- auction's own tooltip (its link) gives its lines that make it what it
-- is: + stats, Equip / Use / Chance on hit; auctions with the same
-- lines are one version, at its lowest price, with how many are up.
---------------------------------------------------------------------------
local MAX_VERSIONS = 6
local versionCache = {}   -- key string (KeyString) -> { versions, pending }

local function KeyString(key)
    return key.itemID .. ":" .. (key.itemLevel or 0) .. ":" .. (key.itemSuffix or 0)
end

local TRIGGERS = {}
for _, g in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC" }) do
    if _G[g] then TRIGGERS[#TRIGGERS + 1] = _G[g] end
end

-- The lines that tell one version from another, or nil (not loaded yet)
local function VersionLines(link)
    local tips = C_TooltipInfo
    if not (tips and tips.GetHyperlink) then return nil end
    local ok, data = pcall(tips.GetHyperlink, link)
    if not ok or not data or not data.lines or #data.lines < 2 then return nil end
    local lines = {}
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if text and text ~= "" then
            local keep = text:match("^[%+%-]%d")
            for _, trigger in ipairs(TRIGGERS) do
                if text:sub(1, #trigger) == trigger then keep = true end
            end
            if keep then lines[#lines + 1] = text end
        end
    end
    return lines
end

local function Versions(listings)
    local byLines, list, pending = {}, {}, false
    for _, l in ipairs(listings or {}) do
        local lines = l.link and VersionLines(l.link)
        if l.link and not lines then pending = true end
        if lines then
            local sig = table.concat(lines, "|")
            local v = byLines[sig]
            if not v then
                v = { lines = lines, price = math.huge, count = 0 }
                byLines[sig] = v
                list[#list + 1] = v
            end
            v.price = math.min(v.price, l.total or l.unit * l.count)
            v.count = v.count + l.count
        end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    return { versions = list, pending = pending }
end

local function AddVersions(key)
    local c = versionCache[KeyString(key)]
    if not c then return end
    local versions = c.versions
    if #versions == 0 then
        if c.pending then GameTooltip:AddLine("Loading the versions listed...", 0.6, 0.55, 0.45) end
        return
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(#versions == 1 and "Listed: 1 version" or ("Listed: " .. #versions .. " versions"), 0.79, 0.64, 0.35)
    for i, v in ipairs(versions) do
        if i > MAX_VERSIONS then
            GameTooltip:AddLine("and " .. (#versions - MAX_VERSIONS) .. " more", 0.6, 0.55, 0.45)
            break
        end
        GameTooltip:AddDoubleLine(" ", A.Money(v.price) .. (v.count > 1 and ("  |cff9d917a(" .. v.count .. ")|r") or ""),
            1, 1, 1, 1, 1, 1)
        if #v.lines == 0 then
            GameTooltip:AddLine("   no extra stats", 0.6, 0.55, 0.45)
        end
        for _, line in ipairs(v.lines) do
            GameTooltip:AddLine("   " .. line, 0.4, 0.9, 0.4, true)
        end
    end
end

local function KeepVersions(key, listings)
    local c = Versions(listings)
    c.listings = listings
    versionCache[KeyString(key)] = c
end

-- A group's upgrade: its best listed version (once its auctions were looked
-- up: gear with random stats, whose plain item has none), else its plain
-- item. Returns upgrade, gain, needLevel.
function BY.GroupUpgrade(itemKey)
    if S().buyUpgrades == "off" then return false end
    local UP = IF.Upgrades
    local c = versionCache[KeyString(itemKey)]
    local best, bestGain, bestNeed = false, nil, nil
    for _, l in ipairs(c and c.listings or {}) do
        if l.link and UP.IsUpgrade(l.link, nil, nil, true) then
            local gain, need = UP.Gain(l.link, nil, nil, true)
            if not best or (gain or 0) > (bestGain or 0) then best, bestGain, bestNeed = true, gain, need end
        end
    end
    if best then return true, bestGain, bestNeed end
    if UP.IsUpgradeKey(itemKey) then return true, UP.GainKey(itemKey) end
    return false
end

-- Why the picked one is an upgrade or not (/if upgrade): an item's
-- picked auction, else the group's plain item
function BY.Explain()
    if not win:IsShown() or BY.tab ~= "buy" then
        return IF.Print("open the auction house's Buy tab and pick an item first.")
    end
    local link
    if D and not D.commodity then
        local a = Auctions()[D.row]
        link = a and a.link
    end
    local result = BY.results[BY.index]
    if not link and result then link = select(2, (C_Item and C_Item.GetItemInfo or GetItemInfo)(result.itemKey.itemID)) end
    if not link then return IF.Print("no item picked (or its data not loaded yet).") end
    IF.Print("upgrade? " .. link)
    for _, line in ipairs(IF.Upgrades.Explain(link, true)) do IF.Print("  " .. line) end
end

-- Item data come in: the versions still loading worked out again
local function VersionsLoaded()
    local changed = false
    for k, c in pairs(versionCache) do
        if c.pending then
            local again = Versions(c.listings)
            again.listings = c.listings
            versionCache[k] = again
            changed = true
        end
    end
    if changed then BY.Tip() end
end

-- Where tooltips go: beside the window under the pages' names, on the
-- screen's right where there's room for one, else on its left
function BY.PlaceTip()
    GameTooltip:ClearAllPoints()
    local right = win:GetRight()
    local scale = win:GetEffectiveScale() / UIParent:GetEffectiveScale()
    -- (a tooltip's room: 300)
    if right and right * scale + 300 > UIParent:GetWidth() then
        GameTooltip:SetPoint("TOPRIGHT", win, "TOPLEFT", -16, -TAB_H)
    else
        GameTooltip:SetPoint("TOPLEFT", win, "TOPRIGHT", 16, -TAB_H)
    end
end

-- Tooltips show as the bag window's do: the game's own setting (CVar
-- GamepadDisableTooltips), which R3 turns on and off here too
function BY.TipsOff()
    -- (with the mouse: always on, as the game's own)
    if Mouse() then return false end
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return get and get("GamepadDisableTooltips") or false
end

function BY.ToggleTips()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set("GamepadDisableTooltips", BY.TipsOff() and "0" or "1") end
end

-- What is worn in its place, beside the tooltip (gear: the game's own
-- comparison), else no comparison left from before. The game puts it on
-- the side with more room (left: over the window): moved to the
-- tooltip's right, or under it when the screen ends first.
function BY.Compare()
    local tips = {}
    for _, tip in ipairs({ _G.ShoppingTooltip1, _G.ShoppingTooltip2 }) do
        if tip then tips[#tips + 1] = tip end
    end
    if not (GameTooltip_ShowCompareItem and pcall(GameTooltip_ShowCompareItem, GameTooltip)) then
        for _, tip in ipairs(tips) do tip:Hide() end
        return
    end
    local shown, width = {}, 0
    -- (the game shows the second first, the first beside it: worn order)
    for _, tip in ipairs(tips) do
        if tip:IsShown() then
            shown[#shown + 1] = tip
            width = width + tip:GetWidth()
        end
    end
    if #shown == 0 then return end
    local right = GameTooltip:GetRight() or 0
    local fits = right + width <= GetScreenWidth()
    for i, tip in ipairs(shown) do
        tip:ClearAllPoints()
        if i == 1 then
            if fits then
                tip:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 2, 0)
            else
                tip:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -2)
            end
        else
            tip:SetPoint("TOPLEFT", shown[i - 1], "TOPRIGHT", 2, 0)
        end
    end
end

-- The tooltip, beside the window: the picked group (its item key), or in an
-- item the auction picked (its own link: its exact stats)
local function ItemKeyTip(key)
    if GameTooltip.SetItemKey then
        local required = AH.GetItemKeyRequiredLevel and AH.GetItemKeyRequiredLevel(key)
        GameTooltip:SetItemKey(key.itemID, key.itemLevel, key.itemSuffix, required)
    else
        GameTooltip:SetItemByID(key.itemID)
    end
end

function BY.Tip()
    if BY.Hovering() then return end
    local tipOwner = GameTooltip:GetOwner() == win
    local result = BY.results[BY.index]
    if not win:IsShown() or filterBox:IsShown() or (not D and not result) or BY.TipsOff() then
        if tipOwner then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(win, "ANCHOR_NONE")
    BY.PlaceTip()
    local key
    if D then
        local auction = not D.commodity and Auctions()[D.row]
        if auction and auction.link then
            GameTooltip:SetHyperlink(auction.link)
        elseif D.commodity then
            GameTooltip:SetItemByID(D.itemID)
        else
            ItemKeyTip(D.result.itemKey)
        end
    else
        key = result.itemKey
        ItemKeyTip(key)
    end
    -- (a group: its versions; an auction's own tooltip is that version)
    if key then AddVersions(key) end
    GameTooltip:Show()
    BY.Compare()
end

-- Gear picked in the list for a moment: its auctions looked up quietly,
-- for its possible stats
local PREFETCH_AFTER = 0.6
local prefetched = {}

local function Prefetch(now)
    local result = not D and not filterBox:IsShown() and not BY.searching and BY.results[BY.index]
    if not result then
        BY.restingOn = nil
        return
    end
    local key = KeyString(result.itemKey)
    if BY.restingOn ~= key then
        BY.restingOn, BY.restingSince = key, now
        return
    end
    if prefetched[key] or now - BY.restingSince < PREFETCH_AFTER then return end
    local info = KeyInfo(result)
    if not info or info.isCommodity or not info.isEquipment then return end
    prefetched[key] = true
    local itemKey = result.itemKey
    A.Search(itemKey.itemID, false, nil, function(listings)
        if listings then
            KeepVersions(itemKey, listings)
            -- (its badges from its versions now; its tooltip too)
            BY.FilterResults()
            BY.Render()
        else
            prefetched[key] = nil
        end
    end, itemKey)
end

function BY.SearchItem()
    if not D then return end
    D.searching, D.state, D.message = true, nil, nil
    local itemID = D.itemID
    A.Search(itemID, D.commodity, nil, function(listings)
        if not D or D.itemID ~= itemID then return end
        D.searching = false
        D.listings = {}
        for _, l in ipairs(listings or {}) do
            if not boughtIDs[l.auctionID] then D.listings[#D.listings + 1] = l end
        end
        if not listings then D.message = "No answer from the auction house" end
        if not D.commodity then KeepVersions(D.result.itemKey, D.listings) end
        D.qty = math.max(1, math.min(D.qty or 1, Available()))
        BY.Render()
    end, not D.commodity and D.result.itemKey or nil)
    BY.Render()
end

-- result: a browse result ({ itemKey }); qty: where a commodity's quantity starts
local function Open(result, qty)
    local info = KeyInfo(result)
    if not result or not info then return false end
    D = {
        result = result, info = info, itemID = result.itemKey.itemID, commodity = info.isCommodity,
        row = 1, qty = math.max(1, qty or 1), listings = {}, wantQty = qty,
    }
    detail:Show()
    SC.FadeIn(detail, 0.2)
    BY.SearchItem()
    return true
end

function BY.OpenItem()
    Open(BY.results[BY.index])
end

-- Where the item's screen goes on the Buy tab: beside the list
local function PlaceDetail()
    if detail:GetParent() ~= buyPage then return end
    detail:ClearAllPoints()
    -- (the third column, the page's full height)
    detail:SetPoint("TOPLEFT", buyPage, "TOPLEFT", PREVIEW_X, -20)
    detail:SetPoint("BOTTOMRIGHT", buyPage, "BOTTOMRIGHT", -16, 36)
end

-- The list view: a moment's rest on an item, its screen beside the list
-- (searched); the one shown before closed
local function Preview(now)
    if BY.detailFocus or filterBox:IsShown() then
        BY.previewOn = nil
        return
    end
    local result = BY.results[BY.index]
    if not result then
        -- (nothing listed now: the one shown before closed)
        BY.previewOn = nil
        if D and not BY.searching then BY.CloseItem() end
        return
    end
    local key = KeyString(result.itemKey)
    if D and KeyString(D.result.itemKey) == key then return end
    if BY.previewOn ~= key then
        BY.previewOn, BY.previewSince = key, now
        return
    end
    if now - BY.previewSince < PREVIEW_AFTER then return end
    if D then BY.CloseItem() end
    Open(result)
    BY.Render()
end

-- An item to buy from elsewhere (a task): the Buy tab, its item open,
-- qty to start at (once its data have come, if not yet)
local pendingOpen
function BY.OpenFor(itemID, qty)
    if not win:IsShown() then return end
    BY.SetTab("buy")
    filterBox:Hide()
    if D then BY.CloseItem() end
    local result = { itemKey = AH.MakeItemKey(itemID) }
    pendingOpen = nil
    BY.detailFocus = true
    if not Open(result, qty) then pendingOpen = { result = result, qty = qty } end
    BY.Render()
end

function BY.CloseItem()
    BY.detailFocus = false
    if D and D.state == "quote" or D and D.state == "confirm" then
        if AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
    end
    D = nil
    detail:Hide()
    BY.Render()
end

-- The server takes one auction house message at a time: a buy sent while
-- it's busy (the search or the list asked again after the last buy) is
-- dropped, never answered
local BUSY = "The auction house is busy: hold again in a moment"
local function Busy()
    return AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady()
end

-- The client takes a bid only on an auction of its last search: one
-- sent since (the list, another item) and the bid goes nowhere, unsaid
local AGAIN = "Looked up again: hold again"
local function SearchedElsewhere()
    local q = A.lastQuery
    return type(q) ~= "table" or q.commodity or not q.itemKey or q.itemID ~= D.itemID
end

-- The refresh icon: what is listed looked up again in place, then the open
-- item's auctions (after the list: its search the last one sent)
function BY.Refresh()
    BY.Query(true)
    if D then D.afterBrowse = GetTime() end
end

-- After a buy: the list's refresh first, the item looked up again once it
-- has come (the item's search the last one sent)
function BY.AfterBrowse()
    if not (D and D.afterBrowse) then return end
    D.afterBrowse = nil
    local message = D.message
    BY.SearchItem()
    D.message = message
end

-- Cross held: the hold starts (a commodity's price asked of the server
-- now: that wants a hardware event too, the press is one); short of
-- money or of that many: said, no hold
local function BuyStart()
    if not D or D.searching or D.state == "buying" or IF.InCombat() then return end
    if Busy() and D.state ~= "confirm" then
        D.message = BUSY
        return BY.Render()
    end
    if D.commodity then
        local total = Cost(D.qty)
        if not total then
            D.message = "Not that many for sale"
            return BY.Render()
        end
        if total > GetMoney() then
            D.message = "Not enough money"
            return BY.Render()
        end
        if D.state ~= "confirm" then
            D.state, D.quote = "quote", nil
            AH.StartCommoditiesPurchase(D.itemID, D.qty, math.ceil(total / D.qty))
        end
    else
        local auction = Auctions()[D.row]
        if not auction then return end
        if SearchedElsewhere() then
            BY.SearchItem()
            D.message = AGAIN
            return BY.Render()
        end
        local price = auction.total or auction.unit * auction.count
        if price > GetMoney() then
            D.message = "Not enough money"
            return BY.Render()
        end
    end
    D.holdStart, D.message = GetTime(), nil
    BY.Render()
end

-- A commodity's price asked and not bought: let go
local function DropQuote()
    if D and (D.state == "quote" or D.state == "confirm") then
        if AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
        D.state, D.quote = nil, nil
    end
end

-- Cross let go (a hardware event): full, bought (a commodity: at the
-- server's price, once it has come); short of full, nothing
function BY.DetailRelease(name)
    if name ~= "A" or not (D and D.holdStart) then return end
    local full = BY.HoldProgress(D.holdStart) >= 1
    D.holdStart = nil
    if not full or IF.InCombat() then
        DropQuote()
        return BY.Render()
    end
    if Busy() then
        if D.state ~= "confirm" then DropQuote() end
        D.message = BUSY
        return BY.Render()
    end
    if D.commodity then
        if D.state == "confirm" and D.quote then
            D.state, D.message, D.buyingAt = "buying", "Buying...", GetTime()
            AH.ConfirmCommoditiesPurchase(D.itemID, D.qty)
            BY.HoldDone()
        else
            DropQuote()
            D.message = "The price hasn't come back yet: hold again"
        end
    else
        local auction = Auctions()[D.row]
        if auction and SearchedElsewhere() then
            BY.SearchItem()
            D.message = AGAIN
        elseif auction then
            local price = auction.total or auction.unit * auction.count
            D.state, D.message, D.buyingAt = "buying", "Buying...", GetTime()
            D.bought = auction
            AH.PlaceBid(auction.auctionID, price)
            BY.HoldDone()
        end
    end
    BY.Render()
end

local function Bought(what)
    PlaySound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
    IF.Print("bought " .. what .. ".")
    if D then
        -- (looked up again after the list's refresh, BY.AfterBrowse)
        D.state, D.searching, D.afterBrowse = nil, true, GetTime()
        D.message = "|cff5fd35fBought " .. what .. "|r"
    end
end

---------------------------------------------------------------------------
-- The mouse: the wheel over each list, the rows' tooltips, the hold box
-- held, a search box over the categories
---------------------------------------------------------------------------
local CloseFilters, RenderFilters
do
    -- (the wheel scrolls the results, the pick left where it is)
    local function ScrollResults(dir)
        local n = #BY.results
        if n == 0 then return end
        BY.freeTop = true
        -- (a row a step: the first shown stays the start of a row)
        local lastTop = (math.max(1, math.ceil(n / COLS) - GRID_ROWS + 1) - 1) * COLS + 1
        BY.top = math.max(1, math.min(lastTop, BY.top + dir * COLS))
        MoreIfNeeded(BY.top + PER - 1)
        BY.Render()
    end
    local list = { content }
    for _, r in ipairs(listRows) do list[#list + 1] = r end
    BY.Wheel(list, ScrollResults)
    local sides = { side }
    for _, r in ipairs(sideRows) do sides[#sides + 1] = r end
    BY.Wheel(sides, function(dir) BY.SetMain(BY.main + dir) end)
    BY.Wheel({ bar2 }, function(dir) BY.SetSub(BY.sub + dir) end)
    BY.Wheel({ bar3 }, function(dir) BY.SetSubSub(BY.subsub + dir) end)
    -- (the item's screen: a commodity's quantity, else the auction)
    local screens = { detail }
    for _, r in ipairs(V.rows) do screens[#screens + 1] = r end
    BY.Wheel(screens, function(dir)
        if not D then return end
        if D.commodity then
            DetailPress(dir < 0 and "RIGHT" or "LEFT", IsShiftKeyDown())
        else
            DetailPress(dir < 0 and "UP" or "DOWN")
        end
    end)

    for _, r in ipairs(listRows) do
        BY.Hover(r, function(self)
            local result = self.index and BY.results[self.index]
            if not result then return false end
            ItemKeyTip(result.itemKey)
            AddVersions(result.itemKey)
        end)
    end
    for _, r in ipairs(V.rows) do
        r:SetScript("OnClick", function(self)
            if not (D and self.index) or D.state == "buying" then return end
            if detail:GetParent() == buyPage then BY.detailFocus = true end
            DropQuote()
            D.row, D.state, D.message = self.index, nil, nil
            BY.Render()
        end)
        BY.Hover(r, function(self)
            local a = D and not D.commodity and self.index and Auctions()[self.index]
            if not (a and a.link) then return false end
            GameTooltip:SetHyperlink(a.link)
        end)
    end
    for _, row in ipairs(ddRows) do
        row:HookScript("OnEnter", function(self)
            if Mouse() and Selectable(self.entry) then
                BY.filterRow = self.index
                RenderFilters()
            end
        end)
    end

    -- (held down on: as Cross held on the item's screen)
    V.hold.onDown = function()
        if filterBox:IsShown() then CloseFilters() end
        if detail:GetParent() == buyPage then BY.detailFocus = true end
        BY.MouseDown("A")
    end
    V.hold.onUp = function() BY.MouseUp("A") end

    -- The search box, where the categories' title is: what's typed looked
    -- up (in the chosen category) a moment after
    local ok, box = pcall(K.NewFrame, "EditBox", "ImprovedForeverAuctionSearch", side, "SearchBoxTemplate")
    if not ok then box = K.NewFrame("EditBox", "ImprovedForeverAuctionSearch", side, "InputBoxTemplate") end
    box:SetSize(SIDE_W - 28, 20)
    box:SetPoint("TOP", 2, -6)
    box:SetAutoFocus(false)
    box:HookScript("OnTextChanged", function(self, user)
        local text = strtrim(self:GetText() or "")
        if text == (BY.search or "") then return end
        BY.search = text
        BY.Query()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:Hide()
    BY.searchBox = box
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function RenderSide()
    local mains = Mains()
    -- (with the mouse: the search box in its place)
    BY.searchBox:SetShown(Mouse())
    local top = math.max(1, math.min(BY.main - math.floor(SIDE_ROWS / 2), #mains - SIDE_ROWS + 1))
    local GOLD, sideMark = SCENE.gold, SCENE.mark
    sideMark:Hide()
    for i, r in ipairs(sideRows) do
        local index = top + i - 1
        local cat = mains[index]
        r:SetShown(cat ~= nil)
        if cat then
            r.index = index
            local on = index == BY.main
            r.text:SetText(cat.name)
            if on then r.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else r.text:SetTextColor(0.62, 0.62, 0.62) end
            if on then
                SCENE.icon:SetTexture("Interface\\Icons\\" .. (CATEGORY_ICONS[cat.name] or "INV_Misc_QuestionMark"))
                sideMark:Show()
            end
        end
    end
end

local function RenderResults()
    local results = BY.results
    local n = #results
    BY.index = math.max(1, math.min(BY.index, math.max(1, n)))
    -- Scrolled keeping the picked one in view (unless the wheel scrolled it),
    -- by rows: the first shown is the start of one
    local indexRow, topRow = math.ceil(BY.index / COLS), math.ceil(BY.top / COLS)
    if not BY.freeTop then
        if indexRow < topRow then topRow = indexRow end
        if indexRow > topRow + GRID_ROWS - 1 then topRow = indexRow - GRID_ROWS + 1 end
    end
    topRow = math.max(1, math.min(topRow, math.max(1, math.ceil(n / COLS) - GRID_ROWS + 1)))
    BY.top = (topRow - 1) * COLS + 1
    emptyText:SetShown(n == 0)
    emptyText:SetText(BY.searching and "Searching..." or "Nothing listed here")
    for _, r in ipairs(listRows) do r:Hide() end
    for i, f in ipairs(listRows) do
        local index = BY.top + i - 1
        local result = results[index]
        if result then
            f.index = index
            local info = KeyInfo(result)
            local price = result.minPrice
            local upgrade, gain, needLevel = BY.GroupUpgrade(result.itemKey)
            f:Fill({
                icon = info and info.iconFileID, quality = info and info.quality,
                name = info and info.itemName or "...", itemID = result.itemKey.itemID, price = price,
                count = result.totalQuantity, upgrade = upgrade, gain = gain, needLevel = needLevel,
            })
            f:Lit(index == BY.index, filterBox:IsShown(), true)
            f:Show()
        end
    end
end

-- What it costs, for the hold box: the picked auction; a commodity's
-- quantity (the server's price once asked, else from the listings)
function HoldPrice()
    if not D then return nil end
    if D.commodity then
        local total = D.quote and D.quote.total or Cost(D.qty)
        return total and A.Money(total) or "not that many"
    end
    local a = Auctions()[D.row]
    return a and A.Money(a.total or a.unit * a.count) or nil
end

-- The item's screen has the pad: gone into (beside the list), or in
-- another page (the Tasks tab)
local function DetailActive()
    return BY.detailFocus or detail:GetParent() ~= buyPage
end

-- What sets an auction apart, for its capsule: its upgrade and the gain
-- (one of a higher level: for later), else how far from the usual price
local CHEAP, DEAR, UPGRADE, LATER = { 0.55, 0.85, 0.55 }, { 0.92, 0.55, 0.5 }, { 0.5, 0.75, 1 }, { 0.78, 0.62, 1 }
local function Apart(itemID, unit, upgrade, gain, needLevel)
    if upgrade then
        return "UPGRADE " .. (gain and ("+" .. math.max(1, math.floor(gain + 0.5)) .. "%") or "NEW")
            .. (needLevel and " LATER" or ""), needLevel and LATER or UPGRADE
    end
    local usual = A.MarketPrice(itemID)
    local pct = usual and usual > 0 and unit and unit > 0 and math.floor((unit / usual - 1) * 100 + 0.5)
    if pct and pct <= -5 then return -pct .. "% BELOW USUAL", CHEAP end
    if pct and pct >= 5 then return pct .. "% ABOVE USUAL", DEAR end
end

local function RenderDetail()
    if not D then return end
    local w = detail:GetWidth()
    V.rule:SetLength(math.max(100, w - 40))
    -- (the two prices each in the middle of its half)
    V.lowLabel:ClearAllPoints()
    V.lowLabel:SetPoint("TOP", V.rule, "BOTTOM", -w / 4, -10)
    V.usualLabel:ClearAllPoints()
    V.usualLabel:SetPoint("TOP", V.rule, "BOTTOM", w / 4, -10)
    -- (a short screen, beside the list: a shorter chart, more auctions)
    V.chart:SetHeight(detail:GetHeight() >= 520 and 110 or 70)
    local info = D.info
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
    V.icon:SetIcon(info.iconFileID)
    V.upgrade:SetShown(BY.GroupUpgrade(D.result.itemKey) and true or false)
    V.name:SetText(info.itemName)
    -- (poor and common names in cream: their own is too dark to read)
    if (info.quality or 1) <= 1 or not c then
        V.name:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3])
    else
        V.name:SetTextColor(c.r, c.g, c.b)
    end
    local available = Available()
    V.sub:SetText(D.searching and "Searching..." or (available .. " for sale"))
    local lowest = D.listings[1] and D.listings[1].unit
    local pay
    if D.commodity then
        local total = Cost(D.qty)
        pay = total and total / D.qty
    else
        local a = Auctions()[D.row]
        pay = a and a.unit
    end
    V.chart:Draw({ itemID = D.itemID, lowestNow = lowest, price = pay, searching = D.searching })
    local usual = A.MarketPrice(D.itemID)
    V.low:SetText(lowest and A.Money(lowest) or "—")
    V.usual:SetText(usual and A.Money(usual) or "—")
    V.deal:Set(Apart(D.itemID, lowest))

    local active = DetailActive()
    if D.commodity then
        for _, r in ipairs(V.rows) do r:Hide() end
        V.qtyMid:Show()
        V.moreUp:Hide()
        V.moreDown:Hide()
        V.qty:SetText(D.qty .. "|cff9d917a / " .. available .. "|r")
        -- (the arrows bright while the screen has the pad)
        V.qtyLeft:SetAlpha(active and 1 or 0.4)
        V.qtyRight:SetAlpha(active and 1 or 0.4)
        V.qtyLabel:SetText("")
        -- (with the mouse: typed, its arrows clicked)
        local mouse = Mouse()
        V.qty:SetAlpha(mouse and 0 or 1)
        V.qtyEdit:SetShown(mouse)
        if mouse then
            if not V.qtyEdit:HasFocus() then V.qtyEdit:SetText(D.qty) end
            V.qtyLabel:SetText("of " .. available .. "  ·  Shift: by 10")
        end
        V.qtyLeftButton:SetShown(mouse)
        V.qtyRightButton:SetShown(mouse)
    else
        V.qtyMid:Hide()
        V.qtyEdit:Hide()
        local auctions = Auctions()
        D.row = math.max(1, math.min(D.row, math.max(1, #auctions)))
        -- (as many rows as fit between the chart and the hold line, a
        -- line's room kept over them and under them for "more", and the
        -- message's when there is one)
        local chartBottom, holdTop = V.chart:GetBottom(), V.hold:GetTop()
        local room
        if chartBottom and holdTop then
            room = chartBottom - holdTop - 16 - 16 - ((D.message and D.message ~= "") and 22 or 8)
        else
            room = detail:GetHeight() - 300
        end
        local fit = math.max(1, math.min(AUCTION_ROWS, math.floor(room / AUCTION_H)))
        local top = math.max(1, D.row - fit + 1)
        local shownN = math.min(fit, #auctions - top + 1)
        V.moreUp:SetShown(top > 1)
        V.moreUp:ClearAllPoints()
        V.moreUp:SetPoint("TOP", V.chart, "BOTTOM", 0, -2)
        V.moreUp:SetText((top - 1) .. " more above")
        local below = #auctions - (top + shownN - 1)
        V.moreDown:SetShown(below > 0 and shownN > 0)
        if below > 0 and shownN > 0 then
            V.moreDown:ClearAllPoints()
            V.moreDown:SetPoint("TOP", V.rows[shownN], "BOTTOM", 0, -4)
            V.moreDown:SetText(below .. " more below")
        end
        for i, r in ipairs(V.rows) do
            local a = i <= fit and auctions[top + i - 1]
            r:SetShown(a and true or false)
            r.index = a and top + i - 1 or nil
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", V.chart, "BOTTOMLEFT", 0, -16 - (i - 1) * AUCTION_H)
            r:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
            r.rule:SetLength(math.max(100, w - 40))
            if a then
                local on = top + i - 1 == D.row
                local upgrade = S().buyUpgrades ~= "off" and a.link and IF.Upgrades.IsUpgrade(a.link, nil, nil, true)
                    and true or false
                local gain, needLevel
                if upgrade then gain, needLevel = IF.Upgrades.Gain(a.link, nil, nil, true) end
                local parts = {}
                if a.itemLevel and a.itemLevel > 0 and info.isEquipment then
                    parts[#parts + 1] = "item level " .. a.itemLevel
                end
                if a.count > 1 then parts[#parts + 1] = a.count .. " × " .. A.Money(a.unit) end
                r.icon:SetIcon(info.iconFileID)
                r.upgrade:SetShown(upgrade)
                -- (its own name: a random suffix's "of the Owl")
                r.name:SetText(a.link and a.link:match("%[(.-)%]") or info.itemName)
                if (info.quality or 1) <= 1 or not c then
                    r.name:SetTextColor(0.9, 0.9, 0.9)
                else
                    r.name:SetTextColor(c.r, c.g, c.b)
                end
                r.line:SetText(table.concat(parts, "  ·  "))
                r.price:SetText(A.Money(a.total or a.unit * a.count))
                r.tag:Set(Apart(D.itemID, a.unit, upgrade, gain, needLevel))
                -- (beside the list, not gone into: lit faintly; with the
                -- mouse it's clicked, lit as gone into)
                r:Lit(on, active or Mouse())
            end
        end
    end
    V.status:SetText(D.message or "")
    V.hold:SetHold(BY.HoldProgress(D.holdStart), "A", "Buy", HoldPrice())
end

function RenderFilters()
    ddHint:SetText(Mouse() and "Click to tick  ·  Done closes"
        or (Glyph("DPAD", 16) .. " Move   " .. Glyph("A", 16) .. " Select   " .. Glyph("B", 16) .. " Close"))
    filterBox:SetSize(math.max(filterBox.baseWidth, ddHint:GetStringWidth() + DD_INSET.left + DD_INSET.right),
        filterBox.baseHeight)
    for i, row in ipairs(ddRows) do
        local entry = row.entry
        if Selectable(entry) then row.check:SetShown(entry.isSelected() and true or false) end
        row.highlight:SetShown(i == BY.filterRow)
    end
end

-- For the other pages: the window's parts and looks
BY.Glyph, BY.Panel, BY.FocusStroke, BY.ItemIcon, BY.FocusColor, BY.Atlas, BY.Deal =
    Glyph, Panel, FocusStroke, ItemIcon, FocusColor, Atlas, Deal
BY.ItemRow, BY.DealBadge = ItemRow, DealBadge
BY.W, BY.H = W, H
function BY.IsShown() return win:IsShown() end
function BY.Tab() return BY.tab end

---------------------------------------------------------------------------
-- The pages' names along the window's top, in Morpheus (AuctionScene.lua):
-- the right stick's glyph before them (up / down moves through them)
---------------------------------------------------------------------------
local function CurrentPage()
    for _, t in ipairs(BY.TABS) do
        if t.key == BY.tab and t.key ~= "buy" then return t end
    end
end

local tabRow = SC.TabRow(win, function(key) BY.SetTab(key) end, function(dir) BY.StepTab(dir) end)
-- (its middle the window's, on the Buy page the grid's: ApplyScene)
tabRow:SetWidth(BUY_W)

local function RenderTabs()
    tabRow:Render(BY.TABS, BY.tab)
end

-- The legend: a page's buttons, then the right stick for the tabs (with
-- the mouse: no legend, as the game's mouse windows; the buttons, mouse,
-- in the bottom bar instead; the Wiki by Alt + click, as everywhere)
local mouseBar = K.NewFrame("Frame", nil, SC.footer)
mouseBar:SetPoint("CENTER", SC.footer, "CENTER")
mouseBar:SetSize(1, 26)
mouseBar.buttons = {}

-- (the first-time tour's buttons: words in a row, a faint bar between
-- them, cream under the mouse; Close always last)
local function SetMouseBar(list)
    local x = 0
    list = { unpack(list) }
    list[#list + 1] = { "Close", function() win.onClose() end }
    for i, def in ipairs(list) do
        local b = mouseBar.buttons[i]
        if not b then
            b = SC.TextButton(mouseBar, "", function() end, 15)
            b.text:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3])
            b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
            b:SetScript("OnEnter", function(self) self.text:SetTextColor(SC.GOLD[1], SC.GOLD[2], SC.GOLD[3]) end)
            b:SetScript("OnLeave", function(self) self.text:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3]) end)
            b.bar = SC.Text(mouseBar, 15, SC.GREY, SC.BODY)
            b.bar:SetText("|")
            mouseBar.buttons[i] = b
        end
        b.fn = def[2]
        b.text:SetText(def[1])
        b:SetWidth(b.text:GetStringWidth() + 16)
        b:ClearAllPoints()
        b:SetPoint("LEFT", mouseBar, "LEFT", x, 0)
        b:Show()
        b.bar:SetShown(i > 1)
        b.bar:ClearAllPoints()
        b.bar:SetPoint("CENTER", b, "LEFT", -6, 1)
        x = x + b:GetWidth() + 12
    end
    for i = #list + 1, #mouseBar.buttons do
        mouseBar.buttons[i]:Hide()
        mouseBar.buttons[i].bar:Hide()
    end
    mouseBar:SetWidth(math.max(1, x - 12))
end

local function SetHints(text, mouseList)
    local mouse = Mouse()
    legend:SetShown(not mouse)
    mouseBar:SetShown(mouse)
    if mouse then return SetMouseBar(mouseList or {}) end
    legend:SetText(text .. "   " .. Glyph("RS") .. " Pages (tilt) / " .. (BY.TipsOff() and "Tooltip (click)" or "No tooltip (click)")
        .. ((IF.Wiki and IF.Wiki.Settings().enabled) and " / Hold to Open Wiki" or ""))
end

-- The window's own look (its frame, background, title) never shows: only
-- the scene's parts (AuctionScene.lua); the mouse closes it with the word
-- along the bottom (SetMouseBar), not the corner button. Sized for the page (a page may want it wider: the Tasks tab's
-- three columns), then placed in the room under the header
for _, key in ipairs({ "NineSlice", "Bg", "Background", "TopTileStreaks", "TitleContainer", "TitleBg", "InsetBg",
    "CloseButton" }) do
    local part = win[key]
    if part and part.Hide then part:Hide() end
end
-- (a plain dialog box where the client has no panel template)
if win.SetBackdropColor and not win.NineSlice then
    win:SetBackdropColor(1, 1, 1, 0)
    win:SetBackdropBorderColor(1, 1, 1, 0)
end
local function ApplyScene()
    local page = CurrentPage()
    tabRow:ClearAllPoints()
    if page then
        win:SetSize(page.width or W, H + TAB_H)
        tabRow:SetPoint("TOP", win, "TOP", 0, -4)
    else
        win:SetSize(BUY_W, BUY_H + TAB_H)
        -- (over the grid, the categories' chips under it centred there too)
        tabRow:SetPoint("TOP", win, "TOPLEFT", MAIN_X + MAIN_W / 2, -4)
    end
    SC.Place(win)
end

function BY.SetTab(key)
    if key == BY.tab then return end
    local old = CurrentPage()
    if old then old.Hide() else buyPage:Hide() end
    local was = BY.tab
    if GameTooltip:GetOwner() == win then GameTooltip:Hide() end
    BY.tab, BY.held = key, nil
    -- (an item's screen open: closed, back home)
    pendingOpen = nil
    if D then
        D = nil
        detail:Hide()
    end
    BY.detailFocus = false
    BY.DetailHome()
    local page = CurrentPage()
    -- (a page may want the window wider: the Tasks tab's three columns)
    ApplyScene()
    if page then
        if not page.frame then page.frame = page.Build(pageHost) end
        page.Show()
    else
        buyPage:Show()
    end
    -- (the new page fading in)
    if was ~= key then SC.FadeIn(page and page.frame or buyPage, 0.25) end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
    BY.Render()
end

-- dir: 1 the tab below, -1 the one above (round from the ends)
function BY.StepTab(dir)
    local n = #BY.TABS
    for i, t in ipairs(BY.TABS) do
        if t.key == BY.tab then return BY.SetTab(BY.TABS[(i - 1 + dir) % n + 1].key) end
    end
end

-- The item's screen's buttons (no Circle: its page says what that does)
local function DetailHints(onBuy)
    if not D then return "" end
    -- (a commodity's quantity steps: 1, 5, 20; on the Buy tab the
    -- shoulders change the categories)
    local move = D.commodity
        and (Glyph("DPAD_LR") .. " 1   " .. Glyph("DPAD_UD") .. " 5   "
            .. (onBuy and "" or (Glyph("LT") .. " " .. Glyph("RT") .. " 20   ")))
        or (Glyph("DPAD_UD") .. " Auction   ")
    return Glyph("A") .. " Hold to Buy   " .. move .. Glyph("X") .. " Refresh   "
end

---------------------------------------------------------------------------
-- The item's screen in another page (the Tasks tab): moved into a frame
-- there and back; an item opened in place; drawn, its buttons
---------------------------------------------------------------------------
function BY.DetailInto(parent, left, top, right, bottom)
    detail:SetParent(parent)
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
    detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", right, bottom)
    detail:SetFrameLevel(parent:GetFrameLevel() + 20)
end

function BY.DetailHome()
    detail:SetParent(buyPage)
    detail:ClearAllPoints()
    detail:SetAllPoints(content)
    detail:SetFrameLevel(win:GetFrameLevel() + 20)
end

function BY.DetailOpen(itemID, qty)
    if D then BY.CloseItem() end
    local result = { itemKey = AH.MakeItemKey(itemID) }
    pendingOpen = nil
    if not Open(result, qty) then pendingOpen = { result = result, qty = qty } end
end

function BY.DetailClose()
    pendingOpen = nil
    if D then BY.CloseItem() end
end

function BY.DetailItemID()
    return (D and D.itemID) or (pendingOpen and pendingOpen.result.itemKey.itemID)
end

function BY.DetailRender()
    if D then RenderDetail() end
end

-- The item in front (R3 held: its Wiki page, Wiki.lua): a page's own
-- (its FocusedItem), else the item's screen open, else the picked result
function BY.FocusedItem()
    local page = CurrentPage()
    local item = page and page.FocusedItem and page.FocusedItem()
    if item then return item end
    local id = BY.DetailItemID()
    if id or page then return id end
    local result = BY.results[BY.index]
    return result and result.itemKey and result.itemKey.itemID
end

BY.DetailHints = DetailHints

function BY.Render()
    if not win:IsShown() then return end
    RenderTabs()
    local page = CurrentPage()
    if page then
        titleText:SetText("Auction House  ·  " .. page.label)
        page.Render()
        SetHints(page.Hints(), page.MouseHints and page.MouseHints() or {})
        return
    end
    titleText:SetText("Auction House  ·  Buy")
    RenderSide()
    local main, sub = Chosen()
    bar2:Render(Names(main), BY.sub)
    -- (the third row only where the second's pick has its own)
    local names3 = Names(sub)
    bar3:SetShown(sub ~= nil and #names3 > 1)
    if bar3:IsShown() then bar3:Render(names3, BY.subsub) end
    RenderResults()
    PlaceDetail()
    if D then RenderDetail() end
    if filterBox:IsShown() then RenderFilters() end
    local text
    if filterBox:IsShown() then
        text = Glyph("DPAD") .. " Move   " .. Glyph("A") .. " Select   " .. Glyph("LS") .. " / " .. Glyph("B") .. " Close"
    elseif D and BY.detailFocus then
        text = DetailHints(true) .. Glyph("LB") .. " " .. Glyph("RB") .. " Category   " .. Glyph("B") .. " Back"
    else
        text = Glyph("A") .. " Open   " .. Glyph("DPAD") .. " Move   " .. Glyph("LS") .. " Filters   "
            .. Glyph("B") .. " Close"
    end
    filterWord:Tint(filterWord:IsMouseOver())
    SetHints(text, {})
    BY.Tip()
end

---------------------------------------------------------------------------
-- The pad: buttons, and the left stick (main categories)
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
    PADLSTICK = "LS", PADRSTICK = "RS",
}
local REPEATS = { UP = true, DOWN = true, LEFT = true, RIGHT = true, LB = true, RB = true, LT = true, RT = true }

local function MoveResults(name, fast)
    local n = #BY.results
    if n == 0 then return end
    -- (left / right along a row, on to the next; up / down by a row)
    local d = ({ UP = -COLS, DOWN = COLS, LEFT = -1, RIGHT = 1 })[name]
    if not d then return end
    if fast and (name == "UP" or name == "DOWN") then d = d * 3 end
    local to = BY.index + d
    if to < 1 then
        -- (up from the top rows: where it is; left from the first: there)
        to = name == "LEFT" and 1 or BY.index
    elseif to > n then
        -- (down into a short last row: its last one)
        to = (name == "DOWN" and math.ceil(BY.index / COLS) < math.ceil(n / COLS)) and n or BY.index
    end
    BY.index = to
    BY.freeTop = false
    MoreIfNeeded()
end

function BY.PickFilter()
    local entry = ENTRIES[BY.filterRow]
    if not Selectable(entry) then return end
    entry.onSelect()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    BY.filtersChanged = true
    BY.Render()
end

function BY.CloseFilters() CloseFilters() end
function CloseFilters()
    filterBox:Hide()
    if BY.filtersChanged then
        BY.filtersChanged = false
        BY.Query()
    end
end

-- The item's screen's presses (true: taken). stay: Circle not taken (a
-- page showing it all along: the Tasks tab)
function DetailPress(name, fast, stay)
    if not D then return false end
    if name == "B" then
        if stay then return false end
        BY.CloseItem()
        return true
    end
    if name == "A" then
        BuyStart()
        return true
    end
    -- (anything else pressed while holding: the hold dropped)
    if D.holdStart then
        D.holdStart = nil
        DropQuote()
    end
    if name == "X" then
        BY.SearchItem()
        return true
    end
    if D.state == "buying" or D.state == "quote" then return true end
    if D.commodity and (name == "LEFT" or name == "RIGHT") then
        D.qty = math.max(1, math.min(math.max(1, Available()), D.qty + (name == "RIGHT" and 1 or -1) * (fast and 10 or 1)))
        D.state, D.quote, D.message = nil, nil, nil
    elseif D.commodity and (name == "UP" or name == "DOWN" or name == "LB" or name == "RB"
        or name == "LT" or name == "RT") then
        -- Up / down and L1 / R1: by 5, L2 / R2: by 20 (held: again), on
        -- their round numbers: 1 -> 5 -> 10..., 7 -> 10 up, 5 down; never
        -- under 1 (on the Buy tab the shoulders change the categories)
        local step = (name == "LT" or name == "RT") and 20 or 5
        local qty
        if name == "UP" or name == "RB" or name == "RT" then
            qty = (math.floor(D.qty / step) + 1) * step
        else
            qty = (math.ceil(D.qty / step) - 1) * step
        end
        D.qty = math.max(1, math.min(math.max(1, Available()), qty))
        D.state, D.quote, D.message = nil, nil, nil
    elseif not D.commodity and (name == "UP" or name == "DOWN") then
        D.row = D.row + (name == "UP" and -1 or 1)
        D.state, D.message = nil, nil
    else
        return false
    end
    BY.Render()
    return true
end
BY.DetailPress = DetailPress

function BY.Press(name, fast)
    -- (a popup up, AuctionConfirm.lua: its press)
    if IF.AuctionConfirm.Press(name) then return BY.Render() end
    if name == "RS" then
        BY.ToggleTips()
        if BY.TipsOff() and GameTooltip:GetOwner() == win then GameTooltip:Hide() end
        return BY.Render()
    end
    local page = CurrentPage()
    if page then
        if page.Press(name, fast) then return end
        if name == "B" and AH.CloseAuctionHouse then AH.CloseAuctionHouse() end
        return
    end
    if filterBox:IsShown() then
        if name == "UP" or name == "DOWN" then
            MoveFilterFocus(name == "UP" and -1 or 1)
        elseif name == "A" then
            return BY.PickFilter()
        elseif name == "LS" or name == "B" then
            CloseFilters()
        end
        return BY.Render()
    end
    if D and BY.detailFocus then
        -- (Circle back to the list, the screen kept; the categories' buttons
        -- and the filters: the list's, the screen left)
        local toList = name == "LB" or name == "RB" or name == "LT" or name == "RT" or name == "LS"
        if name == "B" or toList then
            if D.holdStart then D.holdStart = nil end
            BY.detailFocus = false
            if name == "B" then return BY.Render() end
        else
            DetailPress(name, fast)
            return
        end
    end
    if name == "UP" or name == "DOWN" or name == "LEFT" or name == "RIGHT" then
        MoveResults(name, fast)
    elseif name == "LB" or name == "RB" then
        BY.SetSub(BY.sub + (name == "RB" and 1 or -1))
        return
    elseif name == "LT" or name == "RT" then
        BY.SetSubSub(BY.subsub + (name == "RT" and 1 or -1))
        return
    elseif name == "A" then
        -- (the list view: into the screen beside it, opened now if not yet)
        local result = BY.results[BY.index]
        if not result then return end
        if not (D and KeyString(D.result.itemKey) == KeyString(result.itemKey)) then
            if D then BY.CloseItem() end
            BY.OpenItem()
        end
        BY.detailFocus = D ~= nil
        return BY.Render()
    elseif name == "LS" then
        if not Selectable(ENTRIES[BY.filterRow]) then
            BY.filterRow = 0
            MoveFilterFocus(1)
        end
        filterBox:Show()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    elseif name == "B" then
        if AH.CloseAuctionHouse then AH.CloseAuctionHouse() end
        return
    end
    BY.Render()
end

-- The mouse's press (a button, a hold box held) as the pad's: down,
-- then up (Circle on its release, a hold let go there)
function BY.MouseDown(name)
    if name ~= "B" then BY.Press(name) end
end

function BY.MouseUp(name)
    if name == "B" then return BY.Press("B") end
    if IF.AuctionConfirm.IsShown() then return end
    if D and D.holdStart then return BY.DetailRelease(name) end
    local page = CurrentPage()
    if page and page.Release then page.Release(name) end
end

-- The close button: the auction house closed (ours goes with it)
win.onClose = function()
    if AH.CloseAuctionHouse then AH.CloseAuctionHouse() else win:Hide() end
end

IF.Input.OnChange(function()
    if win:IsShown() then BY.Render() end
end)

local catcher = K.NewFrame("Frame", nil, win)
catcher:SetAllPoints(win)

-- The left stick, up / down: the main category (held: again, steadily)
local stickY, stickNext = 0, nil
local stickX, sideHeld = 0, false
-- The right stick, up / down: the tab above / below (once a push)
local rightY, rightHeld = 0, false
local function Stick(now)
    if filterBox:IsShown() then
        stickNext = nil
        return
    end
    local dir = stickY > STICK_ON and -1 or stickY < -STICK_ON and 1 or 0
    if dir == 0 then
        if math.abs(stickY) < STICK_OFF then stickNext = nil end
        return
    end
    if stickNext and now < stickNext then return end
    stickNext = now + (stickNext and REPEAT_EVERY * 2 or REPEAT_DELAY)
    BY.SetMain(BY.main + dir)
end

-- R3: a click turns the tooltip over (on its release), held the item in
-- front opens the Wiki (Wiki.lua)
local rsHold                   -- { start, item, done }
local wikiPress = {}        -- buttons pressed while the Wiki was up
local function WikiHold(now)
    if not rsHold or rsHold.done then return end
    local p = IF.Wiki.HoldProgress(rsHold.start)
    if not p then return end
    if p < 1 then return IF.Wiki.HoldShow(p, win) end
    rsHold.done = true
    IF.Wiki.HoldHide(true)
    IF.Wiki.Open(rsHold.item, "auction")
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        -- (the Wiki with the pad: the press is its, the release too; the
        -- Wiki up at all: L2 / R2 are its, the pad's way back to it)
        local wiki = IF.Wiki and IF.Wiki.HasFocus
        if wiki and (IF.Wiki.HasFocus()
            or IF.Wiki.IsShown() and (button == "PADLTRIGGER" or button == "PADRTRIGGER")) then
            wikiPress[button] = true
            return
        end
        -- Circle on its release: on the press the release reaches the game's
        -- own window, which closes
        if not name or name == "B" then return end
        if name == "RS" and IF.Wiki and IF.Wiki.Settings().enabled and not IF.AuctionConfirm.IsShown() then
            local item = BY.FocusedItem()
            rsHold = { start = GetTime(), item = item, done = item == nil }
            if item then return end
        end
        BY.Press(name)
        if REPEATS[name] then BY.held = { name = name, at = GetTime(), next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "RS" and rsHold then
            -- (let go before the Wiki: the click's)
            local short = not rsHold.done
            rsHold = nil
            if short then
                IF.Wiki.HoldHide()
                BY.Press("RS")
            end
            return
        end
        -- (a press the Wiki had: its release too, though it has closed)
        if wikiPress[button] or (IF.Wiki and IF.Wiki.HasFocus and IF.Wiki.HasFocus()) then
            wikiPress[button] = nil
            return
        end
        if name == "B" then return BY.Press("B") end
        if BY.held and BY.held.name == name then BY.held = nil end
        -- (a hold let go: the item's screen's, or a page's)
        if not name or IF.AuctionConfirm.IsShown() then return end
        if D and D.holdStart then return BY.DetailRelease(name) end
        local page = CurrentPage()
        if page and page.Release then page.Release(name) end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
end
if catcher.EnableGamePadStick then
    catcher:SetScript("OnGamePadStick", function(_, stick, x, y)
        if stick == "Left" or stick == "Movement" then stickY, stickX = y or 0, x or 0 end
        if stick == "Right" or stick == "Camera" then rightY = y or 0 end
    end)
end

win:SetScript("OnUpdate", function()
    local now = GetTime()
    -- (its own focus glow while it has the pad, as the game's windows: not
    -- while the Wiki or the confirmation over it has it)
    local wiki = IF.Wiki and IF.Wiki.HasFocus and IF.Wiki.HasFocus()
    -- (a scene has no window to outline: the cursor shows where the pad is)
    IF.Focus.Glow(win, false)
    WikiHold(now)
    -- (the Wiki with the pad: its sticks too)
    if IF.Wiki and IF.Wiki.HasFocus and IF.Wiki.HasFocus() then return end
    if not rightHeld and math.abs(rightY) > STICK_ON then
        rightHeld = true
        BY.StepTab(rightY > 0 and -1 or 1)
    elseif rightHeld and math.abs(rightY) < STICK_OFF then
        rightHeld = false
    end
    if BY.tab == "buy" then
        Stick(now)
        Prefetch(now)
        Preview(now)
    else
        local page = CurrentPage()
        if page and page.Update then page.Update(now) end
        -- The left stick, left / right: a page's lists (its StickSide), once
        -- a tilt
        if page and page.StickSide and not IF.AuctionConfirm.IsShown() then
            local side = stickX > STICK_ON and 1 or stickX < -STICK_ON and -1 or 0
            if side ~= 0 and not sideHeld and math.abs(stickX) > math.abs(stickY) then
                sideHeld = true
                page.StickSide(side)
            elseif math.abs(stickX) < STICK_OFF then
                sideHeld = false
            end
        end
        -- The left stick, up / down: a page's own list (its StickStep)
        if page and page.StickStep and not IF.AuctionConfirm.IsShown() then
            local dir = math.abs(stickY) < math.abs(stickX) and 0
                or stickY > STICK_ON and -1 or stickY < -STICK_ON and 1 or 0
            if dir == 0 then
                if math.abs(stickY) < STICK_OFF then stickNext = nil end
            elseif not stickNext or now >= stickNext then
                stickNext = now + (stickNext and REPEAT_EVERY * 2 or REPEAT_DELAY)
                page.StickStep(dir)
            end
        end
    end
    local held = BY.held
    if held and now >= held.next then
        held.next = now + REPEAT_EVERY
        BY.Press(held.name, now - held.at > FAST_AFTER)
    end
    -- A commodity's price, held for a short while
    if D and D.state == "confirm" and not D.holdStart and AH.GetQuoteDurationRemaining
        and AH.GetQuoteDurationRemaining() == 0 then
        D.state, D.quote, D.message = nil, nil, nil
        BY.Render()
    end
    -- The list's refresh not come after a buy: the item looked up anyway
    if D and D.afterBrowse and now - D.afterBrowse > 5 then BY.AfterBrowse() end
    -- A buy never answered: given up, its auctions looked up again
    if D and D.state == "buying" and now - (D.buyingAt or now) > BUY_TIMEOUT then
        D.state = nil
        BY.SearchItem()
        D.message = "No answer from the auction house: check your bags and try again"
    end
    -- A hold under way (the item's screen, or a page's): its bar, its feel
    local progress
    if D and D.holdStart then
        progress = BY.HoldProgress(D.holdStart)
        V.hold:SetHold(progress, "A", "Buy", HoldPrice())
    else
        local page = CurrentPage()
        if page and page.HoldProgress then progress = page.HoldProgress() end
    end
    BY.HoldFeel(progress)
end)

local function TakePad(on)
    if IF.InCombat() then return end
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(on and true or false) end
    -- (both sticks: the camera and the character stay still)
    if catcher.EnableGamePadStick then catcher:EnableGamePadStick(on and true or false) end
end

---------------------------------------------------------------------------
-- Showing, hiding
---------------------------------------------------------------------------
-- The game's own window stays hidden (not closed: that would close the
-- auction house) while ours is up, its cursor too
local pointer
local function SyncNative()
    local ah = _G.AuctionHouseFrame
    if ah then ah:SetAlpha(win:IsShown() and A.IsOpen() and 0 or 1) end
    local nav = _G.SmartNavigation
    if win:IsShown() then
        if nav and nav.Pointer and not pointer then
            pointer = nav.Pointer
            pointer:SetAlpha(0)
        end
    elseif pointer then
        pointer:SetAlpha(1)
        pointer = nil
    end
end

function BY.Show()
    if IF.InCombat() or not A.Available() or not A.IsOpen() then return end
    if #Mains() == 0 then return end
    -- The scene in (the bars, the HUD out), the window in the screen's
    -- middle under the header (the auctioneer's), fading in
    SC.Enter()
    ApplyScene()
    win:Show()
    SC.FadeIn(win, 0.4, 0.15)
    TakePad(true)
    SyncNative()
    local page = CurrentPage()
    if page then
        if not page.frame then page.frame = page.Build(pageHost) end
        page.Show()
    end
    if #BY.results == 0 and not BY.searching then BY.Query() end
    BY.Render()
end

function BY.Hide()
    win:Hide()
end

win:SetScript("OnHide", function()
    -- (the scene out: at once in a fight)
    SC.Leave(IF.InCombat())
    TakePad(false)
    BY.HoldFeel(nil)
    BY.held, stickY, stickNext, rightY, rightHeld = nil, 0, nil, 0, false
    stickX, sideHeld = 0, false
    filterBox:Hide()
    if D then BY.CloseItem() end
    local page = CurrentPage()
    if page and page.frame then page.Hide() end
    if GameTooltip:GetOwner() == win then GameTooltip:Hide() end
    IF.AuctionConfirm.Hide()
    SyncNative()
end)

IF.Upgrades.OnChange(function()
    if not win:IsShown() then return end
    BY.FilterResults()
    BY.Render()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE", "ITEM_KEY_ITEM_INFO_RECEIVED",
    "GET_ITEM_INFO_RECEIVED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE",
    "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        BY.results = {}
        -- (after the game's own window has settled, and its own first query)
        C_Timer.After(0.4, function()
            if IF.db and S().buy then BY.Show() end
        end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        -- (listings change: looked up again next visit)
        wipe(prefetched)
        wipe(versionCache)
        wipe(boughtIDs)
        win:Hide()
        SyncNative()
    elseif not win:IsShown() then
        return
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        ResultsIn()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        BY.searching = false
        BY.AfterBrowse()
        BY.Render()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- (many at once: worked out once, a moment later)
        if not BY.versionsQueued then
            BY.versionsQueued = true
            C_Timer.After(0.2, function()
                BY.versionsQueued = false
                VersionsLoaded()
            end)
        end
    elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        if pendingOpen and pendingOpen.result.itemKey.itemID == ... then
            local p = pendingOpen
            pendingOpen = nil
            Open(p.result, p.qty)
        end
        BY.Render()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if BY.queryWaiting then SendQuery() end
        if D and D.message == BUSY then
            D.message = nil
            BY.Render()
        end
    elseif event == "COMMODITY_PRICE_UPDATED" then
        if D and D.state == "quote" then
            local unit, total = ...
            D.state, D.quote, D.message = "confirm", { unit = unit, total = total }, nil
            -- (dearer than it looked: said before the release)
            local expected = Cost(D.qty)
            if expected and total > expected then
                D.message = "|cffff7a5cThe price went up by " .. A.Money(total - expected) .. "|r"
            end
            BY.Render()
        end
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" or event == "COMMODITY_PURCHASE_FAILED" then
        if D then
            D.state, D.quote, D.message = nil, nil, "Couldn't buy: the price changed or they're gone"
            BY.SearchItem()
            D.message = "Couldn't buy: the price changed or they're gone"
        end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if D then Bought(D.qty .. " × " .. (D.info.itemName or "item")) end
        BY.Query(true)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        local auctionID = ...
        if auctionID then boughtIDs[auctionID] = true end
        if D and D.state == "buying" then Bought(D.info.itemName or "item") end
        BY.Query(true)
    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        -- (the server's queue full: what was sent never goes; said, hold again)
        if D and D.state == "buying" then
            D.state, D.message = nil, BUSY
            BY.Render()
        end
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if D and D.state == "buying" then
            D.state, D.message = nil, "Couldn't buy it"
            BY.Render()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        SC.Leave(true)
        win:Hide()
    end
end)
