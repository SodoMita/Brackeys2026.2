#!/usr/bin/env python3
"""
Sprite matte pipeline for Steel Knife — Seirin triangulation edition v2
Lossy WebP output, lossless WebP or PNG plates.

Implements proper white/black difference matte from
github.com/SodoMita/Seirin tools/triangulate_matte.py:

  B = F * a
  W = F * a + (1-a)   (white=1)
  => a = 1 - (W - B) ;  F = B / a

Front / back views:
  The generator should produce TWO plates per frame:
    <name>_white.png  +  <name>_black.png  (or .webp lossless)
  e.g.:
    colt_front_walk1_white.webp + colt_front_walk1_black.webp
    colt_back_walk1_white.webp  + colt_back_walk1_black.webp

  If only white plate exists (legacy), we derive black via masking,
  but warn that edges will be binary.

  Supported naming (all produce assets/sprites/<base>.webp lossy):
    <kind>_<direction>_<action><idx>_white.webp
    <kind>_<action><idx>_<direction>_white.webp
    <kind>_<action><idx>_white.webp
    <kind>_<direction>_white.webp
  where direction in {front, back, side, left, right} — front/back are primary.

  Sheets:
    <kind>_<direction>_<action>_sheet.webp  (e.g. colt_front_walk_sheet.webp)
    sliced via slice_sheet.py into white plates, then matted.

Pipeline per file:
  1. normalize white plate (corner median -> exact white)
  2. normalize black plate if present (corner median -> exact black)
     else derive black via mask (legacy fallback)
  3. triangulate -> RGBA straight alpha
  4. crop to content (alpha > 10) + 4px padding
  5. resize to TARGET_H (256) using LANCZOS for smooth edges
     (NEAREST kept as optional --pixelate for PSX crunchy look)
  6. write assets/sprites/<name>.webp (lossy q=85, alpha q=85)

Usage:
  python3 tools/make_sprites.py                    # all plates
  python3 tools/make_sprites.py colt_front_walk1   # specific base (without _white)
  python3 tools/make_sprites.py --pixelate         # use NEAREST
  python3 tools/make_sprites.py --check            # verify outputs
"""

from __future__ import annotations
import argparse
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "src"
OUT = ROOT / "assets" / "sprites"
TARGET_H = 256
PADDING = 4

DIRECTIONS = {"front", "back", "side", "left", "right", "f", "b"}


def normalize_white(im: Image.Image, threshold: float = 38.0) -> np.ndarray:
    a = np.asarray(im.convert("RGB")).astype(np.float64)
    p = 12
    corners = np.concatenate([
        a[:p, :p].reshape(-1, 3),
        a[:p, -p:].reshape(-1, 3),
        a[-p:, :p].reshape(-1, 3),
        a[-p:, -p:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    a[dist <= threshold] = 255.0
    a[(a >= 250).all(axis=2)] = 255.0
    return a


def normalize_black(im: Image.Image, threshold: float = 38.0) -> np.ndarray:
    a = np.asarray(im.convert("RGB")).astype(np.float64)
    p = 12
    corners = np.concatenate([
        a[:p, :p].reshape(-1, 3),
        a[:p, -p:].reshape(-1, 3),
        a[-p:, :p].reshape(-1, 3),
        a[-p:, -p:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    if bg.mean() < 70:
        dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
        a[dist <= threshold] = 0.0
        a[(a <= 6).all(axis=2)] = 0.0
    return a


def derive_black_legacy(white: np.ndarray) -> np.ndarray:
    black = np.zeros_like(white)
    mask = (white < 250.0).any(axis=2)
    black[mask] = white[mask]
    return black


def triangulate(w: np.ndarray, b: np.ndarray) -> np.ndarray:
    wf = w / 255.0
    bf = b / 255.0
    alpha_rgb = 1.0 - (wf - bf)
    alpha = np.clip(alpha_rgb.mean(axis=2), 0.0, 1.0)
    safe = np.maximum(alpha, 1e-6)
    fg = np.clip(bf / safe[..., None], 0.0, 1.0)
    rgba = np.dstack([
        (fg * 255.0 + 0.5).astype(np.uint8),
        (alpha * 255.0 + 0.5).astype(np.uint8),
    ])
    return rgba


def crop_and_resize(rgba: np.ndarray, use_nearest: bool = False, target_h: int = 256) -> np.ndarray:
    a = rgba[..., 3]
    ys, xs = np.where(a > 12)
    if len(xs) == 0:
        return rgba
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    x0 = max(0, x0 - PADDING)
    y0 = max(0, y0 - PADDING)
    x1 = min(rgba.shape[1] - 1, x1 + PADDING)
    y1 = min(rgba.shape[0] - 1, y1 + PADDING)
    img = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1], "RGBA")
    h = img.height
    if h > target_h:
        scale = target_h / h
        new_w = max(1, int(img.width * scale))
        resample = Image.Resampling.NEAREST if use_nearest else Image.Resampling.LANCZOS
        img = img.resize((new_w, target_h), resample)
    return np.asarray(img)


def discover_pairs():
    pairs = {}
    # Support both PNG and WebP plates (lossless WebP preferred)
    all_files = sorted(list(SRC.glob("*.png")) + list(SRC.glob("*.webp")))
    for p in all_files:
        stem = p.stem
        if stem.endswith("_sheet"):
            continue
        m = re.match(r"^(.*?)(?:_white|_black)$", stem)
        if m:
            base = m.group(1)
            is_white = stem.endswith("_white")
            entry = pairs.get(base, {"white": None, "black": None})
            # Prefer WebP lossless over PNG if both exist
            if is_white:
                if entry["white"] is None:
                    entry["white"] = p
                elif p.suffix == ".webp" and entry["white"].suffix == ".png":
                    entry["white"] = p
            else:
                if entry["black"] is None:
                    entry["black"] = p
                elif p.suffix == ".webp" and entry["black"].suffix == ".png":
                    entry["black"] = p
            pairs[base] = entry
        else:
            if stem not in pairs:
                pairs[stem] = {"white": p, "black": None}
            else:
                if pairs[stem]["white"] is None:
                    pairs[stem]["white"] = p
    return pairs


def process_one(base: str, white_path: Path, black_path: Path | None, use_nearest: bool = False, target_h: int = 256) -> bool:
    if white_path is None or not white_path.exists():
        print(f"skip {base}: no white plate")
        return False
    try:
        white_im = Image.open(white_path)
    except Exception as e:
        print(f"skip {base}: cannot open white {e}")
        return False
    white = normalize_white(white_im)
    if black_path and black_path.exists():
        try:
            black_im = Image.open(black_path)
            black = normalize_black(black_im)
            if white_im.size != black_im.size:
                print(f"warn {base}: size mismatch white={white_im.size} black={black_im.size}, resizing black")
                black_im_resized = black_im.resize(white_im.size, Image.Resampling.LANCZOS)
                black = normalize_black(black_im_resized)
            legacy = False
        except Exception as e:
            print(f"warn {base}: black plate failed {e}, falling back to derive")
            black = derive_black_legacy(white)
            legacy = True
    else:
        black = derive_black_legacy(white)
        legacy = True
    rgba = triangulate(white, black)
    rgba = crop_and_resize(rgba, use_nearest=use_nearest, target_h=target_h)
    OUT.mkdir(parents=True, exist_ok=True)
    out_path = OUT / f"{base}.webp"
    Image.fromarray(rgba, "RGBA").save(out_path, "WEBP", quality=85, method=4, alpha_quality=85)
    a = rgba[..., 3].astype(np.float32) / 255.0
    t = (a < 0.05).mean() * 100
    pa = ((a >= 0.05) & (a < 0.95)).mean() * 100
    tag = "LEGACY" if legacy else "PAIR"
    print(f"ok {base}: {rgba.shape[1]}x{rgba.shape[0]} T:{t:.1f}% P:{pa:.1f}% [{tag}] -> {out_path.name}")
    if legacy and pa < 0.5:
        print(f"  hint: {base} has binary alpha — generate a black plate pair for soft edges (see Seirin docs)")
    return True


def main() -> None:
    ap = argparse.ArgumentParser(description="Make sprites via Seirin triangulation (front/back aware) WebP output")
    ap.add_argument("names", nargs="*", help="base names to process (without _white/_black), or empty for all")
    ap.add_argument("--pixelate", action="store_true", help="use NEAREST resize for crunchy PSX look")
    ap.add_argument("--check", action="store_true", help="run check_matte on outputs")
    ap.add_argument("--target-h", type=int, default=TARGET_H, help="target height")
    args = ap.parse_args()
    pairs = discover_pairs()
    target_h = args.target_h
    if args.names:
        requested = []
        for n in args.names:
            n = re.sub(r"_(white|black)$", "", n)
            n = n.replace(".png", "").replace(".webp", "")
            requested.append(n)
        to_process = {k: v for k, v in pairs.items() if k in requested}
        missing = set(requested) - set(to_process.keys())
        for m in missing:
            print(f"skip {m}: no plate found in assets/src/")
    else:
        to_process = pairs
    ok = 0
    for base in sorted(to_process.keys()):
        entry = to_process[base]
        if process_one(base, entry.get("white"), entry.get("black"), use_nearest=args.pixelate, target_h=target_h):
            ok += 1
    print(f"\nDone: {ok}/{len(to_process)} sprites written to {OUT}")
    if args.check:
        from check_matte import check_image
        print("\n--- matte check ---")
        for base in sorted(to_process.keys()):
            out_path = OUT / f"{base}.webp"
            if not out_path.exists():
                out_path = OUT / f"{base}.png"
            if out_path.exists():
                res = check_image(out_path)
                if res["ok"]:
                    print(f"PASS {base}: T:{res['transparent']:.1f}% P:{res['partial']:.1f}%")
                else:
                    print(f"FAIL {base}:")
                    for iss in res["issues"]:
                        print(f"  - {iss}")


if __name__ == "__main__":
    main()
