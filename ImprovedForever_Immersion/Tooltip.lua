-- The game's world tooltip (the unit or object under the mouse or the soft target, anchored
-- bottom right over the action bar) drawn again as ours: to the right of your character in the
-- 3D world, between it and the quest tracker, as a card in the Immersion look (Card.lua: the
-- diamond with the mob's portrait, the gold line, the words, the cinematic in and out). The
-- game's stays alive but drawn at 0 (IF.Focus.Fade, an animation of ours: a property of the
-- game's frames set from addon code taints them); ours only reads its lines (text and colour).
-- A tooltip anchored to something else (an item in the bags, a button) is the game's, as it is.
-- Setting tooltipOurs.
local IF = ImprovedForever
local IN = IF.Interface

local TT = {}
IN.Tooltip = TT

local OFFSET_X, OFFSET_Y = 230, -40     -- (from the screen's middle: right of your character)

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local card = IN.Card.New("ImprovedForeverTooltip", { seamless = true, grace = 0.15 })
card.panel:SetPoint("TOPLEFT", UIParent, "CENTER", OFFSET_X, OFFSET_Y + 30)
TT.card = card     -- (the buff notice sits under it while it shows: AuraNotice.lua)

-- (the portrait: the tooltip's unit's; for an object (a herb, a chest) the cursor the game draws
-- for it (SetUnitCursorTexture: its herb, its lock), as the interact tile does; else a plain mark)
local function Yes(fn, unit)
    local ok, v = pcall(fn, unit)
    return ok and not Secret(v) and v and true or false
end
local function Portrait(icon)
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if not (ok and type(unit) == "string" and not Secret(unit)) then unit = nil end
    for _, token in pairs({ unit, "mouseover", "softinteract" }) do
        if Yes(UnitIsGameObject, token) then
            local drawn, done = pcall(SetUnitCursorTexture, icon, token, nil, nil, false)
            if drawn and done and not Secret(done) then return end
        end
    end
    if unit and Yes(UnitExists, unit) then
        SetPortraitTexture(icon, unit)
        icon:SetTexCoord(0, 1, 0, 1)
    else
        IN.Card.Icon(icon, nil)
    end
end

-- (the tooltip's unit token, nil for an object)
local function UnitToken()
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if ok and type(unit) == "string" and not Secret(unit) and Yes(UnitExists, unit) then return unit end
    return nil
end

-- (its level for the badge: { text, color }; a skull (text nil) when
-- too high to say; nil for an object or a level we can't read)
local function LevelInfo(unit)
    if not unit then return nil end
    local ok, v = pcall(UnitLevel, unit)
    if not ok or Secret(v) or type(v) ~= "number" then return nil end
    if v <= 0 then return { color = { 1, 0, 0 } } end
    return { text = tostring(v), color = { 1, 0.82, 0 } }
end

-- (the lines without the level the badge says: "Level 5" goes, "Level 5 Beast" is "Beast")
local function WithoutLevel(lines)
    local word = _G.LEVEL
    if type(word) ~= "string" then return lines end
    local out = {}
    for _, l in ipairs(lines) do
        local text = l.lt
        if text and text:find("^" .. word .. "%s+[%d%?]") then
            text = text:gsub("^" .. word .. "%s+[%d%?]+%s*", "")
            text = text:gsub("^%?%?%s*", "")
        end
        if text ~= "" or l.rt then
            local copy = {}
            for k, v in pairs(l) do copy[k] = v end
            copy.lt = text ~= "" and text or nil
            out[#out + 1] = copy
        end
    end
    return #out > 0 and out or lines
end

-- (a line of the game's tooltip: its text and colour, nil when empty or a secret)
local function Read(fs)
    if not fs then return nil end
    local ok, text, r, g, b = pcall(function()
        local t = fs:GetText()
        local cr, cg, cb = fs:GetTextColor()
        return t, cr, cg, cb
    end)
    if not ok or Secret(text) or type(text) ~= "string" or text == "" then return nil end
    if Secret(r) or Secret(g) or Secret(b) or type(r) ~= "number" then r, g, b = 1, 1, 1 end
    return text, r, g, b
end

local function Lines()
    local n = GameTooltip:NumLines()
    if Secret(n) or type(n) ~= "number" then return nil end
    local out = {}
    for i = 1, n do
        local lt, lr, lg, lb = Read(_G["GameTooltipTextLeft" .. i])
        local rt, rr, rg, rb = Read(_G["GameTooltipTextRight" .. i])
        if lt or rt then
            out[#out + 1] = { lt = lt, lr = lr, lg = lg, lb = lb, rt = rt, rr = rr, rg = rg, rb = rb }
        end
    end
    return #out > 0 and out or nil
end

local function Signature(lines)
    local parts = {}
    for i, l in ipairs(lines) do
        parts[i] = (l.lt or "") .. "|" .. (l.rt or "") .. "|" .. string.format("%.2f%.2f%.2f", l.lr or 0, l.lg or 0, l.lb or 0)
    end
    return table.concat(parts, "\n")
end

-- (the game's tooltip is the default world one: shown, on the screen's frame)
local function WorldTip()
    if not (IF.db and IN.Settings().tooltipOurs ~= false) then return false end
    if not GameTooltip:IsShown() then return false end
    local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
    return ok and owner == UIParent
end

-- The game's own buff tooltip on the pad: with the controller on, its buff frame shows a buff's
-- tooltip by itself, in a tooltip frame of its own (BuffFrameTooltip: bottom right, by the buffs;
-- found by a probe). Drawn at 0 like the world one while the mouse isn't on the buff (a mouse over
-- it is asked for). Setting hideAuraTip.
local buffFaded = false
local function BuffTip()
    local tip = _G.BuffFrameTooltip
    local hide = false
    local pad = IF.Input and IF.Input.Pad()
    local on = tip and IF.db and IN.Settings().hideAuraTip ~= false and pad
    if on then
        local ok, shown = pcall(tip.IsShown, tip)
        hide = ok and shown == true
    end
    if tip and hide ~= buffFaded then
        buffFaded = hide
        IF.Focus.Fade(tip, hide)
    end
end

local gameFaded = false
local function Native(on)
    if on == gameFaded then return end
    gameFaded = on
    IF.Focus.Fade(GameTooltip, on)
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    local lines = WorldTip() and Lines() or nil
    Native(lines ~= nil)
    BuffTip()
    local content
    if lines then
        local level = LevelInfo(UnitToken())
        if level then lines = WithoutLevel(lines) end
        content = { key = lines[1].lt or "", sig = Signature(lines) .. "#" .. (level and level.text or ""), lines = lines, portrait = Portrait, level = level }
    end
    card:Update(elapsed, content)
end)
