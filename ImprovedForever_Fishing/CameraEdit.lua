-- The fishing camera framed in game: in fishing mode (the fishing view and
-- its camera on, nothing else open), Triangle or Alt-F starts the camera
-- edit (Mode.lua's presses: F.CameraStart). In it:
--   the controller: L2 / R2 held bring the camera in / out, L1 / R1 held
--     move you left / right on the screen, the D-pad up / down lower /
--     raise you; Cross keeps, Circle leaves;
--   the keyboard: the mouse wheel brings the camera in / out (the game's
--     own), A / D (or the arrows) left / right, W / S (or the arrows)
--     lower / higher; Enter keeps, Esc leaves.
-- The sticks, R3 and the mouse still the game's. What it does shows on the
-- guide line, top left (Mode.lua). Kept: the Fishing tab's camera settings
-- (View.lua: settings and distance, as DialogueUI frames its scenes; the
-- camera's turn isn't kept). Left: the kept one back. A fight ends it, the
-- kept one back.
-- In the edit the presses it uses are bound to a button of ours doing
-- nothing (their own actions don't run: the crossbar's, walking), read by
-- IsKeyDown; keep and leave act at their release (so the release isn't the
-- game's).
local IF = ImprovedForever
local F = IF.Fishing

local PAD_KEYS = { "PADLTRIGGER", "PADRTRIGGER", "PADLSHOULDER", "PADRSHOULDER", "PADDUP", "PADDDOWN", "PAD1", "PAD2",
    "PAD3", "PAD4", "PADDLEFT", "PADDRIGHT" }
local KEYBOARD_KEYS = { "A", "D", "W", "S", "LEFT", "RIGHT", "UP", "DOWN", "ENTER" }
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
-- (how fast, held: the distance in yards a second, the others a second)
local ZOOM_RATE, SHOULDER_RATE, PITCH_RATE = 4, 1.5, 0.2

local editing = false
local cam                                -- (the framing tried: { zoom, shoulder, pitch })

function F.CameraEditing()
    return editing
end

local function Usable()
    return F.InMode and F.InMode() and F.ViewActive and F.ViewActive() and F.Settings().camera
        and not IF.InCombat() or false
end
F.CameraEditUsable = Usable

---------------------------------------------------------------------------
-- The presses: bound to nothing while editing (their own actions kept from
-- running), read as they're held
---------------------------------------------------------------------------
local owner = CreateFrame("Frame", "ImprovedForeverFishingCameraBinds")
local sink = CreateFrame("Button", "ImprovedForeverFishingCameraSink", UIParent)
sink:SetSize(1, 1)
sink:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
sink:RegisterForClicks("AnyDown", "AnyUp")
local leave = CreateFrame("Button", "ImprovedForeverFishingCameraLeave", UIParent)
leave:SetSize(1, 1)
leave:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)

local function Bind(on)
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    if not on then return end
    for _, list in ipairs({ PAD_KEYS, KEYBOARD_KEYS }) do
        for _, key in ipairs(list) do
            for _, prefix in ipairs(PREFIXES) do
                SetOverrideBindingClick(owner, true, prefix .. key, sink:GetName(), "LeftButton")
            end
        end
    end
    SetOverrideBindingClick(owner, true, "ESCAPE", leave:GetName(), "LeftButton")
end

local Stop

local function Start()
    if editing or not Usable() then return end
    editing = true
    cam = {
        zoom = F.CameraZoom and F.CameraZoom() or F.CameraGet("zoom"),
        shoulder = F.CameraGet("shoulder"),
        pitch = F.CameraGet("pitch"),
    }
    Bind(true)
    -- (R2 no longer the cast's: Fishing.lua lets it go at once)
    if F.Apply then F.Apply() end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
end

-- (keep: the framing as the fishing one; else the kept one back)
Stop = function(keep)
    if not editing then return end
    editing = false
    Bind(false)
    if F.Apply then F.Apply() end
    if keep then
        F.CameraSet("zoom", F.CameraZoom and F.CameraZoom() or cam.zoom)
        F.CameraSet("shoulder", cam.shoulder)
        F.CameraSet("pitch", cam.pitch)
        IF.Print(("Fishing camera kept: distance %.1f, left / right %.1f, height %.2f."):format(
            F.CameraGet("zoom"), F.CameraGet("shoulder"), F.CameraGet("pitch")))
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    else
        F.CameraPreview(nil)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
    end
end
leave:SetScript("OnClick", function() Stop(false) end)

local function Clamp(key, value)
    local limit = F.CAMERA_LIMITS and F.CAMERA_LIMITS[key]
    if not limit then return value end
    return math.max(limit[1], math.min(limit[2], value))
end

local function Down(...)
    for i = 1, select("#", ...) do
        if IsKeyDown((select(i, ...))) then return 1 end
    end
    return 0
end

local was = {}
local function Edge(key)
    local down = IsKeyDown(key) and true or false
    local before = was[key]
    was[key] = down
    return down and not before, not down and before, down
end

local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function(_, elapsed)
    if not (IF.db and IsKeyDown and editing) then return end
    if not Usable() then return Stop(false) end
    -- (keep: Cross or Enter; leave: Circle (Esc: its binding): at their release)
    local _, keepPad = Edge("PAD1")
    local _, keepKey = Edge("ENTER")
    local _, back = Edge("PAD2")
    if keepPad or keepKey then return Stop(true) end
    if back then return Stop(false) end
    local changed = false
    local inOut = Down("PADRTRIGGER") - Down("PADLTRIGGER")
    if inOut ~= 0 then
        local zoom = F.CameraZoom and F.CameraZoom()
        local limit = F.CAMERA_LIMITS and F.CAMERA_LIMITS.zoom
        local step = ZOOM_RATE * elapsed
        if inOut > 0 and (not (zoom and limit) or zoom < limit[2]) then
            pcall(CameraZoomOut, step)
        elseif inOut < 0 and (not (zoom and limit) or zoom > limit[1]) then
            pcall(CameraZoomIn, step)
        end
    end
    local side = Down("PADRSHOULDER", "D", "RIGHT") - Down("PADLSHOULDER", "A", "LEFT")
    if side ~= 0 then
        cam.shoulder = Clamp("shoulder", cam.shoulder + side * SHOULDER_RATE * elapsed)
        changed = true
    end
    local height = Down("PADDUP", "W", "UP") - Down("PADDDOWN", "S", "DOWN")
    if height ~= 0 then
        cam.pitch = Clamp("pitch", cam.pitch + height * PITCH_RATE * elapsed)
        changed = true
    end
    if changed then
        F.CameraPreview({ shoulder = cam.shoulder, pitch = cam.pitch })
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    -- (a fight: bindings can't change in one; it's begun, not yet locked)
    if editing then Stop(false) end
end)

-- The camera edit begun (Mode.lua's press), when it can be
function F.CameraStart()
    if F.NothingOpen and F.NothingOpen() then Start() end
end
