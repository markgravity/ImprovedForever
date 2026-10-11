# Changelog

## Unreleased

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
