-- Tasks: "make N of a recipe" (set in the profession window,
-- TaskCraft.lua) turned into what is still to buy: each reagent times
-- the crafts left, less what the bags hold, from a vendor (an item seen at
-- one, or a well-known one: thread, vials, flux...) or the auction house.
-- Kept per character (ImprovedForeverCharDB.tasks). Shown in a Tasks
-- panel on top of the objective tracker, in its look (below). A craft of
-- the recipe counts down its task; done, it goes. The auction house's
-- Tasks tab (AuctionTasks.lua) and the vendor's (VendorTasks.lua) buy what
-- is missing.
local IF = ImprovedForever

local TK = {}
IF.Tasks = TK

-- Reagents vendors sell (the trade supply vendors'), known before any is
-- seen at a vendor, without the Wiki's data: thread, dyes, vials, flux,
-- spices, salt, water, bleach, parchment, rods... (Forever's items, checked
-- against QuestieDB's Forever vendors; with the Wiki loaded its data
-- answers for any item)
local SEED_VENDOR = {
    2320, 2321, 4291, 8343, 14341,                  -- coarse, fine, silken, heavy silken, rune thread
    2324, 2325, 2604, 2605, 4340, 4341, 4342, 6260, 6261, 10290, -- bleach, dyes
    3371, 3372, 8925, 18256,                        -- vials
    2880, 3466, 3857, 18567,                        -- weak flux, strong flux, coal, elemental flux
    2678, 2692, 3713, 159,                          -- mild spices, hot spices, soothing spices, spring water
    4289, 4399, 4400, 11291, 272941,                -- salt, wooden stock, heavy stock, star wood, thick logs
    2928, 8923, 8924, 5173, 3777,                   -- poison supplies
    16583, 17020, 17194, 10284,                     -- demonic figurine, arcane powder, holiday spices, simple flour
    6217, 4470, 4471, 10647, 10648,                 -- copper rod, simple wood, flint and tinder, engineer's ink, parchment
}
local seed = {}
for _, id in ipairs(SEED_VENDOR) do seed[id] = true end

local function Vendors()
    IF.db.vendorItems = IF.db.vendorItems or {}
    return IF.db.vendorItems
end

-- Sold by vendors (seen at one, well known, or in the Wiki's Forever data)
function TK.FromVendor(itemID)
    if seed[itemID] or Vendors()[itemID] ~= nil then return true end
    local wiki = IF.Wiki
    return wiki and wiki.Sold and wiki.Sold(itemID) or false
end

-- What a vendor sells, kept (account-wide) as its window opens
local function LearnMerchant()
    if not (GetMerchantNumItems and GetMerchantItemID) then return end
    local known = Vendors()
    for i = 1, GetMerchantNumItems() or 0 do
        local id = GetMerchantItemID(i)
        if id then known[id] = true end
    end
end

function TK.Tasks()
    local db = IF.charDB
    -- (kept as buyTasks once: carried over)
    if db.buyTasks and not db.tasks then db.tasks = db.buyTasks end
    db.buyTasks = nil
    db.tasks = db.tasks or {}
    return db.tasks
end

local function ItemCount(itemID)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
    return GetItemCount and GetItemCount(itemID) or 0
end
TK.ItemCount = ItemCount

---------------------------------------------------------------------------
-- A recipe's reagents (the basic ones: their first choice), how many one
-- craft makes, its name and icon
---------------------------------------------------------------------------
function TK.Recipe(recipeID)
    local ui = C_TradeSkillUI
    if not (ui and ui.GetRecipeSchematic) then return nil end
    local ok, schematic = pcall(ui.GetRecipeSchematic, recipeID, false)
    if not ok or not schematic then return nil end
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local basic = not Enum.CraftingReagentType or slot.reagentType == Enum.CraftingReagentType.Basic
        local first = slot.reagents and slot.reagents[1]
        if basic and first and first.itemID and (slot.quantityRequired or 0) > 0 then
            reagents[#reagents + 1] = { itemID = first.itemID, per = slot.quantityRequired }
        end
    end
    local info = ui.GetRecipeInfo and ui.GetRecipeInfo(recipeID)
    return {
        recipeID = recipeID, reagents = reagents,
        name = schematic.name or (info and info.name) or ("recipe " .. recipeID),
        icon = info and info.icon, makes = math.max(1, schematic.quantityMin or 1),
        output = schematic.outputItemID,
    }
end

function TK.Add(recipeID, count)
    local recipe = TK.Recipe(recipeID)
    if not recipe or #recipe.reagents == 0 then
        IF.Print("that recipe needs nothing to buy.")
        return nil
    end
    local tasks = TK.Tasks()
    -- The same recipe again: its count raised
    for _, t in ipairs(tasks) do
        if t.recipeID == recipeID then
            t.count = t.count + count
            TK.Changed()
            return t
        end
    end
    local task = {
        recipeID = recipeID, name = recipe.name, icon = recipe.icon,
        count = count, made = 0, reagents = recipe.reagents,
    }
    tasks[#tasks + 1] = task
    TK.Changed()
    return task
end

function TK.Remove(task)
    local tasks = TK.Tasks()
    for i, t in ipairs(tasks) do
        if t == task then table.remove(tasks, i) end
    end
    TK.Changed()
end

-- A task done: all its crafts made (kept until removed: its recipe opened
-- from it, Quantity starts it again)
function TK.Done(task)
    return (task.made or 0) >= task.count
end

-- What all the tasks still need: { { itemID, need, have, missing, vendor } },
-- by item (two tasks wanting the same: added up), the bags' count once
function TK.Needs()
    local byItem, list = {}, {}
    for _, t in ipairs(TK.Tasks()) do
        local left = math.max(0, t.count - (t.made or 0))
        for _, r in ipairs(t.reagents) do
            local e = byItem[r.itemID]
            if not e then
                e = { itemID = r.itemID, need = 0, vendor = TK.FromVendor(r.itemID) }
                byItem[r.itemID] = e
                list[#list + 1] = e
            end
            e.need = e.need + r.per * left
        end
    end
    for _, e in ipairs(list) do
        e.have = ItemCount(e.itemID)
        e.missing = math.max(0, e.need - e.have)
    end
    return list
end

-- What one task still needs (nil: all of them, added up): { itemID, need,
-- have, missing, vendor }, only what is missing
function TK.NeedsFor(task)
    local list = {}
    if not task then
        for _, e in ipairs(TK.Needs()) do
            if e.missing > 0 then list[#list + 1] = e end
        end
        return list
    end
    local left = math.max(0, task.count - (task.made or 0))
    for _, r in ipairs(task.reagents) do
        local need = r.per * left
        local have = ItemCount(r.itemID)
        if need > have then
            list[#list + 1] = { itemID = r.itemID, need = need, have = have, missing = need - have,
                vendor = TK.FromVendor(r.itemID) }
        end
    end
    return list
end

-- A task ready to craft: the bags hold all it still needs
function TK.Ready(task)
    local left = math.max(0, task.count - (task.made or 0))
    for _, r in ipairs(task.reagents) do
        if ItemCount(r.itemID) < r.per * left then return false end
    end
    return true
end

-- The tasks as the buying lists show them: "All tasks", those still
-- getting reagents, then the ready ones under a header (done ones not:
-- they need nothing). { all } / { task } / { header, count }
function TK.TaskLines()
    local lines, ready = { { all = true } }, {}
    for _, t in ipairs(TK.Tasks()) do
        if TK.Done(t) then
        elseif TK.Ready(t) then ready[#ready + 1] = t else lines[#lines + 1] = { task = t } end
    end
    if #ready > 0 then
        lines[#lines + 1] = { header = "Ready to craft", count = #ready }
        for _, t in ipairs(ready) do lines[#lines + 1] = { task = t } end
    end
    return lines
end

-- One item's still-missing count (0: none)
function TK.Missing(itemID)
    for _, e in ipairs(TK.Needs()) do
        if e.itemID == itemID then return e.missing end
    end
    return 0
end

---------------------------------------------------------------------------
-- Listeners: told when tasks or the bags change
---------------------------------------------------------------------------
local listeners = {}
function TK.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function TK.Changed()
    if TK.RenderTracker then TK.RenderTracker() end
    for _, fn in ipairs(listeners) do fn() end
end

---------------------------------------------------------------------------
-- The Tasks panel: on top of the objective tracker ("All Objectives"), in its
-- look: its main header bar, each task a block (its name in the header
-- colour, its reagents as objective lines, a check on those had). The
-- game's tracker isn't touched: its sections can't be added to or
-- reordered from an addon without tainting its gamepad navigation
-- (ADDON_ACTION_FORBIDDEN, SetPreferredGamepadInteractTarget), so the panel
-- is a frame of ours, its own pad: with the tracker focused, L2 (free
-- there; watched, not taken) moves into the tasks: the D-pad picks one (the
-- game's cursor on it), Cross crafts it (its recipe opened, the amount
-- set), Square held removes it, Triangle opens its menu (more options:
-- quantity),
-- Circle / L2 / R2 hand the pad back. A click crafts too. Each task has a quest's status icon:
-- in progress (still to buy) or ready to craft.
---------------------------------------------------------------------------
local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    return name or (select(1, (C_Item and C_Item.GetItemInfo or GetItemInfo)(itemID))) or ("item " .. itemID)
end
TK.ItemName = ItemName

-- Its recipe in the profession window, to start crafting (a click or a
-- press: a hardware event)
function TK.OpenRecipe(task)
    if IF.InCombat() then return end
    -- (the game loads and shows its own window for it: never loaded from
    -- here, a Blizzard window loaded by addon code is tainted)
    local ui = C_TradeSkillUI
    if ui and ui.OpenRecipe then
        local ok = pcall(ui.OpenRecipe, task.recipeID)
        if not ok then IF.Print("couldn't open that recipe.") end
    end
end

local function WindowUp()
    local frame = _G.ProfessionsFrame
    return frame and frame:IsShown() or false
end

-- The recipe the profession window shows now (nil: not up, or not known)
local function ShownRecipe()
    local frame = _G.ProfessionsFrame
    local page = WindowUp() and frame.CraftingPage
    local form = page and page.SchematicForm
    if not (form and form.GetRecipeInfo) then return nil end
    local ok, info = pcall(form.GetRecipeInfo, form)
    return ok and info and info.recipeID or nil
end

-- How many the bags allow now
local function Craftable(recipeID)
    local ui = C_TradeSkillUI
    if ui.GetCraftableCount then
        local ok, n = pcall(ui.GetCraftableCount, recipeID)
        if ok and n then return n end
    end
    local got, info = pcall(ui.GetRecipeInfo, recipeID)
    return got and info and info.numAvailable or 0
end

-- The window's amount set as the craft's (its own Create All count shown)
local function ShowAmount(count)
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local box = page and page.CreateMultipleInputBox
    if box and box.SetValue then pcall(box.SetValue, box, count) end
end

-- How many to craft now: what the task still needs, as many as the bags
-- allow (0: none; said why)
local function Amount(task)
    local left = math.max(0, task.count - (task.made or 0))
    local craftable = Craftable(task.recipeID)
    local can = math.min(left, craftable)
    if can <= 0 then
        IF.Print("not enough reagents for " .. task.name .. " yet (" .. craftable .. " craftable, "
            .. left .. " left).")
    end
    return can
end

-- The amount kept: the window sets its own again (to 1) as the bags or
-- the recipe change (its ValidateControls); after that (a post-hook), ours
-- again, while it shows the task's recipe and no craft is under way (one
-- started: let go, the window counts the casts down itself)
local holding                   -- the task whose amount is kept
local HoldAmount
local hookedPage = false
function HoldAmount(task)
    holding = task
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    if page and page.ValidateControls and not hookedPage then
        hookedPage = true
        hooksecurefunc(page, "ValidateControls", function(_, skipConstrainCount)
            local t = holding
            if not t or skipConstrainCount then return end
            local recasts = C_TradeSkillUI.GetRemainingRecasts and C_TradeSkillUI.GetRemainingRecasts() or 0
            if not WindowUp() or ShownRecipe() ~= t.recipeID or recasts > 0
                or not tContains(TK.Tasks(), t) then
                holding = nil
                return
            end
            local can = math.min(math.max(0, t.count - (t.made or 0)), Craftable(t.recipeID))
            if can > 0 then ShowAmount(can) end
        end)
    end
    local can = math.min(math.max(0, task.count - (task.made or 0)), Craftable(task.recipeID))
    if can > 0 then ShowAmount(can) end
end

-- Crafting a task (a press): its recipe shown in the profession window
-- (opened: the game shows its window), its amount set to what the task
-- still needs (as many as the bags allow) once it shows (a moment later;
-- given up after 5 s); the pad handed to the game: its own Create crafts
local pending                   -- { task, deadline, seen }
local opener = CreateFrame("Frame")
opener:Hide()
opener:SetScript("OnUpdate", function(self)
    local p, now = pending, GetTime()
    if not p or IF.InCombat() then
        pending = nil
        return self:Hide()
    end
    -- (the window up a moment, on the recipe; its recipe not known there
    -- after 2 s: set all the same)
    if WindowUp() then
        p.seen = p.seen or now
        local shown = ShownRecipe()
        if now - p.seen >= 0.6 and (shown == p.task.recipeID or now - p.seen >= 2) then
            pending = nil
            self:Hide()
            local can = Amount(p.task)
            if can > 0 then HoldAmount(p.task) end
            return
        end
    end
    if now > p.deadline then
        pending = nil
        self:Hide()
        IF.Print("couldn't open " .. p.task.name .. "'s recipe.")
    end
end)

-- Cross on a task: crafting it; done: its recipe opened, no amount set
function TK.Act(task)
    if TK.Done(task) then
        if IF.InCombat() then return end
        if TK.TakePad then TK.TakePad(false) end
        return TK.OpenRecipe(task)
    end
    TK.Craft(task)
end

function TK.Craft(task)
    if IF.InCombat() then return end
    if TK.TakePad then TK.TakePad(false) end
    pending = { task = task, deadline = GetTime() + 5 }
    if ShownRecipe() == task.recipeID then pending.seen = GetTime() - 1 end
    if not pending.seen then TK.OpenRecipe(task) end
    opener:Show()
end

local W = 260
local function Color(name)
    local c = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR[name]
    if c then return c.r, c.g, c.b end
    if name == "Header" then return 1, 0.82, 0 end
    if name == "Complete" then return 0.6, 0.6, 0.6 end
    return 0.8, 0.8, 0.8
end
local function Font(fs, name, fallback)
    if _G[name] then fs:SetFontObject(_G[name]) else fs:SetFontObject(fallback) end
end
local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local panel = CreateFrame("Frame", "ImprovedForeverTasks", nil)
panel:SetParent(UIParent)
panel:SetSize(W, 32)
panel:SetFrameStrata("LOW")
panel:Hide()

-- The header: the tracker's main header bar ("All Objectives"'s), no
-- collapse button
local header = CreateFrame("Frame", nil, nil)
header:SetParent(panel)
header:SetSize(W, 32)
header:SetPoint("TOPLEFT")
local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetPoint("CENTER")
if IF.HasAtlas("ui-questtracker-primary-objective-header") then
    headerBg:SetAtlas("ui-questtracker-primary-objective-header", true)
else
    headerBg:SetSize(W, 32)
    headerBg:SetColorTexture(0.1, 0.08, 0.05, 0.7)
end
local headerText = header:CreateFontString(nil, "ARTWORK")
Font(headerText, "ObjectiveTrackerHeaderFont", GameFontNormalMed2 or GameFontNormal)
headerText:SetPoint("LEFT", 7, 0)
headerText:SetJustifyH("LEFT")
-- The button legend while the panel has the pad: the game's own look
-- (IF.InputLegend, Pad.lua), right-aligned under the panel (or its menu)
local legend = IF.InputLegend(panel)
legend:SetFrameStrata("MEDIUM")
local PANEL_PROMPTS = { { "PAD1", "A", "Craft" }, { "PAD3", "X", "Hold to Remove", hold = true }, { "PAD4", "Y", "More" },
    { "PAD2", "B", "Back" } }
-- (a task done: Cross opens its recipe)
local DONE_PROMPTS = { { "PAD1", "A", "Open" }, { "PAD3", "X", "Hold to Remove", hold = true }, { "PAD4", "Y", "More" },
    { "PAD2", "B", "Back" } }
local MENU_PROMPTS = { { "PAD1", "A", "Select" }, { "PAD2", "B", "Close" } }
local QTY_PROMPTS = { { "PAD1", "A", "Set" }, { glyph = "DPAD_LR", text = "1" }, { glyph = "DPAD_UD", text = "5" },
    { "PAD2", "B", "Back" } }
local function ShowLegend(defs, under, gap)
    if not defs then return legend:Hide() end
    legend:Set(defs)
    legend:ClearAllPoints()
    legend:SetPoint("TOPRIGHT", under or panel, "BOTTOMRIGHT", 0, -(gap or 4))
end

-- The game's own cursor, as ImprovedForever's Focus.lua copies it (its
-- RIGHT anchored at what it points at)
local function NewArrow(parent)
    local arrow = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    IF.Focus.CursorTexture(arrow)
    arrow.cursorAnim:Play()
    return arrow
end

-- In the cursor colour
local function CursorColor(arrow)
    local cursor = GAMEPAD_SMARTNAV_CURSOR_COLOR
    if cursor and cursor.GetRGBA then arrow:SetVertexColor(cursor:GetRGBA()) end
end

-- A task's status as a quest's icon: in progress (the quest number disc,
-- the in-progress mark on it) or ready to craft (the turn-in "?")
local function SetStatus(b, ready, done)
    local state = done and "done" or ready and "ready" or "progress"
    if b.state == state then return end
    b.state = state
    if done then
        -- (the tracker's own check)
        if not Atlas(b.status, "ui-questtracker-tracker-check") then
            b.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        end
        b.statusMark:Hide()
    elseif ready then
        if not Atlas(b.status, "UI-QuestIcon-TurnIn-Normal") then
            b.status:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        end
        b.statusMark:Hide()
    elseif Atlas(b.status, "UI-QuestPoi-QuestNumber") then
        b.statusMark:SetShown(Atlas(b.statusMark, "Quest-In-Progress-Icon-yellow") or false)
    else
        b.status:SetTexture("Interface\\GossipFrame\\IncompleteQuestIcon")
        b.statusMark:Hide()
    end
end

-- The blocks: a task each (its title a button: a click crafts it;
-- the game's cursor on it when picked), its status icon at its left, its
-- lines under it
local focus = { on = false, index = 1 }
local blocks = {}
local OpenMenu
local function Block(i)
    local b = blocks[i]
    if b then return b end
    b = CreateFrame("Button", nil, nil)
    -- (not a stop for the game's own cursor: the panel has its own pad, L2
    -- in; else the cursor lands on it, a reload in, as on any button)
    b.smartNavigationIgnored = true
    b:SetParent(panel)
    b.index = i
    -- (a right-click: its menu, as Triangle)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if not self.task then return end
        if button == "RightButton" then
            focus.index = self.index
            return OpenMenu(self.index)
        end
        TK.Act(self.task)
    end)
    -- (with the mouse: what a click does)
    b:SetScript("OnEnter", function(self)
        if IF.Input.Pad() or not self.task then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.task.name)
        GameTooltip:AddLine(TK.Done(self.task) and "Click: open its recipe" or "Click: craft", 1, 1, 1)
        GameTooltip:AddLine("Right-click: quantity, remove", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    b.title = b:CreateFontString(nil, "ARTWORK")
    Font(b.title, "ObjectiveTrackerLineFont", GameFontNormal)
    b.title:SetPoint("TOPLEFT", 20, 0)
    b.title:SetPoint("RIGHT", -8, 0)
    b.title:SetJustifyH("LEFT")
    b.title:SetWordWrap(true)
    b.lines = {}
    -- Square held on it (removing): a gold bar filling behind it
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetPoint("TOPLEFT", 16, 2)
    b.fill:SetPoint("BOTTOMLEFT", 16, -2)
    b.fill:SetWidth(1)
    b.fill:Hide()
    -- The status icon, centred on the title's first line, at its left
    b.status = b:CreateTexture(nil, "ARTWORK")
    b.status:SetSize(30, 30)
    b.status:SetPoint("RIGHT", b.title, "TOPLEFT", 1, -7)
    b.statusMark = b:CreateTexture(nil, "OVERLAY")
    b.statusMark:SetSize(30, 30)
    b.statusMark:SetPoint("CENTER", b.status)
    -- The cursor at the icon's left
    b.arrow = NewArrow(b)
    b.arrow:SetPoint("RIGHT", b.status, "LEFT", 2, 0)
    blocks[i] = b
    return b
end

local function Line(b, i)
    local l = b.lines[i]
    if l then return l end
    l = {}
    l.icon = b:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(14, 14)
    Atlas(l.icon, "ui-questtracker-tracker-check")
    l.dash = b:CreateFontString(nil, "ARTWORK")
    Font(l.dash, "ObjectiveTrackerLineFont", GameFontHighlight)
    l.dash:SetText(QUEST_DASH or "- ")
    l.text = b:CreateFontString(nil, "ARTWORK")
    Font(l.text, "ObjectiveTrackerLineFont", GameFontHighlight)
    l.text:SetJustifyH("LEFT")
    l.text:SetWordWrap(true)
    b.lines[i] = l
    return l
end

---------------------------------------------------------------------------
-- A task's menu (Triangle: "More"), in the look of the game's own menus
-- (its dark dropdown box, the task's name over a divider, the highlight
-- bar and the game's cursor on the picked entry): a frame of ours, the
-- game's Menu opened from addon code taints its gamepad navigation.
-- Quantity opens a submenu. (Removing: Square held on the task.)
---------------------------------------------------------------------------
local MENU_W, ENTRY_H = 200, 20
local REPEAT_DELAY, REPEAT_EVERY = 0.35, 0.08

-- The game's menu box: its atlas a little past the frame (its inset
-- 8 / 8 / 8 / 15), a title over a divider
local function MenuBox(name)
    local f = CreateFrame("Frame", name, nil)
    f:SetParent(UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    local bg = f:CreateTexture(nil, "BACKGROUND")
    if Atlas(bg, "common-dropdown-bg") then
        bg:SetPoint("TOPLEFT", -10, 3)
        bg:SetPoint("BOTTOMRIGHT", 10, -3)
        bg:SetAlpha(0.925)
    else
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
    end
    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetPoint("RIGHT", -12, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    f.divider:SetHeight(13)
    f.divider:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.divider:SetPoint("RIGHT", -12, 0)
    return f
end

local menu = MenuBox("ImprovedForeverTasksMenu")
menu.arrow = NewArrow(menu)
menu.sel, menu.entries = 1, {}

-- "Quantity"'s submenu, beside the menu (on its left: the panel is
-- on its right): how many are still to craft, as the profession window's
-- Add Task sets it (TaskCraft.lua): the D-pad left / right 1, up / down 5,
-- held to repeat; Cross sets it, Circle goes back to the menu
local qtyBox = MenuBox("ImprovedForeverTasksQuantity")
qtyBox.title:SetText("Quantity")

-- The game's gamepad focus gold, as its cursor's
local function FocusGold(tex)
    local c = GAMEPAD_SMARTNAV_CURSOR_COLOR
    if c and c.GetRGBA then tex:SetVertexColor(c:GetRGBA()) else tex:SetVertexColor(1, 0.82, 0) end
end

-- An atlas's file and coords (to draw it flipped or turned)
local function AtlasPart(name)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    if not info or not (info.file or info.filename) then return nil end
    return info.file or info.filename, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
end

-- The game's numeric input: its input box's art (InputBoxTemplate's:
-- Common-Input-Border's left, middle, right; a frame of ours, never focused,
-- the pad sets it), a scroll arrow at each end (the pad changes it)
qtyBox.input = CreateFrame("Frame", nil, nil)
qtyBox.input:SetParent(qtyBox)
qtyBox.input:SetSize(60, 20)
qtyBox.input:SetPoint("TOP", 0, -46)
do
    local box = qtyBox.input
    local INPUT = "Interface\\Common\\Common-Input-Border"
    local left = box:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(INPUT)
    left:SetTexCoord(0, 0.0625, 0, 0.625)
    left:SetSize(8, 20)
    left:SetPoint("LEFT", -5, 0)
    local right = box:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(INPUT)
    right:SetTexCoord(0.9375, 1, 0, 0.625)
    right:SetSize(8, 20)
    right:SetPoint("RIGHT")
    local middle = box:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(INPUT)
    middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
    middle:SetHeight(20)
    middle:SetPoint("LEFT", left, "RIGHT")
    middle:SetPoint("RIGHT", right, "LEFT")
    box.text = box:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    box.text:SetPoint("CENTER", -2, 0)
end
do
    -- (the arrows' frame: around the box's art)
    local line = CreateFrame("Frame", nil, nil)
    line:SetParent(qtyBox.input)
    line:SetPoint("TOPLEFT", -10, 6)
    line:SetPoint("BOTTOMRIGHT", 6, -6)
    -- (the scroll arrows: the right one as drawn, the left one mirrored)
    local afile, al, ar, at, ab = AtlasPart("gamepad-smartnavcursor-arrowscroll")
    qtyBox.arrows = {}
    for side = -1, 1, 2 do
        local arrow = line:CreateTexture(nil, "OVERLAY", nil, 1)
        qtyBox.arrows[side] = arrow
        arrow:SetSize(20, 20)
        if afile then
            arrow:SetTexture(afile)
            if side > 0 then arrow:SetTexCoord(al, ar, at, ab) else arrow:SetTexCoord(ar, al, at, ab) end
        else
            arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
            if side < 0 then arrow:SetTexCoord(1, 0, 0, 1) end
        end
        arrow:SetPoint(side > 0 and "LEFT" or "RIGHT", line, side > 0 and "RIGHT" or "LEFT", side * -4, 0)
        FocusGold(arrow)
    end
end
qtyBox.label = qtyBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
qtyBox.label:SetPoint("TOP", qtyBox.input, "BOTTOM", 0, -10)
local qty = {}                  -- { task, value, held }

-- With the mouse: the number typed, its arrows clicked, the wheel over it,
-- a Set button under it
local QtyPress, StepQty
do
    local edit = CreateFrame("EditBox", nil, nil, "InputBoxTemplate")
    edit:SetParent(qtyBox.input)
    edit:SetAllPoints(qtyBox.input)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(3)
    edit:SetJustifyH("CENTER")
    local function Typed(self)
        local n = tonumber(self:GetText())
        if n and qty.task then qty.value = math.max(1, math.min(999, n)) end
    end
    edit:SetScript("OnEditFocusLost", Typed)
    edit:SetScript("OnEnterPressed", function(self)
        Typed(self)
        self:ClearFocus()
        QtyPress("A")
    end)
    edit:Hide()
    qtyBox.edit = edit
    for side, arrow in pairs(qtyBox.arrows) do
        local b = CreateFrame("Button", nil, nil)
        b:SetParent(qtyBox)
        b:SetSize(22, 22)
        b:SetPoint("CENTER", arrow, "CENTER")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function() StepQty(side > 0 and (IsShiftKeyDown() and "UP" or "RIGHT")
            or (IsShiftKeyDown() and "DOWN" or "LEFT")) end)
        b:Hide()
        arrow.button = b
    end
    local set = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
    set:SetParent(qtyBox)
    set:SetSize(80, 22)
    set:SetText("Set")
    set:SetPoint("TOP", qtyBox.label, "BOTTOM", 0, -8)
    set:SetScript("OnClick", function()
        Typed(edit)
        QtyPress("A")
    end)
    set:Hide()
    qtyBox.set = set
    qtyBox:EnableMouseWheel(true)
    qtyBox:SetScript("OnMouseWheel", function(_, delta) StepQty(delta > 0 and "RIGHT" or "LEFT") end)
end

local OpenQty
-- An entry: its label, what it does (sub: opens a submenu, the menu kept)
local MENU = {
    { "Quantity", function(task) OpenQty(task) end, sub = true },
    -- (Square held on the task does it too)
    { "Remove", function(task)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 846)
        IF.Print("task removed: " .. task.name .. ".")
        TK.Remove(task)
    end },
}

local function RenderMenu()
    local task = menu.task
    menu.title:SetText(task and task.name or "")
    menu.sel = math.max(1, math.min(menu.sel, #MENU))
    local y = -10 - menu.title:GetStringHeight() - 2 - 13
    for i, def in ipairs(MENU) do
        local e = menu.entries[i]
        if not e then
            e = CreateFrame("Button", nil, nil)
            e.smartNavigationIgnored = true
            e:SetParent(menu)
            e:SetHeight(ENTRY_H)
            e:RegisterForClicks("LeftButtonUp")
            e.text = e:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            e.text:SetPoint("LEFT", 8, 0)
            e.highlight = e:CreateTexture(nil, "BACKGROUND")
            e.highlight:SetAllPoints()
            e.highlight:SetBlendMode("ADD")
            e.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            -- (a submenu's: the game's expand arrow at its right)
            e.expand = e:CreateTexture(nil, "ARTWORK")
            e.expand:SetPoint("RIGHT")
            e.expand:SetSize(16, 16)
            e.expand:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
            e:SetScript("OnEnter", function()
                if qtyBox:IsShown() then return end
                menu.sel = i
                RenderMenu()
            end)
            e:SetScript("OnClick", function()
                if qtyBox:IsShown() then return end
                menu.sel = i
                TK.MenuPress("A")
            end)
            menu.entries[i] = e
        end
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", 4, y)
        e:SetPoint("RIGHT", -4, 0)
        e.text:SetText(def[1])
        e.expand:SetShown(def.sub == true)
        e.highlight:SetShown(i == menu.sel)
        y = y - ENTRY_H
    end
    -- (its submenu open: the cursor there)
    menu.arrow:ClearAllPoints()
    menu.arrow:SetPoint("RIGHT", menu.entries[menu.sel], "LEFT", 2, 0)
    menu.arrow:SetShown(not qtyBox:IsShown())
    CursorColor(menu.arrow)
    menu:SetSize(math.max(MENU_W, menu.title:GetStringWidth() + 24), -y + 15)
end

local function RenderQty()
    local task = qty.task
    if not task then return end
    local mouse = not IF.Input.Pad()
    qtyBox.input.text:SetText(mouse and "" or qty.value)
    qtyBox.edit:SetShown(mouse)
    if mouse and not qtyBox.edit:HasFocus() then qtyBox.edit:SetText(qty.value) end
    for _, arrow in pairs(qtyBox.arrows) do arrow.button:SetShown(mouse) end
    qtyBox.set:SetShown(mouse)
    local made = task.made or 0
    qtyBox.label:SetText("left to craft" .. (made > 0 and (" (" .. made .. " made)") or ""))
    -- (wrapping what it shows: 12 each side, the menu's 15 under it; the
    -- input with its arrows is 108 wide; the mouse's Set button under it)
    local width = math.max(108, qtyBox.title:GetStringWidth(), qtyBox.label:GetStringWidth())
    qtyBox:SetSize(width + 24, 46 + 20 + 10 + qtyBox.label:GetStringHeight() + 15 + (mouse and 30 or 0))
end

function OpenQty(task)
    qty.task, qty.value, qty.held = task, math.max(1, task.count - (task.made or 0)), nil
    RenderQty()
    -- (its top level with its entry, as the game's submenus)
    qtyBox:ClearAllPoints()
    qtyBox:SetPoint("TOPRIGHT", menu.entries[menu.sel], "TOPLEFT", -18, 13)
    qtyBox:SetFrameLevel(menu:GetFrameLevel() + 20)
    qtyBox:Show()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    RenderMenu()
    TK.RenderTracker()
end

local function CloseQty()
    if not qtyBox:IsShown() then return end
    qtyBox:Hide()
    qty.task, qty.held = nil, nil
    RenderMenu()
    TK.RenderTracker()
end

local STEPS = { LEFT = 1, RIGHT = 1, UP = 5, DOWN = 5 }
local UP = { RIGHT = true, UP = true }

-- As Add Task's: 1 at a time, or to the next / last multiple of 5 or 20
function StepQty(name)
    local step, value = STEPS[name], qty.value
    if step == 1 then
        value = value + (UP[name] and 1 or -1)
    elseif UP[name] then
        value = (math.floor(value / step) + 1) * step
    else
        value = (math.ceil(value / step) - 1) * step
    end
    qty.value = math.max(1, math.min(999, value))
    RenderQty()
end

function QtyPress(name)
    if STEPS[name] then return StepQty(name) end
    if name == "A" then
        local task, value = qty.task, qty.value
        qtyBox:Hide()
        qty.task, qty.held = nil, nil
        menu:Hide()
        menu.task = nil
        if task and tContains(TK.Tasks(), task) then
            task.count = (task.made or 0) + value
            PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN or 875)
            TK.Changed()
        else
            TK.RenderTracker()
        end
    elseif name == "B" then
        CloseQty()
    end
end

qtyBox:SetScript("OnUpdate", function()
    local held = qty.held
    if held and GetTime() >= held.next then
        held.next = GetTime() + REPEAT_EVERY
        StepQty(held.name)
    end
end)

local function CloseMenu()
    if not menu:IsShown() then return end
    qtyBox:Hide()
    qty.task, qty.held = nil, nil
    menu:Hide()
    menu.task = nil
    TK.RenderTracker()
end

-- With the mouse: Escape, or a click away from them, closes the menu
tinsert(UISpecialFrames, menu:GetName())
tinsert(UISpecialFrames, qtyBox:GetName())
local closing = false
menu:SetScript("OnHide", function()
    if closing then return end
    closing = true
    qtyBox:Hide()
    qty.task, qty.held = nil, nil
    menu.task = nil
    TK.RenderTracker()
    closing = false
end)
qtyBox:SetScript("OnHide", function()
    qty.task, qty.held = nil, nil
    if menu:IsShown() then RenderMenu() end
end)
local away = CreateFrame("Frame")
away:RegisterEvent("GLOBAL_MOUSE_DOWN")
away:SetScript("OnEvent", function()
    if menu:IsShown() and not IF.Input.Pad() and not menu:IsMouseOver() and not qtyBox:IsMouseOver() then
        CloseMenu()
    end
end)

-- Opened at the picked task's left (the panel is at the screen's right)
function OpenMenu(index)
    local task, b = TK.Tasks()[index], blocks[index]
    if not (task and b) then return end
    menu.task, menu.sel = task, 1
    RenderMenu()
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", b.status, "TOPLEFT", -40, 6)
    menu:Show()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
    TK.RenderTracker()
end

function TK.MenuPress(name)
    if qtyBox:IsShown() then return QtyPress(name) end
    if name == "UP" or name == "DOWN" then
        menu.sel = menu.sel + (name == "UP" and -1 or 1)
        RenderMenu()
    elseif name == "A" then
        local def, task = MENU[menu.sel], menu.task
        if not (def and task) then return end
        if def.sub then return def[2](task) end
        CloseMenu()
        def[2](task)
    elseif name == "B" or name == "Y" then
        CloseMenu()
    end
end

-- Where it goes: beside the tracker, on its left. Never in the game's own
-- right column (RightManagedFrameContainer:AddManagedFrame): from addon
-- code that lays the column out tainted, resizing the game's tracker
-- (ObjectiveTrackerFrame:UpdateHeight) and so its gamepad focus (closing
-- it gets SetPreferredGamepadInteractTarget forbidden).
local function Place()
    local tracker = _G.ObjectiveTrackerFrame
    panel:ClearAllPoints()
    if tracker and tracker:GetTop() then
        panel:SetPoint("TOPRIGHT", tracker, "TOPLEFT", -12, 0)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -320, -220)
    end
end

function TK.RenderTracker()
    if not (IF.charDB and IF.db and IF.Auction) then return end
    local tasks = TK.Tasks()
    -- (recipes tracked by the game for tasks before: untracked, once)
    for _, t in ipairs(tasks) do
        if t.tracked and C_TradeSkillUI and C_TradeSkillUI.SetRecipeTracked then
            pcall(C_TradeSkillUI.SetRecipeTracked, t.recipeID, false, false)
        end
        t.tracked, t.verified = nil, nil
    end
    if #tasks == 0 or IF.Auction.Settings().tasksTracker == false then
        if focus.on then TK.TakePad(false) end
        panel:Hide()
        return
    end
    local collapsed = false
    headerText:SetText("Tasks")
    -- (its task gone, crafted or removed: the menu closed)
    if menu:IsShown() and not tContains(tasks, menu.task) then
        qtyBox:Hide()
        qty.task, qty.held = nil, nil
        menu:Hide()
        menu.task = nil
    end
    local menuOpen = menu:IsShown()
    if qtyBox:IsShown() then
        ShowLegend(focus.on and QTY_PROMPTS or nil, qtyBox, 8)
    elseif menuOpen then
        ShowLegend(focus.on and MENU_PROMPTS or nil, menu, 8)
    else
        local picked = tasks[math.max(1, math.min(focus.index, #tasks))]
        ShowLegend(focus.on and (picked and TK.Done(picked) and DONE_PROMPTS or PANEL_PROMPTS) or nil, panel, 4)
    end
    focus.index = math.max(1, math.min(focus.index, #tasks))
    local needs = {}
    for _, e in ipairs(TK.Needs()) do needs[e.itemID] = e end
    local y = -32 - 4
    for i, t in ipairs(tasks) do
        local b = Block(i)
        b.task = t
        b:SetShown(not collapsed)
        if not collapsed then
            local left = math.max(0, t.count - (t.made or 0))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
            b:SetWidth(W)
            local done = TK.Done(t)
            b.title:SetText(done and t.name or (t.name .. " × " .. left))
            b.title:SetTextColor(Color(focus.on and i == focus.index and "HeaderHighlight" or "Header"))
            -- (its menu open: the cursor in the menu)
            b.arrow:SetShown(focus.on and i == focus.index and not menuOpen)
            CursorColor(b.arrow)
            local ready = true
            local by = -b.title:GetStringHeight() - 4
            -- (done: one line, what was made, its reagents no more)
            local shownLines = 0
            if done then
                local l = Line(b, 1)
                l.icon:ClearAllPoints()
                l.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 20, by)
                l.text:ClearAllPoints()
                l.text:SetPoint("TOPLEFT", b, "TOPLEFT", 34, by)
                l.text:SetWidth(W - 44)
                l.text:SetText("Done  ·  " .. (t.made or 0) .. " made")
                l.text:SetTextColor(Color("Complete"))
                l.icon:Show()
                l.dash:Hide()
                l.text:Show()
                by = by - l.text:GetStringHeight() - 2
                shownLines = 1
            end
            for j, r in ipairs(done and {} or t.reagents) do
                local l = Line(b, j)
                local need = r.per * left
                local have = math.min(need, TK.ItemCount(r.itemID))
                local met = have >= need
                ready = ready and met
                local e = needs[r.itemID]
                l.icon:ClearAllPoints()
                l.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 20, by)
                l.dash:ClearAllPoints()
                l.dash:SetPoint("TOPLEFT", b, "TOPLEFT", 20, by)
                l.text:ClearAllPoints()
                l.text:SetPoint("TOPLEFT", b, "TOPLEFT", 34, by)
                l.text:SetWidth(W - 44)
                l.text:SetText(have .. "/" .. need .. " " .. ItemName(r.itemID)
                    .. (met and "" or ("  |cff9d917a" .. (e and e.vendor and "vendor" or "auction") .. "|r")))
                l.text:SetTextColor(Color(met and "Complete" or "Normal"))
                l.icon:SetShown(met)
                l.dash:SetShown(not met)
                l.text:Show()
                by = by - l.text:GetStringHeight() - 2
                shownLines = j
            end
            for j = shownLines + 1, #b.lines do
                local l = b.lines[j]
                l.icon:Hide()
                l.dash:Hide()
                l.text:Hide()
            end
            SetStatus(b, ready, done)
            b:SetHeight(-by)
            y = y + by - 8
        end
    end
    for i = #tasks + 1, #blocks do blocks[i]:Hide() end
    panel:SetHeight(-y)
    panel:Show()
    Place()
end

---------------------------------------------------------------------------
-- The pad: with the tracker focused, L2 into the tasks (watched); the panel
-- takes the pad then (its catcher), the game's cursor and the tracker's
-- legend hidden meanwhile (only their look: nothing of theirs written)
---------------------------------------------------------------------------
local trackerFocused = false
local catcher = CreateFrame("Frame", nil, nil)
catcher:SetParent(panel)
catcher:SetAllPoints(panel)
local hiddenPointer

function TK.TakePad(on)
    if IF.InCombat() then return end
    focus.on = on and true or false
    if not focus.on then
        -- (its menu and popup go with the pad)
        qtyBox:Hide()
        qty.task, qty.held = nil, nil
        menu:Hide()
        menu.task = nil
        TK.DropRemove()
    end
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(focus.on) end
    local tracker = _G.ObjectiveTrackerFrame
    local legend = tracker and tracker.gamepadFooter and tracker.gamepadFooter.inputLegend
    if legend then IF.Focus.Fade(legend, focus.on) end
    local nav = _G.SmartNavigation
    if focus.on and nav and nav.Pointer then
        hiddenPointer = nav.Pointer
        IF.Focus.Fade(hiddenPointer, true)
    elseif hiddenPointer then
        IF.Focus.Fade(hiddenPointer, false)
        hiddenPointer = nil
    end
    TK.RenderTracker()
end

local KEYS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT" }

-- Square held on a task: it goes once the bar is full (1.2 s; no need to
-- let go: removing isn't a protected action), the pad rumbling with it
-- (Vibration.lua); let go, or anything else pressed, before: kept
local REMOVE_HOLD = 1.2
local removing                  -- { task, start }

local function RemoveProgress()
    return removing and math.min(1, (GetTime() - removing.start) / REMOVE_HOLD) or 0
end

local function RenderRemove()
    -- (the legend's Square ring lit as it comes)
    for _, ring in ipairs(legend.rings) do ring:SetProgress(RemoveProgress()) end
    for _, b in ipairs(blocks) do
        local p = removing and b.task == removing.task and RemoveProgress() or 0
        b.fill:SetShown(p > 0)
        b.fill:SetWidth(math.max(1, (W - 16) * p))
        b.fill:SetColorTexture(1, 0.3, 0.2, 0.18 + 0.2 * p)
    end
end

function TK.DropRemove()
    if not removing then return end
    removing = nil
    if IF.Vibe then IF.Vibe.Hold(nil) end
    RenderRemove()
end

catcher:SetScript("OnUpdate", function()
    if not removing then return end
    local p = RemoveProgress()
    if IF.Vibe then IF.Vibe.Hold(p) end
    if p >= 1 then
        local task = removing.task
        TK.DropRemove()
        if IF.Vibe and IF.Vibe.Confirm then IF.Vibe.Confirm() end
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 846)
        IF.Print("task removed: " .. task.name .. ".")
        TK.Remove(task)
        return
    end
    RenderRemove()
end)

-- A press: the menu first (and its submenu: L2 / R2 step there), then the
-- panel
local function Press(name)
    -- (anything else pressed while removing: kept)
    if removing and name ~= "X" then TK.DropRemove() end
    if qtyBox:IsShown() then return TK.MenuPress(name) end
    if name == "LT" or name == "RT" then return TK.TakePad(false) end
    if menu:IsShown() then return TK.MenuPress(name) end
    local task = TK.Tasks()[focus.index]
    if name == "UP" or name == "DOWN" then
        focus.index = focus.index + (name == "UP" and -1 or 1)
        TK.RenderTracker()
    elseif name == "A" and task then
        TK.Act(task)
    elseif name == "Y" and task then
        OpenMenu(focus.index)
    elseif name == "X" and task then
        removing = { task = task, start = GetTime() }
    elseif name == "B" then
        TK.TakePad(false)
    end
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        if not name or name == "B" then return end
        Press(name)
        -- (a quantity step held: repeated)
        if qtyBox:IsShown() and STEPS[name] then qty.held = { name = name, next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if qty.held and qty.held.name == name then qty.held = nil end
        -- (Square let go before the bar is full: kept)
        if name == "X" then TK.DropRemove() end
        -- (Circle on its release: the tracker's own Circle would take it too)
        if name == "B" then Press("B") end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
end

local hooked = false
local function HookTracker()
    local tracker = _G.ObjectiveTrackerFrame
    if hooked or not (tracker and tracker.FocusGamepad) then return end
    hooked = true
    hooksecurefunc(tracker, "FocusGamepad", function() trackerFocused = true end)
    hooksecurefunc(tracker, "UnfocusGamepad", function()
        trackerFocused = false
        if focus.on then TK.TakePad(false) end
    end)
end

-- The tracker the game's focused frame now, the UI with the pad (read
-- only; the hook's flag alone can outlast a reload)
local function TrackerHasPad()
    local tracker = _G.ObjectiveTrackerFrame
    local manager = _G.GamepadMode and GamepadMode.FrameControlsManager
    if manager and manager.focusedFrame ~= nil then
        return manager.isUIFocused and manager.focusedFrame == tracker or false
    end
    return trackerFocused
end

-- (L2 counted only once seen up: one read as down as the UI loads, a
-- trigger resting a little in, is no press)
local lastL2 = true
local keys = CreateFrame("Frame")
keys:SetScript("OnUpdate", function()
    local l2 = IsKeyDown and IsKeyDown("PADLTRIGGER") or false
    if l2 and not lastL2 and trackerFocused and TrackerHasPad() and not focus.on and panel:IsShown()
        and not IF.InCombat() then
        TK.TakePad(true)
    end
    lastL2 = l2
end)

-- (beside the tracker: placed again now and then, the tracker moves with
-- Edit Mode)
local placer, waited = CreateFrame("Frame"), 0
placer:SetScript("OnUpdate", function(_, elapsed)
    waited = waited + elapsed
    if waited < 1 then return end
    waited = 0
    if panel:IsShown() then Place() end
end)

local entering = CreateFrame("Frame")
entering:RegisterEvent("PLAYER_ENTERING_WORLD")
entering:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        if not IF.db then return end
        HookTracker()
        TK.RenderTracker()
    end)
end)

-- /if tasks: each task and what it still needs
function TK.Report()
    local tasks = TK.Tasks()
    IF.Print(#tasks .. (#tasks == 1 and " task" or " tasks") .. ".")
    for _, t in ipairs(tasks) do
        IF.Print("  " .. t.name .. " × " .. math.max(0, t.count - (t.made or 0)) .. " (recipe " .. t.recipeID .. ")")
    end
    IF.Print("  panel " .. (panel:IsShown() and "shown" or "hidden") .. ", the tracker "
        .. (trackerFocused and "focused (L2: into the tasks)" or "not focused"))
    local manager = _G.GamepadMode and GamepadMode.FrameControlsManager
    IF.Print("  pad: tasks " .. (focus.on and "have it" or "don't")
        .. ", catcher " .. tostring(catcher.IsGamePadButtonEnabled and catcher:IsGamePadButtonEnabled())
        .. ", UI focused " .. tostring(manager and manager.isUIFocused)
        .. ", focused frame " .. tostring(manager and manager.focusedFrame and (manager.focusedFrame.GetName
            and manager.focusedFrame:GetName() or "?")))
end

---------------------------------------------------------------------------
-- Events: the bags (what is had), a craft (a task counted down), a vendor
-- (what it sells, learnt)
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "UNIT_SPELLCAST_SUCCEEDED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
    "GET_ITEM_INFO_RECEIVED" }) do
    pcall(events.RegisterEvent, events, event)
end
local queued = false
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if not IF.charDB then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        for _, t in ipairs(TK.Tasks()) do
            if t.recipeID == spellID then
                t.made = (t.made or 0) + 1
                if TK.Done(t) and t.made == t.count then
                    IF.Print("task done: " .. t.name .. " × " .. t.count .. ".")
                end
                TK.Changed()
                return
            end
        end
        return
    end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then LearnMerchant() end
    -- (many at once: once, a moment later)
    if queued then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        TK.Changed()
    end)
end)
