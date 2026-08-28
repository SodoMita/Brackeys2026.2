class_name SettingsPanel
extends Control
## Reusable procedural settings screen (extracted from main_menu.gd so the
## pause menu shows the exact same panel instead of a copy).
## Emits `closed` when the player backs out; the host decides what to show.

signal closed

var btn_back: Button
var btn_reset: Button

var _sens: HSlider
var _stick: HSlider
var _volume: HSlider
var _dialogue_volume: HSlider
var _typing_volume: HSlider
var _render_scale: HSlider
var _screen_shake: HSlider
var _deadzone: HSlider
var _text_speed: HSlider
var _resolution_width: SpinBox
var _resolution_height: SpinBox
var _vsync: OptionButton
var _aa: OptionButton
var _invert: Button
var _fullscreen: Button
var _borderless: Button
var _vibration: Button
var _subtitles: Button
var _sens_lbl: Label
var _stick_lbl: Label
var _vol_lbl: Label
var _arming := false
var _binding_action := ""
var _binding_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func open() -> void:
	visible = true
	_sync_widgets()
	if is_inside_tree() and btn_back:
		btn_back.grab_focus()


func close() -> void:
	_persist()
	_binding_action = ""
	_binding_button = null
	visible = false
	closed.emit()


func is_binding() -> bool:
	return not _binding_action.is_empty()


func _build() -> void:
	add_child(UIKit.fullrect_dim())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.05, 0.01, 0.02, 0.96), Color(0.45, 0.07, 0.1)))
	UIKit.centered(panel)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 620)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	box.add_child(UIKit.label("SETTINGS", 13, Color(1.0, 0.62, 0.3)))

	var dm := float(Settings.default_value("mouse_sensitivity"))
	var ds := float(Settings.default_value("stick_look_speed"))

	var r1 := _add_row(box, "MOUSE SENS")
	_sens = UIKit.slider(dm * 0.2, dm * 3.0, dm * 0.05)
	_sens_lbl = _value_label()
	r1.add_child(_sens)
	r1.add_child(_sens_lbl)

	var r2 := _add_row(box, "STICK SPEED")
	_stick = UIKit.slider(ds * 0.2, ds * 3.0, ds * 0.1)
	_stick_lbl = _value_label()
	r2.add_child(_stick)
	r2.add_child(_stick_lbl)

	var r3 := _add_row(box, "INVERT LOOK")
	_invert = UIKit.toggle_button()
	r3.add_child(_invert)

	var r4 := _add_row(box, "VOLUME")
	_volume = UIKit.slider(0.0, 1.0, 0.05)
	_vol_lbl = _value_label()
	r4.add_child(_volume)
	r4.add_child(_vol_lbl)
	var ra1 := _add_row(box, "DIALOGUE VOL")
	_dialogue_volume = UIKit.slider(0.0, 1.0, 0.05)
	ra1.add_child(_dialogue_volume)
	var ra2 := _add_row(box, "TYPING VOL")
	_typing_volume = UIKit.slider(0.0, 1.0, 0.05)
	ra2.add_child(_typing_volume)
	var ra3 := _add_row(box, "RENDER SCALE")
	_render_scale = UIKit.slider(0.5, 1.5, 0.05)
	ra3.add_child(_render_scale)
	var ra4 := _add_row(box, "SCREEN SHAKE")
	_screen_shake = UIKit.slider(0.0, 1.0, 0.05)
	ra4.add_child(_screen_shake)

	var r5 := _add_row(box, "FULLSCREEN")
	r5.visible = not OS.has_feature("web")
	_fullscreen = UIKit.toggle_button()
	r5.add_child(_fullscreen)

	var rv := _add_row(box, "RESOLUTION")
	_resolution_width = UIKit.resolution_box()
	_resolution_height = UIKit.resolution_box()
	rv.add_child(_resolution_width)
	rv.add_child(UIKit.label("×", 10, UIKit.PAPER))
	rv.add_child(_resolution_height)
	var rvs := _add_row(box, "V-SYNC")
	_vsync = UIKit.options(["OFF", "ON"])
	rvs.add_child(_vsync)
	var raa := _add_row(box, "ANTI-ALIASING")
	_aa = UIKit.options(["OFF", "MSAA 2X", "MSAA 4X", "MSAA 8X"])
	raa.add_child(_aa)

	var r6 := _add_row(box, "STICK DEADZONE")
	_deadzone = UIKit.slider(0.0, 0.8, 0.01)
	r6.add_child(_deadzone)
	var r7 := _add_row(box, "TEXT SPEED")
	_text_speed = UIKit.slider(0.001, 0.1, 0.001)
	r7.add_child(_text_speed)
	var r8 := _add_row(box, "BORDERLESS")
	_borderless = UIKit.toggle_button()
	r8.add_child(_borderless)
	var r9 := _add_row(box, "CONTROLLER VIBRATION")
	_vibration = UIKit.toggle_button()
	r9.add_child(_vibration)
	var r10 := _add_row(box, "SUBTITLES")
	_subtitles = UIKit.toggle_button()
	r10.add_child(_subtitles)

	box.add_child(UIKit.label("KEY MAPPING — CLICK A BINDING, THEN PRESS A KEY", 8, UIKit.CYAN))
	for entry in [["MOVE FORWARD", "move_forward"], ["MOVE BACK", "move_back"], ["MOVE LEFT", "move_left"], ["MOVE RIGHT", "move_right"], ["JUMP", "jump"], ["DASH", "dash"], ["SLIDE", "slide"], ["PARRY", "parry"], ["FIRE", "fire"], ["COIN", "coin"], ["INTERACT", "interact"]]:
		_add_binding_row(box, entry[0], entry[1])

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)
	btn_reset = UIKit.button("RESET DEFAULTS", 104)
	btn_reset.pressed.connect(_reset_defaults)
	actions.add_child(btn_reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	btn_back = UIKit.button("BACK", 64)
	btn_back.pressed.connect(close)
	actions.add_child(btn_back)

	for s: HSlider in [_sens, _stick, _volume, _dialogue_volume, _typing_volume,
			_render_scale, _screen_shake, _deadzone, _text_speed]:
		s.value_changed.connect(func(_v): _on_live_change())
		s.drag_ended.connect(func(_c): _persist())
	_resolution_width.value_changed.connect(func(_v): _on_live_change())
	_resolution_height.value_changed.connect(func(_v): _on_live_change())
	_vsync.item_selected.connect(func(_i): _on_live_change())
	_aa.item_selected.connect(func(_i): _on_live_change())
	for toggle: Button in [_invert, _fullscreen, _borderless, _vibration, _subtitles]:
		toggle.toggled.connect(func(_on):
			_on_live_change()
			_persist())


func _value_label() -> Label:
	var l := UIKit.label("", 8, UIKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(42, 0)
	return l


func _add_row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := UIKit.label(text, 8, UIKit.PAPER, HORIZONTAL_ALIGNMENT_LEFT)
	lbl.custom_minimum_size = Vector2(86, 0)
	row.add_child(lbl)
	box.add_child(row)
	return row


func _add_binding_row(box: VBoxContainer, title: String, action: String) -> void:
	var row := _add_row(box, title)
	var button := UIKit.button(Settings.binding_text(action), 150)
	button.pressed.connect(func(): _begin_rebind(action, button))
	row.add_child(button)


func _begin_rebind(action: String, button: Button) -> void:
	_binding_action = action
	_binding_button = button
	button.text = "PRESS A KEY…"


func _finish_rebind(event: InputEvent) -> void:
	Settings.rebind(_binding_action, event)
	_binding_button.text = Settings.binding_text(_binding_action)
	_binding_action = ""
	_binding_button = null


func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if not _binding_action.is_empty():
		if (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton) and ev.is_pressed():
			_finish_rebind(ev)
			_mark_handled()
		return
	var back: bool = ev is InputEventKey and ev.pressed and not ev.echo \
			and ev.keycode == KEY_ESCAPE
	var joy: InputEventJoypadButton = ev as InputEventJoypadButton
	if back or (joy != null and joy.pressed and joy.button_index == JOY_BUTTON_B):
		close()
		_mark_handled()


func _mark_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _collect() -> Dictionary:
	return {
		"mouse_sensitivity": float(_sens.value),
		"stick_look_speed": float(_stick.value),
		"invert_look": bool(_invert.button_pressed),
		"master_volume": float(_volume.value),
		"dialogue_volume": float(_dialogue_volume.value),
		"typing_volume": float(_typing_volume.value),
		"render_scale": float(_render_scale.value),
		"screen_shake": float(_screen_shake.value),
		"fullscreen": bool(_fullscreen.button_pressed),
		"stick_deadzone": float(_deadzone.value),
		"text_speed": float(_text_speed.value),
		"borderless": bool(_borderless.button_pressed),
		"controller_vibration": bool(_vibration.button_pressed),
		"subtitles": bool(_subtitles.button_pressed),
		"resolution": Vector2i(int(_resolution_width.value), int(_resolution_height.value)),
		"vsync": _vsync.selected,
		"aa_mode": _aa.selected,
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
	_dialogue_volume.set_value_no_signal(clampf(float(cur.get("dialogue_volume", 1.0)), 0.0, 1.0))
	_typing_volume.set_value_no_signal(clampf(float(cur.get("typing_volume", 0.8)), 0.0, 1.0))
	_render_scale.set_value_no_signal(clampf(float(cur.get("render_scale", 1.0)), 0.5, 1.5))
	_screen_shake.set_value_no_signal(clampf(float(cur.get("screen_shake", 1.0)), 0.0, 1.0))
	_invert.set_pressed_no_signal(bool(cur.get("invert_look", false)))
	_fullscreen.set_pressed_no_signal(bool(cur.get("fullscreen", false)))
	_deadzone.set_value_no_signal(float(cur.get("stick_deadzone", 0.18)))
	_text_speed.set_value_no_signal(float(cur.get("text_speed", 0.01)))
	_borderless.set_pressed_no_signal(bool(cur.get("borderless", false)))
	_vibration.set_pressed_no_signal(bool(cur.get("controller_vibration", true)))
	_subtitles.set_pressed_no_signal(bool(cur.get("subtitles", true)))
	var wanted: Vector2i = cur.get("resolution", Vector2i(1280, 720))
	_resolution_width.set_value_no_signal(wanted.x)
	_resolution_height.set_value_no_signal(wanted.y)
	_vsync.select(clampi(int(cur.get("vsync", 1)), 0, 1))
	_aa.select(clampi(int(cur.get("aa_mode", 2)), 0, 3))
	_arming = false
	_refresh_labels()


func _refresh_labels() -> void:
	var dm := float(Settings.default_value("mouse_sensitivity"))
	var ds := float(Settings.default_value("stick_look_speed"))
	_sens_lbl.text = "×%.2f" % (float(_sens.value) / dm)
	_stick_lbl.text = "×%.2f" % (float(_stick.value) / ds)
	_vol_lbl.text = "%d%%" % int(round(float(_volume.value) * 100.0))
	_invert.text = "ON" if _invert.button_pressed else "OFF"
	_invert.add_theme_color_override("font_color", UIKit.CYAN if _invert.button_pressed else UIKit.PAPER)
	_fullscreen.text = "ON" if _fullscreen.button_pressed else "OFF"
	_fullscreen.add_theme_color_override("font_color", UIKit.CYAN if _fullscreen.button_pressed else UIKit.PAPER)
	for toggle in [_borderless, _vibration, _subtitles]:
		toggle.text = "ON" if toggle.button_pressed else "OFF"


func _reset_defaults() -> void:
	Settings.apply(Settings.capture_defaults())
	_sync_widgets()
	_persist()
