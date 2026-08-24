extends CanvasLayer
## Mobile FPS input via the Thumbstick Plugin (Godot Asset Library #3400,
## github.com/JoenTNT/godot_thumbstick_addon, MIT):
##  - dynamic virtual joystick on the left half  -> movement
##  - multitouch controller on the right half    -> look

var player: CharacterBody3D = null
var _last_drag := {}


func setup(p: CharacterBody3D) -> void:
	player = p
	layer = 30
	var stick_path := "res://addons/thumbstick_plugin/plugin/controllers/normal_joystick.tscn"
	var look_path := "res://addons/thumbstick_plugin/plugin/controllers/multitouch_controller.tscn"
	if not ResourceLoader.exists(stick_path) or not ResourceLoader.exists(look_path):
		push_warning("mobile_controls: thumbstick addon scenes missing — touch move/look disabled")
		return
	var stick_ps: PackedScene = load(stick_path)
	var look_ps: PackedScene = load(look_path)
	if stick_ps == null or look_ps == null:
		push_warning("mobile_controls: failed to load thumbstick scenes")
		return
	var stick = stick_ps.instantiate()
	stick.name = "MoveStick"
	add_child(stick)
	stick.anchor_left = 0.0
	stick.anchor_right = 0.5
	stick.anchor_top = 0.0
	stick.anchor_bottom = 1.0
	if stick.has_signal("on_trigger"):
		stick.on_trigger.connect(func(a):
			if player and is_instance_valid(player) and a != null:
				# addon: up = -y; player: +y = forward
				var v = a.input_v if "input_v" in a else Vector2.ZERO
				player.touch_move = Vector2(v.x, -v.y))
	if stick.has_signal("on_released"):
		stick.on_released.connect(func(_a):
			if player and is_instance_valid(player):
				player.touch_move = Vector2.ZERO)
	var look = look_ps.instantiate()
	look.name = "LookArea"
	add_child(look)
	look.anchor_left = 0.5
	look.anchor_right = 1.0
	look.anchor_top = 0.0
	look.anchor_bottom = 1.0
	if look.has_signal("on_touch_pressed"):
		look.on_touch_pressed.connect(func(a):
			if a != null and "finger_index" in a and "pressed_position" in a:
				_last_drag[a.finger_index] = a.pressed_position)
	if look.has_signal("on_touch_dragged"):
		look.on_touch_dragged.connect(func(a):
			if a == null or not ("finger_index" in a):
				return
			if player and is_instance_valid(player) and _last_drag.has(a.finger_index):
				var pos = a.drag_pos if "drag_pos" in a else a.pressed_position
				player.touch_look += pos - _last_drag[a.finger_index]
			if "pressed_position" in a:
				_last_drag[a.finger_index] = a.pressed_position)
	if look.has_signal("on_touch_released"):
		look.on_touch_released.connect(func(a):
			if a != null and "finger_index" in a:
				_last_drag.erase(a.finger_index))
