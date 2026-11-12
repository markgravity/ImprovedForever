-- What's new, as a changelog: when a module has been updated since you last
-- saw it, a list of what changed, in the look of Immersion's sidebar cards
-- (Card.lua, QuestPeek.lua): at the screen's top left on the NPC dialog's
-- dark band, "What's new" in Morpheus, then a card for each module: its
-- spell diamond (the module's icon), a gold line running down from it, its
-- name and versions, under them its changes as a list with each change's
-- name lit. The cards play in as the quest cards do, one after another. The
-- list scrolls (the wheel, the D-pad) when it would reach the chat box. The
-- game's button legend under it with the pad (Close; B or Esc end it), the
-- game's X at the top right with the mouse.
-- * The changes live here, in WhatsNewData.lua, per module and version
--   (IF.WhatsNew.Add).
-- * What each module was last seen at is IF.db.whatsNew[module]. A first
--   install (IF.freshInstall) shows nothing: the versions are just noted, as
--   for a module installed later. A player with no version tracked (an
--   update from before this existed) is shown every change there is. Several
--   updated modules are one list.
-- * /if whatsnew demo plays that case; /if whatsnew [module] one module's
--   latest changes; the General tab's button every module's latest.
-- The pad is taken by a catcher frame only while the list is up (not in a
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

-- module: "Core" or the module's name ("Immersion"); def.pages: { name,
-- lines = { first, second } }: one change each, its name lit
function WN.Add(module, version, def)
    local list = WN.data[module] or {}
    WN.data[module] = list
    list[#list + 1] = { version = version, pages = def.pages }
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
local GOLD_HEX = "ffd173"                   -- (a change's name, lit)

-- Where the sidebar is: Immersion's cards' corner, its top and scale (the
-- Body tab's), else the same defaults
local function Corner()
    local C = IF.Interface and IF.Interface.Card
    local top = C and C.Top and C.Top() or 0.15
    local scale = C and C.Scale and C.Scale() or 1
    return CORNER_X, top, scale
end

---------------------------------------------------------------------------
-- The panel: "What's new", then a card for each module: its diamond and
-- name, under it the list of its changes
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

-- (the title in Morpheus, what it is small under it)
local headName = Text(root, FONT, NAME_SIZE, GOLD[1], GOLD[2], GOLD[3])
headName:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
local headSmall = Text(root, bodyFont, SMALL_SIZE, 1, 1, 1)
headSmall:SetPoint("TOPLEFT", headName, "BOTTOMLEFT", 0, -4)

-- (the cards in a window under the header: the list scrolls when it would
-- reach the chat box, the wheel or the pad's D-pad moving it)
local HEAD_H = NAME_SIZE + SMALL_SIZE + 4 + 18
local VIEW_PAD = 14
local SCROLL_STEP = 80
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
    scroll = scroll - delta * SCROLL_STEP
    Scrolled()
end)

-- (the current tour)
local items = {}
local cards = {}
local goal = 0
local broken
local tour                              -- { items, demo, born }

-- A module's card: its diamond (the module's own icon), the gold line
-- running down from it, its name and versions, then its changes: a version's
-- small label when there are several, each change with its name lit
local function Card(k)
    local f = CreateFrame("Frame", nil, content)
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
    f.name = Text(f, FONT, 22, GOLD[1], GOLD[2], GOLD[3])
    f.ver = Text(f, bodyFont, 12, 0.6, 0.6, 0.6)
    f.rows = {}                         -- (fontstrings, reused)
    cards[k] = f
    return f
end

local function RowString(f, j)
    local fs = f.rows[j]
    if not fs then
        fs = Text(f, bodyFont, SMALL_SIZE, 1, 1, 1)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetWidth(TEXT_W)
        f.rows[j] = fs
    end
    return fs
end

-- (a page's words, joined)
local function Words(p)
    local t = {}
    for _, line in ipairs(p.lines or {}) do t[#t + 1] = line end
    return table.concat(t, " ")
end

local function IconOf(module)
    local A = _G.C_AddOns
    local icon = A and A.GetAddOnMetadata and A.GetAddOnMetadata(Folder(module), "IconTexture")
    return icon or "Interface\\Icons\\INV_Misc_Note_01"
end

local function Fill(f, item)
    f.tile.icon:SetTexture(IconOf(item.module))
    f.tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.name:SetText(Title(item.module))
    f.ver:SetText(item.seen and (item.seen .. "  >  " .. tostring(item.version))
        or ((item.all and "up to " or "") .. tostring(item.version)))
    f.nameY = -(ACROSS / 2 - 10)
    local y = f.nameY - 24 - 6
    local shown = 0
    local last
    local multi = false
    for _, p in ipairs(item.pages) do
        if p.version ~= item.pages[1].version then multi = true end
    end
    f.list = {}
    for _, p in ipairs(item.pages) do
        if multi and p.version ~= last then
            last = p.version
            shown = shown + 1
            local fs = RowString(f, shown)
            fs:SetTextColor(0.6, 0.6, 0.6)
            fs:SetText(tostring(p.version))
            y = y - 4
            f.list[#f.list + 1] = { fs = fs, y = y }
            y = y - (fs:GetStringHeight() or 12) - 3
        end
        shown = shown + 1
        local fs = RowString(f, shown)
        fs:SetTextColor(1, 1, 1)
        fs:SetText(("|cff%s%s|r  %s"):format(GOLD_HEX, p.name or "", Words(p)))
        f.list[#f.list + 1] = { fs = fs, y = y }
        y = y - (fs:GetStringHeight() or 14) - 6
    end
    for j = shown + 1, #f.rows do f.rows[j]:Hide() end
    for _, e in ipairs(f.list) do e.fs:Show() end
    f.h = math.max(-y + PAD_Y, ACROSS + 24)
    f:SetHeight(f.h)
    f.line:SetHeight(0.001)
end

-- (with the mouse and keyboard: the game's X at the top right, no legend)
local LEGEND = {
    { "PAD2", "PAD2", "Close" },
    { glyph = "DPAD_UD", text = "Browse", pad = true },
}
local legend = IF.InputLegend(root)
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
    for k = 1, #items do
        local f = cards[k]
        f:Show()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - f.h - STACK_GAP
    end
    for k = #items + 1, #cards do cards[k]:Hide() end
    -- (as tall as the cards, but not past the chat box)
    local contentH = math.max(1, -y - STACK_GAP)
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

---------------------------------------------------------------------------
-- Closing, the pad
---------------------------------------------------------------------------
local escape = CreateFrame("Frame", "ImprovedForeverWhatsNewEscape", UIParent)
escape:Hide()
IF.Focus.EscapeClose(escape)

local function Finish()
    goal = 0
    -- (seen: each module's version is noted, so its next update shows again)
    if tour and IF.db and not tour.demo then
        IF.db.whatsNew = IF.db.whatsNew or {}
        for _, item in ipairs(tour.items) do
            IF.db.whatsNew[item.module] = Installed(item.module) or item.version
        end
    end
    escape:Hide()
end

local function Press(key)
    if goal ~= 1 then return end
    if key == "UP" then
        scroll = scroll - SCROLL_STEP
        Scrolled()
    elseif key == "DOWN" then
        scroll = scroll + SCROLL_STEP
        Scrolled()
    elseif key == "PAD2" then
        Finish()
    end
end
close:SetScript("OnClick", function() Press("PAD2") end)

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

local function Play(f, now)
    local T = math.min(1, (now - (f.born or 0)) / IN_TIME)
    local pop = Ease(T, 0, 0.4)
    local scale = math.max(0.01, 0.5 + 0.5 * Pop(pop))
    f.tile:SetScale(scale)
    f.tile:ClearAllPoints()
    f.tile:SetPoint("CENTER", f, "TOPLEFT", ACROSS / 2 / scale, -ACROSS / 2 / scale)
    f.tile:SetAlpha(pop)
    f.line:SetHeight(math.max(0.001, (f.h - (ACROSS + 4)) * Ease(T, 0.2, 0.75)))
    local e = Ease(T, 0.3, 0.7)
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", ACROSS + 10 - ROW_SLIDE * (1 - e), f.nameY)
    f.name:SetAlpha(e)
    f.ver:ClearAllPoints()
    f.ver:SetPoint("TOPRIGHT", f, "TOPLEFT", ACROSS + 10 + TEXT_W, f.nameY - 8)
    f.ver:SetAlpha(e)
    -- (the changes, a beat apart)
    for j, row in ipairs(f.list or {}) do
        local from = math.min(0.55, 0.4 + 0.04 * (j - 1))
        local r = Ease(T, from, from + 0.35)
        row.fs:ClearAllPoints()
        row.fs:SetPoint("TOPLEFT", f, "TOPLEFT", ACROSS + 10 - ROW_SLIDE * (1 - r), row.y)
        row.fs:SetAlpha(r)
    end
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
    for k = 1, #items do
        if cards[k]:IsShown() then Play(cards[k], now) end
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
-- A tour of the modules' entries: { module, pages, version, seen?, all? },
-- one list, a card for each module
local function Start(list, demo)
    broken = nil
    items = list
    for k, item in ipairs(items) do Fill(cards[k] or Card(k), item) end
    tour = { items = items, born = GetTime(), demo = demo }
    headName:SetText("What's new")
    headSmall:SetText(demo and "Demo: nothing is noted as seen." or "Since the version you had.")
    goal = 1
    scroll = 0
    -- (the cards one after another a beat apart)
    for k = 1, #items do cards[k].born = GetTime() + (k - 1) * CARD_BEAT end
    local ok, err = pcall(Layout)
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

-- Every module's latest pages again, in one list (the General tab's button;
-- nothing is noted as seen)
function WN.Replay()
    local items = {}
    for _, name in ipairs(WN.Names()) do
        if Installed(name) then
            local pages, version = PagesFor(name, nil, Installed(name))
            if #pages == 0 then pages, version = PagesFor(name) end
            if #pages > 0 then
                items[#items + 1] = { module = name, pages = pages, version = version }
            end
        end
    end
    if #items == 0 then return IF.Print("What's new: no pages") end
    Start(items, true)
end

-- /if whatsnew demo: what a player sees after installing the new release with
-- no version tracked: every module's every change in the data, even those
-- of versions not installed yet (nothing is noted as seen);
-- /if whatsnew demo update: a player who had the version installed now:
-- only the changes of versions newer than it (what this release adds)
-- /if whatsnew [module]: a module's latest changes again (Core's by default)
local function Versions(name)
    local list = {}
    for _, v in ipairs(WN.data[name] or {}) do list[#list + 1] = v.version end
    table.sort(list, function(a, b) return Compare(a, b) > 0 end)
    return list
end

IF.AddCommand("whatsnew", function(args)
    local want = args and args[1]
    if want and want:lower() == "demo" then
        local update = args[2] and args[2]:lower() == "update"
        local list = {}
        for _, name in ipairs(WN.Names()) do
            local versions = Versions(name)
            local newest = versions[1]
            if newest then
                if update then
                    -- (the modules this release brings new changes to: newer than installed)
                    local now = Installed(name)
                    local before = now or versions[2] or "0"
                    local pages = (not now or Compare(newest, now) > 0) and PagesFor(name, before, newest) or {}
                    if #pages > 0 then
                        list[#list + 1] = { module = name, pages = pages, version = newest, seen = before }
                    end
                else
                    local pages = PagesFor(name, nil, newest, true)
                    if #pages > 0 then
                        list[#list + 1] = { module = name, pages = pages, version = newest, all = true }
                    end
                end
            end
        end
        if #list == 0 then return IF.Print("What's new: no pages") end
        return Start(list, true)
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
end, "[module | demo [update]]: play a module's what's new again, or what a player sees after installing the new release (demo: with no version tracked; demo update: from the version before)")
