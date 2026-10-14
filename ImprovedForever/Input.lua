-- The input in hand: the pad, or the mouse and keyboard. Our windows look
-- and work for the one used last, as the game's own do (its prompts and
-- hotkeys follow GAME_PAD_ACTIVE_CHANGED): the pad's legend, cursor and
-- focus glow while it's the pad; buttons to click and tooltips on hover
-- with the mouse. Both always work.
--   IF.Input.Pad() -> true while the pad is the input
--   IF.Input.OnChange(fn): fn(pad) as it changes
--   IF.Input.AddItemClick{ id, button, label, when(item), fn(item) }: an
--     Alt + click (button "LeftButton" / "RightButton") on an item, wherever
--     the game's modified clicks reach (bags, loot window, chat links...);
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

-- Gamepad mode on (Options > Controller), and a pad plugged in
local function Enabled()
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
    return pad
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
        if arg == "GamePadEnable" or arg == "GAMEPAD_ENABLE" then Set(pad) end
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
-- Items under the mouse, and Alt + clicks on them
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

local clicks = {}

function I.AddItemClick(def)
    for i, other in ipairs(clicks) do
        if other.id == def.id then
            clicks[i] = def
            return def
        end
    end
    clicks[#clicks + 1] = def
    return def
end

-- The Alt + clicks there are, for a help text: { { button, label } }
function I.ItemClicks()
    return clicks
end

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link, location)
        if not (link and IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then return end
        if IF.InCombat() then return end
        local button = GetMouseButtonClicked and GetMouseButtonClicked() or "LeftButton"
        local item = ItemOf(Focus(), link, location)
        if not item then return end
        for _, def in ipairs(clicks) do
            if (def.button or "LeftButton") == button and (not def.when or def.when(item)) then
                def.fn(item)
                return
            end
        end
    end)
end

IF.AddCommand("input", function(args)
    local mode = args[1]
    if mode == "auto" or mode == "pad" or mode == "mouse" then I.SetMode(mode) end
    IF.Print("input: " .. (IF.db.inputMode or "auto") .. " (now " .. (I.Pad() and "the pad" or "the mouse and keyboard") .. ")")
end, "[auto|pad|mouse]: windows for the pad or the mouse (auto: the one used last)")
