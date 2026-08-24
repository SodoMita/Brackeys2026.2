# Brackeys Game Jam 2026.2 — Godot Project Template

Godot **4.7.x** project scaffold for the jam: example game, headless test suite,
export presets for five platforms, and GitHub Actions CI.

## Repository layout

```
├── project.godot           # Engine config (GL Compatibility renderer, 1280×720)
├── scenes/main.tscn        # Main scene
├── scripts/
│   ├── game.gd             # Root: arena, waves, HUD, style meter, audio
│   ├── player.gd           # FPS controller (keyboard+mouse / gamepad / touch)
│   ├── enemy.gd            # Melee chaser AI
│   ├── touch_controls.gd   # Virtual stick + on-screen buttons (touch devices)
│   └── combat_logic.gd     # Pure combat math — unit-testable, no nodes
├── tests/
│   ├── test_runner.gd      # Headless runner (SceneTree script, no addons)
│   ├── test_base.gd        # Assertion helpers
│   ├── test_game_logic.gd  # Unit tests
│   └── test_scene.gd       # Scene integration tests
├── assets/                 # Art/audio go here
├── addons/                 # Third-party addons go here
├── export_presets.cfg      # Web / Windows / Linux / macOS / Android
└── .github/workflows/      # tests.yml + build.yml
```

## Running locally

Open the project in Godot 4.7.x and press **F5**, or from a terminal:

```bash
godot --path .          # run the game
```

## Tests

No addons required. Run the suite headless:

```bash
godot --headless --path . --import                       # once, builds caches
godot --headless --path . --script res://tests/test_runner.gd
```

Exit code is `0` on success, `1` on failure — CI uses this directly.
Add tests by dropping `tests/test_*.gd` files extending `TestBase`; every
`test_*` method is discovered automatically.

## Building

Export presets are committed in `export_presets.cfg`:

| Preset  | Output                              | Notes                              |
|---------|-------------------------------------|------------------------------------|
| Web     | `build/web/index.html` (+js/wasm/pck) | Threads disabled → no COOP/COEP |
| Windows | `build/windows/brackeys2026.2.exe` | x86_64, embedded PCK               |
| Linux   | `build/linux/brackeys2026.2.x86_64` | x86_64, embedded PCK               |
| macOS   | `build/macos/brackeys2026.2.zip`   | Unsigned `.app` bundle             |
| Android | `build/android/brackeys2026.2.apk` | arm64, debug-signed                |

Manual export:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

## CI / branch model

| Branch | What runs                                          |
|--------|----------------------------------------------------|
| `main` | **Tests only** (on push and on pull requests)      |
| `build`| **Tests + full multi-platform build**, artifacts uploaded, **Web build deployed to GitHub Pages** |

- `.github/workflows/tests.yml` — installs the Godot binary, imports the
  project, runs the test suite. Triggers on `main` and `build` pushes + PRs.
- `.github/workflows/build.yml` — installs Godot + export templates, generates
  an Android debug keystore, exports all five presets in parallel and uploads
  each as an artifact; the Web build is additionally deployed to
  **https://sodomita.github.io/Brackeys2026.2/** via the official Pages actions.
  Triggers only on the `build` branch (or manual dispatch).
  (Pattern adapted from the community reference `abarichello/godot-ci`.)

Ship a build by merging `main` into `build` and pushing.

## The game: STEEL KNIFE (GDD in `docs/GDD_STEEL_KNIFE.md`)

GDD-driven retro FPS (original assets, fully procedural), PSX-style 320×180
upscaled rendering. Mission 1: three sealed rooms (7 waves) of hounds and
bullet-hell spitters in a desert complex, scrap terminals between rooms,
COLT the colleague at your side — until the plaza, and the betrayal boss.
Blood heals, style decays, parry everything.

| Input | Move | Look | Jump | Dash | Slide | Fire | Weapons |
|---|---|---|---|---|---|---|---|
| Keyboard+mouse | WASD | mouse | SPACE | SHIFT | CTRL/C | LMB | 1 / 2 |
| Gamepad | left stick | right stick | A | LB | RB | RT | d-pad / Y |
| Touch | left stick | right drag | JMP | DSH | SLD | FIRE | WPN |

Touch controls appear automatically on touch devices (virtual stick + button
cluster); gamepad and keyboard work everywhere, including web exports.

## Art: DOOM-style billboard sprites with front/back + Seirin triangulation

Characters are 2D sprites in a gritty Road-of-the-Dead flash style
(cyborg partner COLT, mutant hound, spitter), generated as **2-3 frame**
walk-cycle sheets (side-by-side, 1 image), sliced by `tools/slice_sheet.py`
(connected components, any layout), matted to transparency by
`tools/make_sprites.py` using the **difference-matte triangulation from
github.com/SodoMita/Seirin** (`B=F*a, W=F*a+(1-a) => a=1-(W-B), F=B/a`):

- White plate: figure on pure white #FFFFFF
- Black plate: same pose/position/scale over pure black #000000, generated as **edit of white plate** so they register pixel-perfect
- Triangulate: `tools/triangulate_matte.py white black out --alpha-out alpha`
- Verify: `tools/check_matte.py out --report`

Front and back views are first-class:
- `colt_front_idle_white/black.png` + `colt_back_idle_white/black.png` -> `colt_front_idle.png` + `colt_back_idle.png`
- Walk: `colt_front_walk_sheet_white/black.png` (3 frames side-by-side) -> `colt_front_walk1-3.png` + `colt_back_walk1-3.png`
- Same for hound and spitter, with **straight back 180°** (not 3/4) for back view
- If a sheet already contains front+back (e.g. spitter idle sheet with front left, back right), slice it into front/back

Runtime: `SpriteLib.build_actor(kind)` returns `SpriteActor` (Node3D) with front/back switching based on dot(forward, to_player) — front when facing player, back when player behind. `enemy.gd` and `companion.gd` use this. Legacy `build()` still works with side-view fallback. Missing frames fall back to solid capsules so the game always runs. See `docs/SPRITES.md` for full workflow.

## Designer tuning

All gameplay values are `@export`ed on the **Cfg** autoload
(`scripts/game_config.tscn`): movement, health, parry window/cooldown,
weapon damage/cooldowns, coin toss & ricochet, style table & rank
thresholds, enemy stats & wave scaling, dialogue timeline. Open the scene
and edit in the inspector — no code changes needed.

## Dialogue

[Dialogic 2](https://github.com/dialogic-godot/dialogic) is vendored in
`addons/dialogic` (official repo, plugin enabled, `Dialogic` autoload).
A sample timeline lives at `dialogue/intro.dtl`; it plays at round start.
Assign any other timeline via `Cfg.intro_timeline` in the inspector.
Note: the Dialogic 2 alpha never registers its `.dtl` runtime loader, so
`game.gd` wires up the addon's own `DialogicTimelineFormatLoader` class,
and `*.dtl` is added to the export include filters.

## History

The original multi-purpose template (procedural runner example) is preserved
under the git tag `template`.

## Jam checklist

- [ ] Keep gameplay math in pure classes like `combat_logic.gd` so it stays testable.
- [ ] Swap `icon.svg` (and set an Android launcher icon in the preset when you have one).
- [ ] Update `package/unique_name` and `application/identifier`.
# test
