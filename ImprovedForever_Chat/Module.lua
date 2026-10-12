-- Improved Forever: Chat. Typing with the controller: while a text box has
-- the keyboard's focus, a letter or a word drawn on the touchpad is read
-- (Letters.lua) and put in it (Handwriting.lua), set up in its tab
-- (ChatEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "chat", label = "Chat", icon = IF.TEX .. "ic_mod_chat", addon = ... })

-- /if ink: each drawing read, with each letter's next best guesses
IF.AddCommand("ink", function() IF.Ink.ToggleDebug() end, ": each touchpad drawing read, each letter's runners-up")
