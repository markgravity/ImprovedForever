-- The Vibration tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- under Settings, vibration on / off and its strength; under Events, the
-- events in sections (Combat; Casting: spell, gathering, crafting; Food &
-- drink; Wheel; Progress), each a dropdown of patterns (a kind of cast: of ready-made sets for its
-- four moments: casting, interrupted, cancelled, pushed back). Choosing
-- one sets it and plays it; Triangle plays it again.
local IF = ImprovedForever

local menu = IF.Menu
local V = IF.Vibe
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local GROUPS = { { key = "settings", label = "Settings" }, { key = "events", label = "Events" } }
-- (each event's section: its group's name)
local SECTION = {}
for _, g in ipairs(V.GROUPS) do SECTION[g.key] = g.label end

local function Enabled()
    if V.Settings().enabled then return true end
    menu.Toast("Vibration is off (Settings)", true)
    return false
end

-- An event's patterns: Off, its Match the... (Shooting: the weapon's;
-- Abilities: the move's), its family's patterns, then the general ones (the
-- actions' own only come with a cast's "Match the action")
local function Patterns(event)
    local entries = { { action = "off", name = "Off" } }
    if event.auto then entries[#entries + 1] = { action = "auto", name = event.auto } end
    for _, p in ipairs(V.PATTERNS) do
        if event.family and p[event.family] then entries[#entries + 1] = { action = p.key, name = p.label } end
    end
    for _, p in ipairs(V.PATTERNS) do
        if not p.action then
            entries[#entries + 1] = { action = p.key, name = p.label }
        end
    end
    return entries
end

local ITEMS = {
    Item({
        key = "enabled", group = "settings", label = "Vibration",
        tip = "The controller vibrates on the events in the other categories. Off: none of them does.",
    }, OnOff(function() return V.Settings().enabled end, function(on)
        V.Settings().enabled = on
        if on then V.Play("pulse") else V.Stop() end
    end, "Vibration")),
    {
        key = "intensity", group = "settings", label = "Strength",
        tip = "How strong every vibration is. Each change plays a pulse so you can feel it.",
        slider = {
            min = 1, max = 10, step = 1,
            get = function() return math.floor(V.Settings().intensity * 10 + 0.5) end,
            set = function(n)
                V.Settings().intensity = n / 10
                V.Play("pulse")
            end,
            format = function(n) return (n * 10) .. "%" end,
        },
        try = function() if Enabled() then V.Play("pulse") end end,
    },
}

-- (in the sections' order)
local RAIL = {}
for _, g in ipairs(V.GROUPS) do
    for _, rail in ipairs(V.RAIL) do
        if rail.group == g.key then RAIL[#RAIL + 1] = rail end
    end
end

for _, rail in ipairs(RAIL) do
    if rail.castKind then
        -- A kind of cast: one of the ready-made sets
        local kind = rail.castKind
        ITEMS[#ITEMS + 1] = {
            key = rail.key, group = "events", section = SECTION[rail.group], label = rail.label, tip = rail.tip,
            value = function() return V.CastPreset(kind) end,
            text = function()
                local preset = V.Preset(V.CastPreset(kind))
                if not preset or preset.key == "off" then return "|cffff7a5cOff|r" end
                if preset.auto then return preset.label .. "|n|cffb9ab8cEach action its own feel|r" end
                local parts = {}
                for _, phase in ipairs(V.CAST_PHASES) do
                    local pattern = V.Pattern(preset[phase])
                    local label = phase == "cast" and "Casting" or phase == "pushback" and "Pushed back"
                        or (phase:sub(1, 1):upper() .. phase:sub(2))
                    parts[#parts + 1] = label .. ": " .. (pattern and pattern.label or "—")
                end
                return preset.label .. "|n|cffb9ab8c" .. table.concat(parts, " · ") .. "|r"
            end,
            options = function()
                -- Off, Match the action, then the general sets (each action's
                -- own set only comes with Match the action)
                local entries = {}
                for _, p in ipairs(V.CAST_PRESETS) do
                    if not p.action then
                        entries[#entries + 1] = { action = p.key, name = p.label }
                    end
                end
                return entries
            end,
            -- (felt as a cast would go with it: each moment where it would come)
            try = function()
                if not Enabled() then return end
                if V.CastPreset(kind) == "off" then return menu.Toast(rail.label .. " is off", true) end
                V.SimulateCast(function(label)
                    if label then menu.Toast(rail.label .. ": " .. label) end
                end, kind)
            end,
        }
        local item = ITEMS[#ITEMS]
        item.choose = function(action)
            V.SetCastPreset(kind, action)
            local preset = V.Preset(action)
            menu.Toast(rail.label .. ": " .. (preset and preset.label or action))
            if action ~= "off" then item.try() end
        end
    else
        -- An event: its pattern
        local event = rail.subs[1]
        ITEMS[#ITEMS + 1] = {
            key = rail.key, group = "events", section = SECTION[rail.group], label = rail.label, tip = event.tip,
            value = function() return V.EventChoice(event.key) end,
            text = function()
                local choice = V.EventChoice(event.key)
                if choice == "auto" and event.family == "move" then
                    return event.auto .. "|n|cffb9ab8cEach ability its own feel|r"
                end
                local pattern = V.Pattern(V.EventPattern(event.key))
                if not pattern then return "|cffff7a5cOff|r" end
                if choice == "auto" then return event.auto .. "|n|cffb9ab8cNow: " .. pattern.label .. "|r" end
                return pattern.label
            end,
            options = function() return Patterns(event) end,
            choose = function(action)
                V.SetEventPattern(event.key, action)
                -- (Match the move: felt with the moves' run, Triangle)
                local key = not (action == "auto" and event.family == "move") and V.EventPattern(event.key)
                if key and V.Settings().enabled then V.Play(key) end
                local pattern = V.Pattern(key)
                local name = action == "auto" and event.auto .. (pattern and " (" .. pattern.label .. ")" or "")
                    or (pattern and pattern.label or "Off")
                menu.Toast(event.label .. ": " .. name)
            end,
            -- (a state that lasts plays on; a critical hit: a run of them)
            try = function()
                if not Enabled() then return end
                local pattern = V.EventPattern(event.key)
                if event.family == "move" and V.EventChoice(event.key) ~= "off" then
                    V.SimulateMoves(event.key, function(name)
                        local feel = V.Pattern(V.EventPattern(event.key))
                        menu.Toast(name .. (feel and ": " .. feel.label or ""))
                    end)
                elseif not pattern then
                    menu.Toast(event.label .. " is off", true)
                elseif event.loop then
                    if V.SimulateLoop(event.key, 6) then
                        menu.Toast(event.label .. ": playing (" .. IF.ButtonName("Y") .. " stops)")
                    else
                        menu.Toast(event.label .. ": stopped")
                    end
                elseif event.key == "shot" then
                    V.SimulateShots(event.key, function(n)
                        menu.Toast(event.label .. ": " .. V.Pattern(pattern).label .. (n > 1 and " x" .. n or ""))
                    end)
                elseif event.combo then
                    V.SimulateCombo(event.key, function(n)
                        menu.Toast(event.label .. (n > 1 and " x" .. n or ""))
                    end)
                else
                    V.Play(pattern)
                end
            end,
        }
    end
end

V.Editor = IF.SettingsPage({ key = "vibration", label = "Vibration", module = "vibration", order = 30 }, GROUPS, ITEMS,
    { hide = function() V.StopSimulation() end })

hooksecurefunc(menu, "Close", function() V.StopSimulation() end)
