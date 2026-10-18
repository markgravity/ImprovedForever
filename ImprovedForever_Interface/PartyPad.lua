-- Party casting on the controller, for any role (the setting on). A test
-- of taking L1 from the game:
-- * L1 is the game's friendly targeting modifier (GAMEPADLEFTTARGETMODIFIER:
--   held, its targeting bar overrides the top bar). Ours goes over it: an
--   override binding (out of combat, while the game has the pad) to a
--   secure button of ours, so the game's never runs.
-- * Held, that button's snippet (secure: in combat too) binds the D-pad
--   to pick one of four spell slots of ours (the one picked kept, per
--   character) and Square / Circle / Triangle / X to cast the picked
--   slot's spell on party 1 to 4 (a tank's: on the monster that member is
--   fighting, when there is one), your target left as it is (as a cast on
--   the mouse's unit); let go, it clears them.
-- * The four slots are ours (per character, charDB.partyCasts), apart
--   from the game's bars: a small diamond after the party cards (as tall
--   as one, the cards' row centred with it: PartyCards' Layout), the
--   picked tile lit, alone at rest (all four while L1 is held, a spell
--   book or our settings are open); a spell, item or macro dragged onto a
--   tile (out of combat), dragged off to empty it.
-- An earlier test put our macros in the L2 bar's face slots: given back
-- (charDB.partyPad), the macros deleted.
local IF = ImprovedForever
local IN = IF.Interface

local PP = {}
IN.PartyPad = PP

-- (each member's face button, its place in a crossbar bar: 5 left, 6 top,
-- 7 right, 8 bottom; party 1 Square, 2 Circle, 3 Triangle, 4 X. Each slot's
-- D-pad direction: 1 left, 2 up, 3 right, 4 down)
local BUTTON = { 5, 7, 6, 8 }
local DIRS = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } }

-- On (the setting, and you in a party or raid, or a preview up: /if
-- cards tries it solo), and how: "tank" (the party cards' focus a tank's,
-- a preview's counting: casts go on the monster a member is fighting) or
-- "party" (on the member); nil off (L1 the game's)
local function Mode()
    if not IN.Settings().partyPad then return nil end
    if not ((IsInGroup and IsInGroup()) or IN.PartyCards.Previewing()) then return nil end
    return IN.PartyCards.Focus() == "tank" and "tank" or "party"
end

---------------------------------------------------------------------------
-- The secure buttons: one per member (a macro: the picked slot's cast on
-- it), the layer
---------------------------------------------------------------------------
local picks = {}
for i = 1, 4 do
    local b = CreateFrame("Button", "ImprovedForeverPartyPick" .. i, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("useOnKeyDown", true)
    b:SetAttribute("type", "macro")
    b:Hide()
    picks[i] = b
end

-- (the layer: its LeftButton click is L1's press and release; held, the
-- D-pad bound to it ("pickN" clicks: the slot picked) and the face buttons
-- to the members' buttons (keys and each member's cast of each slot its
-- attributes, Bind), released, cleared. A pick sets each member's macro to
-- its cast of that slot. "held" and "picked" read by the look, PP.Held)
local layer = CreateFrame("Button", "ImprovedForeverPartyLayer", UIParent, "SecureHandlerClickTemplate")
layer:RegisterForClicks("AnyDown", "AnyUp")
for i = 1, 4 do SecureHandlerSetFrameRef(layer, "member" .. i, picks[i]) end
layer:SetAttribute("_onclick", [[
    if button == "LeftButton" then
        if down then
            self:SetAttribute("held", true)
            for i = 1, 4 do
                local member, slot = self:GetAttribute("memberKey" .. i), self:GetAttribute("slotKey" .. i)
                if member then self:SetBindingClick(true, member, "ImprovedForeverPartyPick" .. i, "LeftButton") end
                if slot then self:SetBindingClick(true, slot, self, "pick" .. i) end
            end
        else
            self:SetAttribute("held", false)
            self:ClearBindings()
        end
        return
    end
    local picked = down and tonumber(strsub(button, 5))
    if not picked then return end
    self:SetAttribute("picked", picked)
    for i = 1, 4 do
        self:GetFrameRef("member" .. i):SetAttribute("macrotext", self:GetAttribute("text" .. i .. "-" .. picked) or "")
    end
]])
-- (the L1 binding's owner: apart from the layer, whose ClearBindings
-- clears only its own)
local owner = CreateFrame("Frame")
local LAYER_CLICK = "CLICK ImprovedForeverPartyLayer:LeftButton"

local function L1Key()
    return GetBindingKey("GAMEPADLEFTTARGETMODIFIER") or "PADLSHOULDER"
end

-- What a key runs now, overrides counted, or nil
local function Action(key)
    local ok, action = pcall(GetBindingAction, key, true)
    return ok and action or nil
end

-- On: its L1 bound
local bound = false
function PP.Active()
    return bound
end

-- L1 held: ours, or (not ours: a preview, PartyCards.lua) the game's
-- friendly targeting modifier (read, never driven)
function PP.Held()
    if bound then return layer:GetAttribute("held") == true end
    local mode = GamepadMode
    if not (mode and mode.IsTargetingModifierDown and mode.GetLeftTargetModifierFlag) then return false end
    local ok, down = pcall(function() return mode.IsTargetingModifierDown(mode.GetLeftTargetModifierFlag()) end)
    return ok and down == true
end

-- A member's face button's glyph (atlas), or nil
function PP.Glyph(member)
    local n = member and BUTTON[member]
    local key = n and GetBindingKey("GAMEPADACTIONBUTTON" .. n)
    return key and IF.GlyphAtlas(key) or nil
end

-- A slot's D-pad key
local function SlotKey(i)
    return GetBindingKey("GAMEPADACTIONBUTTON" .. i)
end

---------------------------------------------------------------------------
-- The slots: "spell:<id>", "item:<id>", "macro:<name>"
---------------------------------------------------------------------------
local function Slots()
    IF.charDB.partyCasts = IF.charDB.partyCasts or {}
    return IF.charDB.partyCasts
end

local function Icon(action)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    if kind == "spell" then
        local get = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
        return get and get(tonumber(value))
    elseif kind == "item" then
        local get = C_Item and C_Item.GetItemIconByID or GetItemIcon
        return get and get(tonumber(value))
    elseif kind == "macro" then
        local _, icon = GetMacroInfo(value)
        return icon
    end
end

-- A slot's cast on a unit, as a macro (on: its conditions, "[@party1]"):
-- a spell by name, an item by ID, a macro's own lines, each /cast or /use
-- without conditions of its own given these (its #show... lines left
-- out); "" empty. Your target isn't changed.
local CASTS = { cast = true, use = true, castsequence = true, castrandom = true }
local function CastText(action, on)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    if kind == "spell" then
        local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
        local name = get and get(tonumber(value))
        return name and ("/cast " .. on .. " " .. name) or ""
    elseif kind == "item" then
        return "/use " .. on .. " item:" .. value
    elseif kind == "macro" then
        local _, _, body = GetMacroInfo(value)
        local lines = {}
        for line in (body or ""):gmatch("[^\r\n]+") do
            if not line:match("^#show") then
                local command, rest = line:match("^/(%a+)%s+(.*)$")
                if command and CASTS[command:lower()] and not rest:match("^%[") then
                    line = "/" .. command .. " " .. on .. " " .. rest
                end
                lines[#lines + 1] = line
            end
        end
        return table.concat(lines, "\n")
    end
    return ""
end

-- The slot picked (kept per character; the layer's while L1 is held)
local function Picked()
    local picked = layer:GetAttribute("picked")
    if type(picked) == "number" then return picked end
    return IF.charDB and IF.charDB.partyPicked or 1
end

-- Each member's cast of each slot (the layer's "text<member>-<slot>"), and
-- its macro the picked one's (out of combat; in combat the layer's snippet
-- sets them)
local function SetMembers()
    local picked = Picked()
    layer:SetAttribute("picked", picked)
    for i, b in ipairs(picks) do
        for slot = 1, 4 do
            layer:SetAttribute("text" .. i .. "-" .. slot, CastText(Slots()[slot], layer:GetAttribute("on" .. i) or ""))
        end
        b:SetAttribute("macrotext", layer:GetAttribute("text" .. i .. "-" .. picked))
    end
end

-- The cursor's action, or nil
local function CursorAction()
    local kind, a, _, d = GetCursorInfo()
    if kind == "spell" then
        local id = d or a
        if type(id) == "number" then return "spell:" .. id end
    elseif kind == "item" and type(a) == "number" then
        return "item:" .. a
    elseif kind == "macro" and a then
        local name = GetMacroInfo(a)
        if name then return "macro:" .. name end
    end
end

local function Pickup(action)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    if kind == "spell" then
        local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
        pickup(tonumber(value))
    elseif kind == "item" then
        local pickup = (C_Item and C_Item.PickupItem) or PickupItem
        pickup(tonumber(value))
    elseif kind == "macro" then
        PickupMacro(value)
    end
end

---------------------------------------------------------------------------
-- The slots' diamond, after the party cards: the gamepad bar's tiles and
-- their effects (GamepadBar.lua: cooldown, cast, food and drink rings),
-- point to point as tall as a party card (CARD_H, its glyphs past the
-- points); grown while L1 is held
---------------------------------------------------------------------------
local ROOT2 = math.sqrt(2)
local CARD_H, VISIBLE, TILE_GAP = 100, 1.2, 3
-- (2 * (spread + width / 2) = CARD_H, the tiles' size from it)
local SIZE = (CARD_H / 2 - TILE_GAP / ROOT2) / (VISIBLE / ROOT2 + VISIBLE / 2 * ROOT2)
local GLYPH = 14
local GB = IN.GamepadBar
local D = GB.Dims(SIZE, GLYPH)
local WIDTH, SPREAD = D.width, D.spread
-- (each tile's glyph hangs MARGIN past its point: counted in its width)
local MARGIN = GLYPH * 0.7
local EXTENT = SPREAD + WIDTH / 2 + MARGIN
local HELD_GROW, HELD_TIME = 1.2, 0.15

local cluster = CreateFrame("Frame", "ImprovedForeverPartyCasts", UIParent)
cluster:SetFrameStrata("LOW")
cluster:SetSize(2 * EXTENT, 2 * EXTENT)
cluster:SetPoint("CENTER", UIParent, "BOTTOM", 0, CARD_H / 2 + IN.BOTTOM)
cluster:Hide()

-- (the cards' row places it, PartyCards' Layout: its left edge x from the
-- screen's middle, its middle y up from the bottom)
function PP.Shown()
    return cluster:IsShown()
end

function PP.Width()
    return 2 * EXTENT
end

function PP.Place(x, y)
    cluster:ClearAllPoints()
    cluster:SetPoint("LEFT", UIParent, "BOTTOM", x, y)
end
-- (its middle EXTENT in from its left edge, in its own scale: grown, it
-- grows away from the cards, its left edge kept)
local center = CreateFrame("Frame", nil, cluster)
center:SetSize(1, 1)
center:SetPoint("CENTER", cluster, "LEFT", EXTENT, 0)

local tiles = {}

-- (the picked slot's name under its tile at rest: faded out as the
-- diamond opens)
local label = cluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetWidth(2 * EXTENT)
label:SetWordWrap(false)
label:SetShadowOffset(1, -1)

-- A slot's name: its spell's, item's or macro's
local function Name(action)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    if kind == "spell" then
        local get = C_Spell and C_Spell.GetSpellName or GetSpellInfo
        return get and get(tonumber(value))
    elseif kind == "item" then
        local get = C_Item and C_Item.GetItemNameByID or GetItemInfo
        return get and get(tonumber(value))
    elseif kind == "macro" then
        return value
    end
end

-- (each slot's stand-in for the game's button, GB.StandIn: its icon, its
-- spell (a macro's: the one it casts) or item; made again as they change)
local standIns = {}

local function StandIn(action)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    local spellID, itemID
    if kind == "spell" then
        spellID = tonumber(value)
    elseif kind == "item" then
        itemID = tonumber(value)
    elseif kind == "macro" then
        local index = GetMacroIndexByName(value)
        spellID = index and index > 0 and GetMacroSpell and GetMacroSpell(index) or nil
    end
    local getName = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    return GB.StandIn(Icon(action), spellID, itemID, spellID and getName and getName(spellID) or nil)
end

-- (a spell's colour, as the game's buttons: grey when unusable, blue out
-- of power; read whole or not at all (a secret: as usable))
local function Usable(standIn)
    local icon = standIn.icon
    icon.r, icon.g, icon.b = 1, 1, 1
    local id = standIn.spellID
    if not id then return end
    local get = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
    local ok, usable, noPower = pcall(get, id)
    if not ok or issecretvalue and (issecretvalue(usable) or issecretvalue(noPower)) then return end
    if noPower then
        icon.r, icon.g, icon.b = 0.5, 0.5, 1
    elseif not usable then
        icon.r, icon.g, icon.b = 0.4, 0.4, 0.4
    end
end

-- Each tile as the gamepad bar's (GB.Mirror), then ours over it: the
-- picked one's selected border and gold, the others' icons greyed
local function Mirror()
    local picked = Picked()
    for i, b in ipairs(tiles) do
        local standIn = standIns[i]
        if standIn then Usable(standIn) end
        GB.Mirror(b, standIn)
        local on = i == picked
        if on then GB.SetBorder(b, GB.SLOT.selected) end
        b.lit:SetShown(on)
        if not on then b.icon:SetDesaturated(true) end
    end
end

local function Render()
    local picked = Picked()
    label:SetText(Name(Slots()[picked]) or "")
    for i, b in ipairs(tiles) do
        standIns[i] = Slots()[i] and StandIn(Slots()[i]) or nil
        local key = SlotKey(i)
        local atlas = key and IF.GlyphAtlas(key)
        if atlas then b.key:SetAtlas(atlas) else b.key:SetTexture(nil) end
    end
    Mirror()
end

local function Drop(i)
    if IF.InCombat() then return end
    local action = CursorAction()
    if not action then return end
    local had = Slots()[i]
    Slots()[i] = action
    ClearCursor()
    SetMembers()
    if had then Pickup(had) end
    Render()
end

local function DragOff(i)
    local had = Slots()[i]
    if IF.InCombat() or not had then return end
    Slots()[i] = nil
    SetMembers()
    Pickup(had)
    Render()
end

for i, dir in ipairs(DIRS) do
    local b = GB.Tile(center, center, D, dir)
    -- (picked: the game's selected border (Mirror), the diamond lit gold
    -- over the icon, as the gamepad bar's toggled slot; the others' icons
    -- greyed)
    b.lit = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.lit:SetPoint("CENTER")
    b.lit:SetSize(WIDTH * 0.94, WIDTH * 0.94)
    b.lit:SetColorTexture(1, 0.75, 0.25, 0.3)
    b.lit:SetBlendMode("ADD")
    b.lit:AddMaskTexture(b.mask)
    b.lit:Hide()

    b:SetScript("OnEnter", function(self)
        local kind, value = (Slots()[i] or ""):match("^(%a+):(.+)$")
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if kind == "spell" then
            GameTooltip:SetSpellByID(tonumber(value))
        elseif kind == "item" then
            GameTooltip:SetItemByID(tonumber(value))
        elseif kind == "macro" then
            GameTooltip:SetText(value)
        else
            GameTooltip:SetText("Party spell " .. i)
            GameTooltip:AddLine("Drag a spell, item or macro here. L1 + this direction picks it; then L1 + "
                .. "a face button casts it on that party member, your target left as it is.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnReceiveDrag", function() Drop(i) end)
    b:SetScript("OnMouseUp", function()
        if GetCursorInfo() then Drop(i) end
    end)
    b:SetScript("OnDragStart", function() DragOff(i) end)
    tiles[i] = b
end

-- (at rest only the picked tile shows, in the left tile's place (next to
-- the cards); the whole diamond while L1 is held, a spell book or our
-- settings are open or something is on the cursor (to set the slots): the
-- others eased in, the picked one sliding to its own place; held, grown
-- too. The cards do theirs, PartyCards.lua)
local function Full()
    if PP.Held() or GetCursorInfo() then return true end
    for _, name in ipairs({ "SpellBookFrame", "PlayerSpellsFrame" }) do
        local frame = _G[name]
        if frame and frame:IsShown() then return true end
    end
    return IF.Menu ~= nil and IF.Menu.IsOpen ~= nil and IF.Menu.IsOpen() == true
end

local function Ease(f)
    return f * f * (3 - 2 * f)
end

local function Toward(now, want, step)
    return want > now and math.min(want, now + step) or math.max(want, now - step)
end

local MIRROR_EVERY = 0.05      -- (as the gamepad bar's)
local grow, open, placed, since = 0, nil, nil, 0
cluster:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since >= MIRROR_EVERY then
        since = 0
        Mirror()
    end
    local step = elapsed / HELD_TIME
    local want = PP.Held() and 1 or 0
    if grow ~= want then
        grow = Toward(grow, want, step)
        center:SetScale(1 + (HELD_GROW - 1) * Ease(grow))
    end
    local picked = Picked()
    want = Full() and 1 or 0
    if open == want and placed == picked then return end
    open, placed = Toward(open or want, want, step), picked
    local e = Ease(open)
    local rest = DIRS[1]
    label:SetAlpha(1 - e)
    for i, b in ipairs(tiles) do
        local dir = DIRS[i]
        local mine = i == picked
        local f = mine and e or 1
        b:ClearAllPoints()
        b:SetPoint("CENTER", center, "CENTER", (rest[1] + (dir[1] - rest[1]) * f) * SPREAD,
            (rest[2] + (dir[2] - rest[2]) * f) * SPREAD)
        b:SetAlpha(mine and 1 or e)
        if mine then
            label:ClearAllPoints()
            label:SetPoint("TOP", b, "CENTER", 0, -WIDTH / 2 - 2)
        end
        local on = mine or open == 1
        if b:IsMouseEnabled() ~= on then b:EnableMouse(on) end
    end
end)

---------------------------------------------------------------------------
-- The binding: L1 ours while on and the game has the pad (combat: kept
-- as it was, nothing can change; at its start, on if wanted)
---------------------------------------------------------------------------
-- (the targets' macros, for the focus: a healer's, the member; a tank's,
-- the monster it's fighting, else the member)
-- (a preview's, /if cards: each you, so a press shows it works solo)
-- (each member's cast conditions: a healer's, on it; a tank's, on the
-- monster it's fighting, else on it)
local function SetTargets(mode, preview)
    for i = 1, 4 do
        local unit = preview and "player" or ("party" .. i)
        layer:SetAttribute("on" .. i, mode == "tank"
            and ("[@%starget,harm,nodead][@%s]"):format(unit, unit)
            or ("[@" .. unit .. "]"))
    end
end

local function Keys()
    for i = 1, 4 do
        layer:SetAttribute("memberKey" .. i, GetBindingKey("GAMEPADACTIONBUTTON" .. BUTTON[i]))
        layer:SetAttribute("slotKey" .. i, SlotKey(i))
    end
end

-- (on: the buttons set up when it comes on, the focus changes, or force
-- (the bindings changed))
local boundMode, boundKey, boundPreview
local function Bind(on, mode, force)
    if IF.InCombat() then return end
    local preview = IN.PartyCards.Previewing()
    if on and (force or not bound or mode ~= boundMode or preview ~= boundPreview) then
        boundMode, boundPreview = mode, preview
        SetTargets(mode, preview)
        Keys()
        SetMembers()
    end
    if on == bound then return end
    bound = on
    ClearOverrideBindings(layer)
    layer:SetAttribute("held", false)
    if on then
        boundKey = L1Key()
        SetOverrideBindingClick(owner, true, boundKey, "ImprovedForeverPartyLayer", "LeftButton")
    else
        ClearOverrideBindings(owner)
    end
end

---------------------------------------------------------------------------
-- The earlier test's L2 slots given back, its macros deleted
---------------------------------------------------------------------------
local function GiveBack()
    local state = IF.charDB.partyPad
    if not state or IF.InCombat() then return end
    for spec, had in pairs(state.slots or {}) do
        local now = IF.Native.Get(spec)
        if type(now) == "string" and now:match("^party:") then
            if had then IF.Native.Set(spec, had) else IF.Native.Clear(spec) end
        end
    end
    IF.charDB.partyPad = nil
    local macros = IF.charDB.nativeMacros or {}
    for i = 1, 4 do
        local name = "IF:Party" .. i
        if GetMacroIndexByName(name) > 0 then DeleteMacro(name) end
        macros[name] = nil
    end
end

local pending

function PP.Apply()
    if not IF.charDB then return end
    if IF.InCombat() then
        pending = true
        return
    end
    pending = nil
    GiveBack()
    local mode = Mode()
    Bind(mode ~= nil and IF.Binds.InGame(), mode, true)
    cluster:SetShown(mode ~= nil)
    Render()
    IN.PartyCards.Layout()
end

-- (the game's pad focus followed, out of combat; a stuck layer (its
-- release missed) cleared)
IN.Watcher("party pad", 0.1, function()
    if not IF.charDB then return end
    -- (a slot picked (the layer's snippet, in combat too): kept, shown)
    local picked = layer:GetAttribute("picked")
    if type(picked) == "number" and picked ~= IF.charDB.partyPicked then
        IF.charDB.partyPicked = picked
        Render()
    end
    if IF.InCombat() then return end
    local mode = Mode()
    Bind(mode ~= nil and IF.Binds.InGame(), mode)
    if cluster:IsShown() ~= (mode ~= nil) then
        cluster:SetShown(mode ~= nil)
        Render()
        IN.PartyCards.Layout()
    end
    if not bound then return end
    -- (the game binds its own keys as priority overrides too (its input
    -- binding stack, on UIParent), again as its windows come and go: the
    -- last one set wins, so ours set again when it isn't what L1 runs)
    if Action(boundKey) ~= LAYER_CLICK then
        ClearOverrideBindings(owner)
        SetOverrideBindingClick(owner, true, boundKey, "ImprovedForeverPartyLayer", "LeftButton")
    end
    if layer:GetAttribute("held") and not IsKeyDown(boundKey) then
        ClearOverrideBindings(layer)
        layer:SetAttribute("held", false)
    end
end)

-- /if l1probe: what L1, the face buttons and the D-pad run, 10 s (into
-- the saved variables: /reload, then read ImprovedForeverDB.l1Log)
function PP.Probe()
    local log = { date("%H:%M:%S") .. " L1 probe" }
    IF.db.l1Log = log
    IF.Print("L1 probe: 10 s, hold L1 and press the face buttons and the D-pad")
    local n, last = 0, nil
    local ticker
    ticker = C_Timer.NewTicker(0.1, function()
        n = n + 1
        local parts = {
            ("bound=%s mode=%s held=%s ingame=%s"):format(tostring(bound), tostring(boundMode),
                tostring(layer:GetAttribute("held")), tostring(IF.Binds.InGame())),
            ("L1 %s down=%s -> %s"):format(tostring(boundKey or L1Key()), tostring(IsKeyDown(boundKey or L1Key())),
                tostring(Action(boundKey or L1Key()))),
        }
        for i = 1, 4 do
            local pick, cast = layer:GetAttribute("memberKey" .. i), layer:GetAttribute("slotKey" .. i)
            parts[#parts + 1] = ("%s->%s %s->%s"):format(tostring(pick), tostring(pick and Action(pick)),
                tostring(cast), tostring(cast and Action(cast)))
        end
        local line = table.concat(parts, " | ")
        if line ~= last then
            last = line
            log[#log + 1] = ("%.1f %s"):format(GetTime() % 1000, line)
        end
        if n >= 100 then
            ticker:Cancel()
            IF.Print("L1 probe done: " .. #log .. " lines; /reload to save them")
        end
    end)
end

-- (your role, the group, combat's end: looked at again, the cards with it
-- (their buttons shown or not; PartyCards' Apply runs PP.Apply); combat's
-- start: L1 ours if wanted, whatever has the pad (still allowed then); the
-- bindings changed (not ours: the layer's come and go with each L1 press):
-- the keys read again)
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "UPDATE_BINDINGS", "UPDATE_MACROS", "SPELLS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        local mode = Mode()
        if mode then Bind(true, mode) end
    elseif event == "UPDATE_BINDINGS" then
        if bound and not PP.Held() and not IF.InCombat() then
            Bind(true, boundMode, true)
            Render()
        end
    elseif event == "UPDATE_MACROS" or event == "SPELLS_CHANGED" then
        if cluster:IsShown() then Render() end
    elseif event ~= "PLAYER_REGEN_ENABLED" or pending then
        IN.PartyCards.Apply()
    end
end)
