"""SUPERSEDED by tools/import_icons.py (the designed icons); this draws the old ones.

The addon's own icon (the AddOns list, ## IconTexture in the core's toc),
solid as the modules' (line_icon.py's render_solid: cream shapes, green
accents): Forever, an infinity loop (its strands over and under where they
cross), Improved, a green double arrow rising out of its right lobe; on the
logo's dark rounded square; as textures/ic_addon.tga, 128 x 128.

Run: python3 tools/make_addon_icon.py   (needs Pillow)
     python3 tools/make_addon_icon.py --logo   also the CurseForge logo, 400 x 400
     on the same background, as dist/logos/ImprovedForever.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import GOLD, GREEN, Icon  # noqa: E402
from line_icon import render_solid  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures", "ic_addon.tga")
icon = Icon()
CX, CY, A, TALL, WIDTH = 58, 80, 50, 1.3, 12


def new():
    m = icon.mask()
    return m, icon.draw(m)


def loop(t0, t1, steps=160):
    """The infinity loop (a lemniscate, its lobes a little taller) from t0 to t1"""
    pts = []
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        d = 1 + math.sin(t) ** 2
        pts.append((CX + A * math.cos(t) / d, CY + TALL * A * math.sin(t) * math.cos(t) / d))
    return pts


if __name__ == "__main__":
    from PIL import ImageChops, ImageFilter
    # The loop, open at its right lobe's top (where the arrow rises); where
    # it crosses, the strand from lower left to upper right goes over: the
    # other one cut round it there (only there: one shape, no seams)
    back, db = new()
    icon.stroke(db, loop(-math.pi * 0.06, math.pi * 1.74), WIDTH)
    core, dc = new()
    icon.stroke(dc, loop(math.pi * 1.5 - 0.04, math.pi * 1.5 + 0.04), WIDTH)
    gap = core.filter(ImageFilter.MaxFilter(icon.px(2.5) * 2 + 1))
    over, do = new()
    icon.stroke(do, loop(math.pi * 1.5 - 0.5, math.pi * 1.5 + 0.5), WIDTH)
    shape = ImageChops.lighter(ImageChops.subtract(back, gap), over)
    # Improved: a double arrow up, out of the gap in the right lobe
    arrows, da = new()
    for y in (12, 32):
        icon.stroke(da, [(92, y + 14), (106, y), (120, y + 14)], 9)
    layers = [(shape, GOLD), (arrows, GREEN)]
    render_solid(OUT, layers)

    # On the logo's background: a dark rounded square, the art inset on it
    from PIL import Image, ImageDraw

    def on_background(path, size, inset, radius):
        art = Image.open(path).convert("RGBA")
        out = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
        ImageDraw.Draw(out).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=radius * 4,
                                              fill=(70, 70, 70, 255))
        out = out.resize((size, size), Image.LANCZOS)
        # (the art's own extent, centred in the square)
        art = art.crop(art.getbbox())
        k = (size - 2 * inset) / max(art.size)
        art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
        out.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
        out.save(path)
        print("on its background:", path)

    on_background(OUT, 128, 12, 22)
    if "--logo" in sys.argv:
        # (the modules' logos' size and margins: make_module_icons.py --logos)
        logo = os.path.join(os.path.dirname(__file__), "..", "dist", "logos", "ImprovedForever.png")
        os.makedirs(os.path.dirname(logo), exist_ok=True)
        render_solid(logo, layers, out_size=400)
        on_background(logo, 400, 38, 69)
