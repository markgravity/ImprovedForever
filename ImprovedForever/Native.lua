-- Forever's crossbar (Blizzard_GamepadActionBars): the D-pad and face
-- buttons run the slots of its bars, the top one alone (the face buttons'
-- slots there are the game's own: jump...), the left / right one while
-- its modifier (GAMEPADLEFTMOD / GAMEPADRIGHTMOD, L2 / R2 by default) is
-- held, the bottom one while both are. Those presses are the crossbar's: what they run is read from and
-- written to its slots (on the page shown), so the Bindings tab and the
-- game's own gamepad action bar editor always show the same thing, both
-- ways. A spell, an item or a macro goes in as itself; what a slot can't
-- hold (an emote, a window, a wheel) as a macro of ours ("IF:..."), made
-- for it. Out of combat only.
--
--  Page unit slots (ActionBindingUtil.lua):  top 1-8, left 9-16, right 17-24,
--  bottom 25-32
--  (1-4 the D-pad: left, up, right, down; 5-8 the face buttons: left, top,
--  right, bottom), GAMEPADACTIONBUTTON1-8 the buttons that press them.
local _, IF = ...

local N = {}
IF.Native = N

local PREFIX = "IF:"
-- What a macro of ours runs for an action kind a module adds (its text by
-- the action's value): N.MacroBodies[kind] = fn(value)
N.MacroBodies = {}
local PER_BAR = 8
-- N.Bound's list, the frame it was read in (nil: read again)
local bound, boundAt

local function Util()
    return _G.GamepadActionBarBindingUtil
end

local function PageUnit()
    local frame = _G.GamepadMainActionBarFrame
    return frame and frame.PageUnit
end

-- This client has the crossbar
function N.Available()
    local unit = PageUnit()
    return Util() ~= nil and unit ~= nil and unit.GetCurrentPage ~= nil
end

-- The game's bindings read once (until they change): each button's place
-- in a bar (1-8), each modifier's bar (1 left, 2 right)
local keys
local function Keys()
    if keys then return keys end
    keys = { index = {}, bar = {} }
    for n = 1, PER_BAR do
        for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. n) }) do keys.index[key] = n end
    end
    for i, name in ipairs({ "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD" }) do
        for _, key in ipairs({ GetBindingKey(name) }) do keys.bar[key] = i end
    end
    return keys
end

local function ButtonIndex(key)
    return Keys().index[key]
end

-- The bar the buttons held pick: 0 (none held), 1 (left), 2 (right), 3
-- (both: the bottom one), or nil
local function BarOffset(held)
    if not held then return 0 end
    local bars = {}
    for _, key in ipairs(IF.Binds.HeldList(held)) do
        local bar = Keys().bar[key]
        if not bar then return nil end
        bars[#bars + 1] = bar
    end
    if #bars == 1 then return bars[1] end
    if #bars == 2 and bars[1] ~= bars[2] then return 3 end
end

-- A button the crossbar holds for a modifier (its left / right bar)
function N.IsModifier(key)
    return N.Available() and BarOffset(key) ~= nil and key ~= nil
end

-- The crossbar slot a press runs (page unit slot id), or nil: not one of
-- its presses, or one the game keeps (the top bar's face buttons)
function N.SlotOf(spec)
    if not (spec and N.Available()) then return nil end
    local held, pressed, double = IF.Binds.Parse(spec)
    if double then return nil end
    local n, bar = ButtonIndex(pressed), BarOffset(held)
    if not (n and bar) then return nil end
    local slot = bar * PER_BAR + n
    if not Util().IsBindablePageUnitSlotID(slot) then return nil end
    return slot
end

-- The action slot (PickupAction / PlaceAction / GetActionInfo) of a press,
-- on the page shown
local function Storage(spec)
    local slot = N.SlotOf(spec)
    if not slot then return nil end
    return Util().GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(PageUnit():GetCurrentPage(), slot)
end

---------------------------------------------------------------------------
-- Our macros: "IF:<name>"; charDB.nativeMacros = { [name] = action } says
-- what each stands for (a wheel: "wheel:<key>")
---------------------------------------------------------------------------
local function Macros()
    IF.charDB.nativeMacros = IF.charDB.nativeMacros or {}
    return IF.charDB.nativeMacros
end

-- What a wheel's macro runs: its button (Ring.lua), as "Macro" (opened
-- on a click of any kind, not just a press)
function N.WheelBody(key)
    return "/click ImprovedForeverWheel_" .. key .. " Macro"
end

-- Our macro for an action (made, or remade, as needed); its name or nil
-- A macro's icon as a file ID (a macro takes nothing else, no texture of
-- an addon): the one given, else the action's (Actions.MacroIcon), else
-- the question mark
local function FileID(icon)
    if type(icon) == "number" then return icon end
    if type(icon) ~= "string" or not GetFileIDFromPath then return nil end
    for _, ext in ipairs({ "", ".blp", ".tga" }) do
        local id = GetFileIDFromPath(icon .. ext)
        if type(id) == "number" and id > 0 then return id end
    end
end

local function MacroIcon(action, icon)
    local kind = (action or ""):match("^(%a+):")
    return FileID(icon) or (not kind and FileID(IF.Actions.MacroIcon(action))) or 134400
end

local function OurMacro(action, label, body, icon)
    icon = MacroIcon(action, icon)
    if not body then return nil end
    local map = Macros()
    for name, a in pairs(map) do
        if a == action and GetMacroIndexByName(name) > 0 then
            EditMacro(name, name, icon, body)
            return name
        end
    end
    local name = (PREFIX .. (label or action)):sub(1, 16)
    if GetMacroIndexByName(name) == 0 then
        local _, perChar = GetNumMacros()
        if perChar >= (MAX_CHARACTER_MACROS or 18) then
            UIErrorsFrame:AddMessage("Improved Forever: no room for another character macro", 1, 0.3, 0.3)
            return nil
        end
        if not CreateMacro(name, icon, body, true) then return nil end
    else
        EditMacro(name, name, icon, body)
    end
    map[name] = action
    return name
end

---------------------------------------------------------------------------
-- Reading and writing a slot
---------------------------------------------------------------------------
-- What the press's slot holds: an action ("spell:<id>", "item:<id>",
-- "macro:<name>", or what one of our macros stands for: "emote:wave",
-- "map", "wheel:quest"...), or nil (empty, or not a crossbar press)
function N.Get(spec)
    local storage = Storage(spec)
    if not storage then return nil end
    local kind, id = GetActionInfo(storage)
    if kind == "spell" then return "spell:" .. id end
    if kind == "item" then return "item:" .. id end
    if kind == "macro" then
        local name = GetMacroInfo(id)
        if not name then return nil end
        return Macros()[name] or ("macro:" .. name)
    end
    return nil
end

local function Pickup(kind, value)
    if kind == "spell" then
        local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
        return pickup, tonumber(value)
    elseif kind == "item" then
        local pickup = (C_Item and C_Item.PickupItem) or PickupItem
        return pickup, tonumber(value)
    elseif kind == "macro" then
        return PickupMacro, value
    end
end

-- Puts an action in the press's slot (label / icon: for a macro of ours);
-- false if it couldn't. Out of combat.
function N.Set(spec, action, label, icon)
    local storage = Storage(spec)
    if not storage or IF.InCombat() then return false end
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    local pickup, arg = Pickup(kind, value)
    if not pickup then
        local wheel = kind == "wheel" and value
        local made = kind and N.MacroBodies[kind]
        local body = (made and made(value)) or (wheel and N.WheelBody(wheel)) or IF.Override.Macro(action)
        local name = OurMacro(action, label, body, icon)
        if not name then return false end
        pickup, arg = PickupMacro, name
    end
    bound = nil
    return Util().AssignActionToGamepadStandardSlot(storage, pickup, arg) and true or false
end

-- Empties the press's slot
function N.Clear(spec)
    local storage = Storage(spec)
    if not storage or IF.InCombat() then return end
    bound = nil
    Util().ClearActionFromGamepadSlot(storage)
end

-- Every press whose slot holds something (the D-pad alone, and both
-- modifiers' bars), with what; read once a frame (every binding asks)
function N.Bound()
    if bound and boundAt == GetTime() then return bound end
    local list = {}
    bound, boundAt = list, GetTime()
    if not N.Available() then return list end
    -- (the bars: none held, each modifier, both)
    local left, right = GetBindingKey("GAMEPADLEFTMOD"), GetBindingKey("GAMEPADRIGHTMOD")
    local helds = { {} }
    if left then helds[#helds + 1] = { left } end
    if right then helds[#helds + 1] = { right } end
    if left and right then helds[#helds + 1] = { left, right } end
    for _, held in ipairs(helds) do
        for n = 1, PER_BAR do
            local pressed = GetBindingKey("GAMEPADACTIONBUTTON" .. n)
            local spec = pressed and IF.Binds.SpecOf(held, pressed)
            local action = spec and N.Get(spec)
            if action then list[#list + 1] = { spec = spec, action = action } end
        end
    end
    return list
end

-- The game's bars changed (a slot, a page, the bindings): the panel redraws
local events = CreateFrame("Frame")
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_BINDINGS" then keys = nil end
    bound = nil
    if IF.Menu and IF.Menu.IsOpen() then IF.Menu.Render() end
end)
-- (the page shown is read as the panel draws: no callback of ours in the
-- crossbar's lists, which would taint its secure work)

-- Our windows' macros made before their icons were right (the question
-- mark): each given its window's icon, once a session
IF.OnLogin(function()
    if IF.InCombat() then return end
    for name, action in pairs(Macros()) do
        local _, current, body = GetMacroInfo(name)
        if body and not action:find(":", 1, true) then
            local icon = MacroIcon(action)
            if icon ~= current then EditMacro(name, name, icon, body) end
        end
    end
end)
