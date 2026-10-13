-- Picking a chat line with the controller, then what's linked in it.
-- While the game's chat window has the pad (its edit box focused, Forever's
-- own gamepad chat: FloatingChatFrame.lua), D-pad Up goes up into its
-- lines: the D-pad moves from line to line (past the top or the bottom
-- one, the chat scrolls), left / right through the links in the line (an
-- item, a spell, a quest, a player...), the link's tooltip beside the
-- chat. Cross on an item opens it in the Library; Square puts the link in
-- the chat's edit box; Circle, or Down past the newest line, goes back to
-- the edit box.
--
-- D-pad Up is watched (IsKeyDown), never bound, and nothing of ours goes
-- into the game's chat window. Once open, a catcher of ours takes the pad
-- (the chat window keeps the game's focus, its edit box the keyboard's),
-- the game's cursor and the chat's legend dimmed (IF.Focus). The lines are
-- only read (the chat frame's visibleLines, their messageInfo); the
-- chat is scrolled with its own ScrollUp / ScrollDown (its secure mixin's).
local IF = ImprovedForever

local K = IF.ConfigKit
local UI = IF.UI
local F = IF.Focus

local CL = {}
IF.ChatLines = CL

local OPEN_KEY = "PADDUP"
local REPEAT_DELAY, REPEAT_RATE = 0.4, 0.08
local MAX_AREAS = 4               -- (a link wrapped over this many lines: the rest unlit)

local DEFAULTS = { enabled = true }

function CL.Settings()
    local db = IF.db
    db.chatLines = db.chatLines or {}
    local settings = db.chatLines
    for key, value in pairs(DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    return settings
end

---------------------------------------------------------------------------
-- What's read
---------------------------------------------------------------------------
local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- (a value of the game's we can use: not secret, of its type)
local function Plain(v, kind)
    if Secret(v) or type(v) ~= kind then return nil end
    return v
end

-- The game's chat window that has the pad (its edit box focused), or nil
local function FocusedChat()
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local chat = box and box.chatFrame
    if not (chat and chat.visibleLines and chat.editBox == box and chat:IsVisible()) then return nil end
    local m = F.Manager()
    if not (m and m.focusedFrame == chat) then return nil end
    return chat
end

-- (a line's top on screen, nil: not shown, or not to be read)
local function Top(line)
    if not (line:IsShown() and line.messageInfo) then return nil end
    local ok, top = pcall(line.GetTop, line)
    return ok and Plain(top, "number") or nil
end

-- The chat's lines on screen, top to bottom (its font strings)
local function Rows(chat)
    local rows, tops = {}, {}
    for _, line in ipairs(chat.visibleLines or {}) do
        local top = Top(line)
        if top then
            rows[#rows + 1] = line
            tops[line] = top
        end
    end
    table.sort(rows, function(a, b) return tops[a] > tops[b] end)
    return rows
end

local function Text(line)
    return Plain(line.messageInfo and line.messageInfo.message, "string")
end

-- A line's links, in order: { link (with its colour), data ("item:..."),
-- kind ("item"), label ("[Linen Cloth]"), s, e (its bytes in the text) };
-- not the channel's ("[2. Trade]": nothing to show or do)
local function Links(text)
    local links = {}
    if not text then return links end
    local pos = 1
    while true do
        local s, e, data, label = text:find("|H(.-)|h(.-)|h", pos)
        if not s then break end
        -- (its colour before it, "|cffxxxxxx" or "|cnNAME:", and its "|r")
        local before = text:sub(1, s - 1)
        local start = before:find("|c%x%x%x%x%x%x%x%x$") or before:find("|cn[^|:]*:$") or s
        local stop = text:sub(e + 1, e + 2) == "|r" and e + 2 or e
        local kind = data:match("^([^:]+)") or data
        if kind ~= "channel" then
            links[#links + 1] = { link = text:sub(start, stop), data = data, kind = kind, label = label, s = start, e = stop }
        end
        pos = e + 1
    end
    return links
end

-- Links with a tooltip of their own (the others: players, channels...)
local TOOLTIP = {
    item = true, spell = true, enchant = true, quest = true, achievement = true, talent = true,
    currency = true, trade = true, unit = true, battlepet = true, instancelock = true,
}

---------------------------------------------------------------------------
-- The picker: our frames over the chat window's lines, the row's and the
-- link's focus (the card stroke, the game's cursor), a legend
---------------------------------------------------------------------------
local overlay = K.NewFrame("Frame", "ImprovedForeverChatLines", UIParent)
overlay:SetFrameStrata("DIALOG")
overlay:SetAllPoints(UIParent)
overlay:EnableMouse(false)
overlay:Hide()

local rowFrame = K.NewFrame("Frame", nil, overlay)
rowFrame.focus = UI.FocusStroke(rowFrame)

local linkFrame = K.NewFrame("Frame", nil, overlay)
linkFrame:SetFrameLevel(rowFrame:GetFrameLevel() + 4)
linkFrame.focus = UI.FocusStroke(linkFrame)

local legend = IF.InputLegend(overlay)

local function Prompts(link)
    local list = { { glyph = "DPAD_UD", text = "Lines" } }
    list[#list + 1] = { glyph = "DPAD_LR", text = "Links" }
    if link and link.kind == "item" and IF.Library and IF.Library.Open then
        list[#list + 1] = { "PAD1", "A", "Library" }
    end
    if link then list[#list + 1] = { "PAD3", "X", "Link in Chat" } end
    list[#list + 1] = { "PAD2", "B", _G.BACK or "Back" }
    return list
end
-- (kept by contents: the legend builds a set of prompts once per table)
local promptSets = {}
local function PromptSet(link)
    local list = Prompts(link)
    local key = {}
    for _, p in ipairs(list) do key[#key + 1] = p[3] or p.text end
    key = table.concat(key, "|")
    promptSets[key] = promptSets[key] or list
    return promptSets[key]
end

-- The prompt to go up into the lines, under the chat while it has the pad
local openLegend = IF.InputLegend(UIParent)
openLegend:SetFrameStrata("DIALOG")
local OPEN_PROMPTS = { { glyph = "DPAD_UP", text = "Chat Lines" } }

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local chat              -- the chat window picked in
local selected          -- the picked line's messageInfo (the game's, read)
local linkIndex = 0     -- 0: the line; else its link
local pendingMove       -- -1 / 1: a line up / down once the chat has scrolled
local held, nextRepeat
local tipFor            -- (the link the tooltip shows)

local function HideTooltip()
    tipFor = nil
    if GameTooltip:IsOwned(overlay) then GameTooltip:Hide() end
end

local function Hide()
    rowFrame.focus:Hide()
    linkFrame.focus:Hide()
    HideTooltip()
end

-- (the picked line among the rows, its index)
local function Find(rows)
    for i, line in ipairs(rows) do
        if line.messageInfo == selected then return i, line end
    end
end

local function ShowTooltip(link)
    if not (link and TOOLTIP[link.kind]) then return HideTooltip() end
    if tipFor == link.data and GameTooltip:IsOwned(overlay) then return end
    tipFor = link.data
    GameTooltip:SetOwner(overlay, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", chat, "TOPRIGHT", 24, 0)
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, link.data) then GameTooltip:Hide() end
end

-- The row's and the link's light, the tooltip, the legend
local function Render()
    local rows = Rows(chat)
    local index, line = Find(rows)
    if not line then
        Hide()
        legend:Set(PromptSet(nil))
        return
    end
    local links = Links(Text(line))
    if linkIndex > #links then linkIndex = #links end
    local link = links[linkIndex]

    rowFrame:ClearAllPoints()
    rowFrame:SetPoint("TOPLEFT", line, "TOPLEFT", -6, 3)
    rowFrame:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 4, -3)
    -- (a link picked: the line dimmed, the link lit, the cursor on it)
    rowFrame.focus:Light(true, link ~= nil)

    linkFrame.focus:Hide()
    if link then
        local ok, areas = pcall(line.CalculateScreenAreaFromCharacterSpan, line, link.s, link.e)
        local area = ok and type(areas) == "table" and areas[1]
        if area and not Secret(area.left) then
            local left, bottom, right, top = area.left, area.bottom, area.left + area.width, area.bottom + area.height
            for i = 2, math.min(#areas, MAX_AREAS) do
                -- (wrapped over lines: the first line's part lit)
                if areas[i].bottom == area.bottom then right = math.max(right, areas[i].left + areas[i].width) end
            end
            linkFrame:ClearAllPoints()
            linkFrame:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", left - 4, bottom - 3)
            linkFrame:SetPoint("TOPRIGHT", line, "BOTTOMLEFT", right + 4, top + 3)
            linkFrame.focus:Light(true)
        else
            -- (its place unknown: the line lit instead)
            rowFrame.focus:Light(true)
        end
    end
    ShowTooltip(link)
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", chat.editBox, "BOTTOMLEFT", 0, -4)
    legend:Set(PromptSet(link))
end

-- The chat's legend (its footer is a table of the game's: the legend frame
-- is in it), or nil
local function ChatLegend(window)
    local footer = window and window.footer
    local legend = type(footer) == "table" and footer.inputLegend
    return legend and legend.GetObjectType and legend or nil
end

local function Close()
    if not overlay:IsShown() then return end
    overlay:Hide()
    Hide()
    legend:Hide()
    if overlay.EnableGamePadButton then pcall(overlay.EnableGamePadButton, overlay, false) end
    F.DimNative(overlay, false)
    F.Fade(ChatLegend(chat), false)
    chat, selected, linkIndex, pendingMove, held = nil, nil, 0, nil, nil
end
CL.Close = Close

function CL.Open(window)
    if IF.InCombat() or not window then return end
    local rows = Rows(window)
    if #rows == 0 then return end
    chat, linkIndex, pendingMove, held = window, 0, nil, nil
    selected = rows[#rows].messageInfo
    overlay:Show()
    if overlay.EnableGamePadButton then overlay:EnableGamePadButton(true) end
    F.DimNative(overlay, true)
    F.Fade(ChatLegend(chat), true)
    if IF.Vibe then IF.Vibe.Play("pulse") end
    Render()
end

function CL.IsOpen()
    return overlay:IsShown()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- A line up (-1) or down (1); the chat scrolled past its ends
local function Move(step)
    local rows = Rows(chat)
    local index = Find(rows)
    if not index then
        selected = rows[#rows] and rows[#rows].messageInfo
        linkIndex = 0
        return Render()
    end
    local to = index + step
    if rows[to] then
        selected, linkIndex = rows[to].messageInfo, 0
        return Render()
    end
    if step > 0 and chat:AtBottom() then return Close() end
    if step < 0 and chat:AtTop() then return end
    -- (the chat scrolled a line; its lines are laid out again next frame)
    if step < 0 then chat:ScrollUp() else chat:ScrollDown() end
    pendingMove = step
end

local function Current()
    local _, line = Find(Rows(chat))
    local links = line and Links(Text(line)) or {}
    return links[linkIndex], links
end

local function Press(button)
    if button == "PADDUP" then
        Move(-1)
    elseif button == "PADDDOWN" then
        Move(1)
    elseif button == "PADDLEFT" or button == "PADDRIGHT" then
        local _, links = Current()
        local to = linkIndex + (button == "PADDRIGHT" and 1 or -1)
        if to >= 0 and to <= #links then
            linkIndex = to
            Render()
        end
    elseif button == "PAD1" then
        local link, links = Current()
        if not link then
            -- (on the line: to its first link)
            if links[1] then
                linkIndex = 1
                Render()
            end
        elseif link.kind == "item" and IF.Library and IF.Library.Open then
            Close()
            IF.Library.Open(link.link, "chat")
        end
    elseif button == "PAD3" then
        local link = Current()
        local box = chat and chat.editBox
        if link and box then
            -- (a player: the name; the rest as links)
            local text = link.link
            if link.kind == "player" or link.kind == "BNplayer" then text = link.data:match("^[^:]+:([^:]+)") end
            if text then box:Insert(text) end
            if IF.Vibe then IF.Vibe.Play("pulse") end
        end
    end
end

local REPEATS = { PADDUP = true, PADDDOWN = true }

if overlay.EnableGamePadButton then
    overlay:SetScript("OnGamePadButtonDown", function(_, button)
        if REPEATS[button] then held, nextRepeat = button, GetTime() + REPEAT_DELAY end
        Press(button)
    end)
    overlay:SetScript("OnGamePadButtonUp", function(_, button)
        if button == held then held = nil end
        -- (Circle closes on its release: else the release goes to the chat)
        if button == "PAD2" then Close() end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself:
    -- off until it is wanted)
    overlay:EnableGamePadButton(false)
end

overlay:SetScript("OnUpdate", function()
    -- Gone from under us: the chat closed, lost the pad, or combat
    if FocusedChat() ~= chat or IF.InCombat() then return Close() end
    if pendingMove then
        local step = pendingMove
        pendingMove = nil
        local rows = Rows(chat)
        local index = Find(rows)
        local to = index and rows[index + step]
        if to then selected, linkIndex = to.messageInfo, 0 end
    end
    if held and IsKeyDown and IsKeyDown(held) and GetTime() >= nextRepeat then
        nextRepeat = GetTime() + REPEAT_RATE
        Press(held)
    end
    -- (new lines in, a scroll by the stick: the light follows the line)
    Render()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", Close)

---------------------------------------------------------------------------
-- D-pad Up watched while the chat has the pad, its prompt under the chat
---------------------------------------------------------------------------
local wasDown, shown = false, false
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
    if not IF.db then return end
    local window = not overlay:IsShown() and not IF.InCombat() and CL.Settings().enabled and FocusedChat()
    local down = IsKeyDown and IsKeyDown(OPEN_KEY) or false
    -- (a press counts if the prompt was up just before it)
    if window and down and not wasDown and shown then
        wasDown, shown = down, false
        openLegend:Hide()
        return CL.Open(window)
    end
    wasDown = down
    shown = window and true or false
    if window then
        openLegend:ClearAllPoints()
        local chatLegend = ChatLegend(window)
        if chatLegend and chatLegend:IsVisible() then
            openLegend:SetPoint("LEFT", chatLegend, "RIGHT", 6, 0)
        else
            openLegend:SetPoint("TOPLEFT", window.editBox, "BOTTOMLEFT", 0, -4)
        end
        openLegend:Set(OPEN_PROMPTS)
    elseif openLegend:IsShown() then
        openLegend:Hide()
    end
end)

-- /if chatlines: what the picker reads (the chat with the pad, its lines,
-- the picked line's links and where they are)
function CL.Probe()
    local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local m = F.Manager()
    local focused = m and m.focusedFrame
    IF.Print("chatlines: keyboard " .. tostring(box and box.GetName and box:GetName()) .. ", pad on "
        .. tostring(focused and focused.GetName and focused:GetName()) .. ", chat " .. tostring(FocusedChat() ~= nil)
        .. ", open " .. tostring(overlay:IsShown()) .. ", on " .. tostring(CL.Settings().enabled))
    local window = chat or FocusedChat() or _G.SELECTED_CHAT_FRAME
    if not window then return end
    local rows = Rows(window)
    IF.Print("chatlines: " .. tostring(window:GetName()) .. ", " .. #rows .. " lines, at bottom "
        .. tostring(window:AtBottom()))
    local _, line = Find(rows)
    line = line or rows[#rows]
    local text = line and Text(line)
    if not text then return IF.Print("chatlines: line text " .. (line and "<hidden>" or "none")) end
    IF.Print("chatlines: " .. text:gsub("|", "||"))
    for i, link in ipairs(Links(text)) do
        local ok, areas = pcall(line.CalculateScreenAreaFromCharacterSpan, line, link.s, link.e)
        local area = ok and type(areas) == "table" and areas[1]
        IF.Print(("chatlines: link %d %s %s, bytes %d-%d, area %s"):format(i, link.kind, link.label, link.s, link.e,
            area and ("%d,%d %dx%d"):format(area.left, area.bottom, area.width, area.height) or tostring(areas)))
    end
end
