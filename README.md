# Brackeys Game Jam 2026.2 — Godot Project Template

Godot **4.7.x** project scaffold for the jam: example game, headless test suite,
export presets for five platforms, and GitHub Actions CI.

## Repository layout

```
├── project.godot           # Engine config (GL Compatibility renderer, 1280×720)
├── scenes/main.tscn        # Main scene
├── scripts/
│   ├── game.gd             # Example game (synthwave runner, fully procedural)
│   └── game_logic.gd       # Pure gameplay math — unit-testable, no nodes
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

## Jam checklist

- [ ] Replace `scripts/game.gd` with your game; keep logic in pure classes like `game_logic.gd` so it stays testable.
- [ ] Swap `icon.svg` (and set an Android launcher icon in the preset when you have one).
- [ ] Update `package/unique_name` and `application/identifier`.
