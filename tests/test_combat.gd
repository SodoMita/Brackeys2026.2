extends TestBase
## Unit tests for the pure combat math (tuning passed explicitly, as Cfg does).


func test_heal_on_damage() -> void:
	assert_near(CombatLogic.heal_on_damage(50.0, 10.0, 0.8, 100.0), 58.0, 0.001, "damage heals by factor")
	assert_near(CombatLogic.heal_on_damage(99.0, 100.0, 0.8, 100.0), 100.0, 0.001, "clamped at max")
	assert_near(CombatLogic.heal_on_damage(10.0, 10.0, 0.0, 100.0), 10.0, 0.001, "zero factor, zero heal")
	assert_near(CombatLogic.heal_on_damage(50.0, 15.0, 1.0, 100.0), 65.0, 0.001, "parry-style full bonus")
	assert_near(CombatLogic.heal_on_damage(0.0, 5.0, 0.8, 100.0), 4.0, 0.001, "heal from zero")
	assert_near(CombatLogic.heal_on_damage(100.0, 50.0, 0.8, 100.0), 100.0, 0.001, "already full")


func test_ranks() -> void:
	assert_eq(CombatLogic.rank_for_points(0.0), "D")
	assert_eq(CombatLogic.rank_for_points(40.0), "C")
	assert_eq(CombatLogic.rank_for_points(280.0), "S")
	assert_eq(CombatLogic.rank_for_points(550.0), "SSS")
	assert_eq(CombatLogic.rank_for_points(-5.0), "D", "never below D")
	# custom thresholds (designer-editable)
	assert_eq(CombatLogic.rank_for_points(10.0, [0.0, 10.0], ["X", "Y"]), "Y")
	assert_eq(CombatLogic.rank_for_points(0.0, [], []), "D", "empty ranks safe")
	assert_eq(CombatLogic.rank_for_points(999.0, [0.0], ["ONLY"]), "ONLY", "single rank")
	assert_eq(CombatLogic.rank_for_points(99.9), "B", "just under A")
	assert_eq(CombatLogic.rank_for_points(180.0), "A")
	assert_eq(CombatLogic.rank_for_points(400.0), "SS")


func test_decay() -> void:
	assert_gt(CombatLogic.decay_rate(500.0), CombatLogic.decay_rate(10.0), "higher ranks decay faster")
	assert_near(CombatLogic.decay_rate(0.0, 6.0, 0.04), 6.0, 0.001)
	assert_near(CombatLogic.decay_rate(100.0, 6.0, 0.04), 10.0, 0.001)
	assert_near(CombatLogic.decay_rate(-50.0, 6.0, 0.04), 6.0, 0.001, "negative points still base")


func test_on_hurt() -> void:
	assert_near(CombatLogic.on_hurt(100.0), 50.0, 0.001, "hurt halves style")
	assert_near(CombatLogic.on_hurt(0.0), 0.0, 0.001)
	assert_near(CombatLogic.on_hurt(-10.0), 0.0, 0.001, "negative clamped via maxf")


func test_parry_window() -> void:
	assert_true(CombatLogic.parry_active(0.0, 0.22), "active on press frame")
	assert_true(CombatLogic.parry_active(0.2, 0.22), "inside window")
	assert_false(CombatLogic.parry_active(0.3, 0.22), "outside window")
	assert_false(CombatLogic.parry_active(-1.0, 0.22), "not pressed")
	assert_true(CombatLogic.parry_active(0.5, 0.5), "designer can widen the window")
	assert_false(CombatLogic.parry_active(0.0, -1.0), "negative window never active")


func test_nearest_targets() -> void:
	var parent := Node3D.new()
	add_to_root(parent)
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
	assert_eq(CombatLogic.nearest_targets(Vector3.ZERO, [], 3).size(), 0, "empty pool")
	assert_eq(CombatLogic.nearest_targets(Vector3.ZERO, [a, b, c], 0).size(), 0, "zero count")
	assert_eq(CombatLogic.nearest_targets(Vector3.ZERO, [a, null, b], 5).size(), 2, "nulls filtered")
	parent.queue_free()


func test_wave_composition() -> void:
	var w0 := CombatLogic.wave_composition(0, 0)
	assert_eq(w0.hounds, 3, "room1 wave1 hounds")
	assert_eq(w0.spitters, 0, "room1 wave1 no spitters")
	var w2 := CombatLogic.wave_composition(0, 2)
	assert_eq(w2.hounds, 5)
	assert_eq(w2.spitters, 3, "spitters appear from room+wave >= 2")
	var w_r2 := CombatLogic.wave_composition(1, 0)
	assert_eq(w_r2.hounds, 4)
	assert_eq(w_r2.spitters, 0)
	var w_r2w1 := CombatLogic.wave_composition(1, 1)
	assert_eq(w_r2w1.spitters, 2)
	# negative room/wave should not crash and stay non-negative
	var bad := CombatLogic.wave_composition(-5, -5)
	assert_ge(float(bad.hounds), 0.0)
	assert_ge(float(bad.spitters), 0.0)


func test_apply_purchase() -> void:
	var costs := [60, 40, 50]
	var r := CombatLogic.apply_purchase(1, 100, 100.0, 80.0, 1.0, [true, true, false], costs, 25.0, 1.15)
	assert_true(r.ok, "plating buys")
	assert_eq(r.scrap, 60)
	assert_near(r.max_hp, 125.0, 0.001)
	assert_near(r.hp, 105.0, 0.001)

	var broke := CombatLogic.apply_purchase(0, 10, 100.0, 100.0, 1.0, [true, true, false], costs, 25.0, 1.15)
	assert_false(broke.ok, "not enough scrap")
	assert_eq(broke.reason, "broke")

	var owned := CombatLogic.apply_purchase(0, 100, 100.0, 100.0, 1.0, [true, true, true], costs, 25.0, 1.15)
	assert_false(owned.ok, "already owns nailgun")
	assert_eq(owned.reason, "owned")

	var nail := CombatLogic.apply_purchase(0, 100, 100.0, 100.0, 1.0, [true, true, false], costs, 25.0, 1.15)
	assert_true(nail.ok)
	assert_true(bool(nail.weapons[2]))
	assert_eq(nail.weapon, 2)
	assert_eq(nail.scrap, 40)

	var oc := CombatLogic.apply_purchase(2, 100, 100.0, 100.0, 1.0, [true, true, false], costs, 25.0, 1.15)
	assert_true(oc.ok)
	assert_near(oc.damage_mult, 1.15, 0.001)

	var bad := CombatLogic.apply_purchase(9, 100, 100.0, 100.0, 1.0, [true, true, false], costs, 25.0, 1.15)
	assert_false(bad.ok)
	assert_eq(bad.reason, "bad_item")
