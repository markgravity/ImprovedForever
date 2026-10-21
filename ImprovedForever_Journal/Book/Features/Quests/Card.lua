-- A task done on Your Diary's plates (ours, not Social Diary's): its mark,
-- an ink tick where it was handed in (Plate.RegisterMark), and its card in
-- the plate's margin (JourneyMargin.Register): a paper strip
-- (UI/Paper/Strip.lua) with the tick and the reward's icon over the task's
-- name in the diary's hand, and who it was for and what it paid under it.
-- The moments are BookData.lua's ("quest": one a task handed in, m.quest
-- its event, Journal.lua's).

local addonName, ns = ...

local Style = ns.Style
local HAND = Style.NEUTON_ITALIC

local QuestCard = {}
ns.QuestCard = QuestCard

-- The tick on the plate: a short stroke and a long one, `width` px, in
-- ink, on a halo of paper.
local TICK = { short = { -4, 0, -1, 3 }, long = { -1, 3, 5, -4 }, width = 1.6, halo = 15 }
-- The card: the picture's room over the name `h` tall, the tick `tick`
-- px and the reward's icon `icon` px, `gap` apart; the name at the hand's
-- smaller size `small` where it is long, cut with an ellipsis where even
-- that will not fit; its tape `tapeAt` along, its turn at most `turn`.
local CARD = { h = 22, tick = 18, icon = 20, gap = 6, under = 3, small = 14, tapeAt = 0.3, turn = 1.6 }

local function Icon(id)
    local get = C_Item and C_Item.GetItemIconByID or _G.GetItemIcon
    local ok, icon = pcall(get, id)
    icon = ok and ns.Plain(icon) or nil
    if icon == nil or icon == 0 or icon == "" then return nil end
    return icon
end

-- "1s 75c"
local function Money(c)
    if not c or c <= 0 then return nil end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if k > 0 then parts[#parts + 1] = k .. "c" end
    return table.concat(parts, " ")
end

local function ItemName(id)
    local get = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local ok, name = pcall(get, id)
    name = ok and ns.Plain(name) or nil
    return type(name) == "string" and name or nil
end

-- What goes under the name: who it was for, what it paid
function QuestCard.What(q)
    local bits = {}
    local who = q.ender or q.giver
    if type(who) == "string" and who ~= "" then bits[#bits + 1] = "for " .. who end
    local money = Money(q.money)
    if money then bits[#bits + 1] = money end
    return #bits > 0 and table.concat(bits, " \194\183 ") or "done"
end

function QuestCard.Tip(q)
    local lines = { "Done" .. (q.ender and (", for " .. q.ender) or "") .. "." }
    if q.reward then lines[#lines + 1] = "Reward: " .. (ItemName(q.reward) or "an item") end
    local money = Money(q.money)
    if money then lines[#lines + 1] = "Paid " .. money end
    if q.xp then lines[#lines + 1] = q.xp .. " experience" end
    return q.name or "A task", lines
end

function QuestCard.New(parent)
    local hooks = {}
    local card = ns.UI.PaperStrip(parent, hooks)
    card.tick = card:CreateTexture(nil, "ARTWORK", nil, 3)
    card.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    card.tick:SetDesaturated(true)
    card.edge = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.icon = card:CreateTexture(nil, "ARTWORK", nil, 3)
    for _, t in ipairs({ card.tick, card.edge, card.icon }) do
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
    end

    function card:SetQuest(q, seed)
        self.quest = q
        self.iconFile = q.reward and Icon(q.reward) or nil
        self:SetNote({ name = q.name or "A task", what = QuestCard.What(q), strong = true, seed = seed,
            tapeAt = CARD.tapeAt, turn = CARD.turn,
            tip = function() return Style.TipList(QuestCard.Tip(q)) end })
    end

    -- The name at the hand's size, else the smaller, else cut to fit
    function hooks.plan(self, note, width)
        local l, _, r = self:Pad()
        local inside = width - l - r
        local w = CARD.tick + (self.iconFile and (CARD.gap + CARD.icon) or 0)
        note.picture = { w = w, h = CARD.h, gap = CARD.under }
        local name = self.name
        name:SetFontObject(Style.FONT.noteWritten)
        name:SetText(note.name or "")
        local function Wide() return (name:GetUnboundedStringWidth() or 0) > inside end
        if Wide() then name:SetFont(HAND, CARD.small, "") end
        if Wide() then
            local words = {}
            for word in (note.name or ""):gmatch("%S+") do words[#words + 1] = word end
            while #words > 1 do
                words[#words] = nil
                name:SetText(table.concat(words, " ") .. "\226\128\166")
                if not Wide() then break end
            end
        end
        self.overfull = w > inside
    end

    function hooks.draw(self)
        local INK = Style.INK
        for _, line in ipairs(self:WhatLines()) do line:SetTextColor(INK[1], INK[2], INK[3]) end
        local pic = self.picture
        self.tick:SetShown(pic ~= nil)
        self.icon:SetShown(pic ~= nil and self.iconFile ~= nil)
        self.edge:SetShown(pic ~= nil and self.iconFile ~= nil)
        if not pic then return end
        local left = pic.lx - pic.w / 2
        local S = Style.INK_STRONG
        self.tick:SetVertexColor(S[1], S[2], S[3], 1)
        self:Lay(self.tick, left + CARD.tick / 2, pic.ly, CARD.tick, CARD.tick)
        if self.iconFile then
            local x = left + CARD.tick + CARD.gap + CARD.icon / 2
            self.edge:SetColorTexture(INK[1], INK[2], INK[3], 0.55)
            self:Lay(self.edge, x, pic.ly, CARD.icon + 2, CARD.icon + 2)
            self.icon:SetTexture(self.iconFile)
            self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            self:Lay(self.icon, x, pic.ly, CARD.icon, CARD.icon)
        end
    end

    return card
end

-- The tick where a task was handed in, kept (plate.questMarks) for its
-- card's leader. After the hunts' marks (40, 50), before the deaths on
-- the road (60).
ns.UI.JourneyPlate.RegisterMark("quest", {
    order = 55, cap = 20, count = "quests",
    radius = 5, halo = TICK.halo, hover = TICK.halo,
    keep = "questMarks",
    tip = function(m) return QuestCard.Tip(m.quest) end,
    draw = function(kit, x, y)
        local a, b = TICK.short, TICK.long
        kit.Stroke(kit.ink, x + a[1], y + a[2], x + a[3], y + a[4], TICK.width, kit.INK_STRONG, 1)
        kit.Stroke(kit.ink, x + b[1], y + b[2], x + b[3], y + b[4], TICK.width, kit.INK_STRONG, 1)
    end,
})

-- A card a task on the plate, after the killer (40: a fall keeps its card
-- first), before the foes (45)
ns.UI.JourneyMargin.Register("quest", {
    order = 42, pool = "questPool", count = "questsWritten",
    new = function(parent) return QuestCard.New(parent) end,
    items = function(plate)
        local list = {}
        for _, mark in ipairs(plate.questMarks or {}) do
            for _, m in ipairs(mark.list or {}) do
                list[#list + 1] = { quest = m.quest, at = mark.at, top = mark.at[2], x = mark.at[1] }
            end
        end
        return list
    end,
    write = function(card, it, c) card:SetQuest(it.quest, c.Seed("quest", it.quest.id or it.quest.name or "")) end,
    mark = function(it) return it.at end,
})
