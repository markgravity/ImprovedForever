-- Talking to an NPC in a panel of ours, as Immersion lays it out: the
-- NPC's card on the left (its model, its level, a strip in its reaction's
-- colour, as our player and party cards), its name and words on the right,
-- the rewards and the quests or options to pick along the panel's bottom,
-- the answers (Accept, Decline, Goodbye...) in the game's button legend
-- under it. For the game's quest window (greeting, offer, progress,
-- reward) and gossip window, low in the middle of the screen.
--
-- The game's windows keep running unseen under ours (IF.Focus.Fade, their
-- mouse covered: UF.Cover) and keep the game's gamepad focus: its D-pad,
-- A, B and right stick are the game's, untouched. Ours only shows where its
-- cursor is (SmartNavigation's current button, on our row for it) and
-- follows its text's scrolling. With the mouse, our rows and the legend's
-- buttons answer through the quest and gossip API (AcceptQuest,
-- C_GossipInfo.SelectOptionByIndex...); the game's window then closes or
-- changes from its own events. Nothing here shows, hides or clicks a frame
-- of the game's.
--
-- With Spoken (spoken.rusty.one) installed, its voice plays the NPC's words
-- as it does for the game's windows; ours shows whether it speaks, how far,
-- and its button to stop or hear it again. Its own subtitles are faded
-- while ours show.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local ND = {}
IN.NpcDialog = ND

local WIDTH = 680
local PAD = 14                  -- (the panel's inner margin)
local AVATAR_H = 150            -- (a card's proportions, as the player's: UnitFrames.lua)
local AVATAR_W = math.floor(AVATAR_H * 0.78 + 0.5)
local TEXT_X = PAD + AVATAR_W + 16
local TEXT_W = WIDTH - TEXT_X - PAD - 44        -- (the marker and close button at the top right)
local BODY_MAX = 150            -- (the words' height before they scroll: ~8 lines)
local BOTTOM_Y = 210            -- (over the party cards and the spell diamonds)
local ROW_H = 28
local COLUMN_GAP = 8
local ITEM = 32                 -- (a reward's icon)
local GAP = 8

---------------------------------------------------------------------------
-- The panel: dark, in the game's tooltip border (as our cards)
---------------------------------------------------------------------------
local panel = CreateFrame("Frame", "ImprovedForeverNpcDialog", UIParent)
panel:SetSize(WIDTH, 200)
panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, BOTTOM_Y)
panel:SetFrameStrata("HIGH")
panel:EnableMouse(true)
panel:Hide()

local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetPoint("TOPLEFT", 3, -3)
bg:SetPoint("BOTTOMRIGHT", -3, 3)
bg:SetColorTexture(0.03, 0.03, 0.04, 0.88)
local edge = CreateFrame("Frame", nil, panel)
edge:SetAllPoints()
edge:SetFrameLevel(panel:GetFrameLevel() + 8)
UF.Border(edge)

-- The NPC's card
local avatar = UF.Avatar(panel, AVATAR_W, AVATAR_H)
avatar:SetPoint("TOPLEFT", PAD, -PAD)

local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
name:SetPoint("TOPLEFT", TEXT_X, -PAD - 2)
name:SetJustifyH("LEFT")
local status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
status:SetPoint("LEFT", name, "RIGHT", 8, 0)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetWidth(TEXT_W)
title:SetJustifyH("LEFT")
title:SetTextColor(0.95, 0.85, 0.6)

-- The words: scrolled as the game's window is (its right stick)
local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetWidth(TEXT_W)
local page = CreateFrame("Frame", nil, scroll)
page:SetWidth(TEXT_W)
scroll:SetScrollChild(page)
local body = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
body:SetPoint("TOPLEFT")
body:SetWidth(TEXT_W)
body:SetJustifyH("LEFT")
body:SetSpacing(2)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30)))
end)
local more = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
more:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)

-- Spoken's voice: how far it is, a thin bar under the words
local bar = CreateFrame("StatusBar", nil, panel)
bar:SetSize(TEXT_W, 3)
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
bar:SetStatusBarColor(1, 0.82, 0, 0.85)
bar:SetMinMaxValues(0, 1)
local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetColorTexture(1, 1, 1, 0.08)

-- (stop it, or hear it again: Spoken's own round button, made once it's
-- there)
local listen
local function ListenButton()
    if listen then return listen end
    local s = _G.Spoken
    if not (type(s) == "table" and s.CreateRoundButton) then return nil end
    local ok, button = pcall(s.CreateRoundButton, s, panel, "play")
    if not (ok and button) then return nil end
    listen = button
    listen:SetSize(20, 20)
    return listen
end

-- Top right: what the NPC has for you (a quest's marker), and the mouse's
-- close (the pad's is B, in the legend)
local marker = panel:CreateTexture(nil, "OVERLAY")
marker:SetSize(18, 18)
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
marker:SetPoint("RIGHT", close, "LEFT", -2, 0)

-- Along the bottom: a line, the rewards, the quests and options
local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetColorTexture(0.62, 0.5, 0.32, 0.45)
local itemLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
itemLabel:SetJustifyH("LEFT")
local items = CreateFrame("Frame", nil, panel)
items:SetSize(WIDTH - 2 * PAD, ITEM)
local extra = items:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local rows = CreateFrame("Frame", nil, panel)
rows:SetWidth(WIDTH - 2 * PAD)

-- The answers: the game's button legend under the panel (with the mouse,
-- its buttons there)
local legend = IF.InputLegend(panel)
legend:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -4)
legend.row:ClearAllPoints()
legend.row:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -6)

local cursor = IF.Focus.Cursor(panel)

---------------------------------------------------------------------------
-- Pools: a row (a quest or an option: its icon, its words), a reward
---------------------------------------------------------------------------
local function Lit(button)
    button.hl:SetShown(button.lit or button.pointed or false)
end

local rowPool, itemPool = {}, {}

local function Row(i)
    local r = rowPool[i]
    if r then return r end
    r = CreateFrame("Button", nil, rows)
    r:SetHeight(ROW_H)
    local base = r:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints()
    base:SetColorTexture(1, 1, 1, 0.05)
    r.hl = r:CreateTexture(nil, "BORDER")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.82, 0, 0.16)
    r.hl:Hide()
    r.accent = r:CreateTexture(nil, "ARTWORK")
    r.accent:SetPoint("TOPLEFT")
    r.accent:SetPoint("BOTTOMLEFT")
    r.accent:SetWidth(2)
    r.accent:SetColorTexture(1, 0.82, 0, 0.9)
    r.accent:Hide()
    r.hl:HookScript("OnShow", function() r.accent:Show() end)
    r.hl:HookScript("OnHide", function() r.accent:Hide() end)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 10, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.text:SetPoint("RIGHT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self) self.lit = true Lit(self) end)
    r:SetScript("OnLeave", function(self) self.lit = nil Lit(self) end)
    r:SetScript("OnClick", function(self) if self.Run then self.Run() end end)
    rowPool[i] = r
    return r
end

local function ItemButton(i)
    local b = itemPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, items)
    b:SetSize(ITEM, ITEM)
    b.chosen = b:CreateTexture(nil, "BACKGROUND")
    b.chosen:SetPoint("TOPLEFT", -3, 3)
    b.chosen:SetPoint("BOTTOMRIGHT", 3, -3)
    b.chosen:SetColorTexture(1, 0.82, 0, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.hl = b:CreateTexture(nil, "OVERLAY")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.22)
    b.hl:Hide()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetScript("OnEnter", function(self)
        self.lit = true
        Lit(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        pcall(GameTooltip.SetQuestItem, GameTooltip, self.kind, self.index)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.lit = nil
        Lit(self)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self) if self.Run then self.Run() end end)
    itemPool[i] = b
    return b
end

---------------------------------------------------------------------------
-- What the game's windows show now: a dialog { kind, native, unit, title,
-- text, rows = { { key, text, icon/atlas, Run } }, items = { { kind,
-- index, texture, count, choice } }, itemLabel, money, xp, answers = { {
-- key ("PAD1" / "PAD2"), text, Run, disabled } }, scrollFrame }
---------------------------------------------------------------------------
local choice = 0        -- (the reward picked with the mouse)

local function QuestItems(list, kind, count, label)
    local first = #list + 1
    for i = 1, count do
        local itemName, texture, number = GetQuestItemInfo(kind, i)
        if texture then
            list[#list + 1] = { kind = kind, index = i, texture = texture, count = number, name = itemName }
        end
    end
    return #list >= first and label or nil
end

local function Rewards(d)
    d.items = {}
    local choices = GetNumQuestChoices() or 0
    local label = QuestItems(d.items, "choice", choices, choices > 1 and "Choose one" or nil)
    if choices > 0 then
        for _, it in ipairs(d.items) do it.choice = true end
    end
    QuestItems(d.items, "reward", GetNumQuestRewards() or 0)
    local money = GetRewardMoney and GetRewardMoney() or 0
    local xp = GetRewardXP and GetRewardXP() or 0
    d.money = money > 0 and money or nil
    d.xp = xp > 0 and xp or nil
    d.itemLabel = label or ((#d.items > 0 or d.money or d.xp) and "Rewards" or nil)
end

-- (the chosen reward: the mouse's, else the game's window's)
local function Chosen()
    if choice > 0 then return choice end
    local info = _G.QuestInfoFrame
    return info and type(info.itemChoice) == "number" and info.itemChoice or 0
end

local function Greeting()
    local d = { kind = "greeting", text = GetGreetingText(), rows = {}, scrollFrame = _G.QuestGreetingScrollFrame }
    for i = 1, GetNumActiveQuests() or 0 do
        local _, complete = GetActiveTitle(i)
        d.rows[#d.rows + 1] = { key = "qactive:" .. i, text = (GetActiveTitle(i)),
            atlas = complete and "QuestTurnin" or "SideInProgressquesticon", Run = function() SelectActiveQuest(i) end }
    end
    for i = 1, GetNumAvailableQuests() or 0 do
        d.rows[#d.rows + 1] = { key = "qavail:" .. i, text = GetAvailableTitle(i), atlas = "QuestNormal",
            Run = function() SelectAvailableQuest(i) end }
    end
    d.answers = { { key = "PAD2", text = GOODBYE or "Goodbye", Run = CloseQuest } }
    return d
end

local function Detail()
    local d = { kind = "detail", title = GetTitleText(), text = GetQuestText(), scrollFrame = _G.QuestDetailScrollFrame }
    local objectives = GetObjectiveText and GetObjectiveText()
    if objectives and objectives ~= "" then
        d.extra = "|cffffd100" .. (QUEST_OBJECTIVES or "Objectives") .. "|r\n" .. objectives
    end
    Rewards(d)
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        d.answers = { { key = "PAD1", text = OKAY or "Okay", Run = AcknowledgeAutoAcceptQuest } }
    else
        d.answers = {
            { key = "PAD1", text = ACCEPT or "Accept", Run = AcceptQuest },
            { key = "PAD2", text = DECLINE or "Decline", Run = DeclineQuest },
        }
    end
    return d
end

local function Progress()
    local d = { kind = "progress", title = GetTitleText(), text = GetProgressText(), scrollFrame = _G.QuestProgressScrollFrame }
    d.items = {}
    d.itemLabel = QuestItems(d.items, "required", GetNumQuestItems() or 0, "Required items")
    local can = IsQuestCompletable()
    d.answers = {
        { key = "PAD1", text = CONTINUE or "Continue", Run = CompleteQuest, disabled = not can },
        { key = "PAD2", text = GOODBYE or "Goodbye", Run = CloseQuest },
    }
    return d
end

local function Reward()
    local d = { kind = "reward", title = GetTitleText(), text = GetRewardText(), scrollFrame = _G.QuestRewardScrollFrame }
    Rewards(d)
    local choices = GetNumQuestChoices() or 0
    d.answers = {
        { key = "PAD1", text = COMPLETE_QUEST or "Complete Quest", Run = function()
            local picked = choices == 1 and 1 or Chosen()
            if choices > 1 and picked <= 0 then
                UIErrorsFrame:AddMessage(ERR_QUEST_MUST_CHOOSE or "You must choose a reward.", 1, 0.1, 0.1)
                return
            end
            GetQuestReward(picked)
        end },
        { key = "PAD2", text = CANCEL or "Cancel", Run = CloseQuest },
    }
    return d
end

local function Gossip()
    local info = C_GossipInfo
    local d = { kind = "gossip", text = info.GetText(), rows = {} }
    local panel = GossipFrame and GossipFrame.GreetingPanel
    d.scrollBox = panel and panel.ScrollBox
    for _, quest in ipairs(info.GetAvailableQuests() or {}) do
        local id = quest.questID
        d.rows[#d.rows + 1] = { key = "avail:" .. tostring(id), text = quest.title,
            atlas = "QuestNormal", trivial = quest.isTrivial,
            Run = function() info.SelectAvailableQuest(id) end }
    end
    for _, quest in ipairs(info.GetActiveQuests() or {}) do
        local id = quest.questID
        d.rows[#d.rows + 1] = { key = "active:" .. tostring(id), text = quest.title,
            atlas = quest.isComplete and "QuestTurnin" or "SideInProgressquesticon",
            Run = function() info.SelectActiveQuest(id) end }
    end
    local options = info.GetOptions() or {}
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    for _, option in ipairs(options) do
        local index = option.orderIndex or 0
        d.rows[#d.rows + 1] = { key = "option:" .. tostring(index), text = option.name,
            texture = option.overrideIconID or option.icon, Run = function() info.SelectOptionByIndex(index) end }
    end
    d.answers = { { key = "PAD2", text = GOODBYE or "Goodbye", Run = info.CloseGossip } }
    return d
end

-- The window of the game's shown now and its dialog, or nil
local function Read()
    local gossip, quest = _G.GossipFrame, _G.QuestFrame
    if gossip and gossip:IsShown() and C_GossipInfo then
        local d = Gossip()
        d.native, d.unit = gossip, "npc"
        return d
    end
    if quest and quest:IsShown() then
        local d
        if _G.QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then d = Detail()
        elseif _G.QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then d = Progress()
        elseif _G.QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then d = Reward()
        elseif _G.QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then d = Greeting()
        end
        if d then d.native, d.unit = quest, "questnpc" end
        return d
    end
end

---------------------------------------------------------------------------
-- Spoken: its line for this NPC, if it has one
---------------------------------------------------------------------------
local function Spoken()
    local s = _G.Spoken
    return type(s) == "table" and s.IsCompatible and s:IsCompatible(1) and s or nil
end

local function SpokenQuests()
    local stub = _G.LibStub
    local ace = stub and stub("AceAddon-3.0", true)
    return ace and ace:GetAddon("SpokenQuests", true) or nil
end

-- (the event Spoken's quest part reads each window on)
local EVENTS = { greeting = "QUEST_GREETING", detail = "QUEST_DETAIL", progress = "QUEST_PROGRESS",
    reward = "QUEST_COMPLETE", gossip = "GOSSIP_SHOW" }

local current           -- (the dialog shown)

-- Spoken's line now for ours: the clip and whether it speaks, or nil
local function Line()
    local s = Spoken()
    if not (s and current) then return nil end
    local ok, clip = pcall(s.GetCurrent, s)
    local present = ok and type(clip) == "table" and clip.present
    if not present then return nil end
    if present.header ~= current.name and present.label ~= current.title then return nil end
    local playing = s:GetNowPlaying() == clip and not s:IsPaused()
    return clip, playing
end

local function Progressed()
    local s = Spoken()
    local ok, caption = pcall(function() return s and s.GetCaption and s:GetCaption() end)
    local f = ok and type(caption) == "table" and caption.progress
    if type(f) ~= "number" then return nil end
    local total = caption.totalWeight
    if f > 1 and type(total) == "number" and total > 0 then f = f / total end
    return math.max(0, math.min(1, f))
end

local function Listen()
    local s = Spoken()
    if not s then return end
    local clip, playing = Line()
    if clip and playing then
        s:Pause()
    elseif clip and s:IsPaused() then
        s:Resume()
    else
        local quests = SpokenQuests()
        local event = current and EVENTS[current.kind]
        if quests and event and quests[event] then pcall(quests[event], quests, event, true) end
    end
end

local spokenFaded = false
local function FadeSpoken(on)
    local s = Spoken()
    local frame = s and s.GetPlayerFrame and s:GetPlayerFrame()
    if not frame then return end
    if on ~= spokenFaded then
        spokenFaded = on
        IF.Focus.Fade(frame, on)
    end
end

---------------------------------------------------------------------------
-- Laying it out
---------------------------------------------------------------------------
local primary           -- (the cursor's spot when the game's is on none of ours: the first row)
local byKey = {}        -- (our row / reward for the game's button)

-- (the legend's lists, one per set of answers: it builds each once)
local legendSets = {}
local function Defs(answers)
    local parts = {}
    for _, a in ipairs(answers) do
        if not a.disabled then parts[#parts + 1] = a.key .. "=" .. a.text end
    end
    local key = table.concat(parts, "|")
    if not legendSets[key] then
        local defs = {}
        for _, a in ipairs(answers) do
            if not a.disabled then defs[#defs + 1] = { a.key, a.key, a.text } end
        end
        legendSets[key] = defs
    end
    return legendSets[key]
end

-- (with the mouse: the legend's button answers as the pad's would)
local function Answer(key)
    for _, a in ipairs(current and current.answers or {}) do
        if a.key == key and not a.disabled and a.Run then return a.Run() end
    end
end
legend:SetPress(function(key, down) if down then Answer(key) end end)
close:SetScript("OnClick", function() Answer("PAD2") end)

-- The NPC's reaction's colour, for its card's strip
local function Reaction(unit)
    local reaction = UnitExists(unit) and UnitReaction(unit, "player")
    local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    return c and { c.r, c.g, c.b } or UF.GOLD
end

local MARKER = { detail = "QuestNormal", reward = "QuestTurnin" }

local function Build(d)
    current = d
    wipe(byKey)
    primary = nil
    local unit = UnitExists(d.unit) and d.unit or "npc"
    d.name = UnitName(unit) or ""

    -- (the card)
    if UnitExists(unit) then
        UF.AvatarUnit(avatar, unit, true)
        UF.AvatarLook(avatar, unit, Reaction(unit), false)
    else
        avatar.model:Hide()
        avatar.portrait:Show()
        avatar.portrait:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
        avatar.level:SetText("")
        avatar.strip:SetVertexColor(UF.GOLD[1], UF.GOLD[2], UF.GOLD[3], 1)
    end
    name:SetText(d.name)
    local atlas = MARKER[d.kind]
    if d.kind == "progress" then atlas = IsQuestCompletable() and "QuestTurnin" or "SideInProgressquesticon" end
    marker:SetShown(atlas ~= nil)
    if atlas then marker:SetAtlas(atlas) end
    if ListenButton() then
        listen:SetScript("OnClick", Listen)
        listen:ClearAllPoints()
        listen:SetPoint("LEFT", status, "RIGHT", 4, 0)
    end

    -- (beside it: the quest's title, the words, Spoken's bar)
    local y = PAD + 2 + name:GetStringHeight() + 6
    title:SetText(d.title or "")
    title:SetShown(d.title ~= nil and d.title ~= "")
    if title:IsShown() then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", TEXT_X, -y)
        y = y + title:GetStringHeight() + 6
    end
    local text = d.text or ""
    if d.extra then text = text .. "\n\n" .. d.extra end
    body:SetText(text)
    local h = body:GetStringHeight()
    page:SetHeight(h)
    scroll:SetHeight(math.max(1, math.min(h, BODY_MAX)))
    scroll:SetVerticalScroll(0)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", TEXT_X, -y)
    y = y + math.min(h, BODY_MAX) + 8
    bar:SetShown(Spoken() ~= nil)
    if bar:IsShown() then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", TEXT_X, -y)
        y = y + 3 + 8
    end
    local top = math.max(PAD + AVATAR_H, y) + 10

    -- (along the bottom: the rewards or the items needed, then the quests
    -- and options)
    local list = d.items or {}
    local options = d.rows or {}
    local extras = {}
    if d.money then extras[#extras + 1] = IF.ItemValue.Money(d.money) end
    if d.xp then extras[#extras + 1] = d.xp .. " " .. (XP or "XP") end
    local hasItems = #list > 0 or #extras > 0
    divider:SetShown(hasItems or #options > 0)
    if divider:IsShown() then
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", PAD, -top)
        divider:SetPoint("TOPRIGHT", -PAD, -top)
        top = top + 10
    end
    itemLabel:SetText(d.itemLabel or "")
    itemLabel:SetShown(hasItems and d.itemLabel ~= nil)
    if itemLabel:IsShown() then
        itemLabel:ClearAllPoints()
        itemLabel:SetPoint("TOPLEFT", PAD, -top)
        top = top + itemLabel:GetStringHeight() + 6
    end
    for i, it in ipairs(list) do
        local b = ItemButton(i)
        b.kind, b.index, b.choice = it.kind, it.index, it.choice
        b.icon:SetTexture(it.texture)
        b.count:SetText(it.count and it.count > 1 and it.count or "")
        b.Run = it.choice and function()
            choice = it.index
            ND.Refresh()
        end or nil
        b:ClearAllPoints()
        b:SetPoint("LEFT", items, "LEFT", 3 + (i - 1) * (ITEM + GAP), 0)
        b:Show()
        byKey[it.kind .. ":" .. it.index] = b
    end
    for i = #list + 1, #itemPool do itemPool[i]:Hide() end
    extra:SetText(table.concat(extras, "    "))
    extra:ClearAllPoints()
    extra:SetPoint("LEFT", items, "LEFT", 3 + #list * (ITEM + GAP) + (#list > 0 and 6 or 0), 0)
    items:SetShown(hasItems)
    if hasItems then
        items:ClearAllPoints()
        items:SetPoint("TOPLEFT", PAD, -top)
        top = top + ITEM + 10
    end
    -- (one column, two past five: down the left one first, as the game's
    -- D-pad goes)
    local columns = #options > 5 and 2 or 1
    local perColumn = math.ceil(#options / columns)
    local columnW = (WIDTH - 2 * PAD - (columns - 1) * COLUMN_GAP) / columns
    for i, rowData in ipairs(options) do
        local r = Row(i)
        r.text:SetText(rowData.text or "")
        local shade = rowData.trivial and 0.6 or 1
        r.text:SetTextColor(shade, shade, shade)
        if rowData.atlas then r.icon:SetAtlas(rowData.atlas) else r.icon:SetTexture(rowData.texture) end
        r.Run = rowData.Run
        r:SetWidth(columnW)
        local column, line = math.floor((i - 1) / perColumn), (i - 1) % perColumn
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", rows, "TOPLEFT", column * (columnW + COLUMN_GAP), -line * (ROW_H + 4))
        r:Show()
        byKey[rowData.key] = r
        primary = primary or r
    end
    for i = #options + 1, #rowPool do rowPool[i]:Hide() end
    rows:SetShown(#options > 0)
    if #options > 0 then
        rows:SetHeight(perColumn * (ROW_H + 4))
        rows:ClearAllPoints()
        rows:SetPoint("TOPLEFT", PAD, -top)
        top = top + perColumn * (ROW_H + 4) + 6
    end

    panel:SetHeight(top + PAD - 10)
    legend:Set(Defs(d.answers or {}))
    ND.Refresh()
end

---------------------------------------------------------------------------
-- Each frame: the reward picked, Spoken's state, the game's scrolling and
-- its cursor on ours
---------------------------------------------------------------------------
-- (the game's cursor and scroll hint faded while on its unseen window;
-- only changed when ours changes it: the Quest Tracker fades the cursor
-- too)
local pointer = false
local function HidePointer(hide)
    if pointer == hide then return end
    pointer = hide
    local nav = _G.SmartNavigation
    if nav and nav.Pointer then IF.Focus.Fade(nav.Pointer, hide) end
    if _G.GamepadScrollBarHint then IF.Focus.Fade(GamepadScrollBarHint, hide) end
end

-- Our row or reward for the game's focused button (by what it stands for)
local function KeyOf(button)
    if not button then return nil end
    if button.GetElementData then
        local ok, data = pcall(button.GetElementData, button)
        local info = ok and type(data) == "table" and data.info
        if info then
            if data.availableQuestButton then return "avail:" .. tostring(info.questID) end
            if data.activeQuestButton then return "active:" .. tostring(info.questID) end
            if data.titleOptionButton then return "option:" .. tostring(info.orderIndex) end
        end
    end
    if button.isActive ~= nil and button.GetID then
        return (button.isActive == 1 and "qactive:" or "qavail:") .. button:GetID()
    end
    if (button.type == "choice" or button.type == "reward") and button.GetID then
        return button.type .. ":" .. button:GetID()
    end
end

local pointed
local function Point(target)
    if pointed and pointed ~= target then
        pointed.pointed = nil
        Lit(pointed)
    end
    pointed = target
    if not target then
        cursor:Hide()
        return
    end
    target.pointed = true
    Lit(target)
    cursor:Point(target)
end

local function NativeFocused()
    local m = IF.Focus.Manager()
    return m and m.isUIFocused and current and m.focusedFrame == current.native or false
end

function ND.Refresh()
    if not current then return end
    -- (rewards: the one picked marked)
    local chosen = Chosen()
    for _, b in ipairs(itemPool) do
        b.chosen:SetShown(b:IsShown() and b.choice and b.index == chosen or false)
    end
    -- (Spoken)
    if Spoken() then
        local clip, playing = Line()
        status:SetText(playing and "Speaking" or (clip and "Paused") or "")
        bar:SetValue(clip and (Progressed() or 0) or 0)
        if listen then
            if listen.SetPlaying then listen:SetPlaying(playing or false) end
            listen:Show()
        end
    else
        status:SetText("")
        if listen then listen:Hide() end
    end
end

local function FollowScroll()
    local d = current
    local range = scroll:GetVerticalScrollRange()
    more:SetText(range > 1 and IF.Input.Pad() and IF.GlyphText("PADRSTICK", 18) or "")
    if range <= 1 or not IF.Input.Pad() then return end
    local f
    if d.scrollBox and d.scrollBox.GetScrollPercentage then
        local ok, p = pcall(d.scrollBox.GetScrollPercentage, d.scrollBox)
        f = ok and p
    elseif d.scrollFrame then
        local r = d.scrollFrame:GetVerticalScrollRange()
        f = r > 0 and d.scrollFrame:GetVerticalScroll() / r or 0
    end
    if type(f) == "number" then scroll:SetVerticalScroll(range * math.max(0, math.min(1, f))) end
end

---------------------------------------------------------------------------
-- On / off: ours shown while one of the game's is, the game's faded
---------------------------------------------------------------------------
local dirty = true
local signature
local faded

local function Fade(native, on)
    if faded and faded ~= native then
        IF.Focus.Fade(faded, false)
        UF.Cover(faded, false)
        faded = nil
    end
    if native then
        if on and faded ~= native then IF.Focus.Fade(native, true) end
        if not on and faded == native then IF.Focus.Fade(native, false) end
        faded = on and native or nil
        UF.Cover(native, on)
    end
end

local function Off()
    if current then Fade(current.native, false) end
    Fade(nil)
    current, signature = nil, nil
    Point(nil)
    HidePointer(false)
    FadeSpoken(false)
    panel:Hide()
end

local function Tick()
    if not (IF.db and IN.Settings().npcDialog) then return Off() end
    local gossip, quest = _G.GossipFrame, _G.QuestFrame
    local open = (gossip and gossip:IsShown()) or (quest and quest:IsShown())
    if not open then return Off() end
    -- (a new page: read again; the game's window lays it out first)
    local panelName = gossip and gossip:IsShown() and "gossip"
        or (_G.QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() and "detail")
        or (_G.QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() and "progress")
        or (_G.QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() and "reward")
        or "greeting"
    if dirty or panelName ~= signature then
        if panelName ~= signature then choice = 0 end
        dirty = false
        signature = panelName
        local d = Read()
        if not d then return Off() end
        Build(d)
    end
    Fade(current.native, true)
    FadeSpoken(true)
    panel:Show()
    ND.Refresh()
    FollowScroll()
    -- (the game's cursor: ours on our row for it, else on the first row)
    if NativeFocused() and IF.Input.Pad() then
        local nav = _G.SmartNavigation
        local ok, button = pcall(function() return nav and nav:GetCurrentButton() end)
        local target = byKey[KeyOf(ok and button or nil) or ""]
        Point((target and target:IsShown() and target) or primary)
        HidePointer(true)
    else
        Point(nil)
        HidePointer(false)
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local ok, err = pcall(Tick)
    if not ok then
        ticker:SetScript("OnUpdate", nil)
        Off()
        IF.Print("Interface: NPC dialog stopped after an error: " .. tostring(err))
    end
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    -- (the quest log changing: only a list of quests to read again)
    if event == "QUEST_LOG_UPDATE" and not (current and (current.kind == "gossip" or current.kind == "greeting")) then
        return
    end
    dirty = true
end)

IF.Input.OnChange(function() dirty = true end)

function ND.Apply()
    dirty = true
end
