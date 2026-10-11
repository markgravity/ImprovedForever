"""Sync the addon's game data with WoW Forever, and check what's hardcoded.

1. QuestieDB (vendor/QuestieDB) moved to its latest master: drops, vendors,
   quests, NPCs and objects for Forever, with its corrections (its own
   exporter, tools/export-forever.lua, run with a Lua 5.1).
2. RecipeData.lua (core) rebuilt from Forever's own client tables on wago.tools
   (tools/make_library.py: the newest 1.16+ build, whatever product it's
   listed under).
3. WorldData.lua (core) rebuilt (tools/make_library_data.py).
4. The IDs and names written into the code checked against Forever's data:
   Tasks' vendor reagents, Vibration's spells (moves, food and drink),
   Gather's node names.
5. The Lua checks: syntax of the data files, tools/loadcheck.lua.

A Lua 5.1 is needed for step 1 (LuaJIT can't load QuestieDB's largest
tables): LUA51=path, else lua5.1 on the PATH, else Lua 5.1.5 is built once
from lua.org's source (checksum verified) into tools/.lua51/.

Usage:
    python tools/sync_forever_data.py            # everything
    python tools/sync_forever_data.py --no-pull  # keep QuestieDB where it is
    python tools/sync_forever_data.py --check    # only the checks (step 4, 5)
"""
import csv
import hashlib
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
QDB = ROOT / "vendor" / "QuestieDB"
LUA_CACHE = TOOLS / ".lua51"
LUA_URL = "https://www.lua.org/ftp/lua-5.1.5.tar.gz"
LUA_SHA256 = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"

sys.path.insert(0, str(TOOLS))


def step(text):
    print(f"\n== {text}", flush=True)


def run(cmd, cwd=ROOT, env=None):
    print("$ " + " ".join(str(c) for c in cmd), flush=True)
    done = subprocess.run(cmd, cwd=cwd, env=env)
    if done.returncode != 0:
        raise SystemExit(f"failed: {' '.join(str(c) for c in cmd)}")


def is_lua51(path):
    if not path:
        return False
    out = subprocess.run([path, "-v"], capture_output=True, text=True)
    return "Lua 5.1" in out.stdout + out.stderr


def lua51():
    """A Lua 5.1 interpreter: LUA51, lua5.1, or one built into tools/.lua51"""
    for candidate in (os.environ.get("LUA51"), shutil.which("lua5.1"), shutil.which("lua"),
                      str(LUA_CACHE / "lua-5.1.5" / "src" / "lua")):
        if candidate and Path(candidate).exists() and is_lua51(candidate):
            return candidate
    print("building Lua 5.1.5 from lua.org into tools/.lua51 (once)")
    LUA_CACHE.mkdir(exist_ok=True)
    req = urllib.request.Request(LUA_URL, headers={"User-Agent": "ImprovedForever-tools"})
    data = urllib.request.urlopen(req, timeout=120).read()
    if hashlib.sha256(data).hexdigest() != LUA_SHA256:
        raise SystemExit("lua-5.1.5.tar.gz checksum mismatch: not built")
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(LUA_CACHE)
    target = "macosx" if sys.platform == "darwin" else "linux"
    subprocess.run(["make", target], cwd=LUA_CACHE / "lua-5.1.5", capture_output=True)
    built = str(LUA_CACHE / "lua-5.1.5" / "src" / "lua")
    if not is_lua51(built):
        raise SystemExit("could not build Lua 5.1: set LUA51 to a Lua 5.1 interpreter")
    return built


def pull_questiedb():
    before = subprocess.run(["git", "-C", str(QDB), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    run(["git", "submodule", "update", "--init", "--remote", "vendor/QuestieDB"])
    after = subprocess.run(["git", "-C", str(QDB), "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True).stdout.strip()
    print(f"QuestieDB {before or '?'} -> {after}")


# ---------------------------------------------------------------------------
# The checks: what the code names, against Forever's data
# ---------------------------------------------------------------------------
def forever_spell_names():
    import make_library
    build = make_library.forever_build()
    rows = make_library.table("SpellName", build)
    return build, {int(r["ID"]): r["Name_lang"] for r in rows}


def lua_ids(text):
    return [int(x) for x in re.findall(r"\b(\d+)\b", re.sub(r"--[^\n]*", "", text))]


def check_code():
    import make_library_data as data
    problems = []
    items, objects = data.combined("Item"), data.combined("Object")

    # Tasks: the reagents it takes as sold by vendors
    src = (ROOT / "ImprovedForever_Auction" / "Tasks.lua").read_text()
    block = re.search(r"SEED_VENDOR = \{(.*?)\n\}", src, re.S)
    for iid in lua_ids(block.group(1)) if block else []:
        row = items.get(iid)
        if not row:
            problems.append(f"Tasks.lua SEED_VENDOR: item {iid} isn't in Forever's data")
        elif not data.as_list(row.get(14)):
            problems.append(f"Tasks.lua SEED_VENDOR: {row.get(1)} ({iid}) has no Forever vendor")

    # Vibration: the spells each move matches, food and drink, and the gathering spells
    build, names = forever_spell_names()
    src = (ROOT / "ImprovedForever_Vibration" / "Vibration.lua").read_text()
    moves = re.search(r"V\.MOVES = \{(.*?)\n\}", src, re.S)
    for key, body in re.findall(r"(\w+) = \{([^}]*)\}", moves.group(1) if moves else ""):
        for sid in lua_ids(body):
            if sid not in names:
                problems.append(f"Vibration.lua V.MOVES.{key}: spell {sid} isn't in Forever ({build})")
    rest = re.search(r"local REST_SPELLS = \{(.*?)\n\}", src, re.S)
    for key, body in re.findall(r"(\w+) = \{([^}]*)\}", rest.group(1) if rest else ""):
        for sid in lua_ids(body):
            if sid not in names:
                problems.append(f"Vibration.lua REST_SPELLS.{key}: spell {sid} isn't in Forever ({build})")
    for sid in (int(x) for x in re.findall(r"spell = (\d+)", src)):
        if sid not in names:
            problems.append(f"Vibration.lua: spell {sid} isn't in Forever ({build})")

    # Gather: herb and ore nodes Forever has that NodeScan doesn't know
    src = (ROOT / "ImprovedForever_Gather" / "NodeScan.lua").read_text()
    known = set()
    for table in ("HERBS", "ORES"):
        m = re.search(r"local " + table + r" = \{(.*?)\n\}", src, re.S)
        known |= set(re.findall(r'\["([^"]+)"\]', m.group(1) if m else ""))
    for iid, row in items.items():
        if (row.get(12), row.get(13)) not in ((7, 9), (7, 7)):     # herbs, metal & stone
            continue
        for oid in data.as_list(row.get(3)):
            name = (objects.get(oid) or {}).get(1)
            if name and name not in known and not re.search(r"Chest|Strongbox|Crate|Granite", name):
                problems.append(f"NodeScan.lua: Forever node {name!r} (drops {row.get(1)}) isn't in HERBS / ORES")
                known.add(name)
    return problems


def check_lua():
    for f in ("ImprovedForever/RecipeData.lua", "ImprovedForever/WorldData.lua"):
        run(["luajit", "-bl", f, "/dev/null"])
    run(["luajit", "tools/loadcheck.lua", "each"])


def main():
    args = set(sys.argv[1:])
    check_only = "--check" in args
    if not check_only:
        env = dict(os.environ, LUA51=lua51())
        if "--no-pull" not in args:
            step("QuestieDB: latest")
            pull_questiedb()
        step("Recipes: Forever's client tables")
        run([sys.executable, "tools/make_library.py"], env=env)
        step("Library data: QuestieDB with its corrections, trainers, portraits")
        run([sys.executable, "tools/make_library_data.py"], env=env)
    step("Hardcoded data against Forever's")
    problems = check_code()
    for p in problems:
        print("  ! " + p)
    print(f"{len(problems)} to look at" if problems else "all found in Forever's data")
    step("Lua checks")
    check_lua()
    step("Changed")
    run(["git", "status", "--short", "--", "ImprovedForever/RecipeData.lua", "ImprovedForever/WorldData.lua", "vendor"])
    if problems:
        sys.exit(2)


if __name__ == "__main__":
    main()
