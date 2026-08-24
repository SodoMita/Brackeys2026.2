extends TestBase
## Entity unit tests using out-of-tree construction (manual _ready / no auto-process).


func test_enemy_damage_and_death() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.kind = "hound"
	# _ready builds mesh fallback; call manually out of tree
	e._ready()
	assert_near(float(e.hp), float(Cfg.enemy_hp), 0.001)
	e.take_damage(10.0, Vector3.FORWARD, 1.0)
	assert_near(float(e.hp), float(Cfg.enemy_hp) - 10.0, 0.001)
	var deaths := [0]
	e.died.connect(func(_p): deaths[0] += 1)
	e.take_damage(9999.0, Vector3.ZERO, 0.0)
	assert_eq(deaths[0], 1)
	# already dead (queued) — further damage no-ops if still valid
	if is_instance_valid(e) and not e.is_queued_for_deletion():
		e.take_damage(1.0, Vector3.FORWARD, 0.0)
	if is_instance_valid(e) and not e.is_queued_for_deletion():
		e.free()


func test_enemy_stagger_and_spitter_volley() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.ranged = true
	e.kind = "spitter"
	e._ready()
	e.windup_t = 0.3
	e.stagger(1.0)
	assert_near(e.windup_t, -1.0, 0.001)
	assert_ge(e.stagger_t, 1.0)

	var target := Node3D.new()
	target.position = Vector3(0, 0, -10)
	e.target = target
	e.position = Vector3.ZERO
	var volleys := [0]
	e.volley.connect(func(_d, _o): volleys[0] += 1)
	e.windup_t = 0.01
	e._physics_process(0.02)
	assert_eq(volleys[0], 1, "spitter volley after windup")
	e.free()
	target.free()


func test_melee_attacked_signal() -> void:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.ranged = false
	e._ready()
	var target := Node3D.new()
	target.position = Vector3(0, 0, -1.0)
	e.target = target
	e.position = Vector3.ZERO
	var atks := [0]
	e.attacked.connect(func(): atks[0] += 1)
	e.windup_t = 0.01
	e._physics_process(0.02)
	assert_eq(atks[0], 1)
	e.free()
	target.free()


func test_companion_vanish() -> void:
	var c: CharacterBody3D = load("res://scripts/companion.gd").new()
	c._ready()
	assert_false(c.hidden)
	c.vanish()
	assert_true(c.hidden)
	assert_false(c.visible)
	c._physics_process(0.016)  # no-op while hidden
	c.free()


func test_projectile_moves_and_expires() -> void:
	var pr = load("res://scripts/projectile.gd").new()
	pr.vel = Vector3(0, 0, -5)
	pr.life = 1.0
	var start := pr.position
	pr._physics_process(0.1)
	assert_ne(pr.position, start)
	pr.life = 0.0
	pr._physics_process(0.01)
	# queued free
	if is_instance_valid(pr) and not pr.is_queued_for_deletion():
		pr.free()


func test_player_api_out_of_tree() -> void:
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	assert_near(float(p.hp), float(Cfg.max_hp), 0.001)
	assert_true(p.cam != null)
	assert_false(p.is_parry_active())
	p.request_parry()
	assert_true(p.is_parry_active())
	p.cycle_weapon()
	assert_eq(p.weapon, 1)
	p.cycle_weapon()
	assert_eq(p.weapon, 0)
	p.weapons[2] = true
	p.cycle_weapon()
	assert_eq(p.weapon, 1)
	p.cycle_weapon()
	assert_eq(p.weapon, 2)
	# try_fire without world is safe
	p.try_fire()
	assert_eq(p.fire_cd, 0.0)
	p.take_damage(10.0)
	assert_near(float(p.hp), float(Cfg.max_hp) - 10.0, 0.001)
	var died := [false]
	p.player_died.connect(func(): died[0] = true)
	p.take_damage(9999.0)
	assert_true(p.dead and died[0])
	p.free()


func test_sprite_lib_unknown() -> void:
	assert_true(SpriteLib.build("nope") == null)
	# known kinds either return null (missing frames) or AnimatedSprite3D
	for k in ["colt", "hound", "spitter", "boss"]:
		var s = SpriteLib.build(k)
		if s != null:
			assert_true(s is AnimatedSprite3D)
			s.free()


func test_shop_terminal_ui() -> void:
	var st = load("res://scripts/shop_terminal.gd").new()
	var cl := CanvasLayer.new()
	st.setup_ui(cl)
	assert_true(st.prompt != null and st.panel != null)
	st.refresh_panel(42, false)
	assert_true(st.panel.text.find("42") >= 0)
	st.refresh_panel(0, true)
	assert_true(st.panel.text.find("owned") >= 0)
	st.close()
	assert_false(st.open)
	# safe before setup
	var st2 = load("res://scripts/shop_terminal.gd").new()
	st2.refresh_panel(1, false)
	st2.close()
	st.free()
	st2.free()
	cl.free()


func test_touch_controls_buttons() -> void:
	var tc = load("res://scripts/touch_controls.gd").new()
	var p: CharacterBody3D = load("res://scripts/player.gd").new()
	tc.setup(p)
	assert_true(tc.buttons.has("fire"))
	assert_true(tc.buttons.has("parry"))
	tc._press("fire", true)
	assert_true(p.touch_fire)
	tc._press("dash", true)
	assert_true(p._want_dash)
	tc._press("parry", true)
	assert_true(p.is_parry_active() or p.parry_cd > 0.0)
	tc.player = null
	tc._press("fire", true)  # null-safe
	tc.free()
	p.free()


func test_cfg_mirrors_combat_logic() -> void:
	assert_near(Cfg.heal_on_damage(50.0, 10.0),
			CombatLogic.heal_on_damage(50.0, 10.0, Cfg.heal_factor, Cfg.max_hp), 0.001)
	assert_eq(Cfg.rank_for_points(0.0), "D")
	assert_eq(Cfg.rank_for_points(550.0), "SSS")
	assert_gt(Cfg.decay_rate(100.0), Cfg.decay_rate(0.0))
	assert_eq(Cfg.ranks.size(), Cfg.rank_thresholds.size())


func test_scripts_load() -> void:
	for path in [
		"res://scripts/combat_logic.gd",
		"res://scripts/game.gd",
		"res://scripts/player.gd",
		"res://scripts/enemy.gd",
		"res://scripts/companion.gd",
		"res://scripts/projectile.gd",
		"res://scripts/shop_terminal.gd",
		"res://scripts/sprite_lib.gd",
		"res://scripts/touch_controls.gd",
		"res://scripts/mobile_controls.gd",
	]:
		assert_true(ResourceLoader.exists(path), path)
		assert_true(load(path) != null, "load " + path)
	for path in [
		"res://dialogue/intro.dtl",
		"res://dialogue/betrayal.dtl",
		"res://dialogue/ending.dtl",
		"res://dialogue/quip1.dtl",
	]:
		assert_true(FileAccess.file_exists(path), path)
