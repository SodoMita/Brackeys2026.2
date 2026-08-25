extends TestBase

func test_gameplay_actions_are_available_without_main_menu() -> void:
	# Levels may be launched directly, so player startup must not depend on menu initialization.
	Settings.apply_saved()
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "dash", "slide", "parry", "fire", "coin", "interact"]:
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
