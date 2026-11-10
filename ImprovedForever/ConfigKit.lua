-- The configuration panel's parts, adapted from Easy Controller - Forever's
-- ConfigKit (moust4ki, MIT License, see LICENSE-EasyController.md):
-- its colours and type, rounded boxes, gamepad glyphs, the help bar's hints,
-- the detail panel and buttons. Menu.lua builds the window out of them.
local _, IF = ...

local K = {}
IF.ConfigKit = K

local TEX = "Interface\\AddOns\\ImprovedForever\\textures\\"
-- (Friz Quadrata has Latin letters only: a Russian, Korean or Chinese client gets the game's own
-- font, else translated names are rows of empty squares: issue #12)
local LOCALE = GetLocale()
local FONT = (LOCALE == "ruRU" or LOCALE == "koKR" or LOCALE == "zhCN" or LOCALE == "zhTW")
    and STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
K.FONT = FONT
K.TEX = TEX

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

K.C = {
    title = hex("F2C43C"), focus = hex("FFD24A"), dimGold = hex("C9A25A"), focusText = hex("FFF3D0"),
    cream = hex("EFE4C8"), cream2 = hex("D8CCB0"), tab = hex("E6DCC4"), rail = hex("CBBD9C"),
    help = hex("B9AB8C"), grey = hex("9D917A"), disabled = hex("6F6452"),
    bronze = hex("7A5D36"), line1 = hex("5A4630"), line2 = hex("4A3A26"), line3 = hex("3A2C1D"),
    control = hex("6B5235"), boxEdge = hex("7A6448"), boxOff = hex("4A3C2A"), arrowOff = hex("5A4C3A"),
    bg = hex("16110C"), controlBg = hex("0F0B07"), boxBg = hex("0B0805"), pressed = hex("2A1F12"),
    slot = hex("D9A93A"), info = hex("9FD8E2"), fill = hex("8A6A2A"),
    danger = hex("FF7A5C"), dangerBg = hex("4A140E"), dangerText = hex("FFE0D6"), warn = hex("F0A090"),
    inner = hex("2A1F14"), white = { 1, 1, 1 }, black = { 0, 0, 0 },
    -- The wheels: a slot's kind, empty dots, the editor's boxes
    spell = hex("2F4A73"), item = hex("6B4A1C"), macro = hex("4F3466"), emptyDot = hex("6B5A44"),
    iconBg = hex("3E3A33"), panel = hex("120D08"), yours = hex("5FC0D0"), eventOff = hex("7A6E5A"),
}
local C = K.C

-- Forever's gamepad navigation hooks the global CreateFrame and refreshes
-- its button groups from the caller's (tainted) context. Creating frames
-- without a parent and parenting them afterwards isn't watched.
function K.NewFrame(frameType, name, parent, template)
    local f = CreateFrame(frameType, name, nil, template)
    if parent then
        f:SetParent(parent)
    end
    return f
end

---------------------------------------------------------------------------
-- Type: Friz Quadrata for titles and labels, the chat's font for help texts
---------------------------------------------------------------------------
function K.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function chatFont()
    return (ChatFontNormal and ChatFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
end

function K.ChatText(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(chatFont(), size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH("LEFT")
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

-- A solid colour texture
function K.Solid(parent, color, alpha, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    return t
end

-- 9-slice: the `texCorner` px corners of a texW x texH texture are drawn at
-- `corner` px; edges and centre stretch.
function K.NineSlice(frame, file, texW, texH, texCorner, corner, layer)
    local u, v = texCorner / texW, texCorner / texH
    local cols = { { 0, u }, { u, 1 - u }, { 1 - u, 1 } }
    local rows = { { 0, v }, { v, 1 - v }, { 1 - v, 1 } }
    local parts = {}
    for r = 1, 3 do
        for c = 1, 3 do
            local t = frame:CreateTexture(nil, layer or "ARTWORK")
            t.coords = { cols[c][1], cols[c][2], rows[r][1], rows[r][2] }
            parts[#parts + 1] = t
        end
    end
    local tl, t, tr, l, m, r, bl, b, br = unpack(parts)
    tl:SetPoint("TOPLEFT"); tl:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT"); tr:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT"); bl:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT"); br:SetSize(corner, corner)
    t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    b:SetPoint("TOPLEFT", bl, "TOPRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    r:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")

    local slice = { parts = parts }
    function slice:SetFile(name)
        for _, p in ipairs(self.parts) do
            p:SetTexture(TEX .. name)
            p:SetTexCoord(unpack(p.coords))
        end
    end
    function slice:SetShown(shown)
        for _, p in ipairs(self.parts) do p:SetShown(shown) end
    end
    slice:SetFile(file)
    return slice
end

---------------------------------------------------------------------------
-- Rounded boxes: nine-slices of the ic_box textures (32 texels for 16 px,
-- corners of 4 px), tinted
---------------------------------------------------------------------------
function K.Slice(parent, file, layer, sub)
    local s = { parts = {} }
    local u = 8 / 32
    local cuts = { { 0, u }, { u, 1 - u }, { 1 - u, 1 } }
    for r = 1, 3 do
        for c = 1, 3 do
            local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
            t:SetTexture(TEX .. file)
            t:SetTexCoord(cuts[c][1], cuts[c][2], cuts[r][1], cuts[r][2])
            s.parts[#s.parts + 1] = t
        end
    end
    local tl, t, tr, l, m, rt, bl, b, br = unpack(s.parts)
    function s:SetPoints(region, inset)
        inset = inset or 0
        for _, p in ipairs(self.parts) do p:ClearAllPoints() end
        tl:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset)
        tr:SetPoint("TOPRIGHT", region, "TOPRIGHT", -inset, -inset)
        bl:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", inset, inset)
        br:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset)
        for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(4, 4) end
        t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
        b:SetPoint("TOPLEFT", bl, "TOPRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
        l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
        rt:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rt:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
        m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    end
    function s:SetColor(color, alpha)
        for _, p in ipairs(self.parts) do p:SetVertexColor(color[1], color[2], color[3], alpha or 1) end
    end
    function s:SetShown(shown)
        for _, p in ipairs(self.parts) do p:SetShown(shown) end
    end
    s:SetPoints(parent)
    return s
end

-- A filled box with an edge: radius 3 (edge 2) or 4 (edge 1 or 2)
function K.Box(parent, radius, edge, layer, sub)
    local box = { fill = K.Slice(parent, format("ic_box%d", radius), layer, sub) }
    if edge then box.line = K.Slice(parent, format("ic_box%d_line%d", radius, edge), layer, (sub or 0) + 1) end
    function box:SetPoints(region, inset)
        self.fill:SetPoints(region, inset)
        if self.line then self.line:SetPoints(region, inset) end
    end
    -- No colour: that part stays hidden (an edge alone, a fill alone)
    function box:SetColors(fill, fillAlpha, line, lineAlpha)
        self.noFill, self.noLine = fill == nil, line == nil
        self.fill:SetShown(fill ~= nil and not self.hidden)
        if fill then self.fill:SetColor(fill, fillAlpha) end
        if self.line then
            self.line:SetShown(line ~= nil and not self.hidden)
            if line then self.line:SetColor(line, lineAlpha) end
        end
    end
    function box:SetShown(shown)
        self.hidden = not shown
        self.fill:SetShown(shown and not self.noFill)
        if self.line then self.line:SetShown(shown and not self.noLine) end
    end
    return box
end

---------------------------------------------------------------------------
-- Glyphs: the game's own, in the style of the pad in hand (Pad.lua), else
-- ours (textures/ic_g_*)
---------------------------------------------------------------------------
local FALLBACK = {
    A = "ic_g_a", B = "ic_g_b", X = "ic_g_x", Y = "ic_g_y", LB = "ic_g_lb", RB = "ic_g_rb",
    LT = "ic_g_lt", RT = "ic_g_rt", LS = "ic_g_ls", RS = "ic_g_rs",
    DPAD = "ic_g_dpad", DPAD_LR = "ic_g_dpad_lr", DPAD_UP = "ic_g_dpad_up",
}

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function K.SetGlyph(tex, key)
    local atlas = IF.GlyphAtlas(key)
    if atlas then
        tex:SetAtlas(atlas)
        return
    end
    tex:SetTexture(TEX .. (FALLBACK[key] or "ic_g_a"))
    tex:SetTexCoord(0, 1, 0, 1)
end

-- A glyph; keys without an image as a grey pill with the button's name
function K.Glyph(parent, size)
    local g = K.NewFrame("Frame", nil, parent)
    g:SetSize(size, size)
    g.size = size
    g.tex = g:CreateTexture(nil, "ARTWORK")
    g.tex:SetAllPoints()
    local h = math.floor(size * 0.72 + 0.5)
    g.chip = {}
    for i, cut in ipairs({ { 0, 22 / 64 }, { 22 / 64, 42 / 64 }, { 42 / 64, 1 } }) do
        local t = g:CreateTexture(nil, "ARTWORK")
        t:SetTexture(TEX .. "ic_chip")
        t:SetTexCoord(cut[1], cut[2], 10 / 64, 54 / 64)
        t:SetHeight(h)
        g.chip[i] = t
    end
    g.chip[1]:SetPoint("LEFT")
    g.chip[1]:SetWidth(h / 2)
    g.chip[3]:SetPoint("RIGHT")
    g.chip[3]:SetWidth(h / 2)
    g.chip[2]:SetPoint("LEFT", g.chip[1], "RIGHT")
    g.chip[2]:SetPoint("RIGHT", g.chip[3], "LEFT")
    g.label = K.ChatText(g, math.max(9, math.floor(size * 0.38)), C.white)
    g.label:SetPoint("CENTER", 0, 0)
    g.label:SetJustifyH("CENTER")
    function g:Set(key)
        local image = IF.GlyphAtlas(key) ~= nil or FALLBACK[key] ~= nil
        self.tex:SetShown(image)
        for _, t in ipairs(self.chip) do t:SetShown(not image) end
        self.label:SetShown(not image)
        if image then
            K.SetGlyph(self.tex, key)
            self:SetSize(self.size, self.size)
        else
            self.label:SetText(IF.ButtonName(key))
            self:SetWidth(math.max(self.size * 0.75, self.label:GetStringWidth() + h * 0.6))
        end
        self:Show()
    end
    return g
end

-- A row of glyphs ("L1", "+", "R3": "+" is a plus sign): returns its width
function K.GlyphRow(parent, size)
    local row = K.NewFrame("Frame", nil, parent)
    row:SetSize(1, size)
    row.items = {}
    function row:Set(keys)
        local x = 0
        for i, key in ipairs(keys or {}) do
            local item = self.items[i]
            if not item then
                item = { glyph = K.Glyph(self, size), plus = K.Text(self, math.max(12, math.floor(size * 0.6)), C.cream) }
                item.plus:SetText("+")
                self.items[i] = item
            end
            item.glyph:ClearAllPoints()
            item.plus:ClearAllPoints()
            if key == "+" then
                item.glyph:Hide()
                item.plus:Show()
                item.plus:SetPoint("LEFT", x + 2, 0)
                x = x + item.plus:GetStringWidth() + 5
            else
                item.plus:Hide()
                item.glyph:Set(key)
                item.glyph:SetPoint("LEFT", x, 0)
                x = x + item.glyph:GetWidth() + 1
            end
        end
        for i = #(keys or {}) + 1, #self.items do
            self.items[i].glyph:Hide()
            self.items[i].plus:Hide()
        end
        self:SetWidth(math.max(1, x))
        return x
    end
    return row
end

-- A help bar hint: { keys, verb, press (the key a click presses) }
function K.H(keys, verb, press)
    return { keys = keys, verb = verb, press = press or keys[1] }
end

-- A help bar hint: its glyph(s), then a short verb; a click presses its key.
-- style = { glyph = px, font = pt, color } (default 30 / 15 / cream)
function K.Hint(parent, onPress, style)
    style = style or {}
    local size = style.glyph or 30
    local h = K.NewFrame("Button", nil, parent)
    h:SetHeight(size)
    h.glyphs = K.GlyphRow(h, size)
    h.glyphs:SetPoint("LEFT")
    h.verb = K.Text(h, style.font or 15, style.color or C.cream)
    h:SetScript("OnClick", function(self) if self.press then onPress(self.press) end end)
    function h:Set(hint)
        local w = self.glyphs:Set(hint.keys)
        self.verb:ClearAllPoints()
        self.verb:SetPoint("LEFT", w + 6, 0)
        self.verb:SetText(hint.verb or "")
        self.press = hint.press
        self:SetWidth(w + 6 + self.verb:GetStringWidth())
        self:Show()
    end
    return h
end

---------------------------------------------------------------------------
-- The detail panel (right): what has the focus, explained. A title, a
-- state tag (a dot and a word), the help text, a cyan info line
---------------------------------------------------------------------------
function K.Detail(parent, width)
    local d = K.NewFrame("Frame", nil, parent)
    d:SetWidth(width)
    d.box = K.Box(d, 4, 1, "BACKGROUND", 1)
    d.box:SetPoints(d)
    d.box:SetColors(C.black, 0.72, C.line1, 1)
    local inner = width - 28
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(40, 40)
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.title = K.Text(d, 19, C.title)
    d.title:SetWidth(inner)
    d.title:SetWordWrap(true)
    d.title:SetSpacing(5)
    d.dot = d:CreateTexture(nil, "ARTWORK")
    d.dot:SetTexture(TEX .. "ic_dot")
    d.dot:SetSize(10, 10)
    d.tag = K.ChatText(d, 13, C.cream)
    d.body = K.ChatText(d, 14, C.cream2)
    d.body:SetWidth(inner)
    d.body:SetWordWrap(true)
    d.body:SetSpacing(6)
    d.extra = K.ChatText(d, 14, C.info)
    d.extra:SetWidth(inner)
    d.extra:SetWordWrap(true)
    d.extra:SetSpacing(6)
    -- content = { icon, title, tag, tagColor, body, extra }
    function d:Set(content)
        content = content or {}
        local last
        local function place(region, gap)
            region:ClearAllPoints()
            if last then
                region:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -(gap or 10))
            else
                region:SetPoint("TOPLEFT", self, "TOPLEFT", 14, -14)
            end
            last = region
        end
        self.icon:SetShown(content.icon ~= nil)
        if content.icon then
            self.icon:SetTexture(content.icon)
            place(self.icon)
        end
        self.title:SetText(content.title or "")
        place(self.title)
        self.dot:SetShown(content.tag ~= nil)
        self.tag:SetShown(content.tag ~= nil)
        if content.tag then
            place(self.dot)
            local tc = content.tagColor or C.grey
            self.dot:SetVertexColor(tc[1], tc[2], tc[3])
            self.tag:ClearAllPoints()
            self.tag:SetPoint("LEFT", self.dot, "RIGHT", 8, 0)
            self.tag:SetText(content.tag)
        end
        self.body:SetShown(content.body ~= nil and content.body ~= "")
        if self.body:IsShown() then
            self.body:SetText(content.body)
            place(self.body)
        end
        self.extra:SetShown(content.extra ~= nil)
        if content.extra then
            self.extra:SetText(content.extra)
            place(self.extra)
        end
    end
    return d
end

---------------------------------------------------------------------------
-- A button of the ic_btn textures. States: active (the focus, the open
-- tab), armed (a destructive one asking again: red), disabled (faded)
---------------------------------------------------------------------------
function K.Button(parent, size)
    local b = K.NewFrame("Button", nil, parent)
    b.slice = K.NineSlice(b, "ic_btn_normal", 128, 32, 6, 6, "ARTWORK")
    b.armedBox = K.Box(b, 4, 2, "ARTWORK", 2)
    b.armedBox:SetPoints(b)
    b.armedBox:SetColors(C.dangerBg, 1, C.danger, 1)
    b.armedBox:SetShown(false)
    b.label = K.Text(b, size or 15, C.tab)
    b.label:SetPoint("LEFT", 6, 0)
    b.label:SetPoint("RIGHT", -6, 0)
    b.label:SetJustifyH("CENTER")
    b.state = {}
    function b:SetState(state)
        self.state = state or {}
        self:Render()
    end
    function b:Render()
        local st = self.state
        self.armedBox:SetShown(st.armed and true or false)
        self.slice:SetShown(not st.armed)
        if st.armed then
            self.label:SetTextColor(unpack(C.dangerText))
        else
            local on = st.active or st.focus
            self.slice:SetFile(on and "ic_btn_active" or (self.hover and not st.disabled and "ic_btn_hover" or "ic_btn_normal"))
            self.label:SetTextColor(unpack(st.disabled and C.disabled or (on and C.focus or C.tab)))
        end
        self:SetAlpha(st.disabled and 0.45 or 1)
    end
    b:SetScript("OnEnter", function(self)
        self.hover = true
        self:Render()
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = false
        self:Render()
    end)
    b:Render()
    return b
end

---------------------------------------------------------------------------
-- Icons: a texture path, a file ID, or an atlas name
---------------------------------------------------------------------------
function K.SetIcon(tex, icon)
    if type(icon) == "string" and hasAtlas(icon) then
        tex:SetAtlas(icon)
    else
        tex:SetTexture(icon or 134400)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

function K.RoundIcon(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(t)
    if hasAtlas("CircleMask") then
        mask:SetAtlas("CircleMask")
    else
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    t:AddMaskTexture(mask)
    return t
end

---------------------------------------------------------------------------
-- A round slot (ic_slot): the wheel editor's slots. An icon cut round on
-- its dark disc, a "+", the focus glow, the target's dashed ring.
---------------------------------------------------------------------------
function K.Slot(parent, size, iconSize)
    local s = K.NewFrame("Button", nil, parent)
    s:SetSize(size, size)
    s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetTexture(TEX .. "ic_slot")
    s.bg:SetAllPoints()
    s.disc = s:CreateTexture(nil, "ARTWORK", nil, 0)
    s.disc:SetTexture(TEX .. "ic_dot")
    s.disc:SetSize(iconSize, iconSize)
    s.disc:SetPoint("CENTER")
    s.icon = K.RoundIcon(s, iconSize, "ARTWORK")
    s.icon:SetDrawLayer("ARTWORK", 1)
    s.icon:SetPoint("CENTER")
    s.hatch = s:CreateTexture(nil, "ARTWORK", nil, 2)
    s.hatch:SetTexture(TEX .. "ic_hatch")
    s.hatch:SetSize(iconSize, iconSize)
    s.hatch:SetPoint("CENTER")
    s.plus = K.Text(s, size >= 52 and 20 or 18, C.dimGold, "OVERLAY")
    s.plus:SetPoint("CENTER", 0, 1)
    s.plus:SetJustifyH("CENTER")
    s.plus:SetText("+")
    s.glow = s:CreateTexture(nil, "OVERLAY", nil, 3)
    s.glow:SetTexture(TEX .. "ic_slot_glow")
    s.glow:SetBlendMode("ADD")
    s.glow:SetSize(math.floor(size * 1.46 + 0.5), math.floor(size * 1.46 + 0.5))
    s.glow:SetPoint("CENTER")
    s.dash = s:CreateTexture(nil, "OVERLAY", nil, 4)
    s.dash:SetTexture(TEX .. "ic_ring_dash")
    s.dash:SetVertexColor(C.focus[1], C.focus[2], C.focus[3])
    s.dash:SetSize(size + 10, size + 10)
    s.dash:SetPoint("CENTER")
    -- look = { icon, discColor, plus, hatch (off), glow, dash }
    function s:SetLook(look)
        if look.icon then K.SetIcon(self.icon, look.icon) end
        self.icon:SetShown(look.icon ~= nil)
        local dc = look.discColor
        self.disc:SetShown(dc ~= nil)
        if dc then self.disc:SetVertexColor(dc[1], dc[2], dc[3]) end
        self.plus:SetShown(look.plus and true or false)
        self.hatch:SetShown(look.hatch and true or false)
        self.icon:SetDesaturated(look.hatch and true or false)
        self.glow:SetShown(look.glow and true or false)
        self.dash:SetShown(look.dash and true or false)
    end
    return s
end

---------------------------------------------------------------------------
-- The lists picker: a kicker and a title, its lists' tabs (L1 / R1), then
-- the entries with their sections (L2 / R2 switch lists). def = { kicker, title, lists = { { label,
-- entries = function() return { { header } or { action, name, icon, sub } }
-- end } }, onChoose = function(entry), onBack = function(), marked =
-- function(entry) (a diamond: already there), current, rows = 10 }
---------------------------------------------------------------------------
local PICK_ROW, PICK_HEAD = 32, 28

-- A row's slot: a piece of the wheel's own art (cut from inside its left
-- segment: the same see-through dark fill) in the wheel's grey metal rim
-- (dark edges, a lighter bevel on the inside)
local WHEEL_ATLAS = "gamepad-radial-menu-wheelbg"
local WHEEL_CUT = { 0.11, 0.29, 0.43, 0.57 } -- left, right, top, bottom of the atlas
local RIM = {
    { size = 1, color = { 0.04, 0.035, 0.03, 1 } },   -- outer edge
    { size = 3, color = { 0.30, 0.29, 0.26, 1 } },    -- the metal
    { size = 1, color = { 0.46, 0.44, 0.39, 0.9 } },  -- bevel
    { size = 1, color = { 0.05, 0.04, 0.03, 0.9 } },  -- inner edge
}

-- Tabs with one slot in the middle (Touchpad, Vibration, General): their
-- lists' rings centred this far to the side, so the lists sit close to it
---------------------------------------------------------------------------
-- The config tabs' two layouts. Every tab is one or the other:
--
--   Stage (Wheels, General): a big thing in the middle of the screen (the
--     wheel, the controller), a list down its left and one down its right,
--     each K.GAP clear of its edges, centred on its middle up and down.
--     STAGE = K.Stage(half, mid): half its width, its middle's y, from the
--     screen's centre. The left list's rows from K.CenterTop(STAGE.mid,
--     shown); the picker: p:Center(f, STAGE.picker, STAGE.mid) after each
--     render (its rows centred, its list's name and tabs above them).
--
--   Columns (Gather, Vibration): three columns K.GAP apart, their tops on
--     one line: the list on the left, the choices in the middle (centred on
--     the screen), and what is selected on the right: its icon, its value,
--     what it does (K.ColumnDetail). K.COLS.
--
-- Either way: the left list's rows are K.Segment rows (200 wide) placed by
-- K.RailWindow / K.RowY and seg:Place(f, y, layout.rail); the right list is
-- a K.Picker (rows 316 wide, 12 into it) at TOPLEFT layout.picker,
-- layout.top from the centre.
---------------------------------------------------------------------------
K.GAP = 24
local RAIL_W, LIST_W = 200, 316

function K.Stage(half, mid)
    return {
        mid = mid,
        rail = -(half + K.GAP + RAIL_W / 2),  -- the left list's rows' centre x
        picker = half + K.GAP - 12,           -- the picker's left
        right = half + K.GAP,                 -- the right side's left edge
    }
end

K.COLS = {
    top = 200,
    detailW = 300,
    rail = -(LIST_W / 2 + K.GAP + RAIL_W / 2),  -- the list's rows' centre x
    picker = -LIST_W / 2 - 12,                   -- the picker's left (rows centred)
    detail = LIST_W / 2 + K.GAP + 150,           -- the detail's centre x
}

-- The Columns layout's right column: the selected thing's icon (a slot:
-- onClick when clicked), its value, what it does under it
function K.ColumnDetail(f, onClick)
    local d = {}
    d.big = K.Slot(f, 120, 86)
    d.big:SetPoint("TOP", f, "CENTER", K.COLS.detail, K.COLS.top - 12)
    if onClick then d.big:SetScript("OnClick", onClick) end
    d.value = K.Text(f, 16, C.title)
    d.value:SetPoint("TOP", d.big, "BOTTOM", 0, -30)
    d.value:SetWidth(K.COLS.detailW)
    d.value:SetJustifyH("CENTER")
    d.note = K.Text(f, 12, C.help)
    d.note:SetPoint("TOP", d.value, "BOTTOM", 0, -8)
    d.note:SetWidth(K.COLS.detailW)
    d.note:SetJustifyH("CENTER")
    d.note:SetWordWrap(true)
    return d
end

local function WheelFill(texture)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(WHEEL_ATLAS)
    local file = info and (info.file or info.filename)
    if not file then
        texture:SetColorTexture(0.12, 0.07, 0.04, 0.7)
        return
    end
    texture:SetTexture(file)
    local l, r = info.leftTexCoord, info.rightTexCoord
    local t, b = info.topTexCoord, info.bottomTexCoord
    texture:SetTexCoord(l + (r - l) * WHEEL_CUT[1], l + (r - l) * WHEEL_CUT[2],
        t + (b - t) * WHEEL_CUT[3], t + (b - t) * WHEEL_CUT[4])
end

function K.RowSlot(frame)
    local slot = { parts = {} }
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    fill:SetAllPoints()
    WheelFill(fill)
    slot.parts[#slot.parts + 1] = fill
    -- The rim, layer by layer from the outside in
    local inset = 0
    for layer, line in ipairs(RIM) do
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = frame:CreateTexture(nil, "BORDER", nil, layer)
            t:SetColorTexture(unpack(line.color))
            if side == "TOP" or side == "BOTTOM" then
                local y = side == "TOP" and -inset or inset
                t:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, y)
                t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, y)
                t:SetHeight(line.size)
            else
                local x = side == "LEFT" and inset or -inset
                t:SetPoint("TOP" .. side, frame, "TOP" .. side, x, -inset)
                t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, x, inset)
                t:SetWidth(line.size)
            end
            slot.parts[#slot.parts + 1] = t
        end
        inset = inset + line.size
    end
    function slot:SetShown(shown)
        for _, part in ipairs(self.parts) do part:SetShown(shown) end
    end
    return slot
end

-- The side lists' rows: straight slots (as the pickers' rows), 200 x 34,
-- ROW_STEP apart down the left from the middle's top line
K.ROW_STEP = 42

-- Puts a slot look on a frame (a row): seg:Place(anchor, y, x) puts the
-- row's centre at x, y from the anchor's centre (a layout's rail, a K.RailWindow's
-- yAt); seg:SetFocus(on) lights it
function K.Segment(frame)
    local seg = { slot = K.RowSlot(frame) }
    seg.sel = K.NineSlice(frame, "ic_select", 128, 32, 10, 10, "ARTWORK")
    seg.sel:SetShown(false)
    function seg:Place(anchor, y, x)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchor, "CENTER", x, y)
    end
    function seg:SetFocus(on)
        self.sel:SetShown(on and true or false)
    end
    function seg:SetShown(shown)
        self.slot:SetShown(shown)
        if not shown then self.sel:SetShown(false) end
    end
    return seg
end

-- A more-above / more-below arrow at a row's place (as K.Segment's)
function K.RingArrow(arrow, anchor, y, up, x)
    arrow:SetTexCoord(0, 1, 0, 1)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", anchor, "CENTER", x, y)
    arrow:SetRotation(up and math.pi or 0)
end

-- The top line that centres shown side-list rows on y = mid
function K.CenterTop(mid, shown)
    return mid + ((shown - 1) * K.ROW_STEP + 34) / 2
end

-- The y of a side list's row slot (1 the first, fractions between) whose
-- first row's top edge is on the line topY
function K.RowY(topY, slot)
    return topY - 17 - (slot - 1) * K.ROW_STEP
end

-- A side list of group headings and items, at most max lines at once:
-- where it starts (kept so the selected item, and its heading just above,
-- show), how many show, and each shown line's y (from topY down)
function K.RailWindow(lines, selected, top, max, topY)
    local n = #lines
    local shown = math.min(n, max)
    local sel = 1
    for i, line in ipairs(lines) do
        if line.index == selected then sel = i end
    end
    top = math.max(1, math.min(top or 1, n - shown + 1))
    local first = (sel > 1 and lines[sel - 1].header) and sel - 1 or sel
    if first < top then top = first end
    if sel > top + shown - 1 then top = sel - shown + 1 end
    return top, shown, function(slot) return K.RowY(topY, slot) end
end

-- More above / below: the small gold triangles
function K.MoreArrows(parent)
    local up = parent:CreateTexture(nil, "OVERLAY")
    up:SetTexture(TEX .. "ic_tri")
    up:SetTexCoord(0, 1, 1, 0)
    up:SetSize(12, 12)
    up:SetVertexColor(C.dimGold[1], C.dimGold[2], C.dimGold[3])
    local down = parent:CreateTexture(nil, "OVERLAY")
    down:SetTexture(TEX .. "ic_tri")
    down:SetSize(12, 12)
    down:SetVertexColor(C.dimGold[1], C.dimGold[2], C.dimGold[3])
    return up, down
end

-- opts = { bare = true (no box,
-- the lists switched like the panel's tabs: the list's name over the
-- native band with a dot per list between L2 / R2; each row a wheel slot),
-- tabs = true (bare: the band and the list's name even for one list) }
function K.Picker(parent, width, onRender, opts)
    opts = opts or {}
    local ROW = opts.rowHeight or PICK_ROW
    local p = K.NewFrame("Frame", nil, parent)
    p:SetWidth(width)
    p:EnableMouseWheel(true)
    p.box = K.Box(p, 4, 1, "BACKGROUND", 1)
    p.box:SetPoints(p)
    p.box:SetColors(C.black, 0.72, C.line1, 1)
    if opts.bare then p.box:SetShown(false) end
    p.kicker = K.ChatText(p, 12, C.grey)
    p.kicker:SetPoint("TOPLEFT", 12, -12)
    p.kicker:SetWidth(width - 24)
    p.title = K.Text(p, 17, C.title)
    p.title:SetPoint("TOPLEFT", p.kicker, "BOTTOMLEFT", 0, -3)
    p.title:SetWidth(width - 24)
    p.tabs = {}
    p.rows = {}
    -- L2 / R2 around the lists' tabs, like L1 / R1 around the panel's
    local GLYPH = 34
    p.ltGlyph = K.Glyph(p, GLYPH)
    p.ltGlyph:SetPoint("TOPLEFT", 10, -55)
    p.rtGlyph = K.Glyph(p, GLYPH)
    p.rtGlyph:SetPoint("TOPLEFT", width - 10 - GLYPH, -55)
    if opts.bare then
        -- No slot line or title here: the list's name and its band at the top
        p.kicker:Hide()
        p.title:Hide()
        -- (centred over the rows, its top on the picker's: the list's top line)
        local mid = 12 + (width - 24) / 2
        p.listName = p:CreateFontString(nil, "OVERLAY")
        p.listName:SetFont(FONT, 14, "")
        p.listName:SetShadowOffset(1, -1)
        p.listName:SetTextColor(1, 1, 1)
        p.listName:SetPoint("TOP", p, "TOPLEFT", mid, 0)
        p.band = p:CreateTexture(nil, "BACKGROUND", nil, -2)
        p.band:SetSize(width, 50)
        p.band:SetPoint("TOP", p.listName, "BOTTOM", 0, 4)
        if hasAtlas("gamepad-radial-menu-toptext") then
            p.band:SetAtlas("gamepad-radial-menu-toptext")
        else
            p.band:SetColorTexture(0, 0, 0, 0.5)
        end
        p.dotRow = K.NewFrame("Frame", nil, p)
        p.dotRow:SetSize(1, 13)
        p.dotRow:SetPoint("TOP", p.listName, "BOTTOM", 0, -12)
        p.dots = {}
        -- Smaller beside the list's name (Set keeps them square at .size)
        for _, g in ipairs({ p.ltGlyph, p.rtGlyph }) do
            g.size = 30
            g:SetSize(30, 30)
        end
    end
    p.kicker:ClearAllPoints()
    p.kicker:SetPoint("TOPLEFT", 12, -12)
    p.moreUp, p.moreDown = K.MoreArrows(p)
    p:SetScript("OnMouseWheel", function(self, delta) self:Move(-delta * 3) end)
    p:Hide()

    local function tab(i)
        local t = p.tabs[i]
        if t then return t end
        t = K.Button(p, 13)
        t:SetHeight(28)
        t:SetScript("OnClick", function() p:SetList(i) end)
        p.tabs[i] = t
        return t
    end

    local function row(i)
        local r = p.rows[i]
        if r then return r end
        r = K.NewFrame("Button", nil, p)
        r:SetSize(width - 24, ROW)
        r.sel = K.NineSlice(r, "ic_select", 128, 32, 10, 10, "ARTWORK")
        if opts.bare then
            r:SetHeight(ROW - 3)
            r.slot = K.RowSlot(r)
        end
        r.icon = K.RoundIcon(r, 24, "ARTWORK")
        r.icon:SetDrawLayer("ARTWORK", 2)
        r.icon:SetPoint("LEFT", opts.bare and 10 or 6, 0)
        r.mark = r:CreateTexture(nil, "OVERLAY")
        r.mark:SetTexture(TEX .. "ic_diamond")
        r.mark:SetSize(8, 8)
        r.mark:SetVertexColor(C.info[1], C.info[2], C.info[3])
        r.mark:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMLEFT", -3, -1)
        r.label = K.Text(r, opts.bare and 13 or 15, C.cream)
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.label:SetPoint("RIGHT", -6, 0)
        r.head = K.Text(r, 14, C.title)
        r.head:SetPoint("BOTTOMLEFT", 4, 3)
        r:SetScript("OnClick", function(self)
            if self.index then
                p.index = self.index
                p:Choose()
                if onRender then onRender() end
            end
        end)
        r:SetScript("OnEnter", function(self)
            if self.index and p.index ~= self.index then
                p.index = self.index
                p:Render()
            end
        end)
        p.rows[i] = r
        return r
    end

    function p:Open(def)
        self.def = def
        self.list = def.list or 1
        self:LoadList()
        self:Show()
    end

    -- Its rows centred up and down on y = mid from anchor's centre (its
    -- list's name and tabs above them, not counted), its left at x (after a
    -- render: how many rows show varies)
    function p:Center(anchor, x, mid)
        local top, bottom = self.rowsTop or 0, self.rowsBottom or 0
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "CENTER", x, mid - (top + bottom) / 2)
    end

    function p:Close()
        self.def = nil
        self:Hide()
    end

    function p:IsOpen() return self.def ~= nil end

    function p:LoadList()
        local list = self.def.lists[self.list]
        self.entries = list and list.entries() or {}
        self.offset, self.index = 0, nil
        local current = self.def.current
        if type(current) == "function" then current = current(list) end
        for i, e in ipairs(self.entries) do
            if not e.header and (not self.index or e.action == current) then
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

    -- Keep the entry (and the section title above it) in the window, with
    -- one entry of context at the edges
    function p:Move(delta)
        local entries, i = self.entries or {}, self.index
        if not i then return self:Render() end
        local step = delta < 0 and -1 or 1
        for _ = 1, math.abs(delta) do
            local j = i + step
            while entries[j] and entries[j].header do j = j + step end
            if entries[j] then i = j end
        end
        self.index = i
        local max = self.def.rows or 10
        if i - 1 <= self.offset then self.offset = math.max(0, i - 2) end
        if self.offset > 0 and entries[self.offset] and entries[self.offset].header then
            self.offset = self.offset - 1
        end
        if i + 1 > self.offset + max then self.offset = math.min(#entries - max, i + 1 - max) end
        self.offset = math.max(0, self.offset)
        self:Render()
    end

    -- The previous / next section
    function p:Jump(step)
        local entries, headers = self.entries or {}, {}
        for i, e in ipairs(entries) do
            if e.header then headers[#headers + 1] = i end
        end
        if #headers < 2 then return self:Move(step * (self.def.rows or 10)) end
        local current = 0
        for n, h in ipairs(headers) do
            if h < (self.index or 0) then current = n end
        end
        local target = headers[current + step]
        if not target then return end
        self.index = target
        self:Move(1)
    end

    function p:Choose()
        local e = self.def and self.index and self.entries[self.index]
        if e and not e.header and self.def.onChoose then self.def.onChoose(e) end
    end

    function p:Press(name)
        if name == "UP" or name == "DOWN" then
            self:Move(name == "UP" and -1 or 1)
        elseif name == "LEFT" or name == "RIGHT" then
            self:Jump(name == "LEFT" and -1 or 1)
        elseif name == "LT" or name == "RT" then
            if #self.def.lists > 1 then self:SetList(self.list + (name == "LT" and -1 or 1)) end
        elseif name == "A" then
            self:Choose()
        elseif name == "B" then
            if self.def.onBack then self.def.onBack() end
        end
        return true
    end

    function p:Hints()
        local hints = { K.H({ "DPAD" }, "Move"), K.H({ "A" }, self.def.chooseVerb or "Choose", "A") }
        if #self.def.lists > 1 then hints[#hints + 1] = K.H({ "LT", "RT" }, "List", "RT") end
        hints[#hints + 1] = K.H({ "B" }, "Back", "B")
        return hints
    end

    function p:Render()
        local def = self.def
        if not def then return end
        local kicker, title = def.kicker, def.title
        if type(kicker) == "function" then kicker = kicker() end
        if type(title) == "function" then title = title() end
        self.kicker:SetText((kicker or ""):upper())
        self.title:SetText(title or "")
        -- The lists' tabs share the width between the L2 / R2 glyphs
        local n = #def.lists
        self.ltGlyph:SetShown(n > 1)
        self.rtGlyph:SetShown(n > 1)
        if n > 1 then
            self.ltGlyph:Set("LT")
            self.rtGlyph:Set("RT")
        end
        if opts.bare then
            -- As the panel's tabs: the list's name, a dot per list (they
            -- click to their list), L2 / R2 either side
            local named = n > 1 or opts.tabs
            self.listName:SetShown(named and true or false)
            self.band:SetShown(named and true or false)
            self.listName:SetText(named and def.lists[self.list].label or "")
            for i = 1, math.max(n, #self.dots) do
                local d = self.dots[i]
                if not d then
                    d = K.NewFrame("Button", nil, self.dotRow)
                    d:SetSize(13, 13)
                    d.tex = d:CreateTexture(nil, "OVERLAY")
                    d.tex:SetAllPoints()
                    local index = i
                    d:SetScript("OnClick", function() p:SetList(index) end)
                    self.dots[i] = d
                end
                d:SetShown((n > 1 or opts.tabs) and i <= n and true or false)
                if i <= n then
                    d:ClearAllPoints()
                    d:SetPoint("CENTER", self.dotRow, "CENTER", (i - (n + 1) / 2) * 18, 0)
                    local active = i == self.list
                    local name = active and "gamepad-radialgamemenu-cursorbg-neutral" or "gamepad-radialgamemenu-cursorbg-inactive"
                    if hasAtlas(name) then
                        d.tex:SetAtlas(name)
                    else
                        d.tex:SetColorTexture(active and 1 or 0.4, active and 1 or 0.4, active and 1 or 0.4, 1)
                    end
                end
            end
            local edge = (n - 1) / 2 * 18 + 12
            self.ltGlyph:ClearAllPoints()
            self.ltGlyph:SetPoint("RIGHT", self.dotRow, "CENTER", -edge, 0)
            self.rtGlyph:ClearAllPoints()
            self.rtGlyph:SetPoint("LEFT", self.dotRow, "CENTER", edge, 0)
        end
        local side = GLYPH + 4
        local tw = (width - 20 - 2 * side - (n - 1) * 4) / n
        for i = 1, math.max(n, #self.tabs) do
            local t = tab(i)
            t:SetShown(n > 1 and i <= n and not opts.bare)
            if i <= n then
                t:SetWidth(tw)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self, "TOPLEFT", 10 + side + (i - 1) * (tw + 4), -54)
                t.label:SetText(def.lists[i].label)
                t:SetState({ active = i == self.list })
            end
        end
        local named = n > 1 or (opts.bare and opts.tabs)
        local top = named and (opts.bare and -70 or -88) or (opts.bare and 0 or -54)
        local max = def.rows or 10
        local y = top
        local shown = 0
        for i = 1, max + 1 do
            local e = self.entries[self.offset + i]
            local r = row(i)
            r.index = nil
            if e and shown < max then
                shown = shown + 1
                local h = e.header and PICK_HEAD or ROW
                -- (wheel slots: a small gap between them)
                r:SetHeight(h - ((opts.bare and not e.header) and 3 or 0))
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", self, "TOPLEFT", 12, y)
                y = y - h
                r.head:SetShown(e.header ~= nil)
                if r.slot then r.slot:SetShown(not e.header) end
                r.label:SetShown(not e.header)
                r.icon:SetShown(not e.header)
                r.mark:SetShown(not e.header and def.marked and def.marked(e) or false)
                r.sel:SetShown(not e.header and self.offset + i == self.index)
                if e.header then
                    r.head:SetText(e.header)
                else
                    r.index = self.offset + i
                    K.SetIcon(r.icon, e.icon)
                    r.label:SetText(e.name .. (e.sub and ("  |cff9d9a8c" .. e.sub .. "|r") or ""))
                end
                r:Show()
            else
                r:Hide()
            end
        end
        for i = max + 2, #self.rows do self.rows[i]:Hide() end
        -- More above / below the rows shown
        self.moreUp:ClearAllPoints()
        self.moreDown:ClearAllPoints()
        self.moreUp:SetPoint("BOTTOM", self, "TOPLEFT", 12 + (width - 24) / 2, top + 1)
        self.moreDown:SetPoint("TOP", self, "TOPLEFT", 12 + (width - 24) / 2, y - 1)
        self.moreDown:SetShown(self.offset + max < #self.entries)
        -- Where its rows start (under its list's name and tabs) and end
        self.rowsTop, self.rowsBottom = top, y
        if #self.entries == 0 then
            local r = row(1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self, "TOPLEFT", 12, top)
            r:Show()
            r.head:Show()
            r.head:SetText("Nothing here")
            r.label:Hide()
            r.icon:Hide()
            r.mark:Hide()
            r.sel:SetShown(false)
        end
    end
    return p
end

-- Buttons side by side in a row frame, each sized by its share ("flex") of
-- the row's width, with a gap between them
function K.LayoutRow(row, buttons, flexes, gap)
    local total = 0
    for i = 1, #buttons do total = total + (flexes[i] or 1) end
    local room, x = row:GetWidth() - gap * (#buttons - 1), 0
    for i, b in ipairs(buttons) do
        local w = room * (flexes[i] or 1) / total
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        b:SetSize(w, row:GetHeight())
        x = x + w + gap
    end
end
