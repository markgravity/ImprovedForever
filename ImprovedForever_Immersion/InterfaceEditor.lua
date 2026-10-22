-- The Interface tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- each change to the game's HUD on / off. UnitFrames.lua, XPBar.lua,
-- GamepadBar.lua, ChatView.lua, ChatFade.lua, NpcDialog.lua, QuestArrow.lua,
-- ZoneBanner.lua, LevelBanner.lua, TargetHeader.lua and QuestProgress.lua do
-- the work.
local IF = ImprovedForever
local IN = IF.Interface

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function Toggle(key, label, after)
    return OnOff(function() return IN.Settings()[key] end, function(on)
        IN.Settings()[key] = on
        after()
    end, label)
end

local STYLE_NAMES = { diamond = "Diamonds", square = "Squares", circle = "Circles" }

local FOCUS_ORDER = { "auto", "tank", "healer", "off" }
local FOCUS_NAMES = { auto = "Automatic", tank = "Tank", healer = "Healer", off = "Off" }

local ITEMS = {
    Item({
        key = "player", group = "frames", label = "Player frame",
        tip = "Your name, health and power bottom left (your pet's beside it), in place of the game's "
            .. "player frame. Click it to target yourself, right click "
            .. "for your menu.",
    }, Toggle("player", "Player frame", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "target", group = "frames", label = "Target header",
        tip = "The target in the header's place under the top of the screen (the quest arrow's and the "
            .. "zone names' look; it takes the place from the quest arrow while you have a target): its health "
            .. "as the line, out from the middle both ways in its nameplate's colour; on it a diamond with its "
            .. "portrait, its level under it (coloured by how hard it is, a skull when too high), an elite or "
            .. "rare's dragon beside it and a gold or silver rim. Under them its name big, the quests it "
            .. "counts for (else a player's guild, race and class, or an NPC's title and kind), then its "
            .. "casts as a thin line. In a fight only its name, smaller, and its casts. Click the diamond or the name to target it, right click for its menu. In "
            .. "place of the game's target frame.",
    }, Toggle("target", "Target header", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "cards", group = "frames", label = "Minion and party cards",
        tip = "Your pet (Minions) and your party (Party) as cards standing along the bottom, either side "
            .. "of the middle, in place of the game's pet and party frames: each its model in the tooltip's "
            .. "bronze frame, a strip in its class colour, its level, name, health and power; faint when out "
            .. "of range. Click one to target it, right click for its menu. Hidden in a raid (the game's raid "
            .. "frames show).",
    }, Toggle("cards", "Minion and party cards", function() IN.PartyCards.Apply() end)),
    Item({
        key = "cardFocus", group = "frames", label = "Party cards focus",
        tip = "What the party cards show for your role, a border coloured as a monster's level. Tank: who has "
            .. "a monster's attention, green to red by their threat, flashing red for the highest. Healer: "
            .. "who's hurt, green under 90% health to red, flashing red under 35%. Automatic: your assigned "
            .. "role's (none when you have none). /if cards tank (healer, dps) shows it on stand-ins.",
        value = function() return IN.Settings().cardFocus end,
        text = function() return FOCUS_NAMES[IN.Settings().cardFocus] or "" end,
        options = function()
            local list = {}
            for _, key in ipairs(FOCUS_ORDER) do list[#list + 1] = { action = key, name = FOCUS_NAMES[key] } end
            return list
        end,
        choose = function(action)
            IN.Settings().cardFocus = action
            IN.PartyCards.Apply()
        end,
    }),
    Item({
        key = "castBar", group = "frames", label = "Cast line",
        tip = "Your casts as a long thin line over the party cards, in place of the game's casting bar: a "
            .. "cast fills it from the middle out to both ends, a channel drains from both ends in to the "
            .. "middle, the spell's name over it. Yellow for a cast, green for a channel, grey while it can't "
            .. "be interrupted, red when it's cut. Edit Mode shows the game's bar.",
    }, Toggle("castBar", "Cast line", function() IN.PlayerCast.Apply() end)),
    Item({
        key = "castRange", group = "frames", label = "Target range",
        tip = "With an enemy targeted, the target header shows whether it's in reach of the longest-reaching "
            .. "harmful spell on your gamepad bar (a wand's Shoot, a bow's Auto Shot, a Frostbolt...): out of "
            .. "it, its portrait turns grey and its health line faint.",
    }, Toggle("castRange", "Target range", function() end)),
    Item({
        key = "hpLine", group = "frames", label = "Health line",
        tip = "Your health as a bar over the power line, drawn as it is: green, amber past half, red "
            .. "when low, the health just lost trailing. Shown in a fight and while you're hurt.",
    }, Toggle("hpLine", "Health line", function() IN.PlayerHealth.Apply() end)),
    Item({
        key = "mpLine", group = "frames", label = "Power line",
        tip = "Your mana, rage or energy as a bar along the screen's bottom edge, under the health line, in "
            .. "its own colour. Shown with the health line: in a fight, and while your mana or energy isn't "
            .. "full or you have rage.",
    }, Toggle("mpLine", "Power line", function() IN.PlayerHealth.Apply() end)),
    Item({
        key = "xp", group = "frames", label = "Experience ring",
        tip = "Your experience as a ring round your frame bottom left, the rested part beyond it, in place "
            .. "of the game's experience bar (its reputation bar at the top level stays). With your frame on. "
            .. "The mouse over your frame shows the numbers.",
    }, Toggle("xp", "Experience ring", function() IN.XPBar.Apply() end)),
    Item({
        key = "questArrow", group = "frames", label = "Quest arrow",
        tip = "The way to your focused quest (the one picked in the tracker or on the map) near the top of "
            .. "the screen, as the camp's summary header: a gold rule, under it the quest's name big in gold "
            .. "and the yards left small and white, and on the rule a 3D diamond lying on its side in "
            .. "perspective, hovering, turning as you do: green while you're headed its way, yellow, orange, "
            .. "then red turned away from it, and brighter dead on. In a fight only the diamond, small and plain (also while the game "
            .. "names a zone you enter). It gives its place "
            .. "to the target and to zone names, and comes back after. "
            .. "It points where "
            .. "the quest leads next (another zone's way in, its words small under the yards), else at the quest's "
            .. "place on the map. Gone once you're there (or inside its area on the map), on a flight, "
            .. "while an NPC talks, and where the game "
            .. "gives no way (an instance, another continent).",
    }, Toggle("questArrow", "Quest arrow", function() IN.QuestArrow.Apply() end)),
    Item({
        key = "levelBanner", group = "frames", label = "Level ups",
        tip = "Your level ups in the quest arrow's place and look, in place of the game's: the gold rule, on "
            .. "it a diamond with the game's level up arrow, \"Level 12\" big under it, what it gave small and white "
            .. "(+18 Health, +1 Strength...), what's new small in gold (talent points, the spells the game "
            .. "names). In a fight with a target it waits for the fight to end. /if leveltest shows it.",
    }, Toggle("levelBanner", "Level ups", function() IN.LevelBanner.Apply() end)),
    Item({
        key = "questProgress", group = "frames", label = "Quest progress",
        tip = "Quest progress (\"Necrotic Crystal Fragment: 6/12\") taking the header's place for a few "
            .. "seconds, as the target and zone names do (what was there comes back after): the line is the "
            .. "objective's progress, filling to the new count; on it a diamond with the quest mark (a check "
            .. "once done); under them the objective big, its count, its quest. In a fight with a living "
            .. "target it waits. The game's other notices (errors, \"Out of range\"...) move under the "
            .. "header, so nothing sits on it. /if progresstest shows it.",
    }, Toggle("questProgress", "Quest progress", function() IN.QuestProgress.Apply() end)),
    Item({
        key = "zoneBanner", group = "frames", label = "Zone names",
        tip = "The zone's name as you enter one in the quest arrow's place and look, in place of the game's: "
            .. "the gold rule, on it a diamond with the zone's picture (Spoken's, as its Compendium "
            .. "shows it), the name big under it, the subzone and "
            .. "the game's PvP words small under that. The quest arrow spins away for it and comes back "
            .. "after. /if zonetest shows it for the zone you're in.",
    }, Toggle("zoneBanner", "Zone names", function() IN.ZoneBanner.Apply() end)),
    Item({
        key = "pad", group = "pad", label = "Spell diamonds",
        tip = "The gamepad action bar laid out as Hogwarts Legacy's spells: bottom right, the face buttons' "
            .. "slots as a big diamond of diamond tiles, the D-pad's as a smaller one beside it. Holding L2 / R2 (or both) "
            .. "swaps them to that set in place; the pips under them show which set is up. The game's bar "
            .. "still does every press: its slots are set as before (the Bindings tab, its own editor). With the "
            .. "Gamepad UI off, the keyboard and mouse bar's 12 buttons are shown the same way as three groups of four, "
            .. "their keys written on them.",
    }, Toggle("pad", "Spell diamonds", function() IN.GamepadBar.Apply() end)),
    Item({
        key = "recentLoot", group = "pad", label = "Recent loot (experiment)",
        tip = "An experiment. Your last four loots as small tiles left of the bags' tile under the spell diamonds, the "
            .. "newest nearest it, the same item again added to its tile. Each is ringed in its quality's "
            .. "colour. An item taken from the loot window flies into them. Mouse over one for its tooltip.",
    }, Toggle("recentLoot", "Recent loot (experiment)", function() IN.RecentLoot.Apply() end)),
    Item({
        key = "padStyle", group = "pad", label = "Tile style",
        tip = "The shape of the gamepad bar's tiles (and of the party spells' and the cast line's): Diamonds, "
            .. "four to a group as one big diamond; Squares, the game's square slots in two rows and two "
            .. "columns; Circles, the game's round slots in a cross, as its own bar.",
        value = function() return IN.Settings().padStyle end,
        text = function() return STYLE_NAMES[IN.Settings().padStyle] or "" end,
        options = function()
            local list = {}
            for _, key in ipairs(IN.GamepadBar.STYLE_ORDER) do list[#list + 1] = { action = key, name = STYLE_NAMES[key] } end
            return list
        end,
        choose = function(action)
            IN.Settings().padStyle = action
            IN.GamepadBar.Apply()
        end,
    }),
    Item({
        key = "partyPad", group = "pad", label = "Party casting (L1, experiment)",
        tip = "An experiment, for any role, in a party or raid: L1 is ours instead of the game's friendly targeting. "
            .. "Held: the D-pad "
            .. "picks one of four party spells (kept until you pick another), and Square, Circle, Triangle "
            .. "and X cast it on party members 1 to 4, your target left as it is (the button shows on each "
            .. "card). With the cards' focus a tank's, a press casts on the monster that member is "
            .. "fighting, when there is one. The four spells are a diamond of their own after the party "
            .. "cards, the picked one alone at rest (all four while L1 is held or the spell book is open): "
            .. "drag a spell, item or macro onto a tile, off it to empty it. Off, or alone, L1 is the game's. L1 is "
            .. "taken out of combat only, while the game has the controller.",
    }, Toggle("partyPad", "Party casting (L1, experiment)", function() IN.PartyCards.Apply() end)),
    Item({
        key = "chatAbove", group = "chat", label = "Chat over your frame (experiment)",
        tip = "The chat moved over your player frame, written into your Edit Mode layout (a preset is copied "
            .. "as \"Improved Forever\") and made the active layout again, so the game moves it now. Done once "
            .. "per layout: moved again in Edit Mode, it stays where you put it. To undo it, pick your old "
            .. "layout in Edit Mode.",
    }, Toggle("chatAbove", "Chat over your frame (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "hudAuras", group = "frames", label = "Buffs along the bottom (experiment)",
        tip = "The game's buffs and debuffs moved to the bottom, between the minion and the party cards "
            .. "(debuffs on the bottom row, buffs over them, growing right), as big as the Cooldown Manager's "
            .. "icons, each with its effect in short on it (+5 STA), written into your Edit Mode "
            .. "layout as the chat is. Done once per layout: moved again in Edit Mode, they stay where you put "
            .. "them.",
    }, Toggle("hudAuras", "Buffs along the bottom (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "buffTimeline", group = "frames", label = "Buff row",
        tip = "Your buffs and debuffs in a row along the bottom, from the minion card toward the party "
            .. "cards: round icons, each with its time left and a thin line down to the power line, the "
            .. "soonest gone nearest the middle, debuffs nearest of all (tinted by their kind). The game fills "
            .. "the row itself, so it stays right in a fight. Mouse over one for its tooltip. In place of the "
            .. "game's buffs (hidden while it's on; Edit Mode shows them).",
    }, Toggle("buffTimeline", "Buff row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "cooldownTimeline", group = "pad", label = "Cooldown row",
        tip = "The cooldowns of what's on your gamepad bar (every slot of its page shown) and your on-use "
            .. "trinkets, in a row along the bottom from the party cards toward the spell diamonds: each "
            .. "shown while it cools, the soonest ready nearest the middle, sliding along as the order "
            .. "changes, coloured red to green as it runs down, flashing green as it comes ready, then gone. "
            .. "In place of the game's Cooldown Manager. In a fight the game hides cooldown times: each is "
            .. "timed from your cast, by the length it had out of one.",
    }, Toggle("cooldownTimeline", "Cooldown row", function() IN.BuffTimeline.Apply() end)),
    Item({
        key = "hudCooldowns", group = "pad", label = "Cooldowns beside the diamonds (experiment)",
        tip = "The game's Cooldown Manager (turn it on in the game's options) moved to the bottom, left of the "
            .. "spell diamonds: your main cooldowns on the bottom row, the utility ones over them, growing "
            .. "left. Written into your Edit Mode layout as the chat is; its own options choose what it "
            .. "shows.",
    }, Toggle("hudCooldowns", "Cooldowns beside the diamonds (experiment)", function() IN.HudLayout.Apply() end)),
    Item({
        key = "chatDim", group = "chat", label = "Immersive chat",
        tip = "While you aren't using the chat only its lines show, no box, tabs or edit box: each new line "
            .. "bright for a few seconds, then barely there. Typing, the controller on it or the mouse over "
            .. "it brings the game's chat back.",
    }, Toggle("chatDim", "Immersive chat", function() IN.ChatFade.Apply() end)),
    Item({
        key = "npcDialog", group = "chat", label = "NPC dialog as subtitles",
        tip = "Talking to an NPC (its greeting, quests offered, handed in, rewards, gossip) shown as a line of "
            .. "dialogue low in the middle of the screen: its face and name, its words, the quests and options "
            .. "under them, in place of the game's window. The controller works as on the game's window (the "
            .. "D-pad picks, A answers, B leaves, the right stick scrolls); the mouse clicks the lines. With "
            .. "Spoken installed, its voice reads the words: how far it is shows under them, with a button to "
            .. "stop or hear it again.",
    }, Toggle("npcDialog", "NPC dialog as subtitles", function() IN.NpcDialog.Apply() end)),
}

local GROUPS = {
    { key = "frames", label = "Unit frames" },
    { key = "pad", label = "Gamepad bar" },
    { key = "chat", label = "Chat" },
}

IF.InterfaceEditor = IF.SettingsPage({ key = "interface", label = "Immersion", module = "interface", order = 35 },
    GROUPS, ITEMS)
