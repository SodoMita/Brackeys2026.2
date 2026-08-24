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
