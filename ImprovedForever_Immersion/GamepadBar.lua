-- The gamepad action bar laid out as Hogwarts Legacy's spells: bottom
-- right, in diamond tiles (the game's square slot turned): the face
-- buttons' four as a big diamond, the D-pad's four as a smaller one left
-- of it, one set at a time. Holding L2 / R2 (or both) swaps the icons in
-- place to that set, four pips under the face diamond saying which set is
-- up.
-- Ours only shows: the game's bar (Blizzard_GamepadActionBars) does every
-- press and keeps every slot, so the Bindings tab and the game's own
-- editor stay as they are. Its crosses are drawn at 0 (IF.Focus.Fade, an
-- animation of ours: a property of the game's frames set from addon code
-- taints them), a frame of ours over each taking the mouse they'd still
-- get, and ours mirrors the buttons of whichever bar it has active (its
-- top / L2 / R2 / both bar, or one standing in: a vehicle's, a stance
-- bar...): their icon, its tint (unusable, out of range), count, pressed
-- state; the tile lit while cast from, toggled on or on a proc; a ring
-- round it for a cast from it, its item's buff (food, drink) or its
-- cooldown (not the global one); a
-- spell, item or macro dropped on ours with the mouse goes into the slot
-- it shows, and one dragged off is picked up (out of combat). Its two
-- class action buttons (L1 + L2, R1 + R2) too, beside the diamonds, their two-glyph
-- prompt over them.
-- A cooldown can be a secret (Forever restricts them at times): its ring
-- and countdown then aren't shown.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local GB = {}
IN.GamepadBar = GB

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function PageUnit()
    local main = GamepadMainActionBarFrame
    return main and main.PageUnit
end

---------------------------------------------------------------------------
-- Layout: each diamond's buttons (the game's order in a cluster: left, up,
-- right, down) round its centre, the glyph of the press outside each
---------------------------------------------------------------------------
local DIRS = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } }
local FACE_KEYS = { "PAD3", "PAD4", "PAD2", "PAD1" }
local DPAD_KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN" }

-- The tiles' style (the setting padStyle, GB.SetStyle):
-- * diamond, as Hogwarts Legacy's: the game's square slot turned a quarter
--   of a right angle, cut by the game's diamond mask; the four edge to edge
--   as one big diamond;
-- * square: the game's square slot as it is (its own square mask), the
--   four in two rows and two columns, each where the diamond's had it
--   (turned an eighth back: left top left, up top right, right bottom
--   right, down bottom left);
-- * circle: the game's circle slot (its own circle mask), the four in a
--   cross as the game's own bar has them.
-- A tile's visible side: VISIBLE times its size (the art's soft margin
-- left out); its width across (a diamond's point to point: that times the
-- root of 2); TILE_GAP between two. `spread`: each tile's middle out from
-- the group's (a grid's: on each axis).
local ROOT2 = math.sqrt(2)
local VISIBLE, TILE_GAP = 1.2, 3
local CLASS_GAP = 10    -- (the class actions' tiles off their group's)
local STYLES = {
    diamond = { slot = "squareslot", mask = "progress-bar-diamond-pip-mask", turn = math.pi / 4, pointed = true,
        upright = 0.5 },
    square = { slot = "squareslot", mask = "SquareMask", turn = 0, grid = true, upright = 0.72 },
    circle = { slot = "circleslot", mask = "CircleMask", turn = 0, round = true, upright = 0.7 },
}
GB.STYLE_ORDER = { "diamond", "square", "circle" }
local style, styleName = STYLES.square, "square"

-- (every size table made, so a new style reshapes them all)
local dims = setmetatable({}, { __mode = "k" })
local function Shape(d)
    dims[d] = true
    d.side = d.size * VISIBLE
    d.width = style.pointed and d.side * ROOT2 or d.side
    d.spread = style.grid and (d.side + TILE_GAP) / 2 or (d.side + TILE_GAP) / ROOT2
    return d
end
local FACE = Shape({ size = 44, glyph = 22 })
local DPAD = Shape({ size = 36, glyph = 18 })
local CLASS = Shape({ size = 36, glyph = 18 })

-- (a press's direction to its tile's place, times its spread: the
-- cross's, or a grid's corner)
local function Place(dir)
    if style.grid then return dir[1] + dir[2], dir[2] - dir[1] end
    return dir[1], dir[2]
end

-- (how far a tile's glyph reaches past its corner, and a little more: a
-- grid's tiles' glyphs are at their outer corners, Button)
local function GlyphOut(d)
    return d.glyph * 0.7 + 3
end

-- Where a class action's tile sits by a group: CLASS_GAP off the upper
-- outer edge of its top tile (in a diamond's turned frame: one tile further
-- along; a grid's: beside its top row's outer tile), as (x, y) from the
-- group's middle, x away from the screen's middle line of the group
local function ClassSpot(d)
    -- (a grid: a row of its own over the group, over its outer column,
    -- clear of that column's corner glyph: GlyphOut)
    if style.grid then return d.spread, d.spread + d.side / 2 + GlyphOut(d) + CLASS.side / 2 end
    local a = d.spread / ROOT2
    local rx, ry = a + d.side / 2 + CLASS_GAP + CLASS.side / 2, a
    return (rx - ry) / ROOT2, (rx + ry) / ROOT2
end
-- (as far in from the screen's right edge as the player frame from its
-- left (UnitFrames.lua), its tiles' bottom on the HUD's shared bottom,
-- IN.BOTTOM: the holder's corner there, the outermost tile's edge on it)
local MARGIN_X = 20
local GAP = 34          -- (between the two groups)

local holder = CreateFrame("Frame", "ImprovedForeverGamepadBar", UIParent)
holder:SetFrameStrata("LOW")
holder:SetSize(1, 1)
holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MARGIN_X, IN.BOTTOM)
holder:Hide()
-- (the keyboard and mouse bar shown, not the pad's: KeyTiles below)
local keyMode = false

local function Extent(d)
    return d.spread + d.width / 2 + d.glyph / 2
end

local faceCenter = CreateFrame("Frame", nil, holder)
faceCenter:SetSize(1, 1)
local dpadCenter = CreateFrame("Frame", nil, holder)
dpadCenter:SetSize(1, 1)
-- (the groups placed for the style: the D-pad's raised so its class
-- action sits on one row with the face buttons')
local function PlaceGroups()
    -- (the face group's lowest and rightmost tile edges (its class
    -- action's further right) on the holder's corner)
    local edge = FACE.spread + FACE.width / 2
    local classX = ClassSpot(FACE)
    faceCenter:ClearAllPoints()
    faceCenter:SetPoint("CENTER", holder, "BOTTOMRIGHT", -math.max(edge, classX + CLASS.width / 2), edge)
    -- (a grid: both groups' bottoms on one line)
    local _, faceClassY = ClassSpot(FACE)
    local _, dpadClassY = ClassSpot(DPAD)
    local dy = faceClassY - dpadClassY
    if style.grid then dy = (DPAD.spread + DPAD.width / 2) - (FACE.spread + FACE.width / 2) end
    dpadCenter:ClearAllPoints()
    dpadCenter:SetPoint("CENTER", faceCenter, "CENTER", -(Extent(FACE) + GAP + Extent(DPAD)), dy)
end
PlaceGroups()

---------------------------------------------------------------------------
-- A button of ours: the game's square slot (its background, the icon in
-- its rounded mask, its border; pressed / toggled borders), a cooldown, a
-- count, the press's glyph
---------------------------------------------------------------------------
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- (the set pips)
-- The game's square slot (its D-pad buttons' look), turned into a
-- diamond: background, border, pressed and selected borders; the icon
-- upright, cut to a diamond (the game's diamond mask)
-- (the style's slot art, its mask; filled in place by SetSlot)
local SLOT = {}
local TURN
local function SetSlot()
    local slot = "gamepad-actionbar-" .. style.slot
    SLOT.bg = slot .. "-bg"
    SLOT.normal = slot .. "-border-normal"
    SLOT.pressed = slot .. "-border-pressed"
    SLOT.selected = slot .. "-border-selected"
    SLOT.mask = style.mask
    TURN = style.turn
end
SetSlot()
-- (toggled on, a proc: the diamond lit, at these colours and strengths)
local CHECKED_FILL, CHECKED_ALPHA = { 1, 0.75, 0.25 }, 0.35
local PROC_FILL, PROC_ALPHA = { 1, 0.95, 0.6 }, 0.3
-- (a cooldown's beat, its end: the diamond flashing in the cooldown's
-- colour, at most these)
local FLASH_FILL, BEAT_FLASH, READY_FLASH = { 1, 1, 1 }, 0.4, 0.45
-- (a cooldown this short is the global one: not shown)
local GCD_MAX = 1.6
-- (the cast ring: on the border, RING_AT of the tile's half width out; its
-- line and glow's thickness)
local RING_AT, RING_LINE, RING_GLOW = 0.96, 2.5, 4
local COUNT_BADGE = 22              -- (the count's circle, inside a tile's foot, clear of its glyph)
local COUNT_LIFT = 3
-- (an icon's share of its tile: a turned one's side, the diamond mask's
-- width; an upright one fits inside at half the diamond's width)
local ICON_FILL = 0.94
local function UprightFill() return style.upright end

-- A turned texture's atlas changed, its turn kept (only when it changes)
local function SetBorder(b, atlas)
    if b.borderAtlas == atlas then return end
    b.borderAtlas = atlas
    b.border:SetAtlas(atlas)
    b.border:SetRotation(TURN)
end

-- The game's action slot ours shows, when it is one (the top bar's own
-- face buttons, drawn on SpecialActionIcon, aren't)
local function Slot(b)
    local native = b.native
    if not (native and native.action) then return nil end
    local special = native.SpecialActionIcon
    if special and special:IsShown() then return nil end
    return native.action
end

local function Drop(b)
    local slot = Slot(b)
    if not slot or IF.InCombat() or not GetCursorInfo() then return end
    PlaceAction(slot)
end

-- (bars locked: only with the pick-up modifier, as the game's)
local function DragOff(b)
    local slot = Slot(b)
    if not slot or IF.InCombat() or not HasAction(slot) then return end
    local locked = GetCVarBool and GetCVarBool("lockActionBars")
    if locked and not IsModifiedClick("PICKUPACTION") then return end
    PickupAction(slot)
end

local tiles = setmetatable({}, { __mode = "k" })    -- (every tile made: reshaped with the style)

local function Button(center, d, dir, key, parent)
    local b = CreateFrame("Frame", nil, parent or holder)
    tiles[b] = true
    b.center, b.dir = center, dir
    b:SetSize(d.size, d.size)
    local px, py = Place(dir)
    b:SetPoint("CENTER", center, "CENTER", px * d.spread, py * d.spread)
    b:EnableMouse(true)

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAtlas(SLOT.bg)
    b.bg:SetPoint("CENTER")
    b.bg:SetSize(d.side, d.side)
    b.bg:SetRotation(TURN)
    -- (the icon under its border, cut to the diamond by a mask of its own
    -- size: Picture turns a spell's or item's icon with the tile, so the
    -- whole square fills it; the game's own symbols stay upright, as big
    -- as fits inside)
    b.d = d
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    local mask = b:CreateMaskTexture()
    mask:SetAtlas(SLOT.mask)
    mask:SetPoint("CENTER")
    mask:SetSize(d.width * ICON_FILL, d.width * ICON_FILL)
    b.icon:AddMaskTexture(mask)
    b.mask = mask
    -- (toggled on, a proc: the diamond lit over the icon, cut by the same
    -- mask; Mirror)
    local function Fill(color, sub)
        local t = b:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetPoint("CENTER")
        t:SetSize(d.width * ICON_FILL, d.width * ICON_FILL)
        t:SetColorTexture(color[1], color[2], color[3], 1)
        t:SetBlendMode("ADD")
        t:AddMaskTexture(mask)
        t:SetAlpha(0)
        return t
    end
    b.checkedFill = Fill(CHECKED_FILL, 2)
    b.procFill = Fill(PROC_FILL, 3)
    b.flashFill = Fill(FLASH_FILL, 4)
    b.fills = { b.checkedFill, b.procFill, b.flashFill }

    -- (a square sweep would spill out of the diamond: the countdown only,
    -- the icon dimmed while it runs, Mirror)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetPoint("CENTER")
    b.cooldown:SetSize(d.side, d.side)
    b.cooldown:SetDrawSwipe(false)
    b.cooldown:SetDrawEdge(false)
    b.cooldown:SetDrawBling(false)
    -- (its numbers ours, short: Mirror)
    b.cooldown:SetHideCountdownNumbers(true)

    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.cooldown:GetFrameLevel() + 2)
    local function Turned(atlas, scale, sub)
        local t = over:CreateTexture(nil, "OVERLAY", nil, sub)
        t:SetAtlas(atlas)
        t:SetPoint("CENTER")
        t:SetSize(d.size * scale, d.size * scale)
        t:SetRotation(TURN)
        return t
    end
    b.border = Turned(SLOT.normal, 64 / 46, 0)
    b.borderAtlas = SLOT.normal
    -- (a cast from this slot: a line running round the tile's border, its
    -- four edges clockwise from the top point, each with a wider, fainter
    -- one under it as its glow; CastFill)
    b.ring = CreateFrame("Frame", nil, over)
    b.ring:SetAllPoints()
    b.ring:SetFrameLevel(over:GetFrameLevel() + 1)
    b.ring.r = d.width / 2 * RING_AT
    b.ring.glows, b.ring.lines = {}, {}
    b.ring:Hide()
    b.timer = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    b.timer:SetPoint("CENTER")
    b.timer:SetShadowOffset(1, -1)
    b.timer:Hide()
    -- (the count in the game's level badge, under the tile's foot: legible
    -- on any icon; as wide as its digits need)
    b.countBg = over:CreateTexture(nil, "OVERLAY", nil, 2)
    b.countBg:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    b.countBg:Hide()
    b.count = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetDrawLayer("OVERLAY", 3)
    b.count:SetShadowOffset(1, -1)
    b.count:SetPoint("CENTER", b.countBg, "CENTER", 0, -0.5)
    b.countBg:SetPoint("BOTTOM", b, "CENTER", 0, -d.width / 2 + (b.countLift or COUNT_LIFT))
    hooksecurefunc(b.count, "SetText", function(self, text)
        local on = type(text) == "string" and text ~= ""
        b.countBg:SetShown(on)
        if on then b.countBg:SetSize(math.max(COUNT_BADGE, self:GetStringWidth() + 10), COUNT_BADGE) end
    end)

    b.key = over:CreateTexture(nil, "OVERLAY", nil, 2)
    b.key:SetSize(d.glyph, d.glyph)
    b.key.size = d.glyph
    -- (outside it: past its point, or square, its outer corner)
    b.key:SetPoint("CENTER", b, "CENTER", px * (d.width / 2 + d.glyph * 0.2),
        py * (d.width / 2 + d.glyph * 0.2))
    b.keyName = key

    b:SetScript("OnEnter", function(self)
        local native = self.native
        local action = native and native.action
        if not action then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if pcall(GameTooltip.SetAction, GameTooltip, action) then GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- (the mouse: what it holds dropped into the slot shown, the slot's
    -- action dragged off, as the game's buttons do; out of combat)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnReceiveDrag", Drop)
    b:SetScript("OnMouseUp", function(self)
        if GetCursorInfo() then Drop(self) end
    end)
    b:SetScript("OnDragStart", DragOff)
    return b
end

-- A key tile's keybind text, inside its top (a diamond's top is a point:
-- lower)
local function PlaceHotkey(b)
    local d = b.d
    b.hotkey:ClearAllPoints()
    b.hotkey:SetPoint("TOP", b, "CENTER", 0, style.pointed and d.width / 4 + 2 or d.side / 2 - 3)
end

-- A tile reshaped for the style: its place (unless placed by its owner:
-- b.placed), slot art, mask, fills, cooldown, border, ring, count, glyph
local function Reshape(b)
    local d = b.d
    b:SetSize(d.size, d.size)
    if not b.placed then
        local px, py = Place(b.dir)
        b:ClearAllPoints()
        b:SetPoint("CENTER", b.center, "CENTER", px * d.spread, py * d.spread)
    end
    b.bg:SetAtlas(SLOT.bg)
    b.bg:SetSize(d.side, d.side)
    b.bg:SetRotation(TURN)
    b.mask:SetAtlas(SLOT.mask)
    b.mask:SetSize(d.width * ICON_FILL, d.width * ICON_FILL)
    for _, t in ipairs(b.fills) do t:SetSize(d.width * ICON_FILL, d.width * ICON_FILL) end
    b.cooldown:SetSize(d.side, d.side)
    b.borderAtlas = nil
    SetBorder(b, SLOT.normal)
    b.ring.r = d.width / 2 * RING_AT
    b.countBg:ClearAllPoints()
    b.countBg:SetPoint("BOTTOM", b, "CENTER", 0, -d.width / 2 + (b.countLift or COUNT_LIFT))
    if not b.placed then
        local px, py = Place(b.dir)
        b.key:ClearAllPoints()
        b.key:SetPoint("CENTER", b, "CENTER", px * (d.width / 2 + d.glyph * 0.2), py * (d.width / 2 + d.glyph * 0.2))
    end
    if b.hotkey then PlaceHotkey(b) end
    if b.onReshape then b.onReshape(b) end
end

local buttons = {}
for i, dir in ipairs(DIRS) do
    buttons[i] = Button(dpadCenter, DPAD, dir, DPAD_KEYS[i])
    buttons[4 + i] = Button(faceCenter, FACE, dir, FACE_KEYS[i])
end

-- The class actions, a tile each against their group's top tile: R1 + R2
-- at the face buttons' upper right, L1 + L2 at the D-pad's upper left (the
-- D-pad raised to put them on one row); their prompt (both glyphs) over
-- them
local function PlaceClass(b)
    local x, y = ClassSpot(b.group)
    b:ClearAllPoints()
    b:SetPoint("CENTER", b.center, "CENTER", b.sign * x, y)
    b.key:ClearAllPoints()
    b.key:SetPoint("BOTTOMRIGHT", b, "CENTER", -1, CLASS.width / 2 + 2)
    b.key2:ClearAllPoints()
    b.key2:SetPoint("BOTTOMLEFT", b, "CENTER", 1, CLASS.width / 2 + 2)
end

local function ClassButton(center, d, sign, keys)
    local b = Button(center, CLASS, { sign, 1 }, nil)
    b.placed, b.group, b.sign = true, d, sign
    b.key2 = b.key:GetParent():CreateTexture(nil, "OVERLAY", nil, 2)
    b.key2:SetSize(CLASS.glyph, CLASS.glyph)
    b.key2.size = CLASS.glyph
    b.keyName, b.keyName2 = keys[1], keys[2]
    PlaceClass(b)
    return b
end
local classLeft = ClassButton(dpadCenter, DPAD, -1, { "PADLSHOULDER", "PADLTRIGGER" })
local classRight = ClassButton(faceCenter, FACE, 1, { "PADRSHOULDER", "PADRTRIGGER" })

---------------------------------------------------------------------------
-- KeyTiles: with the keyboard and mouse bar (the Gamepad UI off), its 12
-- buttons (the game's main bar, ActionButton1 to 12) as three groups of
-- four, bottom right where the pad's diamonds are: same tiles, rings and
-- cooldowns, the key's name where the pad's glyph is. Left to right, top
-- to bottom in a grid (left, up, down, right in a cross).
---------------------------------------------------------------------------
local KEYD = Shape({ size = 36, glyph = 0 })
local KEY_GAP = 14          -- (between two groups)
local KEY_DIRS = { { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 0 } }
local keyCenters, keyButtons = {}, {}
for g = 1, 3 do
    local center = CreateFrame("Frame", nil, holder)
    center:SetSize(1, 1)
    keyCenters[g] = center
    for j, dir in ipairs(KEY_DIRS) do
        local b = Button(center, KEYD, dir, nil)
        -- (a secure catcher of ours over it takes the mouse: Catcher)
        b:EnableMouse(false)
        b.key:Hide()
        b.hotkey = b.key:GetParent():CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.hotkey:SetShadowOffset(1, -1)
        PlaceHotkey(b)
        b:Hide()
        keyButtons[(g - 1) * 4 + j] = b
    end
end

-- The menu's tile, left of the groups: three bars on a tile (the game's
-- micro menu and bags, drawn at 0 with the keyboard bar, are in the popup
-- it opens: Menu below)
local MENUD = Shape({ size = 30, glyph = 0 })
local menuCenter = CreateFrame("Frame", nil, holder)
menuCenter:SetSize(1, 1)
local menuTile = Button(menuCenter, MENUD, { 0, 0 }, nil)
menuTile.key:Hide()
menuTile.bars = {}
for i = 1, 3 do
    local t = menuTile.key:GetParent():CreateTexture(nil, "OVERLAY", nil, 3)
    t:SetColorTexture(0.92, 0.86, 0.7, 1)
    menuTile.bars[i] = t
end
menuTile.onReshape = function(b)
    local d = b.d
    for i, t in ipairs(b.bars) do
        t:ClearAllPoints()
        t:SetSize(d.side * 0.42, 2)
        t:SetPoint("CENTER", b, "CENTER", 0, (2 - i) * d.side * 0.16)
    end
end
menuTile.onReshape(menuTile)
menuTile:SetScript("OnDragStart", nil)
menuTile:SetScript("OnReceiveDrag", nil)
menuTile:Hide()

-- (the right group's corner on the holder's, its bottom on the HUD's)
local function KeyExtent()
    return KEYD.spread + KEYD.width / 2
end
local function PlaceKeys()
    local e = KeyExtent()
    menuCenter:ClearAllPoints()
    menuCenter:SetPoint("CENTER", keyCenters[1], "CENTER", -(e + KEY_GAP + MENUD.width / 2), MENUD.width / 2 - e)
    for g, center in ipairs(keyCenters) do
        center:ClearAllPoints()
        center:SetPoint("CENTER", holder, "BOTTOMRIGHT", -(e + (3 - g) * (2 * e + KEY_GAP)), e)
    end
end
PlaceKeys()

-- A press's glyph as the game's crossbar draws it (its
-- InputIconTextureFrameTemplate's art: the game's prompt for the
-- controller in use, read from its icon sets, its states Normal (1),
-- Pressed (3) and Disabled (5)), else ours (IF.GlyphAtlas). The game's newer
-- prompts (76 x 75) carry a shadow's padding: drawn bigger, their coords
-- cut, as the game lays them out (InputIconTextureMixin:ApplyTextureLayout,
-- for a 20 frame: 5 out at the top left, 4 and 3 at the bottom right).
local LARGE_W, LARGE_H = 76, 75
local function GameGlyphs(key)
    local util = _G.InputIconTextureSetUtility
    local ok, set = pcall(function() return util and util.GetActiveInputIconButtonTextures(key) end)
    return ok and type(set) == "table" and set or nil
end

local function Glyph(tex, key, state)
    local size = tex.size or tex:GetWidth()
    local set = key and GameGlyphs(key)
    local atlas = set and (set[state or 1] or set[1]) or nil
    if not (atlas and IF.HasAtlas and IF.HasAtlas(atlas)) then atlas = key and IF.GlyphAtlas(key) end
    tex.state = state or 1
    if not atlas then
        tex:SetTexture(nil)
        return
    end
    tex:SetAtlas(atlas)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info and info.width == LARGE_W and info.height == LARGE_H then
        local k = size / 20
        tex:SetSize(size + 9 * k, size + 8 * k)
        tex:SetTexCoord(0.015, 0.96, 0.015, 0.94)
    else
        tex:SetSize(size, size)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function UpdateGlyphs()
    for _, b in ipairs(buttons) do Glyph(b.key, b.keyName) end
    for _, b in ipairs({ classLeft, classRight }) do
        Glyph(b.key, b.keyName)
        Glyph(b.key2, b.keyName2)
    end
end

---------------------------------------------------------------------------
-- The set pips under the diamonds, centred on both: no trigger, L2, R2,
-- both; the one up lit. A bar standing in for them (a vehicle's...): none
-- lit.
---------------------------------------------------------------------------
local pips = {}
local PIP, PIP_GAP = 8, 6
-- (centred on the whole: midway between the two diamonds' middles; just
-- over the power line (IN.MP_H) and the health bar (IN.HP_H), the lit
-- one's bigger size clear of them. The face diamond's bottom point is on
-- IN.BOTTOM)
local PIPS_Y = IN.MP_H + IN.HP_H + 4 + (PIP + 3) / 2
for i = 1, 4 do
    local p = holder:CreateTexture(nil, "ARTWORK")
    p:SetSize(PIP, PIP)
    p:SetTexture(CIRCLE)
    pips[i] = p
end
local function PlacePips()
    local x = -(Extent(FACE) + GAP + Extent(DPAD)) / 2
    for i, p in ipairs(pips) do
        p:ClearAllPoints()
        p:SetPoint("CENTER", faceCenter, "CENTER", x + (i - 2.5) * (PIP + PIP_GAP),
            -(FACE.spread + FACE.width / 2) - (IN.BOTTOM - PIPS_Y))
    end
end
PlacePips()
local page = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
page:SetPoint("LEFT", pips[4], "RIGHT", 8, 0)

local function SetIndex(pu, bar)
    local bars = pu.actionBars or {}
    local order = { bars.topBar, bars.leftBar, bars.rightBar, bars.bottomBar }
    for i, p in ipairs(pips) do
        local on = bar ~= nil and order[i] == bar
        p:SetVertexColor(on and 1 or 0.45, on and 0.82 or 0.45, on and 0 or 0.45, on and 1 or 0.7)
        p:SetSize(on and PIP + 3 or PIP, on and PIP + 3 or PIP)
    end
    local n = pu.GetCurrentPage and pu.PageTracker and pu.PageTracker.currentPage
    page:SetText(type(n) == "number" and n > 1 and tostring(n) or "")
end

---------------------------------------------------------------------------
-- Mirroring the game's buttons
---------------------------------------------------------------------------
-- The game's button for ours: its cluster (Left: the D-pad, Right: the
-- face buttons) in the active bar
local function Native(bar, i)
    local side = bar and (i <= 4 and bar.Left or bar.Right)
    return side and side["ActionButton" .. ((i - 1) % 4 + 1)]
end

-- The slot's cooldown, in seconds (start, duration): its action's, read
-- straight from the game (C_ActionBar.GetActionCooldown; the button's own
-- cooldown frame is hidden or reset while it plays its cast animation),
-- else that frame's (the top bar's own face buttons)
local function SlotCooldown(native)
    -- (a stand-in's (GB.StandIn): its spell's or item's)
    if native.spellID then
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, info = pcall(C_Spell.GetSpellCooldown, native.spellID)
            if ok and type(info) == "table" then return info.startTime, info.duration end
        elseif GetSpellCooldown then
            local ok, start, duration = pcall(GetSpellCooldown, native.spellID)
            if ok then return start, duration end
        end
        return nil
    elseif native.itemID then
        local get = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
        if get then
            local ok, start, duration = pcall(get, native.itemID)
            if ok then return start, duration end
        end
        return nil
    end
    local action = native.action
    local special = native.SpecialActionIcon
    if action and not (special and special:IsShown()) then
        if C_ActionBar and C_ActionBar.GetActionCooldown then
            local ok, info = pcall(C_ActionBar.GetActionCooldown, action)
            if ok and type(info) == "table" then return info.startTime, info.duration end
        elseif GetActionCooldown then
            local ok, start, duration = pcall(GetActionCooldown, action)
            if ok then return start, duration end
        end
    end
    local cd = native.cooldown
    if cd and cd.GetCooldownTimes and cd:IsShown() then
        local ok, start, duration = pcall(cd.GetCooldownTimes, cd)
        if ok and not (Secret(start) or Secret(duration)) and type(start) == "number" and type(duration) == "number" then
            return start / 1000, duration / 1000
        end
    end
end

local function Cooldown(b, native)
    local start, duration = SlotCooldown(native)
    -- (none, a secret one, or the global cooldown: nothing)
    if Secret(start) or Secret(duration) or type(start) ~= "number" or type(duration) ~= "number"
        or duration <= GCD_MAX then
        if b.cdStart then
            b.cooldown:Clear()
            -- (run out, not cut short: its end flashes)
            local now = GetTime()
            if type(now) == "number" and type(b.cdUntil) == "number" and now >= b.cdUntil - 0.1 then
                b.cdDoneAt = now
            end
            b.cdStart, b.cdUntil = nil, nil
        end
        return
    end
    if b.cdStart ~= start or b.cdDuration ~= duration then
        b.cdStart, b.cdDuration = start, duration
        b.cdUntil = start + duration
        b.cooldown:SetCooldown(start, duration)
    end
end

-- A cast or channel from the slot: the game's button plays its own cast
-- animation while its action is the one being cast (SpellCastAnimFrame,
-- its fill's CastingAnim; else by name, SlotCasting); ours runs a line round its tile's border over the cast's
-- time (your casting or channel info), clockwise from the top point: blue
-- growing for a cast, green shrinking for a channel (not gold: the
-- glows are). Times the game keeps
-- secret: no ring (they can't be worked into a length).
local CAST_COLOR = { 0.35, 0.75, 1 }
-- A cooldown's time left, short and rounded up: 2h, 2m, 45
local function Short(left)
    if left >= 3600 then return math.ceil(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
end

-- (a cooldown's beat, as a party card's alert: each whole second left,
-- the ring flashing (bright on the beat, down to BEAT_LOW half a second
-- later) and the diamond pulsing (a flash fading over BEAT seconds); its
-- end, the whole ring flashing out over READY seconds)
local BEAT, BEAT_LOW, READY = 0.35, 0.35, 0.6
-- (its colour by the share of it left, as a monster's level (Module.lua):
-- red over 3/4, orange over 1/2, yellow over 1/4, green after; ready
-- green)
local function CooldownColor(f)
    local level = IN.LEVEL_COLORS
    if f > 0.75 then return level[4] end
    if f > 0.5 then return level[3] end
    if f > 0.25 then return level[2] end
    return level[1]
end

local CHANNEL_COLOR = { 0.4, 1, 0.5 }
-- (the corners, clockwise from the top: unit steps of the ring's radius)
-- (its path round the tile, clockwise, in units of its half width: a
-- diamond's from its top point, a square's from its top left corner, a
-- circle's from its top)
local CIRCLE_STEPS = 32
local function RingPath()
    if style.grid then return { { -1, 1 }, { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } } end
    if style.round then
        local path = {}
        for i = 0, CIRCLE_STEPS do
            local a = i / CIRCLE_STEPS * 2 * math.pi
            path[#path + 1] = { math.sin(a), math.cos(a) }
        end
        return path
    end
    return { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 }, { 0, 1 } }
end
GB.RingPath = RingPath

-- (a ring's line and glow for one segment, made as needed)
local function RingLines(ring, i)
    if not ring.lines[i] then
        local glow = ring:CreateLine(nil, "OVERLAY", nil, 1)
        glow:SetThickness(RING_GLOW)
        glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        glow:SetBlendMode("ADD")
        local line = ring:CreateLine(nil, "OVERLAY", nil, 2)
        line:SetThickness(RING_LINE)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetBlendMode("ADD")
        ring.glows[i], ring.lines[i] = glow, line
    end
    return ring.lines[i], ring.glows[i]
end

local function Casting(native)
    local anim = native and native.SpellCastAnimFrame
    local fill = anim and anim:IsShown() and anim.Fill
    local playing = fill and fill.CastingAnim
    return playing and playing:IsPlaying() and true or false
end

-- The ring drawn to f (0 to 1 of the way round); pulse (0 to 1) a beat
-- over it: the line whitened, its glow a little stronger (its width kept:
-- wider, the square ends block up at the corners; the tile flashes
-- instead, Mirror)
local function DrawRing(ring, f, color, pulse)
    local r = ring.r
    pulse = pulse or 0
    local lr = color[1] + (1 - color[1]) * pulse
    local lg = color[2] + (1 - color[2]) * pulse
    local lb = color[3] + (1 - color[3]) * pulse
    local path = RingPath()
    local segments = #path - 1
    for i = segments + 1, #ring.lines do
        ring.lines[i]:Hide()
        ring.glows[i]:Hide()
    end
    for i = 1, segments do
        local part = math.min(math.max(f * segments - (i - 1), 0), 1)
        local line, glow = RingLines(ring, i)
        if part <= 0 then
            line:Hide()
            glow:Hide()
        else
            local a, z = path[i], path[i + 1]
            local x1, y1 = a[1] * r, a[2] * r
            local x2, y2 = x1 + (z[1] - a[1]) * r * part, y1 + (z[2] - a[2]) * r * part
            for _, l in ipairs({ line, glow }) do
                l:SetStartPoint("CENTER", ring, x1, y1)
                l:SetEndPoint("CENTER", ring, x2, y2)
                l:Show()
            end
            line:SetVertexColor(lr, lg, lb, 1)
            glow:SetVertexColor(color[1], color[2], color[3], 0.25 + 0.25 * pulse)
        end
    end
end

-- The slot's spell (its action's, or its macro's) by name, or nil
local function SlotSpellName(native)
    if native and native.spellName then return native.spellName end
    local action = native and native.action
    if not action then return nil end
    local special = native.SpecialActionIcon
    if special and special:IsShown() then return nil end
    local ok, name = pcall(function()
        local kind, id = GetActionInfo(action)
        if Secret(kind) or Secret(id) then return nil end
        if kind == "macro" then id = GetMacroSpell(id) elseif kind ~= "spell" then return nil end
        if not id then return nil end
        return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo(id)
    end)
    return ok and name or nil
end

-- (the interact button's cast: one begun at something to interact with, a
-- herb, a vein, a corpse to skin, a chest; its spell's name, see
-- DrawCursor's casts below)
local interactCast

-- Casting from this slot: its button's cast animation, or (when the game
-- doesn't play it there: some channels come with another rank's id) your
-- cast or channel by the slot's spell's name (the interact button: by the
-- interact cast's)
local function SlotCasting(native, interact)
    if Casting(native) then return true end
    local slotName = SlotSpellName(native)
    if interact then slotName = interactCast end
    if not slotName then return false end
    if Secret(slotName) then return false end
    local ok, name = pcall(UnitChannelInfo, "player")
    if ok and not Secret(name) and not name then ok, name = pcall(UnitCastingInfo, "player") end
    if not ok or Secret(name) or not name then return false end
    return name == slotName
end

local function CastFill(b, native, interact)
    b.casting = false
    if not SlotCasting(native, interact) then
        if b.ring:IsShown() then b.ring:Hide() end
        return
    end
    local channel = false
    local _, _, texture, startMs, endMs = UnitCastingInfo("player")
    if not (Secret(startMs) or startMs) then
        _, _, texture, startMs, endMs = UnitChannelInfo("player")
        channel = true
    end
    if Secret(startMs) or Secret(endMs) or type(startMs) ~= "number" or type(endMs) ~= "number"
        or endMs <= startMs then
        b.ring:Hide()
        return
    end
    local f = (GetTime() * 1000 - startMs) / (endMs - startMs)
    f = math.min(math.max(f, 0), 1)
    -- (in the cast's icon's colour, as the cast line (PlayerCast.lua), else
    -- the casting bar's)
    local PC = IN.PlayerCast
    local color = PC and PC.IconColor and PC.IconColor(texture)
    DrawRing(b.ring, channel and (1 - f) or f, color or (channel and CHANNEL_COLOR or CAST_COLOR))
    b.ring:SetAlpha(1)
    b.ring:Show()
    b.flashFill:SetAlpha(0)
    b.casting = true
end

-- A buff from the slot's item (food, drink, a bandage's...): the spell
-- the item casts when used (its "Use:"), on you now. Its time left and
-- whole time, and whether it's a drink (by the spell's name), or nil.
-- Read whole or not at all (a secret: none).
local DRINK_NAME = _G.DRINK or "Drink"
local FOOD_COLOR = { 1, 0.6, 0.2 }
local DRINK_COLOR = { 0.3, 0.9, 1 }
local itemSpells = {}      -- (itemID: { name, spellID } or false)

local function ItemSpell(itemID)
    local known = itemSpells[itemID]
    if known ~= nil then return known end
    local get = C_Item and C_Item.GetItemSpell or GetItemSpell
    local name, spellID = get and get(itemID)
    -- (not cached when the item isn't loaded yet: asked again)
    if name then itemSpells[itemID] = { name = name, spellID = spellID } end
    return itemSpells[itemID] or false
end

local function ItemBuff(native)
    local action = native.action
    local special = native.SpecialActionIcon
    if not native.itemID and (not action or (special and special:IsShown())) then return nil end
    local ok, left, whole, drink = pcall(function()
        local id = native.itemID
        if not id then
            local kind
            kind, id = GetActionInfo(action)
            if Secret(kind) or Secret(id) or kind ~= "item" or not id then return nil end
        end
        local spell = ItemSpell(id)
        if not spell then return nil end
        local aura = spell.spellID and C_UnitAuras.GetPlayerAuraBySpellID(spell.spellID)
        if not aura and C_UnitAuras.GetAuraDataBySpellName then
            aura = C_UnitAuras.GetAuraDataBySpellName("player", spell.name, "HELPFUL")
        end
        if not aura or Secret(aura.duration) or Secret(aura.expirationTime) then return nil end
        if not aura.duration or aura.duration <= 0 then return nil end
        return aura.expirationTime - GetTime(), aura.duration, spell.name:find(DRINK_NAME) ~= nil
    end)
    if not ok or type(left) ~= "number" or left <= 0 then return nil end
    return left, whole, drink
end

-- What the game's button shows: its own picture when it has one (the top
-- bar's face buttons are the game's own: interact, inspect, back, jump,
-- drawn on SpecialActionIcon: an atlas, a cursor, a raid marker), else its
-- action's icon. Copied onto ours: (texture or atlas, its coords).
local function Has(v)
    return Secret(v) or v ~= nil
end

local function Picture(native)
    if not (native and native:IsShown()) then return false end
    local special = native.SpecialActionIcon
    if special and special:IsShown() then
        local atlas = special.GetAtlas and special:GetAtlas()
        if Secret(atlas) or (type(atlas) == "string" and atlas ~= "") then return true, nil, atlas end
        local texture = special:GetTexture()
        if Has(texture) then return true, texture, nil, { special:GetTexCoord() } end
    end
    local icon = native.icon
    if not (icon and icon:IsShown()) then return false end
    local texture = icon:GetTexture()
    if Has(texture) then return true, texture, nil, nil, icon end
    return false
end

local FULL = { 0.07, 0.07, 0.07, 0.93, 0.93, 0.07, 0.93, 0.93 }   -- (an icon's own edge cropped)

-- The interact button (the top bar's right face cluster's first): the game
-- draws a unit's cursor on it (SetUnitCursorTexture: a herb's, an NPC's),
-- a picture it can't hand on. Ours draws the same cursor itself, for the
-- unit the game's would (MainActionBarFrame.lua's interact actions: the
-- soft interact target in range, else the target to interact with; their
-- loot icons are readable pictures)
local function InteractButton()
    local pu = PageUnit()
    local top = pu and pu.actionBars and pu.actionBars.topBar
    return top and top.Right and top.Right.ActionButton1
end

local function Yes(fn, unit)
    if not fn then return false end
    local ok, v = pcall(fn, unit)
    return ok and not Secret(v) and v and true or false
end

local function CursorUnit()
    local soft = Yes(UnitExists, "softinteract") or Yes(UnitIsGameObject, "softinteract")
    if soft and Yes(UnitIsInInteractRange, "softinteract") then
        return not Yes(UnitHasLootInteraction, "softinteract") and "softinteract" or nil
    end
    if Yes(UnitExists, "target") and not Yes(UnitHasLootInteraction, "target") and Yes(UnitIsInteractable, "target") then
        return "target"
    end
end

-- (a cast of yours begun with something to interact with in reach, its
-- spell on none of your action slots (gathering, skinning, opening): the
-- interact button's, its progress shown on it)
local castWatch = CreateFrame("Frame")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
castWatch:SetScript("OnEvent", function(_, _, _, _, spellID)
    interactCast = nil
    if Secret(spellID) or type(spellID) ~= "number" then return end
    local near = Yes(UnitExists, "softinteract") or Yes(UnitIsGameObject, "softinteract")
        or (Yes(UnitExists, "target") and Yes(UnitIsInteractable, "target"))
    if not near then return end
    local find = C_ActionBar and C_ActionBar.FindSpellActionButtons
    local ok, slots = pcall(function() return find and find(spellID) end)
    if ok and type(slots) == "table" and not Secret(slots) and #slots > 0 then return end
    local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    local named, name = pcall(get, spellID)
    if named and type(name) == "string" and not Secret(name) then interactCast = name end
end)

-- (drawn on ours: true)
local function DrawCursor(b, native)
    if native ~= InteractButton() then return false end
    local unit = CursorUnit()
    if not unit then return false end
    local ok, drawn = pcall(SetUnitCursorTexture, b.icon, unit, nil, nil, false)
    return ok and not Secret(drawn) and drawn and true or false
end

local function Mirror(b, native)
    b.native = native
    local interact = native ~= nil and native == InteractButton()
    local cursor = DrawCursor(b, native)
    local has, texture, atlas, coords, icon = Picture(native)
    if cursor then has, texture, atlas, coords, icon = true, nil, nil, nil, nil end
    if not has then
        b.icon:SetTexture(nil)
        b.count:SetText("")
        b.ring:Hide()
        b.checkedFill:SetAlpha(0)
        b.procFill:SetAlpha(0)
        b.flashFill:SetAlpha(0)
        b.timer:Hide()
        SetBorder(b, SLOT.normal)
        if b.cdStart then
            b.cooldown:Clear()
            b.cdStart = nil
        end
        return
    end
    local d = b.d
    if cursor then
        -- (the cursor drawn above, its own coords: upright)
        b.icon:SetSize(d.width * UprightFill(), d.width * UprightFill())
        b.icon:SetRotation(0)
    elseif Has(atlas) then
        b.icon:SetAtlas(atlas)
        b.icon:SetSize(d.width * UprightFill(), d.width * UprightFill())
        b.icon:SetRotation(0)
    else
        b.icon:SetTexture(texture)
        b.icon:SetTexCoord(unpack(coords or FULL))
        if coords then
            -- (the game's own picture, a cursor or a raid marker: upright)
            b.icon:SetSize(d.width * UprightFill(), d.width * UprightFill())
            b.icon:SetRotation(0)
        else
            b.icon:SetSize(d.side * ICON_FILL, d.side * ICON_FILL)
            b.icon:SetRotation(TURN)
        end
    end
    -- The icon's colour: the game's (unusable, out of range), dimmed while
    -- cooling down
    if icon then
        b.icon:SetVertexColor(icon:GetVertexColor())
        b.icon:SetDesaturated(b.disabled or icon:IsDesaturated())
    else
        b.icon:SetVertexColor(1, 1, 1)
        b.icon:SetDesaturated(b.disabled and true or false)
    end
    Cooldown(b, native)
    local now = GetTime()
    local cooling = type(b.cdUntil) == "number" and type(now) == "number" and now < b.cdUntil
    if cooling then b.icon:SetVertexColor(0.4, 0.4, 0.4) end

    -- The ring: a cast from the slot, else a buff from its item (food,
    -- drink: shrinking with its time left, its timer on it), else its
    -- cooldown (coloured by its share left, unwinding: the share still to wait)
    CastFill(b, native, interact)
    if b.casting then
        b.timer:Hide()
    else
        local left, whole, drink = ItemBuff(native)
        if left then
            DrawRing(b.ring, left / whole, drink and DRINK_COLOR or FOOD_COLOR)
            b.ring:SetAlpha(1)
            b.ring:Show()
            b.flashFill:SetAlpha(0)
            b.timer:SetText(Short(left))
            b.timer:Show()
            b.buffing = true
        else
            b.buffing = false
        end
    end
    if not (b.casting or b.buffing) then
        local done = type(b.cdDoneAt) == "number" and type(now) == "number" and now - b.cdDoneAt
        if cooling and type(b.cdDuration) == "number" and b.cdDuration > 0 then
            -- (a beat on each whole second left: the ring's flash, the
            -- diamond's pulse)
            local left = b.cdUntil - now
            local share = left / b.cdDuration
            local color = CooldownColor(share)
            local since = 1 - (left - math.floor(left))
            local beat = math.max(0, 1 - since / BEAT)
            local wave = 0.5 + 0.5 * math.cos(2 * math.pi * since)
            b.timer:SetText(Short(left))
            b.timer:Show()
            DrawRing(b.ring, share, color)
            b.ring:SetAlpha(BEAT_LOW + (1 - BEAT_LOW) * wave)
            b.ring:Show()
            b.flashFill:SetVertexColor(color[1], color[2], color[3], 1)
            b.flashFill:SetAlpha(BEAT_FLASH * beat)
        elseif done and done < READY then
            b.timer:Hide()
            -- (ready: the whole ring and the tile flashing out, green)
            local color = CooldownColor(0)
            local fade = 1 - done / READY
            DrawRing(b.ring, 1, color, fade)
            b.ring:SetAlpha(fade)
            b.ring:Show()
            b.flashFill:SetVertexColor(color[1], color[2], color[3], 1)
            b.flashFill:SetAlpha(READY_FLASH * fade)
        else
            if b.ring:IsShown() then b.ring:Hide() end
            b.flashFill:SetAlpha(0)
            b.timer:Hide()
        end
        if not (cooling or (done and done < READY)) then b.ring:SetAlpha(1) end
    end

    -- The diamond lit: casting or channelling from it, its item's buff on
    -- you (with its ring),
    -- toggled on (GetChecked can be a secret: SetAlphaFromBoolean takes it
    -- as it is), a proc
    if b.casting or b.buffing then
        b.checkedFill:SetAlpha(CHECKED_ALPHA)
    else
        local checked = native.GetChecked and native:GetChecked()
        if not pcall(b.checkedFill.SetAlphaFromBoolean, b.checkedFill, checked, CHECKED_ALPHA, 0) then
            b.checkedFill:SetAlpha(0)
        end
    end
    local alert = native.SpellActivationAlert
    b.procFill:SetAlpha(alert and alert:IsShown() and PROC_ALPHA or 0)

    local count = native.Count
    pcall(b.count.SetText, b.count, count and count:IsShown() and count:GetText() or "")
    local ok, pressed = pcall(function() return native:GetButtonState() == "PUSHED" end)
    SetBorder(b, ok and pressed and SLOT.pressed or SLOT.normal)
    -- (its glyph pressed with it, greyed while it's disabled, as the game's)
    if b.keyName then
        local state = b.disabled and 5 or (ok and pressed and 3) or 1
        if b.key.state ~= state then Glyph(b.key, b.keyName, state) end
    end
end

-- /if padprobe: what the game's active bar holds, logged in the saved
-- variables (ImprovedForeverDB.padProbe; /reload, then read it)
function GB.Probe()
    local pu = PageUnit()
    local log = { date("%H:%M:%S") .. " pad probe" }
    IF.db.padProbe = log
    if not pu then
        IF.Print("pad probe: no gamepad bar")
        return
    end
    local bars = pu.actionBars or {}
    local names = {}
    for key, bar in pairs(bars) do names[bar] = key end
    local active = pu.activeBar
    log[#log + 1] = "active " .. tostring(names[active] or active) .. ", page " .. tostring(pu.PageTracker and pu.PageTracker.currentPage)
    for key, bar in pairs(bars) do
        log[#log + 1] = string.format("bar %s shown=%s visible=%s", key, tostring(bar:IsShown()), tostring(bar:IsVisible()))
    end
    for i = 1, 8 do
        local n = Native(active, i)
        if not n then
            log[#log + 1] = i .. ": no button"
        else
            local icon, special = n.icon, n.SpecialActionIcon
            log[#log + 1] = string.format("%d: %s shown=%s action=%s has=%s icon=%s/%s/%.2f special=%s/%s",
                i, tostring(n:GetName()), tostring(n:IsShown()), tostring(n.action),
                tostring(n.action and HasAction(n.action)), tostring(icon and icon:IsShown()),
                tostring(icon and icon:GetTexture()), icon and icon:GetAlpha() or -1,
                tostring(special and special:IsShown()), tostring(special and (special:GetAtlas() or special:GetTexture())))
            local cs, cdur = SlotCooldown(n)
            log[#log + 1] = string.format("   cooldown %s / %s (secret %s), frame shown=%s",
                Secret(cs) and "<hidden>" or tostring(cs), Secret(cdur) and "<hidden>" or tostring(cdur),
                tostring(Secret(cs) or Secret(cdur)), tostring(n.cooldown and n.cooldown:IsShown()))
        end
    end
    IF.Print("pad probe: " .. #log .. " lines; /reload to save them")
end

---------------------------------------------------------------------------
-- The game's crosses drawn at 0 while ours shows (Edit Mode: the game's
-- shown, ours not), and ours mirrored a few dozen times a second
---------------------------------------------------------------------------
local function NativeParts(pu)
    local parts = { pu.TopCenteredAnchor, pu.LeftCenteredAnchor, pu.RightCenteredAnchor, pu.BottomCenteredAnchor,
        pu.PageTracker, pu.LeftShoulderBackground, pu.RightShoulderBackground, pu.LeftShoulderIcon,
        pu.RightShoulderIcon, pu.LeftShoulderHighlight, pu.RightShoulderHighlight, pu.LeftClassAction,
        pu.RightClassAction, pu.LeftInputPrompt, pu.RightInputPrompt }
    return parts
end

-- (what the mouse would still find under them)
local function NativeBars(pu)
    local bars = pu.actionBars or {}
    return { bars.topBar, bars.leftBar, bars.rightBar, bars.bottomBar, pu.LeftClassAction, pu.RightClassAction }
end

-- A class action of ours, shown while the game's is (it has one for the
-- class, in a form...)
local function MirrorClass(b, native)
    local on = native ~= nil and native:IsShown()
    b:SetShown(on)
    if on then Mirror(b, native) end
end

local shown, padShown

-- A key tile's keybind: the game's own text on its button (what it has when
-- unbound is the range dot: none)
local function HotkeyText(native)
    local hk = native.HotKey
    if not (hk and hk:IsShown()) then return "" end
    local ok, text = pcall(hk.GetText, hk)
    if not ok or Secret(text) or type(text) ~= "string" or text == RANGE_INDICATOR then return "" end
    return text
end

-- What the mouse does on a key tile: a secure button of ours over it
-- clicks the game's button (so it works in a fight), and its tooltip and
-- drags are the game's (pick up out of combat, drop onto it). Not a child
-- of the holder or anchored to a tile (a secure frame's protection spreads
-- to what it's anchored to): placed by the tile's rect, out of combat only.
local catchers = {}

local function Catcher(i)
    local c = catchers[i]
    if c then return c end
    local native = _G["ActionButton" .. i]
    if not native or InCombatLockdown() then return nil end
    c = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    c:SetParent(UIParent)
    c:SetFrameStrata("LOW")
    c:SetFrameLevel(60)
    c:RegisterForClicks("AnyUp")
    c:RegisterForDrag("LeftButton")
    c:SetAttribute("type", "click")
    c:SetAttribute("clickbutton", native)
    c:SetScript("OnEnter", function(self)
        local action = native.action
        if not action then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if pcall(GameTooltip.SetAction, GameTooltip, action) then GameTooltip:Show() end
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnDragStart", function() DragOff({ native = native }) end)
    c:SetScript("OnReceiveDrag", function() Drop({ native = native }) end)
    c:Hide()
    catchers[i] = c
    return c
end

local function PlaceCatchers(on)
    if InCombatLockdown() then return end
    for i, b in ipairs(keyButtons) do
        local shownTile = on and b:IsShown()
        local c = shownTile and Catcher(i) or catchers[i]
        if c then
            local x, y = b:GetCenter()
            if shownTile and x and y then
                local d = b.d
                local k = b:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local size = (style.pointed and d.width or d.side) * k
                if c.x ~= x or c.y ~= y or c.size ~= size then
                    c.x, c.y, c.size = x, y, size
                    c:ClearAllPoints()
                    c:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, y * k)
                    c:SetSize(size, size)
                end
                if not c:IsShown() then c:Show() end
            elseif c:IsShown() then
                c:Hide()
            end
        end
    end
end

local function MirrorKeys()
    for i, b in ipairs(keyButtons) do
        local native = _G["ActionButton" .. i]
        local on = native ~= nil and native:IsVisible()
        b:SetShown(on)
        if on then
            Mirror(b, native)
            b.hotkey:SetText(HotkeyText(native))
        end
    end
end

---------------------------------------------------------------------------
-- Menu: the diamond's popup, the game's micro menu buttons (character,
-- spellbook...) and the bags as a list. Each row is a secure button of
-- ours clicking the game's own (it opens its window the way its button
-- does). Secure frames can't be shown, hidden or moved in a fight, so the
-- popup is only opened and rebuilt out of combat, placed by the tile's
-- rect (not anchored to it), and a close in a fight waits for its end.
---------------------------------------------------------------------------
local ROW_H, ROW_W, POP_PAD = 24, 200, 6
local popup = CreateFrame("Frame", nil, UIParent)
popup:SetFrameStrata("DIALOG")
popup:SetFrameLevel(20)
popup:EnableMouse(true)
popup:Hide()
local popupBg = popup:CreateTexture(nil, "BACKGROUND")
popupBg:SetAllPoints()
popupBg:SetColorTexture(0.04, 0.04, 0.06, 0.94)
for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 1 } }) do
    local line = popup:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.75, 0.62, 0.3, 0.9)
    line:SetHeight(1)
    line:SetPoint(e[1])
    line:SetPoint(e[2])
end
for _, e in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local line = popup:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.75, 0.62, 0.3, 0.9)
    line:SetWidth(1)
    line:SetPoint(e[1])
    line:SetPoint(e[2])
end

-- (a click anywhere else closes it)
local closer = CreateFrame("Frame", nil, UIParent)
closer:SetAllPoints(UIParent)
closer:SetFrameStrata("DIALOG")
closer:SetFrameLevel(1)
closer:EnableMouse(true)
closer:Hide()

local pendingClose
local function ClosePopup()
    if InCombatLockdown() then
        pendingClose = popup:IsShown() or nil
        return
    end
    pendingClose = nil
    popup:Hide()
    closer:Hide()
end
closer:SetScript("OnMouseDown", ClosePopup)

local menuRows = {}
local function Row(i)
    local r = menuRows[i]
    if r then return r end
    r = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    r:SetParent(popup)
    r:SetSize(ROW_W, ROW_H)
    r:SetPoint("TOPLEFT", popup, "TOPLEFT", POP_PAD, -POP_PAD - (i - 1) * ROW_H)
    r:RegisterForClicks("AnyUp")
    r:SetAttribute("type", "click")
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.82, 0.3, 0.14)
    r.hl:Hide()
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", 8, 0)
    r.bind = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.bind:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnEnter", function(self) self.hl:Show() end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() end)
    r:HookScript("PostClick", ClosePopup)
    menuRows[i] = r
    return r
end

-- (the game's micro buttons in its order, then the bags)
local function MenuItems()
    local items = {}
    local menu = _G.MicroMenu
    if menu then
        local kids = {}
        for _, child in ipairs({ menu:GetChildren() }) do
            if child.layoutIndex and child:IsShown() then kids[#kids + 1] = child end
        end
        table.sort(kids, function(a, b) return a.layoutIndex < b.layoutIndex end)
        for _, child in ipairs(kids) do
            local label = type(child.tooltipText) == "string" and child.tooltipText or child:GetName() or "?"
            items[#items + 1] = { native = child, label = label, command = child.commandName }
        end
    end
    local bags = _G.MainMenuBarBackpackButton or _G.BagsBarBackpackButton
    if bags then
        items[#items + 1] = { native = bags, label = _G.BAGSLOTTEXT or "Bags", command = "OPENALLBAGS" }
    end
    return items
end

local function OpenPopup()
    if InCombatLockdown() then return end
    local items = MenuItems()
    if #items == 0 then return end
    for i, item in ipairs(items) do
        local r = Row(i)
        r:SetAttribute("clickbutton", item.native)
        r.text:SetText(item.label)
        local key = item.command and GetBindingKey(item.command)
        r.bind:SetText(key and GetBindingText(key, "KEY_", true) or "")
        r:Show()
    end
    for i = #items + 1, #menuRows do menuRows[i]:Hide() end
    popup:SetSize(ROW_W + 2 * POP_PAD, #items * ROW_H + 2 * POP_PAD)
    -- (over the tile, kept on the screen)
    local x, y = menuTile:GetCenter()
    local k = menuTile:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not (x and y) then return end
    local half = (ROW_W + 2 * POP_PAD) / 2
    local px = math.min(math.max(x * k, half + 4), UIParent:GetWidth() - half - 4)
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", px, y * k + MENUD.width / 2 * k + 10)
    closer:Show()
    popup:Show()
end

menuTile:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then return end
    if popup:IsShown() then ClosePopup() else OpenPopup() end
end)
local function MenuTileColor(on)
    for _, t in ipairs(menuTile.bars) do
        if on then t:SetColorTexture(1, 0.82, 0.3, 1) else t:SetColorTexture(0.92, 0.86, 0.7, 1) end
    end
end
menuTile:SetScript("OnEnter", function()
    MenuTileColor(true)
    GameTooltip:SetOwner(menuTile, "ANCHOR_LEFT")
    GameTooltip:SetText(MAINMENU_BUTTON or "Game Menu")
    GameTooltip:Show()
end)
menuTile:SetScript("OnLeave", function()
    MenuTileColor(false)
    GameTooltip:Hide()
end)

local menuWatch = CreateFrame("Frame")
menuWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
menuWatch:SetScript("OnEvent", function()
    if pendingClose then ClosePopup() end
end)

-- The pad's parts shown, or hidden (the keyboard bar's up)
local function SetPadParts(on)
    for _, b in ipairs(buttons) do b:SetShown(on) end
    classLeft:SetShown(on)
    classRight:SetShown(on)
    for _, p in ipairs(pips) do p:SetShown(on) end
    page:SetShown(on)
end

---------------------------------------------------------------------------
-- Picking a party member (PartyPad.lua: L1 held, party targeting on): the
-- game's bar isn't what L1 runs then (the party slots' diamond is): dimmed
-- and greyed, eased over SWAP_TIME.
---------------------------------------------------------------------------
local SWAP_TIME, PICK_DIM = 0.15, 0.45
local swap = { now = 0, want = 0 }

local function SetSwap(f)
    local e = f * f * (3 - 2 * f)
    holder:SetAlpha(1 - (1 - PICK_DIM) * e)
end

local swapper = CreateFrame("Frame", nil, holder)
swapper:SetScript("OnUpdate", function(_, elapsed)
    if swap.now == swap.want then return end
    local step = elapsed / SWAP_TIME
    swap.now = swap.want > swap.now and math.min(swap.want, swap.now + step) or math.max(swap.want, swap.now - step)
    SetSwap(swap.now)
end)

local function Picking()
    local PC = IN.PartyCards
    return PC ~= nil and PC.Picking ~= nil and PC.Picking()
end

local function Watch()
    if not IF.db then return end
    GB.SetStyle(IN.Settings().padStyle)
    local pu = PageUnit()
    local main = GamepadMainActionBarFrame
    local wanted = IN.Settings().pad and not UF.EditMode()
    local gamepadUI = pu ~= nil and main:IsVisible()
    local on = wanted and gamepadUI
    -- (the keyboard and mouse bar: the game's main bar, shown instead of
    -- the pad's while the Gamepad UI is off)
    local keyBar = _G.MainActionBar
    local keys = wanted and not gamepadUI and keyBar ~= nil and keyBar:IsVisible()
    if pu then
        for _, part in ipairs(NativeParts(pu)) do IF.Focus.Fade(part, on) end
        for _, bar in ipairs(NativeBars(pu)) do UF.Cover(bar, on) end
    end
    IF.Focus.Fade(keyBar, keys)
    UF.Cover(keyBar, keys)
    -- (its micro menu and bags: the menu tile's popup holds them)
    for _, name in ipairs({ "MicroMenuContainer", "BagsBar" }) do
        local native = _G[name]
        IF.Focus.Fade(native, keys)
        UF.Cover(native, keys)
    end
    menuTile:SetShown(keys and true or false)
    if not keys and popup:IsShown() then ClosePopup() end
    -- (the popup's tile lit while it's open)
    SetBorder(menuTile, popup:IsShown() and SLOT.selected or SLOT.normal)
    if on ~= padShown then
        padShown = on
        SetPadParts(on)
        if on then UpdateGlyphs() end
    end
    keyMode = keys and true or false
    local active = on or keys
    if active ~= shown then
        shown = active
        holder:SetShown(active)
    end
    if keys then MirrorKeys() end
    PlaceCatchers(keys)
    if not on then return end
    local bar = pu.activeBar
    local picking = Picking()
    swap.want = picking and 1 or 0
    for i, b in ipairs(buttons) do
        b.disabled = picking
        Mirror(b, Native(bar, i))
    end
    MirrorClass(classLeft, pu.LeftClassAction)
    MirrorClass(classRight, pu.RightClassAction)
    SetIndex(pu, bar)
end

IN.Watcher("gamepad bar", 0.05, Watch)

-- (the controller's style changed: other glyphs)
local glyphEvents = CreateFrame("Frame")
for _, e in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED" }) do
    pcall(glyphEvents.RegisterEvent, glyphEvents, e)
end
glyphEvents:SetScript("OnEvent", function()
    if padShown then UpdateGlyphs() end
end)

---------------------------------------------------------------------------
-- Supplies: small tiles (0.7 of a D-pad tile) in a row under the R3 slot
-- (the Wheel module's recent slot, ImprovedForever_Wheel/RecentSlot.lua;
-- its spot, GB.SideSpot, without it): your bags' free slots, and a
-- hunter's ammo, a warlock's soul shards. The count on each (red at none,
-- the icon too, the tile pulsing red as a cooldown beats; orange when low); its numbers
-- in a tooltip.
---------------------------------------------------------------------------
local SUPPLY = Shape({ size = DPAD.size * 0.7, glyph = 0 })
local SUPPLY_GAP, SUPPLY_LOW = 4, 3
local SUPPLY_UNDER = 20         -- (under the R3 slot, clear of its glyphs)
local SOUL_SHARD = 6265
local supplies = {}

local function Count(fn, ...)
    local ok, n = pcall(fn, ...)
    if not ok or Secret(n) or type(n) ~= "number" then return nil end
    return n
end

-- (free slots in the bags that take anything (no quivers, soul bags...))
local function BagSpace()
    local C = C_Container
    if not (C and C.GetContainerNumFreeSlots) then return nil end
    local free, total = 0, 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local ok, n, kind = pcall(C.GetContainerNumFreeSlots, bag)
        if ok and type(n) == "number" and (kind == 0 or kind == nil) then
            free = free + n
            total = total + (Count(C.GetContainerNumSlots, bag) or 0)
        end
    end
    return free, total
end

local function Supply(read, tip)
    local center = CreateFrame("Frame", nil, holder)
    center:SetSize(1, 1)
    local b = Button(center, SUPPLY, { 0, 0 }, nil, holder)
    b.read, b.tip = read, tip
    -- (no glyph on it: its count as the level badge, under its foot)
    b.countLift = -COUNT_BADGE / 2
    b.countBg:ClearAllPoints()
    b.countBg:SetPoint("BOTTOM", b, "CENTER", 0, -SUPPLY.width / 2 + b.countLift)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        self.tip()
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- (none left: the tile pulsing red, as a cooldown's beat: a flash on
    -- each whole second, fading over BEAT)
    local alarm = CreateFrame("Frame", nil, b)
    alarm:SetScript("OnUpdate", function()
        local since = GetTime() % 1
        b.flashFill:SetVertexColor(1, 0.15, 0.1, 1)
        b.flashFill:SetAlpha(BEAT_FLASH * math.max(0, 1 - since / BEAT))
    end)
    alarm:Hide()
    b.alarm = alarm
    b:Hide()
    supplies[#supplies + 1] = { tile = b, center = center }
    return b
end

local bagTile = Supply(function()
    local free = BagSpace()
    return free and "Interface\\Icons\\INV_Misc_Bag_08", free
end, function()
    local free, total = BagSpace()
    GameTooltip:SetText(BAGSLOTTEXT or "Bags")
    GameTooltip:AddLine(("%d / %d free"):format(free or 0, total or 0), 1, 1, 1)
end)

local _, playerClass = UnitClass("player")
if playerClass == "HUNTER" then
    local AMMO = INVSLOT_AMMO or 0
    Supply(function()
        local texture = GetInventoryItemTexture("player", AMMO)
        return texture or "Interface\\Icons\\INV_Ammo_Arrow_02", texture and Count(GetInventoryItemCount, "player", AMMO) or 0
    end, function()
        if not pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", AMMO) or not GameTooltip:NumLines()
            or GameTooltip:NumLines() == 0 then
            GameTooltip:SetText(AMMOSLOT or "Ammo")
            GameTooltip:AddLine("None equipped", 1, 0.3, 0.3)
        end
    end)
elseif playerClass == "WARLOCK" then
    local GetCount = C_Item and C_Item.GetItemCount or GetItemCount
    local GetIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
    Supply(function()
        local ok, icon = pcall(GetIcon, SOUL_SHARD)
        return ok and icon or "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", Count(GetCount, SOUL_SHARD) or 0
    end, function()
        pcall(GameTooltip.SetItemByID, GameTooltip, SOUL_SHARD)
    end)
end

-- (centred under the R3 slot, or its spot while it isn't shown)
local supplyRow = CreateFrame("Frame", nil, holder)
supplyRow:SetSize(1, 1)
local function PlaceSupplies()
    local shown = {}
    for _, sp in ipairs(supplies) do
        if sp.tile:IsShown() then shown[#shown + 1] = sp end
    end
    supplyRow:ClearAllPoints()
    if keyMode then
        -- (the keyboard bar's: left of its groups, bottoms level)
        local e = KeyExtent()
        local pitch = SUPPLY.width + SUPPLY_GAP
        supplyRow:SetPoint("TOP", keyCenters[1], "CENTER", -(e + 2 * KEY_GAP + MENUD.width + #shown * pitch / 2), SUPPLY.width - e)
    else
        local slot = rawget(_G, "ImprovedForeverRecentSlot")
        if type(slot) == "table" and slot.IsShown and slot:IsShown() then
            supplyRow:SetPoint("TOP", slot, "BOTTOM", 0, -SUPPLY_UNDER)
        else
            local anchor, x, y, d = GB.SideSpot()
            if not anchor then return end
            supplyRow:SetPoint("TOP", anchor, "CENTER", x, y - d.width / 2 - SUPPLY_UNDER)
        end
    end
    for k, sp in ipairs(shown) do
        sp.center:ClearAllPoints()
        sp.center:SetPoint("CENTER", supplyRow, "TOP", (k - (#shown + 1) / 2) * (SUPPLY.width + SUPPLY_GAP),
            -SUPPLY.width / 2)
    end
end

local function UpdateSupplies()
    for _, sp in ipairs(supplies) do
        local b = sp.tile
        local texture, n = b.read()
        local on = texture ~= nil
        b:SetShown(on)
        if on then
            local text = tostring(n or 0)
            local stand = GB.StandIn(texture)
            stand.Count = { IsShown = function() return true end, GetText = function() return text end }
            -- (none left: the icon red)
            if (n or 0) <= 0 then
                stand.icon.r, stand.icon.g, stand.icon.b = 1, 0.2, 0.2
                function stand.icon.IsDesaturated() return true end
            end
            pcall(Mirror, b, stand)
            local alarm, empty = b.alarm, (n or 0) <= 0
            alarm:SetShown(empty)
            if not empty then b.flashFill:SetAlpha(0) end
            local c = (n or 0) <= 0 and { 1, 0.25, 0.25 } or (n or 0) <= SUPPLY_LOW and { 1, 0.6, 0.15 } or { 1, 1, 1 }
            b.count:SetTextColor(c[1], c[2], c[3])
        end
    end
    PlaceSupplies()
end
GB.UpdateSupplies, GB.PlaceSupplies = UpdateSupplies, PlaceSupplies
-- (the bags' tile and the supplies' sizes: the recent loot beside it,
-- RecentLoot.lua)
GB.BagTile, GB.SUPPLY, GB.SUPPLY_GAP = bagTile, SUPPLY, SUPPLY_GAP

local supplyEvents = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED" }) do
    supplyEvents:RegisterEvent(e)
end
supplyEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    UpdateSupplies()
end)
-- (placed again now and then: the R3 slot comes, goes and moves (Edit Mode))
local sincePlaced = 0
supplyRow:SetScript("OnUpdate", function(_, elapsed)
    sincePlaced = sincePlaced + elapsed
    if sincePlaced < 0.5 then return end
    sincePlaced = 0
    PlaceSupplies()
end)

---------------------------------------------------------------------------
-- For other diamonds of ours (the party spells', PartyPad.lua): a tile as
-- these, and the same effects (cooldown ring and beat, cast and channel
-- ring, food and drink, its end's flash) from a stand-in for the game's
-- button: GB.StandIn
---------------------------------------------------------------------------
-- A tile's sizes from its size and its glyph's
function GB.Dims(size, glyph)
    return Shape({ size = size, glyph = glyph })
end

-- A press's direction to its tile's place (x, y, times a Dims' spread)
GB.Place = Place

-- A tile (parent: its frame; the mouse's scripts the caller's)
function GB.Tile(parent, center, d, dir)
    return Button(center, d, dir, nil, parent)
end

-- A stand-in for the game's button: a spell's (by ID, its name for the
-- cast ring), an item's (its cooldown, its buff), its icon, its colour
-- (r, g, b: unusable, out of power)
function GB.StandIn(texture, spellID, itemID, spellName)
    local icon = { texture = texture, r = 1, g = 1, b = 1 }
    function icon.IsShown() return true end
    function icon.GetTexture(self) return self.texture end
    function icon.GetVertexColor(self) return self.r, self.g, self.b end
    function icon.IsDesaturated() return false end
    local standIn = { icon = icon, spellID = spellID, itemID = itemID, spellName = spellName }
    function standIn.IsShown() return texture ~= nil end
    return standIn
end

GB.Mirror, GB.SetBorder, GB.SLOT = Mirror, SetBorder, SLOT

-- Where these are on screen, in screen pixels (left, bottom, right, top:
-- every tile and its glyphs), or nil while hidden: another addon's frame
-- kept clear of them (the Quest Tracker module's tracker)
function GB.Rect()
    if not holder:IsShown() then return nil end
    local l, b, r, t
    local function Add(region)
        if not (region and region:IsShown()) then return end
        local rl, rb, rw, rh = region:GetRect()
        if not (rl and rb and rw and rh) then return end
        local k = region:GetEffectiveScale()
        rl, rb, rw, rh = rl * k, rb * k, rw * k, rh * k
        l, b = math.min(l or rl, rl), math.min(b or rb, rb)
        r, t = math.max(r or rl + rw, rl + rw), math.max(t or rb + rh, rb + rh)
    end
    if keyMode then
        for _, button in ipairs(keyButtons) do Add(button) end
        Add(menuTile)
    else
        for _, button in ipairs(buttons) do
            Add(button)
            Add(button.key)
        end
        for _, button in ipairs({ classLeft, classRight }) do
            Add(button)
            Add(button.key)
            Add(button.key2)
        end
    end
    if not l then return nil end
    return l, b, r, t
end

-- Another addon's tile beside these (the Wheel module's recent slot,
-- ImprovedForever_Wheel/RecentSlot.lua): left of the D-pad's group, the
-- D-pad's tile size; level with its middle, or (a grid) beside its bottom
-- row. While these show: the
-- frame to anchor its middle to, x, y from it, the tile's sizes (GB.Dims);
-- else nil.
local SIDE_GAP = 14
local sideDims = GB.Dims(DPAD.size, DPAD.glyph)
function GB.SideSpot()
    -- (none with the keyboard bar: that slot is the pad's)
    if not holder:IsShown() or keyMode then return nil end
    -- (a grid: beside its bottom row, clear of that row's outer glyph)
    if style.grid then
        return dpadCenter, -(DPAD.spread + DPAD.side / 2 + GlyphOut(DPAD) + sideDims.width / 2), -DPAD.spread, sideDims
    end
    return dpadCenter, -(Extent(DPAD) + SIDE_GAP + sideDims.width / 2), 0, sideDims
end

---------------------------------------------------------------------------
-- The style: every size, tile and place again; others told (GB.OnStyle)
---------------------------------------------------------------------------
local styleListeners = {}
function GB.OnStyle(fn)
    styleListeners[#styleListeners + 1] = fn
end

function GB.Style()
    return styleName
end

function GB.SetStyle(name)
    if not STYLES[name] or name == styleName then return end
    style, styleName = STYLES[name], name
    SetSlot()
    for d in pairs(dims) do Shape(d) end
    PlaceGroups()
    for b in pairs(tiles) do Reshape(b) end
    PlaceClass(classLeft)
    PlaceClass(classRight)
    PlacePips()
    PlaceKeys()
    PlaceSupplies()
    for _, fn in ipairs(styleListeners) do pcall(fn, name) end
end

function GB.Apply()
    shown = nil
    Watch()
end
