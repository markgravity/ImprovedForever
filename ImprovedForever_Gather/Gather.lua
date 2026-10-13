-- Gathering with the minimap (NodeScan.lua reads it):
--   labels: each herb and ore on the minimap gets its name beside it,
--     coloured by the skill it gives (as the game colours recipes).
--     Shown and hidden by a hotkey (recorded
--     in the Gather tab, one button or one held + one pressed), a touchpad
--     corner / button override action, or the key binding;
--   alerts: the minimap read every few seconds, and a herb or ore worth
--     having that appears pulses the controller, plays a sound and says
--     what and where.
-- Set in the Gather tab (GatherEditor.lua); IF.db.gather.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local N = IF.NodeScan

local Gather = {}
IF.Gather = Gather

local DEFAULTS = {
    labels = false,      -- the labels on the minimap shown
    colors = true,       -- herbs and ore coloured by the skill they give
    need = true,         -- a red one's label says the skill it needs: "Bruiseweed (100)"
    alert = false,
    alertFor = "skill",  -- skill (gives skill), gather (can gather), any (any herb / ore), all (any dot)
    alertWith = "both",  -- both, vibe, sound, show (the message only)
    interval = 3,        -- seconds between alert scans
}

function Gather.Settings()
    IF.db.gather = IF.db.gather or {}
    local s = IF.db.gather
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
function Gather.SkillColor(node)
    if not Gather.Settings().colors then return nil end
    if type(node) == "table" then
        if N.Kind(node.name) and Telling(node.gameColor) then return node.gameColor end
        node = node.name
    end
    local state = N.State(node)
    return state and N.COLORS[state]
end

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- A label's words: "Silverleaf x2", "Bruiseweed (100)" for one beyond the
-- player's skill
function Gather.LabelText(node)
    local text = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    if Gather.Settings().need and N.State(node.name) == "red" then
        text = text .. " (" .. select(2, N.Kind(node.name)) .. ")"
    end
    return text
end

-- The player's place in the world, as yards east and north, or nil (in an
-- instance). The world's x runs north, its y west.
local function PlayerPos()
    if not UnitPosition then return nil end
    local y, x = UnitPosition("player")
    if type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    return -y, x
end

local function Vibrate()
    if IF.Vibe and IF.Vibe.Settings().enabled then IF.Vibe.Play("pulse") end
end

---------------------------------------------------------------------------
-- The labels: on the minimap, over its dots
---------------------------------------------------------------------------
local SCAN = 0.5     -- seconds between scans while shown (0.25 where the player's place is unknown)
local DOT = 11       -- the game's dot: a label sits just beside it

local overlay = K.NewFrame("Frame", "ImprovedForeverGatherLabels")
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

-- The herbs and ore on the minimap (NPCs, players, quest givers left out)
local function Rescan()
    nodes = {}
    for _, node in ipairs(N.Scan()) do
        if N.Kind(node.name) then nodes[#nodes + 1] = node end
    end
    scanEast, scanNorth = PlayerPos()
end

-- Where a label can go round its dot (x, y its centre): right, left,
-- above, below; the rectangle it would take
local GAP = 2
local SIDES = { "right", "left", "above", "below" }
local function LabelRect(side, x, y, w, h)
    local half = DOT / 2
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
            local color = Gather.SkillColor(node) or KC.white
            p.label:SetTextColor(color[1], color[2], color[3])
            p.label:SetText(Gather.LabelText(node))
            p.x, p.y = x, y
            p:Show()
            shown[#shown + 1] = p
        end
    end
    for i = #nodes + 1, #pins do pins[i]:Hide() end
    -- Each label on the first side clear of the dots and the labels placed
    -- already: the side it had (no flicker), then towards the middle first
    local taken = {}
    for _, p in ipairs(shown) do
        taken[#taken + 1] = { p.x - DOT / 2, p.y - DOT / 2, DOT, DOT, p }
    end
    for _, p in ipairs(shown) do
        local w, h = p.label:GetStringWidth(), p.label:GetStringHeight()
        local order = { p.side }
        local inward = p.x > 0 and "left" or "right"
        order[#order + 1] = inward
        for _, side in ipairs(SIDES) do order[#order + 1] = side end
        local best, bestCost
        for _, side in ipairs(order) do
            local lx, ly = LabelRect(side, p.x, p.y, w, h)
            local cost = 0
            for _, t in ipairs(taken) do
                if t[5] ~= p then cost = cost + Overlap(lx, ly, w, h, t[1], t[2], t[3], t[4]) end
            end
            -- (past the minimap's edge counts against it too)
            local far = math.max(math.abs(lx), math.abs(lx + w))
            if far > radius then cost = cost + (far - radius) * h end
            if not bestCost or cost < bestCost then best, bestCost = side, cost end
            if cost == 0 then break end
        end
        p.side = best
        local lx, ly = LabelRect(best, p.x, p.y, w, h)
        taken[#taken + 1] = { lx, ly, w, h, p }
        p.label:ClearAllPoints()
        p.label:SetPoint("BOTTOMLEFT", overlay, "CENTER", lx, ly)
    end
end

overlay:SetScript("OnUpdate", function(self, elapsed)
    self.left = (self.left or 0) - elapsed
    if self.left <= 0 then
        self.left = PlayerPos() and SCAN or SCAN / 2
        Rescan()
    end
    Place()
end)

function Gather.ApplyLabels()
    local on = Gather.Settings().labels and N.Supported()
    overlay.left = 0
    overlay:SetShown(on and true or false)
end

function Gather.SetLabels(on)
    Gather.Settings().labels = on
    Gather.ApplyLabels()
end

-- The hotkey, the touchpad / override action, the key binding: labels on
-- or off
local lastToggle = 0
function Gather.Toggle()
    -- (a click arrives twice: down and up)
    if GetTime() - lastToggle < 0.3 then return end
    lastToggle = GetTime()
    if not N.Supported() then
        IF.Print("This client can't read the minimap.")
        return
    end
    Gather.SetLabels(not Gather.Settings().labels)
end

local toggle = K.NewFrame("Button", "ImprovedForeverNodeScan", UIParent)
toggle:RegisterForClicks("AnyDown", "AnyUp")
toggle:SetScript("OnClick", Gather.Toggle)
_G["BINDING_NAME_CLICK ImprovedForeverNodeScan:LeftButton"] = "Minimap labels"

---------------------------------------------------------------------------
-- The hotkey: a button, or one held + one pressed ("PADLSHOULDER+PADDUP").
-- Watched, not taken over: the buttons keep their own actions too.
---------------------------------------------------------------------------
function Gather.Key()
    return IF.db and IF.db.gatherKey
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- Its name: "L1 + D-pad Up"; glyphs too with size
function Gather.KeyText(size)
    local key = Gather.Key()
    if not key then return "Not bound" end
    local held, pressed = Parts(key)
    local function one(k)
        return (size and (IF.GlyphText(k, size) .. " ") or "") .. IF.ButtonName(k)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

function Gather.SetKey(key)
    IF.db.gatherKey = key
end

local keyWatch = CreateFrame("Frame")
local wasDown = false
keyWatch:SetScript("OnUpdate", function()
    local key = Gather.Key()
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
        Gather.Toggle()
    end
    wasDown = down
end)

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
local banner = K.NewFrame("Frame", "ImprovedForeverGatherAlert", UIParent)
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
    local how = Gather.Settings().alertFor
    if how == "all" then return true end
    if how == "any" then return N.Kind(name) ~= nil end
    local state = N.State(name)
    if how == "gather" then return state ~= nil and state ~= "red" end
    return state == "orange" or state == "yellow" or state == "green"
end

-- "Silverleaf x2" in its colour
local function Label(node)
    local c = Gather.SkillColor(node) or KC.white
    local name = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, name)
end

function Gather.Alert(node, more)
    local s = Gather.Settings()
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

local function Watch()
    local s = Gather.Settings()
    if not s.alert or IF.InCombat() or not N.Supported() or not Minimap:IsVisible() then return end
    local counts, fresh = {}, {}
    for _, node in ipairs(N.Scan()) do
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
    Gather.Alert(new[1], #new - 1)
end

local watcher = CreateFrame("Frame")
watcher.left = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - elapsed
    if self.left > 0 then return end
    self.left = Gather.Settings().interval
    Watch()
end)
watcher:Hide()

function Gather.ApplyAlert()
    seen = {}
    watcher.left = 0
    watcher:SetShown(Gather.Settings().alert)
end

IF.OnLogin(function()
    Gather.ApplyLabels()
    Gather.ApplyAlert()
end)

-- /if nodes [step <n>|debug]: labels on / off, the scan's spacing, one scan
-- printed dot by dot
function Gather.Command(option, value)
    value = tonumber(value)
    if option == "step" and value and value >= 2 then
        N.step = value
    elseif option == "debug" then
        -- One scan, each dot printed
        N.debug = true
        N.Scan()
        N.debug = false
        return
    elseif option then
        IF.Print("usage: /if nodes [step <n>|debug]")
        return
    else
        lastToggle = 0
        return Gather.Toggle()
    end
    IF.Print("Minimap nodes: step " .. N.step)
end

-- Its binding, on the Controller tab (Binds.lua) and the Gather tab
local B = IF.Binds
B.Add({
    id = "gather", label = "Minimap labels", group = "Other", tab = "gather",
    icon = IF.TEX .. "ic_fn_labels", context = "world", order = 30,
    desc = "Shows / hides names beside the minimap's dots",
    tip = "Shows / hides the names beside the minimap's dots. Watched only: the buttons keep their own"
        .. " actions too.",
    accepts = B.NotDouble,
    specs = function() return B.One(IF.Gather.Key()) end,
    set = function(spec) IF.Gather.SetKey(spec) end,
})
