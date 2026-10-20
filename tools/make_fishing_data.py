"""Build FishingData.lua (the core's game data: the Wiki's fishing waters, the
Fishing module's book): what can be fished
where, the fishing pools and what they hold, the fishing events, the poles
and the lures.

What's caught is the server's, which no client table has: it comes from
cMaNGOS's Classic database (github.com/cmangos/classic-db, GPL-3.0), the
Classic loot Forever's servers started from (fishing_loot_template by zone or
subzone, its reference_loot_template entries followed; the fishing pools,
gameobject_template type 25, and their gameobject_loot_template; the events,
game_event and game_event_time; an item only in season, a loot row's
condition naming a game event). Every item is kept only when Forever's own
item table has it (WikiItems.lua, Forever's ItemSparse), its name and
quality Forever's; the zones' names are Forever's AreaTable's (wago.tools,
Forever's own build). The poles are Forever's own (WikiItems: weapons,
subclass fishing pole).

Rows (fields split by "|", lists by ","):
    items[id]  = "name|quality|kind"     kind: fish, junk (grey), treasure
                                          (containers, gear), other
    zones[id]  = "name|catches"           a zone (AreaTable, no parent)
    areas[id]  = "name|zoneID|catches"    a subzone with its own loot
    pools[id]  = "name|catches"
    catches    = "item:chance:event,..."  (chance in %, event: the game
                                          event it's caught in, 0 any)
    events[id] = "name|weekday|minutes|every"   (weekday 1 Sunday..7, its
                                          length and how often, in minutes)
    poles      = { id, ... }

Usage:
    python tools/make_fishing_data.py
"""
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_library_data import fetch, sql_rows, wago_table, CMANGOS_DUMP  # noqa: E402
import gzip  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ImprovedForever" / "FishingData.lua"
WIKI_ITEMS = ROOT / "ImprovedForever_Wiki" / "WikiItems.lua"
FISHING_HOLE = 25
CONDITION_GAME_EVENT = 12
EVENTS = re.compile(r"fish", re.I)


def forever_items():
    """id -> (name, quality, class, subclass) from WikiItems.lua"""
    items = {}
    for m in re.finditer(r'^\[(\d+)\]="(.*)",$', WIKI_ITEMS.read_text(), re.M):
        f = m.group(2).split("|")
        items[int(m.group(1))] = (f[0].replace('\\"', '"'), int(f[1]), int(f[4]), int(f[5]))
    return items


FISH = re.compile(r"fish|snapper|eel|squid|salmon|bass|lobster|mackerel|grouper|yellowtail|sagefish|"
                  r"blackmouth|frenzy|whitescale|nightfin|redgill|darkclaw|clam|crab|mightfish", re.I)


def kind(item):
    name, quality, cls, sub = item
    if quality == 0:
        return "junk"
    if cls in (0, 7) and FISH.search(name):
        return "fish"
    if cls in (1, 2, 4, 15) and not re.search(r"fish|snapper|eel|squid|salmon|bass|lobster|clam", name, re.I):
        return "treasure"
    if (cls == 0 and sub == 5) or (cls == 7 and sub in (8, 11)):
        return "fish"
    return "other"


def main():
    print("cMaNGOS dump...")
    text = gzip.decompress(fetch(CMANGOS_DUMP)).decode("utf-8", errors="replace")
    wanted = {"fishing_loot_template", "reference_loot_template", "gameobject_template",
              "gameobject_loot_template", "game_event", "game_event_time", "conditions"}
    tables = {t: [] for t in wanted}
    for line in text.splitlines():
        m = re.match(r"INSERT INTO `(\w+)`", line)
        if m and m.group(1) in wanted:
            tables[m.group(1)] += sql_rows(line)

    items = forever_items()
    # (a condition naming a game event: the event)
    event_of = {int(r[0]): int(r[2]) for r in tables["conditions"] if int(r[1]) == CONDITION_GAME_EVENT}

    def by_entry(rows):
        out = {}
        for r in rows:
            out.setdefault(int(r[0]), []).append(r)
        return out

    refs = by_entry(tables["reference_loot_template"])

    def resolve(rows, scale=1.0, event=0, seen=None):
        """[(item, chance %, event)], references followed, chances scaled"""
        seen = seen or set()
        out = []
        # (a group's rows with no chance share what its others leave of 100)
        left, empty = {}, {}
        for r in rows:
            group = int(r[3])
            if group:
                left[group] = left.get(group, 100.0) - float(r[2])
                if float(r[2]) == 0:
                    empty[group] = empty.get(group, 0) + 1
        for r in rows:
            item, chance, count, cond = int(r[1]), float(r[2]), int(r[4]), int(r[6])
            group = int(r[3])
            if chance == 0 and group and empty.get(group):
                chance = max(0.0, left[group]) / empty[group]
            ev = event_of.get(cond, event)
            if count < 0:
                ref = -count
                if ref in seen:
                    continue
                # (a reference's chance: its share of the rows under it)
                out += resolve(refs.get(ref, []), scale * (chance or 100) / 100, ev, seen | {ref})
            else:
                out.append((item, chance * scale, ev))
        return out

    def catches(rows):
        found = {}
        for item, chance, ev in resolve(rows):
            if item not in items:
                continue
            was = found.get(item)
            if not was or chance > was[0]:
                found[item] = (chance, ev)
        listed = sorted(found.items(), key=lambda kv: -kv[1][0])
        return ",".join(f"{i}:{c:.4g}:{e}" for i, (c, e) in listed), set(found)

    # The zones and subzones, Forever's names
    print("AreaTable...")
    areas = {}
    for r in wago_table("AreaTable"):
        areas[int(r["ID"])] = (r["AreaName_lang"], int(r["ParentAreaID"] or 0))

    def zone_of(area):
        seen = set()
        while area in areas and areas[area][1] and area not in seen:
            seen.add(area)
            area = areas[area][1]
        return area

    used = set()
    zones, subs = {}, {}
    for entry, rows in sorted(by_entry(tables["fishing_loot_template"]).items()):
        if entry == 0 or entry not in areas:
            continue
        text_, ids = catches(rows)
        if not ids:
            continue
        used |= ids
        name = areas[entry][0].replace("|", "/")
        top = zone_of(entry)
        if top == entry:
            zones[entry] = f"{name}|{text_}"
        else:
            subs[entry] = f"{name}|{top}|{text_}"
    # (a subzone's zone with no loot of its own: listed by name)
    for entry, row in subs.items():
        top = int(row.split("|")[1])
        if top not in zones and top in areas:
            zones[top] = f"{areas[top][0]}|"

    # The pools
    loot = by_entry(tables["gameobject_loot_template"])
    pools = {}
    for r in tables["gameobject_template"]:
        if int(r[1]) != FISHING_HOLE:
            continue
        lootid = int(r[9] or 0)
        text_, ids = catches(loot.get(lootid, []))
        if not ids:
            continue
        used |= ids
        pools[int(r[0])] = f"{r[3].replace('|', '/')}|{text_}"

    # The events
    times = {int(r[0]): r[1] for r in tables["game_event_time"]}
    events = {}
    for r in tables["game_event"]:
        entry, every, length, desc = int(r[0]), int(r[2]), int(r[3]), r[6]
        if not EVENTS.search(desc) or entry not in times:
            continue
        start = datetime.strptime(times[entry], "%Y-%m-%d %H:%M:%S")
        weekday = (start.isoweekday() % 7) + 1
        events[entry] = f"{desc.replace('|', '/')}|{weekday}|{length}|{every}"

    poles = sorted(i for i, it in items.items() if it[2] == 2 and it[3] == 20)
    used |= set(poles)

    def esc(s):
        return s.replace("\\", "\\\\").replace('"', '\\"')

    out = ["-- GENERATED by tools/make_fishing_data.py: what's caught where, the pools",
           "-- and the events from cMaNGOS's Classic database (github.com/cmangos/classic-db,",
           "-- GPL-3.0), the Classic loot Forever's servers started from; items, names and",
           "-- zones Forever's own (its ItemSparse and AreaTable). Do not edit by hand.",
           "local IF = ImprovedForever",
           "IF.FishingData = {",
           "items = {"]
    for i in sorted(used):
        it = items[i]
        out.append(f'[{i}]="{esc(it[0])}|{it[1]}|{kind(it)}",')
    out.append("},\nzones = {")
    out += [f'[{k}]="{esc(v)}",' for k, v in sorted(zones.items())]
    out.append("},\nareas = {")
    out += [f'[{k}]="{esc(v)}",' for k, v in sorted(subs.items())]
    out.append("},\npools = {")
    out += [f'[{k}]="{esc(v)}",' for k, v in sorted(pools.items())]
    out.append("},\nevents = {")
    out += [f'[{k}]="{esc(v)}",' for k, v in sorted(events.items())]
    out.append("},\npoles = { " + ", ".join(map(str, poles)) + " },\n}")
    OUT.write_text("\n".join(out) + "\n")
    print(f"{OUT}: {len(used)} items, {len(zones)} zones, {len(subs)} subzones, {len(pools)} pools, "
          f"{len(events)} events, {len(poles)} poles")


if __name__ == "__main__":
    main()
