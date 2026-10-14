-- The configuration panel, in the auction window's look (Window.lua): one
-- tab per module loaded down the window's right (the right stick tilted up
-- / down), the tab's page inside: a module's settings as
-- form fields (SettingsPage.lua: its sections down the left, their fields
-- in the middle, the focused one's choices on the right), or a page of its
-- own (the wheel editor, the vibration patterns, the controller drawing).
-- The legend under the window shows what the pad does there. While it is
-- open the pad is bound to hidden buttons of ours, out of combat only, and
-- released when it closes (or combat starts).
-- Open it with /if, the key binding, the AddOns options, or Menu pressed
-- twice.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C
local UI = IF.UI

local menu = {}
IF.Menu = menu

-- The window; the stage inside it (what a page lays itself out on: a page
-- built on menu.body draws on menu.body:GetParent()), the body in its
-- middle (BODY_W x BODY_H: the pages' own layouts are made for it)
local W, H = 1010, 620
local BODY_W, BODY_H = 964, 424
local STICK_ON, STICK_OFF = 0.6, 0.3
local STEP_DELAY, STEP_EVERY = 0.35, 0.2

---------------------------------------------------------------------------
-- The tabs: menu.AddTab{ key, label, icon, order, page }. A page: Build(body),
-- Show(), Hide(), Render(), Press(name) -> handled (Circle unhandled: the
-- panel closes), Help() -> { K.H... }, and
-- optionally OnStick(stick, x, y, len) -> true (it takes that stick), StickStep(dir)
-- (the left stick up / down: -1 up, 1 down, repeating while held),
-- StickSide(dir) (the left stick left / right: once a tilt), OnTouch() (the
-- touchpad clicked).
---------------------------------------------------------------------------
menu.TABS = {}

function menu.AddTab(def)
    -- (an old Controller module still loaded: its tab is the core's Bindings now)
    if def.key == "controller" then return def end
    def.order = def.order or 50
    if not def.icon and def.module and IF.Module(def.module) then def.icon = IF.Module(def.module).icon end
    for i, other in ipairs(menu.TABS) do
        if other.key == def.key then
            menu.TABS[i] = def
            return def
        end
    end
    menu.TABS[#menu.TABS + 1] = def
    table.sort(menu.TABS, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    return def
end

local function Tab(key)
    for _, def in ipairs(menu.TABS) do
        if def.key == key then return def end
    end
end

---------------------------------------------------------------------------
-- Transient states: a destructive button armed (a second Cross does it;
-- Circle, a move or 4 s let it go), a short message over the legend (1.8 s)
---------------------------------------------------------------------------
function menu.Arm(id)
    menu.armed = id
    menu.armToken = (menu.armToken or 0) + 1
    local token = menu.armToken
    C_Timer.After(4, function()
        if menu.armToken == token and menu.armed == id then
            menu.armed = nil
            menu.Render()
        end
    end)
end

function menu.IsArmed(id)
    return menu.armed ~= nil and menu.armed == id
end

function menu.Disarm()
    menu.armed = nil
end

function menu.Toast(text, warn, seconds)
    menu.toast = { text = text, color = warn and KC.warn or KC.info }
    menu.toastToken = (menu.toastToken or 0) + 1
    local token = menu.toastToken
    C_Timer.After(seconds or 1.8, function()
        if menu.toastToken == token then
            menu.toast = nil
            menu.Render()
        end
    end)
    menu.Render()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local frame
local built = {}

function menu.IsOpen()
    return frame ~= nil and frame:IsShown()
end

local function CurrentTab()
    return Tab(menu.tab) or menu.TABS[1]
end

local function CurrentPage()
    local def = CurrentTab()
    return def and def.page
end

-- A tab's page, built the first time it shows
local function PageOf(def)
    local page = def and def.page
    if page and not built[def.key] then
        built[def.key] = true
        page:Build(menu.body)
    end
    return page
end

local function Build()
    if frame then return end
    local f = UI.Window("ImprovedForeverConfigFrame", W, H, true)
    -- Above every other window (chat, the gamepad bars...), so nothing
    -- shows through the panel's text
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    -- Where it sits: as the game's own panels (and the Library), along the
    -- top beside the open windows, again as they come and go (Focus.lua)
    IF.Focus.Dock(f)
    -- (its own focus glow, as the game's windows: it has the pad while up)
    IF.Focus.Glow(f, true)
    f.onClose = function() menu.Close() end
    frame = f

    -- The stage: the window under its title; the body in its middle
    local stage = K.NewFrame("Frame", nil, f)
    stage:SetPoint("TOPLEFT", 6, -24)
    stage:SetPoint("BOTTOMRIGHT", -6, 6)
    menu.stage = stage
    menu.body = K.NewFrame("Frame", nil, stage)
    menu.body:SetPoint("CENTER", stage, "CENTER", 0, 0)
    menu.body:SetSize(BODY_W, BODY_H)

    f.tabs = UI.SideTabs(f, function(key) menu.SetTab(key) end)

    -- Under the window: a short message, then the pad's hints (each a
    -- button: a click presses it)
    f.legend = UI.Legend(f)
    f.toast = K.ChatText(f, 13, KC.grey)
    f.toast:SetPoint("BOTTOM", f.legend, "TOP", 0, 6)
    f.toast:SetJustifyH("CENTER")
    f.hintRow = K.NewFrame("Frame", nil, f.legend)
    f.hintRow:SetSize(1, 30)
    f.hintRow:SetPoint("CENTER", f.legend, "CENTER", 0, 0)
    f.hints = {}

    f:SetScript("OnUpdate", function() menu.OnUpdate() end)
    -- The panel takes both sticks while it is open (the camera and the
    -- character stay still): a page may point with one (the wheel editor),
    -- else the right one moves through the tabs, the left one the page's lists
    if f.EnableGamePadStick then
        f:EnableGamePadStick(true)
        f:SetScript("OnGamePadStick", function(_, stick, x, y, len)
            local page = CurrentPage()
            -- (a page may take a stick: its OnStick answers true)
            if page and page.OnStick and page:OnStick(stick, x, y, len) then return end
            if stick == "Right" or stick == "Camera" then
                menu.rightY = y or 0
            elseif stick == "Left" or stick == "Movement" then
                menu.leftX, menu.leftY = x or 0, y or 0
            end
        end)
    end
    menu.CreateInput()
end

function menu.SetTab(key)
    local def = Tab(key)
    if not def then return end
    if key == menu.tab and menu.IsOpen() then return menu.Render() end
    menu.Disarm()
    local old = CurrentPage()
    if old and menu.tab ~= key and built[menu.tab] then old:Hide() end
    menu.tab = key
    IF.db.menuTab = key
    PageOf(def):Show()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
    menu.Render()
end

function menu.StepTab(delta)
    local index = 1
    for i, def in ipairs(menu.TABS) do
        if def.key == menu.tab then index = i end
    end
    menu.SetTab(menu.TABS[(index - 1 + delta) % #menu.TABS + 1].key)
end

function menu.Render()
    if not menu.IsOpen() then return end
    local f = frame
    local def = CurrentTab()
    f:SetTitle(IF.TITLE .. ": " .. def.label)
    f.tabs:Render(menu.TABS, def.key)
    local page = CurrentPage()
    page:Render()

    -- The legend: the page's buttons, then the tabs'
    local hints = page:Help() or {}
    if menu.armed then hints = { K.H({ "A" }, "Confirm", "A"), K.H({ "B" }, "Cancel", "B") } end
    if IF.Recorder and IF.Recorder.IsActive() then hints = IF.Recorder.Hints() end
    -- (with the mouse: none on a page whose presses all have a click, as
    -- the game's mouse windows have none)
    local mouseless = not IF.Input.Pad() and page.mouseLegend == false
    f.legend:SetShown(not mouseless)
    if mouseless then hints = {} end
    local x = 0
    for i, hint in ipairs(hints) do
        local h = f.hints[i]
        if not h then
            h = K.Hint(f.hintRow, menu.Press, { glyph = 26, font = 12, color = KC.title })
            f.hints[i] = h
        end
        h:Set(hint)
        h:ClearAllPoints()
        h:SetPoint("LEFT", f.hintRow, "LEFT", x, 0)
        x = x + h:GetWidth() + 16
    end
    for i = #hints + 1, #f.hints do f.hints[i]:Hide() end
    local rowW = math.max(1, x - 16)
    f.legend:SetWidth(math.max(500, rowW + 40))

    -- (a page showing the message itself, ShowsToast: none over the legend)
    local text, color = "", KC.grey
    local page = CurrentPage()
    if menu.toast and not (page and page.ShowsToast) then text, color = menu.toast.text, menu.toast.color end
    f.toast:SetText(text)
    f.toast:SetTextColor(unpack(color))
end

---------------------------------------------------------------------------
-- Pad input while open: hidden buttons bound with priority
---------------------------------------------------------------------------
local NAV = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT", ESCAPE = "B",
    PADBACK = "TOUCH",
}
-- Held triggers may add modifiers to the keys
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local REPEAT = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

function menu.Press(name)
    local page = CurrentPage()
    if not page then return end
    -- A touchpad click: the page may read where the finger is
    if name == "TOUCH" then
        if page.OnTouch then page:OnTouch() end
        return
    end
    -- (recording a press: Circle, or the legend's cancel clicked, stops it)
    if name == "B" and IF.Recorder and IF.Recorder.IsActive() then return IF.Recorder.Finish(true) end
    -- A destructive button armed: Cross does it, Circle cancels, a move lets it go
    if menu.armed then
        if name == "B" then
            menu.Disarm()
            return menu.Render()
        end
        if name == "LB" or name == "RB" then return end
        if name ~= "A" then menu.Disarm() end
    end
    if page:Press(name) then return end
    -- (the tabs are the right stick's: L1 / R1 change nothing here)
    if name == "B" then menu.Close() end
end

function menu.CreateInput()
    for key, name in pairs(NAV) do
        local b = K.NewFrame("Button", "ImprovedForeverConfigPad" .. key)
        b:SetSize(1, 1)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetScript("OnClick", function(_, _, down)
            -- Circle acts on release: closing on the press would leave the
            -- release to the game alone
            if name == "B" then
                if down == false then menu.Press(name) end
                return
            end
            if down == false then
                if menu.repeatName == name then menu.repeatName = nil end
                return
            end
            if REPEAT[name] then
                menu.repeatName, menu.repeatKey, menu.repeatAt = name, key, GetTime() + 0.35
            end
            menu.Press(name)
        end)
    end
end

local function BindKey(key)
    local name = "ImprovedForeverConfigPad" .. key
    if key == "ESCAPE" then
        SetOverrideBindingClick(frame, true, key, name)
    else
        for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(frame, true, prefix .. key, name) end
    end
end

-- A button still held (the one that opened the panel) is taken only once
-- released: its release belongs to the game, which saw it pressed
function menu.BindPad()
    if InCombatLockdown() or not frame then return end
    ClearOverrideBindings(frame)
    menu.heldKeys = {}
    for key in pairs(NAV) do
        if key ~= "ESCAPE" and IsKeyDown and IsKeyDown(key) then
            menu.heldKeys[key] = true
        else
            BindKey(key)
        end
    end
end

function menu.UnbindPad()
    menu.heldKeys = nil
    if frame and not InCombatLockdown() then ClearOverrideBindings(frame) end
end

-- The sticks, as the auction window reads them: the right one tilted up /
-- down steps through the tabs (once a tilt), the left one up / down the
-- page's list (repeating while held)
local rightHeld, leftNext, sideHeld = false, nil, false
local function Sticks(now)
    local page = CurrentPage()
    local ry = menu.rightY or 0
    if page and page.TakesRightStick and page:TakesRightStick() then ry = 0 end
    if not rightHeld and math.abs(ry) > STICK_ON then
        rightHeld = true
        menu.StepTab(ry > 0 and -1 or 1)
    elseif rightHeld and math.abs(ry) < STICK_OFF then
        rightHeld = false
    end
    local lx, ly = menu.leftX or 0, menu.leftY or 0
    if page and page.StickSide then
        local side = lx > STICK_ON and 1 or lx < -STICK_ON and -1 or 0
        if side ~= 0 and not sideHeld and math.abs(lx) > math.abs(ly) then
            sideHeld = true
            menu.Disarm()
            page:StickSide(side)
            menu.Render()
        elseif math.abs(lx) < STICK_OFF then
            sideHeld = false
        end
    end
    if not (page and page.StickStep) then return end
    local dir = math.abs(ly) < math.abs(lx) and 0 or ly > STICK_ON and -1 or ly < -STICK_ON and 1 or 0
    if dir == 0 then
        if math.abs(ly) < STICK_OFF then leftNext = nil end
    elseif not leftNext or now >= leftNext then
        leftNext = now + (leftNext and STEP_EVERY or STEP_DELAY)
        menu.Disarm()
        page:StickStep(dir)
        menu.Render()
    end
end

function menu.OnUpdate()
    if menu.heldKeys and next(menu.heldKeys) and not InCombatLockdown() then
        for key in pairs(menu.heldKeys) do
            if not IsKeyDown(key) then
                menu.heldKeys[key] = nil
                BindKey(key)
            end
        end
    end
    -- Its release went elsewhere (the game rebound the pad): over
    if menu.repeatName and IsKeyDown and menu.repeatKey and not IsKeyDown(menu.repeatKey) then
        menu.repeatName = nil
    end
    if menu.repeatName and GetTime() >= menu.repeatAt then
        menu.repeatAt = GetTime() + 0.08
        menu.Press(menu.repeatName)
    end
    if not (IF.Recorder and IF.Recorder.IsActive()) then Sticks(GetTime()) end
end

---------------------------------------------------------------------------
-- Open / close: back on the last tab
---------------------------------------------------------------------------
-- (the pad or the mouse taken up: the legend and the cursor for it; a
-- key binding changed: the fields that show one)
IF.Input.OnChange(function() menu.Render() end)
local rebind = CreateFrame("Frame")
rebind:RegisterEvent("UPDATE_BINDINGS")
rebind:SetScript("OnEvent", function() menu.Render() end)

function menu.Open(tab)
    if InCombatLockdown() then
        IF.Print("the panel opens after combat.")
        return
    end
    if #menu.TABS == 0 then
        IF.Print("no module with settings is loaded (enable one in the AddOns list).")
        return
    end
    Build()
    if menu.IsOpen() then
        if tab then menu.SetTab(tab) end
        return
    end
    local key = tab or IF.db.menuTab
    if not Tab(key or "") then key = menu.TABS[1].key end
    menu.tab = key
    IF.db.menuTab = key
    menu.Disarm()
    menu.rightY, menu.leftX, menu.leftY = 0, 0, 0
    frame:Show()
    PageOf(CurrentTab()):Show()
    menu.BindPad()
    menu.Render()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end

function menu.Close()
    if not menu.IsOpen() then return end
    menu.Disarm()
    CurrentPage():Hide()
    menu.UnbindPad()
    frame:Hide()
    menu.repeatName = nil
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
end

function menu.Toggle()
    if menu.IsOpen() then
        menu.Close()
    else
        menu.Open()
    end
end

-- Target of the "Toggle Improved Forever panel" key binding (and the
-- touchpad's "Improved Forever panel" region)
IF.Actions.PressButton("ImprovedForeverMenuToggle", function() menu.Toggle() end)
BINDING_HEADER_IMPROVEDFOREVER = IF.TITLE
_G["BINDING_NAME_CLICK ImprovedForeverMenuToggle:LeftButton"] = "Toggle Improved Forever panel"

-- Combat closes the panel (its bindings can only change out of combat;
-- PLAYER_REGEN_DISABLED comes just before the lockdown); spellbook and bag
-- changes redraw it
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        return menu.Close()
    end
    menu.Render()
end)

-- Another controller in hand (or /if buttons): its buttons
IF.OnPadStyleChanged(function() menu.Render() end)

-- The controller's Menu / Options button pressed twice quickly opens this
-- panel (once still opens the game's own menu wheel: the button is only
-- watched, never taken). The game's wheel, opened by the first press, is
-- closed. Out of combat; off with IF.db.menuDouble = false (Bindings tab).
local DOUBLE = 0.35
local menuKey = CreateFrame("Frame")
local wasDown, lastPress = false, 0
menuKey:SetScript("OnUpdate", function()
    if not IsKeyDown then return end
    local down = IsKeyDown("PADFORWARD")
    if down and not wasDown then
        local now = GetTime()
        if now - lastPress <= DOUBLE then
            lastPress = 0
            if IF.db and IF.db.menuDouble ~= false and not InCombatLockdown() and not menu.IsOpen() then
                -- (on the next frame: the game handles the press first)
                C_Timer.After(0, function()
                    local radial = _G.GamepadRadial
                    if radial and radial:IsShown() then radial:Hide() end
                    if not InCombatLockdown() then menu.Open() end
                end)
            end
        else
            lastPress = now
        end
    end
    wasDown = down
end)
