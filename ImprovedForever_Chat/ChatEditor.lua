-- The Chat tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- handwriting on the touchpad on / off, how long the finger stays off the
-- pad before the strokes are read (a letter or a word), and whether letters go in
-- as drawn or always in lower case. Handwriting.lua does the work.
local IF = ImprovedForever

local Ink = IF.Ink
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function S()
    return Ink.Settings()
end

local ITEMS = {
    Item({
        key = "enabled", group = "write", label = "Touchpad handwriting (beta)",
        tip = "While a text box has the focus (the chat, a search box...), write a letter or a whole word on the "
            .. "touchpad (letters side by side, the finger lifted between them) and it is typed in. Swipe right "
            .. "across the pad for a space, left to delete. PlayStation controllers only. A beta, off by default.",
    }, OnOff(function() return S().enabled end, function(on) S().enabled = on end, "Touchpad handwriting")),
    {
        key = "pause", group = "write", label = "Read after",
        tip = "How long the finger is off the pad before what was drawn is read and typed. Longer leaves more "
            .. "time between strokes and letters (the bar of a t, the next letter of a word).",
        slider = {
            min = 3, max = 12, step = 1,
            get = function() return math.floor(S().pause * 10 + 0.5) end,
            set = function(v) S().pause = v / 10 end,
            format = function(v) return ("%.1f s"):format(v / 10) end,
        },
    },
    Item({
        key = "lowercase", group = "write", label = "Always lower case",
        tip = "On: every letter goes in lower case. Off: a capital drawn (A, B, D, E...) goes in as a capital.",
    }, OnOff(function() return S().lowercase end, function(on) S().lowercase = on end, "Always lower case")),
}

local GROUPS = {
    { key = "write", label = "Handwriting" },
}

IF.ChatEditor = IF.SettingsPage({ key = "chat", label = "Chat", module = "chat", order = 65 }, GROUPS, ITEMS)
