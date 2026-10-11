---
name: curseforge-comments
description: Check the comments on our CurseForge projects (the core and every module), work out what each unanswered one reports, fix the addon when it's a bug, and reply on CurseForge. Use when the user asks to check, read, answer or reply to CurseForge comments, mentions a player's comment or bug report from CurseForge, or asks "any new comments".
---

# CurseForge comments

CurseForge's public API (api.curseforge.com) has **no comments**. The website's
own endpoints do:

| What | How | Login |
|---|---|---|
| Read a project's comments | `GET https://www.curseforge.com/api/v1/mods/<projectId>/comments?page=0&size=50` | no |
| Post a comment or reply | `POST https://www.curseforge.com/api/v1/comments` | yes (site cookie) |

Project IDs are the TOCs' `## X-Curse-Project-ID`. Our account is
`markgravity11` (override with `CF_AUTHOR`).

## 1. Read

```sh
python3 tools/cf_comments.py          # threads whose last word isn't ours
python3 tools/cf_comments.py --all    # every thread
python3 tools/cf_comments.py --json   # for parsing
```

Each thread shows its project (folder, slug), the thread ID (the top comment's
ID, used as `parentId` when replying) and its posts, oldest first.

## 2. Work out each waiting thread

Sort it:
- **Bug report**
- **Feature request**
- **Question**
- **Thanks / praise**
- **Pointer elsewhere**, e.g. "I filed issues on GitHub": check them with `gh issue list`.

Players write loosely ("the pad", "the ring", "the area to open the bag"):
- Map their words onto the addon:
  - the module the project is for, but a comment on the core page can be about any module
  - its README
  - CHANGELOG.md
  - the controller's buttons and touchpad
- Read the code involved (codegraph first).
- If what they mean is still unclear after that, the reply asks them, specifically
  (which button, which window, the exact error text, BugSack/`/console scriptErrors 1`).

### Bugs

- **Find the cause in the code** before changing anything. Read the paths their
  steps go through.
- **Fix it** following CLAUDE.md (focus rules, game data, no taint).
- **Run the checks:**
  - `luajit -bl <file>`
  - the stray-global grep
  - `luajit tools/loadcheck.lua each`
- **Ask the user to confirm in game when it can't be reproduced from code**, e.g. a
  taint, an error only the client shows. Log to SavedVariables as CLAUDE.md says.
- **Add the fix to CHANGELOG.md** under the next version.
- **Don't commit, tag or release** unless the user asks.

### Feature requests

Say whether it fits and how big it is. Build it only if the user says so.

## 3. Reply

- **Draft each reply and show the drafts to the user.** Post only after they
  approve: replies are public.
- **Style:**
  - Short, friendly, plain English (many players aren't native speakers).
  - Start with `@<displayName>`, as the site's Reply button does.
  - Say what was wrong and what changed, in player terms. No code talk.
  - If it's fixed, say it lands in the next update, or name the version if one
    is already out with it.
  - If more info is needed, ask for exactly what.
- **Post from the browser, signed in as the author.** Use chrome-devtools:
  1. Open a tab on the thread's `url` (`new_page`, `background: true`). The page
     list shows whether one is open already.
  2. Run this with `evaluate_script` on that tab, filling in the values:

```js
async () => {
  const projectId = 1731245, parentId = 8529801;   // thread's project and ID
  const text = "@Name Thanks for ...";              // the approved reply
  const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const body = text.split(/\n{2,}/).map(p => `<p>${esc(p).replace(/\n/g, "<br>")}</p>`).join("");
  const r = await fetch("/api/v1/comments", {
    method: "POST", credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ entityId: projectId, parentId, body, bodyType: "RawHtml" }),
  });
  return { status: r.status, body: await r.text() };
}
```

- **Check the result:**
  - **2xx (201, empty body):** it's posted. It shows up in the list about 10 s
    later. Don't post again: poll `python3 tools/cf_comments.py` (in the
    background) until the thread no longer waits.
  - **401/403:** the browser isn't signed in. Ask the user to sign in to
    curseforge.com in that Chrome, then retry.
  - **429:** rate limited. Wait and retry once.
  - **Never** copy cookies out of the browser into scripts or files.

## 4. Report

For each thread:
- what it was
- what was changed (files) or why nothing was
- the reply posted, or that it's waiting on the user's approval or in-game test
