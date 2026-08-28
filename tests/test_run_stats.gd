extends TestBase
## Unit tests for the per-run scoreboard: scrap, style decay, ranks, purchases.


func _stats() -> RunStats:
	var s := RunStats.new()
	s.configure(6.0, 0.04)
	return s


func test_starts_empty() -> void:
	var s := _stats()
	assert_eq(float(s.scrap), 0.0, "no scrap at start")
	assert_near(s.style, 0.0, 0.001, "no style at start")
	assert_eq(float(s.kills), 0.0, "no kills at start")
	assert_eq(s.rank(), "D", "starts at rank D")


func test_scrap_accumulates_and_floors_at_zero() -> void:
	var s := _stats()
	s.record_kill("hound", 10)
	s.record_kill("spitter", 15)
	assert_eq(float(s.scrap), 25.0, "scrap sums")
	assert_eq(float(s.kills), 2.0, "kills counted")
	s.record_kill("hound", -100)
	assert_eq(float(s.scrap), 0.0, "scrap never goes negative")


func test_boss_kills_tracked_separately() -> void:
	var s := _stats()
	s.record_kill("hound", 10)
	s.record_kill("boss", 100)
	assert_eq(float(s.boss_kills), 1.0, "boss kill counted")
	assert_eq(float(s.kills), 2.0, "total still includes the boss")


func test_style_rank_uses_combat_logic_thresholds() -> void:
	var s := _stats()
	s.add_style(550.0)
	assert_eq(s.rank(), "SSS", "top rank at 550")
	assert_eq(s.rank(), CombatLogic.rank_for_points(s.style), "delegates to CombatLogic")


func test_style_never_negative() -> void:
	var s := _stats()
	s.add_style(-50.0)
	assert_near(s.style, 0.0, 0.001, "clamped at zero")


func test_style_decays_over_time() -> void:
	var s := _stats()
	s.add_style(200.0)
	var before := s.style
	s.tick(1.0)
	assert_lt(s.style, before, "style bleeds off")
	assert_ge(s.style, 0.0, "never below zero")


func test_decay_is_faster_at_high_rank() -> void:
	var low := _stats()
	low.add_style(10.0)
	var high := _stats()
	high.add_style(500.0)
	var low_before := low.style
	var high_before := high.style
	low.tick(1.0)
	high.tick(1.0)
	assert_gt(high_before - high.style, low_before - low.style, "higher rank decays faster")


func test_tick_ignores_non_positive_delta() -> void:
	var s := _stats()
	s.add_style(100.0)
	s.tick(0.0)
	s.tick(-1.0)
	assert_near(s.style, 100.0, 0.001, "no decay on a zero/negative step")


func test_hurt_halves_style() -> void:
	var s := _stats()
	s.add_style(100.0)
	s.on_hurt()
	assert_near(s.style, 50.0, 0.001, "getting hurt halves style")


func test_purchase_affordability() -> void:
	var s := _stats()
	s.scrap = 40
	assert_true(s.can_afford(40), "exact price is affordable")
	assert_false(s.can_afford(41), "one over is not")
	assert_true(s.spend(40), "spend succeeds")
	assert_eq(float(s.scrap), 0.0, "scrap deducted")
	assert_false(s.spend(10), "cannot overspend")


func test_zero_cost_is_free() -> void:
	var s := _stats()
	assert_true(s.can_afford(0), "free upgrade always affordable")
	assert_true(s.spend(0), "free upgrade always applies")


func test_ownership_tracking() -> void:
	var s := _stats()
	assert_false(s.owns(RunStats.Purchase.NAILGUN), "not owned yet")
	s.mark_owned(RunStats.Purchase.NAILGUN)
	assert_true(s.owns(RunStats.Purchase.NAILGUN), "owned after purchase")
	assert_false(s.owns(RunStats.Purchase.OVERCLOCK), "other slots unaffected")


func test_accuracy() -> void:
	var s := _stats()
	assert_near(s.accuracy(), 0.0, 0.001, "no shots, no accuracy (no div by zero)")
	s.record_shot()
	s.record_shot()
	s.record_kill("hound", 10)
	assert_near(s.accuracy(), 0.5, 0.001, "one kill from two shots")


func test_room_clear_counter() -> void:
	var s := _stats()
	s.room_clear()
	s.room_clear()
	assert_eq(float(s.rooms_cleared), 2.0, "rooms counted")
