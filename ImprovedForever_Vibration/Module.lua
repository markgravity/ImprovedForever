-- Improved Forever: Vibration. The controller's motors on game events and
-- spell casts (Vibration.lua), set up in its tab (VibeEditor.lua). Other
-- modules play their own feedback through IF.Vibe when it is loaded.
local IF = ImprovedForever

IF.AddModule({ key = "vibration", label = "Vibration", icon = IF.TEX .. "ic_mod_vibration", addon = ... })

-- /if vibe: test each vibration motor (which side)
IF.AddCommand("vibe", function() IF.Vibe.TestSides() end, ": test each motor (which side)")
