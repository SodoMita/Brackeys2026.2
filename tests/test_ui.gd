extends TestBase
## UI system tests: layer ordering contract, UIManager state machine,
## touch-control gating, pause menu intents. All headless-safe (nodes are
## exercised outside the tree; tree-dependent effects are guarded).


func test_layer_stack_ordering() -> void:
	# The whole point of UILayers: pause > dialog > touch > hud.
	assert_gt(float(UILayers.PAUSE), float(UILayers.DIALOG), "pause above dialogue")
	assert_gt(float(UILayers.DIALOG), float(UILayers.TOUCH), "dialogue above touch")
	assert_gt(float(UILayers.TOUCH), float(UILayers.HUD), "touch above hud")


func test_touch_controls_layer_and_gating() -> void:
	var tc := TouchControls.new()
	assert_eq(tc.layer, UILayers.TOUCH, "touch layer from UILayers")
	var p: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	tc.setup(p)
	assert_true(tc._buttons.size() > 0, "action buttons built")
	# simulate held inputs, then deactivate: everything must release
	p.touch_fire = true
	p.touch_move = Vector2(1, 0)
	p.touch_jump = true
	tc.set_active(false)
	assert_false(tc.visible, "hidden outside gameplay")
	assert_false(p.touch_fire, "fire released on deactivate")
	assert_eq(p.touch_move, Vector2.ZERO, "stick zeroed on deactivate")
	assert_false(p.touch_jump, "jump released on deactivate")
	tc.set_active(true)
	assert_true(tc.visible, "visible again in gameplay")
	tc.free()
	p.free()


func test_touch_button_single_touch_ownership() -> void:
	var b := TouchControls.TouchButton.new("FIRE", Vector2(110, 110))
	var downs := [0]
	var ups := [0]
	b.button_down.connect(func(): downs[0] += 1)
	b.button_up.connect(func(): ups[0] += 1)
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	b._gui_input(t0)
	assert_eq(downs[0], 1, "first finger presses")
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	b._gui_input(t1)
	assert_eq(downs[0], 1, "second finger ignored while held")
	var r1 := InputEventScreenTouch.new()
	r1.index = 1
	r1.pressed = false
	b._gui_input(r1)
	assert_eq(ups[0], 0, "unrelated finger release does not release button")
	var r0 := InputEventScreenTouch.new()
	r0.index = 0
	r0.pressed = false
	b._gui_input(r0)
	assert_eq(ups[0], 1, "owning finger releases")
	b.free()


func test_ui_manager_pause_state_machine() -> void:
	var ui := UIManager.new()
	var p: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	ui.setup(p)
	assert_eq(ui.state, UIManager.State.GAMEPLAY, "starts in gameplay")
	assert_false(p.disabled, "player enabled in gameplay")
	ui.pause()
	assert_eq(ui.state, UIManager.State.PAUSED, "pause() -> PAUSED")
	assert_true(p.disabled, "player disabled while paused")
	assert_true(ui.pause_menu.visible, "pause menu shown")
	ui.pause()
	assert_eq(ui.state, UIManager.State.PAUSED, "pause() idempotent")
	ui.resume()
	assert_eq(ui.state, UIManager.State.GAMEPLAY, "resume() -> back to gameplay")
	assert_false(p.disabled, "player re-enabled")
	assert_false(ui.pause_menu.visible, "pause menu hidden")
	ui.free()
	p.free()


func test_ui_manager_dialog_state() -> void:
	var ui := UIManager.new()
	var p: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	ui.setup(p)
	ui._on_timeline_started()
	assert_eq(ui.state, UIManager.State.DIALOG, "timeline start -> DIALOG")
	assert_true(p.disabled, "player ignores input during dialogue")
	# pausing over a dialogue and resuming must land back in DIALOG
	ui.pause()
	assert_eq(ui.state, UIManager.State.PAUSED, "pause over dialogue works")
	ui.resume()
	assert_eq(ui.state, UIManager.State.DIALOG, "resume returns to dialogue")
	ui._on_timeline_ended()
	assert_eq(ui.state, UIManager.State.GAMEPLAY, "timeline end -> gameplay")
	assert_false(p.disabled, "player back after dialogue")
	ui.free()
	p.free()


func test_dialog_ending_while_paused() -> void:
	var ui := UIManager.new()
	var p: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	ui.setup(p)
	ui._on_timeline_started()
	ui.pause()
	ui._on_timeline_ended()
	assert_eq(ui.state, UIManager.State.PAUSED, "stays paused when dialogue ends")
	ui.resume()
	assert_eq(ui.state, UIManager.State.GAMEPLAY, "resume goes to gameplay, not dead dialogue")
	ui.free()
	p.free()


func test_pause_menu_emits_intents() -> void:
	var pm := PauseMenu.new()
	assert_eq(pm.layer, UILayers.PAUSE, "pause menu on pause layer")
	var got := [false]
	pm.resume_requested.connect(func(): got[0] = true)
	pm.open()
	assert_true(pm.visible, "open() shows menu")
	pm.btn_resume.pressed.emit()
	assert_true(got[0], "resume button emits intent (manager decides)")
	pm.close()
	assert_false(pm.visible, "close() hides menu")
	pm.free()


func test_settings_panel_standalone() -> void:
	Settings.apply_saved()
	var sp := SettingsPanel.new()
	assert_false(sp.visible, "settings hidden by default")
	var closed := [false]
	sp.closed.connect(func(): closed[0] = true)
	sp.open()
	assert_true(sp.visible, "open() shows panel")
	sp.close()
	assert_false(sp.visible, "close() hides panel")
	assert_true(closed[0], "close() notifies host")
	sp.free()
