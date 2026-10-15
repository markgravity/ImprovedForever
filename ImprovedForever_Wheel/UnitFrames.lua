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

-- Which of several frames showing one unit: group frames first (by the
-- names LibGetFrame knows), the player / target frames last
local PREFER = {
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

-- (never reached into: restricted, or ours)
local function Skipped(frame)
    if IsForbidden and IsForbidden(frame) then return true end
    local name = GetName(frame)
    return type(name) == "string" and (name:find("NamePlate") or name:find("^ImprovedForever")) and true or false
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
-- The highlight: the game's raid frame selection art, gold
---------------------------------------------------------------------------
local glow = CreateFrame("Frame", nil, UIParent)
glow:SetFrameStrata("HIGH")
glow:Hide()
local art = glow:CreateTexture(nil, "OVERLAY")
art:SetAllPoints()
if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("RaidFrame-TargetFrame") then
    art:SetAtlas("RaidFrame-TargetFrame")
else
    art:SetTexture("Interface\\RaidFrame\\Raid-FrameHighlights")
    art:SetTexCoord(0, 0.265625, 0.09375, 0.53125)
end
art:SetVertexColor(1, 0.82, 0)

local function Place(frame)
    local left, bottom, width, height = GetRect(frame)
    if not (left and width and width > 0) then
        glow:Hide()
        return
    end
    local scale = GetEffectiveScale(frame) / UIParent:GetEffectiveScale()
    glow:ClearAllPoints()
    glow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
    glow:SetSize(width * scale, height * scale)
    glow:Show()
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
