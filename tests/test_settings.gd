extends TestBase
## Unit tests for the settings backend (persistence + live application).

const TMP := "user://__test_settings.cfg"


func test_missing_file_returns_defaults() -> void:
	var old := Settings.path
	Settings.path = TMP
	var loaded := Settings.load_config()
	var defaults := Settings.capture_defaults()
	for key in ["mouse_sensitivity", "stick_look_speed", "invert_look", "master_volume", "fullscreen"]:
		assert_eq(loaded.get(key), defaults.get(key), "missing file falls back to default (%s)" % key)
	Settings.path = old


func test_save_roundtrip() -> void:
	var old := Settings.path
	Settings.path = TMP
	Settings.save({
		"mouse_sensitivity": 0.004,
		"stick_look_speed": 3.3,
		"invert_look": true,
		"master_volume": 0.4,
		"fullscreen": true,
	})
	var loaded := Settings.load_config()
	assert_near(float(loaded["mouse_sensitivity"]), 0.004, 0.00001, "mouse sensitivity round-trips")
	assert_near(float(loaded["stick_look_speed"]), 3.3, 0.001, "stick speed round-trips")
	assert_true(bool(loaded["invert_look"]), "invert look round-trips")
	assert_near(float(loaded["master_volume"]), 0.4, 0.001, "volume round-trips")
	assert_true(bool(loaded["fullscreen"]), "fullscreen round-trips")
	var d := DirAccess.open("user://")
	if d and d.file_exists("__test_settings.cfg"):
		d.remove("__test_settings.cfg")
	Settings.path = old


func test_partial_save_fills_defaults() -> void:
	var old := Settings.path
	Settings.path = TMP
	Settings.save({"invert_look": true})
	var loaded := Settings.load_config()
	var defaults := Settings.capture_defaults()
	assert_true(bool(loaded["invert_look"]), "saved key kept")
	assert_eq(loaded.get("master_volume"), defaults.get("master_volume"), "unsaved key uses default")
	var d := DirAccess.open("user://")
	if d and d.file_exists("__test_settings.cfg"):
		d.remove("__test_settings.cfg")
	Settings.path = old


func test_apply_updates_cfg_and_audio() -> void:
	Settings.apply({
		"mouse_sensitivity": 0.005,
		"stick_look_speed": 4.0,
		"invert_look": true,
		"master_volume": 0.0,
		"fullscreen": false,
	})
	assert_near(Cfg.mouse_sensitivity, 0.005, 0.00001, "sensitivity applied live")
	assert_near(Cfg.stick_look_speed, 4.0, 0.001, "stick speed applied live")
	assert_true(Cfg.invert_look, "invert applied live")
	assert_true(AudioServer.is_bus_mute(0), "volume 0 mutes the master bus")
	Settings.apply({"mouse_sensitivity": 0.003, "invert_look": false, "master_volume": 2.0})
	assert_false(Cfg.invert_look, "invert cleared")
	assert_near(AudioServer.get_bus_volume_db(0), 0.0, 0.01, "volume clamps at 0 dB (100%)")
	assert_false(AudioServer.is_bus_mute(0), "unmuted above zero")
	Settings.apply(Settings.capture_defaults().duplicate())


func test_reset_defaults() -> void:
	var old := Settings.path
	Settings.path = TMP
	Settings.apply({"mouse_sensitivity": 0.001, "invert_look": true, "master_volume": 0.25,
		"stick_look_speed": 1.0, "fullscreen": false})
	Settings.reset_defaults()
	var defaults := Settings.capture_defaults()
	assert_near(Cfg.mouse_sensitivity, float(defaults["mouse_sensitivity"]), 0.00001, "reset restores sensitivity")
	assert_false(Cfg.invert_look, "reset restores invert")
	assert_near(float(Settings.current["master_volume"]), 1.0, 0.001, "reset restores volume")
	var d := DirAccess.open("user://")
	if d and d.file_exists("__test_settings.cfg"):
		d.remove("__test_settings.cfg")
	Settings.path = old
