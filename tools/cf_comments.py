"""Comments on our CurseForge projects. Python standard library only.

    python3 tools/cf_comments.py           threads still waiting on us
    python3 tools/cf_comments.py --all     every thread
    python3 tools/cf_comments.py --json    the same, as JSON (for the skill)

CurseForge's public API has no comments. These come from the website's own
endpoint (GET www.curseforge.com/api/v1/mods/<id>/comments), which needs no
login. Each addon with '## X-Curse-Project-ID' in its TOC is read.

A thread waits on us when its last word isn't the author's (AUTHOR, or
CF_AUTHOR in the environment): a comment nobody answered, or a reply that came
after ours.

Replying needs the author's login, so it isn't done here: the skill
(.claude/skills/curseforge-comments) posts from the browser, where the author is
signed in (POST /api/v1/comments {entityId, parentId, body, bodyType: "RawHtml"}).
"""
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = "https://www.curseforge.com/api/v1"
AUTHOR = os.environ.get("CF_AUTHOR", "markgravity11")
PAGE = 50


def projects():
    """(folder, project ID, slug) of each addon with a CurseForge project"""
    found = []
    for toc in sorted(ROOT.glob("ImprovedForever*/ImprovedForever*.toc")):
        m = re.search(r"^## X-Curse-Project-ID:\s*(\d+)", toc.read_text(encoding="utf-8"), re.M)
        if m and toc.stem == toc.parent.name:
            words = re.findall(r"[A-Z][a-z]*", toc.stem[len("ImprovedForever"):])
            slug = "-".join(["improved", "forever"] + [w.lower() for w in words])
            found.append((toc.parent.name, int(m.group(1)), slug))
    return found


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def comments(project):
    """Every top-level comment of a project, its replies under 'replies'"""
    found, page = [], 0
    while True:
        body = get(f"{SITE}/mods/{project}/comments?page={page}&size={PAGE}")
        found += body.get("data") or []
        total = (body.get("pagination") or {}).get("totalCount", 0)
        page += 1
        if not body.get("data") or page * PAGE >= total:
            return found


def flat(comment):
    """A comment and its replies, oldest first"""
    out = [comment]
    for reply in comment.get("replies") or []:
        out += flat(reply)
    return sorted(out, key=lambda c: c["datePosted"])


def who(comment):
    author = comment.get("author") or {}
    return author.get("username"), author.get("displayName") or author.get("username")


def when(ms):
    return datetime.fromtimestamp(ms / 1000, timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def threads(show_all):
    out = []
    for folder, project, slug in projects():
        for top in comments(project):
            posts = flat(top)
            waiting = who(posts[-1])[0] != AUTHOR
            if not (waiting or show_all):
                continue
            out.append({
                "folder": folder, "project": project, "slug": slug,
                "url": f"https://www.curseforge.com/wow/addons/{slug}/comments",
                "id": top["id"], "waiting": waiting,
                "posts": [{
                    "id": c["id"], "user": who(c)[0], "name": who(c)[1],
                    "date": when(c["datePosted"]), "text": c.get("text", ""),
                } for c in posts],
            })
    return out


def main():
    args = sys.argv[1:]
    found = threads("--all" in args)
    if "--json" in args:
        print(json.dumps(found, indent=1, ensure_ascii=False))
        return
    if not found:
        print("No thread waiting on us." if "--all" not in args else "No comments.")
        return
    for t in found:
        print(f"{t['slug']} ({t['folder']}, project {t['project']}) thread {t['id']}"
              f"{'  <- waiting' if t['waiting'] else ''}\n  {t['url']}")
        for p in t["posts"]:
            me = " (us)" if p["user"] == AUTHOR else ""
            print(f"  [{p['id']}] {p['date']} {p['name']}{me}: {p['text']}")
        print()


if __name__ == "__main__":
    main()
