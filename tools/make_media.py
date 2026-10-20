"""CurseForge media (the gallery's pictures) in the logos' look: a square,
the designed icons' frame (its cream line and corner swirls, taken from one
of them: import_icons.py's source) over the picture itself blurred and
darkened, the picture in the middle with a soft shadow, a caption under it.

Run: python3 tools/make_media.py <picture> <out.png> [--crop l,t,r,b] [--caption "Text"]
     [--frame ~/Downloads/Icon Map@1x.png]   (needs Pillow)
"""
import argparse
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

SIZE = 1080
CREAM = (255, 255, 192)
BOX = (130, 120, 950, 870)              # (the picture's room inside the frame)
WIDE_BOX = (105, 170, 975, 860)         # (a wide one's: the frame's whole width)
CAPTION_Y = 925
FONTS = ["/System/Library/Fonts/Supplemental/Georgia Bold.ttf", "/System/Library/Fonts/Supplemental/Georgia.ttf"]


def frame_layer(path):
    """The frame alone: the cream line and swirls round the edge, RGBA"""
    img = Image.open(os.path.expanduser(path)).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    r, g, b = img.split()
    near = None
    for ch, c in zip((r, g, b), CREAM):
        m = ch.point(lambda v, c=c: 255 if abs(v - c) <= 70 else 0)
        near = m if near is None else ImageChops.multiply(near, m)
    # (only round the edge: the middle held the icon's own art)
    edge = Image.new("L", (SIZE, SIZE), 255)
    ImageDraw.Draw(edge).rectangle((175, 175, SIZE - 175, SIZE - 175), fill=0)
    mask = ImageChops.multiply(near, edge).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # (its own soft dark edge, as on the logos)
    shadow = mask.filter(ImageFilter.GaussianBlur(6)).point(lambda v: min(200, v * 2))
    out.paste((0, 0, 0, 255), (0, 0), shadow)
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def cover(img, size):
    k = max(size / img.width, size / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    left, top = (img.width - size) // 2, (img.height - size) // 2
    return img.crop((left, top, left + size, top + size))


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("picture")
    ap.add_argument("out")
    ap.add_argument("--crop")
    ap.add_argument("--caption", default="")
    ap.add_argument("--frame", default="~/Downloads/Icon Map@1x.png")
    ap.add_argument("--bright", type=float, default=1.0, help="the picture lit up (a night scene)")
    a = ap.parse_args()

    pic = Image.open(a.picture).convert("RGB")
    if a.crop:
        pic = pic.crop(tuple(int(v) for v in a.crop.split(",")))
    # (behind: the picture itself, blurred and dark)
    back = cover(pic, SIZE).filter(ImageFilter.GaussianBlur(28))
    back = ImageEnhance.Brightness(back).enhance(0.45).convert("RGBA")
    if a.bright != 1:
        pic = ImageEnhance.Brightness(pic).enhance(a.bright)
    # (the picture, as big as its room lets it be, a soft shadow under)
    box = WIDE_BOX if pic.width > pic.height * 1.4 else BOX
    w, h = box[2] - box[0], box[3] - box[1]
    k = min(w / pic.width, h / pic.height)
    shown = pic.resize((round(pic.width * k), round(pic.height * k)), Image.LANCZOS)
    x = box[0] + (w - shown.width) // 2
    y = box[1] + (h - shown.height) // 2
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).rectangle((x - 4, y - 2, x + shown.width + 4, y + shown.height + 8), fill=220)
    back.paste((0, 0, 0, 255), (0, 0), shadow.filter(ImageFilter.GaussianBlur(14)))
    back.paste(shown, (x, y))
    ImageDraw.Draw(back).rectangle((x - 1, y - 1, x + shown.width, y + shown.height), outline=(20, 16, 10, 255),
                                   width=2)
    back.alpha_composite(frame_layer(a.frame))
    if a.caption:
        d = ImageDraw.Draw(back)
        f = font(44)
        tw = d.textlength(a.caption, font=f)
        tx = (SIZE - tw) / 2
        d.text((tx + 2, CAPTION_Y + 3), a.caption, font=f, fill=(0, 0, 0, 230), anchor="lm")
        d.text((tx, CAPTION_Y), a.caption, font=f, fill=CREAM + (255,), anchor="lm")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    back.convert("RGB").save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
