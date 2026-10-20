-- In fishing mode (Mode.lua: a pole in hand, R2 twice), R2 is ours: pressed, it casts
-- Fishing; pressed twice quickly, it puts the best lure in your bags on
-- the pole (Aquadynamic Fish Attractor, Flesh Eating Worm, Bright Baubles,
-- Aquadynamic Fish Lens, Nightcrawlers, Shiny Bauble), stopping the cast
-- the first press began.
-- An override binding (with priority, as Override.lua's) to a secure
-- button running a macro, its double press told as Override.lua's: a plain
-- frame shown for DOUBLE seconds after each click, which the secure click
-- reads. Bound only while the game has the gamepad's focus (Binds.InGame:
-- no window of its gamepad UI holds it) and out of combat (bindings can't
-- change in one: kept as they were through it). R2 then doesn't page the
-- crossbar; out of the mode, it's the game's again.
local IF = ImprovedForever
local F = IF.Fishing

local KEY = "PADRTRIGGER"
local DOUBLE = 0.35
local FISHING = 7620            -- (Fishing, its first rank: /cast by name takes your best)
local MAIN_HAND = INVSLOT_MAINHAND or 16
local POLE_CLASS, POLE_SUBCLASS = 2, 20                 -- (a weapon, a fishing pole)
-- (lures, the strongest first: +100, +75, +75, +50, +50, +25)
local LURES = { 6533, 7307, 6532, 6811, 6530, 6529 }

local owner = CreateFrame("Frame", "ImprovedForeverFishingBinds")

local button = CreateFrame("Button", "ImprovedForeverFishingCast", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
button:SetSize(1, 1)
button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
button:SetAttribute("type", "macro")
-- (both edges: the one it acts on is ic-down's, Override.lua)
button:RegisterForClicks("AnyDown", "AnyUp")
local window = CreateFrame("Frame", nil, UIParent)
window:Hide()
window:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - elapsed
    if self.left <= 0 then self:Hide() end
end)
SecureHandlerSetFrameRef(button, "window", window)
-- The second click of a pair puts the lure on (none in the bags: nothing),
-- any other casts
SecureHandlerWrapScript(button, "OnClick", button, [[
    if not down ~= not self:GetAttribute("ic-down") then return false end
    local window = self:GetFrameRef("window")
    if window and window:IsShown() then
        local double = self:GetAttribute("ic-double")
        if not double then return false end
        self:SetAttribute("macrotext", double)
    else
        self:SetAttribute("macrotext", self:GetAttribute("ic-single"))
    end
    if not self:GetAttribute("macrotext") then return false end
]])
-- After each click: the window opens, or a pair just ended it
button:HookScript("OnClick", function(self, _, down)
    if not down ~= not self:GetAttribute("ic-down") then return end
    if window:IsShown() then
        window:Hide()
    else
        window.left = DOUBLE
        window:Show()
    end
end)

-- A fishing pole in the main hand
function F.PoleEquipped()
    local id = GetInventoryItemID("player", MAIN_HAND)
    if not id or not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    return classID == POLE_CLASS and subclassID == POLE_SUBCLASS
end

-- The best lure in the bags, or nil
function F.Lure()
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    for _, id in ipairs(LURES) do
        local ok, n = pcall(count, id)
        if ok and type(n) == "number" and n > 0 then return id end
    end
end

local function FishingName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING)
    return name or (GetSpellInfo and GetSpellInfo(FISHING)) or "Fishing"
end

-- (the button's macros: the cast, the lure's; only out of combat)
local function SetMacros()
    if InCombatLockdown() then return end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local onDown = get and get("ActionButtonUseKeyDown") ~= "0"
    button:SetAttribute("ic-down", onDown)
    button:SetAttribute("useOnKeyDown", onDown)
    button:SetAttribute("ic-single", "/cast " .. FishingName())
    local lure = F.Lure()
    button:SetAttribute("ic-double", lure and ("/stopcasting\n/use item:" .. lure .. "\n/use " .. MAIN_HAND) or nil)
end

-- R2 ours in fishing mode while the game has the gamepad's focus
local bound = false
local function Bind()
    if InCombatLockdown() or not IF.db then return end
    local want = F.InMode and F.InMode() and IF.Binds.InGame()
        and not (F.CameraEditing and F.CameraEditing()) or false
    if want == bound then return end
    bound = want
    ClearOverrideBindings(owner)
    if want then
        SetMacros()
        SetOverrideBindingClick(owner, true, KEY, button:GetName(), "LeftButton")
    end
end
F.Apply = Bind

owner:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
owner:RegisterEvent("BAG_UPDATE_DELAYED")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("CVAR_UPDATE")
owner:RegisterEvent("PLAYER_ENTERING_WORLD")
owner:SetScript("OnEvent", function()
    SetMacros()
    Bind()
end)
-- (the gamepad's focus has no event: read a few times a second)
local wait = 0
owner:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.1
    Bind()
end)
