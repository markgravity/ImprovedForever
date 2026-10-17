-- The game's player and target frames hidden, ours in their place, all in
-- one look: a name over bars in the casting bar's frame (its background
-- and border round the unit frames' fills), the percent on them:
-- * the target's health across the top centre, coloured by what it is,
--   its casts under it;
-- * the player's health and power bottom left, its round portrait on
--   their left (the ring of the game's unit frame), its level on it, a
--   combat mark by its name (its pet: a card at the bottom centre,
--   PartyCards.lua).
-- Ours are secure unit buttons (a click targets, a right click opens the
-- unit's menu), shown by the game's unit watch, so they work in a fight.
-- The game's are never hidden or changed (a property of the game's frames
-- set from addon code taints them): IF.Focus.Fade draws them at 0, and a
-- frame of ours over where they are takes the mouse they'd still get.
-- Health is a secret value in Forever: it's only handed to the widgets
-- (StatusBar:SetValue, FontString:SetFormattedText), never compared.
local IF = ImprovedForever
local IN = IF.Interface

local UF = {}
IN.UnitFrames = UF

local function Settings()
    return IN.Settings()
end

local function EditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() or false
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
-- (a widget method fed a secret value: never let one error stop an update)
local function Try(fn, ...)
    return pcall(fn, ...)
end

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- A yes / no about the unit (false when the API has none or says a secret)
local function Flag(fn, unit)
    if not fn then return false end
    local ok, yes = pcall(function() return fn(unit) == true end)
    return ok and yes
end

local function Atlas(parent, layer, atlas, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetAtlas(atlas, true)
    return t
end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(justify or "CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)
    return fs
end

-- A bar in the casting bar's frame, w x h: its background and border
-- (UI-CastingBar-Background / -Frame, the fill inset as the casting bar
-- has it: 209 / 214 wide, 11 / 16 high), the fill's atlas, a text over it
local function Bar(parent, w, h, atlas)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(w, h)
    local iw, ih = w * 209 / 214, h * 11 / 16
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("UI-CastingBar-Background")
    bg:SetSize(iw, ih)
    bg:SetPoint("CENTER")
    local bar = CreateFrame("StatusBar", nil, box)
    bar:SetSize(iw, ih)
    bar:SetPoint("CENTER")
    bar:SetStatusBarTexture(atlas)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local border = CreateFrame("Frame", nil, box)
    border:SetAllPoints()
    border:SetFrameLevel(bar:GetFrameLevel() + 1)
    local frame = border:CreateTexture(nil, "ARTWORK")
    frame:SetAtlas("UI-CastingBar-Frame")
    frame:SetAllPoints()
    bar.box = box
    bar.bg = bg
    bar.text = Text(border, "TextStatusBarText")
    bar.text:SetPoint("CENTER")
    return bar
end

-- The percent on a bar (the API's percent scaled to 100: a secret handed
-- to the text as is); percent(curve) asks the API
local function Percent(fs, percent)
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if not curve then return false end
    local ok, pct = pcall(percent, curve)
    return ok and Try(fs.SetFormattedText, fs, "%.0f%%", pct) or false
end

-- The bar's values: min, max and value straight from the API (secret or
-- not); its text the percent, "value / max" with the mouse over it or the
-- game's status text on
local function Fill(bar, value, max, numbers, percent)
    if not Try(bar.SetMinMaxValues, bar, 0, max) or not Try(bar.SetValue, bar, value) then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end
    local shown
    if numbers then
        shown = Try(bar.text.SetFormattedText, bar.text, "%s / %s", value, max)
    else
        shown = Percent(bar.text, percent)
    end
    if shown then
        bar.text:Show()
    else
        bar.text:SetText("")
        bar.text:Hide()
    end
end

-- The power bar's fill by the unit's power: the game's atlases per type
local POWER = { MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus", RUNIC_POWER = "RunicPower" }
local HEALTH_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local POWER_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-"

local function PowerAtlas(unit)
    local ok, kind = pcall(function()
        local _, token = UnitPowerType(unit)
        return POWER[token]
    end)
    return POWER_FILL .. (ok and kind or "Mana")
end

local function StatusTextOn()
    return GetCVarBool and GetCVarBool("statusText") or false
end

local function Numbers(frame)
    return frame.hover or StatusTextOn()
end

local function FillHealth(frame)
    local unit = frame.unit
    Fill(frame.health, UnitHealth(unit), UnitHealthMax(unit), Numbers(frame), function(curve)
        return UnitHealthPercent(unit, true, curve)
    end)
end

local function FillPower(frame)
    local unit = frame.unit
    frame.power:SetStatusBarTexture(PowerAtlas(unit))
    Fill(frame.power, UnitPower(unit), UnitPowerMax(unit), Numbers(frame), function(curve)
        return UnitPowerPercent(unit, nil, false, curve)
    end)
end

-- A secure unit button of ours: Cross / left click targets the unit, right
-- click opens its menu; the mouse over it shows its tooltip and its bars'
-- numbers
local function UnitButton(name, unit, w, h)
    local b = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    b:SetSize(w, h)
    b:SetFrameStrata("LOW")
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    b.unit = unit
    b:SetScript("OnEnter", function(self)
        self.hover = true
        if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) end
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
        if self.Refresh then self:Refresh() end
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = nil
        GameTooltip:Hide()
        if self.Refresh then self:Refresh() end
    end)
    return b
end

-- The name's colour: gold, grey when dead
local function NameColor(frame)
    local dead = Flag(UnitIsDeadOrGhost, frame.unit)
    frame.name:SetTextColor(dead and 0.5 or 1, dead and 0.5 or 0.82, dead and 0.5 or 0)
end

---------------------------------------------------------------------------
-- The target's health across the top centre: its name over a bar 1.5
-- times the casting bar, coloured by what the target is; its casts under
-- it
---------------------------------------------------------------------------
local SCALE = 1.5
local BAR_W, BAR_H = 214 * SCALE, 16 * SCALE
local NAME_H = 22
local CAST_H, CAST_GAP = 16, 4

local target = UnitButton("ImprovedForeverTargetBar", "target", BAR_W, NAME_H + BAR_H + CAST_GAP + CAST_H)
target:SetPoint("TOP", UIParent, "TOP", 0, -36)
target:Hide()

do
    local t = target
    t.name = Text(t, "GameFontNormalLarge")
    t.name:SetPoint("TOPLEFT")
    t.name:SetPoint("TOPRIGHT")
    t.name:SetHeight(NAME_H - 2)
    t.health = Bar(t, BAR_W, BAR_H, HEALTH_FILL)
    t.health.box:SetPoint("TOP", 0, -NAME_H)
end

-- The health's colour by what the target is: a player by its class, else
-- by its reaction to you (the game's FACTION_BAR_COLORS: hostile red,
-- unfriendly orange, neutral yellow, friendly green), grey when tapped by
-- others. A secret answer: red if you can attack it, else green.
local REACTION = {
    { 0.8, 0.3, 0.22 }, { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
    { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
}

local function UnitColor(unit)
    if Flag(UnitIsTapDenied, unit) then return 0.6, 0.6, 0.6 end
    if Flag(UnitIsPlayer, unit) then
        local ok, c = pcall(function()
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class]
            return color and { color.r, color.g, color.b }
        end)
        if ok and c then return c[1], c[2], c[3] end
    end
    local ok, c = pcall(function()
        local reaction = UnitReaction(unit, "player")
        local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if color then return { color.r, color.g, color.b } end
        return REACTION[reaction]
    end)
    if ok and c then return c[1], c[2], c[3] end
    local attack = Flag(function(u) return UnitCanAttack("player", u) end, unit)
    if attack then return REACTION[1][1], REACTION[1][2], REACTION[1][3] end
    return REACTION[5][1], REACTION[5][2], REACTION[5][3]
end

function target:Refresh()
    local unit = self.unit
    if not UnitExists(unit) then return end
    Try(self.name.SetText, self.name, UnitName(unit))
    NameColor(self)
    FillHealth(self)
    self.health:SetStatusBarDesaturated(true)
    self.health:SetStatusBarColor(UnitColor(unit))
end

---------------------------------------------------------------------------
-- The target's casts under its health, the casting bar's own fills (a
-- cast yellow, a channel green, grey while it can't be interrupted, red
-- when interrupted), the spell's icon on the left, its name on the bar.
-- The cast's times can be secret: they go to the bar as its min and max
-- as they are, the clock as its value (the bar works the fill out), and
-- the bar ends on the cast's end events, never by comparing them. A
-- channel drains: its fill drawn as the bar's background, the time gone
-- over it from the right. Whether it can be interrupted (a secret too)
-- shows through SetAlphaFromBoolean.
---------------------------------------------------------------------------
local FILL = {
    cast = "UI-CastingBar-Filling-Standard",
    channel = "UI-CastingBar-Filling-Channel",
    shield = "UI-CastingBar-Uninterruptable",
    interrupted = "UI-CastingBar-Interrupted",
    empty = "UI-CastingBar-Background",
}
local INTERRUPTED_HOLD = 0.6

local cast = Bar(target, BAR_W, CAST_H, FILL.cast)
cast.box:SetPoint("TOP", target.health.box, "BOTTOM", 0, -CAST_GAP)
cast.box:Hide()
cast.text:SetFontObject(_G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small or "TextStatusBarText")
cast.icon = cast.box:CreateTexture(nil, "ARTWORK")
cast.icon:SetSize(CAST_H + 4, CAST_H + 4)
cast.icon:SetPoint("RIGHT", cast.box, "LEFT", -2, 0)
cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
-- (the grey of a cast that can't be interrupted, over the fill)
cast.shield = cast:CreateTexture(nil, "ARTWORK", nil, 1)
cast.shield:SetAtlas(FILL.shield)
cast.shield:SetAlpha(0)
target.cast = cast

local function Present(v)
    return Secret(v) or v ~= nil
end

-- What the target casts now: kind ("cast" / "channel") and its info
local function Casting(unit)
    local name, text, texture, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(unit)
    if Present(name) then return "cast", text, texture, startMs, endMs, notInterruptible end
    local cname, ctext, ctexture, cstart, cend, _, cnot = UnitChannelInfo(unit)
    if Present(cname) then return "channel", ctext, ctexture, cstart, cend, cnot end
end

local function Shielded(notInterruptible)
    if not Try(cast.shield.SetAlphaFromBoolean, cast.shield, notInterruptible, 1, 0) then
        cast.shield:SetAlpha(0)
    end
end

function cast:Start(kind, text, texture, startMs, endMs, notInterruptible)
    self.kind = kind
    self.holdUntil = nil
    local channel = kind == "channel"
    self:SetStatusBarTexture(channel and FILL.empty or FILL.cast)
    self.bg:SetAtlas(channel and FILL.channel or FILL.empty)
    self:SetReverseFill(channel)
    local fill = self:GetStatusBarTexture()
    self.shield:ClearAllPoints()
    if channel then
        self.shield:SetPoint("TOPLEFT", self, "TOPLEFT")
        self.shield:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT")
    else
        self.shield:SetAllPoints(fill)
    end
    Shielded(notInterruptible)
    if not Try(self.SetMinMaxValues, self, startMs, endMs) then
        self.kind = nil
        self.box:Hide()
        return
    end
    self:SetValue(GetTime() * 1000)
    -- (plain times: an end of our own too, should an event be missed)
    self.endMs = not Secret(endMs) and type(endMs) == "number" and endMs or nil
    Try(self.text.SetText, self.text, text)
    self.text:Show()
    if not Try(self.icon.SetTexture, self.icon, texture) then self.icon:SetTexture(nil) end
    self.box:Show()
end

function cast:Interrupted()
    self.kind = nil
    self:SetReverseFill(false)
    self:SetStatusBarTexture(FILL.interrupted)
    self.bg:SetAtlas(FILL.empty)
    self.shield:SetAlpha(0)
    self:SetMinMaxValues(0, 1)
    self:SetValue(1)
    self.text:SetText(INTERRUPTED or "Interrupted")
    self.holdUntil = GetTime() + INTERRUPTED_HOLD
    self.box:Show()
end

function cast:Stop()
    self.kind = nil
    self.holdUntil = nil
    self.box:Hide()
end

-- The cast the target has now shown, or none
function cast:Check()
    local unit = target.unit
    if not UnitExists(unit) then return self:Stop() end
    local kind, text, texture, startMs, endMs, notInterruptible = Casting(unit)
    if kind then
        self:Start(kind, text, texture, startMs, endMs, notInterruptible)
    elseif not self.holdUntil then
        self:Stop()
    end
end

cast:SetScript("OnUpdate", function(self)
    local now = GetTime()
    if self.kind then
        self:SetValue(now * 1000)
        if self.endMs and now * 1000 > self.endMs + 300 then self:Check() end
    elseif self.holdUntil and now > self.holdUntil then
        self:Stop()
    end
end)

local castEvents = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
    castEvents:RegisterUnitEvent(e, "target")
end
castEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
castEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        cast.holdUntil = nil
        cast:Check()
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not Casting(target.unit) then cast:Interrupted() end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        cast.shield:SetAlpha(0)
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if cast.kind then cast.shield:SetAlpha(1) end
    else
        cast:Check()
    end
end)

---------------------------------------------------------------------------
-- A round portrait: the unit's face in the ring of the game's own unit
-- frame art, cut out of it (the atlas's part round its portrait, a circle
-- mask taking off the name and bar boxes it touches). ring = { atlas, x,
-- y, r }: the portrait's centre and the ring's outer radius in the atlas's
-- pixels; inner: the portrait's share of the ring's width.
---------------------------------------------------------------------------
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function Ring(parent, size, ring, inner)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    local face = holder:CreateTexture(nil, "BACKGROUND")
    face:SetSize(size * inner, size * inner)
    face:SetPoint("CENTER")
    local art = holder:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ring.atlas)
    local file = info and (info.file or info.filename)
    if file then
        local function U(px) return info.leftTexCoord + (info.rightTexCoord - info.leftTexCoord) * px / info.width end
        local function V(px) return info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) * px / info.height end
        art:SetTexture(file)
        art:SetTexCoord(U(ring.x - ring.r), U(ring.x + ring.r), V(ring.y - ring.r), V(ring.y + ring.r))
        local mask = holder:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints()
        art:AddMaskTexture(mask)
    end
    holder.face = face
    return holder
end

-- (the player frame's art: 198 x 71, its 60 px portrait's centre 37, 34.5
-- in)
local PLAYER_RING = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn", x = 37, y = 34.5, r = 35 }

---------------------------------------------------------------------------
-- The player's bottom left, as the target's: its portrait on the left
-- (its level in a circle on it, as the game's), then its name (a combat
-- mark before it) over its health, its power under it (the same width,
-- two thirds the height)
---------------------------------------------------------------------------
local POWER_H = 16
local RING = NAME_H + BAR_H + 2 + POWER_H + 8
local OVERLAP = 6
local PLAYER_X, PLAYER_Y = 20, 20
local player = UnitButton("ImprovedForeverPlayerFrame", "player", RING - OVERLAP + BAR_W, RING)
player:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", PLAYER_X, PLAYER_Y)
player:Hide()

do
    local p = player
    p.ring = Ring(p, RING, PLAYER_RING, 60 / 70)
    p.ring:SetPoint("LEFT")
    p.portrait = p.ring.face
    local bars = CreateFrame("Frame", nil, p)
    bars:SetSize(BAR_W, NAME_H + BAR_H + 2 + POWER_H)
    bars:SetPoint("RIGHT")
    p.ring:SetFrameLevel(bars:GetFrameLevel() + 5)
    p.combat = Atlas(bars, "OVERLAY", "UI-HUD-UnitFrame-Player-CombatIcon")
    p.combat:SetPoint("TOPLEFT", OVERLAP + 4, -3)
    p.name = Text(bars, "GameFontNormalLarge", "LEFT")
    p.name:SetHeight(NAME_H - 2)
    p.health = Bar(bars, BAR_W, BAR_H, HEALTH_FILL)
    p.health.box:SetPoint("TOP", 0, -NAME_H)
    p.power = Bar(bars, BAR_W, POWER_H, POWER_FILL .. "Mana")
    p.power.box:SetPoint("TOP", p.health.box, "BOTTOM", 0, -2)
    p.power.text:SetFontObject(_G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small or "TextStatusBarText")
    -- (the level: the game's small circle over the portrait's bottom left)
    local top = CreateFrame("Frame", nil, p.ring)
    top:SetAllPoints()
    top:SetFrameLevel(p.ring:GetFrameLevel() + 2)
    p.levelCircle = Atlas(top, "OVERLAY", "UI-HUD-UnitFrame-SmallCircle", 1)
    p.levelCircle:SetPoint("CENTER", p.ring, "BOTTOMLEFT", RING * 0.17, RING * 0.17)
    p.level = Text(top, "WhiteLargeNumberFont")
    p.level:SetDrawLayer("OVERLAY", 2)
    p.level:SetPoint("CENTER", p.levelCircle, "CENTER", 0, -0.5)
end

function player:Refresh()
    local unit = self.unit
    SetPortraitTexture(self.portrait, unit)
    Try(self.name.SetText, self.name, UnitName(unit))
    NameColor(self)
    Try(self.level.SetText, self.level, UnitLevel(unit))
    -- (the name after the combat mark while in a fight)
    local fighting = Flag(UnitAffectingCombat, unit)
    self.combat:SetShown(fighting)
    self.name:ClearAllPoints()
    self.name:SetPoint("TOPLEFT", (fighting and 24 or 4) + OVERLAP, 0)
    self.name:SetPoint("TOPRIGHT", -4, 0)
    FillHealth(self)
    FillPower(self)
end

---------------------------------------------------------------------------
-- Events: each frame refreshed when its unit changes
---------------------------------------------------------------------------
local function Listen(frame, unitEvents, events)
    for _, e in ipairs(unitEvents) do frame:RegisterUnitEvent(e, frame.unit) end
    for _, e in ipairs(events or {}) do frame:RegisterEvent(e) end
    frame:SetScript("OnEvent", function(self) self:Refresh() end)
    frame:SetScript("OnShow", function(self) self:Refresh() end)
end

local UNIT = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_PORTRAIT_UPDATE",
    "UNIT_MODEL_CHANGED" }
local POWER_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

local function Join(a, b)
    local t = {}
    for _, v in ipairs(a) do t[#t + 1] = v end
    for _, v in ipairs(b) do t[#t + 1] = v end
    return t
end

Listen(player, Join(UNIT, POWER_EVENTS), { "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" })
Listen(target, { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_FACTION" },
    { "PLAYER_TARGET_CHANGED", "CVAR_UPDATE" })

---------------------------------------------------------------------------
-- The game's frames drawn at 0 while ours show, and the mouse they'd
-- still get taken over where they are (a frame of ours placed by their
-- rect, not anchored to them: an anchor to a secure frame would lock ours
-- in a fight). In their strata: windows opened over them still get the
-- mouse.
---------------------------------------------------------------------------
local function Blocker()
    local f = CreateFrame("Frame", nil, UIParent)
    f:EnableMouse(true)
    f:SetMouseMotionEnabled(true)
    f:Hide()
    return f
end

local covers = {}

local function Cover(native, on)
    if not native then return end
    local f = covers[native]
    if not f then
        if not on then return end
        f = Blocker()
        covers[native] = f
    end
    if not (on and native:IsVisible()) then
        f:Hide()
        return
    end
    local l, b, w, h = native:GetRect()
    if not (l and b and w and h) then
        f:Hide()
        return
    end
    local k = native:GetEffectiveScale() / UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, b * k)
    f:SetSize(w * k, h * k)
    f:SetFrameStrata(native:GetFrameStrata())
    f:SetFrameLevel(native:GetFrameLevel() + 20)
    f:Show()
end

UF.Cover = Cover
UF.EditMode = EditMode
-- (the pieces the party cards are made of too, PartyCards.lua)
UF.Try, UF.Flag, UF.Text, UF.Atlas, UF.Bar = Try, Flag, Text, Atlas, Bar
UF.FillHealth, UF.FillPower, UF.UnitButton, UF.NameColor = FillHealth, FillPower, UnitButton, NameColor
UF.Listen, UF.Join, UF.UNIT, UF.POWER_EVENTS = Listen, Join, UNIT, POWER_EVENTS

-- What the settings ask, now (Edit Mode: the game's shown to be moved,
-- ours drawn at 0)
local function Hides()
    local s = Settings()
    local edit = EditMode()
    return s.player and not edit, s.target and not edit, edit
end

local function Watch()
    if not IF.db then return end
    local hidePlayer, hideTarget, edit = Hides()
    IF.Focus.Fade(PlayerFrame, hidePlayer)
    IF.Focus.Fade(TargetFrame, hideTarget)
    Cover(PlayerFrame, hidePlayer)
    Cover(TargetFrame, hideTarget)
    local alpha = edit and 0 or 1
    player:SetAlpha(alpha)
    target:SetAlpha(alpha)
end

IN.Watcher("unit frames", 0.1, Watch)

---------------------------------------------------------------------------
-- Ours shown or not (secure frames: out of combat only, else after it)
---------------------------------------------------------------------------
local pending

function UF.Watched(frame, on)
    if on and not frame.watched then
        RegisterUnitWatch(frame)
        frame.watched = true
    elseif not on and frame.watched then
        UnregisterUnitWatch(frame)
        frame.watched = nil
        frame:Hide()
    end
end

function UF.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = nil
    local s = Settings()
    player:SetShown(s.player)
    UF.Watched(target, s.target)
    Watch()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then UF.Apply() end
end)

IF.OnLogin(UF.Apply)
