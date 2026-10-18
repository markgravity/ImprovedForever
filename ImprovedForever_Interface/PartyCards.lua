-- Minions and party as cards standing on the experience line along the
-- screen's bottom edge (XPBar.lua): your pet beside the player frame,
-- bottom left ("Minions"), your party's four centred ("Party"), each a card in
-- the look of the rest of the bottom: the avatar the player's has too
-- (UnitFrames.lua: the unit's model in the game's tooltip border, a strip
-- along its top in its class colour (a minion's gold, grey when dead or
-- offline), its level at the top left); along its foot, on a dark band,
-- its name over its health and power in our bars (the casting bar's
-- frame, as the player's).
-- Under each, its role as a flat dot on the experience line, its icon in
-- it (a minion's gold, its paw; a party member's tank blue / healer green
-- / damage red), a thin line up to it; a minion's card smaller. Faint when out of range.
-- /if cards previews every slot (Preview).
-- Each card is a secure unit button (a click targets, a right click opens
-- the unit's menu) in a place of its own, shown by the game's state
-- driver (the pet's unit watch; a party member's: there and not in a
-- raid), so nothing moves in a fight. The game's party frames (and its
-- pet frame) are drawn at 0 (IF.Focus.Fade), a frame of ours over them
-- taking the mouse.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PC = {}
IN.PartyCards = PC

local CARD_W, CARD_H, GAP = 76, 100, 8
local MINION_GAP = 16            -- (the minions after the player frame, bottom left)
local PAD_GAP = 12               -- (the party spells' diamond after the last card, PartyPad.lua)
local HEALTH_H, POWER_H, BAR_GAP, INSET = 14, 11, 0, 4
local NAME_H = 14
-- (the cards' bottom: the HUD's shared bottom line, Module.lua; their role
-- dots under them, over the experience line)
local BOTTOM = IN.BOTTOM
local PAD_GLYPH = 20             -- (a party card's face button, PartyPad.lua)
-- (L1 held, picking: each party card grown by PICK_GROW, its face button
-- PICK_GLYPH big in the middle of its picture, eased over PICK_TIME)
local PICK_GROW, PICK_GLYPH, PICK_TIME = 1.15, 44, 0.15
-- (the member to see to, a tank's or a healer's (Highlight): while
-- picking, its card in the game's spell alert (a proc's glow), behind it
-- and ALERT_OUT past each edge, so only its outer part shows; its burst
-- as big to it as the game's to its alert (150 to a 45 button's 63))
local ALERT_OUT, BURST_SIZE = 18, 150 / 63
local DOT, DOT_ICON = 18, 12     -- (a flat dot as the gamepad bar's set pips, its role's icon in it)
local DOT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MINION_SCALE = 0.8         -- (a minion's card, a party member's times)
-- (the alert's colours, as a monster's level against yours (Module.lua):
-- green, yellow, orange steady, red flashing at its worst)
local LEVEL = IN.LEVEL_COLORS
local ALERT_COLORS = { LEVEL[1], LEVEL[2], LEVEL[3] }
local URGENT_COLOR = LEVEL[4]
local FLASH, FLASH_LOW = 0.5, 0.25    -- (the alert's flash: seconds each way, its dimmest)
-- (its pulse, as a gamepad diamond's cooldown beat in the alert's colour:
-- each second, a flash fading over PULSE seconds, at PULSE_PEAK)
local PULSE, PULSE_PEAK = 0.35, 0.45
local LINE_H = IN.XP_H  -- (the experience line's height, XPBar.lua: the dots sit on it)
local STEM_W, STEM_ALPHA = 2, 0.55
local HEALTH_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local POWER_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-"

local Try, Flag, Text, Bar = UF.Try, UF.Flag, UF.Text, UF.Bar

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

---------------------------------------------------------------------------
-- A card: the avatar (UnitFrames.lua, as the player's), along its foot on
-- a dark band its name over its health and power
---------------------------------------------------------------------------
local function Card(name, unit, scale)
    local w, h = math.floor(CARD_W * scale + 0.5), math.floor(CARD_H * scale + 0.5)
    local b = UF.UnitButton(name, unit, w, h)
    b.cardW = w
    b:Hide()
    b.avatar = UF.Avatar(b, w, h)
    b.avatar:SetPoint("BOTTOM")
    b.portrait = b.avatar.portrait

    local over = b.avatar.over
    local shade = over:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("BOTTOMLEFT", INSET, INSET)
    shade:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    shade:SetHeight(POWER_H + HEALTH_H + NAME_H + 4)
    shade:SetColorTexture(0, 0, 0, 0.65)

    b.power = Bar(over, w - 2 * INSET + 2, POWER_H, POWER_FILL .. "Mana")
    b.power.box:SetPoint("BOTTOM", 0, INSET - 1)
    b.health = Bar(over, w - 2 * INSET + 2, HEALTH_H, HEALTH_FILL)
    b.health.box:SetPoint("BOTTOM", b.power.box, "TOP", 0, BAR_GAP)
    local small = _G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small
    if small then
        b.health.text:SetFontObject(small)
        b.power.text:SetFontObject(small)
    end
    b.name = Text(over, "GameFontNormalSmall")
    b.name:SetPoint("BOTTOMLEFT", b.health.box, "TOPLEFT", 2, 1)
    b.name:SetPoint("BOTTOMRIGHT", b.health.box, "TOPRIGHT", -2, 1)
    b.name:SetHeight(NAME_H)

    -- (an alert over it, Focus: the card's border again, under its level
    -- badge, one of each colour: steady green, yellow, orange (b.bands),
    -- or at its worst red flashing, its picture pulsing (b.urgent,
    -- b.pulse). Which shows is the frames' alpha, which takes a secret;
    -- the flash and pulse animations of their own, always running)
    local level = b.avatar.badge:GetFrameLevel() - 1
    local function Edge(c)
        local f = CreateFrame("Frame", nil, b.avatar)
        f:SetAllPoints()
        f:SetFrameLevel(level)
        f:SetAlpha(0)
        UF.Border(f)
        for _, t in ipairs(f.borderPieces) do t:SetVertexColor(c[1], c[2], c[3], 1) end
        return f
    end
    b.bands = {}
    for i, c in ipairs(ALERT_COLORS) do b.bands[i] = Edge(c) end
    local flash = Edge(URGENT_COLOR)
    b.urgent = flash
    local anim = flash:CreateAnimationGroup()
    anim:SetLooping("BOUNCE")
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(FLASH_LOW)
    fade:SetDuration(FLASH)
    fade:SetSmoothing("IN_OUT")
    anim:Play()
    -- (the pulse: on the card's picture, under its band and bars, so it
    -- doesn't wash them out; shown with the red flash, AlertBand)
    b.pulse = CreateFrame("Frame", nil, b.avatar)
    b.pulse:SetAllPoints()
    b.pulse:SetFrameLevel(b.avatar.over:GetFrameLevel() - 1)
    b.pulse:SetAlpha(0)
    b.pulseFill = b.pulse:CreateTexture(nil, "ARTWORK")
    b.pulseFill:SetPoint("TOPLEFT", INSET, -INSET)
    b.pulseFill:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    b.pulseFill:SetColorTexture(URGENT_COLOR[1], URGENT_COLOR[2], URGENT_COLOR[3], 1)
    b.pulseFill:SetBlendMode("ADD")
    b.pulseFill:SetAlpha(0)
    local beat = b.pulseFill:CreateAnimationGroup()
    beat:SetLooping("REPEAT")
    local rise = beat:CreateAnimation("Alpha")
    rise:SetFromAlpha(PULSE_PEAK)
    rise:SetToAlpha(0)
    rise:SetDuration(PULSE)
    rise:SetEndDelay(2 * FLASH - PULSE)
    beat:Play()

    -- (its role under it: a flat dot in the role's colour, as the gamepad
    -- bar's set pips, on the experience line, a thin line of that colour up
    -- to the card)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetTexture(DOT_MASK)
    b.dot:SetSize(DOT, DOT)
    b.dot:SetPoint("BOTTOM", b, "BOTTOM", 0, LINE_H - BOTTOM)
    b.stem = b:CreateTexture(nil, "BACKGROUND")
    b.stem:SetColorTexture(1, 1, 1, 1)
    b.stem:SetWidth(STEM_W)
    b.stem:SetPoint("TOP", b, "BOTTOM")
    b.stem:SetPoint("BOTTOM", b.dot, "CENTER")
    b.role = b:CreateTexture(nil, "OVERLAY")
    b.role:SetSize(DOT_ICON, DOT_ICON)
    b.role:SetPoint("CENTER", b.dot, "CENTER")
    return b
end

-- Its colour: a minion's gold, a party member's class, grey when dead or
-- offline
local function CardColor(b)
    local unit = b.unit
    if Flag(UnitIsDeadOrGhost, unit) or (b.isParty and not Flag(UnitIsConnected, unit)) then return UF.GREY end
    if not b.isParty then return UF.GOLD end
    return UF.ClassColor(unit) or UF.GOLD
end

-- Out of range: faint (a secret answer: as in range)
local function Near(unit)
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok or Secret(inRange) or Secret(checked) then return true end
    return not (checked == true and inRange == false)
end

-- Its role's colour and icon: a minion's gold, its paw; a party member's
-- role (the game's: tank blue, healer green, damage red, the role's icon),
-- grey and none when it has none
local ROLE_COLOR = {
    MINION = { 1, 0.82, 0 },
    TANK = { 0.3, 0.55, 1 },
    HEALER = { 0.3, 0.9, 0.35 },
    DAMAGER = { 0.95, 0.3, 0.25 },
}
local NO_ROLE = { 0.45, 0.45, 0.45 }

local ROLE_ICON = {
    MINION = "paw-icon",
    TANK = "groupfinder-icon-role-micro-tank",
    HEALER = "groupfinder-icon-role-micro-heal",
    DAMAGER = "groupfinder-icon-role-micro-dps",
}

local function SetRole(b, role)
    local c = role and ROLE_COLOR[role] or NO_ROLE
    b.dot:SetVertexColor(c[1], c[2], c[3], 1)
    b.stem:SetVertexColor(c[1], c[2], c[3], STEM_ALPHA)
    local atlas = role and ROLE_ICON[role]
    if atlas then
        b.role:SetAtlas(atlas)
        b.role:Show()
    else
        b.role:Hide()
    end
end

local function Role(b)
    if not b.isParty then return "MINION" end
    if not UnitGroupRolesAssigned then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, b.unit)
    if not ok or Secret(role) then return nil end
    return role
end

-- (previewing, /if cards: on, and the focus it shows: nil the setting's)
local previewing, previewFocus = false, nil

-- (a preview's stand-in: the slot's name, class colour, role, health and
-- threat; its model, power and level yours)
local function Sample(b)
    local sample = b.sample
    b.name:SetText(sample.name)
    local color = sample.class and RAID_CLASS_COLORS[sample.class]
    local c = color and { color.r, color.g, color.b } or UF.GOLD
    UF.AvatarLook(b.avatar, "player", c, false)
    SetRole(b, sample.role)
    b.health:SetMinMaxValues(0, 1)
    b.health:SetValue(sample.health)
    b.health.text:SetFormattedText("%d%%", sample.health * 100)
    b.health.text:Show()
end

---------------------------------------------------------------------------
-- Focus: the cards as your role needs them (the setting, or your assigned
-- role), coloured as a monster's level: a tank's show who has a monster's
-- attention (a border by threat, 0 green to 3 red flashing; nothing when
-- the game keeps threat secret); a healer's show who's hurt (a border by
-- health left, green to red flashing under URGENT: the game's curves of
-- the health percent, secrets handed to SetAlpha as they are).
-- Only the card's look changes: its button (secure) stays as it is.
---------------------------------------------------------------------------
local TOP_THREAT = 3             -- (securely tanking: the alert flashing)

-- (the healer's alert by health left, a band of it each: green to 90%,
-- yellow to 70%, orange to 50%, red flashing under URGENT. As the game's
-- curves of the health percent (secret: one per band, 1 inside it, 0
-- outside), and the same worked in Lua for a preview's stand-in health)
local URGENT = 0.35
local function Band(low, high)
    local e = 0.001
    local points = { { 0, low > 0 and 0 or 1 } }
    if low > 0 then
        points[#points + 1] = { low, 0 }
        points[#points + 1] = { low + e, 1 }
    end
    points[#points + 1] = { high, 1 }
    points[#points + 1] = { high + e, 0 }
    points[#points + 1] = { 1, 0 }
    return points
end
local HURT_BANDS = { Band(0.7, 0.9), Band(0.5, 0.7), Band(URGENT, 0.5) }
local URGENT_POINTS = Band(0, URGENT)

local curves = {}
local function Curve(points)
    if curves[points] ~= nil then return curves[points] end
    curves[points] = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, curve = pcall(function()
            local c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Linear)
            for _, p in ipairs(points) do c:AddPoint(p[1], p[2]) end
            return c
        end)
        if ok then curves[points] = curve end
    end
    return curves[points]
end

local function CurveAt(points, p)
    for i = 2, #points do
        local a, z = points[i - 1], points[i]
        if p <= z[1] then return a[2] + (z[2] - a[2]) * (p - a[1]) / (z[1] - a[1]) end
    end
    return 0
end

-- The focus in use: a preview's, else PC.RoleFocus()
function PC.Focus()
    if previewing and previewFocus then return previewFocus end
    return PC.RoleFocus()
end

-- The focus of the setting, or (auto) your assigned role's: "tank",
-- "healer" or "off" (a preview's left out)
function PC.RoleFocus()
    local choice = IN.Settings().cardFocus
    if choice ~= "auto" then return choice end
    if not UnitGroupRolesAssigned then return "off" end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if not ok or Secret(role) then return "off" end
    if role == "TANK" then return "tank" end
    if role == "HEALER" then return "healer" end
    return "off"
end

-- (the alert shown: band (1 green, 2 yellow, 3 orange, 4 red flashing),
-- or none)
local function AlertBand(b, band)
    for i, f in ipairs(b.bands) do f:SetAlpha(i == band and 1 or 0) end
    b.urgent:SetAlpha(band == 4 and 1 or 0)
    b.pulse:SetAlpha(band == 4 and 1 or 0)
end

-- (its threat, 0 to 3; nil when it has none or the game keeps it secret)
local function Threat(b)
    local ok, level = pcall(function()
        if b.sample then return b.sample.threat end
        local status = UnitThreatSituation(b.unit)
        if Secret(status) or type(status) ~= "number" then return nil end
        return status
    end)
    return ok and level or nil
end

local function Focus(b)
    local mode = PC.Focus()
    local unit = b.unit
    if mode == "tank" then
        local level = Threat(b)
        if level then
            -- (0 green ... the highest, flashing red)
            AlertBand(b, math.min(level, TOP_THREAT) + 1)
        else
            AlertBand(b, nil)
        end
    elseif mode == "healer" and b.sample then
        local band
        for i, points in ipairs(HURT_BANDS) do
            if CurveAt(points, b.sample.health) > 0.5 then band = i end
        end
        if CurveAt(URGENT_POINTS, b.sample.health) > 0.5 then band = 4 end
        AlertBand(b, band)
    elseif mode == "healer" and Curve(URGENT_POINTS) then
        -- (each band's alpha its curve's: secrets, handed on as they are)
        local ok = pcall(function()
            for i, points in ipairs(HURT_BANDS) do
                b.bands[i]:SetAlpha(UnitHealthPercent(unit, true, Curve(points)))
            end
            local urgent = UnitHealthPercent(unit, true, Curve(URGENT_POINTS))
            b.urgent:SetAlpha(urgent)
            b.pulse:SetAlpha(urgent)
        end)
        if not ok then AlertBand(b, nil) end
    else
        AlertBand(b, nil)
    end
end

-- Party casting's buttons shown: it's on (PartyPad.lua), or a tank's or
-- healer's preview
function PC.PadShown()
    local pp = IN.PartyPad
    if not pp then return false end
    if pp.Active() then return true end
    local focus = PC.Focus()
    return previewing and (focus == "tank" or focus == "healer")
end

-- A preview up (/if cards)
function PC.Previewing()
    return previewing
end

-- Picking now: those buttons shown and L1 held
function PC.Picking()
    return PC.PadShown() and IN.PartyPad.Held()
end

-- (its face button shown, at its corner; picking, big in its middle)
local function PadGlyph(b)
    if not b.padGlyph then return end
    local atlas = PC.PadShown() and IN.PartyPad.Glyph(b.member)
    if atlas then
        b.padGlyph:SetAtlas(atlas)
        b.pickGlyph:SetAtlas(atlas)
    end
    b.padGlyph:SetShown(atlas and true or false)
    b.pickGlyph:SetShown(atlas and true or false)
end

local function Refresh(b)
    local unit = b.unit
    if not UnitExists(unit) then return end
    PadGlyph(b)
    Focus(b)
    if b.sample then
        UF.AvatarUnit(b.avatar, unit)
        UF.FillHealth(b)
        UF.FillPower(b)
        Sample(b)
        b:SetAlpha(1)
        return
    end
    UF.AvatarUnit(b.avatar, unit)
    Try(b.name.SetText, b.name, UnitName(unit))
    UF.NameColor(b)
    local c = CardColor(b)
    UF.AvatarLook(b.avatar, unit, c, c == UF.GREY)
    UF.FillHealth(b)
    UF.FillPower(b)
    SetRole(b, Role(b))
    b:SetAlpha(Near(unit) and 1 or 0.55)
end

local MODEL_EVENTS = UF.MODEL_EVENTS

local function Listen(b)
    for _, e in ipairs(UF.Join(UF.UNIT, UF.POWER_EVENTS)) do pcall(b.RegisterUnitEvent, b, e, b.unit) end
    for _, e in ipairs({ "UNIT_LEVEL", "UNIT_CONNECTION", "UNIT_THREAT_SITUATION_UPDATE" }) do
        pcall(b.RegisterUnitEvent, b, e, b.unit)
    end
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_ENTERING_WORLD", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(b.RegisterEvent, b, e)
    end
    b.Refresh = Refresh
    b:SetScript("OnEvent", function(self, event)
        if not UnitExists(self.unit) then return end
        if MODEL_EVENTS[event] then UF.AvatarUnit(self.avatar, self.unit, true) end
        Refresh(self)
    end)
    b:SetScript("OnShow", function(self)
        UF.AvatarUnit(self.avatar, self.unit, true)
        Refresh(self)
    end)
end

---------------------------------------------------------------------------
-- The two groups in one row, a label over each (Layout centres the row)
---------------------------------------------------------------------------
local minions = { Card("ImprovedForeverMinionCard1", "pet", MINION_SCALE) }
minions[1]:SetPoint("BOTTOMLEFT", UF.player, "BOTTOMRIGHT", MINION_GAP, 0)   -- (Layout places them)

local party = {}
for i = 1, 4 do
    local b = Card("ImprovedForeverPartyCard" .. i, "party" .. i, 1)
    b.isParty = true
    b.member = i
    -- (its face button, top right, while L1 + it targets this member:
    -- PartyPad.lua)
    b.padGlyph = b.avatar.badge:CreateTexture(nil, "OVERLAY", nil, 2)
    b.padGlyph:SetSize(PAD_GLYPH, PAD_GLYPH)
    b.padGlyph:SetPoint("CENTER", b.avatar, "TOPRIGHT", -6, -6)
    b.padGlyph:Hide()
    b.pickGlyph = b.avatar.badge:CreateTexture(nil, "OVERLAY", nil, 2)
    b.pickGlyph:SetSize(PICK_GLYPH, PICK_GLYPH)
    b.pickGlyph:SetPoint("CENTER", b.avatar, "CENTER", 0, 8)
    b.pickGlyph:SetAlpha(0)
    b.pick = 0
    -- (the highlight, round the whole card while picking: the game's
    -- spell alert template, a frame of ours (not its alert manager's),
    -- under the card's picture (which hides its inner part), anchored
    -- round it (so it grows with it); its strength b.hl's alpha (a secret,
    -- maybe: Highlight), its fade in the alert's own alpha (Picking))
    b.hl = CreateFrame("Frame", nil, b)
    b.hl:SetAllPoints(b.avatar)
    b.hl:SetFrameLevel(math.max(0, b.avatar:GetFrameLevel() - 1))
    b.hl:SetAlpha(0)
    b.hl:Hide()
    local ok, alert = pcall(CreateFrame, "Frame", nil, b.hl, "ActionButtonSpellAlertTemplate")
    if ok and alert and alert.ProcStartAnim then
        alert:SetPoint("TOPLEFT", b.avatar, "TOPLEFT", -ALERT_OUT, ALERT_OUT)
        alert:SetPoint("BOTTOMRIGHT", b.avatar, "BOTTOMRIGHT", ALERT_OUT, -ALERT_OUT)
        local w, h = b.avatar:GetSize()
        if alert.ProcStartFlipbook then
            alert.ProcStartFlipbook:SetSize((w + 2 * ALERT_OUT) * BURST_SIZE, (h + 2 * ALERT_OUT) * BURST_SIZE)
        end
        b.alertGlow = alert
    end
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", (i - 1) * (CARD_W + GAP), BOTTOM)
    party[i] = b
end

for _, b in ipairs(minions) do Listen(b) end
for _, b in ipairs(party) do Listen(b) end

local function Label(text, anchor, point)
    local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(0.75, 0.75, 0.75)
    -- (clear of the card's level badge, on its top left corner)
    fs:SetPoint(point, anchor, "TOP" .. point, 20, 8)
    fs:Hide()
    return fs
end
local minionLabel = Label("Minions", minions[1], "LEFT")
local partyLabel = Label("Party", party[1], "LEFT")

local function AnyShown(list)
    for _, b in ipairs(list) do
        if b:IsShown() then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The game's party and pet frames drawn at 0 while ours show (Edit Mode:
-- the game's shown, ours drawn at 0); the labels with their groups; the
-- range a few times a second
---------------------------------------------------------------------------
local function Natives()
    return { PartyFrame, CompactPartyFrame, PetFrame }
end

-- The member to see to, their button lit (Watch, as their buttons show):
-- a tank's, the highest threat (when the game says it: none secret); a
-- healer's, the lowest health under HEAL_AT. Health the game keeps secret
-- can't be compared: then each card lit by its own, the game's curve of
-- its health percent (LOW_POINTS), a secret handed to SetAlpha.
local HEAL_AT = 0.9
local LOW_POINTS = { { 0, 1 }, { URGENT, 1 }, { 0.6, 0 }, { 1, 0 } }

local function Readable(v)
    return type(v) == "number" and not Secret(v)
end

-- (its health, 0 to 1, or nil: secret)
local function Health(b)
    if b.sample then return b.sample.health end
    local ok, h, top = pcall(function() return UnitHealth(b.unit), UnitHealthMax(b.unit) end)
    if not (ok and Readable(h) and Readable(top)) or top <= 0 then return nil end
    return h / top
end

local function Highlight()
    local mode = PC.Focus()
    local list = {}
    for _, b in ipairs(party) do
        if b:IsShown() and b.padGlyph:IsShown() then list[#list + 1] = b end
    end
    local lit = {}
    if mode == "tank" then
        local top = 0
        for _, b in ipairs(list) do
            local level = Threat(b)
            if level and level >= 1 then
                if level > top then top, lit = level, {} end
                if level == top then lit[b] = true end
            end
        end
    elseif mode == "healer" then
        local low, lowest, secret = HEAL_AT, nil, false
        for _, b in ipairs(list) do
            if b.sample or not Flag(UnitIsDeadOrGhost, b.unit) then
                local h = Health(b)
                if h == nil then
                    secret = true
                elseif h < low then
                    low, lowest = h, b
                end
            end
        end
        if secret and Curve(LOW_POINTS) then
            for _, b in ipairs(list) do
                local ok = not Flag(UnitIsDeadOrGhost, b.unit)
                    and pcall(function() b.hl:SetAlpha(UnitHealthPercent(b.unit, true, Curve(LOW_POINTS))) end)
                if not ok then b.hl:SetAlpha(0) end
            end
            return
        end
        if lowest then lit[lowest] = true end
    end
    for _, b in ipairs(party) do b.hl:SetAlpha(lit[b] and 1 or 0) end
end

local function Watch()
    if not IF.db then return end
    local on = IN.Settings().cards
    local edit = UF.EditMode()
    for _, native in ipairs(Natives()) do
        IF.Focus.Fade(native, on and not edit)
        UF.Cover(native, on and not edit)
    end
    local alpha = edit and 0 or 1
    for _, list in ipairs({ minions, party }) do
        for _, b in ipairs(list) do
            if b:IsShown() then
                b:SetAlpha(edit and 0 or ((b.sample or Near(b.unit)) and 1 or 0.55))
            end
        end
    end
    Highlight()
    minionLabel:SetShown(on and alpha > 0 and AnyShown(minions))
    partyLabel:SetShown(on and alpha > 0 and AnyShown(party))
end

IN.Watcher("cards", 0.2, Watch)


-- Picking (L1 held, party targeting): each party card grown, its button
-- big in its middle, eased in and out (its picture scaled from its foot:
-- the secure button stays as it is)
local picker = CreateFrame("Frame")
picker:SetScript("OnUpdate", function(_, elapsed)
    if not IF.db then return end
    local want = PC.Picking() and 1 or 0
    for _, b in ipairs(party) do
        -- (the highlight's glow: shown, its birth played, as picking starts)
        local glow = want == 1 and b:IsShown() and b.pickGlyph:IsShown() and b.alertGlow ~= nil
        if b.glowing ~= glow then
            b.glowing = glow
            b.hl:SetShown(glow)
            if glow then
                b.alertGlow:Show()
                b.alertGlow.ProcStartAnim:Play()
            end
        end
        if b.pick ~= want and b:IsShown() then
            local step = elapsed / PICK_TIME
            b.pick = want > b.pick and math.min(want, b.pick + step) or math.max(want, b.pick - step)
            local e = b.pick * b.pick * (3 - 2 * b.pick)
            b.avatar:SetScale(1 + (PICK_GROW - 1) * e)
            b.pickGlyph:SetAlpha(e)
            b.padGlyph:SetAlpha(1 - e)
            if b.alertGlow then b.alertGlow:SetAlpha(e) end
        end
    end
end)

---------------------------------------------------------------------------
-- Shown or not (secure frames: out of combat only, else after it)
---------------------------------------------------------------------------
local pending

local function Driven(b, on, condition)
    if on and not b.driven then
        RegisterStateDriver(b, "visibility", condition)
        b.driven = true
    elseif not on and b.driven then
        UnregisterStateDriver(b, "visibility")
        b.driven = nil
        b:Hide()
    end
end

---------------------------------------------------------------------------
-- Preview (/if cards): every slot shown, a stand-in in each (your model,
-- bars and level under a slot's name, class colour and role), to see the
-- layout without a group; the game's state drivers off meanwhile. Out of
-- combat only (the cards are secure frames); /if cards again, a reload or
-- the setting turned off ends it.
---------------------------------------------------------------------------
-- (health 0 to 1, threat 0 to 3: a spread, so each focus has something to
-- show)
local SAMPLES = {
    minion = { name = "Minion", role = "MINION", health = 0.9, threat = 0 },
    { name = "Tank", class = "WARRIOR", role = "TANK", health = 0.55, threat = 3 },
    { name = "Healer", class = "PRIEST", role = "HEALER", health = 0.85, threat = 0 },
    { name = "Mage", class = "MAGE", role = "DAMAGER", health = 0.2, threat = 2 },
    { name = "Rogue", class = "ROGUE", role = "DAMAGER", health = 0.7, threat = 1 },
}

local realUnit = {}

local function Preview(on)
    local all = {}
    for _, b in ipairs(minions) do all[#all + 1] = { b, SAMPLES.minion } end
    for i, b in ipairs(party) do all[#all + 1] = { b, SAMPLES[i] } end
    for _, entry in ipairs(all) do
        local b, sample = entry[1], entry[2]
        if on then
            UF.Watched(b, false)
            Driven(b, false)
            -- (its own unit kept: the stand-in drawn from yours)
            realUnit[b] = realUnit[b] or b.unit
            b.unit, b.sample = "player", sample
            b:Show()
            UF.AvatarUnit(b.avatar, "player", true)
            Refresh(b)
        else
            b.unit, b.sample = realUnit[b] or b.unit, nil
        end
    end
end

-- The cards placed (those there; all of them previewing): your minions
-- beside the player frame, your party centred, GAP apart. Secure frames:
-- placed out of combat only, else after it.
local layoutPending

local function Layout()
    if IF.InCombat() then
        layoutPending = true
        return
    end
    layoutPending = nil
    local inRaid = IsInRaid and IsInRaid()
    local mins, members = {}, {}
    for _, b in ipairs(minions) do
        if previewing or UnitExists(b.unit) then mins[#mins + 1] = b end
    end
    for _, b in ipairs(party) do
        if previewing or (not inRaid and UnitExists(realUnit[b] or b.unit)) then members[#members + 1] = b end
    end
    -- (the minions beside the player frame, bottom left, their bottoms
    -- level, MINION_GAP after it, GAP apart)
    local anchor, gap = UF.player, MINION_GAP
    for _, b in ipairs(mins) do
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", gap, 0)
        anchor, gap = b, GAP
    end
    -- (the party centred at the bottom; the party spells' diamond,
    -- PartyPad.lua, when shown: PAD_GAP after the last card, the cards
    -- centred without it)
    local pp = IN.PartyPad
    local pad = pp and pp.Shown() and pp.Width() or 0
    if #members == 0 then
        if pad > 0 then pp.Place(-pad / 2, BOTTOM + CARD_H / 2) end
        return
    end
    local width = (#members - 1) * GAP
    for _, b in ipairs(members) do width = width + b.cardW end
    local x = -width / 2
    for _, b in ipairs(members) do
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", x, BOTTOM)
        x = x + b.cardW + GAP
    end
    if pad > 0 then pp.Place(x - GAP + PAD_GAP, BOTTOM + CARD_H / 2) end
end
PC.Layout = Layout

local layoutEvents = CreateFrame("Frame")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
    layoutEvents:RegisterEvent(e)
end
layoutEvents:RegisterUnitEvent("UNIT_PET", "player")
layoutEvents:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_ENABLED" or layoutPending then Layout() end
end)

-- /if cards [tank | healer | dps | off]: the preview on (with that focus:
-- dps none; none given, the setting's), or off; /if cards alone toggles it
local PREVIEW_FOCUS = { tank = "tank", healer = "healer", heal = "healer", dps = "off", damage = "off" }

local function RefreshAll()
    for _, list in ipairs({ minions, party }) do
        for _, b in ipairs(list) do
            if b:IsShown() then Refresh(b) end
        end
    end
end

function PC.TogglePreview(arg)
    if IF.InCombat() then return IF.Print("cards preview: not in combat") end
    arg = arg and arg:lower()
    local focus = arg and PREVIEW_FOCUS[arg]
    if arg and not focus and arg ~= "off" then
        return IF.Print("/if cards [tank | healer | dps | off]")
    end
    local on
    if arg == "off" then on = false elseif focus then on = true else on = not previewing end
    previewFocus = focus
    if on and previewing then
        RefreshAll()
    elseif on then
        previewing = true
        Preview(true)
        Layout()
    elseif previewing then
        previewing = false
        Preview(false)
        PC.Apply()
        Layout()
        return IF.Print("cards preview off")
    else
        return
    end
    IF.Print("cards preview on" .. (focus and (" (" .. arg .. " focus)") or "") .. ": /if cards off to end it")
end

function PC.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = nil
    if previewing then return end
    local on = IN.Settings().cards
    for _, b in ipairs(minions) do UF.Watched(b, on) end
    for i, b in ipairs(party) do
        Driven(b, on, "[group:raid] hide; [@party" .. i .. ",exists] show; hide")
    end
    Layout()
    Watch()
    if IN.PartyPad then IN.PartyPad.Apply() end
    -- (their look again: the focus may have changed)
    for _, list in ipairs({ minions, party }) do
        for _, b in ipairs(list) do
            if b:IsShown() then Refresh(b) end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then PC.Apply() end
end)

IF.OnLogin(PC.Apply)
