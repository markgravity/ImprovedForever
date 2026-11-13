-- The quest tracker of the Immersion look: the focused quest as a tooltip card of its own, the
-- other tracked quests together in a group card under it, at the screen's top left, then the unit / object tooltip and the buff notice under them
-- (they always have their room: MaxLines). The focused (super-tracked) quest comes first, its way in
-- the diamond; swipe left to right to open it in full (story, every objective), again to shut it. The
-- old tracker (QuestTracker's) is out of sight while this shows. The world tooltip's mirror
-- (Tooltip.lua, Card.lua). The swipe: only the finger's position is read (IF.Touch.FingerPosition),
-- no button taken; right to left is not used here. The pad: L1 + R1 + D-pad Up (see PadFocus below).
-- Setting questPeek.
local IF = ImprovedForever
local IN = IF.Interface

local WRAP = 46
local DONE, GREY, GOLD = { 0.35, 0.9, 0.35 }, { 0.6, 0.6, 0.6 }, { 1, 0.82, 0 }
local ICON = "Interface\\GossipFrame\\ActiveQuestIcon"

-- (two cards: the focused quest's on its own, the others together in a group; they sit one under another, then the unit /
-- object tooltip and the buff notice under the last one showing: Card.Dock)
local MAX_CARDS = 2     -- (the focused quest's, and one group of the others')
local cards, above = {}, {}
for i = 1, MAX_CARDS do
    cards[i] = IN.Card.New("ImprovedForeverQuestPeek" .. i, { seamless = true, always = true, strata = "LOW" })
    above[i] = {}
    for j = 1, i - 1 do above[i][j] = cards[j] end
end
local card = cards[1]
IN.QuestPeek = { card = card, cards = cards }
-- (the old tracker's pad mirror (QuestTracker's Pad.lua) stands down while this one is the tracker)
function IN.QuestPeek.Replaces()
    return IF.db ~= nil and IN.Settings().questPeek ~= false
end

local function Wrap(text, out, r, g, b)
    local line = ""
    for word in text:gmatch("%S+") do
        if line ~= "" and #line + #word + 1 > WRAP then
            out[#out + 1] = { lt = line, lr = r, lg = g, lb = b }
            line = word
        else
            line = line == "" and word or (line .. " " .. word)
        end
    end
    if line ~= "" then out[#out + 1] = { lt = line, lr = r, lg = g, lb = b } end
end

-- The quest's own story (the quest log's text: GetQuestLogQuestText reads the selected quest, so
-- ours is selected for the read and the player's put back). Read once per quest, kept.
local stories = {}
local function Story(id)
    if stories[id] ~= nil then return stories[id] or nil end
    if not (C_QuestLog.SetSelectedQuest and GetQuestLogQuestText) then return nil end
    local before = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    local ok, text = pcall(function()
        C_QuestLog.SetSelectedQuest(id)
        return GetQuestLogQuestText()
    end)
    if before and before ~= id then pcall(C_QuestLog.SetSelectedQuest, before) end
    if ok and type(text) == "string" and text ~= "" and not (type(issecretvalue) == "function" and issecretvalue(text)) then
        stories[id] = text
        return text
    end
    -- (not read: tried again the next time it shows, not at once every frame)
    stories[id] = false
    return nil
end

-- Room: the unit / object tooltip and the buff notice come first, under this card, and always have
-- their space: this card takes what's left of the screen's height (its top is the stack's top), the
-- other quests giving way first, then the story, ended with an ellipsis.
local RESERVE, BOTTOM, LINE_H, CHROME, MIN_STORY = 330, 40, 17, 40, 2
local CARD_STEP = 80
local RESERVE_MIN = 40    -- (the least room at the bottom, with no chat to read)
local CHAT_TAB, CHAT_GAP = 22, 12   -- (the chat's tab over its frame; the gap kept between it and the cards)
-- The room kept for what sits under the cards: the unit tooltip at its tallest (Tooltip.lua keeps it to
-- TIP_LINES lines), always, so the cards never change size as the tooltip comes and goes
local TIP_ROOM = 200
local function TipRoom() return TIP_ROOM end
local MIN_TOP = 0.03     -- (the least top padding, a share of the screen's height)
-- The height kept free at the screen's bottom, in the cards' own units: the tooltip's room, or the
-- chat's (its top, its tab above, and the unit tooltip's room over them), whichever is more
local function Reserve()
    local scale = IN.Card.Scale()
    local keep = RESERVE_MIN + TipRoom()
    local chat = _G.ChatFrame1
    local top = chat and chat:GetTop()
    if top and not (issecretvalue and issecretvalue(top)) then
        local k = chat:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if not (issecretvalue and issecretvalue(k)) then
            keep = math.max(RESERVE_MIN, (top * k + CHAT_TAB + CHAT_GAP) / scale + TipRoom())
        end
    end
    return keep
end

local function MaxLines()
    local h = UIParent:GetHeight()
    -- (the cards' scale makes a line that much of the screen)
    local scale = IN.Card.Scale()
    local avail = h * (1 - IN.Card.Top()) / scale - Reserve()
    return math.max(4, math.floor((avail - CHROME) / LINE_H))
end

-- (the tour's stand-in quest, while the arrow's demo runs: Onboarding.lua)
local function Demo()
    return { key = "demo", sig = "demo", tint = GOLD,
        lines = { { lt = "A Threat Within", lr = GOLD[1], lg = GOLD[2], lb = GOLD[3] } },
        portrait = function(icon) IN.Card.Icon(icon, ICON) end }
end

local WHITE = { 1, 1, 1 }
local DIST = { 0.45, 0.9, 0.8 }     -- (the yards left: teal, apart from the gold, the blue and the greys)
local OPEN = { 0.55, 0.85, 1 }   -- (an open objective in the detail: light blue, apart from the story's grey and the title's gold)
local BLANK = " "

-- The quests being tracked, the focused one first, then in the tracker's order (the watch list, kept
-- in the tracker's sort: QuestTracker's Sort.lua)
local function Quests(focus)
    local list = {}
    if focus and C_QuestLog.GetLogIndexForQuestID(focus) then list[1] = focus end
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if id and id ~= focus and C_QuestLog.GetLogIndexForQuestID(id) then list[#list + 1] = id end
    end
    return list
end

local function Title(id)
    local index = C_QuestLog.GetLogIndexForQuestID(id)
    local info = index and C_QuestLog.GetInfo(index)
    return info and info.title or C_QuestLog.GetTitleForQuestID(id) or "", info
end

-- A quest's objectives as lines, `all` of them (else the first not done only, its first line)
local function Objectives(id, all, sig)
    local out = {}
    if C_QuestLog.IsComplete(id) then
        out[1] = { lt = _G.QUEST_WATCH_QUEST_READY or "Ready to turn in", lr = DONE[1], lg = DONE[2], lb = DONE[3] }
        sig[#sig + 1] = "done"
        if not all then return out end
    end
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        if o.text and o.text ~= "" and (all or not o.finished) then
            local c = o.finished and GREY or (all and OPEN or WHITE)
            Wrap(o.text, out, c[1], c[2], c[3])
            sig[#sig + 1] = o.text
            if not all then
                while #out > 1 do out[#out] = nil end
                return out
            end
        end
    end
    if #out == 0 and IF.GameData and IF.GameData.QuestObjectivesText then
        for _, text in ipairs(IF.GameData.QuestObjectivesText(id) or {}) do
            Wrap(text, out, GREY[1] + 0.25, GREY[2] + 0.25, GREY[3] + 0.25)
            sig[#sig + 1] = text
            if not all then
                while #out > 1 do out[#out] = nil end
                return out
            end
        end
    end
    return out
end

-- One quest's card: its title, its first open objective; the focused one's way (waypoint words
-- under the title, the arrow and yards in the diamond) and, opened, its story and every objective.
local function Build(id, focused, expanded, budget)
    local name, info = Title(id)
    local sig = { id, expanded and "open" or "shut" }
    local head = { { lt = name, lr = GOLD[1], lg = GOLD[2], lb = GOLD[3] } }
    local QA = IN.QuestArrow
    local way = focused and QA and QA.Info and QA.Info() or nil
    -- (the yards left under the name, the waypoint's words under them)
    if way then
        local text = IN_GAME_NAVIGATION_RANGE and IN_GAME_NAVIGATION_RANGE:format(way.short) or (way.short .. " yds")
        head[#head + 1] = { lt = text, lr = DIST[1], lg = DIST[2], lb = DIST[3] }
        sig[#sig + 1] = way.short
        if way.words then
            head[#head + 1] = { lt = way.words, lr = GOLD[1], lg = GOLD[2], lb = GOLD[3] }
            sig[#sig + 1] = way.words
        end
    end
    local goals = Objectives(id, expanded, sig)
    local story = {}
    if expanded then
        local text = Story(id)
        if text then
            for paragraph in text:gmatch("[^\r\n]+") do
                if #story > 0 then story[#story + 1] = { lt = BLANK } end
                Wrap(paragraph, story, 0.85, 0.85, 0.85)
            end
        end
        local room = math.max(MIN_STORY, budget - #head - #goals - (#story > 0 and 1 or 0))
        if #story > room then
            while #story > room do story[#story] = nil end
            while #story > 1 and story[#story].lt == BLANK do story[#story] = nil end
            story[#story].lt = story[#story].lt:gsub("%s+$", "") .. "…"
        end
        if #story > 0 then
            sig[#sig + 1] = "story" .. #story
            story[#story + 1] = { lt = BLANK }
        end
    end
    local lines = {}
    for _, group in ipairs({ head, story, goals }) do
        for _, l in ipairs(group) do lines[#lines + 1] = l end
    end
    -- (the diamond holds the way's arrow (QuestArrow.lua) while there's a way to show, else the giver's
    -- portrait (the quest mark when an object or item gives it, or its look is unknown); the badge
    -- the quest's level)
    local level
    if info and info.level then
        local c = GetQuestDifficultyColor and GetQuestDifficultyColor(info.level) or GOLD
        level = { text = tostring(info.level), color = { c.r or c[1], c.g or c[2], c.b or c[3] } }
    end
    return {
        key = tostring(id), sig = table.concat(sig, "|") .. (way and "|way" or "|noway") .. "|" .. tostring(info and info.level),
        lines = lines, tint = GOLD, level = level, ids = { id }, rowOf = { [id] = 1 }, endOf = { [id] = #lines },
        portrait = function(icon)
            if way then
                icon:SetTexture(nil)
                return
            end
            local npc = IF.GameData and IF.GameData.QuestGiverNpc and IF.GameData.QuestGiverNpc(id)
            if npc and IF.Book and IF.Book.Portrait(npc, icon) then
                icon:SetTexCoord(0, 1, 0, 1)
            else
                IN.Card.Icon(icon, ICON)
            end
        end,
    }
end

-- The others' group: one card, each quest a row (its title, its first open objective), as many as
-- fit in `budget` lines, the rest counted. The diamond holds the quest mark, the badge their number.
local function BuildGroup(quests, budget, open)
    local lines, sig = {}, { "group" }
    local shown = 0
    local ids, rowOf, endOf = {}, {}, {}
    for i = 2, #quests do
        local id = quests[i]
        local name = Title(id)
        local goal = Objectives(id, id == open, sig)
        if id == open then
            -- (opened: its story too, a few lines of it)
            local text, story = Story(id), {}
            for paragraph in (text or ""):gmatch("[^\r\n]+") do
                if #story > 0 then story[#story + 1] = { lt = BLANK } end
                Wrap(paragraph, story, 0.85, 0.85, 0.85)
            end
            while #story > 8 do story[#story] = nil end
            if #story == 8 then story[8].lt = story[8].lt:gsub("%s+$", "") .. "…" end
            for i = #story, 1, -1 do table.insert(goal, 1, story[i]) end
            sig[#sig + 1] = "open" .. id
        end
        local need = 1 + #goal + (shown > 0 and 1 or 0)
        if #lines + need > budget - 2 and i < #quests then
            -- (no room for this one and the rest: say how many are left out)
            break
        end
        if shown > 0 then lines[#lines + 1] = { lt = BLANK } end
        lines[#lines + 1] = { lt = name, lr = 1, lg = 0.95, lb = 0.8 }
        ids[#ids + 1], rowOf[id] = id, #lines
        sig[#sig + 1] = id
        for _, l in ipairs(goal) do lines[#lines + 1] = l end
        endOf[id] = #lines
        shown = shown + 1
    end
    local others = #quests - 1
    if shown < others then
        lines[#lines + 1] = { lt = BLANK }
        lines[#lines + 1] = { lt = ("+%d more"):format(others - shown), lr = GREY[1], lg = GREY[2], lb = GREY[3] }
        sig[#sig + 1] = "more" .. (others - shown)
    end
    return {
        key = "group", sig = table.concat(sig, "|"), lines = lines, tint = GOLD, ids = ids, rowOf = rowOf, endOf = endOf,
        level = { text = tostring(others), color = { 1, 1, 1 } },
        portrait = function(icon) IN.Card.Icon(icon, ICON) end,
    }
end

---------------------------------------------------------------------------
-- The pad on the tracker: L1 + R1 + D-pad Up (watched, never taken: IsKeyDown) puts the pad on it,
-- as on one of the game's windows. A catcher frame takes the buttons while it has them (D-pad up /
-- down between the quests, A makes one the focused quest, X opens / shuts the focused quest's
-- detail, B gives the pad back); the game's cursor is drawn on the quest the pad is on, and the
-- game's own focus dimmed, as with our other windows. The game's tracker is left alone.
---------------------------------------------------------------------------
local fromX, swiped, expanded = nil, false, nil   -- (the swipe's, and the id of the quest open in full)
local since, built = 1, {}   -- (the cards' contents, worked out a few times a second)
local owner = {}                 -- (the key of our DimNative)
local pad = { on = false, sel = nil }
local cursor
local lastCombo = false

local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetSize(1, 1)
catcher:SetPoint("CENTER")

local function Ids()
    local ids, rowOf, cardOf, endOf = {}, {}, {}, {}
    for c = 1, MAX_CARDS do
        local b = built[c]
        for _, id in ipairs(b and b.ids or {}) do
            ids[#ids + 1], rowOf[id], cardOf[id], endOf[id] = id, b.rowOf[id], c, b.endOf[id]
        end
    end
    return ids, rowOf, cardOf, endOf
end

-- The buttons, in the game's legend above the cards while the pad is on the tracker
local legend = IF.InputLegend(UIParent)
legend:SetFrameStrata("TOOLTIP")
-- (placed on the screen, not on the card: the card may be hidden or not laid out yet; the top left
-- corner's place (Card.Dock), a little above it. The mouse's buttons (legend.row) there too)
local function PlaceLegend()
    local h = UIParent:GetHeight()
    for _, f in ipairs({ legend, legend.row }) do
        f:ClearAllPoints()
        local scale = IN.Card.Scale()
        f:SetScale(scale)
        f:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", (IN.Card.CORNER_X - 6) / scale, (-h * IN.Card.Top() + 18) / scale)
    end
end
PlaceLegend()
legend:SetPress(catcher)
local PROMPTS = {
    { glyph = "DPAD_UD", text = "Select", pad = true },
    { "PAD1", "A", "Focus quest" },
    { "PAD3", "X", "Details" },
    { "PAD2", "B", "Back" },
}

-- The quest the pad is on: gold behind its lines, fading out to both sides (two halves, as the
-- header's rule)
local function Wash(c)
    local card = cards[c]
    if card.wash then return card.wash end
    local w = CreateFrame("Frame", nil, card.panel)
    w:SetFrameLevel(math.max(0, card.panel:GetFrameLevel() - 1))     -- (under the words, over the band: as the band is)
    w.left, w.right = w:CreateTexture(nil, "BACKGROUND", nil, 3), w:CreateTexture(nil, "BACKGROUND", nil, 3)
    local function Half(t, from, to)
        t:SetColorTexture(1, 0.78, 0.25, 1)
        if not pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(1, 0.78, 0.25, from), CreateColor(1, 0.78, 0.25, to)) then
            t:SetAlpha(0.2)
        end
    end
    Half(w.left, 0, 0.4)
    Half(w.right, 0.4, 0)
    w.left:SetPoint("TOPLEFT")
    w.left:SetPoint("BOTTOMRIGHT", w, "BOTTOM")
    w.right:SetPoint("TOPLEFT", w, "TOP")
    w.right:SetPoint("BOTTOMRIGHT")
    w:Hide()
    card.wash = w
    return w
end

-- The game's tracker, in focus under ours: its legend (and the cursor, the glow) out of sight while
-- ours has the pad, looked at again now and then (its focus comes a moment after the press)
local faded = {}
local function HideNative(on)
    local list = {}
    for _, name in ipairs({ "ObjectiveTrackerFrame", "IFObjectiveTrackerFrame" }) do
        local tracker = _G[name]
        local footer = tracker and tracker.gamepadFooter
        -- (the footer is a mixin holding the legend frame: its legend, and the footer where it is a frame)
        list[#list + 1] = footer and footer.inputLegend
        list[#list + 1] = footer
    end
    for _, f in ipairs(list) do
        if f and f.GetObjectType then
            if on then
                faded[f] = true
                IF.Focus.Fade(f, true)
            elseif faded[f] then
                faded[f] = nil
                IF.Focus.Fade(f, false)
            end
        end
    end
    if not on then
        for f in pairs(faded) do
            IF.Focus.Fade(f, false)
            faded[f] = nil
        end
    end
end

local function Leave()
    if not pad.on then return end
    pad.on, pad.sel = false, nil
    if not InCombatLockdown() then catcher:EnableGamePadButton(false) end
    IF.Focus.DimNative(owner, false)
    HideNative(false)
    legend:Set(nil)
    for c = 1, MAX_CARDS do if cards[c].wash then cards[c].wash:Hide() end end
    if cursor then cursor:Hide() end
end

local function Enter()
    if pad.on or InCombatLockdown() or not IF.Input.Pad() then return end
    local ids = Ids()
    if #ids == 0 then return end
    pad.on, pad.sel = true, ids[1]
    catcher:EnableGamePadButton(true)
    IF.Focus.DimNative(owner, true)
    pad.dimAt = GetTime()
    PlaceLegend()
    legend:Set(PROMPTS)
end

local function Move(step)
    local ids = Ids()
    for i, id in ipairs(ids) do
        if id == pad.sel then
            pad.sel = ids[math.max(1, math.min(#ids, i + step))]
            -- (the pad moved off the quest open in full: it shuts)
            if expanded and expanded ~= pad.sel then
                expanded = nil
                since = 1
            end
            return
        end
    end
    pad.sel = ids[1]
end

local KEYS = { PADDUP = "UP", PADDDOWN = "DOWN", PAD1 = "A", PAD3 = "X", PAD2 = "B" }
-- (B goes on to the game too: D-pad Up put the game's own (unseen) tracker in focus as well, and its
-- B takes it out, so one press leaves both. The other buttons stay ours)
catcher:SetScript("OnGamePadButtonDown", function(self, button)
    local name = KEYS[button]
    self:SetPropagateKeyboardInput(name == "B")
    if name == "B" and pad.on then return Leave() end
    if not (name and pad.on) then return end
    if name == "UP" then Move(-1)
    elseif name == "DOWN" then Move(1)
    elseif name == "A" then
        if pad.sel and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(pad.sel)
        end
        since = 1
    elseif name == "X" then
        expanded = (expanded ~= pad.sel) and pad.sel or nil
        since = 1
    end
end)
catcher:SetScript("OnGamePadButtonUp", function(self, button)
    -- (Circle on its release, so the press doesn't reach what's under)
    self:SetPropagateKeyboardInput(KEYS[button] == "B")
end)
-- (setting a handler switches the frame's input on: off until wanted)
catcher:EnableGamePadButton(false)

-- Each frame: the combo to enter, the cursor on the quest, the reasons to leave
local function WatchPad(on)
    local combo = IsKeyDown("PADLSHOULDER") and IsKeyDown("PADRSHOULDER") and IsKeyDown("PADDUP")
    if on and combo and not lastCombo and not pad.on then Enter() end
    lastCombo = combo and true or false
    if not pad.on then return end
    if not on or InCombatLockdown() or not IF.Input.Pad() then return Leave() end
    if GetTime() - (pad.dimAt or 0) > 0.3 then
        pad.dimAt = GetTime()
        IF.Focus.DimNative(owner, true)
    end
    HideNative(true)
    local ids, rowOf, cardOf, endOf = Ids()
    if #ids == 0 then return Leave() end
    local found
    for _, id in ipairs(ids) do if id == pad.sel then found = true end end
    if not found then pad.sel = ids[1] end
    -- (the wash on the quest's lines: its title row to its last, in its card only)
    for c = 1, MAX_CARDS do
        local w = cards[c].wash
        if w and c ~= cardOf[pad.sel] then w:Hide() end
    end
    local c = cards[cardOf[pad.sel]]
    local row = c and c.rows[rowOf[pad.sel]]
    local last = c and c.rows[endOf[pad.sel]]
    if row and last and row.left:IsShown() and c.panel:GetRight() and row.left:GetLeft() then
        local w = Wash(cardOf[pad.sel])
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", row.left, "TOPLEFT", -50, 5)
        w:SetPoint("BOTTOMRIGHT", last.left, "BOTTOMLEFT", c.panel:GetRight() - row.left:GetLeft() + 40, -5)
        w:Show()
    elseif cardOf[pad.sel] and cards[cardOf[pad.sel]].wash then
        cards[cardOf[pad.sel]].wash:Hide()
    end
    if row and row.left:IsShown() then
        if not cursor then
            cursor = IF.Focus.Cursor(UIParent)
            cursor:SetFrameStrata("TOOLTIP")
            cursor:SetFrameLevel(60)
        end
        if pad.pointed ~= row.left or not cursor:IsShown() then
            pad.pointed = row.left
            cursor:Point(row.left)
        end
    elseif cursor then
        pad.pointed = nil
        cursor:Hide()
    end
end

local SWIPE = 0.4       -- (how far across the pad, -1..1, counts as a swipe)

local function WatchSwipe()
    local touch = IF.Touch
    if not touch then return end
    -- (two values: x, y; (0, 0) when the finger is up)
    local x, y = touch.FingerPosition()
    if not x or (x == 0 and (y or 0) == 0) then
        fromX, swiped = nil, false
        return
    end
    fromX = fromX or x
    if swiped then return end
    -- (left to right, again and again: opens the focused quest, shuts it; right to left is left for another action)
    if x - fromX >= SWIPE then
        local f = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
        if f and f ~= 0 then expanded = (expanded ~= f) and f or nil end
        swiped = true
    end
end

-- The old tracker (QuestTracker's, bottom right) out of sight while ours shows: its frame, ours, at
-- alpha 0 (the game's own tracker runs unseen under it as always)
local oldHidden = false
local function HideOld(hide)
    local old = _G.IFObjectiveTrackerFrame
    if not old or hide == oldHidden then return end
    oldHidden = hide
    old:SetAlpha(hide and 0 or 1)
end

---------------------------------------------------------------------------
-- The mouse: a click on a quest's lines makes it the focused quest (again: opens / shuts it in full),
-- a right click gives its menu (QuestTracker's list, as the game's tracker). Hit areas of ours over
-- each quest's rows; the cards themselves take no mouse.
---------------------------------------------------------------------------
local function QuestMenu(id)
    local Menu = _G.IFObjectiveTrackerMenu
    if not (Menu and Menu.CreateContextMenu) or InCombatLockdown() then return end
    Menu.CreateContextMenu(UIParent, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(id) or "")
        if C_SuperTrack.GetSuperTrackedQuestID() ~= id then
            root:CreateButton(SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(id) end)
        else
            root:CreateButton(STOP_SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
        end
        root:CreateButton(expanded == id and HIDE or SHOW, function()
            expanded = (expanded ~= id) and id or nil
            since = 1
        end)
        root:CreateButton(OBJECTIVES_VIEW_IN_QUESTLOG, function() QuestUtil.OpenQuestDetails(id) end)
        root:CreateButton(OBJECTIVES_SHOW_QUEST_MAP, function() QuestMapFrame_OpenToQuestDetails(id) end)
        if QuestUtil.CanRemoveQuestWatch() then
            root:CreateButton(OBJECTIVES_STOP_TRACKING, function() C_QuestLog.RemoveQuestWatch(id) end)
        end
        if C_QuestLog.IsPushableQuest(id) and IsInGroup() then
            root:CreateButton(SHARE_QUEST, function() QuestUtil.ShareQuest(id) end)
        end
        root:CreateButton(SHARE_IN_CHAT, function()
            local link = GetQuestLink(id)
            if link and not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
        end)
        root:CreateButton(ABANDON_QUEST_ABBREV, function() QuestMapQuestOptions_AbandonQuest(id) end)
    end)
end

local function QuestClick(id, button)
    if button == "RightButton" then return QuestMenu(id) end
    if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID and ChatFrameUtil.TryInsertQuestLinkForQuestID(id) then
        return
    end
    local focus = C_SuperTrack.GetSuperTrackedQuestID()
    if focus == id then
        expanded = (expanded ~= id) and id or nil
    else
        C_SuperTrack.SetSuperTrackedQuestID(id)
    end
    since = 1
end

local hits = {}
local function Hit(c, id)
    local list = hits[c]
    if not list then list = {} hits[c] = list end
    local b = list[id]
    if not b then
        b = CreateFrame("Button", nil, cards[c].panel)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button) QuestClick(self.id, button) end)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 0.82, 0.3, 0.08)
        b.hl:Hide()
        b:SetScript("OnEnter", function(self) self.hl:Show() end)
        b:SetScript("OnLeave", function(self) self.hl:Hide() end)
        list[id] = b
    end
    b.id = id
    return b
end

local function PlaceHits(c, content)
    local card = cards[c]
    local list = hits[c]
    local live = {}
    if content and content.ids and card.panel:IsShown() then
        for _, id in ipairs(content.ids) do
            local first, last = card.rows[content.rowOf[id]], card.rows[content.endOf[id]]
            if first and last and first.ty and last.ty then
                local b = Hit(c, id)
                live[id] = true
                local top, bottom = first.ty + 3, last.ty - (last.h or 14) - 3
                if b.top ~= top or b.bottom ~= bottom then
                    b.top, b.bottom = top, bottom
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", card.panel, "TOPLEFT", 0, top)
                    b:SetPoint("TOPRIGHT", card.panel, "TOPRIGHT", 0, top)
                    b:SetHeight(top - bottom)
                end
                b:Show()
            end
        end
    end
    for id, b in pairs(list or {}) do
        if not live[id] then b:Hide() end
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    if IF.db and IF.db.peekLog then IF.db.peekLog = nil end     -- (the probe's log, cleared once)
    local on = IF.db and IN.Settings().questPeek ~= false
    if on then WatchSwipe() else expanded = nil end
    HideOld(on and true or false)
    local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    local focus = id ~= 0 and id or nil
    WatchPad(on and true or false)
    -- (the cards' contents worked out a few times a second, drawn every frame)
    since = since + elapsed
    if since >= 0.2 or built.expanded ~= expanded or built.on ~= on then
        since = 0
        built.expanded, built.on = expanded, on
        local quests = on and Quests(focus) or {}
        -- (the top padding gives way, down to MIN_TOP, as far as the quests need the room above)
        local H, scale = UIParent:GetHeight(), IN.Card.Scale()
        IN.Card.Squeeze(nil)
        if #quests > 0 then
            local keep = Reserve()
            local firstFull = Build(quests[1], quests[1] == focus, quests[1] == expanded, 200)
            local need = #firstFull.lines * LINE_H + CHROME + 14
            if #quests > 1 then
                local group = BuildGroup(quests, 200, expanded)
                need = need + #group.lines * LINE_H + CHROME
            end
            local top = 1 - (need + keep) * scale / H
            if top < IN.Card.UserTop() then IN.Card.Squeeze(math.max(MIN_TOP, top)) end
        end
        -- (the group takes what height is left under the focused quest's card)
        local avail = UIParent:GetHeight() * (1 - IN.Card.Top()) / IN.Card.Scale() - Reserve()
        local first = quests[1] and Build(quests[1], quests[1] == focus, quests[1] == expanded, MaxLines()) or nil
        built[1] = first
        local left = math.floor((avail - (first and (#first.lines * LINE_H + CHROME + 14) or 0) - CHROME) / LINE_H)
        built[2] = (#quests > 1 and left >= 4) and BuildGroup(quests, left, expanded) or nil
    end
    local QA = IN.QuestArrow
    for i = 1, MAX_CARDS do
        local content = built[i]
        if i == 1 and QA then
            -- (the arrow reads the way only while the first card shows; the tour's stand-in shows it too)
            QA.wanted = content ~= nil or QA.demo
            if QA.demo and not content then content = Demo() end
        end
        cards[i]:Dock(above[i])
        cards[i]:Update(elapsed, content)
        PlaceHits(i, content)
    end
end)
