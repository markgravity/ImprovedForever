-- A module's settings as a form, laid out as the auction window's Buy page
-- (Window.lua): the categories down the left (the left stick up / down, or
-- L2 / R2), the category's fields in the middle as rows (the D-pad up /
-- down), each with its control on the right: a toggle, a dropdown, a
-- slider, a button, a press to record. Left / right change a field in
-- place; Cross flips a toggle, opens a dropdown (its list under it: the
-- D-pad moves, Cross picks, Circle closes), runs a button, records a
-- press. Under the rows, what the focused field does. Triangle tries a
-- field that can be felt or seen (a vibration). Square records another
-- press for a field that runs on one (Recorder.lua).
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C
local UI = IF.UI
local menu = IF.Menu
local B = IF.Binds

local SIDE_W = 200
local ROW_H, ROW_GAP = 50, 4          -- a row's least height (it grows with its description)
local LINE_TOP, ROW_PAD = 29, 10     -- the description's top in a row, the room under it
local CONTROL_W = 280
local HEAD_H = 30                     -- a section's title over its fields
local DROP_ROWS, DROP_ROW_H = 12, 20


local function Resolve(v)
    if type(v) == "function" then return v() end
    return v
end

---------------------------------------------------------------------------
-- The fields. Each item = { key, group (its category), section (a title
-- over it and the fields after it with the same one), label, tip, note (a
-- short line under its name), disabled, hidden, try (Triangle: feel it) }
-- and one way to be changed:
--   a toggle:   IF.SettingsOnOff(get, set, label)
--   a dropdown: value() (the chosen action), text() (its name), options() ->
--               { { action, name } or { header } }, choose(action);
--               cycle = false: left / right don't step through them (a menu
--               of things to do, as "Clear the prices")
--   a slider:   slider = { min, max, step, get, set, format(v) -> text }
--   a button:   run(), confirm = true (asks for Cross again first)
--   a press:    bindable, bindId (Binds.lua), binding() -> spec,
--               keyText(size), chord, toggle (recording its own press again
--               unbinds it); with another control, Square records it
--   info:       text() only
---------------------------------------------------------------------------
local function OnOff(get, set, label)
    return {
        onoff = true,
        value = function() return get() and "on" or "off" end,
        text = function() return get() and "On" or "|cffff7a5cOff|r" end,
        options = function()
            return {
                { action = "on", name = "On" },
                { action = "off", name = "Off" },
            }
        end,
        choose = function(action)
            set(action == "on")
            menu.Toast(label .. ": " .. (action == "on" and "on" or "off"))
        end,
    }
end

local function Item(def, behaviour)
    for k, v in pairs(behaviour or {}) do def[k] = v end
    return def
end

local function Kind(item)
    if item.onoff then return "toggle" end
    if item.slider then return "slider" end
    if item.run then return "button" end
    if item.options then return "dropdown" end
    if item.bindable then return "binding" end
    return "info"
end

-- The choices a field steps through with left / right (its actions, in
-- order), and where the current one is; nil: it doesn't step
local function Steps(item)
    if item.cycle == false or not item.options or not item.value then return nil end
    local current = item.value()
    local actions, at = {}, nil
    for _, e in ipairs(item.options()) do
        if e.action then
            actions[#actions + 1] = e.action
            if e.action == current then at = #actions end
        end
    end
    if not at or #actions < 2 then return nil end
    return actions, at
end

-- The first line of a text
local function FirstLine(text)
    text = text or ""
    return text:match("^(.-)|n") or text
end

---------------------------------------------------------------------------
-- The game's Options panel's own controls (Blizzard_Settings), for their
-- look: its check box, its dropdown with a step button each side, its
-- slider with steppers. The row takes the pad (and a click on it); the
-- step buttons and the slider still answer the mouse. Our own look where
-- the client has no such template.
---------------------------------------------------------------------------
local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local function Native(frameType, parent, template)
    local ok, f = pcall(K.NewFrame, frameType, nil, parent, template)
    if ok and f then return f end
end

-- (the Options panel's check box, from its art: its template anchors to its
-- grandparent at load, which a frame made without a parent doesn't have)
local function CheckBox(parent)
    local cb = K.NewFrame("CheckButton", nil, parent)
    cb:SetSize(30, 29)
    local art = { "checkbox-minimal", "checkmark-minimal", "checkmark-minimal-disabled" }
    if IF.HasAtlas(art[1]) then
        cb:SetNormalAtlas(art[1])
        cb:SetCheckedTexture(cb:CreateTexture())
        cb:GetCheckedTexture():SetAtlas(art[2])
        cb:SetDisabledCheckedTexture(cb:CreateTexture())
        cb:GetDisabledCheckedTexture():SetAtlas(art[3])
    else
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    end
    cb:EnableMouse(false)
    return cb
end

-- The dropdown: d.Dropdown (its button), d.DecrementButton / d.IncrementButton;
-- d:SetValueText(text), d:SetSteppers(on). onStep(dir) as a step button is clicked
local function DropButton(parent, width, onStep)
    local d = Native("Frame", parent, "SettingsDropdownWithButtonsTemplate")
    if d and d.Dropdown and d.IncrementButton and d.DecrementButton then
        if d.Label then d.Label:SetText("") end
        d.Dropdown:EnableMouse(false)
        d:SetWidth(width)
        -- (its ▶ on the right edge, as the other controls; the button as
        -- wide as the rest leaves: the step buttons hang off its sides)
        local step = d.IncrementButton:GetWidth()
        if type(step) ~= "number" or step <= 0 then step = 28 end
        d.Dropdown:ClearAllPoints()
        d.Dropdown:SetPoint("RIGHT", d, "RIGHT", -(step + 4), 0)
        d.Dropdown:SetWidth(width - 2 * step - 9)
        d.IncrementButton:SetScript("OnClick", function() onStep(1) end)
        d.DecrementButton:SetScript("OnClick", function() onStep(-1) end)
        function d:SetValueText(text)
            local dd = self.Dropdown
            if dd.OverrideText then dd:OverrideText(text)
            elseif dd.SetText then dd:SetText(text) end
            if dd.Text then dd.Text:SetText(text) end
        end
        function d:SetSteppers(on)
            self.DecrementButton:SetEnabled(on)
            self.IncrementButton:SetEnabled(on)
        end
        return d
    end
    if d then d:Hide() end
    -- (our own: a box, its text, an arrow)
    d = K.NewFrame("Frame", nil, parent)
    d:SetSize(width - 40, 26)
    d.box = K.Box(d, 4, 1, "ARTWORK")
    d.box:SetPoints(d)
    d.box:SetColors(KC.controlBg, 0.95, KC.control, 1)
    d.text = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.text:SetPoint("LEFT", 10, 0)
    d.text:SetPoint("RIGHT", -24, 0)
    d.text:SetJustifyH("LEFT")
    d.text:SetWordWrap(false)
    local arrow = d:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(K.TEX .. "ic_tri")
    arrow:SetSize(11, 11)
    arrow:SetPoint("RIGHT", -9, 0)
    function d:SetValueText(text) self.text:SetText(text) end
    function d:SetSteppers() end
    return d
end

-- The slider: s:Set(value, min, max, step, format); onChange(value) as the
-- mouse moves it (its thumb, its steppers)
local function Slider(parent, width, onChange)
    local s = Native("Frame", parent, "MinimalSliderWithSteppersTemplate")
    if s and s.Slider and s.Init and MinimalSliderWithSteppersMixin then
        s:SetWidth(width)
        local label = MinimalSliderWithSteppersMixin.Label.Right
        local setting = false
        function s:Set(value, min, max, step, format)
            setting = true
            self:Init(value, min, max, math.max(1, math.floor((max - min) / step + 0.5)),
                { [label] = function(v) return format(v) end })
            setting = false
        end
        if s.RegisterCallback and MinimalSliderWithSteppersMixin.Event then
            s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                if not setting then onChange(value) end
            end, s)
        end
        return s
    end
    if s then s:Hide() end
    -- (our own: a track and its fill, the value beside it)
    s = K.NewFrame("Frame", nil, parent)
    s:SetSize(width, 26)
    s.track = K.NewFrame("Frame", nil, s)
    s.track:SetHeight(8)
    s.track:SetPoint("LEFT", 6, 0)
    s.track:SetPoint("RIGHT", s, "RIGHT", -6, 0)
    s.trackBox = K.Box(s.track, 4, 1, "ARTWORK")
    s.trackBox:SetPoints(s.track)
    s.trackBox:SetColors(KC.controlBg, 1, KC.control, 1)
    s.fill = K.Solid(s.track, KC.dimGold, 1, "OVERLAY")
    s.fill:SetPoint("LEFT")
    s.fill:SetHeight(8)
    s.value = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s.value:SetPoint("RIGHT", -8, 0)
    s.value:SetJustifyH("RIGHT")
    function s:Set(value, min, max, _, format)
        local w = self.track:GetWidth()
        if not w or w <= 0 then w = width - 12 end
        self.fill:SetWidth(math.max(1, (value - min) / math.max(1e-9, max - min) * w))
        self.value:SetText(format(value))
    end
    return s
end

---------------------------------------------------------------------------
-- A field's row: a dark card (its name, a line under it), its control on
-- the right. onClick(slot): clicked; onStep(slot, dir): a step button;
-- onSlide(slot, value): its slider moved with the mouse
---------------------------------------------------------------------------
local function FieldRow(parent, width, onClick, onStep, onSlide)
    -- (the dark inset panels' look: the item card's art stretches badly
    -- this wide)
    local r = K.NewFrame("Button", nil, parent, "BackdropTemplate")
    r:SetSize(width, ROW_H)
    r:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    r:SetBackdropColor(0.03, 0.02, 0.01, 0.55)
    r:SetBackdropBorderColor(0.45, 0.38, 0.25, 0.8)
    r.focus = UI.FocusStroke(r)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", 14, -9)
    r.name:SetPoint("RIGHT", r, "RIGHT", -(CONTROL_W + 24), 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.line = K.ChatText(r, 11, KC.grey)
    r.line:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.line:SetPoint("RIGHT", r, "RIGHT", -(CONTROL_W + 24), 0)
    r.line:SetJustifyH("LEFT")
    r.line:SetWordWrap(true)

    -- The controls, one shown at a time on the right: the check box (in
    -- the dropdown's left step button's place), the dropdown, the slider,
    -- a box (a button, a press), a plain value (info)
    r.drop = DropButton(r, CONTROL_W, function(dir) if r.slot then onStep(r.slot, dir) end end)
    r.drop:SetPoint("RIGHT", -12, 0)
    r.check = CheckBox(r)
    r.check:SetPoint("RIGHT", -12, 0)
    -- (its value on the right edge, as the other controls end; the slider
    -- and its steppers the rest)
    local VALUE_W = 56
    r.slider = Slider(r, CONTROL_W - VALUE_W - 8, function(value) if r.slot then onSlide(r.slot, value) end end)
    r.slider:SetPoint("RIGHT", -(12 + VALUE_W + 8), 0)
    local value = r.slider.RightText or r.slider.value
    if value then
        value:ClearAllPoints()
        value:SetPoint("RIGHT", r, "RIGHT", -12, 0)
        value:SetWidth(VALUE_W)
        value:SetJustifyH("RIGHT")
    end

    local c = K.NewFrame("Frame", nil, r)
    c:SetSize(CONTROL_W, 28)
    c:SetPoint("RIGHT", -12, 0)
    c.box = K.Box(c, 4, 1, "ARTWORK")
    c.box:SetPoints(c)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.text:SetPoint("LEFT", 10, 0)
    c.text:SetPoint("RIGHT", -10, 0)
    c.text:SetWordWrap(false)
    r.control = c
    -- (a right-click: the field's second press, Square's or Triangle's)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button) if self.slot then onClick(self.slot, button) end end)

    -- kind: which control; on: the row has the focus; open: its list is open
    function r:SetControl(item, kind, on, open)
        local disabled = Resolve(item.disabled) and true or false
        r.check:SetShown(kind == "toggle")
        r.drop:SetShown(kind == "dropdown")
        r.slider:SetShown(kind == "slider")
        c:SetShown((kind == "button" or kind == "binding") or (kind == "info" and item.text and item.text() ~= ""))
        self.anchor = c
        if kind == "toggle" then
            r.check:SetChecked(item.value() == "on")
            if disabled then r.check:Disable() else r.check:Enable() end
            self.anchor = r.check
            return
        elseif kind == "dropdown" then
            r.drop:SetValueText(FirstLine(item.text and item.text() or "Choose..."))
            r.drop:SetSteppers(not disabled and Steps(item) ~= nil)
            r.drop:SetAlpha(disabled and 0.5 or 1)
            -- (the button's own open look while its list shows)
            local button = r.drop.Dropdown
            if button and button.SetMenuOpen then pcall(button.SetMenuOpen, button, open and true or false) end
            self.anchor = button or r.drop
            return
        elseif kind == "slider" then
            local s = item.slider
            r.slider:Set(s.get(), s.min, s.max, s.step or 1, function(v)
                return s.format and s.format(math.floor(v + 0.5)) or tostring(math.floor(v + 0.5))
            end)
            if r.slider.SetEnabled then r.slider:SetEnabled(not disabled) end
            self.anchor = r.slider
            return
        end
        local edge = on and KC.slot or KC.control
        c.text:SetJustifyH("CENTER")
        if kind == "button" then
            c.box:SetColors(KC.pressed, 0.95, edge, 1)
            c.text:SetText(item.button or item.label)
        elseif kind == "binding" then
            c.box:SetColors(KC.controlBg, 0.95, edge, 1)
            -- (with the mouse its keyboard / mouse press, when it takes one)
            local def = B.Get(item.bindId)
            local keyed = (not IF.Input.Pad() or not IF.Input.PadEnabled()) and B.TakesKey(def)
            c.text:SetText(IF.Recorder.IsActive() and on and "Press a button..."
                or keyed and B.KeyText(B.KeyBind(def))
                or (item.keyText and item.keyText(16) or B.Text(item.binding(), 16)))
        else
            c.box:SetColors(nil, nil, nil, nil)
            c.text:SetJustifyH("RIGHT")
            c.text:SetText(FirstLine(item.text and item.text() or ""))
        end
        c:SetAlpha(disabled and 0.5 or 1)
    end
    return r
end

---------------------------------------------------------------------------
-- The dropdown's list, as the game's own menu (Blizzard_Menu's look: its
-- background, the radio ticks, the highlight bar): the field's choices, the
-- current one ticked, the cursor lit
---------------------------------------------------------------------------
local DROP_INSET = { left = 10, top = 10, right = 10, bottom = 10 }

local function Dropdown(parent, onClick)
    local d = K.NewFrame("Frame", nil, parent)
    d:SetFrameLevel(parent:GetFrameLevel() + 30)
    d:SetWidth(CONTROL_W + 20)
    d:EnableMouse(true)
    local bg = d:CreateTexture(nil, "BACKGROUND", nil, -8)
    if not Atlas(bg, "common-dropdown-bg") then bg:SetColorTexture(0.05, 0.04, 0.03, 0.95) end
    bg:SetPoint("TOPLEFT", -10, 3)
    bg:SetPoint("BOTTOMRIGHT", 10, -3)
    bg:SetAlpha(0.925)
    d.rows = {}
    for i = 1, DROP_ROWS do
        local r = K.NewFrame("Button", nil, d)
        r:SetHeight(DROP_ROW_H)
        r:SetPoint("TOPLEFT", DROP_INSET.left, -DROP_INSET.top - (i - 1) * DROP_ROW_H)
        r:SetPoint("RIGHT", d, "RIGHT", -DROP_INSET.right, 0)
        r.highlight = r:CreateTexture(nil, "BACKGROUND")
        r.highlight:SetAllPoints()
        r.highlight:SetBlendMode("ADD")
        r.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        r.highlight:Hide()
        r.tick = r:CreateTexture(nil, "ARTWORK")
        if not Atlas(r.tick, "common-dropdown-tickradial") then r.tick:SetColorTexture(0.3, 0.3, 0.3, 0.8) end
        r.tick:SetSize(16, 16)
        r.tick:SetPoint("LEFT", -3, 0)
        r.check = r:CreateTexture(nil, "OVERLAY")
        if not Atlas(r.check, "common-dropdown-icon-radialtick-yellow") then r.check:SetColorTexture(1, 0.82, 0, 1) end
        r.check:SetSize(16, 16)
        r.check:SetPoint("TOPLEFT", r.tick, "TOPLEFT")
        r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        r.text:SetPoint("LEFT", r.tick, "RIGHT", 4, 0)
        r.text:SetPoint("RIGHT", 0, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.title = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        r.title:SetPoint("LEFT", 0, 0)
        r.title:SetJustifyH("LEFT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button) if self.index then onClick(self.index, button) end end)
        d.rows[i] = r
    end
    d.moreUp, d.moreDown = K.MoreArrows(d)
    d.moreUp:SetPoint("TOP", d, "TOP", 0, -1)
    d.moreDown:SetPoint("BOTTOM", d, "BOTTOM", 0, 1)
    d:Hide()

    -- entries: the field's options; cursor: the lit one; current: the
    -- chosen action
    function d:Render(entries, cursor, current)
        local n = math.min(DROP_ROWS, #entries)
        self:SetHeight(DROP_INSET.top + DROP_INSET.bottom + n * DROP_ROW_H)
        local top = math.max(1, math.min(cursor - math.floor(DROP_ROWS / 2), #entries - DROP_ROWS + 1))
        self.moreUp:SetShown(top > 1)
        self.moreDown:SetShown(top + DROP_ROWS - 1 < #entries)
        for i, r in ipairs(self.rows) do
            local index = top + i - 1
            local e = entries[index]
            r:SetShown(e ~= nil and i <= n)
            if e then
                local header = e.header ~= nil
                r.index = e.action and index or nil
                r.title:SetShown(header)
                r.text:SetShown(not header)
                r.tick:SetShown(not header)
                r.check:SetShown(not header and current ~= nil and e.action == current)
                r.highlight:SetShown(not header and index == cursor)
                if header then
                    r.title:SetText(e.header)
                else
                    r.text:SetText(e.name or e.action)
                end
            end
        end
    end
    return d
end

---------------------------------------------------------------------------
-- The page. tab = { key, label, order, module }: its tab (Menu.lua);
-- GROUPS / ITEMS: { { key, label, note } }, the items above. hooks
-- (optional): render(G) after each drawing, hide() as the tab goes.
---------------------------------------------------------------------------
function IF.SettingsPage(tab, GROUPS, ITEMS, hooks)
    hooks = hooks or {}
    -- zone: "fields", "dropdown" (the focused field's list)
    -- (mouseLegend false: no legend with the mouse, every press has a click)
    local G = { zone = "fields", group = 1, index = {}, mouseLegend = false }

    -- The current category's fields
    function G:Fields()
        local key = GROUPS[self.group].key
        local list = {}
        for _, item in ipairs(ITEMS) do
            if item.group == key and not Resolve(item.hidden) then list[#list + 1] = item end
        end
        return list
    end

    function G:Item()
        local fields = self:Fields()
        local i = math.max(1, math.min(#fields, self.index[self.group] or 1))
        self.index[self.group] = i
        return fields[i], i, fields
    end

    function G:Build(parent)
        local stage = parent:GetParent() or parent
        local f = K.NewFrame("Frame", nil, stage)
        f:SetAllPoints(stage)
        f:Hide()
        self.frame = f

        -- Left: the categories
        f.side = UI.SideList(f, SIDE_W, 17, function(i)
            G:SetGroup(i)
            menu.Render()
        end)
        f.side:SetPoint("TOPLEFT", 8, -8)
        f.side:SetPoint("BOTTOMLEFT", 8, 8)

        -- Middle: the category's name over its fields
        f.status = K.ChatText(f, 11, KC.help)
        f.status:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 14, -4)
        f.status:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        f.status:SetJustifyH("LEFT")
        f.list = K.NewFrame("Frame", nil, f)
        f.list:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 10, -22)
        f.list:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        f.list:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
        f.measure = K.ChatText(f, 11, KC.grey)
        f.measure:SetWordWrap(true)
        f.measure:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.measure:SetAlpha(0)
        f.moreUp, f.moreDown = K.MoreArrows(f)
        f.moreUp:SetPoint("BOTTOM", f.list, "TOP", 0, 2)
        f.moreDown:SetPoint("TOP", f.list, "BOTTOM", 0, -1)
        f.rows = {}

        f.drop = Dropdown(f, function(index, button)
            G.cursor = index
            -- (a right-click tries it, as Triangle)
            local item = G:Item()
            if button == "RightButton" then
                if item and item.try then item.try() end
            else
                G:Choose()
            end
            menu.Render()
        end)

        -- The mouse: the wheel scrolls the fields (or the open list), a
        -- list's choice under it lit
        f.list:EnableMouseWheel(true)
        f.list:SetScript("OnMouseWheel", function(_, delta) G:Wheel(delta) end)
        f.drop:EnableMouseWheel(true)
        f.drop:SetScript("OnMouseWheel", function(_, delta) G:Wheel(delta) end)
        for _, r in ipairs(f.drop.rows) do
            r:SetScript("OnEnter", function(self)
                if self.index and not IF.Input.Pad() and G.zone == "dropdown" then
                    G.cursor = self.index
                    menu.Render()
                end
            end)
        end
    end

    -- The wheel: the open list's choice moved, else the fields scrolled a
    -- line (the focus kept in view)
    function G:Wheel(delta)
        local dir = delta > 0 and -1 or 1
        if self.zone == "dropdown" then
            self:MoveCursor(dir)
            return menu.Render()
        end
        local lines, drawn = self.lines, self.drawn or 0
        if not lines or #lines == 0 then return end
        self.top = self.top or {}
        local top = self.top[self.group] or 1
        if dir > 0 and top + drawn - 1 >= #lines then return end
        top = math.max(1, math.min(#lines, top + dir))
        local _, index = self:Item()
        local at
        for n, line in ipairs(lines) do
            if line.slot == index then at = n end
        end
        -- (the focus scrolled off: the nearest field still in view)
        local last = top + math.max(1, drawn - 1) - 1
        if at and at < top then
            for n = top, #lines do
                if lines[n].slot then self.index[self.group] = lines[n].slot break end
            end
        elseif at and at > last then
            for n = last, top, -1 do
                if lines[n].slot then self.index[self.group] = lines[n].slot break end
            end
        end
        self.top[self.group] = top
        menu.Disarm()
        menu.Render()
    end

    function G:Row(i)
        local f = self.frame
        if f.rows[i] then return f.rows[i] end
        local w = f.list:GetWidth()
        if not w or w <= 0 then w = 760 end
        local function Focus(slot)
            G.index[G.group], G.zone = slot, "fields"
            return (G:Item())
        end
        local r = FieldRow(f.list, w, function(slot, button)
            local item = Focus(slot)
            -- (as Cross, so a press waiting for it to confirm gets it; a
            -- right-click records the field's press, else tries it)
            if button == "RightButton" then
                if item and (item.bindable or item.try) then G:Press(item.bindable and "X" or "Y") end
            else
                G:Press("A")
            end
            menu.Render()
        end, function(slot, dir)
            G:Step(Focus(slot), dir)
            menu.Render()
        end, function(slot, value)
            local item = Focus(slot)
            local sl = item.slider
            value = math.floor(value / (sl.step or 1) + 0.5) * (sl.step or 1)
            if sl and value ~= sl.get() and not Resolve(item.disabled) then sl.set(value) end
            menu.Render()
        end)
        -- (the mouse over a field: the focus, its help on the right)
        r:HookScript("OnEnter", function(self)
            if self.slot and not IF.Input.Pad() and G.zone == "fields"
                and self.slot ~= G.index[G.group] then
                Focus(self.slot)
                menu.Render()
            end
        end)
        f.rows[i] = r
        return r
    end

    -- A section's title: gold, a rule running on to the right
    function G:Head(i)
        local f = self.frame
        f.heads = f.heads or {}
        if f.heads[i] then return f.heads[i] end
        local hd = K.NewFrame("Frame", nil, f.list)
        hd.text = K.Text(hd, 14, KC.title)
        hd.text:SetPoint("BOTTOMLEFT", 4, 6)
        hd.rule = K.Solid(hd, KC.line1, 1, "ARTWORK")
        hd.rule:SetHeight(1)
        hd.rule:SetPoint("LEFT", hd.text, "RIGHT", 10, 0)
        hd.rule:SetPoint("RIGHT", hd, "RIGHT", -4, 0)
        f.heads[i] = hd
        return hd
    end

    function G:SetGroup(i)
        self.group = (i - 1) % #GROUPS + 1
        self.zone = "fields"
        menu.Disarm()
    end

    -- The left stick, up / down (Menu.lua): the categories
    function G:StickStep(dir)
        if self.zone == "dropdown" then return end
        self:SetGroup(self.group + dir)
    end

    function G:Show()
        self.zone = "fields"
        self.frame:Show()
    end

    function G:Hide()
        self:StopCapture()
        self.zone = "fields"
        self.frame:Hide()
        if hooks.hide then hooks.hide() end
    end

    ---------------------------------------------------------------------------
    -- Changing a field
    ---------------------------------------------------------------------------
    -- Left / right: a step (dir -1 / 1) through its choices or its range
    function G:Step(item, dir)
        if Resolve(item.disabled) then return end
        if item.slider then
            local s = item.slider
            local v = math.max(s.min, math.min(s.max, s.get() + dir * (s.step or 1)))
            if v ~= s.get() then s.set(v) end
            return
        end
        local actions, at = Steps(item)
        if not actions then return end
        -- (a toggle: left off, right on; a dropdown: round from the ends)
        local next = item.onoff and (dir > 0 and "on" or "off") or actions[(at - 1 + dir) % #actions + 1]
        if next ~= item.value() then item.choose(next) end
    end

    -- The dropdown opened on the current choice
    function G:OpenDropdown(item)
        self.zone = "dropdown"
        local current = item.value and item.value()
        self.cursor = nil
        for i, e in ipairs(item.options()) do
            if e.action and (e.action == current or not self.cursor) then
                self.cursor = i
                if e.action == current then break end
            end
        end
        self.cursor = self.cursor or 1
    end

    function G:MoveCursor(dir)
        local entries = self:Item().options()
        local i = self.cursor
        repeat
            i = i + dir
        until not entries[i] or entries[i].action
        if entries[i] then self.cursor = i end
    end

    -- Cross in the dropdown: that choice (the list stays open while a
    -- choice asks for Cross again: "Clear the prices")
    function G:Choose()
        local item = self:Item()
        local e = item.options()[self.cursor]
        if not (e and e.action) then return end
        item.choose(e.action)
        if not menu.armed then self.zone = "fields" end
    end

    -- Cross on a field
    function G:Act()
        local item = self:Item()
        if not item or Resolve(item.disabled) then return end
        local kind = Kind(item)
        if kind == "toggle" then
            item.choose(item.value() == "on" and "off" or "on")
        elseif kind == "dropdown" then
            self:OpenDropdown(item)
        elseif kind == "button" then
            local id = "field:" .. tab.key .. ":" .. item.key
            if item.confirm and not menu.IsArmed(id) then
                menu.Arm(id)
                menu.Toast(IF.PadText((item.confirmText or (item.label .. "?"))
                    .. (IF.Input.Pad() and " {A} again to confirm" or " Click again to confirm")), true, 4)
            else
                menu.Disarm()
                item.run()
            end
        elseif kind == "binding" then
            self:StartCapture()
        end
    end

    ---------------------------------------------------------------------------
    -- Binding a field to another button
    ---------------------------------------------------------------------------
    -- Square: a press recorded for the field (Recorder.lua: the first
    -- button let go ends it)
    function G:StartCapture()
        local item = self:Item()
        if not item or not item.bindable or IF.InCombat() then return end
        local def = B.Get(item.bindId)
        -- (the Gamepad UI off: keys and clicks only; none taken: nothing to do)
        if not IF.Input.PadEnabled() and not B.TakesKey(def) then
            return menu.Toast(item.label .. ": a controller press only (the Gamepad UI is off)", true)
        end
        -- (a key or a click too, when it takes one: its keyboard / mouse press)
        local keyed = B.TakesKey(def)
        IF.Recorder.Start({
            title = "Bind " .. item.label, chord = item.chord and true or false,
            accept = def and def.accepts, reject = item.label .. " can't go on that press",
            onDone = function(spec) G:Offer(item, spec) end,
            keys = keyed and (def.run ~= nil or def.button ~= nil or def.click ~= nil),
            clicks = keyed and def.click ~= nil,
            acceptKey = function(spec) return B.KeyFits(def, spec) end,
            onKey = function(spec) G:CommitKey(item, def, spec) end,
            onCancel = function() menu.Toast(item.label .. ": unchanged") end,
        })
    end

    function G:StopCapture()
        IF.Recorder.Stop()
    end

    -- A recorded press for a field: bound, or (taking it from something
    -- else) once Cross confirms
    function G:Offer(item, spec)
        local def = B.Get(item.bindId)
        if item.toggle and def and B.Has(def, spec) then
            B.Assign(item.bindId, nil)
            return menu.Toast(item.label .. ": unbound")
        end
        local gone = B.Conflicts(item.bindId, spec)
        if #gone > 0 then
            self.pending = { item = item, spec = spec }
            menu.Arm("record:" .. item.bindId)
            return menu.Toast(IF.PadText(B.Text(spec) .. " runs " .. B.Names(gone)
                .. (IF.Input.Pad() and ": {A} replaces it, {B} keeps it" or ": click it again to replace it")), true, 4)
        end
        self:Commit(item, spec)
    end

    -- A recorded key / click: its keyboard / mouse press (the same again: off)
    function G:CommitKey(item, def, spec)
        if B.KeyBind(def) == spec then
            B.SetKey(def.id, nil)
            return menu.Toast(item.label .. ": " .. B.KeyText(spec) .. " unbound")
        end
        local gone = B.SetKey(def.id, spec)
        menu.Toast(item.label .. ": " .. B.KeyText(spec)
            .. (#gone > 0 and (" (" .. B.Names(gone) .. " unbound)") or ""), #gone > 0)
    end

    function G:Commit(item, spec)
        local gone = B.Assign(item.bindId, spec)
        menu.Toast(item.label .. ": " .. (item.keyText and item.keyText() or B.Text(spec))
            .. (#gone > 0 and (" (" .. B.Names(gone) .. " unbound)") or ""), #gone > 0)
    end

    ---------------------------------------------------------------------------
    -- The pad
    ---------------------------------------------------------------------------
    function G:Press(name)
        -- A recorded press waiting for Cross (any other press let it go)
        local pending = self.pending
        self.pending = nil
        if pending and name == "A" and menu.IsArmed("record:" .. pending.item.bindId) then
            menu.Disarm()
            self:Commit(pending.item, pending.spec)
            menu.Render()
            return true
        end
        if name == "LB" or name == "RB" then return self.zone == "dropdown" end
        local item, i, fields = self:Item()
        if self.zone == "dropdown" then
            if name == "UP" or name == "DOWN" then
                self:MoveCursor(name == "UP" and -1 or 1)
            elseif name == "A" then
                self:Choose()
            elseif name == "B" or name == "LEFT" then
                self.zone = "fields"
                menu.Disarm()
            elseif name == "Y" and item.try then
                item.try()
            end
            menu.Render()
            return true
        end
        if name == "LT" or name == "RT" then
            self:SetGroup(self.group + (name == "LT" and -1 or 1))
            menu.Render()
            return true
        end
        if not item then return false end
        if name == "X" then
            if item.bindable then self:StartCapture() end
            return true
        end
        if name == "Y" then
            if item.try then item.try() end
            return true
        end
        if name == "UP" or name == "DOWN" then
            self.index[self.group] = math.max(1, math.min(#fields, i + (name == "UP" and -1 or 1)))
            menu.Disarm()
        elseif name == "LEFT" or name == "RIGHT" then
            self:Step(item, name == "LEFT" and -1 or 1)
        elseif name == "A" then
            self:Act()
        else
            -- Circle closes the panel
            return false
        end
        menu.Render()
        return true
    end

    function G:Help()
        local H = K.H
        local hints = {}
        local item = self:Item()
        if not item then
            return { H({ "LS" }, "Category"), H({ "RS" }, "Tab"), H({ "B" }, "Close", "B") }
        end
        local kind = Kind(item)
        if self.zone == "dropdown" then
            hints[#hints + 1] = H({ "DPAD_UD" }, "Move")
            hints[#hints + 1] = H({ "A" }, "Choose", "A")
            if item.try then hints[#hints + 1] = H({ "Y" }, "Try it", "Y") end
            hints[#hints + 1] = H({ "B" }, "Close list", "B")
            return hints
        end
        hints[#hints + 1] = H({ "DPAD_UD" }, "Move")
        if item.slider or Steps(item) then hints[#hints + 1] = H({ "DPAD_LR" }, "Change") end
        local verb = ({ toggle = "Toggle", dropdown = "Choose", button = item.button or item.label,
            binding = "Record" })[kind]
        if verb and not Resolve(item.disabled) then hints[#hints + 1] = H({ "A" }, verb, "A") end
        if item.bindable and kind ~= "binding" then hints[#hints + 1] = H({ "X" }, "Record", "X") end
        if item.try then hints[#hints + 1] = H({ "Y" }, "Try it", "Y") end
        hints[#hints + 1] = H({ "LS" }, "Category")
        hints[#hints + 1] = H({ "RS" }, "Tab")
        hints[#hints + 1] = H({ "B" }, "Close", "B")
        return hints
    end

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------
    -- The line under a field's name: its clash, its note, the rest of
    -- what it shows (info), else what it does
    -- (with the mouse: what a right-click on it does, the pad's second press)
    local function MouseNote(item)
        if IF.Input.Pad() then return "" end
        if item.bindable then
            local keyed = B.TakesKey(B.Get(item.bindId))
            if not IF.Input.PadEnabled() then
                return keyed and "  |cff9d917aRight-click: record a key or a click.|r" or ""
            end
            return keyed and "  |cff9d917aRight-click: record a key, a click or a controller press.|r"
                or "  |cff9d917aRight-click: record a controller press.|r"
        end
        if item.try then return "  |cff9d917aRight-click: try it.|r" end
        return ""
    end

    -- (a binding that takes one: its keyboard / mouse press)
    local function KeyNote(item)
        local def = item.bindable and B.Get(item.bindId)
        if not B.TakesKey(def) then return "" end
        return "  |cffd8ccb0Keyboard / mouse: " .. B.KeyText(B.KeyBind(def)) .. ".|r"
    end

    function G:Line(item)
        if item.bindable then
            local clashes = B.ClashesOf(item.bindId)
            if #clashes > 0 then return "|cffff7a5cClashes with " .. B.Names(clashes) .. " (Bindings tab)|r" end
        end
        local note = Resolve(item.note)
        if note then return note end
        local rest = item.text and (item.text():match("^.-|n(.*)$"))
        if rest and Kind(item) == "info" then return (rest:gsub("|n", "  ·  ")) end
        return (Resolve(item.tip) or "") .. KeyNote(item) .. MouseNote(item)
    end

    -- A field's row's height: its description wrapped to the row's width
    -- (measured in a hidden copy of the row's line)
    function G:Height(item, width)
        local m = self.frame.measure
        m:SetWidth(width - CONTROL_W - 38)
        m:SetText(self:Line(item))
        local text = m:GetText()
        local h = (text and text ~= "") and m:GetStringHeight() or 0
        return math.max(ROW_H, math.ceil(LINE_TOP + h + ROW_PAD))
    end

    function G:Render()
        local f = self.frame
        if not f or #GROUPS == 0 then return end
        local entries = {}
        for i, g in ipairs(GROUPS) do entries[i] = { label = g.label } end
        f.side:Render((IF.Input.Pad() and (IF.GlyphText("LS", 18) .. " ") or "") .. "Category", entries,
            self.group, self.zone ~= "dropdown")

        local item, index, fields = self:Item()
        local group = GROUPS[self.group]
        f.status:SetText(group.label .. (group.note and ("  ·  " .. Resolve(group.note)) or "")
            .. "  ·  " .. #fields .. (#fields == 1 and " setting" or " settings"))

        -- The fields, each as tall as its description, under their
        -- sections' titles; as many lines as fit from the top one, scrolled
        -- (by lines) to keep the focused field, and its title when it is
        -- its section's first, in view
        local h = f.list:GetHeight()
        if not h or h <= 0 then h = 360 end
        local w = f.list:GetWidth()
        if not w or w <= 0 then w = 760 end
        local lines, at, section = {}, {}, nil
        for i, it in ipairs(fields) do
            if it.section and it.section ~= section then lines[#lines + 1] = { head = it.section } end
            section = it.section
            lines[#lines + 1] = { slot = i }
            at[i] = #lines
        end
        local heights = {}
        for i, line in ipairs(lines) do
            heights[i] = line.head and HEAD_H or self:Height(fields[line.slot], w)
        end
        local function Span(from, to)
            local total = 0
            for i = from, to do total = total + heights[i] + (i > from and ROW_GAP or 0) end
            return total
        end
        local want = at[index] or 1
        local first = (lines[want - 1] and lines[want - 1].head) and want - 1 or want
        self.top = self.top or {}
        local top = math.max(1, math.min(self.top[self.group] or 1, first))
        while top < want and Span(top, want) > h do top = top + 1 end
        -- (pulled back up while the rows under the last still leave room)
        while top > 1 and Span(top - 1, #lines) <= h do top = top - 1 end
        self.top[self.group] = top
        local y, shown, heads, drawn = 0, 0, 0, 0
        for n = top, #lines do
            if y + heights[n] > h and n > top then break end
            drawn = drawn + 1
            local line = lines[n]
            if line.head then
                heads = heads + 1
                local hd = self:Head(heads)
                hd:ClearAllPoints()
                hd:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
                hd:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
                hd:SetHeight(heights[n])
                hd.text:SetText(line.head)
                hd:Show()
                y = y + heights[n] + ROW_GAP
            else
                local slot = line.slot
                shown = shown + 1
                local r = self:Row(shown)
                local it = fields[slot]
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
                r:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
                r:SetHeight(heights[n])
                r:Show()
                r.slot = slot
                local on = slot == index
                local disabled = Resolve(it.disabled)
                r.name:SetText(it.label)
                r.name:SetTextColor(unpack(disabled and KC.disabled or (on and KC.focusText or KC.cream)))
                r.line:SetText(self:Line(it))
                r:SetControl(it, Kind(it), on and self.zone ~= "dropdown", on and self.zone == "dropdown")
                r.focus:Light(on, self.zone ~= "fields")
                y = y + heights[n] + ROW_GAP
            end
        end
        for i = shown + 1, #f.rows do f.rows[i]:Hide() end
        for i = heads + 1, #(f.heads or {}) do f.heads[i]:Hide() end
        self.lines, self.drawn = lines, drawn
        f.moreUp:SetShown(top > 1)
        f.moreDown:SetShown(top + drawn - 1 < #lines)
        local placed = 0
        for i = top, want do placed = placed + heights[i] + ROW_GAP end

        -- The dropdown, under its field's control
        local open = self.zone == "dropdown" and item and item.options
        f.drop:SetShown(open and true or false)
        if open then
            local row
            for _, r in ipairs(f.rows) do
                if r:IsShown() and r.slot == index then row = r end
            end
            f.drop:ClearAllPoints()
            -- (under it; over it for the rows in the lower half)
            if row and placed > h / 2 then
                f.drop:SetPoint("BOTTOMRIGHT", row.anchor or row.control, "TOPRIGHT", 0, 6)
            elseif row then
                f.drop:SetPoint("TOPRIGHT", row.anchor or row.control, "BOTTOMRIGHT", 0, -6)
            else
                f.drop:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", 0, 0)
            end
            f.drop:Render(item.options(), self.cursor or 1, item.value and item.value())
        end
        if hooks.render then hooks.render(self) end
    end

    hooksecurefunc(menu, "Close", function()
        G:StopCapture()
        G.zone = "fields"
    end)

    menu.AddTab({ key = tab.key, label = tab.label, icon = tab.icon, order = tab.order, module = tab.module, page = G })
    return G
end

IF.SettingsItem, IF.SettingsOnOff = Item, OnOff
