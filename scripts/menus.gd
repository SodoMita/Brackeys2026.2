extends Control
## CRIMSON VELOCITY — main menu, pause menu and settings panel, built
## procedurally for the 320×180 pixel UI (same style as the HUD in game.gd).
## Emits requests; game.gd owns the state machine and wires these signals.
##
## Runs while the tree is paused (PROCESS_MODE_ALWAYS) so ESC/B/gamepad
## navigate the pause menu; on touch devices mouse-from-touch emulation is
## enabled only while a menu is open (gameplay reads raw touches instead).

signal start_pressed
signal resume_pressed
signal quit_to_menu_pressed
signal quit_game_pressed

const ACCENT := Color(1.0, 0.16, 0.22)
const CYAN := Color(0.4, 0.95, 1.0)
const PAPER := Color(0.92, 0.86, 0.85)
const MUTED := Color(0.66, 0.56, 0.56)
const DIM := Color(0.02, 0.0, 0.01, 0.6)

var main_panel: Control
var pause_panel: Control
var settings_panel: Control
var settings_open := false
var settings_from: Control

var btn_start: Button
var btn_resume: Button
var btn_back: Button

var _sens: HSlider
var _stick: HSlider
var _volume: HSlider
var _invert: Button
var _fullscreen: Button
var _sens_lbl: Label
var _stick_lbl: Label
var _vol_lbl: Label
var _arming := false  # suppress apply/save while syncing widgets


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_main()
	_build_pause()
	_build_settings()


# ------------------------------------------------------------ open / close
func open_main() -> void:
	settings_open = false
	main_panel.visible = true
	pause_panel.visible = false
	settings_panel.visible = false
	visible = true
	_set_touch_mouse(true)
	if is_inside_tree():
		btn_start.grab_focus()


func open_pause() -> void:
	settings_open = false
	main_panel.visible = false
	pause_panel.visible = true
	settings_panel.visible = false
	visible = true
	_set_touch_mouse(true)
	if is_inside_tree():
		btn_resume.grab_focus()


func open_settings(from: Control) -> void:
	settings_from = from
	settings_open = true
	from.visible = false
	settings_panel.visible = true
	visible = true
	_set_touch_mouse(true)
	_sync_widgets()
	if is_inside_tree():
		btn_back.grab_focus()


func close_all() -> void:
	settings_open = false
	main_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	visible = false
	_set_touch_mouse(false)
	if is_inside_tree():
		release_focus()


# ------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	var back := ev is InputEventKey and ev.pressed and not ev.echo \
			and ev.keycode == KEY_ESCAPE
	var joy := ev as InputEventJoypadButton
	if joy == null or not joy.pressed:
		joy = null
	if settings_open:
		if back or (joy != null and joy.button_index == JOY_BUTTON_B):
			_close_settings()
			get_viewport().set_input_as_handled()
	elif pause_panel.visible:
		# ESC / START / B resumes (menus stay responsive while paused).
		if back or (joy != null and joy.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]):
			resume_pressed.emit()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------ builders
func _make_dim_panel() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)
	add_child(p)
	return p


func _centered(container: Control) -> void:
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH


func _centered_vbox(parent: Control, sep: int = 4) -> VBoxContainer:
	var box := VBoxContainer.new()
	_centered(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", sep)
	parent.add_child(box)
	return box


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
	b.custom_minimum_size = Vector2(width, 17)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("icon_normal_color", PAPER)
	b.add_theme_stylebox_override("normal", _stylebox(Color(0.07, 0.01, 0.02, 0.9), Color(0.5, 0.08, 0.12)))
	b.add_theme_stylebox_override("hover", _stylebox(Color(0.17, 0.03, 0.05, 0.95), ACCENT))
	b.add_theme_stylebox_override("pressed", _stylebox(Color(0.05, 0.01, 0.01, 0.95), CYAN))
	b.add_theme_stylebox_override("focus", _stylebox(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.85)))
	return b


func _build_main() -> void:
	main_panel = _make_dim_panel()
	var box := _centered_vbox(main_panel)
	box.add_child(_label("CRIMSON VELOCITY", 22, Color(1.0, 0.3, 0.32)))
	box.add_child(_label("blood heals · speed is power · style is everything", 7, MUTED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	btn_start = _button("START")
	btn_start.pressed.connect(func(): start_pressed.emit())
	box.add_child(btn_start)
	var opts := _button("SETTINGS")
	opts.pressed.connect(func(): open_settings(main_panel))
	box.add_child(opts)
	var quit := _button("QUIT GAME")
	quit.visible = not OS.has_feature("web")
	quit.pressed.connect(func(): quit_game_pressed.emit())
	box.add_child(quit)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap2)
	var hints := _label(
		"WASD move · SPACE jump · SHIFT dash · CTRL slide\n" +
		"LMB fire · RMB coin · F parry · 1/2 weapons · ESC pause\n" +
		"gamepad: sticks · A jump · LB dash · RB slide · RT fire · X parry\n" +
		"parry the white eyes · shoot the coin", 7, MUTED)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.custom_minimum_size = Vector2(300, 0)
	box.add_child(hints)


func _build_pause() -> void:
	pause_panel = _make_dim_panel()
	var box := _centered_vbox(pause_panel)
	box.add_child(_label("PAUSED", 16, Color(1.0, 0.3, 0.32)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	btn_resume = _button("RESUME")
	btn_resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(btn_resume)
	var opts := _button("SETTINGS")
	opts.pressed.connect(func(): open_settings(pause_panel))
	box.add_child(opts)
	var menu := _button("QUIT TO MENU")
	menu.pressed.connect(func(): quit_to_menu_pressed.emit())
	box.add_child(menu)


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


func _build_settings() -> void:
	settings_panel = _make_dim_panel()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.05, 0.01, 0.02, 0.94), Color(0.45, 0.07, 0.1)))
	_centered(panel)
	settings_panel.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("SETTINGS", 13, Color(1.0, 0.4, 0.42)))

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
	var reset := _button("RESET DEFAULTS", 104)
	reset.pressed.connect(func(): _reset_defaults())
	actions.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	btn_back = _button("BACK", 64)
	btn_back.pressed.connect(func(): _close_settings())
	actions.add_child(btn_back)

	_sens.value_changed.connect(func(_v): _on_live_change())
	_stick.value_changed.connect(func(_v): _on_live_change())
	_volume.value_changed.connect(func(_v): _on_live_change())
	_sens.drag_ended.connect(func(_changed): _persist())
	_stick.drag_ended.connect(func(_changed): _persist())
	_volume.drag_ended.connect(func(_changed): _persist())
	_invert.toggled.connect(func(_on):
		_on_live_change()
		_persist())
	_fullscreen.toggled.connect(func(_on):
		_on_live_change()
		_persist())


# ------------------------------------------------------------ settings logic
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


func _close_settings() -> void:
	_persist()
	settings_open = false
	settings_panel.visible = false
	if settings_from:
		settings_from.visible = true
		if settings_from == main_panel and is_inside_tree():
			btn_start.grab_focus()
		elif settings_from == pause_panel and is_inside_tree():
			btn_resume.grab_focus()


func _set_touch_mouse(on: bool) -> void:
	if DisplayServer.is_touchscreen_available():
		Input.set_emulate_mouse_from_touch(on)
