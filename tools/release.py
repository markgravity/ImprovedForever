"""Release helpers, run by the GitHub workflow (.github/workflows/release.yml)
on every version tag (v0.2.0, v0.3.0-beta1...). Python standard library only.

    python tools/release.py check v1.0.0   the tag matches the TOC's version
    python tools/release.py notes          this version's CHANGELOG section
    python tools/release.py curseforge     upload each addon's zip to CurseForge

The version is the core's TOC's (ImprovedForever/ImprovedForever.toc); every
module's TOC must say the same. CurseForge needs CF_API_KEY: a GitHub secret
in CI, or a line in the local .env (git-ignored) when run by hand. Each addon
is its own CurseForge project: its ID from its TOC (## X-Curse-Project-ID; an
addon without one isn't uploaded), its slug from its folder (slug() below),
its TOC's Dependencies / OptionalDeps on our addons sent as the file's
relations. The game version comes from CF_GAME_VERSION (default 1.60.1, WoW
Forever) or CF_GAME_VERSION_ID.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "ImprovedForever"
API = "https://wow.curseforge.com/api"


def load_env():
    """Fill missing environment variables from a local, git-ignored .env (KEY=value lines)."""
    env = ROOT / ".env"
    if not env.is_file():
        return
    for line in env.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition("=")
        if sep and not key.strip().startswith("#"):
            os.environ.setdefault(key.strip(), value.strip().strip("'\""))


load_env()


def toc_field(name, folder=ADDON):
    toc = (ROOT / folder / f"{folder}.toc").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(name)}:\s*(.+?)\s*$", toc, re.M)
    return match and match.group(1)


def version():
    return toc_field("Version")


def module_versions():
    """Each addon folder's TOC version: {folder: version}"""
    found = {}
    for toc in sorted(ROOT.glob(f"{ADDON}*/{ADDON}*.toc")):
        match = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8"), re.M)
        found[toc.parent.name] = match and match.group(1)
    return found


def notes(ver=None):
    """The CHANGELOG section of a version, without its title."""
    ver = ver or version()
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(ver)}(?=\s|$).*?$\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        sys.exit(f"CHANGELOG.md has no '## {ver}' section")
    return match.group(1).strip() + "\n"


def release_type(ver):
    if "alpha" in ver:
        return "alpha"
    if "beta" in ver or "-" in ver:
        return "beta"
    return "release"


class RequestError(Exception):
    pass


def request(url, token, data=None, headers=None, fail=True):
    """The JSON response; on an HTTP error, exit (or raise RequestError if fail is False)"""
    req = urllib.request.Request(url, data=data, headers={"X-Api-Token": token, **(headers or {})})
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as error:
        message = f"{url}: HTTP {error.code} {error.read().decode('utf-8', 'replace')}"
        if fail:
            sys.exit(message)
        raise RequestError(message)


def game_version_id(token):
    if os.environ.get("CF_GAME_VERSION_ID"):
        return int(os.environ["CF_GAME_VERSION_ID"])
    wanted = os.environ.get("CF_GAME_VERSION") or "1.60.1"
    versions = request(f"{API}/game/versions", token)
    found = [v for v in versions if v.get("name") == wanted]
    if not found:
        close = sorted({v.get("name") for v in versions if str(v.get("name", "")).startswith(wanted.split(".")[0] + ".")})
        sys.exit(f"No CurseForge game version named {wanted}. Close ones: {', '.join(close[-20:])}\n"
                 "Set the CF_GAME_VERSION (or CF_GAME_VERSION_ID) repository variable.")
    if len(found) > 1:
        print("Several game versions named", wanted, [(v["id"], v.get("gameVersionTypeID")) for v in found])
    return found[-1]["id"]


def slug(folder):
    """The CurseForge slug of an addon of ours: improved-forever,
    improved-forever-quest-tracker..."""
    module = folder[len(ADDON):].lstrip("_")
    words = re.findall(r"[A-Z][a-z]*", module)
    return "-".join(["improved", "forever"] + [w.lower() for w in words])


def relations(folder):
    """The file's relations: the TOC's Dependencies / OptionalDeps on our own addons"""
    found = []
    for field, kind in (("Dependencies", "requiredDependency"), ("OptionalDeps", "optionalDependency")):
        for dep in (toc_field(field, folder) or "").split(","):
            dep = dep.strip()
            if dep.startswith(ADDON) and (ROOT / dep / f"{dep}.toc").is_file():
                found.append({"slug": slug(dep), "type": kind})
    return found


def upload(folder, token, game_version):
    ver = version()
    project = toc_field("X-Curse-Project-ID", folder)
    if not project:
        print(f"CurseForge: {folder} has no '## X-Curse-Project-ID', not uploaded")
        return
    zip_path = ROOT / "dist" / f"{folder}-{ver}.zip"
    if not zip_path.is_file():
        sys.exit(f"{zip_path} is missing: run tools/package.py first")

    metadata = {
        "changelog": notes(ver),
        "changelogType": "markdown",
        "displayName": f"{toc_field('Title', folder)} {ver}",
        "releaseType": release_type(ver),
        "gameVersions": [game_version],
    }
    if relations(folder):
        metadata["relations"] = {"projects": relations(folder)}

    def send(metadata, fail):
        boundary = uuid.uuid4().hex
        body = b"".join([
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".encode(),
            json.dumps(metadata).encode("utf-8"),
            f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{zip_path.name}\"\r\n"
            "Content-Type: application/zip\r\n\r\n".encode(),
            zip_path.read_bytes(),
            f"\r\n--{boundary}--\r\n".encode(),
        ])
        return request(f"{API}/projects/{project}/upload-file", token, body,
                       {"Content-Type": f"multipart/form-data; boundary={boundary}"}, fail)

    # A related project CurseForge refuses (not approved yet...): left out, the others kept
    while True:
        try:
            result = send(metadata, fail="relations" not in metadata)
            break
        except RequestError as error:
            message = str(error).replace("\\u0027", "'")
            projects = metadata["relations"]["projects"]
            refused = [r["slug"] for r in projects if f"relations: '{r['slug']}'" in message]
            kept = [r for r in projects if r["slug"] not in refused] if refused else []
            print(f"CurseForge: {folder}: relation {', '.join(refused) or '(all)'} refused, left out")
            if kept:
                metadata["relations"]["projects"] = kept
            else:
                del metadata["relations"]
    print(f"CurseForge: {zip_path.name} uploaded ({metadata['releaseType']}), file id {result and result.get('id')}")


def curseforge():
    token = os.environ.get("CF_API_KEY")
    if not token:
        sys.exit("CF_API_KEY is not set (GitHub: Settings > Secrets and variables > Actions)")
    game_version = game_version_id(token)
    # (the core first: the modules' files name it as a relation)
    for folder in sorted(module_versions(), key=lambda f: f != ADDON):
        upload(folder, token, game_version)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "check":
        tag = sys.argv[2] if len(sys.argv) > 2 else ""
        if tag != f"v{version()}":
            sys.exit(f"The tag {tag} doesn't match the TOC's version {version()} (expected v{version()})")
        off = {folder: v for folder, v in module_versions().items() if v != version()}
        if off:
            sys.exit("Modules on another version: " + ", ".join(f"{f} {v}" for f, v in off.items()))
        notes()
        print(f"Version {version()}: ok")
    elif command == "notes":
        sys.stdout.write(notes(sys.argv[2] if len(sys.argv) > 2 else None))
    elif command == "curseforge":
        curseforge()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
