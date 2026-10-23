-- The auction house window's Tasks tab (AuctionBuy.lua's window): three
-- columns.
--   Left, the tasks (IF.TaskList below, shared with the vendor's Tasks,
--     VendorTasks.lua): "All tasks", each task still getting its reagents,
--     then a "Ready to craft" section (Tasks.lua's TK.TaskLines);
--   middle, what the picked one (all of them: added up) still needs from the
--     auction house, how many are missing (a vendor's items not: bought at
--     one, its own Tasks; how many: said under the list);
--   right, the picked item's screen (the Buy tab's itself: its chart, its
--     quantity or auctions, Cross held buys), opened with the quantity still
--     missing a moment after it is picked.
-- The left stick works the lists: left / right the column (tasks, items),
-- up / down the pick in it; the D-pad and the buttons work the item's
-- screen. Circle closes the auction house.
-- With the Immersion module and its "Auction house scene" switch on only
-- (IF.auctionScene, Module.lua); else AuctionTasksClassic.lua's classic look runs instead.
local IF = ImprovedForever
if not IF.auctionScene then return end

local K = IF.ConfigKit
local KC = K.C
local BY = IF.AuctionBuy
local SC = IF.AuctionScene
local TK = IF.Tasks

local TASKS_W = 190 + 14           -- the Buy tab's categories' column
local ITEMS_W = 236                -- (the item's screen: the rest, as wide as the Sell tab's)
local ITEMS_X = 14 + TASKS_W + 10
local DETAIL_X = ITEMS_X + ITEMS_W + 10
local ROW_H = 48
local OPEN_AFTER = 0.3             -- resting on an item this long: its screen opens (searched)
local ALL_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local Glyph = function(key, size) return BY.Glyph(key, size) end

---------------------------------------------------------------------------
-- The tasks' column (here and at a vendor): a panel, its title, a row a
-- task ("All tasks" first, the ready ones under their header). list =
-- IF.TaskList(parent, width, rows, onClick, scene): list.frame (to place),
-- (scene: the auction window's look, AuctionScene.lua: no panel, bare rows,
-- the title in Morpheus; else the vendor window's, the game's panels)
-- list:Render(focused, extra) (extra: "All tasks"' second line),
-- list:Picked() (the task; nil: all), list:Step(dir), list:Pick(index)
---------------------------------------------------------------------------
local function Header(parent, width)
    local header = K.NewFrame("Frame", nil, parent)
    header:SetSize(width, ROW_H - 4)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("BOTTOMLEFT", 4, 8)
    header.info = K.ChatText(header, 11, KC.help)
    header.info:SetPoint("BOTTOMRIGHT", -4, 8)
    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 3)
    rule:SetPoint("BOTTOMRIGHT", 0, 3)
    rule:SetColorTexture(0.45, 0.38, 0.25, 0.8)
    return header
end

function IF.TaskList(parent, width, rowsFit, onClick, scene)
    local list = { sel = 1, top = 1, lines = {} }
    local box = scene and K.NewFrame("Frame", nil, parent) or BY.Panel(parent, 0.4)
    box:SetWidth(width)
    list.frame = box
    local title = scene and SC.Title(box) or K.ChatText(box, 12, KC.dimGold)
    title:SetPoint("TOP", 0, -10)
    local rows = {}
    local rowW = width - 16
    for i = 1, rowsFit do
        local row
        if scene then
            row = SC.Row(box, ROW_H - 4, 28)
            row:SetPoint("TOPLEFT", 0, -36 - (i - 1) * ROW_H)
            row:SetPoint("RIGHT", box, "RIGHT", 0, 0)
            row.header = SC.Section(box, ROW_H - 4)
            row.header:SetPoint("TOPLEFT", row, "TOPLEFT")
            row.header:SetPoint("TOPRIGHT", row, "TOPRIGHT")
        else
            row = BY.ItemRow(box, rowW, ROW_H - 4, rowW - 50 - 6)
            row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
            row.header = Header(box, rowW)
            row.header:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        end
        row:SetScript("OnClick", function(self)
            if self.index then
                list:Pick(self.index)
                if onClick then onClick() end
            end
        end)
        rows[i] = row
    end
    -- (the mouse's wheel: the task above / below, as a click on it)
    local wheel = { box }
    for _, row in ipairs(rows) do wheel[#wheel + 1] = row end
    BY.Wheel(wheel, function(dir)
        if list:Step(dir) and onClick then onClick() end
    end)

    function list:Picked()
        local line = self.lines[self.sel]
        return line and line.task or nil
    end

    -- (a header: on past it, the way it was going); true: another picked
    function list:Pick(index, dir)
        index = math.max(1, math.min(#self.lines, index))
        if self.lines[index] and self.lines[index].header then
            local past = index + (dir or 1)
            if self.lines[past] then index = past else index = self.sel end
        end
        if index == self.sel then return false end
        self.sel = index
        return true
    end

    function list:Step(dir)
        return self:Pick(self.sel + dir, dir)
    end

    -- The lines again (the picked task kept picked as it moves between
    -- sections)
    function list:Refresh()
        local picked = self:Picked()
        self.lines = TK.TaskLines()
        if picked then
            for i, line in ipairs(self.lines) do
                if line.task == picked then self.sel = i end
            end
        end
        self.sel = math.max(1, math.min(self.sel, #self.lines))
        if self.lines[self.sel].header then self.sel = self.sel + 1 end
    end

    function list:Render(focused, allLine)
        local lines = self.lines
        local n = #lines
        local shown = #rows
        if self.sel < self.top then self.top = self.sel end
        if self.sel > self.top + shown - 1 then self.top = self.sel - shown + 1 end
        self.top = math.max(1, math.min(self.top, math.max(1, n - shown + 1)))
        local count = #TK.Tasks()
        if scene then
            title:Set(count .. (count == 1 and " task" or " tasks"), focused, self.glyph or "LS")
        else
            title:SetText((focused and not BY.Mouse() and Glyph(self.glyph or "LS", 18) .. " " or "") .. count
                .. (count == 1 and " task" or " tasks"))
        end
        local fr, fg, fb = BY.FocusColor()
        for i, row in ipairs(rows) do
            local index = self.top + i - 1
            local line = lines[index]
            row.index = index
            row:SetShown(line ~= nil and not line.header)
            row.header:SetShown(line ~= nil and line.header ~= nil)
            if line and line.header and scene then
                row.header:Set(line.header, { 0.56, 0.85, 0.56 }, line.count .. "")
            elseif line and line.header then
                row.header.text:SetText("|cff5fd35f" .. line.header:upper() .. "|r")
                row.header.info:SetText(line.count .. "")
            elseif line then
                if line.all then
                    row:Fill({ icon = ALL_ICON, quality = 1, name = "All tasks", line = allLine or "" })
                else
                    local t = line.task
                    local left = math.max(0, t.count - (t.made or 0))
                    row:Fill({ icon = t.icon, quality = 1, name = t.name .. " × " .. left,
                        line = TK.Ready(t) and "|cff5fd35fready to craft|r" or "reagents to get" })
                end
                -- (the list with the pad: its pick lit in full; else dimmed)
                if scene then
                    row:Lit(index == self.sel, focused)
                else
                    row.focus:SetShown(index == self.sel)
                    row.focus:SetVertexColor(fr, fg, fb, focused and 1 or 0.35)
                end
            end
        end
    end

    -- (the stick's glyph in the title: the caller says which glyph)
    function list:SetGlyph(key)
        self.glyph = key
    end

    return list
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
local TT = { key = "tasks", label = "Tasks", icon = ALL_ICON }
IF.AuctionTasks = TT

local f, tasks, itemRows, itemsBox, blank
local column = "items"                 -- the list the stick works
local itemSel, itemTop = 1, 1
local items, vendorCount = {}, 0
local pickedAt = 0

local function ItemInfo(id)
    return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
end

-- What the picked task (or all) still needs from the auction house; how
-- many come from a vendor
local function Gather()
    items, vendorCount = {}, 0
    for _, e in ipairs(TK.NeedsFor(tasks:Picked())) do
        if e.vendor then vendorCount = vendorCount + 1 else items[#items + 1] = e end
    end
end

-- The tab, in the scene's look (AuctionScene.lua): no panels, the three
-- columns' titles in Morpheus (gold where the stick is), gold rules
-- standing between them, the rows bare (the picked one in a soft gold
-- light)
function TT.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    local rowsFit = math.floor((BY.H - 30 - 36 - 34) / ROW_H)

    -- Left: the tasks
    tasks = IF.TaskList(f, TASKS_W, rowsFit, function()
        column = "tasks"
        itemSel, itemTop, pickedAt = 1, 1, GetTime()
        BY.Render()
    end, true)
    tasks.frame:SetPoint("TOPLEFT", 14, -20)
    tasks.frame:SetPoint("BOTTOMLEFT", 14, 36)
    for _, x in ipairs({ ITEMS_X - 5, DETAIL_X - 5 }) do
        local standing = SC.Rule(f, BY.H - 70, true)
        standing:SetPoint("TOP", f, "TOPLEFT", x, -24)
    end

    -- Middle: what to buy here
    itemsBox = K.NewFrame("Frame", nil, f)
    itemsBox:SetPoint("TOPLEFT", ITEMS_X, -20)
    itemsBox:SetPoint("BOTTOMLEFT", ITEMS_X, 36)
    itemsBox:SetWidth(ITEMS_W)
    itemsBox.title = SC.Title(itemsBox)
    itemsBox.title:SetPoint("TOP", 0, -10)
    itemsBox.note = SC.Text(itemsBox, 11, SC.GREY, SC.BODY)
    itemsBox.note:SetPoint("BOTTOM", 0, 10)
    itemsBox.note:SetWidth(ITEMS_W - 20)
    itemsBox.empty = SC.Text(itemsBox, 12, SC.GREY, SC.BODY)
    itemsBox.empty:SetPoint("CENTER")
    itemsBox.empty:SetWidth(ITEMS_W - 30)
    itemsBox.empty:SetWordWrap(true)
    itemRows = {}
    for i = 1, rowsFit - 1 do
        local row = SC.Row(itemsBox, ROW_H - 4, 28)
        row:SetPoint("TOPLEFT", 0, -36 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", itemsBox, "RIGHT", 0, 0)
        row:SetScript("OnClick", function(self)
            if self.index then
                column = "items"
                itemSel, pickedAt = self.index, 0
                BY.Render()
            end
        end)
        BY.Hover(row, function(self)
            local e = self.index and items[self.index]
            if not e then return false end
            GameTooltip:SetItemByID(e.itemID)
        end)
        itemRows[i] = row
    end
    -- (the wheel: the item above / below)
    local wheel = { itemsBox }
    for _, row in ipairs(itemRows) do wheel[#wheel + 1] = row end
    BY.Wheel(wheel, function(dir)
        local was = itemSel
        column = "items"
        itemSel = math.max(1, math.min(#items, itemSel + dir))
        if itemSel ~= was then pickedAt = GetTime() end
        BY.Render()
    end)

    -- Right: the item's screen (moved in on Show); nothing picked: a note
    blank = K.NewFrame("Frame", nil, f)
    blank:SetPoint("TOPLEFT", DETAIL_X, -20)
    blank:SetPoint("BOTTOMRIGHT", -16, 36)
    blank.text = SC.Text(blank, 13, SC.GREY, SC.BODY)
    blank.text:SetPoint("CENTER")
    blank.text:SetWidth(BY.W - DETAIL_X - 16 - 60)
    blank.text:SetWordWrap(true)
    return f
end

local function RenderItems()
    local n = #items
    itemsBox.title:Set("To buy here", column == "items", "LS")
    itemsBox.note:SetText(vendorCount > 0 and (vendorCount .. " more from a vendor") or "")
    itemSel = math.max(1, math.min(itemSel, math.max(1, n)))
    local shown = #itemRows
    if itemSel < itemTop then itemTop = itemSel end
    if itemSel > itemTop + shown - 1 then itemTop = itemSel - shown + 1 end
    itemTop = math.max(1, math.min(itemTop, math.max(1, n - shown + 1)))
    itemsBox.empty:SetShown(n == 0)
    itemsBox.empty:SetText(#TK.Tasks() == 0 and "No tasks yet"
        or ("Nothing to buy here" .. (vendorCount > 0 and "" or ":|nthe bags hold it all")))
    for i, row in ipairs(itemRows) do
        local index = itemTop + i - 1
        local e = items[index]
        row.index = index
        row:SetShown(e ~= nil)
        if e then
            local _, _, quality, _, _, _, _, _, _, iconID = ItemInfo(e.itemID)
            row:Fill({
                icon = iconID, quality = quality, name = TK.ItemName(e.itemID),
                line = "have " .. e.have .. " of " .. e.need, price = "× " .. e.missing,
            })
            row:Lit(index == itemSel, column == "items")
        end
    end
end

-- Right: the picked item's screen (opened a moment after it is picked),
-- else what there is to say
local function RenderRight()
    local e = items[itemSel]
    -- (another item's screen still up: closed)
    if BY.DetailItemID() and not (e and BY.DetailItemID() == e.itemID) then BY.DetailClose() end
    local up = e and BY.DetailItemID() == e.itemID
    blank:SetShown(not up)
    if up then
        BY.DetailRender()
        BY.Tip()
        return
    end
    if GameTooltip:GetOwner() == BY.window and not BY.Hovering() then GameTooltip:Hide() end
    local mouse = BY.Mouse()
    if #TK.Tasks() == 0 then
        blank.text:SetText(mouse and "No tasks. In a profession window, pick a recipe and click Add Task under the window."
            or ("No tasks. In a profession window, hold " .. IF.ButtonName("A") .. " on a recipe of its list (Add Task)."))
    elseif not e then
        blank.text:SetText("Nothing to buy at the auction house" .. (vendorCount > 0
            and (".|n|cffb9ab8cThe rest is sold by vendors: at one, " .. (mouse and "click Tasks under its window"
                or ("press " .. IF.ButtonName("Y") .. " in its window (Tasks)")) .. ".|r") or ": the bags hold it all."))
    else
        blank.text:SetText("Looking it up...")
    end
end

function TT.Render()
    if not f then return end
    tasks:Refresh()
    Gather()
    local count = 0
    for _, e in ipairs(TK.NeedsFor(nil)) do
        if not e.vendor then count = count + 1 end
    end
    tasks:Render(column == "tasks", count > 0 and (count .. " to buy here") or "|cff5fd35fnothing to buy here|r")
    RenderItems()
    RenderRight()
end

function TT.Hints()
    local text = Glyph("LS") .. " " .. (column == "tasks" and "Task" or "Item") .. "   "
    if BY.DetailItemID() and items[itemSel] and BY.DetailItemID() == items[itemSel].itemID then
        text = text .. BY.DetailHints()
    end
    return text .. Glyph("B") .. " Close"
end

-- The left stick: left / right the column, up / down the pick in it
function TT.StickSide(dir)
    local want = dir < 0 and "tasks" or "items"
    if want == column then return end
    column = want
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    BY.Render()
end

function TT.StickStep(dir)
    if column == "tasks" then
        if tasks:Step(dir) then itemSel, itemTop, pickedAt = 1, 1, GetTime() end
    else
        local was = itemSel
        itemSel = math.max(1, math.min(#items, itemSel + dir))
        if itemSel ~= was then pickedAt = GetTime() end
    end
    BY.Render()
end

-- The buttons: the item's screen's (Circle: not its; the auction house closes)
function TT.Press(name, fast)
    if BY.DetailItemID() and BY.DetailPress(name, fast, true) then return true end
    return name ~= "B"
end

-- A moment's rest on an item: its screen opened (searched), the quantity
-- still missing
function TT.Update(now)
    local e = items[itemSel]
    if e and BY.DetailItemID() ~= e.itemID and now - pickedAt >= OPEN_AFTER then
        BY.DetailOpen(e.itemID, e.missing)
        BY.Render()
    end
end

function TT.Show()
    f:Show()
    BY.DetailInto(f, DETAIL_X, -20, -10, 36)
    column, itemSel, itemTop, pickedAt = "items", 1, 1, 0
end

function TT.Hide()
    BY.DetailClose()
    BY.DetailHome()
    if f then f:Hide() end
    if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
end

TK.OnChange(function()
    if f and f:IsShown() then BY.Render() end
end)

BY.AddPage(TT)
