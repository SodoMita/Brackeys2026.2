#!/usr/bin/env python3
"""
Check matte quality — port of Seirin tools/check_matte.py

Verifies:
- has transparency (not flattened)
- has soft edges (partial alpha)
- edge colour not contaminated by background
- size and format

Usage:
  python3 tools/check_matte.py sprite.webp --report
  python3 tools/check_matte.py sprite.webp --checks --out check.png
  python3 tools/check_matte.py assets/sprites --report
"""
from __future__ import annotations
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image


def check_image(path: Path, make_check_img: Path | None = None) -> dict:
    im = Image.open(path)
    if im.mode != "RGBA":
        return {"ok": False, "error": f"not RGBA, mode={im.mode}"}

    rgba = np.asarray(im)
    a = rgba[..., 3].astype(np.float32) / 255.0
    rgb = rgba[..., :3].astype(np.float32) / 255.0

    h, w = a.shape
    transparent = (a < 0.05).mean()
    partial = ((a >= 0.05) & (a < 0.95)).mean()
    opaque = (a >= 0.95).mean()

    issues = []

    if transparent < 0.05:
        issues.append(f"no transparency ({transparent*100:.1f}% < 5%): plates were flattened?")

    if partial < 0.002:
        issues.append(f"no soft edges ({partial*100:.2f}% partial): binary alpha, will have jaggies")

    # edge contamination check: sample border pixels with partial alpha
    # and compare to interior opaque average
    opaque_mask = a > 0.95
    if opaque_mask.any():
        interior_color = rgb[opaque_mask].mean(axis=0)
        # Only inspect the outer image border. Dark foreground details are
        # valid sprite colours; treating every partial-alpha dark pixel as
        # black-plate contamination produces false positives on characters.
        border = np.zeros_like(a, dtype=bool)
        border[:2, :] = True
        border[-2:, :] = True
        border[:, :2] = True
        border[:, -2:] = True
        edge_mask = (a >= 0.1) & (a < 0.9) & border
        if edge_mask.any():
            edge_colors = rgb[edge_mask]
            white_dist = np.sqrt(((edge_colors - 1.0) ** 2).mean(axis=1))
            black_dist = np.sqrt(((edge_colors - 0.0) ** 2).mean(axis=1))
            near_white = (white_dist < 0.15).mean()
            near_black = (black_dist < 0.15).mean()
            if near_white > 0.15:
                issues.append(f"outer edge contaminated by white ({near_white*100:.1f}% near-white)")
            if near_black > 0.15:
                issues.append(f"outer edge contaminated by black ({near_black*100:.1f}% near-black)")

    ok = len(issues) == 0

    if make_check_img:
        # create checkerboard composite to visually verify
        checker = np.zeros((h, w, 3), dtype=np.uint8)
        # 16px checker
        for y in range(h):
            for x in range(w):
                c = 255 if ((x // 16) + (y // 16)) % 2 == 0 else 180
                checker[y, x] = (c, c, c)
        # composite
        # out = fg * a + bg * (1-a)
        bg = checker.astype(np.float32) / 255.0
        out_rgb = rgb * a[..., None] + bg * (1 - a[..., None])
        out = (out_rgb * 255).astype(np.uint8)
        Image.fromarray(out, "RGB").save(make_check_img)

    return {
        "ok": ok,
        "issues": issues,
        "transparent": transparent * 100,
        "partial": partial * 100,
        "opaque": opaque * 100,
        "size": (w, h),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", help="PNG or WebP file, or directory")
    ap.add_argument("--report", action="store_true", help="print report")
    ap.add_argument("--checks", action="store_true", help="same as --report but explicit")
    ap.add_argument("--out", default=None, help="write checker composite")
    args = ap.parse_args()

    p = Path(args.input)
    paths = [p] if p.is_file() else sorted(
        list(p.glob("*.png")) + list(p.glob("*.webp"))
    )

    any_fail = False
    for path in paths:
        result = check_image(path, Path(args.out) if args.out and len(paths) == 1 else None)
        if args.report or args.checks or len(paths) > 1:
            if result.get("ok"):
                print(f"PASS {path.name}: {result['size'][0]}x{result['size'][1]} "
                      f"T:{result['transparent']:.1f}% P:{result['partial']:.1f}% O:{result['opaque']:.1f}%")
            else:
                any_fail = True
                print(f"FAIL {path.name}: {result.get('error','')}")
                for iss in result.get("issues", []):
                    print(f"  - {iss}")
                print(f"  T:{result.get('transparent',0):.1f}% P:{result.get('partial',0):.1f}% O:{result.get('opaque',0):.1f}%")
        if args.out and len(paths) > 1:
            out_path = Path(args.out) / f"{path.stem}_check.png"
            out_path.parent.mkdir(parents=True, exist_ok=True)
            check_image(path, out_path)

    if any_fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
