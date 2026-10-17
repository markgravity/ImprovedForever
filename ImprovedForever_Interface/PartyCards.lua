-- Minions and party as cards standing on the experience line along the
-- screen's bottom edge (XPBar.lua): your pet on the left of the middle
-- ("Minions"), your party's four on the right ("Party"), each a card in
-- the look of the rest of the bottom: the avatar the player's has too
-- (UnitFrames.lua: the unit's model in the game's tooltip border, a strip
-- along its top in its class colour (a minion's gold, grey when dead or
-- offline), its level at the top left); along its foot, on a dark band,
-- its name over its health and power in our bars (the casting bar's
-- frame, as the player's).
-- Faint when out of range.
-- Each card is a secure unit button (a click targets, a right click opens
-- the unit's menu) in a place of its own, shown by the game's state
-- driver (the pet's unit watch; a party member's: there and not in a
-- raid), so nothing moves in a fight. The game's party frames (and its
-- pet frame) are drawn at 0 (IF.Focus.Fade), a frame of ours over them
-- taking the mouse.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PC = {}
IN.PartyCards = PC

local CARD_W, CARD_H, GAP, GROUP_GAP = 76, 100, 8, 40
local HEALTH_H, POWER_H, BAR_GAP, INSET = 14, 11, 0, 4
local NAME_H = 14
local BOTTOM = 4        -- (the cards' bottom: on top of the experience line, LINE_H in XPBar.lua)
local HEALTH_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local POWER_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-"

local Try, Flag, Text, Bar = UF.Try, UF.Flag, UF.Text, UF.Bar

---------------------------------------------------------------------------
-- A card: the avatar (UnitFrames.lua, as the player's), along its foot on
-- a dark band its name over its health and power
---------------------------------------------------------------------------
local function Card(name, unit)
    local b = UF.UnitButton(name, unit, CARD_W, CARD_H)
    b:Hide()
    b.avatar = UF.Avatar(b, CARD_W, CARD_H)
    b.avatar:SetAllPoints()
    b.portrait = b.avatar.portrait

    local over = b.avatar.over
    local shade = over:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("BOTTOMLEFT", INSET, INSET)
    shade:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    shade:SetHeight(POWER_H + HEALTH_H + NAME_H + 4)
    shade:SetColorTexture(0, 0, 0, 0.65)

    b.power = Bar(over, CARD_W - 2 * INSET + 2, POWER_H, POWER_FILL .. "Mana")
    b.power.box:SetPoint("BOTTOM", 0, INSET - 1)
    b.health = Bar(over, CARD_W - 2 * INSET + 2, HEALTH_H, HEALTH_FILL)
    b.health.box:SetPoint("BOTTOM", b.power.box, "TOP", 0, BAR_GAP)
    local small = _G.TextStatusBarTextSmall or _G.SystemFont_Shadow_Small
    if small then
        b.health.text:SetFontObject(small)
        b.power.text:SetFontObject(small)
    end
    b.name = Text(over, "GameFontNormalSmall")
    b.name:SetPoint("BOTTOMLEFT", b.health.box, "TOPLEFT", 2, 1)
    b.name:SetPoint("BOTTOMRIGHT", b.health.box, "TOPRIGHT", -2, 1)
    b.name:SetHeight(NAME_H)
    return b
end

-- Its colour: a minion's gold, a party member's class, grey when dead or
-- offline
local function CardColor(b)
    local unit = b.unit
    if Flag(UnitIsDeadOrGhost, unit) or (b.isParty and not Flag(UnitIsConnected, unit)) then return UF.GREY end
    if not b.isParty then return UF.GOLD end
    return UF.ClassColor(unit) or UF.GOLD
end

-- Out of range: faint (a secret answer: as in range)
local function Near(unit)
    local ok, near = pcall(function()
        local inRange, checked = UnitInRange(unit)
        if checked == true and inRange == false then return false end
        return true
    end)
    return not ok or near
end

local function Refresh(b)
    local unit = b.unit
    if not UnitExists(unit) then return end
    UF.AvatarUnit(b.avatar, unit)
    Try(b.name.SetText, b.name, UnitName(unit))
    UF.NameColor(b)
    local c = CardColor(b)
    UF.AvatarLook(b.avatar, unit, c, c == UF.GREY)
    UF.FillHealth(b)
    UF.FillPower(b)
    b:SetAlpha(Near(unit) and 1 or 0.55)
end

local MODEL_EVENTS = UF.MODEL_EVENTS

local function Listen(b)
    for _, e in ipairs(UF.Join(UF.UNIT, UF.POWER_EVENTS)) do b:RegisterUnitEvent(e, b.unit) end
    for _, e in ipairs({ "UNIT_LEVEL", "UNIT_CONNECTION" }) do b:RegisterUnitEvent(e, b.unit) end
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" }) do
        b:RegisterEvent(e)
    end
    b.Refresh = Refresh
    b:SetScript("OnEvent", function(self, event)
        if not UnitExists(self.unit) then return end
        if MODEL_EVENTS[event] then UF.AvatarUnit(self.avatar, self.unit, true) end
        Refresh(self)
    end)
    b:SetScript("OnShow", function(self)
        UF.AvatarUnit(self.avatar, self.unit, true)
        Refresh(self)
    end)
end

---------------------------------------------------------------------------
-- The two groups, each side of the middle, a label over each
---------------------------------------------------------------------------
local minions = { Card("ImprovedForeverMinionCard1", "pet") }
minions[1]:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -GROUP_GAP / 2, BOTTOM)

local party = {}
for i = 1, 4 do
    local b = Card("ImprovedForeverPartyCard" .. i, "party" .. i)
    b.isParty = true
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", GROUP_GAP / 2 + (i - 1) * (CARD_W + GAP), BOTTOM)
    party[i] = b
end

for _, b in ipairs(minions) do Listen(b) end
for _, b in ipairs(party) do Listen(b) end

local function Label(text, anchor, point)
    local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(0.75, 0.75, 0.75)
    fs:SetPoint(point, anchor, "TOP" .. point, 0, 8)
    fs:Hide()
    return fs
end
local minionLabel = Label("Minions", minions[1], "RIGHT")
local partyLabel = Label("Party", party[1], "LEFT")

local function AnyShown(list)
    for _, b in ipairs(list) do
        if b:IsShown() then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The game's party and pet frames drawn at 0 while ours show (Edit Mode:
-- the game's shown, ours drawn at 0); the labels with their groups; the
-- range a few times a second
---------------------------------------------------------------------------
local function Natives()
    return { PartyFrame, CompactPartyFrame, PetFrame }
end

local function Watch()
    if not IF.db then return end
    local on = IN.Settings().cards
    local edit = UF.EditMode()
    for _, native in ipairs(Natives()) do
        IF.Focus.Fade(native, on and not edit)
        UF.Cover(native, on and not edit)
    end
    local alpha = edit and 0 or 1
    for _, list in ipairs({ minions, party }) do
        for _, b in ipairs(list) do
            if b:IsShown() then
                b:SetAlpha(edit and 0 or (Near(b.unit) and 1 or 0.55))
            end
        end
    end
    minionLabel:SetShown(on and alpha > 0 and AnyShown(minions))
    partyLabel:SetShown(on and alpha > 0 and AnyShown(party))
end

IN.Watcher("cards", 0.2, Watch)

---------------------------------------------------------------------------
-- Shown or not (secure frames: out of combat only, else after it)
---------------------------------------------------------------------------
local pending

local function Driven(b, on, condition)
    if on and not b.driven then
        RegisterStateDriver(b, "visibility", condition)
        b.driven = true
    elseif not on and b.driven then
        UnregisterStateDriver(b, "visibility")
        b.driven = nil
        b:Hide()
    end
end

function PC.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = nil
    local on = IN.Settings().cards
    for _, b in ipairs(minions) do UF.Watched(b, on) end
    for i, b in ipairs(party) do
        Driven(b, on, "[group:raid] hide; [@party" .. i .. ",exists] show; hide")
    end
    Watch()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then PC.Apply() end
end)

IF.OnLogin(PC.Apply)
