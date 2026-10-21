-- The foes cut down on Your Diary's plates (ours, not Social Diary's):
-- three slashes where a fight went on (Plate.RegisterMark), and in the
-- margin a card for the creature cut down most there, and the one after
-- (JourneyMargin.Register): the killer card (Features/Deaths/Card.lua),
-- its silhouette in ink and its name in the diary's hand, "cut down 20"
-- under it. The moments are BookData.lua's ("foes": one a hunt or a
-- notable kill, m.foes its { [name] = count }).

local addonName, ns = ...

local Style = ns.Style
local KillerCard = ns.Deaths.Card

local FoeCard = {}
ns.FoeCard = FoeCard

-- The slashes: `n` strokes `gap` apart, `h` tall, leaning `lean`, `width`
-- px, in ink. The cards: at most `most` a plate.
local SLASH = { n = 3, gap = 3, h = 9, lean = 4, width = 1.3, halo = 15 }
local FOES = { most = 2 }

local NUMBER = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve" }

function FoeCard.What(n)
    return "cut down " .. (NUMBER[n] or tostring(n))
end

local function Tip(m)
    local lines = {}
    for name, n in pairs(m.foes or {}) do lines[#lines + 1] = name .. " \195\151" .. n end
    table.sort(lines)
    return "Fighting", lines
end

-- The slashes where a fight went on, kept (plate.foeMarks) for the
-- cards' leaders. After the tasks' ticks (55), before the deaths on the
-- road (60).
ns.UI.JourneyPlate.RegisterMark("foes", {
    order = 57, cap = 20, count = "foes",
    radius = 6, halo = SLASH.halo, hover = SLASH.halo,
    keep = "foeMarks",
    tip = function(m) return Tip(m) end,
    draw = function(kit, x, y)
        local S = SLASH
        local half = (S.n - 1) * S.gap / 2
        for i = 1, S.n do
            local u = x - half + (i - 1) * S.gap
            kit.Stroke(kit.ink, u - S.lean / 2, y + S.h / 2, u + S.lean / 2, y - S.h / 2, S.width, kit.INK_STRONG, 1)
        end
    end,
})

-- The creatures cut down on the plate, the most first: each its count,
-- the mark where most of them fell, its look; never the one whose killer
-- card is there already (plate.killer, its pass before the margin)
function FoeCard.Items(plate)
    local by, list = {}, {}
    local killer = plate.killer and plate.killer.name
    local foeIDs = ns.BookData and ns.BookData.FoeIDs and ns.BookData.FoeIDs() or {}
    local looks = ImprovedForever.WorldData and ImprovedForever.WorldData.displays or {}
    for _, mark in ipairs(plate.foeMarks or {}) do
        for _, m in ipairs(mark.list or {}) do
            for name, n in pairs(m.foes or {}) do
                local f = by[name]
                if not f and name ~= killer then
                    local npc = foeIDs[name]
                    f = { name = name, count = 0, npcID = npc, display = npc and looks[npc], best = 0 }
                    by[name] = f
                    list[#list + 1] = f
                end
                if f then
                    f.count = f.count + n
                    if n > f.best then f.best, f.mark = n, mark.at end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    for i = #list, FOES.most + 1, -1 do list[i] = nil end
    return list
end

-- A card a creature, after the killer (40) and the tasks (42)
ns.UI.JourneyMargin.Register("foes", {
    order = 45, pool = "foePool", count = "foesWritten",
    new = function(parent) return KillerCard.New(parent) end,
    items = function(plate)
        local out = {}
        for _, f in ipairs(FoeCard.Items(plate)) do
            out[#out + 1] = { foe = f, top = f.mark[2], x = f.mark[1] }
        end
        return out
    end,
    write = function(card, it, c)
        local f = it.foe
        local K = KillerCard.KILLER
        card:Wear(nil, f, { name = f.name, what = FoeCard.What(f.count), strong = true,
            seed = c.Seed("foes", f.npcID or f.name), tapeAt = K.tapeAt, turn = K.turn,
            tip = function() return Style.TipList(f.name, { FoeCard.What(f.count) .. " here" }) end })
    end,
    mark = function(it) return it.foe.mark end,
})
