-- The input in hand: the pad, or the mouse and keyboard. Our windows look
-- and work for the one used last, as the game's own do (its prompts and
-- hotkeys follow GAME_PAD_ACTIVE_CHANGED): the pad's legend, cursor and
-- focus glow while it's the pad; buttons to click and tooltips on hover
-- with the mouse. Both always work.
--   IF.Input.Pad() -> true while the pad is the input
--   IF.Input.PadEnabled() -> the game's Gamepad UI on (Options > Gamepad:
--     Enable Gamepad UI); off, our windows are the mouse's whatever is used,
--     and only keyboard / mouse presses are bound (Bindings tab)
--   IF.Input.OnChange(fn): fn(pad) as it changes
--   A modified click on an item, wherever the game's modified clicks reach
--     (bags, loot window, chat links...), runs the binding on that click
--     (Binds.lua: a binding's keyboard / mouse press, "ALT-BUTTON1"), with
--     item = { link, bag, slot, owner } (owner: the frame clicked)
--   IF.Input.Hovered() -> the item under the mouse, as above, or nil
-- /if input [auto|pad|mouse]: which one (auto: the one used last)
local _, IF = ...

local I = {}
IF.Input = I

local PAD_KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK",
    "PADFORWARD", "PADBACK",
}
local LOOK_EVERY = 0.2
local MOVED = 24        -- the mouse moved this far (px) between looks: it's in hand

local pad
local listeners = {}

-- The game's Gamepad UI on (InputUtil, CVar InputDeviceInterfaceStyle)
local function GamepadUI()
    local util = _G.InputUtil
    if util and util.IsGamepadUIEnabled then
        local ok, on = pcall(util.IsGamepadUIEnabled)
        if ok then return on and true or false end
    end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local style = get and get("InputDeviceInterfaceStyle")
    local gamepad = Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
    if style == nil or gamepad == nil then return true end
    return tostring(style) == tostring(gamepad)
end

I.PadEnabled = GamepadUI

-- The Gamepad UI on, gamepad mode on (the pad's input), and a pad plugged in
local function Enabled()
    if not GamepadUI() then return false end
    if C_GamePad and C_GamePad.IsEnabled then return C_GamePad.IsEnabled() and true or false end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    return get ~= nil and get("GamePadEnable") == "1"
end

local function Connected()
    if not (C_GamePad and C_GamePad.GetAllDeviceIDs) then return Enabled() end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    return ok and type(ids) == "table" and #ids > 0
end

-- The cursor moved by the pad (the game's cursor control), not the mouse
local function PadCursor()
    return IsGamePadCursorControlEnabled ~= nil and IsGamePadCursorControlEnabled() and true or false
end

local function PadKeyDown()
    for _, key in ipairs(PAD_KEYS) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- /if input pad or mouse: that one whatever is used
local function Forced()
    local mode = IF.db and IF.db.inputMode
    if mode == "pad" then return true end
    if mode == "mouse" then return false end
end

function I.Pad()
    local forced = Forced()
    if forced ~= nil then return forced end
    if pad == nil then pad = Enabled() and Connected() end
    -- (the Gamepad UI off: the mouse's windows, whatever is in hand)
    return (pad and GamepadUI()) and true or false
end

function I.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Changed(was)
    local now = I.Pad()
    if now == was then return end
    for _, fn in ipairs(listeners) do fn(now) end
end

local function Set(on)
    local was = I.Pad()
    pad = (on and Enabled()) and true or false
    Changed(was)
end

function I.SetMode(mode)
    local was = I.Pad()
    IF.db.inputMode = (mode == "pad" or mode == "mouse") and mode or nil
    Changed(was)
end

local watch = CreateFrame("Frame")
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_DISCONNECTED", "CVAR_UPDATE", "GLOBAL_MOUSE_DOWN" }) do
    pcall(watch.RegisterEvent, watch, event)
end
watch:SetScript("OnEvent", function(_, event, arg)
    if event == "GAME_PAD_ACTIVE_CHANGED" then
        Set(arg)
    elseif event == "GAME_PAD_DISCONNECTED" then
        if not Connected() then Set(false) end
    elseif event == "CVAR_UPDATE" then
        if arg == "GamePadEnable" or arg == "GAMEPAD_ENABLE" or arg == "InputDeviceInterfaceStyle" then
            Set(pad or Connected())
        end
    elseif event == "GLOBAL_MOUSE_DOWN" then
        -- (a click the pad made: its cursor control, or a button of it held)
        if not PadCursor() and not PadKeyDown() then Set(false) end
    end
end)

-- (a look now and then, in case the game says nothing: a pad button down,
-- or the mouse moved by hand)
local lastX, lastY, wait = nil, nil, 0
watch:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = LOOK_EVERY
    local x, y = GetCursorPosition()
    if PadKeyDown() then
        if not pad then Set(true) end
    elseif pad and lastX and not PadCursor()
        and math.abs(x - lastX) + math.abs(y - lastY) > MOVED * (UIParent:GetEffectiveScale() or 1) then
        Set(false)
    end
    lastX, lastY = x, y
end)

---------------------------------------------------------------------------
-- Items under the mouse, and modified clicks on them
---------------------------------------------------------------------------
local function Focus()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        return foci and foci[1]
    end
    return GetMouseFocus and GetMouseFocus()
end

local function ItemOf(owner, link, location)
    local item = { link = link, owner = owner }
    if location and location.IsBagAndSlot and location:IsBagAndSlot() then
        item.bag, item.slot = location:GetBagAndSlot()
    elseif owner and owner.GetBagID and owner.GetID then
        local ok, bag = pcall(owner.GetBagID, owner)
        if ok and bag then item.bag, item.slot = bag, owner:GetID() end
    end
    if item.bag and not item.link and C_Container then
        item.link = C_Container.GetContainerItemLink(item.bag, item.slot)
    end
    return item.link and item or nil
end

function I.Hovered()
    local owner = Focus()
    local item = owner and ItemOf(owner)
    if item then return item end
    -- (else what the tooltip shows, an item's: loot, chat, merchant...)
    if GameTooltip:IsShown() and GameTooltip.GetItem then
        local _, link = GameTooltip:GetItem()
        if link then return { link = link, owner = GameTooltip:GetOwner() } end
    end
end

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link, location)
        if not link or IF.InCombat() or not IF.Binds then return end
        local button = GetMouseButtonClicked and GetMouseButtonClicked() or "LeftButton"
        local item = ItemOf(Focus(), link, location)
        if item then IF.Binds.RunClick(button, item) end
    end)
end

IF.AddCommand("input", function(args)
    local mode = args[1]
    if mode == "auto" or mode == "pad" or mode == "mouse" then I.SetMode(mode) end
    IF.Print("input: " .. (IF.db.inputMode or "auto") .. " (now " .. (I.Pad() and "the pad" or "the mouse and keyboard") .. ")")
end, "[auto|pad|mouse]: windows for the pad or the mouse (auto: the one used last)")
