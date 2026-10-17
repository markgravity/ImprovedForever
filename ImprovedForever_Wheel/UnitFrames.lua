-- While the Group wheel is up, the picked member's unit frame gets a
-- highlight of ours: the game's raid-style party / raid frames, or another
-- addon's (ForeverUI, Z-Perl, EllesmereUI...: any secure unit button,
-- found by its "unit" attribute, as LibGetFrame finds them). Their frames
-- are only looked at, through clean widget methods (another addon's
-- replaced metatable can't run in ours), never changed, anchored to or
-- clicked: ours sits on UIParent, placed by their rect. The pick itself
-- never goes through a frame (Group.lua: unit tokens).
local IF = ImprovedForever

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- (clean methods: a Frame's, which a Button has too)
local probe = CreateFrame("Frame")
local mt = getmetatable(probe)
local M = (mt and type(mt.__index) == "table") and mt.__index or probe
local GetAttribute, IsVisible, GetChildren, GetRect = M.GetAttribute, M.IsVisible, M.GetChildren, M.GetRect
local GetName, GetObjectType, GetEffectiveScale, IsForbidden =
    M.GetName, M.GetObjectType, M.GetEffectiveScale, M.IsForbidden
local GetRegions = M.GetRegions
-- (and a texture's, for its parts: a portrait, a name)
local rmt = getmetatable(probe:CreateTexture())
local R = (rmt and type(rmt.__index) == "table") and rmt.__index or {}

-- Which of several frames showing one unit: the Interface module's cards
-- first (the game's party frames are faded under them), then group frames
-- (by the names LibGetFrame knows), the player / target frames last
local PREFER = {
    "^ImprovedForeverPartyCard", "^ImprovedForeverMinionCard",
    "^CompactParty", "^CompactRaid", "^XPerl_Raid_Grp", "^XPerl_party", "^ERF", "^ElvUF_Raid", "^ElvUF_Party",
    "^oUF_.-Raid", "^oUF_.-Party", "^Cell", "^Grid2Layout", "^Vd", "^HealBot_HealUnit", "^SUFHeader",
    "^PitBull4_Groups", "^Dander", "^PartyFrame", "^PartyMemberFrame",
}
local AVOID = { "^PlayerFrame", "^TargetFrame", "^FocusFrame", "[Tt]arget", "[Ff]ocus" }

local function Rank(name)
    if type(name) ~= "string" then return 50 end
    for i, pattern in ipairs(PREFER) do
        if name:find(pattern) then return i end
    end
    for _, pattern in ipairs(AVOID) do
        if name:find(pattern) then return 100 end
    end
    return 50
end

-- (never reached into: restricted, or ours but the Interface module's
-- party and minion cards)
local function Skipped(frame)
    if IsForbidden and IsForbidden(frame) then return true end
    local name = GetName(frame)
    if type(name) ~= "string" then return false end
    if name:find("^ImprovedForeverPartyCard") or name:find("^ImprovedForeverMinionCard") then return false end
    return (name:find("NamePlate") or name:find("^ImprovedForever")) and true or false
end

---------------------------------------------------------------------------
-- The unit buttons on screen: { frame, rank }, found out of combat, a few
-- milliseconds a frame (their units are read again each time: a group
-- header hands them round)
---------------------------------------------------------------------------
local frames = {}

-- The game's own (by name: there before the first scan, or in a fight;
-- made on first need, again after a group change)
local native
local function Native()
    if native then return native end
    local list = {}
    local function Add(name)
        local f = _G[name]
        if f and not Skipped(f) then list[#list + 1] = { frame = f, rank = Rank(name) } end
    end
    for i = 1, 5 do Add("CompactPartyFrameMember" .. i) end
    for i = 1, 40 do Add("CompactRaidFrame" .. i) end
    for g = 1, 8 do
        for i = 1, 5 do Add("CompactRaidGroup" .. g .. "Member" .. i) end
    end
    native = list
    return list
end

local BUDGET_MS, MAX_DEPTH = 2, 40
local scan
local scanner = CreateFrame("Frame")
scanner:Hide()

local function Walk(found, frame, depth, started)
    if depth > MAX_DEPTH or Skipped(frame) or not IsVisible(frame) then return started end
    if GetObjectType(frame) == "Button" then
        local unit = GetAttribute(frame, "unit")
        if type(unit) == "string" and not Secret(unit) then
            found[#found + 1] = { frame = frame, rank = Rank(GetName(frame)) }
        end
    end
    for _, child in ipairs({ GetChildren(frame) }) do
        if debugprofilestop() - started > BUDGET_MS then
            coroutine.yield()
            started = debugprofilestop()
        end
        started = Walk(found, child, depth + 1, started)
    end
    return started
end

local function Scan()
    if scan or IF.InCombat() then return end
    scan = coroutine.create(function()
        local found = {}
        Walk(found, UIParent, 0, debugprofilestop())
        frames = found
    end)
    scanner:Show()
end

scanner:SetScript("OnUpdate", function(self)
    if not scan or IF.InCombat() then return end
    local ok = coroutine.resume(scan)
    if not ok or coroutine.status(scan) == "dead" then
        scan = nil
        self:Hide()
    end
end)

local queued = false
local function QueueScan()
    if queued then return end
    queued = true
    C_Timer.After(1, function()
        queued = false
        native = nil
        Scan()
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", QueueScan)

-- The frame showing a unit token now, or nil
local function Same(a, b)
    if a == b then return true end
    if not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, a, b)
    return ok and not Secret(same) and same == true
end

local function Find(token, list, best, bestRank)
    for _, f in ipairs(list) do
        if f.rank < (bestRank or math.huge) and IsVisible(f.frame) then
            local unit = GetAttribute(f.frame, "unit")
            if type(unit) == "string" and not Secret(unit) and Same(unit, token) then
                best, bestRank = f.frame, f.rank
            end
        end
    end
    return best, bestRank
end

---------------------------------------------------------------------------
-- The highlight: a soft gold glow that follows the frame's shape, breathing.
-- Its bars (and the name over them) get a rounded one (ic_frame_glow, a
-- nine-slice whose line sits GLOW_OUT in from its edge), its portrait a
-- round one (ic_round_glow: the circle 40 of its 64 across); a frame with
-- neither, one round all of it. Both only outside the edge, a little off
-- it (GAP: clear of the frame's own gold border).
---------------------------------------------------------------------------
local GLOW_OUT, GAP = 20, 2
-- (the portrait's ring art sits a little outside the portrait itself)
local RING_SCALE = 64 / 40 * 1.12
local GOLD = { 1, 0.82, 0 }

local glow = CreateFrame("Frame", nil, UIParent)
glow:SetFrameStrata("HIGH")
glow:SetAllPoints(UIParent)
glow:Hide()

local body = CreateFrame("Frame", nil, glow)
local slice = IF.ConfigKit.NineSlice(body, "ic_frame_glow", 64, 64, 24, 24, "OVERLAY")
for _, part in ipairs(slice.parts) do
    part:SetVertexColor(unpack(GOLD))
    part:SetBlendMode("BLEND")
end
local round = glow:CreateTexture(nil, "OVERLAY")
round:SetTexture(IF.TEX .. "ic_round_glow")
round:SetVertexColor(unpack(GOLD))

local pulse = glow:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.55)
fade:SetDuration(0.8)
fade:SetSmoothing("IN_OUT")
glow:SetScript("OnShow", function() pulse:Play() end)
glow:SetScript("OnHide", function() pulse:Stop() end)

-- A frame's or a region's rect in UIParent's units: left, bottom, right,
-- top (nil: not on screen)
local function Rect(object, methods)
    local ok, left, bottom, width, height = pcall(methods.GetRect, object)
    if not (ok and left and width and width > 1 and height and height > 1) then return nil end
    local okScale, scale = pcall(methods.GetEffectiveScale, object)
    scale = (okScale and scale or 1) / UIParent:GetEffectiveScale()
    return left * scale, bottom * scale, (left + width) * scale, (bottom + height) * scale
end

local function Shown(object, methods)
    local ok, shown = pcall(methods.IsVisible, object)
    return ok and shown
end

-- Its bars (any shown StatusBar a few levels in, and the ones it keeps by
-- the usual keys: the player frame's sit deeper), joined: l, b, r, t
local BAR_KEYS = { "healthbar", "manabar", "HealthBar", "ManaBar", "healthBar", "powerBar", "PowerBar" }
local function Join(box, l, b, r, t)
    if not l then return box end
    if not box then return { l, b, r, t } end
    box[1], box[2] = math.min(box[1], l), math.min(box[2], b)
    box[3], box[4] = math.max(box[3], r), math.max(box[4], t)
    return box
end

local function Bars(frame, depth, box)
    if depth == 1 then
        for _, key in ipairs(BAR_KEYS) do
            local bar = rawget(frame, key)
            if type(bar) == "table" and type(rawget(bar, 0)) == "userdata" and not Skipped(bar)
                and IsVisible(bar) and GetObjectType(bar) == "StatusBar" then
                box = Join(box, Rect(bar, M))
            end
        end
    end
    for _, child in ipairs({ GetChildren(frame) }) do
        if not Skipped(child) and IsVisible(child) then
            if GetObjectType(child) == "StatusBar" then
                box = Join(box, Rect(child, M))
            elseif depth < 4 then
                box = Bars(child, depth + 1, box)
            end
        end
    end
    return box
end

-- A part of it by its key (a portrait, a name), shown, as a region
local function Part(frame, ...)
    for _, key in ipairs({ ... }) do
        local part = rawget(frame, key)
        if type(part) == "table" and type(rawget(part, 0)) == "userdata" and Shown(part, R) then return part end
    end
end

local function Place(frame)
    local box = Bars(frame, 1)
    local portrait = Part(frame, "Portrait", "portrait")
    local pl, pb, pr, pt
    if portrait then pl, pb, pr, pt = Rect(portrait, R) end
    if box then
        -- (the name over the bars: as high as its top, as wide as the bars)
        local name = Part(frame, "Name", "name")
        local nt
        if name then nt = select(4, Rect(name, R)) end
        if nt and nt > box[4] and nt - box[4] < 30 then box[4] = nt end
    elseif not pl then
        local l, b, r, t = Rect(frame, M)
        box = l and { l, b, r, t }
    end
    body:SetShown(box ~= nil)
    if box then
        body:ClearAllPoints()
        local out = GLOW_OUT + GAP
        body:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", box[1] - out, box[2] - out)
        body:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", box[3] + out, box[4] + out)
    end
    round:SetShown(pl ~= nil)
    if pl then
        local size = math.max(pr - pl, pt - pb) * RING_SCALE
        round:ClearAllPoints()
        round:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (pl + pr) / 2, (pb + pt) / 2)
        round:SetSize(size, size)
    end
    glow:SetShown(box ~= nil or pl ~= nil)
end

local driver = CreateFrame("Frame")
driver:Hide()
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.05 then return end
    since = 0
    local token = IF.RingPickedUnit and IF.RingPickedUnit()
    local frame = token and Find(token, frames)
    if token and not frame then frame = Find(token, Native()) end
    if frame then Place(frame) else glow:Hide() end
end)

local ring = _G.ImprovedForeverRing
if ring then
    ring:HookScript("OnShow", function()
        if #frames == 0 then Scan() end
        driver:Show()
    end)
    ring:HookScript("OnHide", function()
        driver:Hide()
        glow:Hide()
    end)
end
