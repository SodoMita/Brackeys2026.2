# Scenes — Editor-First

This folder now contains proper `.tscn` scenes instead of only procedural building.

## Quick Start

1. Open Godot 4.7
2. Open `res://scenes/game.tscn` → F6 to play
3. Edit `res://scenes/level.tscn` to move walls, doors, triggers, shop terminals
4. Edit `res://scenes/player.tscn` to tweak camera, gun mesh, collision
5. Edit `res://scenes/hud.tscn` to reposition HUD elements

## Scene Graph

- `player.tscn` — FPS controller, uses `player.gd`
- `companion.tscn` — COLT, uses `companion.gd` + `SpriteLib`
- `enemy.tscn` — base, exports `kind`
  - `enemies/hound.tscn` — melee
  - `enemies/spitter.tscn` — ranged
  - `enemies/boss.tscn` — boss
- `projectile.tscn` — spitter bullet
- `shop_terminal.tscn` — scrap shop
- `level.tscn` — arena geometry + doors + triggers + terminals + environment
- `hud.tscn` — HUD CanvasLayer
- `environment.tscn` — WorldEnvironment + Sun (standalone)
- `game.tscn` — assembles Level + Player + Companion + Enemies + HUD + game.gd logic
- `main.tscn` — legacy procedural (still works)
- `main_menu.tscn` — menu that loads `game.tscn`

## No Build Script Needed

Previously `game.gd` built everything in code. Now it checks if nodes exist:

```gdscript
if get_node_or_null("Level") != null:
    _collect_from_level(Level)  # finds Doors, Terminals, Triggers
else:
    _build_level()  # fallback

if get_node_or_null("Player") != null:
    _wire_player(Player)
else:
    _build_player()
```

So you can:
- Delete a node in the scene → it gets recreated procedurally (safe fallback)
- Add new nodes in editor → they are used
- Move doors/triggers visually → game logic follows

## Adding a New Room

1. Duplicate `Floor_Room2` in `level.tscn`, adjust size/position
2. Duplicate 2 wall `StaticBody3D` and adjust
3. Add a new `Door_-XX` in `Doors` container
4. Add a new `Trigger_RoomX` in `Triggers` container
5. Update `ROOMS` and `DOOR_Z` in `game.gd` if you want wave logic, or keep manual spawning

## Sprite Setup

Enemies and companion use `SpriteLib.build_actor(kind)` at runtime which loads `assets/sprites/<kind>_front_*.webp` etc. To preview in editor:

1. Add `AnimatedSprite3D` child to enemy
2. Create `SpriteFrames` resource
3. Add animations `idle_front`, `walk_front`, etc. with textures from `assets/sprites/`
4. At runtime, `enemy.gd` will reuse existing sprite if found, else build one

## Audio

If `SFX` node with children `Shot`, `Hit`, etc. exists, game uses them. Otherwise it generates procedural tones (sine/square/noise) via `_tone()`. You can replace procedural with imported `AudioStreamWAV`/`Ogg` by adding AudioStreamPlayers named accordingly under `SFX`.

## See Also

- `docs/SCENE_BUILD.md` — step-by-step manual build instructions
- `docs/SPRITES.md` — sprite triangulation workflow
- `docs/GDD_STEEL_KNIFE.md` — game design
