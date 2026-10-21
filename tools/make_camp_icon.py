"""The Camp module's icon, drawn in the designed icons' style
(import_icons.py: cream and green art, a black outline, a soft shadow): a
campfire, two cream logs crossed, their cut ends ringed, a green flame
rising from them, a cream flame inside it.
  textures/ic_mod_camp.tga   128 x 128 (import_icons.texture)
  dist/logos/Camp.png        400 x 400, on the addon logo's dark square

Run: python3 tools/make_camp_icon.py   (needs Pillow)
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from import_icons import CREAM, GREEN, LOGOS, TEX, texture  # noqa: E402

DARK = (24, 24, 24)
S = 1080
C = S // 2


def flame(d, cx, cy, w, h, lean, fill, steps=180):
    """A teardrop, its point up, leaning `lean` px to the right at the tip"""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        y = -math.cos(t)                        # 1 at the bottom, -1 at the tip
        x = math.sin(t) * abs(math.sin(t / 2)) ** 1.3
        up = (1 - y) / 2                        # 0 bottom, 1 tip
        pts.append((cx + w * x + lean * up ** 3, cy + h * y))
    d.polygon(pts, fill=fill)


def log(d, a, b, width, fill):
    """A log from a to b, round ended; its far end's cut face ringed"""
    d.line([a, b], fill=fill, width=width)
    for p in (a, b):
        d.ellipse((p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2), fill=fill)


def ring(d, p, r, fill):
    d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=fill)


def art():
    img = Image.new("RGB", (S, S), DARK)
    d = ImageDraw.Draw(img)
    # (the logs, crossed under the fire)
    w = 78
    l1 = ((C - 270, C + 300), (C + 250, C + 170))
    l2 = ((C + 270, C + 300), (C - 250, C + 170))
    log(d, *l1, w + 36, DARK)
    log(d, *l1, w, CREAM)
    log(d, *l2, w + 36, DARK)
    log(d, *l2, w, CREAM)
    # (their front ends cut: a ring each)
    for p in (l1[0], l2[0]):
        ring(d, p, w / 2 - 14, DARK)
        ring(d, p, w / 2 - 30, CREAM)
    # (the flame: green, a gap round it, a cream heart)
    fy = C - 30
    flame(d, C, fy, 200, 250, 40, DARK)
    flame(d, C, fy, 172, 222, 34, GREEN)
    flame(d, C, fy + 70, 96, 140, 22, DARK)
    flame(d, C, fy + 80, 70, 112, 18, CREAM)
    return img


def main():
    img = art()
    texture(img, os.path.join(TEX, "ic_mod_camp.tga"))
    os.makedirs(LOGOS, exist_ok=True)
    size = 400
    logo = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    ImageDraw.Draw(logo).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=69 * 4, fill=(70, 70, 70, 255))
    logo = logo.resize((size, size), Image.LANCZOS)
    tex = Image.open(os.path.join(TEX, "ic_mod_camp.tga")).convert("RGBA").resize((324, 324), Image.LANCZOS)
    logo.alpha_composite(tex, (38, 38))
    path = os.path.join(LOGOS, "Camp.png")
    logo.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
