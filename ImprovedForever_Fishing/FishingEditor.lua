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

-- (a framing slider: its limits, the view's, seen at once while fishing.
-- The page's sliders step in whole numbers: this one's in units of `unit`)
local function CameraSlider(key, unit, format)
    local limit = F.CAMERA_LIMITS and F.CAMERA_LIMITS[key] or { 0, 1 }
    return {
        min = math.floor(limit[1] / unit + 0.5), max = math.floor(limit[2] / unit + 0.5), step = 1,
        get = function() return math.floor((F.CameraGet and F.CameraGet(key) or limit[1]) / unit + 0.5) end,
        set = function(n) if F.CameraSet then F.CameraSet(key, n * unit) end end,
        format = function(n) return format(n * unit) end,
    }
end

local ITEMS = {
    Item({
        key = "guide", group = "fishing", label = "Start / stop guide",
        tip = "A fishing pole in hand doesn't start fishing: a line on the screen says how. R2 twice, or a "
            .. "double right-click on the world, starts it (R2 then casts, R2 twice puts a lure on); Circle "
            .. "or Esc stops it, when no window is open (else they close the window). Off: no line, the "
            .. "presses still work.",
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
            .. "allow them, Accept). Your camera comes back when you stop fishing. /if fishcam keeps the "
            .. "distance you're at; /if fishcam shoulder 0.8, /if fishcam pitch 0.3 frame you.",
    }, Toggle("camera", "Fishing camera", function() F.ApplyView() end)),
    Item({
        key = "chat", group = "view", label = "Fishing chat",
        tip = "With the fishing view: the chat by the session panel, bottom right, every line faint and a "
            .. "new one bright for a while. Typing in the chat, or the mouse on it, brings the game's back.",
    }, Toggle("chat", "Fishing chat", function() F.ApplyChat() end)),
    {
        key = "zoom", group = "view", section = "Camera framing", label = "Distance",
        tip = "How far the camera sits from you while fishing. In fishing mode you see it change as you "
            .. "slide. /if fishcam keeps the distance you're at.",
        slider = CameraSlider("zoom", 0.5, function(v) return ("%.1f yd"):format(v) end),
    },
    {
        key = "shoulder", group = "view", section = "Camera framing", label = "Character left / right",
        tip = "How far the camera moves over your shoulder: higher puts you further left on the screen, "
            .. "lower further right (below 0: the other shoulder).",
        slider = CameraSlider("shoulder", 0.1, function(v)
            if math.abs(v) < 0.05 then return "Middle" end
            return ("%.1f %s"):format(math.abs(v), v > 0 and "left" or "right")
        end),
    },
    {
        key = "pitch", group = "view", section = "Camera framing", label = "Character low / high",
        tip = "How much of the screen is kept under your feet: lower puts you lower on the screen, the water "
            .. "and the sky more in view.",
        -- (its whole range, 0 to 0.4, shown as 0 to 100%)
        slider = CameraSlider("pitch", 0.004, function(v) return ("%d%%"):format(math.floor(v / 0.4 * 100 + 0.5)) end),
    },
}

local GROUPS = {
    { key = "fishing", label = "Fishing" },
    { key = "view", label = "View" },
}

F.Editor = IF.SettingsPage({ key = "fishing", label = "Fishing", module = "fishing", order = 37 }, GROUPS, ITEMS)
