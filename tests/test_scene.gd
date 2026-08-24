extends TestBase
## Integration tests: instantiate the FPS root scene headless.


func _boot() -> Node3D:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	scene._ready()
	return scene


func test_scene_boots_into_menu() -> void:
	var scene := _boot()
	assert_true(scene.player != null, "player spawned")
	assert_true(scene.player.cam != null, "camera built")
	assert_eq(scene.state, scene.State.MENU, "boots into menu")
	assert_true(scene.companion != null, "COLT spawned")
	assert_eq(scene.doors.size(), 5, "five doors")
	assert_eq(scene.terminals.size(), 2, "two shop terminals")
	assert_true(scene.hud_hp != null, "HUD built")
	assert_true(scene.hud_rank != null, "style rank HUD built")
	scene.free()


func test_start_spawns_first_wave() -> void:
	var scene := _boot()
	scene._start()
	assert_eq(scene.wave_in_room, 0, "first wave index")
	assert_eq(scene.room, 0, "room 0")
	assert_gt(float(scene.enemies.get_child_count()), 0.0, "room 1 wave 1 spawned")
	assert_eq(float(scene.alive), float(scene.enemies.get_child_count()), "alive counter synced")
	assert_eq(scene.state, scene.State.PLAYING)
	scene.free()


func test_wave_scaling() -> void:
	var scene := _boot()
	scene._start()
	var before: int = scene.alive
	scene._enter_room(1)
	assert_eq(scene.room, 1)
	assert_gt(float(scene.alive), float(before), "room 2 adds more hostiles")
	scene.free()


func test_audio_synthesis() -> void:
	var scene := _boot()
	var wav: AudioStreamWAV = scene._tone(440.0, 0.1, 0.5)
	assert_true(wav != null, "tone generator returns a stream")
	assert_eq(wav.data.size(), int(0.1 * 22050.0) * 2, "16-bit PCM length")
	scene.free()


func test_input_sources_do_not_crash_headless() -> void:
	var scene := _boot()
	scene._start()
	scene._process(0.016)
	scene.free()


func test_shop_and_kill_and_parry_safe() -> void:
	var scene := _boot()
	scene._start()
	# shop
	scene.scrap = 100
	var max_before: float = float(Cfg.max_hp)
	scene._on_purchase(1)
	assert_gt(float(Cfg.max_hp), max_before, "plating")
	Cfg.max_hp = max_before
	# kill one enemy
	if scene.enemies.get_child_count() > 0:
		var e: Node3D = scene.enemies.get_child(0)
		var scrap0 := scene.scrap
		e.take_damage(9999.0, Vector3.FORWARD, 0.0)
		assert_gt(float(scene.scrap), float(scrap0), "scrap on kill")
	# parry path
	scene.player.request_parry()
	scene._on_attacked(null)
	# volley
	scene._on_volley(Vector3(0, 0, -1), Vector3.ZERO)
	assert_gt(float(scene.projectiles.size()), 0.0, "projectiles")
	# betrayal
	scene._betrayal()
	assert_eq(scene.state, scene.State.BOSS)
	scene.free()


func test_door_set_safe() -> void:
	var scene := _boot()
	for d in scene.doors:
		scene.door_set(d, true)
		scene.door_set(d, false)
	scene.free()


func test_wave_clear_schedules_next() -> void:
	var scene := _boot()
	scene._start()
	assert_eq(scene.wave_in_room, 0)
	var foes: Array = scene.enemies.get_children()
	for e in foes:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999.0, Vector3.FORWARD, 0.0)
	assert_eq(scene.alive, 0)
	assert_gt(scene.wave_delay, 0.0)
	assert_eq(scene.wave_in_room, 1)
	scene.wave_delay = 0.001
	scene._process(0.02)
	assert_gt(float(scene.alive), 0.0)
	scene.free()


func test_style_decay() -> void:
	var scene := _boot()
	scene._start()
	scene.style = 100.0
	var before := scene.style
	scene._process(1.0)
	assert_lt(scene.style, before)
	assert_ge(scene.style, 0.0)
	scene.free()


func test_double_start_and_bad_room() -> void:
	var scene := _boot()
	scene._start()
	var n := scene.alive
	scene._start()
	assert_eq(scene.alive, n)
	scene._enter_room(-1)
	assert_eq(scene.room, 0)
	scene._enter_room(99)
	assert_eq(scene.room, 0)
	scene.free()


func test_player_death_overlay() -> void:
	var scene := _boot()
	scene._start()
	scene.player.take_damage(9999.0)
	assert_eq(scene.state, scene.State.DEAD)
	assert_true(scene.overlay.visible)
	scene.free()


func test_end_mission_overlay() -> void:
	var scene := _boot()
	scene._start()
	scene._end_mission()
	assert_eq(scene.state, scene.State.END)
	assert_true(scene.overlay.visible)
	scene.free()


func test_fired_null_safe_and_heal() -> void:
	var scene := _boot()
	scene._start()
	scene._on_fired(null, false, false, 10.0, false)
	if scene.enemies.get_child_count() > 0:
		var e: Node3D = scene.enemies.get_child(0)
		scene.player.hp = 40.0
		var hp0: float = float(scene.player.hp)
		scene._on_fired(e, true, false, 20.0, false)
		assert_gt(float(scene.player.hp), hp0)
	scene.free()


func test_composition_matches_spawn() -> void:
	var scene := _boot()
	scene._start()
	var w := CombatLogic.wave_composition(0, 0)
	assert_eq(scene.alive, int(w.hounds) + int(w.spitters))
	scene.free()


func test_game_constants() -> void:
	var scene := _boot()
	assert_eq(scene.ROOMS.size(), 3)
	assert_eq(scene.DOOR_Z.size(), 5)
	assert_eq(scene.ROOM_WAVES[0] + scene.ROOM_WAVES[1] + scene.ROOM_WAVES[2], 7)
	scene.free()
