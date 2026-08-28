extends TestBase
## Integration tests for CombatDirector — the layer that makes guns actually
## hurt and enemies actually attack. Uses the real player and enemy scenes so
## the signal signatures and take_damage() contracts are exercised for real.

const HOUND := "res://scenes/enemies/hound.tscn"
const SPITTER := "res://scenes/enemies/spitter.tscn"
const PLAYER := "res://scenes/player.tscn"

var _owned: Array = []


func _keep(n: Node) -> Node:
	_owned.append(n)
	return n


func _teardown() -> void:
	for n in _owned:
		if n != null and is_instance_valid(n):
			n.free()
	_owned.clear()


func _player() -> CharacterBody3D:
	return _keep((load(PLAYER) as PackedScene).instantiate())


func _enemy(scene := HOUND) -> Node3D:
	return _keep((load(scene) as PackedScene).instantiate())


func _rig() -> Dictionary:
	var pool := _keep(Node3D.new())
	var p := _player()
	var combat := CombatDirector.new()
	_keep(combat)
	combat.setup(p, pool, RunStats.new())
	return {"combat": combat, "player": p, "pool": pool}


func test_register_gives_the_enemy_a_target() -> void:
	# Without this the whole enemy AI block is dead code — it is gated on
	# `if target and is_instance_valid(target)`.
	var r := _rig()
	var e := _enemy()
	assert_true(e.target == null, "spawned enemy starts with no target")
	r["combat"].register(e)
	assert_eq(e.target, r["player"], "enemy now hunts the player")
	_teardown()


func test_register_is_safe_on_junk() -> void:
	var r := _rig()
	r["combat"].register(null)
	var plain := _keep(Node3D.new())
	r["combat"].register(plain)  # no target / no signals, must not error
	_teardown()


func test_gun_damage_is_applied() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	var before := float(e.hp)
	r["combat"].on_player_fired(e, false, false, 34.0, false)
	assert_lt(float(e.hp), before, "body shot removes hit points")
	assert_near(before - float(e.hp), 34.0, 0.001, "exactly the rolled damage")
	_teardown()


func test_headshot_hits_harder() -> void:
	var r := _rig()
	var body := _enemy()
	var head := _enemy()
	r["combat"].register(body)
	r["combat"].register(head)
	r["combat"].on_player_fired(body, false, false, 34.0, false)
	r["combat"].on_player_fired(head, true, false, 34.0, false)
	assert_gt(float(body.hp), float(head.hp), "headshot leaves less health")
	_teardown()


func test_blood_heals_the_shooter() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	r["player"].hp = 10.0
	r["combat"].on_player_fired(e, false, false, 30.0, false)
	assert_gt(float(r["player"].hp), 10.0, "dealing damage heals")
	_teardown()


func test_heal_is_clamped_at_max() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	r["player"].hp = 99.0
	r["combat"].on_player_fired(e, false, false, 500.0, false)
	assert_le(float(r["player"].hp), CombatDirector._cfg_float("max_hp", 100.0) + 0.001,
		"never overheals past max")
	_teardown()


func test_dead_enemy_takes_no_further_damage() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	e.dead = true
	var before := float(e.hp)
	r["combat"].on_player_fired(e, false, false, 34.0, false)
	assert_near(float(e.hp), before, 0.001, "overkill on a corpse is ignored")
	_teardown()


func test_firing_at_nothing_is_safe() -> void:
	var r := _rig()
	r["combat"].on_player_fired(null, true, true, 34.0, true)
	var plain := _keep(Node3D.new())
	r["combat"].on_player_fired(plain, false, false, 34.0, false)  # no take_damage
	_teardown()


func test_melee_strike_hurts_the_player() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	var before := float(r["player"].hp)
	r["combat"]._on_enemy_attacked(e)
	assert_lt(float(r["player"].hp), before, "an unparried strike lands")
	_teardown()


func test_melee_strike_costs_style() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	r["combat"].stats.add_style(100.0)
	r["combat"]._on_enemy_attacked(e)
	assert_lt(r["combat"].stats.style, 100.0, "getting hit decays the meter")
	_teardown()


func test_parry_staggers_instead_of_hurting() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	var before := float(r["player"].hp)
	r["player"].parry_age = 0.0  # inside the active window
	r["combat"]._on_enemy_attacked(e)
	assert_gt(float(e.stagger_t), 0.0, "enemy is staggered")
	assert_ge(float(r["player"].hp), before, "player takes no damage")
	_teardown()


func test_parry_reports_a_landed_parry() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	var count := [0]
	r["player"].parried.connect(func(): count[0] += 1)
	r["player"].parry_age = 0.0
	r["combat"]._on_enemy_attacked(e)
	assert_eq(float(count[0]), 1.0, "player.gd arms the window but never emits")
	_teardown()


func test_volley_spawns_configured_shot_count() -> void:
	var r := _rig()
	var n := CombatDirector._cfg_int("spitter_volley", 3)
	r["combat"]._on_enemy_volley(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, -5.0))
	assert_eq(float(r["pool"].get_child_count()), float(n), "one projectile per volley slot")
	assert_eq(float(r["combat"]._projectiles.size()), float(n), "all tracked for hit tests")
	_teardown()


func test_projectiles_are_aimed_and_armed() -> void:
	var r := _rig()
	r["combat"]._on_enemy_volley(Vector3(0.0, 0.0, -1.0), Vector3.ZERO)
	for c in r["pool"].get_children():
		var v: Vector3 = c.vel
		assert_gt(v.length(), 0.0, "projectile has velocity")
		assert_gt(float(c.damage), 0.0, "projectile carries damage")
	_teardown()


func test_volley_without_a_pool_is_safe() -> void:
	var combat := CombatDirector.new()
	_keep(combat)
	combat.setup(_player(), null, null)
	combat._on_enemy_volley(Vector3.FORWARD, Vector3.ZERO)
	assert_eq(float(combat._projectiles.size()), 0.0, "nothing spawned")
	_teardown()


func test_consume_damages_the_player() -> void:
	var r := _rig()
	var before := float(r["player"].hp)
	r["combat"]._on_projectile_consumed(Vector3.ZERO, false, null)
	assert_lt(float(r["player"].hp), before, "an unparried round lands")
	_teardown()


func test_consume_while_parrying_is_free() -> void:
	var r := _rig()
	var before := float(r["player"].hp)
	r["combat"]._on_projectile_consumed(Vector3.ZERO, true, null)
	assert_ge(float(r["player"].hp), before, "parried round does no damage")
	_teardown()


func test_hit_test_matches_the_projectile_rule() -> void:
	var r := _rig()
	var proj := _keep(Node3D.new())
	proj.position = r["player"].position + Vector3(0.2, 0.8, 0.0)
	assert_true(r["combat"]._hits_player(proj), "a round at the body connects")
	var far := _keep(Node3D.new())
	far.position = r["player"].position + Vector3(30.0, 0.0, 0.0)
	assert_false(r["combat"]._hits_player(far), "a distant round does not")
	_teardown()


func test_player_hit_signal_carries_the_amount() -> void:
	var r := _rig()
	var e := _enemy()
	r["combat"].register(e)
	var got := [-1.0]
	r["combat"].player_hit.connect(func(a: float): got[0] = a)
	r["combat"]._on_enemy_attacked(e)
	assert_gt(got[0], 0.0, "host learns how hard the player was hit")
	_teardown()


func test_parried_round_reflects_at_the_nearest_enemy() -> void:
	var r := _rig()
	var e := _enemy()
	r["pool"].add_child(e)
	e.position = Vector3(0.0, 0.0, 5.0)
	var combat: CombatDirector = r["combat"]
	var proj: Node3D = combat._spawn_projectile(
		Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, -3.0))
	assert_true(proj != null, "volley spawns a round")
	combat._on_projectile_consumed(Vector3.ZERO, true, proj)
	assert_true(bool(proj.get("reflected")), "parried round is reflected")
	assert_true(proj.vel.z > 0.0, "reflected round flies at the enemy")
	assert_true(combat._projectiles.has(proj), "reflected round stays tracked")
	proj.position = e.position + Vector3(0.0, 1.0, 0.0)
	var before := float(e.hp)
	combat._physics_process(0.1)
	assert_lt(float(e.hp), before, "reflected round damages the enemy")
	assert_false(combat._projectiles.has(proj), "spent reflected round is untracked")
	_teardown()


func test_reflected_round_expiry_never_hurts_the_player() -> void:
	var r := _rig()
	var combat: CombatDirector = r["combat"]
	var proj: Node3D = combat._spawn_projectile(Vector3.FORWARD, Vector3(0.0, 1.0, -3.0))
	proj.set("reflected", true)
	var before := float(r["player"].hp)
	combat._on_projectile_consumed(Vector3.ZERO, false, proj)
	assert_ge(float(r["player"].hp), before, "expired reflected round is harmless")
	assert_false(combat._projectiles.has(proj), "expired reflected round is untracked")
	_teardown()


func test_parried_round_without_enemies_is_consumed() -> void:
	var r := _rig()
	var combat: CombatDirector = r["combat"]
	var proj: Node3D = combat._spawn_projectile(Vector3.FORWARD, Vector3(0.0, 1.0, -3.0))
	var before := float(r["player"].hp)
	combat._on_projectile_consumed(Vector3.ZERO, true, proj)
	assert_ge(float(r["player"].hp), before, "parry still costs nothing")
	assert_false(bool(proj.get("reflected")), "no enemy to reflect at")
	assert_false(combat._projectiles.has(proj), "unreflected round is untracked")
	_teardown()


func test_expired_round_far_from_the_player_is_a_dodge() -> void:
	# Regression: every expired round used to damage the player wherever it
	# was, so dodged volleys still hurt at the far end of the arena.
	var r := _rig()
	var combat: CombatDirector = r["combat"]
	var proj: Node3D = combat._spawn_projectile(Vector3.FORWARD, Vector3(0.0, 1.0, -30.0))
	var before := float(r["player"].hp)
	combat._on_projectile_consumed(Vector3.ZERO, false, proj)
	assert_ge(float(r["player"].hp), before, "a distant expired round deals no damage")
	assert_false(combat._projectiles.has(proj), "dodged round is untracked")
	_teardown()


func test_expired_round_on_top_of_the_player_still_lands() -> void:
	var r := _rig()
	var combat: CombatDirector = r["combat"]
	var proj: Node3D = combat._spawn_projectile(Vector3.FORWARD, Vector3(0.0, 1.0, -30.0))
	proj.position = Vector3(0.2, 0.8, 0.0)  # inside the player's capsule
	var before := float(r["player"].hp)
	combat._on_projectile_consumed(Vector3.ZERO, false, proj)
	assert_lt(float(r["player"].hp), before, "expiring inside the player still hurts")
	_teardown()
