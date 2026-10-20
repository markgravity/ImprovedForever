-- Fishing mode: a pole in hand isn't fishing yet. A line on the screen says
-- how to start: R2 twice (the controller), or a double right-click on the
-- world (the mouse). In it, R2 casts (Fishing.lua), the HUD steps back and
-- the camera comes in (View.lua), the session runs (Session.lua), auto
-- loot is on (AutoLoot.lua); the line then says how to stop: Circle or
-- Esc. Out of it by those, the pole put away, a fight, or dying.
-- In it, nothing else open (a window, the bags, a dialog, one of ours, the
-- game's pad focus on a window), its presses are ours: Circle / Esc stop
-- it, D-pad up / Up the Fish Collection, Triangle / Alt-F the camera edit
-- (override bindings, only then: cleared the moment something opens, the
-- press then that thing's, to close it). R2's double press to start:
-- watched, not taken (out of the mode it's the game's crossbar modifier),
-- the press counted only if it began with nothing open, a tap each (held,
-- it pages the crossbar). Kept per character through a /reload
-- (IF.charDB.fishingMode).
local IF = ImprovedForever
local F = IF.Fishing

local DOUBLE, TAP, STILL = 0.45, 0.3, 8     -- (a double press: the second within DOUBLE; each under TAP; the mouse moved under STILL px)
local QUIET = 0.3                           -- (something closed lately: its press, not ours)
local ENTER_KEY, EXIT_KEY = "PADRTRIGGER", "PAD2"

local on = false
local listeners = {}

function F.OnMode(fn)
    listeners[#listeners + 1] = fn
end

-- In fishing mode
function F.InMode()
    return on
end

local function Set(want)
    want = want and true or false
    if want == on then return end
    on = want
    if IF.charDB then IF.charDB.fishingMode = on or nil end
    PlaySound(on and (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850) or (SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851))
    for _, fn in ipairs(listeners) do pcall(fn, on) end
end
F.SetMode = Set

-- (fishing can begin: a pole in hand, out of a fight, alive, not in Edit Mode)
local function CanFish()
    return IF.db ~= nil and F.PoleEquipped() and not IF.InCombat() and not F.EditMode()
        and not UnitIsDeadOrGhost("player")
end

-- Something else open: Esc and Circle are its
local function Shown(f)
    return f ~= nil and f.IsShown ~= nil and f:IsShown()
end

local function OtherOpen()
    if not IF.Binds.InGame() then return true end
    local m = IF.Focus.Manager()
    if m and m.isUIFocused then return true end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return true end
    if SpellIsTargeting and SpellIsTargeting() then return true end
    if IF.Focus.OursOpen and IF.Focus.OursOpen() then return true end
    if GetUIPanel then
        for _, side in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
            if GetUIPanel(side) then return true end
        end
    end
    for _, name in ipairs(UISpecialFrames or {}) do
        if Shown(_G[name]) then return true end
    end
    if Shown(_G.ContainerFrameCombinedBags) or Shown(_G.GameMenuFrame) or Shown(_G.LootFrame) then return true end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        if Shown(_G["ContainerFrame" .. i]) then return true end
    end
    for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
        if Shown(_G["StaticPopup" .. i]) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- In the mode, nothing else open: its presses, ours (override bindings,
-- cleared the moment something opens; each acting at its release, so the
-- release isn't the game's): Circle / Esc stop, D-pad up / Up the Fish
-- Collection (CollectionWindow.lua), Triangle / Alt-F the camera edit
-- (CameraEdit.lua)
---------------------------------------------------------------------------
local owner = CreateFrame("Frame", "ImprovedForeverFishingModeBinds")
local PRESSES = {
    { keys = { "PAD2", "ESCAPE" }, run = function() Set(false) end },
    { keys = { "PADDUP", "UP" }, run = function() if F.Book and F.Book.Toggle then F.Book.Toggle() end end },
    { keys = { "PAD4", "ALT-F" }, run = function() if F.CameraStart then F.CameraStart() end end },
}
for i, press in ipairs(PRESSES) do
    local b = CreateFrame("Button", "ImprovedForeverFishingPress" .. i, UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(self, _, down)
        if down then
            self.pressed = true
        elseif self.pressed then
            self.pressed = false
            press.run()
        end
    end)
    press.button = b:GetName()
end

local bound = false
local function BindPresses(want)
    if want == bound or InCombatLockdown() then return end
    bound = want
    ClearOverrideBindings(owner)
    if not want then return end
    for _, press in ipairs(PRESSES) do
        for _, key in ipairs(press.keys) do SetOverrideBindingClick(owner, true, key, press.button) end
    end
end

---------------------------------------------------------------------------
-- The presses watched: R2 twice, a right-click twice
---------------------------------------------------------------------------
-- (a double tap: down / up edges in, true on the second's release)
local function Tapper()
    return { down = false, taps = 0 }
end

local function Tap(t, down, now, ok, x, y)
    if down and not t.down then
        t.down, t.at, t.x, t.y = true, now, x, y
        t.second = ok and t.taps == 1 and now - t.first <= DOUBLE
        if not ok then t.taps = 0 end
    elseif not down and t.down then
        t.down = false
        local moved = x and t.x and math.abs(x - t.x) + math.abs(y - t.y) > STILL
        if not ok or now - t.at > TAP or moved then
            t.taps = 0
        elseif t.second then
            t.taps = 0
            return true
        else
            t.taps, t.first = 1, t.at
        end
    end
    return false
end

local r2, right = Tapper(), Tapper()
local lastFree = false

-- Nothing else open (the last look): a press of the world's
function F.NothingOpen()
    return lastFree
end
local openAt = -math.huge

local function OverWorld()
    local foci = GetMouseFoci and GetMouseFoci()
    local f = foci and foci[1]
    if not foci and GetMouseFocus then f = GetMouseFocus() end
    return f == nil or f == WorldFrame
end

local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
    if not IF.db then return end
    local now = GetTime()
    if on and not CanFish() then Set(false) end
    local other = OtherOpen()
    if other then openAt = now end
    local free = not other and now - openAt > QUIET
    lastFree = free
    -- (the camera edit has its own presses, CameraEdit.lua)
    local editing = F.CameraEditing and F.CameraEditing()
    BindPresses(on and free and not editing)
    if not IsKeyDown then return end
    if on then
        r2.down, r2.taps, right.down, right.taps = IsKeyDown(ENTER_KEY), 0, false, 0
    else
        local can = free and CanFish()
        if Tap(r2, IsKeyDown(ENTER_KEY), now, can) then Set(true) end
        local x, y = GetCursorPosition()
        local clicked = IsMouseButtonDown and IsMouseButtonDown("RightButton") or false
        if Tap(right, clicked, now, can and OverWorld(), x, y) then Set(true) end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function()
    if on and not CanFish() then Set(false) end
end)

-- (in it at a /reload: still, with the pole in hand)
IF.OnLogin(function()
    if IF.charDB and IF.charDB.fishingMode and CanFish() then
        Set(true)
    elseif IF.charDB then
        IF.charDB.fishingMode = nil
    end
end)

---------------------------------------------------------------------------
-- The guide line: how to start, a pole in hand; how to stop, in the mode
---------------------------------------------------------------------------
local guide = CreateFrame("Frame", "ImprovedForeverFishingGuide", UIParent)
guide:SetSize(10, 48)
guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -14)
guide:SetFrameStrata("MEDIUM")
guide:EnableMouse(false)
guide:SetAlpha(0)
guide:Hide()
local icon = guide:CreateTexture(nil, "ARTWORK")
icon:SetTexture(IF.TEX .. "ic_mod_fishing")
icon:SetSize(40, 40)
icon:SetPoint("LEFT", 18, 0)
local text = guide:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
text:SetShadowOffset(1, -1)
text:SetShadowColor(0, 0, 0, 1)
-- (a soft dark band behind, from the screen's edge, fading out to the right)
local left = guide:CreateTexture(nil, "BACKGROUND")
left:SetTexture("Interface\\Buttons\\WHITE8x8")
left:SetPoint("TOPLEFT")
left:SetPoint("BOTTOMRIGHT", guide, "BOTTOM")
left:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0.55))
local right_ = guide:CreateTexture(nil, "BACKGROUND")
right_:SetTexture("Interface\\Buttons\\WHITE8x8")
right_:SetPoint("TOPLEFT", guide, "TOP")
right_:SetPoint("BOTTOMRIGHT")
right_:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))

local GOLD = "|cffffd100"
local function Glyph(key)
    return IF.GlyphText and IF.GlyphText(key, 32) or key
end

local function MouseRight()
    local atlas = "newplayertutorial-icon-mouse-rightbutton"
    local has = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    return has and ("|A:" .. atlas .. ":34:28|a ") or ""
end

-- (a key on the keyboard, as the line shows it)
local function Key(text)
    return "|cffffffff" .. text .. "|r"
end

local function Line(fishing)
    local pad = IF.Input.Pad()
    -- (the camera edit, CameraEdit.lua: its presses)
    if F.CameraEditing and F.CameraEditing() then
        if pad then
            return Glyph("PADLTRIGGER") .. Glyph("PADRTRIGGER") .. " Closer / further     "
                .. Glyph("PADLSHOULDER") .. Glyph("PADRSHOULDER") .. " Left / right     "
                .. Glyph("PADDUP") .. Glyph("PADDDOWN") .. " Lower / higher     "
                .. Glyph("PAD1") .. " " .. GOLD .. "Keep|r     " .. Glyph("PAD2") .. " Leave"
        end
        return Key("Mouse wheel") .. "  Closer / further     " .. Key("A / D") .. "  Left / right     "
            .. Key("W / S") .. "  Lower / higher     " .. Key("Enter") .. "  " .. GOLD .. "Keep|r     "
            .. Key("Esc") .. "  Leave"
    end
    local camera = F.Settings().camera and F.Settings().view
    if not fishing then
        if pad then return Glyph(ENTER_KEY) .. Glyph(ENTER_KEY) .. "  " .. GOLD .. "Start fishing|r" end
        return MouseRight() .. "Double right-click  " .. GOLD .. "Start fishing|r"
    end
    if pad then
        return Glyph(ENTER_KEY) .. " Cast     " .. Glyph(ENTER_KEY) .. Glyph(ENTER_KEY) .. " Lure     "
            .. Glyph("PADDUP") .. " Collection     " .. (camera and (Glyph("PAD4") .. " Camera     ") or "")
            .. Glyph(EXIT_KEY) .. " " .. GOLD .. "Stop fishing|r"
    end
    return Key("Up") .. "  Collection     " .. (camera and (Key("Alt + F") .. "  Camera     ") or "")
        .. Key("Esc") .. "  " .. GOLD .. "Stop fishing|r"
end

-- (start: bright a while, then quieter; in it: quiet)
local BRIGHT, QUIET_ALPHA, FADE = 6, 0.55, 0.25
local shownText, since = nil, 0
guide:SetScript("OnUpdate", function(self, elapsed)
    local alpha = self:GetAlpha()
    local goal = self.goal or 0
    alpha = goal > alpha and math.min(goal, alpha + elapsed / FADE) or math.max(goal, alpha - elapsed / FADE)
    self:SetAlpha(alpha)
    if alpha <= 0 and goal <= 0 then self:Hide() end
end)

F.Watcher("fishing guide", 0.1, function()
    local fishing = on
    local editing = F.CameraEditing and F.CameraEditing()
    local want = (editing or F.Settings().guide and (fishing or CanFish()) and not OtherOpen())
        and not (F.BarBusy and F.BarBusy() and not fishing) or false
    if not want then
        guide.goal = 0
        shownText = nil
        return
    end
    local line = Line(fishing)
    if line ~= shownText then
        shownText = line
        text:SetText(line)
        guide:SetWidth(18 + 40 + 10 + text:GetStringWidth() + 70)
        since = GetTime()
    end
    -- (the camera edit's at full: what it does is all there is to read)
    guide.goal = (editing or not fishing and GetTime() - since < BRIGHT) and 1 or QUIET_ALPHA
    guide:Show()
end)
