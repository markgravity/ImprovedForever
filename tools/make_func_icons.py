"""The functions' icons (the Controller tab's cards of what can be bound, a
window of ours put on a press), in the module icons' style
(make_module_icons.py: line_icon's render_solid, cream shapes, green
accents, holes cut). A function that opens a module's panel keeps that
module's icon (Journal, the Improved Forever panel, Destroy's bin).
  ic_fn_bagsort   a backpack, green sort arrows (up / down) beside it
  ic_fn_junkmark  a bag slot, a green junk coin stamped on its corner
  ic_fn_labels    the minimap's ring, its dots, a green name tag by one
  ic_fn_peekmap   a folded map, a green eye over it (see-through)
  ic_fn_reload    two arrows chasing round a circle, one green

Run: python3 tools/make_func_icons.py   (needs Pillow)
"""
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import GOLD, GREEN, Icon, preview  # noqa: E402
from line_icon import render_solid  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
icon = Icon()
ALL = []


def save(name, layers):
    path = os.path.join(OUT, name + ".tga")
    render_solid(path, layers)
    ALL.append(path)


def new():
    m = icon.mask()
    return m, icon.draw(m)


def rounded(d, x0, y0, x1, y1, r):
    px = icon.px
    d.rounded_rectangle((px(x0), px(y0), px(x1), px(y1)), radius=px(r), fill=255)


def arrow_arc(d, cx, cy, r, a0, a1, width, head):
    """An arc from a0 to a1 (degrees, 0 = right, 90 = down), a head at a1
    pointing along it"""
    icon.arc(d, cx, cy, r, a0, a1 - 8, width)
    a = math.radians(a1)
    tip = (cx + r * math.cos(a), cy + r * math.sin(a))
    back = math.radians(a1 - 22)
    bx, by = cx + r * math.cos(back), cy + r * math.sin(back)
    # (the head's base across the arc, at its radius in and out)
    nx, ny = math.cos(back), math.sin(back)
    icon.polygon(d, [tip, (bx + nx * head, by + ny * head), (bx - nx * head, by - ny * head)])


def make():
    # Bag clean-up: a backpack (a flap and a pocket cut), sort arrows
    # (green) up and down beside it
    bag, db = new()
    rounded(db, 14, 30, 82, 112, 16)
    icon.arc(db, 48, 32, 14, 180, 360, 6)
    cuts, dc = new()
    icon.stroke(dc, [(18, 58), (78, 58)], 5)
    rounded(dc, 30, 74, 66, 98, 6)
    pocket, dp = new()
    rounded(dp, 35, 79, 61, 93, 3)
    cuts = icon.cut(cuts, pocket)
    bag = icon.cut(bag, cuts)
    arrows, da = new()
    icon.stroke(da, [(100, 34), (100, 70)], 7)
    icon.polygon(da, [(88, 44), (100, 24), (112, 44)])
    icon.stroke(da, [(100, 76), (100, 104)], 7)
    icon.polygon(da, [(88, 96), (100, 116), (112, 96)])
    save("ic_fn_bagsort", [(bag, GOLD), (arrows, GREEN)])

    # Mark Junk: a bag slot (its middle cut), a junk coin (green, a ring
    # cut in it) stamped on its lower right corner
    slot, ds = new()
    rounded(ds, 12, 12, 92, 92, 14)
    hole, dh = new()
    rounded(dh, 24, 24, 80, 80, 8)
    slot = icon.cut(slot, hole)
    coin, dc = new()
    icon.circle(dc, 88, 88, 28)
    ring, dr = new()
    icon.circle(dr, 88, 88, 17)
    inner, di = new()
    icon.circle(di, 88, 88, 11)
    ring = icon.cut(ring, inner)
    coin = icon.cut(coin, ring)
    save("ic_fn_junkmark", [(slot, GOLD), (coin, GREEN)])

    # Minimap labels: the minimap's ring, three dots in it, a name tag
    # (green, two lines cut) by the top one
    ring, dr = new()
    icon.circle(dr, 52, 70, 44)
    inside, di = new()
    icon.circle(di, 52, 70, 36)
    ring = icon.cut(ring, inside)
    dots, dd = new()
    for x, y in ((42, 52), (68, 82), (34, 88)):
        icon.circle(dd, x, y, 7)
    tag, dt = new()
    rounded(dt, 58, 18, 122, 50, 8)
    icon.polygon(dt, [(56, 40), (46, 50), (66, 46)])
    lines, dl = new()
    icon.stroke(dl, [(68, 29), (110, 29)], 5)
    icon.stroke(dl, [(68, 40), (96, 40)], 5)
    tag = icon.cut(tag, lines)
    save("ic_fn_labels", [(ring, GOLD), (dots, GOLD), (tag, GREEN)])

    # Peek map: a folded map, an eye (green, its pupil cut) over it
    m, d = new()
    icon.polygon(d, [(12, 40), (44, 28), (84, 40), (116, 28), (116, 102), (84, 114), (44, 102), (12, 114)])
    folds, fd = new()
    icon.stroke(fd, [(44, 28), (44, 102)], 4)
    icon.stroke(fd, [(84, 40), (84, 114)], 4)
    m = icon.cut(m, folds)
    eye, de = new()
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((26 + 76 * t, 70 - 26 * math.sin(math.pi * t)))
    for i in range(41):
        t = i / 40
        pts.append((102 - 76 * t, 70 + 26 * math.sin(math.pi * t)))
    icon.polygon(de, pts)
    iris, dr = new()
    icon.circle(dr, 64, 70, 15)
    pupil, dp = new()
    icon.circle(dp, 64, 70, 7)
    iris = icon.cut(iris, pupil)
    eye = icon.cut(eye, iris)
    save("ic_fn_peekmap", [(m, GOLD), (eye, GREEN)])

    # Reload: two arrows chasing each other round a circle, one green
    a, da = new()
    arrow_arc(da, 64, 64, 40, 200, 330, 10, 14)
    b, db = new()
    arrow_arc(db, 64, 64, 40, 20, 150, 10, 14)
    save("ic_fn_reload", [(a, GOLD), (b, GREEN)])


if __name__ == "__main__":
    make()
    out = os.path.join(tempfile.gettempdir(), "func_icons_preview.png")
    preview(ALL, out)
    print("preview", out)
