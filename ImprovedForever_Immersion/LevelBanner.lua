-- Your level up, ours in place of the game's (its level up toast, drawn at
-- 0 by IF.Focus.Fade while it shows one, never touched): in the header's
-- place and look (HeaderSlot.lua), first of all: the gold rule, on it a
-- diamond (the spell diamonds' tile) with the game's level up arrow in it
-- (the new level, should the client lack it), under it
-- "Level 12" big, what it gave small and white (+18 Health, +1 Strength...),
-- what's new small in gold (talent points, the spells the game names).
-- It comes on PLAYER_LEVEL_UP and holds a while once in. What had the
-- header's place goes out first and comes back after; in a fight with a
-- target it waits for the fight to end.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot

local LB = {}
IN.LevelBanner = LB

local HOLD = 5                          -- (seconds shown, once in)
local TILE = 34
local SLIDE = 10
local DOT = "  |cff808080\194\183|r  "

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function Words(v)
    return type(v) == "string" and not Secret(v) and v ~= "" and v or nil
end

---------------------------------------------------------------------------
-- The banner
---------------------------------------------------------------------------
local banner = CreateFrame("Frame", "ImprovedForeverLevelBanner", UIParent)
banner:SetSize(2 * HS.RULE_W, 140)
banner:SetFrameStrata("LOW")
banner:EnableMouse(false)
banner:SetPoint("CENTER", HS.Origin, "CENTER")
banner:Hide()

-- (the diamond, the game's level up arrow in it upright (else the level
-- in the header's Morpheus), in gold: its rim tinted, its edges lit as
-- the cast line's diamond (a line and a wider glow, added light), a soft
-- halo round it, breathing)
local ARROW = "LevelUp-Icon-Arrow"
local tile = HS.Tile(banner, TILE)
local hasArrow = IF.HasAtlas and IF.HasAtlas(ARROW)
-- (its ground gold: a fill cut to the diamond over the slot's dark one)
local fill = tile:CreateTexture(nil, "BACKGROUND", nil, 2)
fill:SetPoint("CENTER")
fill:SetSize(tile.across, tile.across)
fill:SetColorTexture(1, 1, 1, 1)
fill:AddMaskTexture(tile.mask)
local ARROW_W, ARROW_H = tile.across * 0.5 * 30 / 34, tile.across * 0.5
-- (the arrow pure white: white cut to its shape (the atlas as a mask),
-- outlined dark (the same shape bigger under it) and shadowed (a little
-- down), so it stands off the gold)
local shine
if hasArrow then
    tile.icon:Hide()
    local function Shape(sub, r, g, b, a, dy, blend, grow)
        local t = tile:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetSize(ARROW_W + (grow or 0), ARROW_H + (grow or 0))
        t:SetPoint("CENTER", tile, "CENTER", 0, dy)
        t:SetColorTexture(r, g, b, a)
        local m = tile:CreateMaskTexture()
        m:SetAtlas(ARROW)
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
        if blend then t:SetBlendMode(blend) end
        return t
    end
    Shape(0, 0.12, 0.06, 0, 0.7, -2.5, nil, 4)
    Shape(1, 0.18, 0.1, 0, 1, 0, nil, 4)
    Shape(2, 1, 1, 1, 1, 0)
    shine = Shape(3, 1, 1, 1, 0.5, 0, "ADD")
end
local GOLD = { 1, 0.78, 0.15 }          -- (the cast line's gold, PlayerCast.lua)
local PULSE = 1.4                       -- (seconds a pulse takes)
local GROUND = { 0.95, 0.62, 0.08 }     -- (the diamond's ground, under its arrow)
tile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
-- (the halo: the rim again, added light, a pulse running out from it)
local glow = tile:CreateTexture(nil, "OVERLAY", nil, 3)
glow:SetAtlas("gamepad-actionbar-squareslot-border-normal")
glow:SetPoint("CENTER")
glow:SetSize(TILE * 64 / 46 * 1.25, TILE * 64 / 46 * 1.25)
glow:SetRotation(HS.TILE_TURN)
glow:SetBlendMode("ADD")
glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
-- (the edges: from the top point round, on the diamond's border)
local edges = {}
do
    local r = tile.across / 2 * 0.96
    local points = { { 0, r }, { r, 0 }, { 0, -r }, { -r, 0 } }
    for i = 1, 4 do
        local a, b = points[i], points[i % 4 + 1]
        for k, thick in ipairs({ 5, 2 }) do
            local l = tile:CreateLine(nil, "OVERLAY", nil, 4 + k)
            l:SetThickness(thick)
            l:SetTexture("Interface\\Buttons\\WHITE8x8")
            l:SetBlendMode("ADD")
            l:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            l:SetStartPoint("CENTER", tile, a[1], a[2])
            l:SetEndPoint("CENTER", tile, b[1], b[2])
            edges[#edges + 1] = { line = l, alpha = k == 1 and 0.35 or 1 }
        end
    end
end
local number = HS.Text(tile, HS.FONT, 22, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
number:SetDrawLayer("OVERLAY", 2)
number:SetPoint("CENTER", tile, "CENTER", 0, 1)
number:SetShown(not hasArrow)

local title = HS.Text(banner, HS.FONT, HS.NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
title:SetWidth(2 * HS.RULE_W)
local gains = HS.Text(banner, GameFontHighlight and GameFontHighlight:GetFont(), HS.SMALL_SIZE, 1, 1, 1)
gains:SetPoint("TOP", title, "BOTTOM", 0, -4)
gains:SetWidth(2.2 * HS.RULE_W)
local news = HS.Text(banner, GameFontNormal and GameFontNormal:GetFont(), HS.SMALL_SIZE, 1, 0.82, 0)
news:SetPoint("TOP", gains, "BOTTOM", 0, -4)
news:SetWidth(2.2 * HS.RULE_W)

---------------------------------------------------------------------------
-- What it says
---------------------------------------------------------------------------
-- (the gains, as PLAYER_LEVEL_UP hands them: health, power, talent points,
-- then the stats (Forever's four: strength, agility, stamina, intellect);
-- a gain of 0 left out)
local STATS = { "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME", "SPELL_STAT4_NAME", "SPELL_STAT5_NAME" }
local STAT_FALLBACK = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

local function Gains(healthDelta, powerDelta, stats)
    local parts = {}
    local function Add(n, label)
        if type(n) == "number" and not Secret(n) and n > 0 then parts[#parts + 1] = ("+%d %s"):format(n, label) end
    end
    Add(healthDelta, HEALTH or "Health")
    local _, token = UnitPowerType("player")
    local power = not Secret(token) and token and _G[token] or (MANA or "Mana")
    Add(powerDelta, power)
    for i, n in ipairs(stats or {}) do Add(n, _G[STATS[i]] or STAT_FALLBACK[i]) end
    return table.concat(parts, DOT)
end

-- (what's new at the level: talent points, and the spells (dungeons...)
-- the game's level up toasts name)
local function News(level, talents)
    local parts = {}
    if type(talents) == "number" and not Secret(talents) and talents > 0 then
        parts[#parts + 1] = talents == 1 and "A talent point" or ("%d talent points"):format(talents)
    end
    local ok, toasts = pcall(function()
        return C_EventToastManager and C_EventToastManager.GetLevelUpDisplayToastsFromLevel
            and C_EventToastManager.GetLevelUpDisplayToastsFromLevel(level)
    end)
    for _, info in ipairs(ok and type(toasts) == "table" and toasts or {}) do
        local t = Words(info.title)
        if t and info.eventType ~= (Enum.EventToastEventType and Enum.EventToastEventType.LevelUp or 0) then
            parts[#parts + 1] = t .. (Words(info.subtitle) and (": " .. info.subtitle) or "")
        end
    end
    return table.concat(parts, DOT)
end

local goal, shownAt = 0, nil

local function Show(level, healthDelta, powerDelta, talents, stats)
    if type(level) ~= "number" or Secret(level) then level = UnitLevel("player") end
    number:SetText(level)
    title:SetText((LEVEL or "Level") .. " " .. level)
    gains:SetText(Gains(healthDelta, powerDelta, stats))
    news:SetText(News(level, talents))
    goal, shownAt = 1, nil
end

---------------------------------------------------------------------------
-- The game's level up toast drawn at 0 while it shows one (its toasts of a
-- level: the level, its spells, dungeons...)
---------------------------------------------------------------------------
local LEVEL_TOASTS = {}
do
    local E = Enum.EventToastEventType or {}
    for _, k in ipairs({ "LevelUp", "LevelUpSpell", "LevelUpDungeon", "LevelUpRaid", "LevelUpPvP", "LevelUpOther" }) do
        if E[k] then LEVEL_TOASTS[E[k]] = true end
    end
end

local function On()
    return IF.db and IN.Settings().levelBanner and true or false
end

local function NativeLevelToast()
    local f = EventToastManagerFrame
    local toast = f and f:IsShown() and f.currentDisplayingToast
    local info = toast and toast.toastInfo
    return info and LEVEL_TOASTS[info.eventType] or false
end

local Ease, Pop = HS.Ease, HS.Pop
local broken

local function Step()
    local on = On()
    if EventToastManagerFrame then IF.Focus.Fade(EventToastManagerFrame, on and NativeLevelToast()) end
    if not on then goal = 0 end
    local p = HS.Presence("level")
    -- (held HOLD seconds from when it's fully in)
    if p >= 1 and not shownAt then shownAt = GetTime() end
    if goal == 1 and shownAt and GetTime() - shownAt > HOLD then goal = 0 end
    if p <= 0 then
        banner:Hide()
        return
    end
    banner:Show()
    local come = Ease(p, 0, 0.7)
    tile:SetScale(math.max(0.01, come < 1 and Pop(come) or 1))
    tile:SetAlpha(come)
    -- (the pulse: the halo out from the rim and fading, over and over;
    -- the ground and the edges brightest as it leaves)
    local now = GetTime()
    local beat = (now % PULSE) / PULSE
    local size = TILE * 64 / 46 * (1 + 0.6 * beat)
    glow:SetSize(size, size)
    glow:SetAlpha(0.9 * (1 - beat) ^ 1.5)
    local lit = (1 - beat) ^ 2
    -- (the ground a deep gold, so the white arrow stands off it)
    local k = 0.62 + 0.18 * lit
    fill:SetVertexColor(GROUND[1] * k, GROUND[2] * k, GROUND[3] * k, 1)
    if shine then shine:SetAlpha(0.3 * lit) end
    for _, e in ipairs(edges) do e.line:SetAlpha(e.alpha * (0.7 + 0.3 * lit)) end
    local words = Ease(p, 0.3, 1)
    title:ClearAllPoints()
    title:SetPoint("TOP", banner, "CENTER", 0, -HS.NAME_GAP - SLIDE * (1 - words))
    for _, s in ipairs({ title, gains, news }) do s:SetAlpha(words) end
end

-- (one error said once, then no more; the game's toast back)
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if broken then return end
    local ok, err = pcall(Step)
    if not ok then
        broken, goal = true, 0
        banner:Hide()
        if EventToastManagerFrame then IF.Focus.Fade(EventToastManagerFrame, false) end
        IF.Print("Immersion: the level up banner stopped after an error: " .. tostring(err))
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, _, level, healthDelta, powerDelta, talents, _, ...)
    if not On() or broken then return end
    -- (PLAYER_LEVEL_UP: level, health, power, talents, PvP talent slots,
    -- then strength, agility, stamina, intellect)
    local ok, err = pcall(Show, level, healthDelta, powerDelta, talents, { ... })
    if not ok then IF.Print("Immersion: the level up banner: " .. tostring(err)) end
end)

-- (the header's place, first of all; in a fight with a target, after it)
HS.Add("level", 4, {
    wants = function()
        return goal == 1 and not broken and On() and not (IF.InCombat() and UnitExists("target"))
    end,
    rule = function() return true end,
})

function LB.Apply()
    if not On() and EventToastManagerFrame then IF.Focus.Fade(EventToastManagerFrame, false) end
end

-- /if leveltest [level]: the banner as reaching that level (your next one)
-- shows it, with made-up gains
function LB.Test(level)
    level = tonumber(level) or (UnitLevel("player") + 1)
    Show(level, 18, 25, level >= 10 and level % 2 == 0 and 1 or 0, { 1, 0, 2, 1 })
    IF.Print(("Level up banner: level %d (made-up gains)."):format(level))
end

IF.OnLogin(LB.Apply)
