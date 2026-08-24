class_name Settings
extends RefCounted
## Persistent player-facing options. Platform-specific settings are intentionally excluded.

const KEYS := [
	"mouse_sensitivity", "stick_look_speed", "stick_deadzone", "invert_look",
	"master_volume", "dialogue_volume", "typing_volume", "fullscreen", "borderless",
	"resolution", "vsync", "aa_mode", "render_scale", "screen_shake", "text_speed",
	"controller_vibration", "subtitles"
]
const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "slide": [KEY_CTRL, KEY_C],
	"parry": [KEY_F, KEY_V], "fire": [MOUSE_BUTTON_LEFT], "coin": [MOUSE_BUTTON_RIGHT],
	"weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3], "interact": [KEY_E]
}
static var path := "user://settings.cfg"
static var current: Dictionary = {}
static var _defaults: Dictionary = {}

static func capture_defaults() -> Dictionary:
	if _defaults.is_empty():
		_defaults = {
			"mouse_sensitivity": Cfg.mouse_sensitivity, "stick_look_speed": Cfg.stick_look_speed,
			"stick_deadzone": 0.18, "invert_look": Cfg.invert_look, "master_volume": 1.0,
			"dialogue_volume": 1.0, "typing_volume": 0.8, "fullscreen": false, "borderless": false,
			"resolution": Vector2i(1280, 720), "vsync": 1, "aa_mode": 2, "render_scale": 1.0,
			"screen_shake": 1.0, "text_speed": 0.01, "controller_vibration": true, "subtitles": true
		}
	return _defaults

static func default_value(key: String) -> Variant:
	return capture_defaults().get(key)

static func _ensure_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
			for key in ACTIONS[action]:
				var ev := InputEventKey.new()
				ev.keycode = key
				InputMap.action_add_event(action, ev)

static func load_config() -> Dictionary:
	capture_defaults()
	_ensure_actions()
	var out := _defaults.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		for key in KEYS: out[key] = cf.get_value("settings", key, out[key])
	return out

static func apply(values: Dictionary) -> void:
	capture_defaults()
	_ensure_actions()
	current = _defaults.duplicate()
	for key in KEYS: current[key] = values.get(key, current[key])
	Cfg.mouse_sensitivity = clampf(float(current.mouse_sensitivity), 0.0001, 0.05)
	Cfg.stick_look_speed = clampf(float(current.stick_look_speed), 0.1, 10.0)
	Cfg.invert_look = bool(current.invert_look)
	ProjectSettings.set_setting("dialogic/text/letter_speed", clampf(float(current.text_speed), 0.001, 0.2))
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		var vol := clampf(float(current.master_volume), 0.0, 1.0)
		AudioServer.set_bus_mute(master, vol <= 0.001)
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(vol, 0.001)))
	var type_bus := AudioServer.get_bus_index("Dialogic")
	if type_bus >= 0: AudioServer.set_bus_volume_db(type_bus, linear_to_db(maxf(float(current.typing_volume), 0.001)))
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(current.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(current.borderless))
		DisplayServer.window_set_size(current.resolution)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if int(current.vsync) else DisplayServer.VSYNC_DISABLED)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var aa := clampi(int(current.aa_mode), 0, 3)
		tree.root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][aa]
		tree.root.scaling_3d_scale = clampf(float(current.render_scale), 0.5, 1.5)

static func apply_saved() -> void:
	apply(load_config())

static func save(values: Dictionary) -> void:
	apply(values)
	var cf := ConfigFile.new()
	for key in KEYS: cf.set_value("settings", key, current[key])
	cf.save(path)

static func reset_defaults() -> void:
	apply(capture_defaults())
	save(current)

static func rebind(action: String, event: InputEvent) -> void:
	_ensure_actions()
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

static func binding_text(action: String) -> String:
	_ensure_actions()
	var events := InputMap.action_get_events(action)
	return events[0].as_text() if not events.is_empty() else "Unbound"
