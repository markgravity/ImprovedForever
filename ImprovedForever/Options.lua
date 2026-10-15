-- Esc > Options > AddOns > Improved Forever: how to open the controller
-- panel, which holds every module's settings. No button: closing Options
-- from addon code (HideUIPanel) gets SetPreferredGamepadInteractTarget
-- forbidden, and the pad can't reach a canvas page's buttons anyway.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C

local INTRO = "Every module's settings live in the controller panel."

-- Gold, for what to type or press
local function Key(text)
    return "|cffffd24a" .. text .. "|r"
end

-- The tip's lines, with the pad's glyphs as they are now
local function TipLines()
    local lines = { "Type " .. Key("/if") .. " in chat" }
    if IF.db and IF.db.menuDouble ~= false then
        lines[#lines + 1] = "Press " .. IF.GlyphText("PADFORWARD", 18) .. " " .. Key("Menu twice") .. " on the controller"
    end
    lines[#lines + 1] = "Or bind " .. Key("Toggle Improved Forever panel") .. " in Key Bindings > AddOns"
    return lines
end

local CONTROLS = "In the panel: D-pad to move, {A} to choose, {B} to go back; "
    .. "or click, the wheel to scroll, Esc to close."

---------------------------------------------------------------------------
-- The page: its title, and a dark box (the tooltip's border round it) with
-- the ways in, redrawn as it shows (the glyphs and settings of now)
---------------------------------------------------------------------------
local function CanvasPanel()
    local panel = K.NewFrame("Frame")
    panel.name = IF.TITLE

    local heading = K.Text(panel, 20, KC.title)
    heading:SetPoint("TOPLEFT", 24, -24)
    heading:SetText(IF.TITLE)

    local tip = IF.UI.Panel(panel, 0.85)
    tip:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -20)
    tip:SetPoint("RIGHT", panel, "RIGHT", -24, 0)

    local intro = K.Text(tip, 14, KC.cream)
    intro:SetPoint("TOPLEFT", 16, -14)
    intro:SetText(INTRO)

    local title = K.Text(tip, 15, KC.title)
    title:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
    title:SetText("To open it")

    local rows = {}
    local controls = K.ChatText(tip, 13, KC.help)
    controls:SetWordWrap(true)

    local function Render()
        local lines = TipLines()
        local height = 14 + intro:GetStringHeight() + 14 + title:GetStringHeight()
        local prev = title
        for i, text in ipairs(lines) do
            local row = rows[i]
            if not row then
                row = K.Text(tip, 14, KC.cream)
                rows[i] = row
            end
            local gap = i == 1 and 12 or 8
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
            row:SetPoint("RIGHT", tip, "RIGHT", -16, 0)
            row:SetText("|cffffd24a•|r  " .. text)
            row:Show()
            height = height + gap + row:GetStringHeight()
            prev = row
        end
        for i = #lines + 1, #rows do rows[i]:Hide() end
        controls:ClearAllPoints()
        controls:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
        controls:SetPoint("RIGHT", tip, "RIGHT", -16, 0)
        controls:SetText(IF.PadText(CONTROLS))
        tip:SetHeight(height + 14 + controls:GetStringHeight() + 16)
    end
    panel:SetScript("OnShow", Render)
    Render()
    return panel
end

IF.OnLogin(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CanvasPanel()
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(CanvasPanel())
    end
end)

---------------------------------------------------------------------------
-- The core's commands (each module adds its own: /if help lists them)
---------------------------------------------------------------------------
-- /if glyphs: the controller style in use, and each style's glyphs this
-- client has (a missing one shows our own, or the button's name)
IF.AddCommand("glyphs", function()
    IF.Print("Buttons: " .. IF.PAD_STYLE_LABELS[IF.PadStyle()] .. " (detected: "
        .. IF.PAD_STYLE_LABELS[IF.DetectedPadStyle()] .. ", set: " .. IF.PAD_STYLE_LABELS[IF.db.padStyle or "auto"] .. ")")
    for _, style in ipairs(IF.PAD_STYLES) do
        local glyphs = IF.PAD_ATLAS[style]
        if glyphs then
            local found, missing = 0, {}
            for key, names in pairs(glyphs) do
                local any = false
                for _, name in ipairs(names) do
                    if IF.HasAtlas(name) then any = true break end
                end
                if any then found = found + 1 else missing[#missing + 1] = key end
            end
            table.sort(missing)
            IF.Print(IF.PAD_STYLE_LABELS[style] .. ": " .. found .. " glyphs"
                .. (#missing > 0 and ", missing " .. table.concat(missing, " ") or ""))
        end
    end
end, ": the controller style and its glyphs")

-- /if buttons <style>: which controller's buttons to show
IF.AddCommand("buttons", function(args)
    local styles = { auto = "auto", playstation = "Shapes", ps = "Shapes", xbox = "Letters", switch = "Reverse",
        nintendo = "Reverse" }
    local style = styles[args[1] or ""]
    if not style then
        IF.Print("usage: /if buttons <auto|playstation|xbox|switch> (now: "
            .. (IF.db.padStyle and IF.PAD_STYLE_LABELS[IF.db.padStyle] or "automatic") .. ")")
        return
    end
    IF.SetPadStyle(style)
    IF.Print("Buttons shown: " .. IF.PAD_STYLE_LABELS[style]
        .. (style == "auto" and (" (" .. IF.PAD_STYLE_LABELS[IF.DetectedPadStyle()] .. ")") or ""))
end, "<auto|playstation|xbox|switch>: which buttons to show")

-- Probe.lua's recorders
IF.AddCommand("probe", function() IF.StartProbe() end, ": record the native radial menu's look")
IF.AddCommand("touchprobe", function() IF.StartTouchProbe() end, ": record what the touchpad reports")
IF.AddCommand("padtest", function() IF.StartPadTest() end)
