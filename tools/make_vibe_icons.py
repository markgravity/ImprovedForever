"""The Vibration tab's icons in the addon logo's style (line_icon.py: cream
outlines, green accents; shapes drawn with radial_icon's helpers):
textures/ic_vibe_<pattern>.tga for the patterns and Off, and
textures/ic_event_<event>.tga for the events.

Run: python3 tools/make_vibe_icons.py   (needs Pillow)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import BLUE, GOLD, GREEN, GREY, LEATHER, RED, STEEL, Icon, preview  # noqa: E402
from line_icon import render  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
icon = Icon()


def path(name):
    return os.path.join(OUT, name + ".tga")


def waves(d, cx, cy, n, r0, step, width, span=50):
    """Vibration arcs either side of a point"""
    for i in range(n):
        r = r0 + i * step
        icon.arc(d, cx, cy, r, -span, span, width)
        icon.arc(d, cx, cy, r, 180 - span, 180 + span, width)


def patterns():
    m = icon.mask(); d = icon.draw(m)
    icon.circle(d, 64, 64, 10)
    waves(d, 64, 64, 1, 26, 0, 6, 40)
    render(path("ic_vibe_micro"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(14, 76), (44, 76), (58, 28), (72, 100), (84, 76), (114, 76)], 10)
    render(path("ic_vibe_tick"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(10, 78), (28, 78), (38, 34), (50, 96), (60, 78), (68, 78), (78, 34), (90, 96), (100, 78),
                    (118, 78)], 9)
    render(path("ic_vibe_double"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.circle(d, 64, 64, 12)
    waves(d, 64, 64, 3, 24, 16, 7, 55)
    render(path("ic_vibe_pulse"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(x, 64 + 18 * math.sin((x - 12) / 104 * 6 * math.pi)) for x in range(12, 117, 2)], 10)
    render(path("ic_vibe_long"), [(m, GOLD)])

    heart = icon.mask(); d = icon.draw(heart)
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((64 + x * 3.1, 60 - y * 3.1))
    icon.polygon(d, pts)
    line = icon.mask(); d = icon.draw(line)
    icon.stroke(d, [(8, 66), (36, 66), (46, 44), (58, 90), (70, 34), (80, 66), (120, 66)], 7)
    render(path("ic_vibe_heart"), [(heart, RED), (line, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.bar(d, 36, 74, 104, 18)
    icon.bar(d, 64, 52, 104, 18)
    icon.bar(d, 92, 26, 104, 18)
    render(path("ic_vibe_rise"), [(m, GOLD)])

    # Impact: a heavy fist-like burst, short and hard: a wide star, waves
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 64, 64, 44, 22, 8, turn=-90)
    hit = icon.mask(); d = icon.draw(hit)
    waves(d, 64, 64, 1, 52, 0, 8, 35)
    render(path("ic_vibe_impact"), [(burst, RED), (hit, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(8, 78), (20, 78), (28, 38), (38, 94), (46, 78), (52, 78), (60, 38), (70, 94), (78, 78),
                    (84, 78), (92, 38), (102, 94), (110, 78), (120, 78)], 8)
    render(path("ic_vibe_triple"), [(m, GOLD)])

    # Purr: small soft bumps in a row, over and over
    m = icon.mask(); d = icon.draw(m)
    for x in (28, 64, 100):
        icon.arc(d, x, 72, 14, 180, 360, 8)
    loop = icon.mask(); d = icon.draw(loop)
    icon.arc(d, 64, 72, 46, 20, 160, 7)
    icon.polygon(d, [(22, 84), (40, 92), (24, 104)])
    render(path("ic_vibe_purr"), [(m, GOLD), (loop, GREY)])

    # Sweep: left to right and back, arrows both ways over a row of dots
    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(24, 64), (104, 64)], 9)
    icon.polygon(d, [(8, 64), (30, 46), (30, 82)])
    icon.polygon(d, [(120, 64), (98, 46), (98, 82)])
    for x in (44, 64, 84):
        icon.circle(d, x, 40, 6)
        icon.circle(d, x, 88, 6)
    render(path("ic_vibe_sweep"), [(m, GOLD)])

    # Fade out: bars stepping down
    m = icon.mask(); d = icon.draw(m)
    icon.bar(d, 36, 26, 104, 18)
    icon.bar(d, 64, 52, 104, 18)
    icon.bar(d, 92, 74, 104, 18)
    render(path("ic_vibe_fade"), [(m, GOLD)])

    rings = icon.mask(); d = icon.draw(rings)
    icon.circle(d, 64, 64, 10)
    waves(d, 64, 64, 2, 26, 16, 7, 50)
    slash = icon.mask(); d = icon.draw(slash)
    icon.stroke(d, [(28, 100), (100, 28)], 11)
    render(path("ic_vibe_off"), [(rings, GREY), (slash, RED)])


def events():
    # Level up: a gold up-arrow, a star above it
    arrow = icon.mask(); d = icon.draw(arrow)
    icon.polygon(d, [(64, 34), (100, 72), (78, 72), (78, 110), (50, 110), (50, 72), (28, 72)])
    star = icon.mask(); d = icon.draw(star)
    icon.star(d, 64, 22, 16, 7, 5)
    render(path("ic_event_levelup"), [(arrow, GOLD), (star, GOLD)])

    # You crit: a jagged gold burst, a red core
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 64, 64, 56, 30, 10, turn=-72)
    core = icon.mask(); d = icon.draw(core)
    icon.star(d, 64, 64, 26, 14, 6, turn=-90)
    render(path("ic_event_crit"), [(burst, GOLD), (core, RED)])

    # You get crit: a red burst behind a cracked steel shield
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 90, 36, 36, 16, 8)
    shield = icon.mask(); d = icon.draw(shield)
    # A heater shield: a flat top, sides curving in to a point
    right = [(100 - 36 * t * t, 28 + 84 * t) for t in (i / 20 for i in range(21))]
    left = [(128 - x, y) for x, y in reversed(right)]
    icon.polygon(d, [(28, 22), (100, 22)] + right + left)
    crack = icon.mask(); d = icon.draw(crack)
    icon.stroke(d, [(66, 24), (58, 46), (72, 60), (56, 82), (66, 98)], 4)
    render(path("ic_event_critted"), [(burst, RED), (icon.cut(shield, crack), STEEL)])

    # Low health: a red heart, mostly drained (the top cut out), a pulse line
    heart = icon.mask(); d = icon.draw(heart)
    pts = []
    for i in range(160):
        t = i / 160 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((64 + x * 3.3, 58 - y * 3.3))
    icon.polygon(d, pts)
    drained = icon.mask(); d = icon.draw(drained)
    icon.polygon(d, [(0, 0), (128, 0), (128, 74), (0, 74)])
    full = icon.cut(heart, drained)
    empty = icon.cut(heart, full)
    line = icon.mask(); d = icon.draw(line)
    icon.stroke(d, [(6, 66), (34, 66), (44, 46), (56, 88), (66, 56), (74, 66), (122, 66)], 6)
    render(path("ic_event_lowhp"), [(empty, GREY), (full, RED), (line, GOLD)])

    # Spell cast: a glowing orb in a cupped hand of waves (a cast's loop)
    orb = icon.mask(); d = icon.draw(orb)
    icon.circle(d, 64, 56, 24)
    sparks = icon.mask(); d = icon.draw(sparks)
    icon.star(d, 30, 26, 12, 4, 4)
    icon.star(d, 100, 30, 9, 3, 4)
    hand = icon.mask(); d = icon.draw(hand)
    icon.arc(d, 64, 56, 44, 20, 160, 10)
    render(path("ic_event_cast"), [(hand, GOLD), (orb, BLUE), (sparks, GOLD)])

    # Slot change: a small wheel, one slice lit
    wheel = icon.mask(); d = icon.draw(wheel)
    icon.arc(d, 64, 64, 44, 0, 360, 14)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        icon.stroke(d, [(64 + 30 * math.cos(a), 64 + 30 * math.sin(a)),
                        (64 + 58 * math.cos(a), 64 + 58 * math.sin(a))], 4)
    lit = icon.mask(); d = icon.draw(lit)
    pts = [(64, 64)] + [(64 + 56 * math.cos(math.radians(a)), 64 + 56 * math.sin(math.radians(a)))
                        for a in range(-112, -67, 3)]
    icon.polygon(d, pts)
    hub = icon.mask(); d = icon.draw(hub)
    icon.circle(d, 64, 64, 14)
    render(path("ic_event_wheel"), [(icon.cut(wheel, lit), STEEL), (lit, GOLD), (hub, GOLD)])

    # Gathering: a pickaxe, a herb leaf beside it
    leaf = icon.mask(); d = icon.draw(leaf)
    pts = []
    for i in range(40):
        t = i / 40 * 2 * math.pi
        x, y = 22 * math.cos(t), 11 * math.sin(t)
        a = math.radians(-40)
        pts.append((94 + x * math.cos(a) - y * math.sin(a), 96 + x * math.sin(a) + y * math.cos(a)))
    icon.polygon(d, pts)
    stem = icon.mask(); d = icon.draw(stem)
    icon.stroke(d, [(70, 120), (80, 108), (94, 96)], 5)
    handle = icon.mask(); d = icon.draw(handle)
    icon.stroke(d, [(22, 112), (80, 40)], 10)
    head = icon.mask(); d = icon.draw(head)
    icon.stroke(d, [(52, 16), (82, 26), (104, 48), (114, 70)], 11)
    render(path("ic_event_gather"), [(leaf, GREEN), (stem, GREEN), (handle, LEATHER), (head, STEEL)])

    # Crafting: a hammer over an anvil
    anvil = icon.mask(); d = icon.draw(anvil)
    icon.polygon(d, [(14, 74), (98, 74), (114, 66), (114, 84), (92, 90), (84, 98), (88, 112), (40, 112),
                     (44, 98), (36, 90), (14, 86)])
    handle = icon.mask(); d = icon.draw(handle)
    icon.stroke(d, [(30, 58), (82, 16)], 9)
    hammer = icon.mask(); d = icon.draw(hammer)
    icon.polygon(d, [(70, 6), (104, 36), (92, 48), (58, 18)])
    render(path("ic_event_craft"), [(anvil, STEEL), (handle, LEATHER), (hammer, GOLD)])

    # Interrupted: the cast's orb struck through by a red bolt
    orb = icon.mask(); d = icon.draw(orb)
    icon.circle(d, 64, 64, 32)
    bolt = icon.mask(); d = icon.draw(bolt)
    icon.polygon(d, [(84, 8), (52, 62), (70, 62), (40, 120), (90, 52), (70, 52), (96, 8)])
    render(path("ic_event_interrupted"), [(icon.cut(orb, bolt), BLUE), (bolt, RED)])

    # Cancelled: the orb dimmed, a curved arrow turning back
    orb = icon.mask(); d = icon.draw(orb)
    icon.circle(d, 72, 70, 26)
    back = icon.mask(); d = icon.draw(back)
    icon.arc(d, 64, 64, 46, 150, 330, 10)
    icon.polygon(d, [(14, 70), (42, 70), (28, 96)])
    render(path("ic_event_cancelled"), [(orb, GREY), (back, GOLD)])

    # Pushed back: the cast bar knocked back, a double arrow over it
    bar = icon.mask(); d = icon.draw(bar)
    icon.polygon(d, [(14, 74), (114, 74), (114, 100), (14, 100)])
    fill = icon.mask(); d = icon.draw(fill)
    icon.polygon(d, [(18, 78), (64, 78), (64, 96), (18, 96)])
    arrows = icon.mask(); d = icon.draw(arrows)
    icon.stroke(d, [(70, 24), (50, 42), (70, 60)], 9)
    icon.stroke(d, [(98, 24), (78, 42), (98, 60)], 9)
    render(path("ic_event_pushback"), [(bar, STEEL), (fill, GOLD), (arrows, RED)])


def leaf_shape(d, cx, cy, rx, ry, turn):
    pts = []
    for i in range(40):
        t = i / 40 * 2 * math.pi
        x, y = rx * math.cos(t), ry * math.sin(t)
        a = math.radians(turn)
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    icon.polygon(d, pts)


def actions():
    """The action patterns' icons (gathering, crafting)"""
    # Rustle (herbalism): two leaves and a stem, a pull arrow
    m = icon.mask(); d = icon.draw(m)
    leaf_shape(d, 46, 76, 24, 11, -35)
    leaf_shape(d, 82, 76, 24, 11, 35)
    icon.stroke(d, [(64, 118), (64, 64)], 6)
    a = icon.mask(); d = icon.draw(a)
    icon.polygon(d, [(64, 10), (86, 36), (72, 36), (72, 52), (56, 52), (56, 36), (42, 36)])
    render(path("ic_vibe_pluck"), [(m, GREEN), (a, GOLD)])

    # Pickaxe (mining): the pick, a spark where it lands
    h = icon.mask(); d = icon.draw(h)
    icon.stroke(d, [(22, 112), (80, 40)], 10)
    hd = icon.mask(); d = icon.draw(hd)
    icon.stroke(d, [(52, 16), (82, 26), (104, 48), (114, 70)], 11)
    sp = icon.mask(); d = icon.draw(sp)
    icon.star(d, 104, 100, 18, 7, 6)
    render(path("ic_vibe_pickaxe"), [(h, LEATHER), (hd, STEEL), (sp, GOLD)])

    # Cut (skinning): a curved knife, its handle
    blade = icon.mask(); d = icon.draw(blade)
    icon.polygon(d, [(34, 82), (88, 24), (110, 18), (100, 40), (48, 94)])
    hdl = icon.mask(); d = icon.draw(hdl)
    icon.stroke(d, [(18, 110), (40, 88)], 13)
    render(path("ic_vibe_skin"), [(blade, STEEL), (hdl, LEATHER)])

    # Line (fishing): a hook on its line, a bobber
    line = icon.mask(); d = icon.draw(line)
    icon.stroke(d, [(64, 6), (64, 76)], 5)
    icon.arc(d, 52, 84, 14, -10, 200, 7)
    bob = icon.mask(); d = icon.draw(bob)
    icon.circle(d, 64, 40, 13)
    render(path("ic_vibe_reel"), [(line, STEEL), (bob, RED)])

    # Tumbler (opening): a key
    k = icon.mask(); d = icon.draw(k)
    icon.circle(d, 38, 64, 22)
    icon.stroke(d, [(56, 64), (114, 64)], 11)
    icon.stroke(d, [(94, 64), (94, 84)], 9)
    icon.stroke(d, [(110, 64), (110, 80)], 9)
    hole = icon.mask(); d = icon.draw(hole)
    icon.circle(d, 38, 64, 9)
    render(path("ic_vibe_click"), [(icon.cut(k, hole), GOLD)])

    # Anvil (blacksmithing): a hammer striking, sparks
    hdl = icon.mask(); d = icon.draw(hdl)
    icon.stroke(d, [(22, 108), (74, 56)], 10)
    hd = icon.mask(); d = icon.draw(hd)
    icon.polygon(d, [(58, 30), (96, 68), (82, 82), (44, 44)])
    sp = icon.mask(); d = icon.draw(sp)
    icon.star(d, 104, 24, 14, 5, 6)
    icon.star(d, 116, 52, 9, 3, 5)
    render(path("ic_vibe_hammer"), [(hdl, LEATHER), (hd, STEEL), (sp, GOLD)])

    # Stitch (tailoring): a needle, its thread in loops
    n = icon.mask(); d = icon.draw(n)
    icon.stroke(d, [(28, 108), (104, 20)], 7)
    eye = icon.mask(); d = icon.draw(eye)
    icon.circle(d, 98, 28, 3.5)
    th = icon.mask(); d = icon.draw(th)
    icon.arc(d, 70, 86, 16, 0, 180, 5)
    icon.arc(d, 38, 86, 16, 180, 360, 5)
    render(path("ic_vibe_sew"), [(icon.cut(n, eye), STEEL), (th, RED)])

    # Punch (leatherworking): a hide, an awl through it
    hide = icon.mask(); d = icon.draw(hide)
    icon.polygon(d, [(18, 40), (44, 30), (64, 40), (86, 30), (112, 42), (104, 70), (112, 98), (84, 108),
                     (64, 98), (42, 108), (16, 96), (26, 70)])
    holes = icon.mask(); d = icon.draw(holes)
    for x in (42, 64, 86):
        icon.circle(d, x, 70, 5)
    render(path("ic_vibe_punch"), [(icon.cut(hide, holes), LEATHER)])

    # Bubbles (alchemy): a flask, bubbles rising
    f = icon.mask(); d = icon.draw(f)
    icon.circle(d, 64, 84, 32)
    icon.polygon(d, [(54, 18), (74, 18), (74, 60), (54, 60)])
    liq = icon.mask(); d = icon.draw(liq)
    icon.circle(d, 64, 88, 24)
    b = icon.mask(); d = icon.draw(b)
    for x, y, r in ((54, 84, 5), (72, 94, 4), (66, 74, 3.5)):
        icon.circle(d, x, y, r)
    render(path("ic_vibe_bubble"), [(f, STEEL), (icon.cut(liq, b), GREEN)])

    # Sizzle (cooking): a pan, heat waves over it
    pan = icon.mask(); d = icon.draw(pan)
    leaf_shape(d, 56, 88, 40, 14, 0)
    icon.stroke(d, [(92, 86), (122, 76)], 9)
    w = icon.mask(); d = icon.draw(w)
    for x in (40, 58, 76):
        icon.stroke(d, [(x, 66), (x - 6, 54), (x + 2, 42), (x - 4, 30)], 5)
    render(path("ic_vibe_sizzle"), [(pan, STEEL), (w, RED)])

    # Ratchet (engineering): a gear
    g = icon.mask(); d = icon.draw(g)
    icon.star(d, 64, 64, 50, 38, 10, turn=-90)
    icon.circle(d, 64, 64, 40)
    hole = icon.mask(); d = icon.draw(hole)
    icon.circle(d, 64, 64, 14)
    render(path("ic_vibe_gears"), [(icon.cut(g, hole), STEEL)])

    # Shimmer (enchanting): a big sparkle, two small
    m = icon.mask(); d = icon.draw(m)
    icon.star(d, 60, 66, 46, 12, 4)
    icon.star(d, 102, 28, 16, 5, 4)
    icon.star(d, 102, 102, 12, 4, 4)
    render(path("ic_vibe_shimmer"), [(m, BLUE)])


def spells():
    """Spell actions: one per family of spells (fire, frost...)"""
    # Kindle (fire): a flame, two tongues licking up
    f = icon.mask(); d = icon.draw(f)
    pts = [(64 + 40 * math.cos(math.radians(a)), 84 + 34 * math.sin(math.radians(a))) for a in range(-10, 191, 6)]
    pts += [(26, 70), (34, 46), (44, 58), (52, 20), (66, 46), (76, 8), (90, 44), (98, 36), (104, 74)]
    icon.polygon(d, pts)
    core = icon.mask(); d = icon.draw(core)
    pts = [(64 + 20 * math.cos(math.radians(a)), 96 + 16 * math.sin(math.radians(a))) for a in range(-10, 191, 6)]
    pts += [(46, 88), (56, 62), (64, 76), (72, 54), (84, 90)]
    icon.polygon(d, pts)
    render(path("ic_vibe_kindle"), [(f, RED), (core, GOLD)])

    # Frost: a snowflake
    m = icon.mask(); d = icon.draw(m)
    for k in range(6):
        a = math.radians(k * 60 - 90)
        x1, y1 = 64 + 52 * math.cos(a), 64 + 52 * math.sin(a)
        icon.stroke(d, [(64, 64), (x1, y1)], 9)
        for side in (-1, 1):
            b2 = a + side * math.radians(40)
            mx, my = 64 + 32 * math.cos(a), 64 + 32 * math.sin(a)
            icon.stroke(d, [(mx, my), (mx + 16 * math.cos(b2), my + 16 * math.sin(b2))], 6)
    render(path("ic_vibe_frost"), [(m, BLUE)])

    # Arcane: three missiles streaking in
    m = icon.mask(); d = icon.draw(m)
    for i, (x, y) in enumerate(((88, 30), (100, 64), (88, 98))):
        icon.circle(d, x, y, 11)
        icon.stroke(d, [(x - 12, y), (x - 62 + i * 4, y + (y - 64) * 0.4)], 5)
    render(path("ic_vibe_arcane"), [(m, BLUE)])

    # Shadow: a dark orb in a swirl
    orb = icon.mask(); d = icon.draw(orb)
    icon.circle(d, 64, 64, 30)
    sw = icon.mask(); d = icon.draw(sw)
    icon.arc(d, 64, 64, 46, 200, 330, 9)
    icon.arc(d, 64, 64, 46, 20, 150, 9)
    render(path("ic_vibe_shadow"), [(sw, GREY), (orb, ((200, 150, 255), (110, 50, 170), (45, 15, 80)))])

    # Radiance (holy, resurrection): a sun
    m = icon.mask(); d = icon.draw(m)
    icon.circle(d, 64, 64, 26)
    for k in range(12):
        a = math.radians(k * 30)
        icon.stroke(d, [(64 + 36 * math.cos(a), 64 + 36 * math.sin(a)),
                        (64 + (54 if k % 2 == 0 else 46) * math.cos(a), 64 + (54 if k % 2 == 0 else 46) * math.sin(a))], 7)
    render(path("ic_vibe_radiance"), [(m, GOLD)])

    # Mend (healing): a green cross in a soft ring
    ring = icon.mask(); d = icon.draw(ring)
    icon.arc(d, 64, 64, 50, 0, 360, 7)
    c = icon.mask(); d = icon.draw(c)
    icon.polygon(d, [(52, 26), (76, 26), (76, 52), (102, 52), (102, 76), (76, 76), (76, 102), (52, 102),
                     (52, 76), (26, 76), (26, 52), (52, 52)])
    render(path("ic_vibe_mend"), [(ring, GOLD), (c, GREEN)])

    # Static (nature, lightning): a bolt
    m = icon.mask(); d = icon.draw(m)
    icon.polygon(d, [(76, 6), (32, 70), (60, 70), (46, 122), (98, 52), (68, 52), (88, 6)])
    render(path("ic_vibe_static"), [(m, GOLD)])

    # Draw (aimed shots): a bow drawn back, an arrow on its string
    bow = icon.mask(); d = icon.draw(bow)
    icon.arc(d, 34, 64, 56, -64, 64, 10)
    st = icon.mask(); d = icon.draw(st)
    icon.stroke(d, [(58, 14), (18, 64), (58, 114)], 3)
    ar = icon.mask(); d = icon.draw(ar)
    icon.stroke(d, [(18, 64), (106, 64)], 6)
    icon.polygon(d, [(100, 50), (124, 64), (100, 78)])
    render(path("ic_vibe_draw"), [(st, GREY), (bow, LEATHER), (ar, STEEL)])

    # Hearth (Hearthstone, teleports): a hearthstone
    stone = icon.mask(); d = icon.draw(stone)
    ell = [(64 + 46 * math.cos(math.radians(a)), 66 + 38 * math.sin(math.radians(a))) for a in range(0, 360, 6)]
    icon.polygon(d, ell)
    sw = icon.mask(); d = icon.draw(sw)
    pts = [(64 + (4 + t * 0.9) * math.cos(math.radians(t * 12)), 66 + (4 + t * 0.75) * math.sin(math.radians(t * 12)))
           for t in range(0, 34)]
    icon.stroke(d, pts, 6)
    render(path("ic_vibe_hearth"), [(icon.cut(stone, sw), GREY), (sw, BLUE)])

    # Ritual (summoning): a rune circle
    ring = icon.mask(); d = icon.draw(ring)
    icon.arc(d, 64, 64, 50, 0, 360, 7)
    st = icon.mask(); d = icon.draw(st)
    pts = []
    for k in range(6):
        a = math.radians(-90 + k * 144)
        pts.append((64 + 44 * math.cos(a), 64 + 44 * math.sin(a)))
    icon.stroke(d, pts, 5)
    render(path("ic_vibe_ritual"), [(ring, RED), (st, GOLD)])


def weapons():
    """Shots, one per ranged weapon (Shooting's Match the weapon)"""
    # Bowstring (bow): a bow just loosed, its string still buzzing
    bow = icon.mask(); d = icon.draw(bow)
    icon.arc(d, 30, 64, 56, -64, 64, 10)
    st = icon.mask(); d = icon.draw(st)
    icon.stroke(d, [(54 + (4 if i % 2 else -4) if 0 < i < 12 else 54, 14 + i * 100 / 12) for i in range(13)], 3)
    hum = icon.mask(); d = icon.draw(hum)
    waves(d, 92, 64, 2, 16, 14, 6, 40)
    render(path("ic_vibe_string"), [(st, GREY), (bow, LEATHER), (hum, GOLD)])

    # Latch (crossbow): a stock, its limbs across, a bolt on it
    stock = icon.mask(); d = icon.draw(stock)
    icon.stroke(d, [(18, 96), (92, 50)], 12)
    limbs = icon.mask(); d = icon.draw(limbs)
    icon.arc(d, 80, 58, 40, 150, 300, 9)
    bolt = icon.mask(); d = icon.draw(bolt)
    icon.stroke(d, [(52, 74), (110, 38)], 5)
    icon.polygon(d, [(104, 30), (122, 28), (114, 46)])
    render(path("ic_vibe_latch"), [(stock, LEATHER), (limbs, STEEL), (bolt, GOLD)])

    # Recoil (gun): a blunderbuss, a muzzle flash
    barrel = icon.mask(); d = icon.draw(barrel)
    icon.polygon(d, [(30, 52), (94, 52), (100, 44), (100, 70), (94, 64), (30, 64)])
    grip = icon.mask(); d = icon.draw(grip)
    icon.polygon(d, [(12, 54), (34, 50), (40, 64), (30, 98), (12, 92)])
    flash = icon.mask(); d = icon.draw(flash)
    icon.star(d, 112, 57, 16, 6, 6, turn=0)
    render(path("ic_vibe_recoil"), [(grip, LEATHER), (barrel, STEEL), (flash, RED)])

    # Zap (wand): a wand, a spark at its tip
    wand = icon.mask(); d = icon.draw(wand)
    icon.stroke(d, [(18, 110), (76, 52)], 10)
    spark = icon.mask(); d = icon.draw(spark)
    icon.star(d, 90, 38, 28, 9, 4, turn=-90)
    render(path("ic_vibe_zap"), [(wand, LEATHER), (spark, BLUE)])

    # Toss (thrown): a throwing knife, spinning
    blade = icon.mask(); d = icon.draw(blade)
    icon.polygon(d, [(64, 14), (76, 58), (64, 70), (52, 58)])
    hilt = icon.mask(); d = icon.draw(hilt)
    icon.stroke(d, [(44, 72), (84, 72)], 7)
    icon.stroke(d, [(64, 74), (64, 100)], 8)
    spin = icon.mask(); d = icon.draw(spin)
    icon.arc(d, 64, 64, 54, 200, 300, 7)
    icon.arc(d, 64, 64, 54, 20, 120, 7)
    render(path("ic_vibe_toss"), [(spin, GOLD), (blade, STEEL), (hilt, LEATHER)])

    # Shooting (the event): a target, a shot streaking into it
    ring = icon.mask(); d = icon.draw(ring)
    icon.arc(d, 74, 64, 44, 0, 360, 8)
    icon.arc(d, 74, 64, 24, 0, 360, 7)
    core = icon.mask(); d = icon.draw(core)
    icon.circle(d, 74, 64, 9)
    streak = icon.mask(); d = icon.draw(streak)
    icon.stroke(d, [(8, 64), (58, 64)], 7)
    icon.stroke(d, [(14, 46), (44, 52)], 4)
    icon.stroke(d, [(14, 82), (44, 76)], 4)
    render(path("ic_event_shot"), [(ring, STEEL), (core, RED), (streak, GOLD)])


def blade(d, x0, y0, x1, y1, width=10):
    """A sword's blade from hilt (x0, y0) to point (x1, y1)"""
    icon.stroke(d, [(x0, y0), (x1, y1)], width)


def moves():
    """Moves, one per kind of instant ability (Abilities' Match the move)"""
    # Slash (Heroic Strike): a blade brought down, its arc behind it
    arc = icon.mask(); d = icon.draw(arc)
    icon.arc(d, 40, 88, 64, -80, -10, 8)
    sw = icon.mask(); d = icon.draw(sw)
    blade(d, 30, 98, 98, 30)
    hilt = icon.mask(); d = icon.draw(hilt)
    icon.stroke(d, [(18, 88), (40, 110)], 8)
    icon.stroke(d, [(14, 114), (26, 102)], 9)
    render(path("ic_vibe_slash"), [(arc, GOLD), (sw, STEEL), (hilt, LEATHER)])

    # Cleave: a wide sweep, an axe head at its end
    arc = icon.mask(); d = icon.draw(arc)
    icon.arc(d, 64, 96, 54, 200, 340, 9)
    head = icon.mask(); d = icon.draw(head)
    icon.polygon(d, [(96, 26), (122, 40), (112, 70), (98, 52)])
    render(path("ic_vibe_cleave"), [(arc, GOLD), (head, STEEL)])

    # Stab: a dagger thrust forward, speed lines behind
    sw = icon.mask(); d = icon.draw(sw)
    icon.polygon(d, [(54, 56), (116, 64), (54, 72)])
    hilt = icon.mask(); d = icon.draw(hilt)
    icon.stroke(d, [(50, 44), (50, 84)], 7)
    icon.stroke(d, [(28, 64), (50, 64)], 9)
    lines = icon.mask(); d = icon.draw(lines)
    for y in (40, 88):
        icon.stroke(d, [(10, y), (38, y)], 5)
    render(path("ic_vibe_stab"), [(lines, GOLD), (sw, STEEL), (hilt, LEATHER)])

    # Rend: three claw marks
    m = icon.mask(); d = icon.draw(m)
    for dx in (-26, 0, 26):
        icon.stroke(d, [(48 + dx, 18), (64 + dx, 64), (72 + dx, 110)], 8)
    render(path("ic_vibe_rend"), [(m, RED)])

    # Slam (Thunder Clap): a fist on the ground, the shock rolling out
    ground = icon.mask(); d = icon.draw(ground)
    icon.stroke(d, [(8, 104), (120, 104)], 6)
    fist = icon.mask(); d = icon.draw(fist)
    icon.polygon(d, [(46, 54), (82, 54), (82, 94), (46, 94)])
    wave = icon.mask(); d = icon.draw(wave)
    waves(d, 64, 94, 2, 34, 16, 6, 40)
    render(path("ic_vibe_slam"), [(ground, GREY), (fist, STEEL), (wave, GOLD)])

    # Bash (Shield Bash, Hammer of Justice): a round shield, a star of impact
    shield = icon.mask(); d = icon.draw(shield)
    icon.circle(d, 52, 68, 36)
    boss = icon.mask(); d = icon.draw(boss)
    icon.circle(d, 52, 68, 10)
    hit = icon.mask(); d = icon.draw(hit)
    icon.star(d, 98, 36, 22, 9, 6)
    render(path("ic_vibe_bash"), [(icon.cut(shield, boss), STEEL), (boss, GOLD), (hit, RED)])

    # Charge: an arrow rushing in, speed lines, a hit at its end
    m = icon.mask(); d = icon.draw(m)
    icon.polygon(d, [(34, 50), (88, 50), (88, 34), (118, 64), (88, 94), (88, 78), (34, 78)])
    lines = icon.mask(); d = icon.draw(lines)
    for y in (42, 64, 86):
        icon.stroke(d, [(8, y), (24, y)], 5)
    render(path("ic_vibe_charge"), [(lines, GOLD), (m, RED)])

    # Whirl (Whirlwind): two blades going round
    m = icon.mask(); d = icon.draw(m)
    icon.arc(d, 64, 64, 46, 20, 160, 8)
    icon.arc(d, 64, 64, 46, 200, 340, 8)
    tips = icon.mask(); d = icon.draw(tips)
    icon.polygon(d, [(16, 46), (30, 58), (8, 64)])
    icon.polygon(d, [(112, 82), (98, 70), (120, 64)])
    render(path("ic_vibe_whirl"), [(m, GOLD), (tips, STEEL)])

    # Flurry (Eviscerate): combo points, the last one big
    m = icon.mask(); d = icon.draw(m)
    for x, r in ((20, 8), (42, 10), (66, 12)):
        icon.circle(d, x, 64, r)
    big = icon.mask(); d = icon.draw(big)
    icon.star(d, 100, 64, 24, 10, 8)
    render(path("ic_vibe_flurry"), [(m, GOLD), (big, RED)])

    # Shock: a jagged bolt into a burst
    bolt = icon.mask(); d = icon.draw(bolt)
    icon.stroke(d, [(10, 30), (44, 52), (36, 70), (78, 84)], 8)
    hit = icon.mask(); d = icon.draw(hit)
    icon.star(d, 94, 90, 24, 10, 8)
    render(path("ic_vibe_shock"), [(bolt, BLUE), (hit, GOLD)])

    # Burst (Frost Nova, shouts): rings spreading out from a point
    core = icon.mask(); d = icon.draw(core)
    icon.circle(d, 64, 64, 12)
    rings = icon.mask(); d = icon.draw(rings)
    icon.arc(d, 64, 64, 32, 0, 360, 7)
    icon.arc(d, 64, 64, 52, 0, 360, 5)
    render(path("ic_vibe_burst"), [(rings, BLUE), (core, GOLD)])

    # Seal (Seal of Righteousness): a seal's ring, light inside
    ring = icon.mask(); d = icon.draw(ring)
    icon.arc(d, 64, 64, 46, 0, 360, 8)
    light = icon.mask(); d = icon.draw(light)
    icon.star(d, 64, 64, 30, 10, 4)
    render(path("ic_vibe_seal"), [(ring, GOLD), (light, GOLD)])

    # Judgement: a hammer of light coming down
    handle = icon.mask(); d = icon.draw(handle)
    icon.stroke(d, [(28, 106), (70, 60)], 9)
    head = icon.mask(); d = icon.draw(head)
    icon.polygon(d, [(58, 30), (88, 58), (104, 42), (74, 14)])
    rays = icon.mask(); d = icon.draw(rays)
    for a in (-20, 20, 60):
        r = math.radians(a)
        icon.stroke(d, [(96 + 16 * math.cos(r), 70 + 16 * math.sin(r)), (96 + 28 * math.cos(r), 70 + 28 * math.sin(r))], 5)
    render(path("ic_vibe_judge"), [(handle, LEATHER), (head, GOLD), (rays, GOLD)])

    # Ward (shields): a dome over a figure's ground
    dome = icon.mask(); d = icon.draw(dome)
    icon.arc(d, 64, 96, 50, 180, 360, 8)
    ground = icon.mask(); d = icon.draw(ground)
    icon.stroke(d, [(8, 98), (120, 98)], 6)
    glint = icon.mask(); d = icon.draw(glint)
    icon.star(d, 48, 66, 12, 4, 4)
    render(path("ic_vibe_ward"), [(dome, BLUE), (ground, GREY), (glint, GOLD)])

    # Hex (curses, poisons): a drip of venom, a spiral
    drop = icon.mask(); d = icon.draw(drop)
    pts = [(64 + 26 * math.cos(math.radians(a)), 82 + 26 * math.sin(math.radians(a))) for a in range(-30, 211, 6)]
    icon.polygon(d, pts + [(64, 16)])
    sw = icon.mask(); d = icon.draw(sw)
    pts = [(64 + (2 + t * 0.6) * math.cos(math.radians(t * 18)), 82 + (2 + t * 0.6) * math.sin(math.radians(t * 18)))
           for t in range(0, 26)]
    icon.stroke(d, pts, 4)
    render(path("ic_vibe_hex"), [(icon.cut(drop, sw), GREEN), (sw, GREY)])

    # Abilities (the event): a sword and a fist of light crossed
    sw = icon.mask(); d = icon.draw(sw)
    blade(d, 30, 100, 104, 26)
    hilt = icon.mask(); d = icon.draw(hilt)
    icon.stroke(d, [(18, 88), (42, 112)], 8)
    spark = icon.mask(); d = icon.draw(spark)
    icon.star(d, 92, 92, 22, 8, 4)
    render(path("ic_event_instant"), [(sw, STEEL), (hilt, LEATHER), (spark, GOLD)])


def rest():
    """Eating and drinking: the events' icons and their patterns'"""
    # Eating: a drumstick, the bone's knob below
    meat = icon.mask(); d = icon.draw(meat)
    leaf_shape(d, 76, 52, 40, 28, -45)
    bone = icon.mask(); d = icon.draw(bone)
    icon.stroke(d, [(52, 78), (28, 102)], 12)
    icon.circle(d, 20, 100, 10)
    icon.circle(d, 30, 112, 10)
    render(path("ic_event_eat"), [(meat, LEATHER), (bone, GREY)])

    # Drinking: a mug of water, its handle, a drop above
    mug = icon.mask(); d = icon.draw(mug)
    icon.polygon(d, [(26, 40), (86, 40), (82, 114), (30, 114)])
    icon.arc(d, 88, 72, 18, -80, 80, 9)
    water = icon.mask(); d = icon.draw(water)
    icon.polygon(d, [(32, 52), (80, 52), (78, 74), (34, 74)])
    drop = icon.mask(); d = icon.draw(drop)
    pts = [(56 + 10 * math.cos(math.radians(a)), 22 + 10 * math.sin(math.radians(a))) for a in range(-30, 211, 6)]
    icon.polygon(d, pts + [(56, 0)])
    render(path("ic_event_drink"), [(icon.cut(mug, water), STEEL), (water, BLUE), (drop, BLUE)])

    # Munch: an apple, a bite out of its side
    apple = icon.mask(); d = icon.draw(apple)
    icon.circle(d, 52, 72, 38)
    icon.circle(d, 76, 72, 38)
    bite = icon.mask(); d = icon.draw(bite)
    icon.circle(d, 116, 66, 16)
    icon.circle(d, 112, 92, 14)
    stem = icon.mask(); d = icon.draw(stem)
    icon.stroke(d, [(64, 40), (66, 18)], 6)
    lf = icon.mask(); d = icon.draw(lf)
    leaf_shape(d, 82, 22, 14, 7, -25)
    render(path("ic_vibe_chew"), [(icon.cut(apple, bite), RED), (stem, LEATHER), (lf, GREEN)])

    # Gulp: two drops falling, ripples where they land
    drops = icon.mask(); d = icon.draw(drops)
    for cx, cy, r in ((48, 46, 14), (82, 30, 10)):
        pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(-30, 211, 6)]
        icon.polygon(d, pts + [(cx, cy - 2.4 * r)])
    rip = icon.mask(); d = icon.draw(rip)
    icon.arc(d, 64, 96, 20, 200, 340, 6)
    icon.arc(d, 64, 100, 40, 200, 340, 6)
    render(path("ic_vibe_gulp"), [(drops, BLUE), (rip, STEEL)])


if __name__ == "__main__":
    patterns()
    actions()
    spells()
    weapons()
    moves()
    events()
    rest()
