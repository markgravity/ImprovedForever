# Features (shipped, per README.md / CHANGELOG.md / dist/curseforge/*.md)

- **Core**: button glyphs, configuration panel (double-tap Menu or `/if`), Bindings tab (controller press and keyboard/mouse press per binding), bag clean-up, touchpad corner actions (incl. double-tap; on SteamOS with a PlayStation controller, turn Steam Input off for the game and restart it), shared item verdict, bundled game data, a General switch that leaves the controller's buttons to the game.
- **Wheel**: radial wheels on R3 combos (defaults: L1 Quest Items, L2 Emotes, R1 Consumables); built-in wheels Quest Items (items a quest has you use or that start one), Consumables (food, drink, potions, bandages, scrolls, elixirs, flasks), Emotes, Group (pick a party or raid member, then cast a helpful spell on them, usable in combat), Improved Forever (our windows) and Camping (with the Camp module); custom wheels (spells, items, macros, emotes, chat phrases, totems, trinket swap); recent action slot. Source: ImprovedForever_Wheel code (Wheel.lua, MyWheels.lua).
- **Vibration**: vibration on game events and spell casts, per-action patterns.
- **Minimap**: names beside minimap dots (herbs, ore, quests, NPCs, party), gathering alerts. Paused since WoW Forever's November 2026 update stopped addons reading the minimap (0.7.1 says so in game); back by itself once the game answers again.
- **Map**: peek map.
- **Chat**: pick a chat line and the links in it with the pad; Cross opens an item in the Wiki.
- **Auction**: controller auction window, Buy/Sell/Owned pages, prices over time, tasks.
- **Junk**: marks junk (quests, recipes, auction prices, class, soulbound), L2+L3 to mark, vendor Sell All Junk, Destroy panel, loot-window destroy when bags are full.
- **Wiki**: hold R3 on an item (or the middle mouse button) for drops, vendors, recipes, quests, auction prices; search any item by name; fishing waters. Data from QuestieDB.
- **Journal**: first-person diary of each day, per character, read as a leather book.
- **Fishing**: fishing mode (R2 twice or double right-click), per-cast scene, stringer, Fish Collection with first-catch cinematic, camera framing; mouse fishing.
- **Camp**: sitting by a campfire as a cutscene.
- **Immersion**: HUD rework: target header, player ring (movable and resizable), header (movable), spell-diamond gamepad bar, party/pet cards, nameplates (name font and size), debuffs and cast bars under nameplates, recent loot tiles, NPC subtitles (stay off when DialogueUI is installed), first-time tour (`/if tour`). Needs Journal and Spoken.
- **QuestTracker**: rebuilt objective tracker with sorting (zone, level, title, distance, completed), completion sound, full pad support.
- Square shoots your wand (Core 0.11.0; off by default since Core 0.12.1, a General switch).
