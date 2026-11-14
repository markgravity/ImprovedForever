-- The nameplates in the module's look: the name in gold (the header's
-- font), under it a thin line in the nameplate's colour over a dark
-- track, the level in the small circle at the line's end;
-- (your target's full size, the others a little smaller and softer). Each is a frame of
-- ours anchored to the game's plate (a plain anchor: probe verified
-- taint-free; the plate is never measured or changed), and the game's own
-- look of it (its UnitFrame) drawn at alpha 0 by an animation of ours
-- (IF.Focus.Fade). Plates that only carry widgets and the soft-interact
-- object (the fishing bobber) stay the game's. Health can be secret:
-- handed to the bar, never compared.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot
local UF = IN.UnitFrames
local TH = IN.TargetHeader

local Try, Flag, Secret = UF.Try, UF.Flag, UF.Secret

local W, LINE_H, BADGE = 110, 4, 20
local TRACK = { 0, 0, 0, 0.55 }
local NAME_SIZE = 17
local TITLE_SIZE = 12
local TITLE_COLOR = { 0.85, 0.82, 0.7 }   -- (the NPC's job, <Warrior Trainer>: softer than the name)
local STEP = 0.1
local OTHER_SCALE, OTHER_ALPHA = 0.8, 0.6
local OTHER_MUTE, OTHER_DIM = 0.55, 0.75   -- (a non-target's colours: this much toward grey, then this bright)

-- A non-target's colour, muted so your target's plate stands out
local function Mute(r, g, b)
    local grey = 0.3 * r + 0.59 * g + 0.11 * b
    local k = 1 - OTHER_MUTE
    return (grey + (r - grey) * k) * OTHER_DIM, (grey + (g - grey) * k) * OTHER_DIM, (grey + (b - grey) * k) * OTHER_DIM
end
local BAR_GAP = 7                    -- (between the health line and what's over it)
local PLATE_DROP = 34                -- (ours sits this far under the game's plate centre: closer to the head)
local FADE_SPEED = 8                    -- (how fast alpha and size ease)
-- (the cast bar under the line: its height, the gap over it, its spell name's size; the room it
-- takes, the debuffs going under it while it shows)
local CAST_H, CAST_GAP, CAST_TEXT = 4, 4, 10
local CAST_AREA = CAST_GAP + CAST_H + 2 + CAST_TEXT + 2
local CAST_HOLD = 0.6                   -- (an interrupted cast shown in red this long)

-- (/if platecast: a made-up cast on every plate in play, looping (N.Demo below); nil: the real ones)
local demo
local function Casting(unit)
    if demo then
        if not demo.casting then return nil end
        return demo[1], demo[2], demo[3], demo.started, demo.started + demo[4], demo[5]
    end
    return TH.Casting(unit)
end

---------------------------------------------------------------------------
-- One plate of ours (pooled)
---------------------------------------------------------------------------
local pool = {}

local function Build()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(W, LINE_H)
    p:SetFrameStrata("LOW")
    p:EnableMouse(false)
    p:Hide()
    local track = p:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    p.track = track
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    p.bar = CreateFrame("StatusBar", nil, p)
    p.bar:SetAllPoints()
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    p.bar:SetMinMaxValues(0, 1)
    p.bar:SetValue(1)
    p.name = HS.Text(p, HS.FONT, NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
    p.name:SetPoint("BOTTOM", p, "TOP", 0, BAR_GAP)
    p.name:SetWidth(W * 2.4)
    p.title = HS.Text(p, HS.FONT, TITLE_SIZE, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
    p.title:SetWidth(W * 2.4)
    local badge = p:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("LEFT", p, "RIGHT", 2, 0)
    p.badge = badge
    p.level = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.level:SetDrawLayer("OVERLAY", 3)
    p.level:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
    p.skull = p:CreateTexture(nil, "OVERLAY", nil, 4)
    p.skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
    p.skull:SetPoint("CENTER", badge, "CENTER")
    p.skull:Hide()
    -- (its raid marker, as the game gives them: skull, cross, moon...; left of the line, the badge's twin)
    p.mark = p:CreateTexture(nil, "OVERLAY", nil, 5)
    p.mark:SetTexture(IF.TEX .. "ic_raid_marks")
    p.mark:SetSize(BADGE - 4, BADGE - 4)
    p.mark:Hide()
    -- (your combo points on your target's plate: five small gems in a row over its name; the same gems
    -- as the target header's, tools/make_combo_gem.py)
    p.combo = {}
    for i = 1, 5 do
        local g = p:CreateTexture(nil, "OVERLAY", nil, 6)
        g:SetTexture(IF.TEX .. "ic_combo_gem")
        g:SetTexCoord(0, 0.5, 0, 1)
        g:SetSize(10, 10)
        g:Hide()
        p.combo[i] = g
    end
    -- (its cast: a bar of ours, the times handed to it (secret in a fight), never compared)
    local cb = CreateFrame("StatusBar", nil, p)
    cb:SetSize(W, CAST_H)
    cb:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    cb.bg = cb:CreateTexture(nil, "BACKGROUND")
    cb.bg:SetAllPoints()
    cb.shield = cb:CreateTexture(nil, "ARTWORK", nil, 1)
    cb.shield:SetAllPoints()
    cb.shield:SetColorTexture(0.6, 0.6, 0.6, 1)
    cb.shield:SetAlpha(0)
    -- (the spell's icon round, in the level badge's circle: that badge's twin on the other side)
    cb.ring = cb:CreateTexture(nil, "OVERLAY", nil, 1)
    cb.ring:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    cb.ring:SetSize(BADGE, BADGE)
    cb.ring:SetPoint("RIGHT", cb, "LEFT", -2, 0)
    cb.icon = cb:CreateTexture(nil, "OVERLAY", nil, 2)
    cb.icon:SetSize(BADGE * 0.7, BADGE * 0.7)
    cb.icon:SetPoint("CENTER", cb.ring, "CENTER", 0, 0)
    local mask = cb:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(cb.icon)
    cb.icon:AddMaskTexture(mask)
    cb.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.text:SetFont(STANDARD_TEXT_FONT, CAST_TEXT, "")
    cb.text:SetShadowOffset(1, -1)
    cb.text:SetPoint("TOP", cb, "BOTTOM", 0, -2)
    cb.text:SetWidth(W * 1.6)
    cb.text:SetWordWrap(false)
    cb:Hide()
    cb:HookScript("OnShow", function() cb.text:Show() end)
    cb:HookScript("OnHide", function() cb.text:Hide() end)
    cb.text:Hide()
    p.cast = cb
    return p
end

-- What's under the line: the cast bar, then the debuffs (under the cast while it shows)
local function PlaceBelow(p)
    local drop = p.auraDrop or -3
    p.cast:ClearAllPoints()
    p.cast:SetPoint("TOP", p, "BOTTOM", 0, drop - CAST_GAP + 3)
    if p.auras then
        p.auras:ClearAllPoints()
        p.auras:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, drop - (p.cast:IsShown() and CAST_AREA or 0))
    end
end

local function Same(other)
    return function(unit) return UnitIsUnit(unit, other) end
end
local IsTarget, IsSoft = Same("target"), Same("softinteract")

-- Your debuffs on it, under the line: the game's aura container (filled
-- by the game itself, so it reads them in a fight too), one per plate of
-- ours, the unit handed to it.
local DEBUFF_SIZE, DEBUFF_MAX, DEBUFF_GAP = 16, 5, 2

local function StyleDebuff(b)
    b:SetSize(DEBUFF_SIZE, DEBUFF_SIZE)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    local time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    time:SetPoint("TOP", b, "BOTTOM", 0, -1)
    pcall(b.SetIcon, b, icon)
    pcall(b.SetApplicationCount, b, count)
    pcall(b.SetDurationText, b, time)
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(DEBUFF_SIZE * 1.2, DEBUFF_SIZE * 1.2)
    pcall(b.AddDispelTypeTexture, b, border, {
        style = styles and styles.Border or 0,
        showWhenHarmful = true, showWithoutDispelType = true,
    })
end

-- (nil: this client has none)
local function AuraList(p)
    if p.auras ~= nil then return p.auras or nil end
    p.auras = false
    if not (AuraContainerSortMethod and AuraContainerSortDirection) then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, p, "CustomAuraContainerTemplate")
    if not (ok and c) then return nil end
    pcall(c.AddAuraGroup, c, "debuffs", "HARMFUL|PLAYER", {
        maxFrameCount = DEBUFF_MAX,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        layout = { elementSpacing = DEBUFF_GAP, groupSpacing = 0, elementWidth = DEBUFF_SIZE, elementHeight = DEBUFF_SIZE },
        initializeFrame = StyleDebuff,
    })
    c:Hide()
    p.auras = c
    PlaceBelow(p)
    return c
end

-- (shown for the unit, or hidden: the setting off, or none)
local function Auras(p, unit)
    local on = unit and IN.Settings().nameplateDebuffs ~= false
    local c = (on or p.auras) and AuraList(p)
    if not c then return end
    if on then pcall(c.SetUnit, c, unit) end
    c:SetShown(on and true or false)
    pcall(c.SetEnabled, c, on and true or false)
end

local function Level(p, unit)
    local ok, l, r, g, b = pcall(function()
        local v = UnitLevel(unit)
        if Secret(v) then error("secret") end
        if not v or v <= 0 then return nil end
        -- (a friend's level in plain gold: the difficulty colour is for what you fight)
        if not UnitCanAttack("player", unit) then return v, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3] end
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(v)
        return v, color.r, color.g, color.b
    end)
    p.skull:SetShown(ok and not l)
    if ok and l then
        p.level:SetText(l)
        p.level:SetTextColor(r, g, b)
    else
        p.level:SetText("")
    end
end

-- The raid marker on a plate (the index can be secret in a fight: handed to the texture, never compared)
local function Mark(p, unit)
    -- (the game answers a secret number here: handed to its own setter, never compared; none: nil, which
    -- the setter refuses)
    local ok, index = pcall(GetRaidTargetIndex, unit)
    local set = ok and SetRaidTargetIconTexture and pcall(SetRaidTargetIconTexture, p.mark, index)
    p.mark:SetShown(set and true or false)
    if set then
        local width = p.name:GetStringWidth() or 0
        p.mark:ClearAllPoints()
        p.mark:SetPoint("LEFT", p.name, "CENTER", width / 2 + 9, 0)
    end
end

-- The combo gems over a plate's name: only on your target's, as many as you have
local function Combo(p, unit)
    local n = unit and UnitIsUnit(unit, "target") and IN.ComboCount and IN.ComboCount() or 0
    if p.comboN == n then return end
    p.comboN = n
    for i = 1, 5 do
        local g = p.combo[i]
        if i <= n then
            g:ClearAllPoints()
            g:SetPoint("BOTTOM", p.name, "TOP", (i - 3) * 16, 3)
            g:Show()
        else
            g:Hide()
        end
    end
end

-- (drawn at its current alpha and size; none left: not shown)
local function Draw(p)
    local a = p.alpha * (p.seen or 1)
    p:SetScale(math.max(0.01, p.scale * (p.size or 1)))
    p:SetAlpha(a)
    p:SetShown(a > 0.01)
end

-- The name's font and size, from the settings (N.FONTS: the Interface tab's
-- choices); the game's standard font when a file can't be set
local N = {}
IN.Nameplates = N

N.FONTS = {
    { key = "morpheus", name = "Morpheus", file = HS.FONT },
    { key = "friz", name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "arial", name = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
    { key = "skurri", name = "Skurri", file = "Fonts\\skurri.ttf" },
}
N.SIZE_MIN, N.SIZE_MAX, N.SIZE_DEFAULT = 8, 24, NAME_SIZE

local function NameFont()
    local s = IN.Settings()
    local file = HS.FONT
    for _, f in ipairs(N.FONTS) do
        if f.key == s.nameplateFont then file = f.file end
    end
    -- (the choices have Latin letters only, bar Arial Narrow's Cyrillic)
    if not HS.LATIN then file = STANDARD_TEXT_FONT end
    local size = math.max(N.SIZE_MIN, math.min(N.SIZE_MAX, tonumber(s.nameplateNameSize) or NAME_SIZE))
    return file, size
end

local function StyleName(p)
    local file, size = NameFont()
    if p.nameFile == file and p.nameSize == size then return end
    if not p.name:SetFont(file, size, "") then p.name:SetFont(STANDARD_TEXT_FONT, size, "") end
    local tsize = math.max(8, math.floor(size * 0.72 + 0.5))
    if not p.title:SetFont(file, tsize, "") then p.title:SetFont(STANDARD_TEXT_FONT, tsize, "") end
    p.nameFile, p.nameSize = file, size
end


-- The job under an NPC's name (<Warrior Trainer>): the game draws it itself
-- only when it draws the name too, so it's read from the unit's tooltip, its
-- second line (a level line has a number: not a job). A player's: the guild.
-- (nil: none, or secret)
local function Title(unit)
    local ok, t = pcall(function()
        local v
        if Flag(UnitIsPlayer, unit) then
            v = GetGuildInfo(unit)
        else
            local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
            local line = data and data.lines and data.lines[2]
            v = line and line.leftText
            if type(v) == "string" and not Secret(v) and v:find("%d") then v = nil end
        end
        if Secret(v) or type(v) ~= "string" or v == "" then return nil end
        return "<" .. v .. ">"
    end)
    return ok and t or nil
end

-- In your party or raid
local function Teammate(unit)
    return Flag(function(u) return UnitInParty(u) == true or (UnitInRaid(u) or nil) ~= nil end, unit)
end

-- (team colours on: your party and raid's plates in this green, name and
-- line, kept bright off target too, so the team stands out)
local TEAM = { 0.2, 1, 0.6 }
local function Team(unit)
    return IN.Settings().nameplateGroupColors ~= false and Flag(UnitIsPlayer, unit) and Teammate(unit)
end

-- The name's colour: NPCs and mobs in the header's gold, other players in
-- their class colour (white when it can't be read; gold with the setting
-- off), your party and raid in the team green.
local function NameColor(unit)
    if Team(unit) then return TEAM[1], TEAM[2], TEAM[3] end
    if IN.Settings().nameplateClassColors == false or not Flag(UnitIsPlayer, unit) then return HS.GOLD[1], HS.GOLD[2], HS.GOLD[3] end
    local ok, r, g, b = pcall(function()
        local _, class = UnitClass(unit)
        if Secret(class) or not class then return nil end
        local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
            or RAID_CLASS_COLORS[class]
        if not c then return nil end
        return c.r, c.g, c.b
    end)
    if ok and r then return r, g, b end
    return 1, 1, 1
end

local function Refresh(p)
    local unit = p.unit
    if not unit then return end
    StyleName(p)
    local target = Flag(IsTarget, unit)
    Try(p.name.SetText, p.name, IN.DisplayName(unit))
    Mark(p, unit)
    p.comboN = nil
    Combo(p, unit)
    if Flag(UnitIsDeadOrGhost, unit) then
        p.name:SetTextColor(0.5, 0.5, 0.5)
    else
        local r, g, b = NameColor(unit)
        if not (target or Team(unit)) then r, g, b = Mute(r, g, b) end
        p.name:SetTextColor(r, g, b)
    end
    -- (the health line off, for NPCs and players apart: the name alone)
    local set = IN.Settings()
    local hide
    if Flag(UnitIsPlayer, unit) then hide = set.nameplateHideBarPlayers == true
    else
        -- (a mob you can attack keeps its line, a friendly NPC loses it)
        local mob = Flag(function(u) return UnitCanAttack("player", u) end, unit)
        hide = (not mob) and set.nameplateHideBar ~= false
    end
    local showBar = not hide
    p.bar:SetShown(showBar)
    p.track:SetShown(showBar)
    p.badge:SetShown(showBar)
    -- (the job under the name, as the game's: the guild line of an NPC)
    if p.titleUnit ~= unit then p.titleUnit, p.titleText = unit, Title(unit) end
    local title = p.titleText
    local hasTitle = title ~= nil
    p.title:SetText(title or "")
    p.title:SetShown(hasTitle)
    if p.barShown ~= showBar or p.hasTitle ~= hasTitle then
        p.barShown, p.hasTitle = showBar, hasTitle
        p.name:ClearAllPoints()
        p.title:ClearAllPoints()
        if showBar then
            -- (over the line: the name, the job between it and the line)
            if hasTitle then
                p.title:SetPoint("BOTTOM", p, "TOP", 0, BAR_GAP)
                p.name:SetPoint("BOTTOM", p.title, "TOP", 0, 1)
            else
                p.name:SetPoint("BOTTOM", p, "TOP", 0, BAR_GAP)
            end
        else
            -- (no line: the name where the line was, the job under it)
            if hasTitle then
                p.name:SetPoint("CENTER", p, "CENTER", 0, 6)
                p.title:SetPoint("TOP", p.name, "BOTTOM", 0, -1)
            else
                p.name:SetPoint("CENTER", p, "CENTER", 0, 0)
            end
        end
        p.auraDrop = showBar and -3 or (hasTitle and -17 or -9)
        PlaceBelow(p)
    end
    local value, max = UnitHealth(unit), UnitHealthMax(unit)
    if not Try(p.bar.SetMinMaxValues, p.bar, 0, max) or not Try(p.bar.SetValue, p.bar, value) then
        p.bar:SetMinMaxValues(0, 1)
        p.bar:SetValue(0)
    end
    local r, g, b = TH.NameplateColor(unit, IN.Settings().nameplateClassColors == false)
    local team = Team(unit)
    if team then r, g, b = TEAM[1], TEAM[2], TEAM[3] end
    if not (target or team) then r, g, b = Mute(r, g, b) end
    p.bar:SetStatusBarColor(r, g, b)
    if showBar then
        Level(p, unit)
    else
        p.skull:Hide()
        p.level:SetText("")
    end
    -- (your target's at full size, the others softer: eased on a change)
    p.goalAlpha = target and 1 or OTHER_ALPHA
    p.goalScale = target and 1 or OTHER_SCALE
    p:SetFrameLevel(target and 20 or 10)
    -- (a cast's end missed: gone with it)
    if p.castKind and not Casting(unit) then p.castKind = nil end
    if not p.alpha then
        p.alpha, p.scale = p.goalAlpha, p.goalScale
        Draw(p)
    end
end

---------------------------------------------------------------------------
-- The unit's cast under the line: gold filling for a cast, green draining
-- for a channel (its time gone drawn dark from the right), grey over it when
-- it can't be interrupted (a secret flag: handed to SetAlphaFromBoolean),
-- red a moment when it's interrupted. Its times go to the bar as they are.
---------------------------------------------------------------------------
local function CastOn()
    return IN.Settings().nameplateCast ~= false
end


local function ShowCast(p, on)
    local cb = p.cast
    if cb:IsShown() == (on and true or false) then return end
    cb:SetShown(on)
    PlaceBelow(p)
end

local function CastStop(p)
    p.castKind, p.castHold = nil, nil
    ShowCast(p, false)
end

local function CastStart(p)
    local unit = p.unit
    if not (unit and CastOn()) then return CastStop(p) end
    local kind, text, texture, startMs, endMs, notInterruptible = Casting(unit)
    if not kind then
        -- (an interrupted one stays red its moment)
        if not p.castHold then CastStop(p) end
        return
    end
    local cb = p.cast
    if not Try(cb.SetMinMaxValues, cb, startMs, endMs) then return CastStop(p) end
    p.castKind, p.castHold = kind, nil
    local colors = TH.CAST_COLORS
    if kind == "channel" then
        local c = colors.channel
        cb:SetReverseFill(true)
        cb:SetStatusBarColor(0, 0, 0, 0.75)
        cb.bg:SetColorTexture(c[1], c[2], c[3], 1)
    else
        local c = colors.cast
        cb:SetReverseFill(false)
        cb:SetStatusBarColor(c[1], c[2], c[3], 1)
        cb.bg:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    end
    cb:SetValue(GetTime() * 1000)
    if not Try(cb.shield.SetAlphaFromBoolean, cb.shield, notInterruptible, 0.85, 0) then cb.shield:SetAlpha(0) end
    if not Try(cb.text.SetText, cb.text, text) then cb.text:SetText("") end
    if not Try(cb.icon.SetTexture, cb.icon, texture) then cb.icon:SetTexture(nil) end
    ShowCast(p, true)
end

local function CastInterrupted(p)
    if not p.castKind or Casting(p.unit) then return end
    local cb = p.cast
    local c = TH.CAST_COLORS.interrupted
    p.castKind, p.castHold = nil, GetTime() + CAST_HOLD
    cb:SetReverseFill(false)
    cb:SetMinMaxValues(0, 1)
    cb:SetValue(1)
    cb:SetStatusBarColor(c[1], c[2], c[3], 1)
    cb.shield:SetAlpha(0)
    cb.text:SetText(INTERRUPTED or "Interrupted")
    ShowCast(p, true)
end

local function CastTick(p)
    if p.castKind then
        p.cast:SetValue(GetTime() * 1000)
    elseif not p.castHold or GetTime() > p.castHold then
        if p.cast:IsShown() then CastStop(p) end
    end
end

---------------------------------------------------------------------------
-- The game's plates in play: unit token -> { game plate, ours }
---------------------------------------------------------------------------
local active = {}

local function HideGame(game, on)
    local ok, unitFrame = pcall(function() return game.UnitFrame end)
    if ok and type(unitFrame) == "table" then pcall(IF.Focus.Fade, unitFrame, on) end
end

local function IsCreature(unit)
    local ok, kind = pcall(function()
        local guid = UnitGUID(unit)
        if Secret(guid) or type(guid) ~= "string" then return false end
        return guid:find("^Creature") or guid:find("^Player") or guid:find("^Vehicle") or guid:find("^Pet")
    end)
    return ok and kind and true or false
end

local function Wanted(unit)
    local s = IN.Settings()
    if s.nameplates == false or UF.EditMode() then return false end
    if Flag(UnitNameplateShowsWidgetsOnly, unit) then return false end
    -- (the soft-interact object that isn't a creature or player, the fishing
    -- bobber, stays the game's; a soft-interact NPC gets our look)
    if Flag(IsSoft, unit) and not Flag(IsTarget, unit) and not IsCreature(unit) then return false end
    return true
end


local function Release(unit)
    local a = active[unit]
    if not a then return end
    active[unit] = nil
    HideGame(a.game, false)
    if a.ours then
        Auras(a.ours, nil)
        CastStop(a.ours)
        a.ours:Hide()
        a.ours.unit = nil
        pool[#pool + 1] = a.ours
    end
end

local function Add(unit)
    Release(unit)
    local game = C_NamePlate.GetNamePlateForUnit(unit)
    if not game then return end
    local a = { game = game }
    active[unit] = a
    if not Wanted(unit) then return end
    local p = table.remove(pool) or Build()
    a.ours = p
    p.unit = unit
    p.game = game
    p.seen, p.size = 1, 1
    p.titleUnit = nil
    p.alpha = nil
    HideGame(game, true)
    p:ClearAllPoints()
    p:SetPoint("CENTER", game, "CENTER", 0, -PLATE_DROP)
    Refresh(p)
    Auras(p, unit)
    CastStart(p)
end

-- (an error said once, then no more)
local broken
local function Safe(fn, ...)
    if broken then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        broken = true
        for unit in pairs(active) do Release(unit) end
        IF.Print("Immersion: the nameplates stopped after an error: " .. tostring(err))
    end
end

-- (the combo gems on the plates again: the demo, the setting)
function N.ComboRefresh()
    for u, a in pairs(active) do
        if a.ours then Safe(Combo, a.ours, u) end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("RAID_TARGET_UPDATE")
for _, e in ipairs({ "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_COMBO_POINTS" }) do
    pcall(events.RegisterEvent, events, e)
end
-- (casts: any unit's, the ones with a plate of ours kept)
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = CastStart, UNIT_SPELLCAST_STOP = CastStart, UNIT_SPELLCAST_FAILED = CastStart,
    UNIT_SPELLCAST_DELAYED = CastStart, UNIT_SPELLCAST_CHANNEL_START = CastStart,
    UNIT_SPELLCAST_CHANNEL_STOP = CastStart, UNIT_SPELLCAST_CHANNEL_UPDATE = CastStart,
    UNIT_SPELLCAST_INTERRUPTIBLE = CastStart, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = CastStart,
    UNIT_SPELLCAST_INTERRUPTED = CastInterrupted,
}
for e in pairs(CAST_EVENTS) do pcall(events.RegisterEvent, events, e) end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_COMBO_POINTS" then
        if unit == "player" then
            for u, a in pairs(active) do
                if a.ours then Safe(Combo, a.ours, u) end
            end
        end
        return
    end
    local onCast = CAST_EVENTS[event]
    if onCast then
        local a = unit and active[unit]
        if a and a.ours then Safe(onCast, a.ours) end
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        Safe(Add, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Safe(Release, unit)
    else
        for u, a in pairs(active) do
            if a.ours then Safe(Refresh, a.ours) end
        end
    end
end)

-- Behind an object the game dims its plate (its alpha: only read, in a pcall)
-- but keeps its size; far away it shrinks and fades both. So ours goes out
-- only while the game's plate is dimmed at a normal size: ramping from
-- OCCLUDED_LOW (gone) to OCCLUDED_HIGH (whole). A far one stays ours, a
-- little smaller (FAR_MIN at the smallest) until the game takes the plate.
local OCCLUDED_LOW, OCCLUDED_HIGH = 0.25, 0.45
local NEAR_SCALE, FAR_MIN = 0.57, 0.6
local function Seen(game)
    local ok, a, sc = pcall(function() return game:GetAlpha(), game:GetScale() end)
    if not ok or type(a) ~= "number" or type(sc) ~= "number" or Secret(a) or Secret(sc) then return 1, 1 end
    local size = math.max(FAR_MIN, math.min(1, sc / NEAR_SCALE))
    if sc < NEAR_SCALE * 0.8 then return 1, size end
    return math.max(0, math.min(1, (a - OCCLUDED_LOW) / (OCCLUDED_HIGH - OCCLUDED_LOW))), size
end

local function Ease(p, elapsed)
    if not p.alpha then return end
    local k = math.min(1, elapsed * FADE_SPEED)
    local seen, size = Seen(p.game)
    p.seen = (p.seen or 1) + (seen - (p.seen or 1)) * k
    p.size = (p.size or 1) + (size - (p.size or 1)) * k
    p.alpha = p.alpha + (p.goalAlpha - p.alpha) * k
    p.scale = p.scale + (p.goalScale - p.scale) * k
    if math.abs(p.alpha - p.goalAlpha) < 0.01 then p.alpha, p.scale = p.goalAlpha, p.goalScale end
    Draw(p)
end


local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    local data = since >= STEP
    if data then since = 0 end
    for _, a in pairs(active) do
        if a.ours then
            if data then Safe(Refresh, a.ours) end
            Safe(Ease, a.ours, elapsed)
            Safe(CastTick, a.ours)
        end
    end
end)

-- /if platecast [cast | channel | shield | interrupt | off]: every plate of ours in play shows
-- that made-up cast, over and over (an interrupt: cut short and red), to look at; off: the real ones
local DEMOS = {
    cast = { "cast", "Fireball", 135812, 2600, false },
    channel = { "channel", "Arcane Missiles", 136096, 3000, false },
    shield = { "cast", "Pyroblast", 135808, 2600, true },
    interrupt = { "cast", "Frostbolt", 135846, 2000, false, true },
}
local DEMO_PAUSE = 900

local function EachPlate(fn)
    for _, a in pairs(active) do
        if a.ours then Safe(fn, a.ours) end
    end
end

local demoTicker = CreateFrame("Frame")
demoTicker:Hide()
demoTicker:SetScript("OnUpdate", function()
    if not demo then return demoTicker:Hide() end
    local now = GetTime() * 1000
    if demo.casting then
        -- (an interrupt: cut at 60% of the way)
        local stopAt = demo.started + demo[4] * (demo[6] and 0.6 or 1)
        if now >= stopAt then
            demo.casting = false
            demo.restartAt = now + DEMO_PAUSE
            EachPlate(demo[6] and CastInterrupted or CastStop)
        end
    elseif now >= demo.restartAt then
        demo.casting, demo.started = true, now
        EachPlate(CastStart)
    end
end)

function N.Demo(kind)
    kind = kind and kind:lower() or "cast"
    if kind == "off" then
        demo = nil
        demoTicker:Hide()
        EachPlate(CastStop)
        EachPlate(CastStart)
        IF.Print("Nameplate cast demo: off.")
        return
    end
    local d = DEMOS[kind]
    if not d then
        IF.Print("Nameplate cast demo: cast, channel, shield, interrupt or off.")
        return
    end
    demo = { d[1], d[2], d[3], d[4], d[5], d[6], casting = true, started = GetTime() * 1000 }
    demoTicker:Show()
    local n = 0
    for _, a in pairs(active) do
        if a.ours then n = n + 1 end
    end
    EachPlate(CastStart)
    if not CastOn() then
        IF.Print("Nameplate cast demo: the Nameplate cast bars setting is off (the Immersion tab).")
    elseif n == 0 then
        IF.Print("Nameplate cast demo: " .. kind .. ", but no nameplates in sight: stand near some NPCs or mobs.")
    else
        IF.Print("Nameplate cast demo: " .. kind .. " on " .. n .. " nameplates (/if platecast off to stop).")
    end
end

-- The setting changed: every plate in play drawn again (ours, or the game's)
function N.Apply()
    pcall(N.ApplyCVar)
    local units = {}
    for unit in pairs(active) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do Safe(Add, unit) end
end

---------------------------------------------------------------------------
-- Friendly NPC plates: the game draws none by itself (nameplateShowFriendlyNPCs
-- 0), only their name as plain text, so ours has nothing to dress. The setting
-- turns the CVar on (remembering yours, put back when it's off).
---------------------------------------------------------------------------
-- Far away (no plate) the engine draws a unit's name itself, tiny and in the
-- game's colours: green for NPCs, blue for players. Those can't be restyled,
-- so the setting turns them off and only our plates are left.
local CVARS = {
    { "nameplateShowFriendlyNPCs", "1", function(s) return s.nameplateFriendlyNPCs ~= false end },
    { "UnitNameNPC", "0", function(s) return s.nameplateHideFarNames ~= false end },
    { "UnitNameFriendlyPlayerName", "0", function(s) return s.nameplateHideFarNames ~= false end },
    { "UnitNameNonCombatCreatureName", "0", function(s) return s.nameplateHideFarNames ~= false end },
}
-- (the rest of the game's unit name options: one the client doesn't have reads nil and is skipped)
for _, name in ipairs({
    "UnitNameFriendlySpecialNPCName", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
    "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
    "UnitNameFriendlyMinionName", "UnitNameEnemyPlayerName", "UnitNameEnemyPetName",
    "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName", "UnitNameEnemyMinionName",
}) do
    CVARS[#CVARS + 1] = { name, "0", function(s) return s.nameplateHideFarNames ~= false end }
end

function N.ApplyCVar()
    if InCombatLockdown() then
        N.cvarPending = true
        return
    end
    N.cvarPending = nil
    local s = IN.Settings()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    -- (an earlier version kept the one value as a string)
    if type(s.cvarWas) ~= "table" then s.cvarWas = {} end
    local on = s.nameplates ~= false
    for _, c in ipairs(CVARS) do
        local name, value, test = c[1], c[2], c[3]
        local was = s.cvarWas[name]
        if on and test(s) then
            local now = get(name)
            if was == nil and now ~= nil then s.cvarWas[name] = now end
            if now ~= nil and now ~= value then pcall(set, name, value) end
        elseif was ~= nil then
            pcall(set, name, was)
            s.cvarWas[name] = nil
        end
    end
end

local cvarEvents = CreateFrame("Frame")
cvarEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
cvarEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
cvarEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not N.cvarPending then return end
    pcall(N.ApplyCVar)
end)
