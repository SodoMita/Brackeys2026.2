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
	var stick = load("res://addons/thumbstick_plugin/plugin/controllers/normal_joystick.tscn").instantiate()
	stick.name = "MoveStick"
	add_child(stick)
	stick.anchor_left = 0.0
	stick.anchor_right = 0.5
	stick.anchor_top = 0.0
	stick.anchor_bottom = 1.0
	stick.on_trigger.connect(func(a):
		if player:
			# addon: up = -y; player: +y = forward
			player.touch_move = Vector2(a.input_v.x, -a.input_v.y))
	stick.on_released.connect(func(_a):
		if player:
			player.touch_move = Vector2.ZERO)
	var look = load("res://addons/thumbstick_plugin/plugin/controllers/multitouch_controller.tscn").instantiate()
	look.name = "LookArea"
	add_child(look)
	look.anchor_left = 0.5
	look.anchor_right = 1.0
	look.anchor_top = 0.0
	look.anchor_bottom = 1.0
	look.on_touch_pressed.connect(func(a):
		_last_drag[a.finger_index] = a.pressed_position)
	look.on_touch_dragged.connect(func(a):
		if player and _last_drag.has(a.finger_index):
			player.touch_look += a.drag_pos - _last_drag[a.finger_index]
		_last_drag[a.finger_index] = a.pressed_position)
	look.on_touch_released.connect(func(a):
		_last_drag.erase(a.finger_index))
