-- The Quest Tracker tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- how the quest tracker sorts (Sort.lua) and the objective sound
-- (ObjectiveSound.lua). The same as the tracker's own sort menu (its filter
-- button, or R3 while it has the controller).
local IF = ImprovedForever

local IQT = IF.QuestTracker
local menu = IF.Menu
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

-- One of a list of { id, text } (IQT.SORTS, IQT.COMPLETED) on a setting
local function Choice(list, key, label, set)
    return {
        value = function() return IQT.Settings()[key] end,
        text = function()
            for _, e in ipairs(list) do
                if e.id == IQT.Settings()[key] then return e.text end
            end
            return tostring(IQT.Settings()[key])
        end,
        options = function()
            local options = {}
            for _, e in ipairs(list) do options[#options + 1] = { action = e.id, name = e.text } end
            return options
        end,
        choose = function(id)
            set(id)
            for _, e in ipairs(list) do
                if e.id == id then menu.Toast(label .. ": " .. e.text) end
            end
        end,
    }
end

local ITEMS = {
    Item({
        key = "sort", group = "sort", label = "Sort quests",
        tip = "The order of the tracked quests. Off keeps the game's own. By distance (WoW Forever) keeps the"
            .. " nearest on top as you move. When the tracker is full, the quests it shows are the top-sorted ones.",
    }, Choice(IQT.SORTS, "sort", "Sort quests", function(id) IQT.SetSort(id) end)),
    Item({
        key = "zoneFirst", group = "sort", label = "Current zone first",
        tip = "Quests in the zone you are in come before the others, whatever the sort.",
    }, OnOff(function() return IQT.Settings().currentZoneFirst end,
        function(on) IQT.SetCurrentZoneFirst(on) end, "Current zone first")),
    Item({
        key = "focusFirst", group = "sort", label = "Focused quest on top",
        tip = "The quest you focus (super-track) is always first.",
    }, OnOff(function() return IQT.Settings().focusFirst end,
        function(on) IQT.SetFocusFirst(on) end, "Focused quest on top")),
    Item({
        key = "completed", group = "sort", label = "Completed quests",
        tip = "Where quests ready to turn in go.",
    }, Choice(IQT.COMPLETED, "sortCompleted", "Completed quests", function(id) IQT.SetSortCompleted(id) end)),
    Item({
        key = "sound", group = "sound", label = "Objective complete",
        tip = "Plays a sound when an objective of a tracked quest completes.",
    }, OnOff(function() return IQT.Settings().objectiveSound end,
        function(on) IQT.SetObjectiveSound(on) end, "Objective sound")),
}

local GROUPS = {
    { key = "sort", label = "Sorting" },
    { key = "sound", label = "Sound" },
}

IF.QuestTrackerEditor = IF.SettingsPage({ key = "quests", label = "Quest Tracker", module = "quests", order = 45 },
    GROUPS, ITEMS)
