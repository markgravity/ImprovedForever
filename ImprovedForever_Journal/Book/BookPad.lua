-- The book with the pad, as every window of ours that takes it (Focus.lua):
-- its frame's own focus glow while it has the pad, the game's focus dimmed
-- meanwhile, L2 / R2 to the game's window and back, placed as the game's
-- panels are (IF.Focus.Dock), a catcher frame for the buttons, Escape and
-- Circle on their release, the legend under it (with the mouse its
-- buttons on the page). The D-pad: up / down the days (or the people),
-- left / right the open day's words a page at a time; L1 / R1 the ribbons; Cross on
-- a companion reads the last day we met. Never in combat. The Journal's
-- entry points: IF.JournalBook.Open(key), .Toggle().
local addonName, ns = ...
local IF = ImprovedForever
local Jn = IF.Journal

local Style = ns.Style
local J = ns.UI.Journal
local BP = ns.BookPages
local JB = IF.JournalBook

local focus = "ours"
local panel, catcher, legend, switch

function BP.PadOn()
    return IF.Input.Pad() and focus == "ours" and panel and panel:IsShown()
end

local VIEWS = { "journey", "people" }

local function View() return ns.UI.JournalView() end

local function Turn(step)
    local view = View()
    for i, key in ipairs(VIEWS) do
        if key == view then
            local nxt = VIEWS[(i - 1 + step) % #VIEWS + 1]
            J.TurnTo(nxt)
            return
        end
    end
    J.TurnTo(VIEWS[1])
end

---------------------------------------------------------------------------
-- The legend
---------------------------------------------------------------------------
local hintSets = {}
local function SetHints(defs)
    local key = {}
    for _, d in ipairs(defs) do key[#key + 1] = tostring(d[1]) .. "=" .. tostring(d[3]) end
    key = table.concat(key, "|")
    hintSets[key] = hintSets[key] or defs
    legend:Set(hintSets[key])
end

local function Hints()
    local defs = {}
    if View() == "people" then
        defs[#defs + 1] = { "PAD1", "A", "Last Day Met", pad = true }
    else
        defs[#defs + 1] = { { "PADDLEFT", "PADDRIGHT" }, { "LEFT", "RIGHT" }, "Turn the Words", pad = true }
    end
    defs[#defs + 1] = { { "PADLSHOULDER", "PADRSHOULDER" }, { "LB", "RB" }, View() == "people" and "Diary" or "Companions", pad = true }
    local hint = switch and switch:Hint()
    if hint then defs[#defs + 1] = hint end
    -- (the pad's own: with the mouse, the book's close button in its corner)
    defs[#defs + 1] = { "PAD2", "B", "Close", pad = true }
    return defs
end

local function Render()
    if not (panel and panel:IsShown()) then return end
    local ours = focus == "ours"
    IF.Focus.Glow(panel, ours)
    if ours then SetHints(Hints()) else legend:Hide() end
    -- (the cursor on the picked row follows the pad)
    if View() == "people" then
        if BP.people.listFrame then BP.people.listFrame:Refresh() end
    elseif BP.diary.list then
        BP.diary.list:Refresh()
    end
end
BP.RenderPad = Render

---------------------------------------------------------------------------
-- The buttons
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
    PADLTRIGGER = "LT", PADRTRIGGER = "RT",
}

local skipRelease

local function Close()
    if panel and panel:IsShown() then Style.PlaySound("sheetClose") end
    ns.UI.CloseJournal()
end

local function Press(name, down)
    -- (Circle on its release: on the press the release goes to the window
    -- under it)
    if name == "B" then
        if not down then
            if skipRelease then skipRelease = nil return end
            Close()
        end
        return
    end
    if not down then return end
    local people = View() == "people"
    if name == "UP" or name == "DOWN" then
        local step = name == "UP" and -1 or 1
        if people then BP.PeopleMove(step) else BP.DiaryMove(step) end
    elseif name == "LEFT" or name == "RIGHT" then
        if not people then BP.DiaryTurn(name == "LEFT" and -1 or 1) end
    elseif name == "LB" or name == "RB" then
        Turn(name == "RB" and 1 or -1)
    elseif name == "LT" or name == "RT" then
        switch:Press(name)
    elseif name == "A" and people then
        local c = BP.people.list and BP.people.list[BP.people.sel]
        local last
        for key in pairs(c and c.p.days or {}) do
            if Jn.Day(key) and (not last or key > last) then last = key end
        end
        if last then BP.ToDay(last) end
    end
    Render()
end

local function TakePad(on)
    if catcher and catcher.EnableGamePadButton and not IF.InCombat() then
        catcher:EnableGamePadButton(on and true or false)
    end
end

local escape = CreateFrame("Button", "ImprovedForeverJournalEscape")
escape:RegisterForClicks("AnyUp")
escape:SetScript("OnClick", function() Close() end)

local function BindEscape(on)
    if IF.InCombat() or not panel then return end
    ClearOverrideBindings(panel)
    if on then SetOverrideBindingClick(panel, true, "ESCAPE", escape:GetName()) end
end

---------------------------------------------------------------------------
-- Made once, as the book is built
---------------------------------------------------------------------------
local function Attach(frame)
    panel = frame
    -- Placed as the game's own panels are, beside what's open
    IF.Focus.Dock(panel)

    catcher = CreateFrame("Frame", nil, panel)
    catcher:SetAllPoints(panel)
    if catcher.EnableGamePadButton then
        catcher:SetScript("OnGamePadButtonDown", function(_, button)
            if KEYS[button] then Press(KEYS[button], true) end
        end)
        catcher:SetScript("OnGamePadButtonUp", function(_, button)
            if KEYS[button] then Press(KEYS[button], false) end
        end)
        -- (setting the handler turns the frame's input on: off until wanted)
        catcher:EnableGamePadButton(false)
    end

    legend = IF.InputLegend(panel)
    legend:SetPoint("TOP", panel, "BOTTOM", 0, -2)
    legend:SetPress(catcher)
    -- (with the mouse its buttons on the right page's foot)
    legend.row:ClearAllPoints()
    legend.row:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -40, 26)

    switch = IF.Focus.Switch(panel, {
        onChange = function(f)
            local ours = f == "ours"
            focus = ours and "ours" or "game"
            TakePad(ours)
            BindEscape(ours)
            IF.Focus.DimNative(panel, ours)
            Render()
        end,
    })

    panel:HookScript("OnShow", function()
        switch.focus, focus = "ours", "ours"
        TakePad(true)
        BindEscape(true)
        IF.Focus.DimNative(panel, true)
        skipRelease = IsKeyDown and IsKeyDown("PAD2") or nil
        Render()
    end)
    panel:HookScript("OnHide", function()
        TakePad(false)
        BindEscape(false)
        IF.Focus.DimNative(panel, false)
        IF.Focus.Glow(panel, false)
        legend:Hide()
    end)
    panel:HookScript("OnUpdate", function() switch:Update() end)
    if panel.close then panel.close:SetScript("OnClick", Close) end
end

-- (the book is built on its first opening: attached then)
local showJournal = ns.UI.ShowJournal
ns.UI.ShowJournal = function(...)
    if IF.InCombat() then return IF.Print("Not in combat.") end
    local was = J.journal and J.journal:IsShown()
    showJournal(...)
    if not was then Style.PlaySound("sheetOpen") end
    if not panel and J.journal then
        Attach(J.journal)
        Render()
    end
end

-- (a ribbon turned: the legend and the cursor for that page)
local setView = ns.UI.SetJournalView
ns.UI.SetJournalView = function(...)
    setView(...)
    Render()
end

IF.Input.OnChange(function() Render() end)

-- Combat: the book is put away; after it, what couldn't be undone in it
-- (the catcher's input, Escape's binding: protected in combat) is
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if not panel then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if panel:IsShown() then ns.UI.CloseJournal() end
    elseif not panel:IsShown() then
        TakePad(false)
        BindEscape(false)
    end
end)

---------------------------------------------------------------------------
-- The Journal's entry points
---------------------------------------------------------------------------
-- key: a day ("YYYY-MM-DD") to open at; nil: as it was left
function JB.Open(key)
    if IF.InCombat() then return IF.Print("Not in combat.") end
    if key then BP.diary.open = key end
    J.view = "journey"
    ns.UI.ShowJournal()
    if key then BP.OpenDay(key, true) end
end

function JB.Toggle()
    if panel and panel:IsShown() then return Close() end
    if IF.InCombat() then return IF.Print("Not in combat.") end
    ns.UI.ShowJournal()
end

-- (today, as it goes on: once a moment)
local pending = false
Jn.OnChange(function()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        BP.Changed()
    end)
end)

-- The press that opens it: a key binding, a wheel's or the touchpad's
-- (the core's windows of ours, Actions.lua)
IF.Actions.PressButton("ImprovedForeverJournalToggle", function() JB.Toggle() end)
_G["BINDING_NAME_CLICK ImprovedForeverJournalToggle:LeftButton"] = "Toggle Journal"
