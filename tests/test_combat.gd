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


func test_apply_headshot() -> void:
	assert_near(CombatLogic.apply_headshot(34.0, 2.0, true), 68.0, 0.001, "headshot doubles")
	assert_near(CombatLogic.apply_headshot(34.0, 2.0, false), 34.0, 0.001, "body shot unchanged")
	assert_near(CombatLogic.apply_headshot(10.0, 1.0, true), 10.0, 0.001, "mult 1 is a no-op")
	assert_near(CombatLogic.apply_headshot(0.0, 2.0, true), 0.0, 0.001, "zero stays zero")


func test_knockback() -> void:
	assert_near(CombatLogic.knockback(20.0, 0.35), 7.0, 0.001, "damage * scale")
	assert_near(CombatLogic.knockback(1000.0, 0.35, 9.0), 9.0, 0.001, "capped")
	assert_near(CombatLogic.knockback(-5.0, 0.35), 0.0, 0.001, "negative damage cannot pull")
	assert_near(CombatLogic.knockback(10.0, 0.0), 0.0, 0.001, "zero scale, no push")


func test_projectile_hits() -> void:
	var t := Vector3(0.0, 0.0, 0.0)
	assert_true(CombatLogic.projectile_hits(Vector3(0.2, 0.8, 0.0), t, 0.73), "inside combined radius")
	assert_false(CombatLogic.projectile_hits(Vector3(5.0, 0.8, 0.0), t, 0.73), "far away misses")
	# Vertical: the player is a capsule, so a round at chest height connects
	# while one far above the head does not.
	assert_true(CombatLogic.projectile_hits(Vector3(0.0, 0.7, 0.0), t, 0.30), "chest height hits")
	assert_false(CombatLogic.projectile_hits(Vector3(0.0, 40.0, 0.0), t, 0.30), "above head misses")
	assert_false(CombatLogic.projectile_hits(Vector3(0.0, -40.0, 0.0), t, 0.30), "far below misses")


func test_volley_dirs_single_is_centered() -> void:
	var dirs := CombatLogic.volley_dirs(Vector3(0.0, 0.0, -1.0), 1, 0.22)
	assert_eq(float(dirs.size()), 1.0, "one direction requested")
	assert_near((dirs[0] as Vector3).z, -1.0, 0.001, "single shot goes straight")
	assert_near((dirs[0] as Vector3).x, 0.0, 0.001, "no lateral drift")


func test_volley_dirs_fan_is_symmetric() -> void:
	var dirs := CombatLogic.volley_dirs(Vector3(0.0, 0.0, -1.0), 3, 0.22)
	assert_eq(float(dirs.size()), 3.0, "three directions")
	assert_near((dirs[1] as Vector3).z, -1.0, 0.001, "middle shot stays centred")
	assert_near((dirs[0] as Vector3).x, -(dirs[2] as Vector3).x, 0.001, "outer shots mirror")
	assert_lt((dirs[0] as Vector3).x, 0.0, "first veers one way")
	assert_gt((dirs[2] as Vector3).x, 0.0, "last veers the other")


func test_volley_dirs_are_normalized_and_flat() -> void:
	for count in [1, 2, 3, 5]:
		for d in CombatLogic.volley_dirs(Vector3(0.3, 0.0, -0.9), count, 0.4):
			var v: Vector3 = d
			assert_near(v.length(), 1.0, 0.001, "unit length")
			assert_near(v.y, 0.0, 0.001, "volley stays on the ground plane")


func test_volley_dirs_edge_cases() -> void:
	assert_eq(float(CombatLogic.volley_dirs(Vector3.FORWARD, 0, 0.2).size()), 0.0, "zero count")
	assert_eq(float(CombatLogic.volley_dirs(Vector3.FORWARD, -3, 0.2).size()), 0.0, "negative count")
	# A degenerate (straight-up) aim must still produce a usable direction.
	var dirs := CombatLogic.volley_dirs(Vector3(0.0, 1.0, 0.0), 3, 0.22)
	assert_eq(float(dirs.size()), 3.0, "degenerate aim still fans out")
	assert_near((dirs[0] as Vector3).length(), 1.0, 0.001, "and stays normalized")
