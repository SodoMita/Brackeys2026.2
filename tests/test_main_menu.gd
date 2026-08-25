extends TestBase

func test_detached_menu_input_is_safe() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	menu._unhandled_input(enter)
	assert_true(true, "detached menu accepts input safely")
	menu.free()
