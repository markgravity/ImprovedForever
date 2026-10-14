-- The Wiki on the world map: a creature, a node, a chest, a place
-- (Cross on a zone, Square on an entry) opens the game's map and quest panel
-- at its zone, its areas drawn as the quest areas are (a soft blue fill, a
-- lit rim: its spawns, near ones together), the game's own waypoint at the
-- nearest spawn (its pin, the arrow in the world). The book it's shown from
-- (the Wiki's, the Journal's) steps aside while the map is up and comes
-- back, on the same page, once it's closed.
-- The areas are drawn on the map's canvas by a data provider of ours (no pin
-- templates or the map's own pin pools: HereBeDragons' way).
local IF = ImprovedForever

local LB = IF.Wiki

local AREA = "Interface\\AddOns\\ImprovedForever\\textures\\ic_area"
local AREA_COLOR = { 0.35, 0.6, 1, 0.85 }
local NEAR = 7          -- spawns this close (map percent) are one area
local PAD = 3.5         -- an area reaches this far past its spawns (map percent)
local MIN_SIZE = 6      -- the smallest area (map percent)

---------------------------------------------------------------------------
-- The areas: spawns gathered into clusters, each its box (0-1 map
-- coordinates: centre x, y, width, height)
---------------------------------------------------------------------------
local function Clusters(points)
    local groups, of = {}, {}
    for i, p in ipairs(points) do
        local g = { p }
        groups[#groups + 1] = g
        of[i] = g
    end
    -- (single linkage: two near spawns' groups made one)
    for i = 1, #points do
        for j = i + 1, #points do
            local a, b = points[i], points[j]
            if of[i] ~= of[j] and math.abs(a[1] - b[1]) <= NEAR and math.abs(a[2] - b[2]) <= NEAR then
                local keep, gone = of[i], of[j]
                for _, p in ipairs(gone) do keep[#keep + 1] = p end
                for k = 1, #points do
                    if of[k] == gone then of[k] = keep end
                end
                wipe(gone)
            end
        end
    end
    local boxes = {}
    for _, g in ipairs(groups) do
        if #g > 0 then
            local x1, y1, x2, y2 = 100, 100, 0, 0
            for _, p in ipairs(g) do
                x1, y1 = math.min(x1, p[1]), math.min(y1, p[2])
                x2, y2 = math.max(x2, p[1]), math.max(y2, p[2])
            end
            local w = math.max(MIN_SIZE, x2 - x1 + 2 * PAD)
            local h = math.max(MIN_SIZE, y2 - y1 + 2 * PAD)
            boxes[#boxes + 1] = { (x1 + x2) / 200, (y1 + y2) / 200, w / 100, h / 100 }
        end
    end
    return boxes
end

---------------------------------------------------------------------------
-- Drawing them on the map's canvas, while it shows their zone
---------------------------------------------------------------------------
local shown                    -- { map = uiMapID, boxes } (what to draw)
local holder, textures         -- (made the first time the map is opened)
local provider

local function Draw()
    if not holder then return end
    for _, t in ipairs(textures) do t:Hide() end
    local map = WorldMapFrame
    if not (shown and map and map:GetMapID() == shown.map) then return end
    local canvas = map:GetCanvas()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    for i, box in ipairs(shown.boxes) do
        local t = textures[i]
        if not t then
            t = holder:CreateTexture(nil, "ARTWORK")
            t:SetTexture(AREA)
            t:SetVertexColor(AREA_COLOR[1], AREA_COLOR[2], AREA_COLOR[3], AREA_COLOR[4])
            textures[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", canvas, "TOPLEFT", box[1] * w, -box[2] * h)
        t:SetSize(box[3] * w, box[4] * h)
        t:Show()
    end
end

local function Hook()
    if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider) then return provider ~= nil end
    local canvas = WorldMapFrame:GetCanvas()
    holder = CreateFrame("Frame", nil, canvas)
    holder:SetAllPoints(canvas)
    -- (under the map's pins: its quests, the waypoint)
    holder:SetFrameLevel(canvas:GetFrameLevel() + 1)
    textures = {}
    provider = CreateFromMixins and MapCanvasDataProviderMixin and CreateFromMixins(MapCanvasDataProviderMixin) or {}
    provider.RefreshAllData = function() Draw() end
    provider.RemoveAllData = function()
        for _, t in ipairs(textures) do t:Hide() end
    end
    provider.OnMapChanged = function() Draw() end
    provider.OnCanvasSizeChanged = function() Draw() end
    WorldMapFrame:AddDataProvider(provider)
    return true
end

-- The map closed: the areas gone, the book back
local hooked = false
local away                     -- the book stepped aside for the map
local function WatchMap()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnHide", function()
        shown = nil
        Draw()
        local book = away
        away = nil
        if book then book:Resume() end
    end)
end

---------------------------------------------------------------------------
-- Showing a line on the map: its zone, its areas, the waypoint
---------------------------------------------------------------------------
local function Zone(line)
    local spot = line.spot
    local area = spot and spot.area or line.zone
    local points = {}
    for _, p in ipairs(line.spawns and line.spawns[area] or {}) do
        if p[1] and p[1] >= 0 then points[#points + 1] = p end
    end
    if #points == 0 and spot then points[1] = { spot.x, spot.y } end
    return area, points
end

-- book: the one it's shown from (nil: the Wiki's). -> true: shown (false:
-- nowhere to show it: an instance, a zone the map doesn't have)
function LB.ShowOnMap(line, book)
    if IF.InCombat() or not line then return false end
    local area, points = Zone(line)
    local map = LB.UiMap(area)
    if not map or #points == 0 then
        IF.Print((line.plain or "it") .. ": nowhere on the map (inside an instance?)")
        return false
    end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    if not (OpenWorldMap and Hook()) then return false end
    WatchMap()
    shown = { map = map, boxes = Clusters(points) }
    LB.Waypoint(line)
    if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
    away = book or LB.book
    away:Suspend()
    OpenWorldMap(map)
    Draw()
    return true
end

local load = CreateFrame("Frame")
load:RegisterEvent("ADDON_LOADED")
load:RegisterEvent("PLAYER_LOGIN")
load:SetScript("OnEvent", function()
    WatchMap()
    if hooked then load:UnregisterAllEvents() end
end)
