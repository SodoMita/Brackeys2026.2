extends TestBase
## Tests for the trauma-based camera shake and its settings hookup.

var _owned: Array = []
var _saved_shake: Variant = null


func _keep(n: Node) -> Node:
	_owned.append(n)
	return n


func _teardown() -> void:
	# Restore the setting so no other suite inherits a muted screen_shake.
	if _saved_shake != null:
		Settings.current["screen_shake"] = _saved_shake
		_saved_shake = null
	for n in _owned:
		if n != null and is_instance_valid(n):
			n.free()
	_owned.clear()


func _force_intensity(value: float) -> void:
	if _saved_shake == null:
		_saved_shake = Settings.current.get("screen_shake", 1.0)
	Settings.current["screen_shake"] = value


func _rig() -> Dictionary:
	var cam := _keep(Camera3D.new())
	var shake := CameraShake.new()
	_keep(shake)
	shake.setup(cam)
	return {"cam": cam, "shake": shake}


func test_add_accumulates_trauma() -> void:
	_force_intensity(1.0)
	var r := _rig()
	assert_near(r["shake"].trauma, 0.0, 0.001, "starts calm")
	r["shake"].add(0.3)
	assert_gt(r["shake"].trauma, 0.0, "a hit registers")
	r["shake"].add(0.4)
	assert_near(r["shake"].trauma, 0.7, 0.001, "trauma accumulates")
	_teardown()


func test_trauma_is_clamped() -> void:
	_force_intensity(1.0)
	var r := _rig()
	for _i in range(50):
		r["shake"].add(1.0)
	assert_le(r["shake"].trauma, 1.0 + 0.001, "cannot exceed full shake")
	_teardown()


func test_negative_kick_is_ignored() -> void:
	_force_intensity(1.0)
	var r := _rig()
	r["shake"].add(0.5)
	r["shake"].add(-5.0)
	assert_near(r["shake"].trauma, 0.5, 0.001, "a negative amount cannot calm it")
	_teardown()


func test_disabled_setting_blocks_shake() -> void:
	_force_intensity(0.0)
	assert_false(CameraShake.enabled(), "screen_shake 0 means off")
	var r := _rig()
	r["shake"].add(1.0)
	assert_near(r["shake"].trauma, 0.0, 0.001, "and no trauma is stored")
	_teardown()


func test_intensity_is_normalised() -> void:
	_force_intensity(0.5)
	assert_near(CameraShake.intensity(), 0.5, 0.001, "reads the setting")
	assert_true(CameraShake.enabled(), "non-zero intensity is on")
	_teardown()


func test_apply_moves_the_camera() -> void:
	_force_intensity(1.0)
	var r := _rig()
	r["shake"].trauma = 1.0
	r["shake"]._apply()
	assert_gt((r["cam"] as Camera3D).position.length(), 0.0, "camera is displaced")
	_teardown()


func test_zero_intensity_leaves_camera_still() -> void:
	_force_intensity(0.0)
	var r := _rig()
	r["shake"].trauma = 1.0
	r["shake"]._apply()
	assert_near((r["cam"] as Camera3D).position.length(), 0.0, 0.001,
		"shake off means the view does not move")
	_teardown()


func test_trauma_decays_to_rest() -> void:
	_force_intensity(1.0)
	var r := _rig()
	r["shake"].trauma = 0.8
	for _i in range(200):
		r["shake"]._process(0.016)
	assert_near(r["shake"].trauma, 0.0, 0.001, "trauma fully decays")
	assert_eq((r["cam"] as Camera3D).position, Vector3.ZERO, "camera snaps back to rest")
	_teardown()


func test_reset_clears_immediately() -> void:
	_force_intensity(1.0)
	var r := _rig()
	r["shake"].trauma = 1.0
	r["shake"]._apply()
	r["shake"].reset()
	assert_near(r["shake"].trauma, 0.0, 0.001, "trauma cleared")
	assert_eq((r["cam"] as Camera3D).position, Vector3.ZERO, "camera centred")
	assert_eq((r["cam"] as Camera3D).rotation, Vector3.ZERO, "roll cleared")
	_teardown()


func test_no_camera_is_safe() -> void:
	_force_intensity(1.0)
	var shake := _keep(CameraShake.new())
	shake.add(1.0)
	shake._process(0.016)
	shake._apply()
	shake.reset()  # must not dereference a null camera
	_teardown()
