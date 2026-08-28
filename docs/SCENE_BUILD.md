# Scene Build Guide — No-Code Procedural Fallback, Editor-First Workflow

This project originally built everything procedurally in `_ready()` (floors, walls, doors, player, companion, HUD, audio). It now also supports **proper Godot `.tscn` scenes** that you can edit in the editor without touching code. The scripts are hybrid: if a node exists in the scene they reuse it, otherwise they create it procedurally (so old `main.tscn` still works).

## Created Scenes

All scenes are in `res://scenes/`:

```
scenes/
  player.tscn           # CharacterBody3D + CollisionShape + Head/Camera/Muzzle/Gun
  companion.tscn        # CharacterBody3D (COLT) + CollisionShape, sprite added at runtime via SpriteLib
  enemy.tscn            # Base enemy (CharacterBody3D, kind export)
  enemies/
    hound.tscn          # inherits enemy.tscn, kind=hound, melee
    spitter.tscn        # kind=spitter, ranged=true
    boss.tscn           # kind=boss, is_boss=true, scale 1.5
  projectile.tscn       # Area3D bullet-hell projectile
  shop_terminal.tscn    # StaticBody3D shop
  level.tscn            # Full arena: floors, walls, doors, triggers, shop terminals, environment
  hud.tscn              # CanvasLayer HUD: HP, Rank, Wave, Scrap, Weapon, Crosshair, HurtFlash, Overlay
  environment.tscn      # WorldEnvironment + Sun (reuse if you want separate)
  game.tscn             # Main gameplay scene: Level + Enemies + Player + Companion + HUD, scripted by game_root.gd
  main.tscn             # Thin wrapper that instances game.tscn
  main_menu.tscn        # Menu (UI built procedurally from scripts/ui/ui_kit.gd)
```

Boot order: `main_menu.tscn` (the project's main scene) → `dialogue/cutscence/cutscene_01.tscn` (intro, skippable) → `game.tscn`.

## How Scripts Were Made Scene-Friendly

Previously `_init()` created child nodes unconditionally. Now:

- `_init()` does nothing (or only sets defaults)
- `_ready()` calls `_ensure_nodes()` / `_ensure_collision()` / `_ensure_visuals()` which:
  - checks `get_node_or_null("CollisionShape3D")`, `Head`, `Camera3D`, etc.
  - if missing, creates them procedurally (so scene still works if you delete them)
  - if present, reuses them

This pattern is applied to:
- `player.gd` — looks for `Head`, `Camera3D`, `MuzzleLight`, `GunMesh`, `CollisionShape3D`
- `enemy.gd` — looks for existing `SpriteActor`/`AnimatedSprite3D`, else builds via `SpriteLib`
- `companion.gd` — same
- `shop_terminal.gd` — looks for `Mesh` + `CollisionShape3D`
- `projectile.gd` — looks for `Mesh` + `CollisionShape3D`
- `game_root.gd` — resolves `Player`, `Companion`, `Enemies`, `HUD`, `Level1` with
  `get_node_or_null`, so a missing node degrades gracefully instead of erroring.
  (It has no procedural `_build_*` fallback — the old root's builder is gone.)

Exports were added:
- `enemy.gd`: `@export_enum("hound","spitter","boss","colt") var kind`, `@export var ranged`, `custom_hp`, `custom_speed`, `is_boss`
- `player.gd`: `head_path`, `camera_path`, `muzzle_path` (NodePath) so you can rewire in inspector

## How to Build Each Scene Manually (Editor Steps)

### 1. Player (`player.tscn`)
1. Create `CharacterBody3D` named `Player`, attach `res://scripts/player.gd`
2. Add child `CollisionShape3D` with `CapsuleShape3D` radius 0.4 height 1.6 at (0,0.8,0)
3. Add child `Node3D` named `Head` at (0,1.6,0)
4. Under `Head`:
   - `Camera3D` named `Camera3D`, FOV 90, Far 200
   - `OmniLight3D` named `MuzzleLight` at (0.3,-0.25,-0.9), color (1,0.75,0.35), energy 0, range 7
   - `MeshInstance3D` named `GunMesh` at (0.28,-0.24,-0.55) with `BoxMesh` 0.07x0.11x0.55, material dark (0.12,0.12,0.16)
5. Save as `res://scenes/player.tscn`

### 2. Companion (`companion.tscn`)
1. `CharacterBody3D` named `Companion`, script `companion.gd`
2. `CollisionShape3D` capsule 0.4x1.6 at (0,0.8,0)
3. (Optional) Add `AnimatedSprite3D` with `SpriteFrames` built from `assets/sprites/colt_front_*.webp` etc. Or leave empty — runtime `SpriteLib.build_actor("colt")` will add it.
4. Save

### 3. Enemy Base (`enemy.tscn`)
1. `CharacterBody3D` named `Enemy`, script `enemy.gd`
2. Set exports: `kind = hound`, `ranged = false`
3. `CollisionShape3D` capsule 0.45x1.5 at (0,0.75,0)
4. (Optional) Add `SpriteActor` placeholder. Runtime will create one via `SpriteLib` if missing.
5. Save as `enemy.tscn`
6. For variants: Create Inherited Scene → change `kind` export:
   - `hound.tscn`: kind hound, ranged false
   - `spitter.tscn`: kind spitter, ranged true
   - `boss.tscn`: kind boss, is_boss true, scale 1.5, custom_hp 400

### 4. Projectile (`projectile.tscn`)
1. `Area3D` named `Projectile`, script `projectile.gd`, `monitoring = false`
2. Child `MeshInstance3D` named `Mesh` with `SphereMesh` radius 0.18 height 0.36, material unshaded orange (1,0.6,0.1)
3. Child `CollisionShape3D` with `SphereShape3D` radius 0.25
4. Save

### 5. Shop Terminal (`shop_terminal.tscn`)
1. `StaticBody3D` named `ShopTerminal`, script `shop_terminal.gd`
2. Child `MeshInstance3D` named `Mesh` at (0,0.7,0) with `BoxMesh` 0.8x1.4x0.4, material dark with emission (1,0.6,0.1)*0.8
3. Child `CollisionShape3D` with `BoxShape3D` same size
4. Save

### 6. Level (`level.tscn`)
This is the most involved. You can build it entirely in editor, or instance the provided `level.tscn` and edit.

**Structure to recreate:**
- `Node3D` named `Level`
  - `WorldEnvironment` with Environment: bg Color(0.12,0.07,0.03), ambient Color(0.8,0.6,0.4) energy 0.6, fog enabled Color(0.5,0.3,0.12) density 0.01, tonemap filmic
  - `DirectionalLight3D` named `Sun`, rotation (-55,20,0), color (1,0.85,0.6), energy 1.1
  - `StaticBody3D` `WorldBoundary` with `WorldBoundaryShape3D`
  - `Node3D` `Floors`:
    - Each floor is `MeshInstance3D` with `PlaneMesh`:
      - Room1: size 28x34 at (0,0,-11)
      - Corr1: 8x8 at (0,0,-32)
      - Room2: 28x28 at (0,0,-50)
      - Corr2: 8x8 at (0,0,-68)
      - Room3: 28x28 at (0,0,-86)
      - Plaza: 28x30 at (0,0,-115)
    - Materials: sandy colors (0.4,0.32,0.16) and (0.36,0.25,0.12)
  - `Node3D` `Walls`:
    - For each floor segment, 2 side walls: `StaticBody3D` at X ±(width/2+0.5), Y 3, Z center, with `BoxShape3D` 1x6xlength and `BoxMesh` same, material dark (0.16,0.1,0.06) emission (1,0.5,0.15)*0.2
  - `Node3D` `EndWalls`:
    - Front at (0,3,6) and Back at (0,3,-130) with Box 30x6x1
  - `Node3D` `Doors`:
    - 5 doors: Node3D at (0,0,Z) where Z = -28,-36,-64,-72,-100
    - Each door has child `StaticBody3D` `Body` with `CollisionShape3D` Box (width 8 for first 4, 28 for last) x5x1 and `MeshInstance3D` `Mesh` at (0,2.5,0) with BoxMesh same, material door (0.2,0.12,0.07) emission (1,0.4,0.1)*0.5
    - Name them `Door_-28` etc. Game code finds them by name `Door_*` or by having child `Body/Mesh`
  - `Node3D` `Triggers`:
    - 3 `Area3D`: `Trigger_Room2` at (0,2,-40) size 8x4x1, `Trigger_Room3` at (0,2,-76) size 8x4x1, `Trigger_Boss` at (0,2,-105) size 28x4x1
    - Game code wires these by name: Room2 → `_enter_room(1)`, Room3 → `_enter_room(2)`, Boss → `_betrayal()`
  - `Node3D` `ShopTerminals`:
    - Instance `shop_terminal.tscn` at (2.6,0,-32) and (-2.6,0,-68)

You can also use CSGBoxes for walls for easier editing, then convert to StaticBody.

### 7. HUD (`hud.tscn`)
1. `CanvasLayer` named `HUD` (layer 1, passive — no input)
2. Children (mobile-friendly: large fonts, safe margins, no overlapping rows):
   - `Label` `Wave` at (14,12) font 17 color (0.9,0.82,0.62) text "ROOM 1"
   - `Label` `Scrap` at (14,44) font 17 color (1,0.85,0.4) text "SCRAP 0"
   - `Label` `HP` at (14,80) font 24 color (1,0.72,0.32) text "100"
   - `ColorRect` `HPBarBack` at (14,114) size 240×18, dark fill, mouse_filter Ignore
   - `ColorRect` `HPFill` at (16,116) size 236×14 — width/color driven by
     `hud_controller.gd` (green→red as HP drops), mouse_filter Ignore
   - `Label` `Weapon` at (14,140) font 14 color (0.85,0.85,0.88) text "REVOLVER"
   - `Label` `Rank` top-center font 30 color (0.78,0.78,0.82) text "D"
   - `Node` `Crosshair` centered with 4 visible `ColorRect` ticks (9×4 with a
     5px gap) + center `Dot` — always on, essential on touch devices
   - `ColorRect` `HurtFlash` full rect, color (1,0,0.1,0), mouse_filter Ignore
   - `Label` `Overlay` full rect, centered, font 22 color (1,0.78,0.45),
     text "S T E E L   K N I F E"
3. Save

### 8. Game (`game.tscn`)
1. `Node3D` named `Game`, attach `res://scripts/game_root.gd`
2. Instance `Level` as child named `Level`
3. Add `Node3D` `Enemies`
4. Instance `Player` at (0,0,-4)
5. Instance `Companion` at (2,0,-2)
6. Instance `HUD` as child
7. (Optional) Add `Node` `SFX` with `AudioStreamPlayer` children named `Shot`, `Hit`, `Headshot`, `Die`, `Hurt`, `Dash`, `Slide`, `Parry`, `Coin`, `Windup`, `Spit`, `Buy`, `Door`.
   The runtime tone synthesiser lived in the old procedural root and is not wired up yet — audio is currently silent.
8. Save as `res://scenes/game.tscn`
9. `cutscene_01.gd` targets `game.tscn` (falling back to `main.tscn`); `main_menu.gd` targets the cutscene

## Wiring Logic (How Game Finds Scene Nodes)

`game_root.gd::_ready()` does:

```
Player exists  -> sets enemy_pool, connects fired / parried / player_died
Companion      -> sets player_ref
Level1         -> hands doors + trigger_nodes to LevelDirector, terminals get player_ref + setup_ui
Enemies        -> LevelDirector spawn pool
HUD            -> HudController binds HP / Rank / Wave / Scrap / Weapon / Overlay / HurtFlash
(always)       -> creates RunStats, LevelDirector, HudController, ResultScreen, UIManager
```

Triggers: `level_director.gd` connects each authored `Area3D`'s `body_entered`
and arms rooms strictly in order — crossing trigger *i* seals the doors listed
in `RoomPlan.ROOMS[i].seal`, spawns that room's wave, and opening happens on
clear via `RoomPlan.ROOMS[i].open`.

Doors: `door.gd::door_set(closed)` disables `CollisionShape3D` and tweens the
mesh Y between 2.5 (shut) and 6.5 (open).

## Testing

- Open `res://scenes/game.tscn` and press F6 (Run Current Scene)
- Or run main menu: `res://scenes/main_menu.tscn` → Start → loads `game.tscn`
- `main.tscn` instances `game.tscn`

## Extending

- Spawn positions come from `RoomPlan.spawn_points()` (an even spread across each room's band). To place enemies by hand instead, add `Marker3D` nodes and read them in `level_director.gd::_spawn()`
- Add lights: instance `OmniLight3D` in corridors for scrap terminal glow
- Add decals: `Decal` nodes on walls for grit
- Replace floor `PlaneMesh` with `CSGBox` or imported `glTF` from Blender
- For sprites: add `SpriteActor` manually — `SpriteLib.build_actor(kind)` returns a Node3D with `AnimatedSprite3D` that switches front/back based on dot product. You can instance it in editor by adding a `Node3D` and attaching a script that calls `SpriteLib.build_actor` in `_ready()` or by manually creating `AnimatedSprite3D` with frames from `assets/sprites/`

## Why This Approach?

- No need for a separate "scene build script" — scenes are editor-editable, version-controlled, and can be opened by level designers
- Hybrid fallback means you can delete any part of the scene and it will still run (procedural creation)
- All tuning remains in `Cfg` autoload (`scripts/game_config.tscn`) — edit in inspector
- Dialogic timelines are started by `game_root.gd::_say_timeline()` and by the intro cutscene

## Checklist for New Level

- [ ] Create new `Level2.tscn` inheriting `Level` or from scratch
- [ ] Extend the `ROOMS` table in `scripts/room_plan.gd` (seal/open door indices + spawn band)
- [ ] Place `Door_*` nodes and `Trigger_*` areas
- [ ] Place `ShopTerminal` instances
- [ ] Instance Player/Companion/HUD
- [ ] Save as `scenes/game2.tscn` and add to `main_menu.gd` map selector
