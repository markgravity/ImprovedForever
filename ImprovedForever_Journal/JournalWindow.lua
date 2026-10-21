-- The Journal's window, laid out as Spoken's Azeroth's Compendium: the
-- game's portrait frame, a tree down the left (the companions met, then
-- the years, their months as cards, a line a day) and a parchment page on
-- the right that scrolls: the day's title, what I wrote of it
-- (JournalWriter.lua), notes pasted in among the words as a scrapbook's
-- (the map torn out round where I woke or fell, the foe as it stood with a
-- tally of them, a level, a find, who was with me), the words going round
-- them; a companion's page, the days we met.
-- The pad: the D-pad down the tree (left / right fold a year or a month),
-- Cross on a companion steps into their page (the D-pad over the days we
-- met, Cross reads one, Circle back to the tree), L1 / R1 scroll the page, L2 / R2 to
-- the game's window (Focus.lua). The mouse: click, the wheel, Esc.
-- Opened with /if journal, its key binding, or a wheel / the touchpad
-- (ImprovedForeverJournalToggle). Never in combat.
local IF = ImprovedForever

local J = IF.Journal
local BK = IF.Book
local JB = IF.JournalBook
local K = IF.ConfigKit

local Plural, Join = BK.Plural, BK.Join
local INK = BK.INK

---------------------------------------------------------------------------
-- The looks
---------------------------------------------------------------------------
local WIN_W, WIN_H = 940, 620
local LIST_W = 300
local SIDE = 6                           -- the insets from the frame's edge, and between them
local LIST_TOP = 60                      -- the list's inset under the title (the summary line above it)
local PAGE_W = WIN_W - LIST_W - 3 * SIDE
local PAD_L, PAD_R, PAD_TOP = 28, 40, 30 -- the writing on the page
local TEXT_W = PAGE_W - 6 - PAD_L - PAD_R
local SCROLL_STEP = 60
local HEADING_FONT = "Fonts\\MORPHEUS.TTF"
local BODY_FONT = "Fonts\\FRIZQT__.TTF"
-- The hand it's written in: Kalam (SIL Open Font License, Fonts/OFL.txt)
local HAND_FONT = "Interface\\AddOns\\ImprovedForever_Journal\\Fonts\\Kalam-Regular.ttf"
local HAND_BOLD = "Interface\\AddOns\\ImprovedForever_Journal\\Fonts\\Kalam-Bold.ttf"
local HAND_INK = { 0.16, 0.1, 0.06 }
local RUBRIC = { 0.6, 0.12, 0.07 }       -- the red a note's title and a fall are written in
local SEAL_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"   -- (a round: stamps, drops of blood)
local ACCENT_RGB = { 0.43, 0.16, 0.05 }
local NAME_INK = { 1, 0.82, 0 }
local DIM_INK = { 0.84, 0.71, 0.31 }
local RAIL_INK = { 0.84, 0.71, 0.31, 0.25 }

-- The tree's rows
local BANNER_H, BANNER_GAP, CARD_H, LEAF_H, TOP_H = 34, 10, 46, 22, 28
local NEST = 16                          -- what an open row holds, this far in
local RAIL_X = 12

local ICON = JB.ICON
local SUMMARY_ICON = ICON .. "INV_Misc_Book_11"
local MONTH_ICON = ICON .. "INV_Misc_Note_02"
local CHECK = "questlog-icon-checkmark-yellow"
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local function Sound(kit) BK.Sound(kit) end

-- Part of an atlas (its own pixels x1..x2, y1..y2), mirrored or not;
-- false where the client hasn't it
local function AtlasCut(tex, atlas, x1, x2, y1, y2, mirror)
    local info = C_Texture and C_Texture.GetAtlasInfo and IF.HasAtlas(atlas) and C_Texture.GetAtlasInfo(atlas)
    if not info or not info.file and not info.filename then return false end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local w, h = info.width, info.height
    local u1, u2 = l + (r - l) * x1 / w, l + (r - l) * x2 / w
    local v1, v2 = t + (b - t) * y1 / h, t + (b - t) * y2 / h
    tex:SetTexture(info.file or info.filename)
    if mirror then tex:SetTexCoord(u2, u1, v1, v2) else tex:SetTexCoord(u1, u2, v1, v2) end
    return true, w, h
end

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local function Ink(fs, font, size, color, flags)
    pcall(fs.SetFont, fs, font, size, flags or "")
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetShadowOffset(0, 0)
    return fs
end

local function ItemName(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, _, quality = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, quality
end

local function ItemIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return icon or (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Faction()
    return UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
end

local EMPTY = { events = {}, sessions = {}, stats = { levelFrom = 1, levelTo = 1, xp = 0, kills = 0, deaths = 0,
    quests = 0, played = 0, money = { earned = 0, spent = 0 }, foes = {}, foeIDs = {}, zones = {} } }

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local W = { opened = {}, where = "tree", sel = 1, link = 1, focus = "ours" }
JB.window = W

local ok, window = pcall(K.NewFrame, "Frame", "ImprovedForeverJournal", UIParent, "PortraitFrameTemplate")
if not ok then window = K.NewFrame("Frame", "ImprovedForeverJournal", UIParent) end
window:SetSize(WIN_W, WIN_H)
window:SetFrameStrata("DIALOG")
window:SetPoint("CENTER")
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:Hide()
pcall(function()
    if window.SetTitle then window:SetTitle("Journal") end
    if window.SetPortraitToAsset then window:SetPortraitToAsset(SUMMARY_ICON) end
end)
W.frame = window

-- Who's writing: under the title bar, right of the portrait
local who = Ink(window:CreateFontString(nil, "ARTWORK"), HEADING_FONT, 15, NAME_INK)
who:SetPoint("TOPLEFT", window, "TOPLEFT", 66, -32)
who:SetPoint("RIGHT", window, "LEFT", LIST_W, 0)
who:SetJustifyH("LEFT")
who:SetWordWrap(false)

local function Inset(parent)
    local okInset, f = pcall(K.NewFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if not okInset or not f then f = K.NewFrame("Frame", nil, parent) end
    return f
end

---------------------------------------------------------------------------
-- The tree
---------------------------------------------------------------------------
local listInset = Inset(window)
listInset:SetPoint("TOPLEFT", window, "TOPLEFT", SIDE, -LIST_TOP)
listInset:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", SIDE, SIDE)
listInset:SetWidth(LIST_W)
if type(listInset.Bg) == "table" and listInset.Bg.SetTexture then
    listInset.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
end

local listScroll = K.NewFrame("ScrollFrame", nil, listInset)
listScroll:SetPoint("TOPLEFT", 4, -4)
listScroll:SetPoint("BOTTOMRIGHT", -4, 4)
local listChild = K.NewFrame("Frame", nil, listScroll)
listChild:SetSize(LIST_W - 8, 1)
listScroll:SetScrollChild(listChild)
listScroll:EnableMouseWheel(true)

local function ScrollBy(scroll, child, delta)
    local max = math.max(0, child:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(max, scroll:GetVerticalScroll() + delta)))
end

-- The thin bar of a scroll's place, down its right (the mouse can't drag
-- it: the wheel scrolls)
local function Thumb(parent, scroll, child, r, g, b, a)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(r, g, b, a)
    t:SetWidth(3)
    function t:Update()
        local view, total = scroll:GetHeight(), child:GetHeight()
        if total <= view + 1 or view <= 0 then return self:Hide() end
        local h = math.max(24, view * view / total)
        local y = (view - h) * scroll:GetVerticalScroll() / (total - view)
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 2, -y)
        self:SetHeight(h)
        self:Show()
    end
    scroll:HookScript("OnVerticalScroll", function() t:Update() end)
    return t
end
local listThumb = Thumb(listInset, listScroll, listChild, 0.84, 0.71, 0.31, 0.5)

-- The rows (made as they're needed)
local rows = {}

local function NineCard(row)
    local parts = {}
    for i = 1, 9 do
        parts[i] = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        if parts[i].SetDesaturated then parts[i]:SetDesaturated(true) end
        parts[i]:SetVertexColor(0.92, 0.94, 1)
    end
    return parts
end

-- The character select card's frame round a row (its corners cut, sides
-- stretched), silvered as Spoken's cards; false where the client hasn't it
local CARD_ART = { normal = "glues-characterselect-card-singles-c60", hover = "glues-characterselect-card-singles-hover-c60" }
local function SetCard(parts, atlas, row, left)
    local info = C_Texture and C_Texture.GetAtlasInfo and IF.HasAtlas(atlas) and C_Texture.GetAtlasInfo(atlas)
    if not info then return false end
    local cut, size = 16, 11
    local xs = { 0, cut, info.width - cut, info.width }
    local ys = { 0, cut, info.height - cut, info.height }
    for r = 1, 3 do
        for c = 1, 3 do
            local p = parts[(r - 1) * 3 + c]
            AtlasCut(p, atlas, xs[c], xs[c + 1], ys[r], ys[r + 1])
            p:ClearAllPoints()
        end
    end
    local tl, tr, bl, br = parts[1], parts[3], parts[7], parts[9]
    for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(size, size) end
    tl:SetPoint("TOPLEFT", row, "TOPLEFT", left, -2)
    tr:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2)
    bl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, 2)
    br:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
    parts[2]:SetPoint("TOPLEFT", tl, "TOPRIGHT"); parts[2]:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    parts[4]:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); parts[4]:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    parts[5]:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); parts[5]:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    parts[6]:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); parts[6]:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    parts[8]:SetPoint("TOPLEFT", bl, "TOPRIGHT"); parts[8]:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    return true
end

local function ShowAll(parts, on)
    for _, p in ipairs(parts) do p:SetShown(on and true or false) end
end

local function NewRow(i)
    local row = K.NewFrame("Button", nil, listChild)
    row:RegisterForClicks("LeftButtonUp")
    -- (a banner: the objective tracker's campaign bar, its ends alike)
    row.barL = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.barM = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.barR = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.card = NineCard(row)
    row.warm = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.warm:SetColorTexture(0.55, 0.38, 0.12, 0.35)
    row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.wash:SetColorTexture(1, 0.82, 0, 0.12)
    row.rail = row:CreateTexture(nil, "BORDER")
    row.rail:SetColorTexture(RAIL_INK[1], RAIL_INK[2], RAIL_INK[3], RAIL_INK[4])
    row.rail:SetWidth(1)
    row.rail2 = row:CreateTexture(nil, "BORDER")
    row.rail2:SetColorTexture(RAIL_INK[1], RAIL_INK[2], RAIL_INK[3], RAIL_INK[4])
    row.rail2:SetWidth(1)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.iconEdge = row:CreateTexture(nil, "ARTWORK", nil, -1)
    row.iconEdge:SetColorTexture(0, 0, 0, 0.8)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.count:SetJustifyH("RIGHT")
    row.sub = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.track = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.track:SetColorTexture(0, 0, 0, 0.6)
    row.track:SetHeight(4)
    row.fill = row:CreateTexture(nil, "ARTWORK", nil, 2)
    row.fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.fill:SetVertexColor(1, 0.6, 0.1)
    row.fill:SetHeight(4)
    row.ring = IF.UI.FocusStroke(row)
    row:SetScript("OnClick", function(self) W.Click(self.index) end)
    row:SetScript("OnEnter", function(self)
        self.over = true
        W.LightRow(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.over = false
        W.LightRow(self)
    end)
    rows[i] = row
    return row
end

-- What the tree holds, as it's folded: { kind ("top", "banner", "card",
-- "person", "day"), key, label, nest, ... }
local function Tree()
    local items, keys = {}, J.Days()
    local today = J.TodayKey()
    items[1] = { kind = "top", key = "summary", label = "The Journal So Far", icon = SUMMARY_ICON }
    local people = JB.Companions()
    if #people > 0 then
        local open = W.opened.people
        items[#items + 1] = { kind = "banner", key = "people", label = "Companions", count = #people, open = open }
        if open then
            for _, c in ipairs(people) do
                local p = c.p
                items[#items + 1] = { kind = "person", key = "p:" .. c.name, person = c.name, label = c.name,
                    icon = JB.Avatar(p), nest = 1,
                    sub = Join({ Join({ p.race, p.class }, " "), p.dayCount and Plural(p.dayCount, "day", "days") }) }
            end
        end
    end
    -- (the years, the newest first; a year's months; a month's days)
    local years, months = {}, {}
    for _, key in ipairs(keys) do
        local y, m = key:match("^(%d+)-(%d+)")
        if not months[y] then
            months[y] = {}
            years[#years + 1] = y
        end
        local list = months[y]
        local last = list[#list]
        if not last or last.m ~= m then
            last = { m = m, days = {} }
            list[#list + 1] = last
        end
        last.days[#last.days + 1] = key
    end
    for _, y in ipairs(years) do
        local count = 0
        for _, mo in ipairs(months[y]) do count = count + #mo.days end
        local yopen = W.opened["y" .. y]
        items[#items + 1] = { kind = "banner", key = "y" .. y, label = y, count = count, open = yopen }
        if yopen then
            for _, mo in ipairs(months[y]) do
                local mkey = "m" .. y .. "-" .. mo.m
                local t = J.KeyTime(mo.days[1])
                -- (days in the month: its share written)
                local total = tonumber(date("%d", time({ year = tonumber(y), month = tonumber(mo.m) + 1, day = 0, hour = 12 })))
                local mopen = W.opened[mkey]
                items[#items + 1] = { kind = "card", key = mkey, label = t and date("%B", t) or mo.m, icon = MONTH_ICON,
                    count = #mo.days, total = total, open = mopen, nest = 1 }
                if mopen then
                    for _, key in ipairs(mo.days) do
                        local day = J.Day(key) or EMPTY
                        local s = day.stats
                        local dt = J.KeyTime(key)
                        items[#items + 1] = { kind = "day", key = key, nest = 2,
                            label = (dt and (date("%a ", dt) .. tonumber(date("%d", dt))) or key)
                                .. (key == today and "  · today" or ""),
                            sub = J.Zones(day)[1],
                            grew = (s.levelTo or 1) > (s.levelFrom or 1) and ("Lv " .. s.levelTo) or nil,
                            fell = (s.deaths or 0) > 0 }
                    end
                end
            end
        end
    end
    -- (the last of a nest: its rail ends there)
    for i, it in ipairs(items) do
        local nxt = items[i + 1]
        it.lastIn = not nxt or (nxt.nest or 0) < (it.nest or 0)
        it.lastOut = not nxt or (nxt.nest or 0) == 0
    end
    return items
end

-- A row's light: the pad's stroke where it is (dimmed: picked, the pad on
-- the page); the mouse's hover; the card's warm fill when picked
function W.LightRow(row)
    local it = row.item
    if not it then return end
    local picked = row.index == W.sel
    local pad = IF.Input.Pad()
    local ours = W.focus == "ours"
    row.ring:Light(picked and pad and ours, W.where == "page")
    local over = row.over and not pad
    local cardy = it.kind == "card" or it.kind == "person"
    if cardy and row.cardArt then
        ShowAll(row.card, true)
        SetCard(row.card, over and CARD_ART.hover or CARD_ART.normal, row, row.indent)
    end
    row.warm:SetShown(picked and (it.kind ~= "banner") and not (pad and ours and W.where == "tree"))
    row.wash:SetShown(over and it.kind ~= "banner" and not cardy)
    if it.kind == "banner" then
        local a = (over or (picked and pad and ours)) and 1 or 0.85
        row.barL:SetAlpha(a); row.barM:SetAlpha(a); row.barR:SetAlpha(a)
    end
end

local function DrawBanner(row, it)
    local atlas = "Objective-Header-Campaign" .. Faction()
    local info = C_Texture and C_Texture.GetAtlasInfo and IF.HasAtlas(atlas) and C_Texture.GetAtlasInfo(atlas)
    local w = info and info.width or 0
    local okBar = w > 250
    if okBar then
        -- (its right end, turned round for the left: the crest at the left
        -- end looked cut off)
        AtlasCut(row.barR, "Objective-Header-Campaign" .. Faction(), 250, w, 3, 40)
        AtlasCut(row.barL, "Objective-Header-Campaign" .. Faction(), 250, w, 3, 40, true)
        AtlasCut(row.barM, "Objective-Header-Campaign" .. Faction(), 64, 250, 3, 40)
        local cap = math.floor((w - 250) * BANNER_H / 37 + 0.5)
        row.barL:ClearAllPoints(); row.barL:SetPoint("TOPLEFT"); row.barL:SetSize(cap, BANNER_H)
        row.barR:ClearAllPoints(); row.barR:SetPoint("TOPRIGHT"); row.barR:SetSize(cap, BANNER_H)
        row.barM:ClearAllPoints()
        row.barM:SetPoint("TOPLEFT", row.barL, "TOPRIGHT")
        row.barM:SetPoint("BOTTOMRIGHT", row.barR, "BOTTOMLEFT")
    else
        row.barM:ClearAllPoints()
        row.barM:SetAllPoints()
        row.barM:SetTexture(nil)
        row.barM:SetColorTexture(0.25, 0.18, 0.08, 0.9)
        row.barL:Hide(); row.barR:Hide()
    end
    row.barM:Show()
    if okBar then row.barL:Show(); row.barR:Show() end
    row.toggle:SetTexture(it.open and MINUS or PLUS)
    row.toggle:ClearAllPoints()
    row.toggle:SetPoint("LEFT", row, "LEFT", 10, -1)
    row.toggle:Show()
    row.label:SetFontObject("GameFontNormal")
    row.label:SetTextColor(0.85, 0.81, 0.73)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 32, -1)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
    row.label:SetText(it.label)
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", row, "RIGHT", -14, -1)
    row.count:SetText(it.key == "people" and Plural(it.count, "person", "people") or Plural(it.count, "day", "days"))
    row.count:Show()
end

local function DrawIcon(row, icon, x, size)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", x, 0)
    row.icon:SetSize(size, size)
    if type(icon) == "string" and icon:find("^atlas:") then
        row.icon:SetAtlas(icon:sub(7))
        row.icon:SetTexCoord(0, 1, 0, 1)
    else
        row.icon:SetTexture(icon)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    row.icon:Show()
    row.iconEdge:ClearAllPoints()
    row.iconEdge:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
    row.iconEdge:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
    row.iconEdge:Show()
end

local function DrawCard(row, it, indent)
    row.cardArt = SetCard(row.card, CARD_ART.normal, row, indent)
    if not row.cardArt then
        row.wash:ClearAllPoints()
        row.wash:SetPoint("TOPLEFT", indent, 0)
        row.wash:SetPoint("BOTTOMRIGHT")
    end
    ShowAll(row.card, row.cardArt)
    DrawIcon(row, it.icon, indent + 10, 28)
    if it.kind == "card" then
        row.toggle:SetTexture(it.open and MINUS or PLUS)
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("CENTER", row.icon, "BOTTOMRIGHT", -2, 2)
        row.toggle:SetSize(12, 12)
        row.toggle:Show()
    end
    row.label:SetFontObject("GameFontNormal")
    local c = it.kind == "person" and NAME_INK or (it.count > 0 and NAME_INK or DIM_INK)
    row.label:SetTextColor(c[1], c[2], c[3])
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", indent + 48, -9)
    row.label:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    BK.Script(row.label, it.label, "GameFontNormal", "GameFontNormal")
    row.label:SetTextColor(c[1], c[2], c[3])
    row.count:ClearAllPoints()
    row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -10)
    if it.kind == "card" then
        local share = it.total > 0 and it.count / it.total or 0
        row.count:SetText(it.count .. "/" .. it.total .. " \226\128\162 " .. math.floor(share * 100 + 0.5) .. "%")
        row.count:Show()
        row.track:ClearAllPoints()
        row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", indent + 48, 11)
        row.track:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 11)
        row.track:Show()
        local width = (LIST_W - 8 - 5) - indent - 48 - 12
        row.fill:ClearAllPoints()
        row.fill:SetPoint("LEFT", row.track, "LEFT")
        row.fill:SetWidth(math.max(2, width * share))
        row.fill:Show()
    else
        row.sub:ClearAllPoints()
        row.sub:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.sub:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.sub:SetText(it.sub or "")
        row.sub:Show()
    end
end

local function DrawDay(row, it, indent)
    row.label:SetFontObject("GameFontHighlight")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", indent + 12, 0)
    row.label:SetWidth(84)
    row.label:SetText(it.label)
    row.sub:ClearAllPoints()
    row.sub:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
    row.sub:SetPoint("RIGHT", row, "RIGHT", -52, 0)
    row.sub:SetText(it.sub or "")
    row.sub:Show()
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.count:SetText(it.grew and ("|cffffd100" .. it.grew .. "|r") or (it.fell and "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12|t") or "")
    row.count:Show()
end

local function DrawTop(row, it)
    DrawIcon(row, it.icon, 8, 20)
    row.label:SetFontObject("GameFontNormal")
    row.label:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3])
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 36, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.label:SetText(it.label)
end

local function Hide(...)
    for i = 1, select("#", ...) do select(i, ...):Hide() end
end

-- The rail down an open row's contents, at each nest it's in
local function Rails(row, it)
    row.rail:Hide()
    row.rail2:Hide()
    local nest = it.nest or 0
    if nest >= 1 then
        row.rail:ClearAllPoints()
        row.rail:SetPoint("TOPLEFT", row, "TOPLEFT", RAIL_X, it.firstIn and -2 or 0)
        row.rail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", RAIL_X, it.lastOut and 8 or 0)
        row.rail:Show()
    end
    if nest >= 2 then
        row.rail2:ClearAllPoints()
        row.rail2:SetPoint("TOPLEFT", row, "TOPLEFT", RAIL_X + NEST, 0)
        row.rail2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", RAIL_X + NEST, it.lastIn and 6 or 0)
        row.rail2:Show()
    end
end

local function RowHeight(it)
    if it.kind == "banner" then return BANNER_H elseif it.kind == "card" or it.kind == "person" then return CARD_H
    elseif it.kind == "top" then return TOP_H end
    return LEAF_H
end

function W.RenderTree()
    local items = Tree()
    W.items = items
    W.sel = math.max(1, math.min(W.sel, #items))
    local y = 2
    for i, it in ipairs(items) do
        local row = rows[i] or NewRow(i)
        row.index, row.item = i, it
        if it.kind == "banner" and i > 1 then y = y + BANNER_GAP end
        local h = RowHeight(it)
        local indent = (it.nest or 0) * NEST + ((it.nest or 0) > 0 and 4 or 0)
        row.indent = indent
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 2, -y)
        row:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", -5, -y)
        row:SetHeight(h)
        row.top, row.bottom = y, y + h
        y = y + h + ((it.kind == "card" or it.kind == "person") and 2 or 0)
        Hide(row.barL, row.barM, row.barR, row.toggle, row.icon, row.iconEdge, row.count, row.sub, row.tick, row.track,
            row.fill, row.wash, row.warm)
        ShowAll(row.card, false)
        row.cardArt = nil
        row.label:SetWidth(0)
        row.toggle:SetSize(14, 14)
        row.wash:ClearAllPoints()
        row.wash:SetPoint("TOPLEFT", indent, 0)
        row.wash:SetPoint("BOTTOMRIGHT")
        row.warm:ClearAllPoints()
        row.warm:SetPoint("TOPLEFT", indent + 4, -4)
        row.warm:SetPoint("BOTTOMRIGHT", -4, 4)
        if it.kind == "banner" then DrawBanner(row, it)
        elseif it.kind == "card" or it.kind == "person" then DrawCard(row, it, indent)
        elseif it.kind == "day" then DrawDay(row, it, indent)
        else DrawTop(row, it) end
        it.firstIn = i > 1 and (items[i - 1].nest or 0) < (it.nest or 0)
        Rails(row, it)
        row:Show()
        W.LightRow(row)
    end
    for i = #items + 1, #rows do rows[i]:Hide() end
    listChild:SetHeight(y + 8)
    listThumb:Update()
end

-- The picked row in sight
local function ShowRow(i)
    local row = rows[i]
    if not row then return end
    local top, view = listScroll:GetVerticalScroll(), listScroll:GetHeight()
    if row.top - 8 < top then
        listScroll:SetVerticalScroll(math.max(0, row.top - 8))
    elseif row.bottom + 8 > top + view then
        listScroll:SetVerticalScroll(math.max(0, row.bottom + 8 - view))
    end
    listThumb:Update()
end

---------------------------------------------------------------------------
-- The page: parchment, its title, the words that scroll
---------------------------------------------------------------------------
local pageInset = Inset(window)
pageInset:SetPoint("TOPLEFT", listInset, "TOPRIGHT", SIDE, LIST_TOP - 22)
pageInset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -SIDE, SIDE)
local page = K.NewFrame("Frame", nil, pageInset)
page:SetPoint("TOPLEFT", 3, -3)
page:SetPoint("BOTTOMRIGHT", -3, 3)
if type(pageInset.NineSlice) == "table" and pageInset.NineSlice.SetFrameLevel then
    pageInset.NineSlice:SetFrameLevel(page:GetFrameLevel() + 5)
end
W.page = page

local parchment = page:CreateTexture(nil, "BACKGROUND")
parchment:SetAllPoints()
do
    -- (the quest log's page, lighter, as Spoken Places' Place Story has it:
    -- its copy where it's installed, else the game's own; else the
    -- spellbook's page, its dark top band cut off)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Spoken_Places")
    local info = C_Texture and C_Texture.GetAtlasInfo and IF.HasAtlas("spellbook-Page-Right-C60")
        and C_Texture.GetAtlasInfo("spellbook-Page-Right-C60")
    if loaded then
        parchment:SetTexture("Interface\\AddOns\\Spoken_Places\\Textures\\Art\\QuestDetailsBackgrounds")
        parchment:SetTexCoord(0, 0.560547, 0, 0.90625)
    elseif IF.HasAtlas("QuestDetailsBackgrounds") then
        parchment:SetAtlas("QuestDetailsBackgrounds")
    elseif info then
        AtlasCut(parchment, "spellbook-Page-Right-C60", 0, info.width, info.height * 0.07, info.height)
    else
        parchment:SetColorTexture(0.86, 0.76, 0.56, 1)
    end
end

local title = Ink(page:CreateFontString(nil, "ARTWORK"), HEADING_FONT, 26, INK)
title:SetPoint("TOPLEFT", page, "TOPLEFT", PAD_L, -PAD_TOP)
title:SetPoint("RIGHT", page, "RIGHT", -PAD_R, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)
local subtitle = Ink(page:CreateFontString(nil, "ARTWORK"), BODY_FONT, 12, INK)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetPoint("RIGHT", page, "RIGHT", -PAD_R, 0)
subtitle:SetJustifyH("LEFT")
subtitle:SetWordWrap(false)
local divider = page:CreateTexture(nil, "ARTWORK")
divider:SetHeight(11)
divider:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -6, -8)
divider:SetPoint("RIGHT", page, "RIGHT", -PAD_R + 6, 0)
if not Atlas(divider, "spellbook-divider") then divider:SetColorTexture(INK[1], INK[2], INK[3], 0.35) divider:SetHeight(1) end

local pageScroll = K.NewFrame("ScrollFrame", nil, page)
pageScroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 6, -4)
pageScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -PAD_R + 12, 16)
local body = K.NewFrame("Frame", nil, pageScroll)
body:SetSize(TEXT_W, 1)
pageScroll:SetScrollChild(body)
pageScroll:EnableMouseWheel(true)
local pageThumb = Thumb(page, pageScroll, body, INK[1], INK[2], INK[3], 0.45)

-- Pools: made as needed, handed out again each time it's drawn
local function Pool(make)
    local pool = { used = 0, list = {} }
    function pool:Next()
        self.used = self.used + 1
        local f = self.list[self.used]
        if not f then
            f = make()
            self.list[self.used] = f
        end
        f:Show()
        return f
    end
    function pool:Reset() self.used = 0 end
    function pool:HideRest()
        for i = self.used + 1, #self.list do self.list[i]:Hide() end
    end
    return pool
end

local paragraphs = Pool(function()
    local fs = Ink(body:CreateFontString(nil, "ARTWORK"), BODY_FONT, 13, INK)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(4)
    fs:SetWidth(TEXT_W)
    return fs
end)

local headings = Pool(function()
    local f = K.NewFrame("Frame", nil, body)
    f:SetSize(TEXT_W, 30)
    f.text = Ink(f:CreateFontString(nil, "ARTWORK"), HEADING_FONT, 17, ACCENT_RGB)
    f.text:SetPoint("BOTTOMLEFT", 0, 8)
    f.info = Ink(f:CreateFontString(nil, "ARTWORK"), BODY_FONT, 11, INK)
    f.info:SetPoint("BOTTOMRIGHT", 0, 9)
    f.info:SetAlpha(0.7)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(6)
    f.rule:SetPoint("BOTTOMLEFT", -10, 0)
    f.rule:SetPoint("BOTTOMRIGHT", 6, 0)
    if not Atlas(f.rule, "spellbook-divider") then f.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.4) f.rule:SetHeight(1) end
    f.rule:SetAlpha(0.55)
    return f
end)

-- A ledger's line: its name, dots out to its value
local ledgers = Pool(function()
    local f = K.NewFrame("Frame", nil, body)
    f:SetSize(TEXT_W - 20, 18)
    f.name = Ink(f:CreateFontString(nil, "ARTWORK"), BODY_FONT, 12, INK)
    f.name:SetPoint("LEFT")
    f.value = Ink(f:CreateFontString(nil, "ARTWORK"), BODY_FONT, 12, INK)
    f.value:SetPoint("RIGHT")
    f.dots = Ink(f:CreateFontString(nil, "ARTWORK"), BODY_FONT, 12, INK)
    f.dots:SetPoint("LEFT", f.name, "RIGHT", 4, 0)
    f.dots:SetPoint("RIGHT", f.value, "LEFT", -4, 0)
    f.dots:SetWordWrap(false)
    f.dots:SetJustifyH("LEFT")
    f.dots:SetAlpha(0.45)
    f.dots:SetText(string.rep(". ", 80))
    return f
end)

-- A list's entry: an icon, its name, a line under it; the pad's stroke
-- and cursor while it's where the pad is
local links = Pool(function()
    local b = K.NewFrame("Button", nil, body)
    b:SetSize(TEXT_W, 32)
    b:RegisterForClicks("LeftButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(24, 24)
    b.icon:SetPoint("LEFT", 8, 0)
    b.edge = b:CreateTexture(nil, "ARTWORK", nil, -1)
    b.edge:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -1, 1)
    b.edge:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, -1)
    b.edge:SetColorTexture(INK[1], INK[2], INK[3], 0.6)
    b.name = Ink(b:CreateFontString(nil, "ARTWORK"), BODY_FONT, 13, INK)
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, 1)
    b.name:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = Ink(b:CreateFontString(nil, "ARTWORK"), BODY_FONT, 11, INK)
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
    b.sub:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b.sub:SetAlpha(0.75)
    b.hover = b:CreateTexture(nil, "BACKGROUND")
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(INK[1], INK[2], INK[3], 0.08)
    b.hover:Hide()
    b.ring = IF.UI.FocusStroke(b)
    b:SetScript("OnClick", function(self) W.ActivateLink(self.link) end)
    b:SetScript("OnEnter", function(self)
        if IF.Input.Pad() then return end
        self.hover:Show()
        W.Tip(self, self.link)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    return b
end)

---------------------------------------------------------------------------
-- A pinned note: a slip of paper, a strip of tape over its top. Beside the
-- paragraph it belongs to: the map torn out round a place (a pin and its
-- label on it), the foe as it stood, a tally of them, a find
---------------------------------------------------------------------------
local NOTE_W = math.floor((TEXT_W - 18) / 2)   -- (two across: the journal's first page)
local MODEL_W, MODEL_H = 76, 92
local LEVEL_ICON = "Interface\\Icons\\Spell_ChargePositive"

local notes = Pool(function()
    local f = K.NewFrame("Frame", nil, body)
    f:SetWidth(NOTE_W)
    -- (its paper and what's under it: turned as it was pasted, Dress below)
    f.back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.backShadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.shadow2 = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.shadow = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    f.edge = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    f.paper = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    f.grain = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.rules = {}
    f.title = Ink(f:CreateFontString(nil, "ARTWORK"), HAND_BOLD, 15, RUBRIC)
    f.title:SetPoint("TOPLEFT", 12, -14)
    f.title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.title:SetJustifyH("LEFT")
    f.big = Ink(f:CreateFontString(nil, "ARTWORK"), HAND_BOLD, 22, HAND_INK)
    f.big:SetJustifyH("LEFT")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(30, 30)
    f.icon:SetPoint("TOPRIGHT", -10, -12)
    f.text = Ink(f:CreateFontString(nil, "ARTWORK"), HAND_FONT, 14, HAND_INK)
    -- (a photograph's caption, under it)
    f.caption = Ink(f:CreateFontString(nil, "ARTWORK"), HAND_BOLD, 16, HAND_INK)
    f.caption:SetJustifyH("CENTER")
    f.sub = Ink(f:CreateFontString(nil, "ARTWORK"), HAND_FONT, 13, HAND_INK)
    f.sub:SetJustifyH("CENTER")
    f.sub:SetAlpha(0.75)
    -- (a photograph's dark behind the foe)
    f.backdrop = f:CreateTexture(nil, "BORDER", nil, 1)
    f.blots = {}
    f.mk, f.mCoins = {}, {}             -- (a mark's parts, made as needed)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    f.marks = {}
    -- (the map, torn out round a place: its tiles clipped to the piece)
    f.map = K.NewFrame("Frame", nil, f)
    if f.map.SetClipsChildren then f.map:SetClipsChildren(true) end
    f.map.tiles = {}
    f.mapEdge = f:CreateTexture(nil, "BORDER")
    f.mapEdge:SetColorTexture(INK[1], INK[2], INK[3], 0.55)
    f.pins = K.NewFrame("Frame", nil, f)
    f.pins:SetAllPoints()
    f.pins:SetFrameLevel(f.map:GetFrameLevel() + 4)
    f.pin = f.pins:CreateTexture(nil, "OVERLAY", nil, 2)
    f.pin:SetSize(18, 18)
    f.tag = f.pins:CreateTexture(nil, "OVERLAY", nil, 0)
    f.tag:SetColorTexture(0.98, 0.96, 0.9, 0.95)
    f.tagEdge = f.pins:CreateTexture(nil, "OVERLAY", nil, -1)
    f.tagEdge:SetColorTexture(0.12, 0.07, 0.03, 0.9)
    f.tagEdge:SetPoint("TOPLEFT", f.tag, "TOPLEFT", -1, 1)
    f.tagEdge:SetPoint("BOTTOMRIGHT", f.tag, "BOTTOMRIGHT", 1, -1)
    f.tagText = Ink(f.pins:CreateFontString(nil, "OVERLAY"), HEADING_FONT, 12, { 0.1, 0.06, 0.03 })
    f.tape = f.pins:CreateTexture(nil, "OVERLAY", nil, 3)
    f.tape2 = f.pins:CreateTexture(nil, "OVERLAY", nil, 3)
    f.pinShadow = f.pins:CreateTexture(nil, "OVERLAY", nil, 4)
    f.pinHead = f.pins:CreateTexture(nil, "OVERLAY", nil, 5)
    f.corners = {}
    for c = 1, 4 do f.corners[c] = f.pins:CreateTexture(nil, "OVERLAY", nil, 1) end
    -- (pasted in: it drops onto the page, a moment after the one before)
    f.drop = f:CreateAnimationGroup()
    f.drop:SetToFinalAlpha(true)
    local fade = f.drop:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.22)
    local settle = f.drop:CreateAnimation("Scale")
    if settle.SetScaleFrom then
        settle:SetScaleFrom(1.18, 1.18)
        settle:SetScaleTo(1, 1)
    elseif settle.SetFromScale then
        settle:SetFromScale(1.18, 1.18)
        settle:SetToScale(1, 1)
    end
    settle:SetDuration(0.32)
    settle:SetSmoothing("OUT")
    f.dropParts = { fade, settle }
    -- (the foe as it stood: its model, else its face)
    local okModel, model = pcall(CreateFrame, "PlayerModel", nil, f)
    if okModel and model then
        f.model = model
        model:SetSize(MODEL_W, MODEL_H)
    end
    f.face = f:CreateTexture(nil, "ARTWORK")
    f.face:SetSize(56, 56)
    -- (what's on top of the picture: over the model, too)
    f.pins:SetFrameLevel(f:GetFrameLevel() + 8)
    return f
end)

-- A tally: strokes in fives, the fifth across them
local TALLY_STEP = 30
local function Tally(f, n, x, y, width)
    local shown = math.min(n, 50)
    local across = math.max(1, math.floor(width / TALLY_STEP))
    local lines = 0
    for i = 1, shown do
        local group, pos = math.floor((i - 1) / 5), (i - 1) % 5
        local line, col = math.floor(group / across), group % across
        lines = line + 1
        local left, top = x + col * TALLY_STEP, y + line * 22
        local t = f.marks[i] or f:CreateTexture(nil, "ARTWORK")
        f.marks[i] = t
        t:SetColorTexture(INK[1], INK[2], INK[3], 0.85)
        t:ClearAllPoints()
        if pos < 4 then
            t:SetRotation(0)
            t:SetSize(2, 16)
            t:SetPoint("TOPLEFT", f, "TOPLEFT", left + pos * 5, -top)
        else
            -- (the fifth, across the four)
            t:SetSize(2, 24)
            t:SetRotation(math.rad(-62))
            t:SetPoint("CENTER", f, "TOPLEFT", left + 8, -top - 8)
        end
        t:Show()
    end
    for i = shown + 1, #f.marks do f.marks[i]:Hide() end
    return y + lines * 22 + 2
end

-- A zone's map art as the world map shows it, printed as an old photograph:
-- the base tiles (a classic zone's base is only its frame, the mountains
-- round the edge) and over them the areas explored, laid as the world map
-- lays them (C_MapExplorationInfo.GetExploredMapTextures: each area's size,
-- offset and its tiles row by row; its last row and column in files the
-- least power of two from 16 that holds them). Areas shown only under the
-- mouse left off. The colour drawn part way to grey and warmed, a print
-- rather than a screen (as Social Diary's plates are). Never the world map
-- frame: nothing to taint.
local PRINT = { desaturate = 0.35, tint = { 0.97, 0.91, 0.78 } }

local function FileSize(pixels)
    local size = 16
    while size < pixels do size = size * 2 end
    return size
end

-- The map's art layer and its pieces ({ file, x, y, w, h, fw, fh } in the
-- layer's pixels), kept a map at a time; nil: no art
local artCache = {}
local function MapPieces(map)
    local cached = artCache[map]
    if cached ~= nil then
        if cached then return cached.layer, cached.pieces end
        return nil
    end
    artCache[map] = false
    local okL, layers = pcall(C_Map.GetMapArtLayers, map)
    local layer = okL and layers and layers[1]
    local okT, textures = pcall(C_Map.GetMapArtLayerTextures, map, 1)
    if not (layer and (layer.layerWidth or 0) > 0 and okT and textures and #textures > 0) then return nil end
    local TW, TH = layer.tileWidth, layer.tileHeight
    local cols, rows = math.ceil(layer.layerWidth / TW), math.ceil(layer.layerHeight / TH)
    local pieces = {}
    for r = 1, rows do
        for c = 1, cols do
            local file = textures[(r - 1) * cols + c]
            if file then
                pieces[#pieces + 1] = { file = file, x = (c - 1) * TW, y = (r - 1) * TH, w = TW, h = TH, fw = TW, fh = TH }
            end
        end
    end
    local explored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    local okE, areas = false, nil
    if explored then okE, areas = pcall(explored, map) end
    for _, area in ipairs(okE and areas or {}) do
        local files, AW, AH = area.fileDataIDs, area.textureWidth, area.textureHeight
        if files and not area.isShownByMouseOver and (AW or 0) > 0 and (AH or 0) > 0 then
            local wide, tall = math.ceil(AW / TW), math.ceil(AH / TH)
            for j = 1, tall do
                local h = j < tall and TH or AH - (tall - 1) * TH
                for k = 1, wide do
                    local file = files[(j - 1) * wide + k]
                    if file then
                        local w = k < wide and TW or AW - (wide - 1) * TW
                        pieces[#pieces + 1] = { file = file, x = area.offsetX + (k - 1) * TW, y = area.offsetY + (j - 1) * TH,
                            w = w, h = h, fw = k < wide and TW or FileSize(w), fh = j < tall and TH or FileSize(h), over = true }
                    end
                end
            end
        end
    end
    artCache[map] = { layer = layer, pieces = pieces }
    return layer, pieces
end

-- The map printed into clip (w x h): the window of it x0, y0 .. x1, y1 in
-- the layer's pixels, its pieces from the clip's own pool (clip.tiles)
local function PrintMap(clip, layer, pieces, x0, y0, x1, y1, w, h)
    local tiles = clip.tiles
    local used = 0
    local sx, sy = w / (x1 - x0), h / (y1 - y0)
    for _, p in ipairs(pieces) do
        local ix0, ix1 = math.max(p.x, x0), math.min(p.x + p.w, x1)
        local iy0, iy1 = math.max(p.y, y0), math.min(p.y + p.h, y1)
        if ix1 > ix0 and iy1 > iy0 then
            used = used + 1
            local t = tiles[used]
            if not t then
                t = clip:CreateTexture(nil, "ARTWORK")
                tiles[used] = t
            end
            t:SetDrawLayer("ARTWORK", p.over and 1 or 0)
            t:SetTexture(p.file)
            t:SetTexCoord((ix0 - p.x) / p.fw, (ix1 - p.x) / p.fw, (iy0 - p.y) / p.fh, (iy1 - p.y) / p.fh)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", clip, "TOPLEFT", (ix0 - x0) * sx, -(iy0 - y0) * sy)
            t:SetSize((ix1 - ix0) * sx, (iy1 - iy0) * sy)
            if t.SetDesaturation then t:SetDesaturation(PRINT.desaturate) end
            t:SetVertexColor(PRINT.tint[1], PRINT.tint[2], PRINT.tint[3])
            t:Show()
        end
    end
    for i = used + 1, #tiles do tiles[i]:Hide() end
    return used > 0
end

-- A window of the map w x h on screen, its middle at cx, cy (0-1) and
-- `zoom` times the map's width across w (kept on the map); where a point
-- (0-1) falls in it
local function MapWindow(layer, cx, cy, zoom, w, h)
    local LW, LH = layer.layerWidth, layer.layerHeight
    local ww = LW / zoom
    local wh = ww * h / w
    if wh > LH then wh, ww = LH, LH * w / h end
    local x0 = math.max(0, math.min(LW - ww, cx * LW - ww / 2))
    local y0 = math.max(0, math.min(LH - wh, cy * LH - wh / 2))
    return x0, y0, x0 + ww, y0 + wh, function(x, y) return (x * LW - x0) * w / ww, (y * LH - y0) * h / wh end
end

-- The map's art round a place, in w x h at x, y of the note; where the
-- place falls on it (nil: no art)
local function Crop(f, n, x, y, w, h)
    local clip = f.map
    local layer, pieces = MapPieces(n.map)
    if not layer then
        for _, t in ipairs(clip.tiles) do t:Hide() end
        return nil
    end
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    clip:SetSize(w, h)
    local x0, y0, x1, y1, At = MapWindow(layer, n.x or 0.5, n.y or 0.5, n.zoom or 2.4, w, h)
    PrintMap(clip, layer, pieces, x0, y0, x1, y1, w, h)
    local px, py = At(n.x or 0.5, n.y or 0.5)
    return x + px, y + py
end

-- The foe on a note: its model where the client draws one, else its face
local function Foe(f, display, x, y, w, h)
    if f.model then f.model:Hide() end
    f.face:Hide()
    f.modelY = nil
    if not display then return false end
    if f.model and pcall(f.model.SetDisplayInfo, f.model, display) then
        f.modelY = y
        f.model:SetSize(w or MODEL_W, h or MODEL_H)
        f.modelH = h or MODEL_H
        f.model:ClearAllPoints()
        f.model:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
        f.model:Show()
        pcall(f.model.SetPortraitZoom, f.model, 0)
        pcall(f.model.SetCamDistanceScale, f.model, 0.85)
        pcall(f.model.SetRotation, f.model, math.rad(20))
        return true, w or MODEL_W, h or MODEL_H
    end
    if SetPortraitTextureFromCreatureDisplayID and pcall(SetPortraitTextureFromCreatureDisplayID, f.face, display) then
        f.face:ClearAllPoints()
        if w then f.face:SetPoint("CENTER", f, "TOPLEFT", x + w / 2, -y - h / 2)
        else f.face:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y) end
        f.face:Show()
        return true, 56, 56
    end
    return false
end

-- A note laid out w wide: { title, map, x, y, zoom, callout, pin, display,
-- big, icon, text, tally }; its height
-- A note's look, by what it holds: a photograph for a map (a white border,
-- taped at its corners), a poster for a foe (old paper, pinned), an index
-- card for a level or a fight (ruled lines, red under its title), a torn
-- slip for the rest (another sheet peeking out under it)
local NOTE_STYLES = {
    photo = { paper = { 0.90, 0.85, 0.70 }, edge = { 0.29, 0.19, 0.105 }, tilt = 1.6 },
    scrap = { paper = { 0.86, 0.76, 0.56 }, edge = { 0.4, 0.26, 0.12 }, tilt = 4 },
    poster = { paper = { 0.92, 0.86, 0.70 }, edge = { 0.29, 0.19, 0.105 }, tilt = 3, pin = true },
    card = { paper = { 0.95, 0.91, 0.79 }, edge = { 0.29, 0.19, 0.105 }, tilt = 2.5, rules = true },
    slip = { paper = { 0.95, 0.91, 0.79 }, edge = { 0.29, 0.19, 0.105 }, tilt = 2, back = true },
}

local function NoteStyle(n)
    if n.map or n.photo then return "photo" end
    if n.quote then return "scrap" end
    if n.display or n.tally then return "poster" end
    if n.icon == LEVEL_ICON or (n.big and not n.icon) then return "card" end
    return "slip"
end

-- (a point of the paper, from its middle, as it's turned)
local function Turned(dx, dy, a)
    local c, s = math.cos(a), math.sin(a)
    return dx * c - dy * s, dx * s + dy * c
end

local function Paper(tex, style, tint)
    tex:SetColorTexture(tint[1], tint[2], tint[3], 1)
end

local function Sheet(tex, w, h, a, dx, dy)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", tex:GetParent(), "CENTER", dx or 0, dy or 0)
    tex:SetSize(w, h)
    tex:SetRotation(a)
    tex:Show()
end

local function Tape(tex, x, y, a, w)
    tex:SetColorTexture(0.98, 0.96, 0.84, 0.55)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", tex:GetParent(), "TOPLEFT", x, -y)
    tex:SetSize(w or 56, 15)
    tex:SetRotation(a)
    tex:Show()
end

-- seed: where it is on the page, to turn each its own way
local PAPER_PARTS = { "back", "backShadow", "shadow2", "shadow", "edge", "paper", "grain", "tape", "tape2", "pinHead", "pinShadow" }

local function Dress(f, n, w, h, seed)
    if n.mark then
        -- (drawn on the page itself: no paper)
        for _, k in ipairs(PAPER_PARTS) do f[k]:Hide() end
        for _, r in ipairs(f.rules) do r:Hide() end
        for _, c in ipairs(f.corners) do c:Hide() end
        return
    end
    local key = NoteStyle(n)
    local st = NOTE_STYLES[key]
    local sign = seed % 2 == 0 and 1 or -1
    local a = math.rad(sign * (st.tilt * (0.55 + (seed * 37 % 10) / 20)))
    local cx, cy = w / 2, h / 2
    -- (the shadow under it, soft: two of them)
    -- (a thin contact shadow, a soft one wider)
    f.shadow:SetColorTexture(0.12, 0.07, 0.02, 0.4)
    Sheet(f.shadow, w, h, a, 1.2, -1.5)
    f.shadow2:SetColorTexture(0.12, 0.07, 0.02, 0.14)
    Sheet(f.shadow2, w + 4, h + 4, a, 3.5, -4.5)
    f.edge:SetColorTexture(st.edge[1], st.edge[2], st.edge[3], 0.2)
    Sheet(f.edge, w + 2, h + 2, a)
    Paper(f.paper, st, st.paper)
    Sheet(f.paper, w, h, a)
    -- (the paper's grain)
    f.grain:SetTexture("Interface\\Stationery\\StationeryTest1")
    f.grain:SetVertexColor(1, 1, 1, key == "poster" and 0.2 or 0.13)
    Sheet(f.grain, w, h, a)
    -- (a sheet under the slip, turned the other way)
    f.back:Hide(); f.backShadow:Hide()
    if st.back then
        local b = -a * 2.4
        Paper(f.back, st, { 0.86, 0.76, 0.58 })
        Sheet(f.back, w - 10, h - 4, b, sign * 6, -5)
        f.backShadow:SetColorTexture(0.1, 0.05, 0.01, 0.22)
        Sheet(f.backShadow, w - 10, h - 4, b, sign * 6 + 3, -9)
    end
    -- (an index card's lines: red under the title, blue under that)
    for _, r in ipairs(f.rules) do r:Hide() end
    if st.rules then
        local top = 14 + math.ceil(f.title:GetStringHeight()) + 3
        local k, ly = 0, top
        while ly < h - 8 do
            k = k + 1
            local r = f.rules[k] or f:CreateTexture(nil, "BACKGROUND", nil, -1)
            f.rules[k] = r
            if k == 1 then r:SetColorTexture(0.8, 0.25, 0.22, 0.55) else r:SetColorTexture(0.35, 0.52, 0.8, 0.28) end
            local x, y = Turned(0, cy - ly, a)
            Sheet(r, w - 8, 1, a, x, y)
            ly = ly + 18
        end
    end
    -- (what holds it to the page)
    f.tape:Hide(); f.tape2:Hide(); f.pinHead:Hide(); f.pinShadow:Hide()
    for _, c in ipairs(f.corners) do c:Hide() end
    if key == "photo" and n.photo and seed % 2 == 1 then
        st = NOTE_STYLES.poster
    end
    if key == "photo" and not st.pin then
        -- (tape across its two top corners)
        local x1, y1 = Turned(-cx + 6, cy - 6, a)
        local x2, y2 = Turned(cx - 6, cy - 6, a)
        Tape(f.tape, cx + x1, cy - y1, a + math.rad(40), 46)
        Tape(f.tape2, cx + x2, cy - y2, a - math.rad(40), 46)
        -- (photo corners on the picture)
        if f.map:IsShown() then
            local l, t = 12, select(5, f.map:GetPoint(1)) or 0
            local mw, mh = f.map:GetWidth(), f.map:GetHeight()
            for c, p in ipairs({ { l, -t }, { l + mw, -t }, { l, -t + mh }, { l + mw, -t + mh } }) do
                local corner = f.corners[c]
                corner:SetColorTexture(0.18, 0.12, 0.07, 0.9)
                corner:ClearAllPoints()
                corner:SetPoint("CENTER", f, "TOPLEFT", p[1], -p[2])
                corner:SetSize(13, 13)
                corner:SetRotation(math.rad(45))
                corner:Show()
            end
        end
    elseif st.pin then
        -- (a pin through its top)
        local x, y = Turned(0, cy - 9, a)
        f.pinShadow:SetTexture("Interface\\COMMON\\Indicator-Gray")
        f.pinShadow:SetVertexColor(0, 0, 0, 0.5)
        f.pinShadow:ClearAllPoints()
        f.pinShadow:SetPoint("CENTER", f, "CENTER", x + 3, y - 4)
        f.pinShadow:SetSize(16, 16)
        f.pinShadow:Show()
        f.pinHead:SetTexture("Interface\\COMMON\\Indicator-Red")
        f.pinHead:SetVertexColor(1, 1, 1, 1)
        f.pinHead:ClearAllPoints()
        f.pinHead:SetPoint("CENTER", f, "CENTER", x, y)
        f.pinHead:SetSize(18, 18)
        f.pinHead:Show()
    else
        local x, y = Turned(sign * w * 0.12, cy, a)
        Tape(f.tape, cx + x, cy - y, a + math.rad(sign * -6), 60)
    end
end

-- Blood on a photograph: drops of it, where the seed falls
local function Blood(f, x, y, w, h, seed)
    for i = 1, 7 do
        local t = f.blots[i]
        if not t then
            t = f.pins:CreateTexture(nil, "OVERLAY", nil, 0)
            t:SetTexture(SEAL_MASK)
            f.blots[i] = t
        end
        local r = (seed * 13 + i * 29) % 100 / 100
        local size = i == 1 and 26 or (4 + (seed + i * 7) % 12)
        t:SetVertexColor(0.5, 0.02, 0.02, i == 1 and 0.55 or 0.7)
        t:SetSize(size, size * (0.8 + r * 0.4))
        t:ClearAllPoints()
        t:SetPoint("CENTER", f, "TOPLEFT", x + w * (0.55 + (r - 0.5) * 0.7), -(y + h * (0.35 + ((i * 37) % 100 / 100 - 0.5) * 0.6)))
        t:Show()
    end
end

-- A photograph: the picture (the map round a place, the foe as it stood),
-- its caption written under it, a tally under that
local function FillPhoto(f, n, w, seed)
    local inner = w - 20
    local y, ph = 10, n.map and math.floor(inner * 0.68) or math.floor(inner * 0.78)
    local drawn = false
    if n.map then
        local px, py = Crop(f, n, 10, y, inner, ph)
        if px then
            drawn = true
            f.map:Show()
            f.mapEdge:ClearAllPoints()
            f.mapEdge:SetPoint("TOPLEFT", f.map, "TOPLEFT", -1, 1)
            f.mapEdge:SetPoint("BOTTOMRIGHT", f.map, "BOTTOMRIGHT", 1, -1)
            f.mapEdge:Show()
            if n.pin == "skull" then
                f.pin:SetTexture(SKULL)
                f.pin:SetTexCoord(0, 1, 0, 1)
            else
                f.pin:SetTexture("Interface\\Minimap\\ObjectIcons")
                f.pin:SetTexCoord(0.125, 0.25, 0, 0.125)
                if IF.HasAtlas("Waypoint-MapPin-Untracked") then f.pin:SetAtlas("Waypoint-MapPin-Untracked") end
            end
            f.pin:ClearAllPoints()
            f.pin:SetPoint("CENTER", f, "TOPLEFT", px, -py)
            f.pin:Show()
        end
    else
        -- (an old photograph's dark, the foe on it)
        f.backdrop:ClearAllPoints()
        f.backdrop:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -y)
        f.backdrop:SetSize(inner, ph)
        f.backdrop:SetColorTexture(1, 1, 1, 1)
        if f.backdrop.SetGradient and CreateColor then
            pcall(f.backdrop.SetGradient, f.backdrop, "VERTICAL", CreateColor(0.18, 0.13, 0.09, 1), CreateColor(0.42, 0.34, 0.24, 1))
        else
            f.backdrop:SetColorTexture(0.3, 0.23, 0.16, 1)
        end
        f.backdrop:Show()
        Foe(f, n.display, 10, y, inner, ph)
        drawn = true
        if n.blood then Blood(f, 10, y, inner, ph, seed) end
    end
    if drawn then y = y + ph + 8 end
    f.caption:ClearAllPoints()
    f.caption:SetPoint("TOP", f, "TOPLEFT", w / 2, -y)
    f.caption:SetWidth(inner)
    f.caption:SetText(n.caption or "")
    if n.blood then f.caption:SetTextColor(RUBRIC[1], RUBRIC[2], RUBRIC[3]) else f.caption:SetTextColor(HAND_INK[1], HAND_INK[2], HAND_INK[3]) end
    f.caption:Show()
    y = y + math.ceil(f.caption:GetStringHeight()) + 1
    if n.sub then
        f.sub:ClearAllPoints()
        f.sub:SetPoint("TOP", f, "TOPLEFT", w / 2, -y)
        f.sub:SetWidth(inner)
        f.sub:SetText(n.sub)
        f.sub:Show()
        y = y + math.ceil(f.sub:GetStringHeight()) + 2
    end
    if n.tally then
        local across = math.min(10, math.ceil(math.min(n.tally, 50) / 5)) * 30
        y = Tally(f, n.tally, math.max(12, (w - across) / 2), y + 4, inner)
    end
    return y + 10
end

-- A mark drawn on the page, no paper: a badge with its number (a level, a
-- fall), coin with its sum, a find in a ring, a tally; its words written
-- under it. { mark = "badge" | "coin" | "item" | "tally", value, label,
-- sub, icon, coins = copper, net (+1 / -1), tally }
local COIN_ART = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local function Round(f, key, layer, sub)
    local t = f.mk[key]
    if t then return t end
    t = f.pins:CreateTexture(nil, layer, nil, sub)
    if f.CreateMaskTexture then
        local m = f:CreateMaskTexture()
        m:SetTexture(SEAL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    f.mk[key] = t
    return t
end

local function HideMark(f)
    for _, part in pairs(f.mk) do part:Hide() end
    for _, t in ipairs(f.mCoins) do t:Hide() end
end

local function Circle(t, x, y, size)
    t:ClearAllPoints()
    t:SetPoint("CENTER", t:GetParent(), "TOPLEFT", x, -y)
    t:SetSize(size, size)
    t:Show()
end

local function MarkText(f, key, font, size, color)
    if not f.mk[key] then
        f.mk[key] = f.pins:CreateFontString(nil, "OVERLAY")
        f.mk[key]:SetJustifyH("CENTER")
    end
    return Ink(f.mk[key], font, size, color)
end

-- A plain part of a mark (a texture of its own, made once)
local function MarkTex(f, key, sub)
    local t = f.mk[key]
    if not t then
        t = f.pins:CreateTexture(nil, "OVERLAY", nil, sub or 0)
        f.mk[key] = t
    end
    return t
end

-- A level's rosette: a scalloped red edge, ribbon tails under it, a cream
-- middle in a ring of ink, "LEVEL" over its number; its height
local function Rosette(f, cx, top, value)
    local r = 30
    local my = top + r + 2
    -- (the ribbon's tails, behind it)
    for i, side in ipairs({ -1, 1 }) do
        local t = MarkTex(f, "tail" .. i, -2)
        t:SetColorTexture(RUBRIC[1] * 0.85, RUBRIC[2] * 0.85, RUBRIC[3] * 0.85, 1)
        t:SetSize(14, 34)
        t:ClearAllPoints()
        t:SetPoint("CENTER", f, "TOPLEFT", cx + side * 11, -(my + 26))
        t:SetRotation(math.rad(side * -18))
        t:Show()
    end
    -- (the scallops round its edge)
    for i = 1, 16 do
        local a = (i - 1) / 16 * math.pi * 2
        local d = MarkTex(f, "scal" .. i, 1)
        d:SetTexture(SEAL_MASK)
        d:SetVertexColor(RUBRIC[1], RUBRIC[2], RUBRIC[3], 1)
        d:SetSize(13, 13)
        d:ClearAllPoints()
        d:SetPoint("CENTER", f, "TOPLEFT", cx + math.cos(a) * (r - 3), -(my + math.sin(a) * (r - 3)))
        d:Show()
    end
    local function Disc(key, size, color, alpha, sub)
        local d = MarkTex(f, key, sub)
        d:SetTexture(SEAL_MASK)
        d:SetVertexColor(color[1], color[2], color[3], alpha)
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("CENTER", f, "TOPLEFT", cx, -my)
        d:Show()
    end
    Disc("rRed", 2 * r - 4, RUBRIC, 1, 2)
    Disc("rCream", 2 * r - 14, { 0.96, 0.91, 0.78 }, 1, 3)
    Disc("rInk", 2 * r - 18, HAND_INK, 0.55, 4)
    Disc("rInner", 2 * r - 20, { 0.96, 0.91, 0.78 }, 1, 5)
    local word = MarkText(f, "rWord", HAND_BOLD, 9, RUBRIC)
    word:ClearAllPoints()
    word:SetPoint("CENTER", f, "TOPLEFT", cx, -(my - 11))
    word:SetText("LEVEL")
    word:Show()
    local v = MarkText(f, "mValue", HAND_BOLD, 24, HAND_INK)
    v:ClearAllPoints()
    v:SetPoint("CENTER", f, "TOPLEFT", cx, -(my + 4))
    v:SetText(value)
    v:Show()
    return 2 * r + 30
end

-- Coin, as one writes it: "20s 47c"
local function CoinWords(copper)
    local parts = {}
    for i, n in ipairs({ math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }) do
        if n > 0 then parts[#parts + 1] = n .. ({ "g", "s", "c" })[i] end
    end
    return #parts > 0 and table.concat(parts, " ") or "0c"
end

-- The purse: a little stack of each coin (gold, silver, copper), taller
-- the more of it, its count written under it; its height
local function CoinStacks(f, cx, top, copper, lost, seed)
    local counts = { math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }
    local shown = {}
    for i = 1, 3 do if counts[i] > 0 then shown[#shown + 1] = i end end
    if #shown == 0 then shown[1] = 3 end
    local gap = 46
    local x0 = cx - (#shown - 1) * gap / 2
    local base = top + 40
    local used = 0
    for k, coin in ipairs(shown) do
        local x = x0 + (k - 1) * gap
        local tall = math.max(1, math.min(6, 1 + math.floor(math.log10(counts[coin] + 1) * 2.5)))
        for c = 1, tall do
            used = used + 1
            local t = f.mCoins[used] or f.pins:CreateTexture(nil, "OVERLAY", nil, 2)
            f.mCoins[used] = t
            t:SetTexture(COIN_ART[coin])
            t:SetSize(22, 22)
            t:ClearAllPoints()
            -- (each a little off the one under it)
            t:SetPoint("CENTER", f, "TOPLEFT", x + ((seed + c * 3 + k) % 3 - 1) * 1.5, -(base - (c - 1) * 4))
            t:SetDrawLayer("OVERLAY", math.min(7, c))
            t:Show()
        end
        local fs = MarkText(f, "cnt" .. k, HAND_BOLD, 17, lost and RUBRIC or HAND_INK)
        fs:ClearAllPoints()
        fs:SetPoint("TOP", f, "TOPLEFT", x, -(base + 13))
        fs:SetText((k == 1 and (lost and "-" or "+") or "") .. counts[coin] .. ({ "g", "s", "c" })[coin])
        fs:Show()
    end
    return base + 13 + 20 - top
end

local function FillMark(f, n, w, seed)
    local cx, y = w / 2, 6
    local kind = n.mark
    if kind == "badge" and n.value and not n.red then
        y = y + Rosette(f, cx, y, n.value)
    elseif kind == "badge" or kind == "item" then
        -- (a seal inked on the page: a ring, its middle, the number or the
        -- find in it)
        local size = kind == "badge" and 64 or 54
        local ink = n.red and RUBRIC or ACCENT_RGB
        local ring = Round(f, "mRing", "OVERLAY", 1)
        ring:SetColorTexture(ink[1], ink[2], ink[3], 0.85)
        Circle(ring, cx, y + size / 2, size)
        local fill = Round(f, "mFill", "OVERLAY", 2)
        fill:SetColorTexture(0.93, 0.85, 0.68, 1)
        Circle(fill, cx, y + size / 2, size - 6)
        local inner = Round(f, "mInner", "OVERLAY", 3)
        inner:SetColorTexture(ink[1], ink[2], ink[3], kind == "badge" and 0.18 or 0.5)
        Circle(inner, cx, y + size / 2, size - 11)
        if kind == "item" or n.icon then
            local icon = Round(f, "mIcon", "OVERLAY", 4)
            icon:SetTexture(n.icon)
            icon:SetVertexColor(1, 1, 1, 1)
            Circle(icon, cx, y + size / 2, kind == "item" and size - 14 or 28)
        end
        if n.value then
            local v = MarkText(f, "mValue", HAND_BOLD, kind == "badge" and 30 or 20, n.red and RUBRIC or HAND_INK)
            v:ClearAllPoints()
            v:SetPoint("CENTER", f, "TOPLEFT", cx, -(y + size / 2 + 1))
            v:SetText(n.value)
            v:Show()
        end
        y = y + size + 4
    elseif kind == "coin" then
        y = y + CoinStacks(f, cx, y, n.coins or 0, n.net and n.net < 0, seed)
    elseif kind == "tally" then
        local across = math.min(10, math.ceil(math.min(n.tally, 50) / 5)) * 30
        y = Tally(f, n.tally, math.max(4, (w - across) / 2), y + 4, w - 8) + 2
    end
    local l = MarkText(f, "mLabel", HAND_BOLD, 16, n.red and RUBRIC or HAND_INK)
    l:ClearAllPoints()
    l:SetPoint("TOP", f, "TOPLEFT", cx, -y)
    l:SetWidth(w)
    l:SetText(n.label or "")
    l:Show()
    y = y + math.ceil(l:GetStringHeight())
    if n.sub then
        local sub = MarkText(f, "mSub", HAND_FONT, 13, HAND_INK)
        sub:SetAlpha(0.75)
        sub:ClearAllPoints()
        sub:SetPoint("TOP", f, "TOPLEFT", cx, -(y + 1))
        sub:SetWidth(w)
        sub:SetText(n.sub)
        sub:Show()
        y = y + 1 + math.ceil(sub:GetStringHeight())
    end
    return y + 4
end

local function FillNote(f, n, w, seed)
    f:SetWidth(w)
    f.map:Hide(); f.mapEdge:Hide(); f.pin:Hide(); f.tag:Hide(); f.tagEdge:Hide(); f.tagText:Hide()
    f.caption:Hide(); f.sub:Hide(); f.backdrop:Hide(); f.big:Hide(); f.icon:Hide()
    for _, t in ipairs(f.blots) do t:Hide() end
    for _, t in ipairs(f.marks) do t:Hide() end
    if f.model then f.model:Hide() end
    f.face:Hide()
    f.modelY = nil
    f.title:SetText(n.title or "")
    f.text:SetText("")
    HideMark(f)
    f.title:SetShown(not n.mark)
    if n.mark then
        local h = FillMark(f, n, w, seed or 0)
        f:SetHeight(h)
        Dress(f, n, w, h, seed or 0)
        return h
    end
    if n.map or n.photo then
        local h = FillPhoto(f, n, w, seed or 0)
        f:SetHeight(h)
        Dress(f, n, w, h, seed or 0)
        return h
    end
    if n.quote then
        -- (a scrap torn from a letter: the words, who said them)
        f.text:ClearAllPoints()
        f.text:SetPoint("TOPLEFT", 14, -14)
        f.text:SetWidth(w - 28)
        f.text:SetText(n.quote .. (n.by and ("\n|cff6e5a40" .. n.by .. "|r") or ""))
        local h = 14 + math.ceil(f.text:GetStringHeight()) + 14
        f:SetHeight(h)
        Dress(f, n, w, h, seed or 0)
        return h
    end
    local y = 14 + math.ceil(f.title:GetStringHeight()) + 6
    local inner = w - 24
    if n.map then
        local h = math.floor(inner * 0.66)
        local px, py = Crop(f, n, 12, y, inner, h)
        if px then
            f.map:Show()
            f.mapEdge:ClearAllPoints()
            f.mapEdge:SetPoint("TOPLEFT", f.map, "TOPLEFT", -1, 1)
            f.mapEdge:SetPoint("BOTTOMRIGHT", f.map, "BOTTOMRIGHT", 1, -1)
            f.mapEdge:Show()
            local pin = n.pin or "pin"
            if pin == "skull" then
                f.pin:SetTexture(SKULL)
                f.pin:SetTexCoord(0, 1, 0, 1)
            else
                f.pin:SetTexture("Interface\\Minimap\\ObjectIcons")
                f.pin:SetTexCoord(0.125, 0.25, 0, 0.125)
                if IF.HasAtlas("Waypoint-MapPin-Untracked") then f.pin:SetAtlas("Waypoint-MapPin-Untracked") end
            end
            f.pin:ClearAllPoints()
            f.pin:SetPoint("CENTER", f, "TOPLEFT", px, -py)
            f.pin:Show()
            if n.callout then
                -- (its label beside it, toward the piece's middle)
                f.tagText:SetText(n.callout)
                local tw = math.min(inner - 16, f.tagText:GetStringWidth() + 12)
                f.tag:SetSize(tw, 18)
                f.tag:ClearAllPoints()
                -- (right of the pin where it fits, else left; inside the piece)
                local tx = px + 14 + tw <= 12 + inner and (px + 12) or (px - 12 - tw)
                tx = math.max(14, math.min(12 + inner - tw - 2, tx))
                local ty = math.max(y + 2, math.min(y + h - 20, py - 9))
                f.tag:SetPoint("TOPLEFT", f, "TOPLEFT", tx, -ty)
                f.tagText:ClearAllPoints()
                f.tagText:SetPoint("CENTER", f.tag, "CENTER", 0, 0)
                f.tagText:SetWidth(tw - 8)
                f.tagText:SetWordWrap(false)
                f.tag:Show(); f.tagEdge:Show(); f.tagText:Show()
            end
            y = y + h + 8
        end
    end
    local left, bottom = 12, y
    local shown, fw, fh = Foe(f, n.display, 10, y)
    if shown then
        left = 10 + fw + 6
        bottom = y + fh
    end
    f.icon:SetShown(n.icon ~= nil)
    if n.icon then
        f.icon:SetTexture(n.icon)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local right = n.icon and not n.map and 46 or 12
    f.big:ClearAllPoints()
    if n.big then
        f.big:SetPoint("TOPLEFT", left, -y)
        f.big:SetWidth(w - left - right)
        f.big:SetText(n.big)
        f.big:Show()
        y = y + math.ceil(f.big:GetStringHeight()) + 4
    else
        f.big:Hide()
    end
    if n.tally then
        y = Tally(f, n.tally, left, y + 2, w - left - 12)
    else
        for _, t in ipairs(f.marks) do t:Hide() end
    end
    f.text:ClearAllPoints()
    f.text:SetPoint("TOPLEFT", left, -y)
    f.text:SetWidth(w - left - (n.big and 12 or right))
    f.text:SetText(n.text or "")
    if n.text and n.text ~= "" then y = y + math.ceil(f.text:GetStringHeight()) end
    local h = math.max(y, bottom) + 14
    f:SetHeight(h)
    Dress(f, n, w, h, seed or 0)
    return h
end

---------------------------------------------------------------------------
-- What's on a page
---------------------------------------------------------------------------
local function Display(npc)
    local looks = IF.WorldData and IF.WorldData.displays
    return npc and looks and looks[npc] or nil
end

local function NpcOf(day, name)
    return name and day.stats.foeIDs and day.stats.foeIDs[name] or nil
end

-- What a paragraph tells of, worth a note beside it, the most telling
-- first: where I woke, a fall, a hard fight, growing, the foe slain most,
-- a place seen first, a new land, a find, company
local function Moments(day, meta, i, text, used)
    local from = meta.starts[i] or 0
    local to = meta.starts[i + 1] or math.huge
    local found = {}
    local function add(rank, n) found[#found + 1] = { rank = rank, n = n, at = #found } end
    if i == 1 and meta.woke then
        local w = meta.woke
        add(1, { map = w.map, x = w.x, y = w.y, zoom = 1.7, caption = w.place or "Here",
            sub = w.inn and "where I woke, at the inn" or "where I woke" })
    end
    local foes, falls = {}, 0
    for _, e in ipairs(day.events) do
        if e.t and e.t >= from and e.t < to then
            local k = e.k
            if k == "death" then
                falls = falls + 1
                if falls == 1 then
                    local display = Display(NpcOf(day, e.by))
                    if display then
                        add(2, { photo = true, display = display, blood = true, caption = e.by,
                            sub = "got the better of me" })
                    elseif e.map and e.x then
                        add(2, { map = e.map, x = e.x, y = e.y, zoom = 1.7, pin = "skull", caption = e.sub or e.zone or "Here",
                            sub = e.by and ("where " .. e.by .. " felled me") or "where I fell" })
                    else
                        add(2, { mark = "badge", red = true, icon = SKULL, label = "I fell",
                            sub = e.by and ("to " .. e.by) or (e.sub or e.zone) })
                    end
                end
            elseif k == "kill" then
                local display = Display(e.npc)
                local what = Join({ e.level and ("level " .. e.level), J.FEARSOME[e.class] or "a fearsome brute" }, ", ")
                add(3, display and { photo = true, display = display, caption = e.name, sub = what }
                    or { title = "The hardest fight", big = e.name, text = BK.Capital(what) })
            elseif k == "level" then
                add(4, { mark = "badge", value = tostring(e.level or "?"), label = "Grew stronger!",
                    sub = (e.sub or e.zone) and ("at " .. (e.sub or e.zone)) or nil })
            elseif k == "hunt" then
                for name, n in pairs(e.foes or {}) do foes[name] = (foes[name] or 0) + n end
            elseif k == "discover" and e.map and e.x then
                add(6, { map = e.map, x = e.x, y = e.y, zoom = 1.6, caption = e.name, sub = "seen for the first time" })
            elseif k == "zone" and e.map and i > 1 then
                add(7, { map = e.map, x = e.x, y = e.y, zoom = 1, caption = e.name or "New lands", sub = "where the road led" })
            elseif k == "talk" and e.with and not (UnitName("player") and e.with:match("^(%S+)") == UnitName("player")) then
                -- (a line someone said to me, kept on a scrap)
                for _, line in ipairs(e.said or {}) do
                    if line[1] == 0 and line[2] and #line[2] >= 4 then
                        add(8.5, { quote = "\226\128\156" .. line[2]:sub(1, 1):upper() .. line[2]:sub(2) .. "\226\128\157",
                            by = "\226\128\148 " .. (e.with:match("^(%S+)") or e.with) })
                        break
                    end
                end
            elseif (k == "quest" and e.reward) or k == "loot" then
                local id = k == "quest" and e.reward or e.item
                local name, q = ItemName(id)
                if name and (q or 1) >= (k == "quest" and 2 or 3) then
                    add(8, { mark = "item", icon = ItemIcon(id), label = (BK.QUALITY_INK[q] or "") .. name .. "|r",
                        sub = k == "quest" and "my reward" or "a lucky find" })
                end
            elseif k == "party" and e.members and #e.members > 0 then
                local lines = {}
                for n, name in ipairs(e.members) do
                    if n > 4 then break end
                    local p = J.People and J.People.Get(name)
                    lines[#lines + 1] = name .. (p and (p.race or p.class)
                        and ("  |cff6e5a40" .. Join({ p.race, p.class }, " ") .. "|r") or "")
                end
                add(9, { title = "In good company", icon = JB.Avatar(J.People and J.People.Get(e.members[1])),
                    text = table.concat(lines, "\n") })
            end
        end
    end
    -- (the foe slain most here)
    local top, topN = nil, 0
    for name, n in pairs(foes) do
        if n > topN then top, topN = name, n end
    end
    if top and topN >= 3 then
        local display = Display(NpcOf(day, top))
        add(5, display and { photo = true, display = display, caption = top, tally = topN }
            or { mark = "tally", tally = topN, label = top, sub = topN .. " slain" })
    end
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.at < b.at
    end)
    local out, ranks = {}, {}
    -- (one beside a paragraph; two beside a long one, of different kinds;
    -- none the day has pinned already: the same foe twice)
    local room = #(text or "") > 700 and 2 or 1
    for _, f in ipairs(found) do
        if #out >= room then break end
        local id = (f.n.title or "") .. "|" .. (f.n.big or "") .. "|" .. (f.n.caption or "") .. "|" .. (f.n.quote or "")
            .. "|" .. (f.n.map and "map" or "")
        if not used[id] and not ranks[f.rank] then
            used[id], ranks[f.rank] = true, true
            out[#out + 1] = f.n
        end
    end
    return out
end

-- Beside the day's last words: the purse, the find of the day
-- Coin, short: its two largest coins, each with its picture
local COIN = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local function ShortCoins(copper)
    local parts = {}
    for i, n in ipairs({ math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }) do
        if n > 0 and #parts < 2 then parts[#parts + 1] = n .. "|T" .. COIN[i] .. ":13:13:1:0|t" end
    end
    return #parts > 0 and table.concat(parts, " ") or "0"
end

local function Closing(day)
    local s, out = day.stats, {}
    local m = s.money or { earned = 0, spent = 0 }
    if m.earned > 0 or m.spent > 0 then
        local net = m.earned - m.spent
        out[#out + 1] = { mark = "coin", coins = math.abs(net), net = net >= 0 and 1 or -1,
            value = (net >= 0 and "+" or "-") .. ShortCoins(math.abs(net)),
            label = net >= 0 and "The purse, heavier" or "The purse, lighter",
            sub = "earned " .. CoinWords(m.earned) .. ", spent " .. CoinWords(m.spent) }
    end
    local best, bestQ = nil, 1
    for _, e in ipairs(J.Events(day, "loot", "create")) do
        local _, q = ItemName(e.item)
        if q and q > bestQ then best, bestQ = e.item, q end
    end
    if best then
        out[#out + 1] = { mark = "item", icon = ItemIcon(best), sub = "the find of the day",
            label = (BK.QUALITY_INK[bestQ] or "") .. (ItemName(best) or "Something fine") .. "|r" }
    end
    return out
end

-- A page's content: { title, sub, paras, pinned = { [i] = notes }, signature,
-- notes (two across, after the words), ledger = { { name, value } },
-- sections = { { title, lines } } }
---------------------------------------------------------------------------
-- A paragraph told as a picture: the map where it happened glued in, the
-- road drawn on it, a numbered mark at each stop, a slip under it for each
-- with a pencil line up to its mark, a caption written under them
---------------------------------------------------------------------------
-- What a stop is, the most telling first (one stop, one kind)
local STOP_RANK = { death = 1, level = 2, discover = 3, hunt = 4, quest = 5, ready = 6, accept = 7, zone = 8 }

local function TopFoe(e)
    local top, n = nil, 0
    for name, c in pairs(e.foes or {}) do
        if c > n then top, n = name, c end
    end
    return top, e.n or n
end

-- A stop's slip: its words, red for a fall
local function StopWords(st)
    local e = st.e
    if st.k == "death" then return "Fell" .. (e.by and (" to " .. e.by) or ""), true end
    if st.k == "level" then return "Grew stronger: level " .. (e.level or "?") end
    if st.k == "discover" then return "Found " .. (e.name or "a new place") end
    if st.k == "hunt" then
        local top, n = TopFoe(e)
        return (n or 0) .. " slain" .. (top and (", most of them " .. top) or "")
    end
    if st.k == "quest" then return "Handed in \226\128\156" .. (e.name or "a task") .. "\226\128\157" end
    if st.k == "ready" then return "Done with \226\128\156" .. (e.name or "a task") .. "\226\128\157" end
    if st.k == "accept" then return "Took on \226\128\156" .. (e.name or "a task") .. "\226\128\157" end
    if st.k == "zone" then return "Into " .. (e.name or "new lands") end
end

-- The stops of a stretch of the day (from, to: its times) on its map
local function Stops(day, from, to)
    local byMap, order = {}, {}
    for _, e in ipairs(day.events) do
        if e.t and e.t >= from and e.t < to and e.map and e.x and e.y and STOP_RANK[e.k] then
            if not byMap[e.map] then
                byMap[e.map] = {}
                order[#order + 1] = e.map
            end
            local list = byMap[e.map]
            list[#list + 1] = e
        end
    end
    -- (the map with the most of it)
    local map, events = nil, {}
    for _, m in ipairs(order) do
        if #byMap[m] > #events then map, events = m, byMap[m] end
    end
    -- (events close together: one stop, told by the most telling of them)
    local stops = {}
    for _, e in ipairs(events) do
        local last = stops[#stops]
        if last and (e.x - last.x) ^ 2 + (e.y - last.y) ^ 2 < 0.0004 then
            if STOP_RANK[e.k] < STOP_RANK[last.k] then last.k, last.e = e.k, e end
        else
            stops[#stops + 1] = { x = e.x, y = e.y, k = e.k, e = e }
        end
    end
    return map, stops
end

-- A stretch worth a picture: on one map, four stops or more, spread out;
-- its worth (falls and fights count most)
local function PlateFor(day, meta, i)
    local from, to = meta.starts[i] or 0, meta.starts[i + 1] or math.huge
    local map, stops = Stops(day, from, to)
    if not map or #stops < 4 then return nil end
    local x1, y1, x2, y2 = 1, 1, 0, 0
    for _, st in ipairs(stops) do
        x1, y1, x2, y2 = math.min(x1, st.x), math.min(y1, st.y), math.max(x2, st.x), math.max(y2, st.y)
    end
    if (x2 - x1) + (y2 - y1) < 0.06 then return nil end
    -- (six at most: the most telling, in the order they came)
    if #stops > 6 then
        local ranked = {}
        for n, st in ipairs(stops) do ranked[n] = st; st.at = n end
        table.sort(ranked, function(a, b)
            if STOP_RANK[a.k] ~= STOP_RANK[b.k] then return STOP_RANK[a.k] < STOP_RANK[b.k] end
            return a.at < b.at
        end)
        local keep = {}
        for n = 1, 6 do keep[ranked[n]] = true end
        local out = {}
        for _, st in ipairs(stops) do if keep[st] then out[#out + 1] = st end end
        stops = out
    end
    local worth = 0
    for _, st in ipairs(stops) do
        worth = worth + (st.k == "death" and 4 or st.k == "level" and 3 or st.k == "hunt" and 2 or 1)
    end
    local first = stops[1].e
    local place = first.sub or first.zone
    local rm = first.rm or (J.RealmAt and J.RealmAt(first.t))
    local deaths = 0
    for _, st in ipairs(stops) do if st.k == "death" then deaths = deaths + 1 end end
    local caption = (place or "On the road") .. (rm and J.Clock and (", " .. (J.Clock(rm))) or "")
    local note = deaths > 1 and "Hard going." or deaths == 1 and "A close call." or nil
    return { map = map, stops = stops, box = { x1, y1, x2, y2 }, worth = worth, caption = caption, note = note }
end

-- The day's pictures: the one or two stretches most worth one, never side
-- by side, never the first words of the day nor its last
local function Plates(day, meta, paras)
    local found = {}
    for i = 2, #paras do
        if i ~= meta.summary then
            local p = PlateFor(day, meta, i)
            if p then found[#found + 1] = { i = i, p = p } end
        end
    end
    table.sort(found, function(a, b) return a.p.worth > b.p.worth end)
    local out, room = {}, #paras >= 8 and 2 or 1
    for _, f in ipairs(found) do
        if room <= 0 then break end
        if not out[f.i - 1] and not out[f.i + 1] then
            out[f.i] = f.p
            room = room - 1
        end
    end
    return out
end

-- The day in numbers, as stamps at the page's foot: { icon, value, label }
local STAMP_ICONS = {
    slain = ICON .. "INV_Sword_04", falls = ICON .. "Ability_Rogue_FeignDeath", level = LEVEL_ICON,
    tasks = ICON .. "INV_Misc_Note_01", gain = ICON .. "INV_Misc_Coin_02", loss = ICON .. "INV_Misc_Coin_04",
    time = ICON .. "INV_Misc_PocketWatch_01", found = ICON .. "INV_Misc_Map_01", finds = ICON .. "INV_Misc_Bag_10",
    company = ICON .. "INV_Misc_GroupLooking", days = ICON .. "INV_Scroll_03",
}

local function Stamps(t)
    local out = {}
    local function add(key, value, label) out[#out + 1] = { icon = STAMP_ICONS[key], value = value, label = label } end
    if (t.days or 0) > 0 then add("days", tostring(t.days), t.days == 1 and "Day written" or "Days written") end
    if (t.played or 0) > 0 then add("time", J.Played(t.played), "On the road") end
    if (t.kills or 0) > 0 then add("slain", tostring(t.kills), "Slain") end
    if (t.levels or 0) > 0 then add("level", "+" .. t.levels, t.levels == 1 and "Level" or "Levels") end
    if (t.quests or 0) > 0 then add("tasks", tostring(t.quests), t.quests == 1 and "Task done" or "Tasks done") end
    if (t.deaths or 0) > 0 then add("falls", tostring(t.deaths), t.deaths == 1 and "Fall" or "Falls") end
    local net = (t.earned or 0) - (t.spent or 0)
    if (t.earned or 0) + (t.spent or 0) > 0 then
        add(net >= 0 and "gain" or "loss", (net >= 0 and "+" or "-") .. ShortCoins(math.abs(net)), net >= 0 and "Earned" or "Spent")
    end
    if (t.found or 0) > 0 then add("found", tostring(t.found), "Places found") end
    if (t.finds or 0) > 0 then add("finds", tostring(t.finds), t.finds == 1 and "Find" or "Finds") end
    if (t.company or 0) > 0 then add("company", tostring(t.company), "Companions") end
    return out
end

local function DayStamps(day)
    local s = day.stats
    local with = {}
    local company = 0
    for _, e in ipairs(day.events) do
        for _, name in ipairs(e.group or {}) do
            if not with[name] then with[name], company = true, company + 1 end
        end
    end
    return Stamps({ played = s.played, kills = s.kills, deaths = s.deaths, quests = s.quests,
        levels = math.max(0, (s.levelTo or 1) - (s.levelFrom or 1)),
        earned = s.money and s.money.earned, spent = s.money and s.money.spent,
        found = #J.Events(day, "discover"), finds = #J.Events(day, "loot", "create"), company = company })
end

local function DayContent(key)
    local day = J.Day(key) or EMPTY
    local s, zones = day.stats, J.Zones(day)
    local paras, meta = J.Write(key, day)
    meta = meta or { starts = {} }
    local c = {
        title = J.DayTitle(key),
        sub = Join({ zones[1] and (BK.Names({ unpack(zones, 1, math.min(3, #zones)) })
            .. (#zones > 3 and (" and " .. (#zones - 3) .. " more") or "")),
            s.played > 0 and (J.Played(s.played) .. " on the road"), J.Grew(day) }, "  \194\183  "),
        paras = paras, pinned = {}, signature = J.Signature(), ledger = {}, sections = {},
        stamps = DayStamps(day), stampsTitle = "The Day in Numbers",
    }
    c.plates = Plates(day, meta, paras)
    local used = {}
    for i, text in ipairs(paras) do
        -- (a picture told instead: no notes beside it)
        c.pinned[i] = c.plates[i] and {} or i == meta.summary and Closing(day) or Moments(day, meta, i, text, used)
    end
    return c
end

local function SummaryContent()
    local keys = J.Days()
    local total = { played = 0, kills = 0, deaths = 0, quests = 0, earned = 0, spent = 0, levels = 0 }
    for _, key in ipairs(keys) do
        local s = (J.Day(key) or EMPTY).stats
        total.played = total.played + (s.played or 0)
        total.kills = total.kills + (s.kills or 0)
        total.deaths = total.deaths + (s.deaths or 0)
        total.quests = total.quests + (s.quests or 0)
        total.levels = total.levels + math.max(0, (s.levelTo or 1) - (s.levelFrom or 1))
        total.earned = total.earned + (s.money and s.money.earned or 0)
        total.spent = total.spent + (s.money and s.money.spent or 0)
    end
    local c = {
        title = UnitName("player") or "",
        sub = Join({ Join({ UnitRace("player"), UnitClass("player") }, " "),
            #keys > 0 and (Plural(#keys, "day", "days") .. " written since " .. J.DayTitle(keys[#keys], true)) or "Nothing written yet" },
            "  \194\183  "),
        paras = { J.Summary(keys) }, ledger = {}, sections = {}, notes = {},
        stampsTitle = "The Road So Far",
    }
    total.days = #keys
    c.stamps = Stamps(total)
    return c
end

local function PersonContent(name)
    local p = J.People and J.People.Get(name) or {}
    local keys, lines = {}, {}
    for key in pairs(p.days or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return a > b end)
    for _, key in ipairs(keys) do
        if J.Day(key) then
            lines[#lines + 1] = { kind = "day", key = key, round = true, icon = JB.DAY_ICON, name = J.DayTitle(key),
                line = J.DayLine(J.Day(key)) }
        end
    end
    return {
        title = name,
        sub = Join({ Join({ p.race, p.class }, " "), p.guild and ("\226\128\185" .. p.guild .. "\226\128\186"),
            p.dayCount and (Plural(p.dayCount, "day", "days") .. " met") }, "  \194\183  "),
        paras = J.PersonStory(name), ledger = {}, notes = {},
        sections = #lines > 0 and { { title = "Days We Met", lines = lines } } or {},
    }
end

local function Content(it)
    if not it or it.kind == "top" then return SummaryContent() end
    if it.kind == "day" then return DayContent(it.key) end
    if it.kind == "person" then return PersonContent(it.person) end
    return nil
end

-- (what the page shows: the picked row's, or the last day / person picked
-- while a banner or month is)
local function PageItem()
    local it = W.items and W.items[W.sel]
    if it and (it.kind == "day" or it.kind == "person" or it.kind == "top") then
        W.shown = it
    end
    return W.shown
end

local function LinkLine(b, line)
    local name, sub, icon = line.name, line.line, line.icon
    if line.item then
        local n, q = ItemName(line.item)
        name = n and ((BK.QUALITY_INK[q or 1] or "") .. n .. "|r") or line.name or ("Item " .. line.item)
        sub = line.line or (line.describe and BK.ItemKind(line.item)) or nil
        icon = ItemIcon(line.item)
    elseif line.getName then
        name = line.getName(line)
    end
    if type(icon) == "string" and icon:find("^atlas:") then
        b.icon:SetAtlas(icon:sub(7))
        b.icon:SetTexCoord(0, 1, 0, 1)
    else
        b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    BK.Script(b.name, name or "", "GameFontNormal", "GameFontNormal")
    b.sub:SetText(sub or "")
end

-- A stamp at the page's foot: a seal of ink, its picture in it, the
-- number under it and what it counts; it thumps onto the page
local STAMP_W, STAMP_H, STAMPS_ACROSS = math.floor(TEXT_W / 4), 96, 4
local stamps = Pool(function()
    local f = K.NewFrame("Frame", nil, body)
    f:SetSize(STAMP_W, STAMP_H)
    local function Round(size, layer, sub)
        local t = f:CreateTexture(nil, layer, nil, sub)
        t:SetSize(size, size)
        t:SetPoint("TOP", f, "TOP", 0, -(52 - size) / 2)
        if f.CreateMaskTexture then
            local m = f:CreateMaskTexture()
            m:SetTexture(SEAL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(t)
            t:AddMaskTexture(m)
        end
        return t
    end
    f.ring = Round(52, "ARTWORK", 0)
    f.ring:SetColorTexture(ACCENT_RGB[1], ACCENT_RGB[2], ACCENT_RGB[3], 0.75)
    f.fill = Round(47, "ARTWORK", 1)
    f.fill:SetColorTexture(0.93, 0.86, 0.7, 1)
    f.inner = Round(43, "ARTWORK", 2)
    f.inner:SetColorTexture(ACCENT_RGB[1], ACCENT_RGB[2], ACCENT_RGB[3], 0.35)
    f.icon = Round(40, "ARTWORK", 3)
    f.value = Ink(f:CreateFontString(nil, "ARTWORK"), HEADING_FONT, 19, INK)
    f.value:SetPoint("TOP", f, "TOP", 0, -56)
    f.value:SetWidth(STAMP_W - 6)
    f.value:SetWordWrap(false)
    f.label = Ink(f:CreateFontString(nil, "ARTWORK"), BODY_FONT, 10, INK)
    f.label:SetPoint("TOP", f.value, "BOTTOM", 0, -2)
    f.label:SetAlpha(0.7)
    f.thump = f:CreateAnimationGroup()
    f.thump:SetToFinalAlpha(true)
    local fade = f.thump:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.12)
    local press = f.thump:CreateAnimation("Scale")
    if press.SetScaleFrom then
        press:SetScaleFrom(1.6, 1.6)
        press:SetScaleTo(1, 1)
    elseif press.SetFromScale then
        press:SetFromScale(1.6, 1.6)
        press:SetToScale(1, 1)
    end
    press:SetDuration(0.2)
    press:SetSmoothing("IN")
    f.thumpParts = { fade, press }
    return f
end)

-- The words laid out by hand, a line at a time, round what's pasted on the
-- page: each line in the widest gap the notes leave at its height (none
-- wide enough: on under them). A name's ink carried over a line's end.
local LINE_H, NOTE_GAP, LEAST, INDENT = 23, 18, 110, 24
local BODY_SIZE = 16
local lines = Pool(function()
    local fs = body:CreateFontString(nil, "ARTWORK")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end)
-- (the notebook's lines under the words)
local rules = Pool(function()
    local t = body:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetColorTexture(0.32, 0.22, 0.12, 0.14)
    t:SetHeight(1)
    return t
end)
local margin = body:CreateTexture(nil, "BACKGROUND", nil, 2)
margin:SetColorTexture(0.7, 0.18, 0.12, 0.22)
margin:SetWidth(1)
-- (drops of blood on the page, by a fall)
local blots = Pool(function()
    local t = body:CreateTexture(nil, "BACKGROUND", nil, 3)
    t:SetTexture(SEAL_MASK)
    return t
end)
local measure = body:CreateFontString(nil, "ARTWORK")
measure:Hide()
local widths, measured = {}, nil
local function Width(word, font, size)
    local key = font .. size
    if measured ~= key then
        measured = key
        pcall(measure.SetFont, measure, font, size, "")
    end
    local k = key .. word
    local w = widths[k]
    if not w then
        measure:SetText(word)
        w = measure:GetStringWidth()
        widths[k] = w
    end
    return w
end

-- The free stretch of a line at y, given the notes: x, width (nil: none,
-- and where the notes beside it end)
local function Gap(y, placed)
    local free = { { 0, TEXT_W } }
    local under
    for _, r in ipairs(placed) do
        if r.y1 < y + LINE_H and r.y2 > y then
            under = under and math.min(under, r.y2) or r.y2
            local out = {}
            for _, g in ipairs(free) do
                if r.x2 <= g[1] or r.x1 >= g[2] then out[#out + 1] = g
                else
                    if r.x1 > g[1] then out[#out + 1] = { g[1], r.x1 } end
                    if r.x2 < g[2] then out[#out + 1] = { r.x2, g[2] } end
                end
            end
            free = out
        end
    end
    local best
    for _, g in ipairs(free) do
        if not best or g[2] - g[1] > best[2] - best[1] then best = g end
    end
    if best and best[2] - best[1] >= LEAST then return best[1], best[2] - best[1] end
    return nil, under
end

-- (a y on the notebook's lines: the first at top)
local function Snap(y, top)
    return top + math.ceil((y - top) / LINE_H - 0.001) * LINE_H
end

-- Words written from y, on the lines (top: the first), round the notes;
-- opts = { font, size, color, indent (the first line's) }; where they end
local function Flow(text, y, placed, top, opts)
    local font, size, color = opts.font or HAND_FONT, opts.size or BODY_SIZE, opts.color or HAND_INK
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    local space = Width("a a", font, size) - Width("aa", font, size)
    local ink                       -- (the colour open at a line's start)
    local i, first = 1, true
    while i <= #words do
        local x, width = Gap(y, placed)
        if not x then
            y = Snap(width and math.max(width, y + 1) or (y + LINE_H), top)
        else
            if first and opts.indent then x, width = x + opts.indent, width - opts.indent end
            first = false
            local parts, used, start = {}, 0, ink
            while i <= #words do
                local word = words[i]
                local ww = Width(word, font, size)
                local add = (#parts > 0 and space or 0) + ww
                if #parts > 0 and used + add > width then break end
                parts[#parts + 1] = word
                used = used + add
                -- (the ink open after it: its last colour, unless closed)
                for code in word:gmatch("|[cr]%x*") do
                    ink = code:sub(2, 2) == "c" and code:sub(1, 10) or nil
                end
                i = i + 1
            end
            local fs = lines:Next()
            Ink(fs, font, size, color)
            fs:ClearAllPoints()
            -- (sitting on the line: its foot a little over the rule)
            fs:SetPoint("BOTTOMLEFT", body, "TOPLEFT", x, -(y + LINE_H - 4))
            fs:SetWidth(width + 8)
            fs:SetText((start or "") .. table.concat(parts, " ") .. (ink and "|r" or ""))
            y = y + LINE_H
        end
    end
    return y
end

local plates, FillPlate
do
    -- A plate: the map's piece printed on a card glued across the page, as
    -- Social Diary's are. Aged photo stock, lighter than the page; the art
    -- in a double rule of ink; its edges darker, as an old print's; a soft
    -- shadow on the page to its right and below; folded kraft photo corners.
    -- On it the road in red-brown dashes and a mark at each stop (a paper
    -- halo, a ring of ink, its number; a fall a cross on a dot of paper).
    -- Under it a slip for each stop, cut from cream paper, a graphite leader
    -- from it up to its mark, bowing a little, ending in a pencil dot short of
    -- it; the caption under them
    local PLATE_W = TEXT_W - 30
    local PLATE_H = 236
    local CARD_PAD = 9                       -- the stock round the art
    local SLIP_W, SLIP_GAP = 150, 14
    local STOCK = { 0.90, 0.85, 0.70 }
    local KRAFT = { 0.29, 0.19, 0.105 }
    local SLIP_PAPER = { 0.95, 0.91, 0.79 }
    local ROAD = { 0.5, 0.18, 0.1, 0.9 }
    local GRAPHITE = { 0.27, 0.26, 0.24, 0.85 }
    local PAPER_DOT = { 0.96, 0.93, 0.83 }
    local GRAIN = "Interface\\Stationery\\StationeryTest1"
    local TRI = IF.TEX .. "ic_tri"

    -- A band of shade: from `a` at one end to nothing at the other
    local function Fade(t, dir, r, g, b, a, flip)
        t:SetColorTexture(1, 1, 1, 1)
        local from, to = CreateColor and CreateColor(r, g, b, a), CreateColor and CreateColor(r, g, b, 0)
        if flip then from, to = to, from end
        if not (from and t.SetGradient and pcall(t.SetGradient, t, dir, from, to)) then t:SetColorTexture(r, g, b, a / 2) end
    end

    plates = Pool(function()
        local f = K.NewFrame("Frame", nil, body)
        f:SetSize(TEXT_W, PLATE_H)
        -- (its shadow on the page: bands along its right and bottom)
        f.shadowR = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.shadowB = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.contact = f:CreateTexture(nil, "BACKGROUND", nil, -6)
        f.stock = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        f.grain = f:CreateTexture(nil, "BACKGROUND", nil, -4)
        f.clip = K.NewFrame("Frame", nil, f)
        if f.clip.SetClipsChildren then f.clip:SetClipsChildren(true) end
        f.clip.tiles = {}
        -- (over the art: the old print's darker edges)
        f.vig = {}
        for i = 1, 4 do f.vig[i] = f.clip:CreateTexture(nil, "OVERLAY", nil, 2) end
        f.ink = K.NewFrame("Frame", nil, f)
        f.ink:SetAllPoints()
        f.ink:SetFrameLevel(f.clip:GetFrameLevel() + 3)
        f.rules = {}
        for i = 1, 8 do f.rules[i] = f.ink:CreateTexture(nil, "ARTWORK", nil, 0) end
        f.corners = {}
        for c = 1, 4 do f.corners[c] = f.ink:CreateTexture(nil, "ARTWORK", nil, 1) end
        f.lines, f.marks, f.slips, f.dots = {}, {}, {}, {}
        f.caption = Ink(f.ink:CreateFontString(nil, "OVERLAY"), HAND_BOLD, 17, HAND_INK)
        f.caption:SetJustifyH("LEFT")
        f.note = Ink(f.ink:CreateFontString(nil, "OVERLAY"), HAND_FONT, 15, RUBRIC)
        f.note:SetJustifyH("LEFT")
        return f
    end)

    -- A line of ink on the plate (n: its number among them)
    local function PlateLine(f, n, x1, y1, x2, y2, color, thick, layer)
        local l = f.lines[n]
        if not l then
            l = f.ink:CreateLine(nil, "OVERLAY", nil, 0)
            f.lines[n] = l
        end
        l:SetDrawLayer("OVERLAY", layer or 0)
        l:SetThickness(thick)
        l:SetColorTexture(color[1], color[2], color[3], color[4])
        l:SetStartPoint("TOPLEFT", f, x1, -y1)
        l:SetEndPoint("TOPLEFT", f, x2, -y2)
        l:Show()
    end

    -- A dot (a disc) on the plate
    local function PlateDot(f, n, x, y, size, color, alpha, sub)
        local d = f.dots[n]
        if not d then
            d = f.ink:CreateTexture(nil, "OVERLAY")
            d:SetTexture(SEAL_MASK)
            f.dots[n] = d
        end
        d:SetDrawLayer("OVERLAY", sub or 3)
        d:SetVertexColor(color[1], color[2], color[3], alpha or 1)
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("CENTER", f, "TOPLEFT", x, -y)
        d:Show()
    end

    -- A mark's number, in ink
    local function PlateNumber(f, n, x, y, text)
        local fs = f.marks[n]
        if not fs then
            fs = Ink(f.ink:CreateFontString(nil, "OVERLAY"), HAND_BOLD, 12, HAND_INK)
            f.marks[n] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", f, "TOPLEFT", x + 0.5, -y)
        fs:SetText(text)
        fs:Show()
    end

    -- A slip under the plate, cut from cream paper: its number, its words;
    -- its height
    local function PlateSlip(f, n, x, y, num, words, red)
        local s = f.slips[n]
        if not s then
            s = {}
            s.shadow = f.ink:CreateTexture(nil, "ARTWORK", nil, 2)
            s.edge = f.ink:CreateTexture(nil, "ARTWORK", nil, 3)
            s.paper = f.ink:CreateTexture(nil, "ARTWORK", nil, 4)
            s.grain = f.ink:CreateTexture(nil, "ARTWORK", nil, 5)
            s.num = Ink(f.ink:CreateFontString(nil, "OVERLAY"), HAND_BOLD, 15, RUBRIC)
            s.text = Ink(f.ink:CreateFontString(nil, "OVERLAY"), HAND_FONT, 14, HAND_INK)
            s.text:SetJustifyH("LEFT")
            f.slips[n] = s
        end
        s.num:ClearAllPoints()
        s.num:SetPoint("TOPLEFT", f, "TOPLEFT", x + 8, -(y + 5))
        s.num:SetText(num .. ".")
        s.text:ClearAllPoints()
        s.text:SetPoint("TOPLEFT", f, "TOPLEFT", x + 26, -(y + 6))
        s.text:SetWidth(SLIP_W - 33)
        s.text:SetText(words)
        if red then s.text:SetTextColor(RUBRIC[1], RUBRIC[2], RUBRIC[3]) else s.text:SetTextColor(HAND_INK[1], HAND_INK[2], HAND_INK[3]) end
        local h = math.ceil(s.text:GetStringHeight()) + 12
        -- (turned a little, as a slip is pasted: at most 1.4 degrees)
        local a = math.rad(((n * 37 + num * 11) % 9 - 4) * 0.35)
        local cx, cy = x + SLIP_W / 2, y + h / 2
        local function Lay(t, dx, dy, w, hh)
            t:ClearAllPoints()
            t:SetPoint("CENTER", f, "TOPLEFT", cx + dx, -(cy + dy))
            t:SetSize(w, hh)
            t:SetRotation(a)
            t:Show()
        end
        s.shadow:SetColorTexture(0.12, 0.07, 0.02, 0.4)
        Lay(s.shadow, 0.8, 1, SLIP_W, h)
        s.edge:SetColorTexture(HAND_INK[1], HAND_INK[2], HAND_INK[3], 0.16)
        Lay(s.edge, 0, 0, SLIP_W + 1, h + 1)
        s.paper:SetColorTexture(SLIP_PAPER[1], SLIP_PAPER[2], SLIP_PAPER[3], 1)
        Lay(s.paper, 0, 0, SLIP_W, h)
        s.grain:SetTexture(GRAIN)
        s.grain:SetVertexColor(1, 1, 1, 0.12)
        Lay(s.grain, 0, 0, SLIP_W, h)
        s.num:Show(); s.text:Show()
        return h
    end

    local function HidePlateParts(f)
        for _, l in ipairs(f.lines) do l:Hide() end
        for _, m in ipairs(f.marks) do m:Hide() end
        for _, d in ipairs(f.dots) do d:Hide() end
        for _, s in ipairs(f.slips) do s.shadow:Hide(); s.edge:Hide(); s.paper:Hide(); s.grain:Hide(); s.num:Hide(); s.text:Hide() end
    end

    -- A graphite leader from a slip up to its mark: a gentle bow, a pencil
    -- dot a little short of the mark; the next line's number after it
    local function Leader(f, nl, sx, sy, mx, my)
        local dx, dy = mx - sx, my - sy
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 12 then return nl end
        -- (short of the mark by 9)
        local ex, ey = mx - dx / len * 9, my - dy / len * 9
        -- (bowed: a bend 6% of its length to one side)
        local kx, ky = (sx + ex) / 2 - dy / len * len * 0.06, (sy + ey) / 2 + dx / len * len * 0.06
        local steps = 8
        local px, py = sx, sy
        for k = 1, steps do
            local t = k / steps
            local qx = (1 - t) ^ 2 * sx + 2 * (1 - t) * t * kx + t * t * ex
            local qy = (1 - t) ^ 2 * sy + 2 * (1 - t) * t * ky + t * t * ey
            nl = nl + 1
            -- (the pen thinner toward its end)
            PlateLine(f, nl, px, py, qx, qy, GRAPHITE, 1.7 - 0.6 * t, 1)
            px, py = qx, qy
        end
        f.dotN = f.dotN + 1
        PlateDot(f, f.dotN, ex, ey, 3.6, GRAPHITE, 0.9, 2)
        return nl
    end

    -- The map's window over a box of it (x1..y2, 0-1), padded, widened to the
    -- plate's shape, kept on the map
    local function BoxWindow(layer, box, w, h)
        local LW, LH = layer.layerWidth, layer.layerHeight
        local bx0, by0 = (box[1] - 0.05) * LW, (box[2] - 0.06) * LH
        local bx1, by1 = (box[3] + 0.05) * LW, (box[4] + 0.06) * LH
        local ww, wh = bx1 - bx0, by1 - by0
        if ww / wh < w / h then ww = wh * w / h else wh = ww * h / w end
        ww, wh = math.min(ww, LW), math.min(wh, LH)
        if ww / wh > w / h then ww = wh * w / h else wh = ww * h / w end
        local cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
        local x0 = math.max(0, math.min(LW - ww, cx - ww / 2))
        local y0 = math.max(0, math.min(LH - wh, cy - wh / 2))
        return x0, y0, x0 + ww, y0 + wh, function(x, y) return (x * LW - x0) * w / ww, (y * LH - y0) * h / wh end
    end

    -- A plate laid out from p (PlateFor's); its height (nil: no art)
    function FillPlate(f, p, seed)
        HidePlateParts(f)
        f.dotN = 0
        local layer, pieces = MapPieces(p.map)
        if not layer then return nil end
        local cx0 = (TEXT_W - PLATE_W) / 2 - CARD_PAD
        local ax, ay = cx0 + CARD_PAD, 6 + CARD_PAD
        local cw, ch = PLATE_W + 2 * CARD_PAD, PLATE_H + 2 * CARD_PAD
        -- The card: its stock and grain, its shadow on the page
        f.stock:SetColorTexture(STOCK[1], STOCK[2], STOCK[3], 1)
        f.stock:ClearAllPoints()
        f.stock:SetPoint("TOPLEFT", f, "TOPLEFT", cx0, -6)
        f.stock:SetSize(cw, ch)
        f.grain:SetTexture(GRAIN)
        f.grain:SetVertexColor(1, 1, 1, 0.14)
        f.grain:SetAllPoints(f.stock)
        f.contact:SetColorTexture(0.12, 0.07, 0.02, 0.4)
        f.contact:ClearAllPoints()
        f.contact:SetPoint("TOPLEFT", f.stock, "TOPLEFT", 1.5, -1.5)
        f.contact:SetSize(cw, ch)
        Fade(f.shadowR, "HORIZONTAL", 0.12, 0.07, 0.02, 0.28)
        f.shadowR:ClearAllPoints()
        f.shadowR:SetPoint("TOPLEFT", f.stock, "TOPRIGHT", 0, -6)
        f.shadowR:SetSize(5, ch)
        Fade(f.shadowB, "VERTICAL", 0.12, 0.07, 0.02, 0.28, true)
        f.shadowB:ClearAllPoints()
        f.shadowB:SetPoint("TOPLEFT", f.stock, "BOTTOMLEFT", 6, 0)
        f.shadowB:SetSize(cw, 5)
        -- The art
        f.clip:ClearAllPoints()
        f.clip:SetPoint("TOPLEFT", f, "TOPLEFT", ax, -ay)
        f.clip:SetSize(PLATE_W, PLATE_H)
        local x0, y0, x1, y1, At = BoxWindow(layer, p.box, PLATE_W, PLATE_H)
        PrintMap(f.clip, layer, pieces, x0, y0, x1, y1, PLATE_W, PLATE_H)
        -- (its edges darker, the bottom and right more: away from the light)
        local depth = math.floor(math.min(PLATE_W, PLATE_H) * 0.14)
        local V = { 0.3, 0.2, 0.08 }
        local sides = {
            { "TOPLEFT", "TOPRIGHT", nil, depth, "VERTICAL", 0.22, false },
            { "BOTTOMLEFT", "BOTTOMRIGHT", nil, depth, "VERTICAL", 0.32, true },
            { "TOPLEFT", "BOTTOMLEFT", depth, nil, "HORIZONTAL", 0.22, true },
            { "TOPRIGHT", "BOTTOMRIGHT", depth, nil, "HORIZONTAL", 0.32, false },
        }
        for i, sd in ipairs(sides) do
            local t = f.vig[i]
            t:ClearAllPoints()
            t:SetPoint(sd[1], f.clip, sd[1])
            t:SetPoint(sd[2], f.clip, sd[2])
            if sd[3] then t:SetWidth(sd[3]) else t:SetHeight(sd[4]) end
            -- (top: dark at the top; bottom: dark at the bottom; ...)
            Fade(t, sd[5], V[1], V[2], V[3], sd[6], (i == 1) or (i == 3))
            t:Show()
        end
        -- (the double rule round it: a line hugging it, a gap, a hairline)
        local function Rule(i, inset, thick)
            local l, r, t, b = ax - inset, ax + PLATE_W + inset, ay - inset, ay + PLATE_H + inset
            local parts = {
                { l, t, r - l, thick }, { l, b - thick, r - l, thick }, { l, t, thick, b - t }, { r - thick, t, thick, b - t },
            }
            for k, pr in ipairs(parts) do
                local tex = f.rules[(i - 1) * 4 + k]
                tex:SetColorTexture(HAND_INK[1], HAND_INK[2], HAND_INK[3], 0.65)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", f, "TOPLEFT", pr[1], -pr[2])
                tex:SetSize(pr[3], pr[4])
                tex:Show()
            end
        end
        Rule(1, 1.5, 1.5)
        Rule(2, 4.5, 1)
        -- (folded kraft photo corners over the card's)
        local pts = { { cx0, 6, 0 }, { cx0 + cw, 6, -90 }, { cx0 + cw, 6 + ch, 180 }, { cx0, 6 + ch, 90 } }
        for c, pt in ipairs(pts) do
            local corner = f.corners[c]
            corner:SetTexture(TRI)
            local shade = 0.92 + ((seed + c) % 3) * 0.06
            corner:SetVertexColor(KRAFT[1] * shade, KRAFT[2] * shade, KRAFT[3] * shade, 0.95)
            corner:SetSize(26, 26)
            corner:ClearAllPoints()
            -- (the triangle's right angle into the corner: ic_tri points up)
            local inX = (c == 1 or c == 4) and 1 or -1
            local inY = (c == 1 or c == 2) and 1 or -1
            corner:SetPoint("CENTER", f, "TOPLEFT", pt[1] + inX * 5.5, -(pt[2] + inY * 5.5))
            corner:SetRotation(math.rad(({ 135, 225, 315, 45 })[c]))
            corner:Show()
        end
        -- Where each stop falls on the plate
        local spots = {}
        for n, st in ipairs(p.stops) do
            local x, y = At(st.x, st.y)
            spots[n] = { ax + math.max(12, math.min(PLATE_W - 12, x)), ay + math.max(12, math.min(PLATE_H - 12, y)) }
        end
        -- The road: red-brown dashes, 5 long, 4 apart, from stop to stop,
        -- clear of the marks
        local nl = 0
        for n = 2, #spots do
            local sx, sy, ex, ey = spots[n - 1][1], spots[n - 1][2], spots[n][1], spots[n][2]
            local len = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)
            if len > 20 then
                local ux, uy = (ex - sx) / len, (ey - sy) / len
                local d = 11
                while d + 5 < len - 11 and nl < 140 do
                    nl = nl + 1
                    PlateLine(f, nl, sx + ux * d, sy + uy * d, sx + ux * (d + 5), sy + uy * (d + 5), ROAD, 1.5, 0)
                    d = d + 9
                end
            end
        end
        -- The slips under the plate, as many across as fit, each with its
        -- leader up to its mark
        local across = math.max(1, math.floor((TEXT_W + SLIP_GAP) / (SLIP_W + SLIP_GAP)))
        local y = 6 + ch + 24
        local rowH = 0
        local count = #p.stops
        -- (a slip's column under the mark nearest it, left to right: the
        -- leaders less likely to cross)
        local order = {}
        for n = 1, count do order[n] = n end
        for n, st in ipairs(p.stops) do
            local col = (n - 1) % across
            if n > 1 and col == 0 then
                y = y + rowH + 10
                rowH = 0
            end
            local inRow = math.min(across, count - (n - 1 - col))
            local x = (TEXT_W - (inRow * SLIP_W + (inRow - 1) * SLIP_GAP)) / 2 + col * (SLIP_W + SLIP_GAP)
            local words, red = StopWords(st)
            local h = PlateSlip(f, n, x, y, n, words or "", red)
            rowH = math.max(rowH, h)
            nl = Leader(f, nl, x + SLIP_W / 2, y + 1, spots[n][1], spots[n][2])
        end
        -- The marks over all: a paper halo, a ring of ink, its number; a fall
        -- a cross on a dot of paper
        local nm = 0
        for n, pt in ipairs(spots) do
            local x, y2 = pt[1], pt[2]
            if p.stops[n].k == "death" then
                f.dotN = f.dotN + 1
                PlateDot(f, f.dotN, x, y2, 14, PAPER_DOT, 1, 3)
                nl = nl + 1
                PlateLine(f, nl, x - 4, y2 - 4, x + 4, y2 + 4, { RUBRIC[1], RUBRIC[2], RUBRIC[3], 1 }, 2, 5)
                nl = nl + 1
                PlateLine(f, nl, x - 4, y2 + 4, x + 4, y2 - 4, { RUBRIC[1], RUBRIC[2], RUBRIC[3], 1 }, 2, 5)
            else
                f.dotN = f.dotN + 1
                PlateDot(f, f.dotN, x, y2, 21, PAPER_DOT, 0.75, 3)
                f.dotN = f.dotN + 1
                PlateDot(f, f.dotN, x, y2, 17, HAND_INK, 0.9, 4)
                f.dotN = f.dotN + 1
                PlateDot(f, f.dotN, x, y2, 14, PAPER_DOT, 1, 5)
                nm = nm + 1
                PlateNumber(f, nm, x, y2, n)
            end
        end
        y = y + rowH + 12
        f.caption:ClearAllPoints()
        f.caption:SetPoint("TOPLEFT", f, "TOPLEFT", cx0 + 2, -y)
        f.caption:SetWidth(TEXT_W - cx0)
        f.caption:SetText(p.caption or "")
        y = y + math.ceil(f.caption:GetStringHeight())
        f.note:SetShown(p.note ~= nil)
        if p.note then
            f.note:ClearAllPoints()
            f.note:SetPoint("TOPLEFT", f, "TOPLEFT", cx0 + 2, -(y + 1))
            f.note:SetText(p.note)
            y = y + 1 + math.ceil(f.note:GetStringHeight())
        end
        local h = y + 8
        f:SetHeight(h)
        return h
    end
end

-- How wide a note is pasted: a map's piece widest, a slip narrowest
local function NoteWidth(n)
    if n.mark == "coin" then return 180 end
    if n.mark then return 150 end
    if n.map then return n.zoom == 1 and 260 or 240 end
    if n.photo then return 186 end
    if n.quote then return 210 end
    if n.display or n.tally then return 214 end
    return 196
end

function W.RenderPage()
    local it = PageItem()
    local key = it and (it.key or "") or "summary"
    -- (another page: back to its top, its notes pasted in again)
    local fresh = W.pageKey ~= key
    if fresh then
        W.pageKey = key
        W.link = 1
        pageScroll:SetVerticalScroll(0)
    end
    local c = Content(it) or SummaryContent()
    W.content = c
    title:SetText(c.title or "")
    subtitle:SetText(c.sub or "")
    paragraphs:Reset(); headings:Reset(); ledgers:Reset(); links:Reset(); notes:Reset(); lines:Reset(); stamps:Reset()
    rules:Reset(); blots:Reset(); plates:Reset()
    local y = 8
    W.linkRows = {}
    local function Para(text, x, width, alpha, justify)
        local fs = paragraphs:Next()
        fs:SetWidth(width)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetAlpha(alpha or 1)
        fs:SetText(text)
        return math.ceil(fs:GetStringHeight())
    end
    -- What I wrote, its notes pasted in among the words: each where its
    -- paragraph begins (a line into it), on one side then the other, never
    -- beside another; the words go round them, line by line
    local placed, side, below = {}, "left", 0
    local top = y
    for i, text in ipairs(c.paras or {}) do
        -- (a stretch told as a picture, across the page, on the next line
        -- clear of the notes)
        local plate = c.plates and c.plates[i]
        local pf = plate and plates:Next()
        local ph = pf and FillPlate(pf, plate, i)
        if pf and not ph then pf:Hide() end
        if ph then
            local at = Snap(math.max(y, below + 14), top) + 6
            pf:ClearAllPoints()
            pf:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -at)
            y = Snap(at + ph + 10, top)
            below = y
        end
        for k, n in ipairs(not ph and c.pinned and c.pinned[i] or {}) do
            side = side == "right" and "left" or "right"
            local w = NoteWidth(n)
            -- (a little off the edge, as a hand would paste it)
            local nudge = (i * 7 + k * 5) % 13
            local f = notes:Next()
            local h = FillNote(f, n, w, i * 3 + k)
            local noteTop = math.max(y + LINE_H, below + 14)
            local x = side == "left" and nudge or (TEXT_W - w - nudge)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", body, "TOPLEFT", x, -noteTop)
            f.bodyTop = noteTop
            placed[#placed + 1] = { x1 = x - NOTE_GAP, x2 = x + w + NOTE_GAP, y1 = noteTop - 6, y2 = noteTop + h + NOTE_GAP }
            below = noteTop + h
            if n.blood then
                -- (drops of it on the page by it, toward the words)
                for b = 1, 6 do
                    local t = blots:Next()
                    local r = ((i * 31 + b * 17) % 100) / 100
                    local size = 3 + (b * 7 + i) % 9
                    t:SetVertexColor(0.48, 0.03, 0.02, 0.45 + r * 0.3)
                    t:SetSize(size, size)
                    t:ClearAllPoints()
                    local bx = side == "left" and (x + w + 6 + r * 30) or (x - 6 - r * 30)
                    t:SetPoint("CENTER", body, "TOPLEFT", bx, -(noteTop + h * (0.2 + ((b * 23) % 100) / 140)))
                end
            end
        end
        if not ph then y = Flow(text, y, placed, top, { indent = INDENT }) end
    end
    y = math.max(y, below + 16)
    -- (the notebook's lines, from the first to the last written on; a red
    -- margin down their left)
    if #(c.paras or {}) > 0 then
        local last = Snap(y, top)
        for ly = top + LINE_H, last, LINE_H do
            local r = rules:Next()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", body, "TOPLEFT", -10, -(ly - 1))
            r:SetPoint("TOPRIGHT", body, "TOPLEFT", TEXT_W + 6, -(ly - 1))
        end
        margin:ClearAllPoints()
        margin:SetPoint("TOPLEFT", body, "TOPLEFT", -14, -(top - 4))
        margin:SetHeight(last - top + 4)
        margin:Show()
        y = last + 8
    else
        margin:Hide()
    end
    if c.signature then y = y + Para(c.signature, 0, TEXT_W, 0.75, "RIGHT") + 12 end
    -- The stamps at its foot, four across, each row centred
    if #(c.stamps or {}) > 0 then
        local h = headings:Next()
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 6))
        h.text:SetText(c.stampsTitle or "")
        h.info:SetText("")
        y = y + 48
        local n = #c.stamps
        for i, st in ipairs(c.stamps) do
            local row, col = math.floor((i - 1) / STAMPS_ACROSS), (i - 1) % STAMPS_ACROSS
            local across = math.min(STAMPS_ACROSS, n - row * STAMPS_ACROSS)
            local f = stamps:Next()
            f.icon:SetTexture(st.icon)
            f.icon:SetVertexColor(1, 0.92, 0.78)
            f.value:SetText(st.value)
            f.label:SetText(st.label:upper())
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", body, "TOPLEFT", (TEXT_W - across * STAMP_W) / 2 + col * STAMP_W, -(y + row * STAMP_H))
        end
        y = y + math.ceil(n / STAMPS_ACROSS) * STAMP_H + 6
    end
    -- (the journal's first page: its notes two across)
    if #(c.notes or {}) > 0 then
        y = y + 8
        local col = { y, y }
        for _, n in ipairs(c.notes) do
            local f = notes:Next()
            local i = col[1] <= col[2] and 1 or 2
            local h = FillNote(f, n, NOTE_W, #c.notes + i)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", body, "TOPLEFT", (i - 1) * (NOTE_W + 18) + 2, -(col[i] + 6))
            f.bodyTop = col[i] + 6
            col[i] = col[i] + h + 20
        end
        y = math.max(col[1], col[2]) + 4
    end
    -- The ledger
    if #(c.ledger or {}) > 0 then
        local h = headings:Next()
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        h.text:SetText("Where the Time Went")
        h.info:SetText("")
        y = y + 36
        for _, l in ipairs(c.ledger) do
            local f = ledgers:Next()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -y)
            BK.Script(f.name, l[1], "GameFontNormal", "GameFontNormal")
            f.value:SetText(l[2])
            y = y + 20
        end
        y = y + 10
    end
    -- The lists
    for _, sec in ipairs(c.sections or {}) do
        local h = headings:Next()
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        h.text:SetText(sec.title)
        h.info:SetText("")
        y = y + 36
        for _, line in ipairs(sec.lines) do
            if line.header then
                y = y + 2
                Para(line.header:upper() .. "  \194\183  " .. (line.info or ""), 8, TEXT_W - 8, 0.7)
                y = y + 20
            else
                local b = links:Next()
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
                b.link = line
                LinkLine(b, line)
                b.top, b.bottom = y, y + 32
                W.linkRows[#W.linkRows + 1] = b
                b.index = #W.linkRows
                y = y + 34
            end
        end
        y = y + 8
    end
    paragraphs:HideRest(); headings:HideRest(); ledgers:HideRest(); links:HideRest(); notes:HideRest(); lines:HideRest()
    stamps:HideRest(); rules:HideRest(); blots:HideRest(); plates:HideRest()
    body:SetHeight(y + 20)
    pageThumb:Update()
    if fresh then
        for i = 1, notes.used do
            local f = notes.list[i]
            f.drop:Stop()
            f:SetAlpha(0)
            for _, part in ipairs(f.dropParts) do part:SetStartDelay(0.15 + 0.12 * (i - 1)) end
            f.drop:Play()
        end
        for i = 1, stamps.used do
            local f = stamps.list[i]
            f.thump:Stop()
            f:SetAlpha(0)
            for _, part in ipairs(f.thumpParts) do part:SetStartDelay(0.3 + 0.12 * notes.used + 0.08 * (i - 1)) end
            f.thump:Play()
        end
    end
    W.ClipModels()
    W.LightLinks()
end

-- The foes' models only while all of them is in sight: a model isn't cut
-- by the scroll, and drew over the title and the frame
function W.ClipModels()
    local top, view = pageScroll:GetVerticalScroll(), pageScroll:GetHeight()
    for i = 1, notes.used do
        local f = notes.list[i]
        if f.model and f.modelY then
            local a = (f.bodyTop or 0) + f.modelY
            f.model:SetShown(a >= top - 2 and a + (f.modelH or MODEL_H) <= top + view + 2)
        end
    end
end

-- The page's entries lit: the pad's on one while it's on the page
function W.LightLinks()
    local pad, onPage = IF.Input.Pad(), W.where == "page" and W.focus == "ours"
    W.link = math.max(1, math.min(W.link, #(W.linkRows or {})))
    for i, b in ipairs(W.linkRows or {}) do
        b.ring:Light(pad and onPage and i == W.link)
    end
end

local function ShowLink(i)
    local b = W.linkRows and W.linkRows[i]
    if not b then return end
    local top, view = pageScroll:GetVerticalScroll(), pageScroll:GetHeight()
    local max = math.max(0, body:GetHeight() - view)
    if b.top - 40 < top then
        pageScroll:SetVerticalScroll(math.max(0, b.top - 40))
    elseif b.bottom + 20 > top + view then
        pageScroll:SetVerticalScroll(math.min(max, b.bottom + 20 - view))
    end
    pageThumb:Update()
end

---------------------------------------------------------------------------
-- Away to the map or the Wiki: the window steps aside, back once it's shut
---------------------------------------------------------------------------
local away = nil
local hooked = {}

local function Resume()
    if not away then return end
    away = nil
    if IF.InCombat() then return end
    W.Show(true)
end

local function Away(frame)
    if frame and frame.HookScript and not hooked[frame] then
        hooked[frame] = true
        frame:HookScript("OnHide", function() if away == frame then Resume() end end)
    end
    away = frame
    W.suspending = true
    window:Hide()
    W.suspending = nil
end

local function ShowMap(map, x, y)
    if IF.InCombat() or not map then return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    if not (OpenWorldMap and WorldMapFrame) then return end
    if x and y and UiMapPoint and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    Away(WorldMapFrame)
    OpenWorldMap(map)
end

local function WikiPage(line)
    local LB = IF.Wiki
    if not (LB and LB.Page) then return nil end
    if line.kind == "quest" then return LB.Page("quest", line.id) end
    if line.kind == "npc" then return LB.Page("npc", line.id) end
    if line.item then return LB.Page("item", line.item) end
end

local function Verb(line)
    if not line then return nil end
    if line.kind == "day" then return "Read" end
    if (line.kind == "zone" or line.kind == "death") and line.map then return "Show on Map" end
    if IF.Wiki and IF.Wiki.Page and (line.kind == "quest" or line.kind == "npc" or line.item) then return "Open" end
end

function W.ActivateLink(line)
    if not line then return end
    if line.kind == "day" then return W.Select(line.key) end
    if line.kind == "zone" or line.kind == "death" then return ShowMap(line.map, line.x, line.y) end
    local p = WikiPage(line)
    local LB = IF.Wiki
    if p and LB.book then
        Sound("IG_ABILITY_PAGE_TURN")
        Away(LB.book.window)
        LB.book:Open(p)
    end
end

-- A tooltip for an entry (an item's)
function W.Tip(owner, line)
    if not (line and line.item) then return GameTooltip:Hide() end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(line.item) end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- The legend, the pad
---------------------------------------------------------------------------
local legend = IF.InputLegend(window)
legend:SetPoint("TOP", window, "BOTTOM", 0, -4)
legend.row:ClearAllPoints()
legend.row:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 10)

local switch
local hintSets = {}
local function SetHints(defs)
    local key = {}
    for _, d in ipairs(defs) do key[#key + 1] = tostring(d[1]) .. "=" .. tostring(d[3]) end
    key = table.concat(key, "|")
    hintSets[key] = hintSets[key] or defs
    legend:Set(hintSets[key])
end

local function Hints()
    local defs = {}
    if W.where == "page" then
        local line = W.linkRows and W.linkRows[W.link] and W.linkRows[W.link].link
        local verb = Verb(line)
        if verb then defs[#defs + 1] = { "PAD1", "A", verb, pad = true } end
    else
        local it = W.items and W.items[W.sel]
        local verb = it and ((it.kind == "banner" or it.kind == "card") and (it.open and "Close" or "Open")
            or (it.kind == "day" or it.kind == "person" or it.kind == "top") and #(W.linkRows or {}) > 0 and "Entries")
        if verb then defs[#defs + 1] = { "PAD1", "A", verb, pad = true } end
    end
    defs[#defs + 1] = { { "PADLSHOULDER", "PADRSHOULDER" }, { "LB", "RB" }, "Scroll", pad = true }
    local hint = switch and switch:Hint()
    if hint then defs[#defs + 1] = hint end
    defs[#defs + 1] = { "PAD2", "B", W.where == "page" and "Back" or "Close", pad = true }
    return defs
end

function W.Render()
    if not window:IsShown() then return end
    who:SetText(Join({ UnitName("player"), Join({ UnitRace("player"), UnitClass("player") }, " ") }, "  \194\183  "))
    W.RenderTree()
    W.RenderPage()
    local focused = W.focus == "ours"
    IF.Focus.Glow(window, focused)
    if focused and IF.Input.Pad() then SetHints(Hints()) else legend:Hide() end
    -- (the pad on an item: its tooltip)
    if focused and IF.Input.Pad() and W.where == "page" then
        local b = W.linkRows and W.linkRows[W.link]
        if b and b.link and b.link.item then W.Tip(b, b.link) else GameTooltip:Hide() end
    end
end

-- A row's fold opened or shut
local function Fold(it, open)
    if not it or not (it.kind == "banner" or it.kind == "card") then return false end
    if (W.opened[it.key] and true or false) == open then return false end
    W.opened[it.key] = open or nil
    Sound(open and "IG_QUEST_LOG_OPEN" or "IG_QUEST_LOG_CLOSE")
    return true
end

-- The picked row moved to (its page shown)
local function Pick(i)
    if not W.items or not W.items[i] then return end
    if i ~= W.sel then Sound("IG_MAINMENU_OPTION_CHECKBOX_ON") end
    W.sel = i
    W.Render()
    ShowRow(i)
end

-- The mouse on a row: a fold opens or shuts, a day / person shown
function W.Click(index)
    local it = W.items and W.items[index]
    if not it then return end
    W.where = "tree"
    W.sel = index
    if it.kind == "banner" or it.kind == "card" then Fold(it, not it.open) end
    W.Render()
end

-- A day picked, its year and month opened (a companion's days)
function W.Select(key)
    if not key then return end
    local y, m = key:match("^(%d+)-(%d+)")
    if y then
        W.opened["y" .. y] = true
        W.opened["m" .. y .. "-" .. m] = true
    end
    W.where = "tree"
    W.items = Tree()
    for i, it in ipairs(W.items) do
        if it.key == key then W.sel = i end
    end
    W.Render()
    ShowRow(W.sel)
end

local function Move(dir)
    if W.where == "page" then
        local n = #(W.linkRows or {})
        if n == 0 then return ScrollBy(pageScroll, body, dir * SCROLL_STEP) end
        local i = math.max(1, math.min(n, W.link + dir))
        if i ~= W.link then
            W.link = i
            Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            ShowLink(i)
            W.Render()
        end
        return
    end
    Pick(math.max(1, math.min(#(W.items or {}), W.sel + dir)))
end

local function IntoPage()
    if #(W.linkRows or {}) == 0 then return end
    W.where = "page"
    W.link = math.max(1, math.min(W.link, #W.linkRows))
    Sound("IG_ABILITY_PAGE_TURN")
    ShowLink(W.link)
    W.Render()
end

local function Back()
    if W.where == "page" then
        W.where = "tree"
        GameTooltip:Hide()
        Sound("IG_ABILITY_PAGE_TURN")
        return W.Render()
    end
    W.Close()
end

local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
    PADLTRIGGER = "LT", PADRTRIGGER = "RT",
}

function W.Press(name, down)
    -- (Circle on its release: closing on the press hands the release to
    -- the window under it)
    if name == "B" then
        if not down then
            if W.skipRelease then W.skipRelease = nil return end
            Back()
        end
        return
    end
    if not down then return end
    local it = W.items and W.items[W.sel]
    if name == "UP" then Move(-1)
    elseif name == "DOWN" then Move(1)
    elseif name == "LB" then ScrollBy(pageScroll, body, -pageScroll:GetHeight() * 0.8) pageThumb:Update()
    elseif name == "RB" then ScrollBy(pageScroll, body, pageScroll:GetHeight() * 0.8) pageThumb:Update()
    elseif name == "LT" or name == "RT" then switch:Press(name)
    elseif W.where == "page" then
        if name == "A" then
            local b = W.linkRows and W.linkRows[W.link]
            if b then W.ActivateLink(b.link) end
        elseif name == "LEFT" then Back()
        end
    elseif name == "RIGHT" then
        if Fold(it, true) then W.Render() else IntoPage() end
    elseif name == "LEFT" then
        if Fold(it, false) then return W.Render() end
        -- (to the row holding it)
        local nest = it and it.nest or 0
        if nest > 0 then
            for i = W.sel - 1, 1, -1 do
                if (W.items[i].nest or 0) < nest then return Pick(i) end
            end
        end
    elseif name == "A" then
        if it and (it.kind == "banner" or it.kind == "card") then
            Fold(it, not it.open)
            W.Render()
            ShowRow(W.sel)
        else
            IntoPage()
        end
    end
end

local catcher = K.NewFrame("Frame", nil, window)
catcher:SetAllPoints(window)
if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        if KEYS[button] then W.Press(KEYS[button], true) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        if KEYS[button] then W.Press(KEYS[button], false) end
    end)
    -- (setting the handler turns the frame's input on: off until wanted)
    catcher:EnableGamePadButton(false)
end
legend:SetPress(catcher)

local function TakePad(on)
    if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

-- Escape: back from the page, else shut (on its release, as Circle)
local escape = K.NewFrame("Button", "ImprovedForeverJournalEscape")
escape:RegisterForClicks("AnyUp")
escape:SetScript("OnClick", function() Back() end)

local function BindEscape(on)
    if IF.InCombat() then return end
    ClearOverrideBindings(window)
    if on then SetOverrideBindingClick(window, true, "ESCAPE", escape:GetName()) end
end

-- Placed as the game's own panels, along the top beside what's open
IF.Focus.Dock(window)

switch = IF.Focus.Switch(window, {
    onChange = function(focus)
        local ours = focus == "ours"
        W.focus = ours and "ours" or "game"
        TakePad(ours)
        BindEscape(ours)
        IF.Focus.DimNative(window, ours)
        if not ours then GameTooltip:Hide() end
        W.Render()
    end,
})

window:SetScript("OnUpdate", function() switch:Update() end)
IF.Input.OnChange(function() W.Render() end)

listScroll:SetScript("OnMouseWheel", function(_, delta)
    ScrollBy(listScroll, listChild, -delta * SCROLL_STEP)
    listThumb:Update()
end)
pageScroll:HookScript("OnVerticalScroll", function() W.ClipModels() end)
pageScroll:SetScript("OnMouseWheel", function(_, delta)
    ScrollBy(pageScroll, body, -delta * SCROLL_STEP)
    pageThumb:Update()
end)

-- Shown (back from the map or the Wiki: as it was left)
function W.Show(resumed)
    if IF.InCombat() then return end
    switch.focus, W.focus = "ours", "ours"
    if not window:IsShown() and not resumed then Sound("IG_SPELLBOOK_OPEN") end
    window:Show()
    TakePad(true)
    BindEscape(true)
    IF.Focus.DimNative(window, true)
    W.skipRelease = resumed and IsKeyDown and IsKeyDown("PAD2") or nil
    W.Render()
    ShowRow(W.sel)
end

function W.Close()
    if window:IsShown() then Sound("IG_SPELLBOOK_CLOSE") end
    away = nil
    window:Hide()
end

window:SetScript("OnHide", function()
    TakePad(false)
    BindEscape(false)
    IF.Focus.DimNative(window, false)
    IF.Focus.Glow(window, false)
    legend:Hide()
    GameTooltip:Hide()
    if not W.suspending then away = nil end
end)

if window.CloseButton then window.CloseButton:SetScript("OnClick", function() W.Close() end) end

---------------------------------------------------------------------------
-- Opened: on a day ("YYYY-MM-DD"), else the newest
---------------------------------------------------------------------------
function JB.Open(key)
    if IF.InCombat() then return IF.Print("Not in combat.") end
    W.where = "tree"
    key = key or J.Days()[1]
    if key then
        W.Show()
        W.Select(key)
    else
        W.sel = 1
        W.Show()
    end
end

function JB.Toggle()
    if window:IsShown() then return W.Close() end
    JB.Open()
end

-- (today, as it goes on: drawn again while it's read, once a moment)
local pending = false
local function Redraw()
    if not window:IsShown() or pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        W.Render()
    end)
end
J.OnChange(Redraw)

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if window:IsShown() then W.Close() end
        return
    end
    Redraw()
end)

-- The press that opens it: a key binding, a wheel's or the touchpad's
-- (the core's windows of ours, Actions.lua)
IF.Actions.PressButton("ImprovedForeverJournalToggle", function() JB.Toggle() end)
_G["BINDING_NAME_CLICK ImprovedForeverJournalToggle:LeftButton"] = "Toggle Journal"
