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
    -- Scaled to the place's height, centred on it (offsets in the map's own
    -- scaled units, from the screen's bottom left)
    Place()
    local px, py = place:GetCenter()
    local placeScale = place:GetEffectiveScale()
    local scale = saved.scale * (place:GetHeight() * placeScale) / (h * scroll:GetEffectiveScale())
    scroll:SetScale(scale)
    scroll:ClearAllPoints()
    scroll:SetSize(w, h)
    local mapScale = scroll:GetEffectiveScale()
    scroll:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px * placeScale / mapScale, py * placeScale / mapScale)
    scroll:SetAlpha(PeekMap.Settings().alpha)
end

local function Restore()
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not saved then return end
    IF.Focus.DimNative(place, false)
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

-- A click of ours has just opened the map (the hold button, a touchpad
-- corner): shown as the peek map
function PeekMap.Opened()
    if peeking or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    peeking = true
    Apply()
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
end)

-- Its binding, on the Bindings tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "peekmap", label = "Peek map", group = "Other", tab = "bindings",
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
