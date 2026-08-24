extends TestBase
## Player controller unit/integration tests (headless-safe).


func _make_player() -> CharacterBody3D:
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	add_to_root(p)
	return p


func test_player_inits_with_cfg_hp() -> void:
	var p := _make_player()
	assert_near(float(p.hp), float(Cfg.max_hp), 0.001, "hp from Cfg")
	assert_true(p.cam != null, "camera present")
	assert_true(p.head != null, "head present")
	assert_true(p.muzzle != null, "muzzle light present")
	assert_false(p.dead)
	assert_eq(p.weapon, 0)
	assert_true(bool(p.weapons[0]) and bool(p.weapons[1]))
	assert_false(bool(p.weapons[2]), "nailgun locked by default")


func test_look_clamps_pitch() -> void:
	var p := _make_player()
	p._apply_look(0.5, 10.0)
	assert_le(p.pitch, 1.45)
	p._apply_look(0.0, -20.0)
	assert_ge(p.pitch, -1.45)
	assert_near(p.rotation.y, p.yaw, 0.001)
	assert_near(p.head.rotation.x, p.pitch, 0.001)


func test_parry_window_and_cooldown() -> void:
	var p := _make_player()
	assert_false(p.is_parry_active())
	p.request_parry()
	assert_true(p.is_parry_active(), "active immediately")
	assert_gt(p.parry_cd, 0.0, "cooldown armed")
	p.parry_age = Cfg.parry_active_window + 0.05
	assert_false(p.is_parry_active(), "expired")
	var age_before := p.parry_age
	p.request_parry()
	assert_eq(p.parry_age, age_before, "cooldown blocks")
	p.parry_cd = 0.0
	p.request_parry()
	assert_near(p.parry_age, 0.0, 0.001, "re-armed after cd")


func test_cycle_weapon_respects_ownership() -> void:
	var p := _make_player()
	assert_eq(p.weapon, 0)
	p.cycle_weapon()
	assert_eq(p.weapon, 1, "to shotgun")
	p.cycle_weapon()
	assert_eq(p.weapon, 0, "back to revolver (no nailgun)")
	p.weapons[2] = true
	p.cycle_weapon()
	assert_eq(p.weapon, 1)
	p.cycle_weapon()
	assert_eq(p.weapon, 2, "nailgun now in cycle")
	p.cycle_weapon()
	assert_eq(p.weapon, 0)


func test_take_damage_and_death() -> void:
	var p := _make_player()
	var died := [false]
	p.player_died.connect(func(): died[0] = true)
	p.take_damage(10.0)
	assert_near(float(p.hp), float(Cfg.max_hp) - 10.0, 0.001)
	assert_false(p.dead)
	p.take_damage(9999.0)
	assert_true(p.dead)
	assert_true(died[0], "death signal")
	var hp_after := p.hp
	p.take_damage(50.0)
	assert_eq(p.hp, hp_after)


func test_toss_coin_once() -> void:
	var p := _make_player()
	p.toss_coin()
	assert_true(p.coin != null and is_instance_valid(p.coin), "coin spawned")
	assert_true(p.coin.has_meta("coin"))
	var first = p.coin
	p.toss_coin()
	assert_true(p.coin == first, "second toss ignored while live")
	# coin is parented to root (host); track so cleanup frees it
	if first.get_parent() == runner.root:
		own(first)
	if is_instance_valid(p.coin):
		p.coin.queue_free()
	p.coin = null
	p.dead = true
	p.toss_coin()
	assert_true(p.coin == null, "dead cannot toss")


func test_dash_request_flag() -> void:
	var p := _make_player()
	assert_false(p._want_dash)
	p.request_dash()
	assert_true(p._want_dash)


func test_try_fire_without_world_is_safe() -> void:
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	# Intentionally NOT added to the tree.
	p.try_fire()
	assert_eq(p.fire_cd, 0.0, "no fire without world")
	add_to_root(p)
	p.dead = true
	p.try_fire()
	p.dead = false
	p.disabled = true
	p.try_fire()


func test_gather_move_touch_overrides() -> void:
	var p := _make_player()
	p.touch_move = Vector2(1, 0)
	var m: Vector2 = p._gather_move()
	assert_near(m.x, 1.0, 0.001)
	assert_near(m.y, 0.0, 0.001)
	p.touch_move = Vector2.ZERO
	var m2: Vector2 = p._gather_move()
	assert_near(m2.length(), 0.0, 0.001)


func test_horizontal_speed() -> void:
	var p := _make_player()
	p.velocity = Vector3(3, 9, 4)
	assert_near(p.horizontal_speed(), 5.0, 0.001)


func test_ricochet_with_empty_pool() -> void:
	var p := _make_player()
	p.enemy_pool = null
	p._ricochet(10.0)
	var pool := Node3D.new()
	add_to_root(pool)
	p.enemy_pool = pool
	p._ricochet(10.0)
