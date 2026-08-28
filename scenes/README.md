# Scenes — Editor-First

This folder now contains proper `.tscn` scenes instead of only procedural building.

## Quick Start

1. Open Godot 4.7
2. Open `res://scenes/game.tscn` → F6 to play
3. Edit `res://scenes/level_1.tscn` to move walls, doors, triggers, shop terminals
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
- `level_1.tscn` — the playable arena geometry + doors + triggers + terminals + environment (game.tscn uses this one)
- `level.tscn` — earlier standalone arena scene, kept for load tests
- `hud.tscn` — HUD CanvasLayer
- `environment.tscn` — WorldEnvironment + Sun (standalone)
- `game.tscn` — assembles Level + Player + Companion + Enemies + HUD; scripted by `scripts/game_root.gd`
- `main.tscn` — thin wrapper that instances `game.tscn`
- `main_menu.tscn` — menu that loads the intro cutscene, which loads `game.tscn`

## No Build Script Needed

The old procedural `game.gd` is gone. `scripts/level_director.gd` reads
whatever the level scene actually authored, through `level_1.gd`'s exports:

```gdscript
if "doors" in level:
	for d in level.doors: ...        # finds the Door instances
if "trigger_nodes" in level:
	for t in level.trigger_nodes: ... # finds the Area3D triggers
```

So you can:
- Add new doors/triggers in the editor and add them to the exported arrays
- Move doors/triggers visually — the director follows the node, not a coordinate
- Remove a door and the director simply skips the missing index

## Adding a New Room

1. Duplicate `Floor_Room2` in `level_1.tscn`, adjust size/position
2. Duplicate 2 wall `StaticBody3D` and adjust
3. Add a new `Door_-XX` in `Doors` container
4. Add a new `Trigger_RoomX` in `Triggers` container
5. Add the new door/trigger to `level_1.gd`'s exported arrays, then extend the
   `ROOMS` table in `scripts/room_plan.gd` (seal/open indices + spawn band)

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
