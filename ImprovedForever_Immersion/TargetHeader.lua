-- The target in the header's place under the top (HeaderSlot.lua), in its
-- look: its health is the rule, a line out from the middle both ways in
-- its nameplate's colour over a dark track; on it a diamond (the spell
-- diamonds' tile) with its portrait, its level under the diamond's foot
-- (coloured by how hard it is, a skull when too high to say), what it is
-- beside it (the nameplate's elite / rare dragon) and in the diamond's
-- rim; under them its name big, the quests it counts for (as its tooltip
-- has them), else what more there is to say of it (a player's guild, race
-- and class; an NPC's title and kind), then its casts as a thin line. In
-- a fight only the fight's: the name smaller, the casts. An enemy out of
-- your reach (your longest-reaching harmful spell, PlayerCast.lua): its
-- portrait grey, its line faint.
-- It comes in when you target something and goes when you don't (a moment
-- after, so a quick change doesn't strobe; one target to another changes in
-- place): the line grows out from the middle, the diamond pops up, the
-- words rise in; going, the same backwards.
-- The secure button that takes the clicks is UnitFrames.lua's (in the
-- same place, over the diamond and the name); this is a frame of its own,
-- never anchored to it. Health and casts can be secret: only handed to the
-- widgets, never compared.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot
local UF = IN.UnitFrames

local TH = {}
IN.TargetHeader = TH

local Try, Flag, Secret = UF.Try, UF.Flag, UF.Secret

local TILE = 30                         -- (the diamond's tile)
local LINE_H = 3                        -- (the health line)
local TRACK = { 0, 0, 0, 0.5 }
local NAME_GAP = HS.NAME_GAP + 10       -- (past the level under the diamond's foot)
local BADGE = 22
local QUEST_W = HS.RULE_W * 2.2
local CAST_W, CAST_H, CAST_GAP = HS.RULE_W, 4, 8
local LINGER = 0.3                      -- (seconds held after the target's gone)
local SLIDE = 10                        -- (the words rise from this far down)

---------------------------------------------------------------------------
-- The frame, in the header's place
---------------------------------------------------------------------------
local look = CreateFrame("Frame", "ImprovedForeverTargetHeader", UIParent)
look:SetSize(2 * HS.RULE_W, 140)
look:SetFrameStrata("LOW")
look:EnableMouse(false)
look:SetPoint("CENTER", HS.Origin, "CENTER")
look:Hide()

-- (the health: two halves filling out from the diamond's sides, each over
-- its own dark track; PlayerCast.lua's line)
local tile = HS.Tile(look, TILE)
local radius = tile.across / 2 * 0.9
local halves = {}
for i, reverse in ipairs({ true, false }) do
    local side = i == 1 and -1 or 1
    local holder = CreateFrame("Frame", nil, look)
    holder:SetHeight(LINE_H)
    holder:SetPoint(side < 0 and "RIGHT" or "LEFT", look, "CENTER", side * radius, 0)
    local track = holder:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetReverseFill(reverse)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    halves[i] = { holder = holder, bar = bar }
end
tile:SetFrameLevel(halves[1].bar:GetFrameLevel() + 4)
-- (its raid marker over the diamond's top left: skull, cross, moon...)

local function LineWidth(k)
    for _, h in ipairs(halves) do h.holder:SetWidth(math.max(1, (HS.RULE_W - radius) * k)) end
end
LineWidth(1)

-- (its level, under the diamond's foot; what it is, beside the diamond)
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
skull:Hide()
local classIcon = tile:CreateTexture(nil, "OVERLAY", nil, 2)
classIcon:SetSize(28, 26)
classIcon:SetPoint("LEFT", tile, "CENTER", tile.across / 2 - 6, 4)
classIcon:Hide()

-- (the words)
local name = HS.Text(look, HS.FONT, HS.NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
name:SetWidth(2 * HS.RULE_W)
-- (beside the name: just left of its first letter, whatever the name's length)
-- Our markers (tools/make_raid_marks.py: cut shapes in the quest arrow's look, on a sheet laid out as the
-- game's own, so its SetRaidTargetIconTexture picks one), right of the name
local MARK_SIZE = 26
local mark = look:CreateTexture(nil, "OVERLAY", nil, 7)
mark:SetTexture(IF.TEX .. "ic_raid_marks")
mark:SetSize(MARK_SIZE, MARK_SIZE)
mark:Hide()
local function Mark(unit)
    -- (the game answers a secret number: handed to its setter, never compared; none: nil, refused)
    local ok, index = pcall(GetRaidTargetIndex, unit)
    local set = ok and SetRaidTargetIconTexture and pcall(SetRaidTargetIconTexture, mark, index)
    mark:SetShown(set and true or false)
    if set then
        local width = (name:GetStringWidth() or 0) * (name.GetTextScale and name:GetTextScale() or 1)
        mark:ClearAllPoints()
        mark:SetPoint("LEFT", name, "CENTER", width / 2 + 7, 0)
    end
end
local markEvents = CreateFrame("Frame")
markEvents:RegisterEvent("RAID_TARGET_UPDATE")
markEvents:SetScript("OnEvent", function()
    if look:IsShown() and UnitExists("target") then Mark("target") end
end)
local quest = look:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
quest:SetPoint("TOP", name, "BOTTOM", 0, -4)
quest:SetWidth(QUEST_W)       -- (one line, cut with "..." past that)
quest:SetJustifyH("CENTER")
quest:SetWordWrap(false)
quest:SetShadowOffset(1, -1)
quest:SetShadowColor(0, 0, 0, 1)

---------------------------------------------------------------------------
-- What it shows: the game's say on the target
---------------------------------------------------------------------------
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
            if Secret(line.type) or Secret(line.leftText) or Secret(line.completed) then return "" end
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
        for i, q in ipairs(quests) do
            quests[i] = table.concat(q, OBJECTIVE_GAP)
        end
        return table.concat(quests, QUEST_GAP)
    end)
    return ok and text or ""
end

-- What more there is to say of it, when it counts for no quest: a
-- player's guild, race and class (in its colour); an NPC's title (as its
-- tooltip has it, "<Innkeeper>") and its kind (Humanoid, Beast...). Each
-- part left out when the game keeps it secret.
local DOT = "  |cff808080\194\183|r  "

local function Words(v)
    return type(v) == "string" and not Secret(v) and v ~= "" and v or nil
end

local function Extras(unit)
    local parts = {}
    local function Add(text, color)
        if text then parts[#parts + 1] = (color or "|cffd8d8d8") .. text .. "|r" end
    end
    if Flag(UnitIsPlayer, unit) then
        local ok, guild = pcall(GetGuildInfo, unit)
        Add(ok and Words(guild) and ("<" .. guild .. ">"))
        local okR, race = pcall(UnitRace, unit)
        Add(okR and Words(race))
        local okC, className, class = pcall(UnitClass, unit)
        local color = okC and not Secret(class) and class and RAID_CLASS_COLORS[class]
        Add(okC and Words(className), color and color.colorStr and ("|c" .. color.colorStr) or nil)
    else
        local ok, title = pcall(function()
            local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
            for i = 2, math.min(3, data and data.lines and #data.lines or 0) do
                local text = Words(data.lines[i].leftText)
                if text and text:match("^<.+>$") then return text end
            end
        end)
        Add(ok and title or nil)
        local okT, kind = pcall(UnitCreatureType, unit)
        Add(okT and Words(kind))
    end
    return table.concat(parts, DOT)
end

-- The health's colour, as the game's nameplate works it out
-- (CompactUnitFrame_UpdateHealthColor with the nameplates' options): grey
-- dead, a player by its class, light grey tapped by others, red fighting
-- you, a friendly player light blue, else its selection colour (hostile
-- red, neutral yellow, friendly green...). An answer that can't be read:
-- the next rule.
local function ClassColorOf(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if not ok or Secret(class) or not class then return nil end
    local color = RAID_CLASS_COLORS[class]
    return color and { color.r, color.g, color.b }
end

-- (noClass: a player in the game's colours of it, not its class's)
local function NameplateColor(unit, noClass)
    local player = Flag(UnitIsPlayer, unit)
    if Flag(UnitIsDead, unit) and not player then return 0.5, 0.5, 0.5 end
    if player and not noClass then
        local c = ClassColorOf(unit)
        if c then return c[1], c[2], c[3] end
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

TH.NameplateColor = NameplateColor

-- What it is: the nameplate's icon and the diamond's rim
local CLASSIFICATION = {
    worldboss = { icon = "nameplates-icon-elite-gold", tint = { 1, 0.6, 0.25 } },
    elite = { icon = "nameplates-icon-elite-gold", tint = { 1, 0.82, 0.35 } },
    rareelite = { icon = "nameplates-icon-elite-silver", tint = { 0.8, 0.88, 1 } },
    rare = { icon = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", tint = { 0.8, 0.88, 1 } },
}

local function Classification(unit)
    local ok, kind = pcall(UnitClassification, unit)
    if not ok or Secret(kind) or not kind then return nil end
    return CLASSIFICATION[kind]
end

-- Its level, coloured by how hard it is for you; a skull when it's too
-- high to say
local function Level(unit)
    local ok, l, r, g, b = pcall(function()
        local v = UnitLevel(unit)
        if Secret(v) then error("secret") end
        if not v or v <= 0 then return nil end
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(v)
        return v, color.r, color.g, color.b
    end)
    skull:SetShown(ok and not l)
    if ok and l then
        level:SetText(l)
        level:SetTextColor(r, g, b)
    else
        level:SetText("")
    end
end

-- Its health on the line (both halves the same: out from the middle)
local function FillHealth(unit)
    local value, max = UnitHealth(unit), UnitHealthMax(unit)
    for _, h in ipairs(halves) do
        if not Try(h.bar.SetMinMaxValues, h.bar, 0, max) or not Try(h.bar.SetValue, h.bar, value) then
            h.bar:SetMinMaxValues(0, 1)
            h.bar:SetValue(0)
        end
    end
end

-- (the tour's stand-in, TH.Demo: the header drawn for you with another's
-- name, colour, level, health and quest, in the header's place as a target)
local demo

local function Refresh(button)
    local unit = demo and "player" or button.unit
    if not UnitExists(unit) then return end
    Try(name.SetText, name, UnitName(unit))
    local dead = Flag(UnitIsDeadOrGhost, unit)
    if dead then name:SetTextColor(0.5, 0.5, 0.5) else name:SetTextColor(HS.GOLD[1], HS.GOLD[2], HS.GOLD[3]) end
    FillHealth(unit)
    local r, g, b = NameplateColor(unit)
    for _, h in ipairs(halves) do h.bar:SetStatusBarColor(r, g, b) end
    Level(unit)
    if demo then mark:Hide() else Mark(unit) end
    local quests = QuestText(unit)
    quest:SetText(quests ~= "" and quests or Extras(unit))
    SetPortraitTexture(tile.icon, unit)
    tile.icon:SetSize(tile.across * 0.94, tile.across * 0.94)
    if demo then
        name:SetText(demo.name)
        for _, h in ipairs(halves) do
            h.bar:SetMinMaxValues(0, 1)
            h.bar:SetValue(demo.health)
            h.bar:SetStatusBarColor(demo.color[1], demo.color[2], demo.color[3])
        end
        skull:Hide()
        local lv = UnitLevel("player") + (demo.levelGap or 0)
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(lv)
        level:SetText(lv)
        level:SetTextColor(color.r, color.g, color.b)
        quest:SetText(demo.quest)
        classIcon:Hide()
        tile.border:SetVertexColor(1, 1, 1)
        return
    end
    local c = Classification(unit)
    if c then
        classIcon:SetAtlas(c.icon)
        classIcon:Show()
        tile.border:SetVertexColor(c.tint[1], c.tint[2], c.tint[3])
    else
        classIcon:Hide()
        tile.border:SetVertexColor(1, 1, 1)
    end
end

-- (the secure button's events refresh it: UnitFrames.lua's Listen)
UF.target.Refresh = Refresh

---------------------------------------------------------------------------
-- Its casts, a thin line under the quests: the casting bar's own fills (a
-- cast yellow, a channel green, grey while it can't be interrupted, red
-- when interrupted), the spell's icon at its left, its name under it.
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

local castBox = CreateFrame("Frame", nil, look)
castBox:SetSize(CAST_W, CAST_H)
castBox:SetPoint("TOP", quest, "BOTTOM", 0, -CAST_GAP)
castBox:Hide()
-- (TargetAuras.lua hangs the target's buffs and debuffs under these)
TH.look, TH.castBox = look, castBox
local cast = CreateFrame("StatusBar", nil, castBox)
cast:SetAllPoints()
cast:SetStatusBarTexture(FILL.cast)
cast:SetMinMaxValues(0, 1)
cast.box = castBox
cast.bg = castBox:CreateTexture(nil, "BACKGROUND")
cast.bg:SetAllPoints()
cast.bg:SetAtlas(FILL.empty)
cast.text = castBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cast.text:SetPoint("BOTTOM", tile, "TOP", 0, 2)     -- (over the diamond: the buffs sit close under the race / class line)
-- The cast as the diamond's own edges (as the player's cast bar, PlayerCast.lua): the spell's icon in the
-- avatar's diamond, its border lit from the top and bottom points to the sides as the cast goes. The long
-- bar under the name is gone (kept only as the cast's value and an anchor for the name's text and the auras).
cast:SetAlpha(0)
cast.bg:Hide()
cast.icon = tile:CreateTexture(nil, "OVERLAY", nil, 1)
cast.icon:SetPoint("CENTER")
cast.icon:SetSize(tile.across * 0.94, tile.across * 0.94)
cast.icon:AddMaskTexture(tile.mask)
cast.icon:Hide()
local arcs = CreateFrame("Frame", nil, look)
arcs:SetSize(1, 1)
arcs:SetPoint("CENTER", tile, "CENTER")
arcs:SetFrameLevel(tile:GetFrameLevel() + 10)
local arcLines, arcGlows = {}, {}
for i = 1, 4 do
    local glow = arcs:CreateLine(nil, "OVERLAY", nil, 1)
    glow:SetThickness(4)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetBlendMode("ADD")
    local edge = arcs:CreateLine(nil, "OVERLAY", nil, 2)
    edge:SetThickness(2.5)
    edge:SetTexture("Interface\\Buttons\\WHITE8x8")
    edge:SetBlendMode("ADD")
    arcLines[i], arcGlows[i] = edge, glow
end
local CAST_COLORS = { cast = { 1, 0.8, 0.2 }, channel = { 0.3, 0.9, 0.4 }, shield = { 0.6, 0.6, 0.6 },
    interrupted = { 1, 0.2, 0.2 } }
local QUARTERS = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
-- (amount 0 to 1 of the way along each edge, from the top and bottom points to the sides)
local function Arcs(amount, color)
    local r = tile.across / 2 * 0.98
    for i, q in ipairs(QUARTERS) do
        local edge, glow = arcLines[i], arcGlows[i]
        if amount <= 0 then
            edge:Hide()
            glow:Hide()
        else
            local x, y = q[1] * amount, q[2] * (1 - amount)
            for _, l in ipairs({ edge, glow }) do
                l:SetStartPoint("CENTER", arcs, 0, q[2] * r)
                l:SetEndPoint("CENTER", arcs, x * r, y * r)
                l:Show()
            end
            edge:SetVertexColor(color[1], color[2], color[3], 1)
            glow:SetVertexColor(color[1], color[2], color[3], 0.35)
        end
    end
end
local function ArcsOff()
    Arcs(0, CAST_COLORS.cast)
    cast.icon:Hide()
end
-- (the grey of a cast that can't be interrupted, over the fill)
cast.shield = cast:CreateTexture(nil, "ARTWORK", nil, 1)
cast.shield:SetAtlas(FILL.shield)
cast.shield:SetAlpha(0)

local function Present(v)
    return Secret(v) or v ~= nil
end

-- What the target casts now: kind ("cast" / "channel") and its info
local function Casting(unit)
    local cname, text, texture, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(unit)
    if Present(cname) then return "cast", text, texture, startMs, endMs, notInterruptible end
    local chname, ctext, ctexture, cstart, cend, _, cnot = UnitChannelInfo(unit)
    if Present(chname) then return "channel", ctext, ctexture, cstart, cend, cnot end
end

TH.Casting = Casting
TH.CAST_COLORS = CAST_COLORS

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
    self.startMs = not Secret(startMs) and type(startMs) == "number" and startMs or nil
    -- (can't be interrupted: secret in a fight, never compared (a compare of a secret taints, and the
    -- loot window's close then gets SetPreferredGamepadInteractTarget forbidden); the shield shows it)
    local shield = not Secret(notInterruptible) and notInterruptible == true
    self.color = CAST_COLORS[shield and "shield" or kind] or CAST_COLORS.cast
    Try(self.text.SetText, self.text, text)
    self.text:Show()
    if not Try(self.icon.SetTexture, self.icon, texture) then self.icon:SetTexture(nil) end
    self.icon:Show()
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
    self.color = CAST_COLORS.interrupted
    Arcs(1, self.color)
    self.box:Show()
end

function cast:Stop()
    self.kind = nil
    self.holdUntil = nil
    self.box:Hide()
    ArcsOff()
end

-- The cast the target has now shown, or none
function cast:Check()
    if not UnitExists("target") then return self:Stop() end
    local kind, text, texture, startMs, endMs, notInterruptible = Casting("target")
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
        -- (plain times: the edges as far as the cast has gone (a channel's draining); secret ones: all lit)
        local amount = 1
        if self.startMs and self.endMs and self.endMs > self.startMs then
            amount = math.min(1, math.max(0, (now * 1000 - self.startMs) / (self.endMs - self.startMs)))
            if self.kind == "channel" then amount = 1 - amount end
        end
        Arcs(amount, self.color or CAST_COLORS.cast)
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
        if not Casting("target") then cast:Interrupted() end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        cast.shield:SetAlpha(0)
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if cast.kind then cast.shield:SetAlpha(1) end
    else
        cast:Check()
    end
end)

---------------------------------------------------------------------------
-- Your reach: an enemy out of range of your longest-reaching harmful spell
-- (PlayerCast.lua's pick) greys its portrait and dims its line. The range
-- check's answer can be secret (in a fight): handed to the widgets as it
-- is (SetVertexColorFromBoolean, SetAlphaFromBoolean), never compared.
---------------------------------------------------------------------------
local RANGE_CHECK, OUT_ALPHA = 0.1, 0.35
local OUT_GREY = 0.4
local WHITE_C, GREY_C
local rangeSince = 0

local function Reach(inRange)
    local icon = tile.icon
    if inRange == nil then
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1)
        for _, h in ipairs(halves) do h.holder:SetAlpha(1) end
        return
    end
    if Secret(inRange) then
        WHITE_C = WHITE_C or CreateColor(1, 1, 1, 1)
        GREY_C = GREY_C or CreateColor(OUT_GREY, OUT_GREY, OUT_GREY, 1)
        icon:SetDesaturated(false)
        if not Try(icon.SetVertexColorFromBoolean, icon, inRange, WHITE_C, GREY_C) then icon:SetVertexColor(1, 1, 1) end
        for _, h in ipairs(halves) do
            if not Try(h.holder.SetAlphaFromBoolean, h.holder, inRange, 1, OUT_ALPHA) then h.holder:SetAlpha(1) end
        end
        return
    end
    local out = inRange == false
    icon:SetDesaturated(out)
    local c = out and OUT_GREY or 1
    icon:SetVertexColor(c, c, c)
    for _, h in ipairs(halves) do h.holder:SetAlpha(out and OUT_ALPHA or 1) end
end

-- (an enemy targeted, alive)
local function Enemy()
    local ok, yes = pcall(function()
        if not UnitExists("target") then return false end
        local attack, dead = UnitCanAttack("player", "target"), UnitIsDeadOrGhost("target")
        if Secret(attack) or Secret(dead) then return true end
        return attack and not dead
    end)
    return ok and yes or false
end

local function CheckRange(elapsed)
    rangeSince = rangeSince + (elapsed or 0)
    if rangeSince < RANGE_CHECK then return end
    rangeSince = 0
    local PC = IN.PlayerCast
    local spell = IN.Settings().castRange ~= false and PC and PC.RangeSpell and PC.RangeSpell()
    if not (spell and Enemy()) then return Reach(nil) end
    local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, "target")
    -- (false is an answer: out of reach; only an error is none)
    if not ok then inRange = nil end
    Reach(inRange)
end

-- /if rangeprobe: what the range check reads now
function TH.RangeProbe()
    local PC = IN.PlayerCast
    local spell = PC and PC.RangeSpell and PC.RangeSpell()
    local name = spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    local ok, inRange = pcall(C_Spell.IsSpellInRange, spell or 0, "target")
    local shown = not ok and ("error " .. tostring(inRange)) or Secret(inRange) and "<hidden>" or tostring(inRange)
    IF.Print(("Target range: spell %s (%s), enemy %s, setting %s, in range %s"):format(tostring(spell),
        tostring(name), tostring(Enemy()), tostring(IN.Settings().castRange), shown))
end

---------------------------------------------------------------------------
-- In the header's place while there's a target (and a moment after), the
-- setting on, out of Edit Mode; drawn from its presence
---------------------------------------------------------------------------
local lostAt

local function Wants()
    if demo then
        lostAt = nil
        return true
    end
    local s = IN.Settings()
    if not s.target or UF.EditMode() then return false end
    if UnitExists("target") then
        lostAt = nil
        return true
    end
    lostAt = lostAt or GetTime()
    return GetTime() - lostAt < LINGER
end

HS.Add("target", 2, { wants = Wants, rule = function() return false end })

local Ease, Pop = HS.Ease, HS.Pop
local drawn, drawnCalm
-- (the name always at the size it has in a fight; in a fight the quests
-- and the rest go too (the casts stay), eased)
local CALM_NAME, CALM_SPEED = 0.6, 4
local calm = 0

local function NameScale(k)
    if name.SetTextScale then
        name:SetTextScale(k)
    else
        name:SetFont(HS.FONT, HS.NAME_SIZE * k, "")
    end
end

local function Draw(elapsed)
    local fight = IF.InCombat() and 1 or 0
    calm = calm + (fight - calm) * math.min(1, (elapsed or 0) * CALM_SPEED)
    if math.abs(calm - fight) < 0.01 then calm = fight end
    local p = HS.Presence("target")
    if p <= 0 then
        if look:IsShown() then look:Hide() end
        drawn = nil
        return
    end
    if not look:IsShown() then
        look:Show()
        Refresh(UF.target)
    end
    CheckRange(elapsed)
    if p == drawn and calm == drawnCalm then return end
    drawn, drawnCalm = p, calm
    LineWidth(Ease(p, 0, 0.6))
    local come = Ease(p, 0.15, 0.75)
    tile:SetScale(math.max(0.01, come < 1 and Pop(come) or 1))
    tile:SetAlpha(come)
    local words = Ease(p, 0.4, 1)
    name:ClearAllPoints()
    name:SetPoint("TOP", look, "CENTER", 0, -NAME_GAP - SLIDE * (1 - words))
    NameScale(CALM_NAME)
    name:SetAlpha(words)
    castBox:SetAlpha(words)
    quest:SetAlpha(words * (1 - calm))
    quest:SetShown(calm < 0.99)
    -- (the casts up under the name once the quests are gone)
    castBox:ClearAllPoints()
    castBox:SetPoint("TOP", calm < 0.5 and quest or name, "BOTTOM", 0, -CAST_GAP)
end

-- /if targetcast [channel|shield|interrupt]: a made-up cast on the target header (have a target), 12 seconds
IF.AddCommand("targetcast", function(args)
    local kind = args and args[1] or "cast"
    local now = GetTime() * 1000
    if kind == "interrupt" then
        cast:Start("cast", "Frostbolt", 135846, now, now + 1500, false)
        C_Timer.After(1, function() cast:Interrupted() end)
    else
        cast:Start(kind == "channel" and "channel" or "cast", kind == "channel" and "Arcane Missiles" or "Fireball",
            kind == "channel" and 136096 or 135812, now, now + 12000, kind == "shield")
    end
    C_Timer.After(12, function() cast:Stop() end)
end, "[channel|shield|interrupt]: a made-up cast on the target header (have a target), 12 seconds")

-- The tour's stand-in target (Onboarding.lua): "friend", "enemy" or nil to
-- end it
local DEMOS = {
    friend = { name = "Stormwind Guard", color = { 0.1, 0.9, 0.1 }, health = 1, levelGap = 0,
        quest = "<Guard>  |cff808080\194\183|r  Human" },
    enemy = { name = "Defias Bandit", color = { 1, 0.1, 0.1 }, health = 0.6, levelGap = 1,
        quest = "|cffffd100The Defias Brotherhood:|r |cffffffff4/8 Defias Bandit slain|r" },
}

function TH.Demo(kind)
    demo = kind and DEMOS[kind] or nil
    if look:IsShown() then Refresh(UF.target) end
end

-- (drawn each frame; one error said once, then no more)
local broken
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Draw, elapsed)
    if not ok then
        broken = true
        look:Hide()
        IF.Print("Immersion: the target header stopped after an error: " .. tostring(err))
    end
end)
