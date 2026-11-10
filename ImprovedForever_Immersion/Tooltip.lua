-- The game's world tooltip (the unit or object under the mouse or the soft target, anchored
-- bottom right over the action bar) drawn again as ours: to the right of your character in the
-- 3D world, between it and the quest tracker, fading in, in the Immersion look (the
-- header's gold rule fading out, the name in Morpheus, the rest small). The game's
-- stays alive but drawn at 0 (IF.Focus.Fade, an animation of ours: a property of the game's
-- frames set from addon code taints them); ours only reads its lines (text and colour).
-- A tooltip anchored to something else (an item in the bags, a button) is the game's, as it is.
-- Setting tooltip.
local IF = ImprovedForever
local IN = IF.Interface

local TT = {}
IN.Tooltip = TT

local OFFSET_X, OFFSET_Y = 230, -40     -- (from the screen's middle: right of your character)
local SLIDE = 12                        -- (it comes in from this far left)
local FADE = 0.2                        -- (seconds, in and out)
local PAD_Y = 6
local MAX_W = 360

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local panel = CreateFrame("Frame", "ImprovedForeverTooltip", UIParent)
panel:SetFrameStrata("TOOLTIP")
panel:EnableMouse(false)
panel:SetAlpha(0)
panel:Hide()

-- (the Immersion look, as the header's (HeaderSlot.lua): the spell diamonds' tile at the top with
-- the unit's portrait in it, under it a gold line running down (fading out), and the words to the
-- right of it: the name in Morpheus, the rest small with a shadow)
local HS = IN.HeaderSlot
local G = HS.GOLD
local TILE = 24
local tile = HS.Tile(panel, TILE)
local ACROSS = tile.across
local TEXT_X = ACROSS + 10             -- (the words' left: past the tile)
tile:ClearAllPoints()
tile:SetPoint("CENTER", panel, "TOPLEFT", ACROSS / 2, -ACROSS / 2)
tile.icon:SetSize(ACROSS * 0.72, ACROSS * 0.72)
local line = panel:CreateTexture(nil, "ARTWORK")
line:SetWidth(1)
line:SetPoint("TOPLEFT", panel, "TOPLEFT", ACROSS / 2, -(ACROSS + 4))
line:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ACROSS / 2, 0)
line:SetColorTexture(G[1], G[2], G[3], 1)
if not pcall(line.SetGradient, line, "VERTICAL", CreateColor(G[1], G[2], G[3], 0),
    CreateColor(G[1], G[2], G[3], 0.9)) then
    line:SetAlpha(0.6)
end
-- (Spoken's subtitle band, as the NPC dialog draws it (NpcDialog.lua): its texture is 64 high, its
-- top 28 rows a fade in, its last 8 a fade out; the fades kept this high however tall ours is;
-- reaching past the words each side)
local SPOKEN_BAND = "Interface\\AddOns\\Spoken\\Textures\\SubtitleBand"
local BAND_REACH, BAND_TOP_ROWS, BAND_BOTTOM_ROWS = 40, 28 / 64, 8 / 64
local BAND_TOP_FADE, BAND_BOTTOM_FADE = 40, 12
local band = CreateFrame("Frame", nil, panel)
band:SetPoint("TOPLEFT", -BAND_REACH, 10)
band:SetPoint("BOTTOMRIGHT", BAND_REACH, -4)
band:SetFrameLevel(math.max(0, panel:GetFrameLevel() - 1))
do
    local function Slice(top, bottom)
        local t = band:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(SPOKEN_BAND)
        t:SetTexCoord(0, 1, top, bottom)
        return t
    end
    local head = Slice(0, BAND_TOP_ROWS)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(BAND_TOP_FADE)
    local foot = Slice(1 - BAND_BOTTOM_ROWS, 1)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(BAND_BOTTOM_FADE)
    local middle = Slice(BAND_TOP_ROWS, 1 - BAND_BOTTOM_ROWS)
    middle:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    middle:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
end

-- (the portrait: the tooltip's unit's; for an object (a herb, a chest) the cursor the game draws
-- for it (SetUnitCursorTexture: its herb, its lock), as the interact tile does; else a plain mark)
local OBJECT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local function Yes(fn, unit)
    local ok, v = pcall(fn, unit)
    return ok and not Secret(v) and v and true or false
end
local function Portrait()
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if not (ok and type(unit) == "string" and not Secret(unit)) then unit = nil end
    local tokens = { unit, "mouseover", "softinteract" }
    for _, token in pairs(tokens) do
        if Yes(UnitIsGameObject, token) then
            local drawn, done = pcall(SetUnitCursorTexture, tile.icon, token, nil, nil, false)
            if drawn and done and not Secret(done) then return end
        end
    end
    if unit and Yes(UnitExists, unit) then
        SetPortraitTexture(tile.icon, unit)
        tile.icon:SetTexCoord(0, 1, 0, 1)
    else
        tile.icon:SetTexture(OBJECT_ICON)
        tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local rows = {}
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = {}
    r.left = panel:CreateFontString(nil, "OVERLAY")
    r.left:SetJustifyH("LEFT")
    r.left:SetWordWrap(false)
    r.left:SetShadowColor(0, 0, 0, 1)
    r.left:SetShadowOffset(1, -1)
    r.right = panel:CreateFontString(nil, "OVERLAY")
    r.right:SetJustifyH("RIGHT")
    r.right:SetWordWrap(false)
    r.right:SetShadowColor(0, 0, 0, 1)
    r.right:SetShadowOffset(1, -1)
    for _, fs in ipairs({ r.left, r.right }) do
        local ok = i == 1 and fs:SetFont(HS.FONT, 22, "")
        if not ok then fs:SetFont(STANDARD_TEXT_FONT, i == 1 and 20 or 13, "") end
    end
    rows[i] = r
    return r
end

-- (a line of the game's tooltip: its text and colour, nil when empty or a secret)
local function Read(fs)
    if not fs then return nil end
    local ok, text, r, g, b = pcall(function()
        local t = fs:GetText()
        local cr, cg, cb = fs:GetTextColor()
        return t, cr, cg, cb
    end)
    if not ok or Secret(text) or type(text) ~= "string" or text == "" then return nil end
    if Secret(r) or Secret(g) or Secret(b) or type(r) ~= "number" then r, g, b = 1, 1, 1 end
    return text, r, g, b
end

local function Lines()
    local n = GameTooltip:NumLines()
    if Secret(n) or type(n) ~= "number" then return nil end
    local out = {}
    for i = 1, n do
        local lt, lr, lg, lb = Read(_G["GameTooltipTextLeft" .. i])
        local rt, rr, rg, rb = Read(_G["GameTooltipTextRight" .. i])
        if lt or rt then
            out[#out + 1] = { lt = lt, lr = lr, lg = lg, lb = lb, rt = rt, rr = rr, rg = rg, rb = rb }
        end
    end
    return #out > 0 and out or nil
end

local function Signature(lines)
    local parts = {}
    for i, l in ipairs(lines) do
        parts[i] = (l.lt or "") .. "|" .. (l.rt or "") .. "|" .. string.format("%.2f%.2f%.2f", l.lr or 0, l.lg or 0, l.lb or 0)
    end
    return table.concat(parts, "\n")
end

local function Layout(lines)
    local y, width = -(ACROSS / 2 - 10), 0
    -- (the rule's own gap, then the name)
    for i, l in ipairs(lines) do
        local r = Row(i)
        r.left:ClearAllPoints()
        r.right:ClearAllPoints()
        r.left:SetPoint("TOPLEFT", panel, "TOPLEFT", TEXT_X, y)
        r.y = y
        r.left:SetText(l.lt or "")
        r.left:SetTextColor(l.lr or 1, l.lg or 1, l.lb or 1)
        r.right:SetText(l.rt or "")
        r.right:SetTextColor(l.rr or 1, l.rg or 1, l.rb or 1)
        local lw, rw = r.left:GetStringWidth(), r.right:GetStringWidth()
        width = math.max(width, lw + (l.rt and rw + 16 or 0))
        r.left:Show()
        r.right:SetShown(l.rt ~= nil)
        r.h = r.left:GetStringHeight()
        y = y - r.h - (i == 1 and 5 or 3)
    end
    for i = #lines + 1, #rows do
        rows[i].left:Hide()
        rows[i].right:Hide()
    end
    width = math.min(MAX_W, width)
    panel:SetSize(TEXT_X + width, math.max(-y + PAD_Y, ACROSS + 24))
    for i, l in ipairs(lines) do
        local r = rows[i]
        r.right:SetPoint("TOPRIGHT", panel, "TOPLEFT", TEXT_X + width, r.y)
    end
end

-- (the game's tooltip is the default world one: shown, on the screen's frame)
local function WorldTip()
    if not (IF.db and IN.Settings().tooltipOurs ~= false) then return false end
    if not GameTooltip:IsShown() then return false end
    local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
    return ok and owner == UIParent
end

local shown, signature = 0, nil     -- (0 to 1: how far in)
local gameFaded = false

local function Native(on)
    if on == gameFaded then return end
    gameFaded = on
    IF.Focus.Fade(GameTooltip, on)
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    local want = WorldTip()
    local lines = want and Lines() or nil
    if lines then
        local sig = Signature(lines)
        if sig ~= signature then
            signature = sig
            Layout(lines)
            Portrait()
        end
        Native(true)
    else
        Native(false)
    end
    local step = elapsed / FADE
    shown = lines and math.min(1, shown + step) or math.max(0, shown - step)
    if shown <= 0 then
        signature = nil
        if panel:IsShown() then panel:Hide() end
        return
    end
    local e = 1 - (1 - shown) * (1 - shown)
    panel:SetAlpha(e)
    panel:ClearAllPoints()
    panel:SetPoint("LEFT", UIParent, "CENTER", OFFSET_X - SLIDE * (1 - e), OFFSET_Y)
    if not panel:IsShown() then panel:Show() end
end)
