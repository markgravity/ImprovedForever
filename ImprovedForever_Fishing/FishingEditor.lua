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
        key = "guide", group = "fishing", label = "Start / stop guide",
        tip = "A fishing pole in hand doesn't start fishing: a line on the screen says how. R2 twice, or a "
            .. "double right-click on the world, starts it (R2 then casts, R2 twice puts a lure on); Circle "
            .. "or Esc stops it, D-pad up (or Up) opens the Fish Collection, Triangle (or Alt + F) frames the "
            .. "camera, when no window is open (else they're the window's). Off: no line, the presses still "
            .. "work.",
    }, Toggle("guide", "Start / stop guide", function() end)),
    Item({
        key = "bar", group = "fishing", label = "Fishing bar",
        tip = "Each cast of Fishing as a scene on the right of the screen: the bobber thrown out on its line, "
            .. "bobbing, a ring round it draining with the time left; a catch splashing in its colour and "
            .. "reeled in to a row of its items, the best one named; a fish that got away sinking. In place of "
            .. "the cast bar. With the fishing view on, your other casts (a lure put on) show on it too. Try "
            .. "it: /if fishshow, /if fishshow rare, /if fishshow miss, /if fishshow early, /if fishshow cancel.",
    }, Toggle("bar", "Fishing bar", function() F.ApplyBar() end)),
    Item({
        key = "firstCatch", group = "fishing", label = "First catch",
        tip = "Something you've never caught before: a moment of its own on the right of the screen once the "
            .. "fishing bar's done (its icon, rays of its colour, sparks, how far your collection's got). Try "
            .. "it: /if fishshow first.",
    }, Toggle("firstCatch", "First catch", function() F.ApplyFirst() end)),
    Item({
        key = "book", group = "fishing", label = "Fish Collection",
        tip = "What you've fished up, recorded: every fish and item (junk left out) by rarity, a tick on "
            .. "each you've caught, when and where first. Cross on one reads its Wiki page. /if fishbook "
            .. "opens it too.",
    }, { button = "Open", run = function() F.Book.Open() end }),
    Item({
        key = "panel", group = "fishing", label = "Session panel",
        tip = "While a fishing pole is in hand: the session's casts, catches, misses and time over the gamepad "
            .. "bar, and what it caught, the rarest first, the latest catch lit. /if fishreset starts a new "
            .. "session.",
    }, Toggle("panel", "Session panel", function() F.ApplyPanel() end)),
    Item({
        key = "autoLoot", group = "fishing", label = "Auto loot",
        tip = "In fishing mode, the game's auto loot on: a catch is taken at once and the loot "
            .. "window closes by itself (the fishing bar shows the catch). Your own setting comes back with "
            .. "the pole put away.",
    }, Toggle("autoLoot", "Auto loot", function() F.ApplyAutoLoot() end)),
    Item({
        key = "view", group = "view", label = "Fishing view",
        tip = "In fishing mode, out of a fight: the HUD steps back (only the health line, the "
            .. "target, the minimap, the session panel and the fishing bar left) and the camera comes in. "
            .. "Everything back when you stop fishing, put the pole away or a fight begins.",
    }, Toggle("view", "Fishing view", function() F.ApplyView() end)),
    Item({
        key = "camera", group = "view", label = "Fishing camera",
        tip = "With the fishing view: the camera at your fishing distance, over your shoulder and pitched "
            .. "down, so you stand low on the left (the game's ActionCam settings: the game asks once to "
            .. "allow them, Accept). Your camera comes back when you stop fishing. To frame it: in fishing "
            .. "mode, Triangle (or Alt + F) and move it as the line top left says.",
    }, Toggle("camera", "Fishing camera", function() F.ApplyView() end)),
    Item({
        key = "chat", group = "view", label = "Fishing chat",
        tip = "With the fishing view: the chat by the session panel, bottom right, every line faint and a "
            .. "new one bright for a while. Typing in the chat, or the mouse on it, brings the game's back.",
    }, Toggle("chat", "Fishing chat", function() F.ApplyChat() end)),
    Item({
        key = "skillLine", group = "view", label = "Skill line",
        tip = "With the fishing view: your fishing skill as a line along the screen's bottom edge, as the "
            .. "health line, in the water's blue (a lure's bonus beyond it in sea green), its numbers "
            .. "over its left end; it flares as the skill goes up.",
    }, Toggle("skillLine", "Skill line", function() F.ApplySkillLine() end)),
}

local GROUPS = {
    { key = "fishing", label = "Fishing" },
    { key = "view", label = "View" },
}

F.Editor = IF.SettingsPage({ key = "fishing", label = "Fishing", module = "fishing", order = 37 }, GROUPS, ITEMS)
