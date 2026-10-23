-- The campfire as a scene of its own (the Camp module). Sitting by a fire (the Welcoming Campfire
-- aura on you, still a moment), out of a fight: the HUD fades out (your
-- avatar and pet, the minimap with it: IF.Focus.Fade, never their alpha),
-- black bars slide in at the top and bottom, the picture fades up from
-- black on the first shot, and the words come up. The camera holds each
-- shot still but for a slow pan, and cuts to the next through black (close
-- over the shoulder, wide, low beside you, facing you): the angle, distance
-- and framing change only while the screen is black, so nothing is seen
-- stepping.
-- While the Welcoming Campfire counts down: what you're doing by the fire
-- in the bottom bar, one line after another, none twice ("Meditating in
-- the incense smoke"; from the camp's last benefits, as nothing says
-- before which objects are near, then the fire's own), and the time left
-- on the right. Given: the words stop, and the benefits (the Camp
-- Benefits aura's tooltip, a line per camp object) come up a third of the
-- way down the screen.
-- Getting up (a step, a jump, a cast) or a fight: all of it back in
-- reverse, the camera turned back and your settings put back behind black
-- (kept per character until then, IF.charDB.campCamSaved, so a /reload or
-- a logout puts them back). The Welcoming Campfire coming and going while
-- you sit (it does, each minute) changes nothing.
-- Logging out or quitting (the game's 20 second countdown, its "CAMP" /
-- "QUIT" popup left in place to cancel) is the same scene: the camp
-- breaking up. The countdown reads "Leaving in", your day is told back,
-- and the picture fades to black over the last seconds. Cancelled (the
-- popup, a step, LOGOUT_CANCEL): all of it back, as above.
local IF = ImprovedForever
local C = IF.Camp

local WELCOMING = "Welcoming Campfire"
local BENEFITS = "Camp Benefits"
local NEARBY = "Campfire Nearby"
local FONT = "Fonts\\MORPHEUS.TTF"

-- (faded: frames of ours, by name, the game's minimap and tooltip and,
-- without ours, its tracker)
local FADED = { "ImprovedForeverGamepadBar", "ImprovedForeverRecentSlot", "ImprovedForeverPlayerFrame",
    "ImprovedForeverMinionCard1", "ImprovedForeverPartyCard1", "ImprovedForeverPartyCard2",
    "ImprovedForeverPartyCard3", "ImprovedForeverPartyCard4", "ImprovedForeverPartyCasts",
    "ImprovedForeverBuffList", "ImprovedForeverCooldownTimeline",
    "ImprovedForeverChatView", "ImprovedForeverPlayerHealth", "IFObjectiveTrackerFrame",
    "ImprovedForeverNpcDialog", "ImprovedForeverMinimapLabels", "ImprovedForeverMinimapAlert",
    "ImprovedForeverQuestArrow", "ImprovedForeverZoneBanner", "ImprovedForeverHeaderRule",
    "ImprovedForeverTargetHeader", "ImprovedForeverLevelBanner", "ImprovedForeverQuestProgress", "MinimapCluster", "Minimap",
    -- (the tooltip: the faded HUD still takes the mouse, a buff under it
    -- shows its tooltip; any other tooltip has no place in the scene either)
    "GameTooltip" }

-- What you're doing by the fire, by the camp object the benefit's line
-- names ("Lodestone: ..."); FIRE: the fire alone, after those
local WORDS = {
    ["Camp Tent"] = "Resting in the shade of the tent",
    ["Mana Well"] = "Drawing calm from the mana well",
    ["Sharpening Wheel"] = "Honing an edge on the wheel",
    ["Enchanted Lute"] = "Listening to the lute's soft song",
    ["First Aid Kit"] = "Tending old wounds",
    ["Fish Bowl"] = "Watching the fish drift",
    ["Incense Candle"] = "Meditating in the incense smoke",
    ["Lodestone"] = "Feeling the lodestone's pull",
    ["Camp Chair"] = "Leaning back, eyes half closed",
    ["Faction Banner"] = "Gazing up at the banner",
}
-- (each camp object's item, for its icon: RecipeData.lua, the recipe that
-- makes it)
local ITEMS = {
    ["Camp Tent"] = 279978, ["Mana Well"] = 279956, ["Sharpening Wheel"] = 279944,
    ["Enchanted Lute"] = 279976, ["First Aid Kit"] = 279968, ["Fish Bowl"] = 279967,
    ["Incense Candle"] = 279962, ["Lodestone"] = 279960, ["Camp Chair"] = 279979,
    ["Faction Banner"] = 279973,
}
local FIRE = { "Warming your hands by the fire", "Listening to the embers crackle", "Resting tired feet",
    "Breathing slow", "Watching the sparks rise", "Letting the road fall away", "Feeling the warmth on your face",
    "Counting the stars through the smoke", "Thinking of the road behind", "Thinking of the road ahead" }
local WORDS_EVERY = 7

-- The shots, one after another, round again; each reached through black.
-- Where from: yaw, degrees round you from where the camera was when the
-- scene began (behind you, as the gamepad camera follows: 0 behind, 180
-- in front, + to the right), pitch, degrees higher looking down from
-- there; zoom, the distance; shoulder, the camera's offset to the side
-- (test_cameraOverShoulder: + puts you on the left of the picture); pad,
-- the share of the screen under your feet (test_cameraDynamicPitchBase-
-- FovPad: 0.4 puts you at the bottom). Then held, panning pan degrees a
-- second (+ right). words: where the words go, on the picture's empty side
-- (-1 left, 0 middle, 1 right); wordsY: how high (a share of the screen's
-- height from the middle: low, WORDS_Y, unless said). The first shot
-- opens the scene, the rest come in a shuffled order, none twice in a row.
local SHOTS = {
    { yaw = 0, pitch = 8, zoom = 16, shoulder = 0, pad = 0.22, pan = 0, words = 0, wordsY = 0.22, time = 14 },     -- behind, far
    { yaw = 35, pitch = 0, zoom = 8, shoulder = 2.8, pad = 0.38, pan = 1.2, words = 1, time = 14 },                 -- you bottom left
    { yaw = 180, pitch = 30, zoom = 20, shoulder = 0, pad = 0.12, pan = 0.8, words = 0, wordsY = 0.22, time = 16 }, -- in front, far, high, looking down
    { yaw = -40, pitch = 0, zoom = 8, shoulder = -2.8, pad = 0.38, pan = -1.2, words = -1, time = 14 },             -- you bottom right
    { yaw = 25, pitch = 4, zoom = 4, shoulder = 1.2, pad = 0.12, pan = 0.6, words = 1, time = 14 },                 -- close, over the shoulder
    { yaw = 90, pitch = -4, zoom = 10, shoulder = 2, pad = 0.32, pan = 0.6, words = 1, time = 14 },                 -- side on, low, you left
    { yaw = -90, pitch = -4, zoom = 10, shoulder = -2, pad = 0.32, pan = -0.6, words = -1, time = 14 },             -- other side on, low, you right
    { yaw = 0, pitch = 45, zoom = 14, shoulder = 0, pad = 0.1, pan = 1, words = 1, time = 14 },                     -- high over, behind
    { yaw = 160, pitch = -6, zoom = 5, shoulder = -1.5, pad = 0.3, pan = -0.4, words = -1, time = 13 },             -- in front, close, low
    { yaw = 140, pitch = 15, zoom = 14, shoulder = 2.5, pad = 0.35, pan = 0.8, words = 1, time = 15 },              -- in front aside, far, you bottom left
    { yaw = -140, pitch = 15, zoom = 14, shoulder = -2.5, pad = 0.35, pan = -0.8, words = -1, time = 15 },          -- in front other side, far, you bottom right
}
-- (turning while black, at most this many times the game's turn speeds:
-- cameraYawMoveSpeed, cameraPitchMoveSpeed degrees a second at speed 1)
local TURN_SPEED = 2
-- (MoveViewDown raises the camera to look down: -1 if it's the other way)
local PITCH_SIGN = 1
local WORDS_X = 0.25 -- (the words' side, a share of the screen's width from the middle)
local CUT_ZOOM_SPEED = 50 -- (the distance changed while black: at once)
-- (a cut: to black, held while the camera moves, back)
local CUT_DOWN, CUT_HOLD, CUT_UP = 0.5, 0.35, 0.8

local CVARS = { "test_cameraOverShoulder", "test_cameraDynamicPitch", "test_cameraDynamicPitchBaseFovPad",
    "cameraZoomSpeed" }
local CENTERED = "CameraKeepCharacterCentered"
local SETTLE = 1.5 -- seconds still, sitting, before the scene
local GRACE = 1.5  -- seconds in before a move counts as getting up
local AGAIN = 4    -- seconds out before it may come back

local function GetCVarSafe(name)
    local ok, v = pcall(C_CVar and C_CVar.GetCVar or GetCVar, name)
    return ok and v or nil
end
local function SetCVarSafe(name, value)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set and value ~= nil then pcall(set, name, tostring(value)) end
end
local function Zoom()
    local ok, z = pcall(GetCameraZoom)
    return ok and type(z) == "number" and z or nil
end

-- /if camptest [seconds]: the scene without a fire, a countdown of its
-- own (20 seconds) then these benefits; again, or getting up: out
local test
-- Logging out / quitting: { endAt, quit } while its countdown runs; pending
-- until the game's popup shows (an inn or city logs out at once, no
-- countdown: no scene)
local logout, pending
local LOGOUT_POPUP = { [false] = "CAMP", [true] = "QUIT" }
local LOGOUT_TIME, LOGOUT_FADE = 20, 2.5 -- (the countdown unless the popup says; the black over its last seconds)
local LOGOUT_WORDS = { "Putting out the fire", "Rolling up the bedroll", "Shouldering the pack",
    "One last look at the stars", "The road will keep", "Until the next fire" }
-- (every Tier 1 camp object's line, as the Camp Benefits tooltip words
-- it, at the guides' top values)
local TEST_BENEFITS = {
    "Camp Tent: Grants a small amount of rest experience, usable once per hour.",
    "Mana Well: Restores 29 Mana every 5 seconds.",
    "Sharpening Wheel: Strength increased by 34.",
    "Enchanted Lute: Armor increased by 28, all attributes increased by 2, and all resistances increased by 5.",
    "First Aid Kit: Stamina increased by 56.",
    "Fish Bowl: All stats increased by 8%.",
    "Incense Candle: Intellect increased by 25.",
    "Lodestone: Melee Attack Power increased by 90.",
    "Camp Chair: Chance to critically hit with all spells and attacks increased by 2%.",
    "Faction Banner: Spirit increased by 32.",
}

local function HasAura(name)
    local ok, aura = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    return ok and aura ~= nil
end

-- (the Welcoming Campfire's time left: nil without it)
local function Left()
    if logout then
        local left = logout.endAt - GetTime()
        return left > 0 and left or nil
    end
    if test then
        local left = test.endAt - GetTime()
        return left > 0 and left or nil
    end
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not d then return nil end
        if d.name == WELCOMING then
            if issecretvalue and (issecretvalue(d.expirationTime) or issecretvalue(d.duration)) then return nil end
            if d.duration and d.duration > 0 then return math.max(0, d.expirationTime - GetTime()) end
            return 0
        end
    end
end

-- The benefits the camp gave: the Camp Benefits aura's tooltip, "Object:
-- what it gives." a line each (the game's own text, values resolved), and
-- when it runs out (renewed later than at the scene's start: this camp's)
function C.Rewards()
    if test then
        local given = GetTime() >= test.endAt
        return test.rewards or TEST_BENEFITS, given and test.endAt + 3600 or nil
    end
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not d then return nil end
        if d.name == BENEFITS then
            local expires = d.expirationTime
            if issecretvalue and issecretvalue(expires) then expires = nil end
            local okT, tip = pcall(C_TooltipInfo.GetUnitAura, "player", i, "HELPFUL")
            local out = {}
            for _, line in ipairs(okT and tip and tip.lines or {}) do
                local t = line.leftText
                if type(t) == "string" and not (issecretvalue and issecretvalue(t)) and t:find("Gained the following") then
                    for part in t:gmatch("[^\r\n]+") do
                        if not part:find("Gained the following") then out[#out + 1] = part end
                    end
                end
            end
            return out, expires
        end
    end
end

-- (the words for these benefits' objects, the fire's after: each once)
local function Words(rewards)
    local out, seen = {}, {}
    for _, line in ipairs(rewards or {}) do
        local w = WORDS[line:match("^([^:]+):")]
        if w and not seen[w] then out[#out + 1], seen[w] = w, true end
    end
    for _, w in ipairs(FIRE) do out[#out + 1] = w end
    return out
end

-- The day so far, told back: the Journal module's diary (IF.Journal), its
-- last RECAP sentences (the latest day's story, the day before's too when
-- that's short; not the summary closing a day), under an opening line.
-- nil: no Journal, or nothing written yet.
local RECAP = 6
local function Clean(text)
    return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        :gsub("\226\128\156", '"'):gsub("\226\128\157", '"'):gsub("\226\128\152", "'"):gsub("\226\128\153", "'"))
end
-- The opening line from what the first sentence told is about (the first
-- of these whose words it holds; else the caller's): the same story always
-- opens the same way
local OPENERS_BY = {
    { "I fell", "spirit healers", "bested by", "cut down by", "I died", "My corpse" }, "The road took its toll on me...",
    { "fought", "cut down", "slew", "bested", "fell to my blade", "stood my ground", "lost count" }, "Steel drawn, blood on the road...",
    { "quest", "finished", "completed", "turned in", "accepted", "was asked", "task" }, "Another task behind me...",
    { "dove", "swam", "depths" }, "Down beneath the waves...",
    { "sold", "merchant", "coin", "gold", "silver", "copper", "bought" }, "Counting what the road paid...",
    { "rare find", "among my finds", "came away with", "I found", "I looted" }, "A find worth remembering...",
    { "grew stronger", "reached level", "level" }, "Stronger than when I began...",
    { "woke", "rose early", "lay down", "rest" }, "From the first light...",
    { "road led", "came upon", "made my way", "arrived", "set out", "crossed", "flew" }, "The road led on...",
}
local function OpenerFor(sentence, fallback)
    local text = (sentence or ""):lower()
    for i = 1, #OPENERS_BY, 2 do
        for _, word in ipairs(OPENERS_BY[i]) do
            if text:find(word:lower(), 1, true) then return OPENERS_BY[i + 1] end
        end
    end
    return fallback
end

local function Recap(count, opener)
    count = count or RECAP
    local J = IF.Journal
    if not (J and J.Write and J.Days and J.Day) then return nil end
    local ok, lines = pcall(function()
        local keys, all = J.Days(), {}
        for n = 1, math.min(2, #keys) do
            local paragraphs = J.Write(keys[n], J.Day(keys[n])) or {}
            local day = {}
            for p = 1, #paragraphs - (#paragraphs > 1 and 1 or 0) do
                for sentence in Clean(paragraphs[p]):gmatch("[^%.!?]+[%.!?]+\"?") do
                    sentence = sentence:match("^%s*(.-)%s*$")
                    if sentence ~= "" then day[#day + 1] = sentence end
                end
            end
            for i = #day, 1, -1 do table.insert(all, 1, day[i]) end
            if #all >= count then break end
        end
        local first = math.max(1, #all - count + 1)
        local out = { OpenerFor(all[first], opener or "Looking back on the road...") }
        for i = first, #all do out[#out + 1] = all[i] end
        return #out > 1 and out or nil
    end)
    return ok and lines or nil
end

-- Logging out: the same opening every time, then the last LOGOUT_RECAP
-- sentences of the Journal's latest day (what just happened), the fixed
-- lines when there's no Journal or nothing written. nil: not logging out.
local LOGOUT_RECAP = 2
local function LogoutLines()
    if not logout then return nil end
    return Recap(LOGOUT_RECAP, "Breaking camp, the day behind me...") or LOGOUT_WORDS
end

---------------------------------------------------------------------------
-- Easing
---------------------------------------------------------------------------
local function Smooth(p)
    p = math.max(0, math.min(1, p))
    return p * p * (3 - 2 * p)
end
-- (from -> to between t0 and t1 of the phase)
local function Tween(from, to, t, t0, t1)
    return from + (to - from) * Smooth((t - t0) / (t1 - t0))
end

---------------------------------------------------------------------------
-- The scene's own frames: the black (cuts), the bars, the words, the
-- countdown, the benefits
---------------------------------------------------------------------------
local stage = CreateFrame("Frame", "ImprovedForeverCampScene", UIParent)
stage:SetAllPoints(UIParent)
stage:SetFrameStrata("BACKGROUND")
stage:Hide()

local black = stage:CreateTexture(nil, "BACKGROUND", nil, -1)
black:SetAllPoints(stage)
black:SetColorTexture(0, 0, 0, 1)
black:SetAlpha(0)

local barH = 100
local function Bar(top)
    local bar = stage:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetColorTexture(0, 0, 0, 1)
    -- (a soft shadow off its inner edge)
    local shade = stage:CreateTexture(nil, "BACKGROUND", nil, 0)
    shade:SetColorTexture(1, 1, 1, 1)
    local clear, dark = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.55)
    if top then
        shade:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
        shade:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
        if not pcall(shade.SetGradient, shade, "VERTICAL", clear, dark) then shade:SetColorTexture(0, 0, 0, 0) end
    else
        shade:SetPoint("BOTTOMLEFT", bar, "TOPLEFT")
        shade:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT")
        if not pcall(shade.SetGradient, shade, "VERTICAL", dark, clear) then shade:SetColorTexture(0, 0, 0, 0) end
    end
    bar.shade = shade
    return bar
end
local topBar, bottomBar = Bar(true), Bar(false)

-- (slid in by p, 0 to 1)
local function PlaceBars(p)
    local off = barH * (1 - p)
    topBar:ClearAllPoints()
    topBar:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, off)
    topBar:SetPoint("TOPRIGHT", stage, "TOPRIGHT", 0, off)
    bottomBar:ClearAllPoints()
    bottomBar:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 0, -off)
    bottomBar:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, -off)
    for _, bar in ipairs({ topBar, bottomBar }) do
        bar:SetHeight(barH)
        bar.shade:SetHeight(barH * 0.9)
        bar.shade:SetAlpha(p)
    end
end

local texts = CreateFrame("Frame", nil, stage)
texts:SetAllPoints(stage)
texts:SetAlpha(0)

local function Text(parent, size, r, g, b)
    local s = parent:CreateFontString(nil, "OVERLAY")
    if not s:SetFont(FONT, size, "") then s:SetFont(STANDARD_TEXT_FONT, size, "") end
    s:SetTextColor(r, g, b)
    s:SetShadowOffset(1, -1)
    s:SetShadowColor(0, 0, 0, 1)
    return s
end

-- (the words, in the picture, low, on the shot's empty side: a line at a
-- time, a font string a word so each fades in on its own)
local WORD_SIZE = 28
local WORD_EVERY, WORD_FADE = 0.22, 0.7 -- (each word a beat after the last, in over this)
local WORDS_Y = -0.2 -- (below the middle, a share of the screen's height)
local words = CreateFrame("Frame", nil, texts)
words:SetSize(10, WORD_SIZE + 8)
words:SetAlpha(0)
local wordStrings = {}
local space = Text(words, WORD_SIZE, 1, 1, 1)
space:SetAlpha(0)

-- (a space's width in the font: measured when used, the font loaded by then)
local function SpaceWidth()
    space:SetText("a a")
    local w = space:GetStringWidth()
    space:SetText("aa")
    w = w - space:GetStringWidth()
    return w > 0 and w or WORD_SIZE * 0.28
end

-- (a line laid out word by word, wrapped past WORDS_W of the screen's
-- width, each row centred on the frame; how long it stays: its words in,
-- then a while to read)
local WORDS_W, READ = 0.42, 3.5
local function SetLine(text)
    local list = {}
    for w in (text or ""):gmatch("%S+") do list[#list + 1] = w end
    local spaceW, maxW = SpaceWidth(), UIParent:GetWidth() * WORDS_W
    local rows, row, rowW = {}, {}, 0
    for i, w in ipairs(list) do
        local fs = wordStrings[i]
        if not fs then
            fs = Text(words, WORD_SIZE, 0.97, 0.9, 0.76)
            wordStrings[i] = fs
        end
        fs:SetText(w)
        fs:SetAlpha(0)
        fs:Show()
        local fw = fs:GetStringWidth()
        if #row > 0 and rowW + spaceW + fw > maxW then
            rows[#rows + 1], row, rowW = { list = row, w = rowW }, {}, 0
        end
        rowW = rowW + (#row > 0 and spaceW or 0) + fw
        row[#row + 1] = fs
    end
    if #row > 0 then rows[#rows + 1] = { list = row, w = rowW } end
    for i = #list + 1, #wordStrings do wordStrings[i]:Hide() end
    local lineH = WORD_SIZE * 1.35
    for r, line in ipairs(rows) do
        local x, y = -line.w / 2, ((#rows - 1) / 2 - (r - 1)) * lineH
        for _, fs in ipairs(line.list) do
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", words, "CENTER", x, y)
            x = x + fs:GetStringWidth() + spaceW
        end
    end
    words.count = #list
    words.time = math.max(WORDS_EVERY, #list * WORD_EVERY + WORD_FADE + READ)
end

-- (over the bottom bar on the right: the countdown)
local card = CreateFrame("Frame", nil, texts)
card:SetSize(380, 120)
card:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", -80, 36)
local clock = Text(card, 38, 1, 0.94, 0.8)
clock:SetPoint("BOTTOMRIGHT")
local label = Text(card, 13, 0.85, 0.82, 0.76)
label:SetPoint("BOTTOMRIGHT", clock, "TOPRIGHT", 0, 2)
label:SetText("Benefits in")
-- (logging out: how to cancel, under the clock; the pad's own glyph with the pad)
local hint = Text(card, 14, 0.85, 0.82, 0.76)
hint:SetPoint("TOPRIGHT", clock, "BOTTOMRIGHT", 0, -6)
hint:Hide()
-- (logging out with the mouse: the popup's buttons as ours, top right, over the bar; its
-- functions, not a click on the game's hidden ones. In a frame of our own, above the HUD)
local actions = CreateFrame("Frame", nil, UIParent)
actions:SetFrameStrata("DIALOG")
actions:SetSize(240, 30)
actions:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -34)
actions:Hide()
-- (flat, dark, thin gold rule, the scene's own face: lit when the mouse is over)
local function ActionButton(text, run)
    local b = CreateFrame("Button", nil, actions)
    b:SetSize(112, 30)
    local fill = b:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.45)
    local rules = {}
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local r = b:CreateTexture(nil, "BORDER")
        r:SetColorTexture(1, 0.82, 0.45, 1)
        r:SetPoint(p[1])
        r:SetPoint(p[2])
        if p[3] then r:SetHeight(1) else r:SetWidth(1) end
        rules[#rules + 1] = r
    end
    local face = b:CreateFontString(nil, "OVERLAY")
    if not face:SetFont(FONT, 16, "") then face:SetFont(STANDARD_TEXT_FONT, 16, "") end
    face:SetPoint("CENTER", 0, 1)
    face:SetShadowOffset(1, -1)
    face:SetShadowColor(0, 0, 0, 1)
    face:SetText(text)
    local function Light(on)
        fill:SetColorTexture(1, 0.82, 0.45, on and 0.18 or 0)
        if not on then fill:SetColorTexture(0, 0, 0, 0.45) end
        for _, r in ipairs(rules) do r:SetAlpha(on and 0.95 or 0.45) end
        face:SetTextColor(1, on and 0.94 or 0.82, on and 0.8 or 0.55)
    end
    Light(false)
    b:SetScript("OnEnter", function() Light(true) end)
    b:SetScript("OnLeave", function() Light(false) end)
    b:SetScript("OnClick", function() pcall(run) end)
    return b
end
local cancelButton = ActionButton("Cancel", function()
    pcall(CancelLogout)
    C.Leave() -- (the scene out at once; the game's event may come late or not at all)
end)
cancelButton:SetPoint("RIGHT")
local exitButton = ActionButton("Exit now", function() ForceQuit() end)
exitButton:SetPoint("RIGHT", cancelButton, "LEFT", -8, 0)

local title = Text(card, 18, 1, 0.82, 0.45)
title:SetPoint("BOTTOMRIGHT", label, "TOPRIGHT", 0, 6)
title:SetText(WELCOMING)

-- (a third of the way down, in the middle: the benefits given, under a
-- gold rule fading out to both sides)
local summary = CreateFrame("Frame", nil, texts)
summary:SetSize(700, 400)
summary:SetAlpha(0)
local sumTitle = Text(summary, 30, 1, 0.82, 0.45)
sumTitle:SetPoint("TOP")
sumTitle:SetText(BENEFITS)
local function Rule(point, fromA, toA)
    local r = summary:CreateTexture(nil, "OVERLAY")
    r:SetColorTexture(1, 0.82, 0.45, 1)
    r:SetSize(260, 1)
    r:SetPoint(point, sumTitle, "BOTTOM", 0, -10)
    if not pcall(r.SetGradient, r, "HORIZONTAL", CreateColor(1, 0.82, 0.45, fromA), CreateColor(1, 0.82, 0.45, toA)) then
        r:SetAlpha(0.6)
    end
    return r
end
Rule("TOPRIGHT", 0, 0.8)
Rule("TOPLEFT", 0.8, 0)

-- (a benefit's line made short, a part per stat: "Enchanted Lute: Armor
-- increased by 28, all attributes increased by 2, and all resistances
-- increased by 5." -> "+28 Armor", "+2 All Attributes", "+5 All
-- Resistances"; a stat at 0 left out; else the line after its object)
local function Title(text)
    return (text:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
local function Shorts(text)
    text = text:gsub("%.%s*$", "")
    local out = {}
    for part in (text:gsub(", and ", ", ") .. ","):gmatch("%s*(.-),") do
        local what, n = part:match("^(.-) increased by ([%d%.]+%%?)$")
        if what then
            if what:lower():find("critical") then what = "Critical Strike" end
            if tonumber((n:gsub("%%", ""))) ~= 0 then out[#out + 1] = "+" .. n .. " " .. Title(what) end
        end
    end
    if #out > 0 then return out end
    local mana = text:match("^Restores (%d+) Mana every 5 seconds")
    if mana then return { "+" .. mana .. " Mana every 5 sec" } end
    if text:lower():find("rest") and text:lower():find("experience") then return { "Rested Experience" } end
    return { text }
end

local function Icon(object)
    local item = ITEMS[object]
    local ok, icon = pcall(C_Item.GetItemIconByID, item)
    return ok and icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local given = false -- (the camp's benefits given, in this scene)

-- (an item per camp object, a column centred: its icon, its stats short
-- under it a line each, the object under those)
local ICON, TEXT_GAP, COL_GAP, ROW_GAP = 40, 10, 60, 22
local COLUMNS = 3
local items = {}
local function Item(i)
    local item = items[i]
    if item then return item end
    item = CreateFrame("Frame", nil, summary)
    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetSize(ICON, ICON)
    item.icon:SetPoint("TOP")
    item.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    item.frame = item:CreateTexture(nil, "ARTWORK", nil, -1)
    item.frame:SetPoint("TOPLEFT", item.icon, -1, 1)
    item.frame:SetPoint("BOTTOMRIGHT", item.icon, 1, -1)
    item.frame:SetColorTexture(1, 0.82, 0.45, 0.4)
    item.text = Text(item, 18, 0.97, 0.94, 0.88)
    item.text:SetPoint("TOP", item.icon, "BOTTOM", 0, -TEXT_GAP)
    item.text:SetJustifyH("CENTER")
    item.text:SetSpacing(4)
    item.object = Text(item, 12, 0.8, 0.7, 0.5)
    item.object:SetPoint("TOP", item.text, "BOTTOM", 0, -4)
    items[i] = item
    return item
end

-- (COLUMNS to a row under the rule, left to right then down, each row
-- centred (a last one short too); a cell as wide as the widest item, the
-- item in its middle; each row as tall as its tallest)
local function SetBenefits(rewards)
    local entries = {}
    for _, text in ipairs(rewards) do
        local object, rest = text:match("^([^:]+):%s*(.*)$")
        -- (an object's stats together, a line each under its icon)
        entries[#entries + 1] = { object = object, text = table.concat(Shorts(rest or text), "\n") }
    end
    local cellW, rowH = 0, {}
    for i, entry in ipairs(entries) do
        local item = Item(i)
        item.icon:SetTexture(Icon(entry.object))
        item.text:SetText(entry.text)
        item.object:SetText(entry.object or "")
        local w = math.max(ICON, item.text:GetStringWidth(), item.object:GetStringWidth())
        local h = ICON + TEXT_GAP + item.text:GetStringHeight() + 4 + item.object:GetStringHeight()
        item:SetSize(w, h)
        local row = math.floor((i - 1) / COLUMNS) + 1
        cellW = math.max(cellW, w)
        rowH[row] = math.max(rowH[row] or 0, h)
        item:Show()
    end
    for i = #entries + 1, #items do items[i]:Hide() end
    local rowY, y = {}, -(sumTitle:GetStringHeight() + 34)
    for r, h in ipairs(rowH) do rowY[r], y = y, y - h - ROW_GAP end
    for i = 1, #entries do
        local row, col = math.floor((i - 1) / COLUMNS) + 1, (i - 1) % COLUMNS
        local inRow = math.min(COLUMNS, #entries - (row - 1) * COLUMNS)
        items[i].x = (col - (inRow - 1) / 2) * (cellW + COL_GAP)
        items[i].y = rowY[row]
    end
end

-- (one by one, left to right then down: each in and rising, a beat after the last)
local ITEM_AT, ITEM_EVERY, ITEM_TIME, RISE = 0.8, 0.35, 0.6, 12
local sumT = 0
local function StepItems(dt)
    sumT = given and sumT + dt or 0
    for i, item in ipairs(items) do
        if item.x then
            local p = Smooth((sumT - ITEM_AT - (i - 1) * ITEM_EVERY) / ITEM_TIME)
            item:SetAlpha(p)
            item:ClearAllPoints()
            item:SetPoint("TOP", summary, "TOP", item.x, item.y - RISE * (1 - p))
        end
    end
end

---------------------------------------------------------------------------
-- The chat, in the bottom bar: what's said near you and whispered, the
-- rest of the chat left out (channels, party, guild, the game's own lines),
-- centred, as subtitles: "Name: words", the name in its class colour; under
-- them a line to talk in, unseen (its "Say:" too) till Enter (the key,
-- bound over the game's while the scene's on) puts you in it, gone again
-- when you're out: Enter sends (a keypress: SendChatMessage's hardware event), Escape
-- drops it. Say, unless it starts /s, /p, /g, /y, /e, /i, /ra, /w name,
-- /r or /1-/9; the last kind used kept, as the game's chat keeps it. A
-- line kept from the chat's events (CHAT_LIMIT of them, the scene shows
-- the latest); a secret one handed on as it is, never read.
---------------------------------------------------------------------------
local CHAT_LINES, CHAT_KEEP, CHAT_SHOWN = 3, 40, 30
local chat = CreateFrame("ScrollingMessageFrame", nil, texts)
chat:SetPoint("TOP", bottomBar, "TOP", 0, -8)
chat:SetJustifyH("CENTER")
chat:SetMaxLines(CHAT_KEEP)
chat:SetFading(true)
chat:SetTimeVisible(CHAT_SHOWN)
chat:SetFadeDuration(3)
-- (subtitles as a cutscene has them: the game's bold face, big, outlined)
local SUBTITLE_FONT, SUBTITLE_SIZE = "Fonts\\FRIZQT__.TTF", 21
if not chat:SetFont(SUBTITLE_FONT, SUBTITLE_SIZE, "OUTLINE") then chat:SetFontObject(ChatFontNormal) end
chat:SetShadowColor(0, 0, 0, 1)
chat:SetShadowOffset(1, -1)
chat:SetSpacing(4)
chat:EnableMouse(false)

-- (the kinds shown: the event, how its line reads, its words' colour)
local SHOWN = {
    CHAT_MSG_SAY = { said = "%s: %s", kind = "SAY" },
    CHAT_MSG_WHISPER = { said = "%s whispers: %s", kind = "WHISPER" },
    CHAT_MSG_WHISPER_INFORM = { said = "To %s: %s", kind = "WHISPER" },
}
local WARM = { 0.94, 0.9, 0.82 }
local CHAT_LIMIT = 10
local said = {} -- (the latest lines: { text, r, g, b })

local function Colour(kind)
    if kind == "SAY" then return unpack(WARM) end
    local info = ChatTypeInfo and ChatTypeInfo[kind]
    if not info then return unpack(WARM) end
    -- (the game's colour, lightened towards the warm white)
    return (info.r + WARM[1]) / 2, (info.g + WARM[2]) / 2, (info.b + WARM[3]) / 2
end

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- (a name in its class colour, without its realm)
local function Speaker(name, guid)
    if Secret(name) or type(name) ~= "string" then return nil end
    local short = Ambiguate and Ambiguate(name, "short") or name:gsub("%-.*$", "")
    if guid and not Secret(guid) and GetPlayerInfoByGUID then
        local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
        local c = ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c and c.colorStr then return "|c" .. c.colorStr .. short .. "|r" end
    end
    return short
end

local function ChatAdd(line)
    pcall(chat.AddMessage, chat, line[1], line[2], line[3], line[4])
end

local listen = CreateFrame("Frame")
for event in pairs(SHOWN) do listen:RegisterEvent(event) end
listen:SetScript("OnEvent", function(_, event, text, name, _, _, _, _, _, _, _, _, _, guid)
    local how = SHOWN[event]
    local r, g, b = Colour(how.kind)
    local who = Speaker(name, guid)
    local line
    if Secret(text) or not who then
        line = { text, r, g, b }
    else
        line = { how.said:format(who, text), r, g, b }
    end
    said[#said + 1] = line
    if #said > CHAT_LIMIT then table.remove(said, 1) end
    if stage:IsShown() then ChatAdd(line) end
end)

-- (the latest lines back, when the scene begins)
local function ChatRebuild()
    chat:Clear()
    for i = math.max(1, #said - CHAT_LINES + 1), #said do ChatAdd(said[i]) end
end

local input = CreateFrame("EditBox", "ImprovedForeverCampChatInput", texts)
input:SetAutoFocus(false)
if not input:SetFont(SUBTITLE_FONT, 18, "OUTLINE") then input:SetFontObject(ChatFontNormal) end
input:SetShadowColor(0, 0, 0, 1)
input:SetShadowOffset(1, -1)
input:SetHeight(28)
input:SetPoint("BOTTOM", bottomBar, "BOTTOM", 0, 8)
input:SetJustifyH("LEFT")
input:SetMaxLetters(255)
local inputLine = input:CreateTexture(nil, "BACKGROUND")
inputLine:SetPoint("BOTTOMLEFT", 0, -2)
inputLine:SetPoint("BOTTOMRIGHT", 0, -2)
inputLine:SetHeight(1)
inputLine:SetColorTexture(1, 0.82, 0.45, 0.35)
local kindLabel = input:CreateFontString(nil, "OVERLAY")
kindLabel:SetFont(SUBTITLE_FONT, 18, "OUTLINE")
kindLabel:SetPoint("RIGHT", input, "LEFT", -8, 0)
-- (the line, its kind and its rule drawn only while typed in: Enter
-- shows it)
input:SetAlpha(0)

-- (the kind of chat: its name, the game's colour for it)
local KINDS = {
    s = "SAY", say = "SAY", p = "PARTY", party = "PARTY", g = "GUILD", guild = "GUILD", y = "YELL", yell = "YELL",
    e = "EMOTE", em = "EMOTE", me = "EMOTE", emote = "EMOTE", i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT",
    ra = "RAID", raid = "RAID",
}
local KIND_NAMES = { SAY = "Say", PARTY = "Party", GUILD = "Guild", YELL = "Yell", EMOTE = "Emote",
    INSTANCE_CHAT = "Instance", RAID = "Raid", WHISPER = "To", CHANNEL = "Channel" }
local kind, target = "SAY", nil

local function ShowKind()
    local info = ChatTypeInfo and ChatTypeInfo[kind == "CHANNEL" and ("CHANNEL" .. tostring(target)) or kind]
        or ChatTypeInfo and ChatTypeInfo[kind]
    local r, g, b = info and info.r or 1, info and info.g or 1, info and info.b or 1
    local name = KIND_NAMES[kind] or kind
    if kind == "WHISPER" then name = name .. " " .. tostring(target) end
    if kind == "CHANNEL" then name = tostring(target) .. "." end
    kindLabel:SetText(name .. ":")
    kindLabel:SetTextColor(r, g, b)
    input:SetTextColor(r, g, b)
end

-- (a line's kind from how it starts: the kind, its target, the words; a
-- slash we don't know: nil)
local function Parse(text)
    local cmd, rest = text:match("^/(%S+)%s*(.*)$")
    if not cmd then return kind, target, text end
    cmd = cmd:lower()
    if KINDS[cmd] then return KINDS[cmd], nil, rest end
    if cmd == "w" or cmd == "whisper" or cmd == "t" or cmd == "tell" then
        local who, words = rest:match("^(%S+)%s*(.*)$")
        return "WHISPER", who, words or ""
    end
    if cmd == "r" or cmd == "reply" then
        local last = ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget()
        if last and last ~= "" then return "WHISPER", last, rest end
        return nil
    end
    if cmd:match("^%d$") then return "CHANNEL", tonumber(cmd), rest end
    return nil
end

input:SetScript("OnEditFocusGained", function(self) self:SetAlpha(1) end)
input:SetScript("OnEditFocusLost", function(self) self:SetAlpha(0) end)
input:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
end)
input:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    self:SetText("")
    self:ClearFocus()
    if text:match("^%s*$") then return end
    local k, to, words = Parse(text)
    if not k then return IF.Print("Only chat here: use the game's chat for other commands.") end
    if words:match("^%s*$") then
        kind, target = k, to
        return ShowKind()
    end
    local ok, err = pcall(SendChatMessage, words, k, nil, to)
    if not ok then return IF.Print("Couldn't send that: " .. tostring(err)) end
    if k ~= "EMOTE" then kind, target = k, to end
    ShowKind()
end)
-- (a kind typed with a space after it: switched to at once, as in the
-- game's chat)
input:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local text = self:GetText()
    local k, to, words = Parse(text)
    if k and text:match("^/%S+%s") and (k ~= "WHISPER" or text:match("^/%S+%s+%S+%s")) then
        kind, target = k, to
        self:SetText(words)
        ShowKind()
    end
end)

-- (Enter bound to the line while the scene's on: a click of ours)
local talk = CreateFrame("Button", "ImprovedForeverCampTalk", UIParent)
talk:SetSize(1, 1)
talk:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
talk:SetScript("OnClick", function() input:SetFocus() end)
local binds = CreateFrame("Frame")
local bindWanted
local function Bind(on)
    bindWanted = on
    if InCombatLockdown() then return end
    ClearOverrideBindings(binds)
    if on then SetOverrideBindingClick(binds, true, "ENTER", talk:GetName(), "LeftButton") end
end
binds:RegisterEvent("PLAYER_REGEN_ENABLED")
binds:SetScript("OnEvent", function() Bind(bindWanted) end)

-- (the chat setting off: no subtitles, Enter the game's)
local function ChatOn(on)
    on = on and C.Settings().chat
    chat:SetShown(on)
    if on then
        chat:SetWidth(UIParent:GetWidth() * 0.6)
        chat:SetHeight(math.max(30, barH - 50))
        input:SetWidth(UIParent:GetWidth() * 0.3)
        ShowKind()
        ChatRebuild()
    else
        input:SetText("")
        input:ClearFocus()
    end
    Bind(on)
end

local function Format(s)
    return ("%d:%02d"):format(math.floor(s / 60), math.floor(s % 60))
end

---------------------------------------------------------------------------
-- What the texts show: the words (one pass), the countdown, then the
-- benefits
---------------------------------------------------------------------------
local wordList, wordIndex, wordAt = {}, 0, 0
local benefitsAt -- (Camp Benefits' end when the scene began)
local cardA, sumA = 0, 0

local wordsX, wordsY = 0, 0 -- (where the words go for the shot: shares of the screen's width, height)

-- (the next line each WORDS_EVERY seconds, in over a second, out over the
-- last; the last one held; given: out, no more)
local function StepWords(dt)
    if given then
        words:SetAlpha(math.max(0, words:GetAlpha() - dt))
        return
    end
    wordAt = wordAt + dt
    if wordAt >= (words.time or WORDS_EVERY) and wordIndex < #wordList then
        wordAt = 0
        wordIndex = wordIndex + 1
        SetLine(wordList[wordIndex])
    end
    -- (word by word in; the line out together over its last second, the
    -- last line held)
    for i = 1, words.count or 0 do
        wordStrings[i]:SetAlpha(Smooth((wordAt - (i - 1) * WORD_EVERY) / WORD_FADE))
    end
    local a = wordIndex < #wordList and Smooth((words.time or WORDS_EVERY) - wordAt) or 1
    -- (dipping with the black; moved while it's black)
    words:SetAlpha(a * (1 - black:GetAlpha()))
    words:ClearAllPoints()
    words:SetPoint("CENTER", stage, "CENTER", wordsX * UIParent:GetWidth(), wordsY * UIParent:GetHeight())
end

local function StepTexts(dt)
    StepWords(dt)
    -- (the countdown out and the benefits in, rising a little)
    cardA = math.max(0, math.min(1, cardA + (given and -dt or dt)))
    card:SetAlpha(cardA)
    sumA = math.max(0, math.min(1, sumA + (given and dt / 1.5 or -dt)))
    summary:SetAlpha(Smooth(sumA))
    summary:ClearAllPoints()
    summary:SetPoint("TOP", stage, "TOP", 0, -(UIParent:GetHeight() / 3 - 40) - 14 * (1 - Smooth(sumA)))
    StepItems(dt)
end

-- (the card's words: the fire's, or the camp breaking up)
local function CardWords()
    local pad = IF.Input and IF.Input.Pad and IF.Input.Pad()
    hint:SetShown(logout ~= nil and pad and true or false)
    actions:SetShown(logout ~= nil and not pad)
    exitButton:SetShown(logout ~= nil and logout.quit and true or false)
    if logout then
        title:SetText(logout.quit and "Exiting the game" or "Logging out")
        label:SetText("Leaving in")
        -- (the pad: the game's popup, hidden under ours: quit has "Exit now" (A) as well as Cancel (B))
        local no = pad and IF.GlyphAtlas and IF.GlyphAtlas("B")
        local yes = pad and IF.GlyphAtlas and IF.GlyphAtlas("A")
        local cancel = no and ("|A:" .. no .. ":18:18|a Cancel") or "Cancel"
        if logout.quit and yes then
            hint:SetText("|A:" .. yes .. ":18:18|a Exit now     " .. cancel)
        else
            hint:SetText(no and ("Press |A:" .. no .. ":18:18|a to cancel") or "Press Esc to cancel")
        end
    else
        title:SetText(WELCOMING)
        label:SetText("Benefits in")
    end
end

local function Refresh()
    local left = Left()
    if logout then
        if left then clock:SetText(Format(left)) end
        return
    end
    local rewards, expires = C.Rewards()
    if not given and expires and (not benefitsAt or expires > benefitsAt + 1) and rewards and #rewards > 0 then
        given = true
    end
    if given and rewards and #rewards > 0 then
        SetBenefits(rewards)
    end
    if left and left > 0 then clock:SetText(Format(left)) end
end

---------------------------------------------------------------------------
-- The HUD faded (by an animation of ours, drawn at a): its avatars' 3D
-- models draw through it, hidden from half way
---------------------------------------------------------------------------
local hudA, modelsHidden = 1, false

local function Model(f, hide)
    local a = f.avatar
    if not (a and a.model) then return end
    if hide then
        a.model:Hide()
    elseif f.unit then
        local UF = IF.Interface and IF.Interface.UnitFrames
        if UF and UF.AvatarUnit then UF.AvatarUnit(a, f.unit, true) end
    end
end

local function Regions()
    local out = {}
    for _, name in ipairs(FADED) do
        local f = rawget(_G, name)
        if f then out[#out + 1] = f end
    end
    if not rawget(_G, "IFObjectiveTrackerFrame") and _G.ObjectiveTrackerFrame then
        out[#out + 1] = ObjectiveTrackerFrame
    end
    local PC = IF.Interface and IF.Interface.PartyCards
    for _, l in ipairs(PC and PC.labels or {}) do out[#out + 1] = l end
    return out
end

-- The minimap hidden, from half way: its arrow, blips and edge arrows are
-- the engine's, drawn whatever the alpha animation says. Hidden by its
-- frame (an exception to fading the game's frames: watch the taint log for
-- the minimap or Edit Mode), and shown again only if we hid it.
local mapHid = {}
local function MapHidden(hide)
    if hide then
        for _, name in ipairs({ "MinimapCluster", "Minimap" }) do
            local f = rawget(_G, name)
            if f and f:IsVisible() and not mapHid[f] then
                if pcall(f.Hide, f) then mapHid[f] = true end
            end
        end
    else
        for f in pairs(mapHid) do pcall(f.Show, f) end
        wipe(mapHid)
    end
end

-- (force: set again, frames shown since)
local function HUD(a, force)
    a = math.floor(a * 20 + 0.5) / 20
    if a == hudA and not force then return end
    hudA = a
    for _, f in ipairs(Regions()) do
        if a >= 1 then IF.Focus.Fade(f, false) else IF.Focus.Fade(f, true, a) end
    end
    local hide = a < 0.5
    MapHidden(hide)
    if hide ~= modelsHidden or force then
        modelsHidden = hide
        for _, name in ipairs(FADED) do
            local f = rawget(_G, name)
            if f then Model(f, hide) end
        end
    end
end

---------------------------------------------------------------------------
-- The camera: yours kept; each shot set while the screen is black, then
-- held with a slow pan. Where it's turned to is added up (yawDeg,
-- pitchDeg: degrees from where it began), to turn back on the way out.
---------------------------------------------------------------------------
local yawSpeed, pitchSpeed, yawDeg, pitchDeg = 0, 0, 0, 0
local yawRate, pitchRate = 180, 90
local zoomTarget
local shot, shotT = 0, 0

-- (+ right, at speed v; 0 stops)
local function Yaw(v)
    yawSpeed = v
    if v == 0 then
        pcall(MoveViewRightStop)
        pcall(MoveViewLeftStop)
    elseif v > 0 then
        pcall(MoveViewLeftStop)
        pcall(MoveViewRightStart, v)
    else
        pcall(MoveViewRightStop)
        pcall(MoveViewLeftStart, -v)
    end
end

-- (+ higher looking down, at speed v; 0 stops)
local function Pitch(v)
    pitchSpeed = v
    local down = v * PITCH_SIGN > 0
    if v == 0 then
        pcall(MoveViewUpStop)
        pcall(MoveViewDownStop)
    elseif down then
        pcall(MoveViewUpStop)
        pcall(MoveViewDownStart, math.abs(v))
    else
        pcall(MoveViewDownStop)
        pcall(MoveViewUpStart, math.abs(v))
    end
end

-- (turned to yaw and pitch, both there together: how long it takes)
local function TurnTo(yaw, pitch)
    local dy = (yaw - yawDeg + 180) % 360 - 180
    local dp = pitch - pitchDeg
    local time = math.max(math.abs(dy) / (TURN_SPEED * yawRate), math.abs(dp) / (TURN_SPEED * pitchRate))
    if time < 0.01 then
        Yaw(0)
        Pitch(0)
        return 0
    end
    Yaw(dy / (time * yawRate))
    Pitch(dp / (time * pitchRate))
    return time
end

-- (from where it is now: a distance past the game's limits isn't reached)
local function ZoomTo(target)
    if not target then return end
    zoomTarget = Zoom()
    if not zoomTarget then return end
    local d = target - zoomTarget
    if d < -0.1 then pcall(CameraZoomIn, -d) elseif d > 0.1 then pcall(CameraZoomOut, d) end
    zoomTarget = target
end

local function Saved()
    return IF.charDB and IF.charDB.campCamSaved
end

local function CameraSave()
    yawDeg, pitchDeg, zoomTarget = 0, 0, Zoom()
    yawRate = tonumber(GetCVarSafe("cameraYawMoveSpeed")) or 180
    pitchRate = tonumber(GetCVarSafe("cameraPitchMoveSpeed")) or 90
    if not IF.charDB or IF.charDB.campCamSaved then return end
    local saved = { zoom = Zoom(), cvars = {} }
    for _, name in ipairs(CVARS) do saved.cvars[name] = GetCVarSafe(name) end
    if C_CVar and C_CVar.SetTempCVar then saved.centered = GetCVarSafe(CENTERED) end
    IF.charDB.campCamSaved = saved
end

-- (yours set back, but the zoom speed while the distance goes back:
-- zoomBack, at once)
local function CameraRestore(zoomBack)
    Yaw(0)
    Pitch(0)
    local saved = Saved()
    if not saved then return end
    if zoomBack and saved.zoom then
        SetCVarSafe("cameraZoomSpeed", CUT_ZOOM_SPEED)
        ZoomTo(saved.zoom)
    end
    for name, value in pairs(saved.cvars or {}) do
        if name ~= "cameraZoomSpeed" or not zoomBack then SetCVarSafe(name, value) end
    end
    if saved.centered ~= nil and C_CVar and C_CVar.SetTempCVar then
        local ok, pad = pcall(C_CVar.GetCVarBool or GetCVarBool, "GamePadEnable")
        if ok and pad then pcall(C_CVar.SetTempCVar, CENTERED, saved.centered)
        elseif C_CVar.RemoveTempCVar then pcall(C_CVar.RemoveTempCVar, CENTERED) end
    end
end

-- (the zoom speed back once the distance is reached; the save forgotten)
local function CameraDone()
    local saved = Saved()
    if saved then SetCVarSafe("cameraZoomSpeed", saved.cvars and saved.cvars.cameraZoomSpeed) end
    if IF.charDB then IF.charDB.campCamSaved = nil end
    zoomTarget = nil
end

---------------------------------------------------------------------------
-- A cut: the picture to black, held while set (set() returns how long it
-- needs), done() at the end of the hold, back up
---------------------------------------------------------------------------
local cut -- { state, t, hold, set, done }

local function Cut(set, done)
    cut = { state = "down", t = black:GetAlpha() * CUT_DOWN, set = set, done = done }
end

local function StepCut(dt)
    if not cut then return end
    cut.t = cut.t + dt
    if cut.state == "down" then
        black:SetAlpha(Smooth(cut.t / CUT_DOWN))
        if cut.t >= CUT_DOWN then
            cut.state, cut.t = "hold", 0
            cut.hold = math.max(CUT_HOLD, cut.set and cut.set() or 0)
        end
    elseif cut.state == "hold" then
        black:SetAlpha(1)
        if cut.t >= cut.hold then
            if cut.done then cut.done() end
            cut.state, cut.t = "up", 0
        end
    else
        black:SetAlpha(1 - Smooth(cut.t / CUT_UP))
        if cut.t >= CUT_UP then cut = nil end
    end
end

-- (to shot i: turned and set while black, the words moved to its empty
-- side, then the pan)
-- (the next from a shuffled round of them, not the one just shown)
local order = {}
local function NextShot()
    if #order == 0 then
        for i = 1, #SHOTS do order[#order + 1] = i end
        for i = #order, 2, -1 do
            local j = math.random(i)
            order[i], order[j] = order[j], order[i]
        end
        if order[1] == shot and #order > 1 then order[1], order[2] = order[2], order[1] end
    end
    return table.remove(order, 1)
end

-- (the scene opens on any of the level shots, not always the same: the
-- ones looking steeply up or down over you open nothing well)
local OPENERS = { 1, 2, 4, 5, 6, 7, 9, 10, 11 }
local function FirstShot() return OPENERS[math.random(#OPENERS)] end

local function Shot(i)
    shot, shotT = i, 0
    local s = SHOTS[i]
    Cut(function()
        SetCVarSafe("cameraZoomSpeed", CUT_ZOOM_SPEED)
        SetCVarSafe("test_cameraOverShoulder", s.shoulder)
        SetCVarSafe("test_cameraDynamicPitchBaseFovPad", s.pad)
        ZoomTo(s.zoom)
        wordsX, wordsY = (s.words or 0) * WORDS_X, s.wordsY or WORDS_Y
        return TurnTo(s.yaw, s.pitch)
    end, function()
        Pitch(0)
        Yaw(s.pan / yawRate)
    end)
end

---------------------------------------------------------------------------
-- The timeline: in (the HUD out, the bars in, the first shot up from
-- black, the words) and out (black, the camera back, the bars and the HUD)
---------------------------------------------------------------------------
local phase, t, leftAt = nil, 0, -AGAIN
local away = 0 -- (seconds with neither fire aura, in the scene)
local from = {}
local bars, textA = 0, 0
local IN_TIME = 2.6

local function Phase(p)
    phase, t = p, 0
    from = { hud = hudA, bars = bars, text = textA }
end

local function Enter()
    Phase("in")
    -- (tall enough for three lines of subtitles and the line to talk in)
    barH = math.floor(UIParent:GetHeight() * 0.14)
    local rewards
    rewards, benefitsAt = C.Rewards()
    -- (a test's benefits are new however they start)
    if test then benefitsAt = nil end
    wordList, wordIndex, wordAt = LogoutLines() or (C.Settings().recap and Recap()) or Words(rewards), 1, 0
    SetLine(wordList[1])
    given, cardA, sumA = false, 0, 0
    CardWords()
    Refresh()
    stage:Show()
    CameraSave()
    if C_CVar and C_CVar.SetTempCVar then pcall(C_CVar.SetTempCVar, CENTERED, "0") end
    SetCVarSafe("test_cameraDynamicPitch", 1)
    wipe(order)
    Shot(FirstShot())
    ChatOn(true)
end

-- The game's logout / quit popup drawn at alpha 0 while the scene runs (an
-- animation of ours, never its properties): ours says how to cancel, the
-- popup still takes the pad's cancel and Esc underneath
local popupFaded = {}
local function PopupFade(on)
    if on then
        for i = 1, 4 do
            local f = rawget(_G, "StaticPopup" .. i)
            local which = f and f:IsShown() and f.which
            if (which == LOGOUT_POPUP[false] or which == LOGOUT_POPUP[true]) and not popupFaded[f] then
                IF.Focus.Fade(f, true, 0)
                popupFaded[f] = true
            end
        end
    else
        for f in pairs(popupFaded) do IF.Focus.Fade(f, false) end
        wipe(popupFaded)
    end
end

-- (fast: a fight; the camera back at once, no black)
local function Leave(fast)
    if phase ~= "in" and phase ~= "on" then return end
    leftAt, away, test, logout, pending = GetTime(), 0, nil, nil, nil
    PopupFade(false)
    actions:Hide()
    ChatOn(false)
    if fast then
        cut = nil
        black:SetAlpha(0)
        CameraRestore(true)
        Phase("out")
        return
    end
    Phase("leaving")
    -- (turned back to where it began, behind black)
    Cut(function()
        CameraRestore(true)
        return TurnTo(0, 0)
    end, function()
        Yaw(0)
        Pitch(0)
    end)
end

C.Leave = function(...) return Leave(...) end
function C.Active() return phase == "in" or phase == "on" end

stage:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    yawDeg = yawDeg + yawSpeed * yawRate * dt
    pitchDeg = pitchDeg + pitchSpeed * pitchRate * dt
    StepCut(dt)
    if phase == "in" then
        HUD(Tween(from.hud, 0, t, 0, 0.9))
        bars = Tween(from.bars, 1, t, 0.5, 1.7)
        textA = Tween(from.text, 1, t, 1.6, IN_TIME)
        if t >= IN_TIME then phase = "on" end
    elseif phase == "leaving" then
        textA = Tween(from.text, 0, t, 0, 0.5)
        -- (the black on its way back up: the rest goes)
        if not cut or cut.state == "up" then Phase("out") end
    elseif phase == "out" then
        bars = Tween(from.bars, 0, t, 0, 1)
        textA = Tween(from.text, 0, t, 0, 0.4)
        HUD(Tween(from.hud, 1, t, 0.4, 1.4))
        if t >= 1.6 and not cut then
            phase = nil
            HUD(1, true)
            Yaw(0)
            CameraDone()
            stage:Hide()
            return
        end
    end
    PlaceBars(bars)
    texts:SetAlpha(textA)
    actions:SetAlpha(textA)
    if phase == "in" or phase == "on" then
        StepTexts(dt)
        shotT = shotT + dt
        -- (logging out: the picture to black over the last seconds, no more cuts)
        local ending = logout and logout.endAt - GetTime() < LOGOUT_FADE + CUT_UP
        if ending then
            if not cut then
                black:SetAlpha(Smooth(1 - (logout.endAt - GetTime()) / LOGOUT_FADE))
            end
        elseif shotT >= SHOTS[shot].time and not cut then
            Shot(NextShot())
        end
    end
end)

---------------------------------------------------------------------------
-- When: in once sitting by the fire a moment, out on getting up
---------------------------------------------------------------------------
local function Moving()
    return (GetUnitSpeed("player") or 0) > 0 or (IsFalling and IsFalling()) or false
end

-- (the game's countdown popup showing: nil without the API, then taken as shown)
local function PopupShown(quit)
    if not StaticPopup_Visible then return true end
    local ok, shown = pcall(StaticPopup_Visible, LOGOUT_POPUP[quit])
    return not ok or shown ~= nil and shown ~= false
end

-- (a logout or quit began: the scene once its popup shows, an inn's instant
-- one never does)
local function LogoutStep()
    if not pending then return end
    if not PopupShown(pending.quit) then
        if GetTime() - pending.at > 1.5 then pending = nil end
        return
    end
    if IF.InCombat() or not C.Settings().logout then pending = nil return end
    if phase and not C.Active() then return end -- (the last scene still going out: next tick)
    local popup = StaticPopupDialogs and StaticPopupDialogs[LOGOUT_POPUP[pending.quit]]
    logout = { endAt = GetTime() + (popup and popup.timeout or LOGOUT_TIME), quit = pending.quit }
    pending, test = nil, nil
    if C.Active() then
        -- (a campfire scene already: its card and words turned to the logout's)
        wordList, wordIndex, wordAt = LogoutLines(), 1, 0
        SetLine(wordList[1])
        given = false
        CardWords()
        Refresh()
    else
        Enter()
    end
end

local still = 0
C.Watcher("camp scene", 0.25, function()
    if not IF.db then return end
    LogoutStep()
    local on = C.Settings().scene
    if logout then
        -- (the countdown's popup gone, or a step: cancelled)
        -- (past its end the game is logging out: the black stays; a test's end just ends it)
        if logout.fake and not Left() then return Leave() end
        if t > GRACE and Left() and (Moving() or not logout.fake and not PopupShown(logout.quit)) then return Leave() end
        if IF.InCombat() then return Leave(true) end
        HUD(hudA, phase == "on")
        PopupFade(true)
        Refresh()
        return
    end
    if C.Active() then
        -- (up: a step or a jump; a fight; the setting off; away from the
        -- fire a while, no Welcoming Campfire either. Not the Welcoming
        -- Campfire going alone: it comes and goes while you sit)
        local up = t > GRACE and Moving()
        away = (test or HasAura(NEARBY) or HasAura(WELCOMING)) and 0 or away + 0.25
        if IF.InCombat() then return Leave(true) end
        if up or away >= 2 or not on then return Leave() end
        HUD(hudA, phase == "on")
        Refresh()
        return
    end
    if phase or not on or IF.InCombat() or GetTime() - leftAt < AGAIN
        or Moving() or not HasAura(WELCOMING) then
        still = 0
        return
    end
    still = still + 0.25
    if still >= SETTLE then
        still = 0
        Enter()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterEvent("PLAYER_CAMPING")
events:RegisterEvent("PLAYER_QUITING")
events:RegisterEvent("LOGOUT_CANCEL")
-- (a fight: at once; a cast gets you up; a logout or quit begun: the scene
-- when its popup shows, LOGOUT_CANCEL: out)
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_CAMPING" or event == "PLAYER_QUITING" then
        pending = { quit = event == "PLAYER_QUITING", at = GetTime() }
    elseif event == "LOGOUT_CANCEL" then
        pending = nil
        if logout then Leave() end
    elseif not logout or event == "PLAYER_REGEN_DISABLED" then
        -- (a cast while logging out doesn't cancel it: the game's own rule decides)
        Leave(event == "PLAYER_REGEN_DISABLED")
    end
end)

function C.Test(seconds)
    if C.Active() then return Leave() end
    if phase then return end
    if IF.InCombat() then return IF.Print("Not in a fight.") end
    test = { endAt = GetTime() + (seconds or 20) }
    Enter()
end
IF.AddCommand("camptest", function(args) C.Test(tonumber(args[1])) end,
    "[seconds]: try the campfire scene without a fire (again, or a step: out)")

-- /if logouttest [seconds]: the logout scene without logging out (again, or a step: out)
function C.TestLogout(seconds)
    if C.Active() then return Leave() end
    if phase then return end
    if IF.InCombat() then return IF.Print("Not in a fight.") end
    logout = { endAt = GetTime() + (seconds or LOGOUT_TIME), fake = true }
    Enter()
end
IF.AddCommand("logouttest", function(args) C.TestLogout(tonumber(args[1])) end,
    "[seconds]: try the logout scene without logging out (again, or a step: out)")

-- /if campsummary [mine]: the scene straight at its benefits: every camp
-- object's; mine: yours, from the camp that gave them
local function Summary(args)
    if C.Active() then return Leave() end
    if phase then return end
    if IF.InCombat() then return IF.Print("Not in a fight.") end
    local rewards = args[1] == "mine" and C.Rewards() or nil
    if args[1] == "mine" and not (rewards and #rewards > 0) then return IF.Print("No camp benefits on you.") end
    test = { endAt = GetTime(), rewards = rewards }
    Enter()
end
C.Summary = function(mine) Summary({ mine and "mine" or nil }) end
IF.AddCommand("campsummary", Summary, "[mine]: the campfire scene's benefits summary (every camp object's; mine: yours. Again, or a step: out)")
IF.AddCommand("campsum", Summary)

-- (left in the camp camera by a /reload or a logout: yours back)
IF.OnLogin(function()
    Yaw(0)
    Pitch(0)
    if Saved() then
        zoomTarget = Zoom()
        CameraRestore(false)
        ZoomTo(Saved().zoom)
        CameraDone()
    end
    if IF.db then IF.db.campLog = nil end
end)
