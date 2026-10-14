-- Improved Forever: Wiki. Everything about an item (Wiki.lua,
-- WikiPage.lua): what drops it, who sells it, the recipes that make or
-- use it, its quests and auction prices; set up in its tab (WikiEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "wiki", label = "Wiki", icon = IF.TEX .. "ic_mod_wiki", addon = ... })

-- /if wiki <item id or link>: an item's Wiki page
IF.AddCommand("wiki", function(args, msg)
    local id = tonumber(args[1]) or tonumber((msg or ""):match("item:(%d+)"))
    if id then IF.Wiki.Open(id) else IF.Print("/if wiki <item id or link>") end
end, "<item id or link>: an item's page")
