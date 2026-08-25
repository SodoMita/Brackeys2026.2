# Sprites — Seirin triangulation + front/back views

This project now uses the **Seirin white/black triangulation** pipeline for perfect alpha, with **front and back views** for DOOM-style billboard actors.

## Why triangulation?

Generators (Nano-Banana, Seedream, Krea class) **cannot output alpha**. A single flat-color background (green screen) destroys soft edges and translucent parts.

Seirin's method recovers alpha and true color exactly from a **pair of plates**:

```
B = F * a            (figure over pure black #000000)
W = F * a + (1-a)    (figure over pure white #FFFFFF)
=> a = 1 - (W - B)   ;   F = B / a
```

Where `a` is alpha, `F` is foreground color. The difference between plates is the alpha. Opaque pixels agree, transparent differ by full range, partial = soft edge.

**Critical rule from Seirin `sprite-spec.md`:** Never ask model to keep "character pixels identical" between plates — that flattens alpha to 1 and destroys the signal. Generate black plate as an **edit of the white plate** so they register pixel-perfect, with background genuinely showing through.

## File naming — WebP final

Plates live in `assets/src/` (PNG white/black pairs for triangulation):

```
<kind>_<direction>_<action><idx>_white.webp
<kind>_<direction>_<action><idx>_black.webp

Examples:
  colt_front_idle_white.webp + colt_front_idle_black.webp
  colt_back_idle_white.webp  + colt_back_idle_black.webp
  colt_front_walk1_white.webp + colt_front_walk1_black.webp
  colt_back_walk1_white.webp  + colt_back_walk1_black.webp
  hound_front_walk1_white.webp + hound_front_walk1_black.webp
  spitter_back_walk1_white.webp + spitter_back_walk1_black.webp

Sheets (optional, any layout):
  <kind>_<direction>_<action>_sheet_white.webp + _black.webp
  e.g. colt_front_walk_sheet_white.webp (3 frames side-by-side)
       colt_back_walk_sheet_white.webp
       spitter_front_walk_sheet_white.webp (3 frames side-by-side)
       hound_front_walk_sheet_white.webp
```

Direction tokens: `front` (facing camera), `back` (straight back 180°, not 3/4), `side` optional.

**Walk cycle:** 2-3 frames as requested, not 5. Each frame is a separate white/black pair, or a sheet with 3 figures side-by-side (or vertical) sliced by `slice_sheet.py`.

- For back, use **straight behind view**, not 3/4. Use back idle pic as reference for identity.
- For front that already contains back in same image (e.g. spitter idle sheet with front left, back right), slice it into front and back.

## Tools

All tools need Pillow + numpy + scipy:

```bash
python3 -m venv .venv
.venv/bin/pip install Pillow numpy scipy
```

### 1. `triangulate_matte.py` — core Seirin implementation

```bash
.venv/bin/python tools/triangulate_matte.py white.webp black.webp out.webp --alpha-out alpha.webp
.venv/bin/python tools/triangulate_matte.py --check-dir assets/sprites
```

Outputs lossy WebP (q=85) with alpha for final sprites.

- Normalizes white corners to exact white, black corners to exact black (generator haze).
- Computes per-channel alpha, mean, recovers foreground from black plate.
- Outputs straight (unpremultiplied) alpha RGBA.

### 2. `check_matte.py` — verification

```bash
.venv/bin/python tools/check_matte.py assets/sprites/colt_front_idle.webp --report
.venv/bin/python tools/check_matte.py assets/sprites --report
.venv/bin/python tools/check_matte.py sprite.webp --checks --out check.webp
```

Checks:
- Has transparency (not flattened)
- Has soft edges (partial alpha)
- Edge not contaminated by white/black background
- Creates checkerboard composite for visual verification

### 3. `make_sprites.py` — batch pipeline with front/back awareness

```bash
.venv/bin/python tools/make_sprites.py                    # all plates
.venv/bin/python tools/make_sprites.py colt_front_idle    # specific base
.venv/bin/python tools/make_sprites.py --check             # verify outputs
.venv/bin/python tools/make_sprites.py --pixelate          # NEAREST resize for crunchy PSX
.venv/bin/python tools/make_sprites.py --target-h 256
```

Pipeline per file:
1. Normalize white plate (corner median -> exact white)
2. Normalize black plate if present, else derive black via mask (legacy fallback, warns about binary alpha)
3. Triangulate -> RGBA straight alpha
4. Crop to content (alpha > 12) + 4px padding
5. Resize to TARGET_H (256) using LANCZOS (smooth) or NEAREST (crunchy)
6. Write `assets/sprites/<base>.webp`

Supports both:
- Paired: `<base>_white.webp` + `<base>_black.webp` -> `<base>.webp` (proper Seirin, soft edges)
- Legacy: `<base>.webp` alone -> derived black (binary alpha, warns)

### 4. `slice_sheet.py` — walk-cycle sheet slicer

Uses connected-component analysis, so any layout works (1x3, 3x1, 2x2, etc), reading order top->bottom, left->right.

```bash
.venv/bin/python tools/slice_sheet.py colt_front_walk_sheet 3
.venv/bin/python tools/slice_sheet.py hound_back_walk_sheet 3
.venv/bin/python tools/slice_sheet.py --all   # all *_sheet.webp
```

- If sheet has white/black pair (`*_sheet_white.webp` + `*_sheet_black.webp`), both are sliced identically, producing paired plates.
- Output: `<base>1_white.webp` + `<base>1_black.webp` etc.

Example: `colt_front_walk_sheet_white.webp` (5 figures) -> `colt_front_walk1_white.webp` + black etc.

## Generating new sprites (image generator)

Workflow per Seirin `SKILL.md`:

1. **White plate first:** Generate figure on pure white #FFFFFF, flat lighting, no shadows, full body visible, centered.
   Prompt must include: "on pure white background #FFFFFF, no shadows, no other objects, full body visible, game sprite"

2. **Black plate as edit:** Use white plate as reference image, prompt: "Identical character, same exact pose, position, scale, clothing, ... as reference image, but on pure black background #000000, solid black, no white, figure composited honestly over black so translucent edges show black through, keep registration pixel-perfect"

3. **Triangulate:** `python3 tools/triangulate_matte.py white black out`

4. **Verify:** `python3 tools/check_matte.py out --report` — should show double-digit transparent % and some partial %.

For walk cycles:
- Generate **2-3 frames** side-by-side sheet (1 image), not 5. Use vertical or horizontal layout, small gap between figures.
- For back view, **straight back 180°**, not 3/4. Generate individual straight behind pic first, then use it as reference for walk sheet to keep backpack/armor identical.
- If front image already contains back too (e.g. spitter idle sheet with front left, back right), slice it into front and back instead of generating separate back.

For COLT (cyborg partner):
- Must be **cyborg**, not human: half human half machine, robotic arm with pistons, metal chest implants, glowing orange eye implant, tan cap, dirty jacket, jeans, boots, gritty Road of the Dead flash style.

For enemies:
- Hound: cybernetic dog, metal jaw, red eyes, patchy fur with metal plates
- Spitter: tall lanky mutant, bio-mechanical backpack with green glowing acid tanks (2 small + 1 large + oval), gas mask, green veins

## Runtime — front/back switching

`scripts/sprite_lib.gd` defines `SETS` with directional variants:

```gdscript
"colt": {
  "walk_front": ["colt_front_walk1.webp", ...],
  "walk_back": ["colt_back_walk1.webp", ...],
  "idle_front": ["colt_front_idle.webp"],
  "idle_back": ["colt_back_idle.webp"],
  ...
}
```

`SpriteLib.build_actor(kind)` returns `SpriteActor` (Node3D) containing one `AnimatedSprite3D` that switches animation based on view angle:

- `to_target` = vector from self to player
- `forward` = enemy forward (-Z or velocity dir)
- dot = forward.dot(to_target_dir)
  - dot > -0.1 => front (facing player)
  - dot < -0.1 => back (player behind)

`SpriteActor` preserves frame when switching direction, supports `play("walk")` which chooses `walk_front` or `walk_back` automatically, and `set_flip_h`.

`enemy.gd` and `companion.gd` now use `SpriteActor`:
- Enemy: forward = look direction, to_target = player - enemy
- Companion COLT: forward = velocity dir or -to_player when idle, so player sees his back when he walks ahead.

Fallback: If no front/back textures exist, `SpriteLib.build()` returns legacy `AnimatedSprite3D` with side view, or capsule mesh.

## Current assets

After this pass:

- `assets/src/`: 43 white/black pairs (colt cyborg front/back idle/walk 3/shoot, hound front/back idle/walk 3/lunge, spitter front/back idle/walk 3/shoot)
- `assets/sprites/`: triangulated RGBA with LANCZOS resize, TARGET_H=256, soft edges (partial alpha 5-26%)

Check with:

```bash
.venv/bin/python tools/check_matte.py assets/sprites --report
```

Legacy plates (old colt_walk1-3 side views, colt_idle side) still exist as fallback but are now superseded by front/back cyborg versions.

## Future

- Generate black plates for spitter shoot (currently legacy, hit image gen limit)
- Boss corrupted COLT variant (tinted red in game.gd currently)
- Optional side views for 4-direction DOOM style
