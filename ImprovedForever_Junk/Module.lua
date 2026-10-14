-- Improved Forever: Junk. What the bags no longer need, by the core's
-- verdict (ImprovedForever's ItemValue.lua: quests, recipes, auction
-- prices, the class) and the player's own marks: marked on the bag slots,
-- sold with the vendor's Sell All Junk (Junk.lua); thrown away from the
-- controller, from the bags or the loot window (Destroy.lua).
local IF = ImprovedForever

IF.AddModule({ key = "junk", label = "Junk", icon = IF.TEX .. "ic_mod_junk", addon = ... })

BINDING_HEADER_IMPROVEDFOREVER_JUNK = "Improved Forever: Junk"
