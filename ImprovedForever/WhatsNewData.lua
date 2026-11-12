-- The changes of the what's-new list (WhatsNew.lua), per module and version:
-- a module updated since the player last saw it lists the changes of every
-- version after theirs, the newest first. Add a version here when a release
-- has something a player should be shown (not fixes). A change: its name
-- (lit in the list), an icon (kept for later), and two lines of words.
local IF = ImprovedForever
local WN = IF.WhatsNew
local ICON = "Interface\\Icons\\"

WN.Add("Core", "0.17.0", {
    pages = {
        {
            name = "Reset icons", icon = ICON .. "INV_Misc_Gear_01",
            lines = { "Every slider with a default has a reset icon right of its title (X on the pad).",
                "A reset-all icon sits at the right end of a section's title." },
        },
        {
            name = "More tabs", icon = ICON .. "INV_Misc_Map_01",
            lines = { "The side tabs' \"more tabs\" marker is a gold arrow bobbing toward them.",
                "A click or the wheel scrolls; the tooltip has the number." },
        },
    },
})

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

WN.Add("Immersion", "0.10.0", {
    pages = {
        {
            name = "Raid markers", icon = ICON .. "Ability_Hunter_SniperShot",
            lines = { "Skull, cross, moon... on the nameplates and the target header,",
                "in the quest arrow's look." },
        },
        {
            name = "Combo points", icon = ICON .. "Ability_Rogue_Eviscerate",
            lines = { "Small cut gems in a V over the target diamond and its nameplate name.",
                "They pop in when gained and flare outward when spent." },
        },
        {
            name = "Last names", icon = ICON .. "Achievement_Character_Human_Male",
            lines = { "A player's last name after the first on the player card, party cards,",
                "target header and nameplates (off by default)." },
        },
        {
            name = "Screen width", icon = ICON .. "INV_Misc_Gear_01",
            lines = { "Keeps the player frame, chat, buffs and action bar inside 16:9 or 21:9",
                "on an ultrawide screen." },
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
            name = "Sidebar", icon = ICON .. "INV_Misc_Note_01",
            lines = { "The cards at the top left (quests, the world tooltip, buff notices) are the sidebar.",
                "Move it down and resize it in the Body tab: Sidebar top padding and size." },
        },
        {
            name = "Spell tracker", icon = ICON .. "Spell_Holy_HolyBolt",
            lines = { "Pick a mode for each spell you track: told when it is ready again,",
                "or a card with its time running down from the cast until it is." },
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

WN.Add("Wheel", "0.13.0", {
    pages = {
        {
            name = "Use on release", icon = ICON .. "Ability_Hunter_MarkedForDeath",
            lines = { "Aim with the right stick and let go of it to use the slot, as the game's own wheel does.",
                "R2 then closes the wheel without using anything (off by default)." },
        },
    },
})

WN.Add("Auction", "0.9.0", {
    pages = {
        {
            name = "Auction window", icon = ICON .. "INV_Misc_Coin_01",
            lines = { "The auction window is the framed window with its side tabs for everyone:",
                "Buy, Sell, Auctions and Tasks. The auction house scene is gone." },
        },
    },
})

WN.Add("Wiki", "0.9.0", {
    pages = {
        {
            name = "Hold to open", icon = ICON .. "INV_Misc_Book_09",
            lines = { "Hold the middle mouse button on an item (bags, loot, a chat link...) to open its page,",
                "a ring filling as you hold. A short click stays the game's." },
        },
    },
})

WN.Add("Junk", "0.8.0", {
    pages = {
        {
            name = "Sell All Junk", icon = ICON .. "INV_Misc_Bag_08",
            lines = { "A binding (Bindings tab, Bags): at a vendor one press sells all the junk, the greys too.",
                "Unbound until you set one." },
        },
    },
})

WN.Add("Fishing", "0.1.0", {
    pages = {
        {
            name = "Fishing", icon = ICON .. "Trade_Fishing",
            lines = { "With a pole in hand, tap R2 twice to start; R2 casts, R2 twice puts your best lure on.",
                "Each cast is a scene: the HUD steps back and the camera comes over your shoulder." },
        },
        {
            name = "Fish Collection", icon = ICON .. "INV_Misc_Fish_02",
            lines = { "Every fish and item you've caught, when and where first, with a filter.",
                "D-pad up, a key, or the Improved Forever wheel; Cross opens its Wiki page." },
        },
    },
})

WN.Add("Fishing", "0.2.0", {
    pages = {
        {
            name = "Fish with the mouse", icon = ICON .. "INV_Fishingpole_01",
            lines = { "Tap to cast, double-tap to use a lure." },
        },
    },
})

WN.Add("Camp", "0.1.0", {
    pages = {
        {
            name = "Camp scene", icon = ICON .. "Spell_Fire_Fire",
            lines = { "Sitting by a campfire is a cutscene: the HUD steps away and the camera cuts between shots.",
                "Your day is told back from the Journal, and what's said near you shows as subtitles." },
        },
        {
            name = "Logging out", icon = ICON .. "INV_Misc_Note_01",
            lines = { "Logging out is a scene of its own, with a countdown, a recap",
                "and a button to cancel." },
        },
    },
})

WN.Add("Minimap", "0.7.0", {
    pages = {
        {
            name = "Minimap labels", icon = ICON .. "INV_Misc_Map_01",
            lines = { "Quest and objective labels in the minimap's own style, fixed to the map and kept apart.",
                "Forever's herb variants and quest objects are named. Gather is now Minimap." },
        },
    },
})

WN.Add("Map", "0.7.0", {
    pages = {
        {
            name = "Peek map", icon = ICON .. "INV_Misc_Map_02",
            lines = { "The peek map can be moved and zoomed while held,",
                "and shows quest names." },
        },
    },
})

WN.Add("QuestTracker", "0.6.4", {
    pages = {
        {
            name = "Quest cycle", icon = ICON .. "INV_Misc_Map_01",
            lines = { "The quest cycle goes by distance and angle,",
                "so the next quest is the one in front of you." },
        },
    },
})

WN.Add("Vibration", "0.6.3", {
    pages = {
        {
            name = "Seals", icon = ICON .. "Spell_Holy_SealOfMight",
            lines = { "Forever's own seals vibrate like the others:",
                "Fury, Might, Protection, Reckoning, Sacrifice and Martyrdom." },
        },
    },
})
