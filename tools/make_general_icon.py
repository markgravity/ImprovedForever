"""The core's General tab icon, drawn in the designed icons' style
(import_icons.py: cream and green art, a black outline, a soft shadow): three
cream slider tracks, a green knob on each at a different place.
  textures/ic_mod_general.tga   128 x 128 (import_icons.texture)

Run: python3 tools/make_general_icon.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from import_icons import CREAM, GREEN, TEX, texture  # noqa: E402

DARK = (24, 24, 24)
S = 1080
C = S // 2


def art():
    img = Image.new("RGB", (S, S), DARK)
    d = ImageDraw.Draw(img)
    left, right = C - 330, C + 330
    track = 64
    for y, x in ((C - 230, C - 120), (C, C + 150), (C + 230, C - 20)):
        d.line([(left, y), (right, y)], fill=DARK, width=track + 36)
        d.ellipse((left - track / 2 - 18, y - track / 2 - 18, left + track / 2 + 18, y + track / 2 + 18), fill=DARK)
        d.ellipse((right - track / 2 - 18, y - track / 2 - 18, right + track / 2 + 18, y + track / 2 + 18), fill=DARK)
        d.line([(left, y), (right, y)], fill=CREAM, width=track)
        d.ellipse((left - track / 2, y - track / 2, left + track / 2, y + track / 2), fill=CREAM)
        d.ellipse((right - track / 2, y - track / 2, right + track / 2, y + track / 2), fill=CREAM)
        r = 108
        d.ellipse((x - r - 20, y - r - 20, x + r + 20, y + r + 20), fill=DARK)
        d.ellipse((x - r, y - r, x + r, y + r), fill=GREEN)
        d.ellipse((x - 40, y - 40, x + 40, y + 40), fill=CREAM)
    return img


def main():
    texture(art(), os.path.join(TEX, "ic_mod_general.tga"))
    print("wrote ic_mod_general.tga")


if __name__ == "__main__":
    main()
