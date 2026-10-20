-- Fishing as a scene of its own: in fishing mode (Mode.lua), out of a
-- fight, the HUD steps back and the camera comes in. Faded
-- (IF.Focus.Fade): the Interface module's gamepad bar, the Wheel module's
-- R3 slot, your frame, your pet's and your party's cards, the buffs and
-- the cooldowns, the experience line, the chat, the objectives. Left: the
-- health line, the target's bar, the minimap, the session's panel and the
-- fishing bar (Panel.lua, CastBar.lua). The camera zooms in to your
-- fishing distance and sits over your shoulder, pitched down, so you stand
-- low on the left of the screen and everything of ours is on the right
-- (the game's ActionCam settings, test_cameraOverShoulder and
-- test_cameraDynamicPitch: the game asks once to allow these
-- "experimental" settings). Put the pole away, or a fight starts: all of
-- it back as it was, your camera settings too (kept per character until
-- then, IF.charDB.fishCamSaved, so a /reload or a logout puts them back).
-- /if fishcam: the distance you're at now kept as the fishing distance;
-- /if fishcam shoulder 0.8, pitch 0.3: the framing.
local IF = ImprovedForever
local F = IF.Fishing

-- (faded while fishing: frames of ours, by name, and the game's tracker
-- when ours isn't loaded)
local FADED = { "ImprovedForeverGamepadBar", "ImprovedForeverRecentSlot", "ImprovedForeverPlayerFrame",
    "ImprovedForeverMinionCard1", "ImprovedForeverPartyCard1", "ImprovedForeverPartyCard2",
    "ImprovedForeverPartyCard3", "ImprovedForeverPartyCard4", "ImprovedForeverPartyCasts",
    "ImprovedForeverBuffList", "ImprovedForeverCooldownTimeline", "ImprovedForeverXPLine",
    "ImprovedForeverChatView", "ImprovedForeverPlayerHealth", "IFObjectiveTrackerFrame" }
-- (without the Interface module, the game's own: its unit frames, its
-- gamepad bar, its XP bar, its buffs. With it, it fades these itself, its
-- own shown over them, and would show one again we'd faded: not twice)
local NATIVE = { "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame", "PartyFrame", "CompactPartyFrame",
    "GamepadMainActionBarFrame", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
    "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }

local CAMERA_DEFAULTS = { zoom = 3.5, shoulder = 2, pitch = 0.12 }
-- (each kept within what still frames you)
-- (pitch: the game's share of the screen kept under your feet; past about
-- 0.4 it changes nothing)
local CAMERA_LIMITS = { zoom = { 1, 15 }, shoulder = { -3, 3 }, pitch = { 0, 0.4 } }
local CVARS = { "test_cameraOverShoulder", "test_cameraDynamicPitch", "test_cameraDynamicPitchBaseFovPad" }
-- (the game's gamepad mode keeps the character centred with a temporary
-- value of its own (Blizzard_Gamepad/Core.lua: SetupTempCVar), over the
-- saved one: ours a temporary one too, the gamepad's put back after)
local CENTERED = "CameraKeepCharacterCentered"

local function Camera()
    local s = F.Settings()
    s.cam = type(s.cam) == "table" and s.cam or {}
    for k, v in pairs(CAMERA_DEFAULTS) do
        local limit = CAMERA_LIMITS[k]
        local value = tonumber(s.cam[k]) or v
        s.cam[k] = math.max(limit[1], math.min(limit[2], value))
    end
    return s.cam
end

local function GetCVarSafe(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, value = pcall(get, name)
    return ok and value or nil
end

local function SetCVarSafe(name, value)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set and value ~= nil then pcall(set, name, tostring(value)) end
end

local function Zoom()
    local ok, z = pcall(GetCameraZoom)
    return ok and type(z) == "number" and z or nil
end

-- (the camera eased to a distance: in or out by the difference)
local function ZoomTo(target)
    local now = Zoom()
    if not (now and target) then return end
    if now > target + 0.1 then
        pcall(CameraZoomIn, now - target)
    elseif now < target - 0.1 then
        pcall(CameraZoomOut, target - now)
    end
end

---------------------------------------------------------------------------
-- In and out
---------------------------------------------------------------------------
local active = false

-- (a frame's 3D model draws through an alpha animation: hidden itself,
-- and back from its unit after)
local function Model(f, on)
    local a = f.avatar
    if not (a and a.model) then return end
    if on then
        a.model:Hide()
    elseif f.unit then
        local UF = IF.Interface and IF.Interface.UnitFrames
        if UF and UF.AvatarUnit then UF.AvatarUnit(a, f.unit, true) end
    end
end

local function Fade(on)
    for _, name in ipairs(FADED) do
        local f = rawget(_G, name)
        if f then
            IF.Focus.Fade(f, on)
            Model(f, on)
        end
    end
    if not rawget(_G, "IFObjectiveTrackerFrame") and _G.ObjectiveTrackerFrame then
        IF.Focus.Fade(ObjectiveTrackerFrame, on)
    end
    if not IF.Interface then
        for _, name in ipairs(NATIVE) do
            local f = rawget(_G, name)
            if f then IF.Focus.Fade(f, on) end
        end
    end
    local PC = IF.Interface and IF.Interface.PartyCards
    for _, label in ipairs(PC and PC.labels or {}) do IF.Focus.Fade(label, on) end
end

-- (the camera: your settings kept, the fishing ones set)
local function CameraIn()
    if not F.Settings().camera or not IF.charDB then return end
    local cam = Camera()
    if not IF.charDB.fishCamSaved then
        local saved = { zoom = Zoom(), cvars = {} }
        for _, name in ipairs(CVARS) do saved.cvars[name] = GetCVarSafe(name) end
        IF.charDB.fishCamSaved = saved
    end
    if C_CVar and C_CVar.SetTempCVar then
        if IF.charDB.fishCamSaved.centered == nil then IF.charDB.fishCamSaved.centered = GetCVarSafe(CENTERED) end
        pcall(C_CVar.SetTempCVar, CENTERED, "0")
    end
    SetCVarSafe("test_cameraOverShoulder", cam.shoulder)
    SetCVarSafe("test_cameraDynamicPitch", 1)
    SetCVarSafe("test_cameraDynamicPitchBaseFovPad", cam.pitch)
    ZoomTo(cam.zoom)
end

-- The fishing camera's framing (FishingEditor.lua's sliders): zoom,
-- shoulder, pitch, each within its limits; set, and seen at once while
-- the fishing view is on
F.CAMERA_LIMITS = CAMERA_LIMITS
function F.CameraGet(key)
    return Camera()[key]
end
function F.CameraSet(key, value)
    local limit = CAMERA_LIMITS[key]
    if not (limit and tonumber(value)) then return end
    Camera()[key] = math.max(limit[1], math.min(limit[2], tonumber(value)))
    if F.ViewActive() then CameraIn() end
end

-- (yours back; the distance only when it's back from fishing)
local function CameraOut(zoomBack)
    local saved = IF.charDB and IF.charDB.fishCamSaved
    if not saved then return end
    for name, value in pairs(saved.cvars or {}) do SetCVarSafe(name, value) end
    -- (centred again: the gamepad's temporary value back, else none)
    if saved.centered ~= nil and C_CVar and C_CVar.SetTempCVar then
        local get = C_CVar.GetCVarBool or GetCVarBool
        local ok, pad = pcall(get, "GamePadEnable")
        if ok and pad then
            pcall(C_CVar.SetTempCVar, CENTERED, saved.centered)
        elseif C_CVar.RemoveTempCVar then
            pcall(C_CVar.RemoveTempCVar, CENTERED)
        end
    end
    if zoomBack then ZoomTo(saved.zoom) end
    IF.charDB.fishCamSaved = nil
end

local function Enter()
    active = true
    Fade(true)
    CameraIn()
end

local function Leave()
    active = false
    Fade(false)
    CameraOut(true)
end

-- On now (the fishing bar takes your other casts then: CastBar.lua)
function F.ViewActive()
    return active
end

local function Wanted()
    return F.Settings().view and F.InMode and F.InMode() and not IF.InCombat()
        and not F.EditMode() or false
end

local function Watch()
    if not IF.db then return end
    local want = Wanted()
    if want and not active then
        Enter()
    elseif not want and active then
        Leave()
    elseif active then
        -- (frames made since: the R3 slot, a party card shown; the camera
        -- setting turned off)
        Fade(true)
        if not F.Settings().camera then
            CameraOut(true)
        elseif IF.charDB and not IF.charDB.fishCamSaved then
            CameraIn()
        end
    end
end

F.Watcher("fishing view", 0.25, Watch)

-- (a fight: out at once, not a quarter second on)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    if active then Leave() end
end)

-- (left in the fishing camera by a /reload or a logout: yours back)
IF.OnLogin(function()
    if IF.charDB and IF.charDB.fishCamSaved and not Wanted() then CameraOut(false) end
end)

-- /if fishcam [shoulder <n> | pitch <n> | zoom <n>]: alone, the distance
-- you're at kept as the fishing one
IF.AddCommand("fishcam", function(args)
    local cam = Camera()
    local key, value = args[1], tonumber(args[2])
    if key and CAMERA_DEFAULTS[key] and value then
        cam[key] = value
    else
        cam.zoom = Zoom() or cam.zoom
    end
    cam = Camera()
    if active then CameraIn() end
    IF.Print(("Fishing camera: distance %.1f, shoulder %.2f, pitch %.2f."):format(cam.zoom, cam.shoulder, cam.pitch))
    -- (what the game has now: the settings it took)
    local now = {}
    for _, name in ipairs({ CENTERED, unpack(CVARS) }) do now[#now + 1] = name .. "=" .. tostring(GetCVarSafe(name)) end
    IF.Print("Now: " .. table.concat(now, ", ") .. (active and " (fishing view on)" or " (fishing view off)"))
end, "[shoulder <n> | pitch <n> | zoom <n>]: the fishing camera (alone: keep the distance you're at)")

F.ApplyView = Watch
