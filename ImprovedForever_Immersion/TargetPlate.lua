-- The target's own nameplate, in the module's look: its name in gold
-- (the header's font), under it a thin line in the nameplate's colour over
-- a dark track, its level in the small circle at the line's end. Drawn by
-- a frame of ours anchored to the game's plate (a plain anchor: probe
-- verified taint-free; the plate is never measured, read or changed), and
-- the game's own plate for the target (its UnitFrame) drawn at alpha 0 by an animation of
-- ours (IF.Focus.Fade). Other units keep the game's plates. Health can be
-- secret: handed to the bar, never compared.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot
local UF = IN.UnitFrames
local TH = IN.TargetHeader

local Try, Flag, Secret = UF.Try, UF.Flag, UF.Secret

local W, LINE_H, BADGE = 110, 4, 20
local TRACK = { 0, 0, 0, 0.55 }
local NAME_SIZE = 13
local STEP = 0.1

local plate = CreateFrame("Frame", "ImprovedForeverTargetPlate", UIParent)
plate:SetSize(W, LINE_H)
plate:SetFrameStrata("LOW")
plate:EnableMouse(false)
plate:Hide()

local track = plate:CreateTexture(nil, "BACKGROUND")
track:SetAllPoints()
track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
local bar = CreateFrame("StatusBar", nil, plate)
bar:SetAllPoints()
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
bar:SetMinMaxValues(0, 1)
bar:SetValue(1)

local name = HS.Text(plate, HS.FONT, NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
name:SetPoint("BOTTOM", plate, "TOP", 0, 3)
name:SetWidth(W * 1.6)

local badge = plate:CreateTexture(nil, "OVERLAY", nil, 2)
badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
badge:SetSize(BADGE, BADGE)
badge:SetPoint("LEFT", plate, "RIGHT", 2, 0)
local level = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
level:SetDrawLayer("OVERLAY", 3)
level:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
local skull = plate:CreateTexture(nil, "OVERLAY", nil, 4)
skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
skull:SetPoint("CENTER", badge, "CENTER")
skull:Hide()

local function Fill()
    local value, max = UnitHealth("target"), UnitHealthMax("target")
    if not Try(bar.SetMinMaxValues, bar, 0, max) or not Try(bar.SetValue, bar, value) then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end
end

local function Level()
    local ok, l, r, g, b = pcall(function()
        local v = UnitLevel("target")
        if Secret(v) then error("secret") end
        if not v or v <= 0 then return nil end
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(v)
        return v, color.r, color.g, color.b
    end)
    skull:SetShown(ok and not l)
    if ok and l then
        level:SetText(l)
        level:SetTextColor(r, g, b)
    else
        level:SetText("")
    end
end

local function Refresh()
    Try(name.SetText, name, UnitName("target"))
    if Flag(UnitIsDeadOrGhost, "target") then
        name:SetTextColor(0.5, 0.5, 0.5)
    else
        name:SetTextColor(HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
    end
    Fill()
    local r, g, b = TH.NameplateColor("target")
    bar:SetStatusBarColor(r, g, b)
    Level()
end

-- (the game's plate we hide, so it can be shown again: its UnitFrame, the
-- plate's whole look; the plate frame itself and its children alone don't
-- need it)
local hidden

local function Hide(game, on)
    local ok, unitFrame = pcall(function() return game.UnitFrame end)
    if ok and type(unitFrame) == "table" then pcall(IF.Focus.Fade, unitFrame, on) end
end

local function Release()
    if hidden then
        Hide(hidden, false)
        hidden = nil
    end
    plate:Hide()
end

local function Place()
    local s = IN.Settings()
    if not s.target or s.targetPlate == false or UF.EditMode() or not UnitExists("target") then return Release() end
    local game = C_NamePlate.GetNamePlateForUnit("target")
    if not game then return Release() end
    if hidden ~= game then
        if hidden then Hide(hidden, false) end
        Hide(game, true)
        hidden = game
    end
    plate:ClearAllPoints()
    plate:SetPoint("CENTER", game, "CENTER", 0, 0)
    plate:Show()
    Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
    if unit and unit ~= "target" then return end
    Place()
end)

local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not plate:IsShown() then return end
    since = since + elapsed
    if since < STEP then return end
    since = 0
    if not UnitExists("target") then return Release() end
    Refresh()
end)
