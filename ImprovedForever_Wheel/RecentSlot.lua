-- The R3 slot, beside the game's gamepad action bar: the most recent action
-- used from the wheel of the R3 combo held right now (none held: R3's own
-- wheel; L1 held: L1 + R3's...), with its buttons under it. R3 twice (the
-- same combo held) uses it again (Ring.lua).
local IF = ImprovedForever

local K = IF.ConfigKit

local SIZE = 46   -- until a game action button is found to match
local COMBO_BUTTONS = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local COMBO_GLYPHS = {
    R3 = { "RS" }, L1 = { "LB", "+", "RS" }, L2 = { "LT", "+", "RS" }, R1 = { "RB", "+", "RS" }, R2 = { "RT", "+", "RS" },
}

local function HasAtlas(name)
    return IF.HasAtlas and IF.HasAtlas(name)
end

local slot = K.NewFrame("Frame", "ImprovedForeverRecentSlot", UIParent)
slot:SetSize(SIZE, SIZE)
slot:SetFrameStrata("LOW")
slot:Hide()

local bg = slot:CreateTexture(nil, "BACKGROUND")
bg:SetPoint("CENTER")
bg:SetSize(SIZE + 6, SIZE + 6)
if HasAtlas("gamepad-actionbar-circleslot-bg") then
    bg:SetAtlas("gamepad-actionbar-circleslot-bg")
else
    bg:SetColorTexture(0, 0, 0, 0.5)
end

local icon = K.RoundIcon(slot, SIZE - 8, "ARTWORK")
icon:SetPoint("CENTER")

local frame = slot:CreateTexture(nil, "OVERLAY")
frame:SetPoint("CENTER")
frame:SetSize(SIZE + 10, SIZE + 10)
if HasAtlas("gamepad-actionbar-circleslot-frame") then frame:SetAtlas("gamepad-actionbar-circleslot-frame") end

local count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", -2, 2)

local glyphs = K.GlyphRow(slot, 22)
local label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", slot, "TOP", 0, 4)
label:SetWidth(110)
label:SetWordWrap(false)

-- The Immersion module's spell diamonds shown (ImprovedForever_Immersion,
-- GamepadBar.lua): the slot one of their tiles instead (their look and
-- effects: cooldown, cast and food rings, GB.Mirror over a stand-in for a
-- game button), placed left of their D-pad's diamond. Returns their bar's
-- module, the frame to anchor to, x, y and the tile's sizes, or nil.
local function Diamonds()
    local IN = IF.Interface
    local GB = IN and IN.GamepadBar
    if not (GB and GB.SideSpot and GB.Tile and GB.Mirror and GB.StandIn) then return nil end
    local anchor, x, y, d = GB.SideSpot()
    if not anchor then return nil end
    return GB, anchor, x, y, d
end

local tile, standIn, tileCount
local diamond = false
local glyphScale = 1
local STICK_BIG = 1.6            -- (R3 / L3's glyph, bigger than a face button's)

-- (the round look or the tile; the slot the tile's size)
local function Look(GB, d)
    diamond = GB ~= nil
    if diamond and not tile then
        tile = GB.Tile(slot, slot, d, { 0, 0 })
        tile:EnableMouse(false)
    end
    bg:SetShown(not diamond)
    frame:SetShown(not diamond)
    count:SetShown(not diamond)
    if tile then tile:SetShown(diamond) end
    if diamond then
        slot:SetSize(d.width, d.width)
        glyphScale = d.glyph / 22 * STICK_BIG   -- (the row is built at 22; the stick's glyph draws small in its square)
    end
end

-- A stand-in for the recent action (its spell's or item's cooldown and
-- cast; greyed when none of its item is left)
local function StandIn(GB, recent, n)
    local spellID, itemID, spellName
    if recent.type == "item" then
        itemID = tonumber((recent.value or ""):match("^item:(%d+)"))
    elseif recent.type == "spell" then
        spellName = recent.value
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellName)
        spellID = recent.spellID or (type(info) == "table" and info.spellID) or nil
    end
    local s = GB.StandIn(recent.icon or 134400, spellID, itemID, spellName)
    if n == 0 then s.icon.r, s.icon.g, s.icon.b = 0.4, 0.4, 0.4 end
    return s
end

-- The same size as the game's own gamepad action buttons, measured on
-- screen (other addons may resize them): the first shown action button
-- under its bar
local sample
local function FindButton(frame, depth)
    if depth > 6 then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        local name = child:GetName()
        if child:IsShown() and child:IsObjectType("CheckButton") and name and name:find("ActionButton")
            and child:GetWidth() > 0 then
            return child
        end
        local found = child:IsShown() and FindButton(child, depth + 1)
        if found then return found end
    end
end

-- Where and how big, per Edit Mode layout (IF.db.recentSlotLayouts[key] =
-- { x, y (its centre, from the screen's bottom left), scale (of the game
-- buttons' size), alpha, hideName }); none: beside the game's bar, its
-- buttons' size. While Edit Mode is open, changes go to a working copy:
-- kept by its Save (or closing it), dropped by its Revert All Changes.
local function Copy(t)
    local c = {}
    for k, v in pairs(t or {}) do c[k] = v end
    return c
end

local function LayoutKey()
    local m = _G.EditModeManagerFrame
    local info = m and m.GetActiveLayoutInfo and m:GetActiveLayoutInfo()
    if not info then return "default" end
    if info.layoutName and info.layoutName ~= "" then return "layout:" .. info.layoutName end
    local index = m.layoutInfo and m.layoutInfo.activeLayout
    return "preset:" .. tostring(index or info.layoutType or 0)
end

local working
local function Saved()
    IF.db.recentSlotLayouts = IF.db.recentSlotLayouts or {}
    local key = LayoutKey()
    local all = IF.db.recentSlotLayouts
    -- (a layout seen first starts from the one set before layouts were kept)
    if not all[key] then all[key] = Copy(IF.db.recentSlot) end
    return all[key]
end

local function Layout()
    return working or Saved()
end

-- The working copy kept as the layout's
local function SetLayoutSaved()
    IF.db.recentSlotLayouts = IF.db.recentSlotLayouts or {}
    IF.db.recentSlotLayouts[LayoutKey()] = working
    working = nil
end

local function SetLayout(t)
    if working then
        working = t
    else
        IF.db.recentSlotLayouts = IF.db.recentSlotLayouts or {}
        IF.db.recentSlotLayouts[LayoutKey()] = t
    end
end

local size
local function Resize(force)
    if diamond then
        size = nil
        return
    end
    local bar = _G.GamepadMainActionBarFrame
    if not (sample and sample:IsShown() and sample:IsVisible()) then
        sample = bar and bar:IsShown() and FindButton(bar, 0) or nil
    end
    local want = SIZE
    if sample then
        want = sample:GetWidth() * sample:GetEffectiveScale() / slot:GetEffectiveScale()
    end
    want = math.floor(want * (Layout().scale or 1) + 0.5)
    if (want == size and not force) or want < 8 then return end
    size = want
    slot:SetSize(size, size)
    bg:SetSize(size * 1.13, size * 1.13)
    icon:SetSize(size * 0.83, size * 0.83)
    frame:SetSize(size * 1.22, size * 1.22)
    glyphs:SetScale(math.max(0.3, size / 46 * (Layout().glyphScale or 1)))
end

-- The crossbar's right edge and the middle of its rightmost bar, in screen
-- pixels, or nil. Read from the bars' anchors (fixed in place) and their
-- expanded half width, not the buttons: those grow and move while L2 / R2
-- is held. The compact layout stacks every anchor on the bottom one, the
-- full one spreads them (the right bar past the main frame's edge).
-- (ActionBarStyles.lua: its one style's expanded size, 266 x 86; the
-- style table itself is local there, appliedStyle only its id)
local BAR_EXPANDED_WIDTH = 266
local ANCHORS = { "TopCenteredAnchor", "BottomCenteredAnchor", "LeftCenteredAnchor", "RightCenteredAnchor" }
local function BarsRight(main)
    local unit = main.PageUnit
    if not unit then return nil end
    local right, y, n
    for _, key in ipairs(ANCHORS) do
        local anchor = unit[key]
        local shown
        for _, child in ipairs(anchor and { anchor:GetChildren() } or {}) do
            if child:IsShown() then shown = child break end
        end
        local cx, cy
        if shown then cx, cy = anchor:GetCenter() end
        if cx and cy then
            local s = anchor:GetEffectiveScale()
            local edge, mid = (cx + BAR_EXPANDED_WIDTH / 2) * s, cy * s
            if not right or edge > right + 0.5 then
                right, y, n = edge, mid, 1
            elseif edge > right - 0.5 then
                y, n = y + mid, n + 1   -- (level with it: their middle)
            end
        end
    end
    return right, right and y / n
end

-- Beside the game's bar (right of its rightmost bar), else bottom right of
-- the middle. Set again only when it moved (it's checked every update).
local placed
local function Place()
    local main = _G.GamepadMainActionBarFrame
    local layout = Layout()
    local where
    local _, anchor, ax, ay = Diamonds()
    if anchor and not slot.editing then
        where = { "CENTER", anchor, ax, ay, "CENTER" }
    elseif layout.x then
        where = { "CENTER", "BOTTOMLEFT", layout.x, layout.y }
    elseif main and main:IsShown() then
        local right, y = BarsRight(main)
        if right then
            local s = slot:GetEffectiveScale()
            where = { "LEFT", "BOTTOMLEFT", math.floor(right / s + 6.5), math.floor(y / s + 0.5) }
        else
            where = { "LEFT", main, 6, -20, "RIGHT" }
        end
    else
        where = { "BOTTOM", "BOTTOM", 360, 120 }
    end
    if placed and placed[1] == where[1] and placed[2] == where[2]
        and placed[3] == where[3] and placed[4] == where[4] then
        return
    end
    placed = where
    slot:ClearAllPoints()
    if type(where[2]) == "table" then
        slot:SetPoint(where[1], where[2], where[5], where[3], where[4])
    else
        slot:SetPoint(where[1], UIParent, where[2], where[3], where[4])
    end
end

local function HeldCombo()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return "R3" end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local buttons = state and state.buttons
    if not buttons then return "R3" end
    for _, combo in ipairs({ "L1", "R1", "L2", "R2" }) do
        local index = C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(COMBO_BUTTONS[combo])
        if index and buttons[index + 1] then return combo end -- (buttons: 1-based)
    end
    return "R3"
end

local function ItemCount(value)
    local id = type(value) == "string" and tonumber(value:match("^item:(%d+)"))
    if not id then return nil end
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    return get and get(id) or 0
end

local shownCombo
local function Refresh(force)
    if not IF.db then return end
    -- (only with gamepad mode on in the game's options: R3 is the pad's;
    -- while being placed, still)
    if not IF.Input.PadEnabled() and not slot.editing then
        shownCombo = nil
        slot:Hide()
        return
    end
    local combo = HeldCombo()
    if combo == shownCombo and not force then return end
    shownCombo = combo
    local wheel = IF.GetComboRing(combo)
    if not wheel or wheel == "native" then
        -- Nothing on this combo: R3 alone's wheel then, else hidden
        wheel = IF.GetComboRing("R3")
        combo = "R3"
        if (not wheel or wheel == "native") and not slot.editing then
            slot:Hide()
            return
        end
    end
    local GB, _, _, _, d = Diamonds()
    Look(GB, d)
    Place()
    slot:Show()
    Resize()
    slot:SetAlpha(Layout().alpha or 1)
    label:SetShown(not Layout().hideName and not diamond)
    glyphs:SetShown(not Layout().hideGlyphs)
    if diamond then glyphs:SetScale(math.max(0.3, glyphScale * (Layout().glyphScale or 1))) end
    local recent = IF.RecentAction(wheel)
    icon:SetShown(recent ~= nil and not diamond)
    standIn, tileCount = nil, ""
    if recent then
        K.SetIcon(icon, recent.icon or 134400)
        local n = recent.type == "item" and ItemCount(recent.value)
        count:SetText(n and n > 1 and n or "")
        icon:SetDesaturated(n == 0)
        if diamond then
            standIn = StandIn(GB, recent, n)
            tileCount = n and n > 1 and tostring(n) or ""
        end
        -- (a group member's: who holds the token now, Group.lua)
        if recent.unit and IF.GroupWheel then
            label:SetText((IF.GroupWheel.Look(recent.unit)))
        else
            label:SetText(recent.label or "")
        end
    else
        count:SetText("")
        label:SetText("|cff9d917a" .. (IF.RING_LABELS[wheel] or "") .. "|r")
    end
    -- Its buttons under it: the combo, R3 twice
    local keys = COMBO_GLYPHS[combo]
    local w = glyphs:Set(keys) or 0
    glyphs:ClearAllPoints()
    if diamond then
        -- (as the other tiles' glyphs: above it, its count inside)
        glyphs:SetPoint("BOTTOMLEFT", slot, "TOP", -w / 2, 4)
    else
        glyphs:SetPoint("TOPLEFT", slot, "BOTTOM", -w / 2, -4)
    end
end

IF.RecentChanged = function() Refresh(true) end

local elapsed = 0
local sinceResize = 0
slot:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    sinceResize = sinceResize + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    Refresh(false)
    -- (the Immersion module's diamonds shown or not: the look swapped; its
    -- tile's effects each update, as theirs)
    local GB = Diamonds()
    if (GB ~= nil) ~= diamond then Refresh(true) end
    if diamond and tile and GB then
        GB.Mirror(tile, standIn)
        tile.count:SetText(tileCount or "")
    end
    -- (the game's bars move: its compact layout on / off, a bar shown...)
    if not slot.editing then Place() end
    -- (another addon may resize the game's buttons any time)
    if sinceResize >= 1 then
        sinceResize = 0
        Resize()
    end
end)

-- The OnUpdate above only runs while it shows: a small watcher brings it
-- back when a combo gets a wheel again
local watcher = CreateFrame("Frame")
local wait = 0
watcher:SetScript("OnUpdate", function(_, dt)
    wait = wait + dt
    if wait < 0.5 or slot:IsShown() then return end
    wait = 0
    Refresh(true)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
-- (gamepad mode turned on / off in the game's options)
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function() Refresh(true) end)
IF.OnLogin(function() Refresh(true) end)
IF.OnPadStyleChanged(function() Refresh(true) end)
IF.Input.OnChange(function() Refresh(true) end)

---------------------------------------------------------------------------
-- Edit mode: while the game's own Edit Mode is open, the slot shows its
-- blue selection and can be dragged and resized there (the mouse wheel;
-- right click: back beside the bar at the buttons' size), kept as the game
-- keeps its layout. RS.Edit() also edits it from the pad alone: left stick
-- / D-pad move, L1 / R1 resize, Triangle resets, Cross keeps, Circle undoes.
---------------------------------------------------------------------------
local RS = {}
IF.RecentSlot = RS

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 2, 0.05
local MOVE_STEP, STICK_SPEED = 2, 420

-- The game's edit mode selection: its blue nine-slice look
local sel = K.NewFrame("Frame", nil, slot)
sel:SetPoint("TOPLEFT", -8, 8)
sel:SetPoint("BOTTOMRIGHT", 8, -8)
sel:SetFrameLevel(slot:GetFrameLevel() + 10)
sel:Hide()
local fill = sel:CreateTexture(nil, "BACKGROUND")
fill:SetAllPoints()
if not (IF.HasAtlas("editmode-actionbar-selected-nineslice-center")
    and fill:SetAtlas("editmode-actionbar-selected-nineslice-center") ~= false) then
    fill:SetColorTexture(0.25, 0.55, 1, 0.35)
end
for _, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 }, { "BOTTOMLEFT", 0, 1, 1, 0 },
    { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
    local t = sel:CreateTexture(nil, "BORDER")
    t:SetSize(16, 16)
    t:SetPoint(c[1])
    if IF.HasAtlas("editmode-actionbar-selected-nineslice-corner") then
        t:SetAtlas("editmode-actionbar-selected-nineslice-corner")
        t:SetTexCoord(c[2], c[3], c[4], c[5])
    end
end
local selName = sel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
selName:SetPoint("CENTER")
selName:SetText(IF.ButtonName("RS"))

-- The help bar while editing, at the screen's bottom
local help = K.NewFrame("Frame", nil, UIParent, "BackdropTemplate")
help:SetFrameStrata("DIALOG")
help:SetPoint("BOTTOM", 0, 40)
help:SetHeight(40)
help:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
help:SetBackdropColor(0.05, 0.04, 0.03, 0.92)
help:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
help:Hide()
local helpText = help:CreateFontString(nil, "OVERLAY", "GameFontNormal")
helpText:SetPoint("CENTER")

local function Glyph(key) return IF.GlyphText(key, 22) end

local before
local function ShowHelp()
    local pct = math.floor((Layout().scale or 1) * 100 + 0.5)
    helpText:SetText(Glyph("LS") .. " / " .. Glyph("DPAD") .. " Move    " .. Glyph("LB") .. " / " .. Glyph("RB")
        .. " Size " .. pct .. "%    " .. Glyph("Y") .. " Reset    " .. Glyph("A") .. " Save    " .. Glyph("B") .. " Cancel")
    help:SetWidth(helpText:GetStringWidth() + 32)
end

-- Pinned where it is now (so moving starts from there)
local function Pin()
    local layout = Layout()
    if layout.x then return end
    local x, y = slot:GetCenter()
    local s = slot:GetEffectiveScale() / UIParent:GetEffectiveScale()
    layout.x, layout.y = x * s, y * s
end

local function Move(dx, dy)
    Pin()
    local layout = Layout()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    layout.x = math.max(0, math.min(w, layout.x + dx))
    layout.y = math.max(0, math.min(h, layout.y + dy))
    Place()
end

local function Scale(step)
    local layout = Layout()
    local v = math.floor(((layout.scale or 1) + step) * 100 + 0.5) / 100
    v = math.max(SCALE_MIN, math.min(SCALE_MAX, v))
    layout.scale = v ~= 1 and v or nil
    Resize(true)
    ShowHelp()
    if RS.SettingsShown and RS.SettingsShown() then RS.RefreshSettings() end
end

-- Takes the pad while editing
local pad = K.NewFrame("Frame", nil, UIParent)
pad:SetAllPoints(UIParent)
pad:Hide()
local stick = { x = 0, y = 0 }
local repeatKey, repeatAt

local function Stop(save)
    if not slot.editing then return end
    slot.editing = nil
    if not save and before then
        SetLayout(before)
    end
    before = nil
    pad:Hide()
    if pad.EnableGamePadButton and not IF.InCombat() then
        pad:EnableGamePadButton(false)
        pad:EnableGamePadStick(false)
        pad:EnableKeyboard(false)
    end
    help:Hide()
    sel:Hide()
    slot:EnableMouse(false)
    slot:SetMovable(false)
    Place()
    Resize(true)
    Refresh(true)
end

local PRESS = {
    PADDUP = function() Move(0, MOVE_STEP) end, PADDDOWN = function() Move(0, -MOVE_STEP) end,
    PADDLEFT = function() Move(-MOVE_STEP, 0) end, PADDRIGHT = function() Move(MOVE_STEP, 0) end,
    PADLSHOULDER = function() Scale(-SCALE_STEP) end, PADRSHOULDER = function() Scale(SCALE_STEP) end,
    PAD4 = function()
        SetLayout({})
        Place()
        Resize(true)
        ShowHelp()
    end,
}

if pad.EnableGamePadButton then
    pad:SetScript("OnGamePadButtonDown", function(_, button)
        if PRESS[button] then
            PRESS[button]()
            repeatKey, repeatAt = button, GetTime() + 0.35
        end
    end)
    -- Save / cancel on the release, so the release doesn't reach the game
    pad:SetScript("OnGamePadButtonUp", function(_, button)
        if button == repeatKey then repeatKey = nil end
        if button == "PAD1" then Stop(true)
        elseif button == "PAD2" then Stop(false) end
    end)
    pad:SetScript("OnGamePadStick", function(_, name, x, y)
        if name == "Left" or name == "Move" then stick.x, stick.y = x, y end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    pad:EnableGamePadButton(false)
end
pad:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then Stop(false)
    elseif key == "ENTER" then Stop(true) end
end)
pad:SetScript("OnUpdate", function(_, dt)
    local x, y = stick.x or 0, stick.y or 0
    if x * x + y * y > 0.04 then Move(x * STICK_SPEED * dt, y * STICK_SPEED * dt) end
    if repeatKey and IsKeyDown(repeatKey) and GetTime() >= repeatAt then
        repeatAt = GetTime() + 0.05
        if PRESS[repeatKey] and repeatKey ~= "PAD4" then PRESS[repeatKey]() end
    elseif repeatKey and not IsKeyDown(repeatKey) then
        repeatKey = nil
    end
    if InCombatLockdown() then Stop(false) end
end)

-- The mouse: drag to move, the wheel to resize
local downAt
slot:SetScript("OnMouseDown", function(self, button)
    if not self.editing or button ~= "LeftButton" then return end
    Pin()
    placed = nil   -- (dragging moves it: set again after)
    downAt = { self:GetCenter() }
    self:StartMoving()
end)
slot:SetScript("OnMouseWheel", function(self, delta)
    if self.editing then Scale(delta * SCALE_STEP) end
end)
slot:SetScript("OnMouseUp", function(self, button)
    if not self.editing then return end
    self:StopMovingOrSizing()
    if button == "RightButton" then
        RS.Reset()
        return
    end
    local x, y = self:GetCenter()
    local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
    Layout().x, Layout().y = x * s, y * s
    Place()
    -- A click (not a drag): its settings, as the game's Edit Mode does
    if downAt and math.abs(x - downAt[1]) < 3 and math.abs(y - downAt[2]) < 3 then RS.ShowSettings() end
    downAt = nil
end)

-- passive: inside the game's Edit Mode (it has the pad): the mouse only,
-- every change kept
function RS.Edit(passive)
    if IF.InCombat() or slot.editing then return false end
    if not passive and IF.Menu and IF.Menu.Close then IF.Menu.Close() end
    before = not passive and (CopyTable and CopyTable(Layout()) or { x = Layout().x, y = Layout().y, scale = Layout().scale }) or nil
    slot.editing = passive and "native" or "pad"
    stick.x, stick.y = 0, 0
    Refresh(true)
    slot:Show()
    sel:Show()
    selName:SetText(IF.ButtonName("RS"))
    slot:EnableMouse(true)
    slot:SetMovable(true)
    slot:SetClampedToScreen(true)
    if slot.EnableMouseWheel then slot:EnableMouseWheel(true) end
    if passive then return true end
    pad:Show()
    if pad.EnableGamePadButton then
        pad:EnableGamePadButton(true)
        pad:EnableGamePadStick(true)
    end
    pad:EnableKeyboard(true)
    pad:SetPropagateKeyboardInput(false)
    ShowHelp()
    help:Show()
    return true
end

function RS.Reset()
    SetLayout({})
    Place()
    Resize(true)
end

function RS.Describe()
    local layout = Layout()
    local pct = math.floor((layout.scale or 1) * 100 + 0.5)
    return (layout.x and "Moved" or "Beside the action bar") .. " · " .. pct .. "% of the game's buttons"
end

-- The game's Edit Mode: in it, the slot can be moved and resized too
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if not IF.db then return end
        working = Copy(Saved())
        RS.Edit(true)
    end, RS)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if working then
            SetLayoutSaved()
        end
        if slot.editing == "native" then Stop(true) end
    end, RS)
    -- Its Save: the working copy kept
    EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
        if working then
            SetLayoutSaved()
            working = Copy(Saved())
        end
    end, RS)
end

---------------------------------------------------------------------------
-- Its settings in Edit Mode, in the game's own settings dialog look
-- (EditModeSystemSettingsDialog): size and opacity sliders, the name
-- shown or not, Revert Changes, Reset To Default Position
---------------------------------------------------------------------------
local dialog
local opened   -- the layout when the dialog opened (Revert Changes)

local function SliderRow(parent, text, y, min, max, step, get, set, fmt)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(343, 32)
    row:SetPoint("TOP", 0, y)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    row.Label:SetSize(100, 32)
    row.Label:SetPoint("LEFT")
    row.Label:SetJustifyH("LEFT")
    row.Label:SetText(text)
    local ok, slider = pcall(CreateFrame, "Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    if not ok then return row end
    slider:SetSize(200, 32)
    slider:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
    local formatters = {}
    if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin then
        formatters[MinimalSliderWithSteppersMixin.Label.Right] =
            CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
    end
    local last
    function row:Refresh()
        last = get()
        slider:Init(last, min, max, (max - min) / step, formatters)
    end
    -- (its callback, and the inner slider's own change as a fallback)
    local function changed(value)
        if type(value) ~= "number" or value == last then return end
        last = value
        set(value)
    end
    if slider.RegisterCallback and MinimalSliderWithSteppersMixin then
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            changed(value)
        end, row)
    end
    if slider.Slider then
        slider.Slider:HookScript("OnValueChanged", function(_, value) changed(value) end)
    end
    row.slider = slider
    return row
end

local function Build()
    dialog = CreateFrame("Frame", "ImprovedForeverRecentSlotSettings", UIParent)
    dialog:SetSize(380, 384)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()
    local okBorder, border = pcall(CreateFrame, "Frame", nil, dialog, "DialogBorderTranslucentTemplate")
    if okBorder then border:SetAllPoints() end
    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText(IF.ButtonName("RS") .. " Slot")
    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() dialog:Hide() end)

    dialog.rows = {
        SliderRow(dialog, "Size", -50, 50, 200, 5,
            function() return math.floor((Layout().scale or 1) * 100 + 0.5) end,
            function(v)
                v = v / 100
                Layout().scale = math.abs(v - 1) > 0.001 and v or nil
                Resize(true)
            end,
            function(v) return math.floor(v + 0.5) .. "%" end),
        SliderRow(dialog, "Opacity", -86, 20, 100, 5,
            function() return math.floor((Layout().alpha or 1) * 100 + 0.5) end,
            function(v)
                v = v / 100
                Layout().alpha = v < 0.999 and v or nil
                slot:SetAlpha(v)
            end,
            function(v) return math.floor(v + 0.5) .. "%" end),
        SliderRow(dialog, "Icon Size", -122, 50, 200, 5,
            function() return math.floor((Layout().glyphScale or 1) * 100 + 0.5) end,
            function(v)
                v = v / 100
                Layout().glyphScale = math.abs(v - 1) > 0.001 and v or nil
                Resize(true)
            end,
            function(v) return math.floor(v + 0.5) .. "%" end),
    }

    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(32, 32)
    check:SetPoint("TOPLEFT", 20, -160)
    local checkText = check.text or check.Text or check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    checkText:ClearAllPoints()
    checkText:SetPoint("LEFT", check, "RIGHT", 6, 0)
    checkText:SetFontObject("GameFontHighlightMedium")
    checkText:SetText("Show Action Name")
    check:SetScript("OnClick", function(self)
        Layout().hideName = not self:GetChecked() or nil
        label:SetShown(not Layout().hideName and not diamond)
    glyphs:SetShown(not Layout().hideGlyphs)
    end)
    dialog.check = check

    -- The button icons under it (the combo, R3)
    local iconsCheck = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    iconsCheck:SetSize(32, 32)
    iconsCheck:SetPoint("TOPLEFT", 20, -196)
    local iconsText = iconsCheck.text or iconsCheck.Text or iconsCheck:CreateFontString(nil, "ARTWORK")
    iconsText:ClearAllPoints()
    iconsText:SetPoint("LEFT", iconsCheck, "RIGHT", 6, 0)
    iconsText:SetFontObject("GameFontHighlightMedium")
    iconsText:SetText("Show Button Icons")
    iconsCheck:SetScript("OnClick", function(self)
        Layout().hideGlyphs = not self:GetChecked() or nil
        glyphs:SetShown(not Layout().hideGlyphs)
    end)
    dialog.iconsCheck = iconsCheck

    local revert = CreateFrame("Button", nil, dialog, "EditModeSystemSettingsDialogButtonTemplate")
    revert:SetPoint("TOPLEFT", 20, -248)
    revert:SetText(HUD_EDIT_MODE_REVERT_CHANGES or "Revert Changes")
    revert:SetScript("OnClick", function()
        if opened then SetLayout(Copy(opened)) end
        Place()
        Resize(true)
        label:SetShown(not Layout().hideName and not diamond)
    glyphs:SetShown(not Layout().hideGlyphs)
        dialog:Refresh()
    end)

    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(330, 28)
    reset:SetPoint("TOP", 0, -310)
    reset:SetText(HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position")
    reset:SetScript("OnClick", function()
        local layout = Layout()
        layout.x, layout.y = nil, nil
        Place()
    end)

    function dialog:Refresh()
        for _, row in ipairs(self.rows) do
            if row.Refresh then row:Refresh() end
        end
        self.check:SetChecked(not Layout().hideName)
        self.iconsCheck:SetChecked(not Layout().hideGlyphs)
    end
end

function RS.SettingsShown() return dialog and dialog:IsShown() end
function RS.RefreshSettings() if dialog then dialog:Refresh() end end

function RS.ShowSettings()
    if not dialog then Build() end
    opened = Copy(Layout())
    dialog:ClearAllPoints()
    -- Beside the slot, on the side with room, as the game's dialog sits
    local x = slot:GetCenter()
    if x and x > UIParent:GetWidth() / 2 then
        dialog:SetPoint("BOTTOMRIGHT", slot, "TOPLEFT", -20, 20)
    else
        dialog:SetPoint("BOTTOMLEFT", slot, "TOPRIGHT", 20, 20)
    end
    dialog:Refresh()
    dialog:Show()
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if dialog then dialog:Hide() end
    end, dialog or RS.ShowSettings)
end

local function Apply()
    Place()
    Resize(true)
    slot:SetAlpha(Layout().alpha or 1)
    label:SetShown(not Layout().hideName and not diamond)
    glyphs:SetShown(not Layout().hideGlyphs)
    if RS.SettingsShown() then RS.RefreshSettings() end
end

local manager = _G.EditModeManagerFrame
if manager then
    -- Revert All Changes: back to the layout as saved
    if manager.RevertAllChanges then
        hooksecurefunc(manager, "RevertAllChanges", function()
            if working then working = Copy(Saved()) end
            Apply()
        end)
    end
    -- Another layout: its own place and size
    if manager.SelectLayout then
        hooksecurefunc(manager, "SelectLayout", function()
            if working then working = Copy(Saved()) end
            Apply()
        end)
    end
end
local layoutEvents = CreateFrame("Frame")
layoutEvents:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
layoutEvents:SetScript("OnEvent", function()
    if IF.db and not working then Apply() end
end)

-- The game's Save / Revert All Changes buttons light up while the slot has
-- unsaved changes too, as for its own frames (only the buttons' state is
-- touched: Edit Mode's own change tracking is left alone, so its saving is
-- never tainted)
local FIELDS = { "x", "y", "scale", "alpha", "hideName", "hideGlyphs", "glyphScale" }
local function Dirty()
    if not working then return false end
    local saved = Saved()
    for _, k in ipairs(FIELDS) do
        local a, b = working[k], saved[k]
        if type(a) == "number" and type(b) == "number" then
            if math.abs(a - b) > 0.01 then return true end
        elseif a ~= b then
            return true
        end
    end
    return false
end

local function UpdateSaveButtons()
    if not (manager and Dirty()) then return end
    if manager.SaveChangesButton then manager.SaveChangesButton:SetEnabled(true) end
    if manager.RevertAllChangesButton then manager.RevertAllChangesButton:SetEnabled(true) end
end

if manager and manager.SetHasActiveChanges then
    -- (the game turns them off when its own frames have no changes)
    hooksecurefunc(manager, "SetHasActiveChanges", UpdateSaveButtons)
end
local dirtyWatch = CreateFrame("Frame")
local dirtyWait = 0
dirtyWatch:SetScript("OnUpdate", function(_, dt)
    dirtyWait = dirtyWait + dt
    if dirtyWait < 0.2 then return end
    dirtyWait = 0
    if working then UpdateSaveButtons() end
end)

