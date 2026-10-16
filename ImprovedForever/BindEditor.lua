-- The Bindings tab: down the left what can be bound, in lists (L1 / R1,
-- L2 / R2 too): the wheels, the addon's other things (Misc), spells,
-- items, macros, emotes and the game's windows, a card each with its press;
-- beside it a drawing of the controller (each button marked when something
-- of ours is on it, red when two things clash there), the press of the
-- card picked lit. A card on no press: the drawing dimmed, Square over it.
-- Square (Cross too) binds the card picked: a box asks for the press
-- (Recorder.lua: a button, one held and another pressed, or one pressed
-- twice) and it goes there, moved from its press before; taking a press
-- from something else asks first (Cross again). Triangle unbinds it.
-- On a PlayStation controller the touchpad shows its four corners: an
-- action bound by clicking the pad goes on the corner under the finger
-- (Touchpad.lua). Triangle on an action on a corner clears it, held turns
-- the corner off.
-- The other tabs still bind their own things, through Binds.lua, so they
-- warn the same way.
-- Each card also has a keyboard / mouse press (Binds.lua: a key, or a
-- modified click on an item; an action's: a key, Override.lua): recording
-- takes a key or a click as well as a controller press, and it goes on the
-- press of the input used. A click on a card records, a right-click clears
-- its keyboard / mouse press (else its controller one). The game's Gamepad
-- UI off: no drawing, the list alone, only what takes a key, its key on the
-- right.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C
local menu = IF.Menu
local B = IF.Binds
local touch = IF.Touch

local UI = IF.UI

local TEX = "Interface\\AddOns\\ImprovedForever\\textures\\"
local LIST_W = 310

-- The drawing (tools/make_controller.py), the press picked over it
-- (PRESS_H), what runs on that press under it: the three one block in the
-- middle of the column, the drawing as big as the column lets it (its
-- controller DRAWN_W of its width, the rest see-through; ART_PAD clear on
-- each side; up to MAX_SCALE)
local ART_W, ART_H, DRAWN_W, MAX_SCALE = 512, 256, 400, 1.8
local PRESS_H, RUNS_H, MSG_H, ART_PAD = 20, 22, 20, 48
local ART_TOP = PRESS_H + 6

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

-- key: the button of the card picked's press (or a touchpad corner), nil
-- when it is on none; spec: that press; selAction: the card picked (its
-- action, a binding's id); list: its list; popup: a confirmation up
-- ({ onAccept })
local P = { list = 1 }
B.Editor = P
-- (its messages under the drawing, not over the legend: Menu.lua; keys
-- alone, no legend: P:Arrange)
P.ShowsToast = true

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


---------------------------------------------------------------------------
-- Presses: a spec, or a touchpad corner ("TOUCH:upleft")
---------------------------------------------------------------------------
local function CornerOf(press)
    return press and press:match("^TOUCH:(%a+)$")
end

-- "L1 + R3" (with glyphs at size), a corner: the touchpad's, and which
local function PressText(press, size)
    local region = CornerOf(press)
    if region then
        return B.Text("PADBACK", size) .. "  |cff9d917a·|r  " .. touch.REGION_LABELS[region]
    end
    return B.Text(press, size)
end

-- Every action on a press: action -> { press... } (a crossbar slot or an
-- override binding, Binds.lua; a touchpad corner)
local function ActionPresses()
    local map = {}
    local function add(action, press)
        map[action] = map[action] or {}
        table.insert(map[action], press)
    end
    for _, def in ipairs(B.All()) do
        if def.kind == "action" then
            local spec = def.specs()[1]
            local action = spec and B.ActionOn(spec)
            if action then add(action, spec) end
        end
    end
    if HasTouchpad() then
        for _, region in ipairs(touch.REGIONS) do
            local action = touch.GetSettings().regions[region]
            if touch.IsBound(action) then add(action, "TOUCH:" .. region) end
        end
    end
    return map
end

-- A card's presses: a binding's own, an action's where it is
local function PressesOf(e, map)
    if not e then return {} end
    if e.def then
        -- (a binding that can go on a touchpad corner too, def.corner: the corner is its press)
        if not (e.def.corner and HasTouchpad()) then return e.def.specs() end
        local list = {}
        for _, spec in ipairs(e.def.specs()) do list[#list + 1] = spec end
        for _, press in ipairs((map or ActionPresses())[e.def.id] or {}) do list[#list + 1] = press end
        return list
    end
    return (map or ActionPresses())[e.action] or {}
end

-- A card's keyboard / mouse press: a binding's, an action's key; or nil
local function KeyOf(e)
    if not e then return nil end
    if e.def then return B.KeyBind(e.def) end
    for key, action in pairs(IF.Override.KeySettings()) do
        if action == e.action then return key end
    end
end

-- Does a card take one at all (a binding with a run, a button or a click;
-- any action)
local function TakesKey(e)
    if not e then return false end
    if e.def then return B.TakesKey(e.def) end
    return e.action ~= nil
end

local function Mouse()
    return not IF.Input.Pad()
end

-- The game's Gamepad UI off: no controller presses, the keyboard's alone
local function KeysOnly()
    return not IF.Input.PadEnabled()
end

---------------------------------------------------------------------------
-- The lists: what can be bound, a card each: what it does under its name,
-- its press on its right (bound: the card washed)
---------------------------------------------------------------------------
-- Ours: the wheels (wheels = true), or the rest (not the actions on
-- presses: they are in the lists they come from; not the touchpad click)
local function Ours(wheels)
    local entries = {}
    for _, def in ipairs(B.All()) do
        if def.kind ~= "action" and def.id ~= "touch" and (def.group == "Wheels") == wheels then
            -- (a wheel: its name, the list says it's one)
            local name = wheels and def.label:gsub(" wheel$", "") or def.label
            entries[#entries + 1] = { action = def.id, name = name, icon = def.icon, sub = def.desc, def = def }
        end
    end
    return entries
end

-- Each card's presses
local function WithPresses(entries)
    local map = ActionPresses()
    for _, e in ipairs(entries) do
        local press = not e.header and PressesOf(e, map)[1]
        if press then e.press = PressText(press, 14) end
        local key = not e.header and KeyOf(e)
        e.key = key and B.KeyText(key) or nil
        e.takesKey = TakesKey(e)
    end
    return entries
end

local function Lists()
    local lists = {}
    -- (keys only: the cards that take one)
    local function add(key, label, fn)
        lists[#lists + 1] = { key = key, label = label, entries = function()
            local entries = WithPresses(fn())
            if not KeysOnly() then return entries end
            local list = {}
            for _, e in ipairs(entries) do
                if e.header or e.takesKey then list[#list + 1] = e end
            end
            return list
        end }
    end
    if #Ours(true) > 0 and not KeysOnly() then add("wheels", "Wheels", function() return Ours(true) end) end
    for _, list in ipairs(IF.Actions.CATALOG) do add(list.key, list.label, list.entries) end
    add("interface", "Interface", function() return touch.InterfaceEntries() end)
    -- Last, Misc: our other bindings, then our windows (Reload too) not
    -- already among them
    add("misc", "Misc", function()
        local entries, named = Ours(false), {}
        for _, e in ipairs(entries) do named[e.name] = true end
        for _, e in ipairs(touch.InterfaceEntries(true)) do
            if not named[e.name] then entries[#entries + 1] = e end
        end
        return entries
    end)
    return lists
end

-- The card picked
function P:Entry()
    local p = self.picker
    return p and p.def and p.entries and p.index and p.entries[p.index]
end

function P:OpenPicker()
    local lists = Lists()
    self.picker:Open({
        lists = lists, list = math.min(self.list, #lists),
        chooseVerb = "Bind",
        -- (the card picked kept through a change)
        current = function() return P.selAction end,
        -- (the Gamepad UI off: its keyboard / mouse press)
        right = function(e)
            if not P.arranged then return e.press end
            return e.key or "|cff6f6452—|r"
        end,
        bound = function(e) return e.press ~= nil or e.key ~= nil end,
        status = function()
            local e = P:Entry()
            if not e then return "" end
            local press = PressesOf(e)[1]
            local key = KeyOf(e)
            if KeysOnly() then return "|cffffffff" .. (e.name or "") .. "|r:  " .. (key and B.KeyText(key) or "no key") end
            return "|cffffffff" .. (e.name or "") .. "|r:  " .. (press and PressText(press, 14) or "no controller press")
                .. (TakesKey(e) and ("  ·  " .. (key and B.KeyText(key) or "no key")) or "")
        end,
        -- (a card picked binds it only with keys alone: with the Gamepad UI
        -- Square does, a pick only picks)
        onChoose = function() if KeysOnly() then P:Bind() end end,
        onAlt = function() P:Unbind((Mouse() or KeysOnly()) and "key") end,
    })
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function NewSpot(parent, s)
    local size = s.size or 30
    local b = K.NewFrame("Frame", nil, parent)
    b:SetSize(size + 8, size + 8)
    b:SetPoint("CENTER", parent, "TOPLEFT", s.x, -s.y)
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
    return b
end

function P:Build(parent)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- Left: what can be bound (its lists in a bar along its top, as the
    -- auction window's categories; a card each, one a row)
    self.picker = UI.CardPicker(f, 1, 46, menu.Render, "LB", "RB")
    self.picker:SetPoint("TOPLEFT", 8, -8)
    self.picker:SetPoint("BOTTOMLEFT", 8, 8)
    self.picker:SetWidth(LIST_W)

    -- Beside it: the press of the card picked, the controller and its
    -- buttons, what runs on that press
    f.mid = K.NewFrame("Frame", nil, f)
    f.mid:SetPoint("TOPLEFT", self.picker, "TOPRIGHT", 10, 0)
    f.mid:SetPoint("BOTTOMRIGHT", -8, 8)
    local group = K.NewFrame("Frame", nil, f.mid)
    group:SetPoint("LEFT")
    group:SetPoint("RIGHT")
    f.group = group
    f.press = K.Text(group, 14, KC.cream)
    f.press:SetPoint("TOP", group, "TOP", 0, -4)
    f.press:SetHeight(PRESS_H)
    f.press:SetJustifyH("CENTER")
    local art = K.NewFrame("Frame", nil, group)
    art:SetSize(ART_W, ART_H)
    art.tex = art:CreateTexture(nil, "BACKGROUND")
    art.tex:SetTexture(TEX .. "ic_controller")
    art.tex:SetAllPoints()
    f.art = art
    f.spots = {}
    for _, s in ipairs(SPOTS) do f.spots[s.key] = NewSpot(art, s) end
    f.runs = K.ChatText(group, 12, KC.help)
    f.runs:SetJustifyH("CENTER")
    -- Under it, the panel's messages (ShowsToast: not over the legend)
    f.msg = K.ChatText(group, 13, KC.grey)
    f.msg:SetPoint("TOP", f.runs, "BOTTOM", 0, -6)
    f.msg:SetJustifyH("CENTER")

    -- Over the drawing, a card on no press: Square to start binding it
    local over = K.NewFrame("Frame", nil, group)
    over:SetSize(400, 66)
    over:SetFrameLevel(art:GetFrameLevel() + 20)
    over.box = K.Box(over, 4, 1, "BACKGROUND")
    over.box:SetColors(KC.boxBg, 0.92, KC.info, 0.6)
    over.title = K.Text(over, 16, KC.cream)
    over.title:SetPoint("CENTER", 0, 10)
    over.title:SetJustifyH("CENTER")
    over.sub = K.ChatText(over, 12, KC.help)
    over.sub:SetPoint("CENTER", 0, -14)
    over.sub:SetJustifyH("CENTER")
    over:Hide()
    f.over = over

    -- The confirmation box (P:Confirm), over the page: the panel's own
    -- window look (its title in its bar, its focus glow: it has the pad),
    -- above the panel (FULLSCREEN_DIALOG) and its tabs
    local d = UI.Window(nil, 440, 150, true)
    d:SetFrameStrata("TOOLTIP")
    d:SetPoint("CENTER", f, "CENTER", 0, 0)
    d:SetTitle("Replace binding?")
    IF.Focus.Glow(d, true)
    d.text = K.Text(d, 15, KC.cream)
    d.text:SetJustifyH("CENTER")
    d.text:SetWordWrap(true)
    d.text:SetPoint("TOP", d, "TOP", 0, -40)
    d.text:SetWidth(390)
    d.text:SetSpacing(4)
    d.hintRow = K.NewFrame("Frame", nil, d)
    d.hintRow:SetSize(1, 30)
    d.hintRow:SetPoint("BOTTOM", d, "BOTTOM", 0, 22)
    d.hints = {}
    for i = 1, 2 do
        d.hints[i] = K.Hint(d.hintRow, function(press) P:Press(press) end)
    end
    d:Hide()
    self.dialog = d
    f.mid:SetScript("OnSizeChanged", function() P:Layout() end)
    self:Layout()
end

-- The drawing as big as the column lets it, the block placed for it
function P:Layout()
    local f = self.frame
    local w, h = f.mid:GetSize()
    if not w or w <= 0 then return end
    local scale = math.min(MAX_SCALE, (w - 2 * ART_PAD) / DRAWN_W, (h - ART_TOP - 8 - RUNS_H - MSG_H) / ART_H)
    local artH = ART_H * scale
    f.group:SetHeight(ART_TOP + artH + 8 + RUNS_H + MSG_H)
    f.art:SetScale(scale)
    -- (a scaled frame's offsets are in its own units)
    f.art:ClearAllPoints()
    f.art:SetPoint("TOP", f.group, "TOP", 0, -ART_TOP / scale)
    f.runs:ClearAllPoints()
    f.runs:SetPoint("TOP", f.group, "TOP", 0, -(ART_TOP + artH + 8))
    f.over:ClearAllPoints()
    f.over:SetPoint("CENTER", f.group, "TOP", 0, -(ART_TOP + artH / 2))
end

function P:Show()
    self:OpenPicker()
    self:Layout()
    self.frame:Show()
end

-- The left stick (Menu.lua): up / down the cards
function P:StickStep(dir)
    self.picker:Press(dir < 0 and "UP" or "DOWN")
end

function P:Hide()
    -- (an open confirmation is a no)
    if self.popup then self:AnswerPopup(false) end
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Binding
---------------------------------------------------------------------------
-- After a change: the cards' presses again
local function Done(text, warn)
    menu.Toast(text, warn)
    P.picker:LoadList()
    menu.Render()
end

-- Taking a press from something else asks first: a box over the page (the
-- game's dialog look), Cross replaces, Circle backs out
function P:Confirm(text, onAccept)
    if IF.InCombat() then return end
    self.popup = { onAccept = onAccept }
    local d = self.dialog
    d.text:SetText(text)
    local x = 0
    for i, hint in ipairs({ K.H({ "A" }, "Replace", "A"), K.H({ "B" }, "Cancel", "B") }) do
        local h = d.hints[i]
        h:Set(hint)
        h:ClearAllPoints()
        h:SetPoint("LEFT", d.hintRow, "LEFT", x, 0)
        x = x + h:GetWidth() + 28
    end
    d.hintRow:SetWidth(math.max(1, x - 28))
    d:SetHeight(math.max(150, d.text:GetStringHeight() + 112))
    d:Show()
    menu.Render()
end

function P:AnswerPopup(accepted)
    local popup = self.popup
    self.popup = nil
    self.dialog:Hide()
    if popup and accepted then popup.onAccept() end
    menu.Render()
end

-- "L2 + Cross runs Journal.\nReplace it with Reload?"
local function ReplaceText(spec, names, name)
    return B.Text(spec, 16) .. " runs |cffffffff" .. names .. "|r.\nReplace it with |cffffffff" .. (name or "") .. "|r?"
end

-- Takes an action off every press it is on but keep (a spec or a corner)
local function TakeOff(action, keep)
    for _, press in ipairs(ActionPresses()[action] or {}) do
        if press ~= keep then
            local region = CornerOf(press)
            if region then touch.SetAction(region, "none") else B.SetAction(press, nil) end
        end
    end
end

-- One of ours onto a press (moved from where it was)
function P:BindDef(def, spec, confirmed)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local text = B.Text(spec)
    if B.Has(def, spec) then return menu.Toast(def.label .. " is on " .. text .. " already") end
    local gone = B.Conflicts(def.id, spec)
    if #gone > 0 and not confirmed then
        return self:Confirm(ReplaceText(spec, B.Names(gone), def.label), function() P:BindDef(def, spec, true) end)
    end
    local from = def.specs()[1]
    B.Assign(def.id, spec)
    Done(def.label .. ": " .. text .. (from and (" (was " .. B.Text(from) .. ")") or "")
        .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or ""), #gone > 0)
end

-- A spell, item, macro, emote or window onto a press (a crossbar press: in
-- its slot, Native.lua; else Override.lua), moved from where it was
function P:BindAction(e, spec, confirmed)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local O = IF.Override
    local text = B.Text(spec)
    local there = B.ActionOn(spec)
    if there == e.action then return menu.Toast((e.name or "") .. " is on " .. text .. " already") end
    local id = "action:" .. spec
    local gone = B.Conflicts(id, spec)
    -- (what is there: ours that clash, and the action on it, the game's
    -- crossbar slot's too)
    local names = {}
    for _, def in ipairs(gone) do names[#names + 1] = def.label end
    if there then names[#names + 1] = O.ActionLabel(there) or there end
    if #names > 0 and not confirmed then
        return self:Confirm(ReplaceText(spec, table.concat(names, ", "), e.name), function() P:BindAction(e, spec, true) end)
    end
    local from = ActionPresses()[e.action]
    B.Take(id, spec)
    if B.SetAction(spec, e.action, e.name, e.icon) == false then
        return Done(text .. ": couldn't put " .. (e.name or "it") .. " there", true)
    end
    TakeOff(e.action, spec)
    local held, pressed = B.Parse(spec)
    Done((e.name or "") .. ": " .. text .. (from and (" (was " .. PressText(from[1]) .. ")") or "")
        .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or "")
        .. (O.OutOfCombatOnly(spec) and " (out of combat only: " .. B.Text(B.Spec(held, pressed)) .. " stays the game's)" or ""),
        #gone > 0 or O.OutOfCombatOnly(spec))
end

-- An action onto a touchpad corner (the corner turned on), moved from
-- where it was
function P:BindCorner(region, e, confirmed)
    local from = touch.GetSettings().regions[region]
    if from == e.action then return menu.Toast((e.name or "") .. " is on " .. PressText("TOUCH:" .. region) .. " already") end
    if touch.IsBound(from) and not confirmed then
        return self:Confirm(PressText("TOUCH:" .. region, 16) .. " runs |cffffffff" .. touch.ActionLabel(from)
            .. "|r.\nReplace it with |cffffffff" .. (e.name or "") .. "|r?", function() P:BindCorner(region, e, true) end)
    end
    touch.GetSettings().enabled = true
    touch.SetAction(region, e.action)
    TakeOff(e.action, "TOUCH:" .. region)
    Done((e.name or "") .. ": " .. PressText("TOUCH:" .. region)
        .. (touch.IsBound(from) and from ~= e.action and (", " .. touch.ActionLabel(from) .. " off it") or ""))
end

-- Square (Cross too): the card picked onto a press made now (Recorder.lua).
-- An action clicked on the touchpad: the corner under the finger.
function P:Bind()
    local e = self:Entry()
    if not e or IF.InCombat() then return end
    local def = e.def
    IF.Recorder.Start({
        title = "Bind " .. (e.name or ""), chord = true, double = true,
        -- (a key, a click on an item: its keyboard / mouse press)
        keys = TakesKey(e), clicks = def ~= nil and def.click ~= nil,
        acceptKey = function(spec)
            if def then return B.KeyFits(def, spec) end
            if B.IsClick(spec) then return false, (e.name or "It") .. " takes a key, not a click" end
            if spec == "ESCAPE" then return false, "Escape is the game's" end
            return true
        end,
        onKey = function(spec) P:BindKey(e, spec) end,
        accept = function(spec)
            if def then
                -- (the touchpad's click: the corner under the finger, for one that takes a corner)
                if def.corner and spec == "PADBACK" and HasTouchpad() then return true end
                return def.accepts(spec)
            end
            local _, pressed = B.Parse(spec)
            return (pressed == "PADBACK" and HasTouchpad()) or B.ActionFits(spec)
        end,
        reject = function(spec) return B.GameOwns(spec) or ((e.name or "It") .. " can't go on that press") end,
        onDone = function(spec, info)
            local _, pressed = B.Parse(spec)
            if def and not (def.corner and pressed == "PADBACK" and HasTouchpad()) then return P:BindDef(def, spec) end
            if pressed == "PADBACK" and HasTouchpad() then
                local region = info and info.touch and touch.RegionAt(info.touch[1], info.touch[2])
                if not region then return menu.Toast("Click the touchpad in the corner you want", true) end
                return P:BindCorner(region, e)
            end
            P:BindAction(e, spec)
        end,
    })
end

-- A card onto a key / a click (moved from where it was; taking it from
-- another asks first)
function P:BindKey(e, spec, confirmed)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local O = IF.Override
    local text = B.KeyText(spec)
    if KeyOf(e) == spec then return menu.Toast((e.name or "") .. " is on " .. text .. " already") end
    local names = {}
    for _, def in ipairs(B.KeyBound(spec)) do
        if not (e.def and def.id == e.def.id) then names[#names + 1] = def.label end
    end
    local there = not B.IsClick(spec) and O.KeyAction(spec)
    if there and there ~= e.action then names[#names + 1] = O.ActionLabel(there) or there end
    if #names > 0 and not confirmed then
        return self:Confirm(text .. " runs |cffffffff" .. table.concat(names, ", ") .. "|r.\nReplace it with |cffffffff"
            .. (e.name or "") .. "|r?", function() P:BindKey(e, spec, true) end)
    end
    local from = KeyOf(e)
    if e.def then
        B.SetKey(e.def.id, spec)
    else
        if from then O.SetKey(from, nil) end
        O.SetKey(spec, e.action)
    end
    -- (the game's own binding there gives way while ours is on it)
    local game = not B.IsClick(spec) and GetBindingAction and GetBindingAction(spec)
    local over = game and game ~= "" and (_G["BINDING_NAME_" .. game] or game)
    Done((e.name or "") .. ": " .. text .. (from and (" (was " .. B.KeyText(from) .. ")") or "")
        .. (#names > 0 and (", " .. table.concat(names, ", ") .. " unbound") or "")
        .. (over and (" (over the game's " .. over .. ")") or ""), #names > 0)
end

-- Triangle: the card picked off its presses; which "key": off its
-- keyboard / mouse press (none: off its controller one)
function P:Unbind(which)
    if IF.InCombat() then return menu.Toast("Not in combat", true) end
    local e = self:Entry()
    local key = KeyOf(e)
    local presses = PressesOf(e)
    -- (asked for, or the only one it has)
    if key and (which == "key" or not presses[1]) then
        if e.def then B.SetKey(e.def.id, nil) else IF.Override.SetKey(key, nil) end
        return Done((e.name or "") .. ": " .. B.KeyText(key) .. " unbound")
    end
    if not presses[1] then return menu.Toast((e and e.name or "It") .. " isn't bound") end
    if e.def then
        B.Assign(e.def.id, nil)
        if e.def.corner then
            for _, region in ipairs(touch.REGIONS) do
                if touch.GetSettings().regions[region] == e.def.id then touch.SetAction(region, "none") end
            end
        end
    else
        TakeOff(e.action)
    end
    Done((e.name or "") .. ": unbound")
end

-- Triangle on an action on a corner: a press clears it, held (0.6 s) turns
-- the corner off / on; a rumble rises once it is clearly a hold, a thump
-- when it acts (Vibration.lua, when loaded)
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
-- The pad: the cards; Square binds the one picked
---------------------------------------------------------------------------
function P:Press(name)
    -- A confirmation up: Cross replaces, Circle backs out, the rest wait
    if self.popup then
        if name == "A" or name == "B" then self:AnswerPopup(name == "A") end
        return true
    end
    -- (Circle closes: the panel's)
    if name == "B" then return false end
    if name == "X" then
        self:Bind()
        return true
    end
    -- (Cross on a card: picked already, nothing to start)
    if name == "A" then return true end
    if name == "Y" then
        if Region() then self:CornerTriangle(Region()) else self:Unbind() end
        return true
    end
    -- L1 / R1: the lists (as L2 / R2)
    if name == "LB" or name == "RB" then name = name == "LB" and "LT" or "RT" end
    self.picker:Press(name)
    menu.Render()
    return true
end

function P:Help()
    local H = K.H
    if self.popup then return { H({ "A" }, "Replace", "A"), H({ "B" }, "Cancel", "B") } end
    local hints = { H({ "DPAD" }, "Move"), H({ "LB", "RB" }, "List"), H({ "X" }, "Bind", "X") }
    if self.key then
        hints[#hints + 1] = H({ "Y" }, Region() and ("Clear / Hold to " .. (touch.IsOff(Region()) and "Turn On" or "Turn Off")) or "Unbind", "Y")
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

-- The drawing beside the list while the game's Gamepad UI is on; off, the
-- list alone, the whole page wide, keys only, and the panel's messages
-- over the legend's place
function P:Arrange()
    local mouse = KeysOnly()
    if self.arranged == mouse then return end
    self.arranged = mouse
    -- (the cards and their lists again for it)
    if self.picker.def then self:OpenPicker() end
    local f = self.frame
    f.mid:SetShown(not mouse)
    self.picker:ClearAllPoints()
    self.picker:SetPoint("TOPLEFT", 8, -8)
    if mouse then
        self.picker:SetPoint("BOTTOMRIGHT", -8, 8)
    else
        self.picker:SetPoint("BOTTOMLEFT", 8, 8)
        self.picker:SetWidth(LIST_W)
    end
    self.ShowsToast = not mouse
    -- (keys alone: a click on a card binds it, no legend; else its Square
    -- in the legend, clicked too)
    self.mouseLegend = not mouse
end

function P:Render()
    local f = self.frame
    if not f then return end
    self:Arrange()
    if not self.picker.def then self:OpenPicker() end
    self.picker:Render()
    self.list = self.picker.list
    -- The card picked: its press lit
    local e = self:Entry()
    self.selAction = e and e.action
    local press = PressesOf(e)[1]
    -- (on another controller a corner, or the View button, isn't drawn)
    local spot = press and SPOT[CornerOf(press) and press or select(2, B.Parse(press))]
    if not (spot and Visible(spot)) then press = nil end
    local region = CornerOf(press)
    if region then
        self.key, self.spec = press, nil
    elseif press then
        local _, pressed = B.Parse(press)
        self.key, self.spec = pressed, press
    else
        self.key, self.spec = nil, nil
    end
    local spec = self.spec
    -- (the buttons held of the press: each ringed)
    local held = {}
    for _, key in ipairs(B.HeldList(spec and B.Parse(spec))) do held[key] = true end
    local bySpec = Snapshot()

    -- The buttons: the one picked lit, marks for what is on each
    for _, s in ipairs(SPOTS) do
        local key, b = s.key, f.spots[s.key]
        b:SetShown(Visible(s))
        if not s.region and b:IsShown() then
            b.glyph:Set(IF.PAD_KEY[key] or key)
            local any, clash = false, false
            for sp, defs in pairs(bySpec) do
                local _, pressed = B.Parse(sp)
                if pressed == key then
                    any = true
                    clash = clash or Clashes(defs, sp)
                end
            end
            local picked = key == self.key
            b.glow:SetShown(picked)
            Tint(b.glow, KC.focus, 0.9)
            local ring = picked or held[key]
            b.ring:SetShown(ring and true or false)
            if picked then
                Tint(b.ring, KC.focus)
            elseif held[key] then
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

    -- Over the drawing: the press; under it, what runs on it (red: two
    -- things clash there)
    f.press:SetText(press and ("|cff9d917aPress|r   " .. PressText(press, 18))
        or ("|cff6f6452" .. (e and ((e.name or "") .. ": not bound") or "Nothing picked") .. "|r"))
    local runs = ""
    if spec then
        local names = {}
        for _, def in ipairs(B.Bound(spec)) do names[#names + 1] = def.label end
        local color = B.Clashing(spec) and "|cffff7a5c" or "|cffd8ccb0"
        runs = "Runs:  " .. color .. table.concat(names, ", ") .. "|r"
    end
    f.runs:SetText(runs)
    local toast = menu.toast
    f.msg:SetText(toast and toast.text or "")
    if toast then f.msg:SetTextColor(unpack(toast.color)) end

    -- A card on no press: the drawing dimmed, Square over it
    local unbound = e and not press
    f.art:SetAlpha(unbound and 0.3 or 1)
    f.over:SetShown(unbound and true or false)
    if unbound then
        f.over.title:SetText("Press " .. IF.GlyphText("X", 22) .. " " .. IF.ButtonName("X") .. " to start binding")
        f.over.sub:SetText((e.name or "") .. " isn't on a press yet: make the one you want")
    end
end

---------------------------------------------------------------------------
-- The Bindings tab, the first
---------------------------------------------------------------------------
menu.AddTab({ key = "bindings", label = "Bindings", icon = IF.TEX .. "ic_mod_controller", order = 10, page = P })

-- The panel kept the touchpad click while it was open; give it back
hooksecurefunc(menu, "Close", function()
    if P.popup then P:AnswerPopup(false) end
    if not IF.InCombat() then touch.Apply() end
end)
