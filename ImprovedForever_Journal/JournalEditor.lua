-- The Journal tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- what is kept (Journal.lua), for how long, and forgetting it.
local IF = ImprovedForever

local J = IF.Journal
local menu = IF.Menu
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function S()
    return J.Settings()
end

-- A dropdown of values: { { value, name } }
local function Choice(get, set, values, label)
    return {
        value = function() return tostring(get()) end,
        text = function()
            for _, v in ipairs(values) do
                if v[1] == get() then return v[2] end
            end
            return tostring(get())
        end,
        options = function()
            local out = {}
            for _, v in ipairs(values) do out[#out + 1] = { action = tostring(v[1]), name = v[2] } end
            return out
        end,
        choose = function(action)
            for _, v in ipairs(values) do
                if tostring(v[1]) == action then
                    set(v[1])
                    menu.Toast(label .. ": " .. v[2])
                end
            end
        end,
    }
end

local QUALITIES = { { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" } }
local KEEP = { { 30, "30 days" }, { 90, "90 days" }, { 365, "A year" }, { 0, "Forever" } }

local ITEMS = {
    Item({
        key = "enabled", group = "journal", label = "Journal",
        tip = "Keeps a diary of each day you play, for this character: where you went, the quests you finished,"
            .. " your fights and falls, what you found, earned and made. Read it as a book: /if journal, its key"
            .. " binding, or a wheel (the windows of Improved Forever): a day a page, its map plates and the"
            .. " people met; L1 / R1 (the ribbons) between the Diary and your Companions.",
    }, OnOff(function() return S().enabled end, function(on) S().enabled = on end, "Journal")),
    Item({
        key = "open", group = "journal", label = "Read it",
        tip = "Opens the journal.",
    }, { button = "Open", run = function() IF.JournalBook.Open() end }),
    Item({
        key = "voice", group = "journal", label = "Voice",
        tip = "How the journal is written: in the voice of your race (a dwarf's hearty words, a night elf's"
            .. " calm, a Forsaken's dry wit...), or another's. For this character.",
    }, {
        value = function() return IF.charDB.journal and IF.charDB.journal.voice or "auto" end,
        text = function()
            local picked = IF.charDB.journal and IF.charDB.journal.voice
            if picked and J.VOICES[picked] then return J.VOICES[picked].name end
            local _, token = J.Voice()
            return "Your race" .. (token and J.VOICES[token] and (" (" .. J.VOICES[token].name .. ")") or "")
        end,
        options = function()
            local out = { { action = "auto", name = "Your race" } }
            for _, token in ipairs(J.VOICE_ORDER) do out[#out + 1] = { action = token, name = J.VOICES[token].name } end
            return out
        end,
        choose = function(action)
            IF.charDB.journal = IF.charDB.journal or { v = 1, days = {} }
            IF.charDB.journal.voice = action ~= "auto" and action or nil
            menu.Toast("Voice: " .. (action == "auto" and "your race" or J.VOICES[action].name))
        end,
    }),
    Item({
        key = "road", group = "kept", label = "Your road",
        tip = "Where you walked, a point every few steps, for the map plates in the book to draw your road and"
            .. " where you stopped. Only your own position, never in an instance.",
    }, OnOff(function() return S().road end, function(on) S().road = on end, "Your road")),
    Item({
        key = "levels", group = "kept", label = "Levels and quests",
        tip = "Each level reached, the quests taken on and finished (their experience and coin).",
    }, OnOff(function() return S().levels end, function(on) S().levels = on end, "Levels and quests")),
    Item({
        key = "places", group = "kept", label = "Places",
        tip = "The lands you were in and how long, the areas you discovered, instances, flights and the"
            .. " hearthstone.",
    }, OnOff(function() return S().places end, function(on) S().places = on end, "Places")),
    Item({
        key = "fights", group = "kept", label = "Fights and deaths",
        tip = "How many foes you slew and which, the elites, rares and bosses among them (the ones you had in"
            .. " target), where you fell and to whom.",
    }, OnOff(function() return S().fights end, function(on) S().fights = on end, "Fights and deaths")),
    Item({
        key = "loot", group = "kept", label = "Loot, gold and crafting",
        tip = "The items you looted (of the quality below or better), the gold earned and spent, what you made,"
            .. " your profession skills and the recipes learned.",
    }, OnOff(function() return S().loot end, function(on) S().loot = on end, "Loot, gold and crafting")),
    Item({
        key = "minQuality", group = "kept", label = "Loot kept",
        tip = "The least quality of a looted item worth writing down.",
    }, Choice(function() return S().minQuality end, function(v) S().minQuality = v end, QUALITIES, "Loot kept")),
    Item({
        key = "keepDays", group = "days", label = "Keep days",
        tip = "How long a day stays in the journal; older days are thrown away at login.",
    }, Choice(function() return S().keepDays end, function(v) S().keepDays = v end, KEEP, "Keep days")),
    Item({
        key = "clear", group = "days", label = "Forget",
        tip = "Throws away every day of this character's journal, and the people met with what they said.",
        note = function()
            local days = #J.Days()
            return days == 0 and "Nothing written yet" or (days .. (days == 1 and " day, " or " days, ")
                .. J.EventCount() .. " entries")
        end,
        disabled = function() return #J.Days() == 0 end,
    }, { button = "Forget", run = function() J.Clear() end, confirm = true, confirmText = "Forget every day?" }),
}

local GROUPS = {
    { key = "journal", label = "Journal" },
    { key = "kept", label = "What is kept" },
    { key = "days", label = "Days" },
}

IF.JournalEditor = IF.SettingsPage({ key = "journal", label = "Journal", module = "journal", order = 75 }, GROUPS, ITEMS)
