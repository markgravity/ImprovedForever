-- The game's player and target frames hidden, ours in their place, all in
-- one look: a name over bars in the casting bar's frame (its background
-- and border round the unit frames' fills), the percent on them:
-- * the target in the header's place under the top (TargetHeader.lua):
--   its health as the rule, its portrait in a diamond on it, its name,
--   quests and casts under it;
-- * the player bottom left, a card as the minion and party ones: its
--   model in the game's dialog border, its level and class on it, its name (a
--   combat mark by it), health and power in a band along its foot (its
--   pet: a card beside it, PartyCards.lua).
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

-- A yes / no about the unit (false when the API has none or says a
-- secret). A secret is never compared, even in a pcall: the attempt is
-- blocked and taints what runs after it.
local function Flag(fn, unit)
    if not fn then return false end
    local ok, v = pcall(fn, unit)
    if not ok or Secret(v) then return false end
    return v == true
end

-- A unit's class colour as { r, g, b }, or nil (none, or a secret class)
local function ClassColorOf(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if not ok or Secret(class) or not class then return nil end
    local color = RAID_CLASS_COLORS[class]
    return color and { color.r, color.g, color.b }
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
    bar.frame = frame
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
        if Secret(token) then return nil end
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
-- The target: a secure button of ours in the header's place (HeaderSlot.lua),
-- over its diamond and name (a click targets, a right click opens its menu,
-- the mouse over it its tooltip and its health's numbers), shown by the
-- game's unit watch. What it shows is TargetHeader.lua's (target:Refresh):
-- a frame of its own, never anchored to this one (an anchor to a secure
-- frame would lock it in a fight), so it can come and go in the header's
-- place
---------------------------------------------------------------------------
local HS = IN.HeaderSlot
local TARGET_W, TARGET_H, TARGET_Y = 300, 96, -18
local target = UnitButton("ImprovedForeverTargetBar", "target", TARGET_W, TARGET_H)
target:SetPoint("CENTER", UIParent, "TOP", 0, -HS.RULE_Y + TARGET_Y)
target:Hide()
target.Refresh = function() end

---------------------------------------------------------------------------
-- An avatar (the player's, a minion's or a party member's card,
-- PartyCards.lua): the unit's model in the game's dialog border (its
-- diamond-metal frame, scaled down, its centre left out), its round portrait when it's too far
-- to be drawn, a strip along its top in its colour, its level in the
-- game's small circle at the top left. a.over: a frame over the model,
-- under the border (a card's band and bars go on it).
---------------------------------------------------------------------------
local AVATAR_INSET, STRIP_H, ZOOM = 4, 3, 0.45
local BRONZE = { 0.62, 0.5, 0.32 }     -- (the border's own, should the game's layout be missing)

-- The game's dialog border (its diamond-metal frame: NineSliceUtil's
-- "Dialog" layout, as its popups), on a frame of its own over ours scaled
-- down to a card (BORDER_SCALE), its centre left out; without it, thin
-- bronze edges of ours. Its pieces: frame.borderPieces (to tint)
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
local BORDER_LAYOUT, BORDER_SCALE = "Dialog", 0.35

local function Border(frame)
    frame.borderPieces = {}
    local edge = CreateFrame("Frame", nil, frame)
    edge:SetScale(BORDER_SCALE)
    edge:SetAllPoints()
    local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName
        and pcall(NineSliceUtil.ApplyLayoutByName, edge, BORDER_LAYOUT)
    if ok and edge.TopEdge then
        if edge.Center then edge.Center:Hide() end
        for _, key in ipairs(PIECES) do
            if edge[key] then frame.borderPieces[#frame.borderPieces + 1] = edge[key] end
        end
        return
    end
    edge:Hide()
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
        frame.borderPieces[#frame.borderPieces + 1] = t
    end
end

local function Avatar(parent, w, h)
    local a = CreateFrame("Frame", nil, parent)
    a:SetSize(w, h)
    local bg = a:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.03, 0.03, 0.04, 0.9)

    a.portrait = a:CreateTexture(nil, "ARTWORK")
    local side = math.min(w, h) - 20
    a.portrait:SetSize(side, side)
    a.portrait:SetPoint("CENTER", 0, 4)
    a.model = CreateFrame("PlayerModel", nil, a)
    a.model:SetPoint("TOPLEFT", AVATAR_INSET, -AVATAR_INSET - STRIP_H)
    a.model:SetPoint("BOTTOMRIGHT", -AVATAR_INSET, AVATAR_INSET)

    a.over = CreateFrame("Frame", nil, a)
    a.over:SetAllPoints()
    a.over:SetFrameLevel(a.model:GetFrameLevel() + 2)
    a.strip = a.over:CreateTexture(nil, "ARTWORK")
    a.strip:SetPoint("TOPLEFT", AVATAR_INSET, -AVATAR_INSET)
    a.strip:SetPoint("TOPRIGHT", -AVATAR_INSET, -AVATAR_INSET)
    a.strip:SetHeight(STRIP_H)
    a.strip:SetColorTexture(1, 1, 1, 1)

    local frame = CreateFrame("Frame", nil, a.over)
    frame:SetAllPoints()
    frame:SetFrameLevel(a.over:GetFrameLevel() + 6)
    Border(frame)
    local top = CreateFrame("Frame", nil, frame)
    a.badge = top
    top:SetAllPoints()
    top:SetFrameLevel(frame:GetFrameLevel() + 2)
    a.gem = Atlas(top, "OVERLAY", "UI-HUD-UnitFrame-SmallCircle", 1)
    a.gem:SetSize(24, 24)
    a.gem:SetPoint("CENTER", a, "TOPLEFT", 6, -6)
    a.level = Text(top, "GameFontHighlightSmall")
    a.level:SetDrawLayer("OVERLAY", 2)
    a.level:SetPoint("CENTER", a.gem, "CENTER", 0, -0.5)
    return a
end

-- Its model, drawn only when the unit is (else its portrait); again when
-- that changes, or always (force: the unit or its looks changed)
local function AvatarUnit(a, unit, force)
    local visible = Flag(UnitIsVisible, unit)
    if not force and visible == a.modelVisible then return end
    a.model:SetShown(visible)
    a.portrait:SetShown(not visible)
    SetPortraitTexture(a.portrait, unit)
    if visible then
        a.model:SetUnit(unit)
        a.model:SetPortraitZoom(ZOOM)
    end
    a.modelVisible = visible
end

-- Its strip's colour (grey: its portrait greyed too) and its level
local function AvatarLook(a, unit, color, grey)
    a.strip:SetVertexColor(color[1], color[2], color[3], 1)
    a.portrait:SetDesaturated(grey and true or false)
    local ok, level = pcall(function()
        local l = UnitLevel(unit)
        if Secret(l) then return "" end
        return (l and l > 0) and tostring(l) or "??"
    end)
    a.level:SetText(ok and level or "")
end

-- A unit's class colour, or nil
local function ClassColor(unit)
    return ClassColorOf(unit)
end

-- The events that change a model
local MODEL_EVENTS = { UNIT_MODEL_CHANGED = true, UNIT_PORTRAIT_UPDATE = true, GROUP_ROSTER_UPDATE = true,
    UNIT_PET = true, PLAYER_ENTERING_WORLD = true }

---------------------------------------------------------------------------
-- The player's bottom left, a card as the minion and party ones
-- (PartyCards.lua), bigger: its avatar (as tall as the gamepad bar's big
-- diamond; no strip along its top: the experience ring is there,
-- XPBar.lua), along its foot a dark band with its name (a combat mark
-- before it) over its health, its power under it
---------------------------------------------------------------------------
-- (the avatar as tall as the gamepad bar's face buttons diamond,
-- GamepadBar.lua: two spreads and a tile's width of a 44 tile, about 154;
-- the cards' proportions)
local AVATAR_H = 154
local AVATAR_W = math.floor(AVATAR_H * 0.78 + 0.5)
-- (the band's parts, a party card's (14, 11, 14, inset 4) a bit bigger)
local CARD_HEALTH_H, CARD_POWER_H, CARD_NAME_H, CARD_INSET = 18, 14, 18, 4
local PLAYER_X, PLAYER_Y = 20, IN.BOTTOM
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.45, 0.45, 0.45 }
local player = UnitButton("ImprovedForeverPlayerFrame", "player", AVATAR_W, AVATAR_H)
player:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", PLAYER_X, PLAYER_Y)
player:Hide()

do
    local p = player
    p.avatar = Avatar(p, AVATAR_W, AVATAR_H)
    p.avatar:SetPoint("BOTTOM")
    p.avatar.strip:Hide()
    p.avatar.model:SetPoint("TOPLEFT", AVATAR_INSET, -AVATAR_INSET)
    local over = p.avatar.over
    local shade = over:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("BOTTOMLEFT", CARD_INSET, CARD_INSET)
    shade:SetPoint("BOTTOMRIGHT", -CARD_INSET, CARD_INSET)
    shade:SetHeight(CARD_POWER_H + CARD_HEALTH_H + CARD_NAME_H + 4)
    shade:SetColorTexture(0, 0, 0, 0.65)
    local w = AVATAR_W - 2 * CARD_INSET + 2
    p.power = Bar(over, w, CARD_POWER_H, POWER_FILL .. "Mana")
    p.power.box:SetPoint("BOTTOM", 0, CARD_INSET - 1)
    p.health = Bar(over, w, CARD_HEALTH_H, HEALTH_FILL)
    p.health.box:SetPoint("BOTTOM", p.power.box, "TOP", 0, 0)
    local small = _G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small
    if small then
        p.health.text:SetFontObject(small)
        p.power.text:SetFontObject(small)
    end
    p.name = Text(over, "GameFontNormal")
    p.name:SetHeight(CARD_NAME_H)
    p.combat = Atlas(over, "OVERLAY", "UI-HUD-UnitFrame-Player-CombatIcon")
    p.combat:SetSize(CARD_NAME_H, CARD_NAME_H)
    p.combat:SetPoint("BOTTOMLEFT", p.health.box, "TOPLEFT", 2, 1)
end

function player:Refresh(event)
    local unit = self.unit
    AvatarUnit(self.avatar, unit, event == nil or MODEL_EVENTS[event])
    local dead = Flag(UnitIsDeadOrGhost, unit)
    local color = ClassColor(unit) or GOLD
    AvatarLook(self.avatar, unit, dead and GREY or color, dead)
    Try(self.name.SetText, self.name, UnitName(unit))
    NameColor(self)
    -- (the name after the combat mark while in a fight)
    local fighting = Flag(UnitAffectingCombat, unit)
    self.combat:SetShown(fighting)
    self.name:ClearAllPoints()
    self.name:SetPoint("BOTTOMLEFT", self.health.box, "TOPLEFT", fighting and (CARD_NAME_H + 2) or 2, 1)
    self.name:SetPoint("BOTTOMRIGHT", self.health.box, "TOPRIGHT", -2, 1)
    FillHealth(self)
    FillPower(self)
end

---------------------------------------------------------------------------
-- Events: each frame refreshed when its unit changes
---------------------------------------------------------------------------
local function Listen(frame, unitEvents, events)
    -- (an event this client hasn't: left out, not an error)
    for _, e in ipairs(unitEvents) do pcall(frame.RegisterUnitEvent, frame, e, frame.unit) end
    for _, e in ipairs(events or {}) do pcall(frame.RegisterEvent, frame, e) end
    frame:SetScript("OnEvent", function(self, event) self:Refresh(event) end)
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
    "PLAYER_ENTERING_WORLD" })
Listen(target, { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_FACTION", "UNIT_LEVEL",
    "UNIT_CLASSIFICATION_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" },
    { "PLAYER_TARGET_CHANGED", "QUEST_LOG_UPDATE" })

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
UF.Avatar, UF.AvatarUnit, UF.AvatarLook, UF.ClassColor = Avatar, AvatarUnit, AvatarLook, ClassColor
UF.Border = Border
-- (the target's header, TargetHeader.lua)
UF.Secret, UF.Percent, UF.Numbers = Secret, Percent, Numbers
UF.MODEL_EVENTS, UF.GOLD, UF.GREY = MODEL_EVENTS, GOLD, GREY
-- (the player frame's top, from the screen's bottom: the chat over it,
-- HudLayout.lua)
UF.PLAYER_TOP = PLAYER_Y + AVATAR_H
UF.player = player
-- (the target's secure button: TargetHeader.lua draws what it shows)
UF.target = target

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
