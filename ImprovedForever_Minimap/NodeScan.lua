-- Reading the minimap: what its dots are (herbs, ore, quest givers, party
-- members...), and where, without a mouse. Minimap.lua builds the labels
-- and the alerts on it.
--
-- The game draws the minimap's dots itself and tells addons only the names
-- under the minimap's hover point (C_TooltipInfo.GetMinimapMouseover, what
-- its own tooltip shows). Forever's minimap can be told where that point is
-- (Minimap:UpdateMouseoverAtPoint, in screen pixels, for the controller's
-- soft cursor), and answers at once. So a grid of points over the minimap is
-- read, a little each frame; the points that read the same name side by
-- side are one dot, and their middle is where it is.
local IF = ImprovedForever

local N = {}
IF.NodeScan = N

N.step = 6           -- spacing of the points read, in minimap units
N.debug = false      -- print each scan's dots

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function N.Facing()
    local f = GetPlayerFacing and GetPlayerFacing()
    if type(f) ~= "number" or Secret(f) then return nil end
    return f
end

-- The player's place in the world, as yards east and north, or nil (in an
-- instance). The world's x runs north, its y west; UnitPosition gives x
-- first (measured against the minimap's own dots as the player walks).
function N.Position()
    if not UnitPosition then return nil end
    local x, y = UnitPosition("player")
    if type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    return -y, x
end

function N.Supported()
    return Minimap and Minimap.UpdateMouseoverAtPoint and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover
        and true or false
end

---------------------------------------------------------------------------
-- Herbs and ore: the skill each needs (Classic and Burning Crusade, the
-- names as the minimap shows them in English)
---------------------------------------------------------------------------
local HERBS = {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Bloodthistle"] = 1, ["Earthroot"] = 15, ["Mageroyal"] = 50,
    ["Briarthorn"] = 70, ["Stranglekelp"] = 85, ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115,
    ["Grave Moss"] = 120, ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160, ["Goldthorn"] = 170,
    ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195, ["Firebloom"] = 205, ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220, ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270, ["Mountain Silversage"] = 280,
    ["Plaguebloom"] = 285, ["Icecap"] = 290, ["Bloodvine"] = 300, ["Black Lotus"] = 300, ["Felweed"] = 300,
    ["Dreaming Glory"] = 315, ["Ragveil"] = 325, ["Terocone"] = 325, ["Flame Cap"] = 335,
    ["Ancient Lichen"] = 340, ["Netherbloom"] = 350, ["Netherdust Bush"] = 350, ["Nightmare Vine"] = 365,
    ["Mana Thistle"] = 375,
}
local ORES = {
    ["Copper Vein"] = 1, ["Tin Vein"] = 65, ["Incendicite Mineral Vein"] = 65, ["Silver Vein"] = 75,
    ["Ooze Covered Silver Vein"] = 75, ["Lesser Bloodstone Deposit"] = 75, ["Iron Deposit"] = 125,
    ["Indurium Mineral Vein"] = 150, ["Gold Vein"] = 155, ["Ooze Covered Gold Vein"] = 155,
    ["Mithril Deposit"] = 175, ["Ooze Covered Mithril Deposit"] = 175, ["Truesilver Deposit"] = 230,
    ["Ooze Covered Truesilver Deposit"] = 230, ["Dark Iron Deposit"] = 230, ["Small Thorium Vein"] = 245,
    ["Ooze Covered Thorium Vein"] = 245, ["Rich Thorium Vein"] = 275, ["Ooze Covered Rich Thorium Vein"] = 275,
    ["Hakkari Thorium Vein"] = 275, ["Nethercite Deposit"] = 275, ["Fel Iron Deposit"] = 300,
    ["Small Obsidian Chunk"] = 305, ["Large Obsidian Chunk"] = 305, ["Adamantite Deposit"] = 325,
    ["Rich Adamantite Deposit"] = 350, ["Khorium Vein"] = 375,
}
local SKILL_LINE = { herb = 182, ore = 186 }    -- Herbalism, Mining
local SKILL_NAME = { herb = "Herbalism", ore = "Mining" }

-- "herb" / "ore" and the skill it needs, or nil
function N.Kind(name)
    if HERBS[name] then return "herb", HERBS[name] end
    if ORES[name] then return "ore", ORES[name] end
end

-- The player's skill in a kind's profession (nil: not learnt)
local skills, bonuses
local function ReadSkills()
    skills, bonuses = {}, {}
    if not (GetProfessions and GetProfessionInfo) then return end
    for _, index in pairs({ GetProfessions() }) do
        local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
        for kind, id in pairs(SKILL_LINE) do
            if line == id then skills[kind], bonuses[kind] = rank, modifier end
        end
    end
end

function N.Skill(kind)
    if not skills then ReadSkills() end
    return skills[kind]
end

-- Its racial / item bonus, included in N.Skill (nil: none reported)
function N.SkillBonus(kind)
    if not skills then ReadSkills() end
    return bonuses[kind]
end

function N.SkillName(kind)
    return SKILL_NAME[kind]
end

-- How a node stands against the player's skill, as the game colours a
-- profession's recipes: red can't gather it, orange always gives a skill
-- point, yellow mostly, green rarely, grey never. nil: not a herb or ore,
-- or its profession not learnt
N.STATES = { "orange", "yellow", "green", "grey", "red" }
N.COLORS = {
    red = { 1, 0.1, 0.1 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 },
    green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 },
}
function N.State(name)
    local kind, need = N.Kind(name)
    local skill = kind and N.Skill(kind)
    if not skill then return nil end
    if skill < need then return "red" end
    if skill < need + 25 then return "orange" end
    if skill < need + 50 then return "yellow" end
    if skill < need + 100 then return "green" end
    return "grey"
end

function N.Color(name)
    local c = N.COLORS[N.State(name) or ""]
    if c then return c[1], c[2], c[3] end
    return 1, 1, 1
end

---------------------------------------------------------------------------
-- What a dot is, by its name: "herb", "ore", "quest" (a quest of the log's,
-- its area or objective as the minimap marks it, or an NPC with a quest to
-- give or take: the core's game data), "party" (a party or raid member) or
-- "npc" (the rest: the NPCs and creatures tracking shows)
---------------------------------------------------------------------------
N.TYPES = { "herb", "ore", "quest", "npc", "party" }

-- The quests in the log, by title -> its quest ID (true: unknown)
local questTitles
local function QuestTitles()
    if questTitles then return questTitles end
    questTitles = {}
    local log = C_QuestLog
    if log and log.GetNumQuestLogEntries and log.GetInfo then
        for i = 1, log.GetNumQuestLogEntries() or 0 do
            local info = log.GetInfo(i)
            local title = info and not info.isHeader and info.title
            if type(title) == "string" and not Secret(title) then questTitles[title] = info.questID or true end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() or 0 do
            local title, _, _, header = GetQuestLogTitle(i)
            if type(title) == "string" and not header then questTitles[title] = true end
        end
    end
    return questTitles
end

function N.IsQuestTitle(name)
    return QuestTitles()[name] ~= nil
end

-- A quest of the log's ID, by its title (nil: not in the log, or unknown)
function N.QuestID(title)
    local id = QuestTitles()[title]
    return type(id) == "number" and id or nil
end

-- A quest's area as the minimap names it: its title and the objectives
-- under it ("Night Web's Hollow\n5/10 Young Night Web Spider slain"), one
-- name (NamesAt). Its title and objectives: { have, need (nil: no count),
-- subject ("Young Night Web Spider slain"), text }
function N.QuestBlock(name)
    local title, rest = name:match("^([^\n]*)\n(.*)$")
    if not title then return nil end
    local objectives = {}
    for line in rest:gmatch("[^\n]+") do
        local have, need, subject = line:match("^(%d+)%s*/%s*(%d+)%s*(.*)$")
        if not have then
            -- ("Young Night Web Spider slain: 5/10", the quest log's way)
            subject, have, need = line:match("^(.-):?%s*(%d+)%s*/%s*(%d+)$")
        end
        objectives[#objectives + 1] = { have = tonumber(have), need = tonumber(need),
            subject = subject or line, text = line }
    end
    return title, objectives
end

-- The party / raid unit a name is ("party2", "raid14"), or nil
function N.GroupUnit(name)
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n == 0 then return nil end
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and n or n - 1 do
        local unit = (raid and "raid" or "party") .. i
        local unitName, realm = UnitName(unit)
        if type(unitName) == "string" and not Secret(unitName) then
            if unitName == name then return unit end
            if type(realm) == "string" and realm ~= "" and not Secret(realm) and unitName .. "-" .. realm == name then
                return unit
            end
        end
    end
end

local types = {}     -- name -> its type, until the quests or the group change
function N.Type(name)
    local kind = N.Kind(name)
    if kind then return kind end
    local t = types[name]
    if t then return t end
    if name:find("\n") or QuestTitles()[name] or name:find("%d+%s*/%s*%d+") then
        t = "quest"
    elseif N.GroupUnit(name) then
        t = "party"
    elseif IF.GameData and IF.GameData.QuestNpc and IF.GameData.QuestNpc(name) then
        t = "quest"
    else
        t = "npc"
    end
    types[name] = t
    return t
end

local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("CHAT_MSG_SKILL")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event)
    if event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" or event == "PLAYER_LOGIN" then skills = nil end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" or event == "PLAYER_LOGIN" then questTitles = nil end
    if event ~= "SKILL_LINES_CHANGED" and event ~= "CHAT_MSG_SKILL" then types = {} end
end)

---------------------------------------------------------------------------
-- Herbs and ore show on the minimap only while Find Herbs / Find Minerals
-- is on (Forever's spells and their icons)
---------------------------------------------------------------------------
local FIND_SPELLS = { [2383] = true, [8387] = true, [2580] = true, [8388] = true }
local FIND_ICONS = { [133939] = true, [134183] = true, [136025] = true }

-- The player has professions, and neither is Herbalism nor Mining
local function NoGathering()
    if not (GetProfessions and GetProfessionInfo) then return false end
    local any = false
    for _, index in pairs({ GetProfessions() }) do
        local line = select(7, GetProfessionInfo(index))
        if line == SKILL_LINE.herb or line == SKILL_LINE.ore then return false end
        any = true
    end
    return any
end

-- true: one of them is on; false: neither is (the tracking list has them
-- off, or the player has neither profession); nil: can't tell
function N.Tracking()
    local M = C_Minimap
    if M and M.GetNumTrackingTypes and M.GetTrackingInfo then
        local listed = false
        for i = 1, M.GetNumTrackingTypes() or 0 do
            local name, texture, active, _, _, spellID = M.GetTrackingInfo(i)
            -- (a table on newer clients)
            if type(name) == "table" then
                texture, active, spellID = name.texture, name.active, name.spellID
            end
            if not (Secret(texture) or Secret(active) or Secret(spellID))
                and (FIND_SPELLS[spellID] or FIND_ICONS[texture]) then
                if active then return true end
                listed = true
            end
        end
        if listed then return false end
    elseif GetTrackingTexture then
        -- (one tracking at a time: its icon)
        local texture = GetTrackingTexture()
        if Secret(texture) then return nil end
        return FIND_ICONS[texture] and true or false
    end
    if NoGathering() then return false end
    return nil
end

---------------------------------------------------------------------------
-- The scan
---------------------------------------------------------------------------
-- The points: inside the minimap's circle, N.step apart, every other row
-- shifted half a step (no gaps a dot can sit in)
local function Points(radius)
    local grid = {}
    local step = N.step
    local rowStep = step * 0.866
    local r = radius - 2
    local rows = math.floor(r / rowStep)
    local n = math.floor(r / step) + 1
    for j = -rows, rows do
        local shift = (j % 2) * step / 2
        for i = -n, n do
            local x, y = i * step + shift, j * rowStep
            if x * x + y * y <= r * r then
                grid[#grid + 1] = { x = x, y = y }
            end
        end
    end
    return grid
end

-- A tooltip line's own colour, as { r, g, b }, or nil
local function LineColor(line)
    local c = line.leftColor
    if type(c) ~= "table" then return nil end
    if c.GetRGB then return { c:GetRGB() } end
    if c.r then return { c.r, c.g, c.b } end
end

-- name -> how many dots of it are at a point (two dots of one herb under it
-- list it twice), and name -> the colour the game gives it. The player's
-- own arrow is left out.
-- A quest area's lines: its title, then its objectives ("- 5/10 Young Night
-- Web Spider slain"), read as one name: N.QuestBlock
local function Objective(name)
    return name:match("^%-%s*(.+)$") or (name:find("^%d+%s*/%s*%d+") and name)
end

local function NamesAt(px, py, me)
    local counts, colors = {}, {}
    Minimap:UpdateMouseoverAtPoint(px, py)
    local data = C_TooltipInfo.GetMinimapMouseover()
    -- Every name in order, with its colour
    local pieces = {}
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and not Secret(text) then
            local lineColor = LineColor(line)
            for piece in text:gmatch("[^\n]+") do
                -- (a name may carry its own colour code)
                local hex = piece:match("|c%x%x(%x%x%x%x%x%x)")
                local name = strtrim((piece:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
                    :gsub("|A.-|a", "")))
                if name ~= "" and name ~= me then
                    local color = lineColor
                    if hex then
                        color = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
                            tonumber(hex:sub(5, 6), 16) / 255 }
                    end
                    pieces[#pieces + 1] = { name = name, color = color }
                end
            end
        end
    end
    local i = 1
    while i <= #pieces do
        local name, color = pieces[i].name, pieces[i].color
        i = i + 1
        -- A title with objectives under it: one name
        local lines = {}
        while pieces[i] and Objective(pieces[i].name) do
            lines[#lines + 1] = Objective(pieces[i].name)
            i = i + 1
        end
        if #lines > 0 then
            if Objective(name) then table.insert(lines, 1, Objective(name)) name = "" end
            name = name .. "\n" .. table.concat(lines, "\n")
        end
        counts[name] = (counts[name] or 0) + 1
        colors[name] = colors[name] or color
    end
    return counts, colors
end

-- Reading the whole grid at once is a few hundred calls into the game, and
-- with many dots on the minimap (a hunter tracking humanoids in a city) it
-- held up a frame every scan. So a scan reads N.budget milliseconds' worth
-- of points each frame, then groups them a name at a time, the hover point
-- put back off the minimap at the end of every frame's share. Each point
-- read is turned into yards from where the player stood when the scan began,
-- with that frame's zoom and facing and the steps taken since: a dot read
-- over several frames stays one dot while the player walks or turns.
N.budget = 1         -- milliseconds of a frame a scan may take
N.perFrame = 30      -- points (or names) a frame, where the time can't be read

local job            -- the scan under way
local runner = CreateFrame("Frame")
runner:Hide()

-- Minimap units to yards, this frame: yards a unit, the turn of a turning
-- minimap, and how far the player has walked since the scan began
local function View(j)
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or j.radius
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local facing = get("rotateMinimap") == "1" and N.Facing() or 0
    local de, dn = 0, 0
    local e, n = N.Position()
    if e and j.east then de, dn = e - j.east, n - j.north end
    return view / j.radius, math.cos(facing), math.sin(facing), de, dn
end

-- (again from the start: a new scan, or the minimap resized under one)
local function Begin(j)
    j.radius = Minimap:GetWidth() / 2
    j.points, j.i = Points(j.radius), 1
    j.east, j.north = N.Position()
    j.yards = View(j)
    j.byName, j.names, j.ni, j.found = {}, nil, 1, {}
end

-- One point: the names under it, each kept with where it is
local function Read(j, mx, my, e, yards, c, s, de, dn)
    local p = j.points[j.i]
    j.i = j.i + 1
    local counts, colors = NamesAt((mx + p.x) * e, (my + p.y) * e, j.me)
    local ex, ny = p.x * yards, p.y * yards
    -- A turning minimap has the way you face up
    local east, north = ex * c - ny * s + de, ex * s + ny * c + dn
    for name, count in pairs(counts) do
        -- (only herbs and ore, unless every dot is asked for)
        if j.all or N.Kind(name) then
            local hits = j.byName[name]
            if not hits then
                hits = {}
                j.byName[name] = hits
            end
            hits[#hits + 1] = { x = p.x, y = p.y, east = east, north = north, count = count, color = colors[name] }
        end
    end
end

-- One name's points into dots: points that read it next to each other
-- (through any chain of them) are one dot, its centre their middle. Two
-- dots of one herb closer than a dot's reach read as one, with the name
-- listed twice: counted. Each point looks only in its own cell of a grid
-- that size and the eight round it. A group of more points than a dot
-- covers is an area (a quest's): its place the point read nearest its
-- middle, inside it whatever its shape.
local NONE = {}
local AREA = 8       -- points: more is an area, not a dot
local function GroupName(j, name)
    local hits = j.byName[name]
    local near = N.step * 1.6 * j.yards
    if not (near > 0) then near = 1 end
    local near2 = near * near
    local cells, parent = {}, {}
    local function Root(k)
        while parent[k] ~= k do
            parent[k] = parent[parent[k]]
            k = parent[k]
        end
        return k
    end
    for k, hit in ipairs(hits) do
        parent[k] = k
        local cx, cy = math.floor(hit.east / near), math.floor(hit.north / near)
        for dx = -1, 1 do
            for dy = -1, 1 do
                for _, o in ipairs(cells[(cx + dx) * 100000 + cy + dy] or NONE) do
                    local other = hits[o]
                    if (other.east - hit.east) ^ 2 + (other.north - hit.north) ^ 2 <= near2 then
                        parent[Root(o)] = Root(k)
                    end
                end
            end
        end
        local key = cx * 100000 + cy
        cells[key] = cells[key] or {}
        table.insert(cells[key], k)
    end
    local groups, order = {}, {}
    for k, hit in ipairs(hits) do
        local r = Root(k)
        local g = groups[r]
        if not g then
            g = { n = 0, count = 0, x = 0, y = 0, east = 0, north = 0 }
            groups[r] = g
            order[#order + 1] = g
        end
        g.n = g.n + 1
        g.count = math.max(g.count, hit.count)
        g.x, g.y = g.x + hit.x, g.y + hit.y
        g.east, g.north = g.east + hit.east, g.north + hit.north
        g.color = g.color or hit.color
    end
    for k, hit in ipairs(hits) do
        local g = groups[Root(k)]
        if g.n > AREA then
            local d = (hit.x - g.x / g.n) ^ 2 + (hit.y - g.y / g.n) ^ 2
            if not g.best or d < g.bestD then g.best, g.bestD = hit, d end
            -- (an area's points, all: Minimap.lua keeps them in the world)
            g.points = g.points or {}
            g.points[#g.points + 1] = { hit.east, hit.north }
        end
    end
    for _, g in ipairs(order) do
        local x, y = g.x / g.n, g.y / g.n
        local east, north = g.east / g.n, g.north / g.n
        if g.best then x, y, east, north = g.best.x, g.best.y, g.best.east, g.best.north end
        if j.debug then
            local kind, need = N.Kind(name)
            local col = g.color and string.format("%02x%02x%02x", g.color[1] * 255, g.color[2] * 255, g.color[3] * 255)
            IF.Print(string.format("  %s x%d (%s): %d point(s) at %.0f,%.0f; game colour %s; needs %s, skill %s (bonus %s) -> %s",
                name:gsub("\n", " | "), g.count, N.Type(name), g.n, x, y, col or "none", tostring(need), tostring(kind and N.Skill(kind)),
                tostring(kind and N.SkillBonus(kind)), tostring(N.State(name))))
        end
        j.found[#j.found + 1] = { name = name, count = g.count, x = x, y = y, gameColor = g.color,
            east = east, north = north, area = g.best ~= nil, points = g.points }
    end
end

function N.Stop()
    job = nil
    runner:Hide()
end

function N.Running()
    return job ~= nil
end

-- Starts reading the minimap, over the next frames (a scan under way is
-- dropped). opts.all: every dot, not only herbs and ore; opts.debug: each
-- dot printed. done(found) when it's read: each dot's name, count, x / y on
-- the minimap, gameColor, east / north in yards from found.east / .north,
-- where the player stood when it began (nil: unknown); an area (a quest's)
-- area = true and its points, { east, north } each. false: the minimap
-- can't be read now
function N.Start(opts, done)
    opts = opts or {}
    if not N.Supported() or not Minimap:IsVisible() or not Minimap:GetCenter() then return false end
    job = { all = opts.all, debug = opts.debug or N.debug, done = done, me = UnitName("player") }
    Begin(job)
    runner:Show()
    return true
end

local clock = debugprofilestop
local sliceStart
local function Spent(n)
    if clock then return clock() - sliceStart >= N.budget end
    return n >= N.perFrame
end

runner:SetScript("OnUpdate", function()
    local j = job
    if not j then return N.Stop() end
    -- The minimap gone: the last scan stands
    local mx, my = Minimap:GetCenter()
    if not Minimap:IsVisible() or not mx then return N.Stop() end
    if Minimap:GetWidth() / 2 ~= j.radius then Begin(j) end
    sliceStart = clock and clock()
    local n = 0
    if j.i <= #j.points then
        local e = Minimap:GetEffectiveScale()
        local yards, c, s, de, dn = View(j)
        if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(true) end
        repeat
            Read(j, mx, my, e, yards, c, s, de, dn)
            n = n + 1
        until j.i > #j.points or Spent(n)
        -- The hover point off the minimap again, before the game's own look
        Minimap:UpdateMouseoverAtPoint(-10000, -10000)
        if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(false) end
        if j.i <= #j.points then return end
    end
    if not j.names then
        j.names = {}
        for name in pairs(j.byName) do j.names[#j.names + 1] = name end
    end
    while j.ni <= #j.names do
        if Spent(n) then return end
        GroupName(j, j.names[j.ni])
        j.ni, n = j.ni + 1, n + 1
    end
    N.Stop()
    local found = j.found
    found.east, found.north, found.all = j.east, j.north, j.all
    if j.done then j.done(found) end
end)

---------------------------------------------------------------------------
-- Where a dot is, from where the player stands and faces now
---------------------------------------------------------------------------
local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

function N.Yards(node)
    return math.sqrt(node.east ^ 2 + node.north ^ 2)
end

-- Its angle clockwise from the way the player faces (nil: facing unknown)
function N.Angle(node)
    local facing = N.Facing()
    if not facing then return nil end
    -- Bearing clockwise from north; facing turns anticlockwise from north
    return math.atan2(node.east, node.north) + facing
end

-- "2 o'clock", or a compass point when the facing is unknown
function N.Direction(node)
    local angle = N.Angle(node)
    if angle then
        local clock = math.floor(angle / (2 * math.pi) * 12 + 0.5) % 12
        return (clock == 0 and 12 or clock) .. " o'clock"
    end
    local bearing = math.atan2(node.east, node.north)
    return COMPASS[math.floor(bearing / (math.pi / 4) + 0.5) % 8 + 1]
end

function N.Distance(node)
    local yards = N.Yards(node)
    return yards < 3 and "here" or string.format("%d yd", yards + 0.5)
end
