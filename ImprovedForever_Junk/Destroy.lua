-- Destroy (the Junk module's panel): with the bags open, R2 + R3 (or the
-- button(s) bound in the Bindings tab) opens a panel listing what is safe
-- to throw away; so does Triangle in the loot window once the bags are
-- full, where Cross swaps: the junk goes, the loot that didn't fit comes in
-- its place. What it lists: the junk, by the core's verdict (ImprovedForever's
-- ItemValue.lua: greys, the player's marks, gear the class can't use or has
-- outgrown, cheap white gear; never what sells better at the auction house,
-- a quest's item, an upgrade, a reagent of the character's professions);
-- with no junk, every white item a vendor would take, the least useful
-- first. Each card shows its auction worth when priced (Auction.lua). Laid
-- out as Forever's loot window: a list of item cards, the picked one's
-- tooltip beside it. Holding Cross until the picked card has filled, then
-- letting go, destroys it; holding Square and letting go destroys them all
-- (at a vendor: sells them all); R1 marks the picked one junk / not junk
-- (Junk.lua, remembered); Circle closes, R3 shows / hides the tooltip. From
-- the loot window Cross swaps and Triangle destroys only (both held); at a
-- vendor Triangle sells.
-- With the mouse: a key binding or /if destroy opens it (with the bags full,
-- a Destroy button under the loot window); a click picks a card, the wheel
-- scrolls, a card under the mouse shows its tooltip, and the game's buttons
-- under it do what the pad's do (held as they are held).
-- Never in combat.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C

local DS = {}
IF.Destroy = DS

local HOLD_ALL = 1.2          -- Square held this long, then let go: destroy all
local HOLD_ONE = 0.6          -- Cross (or Triangle) held this long, then let go: destroy the picked one
local DEFAULT_KEY = "PADRTRIGGER+PADRSTICK"   -- one button, or "held+pressed"

---------------------------------------------------------------------------
-- Finding what to throw away: the core's verdict (ItemValue.lua)
---------------------------------------------------------------------------
local IV = IF.ItemValue

local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end
end

local function Card(e)
    return {
        bag = e.bag, slot = e.slot, itemID = e.itemID, link = e.link, icon = e.icon, count = e.count,
        quality = e.quality or 0, value = e.value, ah = e.ah, reason = e.tag or "Junk", rank = e.rank,
        sellable = e.sellable, verdict = e.verdict, junk = e.verdict == "junk", why = e.why,
    }
end

-- The junk, the least useful first (the cheapest first in each); with no
-- junk at all, every white item a vendor would take (food and trade goods
-- too: never what sells better at the auction house, nor what's kept)
function DS.Scan()
    local list = {}
    for _, e in ipairs(IV.Bags(function(e) return e.verdict == "junk" end)) do list[#list + 1] = Card(e) end
    if #list == 0 then
        for _, e in ipairs(IV.Bags(function(e) return e.verdict == "vendor" and e.quality <= 1 end)) do
            list[#list + 1] = Card(e)
        end
    end
    for i = #list, 1, -1 do
        local info = SlotInfo(list[i].bag, list[i].slot)
        if not info or info.isLocked then table.remove(list, i) end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.value < b.value
    end)
    return list
end

---------------------------------------------------------------------------
-- Destroying (from a button press; never in combat)
---------------------------------------------------------------------------
local blocked = false

local function DestroyOne(entry)
    local info = SlotInfo(entry.bag, entry.slot)
    if not info or info.itemID ~= entry.itemID or info.isLocked then return false end
    ClearCursor()
    C_Container.PickupContainerItem(entry.bag, entry.slot)
    if not CursorHasItem() then return false end
    blocked = false
    DeleteCursorItem()
    if CursorHasItem() then ClearCursor() end
    return not blocked
end

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:SetScript("OnEvent", function(_, _, addon, fn)
    -- (named after the module whose code it is: ImprovedForever_Junk)
    if type(addon) == "string" and addon:find("^ImprovedForever") and tostring(fn):find("DeleteCursorItem") then
        blocked = true
    end
end)

---------------------------------------------------------------------------
-- The panel: Forever's loot window (its flat panel, item cards, rarity
-- tag, the gamepad focus glow and arrow) with a button legend under it
---------------------------------------------------------------------------
local ROWS, ROW_H, PANEL_W = 6, 48, 262

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedForeverDestroy", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedForeverDestroy", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(PANEL_W, 52 + ROWS * ROW_H)
panel:SetFrameStrata("DIALOG")
panel:SetPoint("CENTER")
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
DS.panel = panel

-- The game's close button in its corner, for the mouse (where its own
-- goes: UIPanelCloseButtonDefaultAnchors)
local madeClose, close = pcall(K.NewFrame, "Button", nil, panel, "UIPanelCloseButton")
if madeClose and close then
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 1, 0)
    close:SetFrameLevel(panel:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() DS.Close() end)
end
-- Where it sits: beside the window it was opened from (the loot window, else
-- the bags), again as they come and go (ImprovedForever's Focus.lua)
local function OpenedFrom()
    local loot = _G.LootFrame
    if DS.origin == "loot" and loot and loot:IsShown() then return { loot } end
    local frames = {}
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then frames[#frames + 1] = combined end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then frames[#frames + 1] = f end
    end
    return frames
end
IF.Focus.Dock(panel, { beside = OpenedFrom })

-- The focus colour of the game's controller options (GamepadFocusStateColor:
-- gold, black, blue), for the picked row
local function FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    local alpha = tonumber(get and get("GamepadFocusStateOpacity") or 1) or 1
    if value == 2 then return 0, 0, 0, alpha end
    if value == 3 then return 0.3, 0.5, 1, alpha end
    return 1, 0.9, 0.4, alpha
end


local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

-- The count and worth, along the panel's bottom
local summary = K.ChatText(panel, 11, KC.help)
summary:SetPoint("BOTTOM", panel, "BOTTOM", 0, 9)
summary:SetJustifyH("CENTER")

local more = { up = panel:CreateTexture(nil, "OVERLAY"), down = panel:CreateTexture(nil, "OVERLAY") }
-- (the game's scroll bar arrows, drawn the right way up)
for key, t in pairs(more) do
    t:SetSize(17, 11)
    if not Atlas(t, key == "up" and "minimal-scrollbar-arrow-top" or "minimal-scrollbar-arrow-bottom") then
        t:SetSize(20, 20)
        t:SetTexture("Interface\\AddOns\\ImprovedForever\\textures\\ic_tri")
        if key == "up" then t:SetTexCoord(0, 1, 1, 0) end
    end
    t:SetPoint(key == "up" and "TOP" or "BOTTOM", panel, key == "up" and "TOP" or "BOTTOM", 0, key == "up" and -26 or 24)
end

-- The rows: an item card each
local rows = {}
for i = 1, ROWS do
    local r = K.NewFrame("Button", nil, panel)
    r:SetSize(PANEL_W - 22, ROW_H - 4)
    r:SetPoint("TOPLEFT", 11, -26 - (i - 1) * ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if not Atlas(r.bg, "Looting_ItemCard_BG") then r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
    r.stroke = r:CreateTexture(nil, "BORDER")
    r.stroke:SetAllPoints()
    Atlas(r.stroke, "Looting_ItemCard_Stroke_Normal")
    -- Focused: the card's bright stroke, in the focus colour (as a bag slot's)
    r.focus = r:CreateTexture(nil, "OVERLAY")
    r.focus:SetAllPoints()
    if not Atlas(r.focus, "Looting_ItemCard_Stroke_ClickState") then r.focus:SetColorTexture(1, 0.8, 0.2, 0.25) end
    r.focusGlow = r:CreateTexture(nil, "OVERLAY", nil, 1)
    r.focusGlow:SetAllPoints()
    r.focusGlow:SetBlendMode("ADD")
    Atlas(r.focusGlow, "Looting_ItemCard_HighlightState")
    -- Cross held: the card fills from the left until it goes
    r.fill = r:CreateTexture(nil, "ARTWORK", nil, -1)
    r.fill:SetPoint("TOPLEFT")
    r.fill:SetPoint("BOTTOMLEFT")
    r.fill:SetColorTexture(0.85, 0.2, 0.1, 0.45)
    r.fill:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.iconBorder = r:CreateTexture(nil, "OVERLAY")
    r.iconBorder:SetPoint("TOPLEFT", r.icon, -1, 1)
    r.iconBorder:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
    r.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    r.iconBorder:SetBlendMode("ADD")
    r.iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
    r.tag = r:CreateTexture(nil, "BORDER", nil, 1)
    r.tag:SetSize(90, 12)
    r.tag:SetPoint("TOPRIGHT", 0, 0)
    Atlas(r.tag, "Looting_RarityTag_Frame")
    r.tagText = r:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny2")
    r.tagText:SetPoint("TOPRIGHT", -4, -1)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -4)
    r.name:SetPoint("RIGHT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.value = K.ChatText(r, 11, KC.help)
    r.value:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 3)
    -- The game's own focus cursor at its left (ImprovedForever's Focus.lua)
    r.cursor = IF.Focus.Cursor(r)
    -- (a right-click, with the mouse: marks it junk / not junk, as R1)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(_, button)
        DS.index = DS.top + i - 1
        DS.CancelPress()
        if button == "RightButton" and IF.Junk then
            DS.Press("MARK", true)
            DS.Press("MARK", false)
        end
        DS.Render()
    end)
    -- (the mouse over a card: its tooltip, the picked one's again after;
    -- never the pick itself, which the buttons act on)
    r:SetScript("OnEnter", function()
        if IF.Input.Pad() then return end
        DS.hover = DS.top + i - 1
        DS.Render()
    end)
    r:SetScript("OnLeave", function()
        if DS.hover == DS.top + i - 1 then
            DS.hover = nil
            DS.Render()
        end
    end)
    rows[i] = r
end

-- The button legend under the panel, as the game's own panels have; it
-- grows leftwards, clear of the bag window's own legend on the right
local legend = K.NewFrame("Frame", nil, panel, "BackdropTemplate")
legend:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -6)
legend:SetHeight(36)
legend:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
legend:SetBackdropColor(0.05, 0.04, 0.03, 0.92)
legend:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
local hints = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hints:SetPoint("CENTER")

local holdBar = legend:CreateTexture(nil, "OVERLAY")
holdBar:SetHeight(3)
holdBar:SetPoint("BOTTOMLEFT", 5, 4)
holdBar:Hide()

-- With the mouse: no legend (the game's mouse windows have none); the
-- game's buttons in the panel instead, over its summary (the panel taller
-- by their rows), pressed and let go as the pad's (a hold: held down);
-- made as they're needed
local MOUSE_ROW = 28
local mouseArea = K.NewFrame("Frame", nil, panel)
mouseArea:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 28)
mouseArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 28)
mouseArea:SetHeight(1)
local mouseButtons = {}
local function MouseButton(i)
    local b = mouseButtons[i]
    if b then return b end
    b = K.NewFrame("Button", nil, mouseArea, "UIPanelButtonTemplate")
    b:SetHeight(24)
    -- (the press it began as, whatever the legend shows by its release)
    b:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not self.press then return end
        self.down = self.press
        DS.Press(self.down, true)
    end)
    b:HookScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.down then return end
        local name = self.down
        self.down = nil
        DS.Press(name, false)
    end)
    mouseButtons[i] = b
    return b
end

-- list: { { press, text } }; laid out left to right, onto a new row where
-- they don't fit; the panel as tall as its rows need
local PANEL_H = 52 + ROWS * ROW_H
local function MouseLegend(list)
    local width = PANEL_W - 18
    local x, rowsUsed = 0, #list > 0 and 1 or 0
    local placed = {}
    for i, def in ipairs(list) do
        local b = MouseButton(i)
        b.press = def[1]
        b:SetText(def[2])
        b:SetWidth(math.min(width, math.max(64, b:GetFontString():GetStringWidth() + 24)))
        if x > 0 and x + b:GetWidth() > width then
            rowsUsed, x = rowsUsed + 1, 0
        end
        placed[i] = { b = b, x = x, row = rowsUsed }
        x = x + b:GetWidth() + 6
        b:Show()
    end
    -- (rows from the top one down, the last over the summary)
    for _, p in ipairs(placed) do
        p.b:ClearAllPoints()
        p.b:SetPoint("BOTTOMLEFT", mouseArea, "BOTTOMLEFT", p.x, (rowsUsed - p.row) * MOUSE_ROW)
    end
    for i = #list + 1, #mouseButtons do
        mouseButtons[i]:Hide()
        mouseButtons[i].down = nil
    end
    local extra = rowsUsed * MOUSE_ROW
    panel:SetHeight(PANEL_H + extra)
    more.down:SetPoint("BOTTOM", panel, "BOTTOM", 0, 24 + extra)
end

DS.items, DS.index, DS.top = {}, 1, 1

-- The held Cross (or Triangle): which, on what, since when
local function ShowFill(p)
    for i, r in ipairs(rows) do
        local on = p and DS.top + i - 1 == DS.index
        r.fill:SetShown(on or false)
        if on then
            r.fill:SetWidth(math.max(1, r:GetWidth() * math.min(1, p)))
            -- (full: brighter, let go now)
            r.fill:SetColorTexture(p >= 1 and 1 or 0.85, p >= 1 and 0.35 or 0.2, 0.1, p >= 1 and 0.6 or 0.45)
        end
    end
end

-- Still the item the press began on (the list is rebuilt as the bags change)
local function Pressed()
    local e, p = DS.items[DS.index], DS.pressEntry
    return e and p and e.bag == p.bag and e.slot == p.slot and e.itemID == p.itemID and e or nil
end

-- The feel of a hold, every update: a rumble rising with it, both grips
-- full once full (Vibration.lua, when loaded); nil: none under way
local vibing = false
local function HoldFeel(p)
    if not IF.Vibe then return end
    if p then
        IF.Vibe.Hold(p)
        vibing = true
    elseif vibing then
        IF.Vibe.Hold(nil)
        vibing = false
    end
end

-- A hold let go full: the confirm thump
local function HoldDone()
    vibing = false
    if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
end

function DS.CancelPress()
    DS.pressStart, DS.pressBy, DS.pressEntry = nil, nil, nil
    ShowFill(nil)
end

local Money = IV.Money

local function Glyph(key)
    return IF.GlyphText(key, 24)
end

-- The tooltip shows as the bag window's does: the game's own setting
-- (CVar GamepadDisableTooltips), which R3 turns on and off in both
local function TipsOff()
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return get and get("GamepadDisableTooltips") or false
end

function DS.SetTipsOff(off)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set("GamepadDisableTooltips", off and "1" or "0") end
end

function DS.Render()
    local items = DS.items
    local n = #items
    DS.index = math.max(1, math.min(DS.index, math.max(1, n)))
    if DS.index < DS.top then DS.top = DS.index end
    if DS.index > DS.top + ROWS - 1 then DS.top = DS.index - ROWS + 1 end
    DS.top = math.max(1, math.min(DS.top, math.max(1, n - ROWS + 1)))
    local total = 0
    for _, e in ipairs(items) do total = total + e.value end
    -- From the loot window a destroy loots in the junk's place: a swap
    local swap = DS.origin == "loot"
    titleText:SetText("Destroy")
    local pad = IF.Input.Pad()
    -- (the mouse acts on the panel wherever the pad is)
    local focused = DS.focus ~= "bags" or not pad
    -- (the panel's own focus glow, as the game's windows; its legend only
    -- while it has the pad)
    IF.Focus.Glow(panel, focused)
    legend:SetShown(focused and pad)
    summary:SetText(n == 0 and "Nothing to throw away" or
        (n .. (n == 1 and " item" or " items") .. " · worth " .. Money(total)))
    more.up:SetShown(DS.top > 1)
    more.down:SetShown(DS.top + ROWS - 1 < n)
    for i, r in ipairs(rows) do
        local index = DS.top + i - 1
        local e = items[index]
        r:SetShown(e ~= nil)
        if e then
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality]
            local selected = index == DS.index and focused
            r.icon:SetTexture(e.icon or 134400)
            r.iconBorder:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
            r.count:SetText(e.count > 1 and e.count or "")
            local name = e.link and e.link:match("%[(.-)%]") or ("item " .. e.itemID)
            r.name:SetText(name)
            r.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
            r.value:SetText((e.value > 0 and Money(e.value) or "no value")
                .. (e.ah and ("  |cff9d917a·  AH " .. Money(e.ah) .. "|r") or ""))
            r.tagText:SetText(e.reason)
            r.focus:SetShown(selected)
            r.focusGlow:SetShown(selected)
            if selected then r.cursor:Point(r) else r.cursor:Hide() end
            if selected then
                local fr, fg, fb = FocusColor()
                r.focus:SetVertexColor(fr, fg, fb)
                r.focusGlow:SetVertexColor(fr, fg, fb, 0.35)
            end
            r.stroke:SetAlpha(selected and 0 or 1)
        end
    end
    -- (with the mouse always, the card under it first)
    local e = focused and (not pad or not TipsOff()) and items[(not pad and DS.hover) or DS.index]
    if e then
        -- Over the bag side (the panel sits left of the bags, with little room
        -- further left); no "equipped" comparison beside it
        GameTooltip:SetOwner(panel, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 26, 0)
        GameTooltip:SetBagItem(e.bag, e.slot)
        GameTooltip:Show()
        for _, tip in ipairs({ _G.ShoppingTooltip1, _G.ShoppingTooltip2 }) do tip:Hide() end
    elseif GameTooltip:GetOwner() == panel then
        GameTooltip:Hide()
    end
    if not pad then
        hints:Hide()
        local list = {}
        local picked = items[DS.index]
        if n > 0 then
            list[#list + 1] = { "A", swap and "Hold to Swap" or "Hold to Destroy" }
            if DS.AtVendor() then
                if picked and picked.sellable then list[#list + 1] = { "Y", "Sell" } end
            elseif swap then
                list[#list + 1] = { "Y", "Hold to Destroy" }
            end
            list[#list + 1] = { "X", swap and "Hold to Swap All" or DS.AtVendor() and "Hold to Sell All"
                or "Hold to Destroy All" }
        end
        -- (closed by the corner's button or Esc; marked by a right-click)
        MouseLegend(list)
        return
    end
    hints:Show()
    MouseLegend({})
    -- From the loot window: Cross swaps, Triangle destroys only (held)
    local press = Glyph("A") .. " " .. (swap and "Hold to Swap" or "Hold to Destroy")
    -- Triangle: at a vendor it sells what can be sold; from the loot window
    -- it destroys only
    local picked = items[DS.index]
    if DS.AtVendor() then
        if picked and picked.sellable then press = press .. "   " .. Glyph("Y") .. " Sell" end
    elseif swap then
        press = press .. "   " .. Glyph("Y") .. " Hold to Destroy"
    end
    local all = swap and " Hold to Swap All   " or DS.AtVendor() and " Hold to Sell All   "
        or " Hold to Destroy All   "
    if picked and IF.Junk then
        all = all .. Glyph("RB") .. (picked.junk and " Not Junk   " or " Mark Junk   ")
    end
    -- (L2 or R2, by the side it's on: the pad to the window it was opened from)
    local label, key = DS.switch:Behind()
    local back = label and (Glyph(key) .. " " .. label .. "   ") or ""
    hints:SetText((n > 0 and (press .. "   " .. Glyph("X") .. all) or "") .. back .. Glyph("B") .. " Close")
    legend:SetWidth(math.max(PANEL_W, hints:GetStringWidth() + 28))
end

function DS.Refresh()
    if not panel:IsShown() then return end
    local current = DS.items[DS.index]
    DS.items = DS.Scan()
    -- Stay near the same place in the list
    if current then
        for i, e in ipairs(DS.items) do
            if e.bag == current.bag and e.slot == current.slot then DS.index = i end
        end
    end
    DS.Render()
end

---------------------------------------------------------------------------
-- The pad, while the panel is up (priority bindings; out of combat)
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", ESCAPE = "B",
    PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADRSTICK = "TIP", PADRSHOULDER = "MARK",
}
-- Kept while the bags have the focus: the way back
local SWITCH_KEYS = { PADLTRIGGER = true, PADRTRIGGER = true }
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

local function Move(step)
    local n = #DS.items
    if n == 0 then return end
    local i = DS.index + step
    if i >= 1 and i <= n then DS.index = i end
    DS.CancelPress()
    DS.Render()
end

-- The wheel: the cards scrolled a row, the pick kept in view
local function Scroll(step)
    local n = #DS.items
    local top = math.max(1, math.min(math.max(1, n - ROWS + 1), DS.top + step))
    if top == DS.top then return end
    DS.top = top
    DS.index = math.max(top, math.min(top + ROWS - 1, DS.index))
    DS.hover = nil
    DS.CancelPress()
    DS.Render()
end
panel:EnableMouseWheel(true)
panel:SetScript("OnMouseWheel", function(_, delta) Scroll(delta > 0 and -1 or 1) end)

function DS.Press(name, down)
    -- L2 / R2 (L2 is the game's Shift: a quick tap): the pad to the window
    -- it was opened from, by the side it's on (bound only on a client
    -- without the catcher: there, either comes back)
    if name == "LT" or name == "RT" then
        if not down then return end
        if DS.focus == "bags" then return DS.SetFocus("panel") end
        DS.switch:Press(name)
        return
    end
    -- (the mouse's buttons work wherever the pad is)
    if DS.focus == "bags" and IF.Input.Pad() then return end
    -- R3: the tooltip shown or not, as in the bag window
    if name == "TIP" then
        if down then
            DS.SetTipsOff(not TipsOff())
            DS.Render()
        end
        return
    end
    -- R1: the picked one junk / not junk (Junk.lua: remembered)
    if name == "MARK" then
        local e = DS.items[DS.index]
        if down and e and IF.Junk then
            DS.CancelPress()
            IF.Junk.Toggle(e.bag, e.slot)
            C_Timer.After(0.15, DS.Refresh)
        end
        return
    end
    if name == "X" then
        -- Hold, then let go: all of them (at a vendor: sold)
        if down then
            DS.holdStart = GetTime()
            holdBar:Show()
        elseif DS.holdStart then
            local held = GetTime() - DS.holdStart
            DS.holdStart = nil
            holdBar:Hide()
            if held >= HOLD_ALL then
                HoldDone()
                if DS.AtVendor() then DS.SellAll() else DS.DestroyAll() end
            end
        end
        return
    end
    -- Cross (Triangle from the loot window) held, then let go once the
    -- picked card has filled: it goes (on the release, a button press the
    -- game lets destroy and loot); let go sooner, nothing
    if name == "A" or (name == "Y" and DS.origin == "loot") then
        if not down then
            if DS.pressBy ~= name then return end
            local e, held = Pressed(), GetTime() - DS.pressStart
            DS.CancelPress()
            -- From the loot window Cross swaps, Triangle only destroys
            if e and held >= HOLD_ONE then
                HoldDone()
                DS.Destroy(e, name == "Y")
            end
            return
        end
        local e = DS.items[DS.index]
        if not e then return end
        DS.pressStart, DS.pressBy, DS.pressEntry = GetTime(), name, e
        ShowFill(0)
        return
    end
    -- Circle on its release: closing on the press would hand the release to
    -- the bag window, which closes the bags
    if name == "B" then
        if not down then DS.Close() end
        return
    end
    if not down then return end
    if name == "UP" then Move(-1)
    elseif name == "DOWN" then Move(1)
    elseif name == "LEFT" then Move(-ROWS)
    elseif name == "RIGHT" then Move(ROWS)
    elseif name == "Y" and DS.AtVendor() then
        -- At a vendor Triangle sells (bought back from it if need be: no hold)
        local e = DS.items[DS.index]
        if e and e.sellable then DS.Sell(e) end
    end
end

local buttons = {}
for key, name in pairs(KEYS) do
    local b = K.NewFrame("Button", "ImprovedForeverDestroyPad" .. key)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(_, _, down) DS.Press(name, down ~= false) end)
    buttons[key] = b
end

-- Only Escape is bound: the pad's buttons are taken by the panel's catcher
-- (below) while it has the focus, and L2 / R2 watched while the bags have
-- it. Override bindings on the pad (Cross above all) carry our taint into
-- the game's gamepad navigation (ADDON_ACTION_FORBIDDEN). (No catcher on
-- this client: the pad bound as before.)
local function Bind()
    if IF.InCombat() then return end
    ClearOverrideBindings(panel)
    local catcherPad = panel.EnableGamePadButton ~= nil
    for key in pairs(KEYS) do
        local name = buttons[key]:GetName()
        if DS.focus == "bags" and not (SWITCH_KEYS[key] and not catcherPad) then
            -- (the bag window's own navigation has it; L2 / R2 watched)
        elseif key == "ESCAPE" then
            SetOverrideBindingClick(panel, true, key, name)
        elseif not catcherPad then
            for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(panel, true, prefix .. key, name) end
        end
    end
end

-- Which has the pad: the panel (ours, the game's focus dimmed) or the
-- window it was opened from (the game's own navigation; L2 / R2 watched,
-- the trigger towards the panel bringing it back): as the game's windows
-- pass it (ImprovedForever's Focus.lua)
DS.switch = IF.Focus.Switch(panel, {
    onChange = function(focus)
        DS.focus = focus == "ours" and "panel" or "bags"
        DS.holdStart = nil
        holdBar:Hide()
        DS.CancelPress()
        Bind()
        DS.TakePad(focus == "ours")
        DS.HideNativeFocus(focus == "ours")
        DS.Render()
    end,
})

-- focus: "panel" or "bags"
function DS.SetFocus(focus)
    DS.switch:Set(focus == "panel" and "ours" or "game")
end

panel:SetScript("OnUpdate", function()
    if panel.EnableGamePadButton then DS.switch:Update() end
    -- (the rumble of whichever hold is under way; none: let go)
    local feel
    if DS.holdStart then
        local p = math.min(1, (GetTime() - DS.holdStart) / HOLD_ALL)
        feel = p
        -- (along the legend; with the mouse, along the button held)
        local along = legend
        for _, b in ipairs(mouseButtons) do
            if b.down == "X" then along = b end
        end
        if holdBar:GetParent() ~= along then
            holdBar:SetParent(along)
            holdBar:ClearAllPoints()
            holdBar:SetPoint("BOTTOMLEFT", along, "BOTTOMLEFT", 5, 4)
        end
        holdBar:SetWidth(math.max(1, (along:GetWidth() - 10) * p))
        holdBar:SetColorTexture(p >= 1 and 1 or 0.85, p >= 1 and 0.35 or 0.2, 0.1, 0.9)
    end
    if DS.pressStart then
        -- (gone from under it: let go)
        if Pressed() then
            local p = (GetTime() - DS.pressStart) / HOLD_ONE
            ShowFill(p)
            feel = math.max(feel or 0, math.min(1, p))
        else
            DS.CancelPress()
        end
    end
    HoldFeel(feel)
end)

-- A vendor's window is open: what can be sold is sold to it
function DS.AtVendor()
    local merchant = _G.MerchantFrame
    return merchant and merchant:IsShown() or false
end

-- Sold by the Junk module's one seller (Junk.lua: judged again, counted
-- once gone from the bags)
function DS.Sell(e)
    if IF.InCombat() or not DS.AtVendor() then return end
    ClearCursor()
    IF.Junk.Sell({ e }, { done = function() DS.Refresh() end })
end

-- Every listed one a vendor buys (not from a bag kept out of Sell All Junk)
function DS.SellAll()
    if IF.InCombat() or not DS.AtVendor() then return end
    local list = {}
    for _, e in ipairs(DS.items) do
        if e.sellable then list[#list + 1] = e end
    end
    ClearCursor()
    IF.Junk.Sell(list, { bulk = true, done = function() DS.Refresh() end })
end

-- noLoot: from the loot window, destroy only (no swap)
function DS.Destroy(e, noLoot)
    if IF.InCombat() then return end
    local name = e.link or "item"
    if DestroyOne(e) then
        IF.Print("destroyed " .. name .. (e.count > 1 and (" x" .. e.count) or ""))
        if not noLoot then DS.LootAfter("one") end
    elseif blocked then
        IF.Print("the game doesn't let addons destroy items here.")
    end
    C_Timer.After(0.2, DS.Refresh)
end

function DS.DestroyAll()
    if IF.InCombat() then return end
    local done = 0
    for _, e in ipairs(DS.items) do
        if DestroyOne(e) then
            done = done + 1
        elseif blocked then
            break
        end
    end
    if blocked and done == 0 then
        IF.Print("the game doesn't let addons destroy items here.")
    else
        IF.Print("destroyed " .. done .. (done == 1 and " item." or " items."))
        if done > 0 then DS.LootAfter("all") end
    end
    C_Timer.After(0.3, DS.Refresh)
end

-- origin: "bags" (default) or "loot", the window it is opened from
function DS.Open(origin)
    if IF.InCombat() or panel:IsShown() then return end
    DS.items, DS.index, DS.top, DS.hover = DS.Scan(), 1, 1, nil
    DS.CancelPress()
    DS.focus = "panel"
    DS.switch.focus = "ours"
    DS.origin = origin or "bags"
    DS.TakePad(true)
    -- (where: beside the loot window or the bags: IF.Focus.Dock above)
    panel:Show()
    Bind()
    DS.HideNativeFocus(true)
    DS.Render()
end

-- While the panel has the pad, the game's own focus (its cursor, the bag or
-- loot window's glow) is hidden, so only ours shows
function DS.HideNativeFocus(hide)
    IF.Focus.DimNative(panel, hide)
end

function DS.Close()
    if not panel:IsShown() then return end
    panel:Hide()
end

panel:SetScript("OnHide", function()
    DS.TakePad(false)
    DS.HideNativeFocus(false)
    DS.holdStart = nil
    holdBar:Hide()
    DS.CancelPress()
    HoldFeel(nil)
    if GameTooltip:GetOwner() == panel then GameTooltip:Hide() end
    if not IF.InCombat() then ClearOverrideBindings(panel) end
end)

IV.OnChange(function() DS.Refresh() end)
-- (the pad or the mouse taken up: its legend, its tooltip)
IF.Input.OnChange(function() if panel:IsShown() then DS.Render() end end)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- (the Sell prompt comes and goes with the vendor's window)
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- (its bindings can't be cleared once combat starts)
        panel:Hide()
    else
        DS.Refresh()
    end
end)

---------------------------------------------------------------------------
-- Opening: its button (or two: one held, one pressed) while a bag is open.
-- Watched, not taken over; an R3 combo it uses is left to it by the wheels
-- while the bags are open.
---------------------------------------------------------------------------
function DS.OpenKey()
    return IF.db and IF.db.bagCleanKey or DEFAULT_KEY
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- Its name: "R2 + R3"; glyphs too with size
function DS.OpenKeyText(size)
    local held, pressed = Parts(DS.OpenKey())
    local function one(key)
        return (size and (IF.GlyphText(key, size) .. " ") or "") .. IF.ButtonName(key)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

function DS.Enabled()
    return IF.db and IF.db.bagClean ~= false
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

-- The R3 combo its key is, if any ("R2")
local COMBO_OF = { PADLSHOULDER = "L1", PADLTRIGGER = "L2", PADRSHOULDER = "R1", PADRTRIGGER = "R2" }
local function Combo(spec)
    local held, pressed = Parts(spec)
    if pressed == "PADRSTICK" then return held and COMBO_OF[held] or "R3" end
end

local suppressed
local function Suppress()
    -- (the wheels' R3 combos: only with the Wheel module)
    if not IF.SuppressCombo then return end
    local want = DS.Enabled() and AnyBagOpen() and Combo(DS.OpenKey()) or nil
    if want == suppressed then return end
    if suppressed and not IF.SuppressCombo(suppressed, false) then return end
    if want and not IF.SuppressCombo(want, true) then return end
    suppressed = want
end

function DS.SetOpenKey(key)
    IF.db.bagCleanKey = key ~= DEFAULT_KEY and key or nil
    Suppress()
end

local watcher = CreateFrame("Frame")
local wasDown = false
local tipsBefore      -- the tooltip setting before the opening press
watcher:SetScript("OnUpdate", function()
    if not IF.db then return end
    Suppress()
    if not DS.Enabled() or panel:IsShown() or IF.InCombat() or not IsKeyDown then
        wasDown = false
        return
    end
    local held, pressed = Parts(DS.OpenKey())
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held))
    -- The moment the combination is made
    if down and not wasDown and AnyBagOpen() then
        -- An R3 in it has also reached the bag window, which turned its
        -- tooltips over: back as they were
        if pressed == "PADRSTICK" and tipsBefore ~= nil and TipsOff() ~= tipsBefore then
            DS.SetTipsOff(tipsBefore)
        end
        DS.Open()
    end
    wasDown = down
    if not down then tipsBefore = TipsOff() end
end)

-- The panel takes the pad's buttons itself while it has the focus: the bag
-- window's own navigation (Circle: close the bags...) comes before override
-- bindings, a frame taking the pad comes before both
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local PAD_NAME = {}
for key, name in pairs(KEYS) do
    if key ~= "ESCAPE" then PAD_NAME[key] = name end
end
if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        if PAD_NAME[button] then DS.Press(PAD_NAME[button], true) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        if PAD_NAME[button] then DS.Press(PAD_NAME[button], false) end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
end

function DS.TakePad(on)
    if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end


---------------------------------------------------------------------------
-- From the loot window: once the bags are full, Triangle "Destroy" joins
-- the window's own button legend (Loot, Loot All, Close) and opens the
-- panel; there, Cross loots in the junk's place. The game's legend and
-- its bindings are never handed anything of ours (that would carry our
-- taint into its binding stack): the prompt
-- is a frame of our own in the game's prompt template, set after Close
-- inside the legend, whose box is only widened to hold it (and given back
-- its width after). Triangle is watched, not taken.
---------------------------------------------------------------------------
local LOOT_KEY = "PAD4"
-- The game's legend layout (InputLegendPromptGroup.lua)
local LEGEND_PAD = 10         -- between the prompts and the box's edge
local PROMPT_GAP = 15         -- between two prompts

local function FreeSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n = C_Container and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bag)
        free = free + (n or 0)
    end
    return free
end

-- The loot window's legend box, while it has the pad
local function LootLegendBox()
    local footer = _G.LootFrame and _G.LootFrame.gamepadFooter
    local legend = footer and footer.isShown and footer.inputLegend
    local box = legend and legend.promptContainerFrame
    return box and box:IsVisible() and box or nil
end

-- Ours, made the first time it is needed (false: the client has no prompts)
local lootPrompt
local function LootPrompt()
    if lootPrompt == nil then
        lootPrompt = false
        local loot = _G.LootFrame
        if not loot then return nil end
        local holder = K.NewFrame("Frame", nil, loot)
        local ok, prompt = pcall(function()
            local p = K.NewFrame("Frame", nil, holder, "InputPromptOneIconWithTextTemplate")
            p:SetPromptInputIconKey(1, _G.GAMEPAD_FACE_TOP or LOOT_KEY)
            p:SetPromptText("Destroy")
            p:EnablePrompt()
            return p
        end)
        if ok and prompt then
            holder.prompt = prompt
            holder:Hide()
            lootPrompt = holder
        end
    end
    return lootPrompt or nil
end

-- Puts it after the last of the game's prompts, the box widened to hold it
local function PlaceLootPrompt(holder, box)
    local width = box:GetWidth()
    -- The game laid its legend out again (or a new box): that's its width
    if holder.box ~= box or not holder.setWidth or math.abs(width - holder.setWidth) > 0.5 then
        holder.box, holder.baseWidth = box, width
        holder.prompt:ClearAllPoints()
        holder.prompt:SetPoint("TOPLEFT", box, "TOPLEFT", width - LEGEND_PAD + PROMPT_GAP, -LEGEND_PAD)
    end
    holder:SetFrameLevel(box:GetFrameLevel() + 2)
    holder.setWidth = holder.baseWidth + PROMPT_GAP + holder.prompt:GetWidth()
    box:SetWidth(holder.setWidth)
end

local function HideLootPrompt()
    local holder = lootPrompt
    if not holder or not holder:IsShown() then return end
    holder:Hide()
    -- The box's own width back, unless the game has set it since
    local box = holder.box
    if box and holder.setWidth and math.abs(box:GetWidth() - holder.setWidth) <= 0.5 then
        box:SetWidth(holder.baseWidth)
    end
    holder.box, holder.setWidth = nil, nil
end

local lootFull, freeAtError = false, 0
local triangleWasDown = false

-- The loot slot last tried, and the one that didn't fit (the bags full)
local lastLootSlot, failedSlot
if LootSlot then hooksecurefunc("LootSlot", function(slot) lastLootSlot = slot end) end

local function HasItem(slot)
    if LootSlotHasItem then return LootSlotHasItem(slot) end
    return GetLootSlotType and Enum.LootSlotType and GetLootSlotType(slot) == Enum.LootSlotType.Item
end

-- What needs bag room, in order: the slot that didn't fit, the one the
-- loot window's cursor is on, then the rest
local function LootTargets()
    local list, seen, n = {}, {}, GetNumLootItems and GetNumLootItems() or 0
    local function add(slot)
        if slot and not seen[slot] and slot >= 1 and slot <= n and HasItem(slot) then
            seen[slot] = true
            list[#list + 1] = slot
        end
    end
    add(failedSlot)
    pcall(function()
        local nav = _G.SmartNavigation
        local button = nav and nav:GetCurrentButton()
        local element = button and button:GetParent()
        if element and element.GetSlotIndex then add(element:GetSlotIndex()) end
    end)
    for slot = 1, n do add(slot) end
    return list
end

-- After a destroy from the loot window: its loot in the junk's place
-- ("one": the item that didn't fit, "all": everything left), once the
-- bags have the room (their next update)
local lootAfter, lootAfterAt
function DS.LootAfter(what)
    local loot = _G.LootFrame
    if DS.origin ~= "loot" or not (loot and loot:IsShown()) then return end
    if lootAfter ~= "all" then lootAfter = what end
    lootAfterAt = GetTime()
end

local function LootNow()
    local what = lootAfter
    lootAfter = nil
    if not what or GetTime() - (lootAfterAt or 0) > 3 or IF.InCombat() then return end
    local targets = LootTargets()
    failedSlot = nil
    for i, slot in ipairs(targets) do
        if what == "one" and i > 1 then break end
        LootSlot(slot)
    end
end

-- With the mouse: a button of ours under the loot window instead (the
-- game's window itself left as it is)
local lootButton
local function LootButton()
    local loot = _G.LootFrame
    if not lootButton and loot then
        lootButton = K.NewFrame("Button", nil, loot, "UIPanelButtonTemplate")
        lootButton:SetSize(120, 24)
        lootButton:SetPoint("TOP", loot, "BOTTOM", 0, -4)
        lootButton:SetText("Destroy Junk")
        lootButton:SetScript("OnClick", function() DS.Open("loot") end)
        lootButton:Hide()
    end
    return lootButton
end

local lootWatch = CreateFrame("Frame")
lootWatch:Hide()
lootWatch:SetScript("OnUpdate", function()
    local room = DS.Enabled() and not panel:IsShown() and not IF.InCombat()
        and (lootFull or FreeSlots() == 0)
    local mouse = room and not IF.Input.Pad() and LootButton()
    if mouse then mouse:Show() elseif lootButton then lootButton:Hide() end
    local box = room and IF.Input.Pad() and LootLegendBox()
    local holder = box and LootPrompt()
    if holder then
        PlaceLootPrompt(holder, box)
        holder:Show()
    else
        HideLootPrompt()
    end
    -- The moment Triangle goes down, with the prompt up
    local down = IsKeyDown and IsKeyDown(LOOT_KEY) or false
    if down and not triangleWasDown and holder then DS.Open("loot") end
    triangleWasDown = down
end)

local lootEvents = CreateFrame("Frame")
lootEvents:RegisterEvent("LOOT_OPENED")
lootEvents:RegisterEvent("LOOT_CLOSED")
lootEvents:RegisterEvent("UI_ERROR_MESSAGE")
lootEvents:RegisterEvent("BAG_UPDATE_DELAYED")
lootEvents:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then
        lootFull, lastLootSlot, failedSlot, lootAfter = false, nil, nil, nil
        -- (a press still held from opening the loot isn't a new one)
        triangleWasDown = IsKeyDown and IsKeyDown(LOOT_KEY) or false
        lootWatch:Show()
    elseif event == "LOOT_CLOSED" then
        lootFull, failedSlot, lootAfter = false, nil, nil
        lootWatch:Hide()
        HideLootPrompt()
        if lootButton then lootButton:Hide() end
        -- Nothing left to swap for
        if DS.origin == "loot" then DS.Close() end
    elseif event == "UI_ERROR_MESSAGE" then
        -- What the loot window itself listens for (the bags may still have
        -- room, of the wrong kind: a quiver, a profession bag)
        -- (errorType, message; older clients: message only)
        local first, message = ...
        if (message or first) == ERR_INV_FULL and lootWatch:IsShown() then
            lootFull, freeAtError = true, FreeSlots()
            failedSlot = lastLootSlot
        end
    else
        if lootFull and FreeSlots() > freeAtError then
            -- Room made since: no longer full
            lootFull = false
        end
        LootNow()
    end
end)

---------------------------------------------------------------------------
-- Opened without the pad: its binding's key, /if destroy (from the loot
-- window while the bags are full, else the bags)
---------------------------------------------------------------------------
local function OpenByHand()
    if panel:IsShown() then return DS.Close() end
    if not DS.Enabled() then return IF.Print("the Destroy panel is off (the Junk tab).") end
    if IF.InCombat() then return IF.Print("the Destroy panel opens after combat.") end
    local loot = _G.LootFrame
    local fromLoot = loot and loot:IsShown() and (lootFull or FreeSlots() == 0)
    DS.Open(fromLoot and "loot" or "bags")
end

IF.AddCommand("destroy", OpenByHand, ": open or close the Destroy panel")
-- (its button: a wheel's slot, a press, a corner opens it: Actions.lua)
IF.Actions.PressButton("ImprovedForeverDestroyToggle", OpenByHand)

-- Its binding, on the Bindings tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "destroy", label = "Destroy", group = "Bags", tab = "bindings",
    icon = IF.TEX .. "ic_mod_destroy", context = "bags", order = 21,
    -- Watched, not taken; on an R3 combo the wheels leave it to the panel
    -- while the bags are open (Destroy.lua)
    desc = "Opens the Destroy panel while your bags are open",
    tip = "Opens the Destroy panel: the junk, safe to throw away. Only while a bag is open. With the bags full,"
        .. " the top face button (Triangle / Y) opens it from the loot window too: there each destroy"
        .. " loots the item that didn't fit in the junk's place.",
    accepts = B.NotDouble,
    specs = function() return IF.Destroy.Enabled() and B.One(IF.Destroy.OpenKey()) or {} end,
    set = function(spec)
        IF.db.bagClean = spec ~= nil
        if spec then IF.Destroy.SetOpenKey(spec) end
    end,
    reset = function() IF.db.bagClean = nil end,
    run = function(down) if down then OpenByHand() end end,
})
