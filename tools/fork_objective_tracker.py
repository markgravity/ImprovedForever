"""Forks the game's objective tracker (Blizzard_ObjectiveTracker, WoW Forever's
own UI source) into ImprovedForever_QuestTracker/Tracker, so the Quest Tracker
module draws its own copy of it: the same templates, art, fonts, layout and
animations, the same modules (quests, achievements, recipes, scenarios...),
none of it touching the game's.

Every global the tracker defines (mixins, templates, frames, constants) is
renamed with an "IF" prefix ("IF_" for CONSTANTS), so ours and the game's sit
side by side. The fonts stay the game's (Edit Mode's text size changes them).
A few lines are changed (PATCHES): the frame isn't one of the game's managed
or Edit Mode frames (ours is placed over the game's, Tracker/Patch*.lua), and
the context menus and the gamepad's close go through ours (the game's Menu
and frame manager can't be driven from addon code without taint).

Usage (from the repo's root):
  python3 tools/fork_objective_tracker.py [path to wow-ui-source-forever]
Without a path, the source is cloned (sparse) into ~/.cache. Rerun after a
client update, then check the diff: the rest of the module builds on these
files (Tracker/PatchEarly.lua, Tracker/Patch.lua) by name.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ImprovedForever_QuestTracker" / "Tracker"
REPO = "https://github.com/Ketho/wow-ui-source-forever"
SUB = "Interface/AddOns/Blizzard_ObjectiveTracker"
# The game's quest object (QuestMixin is local to it): copied for our own
# quest cache (IFQuestCache), so ours never fills the game's QuestCache
QUEST = "Interface/AddOns/Blizzard_ObjectAPI/Mainline/Quest.lua"
# Not copied: the fonts are the game's own (ObjectiveTrackerLineFont...)
SKIP = {"Blizzard_ObjectiveTrackerFonts.xml"}

HEADER = ("-- Forked from WoW Forever's Blizzard_ObjectiveTracker/{name} by\n"
          "-- tools/fork_objective_tracker.py: don't edit, rerun the script.\n")
XML_HEADER = ("<!-- Forked from WoW Forever's Blizzard_ObjectiveTracker/{name} by\n"
              "     tools/fork_objective_tracker.py: don't edit, rerun the script. -->\n")

# (file, old, new): applied after the renaming, each must match
PATCHES = [
    # Not a managed / Edit Mode frame: ours sits over the game's (Patch.lua)
    ("Blizzard_ObjectiveTracker.xml",
     'inherits="RightManagedFrameTemplate, EditModeObjectiveTrackerSystemTemplate, IFObjectiveTrackerContainerTemplate"',
     'inherits="IFObjectiveTrackerContainerTemplate"'),
    ("Blizzard_ObjectiveTracker.xml", ' roleset="objectives"', ''),
    ("Blizzard_ObjectiveTrackerContainer.lua", "\tManagedFrameMixin.OnShow(self);\n", ""),
    ("Blizzard_ObjectiveTrackerContainer.lua",
     "\t\tif EditModeManagerFrame:IsEditModeActive() then",
     "\t\tif EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then"),
    # No Maw on Forever, and its buff check reads the player's auras, secret
    # (in combat) to addon code: ours never shows the Maw block
    ("Blizzard_ScenarioObjectiveTracker.xml",
     '<Button parentKey="Container" inherits="MawBuffsContainer">', '<Button parentKey="Container">'),
    # Never the game's EventRegistry for frame events (EventUtil's waiters,
    # RegisterFrameEventAndCallback): it counts registrations in attributes
    # of one shared frame, ours would write them, and the game's own
    # tracker, set up by such a waiter, then runs tainted. Ours waits on its
    # own frame (Core.lua: IFObjectiveTrackerAfterLoad).
    ("Blizzard_ObjectiveTrackerManager.lua",
     'EventUtil.ContinueAfterAllEvents(GenerateClosure(IFObjectiveTrackerManager.Init, IFObjectiveTrackerManager), "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED");',
     'IFObjectiveTrackerAfterLoad(GenerateClosure(IFObjectiveTrackerManager.Init, IFObjectiveTrackerManager));'),
    ("Blizzard_ObjectiveTrackerManager.lua",
     'EventRegistry:RegisterFrameEventAndCallback("VARIABLES_LOADED", self.OnVariablesLoaded, self);',
     'IFObjectiveTrackerAfterLoad(GenerateClosure(self.OnVariablesLoaded, self));'),
]
# Everywhere: the game's menu and frame manager swapped for ours (Menu.lua, Pad.lua)
EVERYWHERE = [
    ("MenuUtil.CreateContextMenu(", "IFObjectiveTrackerMenu.CreateContextMenu("),
    ("GamepadMode.FrameControlsManager:FrameHidden(", "IFObjectiveTrackerPad.FrameHidden("),
    ("ShouldShowMawBuffs()", "false --[[ ShouldShowMawBuffs(): no Maw, auras secret ]]"),
    # The game's shared caches (QuestCache's quest objects, QuestUtil's group
    # cache): the first caller fills them, so ours would leave tainted
    # entries the game's tracker then reads, tainting its gamepad focus.
    # Ours keeps its own (Blizzard_Quest.lua, Core.lua).
    ("QuestCache:Get(", "IFQuestCache:Get("),
    ("QuestUtil.CanCreateQuestGroup(", "IFCanCreateQuestGroup("),
]


def source(arg):
    if arg:
        return Path(arg).expanduser()
    cache = Path.home() / ".cache" / "wow-ui-source-forever"
    if not cache.exists():
        subprocess.run(["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", REPO, str(cache)], check=True)
        subprocess.run(["git", "-C", str(cache), "sparse-checkout", "set", SUB, str(Path(QUEST).parent)], check=True)
    else:
        subprocess.run(["git", "-C", str(cache), "pull", "--ff-only"], check=True)
    return cache


def toc_files(src):
    """The tracker's files in its TOC's order, Forever's [Game] overrides included"""
    files = []
    for line in (src / "Blizzard_ObjectiveTracker.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name = line.split(" [Allow")[0].strip()
        if name.startswith("[Game]/"):
            if "camelot" not in line:
                continue
            name = "Camelot/" + name[len("[Game]/"):]
        if Path(name).name not in SKIP:
            files.append(name)
    return files


def defined_names(texts):
    names = set()
    for path, text in texts.items():
        if path.endswith(".lua"):
            names.update(re.findall(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", text, re.M))
            names.update(re.findall(r"^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M))
        else:
            names.update(n for n in re.findall(r'\bname="([A-Za-z_][A-Za-z0-9_-]*)"', text))
    return names


def renamed(name):
    return ("IF_" if re.match(r"^[A-Z0-9_]+$", name) else "IF") + name


def main():
    root = source(sys.argv[1] if len(sys.argv) > 1 else None)
    src = root / SUB
    files = toc_files(src)
    texts = {f: (src / f).read_text(encoding="utf-8") for f in files}
    names = defined_names(texts)
    # (plain names everywhere; a hyphenated one, a virtual texture's, only
    # where XML names or inherits it: the same words are file paths too)
    plain = sorted((n for n in names if "-" not in n), key=len, reverse=True)
    hyphenated = sorted((n for n in names if "-" in n), key=len, reverse=True)
    pattern = re.compile(r"(?<![A-Za-z0-9_.$:-])(" + "|".join(map(re.escape, plain)) + r")(?![A-Za-z0-9_-])")
    hyphen_pattern = re.compile(r"(?<![A-Za-z0-9_.$:-])(" + "|".join(map(re.escape, hyphenated)) + r")(?![A-Za-z0-9_-])")

    def rename_attrs(text):
        def attr(m):
            return m.group(1) + hyphen_pattern.sub(lambda n: renamed(n.group(1)), m.group(2)) + '"'
        return re.sub(r'(\b(?:name|inherits)=")([^"]*)"', attr, text) if hyphenated else text

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("Blizzard_*"):
        old.unlink()
    written = []
    for f, text in texts.items():
        text = pattern.sub(lambda m: renamed(m.group(1)), text)
        if f.endswith(".xml"):
            text = rename_attrs(text)
        for old, new in EVERYWHERE:
            text = text.replace(old, new)
        for target, old, new in PATCHES:
            if target == Path(f).name:
                if old not in text:
                    sys.exit(f"{f}: patch no longer matches: {old!r}")
                text = text.replace(old, new)
        out_name = Path(f).name
        if f.endswith(".lua"):
            text = HEADER.format(name=f) + text
        else:
            text = re.sub(r"^(<Ui[^>]*>)", lambda m: m.group(1) + "\n" + XML_HEADER.format(name=f).rstrip(), text, count=1)
        (OUT / out_name).write_text(text, encoding="utf-8")
        written.append(out_name)
    quest = (root / QUEST).read_text(encoding="utf-8")
    if "QuestCache = ObjectCache_Create(QuestMixin);" not in quest:
        sys.exit("Quest.lua: QuestCache line no longer matches")
    quest = quest.replace("QuestCache = ObjectCache_Create(QuestMixin);", "IFQuestCache = ObjectCache_Create(QuestMixin);")
    # The game's QuestEventListener: one shared callback list per quest, run
    # one after the other on QUEST_DATA_LOAD_RESULT. With ours in a list,
    # the game's callbacks after it run tainted (they fill the game's quest
    # objects, which its tracker reads: its gamepad focus tainted). Ours has
    # its own listener (Core.lua).
    if "QuestEventListener:AddCallback(" not in quest:
        sys.exit("Quest.lua: QuestEventListener line no longer matches")
    quest = quest.replace("QuestEventListener:AddCallback(", "IFQuestEventListener:AddCallback(")
    (OUT / "Blizzard_Quest.lua").write_text(HEADER.replace("Blizzard_ObjectiveTracker/{name}", "{name}").format(name="Blizzard_ObjectAPI/Mainline/Quest.lua") + quest, encoding="utf-8")
    written.insert(0, "Blizzard_Quest.lua")
    print(f"{len(names)} names renamed, {len(written)} files in {OUT.relative_to(ROOT)}")
    print("TOC order:")
    for w in written:
        print("Tracker/" + w)


if __name__ == "__main__":
    main()
