-- The gamepad action bar laid out as Hogwarts Legacy's spells: bottom
-- right, the face buttons' four as a big diamond, the D-pad's four as a
-- smaller one left of it, one set at a time. Holding L2 / R2 (or both)
-- swaps the icons in place to that set, four pips under the face diamond
-- saying which set is up.
-- Ours only shows: the game's bar (Blizzard_GamepadActionBars) does every
-- press and keeps every slot, so the Bindings tab and the game's own
-- editor stay as they are. Its crosses are drawn at 0 (IF.Focus.Fade, an
-- animation of ours: a property of the game's frames set from addon code
-- taints them), a frame of ours over each taking the mouse they'd still
-- get, and ours mirrors the buttons of whichever bar it has active (its
-- top / L2 / R2 / both bar, or one standing in: a vehicle's, a stance
-- bar...): their icon, its tint (unusable, out of range), count,
-- cooldown, pressed and toggled state, spell alert. Its two class action
-- buttons (L1 + L2, R1 + R2) too, beside the diamonds, their two-glyph
-- prompt over them.
-- A cooldown can be a secret (Forever restricts them at times): the
-- sweep then isn't shown.
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

local FACE = { size = 56, spread = 60, glyph = 22 }
local DPAD = { size = 44, spread = 46, glyph = 18 }
local MARGIN_X, MARGIN_Y = 40, 40
local GAP = 34          -- (between the two diamonds)

local holder = CreateFrame("Frame", "ImprovedForeverGamepadBar", UIParent)
holder:SetFrameStrata("LOW")
holder:SetSize(1, 1)
holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MARGIN_X, MARGIN_Y)
holder:Hide()

local function Extent(d)
    return d.spread + d.size / 2 + d.glyph
end

local faceCenter = CreateFrame("Frame", nil, holder)
faceCenter:SetSize(1, 1)
faceCenter:SetPoint("CENTER", holder, "BOTTOMRIGHT", -Extent(FACE), Extent(FACE))
local dpadCenter = CreateFrame("Frame", nil, holder)
dpadCenter:SetSize(1, 1)
dpadCenter:SetPoint("CENTER", faceCenter, "CENTER", -(Extent(FACE) + GAP + Extent(DPAD)), -(FACE.spread - DPAD.spread))

---------------------------------------------------------------------------
-- A button of ours: the game's circle slot (its background, the icon in a
-- circle, its border; pressed / toggled borders), a cooldown, a count, the
-- press's glyph
---------------------------------------------------------------------------
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function Button(center, d, dir, key)
    local b = CreateFrame("Frame", nil, holder)
    b:SetSize(d.size, d.size)
    b:SetPoint("CENTER", center, "CENTER", dir[1] * d.spread, dir[2] * d.spread)
    b:EnableMouse(true)

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAtlas("gamepad-actionbar-circleslot-bg")
    b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(d.size * 0.86, d.size * 0.86)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetSwipeTexture(CIRCLE)
    b.cooldown:SetUseCircularEdge(true)
    b.cooldown:SetDrawEdge(false)

    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.cooldown:GetFrameLevel() + 2)
    b.border = over:CreateTexture(nil, "OVERLAY")
    b.border:SetAtlas("gamepad-actionbar-circleslot-border-normal")
    b.border:SetPoint("CENTER")
    b.border:SetSize(d.size * 64 / 46, d.size * 64 / 46)
    b.glow = over:CreateTexture(nil, "OVERLAY", nil, 1)
    b.glow:SetAtlas("gamepad-actionbar-circleslot-border-selected")
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(d.size * 80 / 46, d.size * 80 / 46)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    b.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 2, -2)

    b.key = over:CreateTexture(nil, "OVERLAY", nil, 2)
    b.key:SetSize(d.glyph, d.glyph)
    b.key:SetPoint("CENTER", b, "CENTER", dir[1] * (d.size / 2 + d.glyph * 0.35),
        dir[2] * (d.size / 2 + d.glyph * 0.35))
    b.keyName = key

    b:SetScript("OnEnter", function(self)
        local native = self.native
        local action = native and native.action
        if not action then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if pcall(GameTooltip.SetAction, GameTooltip, action) then GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local buttons = {}
for i, dir in ipairs(DIRS) do
    buttons[i] = Button(dpadCenter, DPAD, dir, DPAD_KEYS[i])
    buttons[4 + i] = Button(faceCenter, FACE, dir, FACE_KEYS[i])
end

-- The class actions: L1 + L2 at the D-pad diamond's upper left, R1 + R2 at
-- the face diamond's upper right; their prompt (both glyphs) over them,
-- not one beside
local CLASS = { size = DPAD.size, spread = DPAD.spread, glyph = 16 }
local function ClassButton(center, d, x, keys)
    local b = Button(center, CLASS, { x, 1 }, nil)
    b:ClearAllPoints()
    b:SetPoint("CENTER", center, "CENTER", x * d.spread, d.spread)
    b.key:ClearAllPoints()
    b.key:SetPoint("BOTTOMRIGHT", b, "TOP", -1, 2)
    b.key2 = b.key:GetParent():CreateTexture(nil, "OVERLAY", nil, 2)
    b.key2:SetSize(CLASS.glyph, CLASS.glyph)
    b.key2:SetPoint("BOTTOMLEFT", b, "TOP", 1, 2)
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
-- The set pips under the face diamond: no trigger, L2, R2, both; the one
-- up lit. A bar standing in for them (a vehicle's...): none lit.
---------------------------------------------------------------------------
local pips = {}
local PIP, PIP_GAP = 8, 6
for i = 1, 4 do
    local p = holder:CreateTexture(nil, "ARTWORK")
    p:SetSize(PIP, PIP)
    p:SetTexture(CIRCLE)
    p:SetPoint("TOP", faceCenter, "CENTER", (i - 2.5) * (PIP + PIP_GAP),
        -(FACE.spread + FACE.size / 2 + FACE.glyph + 4))
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

local function Cooldown(b, native)
    local cd = native.cooldown
    local ok, start, duration = false, nil, nil
    if cd and cd.GetCooldownTimes and cd:IsShown() then
        ok, start, duration = pcall(cd.GetCooldownTimes, cd)
    end
    if not ok or Secret(start) or Secret(duration) or type(duration) ~= "number" or duration <= 0 then
        if b.cdStart then
            b.cooldown:Clear()
            b.cdStart = nil
        end
        return
    end
    if b.cdStart ~= start or b.cdDuration ~= duration then
        b.cdStart, b.cdDuration = start, duration
        b.cooldown:SetCooldown(start / 1000, duration / 1000)
    end
end

local function Mirror(b, native)
    b.native = native
    local icon = native and native:IsShown() and native.icon
    local texture = icon and icon:IsShown() and icon:GetTexture()
    if not texture then
        b.icon:SetTexture(nil)
        b.count:SetText("")
        b.glow:Hide()
        b.border:SetAtlas("gamepad-actionbar-circleslot-border-normal")
        if b.cdStart then
            b.cooldown:Clear()
            b.cdStart = nil
        end
        return
    end
    b.icon:SetTexture(texture)
    b.icon:SetVertexColor(icon:GetVertexColor())
    b.icon:SetDesaturated(icon:IsDesaturated())
    local count = native.Count
    pcall(b.count.SetText, b.count, count and count:IsShown() and count:GetText() or "")
    Cooldown(b, native)
    local pressed = native.GetButtonState and native:GetButtonState() == "PUSHED"
    local checked = native.GetChecked and native:GetChecked()
    b.border:SetAtlas(pressed and "gamepad-actionbar-circleslot-border-pressed"
        or "gamepad-actionbar-circleslot-border-normal")
    local alert = native.SpellActivationAlert
    b.glow:SetShown((checked and true or false) or (alert and alert:IsShown() and true or false))
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
