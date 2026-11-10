-- The game's world tooltip (the unit or object under the mouse or the soft target, anchored
-- bottom right over the action bar) drawn again as ours: to the right of your character in the
-- 3D world, between it and the quest tracker, fading in, in the HUD's look (a dark band
-- fading out at its sides as the NPC dialog's, the name big, the rest small). The game's
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
local PAD_X, PAD_Y = 40, 8
local MAX_W = 360

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local panel = CreateFrame("Frame", "ImprovedForeverTooltip", UIParent)
panel:SetFrameStrata("TOOLTIP")
panel:EnableMouse(false)
panel:SetAlpha(0)
panel:Hide()

-- (the band as the NPC dialog's, Spoken's subtitle look: dark in the middle, fading out to its
-- sides, past the words each side)
local BAND_REACH, BAND_ALPHA = 40, 0.6
local band = CreateFrame("Frame", nil, panel)
band:SetPoint("TOPLEFT", -BAND_REACH, 8)
band:SetPoint("BOTTOMRIGHT", BAND_REACH, -8)
band:SetFrameLevel(math.max(0, panel:GetFrameLevel() - 1))
local function BandPart(points, gradient)
    local t = band:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 1)
    for _, p in ipairs(points) do t:SetPoint(unpack(p)) end
    if gradient and t.SetGradient and CreateColor then
        t:SetGradient(gradient[1], CreateColor(0, 0, 0, gradient[2]), CreateColor(0, 0, 0, gradient[3]))
    else
        t:SetVertexColor(0, 0, 0, BAND_ALPHA)
    end
end
do
    local fade = BAND_REACH * 2
    BandPart({ { "TOPLEFT", band, "TOPLEFT", fade, 0 }, { "BOTTOMRIGHT", band, "BOTTOMRIGHT", -fade, 0 } })
    BandPart({ { "TOPLEFT" }, { "BOTTOMRIGHT", band, "BOTTOMLEFT", fade, 0 } }, { "HORIZONTAL", 0, BAND_ALPHA })
    BandPart({ { "TOPRIGHT" }, { "BOTTOMLEFT", band, "BOTTOMRIGHT", -fade, 0 } }, { "HORIZONTAL", BAND_ALPHA, 0 })
end

local rows = {}
local function Row(i)
    local r = rows[i]
    if r then return r end
    local font = i == 1 and "GameFontNormalLarge" or "GameFontHighlight"
    r = {}
    r.left = panel:CreateFontString(nil, "OVERLAY", font)
    r.left:SetJustifyH("LEFT")
    r.left:SetWordWrap(false)
    r.left:SetShadowColor(0, 0, 0, 1)
    r.left:SetShadowOffset(1, -1)
    r.right = panel:CreateFontString(nil, "OVERLAY", font)
    r.right:SetJustifyH("RIGHT")
    r.right:SetWordWrap(false)
    r.right:SetShadowColor(0, 0, 0, 1)
    r.right:SetShadowOffset(1, -1)
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
    local y, width = -PAD_Y, 0
    for i, l in ipairs(lines) do
        local r = Row(i)
        r.left:ClearAllPoints()
        r.right:ClearAllPoints()
        r.left:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, y)
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
        y = y - r.h - (i == 1 and 4 or 2)
    end
    for i = #lines + 1, #rows do
        rows[i].left:Hide()
        rows[i].right:Hide()
    end
    width = math.min(MAX_W, width)
    panel:SetSize(width + PAD_X * 2, -y + PAD_Y)
    for i, l in ipairs(lines) do
        local r = rows[i]
        r.right:SetPoint("TOPRIGHT", panel, "TOPLEFT", PAD_X + width, r.y)
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
