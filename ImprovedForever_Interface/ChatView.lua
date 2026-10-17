-- Our chat, the view of the game's lines (ChatFade.lua says when): idle,
-- in its place without box, tabs or edit box, every line barely there, a
-- new one bright for a while, fading back; typing, every line at full
-- over the game's edit box. The game's whole chat (the mouse on it, the
-- Chat module's line picker): ours hidden.
-- Two message frames of ours, one over the other, fed the same lines in
-- the same order so they lie on each other: the back one at DIM, never
-- fading; the front one at full, its lines fading out after BRIGHT
-- seconds.
-- The lines come from the game's chat frames as they're added
-- (hooksecurefunc, after the game's own AddMessage: a replaced one would
-- taint its callers), the tab shown in its dock only; a tab picked: its
-- recent lines read back (GetMessageInfo). They can be secret: they're
-- only handed on, never read. Ours sit over the game's frame by its rect,
-- in its font, not anchored to it.
local IF = ImprovedForever
local IN = IF.Interface

local CV = {}
IN.ChatView = CV

local DIM, BRIGHT, FADE, MAX_LINES = 0.22, 10, 3, 80

local view = CreateFrame("Frame", "ImprovedForeverChatView", UIParent)
view:SetFrameStrata("LOW")
view:EnableMouse(false)
view:Hide()

local function Layer(alpha, fading)
    local f = CreateFrame("ScrollingMessageFrame", nil, view)
    f:SetAllPoints()
    f:SetMaxLines(MAX_LINES)
    f:SetJustifyH("LEFT")
    f:SetIndentedWordWrap(true)
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
local layers = { back, front }

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

-- Every chat frame the game has (its windows, and whisper tabs opened
-- since: CHAT_FRAMES lists them by name), hooked once
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

-- Its font, as the game has it for that window
local function Font(frame)
    local ok, font, size, flags = pcall(frame.GetFont, frame)
    if not (ok and font) then return end
    for _, layer in ipairs(layers) do
        layer:SetFont(font, size, flags)
    end
end

-- A tab picked: its recent lines read back (into the dim layer only: the
-- bright one is for new lines)
local function Rebuild(frame)
    current = frame
    Hook()
    back:Clear()
    front:Clear()
    if not frame then return end
    Font(frame)
    local ok, n = pcall(frame.GetNumMessages, frame)
    if not ok or type(n) ~= "number" then return end
    for i = math.max(1, n - MAX_LINES + 1), n do
        local got, text, r, g, b = pcall(frame.GetMessageInfo, frame, i)
        if got then Add(back, text, r, g, b) end
    end
end

-- Over the game's frame, by its rect (it's moved in Edit Mode, resized)
local placed = {}
local function Place(frame)
    local l, b, w, h = frame:GetRect()
    if not (l and b and w and h) then return false end
    local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    l, b, w, h = l * k, b * k, w * k, h * k
    if placed.l ~= l or placed.b ~= b or placed.w ~= w or placed.h ~= h then
        placed.l, placed.b, placed.w, placed.h = l, b, w, h
        view:ClearAllPoints()
        view:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        view:SetSize(w, h)
    end
    return true
end

---------------------------------------------------------------------------
-- The state ChatFade.lua says: "idle" (faint, new lines bright), "typing"
-- (all at full), nil (hidden); its tab followed
---------------------------------------------------------------------------
local shownState

function CV.Update(state)
    local frame = Selected()
    if frame ~= current then Rebuild(frame) end
    local on = (state == "idle" or state == "typing") and frame ~= nil and frame:IsVisible() and Place(frame)
    view:SetShown(on and true or false)
    if on and state ~= shownState then
        shownState = state
        back:SetAlpha(state == "typing" and 1 or DIM)
        -- (typing: the back one alone, at full; the front one's lines on it
        -- would draw them twice)
        front:SetShown(state == "idle")
    end
end

IF.OnLogin(function()
    Rebuild(Selected())
end)
