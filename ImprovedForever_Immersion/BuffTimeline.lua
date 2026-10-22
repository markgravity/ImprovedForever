-- Two rows along the bottom, either side of the party cards, each icon as
-- the game's buff frame draws them (square, a debuff in its kind's border,
-- its time over it in the game's yellow):
-- * left: your buffs and debuffs, from after the minion card toward the
--   party's row: the game's aura container (Blizzard_AuraContainer's
--   CustomAuraContainerTemplate), filled by the game itself, in a fight
--   too, when it hides auras from addons: which auras, their icons,
--   stacks, time left and tooltips, sorted by time left (the soonest gone
--   nearest the middle, debuffs nearest). Ours only styles each button and
--   places the row; it never sees an aura.
-- * right: the cooldowns of what's on your gamepad bar (every slot of the
--   crossbar's page shown) and your on-use trinkets, from the party
--   spells' diamond (PartyPad.lua) toward the spell diamonds; only while
--   cooling (the global cooldown left out), the soonest ready nearest the
--   middle, sliding along as their order changes, a green flash as each
--   comes ready, then gone. In a fight the game keeps their times secret:
--   each is timed from your cast, by the length it had out of one.
-- The cooldowns' end by the middle is marked with a short black line cut
-- into the power line. The middle is kept for the party cards (a full
-- party's row, its spells' diamond, MIDDLE_GAP).
-- The game's buffs, debuffs and Cooldown Manager are drawn at 0
-- (IF.Focus.Fade), the mouse they'd still get taken over where they are
-- (UnitFrames.lua's Cover).
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local BT = {}
IN.BuffTimeline = BT

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local LINE_H = IN.MP_H          -- (the power line, PlayerHealth.lua)
local START_GAP = 20            -- (after the minion card)
local MINION_W = 61             -- (a minion's card, PartyCards.lua)
local MIDDLE_GAP = 28           -- (kept clear by the party's row)
local PAD_GAP = 12              -- (the party spells' diamond after the cards, PartyCards.lua)
local DIAMOND_GAP = 40          -- (before the spell diamonds)
local LOOT_GAP = 16             -- (before the recent loot, RecentLoot.lua)
local SPACING = 10              -- (between two icons; a debuff's border a sixth out each side)
local ROW_GAP = 18              -- (between rows: the effect over each)
local SIZE_FALLBACK = 40        -- (the Cooldown Manager's icons can't be measured)
local SLIDE = 6                 -- (how fast an icon slides to its place)
local GCD_MAX = 1.6             -- (a cooldown this short is the global one)
local READY_FLASH = 1           -- (a cooldown come ready: shown this long, flashing)
-- (the icons as the game's buff frame's (BuffFrameTemplates.xml): square,
-- no frame, a debuff's border the game's (its kind's) BORDER_OUT of the
-- icon's size; the time in GameFontNormalSmall, the stacks in
-- NumberFontNormal at the bottom right)
local BORDER_OUT = 40 / 30
-- (each lane's end, by the middle, where its icons run out: a short black
-- line cut into the power line)
local END_W = 2

-- A time left, short: 2h, 5m, 45
local function Short(left)
    if left >= 3600 then return math.ceil(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
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

-- The icons' size: three quarters of the Cooldown Manager's
-- (HudLayout.lua), else of SIZE_FALLBACK
local ICON_SCALE = 0.75
local function Size()
    local HL = IN.HudLayout
    local size = HL and HL.CooldownIconSize and HL.CooldownIconSize()
    return math.floor((size or SIZE_FALLBACK) * ICON_SCALE + 0.5)
end

-- (an icon coming: from RISE over its place, sliding down, fading in; one
-- going: sliding up RISE, fading out)
local RISE = 24

---------------------------------------------------------------------------
-- A row of ours: its icons, placed each LAYOUT_EVERY, slid each frame.
-- source.Read(now): its entries ({ key, texture, left (nil: untimed),
-- color, count, effect, flash (0 to 1), Tooltip(owner) }); source.Lane():
-- its near and far x (screen units, near the middle first).
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

    -- (its end by the middle: a black mark over the power line, in a
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
        -- (as the game's buff frame's: the icon square, a flash over it)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.flash = b:CreateTexture(nil, "ARTWORK", nil, 2)
        b.flash:SetAllPoints()
        b.flash:SetColorTexture(1, 1, 1, 1)
        b.flash:SetBlendMode("ADD")
        b.flash:SetAlpha(0)
        b.time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.time:SetPoint("TOP", b, "BOTTOM")
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        b.effect = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.effect:SetPoint("BOTTOM", b, "TOP", 0, 2)
        b.effect:SetWordWrap(false)
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

    -- (an icon shown or hidden; its fade)
    local function Parts(b, on) b:SetShown(on) end
    local function Fade(b, alpha) b:SetAlpha(alpha) end

    -- (the entries in a row from the near end, the soonest first, a row
    -- up past the far end)
    local function Layout(entries)
        local near, far = source.Lane()
        local size = Size()
        endFrame:ClearAllPoints()
        endFrame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", near, 0)
        -- (shown with the line it's cut into: it peeks, PlayerHealth.lua)
        local lines = IN.PlayerHealth and IN.PlayerHealth.holder
        endFrame:SetAlpha(lines and lines:IsVisible() and lines:GetAlpha() or 0)
        local sign = far >= near and 1 or -1
        local per = math.max(1, math.floor((math.abs(far - near) + SPACING) / (size + SPACING)))
        for i, entry in ipairs(entries) do entry.slot = i end
        table.sort(entries, function(a, b)
            local la, lb = a.left or math.huge, b.left or math.huge
            if la ~= lb then return la < lb end
            return a.slot < b.slot
        end)
        for i, entry in ipairs(entries) do
            local row, column = math.floor((i - 1) / per), (i - 1) % per
            entry.x = near + sign * (size / 2 + column * (size + SPACING))
            entry.y = IN.BOTTOM + row * (size + ROW_GAP)
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
            pcall(b.icon.SetTexture, b.icon, entry.texture)
            local c = entry.color
            b.flash:SetVertexColor(c[1], c[2], c[3], 1)
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
-- In a fight the game keeps cooldowns' times secret; only your own casts
-- stay readable (UNIT_SPELLCAST_SUCCEEDED). So lengths are learnt out of
-- it, kept per character, and a cast in a fight starts its slot's timer.
-- (As ForeverCDM, Cooldown Master.)
---------------------------------------------------------------------------
local cdLengths = {}    -- (slot key: seconds)

IF.OnLogin(function()
    local learnt = IF.charDB.timelineLengths or {}
    IF.charDB.timelineLengths = learnt
    learnt.cd, learnt.aura = learnt.cd or {}, nil
    cdLengths = learnt.cd
end)

local function SpellName(id)
    local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    local ok, name = pcall(get, id)
    if ok and type(name) == "string" and not Secret(name) then return name end
end

---------------------------------------------------------------------------
-- Left: your buffs and debuffs, the game's aura container. Each button
-- styled as ours as it's made (initializeFrame, in the game's own code:
-- only regions of the button's own, handed to it to fill: its icon, its
-- time left, its stacks; a debuff's ring and line tinted by its kind,
-- by the game too)
---------------------------------------------------------------------------
local GROUP_GAP = 12            -- (between the buffs and the debuffs)
local DEBUFF_MAX = 8

local function StyleButton(b, harmful, size)
    b:SetSize(size, size)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    time:SetPoint("BOTTOM", b, "TOP", 0, 1)
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)

    pcall(b.SetIcon, b, icon)
    pcall(b.SetDurationText, b, time)
    pcall(b.SetApplicationCount, b, count)
    if harmful then
        -- (the game's debuff border, its kind's)
        local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetPoint("CENTER")
        border:SetSize(size * BORDER_OUT, size * BORDER_OUT)
        pcall(b.AddDispelTypeTexture, b, border, {
            style = styles and styles.Border or 0,
            showWhenHarmful = true, showWithoutDispelType = true,
        })
    end
end

-- (the buffs' lane: after the minion card, to the party's row)
local function BuffLane()
    local start = (UF.player:GetRight() or 140) + 16 + MINION_W + START_GAP
    local stop = UIParent:GetWidth() / 2 - (IN.PartyCards.ROW_HALF or 164) - MIDDLE_GAP
    return start, math.max(start + 1, stop)
end

-- The container, made the first time it's shown (nil: this client has
-- none); its row's start, kept
local container, placedAt
local function Container()
    if container ~= nil then return container or nil end
    container = false
    if not (AuraContainerSortMethod and AuraContainerSortDirection) then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", "ImprovedForeverBuffList", UIParent, "CustomAuraContainerTemplate")
    if not (ok and c) then return nil end
    c:SetFrameStrata("LOW")
    local size = Size()
    local start, stop = BuffLane()
    local fits = math.max(1, math.floor((stop - start - GROUP_GAP + SPACING) / (size + SPACING)))
    pcall(c.SetUnit, c, "player")
    -- (the buffs, then the debuffs nearest the middle; each sorted by time
    -- left, the soonest gone last: nearest the middle)
    local function Group(key, filter, harmful, max)
        pcall(c.AddAuraGroup, c, key, filter, {
            maxFrameCount = max,
            sortMethod = AuraContainerSortMethod.Expiration,
            sortDirection = AuraContainerSortDirection.Reverse,
            layout = { elementSpacing = SPACING, groupSpacing = GROUP_GAP, elementWidth = size, elementHeight = size },
            initializeFrame = function(b) StyleButton(b, harmful, size) end,
        })
    end
    Group("buffs", "HELPFUL", false, math.max(1, fits - DEBUFF_MAX))
    Group("debuffs", "HARMFUL", true, math.min(DEBUFF_MAX, fits))
    c:Hide()
    container = c
    return c
end

-- (shown or not; its row placed: its top left, the row's foot on
-- IN.BOTTOM)
local function ShowBuffs(on)
    local c = (on or container) and Container()
    if not c then return end
    if on then
        local start = BuffLane()
        local at = math.floor(start + 0.5)
        if at ~= placedAt then
            placedAt = at
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", at, IN.BOTTOM + Size())
        end
    end
    if c:IsShown() ~= on then
        c:SetShown(on)
        pcall(c.SetEnabled, c, on)
    end
end

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
    local keys = not (main and main:IsVisible()) and _G.MainActionBar and _G.MainActionBar:IsVisible()
    if not keys and not (util and unit and unit.GetCurrentPage) then return {} end
    local page = not keys and unit:GetCurrentPage()
    local list, seen = {}, {}
    -- (the keyboard and mouse bar's: the game's main bar's buttons' actions)
    for slot = 1, keys and 12 or SLOTS do
        local ok, storage
        if keys then
            local native = _G["ActionButton" .. slot]
            ok, storage = true, native and native.action
        else
            ok, storage = pcall(util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, page, slot)
        end
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

-- (for your reach, PlayerCast.lua: the target header's range)
BT.PadSlots, BT.SpellOf = PadSlots, SpellOf

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

-- (a lockout no longer than this (the wand's or a ranged weapon's swing,
-- which the game reports on every spell, not as the global cooldown) is
-- shown only on a slot whose spell has a cooldown of its own, and not
-- while shooting: Shooting)
local LOCKOUT_MAX = 3

-- A slot's own cooldown length, known: learnt, from its tooltip, or its
-- spell's base one; nil for a spell with none
local function RealLength(key, storage)
    return cdLengths[key] or BaseLength(storage)
end

-- (an auto-repeat shot (a wand's Shoot, Auto Shot) running, or stopped
-- under LOCKOUT_MAX ago: its lockout, between shots, shows on every slot
-- as running, a potion's and Cannibalize's too; none of them then counts
-- as a cooldown not seen cast)
local repeating, repeatEnded = false, nil
local repeats = CreateFrame("Frame")
repeats:RegisterEvent("START_AUTOREPEAT_SPELL")
repeats:RegisterEvent("STOP_AUTOREPEAT_SPELL")
repeats:SetScript("OnEvent", function(_, event)
    repeating = event == "START_AUTOREPEAT_SPELL"
    if not repeating then repeatEnded = GetTime() end
end)
local function Shooting(now)
    return repeating or (repeatEnded ~= nil and now - repeatEnded < LOCKOUT_MAX)
end

-- A slot's cooldown now: start, duration (duration nil: running,
-- untimed), or nil (not cooling)
local function SlotCooldown(key, storage, now)
    local start, duration, active, onGCD = ActionCooldown(storage)
    local whole = Timed(start, duration)
    if whole and duration <= LOCKOUT_MAX and (Shooting(now) or not RealLength(key, storage)) then
        known[key], activeSince[key] = nil, nil
        return nil
    end
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
            if left <= 0 or (total and total <= GCD_MAX)
                or (total and total <= LOCKOUT_MAX and (Shooting(now) or not RealLength(key, storage))) then
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
    -- (running, its times secret, not seen cast: only a spell with a
    -- cooldown of its own, and not while shooting; any other is the swing
    -- lockout)
    local length = RealLength(key, storage)
    if not length or Shooting(now) then
        activeSince[key] = nil
        return nil
    end
    activeSince[key] = activeSince[key] or now
    if now - activeSince[key] < GCD_MAX then return nil end
    known[key] = { activeSince[key], length }
    return activeSince[key], length
end

-- (your casts, readable in a fight: each slot of that spell (or another
-- rank of it) starts its timer, its length learnt; a trinket's use too)
local casts = CreateFrame("Frame")
casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
casts:SetScript("OnEvent", function(_, _, _, _, spellID)
    if Secret(spellID) or type(spellID) ~= "number" then return end
    local now = GetTime()
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
    Lane = function()
        local middle = UIParent:GetWidth() / 2
        local near = middle + (IN.PartyCards.ROW_HALF or 164) + MIDDLE_GAP
        local PP = IN.PartyPad
        if PP and PP.Shown and PP.Shown() then near = near + PAD_GAP + PP.Width() end
        local GB = IN.GamepadBar
        local left = GB and GB.Rect and GB.Rect()
        local far = left and (left / UIParent:GetEffectiveScale() - DIAMOND_GAP) or (UIParent:GetWidth() - 420)
        -- (and before the recent loot, RecentLoot.lua)
        local loot = IN.RecentLoot and IN.RecentLoot.Left and IN.RecentLoot.Left()
        if loot then far = math.min(far, loot - LOOT_GAP) end
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
                timeOver = true, Tooltip = Tooltip,
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
    ShowBuffs(buffsOn and true or false)
    cooldowns.SetShown(cooldownsOn)
end

IN.Watcher("timelines", 0.2, Watch)

-- /if tlprobe: what the game keeps secret for the cooldowns, 10 s (into
-- the saved variables: /reload, then read ImprovedForeverDB.timelineProbe)
function BT.Probe()
    local log = { date("%H:%M:%S") .. " timeline probe, combat=" .. tostring(IF.InCombat()) }
    IF.db.timelineProbe = log
    IF.Print("timeline probe: 10 s; be in a fight with a cooldown running")
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
        log[#log + 1] = table.concat(line, " | ")
        if n >= 10 then
            ticker:Cancel()
            IF.Print("timeline probe done: " .. #log .. " lines; /reload to save them")
        end
    end)
end

function BT.Apply()
    cooldowns.dirty = true
    Watch()
end
