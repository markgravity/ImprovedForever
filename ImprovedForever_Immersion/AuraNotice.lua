-- A buff or debuff you gain, announced as a card in the Immersion look (Card.lua) on the left of
-- your character in the 3D world, the world tooltip's mirror (Tooltip.lua): the diamond with its
-- icon, the line (gold for a buff, red for a debuff), its name and kind, its time, its words.
-- Several at once come one after another. Only out of combat: in a fight Forever throws on
-- every aura read from addon code, so a gain then is not announced (and not told afterwards:
-- the first look out of combat takes what is on you as it is). Setting auraNotice.
local IF = ImprovedForever
local IN = IF.Interface

local AN = {}
IN.AuraNotice = AN

local OFFSET_X, OFFSET_Y = 230, -40     -- (from the screen's middle: left of your character)
local HOLD, HOLD_QUEUED = 3.5, 2.2      -- (seconds shown, alone or with others waiting)
local BUFF, DEBUFF = { 1, 0.82, 0.45 }, { 0.9, 0.3, 0.25 }
local DESC_WIDTH, DESC_LINES = 44, 5      -- (the words (the stats) in lines this wide, this many)
local UP, DOWN = { 0.35, 0.9, 0.35 }, { 0.95, 0.3, 0.25 }
local MAX_QUEUE = 6

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local card = IN.Card.New("ImprovedForeverAuraNotice")
card.panel:SetPoint("TOPRIGHT", UIParent, "CENTER", -OFFSET_X, OFFSET_Y + 30)

-- (what is on you: id -> true, per kind; nil until a first look)
local known
local queue = {}
local current, shownFor

local function Words(v)
    return type(v) == "string" and not Secret(v) and v ~= "" and v or nil
end

-- A time left, short: 2h, 5 min, 30 sec
local function Left(t)
    if t >= 3600 then return math.ceil(t / 3600) .. " h" end
    if t >= 60 then return math.ceil(t / 60) .. " min" end
    return math.ceil(t) .. " sec"
end

-- The words with the numbers: the aura's own tooltip lines (what it does), else its spell's
-- description; each cut into lines of DESC_WIDTH, DESC_LINES at most
local function Wrap(text, out, color)
    local cur = ""
    for word in text:gmatch("%S+") do
        if #cur + #word + 1 > DESC_WIDTH and cur ~= "" then
            out[#out + 1] = { lt = cur, lr = color[1], lg = color[2], lb = color[3] }
            cur = word
        else
            cur = cur == "" and word or (cur .. " " .. word)
        end
    end
    if cur ~= "" then out[#out + 1] = { lt = cur, lr = color[1], lg = color[2], lb = color[3] } end
end

local function Describe(aura)
    local out = {}
    local info = C_TooltipInfo
    local call = info and (aura.helpful and info.GetUnitBuffByAuraInstanceID or info.GetUnitDebuffByAuraInstanceID)
    local ok, data = pcall(function() return call and call("player", aura.auraInstanceID) end)
    if ok and type(data) == "table" and not Secret(data) and type(data.lines) == "table" then
        for i, l in ipairs(data.lines) do
            local text = Words(l.leftText)
            if i > 1 and text and not text:lower():find("remaining") then
                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local c = l.leftColor
                local color = type(c) == "table" and type(c.r) == "number" and { c.r, c.g, c.b } or { 0.78, 0.78, 0.78 }
                Wrap(text, out, color)
            end
        end
    end
    if #out == 0 then
        local get = C_Spell and C_Spell.GetSpellDescription
        local id = aura.spellId
        local ok2, text = pcall(function() return get and type(id) == "number" and get(id) end)
        text = ok2 and Words(text)
        if text then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            Wrap(text, out, { 0.78, 0.78, 0.78 })
        end
    end
    while #out > DESC_LINES do out[#out] = nil end
    return out
end

local function Content(aura)
    local c = aura.helpful and BUFF or DEBUFF
    local timeText = aura.duration and aura.duration > 0 and Left(aura.duration) or nil
    local lines = { { lt = aura.name, lr = c[1], lg = c[2], lb = c[3], rt = timeText, rr = 0.8, rg = 0.8, rb = 0.8 } }
    for _, l in ipairs(Describe(aura)) do lines[#lines + 1] = l end
    if #lines == 1 then
        lines[2] = { lt = aura.helpful and "Buff" or "Debuff", lr = 0.78, lg = 0.78, lb = 0.78 }
    end
    local icon = aura.icon
    -- (its sig: what it says without its time, and its stacks: it changes when the numbers do)
    local words = {}
    for i = 1, #lines do words[i] = lines[i].lt or "" end
    return {
        key = tostring(aura.auraInstanceID),
        sig = tostring(aura.auraInstanceID) .. "|" .. tostring(aura.applications) .. "|" .. table.concat(words, "\n"),
        lines = lines, tint = c,
        arrow = { up = aura.helpful, color = aura.helpful and UP or DOWN },
        portrait = function(tex) IN.Card.Icon(tex, icon) end,
    }
end

-- What is on you now: instance id -> its data, or nil when the game won't tell (a fight)
local function Scan()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return nil end
    local all = {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 80 do
            local ok, aura = pcall(get, "player", i, filter)
            if not ok then return nil end
            if not aura then break end
            if Secret(aura.auraInstanceID) or Secret(aura.name) then return nil end
            if Words(aura.name) and type(aura.auraInstanceID) == "number" then
                aura.helpful = filter == "HELPFUL"
                all[aura.auraInstanceID] = aura
            end
        end
    end
    return all
end

-- A notice: the one already showing for the same aura is replaced in place (its hold begins again),
-- one waiting is replaced, else it waits its turn
local function Announce(c)
    if current and current.key == c.key then
        current = c
        shownFor = GetTime() + HOLD
        return
    end
    for i, q in ipairs(queue) do
        if q.key == c.key then
            queue[i] = c
            return
        end
    end
    if #queue < MAX_QUEUE then queue[#queue + 1] = c end
end

-- known: instance id -> { apps, sig } (what was last announced). A gain is announced; so is a
-- change of what it says (Plainsrunning's speed growing as you run, a stack added): the auras the
-- event says were updated, and any whose stacks changed, are read again and compared.
local function Look(updateInfo)
    if not (IF.db and IN.Settings().auraNotice ~= false) or IF.InCombat() then
        known = nil     -- (the next look out of combat only takes what is on you)
        return
    end
    local now = Scan()
    if not now then
        known = nil
        return
    end
    local updated = {}
    if type(updateInfo) == "table" and not Secret(updateInfo) and type(updateInfo.updatedAuraInstanceIDs) == "table" then
        for _, id in ipairs(updateInfo.updatedAuraInstanceIDs) do
            if type(id) == "number" then updated[id] = true end
        end
    end
    -- (an aura gone: its notice goes too, shown or waiting)
    local function Gone(c)
        return not now[tonumber(c.key)]
    end
    if current and Gone(current) then current = nil end
    for i = #queue, 1, -1 do
        if Gone(queue[i]) then table.remove(queue, i) end
    end
    local was = known
    known = {}
    for id, aura in pairs(now) do
        local old = was and was[id]
        if not was then
            known[id] = { apps = aura.applications, sig = Content(aura).sig }
        elseif not old then
            local c = Content(aura)
            known[id] = { apps = aura.applications, sig = c.sig }
            Announce(c)
        else
            known[id] = old
            if updated[id] or old.apps ~= aura.applications then
                local c = Content(aura)
                old.apps = aura.applications
                if c.sig ~= old.sig then
                    old.sig = c.sig
                    Announce(c)
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, _, updateInfo)
    if event == "PLAYER_ENTERING_WORLD" then
        known, queue, current = nil, {}, nil
    end
    local ok = pcall(Look, updateInfo)
    if not ok then known = nil end
end)

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    if current and now >= shownFor then current = nil end
    if not current and #queue > 0 then
        current = table.remove(queue, 1)
        shownFor = now + (#queue > 0 and HOLD_QUEUED or HOLD)
    end
    if IF.db and IN.Settings().auraNotice == false then
        current, queue = nil, {}
    end
    card:Update(elapsed, current)
end)
