extends Control
## Virtual touchscreen controls: left-side dynamic stick (move),
## right-side drag (look), on-screen FIRE / JUMP / DASH / SLIDE / WPN.
## Writes straight into the player's aggregated input vars.

var player: CharacterBody3D
## Gameplay only — menus own the input while they're open (game.gd toggles
## this with the run state; mouse-from-touch emulation is flipped then too).
var enabled := true

var _stick_id := -1
var _stick_anchor := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _knob: ColorRect
var buttons := {}  # name -> {rect, label}

const STICK_R := 70.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p: CharacterBody3D) -> void:
	player = p
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# buttons (bottom-right cluster)
	var defs := {
		"fire": {"rect": Rect2(0, 0, 110, 110), "text": "FIRE", "anchor": Vector2(1, 1), "off": Vector2(-130, -130)},
		"jump": {"rect": Rect2(0, 0, 74, 74), "text": "JMP", "anchor": Vector2(1, 1), "off": Vector2(-250, -160)},
		"dash": {"rect": Rect2(0, 0, 74, 74), "text": "DSH", "anchor": Vector2(1, 1), "off": Vector2(-250, -60)},
		"slide": {"rect": Rect2(0, 0, 74, 74), "text": "SLD", "anchor": Vector2(1, 1), "off": Vector2(-40, -260)},
		"wpn": {"rect": Rect2(0, 0, 64, 44), "text": "WPN", "anchor": Vector2(1, 1), "off": Vector2(-40, -330)},
		"parry": {"rect": Rect2(0, 0, 74, 74), "text": "PRY", "anchor": Vector2(0, 1), "off": Vector2(40, -90)},
		"coin": {"rect": Rect2(0, 0, 74, 74), "text": "COIN", "anchor": Vector2(0, 1), "off": Vector2(40, -190)},
	}
	for name in defs:
		var d: Dictionary = defs[name]
		var r := ColorRect.new()
		r.size = d.rect.size
		r.color = Color(1.0, 0.2, 0.3, 0.22)
		_anchor_rect(r, d.anchor, d.off, d.rect.size)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font_size = 12
		ls.font_color = Color(1, 1, 1, 0.8)
		l.label_settings = ls
		l.text = d.text
		_anchor_rect(l, d.anchor, d.off, d.rect.size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		buttons[name] = {"rect": Rect2(d.off, d.rect.size), "node": r, "anchor": d.anchor}
	_knob = ColorRect.new()
	_knob.size = Vector2(26, 26)
	_knob.color = Color(0.2, 0.9, 1.0, 0.35)
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
	for name in buttons:
		var b: Dictionary = buttons[name]
		var anchor: Vector2 = b.anchor
		var r: Rect2 = b.rect
		var origin := Vector2(sz.x * anchor.x + r.position.x, sz.y * anchor.y + r.position.y)
		if Rect2(origin, r.size).grow(8.0).has_point(pos):
			return name
	return ""


func _press(name: String, on: bool) -> void:
	if player == null:
		return
	match name:
		"fire":
			player.touch_fire = on
		"jump":
			player.touch_jump = on
		"slide":
			player.touch_slide = on
		"dash":
			if on:
				player.request_dash()
		"wpn":
			if on:
				player.cycle_weapon()
		"parry":
			if on:
				player.request_parry()
		"coin":
			if on:
				player.toss_coin()
	if name in buttons:
		var c: ColorRect = buttons[name].node
		c.color.a = 0.45 if on else 0.22


func _input(ev: InputEvent) -> void:
	if not enabled:
		return
	if ev is InputEventScreenTouch:
		var btn := _button_at(ev.position)
		if ev.pressed:
			if btn != "":
				_press(btn, true)
				get_viewport().set_input_as_handled()
				return
			if ev.position.x < get_viewport().get_visible_rect().size.x * 0.45:
				_stick_id = ev.index
				_stick_anchor = ev.position
				_knob.visible = true
				get_viewport().set_input_as_handled()
			else:
				_look_id = ev.index
				_look_last = ev.position
				get_viewport().set_input_as_handled()
		else:
			if btn != "":
				_press(btn, false)
			if ev.index == _stick_id:
				_stick_id = -1
				player.touch_move = Vector2.ZERO
				_knob.visible = false
			if ev.index == _look_id:
				_look_id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == _stick_id:
			var d: Vector2 = ev.position - _stick_anchor
			var v: Vector2 = d.limit_length(STICK_R) / STICK_R
			player.touch_move = Vector2(v.x, -v.y)
			_knob.position = _stick_anchor + v * STICK_R - Vector2(13, 13)
			get_viewport().set_input_as_handled()
		elif ev.index == _look_id:
			player.touch_look += ev.relative
			get_viewport().set_input_as_handled()
