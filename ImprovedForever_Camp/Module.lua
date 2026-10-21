-- Improved Forever: Camp. Sitting by a campfire as a cutscene of its own
-- (Scene.lua): the HUD gone, black bars, the camera cutting between shots
-- round you, your day so far told back (the Journal module's diary, when
-- it's on), the time left until the camp's benefits, then the benefits;
-- what's said and whispered near you as subtitles, a line to talk in.
local IF = ImprovedForever

IF.AddModule({ key = "camp", label = "Camp", icon = IF.TEX .. "ic_mod_camp", addon = ... })

local C = {}
IF.Camp = C

local DEFAULTS = {
    scene = true,   -- sitting by a campfire: the cutscene (Scene.lua)
    recap = true,   -- in it, your day told back from the Journal module's diary (else what the camp's about)
    chat = true,    -- in it, what's said and whispered near you as subtitles, Enter to talk
}

function C.Settings()
    IF.db.camp = IF.db.camp or {}
    local s = IF.db.camp
    for key, value in pairs(DEFAULTS) do
        if s[key] == nil then s[key] = value end
    end
    return s
end

-- A watcher: fn() every `every` seconds. One that errors stops, said once
-- in chat: an error each tick would flood the game's error handler, whose
-- popup then runs from our stack and taints the controller's focus (the
-- Immersion module's IN.Watcher, for the same reason).
function C.Watcher(name, every, fn)
    local f = CreateFrame("Frame")
    local since = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        since = since + elapsed
        if since < every then return end
        since = 0
        local ok, err = pcall(fn)
        if not ok then
            self:SetScript("OnUpdate", nil)
            IF.Print("Camp: " .. name .. " stopped after an error: " .. tostring(err))
        end
    end)
    return f
end
