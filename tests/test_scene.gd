extends TestBase
## Integration tests: Main Menu scene, Game scene, Pause Menu, Mobile Pause button, Dialogic input.


func _boot_game() -> Node3D:
	var scene: Node3D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	scene._ready()
	return scene


func test_main_menu_scene() -> void:
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	assert_true(menu != null, "main menu scene instantiates")
	assert_true(menu.btn_start != null, "has start button")
	assert_true(menu.btn_settings != null, "has settings button")
	assert_true(menu.main_panel.visible, "main panel visible on boot")
	assert_false(menu.settings_panel.visible, "settings panel hidden on boot")

	menu.open_settings()
	assert_true(menu.settings_open, "settings_open is true")
	assert_true(menu.settings_panel.visible, "settings panel becomes visible")
	assert_false(menu.main_panel.visible, "main panel hidden while settings open")

	menu.close_settings()
	assert_false(menu.settings_open, "settings_open is false")
	assert_false(menu.settings_panel.visible, "settings panel hidden")
	assert_true(menu.main_panel.visible, "main panel restored")

	menu.free()


func test_game_scene_boots_directly_into_play() -> void:
	var scene := _boot_game()
	assert_true(scene.player != null, "player spawned")
	assert_true(scene.player.cam != null, "camera built")
	assert_eq(scene.state, scene.State.PLAYING, "boots directly into playing state")
	assert_true(scene.companion != null, "COLT spawned")
	assert_eq(scene.doors.size(), 5.0, "five doors")
	assert_eq(scene.terminals.size(), 2.0, "two shop terminals")
	assert_true(scene.hud_hp != null, "HUD built")
	assert_true(scene.hud_rank != null, "style rank HUD built")
	assert_gt(float(scene.alive), 0.0, "first wave spawned on boot")
	assert_false(scene.menus.visible, "pause menu hidden during play")
	scene.free()


func test_pause_resume_cycle() -> void:
	var scene: Node3D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	runner.root.add_child(scene)
	assert_eq(scene.state, scene.State.PLAYING, "game playing")

	scene._pause()
	assert_eq(scene.state, scene.State.PAUSED, "pause state")
	assert_true(scene.get_tree().paused, "tree paused under the pause menu")
	assert_true(scene.menus.pause_panel.visible, "pause panel shown")

	scene.menus.btn_resume.pressed.emit()
	assert_eq(scene.state, scene.State.PLAYING, "resume returns to playing")
	assert_false(scene.get_tree().paused, "tree unpaused on resume")
	assert_false(scene.menus.visible, "menus hidden after resume")
	scene.free()


func test_mobile_pause_button() -> void:
	var scene: Node3D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	runner.root.add_child(scene)
	assert_true(scene.touch_ui != null, "touch controls built")

	# Mobile pause button triggers pause
	scene.touch_ui.trigger_button("pause", true)
	assert_eq(scene.state, scene.State.PAUSED, "mobile pause button pauses the game")
	assert_true(scene.get_tree().paused, "tree paused via mobile button")
	assert_true(scene.menus.pause_panel.visible, "pause panel opened via mobile button")

	scene._resume()
	assert_eq(scene.state, scene.State.PLAYING, "game resumed")
	assert_false(scene.get_tree().paused, "tree unpaused")
	scene.free()


func test_dialogic_input_action_registered() -> void:
	assert_true(InputMap.has_action("dialogic_default_action"), "dialogic_default_action exists in InputMap")


func test_wave_scaling() -> void:
	var scene := _boot_game()
	var before: int = scene.alive
	scene._enter_room(1)
	assert_eq(scene.room, 1)
	assert_gt(float(scene.alive), float(before), "room 2 adds more hostiles")
	scene.free()


func test_audio_synthesis() -> void:
	var scene := _boot_game()
	var wav: AudioStreamWAV = scene._tone(440.0, 0.1, 0.5)
	assert_true(wav != null, "tone generator returns a stream")
	assert_eq(wav.data.size(), int(0.1 * 22050.0) * 2, "16-bit PCM length")
	scene.free()


func test_input_sources_do_not_crash_headless() -> void:
	var scene := _boot_game()
	scene._process(0.016)
	scene.free()


func test_invert_look_flips_pitch() -> void:
	var scene := _boot_game()
	var old := Cfg.invert_look
	Cfg.invert_look = false
	scene.player._apply_look(0.0, 0.5)
	assert_near(scene.player.pitch, 0.5, 0.001, "look pitch normally adds")
	Cfg.invert_look = true
	scene.player._apply_look(0.0, 0.5)
	assert_near(scene.player.pitch, 0.0, 0.001, "inverted look flips pitch")
	Cfg.invert_look = old
	scene.free()
