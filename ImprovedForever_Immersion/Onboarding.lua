-- The first-time tour: the first time Immersion is in, "Immersion" near the
-- top (no rule, no diamond), and in the middle of the screen, with no ground
-- of its own, in the header's look (HeaderSlot.lua): a gold rule standing,
-- one small diamond on it with the page's picture, the pages' names left of
-- it, and under the last one a diamond button that reveals the next (bobbing
-- and pulsing so it is seen); in the middle of the screen the page's example
-- made of the real thing (the party cards PartyCards.lua draws for /if
-- cards, the spell diamonds' tiles GamepadBar.lua draws, made-up numbers)
-- and what it is under it. Revealed, a name can be picked. Click the right
-- side or the diamond, or A, to reveal more; up / down (the D-pad) pick; Close
-- under the words, B or Esc end it. It is shown once
-- (IN.Settings().tourDone); /if tour plays it again. The pad is taken by a
-- catcher frame only while it is up (not in a fight).
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot

local OB = {}
IN.Onboarding = OB

local START_DELAY = 6                   -- (seconds after login, then once out of a fight)
local FADE = 0.35

-- (the panel, and in it: the list's rule, the right side)
local W, H = 1200, 540
local RIGHT_W = 500                     -- (the right side: in the middle of the screen)
local RULE_X = W / 2 - RIGHT_W / 2 - 70  -- (the standing rule, from the panel's left: left of it)
local TOP_RULE_Y = 92
local RULE_TOP, RULE_BOTTOM = 90, 470   -- (the standing rule's ends)
local LIST_TOP, LIST_BOTTOM = 190, 440  -- (the names' span)
local STAGE_W, STAGE_H = RIGHT_W, 240   -- (the example: its middle the screen's middle)
local STAGE_Y = H / 2 - STAGE_H / 2
local WORDS_Y = STAGE_Y + STAGE_H + 12
local TILE = 30

local GOLD = HS.GOLD
local GREY = { 0.5, 0.5, 0.5 }
local Ease = HS.Ease

local SPELLS = {
    "Interface\\Icons\\Spell_Fire_FlameBolt", "Interface\\Icons\\Spell_Holy_HolyBolt",
    "Interface\\Icons\\Spell_Nature_HealingTouch", "Interface\\Icons\\Ability_Warrior_Charge",
}

---------------------------------------------------------------------------
-- The pages: { name, icon, lines, example }
---------------------------------------------------------------------------
local PAGES = {
    {
        name = "Your frame", icon = "Interface\\Icons\\Achievement_Character_Human_Male", example = "frame",
        portrait = true,
        lines = { "Your portrait sits bottom left, ringed by your experience.",
            "Your health and power run as lines along the bottom edge." },
    },
    {
        name = "Action bar", icon = SPELLS[1], example = "diamonds",
        lines = { "Your gamepad bar, bottom right: its spells as diamonds, with their cooldowns.",
            "Tiles can be squares or circles instead." },
    },
    {
        name = "Recent loot", icon = "Interface\\Icons\\INV_Misc_Bag_08", example = "loot",
        lines = { "The last things you looted that matter, as tiles beside the bags.",
            "Upgrades, quest starters, recipes, finds for the auction house and rares." },
    },
    {
        name = "Cast bar", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", example = "cast",
        lines = { "Your casts as a long line over the party cards, filling out from the middle.",
            "Grey when it can't be interrupted, red when it is cut." },
    },
    {
        name = "Pet and party", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing", example = "cards",
        lines = { "Cards along the bottom: click to target, right click for the menu.",
            "They flag threat for a tank and who is hurt for a healer." },
    },
    {
        name = "The header", icon = "Interface\\Icons\\INV_Misc_Map_01", example = "header",
        lines = { "Under the top of the screen, taking turns: your target, zone names,",
            "the way to your quest, level ups and quest progress." },
    },
    {
        name = "Make it yours", icon = "Interface\\Icons\\INV_Misc_Gear_01", example = "switches",
        lines = { "Each piece has a switch in Improved Forever, Immersion.",
            "/if tour plays this again." },
        last = true,
    },
}

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local root = CreateFrame("Frame", "ImprovedForeverTour", UIParent)
root:SetSize(W, H)
root:SetFrameStrata("HIGH")
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:EnableMouse(true)
root:Hide()

-- A gold rule, fading out at both ends (the header's)
local function Rule(parent, length, vertical)
    local f = CreateFrame("Frame", nil, parent)
    if vertical then f:SetSize(1, length) else f:SetSize(length, 1) end
    local function Color(a) return CreateColor(GOLD[1], GOLD[2], GOLD[3], a) end
    -- (each half: the end clear, the middle 0.8)
    for _, first in ipairs({ true, false }) do
        local r = f:CreateTexture(nil, "ARTWORK")
        r:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        local ok
        if vertical then
            r:SetSize(1, length / 2)
            r:SetPoint(first and "BOTTOM" or "TOP", f, "CENTER")
            -- (vertical gradients run from the bottom to the top)
            ok = pcall(r.SetGradient, r, "VERTICAL", first and Color(0.8) or Color(0), first and Color(0) or Color(0.8))
        else
            r:SetSize(length / 2, 1)
            r:SetPoint(first and "RIGHT" or "LEFT", f, "CENTER")
            ok = pcall(r.SetGradient, r, "HORIZONTAL", first and Color(0) or Color(0.8), first and Color(0.8) or Color(0))
        end
        if not ok then r:SetAlpha(0.6) end
    end
    return f
end

local bodyFont = GameFontHighlight and GameFontHighlight:GetFont()

-- (the standing rule, the list's side and the example's)
local sideRule = Rule(root, RULE_BOTTOM - RULE_TOP, true)
sideRule:SetPoint("TOP", root, "TOPLEFT", RULE_X, -RULE_TOP)

---------------------------------------------------------------------------
-- The list: a diamond on the rule for each page, its name left of it
---------------------------------------------------------------------------
local rows = {}
local page, shownAt, goal = 1, nil, 0
local reached = 1                   -- (the furthest page shown: its name and those before are on the list)
local broken
local Go

local function Row(i)
    local def = PAGES[i]
    local y = LIST_TOP + (i - 0.5) * (LIST_BOTTOM - LIST_TOP) / #PAGES
    local row = CreateFrame("Button", nil, root)
    row:SetSize(RULE_X - 60, 30)
    row:SetPoint("RIGHT", root, "TOPLEFT", RULE_X - 52, -y)
    row.name = HS.Text(row, bodyFont, 16, GREY[1], GREY[2], GREY[3])
    row.name:SetAllPoints()
    row.name:SetJustifyH("RIGHT")
    row.name:SetText(def.name)
    row:SetScript("OnEnter", function(self) self.hover = true end)
    row:SetScript("OnLeave", function(self) self.hover = nil end)
    row:SetScript("OnClick", function() Go(i) end)
    rows[i] = row
end
for i = 1, #PAGES do Row(i) end

-- (the current page's picture in a diamond on the rule, above the names)
-- (above the first name)
local TILE_Y = LIST_TOP + (LIST_BOTTOM - LIST_TOP) / (2 * #PAGES) - 44
local mark = HS.Tile(root, TILE)
mark:ClearAllPoints()
mark:SetPoint("CENTER", root, "TOPLEFT", RULE_X, -TILE_Y)
mark:SetFrameLevel(sideRule:GetFrameLevel() + 5)
mark.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
mark.icon:SetSize(mark.across, mark.across)
-- (the reveal button: a diamond on the rule where the next name will be, bobbing
-- and pulsing so it is seen; the pad's A beside it, the D-pad's up / down
-- under the list)
local more = CreateFrame("Button", nil, root)
more:SetSize(TILE, TILE)
more:SetFrameLevel(sideRule:GetFrameLevel() + 5)
local moreTile = HS.Tile(more, TILE - 6)
moreTile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
moreTile.icon:SetColorTexture(0.6, 0.38, 0.05, 1)
moreTile.icon:SetSize(moreTile.across, moreTile.across)
-- (a down arrow: the game's level up arrow turned over, pure white: white cut
-- to its shape, as the level up banner draws it; else a "v")
local ARROW = "LevelUp-Icon-Arrow"
if IF.HasAtlas and IF.HasAtlas(ARROW) then
    local arrow = moreTile:CreateTexture(nil, "OVERLAY", nil, 2)
    arrow:SetSize(moreTile.across * 0.5 * 30 / 34, moreTile.across * 0.5)
    arrow:SetPoint("CENTER", moreTile, "CENTER", 0, -1)
    arrow:SetColorTexture(1, 1, 1, 1)
    local cut = moreTile:CreateMaskTexture()
    cut:SetAtlas(ARROW)
    cut:SetAllPoints(arrow)
    cut:SetRotation(math.pi)
    arrow:AddMaskTexture(cut)
else
    local v = HS.Text(moreTile, HS.FONT, 18, 1, 1, 1)
    v:SetDrawLayer("OVERLAY", 2)
    v:SetPoint("CENTER", moreTile, "CENTER", 0, 1)
    v:SetText("v")
end
local moreGlow = moreTile:CreateTexture(nil, "OVERLAY", nil, 3)
moreGlow:SetAtlas("gamepad-actionbar-squareslot-border-normal")
moreGlow:SetPoint("CENTER")
moreGlow:SetRotation(HS.TILE_TURN)
moreGlow:SetBlendMode("ADD")
moreGlow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
more:SetScript("OnClick", function() OB.Press("PAD1") end)
more:SetScript("OnEnter", function() moreTile.border:SetVertexColor(1, 1, 1) end)
more:SetScript("OnLeave", function() moreTile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
local moreKey = HS.Text(root, bodyFont, 14, 1, 1, 1)
local browse = HS.Text(root, bodyFont, 14, 1, 1, 1)
browse:SetPoint("TOPRIGHT", root, "TOPLEFT", RULE_X - 52, -(LIST_BOTTOM + 24))
browse:SetJustifyH("RIGHT")

---------------------------------------------------------------------------
-- The right side: the page's name, the example (the middle of the screen),
-- what it is, the buttons
---------------------------------------------------------------------------
local right = CreateFrame("Frame", nil, root)
right:SetSize(RIGHT_W, H)
right:SetPoint("TOP", root, "TOP", 0, 0)

-- (no buttons: A next, B skip, Esc skips, a click on this side goes on)
right:EnableMouse(true)
right:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then OB.Press("PAD1") end
end)

local line1 = HS.Text(right, bodyFont, HS.SMALL_SIZE, 1, 1, 1)
line1:SetWidth(RIGHT_W + 60)
line1:SetPoint("TOP", right, "TOP", 0, -WORDS_Y)
local line2 = HS.Text(right, bodyFont, HS.SMALL_SIZE, 1, 0.82, 0)
line2:SetWidth(RIGHT_W + 60)
line2:SetPoint("TOP", line1, "BOTTOM", 0, -4)

local stage = CreateFrame("Frame", nil, right)
stage:SetSize(STAGE_W, STAGE_H)
stage:SetPoint("TOP", right, "TOP", 0, -STAGE_Y)
---------------------------------------------------------------------------
-- The examples: the real thing with made-up numbers
---------------------------------------------------------------------------
OB.examples = {}

local function Example(key, build)
    local f = CreateFrame("Frame", nil, stage)
    f:SetAllPoints()
    f:Hide()
    OB.examples[key] = f
    f.build = function()
        f.build = nil
        local ok, err = pcall(build, f)
        if not ok then
            local s = HS.Text(f, bodyFont, 12, 1, 0.4, 0.4)
            s:SetPoint("CENTER")
            s:SetText("(example not drawn: " .. tostring(err):sub(1, 90) .. ")")
        end
    end
end

local function Class()
    local _, class = UnitClass("player")
    return class or "WARRIOR"
end

local function Label(parent, text, size, r, g, b)
    local s = HS.Text(parent, bodyFont, size, r or 1, g or 1, b or 1)
    s:SetText(text)
    return s
end

-- Your frame: a real card, bigger, as the player's
Example("frame", function(f)
    local card = IN.PartyCards.Demo(f, { name = UnitName("player"), class = Class(), role = "DAMAGER",
        health = 0.8, threat = 0 }, 1.9)
    card:ClearAllPoints()
    card:SetPoint("CENTER", -80, -4)
    local t = Label(f, "Health and power over the name,", 12)
    t:SetPoint("LEFT", card, "RIGHT", 24, 22)
    local u = Label(f, "the gold ring round the portrait", 12)
    u:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    local v = Label(f, "fills with your experience.", 12)
    v:SetPoint("TOPLEFT", u, "BOTTOMLEFT", 0, -4)
end)

-- The spell diamonds: the gamepad bar's own tiles, in its style
Example("diamonds", function(f)
    local GB = IN.GamepadBar
    local D = GB.Dims(46, 14)
    local center = CreateFrame("Frame", nil, f)
    center:SetSize(2, 2)
    center:SetPoint("CENTER", 0, -2)
    local dirs = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
    for i, dir in ipairs(dirs) do
        local b = GB.Tile(f, center, D, dir)
        b:SetFrameLevel(f:GetFrameLevel() + 2)
        b:EnableMouse(false)
        GB.Mirror(b, GB.StandIn(SPELLS[i], nil, nil, nil))
    end
    local t = Label(f, "Tiles: diamonds, squares or circles (Immersion settings)", 11, 0.7, 0.7, 0.7)
    t:SetPoint("BOTTOM", 0, 10)
end)

-- Pet and party cards, real ones
Example("cards", function(f)
    local samples = {
        { name = "Minion", role = "MINION", health = 0.9, threat = 0 },
        { name = "Tank", class = "WARRIOR", role = "TANK", health = 0.55, threat = 3 },
        { name = "Healer", class = "PRIEST", role = "HEALER", health = 0.85, threat = 0 },
        { name = "Mage", class = "MAGE", role = "DAMAGER", health = 0.2, threat = 2 },
    }
    local gap = 10
    local cards = {}
    for i, sample in ipairs(samples) do
        cards[i] = IN.PartyCards.Demo(f, sample, 1)
    end
    local w = cards[1]:GetWidth()
    local x = -(4 * w + 3 * gap) / 2
    for i, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetPoint("LEFT", f, "CENTER", x + (i - 1) * (w + gap), -6)
    end
    local t = Label(f, "Tank: threat, green to red.  Healer: who is hurt, flashing under 35%.", 11, 0.7, 0.7, 0.7)
    t:SetPoint("BOTTOM", 0, 10)
end)

-- Recent loot: its tiles, the bar's own, new ones landing at the front
Example("loot", function(f)
    local row = IN.RecentLoot.Demo(f)
    row:SetPoint("CENTER", 0, 8)
    local t = Label(f, "Newest nearest the bags. The badge says why it is worth a look.", 11, 0.7, 0.7, 0.7)
    t:SetPoint("BOTTOM", 0, 14)
end)

-- The header: the real one, moved into the example (HS.MoveOrigin: every
-- owner of its place hangs on one anchor), taking turns as it does: your
-- target as a friend and as an enemy (a stand-in, TH.Demo), the way to a
-- quest (QA.Demo), the zone's name, quest progress and a level up (their own
-- tests). Under it, the name of what is showing.
local STEPS = {
    { label = "Friendly target", run = function() IN.TargetHeader.Demo("friend") end },
    { label = "Enemy target", run = function() IN.TargetHeader.Demo("enemy") end },
    { label = "Quest guide", run = function() IN.QuestArrow.Demo(true) end },
    { label = "Zone name", run = function() IN.ZoneBanner.Test() end },
    { label = "Quest progress", run = function() IN.QuestProgress.Test() end },
    { label = "Level up", run = function() IN.LevelBanner.Test() end },
}
local STEP_HOLD = 6.5

-- (the tests say what they did in chat: not here)
local function Quietly(fn)
    local print = IF.Print
    IF.Print = function() end
    local ok, err = pcall(fn)
    IF.Print = print
    return ok, err
end

local demoOn
function OB.StopDemos()
    if not demoOn then return end
    demoOn = nil
    pcall(IN.TargetHeader.Demo, nil)
    pcall(IN.QuestArrow.Demo, false)
    pcall(IN.PlayerCast.Demo, nil)
    HS.ResetOrigin()
end

Example("header", function(f)
    local label = HS.Text(f, HS.FONT, 18, GOLD[1], GOLD[2], GOLD[3])
    label:SetPoint("BOTTOM", 0, 28)
    local count = Label(f, "", 11, 0.55, 0.55, 0.55)
    count:SetPoint("BOTTOM", 0, 12)
    local index, t = 0, STEP_HOLD
    local function Run(n)
        index = n
        OB.StopDemos()
        local step = STEPS[n]
        label:SetText(step.label)
        count:SetText(n .. " / " .. #STEPS)
        HS.MoveOrigin(f, 0, -56)
        demoOn = true
        local ok, err = Quietly(step.run)
        if not ok then count:SetText("(not shown: " .. tostring(err):sub(1, 70) .. ")") end
    end
    f:SetScript("OnShow", function() index, t = 0, STEP_HOLD end)
    f:SetScript("OnHide", function() OB.StopDemos() end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if goal ~= 1 or not root:IsShown() then return end
        t = t + elapsed
        if t >= STEP_HOLD then
            t = 0
            Run(index % #STEPS + 1)
        end
    end)
end)

-- The cast bar: the real line, moved into the example, a made-up cast of each
-- kind in turn
local CASTS = {
    { kind = "cast", label = "A cast fills from the middle out" },
    { kind = "channel", label = "A channel drains in to the middle" },
    { kind = "shield", label = "Grey: it can't be interrupted" },
    { kind = "interrupt", label = "Red: it was interrupted" },
}
local CAST_HOLD = 3.4

Example("cast", function(f)
    local label = Label(f, "", 13, 0.75, 0.75, 0.75)
    label:SetPoint("BOTTOM", 0, 14)
    local index, t = 0, CAST_HOLD
    f:SetScript("OnShow", function() index, t = 0, CAST_HOLD end)
    f:SetScript("OnHide", function() OB.StopDemos() end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if goal ~= 1 or not root:IsShown() then return end
        t = t + elapsed
        if t >= CAST_HOLD then
            t = 0
            index = index % #CASTS + 1
            local c = CASTS[index]
            label:SetText(c.label)
            demoOn = true
            Quietly(function() IN.PlayerCast.Demo(c.kind, f) end)
        end
    end)
end)

-- The settings: a switch for each piece, as the tab shows them
Example("switches", function(f)
    local list = { { "Player HUD", true }, { "Target header", true }, { "Party cards", true },
        { "Cast bar", true }, { "Recent loot (experiment)", false } }
    for i, r in ipairs(list) do
        local y = -34 - (i - 1) * 34
        Label(f, r[1], 14, 1, 1, 1):SetPoint("TOPLEFT", 110, y)
        local on = r[2]
        Label(f, on and "On" or "Off", 14, on and 0.35 or 0.55, on and 0.85 or 0.55, on and 0.35 or 0.55)
            :SetPoint("TOPRIGHT", -110, y)
        local line = f:CreateTexture(nil, "BORDER")
        line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.15)
        line:SetPoint("TOPLEFT", 100, y - 22)
        line:SetPoint("TOPRIGHT", -100, y - 22)
        line:SetHeight(1)
    end
end)

---------------------------------------------------------------------------
-- The button: Close near the bottom of the screen, a word as the NPC dialog's
-- answers (the pad's glyph before one with the pad)
---------------------------------------------------------------------------
local function Word(size, r, g, b, glyph)
    local btn = CreateFrame("Button", nil, root)
    btn:SetHeight(size + 8)
    btn.text = HS.Text(btn, bodyFont, size, r, g, b)
    btn.text:SetPoint("LEFT")
    btn.color = { r, g, b }
    btn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function(self) self.text:SetTextColor(self.color[1], self.color[2], self.color[3]) end)
    function btn:Set(word)
        self.text:SetText((IF.Input.Pad() and (IF.GlyphText(glyph, size) .. " ") or "") .. word)
        self:SetWidth(self.text:GetStringWidth())
    end
    return btn
end
local closeButton = Word(17, 0.7, 0.7, 0.7, "PAD2")
closeButton:SetScript("OnClick", function() OB.Press("PAD2") end)

-- (under the words, close to the tour: the way out, shown with the pad's B or Esc)
local function Hints()
    local pad = IF.Input.Pad()
    moreKey:SetText(pad and IF.GlyphText("PAD1", 18) or "")
    browse:SetText(pad and (IF.GlyphText("DPAD_UD", 18) .. " Browse") or "")
end

local function Buttons()
    Hints()
    closeButton:Set(IF.Input.Pad() and "Close" or "Close  (Esc)")
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPLEFT", root, "TOP", -closeButton:GetWidth() / 2, -(WORDS_Y + 58))
end

---------------------------------------------------------------------------
-- The name at the top, as the header's (HeaderSlot.lua: big in Morpheus, a
-- small line under it) but with no rule and no diamond
---------------------------------------------------------------------------
local head = CreateFrame("Frame", nil, UIParent)
head:SetSize(2 * HS.RULE_W, 80)
head:SetFrameStrata("LOW")
head:EnableMouse(false)
head:SetPoint("TOP", UIParent, "TOP", 0, -(HS.RULE_Y + HS.NAME_GAP - 20))
head:Hide()
local headName = HS.Text(head, HS.FONT, HS.NAME_SIZE, GOLD[1], GOLD[2], GOLD[3])
headName:SetWidth(2 * HS.RULE_W)
headName:SetPoint("TOP")
headName:SetText("Immersion")
local headSmall = HS.Text(head, bodyFont, HS.SMALL_SIZE, 1, 1, 1)
headSmall:SetWidth(2.2 * HS.RULE_W)
headSmall:SetPoint("TOP", headName, "BOTTOM", 0, -4)
headSmall:SetText("The game's HUD, rearranged. A quick look at what is where.")

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
local escape = CreateFrame("Frame", "ImprovedForeverTourEscape", UIParent)
escape:Hide()
if _G.UISpecialFrames then table.insert(UISpecialFrames, "ImprovedForeverTourEscape") end

local function Finish()
    goal = 0
    page = 1
    if IF.db then IN.Settings().tourDone = true end
    escape:Hide()
    OB.StopDemos()
end

function Go(n)
    if n > #PAGES then return Finish() end
    if n < 1 then return end
    local changed = n ~= page or not shownAt
    page, shownAt = n, GetTime()
    reached = math.max(reached, n)
    local p = PAGES[n]
    if p.portrait and SetPortraitTexture then
        pcall(SetPortraitTexture, mark.icon, "player")
    else
        mark.icon:SetTexture(p.icon)
    end
    Buttons()
    line1:SetText(p.lines[1] or "")
    line2:SetText(p.lines[2] or "")
    for key, f in pairs(OB.examples) do
        local shown = key == p.example
        if shown and f.build then f.build() end
        f:SetShown(shown)
    end
    if changed and goal == 1 then PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_SELECT or 856) end
end

-- (A and a click on the right side reveal the next page, up / down pick among
-- the revealed, B and Esc end it)
function OB.Press(key)
    if goal ~= 1 then return end
    if key == "PAD1" then
        if reached < #PAGES then Go(reached + 1) end
    elseif key == "UP" then
        if page > 1 then Go(page - 1) end
    elseif key == "DOWN" then
        if page < reached then Go(page + 1) end
    elseif key == "PAD2" then
        Finish()
    end
end

---------------------------------------------------------------------------
-- The pad: taken only while it is up
---------------------------------------------------------------------------
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetScript("OnGamePadButtonDown", function(_, button)
    if button == "PAD1" then OB.Press(button) end
    if button == "PADDUP" then OB.Press("UP") end
    if button == "PADDDOWN" then OB.Press("DOWN") end
end)
catcher:SetScript("OnGamePadButtonUp", function(_, button)
    if button == "PAD2" then OB.Press(button) end
end)
-- (a gamepad handler turns the frame's input on by itself: off until it is
-- wanted, else it takes the pad from login)
catcher:EnableGamePadButton(false)
IF.OnLogin(function()
    IF.Input.OnChange(function() if goal == 1 then Buttons() end end)
end)

-- (Esc: the game closes it as it does a window)
escape:SetScript("OnHide", function()
    if goal == 1 then Finish() end
end)

local taking
local function TakePad(on)
    if taking == on or not catcher.EnableGamePadButton then return end
    if IF.InCombat() then return end
    taking = on
    catcher:EnableGamePadButton(on)
end

---------------------------------------------------------------------------
-- Drawn
---------------------------------------------------------------------------
local presence = 0

local function Step(elapsed)
    local want = goal == 1 and not IF.InCombat()
    -- (closed or done: gone at once; a fight only fades it)
    if goal == 0 then presence = 0 end
    presence = want and math.min(1, presence + elapsed / FADE) or math.max(0, presence - elapsed / FADE)
    TakePad(want and presence >= 0.5)
    if presence <= 0 then
        root:Hide()
        head:Hide()
        OB.StopDemos()
        return
    end
    head:Show()
    head:SetAlpha(Ease(presence, 0, 1))
    if not root:IsShown() then root:Show() end
    if want and not escape:IsShown() then escape:Show() end
    root:SetAlpha(Ease(presence, 0, 1))
    local now = GetTime()
    -- (the page's words slide in as it turns)
    local words = shownAt and Ease(now - shownAt, 0, 0.35) or 1
    for _, s in ipairs({ line1, line2 }) do s:SetAlpha(words) end
    stage:SetAlpha(0.35 + 0.65 * words)
    -- (the reveal button on the rule where the next name will be)
    local nextSlot = reached + 1
    local beat = (now % 1.2) / 1.2
    more:SetShown(nextSlot <= #PAGES)
    if nextSlot <= #PAGES then
        local y = LIST_TOP + (nextSlot - 0.5) * (LIST_BOTTOM - LIST_TOP) / #PAGES
        more:ClearAllPoints()
        more:SetPoint("CENTER", root, "TOPLEFT", RULE_X, -y + 4 * math.sin(now * 5))
        local size = (TILE - 6) * 64 / 46 * (1 + 0.8 * beat)
        moreGlow:SetSize(size, size)
        moreGlow:SetAlpha(0.95 * (1 - beat) ^ 1.3)
        moreTile:SetScale(1 + 0.06 * math.sin(now * 5))
        moreKey:ClearAllPoints()
        moreKey:SetPoint("LEFT", more, "RIGHT", 10, 0)
    end
    moreKey:SetShown(nextSlot <= #PAGES)
    -- (the list: the page's name gold)
    for i, row in ipairs(rows) do
        local on = i == page
        local c = on and GOLD or (row.hover and { 1, 1, 1 } or GREY)
        row.name:SetTextColor(c[1], c[2], c[3])
        -- (revealed one by one as the tour reaches them)
        row.name:SetAlpha(i < reached and 1 or (i == reached and (i == page and words or 1) or 0))
        row:EnableMouse(i <= reached)
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then
        broken, goal = true, 0
        root:Hide()
        head:Hide()
        escape:Hide()
        TakePad(false)
        IF.Print("Immersion: the tour stopped after an error: " .. tostring(err))
    end
end)

---------------------------------------------------------------------------
-- When it starts
---------------------------------------------------------------------------
function OB.Start()
    broken = nil
    goal = 1
    shownAt = nil
    reached = 1
    local ok, err = pcall(Go, 1)
    if not ok then
        goal = 0
        IF.Print("Immersion: the tour could not start: " .. tostring(err))
    end
end

-- (the first time: a moment after login, once out of a fight)
local function Auto()
    if not IF.db or IN.Settings().tourDone then return end
    if IF.InCombat() or UnitIsDeadOrGhost("player") then
        return C_Timer.After(5, Auto)
    end
    OB.Start()
end

IF.OnLogin(function()
    if not IN.Settings().tourDone then C_Timer.After(START_DELAY, Auto) end
end)

-- /if tour: the tour again
IF.AddCommand("tour", function() OB.Start() end, ": play Immersion's first-time tour again")
