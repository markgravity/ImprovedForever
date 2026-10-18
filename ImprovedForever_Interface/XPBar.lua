-- The experience as a line along the screen's bottom edge, its whole width,
-- in place of the game's experience bar, drawn as DialogueUI's: a dark
-- track in a thin grey frame, cut in 20 by notches, the game's own fills
-- (Forever's experience purple, the rested part beyond it in blue), a glow
-- at the fill's end, the fill easing to a new value. The mouse over it (a
-- taller strip than the line) shows the numbers.
-- The game's bar (the status tracking bar's main container) is drawn at 0
-- while it shows experience (IF.Focus.Fade, never its own alpha), and a
-- frame of ours takes the mouse over it; at the top level it shows
-- reputation, left as it is, and the line goes.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local XP = {}
IN.XPBar = XP

local LINE_H, HOVER_H = IN.XP_H, 14
local COMPARTMENTS = 20
local FRAME = { 0.25, 0.25, 0.25 }      -- (its frame's and notches' grey)
local FILL = "UI-HUD-ExperienceBar-Fill-Experience-Camelot"
local RESTED = "UI-HUD-ExperienceBar-Fill-Rested-Camelot"

local line = CreateFrame("Frame", "ImprovedForeverXPLine", UIParent)
line:SetFrameStrata("BACKGROUND")
line:SetPoint("BOTTOMLEFT")
line:SetPoint("BOTTOMRIGHT")
line:SetHeight(LINE_H)
line:Hide()

local bg = line:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.7)

local function Bar(atlas, level)
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetAllPoints()
    bar:SetFrameLevel(line:GetFrameLevel() + level)
    bar:SetStatusBarTexture(atlas)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local rested = Bar(RESTED, 1)
rested:SetAlpha(0.6)
local xp = Bar(FILL, 2)

-- (over the fills: the glow at the fill's end, the notches, the frame)
local over = CreateFrame("Frame", nil, line)
over:SetAllPoints()
over:SetFrameLevel(line:GetFrameLevel() + 4)
local glow = over:CreateTexture(nil, "ARTWORK")
glow:SetSize(48, LINE_H - 2)
glow:SetPoint("RIGHT", xp:GetStatusBarTexture(), "RIGHT")
glow:SetColorTexture(1, 1, 1, 1)
glow:SetBlendMode("ADD")
if glow.SetGradient and CreateColor then
    glow:SetGradient("HORIZONTAL", CreateColor(1, 0.5, 1, 0), CreateColor(1, 0.5, 1, 0.5))
end

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

-- (a new value eased to, as the game's bars can; at once without it)
local EASE = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
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
-- The numbers
---------------------------------------------------------------------------
local function MaxLevel()
    local util = GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer
    local ok, max = pcall(function() return util and util() or (GetMaxPlayerLevel and GetMaxPlayerLevel()) end)
    return ok and type(max) == "number" and max or nil
end

-- Experience is what the game's bar shows: below the top level, gaining it
local function Gaining()
    local max = MaxLevel()
    local ok, yes = pcall(function()
        if IsXPUserDisabled and IsXPUserDisabled() then return false end
        local level = UnitLevel("player")
        if issecretvalue and issecretvalue(level) then return true end
        return not max or level < max
    end)
    return ok and yes
end

-- (a secret: none, never worked with)
local function Values()
    local ok, cur, max, rest = pcall(function()
        return UnitXP("player"), UnitXPMax("player"), GetXPExhaustion()
    end)
    if not ok or issecretvalue and (issecretvalue(cur) or issecretvalue(max) or issecretvalue(rest)) then return end
    if type(cur) ~= "number" or type(max) ~= "number" then return end
    return cur, max, rest or 0
end

local function Refresh()
    local cur, max, rest = Values()
    if not cur then return end
    xp:SetMinMaxValues(0, max)
    Ease(xp, cur)
    glow:SetShown(cur > 0)
    rested:SetMinMaxValues(0, max)
    local ok = pcall(function() Ease(rested, math.min(cur + rest, max)) end)
    if not ok then rested:SetValue(0) end
end

hover:SetScript("OnEnter", function(self)
    local cur, max, rest = Values()
    if not cur then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    pcall(function()
        GameTooltip:AddLine(XP_LABEL or "Experience", 1, 0.82, 0)
        GameTooltip:AddLine(string.format("%s / %s (%d%%)", BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or cur,
            BreakUpLargeNumbers and BreakUpLargeNumbers(max) or max, max > 0 and math.floor(cur / max * 100) or 0),
            1, 1, 1)
        if rest > 0 then
            GameTooltip:AddLine(string.format("%s: %s", "Rested",
                BreakUpLargeNumbers and BreakUpLargeNumbers(rest) or rest), 0.3, 0.6, 1)
        end
    end)
    GameTooltip:Show()
end)
hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", Refresh)

---------------------------------------------------------------------------
-- Shown while the setting is on and experience is what the game's bar
-- shows; the game's bar then drawn at 0 (Edit Mode: the game's shown, to
-- be moved)
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    local native = MainStatusTrackingBarContainer
    local on = IN.Settings().xp and Gaining()
    local hide = on and not UF.EditMode()
    IF.Focus.Fade(native, hide)
    UF.Cover(native, hide)
    if on ~= line:IsShown() then
        line:SetShown(on)
        if on then Refresh() end
    end
end

IN.Watcher("experience line", 0.25, Watch)

XP.Apply = Watch
