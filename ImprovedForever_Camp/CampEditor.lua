-- The Camp tab, a tab of settings (IF.SettingsPage, SettingsPage.lua): the
-- campfire scene, its recap and its chat on / off, and a try of it (Scene.lua
-- does the work).
local IF = ImprovedForever
local C = IF.Camp

local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function Toggle(key, label)
    return OnOff(function() return C.Settings()[key] end, function(on) C.Settings()[key] = on end, label)
end

local ITEMS = {
    Item({
        key = "scene", group = "scene", label = "Campfire scene",
        tip = "Sitting by a campfire (its Welcoming Campfire on you), out of a fight: a cutscene. The HUD, "
            .. "the minimap and the tooltip go, black bars slide in, the camera cuts between shots round "
            .. "you; the time left until the camp's benefits, then the benefits a third of the way down. "
            .. "A step, a jump, a cast or a fight: all of it back as it was, your camera too.",
    }, Toggle("scene", "Campfire scene")),
    Item({
        key = "logout", group = "scene", label = "Logout scene",
        tip = "Logging out or quitting (the game's countdown): the same cutscene, the camp breaking up. "
            .. "The time left until you leave, a few last lines, the picture fading to black as it ends. "
            .. "The game's popup stays to cancel; a step or cancelling brings everything back.",
    }, Toggle("logout", "Logout scene")),
    Item({
        key = "recap", group = "scene", label = "Day recap",
        tip = "In the scene, while the camp's benefits count down: your day so far told back, a line at a "
            .. "time, word by word, from the Journal module's diary. Off, or without the Journal: what you "
            .. "do by the fire, from the camp's objects.",
    }, Toggle("recap", "Day recap")),
    Item({
        key = "chat", group = "scene", label = "Subtitles",
        tip = "In the scene, in the bottom bar: what's said and whispered near you as subtitles. Enter: a "
            .. "line to talk in (say, or /p, /g, /w name...), Enter sends, Esc drops it.",
    }, Toggle("chat", "Subtitles")),
    Item({
        key = "test", group = "try", label = "Try the scene",
        tip = "The scene without a fire: a short countdown, then every camp object's benefits. Again, or a "
            .. "step, ends it. /if camptest [seconds] too.",
    }, { button = "Try", run = function() C.Test() end }),
    Item({
        key = "summary", group = "try", label = "Benefits summary",
        tip = "The scene straight at its benefits: every camp object's. /if campsum too (/if campsum mine: "
            .. "the ones on you).",
    }, { button = "Show", run = function() C.Summary() end }),
}

local GROUPS = {
    { key = "scene", label = "Scene" },
    { key = "try", label = "Try it" },
}

C.Editor = IF.SettingsPage({ key = "camp", label = "Camp", module = "camp", order = 38 }, GROUPS, ITEMS)
