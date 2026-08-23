extends TestBase
## Unit tests for the pure combat math.


func test_heal_on_damage() -> void:
	assert_near(CombatLogic.heal_on_damage(50.0, 10.0), 58.0, 0.001, "damage heals 80%")
	assert_near(CombatLogic.heal_on_damage(0.0, 10.0), 8.0, 0.001)
	assert_near(CombatLogic.heal_on_damage(99.0, 100.0), CombatLogic.MAX_HP, 0.001, "clamped at max")
	assert_near(CombatLogic.heal_on_damage(10.0, 0.0), 10.0, 0.001, "zero damage, zero heal")


func test_style_points() -> void:
	assert_gt(CombatLogic.style_points("hit"), 0.0)
	assert_gt(CombatLogic.style_points("headshot"), CombatLogic.style_points("hit"), "headshot worth more")
	assert_gt(CombatLogic.style_points("slide_kill"), 0.0)
	assert_eq(CombatLogic.style_points("not-a-move"), 0.0, "unknown action scores nothing")


func test_ranks() -> void:
	assert_eq(CombatLogic.rank_for_points(0.0), "D")
	assert_eq(CombatLogic.rank_for_points(39.9), "D")
	assert_eq(CombatLogic.rank_for_points(40.0), "C")
	assert_eq(CombatLogic.rank_for_points(280.0), "S")
	assert_eq(CombatLogic.rank_for_points(549.9), "SS")
	assert_eq(CombatLogic.rank_for_points(550.0), "SSS")
	assert_eq(CombatLogic.rank_for_points(-5.0), "D", "never below D")


func test_decay() -> void:
	assert_gt(CombatLogic.decay_rate(500.0), CombatLogic.decay_rate(10.0), "higher ranks decay faster")
	assert_gt(CombatLogic.decay_rate(0.0), 0.0)


func test_on_hurt() -> void:
	assert_near(CombatLogic.on_hurt(100.0), 50.0, 0.001, "hurt halves style")
	assert_near(CombatLogic.on_hurt(0.0), 0.0, 0.001)
