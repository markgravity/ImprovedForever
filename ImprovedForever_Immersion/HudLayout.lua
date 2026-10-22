-- The game's own HUD pieces placed round ours, in the Edit Mode layout (a
-- test). Set on the game's frames from addon code they'd be tainted, so
-- their places (and a few of their Edit Mode settings) are written into
-- the layout (C_EditMode.SaveLayouts) and that layout made the active one
-- again (C_EditMode.SetActiveLayout), which has the game place its frames
-- from it now (LibEditModeOverride's way, without its opening of the Edit
-- Mode window: a window of the game shown from addon code taints):
-- * the chat over the player's frame, its edit box's room between;
-- * your buffs and debuffs along the bottom between the minion and the
--   party cards (debuffs on the bottom row, buffs over them, both
--   growing right), as big as the Cooldown Manager's icons (their short
--   effects on them: AuraLabels.lua);
-- * the Cooldown Manager's essential and utility cooldowns along the
--   bottom left of the spell diamonds (GamepadBar.lua), growing left (its
--   own options choose what it shows; it's off until turned on in the
--   game's options).
-- Each piece done once per layout: moved again by the player in Edit
-- Mode, it stays where they put it. A preset layout (Modern, Gamepad...)
-- can't be changed: a copy of it as "Improved Forever" is saved and made
-- the active one. Out of combat and out of Edit Mode only.
local IF = ImprovedForever
local IN = IF.Interface

local HL = {}
IN.HudLayout = HL

-- Two layouts of ours: the game keeps its controller layouts apart from
-- the keyboard and mouse ones (one made while on the pad can't be picked
-- with the mouse, and the other way round), so each mode gets a copy of
-- its own preset
local LAYOUT_NAME = "Improved Forever"
local MOUSE_LAYOUT_NAME = "Improved Forever (Mouse)"

local function PadMode()
    -- (the game's Gamepad UI, Options > Gamepad: not the pad's input being
    -- enabled, which stays on while the mouse plays)
    return IF.Input and IF.Input.PadEnabled and IF.Input.PadEnabled() and true or false
end

local function LayoutName()
    return PadMode() and LAYOUT_NAME or MOUSE_LAYOUT_NAME
end
-- (each piece's place's version: a layout placed at another one is placed
-- again; the chat's carries the player frame's top it was placed over, so a
-- taller frame moves it up)
local VERSION = { chat = 5 + IN.UnitFrames.PLAYER_TOP / 1000, auras = 2, cooldowns = 1 }

local EDIT_BOX_ROOM = 34
local AURA_GAP = 20          -- (after the minion card)
local AURA_TIME = 16         -- (a buff's row: its icon, its time under it)
local AURA_BASE = 30         -- (an aura's icon at 100%, BuffFrameTemplates.xml)
local AURA_FALLBACK = 150    -- (its size when the cooldowns' can't be measured)
local MINION_W = 61          -- (a minion's card, PartyCards.lua: 76 * 0.8)
local COOLDOWN_GAP = 40      -- (before the spell diamonds)
local COOLDOWN_ROW = 50

-- The layouts as the game numbers them: its presets first, then the saved
-- ones (C_EditMode.GetLayouts has only the saved; its activeLayout counts
-- the presets)
local function Layouts()
    if not (C_EditMode and C_EditMode.GetLayouts and EditModePresetLayoutManager) then return end
    local info = C_EditMode.GetLayouts()
    if not (info and info.layouts and info.activeLayout) then return end
    local all = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    for _, layout in ipairs(info.layouts) do all[#all + 1] = layout end
    info.layouts = all
    return info
end

local function System(layout, system, index)
    for _, s in ipairs(layout.systems or {}) do
        if s.system == system and (index == nil or s.systemIndex == index) then return s end
    end
end

local function SetSetting(system, setting, value)
    if setting == nil then return end
    system.settings = system.settings or {}
    for _, s in ipairs(system.settings) do
        if s.setting == setting then
            s.value = value
            return
        end
    end
    table.insert(system.settings, { setting = setting, value = value })
end

local function IsPreset(layout)
    return layout.layoutType == Enum.EditModeLayoutType.Preset
end

-- The active layout, made changeable: a preset swapped for our copy of it
-- (made now, or already there)
local function Changeable(info)
    local active = info.layouts[info.activeLayout]
    if not active or not IsPreset(active) then return active end
    local name = LayoutName()
    for i, layout in ipairs(info.layouts) do
        if not IsPreset(layout) and layout.layoutName == name then
            info.activeLayout = i
            return layout
        end
    end
    local copy = CopyTable(active)
    copy.layoutType = Enum.EditModeLayoutType.Account
    copy.layoutName = name
    info.layouts[#info.layouts + 1] = copy
    info.activeLayout = #info.layouts
    return copy
end

local function Anchor(point, relativePoint, x, y)
    return { point = point, relativeTo = "UIParent", relativePoint = relativePoint,
        offsetX = math.floor(x + 0.5), offsetY = math.floor(y + 0.5) }
end

---------------------------------------------------------------------------
-- The pieces: each its systems placed in the layout (false: couldn't)
---------------------------------------------------------------------------
local PIECES = {}

-- (the chat over the player's frame, its left kept: the game's default
-- 35 in)
PIECES.chat = function(layout)
    local chat = System(layout, Enum.EditModeSystem.ChatFrame)
    if not chat then return false end
    local anchor = chat.anchorInfo
    local x = 35
    if anchor and anchor.point == "BOTTOMLEFT" and anchor.relativePoint == "BOTTOMLEFT"
        and type(anchor.offsetX) == "number" then
        x = anchor.offsetX
    end
    chat.anchorInfo = Anchor("BOTTOMLEFT", "BOTTOMLEFT", x, IN.UnitFrames.PLAYER_TOP + EDIT_BOX_ROOM)
    chat.isInDefaultPosition = false
    return true
end

-- (a shown icon's size on screen, in UIParent's units, under frame)
local function IconSize(frame)
    for _, child in ipairs(frame and { frame:GetChildren() } or {}) do
        local icon = child.Icon or child.icon
        if child:IsShown() and icon and icon.GetWidth and icon:GetWidth() > 0 then
            return icon:GetWidth() * icon:GetEffectiveScale() / UIParent:GetEffectiveScale()
        end
    end
end

-- The Cooldown Manager's essential icons' size on screen (UIParent's
-- units), or nil (none shown)
function HL.CooldownIconSize()
    return IconSize(_G.EssentialCooldownViewer)
end

-- (the auras' icon size (a percent, by tens) as the Cooldown Manager's
-- essential icons: measured on screen, else AURA_FALLBACK)
local function AuraPercent()
    local cooldown = IconSize(_G.EssentialCooldownViewer)
    local scale = BuffFrame and BuffFrame:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1
    if not cooldown then return AURA_FALLBACK end
    local percent = math.floor(cooldown / (AURA_BASE * scale) * 10 + 0.5) * 10
    return math.max(50, math.min(200, percent))
end

-- (buffs and debuffs from after the minion card, growing right: debuffs on
-- the bottom line, buffs a row over them, more rows going up; their icons
-- the cooldowns' size (Edit Mode keeps a slider's value as its steps over
-- its least: (percent - 50) / 10))
PIECES.auras = function(layout)
    local indices = Enum.EditModeAuraFrameSystemIndices
    local buffs = indices and System(layout, Enum.EditModeSystem.AuraFrame, indices.BuffFrame)
    local debuffs = indices and System(layout, Enum.EditModeSystem.AuraFrame, indices.DebuffFrame)
    if not (buffs and debuffs) then return false end
    local player = IN.UnitFrames.player
    local x = (player:GetRight() or 140) + 16 + MINION_W + AURA_GAP
    local setting = Enum.EditModeAuraFrameSetting or {}
    local percent = AuraPercent()
    local row = AURA_BASE * percent / 100 + AURA_TIME
    for i, frame in ipairs({ debuffs, buffs }) do
        frame.anchorInfo = Anchor("BOTTOMLEFT", "BOTTOMLEFT", x, IN.BOTTOM + (i - 1) * row)
        SetSetting(frame, setting.IconSize, (percent - 50) / 10)
        frame.isInDefaultPosition = false
        SetSetting(frame, setting.Orientation, Enum.AuraFrameOrientation and Enum.AuraFrameOrientation.Horizontal or 0)
        SetSetting(frame, setting.IconDirection, Enum.AuraFrameIconDirection and Enum.AuraFrameIconDirection.Right or 1)
        SetSetting(frame, setting.IconWrap, Enum.AuraFrameIconWrap and Enum.AuraFrameIconWrap.Up or 1)
    end
    return true
end

-- (the Cooldown Manager's essential cooldowns on the bottom line, ending
-- COOLDOWN_GAP left of the spell diamonds, its utility ones a row over;
-- growing left)
PIECES.cooldowns = function(layout)
    local indices = Enum.EditModeCooldownViewerSystemIndices
    local essential = indices and System(layout, Enum.EditModeSystem.CooldownViewer, indices.Essential)
    local utility = indices and System(layout, Enum.EditModeSystem.CooldownViewer, indices.Utility)
    if not (essential and utility) then return false end
    local GB = IN.GamepadBar
    local left = GB and GB.Rect and GB.Rect()
    local scale = UIParent:GetEffectiveScale()
    local width = UIParent:GetWidth()
    local x = left and (left / scale - width - COOLDOWN_GAP) or -420
    local setting = Enum.EditModeCooldownViewerSetting or {}
    for i, frame in ipairs({ essential, utility }) do
        frame.anchorInfo = Anchor("BOTTOMRIGHT", "BOTTOMRIGHT", x, IN.BOTTOM + (i - 1) * COOLDOWN_ROW)
        frame.isInDefaultPosition = false
        SetSetting(frame, setting.Orientation,
            Enum.CooldownViewerOrientation and Enum.CooldownViewerOrientation.Horizontal or 0)
        SetSetting(frame, setting.IconDirection,
            Enum.CooldownViewerIconDirection and Enum.CooldownViewerIconDirection.Left or 0)
    end
    return true
end

-- The pieces asked for (the settings)
local function Wanted()
    local s = IN.Settings()
    return { chat = s.chatAbove, auras = s.hudAuras, cooldowns = s.hudCooldowns }
end

function HL.Apply()
    if IF.InCombat() or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) then return end
    if not (Enum and Enum.EditModeSystem and Enum.EditModeLayoutType) then return end
    local s = IN.Settings()
    local info = Layouts()
    if not info then return end
    s.hudPlaced = s.hudPlaced or {}
    -- (the chat's earlier test kept which layouts it placed: kept as theirs)
    for name, version in pairs(s.chatPlaced or {}) do
        s.hudPlaced[name] = s.hudPlaced[name] or {}
        s.hudPlaced[name].chat = s.hudPlaced[name].chat or version
    end
    s.chatPlaced = nil
    local active = info.layouts[info.activeLayout]
    if not active then return end
    -- (the pieces this layout still needs: a preset needs all asked for)
    local wanted = Wanted()
    local todo = {}
    local placed = not IsPreset(active) and s.hudPlaced[active.layoutName] or {}
    for piece, on in pairs(wanted) do
        if on and placed[piece] ~= VERSION[piece] then todo[#todo + 1] = piece end
    end
    if #todo == 0 then return end
    active = Changeable(info)
    s.hudPlaced[active.layoutName] = s.hudPlaced[active.layoutName] or {}
    local done = {}
    for _, piece in ipairs(todo) do
        if PIECES[piece](active) then
            s.hudPlaced[active.layoutName][piece] = VERSION[piece]
            done[#done + 1] = piece
        end
    end
    if #done == 0 then return end
    C_EditMode.SaveLayouts(info)
    -- (made the active one again: the game places its frames from it now)
    if C_EditMode.SetActiveLayout then C_EditMode.SetActiveLayout(info.activeLayout) end
    IF.Print("placed " .. table.concat(done, ", ") .. " round your HUD (Edit Mode's \"" .. active.layoutName
        .. "\" layout).")
end

-- Once the game has its layouts and ours are placed (a moment after
-- login: its own handler runs first)
IF.OnLogin(function()
    C_Timer.After(2, HL.Apply)
end)
