#!/usr/bin/env python3
"""Slice a walk-cycle sheet (any row/column layout) into white plates.

Uses connected-component analysis so sheets laid out as 1x5, 2x3, etc.
all work. Frames are returned in reading order (top row first).

Usage: python3 tools/slice_sheet.py <sheet_name> [frames=5]
Writes assets/src/<base>1.png ... <base>N.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "src"


def slice_sheet(name: str, frames: int = 5) -> None:
    im = Image.open(SRC / f"{name}.png").convert("RGB")
    a = np.asarray(im).astype(np.float64)
    mask = (a < 250.0).any(axis=2)
    # close small internal gaps so each figure is one component
    mask = ndimage.binary_closing(mask, structure=np.ones((5, 5)))
    labels, n = ndimage.label(mask)
    objs = ndimage.find_objects(labels)
    boxes = []
    for i, sl in enumerate(objs):
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if h * w < 2000:  # noise
            continue
        yc = (sl[0].start + sl[0].stop) / 2
        xc = (sl[1].start + sl[1].stop) / 2
        boxes.append((yc, xc, sl))
    # reading order: cluster into rows by y, then sort by x
    boxes.sort(key=lambda b: b[0])
    rows = []
    for b in boxes:
        placed = False
        for row in rows:
            if abs(row[0][0] - b[0]) < im.height * 0.25:
                row.append(b)
                placed = True
                break
        if not placed:
            rows.append([b])
    ordered = []
    for row in rows:
        row.sort(key=lambda b: b[1])
        ordered.extend(row)
    ordered = ordered[:frames]
    base = name.replace("_sheet", "")
    for idx, (yc, xc, sl) in enumerate(ordered):
        sub = im.crop((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
        out = Image.new("RGB", sub.size, (255, 255, 255))
        out.paste(sub, (0, 0))
        out.save(SRC / f"{base}{idx + 1}.png")
        print(f"ok {base}{idx + 1}: {out.size}")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    slice_sheet(args[0], int(args[1]) if len(args) > 1 else 5)


if __name__ == "__main__":
    main()
