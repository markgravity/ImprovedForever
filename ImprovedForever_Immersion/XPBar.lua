-- The experience as a ring round the player frame bottom left (its card,
-- UnitFrames.lua), in place of the game's experience bar, drawn as the
-- gamepad bar's cast ring (GamepadBar.lua): a line on the card's border
-- with a wider, fainter one under it as its glow, on a faint track all the way round, clockwise from the
-- level badge at its top left round to it again, in the experience bar's own fills (Forever's
-- experience purple, the rested part beyond it in blue, fainter), easing
-- to a new value. The mouse over the card shows the numbers in its
-- tooltip.
-- The game's bar (the status tracking bar's main container) is drawn at 0
-- while it shows experience (IF.Focus.Fade, never its own alpha), and a
-- frame of ours takes the mouse over it; at the top level it shows
-- reputation, left as it is, and the ring goes (with the player frame
-- off too: the game's bar then shows it).
-- Under water the same ring shows your breath instead (Breath.lua, XP.Air):
-- blue, draining clockwise as the breath runs out, the experience's gone
-- while it does.
-- The ring is ours, on the card but never anchored to the secure button
-- itself: it's redrawn in a fight (a kill's experience) by its lines'
-- points alone.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local XP = {}
IN.XPBar = XP

local FILL = "UI-HUD-ExperienceBar-Fill-Experience-Camelot"
local RESTED = "UI-HUD-ExperienceBar-Fill-Rested-Camelot"
-- (their colours, should a line not take the atlas)
local FILL_COLOR, RESTED_COLOR = { 0.7, 0.25, 0.85 }, { 0.1, 0.45, 0.95 }
local GLOW_COLOR = { 1, 0.5, 1 }        -- (its glow's, the experience bar's)
local RESTED_ALPHA = 0.6
local AIR_COLOR = { 0.3, 0.65, 1 }      -- (the breath's, with its glow)
-- (on the border, RING_IN in from the card's edge; the line's and glow's
-- thickness, the gamepad bar's cast ring's)
local RING_IN, RING_LINE, RING_GLOW = 3, 2.5, 4
-- (the level badge's reach from the ring's top left corner: the ring
-- starts past it along the top, ends short of it up the left side;
-- UnitFrames.lua's Avatar: its 24 wide circle centred 6 in)
local BADGE = 16
local EASE = 6                          -- (how fast it eases to a new value)
local WHITE = "Interface\\Buttons\\WHITE8x8"

local avatar = UF.player.avatar
local ring = CreateFrame("Frame", "ImprovedForeverXPRing", avatar)
ring:SetAllPoints()
-- (over the card's border, under its level and class icon)
ring:SetFrameLevel(avatar.badge:GetFrameLevel() - 1)
ring:Hide()

-- (a line's fill: the bar's atlas, else its colour)
local function Paint(l, atlas, color)
    if IF.HasAtlas and IF.HasAtlas(atlas) and pcall(l.SetAtlas, l, atlas) then return end
    l:SetTexture(WHITE)
    l:SetVertexColor(color[1], color[2], color[3], 1)
end

-- (an arc's lines (and glows), made as needed, one per side of the card)
local function Arc(atlas, color, alpha, glow)
    return { atlas = atlas, color = color, alpha = alpha, glow = glow, lines = {}, glows = {},
        glowColor = glow and (atlas == "" and AIR_COLOR or GLOW_COLOR) or nil }
end
local fill = Arc(FILL, FILL_COLOR, 1, true)
local rested = Arc(RESTED, RESTED_COLOR, RESTED_ALPHA, false)
local air = Arc("", AIR_COLOR, 1, true)
-- (the whole way round, faint under the fill: the progress reads against it)
local track = Arc("", { 1, 1, 1 }, 0.14, false)
local breath          -- (the breath's share left, 0 to 1, while under water; else nil)
-- (the switch between the two: mix 0 is the experience, 1 the breath, eased;
-- the breath's arc eased to its share, from nothing as it comes)
local mix, airShown, airGoal = 0, 0, 0

local function ArcLines(arc, i)
    if not arc.lines[i] then
        if arc.glow then
            local g = ring:CreateLine(nil, "OVERLAY", nil, 1)
            g:SetThickness(RING_GLOW)
            g:SetTexture(WHITE)
            g:SetBlendMode("ADD")
            g:SetVertexColor(arc.glowColor[1], arc.glowColor[2], arc.glowColor[3], 0.35)
            arc.glows[i] = g
        end
        local l = ring:CreateLine(nil, "OVERLAY", nil, arc.glow and 3 or 2)
        l:SetThickness(RING_LINE)
        Paint(l, arc.atlas, arc.color)
        l:SetAlpha(arc.alpha)
        arc.lines[i] = l
    end
    return arc.lines[i], arc.glows[i]
end

-- The card's path, clockwise from the level badge round to it again
-- (past it along the top, to under it on the left side), in points from
-- its centre, and each side's share of the way (the sides aren't equal: a
-- share by length)
local function Path()
    local w, h = ring:GetSize()
    local hw, hh = math.max(w / 2 - RING_IN, 1), math.max(h / 2 - RING_IN, 1)
    local badge = math.min(BADGE, hw, hh)
    local path = { { -hw + badge, hh }, { hw, hh }, { hw, -hh }, { -hw, -hh }, { -hw, hh - badge } }
    local lengths, total = {}, 0
    for i = 1, #path - 1 do
        local a, z = path[i], path[i + 1]
        lengths[i] = math.abs(z[1] - a[1]) + math.abs(z[2] - a[2])
        total = total + lengths[i]
    end
    local at, cuts = 0, { 0 }
    for i = 1, #path - 1 do
        at = at + lengths[i] / total
        cuts[i + 1] = at
    end
    return path, cuts
end

-- The arc drawn from `from` to `to` (0 to 1 of the way round)
local function DrawArc(arc, from, to, k)
    k = k or 1
    local path, cuts = Path()
    for i = 1, #path - 1 do
        local line, glow = ArcLines(arc, i)
        local s0, s1 = cuts[i], cuts[i + 1]
        local a, b = math.max(from, s0), math.min(to, s1)
        if b - a <= 0 or s1 <= s0 or k <= 0 then
            line:Hide()
            if glow then glow:Hide() end
        else
            local p, q = path[i], path[i + 1]
            local function At(s)
                local k = (s - s0) / (s1 - s0)
                return p[1] + (q[1] - p[1]) * k, p[2] + (q[2] - p[2]) * k
            end
            local x1, y1 = At(a)
            local x2, y2 = At(b)
            line:SetAlpha(arc.alpha * k)
            if glow then glow:SetAlpha(k) end
            for _, l in ipairs({ line, glow }) do
                l:SetStartPoint("CENTER", ring, x1, y1)
                l:SetEndPoint("CENTER", ring, x2, y2)
                l:Show()
            end
        end
    end
end

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

-- (what's drawn, eased to the goal: its share and the rested part's end)
local shown = { f = 0, r = 0 }
local goal = { f = 0, r = 0 }

local function Draw()
    DrawArc(track, 0, 1, 1 - mix)
    DrawArc(fill, 0, shown.f, 1 - mix)
    DrawArc(rested, shown.f, shown.r, 1 - mix)
    DrawArc(air, 0, airShown, mix)
end

local function Step(_, elapsed)
    local k = math.min(1, elapsed * EASE)
    local done = true
    for _, key in ipairs({ "f", "r" }) do
        local d = goal[key] - shown[key]
        if math.abs(d) < 0.001 then
            shown[key] = goal[key]
        else
            shown[key] = shown[key] + d * k
            done = false
        end
    end
    local want = breath and 1 or 0
    if math.abs(want - mix) < 0.005 then
        mix = want
    else
        mix = mix + (want - mix) * k
        done = false
    end
    if math.abs(airGoal - airShown) < 0.002 then
        airShown = airGoal
    else
        airShown = airShown + (airGoal - airShown) * k
        done = false
    end
    Draw()
    if done then
        ring:SetScript("OnUpdate", nil)
        if mix == 0 then XP.Apply() end
    end
end

-- (a new value eased to; less than shown (a new level) from none)
local function Refresh()
    local cur, max, rest = Values()
    if not cur or max <= 0 then return end
    local f = math.min(math.max(cur / max, 0), 1)
    local r = math.min(math.max((cur + rest) / max, f), 1)
    if f < shown.f then shown.f, shown.r = 0, 0 end
    goal.f, goal.r = f, r
    ring:SetScript("OnUpdate", Step)
end

ring:SetScript("OnSizeChanged", Draw)
ring:HookScript("OnShow", Draw)

-- The breath's share left (0 to 1) drawn in the ring in place of the
-- experience; nil: the experience again
function XP.Air(share)
    if share == breath then return end
    local coming = share and not breath
    breath = share
    if share then
        airGoal = share
        if coming then airShown = 0 end
    end
    ring:SetScript("OnUpdate", Step)
    XP.Apply()
end

-- (the card's tooltip: its numbers after the unit's)
UF.player:HookScript("OnEnter", function()
    if not ring:IsShown() then return end
    local cur, max, rest = Values()
    if not cur then return end
    pcall(function()
        GameTooltip:AddLine(" ")
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

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", Refresh)

---------------------------------------------------------------------------
-- Shown while the setting and the player frame are on and experience is
-- what the game's bar shows; the game's bar then drawn at 0 (Edit Mode:
-- the game's shown, to be moved)
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    local native = MainStatusTrackingBarContainer
    local s = IN.Settings()
    local xp = s.xp and s.player and Gaining() or false
    local on = xp or (s.player and not UF.EditMode() and (breath ~= nil or mix > 0))
    local hide = xp and not UF.EditMode()
    IF.Focus.Fade(native, hide)
    UF.Cover(native, hide)
    if on ~= ring:IsShown() then
        ring:SetShown(on)
        if on then Refresh() end
        if on then ring:SetScript("OnUpdate", Step) end
    end
end

IN.Watcher("experience ring", 0.25, Watch)

XP.Apply = Watch
