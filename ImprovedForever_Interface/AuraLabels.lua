-- Each of the game's buff and debuff icons with its effect in short on it
-- ("+5 STA", "+10% Haste", "+120 HP"), read from the aura's tooltip. The
-- game's buttons are never touched (a property of the game's frames set
-- from addon code taints them): a label of ours sits over each icon,
-- placed by its rect (as UnitFrames.lua's Cover), not anchored to it. On
-- with the buffs along the bottom (HudLayout.lua).
local IF = ImprovedForever
local IN = IF.Interface

local AL = {}
IN.AuraLabels = AL

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

---------------------------------------------------------------------------
-- An effect in short, from a tooltip line
---------------------------------------------------------------------------
local STAT = {
    stamina = "STA", strength = "STR", agility = "AGI", intellect = "INT", spirit = "SPI",
    armor = "Armor", ["all stats"] = "Stats", ["attack power"] = "AP", ["ranged attack power"] = "RAP",
    ["spell power"] = "SP", ["spell damage"] = "SP", healing = "Heal", ["movement speed"] = "Speed",
    ["run speed"] = "Speed", ["critical strike chance"] = "Crit", ["chance to hit"] = "Hit",
    ["dodge chance"] = "Dodge", ["attack speed"] = "Haste", ["damage taken"] = "Dmg taken",
    ["damage done"] = "Dmg", ["health regeneration"] = "HP regen", ["mana regeneration"] = "MP regen",
    resistance = "Resist", ["all resistances"] = "Resist",
}

local function Stats(text)
    local out = {}
    for part in (text .. " and "):gmatch("(.-),? and ") do
        for piece in (part .. ","):gmatch("%s*(.-),") do
            local key = piece:lower():gsub("^your ", ""):gsub("^the ", "")
            if key ~= "" then out[#out + 1] = STAT[key] or (key:sub(1, 1):upper() .. key:sub(2, 5)) end
        end
    end
    return table.concat(out, " ")
end

local function Shorten(desc)
    local what, n = desc:match("[Ii]ncrease[sd]? (.-) by (%d+)%%")
    if what then return "+" .. n .. "% " .. Stats(what) end
    what, n = desc:match("[Ii]ncrease[sd]? (.-) by (%d+)")
    if what then return "+" .. n .. " " .. Stats(what) end
    what, n = desc:match("[Rr]educe[sd]? (.-) by (%d+)%%")
    if what then return "-" .. n .. "% " .. Stats(what) end
    what, n = desc:match("[Rr]educe[sd]? (.-) by (%d+)")
    if what then return "-" .. n .. " " .. Stats(what) end
    n = desc:match("[Rr]estores (%d+) health") or desc:match("(%d+) health")
    if n then return "+" .. n .. " HP" end
    n = desc:match("[Rr]estores (%d+) mana") or desc:match("(%d+) mana")
    if n then return "+" .. n .. " MP" end
    n = desc:match("[Aa]bsorbs (%d+)")
    if n then return n .. " shield" end
    return nil
end

-- An aura's effect in short (by its instance, kept while it lasts; its
-- tooltip by instance, else by its place in your auras), or ""
local known = {}
local function Effect(id, index, harmful)
    if known[id] then return known[id] end
    local tips = C_TooltipInfo
    if not tips then return "" end
    local byID = harmful and tips.GetUnitDebuffByAuraInstanceID or tips.GetUnitBuffByAuraInstanceID
    local ok, text = pcall(function()
        local data
        if byID then
            data = byID("player", id)
        elseif tips.GetUnitAura and type(index) == "number" then
            data = tips.GetUnitAura("player", index, harmful and "HARMFUL" or "HELPFUL")
        end
        for i = 2, #(data and data.lines or {}) do
            local line = data.lines[i].leftText
            if type(line) == "string" and not Secret(line) then
                local short = Shorten(line)
                if short then return short end
            end
        end
        return ""
    end)
    -- (a read refused (a fight): tried again later)
    if not ok then return "" end
    known[id] = text
    return text
end

AL.Effect = Effect

---------------------------------------------------------------------------
-- The labels: one per game icon shown, over it by its rect
---------------------------------------------------------------------------
local holder = CreateFrame("Frame", nil, UIParent)
holder:SetAllPoints()
holder:EnableMouse(false)
local labels = {}

local function Label(i)
    local f = labels[i]
    if f then return f end
    f = CreateFrame("Frame", nil, holder)
    f:EnableMouse(false)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("BOTTOMLEFT", 0, 2)
    f.text:SetPoint("BOTTOMRIGHT", 0, 2)
    f.text:SetWordWrap(false)
    local font, size = f.text:GetFont()
    if font then f.text:SetFont(font, size, "OUTLINE") end
    labels[i] = f
    return f
end

local function Place(f, button)
    local region = button.Icon or button
    local l, b, w, h = region:GetRect()
    if not (l and b and w and h) then return false end
    local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, b * k)
    f:SetSize(w * k, h * k)
    f:SetFrameStrata(button:GetFrameStrata())
    f:SetFrameLevel(button:GetFrameLevel() + 10)
    return true
end

local function Update()
    local n = 0
    -- (the timeline on: the game's icons aren't shown, its own icons have
    -- theirs, BuffTimeline.lua)
    if IN.Settings().hudAuras and not IN.Settings().buffTimeline and not IN.UnitFrames.EditMode() then
        for _, frame in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
            local harmful = frame == _G.DebuffFrame
            for _, button in ipairs(frame and frame:IsVisible() and frame.auraFrames or {}) do
                local info = button:IsVisible() and button.hasValidInfo and button.buttonInfo
                local id = info and info.auraInstanceID
                if type(id) == "number" and not Secret(id) then
                    local text = Effect(id, info.index, harmful)
                    if text ~= "" then
                        n = n + 1
                        local f = Label(n)
                        if Place(f, button) then
                            f.text:SetText(text)
                            f:Show()
                        else
                            f:Hide()
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, #labels do labels[i]:Hide() end
end

-- (gone auras forgotten: on each change of yours)
local forget = CreateFrame("Frame")
forget:RegisterUnitEvent("UNIT_AURA", "player")
forget:SetScript("OnEvent", function()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not get then return end
    for id in pairs(known) do
        local ok, aura = pcall(get, "player", id)
        if ok and not aura then known[id] = nil end
    end
end)

IN.Watcher("aura labels", 0.25, function()
    if IF.db then Update() end
end)
