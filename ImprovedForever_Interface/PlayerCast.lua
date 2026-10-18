-- Your casts as a long line above the party cards, in place of the game's
-- casting bar: a cast fills from the middle out to both ends, a channel
-- drains from both ends in to the middle, the spell's icon in a small
-- diamond at the middle (the spell diamonds' tile, GamepadBar.lua), its
-- name over it. The progress is one run: from the diamond's top and bottom
-- points along all four edges to its side points (on its border, as the
-- tiles' cast ring), then on out along the line from there, at one speed
-- (a channel the other way: in along the line, then back along the edges
-- to the top and bottom points).
-- Its colour: the spell's icon's main one (IconColors.lua, made by
-- tools/make_icon_colors.py), else the casting bar's (a cast yellow, a
-- channel green); grey while it can't be interrupted, red with
-- "Interrupted" when it's cut.
-- The cast's times can be secret (in a fight): they go to the line's two
-- halves (status bars) as their min and max as they are, the clock as
-- their value (the bars work the fill out), and the line ends on the
-- cast's end events, never by comparing them (as the target's cast bar,
-- UnitFrames.lua). A half fills outward: the left one reversed. A channel's
-- halves are its time gone, dark, over the line's channel colour, growing
-- in from the ends.
-- The game's casting bar is drawn at 0 (IF.Focus.Fade) while ours shows;
-- in Edit Mode the game's, to be moved.
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PlayerCast = {}
IN.PlayerCast = PlayerCast

local LINE_W = 460
local LINE_H = 3
-- (over the party cards, clear of a card grown while picking, PartyCards.lua)
local LINE_Y = IN.BOTTOM + (IN.PartyCards.CARD_H or 100) * 1.15 + 10
local TILE = 30                 -- (the diamond's tile: a size as the spell diamonds')
local INTERRUPTED_HOLD = 0.6
local FADE = 0.3                -- (a cast done: the line fading out)

local COLORS = {
    cast = { 1, 0.78, 0.15 },
    channel = { 0.3, 0.85, 0.3 },
    shield = { 0.6, 0.6, 0.6 },
    interrupted = { 0.9, 0.15, 0.15 },
}

local Try, Secret = UF.Try, function(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- A spell icon's main colour ({ r, g, b }), or nil (not listed, or secret)
local function IconColor(texture)
    local map = IN.IconColors and IN.IconColors.icons
    if not map or Secret(texture) or type(texture) ~= "number" then return nil end
    local c = map[texture]
    if not c then return nil end
    return { math.floor(c / 65536) / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255 }
end

local line = CreateFrame("Frame", "ImprovedForeverPlayerCast", UIParent)
line:SetSize(LINE_W, LINE_H)
line:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, LINE_Y)
line:SetFrameStrata("LOW")
line:Hide()

-- (the track: dark, a channel's colour under its halves)
local track = line:CreateTexture(nil, "BACKGROUND")
track:SetAllPoints()
track:SetColorTexture(1, 1, 1, 1)

-- (its two halves, filling outward from the middle)
local function Half(reverse)
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetSize(LINE_W / 2, LINE_H)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetReverseFill(reverse)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end
local left, right = Half(true), Half(false)

-- (the diamond's border, where the progress runs: its half width out to a
-- side point; the tile's own once it's made)
local radius = TILE * 0.66
local function PlaceHalves()
    for i, half in ipairs({ left, right }) do
        local side = i == 1 and -1 or 1
        half:ClearAllPoints()
        half:SetPoint(side < 0 and "RIGHT" or "LEFT", line, "CENTER", side * radius, 0)
        half:SetWidth(LINE_W / 2 - radius)
    end
end
PlaceHalves()

-- (its edges lit, from the top and bottom points to each side point: a
-- line and its wider, fainter glow, as the tiles' cast ring)
local arcs = CreateFrame("Frame", nil, line)
arcs:SetSize(1, 1)
arcs:SetPoint("CENTER", line, "CENTER")
local arcLines, arcGlows = {}, {}
for i = 1, 4 do
    local glow = arcs:CreateLine(nil, "OVERLAY", nil, 1)
    glow:SetThickness(4)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetBlendMode("ADD")
    local edge = arcs:CreateLine(nil, "OVERLAY", nil, 2)
    edge:SetThickness(2.5)
    edge:SetTexture("Interface\\Buttons\\WHITE8x8")
    edge:SetBlendMode("ADD")
    arcLines[i], arcGlows[i] = edge, glow
end

-- (amount: 0 to 1 of the way along the edges, from the top and bottom
-- points to the side ones)
local EDGES = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }    -- (side, top (1) or bottom (-1))
local function Arcs(amount, color)
    for i, e in ipairs(EDGES) do
        local edge, glow = arcLines[i], arcGlows[i]
        if amount <= 0 then
            edge:Hide()
            glow:Hide()
        else
            local x, y = e[1] * radius * amount, e[2] * radius * (1 - amount)
            for _, l in ipairs({ edge, glow }) do
                l:SetStartPoint("CENTER", arcs, 0, e[2] * radius)
                l:SetEndPoint("CENTER", arcs, x, y)
                l:Show()
            end
            edge:SetVertexColor(color[1], color[2], color[3], 1)
            glow:SetVertexColor(color[1], color[2], color[3], 0.35)
        end
    end
end

-- (the edges' share of the run: their length against the line's half
-- out from the diamond)
local function EdgeShare()
    local edge = radius * math.sqrt(2)
    return edge / (edge + LINE_W / 2 - radius)
end

-- The spell's icon in a diamond at the line's middle: a tile of the spell
-- diamonds (made once they're loaded), mirroring a stand-in for the cast
local tile, standIn
local function Tile()
    if tile ~= nil then return tile or nil end
    local GB = IN.GamepadBar
    if not (GB and GB.Tile and GB.Dims and GB.Mirror and GB.StandIn) then return nil end
    local ok, t = pcall(GB.Tile, line, line, GB.Dims(TILE, 14), { 0, 0 })
    tile = ok and t or false
    if tile then
        tile:EnableMouse(false)
        tile:SetFrameLevel(line:GetFrameLevel() + 5)
        arcs:SetFrameLevel(line:GetFrameLevel() + 20)
        if type(tile.ring) == "table" and type(tile.ring.r) == "number" then
            radius = tile.ring.r
            PlaceHalves()
        end
    end
    return tile or nil
end

-- (the diamond pulsing while it's cast, as the spell diamonds while they
-- cool down (GamepadBar.lua): a flash of the line's colour on each whole
-- second since it began, fading over PULSE_FADE; an interrupt's red)
local PULSE_EVERY, PULSE_FADE, PULSE_ALPHA = 1, 0.35, 0.4

local function Pulse(t)
    local fill = t.flashFill
    if not fill then return end
    local color = line.kind and line.color or (line.holdUntil and COLORS.interrupted)
    if not (color and line.pulseFrom) then
        fill:SetAlpha(0)
        return
    end
    local since = (GetTime() - line.pulseFrom) % PULSE_EVERY
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    fill:SetAlpha(PULSE_ALPHA * math.max(0, 1 - since / PULSE_FADE))
end

local function Mirror()
    local t = Tile()
    if not (t and standIn) then return end
    pcall(IN.GamepadBar.Mirror, t, standIn)
    Pulse(t)
end

local name = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
name:SetPoint("BOTTOM", line, "CENTER", 0, TILE * 0.75 + 10)
name:SetShadowOffset(1, -1)

-- (grey over the lit part while it can't be interrupted: a cast's two
-- fills, a channel's time left between its halves; shown by the secret
-- boolean as it is)
local shields = {}
for i = 1, 2 do
    local t = line:CreateTexture(nil, "ARTWORK", nil, 2)
    t:SetColorTexture(COLORS.shield[1], COLORS.shield[2], COLORS.shield[3], 1)
    t:SetAlpha(0)
    shields[i] = t
end

local function PlaceShields(channel)
    local l, r = left:GetStatusBarTexture(), right:GetStatusBarTexture()
    for _, t in ipairs(shields) do t:ClearAllPoints() end
    if channel then
        shields[1]:SetPoint("TOPLEFT", l, "TOPRIGHT")
        shields[1]:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    else
        shields[1]:SetAllPoints(l)
        shields[2]:SetAllPoints(r)
    end
end

local function Shielded(notInterruptible)
    for i, t in ipairs(shields) do
        local used = i == 1 or line.kind ~= "channel"
        if not (used and pcall(t.SetAlphaFromBoolean, t, notInterruptible, 1, 0)) then t:SetAlpha(0) end
    end
end

local function Unshield()
    for _, t in ipairs(shields) do t:SetAlpha(0) end
end

local function Present(v)
    return Secret(v) or v ~= nil
end

-- What you cast now: kind ("cast" / "channel") and its info (its spell:
-- name, texture, ID, for the diamond)
local function Casting()
    local cname, text, texture, startMs, endMs, _, _, notInterruptible, spellID = UnitCastingInfo("player")
    if Present(cname) then
        return "cast", text, startMs, endMs, notInterruptible, { cname, texture, spellID }
    end
    local chname, chtext, chtexture, chstart, chend, _, chnot, chspell = UnitChannelInfo("player")
    if Present(chname) then
        return "channel", chtext, chstart, chend, chnot, { chname, chtexture, chspell }
    end
end

local function Start(kind, text, startMs, endMs, notInterruptible, spell)
    if line.kind ~= kind or not line:IsShown() then line.pulseFrom = GetTime() end
    line.kind = kind
    line.holdUntil, line.fadeFrom = nil, nil
    local channel = kind == "channel"
    local c = (spell and IconColor(spell[2])) or COLORS[kind]
    line.color = c
    if channel then
        -- (the line in its colour, the time gone dark over it from the ends)
        track:SetColorTexture(c[1], c[2], c[3], 1)
        for _, half in ipairs({ left, right }) do half:SetStatusBarColor(0, 0, 0, 0.85) end
        left:SetReverseFill(false)
        right:SetReverseFill(true)
    else
        track:SetColorTexture(0, 0, 0, 0.6)
        for _, half in ipairs({ left, right }) do half:SetStatusBarColor(c[1], c[2], c[3], 1) end
        left:SetReverseFill(true)
        right:SetReverseFill(false)
    end
    Tile()
    -- (plain times: the line's halves take their share of the run (a cast
    -- the part after the edges, a channel's time gone the part before
    -- them); secret ones: the whole cast, the edges lit throughout)
    local plain = not (Secret(startMs) or Secret(endMs)) and type(startMs) == "number"
        and type(endMs) == "number" and endMs > startMs
    line.startMs, line.plain = plain and startMs or nil, plain
    local lo, hi = startMs, endMs
    if plain then
        local share = EdgeShare()
        if channel then hi = startMs + (endMs - startMs) * (1 - share) else lo = startMs + (endMs - startMs) * share end
    end
    for _, half in ipairs({ left, right }) do
        if not Try(half.SetMinMaxValues, half, lo, hi) then
            line.kind = nil
            line:Hide()
            return
        end
        half:SetValue(GetTime() * 1000)
    end
    if not plain then Arcs(1, c) end
    PlaceShields(channel)
    Shielded(notInterruptible)
    -- (plain times: an end of our own too, should an event be missed)
    line.endMs = not Secret(endMs) and type(endMs) == "number" and endMs or nil
    if not Try(name.SetText, name, text) then name:SetText("") end
    name:SetTextColor(1, 1, 1)
    -- (the icon only: the progress is the line's and the edges', not the
    -- tile's own cast ring)
    if spell then
        local GB = IN.GamepadBar
        standIn = GB and GB.StandIn and GB.StandIn(spell[2]) or nil
    end
    Mirror()
    line:SetAlpha(1)
    line:Show()
end

local function Interrupted()
    line.kind = nil
    local c = COLORS.interrupted
    track:SetColorTexture(c[1], c[2], c[3], 1)
    for _, half in ipairs({ left, right }) do
        half:SetMinMaxValues(0, 1)
        half:SetValue(0)
    end
    Unshield()
    Arcs(1, c)
    name:SetText(INTERRUPTED or "Interrupted")
    name:SetTextColor(c[1], c[2], c[3])
    line.holdUntil = GetTime() + INTERRUPTED_HOLD
    line.pulseFrom = GetTime()
    line.fadeFrom = nil
    line:SetAlpha(1)
    line:Show()
end

-- (done: the line filled, fading out)
local function Done()
    if not line:IsShown() or line.holdUntil then return end
    line.kind = nil
    line.fadeFrom = GetTime()
end

local function Check()
    local kind, text, startMs, endMs, notInterruptible, spell = Casting()
    if kind then
        Start(kind, text, startMs, endMs, notInterruptible, spell)
    elseif not line.holdUntil then
        Done()
    end
end

line:SetScript("OnUpdate", function(self)
    local now = GetTime()
    Mirror()
    if self.kind then
        left:SetValue(now * 1000)
        right:SetValue(now * 1000)
        if self.plain and self.endMs then
            local f = math.min(1, math.max(0, (now * 1000 - self.startMs) / (self.endMs - self.startMs)))
            local share = EdgeShare()
            local amount = self.kind == "channel" and (1 - f) or f
            Arcs(math.min(1, amount / share), self.color or COLORS[self.kind])
        end
        if self.endMs and now * 1000 > self.endMs + 300 then Check() end
    elseif self.holdUntil then
        if now > self.holdUntil then
            self.holdUntil = nil
            self.fadeFrom = now
        end
    elseif self.fadeFrom then
        local a = 1 - (now - self.fadeFrom) / FADE
        if a <= 0 then
            self.fadeFrom = nil
            self:Hide()
        else
            self:SetAlpha(a)
        end
    end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
    events:RegisterUnitEvent(e, "player")
end
events:SetScript("OnEvent", function(_, event)
    if not PlayerCast.on then return end
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not Casting() then Interrupted() end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        Unshield()
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if line.kind then Shielded(true) end
    else
        Check()
    end
end)

---------------------------------------------------------------------------
-- On while the setting is (Edit Mode: the game's bar shown, to be moved)
---------------------------------------------------------------------------
local function Watch()
    if not IF.db then return end
    local on = IN.Settings().castBar and not UF.EditMode()
    IF.Focus.Fade(_G.PlayerCastingBarFrame, on)
    if on ~= PlayerCast.on then
        PlayerCast.on = on
        if on then
            Check()
        else
            line.kind, line.holdUntil, line.fadeFrom = nil, nil, nil
            line:Hide()
        end
    end
end

IN.Watcher("cast line", 0.25, Watch)

PlayerCast.Apply = Watch
