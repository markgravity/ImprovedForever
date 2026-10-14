# Feature requests

Requests from players, to plan what comes next. Each says where it came from, what was
promised publicly, and a first idea of how it could be done. Move an entry to **Done** (with
the release) when it ships.

Source threads (launch posts, 2026-10-14): r/wowforever `1x5o74u`, r/classicwow `1x5o5ma`,
r/classicwowplus `1x5o7l2`.

## Planned (said "on the list" publicly)

### Quest item wheel
- **Asked by:** u/Aurd04 (r/wowforever, pgp7ktu), a former ConsolePort player: "the biggest
  feature I miss is quest items auto populating in a radial menu".
- **Promised:** "An auto-filled quest item wheel is a great idea though, adding it to the list!"
- **Idea:** a Wheel kind that fills itself with usable quest items: items in the bags with a use
  spell (`GetItemSpell`) that start or belong to a quest in the log (QuestieDB / `IF.GameData`
  for the item's quests, else the item's class Quest). Refresh on `BAG_UPDATE_DELAYED` and
  `QUEST_LOG_UPDATE`; empty wheel shows a hint. Like the consumables wheel, which already
  pages by category.

### Trinket / gear swap wheel
- **Asked by:** u/Sea-Inspection2110 (r/classicwow, pgoss5q): "give controller players the
  utility of itemrack / trinketmenu... managing swapping their 15-20 trinkets in combat".
- **Promised:** "A trinket / gear swap wheel is a great idea, it's going on the list!"
- **Idea:** a wheel per equipment slot (trinkets first) listing the bag items that fit it, with
  their cooldowns; picking one equips it to the chosen slot (`EquipItemByName` / `PickupContainerItem`
  + `EquipCursorItem` out of combat; in combat only what the game allows, queue the rest for
  `PLAYER_REGEN_ENABLED` like ItemRack). Later: saved gear sets.

### Common chat phrases on a wheel
- **Asked by:** u/Darth-Ragnar (r/wowforever, pgoo1kw): "common phrases as well as a dictionary
  of English words for auto complete".
- **Promised:** "Common phrases on a wheel is a nice idea, noting it down."
- **Idea:** a Wheel kind of phrases (editable list, a few defaults: "Thanks!", "Ready?", "One
  sec", "Inc", "OOM") sent to the chat type in use or to `/p`, `/s`. Auto complete is out of
  scope for now (typing stays the game's).

### Hide target icons and other buttons for a cleaner look
- **Asked by:** u/ActuallyaDoombot (r/wowforever, pgp3vt8): "an option to make the target
  icons invisible as well as other buttons/icons".
- **Promised:** "Noted as a request!"
- **Open question:** which icons exactly (the gamepad target / interact icons over units? the
  crossbar's button glyphs?). Ask them before building. Careful: nameplates and the game's
  frames can't be touched (taint), so only what `IF.Focus.Fade` or a CVar can hide.

## To look into

### Easy Controller - Forever compatibility
- **Asked by:** u/wang_johnson (pgp9emw), u/cesarito27 (pgp8alz), r/classicwow.
- **Said:** not tested together, use one or the other, report if something breaks.
- **Idea:** install both, check bindings (both write crossbar slots / override bindings) and
  taint on window close. If they clash, detect it at login and say so once.

### Not possible from an addon (answered, no plan)
- Remap physical buttons (Switch Pro A/B swap) while keeping the on-screen layout
  (u/ufointrovert, pgpi1ko): happens before the game; only `/if buttons` labels.
- Chat from the Battle.net phone app (u/Megaspids, pgoh39n).
- Haptics / devices outside the controller (several jokes, BarrettRTS pgp85as).

## Code review notes (u/Sentiray, r/classicwow, pgpfhxx)

Points from a reader of the code. Check each, fix what holds:

- [x] The Journal's Forget left the people's logs (chat snippets, whispers): fixed, Forget
  clears them too.
- [ ] Two "sell items to a vendor" paths with different rules (the Junk module's vendor sale
  and another): make one, on `IF.ItemValue.Judge`.
- [ ] A sale request is taken as proof the sale happened: confirm from the bag / money change.
- [ ] Missing information treated as permission to go on (callers): find these and fail safe.
- [ ] A controller override clears its own state before removing the binding, so the binding
  stays in game while the addon thinks it's gone.
- [ ] README describes outdated file locations.
- [ ] Big files with many jobs (the auction window file, ~2500 lines): split rendering,
  selection, bindings and server replies.
- [ ] The Journal records whispers by default: consider making chat (talks) an option, off or
  clearly shown in its tab.

## Done

- Core 0.8.1: the Options > AddOns button no longer gets a forbidden action error
  (u/Nilbogz, pgonjs3).
