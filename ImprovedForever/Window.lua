-- The windows' look, as the auction window's (ImprovedForever_Auction's
-- AuctionBuy.lua) and the configuration panel's (Menu.lua) share it: the
-- game's flat panel with its title, pages picked with the game's side tabs
-- down its right (the right stick's glyph above them), a list down the left
-- in a dark panel, rows lit with the card stroke in the gamepad's focus
-- colour, the pad's buttons in a legend.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C

local UI = {}
IF.UI = UI

-- The focus colour the game's gamepad UI uses (Options > Controller)
function UI.FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    if value == 2 then return 0, 0, 0 end
    if value == 3 then return 0.3, 0.5, 1 end
    return 1, 0.9, 0.4
end

-- A dark inset panel, the tooltip's thin border round it
function UI.Panel(parent, alpha)
    local f = K.NewFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.03, 0.02, 0.01, alpha or 0.5)
    f:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
    return f
end

-- A row's focus: the card stroke, in the focus colour
-- (a rounded ring, nine-sliced: its corners stay round at any width;
-- under the row's text and icon), and the game's gamepad cursor at its left
-- while it's lit in full (dimmed: lit but not where the pad is; Focus.lua)
function UI.FocusStroke(parent)
    local slice = K.NineSlice(parent, "ic_select", 128, 32, 10, 10, "BORDER")
    local ring = { shown = false, alpha = 1, tint = 1 }
    local cursor
    local function Cursor()
        local on = ring.shown and ring.alpha >= 0.99 and ring.tint >= 0.99
        if on and not cursor and IF.Focus then cursor = IF.Focus.Cursor(parent) end
        if not cursor then return end
        if on then cursor:Point(parent) else cursor:Hide() end
    end
    function ring:SetShown(on)
        self.shown = on and true or false
        slice:SetShown(self.shown)
        Cursor()
    end
    function ring:Show() self:SetShown(true) end
    function ring:Hide() self:SetShown(false) end
    function ring:SetVertexColor(r, g, b, a)
        self.tint = a or 1
        for _, part in ipairs(slice.parts) do part:SetVertexColor(r, g, b, a or 1) end
        Cursor()
    end
    function ring:SetAlpha(a)
        self.alpha = a
        for _, part in ipairs(slice.parts) do part:SetAlpha(a) end
        Cursor()
    end
    -- On, in the focus colour (dimmed: lit but not where the pad is)
    function ring:Light(on, dim)
        self:SetShown(on)
        if not on then return end
        local r, g, b = UI.FocusColor()
        self:SetVertexColor(r, g, b)
        self:SetAlpha(dim and 0.45 or 1)
    end
    ring:Hide()
    return ring
end

---------------------------------------------------------------------------
-- The window: the game's flat panel (a plain dialog box where the client
-- has no such template), its title at the top. opaque: a dark stone fill
-- behind it (the panel's own is see-through where nothing sits on it)
---------------------------------------------------------------------------
function UI.Window(name, width, height, opaque)
    local ok, win = pcall(K.NewFrame, "Frame", name, UIParent, "DefaultPanelFlatTemplate")
    if not ok then
        win = K.NewFrame("Frame", name, UIParent, "BackdropTemplate")
        win:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end
    win:SetSize(width, height)
    win:SetFrameStrata("DIALOG")
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:Hide()
    if opaque then
        local fill = win:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetPoint("TOPLEFT", 4, -4)
        fill:SetPoint("BOTTOMRIGHT", -4, 4)
        fill:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        fill:SetHorizTile(true)
        fill:SetVertTile(true)
        fill:SetVertexColor(0.32, 0.29, 0.26)
        local shade = win:CreateTexture(nil, "BACKGROUND", nil, -7)
        shade:SetAllPoints(fill)
        shade:SetColorTexture(0, 0, 0, 0.45)
    end
    win.titleText = win.TitleContainer and win.TitleContainer.TitleText
    if not win.titleText then
        win.titleText = K.Text(win, 13, KC.title)
        win.titleText:SetPoint("TOP", 0, -8)
    end
    function win:SetTitle(text) self.titleText:SetText(text) end
    -- The game's close button in its corner (for the mouse): win.onClose()
    -- when set (the auction window closes the auction house), else hidden
    -- (where the game's own goes: UIPanelCloseButtonDefaultAnchors)
    local made, close = pcall(K.NewFrame, "Button", nil, win, "UIPanelCloseButton")
    if made and close then
        close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 1, 0)
        close:SetFrameLevel(win:GetFrameLevel() + 10)
        close:SetScript("OnClick", function()
            if win.onClose then win.onClose() else win:Hide() end
        end)
        win.CloseButton = close
    end
    return win
end

---------------------------------------------------------------------------
-- The pages' tabs down the window's right: the game's side tabs (as the
-- character window's), the right stick's glyph above them (tilted up /
-- down it moves through them; opts.keys = { above, below }: those glyphs
-- instead, one above the tabs and one below, as the Legacy window's L1 /
-- R1). tabs:Render(list, selected): list = { { key, label, icon } };
-- onSelect(key) as one is clicked.
---------------------------------------------------------------------------
function UI.SideTabs(win, onSelect, opts)
    opts = opts or {}
    local tabs = { buttons = {} }
    local glyph = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local below = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    local function Button(i)
        if tabs.buttons[i] then return tabs.buttons[i] end
        local made, b = pcall(K.NewFrame, "Frame", nil, win, "LargeSideTabButtonTemplate")
        if not (made and b and b.Icon) then
            b = K.NewFrame("Frame", nil, win)
            b:SetSize(44, 54)
            b.Background = b:CreateTexture(nil, "BACKGROUND")
            b.Background:SetAllPoints()
            b.Background:SetColorTexture(0.1, 0.08, 0.05, 0.95)
            b.Icon = b:CreateTexture(nil, "ARTWORK")
            b.Icon:SetSize(36, 36)
            b.Icon:SetPoint("CENTER", -3, 0)
            b.SelectedTexture = b:CreateTexture(nil, "OVERLAY")
            b.SelectedTexture:SetAllPoints()
            b.SelectedTexture:SetColorTexture(1, 0.82, 0.3, 0.3)
        end
        b:EnableMouse(true)
        b:SetScript("OnMouseDown", function(self) onSelect(self.key) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.label)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tabs.buttons[i] = b
        return b
    end

    function tabs:Render(list, selected)
        local previous
        for i, t in ipairs(list) do
            local b = Button(i)
            b.key, b.label = t.key, t.label
            -- (the template's icon takes its texture's own size: an atlas's;
            -- ours are 128 px. Our art uncropped, the game's icons trimmed)
            K.SetIcon(b.Icon, t.icon or 134400)
            b.Icon:SetSize(32, 32)
            if type(t.icon) == "string" and t.icon:find(IF.TEX, 1, true) == 1 then b.Icon:SetTexCoord(0, 1, 0, 1) end
            b:ClearAllPoints()
            if previous then
                b:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            else
                b:SetPoint("TOPLEFT", win, "TOPRIGHT", -2, -52)
            end
            if b.SelectedTexture then b.SelectedTexture:SetShown(t.key == selected) end
            b:Show()
            previous = b
        end
        for i = #list + 1, #self.buttons do self.buttons[i]:Hide() end
        glyph:ClearAllPoints()
        if self.buttons[1] then glyph:SetPoint("BOTTOM", self.buttons[1], "TOP", -3, 4) end
        local pad = #list > 1 and IF.Input.Pad()
        local keys = opts.keys
        glyph:SetText(pad and IF.GlyphText(keys and keys[1] or "RS", keys and 22 or 26) or "")
        below:ClearAllPoints()
        if previous then below:SetPoint("TOP", previous, "BOTTOM", -3, -4) end
        below:SetText(pad and keys and IF.GlyphText(keys[2], 22) or "")
    end

    -- The first tab button (a tooltip placed beside the window goes past them)
    function tabs:Last(count)
        return self.buttons[count or #self.buttons]
    end
    return tabs
end

---------------------------------------------------------------------------
-- A list down a page's left, in a dark panel: its title (the glyph that
-- moves it), its rows, the picked one lit. list:Render(title, entries,
-- selected, focused): entries = { { label } or { header = text } };
-- onClick(index) as a row is clicked.
---------------------------------------------------------------------------
function UI.SideList(parent, width, rowCount, onClick)
    local list = UI.Panel(parent, 0.4)
    list:SetWidth(width)
    list.title = K.ChatText(list, 12, KC.dimGold)
    list.title:SetPoint("TOP", 0, -10)
    list.rows = {}
    for i = 1, rowCount do
        local r = K.NewFrame("Button", nil, list)
        r:SetSize(width - 16, 28)
        r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 30)
        r.focus = UI.FocusStroke(r)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.text:SetPoint("LEFT", 10, 0)
        r.text:SetPoint("RIGHT", -6, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
            if self.index then onClick(self.index) end
        end)
        list.rows[i] = r
    end

    function list:Render(title, entries, selected, focused)
        self.title:SetText(title or "")
        local n = #self.rows
        local top = math.max(1, math.min(selected - math.floor(n / 2), #entries - n + 1))
        for i, r in ipairs(self.rows) do
            local index = top + i - 1
            local e = entries[index]
            r:SetShown(e ~= nil)
            if e then
                r.index = not e.header and index or nil
                if e.header then
                    r.text:SetText(e.header:upper())
                    r.text:SetTextColor(unpack(KC.dimGold))
                    r.focus:Hide()
                else
                    local on = index == selected
                    r.text:SetText(e.label)
                    r.text:SetTextColor(on and 1 or 0.8, on and 0.95 or 0.74, on and 0.8 or 0.6)
                    r.focus:Light(on, not focused)
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- The legend: a line of the pad's buttons and what they do, in a dark band
-- under the window. legend:SetText(text) (glyphs in the text: IF.PadText)
---------------------------------------------------------------------------
function UI.Legend(win)
    local legend = K.NewFrame("Frame", nil, win, "BackdropTemplate")
    legend:SetPoint("TOP", win, "BOTTOM", 0, -6)
    legend:SetHeight(36)
    legend:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    legend:SetBackdropColor(0.05, 0.04, 0.03, 0.92)
    legend:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
    legend.text = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    legend.text:SetPoint("CENTER")
    function legend:SetText(text)
        self.text:SetText(text)
        self:SetWidth(math.max(500, self.text:GetStringWidth() + 28))
    end
    return legend
end

---------------------------------------------------------------------------
-- A bar of chips, as the Buy page's categories along its top: the
-- bumper / trigger glyphs at its ends (they move through the chips), the
-- chosen one lit and kept in view (a key nil: no glyph that end).
-- bar:Render(names, selected); onClick(i) as a chip is clicked.
---------------------------------------------------------------------------
function UI.ChipBar(parent, leftKey, rightKey, onClick)
    local bar = UI.Panel(parent, 0.4)
    bar:SetHeight(34)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.left:SetPoint("LEFT", 8, 0)
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.right:SetPoint("RIGHT", -8, 0)
    bar.clip = K.NewFrame("Frame", nil, bar)
    bar.clip:SetPoint("TOPLEFT", 44, 0)
    bar.clip:SetPoint("BOTTOMRIGHT", -44, 0)
    bar.clip:SetClipsChildren(true)
    bar.chips = {}

    local function Chip(i)
        local c = bar.chips[i]
        if c then return c end
        c = K.NewFrame("Button", nil, bar.clip)
        c:SetHeight(26)
        c.bg = c:CreateTexture(nil, "BACKGROUND")
        c.bg:SetAllPoints()
        c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        c.text:SetPoint("CENTER")
        c:SetScript("OnClick", function(self) onClick(self.index) end)
        bar.chips[i] = c
        return c
    end

    -- names: the chips' names; selected: which (1-based); one name: nothing to pick
    function bar:Render(names, selected)
        local enabled = #names > 1
        -- (the pad's glyphs at its ends; with the mouse the chips are clicked)
        local pad = IF.Input.Pad()
        self.left:SetText((pad and leftKey) and IF.GlyphText(leftKey, 22) or "")
        self.right:SetText((pad and rightKey) and IF.GlyphText(rightKey, 22) or "")
        self.left:SetAlpha(enabled and 1 or 0.3)
        self.right:SetAlpha(enabled and 1 or 0.3)
        local widths, total = {}, 0
        for i, name in ipairs(names) do
            local c = Chip(i)
            c.text:SetText(name)
            widths[i] = c.text:GetStringWidth() + 24
            total = total + widths[i] + 6
        end
        for i = #names + 1, #self.chips do self.chips[i]:Hide() end
        -- Scrolled to keep the chosen chip in the middle when they don't all fit
        local clipW = self.clip:GetWidth()
        if not clipW or clipW <= 0 then clipW = self:GetWidth() - 88 end
        local x, at = 0, 0
        for i = 1, #names do
            if i == selected then at = x + widths[i] / 2 end
            x = x + widths[i] + 6
        end
        local shift = 0
        if total > clipW then shift = math.max(0, math.min(total - clipW, at - clipW / 2)) end
        x = -shift
        local fr, fg, fb = UI.FocusColor()
        for i = 1, #names do
            local c = self.chips[i]
            c.index = i
            c:ClearAllPoints()
            c:SetPoint("LEFT", self.clip, "LEFT", x, 0)
            c:SetWidth(widths[i])
            c:Show()
            if i == selected then
                c.bg:SetColorTexture(fr * 0.45, fg * 0.38, fb * 0.2, 0.9)
                c.text:SetTextColor(1, 0.95, 0.8)
            else
                c.bg:SetColorTexture(0, 0, 0, 0.35)
                c.text:SetTextColor(0.8, 0.74, 0.6)
            end
            x = x + widths[i] + 6
        end
    end
    return bar
end

---------------------------------------------------------------------------
-- A card, as the Buy page's items: the card's art, its icon in a border,
-- its name, a line under it, the focus stroke; a tick on the right when it
-- is what's chosen, or a text there (right); bound: washed in the colour of
-- what's set. card:Fill{ icon, name, line, ticked, right, bound }
---------------------------------------------------------------------------
function UI.CardRow(parent, width, height)
    local r = K.NewFrame("Button", nil, parent)
    r:SetSize(width, height)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if IF.HasAtlas("Looting_ItemCard_BG") then
        r.bg:SetAtlas("Looting_ItemCard_BG")
    else
        r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    end
    -- (the wash: a rounded box over the art, its corners as the card's)
    r.wash = K.Box(r, 4, nil, "BACKGROUND", 1)
    r.wash:SetPoints(r, 1)
    r.wash:SetColors(KC.yours, 0.18)
    r.focus = UI.FocusStroke(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(height - 16, height - 16)
    r.icon:SetPoint("CENTER", r, "LEFT", 6 + (height - 16) / 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.border = r:CreateTexture(nil, "OVERLAY")
    r.border:SetPoint("TOPLEFT", r.icon, -1, 1)
    r.border:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
    r.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    r.border:SetBlendMode("ADD")
    r.border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    r.border:SetVertexColor(0.6, 0.6, 0.6, 0.9)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- (the text from the icon's square, whatever the art's shape)
    local textX = 6 + (height - 16) + 10
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", textX, -9)
    r.name:SetPoint("RIGHT", r, "RIGHT", -28, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.line = K.ChatText(r, 11, KC.help)
    r.line:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", textX, 9)
    r.line:SetPoint("RIGHT", r, "RIGHT", -28, 0)
    r.line:SetJustifyH("LEFT")
    r.line:SetWordWrap(false)
    r.tick = r:CreateTexture(nil, "OVERLAY")
    r.tick:SetSize(16, 16)
    r.tick:SetPoint("RIGHT", -10, 0)
    if IF.HasAtlas("common-dropdown-icon-checkmark-yellow") then
        r.tick:SetAtlas("common-dropdown-icon-checkmark-yellow")
    else
        r.tick:SetTexture(IF.TEX .. "ic_emote_yes")
    end
    r.right = K.ChatText(r, 12, KC.cream)
    r.right:SetPoint("RIGHT", -10, 0)
    r.right:SetJustifyH("RIGHT")
    r.right:SetWordWrap(false)
    -- (columns: mid, a text left of right's; each colW wide)
    r.mid = K.ChatText(r, 12, KC.cream)
    r.mid:SetJustifyH("LEFT")
    r.mid:SetWordWrap(false)
    r.mid:Hide()
    local box = height - 16
    function r:Fill(o)
        K.SetIcon(self.icon, o.icon or 134400)
        -- (art, as the radial menu's, kept to its own shape inside the
        -- icon's square, unframed; an icon fills it, framed)
        local info = type(o.icon) == "string" and C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo(o.icon)
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            local k = box / math.max(info.width, info.height)
            self.icon:SetSize(info.width * k, info.height * k)
            self.border:Hide()
        else
            self.icon:SetSize(box, box)
            self.border:Show()
        end
        self.name:SetText(o.name or "")
        self.line:SetText(o.line or "")
        self.right:SetText(o.right or "")
        self.wash:SetShown(o.bound and true or false)
        -- (no line: the name in the middle; a text on the right: up to it;
        -- two columns, colW each: up to them)
        local inset = o.right and o.right ~= "" and -(self.right:GetStringWidth() + 18) or -28
        self.mid:SetShown(o.colW ~= nil)
        if o.colW then
            self.right:SetWidth(o.colW)
            self.right:SetJustifyH("LEFT")
            self.mid:ClearAllPoints()
            self.mid:SetPoint("RIGHT", self, "RIGHT", -(10 + o.colW + 12), 0)
            self.mid:SetWidth(o.colW)
            self.mid:SetText(o.mid or "")
            inset = -(10 + 2 * o.colW + 24)
        else
            self.right:SetWidth(0)
            self.right:SetJustifyH("RIGHT")
        end
        self.name:ClearAllPoints()
        if o.line and o.line ~= "" then
            self.name:SetPoint("TOPLEFT", self, "TOPLEFT", textX, -9)
        else
            self.name:SetPoint("LEFT", self, "LEFT", textX, 0)
        end
        self.name:SetPoint("RIGHT", self, "RIGHT", inset, 0)
        self.line:SetPoint("RIGHT", self, "RIGHT", inset, 0)
        self.tick:SetShown(o.ticked and true or false)
    end
    return r
end

---------------------------------------------------------------------------
-- A picker of cards: its lists in a chip bar along its top (the glyphs at
-- its ends: leftKey / rightKey; L2 / R2 switch them), the list's entries as
-- cards in columns under it; the D-pad moves, Cross picks. The shape of ConfigKit's K.Picker: picker:Open{ lists = { { key,
-- label, entries() -> { { action, name, icon, sub } or { header } } } },
-- list, rows (rows of cards), current(list) -> action, marked(entry) -> the
-- one it holds, right(entry) -> a text on its right, bound(entry) -> washed
-- (CardRow), status() -> a line on what it is for, onChoose(entry),
-- onBack() }; picker.entries / .index / .list
---------------------------------------------------------------------------
function UI.CardPicker(parent, cols, cardH, onRender, leftKey, rightKey)
    local p = K.NewFrame("Frame", nil, parent)
    p.cols, p.cards = cols, {}
    p.bar = UI.ChipBar(p, leftKey, rightKey, function(i)
        p:SetList(i)
        onRender()
    end)
    p.bar:SetPoint("TOPLEFT", 0, 0)
    p.bar:SetPoint("TOPRIGHT", 0, 0)
    -- (under the bar, as the Buy page's: the list's name and how many)
    p.status = K.ChatText(p, 11, KC.help)
    p.status:SetPoint("TOPLEFT", p.bar, "BOTTOMLEFT", 4, -6)
    p.status:SetJustifyH("LEFT")
    p.grid = K.NewFrame("Frame", nil, p)
    p.grid:SetPoint("TOPLEFT", p.bar, "BOTTOMLEFT", 0, -24)
    p.grid:SetPoint("BOTTOMRIGHT", 0, 0)
    p.moreUp, p.moreDown = K.MoreArrows(p)
    p.moreUp:SetPoint("BOTTOM", p.grid, "TOP", 0, 2)
    p.moreDown:SetPoint("TOP", p.grid, "BOTTOM", 0, 2)
    -- (the wheel: a row of cards up / down)
    p.grid:EnableMouseWheel(true)
    p.grid:SetScript("OnMouseWheel", function(_, delta)
        if not p.def then return end
        p:Move(delta > 0 and -p.cols or p.cols)
        onRender()
    end)
    p:Hide()

    function p:Open(def)
        self.def = def
        self.list = def.list or 1
        self:LoadList()
        self:Show()
    end

    -- (false, not nil: a frame's field stays one, read before it is set)
    function p:Close()
        self.def = false
        self:Hide()
    end

    function p:IsOpen() return self.def and true or false end

    -- (the list's entries without its section titles: the cards)
    function p:LoadList()
        local list = self.def.lists[self.list]
        local entries = {}
        for _, e in ipairs(list and list.entries() or {}) do
            if not e.header then entries[#entries + 1] = e end
        end
        self.entries, self.index, self.top = entries, nil, 1
        local current = self.def.current
        if type(current) == "function" then current = current(list) end
        for i, e in ipairs(entries) do
            if not self.index or e.action == current then
                self.index = i
                if e.action == current then break end
            end
        end
        self:Move(0)
    end

    function p:SetList(i)
        local n = #self.def.lists
        self.list = (i - 1) % n + 1
        self:LoadList()
    end

    -- How many rows of cards fit
    function p:Rows()
        local h = self.grid:GetHeight()
        if not h or h <= 0 then return self.def and self.def.rows or 4 end
        return math.max(1, math.floor((h + 6) / (cardH + 6)))
    end

    -- step: ± one card (left / right) or a row (up / down); kept in view
    function p:Move(step)
        local n = #(self.entries or {})
        if n == 0 or not self.index then return end
        local i = self.index + step
        if i >= 1 and i <= n then self.index = i end
        local row, rows = math.ceil(self.index / self.cols), self:Rows()
        if row < self.top then self.top = row end
        if row > self.top + rows - 1 then self.top = row - rows + 1 end
    end

    function p:Choose()
        local e = self.def and self.index and self.entries[self.index]
        if e and self.def.onChoose then self.def.onChoose(e) end
    end

    function p:Press(name)
        if not self.def then return true end
        if name == "UP" or name == "DOWN" then
            self:Move(name == "UP" and -self.cols or self.cols)
        elseif name == "LEFT" or name == "RIGHT" then
            self:Move(name == "LEFT" and -1 or 1)
        elseif name == "LT" or name == "RT" then
            if #self.def.lists > 1 then self:SetList(self.list + (name == "LT" and -1 or 1)) end
        elseif name == "A" then
            self:Choose()
        elseif name == "B" then
            if self.def.onBack then self.def.onBack() end
        end
        return true
    end

    function p:Render()
        local def = self.def
        if not def then return end
        local names = {}
        for i, list in ipairs(def.lists) do names[i] = list.label end
        self.bar:Render(names, self.list)
        local n = #(self.entries or {})
        -- (what is picked and holds now first, when the picker says)
        self.status:SetText((def.status and (def.status() .. "      ") or "")
            .. "|cff9d917a" .. def.lists[self.list].label .. "  ·  " .. n .. (n == 1 and " choice" or " choices") .. "|r")
        local gw = self.grid:GetWidth()
        if not gw or gw <= 0 then gw = 700 end
        local cardW = (gw - (self.cols - 1) * 8) / self.cols
        local rows = self:Rows()
        local entries = self.entries or {}
        local first = (self.top - 1) * self.cols
        for slot = 1, math.max(rows * self.cols, #self.cards) do
            local c = self.cards[slot]
            local e = slot <= rows * self.cols and entries[first + slot]
            if e and not c then
                c = UI.CardRow(self.grid, cardW, cardH)
                self.cards[slot] = c
            end
            if c then
                c:SetShown(e and true or false)
                if e then
                    c:SetWidth(cardW)
                    c:ClearAllPoints()
                    local col, row = (slot - 1) % self.cols, math.floor((slot - 1) / self.cols)
                    c:SetPoint("TOPLEFT", self.grid, "TOPLEFT", col * (cardW + 8), -row * (cardH + 6))
                    c:Fill({ icon = e.icon, name = e.name, line = e.sub,
                        ticked = def.marked and def.marked(e),
                        right = def.right and def.right(e), bound = def.bound and def.bound(e),
                        mid = def.mid and def.mid(e), colW = def.colW and def.colW() })
                    c.focus:Light(first + slot == self.index)
                    -- (the mouse: over one picks it; a click chooses it, a
                    -- right-click does def.onAlt)
                    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    c:SetScript("OnClick", function(_, button)
                        p.index = first + slot
                        if button == "RightButton" then
                            if def.onAlt then def.onAlt(e) end
                        else
                            p:Choose()
                        end
                        onRender()
                    end)
                    c:SetScript("OnEnter", function()
                        if IF.Input.Pad() or p.index == first + slot then return end
                        p.index = first + slot
                        onRender()
                    end)
                end
            end
        end
        self.moreUp:SetShown(self.top > 1)
        self.moreDown:SetShown(first + rows * self.cols < #entries)
    end
    return p
end
