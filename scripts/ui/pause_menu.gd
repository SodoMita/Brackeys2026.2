class_name PauseMenu
extends CanvasLayer
## Procedural pause menu (same UIKit look as the main menu).
## Lives on UILayers.PAUSE — above Dialogic and the touch controls — and
## keeps processing while the tree is paused. It only emits intents;
## UIManager owns the actual state switching and get_tree().paused.

signal resume_requested
signal quit_to_menu_requested

var _root: Control
var _menu_box: Control
var _settings: SettingsPanel
var btn_resume: Button


func _init() -> void:
	layer = UILayers.PAUSE
	# The menu must run while the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Full-screen dim that also swallows clicks aimed at whatever is below.
	_root.add_child(UIKit.fullrect_dim())

	_menu_box = VBoxContainer.new()
	UIKit.centered(_menu_box)
	_menu_box.add_theme_constant_override("separation", 3)
	_root.add_child(_menu_box)

	_menu_box.add_child(UIKit.label("PAUSED", 24, Color(1.0, 0.72, 0.35)))
	_menu_box.add_child(UIKit.gap())

	btn_resume = UIKit.button("RESUME")
	btn_resume.pressed.connect(func(): resume_requested.emit())
	_menu_box.add_child(btn_resume)

	var btn_settings := UIKit.button("SETTINGS")
	btn_settings.pressed.connect(_open_settings)
	_menu_box.add_child(btn_settings)

	var btn_menu := UIKit.button("QUIT TO MENU")
	btn_menu.pressed.connect(func(): quit_to_menu_requested.emit())
	_menu_box.add_child(btn_menu)

	var btn_quit := UIKit.button("QUIT GAME")
	btn_quit.visible = not OS.has_feature("web")
	btn_quit.pressed.connect(func(): get_tree().quit())
	_menu_box.add_child(btn_quit)

	_settings = SettingsPanel.new()
	_settings.closed.connect(_on_settings_closed)
	_root.add_child(_settings)


func open() -> void:
	visible = true
	_settings.visible = false
	_menu_box.visible = true
	if is_inside_tree():
		btn_resume.grab_focus()


func close() -> void:
	if _settings.visible:
		_settings.close()  # persists pending changes
	visible = false


func _open_settings() -> void:
	_menu_box.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_menu_box.visible = true
	if is_inside_tree():
		btn_resume.grab_focus()


func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	# SettingsPanel handles its own ESC/B-button (and key rebinding grabs).
	if _settings.visible:
		return
	var esc: bool = ev is InputEventKey and ev.pressed and not ev.echo \
			and ev.keycode == KEY_ESCAPE
	var joy: InputEventJoypadButton = ev as InputEventJoypadButton
	var joy_back: bool = joy != null and joy.pressed \
			and joy.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]
	if esc or joy_back:
		resume_requested.emit()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
