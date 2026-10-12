-- Handwriting on the touchpad. While a text box has the keyboard's focus
-- (the chat's, a search box...), a finger on the DualSense's touchpad
-- writes: each stroke is followed (the pad's finger position, mapped stick
-- 4, read every frame: it rests at exactly 0, 0 with no finger on it) and
-- drawn on an ink pad over the text box; once the finger has been off the
-- pad a moment, the strokes are read (Letters.lua) and go in at the text
-- cursor: one letter, or a whole word printed left to right across the pad
-- (the finger lifted between letters). A swipe right across the pad types
-- a space, one to the left deletes the character before the cursor.
--
-- Nothing is taken from the game: no binding, no button (the pad's click
-- is still the game's, or the touchpad corners'), only the finger's
-- position read. The touch cursor (the mouse cursor a sliding finger
-- moves) is off while a text box can be written in, as for the corners
-- (Touchpad.lua): the player's own setting back after.
local IF = ImprovedForever

local K = IF.ConfigKit
local UI = IF.UI
local Letters = IF.Letters

local ink = {}
IF.Ink = ink

local PAD_STICK = 4       -- StickConfigNameToIndex("Pad") is nil on Forever
local ASPECT = 1.8        -- the pad's width to its height: x is stretched by it
local MIN_MOVE = 0.015    -- (closer points than this, in pad units: not kept)
local MIN_SWIPE = 0.9     -- a space / a delete: a stroke this far across (of 3.6)
local MAX_LINES = 1500    -- ink lines drawn for one word
local INK_W, INK_H = 288, 160
local CURSOR_CVAR = "GamePadTouchCursorEnable"

-- (a beta: off until turned on in the Chat tab)
local DEFAULTS = { enabled = false, pause = 0.5, lowercase = false }

function ink.Settings()
    local db = IF.db
    db.ink = db.ink or {}
    local settings = db.ink
    for key, value in pairs(DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    return settings
end

---------------------------------------------------------------------------
-- What's read
---------------------------------------------------------------------------
-- The finger on the pad (x, y: -1 to 1, up positive), or nil
local function Finger()
    if not (C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetDeviceMappedState) then return nil end
    local id = C_GamePad.GetActiveDeviceID()
    local state = id and C_GamePad.GetDeviceMappedState(id)
    local stick = state and state.sticks and state.sticks[PAD_STICK]
    if not stick then return nil end
    local x, y = stick.x or 0, stick.y or 0
    if x == 0 and y == 0 then return nil end
    return x, y
end

-- The text box letters can go in now, or nil
local function Target()
    local settings = ink.Settings()
    if not settings.enabled or IF.PadStyle() ~= "Shapes" then return nil end
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not box or (box.IsForbidden and box:IsForbidden()) then return nil end
    if not (box.GetObjectType and box:GetObjectType() == "EditBox") then return nil end
    -- (a number box takes no letters)
    if box.IsNumeric and box:IsNumeric() then return nil end
    return box
end

---------------------------------------------------------------------------
-- The touch cursor, off while a text box can be written in
---------------------------------------------------------------------------
local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    pcall(setter, name, value)
end

-- (the player's setting kept in ours till it's given back, in case the
-- game closes first; the corners may have it off already: left as it is)
local function BlockTouchCursor(block)
    local settings = ink.Settings()
    local current = GetCVarSafe(CURSOR_CVAR)
    if current == nil then return end
    if block then
        if current ~= "0" then
            settings.touchCursor = current
            SetCVarSafe(CURSOR_CVAR, "0")
        end
    elseif settings.touchCursor ~= nil then
        local saved = settings.touchCursor
        settings.touchCursor = nil
        if current ~= saved then SetCVarSafe(CURSOR_CVAR, saved) end
    end
end

---------------------------------------------------------------------------
-- The ink pad: the strokes as drawn, the pad's shape, over the text box;
-- under them what was read (a lone letter's runners-up after it), then
-- how to type a space and delete
---------------------------------------------------------------------------
local pad = UI.Panel(UIParent, 0.92)
pad:SetFrameStrata("FULLSCREEN_DIALOG")
pad:SetSize(INK_W + 16, INK_H + 62)
pad:SetClampedToScreen(true)
pad:Hide()

local area = K.NewFrame("Frame", nil, pad, "BackdropTemplate")
area:SetPoint("TOPLEFT", 8, -8)
area:SetSize(INK_W, INK_H)
area:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
})
area:SetBackdropColor(0, 0, 0, 0.55)
area:SetBackdropBorderColor(0.45, 0.38, 0.25, 0.8)

local letter = pad:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
letter:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 2, -6)
letter:SetPoint("RIGHT", area, "RIGHT", -60, 0)
letter:SetJustifyH("LEFT")
letter:SetWordWrap(false)

local others = pad:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
others:SetPoint("BOTTOMRIGHT", letter, "BOTTOMRIGHT", 58, 2)

local hint = pad:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("BOTTOMLEFT", 10, 8)
hint:SetPoint("BOTTOMRIGHT", -10, 8)
hint:SetJustifyH("LEFT")

local function Hint()
    local get = C_Texture and C_Texture.GetAtlasInfo
    local icon = get and get("gamepad-ps-touchpad-normal") and "|A:gamepad-ps-touchpad-normal:14:14|a " or ""
    return icon .. "Write a letter or a word   |cffffd100Swipe right|r space   |cffffd100Swipe left|r delete"
end

local lines, used = {}, 0

local function ClearInk()
    for i = 1, used do lines[i]:Hide() end
    used = 0
end

-- (pad units to the area's: x -1 to 1 across, y -1 to 1 up)
local function Segment(a, b)
    if used >= MAX_LINES then return end
    used = used + 1
    local line = lines[used]
    if not line then
        line = area:CreateLine(nil, "OVERLAY")
        line:SetThickness(3)
        line:SetColorTexture(1, 0.9, 0.62, 1)
        lines[used] = line
    end
    line:SetStartPoint("BOTTOMLEFT", area, (a.rx + 1) / 2 * INK_W, (a.ry + 1) / 2 * INK_H)
    line:SetEndPoint("BOTTOMLEFT", area, (b.rx + 1) / 2 * INK_W, (b.ry + 1) / 2 * INK_H)
    line:Show()
end

-- Over the text box (under it when there's no room above); our own frame
-- placed by where the box is, never anchored to it
local function Place(box)
    pad:ClearAllPoints()
    local left, top, bottom = box:GetLeft(), box:GetTop(), box:GetBottom()
    if not (left and top and bottom) then
        pad:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        return
    end
    local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
    left, top, bottom = left * s, top * s, bottom * s
    if top + 8 + pad:GetHeight() <= UIParent:GetHeight() then
        pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, top + 8)
    else
        pad:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom - 8)
    end
end

---------------------------------------------------------------------------
-- Typing
---------------------------------------------------------------------------
-- The character before the text cursor taken out (a whole link, or a
-- whole UTF-8 character)
local function Delete(box)
    local text = box:GetText() or ""
    local cursor = box:GetCursorPosition() or #text
    local before, after = text:sub(1, cursor), text:sub(cursor + 1)
    if before == "" then return end
    local link = before:match("()|c%x%x%x%x%x%x%x%x|H[^|]*|h.-|h|r$") or before:match("()|H[^|]*|h.-|h$")
    if link then
        before = before:sub(1, link - 1)
    else
        local cut = #before
        while cut > 1 and before:byte(cut) >= 0x80 and before:byte(cut) < 0xC0 do cut = cut - 1 end
        before = before:sub(1, cut - 1)
    end
    box:SetText(before .. after)
    box:SetCursorPosition(#before)
end

local function Type(box, text)
    if text == "\b" then
        Delete(box)
    elseif text then
        box:Insert(ink.Settings().lowercase and text:lower() or text)
    end
end

-- (what the ink pad says it read)
local SHOWN = { [" "] = "space", ["\b"] = "delete" }

---------------------------------------------------------------------------
-- The finger followed
---------------------------------------------------------------------------
local strokes, current = {}, nil
local liftedAt, target, blockWait = nil, nil, 0

local function Reset()
    strokes, current, liftedAt = {}, nil, nil
end

local function Finish(box)
    local text, guesses = Letters.Read(strokes, MIN_SWIPE)
    Reset()
    letter:SetText(SHOWN[text] and ("|cffffd100" .. SHOWN[text] .. "|r") or text or "|cffff7a5c?|r")
    -- (a lone letter's runners-up)
    local rest = {}
    if #guesses == 1 then
        for i = 2, math.min(4, #guesses[1]) do rest[#rest + 1] = guesses[1][i][1] end
    end
    others:SetText(table.concat(rest, "  "))
    if ink.debug then
        local letters = {}
        for _, ranked in ipairs(guesses) do
            local parts = {}
            for i = 1, math.min(3, #ranked) do parts[#parts + 1] = ("%s %.2f"):format(ranked[i][1], ranked[i][2]) end
            letters[#letters + 1] = table.concat(parts, ", ")
        end
        IF.Print("ink: " .. (SHOWN[text] or tostring(text)) .. (#letters > 0 and (" (" .. table.concat(letters, " | ") .. ")") or ""))
    end
    Type(box, text)
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, elapsed)
    if not IF.db then return end
    local box = Target()
    if box ~= target then
        target = box
        Reset()
        ClearInk()
        letter:SetText("")
        others:SetText("")
        pad:Hide()
        blockWait = 0
    end
    blockWait = blockWait - elapsed
    if blockWait <= 0 then
        blockWait = 0.1
        BlockTouchCursor(box ~= nil)
    end
    if not box then return end

    local x, y = Finger()
    if x then
        if not current then
            -- (a new drawing: the last one's ink cleared)
            if #strokes == 0 then ClearInk() end
            current = {}
            strokes[#strokes + 1] = current
            if not pad:IsShown() then
                hint:SetText(Hint())
                Place(box)
                pad:Show()
            end
        end
        local point = { x = x * ASPECT, y = -y, rx = x, ry = y }
        local last = current[#current]
        if not last or math.abs(point.x - last.x) + math.abs(point.y - last.y) >= MIN_MOVE then
            current[#current + 1] = point
            if last then Segment(last, point) end
        end
        liftedAt = nil
    else
        if current then current, liftedAt = nil, GetTime() end
        if liftedAt and #strokes > 0 and GetTime() - liftedAt >= ink.Settings().pause then
            Finish(box)
        end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    if IF.db then BlockTouchCursor(false) end
end)

-- /if ink: each drawing read, said in chat with each letter's runners-up
function ink.ToggleDebug()
    ink.debug = not ink.debug
    IF.Print("ink: letters read " .. (ink.debug and "shown in chat" or "no longer shown"))
end
