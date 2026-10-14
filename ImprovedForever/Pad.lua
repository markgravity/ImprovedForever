-- Which controller is in hand, and its buttons' names and glyphs. The game
-- ships the glyphs of three styles, picked by the pad's label style as its
-- own prompts do (Blizzard_SharedXML InputIconTexture.lua): "Shapes"
-- (PlayStation), "Letters" (Xbox, and any other pad: "Generic") and
-- "Reverse" (Nintendo Switch). Buttons are named here by place, as the
-- game binds them: A is the bottom face button (PAD1), B the right one
-- (PAD2), X the left (PAD3), Y the top (PAD4). /if buttons: a style can be
-- forced instead of the detected one.
local _, IF = ...

IF.PAD_STYLES = { "auto", "Shapes", "Letters", "Reverse" }
IF.PAD_STYLE_LABELS = {
    auto = "Automatic", Shapes = "PlayStation", Letters = "Xbox", Reverse = "Nintendo Switch",
}

-- Glyph keys of the game's button names
IF.PAD_KEY = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
    PADLSTICK = "LS", PADRSTICK = "RS",
    PADDUP = "DPAD_UP", PADDDOWN = "DPAD_DOWN", PADDLEFT = "DPAD_LEFT", PADDRIGHT = "DPAD_RIGHT",
    PADBACK = "BACK", PADFORWARD = "START", PADSOCIAL = "SHARE", PADSYSTEM = "HOME",
}

-- The game's glyphs per style (its own prompts' atlases), then the older
-- per-style set (Gamepad_Shp_ / _Ltr_ / _Rev_), then the generic one
local ATLAS = {
    Shapes = {
        A = { "gamepad-ps-buttoncrox-normal", "Gamepad_Shp_Cross_64" },
        B = { "gamepad-ps-buttoncircle-normal", "Gamepad_Shp_Circle_64" },
        X = { "gamepad-ps-buttonsquare-normal", "Gamepad_Shp_Square_64" },
        Y = { "gamepad-ps-buttontriangle-normal", "Gamepad_Shp_Triangle_64" },
        LB = { "gamepad-ps-triggerl1-normal", "Gamepad_Shp_LShoulder_64" },
        RB = { "gamepad-ps-triggerr1-normal", "Gamepad_Shp_RShoulder_64" },
        LT = { "gamepad-ps-triggerl2-normal", "Gamepad_Shp_LTrigger_64" },
        RT = { "gamepad-ps-triggerr2-normal", "Gamepad_Shp_RTrigger_64" },
        LS = { "gamepad-ps-stickl3-normal", "Gamepad_Shp_LStickIn_64" },
        RS = { "gamepad-ps-stickr3-normal", "Gamepad_Shp_RStickIn_64" },
        DPAD = { "gamepad-ps-dpadall-normal" },
        DPAD_LR = { "gamepad-ps-dpadleftright-normal" },
        DPAD_UD = { "gamepad-ps-dpadupdown-normal" },
        DPAD_UP = { "gamepad-ps-dpadup-normal", "Gamepad_Shp_Up_64" },
        DPAD_DOWN = { "gamepad-ps-dpaddown-normal", "Gamepad_Shp_Down_64" },
        DPAD_LEFT = { "gamepad-ps-dpadleft-normal", "Gamepad_Shp_Left_64" },
        DPAD_RIGHT = { "gamepad-ps-dpadright-normal", "Gamepad_Shp_Right_64" },
        BACK = { "gamepad-ps-touchpad-normal", "Gamepad_Shp_TouchpadL_64" },
        TOUCHPAD = { "gamepad-ps-touchpad-normal", "Gamepad_Shp_TouchpadL_64" },
        START = { "gamepad-ps-options-normal", "Gamepad_Shp_Menu_64" },
        SHARE = { "gamepad-ps-create-normal", "gamepad-ps-share-normal", "Gamepad_Shp_Share_64" },
        HOME = { "gamepad-ps-pslogo-normal", "Gamepad_Shp_System_64" },
    },
    Letters = {
        A = { "gamepad-xbox1-buttona-normal", "Gamepad_Ltr_A_64" },
        B = { "gamepad-xbox1-buttonb-normal", "Gamepad_Ltr_B_64" },
        X = { "gamepad-xbox1-buttonx-normal", "Gamepad_Ltr_X_64" },
        Y = { "gamepad-xbox1-buttony-normal", "Gamepad_Ltr_Y_64" },
        LB = { "gamepad-xbox1-trigger-lb-normal", "Gamepad_Ltr_LShoulder_64" },
        RB = { "gamepad-xbox1-trigger-rb-normal", "Gamepad_Ltr_RShoulder_64" },
        LT = { "gamepad-xbox1-trigger-lt-normal", "Gamepad_Ltr_LTrigger_64" },
        RT = { "gamepad-xbox1-trigger-rt-normal", "Gamepad_Ltr_RTrigger_64" },
        LS = { "gamepad-xbox1-stick-l3-normal" },
        RS = { "gamepad-xbox1-stick-r3-normal" },
        DPAD = { "gamepad-xbox1-dpadall-normal" },
        DPAD_LR = { "gamepad-xbox1-dpadleftright-normal" },
        DPAD_UD = { "gamepad-xbox1-dpadupdown-normal" },
        DPAD_UP = { "gamepad-xbox1-dpadup-normal", "Gamepad_Ltr_Up_64" },
        DPAD_DOWN = { "gamepad-xbox1-dpaddown-normal", "Gamepad_Ltr_Down_64" },
        DPAD_LEFT = { "gamepad-xbox1-dpadleft-normal", "Gamepad_Ltr_Left_64" },
        DPAD_RIGHT = { "gamepad-xbox1-dpadright-normal", "Gamepad_Ltr_Right_64" },
        BACK = { "gamepad-xbox1-view-normal", "Gamepad_Ltr_View_64" },
        START = { "gamepad-xbox1-menu-normal", "Gamepad_Ltr_Menu_64" },
        SHARE = { "gamepad-xbox1-share-normal", "Gamepad_Ltr_Share_64" },
        HOME = { "gamepad-xbox1-xblogo-normal", "Gamepad_Ltr_System_64" },
    },
    Reverse = {
        -- Nintendo's letters sit the other way round: the bottom button is B
        A = { "gamepad-switch-128x-face-b-normal", "Gamepad_Rev_B_64" },
        B = { "gamepad-switch-128x-face-a-normal", "Gamepad_Rev_A_64" },
        X = { "gamepad-switch-128x-face-y-normal", "Gamepad_Rev_Y_64" },
        Y = { "gamepad-switch-128x-face-x-normal", "Gamepad_Rev_X_64" },
        LB = { "gamepad-switch-128x-shoulder-l-normal", "Gamepad_Rev_LShoulder_64" },
        RB = { "gamepad-switch-128x-shoulder-r-normal", "Gamepad_Rev_RShoulder_64" },
        LT = { "gamepad-switch-128x-zl-normal", "Gamepad_Rev_LTrigger_64" },
        RT = { "gamepad-switch-128x-zr-normal", "Gamepad_Rev_RTrigger_64" },
        LS = { "gamepad-switch-128x-stick-l3-normal" },
        RS = { "gamepad-switch-128x-stick-r3-normal" },
        DPAD = { "gamepad-switch-128x-dpad-all-normal" },
        DPAD_LR = { "gamepad-switch-128x-dpad-leftright-normal" },
        DPAD_UD = { "gamepad-switch-128x-dpad-updown-normal" },
        DPAD_UP = { "gamepad-switch-128x-dpad-up-normal" },
        DPAD_DOWN = { "gamepad-switch-128x-dpad-down-normal" },
        DPAD_LEFT = { "gamepad-switch-128x-dpad-left-normal", "gamepad-switch-128x-dpad-left-default" },
        DPAD_RIGHT = { "gamepad-switch-128x-dpad-right-normal" },
        BACK = { "gamepad-switch-128x-minus-normal", "Gamepad_Rev_Minus_64" },
        START = { "gamepad-switch-128x-plus-normal", "Gamepad_Rev_Plus_64" },
        SHARE = { "gamepad-switch-128x-capture-normal", "Gamepad_Rev_Capture_64" },
        HOME = { "gamepad-switch-128x-home-normal", "Gamepad_Rev_Home_64" },
    },
}
local GENERIC = {
    LB = "Gamepad_Gen_LShoulder_64", RB = "Gamepad_Gen_RShoulder_64",
    LT = "Gamepad_Gen_LTrigger_64", RT = "Gamepad_Gen_RTrigger_64",
    LS = "Gamepad_Gen_LStickIn_64", RS = "Gamepad_Gen_RStickIn_64",
    DPAD_UP = "Gamepad_Gen_Up_64", DPAD_DOWN = "Gamepad_Gen_Down_64",
    DPAD_LEFT = "Gamepad_Gen_Left_64", DPAD_RIGHT = "Gamepad_Gen_Right_64",
    BACK = "Gamepad_Gen_Back_64", START = "Gamepad_Gen_Forward_64",
    SHARE = "Gamepad_Gen_Share_64", HOME = "Gamepad_Gen_System_64",
}
IF.PAD_ATLAS = ATLAS

local NAMES = {
    Shapes = {
        A = "Cross", B = "Circle", X = "Square", Y = "Triangle",
        LB = "L1", RB = "R1", LT = "L2", RT = "R2", LS = "L3", RS = "R3",
        BACK = "Touchpad", TOUCHPAD = "Touchpad", START = "Options", SHARE = "Create", HOME = "PS",
    },
    Letters = {
        A = "A", B = "B", X = "X", Y = "Y",
        LB = "LB", RB = "RB", LT = "LT", RT = "RT", LS = "LS", RS = "RS",
        BACK = "View", START = "Menu", SHARE = "Share", HOME = "Xbox",
    },
    Reverse = {
        A = "B", B = "A", X = "Y", Y = "X",
        LB = "L", RB = "R", LT = "ZL", RT = "ZR", LS = "L3", RS = "R3",
        BACK = "Minus", START = "Plus", SHARE = "Capture", HOME = "Home",
    },
}
local COMMON_NAMES = {
    DPAD = "D-pad", DPAD_LR = "D-pad", DPAD_UD = "D-pad", DPAD_UP = "D-pad Up", DPAD_DOWN = "D-pad Down",
    DPAD_LEFT = "D-pad Left", DPAD_RIGHT = "D-pad Right", TOUCHPAD = "Touchpad",
    PADDLE1 = "Paddle 1", PADDLE2 = "Paddle 2", PADDLE3 = "Paddle 3", PADDLE4 = "Paddle 4",
}

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
IF.HasAtlas = hasAtlas

-- The pad's own style: what the game's prompts use, else what the active
-- pad reports; "Generic" (no pad, or one SDL does not know) shows Xbox's
local function Detected()
    local style
    local manager = InputDeviceIconSetManager
    if manager and manager.GetActiveInputDeviceIconSet then
        style = manager:GetActiveInputDeviceIconSet()
    end
    if not ATLAS[style] and C_GamePad and C_GamePad.GetDeviceMappedState then
        local ok, state = pcall(C_GamePad.GetDeviceMappedState,
            C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID() or nil)
        if ok and type(state) == "table" then style = state.labelStyle end
    end
    return ATLAS[style] and style or "Letters"
end
IF.DetectedPadStyle = Detected

-- The style in use: the one set with /if buttons, else the detected one
function IF.PadStyle()
    local set = IF.db and IF.db.padStyle
    if ATLAS[set] then return set end
    return Detected()
end

function IF.SetPadStyle(style)
    IF.db.padStyle = ATLAS[style] and style or nil
    IF.PadStyleChanged()
end

-- A glyph key's atlas in the style in use, or nil (none in this client)
function IF.GlyphAtlas(key)
    key = IF.PAD_KEY[key] or key
    for _, name in ipairs(ATLAS[IF.PadStyle()][key] or {}) do
        if hasAtlas(name) then return name end
    end
    if GENERIC[key] and hasAtlas(GENERIC[key]) then return GENERIC[key] end
    return nil
end

-- A "Hold to" button, as the game draws its own (Hold to Create All): the
-- glyph inside its press-and-hold ring, the ring lit as the hold comes
-- (0 to 1: SetProgress). IF.HoldRing(parent, anchor, size) puts the ring
-- round an existing icon (a legend prompt's); IF.HoldIcon(parent, size)
-- makes the glyph too (SetKey).
-- (under the icon: its dark disc; round it, at rest: its bronze ring; lit
-- as the hold comes: its gold bar; full: its glow. The ring drawn above the
-- icon, the prompt's icon a frame of its own)
local HOLD_DISC, HOLD_RING = "gamepad-press&hold-indicator-BG", "gamepad-press&hold-indicator"
local HOLD_BAR, HOLD_GLOW = "gamepad-press&hold-loadBar", "gamepad-press&hold-loadBar-glw-BG"

function IF.HoldRing(parent, anchor, size)
    local ring = {}
    local disc = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    disc:SetSize(size, size)
    disc:SetPoint("CENTER", anchor, "CENTER")
    if hasAtlas(HOLD_DISC) then disc:SetAtlas(HOLD_DISC) else disc:Hide() end
    local holder = CreateFrame("Frame", nil, nil)
    holder:SetParent(parent)
    holder:SetSize(size, size)
    holder:SetPoint("CENTER", anchor, "CENTER")
    holder:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or parent:GetFrameLevel()) + 2)
    ring.frame, ring.disc = holder, disc
    local function Layer(atlas, sub)
        local tex = holder:CreateTexture(nil, "OVERLAY", nil, sub)
        tex:SetAllPoints()
        if hasAtlas(atlas) then tex:SetAtlas(atlas) else tex:Hide() end
        return tex
    end
    ring.track = Layer(HOLD_RING, 1)
    ring.bar = Layer(HOLD_BAR, 2)
    ring.glow = Layer(HOLD_GLOW, 3)
    function ring:SetProgress(p)
        if hasAtlas(HOLD_BAR) then self.bar:SetAlpha(p) end
        if hasAtlas(HOLD_GLOW) then self.glow:SetShown(p >= 1) end
    end
    ring:SetProgress(0)
    return ring
end

function IF.HoldIcon(parent, size)
    local f = CreateFrame("Frame", nil, nil)
    f:SetParent(parent)
    f:SetSize(size * 1.4, size * 1.4)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(size, size)
    f.icon:SetPoint("CENTER")
    f.ring = IF.HoldRing(f, f.icon, size * 1.4)
    function f:SetKey(key)
        local atlas = IF.GlyphAtlas(key)
        if atlas then f.icon:SetAtlas(atlas) end
        f.icon:SetShown(atlas ~= nil)
    end
    function f:SetProgress(p) self.ring:SetProgress(p) end
    return f
end

-- The game's button legend (its footer box: slot and neutral border, its
-- prompt templates; 10 padding, 15 between prompts), for a panel of ours:
-- legend = IF.InputLegend(parent); legend:Set(defs) lays it out and shows
-- it (nil: hidden). A def: { key, glyph, text } (key: the button, "PAD1";
-- glyph: its IF.GlyphText key, when no template; hold = true: the game's
-- press-and-hold ring round it, in legend.rings; pad = true: no button
-- for it with the mouse), or { glyph = "DPAD_LR",
-- text } (one glyph for a pair: the D-pad's left / right, up / down).
-- Placed by the caller.
local LEGEND_PAD, PROMPT_GAP = 10, 15
local legends = setmetatable({}, { __mode = "k" })
function IF.InputLegend(parent)
    local legend = CreateFrame("Frame", nil, nil)
    legend:SetParent(parent)
    legend:SetFrameStrata(parent:GetFrameStrata())
    legend:SetFrameLevel(parent:GetFrameLevel() + 5)
    legend:Hide()
    local slot = legend:CreateTexture(nil, "BACKGROUND")
    if hasAtlas("gamepad-footer-slot-bg") then slot:SetAtlas("gamepad-footer-slot-bg")
    else slot:SetColorTexture(0.05, 0.04, 0.03, 0.92) end
    slot:SetAllPoints()
    local border = legend:CreateTexture(nil, "BORDER")
    if hasAtlas("gamepad-footer-slot-frameneutral") then border:SetAtlas("gamepad-footer-slot-frameneutral") end
    border:SetAllPoints()
    local built = {}
    legend.rings = {}
    local textFont                  -- (the prompts' own font, for a glyph's)

    -- A glyph and its words, as a prompt looks
    local function GlyphPrompt(def)
        local x = CreateFrame("Frame", nil, nil)
        x:SetParent(legend)
        local icon = x:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT")
        local atlas = IF.GlyphAtlas(def.glyph)
        if atlas then icon:SetAtlas(atlas) end
        local text = x:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if textFont then text:SetFontObject(textFont) end
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetText(def.text)
        x:SetSize(24 + 4 + text:GetStringWidth(), 24)
        return x
    end

    local function Build(defs)
        if built[defs] then return built[defs] end
        local prompts = {}
        built[defs] = prompts
        for i, def in ipairs(defs) do
            local pair = type(def[1]) == "table"
            local ok, p
            if def.glyph then ok, p = pcall(GlyphPrompt, def) else ok, p = pcall(function()
                local x = CreateFrame("Frame", nil, nil,
                    pair and "InputPromptTwoIconWithTextTemplate" or "InputPromptOneIconWithTextTemplate")
                x:SetParent(legend)
                if pair then
                    x:SetPromptInputIconKey(1, def[1][1])
                    x:SetPromptInputIconKey(2, def[1][2])
                    -- (either of the pair: the game's "/" between, not its big "+")
                    if _G.GAMEPAD_PROMPT_DIVIDER_SLASH then x:SetDividerType(_G.GAMEPAD_PROMPT_DIVIDER_SLASH) end
                else
                    x:SetPromptInputIconKey(1, def[1])
                end
                x:SetPromptText(def[3])
                x:EnablePrompt()
                local fs = x.ControlDescText and x.ControlDescText.FontString
                if fs and not textFont then textFont = fs:GetFontObject() end
                if def.hold then
                    x.holdRing = IF.HoldRing(x, x:GetInputIconControl(1), 32)
                    legend.rings[#legend.rings + 1] = x.holdRing
                end
                return x
            end) end
            if not ok or not p then
                -- (no prompt template: the glyphs and the words)
                p = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                local glyphs = ""
                for _, g in ipairs(type(def[2]) == "table" and def[2] or { def[2] or def.glyph }) do
                    glyphs = glyphs .. IF.GlyphText(g, 26)
                end
                p:SetText(glyphs .. " " .. (def[3] or def.text))
            end
            prompts[i] = p
        end
        return prompts
    end

    -- With the mouse: no legend (the game's mouse windows have none), the
    -- game's buttons inside the window instead, in legend.row (at its
    -- bottom right; the caller may place it elsewhere): one per press that
    -- does something (not the D-pad's moves, the sticks', or a def with
    -- pad = true: the pad's own, as the L2 / R2 switch), pressed and
    -- released as the pad's button would be (a hold: held down, its bar
    -- filling, in legend.rings). Only when legend:SetPress(press) gave it
    -- where to: press(key, down), or a catcher frame (its OnGamePadButton
    -- Down / Up).
    local row = CreateFrame("Frame", nil, nil)
    row:SetParent(parent)
    row:SetFrameLevel(parent:GetFrameLevel() + 5)
    row:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 10)
    row:SetSize(1, 24)
    row:Hide()
    legend.row = row
    local mouseBuilt = {}
    local function Pressed(key, down)
        local press = legend.press
        if type(press) == "function" then return press(key, down) end
        local handler = press and press:GetScript(down and "OnGamePadButtonDown" or "OnGamePadButtonUp")
        if handler then handler(press, key) end
    end

    local function MouseButton(def)
        local b = CreateFrame("Button", nil, nil, "UIPanelButtonTemplate")
        b:SetParent(row)
        b:SetText(def[3] or def.text or "")
        b:SetSize(math.max(64, (b:GetFontString() and b:GetFontString():GetStringWidth() or 60) + 28), 24)
        b:HookScript("OnMouseDown", function(_, button) if button == "LeftButton" then Pressed(def[1], true) end end)
        b:HookScript("OnMouseUp", function(_, button) if button == "LeftButton" then Pressed(def[1], false) end end)
        if def.hold then
            local fill = b:CreateTexture(nil, "OVERLAY")
            fill:SetPoint("BOTTOMLEFT", 4, 3)
            fill:SetHeight(3)
            fill:SetColorTexture(1, 0.82, 0.2, 0.9)
            local bar = { fill = fill }
            function bar:SetProgress(p)
                p = math.max(0, math.min(1, p or 0))
                fill:SetWidth(math.max(0.01, (b:GetWidth() - 8) * p))
                fill:SetShown(p > 0)
            end
            bar:SetProgress(0)
            legend.rings[#legend.rings + 1] = bar
        end
        return b
    end

    local SKIP = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true,
        PADRSTICK = true }
    local function MouseList(defs)
        if mouseBuilt[defs] then return mouseBuilt[defs] end
        local list = {}
        for _, def in ipairs(defs) do
            local key = def[1]
            if type(key) == "string" and not SKIP[key] and not def.pad and (def[3] or def.text) then
                list[#list + 1] = MouseButton(def)
            end
        end
        mouseBuilt[defs] = list
        return list
    end

    local function Lay(list, gap)
        local x, height = 0, 0
        for _, p in ipairs(list) do
            p:ClearAllPoints()
            p:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + p:GetWidth() + gap
            height = math.max(height, p:GetHeight())
        end
        row:SetSize(math.max(1, x - gap), math.max(1, height))
    end

    -- (hidden: its buttons too)
    local hide = legend.Hide
    function legend:Hide()
        hide(self)
        row:Hide()
    end

    function legend:SetPress(press)
        self.press = press
        if self.defs then self:Set(self.defs) end
    end

    function legend:Set(defs)
        self.defs = defs
        if not defs then return self:Hide() end
        local mouse = not IF.Input.Pad()
        local list = (mouse and self.press) and MouseList(defs) or {}
        for set, ps in pairs(mouseBuilt) do
            for _, p in ipairs(ps) do p:SetShown(mouse and set == defs) end
        end
        for set, ps in pairs(built) do
            for _, p in ipairs(ps) do p:SetShown(not mouse and set == defs) end
        end
        if mouse then
            self:Hide()
            if #list > 0 then
                Lay(list, 8)
                row:Show()
            end
            return
        end
        row:Hide()
        list = Build(defs)
        for set, ps in pairs(built) do
            for _, p in ipairs(ps) do p:SetShown(set == defs) end
        end
        local x, height = LEGEND_PAD, 0
        for _, p in ipairs(list) do
            p:ClearAllPoints()
            p:SetPoint("LEFT", self, "LEFT", x, 0)
            x = x + p:GetWidth() + PROMPT_GAP
            height = math.max(height, p:GetHeight())
        end
        self:SetSize(x - PROMPT_GAP + LEGEND_PAD, height + 2 * LEGEND_PAD)
        self:Show()
    end

    legends[legend] = true
    return legend
end

-- The input changed: each legend in use laid out again for it
IF.OnLogin(function()
    IF.Input.OnChange(function()
        for legend in pairs(legends) do
            if legend.defs then legend:Set(legend.defs) end
        end
    end)
end)

-- A button's name as printed on the pad in use ("Cross", "A", "B"...)
function IF.ButtonName(key)
    key = IF.PAD_KEY[key] or key
    local paddle = key:match("^PADPADDLE(%d)$")
    if paddle then return "Paddle " .. paddle end
    return NAMES[IF.PadStyle()][key] or COMMON_NAMES[key] or key
end

-- A button inline in a text: its glyph, else its name
function IF.GlyphText(key, size)
    local atlas = IF.GlyphAtlas(key)
    if atlas then
        return string.format("|A:%s:%d:%d|a", atlas, size or 16, size or 16)
    end
    return IF.ButtonName(key)
end

-- The R3 combos' names in the style in use ("L1 + R3", "LB + RS"...)
local COMBO_HELD = { L1 = "LB", L2 = "LT", R1 = "RB", R2 = "RT" }
local function RefreshComboLabels()
    for _, combo in ipairs(IF.COMBOS) do
        local held = COMBO_HELD[combo]
        IF.COMBO_LABELS[combo] = (held and IF.ButtonName(held) .. " + " or "") .. IF.ButtonName("RS")
    end
end

-- Called when the style may have changed (a pad plugged in, the setting)
local listeners = {}
function IF.OnPadStyleChanged(fn)
    listeners[#listeners + 1] = fn
end

local lastStyle
function IF.PadStyleChanged()
    local style = IF.PadStyle()
    RefreshComboLabels()
    if style == lastStyle then return end
    lastStyle = style
    for _, fn in ipairs(listeners) do fn(style) end
end

IF.OnLogin(IF.PadStyleChanged)

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED" }) do
    pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function()
    if IF.db then IF.PadStyleChanged() end
end)
if InputDeviceIconSetManager and InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback then
    InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(function()
        if IF.db then IF.PadStyleChanged() end
    end, watcher)
end

-- A text with buttons in braces named for the pad in hand:
-- "{A} confirms, {B} cancels" -> "Cross confirms, Circle cancels"
function IF.PadText(text)
    return (text:gsub("{(%u[%u_]*)}", function(key) return IF.ButtonName(key) end))
end
