-- Our windows' gamepad focus, as the game's own windows show and pass it
-- (Blizzard_SharedXMLBase FocusEffects.lua, Blizzard_GamepadSharedUtility
-- FrameControlsManager.lua):
--
-- * The glow: the window's own FrameGlow (DefaultPanelFlatTemplate and
--   PortraitFrameTemplate have it, laid out for the template, in the focus
--   colour and opacity of the game's controller options), shown while the
--   window has the pad. Never a copy of its atlas: the game's is drawn
--   untinted until those options change, a copy never looks the same.
-- * L2 / R2: the game's windows' row (the frame manager's shownFrames, left
--   to right; L2 the previous, R2 the next). Ours takes its place in it by
--   where it sits on screen. The pad goes to the game's window that still
--   has the game's focus (the one it was opened from: the game can't be
--   handed another without taint) by L2 when that's on our left, R2 on our
--   right; and comes back by the other trigger, pressed on that window or
--   the next one along towards ours (the game has none that way for it:
--   watched, not taken).
-- * While ours has the pad, the game's focus (its cursor, the focused
--   window's glow and legend) is dimmed, so only ours shows.
--
-- The manager is only read: its Focus* calls from addon code taint the
-- game's window closing (SetPreferredGamepadInteractTarget).
local _, IF = ...

local F = {}
IF.Focus = F

function F.Manager()
    return _G.GamepadMode and GamepadMode.FrameControlsManager or nil
end

local function Shown(f)
    return f and f.IsShown and f:IsShown() and f.GetCenter and f:GetCenter() and f or nil
end
F.Shown = Shown

-- The window's own focus glow, on or off
function F.Glow(win, on)
    local glow = win and win.FrameGlow
    if glow then glow:SetShown(on and true or false) end
end

-- (screen x of a window's centre, in UIParent's units)
local function CenterX(f)
    local x = f:GetCenter()
    return x * f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function InRow(f)
    local m = F.Manager()
    for _, g in ipairs(m and m.shownFrames or {}) do
        if g == f then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The game's focus dimmed while ours has the pad. Each owner (one of our
-- windows) keeps what it dimmed, and puts it back.
---------------------------------------------------------------------------
local dims = {}

local function Dim(list, f)
    if f and f.SetAlpha and f:GetAlpha() > 0 then
        list[#list + 1] = f
        f:SetAlpha(0)
    end
end

-- A game window's glow and legend
local function DimWindow(list, f)
    if not f then return end
    local ok, root = pcall(function() return f.GetFocusFrameRoot and f:GetFocusFrameRoot() end)
    root = ok and root or f
    Dim(list, root.FrameGlow)
    if root ~= f then Dim(list, f.FrameGlow) end
    for _, w in ipairs({ f, root }) do
        for _, child in ipairs({ w:GetChildren() }) do
            local name = child.GetName and child:GetName()
            if name and name:find("inputLegend$") and child:IsShown() then Dim(list, child) end
        end
    end
end

-- hide: dim the game's cursor, its focused window, the bags and the loot
-- window, and extra (more game windows); else put them back
function F.DimNative(owner, hide, extra)
    local list = dims[owner] or {}
    dims[owner] = list
    -- (what was dimmed before back first: another window may be focused now)
    for _, f in ipairs(list) do f:SetAlpha(1) end
    wipe(list)
    if not hide then return end
    local nav = _G.SmartNavigation
    Dim(list, nav and nav.Pointer)
    local m = F.Manager()
    DimWindow(list, m and m.focusedFrame)
    DimWindow(list, _G.ContainerFrameCombinedBags)
    DimWindow(list, _G.LootFrame)
    for i = 1, NUM_CONTAINER_FRAMES or 13 do DimWindow(list, _G["ContainerFrame" .. i]) end
    for _, f in ipairs(extra or {}) do DimWindow(list, f) end
end

---------------------------------------------------------------------------
-- The switch between one of our windows and the game's: F.Switch(win, opts)
--   opts.other():  one of ours (not in the game's row) the pad goes to
--                  when it's up; else the game's focused window, else the
--                  last in its row
--   opts.label(f): its legend label (default: its jump hint label, else
--                  the game's Previous / Next)
--   opts.onChange(focus): after the pad moved ("ours" / "game")
-- sw.focus: "ours" or "game"; sw:Behind() -> label, key ("LT" / "RT");
-- sw:Press(key): a trigger pressed on ours (true: handled);
-- sw:Update(): from ours' OnUpdate; sw:Set(focus)
---------------------------------------------------------------------------
local Switch = {}
Switch.__index = Switch

function F.Switch(win, opts)
    return setmetatable({ win = win, opts = opts or {}, focus = "ours",
        held = { LT = true, RT = true } }, Switch)
end

function Switch:Other()
    local mine = self.opts.other and Shown(self.opts.other())
    if mine then return mine end
    local m = F.Manager()
    local focused = m and Shown(m.focusedFrame)
    if focused and focused ~= self.win and InRow(focused) then return focused end
    local frames = m and m.shownFrames
    local last = frames and Shown(frames[#frames])
    return last ~= self.win and last or nil
end

function Switch:LeftOfUs(f)
    return Shown(self.win) and CenterX(f) < CenterX(self.win) or false
end

function Switch:Behind()
    local f = self:Other()
    if not f then return nil end
    local key = self:LeftOfUs(f) and "LT" or "RT"
    local label = self.opts.label and self.opts.label(f)
    if not label then
        local ok, l = pcall(function() return f.GetJumpHintLabel and f:GetJumpHintLabel() end)
        label = ok and l or nil
    end
    if not label then label = key == "LT" and (_G.PREVIOUS or "Previous") or (_G.NEXT or "Next") end
    return label, key
end

-- The legend's entry for it ({ button, key, label }), or nil
function Switch:Hint()
    local label, key = self:Behind()
    if not label then return nil end
    return { key == "LT" and "PADLTRIGGER" or "PADRTRIGGER", key, label }
end

function Switch:Set(focus)
    if focus == self.focus or IF.InCombat() then return end
    if focus == "game" and not self:Other() then return end
    self.focus = focus
    self.held.LT, self.held.RT = true, true
    self.before = nil
    if self.opts.onChange then self.opts.onChange(focus) end
end

function Switch:Press(key)
    local _, toward = self:Behind()
    if not toward or key ~= toward then return false end
    self:Set("game")
    return true
end

-- Whether f is the game's window next to ours on its side (nothing of the
-- game's row between them)
function Switch:NextToUs(f)
    if not (Shown(f) and Shown(self.win)) then return false end
    local m = F.Manager()
    local ux, fx = CenterX(self.win), CenterX(f)
    for _, g in ipairs(m and m.shownFrames or {}) do
        if g ~= f and g ~= self.win and Shown(g) then
            local gx = CenterX(g)
            if (gx > fx and gx < ux) or (gx < fx and gx > ux) then return false end
        end
    end
    return true
end

local TRIGGERS = { LT = "PADLTRIGGER", RT = "PADRTRIGGER" }

function Switch:Update()
    if self.focus ~= "game" then return end
    -- (no window left to have the pad: back to ours)
    local other = self:Other()
    if not other then return self:Set("ours") end
    local mine = not InRow(other)
    local m = F.Manager()
    -- (the window that had the pad when the trigger went down: the game
    -- moves its focus on the same press)
    local was = self.before
    self.before = m and m.isUIFocused and Shown(m.focusedFrame) or nil
    for key, button in pairs(TRIGGERS) do
        local down = IsKeyDown and IsKeyDown(button) or false
        local fresh = down and not self.held[key] and not IF.InCombat()
        self.held[key] = down
        if fresh then
            local from = mine and other or was
            -- (towards ours: L2 from a window on its right, R2 from one on its left)
            local towards = from and (key == "LT") == not self:LeftOfUs(from)
            if towards and (mine or self:NextToUs(from)) then return self:Set("ours") end
        end
    end
end

---------------------------------------------------------------------------
-- Where a side window of ours sits: as the game's own panels
-- (UIParentPanelManager.lua), along the top. Nothing open: the first
-- panel's place (the Professions window's: "left", xoffset 35); the game's
-- windows open (Professions, Character...) or ours along the top: beside
-- the last of them, the game's spacing between. Worked out the same way
-- rather than handed to the game's panel manager (an addon's panel there
-- taints it), and again as windows come and go.
--   F.Dock(win): placed so while shown (ours opened earlier first)
--   F.AlongTop(win): ours placed otherwise but counted (the auction window)
---------------------------------------------------------------------------
local PANEL_X, BOTTOM_CLAMP, MIN_Y = 35, 140, -10
local MAX_HANG = 400       -- the most a window's side parts reach past it
local SLOTS = { "left", "center", "right", "doublewide" }
-- (not along the top: the bags, the loot window)
local NOT_ALONG_TOP = { ContainerFrameCombinedBags = true, LootFrame = true }

local docked, alongTop = {}, {}
local shownOrder = 0

local function Layout(name, default)
    local layout = _G.UIPanelLayoutFrame
    return tonumber(layout and layout:GetAttribute(name)) or default
end

-- A window's right edge as the game lays it out (UIParent's units): with
-- its extra width (Character's side tabs) and what hangs off its right side
-- (a stats pane)
local function RightEdge(f)
    local ui = UIParent:GetEffectiveScale()
    local left, r = f:GetLeft() or 0, f:GetRight()
    local ok, w = pcall(function() return GetUIPanelWidth and GetUIPanelWidth(f) end)
    if ok and type(w) == "number" and w > 0 then r = math.max(r, left + w / f:GetScale()) end
    local extra = f.GetAttribute and tonumber(f:GetAttribute("UIPanelLayout-extraWidth"))
    if extra and extra > 0 then r = math.max(r, f:GetRight() + extra / f:GetScale()) end
    for _, c in ipairs({ f:GetChildren() }) do
        local cl, cr = c:IsShown() and c:GetLeft(), c:IsShown() and c:GetRight()
        if cl and cr and cl >= left and cl <= r + 8 and cr > r and cr - r < MAX_HANG
            and (c:GetHeight() or 0) > 40 and c:GetEffectiveScale() == f:GetEffectiveScale() then
            r = cr
        end
    end
    return r * f:GetEffectiveScale() / ui
end

-- The right edge of what's open along the top before win, or nil
local function TakenRight(win)
    local right
    local seen = {}
    local function edge(f)
        if not (f and f ~= win and not seen[f] and f.IsShown and f:IsShown() and f.GetRight and f:GetRight()) then
            return
        end
        seen[f] = true
        local name = f.GetName and f:GetName() or ""
        if NOT_ALONG_TOP[name] or name:find("^ContainerFrame%d") then return end
        right = math.max(right or 0, RightEdge(f))
    end
    for _, slot in ipairs(SLOTS) do edge(GetUIPanel and GetUIPanel(slot)) end
    local m = F.Manager()
    for _, f in ipairs(m and m.shownFrames or {}) do edge(f) end
    for f in pairs(alongTop) do edge(f) end
    local mine = docked[win] and docked[win].order or math.huge
    for f, d in pairs(docked) do
        if d.order and d.order < mine then edge(f) end
    end
    return right
end

function F.Place(win)
    local d = docked[win]
    if not d then return end
    local scale = win:GetScale()
    local right = TakenRight(win)
    local x = right and (right + Layout("PANEl_SPACING_X", 32)) or (Layout("LEFT_OFFSET", 16) + PANEL_X)
    -- (no room past them: as far right as it fits)
    x = math.min(x, (UIParent:GetWidth() or x) - win:GetWidth() * scale)
    local y = Layout("TOP_OFFSET", -116)
    local bottom = (UIParent:GetTop() or 0) + y - win:GetHeight() * scale
    if bottom < BOTTOM_CLAMP then y = y + (BOTTOM_CLAMP - bottom) end
    y = math.min(y, MIN_Y)
    if d.at and math.abs(d.at[1] - x) < 0.5 and math.abs(d.at[2] - y) < 0.5 then return end
    d.at = { x, y }
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
end

function F.AlongTop(win)
    alongTop[win] = true
end

-- (again as windows come and go: every docked window shown, a few times a second)
local driver = CreateFrame("Frame")
local nextPlace = 0
driver:SetScript("OnUpdate", function()
    local now = GetTime()
    if now < nextPlace then return end
    nextPlace = now + 0.2
    for f, d in pairs(docked) do
        if d.order and f:IsShown() then F.Place(f) end
    end
end)

function F.Dock(win)
    if docked[win] then return end
    docked[win] = {}
    win:HookScript("OnShow", function()
        local d = docked[win]
        shownOrder = shownOrder + 1
        d.order, d.at = shownOrder, nil
        F.Place(win)
    end)
    win:HookScript("OnHide", function()
        local d = docked[win]
        d.order, d.at = nil, nil
    end)
    if win:IsShown() then
        shownOrder = shownOrder + 1
        docked[win].order = shownOrder
    end
end

---------------------------------------------------------------------------
-- The focus indicator: the game's gamepad cursor (SmartNavigation's
-- Pointer: its large arrow, in GAMEPAD_SMARTNAV_CURSOR_COLOR, left of what
-- the pad is on), copied from the live one where it's there: its atlas, its
-- size on screen, its animation, its offset from the button.
--   F.CursorTexture(tex): tex made the game's cursor (sized as it's shown)
--   F.Cursor(parent) -> cur: cur:Point(target) beside target; cur:Hide()
-- It shows only where the pad is: in a window of ours with its focus glow on
---------------------------------------------------------------------------
local CURSOR_ATLAS, CURSOR_W, CURSOR_H, CURSOR_SCALE = "gamepad-largecursor", 42, 70, 0.8

local function NativeCursor()
    local nav = _G.SmartNavigation
    local icon = nav and nav.Pointer and nav.Pointer.Icon
    return icon and icon.Cursor or nil, nav
end

local function CursorColor(tex)
    local c = _G.GAMEPAD_SMARTNAV_CURSOR_COLOR
    if c and c.GetRGBA then tex:SetVertexColor(c:GetRGBA()) else tex:SetVertexColor(1, 0.82, 0.2) end
end

-- Its size: the game's on screen, in tex's units
local function CursorSize(tex)
    local native = NativeCursor()
    local w, h = native and tonumber(native:GetWidth()), native and tonumber(native:GetHeight())
    local ns, ts = native and tonumber(native:GetEffectiveScale()), tonumber(tex:GetEffectiveScale())
    if w and h and ns and ts and w > 0 and h > 0 then
        local k = ns / math.max(0.01, ts)
        tex:SetSize(w * k, h * k)
    else
        tex:SetSize(CURSOR_W * CURSOR_SCALE, CURSOR_H * CURSOR_SCALE)
    end
end

-- Its animation: the game's (IntroAnim) copied, else a slow bob towards
-- what it points at
local function CursorAnim(tex)
    local _, nav = NativeCursor()
    local intro = nav and nav.Pointer and nav.Pointer.IntroAnim
    local group = tex:CreateAnimationGroup()
    local copied = false
    if intro and intro.GetAnimations then
        group:SetLooping(intro:GetLooping() or "NONE")
        for _, a in ipairs({ intro:GetAnimations() }) do
            local kind = a:GetObjectType()
            local ok, b = pcall(group.CreateAnimation, group, kind)
            if ok and b then
                copied = true
                b:SetDuration(a:GetDuration())
                b:SetOrder(a:GetOrder())
                if a.GetSmoothing then b:SetSmoothing(a:GetSmoothing()) end
                if a.GetStartDelay then b:SetStartDelay(a:GetStartDelay()) end
                if kind == "Translation" then b:SetOffset(a:GetOffset())
                elseif kind == "Alpha" then b:SetFromAlpha(a:GetFromAlpha()); b:SetToAlpha(a:GetToAlpha())
                elseif kind == "Scale" then b:SetScaleFrom(a:GetScaleFrom()); b:SetScaleTo(a:GetScaleTo())
                end
            end
        end
    end
    if not copied then
        group:SetLooping("REPEAT")
        for i, dx in ipairs({ 4, -4 }) do
            local t = group:CreateAnimation("Translation")
            t:SetOffset(dx, 0)
            t:SetDuration(0.8)
            t:SetSmoothing("IN_OUT")
            t:SetOrder(i)
        end
    end
    return group
end

function F.CursorTexture(tex)
    local native = NativeCursor()
    local atlas = native and native.GetAtlas and native:GetAtlas()
    if not (IF.HasAtlas and IF.HasAtlas(atlas or CURSOR_ATLAS)) then atlas = nil end
    if atlas or (IF.HasAtlas and IF.HasAtlas(CURSOR_ATLAS)) then
        tex:SetAtlas(atlas or CURSOR_ATLAS)
    else
        tex:SetTexture("Interface\\AddOns\\ImprovedForever\\textures\\ic_tri")
        tex:SetRotation(math.pi / 2)
    end
    CursorColor(tex)
    CursorSize(tex)
    local anim = CursorAnim(tex)
    tex.cursorAnim = anim
    -- (sized and lit again each time it shows: the game's may have changed)
    return tex
end

-- The top window of ours a frame is in
local function TopWindow(f)
    while f and f.GetParent and f:GetParent() and f:GetParent() ~= UIParent do f = f:GetParent() end
    return f
end

function F.Cursor(parent)
    local cur = CreateFrame("Frame", nil, parent)
    cur:SetSize(10, 10)
    cur:SetFrameLevel(parent:GetFrameLevel() + 6)
    local arrow = cur:CreateTexture(nil, "OVERLAY", nil, 2)
    arrow:SetPoint("RIGHT", cur, "RIGHT", 0, 0)
    F.CursorTexture(arrow)
    cur.arrow = arrow
    cur:Hide()
    cur:SetScript("OnShow", function()
        CursorColor(arrow)
        CursorSize(arrow)
        arrow.cursorAnim:Play()
    end)
    cur:SetScript("OnHide", function()
        arrow.cursorAnim:Stop()
    end)
    -- (only where the pad is: its window glowing, when it has a glow)
    cur:SetScript("OnUpdate", function(self)
        local win = TopWindow(self)
        local glow = win and win.FrameGlow
        self:SetAlpha((glow and not glow:IsShown()) and 0 or 1)
    end)
    function cur:Point(target, dx, dy)
        local _, nav = NativeCursor()
        self:ClearAllPoints()
        self:SetPoint("RIGHT", target, "LEFT", dx or (nav and nav.cursorOffsetX) or 0, dy or (nav and nav.cursorOffsetY) or 0)
        self:Show()
    end
    return cur
end
