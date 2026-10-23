-- The General tab: the core's own features that have no tab of a module
-- (a tab of settings, IF.SettingsPage, SettingsPage.lua).
local _, IF = ...

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local ITEMS = {
    Item({
        key = "wandShoot", group = "gamepad", label = "Square shoots the wand",
        tip = "With a wand in your ranged slot, Square on a living enemy shoots it instead of swinging the "
            .. "melee weapon. L2 / R2 + Square stay the crossbar's; on a corpse, an NPC or an object Square is "
            .. "the game's own Interact. A Square override set in the Bindings tab wins over it.",
    }, OnOff(function() return IF.db.wandShoot ~= false end, function(on)
        IF.db.wandShoot = on
        IF.Override.Apply()
    end, "Square shoots the wand")),
    Item({
        key = "resetBindings", group = "gamepad", label = "Reset all bindings",
        tip = "Puts every binding back to its default: the buttons and keys of the Bindings tab, the actions "
            .. "put on presses and keys, and the touchpad's corners. The crossbar's own slots stay as they are.",
    }, {
        button = "Reset",
        run = function()
            if IF.InCombat() then return IF.Print("Not in combat.") end
            if IF.Binds.ResetAll() then IF.Print("Every binding is back to its default.") end
        end,
        confirm = true, confirmText = "Reset every binding to its default?",
    }),
}

local GROUPS = {
    { key = "gamepad", label = "Gamepad" },
}

IF.GeneralEditor = IF.SettingsPage({ key = "general", label = "General", icon = IF.TEX .. "ic_mod_general", order = 5 },
    GROUPS, ITEMS)
