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
	assert_eq(scene.doors.size(), 5.0, "five doors")
	assert_eq(scene.terminals.size(), 2.0, "two shop terminals")
	assert_true(scene.hud_hp != null, "HUD built")
	assert_true(scene.hud_rank != null, "style rank HUD built")
	scene.free()


func test_start_spawns_first_wave() -> void:
	var scene := _boot()
	scene._start()
	assert_eq(scene.wave, 1, "wave counter")
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
	# Touch/gamepad paths are guarded for headless; make sure boot + start work.
	var scene := _boot()
	scene._start()
	scene._process(0.016)
	scene.free()
