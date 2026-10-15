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

### Quest items and ground-targeted spells on the pad
- **Asked by:** u/swjodokast (r/wowforever, pgqrdqy): "a way to interact with quest items and
  targeted AOE that the alpha controller support is lacking".
- **Promised:** "Let put it on my list and get you know if it's possible".
- **Idea:** quest items: see the quest item wheel above. Ground-targeted spells (Blizzard,
  Flamestrike, Rain of Fire, Consecration-likes, traps): a wheel / binding entry that casts at
  the target's or your own feet with a secure macro (`/cast [@target]` / `[@player]` / `[@cursor]`),
  if Forever's client honours those for ground spells. Test first.

### Hide target icons and other buttons for a cleaner look
- **Asked by:** u/ActuallyaDoombot (r/wowforever, pgp3vt8): "an option to make the target
  icons invisible as well as other buttons/icons".
- **Promised:** "Noted as a request!" Their follow-up (pgpuz8l): "Customization of what can be
  shown would be great!"
- **Open question:** which icons exactly (the gamepad target / interact icons over units? the
  crossbar's button glyphs?). Ask them before building. Careful: nameplates and the game's
  frames can't be touched (taint), so only what `IF.Focus.Fade` or a CVar can hide.

## To look into

### Easy Controller - Forever compatibility
- **Asked by:** u/wang_johnson (pgp9emw), u/cesarito27 (pgp8alz), r/classicwow.
- **Said:** not tested together, use one or the other, report if something breaks.
- **Idea:** install both, check bindings (both write crossbar slots / override bindings) and
  taint on window close. If they clash, detect it at login and say so once.

### Swap the A/B glyphs on screen only
- **Asked by:** u/ufointrovert (r/wowforever, pgpi1ko, follow-up pgpo1tr, not answered yet): with
  a Switch Pro the on-screen A and B look reversed; keep the buttons' behaviour, swap only the
  pictures.
- **Idea:** `/if buttons` already picks the style for our windows. Check whether Forever has a
  setting / CVar for its own glyph style (crossbar, legends) we can flip; if not, say so.

### Gather: skip tracked nodes that aren't gathering
- **Asked by:** u/swjodokast (r/wowforever, pgqk2lh, edit 2): with many tracked dots (hunter
  tracking humans in a capital) FPS hiccups every 1-2 s.
- **Idea:** only probe blips that can be gathering nodes (skip while no gathering tracking is
  on, or by the blip's texture / tracking type), and spread the probe over frames. See Bugs.

### Wheel presets: totems
- **From:** u/ParanoiD84 (r/wowforever, pgpmlrr): "Radial wheels should be great for totems".
- **Idea:** a ready-made Totems wheel for shamans (one per element, or all on one), like the
  consumables wheel fills itself.

### Healer targeting on the pad
- **From:** a thread under FiskX (pgoypqn): konoxians, Nirwel, dynari (pgu7cil) on picking
  party / raid members with the D-pad (left / right picks the group, up / down the member).
- **Idea:** check what Forever's own unit frame navigation does in a raid first; a raid-frame
  picker could be a module of its own later. Not promised.
- **Now:** the Wheel's Group wheel (task 18): pick a member to target, or cast a picked spell
  on them; their unit frame lights up.

### Motion controls (gyro)
- **Asked by:** u/Shako_117 (pgnzmwq). Answered "Not yet... no gyro."
- **Idea:** check whether `C_GamePad.GetDeviceRawState` reports the DualSense gyro on Forever.

### Steam Deck / trackpads keep the mouse
- **From:** u/stwabewwie (r/wowforever, pgt53r1, not answered yet): hopes it doesn't disable the
  mouse like other gamepad addons (trackpads). We don't: every module but Controller and Wheel
  is mouse usable. Worth a reply.

### Not possible from an addon (answered, no plan)
- Remap physical buttons (Switch Pro A/B swap) while keeping the on-screen layout
  (u/ufointrovert, pgpi1ko): happens before the game; only `/if buttons` labels.
- Chat from the Battle.net phone app (u/Megaspids, pgoh39n).
- Haptics / devices outside the controller (several jokes, BarrettRTS pgp85as).
- Vibrate when a fish bites (u/RockoRockyBoxxyMan, pgqjhvt): Forever fires no event for it;
  answered.
- Cursor always shown in controller mode for touchpad pads (u/SophieBean420 pgu0b9p,
  u/Unrealcoza05 pgu4hk2: it takes a few seconds to appear): the game controls it; answered.
- Custom minimap gathering icons (u/Ollywombat, pgoy4k1): the icons are the game's; Gather
  only adds names. Answered.
- Normal-looking action bars instead of the controller UI (u/madpropz, pgow8uv): that's the
  game's UI; ConsolePort for another layout. Answered.
- First person view with weapons and spell effects (u/Real_Batu_Rem, pgspnk7, not answered):
  out of scope, the camera / model rendering isn't an addon's.

## Bug reports

- [x] **Options > AddOns button: forbidden action / crash / freeze.** u/Nilbogz (pgonjs3),
  u/swjodokast (pgqk2lh: "\if brings up the options just fine and no freeze"). Fixed in Core 0.8.1.
- [ ] **Gather: FPS hiccups every 1-2 s with many minimap dots.** u/swjodokast (pgqk2lh).
  Answered "Let me check".
- [ ] **"Control panel" crashes the game.** u/Immolation_E (r/wowforever, pgs5hn9). Probably the
  same Options button (0.8.1); ask whether it was Options > AddOns or `/if`.
- [ ] **Vibration: nothing on jump or on starting a melee attack** (8BitDo pad). u/Immolation_E
  (pgs5hn9).
- [ ] **Crashes on load.** u/Ninjatendo90 (r/classicwowplus, pgsarbn). Asked which addons; no
  details yet.

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
