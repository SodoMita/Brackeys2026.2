extends Control
## STEEL KNIFE — Standalone Main Menu Scene.
##
## Procedural on purpose (small, code-reviewable, no scene merge conflicts).
## Widgets/styles come from UIKit; the settings screen is the shared
## SettingsPanel component — the pause menu shows the exact same panel.

const GAME_SCENE := "res://scenes/game.tscn"

var main_panel: Control
var settings: SettingsPanel

var btn_start: Button
var btn_settings: Button
var btn_quit: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _ready() -> void:
	Settings.apply_saved()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if DisplayServer.is_touchscreen_available():
		Input.set_emulate_mouse_from_touch(true)
	if is_inside_tree() and btn_start:
		btn_start.grab_focus()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_main_panel()

	settings = SettingsPanel.new()
	settings.closed.connect(_on_settings_closed)
	add_child(settings)


func _build_main_panel() -> void:
	main_panel = Control.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_panel)

	var box := VBoxContainer.new()
	UIKit.centered(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	main_panel.add_child(box)

	box.add_child(UIKit.label("STEEL KNIFE", 24, Color(1.0, 0.72, 0.35)))
	box.add_child(UIKit.label("mission 1: clear the site with COLT", 8, UIKit.MUTED))
	box.add_child(UIKit.gap())

	btn_start = UIKit.button("START")
	btn_start.pressed.connect(start_game)
	box.add_child(btn_start)

	btn_settings = UIKit.button("SETTINGS")
	btn_settings.pressed.connect(open_settings)
	box.add_child(btn_settings)

	btn_quit = UIKit.button("QUIT GAME")
	btn_quit.visible = not OS.has_feature("web")
	btn_quit.pressed.connect(func(): get_tree().quit())
	box.add_child(btn_quit)

	box.add_child(UIKit.gap())

	var hints := UIKit.label(
		"WASD move · SPACE jump · SHIFT dash · CTRL slide · ESC pause\n" +
		"LMB fire · RMB coin · F parry · E shop · 1/2/3 weapons\n" +
		"blood heals · parry the white eyes · shoot the coin", 7, UIKit.MUTED)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.custom_minimum_size = Vector2(300, 0)
	box.add_child(hints)


func open_settings() -> void:
	main_panel.visible = false
	settings.open()


func close_settings() -> void:
	settings.close()  # emits closed -> _on_settings_closed


func _on_settings_closed() -> void:
	main_panel.visible = true
	if is_inside_tree() and btn_start:
		btn_start.grab_focus()


func start_game() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(GAME_SCENE)


func _unhandled_input(ev: InputEvent) -> void:
	# SettingsPanel consumes its own input (ESC, rebinding) before us.
	if settings != null and (settings.visible or settings.is_binding()):
		return
	if _is_start_trigger(ev):
		start_game()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _is_start_trigger(ev: InputEvent) -> bool:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			return true
	if ev is InputEventJoypadButton and ev.pressed:
		if ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			return true
	if ev is InputEventMouseButton and ev.pressed:
		return true
	if ev is InputEventScreenTouch and ev.pressed and not Input.is_emulating_mouse_from_touch():
		return true
	return false
