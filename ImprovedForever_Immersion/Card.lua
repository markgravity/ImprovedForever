-- A card in the Immersion look, for the world tooltip (Tooltip.lua) and the buff / debuff notices
-- (AuraNotice.lua): the spell diamonds' tile at the top with a picture in it, under it a gold
-- line running down, the words to the right of it (the name in Morpheus, the rest small), on
-- Spoken's subtitle band as the NPC dialog has it.
-- card:Update(elapsed, content) each frame: content = { key, sig, lines, portrait = fn(icon), tint }
-- or nil (nothing to show). It plays the whole cinematic itself: in (the band, the diamond
-- popping up, the line drawing down, each line of words sliding in one after another), out (the
-- same backwards, shorter), and between two contents (out fast, the new one laid out at 0, in
-- again). A content with the same key but another sig (a line changed) is laid out in place.
-- lines: { lt, lr, lg, lb, rt, rr, rg, rb } (left text and colour, right text and colour).
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot

local IN_TIME, OUT_TIME, SWAP_TIME = 0.6, 0.3, 0.2   -- (seconds: the whole timeline in, out, and out between two)
local ROW_SLIDE = 12                    -- (each line comes in from this far left)
local PAD_Y = 6
local MAX_W = 360
local TILE = 24
local BADGE = 18
local GLYPH = 22
local OBJECT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SPOKEN_BAND = "Interface\\AddOns\\Spoken\\Textures\\SubtitleBand"
local BAND_REACH, BAND_TOP_ROWS, BAND_BOTTOM_ROWS = 40, 28 / 64, 8 / 64
local BAND_TOP_FADE, BAND_BOTTOM_FADE = 40, 12

local Card = {}
Card.__index = Card
IN.Card = Card

function Card.New(name, opts)
    local self = setmetatable({}, Card)
    -- opts.seamless: another content while showing replaces the first in place (no out and in);
    -- opts.grace: seconds with nothing before it goes out (a gap between two things)
    self.opts = opts or {}
    local G = HS.GOLD
    local panel = CreateFrame("Frame", name, UIParent)
    -- (opts.strata: under the game's windows, as the game's own quest tracker is (LOW); else over all)
    panel:SetFrameStrata(self.opts.strata or "TOOLTIP")
    panel:EnableMouse(false)
    panel:Hide()
    self.panel = panel

    local tile = HS.Tile(panel, TILE)
    local across = tile.across
    self.tile, self.across, self.textX = tile, across, across + 10
    tile:ClearAllPoints()
    tile:SetPoint("CENTER", panel, "TOPLEFT", across / 2, -across / 2)
    tile.icon:SetSize(across * 0.72, across * 0.72)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetWidth(1)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", across / 2, -(across + 4))
    line:SetHeight(0.001)
    line:SetColorTexture(1, 1, 1, 1)
    self.line = line
    self:SetTint(G)

    -- (Spoken's band, as the NPC dialog draws it (NpcDialog.lua): its texture is 64 high, its top 28 rows
    -- a fade in, its last 8 a fade out; the fades kept this high however tall ours is)
    local band = CreateFrame("Frame", nil, panel)
    band:SetPoint("TOPLEFT", -BAND_REACH, 10)
    band:SetPoint("BOTTOMRIGHT", BAND_REACH, -4)
    band:SetFrameLevel(math.max(0, panel:GetFrameLevel() - 1))
    local function Slice(top, bottom)
        local t = band:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(SPOKEN_BAND)
        t:SetTexCoord(0, 1, top, bottom)
        return t
    end
    local head = Slice(0, BAND_TOP_ROWS)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(BAND_TOP_FADE)
    local foot = Slice(1 - BAND_BOTTOM_ROWS, 1)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(BAND_BOTTOM_FADE)
    local middle = Slice(BAND_TOP_ROWS, 1 - BAND_BOTTOM_ROWS)
    middle:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    middle:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
    self.band = band
    -- (an arrow on the diamond, the game's upgrade arrow (the bags' item upgrade one): a buff's up in
    -- green, a debuff's down in red, drifting a little the way it points, over and over)
    self.arrow = CreateFrame("Frame", nil, panel)
    self.arrow:SetSize(30, 30)
    self.arrow:SetFrameLevel(panel:GetFrameLevel() + 5)
    self.arrow.tex = self.arrow:CreateTexture(nil, "OVERLAY")
    self.arrow.tex:SetAllPoints()
    self.arrow:Hide()

    -- (a level under the diamond's foot, as the target header's: the game's small circle, the number
    -- in it coloured by how hard it is; a skull when too high to say)
    local badge = tile:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("CENTER", tile, "CENTER", 0, -tile.across / 2)
    local level = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    level:SetDrawLayer("OVERLAY", 3)
    level:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
    local skull = tile:CreateTexture(nil, "OVERLAY", nil, 4)
    skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
    skull:SetPoint("CENTER", badge, "CENTER")
    badge:Hide()
    skull:Hide()
    self.badge, self.level, self.skull = badge, level, skull

    -- (the pad buttons that run it, under the diamond's foot: content.keys, e.g. { "PADLTRIGGER", "PAD1" },
    -- in the style of the pad in use)
    self.glyphs = {}
    for i = 1, 3 do
        local g = tile:CreateTexture(nil, "OVERLAY", nil, 5)
        g:SetSize(GLYPH, GLYPH)
        g:Hide()
        self.glyphs[i] = g
    end

    self.rows, self.lineH, self.T, self.dir = {}, 0, 0, 0
    self.width = 0
    return self
end

-- The line's colour: a fade out downwards
function Card:SetTint(c)
    local t = self.tint
    if t and t[1] == c[1] and t[2] == c[2] and t[3] == c[3] then return end
    self.tint = c
    if not pcall(self.line.SetGradient, self.line, "VERTICAL", CreateColor(c[1], c[2], c[3], 0),
        CreateColor(c[1], c[2], c[3], 0.9)) then
        self.line:SetVertexColor(c[1], c[2], c[3], 0.6)
    end
end

-- The buttons shown under the diamond's foot (a list of pad keys, or nil for none), side by side
function Card:SetKeys(keys)
    local n = 0
    for _, key in ipairs(keys or {}) do
        local atlas = IF.GlyphAtlas(key)
        if atlas and n < #self.glyphs then
            n = n + 1
            self.glyphs[n]:SetAtlas(atlas)
        end
    end
    local total = n * GLYPH + (n - 1) * 2
    for i, g in ipairs(self.glyphs) do
        g:SetShown(i <= n)
        g:ClearAllPoints()
        g:SetPoint("CENTER", self.tile, "CENTER", -total / 2 + GLYPH / 2 + (i - 1) * (GLYPH + 2), -self.tile.across / 2 - 2)
    end
end

-- A card's picture: a texture (an icon), else the plain mark
function Card.Icon(icon, texture)
    if texture then
        icon:SetTexture(texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        icon:SetTexture(OBJECT_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

function Card:Row(i)
    local r = self.rows[i]
    if r then return r end
    r = {}
    r.left = self.panel:CreateFontString(nil, "OVERLAY")
    r.left:SetJustifyH("LEFT")
    r.right = self.panel:CreateFontString(nil, "OVERLAY")
    r.right:SetJustifyH("RIGHT")
    for _, fs in ipairs({ r.left, r.right }) do
        fs:SetWordWrap(false)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        local ok = i == 1 and fs:SetFont(HS.FONT, 22, "")
        if not ok then fs:SetFont(STANDARD_TEXT_FONT, i == 1 and 20 or 13, "") end
    end
    self.rows[i] = r
    return r
end

-- Lays the words out: where each line, the width and height should be (the goals). Shown from nothing
-- they are taken at once; while showing, Draw eases to them, so another content moves and
-- resizes the card smoothly instead of jumping.
function Card:Layout(lines)
    local snap = self.snap
    local y, width = -(self.across / 2 - 10), 0
    for i, l in ipairs(lines) do
        local r = self:Row(i)
        r.ty = y
        if snap or not r.y then r.y = y end
        if snap or not r.a then r.a = snap and 1 or 0 end
        r.left:SetText(l.lt or "")
        r.left:SetTextColor(l.lr or 1, l.lg or 1, l.lb or 1)
        r.right:SetText(l.rt or "")
        r.right:SetTextColor(l.rr or 1, l.rg or 1, l.rb or 1)
        local lw, rw = r.left:GetStringWidth(), r.right:GetStringWidth()
        width = math.max(width, lw + (l.rt and rw + 16 or 0))
        r.has, r.hasRight = true, l.rt ~= nil
        r.h = r.left:GetStringHeight()
        y = y - r.h - (i == 1 and 5 or 3)
    end
    for i = #lines + 1, #self.rows do
        local r = self.rows[i]
        r.has = false
        if snap then r.a = 0 end
    end
    self.count = #lines
    self.tw = math.min(MAX_W, width)
    self.th = math.max(-y + PAD_Y, self.across + 24)
    if snap or not self.height then
        self.width, self.height = self.tw, self.th
    end
end

local function Toward(cur, goal, k)
    local d = goal - cur
    if math.abs(d) < 0.15 then return goal end
    return cur + d * k
end

function Card:Draw(T)
    local Ease = HS.Ease
    local k = 1 - math.exp(-(self.dt or 0) * 14)
    self.width, self.height = Toward(self.width, self.tw, k), Toward(self.height, self.th, k)
    self.panel:SetSize(self.textX + self.width, self.height)
    self.lineH = self.height - (self.across + 4)
    self.band:SetAlpha(Ease(T, 0, 0.5))
    local pop = Ease(T, 0, 0.4)
    local scale = math.max(0.01, 0.5 + 0.5 * HS.Pop(pop))
    local tile, across = self.tile, self.across
    tile:SetScale(scale)
    tile:ClearAllPoints()
    tile:SetPoint("CENTER", self.panel, "TOPLEFT", across / 2 / scale, -across / 2 / scale)
    tile:SetAlpha(pop)
    self.line:SetHeight(math.max(0.001, self.lineH * Ease(T, 0.2, 0.75)))
    -- (each line a beat after the one before, the last one still in before the timeline ends:
    -- the beat shrinks for a long card)
    local beat = math.min(0.07, 0.3 / math.max(1, (self.count or 1) - 1))
    for i, r in ipairs(self.rows) do
        local from = 0.3 + beat * (i - 1)
        r.y = Toward(r.y or 0, r.ty or 0, k)
        r.a = Toward(r.a or 0, r.has and 1 or 0, k)
        local e = Ease(T, from, from + 0.4) * r.a
        local x = self.textX - ROW_SLIDE * (1 - Ease(T, from, from + 0.4))
        r.left:ClearAllPoints()
        r.left:SetPoint("TOPLEFT", self.panel, "TOPLEFT", x, r.y or 0)
        r.right:ClearAllPoints()
        r.right:SetPoint("TOPRIGHT", self.panel, "TOPLEFT", x + self.width, r.y or 0)
        r.left:SetAlpha(e)
        r.right:SetAlpha(e)
        r.left:SetShown(e > 0.01)
        r.right:SetShown(r.hasRight and e > 0.01 or false)
    end
    local arrow = self.arrow
    if arrow:IsShown() then
        local phase = (GetTime() % 1.6) / 1.6
        local drift = (self.arrowUp and 1 or -1) * 7 * phase
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", self.panel, "TOPLEFT", across * 0.86, -across * 0.8 + drift)
        arrow:SetAlpha(pop * math.sin(math.pi * phase) ^ 0.7)
    end
end

function Card:Apply(content)
    self.snap = self.T <= 0 or not self.panel:IsShown()
    self:Layout(content.lines)
    self.snap = nil
    self:SetTint(content.tint or IN.HeaderSlot.GOLD)
    if content.portrait then content.portrait(self.tile.icon) end
    local lv = content.level
    self.badge:SetShown(lv ~= nil)
    self.skull:SetShown(lv ~= nil and lv.text == nil)
    if lv and lv.text then
        self.level:SetText(lv.text)
        self.level:SetTextColor(lv.color[1], lv.color[2], lv.color[3])
    else
        self.level:SetText("")
    end
    self:SetKeys(content.keys)
    local a = content.arrow
    if a then
        local tex = self.arrow.tex
        tex:SetAtlas("bags-greenarrow")
        tex:SetTexCoord(0, 1, a.up and 0 or 1, a.up and 1 or 0)
        tex:SetDesaturated(not a.up)
        tex:SetVertexColor(a.color[1], a.color[2], a.color[3])
        self.arrowUp = a.up
        self.arrow:Show()
    else
        self.arrow:Hide()
    end
    self.key, self.sig = content.key, content.sig
    self.shownContent = content
end

-- Where the cards sit: the screen's top left corner, the top this far down (a share of the
-- screen's height), one under another when several show. card:Dock(above): above = the cards
-- over it, in order; it goes under the lowest one showing, else in the corner. Call each frame.
local CORNER_X, CORNER_TOP, STACK_GAP = 40, 0.15, 14
Card.CORNER_X = CORNER_X
-- The sidebar (these cards, top left): its top padding (a share of the screen's height) and its scale,
-- the player's own (the Body tab's Sidebar: sidebarTop %, sidebarScale %)
local sidebarRev = 0
function Card.Top()
    local s = IF.db and IN.Settings()
    return math.max(0, math.min(60, tonumber(s and s.sidebarTop) or CORNER_TOP * 100)) / 100
end
function Card.Scale()
    local s = IF.db and IN.Settings()
    return math.max(0.5, math.min(1.5, (tonumber(s and s.sidebarScale) or 100) / 100))
end
Card.CORNER_TOP = CORNER_TOP     -- (the default)
function Card.ApplySidebar() sidebarRev = sidebarRev + 1 end

-- After a login, a cinematic or movie, or a screen change: the cards laid out again and docked again
-- (their words may have been measured while the UI was hidden or not ready, and the same content
-- would never lay them out again)
Card.gen = 0
local regen = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CINEMATIC_STOP", "STOP_MOVIE", "PLAY_MOVIE", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "PLAYER_LOGIN" }) do
    pcall(regen.RegisterEvent, regen, e)
end
regen:SetScript("OnEvent", function() Card.gen = Card.gen + 1 end)

function Card:Dock(above)
    local anchor
    for i = #above, 1, -1 do
        if above[i] and above[i]:Active() then anchor = above[i] break end
    end
    local h = UIParent:GetHeight()
    if anchor == self.dockAnchor and h == self.dockHeight and self.dockRev == sidebarRev and self.dockGen == Card.gen then return end
    self.dockAnchor, self.dockHeight, self.dockRev, self.dockGen = anchor, h, sidebarRev, Card.gen
    local scale = Card.Scale()
    self.panel:SetScale(scale)
    self.panel:ClearAllPoints()
    if anchor then
        self.panel:SetPoint("TOPLEFT", anchor.panel, "BOTTOMLEFT", 0, -STACK_GAP)
    else
        -- (offsets in the card's own scale)
        self.panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", CORNER_X / scale, -h * Card.Top() / scale)
    end
end

-- Is it showing anything (in, or on its way out)?
function Card:Active()
    return self.panel:IsShown()
end

function Card:Update(elapsed, content)
    self.dt = elapsed
    -- (laid out again after a login / cinematic: the same content, measured now)
    if self.gen ~= Card.gen then
        self.gen = Card.gen
        if self.shownContent and self.sig then
            self.snap = true
            self:Layout(self.shownContent.lines)
            self.snap = nil
        end
    end
    -- (the what's-new tour is up, in this corner: every card out of its way)
    local WN = ImprovedForever.WhatsNew
    if content and WN and WN.Active() then content = nil end
    -- (a window open: nothing over it, the card goes out as with nothing to say)
    -- (opts.always: the quest tracker stays while windows are open)
    if content and not self.opts.always and ImprovedForever.Focus and ImprovedForever.Focus.AnyOpen() then content = nil end
    local grace = self.opts.grace
    if content then
        self.gone = 0
    elseif grace and self.sig and self.dir == 1 then
        -- (nothing for a moment: kept as it is, in case another comes straight after)
        self.gone = (self.gone or 0) + elapsed
        if self.gone < grace then
            self:Draw(self.T)
            return
        end
    end
    if content then
        if not self.sig then
            self:Apply(content)
            self.dir = 1
        elseif content.sig ~= self.sig then
            if content.key == self.key or self.opts.seamless then
                self:Apply(content)
                self.pending = nil
                self.dir, self.swapping = 1, false
            elseif not self.pending or self.pending.sig ~= content.sig then
                self.pending = content
                self.dir, self.swapping = -1, true
            end
        elseif not self.pending then
            self.dir, self.swapping = 1, false
        end
    else
        self.pending, self.swapping, self.dir = nil, false, -1
    end
    if self.dir == 1 then
        self.T = math.min(1, self.T + elapsed / IN_TIME)
    elseif self.dir == -1 then
        self.T = math.max(0, self.T - elapsed / (self.swapping and SWAP_TIME or OUT_TIME))
    end
    if self.T <= 0 then
        if self.pending then
            self:Apply(self.pending)
            self.pending, self.swapping, self.dir = nil, false, 1
        else
            if self.panel:IsShown() then self.panel:Hide() end
            self.key, self.sig, self.dir = nil, nil, 0
            return
        end
    end
    self:Draw(self.T)
    if not self.panel:IsShown() then self.panel:Show() end
end
