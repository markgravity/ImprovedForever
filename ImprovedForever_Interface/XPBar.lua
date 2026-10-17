-- The experience as a line along the screen's bottom edge, its whole width,
-- in place of the game's experience bar: the game's own fills (Forever's
-- experience purple, the rested part beyond it in blue) on a dark strip.
-- The mouse over it (a taller strip than the line) shows the numbers.
-- The game's bar (the status tracking bar's main container) is drawn at 0
-- while it shows experience (IF.Focus.Fade, never its own alpha), and a
-- frame of ours takes the mouse over it; at the top level it shows
-- reputation, left as it is, and the line goes.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local XP = {}
IN.XPBar = XP

local LINE_H, HOVER_H = 4, 12
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
bg:SetColorTexture(0, 0, 0, 0.6)

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
        return not max or UnitLevel("player") < max
    end)
    return ok and yes
end

local function Values()
    local ok, cur, max, rest = pcall(function()
        return UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() or 0
    end)
    if not ok then return end
    return cur, max, rest
end

local function Refresh()
    local cur, max, rest = Values()
    if not cur then return end
    xp:SetMinMaxValues(0, max)
    xp:SetValue(cur)
    rested:SetMinMaxValues(0, max)
    local ok = pcall(function() rested:SetValue(math.min(cur + rest, max)) end)
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
