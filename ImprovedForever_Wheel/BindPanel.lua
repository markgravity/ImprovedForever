-- "Bind to Action Bar" for a wheel's slot (Square on the ring): the game's
-- own bind panel (GamepadActionBarEditFrame:BindItem...) can't be opened
-- from here: it suspends the focused window and stacks binding groups,
-- and doing that from addon code taints the binding stack
-- (SetPreferredGamepadInteractTarget blocked). So this is a copy of it,
-- built from its own template and strings, the press caught with override
-- bindings of ours, and the action written to the crossbar the way the
-- Controller tab writes it (IF.Native.Set). Out of combat only.
--
-- While it's up: a D-pad or face button (with L2 / R2 held for their bars)
-- puts the action in that crossbar slot, on the page shown; Circle alone
-- goes back. L2 / R2 stay the game's, so its bars open as they're held.
local IF = ImprovedForever

local P = {}
IF.WheelBindPanel = P

local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
local BACK_KEY = "PAD2"

local panel, legend, current

-- The bar modifier held now (GAMEPADLEFTMOD / GAMEPADRIGHTMOD's key), or nil
local function HeldModifier()
    for _, name in ipairs({ "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD" }) do
        for _, key in ipairs({ GetBindingKey(name) }) do
            if IsKeyDown(key) then return key end
        end
    end
end

local function Build()
    if panel then return panel end
    -- The game's own bind info frame (border, glow, title box, instruction,
    -- name and icon), laid out as GamepadActionBarEditFrame places it
    local ok, frame = pcall(CreateFrame, "Frame", "ImprovedForeverBindPanel", UIParent,
        "GamepadActionBarEditBindingsInfoFrameTemplate")
    if not ok or not frame then return nil end
    panel = frame
    panel:SetSize(485, 180)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 75)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()

    legend = IF.InputLegend(panel)
    legend:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -6)

    -- The presses (an override binding's click: the key comes as the button)
    local catch = CreateFrame("Button", "ImprovedForeverBindCatch", UIParent)
    catch:RegisterForClicks("AnyDown")
    catch:SetScript("OnClick", function(_, key) P.Press(key) end)

    panel:SetScript("OnShow", function(self)
        if IF.InCombat() then return end
        local keys = { [BACK_KEY] = true }
        for n = 1, 8 do
            for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. n) }) do keys[key] = true end
        end
        for key in pairs(keys) do
            for _, modifier in ipairs(MODIFIERS) do
                SetOverrideBindingClick(self, true, modifier .. key, catch:GetName(), key)
            end
        end
    end)
    panel:SetScript("OnHide", function(self)
        if not IF.InCombat() then ClearOverrideBindings(self) end
        current = nil
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    -- Closed when a game window takes the pad (the bags...): its own buttons
    panel:SetScript("OnUpdate", function()
        if IF.Binds and not IF.Binds.InGame() then P.Close() end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function() P.Close() end)

    -- The ring opening (R3) takes the same buttons: this one goes
    local ring = _G.ImprovedForeverRing
    if ring then ring:HookScript("OnShow", function() P.Close() end) end
    return panel
end

function P.Close()
    if panel and panel:IsShown() and not IF.InCombat() then panel:Hide() end
end

-- Opens it for an action ("item:<id>", "spell:<id>", "macro:<name>"); false
-- if it can't (in combat, no crossbar)
function P.Open(action)
    if IF.InCombat() or not (IF.Native and IF.Native.Available()) or not Build() then return false end
    local name, icon = IF.ActionInfo(action)
    if not name then return false end
    current = action
    panel.ActionName:SetText(name)
    panel.ActionIcon:SetTexture(icon or 134400)
    legend:Set({ { BACK_KEY, "B", _G.FRAME_ACTION_BACK or BACK } })

    -- Its tooltip on the right, as the game's
    local kind, value = action:match("^(%a+):(.+)$")
    local tip = GameTooltip
    if kind == "item" or kind == "spell" then
        tip:SetOwner(panel, "ANCHOR_NONE")
        tip:ClearAllPoints()
        tip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 5, -15)
        if kind == "item" then tip:SetItemByID(tonumber(value)) else tip:SetSpellByID(tonumber(value)) end
        tip:Show()
    elseif tip:GetOwner() == panel then
        tip:Hide()
    end
    panel:Show()
    return true
end

-- A press while it's up: a crossbar slot takes the action; Circle alone
-- goes back; anything else (the top bar's face buttons: jump...) nothing
function P.Press(key)
    if not (panel and panel:IsShown() and current) or IF.InCombat() then return end
    local held = HeldModifier()
    if key == BACK_KEY and not held then
        P.Close()
        return
    end
    local spec = IF.Binds.Spec(held, key)
    if not IF.Native.SlotOf(spec) then return end
    if IF.Native.Set(spec, current) then
        if IF.Vibe then IF.Vibe.Fire("wheelTick") end
        P.Close()
    end
end
