-- DualSense touchpad clicks. Clicking the pad runs the action of the corner
-- the finger is in (the pad's four quarters): an interface window, a
-- spell, an item or a macro.
--
-- Why a click and not a swipe: on Forever, opening a game window from addon
-- code taints it (its gamepad action bar then trips over a protected call,
-- SetPreferredGamepadInteractTarget, and the game blocks the addon), and
-- Forever passes on only presses from real buttons, so a swipe can't stand
-- in for one. The pad click is a real button (PADBACK): it clicks a secure
-- button whose snippet reads the finger position (GetGamePadState, mapped
-- stick 4) and runs "/click <the game's own button for that window>", as
-- Controller Forever's wheel does. Inside a real press that is a real click,
-- so the window opens untainted, without a prompt, in combat too.
local _, IF = ...

local touch = {}
IF.Touch = touch

-- (/if peek: printed and logged, PeekMap.Say)
local function Say(text)
    if IF.PeekMap and IF.PeekMap.Say then IF.PeekMap.Say(text) end
end

local PAD_STICK = 4       -- StickConfigNameToIndex("Pad") is nil on Forever
local KEY = "PADBACK"     -- what the game calls a touchpad click
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }

-- Double taps: run by the secure click (below) when a corner has one; none
-- by default now ({ downright = "recentloot" } was one); the Bindings tab
-- records one (RECORD_DOUBLE)
touch.DOUBLE_DEFAULTS = {}

-- A corner's press with L2 held, by default (each only once its action's
-- button is there: the module loaded; "none": the player's choice)
touch.LAYER_DEFAULTS = {
    LT = { downright = "recentloot", upright = "questlog", downleft = "professions", upleft = "talents" },
    RT = { upleft = "journal", upright = "fishcollection", downleft = "wiki" },
}
touch.RECORD_DOUBLE = true

touch.REGIONS = { "upleft", "upright", "downleft", "downright" }
touch.REGION_LABELS = {
    up = "Top", down = "Bottom", left = "Left", right = "Right", centre = "Centre",
    upleft = "Top left", upright = "Top right", downleft = "Bottom left", downright = "Bottom right",
}

-- (top right: the peek map when the Map module is loaded, else the spellbook)
local DEFAULTS = {
    upleft = "character",
    upright = function() return IF.PeekMap and "peekmap" or "spellbook" end,
    downleft = "character",
    downright = "bags",
}
-- An earlier version had sides and a centre too: their actions move to the
-- corners nearest them, once (top -> top left, right -> top right...)
local FROM_SIDES = { upleft = "up", upright = "right", downleft = "left", downright = "down" }

function touch.GetSettings()
    local db = IF.db
    db.touch = db.touch or {}
    local settings = db.touch
    settings.regions = settings.regions or {}
    if not settings.quarters then
        settings.quarters = true
        local any = false
        for corner in pairs(FROM_SIDES) do
            if settings.regions[corner] and settings.regions[corner] ~= "none" then any = true end
        end
        if not any then
            for corner, side in pairs(FROM_SIDES) do
                local action = settings.regions[side]
                if action and action ~= "none" then settings.regions[corner] = action end
            end
        end
        for _, gone in ipairs({ "up", "down", "left", "right", "centre" }) do
            settings.regions[gone] = nil
        end
    end
    -- (the top left's earlier default, the quest log, now the Character
    -- window's: moved once, when it was never changed)
    if not settings.upleftMoved then
        settings.upleftMoved = true
        if settings.regions.upleft == "questlog" then settings.regions.upleft = "character" end
    end
    for region, action in pairs(DEFAULTS) do
        -- (one that depends on a module: only once every addon has loaded)
        if settings.regions[region] == nil and (type(action) ~= "function" or IsLoggedIn()) then
            settings.regions[region] = type(action) == "function" and action() or action
        end
    end
    -- (a corner's double tap: supported, none made by default for now, nor
    -- recorded in the Bindings tab: touch.RECORD_DOUBLE)
    settings.doubles = settings.doubles or {}
    -- (a corner's press with L2 / R2 held: layers.LT / RT / LTRT[region])
    settings.layers = settings.layers or {}
    -- (the doubles made while it was a test (a single click recorded as a
    -- double, a corner's single stopping for it): given up, once)
    if settings.doublesReset ~= 2 then
        settings.doublesReset = 2
        wipe(settings.doubles)
    end
    -- (L2 + bottom left's earlier default, the Journal: now Talents, moved
    -- once, when it was never changed)
    if not settings.downleftLTMoved then
        settings.downleftLTMoved = true
        if settings.layers.LT and settings.layers.LT.downleft == "journal" then
            settings.layers.LT.downleft = "talents"
        end
    end
    -- (and then Talents: now Professions, moved once, when never changed)
    if not settings.downleftLTMoved2 then
        settings.downleftLTMoved2 = true
        if settings.layers.LT and settings.layers.LT.downleft == "talents" then
            settings.layers.LT.downleft = "professions"
        end
    end
    for layer, corners in pairs(touch.LAYER_DEFAULTS) do
        settings.layers[layer] = settings.layers[layer] or {}
        for region, action in pairs(corners) do
            if IsLoggedIn() and settings.layers[layer][region] == nil and IF.Actions.Macro(action) then
                settings.layers[layer][region] = action
            end
        end
    end
    for region, action in pairs(touch.DOUBLE_DEFAULTS) do
        if IsLoggedIn() and settings.doubles[region] == nil and IF.Actions.Macro(action) then
            settings.doubles[region] = action
        end
    end
    return settings
end

-- A region's action: an interface window or a game action (Actions.lua)
touch.IsBound = IF.Actions.IsBound
touch.GetActions = IF.Actions.Windows
touch.ActionIcon = IF.Actions.Icon
touch.ActionLabel = IF.Actions.Label
touch.Macro = IF.Actions.Macro
touch.InterfaceEntries = IF.Actions.InterfaceEntries

-- The corner a finger position falls in (the secure click's own test).
-- nil: every candidate is off.
function touch.RegionAt(x, y)
    -- The quarter the finger is in; one turned off gives its area to the
    -- corner beside it, then the one above / below it
    local h, v = x > 0 and "right" or "left", y > 0 and "up" or "down"
    local beside = v .. (h == "right" and "left" or "right")
    local across = (v == "up" and "down" or "up") .. h
    for _, name in ipairs({ v .. h, beside, across }) do
        if not touch.IsOff(name) then return name end
    end
end

-- Where the finger is on the pad now, or nil
function touch.FingerPosition()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local stick = state and state.sticks and state.sticks[PAD_STICK]
    if stick then return stick.x or 0, stick.y or 0 end
end

-- A slot turned off: a corner's area becomes its sides', another does
-- nothing when clicked
touch.CORNERS = { upleft = true, upright = true, downleft = true, downright = true }

function touch.IsOff(region)
    local off = touch.GetSettings().off
    return off ~= nil and off[region] == true
end

function touch.ToggleOff(region)
    local settings = touch.GetSettings()
    settings.off = settings.off or {}
    settings.off[region] = not settings.off[region] or nil
    touch.Apply()
    return settings.off[region] == true
end

-- A corner's double tap action (a second tap within a moment of the
-- first), or nil
function touch.DoubleOf(region)
    local action = touch.GetSettings().doubles[region]
    return IF.Actions.IsBound(action) and action or nil
end

function touch.SetDouble(region, key)
    touch.GetSettings().doubles[region] = key or "none"
    touch.Apply()
end

-- A corner's press with L1 ("LB"), R1 ("RB"), L2 ("LT"), R2 ("RT") or
-- several held (in that order: "LBRT"): its action, or nil
local HELD_NAME = { PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT" }
local ORDER = { "LB", "RB", "LT", "RT" }
touch.LAYERS = {}
for mask = 1, 15 do
    local name = ""
    for i, part in ipairs(ORDER) do
        if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then name = name .. part end
    end
    touch.LAYERS[#touch.LAYERS + 1] = name
end

function touch.LayerAction(region, layer)
    local settings = touch.GetSettings()
    local action = settings.layers[layer] and settings.layers[layer][region]
    return IF.Actions.IsBound(action) and action or nil
end

function touch.SetLayerAction(region, layer, key)
    local settings = touch.GetSettings()
    settings.layers[layer] = settings.layers[layer] or {}
    settings.layers[layer][region] = key or "none"
    touch.Apply()
end

-- The layer of a held list ("PADLSHOULDER", "PADRTRIGGER+PADLTRIGGER"), or
-- nil (nothing held, or a button that makes none)
function touch.LayerOf(held)
    local has = {}
    for key in (held or ""):gmatch("[^%+]+") do
        if not HELD_NAME[key] then return nil end
        has[HELD_NAME[key]] = true
    end
    local name = ""
    for _, part in ipairs(ORDER) do
        if has[part] then name = name .. part end
    end
    return name ~= "" and name or nil
end

function touch.SetAction(region, key)
    touch.GetSettings().regions[region] = key or "none"
    touch.Apply()
end

---------------------------------------------------------------------------
-- The secure click
---------------------------------------------------------------------------

local click = CreateFrame("Button", "ImprovedForeverTouchClick", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
click:SetSize(1, 1)
click:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
click:RegisterForClicks("AnyDown", "AnyUp")
click:SetAttribute("ic-stick", PAD_STICK)

-- A double tap: a second tap within DOUBLE seconds of the first. The secure
-- click can't tell time, so a plain frame per corner, shown that long after
-- a tap (from insecure code, fine in combat), tells it
local DOUBLE = 0.35
local windows = {}
for _, region in ipairs(touch.REGIONS) do
    local w = CreateFrame("Frame", nil, UIParent)
    w:Hide()
    w:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left <= 0 then self:Hide() end
    end)
    -- (the click is the game's once it's over, a window being open: Apply)
    w:SetScript("OnHide", function()
        if IF.db and not IF.InCombat() then touch.Apply() end
    end)
    SecureHandlerSetFrameRef(click, "win-" .. region, w)
    windows[region] = w
end

-- A tap's window is open (a second one runs the double tap's action)
function touch.DoubleOpen()
    for _, w in pairs(windows) do
        if w:IsShown() then return true end
    end
    return false
end

-- Acts on the press or the release, whichever ActionButtonUseKeyDown makes
-- action buttons fire on, and only once per click (the pad's left and right
-- halves are two raw buttons that both report as a click). The secure
-- environment has no GetTime or math, so a "held" flag does the debouncing.
SecureHandlerWrapScript(click, "OnClick", click, [[
    self:SetAttribute("type", nil)
    local keydown = (self:GetAttribute("ic-keydown") or 1) == 1
    if down then
        if self:GetAttribute("ic-held") then
            return false
        end
        self:SetAttribute("ic-held", true)
        self:SetAttribute("ic-region", nil)
        self:SetAttribute("useOnKeyDown", nil)
        if not keydown then
            return false
        end
    else
        if not self:GetAttribute("ic-held") then
            return false
        end
        self:SetAttribute("ic-held", nil)
        if keydown then
            -- A corner that is held (the peek map): its release closes the
            -- map it opened (PeekMap.SNIPPET)
            local region = self:GetAttribute("ic-region")
            if not (region and self:GetAttribute("ic-peek-" .. region)) then
                return false
            end
            return self:RunAttribute("ic-peek", false, self:GetAttribute("ic-macro-" .. region))
        end
    end
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("ic-stick")]
    local x, y = stick and stick.x or 0, stick and stick.y or 0
    -- The quarter under the finger; one turned off gives its area to the
    -- corner beside it, then the one above / below it (touch.RegionAt)
    local h, v = x > 0 and "right" or "left", y > 0 and "up" or "down"
    local order = newtable(v .. h, v .. (h == "right" and "left" or "right"),
        (v == "up" and "down" or "up") .. h)
    local region
    for _, name in ipairs(order) do
        if not self:GetAttribute("ic-off-" .. name) then
            region = name
            break
        end
    end
    if not region then
        return false
    end
    self:SetAttribute("ic-region", region)
    self:SetAttribute("ic-twice", nil)
    local macro = self:GetAttribute("ic-macro-" .. region)
    -- L2 / R2 held: the corner's press of that layer, when it has one (as the
    -- crossbar's layers: the game's bars read the triggers themselves)
    local pad = state and state.buttons
    local lb, rb = self:GetAttribute("ic-lb"), self:GetAttribute("ic-rb")
    local lt, rt = self:GetAttribute("ic-lt"), self:GetAttribute("ic-rt")
    if pad then
        local layer = ((lb and pad[lb]) and "LB" or "") .. ((rb and pad[rb]) and "RB" or "")
            .. ((lt and pad[lt]) and "LT" or "") .. ((rt and pad[rt]) and "RT" or "")
        local layered = layer ~= "" and self:GetAttribute("ic-lmacro-" .. layer .. "-" .. region)
        if layered then
            self:SetAttribute("ic-region", nil)
            self:SetAttribute("macrotext", layered)
            self:SetAttribute("type", "macro")
            return
        end
    end
    -- A second tap within a moment of the first: the corner's double
    -- tap's action instead (its window shown by the first, PostClick)
    local again = self:GetAttribute("ic-dmacro-" .. region)
    local window = again and self:GetFrameRef("win-" .. region)
    if window and window:IsShown() then
        self:SetAttribute("ic-twice", true)
        self:SetAttribute("macrotext", again)
        self:SetAttribute("type", "macro")
        return
    end
    if not macro then
        if again then
            return
        end
        return false
    end
    -- (the peek map's press opens it, PeekMap.SNIPPET)
    if self:GetAttribute("ic-peek-" .. region) then
        return self:RunAttribute("ic-peek", true, macro)
    end
    self:SetAttribute("macrotext", macro)
    self:SetAttribute("type", "macro")
]])

click:SetScript("PostClick", function(self, button, down)
    local settings = IF.db and touch.GetSettings()
    -- (the tap that acted: a window for the second one, or the pair done)
    local acts = (self:GetAttribute("ic-keydown") == 1) == (down and true or false)
    local tapped = self:GetAttribute("ic-region")
    if acts and tapped and windows[tapped] and settings and touch.DoubleOf(tapped) then
        local w = windows[tapped]
        if self:GetAttribute("ic-twice") then
            w:Hide()
        else
            w.left = DOUBLE
            w:Show()
        end
    end
    -- (the peek map's corner opened the map: shown as the peek map)
    local region = self:GetAttribute("ic-region")
    if IF.PeekMap and IF.PeekMap.debug then
        Say("peek: pad " .. (down and "down" or "up") .. ", corner " .. tostring(region)
            .. " (" .. tostring(region and settings.regions[region]) .. ", held: "
            .. tostring(region and self:GetAttribute("ic-peek-" .. region)) .. "), ran: "
            .. tostring(self:GetAttribute("type") and self:GetAttribute("macrotext")) .. ", map open: "
            .. tostring(WorldMapFrame and WorldMapFrame:IsShown()))
    end
    if settings and region and settings.regions[region] == "peekmap" and IF.PeekMap then
        IF.PeekMap.Opened()
    end
    if settings and settings.debug and self:GetAttribute("type") then
        local region = self:GetAttribute("ic-region")
        IF.Print("touch: " .. tostring(touch.REGION_LABELS[region]) .. " -> "
            .. touch.ActionLabel(settings.regions[region]))
    end
end)

---------------------------------------------------------------------------
-- Settings onto the secure button (out of combat only)
---------------------------------------------------------------------------

local pending = false

-- A game window open (bags, Character...): the click is the game's own then
-- (TOGGLEUIFOCUS), moving the pad onto the window and back. Read from the
-- frame manager, never called (Focus.lua)
local function WindowsShown()
    local manager = _G.GamepadMode and GamepadMode.FrameControlsManager
    return manager ~= nil and manager.shownFrames ~= nil and #manager.shownFrames > 0
end

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    pcall(setter, name, value)
end

-- A finger sliding on the pad moves the mouse cursor (the game's touch
-- cursor) and shows it, which a click on a corner starts with: off while
-- the click is ours, the player's own setting back when it isn't (kept in
-- the settings in case the game closes before it's given back)
local CURSOR_CVAR = "GamePadTouchCursorEnable"

local function BlockTouchCursor(block)
    local settings = touch.GetSettings()
    local current = GetCVarSafe(CURSOR_CVAR)
    if current == nil then return end
    if block then
        if current ~= "0" then
            settings.touchCursor = current
            SetCVarSafe(CURSOR_CVAR, "0")
        end
    elseif settings.touchCursor ~= nil then
        local saved = settings.touchCursor
        settings.touchCursor = nil
        if current ~= saved then SetCVarSafe(CURSOR_CVAR, saved) end
    end
end

function touch.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = false
    local settings = touch.GetSettings()
    click:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
    local function PadIndex(button)
        local index = C_GamePad and C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(button)
        return index and index + 1 or nil
    end
    click:SetAttribute("ic-lb", PadIndex("PADLSHOULDER"))
    click:SetAttribute("ic-rb", PadIndex("PADRSHOULDER"))
    click:SetAttribute("ic-lt", PadIndex("PADLTRIGGER"))
    click:SetAttribute("ic-rt", PadIndex("PADRTRIGGER"))
    local keydown = click:GetAttribute("ic-keydown") == 1
    for _, region in ipairs(touch.REGIONS) do
        local off = touch.IsOff(region)
        local action = settings.regions[region]
        -- The peek map: open while the pad is held (where actions run on
        -- the press; else each click opens / closes it)
        -- (a corner with a double tap keeps its single one: a secure press can't
        -- be held back to see whether a second follows; as the fishing pole's
        -- R2, the second tap first undoes the first's)
        local double = touch.DoubleOf(region)
        local peek = action == "peekmap" and keydown and not off and not double
        click:SetAttribute("ic-off-" .. region, off or nil)
        click:SetAttribute("ic-macro-" .. region, not off and touch.Macro(action) or nil)
        click:SetAttribute("ic-peek-" .. region, peek or nil)
        for _, layer in ipairs(touch.LAYERS) do
            local held = touch.LayerAction(region, layer)
            click:SetAttribute("ic-lmacro-" .. layer .. "-" .. region, not off and held and touch.Macro(held) or nil)
        end
        -- (its double tap's action, after what undoes the first tap's: a window
        -- toggled again, a cast stopped (Fishing.lua's lure does the same))
        local dmacro = not off and double and touch.Macro(double) or nil
        if dmacro then
            local single = touch.Macro(action)
            if single and IF.Actions.IsWindow(action) and action ~= "peekmap" then
                dmacro = single .. "\n" .. dmacro
            elseif type(action) == "string" and action:match("^spell:") then
                dmacro = "/stopcasting\n" .. dmacro
            end
        end
        click:SetAttribute("ic-dmacro-" .. region, dmacro)
    end
    if WorldMapFrame then
        click:SetFrameRef("map", WorldMapFrame)
        if WorldMapFrame.ScrollContainer then click:SetFrameRef("map-scroll", WorldMapFrame.ScrollContainer) end
    end
    if IF.PeekMap then click:SetAttribute("ic-peek", IF.PeekMap.SNIPPET) end
    ClearOverrideBindings(click)
    -- While the panel is open it owns the touchpad click (it picks the slot
    -- under the finger); it gives it back when it closes (BindEditor.lua).
    -- Only a PlayStation pad has a touchpad: on others the same button is
    -- View / Minus, left to the game.
    local panelOpen = IF.Menu and IF.Menu.IsOpen and IF.Menu.IsOpen()
    -- (and only while the game has the gamepad's focus, Binds.lua, with no
    -- window of its open for its own click to focus; through combat whatever
    -- is open, as the other world bindings. Or the peek map has it: the
    -- pad's release closes it)
    local free = not WindowsShown() or UnitAffectingCombat("player") or touch.DoubleOpen()
    local inGame = (IF.Binds.InGame() and free) or (IF.PeekMap and IF.PeekMap.IsPeeking())
    local ours = settings.enabled ~= false and IF.PadStyle() == "Shapes"
    if ours and not panelOpen and inGame then
        for _, modifier in ipairs(MODIFIERS) do
            SetOverrideBindingClick(click, true, modifier .. KEY, click:GetName(), "LeftButton")
        end
    end
    if IF.PeekMap and IF.PeekMap.debug then
        Say("touch: apply, bound: " .. tostring(ours and not panelOpen and inGame) .. ", in game: "
            .. tostring(IF.Binds.InGame()) .. ", windows: " .. tostring(WindowsShown()) .. ", peeking: "
            .. tostring(IF.PeekMap.IsPeeking()) .. ", panel open: " .. tostring(panelOpen))
    end
    -- (the panel picks the corner under the finger too)
    BlockTouchCursor(ours and (inGame or panelOpen) and true or false)
end

-- /if peek: why the click is or isn't ours, each part of touch.Apply's test
function touch.Probe()
    local settings = touch.GetSettings()
    local manager = _G.GamepadMode and GamepadMode.FrameControlsManager
    local names = {}
    for _, frame in ipairs(manager and manager.shownFrames or {}) do
        names[#names + 1] = type(frame) == "table" and frame.GetName and (frame:GetName() or "?") or tostring(frame)
    end
    Say("touch: PADBACK -> " .. tostring(GetBindingAction(KEY, true)) .. ", enabled: "
        .. tostring(settings.enabled ~= false) .. ", pad: " .. tostring(IF.PadStyle()) .. ", panel open: "
        .. tostring(IF.Menu and IF.Menu.IsOpen and IF.Menu.IsOpen()) .. ", in game: " .. tostring(IF.Binds.InGame())
        .. ", windows: " .. (#names > 0 and table.concat(names, " ") or "none") .. ", pending: " .. tostring(pending))
    local x, y = touch.FingerPosition()
    Say("touch: finger " .. tostring(x) .. ", " .. tostring(y) .. ", keydown: "
        .. tostring(click:GetAttribute("ic-keydown")) .. ", top right: " .. tostring(click:GetAttribute("ic-macro-upright"))
        .. ", held: " .. tostring(click:GetAttribute("ic-peek-upright")) .. ", cursor: " .. tostring(GetCVarSafe(CURSOR_CVAR)))
end

function touch.CycleAction(region, step)
    local settings = touch.GetSettings()
    local list = touch.GetActions()
    local current = 1
    for index, key in ipairs(list) do
        if key == settings.regions[region] then
            current = index
        end
    end
    settings.regions[region] = list[(current - 1 + step) % #list + 1]
    touch.Apply()
end


-- An earlier version turned the touchpad edges into paddle buttons with a
-- gamepad config; Forever ignores those presses, so take it out again.
local function RemoveOldConfig(settings)
    if settings.configInstalled and C_GamePad and C_GamePad.DeleteConfig then
        C_GamePad.DeleteConfig({ vendorID = 1356, productID = 3302 })
        C_GamePad.ApplyConfigs()
    end
    settings.configInstalled, settings.actions, settings.reach, settings.buttons = nil, nil, nil, nil
end

IF.OnLogin(function()
    RemoveOldConfig(touch.GetSettings())
    touch.Apply()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if not IF.db then
        return
    end
    -- (the touch cursor saved as the player had it; blocked again at login)
    if event == "PLAYER_LOGOUT" then
        return BlockTouchCursor(false)
    end
    if pending or event == "CVAR_UPDATE" then
        touch.Apply()
    end
end)

-- A game window opened or closed: the click is ours or the game's again
local lastShown, wait = nil, 0
events:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 or not IF.db then return end
    wait = 0.1
    local now = WindowsShown()
    if now ~= lastShown then
        lastShown = now
        touch.Apply()
    end
end)

-- Another controller in hand: the touchpad click only on a PlayStation pad
IF.OnPadStyleChanged(function() touch.Apply() end)

-- Its binding, on the Bindings tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "touch", label = "Touchpad corners", group = "Other", tab = "bindings",
    icon = "gamepad-ps-touchpad-normal", context = "world", order = 32,
    tip = "Clicking the touchpad runs what its corner holds (set on its corners here). PlayStation controllers only.",
    accepts = function(spec) return spec == "PADBACK" and IF.PadStyle() == "Shapes" end,
    specs = function()
        local on = IF.Touch.GetSettings().enabled ~= false and IF.PadStyle() == "Shapes"
        return on and { "PADBACK" } or {}
    end,
    set = function(spec)
        IF.Touch.GetSettings().enabled = spec ~= nil
        IF.Touch.Apply()
    end,
})
