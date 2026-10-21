-- The fishing skill as a line along the screen's bottom edge, its whole
-- width, while the fishing view is on: in the look of the Immersion
-- module's lines along it (PlayerHealth.lua), in the water's colour. A dark track in a thin grey
-- frame, cut in 20 by notches, the fill (the water's blue, lighter at its
-- top as the game's fills are) to your skill of its most, a lure's bonus
-- beyond it fainter, a glow at the fill's end, the fill easing to a new
-- value, a flash as the skill goes up. Its numbers over its left end
-- ("Fishing 75 / 150  +25"); the mouse over it, in a tooltip too.
-- The health and power lines and the game's bar are faded meanwhile (View.lua).
local IF = ImprovedForever
local F = IF.Fishing

local LINE_H, HOVER_H = 5, 14
local COMPARTMENTS = 20
local FRAME = { 0.25, 0.25, 0.25 }      -- (its frame's and notches' grey)
local WHITE = "Interface\\Buttons\\WHITE8x8"
-- (each fill: its bottom's colour, its top's)
-- (quiet: a muted slate, deep water at dusk, not to pull the eye off the
-- bobber; a lure's a dimmer moss)
local COLOR = { 0.42, 0.55, 0.58 }
local COLOR_LOW, COLOR_HIGH = { 0.27, 0.36, 0.39 }, { 0.5, 0.62, 0.65 }
local BONUS = { 0.45, 0.55, 0.45 }
local BONUS_LOW, BONUS_HIGH = { 0.26, 0.32, 0.27 }, { 0.44, 0.53, 0.45 }
local FISHING = 7620

local line = CreateFrame("Frame", "ImprovedForeverFishingSkill", UIParent)
line:SetFrameStrata("BACKGROUND")
line:SetPoint("BOTTOMLEFT")
line:SetPoint("BOTTOMRIGHT")
line:SetHeight(LINE_H)
line:Hide()

local bg = line:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.7)

local function Bar(low, high, level)
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetFrameLevel(line:GetFrameLevel() + level)
    bar:SetStatusBarTexture(WHITE)
    local tex = bar:GetStatusBarTexture()
    if tex and tex.SetGradient and CreateColor then
        tex:SetGradient("VERTICAL", CreateColor(low[1], low[2], low[3], 1), CreateColor(high[1], high[2], high[3], 1))
    else
        bar:SetStatusBarColor(high[1], high[2], high[3])
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local bonus = Bar(BONUS_LOW, BONUS_HIGH, 1)
bonus:SetAlpha(0.7)
local skill = Bar(COLOR_LOW, COLOR_HIGH, 2)

-- (over the fills: the glow at the fill's end, the notches, the frame)
local over = CreateFrame("Frame", nil, line)
over:SetAllPoints()
over:SetFrameLevel(line:GetFrameLevel() + 4)
local glow = over:CreateTexture(nil, "ARTWORK")
glow:SetSize(48, LINE_H - 2)
glow:SetPoint("RIGHT", skill:GetStatusBarTexture(), "RIGHT")
glow:SetColorTexture(1, 1, 1, 1)
glow:SetBlendMode("ADD")
if glow.SetGradient and CreateColor then
    glow:SetGradient("HORIZONTAL", CreateColor(COLOR[1], COLOR[2], COLOR[3], 0),
        CreateColor(0.7, 0.8, 0.82, 0.22))
end
-- (a skill point gained: the glow flaring, wider)
local flare = over:CreateTexture(nil, "ARTWORK", nil, 1)
flare:SetTexture("Interface\\Cooldown\\star4")
flare:SetBlendMode("ADD")
flare:SetVertexColor(0.65, 0.75, 0.78)
flare:SetSize(60, 60)
flare:SetPoint("CENTER", skill:GetStatusBarTexture(), "RIGHT")
flare:SetAlpha(0)

for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
    local t = over:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
    t:SetPoint(e[1])
    t:SetPoint(e[2])
    if e[3] then t:SetWidth(e[3]) end
    if e[4] then t:SetHeight(e[4]) end
end

-- (the notches: two screen pixels wide, re-placed as the width changes)
local notches = {}
local function Notches()
    local width = line:GetWidth()
    if not width or width <= 0 then return end
    local pixel = 768 / (select(2, GetPhysicalScreenSize()) or 768) / line:GetEffectiveScale()
    for i = 1, COMPARTMENTS - 1 do
        local t = notches[i]
        if not t then
            t = over:CreateTexture(nil, "OVERLAY", nil, 1)
            t:SetColorTexture(FRAME[1], FRAME[2], FRAME[3], 1)
            notches[i] = t
        end
        t:SetSize(2 * pixel, LINE_H - 2)
        t:ClearAllPoints()
        t:SetPoint("CENTER", line, "LEFT", i * width / COMPARTMENTS, 0)
    end
end
line:SetScript("OnSizeChanged", Notches)
line:HookScript("OnShow", Notches)

-- (its numbers, over its left end)
local label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("BOTTOMLEFT", line, "TOPLEFT", 12, 5)
label:SetShadowOffset(1, -1)
label:SetTextColor(1, 1, 1)
label:SetShadowColor(0, 0, 0, 1)

-- (a new value eased to, as the game's bars can; at once without it)
local EASE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local function Ease(bar, value)
    if not (EASE and pcall(bar.SetValue, bar, value, EASE)) then bar:SetValue(value) end
end

-- (the mouse: a strip taller than the line, its numbers in a tooltip)
local hover = CreateFrame("Frame", nil, line)
hover:SetPoint("BOTTOMLEFT")
hover:SetPoint("BOTTOMRIGHT")
hover:SetHeight(HOVER_H)
hover:EnableMouse(true)

---------------------------------------------------------------------------
-- The numbers: the skill line named as the Fishing spell is
---------------------------------------------------------------------------
local function FishingName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING)
    return name or (GetSpellInfo and GetSpellInfo(FISHING)) or "Fishing"
end

-- (the line itself: { rank, max, plus }, or nil: Forever's C_SkillInfo,
-- by the Fishing skill line's ID, else by its name among those listed)
local SKILL_LINE = 356
local function Read()
    local info = C_SkillInfo
    if not info then return end
    local function Of(skill)
        if type(skill) ~= "table" or skill.isHeader or type(skill.rank) ~= "number"
            or type(skill.maxRank) ~= "number" or skill.maxRank <= 0 then
            return nil
        end
        return { skill.rank, skill.maxRank, (tonumber(skill.tempPoints) or 0) + (tonumber(skill.modifier) or 0) }
    end
    if info.GetSkillLineInfoByID then
        local ok, skill = pcall(info.GetSkillLineInfoByID, SKILL_LINE)
        local found = ok and Of(skill)
        if found then return found end
    end
    if not (info.GetNumSkillLines and info.GetSkillLineInfo) then return end
    local want = FishingName()
    for i = 1, tonumber(info.GetNumSkillLines()) or 0 do
        local ok, skill = pcall(info.GetSkillLineInfo, i)
        if ok and type(skill) == "table" and (skill.skillID == SKILL_LINE or skill.name == want) then
            local found = Of(skill)
            if found then return found end
        end
    end
end

-- rank, its most, the bonus on it (a lure's), or nil (not learnt): read
-- again only when the skills change (not as our own look changes them)
local cache, dirty, quietUntil = nil, true, 0
local function Values()
    if dirty then
        dirty = false
        cache = Read()
        quietUntil = GetTime() + 0.5
    end
    if cache then return cache[1], cache[2], cache[3] end
end

local lastRank
local flareAt
local function Refresh()
    local rank, max, plus = Values()
    if not rank then return end
    max = math.max(1, max)
    skill:SetMinMaxValues(0, max)
    Ease(skill, rank)
    glow:SetShown(rank > 0)
    bonus:SetMinMaxValues(0, max)
    Ease(bonus, math.min(rank + math.max(0, plus), max))
    label:SetText(("%s  %d / %d"):format(FishingName(), rank, max)
        .. (plus > 0 and ("  |cff8c9c8c+%d|r"):format(plus) or ""))
    if lastRank and rank > lastRank and line:IsShown() then flareAt = GetTime() end
    lastRank = rank
end

line:SetScript("OnUpdate", function()
    if not flareAt then return end
    local t = (GetTime() - flareAt) / 1.2
    if t >= 1 then
        flareAt = nil
        flare:SetAlpha(0)
        return
    end
    flare:SetAlpha(1 - t)
    flare:SetSize(40 + 60 * t, 40 + 60 * t)
end)

hover:SetScript("OnEnter", function(self)
    local rank, max, plus = Values()
    if not rank then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine(FishingName(), 1, 0.82, 0)
    GameTooltip:AddLine(("%d / %d (%d%%)"):format(rank, max, max > 0 and math.floor(rank / max * 100) or 0),
        1, 1, 1)
    if plus > 0 then GameTooltip:AddLine(("Bonus: +%d (%d)"):format(plus, rank + plus), BONUS[1], BONUS[2], BONUS[3]) end
    GameTooltip:Show()
end)
hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function()
    if GetTime() < quietUntil then return end
    dirty = true
    Refresh()
end)

-- /if fishskill: what the skill line reads
IF.AddCommand("fishskill", function()
    dirty = true
    local rank, max, plus = Values()
    IF.Print(rank and ("Fishing skill: %d / %d, +%d"):format(rank, max, plus)
        or ("Fishing skill: not found (looking for \"%s\" in %d skill lines)"):format(FishingName(),
            tonumber(C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetNumSkillLines()) or -1))
end, ": what the fishing skill line reads")

---------------------------------------------------------------------------
-- Shown with the fishing view (and the setting on), Fishing learnt
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    local on = F.Settings().skillLine and F.ViewActive and F.ViewActive() and Values() ~= nil or false
    if on ~= line:IsShown() then
        line:SetShown(on)
        if on then Refresh() end
    end
end

F.Watcher("fishing skill line", 0.25, Watch)

F.ApplySkillLine = Watch
