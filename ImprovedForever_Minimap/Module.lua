-- Improved Forever: Minimap (was Gather). Names beside the minimap's dots
-- (NodeScan.lua, Minimap.lua), set up in its tab (MinimapEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "minimap", label = "Minimap", icon = IF.TEX .. "ic_mod_gather", addon = ... })

-- /if nodes: list what the minimap shows (step / debug tune it)
IF.AddCommand("nodes", function(args) IF.Minimap.Command(args[1], args[2]) end, "[step|debug]: what the minimap shows")

BINDING_HEADER_IMPROVEDFOREVER_MINIMAP = "Improved Forever: Minimap"
