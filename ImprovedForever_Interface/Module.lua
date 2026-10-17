-- Improved Forever: Interface. The game's HUD rearranged: its player and
-- target frames hidden, ours in their place (UnitFrames.lua), your pet
-- and party as cards on the experience line (PartyCards.lua), the
-- experience bar a line along the bottom edge (XPBar.lua), the gamepad
-- bar as two diamonds bottom right (GamepadBar.lua), the chat as only its
-- lines while not in use (ChatView.lua, ChatFade.lua), set up in its tab
-- (InterfaceEditor.lua). The chat isn't moved: the game's place for it,
-- bottom left, is already over the player's frame (moving it through Edit
-- Mode from addon code taints the layout's frames).
local IF = ImprovedForever

IF.AddModule({ key = "interface", label = "Interface", icon = IF.TEX .. "ic_mod_interface", addon = ... })

local IN = {}
IF.Interface = IN

-- /if chatprobe: what keeps the game's chat shown (ChatFade.lua)
IF.AddCommand("chatprobe", function() IN.ChatFade.Probe() end, ": what keeps the game's chat shown")

local DEFAULTS = {
    player = true,      -- the player frame bottom left (and the pet's beside it)
    target = true,      -- the target's health on top, its name over it
    cards = true,       -- your pet and party as cards on the experience line
    chatDim = true,     -- the chat as only its lines while not in use
    xp = true,          -- the experience as a line along the screen's bottom edge
    pad = true,         -- the gamepad bar as Hogwarts Legacy's spell diamonds, bottom right
}

-- A watcher: fn() every `every` seconds. One that errors stops, said once
-- in chat: an error each tick would flood the game's error handler, whose
-- popup then runs from our stack and taints the controller's focus
-- (SetPreferredGamepadInteractTarget forbidden).
function IN.Watcher(name, every, fn)
    local f = CreateFrame("Frame")
    local since = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        since = since + elapsed
        if since < every then return end
        since = 0
        local ok, err = pcall(fn)
        if not ok then
            self:SetScript("OnUpdate", nil)
            IF.Print("Interface: " .. name .. " stopped after an error: " .. tostring(err))
        end
    end)
    return f
end

function IN.Settings()
    local db = IF.db
    db.interface = db.interface or {}
    local settings = db.interface
    for key, value in pairs(DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    -- (0.1.0 moved the chat through Edit Mode: its bookkeeping dropped)
    settings.chat, settings.chatMoved, settings.chatPlaced = nil, nil, nil
    return settings
end
