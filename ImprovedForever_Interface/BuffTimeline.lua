-- Two timelines along the bottom, either side of the party cards, each
-- icon (round, in the game's gamepad circle slot) placed by the time it
-- has left and sliding toward the middle as it runs out, a thin line from
-- it down to a dot on the experience line (as the cards' role dots: a
-- buff's green with an up arrow, a debuff's its kind's colour and icon, a
-- cooldown's red to green with a clock):
-- * left: your buffs and debuffs, from after the minion card (far: long,
--   or with no end) to the party's row;
-- * right: the cooldowns of what's on your gamepad bar (every slot of the
--   crossbar's page shown) and your on-use trinkets, from the spell
--   diamonds (far: long) to the party spells' diamond (PartyPad.lua);
--   only while cooling (the global cooldown left out), a green flash as
--   each comes ready, then gone.
-- Each lane's end by the middle, where its icons run out, marked with a
-- short black line cut into the experience line.
-- Icons never lie on each other: one pushed out of the way goes further
-- out, and past its lane's end a row up. The middle is kept for the party
-- cards (a full party's row, its spells' diamond, MIDDLE_GAP).
-- The icons are ours (the game's can't be moved from addon code without
-- tainting them): the game's buffs, debuffs and Cooldown Manager are drawn
-- at 0 (IF.Focus.Fade), the mouse they'd still get taken over where they
-- are (UnitFrames.lua's Cover). Times the game keeps secret (in a fight):
-- a buff stays at its lane's far end untimed, a cooldown isn't shown.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local BT = {}
IN.BuffTimeline = BT

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local LINE_H = IN.XP_H          -- (the experience line, XPBar.lua)
local START_GAP = 20            -- (after the minion card)
local MINION_W = 61             -- (a minion's card, PartyCards.lua)
local MIDDLE_GAP = 28           -- (kept clear by the party's row)
local PAD_GAP = 12              -- (the party spells' diamond after the cards, PartyCards.lua)
local DIAMOND_GAP = 40          -- (before the spell diamonds)
local SPACING = 4               -- (between two icons)
local ROW_GAP = 18              -- (between rows: the effect over each)
local SIZE_FALLBACK = 40        -- (the Cooldown Manager's icons can't be measured)
local SLIDE = 6                 -- (how fast an icon slides to its place)
local GCD_MAX = 1.6             -- (a cooldown this short is the global one)
local READY_FLASH = 1           -- (a cooldown come ready: shown this long, flashing)
-- (the line and dot as the cards' role dots, PartyCards.lua: an 18 dot on
-- the experience line, its icon in it)
local STEM_W, STEM_ALPHA, DOT, DOT_ICON = 2, 0.55, 18, 12
local DOT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BUFF_COLOR = { 0.25, 0.75, 0.25 }
local DEBUFF_COLOR = { 0.9, 0.15, 0.15 }
-- (the dots' icons: a buff's up, a debuff's down or its kind's, a
-- cooldown's clock; the game's own, the first it has)
local BUFF_ICON = { "Adventure-buff-indicator-small" }
local DEBUFF_ICON = { "Adventure-debuff-indicator-small" }
local DISPEL_ICON = {
    Magic = { "RaidFrame-Icon-DebuffMagic" }, Curse = { "RaidFrame-Icon-DebuffCurse" },
    Disease = { "RaidFrame-Icon-DebuffDisease" }, Poison = { "RaidFrame-Icon-DebuffPoison" },
    Bleed = { "RaidFrame-Icon-DebuffBleed" },
}
local CLOCK_ICON = { "gamepad-radial-icon-clock", "icon-clock", "clock-icon" }
-- (the round slot, as the Wheel's recent slot: the game's gamepad circle
-- slot round the icon; its parts' sizes of the icon's slot)
local RING_BG, RING_ICON, RING_FRAME = 1.13, 0.83, 1.22
-- (each lane's end, by the middle, where its icons run out: a short black
-- line cut into the experience line)
local END_W = 2

local function Atlas(list)
    for _, name in ipairs(list or {}) do
        if IF.HasAtlas and IF.HasAtlas(name) then return name end
    end
end

-- A debuff's kind's colour (the game's), else DEBUFF_COLOR
local function DispelColor(kind)
    local c = type(kind) == "string" and DebuffTypeColor and DebuffTypeColor[kind]
    if c and c.r then return { c.r, c.g, c.b } end
    return DEBUFF_COLOR
end

-- A time left, short: 2h, 5m, 45
local function Short(left)
    if left >= 3600 then return math.ceil(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
end

local function Outline(fs)
    local font, size = fs:GetFont()
    if font then fs:SetFont(font, size, "OUTLINE") end
end

---------------------------------------------------------------------------
-- Times in a fight: the game's duration objects (an action's cooldown, an
-- aura's) read directly, else through a curve of ours that hands their
-- value back as it is (a result is secret only when its curve is, the
-- API's documentation says); nil when both come back secret
---------------------------------------------------------------------------
local identity
local function Identity()
    if identity ~= nil then return identity end
    identity = false
    if C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType then
        local ok, curve = pcall(function()
            local c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Linear)
            c:AddPoint(0, 0)
            c:AddPoint(86400, 86400)
            return c
        end)
        if ok then identity = curve end
    end
    return identity
end

local function Read(duration, get, evaluate)
    if not duration then return nil end
    local ok, value = pcall(duration[get], duration)
    if ok and not Secret(value) and type(value) == "number" then return value end
    local curve = Identity()
    if curve and duration[evaluate] then
        ok, value = pcall(duration[evaluate], duration, curve)
        if ok and not Secret(value) and type(value) == "number" then return value end
    end
end

-- A duration object's time left and whole length (either nil: secret)
local function DurationTimes(duration)
    return Read(duration, "GetRemainingDuration", "EvaluateRemainingDuration"),
        Read(duration, "GetTotalDuration", "EvaluateTotalDuration")
end

-- The icons' size: half the Cooldown Manager's (HudLayout.lua), else of
-- SIZE_FALLBACK
local ICON_SCALE = 0.5
local function Size()
    local HL = IN.HudLayout
    local size = HL and HL.CooldownIconSize and HL.CooldownIconSize()
    return math.floor((size or SIZE_FALLBACK) * ICON_SCALE + 0.5)
end

-- (an icon coming: from RISE over its place, sliding down, fading in; one
-- going: sliding up RISE, fading out)
local RISE = 24

---------------------------------------------------------------------------
-- A timeline: its icons, placed each LAYOUT_EVERY, slid each frame.
-- source.Read(now): its entries ({ key, texture, left (nil: untimed),
-- color, count, effect, flash (0 to 1), Tooltip(owner) }); source.Lane():
-- its near and far x (screen units, near the middle first); source.long:
-- this long or more left (or untimed), its far end.
---------------------------------------------------------------------------
local LAYOUT_EVERY = 0.2

local function Timeline(name, source)
    -- (its icons by their entry's key; spare ones for the next)
    local T = { byKey = {}, spare = {}, since = LAYOUT_EVERY, dirty = true }
    local holder = CreateFrame("Frame", name, UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetAllPoints()
    holder:EnableMouse(false)
    holder:Hide()
    T.holder = holder

    -- (its end by the middle: a black mark over the experience line, in a
    -- frame above it)
    local endFrame = CreateFrame("Frame", nil, holder)
    endFrame:SetFrameStrata("MEDIUM")
    endFrame:SetSize(END_W, LINE_H)
    local endMark = endFrame:CreateTexture(nil, "OVERLAY")
    endMark:SetAllPoints()
    endMark:SetColorTexture(0, 0, 0, 1)

    local function NewIcon()
        local b = CreateFrame("Frame", nil, holder)
        b:EnableMouse(true)
        -- (round: the circle slot's background, the icon cut round, the
        -- slot's ring over it)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetPoint("CENTER")
        if Atlas({ "gamepad-actionbar-circleslot-bg" }) then
            b.bg:SetAtlas("gamepad-actionbar-circleslot-bg")
        else
            b.bg:SetTexture(DOT_MASK)
            b.bg:SetVertexColor(0, 0, 0, 0.6)
        end
        local mask = b:CreateMaskTexture()
        mask:SetTexture(DOT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("CENTER")
        b.mask = mask
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b.icon:AddMaskTexture(mask)
        b.flash = b:CreateTexture(nil, "ARTWORK", nil, 2)
        b.flash:SetPoint("CENTER")
        b.flash:SetColorTexture(1, 1, 1, 1)
        b.flash:SetBlendMode("ADD")
        b.flash:AddMaskTexture(mask)
        b.flash:SetAlpha(0)
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetPoint("CENTER")
        if Atlas({ "gamepad-actionbar-circleslot-frame" }) then
            b.ring:SetAtlas("gamepad-actionbar-circleslot-frame")
        end
        b.time = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
        Outline(b.time)
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("TOPRIGHT", -1, -1)
        Outline(b.count)
        b.effect = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.effect:SetPoint("BOTTOM", b, "TOP", 0, 2)
        b.effect:SetWordWrap(false)
        Outline(b.effect)
        -- (down to the experience line: a thin line, a flat dot on it, its
        -- icon in it)
        b.stem = holder:CreateTexture(nil, "BACKGROUND")
        b.stem:SetColorTexture(1, 1, 1, 1)
        b.stem:SetWidth(STEM_W)
        b.stem:SetPoint("TOP", b, "BOTTOM")
        b.dot = holder:CreateTexture(nil, "ARTWORK")
        b.dot:SetTexture(DOT_MASK)
        b.dot:SetSize(DOT, DOT)
        b.stem:SetPoint("BOTTOM", b.dot, "CENTER")
        b.dotIcon = holder:CreateTexture(nil, "OVERLAY")
        b.dotIcon:SetSize(DOT_ICON, DOT_ICON)
        b.dotIcon:SetPoint("CENTER", b.dot, "CENTER")
        b:SetScript("OnEnter", function(self)
            if not self.Tooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            pcall(self.Tooltip, GameTooltip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        return b
    end

    -- (an icon's parts shown, or hidden, together; their fade)
    local function Parts(b, on)
        for _, part in ipairs({ b, b.stem, b.dot, b.dotIcon }) do part:SetShown(on) end
    end
    local function Fade(b, alpha)
        for _, part in ipairs({ b, b.stem, b.dot, b.dotIcon }) do part:SetAlpha(alpha) end
    end

    -- (each entry's place: its target by its time on a log scale (the
    -- last seconds spread out), then pushed out from the middle past the
    -- one before it in its row, else a row up)
    local function Layout(entries)
        local near, far = source.Lane()
        local size = Size()
        endFrame:ClearAllPoints()
        endFrame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", near, 0)
        local sign = far >= near and 1 or -1
        local span = math.abs(far - near) - size
        for i, entry in ipairs(entries) do
            local f = 1
            if entry.left and entry.left < source.long then
                f = math.log(1 + entry.left) / math.log(1 + source.long)
            end
            entry.d = size / 2 + f * math.max(0, span)
            entry.slot = i
        end
        table.sort(entries, function(a, b)
            if a.d ~= b.d then return a.d < b.d end
            return a.slot < b.slot
        end)
        local last = {}
        for _, entry in ipairs(entries) do
            local row, d = 1, entry.d
            while true do
                local edge = last[row]
                if not edge or d >= edge + size + SPACING then break end
                if edge + size + SPACING <= span + size / 2 then
                    d = edge + size + SPACING
                    break
                end
                row, d = row + 1, entry.d
            end
            last[row] = d
            entry.x = near + sign * d
            entry.y = IN.BOTTOM + (row - 1) * (size + ROW_GAP)
        end
        return size
    end

    local function Fill(entries, size)
        local seen = {}
        for _, entry in ipairs(entries) do
            local key = entry.key
            seen[key] = true
            local b = T.byKey[key]
            if not b or b.leaving then
                if not b then
                    b = table.remove(T.spare) or NewIcon()
                    T.byKey[key] = b
                    -- (coming: from over its place, unseen)
                    b.x, b.y, b.alpha = entry.x, entry.y + RISE, 0
                end
                b.leaving = false
                b:EnableMouse(true)
                Parts(b, true)
            end
            b:SetSize(size, size)
            b.bg:SetSize(size * RING_BG, size * RING_BG)
            b.mask:SetSize(size * RING_ICON, size * RING_ICON)
            b.icon:SetSize(size * RING_ICON, size * RING_ICON)
            b.flash:SetSize(size * RING_ICON, size * RING_ICON)
            b.ring:SetSize(size * RING_FRAME, size * RING_FRAME)
            pcall(b.icon.SetTexture, b.icon, entry.texture)
            local c = entry.color
            -- (the ring tinted for a debuff; the line and dot its colour, its
            -- icon in the dot)
            local r = entry.ring
            if r then b.ring:SetVertexColor(r[1], r[2], r[3], 1) else b.ring:SetVertexColor(1, 1, 1, 1) end
            b.stem:SetVertexColor(c[1], c[2], c[3], STEM_ALPHA)
            b.dot:SetVertexColor(c[1], c[2], c[3], 1)
            b.flash:SetVertexColor(c[1], c[2], c[3], 1)
            local atlas = Atlas(entry.dotIcon)
            if atlas then b.dotIcon:SetAtlas(atlas) end
            b.dotIcon:SetShown(atlas ~= nil)
            b.flash:SetAlpha(entry.flash or 0)
            b.time:SetText(entry.left and entry.left > 0 and Short(entry.left) or "")
            -- (under the icon, or (a cooldown's: no effect there) over it)
            b.time:ClearAllPoints()
            if entry.timeOver then
                b.time:SetPoint("BOTTOM", b, "TOP", 0, 1)
            else
                b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
            end
            b.count:SetText(entry.count or "")
            b.effect:SetText(entry.effect or "")
            b.effect:SetWidth(size + 40)
            b.Tooltip = entry.Tooltip
            b.wantX, b.wantY, b.wantAlpha = entry.x, entry.y, 1
        end
        -- (gone: sliding up and out)
        for key, b in pairs(T.byKey) do
            if not seen[key] and not b.leaving then
                b.leaving = true
                b:EnableMouse(false)
                b.wantY, b.wantAlpha = b.y + RISE, 0
            end
        end
    end

    holder:SetScript("OnUpdate", function(_, elapsed)
        T.since = T.since + elapsed
        if T.dirty or T.since >= LAYOUT_EVERY then
            T.dirty, T.since = false, 0
            local entries = source.Read(GetTime())
            Fill(entries, Layout(entries))
        end
        local k = math.min(1, elapsed * SLIDE)
        for key, b in pairs(T.byKey) do
            b.x = b.x + (b.wantX - b.x) * k
            b.y = b.y + (b.wantY - b.y) * k
            b.alpha = b.alpha + (b.wantAlpha - b.alpha) * k
            if b.leaving and b.alpha < 0.02 then
                Parts(b, false)
                T.byKey[key] = nil
                T.spare[#T.spare + 1] = b
            else
                Fade(b, b.alpha)
                b:ClearAllPoints()
                b:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", b.x, b.y)
                b.dot:ClearAllPoints()
                b.dot:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", b.x, LINE_H)
            end
        end
    end)

    function T.SetShown(on)
        if holder:IsShown() ~= on then
            holder:SetShown(on)
            T.dirty = true
        end
    end

    return T
end

---------------------------------------------------------------------------
-- In a fight Forever hides auras from addons altogether (every read
-- throws) and keeps cooldowns' times secret; only your own casts stay
-- readable (UNIT_SPELLCAST_SUCCEEDED). So lengths are learnt out of it,
-- kept per character, and a cast in a fight starts its timer: a
-- cooldown's (by its slot) and a buff's you cast on yourself (by its
-- spell, else its name: another rank). (As ForeverCDM, Cooldown Master.)
---------------------------------------------------------------------------
local cdLengths, auraLengths = {}, {}   -- (slot key / spell or name: seconds)

IF.OnLogin(function()
    local learnt = IF.charDB.timelineLengths or {}
    IF.charDB.timelineLengths = learnt
    learnt.cd, learnt.aura = learnt.cd or {}, learnt.aura or {}
    cdLengths, auraLengths = learnt.cd, learnt.aura
end)

local function SpellName(id)
    local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    local ok, name = pcall(get, id)
    if ok and type(name) == "string" and not Secret(name) then return name end
end

---------------------------------------------------------------------------
-- Left: your buffs and debuffs (read again on UNIT_AURA, their times as
-- they tick). In a fight (blind) the last list read stays, each on the
-- end it had, gone as that passes; your casts refresh one or add one
-- (castBuffs).
---------------------------------------------------------------------------
local auras = {}
local aurasDirty = true
local blind = false
local castBuffs = {}     -- (spell: { ends, texture }, cast while blind)
local auraEnds = {}      -- (aura instance: its end time)

local function Hidden(v)
    return Secret(v) or (type(issecrettable) == "function" and issecrettable(v))
end

-- (a buff of yours on you, its length learnt: by spell and by name)
local function Learn(aura)
    local id, duration = aura.spellId, aura.duration
    if Secret(id) or Secret(duration) or type(id) ~= "number" or type(duration) ~= "number" or duration <= 0 then return end
    if aura.sourceUnit ~= "player" or Secret(aura.sourceUnit) then return end
    auraLengths[id] = duration
    local name = SpellName(id)
    if name then auraLengths[name] = duration end
end

local function ReadAuras()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return end
    local list = {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for index = 1, 40 do
            local ok, aura = pcall(get, "player", index, filter)
            if not ok or Hidden(aura) then
                -- (a fight: nothing to be read, the last list kept)
                blind = true
                return
            end
            if not aura then break end
            list[#list + 1] = { aura = aura, index = index, filter = filter }
            if filter == "HELPFUL" then Learn(aura) end
        end
    end
    auras, blind = list, false
    wipe(castBuffs)
end

-- A cast of yours while blind: the buff it puts on you, its end from its
-- learnt length (the aura shown refreshed, else one added)
local function CastBuff(spellID, now)
    local name = SpellName(spellID)
    local length = auraLengths[spellID] or (name and auraLengths[name])
    if not length then return end
    for _, item in ipairs(auras) do
        local aura = item.aura
        local id = aura.auraInstanceID
        if item.filter == "HELPFUL" and not Secret(id) and id and not Secret(aura.spellId)
            and (aura.spellId == spellID or (name and SpellName(aura.spellId) == name)) then
            auraEnds[id] = now + length
            return
        end
    end
    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    castBuffs[spellID] = { ends = now + length, texture = not Secret(texture) and texture or nil }
end

-- Its time left, or nil (no end, or not to be read): blind, its end kept
-- (a cast's refresh); else its times read whole (each aura's end kept),
-- else its end kept from before, else its duration object
local function AuraLeft(aura, id, now)
    if blind and id and auraEnds[id] then return math.max(0, auraEnds[id] - now) end
    local expires, duration = aura.expirationTime, aura.duration
    if not (Secret(expires) or Secret(duration)) then
        if type(expires) ~= "number" or type(duration) ~= "number" or duration <= 0 or expires <= 0 then return nil end
        if id then auraEnds[id] = expires end
        return math.max(0, expires - now)
    end
    if id and auraEnds[id] then return math.max(0, auraEnds[id] - now) end
    if id and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local ok, object = pcall(C_UnitAuras.GetAuraDuration, "player", id)
        local left, total = DurationTimes(ok and object or nil)
        if left and total and total > 0 then
            auraEnds[id] = now + left
            return left
        end
    end
    return nil
end

-- An aura's entry (its time left given)
local function AuraEntry(item, id, left)
    local aura = item.aura
    local harmful = item.filter == "HARMFUL"
    local kind = aura.dispelName
    if Secret(kind) then kind = nil end
    local color = harmful and DispelColor(kind) or BUFF_COLOR
    local stacks = aura.applications
    local index, filter = item.index, item.filter
    local AL = IN.AuraLabels
    return {
        key = id or (filter .. index),
        texture = aura.icon,
        left = left,
        color = color,
        ring = harmful and color or nil,
        dotIcon = harmful and (DISPEL_ICON[kind] or DEBUFF_ICON) or BUFF_ICON,
        count = not Secret(stacks) and type(stacks) == "number" and stacks > 1 and stacks or nil,
        effect = id and AL and AL.Effect and AL.Effect(id, index, harmful) or nil,
        Tooltip = function(tip)
            if not (id and pcall(tip.SetUnitAuraByAuraInstanceID, tip, "player", id)) then
                tip:SetUnitAura("player", index, filter)
            end
        end,
    }
end

local buffs = Timeline("ImprovedForeverBuffTimeline", {
    long = 1800,
    Lane = function()
        local start = (UF.player:GetRight() or 140) + 16 + MINION_W + START_GAP
        local stop = UIParent:GetWidth() / 2 - (IN.PartyCards.ROW_HALF or 164) - MIDDLE_GAP
        return stop, start
    end,
    Read = function(now)
        if aurasDirty then
            ReadAuras()
            aurasDirty = false
        end
        local entries = {}
        local current = {}
        for _, item in ipairs(auras) do
            local aura = item.aura
            local id = not Secret(aura.auraInstanceID) and aura.auraInstanceID or nil
            if not id then
                current = nil
            elseif current then
                current[id] = true
            end
            local left = AuraLeft(aura, id, now)
            -- (blind: one run out is gone)
            if not (blind and left and left <= 0) then entries[#entries + 1] = AuraEntry(item, id, left) end
        end
        for spellID, cast in pairs(castBuffs) do
            local left = cast.ends - now
            if left > 0 then
                entries[#entries + 1] = {
                    key = "cast:" .. spellID, texture = cast.texture, left = left,
                    color = BUFF_COLOR, dotIcon = BUFF_ICON,
                    Tooltip = function(tip) tip:SetSpellByID(spellID) end,
                }
            else
                castBuffs[spellID] = nil
            end
        end
        -- (gone auras' ends forgotten: when every aura could be told)
        for id in pairs((current and not blind) and auraEnds or {}) do
            if not current[id] then auraEnds[id] = nil end
        end
        return entries
    end,
})

---------------------------------------------------------------------------
-- Right: the cooldowns of the gamepad bar's slots (the crossbar's page
-- shown, every bar) and your on-use trinkets, while cooling; each as it
-- comes ready kept READY_FLASH seconds, flashing
---------------------------------------------------------------------------
local SLOTS = 32
local TRINKETS = { 13, 14 }
local ready = {}       -- (key: when it came ready)
local cooling = {}     -- (key: its entry while cooling, for its flash)

-- Its colour by its share left, as the spell diamonds' rings (Module.lua)
local function CooldownColor(f)
    local level = IN.LEVEL_COLORS
    if f > 0.75 then return level[4] end
    if f > 0.5 then return level[3] end
    if f > 0.25 then return level[2] end
    return level[1]
end

-- (a cooldown read whole: start, duration as numbers past the global
-- one, else nil)
local function Timed(start, duration)
    if Secret(start) or Secret(duration) then return nil end
    if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= GCD_MAX then return nil end
    return start, duration
end

-- Each gamepad slot's action, once each (by what it is): { key, storage }
local function PadSlots()
    local util = _G.GamepadActionBarBindingUtil
    local main = _G.GamepadMainActionBarFrame
    local unit = main and main.PageUnit
    if not (util and unit and unit.GetCurrentPage) then return {} end
    local page = unit:GetCurrentPage()
    local list, seen = {}, {}
    for slot = 1, SLOTS do
        local ok, storage = pcall(util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, page, slot)
        if ok and type(storage) == "number" then
            local got, kind, id = pcall(GetActionInfo, storage)
            if got and not Secret(kind) and not Secret(id) and kind and id then
                local key = kind .. ":" .. tostring(id)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = { key = key, storage = storage }
                end
            end
        end
    end
    return list
end

-- A slot's cooldown: start, duration (secret in a fight), and whether
-- it's running and on the global cooldown (never secret)
local function ActionCooldown(storage)
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, info = pcall(C_ActionBar.GetActionCooldown, storage)
        if ok and type(info) == "table" then return info.startTime, info.duration, info.isActive, info.isOnGCD end
    elseif GetActionCooldown then
        local ok, start, duration = pcall(GetActionCooldown, storage)
        if ok then return start, duration end
    end
end

-- In a fight the game keeps cooldowns' times secret: ours kept instead.
-- A time read whole is kept (known) and its length learnt (cdLengths);
-- secret, your cast of its spell starts our own timer, its length the
-- learnt one (else its tooltip's, else the spell's base cooldown); one
-- not seen cast (isActive, not the global cooldown, still running past
-- GCD_MAX) from the moment it's seen running. Seen running, then not
-- (isActive, never secret): done. A trinket has no isActive: its use
-- seen in your casts instead.
local known = {}        -- (key: { start, duration })
local activeSince = {}  -- (key: when it was first seen running, secret)

-- A slot's spell: its own, its macro's, its item's use
local function SpellOf(storage)
    local ok, kind, id = pcall(GetActionInfo, storage)
    if not ok or Secret(kind) or Secret(id) then return nil end
    if kind == "macro" then
        id = GetMacroSpell and GetMacroSpell(id) or nil
    elseif kind == "item" then
        local get = C_Item and C_Item.GetItemSpell or GetItemSpell
        id = get and select(2, get(id)) or nil
    elseif kind ~= "spell" then
        return nil
    end
    return not Secret(id) and type(id) == "number" and id or nil
end

-- A slot's length from its tooltip ("8 sec cooldown", an item's "(2 Min
-- Cooldown)"), read once out of a fight
local RECASTS = {
    { _G.SPELL_RECAST_TIME_SEC or "%.2g sec cooldown", 1, true },
    { _G.SPELL_RECAST_TIME_MIN or "%.2g min cooldown", 60, true },
    { _G.SPELL_RECAST_TIME_HOURS or "%.2g hour cooldown", 3600, true },
    { _G.ITEM_COOLDOWN_TOTAL_SEC or "(%d Sec Cooldown)", 1 },
    { _G.ITEM_COOLDOWN_TOTAL_MIN or "(%d Min Cooldown)", 60 },
}
local function Escape(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end
for _, recast in ipairs(RECASTS) do
    local head, tail = recast[1]:match("^(.-)%%[%.%d]*[gdf](.*)$")
    recast.pattern = head and ((recast[3] and "^" or "") .. Escape(head) .. "([%d%.,]+)" .. Escape(tail) .. (recast[3] and "$" or ""))
end

local tipTried = {}     -- (key: its tooltip read)
local function TooltipLength(key, storage)
    if tipTried[key] or IF.InCombat() or not (C_TooltipInfo and C_TooltipInfo.GetAction) then return end
    tipTried[key] = true
    local ok, data = pcall(C_TooltipInfo.GetAction, storage)
    if not (ok and type(data) == "table" and type(data.lines) == "table") then return end
    for _, line in ipairs(data.lines) do
        for _, text in ipairs({ line.leftText, line.rightText }) do
            if type(text) == "string" and not Secret(text) then
                for _, recast in ipairs(RECASTS) do
                    local number = recast.pattern and text:match(recast.pattern)
                    number = number and tonumber((number:gsub(",", ".")))
                    if number and number * recast[2] > GCD_MAX then
                        cdLengths[key] = cdLengths[key] or number * recast[2]
                        return
                    end
                end
            end
        end
    end
end

local function BaseLength(storage)
    local id = SpellOf(storage)
    if not (id and GetSpellBaseCooldown) then return nil end
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    if not ok or Secret(ms) or type(ms) ~= "number" or ms <= GCD_MAX * 1000 then return nil end
    return ms / 1000
end

-- A slot's cooldown now: start, duration (duration nil: running,
-- untimed), or nil (not cooling)
local function SlotCooldown(key, storage, now)
    local start, duration, active, onGCD = ActionCooldown(storage)
    local whole = Timed(start, duration)
    if whole then
        known[key], cdLengths[key], activeSince[key] = { start, duration }, duration, nil
        return start, duration
    end
    if not (Secret(start) or Secret(duration)) then
        -- (read whole and not cooling (or only the global cooldown))
        known[key], activeSince[key] = nil, nil
        return nil
    end
    -- (secret: its duration object (the global cooldown left out), else
    -- kept from before, else our own timer)
    if C_ActionBar and C_ActionBar.GetActionCooldownDuration then
        local ok, object = pcall(C_ActionBar.GetActionCooldownDuration, storage, true)
        local left, total = DurationTimes(ok and object or nil)
        if left then
            if left <= 0 or (total and total <= GCD_MAX) then
                known[key], activeSince[key] = nil, nil
                return nil
            end
            total = total or cdLengths[key] or left
            known[key] = { now - (total - left), total }
            return known[key][1], total
        end
    end
    local was = known[key]
    -- (not running any more, once seen running: done early, or reset)
    if was and active == true then was.seen = true end
    if was and was.seen and active == false then
        known[key], activeSince[key] = nil, nil
        return nil
    end
    if was and was[2] and was[1] + was[2] > now then return was[1], was[2] end
    if active ~= true or onGCD == true then
        known[key], activeSince[key] = nil, nil
        return nil
    end
    activeSince[key] = activeSince[key] or now
    if now - activeSince[key] < GCD_MAX then return nil end
    local length = cdLengths[key] or BaseLength(storage)
    known[key] = { activeSince[key], length }
    return activeSince[key], length
end

-- (your casts, readable in a fight: each slot of that spell (or another
-- rank of it) starts its timer, its length learnt; a buff you cast on
-- yourself, unseen while blind, from its learnt length (CastBuff); a
-- trinket's use too)
local casts = CreateFrame("Frame")
casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
casts:SetScript("OnEvent", function(_, _, _, _, spellID)
    if Secret(spellID) or type(spellID) ~= "number" then return end
    local now = GetTime()
    if blind or IF.InCombat() then
        CastBuff(spellID, now)
        buffs.dirty = true
    end
    local name = SpellName(spellID)
    for _, slot in ipairs(PadSlots()) do
        local id = SpellOf(slot.storage)
        if id and (id == spellID or (name and SpellName(id) == name)) then
            local length = cdLengths[slot.key] or BaseLength(slot.storage)
            if length and length > GCD_MAX then
                known[slot.key], activeSince[slot.key] = { now, length }, nil
            end
        end
    end
    for _, inv in ipairs(TRINKETS) do
        local item = GetInventoryItemID("player", inv)
        local get = C_Item and C_Item.GetItemSpell or GetItemSpell
        local _, useID = item and get and get(item)
        if useID and not Secret(useID) and useID == spellID then
            local key = "inv:" .. inv
            known[key] = { now, cdLengths[key] }
        end
    end
end)

local cooldowns = Timeline("ImprovedForeverCooldownTimeline", {
    long = 300,
    Lane = function()
        local middle = UIParent:GetWidth() / 2
        local near = middle + (IN.PartyCards.ROW_HALF or 164) + MIDDLE_GAP
        local PP = IN.PartyPad
        if PP and PP.Shown and PP.Shown() then near = near + PAD_GAP + PP.Width() end
        local GB = IN.GamepadBar
        local left = GB and GB.Rect and GB.Rect()
        local far = left and (left / UIParent:GetEffectiveScale() - DIAMOND_GAP) or (UIParent:GetWidth() - 420)
        return near, math.max(near + 1, far)
    end,
    Read = function(now)
        local entries = {}
        local found = {}
        local function Add(key, texture, start, duration, Tooltip)
            local left = duration and math.max(0, start + duration - now) or nil
            found[key] = true
            ready[key] = nil
            local entry = {
                key = key, texture = texture, left = left,
                color = left and CooldownColor(left / duration) or CooldownColor(1),
                dotIcon = CLOCK_ICON, timeOver = true, Tooltip = Tooltip,
            }
            cooling[key] = entry
            entries[#entries + 1] = entry
        end
        for _, slot in ipairs(PadSlots()) do
            local storage = slot.storage
            if not cdLengths[slot.key] then TooltipLength(slot.key, storage) end
            local start, duration = SlotCooldown(slot.key, storage, now)
            if start then
                Add(slot.key, GetActionTexture(storage), start, duration, function(tip) tip:SetAction(storage) end)
            end
        end
        for _, inv in ipairs(TRINKETS) do
            local key = "inv:" .. inv
            local ok, start, duration, enable = pcall(GetInventoryItemCooldown, "player", inv)
            local whole = ok and Timed(start, duration)
            if whole and not Secret(enable) and enable ~= 0 then
                known[key], cdLengths[key] = { start, duration }, duration
            elseif ok and not (Secret(start) or Secret(duration)) then
                known[key] = nil
            end
            local was = known[key]
            if was and (not was[2] or was[1] + was[2] > now) then
                Add(key, GetInventoryItemTexture("player", inv), was[1], was[2],
                    function(tip) tip:SetInventoryItem("player", inv) end)
            end
        end
        -- (just come ready: kept READY_FLASH, at the near end, flashing
        -- green; then gone)
        for key, entry in pairs(cooling) do
            if not found[key] then
                ready[key] = ready[key] or now
                local since = now - ready[key]
                if since < READY_FLASH then
                    entry.left = 0
                    entry.color = CooldownColor(0)
                    entry.flash = 0.6 * (1 - since / READY_FLASH)
                    entries[#entries + 1] = entry
                else
                    cooling[key], ready[key] = nil, nil
                end
            end
        end
        return entries
    end,
})

---------------------------------------------------------------------------
-- On / off: the game's own drawn at 0 (and their mouse taken) while ours
-- show; in Edit Mode the game's, to be moved
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    local settings = IN.Settings()
    local edit = UF.EditMode()
    local buffsOn = settings.buffTimeline and not edit
    local cooldownsOn = settings.cooldownTimeline and not edit
    for _, native in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
        IF.Focus.Fade(native, buffsOn)
        UF.Cover(native, buffsOn)
    end
    for _, native in ipairs({ _G.EssentialCooldownViewer, _G.UtilityCooldownViewer }) do
        IF.Focus.Fade(native, cooldownsOn)
        UF.Cover(native, cooldownsOn)
    end
    buffs.SetShown(buffsOn)
    cooldowns.SetShown(cooldownsOn)
end

IN.Watcher("timelines", 0.2, Watch)

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    aurasDirty = true
    buffs.dirty = true
end)

-- /if tlprobe: what the game keeps secret for the timelines, 10 s (into
-- the saved variables: /reload, then read ImprovedForeverDB.timelineProbe)
function BT.Probe()
    local log = { date("%H:%M:%S") .. " timeline probe, combat=" .. tostring(IF.InCombat()) }
    IF.db.timelineProbe = log
    IF.Print("timeline probe: 10 s; be in a fight with a cooldown running and a buff on")
    local n = 0
    local ticker
    local function S(v) return Secret(v) and "<secret>" or tostring(v) end
    ticker = C_Timer.NewTicker(1, function()
        n = n + 1
        local line = { ("%.1f combat=%s"):format(GetTime() % 1000, tostring(IF.InCombat())) }
        -- (each slot cooling: what can be read; ours: what the timeline
        -- shows for it)
        for _, slot in ipairs(PadSlots()) do
            local start, duration, active, onGCD = ActionCooldown(slot.storage)
            if active == true then
                local was = known[slot.key]
                line[#line + 1] = ("%s start=%s dur=%s gcd=%s known=%s,%s since=%s length=%s base=%s"):format(slot.key,
                    S(start), S(duration), S(onGCD), S(was and was[1]), S(was and was[2]), S(activeSince[slot.key]),
                    S(cdLengths[slot.key]), S(BaseLength(slot.storage)))
            end
        end
        -- (the first two buffs: what the call gives back)
        for index = 1, 2 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
            if not ok then
                line[#line + 1] = ("aura%d error=%s"):format(index, S(aura))
            elseif Secret(aura) then
                line[#line + 1] = ("aura%d <secret table>"):format(index)
            elseif type(aura) ~= "table" then
                line[#line + 1] = ("aura%d %s"):format(index, type(aura))
            else
                line[#line + 1] = ("aura%d id=%s exp=%s dur=%s spell=%s name=%s icon=%s"):format(index,
                    S(aura.auraInstanceID), S(aura.expirationTime), S(aura.duration), S(aura.spellId), S(aura.name),
                    S(aura.icon))
            end
        end
        local count = 0
        for _ in pairs(auraEnds) do count = count + 1 end
        line[#line + 1] = "auraEnds=" .. count .. " shown=" .. #auras
        log[#log + 1] = table.concat(line, " | ")
        if n >= 10 then
            ticker:Cancel()
            IF.Print("timeline probe done: " .. #log .. " lines; /reload to save them")
        end
    end)
end

function BT.Apply()
    aurasDirty = true
    buffs.dirty, cooldowns.dirty = true, true
    Watch()
end
