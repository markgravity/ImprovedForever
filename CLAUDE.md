# ImprovedForever

## Window focus: look and behave like the game's own windows

Every window of ours that takes the gamepad (Library, Destroy (Junk), Add Task, vendor
Tasks, the auction window, its confirmation, the config window) shows and passes
focus the way Forever's native windows do. The shared code is
`ImprovedForever/Focus.lua` (`IF.Focus`). Use it, don't hand-roll a copy.

### Focus ring
- Use the window's own `FrameGlow`: `IF.Focus.Glow(win, focused)`.
  `DefaultPanelFlatTemplate` and `PortraitFrameTemplate` already have one, laid
  out for the template and coloured by the controller options.
- Never build the glow from the atlas yourself
  (`gamepad-uiframemetal-*-focus`), and never tint it from
  `GamepadFocusStateColor`. The game draws its glow untinted until those
  options change, so a copy never matches.
- Show the glow only while the window has the pad. Hide our button legend while
  it doesn't, as native windows do.
- While ours has the pad, dim the game's focus (cursor, focused window's glow
  and footer) with `IF.Focus.DimNative(win, true)`, and restore it with
  `false`. It draws them at alpha 0 with an animation of ours.
- Never set a property of the game's frames (`SetAlpha`, `Hide`, `SetPoint`...)
  from addon code: it taints them, and closing a gamepad-focused window later
  gets `SetPreferredGamepadInteractTarget` forbidden. To hide one, use
  `IF.Focus.Fade(region, true)` (an animation of ours aimed at it).
- Never add our frames to the game's managed frames
  (`RightManagedFrameContainer:AddManagedFrame`): it lays them out tainted and
  resizes the objective tracker from addon code.

### L2 / R2
- Build the window's switch with `IF.Focus.Switch(win, { onChange, other?, label? })`:
  - `sw:Hint()` gives the legend entry.
  - Call `sw:Press(key)` for LT/RT on our catcher.
  - Call `sw:Update()` from `OnUpdate`.
  - Use `sw:Set("ours" | "game")` to switch.
- The direction follows the screen side. The pad goes to the game window that
  still has the game's focus (the one ours was opened from): L2 if that window
  is on our left, R2 if on our right. The other trigger, pressed on that window
  (or the next one along toward ours), brings the pad back.
- The legend label is the target's `GetJumpHintLabel()`, else the game's
  PREVIOUS / NEXT.
- Never call the frame manager's `Focus*` / `FrameShown` / `ShowUIPanel` from
  addon code. Only read `GamepadMode.FrameControlsManager`
  (`shownFrames`, `focusedFrame`, `isUIFocused`). Calling them taints window
  closing (ADDON_ACTION_BLOCKED on SetPreferredGamepadInteractTarget).
- Take the pad with a catcher frame (`EnableGamePadButton`). Call
  `EnableGamePadButton(false)` right after `SetScript`, because setting the
  handler turns input on.

### Focus indicator (the cursor)
- The element the pad is on gets the game's gamepad cursor:
  `SmartNavigation.Pointer`, its large arrow in `GAMEPAD_SMARTNAV_CURSOR_COLOR`,
  sitting left of the element.
- Use `IF.Focus.Cursor(parent)`, which gives `cur:Point(target)` and `cur:Hide()`.
  For a bare texture, use `IF.Focus.CursorTexture(tex)`.
- These copy the live native cursor: its atlas, its on-screen size, its
  animation (IntroAnim), and its offset from the button (`cursorOffsetX/Y`).
- Never hand-build the arrow with your own atlas, scale or bob animation.
- A cursor shows only in the window that has the pad (the one whose
  `FrameGlow` is on). Show it on one element only: the lit one.
- List rows use `IF.UI.FocusStroke`. It adds the cursor by itself while the row
  is lit at full strength. A dimmed row (alpha or tint under 1, meaning "picked
  but not where the pad is") gets no cursor. Pass the dim through
  `SetVertexColor(r, g, b, a)`, `SetAlpha` or `Light(on, dim)`.

### Placement
- Every side window of ours sits where the game would put a panel. Use
  `IF.Focus.Dock(win)` and never hand-anchor it to another window.
- **Vertical:** `TOP_OFFSET`, lifted when there's no room at the bottom.
- **Horizontal:** beside whatever is already open along the top, the game's
  spacing between:
  - the game's panel slots (`GetUIPanel("left"/"center"/"right"/"doublewide")`)
  - its gamepad window row (`shownFrames`, where Character lives)
  - windows of ours placed elsewhere but counted (`IF.Focus.AlongTop(win)`,
    like the auction window)
  - our docked windows opened earlier
- **Nothing open:** the first panel slot (`LEFT_OFFSET` + 35, the Professions
  window's place).
- **Full width:** count each window's full width, including its UI-panel
  extra width (Character's side tabs) and parts hanging off its right side.
- **Not along the top:** the bags and the loot window don't count.
- **No room past them:** as far right as the window fits.
- **Re-placed as windows come and go:** every docked window is checked a few
  times a second while shown.
- **Beside its opener:** a window opened from one that isn't along the top
  (Destroy, from the bags or loot window) sits beside that one instead:
  `IF.Focus.Dock(win, { beside = fn })`, `fn` returning the frames. It goes on
  the side with room, tops level, and falls back to the top row when none is
  shown.
- Don't hand placement to the game's panel manager: an addon panel there
  taints it.
- This includes the Improved Forever config window. Center only
  confirmations, the way the game centres its dialogs.

## Quest Tracker: our fork of the game's tracker
- `ImprovedForever_QuestTracker/Tracker/Blizzard_*` is Forever's own
  Blizzard_ObjectiveTracker, every global renamed with an `IF` prefix, made by
  `python3 tools/fork_objective_tracker.py`. Never edit those files: rerun the
  script after a client update and check the diff.
- Our changes go in `Tracker/PatchEarly.lua` (the frame mixin, before its XML),
  `Tracker/Patch.lua` (instances), `Tracker/Menu.lua`, `Pad.lua`, `Items.lua`,
  `Secure.lua`, or as a text patch in the script (`PATCHES`).
- The game's tracker keeps running unseen under ours (its header, background
  and modules at alpha 0, never hidden or emptied: an empty one errors in the
  frame manager when the D-pad focuses it). Edit Mode places it, ours follows.
- The controller is the game's tracker's own: never take its buttons (no catcher,
  no pad override bindings, no propagating presses): that taints its navigation
  (SetPreferredGamepadInteractTarget forbidden on close). `Tracker/Pad.lua` only
  draws our cursor on our element matching SmartNavigation's current button.

## Item verdict: one, in the core
- Whether a bag item is junk, kept, for the auction house or for a vendor is
  `IF.ItemValue.Judge(bag, slot)` (`ImprovedForever/ItemValue.lua`). Every module
  asks it (Junk, the Destroy panel, the auction Sell tab); don't write another.
- Its data is the core's: `IF.GameData` (`GameData.lua`: QuestieDB or our
  `WorldData.lua`, the recipes of `RecipeData.lua` and the ones seen in game).
  The Auction module hands it prices with `IF.ItemValue.UseAuction`.
- The player's junk / not junk marks are per character
  (`IF.charDB.junkMarks`), by item ID.

## Game data: always Forever's
- Every bundled data file and hardcoded game ID (items, spells, NPCs, nodes) must
  match WoW Forever (client 1.60.x), not Classic Era: Forever changed recipes,
  spells and items.
- Sync and check with `/sync-forever-data` (`python3 tools/sync_forever_data.py`).
  It pulls QuestieDB, rebuilds the Library's data from Forever's own client tables
  and QuestieDB's corrected data, and checks the IDs written in the code.
- When adding a hardcoded ID or name, check it against Forever's data, then rerun
  `python3 tools/sync_forever_data.py --check`.

## Debugging in game: log to SavedVariables
When an in-game probe prints more than a screenshot can hold, log to the saved
variables instead of the chat, then read the file:
- Write lines into a table in `IF.db` (`ImprovedForeverDB`), e.g.
  `IF.db.fishLog = { date(...) }` at the start of each run (a fresh log per run),
  then append a line per event or state change, with a timestamp
  (`GetTime() % 1000`). Show any secret value as `<hidden>`: `tostring` on one
  errors. Keep the chat to a start line and a stop line with the line count.
- The game writes it to disk only on `/reload` or logout. Ask the user to run
  the probe, `/reload`, and say when it's done.
- Read it from
  `/Applications/World of Warcraft/_classic_beta_/WTF/Account/53960380#1/SavedVariables/ImprovedForever.lua`
  (per-character data: `ImprovedForeverCharDB` under
  `WTF/Account/53960380#1/<realm>/<character>/SavedVariables/`).
- To find which event comes with something, log every event while it
  happens: `frame:RegisterAllEvents()`, leave out chat and the like, and write
  each name at most once a second. The fishing probe did this (since removed;
  it showed Forever fires nothing when a fish bites).
- Never touch a nameplate frame in a probe: they're restricted, and reaching
  into one taints the gamepad interact button.
- Once you're done, remove the probe and clear its log table (e.g.
  `IF.db.fishLog = nil` in the module's `Settings()`), so the saved variables
  stay small.

## Checks
- `luajit -bl <file>` for syntax.
- `luajit -bl <file> | grep -oE 'GGET.*"[A-Za-z_]+"'` for stray globals.
- `luajit tools/loadcheck.lua each` to load every module alone with the core.
