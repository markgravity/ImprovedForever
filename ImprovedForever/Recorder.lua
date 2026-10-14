-- Recording a press to bind (Square, on every tab that binds): a box asks
-- for it, and the first button let go ends it: the press is what was
-- pressed last (a button pressed while others are held: all of them, "L1 +
-- R3", "L1 + R1 + R3"; asked for, pressed again quickly: twice). Circle alone (or Escape,
-- or 10 s without a press) cancels. The pad
-- is the box's alone while it is up, and until every button is let go
-- after, so no release leaks to the panel or the game.
-- Asked for (opts.keys / opts.clicks), a key pressed (with Alt / Ctrl /
-- Shift held: "ALT-F") or a click on the box with one held ("ALT-BUTTON1")
-- is recorded instead: opts.onKey(spec), for the binding's keyboard /
-- mouse press (Binds.lua). The game's Gamepad UI off: those only, no pad.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C
local menu = IF.Menu

local R = {}
IF.Recorder = R

local WAIT = 10      -- seconds for a first press
local DOUBLE = 0.35  -- seconds for the second press of a double one

-- state: nil (idle), "wait" (no press yet), "press" (buttons down),
-- "release" (done, waiting for the buttons to be let go), "again" (let go:
-- a second press now makes it twice); spec: the last press; down: the
-- buttons held, in the order pressed; info: the finger on the touchpad
-- when it was clicked ({ touch = { x, y } })
local box, opts, state, spec, down, deadline, info, again

local function Build()
    if box then return end
    -- (the panel's own window look, its title in its bar, its focus glow:
    -- it has the pad; above the panel, FULLSCREEN_DIALOG, and its tabs)
    local d = IF.UI.Window("ImprovedForeverRecorder", 480, 240, true)
    d:SetFrameStrata("TOOLTIP")
    IF.Focus.Glow(d, true)
    d.onClose = function() R.Finish(true) end
    d.hint = K.ChatText(d, 13, KC.cream2)
    d.hint:SetPoint("TOP", 0, -40)
    d.hint:SetWidth(430)
    d.hint:SetJustifyH("CENTER")
    d.hint:SetSpacing(4)
    d.glyphs = K.GlyphRow(d, 40)
    d.glyphs:SetPoint("CENTER", d, "CENTER", 0, -22)
    d.press = K.Text(d, 15, KC.cream)
    d.press:SetPoint("TOP", d.glyphs, "BOTTOM", 0, -6)
    d.press:SetJustifyH("CENTER")
    d.status = K.ChatText(d, 12, KC.grey)
    d.status:SetPoint("BOTTOM", 0, 22)
    d.status:SetJustifyH("CENTER")
    d:Hide()
    d:SetScript("OnKeyDown", function(_, key) R.OnKey(key) end)
    d:SetScript("OnMouseDown", function(_, button) R.OnClick(button) end)
    if d.EnableGamePadButton then
        d:SetScript("OnGamePadButtonDown", function(_, button) R.OnDown(button) end)
        d:SetScript("OnGamePadButtonUp", function(_, button) R.OnUp(button) end)
        -- (a gamepad handler switches the input on by itself: off till recording)
        d:EnableGamePadButton(false)
    end
    d:SetScript("OnUpdate", function() R.OnUpdate() end)
    box = d
end

local function Remove(button)
    for i = #down, 1, -1 do
        if down[i] == button then table.remove(down, i) end
    end
end

-- Let go of what the game no longer has down (a release we missed)
local function Prune()
    if not IsKeyDown then return end
    for i = #down, 1, -1 do
        if not IsKeyDown(down[i]) then table.remove(down, i) end
    end
end

function R.Render()
    local d = box
    local keys = spec and IF.Binds.Glyphs(spec)
    d.glyphs:Set(keys or {})
    d.glyphs:SetShown(keys ~= nil)
    d.press:SetText(spec and IF.Binds.Text(spec) or "")
    if state == "wait" then
        d.status:SetText(IF.PadText("Waiting for a press... " .. (IF.Input.Pad() and "{B} alone or Esc cancels."
            or "Esc cancels.")))
    elseif state == "press" or state == "again" then
        d.status:SetText(state == "again" and "" or "Let go to bind it.")
    else
        d.status:SetText("Let go of the buttons.")
    end
end

-- opts = { title, hint (what may be pressed), chord (false: one button
-- only), double (a quick second press makes it ":double"), accept =
-- function(spec) (false: not allowed), reject (its message, or
-- function(spec) -> it), onDone =
-- function(spec, info), onCancel = function() }
function R.Start(o)
    if IF.InCombat() then return false end
    Build()
    R.Stop()
    opts, state, spec, down, info, again = o, "wait", nil, {}, {}, false
    deadline = GetTime() + WAIT
    box:SetTitle(o.title or "Bind")
    -- (over the panel when it is open, else the screen's middle)
    box:ClearAllPoints()
    local panel = menu.IsOpen() and _G.ImprovedForeverConfigFrame
    box:SetPoint("CENTER", panel or UIParent, "CENTER", 0, panel and 0 or 20)
    -- (the keyboard / mouse ways first with the mouse in hand)
    local pad = IF.PadText((o.hint or ("Press the controller button for it"
        .. (o.chord ~= false and ", or hold one and press another" or "") .. "."))
        .. " Letting go of a button binds it.")
    local mouse = (o.keys and o.clicks) and "Press a key (Alt, Ctrl or Shift held too, if you like), or hold one of them and click here."
        or o.keys and "Press a key (Alt, Ctrl or Shift held too, if you like)."
        or o.clicks and "Hold Alt, Ctrl or Shift and click here."
    local padOn = IF.Input.PadEnabled()
    if not mouse then
        box.hint:SetText(pad)
    elseif not padOn then
        box.hint:SetText(mouse)
    elseif IF.Input.Pad() then
        box.hint:SetText(pad .. "\n" .. mouse)
    else
        box.hint:SetText(mouse .. "\n" .. pad)
    end
    box:Show()
    box:EnableKeyboard(true)
    box:SetPropagateKeyboardInput(false)
    if box.EnableGamePadButton then box:EnableGamePadButton(padOn or not mouse) end
    R.Render()
    if menu.IsOpen() then menu.Render() end
    return true
end

-- A key on the keyboard: Escape alone cancels; Alt / Ctrl / Shift wait for
-- the key they go with; any other, asked for, is the press
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true }

local function FinishKey(s)
    local o = opts
    R.Stop()
    if not o then return end
    C_Timer.After(0, function()
        local ok, why = true, nil
        if o.acceptKey then ok, why = o.acceptKey(s) end
        if not ok then
            menu.Toast(why or (IF.Binds.KeyText(s) .. " can't be used for this"), true, 3)
            if o.onCancel then o.onCancel() end
        else
            o.onKey(s)
        end
        if menu.IsOpen() then menu.Render() end
    end)
end

function R.OnKey(key)
    if state ~= "wait" then return end
    if key == "ESCAPE" and IF.Binds.ModsNow() == "" then return R.Finish(true) end
    if MODIFIER_KEYS[key] or not (opts and opts.keys and opts.onKey) then return end
    FinishKey(IF.Binds.ModsNow() .. key)
end

-- A click on the box: with Alt / Ctrl / Shift held, asked for, the press
function R.OnClick(button)
    if state ~= "wait" or not (opts and opts.clicks and opts.onKey) then return end
    local s = IF.Binds.ClickSpec(button)
    if not s then return end
    if not s:find("-", 1, true) then
        box.status:SetText("Hold Alt, Ctrl or Shift as you click.")
        return
    end
    FinishKey(s)
end

function R.IsActive()
    return state ~= nil
end

-- Gone without a word (the panel closed)
function R.Stop()
    if not box then return end
    state, opts = nil, nil
    box:Hide()
    if not IF.InCombat() then
        box:EnableKeyboard(false)
        if box.EnableGamePadButton then box:EnableGamePadButton(false) end
    end
end

function R.OnDown(button)
    if state == "release" then
        down[#down + 1] = button
        return
    end
    -- The second press of a double one (any other: ignored)
    if state == "again" then
        down[#down + 1] = button
        if button == spec then spec = spec .. ":double" end
        state = "release"
        return R.Render()
    end
    if button == "PADBACK" and IF.Touch and IF.Touch.FingerPosition then
        local x, y = IF.Touch.FingerPosition()
        info.touch = x and { x, y } or nil
    end
    Remove(button)
    Prune()
    -- Under every button still held, if more than one may be
    local held = opts.chord ~= false and { unpack(down) } or nil
    down[#down + 1] = button
    spec = IF.Binds.SpecOf(held, button)
    state = "press"
    R.Render()
end

function R.OnUp(button)
    -- (not one pressed while recording: Square's own release)
    local ours = false
    for _, b in ipairs(down) do
        if b == button then ours = true end
    end
    if not ours then return end
    Remove(button)
    -- The first one let go: the press is kept as it is now
    if state == "press" then
        state = "release"
        R.Render()
    end
    if state == "release" and #down == 0 then R.Released() end
end

-- Every button let go: done, or (a single press, twice asked for) a
-- moment for its second press
function R.Released()
    local held, _, double = IF.Binds.Parse(spec)
    if opts.double and not held and not double and not again then
        again = true
        state, deadline = "again", GetTime() + DOUBLE
        return R.Render()
    end
    R.Finish()
end

function R.OnUpdate()
    if (state == "wait" or state == "again") and GetTime() >= deadline then
        return R.Finish(state == "wait")
    end
    if state == "release" then
        Prune()
        if #down == 0 then R.Released() end
    end
end

-- Over: the last press bound (or cancelled), once the buttons are let go
function R.Finish(cancel)
    local o, s, i = opts, spec, info
    R.Stop()
    if not o then return end
    -- (on the next frame: the release that ended it is still being handled)
    C_Timer.After(0, function()
        if cancel or not s or s == "PAD2" then
            if o.onCancel then o.onCancel() end
        elseif o.accept and not o.accept(s) then
            local reject = type(o.reject) == "function" and o.reject(s) or o.reject
            menu.Toast(reject or (IF.Binds.Text(s) .. " can't be used for this"), true, 3)
            if o.onCancel then o.onCancel() end
        else
            o.onDone(s, i)
        end
        if menu.IsOpen() then menu.Render() end
    end)
end

-- The help bar while recording
function R.Hints()
    return { K.H({ "B" }, "Alone: cancel", "B") }
end

hooksecurefunc(menu, "Close", R.Stop)
