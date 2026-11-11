-- The focused (super-tracked) quest's summary as a card at the screen's top left, on top of the stack, the tooltip and the buff notice under it while it shows, the world
-- tooltip's mirror (Tooltip.lua, Card.lua). Swipe the touchpad left to right to show it, again to take
-- it away (right to left is not used here). Only the finger's position is read (IF.Touch.FingerPosition), no
-- button taken. Setting questPeek.
local IF = ImprovedForever
local IN = IF.Interface

local WRAP = 46
local DONE, GREY, GOLD = { 0.35, 0.9, 0.35 }, { 0.6, 0.6, 0.6 }, { 1, 0.82, 0 }
local ICON = "Interface\\GossipFrame\\ActiveQuestIcon"

local card = IN.Card.New("ImprovedForeverQuestPeek", { seamless = true })
IN.QuestPeek = { card = card }     -- (the first of the stack: the tooltip and the buff notice sit under it)

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

local MAX_STORY = 30    -- (lines)

local function Content(id)
    local index = C_QuestLog.GetLogIndexForQuestID(id)
    local info = index and C_QuestLog.GetInfo(index)
    if not info then return nil end
    local lines = { { lt = info.title or C_QuestLog.GetTitleForQuestID(id) or "", lr = GOLD[1], lg = GOLD[2], lb = GOLD[3] } }
    local sig = { id }
    local story = Story(id)
    if story then
        local before = #lines
        for paragraph in story:gmatch("[^\r\n]+") do
            if #lines > before and #lines - before < MAX_STORY then lines[#lines + 1] = { lt = " " } end
            Wrap(paragraph, lines, 0.85, 0.85, 0.85)
        end
        while #lines - before > MAX_STORY do lines[#lines] = nil end
        sig[#sig + 1] = "story"
        lines[#lines + 1] = { lt = " " }
    end
    local first = #lines + 1
    local complete = C_QuestLog.IsComplete(id)
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        if o.text and o.text ~= "" then
            local c = o.finished and GREY or { 1, 1, 1 }
            Wrap(o.text, lines, c[1], c[2], c[3])
            sig[#sig + 1] = o.text
        end
    end
    -- (no objective of the game's yet: the data's own summary of the quest)
    if #lines < first and IF.GameData and IF.GameData.QuestObjectivesText then
        for _, text in ipairs(IF.GameData.QuestObjectivesText(id) or {}) do
            Wrap(text, lines, GREY[1] + 0.25, GREY[2] + 0.25, GREY[3] + 0.25)
            sig[#sig + 1] = text
        end
    end
    if complete then
        lines[#lines + 1] = { lt = _G.QUEST_WATCH_QUEST_READY or "Ready to turn in", lr = DONE[1], lg = DONE[2], lb = DONE[3] }
        sig[#sig + 1] = "done"
    end
    local color = info.level and GetQuestDifficultyColor and GetQuestDifficultyColor(info.level) or GOLD
    return {
        key = tostring(id), sig = table.concat(sig, "|"), lines = lines, tint = GOLD,
        -- (the giver's portrait; the quest mark when an object or item gives it, or its look is unknown)
        portrait = function(icon)
            local npc = IF.GameData and IF.GameData.QuestGiverNpc and IF.GameData.QuestGiverNpc(id)
            if npc and IF.Book and IF.Book.Portrait(npc, icon) then
                icon:SetTexCoord(0, 1, 0, 1)
            else
                IN.Card.Icon(icon, ICON)
            end
        end,
        level = info.level and { text = tostring(info.level), color = { color.r or color[1], color.g or color[2], color.b or color[3] } } or nil,
    }
end

local SWIPE = 0.4       -- (how far across the pad, -1..1, counts as a swipe)
local fromX, swiped, peek = nil, false, false

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
    -- (left to right, again and again: shows, hides; right to left is left for another action)
    if x - fromX >= SWIPE then
        peek, swiped = not peek, true
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    if IF.db and IF.db.peekLog then IF.db.peekLog = nil end     -- (the probe's log, cleared once)
    local on = IF.db and IN.Settings().questPeek ~= false
    if on then WatchSwipe() else peek = false end
    local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    card:Dock({})
    card:Update(elapsed, peek and id and id ~= 0 and Content(id) or nil)
end)
