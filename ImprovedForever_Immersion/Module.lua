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
IN.MP_H = 3
-- The health bar's, over it (PlayerHealth.lua): the old experience line's
IN.HP_H = 4

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

-- /if platecast [cast | channel | shield | interrupt | off]: a made-up cast on every
-- nameplate in sight, looping (Nameplates.lua)
IF.AddCommand("platecast", function(args) IN.Nameplates.Demo(args[1]) end,
    "[cast | channel | shield | interrupt | off]: a made-up cast on the nameplates in sight, to look at")

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
    nameplates = true,  -- the nameplates over mobs in our look: name, health line, level (the game's hidden)
    nameplateFont = "morpheus", -- the nameplates' name font (Nameplates.lua: N.FONTS)
    nameplateNameSize = 17, -- and its size
    nameplateHideBar = true, -- the friendly NPCs' nameplate health line and level badge hidden: the name alone
    nameplateClassColors = true, -- other players' name and health line in their class colour
    nameplateHideBarPlayers = false, -- the same for other players' nameplates
    nameplateHideFarNames = true, -- the game's own tiny names over units too far for a plate hidden (so no mix of its and our look)
    nameplateFriendlyNPCs = true, -- friendly NPCs get a plate too (turns the game's nameplateShowFriendlyNPCs on)
    dialogX = 0, dialogY = 0, -- the NPC subtitle's place (px right, px up)
    targetAuras = true, -- the target's debuffs (yours) and buffs as small icons under its header (TargetAuras.lua)
    castX = 0, castY = 0, -- the cast bar's place (px right, px up)
    gcd = false,        -- the global cooldown's swipe on the gamepad bar's tiles
    playerX = 0, playerY = 0, playerScale = 100, -- the player frame's place (px right, px up) and size (%)
    headerX = 0, headerY = 0, -- the header's (target, banners, quest arrow) place, px right / up
    nameplateCast = true, -- the unit's cast under its nameplate's line (its spell's name and icon)
    nameplateDebuffs = true, -- your debuffs on the mob, under its nameplate (the game fills them, in a fight too)
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
    recentLoot = true, -- your last four loots as tiles beside the bags' one, flying in from the loot window
    recentLootKey = false, -- the binding's controller press (RecentLoot.lua)
    padStyle = "diamond", -- its tiles: "diamond", "square" (rows and columns) or "circle" (GamepadBar.lua)
    padX = 0, padY = 0, padScale = 100, -- the action bar's place (px right, px up) and size (%)
    padSame = false,    -- the D-pad's tiles as big as the face buttons' (read as it loads: after a reload)
    partyX = 0, partyY = 0, -- the party cards' place, px right / up
    headerScale = 100,  -- the header's size (%)
    comboPoints = true, -- your combo points as small gems on the target header's rule (TargetHeader.lua)
    fullNames = false,  -- a player's last name after the first on the cards, header and plates (when the game has one)
    hudWidth = "off",   -- the HUD kept inside a screen ratio on an ultrawide: "off", "16:9" or "21:9" (IN.Inset)
    tourDone = false,   -- the first-time tour has been shown (Onboarding.lua)
    partyPad = false,   -- L1 ours: + the D-pad picks a party spell, + a face button casts it on party 1 to 4 (an experiment)
}

-- A watcher: fn() every `every` seconds. One that errors stops, said once
-- in chat: an error each tick would flood the game's error handler, whose
-- popup then runs from our stack and taints the controller's focus
-- (SetPreferredGamepadInteractTarget forbidden).
-- The room left empty at each side of the screen so the HUD fits the ratio of the setting hudWidth
-- (UIParent's units; 0 when off or the screen is no wider): the pieces anchored to the screen's
-- left and right edges move in by it
IN.WIDTHS = { off = false, ["16:9"] = 16 / 9, ["21:9"] = 21 / 9 }
function IN.Inset()
    if not IF.db then return 0 end
    local ratio = IN.WIDTHS[IN.Settings().hudWidth or "off"]
    if not ratio then return 0 end
    return math.max(0, math.floor((UIParent:GetWidth() - UIParent:GetHeight() * ratio) / 2 + 0.5))
end

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

-- A unit's name for our cards: the game's name, and with the setting fullNames a player's last name after it
-- (UnitFullName's second answer: Forever gives it where WoW has a realm). Secret strings go through as they
-- are, never joined or compared.
function IN.DisplayName(unit)
    local name = UnitName(unit)
    if not IF.db or not IN.Settings().fullNames then return name end
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return name end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or (issecretvalue and issecretvalue(isPlayer)) or not isPlayer then return name end
    local ok2, _, last = pcall(UnitFullName, unit)
    if ok2 and type(last) == "string" and last ~= "" and not (issecretvalue and issecretvalue(last)) then
        return name .. " " .. last
    end
    return name
end

-- A setting's default, for the reset buttons
IN.DEFAULTS = DEFAULTS

function IN.Settings()
    local db = IF.db
    db.plateLog = nil           -- (the nameplate probes' logs, done)
    db.plateFly = nil
    db.npLog = nil              -- (the nameplate probes' log, done)
    db.interface = db.interface or {}
    local settings = db.interface
    -- (the name's size default grew from 13 to 17: the old default moves up once)
    if not settings.nameplateSizeV2 then
        settings.nameplateSizeV2 = true
        if settings.nameplateNameSize == 13 then settings.nameplateNameSize = 17 end
    end
    for key, value in pairs(DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    -- (earlier ones moved the chat to the right or drew your auras, and the
    -- campfire scene was ours (the Camp module's now): their keys gone; the
    -- timelines' bar test's log too)
    settings.chat, settings.auras, settings.camp = nil, nil, nil
    settings.auctionScene = nil      -- (the auction house scene is gone: its classic window only)
    db.timelineBar = nil
    db.hudLog = nil
    -- (the breath probes' logs)
    db.breathLog, db.waterLog = nil, nil
    return settings
end
