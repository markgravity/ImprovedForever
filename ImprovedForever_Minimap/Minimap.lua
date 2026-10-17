-- The minimap's dots, named (NodeScan.lua reads them):
--   labels: each dot of the kinds chosen (herbs, ore, quests, NPCs, party
--     members) gets its name beside it; herbs and ore coloured by the skill
--     they give (as the game colours recipes). Shown and hidden by a hotkey
--     (recorded in the Minimap tab, one button or one held + one pressed),
--     a touchpad corner / button override action, or the key binding;
--   alerts: the minimap read every few seconds, and a herb or ore worth
--     having that appears pulses the controller, plays a sound and says
--     what and where.
-- Set in the Minimap tab (MinimapEditor.lua); IF.db.minimap (the Gather
-- module's IF.db.gather before, moved over by the core).
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local N = IF.NodeScan

local MM = {}
IF.Minimap = MM

local DEFAULTS = {
    labels = false,      -- the labels on the minimap shown
    colors = true,       -- herbs and ore coloured by the skill they give
    need = true,         -- a red one's label says the skill it needs: "Bruiseweed (100)"
    -- the dots labelled, by type (NodeScan.lua's N.TYPES)
    herb = true, ore = true, objective = true, quest = true, npc = false, party = false,
    alert = false,
    alertFor = "skill",  -- skill (gives skill), gather (can gather), any (any herb / ore), all (any dot)
    alertWith = "both",  -- both, vibe, sound, show (the message only)
    interval = 3,        -- seconds between alert scans
}

function MM.Settings()
    IF.db.minimapLog = nil   -- (a probe's, since removed)
    IF.db.minimap = IF.db.minimap or {}
    local s = IF.db.minimap
    -- (quests were one type before objectives were their own)
    if s.objective == nil and s.quest ~= nil then s.objective = s.quest end
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

-- A colour the game gave a name itself that says something: not plain
-- white, nor the tooltips' usual gold
local function Telling(c)
    if not c then return false end
    if c[1] > 0.95 and c[2] > 0.95 and c[3] > 0.95 then return false end
    if c[1] > 0.95 and math.abs(c[2] - 0.82) < 0.04 and c[3] < 0.06 then return false end
    return true
end

-- A node's skill colour (a name for alerts): the game's own when it gives
-- one, else worked out from the skill; nil when it isn't a herb or ore, its
-- profession isn't learnt, or colours are off
function MM.SkillColor(node)
    if not MM.Settings().colors then return nil end
    if type(node) == "table" then
        if N.Kind(node.name) and Telling(node.gameColor) then return node.gameColor end
        node = node.name
    end
    local state = N.State(node)
    return state and N.COLORS[state]
end

-- The colours of the dots that aren't herbs or ore: a quest's the game's
-- quest yellow, a party member's their class's (else the party's blue), an
-- NPC's the game's own when it gives one that says something
local QUEST_COLOR = { 1, 0.82, 0 }
local PARTY_COLOR = { 0.67, 0.67, 1 }

function MM.LabelColor(node)
    local t = node.type or N.Type(node.name)
    if t == "herb" or t == "ore" then return MM.SkillColor(node) or KC.white end
    if t == "quest" or t == "objective" then return QUEST_COLOR end
    if t == "party" then
        local unit = N.GroupUnit(node.name)
        local class = unit and select(2, UnitClass(unit))
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
        return c and { c.r, c.g, c.b } or PARTY_COLOR
    end
    return Telling(node.gameColor) and node.gameColor or KC.white
end

---------------------------------------------------------------------------
-- A label's pieces: { atlas or icon (an item's, round), text, color }. A
-- quest's: each objective's count beside what it is: the creature to slay
-- (its portrait), the item (its icon); else the game's own soft-target
-- icon of its kind; an NPC with a quest for you its name. A quest's mark with no
-- objectives (handed in there) none: the minimap shows its "?" itself
---------------------------------------------------------------------------
local OBJECTIVE_ATLAS = {
    monster = "Crosshair_Attack_48", item = "Crosshair_pickup_48",
    object = "Crosshair_interact_48", event = "Crosshair_Quest_48",
}
local COUNT_COLOR, DONE_COLOR = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }

-- Words alone, for matching an objective the minimap gives to the log's
-- ("5/10 Young Night Web Spider slain", "Young Night Web Spider slain: 5/10")
local function Plain(s)
    return (s:lower():gsub("%d+%s*/%s*%d+", ""):gsub("[%p%s]+", " ")):match("^%s*(.-)%s*$")
end

-- An objective's type in the log ("monster", "item", "object", "event"...)
local function ObjectiveType(questID, subject)
    local log = C_QuestLog
    if questID and log and log.GetQuestObjectives then
        local want = Plain(subject)
        for _, o in ipairs(log.GetQuestObjectives(questID) or {}) do
            if type(o.text) == "string" and Plain(o.text) == want then return o.type end
        end
    end
    if subject:find(" slain$") then return "monster" end
end

-- An item objective's own icon: the item by its name (known once seen or
-- in the bags), else among the quest's items (the core's game data; one
-- not cached yet is asked for, known by a later scan)
local itemIcons = {}
local function ItemIcon(questID, subject)
    if itemIcons[subject] then return itemIcons[subject] end
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    local icon = select(10, info(subject))
    if not icon then
        local items = questID and IF.GameData and IF.GameData.QuestItems and IF.GameData.QuestItems(questID)
        local byID = C_Item and C_Item.GetItemIconByID or GetItemIcon
        for _, id in ipairs(items or {}) do
            if info(id) == subject then icon = byID(id) end
        end
    end
    itemIcons[subject] = icon
    return icon
end

local function ObjectiveParts(node)
    local title, objectives = N.QuestBlock(node.name)
    if not title then
        -- (a creature or object a quest needs: its name)
        if not node.name:find("%d+%s*/%s*%d+") then return { { text = node.name, color = node.color } } end
        title, objectives = "", { { subject = node.name, text = node.name } }
        objectives[1].have, objectives[1].need = node.name:match("(%d+)%s*/%s*(%d+)")
    end
    local questID = N.QuestID(title)
    local parts = {}
    for _, o in ipairs(objectives) do
        local kind = ObjectiveType(questID, o.subject)
        -- (what it is: the creature's portrait, the item's icon; the
        -- generic icon of its kind only when neither is known)
        local GD = IF.GameData
        local npc = (kind == "monster" or not kind) and GD and GD.NpcByName
            and GD.NpcByName((o.subject:gsub("%s+slain$", "")))
        local icon = not npc and (kind == "item" or not kind) and ItemIcon(questID, o.subject) or nil
        if not kind then kind = (npc and "monster") or (icon and "item") or nil end
        local part = { npc = npc, icon = icon, atlas = OBJECTIVE_ATLAS[kind] or OBJECTIVE_ATLAS.event }
        if o.have and o.need then
            part.text = o.have .. "/" .. o.need
            -- (one done, greyed)
            part.color = tonumber(o.have) >= tonumber(o.need) and DONE_COLOR or COUNT_COLOR
        end
        parts[#parts + 1] = part
    end
    return parts
end

-- A quest's label, beside its NPC or its mark: the quest's title (the one
-- handed in there, else the one to take; "+2": as many more)
local function QuestTitle(id)
    local log = C_QuestLog
    return log and log.GetTitleForQuestID and log.GetTitleForQuestID(id)
        or (IF.GameData and IF.GameData.QuestName(id))
end

local function QuestParts(node)
    if N.IsQuestTitle(node.name) then return { { text = node.name, color = node.color } } end
    local _, ids = IF.GameData.QuestNpc(node.name)
    local title = ids and QuestTitle(ids[1])
    if not title then return { { text = node.name, color = node.color } } end
    return { { text = title .. (#ids > 1 and ("  +" .. (#ids - 1)) or ""), color = node.color } }
end

-- A label's pieces: an objective's or a quest's, else its words in its colour
function MM.LabelParts(node)
    local t = node.type or N.Type(node.name)
    if t == "objective" then return ObjectiveParts(node) end
    if t == "quest" then return QuestParts(node) end
    return { { text = MM.LabelText(node), color = node.color } }
end

-- A label's words: "Silverleaf x2", "Bruiseweed (100)" for one beyond the
-- player's skill
function MM.LabelText(node)
    local text = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    if MM.Settings().need and N.State(node.name) == "red" then
        text = text .. " (" .. select(2, N.Kind(node.name)) .. ")"
    end
    return text
end

-- The player's place in the world, as yards east and north, or nil
local PlayerPos = N.Position

local function Vibrate()
    if IF.Vibe and IF.Vibe.Settings().enabled then IF.Vibe.Play("pulse") end
end

---------------------------------------------------------------------------
-- The labels: on the minimap, over its dots
---------------------------------------------------------------------------
local SCAN = 0.5     -- seconds between scans while shown (0.25 where the player's place is unknown)
local DOT = 11       -- the game's dot: a label sits just beside it

local overlay = K.NewFrame("Frame", "ImprovedForeverMinimapLabels")
overlay:SetParent(Minimap)
overlay:SetAllPoints(Minimap)
overlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)
overlay:Hide()

-- A label drawn as the minimap's own header (its zone name's bar: the
-- game's nine-slice, "ui-hud-minimap-button"), its icons the size of the
-- header's tracking button's, its words the game's small font
local BAR_H = 16     -- the header's height
local ICON_SIZE = 13
local PAD, SPACE = 5, 5   -- inside the bar's ends; between pieces

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function Chip(parent)
    local c = K.NewFrame("Frame", nil, parent)
    c:SetHeight(BAR_H)
    local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName
        and pcall(NineSliceUtil.ApplyLayoutByName, c, "UniqueCornersLayout", "ui-hud-minimap-button")
    if not ok then
        -- (no nine-slice: a dark bar)
        local bg = c:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.6)
    end
    c.icons, c.texts = {}, {}
    return c
end

-- An item's icon round, as the minimap's buttons
local function Round(c, tex)
    local mask = c:CreateMaskTexture()
    mask:SetAllPoints(tex)
    if HasAtlas("CircleMask") then
        mask:SetAtlas("CircleMask")
    else
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    tex.mask = mask
end

-- The chip's pieces laid out left to right, its width to fit them
local function Layout(c, parts)
    local x = PAD
    for i, part in ipairs(parts) do
        local tex = c.icons[i]
        if part.atlas or part.icon or part.npc then
            if not tex then
                tex = c:CreateTexture(nil, "ARTWORK")
                tex:SetSize(ICON_SIZE, ICON_SIZE)
                Round(c, tex)
                c.icons[i] = tex
            end
            -- A creature's portrait, else an item's icon (both round), else
            -- the generic atlas
            tex:SetTexCoord(0, 1, 0, 1)
            local round = part.npc ~= nil and IF.Book and IF.Book.Portrait(part.npc, tex) or false
            if not round and part.icon then
                tex:SetTexture(part.icon)
                tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                round = true
            elseif not round then
                tex:SetAtlas(part.atlas)
            end
            if round ~= tex.round then
                if round then tex:AddMaskTexture(tex.mask) else tex:RemoveMaskTexture(tex.mask) end
                tex.round = round
            end
            tex:ClearAllPoints()
            tex:SetPoint("LEFT", c, "LEFT", x - 2, 0)
            tex:Show()
            x = x - 2 + ICON_SIZE + (part.text and 2 or 0)
        elseif tex then
            tex:Hide()
        end
        local fs = c.texts[i]
        if part.text then
            if not fs then
                fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                c.texts[i] = fs
            end
            local color = part.color or KC.white
            fs:SetText(part.text)
            fs:SetTextColor(color[1], color[2], color[3])
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", c, "LEFT", x, 0)
            fs:Show()
            x = x + fs:GetStringWidth()
        elseif fs then
            fs:Hide()
        end
        x = x + SPACE
    end
    for i = #parts + 1, #c.icons do c.icons[i]:Hide() end
    for i = #parts + 1, #c.texts do c.texts[i]:Hide() end
    c:SetWidth(x - SPACE + PAD)
end

-- What a label shows, as one string: laid out again only when it changes
local function Signature(parts)
    local out = {}
    for _, part in ipairs(parts) do
        local c = part.color or KC.white
        out[#out + 1] = string.format("%s|%s|%s|%s|%.2f%.2f%.2f", tostring(part.npc), tostring(part.atlas), tostring(part.icon),
            tostring(part.text), c[1], c[2], c[3])
    end
    return table.concat(out, ";")
end

local pins = {}
local function Pin(i)
    local p = pins[i]
    if p then return p end
    -- (an empty frame the size of the game's dot, over it)
    p = K.NewFrame("Frame", nil, overlay)
    p:SetSize(DOT, DOT)
    p.label = Chip(p)
    pins[i] = p
    return p
end

local nodes, scanEast, scanNorth = {}, nil, nil

-- Does a type of dot get a label
function MM.Labelled(t)
    return MM.Settings()[t] and true or false
end

-- Are only herbs and ore labelled (a scan of them alone does)
local function GatherOnly()
    for _, t in ipairs(N.TYPES) do
        if t ~= "herb" and t ~= "ore" and MM.Labelled(t) then return false end
    end
    return true
end

-- Each dot followed from scan to scan, in the world: a scan reads a dot off
-- points a step apart round the player, so its middle wobbles by up to
-- half a step as the player walks. Its places so far are averaged (the
-- last MEAN), and the side its label took kept with it.
local MEAN = 8
local tracks = {}    -- { key, e, n (yards in the world), k (places averaged), side }

-- (a quest's counts left out: one that goes up is the same area)
local function TrackKey(name)
    return (name:gsub("%d+%s*/%s*%d+", "#"))
end

local function Follow(node, found, reach, fresh)
    if not found.east then return end
    local key = TrackKey(node.name)
    local e, n = found.east + node.east, found.north + node.north
    local best, bestD
    for _, t in ipairs(tracks) do
        if not t.taken and t.key == key then
            local d = (t.e - e) ^ 2 + (t.n - n) ^ 2
            if d <= reach * reach and (not bestD or d < bestD) then best, bestD = t, d end
        end
    end
    local t = best or { key = key, e = e, n = n, k = 0 }
    t.taken = true
    t.k = math.min(t.k + 1, MEAN)
    t.e, t.n = t.e + (e - t.e) / t.k, t.n + (n - t.n) / t.k
    node.east, node.north = t.e - found.east, t.n - found.north
    node.track = t
    fresh[#fresh + 1] = t
end

-- A quest's area, kept in the world. A scan reads only the part in view,
-- so its middle moves as the player walks; instead every point read goes
-- into a grid of CELL-yard cells in the world, kept from scan to scan, and
-- the label sits on the cell nearest the middle of all of them: it stays
-- put, moving only as more of the area comes into view. (Place moves it to
-- the area's nearest cell in view when that one isn't.)
local CELL = 4
local AREA_KEEP = 120  -- seconds an area not read again is kept
local MAX_CELLS = 4000
local areas = {}       -- { key, cells = { [id] = { east, north } }, sumE, sumN, count, e, n, seen, side }

local function CellID(e, n)
    return math.floor(e / CELL) * 1000000 + math.floor(n / CELL)
end

-- (a cell or one next to it known: the scan's points are a step apart,
-- shifted with the player, so a known area's land beside its cells)
local function Near(cells, e, n)
    local ce, cn = math.floor(e / CELL), math.floor(n / CELL)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if cells[(ce + dx) * 1000000 + cn + dy] then return true end
        end
    end
    return false
end

-- The label's cell: the one nearest the middle of all, kept until that
-- middle has moved STICK yards from it (more of the area seen as the
-- player walks moves it a little every scan: a label hopping cell to
-- cell). Place glides it to a new one.
local STICK = 10

local function Anchor(a)
    local me, mn = a.sumE / a.count, a.sumN / a.count
    if a.e and a.cells[CellID(a.e, a.n)] and (a.e - me) ^ 2 + (a.n - mn) ^ 2 <= STICK * STICK then return end
    local bestD
    for _, c in pairs(a.cells) do
        local d = (c[1] - me) ^ 2 + (c[2] - mn) ^ 2
        if not bestD or d < bestD then bestD, a.e, a.n = d, c[1], c[2] end
    end
end

local function AddCell(a, id, e, n)
    if a.cells[id] or a.count >= MAX_CELLS then return false end
    local ce, cn = (math.floor(e / CELL) + 0.5) * CELL, (math.floor(n / CELL) + 0.5) * CELL
    a.cells[id] = { ce, cn }
    a.sumE, a.sumN, a.count = a.sumE + ce, a.sumN + cn, a.count + 1
    return true
end

-- The area a scan's group of points is part of (areas of its name it
-- touches made one: a scan can read one area as two groups), grown by them
local function FollowArea(node, found)
    local key = TrackKey(node.name)
    local points = {}
    for _, p in ipairs(node.points) do
        local e, n = found.east + p[1], found.north + p[2]
        points[#points + 1] = { CellID(e, n), e, n }
    end
    local touched = {}
    for _, a in ipairs(areas) do
        if a.key == key then
            for _, p in ipairs(points) do
                if Near(a.cells, p[2], p[3]) then
                    touched[#touched + 1] = a
                    break
                end
            end
        end
    end
    table.sort(touched, function(x, y) return x.count > y.count end)
    local a = touched[1]
    if not a then
        a = { key = key, cells = {}, sumE = 0, sumN = 0, count = 0 }
        areas[#areas + 1] = a
    end
    -- (the others it touches folded into it)
    for i = 2, #touched do
        local other = touched[i]
        for id, c in pairs(other.cells) do AddCell(a, id, c[1], c[2]) end
        other.merged = a
    end
    a.seen = GetTime()
    for _, p in ipairs(points) do AddCell(a, p[1], p[2], p[3]) end
    Anchor(a)
    node.east, node.north = a.e - found.east, a.n - found.north
    node.track = a
    return a
end

-- The dots of a scan of the types labelled, each with its type and colour,
-- and where the player stood when it began
local function Rescan(found)
    nodes = {}
    -- (a dot read again lands within two steps of where it was)
    local radius = Minimap:GetWidth() / 2
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or radius
    local reach = N.step * 2 * view / radius
    local fresh, labelled, titles = {}, {}, {}
    for _, node in ipairs(found) do
        node.type = N.Type(node.name)
        if MM.Labelled(node.type) then
            node.color = MM.LabelColor(node)
            node.parts = MM.LabelParts(node)
            node.sig = Signature(node.parts)
            if #node.parts > 0 then
                -- (one label an area, however many groups it was read as)
                local area = node.area and node.points and found.east and FollowArea(node, found)
                if not area then Follow(node, found, reach, fresh) end
                -- (a quest's title once: its NPC and its mark both name it)
                local title = node.type == "quest" and node.sig
                if not (area and labelled[area]) and not (title and titles[title]) then nodes[#nodes + 1] = node end
                if title then titles[title] = true end
                if area then labelled[area] = true end
            end
        end
    end
    for _, t in ipairs(fresh) do t.taken = nil end
    tracks = fresh
    -- (an area folded into another later in the scan: its label the other's)
    local seen, kept = {}, {}
    for _, node in ipairs(nodes) do
        local t = node.track
        while t and t.merged do t = t.merged end
        node.track = t or node.track
        if not (node.area and t and seen[t]) then kept[#kept + 1] = node end
        if node.area and t then seen[t] = true end
    end
    nodes = kept
    kept = {}
    for _, a in ipairs(areas) do
        if not a.merged and GetTime() - a.seen < AREA_KEEP then kept[#kept + 1] = a end
    end
    areas = kept
    scanEast, scanNorth = found.east, found.north
end

-- Where a label can go round its dot (x, y its centre): right, left,
-- above, below, or on it (an area's: no dot under it); the rectangle it
-- would take
local GAP = 2
local SIDES = { "right", "left", "above", "below" }
local AREA_SIDES = { "center", "above", "below", "right", "left" }
-- (rows a label may move up or down from its side when that's taken)
local ROWS = { 0, 1, -1, 2, -2, 3, -3 }
local function LabelRect(side, x, y, w, h)
    local half = DOT / 2
    if side == "center" then return x - w / 2, y - h / 2, w, h end
    if side == "right" then return x + half + GAP, y - h / 2, w, h end
    if side == "left" then return x - half - GAP - w, y - h / 2, w, h end
    if side == "above" then return x - w / 2, y + half, w, h end
    return x - w / 2, y - half - h, w, h
end

local function Overlap(ax, ay, aw, ah, bx, by, bw, bh)
    local w = math.min(ax + aw, bx + bw) - math.max(ax, bx)
    local h = math.min(ay + ah, by + bh) - math.max(ay, by)
    return (w > 0 and h > 0) and w * h or 0
end

-- How far a rectangle's farthest corner reaches past a circle round the
-- middle (0: inside it)
local function Outside(lx, ly, w, h, r)
    local fx = math.max(math.abs(lx), math.abs(lx + w))
    local fy = math.max(math.abs(ly), math.abs(ly + h))
    return math.max(0, math.sqrt(fx * fx + fy * fy) - r)
end

-- A rectangle moved towards the middle until it's inside the circle; nil
-- when it can't be (wider than the circle there)
local function Fit(lx, ly, w, h, r)
    for _ = 1, 10 do
        local out = Outside(lx, ly, w, h, r)
        if out <= 0 then return lx, ly end
        local mx, my = lx + w / 2, ly + h / 2
        local len = math.sqrt(mx * mx + my * my)
        if len < 1 then return nil end
        lx, ly = lx - mx / len * (out + 1), ly - my / len * (out + 1)
    end
    if Outside(lx, ly, w, h, r) <= 0 then return lx, ly end
end

-- Each node where it is now: its place at the scan, less how far the
-- player has walked since, turned with a turning minimap
-- A followed dot's place glides to a new one (an area's label moved on,
-- a dot's average) over a few frames rather than jumping: GLIDE a second
local GLIDE = 8

-- (a place in the world within r of the minimap's middle: the player at
-- e, n, the minimap turned c, s, units a yard)
local function InView(we, wn, e, n, c, s, units, r)
    local ce, cn = we - e, wn - n
    local cx, cy = (ce * c + cn * s) * units, (-ce * s + cn * c) * units
    return cx * cx + cy * cy <= r * r
end

local function Place(_, elapsed)
    local radius = Minimap:GetWidth() / 2
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or radius
    local units = radius / view
    local e, n = PlayerPos()
    local de, dn = 0, 0
    if e and scanEast then de, dn = e - scanEast, n - scanNorth end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local facing = get("rotateMinimap") == "1" and N.Facing() or 0
    local c, s = math.cos(facing), math.sin(facing)
    local edge = radius - 4
    -- Where each dot is, and its label's words and colour
    local shown = {}
    for i, node in ipairs(nodes) do
        local p = Pin(i)
        local east, north = node.east - de, node.north - dn
        local t = node.track
        if t and e and t.e then
            -- Where it is in the world: an area's anchor, else (out of view)
            -- its cell nearest it in view, kept while that stays in view
            local te, tn = t.e, t.n
            local inside = edge - 8
            if t.cells and not InView(te, tn, e, n, c, s, units, inside) then
                local v = t.inView
                if not (v and t.cells[CellID(v[1], v[2])] and InView(v[1], v[2], e, n, c, s, units, inside)) then
                    v = nil
                    local bestD
                    for _, cell in pairs(t.cells) do
                        if InView(cell[1], cell[2], e, n, c, s, units, inside) then
                            local d = (cell[1] - te) ^ 2 + (cell[2] - tn) ^ 2
                            if not bestD or d < bestD then bestD, v = d, cell end
                        end
                    end
                    t.inView = v
                end
                if v then te, tn = v[1], v[2] end
            elseif t.cells then
                t.inView = nil
            end
            local k = math.min(1, (elapsed or 0) * GLIDE)
            t.ge = t.ge and t.ge + (te - t.ge) * k or te
            t.gn = t.gn and t.gn + (tn - t.gn) * k or tn
            east, north = t.ge - e, t.gn - n
        end
        local x, y = (east * c + north * s) * units, (-east * s + north * c) * units
        if x * x + y * y > edge * edge then
            p:Hide()
        else
            p:ClearAllPoints()
            p:SetPoint("CENTER", overlay, "CENTER", x, y)
            if p.sig ~= node.sig then
                Layout(p.label, node.parts)
                p.sig = node.sig
            end
            p.x, p.y, p.area = x, y, node.area
            -- (its side kept with the dot, not the pin: the pins go to the
            -- dots in a scan's order, which changes)
            p.memo = node.track or p
            if not p.area and p.memo.side == "center" then p.memo.side = nil end
            p:Show()
            shown[#shown + 1] = p
        end
    end
    for i = #nodes + 1, #pins do pins[i]:Hide() end
    -- Each label on the first place clear of the dots and the labels placed
    -- already, whatever their types: the place it had (no flicker), then each
    -- side, towards the middle first, then each side moved a row up or down
    -- at a time (an area has no dot of its own; a label stays inside the
    -- minimap). A label that can't be placed clear of the others is hidden.
    local taken = {}
    for _, p in ipairs(shown) do
        if not p.area then taken[#taken + 1] = { p.x - DOT / 2, p.y - DOT / 2, DOT, DOT, p } end
    end
    local inner = radius - 2
    for _, p in ipairs(shown) do
        local w, h = p.label:GetWidth(), p.label:GetHeight()
        local sides = { p.memo.side }
        if not p.area then sides[#sides + 1] = p.x > 0 and "left" or "right" end
        for _, side in ipairs(p.area and AREA_SIDES or SIDES) do sides[#sides + 1] = side end
        local function Try(side, row)
            local lx, ly = LabelRect(side, p.x, p.y, w, h)
            lx, ly = Fit(lx, ly + row * (h + GAP), w, h, inner)
            if not lx then return end
            local cost, clash = 0, 0
            for _, t in ipairs(taken) do
                if t[5] ~= p then
                    local o = Overlap(lx, ly, w, h, t[1], t[2], t[3], t[4])
                    cost = cost + o
                    if t[6] then clash = clash + o end
                end
            end
            return lx, ly, cost, clash
        end
        local bx, by, bestCost, bestClash, bestSide, bestRow
        local function Consider(side, row)
            if not side or bestCost == 0 then return end
            -- (above moves only up, below only down: never over its dot)
            if (side == "above" and row < 0) or (side == "below" and row > 0) then return end
            local lx, ly, cost, clash = Try(side, row)
            if lx and (not bestCost or cost < bestCost) then
                bx, by, bestCost, bestClash, bestSide, bestRow = lx, ly, cost, clash, side, row
            end
        end
        Consider(p.memo.side, p.memo.row or 0)
        for _, row in ipairs(ROWS) do
            for _, side in ipairs(sides) do Consider(side, row) end
        end
        if bx and bestClash == 0 then
            p.memo.side, p.memo.row = bestSide, bestRow
            taken[#taken + 1] = { bx, by, w, h, p, true }
            p.label:ClearAllPoints()
            p.label:SetPoint("BOTTOMLEFT", overlay, "CENTER", bx, by)
            p.label:Show()
        else
            p.memo.row = nil
            p.label:Hide()
        end
    end
end

overlay:SetScript("OnUpdate", Place)

local UpdateScans
function MM.ApplyLabels()
    local on = MM.Settings().labels and N.Supported()
    overlay:SetShown(on and true or false)
    UpdateScans(true, false)
end

function MM.SetLabels(on)
    MM.Settings().labels = on
    MM.ApplyLabels()
end

-- The hotkey, the touchpad / override action, the key binding: labels on
-- or off
local lastToggle = 0
function MM.Toggle()
    -- (a click arrives twice: down and up)
    if GetTime() - lastToggle < 0.3 then return end
    lastToggle = GetTime()
    if not N.Supported() then
        IF.Print("This client can't read the minimap.")
        return
    end
    MM.SetLabels(not MM.Settings().labels)
end

-- (a key binding's click comes on the press and again on the release:
-- acted on the press, its release let go; a /click sends one of them,
-- acted on: as the core's IF.Actions.PressButton)
local toggle = K.NewFrame("Button", "ImprovedForeverNodeScan", UIParent)
toggle:RegisterForClicks("AnyDown", "AnyUp")
toggle:SetScript("OnClick", function(self, _, down)
    if down then
        self.pressed = true
    elseif self.pressed then
        self.pressed = false
        return
    end
    lastToggle = 0
    MM.Toggle()
end)
_G["BINDING_NAME_CLICK ImprovedForeverNodeScan:LeftButton"] = "Minimap labels"

---------------------------------------------------------------------------
-- The hotkey: a button, or one held + one pressed ("PADLSHOULDER+PADDUP").
-- Watched, not taken over: the buttons keep their own actions too.
---------------------------------------------------------------------------
function MM.Key()
    return IF.db and IF.db.minimapKey
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- Its name: "L1 + D-pad Up"; glyphs too with size
function MM.KeyText(size)
    local key = MM.Key()
    if not key then return "Not bound" end
    local held, pressed = Parts(key)
    local function one(k)
        return (size and (IF.GlyphText(k, size) .. " ") or "") .. IF.ButtonName(k)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

function MM.SetKey(key)
    IF.db.minimapKey = key
end

local keyWatch = CreateFrame("Frame")
local wasDown = false
keyWatch:SetScript("OnUpdate", function()
    local key = MM.Key()
    -- (only while the game has the gamepad's focus, Binds.lua)
    if not key or not IsKeyDown or (IF.Menu and IF.Menu.IsOpen()) or not IF.Binds.InGame() then
        wasDown = false
        return
    end
    local held, pressed = Parts(key)
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held))
    -- The moment the combination is made
    if down and not wasDown then
        lastToggle = 0
        MM.Toggle()
    end
    wasDown = down
end)

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
local banner = K.NewFrame("Frame", "ImprovedForeverMinimapAlert", UIParent)
banner:SetSize(360, 50)
banner:SetPoint("TOP", UIParent, "TOP", 0, -220)
banner:SetFrameStrata("HIGH")
banner:Hide()
banner.name = K.Text(banner, 20, KC.cream)
banner.name:SetPoint("TOP")
banner.name:SetJustifyH("CENTER")
banner.name:SetShadowOffset(1, -1)
banner.info = K.ChatText(banner, 14, KC.cream2)
banner.info:SetPoint("TOP", banner.name, "BOTTOM", 0, -4)
banner.info:SetJustifyH("CENTER")
banner.info:SetShadowOffset(1, -1)
banner:SetScript("OnUpdate", function(self)
    local left = self.ends - GetTime()
    if left <= 0 then return self:Hide() end
    self:SetAlpha(math.min(1, left))
end)

local function Wanted(name)
    local how = MM.Settings().alertFor
    if how == "all" then return true end
    if how == "any" then return N.Kind(name) ~= nil end
    local state = N.State(name)
    if how == "gather" then return state ~= nil and state ~= "red" end
    return state == "orange" or state == "yellow" or state == "green"
end

-- "Silverleaf x2" in its colour
local function Label(node)
    local c = MM.LabelColor(node)
    local title = N.QuestBlock(node.name)
    if title then return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, title) end
    local name = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, name)
end

function MM.Alert(node, more)
    local s = MM.Settings()
    if s.alertWith == "both" or s.alertWith == "vibe" then Vibrate() end
    local sound = SOUNDKIT and (SOUNDKIT.MAP_PING or SOUNDKIT.RAID_WARNING)
    if (s.alertWith == "both" or s.alertWith == "sound") and sound then PlaySound(sound, "Master") end
    banner.name:SetText(Label(node) .. (more > 0 and ("  |cffb9ab8c+" .. more .. " more|r") or ""))
    banner.info:SetText(N.Direction(node) .. " · " .. N.Distance(node))
    banner.ends = GetTime() + 5
    banner:SetAlpha(1)
    banner:Show()
end

-- What was there at the last look: name -> how many
local seen = {}

local function Watch(found)
    local counts, fresh = {}, {}
    for _, node in ipairs(found) do
        if Wanted(node.name) then
            counts[node.name] = (counts[node.name] or 0) + node.count
            fresh[#fresh + 1] = node
        end
    end
    -- New: a name not seen, or more of it than before
    local new = {}
    for _, node in ipairs(fresh) do
        if (counts[node.name] or 0) > (seen[node.name] or 0) then new[#new + 1] = node end
    end
    seen = counts
    if #new == 0 then return end
    table.sort(new, function(a, b) return N.Yards(a) < N.Yards(b) end)
    MM.Alert(new[1], #new - 1)
end

---------------------------------------------------------------------------
-- The scans: one at a time (NodeScan.lua spreads each over frames), shared
-- by the labels (every SCAN) and the alerts (every interval); each keeps
-- the last scan's dots until the next is read. None while neither is on,
-- nor while Find Herbs / Find Minerals is off and only herbs and ore are
-- wanted: nothing to find. Every dot read when more than herbs and ore are
-- labelled
---------------------------------------------------------------------------
local scanner = CreateFrame("Frame")
scanner:Hide()
local labelsLeft, alertLeft = 0, 0

-- A scan's dots to the labels, and to the alerts when their look is due
local function Publish(found)
    -- (a scan of herbs and ore alone, for the alerts, leaves out the other
    -- labels: those kept until the next whole one)
    if overlay:IsShown() and (found.all or GatherOnly()) then Rescan(found) end
    local s = MM.Settings()
    if s.alert and alertLeft <= 0 and not IF.InCombat() and (found.all or s.alertFor ~= "all") then
        alertLeft = s.interval
        Watch(found)
    end
end

scanner:SetScript("OnUpdate", function(_, elapsed)
    labelsLeft, alertLeft = labelsLeft - elapsed, alertLeft - elapsed
    if N.Running() then return end
    local s = MM.Settings()
    local labels = overlay:IsVisible() and labelsLeft <= 0
    local alerts = s.alert and alertLeft <= 0 and not IF.InCombat() and N.Supported() and Minimap:IsVisible()
    if not (labels or alerts) then return end
    if labels then labelsLeft = PlayerPos() and SCAN or SCAN / 2 end
    -- (every dot: alerts for anything, or labels for more than herbs and ore)
    local all = (s.alert and s.alertFor == "all") or (overlay:IsVisible() and not GatherOnly())
    if not all and N.Tracking() == false then return Publish({}) end
    N.Start({ all = all }, Publish)
end)

-- (labels / alerts: looked for at once)
UpdateScans = function(labels, alerts)
    if labels then labelsLeft = 0 end
    if alerts then alertLeft = 0 end
    local s = MM.Settings()
    local on = (s.labels and N.Supported()) or s.alert
    scanner:SetShown(on and true or false)
    if not on then N.Stop() end
end

function MM.ApplyAlert()
    seen = {}
    UpdateScans(false, true)
end

IF.OnLogin(function()
    MM.ApplyLabels()
    MM.ApplyAlert()
end)

-- /if nodes [step <n>|debug]: labels on / off, the scan's spacing, one scan
-- printed dot by dot
function MM.Command(option, value)
    value = tonumber(value)
    if option == "step" and value and value >= 2 then
        N.step = value
    elseif option == "debug" then
        -- One scan, each dot printed
        if not N.Start({ all = true, debug = true }, function(found)
            IF.Print("Minimap: " .. #found .. " dot(s)")
        end) then
            IF.Print("This client can't read the minimap now.")
        end
        return
    elseif option then
        IF.Print("usage: /if nodes [step <n>|debug]")
        return
    else
        lastToggle = 0
        return MM.Toggle()
    end
    IF.Print("Minimap nodes: step " .. N.step)
end

-- Its binding, on the Bindings tab (Binds.lua) and the Minimap tab
local B = IF.Binds
B.Add({
    id = "minimap", label = "Minimap labels", group = "Other", tab = "minimap",
    icon = IF.TEX .. "ic_fn_labels", context = "world", order = 30,
    desc = "Shows / hides names beside the minimap's dots",
    tip = "Shows / hides the names beside the minimap's dots. Watched only: the buttons keep their own"
        .. " actions too.",
    accepts = B.NotDouble,
    specs = function() return B.One(IF.Minimap.Key()) end,
    set = function(spec) IF.Minimap.SetKey(spec) end,
    run = function(down) if down then MM.Toggle() end end,
})
