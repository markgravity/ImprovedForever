-- Minions and party as cards standing on the experience line along the
-- screen's bottom edge (XPBar.lua): your pet on the left of the middle
-- ("Minions"), your party's four on the right ("Party"), each a card: the
-- unit's model (its round portrait when it's too far to be drawn), a
-- border in its class colour (a minion's gold, grey when dead or offline),
-- its level in the game's small circle at the top left; along its foot,
-- on a dark band, its name over its health and power bars (their percent
-- on them). Faint when out of range.
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
local HEALTH_H, POWER_H, BAR_GAP, INSET = 10, 8, 2, 3
local NAME_H = 13
local BOTTOM = 4        -- (the cards' bottom: on top of the experience line, LINE_H in XPBar.lua)
local ZOOM = 0.45
local HEALTH_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local POWER_FILL = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-"
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.45, 0.45, 0.45 }

local Try, Flag, Text, Atlas = UF.Try, UF.Flag, UF.Text, UF.Atlas

---------------------------------------------------------------------------
-- A card
---------------------------------------------------------------------------
local function Edge(parent, layer)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

-- A bar inside a card: the unit frames' fill on a dark track, its
-- percent on it in a small font (the text Fill writes, UnitFrames.lua)
local function MiniBar(parent, atlas, h)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(h)
    bar:SetStatusBarTexture(atlas)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.7)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
    bar.text:SetPoint("CENTER", 0, 0.5)
    local tiny = _G.SystemFont_Tiny or _G.SystemFont_Shadow_Small
    if tiny then bar.text:SetFontObject(tiny) end
    bar.text:SetShadowOffset(1, -1)
    return bar
end

local function Card(name, unit)
    local b = UF.UnitButton(name, unit, CARD_W, CARD_H)
    b:Hide()

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.92)

    b.portrait = b:CreateTexture(nil, "ARTWORK")
    b.portrait:SetPoint("CENTER", 0, 6)
    b.portrait:SetSize(CARD_W - 16, CARD_W - 16)
    b.model = CreateFrame("PlayerModel", nil, b)
    b.model:SetPoint("TOPLEFT", 3, -3)
    b.model:SetPoint("BOTTOMRIGHT", -3, 3)

    -- (over the model: its border, the level, the name and bars)
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.model:GetFrameLevel() + 2)
    local shade = over:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("BOTTOMLEFT", INSET, INSET)
    shade:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    shade:SetHeight(POWER_H + BAR_GAP + HEALTH_H + NAME_H + 3)
    shade:SetColorTexture(0, 0, 0, 0.6)
    b.edges = {}
    local function E(p1, p2, w, h)
        local t = Edge(over, "BORDER")
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        b.edges[#b.edges + 1] = t
    end
    E("TOPLEFT", "TOPRIGHT", nil, 2)
    E("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    E("TOPLEFT", "BOTTOMLEFT", 2, nil)
    E("TOPRIGHT", "BOTTOMRIGHT", 2, nil)

    b.gem = Atlas(over, "OVERLAY", "UI-HUD-UnitFrame-SmallCircle", 1)
    b.gem:SetSize(24, 24)
    b.gem:SetPoint("CENTER", b, "TOPLEFT", 6, -6)
    b.level = Text(over, "GameFontHighlightSmall")
    b.level:SetDrawLayer("OVERLAY", 2)
    b.level:SetPoint("CENTER", b.gem, "CENTER", 0, -0.5)
    -- (along its foot: the power bar, the health bar over it, the name
    -- over that)
    b.power = MiniBar(over, POWER_FILL .. "Mana", POWER_H)
    b.power:SetPoint("BOTTOMLEFT", INSET, INSET)
    b.power:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    b.health = MiniBar(over, HEALTH_FILL, HEALTH_H)
    b.health:SetPoint("BOTTOMLEFT", b.power, "TOPLEFT", 0, BAR_GAP)
    b.health:SetPoint("BOTTOMRIGHT", b.power, "TOPRIGHT", 0, BAR_GAP)
    b.name = Text(over, "GameFontNormalSmall")
    b.name:SetPoint("BOTTOMLEFT", b.health, "TOPLEFT", 1, 1)
    b.name:SetPoint("BOTTOMRIGHT", b.health, "TOPRIGHT", -1, 1)
    b.name:SetHeight(NAME_H)
    return b
end

-- Its colour: a minion's gold, a party member's class, grey when dead or
-- offline
local function CardColor(b)
    local unit = b.unit
    if Flag(UnitIsDeadOrGhost, unit) or (b.isParty and not Flag(UnitIsConnected, unit)) then return GREY end
    if not b.isParty then return GOLD end
    local ok, c = pcall(function()
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        return color and { color.r, color.g, color.b }
    end)
    return ok and c or GOLD
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

-- Its model, drawn only when the unit is (else its portrait)
local function RefreshModel(b)
    local unit = b.unit
    local visible = Flag(UnitIsVisible, unit)
    b.model:SetShown(visible)
    b.portrait:SetShown(not visible)
    SetPortraitTexture(b.portrait, unit)
    if visible then
        b.model:SetUnit(unit)
        b.model:SetPortraitZoom(ZOOM)
    end
    b.modelVisible = visible
end

local function Refresh(b)
    local unit = b.unit
    if not UnitExists(unit) then return end
    if Flag(UnitIsVisible, unit) ~= b.modelVisible then RefreshModel(b) end
    Try(b.name.SetText, b.name, UnitName(unit))
    UF.NameColor(b)
    local ok, level = pcall(function()
        local l = UnitLevel(unit)
        return (l and l > 0) and tostring(l) or "??"
    end)
    b.level:SetText(ok and level or "")
    local c = CardColor(b)
    for _, edge in ipairs(b.edges) do edge:SetVertexColor(c[1], c[2], c[3], 1) end
    b.portrait:SetDesaturated(c == GREY)
    UF.FillHealth(b)
    UF.FillPower(b)
    b:SetAlpha(Near(unit) and 1 or 0.55)
end

local MODEL_EVENTS = { UNIT_MODEL_CHANGED = true, UNIT_PORTRAIT_UPDATE = true, GROUP_ROSTER_UPDATE = true,
    UNIT_PET = true, PLAYER_ENTERING_WORLD = true }

local function Listen(b)
    for _, e in ipairs(UF.Join(UF.UNIT, UF.POWER_EVENTS)) do b:RegisterUnitEvent(e, b.unit) end
    for _, e in ipairs({ "UNIT_LEVEL", "UNIT_CONNECTION" }) do b:RegisterUnitEvent(e, b.unit) end
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" }) do
        b:RegisterEvent(e)
    end
    b.Refresh = Refresh
    b:SetScript("OnEvent", function(self, event)
        if not UnitExists(self.unit) then return end
        if MODEL_EVENTS[event] then RefreshModel(self) end
        Refresh(self)
    end)
    b:SetScript("OnShow", function(self)
        RefreshModel(self)
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
