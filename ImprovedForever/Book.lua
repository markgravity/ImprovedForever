-- A book: the Wiki's window, for any module to write in (the Wiki's
-- pages of items, creatures and quests; the Journal's days). Forever's
-- spellbook window (its frame, its page): the page's title (its icon in the
-- spellbook's frame), under the rule its notes (paragraphs, who wrote them),
-- then entries in two columns as the spellbook's spells, as many pages as
-- they need: the D-pad reads on from page to page, L1 / R1 turn them. Cross
-- on an entry opens its list (line.go) or does what the page says; Circle
-- goes back to the notes, then to the page before.
-- A page is the module's own table, with these methods (heading and notes
-- needed, the rest as the page has them):
--   page:heading() -> { icon, round, portrait, title, kind, owned, chapter }
--   page:notes() -> paragraphs, signature (nil: none), lines
--   page:list(key) -> lines;  page:about(key) -> its paragraph, or nil
--   page:activate(line, book) (Cross);  page:alt(line, book) (Square)
--   page:verb(line), page:altVerb(line) -> the legend's word for Cross, Square
--   page:tip(line, book) -> true: it drew the tooltip (book:PlaceTip() first)
-- A line: { header, info }, or an entry: { kind ("item", "npc", "object",
-- "quest", "place", "recipe"...), name, line (the words under it), icon,
-- round, portrait (an npc id: its face), item (an id: its name, quality and
-- tooltip), describe (an item's quality and type under it), tip (an item id
-- for the tooltip), go (a list's key), getName (its name worked out each
-- time: names come in late) }.
-- Never in combat.
local IF = ImprovedForever

local K = IF.ConfigKit

local BK = {}
IF.Book = BK

---------------------------------------------------------------------------
-- The book's looks
---------------------------------------------------------------------------
local PARCHMENT = "spellbook-Page-Right-C60"
local WINDOW_W = 680                     -- (the spellbook window, made smaller)
local TITLE_H, INSET_X, INSET_Y = 15, 2, 3   -- (where the window's page sits: PlayerSpellsFrame)
local ART_W = WINDOW_W - 2 * INSET_X - 1
local ART_H = math.floor(ART_W * 682 / 810 + 0.5)      -- (the page atlas's proportions)
local BAND = math.floor(ART_H * 0.085 + 0.5)           -- (its dark strip on top: the tabs', left empty)
local PAGE_W, PAGE_H = ART_W, ART_H - BAND             -- the parchment, where everything is written
local LEFT, RIGHT = 66, 58               -- the writing's margins (room left for the cursor)
local TOP = 112                          -- the notes' top, under the rule
local AREA_W = PAGE_W - LEFT - RIGHT
local AREA_H = PAGE_H - TOP - 62
local GAP = 20
local CELL_W, CELL_H = (AREA_W - GAP) / 2, 58
local HEAD_H = 34
local CELLS = 2 * math.floor(AREA_H / CELL_H)
local HEADS = math.floor(AREA_H / HEAD_H)
local HEADING_FONT = "Fonts\\MORPHEUS.TTF"
local PARA_GAP = 10
local NONE_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The spellbook's ink (SPELLBOOK_FONT_COLOR), and darker accents of it
local INK = { 0.23, 0.16, 0.09 }
if _G.SPELLBOOK_FONT_COLOR and SPELLBOOK_FONT_COLOR.GetRGB then INK = { SPELLBOOK_FONT_COLOR:GetRGB() } end
local ACCENT_RGB = { 0.43, 0.16, 0.05 }
local ACCENT = "|cff6e2a0c"
-- An item's quality, in an ink that reads on parchment
local QUALITY_INK = { [0] = "|cff5c5c5c", [1] = "|cff3b2a1a", [2] = "|cff1a6b12", [3] = "|cff0b4c96",
    [4] = "|cff6a1b9a", [5] = "|cffa64b00", [6] = "|cff8a6d2b" }
local QUALITY_NAMES = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary", [6] = "Artifact" }
BK.INK, BK.ACCENT, BK.QUALITY_INK, BK.QUALITY_NAMES = INK, ACCENT, QUALITY_INK, QUALITY_NAMES

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

-- A font of the game's (the spellbook's), in its ink, no shadow
local function Ink(fs, font, fallback, color)
    local object = _G[font] or _G[fallback]
    if object then fs:SetFontObject(object) end
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetShadowOffset(0, 0)
    return fs
end

-- A name in a script the book's fonts lack (Chinese, Korean, Cyrillic: UTF-8
-- past two bytes, or Cyrillic's): drawn in the chat's font, which has it, at
-- the same size; else the font it was made with (font, fallback: Ink's)
local function Script(fs, text, font, fallback)
    text = text or ""
    local foreign = text:find("[\224-\244]") or text:find("[\208\209]")
    local chat = foreign and _G.ChatFontNormal and _G.ChatFontNormal:GetFont()
    if chat then
        local _, size = fs:GetFont()
        pcall(fs.SetFont, fs, chat, size or 14, "")
        fs:SetTextColor(INK[1], INK[2], INK[3])
        fs:SetShadowOffset(0, 0)
    elseif fs.scripted then
        Ink(fs, font, fallback)
    end
    fs.scripted = chat and true or nil
    fs:SetText(text)
end
BK.Script = Script

local function Text(parent, font, fallback, layer)
    return Ink(parent:CreateFontString(nil, layer or "ARTWORK"), font, fallback)
end

-- The page's subject (top right): the game's book font (Morpheus), in the
-- accent
local function Heading(parent, size)
    local fs = Text(parent, "QuestTitleFont", "GameFontNormalLarge")
    pcall(fs.SetFont, fs, HEADING_FONT, size, "")
    fs:SetTextColor(ACCENT_RGB[1], ACCENT_RGB[2], ACCENT_RGB[3])
    return fs
end

-- The notes' writing: the spellbook's own (Friz), easy to read
local function Body(parent)
    local fs = Text(parent, "SystemFont_Med3", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(4)
    fs:SetWidth(AREA_W)
    return fs
end

local function Sound(kit)
    local id = SOUNDKIT and SOUNDKIT[kit]
    if id and PlaySound then pcall(PlaySound, id) end
end
BK.Sound = Sound

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

local function ItemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or NONE_ICON
end

---------------------------------------------------------------------------
-- Words, for the modules writing in it
---------------------------------------------------------------------------
function BK.Plural(n, one, many)
    return n .. " " .. (n == 1 and one or many)
end

function BK.Capital(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- "a, b and c"
function BK.Names(list)
    if #list <= 1 then return list[1] or "" end
    return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

-- A name in the accent
function BK.Name(s) return ACCENT .. s .. "|r" end

-- "a Battered Chest", "an Alliance Chest" (A_: the name in the accent)
function BK.A_plain(name)
    return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

function BK.A_(name)
    return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. BK.Name(name)
end

-- "a, b, c and 4 more" (names put in the accent)
function BK.Shorten(names, keep)
    local out = {}
    for i = 1, math.min(#names, keep) do
        out[i] = names[i]:find("|c") and names[i] or BK.Name(names[i])
    end
    if #names > keep then out[#out + 1] = (#names - keep) .. " more" end
    return out
end

-- 6420 -> "64 silver 20 copper" (words read better in a sentence than coins)
function BK.Coins(copper)
    copper = math.floor(copper or 0)
    local parts = {}
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if gold > 0 then parts[#parts + 1] = gold .. " gold" end
    if silver > 0 then parts[#parts + 1] = silver .. " silver" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. " copper" end
    return table.concat(parts, " ")
end

-- (parts may have gaps: a nil or false one is left out, the rest kept)
function BK.Join(parts, sep)
    local out = {}
    for i = 1, table.maxn(parts) do
        local p = parts[i]
        if p and p ~= "" then out[#out + 1] = p end
    end
    return table.concat(out, sep or "  ·  ")
end

-- An item's quality and type in the page's ink: "Uncommon Cloth"
function BK.ItemKind(id)
    local _, _, quality, _, _, itemType, subType = ItemInfo(id)
    local q = quality or 1
    return (QUALITY_INK[q] or "") .. (QUALITY_NAMES[q] or "") .. "|r"
        .. ((subType or itemType) and (" " .. (subType or itemType)) or "")
end

-- A creature's portrait, as the game draws one, from its look's display id
-- (WorldData.lua's: the server alone knows them; a model can't be handed
-- one the client hasn't met). -> true: drawn
function BK.Portrait(npcID, texture)
    local looks = IF.WorldData and IF.WorldData.displays
    local display = npcID and looks and looks[npcID]
    if not (display and SetPortraitTextureFromCreatureDisplayID) then return false end
    return pcall(SetPortraitTextureFromCreatureDisplayID, texture, display)
end

-- A list's entries (its headers left out)
local function Count(lines)
    local n = 0
    for _, l in ipairs(lines or {}) do
        if not l.header then n = n + 1 end
    end
    return n
end
BK.Count = Count

-- The tooltip shows as everywhere else: the game's own setting (CVar
-- GamepadDisableTooltips), which R3 turns on and off here as in the bags;
-- always with the mouse (on hover, as the game's own)
local function TipsOn()
    if not IF.Input.Pad() then return true end
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return not (get and get("GamepadDisableTooltips"))
end
BK.TipsOn = TipsOn

local function ToggleTips()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set("GamepadDisableTooltips", TipsOn() and "1" or "0") end
end

---------------------------------------------------------------------------
-- Parts of a page
---------------------------------------------------------------------------
-- A spellbook icon: the spell's frame round a masked icon (square: an item;
-- round: a creature, a place, a quest), its hover glow for the focus. f =
-- IconFrame(parent, size); f:Set(icon, round); f:SetFocus(on)
local function IconFrame(parent, size)
    local f = K.NewFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local k = size / 40
    f.shadow = f:CreateTexture(nil, "ARTWORK", nil, 1)
    Atlas(f.shadow, "spellbook-item-iconframe-shadow")
    f.shadow:SetPoint("TOPLEFT", -12 * k, 3 * k)
    f.shadow:SetPoint("BOTTOMRIGHT", 2 * k, -8 * k)
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, -1)
    f.icon:SetSize(36 * k, 36 * k)
    f.icon:SetPoint("CENTER")
    local function Mask(atlas)
        if not (f.CreateMaskTexture and IF.HasAtlas(atlas)) then return nil end
        local m = f:CreateMaskTexture()
        m:SetAtlas(atlas)
        m:SetAllPoints(f.icon)
        return m
    end
    f.masks = { square = Mask("spellbook-item-spellicon-mask"), round = Mask("talents-node-circle-mask") }
    f.border = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.glow:SetAllPoints()
    f.glow:SetBlendMode("ADD")
    f.glow:Hide()
    -- (icon: a texture, or "atlas:name": an atlas of the game's)
    function f:Set(icon, round)
        local atlas = type(icon) == "string" and icon:match("^atlas:(.+)$")
        if atlas and IF.HasAtlas(atlas) then
            self.icon:SetAtlas(atlas)
        else
            self.icon:SetTexture(not atlas and icon or NONE_ICON)
        end
        local mask = self.masks[round and "round" or "square"]
        if self.mask ~= mask then
            if self.mask then self.icon:RemoveMaskTexture(self.mask) end
            if mask then self.icon:AddMaskTexture(mask) end
            self.mask = mask
        end
        if not (atlas and IF.HasAtlas(atlas)) then
            self.icon:SetTexCoord(mask and 0 or 0.07, mask and 1 or 0.93, mask and 0 or 0.07, mask and 1 or 0.93)
        end
        self.border:ClearAllPoints()
        if round then
            if not Atlas(self.border, "spellbook-passive-iconframe") then Atlas(self.border, "talents-node-circle-gray") end
            self.border:SetPoint("TOPLEFT", -3 * k, 3 * k)
            self.border:SetPoint("BOTTOMRIGHT", 3 * k, -3 * k)
            Atlas(self.glow, "spellbook-item-iconframe-passive-hover")
        else
            Atlas(self.border, "spellbook-item-iconframe")
            self.border:SetPoint("TOPLEFT", -11 * k, 1 * k)
            self.border:SetPoint("BOTTOMRIGHT", 1 * k, -7 * k)
            Atlas(self.glow, "spellbook-item-iconframe-hover")
        end
        self.shadow:SetShown(not round)
    end
    function f:SetFocus(on)
        self.glow:SetShown(on and true or false)
        self.glow:SetAlpha(0.5)
    end
    return f
end

-- Frames made as they're needed
local function Pool(make)
    local pool = { used = 0 }
    function pool:Next()
        self.used = self.used + 1
        local f = self[self.used]
        if not f then
            f = make()
            self[self.used] = f
        end
        return f
    end
    function pool:Reset() self.used = 0 end
    function pool:HideRest()
        for i = self.used + 1, #self do self[i]:Hide() end
    end
    return pool
end

---------------------------------------------------------------------------
-- Laying out: a page's paragraphs (and who wrote them), then its lines,
-- over as many pages as they need
---------------------------------------------------------------------------
-- A list laid out in pages: headers across, entries two a row; a section
-- going on over a page has its header again there. (pages, list, y: going
-- on from the notes)
local function ListLayout(lines, pages, list, startY)
    pages, list = pages or {}, list or {}
    local current = pages[#pages]
    local y, col, header = startY or 0, 0, nil
    local function newPage()
        current = { items = {} }
        pages[#pages + 1] = current
        y, col = 0, 0
        if header then
            current.items[#current.items + 1] = { header = header.header, info = "continued", y = y }
            y = y + HEAD_H
        end
    end
    if not current then newPage() end
    for _, line in ipairs(lines) do
        if line.header then
            if col > 0 then y, col = y + CELL_H, 0 end
            header = nil
            if y + HEAD_H + CELL_H > AREA_H then newPage() end
            header = line
            current.items[#current.items + 1] = { header = line.header, info = line.info, y = y }
            y = y + HEAD_H
        else
            if col == 0 and y + CELL_H > AREA_H then newPage() end
            local c = { line = line, page = #pages, col = col, x = col * (CELL_W + GAP), y = y }
            current.items[#current.items + 1] = c
            list[#list + 1] = c
            c.index = #list
            col = col + 1
            if col == 2 then y, col = y + CELL_H, 0 end
        end
    end
    return pages, list
end

---------------------------------------------------------------------------
-- A book: its own window. opts: { name (the window's global name), title,
-- portrait (its icon), empty (a list with nothing: what it says), notes (the
-- legend's word for Circle back to the notes), other, label (IF.Focus.Switch's:
-- a window of ours behind it), onHide(book) }
---------------------------------------------------------------------------
local Book = {}
Book.__index = Book

function BK.New(opts)
    local book = setmetatable({ opts = opts, stack = {}, focus = "ours", dim = true }, Book)

    -- The window: the spellbook's (PortraitFrameTemplate: its gold frame, a
    -- book in its portrait, the book's name on its title bar), its page
    -- inside; the page's strip on top, where the spellbook has its tabs,
    -- left empty
    local ok, window = pcall(K.NewFrame, "Frame", opts.name, UIParent, "PortraitFrameTemplate")
    if not ok then window = K.NewFrame("Frame", opts.name, UIParent) end
    window:SetSize(WINDOW_W, ART_H + INSET_Y + TITLE_H)
    -- (over the auction window, a DIALOG)
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetPoint("CENTER")
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    pcall(function()
        if window.SetTitle then window:SetTitle(opts.title or "") end
        if window.SetPortraitToAsset then window:SetPortraitToAsset(opts.portrait or "Interface\\Icons\\INV_Misc_Book_09") end
    end)
    book.window = window

    local art = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    art:SetPoint("BOTTOMLEFT", INSET_X, INSET_Y)
    art:SetSize(ART_W, ART_H)
    if not Atlas(art, PARCHMENT) then art:SetColorTexture(0.85, 0.75, 0.58, 1) end

    -- The parchment under the strip: everything on the page is placed on it
    -- (the tooltips' owner)
    local page = K.NewFrame("Frame", nil, window)
    page:SetPoint("BOTTOMLEFT", INSET_X, INSET_Y)
    page:SetSize(PAGE_W, PAGE_H)
    book.panel = page

    -- The title: the page's icon, its name, what it is, the rule under them
    local head = IconFrame(page, 46)
    head:SetPoint("TOPLEFT", LEFT + 2, -34)
    local title = Text(page, "SystemFont_Huge2", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", head, "TOPRIGHT", 16, 2)
    title:SetPoint("RIGHT", page, "RIGHT", -RIGHT - 150, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local kind = Text(page, "SystemFont_Med1", "GameFontNormal")
    kind:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    kind:SetPoint("RIGHT", page, "RIGHT", -RIGHT, 0)
    kind:SetJustifyH("LEFT")
    kind:SetWordWrap(false)
    local owned = Text(page, "SystemFont_Med1", "GameFontNormal")
    owned:SetPoint("TOPLEFT", kind, "BOTTOMLEFT", 0, -3)
    owned:SetPoint("RIGHT", page, "RIGHT", -RIGHT, 0)
    owned:SetJustifyH("LEFT")
    owned:SetAlpha(0.75)
    -- What is read: the notes' name, or the list's subject, at the top right
    local chapter = Heading(page, 17)
    chapter:SetPoint("TOPRIGHT", -RIGHT, -38)
    chapter:SetJustifyH("RIGHT")
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(11)
    rule:SetPoint("TOPLEFT", LEFT - 30, -TOP + 22)
    rule:SetPoint("TOPRIGHT", -RIGHT + 6, -TOP + 22)
    if not Atlas(rule, "spellbook-divider") then rule:SetColorTexture(INK[1], INK[2], INK[3], 0.5) rule:SetHeight(1) end

    -- "Page 1/3", at the bottom right, as the spellbook's
    local pageNo = Text(page, "SystemFont_Med3", "GameFontNormalLarge")
    pageNo:SetPoint("BOTTOMRIGHT", -RIGHT - 6, 30)

    -- With the mouse: the spellbook's page arrows beside it (and the wheel
    -- over the page), set to turn below
    local turn
    local function Arrow(dir, tex)
        local b = K.NewFrame("Button", nil, page)
        b:SetSize(32, 32)
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. tex .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. tex .. "Page-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. tex .. "Page-Disabled")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function() if turn then turn(dir) end end)
        b:Hide()
        return b
    end
    local nextPage = Arrow(1, "Next")
    nextPage:SetPoint("LEFT", pageNo, "RIGHT", 2, 0)
    local prevPage = Arrow(-1, "Prev")
    prevPage:SetPoint("RIGHT", pageNo, "LEFT", -2, 0)
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        if turn and not IF.Input.Pad() then turn(delta > 0 and -1 or 1) end
    end)

    local emptyText = Text(page, "SystemFont_Med3", "GameFontNormalLarge")
    emptyText:SetPoint("TOP", page, "TOP", 0, -TOP - 60)
    emptyText:SetAlpha(0.7)

    -- A list's entry: its icon in its frame, its name, a line under it; the
    -- spellbook's faint backplate behind it, full under the focus
    local cells = {}
    for i = 1, CELLS do
        local c = K.NewFrame("Button", nil, page)
        c:SetSize(CELL_W, CELL_H - 6)
        c.backplate = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        c.backplate:SetSize(CELL_W + 36, 64)
        c.backplate:SetPoint("CENTER", 5, -5)
        if not Atlas(c.backplate, "spellbook-item-backplate") then c.backplate:Hide() end
        c.icon = IconFrame(c, 40)
        c.icon:SetPoint("LEFT", 0, 0)
        c.name = Text(c, "SystemFont_Large", "GameFontNormalLarge")
        c.name:SetPoint("RIGHT", c, "RIGHT", -4, 0)
        c.name:SetJustifyH("LEFT")
        c.name:SetWordWrap(false)
        c.sub = Text(c, "SystemFont_Med1", "GameFontNormal")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
        c.sub:SetPoint("RIGHT", c, "RIGHT", -4, 0)
        c.sub:SetJustifyH("LEFT")
        c.sub:SetWordWrap(true)
        if c.sub.SetMaxLines then c.sub:SetMaxLines(2) end
        -- (the game's gamepad cursor left of the focus: Focus.lua)
        c.pointer = IF.Focus.Cursor(c)
        c.pointer:SetPoint("RIGHT", c.icon, "LEFT", 2, 0)
        -- (the mouse: over one picks it, its tooltip shown; a click opens
        -- it, a right-click does what Square does)
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c:SetScript("OnClick", function(self, button)
            if not self.index then return end
            if button == "RightButton" then
                book:Pick(self.index)
                book:Alt()
            else
                book:Pick(self.index, true)
            end
        end)
        c:SetScript("OnEnter", function(self)
            if self.index and not IF.Input.Pad() then book:Pick(self.index) end
        end)
        cells[i] = c
    end

    -- A list's section header (a zone, a profession, a month): its name, how
    -- many, a faint rule
    local heads = {}
    for i = 1, HEADS do
        local h = K.NewFrame("Frame", nil, page)
        h:SetSize(AREA_W, HEAD_H)
        h.text = Text(h, "SystemFont_Med3", "GameFontNormalLarge")
        h.text:SetPoint("BOTTOMLEFT", 0, 10)
        h.text:SetPoint("RIGHT", -60, 0)
        h.text:SetJustifyH("LEFT")
        h.text:SetWordWrap(false)
        h.info = Text(h, "SystemFont_Med1", "GameFontNormal")
        h.info:SetPoint("BOTTOMRIGHT", 0, 11)
        h.info:SetAlpha(0.7)
        h.rule = h:CreateTexture(nil, "ARTWORK")
        h.rule:SetHeight(6)
        h.rule:SetPoint("BOTTOMLEFT", -10, 2)
        h.rule:SetPoint("BOTTOMRIGHT", 6, 2)
        if not Atlas(h.rule, "spellbook-divider") then h.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.4) h.rule:SetHeight(1) end
        h.rule:SetAlpha(0.55)
        heads[i] = h
    end

    -- The notes' paragraphs, made as they're needed
    local paragraphs = Pool(function() return Body(page) end)
    -- (a paragraph's height before it's placed)
    local measure = Body(page)
    measure:Hide()

    local legend = IF.InputLegend(window)
    legend:SetPoint("TOP", window, "BOTTOM", 0, -4)
    book.legend = legend
    -- (with the mouse its buttons, Back / Close, on the page: bottom left,
    -- level with the page number)
    legend.row:ClearAllPoints()
    legend.row:SetPoint("LEFT", page, "BOTTOMLEFT", LEFT - 8, 38)

    -- A page laid out: its paragraphs (and who wrote them), then its lines
    local function PageLayout(texts, signed, lines)
        local current = { items = {} }
        local pages, y = { current }, 0
        local function place(what, text, h)
            if y > 0 and y + h > AREA_H then
                current = { items = {} }
                pages[#pages + 1] = current
                y = 0
            end
            current.items[#current.items + 1] = { doc = what, text = text, y = y }
            y = y + h
        end
        for _, text in ipairs(texts) do
            measure:SetText(text)
            place("para", text, math.ceil(measure:GetStringHeight()) + PARA_GAP)
        end
        if signed then place("sign", signed, 34) end
        return ListLayout(lines or {}, pages, {}, y)
    end

    -----------------------------------------------------------------------
    -- What is shown: a stack of pages (Cross on an entry: often another
    -- page; Circle: back), each with its tab ("notes" or a list's) and its
    -- views ({ [tab] = { pages, cells, sel, page } })
    -----------------------------------------------------------------------
    local function Top() return book.stack[#book.stack] end

    -- (laid out again each time, the picked entry and page kept: names come
    -- in late)
    local function View(p)
        local key = p.tab
        local old = p.views[key]
        local pages, list
        if key == "notes" then
            local texts, signed, lines = p:notes()
            pages, list = PageLayout(texts or {}, signed, lines)
        else
            pages, list = PageLayout({ p.about and p:about(key) or nil }, nil, p.list and p:list(key) or {})
        end
        local view = { pages = pages, cells = list, sel = old and math.min(old.sel, math.max(1, #list)) or 1,
            page = old and old.page or 1 }
        p.views[key] = view
        return view
    end

    local function Picked()
        local p = Top()
        local view = p and View(p)
        local c = view and view.cells[view.sel]
        return c and c.line, p
    end

    -- A list opened from the notes (Circle: back to them)
    function book:OpenList(key)
        local p = Top()
        if not p or not p.list or Count(p:list(key)) == 0 then return end
        p.tab = key
        Sound("IG_ABILITY_PAGE_TURN")
        self:Render()
    end

    -- An entry picked (its page turned to); activate: Cross on it too
    function book:Pick(index, activate)
        local p = Top()
        local view = p and View(p)
        local c = view and view.cells[index]
        if not c then return end
        view.sel = index
        if c.page ~= view.page then
            view.page = c.page
            Sound("IG_ABILITY_PAGE_TURN")
        end
        if activate then self:Activate() end
        self:Render()
    end

    -- The D-pad: left / right reads on (over the page's edge too), up / down
    -- the row above / below (the same column when it has one)
    local function Move(name)
        local p = Top()
        local view = p and View(p)
        if not view or #view.cells == 0 then return end
        local cur = view.cells[view.sel]
        if name == "LEFT" or name == "RIGHT" then return book:Pick(view.sel + (name == "RIGHT" and 1 or -1)) end
        local down = name == "DOWN"
        local function after(c)
            if c.page ~= cur.page then return (c.page > cur.page) == down end
            return c.y ~= cur.y and (c.y > cur.y) == down
        end
        local from, to, step = 1, #view.cells, 1
        if not down then from, to, step = #view.cells, 1, -1 end
        for i = from, to, step do
            local c = view.cells[i]
            if after(c) then
                -- (that row: the same column, else its nearest)
                local pick = c
                for j = i, to, step do
                    local d = view.cells[j]
                    if d.page ~= c.page or d.y ~= c.y then break end
                    if d.col == cur.col then pick = d end
                end
                return book:Pick(pick.index)
            end
        end
    end

    -- L1 / R1: the page before / after (its first entry)
    local function Turn(dir)
        local p = Top()
        local view = p and View(p)
        if not view then return end
        local want = view.page + dir
        if want < 1 or want > #view.pages then return end
        for _, c in ipairs(view.cells) do
            if c.page == want then return book:Pick(c.index) end
        end
        view.page = want
        Sound("IG_ABILITY_PAGE_TURN")
        book:Render()
    end
    turn = Turn

    -- Cross on the picked entry: its list, else what the page does with it
    function book:Activate()
        local line, p = Picked()
        if not line then return end
        if line.go then return self:OpenList(line.go) end
        if p.activate then p:activate(line, self) end
    end

    -- Square on the picked entry (a right-click on it): what the page does
    -- with it
    local function Alt()
        local line, p = Picked()
        if line and p.alt then p:alt(line, book) end
    end
    function book:Alt() Alt() end

    -- A page on top (Circle: back to the one under it)
    function book:Push(p)
        if not p then return end
        p.tab, p.views = p.tab or "notes", p.views or {}
        self.stack[#self.stack + 1] = p
        if #self.stack > 1 then Sound("IG_ABILITY_PAGE_TURN") end
        self:Render()
    end

    -- The page on top
    function book:Top() return Top() end

    -- Circle: from a list its notes, from the notes the page before, or the
    -- book closed
    function book:Back()
        local p = Top()
        if p and p.tab ~= "notes" then
            p.tab = "notes"
        else
            table.remove(self.stack)
            if #self.stack == 0 then return self:Close() end
        end
        Sound("IG_ABILITY_PAGE_TURN")
        self:Render()
    end

    -----------------------------------------------------------------------
    -- Drawing
    -----------------------------------------------------------------------
    function book:PlaceTip()
        GameTooltip:SetOwner(page, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        if (page:GetRight() or 0) + 320 < (UIParent:GetRight() or 0) then
            GameTooltip:SetPoint("TOPLEFT", page, "TOPRIGHT", 4, -20)
        else
            GameTooltip:SetPoint("TOPRIGHT", page, "TOPLEFT", -4, -20)
        end
    end

    local function RenderTip(p, line)
        if not TipsOn() or not line or line.go then
            if GameTooltip:GetOwner() == page then GameTooltip:Hide() end
            return
        end
        if p.tip and p:tip(line, book) then return end
        local tip = line.tip or line.item
        if tip then
            book:PlaceTip()
            if pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tip) then GameTooltip:Show() else GameTooltip:Hide() end
        elseif GameTooltip:GetOwner() == page then
            GameTooltip:Hide()
        end
    end

    local switch              -- (L2 / R2 to the other window: below, IF.Focus.Switch)

    local function Hints(p, view, line)
        local defs = { { glyph = "DPAD", text = "Move" } }
        if view and #view.pages > 1 then
            defs[#defs + 1] = { { "PADLSHOULDER", "PADRSHOULDER" }, { "LB", "RB" }, "Turn Page" }
        end
        local verb = line and (line.go and "Read" or p.verb and p:verb(line))
        -- (with the mouse a click on the entry, a right-click for Square's)
        if verb then defs[#defs + 1] = { "PAD1", "A", verb, pad = true } end
        local alt = line and p.altVerb and p:altVerb(line)
        if alt then defs[#defs + 1] = { "PAD3", "X", alt, pad = true } end
        if line and not line.go then defs[#defs + 1] = { "PADRSTICK", "RS", TipsOn() and "Hide Tooltip" or "Tooltip" } end
        local hint = switch:Hint()
        if hint then defs[#defs + 1] = hint end
        defs[#defs + 1] = { "PAD2", "B", p.tab ~= "notes" and (opts.notes or "Notes")
            or #book.stack > 1 and "Back" or "Close" }
        return defs
    end

    -- (legend defs are kept by identity: one table a shape)
    local hintSets = {}
    local function SetHints(defs)
        local key = {}
        for _, d in ipairs(defs) do key[#key + 1] = tostring(d[1]) .. "=" .. tostring(d.text or d[3]) end
        key = table.concat(key, "|")
        hintSets[key] = hintSets[key] or defs
        legend:Set(hintSets[key])
    end

    -- A list entry's words: its name, then its line
    local function Fill(c, line)
        local round = line.round or line.kind == "npc" or line.kind == "object" or line.kind == "quest"
            or line.kind == "trainer" or line.kind == "place" or line.go ~= nil
        local name, sub = line.name, line.line
        if line.kind == "item" and line.item then
            name = ItemInfo(line.item) or ("Item " .. line.item)
            -- (a creature's loot, its wares: what each is, "Uncommon Cloth")
            sub = line.describe and BK.ItemKind(line.item) or line.line or "a container"
        elseif line.getName then
            name = line.getName(line)
            if line.kind == "recipe" then sub = nil end
        end
        c.icon:Set(line.icon or (line.item and ItemIcon(line.item)), round)
        -- A creature, a person: its own face
        if line.kind == "npc" or line.portrait then BK.Portrait(line.portrait or line.id, c.icon.icon) end
        Script(c.name, name, "SystemFont_Large", "GameFontNormalLarge")
        c.sub:SetText((sub and sub ~= "") and sub or "")
        c.name:ClearAllPoints()
        if sub and sub ~= "" then
            c.name:SetPoint("BOTTOMLEFT", c, "LEFT", 52, 1)
        else
            c.name:SetPoint("LEFT", c, "LEFT", 52, 0)
        end
        c.name:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    end

    local function At(frame, x, y)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + x, -TOP - y)
        frame:Show()
    end

    local function RenderTitle(p)
        local t = p:heading() or {}
        head:Set(t.icon, t.round)
        if t.portrait then BK.Portrait(t.portrait, head.icon) end
        Script(title, t.title, "SystemFont_Huge2", "GameFontNormalHuge")
        kind:SetText(t.kind or "")
        owned:SetText(t.owned or "")
        chapter:SetText(t.chapter or "")
    end

    function book:Render()
        local p = Top()
        if not p or not window:IsShown() then return end
        RenderTitle(p)
        local view = View(p)
        view.page = math.max(1, math.min(view.page, #view.pages))
        local nc, nh = 0, 0
        paragraphs:Reset()
        local picked = view.cells[view.sel]
        local focused = self.focus == "ours"
        IF.Focus.Glow(window, focused)
        for _, item in ipairs(view.pages[view.page].items) do
            local on = focused and item == picked
            if item.doc then
                local fs = paragraphs:Next()
                fs:SetText(item.text)
                fs:SetJustifyH(item.doc == "sign" and "RIGHT" or "LEFT")
                fs:SetAlpha(item.doc == "sign" and 0.7 or 1)
                At(fs, 0, item.y)
            elseif item.header then
                nh = nh + 1
                local h = heads[nh]
                if h then
                    h.text:SetText(item.header)
                    h.info:SetText(item.info and tostring(item.info) or "")
                    At(h, 0, item.y)
                end
            else
                nc = nc + 1
                local c = cells[nc]
                if c then
                    c.index = item.index
                    Fill(c, item.line)
                    c.icon:SetFocus(on)
                    c.pointer:SetShown(on)
                    c.backplate:SetAlpha(on and 0.9 or 0.25)
                    At(c, item.x, item.y + 2)
                end
            end
        end
        for i = nc + 1, #cells do cells[i]:Hide() end
        for i = nh + 1, #heads do heads[i]:Hide() end
        paragraphs:HideRest()
        emptyText:SetShown(p.tab ~= "notes" and #view.cells == 0)
        emptyText:SetText(opts.empty or "Nothing is written here yet.")
        pageNo:SetShown(#view.pages > 1)
        pageNo:SetText("Page " .. view.page .. "/" .. #view.pages)
        local arrows = #view.pages > 1 and not IF.Input.Pad()
        prevPage:SetShown(arrows)
        nextPage:SetShown(arrows)
        prevPage:SetEnabled(view.page > 1)
        nextPage:SetEnabled(view.page < #view.pages)
        local line = focused and picked and picked.page == view.page and picked.line or nil
        RenderTip(p, line)
        if focused then
            SetHints(Hints(p, view, line))
        else
            -- (another window with the pad: no footer, as the game's own)
            legend:Hide()
        end
    end

    -----------------------------------------------------------------------
    -- The pad, while it's up: a catcher frame takes the buttons (ahead of
    -- the bag and loot windows' own navigation); only Escape is bound
    -----------------------------------------------------------------------
    local KEYS = {
        PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
        PAD1 = "A", PAD2 = "B", PAD3 = "X", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
        PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADRSTICK = "RS",
    }

    function book:Press(name, down)
        -- Circle on its release: closing on the press would hand the release
        -- to the window under it (the bags: closed)
        if name == "B" then
            -- (Circle let go after closing the map: not ours)
            if not down and self.skipRelease then
                self.skipRelease = nil
                return
            end
            if not down then self:Back() end
            return
        end
        if not down then return end
        if name == "UP" or name == "DOWN" or name == "LEFT" or name == "RIGHT" then Move(name)
        elseif name == "LB" then Turn(-1)
        elseif name == "RB" then Turn(1)
        elseif name == "LT" or name == "RT" then switch:Press(name)
        elseif name == "A" then self:Activate()
        elseif name == "X" then Alt()
        elseif name == "RS" then
            ToggleTips()
            self:Render()
        end
    end

    local catcher = K.NewFrame("Frame", nil, window)
    catcher:SetAllPoints(window)
    if catcher.EnableGamePadButton then
        catcher:SetScript("OnGamePadButtonDown", function(_, button)
            if KEYS[button] then book:Press(KEYS[button], true) end
        end)
        catcher:SetScript("OnGamePadButtonUp", function(_, button)
            if KEYS[button] then book:Press(KEYS[button], false) end
        end)
        -- (setting a gamepad handler switches the frame's input on by
        -- itself: off until it is wanted, else a frame on screen takes the
        -- pad from login)
        catcher:EnableGamePadButton(false)
    end

    -- (the mouse: the legend's buttons pressed as the pad's)
    legend:SetPress(catcher)

    local function TakePad(on)
        if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
    end

    -- (on its release, as Circle)
    local escape = K.NewFrame("Button", (opts.name or "ImprovedForeverBook") .. "Escape")
    escape:RegisterForClicks("AnyUp")
    escape:SetScript("OnClick", function() book:Back() end)

    local function BindEscape(on)
        if IF.InCombat() then return end
        ClearOverrideBindings(window)
        if on then SetOverrideBindingClick(window, true, "ESCAPE", escape:GetName()) end
    end

    function book:IsShown()
        return window:IsShown()
    end

    function book:HasFocus()
        return window:IsShown() and self.focus == "ours"
    end

    -- Where it sits: as the game's own panels, along the top beside the open
    -- windows (Focus.lua), again as they come and go
    IF.Focus.Dock(window)

    -- The game's focus dimmed while the book has the pad (not when it's
    -- opened over a window of ours: book.dim false), the window it was
    -- opened from counted (book.extra)
    local function NativeFocus(hide)
        if book.dim then IF.Focus.DimNative(window, hide, book.extra) end
    end

    -- L2 / R2 between the book and the window it was opened from: as the
    -- game's own windows (Focus.lua)
    switch = IF.Focus.Switch(window, {
        other = opts.other,
        label = opts.label,
        onChange = function(focus)
            local ours = focus == "ours"
            book.focus = ours and "ours" or "window"
            TakePad(ours)
            BindEscape(ours)
            NativeFocus(ours)
            book:Render()
        end,
    })

    -- The trigger to the other window and its label: label, "LT" / "RT"; nil: none
    function book:Behind()
        return switch:Behind()
    end

    -- focus: "ours" or "window"
    function book:SetFocus(focus)
        switch:Set(focus == "ours" and "ours" or "game")
    end

    -- (opened, back from the map, closed: the book has the pad)
    local function Ours()
        switch.focus = "ours"
        book.focus = "ours"
    end

    window:SetScript("OnUpdate", function()
        switch:Update()
    end)

    -- (the pad or the mouse taken up: the cursor, tooltip and legend for it)
    IF.Input.OnChange(function() book:Render() end)

    -- Opened on a page. how: { dim (false: over a window of ours, the game's
    -- focus left as it is), extra (the game's window it's opened from) }
    function book:Open(p, how)
        if IF.InCombat() or not p then return end
        wipe(self.stack)
        how = how or {}
        self.dim = how.dim ~= false
        self.extra = how.extra
        Ours()
        if not window:IsShown() then Sound("IG_SPELLBOOK_OPEN") end
        window:Show()
        TakePad(true)
        BindEscape(true)
        NativeFocus(true)
        self:Push(p)
    end

    function book:Close()
        if window:IsShown() then Sound("IG_SPELLBOOK_CLOSE") end
        window:Hide()
    end

    -- Out of the way while the map is up, its pages kept; back once it's
    -- closed (in combat: gone)
    local suspended = false
    function book:Suspend()
        suspended = true
        window:Hide()
    end

    function book:Resume()
        if not suspended then return end
        suspended = false
        if IF.InCombat() or #self.stack == 0 then return wipe(self.stack) end
        Ours()
        window:Show()
        TakePad(true)
        BindEscape(true)
        self.skipRelease = IsKeyDown and IsKeyDown("PAD2") or nil
        self:Render()
    end

    window:SetScript("OnHide", function()
        Ours()
        TakePad(false)
        NativeFocus(false)
        if not suspended then wipe(book.stack) end
        if GameTooltip:GetOwner() == page then GameTooltip:Hide() end
        if not IF.InCombat() then ClearOverrideBindings(window) end
        if opts.onHide then opts.onHide(book) end
    end)

    -- (its bindings can't be cleared once combat starts)
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", function() book:Close() end)

    return book
end
