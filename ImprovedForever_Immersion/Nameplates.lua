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
local NAME_SIZE = 13
local STEP = 0.1
local OTHER_SCALE, OTHER_ALPHA = 0.8, 0.85
local FADE_SPEED = 8                    -- (how fast alpha and size ease)

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
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    p.bar = CreateFrame("StatusBar", nil, p)
    p.bar:SetAllPoints()
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    p.bar:SetMinMaxValues(0, 1)
    p.bar:SetValue(1)
    p.name = HS.Text(p, HS.FONT, NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
    p.name:SetPoint("BOTTOM", p, "TOP", 0, 3)
    p.name:SetWidth(W * 1.6)
    local badge = p:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("LEFT", p, "RIGHT", 2, 0)
    p.level = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.level:SetDrawLayer("OVERLAY", 3)
    p.level:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
    p.skull = p:CreateTexture(nil, "OVERLAY", nil, 4)
    p.skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
    p.skull:SetPoint("CENTER", badge, "CENTER")
    p.skull:Hide()
    return p
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
    c:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -3)
    c:Hide()
    p.auras = c
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

-- (drawn at its current alpha and size; none left: not shown)
local function Draw(p)
    p:SetScale(math.max(0.01, p.scale))
    p:SetAlpha(p.alpha)
    p:SetShown(p.alpha > 0.01)
end

local function Refresh(p)
    local unit = p.unit
    if not unit then return end
    Try(p.name.SetText, p.name, UnitName(unit))
    if Flag(UnitIsDeadOrGhost, unit) then
        p.name:SetTextColor(0.5, 0.5, 0.5)
    else
        p.name:SetTextColor(HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
    end
    local value, max = UnitHealth(unit), UnitHealthMax(unit)
    if not Try(p.bar.SetMinMaxValues, p.bar, 0, max) or not Try(p.bar.SetValue, p.bar, value) then
        p.bar:SetMinMaxValues(0, 1)
        p.bar:SetValue(0)
    end
    local r, g, b = TH.NameplateColor(unit)
    p.bar:SetStatusBarColor(r, g, b)
    Level(p, unit)
    -- (your target's at full size, the others softer: eased on a change)
    local target = Flag(IsTarget, unit)
    p.goalAlpha = target and 1 or OTHER_ALPHA
    p.goalScale = target and 1 or OTHER_SCALE
    p:SetFrameLevel(target and 20 or 10)
    if not p.alpha then
        p.alpha, p.scale = p.goalAlpha, p.goalScale
        Draw(p)
    end
end

---------------------------------------------------------------------------
-- The game's plates in play: unit token -> { game plate, ours }
---------------------------------------------------------------------------
local active = {}
local N = {}
IN.Nameplates = N

local function HideGame(game, on)
    local ok, unitFrame = pcall(function() return game.UnitFrame end)
    if ok and type(unitFrame) == "table" then pcall(IF.Focus.Fade, unitFrame, on) end
end

local function Wanted(unit)
    local s = IN.Settings()
    if s.nameplates == false or UF.EditMode() then return false end
    if Flag(UnitNameplateShowsWidgetsOnly, unit) then return false end
    if Flag(IsSoft, unit) and not Flag(IsTarget, unit) then return false end
    return true
end

local function Release(unit)
    local a = active[unit]
    if not a then return end
    active[unit] = nil
    HideGame(a.game, false)
    if a.ours then
        Auras(a.ours, nil)
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
    p.alpha = nil
    HideGame(game, true)
    p:ClearAllPoints()
    p:SetPoint("CENTER", game, "CENTER", 0, 0)
    Refresh(p)
    Auras(p, unit)
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

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
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

local function Ease(p, elapsed)
    if not p.alpha then return end
    local k = math.min(1, elapsed * FADE_SPEED)
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
        end
    end
end)

-- The setting changed: every plate in play drawn again (ours, or the game's)
function N.Apply()
    local units = {}
    for unit in pairs(active) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do Safe(Add, unit) end
end
