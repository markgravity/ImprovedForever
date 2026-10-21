-- Square (X on Xbox, PAD3) is the game's Interact: on an enemy it swings
-- the melee weapon. With a wand in the ranged slot it shoots instead; on
-- anything else it stays the game's own press (a click on its button, so
-- talking, looting... go on as before). Override.lua binds the macro below
-- on PAD3 like any override of the Bindings tab. /if wandshoot turns it
-- off; IF.db.wandShoot = false.
local _, IF = ...

local W = {}
IF.WandShoot = W

local RANGED_SLOT = 18

local function Wielding()
    local id = GetInventoryItemID("player", RANGED_SLOT)
    if not id then return false end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    local wand = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Wand or 19
    return class == (Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2) and subclass == wand
end

local function ShootName()
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo("Shoot")
    return info and info.name
end

-- The game's crossbar button under Square (the left face button, the first
-- of its face group) for a layer of its bars: top (no trigger), left (L2),
-- right (R2), bottom (both). The top one is the game's own Interact. Named,
-- as a "/click" needs; nil while the bars aren't loaded.
local BARS = { [""] = "topBar", LT = "leftBar", RT = "rightBar", LTRT = "bottomBar" }

local function GameButton(layer)
    local main = _G.GamepadMainActionBarFrame
    local bars = main and main.PageUnit and main.PageUnit.actionBars
    local bar = bars and bars[BARS[layer]]
    local group = bar and bar.Right
    local button = group and group.ActionButton1
    return button and button.GetName and button:GetName()
end

local function Click(layer)
    local name = GameButton(layer)
    return name and ("/click " .. name .. " LeftButton true") or nil
end

-- The macros Square runs, or nil: off, no wand, Shoot not learned or the
-- game's bars not up. The first: "!" keeps a second press from switching
-- Shoot off. The second: what each layer with L2 / R2 held runs, the game's
-- button of that bar (R2 is no modifier, the key comes the same).
function W.Macro()
    if IF.db.wandShoot == false or not Wielding() then return nil end
    local name = ShootName()
    if not (name and GameButton("")) then return nil end
    local layers = {}
    for _, layer in ipairs({ "LT", "RT", "LTRT" }) do layers[layer] = Click(layer) end
    return "/cast [harm,nodead] !" .. name .. "", layers
end

-- Square is ours only while an enemy that lives is targeted: anything else
-- (loot, an NPC, an object) is the game's own press, untouched (a click of
-- ours on its button never auto looted). A state driver flips the binding
-- in secure code, so it follows the target in combat too.
local driver = CreateFrame("Frame", "ImprovedForeverWandDriver", UIParent, "SecureHandlerStateTemplate")
driver:SetAttribute("ic-eval", [[
    self:ClearBindings()
    if self:GetAttribute("ic-on") and self:GetAttribute("state-wand") == "shoot" then
        self:SetBindingClick(true, self:GetAttribute("ic-key"), self:GetAttribute("ic-button"), "LeftButton")
    end
]])
driver:SetAttribute("_onstate-wand", [[ self:RunAttribute("ic-eval") ]])
RegisterStateDriver(driver, "wand", "[harm,nodead] shoot; none")

-- Square's key and the secure button it runs while shooting; nil: off.
-- Out of combat only (Override.Apply)
function W.Bind(key, button)
    driver:SetAttribute("ic-key", key)
    driver:SetAttribute("ic-button", button)
    driver:SetAttribute("ic-on", key and true or nil)
    if not key then ClearOverrideBindings(driver) end
    SecureHandlerExecute(driver, [[ self:RunAttribute("ic-eval") ]])
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function() IF.Override.Apply() end)

IF.AddCommand("wandshoot", function()
    IF.db.wandShoot = IF.db.wandShoot == false
    IF.Override.Apply()
    IF.Print("Square shoots the wand: " .. (IF.db.wandShoot == false and "off" or "on"))
end, ": Square shoots your wand instead of a melee swing")
