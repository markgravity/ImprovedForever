-- The chat while fishing: the game's lines by the stringer (Panel.lua),
-- bottom right over its tally, set right: every line barely there, a new
-- one bright for a while, fading back (as the Interface module's chat).
-- Shown with the fishing view (View.lua). Typing: the game's chat in its
-- own place, ours hidden; the typing done, ours back at once. The game's
-- whole too with the pad on its window, the mouse on it, Edit Mode (ours
-- back HOLD seconds after).
-- Two message frames of ours, one over the other, fed the same lines: the
-- back one at DIM, never fading; the front one at full, its lines fading
-- after BRIGHT seconds. The lines come from the game's chat frames as
-- they're added (hooksecurefunc, after the game's own AddMessage), the tab
-- shown in its dock only; they can be secret: only handed on, never read.
-- Without the Interface module the game's chat drawn at 0 meanwhile (its
-- lines, tabs, edit box, border: IF.Focus.Fade, an animation of ours; never
-- the chat window itself, the pad's focus can be on it). With it, its own
-- chat fading does that.
local IF = ImprovedForever
local F = IF.Fishing

local DIM, BRIGHT, FADE, MAX_LINES = 0.3, 10, 3, 60
local W, H, LIFT = 380, 170, 8
local HOLD, MOUSE_SECS = 1.5, 3

local view = CreateFrame("Frame", "ImprovedForeverFishingChat", UIParent)
view:SetSize(W, H)
view:SetFrameStrata("LOW")
view:EnableMouse(false)
view:Hide()

local function Layer(alpha, fading)
    local f = CreateFrame("ScrollingMessageFrame", nil, view)
    f:SetAllPoints()
    f:SetMaxLines(MAX_LINES)
    f:SetJustifyH("RIGHT")
    f:EnableMouse(false)
    f:SetAlpha(alpha)
    f:SetFading(fading)
    if fading then
        f:SetTimeVisible(BRIGHT)
        f:SetFadeDuration(FADE)
    end
    f:SetFontObject(ChatFontNormal)
    f:SetShadowColor(0, 0, 0, 1)
    f:SetShadowOffset(1, -1)
    return f
end

local back = Layer(DIM, false)
local front = Layer(1, true)

---------------------------------------------------------------------------
-- The game's chat tab shown, its lines
---------------------------------------------------------------------------
local current

local function Selected()
    local dock = GENERAL_CHAT_DOCK
    return dock and dock.selected or ChatFrame1
end

local function Add(layer, text, r, g, b)
    pcall(layer.AddMessage, layer, text, r, g, b)
end

local function OnAdd(frame, text, r, g, b)
    if frame ~= current then return end
    Add(back, text, r, g, b)
    Add(front, text, r, g, b)
end

-- (every chat frame the game has, whisper tabs opened since too, hooked once)
local hooked = {}
local function Hook()
    local names = {}
    if type(CHAT_FRAMES) == "table" then
        for _, name in ipairs(CHAT_FRAMES) do names[#names + 1] = name end
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do names[#names + 1] = "ChatFrame" .. i end
    for _, name in ipairs(names) do
        local f = type(name) == "string" and _G[name]
        if type(f) == "table" and not hooked[f] and f.AddMessage then
            hooksecurefunc(f, "AddMessage", OnAdd)
            hooked[f] = true
        end
    end
end

-- (a tab picked: its recent lines read back, into the dim layer only)
local function Rebuild(frame)
    current = frame
    Hook()
    back:Clear()
    front:Clear()
    if not frame then return end
    local ok, font, size, flags = pcall(frame.GetFont, frame)
    if ok and font then
        back:SetFont(font, size, flags)
        front:SetFont(font, size, flags)
    end
    local got, n = pcall(frame.GetNumMessages, frame)
    if not got or type(n) ~= "number" then return end
    for i = math.max(1, n - MAX_LINES + 1), n do
        local read, text, r, g, b = pcall(frame.GetMessageInfo, frame, i)
        if read then Add(back, text, r, g, b) end
    end
end

-- (over the stringer's tally, its right edge on the tally's; no stringer:
-- the screen's bottom right)
local function Place()
    view:ClearAllPoints()
    local spot = F.RackTally and F.RackTally()
    if spot then
        view:SetPoint("BOTTOMRIGHT", spot, "TOPRIGHT", 0, LIFT)
    else
        view:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 60)
    end
end

---------------------------------------------------------------------------
-- The game's chat drawn at 0 (without the Interface module)
---------------------------------------------------------------------------
local BORDER = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }

local chats = {}
local boxHooked = {}
local Watch
local function Parts()
    local list = {}
    local function Part(f)
        if f and f.GetObjectType then list[#list + 1] = f end
    end
    chats = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = "ChatFrame" .. i
        local chat = _G[name]
        if chat then chats[#chats + 1] = chat end
        -- (the edit box's parts, not the box: the game animates its alpha)
        local box = _G[name .. "EditBox"]
        if box and box.GetRegions then
            for _, region in ipairs({ box:GetRegions() }) do Part(region) end
        end
        -- (typing begun or ended: the chat moved at once, not a moment on)
        if box and box.HookScript and not boxHooked[box] then
            boxHooked[box] = true
            box:HookScript("OnEditFocusGained", function() if Watch then Watch() end end)
            box:HookScript("OnEditFocusLost", function() if Watch then Watch() end end)
        end
        Part(_G[name .. "Tab"])
        Part(_G[name .. "ButtonFrame"])
        for _, part in ipairs(BORDER) do Part(_G[name .. part]) end
        if chat then
            Part(chat.ScrollToBottomButton)
            Part(chat.ResizeButton)
            Part(chat.ScrollBar)
        end
    end
    for _, name in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
        "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton" }) do
        Part(_G[name])
    end
    return list
end

local parts, partsAt = nil, 0
local faded = {}

-- (its parts, and its own lines: the font strings it draws them on, made
-- more of as it scrolls; each new one faded as it's found)
local function FadeGame(hide)
    if hide then
        local function One(region)
            if not faded[region] then
                IF.Focus.Fade(region, true)
                faded[region] = true
            end
        end
        for _, part in ipairs(parts or {}) do One(part) end
        for _, chat in ipairs(chats) do
            for _, line in ipairs(chat.visibleLines or {}) do One(line) end
        end
    elseif next(faded) then
        for region in pairs(faded) do IF.Focus.Fade(region, false) end
        faded = {}
    end
end

---------------------------------------------------------------------------
-- The game's whole: typed in, the pad on it, the mouse on it lately
---------------------------------------------------------------------------
local function IsChat(f)
    if not f then return false end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local chat = _G["ChatFrame" .. i]
        if f == chat or (chat and f == chat.editBox) then return true end
    end
    return false
end

local mouseX, mouseY, mouseAt = 0, 0, -math.huge
local function MouseOn(now)
    local x, y = GetCursorPosition()
    if x ~= mouseX or y ~= mouseY then mouseX, mouseY, mouseAt = x, y, now end
    if now - mouseAt > MOUSE_SECS or IF.Input.Pad() then return false end
    for _, chat in ipairs(chats) do
        if chat:IsVisible() then
            local ok, over = pcall(chat.IsMouseOver, chat)
            if ok and over == true then return true end
        end
    end
    return false
end

-- (the chat's edit box typed in, or nil)
local function Typing()
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    return box and box.chatFrame and box or nil
end

local function GameChatInUse(now, typing)
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then return true end
    if IF.ChatLines and IF.ChatLines.IsOpen and IF.ChatLines.IsOpen() then return true end
    if typing then return false end
    local m = IF.Focus.Manager()
    if m and m.isUIFocused and IsChat(m.focusedFrame) then return true end
    return MouseOn(now)
end

---------------------------------------------------------------------------
-- Each moment: shown with the fishing view, the game's chat not in use
---------------------------------------------------------------------------
local usedAt = -math.huge

Watch = function()
    if not IF.db then return end
    local now = GetTime()
    -- (read again now and then: a whisper tab is a window opened later)
    if not parts or now - partsAt > 2 then parts, partsAt = Parts(), now end
    local fishing = F.Settings().chat and F.ViewActive and F.ViewActive() or false
    local typing = fishing and Typing() ~= nil
    if fishing and GameChatInUse(now, typing) then usedAt = now end
    local on = fishing and not typing and now - usedAt > HOLD
    local frame = Selected()
    if on and frame ~= current then Rebuild(frame) end
    if on then Place() end
    view:SetShown(on)
    FadeGame(on and not IF.Interface)
end

F.Watcher("fishing chat", 0.1, Watch)

IF.OnLogin(function()
    Rebuild(Selected())
end)

function F.ApplyChat()
    Watch()
end
