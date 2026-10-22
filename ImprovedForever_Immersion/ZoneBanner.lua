-- The zone's name as you enter it, ours in place of the game's (its zone
-- and subzone text, drawn at 0 by IF.Focus.Fade, never touched): in the
-- quest arrow's place and look (QuestArrow.lua's header, the camp
-- summary's): the gold rule, on it a flat diamond (the spell diamonds'
-- tile, GamepadBar.lua) with the zone's own picture inside (Spoken's, as
-- its Compendium shows it: a dungeon's key, a zone's or its parent's art),
-- else its kind (a battleground, a town, your side's land or the other's,
-- fought over),
-- under it the name big, the subzone (or the zone) small and white under
-- that, the game's PvP words in their colour under those.
-- It comes when the game would show its own (its frames' showing read),
-- holds a while and goes, first in the header's place (HeaderSlot.lua):
-- what had it goes out (the quest arrow's gem spins down to nothing), then
-- the diamond pops up and the name comes in; going, the same backwards.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot

local ZB = {}
IN.ZoneBanner = ZB

local HOLD = 4                          -- (seconds shown, once in)
local SWAP = 1                          -- (the change over: what has the place out, the name in)
local TILE = 30                         -- (the diamond's tile: a size as the spell diamonds')
local ROOT2 = math.sqrt(2)
local TURN = HS.TILE_TURN
local SLIDE = 10                        -- (the name comes up from this far down)
local MAP_ICON = "Interface\\Icons\\INV_Misc_Map_01"

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function Words(v)
    return type(v) == "string" and not Secret(v) and v ~= "" and v or nil
end

---------------------------------------------------------------------------
-- The banner
---------------------------------------------------------------------------
local banner = CreateFrame("Frame", "ImprovedForeverZoneBanner", UIParent)
banner:SetSize(260, 120)
banner:SetFrameStrata("LOW")
banner:EnableMouse(false)
banner:SetPoint("CENTER", UIParent, "TOP", 0, -HS.RULE_Y)
banner:Hide()

local name = HS.Text(banner, HS.FONT, HS.NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
name:SetWidth(2 * HS.RULE_W)
local sub = HS.Text(banner, GameFontHighlight and GameFontHighlight:GetFont(), HS.SMALL_SIZE, 1, 1, 1)
sub:SetPoint("TOP", name, "BOTTOM", 0, -4)
local pvp = HS.Text(banner, GameFontHighlight and GameFontHighlight:GetFont(), HS.SMALL_SIZE, 1, 1, 1)
pvp:SetPoint("TOP", sub, "BOTTOM", 0, -4)

-- (the diamond, its picture upright inside, cut to the diamond)
local tile = HS.Tile(banner, TILE)
local icon, side = tile.icon, tile.side

---------------------------------------------------------------------------
-- The zone's picture: Spoken's (its Compendium's: a dungeon's or raid's
-- badge, a zone's art or its nearest parent's), else its kind's symbol (an
-- atlas, upright), else the map's icon
---------------------------------------------------------------------------
local function Atlas(name)
    return IF.HasAtlas and IF.HasAtlas(name) and name or nil
end

local function Kind()
    local inside, kind = IsInInstance()
    if inside then
        if kind == "raid" then return Atlas("Raid") or Atlas("Dungeon") end
        if kind == "party" or kind == "scenario" then return Atlas("Dungeon") end
        if kind == "pvp" or kind == "arena" then return Atlas("CrossedFlags") end
    end
    local pvpType = GetZonePVPInfo and GetZonePVPInfo()
    if pvpType == "sanctuary" then return Atlas("poi-town") end
    if pvpType == "contested" or pvpType == "combat" or pvpType == "arena" then return Atlas("CrossedFlags") end
    if IsResting() then return Atlas("poi-town") end
    local mine = UnitFactionGroup("player")
    if pvpType == "friendly" or pvpType == "hostile" then
        local horde = (mine == "Horde") == (pvpType == "friendly")
        return Atlas(horde and "HordeSymbol" or "AllianceSymbol")
    end
    return nil
end

-- (Spoken's picture for where you are, and its crop)
local function SpokenIcon()
    if not Spoken then return nil end
    local inside, kind = IsInInstance()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if inside and (kind == "party" or kind == "raid") and Spoken.DungeonIcon then
        return Spoken:DungeonIcon(map)
    end
    if map and Spoken.ZoneIcon then return Spoken:ZoneIcon(map) end
end

local function SetKind()
    icon:SetRotation(0)
    icon:SetTexCoord(0, 1, 0, 1)
    -- (a picture upright, as big as the diamond's width: the diamond cuts it)
    local ok, picture, crop = pcall(SpokenIcon)
    if ok and picture then
        icon:SetTexture(picture)
        if type(crop) == "table" then icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4]) end
        icon:SetSize(side * ROOT2 * 0.94, side * ROOT2 * 0.94)
        return
    end
    local atlas = Kind()
    if atlas then
        icon:SetAtlas(atlas)
        icon:SetSize(side * ROOT2 * 0.5, side * ROOT2 * 0.5)
    else
        icon:SetTexture(MAP_ICON)
        icon:SetSize(side, side)
        icon:SetRotation(TURN)
    end
end

---------------------------------------------------------------------------
-- Shown: what the game's own frames say, as they come
---------------------------------------------------------------------------
local goal, holdUntil = 0, 0
local wasZone, wasSub = false, false

local function Native(frame)
    return frame and frame:IsVisible() and true or false
end

local function Read(zoneUp, subUp)
    local zone = zoneUp and Words(ZoneTextString and ZoneTextString:GetText())
    local subzone = subUp and Words(SubZoneTextString and SubZoneTextString:GetText())
    local big = zone or subzone
    if not big then return end
    local small = zone and subzone ~= zone and subzone or (not zone and Words(GetZoneText())) or nil
    if small == big then small = nil end
    name:SetText(big)
    sub:SetText(small or "")
    local words, r, g, b
    for _, s in ipairs({ zoneUp and PVPInfoTextString, subUp and PVPArenaTextString }) do
        local w = s and Words(s:GetText())
        if w then
            words = w
            r, g, b = s:GetTextColor()
            break
        end
    end
    pvp:SetText(words or "")
    if words and r then pvp:SetTextColor(r, g, b) end
    SetKind()
    goal, holdUntil = 1, GetTime() + HOLD + SWAP
    banner:Show()
end

local Ease, Pop = HS.Ease, HS.Pop

local function On()
    return IF.db and IN.Settings().zoneBanner and true or false
end

local broken

local function Step(elapsed)
    local on = On()
    local zoneUp, subUp = Native(ZoneTextFrame), Native(SubZoneTextFrame)
    if on then
        IF.Focus.Fade(ZoneTextFrame, true)
        IF.Focus.Fade(SubZoneTextFrame, true)
        if (zoneUp and not wasZone) or (subUp and not wasSub) then Read(zoneUp, subUp) end
    end
    wasZone, wasSub = zoneUp, subUp
    if goal == 1 and GetTime() > holdUntil then goal = 0 end
    if not on then goal = 0 end
    -- (in the header's place as long as it has it, HeaderSlot.lua)
    local p = HS.Presence("zone")
    if p <= 0 then
        banner:Hide()
        return
    end
    banner:Show()
    local come = Ease(p, 0, 0.7)
    local scale = math.max(0.01, come < 1 and Pop(come) or 1)
    tile:SetScale(scale)
    tile:SetAlpha(come)
    local textIn = Ease(p, 0.3, 1)
    name:ClearAllPoints()
    name:SetPoint("TOP", banner, "CENTER", 0, -HS.NAME_GAP - SLIDE * (1 - textIn))
    for _, s in ipairs({ name, sub, pvp }) do s:SetAlpha(textIn) end
end

-- (one error said once, then no more: an error each frame floods the
-- game's error handler, whose popup taints the pad's focus; the game's
-- own zone names back)
local events = CreateFrame("Frame")
events:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then
        broken, goal = true, 0
        banner:Hide()
        IF.Focus.Fade(ZoneTextFrame, false)
        IF.Focus.Fade(SubZoneTextFrame, false)
        IF.Print("Immersion: the zone names stopped after an error: " .. tostring(err))
    end
end)

-- (the header's place, first of all while it's held: not in a fight with
-- a target, the fight's)
HS.Add("zone", 3, {
    wants = function()
        return goal == 1 and not broken and On() and not (IF.InCombat() and UnitExists("target"))
    end,
    rule = function() return true end,
})
-- (the header stopped: the game's own zone names back)
function HS.OnBroken()
    IF.Focus.Fade(ZoneTextFrame, false)
    IF.Focus.Fade(SubZoneTextFrame, false)
end

-- Ours in place of the game's
function ZB.On()
    return not broken and On()
end

function ZB.Apply()
    if not On() then
        IF.Focus.Fade(ZoneTextFrame, false)
        IF.Focus.Fade(SubZoneTextFrame, false)
    end
end

-- /if zonetest: the banner as entering the zone you're in shows it
function ZB.Test()
    local zone = Words(GetZoneText())
    local subzone = Words(GetSubZoneText())
    if not zone then return end
    name:SetText(zone)
    sub:SetText(subzone ~= zone and subzone or "")
    local pvpType, _, faction = GetZonePVPInfo()
    pvp:SetText("")
    SetKind()
    goal, holdUntil = 1, GetTime() + HOLD + SWAP
    IF.Print(("Zone banner: %s (%s), %s"):format(zone, tostring(pvpType), tostring(faction)))
end

IF.OnLogin(ZB.Apply)
