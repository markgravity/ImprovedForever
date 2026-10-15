-- The panel's Wheels tab, adapted from Easy Controller - Forever's MyWheels
-- (moust4ki, MIT License, see LICENSE-EasyController.md), in the auction
-- window's look: down the left every wheel (the built-in ones, the
-- player's own, "New wheel"; the left stick picks one); beside it the
-- wheel, its slots around it (8 a page: the D-pad left / right steps
-- round them, L2 / R2 turn the page), what opens it in the
-- hub (bound in the Bindings tab); on the right what a slot can take,
-- its lists (Spells, Items, Macros, Emotes) in a bar along the top (L1 /
-- R1), each a list of cards (the D-pad up / down):
-- Cross fills the slot and moves on to the next one. Triangle clears a
-- slot (held: renames, or resets a built-in wheel); Square hides or shows
-- the wheel (with the mouse: the button under it), held deletes one of
-- yours. A hidden wheel stays on this list, dimmed, but is off the
-- Bindings tab and the ring (MyWheels.lua).
-- "New wheel" makes one of a kind (WheelKinds.lua: the D-pad left / right
-- picks it): slots of your own, or one that fills itself.
-- "+ Add a phrase" in the Phrases list types a phrase for the slot (a
-- keyboard; the one in the slot to edit; the D-pad left / right goes
-- through phrases added before, up / down its channel).
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local MW = IF.MyWheels
local menu = IF.Menu

local UI = IF.UI

local SIDE_W = 200
local BOX_W = 380                   -- the rename box over the wheel
local PICKER_ROWS = 7
-- The wheel: Forever's radial menu (the R3 ring's art and layout, Ring.lua),
-- its 540 x 541 frame drawn at ZONE_SCALE between the list and the picker
local ZONE_SCALE = 0.74
local SCALE = 1
local CX, CY = 270, 270             -- in the wheel's 540 x 541 frame
local WEDGE_RADIUS = 150 * SCALE    -- highlight / empty wedges
local ICON_SIZE = math.floor(38 * SCALE + 0.5)
local PER_PAGE = 8
-- A wheel whose slots go in the hub (the Group wheel's spells): a small
-- ring of them there, its members round the wheel
local HUB_RADIUS, HUB_ICON = 45, 26
-- What opens the wheel: its glyphs under it (in the wheel's frame, past
-- its bottom edge)
local BIND_Y = 541 + 22

-- zone: nil, or "popup" (a confirmation up), "rename" (naming the wheel)
-- kindIndex: the kind "New wheel" makes (KD.Available()'s)
local W = { index = 1, slot = 1, btn = 1, kindIndex = 1 }
local KD = IF.WheelKinds
MW.Page = W

---------------------------------------------------------------------------
-- The wheels on the rail (hidden ones too, dimmed), then "New wheel" while
-- there is room
---------------------------------------------------------------------------
function W:Entries()
    local entries = MW.Wheels(true)
    if #MW.List() < MW.MAX then
        entries[#entries + 1] = { new = true, label = "+ New wheel" }
    end
    return entries
end

-- The selected wheel (or the "New wheel" entry), kept by its key
function W:Current()
    local entries = self:Entries()
    if self.key then
        for i, e in ipairs(entries) do
            if e.key == self.key then
                self.index = i
                return e, entries
            end
        end
    end
    self.index = math.max(1, math.min(self.index or 1, #entries))
    local e = entries[self.index]
    self.key = e and e.key
    return e, entries
end

local function Editable(wheel)
    return wheel and wheel.slots ~= nil
end

-- What the wheel's slots hold right now (a self-filling one: its content)
local function Slots(wheel)
    if not wheel or wheel.new then return {} end
    return wheel.slots or MW.LiveSlots(wheel)
end

local function Pages(wheel)
    return math.max(1, math.ceil((wheel and wheel.max or PER_PAGE) / PER_PAGE))
end

local function Count(wheel)
    local n = 0
    for _ in pairs(Slots(wheel)) do n = n + 1 end
    return n
end

-- Slot p's icon, from the wheel's top left (y down)
local function SlotPoint(p)
    local a = (p - 1) * math.pi / 4
    local ix, iy = IF.SlotLayout(math.sin(a), math.cos(a))
    return CX + ix * SCALE, CY - iy * SCALE
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function W:Build(parent)
    -- The whole screen, as the R3 wheel (the panel's frame, not its body)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- Left: the wheels
    f.side = UI.SideList(f, SIDE_W, 17, function(i)
        if MW.renaming then return end
        W:Select(i)
        menu.Render()
    end)
    f.side:SetPoint("TOPLEFT", 8, -8)
    f.side:SetPoint("BOTTOMLEFT", 8, 8)
    f.side:EnableMouseWheel(true)
    f.side:SetScript("OnMouseWheel", function(_, delta)
        if MW.renaming then return end
        W:Select(W.index - delta)
        menu.Render()
    end)
    -- The wheel
    local zone = K.NewFrame("Frame", nil, f)
    zone:SetSize(540, 541)
    zone:SetScale(ZONE_SCALE)
    -- (a scaled frame's offsets are in its own units)
    zone:SetPoint("LEFT", f, "LEFT", (8 + SIDE_W + 6) / ZONE_SCALE, 0)
    f.zone = zone
    -- In the hub: the wheel's name, its count, its page
    f.title = K.Text(zone, 15, KC.white)
    f.title:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 16))
    f.title:SetWidth(150)
    f.title:SetJustifyH("CENTER")
    f.kicker = K.ChatText(zone, 12, KC.grey)
    f.kicker:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 32))
    f.kicker:SetWidth(150)
    f.kicker:SetJustifyH("CENTER")
    f.kicker:SetWordWrap(true)
    f.kicker:SetSpacing(2)
    local function atlas(texture, name, fallback)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            texture:SetAtlas(name)
        elseif fallback then
            texture:SetTexture(K.TEX .. fallback)
        end
    end
    local wheelBg = zone:CreateTexture(nil, "BACKGROUND", nil, -3)
    wheelBg:SetSize(540 * SCALE, 541 * SCALE)
    wheelBg:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    atlas(wheelBg, "gamepad-radial-menu-wheelbg", "ic_disc")
    -- The highlight wedge (the slot with the focus, or the one the picker
    -- fills): the art faces down at rotation 0
    f.highlight = zone:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.highlight:SetSize(169 * SCALE, 165 * SCALE)
    atlas(f.highlight, "gamepad-radial-menu-selected")
    f.hubName = K.Text(zone, 12, KC.cream)
    f.hubName:Hide()
    f.hubName:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 9))
    f.hubName:SetSize(80, 30)
    f.hubName:SetJustifyH("CENTER")
    f.hubName:SetWordWrap(true)
    if f.hubName.SetMaxLines then f.hubName:SetMaxLines(2) end
    -- What it is bound to, as button glyphs, under the wheel
    f.bindGlyphs = K.GlyphRow(zone, 36)
    -- A wheel of several pages: a dot each (the native page dots), under it
    f.pageDots = {}
    for i = 1, 4 do
        local d = zone:CreateTexture(nil, "OVERLAY")
        d:SetSize(11, 11)
        f.pageDots[i] = d
    end
    f.bindNone = K.ChatText(zone, 13, KC.grey)
    f.bindNone:SetPoint("CENTER", zone, "TOPLEFT", CX, -BIND_Y)
    f.bindNone:SetText("Not bound")
    f.count = K.Text(zone, 14, KC.title)
    f.count:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 10))
    f.count:SetJustifyH("CENTER")

    f.slots = {}
    for p = 1, PER_PAGE do
        local a = (p - 1) * math.pi / 4
        local sn, cs = math.sin(a), math.cos(a)
        -- An empty slot: the dimmed wedge, a "+"
        local empty = zone:CreateTexture(nil, "BACKGROUND", nil, -2)
        empty:SetSize(169 * SCALE, 164 * SCALE)
        empty:SetPoint("CENTER", zone, "TOPLEFT", CX + WEDGE_RADIUS * sn, -(CY - WEDGE_RADIUS * cs))
        atlas(empty, "gamepad-radial-menu-disabled")
        empty:SetRotation(math.pi - a)
        local s = K.NewFrame("Button", nil, zone)
        s:SetSize(ICON_SIZE, ICON_SIZE)
        -- Laid out as the wheel in play (Ring.lua, the native radial's)
        local ix, iy, lx, ly = IF.SlotLayout(sn, cs)
        s:SetPoint("CENTER", zone, "TOPLEFT", CX + ix * SCALE, -CY + iy * SCALE)
        s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        s.empty = empty
        s.icon = K.RoundIcon(s, ICON_SIZE, "ARTWORK")
        s.icon:SetPoint("CENTER")
        s.plus = K.Text(s, 18, KC.dimGold, "OVERLAY")
        s.plus:SetPoint("CENTER", 0, 1)
        s.plus:SetText("+")
        s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        s.count:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 3, -2)
        s.label = K.Text(zone, 12, KC.title, "OVERLAY")
        s.label:SetSize(90, 40)
        s.label:SetWordWrap(true)
        s.label:SetJustifyH("CENTER")
        s.label:SetPoint("CENTER", zone, "TOPLEFT", CX + lx * SCALE, -CY + ly * SCALE)
        s:SetScript("OnClick", function(_, button)
            if MW.renaming or (W:Current() or {}).hub then return end
            menu.Disarm()
            W.slot = W:PageBase() + p
            if button == "RightButton" then
                W:Empty()
            else
                W:Aim()
            end
        end)
        f.slots[p] = s
    end

    -- The hub's slots (a wheel with hub = true): 1 at the top, clockwise
    f.hubSlots = {}
    for p = 1, PER_PAGE do
        local a = (p - 1) * math.pi / 4
        local h = K.NewFrame("Button", nil, zone)
        h:SetSize(HUB_ICON, HUB_ICON)
        h:SetPoint("CENTER", zone, "TOPLEFT", CX + HUB_RADIUS * math.sin(a), -(CY - HUB_RADIUS * math.cos(a)))
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- (the slot with the focus: a cyan disc behind it)
        h.focus = K.RoundIcon(h, HUB_ICON + 6, "BACKGROUND")
        h.focus:SetPoint("CENTER")
        h.focus:SetTexture("Interface\\Buttons\\WHITE8x8")
        h.focus:SetVertexColor(KC.info[1], KC.info[2], KC.info[3])
        h.icon = K.RoundIcon(h, HUB_ICON, "ARTWORK")
        h.icon:SetPoint("CENTER")
        h.plus = K.Text(h, 14, KC.dimGold, "OVERLAY")
        h.plus:SetPoint("CENTER", 0, 1)
        h.plus:SetText("+")
        h:SetScript("OnClick", function(_, button)
            if MW.renaming then return end
            menu.Disarm()
            W:SetSlot(p)
            if button == "RightButton" then
                W:Empty()
            else
                W:Aim()
            end
        end)
        h:Hide()
        f.hubSlots[p] = h
    end

    -- Gamepad mode off: under the wheel, a button that hides or shows it
    -- (Square's)
    f.hideButton = K.Button(f, 14)
    f.hideButton:SetSize(160, 30)
    f.hideButton:SetPoint("TOP", zone, "BOTTOM", 0, -48)
    f.hideButton.label:SetText("Hide wheel")
    f.hideButton:SetScript("OnClick", function()
        if MW.renaming then return end
        menu.Disarm()
        W:ToggleHidden(W:Current())
    end)
    f.hideButton:Hide()

    -- The name typed in a box over the wheel (a physical keyboard)
    local veil = K.NewFrame("Frame", nil, zone)
    veil:SetAllPoints()
    veil:SetFrameLevel(zone:GetFrameLevel() + 20)
    veil:EnableMouse(true)
    K.Solid(veil, { 0.04, 0.03, 0.02 }, 0.72, "BACKGROUND"):SetAllPoints()
    veil:Hide()
    f.veil = veil
    -- (the box itself unscaled, over the wheel's middle)
    local box = K.NewFrame("Frame", nil, f)
    box:SetSize(BOX_W, 136)
    box:SetPoint("CENTER", zone, "CENTER", 0, 0)
    box:SetFrameLevel(zone:GetFrameLevel() + 25)
    box.bg = K.Box(box, 4, 2, "BACKGROUND")
    box.bg:SetPoints(box)
    box.bg:SetColors(KC.panel, 1, KC.focus, 1)
    box.kicker = K.ChatText(box, 12, KC.grey)
    box.kicker:SetPoint("TOPLEFT", 14, -14)
    box.kicker:SetText("WHEEL NAME")
    local field = K.NewFrame("Frame", nil, box)
    field:SetPoint("TOPLEFT", box.kicker, "BOTTOMLEFT", 0, -8)
    field:SetSize(BOX_W - 28, 36)
    field.box = K.Box(field, 3, 2, "ARTWORK")
    field.box:SetPoints(field)
    field.box:SetColors(KC.boxBg, 1, KC.control, 1)
    local edit = K.NewFrame("EditBox", nil, field)
    edit:SetAllPoints()
    edit:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    edit:SetTextColor(KC.focusText[1], KC.focusText[2], KC.focusText[3])
    edit:SetTextInsets(10, 10, 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(40)
    edit:SetScript("OnEnterPressed", function(self) W:FinishRename(self:GetText()) end)
    edit:SetScript("OnEscapePressed", function() W:FinishRename(nil) end)
    box.edit = edit
    box.help = K.ChatText(box, 13, KC.help)
    box.help:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, -8)
    box.help:SetWidth(BOX_W - 28)
    box.help:SetWordWrap(true)
    box.help:SetSpacing(5)
    self.box = box

    -- The confirmation / recording box: the game's own dialog look
    local d = K.NewFrame("Frame", nil, f, "BackdropTemplate")
    d:SetSize(440, 160)
    d:SetPoint("CENTER", f, "CENTER", 0, 0)
    d:SetFrameLevel(f:GetFrameLevel() + 60)
    d:EnableMouse(true)
    d:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    d.text = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.text:SetFont("Fonts\\FRIZQT__.TTF", 15, "")
    d.text:SetPoint("TOP", d, "TOP", 0, -28)
    d.text:SetWidth(390)
    d.text:SetSpacing(4)
    d.hintRow = K.NewFrame("Frame", nil, d)
    d.hintRow:SetSize(1, 30)
    d.hintRow:SetPoint("BOTTOM", d, "BOTTOM", 0, 22)
    d.hints = {}
    for i = 1, 2 do
        d.hints[i] = K.Hint(d.hintRow, function(press) W:Press(press) end)
    end
    d:Hide()
    self.dialog = d

    -- Right: the picker (its lists in a bar, its choices as cards), or for
    -- a self-filling wheel what it does
    local right = (8 + SIDE_W + 6) + 540 * ZONE_SCALE + 6
    self.picker = UI.CardPicker(f, 1, 46, menu.Render, "LB", "RB")
    self.picker:SetPoint("TOPLEFT", f, "TOPLEFT", right, -8)
    self.picker:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    self.detail = K.Detail(f, 340)
    self.detail:SetPoint("TOPLEFT", f, "TOPLEFT", right, -8)
    self.detail:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    self.detail:SetHeight(300)
end

function W:Show()
    self.zone = nil
    self.frame:Show()
    self:Select(self.index)
end

-- The left stick (Menu.lua): up / down the wheels (the picker's lists are
-- L1 / R1's)
function W:StickStep(dir)
    if self.zone or MW.renaming then return end
    self:Select(self.index + dir)
end

function W:Hide()
    self:FinishRename(nil)
    -- An open confirmation is a no
    if self.popup then self:AnswerPopup(false) end
    if self.dialog then self.dialog:Hide() end
    self.picker:Close()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Selecting, aiming, filling
---------------------------------------------------------------------------
function W:PageBase()
    return math.floor((self.slot - 1) / PER_PAGE) * PER_PAGE
end

function W:Select(i)
    local entries = self:Entries()
    i = math.max(1, math.min(i, #entries))
    if i ~= self.index then menu.Disarm() end
    self.index = i
    local wheel = entries[i]
    self.key = wheel and wheel.key
    self.slot, self.btn = 1, 1
    self:OpenPicker(wheel)
end

-- The picker for the wheel's lists, aimed at its slot
function W:OpenPicker(wheel)
    if not Editable(wheel) then
        self.picker:Close()
        return
    end
    self.picker:Open({
        kicker = function() return format("Slot %d · %s", W.slot, MW.POSITIONS[(W.slot - 1) % PER_PAGE + 1]) end,
        title = function() return (W:Current() or {}).label or "" end,
        lists = wheel.lists, rows = PICKER_ROWS, current = wheel.slots[self.slot], chooseVerb = "Choose, next",
        -- (phrases: where they go right now)
        status = function()
            local list = W.picker.def and W.picker.def.lists[W.picker.list]
            return list == KD.PHRASES and ("|cff9fd8e2Said to " .. KD.PhraseWhere() .. "|r") or ""
        end,
        -- Already in this wheel: a diamond
        marked = function(e)
            local current = W:Current()
            for _, action in pairs(current and current.slots or {}) do
                if action == e.action then return true end
            end
            return false
        end,
        onChoose = function(e)
            if MW.renaming then return end
            -- ("+ Add a phrase": the box, its text and channel)
            if e.add then
                local wheel = W:Current()
                local current = wheel and wheel.slots and wheel.slots[W.slot]
                W:StartRename(wheel, "phrase", not (current and KD.PhraseText(current)))
                return menu.Render()
            end
            W:Fill(e)
        end,
    })
end

function W:Aim()
    local wheel = self:Current()
    if not Editable(wheel) then return menu.Render() end
    local def = self.picker.def
    local current = wheel.slots[self.slot]
    if def then
        def.current = current
        local kind = current and current:match("^(%a+):")
        for i, list in ipairs(wheel.lists) do
            if kind and list.key == kind .. "s" then
                self.picker:SetList(i)
                break
            end
        end
    end
    menu.Render()
end

function W:Fill(e)
    local wheel = self:Current()
    if not (Editable(wheel) and e and e.action) then return end
    MW.SetWheelSlot(wheel, self.slot, e.action)
    menu.Toast(format("Slot %d: %s", self.slot, e.name or ""))
    self.slot = self.slot % wheel.max + 1
end

function W:Empty()
    local wheel = self:Current()
    if Editable(wheel) and wheel.slots[self.slot] then
        MW.SetWheelSlot(wheel, self.slot, nil)
        menu.Toast("Slot emptied")
    end
    menu.Render()
end

---------------------------------------------------------------------------
-- Confirmations: the game's own pop-up (Forever drives it with the pad:
-- Cross accepts, Circle cancels). The panel lets the pad go while it is up.
---------------------------------------------------------------------------
function W:Confirm(text, acceptLabel, onAccept, onCancel)
    if IF.InCombat() then return end
    self.zone = "popup"
    self.popup = { onAccept = onAccept, onCancel = onCancel }
    self:ShowDialog(text, {
        K.H({ "A" }, acceptLabel or "OK", "A"),
        K.H({ "B" }, "Cancel", "B"),
    })
    menu.Render()
end

-- Cross / Circle on the confirmation
function W:AnswerPopup(accepted)
    local popup = self.popup
    self.popup = nil
    self.dialog:Hide()
    self.zone = nil
    if popup then
        if accepted then
            popup.onAccept()
        elseif popup.onCancel then
            popup.onCancel()
        end
    end
    menu.Render()
end

-- The box itself: the game's own dialog look (its dark background and gold
-- border), its text, and what Cross / Circle do in it
function W:ShowDialog(text, hints)
    local d = self.dialog
    d.text:SetText(text)
    local x = 0
    for i, h in ipairs(d.hints) do
        local hint = hints and hints[i]
        h:SetShown(hint ~= nil)
        if hint then
            h:Set(hint)
            h:ClearAllPoints()
            h:SetPoint("LEFT", d.hintRow, "LEFT", x, 0)
            x = x + h:GetWidth() + 28
        end
    end
    d.hintRow:SetWidth(math.max(1, x - 28))
    d:SetHeight(math.max(150, d.text:GetStringHeight() + (hints and 100 or 60)))
    d:Show()
end

-- A press, or a hold (0.6 s): Triangle and Square do one thing each way;
-- a rumble rises once it is clearly a hold, a thump when it acts
-- (Vibration.lua, when loaded)
local HOLD, FEEL_AFTER = 0.6, 0.15

function W:PressOrHold(key, onPress, onHold)
    if self.holding then return end
    local started = GetTime()
    self.holding = key
    C_Timer.NewTicker(0.05, function(ticker)
        local held = IsKeyDown and IsKeyDown(key)
        local elapsed = GetTime() - started
        if held and elapsed >= HOLD then
            ticker:Cancel()
            W.holding = nil
            if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
            onHold()
        elseif not held then
            ticker:Cancel()
            W.holding = nil
            if IF.Vibe and elapsed >= FEEL_AFTER then IF.Vibe.Hold(nil) end
            onPress()
        elseif elapsed >= FEEL_AFTER and IF.Vibe then
            IF.Vibe.Hold(elapsed / HOLD)
        end
    end)
end

-- Triangle: clears the slot; held, renames the wheel (a built-in one:
-- back to its defaults, once confirmed)
function W:Triangle(wheel)
    self:PressOrHold("PAD4", function() W:Empty() end, function()
        if wheel.id then
            W:StartRename(wheel)
            menu.Render()
        elseif wheel.reset then
            W:Confirm("Reset the " .. wheel.label .. " wheel to its defaults?", RESET or "Reset", function()
                MW.ResetWheel(wheel)
                W:Select(W.index)
                menu.Toast(wheel.label .. " reset")
            end)
        end
    end)
end

-- Hides a wheel (off the Bindings tab and the ring), or shows it again
function W:ToggleHidden(wheel)
    if not (wheel and wheel.key) or wheel.new then return end
    local hidden = not MW.Hidden(wheel.key)
    MW.SetHidden(wheel.key, hidden)
    menu.Toast(wheel.label .. (hidden and " hidden: off the Bindings tab and the ring" or " shown"))
    menu.Render()
end

-- Square: hides or shows the wheel; held, deletes a wheel of yours (once
-- confirmed). Binding a wheel to a press is the Bindings tab's.
function W:Square(wheel)
    if not wheel.id then
        self:ToggleHidden(wheel)
        return
    end
    self:PressOrHold("PAD3", function()
        W:ToggleHidden(wheel)
    end, function()
        W:Confirm('Delete the wheel "' .. wheel.label .. '"?', "Delete", function()
            MW.Delete(wheel.id)
            W.key = nil
            W:Select(W.index)
            menu.Toast("Wheel deleted")
        end)
    end)
end

-- The kind "New wheel" makes
function W:NewKind()
    local kinds = KD.Available()
    self.kindIndex = math.max(1, math.min(self.kindIndex or 1, #kinds))
    return kinds[self.kindIndex]
end

function W:StepKind(step)
    local kinds = KD.Available()
    self.kindIndex = ((self.kindIndex or 1) - 1 + step) % #kinds + 1
end

function W:CreateWheel()
    local id = MW.Create(self:NewKind().key)
    if not id then
        menu.Toast("8 wheels at most. Delete one to make room.", true)
        return
    end
    self.key = MW.RingKey(id)
    self:Current()
    self:Select(self.index)
    self:Aim()
end

---------------------------------------------------------------------------
-- Naming: D-pad left / right goes through suggested names (the pad alone
-- can name a wheel), a keyboard can type any name
---------------------------------------------------------------------------
local SUGGESTIONS = {
    "Combat", "Defensive", "Healing", "Buffs", "Utility", "Cooldowns", "Crowd Control", "Pets", "Travel",
    "Mounts", "Professions", "Food & Drink", "Potions", "Macros", "Social", "Questing", "Quest Items",
    "PvP", "Dungeon",
}

function W:Suggestions(wheel)
    local list = {}
    -- First, its kind's own name, then what is in its first filled slot
    local kind = KD.Get(wheel.kind)
    if kind.name then list[1] = kind.name end
    local slots = Slots(wheel)
    for i = 1, wheel.max do
        local name = slots[i] and MW.ActionName(slots[i])
        if name then
            list[#list + 1] = name
            break
        end
    end
    for _, name in ipairs(SUGGESTIONS) do list[#list + 1] = name end
    list[#list + 1] = "Wheel " .. wheel.id
    return list
end

function W:StepName(step)
    local wheel = self:Current()
    if not (wheel and (wheel.id or self.typing == "phrase")) then return end
    local list
    if self.typing == "phrase" then
        -- (the phrases added before)
        list = {}
        for _, action in ipairs(KD.SavedPhrases()) do list[#list + 1] = KD.PhraseText(action) end
        if #list == 0 then return end
    else
        list = self:Suggestions(wheel)
    end
    self.suggestion = ((self.suggestion or 0) - 1 + step) % #list + 1
    self.box.edit:SetText(list[self.suggestion])
    self.box.edit:HighlightText()
end

-- The phrase box's kicker: the slot, and where the phrase goes
function W:PhraseKicker()
    self.box.kicker:SetText(format("PHRASE FOR SLOT %d  ·  %s", self.slot,
        KD.ChannelLabel(KD.CHANNELS[self.channel].key):upper()))
end

-- D-pad up / down in the phrase box: its channel
function W:StepChannel(step)
    self.channel = (self.channel - 1 + step) % #KD.CHANNELS + 1
    self:PhraseKicker()
end

-- The box over the wheel: its name, or (mode "phrase") a chat phrase for
-- the slot aimed at (blank: a new one, from "+ Add a phrase")
function W:StartRename(wheel, mode, blank)
    if not wheel or IF.InCombat() then return end
    mode = mode or "name"
    -- (a name: the player's own wheels; a phrase: any wheel with slots)
    if mode == "name" and not wheel.id then return end
    if mode == "phrase" and not Editable(wheel) then return end
    MW.renaming = wheel.key
    self.typing = mode
    self.suggestion = 0
    self.zone = "rename"
    local edit = self.box.edit
    local phrase = self.typing == "phrase"
    edit:SetMaxLetters(phrase and 200 or 40)
    if phrase then
        local current = not blank and wheel.slots and wheel.slots[self.slot]
        local chan = current and KD.PhraseChannel(current) or "auto"
        self.channel = 1
        for i, c in ipairs(KD.CHANNELS) do
            if c.key == chan then self.channel = i end
        end
        self:PhraseKicker()
        edit:SetText(current and KD.PhraseText(current) or "")
    else
        self.box.kicker:SetText("WHEEL NAME")
        edit:SetText(wheel.label)
    end
    self.box.help:SetText(IF.PadText(phrase
        and "Type a phrase (a keyboard), or D-pad left / right picks one you added; up / down its channel."
            .. " {A} confirms, {B} cancels."
        or "D-pad left / right picks a name, {A} confirms, {B} cancels. A keyboard can type one too."))
    self.frame.veil:Show()
    edit:SetFocus()
    edit:HighlightText()
end

function W:FinishRename(text)
    local key = MW.renaming
    if not key then return end
    MW.renaming = nil
    self.box.edit:ClearFocus()
    self.frame.veil:Hide()
    if self.zone == "rename" then self.zone = nil end
    local typing = self.typing
    self.typing = nil
    if text and typing == "phrase" then
        -- (kept in the Phrases list; the slot takes it, on to the next, as a
        -- pick from the list)
        local chan = KD.CHANNELS[self.channel or 1].key
        local action = KD.MakePhrase(text, chan)
        local wheel = self:Current()
        if action and Editable(wheel) and wheel.key == key then
            KD.SavePhrase(action)
            self:Fill({ action = action, name = KD.PhraseText(action) })
        end
    elseif text then
        local wheel = self:Current()
        if wheel and wheel.key == key and wheel.id then MW.Rename(wheel.id, text) end
    end
    menu.Render()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- Around the wheel: the nearest slot of the page that way
function W:Nearest(dir)
    local p = (self.slot - 1) % PER_PAGE + 1
    local fx, fy = SlotPoint(p)
    local best, bestScore
    for i = 1, PER_PAGE do
        if i ~= p then
            local x, y = SlotPoint(i)
            local dx, dy = x - fx, y - fy
            local main, cross
            if dir == "UP" then
                main, cross = -dy, dx
            elseif dir == "DOWN" then
                main, cross = dy, dx
            elseif dir == "LEFT" then
                main, cross = -dx, dy
            else
                main, cross = dx, dy
            end
            if main > 6 and math.abs(cross) <= main * 2.2 then
                local score = main + math.abs(cross) * 2
                if not bestScore or score < bestScore then best, bestScore = i, score end
            end
        end
    end
    return best and self:PageBase() + best
end

local DIRS = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

-- The same place on the previous / next page (Buffs: 3 pages of 8)
function W:StepPage(step)
    local wheel = self:Current()
    if not wheel or wheel.new then return end
    local pages = Pages(wheel)
    if pages < 2 then return end
    local page = math.floor((self.slot - 1) / PER_PAGE)
    local p = (self.slot - 1) % PER_PAGE + 1
    page = (page + step) % pages
    self.slot = math.min(wheel.max, page * PER_PAGE + p)
end

-- The slot aimed at; the picker on what it holds
function W:SetSlot(slot)
    self.slot = slot
    local wheel = self:Current()
    if Editable(wheel) and self.picker.def then
        local current = wheel.slots[slot]
        self.picker.def.current = current
        local kind = current and current:match("^(%a+):")
        for i, list in ipairs(wheel.lists) do
            if kind and list.key == kind .. "s" then
                if i ~= self.picker.list then self.picker:SetList(i) end
                break
            end
        end
    end
end

function W:Press(name)
    local wheel = self:Current()
    if self.zone == "popup" then
        if name == "A" then
            self:AnswerPopup(true)
        elseif name == "B" then
            self:AnswerPopup(false)
        end
        return true
    end
    if self.zone == "rename" then
        if name == "A" then
            self:FinishRename(self.box.edit:GetText())
        elseif name == "B" then
            self:FinishRename(nil)
        elseif (name == "UP" or name == "DOWN") and self.typing == "phrase" then
            self:StepChannel(name == "UP" and -1 or 1)
        elseif name == "LEFT" or name == "RIGHT" or name == "UP" or name == "DOWN" then
            self:StepName((name == "LEFT" or name == "UP") and -1 or 1)
        end
        return true
    end
    -- L1 / R1: the picker's lists (the panel's tabs are the right stick's)
    if name == "LB" or name == "RB" then
        if not (self.picker.def and Editable(wheel)) then return false end
        self.picker:Press(name == "LB" and "LT" or "RT")
        menu.Render()
        return true
    end
    -- (Circle closes: the panel's)
    if name == "B" then return false end
    if not wheel or wheel.new then
        if name == "A" then
            self:CreateWheel()
        elseif name == "LEFT" or name == "RIGHT" then
            self:StepKind(name == "LEFT" and -1 or 1)
        end
        menu.Render()
        return true
    end
    if name == "Y" then
        if Editable(wheel) or wheel.reset or wheel.id then self:Triangle(wheel) end
        return true
    elseif name == "X" then
        self:Square(wheel)
        return true
    elseif name == "LT" or name == "RT" then
        self:StepPage(name == "LT" and -1 or 1)
        self:SetSlot(self.slot)
    elseif name == "LEFT" or name == "RIGHT" then
        -- The slot before / after (round the wheel)
        self:SetSlot((self.slot - 1 + (name == "LEFT" and -1 or 1)) % wheel.max + 1)
    elseif Editable(wheel) then
        self.picker:Press(name)
    end
    menu.Render()
    return true
end

function W:Help()
    local H = K.H
    local wheel = self:Current()
    if self.zone == "rename" then
        local hints = { H({ "DPAD_LR" }, self.typing == "phrase" and "Phrase" or "Name", "RIGHT") }
        if self.typing == "phrase" then hints[#hints + 1] = H({ "DPAD_UD" }, "Channel", "DOWN") end
        hints[#hints + 1] = H({ "A" }, "Confirm", "A")
        hints[#hints + 1] = H({ "B" }, "Cancel", "B")
        return hints
    end
    if self.zone == "popup" then return { H({ "A" }, "Confirm", "A"), H({ "B" }, "Cancel", "B") } end
    -- Only what does something here: a wheel that fills itself has no slot
    -- to fill, "New wheel" nothing to page, bind or clear
    local hints = { H({ "LS" }, "Wheel") }
    if not wheel or wheel.new then
        if #KD.Available() > 1 then hints[#hints + 1] = H({ "DPAD_LR" }, "Kind", "RIGHT") end
        hints[#hints + 1] = H({ "A" }, "Create", "A")
    else
        hints[#hints + 1] = H({ "DPAD_LR" }, "Slot")
        if Editable(wheel) then
            hints[#hints + 1] = H({ "LB", "RB" }, "List", "RB")
            hints[#hints + 1] = H({ "DPAD_UD" }, "Move")
            hints[#hints + 1] = H({ "A" }, "Choose", "A")
            hints[#hints + 1] = H({ "Y" }, wheel.id and "Clear / Hold to Rename"
                or (wheel.reset and "Clear / Hold to Reset" or "Clear"), "Y")
        elseif wheel.id then
            hints[#hints + 1] = H({ "Y" }, "Hold to Rename", "Y")
        end
        if Pages(wheel) > 1 then hints[#hints + 1] = H({ "LT", "RT" }, "Page", "RT") end
        local hideVerb = wheel.hidden and "Show" or "Hide"
        hints[#hints + 1] = H({ "X" }, wheel.id and (hideVerb .. " / Hold to Delete") or hideVerb, "X")
    end
    hints[#hints + 1] = H({ "RS" }, "Tab")
    hints[#hints + 1] = H({ "B" }, "Close", "B")
    return hints
end

function W:Crumb()
    local wheel = self:Current()
    return "Wheels › " .. (wheel and wheel.label or "")
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function W:Render()
    local f = self.frame
    if not f then return end
    local wheel, entries = self:Current()

    -- The wheels down the left
    local lines = {}
    for i, entry in ipairs(entries) do
        lines[i] = { label = entry.hidden and ("|cff7d7468" .. entry.label .. " (hidden)|r") or entry.label }
    end
    f.side:Render(IF.GlyphText("LS", 18) .. " Wheels", lines, self.index, self.zone == nil)

    -- "New wheel" selected: an empty wheel and what Cross does
    local isNew = wheel == nil or wheel.new
    local slots = Slots(wheel)
    local max = isNew and PER_PAGE or wheel.max
    if self.slot > max then self.slot = 1 end
    local base = self:PageBase()
    f.title:SetText(isNew and "New wheel" or wheel.label)
    local pages = isNew and 1 or Pages(wheel)
    -- Under the count: its page, and what opens it
    local lines = {}
    if isNew then lines[1] = IF.ButtonName("A") .. " makes one" end
    if pages > 1 then lines[#lines + 1] = format("Page %d / %d", base / PER_PAGE + 1, pages) end
    if not isNew then
        local hotkey = MW.HotkeyText(wheel.key)
        lines[#lines + 1] = hotkey and ("|cff9fd8e2" .. hotkey .. "|r") or "Not bound"
    end
    f.kicker:SetText(table.concat(lines, "\n"))
    -- The hub shows only what the wheel is bound to
    f.title:Hide()
    f.kicker:Hide()
    f.count:Hide()
    -- The page dots (the one shown lit), in the hub
    local pageNow = base / PER_PAGE + 1
    for i, d in ipairs(f.pageDots) do
        d:SetShown(pages > 1 and i <= pages)
        if pages > 1 and i <= pages then
            d:ClearAllPoints()
            d:SetPoint("CENTER", d:GetParent(), "TOPLEFT", CX + (i - (pages + 1) / 2) * 15, -CY)
            local name = i == pageNow and "gamepad-radialgamemenu-cursorbg-neutral" or "gamepad-radialgamemenu-cursorbg-inactive"
            if C_Texture.GetAtlasInfo(name) then
                d:SetAtlas(name)
            else
                local v = i == pageNow and 1 or 0.4
                d:SetColorTexture(v, v, v, 1)
            end
        end
    end
    -- (a wheel with its slots in the hub: those there)
    local hub = not isNew and wheel.hub
    local glyphs = not isNew and MW.BindGlyphs(wheel.key)
    f.bindGlyphs:SetShown(glyphs and true or false)
    f.bindNone:SetShown(not isNew and not glyphs)
    if glyphs then
        local w = f.bindGlyphs:Set(glyphs)
        f.bindGlyphs:ClearAllPoints()
        f.bindGlyphs:SetPoint("CENTER", f.bindGlyphs:GetParent(), "TOPLEFT", CX, -BIND_Y)
        f.bindGlyphs:SetWidth(math.max(1, w))
    end

    -- A hub wheel: its slots there, the focused one lit; round the wheel
    -- what it holds now (the Group wheel: the group, its first page)
    for p, h in ipairs(f.hubSlots) do
        local action = hub and slots[p]
        h:SetShown(hub and p <= max or false)
        if hub and p <= max then
            h.icon:SetShown(action ~= nil)
            if action then K.SetIcon(h.icon, MW.ActionIcon(action) or 134400) end
            h.plus:SetShown(not action)
            h.focus:SetShown(p == self.slot)
        end
    end
    local G = IF.GroupWheel
    local members = hub and G and IF.RingBuilders[wheel.key] and IF.RingBuilders[wheel.key]() or {}
    for p, s in ipairs(f.slots) do
        local entry = hub and (members.groups and members.groups[1] or members)[p]
        if hub then
            s:SetShown(entry ~= nil)
            s.empty:SetShown(false)
            s.label:SetShown(entry ~= nil)
            if entry then
                local name, icon, color, usable = G.Look(entry.unit)
                s.icon:Show()
                K.SetIcon(s.icon, icon)
                s.icon:SetDesaturated(not usable)
                s.plus:Hide()
                s.count:SetText("")
                s.label:SetText(name)
                s.label:SetTextColor(unpack(usable and (color or KC.title) or KC.grey))
                s:SetAlpha(1)
            end
        end
    end
    -- The slot the right stick picked always shows (the picker fills it)
    local onSlots = true
    for p, s in ipairs(f.slots) do
        local i = base + p
        local action = slots[i]
        local shown = i <= max and not hub
        if not hub then s:SetShown(shown) end
        -- (an empty slot: just its "+" and its place, no grey wedge)
        if not hub then s.empty:SetShown(false) end
        if not hub then s.label:SetShown(shown) end
        if shown then
            s.icon:SetDesaturated(false)
            local name, icon = action and MW.ActionName(action), action and MW.ActionIcon(action)
            s.icon:SetShown(action ~= nil)
            if action then K.SetIcon(s.icon, icon or 134400) end
            s.plus:SetShown(not action and Editable(wheel) or false)
            local count = action and action:match("^item:(%d+)$")
            local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
            s.count:SetText(count and getCount and getCount(tonumber(count)) or "")
            s.label:SetText(name or MW.POSITIONS[p])
            local focus = i == self.slot
            s.label:SetTextColor(unpack(focus and KC.white or (action and KC.title or KC.grey)))
            s:SetAlpha(isNew and 0.35 or 1)
            s.empty:SetAlpha(isNew and 0.35 or 1)
        end
    end
    -- The highlight on the slot with the focus (cyan: the picker fills it)
    local showHighlight = not isNew and not hub and self.slot <= max
    f.highlight:SetShown(showHighlight)
    if showHighlight then
        local a = ((self.slot - 1) % PER_PAGE) * math.pi / 4
        f.highlight:ClearAllPoints()
        f.highlight:SetPoint("CENTER", f.highlight:GetParent(), "TOPLEFT",
            CX + WEDGE_RADIUS * math.sin(a), -(CY - WEDGE_RADIUS * math.cos(a)))
        f.highlight:SetRotation(math.pi - a)
        -- (cyan: the picker fills it)
        if Editable(wheel) then
            f.highlight:SetVertexColor(KC.info[1], KC.info[2], KC.info[3])
        else
            f.highlight:SetVertexColor(1, 1, 1)
        end
    end
    local focused = slots[self.slot]
    local showSlot = onSlots
    local newKind = isNew and self:NewKind()
    f.hubName:SetText(newKind and newKind.label or showSlot and (focused and MW.ActionName(focused)
        or (hub and "Empty" or MW.POSITIONS[(self.slot - 1) % PER_PAGE + 1])) or "")
    f.hubName:SetTextColor(unpack(focused and KC.cream or KC.grey))
    -- (the hub's slot's name, in its middle)
    f.hubName:SetShown(hub or false)
    f.hubName:ClearAllPoints()
    f.hubName:SetPoint("CENTER", f.hubName:GetParent(), "TOPLEFT", CX, -(hub and CY or (CY - 9)))
    f.hubName:SetSize(hub and 58 or 80, 30)
    f.count:SetText(isNew and "" or format("%d / %d", Count(wheel), max))

    -- Right: the picker (faded unless it has the focus), or the detail
    if Editable(wheel) then
        self.detail:Hide()
        if not self.picker:IsOpen() then self:OpenPicker(wheel) end
        self.picker:Show()
        self.picker:Render()
    else
        self.picker:Close()
        self.detail:Show()
        if isNew then
            local kinds = KD.Available()
            self.detail:Set({ title = "New wheel: " .. newKind.label,
                tag = newKind.slots and "Your slots" or "Fills itself", tagColor = KC.slot,
                body = newKind.about .. " Up to " .. MW.MAX .. " wheels.",
                extra = #kinds > 1 and IF.PadText("D-pad left / right: the kind (" .. self.kindIndex .. " of "
                    .. #kinds .. "). {A} makes it.") or nil })
        else
            self.detail:Set({ title = wheel.label, tag = "Fills itself", tagColor = KC.slot, body = wheel.info,
                extra = "Bound to: " .. (MW.HotkeyText(wheel.key) or "nothing")
                    .. ". Bind it to a press in the Bindings tab." })
        end
    end
    -- (only with the game's gamepad mode off: on the pad, Square)
    f.hideButton:SetShown(not isNew and not IF.Input.PadEnabled() and self.zone == nil)
    if not isNew then f.hideButton.label:SetText(wheel.hidden and "Show wheel" or "Hide wheel") end
    -- The box over the wheel: naming
    f.veil:SetShown(self.zone == "rename")
    self.box:SetShown(self.zone == "rename")
end

---------------------------------------------------------------------------
-- The Wheels tab (Menu.lua) uses this page
---------------------------------------------------------------------------
menu.AddTab({ key = "wheel", label = "Wheels", module = "wheel", order = 20, page = W })

-- The panel closed (Circle, combat) while naming: cancelled
hooksecurefunc(menu, "Close", function()
    W:FinishRename(nil)
end)
