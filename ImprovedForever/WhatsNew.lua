-- What's new: when a module has been updated since you last saw it, a tour of
-- what changed, in the look of Immersion's sidebar cards (Card.lua,
-- QuestPeek.lua): at the screen's top left on the NPC dialog's dark band,
-- the module's name in Morpheus, then a card for each page, one under
-- another: the spell diamond with the page's picture, a gold line running
-- down from it, the page's name and two lines to the right. The cards play
-- in as the quest cards do, one after another, all of them shown; up / down
-- (the D-pad) pick one (a module's example of it, when it gave one, to the
-- right); the game's button legend under them: Close, B or Esc end it.
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
local FADE = 0.35

-- (the sidebar's cards, as Immersion's Card.lua has them)
local CARD_BEAT = 0.25                 -- (seconds between one card starting and the next)
local IN_TIME = 0.6                     -- (seconds a card takes to play in)
local ROW_SLIDE = 12                    -- (each line comes in from this far left)
local PAD_Y, STACK_GAP = 6, 14
local TILE = 24
local TEXT_W = 380
local PANEL_W = 46 + TEXT_W
local CORNER_X = 40
local BAND_ALPHA, BAND_REACH = 0.6, 40
local STAGE_W, STAGE_H = 500, 240

local GOLD = { 1, 0.82, 0.45 }
local GREY = { 0.5, 0.5, 0.5 }
local TILE_TURN, ROOT2 = math.pi / 4, math.sqrt(2)

-- (Morpheus has Latin letters only: a Russian, Korean or Chinese client gets
-- the game's own font)
local locale = GetLocale()
local LATIN = not (locale == "ruRU" or locale == "koKR" or locale == "zhCN" or locale == "zhTW")
local FONT = LATIN and "Fonts\\MORPHEUS.TTF" or STANDARD_TEXT_FONT
local NAME_SIZE, SMALL_SIZE = 30, 13

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

-- The pages of a module's versions in (seen, now], the newest version first;
-- with no `seen`: only the latest version's, or every version's with `all`
-- (a player with no version tracked). Each page tagged with its version.
local function PagesFor(module, seen, now, all)
    local versions = {}
    for _, v in ipairs(WN.data[module] or {}) do
        if (not seen or Compare(v.version, seen) > 0) and (not now or Compare(v.version, now) <= 0) then
            versions[#versions + 1] = v
        end
    end
    table.sort(versions, function(a, b) return Compare(a.version, b.version) > 0 end)
    if not seen and not all then versions = { versions[1] } end
    local pages = {}
    for _, v in ipairs(versions) do
        for _, p in ipairs(v.pages) do
            pages[#pages + 1] = { name = p.name, icon = p.icon, lines = p.lines, example = p.example,
                version = v.version }
        end
    end
    return pages, versions[1] and versions[1].version
end

---------------------------------------------------------------------------
-- Drawing helpers (Immersion's cards: Card.lua)
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

-- (a pop: past full a little, then back)
local function Pop(t)
    local c = 1.7
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
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

local bodyFont = GameFontHighlight and GameFontHighlight:GetFont()
local ACROSS = TILE * 1.2 * ROOT2           -- (a diamond's width, point to point)

-- Where the sidebar is: Immersion's cards' corner, its top and scale (the
-- Body tab's), else the same defaults
local function Corner()
    local C = IF.Interface and IF.Interface.Card
    local top = C and C.Top and C.Top() or 0.15
    local scale = C and C.Scale and C.Scale() or 1
    return CORNER_X, top, scale
end

---------------------------------------------------------------------------
-- The panel: the module's name, then a card for each page revealed so far
---------------------------------------------------------------------------
local root = CreateFrame("Frame", "ImprovedForeverWhatsNew", UIParent)
root:SetSize(PANEL_W, 200)
root:SetFrameStrata("HIGH")
root:EnableMouse(true)
root:Hide()

-- (the ground: the NPC dialog's band (Immersion's NpcDialog.lua), dark in
-- the middle, fading out to its sides)
local band = CreateFrame("Frame", nil, root)
band:SetPoint("TOPLEFT", -BAND_REACH, 14)
band:SetPoint("BOTTOMRIGHT", BAND_REACH, -10)
band:SetFrameLevel(math.max(0, root:GetFrameLevel() - 1))
do
    local fade = BAND_REACH * 2
    local function Part(points, from, to)
        local t = band:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, 1)
        for _, p in ipairs(points) do t:SetPoint(unpack(p)) end
        if from and t.SetGradient and CreateColor then
            t:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, from), CreateColor(0, 0, 0, to))
        else
            t:SetVertexColor(0, 0, 0, BAND_ALPHA)
        end
    end
    Part({ { "TOPLEFT", band, "TOPLEFT", fade, 0 }, { "BOTTOMRIGHT", band, "BOTTOMRIGHT", -fade, 0 } })
    Part({ { "TOPLEFT" }, { "BOTTOMRIGHT", band, "BOTTOMLEFT", fade, 0 } }, 0, BAND_ALPHA)
    Part({ { "TOPRIGHT" }, { "BOTTOMLEFT", band, "BOTTOMRIGHT", -fade, 0 } }, BAND_ALPHA, 0)
end

-- (the module's name in Morpheus, what changed small under it)
local headName = Text(root, FONT, NAME_SIZE, GOLD[1], GOLD[2], GOLD[3])
headName:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
local headSmall = Text(root, bodyFont, SMALL_SIZE, 1, 1, 1)
headSmall:SetPoint("TOPLEFT", headName, "BOTTOMLEFT", 0, -4)

-- (the cards in a window under the header: the list scrolls when it would
-- reach the chat box, the wheel or the pad's browse moving it)
local HEAD_H = NAME_SIZE + SMALL_SIZE + 4 + 18
local VIEW_PAD = 14
local view = CreateFrame("Frame", nil, root)
view:SetPoint("TOPLEFT", root, "TOPLEFT", -VIEW_PAD, -HEAD_H)
view:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", VIEW_PAD, 0)
view:SetClipsChildren(true)
local content = CreateFrame("Frame", nil, view)
content:SetSize(PANEL_W, 10)
local scroll, scrollMax, viewH = 0, 0, 0

local function Scrolled()
    scroll = math.max(0, math.min(scrollMax, scroll))
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", view, "TOPLEFT", VIEW_PAD, scroll)
end
Scrolled()
root:EnableMouseWheel(true)
root:SetScript("OnMouseWheel", function(_, delta)
    scroll = scroll - delta * 60
    Scrolled()
end)

-- (the current tour)
local PAGES = {}                        -- (every page of every module, in order)
local secs = {}                         -- (a module's section: { module, version, seen, all, first, last })
local entries = {}
local headers = {}
local page, goal = 1, 0
local reached = 1
local broken
local Go
local tour                              -- { items, demo, born }

-- A page's card: the diamond with its picture, the gold line running down
-- from it, the name, the words to the right
local function Entry(i)
    local f = CreateFrame("Button", nil, content)
    f:SetWidth(PANEL_W)
    f.tile = Tile(f, TILE)
    f.tile:ClearAllPoints()
    f.tile:SetPoint("CENTER", f, "TOPLEFT", ACROSS / 2, -ACROSS / 2)
    f.tile.icon:SetSize(ACROSS * 0.72, ACROSS * 0.72)
    f.tile.border:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetWidth(1)
    f.line:SetPoint("TOPLEFT", f, "TOPLEFT", ACROSS / 2, -(ACROSS + 4))
    f.line:SetColorTexture(1, 1, 1, 1)
    if not pcall(f.line.SetGradient, f.line, "VERTICAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0),
        CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.9)) then
        f.line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
    end
    f.name = Text(f, FONT, 22, 1, 1, 1)
    f.ver = Text(f, bodyFont, 11, 0.55, 0.55, 0.55)
    f.l1 = Text(f, bodyFont, SMALL_SIZE, 1, 1, 1)
    f.l2 = Text(f, bodyFont, SMALL_SIZE, 1, 0.82, 0)
    for _, s in ipairs({ f.l1, f.l2 }) do
        s:SetWordWrap(true)
        s:SetJustifyH("LEFT")
        s:SetWidth(TEXT_W)
    end
    f:SetScript("OnEnter", function(self) self.hover = true end)
    f:SetScript("OnLeave", function(self) self.hover = nil end)
    f:SetScript("OnClick", function() Go(i) end)
    entries[i] = f
    return f
end

-- (a card's words laid out: where each sits and how tall the card is)
local function FillEntry(f, p)
    f.tile.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_Note_01")
    f.tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.name:SetText(p.name or "")
    f.ver:SetText(p.version or "")
    f.l1:SetText(p.lines and p.lines[1] or "")
    f.l2:SetText(p.lines and p.lines[2] or "")
    local y = -(ACROSS / 2 - 10)
    f.nameY = y
    y = y - 24 - 5
    f.l1Y = y
    y = y - (f.l1:GetStringHeight() or 0) - 3
    f.l2Y = y
    y = y - ((p.lines and p.lines[2]) and f.l2:GetStringHeight() or 0)
    f.h = math.max(-y + PAD_Y, ACROSS + 24)
    f:SetHeight(f.h)
    f.line:SetHeight(0.001)
end

-- (a module's example of a page, to the right of the sidebar)
local stage = CreateFrame("Frame", nil, root)
stage:SetSize(STAGE_W, STAGE_H)
stage:SetPoint("LEFT", root, "TOPRIGHT", 60 + BAND_REACH, -STAGE_H / 2)
local built = {}

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
end

-- The buttons: the game's legend (the pad's prompts; with the mouse its
-- Close button), under the cards
local LEGEND = {
    { "PAD2", "PAD2", "Close" },
    { glyph = "DPAD_UD", text = "Browse", pad = true },
}
local legend = IF.InputLegend(root)

-- (with the mouse and keyboard: the game's X at the top right, no legend)
local close
do
    local ok, b = pcall(CreateFrame, "Button", nil, root, "UIPanelCloseButton")
    if ok and b then
        close = b
    else
        close = CreateFrame("Button", nil, root)
        close:SetSize(24, 24)
        local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        x:SetPoint("CENTER")
        x:SetText("X")
    end
    close:SetFrameLevel(root:GetFrameLevel() + 10)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", 6, 8)
end

-- Where everything sits: the header, the revealed cards one under another,
-- the reveal button under them, then Close; the panel as tall as that, in
-- the sidebar's corner
-- A module's section header: its name, the versions beside it, a rule under
local SEC_H = 34
local function Header(k)
    local f = CreateFrame("Frame", nil, content)
    f:SetSize(PANEL_W, SEC_H)
    f.title = Text(f, FONT, 20, GOLD[1], GOLD[2], GOLD[3])
    f.title:SetPoint("TOPLEFT")
    f.info = Text(f, bodyFont, 12, 0.6, 0.6, 0.6)
    f.info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -6)
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -28)
    rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -28)
    rule:SetColorTexture(1, 1, 1, 1)
    if not pcall(rule.SetGradient, rule, "HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.7),
        CreateColor(GOLD[1], GOLD[2], GOLD[3], 0)) then
        rule:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.4)
    end
    headers[k] = f
    return f
end

-- The height there is for the panel: down to the chat box's top (and the
-- legend under the panel), from where the sidebar starts
local LEGEND_ROOM, CHAT_TABS = 56, 36
local function Available()
    local _, top, scale = Corner()
    local ui = UIParent:GetHeight()
    local floor = 0
    local chat = _G.ChatFrame1
    local ct = chat and chat.GetTop and chat:GetTop()
    if ct then floor = ct * chat:GetEffectiveScale() / UIParent:GetEffectiveScale() + CHAT_TABS end
    return (ui - ui * top - floor - LEGEND_ROOM) / scale
end

local function Layout()
    local y = 0
    for k, sec in ipairs(secs) do
        local h = headers[k] or Header(k)
        h:Show()
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        sec.top = -y
        y = y - SEC_H - 10
        for i = sec.first, sec.last do
            local f = entries[i]
            f:Show()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            f.top = -y
            y = y - f.h - STACK_GAP
        end
    end
    for k = #secs + 1, #headers do headers[k]:Hide() end
    for i = #PAGES + 1, #entries do entries[i]:Hide() end
    -- (as tall as the cards, but not past the chat box)
    local contentH = -y
    viewH = math.max(140, math.min(contentH, Available() - HEAD_H))
    content:SetHeight(contentH)
    root:SetHeight(HEAD_H + viewH)
    scrollMax = math.max(0, contentH - viewH)
    Scrolled()
    local pad = IF.Input.Pad()
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -8)
    legend:Set(pad and LEGEND or nil)
    close:SetShown(not pad)
    local x, top, scale = Corner()
    root:SetScale(scale)
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, -UIParent:GetHeight() * top / scale)
end

-- (a card brought into the window: the first of a section with its header)
local function ScrollTo(n)
    local f = entries[n]
    if not f then return end
    local from, to = f.top, f.top + f.h
    for _, sec in ipairs(secs) do
        if sec.first == n then from = sec.top end
    end
    if from < scroll then
        scroll = from
    elseif to > scroll + viewH then
        scroll = to - viewH
    end
    Scrolled()
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
local escape = CreateFrame("Frame", "ImprovedForeverWhatsNewEscape", UIParent)
escape:Hide()
IF.Focus.EscapeClose(escape)

local function Finish()
    goal = 0
    page = 1
    -- (seen: each module's version is noted, so its next update shows again)
    if tour and IF.db and not tour.demo then
        IF.db.whatsNew = IF.db.whatsNew or {}
        for _, item in ipairs(tour.items) do
            IF.db.whatsNew[item.module] = Installed(item.module) or item.version
        end
    end
    escape:Hide()
end

function Go(n)
    if n > #PAGES then return Finish() end
    if n < 1 then return end
    local changed = n ~= page
    page = n
    ShowExample(PAGES[n].example)
    Layout()
    ScrollTo(n)
    if changed and goal == 1 then PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_SELECT or 856) end
end

local function Press(key)
    if goal ~= 1 then return end
    if key == "UP" then
        if page > 1 then Go(page - 1) end
    elseif key == "DOWN" then
        if page < reached then Go(page + 1) end
    elseif key == "PAD2" then
        Finish()
    end
end
close:SetScript("OnClick", function() Press("PAD2") end)

---------------------------------------------------------------------------
-- The pad: taken only while it is up
---------------------------------------------------------------------------
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetScript("OnGamePadButtonDown", function(_, button)
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
-- Drawn: each card plays in as the quest cards do (the diamond pops up, the
-- line draws down, the words slide in one after another)
---------------------------------------------------------------------------
local presence = 0

-- Is the tour up (or fading)? The sidebar's other cards stand down meanwhile
-- (Immersion's Card.lua asks)
function WN.Active()
    return goal == 1 or presence > 0
end

local function Play(f, i, now)
    local T = math.min(1, (now - (f.born or 0)) / IN_TIME)
    local pop = Ease(T, 0, 0.4)
    local scale = math.max(0.01, 0.5 + 0.5 * Pop(pop))
    f.tile:SetScale(scale)
    f.tile:ClearAllPoints()
    f.tile:SetPoint("CENTER", f, "TOPLEFT", ACROSS / 2 / scale, -ACROSS / 2 / scale)
    f.tile:SetAlpha(pop)
    f.line:SetHeight(math.max(0.001, (f.h - (ACROSS + 4)) * Ease(T, 0.2, 0.75)))
    f.ver:ClearAllPoints()
    f.ver:SetPoint("TOPRIGHT", f, "TOPLEFT", ACROSS + 10 + TEXT_W, f.nameY - 8)
    f.ver:SetAlpha(Ease(T, 0.3, 0.7))
    local rows = { { f.name, f.nameY }, { f.l1, f.l1Y }, { f.l2, f.l2Y } }
    for r, row in ipairs(rows) do
        local from = 0.3 + 0.1 * (r - 1)
        local e = Ease(T, from, from + 0.4)
        row[1]:ClearAllPoints()
        row[1]:SetPoint("TOPLEFT", f, "TOPLEFT", ACROSS + 10 - ROW_SLIDE * (1 - e), row[2])
        row[1]:SetAlpha(e)
    end
    -- (the page picked is lit; the others dimmer)
    local on = i == page
    f:SetAlpha(on and 1 or (f.hover and 0.85 or 0.55))
    f.name:SetTextColor(on and GOLD[1] or 1, on and GOLD[2] or 1, on and GOLD[3] or 1)
end

local function Step(elapsed)
    local want = goal == 1 and not IF.InCombat()
    if goal == 0 then presence = 0 end
    presence = want and math.min(1, presence + elapsed / FADE) or math.max(0, presence - elapsed / FADE)
    TakePad(want and presence >= 0.5)
    if presence <= 0 then
        root:Hide()
        return
    end
    if not root:IsShown() then root:Show() end
    if want and not escape:IsShown() then escape:Show() end
    root:SetAlpha(Ease(presence, 0, 1))
    local now = GetTime()
    band:SetAlpha(Ease(math.min(1, (now - (tour and tour.born or 0)) / IN_TIME), 0, 0.5))
    for k, sec in ipairs(secs) do
        local h, first = headers[k], entries[sec.first]
        if h and first then
            h:SetAlpha(Ease((now - (first.born or 0)) / IN_TIME, 0, 0.4))
        end
    end
    for i, f in ipairs(entries) do
        if f:IsShown() then Play(f, i, now) end
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then
        broken, goal = true, 0
        root:Hide()
        escape:Hide()
        TakePad(false)
        IF.Print("What's new: the tour stopped after an error: " .. tostring(err))
    end
end)

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------
-- A tour of the modules' items: { module, pages, version, seen?, all? },
-- one list, a section for each module
local function Start(items, demo)
    broken = nil
    PAGES, secs = {}, {}
    for _, item in ipairs(items) do
        local first = #PAGES + 1
        for _, p in ipairs(item.pages) do PAGES[#PAGES + 1] = p end
        secs[#secs + 1] = { module = item.module, version = item.version, seen = item.seen, all = item.all,
            first = first, last = #PAGES }
    end
    for i, p in ipairs(PAGES) do FillEntry(entries[i] or Entry(i), p) end
    for k, sec in ipairs(secs) do
        local h = headers[k] or Header(k)
        h.title:SetText(Title(sec.module))
        h.info:SetText(sec.seen and (sec.seen .. "  >  " .. tostring(sec.version))
            or ((sec.all and "up to " or "") .. tostring(sec.version)))
    end
    tour = { items = items, born = GetTime(), demo = demo }
    headName:SetText("What's new")
    headSmall:SetText(demo and "Demo: nothing is noted as seen." or "Since the version you had.")
    goal = 1
    reached = #PAGES
    page = 0
    -- (every card at once, one after another a beat apart)
    for i = 1, #PAGES do entries[i].born = GetTime() + (i - 1) * CARD_BEAT end
    local ok, err = pcall(Go, 1)
    if not ok then
        goal = 0
        IF.Print("What's new: the tour could not start: " .. tostring(err))
    end
end

-- (a moment after login, once out of a fight)
local function Begin(items, demo)
    if IF.InCombat() or UnitIsDeadOrGhost("player") or goal == 1 then
        return C_Timer.After(5, function() Begin(items, demo) end)
    end
    Start(items, demo)
end

-- Modules updated since they were last seen, as items
local function Pending()
    local db = IF.db
    local first = db.whatsNew == nil
    db.whatsNew = db.whatsNew or {}
    local found = {}
    for _, module in ipairs(WN.Names()) do
        local now = Installed(module)
        local seen = db.whatsNew[module]
        if now then
            if first and not IF.freshInstall then
                -- (no version tracked: every page there is, up to this version)
                local pages, version = PagesFor(module, nil, now, true)
                if #pages > 0 then
                    found[#found + 1] = { module = module, pages = pages, version = version, all = true }
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

function WN.Names()
    local names = {}
    for name in pairs(WN.data) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == "Core" or b == "Core" then return a == "Core" end
        return a < b
    end)
    return names
end

IF.OnLogin(function()
    C_Timer.After(START_DELAY, function()
        local items = Pending()
        if #items > 0 then Begin(items) end
    end)
end)

-- /if whatsnew demo: a player with no version tracked: every module's every
-- page in one list, a section for each (nothing is noted as seen)
-- /if whatsnew [module]: a module's latest pages again (Core's by default)
IF.AddCommand("whatsnew", function(args)
    local want = args and args[1]
    if want and want:lower() == "demo" then
        local items = {}
        for _, name in ipairs(WN.Names()) do
            local pages, version = PagesFor(name, nil, Installed(name), true)
            if #pages > 0 then
                items[#items + 1] = { module = name, pages = pages, version = version, all = true }
            end
        end
        if #items == 0 then return IF.Print("What's new: no pages") end
        return Start(items, true)
    end
    local module
    for name in pairs(WN.data) do
        if want and name:lower() == want:lower() then module = name end
    end
    if not module and not want then module = WN.data.Core and "Core" or next(WN.data) end
    if not module then
        IF.Print("What's new: " .. (want and ("no pages for \"" .. want .. "\"") or "no pages")
            .. ". Modules with pages: " .. table.concat(WN.Names(), ", ") .. ", or demo")
        return
    end
    local pages, version = PagesFor(module, nil, Installed(module))
    if #pages == 0 then pages, version = PagesFor(module) end
    if #pages == 0 then return IF.Print("What's new: no pages for " .. module) end
    Start({ { module = module, pages = pages, version = version } }, true)
end, "[module | demo]: play a module's what's new again, or every module's pages in one list")
