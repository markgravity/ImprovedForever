-- The Fishing tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- the auto loot, the fishing bar, the session's panel, the fishing view and
-- its camera on / off. AutoLoot.lua, CastBar.lua, Panel.lua and View.lua
-- do the work.
local IF = ImprovedForever
local F = IF.Fishing

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function Toggle(key, label, after)
    return OnOff(function() return F.Settings()[key] end, function(on)
        F.Settings()[key] = on
        after()
    end, label)
end

local ITEMS = {
    Item({
        key = "bar", group = "fishing", label = "Fishing bar",
        tip = "Each cast of Fishing as a scene on the right of the screen: the bobber thrown out on its line, "
            .. "bobbing, a ring round it draining with the time left; a catch splashing in its colour and "
            .. "reeled in to a row of its items, the best one named; a fish that got away sinking. In place of "
            .. "the cast bar. With the fishing view on, your other casts (a lure put on) show on it too. Try "
            .. "it: /if fishshow, /if fishshow rare, /if fishshow miss, /if fishshow early, /if fishshow cancel.",
    }, Toggle("bar", "Fishing bar", function() F.ApplyBar() end)),
    Item({
        key = "panel", group = "fishing", label = "Session panel",
        tip = "While a fishing pole is in hand: the session's casts, catches, misses and time over the gamepad "
            .. "bar, and what it caught, the rarest first, the latest catch lit. /if fishreset starts a new "
            .. "session.",
    }, Toggle("panel", "Session panel", function() F.ApplyPanel() end)),
    Item({
        key = "autoLoot", group = "fishing", label = "Auto loot",
        tip = "With a fishing pole in hand, the game's auto loot on: a catch is taken at once and the loot "
            .. "window closes by itself (the fishing bar shows the catch). Your own setting comes back with "
            .. "the pole put away.",
    }, Toggle("autoLoot", "Auto loot", function() F.ApplyAutoLoot() end)),
    Item({
        key = "view", group = "view", label = "Fishing view",
        tip = "With a fishing pole in hand, out of a fight: the HUD steps back (only the health line, the "
            .. "target, the minimap, the session panel and the fishing bar left) and the camera comes in. "
            .. "Everything back with the pole put away or a fight begun.",
    }, Toggle("view", "Fishing view", function() F.ApplyView() end)),
    Item({
        key = "camera", group = "view", label = "Fishing camera",
        tip = "With the fishing view: the camera at your fishing distance, over your shoulder and pitched "
            .. "down, so you stand low on the left (the game's ActionCam settings: the game asks once to "
            .. "allow them, Accept). Your camera comes back with the pole put away. /if fishcam keeps the "
            .. "distance you're at; /if fishcam shoulder 0.8, /if fishcam pitch 0.3 frame you.",
    }, Toggle("camera", "Fishing camera", function() F.ApplyView() end)),
}

local GROUPS = {
    { key = "fishing", label = "Fishing" },
    { key = "view", label = "View" },
}

F.Editor = IF.SettingsPage({ key = "fishing", label = "Fishing", module = "fishing", order = 37 }, GROUPS, ITEMS)
