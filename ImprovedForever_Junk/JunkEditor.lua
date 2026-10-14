-- The Junk tab, a tab of settings (IF.SettingsPage, SettingsPage.lua): what
-- is marked junk and where it shows (Junk.lua, the core's ItemValue.lua),
-- and the Destroy panel: on / off, the press that opens it (Destroy.lua).
local IF = ImprovedForever

local J = IF.Junk
local IV = IF.ItemValue
local DS = IF.Destroy
local B = IF.Binds
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local function S()
    return J.Settings()
end

local ITEMS = {
    Item({
        key = "auto", group = "junk", label = "Find junk",
        tip = "Marks junk by itself: greys; white gear (green once soulbound) you can't use, of a lighter armor"
            .. " than you wear, too low level or worth next to nothing; recipes you already know. Never an item"
            .. " for a quest in your log or one you can still do (not done yet, for your race and class), one"
            .. " that starts a quest, an upgrade, a reagent, recipe or tool of your professions or class,"
            .. " nor what sells for more at the auction house (with Auction's prices). Off: greys and your own"
            .. " marks only.",
    }, OnOff(function() return S().auto end, function(on)
        S().auto = on
        IV.Changed()
    end, "Find junk")),
    Item({
        key = "icons", group = "junk", label = "Bag coins",
        tip = "The game's junk coin on every junk item in the bags.",
    }, OnOff(function() return S().icons end, function(on)
        S().icons = on
        J.RefreshBags()
    end, "Bag coins")),
    Item({
        key = "tooltip", group = "junk", label = "Tooltips",
        tip = "An ordinary item a quest needs (meat, cloth...) says so in its tooltip, in orange: the quest in"
            .. " your log, or one you can still do. Not the game's own quest items (they say so already), nor"
            .. " what a vendor sells.",
    }, OnOff(function() return S().tooltip end, function(on) S().tooltip = on end, "Tooltips")),
    Item({
        key = "sell", group = "junk", label = "Sell All Junk",
        tip = "A vendor's Sell All Junk sells the junk found here too, after the game's greys (a bag kept out"
            .. " of Sell All Junk in its settings is left alone). Its button lights up while there is only"
            .. " this junk to sell.",
    }, OnOff(function() return S().sell end, function(on) S().sell = on end, "Sell All Junk")),
    {
        key = "markKey", group = "junk", label = "Mark junk",
        tip = "The press that marks the bag item the cursor is on as junk, or no longer junk. Remembered for"
            .. " this character, by item: a mistaken verdict stays corrected. An item a quest needs (in your"
            .. " log or still to do) can't be marked junk. Watched, not taken: the button"
            .. " keeps its own action. In the Destroy panel, R1 does the same.",
        -- (the mouse's way, while it's the one in hand)
        note = function()
            if IF.Input.Pad() then return nil end
            local key = IF.Binds.KeyBind(IF.Binds.Get("junkmark"))
            return "With the mouse: " .. (key and (IF.Binds.KeyText(key) .. " a bag item") or "no click or key yet")
                .. "; right-click to record another (a key acts on the bag item under the mouse). In the Destroy"
                .. " panel, right-click a card."
        end,
        bindable = true, chord = true, bindId = "junkmark",
        binding = function() return S().mark and J.MarkKey() or nil end,
        keyText = function(size) return J.MarkKeyText(size) end,
    },
    Item({
        key = "forget", group = "junk", label = "Your marks",
        tip = "Forgets every junk / not junk mark of this character: the verdict decides again.",
        note = function()
            local n = IV.MarkCount()
            return n == 0 and "None yet" or (n .. (n == 1 and " item marked" or " items marked"))
        end,
        disabled = function() return IV.MarkCount() == 0 end,
    }, {
        button = "Forget",
        run = function() IV.ClearMarks() end,
        confirm = true, confirmText = "Forget every mark?",
    }),

    Item({
        key = "enabled", group = "destroy", label = "Destroy panel",
        tip = "The panel of the junk, safe to throw away, opened while a bag is open. With the bags full, the top"
            .. " face button (Triangle / Y) opens it from the loot window too: there each destroy loots the item"
            .. " that didn't fit in the junk's place. At a vendor it sells.",
    }, OnOff(function() return DS.Enabled() end, function(on)
        -- (its own press back, without taking it from anything)
        B.Get("destroy").set(on and DS.OpenKey() or nil)
    end, "Destroy panel")),
    {
        key = "key", group = "destroy", label = "Opens with",
        tip = "The press that opens the panel while a bag is open: one button, or hold one and press another."
            .. " Watched, not taken: the button keeps its own action outside the bags.",
        note = function()
            if IF.Input.Pad() then return nil end
            local key = IF.Binds.KeyBind(IF.Binds.Get("destroy"))
            return "With the mouse: " .. (key and IF.Binds.KeyText(key) or "a key (right-click to record one)")
                .. ", or /if destroy. With the bags full, the loot window shows a Destroy button."
        end,
        bindable = true, chord = true, bindId = "destroy",
        binding = function() return DS.OpenKey() end,
        keyText = function(size) return DS.OpenKeyText(size) end,
        disabled = function() return not DS.Enabled() end,
    },
}

local GROUPS = {
    { key = "junk", label = "Junk" },
    { key = "destroy", label = "Destroy" },
}

IF.JunkEditor = IF.SettingsPage({ key = "junk", label = "Junk", module = "junk", order = 55 }, GROUPS, ITEMS)
