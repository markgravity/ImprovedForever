-- The chat blended into the world, in three states:
-- * idle: the game's lines, tabs, edit box, buttons, background, border
--   drawn at 0, ours showing its lines in its place (ChatView.lua):
--   faint, a new one bright for a while;
-- * typing (its edit box typed in, or the pad on it): the game's edit box
--   as it is, under ours, every line of ours at full; the game's tabs,
--   box and own lines still at 0 (the edit box is the game's: its slash
--   commands need it; L1 / R1 still change the tab);
-- * the game's whole (the mouse on it, the Chat module's line picker
--   reading its lines, Edit Mode): all of it at full, ours hidden.
-- A state is kept a moment after it ends (HOLD), so it doesn't flicker.
-- They're the game's: drawn by IF.Focus.Fade (an animation of ours),
-- their own alpha never set. Never the chat window itself (the pad's
-- focus is on it): what's drawn on it and round it instead; its edit box
-- only while the pad isn't on it.
local IF = ImprovedForever
local IN = IF.Interface

local CF = {}
IN.ChatFade = CF

local HOLD = 1.5

-- The chat's parts: { region, role } (by name: as many as the game's chat
-- windows). role: "frame" (a window: its lines are drawn on it, and its
-- edit box is in it), "edit" (an edit box's parts), "tab", "chrome" (the
-- rest)
local BORDER = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }

local chats = {}

local function Parts()
    local list = {}
    local function Add(f, role)
        if f and f.GetObjectType then list[#list + 1] = { f, role } end
    end
    chats = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = "ChatFrame" .. i
        local chat = _G[name]
        if chat then chats[#chats + 1] = chat end
        Add(chat, "frame")
        -- (the edit box's parts, not the box: the game animates its alpha)
        local box = _G[name .. "EditBox"]
        if box and box.GetRegions then
            for _, region in ipairs({ box:GetRegions() }) do Add(region, "edit") end
        end
        Add(_G[name .. "Tab"], "tab")
        Add(_G[name .. "ButtonFrame"], "chrome")
        for _, part in ipairs(BORDER) do Add(_G[name .. part], "chrome") end
        if chat then
            Add(chat.ScrollToBottomButton, "chrome")
            Add(chat.ResizeButton, "chrome")
            Add(chat.ScrollBar, "chrome")
        end
    end
    for _, name in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
        "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton" }) do
        Add(_G[name], "chrome")
    end
    return list
end

-- Each state: which roles are drawn at 0 ("frame": never, its lines
-- instead)
local HIDE = {
    idle = { edit = true, tab = true, chrome = true, lines = true },
    typing = { tab = true, chrome = true, lines = true },
    native = {},
}

local function IsChat(f)
    if not f then return false end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local chat = _G["ChatFrame" .. i]
        if f == chat or (chat and f == chat.editBox) then return true end
    end
    return false
end

-- What the chat is used for now: "native" (the game's whole), "typing",
-- or nil (idle); and what (a word, for the log). The pad on it: the
-- game's focus on a chat window while the UI has the pad (the frame
-- manager keeps its last focused window after the pad left it). The mouse
-- counts only when it moved lately (MOUSE_SECS) and is over a window or
-- its tabs: left parked over the chat it doesn't hold it open.
local MOUSE_SECS = 3
local mouseX, mouseY, mouseAt = 0, 0, -math.huge

local function MouseMoved(now)
    local x, y = GetCursorPosition()
    if x ~= mouseX or y ~= mouseY then
        mouseX, mouseY, mouseAt = x, y, now
    end
    return now - mouseAt <= MOUSE_SECS
end

local function Use(parts, now)
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then return "native", "edit mode" end
    if IF.ChatLines and IF.ChatLines.IsOpen and IF.ChatLines.IsOpen() then return "native", "line picker" end
    if MouseMoved(now) and not IF.Input.Pad() then
        -- (the windows and their tabs only; guarded: a region may not say)
        for _, part in ipairs(parts) do
            local f, role = part[1], part[2]
            if (role == "frame" or role == "tab") and f:IsVisible() then
                local ok, over = pcall(f.IsMouseOver, f)
                if ok and over == true then
                    return "native", "mouse over " .. tostring(f:GetName())
                end
            end
        end
    end
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if box and box.chatFrame then return "typing", "typing" end
    local m = IF.Focus.Manager()
    if m and m.isUIFocused and IsChat(m.focusedFrame) then return "typing", "pad focus" end
    return nil
end

local parts
local partsAt = 0
local last = { native = 0, typing = 0 }
local state

-- The game's own lines (its window itself left alone): the font strings
-- it draws them on, drawn at 0 (it makes more as it scrolls or grows:
-- looked at again each time)
local lineFaded = {}
local function Lines(hide)
    if hide then
        for _, chat in ipairs(chats) do
            for _, line in ipairs(chat.visibleLines or {}) do
                if not lineFaded[line] then
                    IF.Focus.Fade(line, true)
                    lineFaded[line] = true
                end
            end
        end
    elseif next(lineFaded) then
        for line in pairs(lineFaded) do IF.Focus.Fade(line, false) end
        lineFaded = {}
    end
end

-- Each change of state, logged (the last LOG_LINES) in the saved
-- variables: ImprovedForeverDB.chatLog
local LOG_LINES = 40
local function Log(wanted, why)
    local log = IF.db.chatLog or {}
    IF.db.chatLog = log
    log[#log + 1] = string.format("%s %.1f -> %s (%s) pad=%s", date("%H:%M:%S"), GetTime() % 1000,
        tostring(wanted or "off"), tostring(why or "-"), tostring(IF.Input.Pad()))
    while #log > LOG_LINES do table.remove(log, 1) end
end

local function Watch()
    if not IF.db then return end
    local now = GetTime()
    -- (read again now and then: a whisper tab is a window opened later)
    if not parts or now - partsAt > 2 then
        parts, partsAt, state = Parts(), now, false
    end
    local wanted
    local why
    if IN.Settings().chatDim then
        local use
        use, why = Use(parts, now)
        if use then last[use] = now end
        if now - last.native <= HOLD then
            wanted = "native"
        elseif now - last.typing <= HOLD then
            wanted = "typing"
        else
            wanted = "idle"
        end
    end
    IN.ChatView.Update(wanted)
    Lines(HIDE[wanted or "native"].lines or false)
    if wanted == state then return end
    if wanted ~= state and state ~= false then Log(wanted, why) end
    state = wanted
    local hide = HIDE[wanted or "native"]
    for _, part in ipairs(parts) do
        IF.Focus.Fade(part[1], hide[part[2]] and true or false)
    end
end

-- /if chatprobe: what keeps the chat shown, logged for 8 s (into the
-- saved variables: /reload, then read ImprovedForeverDB.chatProbe)
function CF.Probe()
    local log = { date("%H:%M:%S") .. " chat probe" }
    IF.db.chatProbe = log
    IF.Print("chat probe: 8 s, leave the chat alone")
    local n = 0
    local ticker
    ticker = C_Timer.NewTicker(0.5, function()
        n = n + 1
        parts = parts or Parts()
        local _, why = Use(parts, GetTime())
        local m = IF.Focus.Manager()
        local focused = m and m.focusedFrame
        local chat = ChatFrame1
        local box = ChatFrame1EditBox
        local kb = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        local faded, fadedAt = IF.Focus.Faded(box)
        log[#log + 1] = string.format("   box shown=%s alpha=%.2f eff=%.2f faded=%s at=%s kb=%s kbChat=%s parent=%s",
            tostring(box and box:IsShown()), box and box:GetAlpha() or -1, box and box:GetEffectiveAlpha() or -1,
            tostring(faded), tostring(fadedAt), tostring(kb and kb.GetName and kb:GetName()),
            tostring(kb and kb.chatFrame and kb.chatFrame:GetName()),
            tostring(box and box:GetParent() and box:GetParent():GetName()))
        log[#log + 1] = string.format("%.1f use=%s state=%s setting=%s uiFocused=%s focused=%s view=%s alpha=%.2f eff=%.2f",
            GetTime() % 1000, tostring(why), tostring(state), tostring(IN.Settings().chatDim),
            tostring(m and m.isUIFocused), tostring(focused and focused.GetName and focused:GetName()),
            tostring(ImprovedForeverChatView and ImprovedForeverChatView:IsShown()),
            chat and chat:GetAlpha() or -1, chat and chat:GetEffectiveAlpha() or -1)
        if n >= 16 then
            ticker:Cancel()
            IF.Print("chat probe done: " .. #log .. " lines; /reload to save them")
        end
    end)
end

CF.Apply = function()
    state = false
    Watch()
end

IN.Watcher("chat", 0.1, Watch)
