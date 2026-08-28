class_name RoomPlan
extends RefCounted
## Pure, node-free description of what each room seals, opens and spawns.
##
## Deliberately free of Node/SceneTree dependencies so the whole progression
## table can be asserted in tests/test_room_plan.gd without instantiating a
## level. scripts/level_director.gd is the only thing that touches nodes.
##
## Room layout is derived from the authored geometry in scenes/level_1.tscn:
##
##   doors   z = -28, -36 | -64, -72 | -100 (last one is 3.5x wide = boss gate)
##   triggers z = -40, -76, -105
##
## The player walks towards -Z, so each trigger sits just past the doors it
## gates: crossing it seals the pair behind them and spawns the room's wave.
## Clearing the room opens the next pair.

## Authored door/trigger wiring, in the order the player meets them.
const ROOMS := [
	{
		"name": "room_1",
		"seal": [0, 1],     # doors closed once the player is committed
		"open": [2, 3],     # doors released when the room is clear
		"z_min": -60.0,     # spawn band (further from the player)
		"z_max": -42.0,     # spawn band (closer to the player)
		"boss": false,
	},
	{
		"name": "room_2",
		"seal": [2, 3],
		"open": [4],
		"z_min": -96.0,
		"z_max": -78.0,
		"boss": false,
	},
	{
		"name": "boss_room",
		"seal": [4],
		"open": [],
		"z_min": -120.0,
		"z_max": -106.0,
		"boss": true,
	},
]

## Half-width of the corridor the spawn band may use.
const SPAWN_HALF_WIDTH := 12.0
## Every third enemy from this room onwards is a ranged spitter.
const SPITTER_FROM_ROOM := 1
const SPITTER_EVERY := 3
## How many hounds keep the boss company.
const BOSS_ESCORT := 2


static func room_count() -> int:
	return ROOMS.size()


static func is_boss_room(room_index: int) -> bool:
	if room_index < 0 or room_index >= ROOMS.size():
		return false
	return bool(ROOMS[room_index]["boss"])


## Door indices that slam shut when room_index starts.
static func seal_doors(room_index: int) -> Array:
	return _int_array(room_index, "seal")


## Door indices that slide open when room_index is cleared.
static func open_doors(room_index: int) -> Array:
	return _int_array(room_index, "open")


## Enemy count for a room. Matches Cfg's documented `count = base + wave`.
static func enemy_count(room_index: int, base_count: int) -> int:
	if room_index < 0 or room_index >= ROOMS.size():
		return 0
	return maxi(0, int(base_count) + room_index)


## Deterministic mix of enemy kinds — no RNG, so tests can assert exact output.
static func composition(room_index: int, base_count: int) -> Array:
	var out: Array = []
	if room_index < 0 or room_index >= ROOMS.size():
		return out
	var count := enemy_count(room_index, base_count)
	if bool(ROOMS[room_index]["boss"]):
		# Boss plus a small escort so the arena is not a single-target fight.
		out.append("boss")
		for i in range(BOSS_ESCORT):
			out.append("hound")
		return out
	for i in range(count):
		var kind := "hound"
		if room_index >= SPITTER_FROM_ROOM and i % SPITTER_EVERY == SPITTER_EVERY - 1:
			kind = "spitter"
		out.append(kind)
	return out


## Evenly spread spawn points across the room's band, centred on the corridor.
## Pure function of (room, count) so the same room always lays out the same way.
static func spawn_points(room_index: int, count: int) -> Array:
	var out: Array = []
	if room_index < 0 or room_index >= ROOMS.size() or count <= 0:
		return out
	var room: Dictionary = ROOMS[room_index]
	var z_min := float(room["z_min"])
	var z_max := float(room["z_max"])
	if count == 1:
		out.append(Vector3(0.0, 0.0, (z_min + z_max) * 0.5))
		return out
	# Rows of at most 4, walking away from the player as the room fills up.
	var per_row := 4
	for i in range(count):
		var row := i / per_row
		var col := i % per_row
		var in_row := mini(per_row, count - row * per_row)
		var t := 0.5 if in_row == 1 else float(col) / float(in_row - 1)
		var x := lerpf(-SPAWN_HALF_WIDTH, SPAWN_HALF_WIDTH, t)
		var span := z_max - z_min
		var z := z_max - span * (float(row) / float(maxi(1, (count - 1) / per_row + 1)))
		out.append(Vector3(x, 0.0, z))
	return out


static func _int_array(room_index: int, key: String) -> Array:
	if room_index < 0 or room_index >= ROOMS.size():
		return []
	return (ROOMS[room_index][key] as Array).duplicate()
