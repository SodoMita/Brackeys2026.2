class_name Settings
extends RefCounted
## Player-facing settings (main menu → SETTINGS): mouse sensitivity, stick
## look speed, invert look, master volume, fullscreen.
##
## Designer defaults are captured from the Cfg autoload's exported values on
## first use; user overrides persist to user://settings.cfg and are re-applied
## on boot. Everything applies live — no restart needed.

const KEYS := ["mouse_sensitivity", "stick_look_speed", "invert_look", "master_volume", "fullscreen"]

## Test hook — swap for an isolated file, restore after.
static var path := "user://settings.cfg"

static var current: Dictionary = {}

static var _defaults: Dictionary = {}


## Capture (once) the designed defaults from Cfg. Returns the defaults dict.
static func capture_defaults() -> Dictionary:
	if _defaults.is_empty():
		_defaults = {
			"mouse_sensitivity": Cfg.mouse_sensitivity,
			"stick_look_speed": Cfg.stick_look_speed,
			"invert_look": Cfg.invert_look,
			"master_volume": 1.0,
			"fullscreen": false,
		}
	return _defaults


static func default_value(key: String) -> Variant:
	return capture_defaults().get(key)


## Read the persisted overrides (falls back to defaults per key).
static func load_config() -> Dictionary:
	capture_defaults()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return _defaults.duplicate()
	var out := {}
	for key in KEYS:
		out[key] = cf.get_value("settings", key, _defaults.get(key))
	return out


## Apply values to Cfg / AudioServer / DisplayServer. Missing keys fall back
## to the captured defaults; floats are coerced and clamped.
static func apply(values: Dictionary) -> void:
	capture_defaults()
	Cfg.mouse_sensitivity = clampf(float(values.get("mouse_sensitivity", _defaults["mouse_sensitivity"])), 0.0001, 0.05)
	Cfg.stick_look_speed = clampf(float(values.get("stick_look_speed", _defaults["stick_look_speed"])), 0.1, 10.0)
	Cfg.invert_look = bool(values.get("invert_look", false))
	current = {
		"mouse_sensitivity": Cfg.mouse_sensitivity,
		"stick_look_speed": Cfg.stick_look_speed,
		"invert_look": Cfg.invert_look,
		"master_volume": clampf(float(values.get("master_volume", 1.0)), 0.0, 1.0),
		"fullscreen": bool(values.get("fullscreen", false)),
	}
	var vol := float(current["master_volume"])
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, vol <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(vol, 0.001, 1.0)))
	# Window mode changes are desktop-only (no-op on headless CI / web).
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		var want_full := bool(current["fullscreen"])
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


## Load the persisted file (if any) and apply it.
static func apply_saved() -> void:
	apply(load_config())


## Persist the given values (missing keys are filled from the defaults).
static func save(values: Dictionary) -> void:
	capture_defaults()
	var cf := ConfigFile.new()
	for key in KEYS:
		cf.set_value("settings", key, values.get(key, _defaults.get(key)))
	cf.save(path)


## Convenience: persist whatever was last applied (Settings.current).
static func save_current() -> void:
	save(current if not current.is_empty() else load_config())


## Reset to the designer defaults and persist them.
static func reset_defaults() -> void:
	var d := capture_defaults().duplicate()
	apply(d)
	save(d)
