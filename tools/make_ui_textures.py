"""The panel's own UI textures (they replace Easy Controller's): rounded box
pieces, buttons, the selection, small marks, the round slot's parts, and
the controller button glyphs used when the client has no atlas for one.

  ic_box3 / ic_box4            rounded fills (32 px, corners of 6 / 8 texels)
  ic_box3_line2 / ic_box4_line1 / ic_box4_line2   their edges
  ic_btn_normal / hover / active, ic_select        128 x 32 nine-slices
  ic_diamond, ic_tri, ic_dot, ic_chip              marks
  ic_slot, ic_disc, ic_hatch, ic_ring_dash, ic_slot_glow   the round slot
  ic_g_<a|b|x|y|lb|rb|lt|rt|ls|rs|dpad|dpad_lr|dpad_up>    button glyphs
  ic_area                      a map area (the Wiki's): a soft fill, a lit rim
  ic_frame_glow, ic_round_glow a glow outside a frame's edge (a 64 x 64
                               nine-slice, corners of 24: the edge at 20) /
                               a circle's (40 across, centred)

Run: python3 tools/make_ui_textures.py   (needs Pillow)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
SS = 4
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def big(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def done(img, w, h, name):
    img.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, name + ".tga"))
    print("wrote", name)


def rr(d, box, r, **kw):
    d.rounded_rectangle([v * SS for v in box], radius=r * SS, **kw)


# Rounded boxes: white, tinted in game -------------------------------------
def boxes():
    for radius, name in ((6, "ic_box3"), (8, "ic_box4")):
        img = big(32, 32)
        rr(ImageDraw.Draw(img), (0, 0, 32, 32), radius, fill=(255, 255, 255, 255))
        done(img, 32, 32, name)
    for radius, width, name in ((6, 4, "ic_box3_line2"), (8, 2, "ic_box4_line1"), (8, 4, "ic_box4_line2")):
        img = big(32, 32)
        rr(ImageDraw.Draw(img), (width / 2, width / 2, 32 - width / 2, 32 - width / 2), radius,
           outline=(255, 255, 255, 255), width=width * SS)
        done(img, 32, 32, name)


# Buttons and the selection: 128 x 32 ---------------------------------------
def buttons():
    looks = {
        "ic_btn_normal": ((22, 17, 12, 235), (96, 74, 46, 255)),
        "ic_btn_hover": ((40, 31, 20, 240), (150, 116, 64, 255)),
        "ic_btn_active": ((58, 42, 16, 245), (242, 196, 60, 255)),
    }
    for name, (fill, edge) in looks.items():
        img = big(128, 32)
        d = ImageDraw.Draw(img)
        rr(d, (1, 1, 127, 31), 6, fill=fill, outline=edge, width=2 * SS)
        # a faint light along the top
        rr(d, (3, 3, 125, 12), 4, fill=(255, 255, 255, 14))
        done(img, 128, 32, name)
    img = big(128, 32)
    d = ImageDraw.Draw(img)
    rr(d, (1, 1, 127, 31), 9, fill=(242, 196, 60, 40), outline=(255, 210, 74, 255), width=2 * SS)
    glow = img.filter(ImageFilter.GaussianBlur(3 * SS))
    done(Image.alpha_composite(glow, img), 128, 32, "ic_select")


# Marks ---------------------------------------------------------------------
def marks():
    img = big(16, 16)
    ImageDraw.Draw(img).polygon([(8 * SS, 0), (16 * SS, 8 * SS), (8 * SS, 16 * SS), (0, 8 * SS)],
                                fill=(255, 255, 255, 255))
    done(img, 16, 16, "ic_diamond")
    img = big(16, 16)
    ImageDraw.Draw(img).polygon([(1 * SS, 4 * SS), (15 * SS, 4 * SS), (8 * SS, 13 * SS)], fill=(255, 255, 255, 255))
    done(img, 16, 16, "ic_tri")
    img = big(32, 32)
    ImageDraw.Draw(img).ellipse((1 * SS, 1 * SS, 31 * SS, 31 * SS), fill=(255, 255, 255, 255))
    done(img, 32, 32, "ic_dot")
    img = big(64, 64)
    rr(ImageDraw.Draw(img), (2, 10, 62, 54), 22, fill=(70, 66, 60, 255), outline=(140, 134, 122, 255), width=2 * SS)
    done(img, 64, 64, "ic_chip")


# The round slot --------------------------------------------------------------
def slot():
    img = big(64, 64)
    d = ImageDraw.Draw(img)
    d.ellipse((2 * SS, 2 * SS, 62 * SS, 62 * SS), fill=(14, 10, 7, 230), outline=(122, 93, 54, 255), width=3 * SS)
    d.ellipse((7 * SS, 7 * SS, 57 * SS, 57 * SS), outline=(44, 32, 20, 255), width=1 * SS)
    done(img, 64, 64, "ic_slot")
    img = big(128, 128)
    d = ImageDraw.Draw(img)
    d.ellipse((2 * SS, 2 * SS, 126 * SS, 126 * SS), fill=(30, 20, 12, 200), outline=(90, 70, 45, 255), width=4 * SS)
    done(img, 128, 128, "ic_disc")
    # Stripes inside a circle (a slot turned off)
    img = big(64, 64)
    d = ImageDraw.Draw(img)
    for k in range(-64, 128, 10):
        d.line([(k * SS, 64 * SS), ((k + 64) * SS, 0)], fill=(255, 255, 255, 120), width=3 * SS)
    mask = big(64, 64)
    ImageDraw.Draw(mask).ellipse((2 * SS, 2 * SS, 62 * SS, 62 * SS), fill=(255, 255, 255, 255))
    img.putalpha(Image.composite(img.split()[3], Image.new("L", img.size, 0), mask.split()[3]))
    done(img, 64, 64, "ic_hatch")
    # A dashed ring
    img = big(64, 64)
    d = ImageDraw.Draw(img)
    for i in range(16):
        a0 = i * 22.5
        d.arc((3 * SS, 3 * SS, 61 * SS, 61 * SS), a0, a0 + 13, fill=(255, 255, 255, 255), width=3 * SS)
    done(img, 64, 64, "ic_ring_dash")
    # A soft glowing ring
    img = big(64, 64)
    ImageDraw.Draw(img).ellipse((10 * SS, 10 * SS, 54 * SS, 54 * SS), outline=(255, 220, 120, 255), width=4 * SS)
    done(img.filter(ImageFilter.GaussianBlur(3 * SS)), 64, 64, "ic_slot_glow")


# A glow round a frame (the Group wheel's pick on its unit frame): only
# outside its edge (the frame itself stays clear), a bright rim on the edge
# fading out to nothing. A rounded box (a 64 x 64 nine-slice, corners of
# 24, the edge at 20) and a round one (the circle 40 across, centred).
def outer_glow(shape, name):
    solid = big(64, 64)
    shape(ImageDraw.Draw(solid), dict(fill=(255, 255, 255, 255)))
    halo = solid.filter(ImageFilter.GaussianBlur(6 * SS))
    a = halo.split()[3].point(lambda v: min(255, int(v * 2.2)))
    rim = big(64, 64)
    shape(ImageDraw.Draw(rim), dict(outline=(255, 255, 255, 255), width=2 * SS))
    rim = rim.filter(ImageFilter.GaussianBlur(0.6 * SS)).split()[3]
    a = Image.composite(Image.new("L", a.size, 255), a, rim)
    # (nothing inside the shape)
    inside = solid.split()[3].filter(ImageFilter.MinFilter(2 * SS + 1))
    a = Image.composite(Image.new("L", a.size, 0), a, inside)
    img = Image.new("RGBA", a.size, (255, 255, 255, 0))
    img.putalpha(a)
    done(img, 64, 64, name)


def frame_glow():
    outer_glow(lambda d, kw: rr(d, (20, 20, 44, 44), 4, **kw), "ic_frame_glow")
    outer_glow(lambda d, kw: d.ellipse((12 * SS, 12 * SS, 52 * SS, 52 * SS), **kw), "ic_round_glow")


# Button glyphs (PlayStation) -------------------------------------------------
def glyph_base(round_):
    img = big(64, 64)
    d = ImageDraw.Draw(img)
    if round_:
        d.ellipse((3 * SS, 3 * SS, 61 * SS, 61 * SS), fill=(26, 26, 30, 255), outline=(150, 150, 160, 255), width=3 * SS)
    else:
        rr(d, (4, 10, 60, 54), 10, fill=(26, 26, 30, 255), outline=(150, 150, 160, 255), width=3 * SS)
    return img, d


def label(d, text, size, y=32):
    font = ImageFont.truetype(FONT, size * SS)
    d.text((32 * SS, y * SS), text, font=font, fill=(240, 240, 240, 255), anchor="mm")


def glyphs():
    s = SS
    shapes = {
        "a": lambda d: (d.line([(20 * s, 20 * s), (44 * s, 44 * s)], fill=(124, 176, 255), width=6 * s),
                        d.line([(44 * s, 20 * s), (20 * s, 44 * s)], fill=(124, 176, 255), width=6 * s)),
        "b": lambda d: d.ellipse((18 * s, 18 * s, 46 * s, 46 * s), outline=(255, 96, 96), width=6 * s),
        "x": lambda d: d.rectangle((20 * s, 20 * s, 44 * s, 44 * s), outline=(246, 140, 216), width=6 * s),
        "y": lambda d: d.polygon([(32 * s, 16 * s), (48 * s, 44 * s), (16 * s, 44 * s)], outline=(64, 220, 180),
                                 width=6 * s),
    }
    for key, draw in shapes.items():
        img, d = glyph_base(True)
        draw(d)
        done(img, 64, 64, "ic_g_" + key)
    for key, text in (("lb", "L1"), ("rb", "R1"), ("lt", "L2"), ("rt", "R2")):
        img, d = glyph_base(False)
        label(d, text, 22)
        done(img, 64, 64, "ic_g_" + key)
    for key, text in (("ls", "L3"), ("rs", "R3")):
        img, d = glyph_base(True)
        label(d, text, 20)
        done(img, 64, 64, "ic_g_" + key)
    # D-pad: a cross; all arms lit, left/right lit, or up lit
    for key, lit in (("dpad", "udlr"), ("dpad_lr", "lr"), ("dpad_up", "u")):
        img = big(64, 64)
        d = ImageDraw.Draw(img)
        arms = {"u": (24, 4, 40, 28), "d": (24, 36, 40, 60), "l": (4, 24, 28, 40), "r": (36, 24, 60, 40)}
        rr(d, (24, 24, 40, 40), 2, fill=(70, 70, 76, 255))
        for k, box in arms.items():
            rr(d, box, 4, fill=(230, 230, 236, 255) if k in lit else (80, 80, 88, 255),
               outline=(26, 26, 30, 255), width=2 * s)
        done(img, 64, 64, "ic_g_" + key)


# A map area, as the quest areas are drawn: a soft see-through fill and a
# brighter rim fading out; white, tinted and stretched in game ------------
def area():
    n = 128
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c, r = (n - 1) / 2, n / 2 - 2
    for y in range(n):
        for x in range(n):
            t = math.hypot(x - c, y - c) / r          # 0 centre .. 1 edge
            if t > 1.04:
                continue
            fill = 0.32 + 0.18 * t * t                # a little denser outwards
            rim = math.exp(-((t - 0.93) / 0.045) ** 2)  # the lit edge
            a = min(1.0, fill + 0.75 * rim) if t <= 1 else 0.75 * rim
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(os.path.join(OUT, "ic_area.tga"))
    print("wrote ic_area")


if __name__ == "__main__":
    area()
    boxes()
    buttons()
    marks()
    slot()
    frame_glow()
    glyphs()
