-- The fishing session's highlights (Session.lua): while a pole is in hand,
-- over the gamepad bar on the right (the Interface module's), else as high, "Fishing", its casts, catches, misses and
-- time, then what it caught, the rarest first (then the most), each its
-- icon, its name in its quality's colour and how many; the latest catch's
-- row lit a moment. Faded in and out.
local IF = ImprovedForever
local F = IF.Fishing

local WIDTH, ROW_H, ICON = 280, 22, 18
local MAX_ROWS = 6
local MARGIN_X, OVER_BAR = 24, 16       -- (from the right edge; over the gamepad bar)
local FADE, FLASH = 0.3, 2
local GOLD, GREY = { 1, 0.82, 0 }, { 0.62, 0.62, 0.62 }

local panel = CreateFrame("Frame", "ImprovedForeverFishingLoot", UIParent)
panel:SetFrameStrata("LOW")
panel:SetWidth(WIDTH)
panel:SetAlpha(0)
panel:Hide()

-- (a soft dark band, from the right edge fading out to the left)
local band = panel:CreateTexture(nil, "BACKGROUND")
band:SetPoint("TOPLEFT", -16, 8)
band:SetPoint("BOTTOMRIGHT", MARGIN_X, -8)
band:SetTexture("Interface\\Buttons\\WHITE8x8")
band:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.6))

local function Shadowed(fs, color)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local title = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"), GOLD)
title:SetPoint("TOPLEFT")
title:SetText(PROFESSIONS_FISHING or "Fishing")
local stats = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)
stats:SetPoint("LEFT", title, "RIGHT", 8, 0)
local more = Shadowed(panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), GREY)

local rows = {}
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(ROW_H + 2) - (i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = Shadowed(r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    r.count:SetPoint("RIGHT")
    r.name = Shadowed(r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    -- (the latest catch: a light bar, fading)
    r.flash = r:CreateTexture(nil, "BACKGROUND")
    r.flash:SetPoint("TOPLEFT", -6, 1)
    r.flash:SetPoint("BOTTOMRIGHT", 6, -1)
    r.flash:SetColorTexture(1, 1, 1, 1)
    r.flash:SetAlpha(0)
    rows[i] = r
    return r
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Minutes(seconds)
    local m = math.floor(math.max(0, seconds) / 60)
    if m < 60 then return m .. " min" end
    return ("%dh %02dm"):format(math.floor(m / 60), m % 60)
end

local function Session()
    return F.Session and F.Session() or nil
end

-- (the session's numbers and its catches, the rarest first, then the most)
local newestRow
local function Draw()
    local s = Session()
    if not s then return end
    local ended = s.active and time() or (s.last or time())
    local away = (s.escapes or 0) > 0 and ("  •  %d got away"):format(s.escapes) or ""
    stats:SetText(("%d casts  •  %d caught%s  •  %s"):format(s.casts or 0, s.catches or 0, away,
        Minutes(ended - (s.start or ended))))
    local list = {}
    for _, item in pairs(s.items or {}) do list[#list + 1] = item end
    table.sort(list, function(a, b)
        if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
        if a.count ~= b.count then return a.count > b.count end
        return (a.last or 0) > (b.last or 0)
    end)
    newestRow = nil
    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local r, item = Row(i), list[i]
        r.icon:SetTexture(item.icon or 134400)
        r.name:SetText(item.name or "")
        r.name:SetTextColor(QualityColor(item.quality))
        r.count:SetText("x" .. item.count)
        r:Show()
        if item.id == s.newest then newestRow = r end
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    more:ClearAllPoints()
    more:SetPoint("TOPLEFT", 0, -(ROW_H + 2) - shown * ROW_H - 2)
    more:SetText(#list > MAX_ROWS and ("+%d more"):format(#list - MAX_ROWS) or (#list == 0 and "Nothing caught yet" or ""))
    local h = ROW_H + 2 + shown * ROW_H + (more:GetText() ~= "" and 16 or 0)
    panel:SetHeight(h)
end

-- (over the gamepad bar, by its top; else as high as it would be)
local function Place()
    local GB = IF.Interface and IF.Interface.GamepadBar
    local top = GB and GB.Rect and select(4, GB.Rect())
    local y = top and (top / UIParent:GetEffectiveScale() + OVER_BAR) or 230
    if y ~= panel.y then
        panel.y = y
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MARGIN_X, y)
    end
end

local function Wanted()
    local s = Session()
    return F.panelOn and s and s.active and not F.EditMode() or false
end

panel:SetScript("OnUpdate", function(self, elapsed)
    local goal = Wanted() and 1 or 0
    local a = self:GetAlpha()
    if a ~= goal then
        a = goal > a and math.min(goal, a + elapsed / FADE) or math.max(goal, a - elapsed / FADE)
        self:SetAlpha(a)
    end
    if a <= 0 and goal == 0 then self:Hide() return end
    -- (the latest catch lit, fading over FLASH)
    local s = Session()
    for _, r in ipairs(rows) do
        local lit = r == newestRow and s and s.newestAt and GetTime() - s.newestAt or nil
        r.flash:SetAlpha(lit and lit < FLASH and 0.18 * (1 - lit / FLASH) or 0)
    end
end)

local function Update()
    if not Wanted() then return end
    Draw()
    Place()
    panel:Show()
end

---------------------------------------------------------------------------
-- On while the setting is
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    F.panelOn = F.Settings().panel and true or false
    -- (its time and place kept up)
    Update()
end

F.Watcher("fishing panel", 1, Watch)
F.OnChange(function() Update() end)

F.ApplyPanel = Watch
