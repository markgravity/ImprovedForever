-- The pages of the what's-new tours (WhatsNew.lua), per module and version:
-- a module updated since the player last saw it plays the pages of every
-- version after theirs, the newest first. Add a version here when a release
-- has something a player should be shown (not fixes). A page: its name
-- (the list), an icon, two lines, and optionally an example key a module
-- gave with IF.WhatsNew.Example.
local IF = ImprovedForever
local WN = IF.WhatsNew
local ICON = "Interface\\Icons\\"

WN.Add("Core", "0.18.0", {
    pages = {
        {
            name = "Settings menu", icon = ICON .. "INV_Misc_Gear_01",
            lines = { "The settings are a tree of categories now, with sections inside them.",
                "Filter by section; a setting you change peeks its effect on screen." },
        },
        {
            name = "Bind editor", icon = ICON .. "INV_Misc_Book_09",
            lines = { "Action cards show the rank of the spell you bound.",
                "Pick another rank with the mouse wheel or the stick." },
        },
    },
})

WN.Add("Immersion", "0.11.0", {
    pages = {
        {
            name = "Quest cards", icon = ICON .. "INV_Misc_Map_01",
            lines = { "Your quests are cards at the top left of the screen, several at a time.",
                "Swipe to open the focused quest; L1 + R1 + D-pad Up on the pad." },
        },
        {
            name = "Cooldowns", icon = ICON .. "Spell_Fire_FlameBolt",
            lines = { "Cooldowns in the buff timeline are round tiles with rings, like the gamepad bar's.",
                "Each tile peeks the cooldowns of the same slot in your other bar sets." },
        },
        {
            name = "World tooltip", icon = ICON .. "INV_Misc_Note_01",
            lines = { "What you look at and the buff or debuff notices are one cinematic card.",
                "The game's pad buff tooltip is hidden." },
        },
        {
            name = "Nameplates", icon = ICON .. "Ability_Hunter_SniperShot",
            lines = { "Nameplates of what you don't target are muted,",
                "so your target stands out." },
        },
        {
            name = "Bottom lines", icon = ICON .. "Spell_Holy_HolyBolt",
            lines = { "Health and power are one bar each, left to right, framed and notched",
                "in the look of the fishing skill line." },
        },
    },
})
