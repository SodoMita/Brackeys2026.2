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
    sheet_name without .png, e.g. colt_front_walk_sheet
  python3 tools/slice_sheet.py colt_front_walk_sheet 5
  python3 tools/slice_sheet.py --all   # slice all *_sheet.png in src
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
            out_b.save(SRC / f"{base}{idx + 1}_black.png")
            out.save(SRC / f"{base}{idx + 1}_white.png")
            print(f"  ok {base}{idx + 1}_white/black: {out.size}")
        else:
            # legacy single plate
            # if input was white plate, output as white? Keep simple: output as <base><idx>.png
            # but also support _white output if original had _white suffix
            if "_white" in sheet_path.stem:
                out.save(SRC / f"{base}{idx + 1}_white.png")
                print(f"  ok {base}{idx + 1}_white: {out.size}")
            else:
                out.save(SRC / f"{base}{idx + 1}.png")
                print(f"  ok {base}{idx + 1}: {out.size}")


def main():
    ap = argparse.ArgumentParser(description="Slice walk-cycle sheets (front/back aware)")
    ap.add_argument("sheet", nargs="?", help="sheet name without .png (e.g. colt_front_walk_sheet)")
    ap.add_argument("frames", nargs="?", type=int, default=5, help="number of frames")
    ap.add_argument("--all", action="store_true", help="slice all *_sheet.png")
    args = ap.parse_args()

    if args.all:
        sheets = sorted(SRC.glob("*_sheet.png"))
        # also white variants
        sheets_white = sorted(SRC.glob("*_sheet_white.png"))
        # deduplicate base
        processed_bases = set()
        for s in sheets + sheets_white:
            # skip black sheets — they are handled as pair
            if s.stem.endswith("_sheet_black"):
                continue
            stem = s.stem
            # base without _white
            base_stem = re.sub(r"_(white)$", "", stem)
            if base_stem in processed_bases:
                continue
            processed_bases.add(base_stem)

            # check for black pair
            if s.stem.endswith("_sheet_white"):
                black_candidate = SRC / f"{base_stem.replace('_white','')}_sheet_black.png"
                # actually original white sheet is like colt_front_walk_sheet_white.png
                # base_stem = colt_front_walk_sheet
                # black = colt_front_walk_sheet_black.png
                black_path = SRC / f"{base_stem}_black.png"
                if not black_path.exists():
                    # try alternative naming
                    black_path = SRC / f"{re.sub(r'_sheet$','',base_stem)}_sheet_black.png"
                    if not black_path.exists():
                        black_path = None
                slice_one_sheet(s, args.frames, black_path)
            else:
                # white sheet without suffix? check black pair
                black_path = SRC / f"{stem}_black.png"
                # also check <base>_sheet_black.png if stem is <base>_sheet
                if not black_path.exists():
                    # if s is colt_front_walk_sheet.png, black is colt_front_walk_sheet_black.png?
                    # Actually we look for colt_front_walk_sheet_black.png
                    alt = SRC / f"{stem}_black.png"
                    # stem already is _sheet, so alt = _sheet_black
                    # But we already have that
                    if alt.exists():
                        black_path = alt
                    else:
                        # check white+black pair exists as separate files?
                        # if s is colt_front_walk_sheet.png, maybe pair is colt_front_walk_sheet_white.png + _black.png
                        white_variant = SRC / f"{stem}_white.png"
                        if white_variant.exists():
                            # then we should slice white variant, not this
                            continue
                        black_path = None
                # if this sheet itself is the plain sheet (no white suffix) and there's no black pair,
                # slice it alone
                # But if there is a white/black pair with same base, prefer those
                white_pair = SRC / f"{stem}_white.png"
                black_pair = SRC / f"{stem}_black.png"
                if white_pair.exists() and black_pair.exists():
                    slice_one_sheet(white_pair, args.frames, black_pair)
                else:
                    slice_one_sheet(s, args.frames, black_path if black_path and black_path.exists() else None)
        return

    if not args.sheet:
        print(__doc__)
        return

    name = args.sheet.replace(".png", "")
    # support passing full path or just stem
    sheet_path = SRC / f"{name}.png"
    if not sheet_path.exists():
        # try with _white
        sheet_path_white = SRC / f"{name}_white.png"
        if sheet_path_white.exists():
            black_path = SRC / f"{name}_black.png"
            slice_one_sheet(sheet_path_white, args.frames, black_path if black_path.exists() else None)
            return
        print(f"not found: {sheet_path} nor {sheet_path_white}")
        sys.exit(1)

    # check for black pair with same base
    black_path = None
    # if sheet_path is ..._sheet.png, check ..._sheet_black.png exists?
    # Actually if user gave colt_front_walk_sheet, we check colt_front_walk_sheet_black.png
    # But typical pair is colt_front_walk_sheet_white.png + _black.png
    # So also check _white variant
    white_variant = SRC / f"{name}_white.png"
    black_variant = SRC / f"{name}_black.png"
    if white_variant.exists() and black_variant.exists():
        slice_one_sheet(white_variant, args.frames, black_variant)
    else:
        # check if sheet_path itself has a black counterpart (sheet + _black.png?)
        # e.g. colt_front_walk_sheet.png + colt_front_walk_sheet_black.png — unlikely
        maybe_black = SRC / f"{name}_black.png"
        if maybe_black.exists():
            black_path = maybe_black
        slice_one_sheet(sheet_path, args.frames, black_path)


if __name__ == "__main__":
    main()
