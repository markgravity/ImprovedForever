"""Build WorldData.lua (core): the drops, vendors and quests, taken from
QuestieDB's Forever data (the vendor/QuestieDB submodule:
git submodule update --init) with its corrections applied: QuestieDB's own
exporter (tools/export-forever.lua, needs a Lua 5.1: LUA51=path) merges its
raw data with its Classic and Forever fixes.

Only what the Wiki shows is kept: for each item its sources (creatures,
objects and containers that drop it, vendors, quests); for each creature,
object and quest those name, its name, level, zone and a few spawn points.
Rows are strings, decoded in game only when an item's page opens (Wiki.lua),
so the data costs little memory until then. An installed QuestieDB is read
instead when there is one (newer data).

Row formats (fields split by "|", lists by ","):
    items[id]   = "npcDrops|objectDrops|itemDrops|vendors|questRewards|startQuest|relatedQuests"
                  (relatedQuests: QuestieDB's, and every quest naming the item in its
                   objectives or source items: what the item verdict keeps it for)
    npcs[id]    = "name|minLevel|maxLevel|rank|zoneID|subName|friendlyToFaction|spawns"
    objects[id] = "name|zoneID|spawns"
    quests[id]  = "name|questLevel|zoneOrSort|requiredLevel|startNpcs|startObjects|startItems|
                   endNpcs|endObjects|preQuests|nextQuest|objectives|requiredRaces|
                   requiredClasses|exclusiveTo"   (objectives: lines split by "~"; races and
                   classes: masks, 0 any; the quests before and after it in a chain kept too)
    spawns      = "zone:x,y,x,y;zone:x,y"   (at most SPAWNS_PER_ZONE points a zone)
    displays[npcID] = displayID              (the creature's look, for its portrait)
    trainerSets[n]  = "npcID,npcID,..."      (trainers, a list shared by recipes)
    trainers[spellID] = n                    (the trainers who teach a recipe)
    professionTrainers[skillLine] = n        (a profession's trainers: its first
                                              recipes come with the profession)
    trainerSkill[spellID] = rank             (the skill a trainer asks to teach it)
    trainerLevel[spellID] = level            (the level a trainer asks, when it does)
    starters[spellID] = 1                    (recipes learnt with the profession:
                                              SkillLineAbility's AcquireMethod 1)

The creatures' display ids and the trainers come from cMaNGOS's Classic
database (github.com/cmangos/classic-db, GPL-3.0): creature_template's
ModelId1-4, kept only when the client's own CreatureDisplayInfo table has
them, and npc_trainer / npc_trainer_template (through TrainerTemplateId). A
trainer teaches a spell that teaches the recipe (the client's SpellEffect,
LEARN_SPELL); the recipes are RecipeData.lua's. Recipes Forever adds
(none of cMaNGOS's trainers teach them) that no recipe item teaches and that
don't come with the profession are put down to the profession's trainers, at
the skill rank Forever's SkillLineAbility gives. Client tables from wago.tools,
Forever's own build (make_library.py's forever_build).

Usage:
    LUA51=/path/to/lua5.1 python tools/make_library_data.py
"""
import csv
import gzip
import io
import json
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QDB = ROOT / "vendor" / "QuestieDB"
OUT = ROOT / "ImprovedForever" / "WorldData.lua"
SPAWNS_PER_ZONE = 40
CMANGOS_DUMP = "https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
WAGO = "https://wago.tools"

# item / npc / object / quest field positions (QuestieDB's *Keys, 1-based)
ITEM = {"npcDrops": 2, "objectDrops": 3, "itemDrops": 4, "startQuest": 5, "questRewards": 6,
        "vendors": 14, "relatedQuests": 15}
NPC = {"name": 1, "minLevel": 4, "maxLevel": 5, "rank": 6, "spawns": 7, "zoneID": 9,
       "friendlyToFaction": 13, "subName": 14}
OBJECT = {"name": 1, "spawns": 4, "zoneID": 5}
QUEST = {"name": 1, "startedBy": 2, "finishedBy": 3, "requiredLevel": 4, "questLevel": 5, "requiredRaces": 6,
         "requiredClasses": 7, "objectivesText": 8, "objectives": 10, "sourceItemId": 11, "preQuestGroup": 12,
         "preQuestSingle": 13, "exclusiveTo": 16, "zoneOrSort": 17, "requiredSourceItems": 21,
         "nextQuestInChain": 22}


# ---------------------------------------------------------------------------
# A reader for the Lua table literals QuestieDB's data is written in
# ---------------------------------------------------------------------------
TOKEN = re.compile(r"""
    (?P<space>\s+|--[^\n]*)
  | (?P<num>-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)
  | (?P<str>'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")
  | (?P<word>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<sym>[{}\[\]=,;])
""", re.X)
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"'}


def tokens(text):
    pos = 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError(f"unexpected {text[pos:pos + 30]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "space":
            continue
        value = m.group(kind)
        if kind == "num":
            value = float(value) if any(c in value for c in ".eE") else int(value)
        elif kind == "str":
            value = re.sub(r"\\(.)", lambda e: ESCAPES.get(e.group(1), e.group(1)), value[1:-1])
        yield kind, value


class Reader:
    def __init__(self, text):
        self.toks = list(tokens(text))
        self.i = 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)

    def take(self, value=None):
        tok = self.toks[self.i]
        if value is not None and tok[1] != value:
            raise ValueError(f"expected {value!r}, got {tok!r}")
        self.i += 1
        return tok

    def value(self):
        kind, value = self.take()
        if kind == "sym" and value == "{":
            return self.table()
        if kind == "word":
            return {"nil": None, "true": True, "false": False}[value]
        return value

    # positional values keep their index (a nil holds its place)
    def table(self):
        out, n = {}, 0
        while self.peek()[1] != "}":
            kind, value = self.peek()
            if kind == "sym" and value == "[":
                self.take()
                key = self.value()
                self.take("]")
                self.take("=")
                out[key] = self.value()
            elif kind == "word" and self.toks[self.i + 1][1] == "=" and value not in ("nil", "true", "false"):
                self.take()
                self.take("=")
                out[value] = self.value()
            else:
                n += 1
                v = self.value()
                if v is not None:
                    out[n] = v
            if self.peek()[1] in (",", ";"):
                self.take()
        self.take("}")
        return out


def data_string(path, name):
    text = path.read_text(encoding="utf-8")
    m = re.search(re.escape(name) + r"\s*=\s*\[(=*)\[\s*return\s*(.*?)\]\1\]", text, re.S)
    if not m:
        raise ValueError(f"{name} not found in {path.name}")
    reader = Reader(m.group(2))
    reader.take("{")
    return reader.table()


COMBINED = QDB / "src" / "corrections" / "Forever" / "combined"


def export_forever():
    """QuestieDB's Forever data with its corrections applied: its raw data
    (data/Forever) is only the base; its fixes (the inherited Classic ones and
    Forever's own, src/corrections) are folded in by its own exporter,
    tools/export-forever.lua, run with a Lua 5.1 (LUA51=path, else lua5.1 /
    lua on the PATH when it is 5.1; LuaJIT can't load its biggest tables)."""
    import os
    import shutil
    lua = os.environ.get("LUA51") or shutil.which("lua5.1") or shutil.which("lua")
    if lua:
        out = subprocess.run([lua, "-v"], capture_output=True, text=True)
        if "5.1" not in (out.stdout + out.stderr):
            lua = None
    if lua:
        run = subprocess.run([lua, "tools/export-forever.lua", "--include-authored"], cwd=QDB,
                             capture_output=True, text=True)
        if run.returncode != 0:
            raise SystemExit("QuestieDB's export-forever.lua failed:\n" + run.stdout + run.stderr)
        print(run.stdout.strip().splitlines()[-1])
    elif not (COMBINED / "foreverNpcDB.lua").is_file():
        raise SystemExit("QuestieDB's corrections need its exporter: set LUA51 to a Lua 5.1 interpreter")
    else:
        print("QuestieDB export: no Lua 5.1 found, using the last export in " + str(COMBINED.relative_to(ROOT)))


def combined(name):
    """One merged entity table (name: Item, Npc, Object, Quest): rows written
    as `x[id]={...}`, one a line, positional with nil holes"""
    rows = {}
    for line in (COMBINED / f"forever{name}DB.lua").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\w+\[(\d+)\]=(\{.*\})\s*$", line)
        if m:
            reader = Reader(m.group(2))
            reader.take("{")
            rows[int(m.group(1))] = reader.table()
    return rows


def as_list(v):
    if v is None:
        return []
    if isinstance(v, dict):
        return [v[k] for k in sorted(k for k in v if isinstance(k, int))]
    return [v]


# ---------------------------------------------------------------------------
# Rows
# ---------------------------------------------------------------------------
def text(v):
    s = "" if v is None else str(v)
    if "|" in s or "\n" in s:
        s = s.replace("|", "/").replace("\n", " ")
    return s


def num(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return f"{v:.1f}".rstrip("0").rstrip(".")
    return str(v)


def ids(v):
    return ",".join(str(i) for i in as_list(v))


def spawns(v):
    parts = []
    for zone in sorted(k for k in (v or {}) if isinstance(k, int)):
        points = []
        for p in as_list(v[zone])[:SPAWNS_PER_ZONE]:
            xy = as_list(p)
            if len(xy) >= 2:
                points += [num(xy[0]), num(xy[1])]
        if points:
            parts.append(f"{zone}:" + ",".join(points))
    return ";".join(parts)


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# Creatures' looks: cMaNGOS's creature_template (Entry, ..., ModelId1-4 are
# its 1st and 6th-9th columns), checked against the client's display table
# ---------------------------------------------------------------------------
def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "ImprovedForever-tools"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def sql_rows(statement):
    """The value tuples of one INSERT statement, as lists of raw strings."""
    rows, row, field, quoted, i = [], None, [], False, statement.index("VALUES") + 6
    while i < len(statement):
        c = statement[i]
        if quoted:
            if c == "\\":
                field.append(statement[i + 1])
                i += 1
            elif c == "'":
                quoted = False
            else:
                field.append(c)
        elif c == "'":
            quoted = True
        elif c == "(":
            row, field = [], []
        elif c in ",)" and row is not None:
            row.append("".join(field).strip())
            field = []
            if c == ")":
                rows.append(row)
                row = None
        elif row is not None:
            field.append(c)
        i += 1
    return rows


_builds = {}


def wago_table(name, era=False):
    """A client table from Forever's build; era: from the latest Classic Era
    build (the vanilla spells cMaNGOS's trainers teach, gone from Forever's)"""
    key = "era" if era else "forever"
    if key not in _builds:
        if era:
            _builds[key] = json.loads(fetch(f"{WAGO}/api/builds"))["wow_classic_era"][0]["version"]
        else:
            from make_library import forever_build
            _builds[key] = forever_build()
        print(f"client tables ({key}): build {_builds[key]}")
    build = _builds[key]
    return list(csv.DictReader(io.StringIO(fetch(f"{WAGO}/db2/{name}/csv?build={build}").decode("utf-8"))))


def cmangos():
    """creature_template (entry -> row, its column names) and the trainers'
    rows, from the dump read once."""
    text = gzip.decompress(fetch(CMANGOS_DUMP)).decode("utf-8", errors="replace")
    create = re.search(r"CREATE TABLE `creature_template` \((.*?)\n\)", text, re.S).group(1)
    columns = re.findall(r"^\s+`(\w+)`", create, re.M)
    tables = {"creature_template": [], "npc_trainer": [], "npc_trainer_template": []}
    for line in text.splitlines():
        m = re.match(r"INSERT INTO `(\w+)`", line)
        if m and m.group(1) in tables:
            tables[m.group(1)] += sql_rows(line)
    creatures = {int(r[0]): r for r in tables["creature_template"]}
    return creatures, columns, tables["npc_trainer"], tables["npc_trainer_template"]


def displays(npc_ids, creatures):
    known = {int(r["ID"]) for r in wago_table("CreatureDisplayInfo")}
    found = {}
    for entry in npc_ids:
        row = creatures.get(entry)
        for model in (row[5:9] if row else ()):
            model = int(float(model or 0))
            if model > 0 and model in known:
                found[entry] = model
                break
    return found


def trainers(creatures, columns, own, shared):
    """recipe spell -> trainer npc ids, profession skill line -> trainer npc ids,
    recipe spell -> the skill rank trainers ask for it (the lowest), recipe spell ->
    the level they ask (the lowest)"""
    recipes = {}
    for spell, skill in re.findall(r"^\[(\d+)\]=\{(\d+),", (ROOT / "ImprovedForever" / "RecipeData.lua").read_text(), re.M):
        recipes[int(spell)] = int(skill)
    teaches = {}
    # (cMaNGOS's trainers teach vanilla's teaching spells: Classic Era's link
    # from them to the recipe, and Forever's own where it has one)
    for row in wago_table("SpellEffect", era=True) + wago_table("SpellEffect"):
        if row["Effect"] == "36" and int(row["EffectTriggerSpell"]) > 0:
            teaches.setdefault(int(row["SpellID"]), []).append(int(row["EffectTriggerSpell"]))
    templates = {}
    for row in shared:
        templates.setdefault(int(row[0]), []).append((int(row[1]), int(row[4] or 0), int(row[5] or 0)))
    template_col = columns.index("TrainerTemplateId")
    taught = {}
    for row in own:
        taught.setdefault(int(row[0]), []).append((int(row[1]), int(row[4] or 0), int(row[5] or 0)))
    for entry, row in creatures.items():
        template = int(row[template_col] or 0)
        if template in templates:
            taught.setdefault(entry, []).extend(templates[template])
    by_recipe, by_skill, rank, level = {}, {}, {}, {}
    for npc, spells in taught.items():
        for spell, needs, minimum in spells:
            for recipe in [spell] + teaches.get(spell, []):
                if recipe in recipes:
                    by_recipe.setdefault(recipe, set()).add(npc)
                    by_skill.setdefault(recipes[recipe], set()).add(npc)
                    rank[recipe] = min(rank.get(recipe, needs), needs)
                    level[recipe] = min(level.get(recipe, minimum), minimum)
    return by_recipe, by_skill, rank, level


def emit(name, rows):
    body = "\n".join(f"[{k}]={lua_string(rows[k])}," for k in sorted(rows))
    return f"{name} = {{\n{body}\n}},\n"


def main():
    if not (QDB / "data" / "Forever").is_dir():
        raise SystemExit("vendor/QuestieDB missing: git submodule update --init")
    export_forever()
    items, npcs, objects, quests = combined("Item"), combined("Npc"), combined("Object"), combined("Quest")

    # (the quests an item is for: its objectives' items, the items it hands
    # out or asks to be carried; QuestieDB's relatedQuests misses many)
    for_quests = {}
    for qid, row in quests.items():
        needed = [as_list(o)[0] for o in as_list((row.get(QUEST["objectives"]) or {}).get(3)) if as_list(o)]
        needed += as_list(row.get(QUEST["requiredSourceItems"])) + as_list(row.get(QUEST["sourceItemId"]))
        for iid in needed:
            if isinstance(iid, int) and iid > 0:
                for_quests.setdefault(iid, set()).add(qid)

    item_rows, want_npc, want_obj, want_quest = {}, set(), set(), set()
    for iid in set(items) | set(for_quests):
        row = items.get(iid) or {}
        f = {k: row.get(i) for k, i in ITEM.items()}
        related = sorted(set(as_list(f["relatedQuests"])) | for_quests.get(iid, set()))
        f["relatedQuests"] = {i + 1: q for i, q in enumerate(related)} if related else None
        if not any(f.values()):
            continue
        item_rows[iid] = "|".join([ids(f["npcDrops"]), ids(f["objectDrops"]), ids(f["itemDrops"]),
                                   ids(f["vendors"]), ids(f["questRewards"]), num(f["startQuest"]),
                                   ids(f["relatedQuests"])])
        want_npc.update(as_list(f["npcDrops"]) + as_list(f["vendors"]))
        want_obj.update(as_list(f["objectDrops"]))
        want_quest.update(as_list(f["questRewards"]) + as_list(f["relatedQuests"]))
        if f["startQuest"]:
            want_quest.add(f["startQuest"])

    # (a quest's chain: the quests before and after it, theirs too)
    todo = list(want_quest)
    while todo:
        row = quests.get(todo.pop())
        if not row:
            continue
        for q in as_list(row.get(QUEST["preQuestSingle"])) + as_list(row.get(QUEST["preQuestGroup"])) \
                + as_list(row.get(QUEST["nextQuestInChain"])):
            if q and q not in want_quest:
                want_quest.add(q)
                todo.append(q)
    # (who gives and takes them)
    for qid in want_quest:
        row = quests.get(qid) or {}
        start, finish = row.get(QUEST["startedBy"]) or {}, row.get(QUEST["finishedBy"]) or {}
        want_npc.update(as_list(start.get(1)) + as_list(finish.get(1)))
        want_obj.update(as_list(start.get(2)) + as_list(finish.get(2)))

    creatures, columns, own, shared = cmangos()
    by_recipe, by_skill, ranks, levels = trainers(creatures, columns, own, shared)
    abilities = wago_table("SkillLineAbility")
    starter_spells = {int(r["Spell"]) for r in abilities if r["AcquireMethod"] == "1"}
    # (Forever's own recipes: its trainers, by the profession)
    added = 0
    by_item = {int(m[0]): (int(m[1]), int(m[2])) for m in re.findall(
        r"^\[(\d+)\]=\{(\d+),\d+,\d+,(\d+)", (ROOT / "ImprovedForever" / "RecipeData.lua").read_text(), re.M)}
    for r in abilities:
        spell = int(r["Spell"])
        recipe = by_item.get(spell)
        if not recipe or spell in by_recipe or spell in starter_spells or recipe[1] or r["AcquireMethod"] != "0":
            continue
        npcs_ = by_skill.get(recipe[0])
        if not npcs_:
            continue
        by_recipe[spell] = set(npcs_)
        rank = int(r["MinSkillLineRank"] or 0)
        if rank > 0:
            ranks[spell] = rank
        added += 1
    print(f"{added} recipes put down to their profession's trainers")
    for npcs_ in list(by_recipe.values()) + list(by_skill.values()):
        want_npc.update(npcs_)

    npc_rows = {}
    for nid in want_npc:
        row = npcs.get(nid)
        if row:
            npc_rows[nid] = "|".join([text(row.get(NPC["name"])), num(row.get(NPC["minLevel"])),
                                      num(row.get(NPC["maxLevel"])), num(row.get(NPC["rank"])),
                                      num(row.get(NPC["zoneID"])), text(row.get(NPC["subName"])),
                                      text(row.get(NPC["friendlyToFaction"])), spawns(row.get(NPC["spawns"]))])
    obj_rows = {}
    for oid in want_obj:
        row = objects.get(oid)
        if row:
            obj_rows[oid] = "|".join([text(row.get(OBJECT["name"])), num(row.get(OBJECT["zoneID"])),
                                      spawns(row.get(OBJECT["spawns"]))])
    quest_rows = {}
    for qid in want_quest:
        row = quests.get(qid)
        if row:
            start, finish = row.get(QUEST["startedBy"]) or {}, row.get(QUEST["finishedBy"]) or {}
            objectives = " ~ ".join(text(t) for t in as_list(row.get(QUEST["objectivesText"])) if t)
            quest_rows[qid] = "|".join([text(row.get(QUEST["name"])), num(row.get(QUEST["questLevel"])),
                                        num(row.get(QUEST["zoneOrSort"])), num(row.get(QUEST["requiredLevel"])),
                                        ids(start.get(1)), ids(start.get(2)), ids(start.get(3)),
                                        ids(finish.get(1)), ids(finish.get(2)),
                                        ",".join(str(q) for q in as_list(row.get(QUEST["preQuestSingle"]))
                                                 + as_list(row.get(QUEST["preQuestGroup"]))),
                                        num(row.get(QUEST["nextQuestInChain"])), objectives.replace("~ ~", "~"),
                                        num(row.get(QUEST["requiredRaces"])), num(row.get(QUEST["requiredClasses"])),
                                        ids(row.get(QUEST["exclusiveTo"]))])

    # Zones: area id -> UiMap id (the base table, Forever's overrides on top)
    zones_file = QDB / "support" / "Forever" / "Zones" / "areaIdToUiMapId.lua"
    area_to_ui = {}
    for name in ("ZoneDB.private.areaIdToUiMapId", "ZoneDB.private.areaIdToUiMapIdOverride"):
        area_to_ui.update({k: v for k, v in data_string(zones_file, name).items() if isinstance(v, int)})

    version = re.search(r"^## Version:\s*(\S+)", (QDB / "QuestieDB.toc").read_text(encoding="utf-8"), re.M)
    commit = subprocess.run(["git", "-C", str(QDB), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    source = f"QuestieDB {version.group(1) if version else '?'} ({commit or '?'})"

    zones = ",".join(f"[{k}]={area_to_ui[k]}" for k in sorted(area_to_ui))
    looks = displays(set(npc_rows), creatures)
    # (trainers only those the NPC data has; a list kept once, shared)
    sets, set_index = [], {}
    def shared_set(npcs_):
        key = ",".join(str(n) for n in sorted(n for n in npcs_ if n in npc_rows))
        if not key:
            return None
        if key not in set_index:
            sets.append(key)
            set_index[key] = len(sets)
        return set_index[key]
    recipe_trainers = {r: shared_set(n) for r, n in by_recipe.items()}
    skill_trainers = {k: shared_set(n) for k, n in by_skill.items()}
    def table(rows):
        return ",".join(f"[{k}]={v}" for k, v in sorted(rows.items()) if v)
    looks_lua = ",".join(f"[{k}]={looks[k]}" for k in sorted(looks))
    OUT.write_text(
        "-- GENERATED by tools/make_library_data.py from QuestieDB's Forever data\n"
        "-- (github.com/Questie/QuestieDB, by the Questie team); creatures' display ids\n"
        "-- from cMaNGOS's Classic database (github.com/cmangos/classic-db, GPL-3.0).\n"
        "-- Do not edit by hand.\n"
        "local IF = ImprovedForever\n"
        f"IF.WorldData = {{ source = {lua_string(source)},\n"
        + emit("items", item_rows) + emit("npcs", npc_rows) + emit("objects", obj_rows)
        + emit("quests", quest_rows) + f"areaToUi = {{ {zones} }},\n"
        + f"displays = {{ {looks_lua} }},\n"
        + "trainerSets = {\n" + "\n".join(f"{lua_string(x)}," for x in sets) + "\n},\n"
        + f"trainers = {{ {table(recipe_trainers)} }},\n"
        + f"professionTrainers = {{ {table(skill_trainers)} }},\n"
        + f"trainerSkill = {{ {table(ranks)} }},\n"
        + f"trainerLevel = {{ {table(levels)} }},\n"
        + "starters = { " + ",".join(f"[{k}]=1" for k in sorted(starter_spells)) + " },\n}\n",
        encoding="utf-8",
    )
    size = OUT.stat().st_size / 1e6
    print(f"{source}: {len(item_rows)} items, {len(npc_rows)} npcs, {len(obj_rows)} objects, "
          f"{len(quest_rows)} quests, {len(area_to_ui)} zones, {len(looks)} looks, {sum(1 for v in recipe_trainers.values() if v)} recipes with trainers ({len(sets)} trainer lists) -> {OUT.name} ({size:.1f} MB)")


if __name__ == "__main__":
    main()
