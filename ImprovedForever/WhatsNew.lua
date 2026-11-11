-- What's new: when a module has been updated since you last saw it, a tour of
-- what changed, in the look of Immersion's first-time tour (Onboarding.lua):
-- a gold rule standing, one small diamond on it with the page's picture, the
-- pages' names left of it, and under the last one a diamond button that
-- reveals the next; the page's words (and, when a module gives one, an
-- example) in the middle of the screen. Click the right side or the diamond,
-- or A, to reveal more; up / down (the D-pad) pick; Close, B or Esc end it.
-- * The pages live here, in WhatsNewData.lua, per module and version
--   (IF.WhatsNew.Add); a module may add a live example of its own by key
--   (IF.WhatsNew.Example(key, build(stageFrame))).
-- * What each module was last seen at is IF.db.whatsNew[module]. A first
--   install (IF.freshInstall) shows nothing: the versions are just noted, as
--   for a module installed later. An update from before this existed (no
--   record yet) shows each module's latest pages once. Several updated
--   modules are shown one after another.
-- * /if whatsnew [module] plays it again (the module's latest pages).
-- The pad is taken by a catcher frame only while the tour is up (not in a
-- fight).
local IF = ImprovedForever

local WN = {}
IF.WhatsNew = WN

local START_DELAY = 8                   -- (seconds after login, then once out of a fight)
local NEXT_DELAY = 1.2                  -- (between two modules' tours)
local FADE = 0.35

-- (the panel, and in it: the list's rule, the right side)
local W, H = 1200, 540
local RIGHT_W = 500
local RULE_X = W / 2 - RIGHT_W / 2 - 70
local RULE_TOP, RULE_BOTTOM = 90, 470
local LIST_TOP, LIST_BOTTOM = 190, 440
local STAGE_W, STAGE_H = RIGHT_W, 240
local STAGE_Y = H / 2 - STAGE_H / 2
local WORDS_Y = STAGE_Y + STAGE_H + 12
local TILE = 30
local ROW_MAX = 38                      -- (a row's most height: few pages are not spread wide)

local GOLD = { 1, 0.82, 0.45 }
local GREY = { 0.5, 0.5, 0.5 }
local TILE_TURN, ROOT2 = math.pi / 4, math.sqrt(2)

-- (Morpheus has Latin letters only: a Russian, Korean or Chinese client gets
-- the game's own font)
local locale = GetLocale()
local LATIN = not (locale == "ruRU" or locale == "koKR" or locale == "zhCN" or locale == "zhTW")
local FONT = LATIN and "Fonts\\MORPHEUS.TTF" or STANDARD_TEXT_FONT
local NAME_SIZE, SMALL_SIZE = 30, 13
local RULE_W, RULE_Y, NAME_GAP = 260, 130, 30

---------------------------------------------------------------------------
-- The data: WN.data[module] = { { version, title?, pages }, ... }
---------------------------------------------------------------------------
WN.data = {}
WN.examples = {}

-- module: "Core" or the module's name ("Immersion"); def.pages: { name, icon,
-- lines = { first, second }, example? = key }
function WN.Add(module, version, def)
    local list = WN.data[module] or {}
    WN.data[module] = list
    list[#list + 1] = { version = version, pages = def.pages }
end

function WN.Example(key, build)
    WN.examples[key] = build
end

local function Folder(module)
    return module == "Core" and "ImprovedForever" or ("ImprovedForever_" .. module)
end

local function Title(module)
    if module == "Core" then return "Improved Forever" end
    local A = _G.C_AddOns
    local title = A and A.GetAddOnMetadata and A.GetAddOnMetadata(Folder(module), "Title")
    return title and title:gsub("^Improved Forever:%s*", "") or module
end

local function Installed(module)
    local A = _G.C_AddOns
    if not (A and A.GetAddOnMetadata) then return nil end
    if module ~= "Core" and A.IsAddOnLoaded and not A.IsAddOnLoaded(Folder(module)) then return nil end
    return A.GetAddOnMetadata(Folder(module), "Version")
end

-- ("0.11.0-beta1" -> 0, 11, 0)
local function Parts(version)
    local a, b, c = tostring(version or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- (1: a is newer than b, -1: older, 0: the same)
local function Compare(a, b)
    local a1, a2, a3 = Parts(a)
    local b1, b2, b3 = Parts(b)
    if a1 ~= b1 then return a1 > b1 and 1 or -1 end
    if a2 ~= b2 then return a2 > b2 and 1 or -1 end
    if a3 ~= b3 then return a3 > b3 and 1 or -1 end
    return 0
end

-- The pages of a module's versions in (seen, now], the newest version first
-- (all of the latest when `seen` is nil)
local function PagesFor(module, seen, now)
    local versions = {}
    for _, v in ipairs(WN.data[module] or {}) do
        if (not seen or Compare(v.version, seen) > 0) and (not now or Compare(v.version, now) <= 0) then
            versions[#versions + 1] = v
        end
    end
    table.sort(versions, function(a, b) return Compare(a.version, b.version) > 0 end)
    if not seen then versions = { versions[1] } end
    local pages = {}
    for _, v in ipairs(versions) do
        for _, p in ipairs(v.pages) do pages[#pages + 1] = p end
    end
    return pages, versions[1] and versions[1].version
end

---------------------------------------------------------------------------
-- Drawing helpers (Immersion's header look, as the tour draws it)
---------------------------------------------------------------------------
local function Text(parent, font, size, r, g, b)
    local s = parent:CreateFontString(nil, "ARTWORK", nil, 0)
    if not (font and s:SetFont(font, size, "")) then s:SetFont(STANDARD_TEXT_FONT, size, "") end
    s:SetTextColor(r, g, b)
    s:SetShadowOffset(1, -1)
    s:SetShadowColor(0, 0, 0, 1)
    s:SetWordWrap(false)
    return s
end

local function Ease(x, a, b)
    local t = math.min(1, math.max(0, (x - (a or 0)) / ((b or 1) - (a or 0))))
    return t * t * (3 - 2 * t)
end

-- (the spell diamonds' tile: the game's square slot turned, a picture cut to
-- the diamond)
local function Tile(parent, size)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetSize(size, size)
    tile:SetPoint("CENTER")
    local side = size * 1.2
    tile.side, tile.across = side, side * ROOT2
    local bg = tile:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("gamepad-actionbar-squareslot-bg")
    bg:SetPoint("CENTER")
    bg:SetSize(side, side)
    bg:SetRotation(TILE_TURN)
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    local mask = tile:CreateMaskTexture()
    mask:SetAtlas("progress-bar-diamond-pip-mask")
    mask:SetPoint("CENTER")
    mask:SetSize(tile.across * 0.94, tile.across * 0.94)
    icon:AddMaskTexture(mask)
    local border = tile:CreateTexture(nil, "OVERLAY")
    border:SetAtlas("gamepad-actionbar-squareslot-border-normal")
    border:SetPoint("CENTER")
    border:SetSize(size * 64 / 46, size * 64 / 46)
    border:SetRotation(TILE_TURN)
    tile.icon, tile.bg, tile.mask, tile.border = icon, bg, mask, border
    return tile
end

-- A gold rule, fading out at both ends
local function Rule(parent, length)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, length)
    local function Color(a) return CreateColor(GOLD[1], GOLD[2], GOLD[3], a) end
    for _, first in ipairs({ true, false }) do
        local r = f:CreateTexture(nil, "ARTWORK")
        r:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        r:SetSize(1, length / 2)
        r:SetPoint(first and "BOTTOM" or "TOP", f, "CENTER")
        -- (vertical gradients run from the bottom to the top)
        local ok = pcall(r.SetGradient, r, "VERTICAL", first and Color(0.8) or Color(0), first and Color(0) or Color(0.8))
        if not ok then r:SetAlpha(0.6) end
    end
    return f
end

local bodyFont = GameFontHighlight and GameFontHighlight:GetFont()

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local root = CreateFrame("Frame", "ImprovedForeverWhatsNew", UIParent)
root:SetSize(W, H)
root:SetFrameStrata("HIGH")
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:EnableMouse(true)
root:Hide()

local sideRule = Rule(root, RULE_BOTTOM - RULE_TOP)
sideRule:SetPoint("TOP", root, "TOPLEFT", RULE_X, -RULE_TOP)

-- (the current tour)
local PAGES = {}
local rows = {}
local page, shownAt, goal = 1, nil, 0
local reached = 1
local broken
local Go
local tour                              -- { module, version }

local function RowY(i)
    local step = math.min(ROW_MAX, (LIST_BOTTOM - LIST_TOP) / math.max(#PAGES, 1))
    return LIST_TOP + (i - 0.5) * step
end

local function Row(i)
    local row = CreateFrame("Button", nil, root)
    row:SetSize(RULE_X - 60, 30)
    row.name = Text(row, bodyFont, 16, GREY[1], GREY[2], GREY[3])
    row.name:SetAllPoints()
    row.name:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", function(self) self.hover = true end)
    row:SetScript("OnLeave", function(self) self.hover = nil end)
    row:SetScript("OnClick", function() Go(i) end)
    rows[i] = row
end

-- (the current page's picture in a diamond on the rule, above the names)
local mark = Tile(root, TILE)
mark:ClearAllPoints()
mark:SetFrameLevel(sideRule:GetFrameLevel() + 5)
mark.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
mark.icon:SetSize(mark.across, mark.across)

-- (the reveal button: a diamond on the rule where the next name will be)
local more = CreateFrame("Button", nil, root)
more:SetSize(TILE, TILE)
more:SetFrameLevel(sideRule:GetFrameLevel() + 5)
local moreTile = Tile(more, TILE - 6)
moreTile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
moreTile.icon:SetColorTexture(0.6, 0.38, 0.05, 1)
moreTile.icon:SetSize(moreTile.across, moreTile.across)
local ARROW = "LevelUp-Icon-Arrow"
if IF.HasAtlas and IF.HasAtlas(ARROW) then
    local arrow = moreTile:CreateTexture(nil, "OVERLAY", nil, 2)
    arrow:SetSize(moreTile.across * 0.5 * 30 / 34, moreTile.across * 0.5)
    arrow:SetPoint("CENTER", moreTile, "CENTER", 0, -1)
    arrow:SetColorTexture(1, 1, 1, 1)
    local cut = moreTile:CreateMaskTexture()
    cut:SetAtlas(ARROW)
    cut:SetAllPoints(arrow)
    cut:SetRotation(math.pi)
    arrow:AddMaskTexture(cut)
else
    local v = Text(moreTile, FONT, 18, 1, 1, 1)
    v:SetDrawLayer("OVERLAY", 2)
    v:SetPoint("CENTER", moreTile, "CENTER", 0, 1)
    v:SetText("v")
end
local moreGlow = moreTile:CreateTexture(nil, "OVERLAY", nil, 3)
moreGlow:SetAtlas("gamepad-actionbar-squareslot-border-normal")
moreGlow:SetPoint("CENTER")
moreGlow:SetRotation(TILE_TURN)
moreGlow:SetBlendMode("ADD")
moreGlow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
more:SetScript("OnEnter", function() moreTile.border:SetVertexColor(1, 1, 1) end)
more:SetScript("OnLeave", function() moreTile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end)
local moreKey = Text(root, bodyFont, 14, 1, 1, 1)
local browse = Text(root, bodyFont, 14, 1, 1, 1)
browse:SetJustifyH("RIGHT")

---------------------------------------------------------------------------
-- The right side: the example (the middle of the screen), the words
---------------------------------------------------------------------------
local right = CreateFrame("Frame", nil, root)
right:SetSize(RIGHT_W, H)
right:SetPoint("TOP", root, "TOP", 0, 0)
right:EnableMouse(true)

local line1 = Text(right, bodyFont, SMALL_SIZE, 1, 1, 1)
line1:SetWidth(RIGHT_W + 60)
local line2 = Text(right, bodyFont, SMALL_SIZE, 1, 0.82, 0)
line2:SetWidth(RIGHT_W + 60)
line2:SetPoint("TOP", line1, "BOTTOM", 0, -4)

local stage = CreateFrame("Frame", nil, right)
stage:SetSize(STAGE_W, STAGE_H)
stage:SetPoint("TOP", right, "TOP", 0, -STAGE_Y)
local built = {}                        -- (an example's frame, built when first wanted)

-- (a page's example, or nothing: its words then sit where the stage is)
local function ShowExample(key)
    for k, f in pairs(built) do f:SetShown(k == key) end
    if key and not built[key] and WN.examples[key] then
        local f = CreateFrame("Frame", nil, stage)
        f:SetAllPoints()
        built[key] = f
        local ok, err = pcall(WN.examples[key], f)
        if not ok then
            local s = Text(f, bodyFont, 12, 1, 0.4, 0.4)
            s:SetPoint("CENTER")
            s:SetText("(example not drawn: " .. tostring(err):sub(1, 90) .. ")")
        end
    end
    return key and built[key] ~= nil
end

local function Word(size, r, g, b, glyph)
    local btn = CreateFrame("Button", nil, root)
    btn:SetHeight(size + 8)
    btn.text = Text(btn, bodyFont, size, r, g, b)
    btn.text:SetPoint("LEFT")
    btn.color = { r, g, b }
    btn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function(self) self.text:SetTextColor(self.color[1], self.color[2], self.color[3]) end)
    function btn:Set(word)
        self.text:SetText((IF.Input.Pad() and (IF.GlyphText(glyph, size) .. " ") or "") .. word)
        self:SetWidth(self.text:GetStringWidth())
    end
    return btn
end
local closeButton = Word(17, 0.7, 0.7, 0.7, "PAD2")

local hasExample
local function Layout()
    local pad = IF.Input.Pad()
    moreKey:SetText(pad and IF.GlyphText("PAD1", 18) or "")
    browse:SetText(pad and (IF.GlyphText("DPAD_UD", 18) .. " Browse") or "")
    browse:ClearAllPoints()
    browse:SetPoint("TOPRIGHT", root, "TOPLEFT", RULE_X - 52, -(RowY(#PAGES) + 30))
    closeButton:Set(pad and "Close" or "Close  (Esc)")
    local wordsY = hasExample and WORDS_Y or (STAGE_Y + STAGE_H / 2 - 30)
    line1:ClearAllPoints()
    line1:SetPoint("TOP", right, "TOP", 0, -wordsY)
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPLEFT", root, "TOP", -closeButton:GetWidth() / 2, -(wordsY + 58))
end

---------------------------------------------------------------------------
-- The name at the top (the header's: big in Morpheus, a small line under it)
---------------------------------------------------------------------------
local head = CreateFrame("Frame", nil, UIParent)
head:SetSize(2 * RULE_W, 80)
head:SetFrameStrata("LOW")
head:EnableMouse(false)
head:SetPoint("TOP", UIParent, "TOP", 0, -(RULE_Y + NAME_GAP - 20))
head:Hide()
local headName = Text(head, FONT, NAME_SIZE, GOLD[1], GOLD[2], GOLD[3])
headName:SetWidth(2 * RULE_W)
headName:SetPoint("TOP")
local headSmall = Text(head, bodyFont, SMALL_SIZE, 1, 1, 1)
headSmall:SetWidth(2.2 * RULE_W)
headSmall:SetPoint("TOP", headName, "BOTTOM", 0, -4)

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
local escape = CreateFrame("Frame", "ImprovedForeverWhatsNewEscape", UIParent)
escape:Hide()
IF.Focus.EscapeClose(escape)

local queue = {}
local StartNext

local function Finish()
    goal = 0
    page = 1
    -- (seen: this version is noted, so the module's next update shows again)
    if tour and IF.db and tour.version then
        IF.db.whatsNew = IF.db.whatsNew or {}
        local now = Installed(tour.module)
        IF.db.whatsNew[tour.module] = now or tour.version
    end
    escape:Hide()
    if #queue > 0 then C_Timer.After(NEXT_DELAY, StartNext) end
end

function Go(n)
    if n > #PAGES then return Finish() end
    if n < 1 then return end
    local changed = n ~= page or not shownAt
    page, shownAt = n, GetTime()
    reached = math.max(reached, n)
    local p = PAGES[n]
    mark.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_Note_01")
    hasExample = ShowExample(p.example)
    Layout()
    line1:SetText(p.lines and p.lines[1] or "")
    line2:SetText(p.lines and p.lines[2] or "")
    if changed and goal == 1 then PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_SELECT or 856) end
end

local function Press(key)
    if goal ~= 1 then return end
    if key == "PAD1" then
        if reached < #PAGES then Go(reached + 1) end
    elseif key == "UP" then
        if page > 1 then Go(page - 1) end
    elseif key == "DOWN" then
        if page < reached then Go(page + 1) end
    elseif key == "PAD2" then
        Finish()
    end
end
more:SetScript("OnClick", function() Press("PAD1") end)
closeButton:SetScript("OnClick", function() Press("PAD2") end)
right:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then Press("PAD1") end
end)

---------------------------------------------------------------------------
-- The pad: taken only while it is up
---------------------------------------------------------------------------
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetScript("OnGamePadButtonDown", function(_, button)
    if button == "PAD1" then Press(button) end
    if button == "PADDUP" then Press("UP") end
    if button == "PADDDOWN" then Press("DOWN") end
end)
catcher:SetScript("OnGamePadButtonUp", function(_, button)
    if button == "PAD2" then Press(button) end
end)
-- (a gamepad handler turns the frame's input on by itself: off until it is
-- wanted, else it takes the pad from login)
catcher:EnableGamePadButton(false)
IF.OnLogin(function()
    IF.Input.OnChange(function() if goal == 1 then Layout() end end)
end)

escape:SetScript("OnHide", function()
    if goal == 1 then Finish() end
end)

local taking
local function TakePad(on)
    if taking == on or not catcher.EnableGamePadButton then return end
    if IF.InCombat() then return end
    taking = on
    catcher:EnableGamePadButton(on)
end

---------------------------------------------------------------------------
-- Drawn
---------------------------------------------------------------------------
local presence = 0

local function Step(elapsed)
    local want = goal == 1 and not IF.InCombat()
    if goal == 0 then presence = 0 end
    presence = want and math.min(1, presence + elapsed / FADE) or math.max(0, presence - elapsed / FADE)
    TakePad(want and presence >= 0.5)
    if presence <= 0 then
        root:Hide()
        head:Hide()
        return
    end
    head:Show()
    head:SetAlpha(Ease(presence, 0, 1))
    if not root:IsShown() then root:Show() end
    if want and not escape:IsShown() then escape:Show() end
    root:SetAlpha(Ease(presence, 0, 1))
    local now = GetTime()
    local words = shownAt and Ease(now - shownAt, 0, 0.35) or 1
    for _, s in ipairs({ line1, line2 }) do s:SetAlpha(words) end
    stage:SetAlpha(0.35 + 0.65 * words)
    -- (the picture's diamond sits above the first name)
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", root, "TOPLEFT", RULE_X, -(RowY(1) - 44))
    local nextSlot = reached + 1
    local beat = (now % 1.2) / 1.2
    more:SetShown(nextSlot <= #PAGES)
    if nextSlot <= #PAGES then
        more:ClearAllPoints()
        more:SetPoint("CENTER", root, "TOPLEFT", RULE_X, -RowY(nextSlot) + 4 * math.sin(now * 5))
        local size = (TILE - 6) * 64 / 46 * (1 + 0.8 * beat)
        moreGlow:SetSize(size, size)
        moreGlow:SetAlpha(0.95 * (1 - beat) ^ 1.3)
        moreTile:SetScale(1 + 0.06 * math.sin(now * 5))
        moreKey:ClearAllPoints()
        moreKey:SetPoint("LEFT", more, "RIGHT", 10, 0)
    end
    moreKey:SetShown(nextSlot <= #PAGES)
    for i, row in ipairs(rows) do
        local on = i == page
        local c = on and GOLD or (row.hover and { 1, 1, 1 } or GREY)
        row.name:SetTextColor(c[1], c[2], c[3])
        row.name:SetAlpha(i < reached and 1 or (i == reached and (i == page and words or 1) or 0))
        row:EnableMouse(i <= reached)
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then
        broken, goal = true, 0
        root:Hide()
        head:Hide()
        escape:Hide()
        TakePad(false)
        IF.Print("What's new: the tour stopped after an error: " .. tostring(err))
    end
end)

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------
-- A tour of `pages` for a module, from the first page
local function Start(module, pages, version, seen)
    broken = nil
    PAGES = pages
    for i, p in ipairs(PAGES) do
        if not rows[i] then Row(i) end
        rows[i].name:SetText(p.name or "")
        rows[i]:ClearAllPoints()
        rows[i]:SetPoint("RIGHT", root, "TOPLEFT", RULE_X - 52, -RowY(i))
        rows[i]:Show()
    end
    for i = #PAGES + 1, #rows do rows[i]:Hide() end
    tour = { module = module, version = version }
    headName:SetText(Title(module))
    headSmall:SetText(seen and ("What's new since " .. seen .. ": version " .. tostring(version))
        or ("What's new in version " .. tostring(version)))
    goal = 1
    shownAt = nil
    reached = 1
    local ok, err = pcall(Go, 1)
    if not ok then
        goal = 0
        IF.Print("What's new: the tour could not start: " .. tostring(err))
    end
end

function StartNext()
    local item = table.remove(queue, 1)
    if not item then return end
    if IF.InCombat() or UnitIsDeadOrGhost("player") or goal == 1 then
        table.insert(queue, 1, item)
        return C_Timer.After(5, StartNext)
    end
    Start(item.module, item.pages, item.version, item.seen)
end

-- Modules updated since they were last seen
local function Pending()
    local db = IF.db
    local first = db.whatsNew == nil
    db.whatsNew = db.whatsNew or {}
    local found = {}
    local modules = {}
    for module in pairs(WN.data) do modules[#modules + 1] = module end
    table.sort(modules, function(a, b)
        if a == "Core" or b == "Core" then return a == "Core" end
        return a < b
    end)
    for _, module in ipairs(modules) do
        local now = Installed(module)
        local seen = db.whatsNew[module]
        if now then
            if first and not IF.freshInstall then
                -- (an update from before this existed: its latest pages, once)
                local pages, version = PagesFor(module, nil, now)
                if #pages > 0 then
                    found[#found + 1] = { module = module, pages = pages, version = version }
                else
                    db.whatsNew[module] = now
                end
            elseif first or not seen then
                -- (a first install, or a module installed later: nothing to show)
                db.whatsNew[module] = now
            elseif Compare(now, seen) > 0 then
                local pages, version = PagesFor(module, seen, now)
                if #pages > 0 then
                    found[#found + 1] = { module = module, pages = pages, version = version, seen = seen }
                else
                    db.whatsNew[module] = now
                end
            end
        end
    end
    return found
end

IF.OnLogin(function()
    C_Timer.After(START_DELAY, function()
        queue = Pending()
        StartNext()
    end)
end)

-- /if whatsnew [module]: a module's latest pages again (Core's by default,
-- else the first with pages)
IF.AddCommand("whatsnew", function(args)
    local want = args and args[1]
    local module
    for name in pairs(WN.data) do
        if want and name:lower() == want:lower() then module = name end
    end
    if not module and not want then module = WN.data.Core and "Core" or next(WN.data) end
    if not module then
        local names = {}
        for name in pairs(WN.data) do names[#names + 1] = name end
        table.sort(names)
        IF.Print("What's new: " .. (want and ("no pages for \"" .. want .. "\"") or "no pages")
            .. ". Modules with pages: " .. table.concat(names, ", "))
        return
    end
    local pages, version = PagesFor(module, nil, Installed(module))
    if #pages == 0 then pages, version = PagesFor(module) end
    if #pages == 0 then return IF.Print("What's new: no pages for " .. module) end
    queue = {}
    Start(module, pages, version)
end, "[module]: play a module's what's new tour again")
