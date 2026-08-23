extends Control
## Virtual touchscreen controls / Mobile FPS HUD controls:
## Left-side dynamic joystick (move), right-side drag (look),
## on-screen buttons: FIRE / JUMP / DASH / SLIDE / WPN / PARRY / COIN,
## and a dedicated PAUSE button for mobile navigation.

signal pause_pressed

var player: CharacterBody3D
var enabled := true

var _stick_id := -1
var _stick_anchor := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _knob: Control
var _stick_base: Control
var _touch_buttons := {}  # touch_index -> button_name
var buttons := {}         # name -> {rect: Rect2, node: Control, anchor: Vector2, label: Label}

const STICK_R := 26.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(p: CharacterBody3D) -> void:
	player = p
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Definitions scaled for 320x180 viewport
	var defs := {
		# Bottom-right combat cluster
		"fire": {"rect": Rect2(0, 0, 38, 38), "text": "FIRE", "anchor": Vector2(1, 1), "off": Vector2(-44, -44), "color": Color(0.95, 0.25, 0.15, 0.45)},
		"jump": {"rect": Rect2(0, 0, 30, 30), "text": "JMP", "anchor": Vector2(1, 1), "off": Vector2(-80, -38), "color": Color(0.85, 0.45, 0.1, 0.35)},
		"dash": {"rect": Rect2(0, 0, 30, 30), "text": "DSH", "anchor": Vector2(1, 1), "off": Vector2(-80, -74), "color": Color(0.85, 0.45, 0.1, 0.35)},
		"slide": {"rect": Rect2(0, 0, 30, 26), "text": "SLD", "anchor": Vector2(1, 1), "off": Vector2(-44, -76), "color": Color(0.85, 0.45, 0.1, 0.35)},
		"wpn": {"rect": Rect2(0, 0, 30, 24), "text": "WPN", "anchor": Vector2(1, 1), "off": Vector2(-44, -106), "color": Color(0.2, 0.6, 0.8, 0.35)},
		# Bottom-left auxiliary cluster
		"parry": {"rect": Rect2(0, 0, 28, 24), "text": "PRY", "anchor": Vector2(0, 1), "off": Vector2(6, -56), "color": Color(0.2, 0.85, 0.9, 0.35)},
		"coin": {"rect": Rect2(0, 0, 28, 24), "text": "COIN", "anchor": Vector2(0, 1), "off": Vector2(38, -56), "color": Color(0.95, 0.8, 0.2, 0.35)},
		# Top-right mobile pause button
		"pause": {"rect": Rect2(0, 0, 24, 20), "text": "||", "anchor": Vector2(1, 0), "off": Vector2(-30, 6), "color": Color(0.85, 0.2, 0.25, 0.4)},
	}

	for btn_name in defs:
		var d: Dictionary = defs[btn_name]
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = d.color
		sb.border_color = Color(1.0, 0.6, 0.2, 0.7) if btn_name != "pause" else Color(1.0, 0.3, 0.3, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		panel.add_theme_stylebox_override("panel", sb)
		_anchor_rect(panel, d.anchor, d.off, d.rect.size)
		add_child(panel)

		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font_size = 9 if btn_name != "pause" else 10
		ls.font_color = Color(1.0, 0.95, 0.9)
		ls.outline_color = Color.BLACK
		ls.outline_size = 2
		l.label_settings = ls
		l.text = d.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(l)

		buttons[btn_name] = {
			"rect": Rect2(d.off, d.rect.size),
			"node": panel,
			"anchor": d.anchor,
			"label": l,
			"base_color": d.color,
		}

	# Dynamic joystick base and knob
	_stick_base = Panel.new()
	_stick_base.size = Vector2(STICK_R * 2.0, STICK_R * 2.0)
	var sb_base := StyleBoxFlat.new()
	sb_base.bg_color = Color(0.1, 0.05, 0.02, 0.25)
	sb_base.border_color = Color(0.3, 0.8, 1.0, 0.4)
	sb_base.set_border_width_all(1)
	sb_base.set_corner_radius_all(int(STICK_R))
	_stick_base.add_theme_stylebox_override("panel", sb_base)
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.visible = false
	add_child(_stick_base)

	_knob = Panel.new()
	_knob.size = Vector2(16, 16)
	var sb_knob := StyleBoxFlat.new()
	sb_knob.bg_color = Color(0.2, 0.9, 1.0, 0.6)
	sb_knob.border_color = Color(1.0, 1.0, 1.0, 0.9)
	sb_knob.set_border_width_all(1)
	sb_knob.set_corner_radius_all(8)
	_knob.add_theme_stylebox_override("panel", sb_knob)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.visible = false
	add_child(_knob)


func _anchor_rect(c: Control, anchor: Vector2, off: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + size.x
	c.offset_bottom = off.y + size.y


func _button_at(pos: Vector2) -> String:
	var sz := get_viewport().get_visible_rect().size
	for btn_name in buttons:
		var b: Dictionary = buttons[btn_name]
		var anchor: Vector2 = b.anchor
		var r: Rect2 = b.rect
		var origin := Vector2(sz.x * anchor.x + r.position.x, sz.y * anchor.y + r.position.y)
		var btn_rect := Rect2(origin, r.size)
		if btn_rect.grow(4.0).has_point(pos):
			return btn_name
	return ""


func trigger_button(btn_name: String, pressed: bool = true) -> void:
	_press(btn_name, pressed)


func _press(btn_name: String, on: bool) -> void:
	match btn_name:
		"pause":
			if on:
				pause_pressed.emit()
		"fire":
			if player:
				player.touch_fire = on
		"jump":
			if player:
				player.touch_jump = on
		"slide":
			if player:
				player.touch_slide = on
		"dash":
			if on and player:
				player.request_dash()
		"wpn":
			if on and player:
				player.cycle_weapon()
		"parry":
			if on and player:
				player.request_parry()
		"coin":
			if on and player:
				player.toss_coin()

	if btn_name in buttons:
		var panel: PanelContainer = buttons[btn_name].node
		var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if sb:
			var base_c: Color = buttons[btn_name].base_color
			sb.bg_color = Color(0.3, 0.9, 1.0, 0.7) if on else base_c


func _input(ev: InputEvent) -> void:
	if not enabled:
		return

	if ev is InputEventScreenTouch:
		if ev.pressed:
			var btn := _button_at(ev.position)
			if btn != "":
				_touch_buttons[ev.index] = btn
				_press(btn, true)
				get_viewport().set_input_as_handled()
				return

			if ev.position.x < get_viewport().get_visible_rect().size.x * 0.45:
				_stick_id = ev.index
				_stick_anchor = ev.position
				_stick_base.position = _stick_anchor - Vector2(STICK_R, STICK_R)
				_stick_base.visible = true
				_knob.position = _stick_anchor - Vector2(8, 8)
				_knob.visible = true
				get_viewport().set_input_as_handled()
			else:
				_look_id = ev.index
				_look_last = ev.position
				get_viewport().set_input_as_handled()
		else:
			if ev.index in _touch_buttons:
				var btn: String = _touch_buttons[ev.index]
				_press(btn, false)
				_touch_buttons.erase(ev.index)
				get_viewport().set_input_as_handled()

			if ev.index == _stick_id:
				_stick_id = -1
				if player:
					player.touch_move = Vector2.ZERO
				_knob.visible = false
				_stick_base.visible = false
				get_viewport().set_input_as_handled()

			if ev.index == _look_id:
				_look_id = -1
				get_viewport().set_input_as_handled()

	elif ev is InputEventScreenDrag:
		if ev.index == _stick_id:
			var d: Vector2 = ev.position - _stick_anchor
			var v: Vector2 = d.limit_length(STICK_R) / STICK_R
			if player:
				player.touch_move = Vector2(v.x, -v.y)
			_knob.position = _stick_anchor + v * STICK_R - Vector2(8, 8)
			get_viewport().set_input_as_handled()
		elif ev.index == _look_id:
			if player:
				player.touch_look += ev.relative
			get_viewport().set_input_as_handled()
