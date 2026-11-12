# Changelog

## Immersion 0.12.0

- With "Square shoots the wand" on, Square's tile shows Shoot's icon while an enemy is targeted, and blinks while the wand fires.
- The gathering cast bar shows your profession skill.
- Your health and power lines: set their height, and they glow in combat.
- Cards show the pad's button glyphs.
- The spell tracker follows buffs from weapon enchants too.
- Cards lay themselves out again after login or a cinematic.
- An action's range is read correctly with the pad.
- Settings: Immersion's Quests and Global Tooltips are titles inside Body > Sidebar; the quest cards toggle is renamed.

## Auction 0.10.0

- Buy tab: a scan progress bar, and Y starts or stops the scan.
- Buy tab: sort by required level, and each row shows the level it requires instead of the item level.

## Core 0.18.1

- Fixed: the wand's Shoot button no longer fires at a mob that is only soft-targeted (the pad's hover) while you loot next to it, which pulled it. It needs a target you have actually selected.
- The bind editor locks the game's own binds, picks a spell's rank with the stick, and shows the recorder's hint inline.
- Settings: a section "Parent/Child" lists only its parent; Immersion's Quests and Global Tooltips sit inside Body > Sidebar.

## Core 0.18.0

- **What's new**: after an update, a list of what changed in each Improved Forever module you have, a card per module with its changes, at the top left. Someone who has never seen it gets every change there is. B or Esc closes it; the General tab's "What's new" button (under Updates) shows it again.
- The settings are a tree of categories with sections inside them, and can be filtered by section. A setting with something to see peeks its effect on screen as you change it.
- The bind editor shows the rank of the spell you bound on its action cards, with a rank picker (mouse wheel or the stick).

## Immersion 0.11.0

- **Quest cards**: your quests are cards at the screen's top left, the focused one first and the others together under it; swipe to open the focused quest in full, or L1 + R1 + D-pad Up on the pad. The old tracker is out of sight while they show.
- **Sidebar** (the cards at the top left: quests, the world tooltip, buff notices): move it down and resize it in the Body tab.
- **Cooldowns** in the buff timeline are round tiles with rings, like the gamepad bar's. Each tile of the gamepad bar peeks the cooldowns of the same slot in your other bar sets, and an action out of range greys out.
- The world tooltip and the buff and debuff notices are one cinematic card; the game's pad buff tooltip is hidden. Cards go away while a window is open.
- **Spell tracker**: a mode for each spell (told when it is ready again, or a card counting down until it is) instead of one switch.
- Nameplates of what you don't target are muted, so your target stands out.
- Your health and power lines along the bottom edge are in the fishing skill line's look: a thin frame, twenty compartments, a graded fill with a soft glow at its end, and the two lines touch.

## Auction 0.9.1

- Fixed: after a buy, looking the item up again no longer gets lost when the client's own list refresh comes first.

## QuestTracker 0.6.6

- The tracker's pad cursor and sort prompt stay away while Immersion's quest cards are the tracker.

## Core 0.17.0

- Every slider with a default has a reset icon (a circular arrow) right of its title; X on the pad. A reset-all icon sits at the right end of a section's title.
- The side tabs' "more tabs" marker is a gold arrow bobbing gently toward them. A click or the wheel scrolls; the tooltip has the number.
- The config window uses the game's font on Russian, Korean and Chinese clients.

## Immersion 0.10.0

- **Raid markers** (skull, cross, moon...) on the nameplates and the target header, in the quest arrow's look.
- **Combo points** as small cut gems in a V over the target diamond and the target's nameplate name; they pop in when gained and flare outward when spent.
- **Last names** setting: a player's last name after the first on the player card, party cards, target header and nameplates (off by default).
- **Screen width** setting keeps the player frame, chat, buffs and action bar inside 16:9 or 21:9 on an ultrawide screen.
- Sliders to move and resize the action bar, move the party cards and resize the header; a setting for D-pad tiles as big as the face buttons'. "Reset every place and size" button in the tab.
- The Action bar style setting is back (Diamonds by default, or Squares / Circles).
- The player card's name is centred, and a full name fits.
- On a short buff row the buffs no longer get only two icons.
- Fixed: secret-number errors in combat.
- Fixed: the NPC dialog camera follows the stick the way the game's camera does.

## Wheel 0.13.0

- **"Use on release"** setting: aim with the right stick and let go of it to use the slot, as the game's own wheel does. R2 then closes the wheel without using anything (off by default).
- A reset button on the Wheel size slider.

## Camp 0.1.3

- The camera ends level after a scene, back to its first view; the shots' pitch goes the right way, and the game's experimental camera warning is hidden while the scene runs.
- The scene fades the game's own HUD (player frame, action bar, buffs, chat, minimap...) when Immersion isn't there to hide it.
- The subtitles use the game's font on Russian, Korean and Chinese clients.

## Core 0.16.0

- The Wiki with the mouse, like the spellbook: a search box and a filter button at the top right. Typing searches as you go; emptying the box goes back to the page you were on. No more Search, Filters or Close buttons along the bottom (the window's close button and Escape close it).
- Clicking an entry in a Wiki list with the mouse works again.

## Wiki 0.9.0

- **Hold the middle mouse button on an item** (bags, loot window, a chat link...) to open its page, with a ring filling as you hold; a short click stays the game's. On by default: "Hold middle mouse button" in the Wiki tab.
- Fixed: Wiki pages opening empty.

## Auction 0.9.0

- The auction house scene is gone: the auction window is the framed window with its side tabs (Buy, Sell, Auctions, Tasks) for everyone.

## Immersion 0.9.1

- The "Auction house scene" switch is gone with the scene (Auction 0.9.0).

## Minimap 0.7.1

- WoW Forever's latest update stopped addons from reading the minimap, so the labels and alerts can't work for now. Instead of silently doing nothing, they say so in the chat and the Minimap tab, and come back by themselves once the game answers again.

## Core 0.15.0

- Escape (and the pad's B) no longer gets blocked by Improved Forever: our windows close on Escape their own way, without tainting the game's.

## Immersion 0.9.0

- **Cast bars under the nameplates**: what a mob or player casts as a thin bar under its health line, with the spell's name and its icon in a round badge (the level circle's twin). Gold for a cast, green draining for a channel, grey when it can't be interrupted, red when it is. Setting: "Nameplate cast bars" (on). `/if platecast` shows a made-up cast on the plates in sight.
- The gamepad bar shows a spell's cooldown in a fight too (timed from your own cast), and a tile pulses while its spell is being cast, as a cooldown does.
- The recent loot's item count sits where the bags' free slots count does.
- Fixed: looting and the B button got "blocked" (SetPreferredGamepadInteractTarget, ClearTarget) after targeting a mob that was casting.
- Fixed: the game's own cast bar flashing up when your cast was interrupted.

## Auction 0.8.1

- Escape closes the Tasks, vendor Tasks, crafting and confirmation windows without tainting the game's Escape.

## Junk 0.8.1

- The loot window's Destroy prompt and button no longer resize the game's loot window (a possible "blocked" error on closing it).

## Map 0.7.2

- The peek map hides Spoken's Place Story panel again (Spoken renamed it).

## QuestTracker 0.6.5

- Escape closes the tracker's menu without tainting the game's Escape.

## Wheel 0.12.1

- The unit frame scan no longer tests a hidden (secret) visibility, which could taint the game in a fight.

## Core 0.14.2

- A striped texture for the predictions on Immersion's health and power lines.

## Immersion 0.8.0

- **Nameplates over friendly NPCs**, in the same look as the others: the name in gold, the NPC's job under it (`<Warrior Trainer>`; a player's guild), and the game's own tiny names over units too far for a plate turned off, so the two looks no longer mix. Settings: "Friendly NPC nameplates" and "Hide the game's far names" (both on).
- **Health line off for friendly NPCs** (on): the name alone, with the level circle gone too. Mobs you can attack keep theirs. Players have their own switch (off).
- **Player names and health lines in their class colour**, with a switch to turn it off; a friend's level circle is plain gold, no longer coloured by difficulty.
- A nameplate fades out behind an object, and one far away stays ours, a little smaller. Plates sit closer to the head, the name is a size 17, with more room over the health line.
- **Recent loot is on by default** and no longer called an experiment; an item a quest in your log asks for gets a gold "?" tile.
- Your health and power lines along the bottom edge: the heals coming and the power a spell will take show as striped bands, what you just lost stays as a pale trail, a bright cap marks where each stops.
- The target's buffs no longer stop with "attempt to compare a secret number value".

## Immersion 0.7.0

- **Drop a spell, item or macro on a keyboard bar tile** to put it on that key; drag it off to free the key (what was there comes up on the cursor). The tile shows the action's tooltip, its cast ring, cooldown and item buff. Over the bar the layer stays the plain one: Shift is the game's pick-up key, not a layer.

## Core 0.14.1

- Spells, items and macros can be put on and picked up from keys by other modules (used by Immersion's keyboard bar).

## Core 0.14.0

- **Keyboard drawing in the Bindings tab** (with Immersion): with the mouse and keyboard in hand (or the Gamepad UI off), twelve keys (1 2 3 4, Z X C V, Q E R F) are drawn in three crosses beside the list. A click on a key binds the card picked there, a right-click clears it; Alt, Ctrl and Shift show their layer.

## Camp 0.1.2

- **Exit** no longer triggers the "ForceQuit" blocked-action error: it clicks the game's quit button through a secure button.

## Immersion 0.6.0

- The keyboard and mouse bar's twelve tiles say their own key and show what it runs, for the layer of the Alt / Ctrl / Shift you hold.

- A click on the free bag slots' tile opens the bags, and the menu's "Bag Slots" entry is called "Bags".
- The target's cast runs round its avatar diamond: the spell's icon inside it, its edges lit as the cast goes (yellow cast, green channel, grey when it can't be interrupted, red when cut); the long bar under the name is gone, the spell's name stands over the diamond and the target's buffs sit close under its race and class line. `/if targetcast` tries it on your target.
- Your own cast bar's icon is always the diamond, whatever the action bar's style. `/if casttest` shows it with a made-up cast.
- `/if bufftest` shows made-up buffs and debuffs in the buff row (60 seconds, with tooltips), to try its look without a real aura on you, and says in the chat what the row's real buttons hold.
- The target's buffs and debuffs under the header are cleared and filled again when you change target (they kept the earlier target's icons).
- The menu button's list greys out the entries you can't use yet (Talents before their level, a guild you aren't in...), and has an "Improved Forever" entry that opens this panel.
- The buff row along the bottom (and the target's buffs under its header) show the game's own tooltip for an aura when the mouse is over it, above the icon (out of a fight).
- With the keyboard and mouse bar, the menu button's list works: clicking an entry (Character, Spellbook, Talents, Bags...) now opens it; the click was ignored while the game's "Action buttons use key down" was on. The tiles' mouse clicks too.
- The cast bar can be moved right / up in the Immersion tab (under Cast bar), as the header and the player frame can.

## Camp 0.1.1

- **Text speed** setting (Slow, Normal, Fast) for the scene's lines: how fast the words come and how long each line stays.

## Camp 0.1.0

- Sitting by a campfire is a cutscene: the HUD steps away, black bars come in and the camera cuts between shots round you.
- Your day is told back from the Journal, and the camp's benefits show up when they come.
- What's said near you appears as subtitles.
- Logging out is a scene of its own, with a countdown, a recap and a button to cancel.

## Vibration 0.6.3

- Forever's own seals vibrate like the others: Seal of Fury, Might, Protection, Reckoning, Sacrifice and Martyrdom (only the Classic ones did).

## Core 0.13.0

- **Square shoots the wand** is off until you turn it on (General tab, or `/if wandshoot`). It was on for everyone with a wand and took Square from players who never asked for it (the melee swing or the loot press became a wand shot).
- **Controller buttons** switch in the General tab: off, Improved Forever leaves the controller's buttons to the game (the wheels' R3 combos, the actions put on buttons, Square shooting the wand, the touchpad corners). The modules' windows and the mouse and keyboard presses work as before.
- The short messages in the options window ("Notification" line) sit on a dark plate under the buttons legend and are a bit bigger, so they are readable.

## Core 0.12.0

- **Double-tap the touchpad corners** to run a window action; the bind editor lists them and the layer text shows the pad's glyphs.
- The touchpad glyph keeps its proportions.

## Auction 0.8.0

- The Buy and Owned pages are redesigned as a scene: a grid of items on Buy, capsule status tags on Owned.
- Immersion has a toggle for the auction house scene; switch it off to get the classic window back.

## Immersion 0.5.0

- **Target buffs and debuffs**: your debuffs on the target and its buffs as small icons, centred under the target header's race and class line (a switch in the Immersion tab), read by the game's own aura list so they show in a fight too.
- The NPC subtitle can be moved right / up in the Immersion tab (under NPC dialog), if the player frame or the lines cover its words.
- Each piece of the bottom HUD has its own switch in the Immersion tab: the player card and ring, the health line, the power line and the action bar. Keep the action bar without the player frame and the lines, or the other way round.
- **Global cooldown** option (off by default): a swipe over the action bar's tiles while the global cooldown runs, so you see when the next spell can go.
- A face button (A, B, X, Y) that has an action of yours on it (the Bindings tab) shows that action's icon on the gamepad bar, not the game's slot under it, so the tile says what the press does.
- The gamepad bar stays on the screen: on a small window or a low UI scale its right side (the class action and the button glyphs) was cut off by the screen's edge; it now moves in until all of it shows.
- Names on a Russian, Korean or Chinese client show their letters (the header's, the target's and the nameplates') instead of empty squares: they use the game's own font there.
- Place the HUD yourself, in the Immersion tab: the player frame can move right / up and be resized (50 to 150%; the pet and party cards follow it), and the header (the target, quest arrow, zone names, banners) can move right / up. Each change applies at once, out of combat.
- The names over mobs have a font choice (Morpheus, Friz Quadrata, Arial Narrow, Skurri) and a size, in the Immersion tab under Nameplates.
- Works next to DialogueUI: with it installed, DialogueUI keeps the NPC talking and the NPC subtitles stay off, while the rest of Immersion runs as usual.

## Immersion 0.4.0

- A first-time tour in the middle of the screen, in the header's look: the pages' names on a gold rule, revealed one by one with a diamond showing the current page's picture, the page's example in the middle made of the real party cards, action bar tiles, recent loot tiles, cast line and header. A diamond button on the rule reveals the next page; Close under the words (B with the pad, Esc). `/if tour` plays it again.
- The Immersion settings call the spell diamonds the action bar: "Action bar style" (was "Tile style") and "Cooldowns beside the action bar".
- Nameplates are drawn in the Immersion look, with a toggle in the settings. The target's plate fades on the mob and rises toward the header.
- Your debuffs show under the nameplates, with a toggle.
- A breath bar on your player frame while you are underwater, in place of the XP ring.
- Recent loot tiles are marked with badges for upgrades, quest items, recipes, auction items, rarities and collectibles.
- The target's name always shows at its in-combat size.
- Recent loot waits for the end of combat to refresh.
- Double-tap the touchpad corners works on the recent loot tiles.

## Wheel 0.12.0

- The wheel's size is set in a "Settings" entry at the bottom of the Wheels list (D-pad left / right, or the - and + buttons with the mouse), not in a Wheel options tab of its own.
- The wheels' text (the radial menus, the editor) uses the game's own font on a Russian, Korean or Chinese client, so item and spell names show their letters instead of empty squares.

## Wheel 0.11.0

- **Wheel size** slider (50 to 150%) in a new Wheel options tab, for those who find the wheel too big. Changes out of combat.
- The wheels' R3 combos follow the core's new Controller buttons switch (off: R3 stays the game's).

## Wheel 0.10.0

- Recent loot tiles are marked with badges for upgrades, quest items, recipes, auction items, rarities and collectibles.

## Fishing 0.2.2

- The start / stop guide can be moved right and down in the Fishing tab: it no longer has to cover the game's controller targeting help at the top left.

## Fishing 0.2.1

- Double-tap the touchpad corners to act on the collection window.

## Junk 0.8.0

- A **Sell All Junk** binding (Bindings tab, Bags): at a vendor one press sells all the junk, the greys too, without going to the vendor's button. Unbound until you set one.

## Junk 0.7.3

- Double-tap the touchpad corners to act on the Junk and Destroy windows.

## Wiki 0.8.1

- Double-tap the touchpad corners to act on the Wiki window.

## Immersion 0.3.1

- Your player and pet models no longer stay on screen when another addon hides the interface during an NPC conversation (DialogueUI).

## Immersion 0.3.0

- The gamepad bar was reworked: it shows the mouse fishing actions and works with the mouse.
- The HUD layout has a separate version for the mouse and one for the pad, so switching between them keeps each one's placement.
- Your pet and your party cards have their own switches now.
- The bottom HUD elements sit in one group in the settings.

## Fishing 0.2.0

- Fish with the mouse: tap to cast, double-tap to use a lure.

## Core 0.11.0

- **Square shoots your wand**: with a wand equipped and an enemy targeted, Square shoots it instead of the
  melee swing. Looting, NPCs and objects stay the game's own press; L2 / R2 + Square run the matching
  crossbar button.
- A **General** tab first in the settings, holding the wand toggle.
- The side tabs fit the window's height: arrows with counts for the hidden ones, the wheel scrolls, the
  picked tab stays in view.

## Journal 0.1.0

- New module: **a diary of each day you play**, per character. The lands you passed through, the quests
  you finished, your fights and falls, what you looted, earned and made, written in the first person.
- Read it as a leather book: the days in a list on the left, the day you pick page by page on the right,
  with quest cards, place plates and cards for the foes you hunted. `/if journal`, a key binding, a button
  or a wheel slot opens it.
- Each hunt told as it went (how many it took to get the drop), and moments picked out as toasts and cards.
- With the Wiki, a quest, creature or item in the book opens its page.

## Immersion 0.2.0

- Needs the **Journal** module now.
- A power line under your health, and your experience as a ring round your player frame.
- Level ups, quest progress, the target, the way to your focused quest and zone names take turns in one
  header under the top of the screen.
- Recent loot as tiles (an experiment, off by default).
- The campfire scene left for its own Camp module.

## Fishing 0.1.1

- The fishing view follows Immersion's new header and unit frames.

## Wheel 0.9.1

- The Camping wheel moved to the Camp module.

## Map 0.7.1

- Spoken's place story panel hides while the map is peeked.

## QuestTracker 0.6.4

- The quest cycle goes by distance and angle, so the next quest is the one in front of you.

## Core 0.10.1

- New icon for the Immersion module (formerly Interface) in the AddOns list and the settings.

## Immersion 0.1.0

- New module (formerly Interface): **the HUD made for the controller and the scene**. Needs *Spoken*.
- The gamepad bar as spell diamonds laid out like your buttons, with cooldown rings and beats, cast progress
  round each diamond, and small diamonds for your bag slots, a hunter's ammo and a warlock's soul shards.
- Portrait cards for you, your pet and your party on the experience line; your health as a bar over it.
- The target's health and cast across the top; your cast as a long line over the cards, with a crosshair
  diamond that greys out of range; your buffs and cooldowns in rows along the bottom; the chat as just its lines.
- NPCs talk as subtitles, following Spoken's voice, answered from the controller; quest rewards as round
  icons with their comparison beside the panel, and Complete waits until one is picked.

## Fishing 0.1.0

- New module: **fishing from the controller**. With a pole in hand, tap R2 twice (or double right-click)
  to start fishing; R2 casts, R2 twice puts your best lure on; Circle or Esc stops. A guide line top left
  shows the buttons.
- Each cast is a scene of its own: the HUD steps back, the camera comes in over your shoulder, the bobber
  flies out on its line, the fish of that water swim round it, and a catch or a miss plays out on the bar.
- The session's catches hang on a rope stringer under the minimap; the chat sits beside it, faint until
  something new is said; your fishing skill runs along the bottom edge.
- **Fish Collection** (D-pad up, a key, or the Improved Forever wheel): every fish and item you've caught,
  when and where first, sorted by zone level, with a filter; Cross opens its Wiki page. A cinematic
  greets each fish caught for the first time.
- Triangle (or Alt + F) frames the fishing camera: distance, left / right and height.
- Catches are looted at once in fishing mode; the Wiki shows where each fish can be fished.

## Core 0.10.0

- What fishing needs: the fishing data (what each water holds, from Classic's loot and Forever's own
  items and zones), shared by the Fishing module and the Wiki.
- Our windows (Wiki, Fish Collection, Destroy) can go on a button, a touchpad corner or a wheel.
- Dropdown menus in the game's style, books with tabs, and side tabs with their L1 / R1 glyphs.
- Support for the Interface, Minimap (formerly Gather) and Party modules.

## Wiki 0.8.0

- **Search**: find any item of Forever by name, with filters.
- An item that can be fished shows its **fishing waters**: where, how likely, the pools.
- The Wiki opens on its search from the new Improved Forever wheel, a button or a corner.

## Wheel 0.9.0

- New built-in wheel, **Improved Forever**: fills itself with our windows you have (this settings
  panel, the Journal, the Wiki, the Fish Collection, the Destroy panel).
- Consumables show their stat values under each slot's icon.
- The recent action slot sits beside the gamepad diamonds of the Interface module.

## Junk 0.7.2

- The Destroy panel opens from a wheel's slot, a button or a touchpad corner too.

## Map 0.7.0

- The peek map can be moved and zoomed while held, and shows quest names.

## QuestTracker 0.6.3

- The quest focus stays where it was after the tracker reorders its quests.

## Minimap 0.7.0

- **Gather is now Minimap** (your settings come along; remove the old Gather folder if the app doesn't).
- Quest and objective labels in the minimap's own style, fixed to the map, kept apart from each other.
- Labels no longer overlap, whatever their kind; Forever's herb variants and quest objects are named.

## Core 0.9.0

- **Touchpad**: new default actions, and the ones that need a module wait until you're in the world.
- The Options page now shows how to open the panel.
- New glow textures for the Wheel's unit-frame highlight.

## Wheel 0.8.0

- **Group wheel**: pick a party or raid member with the stick, then cast a helpful spell on them. A
  breathing glow marks the member on their unit frame, shaped to your frame layout.
- Wheels can mix more kinds of slots, and the wheel editor was reworked.
- You can walk with the left stick while a wheel is open.

## Gather 0.6.3

- Node scanning is spread out over time, so the minimap scan no longer hiccups your FPS. Labels and
  alerts have their own timing.

## Junk 0.7.1

- Selling is now one path for Sell All Junk and the Destroy panel: each item is checked again just
  before it goes, only counted sold once it leaves your bags, and at most 12 a press so all of it can
  be bought back.

## Vibration 0.6.2

- Vibration reworked around the shared node scan: smoother, with fewer scan hiccups.

## QuestTracker 0.6.2

- Fixed: closing the tracker with the pad no longer gives a forbidden action error.
- The D-pad now goes down the tracker in your quest sort order.

## Core 0.8.1

- Fixed: the **Open** button in Options > AddOns > Improved Forever no longer gets a forbidden
  action error. It no longer closes Options itself: close Options and the controller panel opens.

## Core 0.8.0

- **Mouse and keyboard**: every window and action now also works with the mouse and keyboard
  (mouse + Esc). The look follows what you used last, pad or mouse.
- **Bag sorting**: sort your bags from a controller press or a key binding.
- **New icons**: the addon and every module have a new icon, in the game's own style.
- The Library became the **Wiki**: your settings and key binding move over by themselves.

## Wiki 0.7.0

- The Library is now the **Wiki**, your in-game encyclopedia for any item: who drops it, sells it,
  its recipes and quests. Open it with a key or Alt + click on an item as well as hold R3.
  `/if wiki <item>` replaces `/if library`.

## Auction 0.7.0

- The auction window and its tasks work with the mouse and keyboard too.

## Junk 0.7.0

- The Destroy panel is reworked and works with the mouse and keyboard too.

## Map 0.6.2

- Peek Map: new options in its tab.

## Gather 0.6.2

- Minimap labels: new options in its tab and a few fixes.

## Wheel 0.7.1

- Small fixes to the wheels, the bind panel and the recent slot.

## QuestTracker 0.6.1

- Fixes to the sort menu and the quest items.

## Vibration 0.6.1

- Small fixes to the Vibration tab.

## Core 0.7.0

- **Controller bindings**: every action in the crossbar and binding lists now has its own
  icon and a one-line description, and a new **Reload** action runs `/reload` from a press.
  An action put in a crossbar slot as a macro shows the game's nearest icon (a macro can't
  show an addon's texture).
- **Controller bindings**: a press can hold more than one button (L1 + R1 + a face button),
  shown in full in the lists.

## Controller 0.7.0

- The Controller tab is redone: down the left, lists of what can be bound (the wheels, Misc,
  spells, items, macros, emotes, the game's windows; L1 / R1 and L2 / R2 change list), beside
  it a bigger drawing of the controller with the picked card's press lit. Square or Cross
  binds, a box asks for the press, Triangle unbinds.

## Wheel 0.7.0

- While a wheel is up (out of combat), **Square** opens a "Bind to Action Bar" panel for the
  picked slot when it can go on the crossbar (a usable or equippable bag item, a known
  spell, a player macro). The next D-pad / face press (L2 / R2 held for their bars) puts it
  in that slot.

## Auction 0.6.1

- Fixed Buy stuck on "Buying..." when buying the same item again: Forever's client dropped
  the bid when another auction house query went out after the item's search. The list now
  refreshes first and the item is searched last, and a buy unanswered after 10 s gives up.

## Gather 0.6.1

- The Minimap labels action has its own icon and description.

## Junk 0.6.1

- The Destroy panel and Mark junk actions have their own icons and descriptions.

## Map 0.6.1

- The Peek map action has its own icon and description.

## 0.6.0

- **Journal** (new module): keeps a diary of each day you play, per character: levels, quests, places
  (zones, discoveries, instances, flights), fights (kills, elites and rares, deaths), loot, gold and
  crafting. Read it in the Library's book: `/if journal`, a key binding, or a wheel's window entry.
- **Library**: its book is now the core's (shared with the Journal); it looks and works as before.
- **Quest Tracker**: the game's objective tracker is replaced by our own copy of it: the game's
  own templates, art, fonts, animations and modules (quests, achievements, recipes, scenarios...),
  where Edit Mode puts the game's, its opacity and text size. Sorting now just orders it: no more
  untracking and re-tracking quests, and with a full tracker the top-sorted quests show.
- **Quest Tracker**: the controller works it exactly as the game's tracker (it is the game's
  tracker's own navigation, legend and buttons: D-pad Up on the shortcuts bar, A, X, Y, quest
  items, L2 / R2, B), the cursor drawn on our list. While the controller is on it, the quests show
  in the game's order (so the D-pad goes top to bottom); the sort comes back when it leaves.
- **Quest Tracker**: R3 on the tracker opens the sort menu (the Quests header's filter button's),
  driven with the controller, its prompt in the game's legend; B closes it. The game's R3 still works.

## 0.5.0

- **Junk** (formerly Destroy): the module now finds what the bags no longer need and marks it junk,
  the game's junk coin on its bag slot. It weighs quests (in your log, or one an item starts:
  QuestieDB's data), your professions' reagents and recipes, auction prices (what sells better at
  the auction house is never junk), your class (gear you can't use, a lighter armor than you wear)
  and whether it's soulbound. L2 + L3 on a bag item (rebindable) marks it junk or not junk; in the
  Destroy panel R1 does. Marks are remembered per character, so a wrong verdict stays fixed.
- **Junk**: an item a quest needs is kept while you're on the quest or can still do it (not done,
  for your race and class), e.g. Crisp Spider Meat for Redridge Goulash; once done, it can be junk.
  Profession tools (Skinning Knife, Mining Pick, Blacksmith Hammer, runed rods, fishing poles...)
  and class tools (Thieves' Tools, totems) are kept for those who use them, never junk. The
  tools come from Forever's own tables, as do the gathering professions' recipes, now known too.
- **Junk**: an ordinary item a quest needs (meat, cloth...) says so in its tooltip, in orange:
  "Needed for "Redridge Goulash"", in the bags, the loot window and links alike (not for what a
  vendor sells). On / off in the Junk tab.
- **Junk**: only items no quest needs can be marked junk; an old junk mark on one waits until the
  quest is done.
- **Junk**: a vendor's Sell All Junk now sells this junk too, after the game's greys; its button
  lights up while only ours is left. In the Destroy panel at a vendor, Square held sells them all.
- **Controller**: bag clean-up on L3 no longer also sorts on L2 + L3 (or with any shoulder or
  trigger held).
- **Auction**: the Sell tab's sections come from the same verdict (Keep now also holds your
  professions' reagents and recipes, and what you marked to keep).
- The QuestieDB and recipe data moved into the core (Improved Forever), shared by every module.
  **Updating**: delete the old `ImprovedForever_Destroy` folder from `Interface/AddOns`; the Junk
  module is `ImprovedForever_Junk`.
- **Vibration**: Eating and Drinking now follow the eat motion as the server plays it: a bite or a
  sip every 5 s (the first 3 s after you sit), as the hand reaches the mouth. Both Skyborne races
  are timed too.

## 0.4.0

- **Options**: Esc > Options > AddOns > Improved Forever can now be used with a controller (D-pad
  right from the list, then the Open button). `/improvedcontroller` works again. (#1)
- **Wheel**: opening a wheel with L1 / R1 / R2 + R3 no longer leaves that button stuck down. (#3)
- **Wheel**: R3 is only taken under the shoulders whose combo has a wheel, so a combo set back to
  the game's own (R3 alone: ping) does what the game does again. R3 alone stays ours while a wheel
  is on R1 or on a shoulder the game doesn't make a modifier. (#4)
- **Vibration**: new Food & drink section. Eating (Munch) and Drinking (Gulp) play while you sit
  with food or a drink, in time with your character: a bite or a sip each time the hand reaches the
  mouth (timed per race and sex from the game's models), until you stand up or it's done. Each can
  take any pattern instead, or be off.
- **Destroy**: Cross (and Triangle from the loot window) is now held instead of pressed twice: the
  picked card fills while you hold, and the item goes when you let go once it's full. Let go
  sooner, or move, and nothing happens.
- **Vibration**: every hold now rumbles the way the auction window's do: rising as you hold, full
  once it's ready, a thump when it acts. New: Destroy (one and all), the Wheels tab (Triangle held:
  rename / reset, Square held: delete) and the touchpad corners in the Controller tab.
- Every hold is now labelled "Hold to …" (Hold to Destroy, Hold to Swap All, Hold to Rename, Hold
  to Delete, Hold to Turn Off, Hold to Open Library).
- **Vibration**: new Shooting event. Each ranged shot (Auto Shot, Shoot, Throw, a hunter's instant
  shots) rumbles, matched to the weapon: a bow's string, a crossbow's latch, a gun's recoil, a wand's
  zap, a throw.
- **Vibration**: new Abilities event. Each instant ability (Heroic Strike, Sinister Strike, a seal,
  a shock...) has its own feel: a slash, a stab, a bash, a charge, a whirl, a seal's light, a
  Judgement...
- **Vibration**: Gathering matches the action, with its own pattern for fishing (the throw, then
  still: Forever doesn't tell addons when a fish bites).
- **Vibration**: hold and confirm rumbles always reach a strength the motors can be felt at.
- **Destroy**: the window now sits beside the one it was opened from (the loot window or the bags),
  and moves as they open and close.
- **Tasks**: "sold by vendors" now uses Forever's own vendor lists (and the Library's data when it's
  loaded), so more reagents are found.
- **Library**: data synced with WoW Forever's own recipes, items and vendors.

## 0.3.1

Each module is now its own CurseForge project, so you can install only the ones you want. The
CurseForge app installs the core, **Improved Forever**, along with any module (and Controller with
Wheel).

- **Improved Forever** on CurseForge is now the core only. If you installed 0.3.0 there, add the
  modules you use: Improved Forever: Controller, Wheel, Vibration, Gather, Map, Auction, Destroy,
  Library and Quest Tracker.
- **Quest Tracker** replaces the old Improved Quest Tracker project, which is no longer on CurseForge.
- GitHub releases attach a zip per addon, plus `ImprovedForever-All-<version>.zip` with all of them.

## 0.3.0

Improved Controller is now **Improved Forever**, split into modules: each feature is its own addon,
enabled or disabled in the AddOns list. The core (ImprovedForever) is needed by all of them.

- **Modules**: Controller (bag clean-up, touchpad corners, every press on one drawing), Wheel,
  Vibration, Gather, Map, Auction (with Tasks), Destroy and Library.
- **New configuration panel** in the auction window's look: a tab per loaded module down the right
  (L1 / R1 or the right stick), each module's sections down the left (the left stick or L2 / R2),
  its settings as fields in the middle (left / right change them in place, Cross picks from the
  list on the right).
- **Destroy** has its own tab: on / off and the press that opens it.
- **Quest Tracker**: the Improved Quest Tracker addon is now a module (`ImprovedForever_QuestTracker`), set up
  in its own tab; `/iqt` is now `/if quests`. Its options are no longer added to the quest's right-click menu.
- `/if` replaces `/ic` (`/if help` lists the commands).
- Settings start fresh: they're kept in new saved variables (ImprovedForeverDB...).
- **Touchpad**: its click is left to the game while one of the game's windows is open.
- **Recent action slot** sits beside the crossbar's rightmost bar and follows it as the bars move.
- **Quest Tracker**: reordering watched quests from the gamepad no longer loops.

## 0.2.0

First public release.

- **Wheels**: radial wheels on R3 combos laid out like Forever's own radial menu, with several
  wheels per combo, slot tooltips, custom emote icons and a consumables wheel split by category.
  The right stick aims the wheel.
- **Recent action slot** on R3, placed and sized in the game's Edit Mode per layout.
- **Touchpad**: corner slots edited from a wheel-style picker.
- **Button overrides**: L3 click and double-click actions.
- **Vibration**: events (low health, spell casts and more) with patterns matched to action
  families, and a cast preset editor per action and per phase.
- **Bag cleaner**: pick items to destroy from the controller.
- **General** tab: bag sort binding, picker offsets. Double-tap Menu opens the config.
- Own icon set: cream line art with green accents.
