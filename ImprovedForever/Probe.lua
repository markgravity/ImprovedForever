-- /if probe: records how Forever's native radial menu (GamepadRadial) is
-- drawn -- textures, atlases, sizes, anchors, fonts -- into
-- ImprovedForeverDB.probe, so the R3 rings can be styled to match.
local IF = ImprovedForever

local MAX_LINES = 2000

local function Safe(object, method, ...)
    local fn = object[method]
    if type(fn) ~= "function" then
        return nil
    end
    local results = { pcall(fn, object, ...) }
    if results[1] then
        return unpack(results, 2, table.maxn(results))
    end
end

-- tostring() errors on no value at all, which Safe returns for some getters.
local function Str(value)
    return tostring(value)
end

local function Num(value)
    return type(value) == "number" and string.format("%.1f", value) or tostring(value)
end

local function DescribePoints(region)
    local points = {}
    for index = 1, Safe(region, "GetNumPoints") or 0 do
        local point, relativeTo, relativePoint, x, y = Safe(region, "GetPoint", index)
        local relativeName = relativeTo and (Safe(relativeTo, "GetDebugName") or Safe(relativeTo, "GetName")) or "nil"
        points[#points + 1] = string.format("%s>%s:%s(%s,%s)", tostring(point), relativeName,
            tostring(relativePoint), Num(x), Num(y))
    end
    return table.concat(points, " ")
end

local function DescribeRegion(region, prefix, add)
    local kind = Safe(region, "GetObjectType")
    local name = Safe(region, "GetDebugName") or "?"
    local width, height = Safe(region, "GetSize")
    local base = string.format("%s%s [%s] size=%sx%s shown=%s alpha=%s points=%s", prefix, name, tostring(kind),
        Num(width), Num(height), Str(Safe(region, "IsShown")), Num(Safe(region, "GetAlpha")), DescribePoints(region))
    if kind == "Texture" or kind == "MaskTexture" then
        local layer, sublevel = Safe(region, "GetDrawLayer")
        local r, g, b, a = Safe(region, "GetVertexColor")
        local left, top, _, _, _, _, right, bottom = Safe(region, "GetTexCoord")
        add(string.format("%s atlas=%s file=%s layer=%s/%s blend=%s color=%s,%s,%s,%s texcoord=%s,%s,%s,%s rot=%s",
            base, Str(Safe(region, "GetAtlas")), Str(Safe(region, "GetTexture")), tostring(layer),
            tostring(sublevel), Str(Safe(region, "GetBlendMode")), Num(r), Num(g), Num(b), Num(a),
            Num(left), Num(top), Num(right), Num(bottom), Num(Safe(region, "GetRotation"))))
        local masks = {}
        for index = 1, Safe(region, "GetNumMaskTextures") or 0 do
            local mask = Safe(region, "GetMaskTexture", index)
            masks[#masks + 1] = mask and (Safe(mask, "GetAtlas") or Str(Safe(mask, "GetTexture"))) or "?"
        end
        if #masks > 0 then
            add(prefix .. "  masks=" .. table.concat(masks, ","))
        end
    elseif kind == "FontString" then
        local font, size, flags = Safe(region, "GetFont")
        local r, g, b = Safe(region, "GetTextColor")
        add(string.format("%s font=%s size=%s flags=%s color=%s,%s,%s shadow=%s text=%s", base, tostring(font),
            Num(size), tostring(flags), Num(r), Num(g), Num(b), Str(Safe(region, "GetShadowOffset")),
            Str(Safe(region, "GetText")):gsub("\n", " ")))
    else
        add(base)
    end
end

local function Walk(frame, prefix, depth, add)
    if not frame or depth > 8 then
        return
    end
    DescribeRegion(frame, prefix, add)
    add(prefix .. "  strata=" .. Str(Safe(frame, "GetFrameStrata")) .. " level=" .. Str(Safe(frame, "GetFrameLevel"))
        .. " scale=" .. Num(Safe(frame, "GetScale")) .. " effScale=" .. Num(Safe(frame, "GetEffectiveScale")))
    for _, region in ipairs({ Safe(frame, "GetRegions") }) do
        DescribeRegion(region, prefix .. "  ", add)
    end
    for _, child in ipairs({ Safe(frame, "GetChildren") }) do
        Walk(child, prefix .. "  ", depth + 1, add)
    end
end

function IF.StartProbe()
    local out = { started = date("%Y-%m-%d %H:%M:%S"), lines = {} }
    IF.db.probe = out
    local function add(text)
        if #out.lines < MAX_LINES then
            out.lines[#out.lines + 1] = text
        end
    end
    local waiter = CreateFrame("Frame")
    local started = GetTime()
    IF.Print("probe: open the native radial menu (Menu / Options button) within 60 seconds.")
    waiter:SetScript("OnUpdate", function(self)
        local radial = _G.GamepadRadial
        if radial and radial:IsShown() then
            self:SetScript("OnUpdate", nil)
            -- Give it a moment to lay out its entries (and let the player
            -- point at one so the highlight is captured too).
            C_Timer.After(1.5, function()
                Walk(radial, "", 0, add)
                IF.Print("probe recorded " .. #out.lines .. " lines. Close the menu and /reload to save it.")
            end)
        elseif GetTime() - started > 60 then
            self:SetScript("OnUpdate", nil)
            IF.Print("probe: GamepadRadial " .. (radial and "never opened" or "not found") .. ".")
        end
    end)
end

-- /if touchprobe: for 15 seconds records every change in the pad's mapped
-- sticks / axes and raw axes / buttons (swipe on the touchpad meanwhile),
-- plus the touch-related settings, into ImprovedForeverDB.touchProbe.
function IF.StartTouchProbe()
    local out = { started = date("%Y-%m-%d %H:%M:%S"), lines = {} }
    IF.db.touchProbe = out
    local function add(text)
        if #out.lines < MAX_LINES then
            out.lines[#out.lines + 1] = text
        end
    end
    local gamepad = C_GamePad or {}
    local device = gamepad.GetActiveDeviceID and gamepad.GetActiveDeviceID()
    add("device=" .. Str(device) .. " enabled=" .. Str(gamepad.IsEnabled and gamepad.IsEnabled()))
    for _, name in ipairs({ "Left", "Right", "Gyro", "Pad", "Movement", "Camera", "Look", "Cursor" }) do
        add("stick " .. name .. " index=" .. Str(gamepad.StickConfigNameToIndex and gamepad.StickConfigNameToIndex(name)))
    end
    if device and gamepad.GetDeviceRawState then
        local raw = gamepad.GetDeviceRawState(device)
        if raw then
            for key, value in pairs(raw) do
                add("raw." .. Str(key) .. " = " .. (type(value) == "table" and ("table #" .. #value) or Str(value)))
            end
        end
    end
    -- Settings that mention touch or the pad cursor.
    if C_Console and C_Console.GetAllCommands then
        for _, info in ipairs(C_Console.GetAllCommands()) do
            local name = info.command or ""
            if name:lower():find("touch") or name:lower():find("gamepadcursor") then
                add("cvar " .. name .. " = " .. Str(GetCVar(name)))
            end
        end
    end

    -- What each paddle (and A for comparison) runs, counting overrides.
    for _, key in ipairs({ "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PAD1" }) do
        add("binding " .. key .. " = " .. Str(GetBindingAction(key, true)) .. " (plain: " .. Str(GetBindingAction(key)) .. ")")
    end
    for _, name in ipairs({ "GamePadEnable", "GamePadStickAxisButtons", "GamePadEmulateShift", "GamePadEmulateCtrl",
            "GamePadEmulateAlt", "GamePadCursorAutoEnable" }) do
        add("cvar " .. name .. " = " .. Str(GetCVar(name)))
    end

    -- Which buttons arrive as button events (what bindings are run from);
    -- passed on, so the game still gets them.
    local listener = CreateFrame("Frame")
    if listener.EnableGamePadButton and not IF.InCombat() then
        listener:EnableGamePadButton(true)
        listener:SetPropagateKeyboardInput(true)
        listener:SetScript("OnGamePadButtonDown", function(_, button)
            add(string.format("%.2f event down %s", GetTime() - (out.t0 or 0), Str(button)))
        end)
        listener:SetScript("OnGamePadButtonUp", function(_, button)
            add(string.format("%.2f event up %s", GetTime() - (out.t0 or 0), Str(button)))
        end)
    end
    listener:SetScript("OnKeyDown", function(_, key)
        add(string.format("%.2f key down %s", GetTime() - (out.t0 or 0), Str(key)))
    end)

    local last = {}
    local function snapshot(prefix, list)
        if type(list) ~= "table" then
            return
        end
        for index, value in pairs(list) do
            local key = prefix .. index
            local text
            if type(value) == "table" then
                text = string.format("x=%s y=%s len=%s", Num(value.x), Num(value.y), Num(value.len))
            else
                text = type(value) == "number" and string.format("%.2f", value) or Str(value)
            end
            if last[key] ~= text then
                last[key] = text
                add(string.format("%.2f %s %s", GetTime() - out.t0, key, text))
            end
        end
    end
    out.t0 = GetTime()
    local waiter = CreateFrame("Frame")
    IF.Print("touch probe: swipe on the touchpad (up, down, left, right) for 15 seconds.")
    waiter:SetScript("OnUpdate", function(self)
        local id = gamepad.GetActiveDeviceID and gamepad.GetActiveDeviceID()
        local mapped = id and gamepad.GetDeviceMappedState and gamepad.GetDeviceMappedState(id)
        if mapped then
            snapshot("mapped.sticks.", mapped.sticks)
            snapshot("mapped.axes.", mapped.axes)
            snapshot("mapped.buttons.", mapped.buttons)
        end
        local raw = id and gamepad.GetDeviceRawState and gamepad.GetDeviceRawState(id)
        if raw then
            snapshot("raw.rawAxes.", raw.rawAxes)
            snapshot("raw.rawButtons.", raw.rawButtons)
        end
        if GetTime() - out.t0 > 15 then
            self:SetScript("OnUpdate", nil)
            listener:SetScript("OnGamePadButtonDown", nil)
            listener:SetScript("OnGamePadButtonUp", nil)
            listener:SetScript("OnKeyDown", nil)
            if listener.EnableGamePadButton and not IF.InCombat() then
                listener:EnableGamePadButton(false)
            end
            out.t0 = nil
            IF.Print("touch probe recorded " .. #out.lines .. " lines. /reload to save it.")
        end
    end)
end

-- /if padtest: for 15 seconds prints every gamepad button event that
-- reaches the interface (what key bindings are run from), passing each on.
function IF.StartPadTest()
    if IF.InCombat() then
        IF.Print("padtest: out of combat only.")
        return
    end
    local listener = IF.padTestFrame or CreateFrame("Frame")
    IF.padTestFrame = listener
    listener:EnableGamePadButton(true)
    listener:SetPropagateKeyboardInput(true)
    listener:SetScript("OnGamePadButtonDown", function(_, button)
        IF.Print("padtest: down " .. Str(button) .. "  binding=" .. Str(GetBindingAction(button, true)))
    end)
    local started = GetTime()
    listener:SetScript("OnUpdate", function(self)
        if GetTime() - started > 15 and not IF.InCombat() then
            self:SetScript("OnUpdate", nil)
            self:SetScript("OnGamePadButtonDown", nil)
            self:EnableGamePadButton(false)
            IF.Print("padtest: done.")
        end
    end)
    IF.Print("padtest: press Cross, then slide to each touchpad edge (15 seconds).")
end

-- /if escprobe: until /reload, logs into ImprovedForeverDB.escLog every Escape press (kept going to
-- the game) and every ToggleGameMenu, with the state the game's Escape chain looks at.
function IF.StartEscProbe()
    local log = { date("%H:%M:%S") .. " escprobe start" }
    IF.db.escLog = log
    local function State()
        local parts = {}
        local gm = _G.GameMenuFrame
        parts[#parts + 1] = "menu=" .. Str(gm and gm:IsShown())
        parts[#parts + 1] = "bind=" .. Str(GetBindingAction("ESCAPE", true))
        parts[#parts + 1] = "target=" .. Str(UnitExists("target"))
        parts[#parts + 1] = "cast=" .. Str(UnitCastingInfo("player") ~= nil)
        local shown = {}
        for _, name in ipairs(_G.UISpecialFrames or {}) do
            local f = _G[name]
            if f and f.IsShown and f:IsShown() then shown[#shown + 1] = name end
        end
        parts[#parts + 1] = "special={" .. table.concat(shown, ",") .. "}"
        local fcm = _G.GamepadMode and _G.GamepadMode.FrameControlsManager
        if fcm then
            parts[#parts + 1] = "uiFocused=" .. Str(fcm.isUIFocused) .. " shown=" .. Str(fcm.shownFrames and #fcm.shownFrames)
        end
        parts[#parts + 1] = "padInput=" .. Str(IF.Input and IF.Input.Pad and IF.Input.Pad())
        return table.concat(parts, " ")
    end
    local function Add(text) if #log < 400 then log[#log + 1] = string.format("%.2f %s", GetTime() % 1000, text) end end
    local listener = IF.escProbeFrame or CreateFrame("Frame")
    IF.escProbeFrame = listener
    listener:EnableKeyboard(true)
    listener:SetPropagateKeyboardInput(true)
    listener:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then Add("ESC down " .. State()) end
    end)
    if not IF.escProbeHooked and _G.ToggleGameMenu then
        IF.escProbeHooked = true
        hooksecurefunc("ToggleGameMenu", function() Add("ToggleGameMenu ran " .. State()) end)
    end
    IF.Print("escprobe: press Esc a few times in game, then /reload (" .. "lines in escLog).")
end
