-- Improved Forever: Map. The peek map: the game's map shown while a press
-- is held (PeekMap.lua), placed and sized in its tab (PeekMapEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "map", label = "Map", icon = IF.TEX .. "ic_mod_map", addon = ... })

-- /if peek: the peek map's hotkey binding; prints each press
IF.AddCommand("peek", function() IF.PeekMap.Probe() end, ": the peek map's binding, each press")

