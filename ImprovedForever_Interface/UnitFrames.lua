-- The game's player and target frames hidden, ours in their place, all in
-- one look: a name over bars in the casting bar's frame (its background
-- and border round the unit frames' fills), the percent on them:
-- * the target's health across the top centre, coloured by what it is,
--   its casts under it;
-- * the player's health and power bottom left, its avatar on their left
--   (its model in the game's tooltip border, as the minion and party
--   cards), its level on it, a combat mark by its name (its pet: a card at
--   the bottom centre, PartyCards.lua).
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
-- times the casting bar, filled and coloured as its nameplate is; its
-- level in the game's small circle at the bar's left (coloured by how hard
-- it is, a skull when too high to say), what it is at the right (the
-- nameplate's elite / rare dragon) and in the border's tint; under it,
-- the quests it counts for (as its tooltip has them), then its casts
---------------------------------------------------------------------------
local SCALE = 1.5
local BAR_W, BAR_H = 214 * SCALE, 16 * SCALE
local NAME_H = 22
local CAST_H, CAST_GAP = 16, 4
local BADGE = 30
local NAMEPLATE_FILL = "nameplates-bar-fill"

local target = UnitButton("ImprovedForeverTargetBar", "target", BAR_W, NAME_H + BAR_H + CAST_GAP + CAST_H)
target:SetPoint("TOP", UIParent, "TOP", 0, -36)
target:Hide()

do
    local t = target
    t.name = Text(t, "GameFontNormalLarge")
    t.name:SetPoint("TOPLEFT")
    t.name:SetPoint("TOPRIGHT")
    t.name:SetHeight(NAME_H - 2)
    t.health = Bar(t, BAR_W, BAR_H, NAMEPLATE_FILL)
    t.health.box:SetPoint("TOP", 0, -NAME_H)

    -- (over the bar's ends: the level, the classification)
    local ends = CreateFrame("Frame", nil, t.health.box)
    ends:SetAllPoints()
    ends:SetFrameLevel(t.health:GetFrameLevel() + 4)
    t.classIcon = ends:CreateTexture(nil, "ARTWORK")
    t.classIcon:SetSize(BADGE + 6, BADGE + 4)
    t.classIcon:SetPoint("CENTER", t.health.box, "RIGHT", -2, 0)
    t.classIcon:Hide()
    t.badge = Atlas(ends, "OVERLAY", "UI-HUD-UnitFrame-SmallCircle", 1)
    t.badge:SetSize(BADGE, BADGE)
    t.badge:SetPoint("CENTER", t.health.box, "LEFT", 2, 0)
    t.level = Text(ends, "GameFontNormal")
    t.level:SetDrawLayer("OVERLAY", 2)
    t.level:SetPoint("CENTER", t.badge, "CENTER", 0, -0.5)
    t.skull = Atlas(ends, "OVERLAY", "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", 2)
    t.skull:SetPoint("CENTER", t.badge, "CENTER")
    t.skull:Hide()

    t.quest = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.quest:SetPoint("TOP", t.health.box, "BOTTOM", 0, -3)
    t.quest:SetWidth(BAR_W * 1.6)  -- (one line: room past the bar, cut with "..." past that)
    t.quest:SetJustifyH("CENTER")
    t.quest:SetWordWrap(false)
end

-- The quests the target counts for, as its tooltip lists them (the game's
-- tooltip data: a quest's title, then its objectives), on one line: each
-- quest's title (gold), its objectives after it (white, grey once done),
-- quests apart. Read whole or not at all (a line the game keeps secret:
-- none shown).
local TITLE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestTitle or 17
local OBJECTIVE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8
local QUEST_GAP, OBJECTIVE_GAP = "    ", "  "

local function QuestText(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return "" end
    local ok, text = pcall(function()
        local data = C_TooltipInfo.GetUnit(unit)
        local quests, current = {}, nil
        for _, line in ipairs(data and data.lines or {}) do
            if line.type == TITLE and line.leftText then
                current = { "|cffffd100" .. line.leftText .. ":|r" }
                quests[#quests + 1] = current
            elseif line.type == OBJECTIVE and line.leftText then
                if not current then
                    current = {}
                    quests[#quests + 1] = current
                end
                current[#current + 1] = (line.completed and "|cff808080" or "|cffffffff") .. line.leftText .. "|r"
            end
        end
        for i, quest in ipairs(quests) do
            quests[i] = table.concat(quest, OBJECTIVE_GAP)
        end
        return table.concat(quests, QUEST_GAP)
    end)
    return ok and text or ""
end

-- The health's colour, as the game's nameplate works it out
-- (CompactUnitFrame_UpdateHealthColor with the nameplates' options): grey
-- dead, a player by its class, light grey tapped by others, red fighting
-- you, a friendly player light blue, else its selection colour (hostile
-- red, neutral yellow, friendly green...). An answer that can't be read:
-- the next rule.
local function NameplateColor(unit)
    local player = Flag(UnitIsPlayer, unit)
    if Flag(UnitIsDead, unit) and not player then return 0.5, 0.5, 0.5 end
    if player then
        local ok, c = pcall(function()
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class]
            return color and { color.r, color.g, color.b }
        end)
        if ok and c then return c[1], c[2], c[3] end
    end
    if Flag(UnitIsTapDenied, unit) then return 0.9, 0.9, 0.9 end
    local friend = Flag(function(u) return UnitIsFriend("player", u) end, unit)
    local threat = Flag(function(u) return UnitThreatSituation("player", u) ~= nil end, unit)
    if threat and not friend then return 1, 0, 0 end
    if player and friend then return 0.667, 0.667, 1 end
    local ok, r, g, b = pcall(UnitSelectionColor, unit, true)
    if ok and r then return r, g, b end
    return 1, 0, 0
end

-- What it is: the nameplate's icon and the border's tint
local CLASSIFICATION = {
    worldboss = { icon = "nameplates-icon-elite-gold", tint = { 1, 0.6, 0.25 } },
    elite = { icon = "nameplates-icon-elite-gold", tint = { 1, 0.82, 0.35 } },
    rareelite = { icon = "nameplates-icon-elite-silver", tint = { 0.8, 0.88, 1 } },
    rare = { icon = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", tint = { 0.8, 0.88, 1 } },
}

local function Classification(unit)
    local ok, c = pcall(function() return CLASSIFICATION[UnitClassification(unit)] end)
    return ok and c or nil
end

-- Its level, coloured by how hard it is for you; a skull when it's too
-- high to say
local function Level(t, unit)
    local ok, level, r, g, b = pcall(function()
        local l = UnitLevel(unit)
        if not l or l <= 0 then return nil end
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(l)
        return l, color.r, color.g, color.b
    end)
    local skull = ok and not level
    t.skull:SetShown(skull)
    if ok and level then
        t.level:SetText(level)
        t.level:SetTextColor(r, g, b)
    else
        t.level:SetText("")
    end
end

function target:Refresh()
    local unit = self.unit
    if not UnitExists(unit) then return end
    Try(self.name.SetText, self.name, UnitName(unit))
    NameColor(self)
    FillHealth(self)
    self.health:SetStatusBarColor(NameplateColor(unit))
    Level(self, unit)
    self.quest:SetText(QuestText(unit))
    local c = Classification(unit)
    if c then
        self.classIcon:SetAtlas(c.icon)
        self.classIcon:Show()
        self.health.frame:SetVertexColor(c.tint[1], c.tint[2], c.tint[3])
    else
        self.classIcon:Hide()
        self.health.frame:SetVertexColor(1, 1, 1)
    end
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
-- (under the quests, when it has any)
cast.box:SetPoint("TOP", target.quest, "BOTTOM", 0, -CAST_GAP)
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
-- An avatar (the player's, a minion's or a party member's card,
-- PartyCards.lua): the unit's model in the game's tooltip border (its
-- bronze frame, its centre left out), its round portrait when it's too far
-- to be drawn, a strip along its top in its colour, its level in the
-- game's small circle at the top left. a.over: a frame over the model,
-- under the border (a card's band and bars go on it).
---------------------------------------------------------------------------
local AVATAR_INSET, STRIP_H, ZOOM = 4, 3, 0.45
local BRONZE = { 0.62, 0.5, 0.32 }     -- (the border's own, should the game's layout be missing)

-- The game's tooltip layout (NineSliceUtil, applied to our frame), its
-- centre left out; without it, thin bronze edges of ours
local function Border(frame)
    local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName
        and pcall(NineSliceUtil.ApplyLayoutByName, frame, "TooltipDefaultLayout")
    if ok and frame.TopEdge then
        if frame.Center then frame.Center:Hide() end
        return
    end
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
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
        return (l and l > 0) and tostring(l) or "??"
    end)
    a.level:SetText(ok and level or "")
end

-- A unit's class colour, or nil
local function ClassColor(unit)
    local ok, c = pcall(function()
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        return color and { color.r, color.g, color.b }
    end)
    return ok and c or nil
end

-- The events that change a model
local MODEL_EVENTS = { UNIT_MODEL_CHANGED = true, UNIT_PORTRAIT_UPDATE = true, GROUP_ROSTER_UPDATE = true,
    UNIT_PET = true, PLAYER_ENTERING_WORLD = true }

---------------------------------------------------------------------------
-- The player's bottom left, as the target's: its avatar on the left (as
-- big as the minion and party cards), then along its foot its name (a
-- combat mark before it) over its health, its power under it (the same
-- width, two thirds the height)
---------------------------------------------------------------------------
local POWER_H = 16
-- (the avatar the cards' size, PartyCards.lua; the bars along its foot)
local AVATAR_W, AVATAR_H = 78, 100
local AVATAR_GAP = 6
local PLAYER_X, PLAYER_Y = 20, 20
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.45, 0.45, 0.45 }
local player = UnitButton("ImprovedForeverPlayerFrame", "player", AVATAR_W + AVATAR_GAP + BAR_W, AVATAR_H)
player:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", PLAYER_X, PLAYER_Y)
player:Hide()

do
    local p = player
    p.avatar = Avatar(p, AVATAR_W, AVATAR_H)
    p.avatar:SetPoint("LEFT")
    local bars = CreateFrame("Frame", nil, p)
    bars:SetSize(BAR_W, NAME_H + BAR_H + 2 + POWER_H)
    bars:SetPoint("BOTTOMRIGHT")
    p.combat = Atlas(bars, "OVERLAY", "UI-HUD-UnitFrame-Player-CombatIcon")
    p.combat:SetPoint("TOPLEFT", 4, -3)
    p.name = Text(bars, "GameFontNormalLarge", "LEFT")
    p.name:SetHeight(NAME_H - 2)
    p.health = Bar(bars, BAR_W, BAR_H, HEALTH_FILL)
    p.health.box:SetPoint("TOP", 0, -NAME_H)
    p.power = Bar(bars, BAR_W, POWER_H, POWER_FILL .. "Mana")
    p.power.box:SetPoint("TOP", p.health.box, "BOTTOM", 0, -2)
    p.power.text:SetFontObject(_G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small or "TextStatusBarText")
end

function player:Refresh(event)
    local unit = self.unit
    AvatarUnit(self.avatar, unit, event == nil or MODEL_EVENTS[event])
    local dead = Flag(UnitIsDeadOrGhost, unit)
    AvatarLook(self.avatar, unit, dead and GREY or ClassColor(unit) or GOLD, dead)
    Try(self.name.SetText, self.name, UnitName(unit))
    NameColor(self)
    -- (the name after the combat mark while in a fight)
    local fighting = Flag(UnitAffectingCombat, unit)
    self.combat:SetShown(fighting)
    self.name:ClearAllPoints()
    self.name:SetPoint("TOPLEFT", fighting and 24 or 4, 0)
    self.name:SetPoint("TOPRIGHT", -4, 0)
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
    "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" })
Listen(target, { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_FACTION", "UNIT_LEVEL",
    "UNIT_CLASSIFICATION_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" },
    { "PLAYER_TARGET_CHANGED", "CVAR_UPDATE", "QUEST_LOG_UPDATE" })

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
UF.MODEL_EVENTS, UF.GOLD, UF.GREY = MODEL_EVENTS, GOLD, GREY

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
