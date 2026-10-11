-- The Controller tab: down the left every binding of ours (the wheels, the
-- bags', the others, the actions put on presses, the touchpad's corners)
-- with its press; beside it a drawing of the controller (each button marked
-- when something of ours is on it, red when two things clash there), the
-- picked binding's press lit, and under it what the press can do, on what
-- it does now: Cross binds. A choice taking a press from
-- something else asks first (Cross again). The left stick: up / down the
-- bindings, left / right the choices' lists (L2 / R2 too); the D-pad the
-- choices. A press can be picked by making it too:
-- Square ("Find press", Recorder.lua) and press the button (or hold one and
-- press another, or press one twice); a binding on no press: Square records
-- one for it.
-- The other tabs still bind their own things, through Binds.lua, so they
-- warn the same way.
-- On a PlayStation controller the touchpad shows its four corners: each
-- runs what it holds when the pad is clicked there (Touchpad.lua), picked
-- from Spells / Items / Macros / Interface (L2 / R2). Find press and click
-- the pad: the corner under the finger. Triangle clears one, held turns it
-- off.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local menu = IF.Menu
local B = IF.Binds
local touch = IF.Touch

local UI = IF.UI

local TEX = "Interface\\AddOns\\ImprovedForever\\textures\\"
local SIDE_W, PICKER_ROWS = 230, 4

-- The drawing (tools/make_controller.py) at SCALE, over the choices
local ART_W, ART_H, SCALE = 512, 256, 1.1

-- Its buttons: where they sit on the drawing (its pixels, y down), their
-- glyph's size; the touchpad's corners (region) in its recess
local SPOTS = {
    { key = "PADLTRIGGER", x = 148, y = 22 }, { key = "PADRTRIGGER", x = 364, y = 22 },
    { key = "PADLSHOULDER", x = 148, y = 56 }, { key = "PADRSHOULDER", x = 364, y = 56 },
    { key = "PADDUP", x = 128, y = 80, size = 28 }, { key = "PADDDOWN", x = 128, y = 140, size = 28 },
    { key = "PADDLEFT", x = 98, y = 110, size = 28 }, { key = "PADDRIGHT", x = 158, y = 110, size = 28 },
    { key = "PAD4", x = 384, y = 80, size = 28 }, { key = "PAD1", x = 384, y = 140, size = 28 },
    { key = "PAD3", x = 354, y = 110, size = 28 }, { key = "PAD2", x = 414, y = 110, size = 28 },
    { key = "PADLSTICK", x = 196, y = 158, size = 38 }, { key = "PADRSTICK", x = 316, y = 158, size = 38 },
    { key = "PADBACK", x = 256, y = 96, size = 40 },
    { key = "TOUCH:upleft", region = "upleft", x = 232, y = 84, size = 20 },
    { key = "TOUCH:upright", region = "upright", x = 280, y = 84, size = 20 },
    { key = "TOUCH:downleft", region = "downleft", x = 232, y = 108, size = 20 },
    { key = "TOUCH:downright", region = "downright", x = 280, y = 108, size = 20 },
    { key = "PADSOCIAL", x = 178, y = 74, size = 24 }, { key = "PADFORWARD", x = 334, y = 74, size = 24 },
}
local SPOT = {}
for _, s in ipairs(SPOTS) do SPOT[s.key] = s end

-- key: the button picked (or a touchpad corner), nil until one is found;
-- spec: the press on it; sel: the binding picked in the list
local P = { variant = {}, sel = 1 }
B.Editor = P

-- A touchpad (its corners) only on a PlayStation controller; elsewhere the
-- same button is View / Minus
local function HasTouchpad()
    return IF.PadStyle() == "Shapes"
end

local function Visible(s)
    if s.region then return HasTouchpad() end
    if s.key == "PADBACK" then return not HasTouchpad() end
    return true
end

local function Region()
    return P.key and SPOT[P.key].region
end

---------------------------------------------------------------------------
-- What is bound where, read once a drawing
---------------------------------------------------------------------------
local function Snapshot()
    local bySpec = {}
    for _, def in ipairs(B.All()) do
        for _, spec in ipairs(def.specs()) do
            bySpec[spec] = bySpec[spec] or {}
            table.insert(bySpec[spec], def)
        end
    end
    return bySpec
end

local function Clashes(defs, spec)
    for i = 1, #(defs or {}) do
        for j = i + 1, #defs do
            if B.Clash(defs[i], defs[j], spec) then return true end
        end
    end
    return false
end

local function NoneName(spec)
    local held, _, double = B.Parse(spec)
    if not held and not double then
        -- (no name for it: what it does depends on what has the focus)
        return "The game's own"
    end
    return "Nothing"
end


---------------------------------------------------------------------------
-- The list down the left: every binding by group, each with its press (its
-- glyphs), then the touchpad's corners
---------------------------------------------------------------------------
local function Glyphs(spec)
    local keys = spec and B.Glyphs(spec)
    if not keys then return "|cff6f6452none|r" end
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key == "+" and "+" or IF.GlyphText(key, 16)
    end
    local _, _, double = B.Parse(spec)
    return table.concat(parts, "") .. (double and " ×2" or "")
end

-- { label, def, spec } or { label, region } or { header }
local function Lines()
    local lines, group = {}, nil
    for _, def in ipairs(B.All()) do
        if def.id ~= "touch" then
            local name = def.kind == "action" and "Actions" or def.group
            if name ~= group then
                group = name
                lines[#lines + 1] = { header = name }
            end
            local spec = def.specs()[1]
            lines[#lines + 1] = { label = def.label .. "  " .. Glyphs(spec), def = def, spec = spec }
        end
    end
    if HasTouchpad() then
        lines[#lines + 1] = { header = "Touchpad" }
        for _, region in ipairs(touch.REGIONS) do
            local action = touch.GetSettings().regions[region]
            lines[#lines + 1] = { label = touch.REGION_LABELS[region] .. "  |cff9d917a"
                .. (touch.IsBound(action) and touch.ActionLabel(action) or "Empty") .. "|r", region = region }
        end
    end
    return lines
end

-- The line picked: its press on the drawing, its choices on the right
function P:Pick(i)
    local lines = Lines()
    local step = i < (self.sel or 1) and -1 or 1
    while lines[i] and lines[i].header do i = i + step end
    if not lines[i] then
        i = self.sel or 1
        while lines[i] and lines[i].header do i = i + 1 end
    end
    local line = lines[i]
    if not line then return end
    self.sel = i
    self.pickerFor = nil
    menu.Disarm()
    if line.region then
        self.key, self.spec = "TOUCH:" .. line.region, nil
    elseif line.spec then
        local _, pressed = B.Parse(line.spec)
        self.key, self.spec = pressed, line.spec
    else
        self.key, self.spec = nil, nil
    end
end

-- The list back on the binding a found press runs (if any)
function P:SyncList()
    local lines = Lines()
    local region = self.key and SPOT[self.key] and SPOT[self.key].region
    for i, line in ipairs(lines) do
        if (region and line.region == region) or (not region and line.spec and line.spec == self:Spec()) then
            self.sel = i
            return
        end
    end
end

function P:Line()
    return Lines()[self.sel or 1]
end

---------------------------------------------------------------------------
-- The picker: what the press picked can do
---------------------------------------------------------------------------
function P:Spec()
    return self.spec or self.key
end

-- Ours that can go on the press: the wheels (wheels = true), or the rest
-- (an action has its own lists: Spells, Items...)
local function Ours(spec, wheels)
    local defs = {}
    for _, def in ipairs(B.All()) do
        if def.kind ~= "action" and (def.group == "Wheels") == wheels and def.accepts(spec) then
            defs[#defs + 1] = def
        end
    end
    return defs
end

local function Entries(spec, wheels)
    local entries = { { action = "none", name = NoneName(spec), icon = TEX .. "ic_emote_no" } }
    local group, groups = nil, {}
    local defs = Ours(spec, wheels)
    for _, def in ipairs(defs) do groups[def.group] = true end
    local many = next(groups) and next(groups, next(groups)) ~= nil
    for _, def in ipairs(defs) do
        if many and def.group ~= group then
            group = def.group
            entries[#entries + 1] = { header = group }
        end
        local sub
        local here = B.Has(def, spec)
        if def.context == "bags" then sub = "bags open" end
        entries[#entries + 1] = { action = def.id, name = def.label, icon = def.icon, sub = sub, here = here,
            def = def }
    end
    return entries
end

-- What a press or a corner can run: as the wheels' picker (Spells, Items,
-- Macros, Emotes; a corner: no emotes), Interface (the game's windows), and
-- (with ours = true) Misc: our own windows (the minimap labels, the peek
-- map, this panel)
local function ActionLists(emotes, ours)
    local lists = {}
    for _, list in ipairs(IF.Actions.CATALOG) do
        if emotes or list.key ~= "emotes" then lists[#lists + 1] = list end
    end
    lists[#lists + 1] = { key = "interface", label = "Interface", entries = function() return touch.InterfaceEntries() end }
    if ours then
        lists[#lists + 1] = { key = "misc", label = "Misc", entries = function() return touch.InterfaceEntries(true) end }
    end
    return lists
end

-- The list an action is in (or fallback)
local function ListOf(lists, action, fallback)
    local kind = touch.IsBound(action) and (action:match("^(%a+):")
        or (IF.Actions.IsOurs(action) and "misc" or "interface"))
    for i, list in ipairs(lists) do
        if kind and (list.key == kind or list.key == kind .. "s") then return i end
    end
    return fallback or 1
end

function P:SyncPicker(force)
    -- Nothing picked: no list
    if not self.key then
        self.pickerFor = nil
        return self.picker:Close()
    end
    local want = Region() or self:Spec()
    if self.pickerFor == want and not force then return end
    self.pickerFor = want
    local region = Region()
    if region then
        local lists = ActionLists(false, true)
        self.picker:Open({
            lists = lists, list = self.variant[self.key] or ListOf(lists, touch.GetSettings().regions[region]),
            rows = PICKER_ROWS, chooseVerb = "Bind",
            current = function() return touch.GetSettings().regions[region] end,
            -- (only what this corner holds)
            marked = function(e) return e.action == touch.GetSettings().regions[region] end,
            status = function()
                local action = touch.GetSettings().regions[region]
                return touch.REGION_LABELS[region] .. ":  "
                    .. (touch.IsBound(action) and ("|cffffffff" .. touch.ActionLabel(action) .. "|r") or "Empty")
            end,
            onChoose = function(e) P:BindCorner(region, e) end,
        })
        return
    end
    -- A press: the wheels (where one can go on it), the addon's other
    -- things (Misc), then what it can run (where an action can go on it),
    -- on the list of what it does now
    local spec = self:Spec()
    local lists = {}
    if #Ours(spec, true) > 0 then
        lists[#lists + 1] = { key = "wheels", label = "Wheels", entries = function() return Entries(spec, true) end }
    end
    local fits = B.ActionFits(spec)
    if fits then
        for _, list in ipairs(ActionLists(true)) do lists[#lists + 1] = list end
    end
    -- Last, Misc: our other bindings that can go on it, and (where an action
    -- can) our windows not already among them
    lists[#lists + 1] = { key = "misc", label = "Misc", entries = function()
        local entries = Entries(spec, false)
        if fits then
            local named = {}
            for _, e in ipairs(entries) do if e.name then named[e.name] = true end end
            for _, e in ipairs(touch.InterfaceEntries(true)) do
                if not named[e.name] then entries[#entries + 1] = e end
            end
        end
        return entries
    end }
    local misc = #lists
    local start = misc
    local bound = B.Bound(spec)[1]
    if B.ActionOn(spec) then
        start = ListOf(lists, B.ActionOn(spec), misc)
    elseif bound and bound.group == "Wheels" then
        start = 1
    end
    self.picker:Open({
        lists = lists, list = start,
        rows = PICKER_ROWS, chooseVerb = "Bind",
        current = function(list)
            if list.key ~= "wheels" and list.key ~= "misc" then return B.ActionOn(spec) end
            if list.key == "misc" and B.ActionOn(spec) and IF.Actions.IsOurs(B.ActionOn(spec)) then
                return B.ActionOn(spec)
            end
            for _, def in ipairs(B.Bound(spec)) do
                if def.kind ~= "action" and (def.group == "Wheels") == (list.key == "wheels") then return def.id end
            end
            return "none"
        end,
        marked = function(e)
            if e.def or e.action == "none" then return e.here end
            return e.action == B.ActionOn(spec)
        end,
        -- The press, what it runs now
        status = function()
            local names = {}
            for _, def in ipairs(B.Bound(spec)) do names[#names + 1] = def.label end
            return B.Text(spec, 14) .. ":  " .. (#names > 0 and ("|cffffffff" .. table.concat(names, ", ") .. "|r")
                or NoneName(spec))
        end,
        onChoose = function(e)
            if e.def or e.action == "none" then P:Choose(e) else P:ChooseAction(spec, e) end
        end,
    })
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function NewSpot(parent, s)
    local size = s.size or 30
    local b = K.NewFrame("Button", nil, parent)
    b:SetSize(size + 8, size + 8)
    b:SetPoint("CENTER", parent, "TOPLEFT", s.x, -s.y)
    b:RegisterForClicks("LeftButtonUp")
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(TEX .. "ic_slot_glow")
    b.glow:SetBlendMode("ADD")
    b.glow:SetSize(size * 2, size * 2)
    b.glow:SetPoint("CENTER")
    b.ring = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.ring:SetTexture(TEX .. "ic_ring_dash")
    b.ring:SetSize(size + 12, size + 12)
    b.ring:SetPoint("CENTER")
    if s.region then
        -- A corner: what it runs, or a "+"
        b.icon = K.RoundIcon(b, size, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b.plus = K.Text(b, 14, KC.dimGold, "OVERLAY")
        b.plus:SetPoint("CENTER", 0, 1)
        b.plus:SetText("+")
    else
        b.glyph = K.Glyph(b, size)
        b.glyph:SetPoint("CENTER")
    end
    b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.dot:SetTexture(TEX .. "ic_dot")
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("CENTER", b, "TOPRIGHT", -4, -4)
    -- (the mouse may pick one; the pad finds it by pressing it)
    b:SetScript("OnClick", function()
        P.key, P.spec = s.key, not s.region and s.key or nil
        menu.Render()
    end)
    return b
end

function P:Build(parent)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- Left: the bindings
    f.side = UI.SideList(f, SIDE_W, 17, function(i)
        P:Pick(i)
        menu.Render()
    end)
    f.side:SetPoint("TOPLEFT", 8, -8)
    f.side:SetPoint("BOTTOMLEFT", 8, 8)

    -- Beside it: the controller and its buttons, what the press can do
    -- under them
    f.mid = K.NewFrame("Frame", nil, f)
    f.mid:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 10, 0)
    f.mid:SetPoint("BOTTOMRIGHT", -8, 8)
    local art = K.NewFrame("Frame", nil, f.mid)
    art:SetSize(ART_W, ART_H)
    art:SetScale(SCALE)
    -- (a scaled frame's offsets are in its own units)
    art:SetPoint("TOP", f.mid, "TOP", 0, -6 / SCALE)
    art.tex = art:CreateTexture(nil, "BACKGROUND")
    art.tex:SetTexture(TEX .. "ic_controller")
    art.tex:SetAllPoints()
    f.art = art
    f.spots = {}
    for _, s in ipairs(SPOTS) do f.spots[s.key] = NewSpot(art, s) end

    -- (its lists in a bar along its top, as the auction window's
    -- categories; their choices as its item cards, two a row)
    self.picker = UI.CardPicker(f.mid, 2, 46, menu.Render, "LS")
    self.picker:SetPoint("TOPLEFT", f.mid, "TOPLEFT", 0, -(ART_H * SCALE + 14))
    self.picker:SetPoint("BOTTOMRIGHT", f.mid, "BOTTOMRIGHT", 0, 0)
end

function P:Show()
    self.pickerFor = nil
    if not self.key then self:Pick(self.sel or 1) end
    self.frame:Show()
end

-- The left stick (Menu.lua): up / down the bindings, left / right the
-- choices' lists
function P:StickStep(dir)
    self:Pick((self.sel or 1) + dir)
end

function P:StickSide(dir)
    if self.key and self.picker.def then self.picker:Press(dir < 0 and "LT" or "RT") end
end

function P:Hide()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Binding
---------------------------------------------------------------------------
-- After a change: the list back on what the press does now
local function Done(text, warn)
    P:SyncList()
    menu.Toast(text, warn)
    P.picker:LoadList()
    menu.Render()
end

function P:Choose(e)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local spec = self:Spec()
    local text = B.Text(spec)
    if e.action == "none" then
        local bound = B.Bound(spec)
        if #bound == 0 then return menu.Toast(text .. ": nothing of ours on it") end
        local armId = "clear:" .. spec
        if not menu.IsArmed(armId) then
            menu.Arm(armId)
            return menu.Toast(IF.PadText("Unbind " .. B.Names(bound) .. " from " .. text .. "? {A} again"), true, 4)
        end
        menu.Disarm()
        B.Clear(spec)
        return Done(text .. ": " .. NoneName(spec):lower())
    end
    local def = B.Get(e.action)
    if not def then return end
    if B.Has(def, spec) then return menu.Toast(def.label .. " is on " .. text .. " already") end
    -- Taking it from something else asks first: Cross again
    local gone = B.Conflicts(def.id, spec)
    local armId = "bind:" .. def.id .. "@" .. spec
    if #gone > 0 and not menu.IsArmed(armId) then
        menu.Arm(armId)
        return menu.Toast(IF.PadText(text .. " runs " .. B.Names(gone) .. ": {A} again replaces it"), true, 4)
    end
    menu.Disarm()
    local from = def.specs()[1]
    B.Assign(def.id, spec)
    Done(def.label .. ": " .. text .. (from and (" (was " .. B.Text(from) .. ")") or "")
        .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or ""), #gone > 0)
end

-- A spell, item, macro, emote or window onto the press (a crossbar
-- press: in its slot, Native.lua; else Override.lua); taking it from
-- something else asks first: Cross again
function P:ChooseAction(spec, e)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local O = IF.Override
    local text = B.Text(spec)
    if B.ActionOn(spec) == e.action then return menu.Toast((e.name or "") .. " is on " .. text .. " already") end
    local id = "action:" .. spec
    local gone = B.Conflicts(id, spec)
    local armId = "act:" .. spec .. "@" .. e.action
    if #gone > 0 and not menu.IsArmed(armId) then
        menu.Arm(armId)
        return menu.Toast(IF.PadText(text .. " runs " .. B.Names(gone) .. ": {A} again replaces it"), true, 4)
    end
    menu.Disarm()
    B.Take(id, spec)
    if B.SetAction(spec, e.action, e.name, type(e.icon) == "number" and e.icon or nil) == false then
        return Done(text .. ": couldn't put " .. (e.name or "it") .. " there", true)
    end
    local held, pressed = B.Parse(spec)
    Done(text .. ": " .. (e.name or "") .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or "")
        .. (O.OutOfCombatOnly(spec) and " (out of combat only: " .. B.Text(B.Spec(held, pressed)) .. " stays the game's)" or ""),
        #gone > 0 or O.OutOfCombatOnly(spec))
end

-- Square: find a press by making it (Recorder.lua). The touchpad: the
-- corner under the finger.
function P:Find()
    if IF.InCombat() then return end
    IF.Recorder.Start({
        title = "Find a press", chord = true, double = true,
        hint = "Press the button, hold one and press another, or press one twice.",
        onDone = function(spec, info)
            local _, pressed = B.Parse(spec)
            if pressed == "PADBACK" and HasTouchpad() then
                local region = info and info.touch and touch.RegionAt(info.touch[1], info.touch[2])
                if not (region and SPOT["TOUCH:" .. region]) then
                    return menu.Toast("Click the touchpad in the corner you want", true)
                end
                P.key, P.spec = "TOUCH:" .. region, nil
                P:SyncList()
                return
            end
            if not (SPOT[pressed] and Visible(SPOT[pressed])) then
                return menu.Toast(B.Text(spec) .. " isn't on the drawing", true)
            end
            P.key, P.spec = pressed, spec
            P:SyncList()
        end,
    })
end

-- Square on a binding on no press: a press recorded for it
function P:Record(def)
    if IF.InCombat() then return end
    IF.Recorder.Start({
        title = "Bind " .. def.label, chord = true, double = true,
        accept = def.accepts, reject = def.label .. " can't go on that press",
        onDone = function(spec)
            local _, pressed = B.Parse(spec)
            P.key, P.spec = pressed, spec
            P.pickerFor = nil
            P:Choose({ action = def.id })
            P:SyncList()
        end,
    })
end

function P:BindCorner(region, e)
    -- (the touchpad click turned off: binding a corner turns it on)
    touch.GetSettings().enabled = true
    touch.SetAction(region, e.action)
    Done(touch.REGION_LABELS[region] .. ": " .. (e.name or ""))
end

-- Triangle on a corner: a press clears it, held (0.6 s) turns it off / on;
-- a rumble rises once it is clearly a hold, a thump when it acts
-- (Vibration.lua, when loaded)
local HOLD, FEEL_AFTER = 0.6, 0.15

function P:CornerTriangle(region)
    if self.holding then return end
    local started = GetTime()
    self.holding = region
    self.holdTicker = C_Timer.NewTicker(0.05, function(ticker)
        local held = IsKeyDown and IsKeyDown("PAD4")
        local elapsed = GetTime() - started
        if held and elapsed >= HOLD then
            ticker:Cancel()
            P.holding = nil
            if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
            local off = touch.ToggleOff(region)
            Done(touch.REGION_LABELS[region] .. (off and " turned off" or " turned on")
                .. (off and touch.CORNERS[region] and " (its sides take its area)" or ""))
        elseif not held then
            ticker:Cancel()
            P.holding = nil
            if IF.Vibe and elapsed >= FEEL_AFTER then IF.Vibe.Hold(nil) end
            if touch.IsBound(touch.GetSettings().regions[region]) then
                touch.SetAction(region, "none")
                Done(touch.REGION_LABELS[region] .. " cleared")
            end
        elseif elapsed >= FEEL_AFTER and IF.Vibe then
            IF.Vibe.Hold(elapsed / HOLD)
        end
    end)
end

---------------------------------------------------------------------------
-- The pad: the picker; Square finds another press
---------------------------------------------------------------------------
function P:Press(name)
    -- (L1 / R1 the tabs, Circle closes: the panel's)
    if name == "LB" or name == "RB" or name == "B" then return false end
    local line = self:Line()
    if name == "X" then
        -- (a binding on no press: record one for it; else find a press)
        if line and line.def and not line.spec and not self.key then self:Record(line.def) else self:Find() end
        return true
    end
    if not self.key then return true end
    if name == "Y" then
        if Region() then
            self:CornerTriangle(Region())
        else
            self:Choose({ action = "none" })
        end
        return true
    end
    self.picker:Press(name)
    menu.Render()
    return true
end

function P:Help()
    local H = K.H
    local hints = { H({ "LS" }, "Binding / List") }
    local line = self:Line()
    if self.key then
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Bind", "A")
        hints[#hints + 1] = H({ "Y" }, Region() and ("Clear / Hold to " .. (touch.IsOff(Region()) and "Turn On" or "Turn Off")) or "Unbind", "Y")
    end
    if line and line.def and not line.spec and not self.key then
        hints[#hints + 1] = H({ "X" }, "Record press", "X")
    else
        hints[#hints + 1] = H({ "X" }, "Find press", "X")
    end
    hints[#hints + 1] = H({ "RS" }, "Tab")
    hints[#hints + 1] = H({ "B" }, "Close", "B")
    return hints
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Tint(t, c, a)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
end

-- The touchpad's corners: what each runs, the one picked lit
local function RenderCorners(f)
    local settings = touch.GetSettings()
    local on = settings.enabled ~= false
    for _, s in ipairs(SPOTS) do
        local b, region = f.spots[s.key], s.region
        if region then
            local action = settings.regions[region]
            local bound, off = touch.IsBound(action), touch.IsOff(region)
            if bound then K.SetIcon(b.icon, touch.ActionIcon(action) or 134400) end
            b.icon:SetShown(bound)
            b.icon:SetDesaturated(off or not on)
            b.plus:SetShown(not bound and not off)
            local picked = s.key == P.key
            b.glow:SetShown(picked)
            Tint(b.glow, KC.focus, 0.9)
            b.ring:SetShown(picked)
            Tint(b.ring, KC.focus)
            b.dot:SetShown(off)
            Tint(b.dot, KC.danger)
            b:SetAlpha((off or not on) and 0.45 or 1)
        end
    end
end

function P:Render()
    local f = self.frame
    if not f then return end
    -- Another controller in hand: the touchpad's corners / its View button
    if self.key and not Visible(SPOT[self.key]) then
        if Region() then
            self.key, self.spec = "PADBACK", "PADBACK"
        else
            self.key, self.spec = "TOUCH:upleft", nil
        end
    end
    self:SyncPicker()
    if Region() then self.variant[self.key] = self.picker.list end
    -- The bindings down the left
    local lines = Lines()
    if (self.sel or 1) > #lines then self.sel = 1 end
    local entries = {}
    for i, line in ipairs(lines) do
        entries[i] = line.header and { header = line.header } or { label = line.label }
    end
    f.side:Render(IF.GlyphText("LS", 18) .. " Bindings", entries, self.sel or 1, true)
    local spec = self:Spec()
    local bySpec = Snapshot()
    local held = B.Parse(spec)
    local region = Region()

    -- The buttons: the one picked lit, marks for what is on each
    for _, s in ipairs(SPOTS) do
        local key, b = s.key, f.spots[s.key]
        b:SetShown(Visible(s))
        if not s.region and b:IsShown() then
            b.glyph:Set(IF.PAD_KEY[key] or key)
            local any, clash = false, false
            local list = { key, key .. ":double" }
            for _, h in ipairs(B.HOLDS) do list[#list + 1] = h .. "+" .. key end
            for _, sp in ipairs(list) do
                local defs = bySpec[sp]
                if defs then
                    any = true
                    clash = clash or Clashes(defs, sp)
                end
            end
            local picked = key == self.key
            b.glow:SetShown(picked)
            Tint(b.glow, KC.focus, 0.9)
            local ring = picked or (not region and key == held)
            b.ring:SetShown(ring and true or false)
            if picked then
                Tint(b.ring, KC.focus)
            elseif key == held then
                Tint(b.ring, KC.dimGold, 0.8)
            else
                Tint(b.ring, KC.info)
            end
            b.dot:SetShown(any)
            Tint(b.dot, clash and KC.danger or KC.slot)
            b.glyph:SetAlpha((picked or any) and 1 or 0.7)
        end
    end
    if HasTouchpad() then RenderCorners(f) end

    if self.key then
        self.picker:Show()
        self.picker:Render()
    end
end

---------------------------------------------------------------------------
-- The Controller tab, the first
---------------------------------------------------------------------------
menu.AddTab({ key = "controller", label = "Controller", module = "controller", order = 10, page = P })

-- The panel kept the touchpad click while it was open; give it back
hooksecurefunc(menu, "Close", function()
    -- Next time: the list's binding again
    P.key, P.spec = nil, nil
    if not IF.InCombat() then touch.Apply() end
end)
