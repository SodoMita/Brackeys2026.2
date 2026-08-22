extends TestBase
## Unit tests for the pure gameplay math (no scene required).


func test_clamp_lane() -> void:
	assert_eq(GameLogic.clamp_lane(-3), 0, "below range clamps to 0")
	assert_eq(GameLogic.clamp_lane(0), 0)
	assert_eq(GameLogic.clamp_lane(1), 1)
	assert_eq(GameLogic.clamp_lane(2), 2)
	assert_eq(GameLogic.clamp_lane(9), 2, "above range clamps to 2")


func test_jump_apex() -> void:
	# v^2 / 2g = 9.8^2 / (2*26) ~= 1.846
	assert_near(GameLogic.jump_apex(9.8, 26.0), 1.846, 0.01)
	assert_eq(GameLogic.jump_apex(0.0, 26.0), 0.0, "no velocity -> no apex")
	assert_eq(GameLogic.jump_apex(9.8, 0.0), 0.0, "no gravity guard")


func test_can_clear_bar() -> void:
	# player_y - radius must exceed bar height (1.0)
	assert_false(GameLogic.can_clear_bar(0.55), "resting on ground cannot clear")
	assert_false(GameLogic.can_clear_bar(1.55), "exactly at threshold cannot clear")
	assert_true(GameLogic.can_clear_bar(1.60), "above threshold clears")


func test_spawn_gap_bounds() -> void:
	for s in [0.0, 16.0, 30.0, 46.0, 999.0]:
		var g := GameLogic.next_spawn_gap(s)
		assert_ge(g, GameLogic.MIN_GAP, "gap >= min at speed %f" % s)
		assert_le(g, GameLogic.MAX_GAP, "gap <= max at speed %f" % s)
	# Gap should shrink as speed rises (within the clamp window).
	assert_gt(GameLogic.next_spawn_gap(16.0), GameLogic.next_spawn_gap(46.0),
		"gap shrinks with speed")


func test_speed_after_time() -> void:
	assert_near(GameLogic.speed_after_time(0.0), GameLogic.START_SPEED, 0.001)
	assert_gt(GameLogic.speed_after_time(10.0), GameLogic.START_SPEED, "accelerates")
	assert_le(GameLogic.speed_after_time(100000.0), GameLogic.MAX_SPEED, "caps at max")
	assert_near(GameLogic.speed_after_time(-5.0), GameLogic.START_SPEED, 0.001,
		"negative time treated as 0")


func test_row_is_passable() -> void:
	assert_true(GameLogic.row_is_passable([]), "empty row passable")
	assert_true(GameLogic.row_is_passable([0]), "one pillar leaves lanes")
	assert_true(GameLogic.row_is_passable([0, 1]), "two pillars leave one lane")
	assert_false(GameLogic.row_is_passable([0, 1, 2]), "all lanes blocked")
	assert_true(GameLogic.row_is_passable([0, 0, 0]), "duplicates still leave lanes")


func test_score_for_distance() -> void:
	assert_eq(GameLogic.score_for_distance(12.9), 12)
	assert_eq(GameLogic.score_for_distance(0.0), 0)
	assert_eq(GameLogic.score_for_distance(-4.0), 0, "never negative")
