# GDD "Steel Knife" — 16th Brackeys Game Jam
BulletHell · Action · FPS

## Concept
Futuristic desert-styled world (ULTRAKILL-esque, not open world). Gameplay-first
(80%), story is the cherry on top (20%). Main chapters with ~3 sub-chapters
each: 3 levels + an ending level.

## Structure (mission 1 implemented)
Wave/room based: crossing an invisible line seals the doors; 2–3 waves per
room; 3 rooms → 7 waves total. Between rooms: corridors with scrap terminals.
Ending: the colleague betrays the player → boss fight.

## Game cycle
Clear room → explore corridor → spend scrap (currency from kills) on weapons
and upgrades at terminals.

## Implemented mapping
- Rooms/doors/triggers: `scripts/room_plan.gd` (`ROOMS` table) driven by `scripts/level_director.gd`
- Bullet hell: spitter volleys + parryable projectiles (`projectile.gd`)
- Scrap & shop: `shop_terminal.gd` (nailgun / plating / overclock)
- Companion & betrayal: `companion.gd`, `dialogue/*.dtl`
- All tuning values: `Cfg` autoload (`scripts/game_config.tscn`)
