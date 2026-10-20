"""Imports the designed module icons (1080 x 1080 framed art, the icon in the
middle, cream + green with a black outline on a blurred backdrop) as:
  textures/ic_mod_<module>.tga / ic_addon.tga   128 x 128, transparent, the
      art cut out (its colours kept, a black outline round it, a soft shadow)
  dist/logos/<Module>.png                       400 x 400, the framed art as is
      (the CurseForge logos)

Run: python3 tools/import_icons.py [folder]   (default ~/Downloads; needs Pillow)
     Files: "Icon <Name>@1x.png" and "Addon icon@1x.png".
"""
import os
import sys

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
TEX = os.path.join(ROOT, "ImprovedForever", "textures")
LOGOS = os.path.join(ROOT, "dist", "logos")
# file name -> (texture, logo)
ICONS = {
    "Icon Auction": ("ic_mod_auction", "Auction"),
    "Icon Chat": ("ic_mod_chat", "Chat"),
    "Icon Controller": ("ic_mod_controller", "Controller"),
    "Icon Fishing": ("ic_mod_fishing", "Fishing"),
    "Icon Gather": ("ic_mod_gather", "Gather"),
    "Icon Immersion": ("ic_mod_immersion", "Immersion"),
    "Icon Journal": ("ic_mod_journal", "Journal"),
    "Icon Junk": ("ic_mod_junk", "Junk"),
    "Icon Wiki": ("ic_mod_wiki", "Wiki"),
    "Icon Map": ("ic_mod_map", "Map"),
    "Icon Quest Tracker": ("ic_mod_quests", "QuestTracker"),
    "Icon Vibration": ("ic_mod_vibration", "Vibration"),
    "Icon Wheel": ("ic_mod_wheel", "Wheel"),
    "Addon icon": ("ic_addon", "ImprovedForever"),
}
CREAM = (255, 255, 192)
GREEN = (124, 204, 140)
INNER = (200, 200, 880, 880)        # inside the frame, clear of its corner swirls
OUTLINE = 12                        # the art's black outline, px at 1080
SIZE = 128
MARGIN = 6


def near(img, color, tol):
    r, g, b = img.split()
    out = None
    for ch, c in zip((r, g, b), color):
        m = ch.point(lambda v, c=c: 255 if abs(v - c) <= tol else 0)
        out = m if out is None else ImageChops.multiply(out, m)
    return out


def cut(img):
    """The art alone: RGBA at 1080, transparent round it"""
    art = img.convert("RGB").crop(INNER)
    fill = ImageChops.lighter(near(art, CREAM, 45), near(art, GREEN, 45))
    fill = fill.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))   # specks out
    # Silhouette: fill grown by the outline, its enclosed holes closed
    sil = fill.filter(ImageFilter.GaussianBlur(OUTLINE * 0.6)).point(lambda v: 255 if v > 24 else 0)
    flood = sil.copy()
    from PIL import ImageDraw
    ImageDraw.floodfill(flood, (0, 0), 128)
    sil = flood.point(lambda v: 0 if v == 128 else 255)
    out = Image.new("RGBA", art.size, (10, 10, 10, 0))
    out.paste((10, 10, 10, 255), (0, 0), sil)
    keep = fill.filter(ImageFilter.GaussianBlur(1)).point(lambda v: min(255, v * 2))
    out.paste(art.convert("RGBA"), (0, 0), keep)
    out.putalpha(sil.filter(ImageFilter.GaussianBlur(1)))
    return out


def texture(img, path):
    art = cut(img)
    art = art.crop(art.getbbox())
    k = (SIZE - 2 * MARGIN) / max(art.size)
    art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pos = ((SIZE - art.width) // 2, (SIZE - art.height) // 2)
    shadow = Image.new("L", (SIZE, SIZE), 0)
    shadow.paste(art.getchannel("A"), pos)
    shadow = shadow.filter(ImageFilter.GaussianBlur(2.5)).point(lambda v: min(150, v))
    out.paste((10, 10, 10, 255), (0, 0), shadow)
    out.alpha_composite(art, pos)
    out.save(path)
    print("wrote", path)


def main():
    folder = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads")
    os.makedirs(LOGOS, exist_ok=True)
    for name, (tex, logo) in ICONS.items():
        src = os.path.join(folder, name + "@1x.png")
        if not os.path.exists(src):
            print("missing", src)
            continue
        img = Image.open(src)
        texture(img, os.path.join(TEX, tex + ".tga"))
        path = os.path.join(LOGOS, logo + ".png")
        img.convert("RGB").resize((400, 400), Image.LANCZOS).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
