-- Quest progress ("Necrotic Crystal Fragment: 6/12") in the header's place
-- and look (HeaderSlot.lua), in turn with the rest: what has the place
-- goes out, then this comes in, holds a few seconds and goes, and what
-- was there comes back. The rule is the objective's progress, a gold line
-- out from the middle both ways over a dark track, filling to the new
-- count; on it a diamond with the game's quest mark (a check once done);
-- under them the objective big, its count small and white, its quest
-- small in gold. A count more while it shows: changed in place, held
-- again. In a fight with a living target it waits (a while, then it's
-- dropped: old news).
-- The game writes these, its errors and its other notices into one frame
-- (UIErrorsFrame) right where the header is. That frame is drawn at 0
-- (IF.Focus.Fade, never touched) and what it's given is read as it comes
-- (hooksecurefunc on its AddMessage, after the game's): quest progress
-- here, everything else into a copy of ours in its font and timing, under
-- the header. A line the game keeps secret goes to the copy unread.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot

local QP = {}
IN.QuestProgress = QP

local TILE = 30
local LINE_H = 3
local HOLD = 3                          -- (seconds shown once in, or since the last count)
local STALE = 8                         -- (seconds it may wait for the place before it's dropped)
local FILL_TIME = 0.5
local SLIDE = 10
local GOLD = HS.GOLD
local ERRORS_UNDER = 125                -- (the copy of the game's notices: this far under the rule)
local MARK, CHECK = "QuestNormal", "QuestLog-icon-checkmark-yellow"

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function On()
    return IF.db and IN.Settings().questProgress and true or false
end

---------------------------------------------------------------------------
-- The banner
---------------------------------------------------------------------------
local banner = CreateFrame("Frame", "ImprovedForeverQuestProgress", UIParent)
banner:SetSize(2 * HS.RULE_W, 140)
banner:SetFrameStrata("LOW")
banner:EnableMouse(false)
banner:SetPoint("CENTER", HS.Origin, "CENTER")
banner:Hide()

local tile = HS.Tile(banner, TILE)
local radius = tile.across / 2 * 0.9
local reach = HS.RULE_W - radius

-- (the line: two halves out from the diamond's sides, a dark track, the
-- gold fill, a flash over it)
local halves = {}
for i = 1, 2 do
    local side = i == 1 and -1 or 1
    local holder = CreateFrame("Frame", nil, banner)
    holder:SetHeight(LINE_H)
    holder:SetPoint(side < 0 and "RIGHT" or "LEFT", banner, "CENTER", side * radius, 0)
    local track = holder:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.5)
    local fill = holder:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(LINE_H)
    fill:SetPoint(side < 0 and "RIGHT" or "LEFT")
    fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local flash = holder:CreateTexture(nil, "OVERLAY")
    flash:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 2)
    flash:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, -2)
    flash:SetColorTexture(1, 0.95, 0.7, 1)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    halves[i] = { holder = holder, fill = fill, flash = flash }
end
tile:SetFrameLevel(halves[1].holder:GetFrameLevel() + 4)

local title = HS.Text(banner, HS.FONT, HS.NAME_SIZE, GOLD[1], GOLD[2], GOLD[3])
title:SetWidth(2 * HS.RULE_W)
local count = HS.Text(banner, GameFontHighlight and GameFontHighlight:GetFont(), HS.SMALL_SIZE, 1, 1, 1)
count:SetPoint("TOP", title, "BOTTOM", 0, -4)
local quest = HS.Text(banner, GameFontNormal and GameFontNormal:GetFont(), HS.SMALL_SIZE, 1, 0.82, 0)
quest:SetPoint("TOP", count, "BOTTOM", 0, -4)
quest:SetWidth(2.2 * HS.RULE_W)

local function Mark(done)
    local atlas = done and CHECK or MARK
    if IF.HasAtlas and not IF.HasAtlas(atlas) then atlas = CHECK end
    tile.icon:SetAtlas(atlas)
    tile.icon:SetSize(tile.across * 0.5, tile.across * 0.5)
end

---------------------------------------------------------------------------
-- What it shows: the latest count, its quest found in the log
---------------------------------------------------------------------------
-- (the quest whose objectives name `label`)
local function QuestOf(label)
    local ok, name = pcall(function()
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    if type(o.text) == "string" and not Secret(o.text) and o.text:find(label, 1, true) then
                        return info.title
                    end
                end
            end
        end
    end)
    return ok and type(name) == "string" and name or nil
end

local goal, since, heldFrom = 0, 0, nil
local fillFrom, fillTo, fillAt, shownFill, done = 0, 0, 0, 0, false

local function Show(label, have, need, isDone)
    local newTo = need and need > 0 and math.min(1, have / need) or (isDone and 1 or 0)
    -- (a new objective starts from its last count; the same one from where it is)
    if title:GetText() ~= label or goal == 0 then
        shownFill = need and need > 0 and math.max(0, have - 1) / need or 0
    end
    fillFrom, fillTo, fillAt = shownFill, newTo, nil
    done = isDone or (need and have >= need) or false
    title:SetText(label)
    count:SetText(need and ("%d / %d"):format(have, need) or (done and (COMPLETE or "Complete") or ""))
    quest:SetText(QuestOf(label) or "")
    Mark(done)
    if goal == 0 then since = GetTime() end
    goal, heldFrom = 1, nil
end

-- (a fight with a living target: the place stays the fight's)
local function Fighting()
    if not (IF.InCombat() and UnitExists("target")) then return false end
    local ok, dead = pcall(UnitIsDead, "target")
    return not (ok and not Secret(dead) and dead)
end

local Ease, Pop = HS.Ease, HS.Pop

local function Step()
    local now = GetTime()
    local p = HS.Presence("progress")
    if goal == 1 and p < 1 and not heldFrom and now - since > STALE then goal = 0 end
    if p >= 1 and not heldFrom then heldFrom = now end
    if goal == 1 and heldFrom and now - heldFrom > HOLD then goal = 0 end
    if p <= 0 then
        banner:Hide()
        return
    end
    banner:Show()
    local line = Ease(p, 0, 0.6)
    for _, h in ipairs(halves) do h.holder:SetWidth(math.max(1, reach * line)) end
    local come = Ease(p, 0.15, 0.75)
    tile:SetScale(math.max(0.01, come < 1 and Pop(come) or 1))
    tile:SetAlpha(come)
    local words = Ease(p, 0.4, 1)
    title:ClearAllPoints()
    title:SetPoint("TOP", banner, "CENTER", 0, -HS.NAME_GAP - SLIDE * (1 - words))
    for _, s in ipairs({ title, count, quest }) do s:SetAlpha(words) end
    -- (the count's fill, once the line is out; a flash as it fills, a done
    -- one's flashing on)
    if p >= 0.6 and not fillAt then fillAt = now end
    local t = fillAt and math.min(1, (now - fillAt) / FILL_TIME) or 0
    shownFill = fillFrom + (fillTo - fillFrom) * Ease(t)
    local flash = fillAt and (1 - t) or 0
    if done then flash = math.max(flash, 0.35 + 0.35 * math.sin(now * 6)) end
    for _, h in ipairs(halves) do
        h.fill:SetWidth(math.max(0.01, reach * line * shownFill))
        h.flash:SetAlpha(flash * 0.7)
    end
end

HS.Add("progress", 3.5, {
    wants = function() return goal == 1 and On() and not Fighting() end,
    rule = function() return false end,
})

---------------------------------------------------------------------------
-- What the game's notice frame is given
---------------------------------------------------------------------------
-- (its quest progress, by the message's kind where the client names it,
-- else by its look: "Name: 3/8", "Name (Complete)", "Objective Complete.")
local PROGRESS = {}
for _, name in ipairs({ "LE_GAME_ERR_QUEST_ADD_KILL_SII", "LE_GAME_ERR_QUEST_ADD_ITEM_SII",
    "LE_GAME_ERR_QUEST_ADD_FOUND_SII", "LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII", "LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S",
    "LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE" }) do
    local v = _G[name]
    if type(v) == "number" then PROGRESS[v] = true end
end

local COMPLETE_S = ERR_QUEST_OBJECTIVE_COMPLETE_S and ERR_QUEST_OBJECTIVE_COMPLETE_S:gsub("%%s", "(.+)")
    :gsub("%(Complete%)", "%%(Complete%%)")

local function Parse(text, id)
    if type(text) ~= "string" or Secret(text) or Secret(id) then return nil end
    local label, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)$")
    if label then return label, tonumber(have), tonumber(need) end
    if COMPLETE_S then
        local done = text:match("^" .. COMPLETE_S .. "$")
        if done then return done, nil, nil, true end
    end
    if PROGRESS[id] or text == ERR_QUEST_UNKNOWN_COMPLETE then return text, nil, nil, true end
    return nil
end

-- (the copy of the game's notices: its font, timing and order, under the
-- header)
local notices = CreateFrame("MessageFrame", "ImprovedForeverNotices", UIParent)
notices:SetSize(512, 60)
notices:SetPoint("TOP", HS.Origin, "CENTER", 0, -ERRORS_UNDER)
notices:SetFrameStrata("DIALOG")
notices:EnableMouse(false)
notices:SetFontObject(ErrorFont or GameFontNormalLarge)
notices:SetJustifyH("CENTER")
notices:SetInsertMode("TOP")
notices:SetTimeVisible(2)
notices:SetFadeDuration(0.5)
if notices.SetFadePower then notices:SetFadePower(3) end

local broken

local function OnAdd(_, text, r, g, b, a, id)
    if not On() or broken then return end
    local label, have, need, done = Parse(text, id)
    if label then
        local ok, err = pcall(Show, label, have, need, done)
        if not ok then IF.Print("Immersion: quest progress: " .. tostring(err)) end
        return
    end
    pcall(notices.AddMessage, notices, text, r, g, b, a, id)
end

local hooked
local function Hook()
    if hooked or not UIErrorsFrame then return end
    hooked = true
    hooksecurefunc(UIErrorsFrame, "AddMessage", OnAdd)
    -- (a repeat the game flashes in place: its time again in ours too)
    if UIErrorsFrame.ResetMessageFadeByID and notices.ResetMessageFadeByID then
        hooksecurefunc(UIErrorsFrame, "ResetMessageFadeByID", function(_, id)
            if On() then pcall(notices.ResetMessageFadeByID, notices, id) end
        end)
    end
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if broken then return end
    local ok, err = pcall(Step)
    if not ok then
        broken, goal = true, 0
        banner:Hide()
        if UIErrorsFrame then IF.Focus.Fade(UIErrorsFrame, false) end
        notices:Hide()
        IF.Print("Immersion: quest progress stopped after an error: " .. tostring(err))
    end
end)

function QP.Apply()
    Hook()
    local on = On() and not broken
    if UIErrorsFrame then IF.Focus.Fade(UIErrorsFrame, on) end
    notices:SetShown(on)
    if not on then goal = 0 end
end

-- /if progresstest: a made-up objective counting up, then done
function QP.Test()
    if not On() then
        IF.Print("Quest progress: off (the Immersion tab's Quest progress).")
        return
    end
    local n = 0
    C_Timer.NewTicker(1, function()
        n = n + 1
        Show("Necrotic Crystal Fragment", n, 4, n >= 4)
    end, 4)
    notices:AddMessage(ERR_OUT_OF_RANGE or "Out of range.", 1, 0.1, 0.1, 1)
end

IF.OnLogin(QP.Apply)
