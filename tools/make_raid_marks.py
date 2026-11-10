"""Raid markers in the look of Immersion's quest arrow: each a cut shape, two tones (its top left face lit,
the rest in shade), a thin gold edge, as the arrow's gem has. Stars, circles, diamonds... in the game's own
colours so a raid still reads them at a glance.
  ic_raid_marks   one sheet laid out as the game's UI-RaidTargetingIcons (4 x 4 cells of 64 px, the markers
                  in the first two rows: 1 star, 2 circle, 3 diamond, 4 triangle / 5 moon, 6 square, 7 cross,
                  8 skull), so the game's own SetRaidTargetIconTexture picks a marker on it, the number secret or not

Drawn 4x and scaled down (smooth edges), 256 x 256, transparent, 32-bit TGA.
Run: python3 tools/make_raid_marks.py   (needs Pillow)
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
SIZE, SCALE = 64, 4
S = SIZE * SCALE
EDGE = (232, 196, 110, 255)         # the header's gold
EDGE_W = 3 * SCALE // 2


def P(x, y):
    return (x * S, y * S)


def poly(points):
    return [P(x, y) for x, y in points]


def mask_of(fn):
    m = Image.new("L", (S, S), 0)
    fn(ImageDraw.Draw(m))
    return m


def star(cx, cy, outer, inner, points=4, turn=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = turn + i * math.pi / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def shape_star(d):
    d.polygon(poly(star(0.5, 0.5, 0.46, 0.17)), fill=255)


def shape_circle(d):
    d.ellipse([0.08 * S, 0.08 * S, 0.92 * S, 0.92 * S], fill=255)


def shape_diamond(d):
    d.polygon(poly([(0.5, 0.05), (0.88, 0.5), (0.5, 0.95), (0.12, 0.5)]), fill=255)


def shape_triangle(d):
    d.polygon(poly([(0.5, 0.07), (0.93, 0.88), (0.07, 0.88)]), fill=255)


def shape_moon(d):
    d.ellipse([0.1 * S, 0.08 * S, 0.9 * S, 0.92 * S], fill=255)
    d.ellipse([0.34 * S, 0.0 * S, 1.06 * S, 0.84 * S], fill=0)


def shape_square(d):
    d.polygon(poly([(0.14, 0.14), (0.86, 0.14), (0.86, 0.86), (0.14, 0.86)]), fill=255)


def shape_cross(d):
    w = 0.17
    a, b = 0.1, 0.9
    for (x0, y0, x1, y1) in ((a, a, b, b), (a, b, b, a)):
        dx, dy = x1 - x0, y1 - y0
        n = math.hypot(dx, dy)
        nx, ny = -dy / n * w / 2, dx / n * w / 2
        d.polygon(poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]), fill=255)


def shape_skull(d):
    # the cranium and the jaw as one cut shape; the eyes and the nose cut out, two notches for the teeth
    d.ellipse([0.14 * S, 0.06 * S, 0.86 * S, 0.68 * S], fill=255)
    d.polygon(poly([(0.28, 0.52), (0.72, 0.52), (0.68, 0.92), (0.32, 0.92)]), fill=255)
    for ex in (0.355, 0.645):
        d.ellipse([(ex - 0.115) * S, 0.33 * S, (ex + 0.115) * S, 0.57 * S], fill=0)
    d.polygon(poly([(0.5, 0.58), (0.44, 0.7), (0.56, 0.7)]), fill=0)
    for tx in (0.43, 0.57):
        d.polygon(poly([(tx - 0.012, 0.8), (tx + 0.012, 0.8), (tx + 0.012, 0.93), (tx - 0.012, 0.93)]), fill=0)


# (shape, the lit colour, the shade colour)
MARKS = [
    (shape_star, (255, 233, 120), (224, 178, 38)),
    (shape_circle, (255, 176, 84), (222, 112, 20)),
    (shape_diamond, (222, 150, 255), (150, 70, 200)),
    (shape_triangle, (150, 236, 120), (60, 160, 50)),
    (shape_moon, (236, 244, 255), (150, 176, 214)),
    (shape_square, (130, 190, 255), (50, 110, 210)),
    (shape_cross, (255, 130, 110), (192, 36, 36)),
    (shape_skull, (255, 252, 240), (186, 180, 164)),
]


def lit_half(cx=0.5, cy=0.5):
    # (the lit face: the shape's top left, cut on a line tilted as the quest arrow's light)
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(poly([(0, 0), (1, 0), (1, 0.18), (0.2, 1), (0, 1)]), fill=255)
    return m


def make(index):
    fn, lit, shade = MARKS[index]
    shape = mask_of(fn)
    # the gold edge: the shape grown
    grown = shape.filter(ImageFilter.MaxFilter(EDGE_W * 2 + 1)) if EDGE_W else shape
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    im.paste(Image.new("RGBA", (S, S), EDGE), mask=grown)
    im.paste(Image.new("RGBA", (S, S), shade + (255,)), mask=shape)
    face = ImageChops.multiply(shape, lit_half())
    im.paste(Image.new("RGBA", (S, S), lit + (255,)), mask=face)
    # (the cut-outs stay holes: the skull's eyes show through to the edge colour's shade)
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    return None, im


if __name__ == "__main__":
    made = [make(i) for i in range(8)]
    sheet = Image.new("RGBA", (SIZE * 4, SIZE * 4), (0, 0, 0, 0))
    for i, (_, im) in enumerate(made):
        sheet.paste(im, ((i % 4) * SIZE, (i // 4) * SIZE))
    sheet_path = os.path.join(OUT, "ic_raid_marks.tga")
    sheet.save(sheet_path)
    strip = Image.new("RGBA", (8 * 80 + 16, 96), (22, 16, 10, 255))
    for i, (_, im) in enumerate(made):
        strip.alpha_composite(im.resize((72, 72), Image.LANCZOS), (8 + i * 80, 12))
    preview = os.path.join(os.environ.get("TMPDIR", "/tmp"), "raid_marks.png")
    strip.save(preview)
    print("\n".join([sheet_path, preview]))
