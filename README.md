# Brackeys Game Jam 2026.2 — Godot Project Template

Godot **4.7.x** project scaffold for the jam: example game, headless test suite,
export presets for five platforms, and GitHub Actions CI.

## Repository layout

```
├── project.godot           # Engine config (GL Compatibility renderer, 1280×720 viewport)
├── scenes/
│   ├── main_menu.tscn      # Dedicated main menu scene (entry point)
│   ├── game.tscn           # Gameplay scene (arena, waves, combat)
│   └── main.tscn           # Main game scene alias
├── scripts/
│   ├── main_menu.gd        # Main menu controller (START / SETTINGS / QUIT)
│   ├── game.gd             # Game scene root: arena, waves, HUD, style meter, audio
│   ├── menus.gd            # In-game pause menu & settings panel
│   ├── settings.gd         # Player settings: live apply + user://settings.cfg
│   ├── player.gd           # FPS controller (keyboard+mouse / gamepad / touch)
│   ├── enemy.gd            # Melee chaser AI & ranged spitter AI
│   ├── touch_controls.gd   # Mobile FPS HUD & touch controls (joystick, actions, pause)
│   ├── shop_terminal.gd    # In-game scrap upgrade shop terminal
│   └── combat_logic.gd     # Pure combat math — unit-testable, no nodes
├── tests/
│   ├── test_runner.gd      # Headless runner (SceneTree script, no addons)
│   ├── test_base.gd        # Assertion helpers
│   ├── test_combat.gd      # Unit tests for combat logic
│   ├── test_settings.gd    # Settings persistence and live apply tests
│   ├── test_scene.gd       # Scene integration tests (menu, game, pause, mobile button)
│   └── playtest.gd         # Automated headless gameplay playthrough test
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

GDD-driven retro FPS (original assets, fully procedural), 1280×720 rendering.
Mission 1: three sealed rooms (7 waves) of hounds and bullet-hell spitters
in a desert complex, scrap terminals between rooms, COLT the colleague at
your side — until the plaza, and the betrayal boss. Blood heals, style decays,
parry everything.

| Input | Move | Look | Jump | Dash | Slide | Fire | Weapons | Pause |
|---|---|---|---|---|---|---|---|---|
| Keyboard+mouse | WASD | mouse | SPACE | SHIFT | CTRL/C | LMB | 1 / 2 / 3 | ESC / P |
| Gamepad | left stick | right stick | A | LB | RB | RT | d-pad / Y | START |
| Touch | left stick | right drag | JMP | DSH | SLD | FIRE | WPN / PRY / COIN | `||` button |

Touch controls appear automatically on touch devices (virtual stick + action buttons + mobile pause button); gamepad and keyboard work everywhere, including web exports.

## Menus, Pause & Mobile Support

- **Separate Main Menu Scene (`scenes/main_menu.tscn`)** — Clean standalone
  scene that loads the game (`scenes/game.tscn`). Offers START, SETTINGS,
  and QUIT GAME (quit is hidden on web). Clicking anywhere, tapping, or
  pressing gamepad A/START also starts the game.
- **In-Game Pause Menu (`scripts/menus.gd`)** — Pauses the game tree during
  play. Features RESUME, SETTINGS, RETRY MISSION, and QUIT TO MENU (returns to
  the main menu scene).
- **Mobile Pause Button** — Dedicated on-screen `||` button on mobile and
  touchscreen devices to open the pause menu and return to the main menu at
  any point.
- **Settings** — Mouse sensitivity & stick speed (×0.2–×3 of designer
  defaults), invert look, master volume, fullscreen (desktop only; hidden on
  web), RESET DEFAULTS / BACK. Everything applies live and persists to
  `user://settings.cfg`.
- **Mobile FPS HUD & Touch Controls** — Dynamic movement joystick on the left,
  drag look on the right, responsive action buttons for FIRE, JMP, DSH, SLD,
  WPN, PRY, COIN, and PAUSE, plus retro HUD displaying health, style rank, wave,
  scrap counter, weapon slot, and hitmarkers.

## Art: DOOM-style billboard sprites

Characters are 2D sprites in a gritty Road-of-the-Dead flash style
(cyborg partner, mutant/bot enemies), generated as 5-frame walk-cycle
sheets, sliced by `tools/slice_sheet.py` (connected components, any
layout), matted to transparency by `tools/make_sprites.py` using the
difference-matte triangulation from github.com/SodoMita/Seirin, and
rendered in-game as billboarded `AnimatedSprite3D`s (`sprite_lib.gd`).
Player stays fully 3D first-person. Missing frames fall back to solid
capsules so the game always runs.

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

## Jam checklist

- [ ] Keep gameplay math in pure classes like `combat_logic.gd` so it stays testable.
- [ ] Swap `icon.svg` (and set an Android launcher icon in the preset when you have one).
- [ ] Update `package/unique_name` and `application/identifier`.
