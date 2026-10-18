-- The Interface tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- each change to the game's HUD on / off. UnitFrames.lua, XPBar.lua,
-- GamepadBar.lua, ChatView.lua and ChatFade.lua do the work.
local IF = ImprovedForever
local IN = IF.Interface

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function Toggle(key, label, after)
    return OnOff(function() return IN.Settings()[key] end, function(on)
        IN.Settings()[key] = on
        after()
    end, label)
end

local FOCUS_ORDER = { "auto", "tank", "healer", "off" }
local FOCUS_NAMES = { auto = "Automatic", tank = "Tank", healer = "Healer", off = "Off" }

local ITEMS = {
    Item({
        key = "player", group = "frames", label = "Player frame",
        tip = "Your name, health and power bottom left (your pet's beside it), in the look of the target's "
            .. "health on top, in place of the game's player frame. Click it to target yourself, right click "
            .. "for your menu.",
    }, Toggle("player", "Player frame", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "target", group = "frames", label = "Target health on top",
        tip = "The target's health across the top of the screen, its name over it, its casts under it, in "
            .. "place of the game's target frame. The bar is filled and coloured as the target's nameplate is; "
            .. "its level sits at the left (coloured by how hard it is, a skull when too high), and an elite, "
            .. "rare or boss shows the nameplate's dragon at the right and a gold or silver border. Under it, "
            .. "the quests it counts for and their progress. With the mouse over it, its numbers.",
    }, Toggle("target", "Target health on top", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "cards", group = "frames", label = "Minion and party cards",
        tip = "Your pet (Minions) and your party (Party) as cards standing on the experience line, either side "
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
        key = "xp", group = "frames", label = "Experience line",
        tip = "Your experience as a thin line along the screen's bottom edge, the rested part beyond it, in "
            .. "place of the game's experience bar (its reputation bar at the top level stays). The mouse over "
            .. "it shows the numbers.",
    }, Toggle("xp", "Experience line", function() IN.XPBar.Apply() end)),
    Item({
        key = "pad", group = "pad", label = "Spell diamonds",
        tip = "The gamepad action bar laid out as Hogwarts Legacy's spells: bottom right, the face buttons' "
            .. "slots as a big diamond of diamond tiles, the D-pad's as a smaller one beside it. Holding L2 / R2 (or both) "
            .. "swaps them to that set in place; the pips under them show which set is up. The game's bar "
            .. "still does every press: its slots are set as before (the Bindings tab, its own editor).",
    }, Toggle("pad", "Spell diamonds", function() IN.GamepadBar.Apply() end)),
    Item({
        key = "partyPad", group = "pad", label = "Party casting (L1, test)",
        tip = "A test, for any role, in a party or raid: L1 is ours instead of the game's friendly targeting. "
            .. "Held: the D-pad "
            .. "picks one of four party spells (kept until you pick another), and Square, Circle, Triangle "
            .. "and X cast it on party members 1 to 4, your target left as it is (the button shows on each "
            .. "card). With the cards' focus a tank's, a press casts on the monster that member is "
            .. "fighting, when there is one. The four spells are a diamond of their own after the party "
            .. "cards, the picked one alone at rest (all four while L1 is held or the spell book is open): "
            .. "drag a spell, item or macro onto a tile, off it to empty it. Off, or alone, L1 is the game's. L1 is "
            .. "taken out of combat only, while the game has the controller.",
    }, Toggle("partyPad", "Party casting (L1, test)", function() IN.PartyCards.Apply() end)),
    Item({
        key = "chatAbove", group = "chat", label = "Chat over your frame (test)",
        tip = "The chat moved over your player frame, written into your Edit Mode layout (a preset is copied "
            .. "as \"Improved Forever\") and made the active layout again, so the game moves it now. Done once "
            .. "per layout: moved again in Edit Mode, it stays where you put it. To undo it, pick your old "
            .. "layout in Edit Mode.",
    }, Toggle("chatAbove", "Chat over your frame (test)", function() IN.ChatPosition.Apply() end)),
    Item({
        key = "chatDim", group = "chat", label = "Immersive chat",
        tip = "While you aren't using the chat only its lines show, no box, tabs or edit box: each new line "
            .. "bright for a few seconds, then barely there. Typing, the controller on it or the mouse over "
            .. "it brings the game's chat back.",
    }, Toggle("chatDim", "Immersive chat", function() IN.ChatFade.Apply() end)),
}

local GROUPS = {
    { key = "frames", label = "Unit frames" },
    { key = "pad", label = "Gamepad bar" },
    { key = "chat", label = "Chat" },
}

IF.InterfaceEditor = IF.SettingsPage({ key = "interface", label = "Interface", module = "interface", order = 35 },
    GROUPS, ITEMS)
