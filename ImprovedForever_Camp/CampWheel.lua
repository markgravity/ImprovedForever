-- The Camping wheel, a built-in one of the Wheel module (when it's here):
-- Forever's campfire kits, Camp Tent and Camp Chair, and the other placeable
-- camp gear (Fish Bowl, Fishing Rack and Hut...), each with the recipe that
-- makes it (the spell's ID, RecipeData.lua: a cook's kits, a blacksmith's
-- tent, a skinner's chair). One in the bags is used (a secure item slot);
-- with none, a slot of a recipe known does nothing on R2, is shown grey and
-- is there for Square, which shows the recipe to craft (the Wheel's
-- entry.craft, and its reagents under the name: entry.reagents).
local IF = ImprovedForever

BINDING_HEADER_IMPROVEDFOREVER_CAMP = "Improved Forever: Camp"

if not IF.AddBuiltInWheel then return end

local CAMPING = {
    { item = 279981, spell = 1229737 }, -- Basic Campfire Kit (Cooking)
    { item = 279961, spell = 1283400 }, -- Journeyman Campfire Kit (Cooking, Blueprint: Journeyman Campfire)
    { item = 279974, spell = 1291341 }, -- Expert Campfire Kit (Cooking, Blueprint: Expert Campfire)
    { item = 279978, spell = 1229432 }, -- Camp Tent (Blacksmithing)
    { item = 279979, spell = 1229517 }, -- Camp Chair (Skinning)
    { item = 279967, spell = 1229745 }, -- Fish Bowl (Fishing)
    { item = 279965, spell = 1262990 }, -- Fishing Rack (Fishing, Blueprint)
    { item = 279966, spell = 1262998 }, -- Fishing Hut (Fishing, Blueprint)
    { item = 279962, spell = 1229705 }, -- Incense Candle (Herbalism)
    { item = 279968, spell = 1230117 }, -- First Aid Kit (First Aid)
    { item = 279957, spell = 1262978 }, -- Cookie's Feast (Cooking, Blueprint)
}

local function ItemInstant(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInfo then
        local _, _, _, _, icon = getInfo(itemID)
        return icon
    end
end

local function ItemName(itemID)
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    return getName and getName(itemID) or ("item:" .. itemID)
end

local function ItemCount(itemID)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(itemID) or 0
end

-- Shows a recipe by its spell ID in the game's profession window (the game
-- loads and opens it: never from here, a Blizzard window loaded by addon
-- code is tainted); its own Create button crafts. A press: a hardware event.
-- (the Wheel calls it: IF.CraftRecipe)
function IF.CraftRecipe(spellID)
    local ui = C_TradeSkillUI
    if not (ui and ui.OpenRecipe) then
        IF.Print("Can't open recipes here.")
        return
    end
    local ok = pcall(ui.OpenRecipe, spellID)
    if not ok then IF.Print("Couldn't open that recipe.") end
end

-- A recipe's reagents from the bundled index (RecipeData.lua): { {itemID,
-- count}... }, and its profession's name
local function RecipeReagents(spellID)
    local data = IF.RecipeData
    local row = data and data.recipes[spellID]
    if not row then return nil end
    local list = {}
    for i = 5, #row, 2 do list[#list + 1] = { row[i], row[i + 1] } end
    return list, data.skills[row[1]]
end

local function BuildCamping()
    local known = IsPlayerSpell or IsSpellKnown
    local entries = {}
    for _, camp in ipairs(CAMPING) do
        local count = ItemCount(camp.item)
        local craft = known and known(camp.spell) and camp.spell or nil
        if count > 0 or craft then
            local reagents, profession
            if craft then reagents, profession = RecipeReagents(camp.spell) end
            entries[#entries + 1] = {
                label = ItemName(camp.item), icon = ItemInstant(camp.item), count = count, craft = craft,
                reagents = reagents, profession = profession,
                -- (none in the bags: nothing to use, only to make; shown grey)
                type = count > 0 and "item" or "macro", value = count > 0 and ("item:" .. camp.item) or "",
                action = "item:" .. camp.item, tip = "item:" .. camp.item,
                missing = count == 0,
            }
        end
    end
    entries.empty = "No camping gear yet: learn a campfire recipe, or find a kit"
    return entries
end

IF.AddBuiltInWheel({
    key = "camping", label = "Camping", build = BuildCamping,
    info = "Fills itself with the camping gear: the campfire kits, Camp Tent, Camp Chair, Fish Bowl, Fishing Rack"
        .. " and Hut, Incense Candle, First Aid Kit and Cookie's Feast in your bags, and any you know how to"
        .. " make. R2 uses one; Square shows its recipe to craft (out of combat). Nothing to set here but its hotkey.",
})
