# Improved Forever

Quality-of-life tweaks for playing **WoW Forever** with a gamepad. Everything is set up and used
from the controller: no keyboard step needed.

Each feature is its own addon (enable only the ones you want in the AddOns list); all of them need
the core, **Improved Forever**:

| Addon | What it does |
|---|---|
| `ImprovedForever` | The core: button glyphs, bindings, the configuration panel, the game data (QuestieDB's, recipes) and the item verdict every module shares. Required. |
| `ImprovedForever_Controller` | Bag clean-up, touchpad corners, the Controller tab: every press on one drawing of the controller. |
| `ImprovedForever_Wheel` | Wheels on R3 combos, the recent action slot. Needs Controller. |
| `ImprovedForever_Vibration` | Vibration on game events and spell casts. |
| `ImprovedForever_Gather` | Names beside the minimap's gathering dots, alerts. |
| `ImprovedForever_Map` | The peek map. |
| `ImprovedForever_Auction` | The controller auction window, prices over time, tasks. |
| `ImprovedForever_Junk` | Finds and marks junk, sells it with the vendor's Sell All Junk, destroys it from the bags or the loot window. Formerly Destroy. |
| `ImprovedForever_Library` | Everything about an item. |
| `ImprovedForever_QuestTracker` | Sort options for the quest tracker (zone, level, title, distance, completed) and an objective complete sound. Formerly Improved Quest Tracker. |

## Features

- **Wheels** on R3 combos, laid out like the game's radial menu: spells, items, emotes,
  consumables (paged by category), several wheels per combo. Aim with the right stick.
- **Recent action slot** on R3, placed in Edit Mode.
- **Touchpad** corner actions.
- **Button overrides** for L3 click and double-click.
- **Vibration** on game events and spell casts, with per-action patterns.
- **Junk**: what the bags no longer need is marked junk (the game's coin on its slot), from quests (QuestieDB's
  data), your professions' recipes, auction prices, your class and whether it's soulbound. L2 + L3 on a bag item
  marks it junk or not junk, remembered per character. A vendor's Sell All Junk sells it all. Its **Destroy**
  panel throws junk away from the controller; from the loot window when the bags are full, it destroys junk
  and loots in its place. The auction window's Sell tab sorts the bags by the same verdict.
- **Library**: hold R3 on an item (bags, loot window, auction house) for everything about it: what drops
  it, who sells it, the recipes that make or use it, its quests and auction prices. Drops, vendors and
  quests come from [QuestieDB](https://github.com/Questie/QuestieDB)'s data: the addon when installed, else
  a copy that ships with this one.

Double-tap **Menu** (or `/if`) to open the configuration: a tab per loaded module down the right
(L1 / R1, or the right stick), the module's sections down the left (the left stick, or L2 / R2), its
settings in the middle (left / right change one, Cross picks from its list on the right).

## Install

- **CurseForge app**: search *Improved Forever* and install the modules you want (*Improved
  Forever: Wheel*, *Improved Forever: Auction*...); each brings the core along.
- **Manual**: download `ImprovedForever-All-<version>.zip` (or the core's and each module's own
  zip) from [Releases](https://github.com/markgravity/ImprovedForever/releases) and unzip it into
  `World of Warcraft/_forever_/Interface/AddOns/` so you get `AddOns/ImprovedForever/`,
  `AddOns/ImprovedForever_Wheel/`... (remove an old `AddOns/ImprovedController/`).

## Development

One repo, one folder per addon (`ImprovedForever/` the core, `ImprovedForever_<Module>/` each module).
Link them into the game with `tools/link.sh "<game>/Interface/AddOns"` and `/reload` in game.

A module reaches the core through the global `ImprovedForever` (`local IF = ImprovedForever`), says it
is there with `IF.AddModule`, adds its presses with `IF.Binds.Add`, its commands with `IF.AddCommand`
and its settings tab with `IF.SettingsPage` (form fields) or `IF.Menu.AddTab` (a page of its own).
Another module's table (`IF.Auction`, `IF.Vibe`...) is used only after checking it is loaded.

`luajit tools/loadcheck.lua each` loads the core with each module alone, then all of them, against a
stand-in for the game's API, and drives the configuration panel: it catches a module reaching for
one that isn't loaded.

`vendor/QuestieDB` is a git submodule of [QuestieDB](https://github.com/Questie/QuestieDB), for its API
types and data (`git submodule update --init`). `python tools/make_library_data.py` copies what the
Library shows from it into `ImprovedForever_Library/LibraryData.lua`, which ships; the submodule itself isn't packaged.

- `tools/make_*.py` regenerate the TGA textures.
- `python tools/make_library.py` regenerates `ImprovedForever_Library/LibraryRecipes.lua` from the game's recipe tables (wago.tools).
- `python tools/package.py` builds a zip per addon in `dist/` and `ImprovedForever-All-<version>.zip` with every addon.
- `python tools/make_module_icons.py --logos` also writes each module's CurseForge logo to `dist/logos/`.

### Releasing

1. Bump `## Version:` in every addon's TOC (`ImprovedForever*/ImprovedForever*.toc`).
2. Add a `## <version>` section on top of `CHANGELOG.md`.
3. Commit, then `git tag v<version> && git push origin main v<version>`.

The [release workflow](.github/workflows/release.yml) checks the tag matches the TOC, builds the
zips, creates the GitHub release with the changelog section, and uploads each addon's zip to its
own CurseForge project (`## X-Curse-Project-ID` in its TOC) when `CF_API_KEY` is set. A tag with a suffix (`v0.3.0-beta1`) makes a pre-release / beta.

## Support

Improved Forever is free and always will be. If it makes your game better and you'd like to
say thanks, you can buy me a coffee:

- [Ko-fi](https://ko-fi.com/markgravity)
- [PayPal](https://paypal.me/markgravity)

## Credits

The Library's drop, vendor and quest data comes from [QuestieDB](https://github.com/Questie/QuestieDB)
by the Questie team; creatures' display ids (their portraits) from
[cMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).

Parts of the code are adapted from
[Easy Controller - Forever](https://github.com/moust4ki/EasyControllerWowForever) by moust4ki
(MIT): see [LICENSE-EasyController.md](LICENSE-EasyController.md).

## License

[MIT](LICENSE)
