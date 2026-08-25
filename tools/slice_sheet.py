#!/usr/bin/env python3
"""
Slice a walk-cycle sheet (any row/column layout) into white plates,
with front/back direction preservation.

Seirin-aware: if sheet has _white suffix and a _black counterpart exists,
both are sliced identically and produce paired white/black plates.

Uses connected-component analysis so sheets laid out as 1x5, 2x3, etc.
all work. Frames returned in reading order (top row first, left to right).

Naming conventions supported:
  Input:
    colt_front_walk_sheet.png  -> colt_front_walk1.png ... etc
    colt_front_walk_sheet_white.png + colt_front_walk_sheet_black.png
        -> colt_front_walk1_white.png + colt_front_walk1_black.png pairs
    colt_walk_sheet.png (no direction) -> colt_walk1.png etc
    hound_back_idle_sheet.png -> hound_back_idle1.png etc

  Output always in assets/src/:
    <base><idx>.png  or  <base><idx>_white.png / _black.png if pair input

Usage:
  python3 tools/slice_sheet.py <sheet_name> [frames=5]
    sheet_name without an extension, e.g. colt_front_walk_sheet
  python3 tools/slice_sheet.py colt_front_walk_sheet 5
  python3 tools/slice_sheet.py --all   # slice all *_sheet.(png|webp) in src
"""

from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

try:
    from scipy import ndimage
except ImportError:
    print("scipy required: pip install scipy")
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "src"


def find_components(im_rgb: Image.Image):
    """Return list of bounding slices sorted in reading order."""
    a = np.asarray(im_rgb).astype(np.float64)
    # mask: not near white
    mask = (a < 250.0).any(axis=2)
    # close small gaps so each figure is one component
    mask = ndimage.binary_closing(mask, structure=np.ones((5, 5)))
    # open to remove tiny specks
    mask = ndimage.binary_opening(mask, structure=np.ones((3, 3)))
    labels, n = ndimage.label(mask)
    objs = ndimage.find_objects(labels)
    boxes = []
    for sl in objs:
        if sl is None:
            continue
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if h * w < 2000:  # noise
            continue
        # filter very thin lines
        if h < 20 or w < 20:
            continue
        yc = (sl[0].start + sl[0].stop) / 2
        xc = (sl[1].start + sl[1].stop) / 2
        boxes.append((yc, xc, sl))

    # reading order: cluster into rows by y
    boxes.sort(key=lambda b: b[0])
    rows = []
    for b in boxes:
        placed = False
        for row in rows:
            # same row if y within 25% of image height
            if abs(row[0][0] - b[0]) < im_rgb.height * 0.25:
                row.append(b)
                placed = True
                break
        if not placed:
            rows.append([b])

    ordered = []
    for row in rows:
        row.sort(key=lambda b: b[1])
        ordered.extend(row)
    return ordered


IMAGE_EXTENSIONS = (".png", ".webp")


def find_image(stem: str) -> Path | None:
    """Find a source image by stem, accepting PNG and WebP plates."""
    for ext in IMAGE_EXTENSIONS:
        candidate = SRC / f"{stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def sibling_with_stem(path: Path, stem: str) -> Path | None:
    """Find a sibling image while preserving the requested stem."""
    for ext in IMAGE_EXTENSIONS:
        candidate = path.parent / f"{stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix.lower() == ".webp":
        image.save(path, "WEBP", lossless=True, method=4)
    else:
        image.save(path)


def slice_one_sheet(sheet_path: Path, frames: int = 5, paired_black: Path | None = None):
    """Slice sheet_path, output frames to SRC."""
    im = Image.open(sheet_path).convert("RGB")
    # if paired black exists, slice it with same boxes
    im_black = None
    if paired_black and paired_black.exists():
        im_black = Image.open(paired_black).convert("RGB")
        if im_black.size != im.size:
            print(f"warn: size mismatch {sheet_path.name} {im.size} vs black {im_black.size}, resizing black")
            im_black = im_black.resize(im.size, Image.Resampling.LANCZOS)

    boxes = find_components(im)
    if len(boxes) == 0:
        print(f"fail {sheet_path.name}: no components found")
        return

    # base name: strip _sheet and _white/_black
    stem = sheet_path.stem
    stem = re.sub(r"_(white|black)$", "", stem)
    base = stem.replace("_sheet", "")

    # limit to frames
    ordered = boxes[:frames]
    out_ext = sheet_path.suffix.lower() if sheet_path.suffix.lower() in IMAGE_EXTENSIONS else ".png"

    print(f"slicing {sheet_path.name}: found {len(boxes)} comps, using {len(ordered)} -> base {base}")

    for idx, (yc, xc, sl) in enumerate(ordered):
        # crop with small padding
        pad = 6
        y0 = max(0, sl[0].start - pad)
        y1 = min(im.height, sl[0].stop + pad)
        x0 = max(0, sl[1].start - pad)
        x1 = min(im.width, sl[1].stop + pad)

        sub = im.crop((x0, y0, x1, y1))
        # paste onto white background of same size (keep tight crop)
        out = Image.new("RGB", sub.size, (255, 255, 255))
        out.paste(sub, (0, 0))

        if paired_black:
            # same crop from black plate
            sub_b = im_black.crop((x0, y0, x1, y1))
            out_b = Image.new("RGB", sub_b.size, (0, 0, 0))
            out_b.paste(sub_b, (0, 0))
            save_image(out_b, SRC / f"{base}{idx + 1}_black{out_ext}")
            save_image(out, SRC / f"{base}{idx + 1}_white{out_ext}")
            print(f"  ok {base}{idx + 1}_white/black: {out.size}")
        else:
            # legacy single plate
            # if input was white plate, output as white? Keep simple: output as <base><idx>.png
            # but also support _white output if original had _white suffix
            if "_white" in sheet_path.stem:
                save_image(out, SRC / f"{base}{idx + 1}_white{out_ext}")
                print(f"  ok {base}{idx + 1}_white: {out.size}")
            else:
                save_image(out, SRC / f"{base}{idx + 1}{out_ext}")
                print(f"  ok {base}{idx + 1}: {out.size}")


def main():
    ap = argparse.ArgumentParser(description="Slice walk-cycle sheets (front/back aware; PNG and WebP)")
    ap.add_argument("sheet", nargs="?", help="sheet stem or path, with or without .png/.webp")
    ap.add_argument("frames", nargs="?", type=int, default=5, help="number of frames")
    ap.add_argument("--all", action="store_true", help="slice all *_sheet.(png|webp) files")
    args = ap.parse_args()

    if args.frames <= 0:
        ap.error("frames must be positive")

    if args.all:
        sheets = sorted(
            [p for ext in IMAGE_EXTENSIONS for p in SRC.glob(f"*_sheet{ext}")]
            + [p for ext in IMAGE_EXTENSIONS for p in SRC.glob(f"*_sheet_white{ext}")]
        )
        processed_bases = set()
        for sheet in sheets:
            if sheet.stem.endswith("_sheet_black"):
                continue
            base_stem = re.sub(r"_(white)$", "", sheet.stem)
            if base_stem in processed_bases:
                continue
            processed_bases.add(base_stem)
            if sheet.stem.endswith("_sheet_white"):
                black = sibling_with_stem(sheet, f"{base_stem}_black")
                slice_one_sheet(sheet, args.frames, black)
                continue
            white = sibling_with_stem(sheet, f"{sheet.stem}_white")
            black = sibling_with_stem(sheet, f"{sheet.stem}_black")
            if white and black:
                slice_one_sheet(white, args.frames, black)
            else:
                slice_one_sheet(sheet, args.frames, black)
        return

    if not args.sheet:
        ap.print_help()
        return

    requested = Path(args.sheet)
    if requested.is_file():
        sheet_path = requested
    else:
        name = args.sheet
        for ext in IMAGE_EXTENSIONS:
            if name.lower().endswith(ext):
                name = name[:-len(ext)]
                break
        sheet_path = find_image(name)
        if sheet_path is None:
            print(f"not found: {name}.png nor {name}.webp in {SRC}")
            sys.exit(1)

    stem = sheet_path.stem
    if stem.endswith("_sheet_white"):
        base_stem = stem.removesuffix("_white")
        black_path = sibling_with_stem(sheet_path, f"{base_stem}_black")
        slice_one_sheet(sheet_path, args.frames, black_path)
        return

    white_variant = sibling_with_stem(sheet_path, f"{stem}_white")
    black_variant = sibling_with_stem(sheet_path, f"{stem}_black")
    if white_variant and black_variant:
        slice_one_sheet(white_variant, args.frames, black_variant)
    else:
        slice_one_sheet(sheet_path, args.frames, black_variant)


if __name__ == "__main__":
    main()
