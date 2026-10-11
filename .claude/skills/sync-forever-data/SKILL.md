---
name: sync-forever-data
description: Re-sync the addon's game data with WoW Forever. It pulls the latest QuestieDB (drops, vendors, quests, NPCs, objects, with QuestieDB's corrections) and rebuilds the Library's recipes from Forever's own client tables. It then rebuilds LibraryData.lua and checks the IDs and names hardcoded in the code (Tasks, Vibration, Gather) against Forever. Use when the user asks to sync, update or refresh the data, says a Library entry is missing or doesn't match the game, mentions a new Forever patch or QuestieDB update, or asks "is our data up to date".
---

# Sync Forever data

Every bundled data file and hardcoded game ID must match **WoW Forever**, not Classic
Era. Forever's client reports itself as 1.60.x (product `wow_classic_beta`). It has
changed recipes, spells and items: for example, healing potions are First Aid
recipes there, not Alchemy.

## Run it

```sh
python3 tools/sync_forever_data.py            # pull QuestieDB, rebuild everything, check
python3 tools/sync_forever_data.py --no-pull  # rebuild from the QuestieDB we have
python3 tools/sync_forever_data.py --check    # only the checks
```

It exits 2 when a hardcoded ID needs a look. It does:

1. **QuestieDB → latest** (`git submodule update --remote vendor/QuestieDB`).
2. **Recipes** (`tools/make_library.py`):
   - `LibraryRecipes.lua` from wago.tools DB2 CSVs of Forever's own build. wago lists
     Forever under the product key `wow_cn_beta`, so `forever_build()` picks the
     highest 1.16+ version from any product.
3. **Library data** (`tools/make_library_data.py` → `LibraryData.lua`):
   - QuestieDB's Forever data with its corrections: its exporter
     `tools/export-forever.lua --include-authored` writes
     `vendor/QuestieDB/src/corrections/Forever/combined/`.
   - It needs Lua 5.1, because LuaJIT can't load the largest tables. The script
     finds `LUA51`/`lua5.1`, or builds Lua 5.1.5 once into the gitignored
     `tools/.lua51/` (checksum verified).
   - Trainers and portrait models come from cMaNGOS. Its teaching spells link to
     recipes only through Classic Era's SpellEffect.
   - Forever-only trainer recipes are assigned to their profession's trainers.
4. **Hardcoded data checks**:
   - `Tasks.lua` `SEED_VENDOR`: each item exists and a Forever vendor sells it.
   - `Vibration.lua` `V.MOVES` and gathering spells: each ID is in Forever's
     SpellName.
   - `NodeScan.lua` `HERBS`/`ORES`: no Forever herb or ore node is missing.
5. **Lua checks**: data files compile, and `tools/loadcheck.lua each` passes.

## After it runs

- **Fix each `!` line it prints:**
  - Drop IDs Forever doesn't have.
  - Find the Forever replacement by name in the build's `SpellName` / ItemSparse /
    QuestieDB data. Forever renames some spells, e.g. Curse of Agony → Bane of Agony.
  - Add missing nodes with their skill rank.
  - Then rerun with `--check`.
- **Spot-check what the user reported**, e.g. the item's row in
  `LibraryRecipes.lua` / `LibraryData.lua`.
- **Report:** the QuestieDB commit move, the build used, the counts it printed
  (recipes, items, NPCs, quests, trainers) against the previous run, and anything
  still unresolved.
- **Don't commit** unless asked. The changed files are `ImprovedForever_Library/
  LibraryRecipes.lua`, `LibraryData.lua`, and the `vendor/QuestieDB` pointer.

## When a generator breaks

- **Forever's DB2 column names differ from Era's.** Already handled:
  - SpellEffect's created count is `EffectBasePointsF`.
  - Item use effects go through `ItemXItemEffect` (ItemID → ItemEffectID).
  - A recipe item's effect with TriggerType 6 *is* the recipe spell.
- **On a new KeyError:** fetch the table's header
  (`https://wago.tools/db2/<Table>/csv?build=<build>`) and map the new name.
- **If QuestieDB's exporter changes** (path or flags), read
  `vendor/QuestieDB/tools/export-forever.lua` and `docs/forever-data.md`.
