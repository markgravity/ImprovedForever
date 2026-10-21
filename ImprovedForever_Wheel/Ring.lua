-- R3 rings. Press R3 (optionally holding L1/L2/R1/R2) to open a ring, point
-- at a slot with the right stick (the pick stays when it springs back; the
-- left stick still walks, as with the native radial) or step with the
-- D-pad, then press R2 to use it. Circle closes. L1/R1 switch wheels,
-- D-pad left / right its pages: every ring is cut into pages of eight, like
-- Forever's native radial menu (GamepadRadial), whose art and layout the
-- ring copies. Square (out of combat) puts the picked slot on the crossbar
-- with a bind panel like the game's (BindPanel.lua), when it can go there.
--
-- It works in combat: every button is a secure button. R3's snippet reads
-- the pad (GetGamePadState) to pick the combo; the stick directions arrive
-- as keys (GamePadStickAxisButtons, switched on while the ring is up) and
-- update the pick; R2 copies the picked slot's action onto itself. Ring
-- contents are rebuilt out of combat only, so loot from a fight shows up
-- afterwards.
local IF = ImprovedForever

-- Measured from GamepadRadial with /if probe.
local WHEEL_WIDTH, WHEEL_HEIGHT = 540, 541
local SLOT_RADIUS = 150  -- wedges (highlight / empty)
local ICON_SIZE = 38     -- as the native menu's (texture) icons

-- A slot's icon and label, as Forever's radial lays its segments out
-- (GamepadRadial): segments 150 out (112, 112 on a diagonal), an icon 20
-- in from there, its label off the icon by 60 straight out (sides) or
-- 30 across and 45 up / down (diagonals). dx, dy: the slot's direction (y
-- up); returns icon x, y and label x, y from the wheel's centre.
function IF.SlotLayout(dx, dy)
    local diagonal = math.abs(dx) > 0.3 and math.abs(dy) > 0.3
    local reach = (diagonal and 112 * math.sqrt(2) or 150) - 20
    local ix, iy = dx * reach, dy * reach
    local lx, ly
    if diagonal then
        lx, ly = (dx > 0 and 30 or -30), (dy > 0 and 45 or -45)
    else
        lx, ly = dx * 60, dy * 60
    end
    return ix, iy, ix + lx, iy + ly
end
local SLOTS_PER_PAGE = 8
local PICK_LENGTH_SQ = 0.25 -- stick must be at least half way out
local KEY = "PADRSTICK"
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
local COMBO_BUTTONS = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local AXIS_CVAR = "GamePadStickAxisButtons"

local ringData = {}
-- The chords an action is on (trigger "ic-act-<chord>"), to clear them
local actChords = {}
local rebuildPending, bindingsPending = false, false

---------------------------------------------------------------------------
-- Secure frames
---------------------------------------------------------------------------

local ring = CreateFrame("Frame", "ImprovedForeverRing", UIParent, "SecureHandlerBaseTemplate")
ring:SetSize(WHEEL_WIDTH, WHEEL_HEIGHT)
-- Where Forever's own radial menu (GamepadRadial) puts its wheel: right of
-- the middle, a little up
ring:SetPoint("CENTER", UIParent, "CENTER", 312, 10)
ring:SetFrameStrata("DIALOG")
ring:Hide()

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not setter then return false end
    local ok, result = pcall(setter, name, value)
    return ok and result ~= false
end

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

-- While the ring is up this child takes the sticks, so the right stick
-- aims without turning the camera. EnableGamePadStick takes both sticks
-- (whatever the handler returns), so the left one walks through bindings
-- instead: its directions arrive as keys (GamePadStickAxisButtons) and the
-- ring binds them to the movement actions while it's up (OnShow below). It
-- shows and hides with the ring, so the secure show / hide drives it in
-- combat too; the pad state the pick reads is unaffected.
local stickCapture = CreateFrame("Frame", nil, ring)
stickCapture:SetAllPoints(ring)
if stickCapture.EnableGamePadStick then
    stickCapture:EnableGamePadStick(true)
    stickCapture:SetScript("OnGamePadStick", function() end)
end

-- After the ring closes (a slot used, Circle) the right stick is often
-- still pushed: the sticks stay taken a moment, until it is back near the
-- middle (at most RELEASE_MAX: the left stick can't walk meanwhile), so the
-- camera doesn't swing round as the ring goes.
local RELEASE_SQ, RELEASE_MAX = 0.2 * 0.2, 0.5
local afterCapture = CreateFrame("Frame", nil, UIParent)
afterCapture:SetAllPoints(UIParent)
afterCapture:SetFrameStrata("DIALOG")
afterCapture:Hide()
if afterCapture.EnableGamePadStick then
    afterCapture:EnableGamePadStick(true)
    afterCapture:SetScript("OnGamePadStick", function() end)
end

local function AimStickPushed()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return false end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local stick = state and state.sticks and state.sticks[ring:GetAttribute("ic-stick") or 0]
    return stick and stick.x and stick.y and stick.x * stick.x + stick.y * stick.y > RELEASE_SQ or false
end

afterCapture:SetScript("OnUpdate", function(self, elapsed)
    self.held = (self.held or 0) + elapsed
    if self.held >= RELEASE_MAX or not AimStickPushed() then self:Hide() end
end)
ring:HookScript("OnHide", function()
    if AimStickPushed() then
        afterCapture.held = 0
        afterCapture:Show()
    end
end)
ring:HookScript("OnShow", function() afterCapture:Hide() end)

-- (the camera-speed hold of an earlier version: put back if left set)
IF.OnLogin(function()
    for name, value in pairs(IF.db.cameraSaved or {}) do SetCVarSafe(name, value) end
    IF.db.cameraSaved = nil
end)

local function SecureButton(name)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    SecureHandlerSetFrameRef(button, "ring", ring)
    return button
end

-- Shared by the snippets: the slot a stick points at, from the stronger of
-- the two sticks, or nil when neither is pushed past `needed`.
ring:SetAttribute("ic-pick-body", [[
    local needed = ...
    local state = GetGamePadState()
    local sticks = state and state.sticks
    if not sticks then
        return nil
    end
    local x, y, lengthSq = 0, 0, 0
    for _, attribute in ipairs(newtable("ic-stick", "ic-stick2")) do
        local stick = sticks[self:GetAttribute(attribute) or 0]
        if stick and stick.x and stick.y and stick.x * stick.x + stick.y * stick.y > lengthSq then
            x, y, lengthSq = stick.x, stick.y, stick.x * stick.x + stick.y * stick.y
        end
    end
    if lengthSq < needed then
        return nil
    end
    local key = self:GetAttribute("ic-active")
    local best, bestDot
    for index = 1, self:GetAttribute(key .. "-count") or 0 do
        local dot = x * self:GetAttribute(key .. "-dx-" .. index) + y * self:GetAttribute(key .. "-dy-" .. index)
        if not bestDot or dot > bestDot then
            best, bestDot = index, dot
        end
    end
    return best
]])

-- Shared by the snippets: put R2 (use), L1 and R1 (wheels) on the ring's
-- buttons. One still held (the combo that opened it: R1 + R3) is taken only
-- once let go: a key's release goes where its binding points by then, and
-- the game's own binding, which got the press, must get it too or it stays
-- down (the crossbar's page, a targeting modifier). `opening`: check all
-- three; else only those still waiting.
ring:SetAttribute("ic-take-pad", [[
    local opening = ...
    if not self:IsShown() then
        return
    end
    local state = GetGamePadState()
    local buttons = state and state.buttons
    local waiting = false
    for _, key in ipairs(newtable("PADRTRIGGER", "PADLSHOULDER", "PADRSHOULDER")) do
        if opening or self:GetAttribute("ic-wait-" .. key) then
            local index = self:GetAttribute("ic-btn-" .. key)
            if buttons and index and buttons[index] then
                self:SetAttribute("ic-wait-" .. key, true)
                waiting = true
            else
                self:SetAttribute("ic-wait-" .. key, nil)
                local target = key == "PADRTRIGGER" and "ImprovedForeverRingUse" or "ImprovedForeverRingPage"
                local click = key == "PADRTRIGGER" and "LeftButton" or key
                for _, modifier in ipairs(newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-")) do
                    self:SetBindingClick(true, modifier .. key, target, click)
                end
            end
        end
    end
    self:SetAttribute("ic-waiting", waiting or nil)
]])

-- R3: open the ring for the held combo. It stays up until R2 uses a slot
-- or Circle closes it. R3 again while it's up, the same combo held (a
-- double click), uses the wheel's most recent action (RecentSlot.lua) and
-- closes it; with another combo held it does nothing. It acts on the press
-- or the release, as action buttons do (ActionButtonUseKeyDown).
local trigger = SecureButton("ImprovedForeverRingTrigger")
trigger:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(trigger, "OnClick", trigger, [[
    local ring = self:GetFrameRef("ring")
    if not down then
        -- The recent action, on the release
        local pending = self:GetAttribute("ic-recent-pending")
        self:SetAttribute("ic-recent-pending", nil)
        if pending then
            self:SetAttribute("type", pending)
            return
        end
        return false
    end
    self:SetAttribute("type", nil)
    self:SetAttribute("ic-recent-pending", nil)
    -- The combo: every shoulder / trigger held ("L1R1"; none: "R3"), and
    -- the first of them alone (L1, R1, L2, R2), what a combo of several
    -- with nothing of its own falls back to
    local chord, single = "", nil
    local state = GetGamePadState()
    local buttons = state and state.buttons
    if buttons then
        for _, name in ipairs(newtable("L1", "L2", "R1", "R2")) do
            local index = self:GetAttribute("ic-btn-" .. name)
            if index and buttons[index] then chord = chord .. name end
        end
        for _, name in ipairs(newtable("L1", "R1", "L2", "R2")) do
            local index = self:GetAttribute("ic-btn-" .. name)
            if not single and index and buttons[index] then single = name end
        end
    end
    if chord == "" then chord = "R3" end
    local combo = single or "R3"
    if ring:IsShown() then
        self:SetAttribute("ic-mode", nil)
        local wheel = ring:GetAttribute((ring:GetAttribute("ic-active") or "") .. "-wheel")
        local actionType = wheel and self:GetAttribute("ic-combo-" .. combo) == wheel
            and ring:GetAttribute("recent-" .. wheel .. "-type")
        if not actionType then
            return false
        end
        ring:Hide()
        -- (said to the insecure side: a gear pick is equipped from there)
        ring:SetAttribute("ic-used-n", (ring:GetAttribute("ic-used-n") or 0) + 1)
        ring:SetAttribute("ic-replay", wheel .. "#" .. ring:GetAttribute("ic-used-n"))
        self:SetAttribute("spell", nil)
        self:SetAttribute("item", nil)
        self:SetAttribute("macrotext", nil)
        -- (a group member's: on the same unit token)
        self:SetAttribute("unit", ring:GetAttribute("recent-" .. wheel .. "-unit"))
        if actionType ~= "target" then
            self:SetAttribute(actionType == "macro" and "macrotext" or actionType,
                ring:GetAttribute("recent-" .. wheel .. "-value"))
        end
        if (self:GetAttribute("ic-keydown") or 1) == 1 then
            self:SetAttribute("type", actionType)
            return
        end
        self:SetAttribute("ic-recent-pending", actionType)
        return false
    end
    -- An action put on this press (the Bindings tab): its macro, on the
    -- press or the release, as the recent action's
    local macro = self:GetAttribute("ic-act-" .. chord)
    if macro then
        self:SetAttribute("ic-mode", nil)
        self:SetAttribute("spell", nil)
        self:SetAttribute("item", nil)
        self:SetAttribute("unit", nil)
        self:SetAttribute("macrotext", macro)
        if (self:GetAttribute("ic-keydown") or 1) == 1 then
            self:SetAttribute("type", "macro")
            return
        end
        self:SetAttribute("ic-recent-pending", "macro")
        return false
    end
    -- (a combo of one, or of several with a wheel of its own)
    if self:GetAttribute("ic-combo-" .. chord) then combo = chord end
    -- A combo another feature has for now (the Destroy panel's, while
    -- the bags are open): left to it
    if self:GetAttribute("ic-skip-" .. combo) then
        self:SetAttribute("ic-mode", nil)
        return false
    end
    local key = self:GetAttribute("ic-combo-" .. combo) or "native"
    self:SetAttribute("ic-mode", key)
    if key ~= "native" then
        ring:SetAttribute("ic-sticky", nil)
        ring:SetAttribute("ic-active", ring:GetAttribute("ic-first-" .. key) or key)
        ring:Show()
    end
    return false
]])

-- Combos left on "native" run R3's normal game binding (Look Here), press
-- and release.
trigger:SetScript("PostClick", function(self, button, down)
    if self:GetAttribute("ic-mode") ~= "native" then
        return
    end
    local action = GetBindingAction(button)
    if action and action ~= "" then
        RunBinding(action, not down and "up" or nil)
    end
end)

-- Key bindings: one button per wheel ("CLICK ImprovedForeverWheel_<key>"
-- in the game's Key Bindings, Bindings.xml) that opens it, or closes it if
-- it is already up. Any key or pad button the player binds works, in combat
-- too.
IF.WHEEL_BINDING_KEYS = { "quest", "consumables", "emotes", "group", "panels", "my1", "my2", "my3", "my4", "my5", "my6",
    "my7", "my8" }
-- (a name kept: Buffs gave its place to Quest Items, and a key or crossbar
-- slot bound to its button opens that now)
local RENAMED = { buffs = "quest" }
local buttonNames = {}
for _, key in ipairs(IF.WHEEL_BINDING_KEYS) do buttonNames[#buttonNames + 1] = key end
for old in pairs(RENAMED) do buttonNames[#buttonNames + 1] = old end
local function MakeOpenButton(name)
    local key = RENAMED[name] or name
    local open = SecureButton("ImprovedForeverWheel_" .. name)
    -- (a key: on its press; a macro's /click ... Macro, on a crossbar slot
    -- (Native.lua): on whichever click it sends)
    open:RegisterForClicks("AnyDown", "AnyUp")
    open:SetAttribute("ic-ring", key)
    SecureHandlerWrapScript(open, "OnClick", open, [[
        if button ~= "Macro" and not down then return false end
        local ring = self:GetFrameRef("ring")
        if ring:IsShown() then
            ring:Hide()
            return false
        end
        local key = self:GetAttribute("ic-ring")
        local first = ring:GetAttribute("ic-first-" .. key)
        if not first then
            return false
        end
        ring:SetAttribute("ic-sticky", nil)
        ring:SetAttribute("ic-active", first)
        ring:Show()
        return false
    ]])
end
for _, name in ipairs(buttonNames) do MakeOpenButton(name) end
-- (a built-in wheel another module adds: MyWheels.lua's IF.AddBuiltInWheel)
function IF.MakeWheelButton(key)
    if not _G["ImprovedForeverWheel_" .. key] then MakeOpenButton(key) end
end

-- Stick directions (as keys): move the sticky pick. A key going down means
-- the stick just left the middle; a key coming up means it is springing
-- back, so only a firm reading counts then.
local aim = SecureButton("ImprovedForeverRingAim")
aim:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(aim, "OnClick", aim, [[
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("ic-waiting") then ring:RunAttribute("ic-take-pad") end
    if ring:IsShown() then
        local pick = ring:RunAttribute("ic-pick-body", down and 0.12 or 0.5)
        if pick then
            ring:SetAttribute("ic-sticky", pick)
        end
    end
    return false
]])

-- D-pad up / down: step the pick round the ring; while a chat phrase is
-- picked, the channel it's said on ("ic-channel": 1 each one's own, then
-- "chan-cmd-<n>"'s, set out of combat); while a group member is (the Group
-- wheel), what a pick does to them ("ic-cast": 1 target, then the spell
-- "cast-spell-<n>").
local step = SecureButton("ImprovedForeverRingStep")
step:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(step, "OnClick", step, [[
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("ic-waiting") then ring:RunAttribute("ic-take-pad") end
    local page = ring:GetAttribute("ic-active")
    local picked = page and ring:IsShown() and (ring:RunAttribute("ic-pick-body", 0.25) or ring:GetAttribute("ic-sticky"))
    local casts = ring:GetAttribute("cast-n") or 1
    if picked and casts > 1 and ring:GetAttribute(page .. "-unit-" .. picked) then
        local c = ring:GetAttribute("ic-cast") or 1
        if button == "PADDUP" then c = (c - 2) % casts + 1 else c = c % casts + 1 end
        ring:SetAttribute("ic-cast", c)
        return false
    end
    if picked and ring:GetAttribute(page .. "-phrase-" .. picked) then
        local n = ring:GetAttribute("chan-n") or 1
        local c = ring:GetAttribute("ic-channel") or 1
        if button == "PADDUP" then c = (c - 2) % n + 1 else c = c % n + 1 end
        ring:SetAttribute("ic-channel", c)
        return false
    end
    local count = ring:GetAttribute(ring:GetAttribute("ic-active") .. "-count") or 0
    if not ring:IsShown() or count < 1 then
        return false
    end
    local current = ring:GetAttribute("ic-sticky")
    local forward = button == "PADDRIGHT" or button == "PADDDOWN"
    if not current then
        current = forward and 1 or count
    elseif forward then
        current = current % count + 1
    else
        current = (current - 2) % count + 1
    end
    ring:SetAttribute("ic-sticky", current)
    return false
]])

-- R2: use the slot a stick points at right now, else the sticky pick.
-- It acts on the press or the release, whichever the game's
-- ActionButtonUseKeyDown setting makes action buttons fire on; a release
-- counts only after a press while the wheel is up (R2 + R3 opens one with
-- R2 still held).
local use = SecureButton("ImprovedForeverRingUse")
use:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(use, "OnClick", use, [[
    self:SetAttribute("type", nil)
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("ic-waiting") then ring:RunAttribute("ic-take-pad") end
    if not ring:IsShown() then
        self:SetAttribute("ic-pressed", nil)
        return false
    end
    if down then self:SetAttribute("ic-pressed", true) end
    if (down and 1 or 0) ~= (self:GetAttribute("ic-keydown") or 1) then
        return false
    end
    if not down and not self:GetAttribute("ic-pressed") then
        return false
    end
    self:SetAttribute("ic-pressed", nil)
    local key = ring:GetAttribute("ic-active")
    local pick = ring:RunAttribute("ic-pick-body", 0.25) or ring:GetAttribute("ic-sticky")
    if not pick then
        return false
    end
    ring:Hide()
    local actionType = ring:GetAttribute(key .. "-type-" .. pick)
    local value = ring:GetAttribute(key .. "-value-" .. pick)
    -- (a chat phrase: on the channel picked, unless that is its own)
    local text = ring:GetAttribute(key .. "-phrase-" .. pick)
    local channel = ring:GetAttribute("ic-channel") or 1
    if text and channel > 1 and ring:GetAttribute("chan-cmd-" .. channel) then
        value = ring:GetAttribute("chan-cmd-" .. channel) .. " " .. text
    end
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("macrotext", nil)
    -- (a group member: targeted, or the spell picked cast on them; any
    -- other slot: no unit, a spell goes where it would from the bar)
    local unit = ring:GetAttribute(key .. "-unit-" .. pick)
    self:SetAttribute("unit", unit)
    if unit then
        local spell = ring:GetAttribute("cast-spell-" .. (ring:GetAttribute("ic-cast") or 1))
        if spell then
            actionType, value = "spell", spell
        else
            actionType, value = "target", nil
        end
    end
    if actionType ~= "target" then
        self:SetAttribute(actionType == "macro" and "macrotext" or actionType, value)
    end
    self:SetAttribute("type", actionType)
    -- The wheel's most recent action (R3 twice uses it again)
    local wheel = ring:GetAttribute(key .. "-wheel")
    if wheel then
        ring:SetAttribute("recent-" .. wheel .. "-type", actionType)
        ring:SetAttribute("recent-" .. wheel .. "-value", value)
        ring:SetAttribute("recent-" .. wheel .. "-unit", unit)
        ring:SetAttribute("ic-used-n", (ring:GetAttribute("ic-used-n") or 0) + 1)
        -- (with the count: the same slot twice is still a change)
        ring:SetAttribute("ic-used", key .. "#" .. pick .. "#" .. ring:GetAttribute("ic-used-n"))
    end
]])

-- L1 / R1: the previous / next wheel (its first page). D-pad left / right:
-- the previous / next page of this wheel.
local page = SecureButton("ImprovedForeverRingPage")
page:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(page, "OnClick", page, [[
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("ic-waiting") then ring:RunAttribute("ic-take-pad") end
    local active = ring:GetAttribute("ic-active") or ""
    local wheel = ring:GetAttribute(active .. "-wheel")
    if not ring:IsShown() or not wheel then
        return false
    end
    local step = (button == "PADLSHOULDER" or button == "PADDLEFT") and -1 or 1
    local target
    if button == "PADLSHOULDER" or button == "PADRSHOULDER" then
        local total = ring:GetAttribute("wheel-total") or 0
        local position = ring:GetAttribute("wheelpos-" .. wheel)
        if total < 2 or not position then
            return false
        end
        target = ring:GetAttribute("wheel-" .. ((position - 1 + step) % total + 1)) .. 1
    else
        local number, of = ring:GetAttribute(active .. "-number"), ring:GetAttribute(active .. "-of") or 1
        if of < 2 or not number then
            return false
        end
        target = wheel .. ((number - 1 + step) % of + 1)
    end
    ring:SetAttribute("ic-sticky", nil)
    ring:SetAttribute("ic-active", target)
    return false
]])

-- Square: put the picked slot on the crossbar with the bind panel
-- (BindPanel.lua, the game's "Bind to Action Bar" as the bags have it),
-- when it can go there (IF.RingBindAction). Out of combat only: Square is
-- the ring's only then.
local bind = CreateFrame("Button", "ImprovedForeverRingBind", UIParent)
bind:SetScript("OnClick", function()
    if IF.RingBindPicked then IF.RingBindPicked() end
end)

-- Circle: close.
local close = SecureButton("ImprovedForeverRingClose")
close:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(close, "OnClick", close, [[
    self:GetFrameRef("ring"):Hide()
    return false
]])

-- While the ring is up it owns R2, Circle, L1, R1, the D-pad and both
-- sticks' directions (the left one's walk), whatever they do otherwise (R2,
-- L1, R1: once let go, ic-take-pad), and Square out of combat.
SecureHandlerWrapScript(ring, "OnShow", ring, [[
    self:RunAttribute("ic-take-pad", true)
    local combat = PlayerInCombat()
    for _, modifier in ipairs(newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-")) do
        self:SetBindingClick(true, modifier .. "PAD2", "ImprovedForeverRingClose", "LeftButton")
        if not combat then
            self:SetBindingClick(true, modifier .. "PAD3", "ImprovedForeverRingBind", "LeftButton")
        end
        for _, key in ipairs(newtable("PADDUP", "PADDDOWN")) do
            self:SetBindingClick(true, modifier .. key, "ImprovedForeverRingStep", key)
        end
        self:SetBindingClick(true, modifier .. "PADDLEFT", "ImprovedForeverRingPage", "PADDLEFT")
        self:SetBindingClick(true, modifier .. "PADDRIGHT", "ImprovedForeverRingPage", "PADDRIGHT")
        -- (the right stick aims; the left one walks, its sticks being taken)
        for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
            self:SetBindingClick(true, modifier .. key, "ImprovedForeverRingAim", key)
        end
        self:SetBinding(true, modifier .. "PADLSTICKUP", "MOVEFORWARD")
        self:SetBinding(true, modifier .. "PADLSTICKDOWN", "MOVEBACKWARD")
        self:SetBinding(true, modifier .. "PADLSTICKLEFT", "STRAFELEFT")
        self:SetBinding(true, modifier .. "PADLSTICKRIGHT", "STRAFERIGHT")
    end
]])
SecureHandlerWrapScript(ring, "OnHide", ring, [[
    self:ClearBindings()
    self:SetAttribute("ic-waiting", nil)
]])

-- Out of combat a held shoulder is taken as soon as it's let go, not only
-- at the next stick / D-pad / R2 press (in combat only those can).
local takeWatch = CreateFrame("Frame", nil, ring)
takeWatch:SetScript("OnUpdate", function()
    if ring:GetAttribute("ic-waiting") and not InCombatLockdown() then
        SecureHandlerExecute(ring, [[ self:RunAttribute("ic-take-pad") ]])
    end
end)

-- The game only sends stick directions as keys with GamePadStickAxisButtons
-- on: switch it on while the ring is up and put it back after. The old
-- value is saved so a /reload mid-ring still restores it. If the game
-- refuses in combat, pointing while pressing R2 and the D-pad still work.
local function RestoreAxisCVar()
    if ring:IsShown() then
        return
    end
    if IF.db and IF.db.axisSaved ~= nil and SetCVarSafe(AXIS_CVAR, IF.db.axisSaved) then
        IF.db.axisSaved = nil
    end
end

ring:HookScript("OnShow", function()
    local current = GetCVarSafe(AXIS_CVAR)
    if current and current ~= "1" then
        if IF.db.axisSaved == nil then
            IF.db.axisSaved = current
        end
        SetCVarSafe(AXIS_CVAR, "1")
    end
end)
ring:HookScript("OnHide", RestoreAxisCVar)
IF.OnLogin(RestoreAxisCVar)

---------------------------------------------------------------------------
-- Visuals (Forever's native radial menu art)
---------------------------------------------------------------------------

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }

local function HasAtlas(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function Atlas(texture, atlas, fallback)
    if HasAtlas(atlas) then
        texture:SetAtlas(atlas)
    elseif fallback then
        texture:SetColorTexture(unpack(fallback))
    end
end

-- A button as inline text in the pad's style (Pad.lua): its glyph, else its name
local function Glyph(key)
    return IF.GlyphText(key, 36)
end

-- Slot i (1..8): 1 at the top, then clockwise, 45 degrees apart.
local function SlotAngle(index)
    return math.pi / 2 - (index - 1) * 2 * math.pi / SLOTS_PER_PAGE
end

local wheel = ring:CreateTexture(nil, "OVERLAY", nil, -3)
wheel:SetPoint("CENTER")
wheel:SetSize(WHEEL_WIDTH, WHEEL_HEIGHT)
Atlas(wheel, "gamepad-radial-menu-wheelbg", { 0, 0, 0, 0.6 })

-- The highlight wedge points outward; the art faces down at rotation 0.
local highlight = ring:CreateTexture(nil, "OVERLAY", nil, -2)
highlight:SetSize(169, 165)
Atlas(highlight, "gamepad-radial-menu-selected", { 1, 0.82, 0, 0.25 })
highlight:Hide()

-- Header: ring name over the top bar, page dots, L1 / R1 prompts.
local header = ring:CreateFontString(nil, "OVERLAY")
header:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
header:SetShadowOffset(1, -1)
header:SetPoint("BOTTOM", ring, "TOP", 0, 40)
local headerBar = ring:CreateTexture(nil, "OVERLAY", nil, -2)
headerBar:SetSize(487, 75)
headerBar:SetPoint("TOP", header, "BOTTOM", 0, 4)
Atlas(headerBar, "gamepad-radial-menu-toptext")
local dotRow = CreateFrame("Frame", nil, ring)
dotRow:SetSize(1, 15)
dotRow:SetPoint("TOP", header, "BOTTOM", 0, -24)
local dots = {}
local pageLeft = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local pageRight = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")

-- Footer: the picked entry's name and the button prompts.
local footerBar = ring:CreateTexture(nil, "OVERLAY", nil, -1)
footerBar:SetSize(570, 151)
footerBar:SetPoint("CENTER", ring, "BOTTOM", 0, -30)
Atlas(footerBar, "gamepad-radial-menu-bottomtext")
local selected = ring:CreateFontString(nil, "OVERLAY")
selected:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
selected:SetShadowOffset(1, -1)
selected:SetTextColor(unpack(GOLD))
selected:SetPoint("CENTER", footerBar, "CENTER", 0, 14)
local prompts = ring:CreateFontString(nil, "OVERLAY")
prompts:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
prompts:SetShadowOffset(1, -1)
prompts:SetPoint("TOP", selected, "BOTTOM", 0, -6)
-- (a craftable slot: what Square makes it from, under its name: have / need)
local reagentLine = ring:CreateFontString(nil, "OVERLAY")
reagentLine:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
reagentLine:SetShadowOffset(1, -1)
reagentLine:SetPoint("TOP", selected, "BOTTOM", 0, -3)
-- (pages: a wheel of more than one, D-pad left / right turns them; bind:
-- the picked slot can go on the crossbar, Square; upDown: what D-pad up /
-- down changes on the picked slot, "Channel" (a chat phrase), "Spell" (a
-- group member), or false)
local function ShowReagents(entry)
    local parts = {}
    for _, reagent in ipairs(entry and entry.reagents or {}) do
        local id, need = reagent[1], reagent[2]
        local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
        local have = getCount and getCount(id) or 0
        local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
        local color = have >= need and "ff40ff40" or "ffff5555"
        parts[#parts + 1] = "|c" .. color .. have .. "/" .. need .. "|r " .. (getName and getName(id) or ("item:" .. id))
    end
    reagentLine:SetText(#parts > 0 and table.concat(parts, "   ") or "")
    prompts:ClearAllPoints()
    prompts:SetPoint("TOP", selected, "BOTTOM", 0, #parts > 0 and -22 or -6)
end
local promptPages, promptBind, promptUpDown
local function SetPrompts(pages, canBind, upDown)
    if pages ~= nil then promptPages = pages end
    if canBind ~= nil then promptBind = canBind end
    if upDown ~= nil then promptUpDown = upDown end
    local bindLabel = _G.CONTEXT_ACTION_LABEL_BIND_TO_GAMEPAD_ACTION_BAR or "Bind"
    prompts:SetText(Glyph("RT") .. " Use      "
        .. (promptBind and (Glyph("X") .. " " .. (promptBind == true and bindLabel or promptBind) .. "      ") or "")
        .. Glyph("B") .. " Close"
        .. (promptPages and ("      " .. Glyph("DPAD_LR") .. " Page") or "")
        .. (promptUpDown and ("      " .. Glyph("DPAD_UD") .. " " .. promptUpDown) or ""))
end
SetPrompts(false, false, false)

-- The hub: while a chat phrase is picked, the channel it's said on; while
-- a group member is, what a pick does to them (target, or a spell)
local hubKicker = ring:CreateFontString(nil, "OVERLAY")
hubKicker:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
hubKicker:SetShadowOffset(1, -1)
hubKicker:SetTextColor(0.62, 0.57, 0.48)
hubKicker:SetPoint("BOTTOM", ring, "CENTER", 0, 4)
hubKicker:SetText("CHANNEL")
local hubChannel = ring:CreateFontString(nil, "OVERLAY")
hubChannel:SetFont("Fonts\\FRIZQT__.TTF", 15, "")
hubChannel:SetShadowOffset(1, -1)
hubChannel:SetTextColor(unpack(GOLD))
hubChannel:SetPoint("TOP", ring, "CENTER", 0, -2)
hubChannel:SetWidth(96)
-- (a group member picked: the spell's icon over its name; "Target" has
-- the target icon)
local TARGET_ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"
local hubIcon = ring:CreateTexture(nil, "OVERLAY")
hubIcon:SetSize(34, 34)
hubIcon:SetPoint("BOTTOM", ring, "CENTER", 0, 2)
do
    local mask = ring:CreateMaskTexture()
    mask:SetAllPoints(hubIcon)
    if HasAtlas("CircleMask") then
        mask:SetAtlas("CircleMask")
    else
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    hubIcon:AddMaskTexture(mask)
end
hubIcon:Hide()
local channelLabels = {}
local castList = {} -- { label, spell?, icon? }, "ic-cast"'s (Group.lua)
local hubMode
-- mode: "chat", "cast" or nil (none shown)
local function ShowChannel(mode)
    hubMode = mode or nil
    hubKicker:SetShown(hubMode == "chat")
    hubChannel:SetShown(hubMode ~= nil)
    hubIcon:SetShown(hubMode == "cast")
    if hubMode == "chat" then
        hubKicker:SetText("CHANNEL")
        hubChannel:SetText(channelLabels[ring:GetAttribute("ic-channel") or 1] or "")
    elseif hubMode == "cast" then
        local cast = castList[ring:GetAttribute("ic-cast") or 1]
        hubChannel:SetText(cast and cast.label or "Target")
        hubIcon:SetTexture(cast and cast.icon or TARGET_ICON)
        hubIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end
ShowChannel(nil)
IF.OnPadStyleChanged(function() SetPrompts() end)

local slots = {}
for index = 1, SLOTS_PER_PAGE do
    local angle = SlotAngle(index)
    local dx, dy = math.cos(angle), math.sin(angle)
    local slot = {}
    slot.dx, slot.dy = dx, dy
    slot.empty = ring:CreateTexture(nil, "OVERLAY", nil, -1)
    slot.empty:SetSize(169, 164)
    slot.empty:SetPoint("CENTER", ring, "CENTER", dx * SLOT_RADIUS, dy * SLOT_RADIUS)
    Atlas(slot.empty, "gamepad-radial-menu-disabled")
    slot.empty:SetRotation(angle + math.pi / 2)
    slot.icon = ring:CreateTexture(nil, "OVERLAY", nil, 0)
    slot.icon:SetSize(ICON_SIZE, ICON_SIZE)
    local ix, iy, lx, ly = IF.SlotLayout(dx, dy)
    slot.icon:SetPoint("CENTER", ring, "CENTER", ix, iy)
    -- Round, as the wheel editor shows them (ConfigKit's RoundIcon)
    local mask = ring:CreateMaskTexture()
    mask:SetAllPoints(slot.icon)
    if HasAtlas("CircleMask") then
        mask:SetAtlas("CircleMask")
    else
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    slot.icon:AddMaskTexture(mask)
    -- A craft ring round the icon: the slot's recipe is known (Square makes it)
    slot.craftRing = ring:CreateTexture(nil, "OVERLAY", nil, -1)
    slot.craftRing:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    slot.craftRing:SetPoint("CENTER", slot.icon, "CENTER")
    slot.craftRing:SetColorTexture(unpack(GOLD))
    local ringMask = ring:CreateMaskTexture()
    ringMask:SetAllPoints(slot.craftRing)
    if HasAtlas("CircleMask") then
        ringMask:SetAtlas("CircleMask")
    else
        ringMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    slot.craftRing:AddMaskTexture(ringMask)
    slot.craftRing:Hide()
    -- Its cooldown (an item's, a spell's), a round swipe over the icon
    -- (not a protected frame: set in combat too)
    slot.cooldown = CreateFrame("Cooldown", nil, ring, "CooldownFrameTemplate")
    slot.cooldown:SetAllPoints(slot.icon)
    if slot.cooldown.SetSwipeTexture then
        slot.cooldown:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    if slot.cooldown.SetUseCircularEdge then slot.cooldown:SetUseCircularEdge(true) end
    if slot.cooldown.SetDrawEdge then slot.cooldown:SetDrawEdge(false) end
    slot.cooldown:Hide()
    slot.count = ring:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.count:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 2, -2)
    slot.label = ring:CreateFontString(nil, "OVERLAY")
    slot.label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    slot.label:SetShadowOffset(1, -1)
    slot.label:SetSize(90, 40)
    slot.label:SetPoint("CENTER", ring, "CENTER", lx, ly)
    -- A group member's health, under the icon (the game's own secret-safe
    -- StatusBar: fed the values as they are)
    slot.health = CreateFrame("StatusBar", nil, ring)
    slot.health:SetSize(ICON_SIZE, 4)
    slot.health:SetPoint("TOP", slot.icon, "BOTTOM", 0, -3)
    slot.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    slot.health:SetStatusBarColor(0.1, 0.8, 0.1)
    local healthBack = slot.health:CreateTexture(nil, "BACKGROUND")
    healthBack:SetAllPoints()
    healthBack:SetColorTexture(0, 0, 0, 0.6)
    slot.health:Hide()
    -- A consumable's stat values (RingContent.lua) under the icon, each
    -- in its kind's colour
    slot.stat = ring:CreateFontString(nil, "OVERLAY")
    slot.stat:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    slot.stat:SetShadowOffset(1, -1)
    slot.stat:SetPoint("TOP", slot.icon, "BOTTOM", 0, -7)
    slot.stat:Hide()
    slots[index] = slot
end

local function ItemCount(value)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(value) or 0
end

-- An entry's cooldown: start, duration (an item's, a gear slot's item's, a
-- spell's), or nil
local function EntryCooldown(entry)
    local itemID = entry.cooldownItem
        or (entry.type == "item" and tonumber(tostring(entry.value):match("item:(%d+)")))
    if itemID then
        local get = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
        if get then return get(itemID) end
    elseif entry.spellID then
        if C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(entry.spellID)
            if type(info) == "table" then return info.startTime, info.duration end
        elseif GetSpellCooldown then
            return GetSpellCooldown(entry.spellID)
        end
    end
end

-- Its swipe (not the global cooldown's)
local function ShowCooldown(cooldown, entry)
    local start, duration = EntryCooldown(entry or {})
    if entry and start and duration and start > 0 and duration > 1.5 then
        cooldown:SetCooldown(start, duration)
        cooldown:Show()
    else
        cooldown:Hide()
    end
end

-- A gear pick waiting for the fight's end (WheelKinds.lua): its label cyan
local PENDING = { 0.62, 0.85, 0.89 }
local function Pending(entry)
    local KD = IF.WheelKinds
    return entry.equip ~= nil and KD and KD.IsPending(entry.equip)
end

local function LabelColor(entry)
    -- (a group member: their class colour, grey while gone, dead, offline)
    local G = IF.GroupWheel
    if entry.unit and G then
        local _, _, color, usable = G.Look(entry.unit)
        return usable and (color or GOLD) or GREY
    end
    if Pending(entry) then return PENDING end
    local usable = (entry.type ~= "item" or ItemCount(entry.value) > 0) and not entry.missing
    return usable and GOLD or GREY
end

-- A recipe a slot makes (entry.craft: its spell ID) while Square can craft
-- it: out of combat, the recipe known; else nil
local CRAFT_LABEL = "Craft"
function IF.RingCraftSpell(entry)
    local spellID = entry and entry.craft
    if not spellID or IF.InCombat() then return nil end
    local known = IsPlayerSpell or IsSpellKnown
    if known and not known(spellID) then return nil end
    return spellID
end

-- The action a ring entry goes on the crossbar as ("item:<id>",
-- "spell:<id>", "macro:<name>"), or nil: it can't go there now (in combat,
-- an emote, an item not in the bags or that does nothing when used: the
-- game offers "Bind to Action Bar" for those only, PaperDollFrame's check)
function IF.RingBindAction(entry)
    if not (entry and IF.WheelBindPanel and IF.Native and IF.Native.Available())
        or IF.InCombat() or (CursorHasItem and CursorHasItem()) then
        return nil
    end
    if entry.type == "item" then
        local itemID = tonumber(tostring(entry.value):match("item:(%d+)"))
        local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        local equippable = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
        if itemID and ItemCount(itemID) > 0
            and ((getSpell and getSpell(itemID)) or (equippable and equippable(itemID))) then
            return "item:" .. itemID
        end
    elseif entry.type == "spell" and entry.spellID then
        local known = IsPlayerSpell or IsSpellKnown
        if not known or known(entry.spellID) then
            return "spell:" .. entry.spellID
        end
    elseif entry.type == "macro" and entry.macroName then
        local index = GetMacroIndexByName(entry.macroName)
        if index and index > 0 then
            return "macro:" .. entry.macroName
        end
    end
    return nil
end

local pageOrder = {}  -- page keys, every wheel's in turn
local wheelOrder = {} -- wheel keys in L1 / R1 order
local pageInfo = {}   -- page key -> { ring = key, number = n, of = total, label?, empty? }

-- What an empty page says (a self-filling wheel's hint: "No quest items...")
local function EmptyText(info)
    return info and info.empty or "Nothing here"
end

-- Without the icon's own square frame (ConfigKit's SetIcon)
local function SetSlotIcon(texture, icon)
    if type(icon) == "string" and HasAtlas(icon) then
        texture:SetAtlas(icon)
    else
        texture:SetTexture(icon)
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

-- A group member's slot, from their unit token now (so in combat too: the
-- token's holder may have changed since the ring was built)
local highlighted
local function UpdateUnitSlot(index, entry)
    local G = IF.GroupWheel
    local slot = slots[index]
    if not (G and slot and entry and entry.unit) then return end
    local name, icon, color, usable = G.Look(entry.unit)
    SetSlotIcon(slot.icon, icon)
    slot.icon:SetDesaturated(not usable)
    slot.label:SetText(name)
    slot.label:SetTextColor(unpack(index == highlighted and { 1, 1, 1 } or (usable and (color or GOLD) or GREY)))
    local max, now = G.Health(entry.unit)
    slot.health:SetShown(max ~= nil)
    if max then
        slot.health:SetMinMaxValues(0, max)
        slot.health:SetValue(now)
    end
end

local function UpdateUnitSlots()
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    for index, entry in ipairs(entries) do
        if entry.unit then UpdateUnitSlot(index, entry) end
    end
end

local function RefreshVisuals()
    local active = ring:GetAttribute("ic-active")
    local entries = ringData[active] or {}
    local info = pageInfo[active]
    -- (a page of a group with a name: "Totems · Fire")
    header:SetText(info and (IF.RING_LABELS[info.ring] .. (info.label and (" · " .. info.label) or "")
        .. (info.of > 1 and ("  " .. info.number .. "/" .. info.of) or "")) or "")
    for index, slot in ipairs(slots) do
        local entry = entries[index]
        slot.empty:SetShown(not entry)
        slot.icon:SetShown(entry ~= nil)
        slot.label:SetShown(entry ~= nil)
        slot.count:SetShown(entry ~= nil)
        slot.health:Hide()
        slot.craftRing:Hide()
        slot.stat:SetText(entry and not entry.unit and entry.stat or "")
        slot.stat:SetShown(entry ~= nil and entry.stat ~= nil and not entry.unit)
        ShowCooldown(slot.cooldown, entry)
        if entry and entry.unit then
            slot.count:SetText("")
            UpdateUnitSlot(index, entry)
        elseif entry then
            SetSlotIcon(slot.icon, entry.icon or 134400)
            slot.count:SetText(entry.type == "item" and ItemCount(entry.value) or "")
            slot.label:SetText(entry.label)
            local usable = (entry.type ~= "item" or ItemCount(entry.value) > 0) and not entry.missing
            slot.icon:SetDesaturated(not usable)
            slot.craftRing:SetShown(entry.craft ~= nil)
            slot.label:SetTextColor(unpack(LabelColor(entry)))
        end
    end
    -- One dot per wheel (L1 / R1), the current one lit; the page is in the
    -- title ("2/3", D-pad left / right)
    for _, dot in ipairs(dots) do
        dot:Hide()
    end
    local total = #wheelOrder
    for position, key in ipairs(wheelOrder) do
        local dot = dots[position]
        if not dot then
            dot = dotRow:CreateTexture(nil, "OVERLAY")
            dot:SetSize(15, 15)
            dots[position] = dot
        end
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", dotRow, "CENTER", (position - (total + 1) / 2) * 20, 0)
        local lit = info and key == info.ring
        Atlas(dot, lit and "gamepad-radialgamemenu-cursorbg-neutral"
            or "gamepad-radialgamemenu-cursorbg-inactive", lit and { 1, 1, 1, 1 } or { 0.4, 0.4, 0.4, 1 })
        dot:Show()
    end
    local edge = (total - 1) * 10 + 12
    pageLeft:ClearAllPoints()
    pageLeft:SetPoint("RIGHT", dotRow, "CENTER", -edge, -2)
    pageLeft:SetText(total > 1 and IF.GlyphText("LB", 38) or "")
    pageRight:ClearAllPoints()
    pageRight:SetPoint("LEFT", dotRow, "CENTER", edge, -2)
    pageRight:SetText(total > 1 and IF.GlyphText("RB", 38) or "")
    selected:SetText(#entries == 0 and EmptyText(info) or "")
    SetPrompts((info and info.of > 1) or false, nil, false)
    ShowChannel(nil)
end

-- Same pick as the secure "ic-pick-body": the stronger of the two sticks.
local function StickPick(entries)
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then
        return nil
    end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local sticks = state and state.sticks
    if not sticks then
        return nil
    end
    local x, y, lengthSq = 0, 0, 0
    for _, attribute in ipairs({ "ic-stick", "ic-stick2" }) do
        local stick = sticks[ring:GetAttribute(attribute) or 0]
        if stick and stick.x and stick.y and stick.x * stick.x + stick.y * stick.y > lengthSq then
            x, y, lengthSq = stick.x, stick.y, stick.x * stick.x + stick.y * stick.y
        end
    end
    if lengthSq < PICK_LENGTH_SQ then
        return nil
    end
    local best, bestDot
    for index in ipairs(entries) do
        local dot = x * slots[index].dx + y * slots[index].dy
        if not bestDot or dot > bestDot then
            best, bestDot = index, dot
        end
    end
    return best
end

-- The picked entry's tooltip, mid-left of the wheel (spells and items; a
-- macro or an emote has none)
local function ShowTooltip(entry)
    local tip = GameTooltip
    local unit = entry and entry.unit
    if unit and not (UnitExists and UnitExists(unit)) then unit = nil end
    if not (entry and (unit or entry.spellID or entry.type == "item" or entry.tip or entry.reagents)) then
        if tip:GetOwner() == ring then tip:Hide() end
        return
    end
    tip:SetOwner(ring, "ANCHOR_NONE")
    tip:ClearAllPoints()
    -- (the wheel art has ~35 px of clear edge around the ring)
    tip:SetPoint("RIGHT", ring, "LEFT", 28, 0)
    if unit then
        tip:SetUnit(unit)
    elseif entry.spellID then
        tip:SetSpellByID(entry.spellID)
    else
        tip:SetHyperlink(entry.tip or entry.value)
    end
    -- (an item the game hasn't cached has no text yet: its name at least)
    if tip:NumLines() == 0 then tip:AddLine(entry.label, 1, 1, 1) end
    tip:Show()
end

local function Highlight(pick)
    -- A new slot picked: a tick (Vibration tab: Wheel, Slot change)
    if pick and pick ~= highlighted and IF.Vibe then IF.Vibe.Fire("wheelTick") end
    highlighted = pick
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    local slot = pick and slots[pick]
    if slot and entries[pick] then
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", ring, "CENTER", slot.dx * SLOT_RADIUS, slot.dy * SLOT_RADIUS)
        highlight:SetRotation(SlotAngle(pick) + math.pi / 2)
        highlight:Show()
        if entries[pick].unit and IF.GroupWheel then
            -- (a name may be a secret: set as it is, never joined to text)
            selected:SetText((IF.GroupWheel.Look(entries[pick].unit)))
        else
            selected:SetText(entries[pick].label .. (Pending(entries[pick]) and "  (after combat)"
                or (entries[pick].where and ("  (" .. entries[pick].where .. ")")) or ""))
        end
        ShowTooltip(entries[pick])
        ShowReagents(entries[pick])
    else
        highlight:Hide()
        ShowReagents(nil)
        selected:SetText(#entries == 0 and EmptyText(pageInfo[ring:GetAttribute("ic-active")]) or "")
        ShowTooltip(nil)
    end
    -- A chat phrase picked: its channel in the hub, D-pad up / down changes
    -- it; a group member (with spells to pick from): what a pick does
    local entry = slot and entries[pick]
    local mode = entry and (entry.phrase and "chat" or (entry.unit and #castList > 1 and "cast")) or nil
    ShowChannel(mode)
    SetPrompts(nil, nil, mode == "chat" and "Channel" or mode == "cast" and "Spell" or false)
    -- The picked entry's label turns white, like the native menu.
    for index, other in ipairs(slots) do
        local entry = entries[index]
        if entry then
            other.label:SetTextColor(unpack(index == pick and { 1, 1, 1 } or LabelColor(entry)))
        end
    end
end

local sinceUnits = 0
ring:SetScript("OnUpdate", function(_, elapsed)
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    local pick = StickPick(entries) or ring:GetAttribute("ic-sticky")
    if pick ~= highlighted then
        Highlight(pick)
    end
    -- (group members: names, health, who's there, a few times a second)
    sinceUnits = sinceUnits + (elapsed or 0)
    if sinceUnits > 0.2 then
        sinceUnits = 0
        UpdateUnitSlots()
    end
    -- Square's prompt, while the picked slot can go on the crossbar
    local picked = pick and entries[pick]
    local canBind = IF.RingCraftSpell(picked) and CRAFT_LABEL or IF.RingBindAction(picked) ~= nil
    if canBind ~= promptBind then SetPrompts(nil, canBind) end
end)

-- The group member picked on the ring now (UnitFrames.lua lights their
-- frame), or nil
function IF.RingPickedUnit()
    if not ring:IsShown() or ring:GetAlpha() == 0 then return nil end
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    local entry = highlighted and entries[highlighted]
    return entry and entry.unit
end

-- Square: the picked slot (as highlighted) to the bind panel; the ring
-- closes first (its bindings go), then the panel takes the buttons
function IF.RingBindPicked()
    if not ring:IsShown() or IF.InCombat() then return end
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    -- (a camping slot: Square crafts it, as the recipe's profession makes it)
    local craft = IF.RingCraftSpell(highlighted and entries[highlighted])
    if craft then
        ring:Hide()
        IF.CraftRecipe(craft)
        return
    end
    local action = IF.RingBindAction(highlighted and entries[highlighted])
    if not action then return end
    ring:Hide()
    IF.WheelBindPanel.Open(action)
end
ring:HookScript("OnShow", function()
    RefreshVisuals()
    Highlight(nil)
end)
ring:HookScript("OnHide", function()
    highlighted = nil
    ShowReagents(nil)
    ShowTooltip(nil)
    SetPrompts(nil, false)
end)
ring:HookScript("OnAttributeChanged", function(_, name, value)
    if name == "ic-active" and ring:IsShown() then
        RefreshVisuals()
        Highlight(nil)
    elseif name == "ic-channel" then
        -- (kept for the next time, and shown in the hub)
        if IF.db and type(value) == "number" then IF.db.phraseChannel = value end
        if ring:IsShown() then ShowChannel(hubMode) end
    elseif name == "ic-cast" then
        if IF.charDB and type(value) == "number" then IF.charDB.groupCast = value end
        if ring:IsShown() then ShowChannel(hubMode) end
    end
end)

---------------------------------------------------------------------------
-- Contents and bindings (out of combat only)
---------------------------------------------------------------------------

-- The wheels' most recent actions, kept per character
-- (IF.charDB.recent[wheel] = { type, value, label, icon }) and given to
-- the secure side (out of combat)
function IF.RecentAction(wheel)
    return IF.charDB and IF.charDB.recent and IF.charDB.recent[wheel]
end

function IF.ApplyRecent()
    if IF.InCombat() or not IF.charDB then return end
    IF.charDB.recent = IF.charDB.recent or {}
    for _, wheel in ipairs(IF.RINGS) do
        local recent = IF.charDB.recent[wheel]
        ring:SetAttribute("recent-" .. wheel .. "-type", recent and recent.type or nil)
        ring:SetAttribute("recent-" .. wheel .. "-value", recent and recent.value or nil)
        ring:SetAttribute("recent-" .. wheel .. "-unit", recent and recent.unit or nil)
    end
end

-- A gear pick ({ item, slot }) equipped, or kept for after the fight
-- (WheelKinds.lua), once the secure click is over
local function Equip(equip)
    local KD = IF.WheelKinds
    if not (equip and KD) then return end
    C_Timer.After(0, function()
        KD.Equip(equip)
        if ring:IsShown() then RefreshVisuals() end
    end)
end

-- A slot used (the secure "ic-used" = page#slot#count): remembered; a gear
-- slot's item put on. R3 twice ("ic-replay" = wheel#count): the wheel's
-- recent gear pick put on again.
ring:HookScript("OnAttributeChanged", function(_, name, value)
    if type(value) ~= "string" or not IF.charDB then return end
    if name == "ic-replay" then
        local recent = IF.RecentAction(value:match("^(.+)#%d+$"))
        if recent and recent.equip then Equip(recent.equip) end
        return
    end
    if name ~= "ic-used" then return end
    local key, pick = value:match("^(.+)#(%d+)#%d+$")
    local entry = key and ringData[key] and ringData[key][tonumber(pick)]
    local info = key and pageInfo[key]
    if not (entry and info) then return end
    IF.charDB.recent = IF.charDB.recent or {}
    if entry.unit then
        -- (a group member: what the pick did, as the secure side has it;
        -- its name is read live, RecentSlot.lua)
        local actionType = ring:GetAttribute("recent-" .. info.ring .. "-type")
        local cast = castList[ring:GetAttribute("ic-cast") or 1]
        IF.charDB.recent[info.ring] = { type = actionType, value = ring:GetAttribute("recent-" .. info.ring .. "-value"),
            unit = entry.unit, icon = actionType == "spell" and cast and cast.icon or entry.icon }
    else
        IF.charDB.recent[info.ring] = { type = entry.type, value = entry.value, label = entry.label, icon = entry.icon,
            equip = entry.equip }
    end
    if IF.RecentChanged then IF.RecentChanged() end
    if entry.equip then Equip(entry.equip) end
end)

local function Rebuild()
    if IF.InCombat() then
        rebuildPending = true
        return
    end
    rebuildPending = false
    wipe(pageOrder)
    wipe(wheelOrder)
    wipe(pageInfo)
    wipe(ringData)
    -- A deleted wheel's key binding opens nothing
    for _, key in ipairs(IF.WHEEL_BINDING_KEYS) do
        ring:SetAttribute("ic-first-" .. key, nil)
    end
    for _, ringKey in ipairs(IF.RINGS) do
        local build = IF.RingBuilders[ringKey]
        if build then
            local entries = build()
            -- Cut into pages of eight; a wheel whose entries come in groups
            -- (entries.groups: lists) starts each group on a page of its own
            -- (a group's label goes with its pages)
            local pageLists, labels = {}, {}
            for _, group in ipairs(entries.groups or { entries }) do
                for first = 1, #group, SLOTS_PER_PAGE do
                    pageLists[#pageLists + 1] = { unpack(group, first, math.min(#group, first + SLOTS_PER_PAGE - 1)) }
                    labels[#pageLists] = group.label
                end
            end
            if #pageLists == 0 then pageLists[1] = {} end
            local pages = #pageLists
            for number = 1, pages do
                local key = ringKey .. number
                local pageEntries = {}
                for index = 1, SLOTS_PER_PAGE do
                    local entry = pageLists[number][index]
                    if not entry then
                        break
                    end
                    pageEntries[index] = entry
                    local angle = SlotAngle(index)
                    ring:SetAttribute(key .. "-dx-" .. index, math.cos(angle))
                    ring:SetAttribute(key .. "-dy-" .. index, math.sin(angle))
                    ring:SetAttribute(key .. "-type-" .. index, entry.type)
                    ring:SetAttribute(key .. "-value-" .. index, entry.value)
                    ring:SetAttribute(key .. "-phrase-" .. index, entry.phrase)
                    ring:SetAttribute(key .. "-unit-" .. index, entry.unit)
                end
                ring:SetAttribute(key .. "-count", #pageEntries)
                ringData[key] = pageEntries
                pageOrder[#pageOrder + 1] = key
                pageInfo[key] = { ring = ringKey, number = number, of = pages, label = labels[number],
                    empty = entries.empty }
                ring:SetAttribute(key .. "-wheel", ringKey)
                ring:SetAttribute(key .. "-number", number)
                ring:SetAttribute(key .. "-of", pages)
            end
            ring:SetAttribute("ic-first-" .. ringKey, ringKey .. 1)
            wheelOrder[#wheelOrder + 1] = ringKey
            ring:SetAttribute("wheelpos-" .. ringKey, #wheelOrder)
            ring:SetAttribute("wheel-" .. #wheelOrder, ringKey)
        end
    end
    ring:SetAttribute("wheel-total", #wheelOrder)
    -- The channels a chat phrase can be said on (WheelKinds.lua): 1,
    -- each phrase's own; the one picked last time
    local KD = IF.WheelKinds
    local channels = KD and KD.RingChannels() or { { label = "Auto" } }
    wipe(channelLabels)
    for n, c in ipairs(channels) do
        channelLabels[n] = c.label
        ring:SetAttribute("chan-cmd-" .. n, c.command)
    end
    ring:SetAttribute("chan-n", #channels)
    local picked = IF.db and IF.db.phraseChannel
    ring:SetAttribute("ic-channel", (type(picked) == "number" and picked <= #channels) and picked or 1)
    -- What a pick does to a group member (Group.lua): 1, target them; then
    -- each spell, cast on them; the one picked last time
    local G = IF.GroupWheel
    local casts = G and G.CastList() or { { label = "Target" } }
    wipe(castList)
    for n = 1, math.max(#casts, ring:GetAttribute("cast-n") or 0) do
        castList[n] = casts[n]
        ring:SetAttribute("cast-spell-" .. n, casts[n] and casts[n].spell)
    end
    ring:SetAttribute("cast-n", #casts)
    local cast = IF.charDB and IF.charDB.groupCast
    ring:SetAttribute("ic-cast", (type(cast) == "number" and cast <= #casts) and cast or 1)
    IF.ApplyRecent()
    if ring:IsShown() then
        RefreshVisuals()
        Highlight(nil)
    end
end

local rebuildQueued = false
local function QueueRebuild()
    if rebuildQueued then
        return
    end
    rebuildQueued = true
    C_Timer.After(0.3, function()
        rebuildQueued = false
        Rebuild()
    end)
end

IF.QueueRingRebuild = QueueRebuild

local function GamePadIndex(binding)
    if C_GamePad and C_GamePad.ButtonBindingToIndex then
        local index = C_GamePad.ButtonBindingToIndex(binding)
        if index then
            return index + 1 -- GetGamePadState().buttons is 1-based
        end
    end
end

local function StickIndex(name)
    if C_GamePad and C_GamePad.StickConfigNameToIndex then
        local index = C_GamePad.StickConfigNameToIndex(name)
        if index and index >= 0 then
            return index + 1
        end
    end
end

function IF.ApplyRingBindings()
    if IF.InCombat() then
        bindingsPending = true
        return
    end
    bindingsPending = false
    ring:SetAttribute("ic-stick", StickIndex("Right") or 2)
    -- Only the right stick aims (the left one moves, as with the native radial)
    ring:SetAttribute("ic-stick2", nil)
    use:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
    trigger:SetAttribute("ic-keydown", use:GetAttribute("ic-keydown"))
    -- The key prefixes R3 reaches us under for a combo with a ring: the
    -- modifier its held button makes (GamePadEmulate*), or none (R3 alone,
    -- or held with a button that isn't one). Only those are taken: the rest
    -- stay the game's own (R3's ping can't be run for it from here).
    local plain, modifiers = false, {}
    for _, combo in ipairs(IF.COMBOS) do
        local key = IF.GetComboRing(combo)
        trigger:SetAttribute("ic-combo-" .. combo, key)
        if key ~= "native" then
            local modifier = COMBO_BUTTONS[combo] and IF.Binds.ModifierOf(COMBO_BUTTONS[combo])
            if modifier then modifiers[#modifiers + 1] = modifier else plain = true end
        end
    end
    -- Actions put on R3 presses (the Bindings tab, Binds.SetAction: kept
    -- with the overrides): each on its chord ("ic-act-L1R1"), R3 taken
    -- under the modifiers its buttons held make
    for chord in pairs(actChords) do trigger:SetAttribute("ic-act-" .. chord, nil) end
    wipe(actChords)
    local O, B = IF.Override, IF.Binds
    for spec, action in pairs(O and O.Settings() or {}) do
        local held, pressed, double = B.Parse(spec)
        local macro = pressed == KEY and not double and O.Macro(action)
        if macro then
            local chord = ""
            for _, name in ipairs({ "L1", "L2", "R1", "R2" }) do
                for _, key in ipairs(B.HeldList(held)) do
                    if key == COMBO_BUTTONS[name] then chord = chord .. name end
                end
            end
            chord = chord ~= "" and chord or "R3"
            actChords[chord] = true
            trigger:SetAttribute("ic-act-" .. chord, macro)
            -- (R3 comes with the modifiers of the buttons held that make
            -- one; none of them: as R3 alone)
            local any = false
            for _, key in ipairs(B.HeldList(held)) do
                local modifier = B.ModifierOf(key)
                if modifier then modifiers[#modifiers + 1], any = modifier, true end
            end
            if not any then plain = true end
        end
    end
    local function Takes(prefix)
        if prefix == "" then return plain end
        for _, modifier in ipairs(modifiers) do
            if prefix:find(modifier, 1, true) then return true end
        end
        return false
    end
    for combo, binding in pairs(COMBO_BUTTONS) do
        trigger:SetAttribute("ic-btn-" .. combo, GamePadIndex(binding))
        ring:SetAttribute("ic-btn-" .. binding, GamePadIndex(binding))
    end
    ClearOverrideBindings(trigger)
    -- Only while the game has the gamepad's focus (Binds.lua): a window
    -- holding it keeps R3 for itself
    if IF.Binds.InGame() then
        for _, modifier in ipairs(MODIFIERS) do
            if Takes(modifier) then
                SetOverrideBindingClick(trigger, true, modifier .. KEY, trigger:GetName(), modifier .. KEY)
            end
        end
    end
end

IF.OnLogin(function()
    Rebuild()
    IF.ApplyRingBindings()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, name)
    if not IF.db then
        return
    end
    if event == "CVAR_UPDATE" then
        if not IF.InCombat() then
            use:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
            trigger:SetAttribute("ic-keydown", use:GetAttribute("ic-keydown"))
        end
        -- (which shoulder is a modifier: the keys R3 is taken on)
        if type(name) == "string" and name:lower():find("^gamepademulate") then
            IF.ApplyRingBindings()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        RestoreAxisCVar()
        if bindingsPending then
            IF.ApplyRingBindings()
        end
        if rebuildPending then
            Rebuild()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Last chance to pick up bag changes before the lockdown.
        Rebuild()
    elseif event == "BAG_UPDATE_DELAYED" and ring:IsShown() then
        RefreshVisuals()
        QueueRebuild()
    else
        QueueRebuild()
    end
end)

-- One radial at a time: ours opening closes Forever's main menu radial, and
-- Forever's opening closes ours. In combat our secure wheel can't be hidden
-- from here: it is turned invisible instead until the native one closes.
local function NativeRadial()
    return _G.GamepadRadial
end

ring:HookScript("OnShow", function()
    ring:SetAlpha(1)
    local native = NativeRadial()
    if native and native:IsShown() then native:Hide() end
end)

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("Gamepad.ShowMainMenu", function()
        if not ring:IsShown() then return end
        if IF.InCombat() then
            ring:SetAlpha(0)
        else
            ring:Hide()
        end
    end, ring)
    EventRegistry:RegisterCallback("Gamepad.HideMainMenu", function()
        ring:SetAlpha(1)
    end, ring)
end

-- Leave an R3 combo ("L1", "R2"...) to something else for now, or take it
-- back; out of combat only
function IF.SuppressCombo(combo, on)
    if IF.InCombat() then return false end
    local trigger = _G.ImprovedForeverRingTrigger
    if trigger then trigger:SetAttribute("ic-skip-" .. combo, on or nil) end
    return true
end


-- Opened by R3, the ring stays invisible for a moment: a quick second R3
-- (the recent action) closes it before it is ever seen. Opened any other
-- way (a key binding), it shows at once. Only its look waits; it works
-- from the first frame.
local REVEAL_DELAY = 0.2
local revealToken = 0
ring:HookScript("OnShow", function()
    revealToken = revealToken + 1
    -- (R3 still down: opened by it)
    if not IsKeyDown or not IsKeyDown("PADRSTICK") then return end
    local token = revealToken
    ring:SetAlpha(0)
    C_Timer.After(REVEAL_DELAY, function()
        if token == revealToken and ring:IsShown() then ring:SetAlpha(1) end
    end)
end)
ring:HookScript("OnHide", function()
    revealToken = revealToken + 1
    ring:SetAlpha(1)
end)
