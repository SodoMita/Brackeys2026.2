extends TestBase
## Integration tests for LevelDirector: trigger -> seal -> spawn -> clear ->
## open, using lightweight stand-ins for the level and doors so the whole
## progression can be driven deterministically headless.

const FAKE_LEVEL := "res://tests/fake_level.gd"
const FAKE_DOOR := "res://tests/fake_door.gd"

var _owned: Array = []


func _track(n: Node) -> Node:
	_owned.append(n)
	return n


func _teardown() -> void:
	for n in _owned:
		if n != null and is_instance_valid(n):
			n.free()
	_owned.clear()


func _rig() -> Dictionary:
	var level: Node3D = (load(FAKE_LEVEL) as GDScript).new()
	var doors: Array = []
	for i in range(5):
		var d: Node3D = (load(FAKE_DOOR) as GDScript).new()
		level.add_child(d)
		doors.append(d)
	var triggers: Array = []
	for i in range(3):
		var t := Area3D.new()
		level.add_child(t)
		triggers.append(t)
	level.doors.assign(doors)
	level.trigger_nodes.assign(triggers)
	var pool := Node3D.new()
	level.add_child(pool)
	var player := CharacterBody3D.new()
	level.add_child(player)
	_track(level)
	return {"level": level, "doors": doors, "triggers": triggers,
		"pool": pool, "player": player}


func test_boss_gate_starts_sealed() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	var doors: Array = r["doors"]
	assert_false(doors[0].closed, "room 1 door open at start")
	assert_false(doors[3].closed, "room 2 door open at start")
	assert_true(doors[4].closed, "boss gate sealed until the last room")
	_teardown()


func test_trigger_seals_doors_and_spawns() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	var started := [-1]
	d.room_started.connect(func(i: int): started[0] = i)
	d._on_trigger_body(r["player"], 0)
	assert_eq(d.phase, LevelDirector.Phase.FIGHTING, "room is live")
	assert_eq(started[0], 0, "room_started fired for room 0")
	assert_true(r["doors"][0].closed, "door behind the player slammed shut")
	assert_true(r["doors"][1].closed, "both doors of the room sealed")
	assert_gt(float(d.alive), 0.0, "wave spawned")
	assert_eq(float(d.alive), float(RoomPlan.composition(0, _base()).size()),
		"alive matches the wave table")
	_teardown()


func test_rooms_must_be_taken_in_order() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	d._on_trigger_body(r["player"], 2)
	assert_eq(d.phase, LevelDirector.Phase.IDLE, "skipping ahead does nothing")
	assert_eq(float(d.alive), 0.0, "no wave spawned out of order")
	_teardown()


func test_other_bodies_do_not_trigger() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	var intruder := CharacterBody3D.new()
	_track(intruder)
	d._on_trigger_body(intruder, 0)
	assert_eq(d.phase, LevelDirector.Phase.IDLE, "only the player arms a room")
	_teardown()


func test_clearing_opens_the_next_doors() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	d._on_trigger_body(r["player"], 0)
	var cleared := [-1]
	d.room_cleared.connect(func(i: int): cleared[0] = i)
	assert_false(r["doors"][2].closed, "next doors shut while fighting")
	for i in range(d.alive):
		d._on_enemy_died(Vector3.ZERO)
	assert_eq(cleared[0], 0, "room_cleared fired")
	assert_eq(float(d.alive), 0.0, "alive counter drained")
	assert_false(r["doors"][2].closed, "exit doors released")
	assert_eq(d.phase, LevelDirector.Phase.IDLE, "ready for the next room")
	_teardown()


func test_alive_never_goes_negative() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	d._on_trigger_body(r["player"], 0)
	for i in range(d.alive + 3):
		d._on_enemy_died(Vector3.ZERO)
	assert_ge(float(d.alive), 0.0, "stale death events cannot go negative")
	_teardown()


func test_full_run_ends_with_level_complete() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	var completed := [false]
	d.level_complete.connect(func(): completed[0] = true)
	for room in range(RoomPlan.room_count()):
		d._on_trigger_body(r["player"], room)
		assert_eq(d.phase, LevelDirector.Phase.FIGHTING, "room %d engaged" % room)
		for i in range(d.alive):
			d._on_enemy_died(Vector3.ZERO)
	assert_true(completed[0], "beating the boss room completes the level")
	assert_eq(d.phase, LevelDirector.Phase.FINISHED, "director finished")
	_teardown()


func test_no_wave_does_not_softlock() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	# A room with no enemies (pool missing) must still clear itself.
	d.setup(r["level"], null, r["player"])
	d._on_trigger_body(r["player"], 0)
	assert_eq(float(d.alive), 0.0, "nothing spawned")
	assert_ne(d.phase, LevelDirector.Phase.FIGHTING, "room resolves immediately")
	_teardown()


func test_out_of_range_start_is_ignored() -> void:
	var r := _rig()
	var d := LevelDirector.new()
	_track(d)
	d.setup(r["level"], r["pool"], r["player"])
	d.start_room(-1)
	d.start_room(99)
	assert_eq(d.phase, LevelDirector.Phase.IDLE, "bad indices are no-ops")
	_teardown()


func test_setup_without_level_is_safe() -> void:
	var d := LevelDirector.new()
	_track(d)
	d.setup(null, null, null)
	assert_eq(float(d._doors.size()), 0.0, "no doors collected")
	assert_eq(float(d._triggers.size()), 0.0, "no triggers collected")
	_teardown()


static func _base() -> int:
	if Cfg != null and "wave_base_count" in Cfg:
		return int(Cfg.wave_base_count)
	return 2
