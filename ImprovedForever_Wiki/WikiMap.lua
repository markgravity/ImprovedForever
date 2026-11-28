-- The Wiki on a map: a creature, a node, a chest, a place (Cross on a zone,
-- Square on an entry) shows its zone's map in a window of ours, its areas drawn
-- (a soft blue fill: its spawns, near ones together), the game's own waypoint set
-- at the nearest spawn (the arrow in the world). The book it's shown from (the
-- Wiki's, the Journal's) steps aside while the map is up and comes back, on the
-- same page, once it's closed.
-- The game's own WorldMapFrame is never opened or touched: OpenWorldMap() from
-- addon code taints the gamepad UI (SetPreferredGamepadInteractTarget forbidden
-- when a window closes, #29). The zone's art is drawn from C_Map as the Journal does.
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
-- The window: the zone's art (its base tiles, the areas explored), the areas over it
---------------------------------------------------------------------------
local ART_W = 760
local win, art, areas, pin, catcher, escape
local tiles, explored, boxTex = {}, {}, {}
local away                     -- the book stepped aside for the map

local function Pool(list, i)
    local t = list[i]
    if not t then
        t = art:CreateTexture(nil, list == tiles and "BACKGROUND" or "BORDER")
        list[i] = t
    end
    return t
end

local function FileSize(pixels)
    local size = 16
    while size < pixels do size = size * 2 end
    return size
end

-- One file over x..x+w, y..y+h of the layer's pixels (fw by fh of them in the file)
local function Piece(list, n, file, x, y, w, h, fw, fh, scale)
    local t = Pool(list, n)
    t:SetTexture(file)
    t:SetTexCoord(0, w / fw, 0, h / fh)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", art, "TOPLEFT", x * scale, -y * scale)
    t:SetSize(w * scale, h * scale)
    t:Show()
end

local function AddArea(n, AW, AH, x, y, files, TW, TH, scale)
    local wide, tall = math.ceil(AW / TW), math.ceil(AH / TH)
    for j = 1, tall do
        local h = j < tall and TH or AH - (tall - 1) * TH
        local fh = j < tall and TH or FileSize(h)
        for k = 1, wide do
            local file = files[(j - 1) * wide + k]
            if file then
                local w = k < wide and TW or AW - (wide - 1) * TW
                n = n + 1
                Piece(explored, n, file, x + (k - 1) * TW, y + (j - 1) * TH, w, h, k < wide and TW or FileSize(w), fh, scale)
            end
        end
    end
    return n
end

-- The map's art in the art frame, -> false: the client has none for it
local function DrawArt(map)
    if not (C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return false end
    local layers = C_Map.GetMapArtLayers(map)
    local layer = layers and layers[1]
    local files = C_Map.GetMapArtLayerTextures(map, 1)
    if not (layer and layer.layerWidth and layer.layerWidth > 0 and files and #files > 0) then return false end
    local scale = ART_W / layer.layerWidth
    art:SetSize(ART_W, layer.layerHeight * scale)
    local TW, TH = layer.tileWidth, layer.tileHeight
    local cols, rows = math.ceil(layer.layerWidth / TW), math.ceil(layer.layerHeight / TH)
    local n = 0
    for row = 1, rows do
        for col = 1, cols do
            local file = files[(row - 1) * cols + col]
            if file then
                n = n + 1
                Piece(tiles, n, file, (col - 1) * TW, (row - 1) * TH, TW, TH, TW, TH, scale)
            end
        end
    end
    for i = n + 1, #tiles do tiles[i]:Hide() end
    local e = 0
    local Explored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    for _, area in ipairs(Explored and Explored(map) or {}) do
        local f, AW, AH = area.fileDataIDs, area.textureWidth, area.textureHeight
        if f and not area.isShownByMouseOver and AW and AW > 0 and AH and AH > 0 then
            e = AddArea(e, AW, AH, area.offsetX, area.offsetY, f, TW, TH, scale)
        end
    end
    for i = e + 1, #explored do explored[i]:Hide() end
    return true
end

local function Build()
    if win then return end
    local K, UI = IF.ConfigKit, IF.UI
    win = UI.Window("ImprovedForeverWikiMap", ART_W + 24, 560, true)
    art = CreateFrame("Frame", nil, win)
    art:SetPoint("TOP", 0, -34)
    areas = CreateFrame("Frame", nil, art)
    areas:SetAllPoints(art)
    areas:SetFrameLevel(art:GetFrameLevel() + 3)
    pin = areas:CreateTexture(nil, "OVERLAY")
    pin:SetSize(22, 22)
    if not pcall(pin.SetAtlas, pin, "Waypoint-MapPin-Untracked") then pin:SetColorTexture(1, 0.82, 0, 1) end
    pin:Hide()
    local function Close() win:Hide() end
    win.onClose = Close
    IF.Focus.Dock(win)
    -- (the pad: B closes; the catcher is off until it is wanted)
    catcher = CreateFrame("Frame", nil, win)
    catcher:SetAllPoints(win)
    if catcher.EnableGamePadButton then
        catcher:SetScript("OnGamePadButtonDown", function(_, button)
            if button == "PAD2" or button == "PADBACK" then Close() end
        end)
        catcher:EnableGamePadButton(false)
    end
    -- (Esc: an override binding while shown, to a button of ours; never UISpecialFrames)
    escape = CreateFrame("Button", "ImprovedForeverWikiMapEscape")
    escape:RegisterForClicks("AnyUp")
    escape:SetScript("OnClick", Close)
    win:SetScript("OnShow", function()
        if IF.InCombat() then return win:Hide() end
        if catcher.EnableGamePadButton then catcher:EnableGamePadButton(true) end
        ClearOverrideBindings(win)
        SetOverrideBindingClick(win, true, "ESCAPE", escape:GetName())
        IF.Focus.Glow(win, true)
        IF.Focus.DimNative(win, true)
    end)
    win:SetScript("OnHide", function()
        if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(false) end
        if not IF.InCombat() then ClearOverrideBindings(win) end
        IF.Focus.Glow(win, false)
        IF.Focus.DimNative(win, false)
        local book = away
        away = nil
        if book then book:Resume() end
    end)
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:SetScript("OnEvent", function() if win:IsShown() then win:Hide() end end)
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
    Build()
    if not DrawArt(map) then
        IF.Print((line.plain or "it") .. ": the game has no map art for this zone")
        return false
    end
    local boxes = Clusters(points)
    local w, h = art:GetSize()
    for i, box in ipairs(boxes) do
        local t = boxTex[i]
        if not t then
            t = areas:CreateTexture(nil, "ARTWORK")
            t:SetTexture(AREA)
            t:SetVertexColor(AREA_COLOR[1], AREA_COLOR[2], AREA_COLOR[3], AREA_COLOR[4])
            boxTex[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", art, "TOPLEFT", box[1] * w, -box[2] * h)
        t:SetSize(box[3] * w, box[4] * h)
        t:Show()
    end
    for i = #boxes + 1, #boxTex do boxTex[i]:Hide() end
    local spot = line.spot
    if spot then
        pin:ClearAllPoints()
        pin:SetPoint("BOTTOM", art, "TOPLEFT", spot.x / 100 * w, -spot.y / 100 * h)
        pin:Show()
    else
        pin:Hide()
    end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    win:SetTitle(info and info.name or "Map")
    win:SetHeight(h + 46)
    LB.Waypoint(line)
    if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
    away = book or LB.book
    if away then away:Suspend() end
    win:Show()
    return true
end
