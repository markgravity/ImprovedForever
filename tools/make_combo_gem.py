"""The combo point gem of Immersion's target header: a small cut diamond in four lit facets (the quest arrow's
look: top left face bright, the right and lower ones in shade), a thin edge and a highlight; beside it a soft
glow to lay under it with additive blending. One sheet, 128 x 64: the gem on the left half, the glow on the
right (texcoords 0-0.5 and 0.5-1).

Drawn 4x and scaled down (smooth edges), 32-bit TGA with alpha.
Run: python3 tools/make_combo_gem.py   (needs Pillow)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures", "ic_combo_gem.tga")
CELL, SCALE = 64, 4
S = CELL * SCALE


def gem():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    r = S * 0.46
    top, right, bottom, left = (c, c - r), (c + r, c), (c, c + r), (c - r, c)
    mid = (c, c)
    # the four facets, lit from the top left
    facets = [
        ([top, left, mid], (255, 150, 140)),          # upper left: brightest
        ([top, right, mid], (236, 64, 64)),           # upper right
        ([left, bottom, mid], (196, 34, 44)),         # lower left
        ([right, bottom, mid], (128, 16, 30)),        # lower right: darkest
    ]
    for pts, color in facets:
        d.polygon(pts, fill=color + (255,))
    # the edge: thin, a dark red with a gold touch on the lit sides
    d.line([top, right, bottom, left, top], fill=(90, 8, 20, 255), width=int(S * 0.045), joint="curve")
    d.line([left, top, right], fill=(255, 208, 120, 255), width=int(S * 0.022), joint="curve")
    # the highlight: a small bright sliver on the upper left face
    d.polygon([(c - r * 0.42, c - r * 0.12), (c - r * 0.1, c - r * 0.62), (c - r * 0.02, c - r * 0.4),
               (c - r * 0.26, c - r * 0.06)], fill=(255, 255, 255, 200))
    return im.resize((CELL, CELL), Image.LANCZOS)


def glow():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    d.ellipse([c - S * 0.30, c - S * 0.30, c + S * 0.30, c + S * 0.30], fill=(255, 60, 60, 255))
    im = im.filter(ImageFilter.GaussianBlur(S * 0.11))
    im = im.resize((CELL, CELL), Image.LANCZOS)
    # (kept faint: laid under the gem, it only warms the air round it)
    a = im.getchannel("A").point(lambda v: int(v * 0.8))
    im.putalpha(a)
    return im


if __name__ == "__main__":
    sheet = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
    sheet.paste(gem(), (0, 0))
    sheet.paste(glow(), (CELL, 0))
    sheet.save(OUT)
    preview = Image.new("RGBA", (CELL * 2 * 3, CELL * 3), (24, 30, 46, 255))
    preview.alpha_composite(sheet.resize((CELL * 2 * 3, CELL * 3), Image.LANCZOS))
    path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "combo_gem.png")
    preview.save(path)
    print(OUT)
    print(path)
