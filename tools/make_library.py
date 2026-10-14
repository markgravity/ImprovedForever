"""Build RecipeData.lua (core): the profession recipe index the Wiki and the item verdict (ItemValue.lua) read.

Blizzard's DB2 tables (SkillLineAbility, SpellReagents, SpellEffect, ItemEffect)
come from wago.tools as CSV, from Forever's own build: the client reports itself
as 1.60.x (product wow_classic_beta; wago lists it under another product name,
so it's found by its version). Recipes newer than that build are learned in
game when a profession window opens (Wiki.lua LB.Learn).

Each recipe spell becomes one row:
    [spellID] = { skillLine, makesItemID, makesCount, taughtByItemID, reagentID, count, ... }

The tools spells need (SpellTotems: an item, or a tool category any fitting
item fills, TotemCategory's type and mask) are listed too, so a profession's
or a class's tool is never taken for junk (ItemValue.lua):
    tools = { [itemID] = { skillLine, ... } }, classTools = { [itemID] = classMask }

Usage:
    python tools/make_library.py [build]
"""
import csv
import io
import json
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ImprovedForever" / "RecipeData.lua"
API = "https://wago.tools"

PROFESSIONS = {
    164: "Blacksmithing", 165: "Leatherworking", 171: "Alchemy", 185: "Cooking",
    186: "Mining", 197: "Tailoring", 202: "Engineering", 333: "Enchanting",
    129: "First Aid",
    # (gathering: no recipes, but tools; and the character's professions by name)
    182: "Herbalism", 393: "Skinning", 356: "Fishing",
}
CREATE_ITEM, LEARN_SPELL = 24, 36


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "ImprovedForever-tools"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode("utf-8")


def table(name, build):
    text = fetch(f"{API}/db2/{name}/csv?build={build}")
    return list(csv.DictReader(io.StringIO(text)))


def forever_build():
    """The latest Forever build wago has: version 1.16 and up (Classic Era is
    1.15; Forever's client is 1.60.x), whichever product it's listed under."""
    builds = json.loads(fetch(f"{API}/api/builds"))
    versions = []
    for listed in builds.values():
        for b in listed:
            parts = [int(x) for x in b["version"].split(".")]
            if parts[0] == 1 and parts[1] >= 16:
                versions.append(parts)
    if not versions:
        raise SystemExit("no Forever build on wago.tools: pass one (python tools/make_library.py <build>)")
    return ".".join(map(str, max(versions)))


def find_tools(build):
    """The items spells need as tools: { item: [profession skill lines] } for
    the professions' spells, { item: class mask } for the classes' (a
    shaman's totems, a rogue's Thieves' Tools)"""
    line_of, class_of = {}, defaultdict(int)
    for row in table("SkillLineAbility", build):
        spell = int(row["Spell"])
        line_of.setdefault(spell, int(row["SkillLine"]))
        class_of[spell] |= int(row.get("ClassMask") or 0)
    cats = {int(r["ID"]): (int(r["TotemCategoryType"]), int(r["TotemCategoryMask"]))
            for r in table("TotemCategory", build)}
    item_cat = {}
    for row in table("ItemSparse", build):
        cat = int(row.get("TotemCategoryID") or 0)
        if cat:
            item_cat[int(row["ID"])] = cat

    def fill(required):
        """Every item filling a tool category: its own, or one of the same
        type whose mask holds it (a Gnomish Army Knife: knife, pick, hammer)"""
        want = cats.get(required)
        for item, cat in item_cat.items():
            have = cats.get(cat)
            if cat == required or (want and have and have[0] == want[0] and have[1] & want[1] == want[1]):
                yield item

    tools, class_tools = defaultdict(set), defaultdict(int)
    for row in table("SpellTotems", build):
        spell = int(row["SpellID"])
        items = [int(row[f"Totem_{i}"]) for i in range(2) if int(row[f"Totem_{i}"]) > 0]
        for i in range(2):
            required = int(row[f"RequiredTotemCategoryID_{i}"])
            if required > 0:
                items += list(fill(required))
        line, mask = line_of.get(spell), class_of.get(spell, 0)
        for item in items:
            if line in PROFESSIONS:
                tools[item].add(line)
            elif mask:
                class_tools[item] |= mask
    return tools, {i: m for i, m in class_tools.items() if i not in tools}


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else forever_build()
    print(f"build {build}")

    skill = {}
    for row in table("SkillLineAbility", build):
        line = int(row["SkillLine"])
        if line in PROFESSIONS:
            skill[int(row["Spell"])] = line

    reagents = {}
    for row in table("SpellReagents", build):
        spell = int(row["SpellID"])
        if spell not in skill:
            continue
        pairs = []
        for i in range(8):
            item, count = int(row[f"Reagent_{i}"]), int(row[f"ReagentCount_{i}"])
            if item > 0 and count > 0:
                pairs += [item, count]
        reagents[spell] = pairs

    makes, learns = {}, defaultdict(list)
    for row in table("SpellEffect", build):
        effect, spell = int(row["Effect"]), int(row["SpellID"])
        if effect == CREATE_ITEM and spell in skill and int(row["EffectItemType"]) > 0:
            if "EffectBasePointsF" in row:
                # (Forever's build: the count itself, as a float)
                count = round(float(row["EffectBasePointsF"] or 0))
            else:
                count = int(row["EffectBasePoints"]) + max(int(row["EffectDieSides"]), 1)
            makes[spell] = (int(row["EffectItemType"]), max(count, 1))
        elif effect == LEARN_SPELL and int(row["EffectTriggerSpell"]) > 0:
            learns[spell].append(int(row["EffectTriggerSpell"]))

    # (an item's use effects: on the effect itself in older builds, through
    # ItemXItemEffect in Forever's)
    effects = table("ItemEffect", build)
    pairs = []
    if effects and "ParentItemID" in effects[0]:
        pairs = [(int(row["ParentItemID"]), int(row["SpellID"])) for row in effects]
    else:
        spell_of = {int(row["ID"]): int(row["SpellID"]) for row in effects}
        for row in table("ItemXItemEffect", build):
            spell = spell_of.get(int(row["ItemEffectID"]))
            if spell:
                pairs.append((int(row["ItemID"]), spell))
    taught = {}
    for item, spell in sorted(pairs):
        # (a recipe item's effect: a spell that learns the recipe, or in
        # Forever's build the recipe itself, its trigger "learn")
        for recipe in tuple(learns.get(spell, ())) + ((spell,) if spell in skill else ()):
            if recipe in skill:
                taught.setdefault(recipe, item)

    tools, class_tools = find_tools(build)

    rows = []
    for spell in sorted(skill):
        if spell not in reagents and spell not in makes:
            continue
        make, count = makes.get(spell, (0, 0))
        fields = [skill[spell], make, count, taught.get(spell, 0)] + reagents.get(spell, [])
        rows.append(f"[{spell}]={{{','.join(map(str, fields))}}},")

    names = ", ".join(f"[{k}] = \"{v}\"" for k, v in sorted(PROFESSIONS.items()))
    OUT.write_text(
        "-- GENERATED by tools/make_library.py from Blizzard DB2 tables (wago.tools).\n"
        "-- Do not edit by hand. Row: { skillLine, makesItemID, makesCount, taughtByItemID,\n"
        "-- reagentID, count, reagentID, count, ... }\n"
        "local IF = ImprovedForever\n"
        f"IF.RecipeData = {{ build = \"{build}\",\n"
        f"skills = {{ {names} }},\n"
        "recipes = {\n" + "\n".join(rows) + "\n},\n"
        "tools = { " + ", ".join(f"[{i}] = {{ {', '.join(map(str, sorted(lines)))} }}"
                                 for i, lines in sorted(tools.items())) + " },\n"
        "classTools = { " + ", ".join(f"[{i}] = {mask}" for i, mask in sorted(class_tools.items())) + " },\n"
        "}\n",
        encoding="utf-8",
    )
    print(f"{len(rows)} recipes, {len(taught)} taught by items, {len(tools)} profession tools,"
          f" {len(class_tools)} class tools -> {OUT.name}")


if __name__ == "__main__":
    main()
