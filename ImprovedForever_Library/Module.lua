-- Improved Forever: Library. Everything about an item (Library.lua,
-- LibraryPage.lua): what drops it, who sells it, the recipes that make or
-- use it, its quests and auction prices; set up in its tab (LibraryEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "library", label = "Library", icon = IF.TEX .. "ic_mod_library", addon = ... })

-- /if library <item id or link>: an item's Library page
IF.AddCommand("library", function(args, msg)
    local id = tonumber(args[1]) or tonumber((msg or ""):match("item:(%d+)"))
    if id then IF.Library.Open(id) else IF.Print("/if library <item id or link>") end
end, "<item id or link>: an item's page")
