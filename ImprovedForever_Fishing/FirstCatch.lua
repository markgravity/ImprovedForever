-- Something caught for the first time ever (Collection.lua: firstEver): a
-- moment of its own on the right of the screen, once the fishing bar is
-- done with the catch (CastBar.lua: F.BarBusy). Rays of its quality's
-- colour turning behind it, a glow; its icon round in a ring of that
-- colour popping in; sparks flying out; FIRST CATCH over it, its name under
-- it, how far the collection's got and where and when it was caught. Held,
-- then it rises a little and fades. Several in one catch, or more catches
-- before it's done: one after another. Our own frames only.
local IF = ImprovedForever
local F = IF.Fishing

local ICON, RAYS, SPARKS = 72, 3, 12
local HOLD, OUT = 4.2, 0.7
local RING = "gamepad-actionbar-circleslot-frame"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAR = "Interface\\Cooldown\\star4"
local GOLD, GREY = { 1, 0.82, 0 }, { 0.75, 0.75, 0.75 }

local function Clamp(x) return math.max(0, math.min(1, x)) end
local function Ease(x) x = Clamp(x) return 1 - (1 - x) ^ 3 end
-- (past its size and back: a pop)
local function Pop(x)
    x = Clamp(x)
    local c = 1.70158 * 1.6
    return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

local stage = CreateFrame("Frame", "ImprovedForeverFishingFirst", UIParent)
stage:SetSize(420, 260)
stage:SetFrameStrata("HIGH")
stage:EnableMouse(false)
stage:Hide()

local function Shadowed(fs, color)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- (the icon's spot: everything turns and grows about it)
local spot = CreateFrame("Frame", nil, stage)
spot:SetSize(1, 1)
spot:SetPoint("CENTER", stage, "CENTER", 0, 40)

-- (a soft shade behind it: the game's level-up shadow in two halves, the
-- upper one upside down, fading out at its top as at its bottom)
local shades = {}
for _, upper in ipairs({ true, false }) do
    local t = stage:CreateTexture(nil, "BACKGROUND")
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("LevelUp-Shadow-Lower")
    if upper and info and info.file then
        t:SetTexture(info.file)
        t:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.bottomTexCoord, info.topTexCoord)
    else
        t:SetAtlas("LevelUp-Shadow-Lower")
    end
    t:SetPoint(upper and "TOPLEFT" or "BOTTOMLEFT", stage, upper and "TOPLEFT" or "BOTTOMLEFT", -60, upper and 30 or -30)
    t:SetPoint(upper and "BOTTOMRIGHT" or "TOPRIGHT", stage, "RIGHT", 60, 0)
    shades[#shades + 1] = t
end
local glow = stage:CreateTexture(nil, "BORDER")
glow:SetAtlas("LevelUp-Glow-Gold")
glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", spot)
local rays = {}
for i = 1, RAYS do
    local r = stage:CreateTexture(nil, "ARTWORK", nil, i)
    r:SetTexture(STAR)
    r:SetBlendMode("ADD")
    r:SetPoint("CENTER", spot)
    rays[i] = r
end

local hero = CreateFrame("Frame", nil, stage)
hero:SetSize(ICON, ICON)
hero:SetPoint("CENTER", spot)
hero.icon = hero:CreateTexture(nil, "ARTWORK")
hero.icon:SetAllPoints()
hero.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local mask = hero:CreateMaskTexture()
mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(hero.icon)
hero.icon:AddMaskTexture(mask)
hero.ring = hero:CreateTexture(nil, "OVERLAY")
hero.ring:SetPoint("TOPLEFT", -ICON * 0.14, ICON * 0.14)
hero.ring:SetPoint("BOTTOMRIGHT", ICON * 0.14, -ICON * 0.14)
hero.ring:SetAtlas(RING)
hero.flash = hero:CreateTexture(nil, "OVERLAY", nil, 2)
hero.flash:SetAllPoints(hero.icon)
hero.flash:SetColorTexture(1, 1, 1, 1)
hero.flash:SetBlendMode("ADD")
hero.flash:AddMaskTexture(mask)

local sparks = {}
for i = 1, SPARKS do
    local s = stage:CreateTexture(nil, "OVERLAY")
    s:SetTexture(STAR)
    s:SetBlendMode("ADD")
    s.angle = (i - 1) / SPARKS * 2 * math.pi + (i % 3) * 0.3
    s.reach = 70 + (i * 37) % 60
    s.delay = (i % 4) * 0.06
    sparks[i] = s
end

local label = Shadowed(stage:CreateFontString(nil, "OVERLAY", "GameFontNormal"), GOLD)
label:SetPoint("BOTTOM", spot, "CENTER", 0, ICON / 2 + 18)
local title = Shadowed(stage:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"))
title:SetPoint("TOP", spot, "CENTER", 0, -ICON / 2 - 16)
title:SetWidth(400)
title:SetWordWrap(false)
local line1 = Shadowed(stage:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
line1:SetPoint("TOP", title, "BOTTOM", 0, -6)
local line2 = Shadowed(stage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)
line2:SetPoint("TOP", line1, "BOTTOM", 0, -4)

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

---------------------------------------------------------------------------
-- The show, and those waiting their turn
---------------------------------------------------------------------------
local queue, show = {}, nil

-- (on the right, clear of the stringer down the screen's edge, Panel.lua)
local function Place()
    local x = UIParent:GetWidth() * 0.7
    local rack = rawget(_G, "ImprovedForeverFishingLoot")
    local left = rack and rack:IsShown() and rack:GetLeft()
    if left then
        x = math.min(x, left * rack:GetEffectiveScale() / UIParent:GetEffectiveScale() - stage:GetWidth() / 2 - 70)
    end
    stage:ClearAllPoints()
    stage:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, UIParent:GetHeight() * 0.58)
end

local function Start(item)
    local c = QualityColor(item.quality)
    show = { at = GetTime(), color = c }
    hero.icon:SetTexture(item.icon or 134400)
    hero.ring:SetVertexColor(c[1], c[2], c[3])
    glow:SetVertexColor(c[1], c[2], c[3])
    for _, r in ipairs(rays) do r:SetVertexColor(c[1], c[2], c[3]) end
    for _, s in ipairs(sparks) do s:SetVertexColor(c[1], c[2], c[3]) end
    label:SetText("FIRST CATCH")
    title:SetText(item.name or "")
    title:SetTextColor(c[1], c[2], c[3])
    line1:SetText(item.progress or "Added to your fishing book")
    line2:SetText(item.where or "")
    Place()
    stage:SetAlpha(1)
    stage:Show()
end

stage:SetScript("OnUpdate", function(self)
    if not show then
        -- (waiting its turn: shown, unseen, so it's still asked; nothing
        -- waiting, gone)
        if #queue > 0 and not (F.BarBusy and F.BarBusy()) then Start(table.remove(queue, 1)) end
        if not show then
            self:SetAlpha(0)
            if #queue == 0 then self:Hide() end
        end
        return
    end
    local t = GetTime() - show.at
    local out = Clamp((t - HOLD) / OUT)
    self:SetAlpha(1 - out)
    spot:SetPoint("CENTER", stage, "CENTER", 0, 40 + 16 * Ease(out))
    -- (the shade and glow in; the rays turning, slowly, each its own way)
    for _, s in ipairs(shades) do s:SetAlpha(0.8 * Ease(t / 0.4)) end
    local g = Ease(t / 0.5)
    glow:SetSize(ICON * 3.2 * g, ICON * 1.8 * g)
    glow:SetAlpha(0.55 + 0.15 * math.sin(t * 3))
    for i, r in ipairs(rays) do
        local size = ICON * (2.4 + 0.5 * i) * Ease((t - 0.1) / 0.6)
        r:SetSize(math.max(1, size), math.max(1, size))
        r:SetRotation((i % 2 == 0 and -1 or 1) * t * (0.25 + 0.1 * i) + i)
        r:SetAlpha(0.35 / i + 0.1)
    end
    -- (the icon popping in, a white flash going off it)
    local p = Pop((t - 0.15) / 0.5)
    hero:SetScale(math.max(0.01, p))
    hero:SetAlpha(Clamp((t - 0.15) / 0.15))
    hero.flash:SetAlpha(0.8 * Clamp(1 - (t - 0.3) / 0.4))
    -- (sparks flying out as it lands, fading)
    for _, s in ipairs(sparks) do
        local q = Clamp((t - 0.35 - s.delay) / 0.9)
        local d = s.reach * Ease(q)
        s:ClearAllPoints()
        s:SetPoint("CENTER", spot, "CENTER", math.cos(s.angle) * d, math.sin(s.angle) * d)
        local size = 18 * (1 - q) + 4
        s:SetSize(size, size)
        s:SetAlpha(q > 0 and (1 - q) or 0)
    end
    -- (the words after it)
    label:SetAlpha(Clamp((t - 0.45) / 0.3))
    title:SetAlpha(Clamp((t - 0.55) / 0.3))
    line1:SetAlpha(Clamp((t - 0.75) / 0.3))
    line2:SetAlpha(Clamp((t - 0.9) / 0.3))
    if out >= 1 then show = nil end
end)

---------------------------------------------------------------------------
-- The catches
---------------------------------------------------------------------------
local function On()
    return IF.db and F.Settings().firstCatch and not F.EditMode() or false
end

-- (how far the collection's got: its fish)
local function Progress()
    local D = IF.FishingData
    local col = F.Collection and F.Collection() or {}
    if not D then return nil end
    local total, n = 0, 0
    for id, row in pairs(D.items or {}) do
        if row:match("|fish$") then
            total = total + 1
            if col[id] then n = n + 1 end
        end
    end
    return total > 0 and ("Added to your fishing book  ·  %d of %d fish"):format(n, total) or nil
end

function F.FirstCatch(item)
    queue[#queue + 1] = item
    stage:Show()
end

F.OnCatch(function(catch)
    if not On() then return end
    local zone = GetZoneText and GetZoneText() or ""
    local D = IF.FishingData
    for _, item in ipairs(catch.items or {}) do
        -- (fish only: a first boot or potion isn't a moment)
        local row = D and D.items and D.items[item.id]
        if item.firstEver and row and row:match("|fish$") then
            F.FirstCatch({ name = item.name, icon = item.icon, quality = item.quality, progress = Progress(),
                where = (zone ~= "" and (zone .. "  ·  ") or "") .. date("%d %b %Y, %H:%M") })
        end
    end
end)

function F.ApplyFirst()
    if not On() then
        wipe(queue)
        show = nil
        stage:Hide()
    end
end
