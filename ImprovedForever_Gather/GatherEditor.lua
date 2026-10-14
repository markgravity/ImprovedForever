-- The Gather tab, a tab of settings (IF.SettingsPage, SettingsPage.lua): the
-- minimap labels and their hotkey, the skill colours, the alerts, and the
-- player's gathering skills. Gather.lua does the work.
local IF = ImprovedForever

local menu = IF.Menu
local Gather = IF.Gather
local N = IF.NodeScan
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff


local function S()
    return Gather.Settings()
end

-- A choice of values: { { value, name }... } on a setting's key
local function Choice(key, label, choices)
    local byValue = {}
    for _, c in ipairs(choices) do byValue[c[1]] = c end
    return {
        value = function() return tostring(S()[key]) end,
        text = function()
            local c = byValue[S()[key]]
            return c and c[2] or tostring(S()[key])
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
            Gather.ApplyAlert()
        end,
    }
end

-- (the labels' help, for the pad or the mouse and keyboard: IF.Input)
local LABELS_TIP_PAD = "Every herb and ore on the minimap gets its name beside it, in its skill colour."
    .. " Square records a hotkey that shows / hides them: one button, or hold one"
    .. " and press another (recording the same one again unbinds it). The buttons keep their own"
    .. " actions too. Also a touchpad corner or override action, or a key (recorded here too)."
local LABELS_TIP_MOUSE = "Every herb and ore on the minimap gets its name beside it, in its skill colour."
    .. " Click to show / hide them. A key does it too (right-click to record one), or /if nodes."
local ALERT_TIP_PAD = "The minimap is read every few seconds; a node worth having that appears pulses the controller,"
    .. " plays a sound and says what and where. Not in combat."
local ALERT_TIP_MOUSE = "The minimap is read every few seconds; a node worth having that appears plays a sound"
    .. " and says what and where (and pulses a controller, when one is used). Not in combat."

local SKILL_TIP = "Herbs and ore are coloured by the skill point they give, as the game colours recipes:"
    .. " orange always, yellow mostly, green rarely, grey never; red is beyond your skill."

local ITEMS = {
    Item({
        key = "labels", group = "labels", label = "Labels",
        tip = function() return IF.Input.Pad() and LABELS_TIP_PAD or LABELS_TIP_MOUSE end,
        bindable = true,
        chord = true,
        bindId = "gather",
        toggle = true,
        binding = function() return Gather.Key() end,
        keyText = function(size) return Gather.KeyText(size) end,
        note = function()
            if not N.Supported() then return "This client can't read the minimap." end
        end,
    }, OnOff(function() return S().labels end, function(on) Gather.SetLabels(on) end, "Labels")),
    Item({
        key = "colors", group = "labels", label = "Skill colours",
        tip = SKILL_TIP,
    }, OnOff(function() return S().colors end, function(on) S().colors = on end, "Skill colours")),
    Item({
        key = "need", group = "labels", label = "Skill needed",
        tip = "A herb or ore beyond your skill (red) shows the skill it needs after its name: Bruiseweed (100).",
    }, OnOff(function() return S().need end, function(on) S().need = on end, "Skill needed")),
    Item({
        key = "alert", group = "alert", label = "Alerts",
        tip = function() return IF.Input.Pad() and ALERT_TIP_PAD or ALERT_TIP_MOUSE end,
    }, OnOff(function() return S().alert end, function(on)
        S().alert = on
        Gather.ApplyAlert()
    end, "Alerts")),
    Item({
        key = "alertFor", group = "alert", label = "Alert for",
        tip = "Which nodes alert. Skill colours decide the first two.",
    }, Choice("alertFor", "Alert for", {
        { "skill", "Skill-ups (orange, yellow, green)" },
        { "gather", "Any I can gather" },
        { "any", "Any herb or ore" },
        { "all", "Anything on the minimap" },
    })),
    Item({
        key = "alertWith", group = "alert", label = "Alert with",
        tip = "How an alert tells you. The message at the top of the screen always shows; vibration needs"
            .. " Vibration on (Vibration tab).",
    }, Choice("alertWith", "Alert with", {
        { "both", "Vibration and sound" },
        { "vibe", "Vibration" },
        { "sound", "Sound" },
        { "show", "Message only" },
    })),
    Item({
        key = "interval", group = "alert", label = "Look every",
        tip = "How often the minimap is read for alerts.",
    }, Choice("interval", "Look every", {
        { 2, "2 seconds" }, { 3, "3 seconds" },
        { 5, "5 seconds" }, { 10, "10 seconds" },
    })),
    Item({
        key = "skills", group = "skills", label = "Your skills",
        tip = SKILL_TIP,
        text = function()
            local parts = {}
            for _, kind in ipairs({ "herb", "ore" }) do
                local skill = N.Skill(kind)
                parts[#parts + 1] = N.SkillName(kind) .. ": " .. (skill or "not learnt")
            end
            return table.concat(parts, "|n")
        end,
    }),
}

local GROUPS = {
    { key = "labels", label = "Minimap" },
    { key = "alert", label = "Alerts" },
    { key = "skills", label = "Skills" },
}

IF.GatherEditor = IF.SettingsPage({ key = "gather", label = "Gather", module = "gather", order = 40 }, GROUPS, ITEMS)

