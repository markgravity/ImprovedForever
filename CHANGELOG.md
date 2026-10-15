# Changelog

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
