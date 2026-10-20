-- The Fish Collection, in the look of Forever's Legacy Challenges
-- (Blizzard_LegacySystem: its window, its art): the portrait frame on the
-- challenges' background, over it the caught progress (the Legacy points'
-- shield and bar), the tabs down its right (Fishes, Items: the game's side
-- tabs, L1 / R1), its filter (the Legacy one's: the game's filter button,
-- its choices in our dropdown, L3; its reset), and a card for each thing
-- that's fished up (junk left out), from the lowest zones it's caught in to
-- the highest: the challenge card (dimmed until caught), its icon in the
-- Legacy frame, its name on the ribbon, under it where and when you first
-- caught it (else where it's fished up, those zones' levels), the date and
-- a tick on its corner once caught. Cross or a click: its page in the Wiki.
local IF = ImprovedForever
local F = IF.Fishing
local B = F.Book
local K = IF.ConfigKit

local W, H = 640, 575
local CARD_H, CARD_GAP = 104, 6
local ICON = 50
local RARITY_ORDER = { 7, 6, 5, 4, 3, 2, 1 }
local FISHING_ICON = "Interface\\Icons\\Trade_Fishing"
local TABS = {
    { key = "fish", label = "Fishes", icon = "Interface\\Icons\\INV_Misc_Fish_02", kinds = { fish = true } },
    { key = "items", label = "Items", icon = "Interface\\Icons\\INV_Misc_Bag_10", kinds = { treasure = true, other = true } },
}

local view = { tab = 1, sel = 1, focus = "ours" }
F.CollectionWindow = view

local function Atlas(t, atlas)
    return pcall(t.SetAtlas, t, atlas) and t:GetAtlas() ~= nil
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function QualityName(q)
    return _G["ITEM_QUALITY" .. q .. "_DESC"] or ({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact",
        "Heirloom" })[q] or "Other"
end

---------------------------------------------------------------------------
-- The window: the portrait frame, the challenges' background
---------------------------------------------------------------------------
local ok, win = pcall(K.NewFrame, "Frame", "ImprovedForeverFishCollection", UIParent, "PortraitFrameTemplate")
if not ok then win = K.NewFrame("Frame", "ImprovedForeverFishCollection", UIParent) end
win:SetSize(W, H)
win:SetFrameStrata("FULLSCREEN_DIALOG")
win:SetPoint("CENTER")
win:EnableMouse(true)
win:SetClampedToScreen(true)
win:Hide()
pcall(function()
    if win.SetTitle then win:SetTitle("Fish Collection") end
    if win.SetPortraitToAsset then win:SetPortraitToAsset(FISHING_ICON) end
end)
if win.CloseButton then win.CloseButton:SetScript("OnClick", function() win:Hide() end) end

local bg = win:CreateTexture(nil, "BACKGROUND", nil, 1)
bg:SetPoint("TOPLEFT", 1, -10)
bg:SetPoint("BOTTOMRIGHT", -2, 4)
if not Atlas(bg, "Legacy-Challenge-BG") then bg:SetColorTexture(0.08, 0.06, 0.04, 1) end

---------------------------------------------------------------------------
-- The caught progress: the Legacy points' shield and bar
---------------------------------------------------------------------------
local summary = CreateFrame("Frame", nil, win)
summary:SetSize(W - 190, 36)
summary:SetPoint("TOP", win, "TOP", 24, -25)
local track = summary:CreateTexture(nil, "ARTWORK")
track:SetPoint("LEFT", -6, -3)
track:SetPoint("RIGHT", 0, -3)
track:SetHeight(16)
if not Atlas(track, "Legacy-Progressbar-BG") then track:SetColorTexture(0, 0, 0, 0.6) end
local bar = CreateFrame("StatusBar", nil, summary)
bar:SetPoint("TOPLEFT", track, "TOPLEFT")
bar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 3)
bar:SetMinMaxValues(0, 1)
if not pcall(bar.SetStatusBarTexture, bar, "Legacy-Progressbar-Fill") or not bar:GetStatusBarTexture()
    or not bar:GetStatusBarTexture():GetAtlas() then
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.75, 0.25)
end
local barFrame = bar:CreateTexture(nil, "OVERLAY")
barFrame:SetPoint("TOPLEFT", -8, 7)
barFrame:SetPoint("BOTTOMRIGHT", 8, -10)
Atlas(barFrame, "Legacy-Progressbar-Frame")
local barText = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
barText:SetPoint("CENTER")
local shield = CreateFrame("Frame", nil, summary)
shield:SetSize(46, 64)
shield:SetPoint("RIGHT", summary, "LEFT", 14, 4)
shield:SetFrameLevel(bar:GetFrameLevel() + 5)
local shieldIcon = shield:CreateTexture(nil, "BACKGROUND")
shieldIcon:SetSize(46, 66)
shieldIcon:SetPoint("TOPRIGHT")
Atlas(shieldIcon, "UI-Legacy-Points-icon-c60")
local shieldText = shield:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
shieldText:SetSize(42, 16)
shieldText:SetPoint("TOPRIGHT", -2, -31)

---------------------------------------------------------------------------
-- The cards: a scroll of them under the progress
---------------------------------------------------------------------------
local scroll = CreateFrame("ScrollFrame", nil, win)
scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -98)
scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 10)
if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(W - 28, 1)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 60)))
end)

local cards = {}
local function Card(i)
    local c = cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, content)
    c:SetHeight(CARD_H)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.selected = c:CreateTexture(nil, "BORDER")
    c.selected:SetAllPoints()
    Atlas(c.selected, "Legacy-Challenge-Cards-selected")
    c.selected:Hide()
    c.ribbon = c:CreateTexture(nil, "ARTWORK")
    c.ribbon:SetPoint("TOPLEFT", 5, -4)
    c.ribbon:SetPoint("TOPRIGHT", -80, -4)
    c.ribbon:SetHeight(46)
    -- (its icon in the Legacy frame)
    c.iconFrame = CreateFrame("Frame", nil, c)
    c.iconFrame:SetSize(60, 60)
    c.iconFrame:SetPoint("TOPLEFT", 12, -18)
    c.icon = c.iconFrame:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("CENTER")
    local mask = c.iconFrame:CreateMaskTexture()
    if pcall(mask.SetAtlas, mask, "UI-Frame-IconMask") then
        mask:SetAllPoints(c.icon)
        c.icon:AddMaskTexture(mask)
    else
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    c.frame = c.iconFrame:CreateTexture(nil, "OVERLAY")
    c.frame:SetSize(66, 66)
    c.frame:SetPoint("CENTER")
    Atlas(c.frame, "Legacy-Tree-Frame-icon-frame")
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    c.label:SetPoint("TOPLEFT", c.ribbon, "TOPLEFT", 70, -18)
    c.label:SetPoint("RIGHT", c, "RIGHT", -150, 0)
    c.label:SetJustifyH("LEFT")
    c.label:SetWordWrap(false)
    c.desc = c:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
    c.desc:SetPoint("TOPLEFT", c.ribbon, "BOTTOMLEFT", 72, -2)
    c.desc:SetPoint("RIGHT", c, "RIGHT", -24, 0)
    c.desc:SetJustifyH("LEFT")
    c.desc:SetJustifyV("TOP")
    c.desc:SetHeight(44)
    -- (caught: the date and a tick on its corner)
    c.dateBg = c:CreateTexture(nil, "OVERLAY")
    c.dateBg:SetSize(124, 21)
    c.dateBg:SetPoint("TOPRIGHT", -6, -3)
    Atlas(c.dateBg, "Legacy-Challenge-Cards-Date-BG")
    c.check = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.check:SetSize(16, 14)
    c.check:SetPoint("TOPRIGHT", -10, -7)
    Atlas(c.check, "worldquest-tracker-checkmark")
    c.date = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.date:SetPoint("RIGHT", c.check, "LEFT", -2, 0)
    c:SetScript("OnClick", function(self) view:Read(self.item) end)
    c:SetScript("OnEnter", function(self)
        if not IF.Input.Pad() then
            view.sel = self.index
            view:Render()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetItemByID, GameTooltip, self.item.id) then GameTooltip:SetText(self.item.name) end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cards[i] = c
    return c
end

---------------------------------------------------------------------------
-- What's shown
---------------------------------------------------------------------------
-- A zone's levels (the game's map's, through the Wiki's zone maps), or nil
local levels = {}
local function ZoneLevels(area)
    if levels[area] == nil then
        levels[area] = false
        local LB = IF.Wiki
        local map = area and LB and LB.UiMap and LB.UiMap(area)
        if map and C_Map and C_Map.GetMapLevels then
            local okLevels, low, high = pcall(C_Map.GetMapLevels, map)
            if okLevels and type(low) == "number" and low > 0 then levels[area] = { low, high or low } end
        end
    end
    return levels[area] or nil
end

-- (the lowest zone it's caught in: its levels)
local function ItemLevels(id)
    local best
    for _, w in ipairs(B.Index().where[id] or {}) do
        local l = ZoneLevels(w.area)
        if l and (not best or l[1] < best[1]) then best = l end
    end
    return best
end

-- The filters (the Legacy one's checkboxes), kept: caught, not caught, each
-- rarity, the zone you're in only
local FILTER_DEFAULTS = { caught = true, missing = true, q1 = true, q2 = true, q3 = true, q4 = true, here = false }
local function Filters()
    local s = F.Settings()
    s.collectionFilter = type(s.collectionFilter) == "table" and s.collectionFilter or {}
    for k, v in pairs(FILTER_DEFAULTS) do
        if s.collectionFilter[k] == nil then s.collectionFilter[k] = v end
    end
    return s.collectionFilter
end

local function Defaults()
    local f = Filters()
    for k, v in pairs(FILTER_DEFAULTS) do
        if f[k] ~= v then return false end
    end
    return true
end

-- (caught somewhere in the zone you're in: the zone or one of its subzones)
local function CaughtHere(id, zone)
    for _, w in ipairs(B.Index().where[id] or {}) do
        if w.place == zone or (w.area and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(w.area) == zone) then
            return true
        end
    end
end

-- A tab's things, the filters' let through, the lowest zones first; how
-- many caught and how many there are (before the filters)
local function Members(tab)
    local list, col, n, total = {}, B.Collection(), 0, 0
    local f, zone = Filters(), GetZoneText and GetZoneText() or ""
    for id, item in pairs(B.Index().items) do
        if tab.kinds[item.kind] and item.quality > 0 and B.Index().where[id] then
            total = total + 1
            local caught = col[id] ~= nil
            if caught then n = n + 1 end
            if (caught and f.caught or not caught and f.missing) and f["q" .. math.min(4, item.quality)]
                and (not f.here or CaughtHere(id, zone)) then
                item.levels = ItemLevels(id)
                list[#list + 1] = item
            end
        end
    end
    table.sort(list, function(a, b)
        local la, lb = a.levels and a.levels[1] or 999, b.levels and b.levels[1] or 999
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return list, n, total
end

-- (where it's fished up: the likeliest places, their levels, in a few words)
local function Where(id)
    local list = {}
    for _, w in ipairs(B.Index().where[id] or {}) do list[#list + 1] = w end
    table.sort(list, function(a, b) return a.chance > b.chance end)
    local names = {}
    for i = 1, math.min(3, #list) do
        local l = ZoneLevels(list[i].area)
        names[i] = list[i].place .. (l and (" (" .. l[1] .. (l[2] ~= l[1] and ("-" .. l[2]) or "") .. ")") or "")
    end
    if #list > 3 then names[#names + 1] = (#list - 3) .. " more" end
    return table.concat(names, ", ")
end

local cursor = IF.Focus.Cursor(win)
local legend = IF.InputLegend(win)
legend:SetPoint("TOP", win, "BOTTOM", 0, -4)
local sideTabs = IF.UI.SideTabs(win, function(key)
    for i, t in ipairs(TABS) do
        if t.key == key then view:SetTab(i) end
    end
end, { keys = { "LB", "RB" } })

-- The filter: the game's filter button (the Legacy one's), its reset; its
-- choices in our dropdown (L3 with the pad)
local dropdown = IF.Dropdown(win, { maxHeight = 360 })
local filterButton
do
    local okButton, b = pcall(K.NewFrame, "DropdownButton", nil, win, "WowStyle1FilterDropdownTemplate")
    if not (okButton and b) then
        b = K.NewFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(90, 22)
        b:SetText(FILTER or "Filter")
    end
    b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -22, -66)
    b:SetScript("OnMouseDown", function() view:Filter() end)
    if b.ResetButton then
        b.ResetButton:SetScript("OnClick", function()
            local f = Filters()
            for k, v in pairs(FILTER_DEFAULTS) do f[k] = v end
            view.sel = 1
            view:Render()
        end)
    end
    filterButton = b
end
dropdown.frame:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -4)
local shown = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
shown:SetPoint("RIGHT", filterButton, "LEFT", -12, 0)

local function FilterEntries()
    local f, list = Filters(), {}
    local function Check(key, text)
        list[#list + 1] = { kind = "checkbox", key = key, text = text, selected = f[key], select = function()
            f[key] = not f[key]
            view.sel = 1
            view:Render()
        end }
    end
    list[#list + 1] = { kind = "title", text = "Show" }
    Check("caught", "Caught")
    Check("missing", "Not caught yet")
    list[#list + 1] = { kind = "divider" }
    list[#list + 1] = { kind = "title", text = "Rarity" }
    for q = 1, 4 do
        local hex = q > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex or ""
        Check("q" .. q, hex .. QualityName(q) .. (q == 4 and " and up" or "") .. (hex ~= "" and "|r" or ""))
    end
    list[#list + 1] = { kind = "divider" }
    Check("here", "Caught in this zone")
    return list
end

function view:Filter()
    if dropdown:IsShown() then return dropdown:Close() end
    dropdown:Open(FilterEntries, { onClose = function() view:Render() end })
    self:Render()
end

local switch
function view:Render()
    if not win:IsShown() then return end
    local focused = self.focus ~= "window"
    local pad = IF.Input.Pad()
    IF.Focus.Glow(win, focused and pad)
    local tab = TABS[self.tab]
    sideTabs:Render(TABS, tab.key)
    local list, n, total = Members(tab)
    self.list = list
    -- (the progress)
    bar:SetValue(total > 0 and n / total or 0)
    barText:SetText(("%s Caught %d / %d"):format(tab.label, n, total))
    shieldText:SetText(n)
    -- (the filter: its reset while it isn't the default; how many it shows)
    if filterButton.ResetButton then filterButton.ResetButton:SetShown(not Defaults()) end
    shown:SetText(#list < total and ("Showing %d of %d"):format(#list, total) or "")
    -- (the cards)
    local col, y = B.Collection(), 0
    local width = content:GetWidth()
    local sel = math.max(1, math.min(self.sel, #list))
    self.sel = sel
    self.spots = {}
    for i, item in ipairs(list) do
        local c = Card(i)
        local caught = col[item.id]
        c.index, c.item = i, item
        c:SetWidth(width)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        if not Atlas(c.bg, caught and "Legacy-Challenge-Cards" or "Legacy-Challenge-Cards-Disable") then
            Atlas(c.bg, "Legacy-Challenge-Cards")
            c.bg:SetDesaturated(not caught)
        end
        local ribbon = caught and "Legacy-Challenge-Cards-Ribbon-Brown" or "Legacy-Challenge-Cards-Ribbon-Brown-Disable"
        if not Atlas(c.ribbon, ribbon) then
            Atlas(c.ribbon, "Legacy-Challenge-Cards-Ribbon-Brown")
            c.ribbon:SetDesaturated(not caught)
        else
            c.ribbon:SetDesaturated(false)
        end
        c.icon:SetTexture(B.Icon(item.id))
        c.icon:SetDesaturated(not caught)
        c.icon:SetAlpha(caught and 1 or 0.6)
        c.label:SetText(item.name)
        if not caught then c.label:SetTextColor(0.6, 0.6, 0.6)
        elseif item.quality > 1 then c.label:SetTextColor(QualityColor(item.quality))
        else c.label:SetTextColor(1, 1, 1) end
        if caught then
            c.desc:SetText(("First caught %s%s.\nCaught %d time%s."):format(date("%d %b %Y", caught.first or time()),
                caught.firstZone and (" in " .. caught.firstZone) or "", caught.count or 1,
                (caught.count or 1) == 1 and "" or "s"))
            c.desc:SetTextColor(1, 1, 1)
            c.date:SetText(date("%m/%d/%y", caught.first or time()))
        else
            c.desc:SetText("Fished up in " .. Where(item.id) .. ".")
            c.desc:SetTextColor(0.55, 0.55, 0.55)
        end
        for _, part in ipairs({ c.dateBg, c.check, c.date }) do part:SetShown(caught ~= nil) end
        c.selected:SetShown(i == sel and (focused and pad or c:IsMouseOver()))
        c:Show()
        self.spots[i] = y
        y = y + CARD_H + CARD_GAP
    end
    for i = #list + 1, #cards do cards[i]:Hide() end
    content:SetHeight(math.max(1, y))
    -- (the pad: its cursor, its prompts)
    local target = focused and pad and cards[sel]
    if target and target:IsShown() then cursor:Point(target) else cursor:Hide() end
    if focused and pad then
        local defs = { { glyph = "DPAD_UD", text = "Choose" }, { "PAD1", "A", "Read" },
            { { "PADLSHOULDER", "PADRSHOULDER" }, { "LB", "RB" }, "Tab" }, { "PADLSTICK", "LS", "Filter" } }
        local hint = switch and switch:Hint()
        if hint then defs[#defs + 1] = hint end
        defs[#defs + 1] = { "PAD2", "B", "Close" }
        legend:Set(defs)
    else
        legend:Set(nil)
    end
end

-- Its page in the Wiki, beside this
function view:Read(item)
    local LB = IF.Wiki
    if item and LB and LB.Open then LB.Open(item.id, "ui") end
end

function view:SetTab(i)
    if not TABS[i] then return end
    self.tab, self.sel = i, 1
    scroll:SetVerticalScroll(0)
    self:Render()
end

-- (the picked card in view)
local function ScrollTo(i)
    local top, h = view.spots and view.spots[i], scroll:GetHeight()
    if not top then return end
    local at = scroll:GetVerticalScroll()
    if top < at then scroll:SetVerticalScroll(math.max(0, top - 4))
    elseif top + CARD_H > at + h then scroll:SetVerticalScroll(top + CARD_H - h) end
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
local KEYS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD1 = "A", PAD2 = "B",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSTICK = "LS" }

local function Press(name, down)
    -- (the filter up: its own, Circle on its release)
    if dropdown:IsShown() then
        if down == (name ~= "B") then dropdown:Press(name) end
        return view:Render()
    end
    if name == "LS" then
        if down then view:Filter() end
        return
    end
    -- (Circle on its release: closing on the press hands the release to the
    -- window under it)
    if name == "B" then
        if not down then win:Hide() end
        return
    end
    if not down then return end
    local n = #(view.list or {})
    if name == "UP" then view.sel = math.max(1, view.sel - 1)
    elseif name == "DOWN" then view.sel = math.min(n, view.sel + 1)
    elseif name == "LB" or name == "RB" then
        return view:SetTab((view.tab - 1 + (name == "RB" and 1 or -1)) % #TABS + 1)
    elseif name == "LT" or name == "RT" then return switch:Press(name)
    elseif name == "A" then return view:Read(view.list and view.list[view.sel])
    end
    view:Render()
    ScrollTo(view.sel)
end

local catcher = K.NewFrame("Frame", nil, win)
catcher:SetAllPoints(win)
if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button) if KEYS[button] then Press(KEYS[button], true) end end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button) if KEYS[button] then Press(KEYS[button], false) end end)
    -- (setting the handler switches its input on: off until wanted)
    catcher:EnableGamePadButton(false)
end
legend:SetPress(catcher)

local function TakePad(on)
    if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

-- (Esc: closed, on its release)
local escape = K.NewFrame("Button", "ImprovedForeverFishCollectionEscape")
escape:RegisterForClicks("AnyUp")
escape:SetScript("OnClick", function()
    if dropdown:IsShown() then return dropdown:Close() end
    win:Hide()
end)
local function BindEscape(on)
    if IF.InCombat() then return end
    ClearOverrideBindings(win)
    if on then SetOverrideBindingClick(win, true, "ESCAPE", escape:GetName()) end
end

-- Where it sits: as the game's own panels (Focus.lua)
IF.Focus.Dock(win)

switch = IF.Focus.Switch(win, {
    onChange = function(focus)
        local ours = focus == "ours"
        view.focus = ours and "ours" or "window"
        TakePad(ours)
        BindEscape(ours)
        IF.Focus.DimNative(win, ours)
        view:Render()
    end,
})

win:SetScript("OnUpdate", function() switch:Update() end)
IF.Input.OnChange(function() view:Render() end)

win:SetScript("OnHide", function()
    view.focus = "ours"
    switch.focus = "ours"
    TakePad(false)
    IF.Focus.DimNative(win, false)
    cursor:Hide()
    dropdown:Close()
    if not IF.InCombat() then ClearOverrideBindings(win) end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
end)
win:RegisterEvent("PLAYER_REGEN_DISABLED")
win:SetScript("OnEvent", function() win:Hide() end)

-- Open: on Fishes (itemID: on its tab, its card picked)
function B.Open(itemID)
    if IF.InCombat() then return IF.Print("Not in combat.") end
    view.tab, view.sel, view.focus = 1, 1, "ours"
    switch.focus = "ours"
    local item = itemID and B.Index().items[itemID]
    if item then
        for i, t in ipairs(TABS) do if t.kinds[item.kind] then view.tab = i end end
    end
    if not win:IsShown() then PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839) end
    win:Show()
    TakePad(true)
    BindEscape(true)
    IF.Focus.DimNative(win, true)
    scroll:SetVerticalScroll(0)
    view:Render()
    if item then
        for i, other in ipairs(view.list) do if other.id == itemID then view.sel = i end end
        view:Render()
        ScrollTo(view.sel)
    end
end

function B.Toggle()
    if win:IsShown() then return win:Hide() end
    B.Open()
end
-- (its button: a wheel's slot, a press, a corner opens it: Actions.lua)
IF.Actions.PressButton("ImprovedForeverFishCollectionToggle", function() B.Toggle() end)

-- (the collection grew while it's open)
F.OnCatch(function() if win:IsShown() then view:Render() end end)

---------------------------------------------------------------------------
-- Its hotkey (the Bindings tab, Misc): a button, or one held + one pressed
-- ("PADLSHOULDER+PADDUP"), watched, not taken over: the buttons keep their
-- own actions too. And a keyboard key (Binds.lua).
---------------------------------------------------------------------------
function B.Key()
    return IF.db and F.Settings().collectionKey or nil
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

local keyWatch = CreateFrame("Frame")
local wasDown = false
keyWatch:SetScript("OnUpdate", function()
    local key = B.Key()
    -- (only while the game has the gamepad's focus, Binds.lua)
    if not key or not IsKeyDown or (IF.Menu and IF.Menu.IsOpen()) or not IF.Binds.InGame() then
        wasDown = false
        return
    end
    local held, pressed = Parts(key)
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held))
    -- (the moment the combination is made)
    if down and not wasDown then B.Toggle() end
    wasDown = down
end)

local Binds = IF.Binds
Binds.Add({
    id = "fishcollection", label = "Fish Collection", group = "Other", tab = "fishing",
    icon = IF.TEX .. "ic_mod_fishing", context = "world", order = 36,
    desc = "Opens / closes the Fish Collection",
    tip = "Opens / closes the Fish Collection: every fish and item caught. Watched only: the buttons"
        .. " keep their own actions too.",
    accepts = Binds.NotDouble,
    specs = function() return Binds.One(B.Key()) end,
    set = function(spec) F.Settings().collectionKey = spec or false end,
    run = function(down) if down then B.Toggle() end end,
})
