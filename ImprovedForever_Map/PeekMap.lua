-- Peek map: while a hotkey is held, the game's own Map & Quest Log shows
-- with everything but its map faded out (its frame, the nav bar, the quest
-- list, the gamepad prompts): the map alone, see-through, placed and sized
-- as the Map tab says (PeekMapEditor.lua, IF.db.peekMap); letting go
-- closes it. The native map, so its quests, markers and arrow are all
-- there.
-- Opening a game window from addon code taints it on Forever (Touchpad.lua),
-- so the hotkey is an override binding on a secure button that runs
-- "/click <the map's micro button>" (press: opens, release: closes; on
-- Forever the quest log's, which toggles the Map & Quest Log), in combat
-- too. Set in the Bindings tab (Binds.lua); IF.db.peekMapKey. A
-- touchpad corner can hold it too (Touchpad.lua: its Interface list): it
-- clicks the map's button itself, then PeekMap.Opened.
-- While open, the map has the gamepad (its own buttons and sticks), as
-- it always does.
local IF = ImprovedForever

local K = IF.ConfigKit

local PeekMap = {}
IF.PeekMap = PeekMap

local MARGIN = 40      -- from the screen's edge, placed at one

local DEFAULTS = {
    alpha = 0.75,        -- how see-through the map is
    size = 0.6,          -- its height, of the screen's
    anchor = "CENTER",   -- where on the screen: CENTER, TOP, TOPLEFT...
    x = 0,               -- moved from there: right (+) / left (-), of the screen's width
    y = 0,               -- up (+) / down (-), of its height
    labels = true,       -- each quest's name beside its node
    legend = true,       -- the buttons' prompts, below the map
}

function PeekMap.Settings()
    local db = IF.db
    db.peekMap = db.peekMap or {}
    local settings = db.peekMap
    for k, v in pairs(DEFAULTS) do
        if settings[k] == nil then settings[k] = v end
    end
    -- (offsets were screen px once)
    for _, k in ipairs({ "x", "y" }) do
        if math.abs(settings[k]) > 0.5 then settings[k] = 0 end
    end
    settings.pins = nil
    return settings
end

---------------------------------------------------------------------------
-- The look: while the map is open for a peek, every part of the window but
-- its map (ScrollContainer) faded out, the map moved and scaled onto a
-- frame of ours placed by the settings. Put back as it closes.
-- Only looks change: no size of the map's (that would refit its canvas
-- from our code, and the values it then holds would taint the map's own
-- secure work, closing it included). The map keeps its size; one anchor
-- (its centre) and a scale put it in place.
---------------------------------------------------------------------------
local place = K.NewFrame("Frame", "ImprovedForeverPeekMapPlace", UIParent)
place:SetSize(1, 1)
place:EnableMouse(false)

-- /if peek: each line printed and kept in IF.db.peekLog (a fresh log per
-- run), read from the saved variables after a /reload
function PeekMap.Say(text)
    if not PeekMap.debug then return end
    IF.Print(text)
    local log = IF.db and IF.db.peekLog
    if log then log[#log + 1] = ("%.2f %s"):format(GetTime() % 1000, text) end
end

local peeking = false      -- the open map is a peek
local legend               -- the button prompts, on the map
local saved                -- what the look changed: { alphas, points, scale, alpha }

-- The map's size and place on the screen, for the player's map
local function Place()
    local settings = PeekMap.Settings()
    local mapID = MapUtil and MapUtil.GetDisplayableMapForPlayer and MapUtil.GetDisplayableMapForPlayer()
        or C_Map.GetBestMapForUnit("player")
    local layer = mapID and (C_Map.GetMapArtLayers(mapID) or {})[1]
    local aspect = layer and layer.layerWidth / layer.layerHeight or 1.5
    local h = UIParent:GetHeight() * settings.size
    place:SetSize(h * aspect, h)
    local a = settings.anchor
    local x = a:find("LEFT") and MARGIN or a:find("RIGHT") and -MARGIN or 0
    local y = a:find("TOP") and -MARGIN or a:find("BOTTOM") and MARGIN or 0
    place:ClearAllPoints()
    place:SetPoint(a, UIParent, a, x + settings.x * UIParent:GetWidth(), y + settings.y * UIParent:GetHeight())
end

local function Fade(region)
    saved.alphas[region] = region:GetAlpha()
    region:SetAlpha(0)
end

-- The map scaled to the place's height, centred on it (offsets in the map's
-- own scaled units, from the screen's bottom left)
local function Layout()
    local scroll = WorldMapFrame.ScrollContainer
    local w, h = scroll:GetSize()
    Place()
    local px, py = place:GetCenter()
    local placeScale = place:GetEffectiveScale()
    local parentScale = scroll:GetEffectiveScale() / scroll:GetScale()
    scroll:SetScale((place:GetHeight() * placeScale) / (h * parentScale))
    scroll:ClearAllPoints()
    scroll:SetSize(w, h)
    local mapScale = scroll:GetEffectiveScale()
    scroll:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px * placeScale / mapScale, py * placeScale / mapScale)
    PeekMap.PlaceLegend()
end

local function Apply()
    local map = WorldMapFrame
    local scroll = map and map.ScrollContainer
    if not scroll or saved then return end
    local w, h = scroll:GetSize()
    if not (w and h and w > 0 and h > 0) then return end
    saved = { alphas = {}, points = {}, scale = scroll:GetScale(), alpha = scroll:GetAlpha() }
    for _, child in ipairs({ map:GetChildren() }) do
        if child ~= scroll then Fade(child) end
    end
    for _, region in ipairs({ map:GetRegions() }) do Fade(region) end
    for i = 1, scroll:GetNumPoints() do saved.points[i] = { scroll:GetPoint(i) } end
    Layout()
    scroll:SetAlpha(PeekMap.Settings().alpha)
end

-- Spoken's place story panel and its side tab: under the gamepad UI they are
-- UIParent's, shown with the map, so they stay over a peek. Faded by an
-- animation of ours (their own alpha is Spoken's to set).
local SPOKEN_PANELS = { "SpokenZonesPanel", "SpokenZonesPanelToggle" }

local function FadeSpoken(hide)
    for _, name in ipairs(SPOKEN_PANELS) do
        local frame = _G[name]
        if frame then IF.Focus.Fade(frame, hide) end
    end
end

local function Restore()
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    FadeSpoken(false)
    if not saved then return end
    IF.Focus.DimNative(place, false)
    PeekMap.Keys(false)
    for region, alpha in pairs(saved.alphas) do region:SetAlpha(alpha) end
    if scroll then
        scroll:SetScale(saved.scale)
        scroll:ClearAllPoints()
        for _, point in ipairs(saved.points) do scroll:SetPoint(unpack(point)) end
        scroll:SetAlpha(saved.alpha)
    end
    saved = nil
end

-- (parts of the window it shows later, a footer, faded too while a peek;
-- and the game's cursor, there when the peek opened the map as a window:
-- the first one, or in combat, Focus.lua)
local refade = CreateFrame("Frame")
refade:SetScript("OnUpdate", function()
    if not (peeking and saved and WorldMapFrame) then return end
    FadeSpoken(true)
    for _, child in ipairs({ WorldMapFrame:GetChildren() }) do
        if child ~= WorldMapFrame.ScrollContainer and saved.alphas[child] == nil then Fade(child) end
    end
    local pointer = _G.SmartNavigation and SmartNavigation.Pointer
    if pointer and pointer:GetAlpha() > 0 then IF.Focus.DimNative(place, true) end
end)

IF.OnLogin(function()
    local map = WorldMapFrame
    if not map then return end
    map:HookScript("OnShow", function()
        PeekMap.Say("peek: map OnShow, peeking: " .. tostring(peeking))
    end)
    map:HookScript("OnHide", function()
        PeekMap.Say("peek: map OnHide, peeking: " .. tostring(peeking))
        peeking = false
        Restore()
    end)
end)

---------------------------------------------------------------------------
-- While peeking: L1 / R1 shrink / grow the map (kept in the settings), L2 /
-- R2 move the focus (the super-tracked quest) to the previous / next
-- tracked quest. Override bindings on a
-- button of ours, only while the game has the pad (not when the map took it
-- as a window: a window keeps its buttons), out of combat.
---------------------------------------------------------------------------
local STEP, MIN_SIZE, MAX_SIZE = 0.05, 0.3, 0.95
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
local KEYS = { PADLTRIGGER = "prev", PADRTRIGGER = "next", PADLSHOULDER = "smaller", PADRSHOULDER = "bigger" }

-- (on a frame above the map's strata, else the map's window covers them)
local labelFrame = CreateFrame("Frame", nil, UIParent)
labelFrame:SetFrameStrata("FULLSCREEN_DIALOG")
labelFrame:SetAllPoints(UIParent)
labelFrame:EnableMouse(false)

local function QuestName(id)
    local name = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if name then return name end
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    local info = index and C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
    return info and info.title or (C_QuestLog.GetQuestInfo and C_QuestLog.GetQuestInfo(id))
end

-- The next quest to focus, step -1 / +1 (round the list): the quests with a
-- node on the map, left to right (UpdateLabels keeps the list), else the
-- tracked ones
local function MoveFocus(step)
    local ids = {}
    for _, id in ipairs(PeekMap.cycle or {}) do ids[#ids + 1] = id end
    if #ids == 0 then
        for i = 1, C_QuestLog.GetNumQuestWatches() do ids[#ids + 1] = C_QuestLog.GetQuestIDForQuestWatchIndex(i) end
    end
    local n = #ids
    if n == 0 then return end
    local current = C_SuperTrack.GetSuperTrackedQuestID()
    local index = 0
    for i = 1, n do
        if ids[i] == current then index = i end
    end
    local target = index == 0 and (step > 0 and 1 or n) or ((index - 1 + step) % n + 1)
    C_SuperTrack.SetSuperTrackedQuestID(ids[target])
end

local function Resize(step)
    local settings = PeekMap.Settings()
    local size = math.floor((settings.size + step) * 100 + 0.5) / 100
    settings.size = math.max(MIN_SIZE, math.min(MAX_SIZE, size))
    if peeking and saved then Layout() end
end

local catch = CreateFrame("Button", "ImprovedForeverPeekMapCatch", UIParent)
catch:RegisterForClicks("AnyDown")
catch:SetScript("OnClick", function(_, key)
    local action = KEYS[key]
    if not (peeking and action) then return end
    if action == "smaller" then Resize(-STEP)
    elseif action == "bigger" then Resize(STEP)
    elseif action == "prev" then MoveFocus(-1)
    else MoveFocus(1) end
end)

local keysOn = false

function PeekMap.Keys(on)
    if IF.InCombat() then return end
    ClearOverrideBindings(catch)
    keysOn = on and IF.Binds.InGame() and true or false
    if PeekMap.ShowLegend then PeekMap.ShowLegend() end
    if not keysOn then return end
    for key in pairs(KEYS) do
        for _, modifier in ipairs(MODIFIERS) do
            SetOverrideBindingClick(catch, true, modifier .. key, catch:GetName(), key)
        end
    end
end

-- Each quest's name beside its node on the map, none over another (or over
-- a node). The nodes are the map's quest pins, read (never changed) for
-- where they are drawn; the labels are ours, on the screen. The focused
-- quest's first, so it keeps its side.
local labels = {}
local GAP, LABEL_PAD = 4, 2
local MAX_NODE = 48   -- a pin wider than this (screen units) isn't a node

-- The map's own lettering: the game's font outlined, as its place names are,
-- sized to the map (a smaller peek, smaller names)
local function FontSize()
    return math.max(9, math.min(14, math.floor(place:GetHeight() / 48 + 0.5)))
end

local function Label(i)
    local fs = labels[i]
    if not fs then
        fs = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetShadowColor(0, 0, 0, 0.8)
        fs:SetShadowOffset(1, -1)
        labels[i] = fs
    end
    return fs
end

local function Style(fs, focused)
    local font = GameFontNormalSmall:GetFont()
    fs:SetFont(font, FontSize() + (focused and 1 or 0), "OUTLINE")
    if focused then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.95, 0.9, 0.78) end
    fs:SetAlpha(focused and 1 or 0.92)
end

local function Overlaps(a, b)
    return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

local function Free(rect, taken, bounds)
    if rect.l < bounds.l or rect.r > bounds.r or rect.b < bounds.b or rect.t > bounds.t then return false end
    for _, other in ipairs(taken) do
        if Overlaps(rect, other) then return false end
    end
    return true
end

-- The map's pins: its own list of them, else the frames on its canvas
local function Pins(map)
    local list = {}
    if map.EnumerateAllPins then
        for pin in map:EnumerateAllPins() do list[#list + 1] = pin end
        return list
    end
    local canvas = map.GetCanvas and map:GetCanvas() or (map.ScrollContainer and map.ScrollContainer.Child)
    for _, child in ipairs(canvas and { canvas:GetChildren() } or {}) do
        list[#list + 1] = child
    end
    return list
end

local function UpdateLabels()
    local map = WorldMapFrame
    local used = 0
    if peeking and saved and map and PeekMap.Settings().labels then
        local ui = UIParent:GetEffectiveScale()
        local bounds = { l = place:GetLeft(), r = place:GetRight(), b = place:GetBottom(), t = place:GetTop() }
        local focused = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
        -- one node per quest: { id, x, y, radius } in the screen's units
        local nodes, seen = {}, {}
        local total, withID = 0, 0
        for _, pin in ipairs(Pins(map)) do
            total = total + 1
            local id = pin.questID or (pin.GetQuestID and pin:GetQuestID())
            if id then withID = withID + 1 end
            if id and id ~= 0 and not seen[id] and pin:IsVisible() then
                local x, y = pin:GetCenter()
                if x and bounds.l then
                    local k = pin:GetEffectiveScale() / ui
                    x, y = x * k, y * k
                    -- (not a quest's area highlight: a shape as big as the map, not a node)
                    local width = pin:GetWidth() * k
                    if width <= MAX_NODE and x >= bounds.l and x <= bounds.r and y >= bounds.b and y <= bounds.t then
                        seen[id] = true
                        nodes[#nodes + 1] = { id = id, x = x, y = y, r = math.max(6, width / 2) }
                    end
                end
            end
        end
        if PeekMap.debug and GetTime() - (PeekMap.lastLabelSay or 0) > 2 then
            PeekMap.lastLabelSay = GetTime()
            local canvas = map.GetCanvas and map:GetCanvas()
            PeekMap.Say(("peek: map has EnumerateAllPins %s, GetCanvas %s, Child %s"):format(
                tostring(map.EnumerateAllPins ~= nil), tostring(canvas ~= nil),
                tostring(map.ScrollContainer and map.ScrollContainer.Child ~= nil)))
            PeekMap.Say(("peek: labels: %d pins, %d with a quest, %d nodes on the map, bounds %s"):format(total,
                withID, #nodes, tostring(bounds.l)))
        end
        -- (the focus' order: left to right, top to bottom)
        local byPlace = {}
        for i, n in ipairs(nodes) do byPlace[i] = n end
        table.sort(byPlace, function(a, b)
            if a.x ~= b.x then return a.x < b.x end
            return a.y > b.y
        end)
        PeekMap.cycle = {}
        for i, n in ipairs(byPlace) do PeekMap.cycle[i] = n.id end
        table.sort(nodes, function(a, b)
            if (a.id == focused) ~= (b.id == focused) then return a.id == focused end
            return a.id < b.id
        end)
        -- every node is taken space first, so no label sits on one
        local taken = {}
        for _, n in ipairs(nodes) do
            taken[#taken + 1] = { l = n.x - n.r, r = n.x + n.r, b = n.y - n.r, t = n.y + n.r }
        end
        PeekMap.unnamed = 0
        local dump = PeekMap.debug and GetTime() - (PeekMap.lastDump or 0) > 4
        if dump then
            PeekMap.lastDump = GetTime()
            PeekMap.Say(("peek: bounds l%.0f r%.0f b%.0f t%.0f, ui scale %.3f"):format(bounds.l, bounds.r, bounds.b,
                bounds.t, ui))
            for _, n in ipairs(nodes) do
                PeekMap.Say(("peek: node %s %s x%.0f y%.0f r%.1f"):format(tostring(n.id), tostring(QuestName(n.id)), n.x,
                    n.y, n.r))
            end
        end
        for _, n in ipairs(nodes) do
            local name = QuestName(n.id)
            if not name then PeekMap.unnamed = PeekMap.unnamed + 1 end
            if name then
                local fs = Label(used + 1)
                Style(fs, n.id == focused)
                fs:SetText(name)
                local w, h = fs:GetStringWidth() + LABEL_PAD * 2, fs:GetStringHeight() + LABEL_PAD * 2
                local d = n.r + GAP
                -- right, left, above, below (then the corners)
                local tries = {
                    { n.x + d, n.y - h / 2 }, { n.x - d - w, n.y - h / 2 },
                    { n.x - w / 2, n.y + d }, { n.x - w / 2, n.y - d - h },
                    { n.x + d, n.y + d / 2 }, { n.x + d, n.y - d / 2 - h },
                    { n.x - d - w, n.y + d / 2 }, { n.x - d - w, n.y - d / 2 - h },
                }
                if dump then PeekMap.Say(("peek: label %s size %.0fx%.0f"):format(tostring(n.id), w, h)) end
                for _, t in ipairs(tries) do
                    local rect = { l = t[1], b = t[2], r = t[1] + w, t = t[2] + h }
                    if Free(rect, taken, bounds) then
                        used = used + 1
                        fs:ClearAllPoints()
                        fs:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.l + LABEL_PAD, rect.b + LABEL_PAD)
                        fs:Show()
                        taken[#taken + 1] = rect
                        break
                    end
                end
            end
        end
    end
    if PeekMap.debug and peeking and GetTime() - (PeekMap.lastUsedSay or 0) > 2 then
        PeekMap.lastUsedSay = GetTime()
        PeekMap.Say(("peek: labels placed %d, unnamed %d, keys on %s, in game %s, pad %s, legend shown %s"):format(
            used, PeekMap.unnamed or 0, tostring(keysOn), tostring(IF.Binds.InGame()), tostring(IF.Input.Pad()),
            tostring(legend:IsShown())))
    end
    for i = used + 1, #labels do labels[i]:Hide() end
end

-- The buttons, as a legend on the map's bottom (with the pad)
legend = IF.InputLegend(labelFrame)
local LEGEND = {
    { { "PADLTRIGGER", "PADRTRIGGER" }, { "PADLTRIGGER", "PADRTRIGGER" }, "Change quest" },
    { { "PADLSHOULDER", "PADRSHOULDER" }, { "PADLSHOULDER", "PADRSHOULDER" }, "Resize map" },
}

function PeekMap.ShowLegend()
    legend:Set(keysOn and peeking and PeekMap.Settings().legend and LEGEND or nil)
end
IF.Input.OnChange(function() PeekMap.ShowLegend() end)

-- Below the map; inside its bottom when there's no room under it
function PeekMap.PlaceLegend()
    legend:ClearAllPoints()
    local bottom = place:GetBottom()
    if bottom and bottom < 60 then
        legend:SetPoint("BOTTOM", place, "BOTTOM", 0, 8)
    else
        legend:SetPoint("TOP", place, "BOTTOM", 0, -8)
    end
end

local sinceLabels = 0
labelFrame:SetScript("OnUpdate", function(_, elapsed)
    sinceLabels = sinceLabels + elapsed
    if sinceLabels < 0.1 then return end
    sinceLabels = 0
    UpdateLabels()
end)

-- A click of ours has just opened the map (the hold button, a touchpad
-- corner): shown as the peek map
function PeekMap.Opened()
    if peeking or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    peeking = true
    Apply()
    PeekMap.Keys(true)
    if PeekMap.debug then
        local scroll = WorldMapFrame.ScrollContainer
        local n = 0
        for _ in pairs(saved and saved.alphas or {}) do n = n + 1 end
        local cx, cy = scroll:GetCenter()
        PeekMap.Say(("peek: shown, look applied: %s, map %dx%d, scale %.3f, centre %s, %s, alpha %.2f,"
            .. " visible: %s, frame alpha %.2f, frame scale %.3f, %d parts faded"):format(tostring(saved ~= nil),
            scroll:GetWidth(), scroll:GetHeight(), scroll:GetEffectiveScale(), tostring(cx and math.floor(cx)),
            tostring(cy and math.floor(cy)), scroll:GetEffectiveAlpha(), tostring(scroll:IsVisible()),
            WorldMapFrame:GetEffectiveAlpha(), WorldMapFrame:GetEffectiveScale(), n))
    end
end

---------------------------------------------------------------------------
-- The hold button: the hotkey's press opens the map (if closed), its
-- release closes it (if open), each on its own phase whatever
-- ActionButtonUseKeyDown says
---------------------------------------------------------------------------
local hold = CreateFrame("Button", "ImprovedForeverPeekMapHold", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
hold:SetSize(1, 1)
hold:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
hold:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(hold, "OnClick", hold, [[
    self:SetAttribute("type", nil)
    return self:RunAttribute("ic-peek", down, self:GetAttribute("ic-macro"))
]])

-- A peek's press (opens) or release (closes), for the hold button and a
-- touchpad corner (Touchpad.lua sets it on its button too). Out of combat
-- the map is shown directly, not as a window: Forever's gamepad UI only
-- takes the gamepad for windows (ShowUIPanel), so the player keeps moving.
-- In combat a handle to the map is refused (it isn't protected): its
-- button opens it as a window then, which takes the gamepad (and the first
-- peek, before the map has a place). Returns false
-- (nothing to run) or sets the click to run the map's button.
PeekMap.SNIPPET = [[
    local down, macro = ...
    local combat = PlayerInCombat()
    local map = not combat and self:GetFrameRef("map")
    -- Before the map's first opening as a window it has no place or size
    -- (its window layout gives it them): shown directly it is drawn nowhere.
    -- That first peek goes through its button too, as in combat, and is
    -- closed the same way.
    local scroll = not combat and self:GetFrameRef("map-scroll")
    local unplaced = scroll and (scroll:GetWidth() or 0) == 0
    local opened = self:GetAttribute("ic-peek-open")
    if map and not (down and unplaced and not map:IsShown())
            and not (not down and opened and map:IsShown()) then
        if down then
            if not map:IsShown() then
                map:Show()
                self:SetAttribute("ic-peek-shown", true)
            end
        elseif self:GetAttribute("ic-peek-shown") then
            map:Hide()
        end
        if not down then
            self:SetAttribute("ic-peek-shown", nil)
            self:SetAttribute("ic-peek-open", nil)
        end
        return false
    end
    if down then
        if self:GetAttribute("ic-peek-shown") or opened then return false end
        self:SetAttribute("ic-peek-open", true)
    else
        if not (self:GetAttribute("ic-peek-shown") or opened) then return false end
        self:SetAttribute("ic-peek-shown", nil)
        self:SetAttribute("ic-peek-open", nil)
    end
    self:SetAttribute("useOnKeyDown", down and true or false)
    self:SetAttribute("macrotext", macro)
    self:SetAttribute("type", "macro")
]]
hold:SetAttribute("ic-peek", PeekMap.SNIPPET)
hold:SetScript("PostClick", function(self, button, down)
    if PeekMap.debug then
        PeekMap.Say("peek: hotkey " .. (down and "down" or "up") .. ", ran: " .. tostring(self:GetAttribute("type"))
            .. ", map open: " .. tostring(WorldMapFrame and WorldMapFrame:IsShown()))
    end
    PeekMap.Opened()
end)

---------------------------------------------------------------------------
-- The hotkey: a button, or one held + one pressed ("PADLSHOULDER+PADDUP"),
-- taken over: an override binding on the hold button. Out of combat. A
-- key: its binding's keyboard / mouse press (Binds.lua: a click of the
-- hold button, pressed and released as the key is).
---------------------------------------------------------------------------
function PeekMap.IsPeeking()
    return peeking
end

function PeekMap.Key()
    return IF.db and IF.db.peekMapKey
end

local pending = false

function PeekMap.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = false
    -- (the core's macro for the map's button: the Controller module's
    -- touchpad not needed)
    local macro = IF.Actions and IF.Actions.Macro("map")
    if WorldMapFrame then
        hold:SetFrameRef("map", WorldMapFrame)
        if WorldMapFrame.ScrollContainer then hold:SetFrameRef("map-scroll", WorldMapFrame.ScrollContainer) end
    end
    hold:SetAttribute("ic-macro", macro)
    ClearOverrideBindings(hold)
    local key = PeekMap.Key() and IF.Binds.KeyOf(PeekMap.Key())
    -- (kept while the map has the gamepad: its release closes it)
    if key and macro then SetOverrideBindingClick(hold, true, key, hold:GetName(), "LeftButton") end
end

function PeekMap.SetKey(key)
    IF.db.peekMapKey = key
    PeekMap.Apply()
end

IF.OnLogin(PeekMap.Apply)

-- /if peek: what the hotkey is bound to and what a press does (each press
-- printed until /if peek again)
function PeekMap.Probe()
    PeekMap.debug = not PeekMap.debug
    if PeekMap.debug then IF.db.peekLog = { date("%Y-%m-%d %H:%M:%S") } end
    local spec = PeekMap.Key()
    local key = spec and IF.Binds.KeyOf(spec)
    PeekMap.Say("peek: hotkey " .. tostring(spec) .. " -> key " .. tostring(key)
        .. ", bound to: " .. tostring(key and GetBindingAction(key, true)))
    PeekMap.Say("peek: macro " .. tostring(hold:GetAttribute("ic-macro")) .. ", map frame: "
        .. tostring(WorldMapFrame ~= nil) .. ", map scroll: " .. tostring(WorldMapFrame and WorldMapFrame.ScrollContainer ~= nil)
        .. ", in combat: " .. tostring(IF.InCombat()) .. ", pending: " .. tostring(pending))
    -- (again once the chat box has closed: while it's open the click is the game's)
    if IF.Touch and IF.Touch.Probe then
        IF.Touch.Probe()
        if PeekMap.debug then C_Timer.After(2, IF.Touch.Probe) end
    end
    IF.Print("peek: press printing " .. (PeekMap.debug and "on, logged to the saved variables (/reload to write)"
        or ("off, " .. #(IF.db.peekLog or {}) .. " lines logged")))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then PeekMap.Apply() end
    -- (the peek's buttons, left bound when it ended in combat)
    if not peeking then PeekMap.Keys(false) end
end)

-- Its binding, on the Bindings tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "peekmap", label = "Peek map", group = "Other", tab = "bindings",
    corner = true,   -- (also a touchpad corner: BindEditor.lua; its action is this id)
    icon = IF.TEX .. "ic_fn_peekmap", context = "world", order = 31,
    desc = "Held: a see-through map; let go and it closes",
    tip = "Held: the game's Map & Quest Log shows with only its map, see-through (placed and sized in"
        .. " the Map tab); let go and it closes. Works in combat. Takes the press over while bound, and"
        .. " while held the map has the controller, as it always does. A touchpad corner can open it too"
        .. " (its Interface list).",
    -- (an override binding: a press one can go on)
    accepts = function(spec)
        local _, _, double = B.Parse(spec)
        return not double and B.KeyOf(spec) ~= nil
    end,
    specs = function() return B.One(IF.PeekMap.Key()) end,
    set = function(spec) IF.PeekMap.SetKey(spec) end,
    -- (a key holds it too: the same secure button)
    button = "ImprovedForeverPeekMapHold",
})
