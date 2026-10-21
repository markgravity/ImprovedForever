"""Build the release zips, one per addon (each its own CurseForge project, and
each on its own version, its TOC's):
    dist/ImprovedForever-<version>.zip           the core
    dist/ImprovedForever_<Module>-<version>.zip  each module
    dist/ImprovedForever-All.zip                 every addon, for a manual install
                                                 (only when no addon is named)

Each addon folder holds what the game loads: its TOC and the files it lists,
its Bindings.xml, the licence; the core also the TGA textures (every module's
too), the EasyController licence, README and CHANGELOG. Tools, icon sources
and tpl.lua (a dev reference) are left out.

Usage:
    python tools/package.py              every addon, and the All zip
    python tools/package.py Wheel Core   only those (Core is the ImprovedForever folder)
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORE = "ImprovedForever"
CORE_EXTRA = ["LICENSE-EasyController.md", "README.md", "CHANGELOG.md"]


def toc_of(folder):
    toc = (ROOT / folder / f"{folder}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    return version, listed


def main():
    folders = sorted(p.parent.name for p in ROOT.glob(f"{CORE}*/{CORE}*.toc") if p.stem == p.parent.name)
    if CORE not in folders:
        sys.exit(f"No {CORE}/{CORE}.toc")

    wanted = set(folders)
    if sys.argv[1:]:
        by_name = {("Core" if f == CORE else f[len(CORE):].lstrip("_")).lower(): f for f in folders}
        unknown = [a for a in sys.argv[1:] if a.lower() not in by_name]
        if unknown:
            sys.exit("No addon named " + ", ".join(unknown))
        wanted = {by_name[a.lower()] for a in sys.argv[1:]}

    entries = {}      # folder: [(source, path in the zip)]
    versions = {}
    code = ""
    for folder in folders:
        ver, listed = toc_of(folder)
        versions[folder] = ver
        files = [f"{folder}.toc"] + listed
        if (ROOT / folder / "Bindings.xml").is_file():
            files.append("Bindings.xml")
        if folder == CORE:
            files += sorted(p.relative_to(ROOT / folder).as_posix() for p in (ROOT / folder / "textures").glob("*.tga"))
        # (a module's own fonts, with their licence)
        files += sorted(p.relative_to(ROOT / folder).as_posix() for p in (ROOT / folder / "Fonts").glob("*") if p.is_file())
        missing = [f for f in files if not (ROOT / folder / f).is_file()]
        if missing:
            sys.exit(f"{folder}: missing files: " + ", ".join(missing))
        entries[folder] = [(ROOT / folder / f, f"{folder}/{f}") for f in files] + [(ROOT / "LICENSE", f"{folder}/LICENSE")]
        code += "".join((ROOT / folder / f).read_text(encoding="utf-8") for f in listed if f.endswith(".lua"))
    entries[CORE] += [(ROOT / f, f"{CORE}/{f}") for f in CORE_EXTRA]

    # Every texture the code names in full must be packaged (they're the core's)
    names = set(re.findall(r'"(ic_[a-z0-9_]+)"', code))
    packaged = {Path(path).stem for _, path in entries[CORE] if "/textures/" in path}
    absent = sorted(n for n in names if n not in packaged and not n.endswith("_"))
    if absent:
        sys.exit("Textures used but not packaged: " + ", ".join(absent))

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    zips = {f"{folder}-{versions[folder]}": entries[folder] for folder in folders if folder in wanted}
    if wanted == set(folders):
        zips[f"{CORE}-All"] = [e for files in entries.values() for e in files]
    for name, files in zips.items():
        base = name.rsplit("-", 1)[0]
        for old in dist.glob(f"{base}-*.zip"):      # an older version of this addon's zip
            if old.stem[len(base) + 1:2 + len(base)].isdigit():
                old.unlink()
        out = dist / f"{name}.zip"
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            for source, path in files:
                z.write(source, path)
        print(f"{out.relative_to(ROOT)}: {len(files)} files, {out.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
