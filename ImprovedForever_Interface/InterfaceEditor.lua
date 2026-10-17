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
            .. "place of the game's target frame. The health is coloured by what it is: a player by its class, "
            .. "else red if hostile, yellow if neutral, green if friendly, grey if tapped by others. With the "
            .. "mouse over it, its numbers.",
    }, Toggle("target", "Target health on top", function() IN.UnitFrames.Apply() end)),
    Item({
        key = "cards", group = "frames", label = "Minion and party cards",
        tip = "Your pet (Minions) and your party (Party) as cards standing on the experience line, either side "
            .. "of the middle, in place of the game's pet and party frames: each its model, its class colour round "
            .. "it, its level, name, health and power; faint when out of range. Click one to target it, right "
            .. "click for its menu. Hidden in a raid (the game's raid frames show).",
    }, Toggle("cards", "Minion and party cards", function() IN.PartyCards.Apply() end)),
    Item({
        key = "xp", group = "frames", label = "Experience line",
        tip = "Your experience as a thin line along the screen's bottom edge, the rested part beyond it, in "
            .. "place of the game's experience bar (its reputation bar at the top level stays). The mouse over "
            .. "it shows the numbers.",
    }, Toggle("xp", "Experience line", function() IN.XPBar.Apply() end)),
    Item({
        key = "pad", group = "pad", label = "Spell diamonds",
        tip = "The gamepad action bar laid out as Hogwarts Legacy's spells: bottom right, the face buttons' "
            .. "slots as a big diamond, the D-pad's as a smaller one beside it. Holding L2 / R2 (or both) "
            .. "swaps them to that set in place; the pips under them show which set is up. The game's bar "
            .. "still does every press: its slots are set as before (the Bindings tab, its own editor).",
    }, Toggle("pad", "Spell diamonds", function() IN.GamepadBar.Apply() end)),
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
