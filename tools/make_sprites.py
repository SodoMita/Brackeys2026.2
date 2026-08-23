#!/usr/bin/env python3
"""Sprite matte pipeline for Steel Knife.

Triangulation math adapted from github.com/SodoMita/Seirin
(tools/triangulate_matte.py): difference-matte recovery
    alpha = 1 - (W - B);  fg = B / alpha
where W = figure on pure white, B = same figure on pure black.

For every assets/src/<name>.png (a generated white plate) this script:
  1. clamps generator background haze to exact white (Seirin normalize step),
  2. derives the black plate (figure pixels over black),
  3. triangulates to RGBA, crops to content and pixel-downsizes for the
     PSX-style look,
  4. writes assets/sprites/<name>.png.

Usage: python3 tools/make_sprites.py [name ...]   (no args = all plates)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "src"
OUT = ROOT / "assets" / "sprites"
TARGET_H = 256


def normalize_white(im: Image.Image, threshold: float = 40.0) -> np.ndarray:
    a = np.asarray(im.convert("RGB")).astype(np.float64)
    p = 12
    corners = np.concatenate([
        a[:p, :p].reshape(-1, 3), a[:p, -p:].reshape(-1, 3),
        a[-p:, :p].reshape(-1, 3), a[-p:, -p:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    a[dist <= threshold] = 255.0
    return a


def derive_black(white: np.ndarray) -> np.ndarray:
    black = np.zeros_like(white)
    mask = (white < 250.0).any(axis=2)
    black[mask] = white[mask]
    return black


def triangulate(w: np.ndarray, b: np.ndarray) -> np.ndarray:
    wf = w / 255.0
    bf = b / 255.0
    alpha = np.clip(1.0 - (wf - bf), 0.0, 1.0).mean(axis=2)
    safe = np.maximum(alpha, 1e-6)
    fg = np.clip(bf / safe[..., None], 0.0, 1.0)
    rgba = np.dstack([
        (fg * 255.0 + 0.5).astype(np.uint8),
        (alpha * 255.0 + 0.5).astype(np.uint8),
    ])
    return rgba


def crop_and_resize(rgba: np.ndarray) -> np.ndarray:
    a = rgba[..., 3]
    ys, xs = np.where(a > 15)
    if len(xs) == 0:
        return rgba
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    img = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1], "RGBA")
    h = img.height
    if h > TARGET_H:
        scale = TARGET_H / h
        img = img.resize((max(1, int(img.width * scale)), TARGET_H),
                         Image.Resampling.NEAREST)
    return np.asarray(img)


def process(name: str) -> None:
    src = SRC / f"{name}.png"
    if not src.exists():
        print(f"skip {name}: no plate")
        return
    white = normalize_white(Image.open(src))
    black = derive_black(white)
    rgba = triangulate(white, black)
    rgba = crop_and_resize(rgba)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT / f"{name}.png")
    print(f"ok {name}: {rgba.shape[1]}x{rgba.shape[0]}")


def main() -> None:
    import sys
    names = sys.argv[1:] or [p.stem for p in sorted(SRC.glob("*.png"))]
    for n in names:
        process(n)


if __name__ == "__main__":
    main()
