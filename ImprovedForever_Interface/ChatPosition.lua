-- The chat over the player's frame (UnitFrames.lua), its edit box's room
-- between. The chat's place is Edit Mode's: set from addon code the chat
-- would be tainted, and switching the layout from addon code makes the
-- game place every frame from our call. So the place is only written into
-- the Edit Mode layout (C_EditMode.SaveLayouts) and the game applies it
-- itself when it next loads the layouts (/reload, a login), as it applies
-- any layout. Done once per layout: moved again by the player in Edit
-- Mode, it stays where they put it.
-- A preset layout (Modern, Gamepad...) can't be changed: a copy of it as
-- "Improved Forever" is saved and made the active one, which the game
-- picks up at the same next load.
local IF = ImprovedForever
local IN = IF.Interface

local CP = {}
IN.ChatPosition = CP

local LAYOUT_NAME = "Improved Forever"
local EDIT_BOX_ROOM = 34
-- (the places used: a layout placed at an older one is placed again)
local PLACE = 3

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

local function ChatSystem(layout)
    local id = Enum.EditModeSystem and Enum.EditModeSystem.ChatFrame
    for _, system in ipairs(layout.systems or {}) do
        if system.system == id then return system end
    end
end

local function IsPreset(layout)
    return layout.layoutType == Enum.EditModeLayoutType.Preset
end

-- The active layout, made changeable: a preset swapped for our copy of it
-- (made now, or already there)
local function Changeable(info)
    local active = info.layouts[info.activeLayout]
    if not active or not IsPreset(active) then return active end
    for i, layout in ipairs(info.layouts) do
        if not IsPreset(layout) and layout.layoutName == LAYOUT_NAME then
            info.activeLayout = i
            return layout
        end
    end
    local copy = CopyTable(active)
    copy.layoutType = Enum.EditModeLayoutType.Account
    copy.layoutName = LAYOUT_NAME
    info.layouts[#info.layouts + 1] = copy
    info.activeLayout = #info.layouts
    return copy
end

-- Over the player's frame, its left kept (the game's default: 35 in)
local function Placed(anchor)
    local x = 35
    if anchor and anchor.point == "BOTTOMLEFT" and anchor.relativePoint == "BOTTOMLEFT"
        and type(anchor.offsetX) == "number" then
        x = anchor.offsetX
    end
    return { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = x,
        offsetY = (IN.UnitFrames.PLAYER_TOP or 184) + EDIT_BOX_ROOM }
end

function CP.Apply()
    if IF.InCombat() or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) then return end
    local s = IN.Settings()
    if not s.chatAbove then return end
    local info = Layouts()
    if not info then return end
    s.chatPlaced = s.chatPlaced or {}
    local active = info.layouts[info.activeLayout]
    if not active then return end
    -- (this layout already placed: left as it is, the player's moves too)
    if not IsPreset(active) and (s.chatPlaced[active.layoutName] or 0) >= PLACE then return end
    active = Changeable(info)
    local chat = active and ChatSystem(active)
    if not chat then return end
    chat.anchorInfo = Placed(chat.anchorInfo)
    chat.isInDefaultPosition = false
    s.chatPlaced[active.layoutName] = PLACE
    C_EditMode.SaveLayouts(info)
    IF.Print("the chat moves over your frame at your next /reload (Edit Mode's \"" .. active.layoutName
        .. "\" layout).")
end

-- Once the game has its layouts (a moment after login: its own handler
-- runs first)
IF.OnLogin(function()
    C_Timer.After(2, CP.Apply)
end)
