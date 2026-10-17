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

-- (diamond tiles, as Hogwarts Legacy's: the game's square slot turned a
-- quarter of a right angle. A tile's visible side: VISIBLE times its size
-- (the art's soft margin left out); its width point to point: that times
-- the root of 2. The four sit edge to edge, TILE_GAP apart, as one big
-- diamond: each tile's middle `spread` out from the group's.)
local ROOT2 = math.sqrt(2)
local VISIBLE, TILE_GAP = 1.2, 3
local FACE = { size = 44, glyph = 22 }
local DPAD = { size = 36, glyph = 18 }
local CLASS = { size = 36, glyph = 16 }
for _, d in ipairs({ FACE, DPAD, CLASS }) do
    d.side = d.size * VISIBLE
    d.width = d.side * ROOT2
    d.spread = (d.side + TILE_GAP) / ROOT2
end

-- Where a class action's tile sits by a group: against the upper outer
-- edge of its top tile (in the tiles' own turned frame: one tile further
-- along), as (x, y) from the group's middle, x away from the screen's
-- middle line of the group
local function ClassSpot(d)
    local a = d.spread / ROOT2
    local rx, ry = a + d.side / 2 + TILE_GAP + CLASS.side / 2, a
    return (rx - ry) / ROOT2, (rx + ry) / ROOT2
end
local MARGIN_X, MARGIN_Y = 40, 40
local GAP = 34          -- (between the two groups)

local holder = CreateFrame("Frame", "ImprovedForeverGamepadBar", UIParent)
holder:SetFrameStrata("LOW")
holder:SetSize(1, 1)
holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MARGIN_X, MARGIN_Y)
holder:Hide()

local function Extent(d)
    return d.spread + d.width / 2 + d.glyph / 2
end

local faceCenter = CreateFrame("Frame", nil, holder)
faceCenter:SetSize(1, 1)
faceCenter:SetPoint("CENTER", holder, "BOTTOMRIGHT", -Extent(FACE), Extent(FACE))
local dpadCenter = CreateFrame("Frame", nil, holder)
dpadCenter:SetSize(1, 1)
-- (the D-pad's raised so its class action sits on one row with the face
-- buttons')
local _, FACE_CLASS_Y = ClassSpot(FACE)
local _, DPAD_CLASS_Y = ClassSpot(DPAD)
dpadCenter:SetPoint("CENTER", faceCenter, "CENTER", -(Extent(FACE) + GAP + Extent(DPAD)), FACE_CLASS_Y - DPAD_CLASS_Y)

---------------------------------------------------------------------------
-- A button of ours: the game's square slot (its background, the icon in
-- its rounded mask, its border; pressed / toggled borders), a cooldown, a
-- count, the press's glyph
---------------------------------------------------------------------------
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- (the set pips)
-- The game's square slot (its D-pad buttons' look), turned into a
-- diamond: background, border, pressed and selected borders; the icon
-- upright, cut to a diamond (the game's diamond mask)
local SLOT = {
    bg = "gamepad-actionbar-squareslot-bg",
    normal = "gamepad-actionbar-squareslot-border-normal",
    pressed = "gamepad-actionbar-squareslot-border-pressed",
    selected = "gamepad-actionbar-squareslot-border-selected",
    mask = "progress-bar-diamond-pip-mask",
}
local TURN = math.pi / 4
-- (toggled on, a proc: the diamond lit, at these colours and strengths)
local CHECKED_FILL, CHECKED_ALPHA = { 1, 0.75, 0.25 }, 0.35
local PROC_FILL, PROC_ALPHA = { 1, 0.95, 0.6 }, 0.3
-- (a cooldown's beat, its end: the diamond flashing white, at most these)
local FLASH_FILL, BEAT_FLASH, READY_FLASH = { 1, 1, 1 }, 0.22, 0.45
-- (a cooldown this short is the global one: not shown)
local GCD_MAX = 1.6
-- (the cast ring: on the border, RING_AT of the tile's half width out; its
-- line and glow's thickness)
local RING_AT, RING_LINE, RING_GLOW = 0.96, 2.5, 4
-- (an icon's share of its tile: a turned one's side, the diamond mask's
-- width; an upright one fits inside at half the diamond's width)
local ICON_FILL, UPRIGHT_FILL = 0.94, 0.5

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

local function Button(center, d, dir, key)
    local b = CreateFrame("Frame", nil, holder)
    b:SetSize(d.size, d.size)
    b:SetPoint("CENTER", center, "CENTER", dir[1] * d.spread, dir[2] * d.spread)
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
    -- (a cast from this slot: a line running round the tile's border, its
    -- four edges clockwise from the top point, each with a wider, fainter
    -- one under it as its glow; CastFill)
    b.ring = CreateFrame("Frame", nil, over)
    b.ring:SetAllPoints()
    b.ring:SetFrameLevel(over:GetFrameLevel() + 1)
    b.ring.r = d.width / 2 * RING_AT
    b.ring.glows, b.ring.lines = {}, {}
    for i = 1, 4 do
        local glow = b.ring:CreateLine(nil, "OVERLAY", nil, 1)
        glow:SetThickness(RING_GLOW)
        glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        glow:SetBlendMode("ADD")
        local line = b.ring:CreateLine(nil, "OVERLAY", nil, 2)
        line:SetThickness(RING_LINE)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetBlendMode("ADD")
        b.ring.glows[i], b.ring.lines[i] = glow, line
    end
    b.ring:Hide()
    b.timer = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    b.timer:SetPoint("CENTER")
    b.timer:SetShadowOffset(1, -1)
    b.timer:Hide()
    b.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOM", b, "CENTER", 0, -d.width / 2 + 6)

    b.key = over:CreateTexture(nil, "OVERLAY", nil, 2)
    b.key:SetSize(d.glyph, d.glyph)
    b.key:SetPoint("CENTER", b, "CENTER", dir[1] * (d.width / 2 + d.glyph * 0.2),
        dir[2] * (d.width / 2 + d.glyph * 0.2))
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

local buttons = {}
for i, dir in ipairs(DIRS) do
    buttons[i] = Button(dpadCenter, DPAD, dir, DPAD_KEYS[i])
    buttons[4 + i] = Button(faceCenter, FACE, dir, FACE_KEYS[i])
end

-- The class actions, a tile each against their group's top tile: R1 + R2
-- at the face buttons' upper right, L1 + L2 at the D-pad's upper left (the
-- D-pad raised to put them on one row); their prompt (both glyphs) over
-- them
local function ClassButton(center, d, sign, keys)
    local b = Button(center, CLASS, { sign, 1 }, nil)
    local x, y = ClassSpot(d)
    b:ClearAllPoints()
    b:SetPoint("CENTER", center, "CENTER", sign * x, y)
    b.key:ClearAllPoints()
    b.key:SetPoint("BOTTOMRIGHT", b, "CENTER", -1, CLASS.width / 2 + 2)
    b.key2 = b.key:GetParent():CreateTexture(nil, "OVERLAY", nil, 2)
    b.key2:SetSize(CLASS.glyph, CLASS.glyph)
    b.key2:SetPoint("BOTTOMLEFT", b, "CENTER", 1, CLASS.width / 2 + 2)
    b.keyName, b.keyName2 = keys[1], keys[2]
    return b
end
local classLeft = ClassButton(dpadCenter, DPAD, -1, { "PADLSHOULDER", "PADLTRIGGER" })
local classRight = ClassButton(faceCenter, FACE, 1, { "PADRSHOULDER", "PADRTRIGGER" })

local function Glyph(tex, key)
    local atlas = key and IF.GlyphAtlas(key)
    if atlas then tex:SetAtlas(atlas) else tex:SetTexture(nil) end
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
-- (centred on the whole: midway between the two diamonds' middles)
local PIPS_X = -(Extent(FACE) + GAP + Extent(DPAD)) / 2
for i = 1, 4 do
    local p = holder:CreateTexture(nil, "ARTWORK")
    p:SetSize(PIP, PIP)
    p:SetTexture(CIRCLE)
    p:SetPoint("TOP", faceCenter, "CENTER", PIPS_X + (i - 2.5) * (PIP + PIP_GAP),
        -(FACE.spread + FACE.width / 2 + FACE.glyph / 2 + 4))
    pips[i] = p
end
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
local COOLDOWN_COLOR = { 0.9, 0.9, 0.9 }
-- A cooldown's time left, short and rounded up: 2h, 2m, 45
local function Short(left)
    if left >= 3600 then return math.ceil(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
end

-- (a cooldown's beat: each whole second left, a flash fading over BEAT
-- seconds; its end, the whole ring flashing over READY seconds)
local BEAT, READY = 0.35, 0.6

local CHANNEL_COLOR = { 0.4, 1, 0.5 }
-- (the corners, clockwise from the top: unit steps of the ring's radius)
local CORNERS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 }, { 0, 1 } }

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
    for i = 1, 4 do
        local part = math.min(math.max(f * 4 - (i - 1), 0), 1)
        local line, glow = ring.lines[i], ring.glows[i]
        if part <= 0 then
            line:Hide()
            glow:Hide()
        else
            local a, z = CORNERS[i], CORNERS[i + 1]
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
    local action = native and native.action
    if not action then return nil end
    local special = native.SpecialActionIcon
    if special and special:IsShown() then return nil end
    local ok, name = pcall(function()
        local kind, id = GetActionInfo(action)
        if kind == "macro" then id = GetMacroSpell(id) elseif kind ~= "spell" then return nil end
        if not id then return nil end
        return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo(id)
    end)
    return ok and name or nil
end

-- Casting from this slot: its button's cast animation, or (when the game
-- doesn't play it there: some channels come with another rank's id) your
-- cast or channel by the slot's spell's name
local function SlotCasting(native)
    if Casting(native) then return true end
    local slotName = SlotSpellName(native)
    if not slotName then return false end
    local ok, same = pcall(function()
        local name = UnitChannelInfo("player") or UnitCastingInfo("player")
        return name ~= nil and name == slotName
    end)
    return ok and same or false
end

local function CastFill(b, native)
    b.casting = false
    if not SlotCasting(native) then
        if b.ring:IsShown() then b.ring:Hide() end
        return
    end
    local channel = false
    local _, _, _, startMs, endMs = UnitCastingInfo("player")
    if not (Secret(startMs) or startMs) then
        _, _, _, startMs, endMs = UnitChannelInfo("player")
        channel = true
    end
    if Secret(startMs) or Secret(endMs) or type(startMs) ~= "number" or type(endMs) ~= "number"
        or endMs <= startMs then
        b.ring:Hide()
        return
    end
    local f = (GetTime() * 1000 - startMs) / (endMs - startMs)
    f = math.min(math.max(f, 0), 1)
    DrawRing(b.ring, channel and (1 - f) or f, channel and CHANNEL_COLOR or CAST_COLOR)
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
    if not action or (special and special:IsShown()) then return nil end
    local ok, left, whole, drink = pcall(function()
        local kind, id = GetActionInfo(action)
        if kind ~= "item" or not id then return nil end
        local spell = ItemSpell(id)
        if not spell then return nil end
        local aura = spell.spellID and C_UnitAuras.GetPlayerAuraBySpellID(spell.spellID)
        if not aura and C_UnitAuras.GetAuraDataBySpellName then
            aura = C_UnitAuras.GetAuraDataBySpellName("player", spell.name, "HELPFUL")
        end
        if not aura or not aura.duration or aura.duration <= 0 then return nil end
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
        if Has(atlas) then return true, nil, atlas end
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

local function Mirror(b, native)
    b.native = native
    local has, texture, atlas, coords, icon = Picture(native)
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
    if Has(atlas) then
        b.icon:SetAtlas(atlas)
        b.icon:SetSize(d.width * UPRIGHT_FILL, d.width * UPRIGHT_FILL)
        b.icon:SetRotation(0)
    else
        b.icon:SetTexture(texture)
        b.icon:SetTexCoord(unpack(coords or FULL))
        if coords then
            -- (the game's own picture, a cursor or a raid marker: upright)
            b.icon:SetSize(d.width * UPRIGHT_FILL, d.width * UPRIGHT_FILL)
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
        b.icon:SetDesaturated(icon:IsDesaturated())
    else
        b.icon:SetVertexColor(1, 1, 1)
        b.icon:SetDesaturated(false)
    end
    Cooldown(b, native)
    local now = GetTime()
    local cooling = type(b.cdUntil) == "number" and type(now) == "number" and now < b.cdUntil
    if cooling then b.icon:SetVertexColor(0.4, 0.4, 0.4) end

    -- The ring: a cast from the slot, else a buff from its item (food,
    -- drink: shrinking with its time left, its timer on it), else its
    -- cooldown (white, unwinding: the share still to wait)
    CastFill(b, native)
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
            -- (a beat on each whole second left)
            local left = b.cdUntil - now
            local since = 1 - (left - math.floor(left))
            local beat = math.max(0, 1 - since / BEAT)
            b.timer:SetText(Short(left))
            b.timer:Show()
            DrawRing(b.ring, left / b.cdDuration, COOLDOWN_COLOR, beat)
            b.ring:Show()
            b.flashFill:SetAlpha(BEAT_FLASH * beat)
        elseif done and done < READY then
            b.timer:Hide()
            -- (ready: the whole ring and the tile flashing out)
            local fade = 1 - done / READY
            DrawRing(b.ring, 1, COOLDOWN_COLOR, fade)
            b.ring:SetAlpha(fade)
            b.ring:Show()
            b.flashFill:SetAlpha(READY_FLASH * fade)
        else
            if b.ring:IsShown() then b.ring:Hide() end
            b.flashFill:SetAlpha(0)
            b.timer:Hide()
        end
        if not (done and done < READY) then b.ring:SetAlpha(1) end
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

local shown

local function Watch()
    if not IF.db then return end
    local pu = PageUnit()
    local main = GamepadMainActionBarFrame
    local on = pu ~= nil and IN.Settings().pad and main:IsVisible() and not UF.EditMode()
    if pu then
        for _, part in ipairs(NativeParts(pu)) do IF.Focus.Fade(part, on) end
        for _, bar in ipairs(NativeBars(pu)) do UF.Cover(bar, on) end
    end
    if on ~= shown then
        shown = on
        holder:SetShown(on)
        if on then UpdateGlyphs() end
    end
    if not on then return end
    local bar = pu.activeBar
    for i, b in ipairs(buttons) do
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
    if shown then UpdateGlyphs() end
end)

function GB.Apply()
    shown = nil
    Watch()
end
