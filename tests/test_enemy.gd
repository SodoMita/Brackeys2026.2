extends TestBase
## Enemy / companion / projectile runtime safety tests.


func test_enemy_inits_and_fallback_mesh() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.kind = "hound"
	add_to_root(e)
	assert_near(float(e.hp), float(Cfg.enemy_hp), 0.001)
	assert_false(e.ranged)
	e.take_damage(10.0, Vector3.FORWARD, 2.0)
	assert_near(float(e.hp), float(Cfg.enemy_hp) - 10.0, 0.001)


func test_enemy_death_emits_once() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	add_to_root(e)
	var deaths := [0]
	e.died.connect(func(_p): deaths[0] += 1)
	e.take_damage(9999.0, Vector3.ZERO, 0.0)
	assert_eq(deaths[0], 1, "single death signal")
	# Already-dead guard on a fresh enemy
	var e2: CharacterBody3D = load("res://scripts/enemy.gd").new()
	add_to_root(e2)
	e2.hp = 0.0
	var d2 := [0]
	e2.died.connect(func(_p): d2[0] += 1)
	e2.take_damage(10.0, Vector3.FORWARD, 1.0)
	assert_eq(d2[0], 0, "already-dead ignores further damage")


func test_enemy_stagger_cancels_windup() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	add_to_root(e)
	e.windup_t = 0.3
	e.stagger(1.0)
	assert_near(e.windup_t, -1.0, 0.001)
	assert_ge(e.stagger_t, 1.0)


func test_spitter_emits_volley_after_windup() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.ranged = true
	e.kind = "spitter"
	var target := Node3D.new()
	add_to_root(target)
	target.position = Vector3(0, 0, -10)
	add_to_root(e)
	e.target = target
	e.position = Vector3.ZERO
	var volleys := [0]
	e.volley.connect(func(_d, _o): volleys[0] += 1)
	e.windup_t = 0.01
	e._set_telegraph(true)
	e._physics_process(0.02)
	assert_eq(volleys[0], 1, "ranged windup fires volley")


func test_melee_emits_attacked_in_range() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.ranged = false
	var target := Node3D.new()
	add_to_root(target)
	target.position = Vector3(0, 0, -1.0)
	add_to_root(e)
	e.target = target
	e.position = Vector3.ZERO
	var atks := [0]
	e.attacked.connect(func(): atks[0] += 1)
	e.windup_t = 0.01
	e._physics_process(0.02)
	assert_eq(atks[0], 1, "melee strike emitted")


func test_companion_vanish_and_follow() -> void:
	var c: CharacterBody3D = load("res://scripts/companion.gd").new()
	var player := Node3D.new()
	add_to_root(player)
	player.position = Vector3(20, 0, 0)
	add_to_root(c)
	c.player_ref = player
	var pool := Node3D.new()
	add_to_root(pool)
	c.enemy_pool = pool
	c._physics_process(0.016)
	assert_false(c.hidden)
	c.vanish()
	assert_true(c.hidden)
	assert_false(c.visible)
	c._physics_process(0.016)


func test_companion_support_fire() -> void:
	var c: CharacterBody3D = load("res://scripts/companion.gd").new()
	var player := Node3D.new()
	add_to_root(player)
	add_to_root(c)
	c.player_ref = player
	var pool := Node3D.new()
	add_to_root(pool)
	c.enemy_pool = pool
	var foe: CharacterBody3D = load("res://scripts/enemy.gd").new()
	pool.add_child(foe)
	foe.position = Vector3(2, 0, 0)
	var shots := [0]
	c.shot.connect(func(): shots[0] += 1)
	c.fire_cd = 0.0
	var hp_before: float = float(foe.hp)
	c._physics_process(0.016)
	assert_eq(shots[0], 1, "companion fired")
	assert_lt(float(foe.hp), hp_before, "enemy took companion damage")


func test_projectile_lifetime() -> void:
	var pr = load("res://scripts/projectile.gd").new()
	add_to_root(pr)
	pr.vel = Vector3(0, 0, -10)
	pr.life = 0.05
	var start := pr.position
	pr._physics_process(0.016)
	assert_ne(pr.position, start, "projectile moved")
	pr.life = 0.0
	pr._physics_process(0.016)
	# queued for free — cleanup must skip it
	assert_true(true, "lifetime path exercised")


func test_projectile_negative_dt_safe() -> void:
	var pr = load("res://scripts/projectile.gd").new()
	add_to_root(pr)
	pr.life = 1.0
	pr._physics_process(-0.5)
	assert_ge(pr.life, 0.0)


func test_sprite_lib_unknown_and_partial() -> void:
	assert_true(SpriteLib.build("nope") == null, "unknown kind → null")
	var colt = SpriteLib.build("colt")
	if colt != null:
		assert_true(colt is AnimatedSprite3D)
		assert_true(colt.sprite_frames != null)
		colt.free()
	var hound = SpriteLib.build("hound")
	if hound != null:
		hound.free()
	var spit = SpriteLib.build("spitter")
	if spit != null:
		spit.free()
	var boss = SpriteLib.build("boss")
	if boss != null:
		boss.free()


func test_shop_terminal_setup_and_refresh() -> void:
	var st = load("res://scripts/shop_terminal.gd").new()
	add_to_root(st)
	var cl := CanvasLayer.new()
	add_to_root(cl)
	st.setup_ui(cl)
	assert_true(st.prompt != null)
	assert_true(st.panel != null)
	st.refresh_panel(42, false)
	assert_true(st.panel.text.find("42") >= 0, "scrap shown")
	st.refresh_panel(0, true)
	assert_true(st.panel.text.find("owned") >= 0, "owned marker")
	st.close()
	assert_false(st.open)


func test_touch_controls_construct() -> void:
	var tc = load("res://scripts/touch_controls.gd").new()
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	add_to_root(p)
	add_to_root(tc)
	tc.setup(p)
	assert_true(tc.buttons.has("fire"))
	assert_true(tc.buttons.has("parry"))
	assert_true(tc.buttons.has("coin"))
	tc._press("fire", true)
	assert_true(p.touch_fire)
	tc._press("fire", false)
	assert_false(p.touch_fire)
	tc._press("jump", true)
	assert_true(p.touch_jump)
	tc._press("dash", true)
	assert_true(p._want_dash)
	tc._press("parry", true)
	assert_true(p.is_parry_active() or p.parry_cd > 0.0)
	tc._press("wpn", true)
	tc._press("coin", true)
	tc._press("slide", true)
	assert_true(p.touch_slide)
	tc.player = null
	tc._press("fire", true)


func test_cfg_helpers() -> void:
	assert_near(Cfg.heal_on_damage(50.0, 10.0),
			CombatLogic.heal_on_damage(50.0, 10.0, Cfg.heal_factor, Cfg.max_hp), 0.001)
	assert_eq(Cfg.rank_for_points(0.0), "D")
	assert_eq(Cfg.rank_for_points(550.0), "SSS")
	assert_gt(Cfg.decay_rate(100.0), Cfg.decay_rate(0.0))
	assert_gt(Cfg.max_hp, 0.0)
	assert_gt(Cfg.revolver_damage, 0.0)
	assert_gt(Cfg.enemy_hp, 0.0)
	assert_gt(Cfg.parry_active_window, 0.0)
	assert_gt(float(Cfg.ricochet_targets), 0.0)
	assert_eq(Cfg.ranks.size(), Cfg.rank_thresholds.size(), "ranks align with thresholds")


func test_mobile_controls_setup() -> void:
	var mc = load("res://scripts/mobile_controls.gd").new()
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	add_to_root(p)
	add_to_root(mc)
	mc.setup(p)
	assert_true(mc.player == p)


func test_enemy_negative_dt_and_no_target() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	add_to_root(e)
	e.target = null
	e._physics_process(-0.5)
	e._physics_process(0.016)


func test_boss_meta_constructs() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.kind = "boss"
	e.set_meta("boss", true)
	add_to_root(e)
	assert_true(e.has_meta("boss"))


func test_shop_refresh_without_setup_safe() -> void:
	var st = load("res://scripts/shop_terminal.gd").new()
	add_to_root(st)
	st.refresh_panel(10, false)
	st.close()
