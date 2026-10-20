-- The wheels, adapted from Easy Controller - Forever's MyWheels (moust4ki,
-- MIT License, see LICENSE-EasyController.md): the built-in ones
-- (Quest Items, Consumables, Emotes) and up to 8 of the player's own per
-- character, each of a kind (WheelKinds.lua): 8 slots holding the spells,
-- items, macros and emotes they pick, or one that fills itself (quest
-- items...). Each is a ring ("quest", "my<id>"...), opened by an R3 combo
-- or its own key binding. Configured in the panel's Wheels tab
-- (WheelEditor.lua), which works on the descriptions MW.Wheels() returns.
local IF = ImprovedForever

local MW = {}
IF.MyWheels = MW

MW.SLOTS = 8
MW.MAX = 8
MW.POSITIONS = { "Top", "Top right", "Right", "Bottom right", "Bottom", "Bottom left", "Left", "Top left" }

-- The built-in rings; the wheels are added after them
local BUILT_IN = { "native", "quest", "consumables", "emotes", "group", "camping", "panels" }
-- The built-in wheels, shown before the player's own
MW.BUILT_IN_WHEELS = { "quest", "consumables", "emotes", "group", "camping", "panels" }

---------------------------------------------------------------------------
-- The wheels: charDB.wheels = { { id = 1-8, name, kind (nil: "custom"),
-- slots = { [1-8] = "spell:133" } } }
---------------------------------------------------------------------------
function MW.List()
    IF.charDB.wheels = IF.charDB.wheels or {}
    return IF.charDB.wheels
end

function MW.Get(id)
    for _, w in ipairs(MW.List()) do
        if w.id == id then return w end
    end
end

function MW.Count(w)
    local n = 0
    for i = 1, IF.WheelKinds.Get(w.kind).max or MW.SLOTS do
        if w.slots[i] then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Hidden wheels (per character: charDB.hiddenWheels = { [ring key] =
-- true }): off the Bindings tab, not on the ring (L1 / R1), their presses
-- back to the game's (kept for when it's shown again). The Wheels tab
-- still lists them, dimmed: Square there shows one again.
---------------------------------------------------------------------------
function MW.HiddenList()
    IF.charDB.hiddenWheels = IF.charDB.hiddenWheels or {}
    return IF.charDB.hiddenWheels
end

function MW.Hidden(key)
    return IF.charDB and IF.charDB.hiddenWheels and IF.charDB.hiddenWheels[key] or false
end
IF.RingHidden = MW.Hidden

-- (Changed, below)
local Changed
function MW.SetHidden(key, hidden)
    MW.HiddenList()[key] = hidden or nil
    Changed()
end

-- A wheel of this kind exists ("quest"...)
function MW.HasKind(key)
    for _, w in ipairs(MW.List()) do
        if (w.kind or "custom") == key then return true end
    end
    return false
end

function MW.RingKey(id)
    return "my" .. id
end

-- (a chat phrase is its own name: WheelKinds.lua)
function MW.ActionName(action)
    local phrase = IF.WheelKinds.PhraseText(action)
    if phrase then return phrase end
    return (IF.ActionInfo(action))
end

function MW.ActionIcon(action)
    if IF.WheelKinds.PhraseText(action) then return IF.WheelKinds.PHRASE_ICON end
    return select(2, IF.ActionInfo(action))
end

MW.CATALOG = IF.Actions.CATALOG
local SPELLS, ITEMS, MACROS, EMOTES = unpack(MW.CATALOG)

-- As a ring: the filled slots in order, or what its kind fills it with
local function Builder(id)
    return function()
        local w = MW.Get(id)
        if not w then return {} end
        local kind = IF.WheelKinds.Get(w.kind)
        if kind.build then return kind.build({ max = kind.max, wheel = w }) end
        return IF.SlotEntries(w.slots, kind.max or MW.SLOTS)
    end
end

-- IF.RINGS / RING_LABELS / RingBuilders: the built-in rings, then the wheels
function MW.Register()
    local rings = {}
    for _, key in ipairs(BUILT_IN) do
        if not MW.Hidden(key) then rings[#rings + 1] = key end
    end
    for key in pairs(IF.RING_LABELS) do
        if key:find("^my%d") then IF.RING_LABELS[key], IF.RingBuilders[key] = nil, nil end
    end
    for _, w in ipairs(MW.List()) do
        local key = MW.RingKey(w.id)
        if not MW.Hidden(key) then rings[#rings + 1] = key end
        IF.RING_LABELS[key] = w.name
        IF.RingBuilders[key] = Builder(w.id)
    end
    IF.RINGS = rings
    -- Buffs gave its place to Quest Items: what opened it opens that
    for combo, ring in pairs(IF.db.combos or {}) do
        if ring == "buffs" then IF.db.combos[combo] = "quest" end
    end
    local keys = MW.WheelKeys()
    for button, ring in pairs(keys) do
        if ring == "buffs" then keys[button] = "quest" end
    end
    IF.charDB.buffSlots, IF.charDB.buffs = nil, nil
    IF.db.phraseSlots, IF.db.phraseDefaultsGone, IF.db.phraseSlotsFull = nil, nil, nil
    -- Each wheel's line in the game's Key Bindings (AddOns)
    for _, key in ipairs(IF.WHEEL_BINDING_KEYS or {}) do
        _G["BINDING_NAME_CLICK ImprovedForeverWheel_" .. key .. ":LeftButton"] = "Open wheel: "
            .. (IF.RING_LABELS[key] or ("Wheel " .. key:gsub("^my", "")))
    end
    -- A combo on a wheel that is gone: back to the game's own R3
    for combo, ring in pairs(IF.db.combos) do
        if not IF.RING_LABELS[ring] then
            IF.db.combos[combo] = "native"
        end
    end
end

function Changed()
    MW.Register()
    -- A recorded button on a wheel that is gone: let go
    local keys = MW.WheelKeys()
    for button, key in pairs(keys) do
        if not IF.RING_LABELS[key] then keys[button] = nil end
    end
    IF.RefreshRings()
    if IF.ApplyRingBindings then IF.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end
MW.Changed = Changed

-- A new wheel of a kind (nil: "custom"), named after it
function MW.Create(kindKey)
    local kind = IF.WheelKinds.Get(kindKey)
    local used = {}
    for _, w in ipairs(MW.List()) do used[w.id] = true end
    for id = 1, MW.MAX do
        if not used[id] then
            local slots = {}
            for i, action in ipairs(kind.defaults and kind.defaults() or {}) do slots[i] = action end
            table.insert(MW.List(), { id = id, name = kind.name or ("Wheel " .. id),
                kind = kind.key ~= "custom" and kind.key or nil, slots = slots })
            Changed()
            return id
        end
    end
end

function MW.Delete(id)
    MW.HiddenList()[MW.RingKey(id)] = nil
    local list = MW.List()
    for i, w in ipairs(list) do
        if w.id == id then
            table.remove(list, i)
            break
        end
    end
    Changed()
end

function MW.SetSlot(id, slot, action)
    local w = MW.Get(id)
    if not w then return end
    w.slots[slot] = action
    Changed()
end

function MW.Rename(id, name)
    local w = MW.Get(id)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if not w or name == "" then return end
    w.name = name:sub(1, 40)
    Changed()
end

---------------------------------------------------------------------------
-- Every wheel, described for the editor: { key, label, builtin, slots
-- (nil: fills itself), max (slots: 8 per page), lists (the picker's),
-- info, reset, id (own wheels: rename / delete), hub (its slots go in the
-- wheel's middle, its own content round it: the Group wheel's spells) }
-- all: the hidden ones too (each with hidden = true)
---------------------------------------------------------------------------
function MW.Wheels(all)
    local wheels = {
        { key = "quest", label = IF.RING_LABELS.quest, builtin = true, max = IF.MAX_SLOTS,
            info = "Fills itself from your bags: the items a quest has you use, then the ones that start a"
                .. " quest. An item leaves once its quest is done. Nothing to set here but its hotkey." },
        { key = "consumables", label = IF.RING_LABELS.consumables, builtin = true, max = IF.MAX_SLOTS,
            info = "Fills itself from your bags: food and drink, potions, bandages, scrolls, elixirs and flasks,"
                .. " best kinds first. Nothing to set here but its hotkey." },
        { key = "emotes", label = IF.RING_LABELS.emotes, builtin = true, slots = IF.GetEmoteSlots(), max = 8,
            lists = { EMOTES, MACROS },
            info = "Emotes to play with a flick of the stick. Change any slot.",
            reset = IF.ResetEmoteSlots, resetLabel = "Default emotes" },
    }
    -- (the Group wheel fills itself with the group; its slots here are the
    -- spells D-pad up / down picks on a member: Group.lua)
    local G = IF.GroupWheel
    if G then
        wheels[#wheels + 1] = { key = "group", label = IF.RING_LABELS.group, builtin = true, slots = G.Spells(),
            max = G.MAX_SPELLS, lists = { SPELLS }, hub = true,
            info = "Fills itself with your party or raid, a group a page. A pick targets them; on a member,"
                .. " D-pad up / down picks one of these spells instead, cast on them without changing your"
                .. " target. Usable in combat; the group updates after a fight.",
            reset = G.ResetSpells, resetLabel = "Default spells" }
    end
    wheels[#wheels + 1] = { key = "camping", label = IF.RING_LABELS.camping, builtin = true, max = IF.MAX_SLOTS,
        info = "Fills itself with the camping gear: the campfire kits, Camp Tent, Camp Chair, Fish Bowl, Fishing Rack"
            .. " and Hut, Incense Candle, First Aid Kit and Cookie's Feast in your bags, and any you know how to make. R2 uses one; Square crafts it (out of combat). Nothing to"
            .. " set here but its hotkey." }
    wheels[#wheels + 1] = { key = "panels", label = IF.RING_LABELS.panels, builtin = true, max = IF.MAX_SLOTS,
        info = "Fills itself with Improved Forever's own windows, each one whose module you have: this"
            .. " settings panel, the Journal, the Wiki, the Fish Collection, the Destroy panel. Nothing to set"
            .. " here but its hotkey." }
    -- (the player's own, by kind: slots to fill, or none, it fills itself)
    for _, w in ipairs(MW.List()) do
        local kind = IF.WheelKinds.Get(w.kind)
        local reset = kind.defaults and function()
            wipe(w.slots)
            for i, action in ipairs(kind.defaults()) do w.slots[i] = action end
        end
        wheels[#wheels + 1] = { key = MW.RingKey(w.id), label = w.name, id = w.id, kind = kind.key,
            slots = kind.slots and w.slots or nil, max = kind.max or MW.SLOTS,
            lists = kind.lists and kind.lists() or MW.CATALOG, info = kind.info,
            reset = reset, resetLabel = reset and "Defaults" or nil }
    end
    local shown = {}
    for _, wheel in ipairs(wheels) do
        wheel.hidden = MW.Hidden(wheel.key)
        if all or not wheel.hidden then shown[#shown + 1] = wheel end
    end
    return shown
end

-- What a self-filling wheel holds right now, as actions by slot (each
-- group from a page of its own, as the ring shows it)
function MW.LiveSlots(wheel)
    local slots = {}
    local entries = IF.RingBuilders[wheel.key] and IF.RingBuilders[wheel.key]() or {}
    local n = 0
    for _, group in ipairs(entries.groups or { entries }) do
        for _, entry in ipairs(group) do
            n = n + 1
            slots[n] = entry.action or entry.value
        end
        n = math.ceil(n / MW.SLOTS) * MW.SLOTS
    end
    return slots
end

function MW.SetWheelSlot(wheel, slot, action)
    if not wheel.slots then return end
    wheel.slots[slot] = action
    MW.Changed()
end

function MW.ResetWheel(wheel)
    if wheel.reset then
        wheel.reset()
        MW.Changed()
    end
end

---------------------------------------------------------------------------
-- Hotkeys: an R3 combo (L1 / L2 / R1 / R2 + R3, or R3), a recorded
-- controller button, or the wheel's line in the game's Key Bindings
---------------------------------------------------------------------------
-- The combos that open a ring ("L1 + R3, R2 + R3"), or nil
function MW.CombosText(ringKey)
    local parts = {}
    for _, combo in ipairs(IF.COMBOS) do
        if IF.GetComboRing(combo) == ringKey then parts[#parts + 1] = IF.COMBO_LABELS[combo] end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- The key bound to it in the game's Key Bindings, or nil
function MW.BindingText(ringKey)
    local key = GetBindingKey("CLICK ImprovedForeverWheel_" .. ringKey .. ":LeftButton")
    return key and (GetBindingText and GetBindingText(key) or key) or nil
end

---------------------------------------------------------------------------
-- Other presses: any press an override binding can go on (Binds.KeyOf: a
-- button, or one pressed while a button the game makes Shift / Ctrl / Alt
-- is held) opens a wheel (IF.db.wheelKeys = { [spec] = ringKey }): bound
-- to the wheel's own button (Ring.lua, as the game's Key Bindings), which
-- opens it, or closes it when it is up
---------------------------------------------------------------------------
function MW.WheelKeys()
    IF.db.wheelKeys = IF.db.wheelKeys or {}
    return IF.db.wheelKeys
end

local keyOwner = CreateFrame("Frame", "ImprovedForeverWheelKeys")
local keysPending = false

function MW.ApplyWheelKeys()
    if IF.InCombat() then
        keysPending = true
        return
    end
    keysPending = false
    ClearOverrideBindings(keyOwner)
    -- Only while the game has the gamepad's focus (Binds.lua)
    if not IF.Binds.InGame() then return end
    for spec, ringKey in pairs(MW.WheelKeys()) do
        local key = IF.Binds.KeyOf(spec)
        if key and _G["ImprovedForeverWheel_" .. ringKey] and not MW.Hidden(ringKey) then
            SetOverrideBindingClick(keyOwner, false, key, "ImprovedForeverWheel_" .. ringKey, "LeftButton")
        end
    end
end

keyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
keyOwner:RegisterEvent("PLAYER_ENTERING_WORLD")
keyOwner:RegisterEvent("CVAR_UPDATE")
keyOwner:SetScript("OnEvent", function(_, event)
    -- (CVAR_UPDATE: which buttons are Shift / Ctrl / Alt may have changed)
    if IF.db and (keysPending or event ~= "PLAYER_REGEN_ENABLED") then MW.ApplyWheelKeys() end
end)

-- The other presses that open a ring ("Triangle, L2 + D-pad Up"), or nil
function MW.KeysText(ringKey)
    local parts = {}
    for spec, key in pairs(MW.WheelKeys()) do
        if key == ringKey then parts[#parts + 1] = IF.Binds.Text(spec) end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- What opens it, as glyph keys for a GlyphRow (ConfigKit): an R3 combo
-- ("LB", "RS"), else a bound button, else its game key binding's name; nil
-- when nothing does
local COMBO_GLYPHS = {
    R3 = { "RS" }, L1 = { "LB", "+", "RS" }, L2 = { "LT", "+", "RS" }, R1 = { "RB", "+", "RS" }, R2 = { "RT", "+", "RS" },
}

function MW.BindGlyphs(ringKey)
    for _, combo in ipairs(IF.COMBOS) do
        if IF.GetComboRing(combo) == ringKey then return COMBO_GLYPHS[combo] end
    end
    for spec, key in pairs(MW.WheelKeys()) do
        if key == ringKey then return IF.Binds.Glyphs(spec) end
    end
    local binding = MW.BindingText(ringKey)
    return binding and { binding } or nil
end

-- Everything that opens it, or nil
function MW.HotkeyText(ringKey)
    local parts = {}
    for _, text in ipairs({ MW.CombosText(ringKey), MW.KeysText(ringKey), MW.BindingText(ringKey) }) do
        if text then parts[#parts + 1] = text end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- No more hotkeys for this wheel
function MW.ClearHotkey(ringKey)
    for _, combo in ipairs(IF.COMBOS) do
        if IF.GetComboRing(combo) == ringKey then IF.db.combos[combo] = "native" end
    end
    local keys = MW.WheelKeys()
    for button, key in pairs(keys) do
        if key == ringKey then keys[button] = nil end
    end
    if IF.ApplyRingBindings then IF.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end

-- Saves a recorded hotkey: the wheel's old one goes, and the press is
-- taken from whatever had it
function MW.SetHotkey(ringKey, spec)
    MW.ClearHotkey(ringKey)
    if spec.combo then
        IF.db.combos[spec.combo] = ringKey
    else
        MW.WheelKeys()[spec.button] = ringKey
    end
    if IF.ApplyRingBindings then IF.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end

-- Before the rings are built (Ring.lua's login runs after this file's)
IF.OnLogin(MW.Register)

-- The wheels' bindings, on the Bindings tab (Binds.lua): an R3 combo each
-- (Ring.lua opens them), first in its list
local B = IF.Binds
B.AddSource(function()
    local list = {}
    local MW = IF.MyWheels
    if not (MW and IF.db) then return list end
    for _, wheel in ipairs(MW.Wheels()) do
        local key = wheel.key
        list[#list + 1] = {
            id = "wheel:" .. key, label = wheel.label .. " wheel", group = "Wheels", tab = "wheel",
            icon = IF.TEX .. "ic_event_wheel", context = "world",
            tip = "Opens the wheel (pressed again: closes it). On " .. IF.ButtonName("RS")
                .. " or a shoulder / trigger + " .. IF.ButtonName("RS") .. ", " .. IF.ButtonName("RS")
                .. " twice uses its last action again.",
            -- R3 combos (Ring.lua), a crossbar slot (Native.lua: a macro of
            -- ours that opens it), or any press an override binding can go on
            accepts = function(spec)
                local _, _, double = B.Parse(spec)
                return B.SpecCombo(spec) ~= nil or IF.Native.SlotOf(spec) ~= nil
                    or (not double and B.KeyOf(spec) ~= nil)
            end,
            specs = function()
                local specs = {}
                for _, combo in ipairs(IF.COMBOS) do
                    if IF.GetComboRing(combo) == key then specs[#specs + 1] = B.ComboSpec(combo) end
                end
                for spec, ring in pairs(MW.WheelKeys()) do
                    if ring == key then specs[#specs + 1] = spec end
                end
                for _, bound in ipairs(IF.Native.Bound()) do
                    if bound.action == "wheel:" .. key then specs[#specs + 1] = bound.spec end
                end
                return specs
            end,
            -- (one press per wheel: setting one takes it off the others)
            set = function(spec)
                MW.ClearHotkey(key)
                for _, bound in ipairs(IF.Native.Bound()) do
                    if bound.action == "wheel:" .. key and bound.spec ~= spec then IF.Native.Clear(bound.spec) end
                end
                if not spec then return end
                if IF.Native.SlotOf(spec) then
                    IF.Native.Set(spec, "wheel:" .. key, wheel.label)
                    return
                end
                local combo = B.SpecCombo(spec)
                MW.SetHotkey(key, combo and { combo = combo } or { button = spec })
            end,
            unbind = function(spec)
                local combo = B.SpecCombo(spec)
                if IF.Native.SlotOf(spec) then
                    if IF.Native.Get(spec) == "wheel:" .. key then IF.Native.Clear(spec) end
                elseif combo then
                    if IF.GetComboRing(combo) == key then IF.SetComboRing(combo, "native") end
                elseif MW.WheelKeys()[spec] == key then
                    MW.WheelKeys()[spec] = nil
                    MW.ApplyWheelKeys()
                end
            end,
        }
    end
    return list
end, 10)
