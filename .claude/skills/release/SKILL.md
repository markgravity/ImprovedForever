---
name: release
description: Release Improved Forever addons. Finds which addons changed since their last tag, picks each one's next version, bumps their TOCs, writes the CHANGELOG sections from the commits, commits, then tags and pushes one tag per addon so the GitHub Action builds the zips, makes the GitHub releases and uploads to CurseForge. Use when the user asks to release, publish, ship, cut a version or bump versions, or asks "what changed since the last release".
---

# Release

Each addon is versioned and released on its own. A tag `<Name>-v<version>` releases
only that addon (`Core` is the `ImprovedForever` folder; the others are the folder
without `ImprovedForever_`: `Wheel`, `QuestTracker`...). The Action
(`.github/workflows/release.yml`) does the rest: checks the tag against the TOC and
the changelog, builds that addon's zip, creates the GitHub release, uploads to
CurseForge when the TOC has `## X-Curse-Project-ID` (Chat and Journal have none: GitHub only).
Pushing to main alone releases nothing.

## Steps

1. **What changed.** `python3 tools/release.py changed` (files changed per addon since its
   last tag; for the first per-addon release it falls back to the old `v<version>` tag).
   Then read the commits per addon:
   `git log <last tag>..HEAD --format='%h %s%n%b' -- <folder>`.
   Ignore mode-only changes (`git -c core.fileMode=false diff --stat <tag> HEAD -- <folder>`
   shows 0): the Quest Tracker's `Blizzard_*` files are generated, not a change.
2. **Pick versions.** Per changed addon: a new feature or module change users see → minor
   (0.6.0 → 0.7.0); only fixes, icons, descriptions → patch (0.6.0 → 0.6.1); a suffix
   (`0.7.0-beta1`) makes a pre-release / beta. An unchanged addon keeps its version and gets
   no tag. If the core changed in a way a module needs (a new API, a texture a module
   points to), release that module too, and tag the core first.
   Show the user the plan (addon, old → new, why) and get a yes before touching files.
3. **Bump** `## Version:` in each released addon's TOC only.
4. **CHANGELOG.md**: add a `## <Name> <version>` section on top for each (e.g.
   `## Wheel 0.7.0`), new ones above the old, one bullet per user-visible change in the
   voice of the existing entries (what the player sees, not the code). Skip chores. Older
   `## 0.6.0` style sections are history; leave them.
5. **Check.** `python3 tools/release.py check <Name>-v<version>` for each (it also needs the
   changelog section), `python3 tools/package.py <Name>...` builds the zips, and
   `luajit tools/loadcheck.lua each` if code changed since the last check.
6. **Commit** the bumps and the changelog (`chore: release ...`), then for each addon
   `git tag <Name>-v<version>`, and one `git push origin main <tag> <tag>...`. Pushing a
   tag starts a run per tag; the user has to ask for the release (this skill's trigger is
   that ask) before anything is pushed.
7. **Watch.** `gh run list --workflow=Release --limit 12`, then `gh run view <id> --log-failed`
   for any failure. A failed run after the tag: fix, delete the tag
   (`git push origin :refs/tags/<tag>`, `git tag -d <tag>`), tag again.

## Notes

- Tag names are case-insensitive for the addon but write them as above.
- Never reuse a version: CurseForge and the GitHub release keep it.
- A new addon needs its CurseForge project and `X-Curse-Project-ID` first (`/curseforge-project`).
- CF_API_KEY is the repository secret; locally it can be in `.env` (git-ignored) to run
  `python3 tools/release.py curseforge <tag>` by hand.
