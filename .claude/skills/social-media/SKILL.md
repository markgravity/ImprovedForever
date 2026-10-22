---
name: social-media
description: Make social media images for Improved Forever (Facebook, Reddit, CurseForge) in the set's look: 1080x1080 feature squares and 1920x1080 wide (rect) versions (a game screenshot with a zoom blur that keeps the character sharp, the addon logo and name at the top, a cream frame with corner flourishes, a kicker + big headline + one line at the bottom, and an optional cut-out game window or zoom card) and framed module icons. Use when the user asks for a post, square, banner, promo image, media or artwork for a feature or module, a new module icon "with background/frame", or to update one of these with a new screenshot.
---

# Social media assets

Every image in the set follows one look. Build new ones the same way so they
sit together in an album:

- **Square post**, 1080x1080. A game screenshot, zoom-blurred out from the
  subject (the character, the NPC, the fight) which stays sharp. The addon logo,
  "Improved Forever" (Cinzel Decorative, the logo's cream `#ffffc0`) and a
  small divider at the top. A cream frame (`#efe6d1`, 5px) with curled corner
  flourishes. At the bottom: a kicker line (Cinzel 40px, caps), the big
  headline (Cinzel 600, 90-150px) and one description line (Marcellus 26px).
- **Optional overlay** on a square: a game window cut out of a screenshot
  (shadow only), or a HUD close-up on a "zoom card" (cream border, rounded,
  shadow), on the side opposite the subject.
- **Wide post**, 1920x1080: the same scene, frame and words, with the logo,
  name, kicker, headline and description in one column on the left over a
  dark fade, and the subject (plus any overlay) on the right.
- **Framed icon**, 1080x1080. A blurred, darkened scene, a warm glow in the
  middle, a thick cream frame (12px) with larger flourishes, the icon centred.
  Module icons at 560px, the addon logo at 700px.

Layout rules that keep text off the subject:
- The header ends near y 266 and the bottom text starts near y 740. Keep the
  sharp subject, and any overlay, inside y 280..720.
- Put the subject on one side and the overlay on the other. Prefer re-cropping
  the screenshot over mirroring it: mirroring flips any text in the scene.
- Wide: the text column is x 110..870; keep the subject and overlays right of
  x 900, inside y 90..990. Make the wide scene with `"size": [1920, 1080]`.
- The kicker must fit on one line inside the frame: about 34 characters at
  40px. Shorten the description before shrinking it.
- When one feature gets several squares, reuse the headline (e.g.
  IMMERSION) and change the kicker and description.

## Steps

The scripts live in `.claude/skills/social-media/scripts/` and need Python 3
with Pillow and numpy. `render.py` needs Playwright (Python `pip install
playwright && playwright install chromium`, or Node's) or Google Chrome. Work in
a scratch folder, not in the addon folders: these images never ship.

1. **Read the screenshot.** Find the subject's box (character, NPC, name
   label, dialogue) and every HUD piece (minimap, quest tracker, unit frames,
   action bar, chat, prompt bars). Crop and enlarge areas with Pillow to read
   exact coordinates.

2. **Make the scene** with `scene.py`:

       python3 scripts/scene.py shot.png work/fishing --config '{
         "ell": [700, 470, 360, 380],      # sharp ellipse: centre, radii
         "zc": [800, 430],                 # zoom centre (optional)
         "keep": [[1010,265,1410,345]],    # name labels, dialogue: stay sharp
         "erase": [[0,0,2000,60]],         # HUD to blur away
         "crop": [250, -148, 1300]         # square: left, top, size
       }'

   Choose `crop` so the subject lands in y 280..720 of the square (the script
   prints where it lands). A crop past the shot's edges is fine: the gap is
   filled with a heavy blur of the scene and blended in. A bigger `size`
   zooms out. Look at the result and adjust: a visible seam or a hard-edged
   patch means a wider fade, a smudge over the subject means a smaller
   `erase`.

   For a HUD piece shown in place (a centred target bar), list it under
   `pieces` too: it is saved as a feathered PNG before being erased, ready to
   put back crisp as an overlay (key its background out with `cutout.py --key`).

3. **Cut out the window** (if the post shows one) with `cutout.py`:

       python3 scripts/cutout.py window.png work/window.png --shapes '[
         ["rect", 26, 28, 661, 600, 4],          # the frame, inside the focus glow
         ["circle", 47, 50, 29],                 # round portrait badge
         ["chamfer", 662, 83, 710, 131, 7],      # side tabs
         ["poly", [[117,600],[139,600],[139,652],[130,666],[121,654]]]
       ]'

   Inspect every corner first (crop, enlarge with NEAREST) and cut just inside
   the game's yellow focus glow. Check `work/window_check.png` (magenta
   background) for leftover world or glow, then tighten the shapes.

4. **Write a spec and render** with `render.py` (see its docstring for every
   key):

       {"type": "square", "out": "fishing.png", "bg": "work/fishing.jpg",
        "overlays": [{"src": "work/window.png", "left": 600, "top": 296, "width": 410}],
        "kicker": "CAST, LURE AND COLLECT WITH",
        "headline": "FISHING", "headline_size": 140,
        "desc": "Fish from your controller and fill your own fish collection"}

       python3 scripts/render.py fishing.json

   For the wide version, the same spec with `"type": "wide"`, a wide scene
   and the overlay moved right (e.g. `"left": 1470, "top": 560, "width": 380`).

   For a module icon:

       {"type": "icon", "out": "icon-fishing.png", "bg": "work/fishing.jpg",
        "glyph": "ic_mod_fishing.png", "glyph_size": 560, "sizes": [512, 256]}

   Module icons are the TOCs' `IconTexture`s
   (`ImprovedForever/textures/ic_mod_*.tga`, 128px, already transparent);
   convert one with Pillow and upscale it to 512 before rendering. The addon
   logo is `assets/logo.png` (the cleaned `ic_addon.tga`).

5. **Look at the PNG** before handing it over: the subject clear of both text
   blocks, no line running into the frame, no HUD left in the scene, the
   overlay's edges clean.

## Words

Write from what the feature does, in the addon's README, the module's TOC
`## Notes`, or its code, and from what the screenshot shows. Never invent a
feature. When the module isn't in the repo, say the wording comes from the
screenshot and offer to change it. Use the user's names for features
("Wiki", not the module's folder name, when they say so).

Lines used so far, for the tone:

| Headline | Kicker | Description |
|---|---|---|
| VIBRATION | ENHANCE YOUR CONTROLLER PLAY WITH | Feel every cast, hit and game event in your hands |
| AUCTION HOUSE | BUY & SELL MADE EASY AT THE | Faster selling, easier buying, prices tracked over time |
| MINIMAP LABELS | QUICK PEEK AT EVERY NODE WITH | See each node's name and required skill level on the minimap |
| WIKI | YOUR IN-GAME ENCYCLOPEDIA | Know any item inside out: who drops it, sells it, its recipes and quests |
| SMART JUNK | CLEAR YOUR BAGS WITH | Finds what your bags no longer need, then sells or destroys it |
| QUEST TRACKER | YOUR QUESTS, SORTED YOUR WAY | By zone, level, title or distance, with full controller support |
| PEEK MAP | HOLD ONE BUTTON FOR A QUICK | The map shows see-through over the game; let go and it's gone |
| RADIAL WHEELS | EVERYTHING ONE STICK AWAY WITH | Spells, items, emotes and food on R3, aimed with the right stick |
| JOURNAL | EVERY ADVENTURE WRITTEN IN YOUR | A diary of each day you play: lands, quests, fights and loot |
| FISHING | CAST, LURE AND COLLECT WITH | Fish from your controller and fill your own fish collection |
| IMMERSION | KEEP YOUR EYES ON THE FIGHT WITH | Target and cast bars centred, right where the action is |

Post text for Facebook or Reddit: an excited first line, then one plain line
per feature ("Enhanced controller vibration when casting spells, landing hits
and on game events"), no emoji unless asked, and the CurseForge search name
"Improved Forever".
