"""The Immersion module's icon, drawn in the designed icons' style
(import_icons.py: cream and green art, a black outline, a soft shadow): the
cast line's diamond, green, a cream core, the line's ends either side (the
module's spell diamonds and cast line).
  textures/ic_mod_immersion.tga   128 x 128 (import_icons.texture)
  dist/logos/Immersion.png        400 x 400, on the addon logo's dark square

Run: python3 tools/make_immersion_icon.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from import_icons import CREAM, GREEN, LOGOS, TEX, texture  # noqa: E402

DARK = (24, 24, 24)
S = 1080
C = S // 2


def diamond(d, half, fill):
    d.polygon([(C, C - half), (C + half, C), (C, C + half), (C - half, C)], fill=fill)


def art():
    img = Image.new("RGB", (S, S), DARK)
    d = ImageDraw.Draw(img)
    # (the cast line through the middle)
    d.rounded_rectangle((C - 250, C - 26, C + 250, C + 26), radius=26, fill=CREAM)
    # (its diamond: green, a gap round it, a cream core)
    diamond(d, 196, DARK)
    diamond(d, 164, GREEN)
    diamond(d, 90, DARK)
    diamond(d, 62, CREAM)
    return img


def main():
    img = art()
    texture(img, os.path.join(TEX, "ic_mod_immersion.tga"))
    os.makedirs(LOGOS, exist_ok=True)
    size = 400
    logo = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    ImageDraw.Draw(logo).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=69 * 4, fill=(70, 70, 70, 255))
    logo = logo.resize((size, size), Image.LANCZOS)
    tex = Image.open(os.path.join(TEX, "ic_mod_immersion.tga")).convert("RGBA").resize((324, 324), Image.LANCZOS)
    logo.alpha_composite(tex, (38, 38))
    path = os.path.join(LOGOS, "Immersion.png")
    logo.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
