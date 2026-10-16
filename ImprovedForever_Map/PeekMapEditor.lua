-- The Map tab, a tab of settings (IF.SettingsPage, SettingsPage.lua): how
-- the peek map looks (opacity, size, place on the screen and an offset
-- from it: a slider each way; the quest names and the button legend on or
-- off); seen the next time it opens. Its press (a button, a key or a
-- touchpad corner) is set on the Bindings tab only (Binds.lua,
-- BindEditor.lua). PeekMap.lua does the work.
local IF = ImprovedForever

local menu = IF.Menu
local PeekMap = IF.PeekMap
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local LIMIT = 50   -- the offset's reach, in % of the screen

local function S()
    return PeekMap.Settings()
end

-- A choice of values: { { value, name }... } on a setting's key
local function Choice(key, label, choices)
    local byValue = {}
    for _, c in ipairs(choices) do byValue[c[1]] = c end
    return {
        value = function() return tostring(S()[key]) end,
        text = function()
            local c = byValue[S()[key]]
            return c and c[2] or (key == "size" and math.floor(S()[key] * 100 + 0.5) .. "% of the screen")
                or tostring(S()[key])
        end,
        options = function()
            local list = {}
            for _, c in ipairs(choices) do
                list[#list + 1] = { action = tostring(c[1]), name = c[2] }
            end
            return list
        end,
        choose = function(action)
            for _, c in ipairs(choices) do
                if tostring(c[1]) == action then
                    S()[key] = c[1]
                    menu.Toast(label .. ": " .. c[2])
                end
            end
        end,
    }
end

-- An offset, one way: a slider in whole % of the screen (kept as a share)
local function Offset(key, negative, positive)
    return {
        min = -LIMIT, max = LIMIT, step = 1,
        get = function() return math.floor(S()[key] * 100 + (S()[key] < 0 and -0.5 or 0.5)) end,
        set = function(v) S()[key] = v / 100 end,
        format = function(v)
            if v == 0 then return "0%" end
            return (v < 0 and negative or positive) .. " " .. math.abs(v) .. "%"
        end,
    }
end

local ITEMS = {
    Item({
        key = "alpha", group = "look", label = "Opacity",
        tip = "How solid the map is: lower shows more of the game through it.",
    }, Choice("alpha", "Opacity", {
        { 0.3, "30%" }, { 0.45, "45%" }, { 0.6, "60%" }, { 0.75, "75%" }, { 0.9, "90%" }, { 1, "100%" },
    })),
    Item({
        key = "size", group = "look", label = "Size",
        tip = "The map's height, of the screen's.",
    }, Choice("size", "Size", {
        { 0.4, "40% of the screen" }, { 0.5, "50% of the screen" }, { 0.6, "60% of the screen" },
        { 0.7, "70% of the screen" }, { 0.8, "80% of the screen" }, { 0.9, "90% of the screen" },
    })),
    Item({
        key = "anchor", group = "look", label = "Position",
        tip = "Where on the screen the map shows.",
    }, Choice("anchor", "Position", {
        { "CENTER", "Centre" }, { "TOP", "Top" }, { "BOTTOM", "Bottom" }, { "LEFT", "Left" }, { "RIGHT", "Right" },
        { "TOPLEFT", "Top left" }, { "TOPRIGHT", "Top right" }, { "BOTTOMLEFT", "Bottom left" },
        { "BOTTOMRIGHT", "Bottom right" },
    })),
    Item({
        key = "labels", group = "look", label = "Quest names",
        tip = "Each quest's name beside its node on the map, none over another. The focused quest's is gold.",
    }, OnOff(function() return S().labels end, function(on) S().labels = on end, "Quest names")),
    Item({
        key = "legend", group = "look", label = "Button legend",
        tip = "The buttons' prompts below the map while it's held (L2 / R2 change quest, L1 / R1 resize), shown"
            .. " with the controller.",
    }, OnOff(function() return S().legend end, function(on)
        S().legend = on
        if PeekMap.ShowLegend then PeekMap.ShowLegend() end
    end, "Button legend")),
    {
        key = "x", group = "look", label = "Offset left / right",
        tip = "Moves the map from its position, by a share of the screen's width.",
        slider = Offset("x", "Left", "Right"),
    },
    {
        key = "y", group = "look", label = "Offset up / down",
        tip = "Moves the map from its position, by a share of the screen's height.",
        slider = Offset("y", "Down", "Up"),
    },
}

local GROUPS = {
    { key = "look", label = "Peek map" },
}

IF.PeekMapEditor = IF.SettingsPage({ key = "map", label = "Map", module = "map", order = 50 }, GROUPS, ITEMS)
