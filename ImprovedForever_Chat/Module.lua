-- Improved Forever: Chat. The chat with the controller: its lines picked
-- and what's linked in them (ChatLines.lua), set up in its tab
-- (ChatEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "chat", label = "Chat", icon = IF.TEX .. "ic_mod_chat", addon = ... })

-- /if chatlines: what the line picker reads
IF.AddCommand("chatlines", function() IF.ChatLines.Probe() end, ": what the chat line picker reads")

-- An earlier version wrote letters drawn on the touchpad: its settings
-- gone, the touch cursor it turned off given back
IF.OnLogin(function()
    local ink = IF.db.ink
    if not ink then return end
    if ink.touchCursor ~= nil then
        local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
        pcall(setter, "GamePadTouchCursorEnable", ink.touchCursor)
    end
    IF.db.ink = nil
end)
