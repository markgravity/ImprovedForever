#!/usr/bin/env python3
"""Render a square post or a framed icon to a 1080x1080 PNG.

    python3 render.py spec.json            # one spec
    python3 render.py a.json b.json ...    # several

A spec is JSON; paths in it are relative to the spec file.

Square post (templates/square.html):
  {"type": "square", "out": "vibration.png",
   "bg": "scene.jpg",                       # from scene.py
   "overlays": [                            # optional, drawn over the scene
     {"src": "window.png", "left": 100, "top": 290, "width": 488,
      "shadow": true},                      # cut-out window (cutout.py)
     {"src": "unitframe.png", "left": 196, "top": 314, "width": 688,
      "card": true}                         # zoom card: cream border, rounded
   ],
   "kicker": "ENHANCE YOUR CONTROLLER PLAY WITH",
   "headline": "VIBRATION", "headline_size": 150,
   "desc": "Feel every cast, hit and game event in your hands"}
  The height of an overlay follows its aspect unless "height" is given.
  Optional "badge" (square or wide), a giveaway card with codes:
    {"left": 1500, "top": 480, "width": 340, "title": "GIVEAWAY",
     "sub": "WoW: Forever Invite-A-Friend launch codes",
     "codes": ["AAAA-...", "BBBB-..."], "note": "optional last line",
     "row": true}          # row: compact, codes side by side, note joins the sub line

Wide post with "center": true puts the text column in the middle (x 580..1340,
over a dark radial fade) so pictures can sit left and right of it.

Wide post, 1920x1080 (templates/wide.html): the same keys as a square, with
"type": "wide" and a 1920x1080 "bg" (scene.py with "size": [1920, 1080]).
The text sits in a column on the left (x 110..870, centred vertically), so
keep the subject and any overlay right of x 900. "headline_size" defaults
to 120; the kicker wraps on its own.

Framed icon (templates/icon.html):
  {"type": "icon", "out": "icon-fishing.png",
   "bg": "scene.jpg",            # any shot or scene; blurred and darkened for you
                                 # ("blur_bg": false to use it as it is)
   "glyph": "ic_mod_fishing.png",
   "glyph_size": 560}            # 560 for module icons, 700 for the addon logo
  Extra "sizes": [512, 256, 128] also writes smaller copies.

Renders with Playwright (Python or Node) when installed, else headless Chrome.
"""
import html
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)

CORNER = ('<svg aria-hidden="true" width="{s}" height="{s}" viewBox="0 0 150 150" class="corner" '
          'style="{pos}; transform: {tf}" fill="none" stroke="#efe6d1" stroke-width="{w}" stroke-linecap="round">'
          '<path d="M22 140 V60 Q22 22 60 22 H140"/><path d="M22 82 Q22 48 50 48 Q72 48 72 68 Q72 84 56 84 Q46 84 46 74"/>'
          '<path d="M82 22 Q48 22 48 50"/><circle cx="22" cy="22" r="{r}" fill="#efe6d1" stroke="none"/></svg>')


def corners(size, off, width, dot):
    places = [(f"left:{off}px;top:{off}px", "none"), (f"right:{off}px;top:{off}px", "scaleX(-1)"),
              (f"left:{off}px;bottom:{off}px", "scaleY(-1)"), (f"right:{off}px;bottom:{off}px", "scale(-1,-1)")]
    return "\n  ".join(CORNER.format(s=size, pos=p, tf=t, w=width, r=dot) for p, t in places)


def url(path, base):
    p = path if os.path.isabs(path) else os.path.join(base, path)
    return "file://" + os.path.abspath(p)


def build(spec, base):
    kind = spec.get("type", "square")
    if kind == "icon":
        page = open(os.path.join(SKILL, "templates", "icon.html")).read()
        size = spec.get("glyph_size", 560)
        bg = spec["bg"] if os.path.isabs(spec["bg"]) else os.path.join(base, spec["bg"])
        if spec.get("blur_bg", True):
            im = Image.open(bg).convert("RGB")
            s = min(im.size)
            im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2)).resize((1080, 1080))
            im = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(28))).enhance(0.75)
            bg = os.path.join(base, ".icon-bg-" + os.path.basename(spec["out"]).rsplit(".", 1)[0] + ".jpg")
            im.save(bg, quality=90)
        page = (page.replace("__CORNERS__", corners(250, 34, 7, 9))
                .replace("__BG__", url(bg, base))
                .replace("__GLYPH__", url(spec["glyph"], base))
                .replace("__GLYPH_SIZE__", str(size))
                .replace("__GLYPH_POS__", str((1080 - size) // 2)))
    else:
        page = open(os.path.join(SKILL, "templates", "wide.html" if kind == "wide" else "square.html")).read()
        parts = []
        for o in spec.get("overlays", []):
            src = o["src"] if os.path.isabs(o["src"]) else os.path.join(base, o["src"])
            w = o["width"]
            h = o.get("height")
            if h is None:
                iw, ih = Image.open(src).size
                h = round(w * ih / iw)
            style = f"position:absolute;left:{o['left']}px;top:{o['top']}px;width:{w}px;height:{h}px;"
            if o.get("card"):
                style += "border:4px solid #efe6d1;border-radius:18px;box-shadow:0 16px 34px rgba(0,0,0,0.75);"
            elif o.get("shadow", True):
                style += "filter:drop-shadow(0 14px 22px rgba(0,0,0,0.8));"
            if "opacity" in o:
                style += f"opacity:{o['opacity']};"
            if o.get("round"):
                style += "border-radius:50%;"
            parts.append(f'<img src="{url(src, base)}" alt="" style="{style}">')
        if kind == "wide" and spec.get("center"):
            page = page.replace("left: 110px; top: 0; bottom: 0; width: 760px", "left: 580px; top: 0; bottom: 0; width: 760px")
            page = page.replace("</style>", ".wd-shade{background:radial-gradient(ellipse 36% 60% at 50% 50%, rgba(14,9,4,0.9) 0%, rgba(14,9,4,0.8) 60%, rgba(14,9,4,0) 100%)}</style>")
        b = spec.get("badge")
        if b and b.get("row"):
            codes = "".join(
                '<div style="flex:1;padding:8px 0;border:2px solid rgba(239,230,209,0.55);border-radius:10px;'
                "background:rgba(0,0,0,0.35);font-family:'Cinzel',serif;font-weight:700;font-size:%dpx;"
                'letter-spacing:0.02em;color:#ffffc0;white-space:nowrap">%s</div>' % (b.get("code_size", 19), html.escape(c))
                for c in b.get("codes", []))
            sub = " · ".join(x for x in (b.get("sub"), b.get("note")) if x)
            parts.append(
                '<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;box-sizing:border-box;padding:14px 14px 14px;'
                'text-align:center;background:rgba(14,9,4,0.82);border:4px solid #efe6d1;border-radius:18px;'
                'box-shadow:0 16px 34px rgba(0,0,0,0.75);color:#fffaec">'
                "<div style=\"font-family:'Cinzel',serif;font-weight:700;font-size:30px;letter-spacing:0.08em;color:#ffffc0\">%s</div>"
                '<div style="margin:2px 0 8px;font-size:19px;letter-spacing:0.03em">%s</div>'
                '<div style="display:flex;gap:10px">%s</div></div>'
                % (b["left"], b["top"], b["width"], html.escape(b.get("title", "GIVEAWAY")), html.escape(sub), codes))
        elif b:
            codes = "".join(
                '<div style="margin-top:10px;padding:9px 0;border:2px solid rgba(239,230,209,0.55);border-radius:10px;'
                "background:rgba(0,0,0,0.35);font-family:'Cinzel',serif;font-weight:700;font-size:%dpx;"
                'letter-spacing:0.02em;color:#ffffc0;white-space:nowrap">%s</div>' % (b.get("code_size", 19), html.escape(c))
                for c in b.get("codes", []))
            note = ('<div style="margin-top:12px;font-size:18px;letter-spacing:0.04em;color:#e8dcc0">%s</div>'
                    % html.escape(b["note"])) if b.get("note") else ""
            parts.append(
                '<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;box-sizing:border-box;padding:20px 14px 18px;'
                'text-align:center;background:rgba(14,9,4,0.82);border:4px solid #efe6d1;border-radius:18px;'
                'box-shadow:0 16px 34px rgba(0,0,0,0.75);color:#fffaec">'
                "<div style=\"font-family:'Cinzel',serif;font-weight:700;font-size:40px;letter-spacing:0.08em;color:#ffffc0\">%s</div>"
                '<div style="margin:6px 0 4px;font-size:20px;line-height:1.3;letter-spacing:0.03em">%s</div>%s%s</div>'
                % (b["left"], b["top"], b["width"], html.escape(b.get("title", "GIVEAWAY")),
                   html.escape(b.get("sub", "")), codes, note))
        page = (page.replace("__CORNERS__", corners(150, 22, 6, 7))
                .replace("__OVERLAYS__", "\n  ".join(parts))
                .replace("__BG__", url(spec["bg"], base))
                .replace("__LOGO__", url(spec.get("logo", os.path.join(SKILL, "assets", "logo.png")), base))
                .replace("__KICKER__", html.escape(spec.get("kicker", "")))
                .replace("__HEADLINE__", html.escape(spec.get("headline", "")))
                .replace("__TITLE_SIZE__", str(spec.get("headline_size", 120 if kind == "wide" else 126)))
                .replace("__DESC__", html.escape(spec.get("desc", ""))))
    return page.replace("__TITLE__", html.escape(spec.get("headline", spec.get("out", "post"))))


def shoot(html_path, png_path, w=1080, h=1080):
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            b = p.chromium.launch()
            pg = b.new_page(viewport={"width": w, "height": h})
            pg.goto("file://" + html_path, wait_until="networkidle")
            pg.evaluate("document.fonts.ready")
            pg.wait_for_timeout(300)
            pg.screenshot(path=png_path)
            b.close()
        return
    except ImportError:
        pass
    node = shutil.which("node")
    if node:
        js = ("const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();"
              "const p=await b.newPage({viewport:{width:+process.argv[3],height:+process.argv[4]}});"
              "await p.goto('file://'+process.argv[1],{waitUntil:'networkidle'});"
              "await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(300);"
              "await p.screenshot({path:process.argv[2]});await b.close();})().catch(e=>{console.error(e);process.exit(3)});")
        env = dict(os.environ)
        try:
            root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip()
            env["NODE_PATH"] = root
        except OSError:
            pass
        r = subprocess.run([node, "-e", js, html_path, png_path, str(w), str(h)], env=env, capture_output=True, text=True)
        if r.returncode == 0:
            return
    chrome = next((c for c in [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        shutil.which("google-chrome"), shutil.which("chromium"), shutil.which("chromium-browser"),
        "/opt/pw-browsers/chromium"] if c and os.path.exists(c)), None)
    if not chrome:
        sys.exit("no renderer: install Playwright (pip install playwright) or Google Chrome")
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={w},{h}",
                    "--virtual-time-budget=4000", f"--screenshot={png_path}", "file://" + html_path], check=True,
                   capture_output=True)


def main():
    for spec_path in sys.argv[1:]:
        spec_path = os.path.abspath(spec_path)
        base = os.path.dirname(spec_path)
        spec = json.load(open(spec_path))
        out = spec["out"] if os.path.isabs(spec["out"]) else os.path.join(base, spec["out"])
        with tempfile.NamedTemporaryFile("w", suffix=".html", dir=base, delete=False) as f:
            f.write(build(spec, base))
            tmp = f.name
        try:
            shoot(tmp, out, *((1920, 1080) if spec.get("type") == "wide" else (1080, 1080)))
        finally:
            os.unlink(tmp)
        for s in spec.get("sizes", []):
            Image.open(out).resize((s, s), Image.LANCZOS).save(out.rsplit(".", 1)[0] + f"-{s}.png")
        print("wrote", out)


if __name__ == "__main__":
    main()
