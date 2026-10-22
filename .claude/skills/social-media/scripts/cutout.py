#!/usr/bin/env python3
"""Cut a game window out of a screenshot onto a transparent background.

The game draws windows over the world (and, when focused, a yellow glow around
the frame). Give the shapes that make up the window; everything outside them
becomes transparent. Inspect the corners first (crop and enlarge them with
NEAREST) to read the exact frame edges; cut just inside the glow.

    python3 cutout.py window.png out.png --shapes '[...]' [--key]

Shapes (window pixels):
  ["rect",    x0, y0, x1, y1, radius]   rounded rectangle
  ["chamfer", x0, y0, x1, y1, cut]      rectangle with cut corners (tabs)
  ["circle",  cx, cy, r]                round badges (portrait at top left)
  ["poly",    [[x, y], ...]]            anything else (bookmark ribbons)
  ["circle_only", cx, cy, r]            same as circle (minimap, radial wheel)

--key  also removes the plain background behind a floating HUD piece (target
       or cast bar drawn straight on the world): pixels close to the border's
       median colour become transparent. Check the result: parts of the piece
       with a similar colour (an empty grey bar) need a "rect" shape forced
       back in with --force '[x0,y0,x1,y1,radius]'.

The output is cropped to the shapes' bounds. A magenta preview is written next
to it (<out>_check.png) to look at before using it.
"""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersample for smooth edges


def draw(d, shape):
    kind = shape[0]
    if kind == "rect":
        x0, y0, x1, y1 = shape[1:5]
        r = shape[5] if len(shape) > 5 else 0
        d.rounded_rectangle((x0 * S, y0 * S, x1 * S, y1 * S), radius=r * S, fill=255)
    elif kind == "chamfer":
        x0, y0, x1, y1, c = shape[1:6]
        pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]
        d.polygon([(x * S, y * S) for x, y in pts], fill=255)
    elif kind in ("circle", "circle_only"):
        cx, cy, r = shape[1:4]
        d.ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), fill=255)
    elif kind == "poly":
        d.polygon([(x * S, y * S) for x, y in shape[1]], fill=255)
    else:
        raise SystemExit(f"unknown shape {kind}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("window")
    ap.add_argument("out")
    ap.add_argument("--shapes", default="[]")
    ap.add_argument("--key", action="store_true")
    ap.add_argument("--key-threshold", type=float, default=28)
    ap.add_argument("--force", default="[]", help="JSON list of [x0,y0,x1,y1,radius] kept opaque after --key")
    ap.add_argument("--scale", type=float, default=1, help="upscale the result (2 for small HUD pieces)")
    args = ap.parse_args()

    im = Image.open(args.window).convert("RGBA")
    W, H = im.size
    shapes = json.loads(args.shapes)
    if shapes:
        mk = Image.new("L", (W * S, H * S), 0)
        d = ImageDraw.Draw(mk)
        for s in shapes:
            draw(d, s)
        mask = np.asarray(mk.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    else:
        mask = np.ones((H, W), np.float32)

    if args.key:
        rgb = np.asarray(im.convert("RGB")).astype(np.float32)
        edge = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
        bg = np.median(edge, 0)
        dist = np.sqrt(((rgb - bg) ** 2).sum(-1))
        k = np.clip((dist - args.key_threshold) / 45, 0, 1)
        k = k * k * (3 - 2 * k)
        k = np.asarray(Image.fromarray((k * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
        forced = json.loads(args.force)
        if forced:
            fm = Image.new("L", (W, H), 0)
            fd = ImageDraw.Draw(fm)
            for x0, y0, x1, y1, r in forced:
                fd.rounded_rectangle((x0, y0, x1, y1), radius=r, fill=255)
            k = np.maximum(k, np.asarray(fm).astype(np.float32) / 255)
        mask = np.minimum(mask, k)

    a = np.asarray(im).astype(np.float32)
    a[..., 3] = a[..., 3] * mask
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    if args.scale != 1:
        out = out.resize((round(out.width * args.scale), round(out.height * args.scale)), Image.LANCZOS)
    out.save(args.out)
    chk = Image.new("RGBA", out.size, (255, 0, 255, 255))
    chk.alpha_composite(out)
    chk.convert("RGB").save(args.out.rsplit(".", 1)[0] + "_check.png")
    print(f"wrote {args.out} {out.size[0]}x{out.size[1]} (aspect {out.size[0] / out.size[1]:.3f})")


if __name__ == "__main__":
    main()
