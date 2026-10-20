-- Improved Forever: Fishing. Fishing from the controller (Fishing.lua):
-- a fishing pole in hand, R2 twice or a double right-click starts fishing
-- mode, Circle or Esc ends it (Mode.lua); in it R2 casts Fishing and R2
-- twice puts your best lure on the pole. The session and what it caught (Session.lua),
-- the game's loot window kept away (AutoLoot.lua), the HUD stepping back
-- and the camera coming in (View.lua), the session's catches (Panel.lua)
-- and a bar of its own for each cast, its catch or miss (CastBar.lua), set
-- in its tab (FishingEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "fishing", label = "Fishing", icon = IF.TEX .. "ic_mod_fishing", addon = ... })

local F = {}
IF.Fishing = F

local DEFAULTS = {
    autoLoot = true,    -- the game's auto loot on in fishing mode (AutoLoot.lua)
    panel = true,       -- the session's catches over the gamepad bar (Panel.lua)
    bar = true,         -- a cast's bar of its own, its catch or miss (CastBar.lua)
    view = true,        -- in fishing mode, out of a fight: the HUD faded, the camera in (View.lua)
    camera = true,      -- and with it the camera over your shoulder (View.lua)
    firstCatch = true,  -- something caught for the first time ever: a moment of its own (FirstCatch.lua)
    chat = true,        -- with the fishing view, the chat by the stringer, faint (Chat.lua)
    guide = true,       -- the line on the screen: how to start fishing, how to stop (Mode.lua)
}
-- (these were the Interface module's once: moved over, then gone from it)
local MOVED = { fishLoot = "panel", fishCatch = "bar", fishMode = "view", fishCamera = "camera", fishCam = "cam" }

function F.Settings()
    IF.db.fishing = IF.db.fishing or {}
    local s = IF.db.fishing
    local old = IF.db.interface
    if old then
        for from, to in pairs(MOVED) do
            if old[from] ~= nil then
                if s[to] == nil then s[to] = old[from] end
                old[from] = nil
            end
        end
    end
    for key, value in pairs(DEFAULTS) do
        if s[key] == nil then s[key] = value end
    end
    return s
end

-- Edit Mode open (the Interface module's own frames then the game's, to be
-- moved): ours step aside too
function F.EditMode()
    local UF = IF.Interface and IF.Interface.UnitFrames
    if UF and UF.EditMode then return UF.EditMode() and true or false end
    return EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
end

-- A watcher: fn() every `every` seconds. One that errors stops, said once
-- in chat: an error each tick would flood the game's error handler, whose
-- popup then runs from our stack and taints the controller's focus (the
-- Interface module's IN.Watcher, for the same reason).
function F.Watcher(name, every, fn)
    local f = CreateFrame("Frame")
    local since = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        since = since + elapsed
        if since < every then return end
        since = 0
        local ok, err = pcall(fn)
        if not ok then
            self:SetScript("OnUpdate", nil)
            IF.Print("Fishing: " .. name .. " stopped after an error: " .. tostring(err))
        end
    end)
    return f
end
