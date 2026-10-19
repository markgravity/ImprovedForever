-- Improved Forever: Interface. The game's HUD rearranged: its player and
-- target frames hidden, ours in their place (UnitFrames.lua), your pet
-- and party as cards on the experience line (PartyCards.lua), the
-- experience bar a line along the bottom edge (XPBar.lua), the gamepad
-- bar as two diamonds bottom right (GamepadBar.lua), the chat as only its
-- lines while not in use (ChatView.lua, ChatFade.lua), set up in its tab
-- (InterfaceEditor.lua). The chat isn't moved: its place is Edit Mode's,
-- and Forever drops a layout saved from addon code (switching layouts
-- from it taints); the player moves it there once.
local IF = ImprovedForever

IF.AddModule({ key = "interface", label = "Interface", icon = IF.TEX .. "ic_mod_interface", addon = ... })

local IN = {}
IF.Interface = IN

-- The bottom padding the HUD's groups share, so their feet line up: the
-- player's avatar (UnitFrames.lua) and the gamepad bar's face buttons
-- diamond (GamepadBar.lua: its bottom point), the set pips and glyphs
-- under it still clear of the experience line and the health bar over it
IN.BOTTOM = 38
-- The experience line's height (XPBar.lua)
IN.XP_H = 8
-- The health bar's, over it (PlayerHealth.lua)
IN.HP_H = 5

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

-- /if padprobe: what the game's gamepad bar holds (GamepadBar.lua)
IF.AddCommand("padprobe", function() IN.GamepadBar.Probe() end, ": what the gamepad bar's buttons hold")

-- /if l1probe: what L1 and the face buttons run (PartyPad.lua)
-- /if tlprobe: what the game keeps secret for the timelines (BuffTimeline.lua)
IF.AddCommand("tlprobe", function() IN.BuffTimeline.Probe() end, ": log what the buff and cooldown timelines can read in a fight")
IF.AddCommand("l1probe", function() IN.PartyPad.Probe() end, ": log what L1 and the face buttons run (party targeting test)")
-- /if chatprobe: what keeps the game's chat shown (ChatFade.lua)
IF.AddCommand("chatprobe", function() IN.ChatFade.Probe() end, ": what keeps the game's chat shown")

local DEFAULTS = {
    player = true,      -- the player frame bottom left (and the pet's beside it)
    target = true,      -- the target's health on top, its name over it
    cards = true,       -- your pet and party as cards on the experience line
    cardFocus = "auto", -- the party cards as your role needs them: auto (your role), tank, healer, off
    chatAbove = true,   -- the chat over the player's frame (in the Edit Mode layout; a test)
    hudAuras = true,    -- your buffs and debuffs along the bottom (in the Edit Mode layout; a test)
    buffTimeline = true, -- your buffs and debuffs in a row along the bottom (the game's aura container), left of the party
    cooldownTimeline = true, -- your gamepad bar's and trinkets' cooldowns in a row along the bottom, right of the party
    hudCooldowns = true, -- the Cooldown Manager left of the spell diamonds (in the Edit Mode layout; a test)
    chatDim = true,     -- the chat as only its lines while not in use
    castBar = true,     -- your casts as a long line over the party cards, filling out from the middle
    castRange = true,   -- with the cast line: its diamond alone while not casting, grey with your target out of range
    hpLine = true,      -- your health as a bar over the experience line
    npcDialog = true,   -- talking to an NPC (quests, gossip) as subtitles low in the middle, Spoken's voice with it
    xp = true,          -- the experience as a line along the screen's bottom edge
    pad = true,         -- the gamepad bar as Hogwarts Legacy's spell diamonds, bottom right
    padStyle = "square", -- its tiles: "diamond", "square" (rows and columns) or "circle" (GamepadBar.lua)
    partyPad = false,   -- L1 ours: + the D-pad picks a party spell, + a face button casts it on party 1 to 4 (a test)
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
            IF.Print("Interface: " .. name .. " stopped after an error: " .. tostring(err))
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
    -- (earlier ones moved the chat to the right or drew your auras: their
    -- keys gone; the timelines' bar test's log too)
    settings.chat, settings.auras = nil, nil
    db.timelineBar = nil
    return settings
end
