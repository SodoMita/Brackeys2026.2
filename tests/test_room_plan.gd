extends TestBase
## Unit tests for the wave/door table. RoomPlan is node-free, so this asserts
## the whole progression contract without instantiating a level.


func test_room_table_matches_authored_level() -> void:
	# scenes/level_1.tscn authors 5 doors and 3 triggers.
	assert_eq(float(RoomPlan.room_count()), 3.0, "three combat rooms")
	var referenced: Dictionary = {}
	for i in range(RoomPlan.room_count()):
		for d in RoomPlan.seal_doors(i):
			referenced[int(d)] = true
		for d in RoomPlan.open_doors(i):
			referenced[int(d)] = true
	assert_eq(float(referenced.size()), 5.0, "all five authored doors are used")
	for i in range(RoomPlan.room_count()):
		assert_lt(float(i), float(RoomPlan.room_count()), "index in range")


func test_boss_room_is_last() -> void:
	assert_false(RoomPlan.is_boss_room(0), "room 1 is not the boss")
	assert_false(RoomPlan.is_boss_room(1), "room 2 is not the boss")
	assert_true(RoomPlan.is_boss_room(2), "last room is the boss")
	assert_false(RoomPlan.is_boss_room(99), "out of range is not a boss room")
	assert_false(RoomPlan.is_boss_room(-1), "negative index is safe")


func test_door_wiring_does_not_overlap() -> void:
	# Each room seals what the previous room opened — no door is both.
	for i in range(RoomPlan.room_count() - 1):
		var opened: Array = RoomPlan.open_doors(i)
		var sealed_next: Array = RoomPlan.seal_doors(i + 1)
		assert_eq(opened, sealed_next, "room %d opens exactly what room %d seals" % [i, i + 1])


func test_boss_room_opens_nothing() -> void:
	assert_eq(float(RoomPlan.open_doors(RoomPlan.room_count() - 1).size()), 0.0,
		"beating the boss opens no further door (level is complete)")


func test_enemy_count_scaling() -> void:
	assert_eq(float(RoomPlan.enemy_count(0, 2)), 2.0, "base count in room 1")
	assert_eq(float(RoomPlan.enemy_count(1, 2)), 3.0, "base + wave in room 2")
	assert_eq(float(RoomPlan.enemy_count(0, 0)), 0.0, "zero base spawns nothing")
	assert_eq(float(RoomPlan.enemy_count(-1, 2)), 0.0, "negative room is safe")
	assert_eq(float(RoomPlan.enemy_count(9, 2)), 0.0, "out of range is safe")


func test_composition_is_deterministic() -> void:
	var a: Array = RoomPlan.composition(1, 2)
	var b: Array = RoomPlan.composition(1, 2)
	assert_eq(a, b, "same room always lays out the same way (no RNG)")


func test_spitters_appear_from_room_two() -> void:
	assert_false(RoomPlan.composition(0, 2).has("spitter"), "room 1 is melee only")
	assert_true(RoomPlan.composition(1, 3).has("spitter"), "room 2 introduces spitters")


func test_boss_composition_has_escort() -> void:
	var boss_room: Array = RoomPlan.composition(RoomPlan.room_count() - 1, 2)
	assert_eq(boss_room[0], "boss", "boss leads its own room")
	assert_gt(float(boss_room.size()), 1.0, "boss is not alone")
	var bosses := 0
	for k in boss_room:
		if String(k) == "boss":
			bosses += 1
	assert_eq(float(bosses), 1.0, "exactly one boss")


func test_composition_size_matches_enemy_count() -> void:
	for room in range(RoomPlan.room_count() - 1):
		assert_eq(float(RoomPlan.composition(room, 2).size()),
			float(RoomPlan.enemy_count(room, 2)), "non-boss rooms honour the count")


func test_spawn_points_inside_room_band() -> void:
	for room in range(RoomPlan.room_count()):
		var room_def: Dictionary = RoomPlan.ROOMS[room]
		var z_lo := float(room_def["z_min"])
		var z_hi := float(room_def["z_max"])
		var count := RoomPlan.composition(room, 2).size()
		var points: Array = RoomPlan.spawn_points(room, count)
		assert_eq(float(points.size()), float(count), "one point per enemy")
		for p in points:
			var v: Vector3 = p
			assert_le(absf(v.x), RoomPlan.SPAWN_HALF_WIDTH + 0.001, "x inside corridor")
			assert_ge(v.z, z_lo - 0.001, "spawn not past the far wall")
			assert_le(v.z, z_hi + 0.001, "spawn not behind the player")


func test_spawn_points_are_distinct() -> void:
	var points: Array = RoomPlan.spawn_points(1, 4)
	assert_eq(float(points.size()), 4.0, "four points requested")
	var seen: Dictionary = {}
	for p in points:
		seen[(p as Vector3).round() * 100.0] = true
	assert_gt(float(seen.size()), 1.0, "enemies do not stack on one point")


func test_spawn_point_edge_cases() -> void:
	assert_eq(float(RoomPlan.spawn_points(0, 0).size()), 0.0, "no enemies, no points")
	assert_eq(float(RoomPlan.spawn_points(0, 1).size()), 1.0, "single enemy centred")
	assert_eq(float(RoomPlan.spawn_points(-1, 3).size()), 0.0, "bad room is safe")
