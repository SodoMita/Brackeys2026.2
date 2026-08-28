class_name TouchControls
extends CanvasLayer
## Touchscreen gameplay controls, merged from the old mobile_controls.gd +
## touch_controls.gd pair (which drifted apart and fought over input).
##
##  - left screen half : dynamic virtual joystick (Thumbstick Plugin) -> move
##  - right screen half: multitouch drag (Thumbstick Plugin)          -> look
##  - action buttons   : real Controls with their own _gui_input, so the GUI
##    stack (Dialogic, pause menu — anything on a higher CanvasLayer) wins
##    input naturally. No global _input() interception, no manual hit-testing,
##    no duplicated button geometry.
##
## The layer is ONLY active in UIManager's GAMEPLAY state (set_active); while
## a dialogue or the pause menu is up it is hidden and receives nothing.

signal pause_pressed

const STICK_SCENE := "res://addons/thumbstick_plugin/plugin/controllers/normal_joystick.tscn"
const LOOK_SCENE := "res://addons/thumbstick_plugin/plugin/controllers/multitouch_controller.tscn"

var player: CharacterBody3D = null

var _buttons: Array[TouchButton] = []
var _last_drag := {}  # finger_index -> last drag position (look surface)


## On-screen action button: a Control that owns exactly one touch at a time.
## Visual rect and hit rect are the same node — they cannot drift apart.
class TouchButton extends Control:
	signal button_down
	signal button_up

	var _touch_index := -1
	var _bg: ColorRect

	func _init(text: String, btn_size: Vector2) -> void:
		size = btn_size
		custom_minimum_size = btn_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = ColorRect.new()
		_bg.color = Color(1.0, 0.2, 0.3, 0.22)
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font_size = 12
		ls.font_color = Color(1, 1, 1, 0.8)
		l.label_settings = ls
		l.text = text
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _touch_index == -1:
				_touch_index = ev.index
				_set_held(true)
			elif not ev.pressed and ev.index == _touch_index:
				_touch_index = -1
				_set_held(false)
			accept_event()
		elif ev is InputEventScreenDrag and ev.index == _touch_index:
			# a held button stays held while its finger wiggles
			accept_event()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT \
				and not Input.is_emulating_mouse_from_touch():
			# real-mouse fallback for desktop debugging; emulated mouse events
			# are skipped or every touch would fire the button twice
			_set_held(ev.pressed)
			accept_event()

	func force_release() -> void:
		if _touch_index != -1 or _bg.color.a > 0.3:
			_touch_index = -1
			_set_held(false)

	func _set_held(on: bool) -> void:
		_bg.color.a = 0.45 if on else 0.22
		if on:
			button_down.emit()
		else:
			button_up.emit()


func _init() -> void:
	layer = UILayers.TOUCH


func setup(p: CharacterBody3D) -> void:
	player = p
	_build_move_stick()
	_build_look_area()
	# Buttons are added AFTER the half-screen surfaces so the GUI picks them
	# first when a touch lands on both.
	_build_buttons()


func set_active(on: bool) -> void:
	## Called by UIManager on every state change. Hidden Controls receive no
	## GUI input, so this both hides and mutes the whole layer.
	if visible == on:
		return
	visible = on
	if not on:
		_release_everything()


func _release_everything() -> void:
	for b in _buttons:
		b.force_release()
	_last_drag.clear()
	if player:
		player.touch_move = Vector2.ZERO
		player.touch_look = Vector2.ZERO
		player.touch_fire = false
		player.touch_jump = false
		player.touch_slide = false


func _build_move_stick() -> void:
	if not ResourceLoader.exists(STICK_SCENE):
		return
	var stick: Control = (load(STICK_SCENE) as PackedScene).instantiate()
	stick.name = "MoveStick"
	add_child(stick)
	_anchor_half(stick, 0.0, 0.5)
	stick.on_trigger.connect(func(a):
		if player:
			# addon: up = -y; player: +y = forward
			player.touch_move = Vector2(a.input_v.x, -a.input_v.y))
	stick.on_released.connect(func(_a):
		if player:
			player.touch_move = Vector2.ZERO)


func _build_look_area() -> void:
	if not ResourceLoader.exists(LOOK_SCENE):
		return
	var look: Control = (load(LOOK_SCENE) as PackedScene).instantiate()
	look.name = "LookArea"
	add_child(look)
	_anchor_half(look, 0.5, 1.0)
	look.on_touch_pressed.connect(func(a):
		_last_drag[a.finger_index] = a.pressed_position)
	look.on_touch_dragged.connect(func(a):
		if player and _last_drag.has(a.finger_index):
			player.touch_look += a.drag_pos - _last_drag[a.finger_index]
		_last_drag[a.finger_index] = a.drag_pos)
	look.on_touch_released.connect(func(a):
		_last_drag.erase(a.finger_index))


static func _anchor_half(c: Control, left: float, right: float) -> void:
	c.anchor_left = left
	c.anchor_right = right
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = 0.0
	c.offset_bottom = 0.0


func _build_buttons() -> void:
	# name: [label, size, anchor, offset]
	var defs := {
		"fire": ["FIRE", Vector2(110, 110), Vector2(1, 1), Vector2(-130, -130)],
		"jump": ["JMP", Vector2(74, 74), Vector2(1, 1), Vector2(-250, -160)],
		"dash": ["DSH", Vector2(74, 74), Vector2(1, 1), Vector2(-250, -60)],
		# old offsets (-40) pushed these partly off the right screen edge
		"slide": ["SLD", Vector2(74, 74), Vector2(1, 1), Vector2(-114, -260)],
		"wpn": ["WPN", Vector2(64, 44), Vector2(1, 1), Vector2(-104, -330)],
		"parry": ["PRY", Vector2(74, 74), Vector2(0, 1), Vector2(40, -90)],
		"coin": ["COIN", Vector2(74, 74), Vector2(0, 1), Vector2(40, -190)],
		"pause": ["||", Vector2(64, 44), Vector2(1, 0), Vector2(-84, 20)],
	}
	for action in defs:
		var d: Array = defs[action]
		var b := TouchButton.new(d[0], d[1])
		b.name = "Btn_" + action
		var anchor: Vector2 = d[2]
		var off: Vector2 = d[3]
		b.anchor_left = anchor.x
		b.anchor_right = anchor.x
		b.anchor_top = anchor.y
		b.anchor_bottom = anchor.y
		b.offset_left = off.x
		b.offset_top = off.y
		b.offset_right = off.x + d[1].x
		b.offset_bottom = off.y + d[1].y
		b.button_down.connect(_on_action.bind(action, true))
		b.button_up.connect(_on_action.bind(action, false))
		add_child(b)
		_buttons.append(b)


func _on_action(action: String, on: bool) -> void:
	if action == "pause":
		if on:
			pause_pressed.emit()
		return
	if player == null:
		return
	match action:
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
