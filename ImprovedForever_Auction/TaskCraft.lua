-- The profession window's "Add Task": Cross held on a recipe of its list (a
-- prompt of ours under the window's legend), for that recipe. It opens a panel
-- beside the window that takes the pad: how many to make (the D-pad left /
-- right 1, up / down 5), each reagent's had and still to buy, where from
-- (a vendor, the auction house) and an estimate of its cost; Cross adds
-- the task (Tasks.lua), Circle backs out. Its buttons in the game's legend
-- under it (IF.InputLegend).
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local TK = IF.Tasks

local TC = {}
IF.TaskCraft = TC

local W = 440
local REPEAT_DELAY, REPEAT_EVERY = 0.35, 0.08

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedForeverTask", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedForeverTask", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(W, 300)
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetToplevel(true)
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
tinsert(UISpecialFrames, panel:GetName())
-- Where it sits: as the game's own panels, along the top beside the open
-- windows, again as they come and go (ImprovedForever's Focus.lua)
IF.Focus.Dock(panel)
local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

local icon = panel:CreateTexture(nil, "ARTWORK")
icon:SetSize(40, 40)
icon:SetPoint("TOPLEFT", 18, -36)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
name:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
local sub = K.ChatText(panel, 11, KC.help)
sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)

-- How many to make: big, between arrows
local qty = K.Text(panel, 40, KC.title)
qty:SetPoint("TOP", panel, "TOP", 0, -96)
local qtyLeft = K.Text(panel, 40, KC.focus)
qtyLeft:SetPoint("RIGHT", qty, "LEFT", -18, 0)
qtyLeft:SetText("‹")
local qtyRight = K.Text(panel, 40, KC.focus)
qtyRight:SetPoint("LEFT", qty, "RIGHT", 18, 0)
qtyRight:SetText("›")
local qtyLabel = K.ChatText(panel, 14, KC.dimGold)
qtyLabel:SetPoint("TOP", qty, "BOTTOM", 0, -8)

-- With the mouse: the number typed, its arrows clicked, the wheel over the
-- panel; the game's close button in its corner
local Step, S
local BY = IF.AuctionBuy
local qtyEdit = BY.NumberBox(panel, 90, function(n)
    if S then
        S.count = math.max(1, math.min(999, n))
        TC.Render()
    end
end)
qtyEdit:SetPoint("CENTER", qty, "CENTER", 0, 0)
local qtyLeftButton = BY.ArrowButton(panel, qtyLeft, function(fast) Step(fast and "DOWN" or "LEFT") end)
local qtyRightButton = BY.ArrowButton(panel, qtyRight, function(fast) Step(fast and "UP" or "RIGHT") end)
panel:EnableMouseWheel(true)
panel:SetScript("OnMouseWheel", function(_, delta) if S then Step(delta > 0 and "RIGHT" or "LEFT") end end)
do
    local made, close = pcall(K.NewFrame, "Button", nil, panel, "UIPanelCloseButton")
    if made and close then
        close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 1, 0)
        close:SetFrameLevel(panel:GetFrameLevel() + 10)
        close:SetScript("OnClick", function() TC.Close() end)
    end
end

-- The reagents, as a receipt: name left, had / to buy and where right
local LINE = 20
local receipt = K.NewFrame("Frame", nil, panel)
receipt:SetPoint("TOPLEFT", 22, -170)
receipt:SetPoint("TOPRIGHT", -22, -170)
local rows = {}
local function Row(i)
    if rows[i] then return rows[i] end
    local r = {
        label = K.ChatText(receipt, 13, KC.help),
        value = K.ChatText(receipt, 13, KC.cream),
    }
    r.value:SetJustifyH("RIGHT")
    rows[i] = r
    return r
end
local rule = receipt:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)
local totalLabel = K.ChatText(receipt, 14, KC.cream)
local totalValue = K.ChatText(receipt, 14, KC.title)
local profitLabel = K.ChatText(receipt, 14, KC.cream)
local profitValue = K.ChatText(receipt, 14, KC.title)
profitValue:SetJustifyH("RIGHT")
totalValue:SetJustifyH("RIGHT")

-- Its buttons in the game's legend under it (with the mouse: in the
-- panel, at its bottom right)
local legend = IF.InputLegend(panel)
legend:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -6)
local PROMPTS = {
    { "PAD1", "A", "Add Task" },
    { glyph = "DPAD_LR", text = "1" },
    { glyph = "DPAD_UD", text = "5" },
    { "PAD2", "B", "Cancel" },
}
-- (with L2 or R2 to the profession window: one table a label, kept by
-- identity for the legend)
local withSwitch = {}

---------------------------------------------------------------------------
-- What it shows: S = { recipe, count } (declared above)
---------------------------------------------------------------------------

local function Render()
    if not S then return end
    local r = S.recipe
    titleText:SetText("Add Task")
    icon:SetTexture(r.icon or 134400)
    name:SetText(r.name)
    sub:SetText(r.makes > 1 and ("makes " .. r.makes .. " each") or "")
    qty:SetText(S.count)
    qtyLabel:SetText("to make" .. (r.makes > 1 and (" (" .. S.count * r.makes .. " items)") or ""))
    local mouse = not IF.Input.Pad()
    qty:SetAlpha(mouse and 0 or 1)
    qtyEdit:SetShown(mouse)
    if mouse and not qtyEdit:HasFocus() then qtyEdit:SetText(S.count) end
    qtyLeftButton:SetShown(mouse)
    qtyRightButton:SetShown(mouse)
    -- Each reagent: had and still to buy (what other tasks want counted too)
    local others = {}
    for _, e in ipairs(TK.Needs()) do others[e.itemID] = e.need end
    local y, cost, unknown = 0, 0, false
    for i, reagent in ipairs(r.reagents) do
        local need = reagent.per * S.count
        local have = TK.ItemCount(reagent.itemID)
        local buy = math.max(0, need + (others[reagent.itemID] or 0) - have)
        buy = math.min(buy, need)
        local vendor = TK.FromVendor(reagent.itemID)
        local row = Row(i)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", 0, y)
        row.value:ClearAllPoints()
        row.value:SetPoint("TOPRIGHT", 0, y)
        row.label:SetText(need .. " × " .. TK.ItemName(reagent.itemID))
        row.value:SetText(buy == 0 and "|cff5fd35fhave all|r"
            or ("buy " .. buy .. "  |cff9d917a" .. (vendor and "vendor" or "auction") .. "|r"))
        row.label:Show()
        row.value:Show()
        y = y - LINE
        if buy > 0 then
            local unit = not vendor and IF.Auction and IF.Auction.MarketPrice(reagent.itemID)
            if vendor then
                -- (a vendor's price: what it asks, seen; a fair guess: 4x what it pays)
                local sell = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(reagent.itemID))
                unit = sell and sell > 0 and sell * 4 or nil
            end
            if unit then cost = cost + unit * buy else unknown = true end
        end
    end
    for i = #r.reagents + 1, #rows do
        rows[i].label:Hide()
        rows[i].value:Hide()
    end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", 0, y - 3)
    rule:SetPoint("TOPRIGHT", 0, y - 3)
    y = y - 9
    totalLabel:ClearAllPoints()
    totalLabel:SetPoint("TOPLEFT", 0, y)
    totalValue:ClearAllPoints()
    totalValue:SetPoint("TOPRIGHT", 0, y)
    totalLabel:SetText("Estimate cost" .. (unknown and " |cff9d917a(some prices unknown)|r" or ""))
    totalValue:SetText(IF.Auction and IF.Auction.Money(cost) or tostring(cost))
    y = y - LINE
    -- What it would bring: what it makes at its usual auction price, after
    -- the cut, less the estimate cost (what is still to buy)
    local A = IF.Auction
    local unitNet = A and r.output and A.UnitNet(r.output)
    profitLabel:ClearAllPoints()
    profitLabel:SetPoint("TOPLEFT", 0, y)
    profitValue:ClearAllPoints()
    profitValue:SetPoint("TOPRIGHT", 0, y)
    if unitNet then
        local profit = math.floor(unitNet * S.count * r.makes - cost)
        profitLabel:SetText("Estimate profit |cff9d917a(" .. S.count * r.makes .. " sold at its usual price)|r")
        profitValue:SetText((profit < 0 and "|cffff7a5c-" or "|cff5fd35f") .. A.Money(math.abs(profit)) .. "|r")
    else
        profitLabel:SetText("Estimate profit")
        profitValue:SetText("|cff9d917aunknown (no price yet)|r")
    end
    y = y - LINE
    receipt:SetHeight(-y)
    -- (with the mouse: room at its bottom for its buttons, the legend's row)
    panel:SetHeight(170 - y + 20 + (IF.Input.Pad() and 0 or 34))
    local fr, fg, fb = 1, 0.9, 0.4
    qtyLeft:SetTextColor(fr, fg, fb)
    qtyRight:SetTextColor(fr, fg, fb)
    -- (its own focus glow and legend while it has the pad, as the game's
    -- windows; L2 or R2, by the side it's on, to the profession window)
    local ours = TC.switch.focus == "ours"
    IF.Focus.Glow(panel, ours)
    legend:SetShown(ours)
    local hint = TC.switch:Hint()
    if not hint then return legend:Set(PROMPTS) end
    local id = hint[1] .. hint[3]
    if not withSwitch[id] then
        withSwitch[id] = { PROMPTS[1], PROMPTS[2], PROMPTS[3], hint, PROMPTS[4] }
    end
    legend:Set(withSwitch[id])
end
TC.Render = Render
IF.Input.OnChange(function() if panel:IsShown() then Render() end end)

function TC.Open(recipeID, count)
    local recipe = recipeID and TK.Recipe(recipeID)
    if not recipe or IF.InCombat() then return end
    if #recipe.reagents == 0 then
        return IF.Print("that recipe needs nothing to buy.")
    end
    S = { recipe = recipe, count = math.max(1, count or 1) }
    -- (where: beside the profession window, as the game's panels: IF.Focus.Dock)
    -- (over the game's More options menu, still open beneath it)
    panel:SetFrameLevel(500)
    panel:Show()
    panel:Raise()
    Render()
end

function TC.Close()
    panel:Hide()
end

---------------------------------------------------------------------------
-- The pad, while the panel is up (it takes the buttons: the profession
-- window's own wait)
---------------------------------------------------------------------------
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local KEYS = {
    PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PADDUP = "UP", PADDDOWN = "DOWN",
    PAD1 = "A", PAD2 = "B", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
}
local held

local function TakePad(on)
    if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

-- Which has the pad: the panel or the profession window (L2 / R2 between
-- them, as the game's windows pass it: ImprovedForever's Focus.lua)
TC.switch = IF.Focus.Switch(panel, {
    onChange = function(focus)
        local ours = focus == "ours"
        held = nil
        TakePad(ours)
        IF.Focus.DimNative(panel, ours)
        Render()
    end,
})

function Step(name)
    -- (the D-pad: left / right 1, up / down 5)
    local step = (name == "LEFT" or name == "RIGHT") and 1 or 5
    local up = name == "RIGHT" or name == "UP"
    local count = S.count
    if step == 1 then
        count = count + (up and 1 or -1)
    elseif up then
        count = (math.floor(count / step) + 1) * step
    else
        count = (math.ceil(count / step) - 1) * step
    end
    S.count = math.max(1, math.min(999, count))
    Render()
end

local function Press(name)
    if not S then return end
    if name == "LT" or name == "RT" then return TC.switch:Press(name) end
    if name == "A" then
        local task = TK.Add(S.recipe.recipeID, S.count)
        if task then IF.Print("task added: " .. S.recipe.name .. " × " .. S.count .. ".") end
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN or 875)
        return TC.Close()
    end
    Step(name)
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        -- (Circle on its release: the press's release would close the profession window)
        if not name or name == "B" then return end
        Press(name)
        if name ~= "A" and name ~= "LT" and name ~= "RT" then held = { name = name, next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "B" then return TC.Close() end
        if held and held.name == name then held = nil end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
end
-- (the mouse: the legend's Add Task and Cancel pressed as the pad's)
legend:SetPress(catcher)
panel:SetScript("OnUpdate", function()
    TC.switch:Update()
    if held and GetTime() >= held.next then
        held.next = GetTime() + REPEAT_EVERY
        Step(held.name)
    end
end)
panel:SetScript("OnShow", function()
    -- (R2 that opened it is still down: its release comes here, harmless)
    TC.switch.focus = "ours"
    TakePad(true)
    IF.Focus.DimNative(panel, true)
end)
panel:SetScript("OnHide", function()
    TC.switch.focus = "ours"
    TakePad(false)
    IF.Focus.DimNative(panel, false)
    held, S = nil, nil
end)

---------------------------------------------------------------------------
-- The profession window: on a recipe of its list, Cross held adds a task
---------------------------------------------------------------------------
local function CurrentRecipe()
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if not (form and form.GetRecipeInfo) then return nil end
    local got, info = pcall(form.GetRecipeInfo, form)
    return got and info and info.recipeID or nil
end

local function CurrentAmount()
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local box = page and page.CreateMultipleInputBox
    local got, value = pcall(function() return box:GetValue() end)
    return got and tonumber(value) or 1
end

-- The menu's owner: a row of the profession window's recipe list
-- Cross held on a recipe of the list opens it: "Hold to Add Task" (the
-- game's hold ring, filling) in the profession window's own legend, while
-- the cursor is on the list (there Cross only selects
-- the recipe: holding it does nothing else). Cross is only watched
-- (IsKeyDown), never bound, and nothing of ours goes into the game's UI (an
-- entry added to its More options menu, Menu.ModifyMenu, sat in the game's
-- menu data and tainted the window's closing: ADDON_ACTION_FORBIDDEN;
-- Triangle held could not be used: the game opens that menu on its press).
local ADD_KEY, ADD_HOLD = "PAD1", 0.8
local ADD_PROMPTS = { { ADD_KEY, "A", "Hold to Add Task", hold = true } }
local addLegend = IF.InputLegend(UIParent)
addLegend:SetFrameStrata("HIGH")
local addStart, addWasDown, addUsed = nil, false, false

-- The profession window's legend, while it shows (its crafting page's)
local function ProfessionLegend()
    local frame = _G.ProfessionsFrame
    local footer = frame and frame:IsShown() and frame.craftingPageFooter
    local legend = footer and footer.isShown and footer.inputLegend
    return legend and legend:IsVisible() and legend or nil
end

-- The game's cursor on a recipe of the profession window's list (read only)
local function OnRecipeList()
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    local nav = _G.SmartNavigation
    if not (list and list:IsVisible() and nav and nav.GetCurrentButton) then return false end
    local ok, button = pcall(nav.GetCurrentButton, nav)
    local frame = ok and button or nil
    while frame do
        if frame == list then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

-- The prompt inside the game's own legend, as the Destroy panel's in the
-- loot window's (Destroy.lua): a holder of ours on the profession window,
-- the game's prompt template in it, set after the last of the game's
-- prompts inside the legend box, the box widened to hold it (its width
-- given back after); the legend is read, never handed anything
local LEGEND_PAD, PROMPT_GAP = 10, 15   -- the game's legend layout (InputLegendPromptGroup.lua)
local inPrompt
local function InPrompt()
    if inPrompt == nil then
        inPrompt = false
        local frame = _G.ProfessionsFrame
        if not frame then
            inPrompt = nil
            return nil
        end
        local holder = K.NewFrame("Frame", nil, frame)
        local ok, x = pcall(function()
            local x = K.NewFrame("Frame", nil, holder, "InputPromptOneIconWithTextTemplate")
            x:SetPromptInputIconKey(1, _G.GAMEPAD_FACE_BOTTOM or ADD_KEY)
            x:SetPromptText("Hold to Add Task")
            x:EnablePrompt()
            x.ring = IF.HoldRing(x, x:GetInputIconControl(1), 32)
            return x
        end)
        if ok and x then
            holder.prompt, holder.ring = x, x.ring
            holder:Hide()
            inPrompt = holder
        end
    end
    return inPrompt or nil
end

-- Puts it after the last of the game's prompts, the box widened to hold it
local function PlaceInLegend(legend)
    local holder = InPrompt()
    local box = legend.promptContainerFrame
    if not (holder and box) then return false end
    local width = box:GetWidth()
    -- The game laid its legend out again (or a new box): that's its width
    if holder.box ~= box or not holder.setWidth or math.abs(width - holder.setWidth) > 0.5 then
        holder.box, holder.baseWidth = box, width
        holder.prompt:ClearAllPoints()
        holder.prompt:SetPoint("TOPLEFT", box, "TOPLEFT", width - LEGEND_PAD + PROMPT_GAP, -LEGEND_PAD)
    end
    holder:SetFrameLevel(box:GetFrameLevel() + 2)
    holder.setWidth = holder.baseWidth + PROMPT_GAP + holder.prompt:GetWidth()
    box:SetWidth(holder.setWidth)
    holder:Show()
    return true
end

local function GiveBackWidth()
    local holder = inPrompt
    if not holder or not holder:IsShown() then return end
    holder:Hide()
    -- The box's own width back, unless the game has set it since
    local box = holder.box
    if box and holder.setWidth and math.abs(box:GetWidth() - holder.setWidth) <= 0.5 then
        box:SetWidth(holder.baseWidth)
    end
    holder.box, holder.setWidth = nil, nil
end

local function SetAddRing(p)
    for _, ring in ipairs(addLegend.rings) do ring:SetProgress(p) end
    if inPrompt then inPrompt.ring:SetProgress(p) end
end

-- With the mouse: an Add Task button of ours under the profession window
-- (our own frame, only placed against the game's), for the recipe shown
local addButton = K.NewFrame("Button", "ImprovedForeverAddTaskButton", UIParent, "UIPanelButtonTemplate")
addButton:SetSize(120, 24)
addButton:SetFrameStrata("HIGH")
addButton:SetText("Add Task")
addButton:SetScript("OnClick", function()
    local recipe = CurrentRecipe()
    if recipe then TC.Open(recipe, CurrentAmount()) end
end)
addButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Add Task")
    GameTooltip:AddLine("Make this recipe a task: what it still needs to buy, tracked beside the quests.", 1, 1, 1, true)
    GameTooltip:Show()
end)
addButton:SetScript("OnLeave", function(self)
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end)
addButton:Hide()

local addShown = false              -- the prompt up last frame (the press checked against it)
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
    local frame = _G.ProfessionsFrame
    if not (frame and frame:IsShown()) then
        if addLegend:IsShown() then addLegend:Hide() end
        if addButton:IsShown() then addButton:Hide() end
        GiveBackWidth()
        addStart, addWasDown, addShown = nil, false, false
        return
    end
    local mouseAdd = not IF.Input.Pad() and not panel:IsShown() and not IF.InCombat() and CurrentRecipe() ~= nil
    if mouseAdd and not addButton:IsShown() then
        addButton:ClearAllPoints()
        addButton:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
        addButton:Show()
    elseif not mouseAdd and addButton:IsShown() then
        addButton:Hide()
    end
    local down = IsKeyDown and IsKeyDown(ADD_KEY) or false
    -- (a press counts if the prompt was up just before it: the cursor on
    -- the list then)
    if down and not addWasDown and addShown then addStart, addUsed = GetTime(), false end
    if not down then
        if addStart and IF.Vibe then IF.Vibe.Hold(nil) end
        addStart, addUsed = nil, false
    end
    addWasDown = down
    local holding = addStart and not addUsed
    local legend = not panel:IsShown() and not IF.InCombat() and CurrentRecipe() and OnRecipeList()
        and ProfessionLegend()
    if legend then
        -- (in the game's legend, else in our own box under it)
        if PlaceInLegend(legend) then
            addLegend:Hide()
        else
            GiveBackWidth()
            addLegend:Set(ADD_PROMPTS)
            addLegend:ClearAllPoints()
            addLegend:SetPoint("TOPRIGHT", legend, "BOTTOMRIGHT", 0, -4)
        end
    elseif not holding then
        -- (while held it stays where it was, its ring filling)
        addLegend:Hide()
        GiveBackWidth()
    end
    addShown = legend and true or false
    if holding then
        local p = math.min(1, (GetTime() - addStart) / ADD_HOLD)
        SetAddRing(p)
        if IF.Vibe then IF.Vibe.Hold(p) end
        if p >= 1 then
            addUsed = true
            SetAddRing(0)
            if IF.Vibe then IF.Vibe.Confirm() end
            TC.Open(CurrentRecipe(), CurrentAmount())
        end
    else
        SetAddRing(0)
    end
end)

-- /if addprobe: why "Hold to Add Task" shows or not (each check's answer)
function TC.Probe()
    local frame = _G.ProfessionsFrame
    local legend = ProfessionLegend()
    local x = inPrompt
    IF.Print("addprobe: window " .. tostring(frame and frame:IsShown()) .. ", recipe " .. tostring(CurrentRecipe())
        .. ", cursor on list " .. tostring(OnRecipeList()) .. ", legend " .. tostring(legend ~= nil)
        .. (legend and (", wrap " .. tostring(legend.wrapAroundRowWidth)) or ""))
    if legend then
        local box = legend.promptContainerFrame
        IF.Print("addprobe: box width " .. tostring(box and math.floor(box:GetWidth())) .. ", right "
            .. tostring(box and box:GetRight() and math.floor(box:GetRight())) .. ", strata "
            .. tostring(box and box:GetFrameStrata()) .. " level " .. tostring(box and box:GetFrameLevel()))
    end
    if x then
        local pr = x.prompt
        IF.Print("addprobe: prompt shown " .. tostring(x:IsShown()) .. " visible " .. tostring(pr:IsVisible())
            .. ", width " .. math.floor(pr:GetWidth()) .. ", left " .. tostring(pr:GetLeft() and math.floor(pr:GetLeft()))
            .. ", strata " .. x:GetFrameStrata() .. " level " .. x:GetFrameLevel() .. ", alpha " .. x:GetEffectiveAlpha())
    else
        IF.Print("addprobe: prompt " .. (inPrompt == false and "couldn't be made (template)" or "not made yet"))
    end
    IF.Print("addprobe: fallback box shown " .. tostring(addLegend:IsShown()))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() TC.Close() end)
