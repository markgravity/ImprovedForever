---
name: control-game
description: Drive the running WoW Forever client from Claude Code on macOS to verify an addon change for real - focus the game, type chat commands (/reload, /run), press keys, walk, click NPCs and menus, screenshot, toggle addons, and read results from SavedVariables. Use when asked to test in game, reproduce a player's bug report, verify a fix on screen, or "control the game yourself".
---

# Control the game

The client runs in a window on the user's Mac and the addon folders are symlinked into it
(`tools/link.sh`), so an edit plus `/reload` is live. Tools: `osascript` (System Events, JXA),
`cliclick` (`/opt/homebrew/bin/cliclick`), `screencapture`. All need the Accessibility and
Screen Recording permissions of the terminal app, which this machine has.
Scripts here: `.claude/skills/control-game/` (call them by full path; `S` below).

## Rules
- The user's character is live. Ask before anything with side effects beyond looking (logging
  out, selling, destroying, fighting). Walking a short way and talking to an NPC is fine when
  the user asked for a real test.
- Change nothing you can't put back. Note each addon you enable or disable, a CVar or a
  setting you flip, and restore it at the end. Tell the user.
- Always focus the game first. A key sent while another app is in front lands in that app
  (it once typed into the Claude prompt box). `shot.sh`, `send.scpt` and `key.scpt` focus it.
- One thing at a time, then a screenshot and read it. Never chain blind clicks.

## Moves
- Screenshot: `S/shot.sh out.png`, then Read the png. The window may be partly under other
  windows; the screenshot is the whole screen (2x retina).
- Chat command: `osascript S/send.scpt '/run UIParent:SetAlpha(0)'`. The text is an argument,
  so quotes in it are fine. `/reload` takes about 10 s; wait before the next step.
- Key: `osascript S/key.scpt 53` (Esc 53, Return 36). Esc closes the NPC window / target
  first, a second Esc opens the game menu.
- Hold a key (walk W 13, turn A 0 / D 2): `S/shot.sh x.png; osascript -l JavaScript S/hold.js 13 1.5`.
- Mouse: `cliclick m:X,Y w:300 c:.` (click) / `rc:X,Y` (right click, e.g. an NPC to talk).
  X, Y are screen points = screenshot pixels / 2. The Read tool says the display scale
  ("multiply by 1.51 to map to original"): points = displayed x 1.51 / 2 = displayed x 0.756.
  Move first, wait 300 ms, then click; the game ignores a click that arrives with the move.
- Esc menu: the first Esc closes whatever is open (an NPC window, the target), the next one
  opens the Game Menu in the middle of the game window. Buttons, top to bottom: Options,
  AddOns, Edit Mode, Support, Macros, Log Out, Exit Game, Return to Game. Screenshot it and
  click from the picture (the window can sit anywhere on the screen); Esc again, or Return
  to Game, closes it. Log Out and Exit Game end the user's session: never without asking.
- AddOns: Esc, click "AddOns" to tick or untick an addon for the character, Okay (the UI
  reloads by itself). Do this rather than `/run C_AddOns.EnableAddOn` plus a logout: the user
  prefers the menu, and an addon turned on mid-session needs the reload it triggers.

## Reading state when the chat can't be seen
Some addons hide the whole UI (DialogueUI sets `UIParent` alpha to 0 and takes Enter), so
chat output and `/run` don't work while their window is open. Follow `CLAUDE.md` "Debugging in
game": a temporary probe in the module logs lines into `IF.db.<name>Log` on the event, then
`/reload` (the game writes SavedVariables only then) and read
`WTF/Account/<account>/SavedVariables/ImprovedForever.lua`. Remove the probe and clear its
table afterwards (`git checkout` the file, `/run ImprovedForever.db.<name>Log=nil`).

## Recipes
- **Hide-the-UI bugs** (what stays visible): `/run UIParent:SetAlpha(0)`, screenshot, restore
  with `/run UIParent:SetAlpha(1)`. 3D `PlayerModel` frames ignore a parent's alpha: they
  need their own (see `UnitFrames.lua`). Nameplates are not under `UIParent` and stay.
- **NPC window of another addon** (DialogueUI is installed but off for the test character):
  turn it on in the AddOns menu, `/reload`, right-click a nearby NPC (innkeepers stand in
  every inn), screenshot, close it with its Goodbye button or Esc, turn the addon off again.
  The reporter's setup is the one to copy; check a third-party addon's own code in
  `_classic_beta_/Interface/AddOns/<Name>/` before blaming ours (the "XP bar" in a bug
  report was DialogueUI's own bar).
- **Which module draws something**: grep the atlas / frame name in the repo first; if ours
  doesn't, read the other addon's source.
- **Finding an NPC**: quest data is in `ImprovedForever/WorldData.lua` (`[npcId]="Name|...|zone:x,y"`);
  the minimap coordinates show under the minimap. Walk in steps of 1-2 s and re-screenshot.

## After
Restore every toggled addon / setting, close windows, leave the character where it can't
come to harm, remove probes, and say what was changed and put back.
