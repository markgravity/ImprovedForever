-- Improved Forever: Wheel. Which ring each R3 combo opens ("native" leaves
-- the game's own R3 action); the rings themselves are RingContent.lua's and
-- MyWheels.lua's, drawn by Ring.lua.
local IF = ImprovedForever

IF.AddModule({ key = "wheel", label = "Wheels", icon = IF.TEX .. "ic_mod_wheel", addon = ... })

IF.RINGS = { "native", "quest", "consumables", "emotes", "group" }
IF.RING_LABELS = { native = "Native (Look Here)", quest = "Quest Items", consumables = "Consumables", emotes = "Emotes", group = "Group" }

local DEFAULT_COMBOS = { R3 = "native", L1 = "quest", L2 = "emotes", R1 = "consumables", R2 = "native" }

local function Combos()
    local db = IF.db
    if not db.combos then
        db.combos = {}
        for combo, ring in pairs(DEFAULT_COMBOS) do db.combos[combo] = ring end
    end
    return db.combos
end

-- (a hidden wheel's combo stays kept, but does the game's own R3 until
-- the wheel is shown again: MyWheels.lua)
function IF.GetComboRing(combo)
    local ring = Combos()[combo] or "native"
    if IF.RingHidden and IF.RingHidden(ring) then return "native" end
    return ring
end

function IF.SetComboRing(combo, ring)
    Combos()[combo] = ring
    if IF.ApplyRingBindings then
        IF.ApplyRingBindings()
    end
end

-- /if ring <combo> <ring>  e.g. /if ring L1 quest
IF.AddCommand("ring", function(args)
    local combo, ring = args[1] and args[1]:upper(), args[2]
    if not IF.COMBO_LABELS[combo or ""] or not IF.RING_LABELS[ring or ""] then
        IF.Print("usage: /if ring <" .. table.concat(IF.COMBOS, "|") .. "> <" .. table.concat(IF.RINGS, "|") .. ">")
        return
    end
    IF.SetComboRing(combo, ring)
    IF.Print(IF.COMBO_LABELS[combo] .. " -> " .. IF.RING_LABELS[ring])
end, "<combo> <ring>: what an R3 combo opens")


BINDING_HEADER_IMPROVEDFOREVER_WHEEL = "Improved Forever: Wheel"
