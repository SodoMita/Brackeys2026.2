extends Control
## STEEL KNIFE — Standalone Main Menu Scene.
##
## Loads the game (res://scenes/game.tscn), provides in-menu settings adjustment,
## and handles mouse, keyboard, gamepad, and touchscreen navigation.

const ACCENT := Color(1.0, 0.62, 0.2)
const CYAN := Color(0.4, 0.95, 1.0)
const PAPER := Color(0.92, 0.86, 0.85)
const MUTED := Color(0.66, 0.56, 0.56)
const DIM := Color(0.05, 0.03, 0.01, 0.88)
const GAME_SCENE := "res://scenes/game.tscn"

var main_panel: Control
var settings_panel: Control
var settings_open := false

var btn_start: Button
var btn_settings: Button
var btn_quit: Button
var btn_back: Button
var btn_reset: Button

var _sens: HSlider
var _stick: HSlider
var _volume: HSlider
var _invert: Button
var _fullscreen: Button
var _sens_lbl: Label
var _stick_lbl: Label
var _vol_lbl: Label
var _arming := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _ready() -> void:
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
	_build_settings_panel()


static func _label(text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb


static func _button(text: String, width := 128) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 18)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _stylebox(Color(0.07, 0.01, 0.02, 0.9), Color(0.5, 0.08, 0.12)))
	b.add_theme_stylebox_override("hover", _stylebox(Color(0.17, 0.03, 0.05, 0.95), ACCENT))
	b.add_theme_stylebox_override("pressed", _stylebox(Color(0.05, 0.01, 0.01, 0.95), CYAN))
	b.add_theme_stylebox_override("focus", _stylebox(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.85)))
	return b


func _centered(container: Control) -> void:
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH


func _build_main_panel() -> void:
	main_panel = Control.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_panel)

	var box := VBoxContainer.new()
	_centered(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	main_panel.add_child(box)

	box.add_child(_label("STEEL KNIFE", 24, Color(1.0, 0.72, 0.35)))
	box.add_child(_label("mission 1: clear the site with COLT", 8, MUTED))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)

	btn_start = _button("START")
	btn_start.pressed.connect(_on_start_pressed)
	box.add_child(btn_start)

	btn_settings = _button("SETTINGS")
	btn_settings.pressed.connect(open_settings)
	box.add_child(btn_settings)

	btn_quit = _button("QUIT GAME")
	btn_quit.visible = not OS.has_feature("web")
	btn_quit.pressed.connect(_on_quit_pressed)
	box.add_child(btn_quit)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap2)

	var hints := _label(
		"WASD move · SPACE jump · SHIFT dash · CTRL slide · ESC pause\n" +
		"LMB fire · RMB coin · F parry · E shop · 1/2/3 weapons\n" +
		"blood heals · parry the white eyes · shoot the coin", 7, MUTED)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.custom_minimum_size = Vector2(300, 0)
	box.add_child(hints)


func _value_label() -> Label:
	var l := _label("", 8, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(42, 0)
	return l


func _add_row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := _label(text, 8, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
	lbl.custom_minimum_size = Vector2(86, 0)
	row.add_child(lbl)
	box.add_child(row)
	return row


static func _slider(minv: float, maxv: float, stepv: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = stepv
	s.custom_minimum_size = Vector2(120, 12)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_stylebox_override("slider", _stylebox(Color(0.1, 0.02, 0.03, 0.9), Color(0.35, 0.06, 0.09)))
	s.add_theme_stylebox_override("grabber_area", _stylebox(ACCENT, ACCENT))
	s.add_theme_stylebox_override("grabber_area_highlight", _stylebox(CYAN, CYAN))
	return s


static func _toggle_button() -> Button:
	var b := _button("OFF", 56)
	b.toggle_mode = true
	return b


func _build_settings_panel() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.visible = false
	add_child(settings_panel)

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.05, 0.01, 0.02, 0.96), Color(0.45, 0.07, 0.1)))
	_centered(panel)
	settings_panel.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("SETTINGS", 13, Color(1.0, 0.62, 0.3)))

	var dm := float(Settings.default_value("mouse_sensitivity"))
	var ds := float(Settings.default_value("stick_look_speed"))

	var r1 := _add_row(box, "MOUSE SENS")
	_sens = _slider(dm * 0.2, dm * 3.0, dm * 0.05)
	_sens_lbl = _value_label()
	r1.add_child(_sens)
	r1.add_child(_sens_lbl)

	var r2 := _add_row(box, "STICK SPEED")
	_stick = _slider(ds * 0.2, ds * 3.0, ds * 0.1)
	_stick_lbl = _value_label()
	r2.add_child(_stick)
	r2.add_child(_stick_lbl)

	var r3 := _add_row(box, "INVERT LOOK")
	_invert = _toggle_button()
	r3.add_child(_invert)

	var r4 := _add_row(box, "VOLUME")
	_volume = _slider(0.0, 1.0, 0.05)
	_vol_lbl = _value_label()
	r4.add_child(_volume)
	r4.add_child(_vol_lbl)

	var r5 := _add_row(box, "FULLSCREEN")
	r5.visible = not OS.has_feature("web")
	_fullscreen = _toggle_button()
	r5.add_child(_fullscreen)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)
	btn_reset = _button("RESET DEFAULTS", 104)
	btn_reset.pressed.connect(_reset_defaults)
	actions.add_child(btn_reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	btn_back = _button("BACK", 64)
	btn_back.pressed.connect(close_settings)
	actions.add_child(btn_back)

	_sens.value_changed.connect(func(_v): _on_live_change())
	_stick.value_changed.connect(func(_v): _on_live_change())
	_volume.value_changed.connect(func(_v): _on_live_change())
	_sens.drag_ended.connect(func(_c): _persist())
	_stick.drag_ended.connect(func(_c): _persist())
	_volume.drag_ended.connect(func(_c): _persist())
	_invert.toggled.connect(func(_on):
		_on_live_change()
		_persist())
	_fullscreen.toggled.connect(func(_on):
		_on_live_change()
		_persist())


func open_settings() -> void:
	settings_open = true
	main_panel.visible = false
	settings_panel.visible = true
	_sync_widgets()
	if is_inside_tree() and btn_back:
		btn_back.grab_focus()


func close_settings() -> void:
	_persist()
	settings_open = false
	settings_panel.visible = false
	main_panel.visible = true
	if is_inside_tree() and btn_start:
		btn_start.grab_focus()


func _collect() -> Dictionary:
	return {
		"mouse_sensitivity": float(_sens.value),
		"stick_look_speed": float(_stick.value),
		"invert_look": bool(_invert.button_pressed),
		"master_volume": float(_volume.value),
		"fullscreen": bool(_fullscreen.button_pressed),
	}


func _on_live_change() -> void:
	if _arming:
		return
	Settings.apply(_collect())
	_refresh_labels()


func _persist() -> void:
	if _arming:
		return
	Settings.save(_collect())


func _sync_widgets() -> void:
	var cur: Dictionary = Settings.current if not Settings.current.is_empty() \
			else Settings.load_config()
	_arming = true
	_sens.set_value_no_signal(clampf(float(cur.get("mouse_sensitivity", _sens.min_value)), _sens.min_value, _sens.max_value))
	_stick.set_value_no_signal(clampf(float(cur.get("stick_look_speed", _stick.min_value)), _stick.min_value, _stick.max_value))
	_volume.set_value_no_signal(clampf(float(cur.get("master_volume", 1.0)), 0.0, 1.0))
	_invert.set_pressed_no_signal(bool(cur.get("invert_look", false)))
	_fullscreen.set_pressed_no_signal(bool(cur.get("fullscreen", false)))
	_arming = false
	_refresh_labels()


func _refresh_labels() -> void:
	var dm := float(Settings.default_value("mouse_sensitivity"))
	var ds := float(Settings.default_value("stick_look_speed"))
	_sens_lbl.text = "×%.2f" % (float(_sens.value) / dm)
	_stick_lbl.text = "×%.2f" % (float(_stick.value) / ds)
	_vol_lbl.text = "%d%%" % int(round(float(_volume.value) * 100.0))
	_invert.text = "ON" if _invert.button_pressed else "OFF"
	_invert.add_theme_color_override("font_color", CYAN if _invert.button_pressed else PAPER)
	_fullscreen.text = "ON" if _fullscreen.button_pressed else "OFF"
	_fullscreen.add_theme_color_override("font_color", CYAN if _fullscreen.button_pressed else PAPER)


func _reset_defaults() -> void:
	var d := Settings.capture_defaults().duplicate()
	_arming = true
	_sens.set_value_no_signal(float(d.get("mouse_sensitivity", _sens.min_value)))
	_stick.set_value_no_signal(float(d.get("stick_look_speed", _stick.min_value)))
	_volume.set_value_no_signal(float(d.get("master_volume", 1.0)))
	_invert.set_pressed_no_signal(bool(d.get("invert_look", false)))
	_fullscreen.set_pressed_no_signal(bool(d.get("fullscreen", false)))
	_arming = false
	_on_live_change()
	_persist()


func _on_start_pressed() -> void:
	start_game()


func start_game() -> void:
	var target_scene := GAME_SCENE
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scenes/main.tscn"
	get_tree().change_scene_to_file(target_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if settings_open:
		var back: bool = ev is InputEventKey and ev.pressed and not ev.echo \
				and ev.keycode == KEY_ESCAPE
		var joy: InputEventJoypadButton = ev as InputEventJoypadButton
		if back or (joy != null and joy.pressed and joy.button_index == JOY_BUTTON_B):
			close_settings()
			get_viewport().set_input_as_handled()
	else:
		if _is_start_trigger(ev):
			start_game()
			get_viewport().set_input_as_handled()


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
