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
    herb = true, ore = true, quest = true, npc = false, party = false,
    alert = false,
    alertFor = "skill",  -- skill (gives skill), gather (can gather), any (any herb / ore), all (any dot)
    alertWith = "both",  -- both, vibe, sound, show (the message only)
    interval = 3,        -- seconds between alert scans
}

function MM.Settings()
    IF.db.minimap = IF.db.minimap or {}
    local s = IF.db.minimap
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
    if t == "quest" then return QUEST_COLOR end
    if t == "party" then
        local unit = N.GroupUnit(node.name)
        local class = unit and select(2, UnitClass(unit))
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
        return c and { c.r, c.g, c.b } or PARTY_COLOR
    end
    return Telling(node.gameColor) and node.gameColor or KC.white
end

---------------------------------------------------------------------------
-- A quest's label: each objective's count with an icon of what it is
-- (a creature, the item itself, an object, else a note): "[skull] 5/10";
-- a quest's own mark (no objectives: handed in there) a "?"; an NPC with a
-- quest for you "!" or "?" and its name
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"
local OBJECTIVE_ICONS = {
    monster = ICON .. "INV_Misc_Bone_HumanSkull_01", item = ICON .. "INV_Misc_Bag_08",
    object = ICON .. "INV_Box_02", event = ICON .. "INV_Misc_Note_01",
}
local TURN_IN = "Interface\\GossipFrame\\ActiveQuestIcon"
local AVAILABLE = "Interface\\GossipFrame\\AvailableQuestIcon"

local function Icon(path, crop)
    -- (an icon's border cropped)
    return crop and ("|T" .. path .. ":12:12:0:0:64:64:5:59:5:59|t") or ("|T" .. path .. ":12:12|t")
end

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

local function QuestText(node)
    local title, objectives = N.QuestBlock(node.name)
    if not title then
        local npc = IF.GameData and IF.GameData.QuestNpc and IF.GameData.QuestNpc(node.name)
        if npc then return Icon(npc == "start" and AVAILABLE or TURN_IN) .. " " .. node.name end
        if N.QuestID(node.name) or not node.name:find("%d+%s*/%s*%d+") then return Icon(TURN_IN) end
        title, objectives = "", { { subject = node.name, text = node.name } }
        objectives[1].have, objectives[1].need = node.name:match("(%d+)%s*/%s*(%d+)")
    end
    local questID = N.QuestID(title)
    local parts = {}
    for _, o in ipairs(objectives) do
        local kind = ObjectiveType(questID, o.subject)
        local icon = kind == "item" and ItemIcon(questID, o.subject)
        local part = icon and Icon(icon, true) or Icon(OBJECTIVE_ICONS[kind] or OBJECTIVE_ICONS.event, true)
        if o.have and o.need then
            local count = o.have .. "/" .. o.need
            -- (one done, greyed)
            if tonumber(o.have) >= tonumber(o.need) then count = "|cff808080" .. count .. "|r" end
            part = part .. count
        end
        parts[#parts + 1] = part
    end
    return table.concat(parts, "  ")
end

-- A label's words: "Silverleaf x2", "Bruiseweed (100)" for one beyond the
-- player's skill; a quest's its objectives (QuestText)
function MM.LabelText(node)
    if (node.type or N.Type(node.name)) == "quest" then return QuestText(node) end
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

local pins = {}
local function Pin(i)
    local p = pins[i]
    if p then return p end
    -- (an empty frame the size of the game's dot, over it)
    p = K.NewFrame("Frame", nil, overlay)
    p:SetSize(DOT, DOT)
    p.label = p:CreateFontString(nil, "OVERLAY")
    p.label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
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

-- The dots of a scan of the types labelled, each with its type and colour,
-- and where the player stood when it began
local function Rescan(found)
    nodes = {}
    for _, node in ipairs(found) do
        node.type = N.Type(node.name)
        if MM.Labelled(node.type) then
            node.color = MM.LabelColor(node)
            node.text = MM.LabelText(node)
            nodes[#nodes + 1] = node
        end
    end
    scanEast, scanNorth = found.east, found.north
end

-- Where a label can go round its dot (x, y its centre): right, left,
-- above, below, or on it (an area's: no dot under it); the rectangle it
-- would take
local GAP = 2
local SIDES = { "right", "left", "above", "below" }
local AREA_SIDES = { "center", "above", "below", "right", "left" }
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
local function Place()
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
        local x, y = (east * c + north * s) * units, (-east * s + north * c) * units
        if x * x + y * y > edge * edge then
            p:Hide()
        else
            p:ClearAllPoints()
            p:SetPoint("CENTER", overlay, "CENTER", x, y)
            local color = node.color or KC.white
            p.label:SetTextColor(color[1], color[2], color[3])
            p.label:SetText(node.text)
            p.x, p.y, p.area = x, y, node.area
            if not p.area and p.side == "center" then p.side = nil end
            p:Show()
            shown[#shown + 1] = p
        end
    end
    for i = #nodes + 1, #pins do pins[i]:Hide() end
    -- Each label on the first side clear of the dots and the labels placed
    -- already: the side it had (no flicker), then towards the middle first
    -- (an area has no dot of its own; a label stays inside the minimap)
    local taken = {}
    for _, p in ipairs(shown) do
        if not p.area then taken[#taken + 1] = { p.x - DOT / 2, p.y - DOT / 2, DOT, DOT, p } end
    end
    local inner = radius - 2
    for _, p in ipairs(shown) do
        local w, h = p.label:GetStringWidth(), p.label:GetStringHeight()
        local order = { p.side }
        if not p.area then order[#order + 1] = p.x > 0 and "left" or "right" end
        for _, side in ipairs(p.area and AREA_SIDES or SIDES) do order[#order + 1] = side end
        local best, bestCost
        for _, side in ipairs(order) do
            local lx, ly = LabelRect(side, p.x, p.y, w, h)
            local cost = 0
            for _, t in ipairs(taken) do
                if t[5] ~= p then cost = cost + Overlap(lx, ly, w, h, t[1], t[2], t[3], t[4]) end
            end
            -- (past the minimap's edge counts against it too)
            cost = cost + Outside(lx, ly, w, h, inner) * (w + h)
            if not bestCost or cost < bestCost then best, bestCost = side, cost end
            if cost == 0 then break end
        end
        p.side = best
        local lx, ly = LabelRect(best, p.x, p.y, w, h)
        lx, ly = Fit(lx, ly, w, h, inner)
        if lx then
            taken[#taken + 1] = { lx, ly, w, h, p }
            p.label:ClearAllPoints()
            p.label:SetPoint("BOTTOMLEFT", overlay, "CENTER", lx, ly)
            p.label:Show()
        else
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
