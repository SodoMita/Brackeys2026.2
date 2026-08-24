#!/usr/bin/env python3
"""
Triangulation matte from Seirin (github.com/SodoMita/Seirin)

White/black pair -> RGBA with straight alpha.

Math:
  B = F * a            (figure over pure black)
  W = F * a + (1-a)    (figure over pure white, white=1)
  => a = 1 - (W - B)
  => F = B / a

Where W,B in [0,1] RGB. Alpha is mean of per-channel a, clamped.
This recovers soft edges, hair, translucency exactly.

Critical rules from Seirin sprite-spec.md:
- Plates must keep pose/position/scale/framing/lighting/colour identical,
  background must genuinely show through where figure is not opaque.
- Never ask model to keep "character pixels identical" between plates —
  that flattens alpha to 1 and destroys the signal.
- Generate black plate as an *edit* of white plate so they register.
- Matte AFTER final upscale, not before.

Usage:
  python3 tools/triangulate_matte.py white.png black.png out.png [--alpha-out alpha.png]
  python3 tools/triangulate_matte.py --check-dir assets/sprites
"""
from __future__ import annotations
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image


def normalize_white_plate(im: Image.Image, threshold: float = 38.0) -> np.ndarray:
    """Clamp generator haze to exact white using corner median."""
    a = np.asarray(im.convert("RGB")).astype(np.float64)
    p = 12
    # corners
    corners = np.concatenate([
        a[:p, :p].reshape(-1, 3),
        a[:p, -p:].reshape(-1, 3),
        a[-p:, :p].reshape(-1, 3),
        a[-p:, -p:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    # distance from bg colour
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    a[dist <= threshold] = 255.0
    # also force near-white to white
    near_white = (a >= 250).all(axis=2)
    a[near_white] = 255.0
    return a


def normalize_black_plate(im: Image.Image, threshold: float = 38.0) -> np.ndarray:
    """Clamp black plate background to exact black."""
    a = np.asarray(im.convert("RGB")).astype(np.float64)
    p = 12
    corners = np.concatenate([
        a[:p, :p].reshape(-1, 3),
        a[:p, -p:].reshape(-1, 3),
        a[-p:, :p].reshape(-1, 3),
        a[-p:, -p:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    # if bg is near black, clamp near-black to 0
    if bg.mean() < 60:
        dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
        a[dist <= threshold] = 0.0
        near_black = (a <= 5).all(axis=2)
        a[near_black] = 0.0
    return a


def triangulate_arrays(white: np.ndarray, black: np.ndarray) -> np.ndarray:
    """
    white, black: HxWx3 float in [0,255] or [0,1] — we expect [0,255] and convert.
    Returns HxWx4 uint8 RGBA straight alpha.
    """
    # ensure float [0,1]
    if white.max() > 1.5:
        wf = white / 255.0
    else:
        wf = white
    if black.max() > 1.5:
        bf = black / 255.0
    else:
        bf = black

    # a_rgb = 1 - (W - B)
    alpha_rgb = 1.0 - (wf - bf)
    # mean across channels for final alpha
    alpha = np.clip(alpha_rgb.mean(axis=2), 0.0, 1.0)

    # recover foreground: F = B / a
    safe_alpha = np.maximum(alpha, 1e-6)
    fg = np.clip(bf / safe_alpha[..., None], 0.0, 1.0)

    # For very low alpha, keep fg as white to avoid noisy colors
    # (Seirin check_matte will flag edge contamination otherwise)
    # Actually keep black plate colour but desaturated — better to keep as is.

    rgba = np.dstack([
        (fg * 255.0 + 0.5).astype(np.uint8),
        (alpha * 255.0 + 0.5).astype(np.uint8),
    ])
    return rgba


def triangulate(white_path: Path, black_path: Path, out_path: Path, alpha_path: Path | None = None) -> dict:
    white_im = Image.open(white_path)
    black_im = Image.open(black_path)

    if white_im.size != black_im.size:
        raise SystemExit(f"Size mismatch: white={white_im.size} black={black_im.size} ({white_path} vs {black_path})")

    white = normalize_white_plate(white_im)
    black = normalize_black_plate(black_im)

    rgba = triangulate_arrays(white, black)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out_path)

    if alpha_path is not None:
        alpha_path.parent.mkdir(parents=True, exist_ok=True)
        alpha = rgba[..., 3]
        Image.fromarray(alpha, "L").save(alpha_path)

    # stats for verification
    a = rgba[..., 3].astype(np.float32) / 255.0
    transparent = (a < 0.05).mean() * 100
    partial = ((a >= 0.05) & (a < 0.95)).mean() * 100
    opaque = (a >= 0.95).mean() * 100
    return {
        "transparent": transparent,
        "partial": partial,
        "opaque": opaque,
        "size": rgba.shape,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Seirin white/black triangulation -> RGBA")
    ap.add_argument("white", nargs="?", help="white plate PNG")
    ap.add_argument("black", nargs="?", help="black plate PNG")
    ap.add_argument("output", nargs="?", help="output RGBA PNG")
    ap.add_argument("--alpha-out", default=None, help="optional alpha map output")
    ap.add_argument("--check-dir", default=None, help="verify all PNGs in dir have alpha")
    args = ap.parse_args()

    if args.check_dir:
        d = Path(args.check_dir)
        for p in sorted(d.glob("*.png")):
            im = Image.open(p)
            if im.mode != "RGBA":
                print(f"FAIL {p.name}: not RGBA ({im.mode})")
                continue
            a = np.asarray(im)[:, :, 3]
            t = (a < 10).mean() * 100
            pa = ((a >= 10) & (a < 245)).mean() * 100
            if t < 5:
                print(f"WARN {p.name}: only {t:.1f}% transparent — maybe flattened?")
            else:
                print(f"ok {p.name}: {t:.1f}% transparent, {pa:.1f}% partial")
        return

    if not args.white or not args.black or not args.output:
        ap.print_help()
        sys.exit(1)

    stats = triangulate(Path(args.white), Path(args.black), Path(args.output),
                        Path(args.alpha_out) if args.alpha_out else None)
    print(f"ok {args.output}: {stats['size'][1]}x{stats['size'][0]} "
          f"T:{stats['transparent']:.1f}% P:{stats['partial']:.1f}% O:{stats['opaque']:.1f}%")


if __name__ == "__main__":
    main()
