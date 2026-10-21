-- The header's place under the top of the screen, and its look (the camp
-- summary's, the Camp module's Scene.lua): a gold rule, a diamond on it,
-- a name big in Morpheus under it, small lines under that. Three take it
-- in turn: the zone's name as you enter one (ZoneBanner.lua), the target
-- (TargetHeader.lua), the focused quest's way (QuestArrow.lua), the first
-- of them that wants it. One goes out before the next comes in: each owner
-- draws itself from its presence, 0 to 1 (going out: 1 to 0; coming in: 0
-- to 1). The gold rule is the slot's own, shown while the owner in it
-- uses it (the target's is its health), so it stays through a swap
-- between two that do.
local IF = ImprovedForever
local IN = IF.Interface

local HS = {}
IN.HeaderSlot = HS

-- (the look: the camp summary's font, sizes and gold; the rule this far
-- down from the screen's top, RULE_W each side of its middle; the name
-- this far under it, past the diamond's foot)
HS.FONT = "Fonts\\MORPHEUS.TTF"
HS.NAME_SIZE, HS.SMALL_SIZE, HS.WORDS_SIZE = 30, 13, 15
HS.GOLD = { 1, 0.82, 0.45 }
HS.RULE_Y, HS.RULE_W = 130, 260
HS.NAME_GAP = 30

local HALF = 0.5                        -- (seconds: one out, or one in)
local RULE_FADE = 4                     -- (the rule's own fade)

-- A line of the header's on `parent`
function HS.Text(parent, font, size, r, g, b)
    local s = parent:CreateFontString(nil, "ARTWORK", nil, 0)
    if not (font and s:SetFont(font, size, "")) then s:SetFont(STANDARD_TEXT_FONT, size, "") end
    s:SetTextColor(r, g, b)
    s:SetShadowOffset(1, -1)
    s:SetShadowColor(0, 0, 0, 1)
    s:SetWordWrap(false)
    return s
end

-- (0 to 1 smoothly between a and b)
function HS.Ease(x, a, b)
    local t = math.min(1, math.max(0, (x - (a or 0)) / ((b or 1) - (a or 0))))
    return t * t * (3 - 2 * t)
end

-- (a pop: past full a little, then back)
function HS.Pop(t)
    local c = 1.7
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

-- The diamond on the rule: the spell diamonds' tile (GamepadBar.lua), the
-- game's square slot turned, a picture inside cut to the diamond.
-- tile.icon (its picture), tile.bg (the slot's dark ground), tile.mask
-- (the diamond's cut), tile.border, tile.side (the slot's side),
-- tile.across (the diamond's width, point to point)
local TILE_TURN, ROOT2 = math.pi / 4, math.sqrt(2)
HS.TILE_TURN = TILE_TURN

function HS.Tile(parent, size)
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

---------------------------------------------------------------------------
-- The gold rule: two halves out from the middle, fading out
---------------------------------------------------------------------------
local ruleFrame = CreateFrame("Frame", "ImprovedForeverHeaderRule", UIParent)
ruleFrame:SetSize(2 * HS.RULE_W, 1)
ruleFrame:SetFrameStrata("LOW")
ruleFrame:EnableMouse(false)
ruleFrame:SetPoint("CENTER", UIParent, "TOP", 0, -HS.RULE_Y)
ruleFrame:SetAlpha(0)

local G = HS.GOLD
for _, half in ipairs({ { "RIGHT", 0, 0.8 }, { "LEFT", 0.8, 0 } }) do
    local r = ruleFrame:CreateTexture(nil, "ARTWORK")
    r:SetColorTexture(G[1], G[2], G[3], 1)
    r:SetSize(HS.RULE_W, 1)
    r:SetPoint(half[1], ruleFrame, "CENTER", 0, 0)
    if not pcall(r.SetGradient, r, "HORIZONTAL", CreateColor(G[1], G[2], G[3], half[2]),
        CreateColor(G[1], G[2], G[3], half[3])) then
        r:SetAlpha(0.6)
    end
end

---------------------------------------------------------------------------
-- The owners: HS.Add(key, priority, { wants = fn, rule = fn }), drawn by
-- themselves from HS.Presence(key)
---------------------------------------------------------------------------
local owners = {}
local active

function HS.Add(key, priority, def)
    local o = { key = key, priority = priority, wants = def.wants, rule = def.rule, p = 0 }
    owners[#owners + 1] = o
    owners[key] = o
    table.sort(owners, function(a, b) return a.priority > b.priority end)
    return o
end

function HS.Presence(key)
    local o = owners[key]
    return o and o.p or 0
end

-- Who has it (or is coming in)
function HS.Active()
    return active and active.key
end

local function Wants(o)
    local ok, yes = pcall(o.wants)
    return ok and yes and true or false
end

local broken

local function Step(elapsed)
    local want
    for _, o in ipairs(owners) do
        if Wants(o) then
            want = o
            break
        end
    end
    active = want
    -- (the others out first, then the one that wants it in)
    local clear = true
    for _, o in ipairs(owners) do
        if o ~= want and o.p > 0 then clear = false end
    end
    local step = elapsed / HALF
    local ruled = false
    for _, o in ipairs(owners) do
        local goal = (o == want and clear) and 1 or 0
        o.p = goal > o.p and math.min(goal, o.p + step) or math.max(goal, o.p - step)
        if o.p > 0 or o == want then
            local ok, uses = pcall(o.rule)
            if ok and uses then ruled = true end
        end
    end
    local a = ruleFrame:GetAlpha()
    local goal = ruled and 1 or 0
    a = a + (goal - a) * math.min(1, elapsed * RULE_FADE)
    if math.abs(a - goal) < 0.01 then a = goal end
    ruleFrame:SetAlpha(a)
end

-- (one error said once, then no more: an error each frame floods the
-- game's error handler, whose popup taints the pad's focus)
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if broken then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then
        broken = true
        ruleFrame:Hide()
        for _, o in ipairs(owners) do o.p = 0 end
        if HS.OnBroken then pcall(HS.OnBroken) end
        IF.Print("Immersion: the header stopped after an error: " .. tostring(err))
    end
end)

function HS.Broken()
    return broken
end
