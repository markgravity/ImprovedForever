-- Every controller press the addon answers, in one place: the wheels' R3
-- combos, bag clean-up, the Destroy panel, the minimap labels' hotkey,
-- the peek map, the touchpad click, the actions put on presses (Override.lua) and the
-- menu's double press.
-- Each feature keeps its own setting; this file reads and writes them
-- through one shape, so the Bindings tab (BindEditor.lua) can show them all
-- on the controller and every tab can tell what a new binding replaces.
--
-- A press is a spec: "PADRSTICK" (pressed), "PADLSHOULDER+PADRSTICK" (one
-- held, one pressed), "PADLSTICK:double" (pressed twice quickly).
-- Two bindings on the same spec clash only where they work at the same
-- time: one for the game and one for the bags share a press (a wheel and
-- bag clean-up on L3), each answering where the focus is.
--
-- Where each works (the gamepad's focus): "world" bindings only while the
-- game has it (B.InGame: no window of Forever's gamepad UI holds it, as
-- bags or the map do); "bags" ones only while a bag is open. A window
-- taking the focus takes our world bindings off its buttons until it lets
-- go (B.FocusChanged re-applies them).
local _, IF = ...

local B = {}
IF.Binds = B

-- Buttons that can be held for a second one
B.HOLDS = { "PADLSHOULDER", "PADLTRIGGER", "PADRSHOULDER", "PADRTRIGGER" }

-- The held button of each R3 combo, and back
local COMBO_HOLD = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local HOLD_COMBO = {}
for combo, key in pairs(COMBO_HOLD) do HOLD_COMBO[key] = combo end

---------------------------------------------------------------------------
-- Specs
---------------------------------------------------------------------------
-- held (or nil: one button held, or several: "PADLSHOULDER+PADRSHOULDER"),
-- pressed, double
function B.Parse(spec)
    if not spec then return nil end
    local base = spec:match("^(.-):double$")
    local pressed, double = base or spec, base ~= nil
    local held, rest = pressed:match("^(.+)%+([^%+]+)$")
    if held then return held, rest, double end
    return nil, pressed, double
end

-- The buttons held of a press, one by one
function B.HeldList(held)
    local list = {}
    for key in (held or ""):gmatch("[^%+]+") do list[#list + 1] = key end
    return list
end

function B.Spec(held, pressed, double)
    return (held and (held .. "+") or "") .. pressed .. (double and ":double" or "")
end

-- A press from its buttons held (a list, in any order: the shoulders and
-- triggers first, as B.HOLDS, then the rest by name), its button pressed
function B.SpecOf(heldList, pressed, double)
    local order = {}
    for i, key in ipairs(B.HOLDS) do order[key] = i end
    local list = {}
    for _, key in ipairs(heldList or {}) do
        if key ~= pressed then list[#list + 1] = key end
    end
    table.sort(list, function(a, b)
        local oa, ob = order[a] or 99, order[b] or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return B.Spec(#list > 0 and table.concat(list, "+") or nil, pressed, double)
end

-- "L1 + R3", "L3 double-click"; with size, each button's glyph before its name
function B.Text(spec, size)
    if not spec then return "Not bound" end
    local held, pressed, double = B.Parse(spec)
    local function one(key)
        return (size and (IF.GlyphText(key, size) .. " ") or "") .. IF.ButtonName(key)
    end
    local parts = {}
    for _, key in ipairs(B.HeldList(held)) do parts[#parts + 1] = one(key) end
    parts[#parts + 1] = one(pressed)
    return table.concat(parts, " + ") .. (double and " double-click" or "")
end

-- Glyph keys for a GlyphRow (ConfigKit): { "LB", "+", "RS" }
function B.Glyphs(spec)
    local held, pressed = B.Parse(spec)
    if not pressed then return nil end
    local keys = {}
    for _, key in ipairs(B.HeldList(held)) do
        keys[#keys + 1] = IF.PAD_KEY[key] or key
        keys[#keys + 1] = "+"
    end
    keys[#keys + 1] = IF.PAD_KEY[pressed] or pressed
    return keys
end

-- An R3 combo ("L1", "R3") as a spec, and a spec as one (or nil)
function B.ComboSpec(combo)
    if combo == "R3" then return "PADRSTICK" end
    return COMBO_HOLD[combo] .. "+PADRSTICK"
end

function B.SpecCombo(spec)
    local held, pressed, double = B.Parse(spec)
    if pressed ~= "PADRSTICK" or double then return nil end
    if not held then return "R3" end
    return HOLD_COMBO[held]
end

-- The modifier a held button gives (the game's GamePadEmulate* CVars), or nil
local EMULATE = { { "GamePadEmulateShift", "SHIFT-" }, { "GamePadEmulateCtrl", "CTRL-" }, { "GamePadEmulateAlt", "ALT-" } }

local function ModifierOf(button)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    for _, m in ipairs(EMULATE) do
        if get and get(m[1]) == button then return m[2] end
    end
end
B.ModifierOf = ModifierOf

-- The modifiers the buttons held make, as a key's prefix ("CTRL-SHIFT-"),
-- or nil when one of them makes none
function B.ModPrefix(held)
    local mods = {}
    for _, key in ipairs(B.HeldList(held)) do
        local modifier = ModifierOf(key)
        if not modifier then return nil end
        mods[modifier] = true
    end
    local prefix = ""
    for _, modifier in ipairs({ "ALT-", "CTRL-", "SHIFT-" }) do
        if mods[modifier] then prefix = prefix .. modifier end
    end
    return prefix
end

-- Presses the game keeps, whatever is bound there (as Easy Controller
-- leaves them): Options / Select (its menu wheel, its interface focus: taken
-- before any binding) and L1 / R1 held with a face button or the D-pad (its
-- targeting bars: a binding of ours there never runs). Returns why, or nil.
local SYSTEM = { PADFORWARD = "its menu", PADBACK = "its interface focus" }
local SHOULDERS = { PADLSHOULDER = true, PADRSHOULDER = true }
local PAD = { PAD1 = true, PAD2 = true, PAD3 = true, PAD4 = true,
    PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }

function B.GameOwns(spec)
    local held, pressed = B.Parse(spec)
    if not pressed then return nil end
    if SYSTEM[pressed] then return IF.ButtonName(pressed) .. " is the game's (" .. SYSTEM[pressed] .. ")" end
    if PAD[pressed] then
        for _, key in ipairs(B.HeldList(held)) do
            if SHOULDERS[key] then return B.Text(B.Spec(held, pressed)) .. " is the game's (its targeting)" end
        end
    end
end

-- The key an override binding for a press goes on ("PADLSTICK",
-- "SHIFT-PAD1"; a press twice: its button's), or nil when it can't have
-- one: R3 (the wheels' combos, Ring.lua), a PlayStation touchpad (its
-- corners), a button the game makes a modifier, or one held that it doesn't
function B.KeyOf(spec)
    -- (a press of Forever's crossbar: its slot holds what it runs, Native.lua)
    if IF.Native and IF.Native.SlotOf(spec) then return nil end
    local held, pressed, double = B.Parse(spec)
    if B.GameOwns(spec) then return nil end
    -- (twice where once is the crossbar's: its slot can't be shared out)
    if double and IF.Native and IF.Native.SlotOf(B.Spec(held, pressed)) then return nil end
    -- (the crossbar's modifiers, L2 / R2: taking one would stop it paging;
    -- held under another press they are fine)
    if IF.Native and IF.Native.IsModifier(pressed) then return nil end
    if not pressed or pressed == "PADRSTICK" or ModifierOf(pressed) then return nil end
    if pressed == "PADBACK" and IF.PadStyle() == "Shapes" then return nil end
    if not held then return pressed end
    local prefix = B.ModPrefix(held)
    return prefix and (prefix .. pressed) or nil
end

-- The key a double press is watched on (Override.lua), or nil: any button
-- (its single press stays the game's), but R3 (its wheel's twice) and a
-- PlayStation touchpad (its corners); held: a modifier the game makes of
-- it, or just held
function B.DoubleKey(spec)
    local held, pressed, double = B.Parse(spec)
    if not double or not pressed or pressed == "PADRSTICK" then return nil end
    if pressed == "PADBACK" and IF.PadStyle() == "Shapes" then return nil end
    -- (several held: only as the modifiers they make)
    if held and held:find("+", 1, true) then
        local prefix = B.ModPrefix(held)
        return prefix and (prefix .. pressed) or nil
    end
    local modifier = held and ModifierOf(held)
    return modifier and (modifier .. pressed) or pressed
end

-- The ways a button can be pressed: alone, twice (where something takes
-- that), with each of the shoulders / triggers held
function B.Variants(key)
    local list = { key }
    local double = key .. ":double"
    for _, def in ipairs(B.All()) do
        if def.accepts(double) or IF.Override.Supports(double) then
            list[#list + 1] = double
            break
        end
    end
    for _, held in ipairs(B.HOLDS) do
        if held ~= key then list[#list + 1] = held .. "+" .. key end
    end
    return list
end

---------------------------------------------------------------------------
-- The bindings: { id, label, icon, group, tab (where else it is set), desc
-- (what it does, a short line under its name), context ("world": while the game has the gamepad's focus, or "bags":
-- while a bag is open), accepts(spec), specs() (what it is bound to now), set(spec)
-- (nil: unbound), unbind(spec) (optional: just that one) }
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

function B.Single(spec)
    local held, _, double = B.Parse(spec)
    return spec ~= nil and not held and not double
end

-- Not twice, and at most one button held (the watched hotkeys read one)
function B.NotDouble(spec)
    local held, _, double = B.Parse(spec)
    return spec ~= nil and not double and not (held and held:find("+", 1, true))
end

function B.One(spec)
    return spec and { spec } or {}
end

-- An override binding: a press one can go on
function B.Overridable(spec)
    local _, _, double = B.Parse(spec)
    return not double and B.KeyOf(spec) ~= nil
end

-- A module's bindings: B.Add(def) one, B.AddSource(fn) a list that changes
-- (fn() -> defs: the wheels). order: where the Bindings tab lists it.
local fixed, sources = {}, {}

function B.Add(def)
    -- (an old Gather loaded beside Minimap: its binding is Minimap's, Core.lua)
    if IF.oldGather and def.id == "gather" then return def end
    def.order = def.order or 50
    -- (one per id: an old Controller module still loaded adds its own again)
    for i, other in ipairs(fixed) do
        if other.id == def.id then
            if IF.oldController and debugstack and (debugstack(2, 1, 0) or ""):find(IF.OLD_CONTROLLER, 1, true) then
                return other
            end
            fixed[i] = def
            return def
        end
    end
    fixed[#fixed + 1] = def
    table.sort(fixed, function(a, b) return a.order < b.order end)
    return def
end

function B.AddSource(fn, order)
    sources[#sources + 1] = { fn = fn, order = order or 50 }
    table.sort(sources, function(a, b) return a.order < b.order end)
end

B.Add({
    id = "menu", label = "Improved Forever panel", group = "Other",
    icon = IF.TEX .. "ic_addon", context = "world", order = 90,
    desc = "Opens this settings panel",
    tip = "Pressed twice quickly, opens this panel. Once still opens the game's own menu.",
    accepts = function(spec) return spec == "PADFORWARD:double" end,
    specs = function() return IF.db.menuDouble ~= false and { "PADFORWARD:double" } or {} end,
    set = function(spec) IF.db.menuDouble = spec ~= nil end,
    run = function(down) if down and IF.Menu then IF.Menu.Toggle() end end,
})

-- A spell, item, macro, emote or window can go on the press: in its
-- crossbar slot (Native.lua), or as an override binding (Override.lua)
-- R3 (and R3 with any buttons held): the wheels' trigger reads the pad and
-- runs it (Ring.lua), when the Wheel module is on
local function OnTrigger(spec)
    local _, pressed, double = B.Parse(spec)
    return pressed == "PADRSTICK" and not double and IF.ApplyRingBindings ~= nil
end
B.OnTrigger = OnTrigger

function B.ActionFits(spec)
    return IF.Native.SlotOf(spec) ~= nil or IF.Override.Supports(spec) or OnTrigger(spec)
end

-- The action on a press (a crossbar slot's, not a wheel's; else the
-- override's), or nil
function B.ActionOn(spec)
    if IF.Native.SlotOf(spec) then
        local action = IF.Native.Get(spec)
        return action and not action:find("^wheel:") and action or nil
    end
    return IF.Override.Get(spec)
end

-- Puts an action on a press (nil: takes it off). Out of combat.
function B.SetAction(spec, action, label, icon)
    if IF.Native.SlotOf(spec) then
        if action then return IF.Native.Set(spec, action, label, icon) end
        return IF.Native.Clear(spec)
    end
    IF.Override.Set(spec, action)
    -- (R3's: kept with the overrides, run by the wheels' trigger)
    if OnTrigger(spec) then IF.ApplyRingBindings() end
end

-- An action on a press: a spell, an item, a macro, an emote or a window.
-- One per press, made for any press asked about.
function B.ActionDef(spec)
    local O = IF.Override
    local action = B.ActionOn(spec)
    return {
        id = "action:" .. spec, kind = "action", group = "Action", context = "world",
        label = action and ("Action: " .. (O.ActionLabel(action) or action)) or "An action",
        icon = O.ActionIcon(action) or ICON .. "INV_Misc_QuestionMark",
        tip = "Runs a spell, an item, a macro, an emote or opens a window, in combat too.",
        accepts = function(s) return s == spec and B.ActionFits(s) end,
        specs = function() return B.ActionOn(spec) and { spec } or {} end,
        set = function(s) if not s then B.SetAction(spec, nil) end end,
    }
end

local function Actions()
    local list = {}
    local O = IF.Override
    if not (O and IF.db) then return list end
    local specs, seen = {}, {}
    for spec in pairs(O.Settings()) do
        if B.ActionOn(spec) then specs[#specs + 1], seen[spec] = spec, true end
    end
    -- (and what the crossbar's slots hold)
    for _, bound in ipairs(IF.Native.Bound()) do
        if not seen[bound.spec] and not bound.action:find("^wheel:") then specs[#specs + 1] = bound.spec end
    end
    table.sort(specs)
    for _, spec in ipairs(specs) do list[#list + 1] = B.ActionDef(spec) end
    return list
end

---------------------------------------------------------------------------
-- The gamepad's focus: in the game, or on a window (Forever's binding stack,
-- GamepadSharedUtility.InputBindingManager), read every 0.1 s: never a
-- callback of ours in its lists, which would taint its secure work.
-- Bindings can only change out of combat: as combat starts ours go on
-- (PLAYER_REGEN_DISABLED comes just before the lockdown), so they work
-- through it whatever has the focus.
---------------------------------------------------------------------------
local inCombat = false

function B.InGame()
    if inCombat then return true end
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    if not (manager and manager.IsOnlyCoreBindingSetActive) then return true end
    return manager:IsOnlyCoreBindingSetActive() and true or false
end

-- The focus moved: every world binding re-applied (each one checks B.InGame)
function B.FocusChanged()
    if IF.InCombat() or not IF.db then return end
    if IF.ApplyRingBindings then IF.ApplyRingBindings() end
    if IF.MyWheels then IF.MyWheels.ApplyWheelKeys() end
    if IF.Override then IF.Override.Apply() end
    if IF.Touch then IF.Touch.Apply() end
end

local focus = CreateFrame("Frame")
focus:RegisterEvent("PLAYER_REGEN_DISABLED")
focus:RegisterEvent("PLAYER_REGEN_ENABLED")
focus:SetScript("OnEvent", function(_, event)
    inCombat = event == "PLAYER_REGEN_DISABLED"
    if inCombat then
        B.FocusChanged()
    else
        -- (after the features' own catch-up on PLAYER_REGEN_ENABLED)
        C_Timer.After(0, B.FocusChanged)
    end
end)

local lastInGame, wait = nil, 0
focus:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 or not IF.db then return end
    wait = 0.1
    local now = B.InGame()
    if now ~= lastInGame then
        lastInGame = now
        B.FocusChanged()
    end
end)

-- Every binding, in the order the Bindings tab lists them
function B.All()
    local list = {}
    -- (the lists first: the wheels)
    for _, source in ipairs(sources) do
        for _, def in ipairs(source.fn()) do list[#list + 1] = def end
    end
    for _, def in ipairs(fixed) do list[#list + 1] = def end
    for _, def in ipairs(Actions()) do list[#list + 1] = def end
    return list
end

function B.Get(id)
    local spec = id:match("^action:(.+)$")
    if spec then return B.ActionDef(spec) end
    for _, def in ipairs(B.All()) do
        if def.id == id then return def end
    end
end

local function Has(def, spec)
    for _, s in ipairs(def.specs()) do
        if s == spec then return true end
    end
    return false
end
B.Has = Has

-- What is bound to a press, world bindings first
function B.Bound(spec)
    local list = {}
    for _, def in ipairs(B.All()) do
        if Has(def, spec) then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return (a.context == "world" and 0 or 1) < (b.context == "world" and 0 or 1) end)
    return list
end

-- Two bindings on one press: do they get in each other's way? Only where
-- they work at the same time (the same focus)
function B.Clash(a, b)
    return a.id ~= b.id and a.context == b.context
end

-- What would have to give way for id on spec
function B.Conflicts(id, spec)
    local def = B.Get(id)
    local list = {}
    if not def or not spec then return list end
    for _, other in ipairs(B.Bound(spec)) do
        if B.Clash(def, other, spec) then list[#list + 1] = other end
    end
    return list
end

-- Bindings that clash on a press right now (two or more), or nil
function B.Clashing(spec)
    local bound = B.Bound(spec)
    for i = 1, #bound do
        for j = i + 1, #bound do
            if B.Clash(bound[i], bound[j], spec) then return bound end
        end
    end
    return nil
end

-- What a binding clashes with where it is bound now
function B.ClashesOf(id)
    local def = B.Get(id)
    local list = {}
    if not def then return list end
    for _, spec in ipairs(def.specs()) do
        for _, other in ipairs(B.Conflicts(id, spec)) do list[#list + 1] = other end
    end
    return list
end

-- "the Buffs wheel and Minimap labels"
function B.Names(defs)
    local names = {}
    for _, def in ipairs(defs) do names[#names + 1] = def.label end
    if #names <= 1 then return names[1] or "" end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function Unbind(def, spec)
    if def.unbind then def.unbind(spec) else def.set(nil) end
end

-- Frees a press for id: whatever clashes with it there is unbound. Returns
-- what was.
function B.Take(id, spec)
    local gone = B.Conflicts(id, spec)
    for _, other in ipairs(gone) do Unbind(other, spec) end
    return gone
end

-- Binds id to spec (nil: unbinds it), taking the press from what clashes
-- with it. Returns what was unbound. Out of combat.
function B.Assign(id, spec)
    local def = B.Get(id)
    if not def then return {} end
    if not spec then
        def.set(nil)
        return {}
    end
    local gone = B.Take(id, spec)
    def.set(spec)
    return gone
end

-- Nothing of ours on a press any more; returns what was there
function B.Clear(spec)
    local gone = B.Bound(spec)
    for _, def in ipairs(gone) do Unbind(def, spec) end
    return gone
end

---------------------------------------------------------------------------
-- The keyboard / mouse press: each binding's second one, beside its
-- controller press (both work, as the game's Key 1 / Key 2). A key as the
-- game writes one ("F", "ALT-F", "CTRL-SHIFT-5"), or a modified click on an
-- item ("ALT-BUTTON1": Alt + left click; BUTTON2 right, BUTTON3 middle). A
-- binding takes a key when it has def.run(down) or def.button (the name of
-- a button the key clicks: a secure one, the peek map's); def.click(item)
-- takes a click on an item, and a key acts on the item under the mouse
-- (IF.Input.Hovered). def.defaultKey: its key until one is set.
-- IF.db.keyBinds = { [id] = spec, or false: none }. Keys are override
-- bindings (out of combat; kept through it), on whatever has the focus.
---------------------------------------------------------------------------
local CLICK_NAMES = { BUTTON1 = "Left Click", BUTTON2 = "Right Click", BUTTON3 = "Middle Click" }
local MOUSE_KEY = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
local MOD_NAMES = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Shift" }
-- (the game's own modified clicks on an item: a chat link, the dressing
-- room, its socket / profession; Bindings_Standard.xml)
local GAME_CLICKS = { ["SHIFT-BUTTON1"] = "links it in the chat", ["CTRL-BUTTON1"] = "tries it on",
    ["SHIFT-BUTTON2"] = "opens its profession" }

function B.IsClick(spec)
    return type(spec) == "string" and spec:match("BUTTON[123]$") ~= nil
end

-- The modifiers held now, as a key's prefix ("ALT-CTRL-")
function B.ModsNow()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "")
end

-- A click made now with a mouse button ("LeftButton"), as a spec
function B.ClickSpec(button)
    local key = MOUSE_KEY[button or ""]
    return key and (B.ModsNow() .. key) or nil
end

-- Does a binding take a key / a click at all
function B.TakesKey(def)
    return def ~= nil and (def.run ~= nil or def.button ~= nil or def.click ~= nil)
end

-- Can spec go on def's keyboard / mouse press; else why not
function B.KeyFits(def, spec)
    if not B.TakesKey(def) then return false, def and def.label .. " has no keyboard press" end
    if B.IsClick(spec) then
        if not def.click then return false, def.label .. " takes a key, not a click" end
        if not spec:find("-", 1, true) then return false, "Hold Alt, Ctrl or Shift as you click" end
        if GAME_CLICKS[spec] then return false, B.KeyText(spec) .. " is the game's (it " .. GAME_CLICKS[spec] .. ")" end
    elseif spec == "ESCAPE" then
        return false, "Escape is the game's"
    end
    return true
end

local function KeyDB()
    IF.db.keyBinds = IF.db.keyBinds or {}
    return IF.db.keyBinds
end

-- def's keyboard / mouse press, or nil
function B.KeyBind(def)
    if not (def and B.TakesKey(def) and IF.db) then return nil end
    local spec = KeyDB()[def.id]
    if spec == false then return nil end
    return spec or def.defaultKey
end

-- "Alt + F", "Ctrl + Left Click"
function B.KeyText(spec)
    if not spec then return "Not bound" end
    local parts = {}
    local key = spec
    while true do
        local mod, rest = key:match("^(%u+)%-(.+)$")
        if not (mod and MOD_NAMES[mod]) then break end
        parts[#parts + 1] = MOD_NAMES[mod]
        key = rest
    end
    parts[#parts + 1] = CLICK_NAMES[key] or (GetBindingText and GetBindingText(key, "KEY_")) or key
    return table.concat(parts, " + ")
end

-- The bindings on a keyboard / mouse press
function B.KeyBound(spec)
    local list = {}
    if not spec then return list end
    for _, def in ipairs(B.All()) do
        if B.KeyBind(def) == spec then list[#list + 1] = def end
    end
    return list
end

-- Puts id's keyboard / mouse press on spec (nil: none), taking it from
-- whatever had it. Returns what gave way. Out of combat.
function B.SetKey(id, spec)
    local def = B.Get(id)
    if not def then return {} end
    local gone = {}
    for _, other in ipairs(B.KeyBound(spec)) do
        if other.id ~= id then
            KeyDB()[other.id] = false
            gone[#gone + 1] = other
        end
    end
    -- (the key free of an action on it too: Override.lua)
    if spec and not B.IsClick(spec) and IF.Override and IF.Override.KeyAction(spec) then
        IF.Override.SetKey(spec, nil)
    end
    KeyDB()[id] = spec or false
    B.ApplyKeys()
    return gone
end

-- The binding a click on an item runs, or nil
function B.ClickDef(spec)
    if not B.IsClick(spec) then return nil end
    for _, def in ipairs(B.KeyBound(spec)) do
        if def.click then return def end
    end
end

-- A click on an item made now (button: "LeftButton"...): its binding run;
-- true when one did. item: as IF.Input's ({ link, bag, slot, owner })
function B.RunClick(button, item)
    local def = B.ClickDef(B.ClickSpec(button))
    if not (def and item) then return false end
    def.click(item)
    return true
end

local keyOwner = CreateFrame("Frame", "ImprovedForeverKeys")
local keyButtons = {}
local keysPending = false

-- The button a binding's key clicks: its own (def.button), else one of ours
-- running it (on the press and its release: def.run(down)), or for an item's
-- binding, the item under the mouse on the press
local function KeyButton(def)
    if def.button then return def.button end
    local b = keyButtons[def.id]
    if b then return b:GetName() end
    b = CreateFrame("Button", "ImprovedForeverKey_" .. def.id:gsub("[^%w]", "_"))
    b:RegisterForClicks("AnyDown", "AnyUp")
    local id = def.id
    b:SetScript("OnClick", function(_, _, down)
        local d = B.Get(id)
        if not d then return end
        if d.run then return d.run(down) end
        if d.click and down then
            local item = IF.Input and IF.Input.Hovered()
            if item then d.click(item) end
        end
    end)
    keyButtons[def.id] = b
    return b:GetName()
end

function B.ApplyKeys()
    if not IF.db then return end
    if IF.InCombat() then
        keysPending = true
        return
    end
    keysPending = false
    ClearOverrideBindings(keyOwner)
    for _, def in ipairs(B.All()) do
        local spec = B.KeyBind(def)
        if spec and not B.IsClick(spec) then SetOverrideBindingClick(keyOwner, false, spec, KeyButton(def), "LeftButton") end
    end
    if IF.Override and IF.Override.ApplyKeys then IF.Override.ApplyKeys() end
end

IF.OnLogin(B.ApplyKeys)
keyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
keyOwner:SetScript("OnEvent", function()
    if keysPending then B.ApplyKeys() end
end)
