# Task list

Work planned from the launch threads' feature requests and bug reports
(`docs/feature-requests.md` has who asked and what was said). Review, then work them in order.

**Priority:** P0 bug players hit now · P1 promised publicly · P2 worth doing · P3 later / research.
**Size:** S (an hour or two) · M (a day) · L (several days).
**Status:** `todo` · `needs info` (waiting on a player) · `review` (approve or drop) · `test` (built, to try in game) · `done`.

| # | Task | Module | Pri | Size | Status |
|---|---|---|---|---|---|
| 1 | Gather: spread the minimap scan, stop the FPS hiccups | Gather | P0 | M | test |
| 2 | Vibration: jump and auto-attack start | Vibration | P0 | S | test |
| 3 | Crash from the "control panel" (Immolation_E) | Core | P0 | S | needs info |
| 4 | Crash on load (Ninjatendo90) | All | P0 | S | needs info |
| 5 | Quest item wheel | Wheel | P1 | M | test |
| 6 | Ground-targeted spells from the pad | Wheel | P1 | M | review |
| 7 | Trinket / gear swap wheel | Wheel | P1 | L | test |
| 8 | Chat phrases wheel | Wheel | P1 | S | test |
| 9 | Hide / customise HUD elements | Core | P1 | ? | needs info |
| 10 | Swap the A/B glyphs on screen only | Core | P2 | S | review |
| 11 | Totems wheel preset | Wheel | P2 | S | test |
| 12 | Easy Controller - Forever compatibility | All | P2 | S | todo |
| 13 | Journal: talks (chat, whispers) as an option | Journal | P2 | S | review |
| 14 | One vendor-sell path, confirmed sales | Junk, Auction | P2 | M | test |
| 15 | Override binding cleared before it's removed | Core | P2 | S | test |
| 16 | README: outdated file locations | Docs | P2 | S | test |
| 17 | Gyro on the DualSense | Core | P3 | S | review |
| 18 | Healer targeting: the Group wheel | Wheel | P3 | L | test |
| 19 | Split the auction window file | Auction | P3 | L | review |

---

## P0: bugs

### 1. Gather: spread the minimap scan, stop the FPS hiccups
- **Report:** u/swjodokast: FPS hiccups every 1-2 s with many dots (hunter tracking humans in a
  capital). They asked to ignore tracked dots that aren't gathering.
- **Cause (likely):** `Gather.lua` `watcher` runs `Watch()` every `interval`, and `N.Scan`
  (`NodeScan.lua`) reads the whole grid of points (`N.step = 6`) in one frame, each point a
  `Minimap:UpdateMouseoverAtPoint` + `C_TooltipInfo.GetMinimapMouseover` call.
- **Plan:**
  1. Measure: time one scan (`debugprofilestop`) with many dots vs few; log to `IF.db` per the
     CLAUDE.md probe rules.
  2. Spread a scan over frames (a budget of points per frame), keep the last full result shown
     until the new one finishes.
  3. Skip the scan when no gathering tracking is on (Find Herbs / Find Minerals), and drop names
     that aren't herbs or ore before grouping.
- **Done when:** no visible hiccup in a capital with Track Humanoids on; labels and alerts still
  appear as before.

### 2. Vibration: jump and auto-attack start
- **Report:** u/Immolation_E (8BitDo): nothing on jumps or when starting a melee attack.
- **Found:** `Vibration.lua` has no jump or melee auto-attack event (only ranged auto-repeat).
- **Plan:** new actions in the Vibration list, off by default for jump (it fires a lot):
  - Jump: `hooksecurefunc("JumpOrAscendStart", ...)` (a post-hook, no taint), skip while
    swimming / flying.
  - Auto-attack start: `PLAYER_ENTER_COMBAT` (and `PLAYER_LEAVE_COMBAT` to stop).
- **Done when:** both show in the Vibration tab with a pattern and strength, and fire on the pad.

### 3. Crash from the "control panel" (Immolation_E)
- **Report:** "I went to the control panel to try to make adjustments but it just crashes the
  game." Likely the Options > AddOns button fixed in Core 0.8.1 (same as Nilbogz, swjodokast).
- **Needs:** whether they opened it from Options > AddOns or `/if`, and their Core version.
- **Plan:** if `/if` also crashes on 0.8.1, reproduce with taintLog 1 and the Vibration tab open.

### 4. Crash on load (Ninjatendo90)
- **Report:** "crashing on load", tried a few times. Asked which addons; no answer yet.
- **Plan while waiting:** install the CurseForge zips fresh (core + every module) in a clean
  AddOns folder, log in, check for Lua errors and taint; `luajit tools/loadcheck.lua each`.

## P1: promised publicly

### 5. Quest item wheel
- **Asked by:** u/Aurd04 ("quest items auto populating in a radial menu"), u/swjodokast.
- **Plan:** a wheel kind that fills itself: bag items with a use spell (`GetItemSpell`) that
  belong to a quest in the log (`IF.GameData` / QuestieDB for the item's quests, else class
  Quest). Refresh on `BAG_UPDATE_DELAYED` / `QUEST_LOG_UPDATE`; empty wheel shows a hint. Model on
  the consumables wheel (paged by category). Secure use with `type = "item"`.
- **Done when:** a quest's usable item appears on the wheel when the quest is taken and leaves
  when it's turned in, usable in combat.

### 6. Ground-targeted spells from the pad
- **Asked by:** u/swjodokast ("targeted AOE that the alpha controller support is lacking").
- **Research first (S):** does Forever's client cast ground spells with `/cast [@player]`,
  `[@target]`, `[@cursor]`? Test Blizzard / Flamestrike / Rain of Fire / Volley in game.
- **Plan if it works:** a wheel slot option "cast at: target / me" for ground spells, a secure
  macro button behind it. **Review:** drop if no conditional works.

### 7. Trinket / gear swap wheel
- **Asked by:** u/Sea-Inspection2110 (ItemRack / TrinketMenu for the pad).
- **Plan:**
  1. A wheel per slot (trinket 1, trinket 2 first): bag items that fit, with cooldown swipes.
  2. Pick = equip to that slot (`EquipItemByName(item, slot)`). In combat only what the game
     allows; queue the rest for `PLAYER_REGEN_ENABLED` like ItemRack, shown as pending.
  3. Later: saved gear sets.
- **Done when:** swapping a trinket out of combat from the wheel works, and an in-combat pick
  equips on leaving combat.

### 8. Chat phrases wheel
- **Asked by:** u/Darth-Ragnar (common phrases; auto complete is out of scope).
- **Plan:** a wheel kind of phrases, editable list in the Wheels tab, defaults ("Thanks!",
  "Ready?", "One sec", "Inc", "OOM"), each sent to the open chat's type, else `/p` in a group,
  `/s` alone. `SendChatMessage` from a key press is fine (hardware event).

### 9. Hide / customise HUD elements
- **Asked by:** u/ActuallyaDoombot ("target icons invisible as well as other buttons/icons",
  "Customization of what can be shown").
- **Needs:** which icons exactly (the gamepad target / interact icon over units? crossbar
  glyphs?). Nameplates and the game's frames can't be touched (taint): only `IF.Focus.Fade` or a
  CVar. Scope after they answer.

## P2: worth doing

### 10. Swap the A/B glyphs on screen only
- **Asked by:** u/ufointrovert (Switch Pro: A and B look reversed on screen).
- **Research (S):** does Forever have a CVar / setting for its own glyph style (crossbar,
  legends)? `/if buttons` already sets ours. **Review:** drop if the game's glyphs can't change.

### 11. Totems wheel preset
- **From:** u/ParanoiD84. A ready-made Totems wheel for shamans (by element), filled from the
  spellbook like the consumables wheel.

### 12. Easy Controller - Forever compatibility
- **Asked by:** u/wang_johnson, u/cesarito27. Install both, check bindings (crossbar slots,
  override bindings) and taint on window close. If they clash, say so once at login.

### 13. Journal: talks as an option
- **From:** u/Sentiray: the Journal records whispers by default. **Review:** add a "Talks
  (chat, whispers)" setting, off by default, shown in the Journal tab; or keep on and say so.

### 14. One vendor-sell path, confirmed sales
- **From:** u/Sentiray: two "sell to vendor" paths with different rules; a sale request is
  taken as proof of the sale; missing info treated as permission to go on.
- **Plan:** find both paths, make one on `IF.ItemValue.Judge`; confirm each sale from the bag
  slot emptying / `PLAYER_MONEY`; stop when an item's info isn't loaded.

### 15. Override binding cleared before it's removed
- **From:** u/Sentiray: an override clears its own state before removing the binding, so the
  binding stays in game while the addon thinks it's gone. Find it, swap the order, test.

### 16. README: outdated file locations
- **From:** u/Sentiray. Check every path the README names against the repo.

## P3: later / research

### 17. Gyro on the DualSense
- **Asked by:** u/Shako_117. Check `C_GamePad.GetDeviceRawState` for motion data on Forever.
  **Review:** only if the API has it.

### 18. Healer targeting: the Group wheel
- **From:** thread discussion (konoxians, Nirwel, dynari).
- **Forever's own:** friendly modifier + D-pad targets party1-4, or walks a cursor over the
  game's compact party / raid frames only (hard-coded; addon frames can't join), each step
  changing the target.
- **Built:** a built-in Group wheel (`Group.lua`): the party (all five slots) or the raid
  (a page a raid group), by unit token. A pick targets; D-pad up / down on a member picks a
  spell from the wheel's slots in the Wheels tab (helpful ranged spells by default), cast on
  them without changing the target. Names, class, health read live (secret-safe). The
  picked member's unit frame (the game's, or any addon's secure unit button) gets a gold
  highlight of ours (`UnitFrames.lua`, read-only).
- **Test:** party and raid, in combat, roster changes mid-fight, R3 twice, the highlight with
  HealForever / Z-Perl Forever / ForeverUI, and no taint on closing pad-focused windows.

### 19. Split the auction window file
- **From:** u/Sentiray (~2500 lines: rendering, selection, bindings, server replies).
  **Review:** refactor only, no player-facing change; do it when touching that file anyway.
