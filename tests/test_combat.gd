extends TestBase
## Unit tests for the pure combat math (tuning passed explicitly, as Cfg does).


func test_heal_on_damage() -> void:
	assert_near(CombatLogic.heal_on_damage(50.0, 10.0, 0.8, 100.0), 58.0, 0.001, "damage heals by factor")
	assert_near(CombatLogic.heal_on_damage(99.0, 100.0, 0.8, 100.0), 100.0, 0.001, "clamped at max")
	assert_near(CombatLogic.heal_on_damage(10.0, 10.0, 0.0, 100.0), 10.0, 0.001, "zero factor, zero heal")
	assert_near(CombatLogic.heal_on_damage(50.0, 15.0, 1.0, 100.0), 65.0, 0.001, "parry-style full bonus")


func test_ranks() -> void:
	assert_eq(CombatLogic.rank_for_points(0.0), "D")
	assert_eq(CombatLogic.rank_for_points(40.0), "C")
	assert_eq(CombatLogic.rank_for_points(280.0), "S")
	assert_eq(CombatLogic.rank_for_points(550.0), "SSS")
	assert_eq(CombatLogic.rank_for_points(-5.0), "D", "never below D")
	# custom thresholds (designer-editable)
	assert_eq(CombatLogic.rank_for_points(10.0, [0.0, 10.0], ["X", "Y"]), "Y")


func test_decay() -> void:
	assert_gt(CombatLogic.decay_rate(500.0), CombatLogic.decay_rate(10.0), "higher ranks decay faster")
	assert_near(CombatLogic.decay_rate(0.0, 6.0, 0.04), 6.0, 0.001)


func test_on_hurt() -> void:
	assert_near(CombatLogic.on_hurt(100.0), 50.0, 0.001, "hurt halves style")


func test_parry_window() -> void:
	assert_true(CombatLogic.parry_active(0.0, 0.22), "active on press frame")
	assert_true(CombatLogic.parry_active(0.2, 0.22), "inside window")
	assert_false(CombatLogic.parry_active(0.3, 0.22), "outside window")
	assert_false(CombatLogic.parry_active(-1.0, 0.22), "not pressed")
	assert_true(CombatLogic.parry_active(0.5, 0.5), "designer can widen the window")


func test_nearest_targets() -> void:
	var parent := Node3D.new()
	runner.root.add_child(parent)
	var a := Node3D.new()
	a.position = Vector3(5.0, 0.0, 0.0)
	var b := Node3D.new()
	b.position = Vector3(1.0, 0.0, 0.0)
	var c := Node3D.new()
	c.position = Vector3(9.0, 0.0, 0.0)
	parent.add_child(a)
	parent.add_child(b)
	parent.add_child(c)
	var got := CombatLogic.nearest_targets(Vector3.ZERO, [a, b, c], 2)
	assert_eq(got.size(), 2, "respects count")
	assert_true(got[0] == b and got[1] == a, "sorted nearest first")
	assert_eq(CombatLogic.nearest_targets(Vector3.ZERO, [a, b, c], 10).size(), 3, "count capped by pool")
	parent.free()
