#!/usr/bin/env python3
"""Turn a game screenshot into a 1080x1080 square (or 1920x1080 wide) background.

The subject stays sharp inside an ellipse; everything else gets a radial zoom
blur from a centre point. HUD pieces can be blurred out first, other pieces
cut out as feathered overlays, and the square can reach past the screenshot's
edges (the missing part is filled with a heavily blurred stretch of the shot).

    python3 scene.py shot.png out/scene --config '{...}'

Config keys (all coordinates in screenshot pixels):
  ell     [cx, cy, rx, ry]   sharp ellipse around the subject (required)
  zc      [x, y]             zoom-blur centre (default: the ellipse centre)
  crop    [left, top, width] area to keep (its height follows "size");
                             top/left may be negative and the area may pass
                             the shot's other edges too
  size    [w, h]             output size: [1080, 1080] (default, square post)
                             or [1920, 1080] (wide post)
  keep    [[x0,y0,x1,y1]...] extra rectangles kept sharp (name labels, dialogue)
  erase   [[x0,y0,x1,y1]...] HUD rectangles blurred away before anything else
  pieces  [[x0,y0,x1,y1]...] rectangles saved as feathered PNG overlays
                             (<out>_piece0.png, ...) before erasing
  strength  zoom amount, default 0.16
  flip_x  true to mirror the result (never on shots with text you keep)

Writes <out>.jpg and prints where the ellipse and crop land in
the square, so overlays and text can be placed clear of the subject.
"""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def smooth(a):
    return a * a * (3 - 2 * a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shot")
    ap.add_argument("out")
    ap.add_argument("--config", required=True, help="JSON, or @file.json")
    args = ap.parse_args()
    cfg = json.load(open(args.config[1:])) if args.config.startswith("@") else json.loads(args.config)

    im = Image.open(args.shot).convert("RGB")
    W, H = im.size
    orig = im.copy()

    for i, (x0, y0, x1, y1) in enumerate(cfg.get("pieces", [])):
        p = orig.crop((x0, y0, x1, y1)).convert("RGBA")
        w, h = p.size
        f = 14
        ys = np.arange(h)[:, None]
        xs = np.arange(w)[None, :]
        a = np.minimum(np.minimum(xs / f, (w - 1 - xs) / f), np.minimum(ys / f, (h - 1 - ys) / f)).clip(0, 1)
        p.putalpha(Image.fromarray((smooth(a) * 255).astype(np.uint8)))
        p.save(f"{args.out}_piece{i}.png")

    if cfg.get("erase"):
        big = im.filter(ImageFilter.GaussianBlur(40))
        em = Image.new("L", (W, H), 0)
        de = ImageDraw.Draw(em)
        for r in cfg["erase"]:
            de.rectangle(r, fill=255)
        em = em.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(14))
        im = Image.composite(big, im, em)

    a = np.asarray(im).astype(np.float32)
    ex, ey, rx, ry = cfg["ell"]
    cx, cy = cfg.get("zc", [ex, ey])
    strength = cfg.get("strength", 0.16)
    acc = np.zeros_like(a)
    n = 28
    for i in range(n):
        s = 1 + strength * i / (n - 1)
        w, h = int(W * s), int(H * s)
        r = im.resize((w, h), Image.BICUBIC)
        l, t = int(cx * s - cx), int(cy * s - cy)
        acc += np.asarray(r.crop((l, t, l + W, t + H))).astype(np.float32)
    blur = acc / n

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((xx - ex) / rx) ** 2 + ((yy - ey) / ry) ** 2)
    m = smooth(np.clip((d - 1) / 0.55, 0, 1))
    for (x0, y0, x1, y1) in cfg.get("keep", []):
        out = np.maximum(np.maximum(x0 - xx, xx - x1), np.maximum(y0 - yy, yy - y1))
        m = np.minimum(m, np.clip(out / 40, 0, 1))
    o = Image.fromarray((a * (1 - m[..., None]) + blur * m[..., None]).clip(0, 255).astype(np.uint8))

    OW, OH = cfg.get("size", [1080, 1080])
    L, T, C = cfg.get("crop", [int(ex - min(W, H) / 2), 0, min(W, H)])
    CH = round(C * OH / OW)
    padT, padB = max(0, -T), max(0, T + CH - H)
    padL, padR = max(0, -L), max(0, L + C - W)
    EW, EH = W + padL + padR, H + padT + padB
    ext = o.resize((EW, EH), Image.BICUBIC).filter(ImageFilter.GaussianBlur(45))
    ys = np.arange(H, dtype=np.float32)
    xs = np.arange(W, dtype=np.float32)
    fy = np.ones(H, np.float32)
    fx = np.ones(W, np.float32)
    if padT:
        fy = np.minimum(fy, ys / 90)
    if padB:
        fy = np.minimum(fy, (H - 1 - ys) / 140)
    if padL:
        fx = np.minimum(fx, xs / 140)
    if padR:
        fx = np.minimum(fx, (W - 1 - xs) / 140)
    f = smooth(np.minimum(fy.clip(0, 1)[:, None], fx.clip(0, 1)[None, :]))
    ext.paste(o, (padL, padT), Image.fromarray((f * 255).astype(np.uint8)))
    sq = ext.crop((L + padL, T + padT, L + padL + C, T + padT + CH)).resize((OW, OH), Image.LANCZOS)
    if cfg.get("flip_x"):
        sq = sq.transpose(Image.FLIP_LEFT_RIGHT)
    sq.save(args.out + ".jpg", quality=90)

    k = OW / C
    to = lambda x, y: (round((x - L) * k), round((y - T) * k))
    x0, y0 = to(ex - rx, ey - ry)
    x1, y1 = to(ex + rx, ey + ry)
    print(f"wrote {args.out}.jpg  scale {k:.3f}")
    print(f"sharp area in the image: x {x0}..{x1}, y {y0}..{y1}")
    if OW == OH:
        print("square: keep it inside y 280..720 (header ends near 266, bottom text starts near 740)")
    else:
        print("wide: keep it right of x 860 (the text column), inside y 90..990")


if __name__ == "__main__":
    main()
