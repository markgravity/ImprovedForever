"""The Fishing module's art:
  textures/ic_mod_fishing.tga      the module's icon, 128 x 128, in the designed
      icons' look (import_icons.py: cream + green, a black outline, a soft
      shadow): a fish leaping from the water
  textures/fishing_bobber.tga      the fishing bar's bobber (CastBar.lua),
      128 x 128: the game's (a cork, red and blue feathers, its swivel) on
      dark water, seen round; the stand-in for the game's own model
  textures/fishing_water.tga       that water alone, under the game's model
  dist/logos/Fishing.png           the CurseForge logo, 400 x 400: the
      designed icons' frame and blurred backdrop (another module's, its art
      taken out) with the icon's art in the middle

Run: python3 tools/make_fishing_icons.py [designed icon]   (needs Pillow;
     default ~/Downloads/Icon Map@1x.png, its frame and backdrop reused)
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from import_icons import CREAM, GREEN, INNER  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
TEX = os.path.join(ROOT, "ImprovedForever", "textures")
LOGOS = os.path.join(ROOT, "dist", "logos")
N = 1024                                # (drawn at, then scaled down)
INK = (10, 10, 10, 255)
LINE = 26                               # (the outline, at N)


def shape(points=None, ellipse=None):
    """A shape's mask, N x N"""
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    if points:
        d.polygon(points, fill=255)
    if ellipse:
        d.ellipse(ellipse, fill=255)
    return m


def layer(img, mask, color):
    """A shape on img: its black outline round it, then its fill"""
    ink = mask.filter(ImageFilter.GaussianBlur(LINE * 0.55)).point(lambda v: 255 if v > 6 else 0)
    img.paste(INK, (0, 0), ink)
    img.paste(color, (0, 0), mask)


def module_art():
    """The module's icon's art: a fish leaping from the water, N x N,
    transparent round it"""
    import math
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    fish = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cream, green = CREAM + (255,), GREEN + (255,)
    cy, x0, x1, tall = 470, 150, 700, 190
    # (its body: round at its head, narrowing to its tail)
    top, bottom = [], []
    for i in range(61):
        t = i / 60
        h = tall * (t ** 0.45) * ((1 - t) ** 0.75) / (0.45 ** 0.45 * 0.55 ** 0.75)
        x = x0 + (x1 - x0) * t
        top.append((x, cy - h * 1.05))
        bottom.append((x, cy + h * 0.9))
    body = top + list(reversed(bottom))
    # (its fins and tail, green, under its body)
    tail = [(x1 - 40, cy - 30), (x1 + 190, cy - 190), (x1 + 120, cy), (x1 + 190, cy + 190), (x1 - 40, cy + 30)]
    dorsal = [(330, cy - tall * 0.9), (420, cy - tall - 120), (560, cy - tall - 80), (590, cy - tall * 0.55)]
    belly = [(380, cy + tall * 0.7), (450, cy + tall + 60), (520, cy + tall * 0.6)]
    for part in (tail, dorsal, belly):
        layer(fish, shape(part), green)
    layer(fish, shape(body), cream)
    d = ImageDraw.Draw(fish)
    # (its gill, its eye with a gleam, a green band of scales along it)
    d.arc((250, cy - 120, 370, cy + 110), 300, 60, fill=INK, width=round(LINE * 0.8))
    ex, ey, er = 240, cy - 45, 34
    d.ellipse((ex - er, ey - er, ex + er, ey + er), fill=INK)
    d.ellipse((ex - er * 0.35 - 9, ey - er * 0.35 - 9, ex - er * 0.35 + 9, ey - er * 0.35 + 9), fill=cream)
    for k, x in enumerate((420, 500, 580)):
        r = 46 - 8 * k
        d.arc((x - r, cy - r, x + r, cy + r), 300, 60, fill=GREEN + (255,), width=round(LINE * 0.9))
    # (leaping: tilted up out of the water)
    fish = fish.rotate(16, resample=Image.BICUBIC, center=(N / 2, cy))
    # (the water under it: two ripples, their near halves)
    d = ImageDraw.Draw(img)
    cx, wy = 470, 760
    for rx, ry, wide in ((300, 60, 32), (420, 96, 28)):
        box = (cx - rx, wy - ry, cx + rx, wy + ry)
        grown = (box[0] - LINE, box[1] - LINE, box[2] + LINE, box[3] + LINE)
        d.arc(grown, 8, 172, fill=INK, width=wide + 2 * LINE)
        d.arc(box, 10, 170, fill=cream, width=wide)
    img.alpha_composite(fish)
    return img


def water():
    """Dark water seen round, lighter in its middle"""
    glow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow).ellipse((N * 0.15, N * 0.2, N * 0.85, N * 0.9), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.12))
    return Image.composite(Image.new("RGBA", (N, N), (36, 66, 78, 255)),
                           Image.new("RGBA", (N, N), (14, 26, 32, 255)), glow)


def leaf(p0, p1, width):
    """A feather from p0 to p1: widest a third of the way, pointed at p1"""
    import math
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    side1, side2 = [], []
    for i in range(25):
        t = i / 24
        w = width * math.sin(math.pi * t ** 0.7) * (1 - 0.3 * t)
        x, y = p0[0] + dx * t, p0[1] + dy * t
        side1.append((x + nx * w, y + ny * w))
        side2.append((x - nx * w * 0.6, y - ny * w * 0.6))
    return side1 + list(reversed(side2))


def bar_bobber():
    """The fishing bar's bobber, as the game's (world/goober/g_fishingbobber):
    a cork, red and blue feathers, its swivel; on dark water. The bar shows
    the game's own model over the water when it can (CastBar.lua); this is
    its stand-in"""
    import random
    random.seed(7)
    img = water()
    edge, line = (24, 18, 16, 255), round(N * 0.018)
    cx = N * 0.56
    top_y, bot_y = N * 0.5, N * 0.76
    top_rx, top_ry, bot_rx, bot_ry = N * 0.17, N * 0.06, N * 0.135, N * 0.05
    d = ImageDraw.Draw(img)
    # (its ring on the water)
    d.ellipse((cx - N * 0.33, bot_y - N * 0.07, cx + N * 0.33, bot_y + N * 0.07), outline=(150, 190, 205, 255),
              width=round(N * 0.016))
    # (the feathers, behind: fanned up to the left from its top)
    base = (cx - N * 0.03, top_y - N * 0.01)
    for tip, wide, color in (((N * 0.1, N * 0.2), N * 0.07, (190, 36, 34)),
                             ((N * 0.07, N * 0.33), N * 0.075, (52, 84, 196)),
                             ((N * 0.13, N * 0.45), N * 0.065, (210, 58, 44))):
        m = shape(leaf(base, tip, wide))
        img.paste(edge, (0, 0), m.filter(ImageFilter.GaussianBlur(line * 0.5)).point(lambda v: 255 if v > 6 else 0))
        img.paste(color + (255,), (0, 0), m)
        # (its quill)
        ImageDraw.Draw(img).line((base, tip), fill=tuple(min(255, c + 60) for c in color) + (255,),
                                 width=round(line * 0.5))
    # (the cork: wider at its top, its side shaded, its top lit)
    side = [(cx - top_rx, top_y), (cx + top_rx, top_y), (cx + bot_rx, bot_y), (cx - bot_rx, bot_y)]
    cork = shape(side, (cx - bot_rx, bot_y - bot_ry, cx + bot_rx, bot_y + bot_ry))
    cork = ImageChops.lighter(cork, shape(None, (cx - top_rx, top_y - top_ry, cx + top_rx, top_y + top_ry)))
    img.paste(edge, (0, 0), cork.filter(ImageFilter.GaussianBlur(line * 0.5)).point(lambda v: 255 if v > 6 else 0))
    shade = Image.linear_gradient("L").rotate(90).resize((N, N))     # (dark at its left, light at its right)
    shade = ImageChops.invert(shade)
    tan = Image.composite(Image.new("RGBA", (N, N), (214, 176, 118, 255)),
                          Image.new("RGBA", (N, N), (120, 90, 54, 255)), shade)
    img.paste(tan, (0, 0), cork)
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x = cx + (random.random() * 2 - 1) * bot_rx * 0.95
        y = top_y + N * 0.03 + random.random() * (bot_y - top_y)
        r = N * (0.004 + 0.006 * random.random())
        d.ellipse((x - r, y - r, x + r, y + r), fill=(96, 70, 40, 255))
    d.ellipse((cx - top_rx, top_y - top_ry, cx + top_rx, top_y + top_ry), fill=(226, 194, 138, 255), outline=edge,
              width=round(line * 0.6))
    # (its swivel: a metal shank up from the top, a ring at its end)
    shank = ((cx + N * 0.01, top_y), (cx + N * 0.07, N * 0.2))
    d.line(shank, fill=edge, width=round(N * 0.045))
    d.line(shank, fill=(196, 202, 208, 255), width=round(N * 0.022))
    rx, ry, rr = cx + N * 0.08, N * 0.16, N * 0.045
    d.ellipse((rx - rr, ry - rr, rx + rr, ry + rr), outline=edge, width=round(N * 0.035))
    d.ellipse((rx - rr, ry - rr, rx + rr, ry + rr), outline=(196, 202, 208, 255), width=round(N * 0.016))
    return img


def texture(art, path, size=128, margin=6, shadow=True):
    art = art.crop(art.getbbox())
    k = (size - 2 * margin) / max(art.size)
    art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pos = ((size - art.width) // 2, (size - art.height) // 2)
    if shadow:
        sh = Image.new("L", (size, size), 0)
        sh.paste(art.getchannel("A"), pos)
        sh = sh.filter(ImageFilter.GaussianBlur(2.5)).point(lambda v: min(150, v))
        out.paste((10, 10, 10, 255), (0, 0), sh)
    out.alpha_composite(art, pos)
    out.save(path)
    print("wrote", path)


def backdrop(src):
    """A designed icon with its art taken out: the backdrop round it blurred in"""
    img = Image.open(src).convert("RGB")
    # (the art and its shadow: all inside the frame, clear of its swirls)
    hole = Image.new("L", img.size, 0)
    ImageDraw.Draw(hole).rounded_rectangle(INNER, radius=80, fill=255)
    # (filled from round it, small (the backdrop's a blur anyway): the hole
    # blurred over and over, what's round it put back each time; coarse
    # first, each finer one starting from the one before)
    fill = None
    for step in (60, 24, 12):
        small = (img.width // step, img.height // step)
        kept = img.resize(small, Image.BILINEAR)
        # (grown: the small picture's pixels at its edge have some of the art in them)
        mask = hole.resize(small, Image.BILINEAR).point(lambda v: 255 if v > 0 else 0)
        mask = mask.filter(ImageFilter.MaxFilter(3 if step > 30 else 7))
        start = fill.resize(small, Image.BILINEAR) if fill else Image.new("RGB", small, (40, 30, 20))
        work = Image.composite(start, kept, mask)
        for _ in range(200):
            work = Image.composite(work.filter(ImageFilter.GaussianBlur(1.5)), kept, mask)
        fill = work
    fill = fill.resize(img.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(8))
    # (blended in softly: the backdrop darkens toward the art, as the
    # designed ones do round theirs)
    return Image.composite(fill, img, hole.filter(ImageFilter.GaussianBlur(60)).point(lambda v: min(255, v * 2)))


def logo(art, src, path, size=400):
    bg = backdrop(src).convert("RGBA")
    art = art.crop(art.getbbox())
    w = bg.width * 0.42
    k = w / max(art.size)
    art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
    pos = ((bg.width - art.width) // 2, (bg.height - art.height) // 2)
    sh = Image.new("L", bg.size, 0)
    sh.paste(art.getchannel("A"), pos)
    sh = sh.filter(ImageFilter.GaussianBlur(18)).point(lambda v: min(170, v))
    bg.paste((0, 0, 0, 255), (0, 0), sh)
    bg.alpha_composite(art, pos)
    os.makedirs(LOGOS, exist_ok=True)
    bg.convert("RGB").resize((size, size), Image.LANCZOS).save(path)
    print("wrote", path)


def main():
    src = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/Icon Map@1x.png")
    art = module_art()
    texture(art, os.path.join(TEX, "ic_mod_fishing.tga"))
    texture(bar_bobber(), os.path.join(TEX, "fishing_bobber.tga"), margin=0, shadow=False)
    texture(water(), os.path.join(TEX, "fishing_water.tga"), margin=0, shadow=False)
    if os.path.exists(src):
        logo(art, src, os.path.join(LOGOS, "Fishing.png"))
    else:
        print("missing", src, "(no logo)")


if __name__ == "__main__":
    main()
