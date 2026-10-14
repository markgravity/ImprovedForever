-- The auction house window: over the game's own as it opens (where it
-- is; the game's window hidden behind it), used with the pad. Its pages
-- are tabs down its right, as the character window's (the right stick
-- up / down):
-- Buy (this file), Sell (AuctionSellTab.lua), Auctions (AuctionOwned.lua).
-- Buy: three levels of category (the game's own, AuctionCategories): the
-- main ones down the left (the left stick up / down), the second along
-- the top (L1 / R1), the third under it (L2 / R2), "All" first in each.
-- Under them what is listed, as a list (the D-pad moves), each
-- with its lowest price and how it compares to its usual one
-- (Auction.lua); the picked one's tooltip beside the window, with the
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
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local A = IF.Auction
local AH = C_AuctionHouse

local BY = {}
IF.AuctionBuy = BY

local W, H = 920, 600
local SIDE_W = 190
local MAIN_X = SIDE_W + 28            -- the main area's left
local MAIN_W = W - MAIN_X - 16
local CONTENT_TOP = -116
local CONTENT_H = H - 116 - 36
local LIST_H = 50                  -- a row: its name, a line of badges under it, inside the ring
local LIST_ROWS = math.floor(CONTENT_H / LIST_H)
local NAME_ROOM = MAIN_W - 50 - 200     -- a list row's name (the price on the right)
-- The list view: the item's screen beside the list (a preview of the
-- picked one; Cross goes into it), the list the rest
local PREVIEW_W = 360
local SIDE_LIST_W = MAIN_W - PREVIEW_W - 10
local PREVIEW_AFTER = 0.3          -- resting on an item this long: its screen beside the list
local SIDE_ROWS = 16
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

-- The pages, one at a time, picked with the tabs down the window's right
-- (the right stick up / down): Buy (this file's), Sell (AuctionSellTab.lua), Auctions
-- (AuctionOwned.lua). A page of another file: BY.AddPage(page), page = {
-- key, label, icon, Build(parent) -> frame, Show(), Hide(), Render(),
-- Press(name, fast) -> handled (Circle unhandled: the auction house
-- closes), Hints() -> the legend's text }.
local buyPage = K.NewFrame("Frame", nil, win)
buyPage:SetAllPoints(win)
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
    -- Alt + click, the Library; Binds.lua)
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
local side = Panel(buyPage, 0.4)
side:SetPoint("TOPLEFT", 14, -30)
side:SetPoint("BOTTOMLEFT", 14, 36)
side:SetWidth(SIDE_W)
local sideTitle = K.ChatText(side, 12, KC.dimGold)
sideTitle:SetPoint("TOP", 0, -10)
local sideRows = {}
for i = 1, SIDE_ROWS do
    local r = K.NewFrame("Button", nil, side)
    r:SetSize(SIDE_W - 16, 28)
    r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 30)
    r.focus = FocusStroke(r)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.text:SetPoint("LEFT", 10, 0)
    r.text:SetPoint("RIGHT", -6, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.index then BY.SetMain(self.index) end
    end)
    sideRows[i] = r
end

---------------------------------------------------------------------------
-- The second and third levels, along the top: a bar each, its bumper /
-- trigger glyphs at the ends, the chosen one lit and kept in view
---------------------------------------------------------------------------
local function TopBar(y, leftKey, rightKey, onClick)
    local bar = IF.UI.ChipBar(buyPage, leftKey, rightKey, onClick)
    bar:SetPoint("TOPLEFT", MAIN_X, y)
    bar:SetWidth(MAIN_W)
    return bar
end

local bar2 = TopBar(-30, "LB", "RB", function(i) BY.SetSub(i) end)
local bar3 = TopBar(-68, "LT", "RT", function(i) BY.SetSubSub(i) end)

---------------------------------------------------------------------------
-- The status line, the content (the list), the legend
---------------------------------------------------------------------------
local status = K.ChatText(buyPage, 11, KC.help)
status:SetPoint("TOPLEFT", MAIN_X + 4, -106 + 6)
status:SetPoint("RIGHT", win, "RIGHT", -20, 0)
status:SetJustifyH("LEFT")

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

-- The browse list's rows
local listRows = {}
for i = 1, LIST_ROWS do
    local r = ItemRow(content, SIDE_LIST_W, LIST_H - 4, NAME_ROOM)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * LIST_H)
    r:SetScript("OnClick", function(self)
        if self.index then
            BY.index = self.index
            BY.Render()
        end
    end)
    listRows[i] = r
end

local legend = IF.UI.Legend(win)

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
filterBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -4)
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

local detail = Panel(buyPage, 0.97)
detail:SetFrameLevel(win:GetFrameLevel() + 20)
detail:SetAllPoints(content)
detail:Hide()

-- Gone into (beside the list): the rows' focus ring round it, faint
local dGlow = FocusStroke(detail)

local dIcon = ItemIcon(detail, 40)
dIcon:SetPoint("TOPLEFT", 16, -14)
local dUpgrade = IF.Upgrades.Arrow(detail, "BOTTOMRIGHT", dIcon, "BOTTOMRIGHT", 2, -2)
local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 10, -2)
dName:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
dName:SetJustifyH("LEFT")
dName:SetWordWrap(false)
local dSub = K.ChatText(detail, 11, KC.help)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 10, 2)

-- One column, as the Sell tab's: the chart across, the lowest and usual
-- prices under it; then the quantity (commodities) or the auctions one by
-- one (items); "Hold to Buy" with what it costs. Every part spans the screen, so
-- it fits any width (the Buy tab's main area, the Tasks tab's column).
local dChart = IF.AuctionChart.New(detail, "Pay")
dChart:SetPoint("TOPLEFT", 10, -66)
dChart:SetPoint("TOPRIGHT", -10, -66)
dChart:SetHeight(140)
local dInfo = K.ChatText(detail, 12, KC.cream2)
dInfo:SetPoint("TOPLEFT", dChart, "BOTTOMLEFT", 0, -8)
dInfo:SetPoint("TOPRIGHT", dChart, "BOTTOMRIGHT", 0, -8)
dInfo:SetJustifyH("CENTER")

-- The middle: the auctions (items), or the quantity and its cost (commodities)
local AUCTION_ROWS = 8                 -- made; as many shown as fit
local AUCTION_H = 44
-- (a short screen, beside the list: a shorter chart, more auctions)
local function ChartHeight()
    return detail:GetHeight() >= 520 and 140 or 80
end
local ROW_NAME_W = 430 - 28 - 50 - 110
-- (as the browse list's rows: each auction its own name, stats' badges)
local dRows = {}
for i = 1, AUCTION_ROWS do
    local r = ItemRow(detail, 100, AUCTION_H - 4, ROW_NAME_W)
    -- (a line's room above the rows for the "more above" mark)
    r:SetPoint("TOPLEFT", dInfo, "BOTTOMLEFT", 4, -22 - (i - 1) * AUCTION_H)
    r:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    dRows[i] = r
end
-- More auctions above / below those shown: the game's expand arrow turned
-- up / down, above the first row / under the last, how many beside it
local function MoreMark()
    local m = K.NewFrame("Frame", nil, detail)
    m:SetSize(60, 16)
    m:SetFrameLevel(detail:GetFrameLevel() + 10)
    m.arrow = m:CreateTexture(nil, "OVERLAY")
    m.arrow:SetSize(16, 16)
    m.arrow:SetPoint("LEFT")
    m.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    m.arrow:SetVertexColor(1, 0.82, 0)
    m.text = K.ChatText(m, 11, KC.dimGold)
    m.text:SetPoint("LEFT", m.arrow, "RIGHT", 2, 0)
    m:Hide()
    return m
end
local dMoreUp, dMoreDown = MoreMark(), MoreMark()
local HoldPrice
dMoreUp.arrow:SetRotation(math.pi / 2)
dMoreDown.arrow:SetRotation(-math.pi / 2)

-- A commodity's quantity: big, centred up and down between the prices
-- and the hold box; its steps in the legend
local dQtyMid = K.NewFrame("Frame", nil, detail)
dQtyMid:SetPoint("TOPLEFT", dInfo, "BOTTOMLEFT", 0, 0)
dQtyMid:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
local dQtyGroup = K.NewFrame("Frame", nil, dQtyMid)
dQtyGroup:SetPoint("LEFT")
dQtyGroup:SetPoint("RIGHT")
dQtyGroup:SetHeight(30)
local dQty = K.Text(dQtyGroup, 30, KC.title)
dQty:SetPoint("TOP", 0, 0)
local dQtyLeft = K.Text(dQtyGroup, 30, KC.focus)
dQtyLeft:SetPoint("RIGHT", dQty, "LEFT", -14, 0)
dQtyLeft:SetText("‹")
local dQtyRight = K.Text(dQtyGroup, 30, KC.focus)
dQtyRight:SetPoint("LEFT", dQty, "RIGHT", 14, 0)
dQtyRight:SetText("›")
local dQtyLabel = K.ChatText(dQtyGroup, 16, KC.dimGold)
dQtyLabel:SetPoint("TOP", dQty, "BOTTOM", 0, -8)

local dHold = BY.HoldBox(detail)
dHold:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, 12)
dHold:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -14, 12)
local dStatus = K.ChatText(detail, 12, KC.warn)
dStatus:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, 52)
dStatus:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -14, 52)
dStatus:SetJustifyH("CENTER")
dQtyMid:SetPoint("BOTTOM", dHold, "TOP", 0, 24)
dQtyGroup:SetPoint("CENTER")

-- With the mouse: the arrows clicked, the quantity typed, the auctions
-- looked up again with a button
local D, DetailPress
local dQtyEdit = BY.NumberBox(dQtyGroup, 80, function(n)
    if not D then return end
    local avail = 0
    for _, l in ipairs(D.listings or {}) do avail = avail + l.count - (l.own or 0) end
    D.qty = math.max(1, math.min(math.max(1, avail), n))
    D.state, D.quote, D.message = nil, nil, nil
    BY.Render()
end)
dQtyEdit:SetPoint("CENTER", dQty, "CENTER", 0, 0)
local dQtyLeftButton = BY.ArrowButton(dQtyGroup, dQtyLeft, function(fast) DetailPress("LEFT", fast) end)
local dQtyRightButton = BY.ArrowButton(dQtyGroup, dQtyRight, function(fast) DetailPress("RIGHT", fast) end)
local dRefresh = BY.Button(detail, "Refresh", function() BY.SearchItem() end, 80)
dRefresh:SetPoint("TOPRIGHT", -12, -12)
dRefresh:Hide()

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

local function ResultsIn()
    BY.allResults = AH.GetBrowseResults() or {}
    BY.FilterResults()
    BY.searching = false
    -- Only upgrades, and few among what came: the rest asked for
    if S().buyUpgrades == "only" and #BY.results < LIST_ROWS and AH.HasFullBrowseResults
        and not AH.HasFullBrowseResults() then
        AH.RequestMoreBrowseResults()
        A.lastQuery = "browse"
    end
    BY.AfterBrowse()
    BY.Render()
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

-- Where tooltips go: under the tabs down the window's right
local sideTabs                   -- (the tabs, made below)
function BY.PlaceTip()
    GameTooltip:ClearAllPoints()
    local last = sideTabs and sideTabs:Last(#BY.TABS)
    if last and last:IsShown() then
        GameTooltip:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -12)
    else
        GameTooltip:SetPoint("TOPLEFT", win, "TOPRIGHT", 52, 0)
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
    detail:SetPoint("TOPLEFT", content, "TOPLEFT", SIDE_LIST_W + 10, 0)
    detail:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
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
        BY.top = math.max(1, math.min(math.max(1, n - LIST_ROWS + 1), BY.top + dir))
        MoreIfNeeded(BY.top + LIST_ROWS - 1)
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
    for _, r in ipairs(dRows) do screens[#screens + 1] = r end
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
    for _, r in ipairs(dRows) do
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
    dHold.onDown = function()
        if filterBox:IsShown() then CloseFilters() end
        if detail:GetParent() == buyPage then BY.detailFocus = true end
        BY.MouseDown("A")
    end
    dHold.onUp = function() BY.MouseUp("A") end

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
    sideTitle:SetText(Mouse() and "" or (Glyph("LS", 18) .. " Category"))
    BY.searchBox:SetShown(Mouse())
    local top = math.max(1, math.min(BY.main - math.floor(SIDE_ROWS / 2), #mains - SIDE_ROWS + 1))
    local fr, fg, fb = FocusColor()
    for i, r in ipairs(sideRows) do
        local index = top + i - 1
        local cat = mains[index]
        r:SetShown(cat ~= nil)
        if cat then
            r.index = index
            local on = index == BY.main
            r.text:SetText(cat.name)
            r.text:SetTextColor(on and 1 or 0.8, on and 0.95 or 0.74, on and 0.8 or 0.6)
            r.focus:SetShown(on)
            r.focus:SetVertexColor(fr, fg, fb)
        end
    end
end

local function RenderResults()
    local results = BY.results
    local n = #results
    local per = LIST_ROWS
    BY.index = math.max(1, math.min(BY.index, math.max(1, n)))
    -- Scrolled keeping the picked one in view (unless the wheel scrolled it)
    if not BY.freeTop then
        if BY.index < BY.top then BY.top = BY.index end
        if BY.index > BY.top + per - 1 then BY.top = BY.index - per + 1 end
    end
    BY.top = math.max(1, math.min(BY.top, math.max(1, n - per + 1)))
    emptyText:SetShown(n == 0)
    emptyText:SetText(BY.searching and "Searching..." or "Nothing listed here")
    local fr, fg, fb = FocusColor()
    for _, r in ipairs(listRows) do r:Hide() end
    for i, f in ipairs(listRows) do
        local index = BY.top + i - 1
        local result = results[index]
        if result then
            f.index = index
            local info = KeyInfo(result)
            local price = result.minPrice
            local upgrade, gain, needLevel = BY.GroupUpgrade(result.itemKey)
            local gainText, gainColor = GainBadge(upgrade, gain, needLevel)
            local dealText, dealColor = DealBadge(result.itemKey.itemID, price)
            local priceText = price and price > 0 and A.Money(price) or "bid only"
            f:Fill({
                icon = info and info.iconFileID, quality = info and info.quality,
                name = info and info.itemName or "...", price = priceText, upgrade = upgrade,
                line = result.totalQuantity .. " available"
                    .. (result.itemKey.itemLevel and result.itemKey.itemLevel > 0 and info and info.isEquipment
                        and ("  ·  item level " .. result.itemKey.itemLevel) or ""),
                gain = gainText and { gainText, gainColor }, deal = dealText and { dealText, dealColor },
            })
            -- (dimmed only under the filters: the item's screen gone into
            -- keeps its row bright)
            f.focus:SetShown(index == BY.index)
            f.focus:SetVertexColor(fr, fg, fb)
            f.focus:SetAlpha(filterBox:IsShown() and 0.4 or 1)
            f:Show()
        end
    end
    local main, sub, subsub = Chosen()
    local path = (main and main.name or "") .. (sub and (" › " .. sub.name) or "") .. (subsub and (" › " .. subsub.name) or "")
    local s = S()
    local active = {}
    if s.buyUsable then active[#active + 1] = "usable" end
    local qualities = {}
    for q = 0, 5 do
        if s.buyQualities[q] then qualities[#qualities + 1] = QUALITY_NAMES[q]:lower() end
    end
    if #qualities > 0 then active[#active + 1] = table.concat(qualities, " / ") end
    if s.buyMyLevel then active[#active + 1] = "up to my level" end
    if s.buyUpgrades == "only" then active[#active + 1] = "upgrades only" end
    if BY.search and BY.search ~= "" then path = path .. "   ·   |cffd8ccb0\"" .. BY.search .. "\"|r" end
    status:SetText(path .. "   ·   " .. (BY.searching and "searching..." or (n .. " found"))
        .. (#active > 0 and ("   ·   |cffc9a25a" .. table.concat(active, ", ") .. "|r") or ""))
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

local function RenderDetail()
    if not D then return end
    dChart:SetHeight(ChartHeight())
    -- (gone into on the Buy tab: the faint focus frame)
    dGlow:SetShown(BY.detailFocus and detail:GetParent() == buyPage)
    dGlow:SetVertexColor(FocusColor())
    dGlow:SetAlpha(0.5)
    local info = D.info
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
    dIcon:SetTexture(info.iconFileID or 134400)
    dIcon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
    dName:SetText(info.itemName)
    dUpgrade:SetShown(BY.GroupUpgrade(D.result.itemKey) and true or false)
    dName:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    local available = Available()
    dSub:SetText(D.searching and "Searching..." or (available .. " for sale"))
    local lowest = D.listings[1] and D.listings[1].unit
    local pay
    if D.commodity then
        local total = Cost(D.qty)
        pay = total and total / D.qty
    else
        local a = Auctions()[D.row]
        pay = a and a.unit
    end
    dChart:Draw({ itemID = D.itemID, lowestNow = lowest, price = pay, searching = D.searching })
    local usual = A.MarketPrice(D.itemID)
    local parts = {}
    if lowest then parts[#parts + 1] = "Lowest now " .. A.Money(lowest) end
    if usual then parts[#parts + 1] = "usually " .. A.Money(usual) end
    dInfo:SetText(table.concat(parts, "   ·   "))

    local fr, fg, fb = FocusColor()
    if D.commodity then
        for _, r in ipairs(dRows) do r:Hide() end
        dQtyMid:Show()
        dMoreUp:Hide()
        dMoreDown:Hide()
        dQty:SetText(D.qty .. "|cff9d917a/" .. available .. "|r")
        local fr, fg, fb = FocusColor()
        dQtyLeft:SetTextColor(fr, fg, fb)
        dQtyRight:SetTextColor(fr, fg, fb)
        dQtyLabel:SetText("")
        -- (with the mouse: typed, its arrows clicked)
        local mouse = Mouse()
        dQty:SetAlpha(mouse and 0 or 1)
        dQtyEdit:SetShown(mouse)
        if mouse then
            if not dQtyEdit:HasFocus() then dQtyEdit:SetText(D.qty) end
            dQtyLabel:SetText("of " .. available .. "  |cff9d917a(Shift: by 10)|r")
        end
        dQtyLeftButton:SetShown(mouse)
        dQtyRightButton:SetShown(mouse)
    else
        dQtyMid:Hide()
        dQtyEdit:Hide()
        local auctions = Auctions()
        D.row = math.max(1, math.min(D.row, math.max(1, #auctions)))
        -- (as many rows as fit between the prices and the hold box)
        -- (from under the prices' line, its "more above" line kept, down to
        -- the hold box, a message's line kept only when there is one, and
        -- the "more below" line)
        local bottom = 12 + 34 + 6 + ((D.message and D.message ~= "") and 16 or 0) + 16
        local infoBottom, detailBottom = dInfo:GetBottom(), detail:GetBottom()
        local room
        if infoBottom and detailBottom then
            room = infoBottom - 22 - detailBottom - bottom
        else
            room = detail:GetHeight() - (66 + ChartHeight() + 30) - bottom - 22
        end
        -- (the last row needs no gap under it)
        local fit = math.max(1, math.min(AUCTION_ROWS, math.floor((room + 4) / AUCTION_H)))
        local top = math.max(1, D.row - fit + 1)
        -- (more above / below: marked above the first row / under the last)
        local shownN = math.min(fit, #auctions - top + 1)
        dMoreUp:SetShown(top > 1)
        if top > 1 then
            dMoreUp:ClearAllPoints()
            dMoreUp:SetPoint("BOTTOM", dRows[1], "TOP", 0, 1)
            dMoreUp.text:SetText(top - 1 .. " more")
        end
        local below = #auctions - (top + shownN - 1)
        dMoreDown:SetShown(below > 0 and shownN > 0)
        if below > 0 and shownN > 0 then
            dMoreDown:ClearAllPoints()
            dMoreDown:SetPoint("TOP", dRows[shownN], "BOTTOM", 0, -2)
            dMoreDown.text:SetText(below .. " more")
        end
        for i, r in ipairs(dRows) do
            local a = i <= fit and auctions[top + i - 1]
            r:SetShown(a and true or false)
            r.index = a and top + i - 1 or nil
            if a then
                local on = top + i - 1 == D.row
                local upgrade = S().buyUpgrades ~= "off" and a.link and IF.Upgrades.IsUpgrade(a.link, nil, nil, true)
                    and true or false
                local gain, needLevel
                if upgrade then gain, needLevel = IF.Upgrades.Gain(a.link, nil, nil, true) end
                local gainText, gainColor = GainBadge(upgrade, gain, needLevel)
                local dealText, dealColor = DealBadge(D.itemID, a.unit)
                local parts = {}
                if a.count > 1 then parts[#parts + 1] = a.count .. " ×  " .. A.Money(a.unit) .. " each" end
                if a.itemLevel and a.itemLevel > 0 and info.isEquipment then
                    parts[#parts + 1] = "item level " .. a.itemLevel
                end
                r:Fill({
                    icon = info.iconFileID, quality = info.quality,
                    -- (its own name: a random suffix's "of the Owl")
                    name = a.link and a.link:match("%[(.-)%]") or info.itemName,
                    line = table.concat(parts, "  ·  "), price = A.Money(a.total or a.unit * a.count),
                    upgrade = upgrade,
                    gain = gainText and { gainText, gainColor }, deal = dealText and { dealText, dealColor },
                })
                -- (beside the list, not gone into: no pick shown; with the
                -- mouse it's clicked, always shown)
                r.focus:SetShown(on and (DetailActive() or Mouse()))
                r.focus:SetVertexColor(fr, fg, fb)
            end
        end
    end
    dStatus:SetText(D.message or "")
    dRefresh:SetShown(Mouse())
    dHold:SetHold(BY.HoldProgress(D.holdStart), "A", "Buy", HoldPrice())
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
-- The tabs down the window's right: the game's side tabs (as the
-- character window's), the right stick's glyph above them (up / down
-- moves through them)
---------------------------------------------------------------------------
local function CurrentPage()
    for _, t in ipairs(BY.TABS) do
        if t.key == BY.tab and t.key ~= "buy" then return t end
    end
end

sideTabs = IF.UI.SideTabs(win, function(key) BY.SetTab(key) end)

local function RenderTabs()
    sideTabs:Render(BY.TABS, BY.tab)
end

-- The legend: a page's buttons, then the right stick for the tabs (with
-- the mouse: no legend, as the game's mouse windows; the buttons, mouse,
-- in the window's bottom band instead, at its right; the Library by Alt +
-- click, as everywhere)
local mouseBar = K.NewFrame("Frame", nil, win)
mouseBar:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 6)
mouseBar:SetSize(1, 26)
mouseBar.buttons = {}

local function SetMouseBar(list)
    local x = 0
    for i, def in ipairs(list) do
        local b = mouseBar.buttons[i]
        if not b then
            b = BY.Button(mouseBar, "", function() end)
            b:SetHeight(26)
            b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
            mouseBar.buttons[i] = b
        end
        b.fn = def[2]
        b:SetText(def[1])
        b:SetWidth(math.max(96, b:GetFontString():GetStringWidth() + 28))
        b:ClearAllPoints()
        b:SetPoint("LEFT", mouseBar, "LEFT", x, 0)
        b:Show()
        x = x + b:GetWidth() + 8
    end
    for i = #list + 1, #mouseBar.buttons do mouseBar.buttons[i]:Hide() end
    mouseBar:SetWidth(math.max(1, x - 8))
end

local function SetHints(text, mouseList)
    local mouse = Mouse()
    legend:SetShown(not mouse)
    mouseBar:SetShown(mouse)
    if mouse then return SetMouseBar(mouseList or {}) end
    legend:SetText(text .. "   " .. Glyph("RS") .. " Tabs (tilt) / " .. (BY.TipsOff() and "Tooltip (click)" or "No tooltip (click)")
        .. ((IF.Library and IF.Library.Settings().enabled) and " / Hold to Open Library" or ""))
end

function BY.SetTab(key)
    if key == BY.tab then return end
    local old = CurrentPage()
    if old then old.Hide() else buyPage:Hide() end
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
    win:SetWidth(page and page.width or W)
    if page then
        if not page.frame then page.frame = page.Build(win) end
        page.Show()
    else
        buyPage:Show()
    end
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

-- The item in front (R3 held: its Library page, Library.lua): a page's own
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
    local names3 = Names(sub)
    if not sub then names3 = { "—" } end
    bar3:Render(names3, sub and BY.subsub or 1)
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
    local mouseList
    if filterBox:IsShown() then
        mouseList = { { "Done", function() BY.Press("LS") end } }
    else
        mouseList = { { "Filters", function() BY.Press("LS") end } }
    end
    SetHints(text, mouseList)
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
    local d = ({ UP = -1, DOWN = 1 })[name]
    if not d then return end
    if fast and (name == "UP" or name == "DOWN") then d = d * 5 end
    BY.index = math.max(1, math.min(n, BY.index + d))
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
    -- (left / right: nothing in the list)
    if name == "UP" or name == "DOWN" then
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
-- front opens the Library (Library.lua)
local rsHold                   -- { start, item, done }
local libraryPress = {}        -- buttons pressed while the Library was up
local function LibraryHold(now)
    if not rsHold or rsHold.done then return end
    local p = IF.Library.HoldProgress(rsHold.start)
    if not p then return end
    if p < 1 then return IF.Library.HoldShow(p, win) end
    rsHold.done = true
    IF.Library.HoldHide(true)
    IF.Library.Open(rsHold.item, "auction")
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        -- (the Library with the pad: the press is its, the release too; the
        -- Library up at all: L2 / R2 are its, the pad's way back to it)
        local library = IF.Library and IF.Library.HasFocus
        if library and (IF.Library.HasFocus()
            or IF.Library.IsShown() and (button == "PADLTRIGGER" or button == "PADRTRIGGER")) then
            libraryPress[button] = true
            return
        end
        -- Circle on its release: on the press the release reaches the game's
        -- own window, which closes
        if not name or name == "B" then return end
        if name == "RS" and IF.Library and IF.Library.Settings().enabled and not IF.AuctionConfirm.IsShown() then
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
            -- (let go before the Library: the click's)
            local short = not rsHold.done
            rsHold = nil
            if short then
                IF.Library.HoldHide()
                BY.Press("RS")
            end
            return
        end
        -- (a press the Library had: its release too, though it has closed)
        if libraryPress[button] or (IF.Library and IF.Library.HasFocus and IF.Library.HasFocus()) then
            libraryPress[button] = nil
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
    -- while the Library or the confirmation over it has it)
    local library = IF.Library and IF.Library.HasFocus and IF.Library.HasFocus()
    IF.Focus.Glow(win, not (library or IF.AuctionConfirm.IsShown()))
    LibraryHold(now)
    -- (the Library with the pad: its sticks too)
    if IF.Library and IF.Library.HasFocus and IF.Library.HasFocus() then return end
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
        dHold:SetHold(progress, "A", "Buy", HoldPrice())
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
    -- Where the game's own window is
    local native = _G.AuctionHouseFrame
    win:ClearAllPoints()
    if native and native:GetLeft() then
        win:SetPoint("TOPLEFT", native, "TOPLEFT")
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    win:SetWidth(CurrentPage() and CurrentPage().width or W)
    win:Show()
    TakePad(true)
    SyncNative()
    local page = CurrentPage()
    if page then
        if not page.frame then page.frame = page.Build(win) end
        page.Show()
    end
    if #BY.results == 0 and not BY.searching then BY.Query() end
    BY.Render()
end

function BY.Hide()
    win:Hide()
end

win:SetScript("OnHide", function()
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
        win:Hide()
    end
end)
