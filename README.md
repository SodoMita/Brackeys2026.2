# SteelKnife
Arena shooter.

## Repository layout

```
├── project.godot           # Engine config (GL Compatibility renderer, 1280×720)
├── scenes/game.tscn        # Main gameplay scene (main.tscn wraps it)
├── scripts/
│   ├── game_root.gd        # Thin root: wires references, owns the run systems
│   ├── player.gd           # FPS controller (keyboard+mouse / gamepad / touch)
│   ├── enemy.gd            # Melee chaser AI
│   ├── combat_logic.gd     # Pure combat math — unit-testable, no nodes
│   ├── room_plan.gd        # Pure wave/door table — unit-testable, no nodes
│   ├── run_stats.gd        # Pure scoreboard (scrap, style, ranks) — no nodes
│   ├── combat_director.gd  # Damage, healing, stagger, bullet hell
│   ├── sfx.gd              # Procedural sound (autoload) — no audio assets
│   ├── camera_shake.gd     # Trauma shake, honours the screen_shake option
│   ├── level_director.gd   # trigger -> seal -> spawn -> clear -> open
│   ├── hud_controller.gd   # Binds the authored HUD to live run state
│   └── ui/
│       ├── ui_layers.gd    # CanvasLayer stack contract (hud<touch<dialog<pause<result)
│       ├── ui_manager.gd   # UI state machine: GAMEPLAY / DIALOG / PAUSED
│       ├── ui_kit.gd       # Shared procedural widget factory (colors, buttons)
│       ├── touch_controls.gd # Virtual stick + on-screen buttons (touch devices)
│       ├── settings_panel.gd # Settings screen (shared by main menu + pause)
│       ├── pause_menu.gd   # Pause menu (ESC / START / touch ||)
│       └── result_screen.gd # Victory / game-over card
├── tests/
│   ├── test_runner.gd      # Headless runner (SceneTree script, no addons)
│   ├── test_base.gd        # Assertion helpers
│   ├── test_combat.gd      # Combat math unit tests
│   ├── test_combat_director.gd # Damage / parry / volley integration tests
│   ├── test_sfx.gd         # Synthesis maths unit tests
│   ├── test_camera_shake.gd # Shake trauma, clamping, settings gate
│   ├── test_dialogue.gd    # .dtl loader registration + timeline resolution
│   ├── test_room_plan.gd   # Wave table / door wiring unit tests
│   ├── test_run_stats.gd   # Scrap / style / purchase unit tests
│   ├── test_level_director.gd # Progression integration tests
│   ├── test_input_map.gd   # Direct-launch input initialization
│   ├── test_scene.gd       # Scene integration tests
│   └── test_ui.gd          # UI layer / pause / dialog-state tests
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
They exist only in the GAMEPLAY UI state — `scripts/ui/ui_manager.gd` hides
and mutes them while a Dialogic timeline or the pause menu is on screen, so
screen-half look/move surfaces never swallow dialogue or menu taps.
CanvasLayer ordering is centralized in `scripts/ui/ui_layers.gd`
(HUD < touch < dialogue < pause) — never hardcode `layer` numbers.

## Game flow & progression

```
main_menu.tscn ──START──▶ cutscene_01.tscn ──timeline ends / skip──▶ game.tscn
                                                                     │
                                            ┌────────────────────────┘
                                            ▼
                    LevelDirector: trigger ▶ seal doors ▶ spawn wave
                               clear ▶ open next doors ▶ next room
                                            │
                    boss trigger ──▶ INTERLUDE ▶ betrayal.dtl ▶ COLT vanishes
                                            │           └──▶ release_room() ▶ boss
                    boss room cleared ──────┴──▶ ending timeline ▶ ResultScreen
                    player.hp <= 0 ────────────▶ ResultScreen (defeat)
```

The layering is deliberate — the numbers, the schedule and the nodes live in
separate files so each can be changed (or tested) on its own:

| File | Owns | Nodes? |
|------|------|--------|
| `scripts/game_config.gd` | every tunable number | no |
| `scripts/combat_logic.gd` | damage / style / rank maths | no |
| `scripts/room_plan.gd` | which doors seal, what each room spawns, where | no |
| `scripts/run_stats.gd` | scrap, style meter, kill counters, purchases | no |
| `scripts/combat_director.gd` | damage, healing, stagger, bullet-hell resolution | yes |
| `scripts/level_director.gd` | *when* a fight happens | yes |
| `scripts/camera_shake.gd` | trauma shake, driven by the `screen_shake` option | yes |
| `scripts/hud_controller.gd` | writing run state into `scenes/hud.tscn` | yes |
| `scripts/game_root.gd` | connecting all of the above | yes |

Combat resolution is separated the same way. `player.gd` only *reports* what it
hit (`fired`) and `enemy.gd` only *reports* its attacks (`attacked`, `volley`) —
neither calls `take_damage`. `scripts/combat_director.gd` is the single place
that turns those signals into consequences: it points each spawned enemy at the
player (its whole AI block is gated on `target`), applies headshot-multiplied
damage with knockback, heals the shooter (blood heals), staggers on a landed
parry, and spawns + hit-tests the spitter bullet-hell. Style is *not* awarded
there — `game_root.gd` owns the scoreboard and listens for the same events.

Rooms are derived from the authored geometry in `scenes/level_1.tscn` — the
three `Area3D` triggers and five `Door` instances already there. Each trigger
sits just past the doors it gates, so crossing it seals the pair behind the
player, spawns the wave, and clearing the room opens the next pair. The last
door is the boss gate: it starts shut and beating the boss completes the level.
To change the waves, edit the `ROOMS` table in `scripts/room_plan.gd`; to
change the counts, edit `wave_base_count` on `Cfg`.

### The betrayal

The GDD's ending is "the colleague betrays the player → boss fight", and
`dialogue/betrayal.dtl` was already written for it — it just played nowhere.
The boss room now opens with it: crossing the last trigger seals the gate and
puts `LevelDirector` in `Phase.INTERLUDE`, `companion.vanish()` walks COLT off
the map, the timeline plays, and `on_dialogue_ended()` calls `release_room()`
to spawn the boss — which deliberately reuses the corrupted COLT sprite set in
`sprite_lib.gd`, so the fight reads as the same character.

The hold is opt-in through `LevelDirector.start_gate`, a
`func(room_index) -> bool` that `game_root.gd` installs. If it returns `false`
the room spawns immediately, so a room can never be stranded behind sealed
doors with nothing to fight. `_gate_room_start()` returns `false` when the
betrayal timeline fails to load, and only ever fires once.

### Options that now actually do something

Three entries in the settings menu were stored and read by nothing:

| Option | Was | Now |
|--------|-----|-----|
| `screen_shake` | dead slider | scales trauma shake in `camera_shake.gd` |
| `controller_vibration` | dead toggle | gates `Input.start_joy_vibration` |
| `subtitles` | dead toggle | still unwired — needs Dialogic text capture |

Shake reads the setting on every kick rather than caching it, so dragging the
slider to zero silences it immediately. Rumble fires on damage taken, on a
landed parry, and lightly on every shot.

## Audio

There are no audio assets in this repo, and none are needed: `scripts/sfx.gd`
(autoloaded as `Sfx`) synthesises every effect at runtime from a `RECIPES`
table of `{freq, dur, wave, vol, decay}`. Waveforms are sine, square, saw and
a deterministic hashed noise, rendered to 16-bit mono PCM under an exponential
decay envelope.

`sfx.gd:RECIPES` covers shot / shotgun / nailgun / hit / headshot / die / hurt
/ dash / slide / parry / coin / windup / spit / buy / door / click / move /
victory / defeat. To retune a sound, edit that one table — there is nothing to
import. An 8-voice pool steals the quietest voice when all are busy, so a
shotgun's seven pellets do not cut each other off, and shot pitches are jittered
so stacked samples do not phase-cancel into one louder thud.

The synthesis maths (`synth_pcm`) is a pure static with no AudioServer
dependency, so it is unit-tested headless where there is no audio driver.

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
- `colt_front_idle_white/black.webp` + `colt_back_idle_white/black.webp` -> `colt_front_idle.webp` + `colt_back_idle.webp`
- Walk: `colt_front_walk_sheet_white/black.webp` (3 frames side-by-side) -> `colt_front_walk1-3.webp` + `colt_back_walk1-3.webp`
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
Timelines live in `dialogue/`: `cutscene_01` (intro cutscene, plays between
the menu and gameplay), `intro`, `quip1`, `betrayal` and `ending`.
Assign them via the `Dialogue` group on `Cfg` in the inspector —
`intro_timeline` (level start), `quip_timeline` (room clear) and
`ending_timeline` (victory, before the result card).

Note: Dialogic 2 ships `DialogicTimelineFormatLoader` but never registers it,
so `ResourceLoader` cannot resolve `res://**.dtl` at all. `game_config.gd`
(the first autoload) registers it in `_enter_tree()` and unregisters it in
`_exit_tree()`; without that, every timeline in the project is unloadable and
the game boots silently dialogue-free. `*.dtl` is also in the export include
filters for all five presets. `tests/test_dialogue.gd` covers both.

## History

The original multi-purpose template (procedural runner example) is preserved
under the git tag `template`.

## Jam checklist

- [ ] Keep gameplay math in pure classes like `combat_logic.gd` so it stays testable.
- [ ] Swap `icon.svg` (and set an Android launcher icon in the preset when you have one).
- [ ] Update `package/unique_name` and `application/identifier`.
# test
