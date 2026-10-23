-- The auction house as a scene, in Immersion's look (its header, its
-- first-time tour, the Camp module's scene), with or without that module:
-- the window has no frame of its own, the world dimmed behind it, the
-- pad's buttons along the screen's bottom, the HUD faded out
-- (IF.Focus.Fade: an animation of ours, never the frames' own alpha), all
-- of it back as the auction house closes (at once in a fight).
-- Its parts, for the pages: gold rules fading out at both ends, a diamond
-- with a picture, names in Morpheus, the pages' names in a row along the
-- top (SC.TabRow), the categories' chips (SC.Chips), the legend
-- (SC.Legend), a frame faded in (SC.FadeIn), the window placed in the
-- room between the header and the legend (SC.Place).
local IF = ImprovedForever
-- (the scene only with the Immersion module and its switch on: Module.lua)
if not IF.auctionScene then return end

local K = IF.ConfigKit

local SC = {}
IF.AuctionScene = SC

-- (the header's look: Immersion's HeaderSlot.lua, copied: it may not be in)
SC.FONT = "Fonts\\MORPHEUS.TTF"
SC.GOLD = { 1, 0.82, 0.45 }
SC.GREY = { 0.62, 0.62, 0.62 }
SC.CREAM = { 0.92, 0.88, 0.8 }
local HEADER_RULE_Y, HEADER_RULE_W, HEADER_NAME_GAP = 130, 260, 30
-- (the room the header takes from the screen's top: its rule, the name and
-- a line under it)
local HEADER_ROOM = 205
local IN_TIME, OUT_TIME = 0.6, 0.35
local DIM = 0.45                        -- (the world behind, darkened)
local FOOT_H = 44                       -- (the legend's line along the screen's bottom)

function SC.Ease(x)
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end

-- A line in the scene's look (Morpheus unless font says otherwise), shadowed
function SC.Text(parent, size, color, font, layer)
    local s = parent:CreateFontString(nil, layer or "OVERLAY")
    if not s:SetFont(font or SC.FONT, size, "") then s:SetFont(STANDARD_TEXT_FONT, size, "") end
    color = color or SC.CREAM
    s:SetTextColor(color[1], color[2], color[3])
    s:SetShadowColor(0, 0, 0, 1)
    s:SetShadowOffset(1, -1)
    s:SetWordWrap(false)
    return s
end

-- The game's own body font, for what isn't a name (in the scene's shadow)
SC.BODY = GameFontHighlight and GameFontHighlight:GetFont() or STANDARD_TEXT_FONT

-- A gold rule, fading out at both ends (the header's, the tour's)
function SC.Rule(parent, length, vertical, alpha)
    local f = K.NewFrame("Frame", nil, parent)
    if vertical then f:SetSize(1, length) else f:SetSize(length, 1) end
    local GOLD = SC.GOLD
    local mid = alpha or 0.8
    local function Color(a) return CreateColor(GOLD[1], GOLD[2], GOLD[3], a) end
    f.halves = {}
    -- (each half: the end clear, the middle bright)
    for _, first in ipairs({ true, false }) do
        local r = f:CreateTexture(nil, "ARTWORK")
        r:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local ok
        if vertical then
            r:SetSize(1, length / 2)
            r:SetPoint(first and "BOTTOM" or "TOP", f, "CENTER")
            -- (vertical gradients run from the bottom to the top)
            ok = pcall(r.SetGradient, r, "VERTICAL", first and Color(mid) or Color(0), first and Color(0) or Color(mid))
        else
            r:SetSize(length / 2, 1)
            r:SetPoint(first and "RIGHT" or "LEFT", f, "CENTER")
            ok = pcall(r.SetGradient, r, "HORIZONTAL", first and Color(0) or Color(mid), first and Color(mid) or Color(0))
        end
        if not ok then r:SetAlpha(mid * 0.75) end
        f.halves[#f.halves + 1] = r
    end
    -- (a new length: its halves follow)
    function f:SetLength(n)
        if vertical then self:SetHeight(n) else self:SetWidth(n) end
        for _, r in ipairs(self.halves) do
            if vertical then r:SetHeight(n / 2) else r:SetWidth(n / 2) end
        end
    end
    return f
end

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

-- A diamond on a rule with a picture in it (the header's, the tour's):
-- d:SetIcon(texture), d:SetBorderColor(r, g, b) (gold until then)
function SC.Diamond(parent, size)
    size = size or 26
    local d = K.NewFrame("Frame", nil, parent)
    d:SetSize(size, size)
    local TURN = math.pi / 4
    local GOLD = SC.GOLD
    local bg = d:CreateTexture(nil, "BACKGROUND")
    if not Atlas(bg, "gamepad-actionbar-squareslot-bg") then bg:SetColorTexture(0.05, 0.04, 0.03, 0.9) end
    bg:SetPoint("CENTER")
    bg:SetSize(size * 1.2, size * 1.2)
    bg:SetRotation(TURN)
    -- (the picture, cut to the diamond)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetPoint("CENTER")
    d.icon:SetSize(size * 1.15, size * 1.15)
    local mask = d:CreateMaskTexture()
    mask:SetAtlas("progress-bar-diamond-pip-mask")
    mask:SetPoint("CENTER")
    mask:SetSize(size * 1.23, size * 1.23)
    d.icon:AddMaskTexture(mask)
    local border = d:CreateTexture(nil, "OVERLAY")
    d.border = border
    if not Atlas(border, "gamepad-actionbar-squareslot-border-normal") then
        border:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
    end
    border:SetPoint("CENTER")
    border:SetSize(size * 1.38, size * 1.38)
    border:SetRotation(TURN)
    border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    function d:SetIcon(texture) self.icon:SetTexture(texture or 134400) end
    function d:SetBorderColor(r, g, b) self.border:SetVertexColor(r, g, b) end
    return d
end

-- A frame faded in (opened, a page changed, a tile come): from nothing to
-- itself over duration, after delay
function SC.FadeIn(frame, duration, delay)
    local g = frame.sceneIn
    if not g then
        g = frame:CreateAnimationGroup()
        g.alpha = g:CreateAnimation("Alpha")
        g.alpha:SetFromAlpha(0)
        g.alpha:SetToAlpha(1)
        if g.alpha.SetSmoothing then g.alpha:SetSmoothing("OUT") end
        g:SetToFinalAlpha(true)
        g:SetScript("OnFinished", function() frame:SetAlpha(1) end)
        g:SetScript("OnStop", function() frame:SetAlpha(1) end)
        frame.sceneIn = g
    end
    g:Stop()
    g.alpha:SetDuration(duration or 0.3)
    g.alpha:SetStartDelay(delay or 0)
    -- (nothing of it shows while it waits)
    frame:SetAlpha(0)
    g:Play()
end

---------------------------------------------------------------------------
-- The stage: the world dimmed, the bars, the title where no header is
---------------------------------------------------------------------------
local stage = CreateFrame("Frame", "ImprovedForeverAuctionScene", UIParent)
stage:SetAllPoints(UIParent)
stage:SetFrameStrata("BACKGROUND")
stage:Hide()

local dim = stage:CreateTexture(nil, "BACKGROUND", nil, -2)
dim:SetAllPoints(stage)
dim:SetColorTexture(0, 0, 0, 1)
dim:SetAlpha(0)

-- The legend's line along the screen's bottom (the legend, the mouse's
-- buttons): over the window's strata, unscaled
local footer = CreateFrame("Frame", nil, stage)
footer:SetFrameStrata("DIALOG")
footer:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 0, 6)
footer:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, 6)
footer:SetHeight(FOOT_H)
SC.footer = footer

-- The title, where the header would be when Immersion's isn't showing:
-- the auctioneer's name in Morpheus under a gold rule, "Auction House"
-- under it
local title = CreateFrame("Frame", nil, stage)
title:SetFrameStrata("DIALOG")
title:SetAllPoints(stage)
local titleRule = SC.Rule(title, HEADER_RULE_W * 2, false)
titleRule:SetPoint("CENTER", title, "TOP", 0, -HEADER_RULE_Y)
local titleName = SC.Text(title, 30, SC.CREAM)
titleName:SetPoint("TOP", titleRule, "CENTER", 0, -HEADER_NAME_GAP + 12)
local titleSub = SC.Text(title, 13, SC.GOLD, SC.BODY)
titleSub:SetPoint("TOP", titleName, "BOTTOM", 0, -6)

-- Immersion's header up (the target's, the zone's...): ours not drawn
local HEADERS = { "ImprovedForeverTargetHeader", "ImprovedForeverQuestArrow", "ImprovedForeverZoneBanner",
    "ImprovedForeverLevelBanner", "ImprovedForeverQuestProgress" }
local function HeaderShown()
    for _, name in ipairs(HEADERS) do
        local f = rawget(_G, name)
        if f and f:IsVisible() and f:GetAlpha() > 0 then return true end
    end
    return false
end

local function RefreshTitle()
    local shown = not HeaderShown()
    title:SetShown(shown)
    if not shown then return end
    local npc = UnitExists("npc") and UnitName("npc")
    titleName:SetText(npc or "Auction House")
    titleSub:SetText(npc and "Auction House" or "")
end

---------------------------------------------------------------------------
-- The HUD, faded (named, as the Camp and Fishing modules': never a sweep
-- of the screen's frames, which would catch the bags, a popup, the game's
-- footer). The header stays: it shows the auctioneer.
---------------------------------------------------------------------------
local OURS = { "ImprovedForeverGamepadBar", "ImprovedForeverRecentSlot", "ImprovedForeverPlayerFrame",
    "ImprovedForeverMinionCard1", "ImprovedForeverPartyCard1", "ImprovedForeverPartyCard2",
    "ImprovedForeverPartyCard3", "ImprovedForeverPartyCard4", "ImprovedForeverPartyCasts",
    "ImprovedForeverBuffList", "ImprovedForeverCooldownTimeline", "ImprovedForeverPlayerHealth",
    "ImprovedForeverPlayerCast", "IFObjectiveTrackerFrame", "ImprovedForeverMinimapLabels",
    "ImprovedForeverMinimapAlert", "MinimapCluster", "Minimap" }
-- (without the Immersion module, the game's own HUD. With it, it fades
-- these itself, its own over them, and would show one again we'd faded)
local NATIVE = { "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame", "PartyFrame", "CompactPartyFrame",
    "GamepadMainActionBarFrame", "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "MicroMenuContainer", "BagsBar",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
    "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }

local faded = {}

-- (a frame's 3D model draws through an alpha animation: hidden itself,
-- and back from its unit after; the Fishing module's)
local function Model(f, on)
    local a = f.avatar
    if not (a and a.model) then return end
    if on then
        a.model:Hide()
    elseif f.unit then
        local UF = IF.Interface and IF.Interface.UnitFrames
        if UF and UF.AvatarUnit then UF.AvatarUnit(a, f.unit, true) end
    end
end

local function Gather()
    wipe(faded)
    local function Add(f)
        if f and f.IsVisible and f:IsVisible() then faded[#faded + 1] = f end
    end
    for _, name in ipairs(OURS) do Add(rawget(_G, name)) end
    if not rawget(_G, "IFObjectiveTrackerFrame") then Add(rawget(_G, "ObjectiveTrackerFrame")) end
    if not IF.Interface then
        for _, name in ipairs(NATIVE) do Add(rawget(_G, name)) end
    end
    local PC = IF.Interface and IF.Interface.PartyCards
    for _, label in ipairs(PC and PC.labels or {}) do Add(label) end
    for _, f in ipairs(faded) do Model(f, true) end
end

-- (a: the HUD's alpha, 0 to 1; done: back as it was, ours let go)
local function HUD(a, done)
    for _, f in ipairs(faded) do
        if done then
            IF.Focus.Fade(f, false)
            Model(f, false)
        else
            IF.Focus.Fade(f, true, a)
        end
    end
    if done then wipe(faded) end
end

---------------------------------------------------------------------------
-- In and out
---------------------------------------------------------------------------
local p, from, to, t, duration = 0, 0, 0, 0, IN_TIME

local function Apply(x)
    local e = SC.Ease(x)
    dim:SetAlpha(DIM * e)
    footer:SetAlpha(e)
    title:SetAlpha(e)
    HUD(1 - e)
end

stage:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    p = from + (to - from) * math.min(1, t / duration)
    Apply(p)
    if to == 0 and p <= 0 then
        HUD(1, true)
        stage:Hide()
    end
end)

function SC.Enter()
    if to == 1 and stage:IsShown() then return RefreshTitle() end
    if not stage:IsShown() then
        p = 0
        Gather()
    end
    from, to, t, duration = p, 1, 0, IN_TIME
    RefreshTitle()
    stage:Show()
end

-- fast: at once (a fight)
function SC.Leave(fast)
    if not stage:IsShown() then return end
    if fast then
        p, from, to = 0, 0, 0
        Apply(0)
        HUD(1, true)
        stage:Hide()
        return
    end
    from, to, t, duration = p, 0, 0, OUT_TIME
end

function SC.Active()
    return stage:IsShown() and to == 1
end

-- The window in the room left between the header (or the title) and the
-- legend, in the screen's middle; made smaller (its scale) where it
-- wouldn't fit
function SC.Place(win)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local bottom = FOOT_H + 12
    local room = sh - HEADER_ROOM - bottom
    local w, h = win:GetWidth(), win:GetHeight()
    local s = math.min(1, room / h, (sw - 40) / w)
    win:SetScale(s)
    win:ClearAllPoints()
    -- (offsets in the window's own scale)
    win:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sw / 2 / s, (bottom + room / 2) / s)
end

---------------------------------------------------------------------------
-- The legend, along the screen's bottom: the pad's buttons and what they do, as a
-- line of text. legend:SetText(text), legend:SetShown(on)
---------------------------------------------------------------------------
function SC.Legend()
    local legend = CreateFrame("Frame", nil, footer)
    legend:SetAllPoints(footer)
    legend.text = SC.Text(legend, 14, SC.CREAM, SC.BODY)
    legend.text:SetPoint("CENTER")
    function legend:SetText(text) self.text:SetText(text) end
    return legend
end

---------------------------------------------------------------------------
-- The pages' names in a row along the window's top, in Morpheus, as the
-- header's name: the picked one gold, the others grey, small gold diamonds
-- between them; a long faint rule under the row,
-- fading out at both ends; the right stick's glyph before them (it moves
-- through them). A click picks one; the wheel over the row steps.
-- row:Render(list, selected): list = { { key, label } }
---------------------------------------------------------------------------
-- A small diamond, gold (a rotated square)
local function Pip(parent, size, alpha)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size, size)
    t:SetColorTexture(SC.GOLD[1], SC.GOLD[2], SC.GOLD[3], alpha or 1)
    t:SetRotation(math.pi / 4)
    return t
end

function SC.TabRow(parent, onSelect, onStep)
    local row = K.NewFrame("Frame", nil, parent)
    row:SetHeight(48)
    row.buttons, row.pips = {}, {}
    row.glyph = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.rule = SC.Rule(row, 600, false, 0.35)
    row.rule:SetPoint("BOTTOM", row, "BOTTOM", 0, 4)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) onStep(delta > 0 and -1 or 1) end)

    local function Button(i)
        local b = row.buttons[i]
        if b then return b end
        b = K.NewFrame("Button", nil, row)
        b:SetHeight(40)
        b.text = SC.Text(b, 20, SC.GREY)
        b.text:SetPoint("CENTER", 0, 3)
        b:SetScript("OnClick", function(self) onSelect(self.key) end)
        b:SetScript("OnEnter", function(self)
            if not self.on then self.text:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3]) end
        end)
        b:SetScript("OnLeave", function(self)
            if not self.on then self.text:SetTextColor(SC.GREY[1], SC.GREY[2], SC.GREY[3]) end
        end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta) onStep(delta > 0 and -1 or 1) end)
        row.buttons[i] = b
        return b
    end

    function row:Render(list, selected)
        local GAP = 44
        local total, widths = 0, {}
        for i, t in ipairs(list) do
            local b = Button(i)
            b.key, b.on = t.key, t.key == selected
            b.text:SetText(t.label)
            local c = b.on and SC.GOLD or SC.GREY
            b.text:SetTextColor(c[1], c[2], c[3])
            widths[i] = b.text:GetStringWidth() + 12
            total = total + widths[i] + (i > 1 and GAP or 0)
        end
        for i = #list + 1, #self.buttons do self.buttons[i]:Hide() end
        for _, pip in ipairs(self.pips) do pip:Hide() end
        local x = -total / 2
        for i = 1, #list do
            local b = self.buttons[i]
            b:SetWidth(widths[i])
            b:ClearAllPoints()
            b:SetPoint("LEFT", self, "CENTER", x, 0)
            b:Show()
            -- (a diamond between it and the one before)
            if i > 1 then
                local pip = self.pips[i - 1] or Pip(self, 4, 0.55)
                self.pips[i - 1] = pip
                pip:ClearAllPoints()
                pip:SetPoint("CENTER", self, "CENTER", x - GAP / 2, 3)
                pip:Show()
            end
            x = x + widths[i] + GAP
        end
        self.rule:SetLength(math.max(360, total + 320))
        -- (the pad's glyph before the first, with more than one page)
        local pad = #list > 1 and IF.Input.Pad()
        self.glyph:SetText(pad and IF.GlyphText("RS", 24) or "")
        self.glyph:ClearAllPoints()
        if self.buttons[1] then self.glyph:SetPoint("RIGHT", self.buttons[1], "LEFT", -18, -1) end
    end
    return row
end

---------------------------------------------------------------------------
-- A row of chips, as the Buy page's categories along its top, in the
-- scene's look: the names, the chosen one gold (as the pages' names), the
-- others grey (cream under the mouse), centred when they all fit; the
-- bumper / trigger glyphs at its ends (a key nil: no glyph that end), the
-- chosen one kept in view.
-- bar:Render(names, selected); onClick(i) as a chip is clicked.
---------------------------------------------------------------------------
function SC.Chips(parent, leftKey, rightKey, onClick)
    local bar = K.NewFrame("Frame", nil, parent)
    bar:SetHeight(34)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.left:SetPoint("LEFT", 4, 0)
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.right:SetPoint("RIGHT", -4, 0)
    bar.clip = K.NewFrame("Frame", nil, bar)
    bar.clip:SetPoint("TOPLEFT", 40, 0)
    bar.clip:SetPoint("BOTTOMRIGHT", -40, 0)
    bar.clip:SetClipsChildren(true)
    bar.chips = {}

    local function Chip(i)
        local c = bar.chips[i]
        if c then return c end
        c = K.NewFrame("Button", nil, bar.clip)
        c:SetHeight(28)
        c.text = SC.Text(c, 14, SC.GREY, SC.BODY)
        c.text:SetPoint("CENTER")
        c:SetScript("OnClick", function(self) onClick(self.index) end)
        c:SetScript("OnEnter", function(self)
            if not self.on then self.text:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3]) end
        end)
        c:SetScript("OnLeave", function(self)
            if not self.on then self.text:SetTextColor(SC.GREY[1], SC.GREY[2], SC.GREY[3]) end
        end)
        bar.chips[i] = c
        return c
    end

    function bar:Render(names, selected)
        local enabled = #names > 1
        local pad = IF.Input.Pad()
        self.left:SetText((pad and leftKey) and IF.GlyphText(leftKey, 22) or "")
        self.right:SetText((pad and rightKey) and IF.GlyphText(rightKey, 22) or "")
        self.left:SetAlpha(enabled and 1 or 0.3)
        self.right:SetAlpha(enabled and 1 or 0.3)
        local widths, total = {}, 0
        for i, name in ipairs(names) do
            local c = Chip(i)
            c.text:SetText(name)
            widths[i] = c.text:GetStringWidth() + 26
            total = total + widths[i] + 4
        end
        for i = #names + 1, #self.chips do self.chips[i]:Hide() end
        -- (scrolled to keep the chosen chip in the middle when they don't all fit)
        local clipW = self.clip:GetWidth()
        if not clipW or clipW <= 0 then clipW = self:GetWidth() - 80 end
        local x, at = 0, 0
        for i = 1, #names do
            if i == selected then at = x + widths[i] / 2 end
            x = x + widths[i] + 4
        end
        -- (all fitting: centred in the row)
        local shift = (total - 4 - clipW) / 2
        if total > clipW then shift = math.max(0, math.min(total - clipW, at - clipW / 2)) end
        x = -shift
        for i = 1, #names do
            local c = self.chips[i]
            local on = i == selected
            c.index = i
            c:ClearAllPoints()
            c:SetPoint("LEFT", self.clip, "LEFT", x, 0)
            c:SetWidth(widths[i])
            c:Show()
            c.on = on
            local color = on and SC.GOLD or SC.GREY
            c.text:SetTextColor(color[1], color[2], color[3])
            x = x + widths[i] + 4
        end
    end
    return bar
end

---------------------------------------------------------------------------
-- An item's icon in the spell diamonds' ring (Immersion's gamepad bar)
-- turned upright to a square, the icon cut to its rounded opening.
-- ri:SetIcon(texture), ri:SetSide(n) (the icon's side; the ring hugs it)
---------------------------------------------------------------------------
-- (the ring's opening is about 0.88 of it across)
SC.RING_SCALE = 1.12
function SC.RingIcon(parent, side)
    local ri = K.NewFrame("Frame", nil, parent)
    ri.icon = ri:CreateTexture(nil, "ARTWORK")
    ri.icon:SetPoint("CENTER")
    ri.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ri.mask = ri:CreateMaskTexture()
    ri.mask:SetAtlas("SquareMask")
    ri.mask:SetPoint("CENTER")
    ri.icon:AddMaskTexture(ri.mask)
    ri.ring = ri:CreateTexture(nil, "OVERLAY", nil, -1)
    ri.ring:SetPoint("CENTER")
    if not Atlas(ri.ring, "gamepad-actionbar-squareslot-border-normal") then ri.ring:Hide() end
    function ri:SetIcon(texture) self.icon:SetTexture(texture or 134400) end
    function ri:SetSide(n)
        self:SetSize(n, n)
        self.icon:SetSize(n, n)
        self.mask:SetSize(n, n)
        self.ring:SetSize(n * SC.RING_SCALE, n * SC.RING_SCALE)
    end
    ri:SetSide(side or 40)
    return ri
end

---------------------------------------------------------------------------
-- A capsule badge: small capitals on a rounded pill of its colour, its
-- round ends the halves of a disc. cap:Set(text, color) (nil: hidden)
---------------------------------------------------------------------------
function SC.Capsule(parent, height, size)
    height = height or 16
    local cap = K.NewFrame("Frame", nil, parent)
    cap:SetHeight(height)
    cap.parts = {}
    for i, coords in ipairs({ { 0, 0.5 }, false, { 0.5, 1 } }) do
        local t = cap:CreateTexture(nil, "BACKGROUND")
        if coords then
            t:SetTexture(K.TEX .. "ic_dot")
            t:SetTexCoord(coords[1], coords[2], 0, 1)
            t:SetSize(height / 2, height)
            t:SetPoint(i == 1 and "LEFT" or "RIGHT")
        else
            t:SetColorTexture(1, 1, 1, 1)
            t:SetPoint("TOPLEFT", height / 2, 0)
            t:SetPoint("BOTTOMRIGHT", -height / 2, 0)
        end
        cap.parts[i] = t
    end
    cap.text = SC.Text(cap, size or 9, nil, SC.BODY)
    cap.text:SetPoint("CENTER")
    function cap:Set(text, color)
        self:SetShown(text ~= nil)
        if not text then return end
        self.text:SetText(text)
        self.text:SetTextColor(color[1], color[2], color[3])
        for _, t in ipairs(self.parts) do t:SetVertexColor(color[1] * 0.35, color[2] * 0.35, color[3] * 0.35, 0.75) end
        self:SetWidth(self.text:GetStringWidth() + height)
    end
    cap:Hide()
    return cap
end

---------------------------------------------------------------------------
-- A soft band of gold light across a row, brightest in its middle and
-- fading out at both ends (the one the pad is on, as Immersion's dialog
-- lights its rows). band:SetLight(a)
---------------------------------------------------------------------------
function SC.Band(parent)
    local band = { halves = {} }
    local G = SC.GOLD
    for _, first in ipairs({ true, false }) do
        local t = parent:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint("TOP")
        t:SetPoint("BOTTOM")
        if first then
            t:SetPoint("LEFT")
            t:SetPoint("RIGHT", parent, "CENTER")
        else
            t:SetPoint("LEFT", parent, "CENTER")
            t:SetPoint("RIGHT")
        end
        t.first = first
        band.halves[#band.halves + 1] = t
    end
    function band:SetLight(a)
        for _, t in ipairs(self.halves) do
            t:SetShown(a > 0)
            if a > 0 and not pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(G[1], G[2], G[3], t.first and 0 or a),
                CreateColor(G[1], G[2], G[3], t.first and a or 0)) then
                t:SetColorTexture(G[1], G[2], G[3], a / 2)
            end
        end
    end
    band:SetLight(0)
    return band
end

---------------------------------------------------------------------------
-- Hold to act, in the scene's look: "Hold (the button) to Buy · its cost"
-- in Morpheus over a faint gold rule, a bright one growing out from its
-- middle as the hold comes (full: "Release to Buy"). The mouse holds it
-- down instead (hold.onDown / hold.onUp). hold:SetHold(p, key, verb, extra)
---------------------------------------------------------------------------
function SC.HoldLine(parent)
    local hold = K.NewFrame("Frame", nil, parent)
    hold:SetHeight(40)
    local G = SC.GOLD
    hold.base = SC.Rule(hold, 300, false, 0.35)
    hold.base:SetPoint("BOTTOM", 0, 2)
    hold.fill = hold:CreateTexture(nil, "ARTWORK")
    hold.fill:SetHeight(2)
    hold.fill:SetPoint("CENTER", hold.base, "CENTER")
    hold.fill:SetColorTexture(G[1], G[2], G[3], 1)
    hold.fill:Hide()
    hold.icon = IF.HoldIcon(hold, 22)
    hold.text = SC.Text(hold, 18, G)
    hold:EnableMouse(true)
    hold.lit = hold:CreateTexture(nil, "HIGHLIGHT")
    hold.lit:SetAllPoints()
    hold.lit:SetColorTexture(1, 1, 1, 1)
    if not pcall(hold.lit.SetGradient, hold.lit, "VERTICAL", CreateColor(G[1], G[2], G[3], 0.12), CreateColor(G[1], G[2], G[3], 0)) then
        hold.lit:SetColorTexture(G[1], G[2], G[3], 0.05)
    end
    hold:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.onDown then self.onDown() end
    end)
    hold:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.onUp then self.onUp() end
    end)
    function hold:SetHold(p, key, verb, extra)
        local full = p >= 1
        local w = self:GetWidth()
        if w and w > 0 then self.base:SetLength(w) end
        self.fill:SetShown(p > 0)
        self.fill:SetWidth(math.max(1, (w or 300) * p))
        self.fill:SetAlpha(full and 1 or 0.75)
        self.icon:SetKey(key)
        self.icon:SetProgress(p)
        -- (with the mouse no glyph: the line itself is held)
        local pad = IF.Input.Pad()
        self.icon:SetShown(pad)
        self.text:SetText((full and "Release to " or "Hold to ") .. verb
            .. (extra and ("  |cff9d917a·|r  |cfff0e6d0" .. extra .. "|r") or ""))
        local c = full and { 1, 0.95, 0.75 } or G
        self.text:SetTextColor(c[1], c[2], c[3])
        local iconW = pad and (self.icon:GetWidth() + 6) or 0
        local tw = iconW + self.text:GetStringWidth()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("LEFT", self, "CENTER", -tw / 2, 3)
        self.text:ClearAllPoints()
        self.text:SetPoint("LEFT", self, "CENTER", -tw / 2 + iconW, 3)
    end
    return hold
end

---------------------------------------------------------------------------
-- A word to click (the mouse's): grey, cream under the mouse. fn on a click
---------------------------------------------------------------------------
function SC.TextButton(parent, label, fn, size)
    local b = K.NewFrame("Button", nil, parent)
    b.text = SC.Text(b, size or 12, SC.GREY, SC.BODY)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetSize(b.text:GetStringWidth() + 12, (size or 12) + 10)
    b:SetScript("OnClick", function() fn() end)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(SC.CREAM[1], SC.CREAM[2], SC.CREAM[3]) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(SC.GREY[1], SC.GREY[2], SC.GREY[3]) end)
    return b
end

---------------------------------------------------------------------------
-- A row of a list, in the scene's look (the Sell, Auctions and Tasks
-- pages): nothing behind it but a faint gold rule under it; the item's
-- icon in the square ring (how many on its corner), its name, a grey line
-- under it, a price in Morpheus on the right, a capsule under that. The
-- picked one in a soft gold light, the game's cursor at its left while its
-- list has the pad. row:Fill({ icon, quality, count, name, nameColor,
-- line, price, tag = { text, color }, upgrade }), row:Lit(on, active)
---------------------------------------------------------------------------
SC.PRICE = { 1, 0.94, 0.82 }
function SC.Row(parent, height, side)
    local r = K.NewFrame("Button", nil, parent)
    r:SetHeight(height or 40)
    r.band = SC.Band(r)
    r.icon = SC.RingIcon(r, side or 28)
    r.icon:SetPoint("LEFT", 12, 0)
    r.upgrade = IF.Upgrades and IF.Upgrades.Arrow(r, "TOPLEFT", r.icon, "TOPLEFT", -5, 5)
    r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 4, -3)
    r.price = SC.Text(r, 14, SC.PRICE)
    r.name = SC.Text(r, 12, nil, SC.BODY)
    r.name:SetJustifyH("LEFT")
    r.line = SC.Text(r, 10, SC.GREY, SC.BODY)
    r.line:SetJustifyH("LEFT")
    r.tag = SC.Capsule(r, 14, 8)
    r.tag:SetPoint("BOTTOMRIGHT", -10, 4)
    r.rule = SC.Rule(r, 300, false, 0.15)
    r.rule:SetPoint("TOP", r, "BOTTOM", 0, -2)
    local hover = r:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)

    function r:Fill(o)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.quality or 1]
        self.icon:SetIcon(o.icon)
        if self.upgrade then self.upgrade:SetShown(o.upgrade and true or false) end
        local n = o.count or 0
        self.count:SetText(n > 1 and n or "")
        self.name:SetText(o.name or "...")
        local nc = o.nameColor or (((o.quality or 1) <= 1 or not c) and { 0.9, 0.9, 0.9 } or { c.r, c.g, c.b })
        self.name:SetTextColor(nc[1], nc[2], nc[3])
        local line = o.line and o.line ~= "" and o.line or nil
        self.line:SetText(line or "")
        self.price:SetText(o.price or "")
        self.tag:Set(o.tag and o.tag[1], o.tag and o.tag[2])
        -- (the price up when a capsule is under it, else in the middle; the
        -- name up when a line is under it, else in the middle)
        self.price:ClearAllPoints()
        if self.tag:IsShown() then self.price:SetPoint("TOPRIGHT", -10, -5) else self.price:SetPoint("RIGHT", -10, 0) end
        self.name:ClearAllPoints()
        if line then
            self.name:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 10, 1)
        else
            self.name:SetPoint("LEFT", self.icon, "RIGHT", 10, 0)
        end
        self.name:SetPoint("RIGHT", self.price, "LEFT", -8, 0)
        self.line:ClearAllPoints()
        self.line:SetPoint("BOTTOMLEFT", self.icon, "BOTTOMRIGHT", 10, -1)
        if self.tag:IsShown() then
            self.line:SetPoint("RIGHT", self.tag, "LEFT", -8, 0)
        else
            self.line:SetPoint("RIGHT", -10, 0)
        end
        local w = self:GetWidth()
        if w and w > 40 then self.rule:SetLength(w - 20) end
    end
    -- on: the picked one; active: its list has the pad
    function r:Lit(on, active)
        self.band:SetLight(on and (active and 0.18 or 0.07) or 0)
        local cursorOn = on and active and IF.Input.Pad()
        if cursorOn and not self.cursor then self.cursor = IF.Focus.Cursor(self) end
        if self.cursor then
            if cursorOn then self.cursor:Point(self) else self.cursor:Hide() end
        end
    end
    return r
end

---------------------------------------------------------------------------
-- A section's name in a list (the Sell page's "Sell here", the ready
-- tasks): in Morpheus in its colour, how many on the right in grey, a gold
-- rule under them. sec:Set(label, color, info)
---------------------------------------------------------------------------
function SC.Section(parent, height)
    local h = K.NewFrame("Frame", nil, parent)
    h:SetHeight(height or 40)
    h.text = SC.Text(h, 15, SC.GOLD)
    h.text:SetPoint("BOTTOMLEFT", 10, 7)
    h.info = SC.Text(h, 10, SC.GREY, SC.BODY)
    h.info:SetPoint("BOTTOMRIGHT", -10, 8)
    h.rule = SC.Rule(h, 300, false, 0.5)
    h.rule:SetPoint("BOTTOM", 0, 3)
    function h:Set(label, color, info)
        self.text:SetText(label or "")
        color = color or SC.GOLD
        self.text:SetTextColor(color[1], color[2], color[3])
        self.info:SetText(info or "")
        local w = self:GetWidth()
        if w and w > 40 then self.rule:SetLength(w - 10) end
    end
    return h
end

---------------------------------------------------------------------------
-- A column's title, in Morpheus (gold while its list has the pad), the
-- pad's glyph before it. title:Set(text, active, key)
---------------------------------------------------------------------------
function SC.Title(parent)
    local t = SC.Text(parent, 16, SC.GREY)
    function t:Set(text, active, key)
        local glyph = active and key and IF.Input.Pad() and (IF.GlyphText(key, 18) .. " ") or ""
        self:SetText(glyph .. text)
        local c = active and SC.GOLD or SC.GREY
        self:SetTextColor(c[1], c[2], c[3])
    end
    return t
end
