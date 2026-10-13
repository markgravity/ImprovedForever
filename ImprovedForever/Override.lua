-- Button overrides: a press of the controller (a spec, Binds.lua: a button,
-- a button pressed twice, or one pressed while a button the game turns into
-- Shift / Ctrl / Alt is held) runs a spell, an item, a macro, an emote or
-- opens a window instead of its own game action. Each is an override
-- binding to a secure button running a macro, so it works in combat (it can
-- only change out of it). Set in the Controller tab (BindEditor.lua);
-- IF.db.overrides = { [spec] = action }, actions as the touchpad's
-- (Touchpad.lua). Not on R3 (the wheels') nor a PlayStation touchpad (its
-- corners').
local _, IF = ...

local O = {}
IF.Override = O

function O.Settings()
    -- (the bind probe's log, the probe gone)
    IF.db.bindLog = nil
    IF.db.overrides = IF.db.overrides or {}
    -- A press the game keeps (Binds.GameOwns; set before it was refused):
    -- never runs, let go
    for spec in pairs(IF.db.overrides) do
        local _, _, double = IF.Binds.Parse(spec)
        if not double and IF.Binds.GameOwns(spec) then IF.db.overrides[spec] = nil end
    end
    return IF.db.overrides
end

function O.Get(button)
    return O.Settings()[button]
end

-- An action's name and icon (nil: none)
function O.ActionLabel(action)
    if not IF.Actions.IsBound(action) then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return (IF.ActionInfo(action)) or emote end
    return IF.Actions.Label(action)
end

function O.ActionIcon(action)
    if not IF.Actions.IsBound(action) then return nil end
    return IF.Actions.Icon(action) or select(2, IF.ActionInfo(action)) or 134400
end

-- What the button's secure click runs, or nil
function O.Macro(action)
    if type(action) ~= "string" or action == "none" then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return "/" .. emote end
    return IF.Actions.Macro(action)
end

-- The key a press is bound on, or nil when an action can't go on it
function O.BindingKey(spec)
    return IF.Binds.KeyOf(spec)
end

function O.Supports(spec)
    local _, _, double = IF.Binds.Parse(spec)
    if double then return O.BindingKey(spec) ~= nil or IF.Binds.DoubleKey(spec) ~= nil end
    return O.BindingKey(spec) ~= nil
end

-- A double press set, its single press not ours: watched (below), so out
-- of combat only
function O.NeedsSingle(spec)
    local held, pressed, double = IF.Binds.Parse(spec)
    return double and O.Get(spec) ~= nil and O.Get(IF.Binds.Spec(held, pressed)) == nil
end
O.OutOfCombatOnly = O.NeedsSingle

local owner = CreateFrame("Frame", "ImprovedForeverOverrides")
local buttons = {}
local pending = false

-- A double click: a second click within DOUBLE seconds of the first. The
-- secure click can't tell time, so a plain frame shown for that long
-- after each click (from insecure code, fine in combat) tells it
local DOUBLE = 0.35

local function SecureButton(key)
    local b = buttons[key]
    if b then return b end
    b = CreateFrame("Button", "ImprovedForeverOverride" .. key:gsub("%-", "_"), UIParent,
        "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    b:SetAttribute("type", "macro")
    -- (both edges, as every press of ours that works: a binding's click
    -- reaches a button registered for one only not at all; the one it acts
    -- on is ic-down's)
    b:RegisterForClicks("AnyDown", "AnyUp")
    local window = CreateFrame("Frame", nil, UIParent)
    window:Hide()
    window:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left <= 0 then self:Hide() end
    end)
    SecureHandlerSetFrameRef(b, "window", window)
    -- The second click of a pair runs the double click's action (if it has
    -- one), any other the single click's
    SecureHandlerWrapScript(b, "OnClick", b, [[
        if not down ~= not self:GetAttribute("ic-down") then return false end
        local window = self:GetFrameRef("window")
        local double = self:GetAttribute("ic-double")
        if double and window and window:IsShown() then
            self:SetAttribute("macrotext", double)
        else
            self:SetAttribute("macrotext", self:GetAttribute("ic-single"))
        end
        if not self:GetAttribute("macrotext") then return false end
    ]])
    -- After each click: the window opens, or a pair just ended it
    b:HookScript("OnClick", function(self, _, down)
        if not down ~= not self:GetAttribute("ic-down") then return end
        if window:IsShown() then
            window:Hide()
        else
            window.left = DOUBLE
            window:Show()
        end
    end)
    buttons[key] = b
    return b
end

function O.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = false
    ClearOverrideBindings(owner)
    -- Only while the game has the gamepad's focus (Binds.lua)
    if not IF.Binds.InGame() then return end
    -- Fires on the press or the release, as the game's action buttons do
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local onDown = get and get("ActionButtonUseKeyDown") ~= "0"
    -- Per key bound: its single and double press's macros
    local macros = {}
    for spec, action in pairs(O.Settings()) do
        local key, macro = O.BindingKey(spec), O.Macro(action)
        if key and macro then
            local _, _, double = IF.Binds.Parse(spec)
            macros[key] = macros[key] or {}
            macros[key][double and "double" or "single"] = macro
        end
    end
    -- A double press without a single one of ours: watched (below)
    wipe(O.watched)
    for spec, action in pairs(O.Settings()) do
        local key, macro = IF.Binds.DoubleKey(spec), O.Macro(action)
        if key and macro and O.NeedsSingle(spec) then
            local held, pressed = IF.Binds.Parse(spec)
            O.watched[#O.watched + 1] = { key = key, held = held, pressed = pressed, macro = macro, onDown = onDown }
        end
    end
    for key, m in pairs(macros) do
        -- Only with its own click's action: a double click alone would leave
        -- the single click doing nothing (the game's own action, autorun on
        -- L3, can't be run from here), so it is watched instead
        if m.single then
            local b = SecureButton(key)
            b:SetAttribute("ic-down", onDown)
            -- (the template acts on the edge this says, as Easy Controller's)
            b:SetAttribute("useOnKeyDown", onDown)
            b:SetAttribute("ic-single", m.single)
            b:SetAttribute("ic-double", m.double)
            -- (with priority, as the wheels' and the bags' presses: the
            -- game's own gamepad bindings, its Main Menu wheel on Options,
            -- would win over a plain override)
            SetOverrideBindingClick(owner, true, key, b:GetName(), "LeftButton")
        end
    end
end

-- An action for a button (nil / "none": back to the game's own)
function O.Set(button, action)
    O.Settings()[button] = (action and action ~= "none") and action or nil
    O.Apply()
end

---------------------------------------------------------------------------
-- Double presses whose single press stays the game's (L3's Auto Run, a
-- crossbar slot...): the game's binding can't be shared, so the button is
-- watched. When its first press is let go, the button is bound to a button
-- of ours for DOUBLE seconds: a second press then runs the double's action,
-- and the button goes back to the game. Bindings can't change in combat:
-- there the button is just the game's. (Armed on the release, not the
-- press: the game's binding gets its release, L2 / R2's crossbar paging
-- needs it.)
---------------------------------------------------------------------------
O.watched = {}
local watchOwner = CreateFrame("Frame", "ImprovedForeverDoubleWatch")
local twice = CreateFrame("Button", "ImprovedForeverDoubleAction", UIParent, "SecureActionButtonTemplate")
twice:SetAttribute("type", "macro")
local armed -- { w (the watched press), ends, fired }

local function Disarm()
    armed = nil
    if not IF.InCombat() then ClearOverrideBindings(watchOwner) end
end

local function Arm(w)
    if IF.InCombat() then return end
    twice:RegisterForClicks(w.onDown and "AnyDown" or "AnyUp")
    twice:SetAttribute("useOnKeyDown", w.onDown)
    twice:SetAttribute("macrotext", w.macro)
    SetOverrideBindingClick(watchOwner, true, w.key, twice:GetName(), "LeftButton")
    armed = { w = w, ends = GetTime() + DOUBLE }
end

twice:HookScript("OnClick", function()
    if armed then armed.fired = true end
end)

watchOwner:SetScript("OnUpdate", function()
    if not IsKeyDown then return end
    if armed then
        local w = armed.w
        local down = IsKeyDown(w.pressed)
        -- Over: done (once let go), timed out, or the held one let go
        if (armed.fired and not down) or (not armed.fired and GetTime() >= armed.ends)
            or (w.held and not IsKeyDown(w.held)) then
            Disarm()
        end
        return
    end
    if #O.watched == 0 or IF.InCombat() or not IF.Binds.InGame() or (IF.Menu and IF.Menu.IsOpen()) then
        return
    end
    for _, w in ipairs(O.watched) do
        local down = IsKeyDown(w.pressed) and (not w.held or IsKeyDown(w.held))
        -- The first press let go: the second one is ours for a moment
        if w.wasDown and not IsKeyDown(w.pressed) and (not w.held or IsKeyDown(w.held)) then Arm(w) end
        w.wasDown = down
        if armed then break end
    end
end)

watchOwner:RegisterEvent("PLAYER_REGEN_DISABLED")
watchOwner:SetScript("OnEvent", function() Disarm() end)

IF.OnLogin(O.Apply)
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("CVAR_UPDATE")
owner:SetScript("OnEvent", function(_, event)
    if not IF.db then return end
    -- (CVAR_UPDATE: which buttons are Shift / Ctrl / Alt may have changed)
    if pending or event == "CVAR_UPDATE" then O.Apply() end
end)
