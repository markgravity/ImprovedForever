-- The Group wheel (built in): the party or the raid, a member a slot. A
-- pick targets them; D-pad up / down on a member picks a spell instead
-- (the Wheels tab's slots of this wheel: helpful spells), cast on them
-- without changing the target. Slots are unit tokens ("party2",
-- "raid14"), never names or other addons' frames: the secure side is set
-- out of combat only, and a token keeps pointing at whoever holds it in a
-- fight. Its look (name, class, health) is read live from the token
-- (Ring.lua), so it follows the group in combat too.
local IF = ImprovedForever

local G = {}
IF.GroupWheel = G

G.MAX_SPELLS = 8
G.MAX = 64 -- eight raid groups, a page each

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end
G.Secret = Secret

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or Secret(a) then return nil end
    return a, b, c
end

---------------------------------------------------------------------------
-- A member's look, read live from the token
---------------------------------------------------------------------------

-- What a slot with nobody in it says ("Party 2")
local function TokenLabel(unit)
    if unit == "player" then return "You" end
    local kind, n = unit:match("^(%a+)(%d+)$")
    return kind and ((kind == "raid" and "Raid " or "Party ") .. n) or unit
end

-- name (maybe a secret: only SetText it), icon (an atlas or a texture),
-- class colour { r, g, b }, usable (there, alive, online)
function G.Look(unit)
    if not Safe(UnitExists, unit) then
        return TokenLabel(unit), "Interface\\Icons\\INV_Misc_QuestionMark", nil, false
    end
    local name = UnitName(unit)
    if name == nil or (not Secret(name) and name == "") then name = TokenLabel(unit) end
    local _, class = Safe(UnitClass, unit)
    local icon, color = "Interface\\Icons\\INV_Misc_QuestionMark", nil
    if type(class) == "string" then
        local atlas = GetClassAtlas and GetClassAtlas(class) or ("classicon-" .. class:lower())
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then icon = atlas end
        local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
        if c then color = { c.r, c.g, c.b } end
    end
    local dead = Safe(UnitIsDeadOrGhost, unit)
    local online = Safe(UnitIsConnected, unit)
    return name, icon, color, not dead and online ~= false
end

-- The token's health for a StatusBar: max, now (either may be a secret:
-- only SetMinMaxValues / SetValue them)
function G.Health(unit)
    if not Safe(UnitExists, unit) or not UnitHealthMax then return nil end
    return UnitHealthMax(unit), UnitHealth(unit)
end

---------------------------------------------------------------------------
-- The ring's members
---------------------------------------------------------------------------
local function Entry(unit)
    local name, icon = G.Look(unit)
    return { type = "target", value = "", unit = unit, label = Secret(name) and TokenLabel(unit) or name,
        icon = icon }
end

local function Build()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        local groups = {}
        for g = 1, 8 do groups[g] = { label = "Raid group " .. g } end
        for i = 1, math.min(n, 40) do
            local _, _, subgroup = Safe(GetRaidRosterInfo, i)
            local group = groups[type(subgroup) == "number" and subgroup or 1] or groups[1]
            group[#group + 1] = Entry("raid" .. i)
        end
        local out, used = { groups = {} }, 0
        for _, group in ipairs(groups) do
            if #group > 0 and used < G.MAX then
                out.groups[#out.groups + 1] = group
                for _, entry in ipairs(group) do out[#out + 1] = entry end
                used = used + 8
            end
        end
        return out
    end
    -- A party: always all five, so one who joins mid-fight has a slot (an
    -- empty one is dimmed, its pick does nothing)
    local entries = { Entry("player") }
    if n > 0 then
        for i = 1, 4 do entries[#entries + 1] = Entry("party" .. i) end
    else
        entries.empty = "Not in a group"
    end
    return entries
end
IF.RingBuilders.group = Build

---------------------------------------------------------------------------
-- The spells D-pad up / down goes through on a member (1 is "Target"),
-- kept per character as the slots of the wheel ("spell:<id>")
---------------------------------------------------------------------------

-- A spell that helps someone else: helpful, with a range (not self only)
local function Helpful(spell)
    local id, name = spell.spellID, spell.name
    local helpful = (C_Spell and C_Spell.IsSpellHelpful and Safe(C_Spell.IsSpellHelpful, id))
        or (IsHelpfulSpell and Safe(IsHelpfulSpell, name))
    if not helpful then return false end
    local ranged = (C_Spell and C_Spell.SpellHasRange and Safe(C_Spell.SpellHasRange, id))
        or (SpellHasRange and Safe(SpellHasRange, name))
    return ranged and true or false
end

function G.DefaultSpells()
    local slots = {}
    for _, spell in ipairs(IF.GetSpellbookSpells and IF.GetSpellbookSpells() or {}) do
        if #slots >= G.MAX_SPELLS then break end
        if spell.spellID and Helpful(spell) then slots[#slots + 1] = "spell:" .. spell.spellID end
    end
    return slots
end

-- (filled from the spellbook once it's there: none of them helpful, none)
function G.Spells()
    local db = IF.charDB
    if not db then return {} end
    if not db.groupSpells then
        if #(IF.GetSpellbookSpells and IF.GetSpellbookSpells() or {}) == 0 then return {} end
        db.groupSpells = G.DefaultSpells()
    end
    return db.groupSpells
end

function G.ResetSpells()
    if IF.charDB then IF.charDB.groupSpells = G.DefaultSpells() end
end

-- { label, spell?, icon? }: 1 "Target", then each spell (cast by name: its
-- highest rank)
function G.CastList()
    local list = { { label = "Target" } }
    local spells = G.Spells()
    for i = 1, G.MAX_SPELLS do
        local id = tonumber((spells[i] or ""):match("^spell:(%d+)$"))
        local name, icon
        if id then name, icon = IF.SpellInfo(id) end
        if name then list[#list + 1] = { label = name, spell = name, icon = icon } end
    end
    return list
end

---------------------------------------------------------------------------
-- The group changing: the ring rebuilt (in combat, after it)
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    if IF.db and IF.charDB then IF.RefreshRings() end
end)
