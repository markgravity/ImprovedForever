-- Fishing mode: a pole in hand isn't fishing yet. A line on the screen says
-- how to start: R2 twice (the controller), or a double right-click on the
-- world (the mouse). In it, R2 casts (Fishing.lua), the HUD steps back and
-- the camera comes in (View.lua), the session runs (Session.lua), auto
-- loot is on (AutoLoot.lua); the line then says how to stop: Circle or
-- Esc. Out of it by those, the pole put away, a fight, or dying.
-- Esc and Circle stop it only when nothing else is open (a window, the
-- bags, a dialog, one of ours, the game's pad focus on a window): else
-- they're that thing's, to close it. Esc: an override binding of ours,
-- only then (cleared the moment something opens). Circle and R2's double
-- press: watched, not taken (they're the game's crossbar presses: never
-- bound over, Native.lua), the press counted only if it began with nothing
-- open; R2 a tap each (held, it pages the crossbar). Kept per character
-- through a /reload (IF.charDB.fishingMode).
local IF = ImprovedForever
local F = IF.Fishing

local DOUBLE, TAP, STILL = 0.45, 0.3, 8     -- (a double press: the second within DOUBLE; each under TAP; the mouse moved under STILL px)
local QUIET = 0.3                           -- (something closed lately: its press, not ours)
local ENTER_KEY, EXIT_KEY = "PADRTRIGGER", "PAD2"
local COMBO = { "PADLTRIGGER", "PADLSHOULDER", "PADRSHOULDER", "PADRTRIGGER" }  -- (held with Circle: another press)

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
-- Esc: ours only while in the mode with nothing else open
---------------------------------------------------------------------------
local owner = CreateFrame("Frame", "ImprovedForeverFishingModeBinds")
local stop = CreateFrame("Button", "ImprovedForeverFishingStop", UIParent)
stop:SetSize(1, 1)
stop:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
stop:RegisterForClicks("AnyDown")
stop:SetScript("OnClick", function() Set(false) end)

local escBound = false
local function BindEscape(want)
    if want == escBound or InCombatLockdown() then return end
    escBound = want
    ClearOverrideBindings(owner)
    if want then SetOverrideBindingClick(owner, false, "ESCAPE", stop:GetName()) end
end

---------------------------------------------------------------------------
-- The presses watched: R2 twice, a right-click twice, Circle
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
local circle = { down = false }
local openAt = -math.huge

local function OverWorld()
    local foci = GetMouseFoci and GetMouseFoci()
    local f = foci and foci[1]
    if not foci and GetMouseFocus then f = GetMouseFocus() end
    return f == nil or f == WorldFrame
end

local function ComboHeld()
    for _, key in ipairs(COMBO) do
        if IsKeyDown(key) then return true end
    end
    return false
end

local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
    if not IF.db then return end
    local now = GetTime()
    if on and not CanFish() then Set(false) end
    local other = OtherOpen()
    if other then openAt = now end
    local free = not other and now - openAt > QUIET
    BindEscape(on and free)
    if not IsKeyDown then return end
    if on then
        -- (Circle alone, begun with nothing open: on its release)
        local down = IsKeyDown(EXIT_KEY)
        if down and not circle.down then
            circle.ours = free and not ComboHeld()
        elseif not down and circle.down and circle.ours and free then
            Set(false)
        end
        circle.down = down
        r2.down, r2.taps, right.down, right.taps = IsKeyDown(ENTER_KEY), 0, false, 0
    else
        local can = free and CanFish()
        if Tap(r2, IsKeyDown(ENTER_KEY), now, can) then Set(true) end
        local x, y = GetCursorPosition()
        local clicked = IsMouseButtonDown and IsMouseButtonDown("RightButton") or false
        if Tap(right, clicked, now, can and OverWorld(), x, y) then Set(true) end
        circle.down = IsKeyDown(EXIT_KEY)
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

local function Line(fishing)
    local pad = IF.Input.Pad()
    if not fishing then
        if pad then return Glyph(ENTER_KEY) .. Glyph(ENTER_KEY) .. "  " .. GOLD .. "Start fishing|r" end
        return MouseRight() .. "Double right-click  " .. GOLD .. "Start fishing|r"
    end
    if pad then
        return Glyph(ENTER_KEY) .. " Cast     " .. Glyph(ENTER_KEY) .. Glyph(ENTER_KEY) .. " Lure     "
            .. Glyph(EXIT_KEY) .. " " .. GOLD .. "Stop fishing|r"
    end
    return "Esc  " .. GOLD .. "Stop fishing|r"
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
    local want = F.Settings().guide and (fishing or CanFish()) and not OtherOpen()
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
    guide.goal = (not fishing and GetTime() - since < BRIGHT) and 1 or QUIET_ALPHA
    guide:Show()
end)
