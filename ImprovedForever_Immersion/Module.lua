-- Improved Forever: Interface. The game's HUD rearranged: its player and
-- target frames hidden, ours in their place (UnitFrames.lua), your pet
-- and party as cards along the bottom (PartyCards.lua), your health and
-- power as lines along the bottom edge (PlayerHealth.lua), the experience
-- bar a ring round the player frame (XPBar.lua), the gamepad
-- bar as two diamonds bottom right (GamepadBar.lua), the chat as only its
-- lines while not in use (ChatView.lua, ChatFade.lua), set up in its tab
-- (InterfaceEditor.lua), the focused quest's way as a header near the top
-- with a diamond arrow on its rule (QuestArrow.lua), the zone's name in
-- its place as you enter one (ZoneBanner.lua), your level ups there too
-- (LevelBanner.lua), quest progress (QuestProgress.lua), the target
-- (TargetHeader.lua), all taking turns (HeaderSlot.lua). The chat isn't moved: its place is Edit Mode's,
-- and Forever drops a layout saved from addon code (switching layouts
-- from it taints); the player moves it there once.
local IF = ImprovedForever

IF.AddModule({ key = "interface", label = "Immersion", icon = IF.TEX .. "ic_mod_immersion", addon = ... })

local IN = {}
IF.Interface = IN

-- The bottom padding the HUD's groups share, so their feet line up: the
-- player's avatar (UnitFrames.lua) and the gamepad bar's face buttons
-- diamond (GamepadBar.lua: its bottom point), the set pips and glyphs
-- under it still clear of the power line and the health bar over it
IN.BOTTOM = 38
-- The power line's height, on the bottom edge (PlayerHealth.lua)
IN.MP_H = 5
-- The health bar's, over it (PlayerHealth.lua): the old experience line's
IN.HP_H = 8

-- The game's colours of a monster's level against yours, its own when it
-- has them: green, yellow, orange, red (a card's alert, a cooldown's time
-- left: PartyCards.lua, GamepadBar.lua)
local function Difficulty(key, r, g, b)
    local c = QuestDifficultyColors and QuestDifficultyColors[key]
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return { r, g, b }
end
IN.LEVEL_COLORS = {
    Difficulty("standard", 0.25, 0.75, 0.25),
    Difficulty("difficult", 1, 0.82, 0),
    Difficulty("verydifficult", 1, 0.5, 0.25),
    Difficulty("impossible", 1, 0.1, 0.1),
}

-- /if cards [tank | healer | dps | off]: every minion and party card shown,
-- stand-ins in them, as that role sees them (PartyCards.lua)
IF.AddCommand("cards", function(args) IN.PartyCards.TogglePreview(args[1]) end,
    "[tank | healer | dps | off]: preview the minion and party cards (as that role sees them)")

-- /if loottest [n | clear]: n items from your bags flown into the recent
-- loot (RecentLoot.lua)
IF.AddCommand("loottest", function(args)
    IF.Print("Recent loot test: starting.")
    local ok, err = pcall(function() IN.RecentLoot.Test(args[1]) end)
    if not ok then IF.Print("Recent loot test failed: " .. tostring(err)) end
end,
    "[n | clear]: fly n items from your bags into the recent loot (or empty it)")

-- /if padprobe: what the game's gamepad bar holds (GamepadBar.lua)
IF.AddCommand("padprobe", function() IN.GamepadBar.Probe() end, ": what the gamepad bar's buttons hold")

-- /if l1probe: what L1 and the face buttons run (PartyPad.lua)
-- /if tlprobe: what the game keeps secret for the timelines (BuffTimeline.lua)
IF.AddCommand("tlprobe", function() IN.BuffTimeline.Probe() end, ": log what the buff and cooldown timelines can read in a fight")
IF.AddCommand("l1probe", function() IN.PartyPad.Probe() end, ": log what L1 and the face buttons run (party targeting test)")
-- /if arrowprobe: where the quest arrow points, and from what (QuestArrow.lua)
IF.AddCommand("arrowprobe", function() IN.QuestArrow.Probe() end, ": where the quest arrow points and from what")
-- /if zonetest: the zone's name as entering it shows it (ZoneBanner.lua)
IF.AddCommand("zonetest", function() IN.ZoneBanner.Test() end, ": show the zone name banner for the zone you're in")
-- /if leveltest [level]: the level up banner, made-up gains (LevelBanner.lua)
IF.AddCommand("leveltest", function(args) IN.LevelBanner.Test(args[1]) end,
    "[level]: show the level up banner (your next level, made-up gains)")
-- /if progresstest: a made-up objective counting up (QuestProgress.lua)
IF.AddCommand("progresstest", function() IN.QuestProgress.Test() end, ": show quest progress counting up (made up)")
-- /if rangeprobe: what the target header's range check reads (TargetHeader.lua)
IF.AddCommand("rangeprobe", function() IN.TargetHeader.RangeProbe() end, ": what the target's range check reads")
-- /if chatprobe: what keeps the game's chat shown (ChatFade.lua)
IF.AddCommand("chatprobe", function() IN.ChatFade.Probe() end, ": what keeps the game's chat shown")

local DEFAULTS = {
    player = true,      -- the player frame bottom left (and the pet's beside it)
    target = true,      -- the target in the header's place under the top: its health the rule, its name under it
    minion = true,      -- your pet as a card beside the player frame
    cards = true,       -- your party as cards along the bottom
    cardFocus = "auto", -- the party cards as your role needs them: auto (your role), tank, healer, off
    chatAbove = true,   -- the chat over the player's frame (in the Edit Mode layout; an experiment)
    hudAuras = true,    -- your buffs and debuffs along the bottom (in the Edit Mode layout; an experiment)
    buffTimeline = true, -- your buffs and debuffs in a row along the bottom (the game's aura container), left of the party
    cooldownTimeline = true, -- your gamepad bar's and trinkets' cooldowns in a row along the bottom, right of the party
    hudCooldowns = true, -- the Cooldown Manager left of the spell diamonds (in the Edit Mode layout; an experiment)
    chatDim = true,     -- the chat as only its lines while not in use
    castBar = true,     -- your casts as a long line over the party cards, filling out from the middle
    breath = true,      -- your breath under water as water filling the player frame, dropping as it runs out
    castRange = true,   -- the target header greyed while an enemy is out of your reach
    hpLine = true,      -- your health as a bar over the power line
    mpLine = true,      -- your power (mana, rage, energy...) as a bar along the screen's bottom edge
    questArrow = true,  -- the focused quest's way: a header near the top (its name, the yards left), a diamond arrow on its rule
    levelBanner = true, -- your level ups: ours, in the header's place and look
    questProgress = true, -- quest progress in the header's place a moment, the game's other notices under it (ours)
    zoneBanner = true,  -- the zone's name as you enter one: ours, in the quest arrow's place and look
    npcDialog = true,   -- talking to an NPC (quests, gossip) as subtitles low in the middle, Spoken's voice with it
    xp = true,          -- the experience as a ring round the player frame
    pad = true,         -- the gamepad bar as Hogwarts Legacy's spell diamonds, bottom right
    recentLoot = false, -- your last four loots as tiles beside the bags' one, flying in from the loot window (an experiment)
    padStyle = "square", -- its tiles: "diamond", "square" (rows and columns) or "circle" (GamepadBar.lua)
    partyPad = false,   -- L1 ours: + the D-pad picks a party spell, + a face button casts it on party 1 to 4 (an experiment)
}

-- A watcher: fn() every `every` seconds. One that errors stops, said once
-- in chat: an error each tick would flood the game's error handler, whose
-- popup then runs from our stack and taints the controller's focus
-- (SetPreferredGamepadInteractTarget forbidden).
function IN.Watcher(name, every, fn)
    local f = CreateFrame("Frame")
    local since = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        since = since + elapsed
        if since < every then return end
        since = 0
        local ok, err = pcall(fn)
        if not ok then
            self:SetScript("OnUpdate", nil)
            IF.Print("Immersion: " .. name .. " stopped after an error: " .. tostring(err))
        end
    end)
    return f
end

function IN.Settings()
    local db = IF.db
    db.interface = db.interface or {}
    local settings = db.interface
    for key, value in pairs(DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    -- (earlier ones moved the chat to the right or drew your auras, and the
    -- campfire scene was ours (the Camp module's now): their keys gone; the
    -- timelines' bar test's log too)
    settings.chat, settings.auras, settings.camp = nil, nil, nil
    db.timelineBar = nil
    db.hudLog = nil
    return settings
end
