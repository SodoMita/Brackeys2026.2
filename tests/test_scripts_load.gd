extends TestBase
## Smoke tests: every gameplay script must parse, instantiate, and expose
## the methods the rest of the game calls. Catches rename/signature breaks.


const GAMEPLAY_SCRIPTS := [
	"res://scripts/combat_logic.gd",
	"res://scripts/game_config.gd",
	"res://scripts/game.gd",
	"res://scripts/player.gd",
	"res://scripts/enemy.gd",
	"res://scripts/companion.gd",
	"res://scripts/projectile.gd",
	"res://scripts/shop_terminal.gd",
	"res://scripts/sprite_lib.gd",
	"res://scripts/touch_controls.gd",
	"res://scripts/mobile_controls.gd",
]


func test_all_gameplay_scripts_load() -> void:
	for path in GAMEPLAY_SCRIPTS:
		assert_true(ResourceLoader.exists(path), "exists %s" % path)
		var scr = load(path)
		assert_true(scr != null, "loads %s" % path)
		assert_true(scr is GDScript, "is GDScript %s" % path)


func test_main_scene_loads() -> void:
	assert_true(ResourceLoader.exists("res://scenes/main.tscn"))
	var ps: PackedScene = load("res://scenes/main.tscn")
	assert_true(ps != null)
	var n := ps.instantiate()
	assert_true(n != null)
	assert_true(n.get_script() != null, "main has game.gd")
	n.free()


func test_cfg_autoload_present() -> void:
	var cfg := runner.root.get_node_or_null("Cfg")
	assert_true(cfg != null, "Cfg autoload registered")
	if cfg:
		assert_has_method(cfg, "heal_on_damage")
		assert_has_method(cfg, "rank_for_points")
		assert_has_method(cfg, "decay_rate")
		assert_gt(float(cfg.max_hp), 0.0)
		assert_gt(float(cfg.revolver_damage), 0.0)
		assert_gt(float(cfg.enemy_hp), 0.0)
		assert_gt(float(cfg.parry_active_window), 0.0)
		assert_gt(float(cfg.boss_hp), 0.0)
		assert_ge(float(cfg.ranks.size()), 1.0)
		assert_eq(cfg.ranks.size(), cfg.rank_thresholds.size())


func test_combat_logic_static_api() -> void:
	assert_near(CombatLogic.heal_on_damage(50.0, 10.0, 0.8, 100.0), 58.0, 0.001)
	assert_eq(CombatLogic.rank_for_points(0.0), "D")
	assert_gt(CombatLogic.decay_rate(10.0), 0.0)
	assert_near(CombatLogic.on_hurt(20.0), 10.0, 0.001)
	assert_true(CombatLogic.parry_active(0.0, 0.2))
	assert_eq(CombatLogic.nearest_targets(Vector3.ZERO, [], 3).size(), 0)
	var w: Dictionary = CombatLogic.wave_composition(0, 0)
	assert_true(w.has("hounds") and w.has("spitters"))
	var r: Dictionary = CombatLogic.apply_purchase(
			1, 100, 100.0, 100.0, 1.0, [true, true, false], [60, 40, 50], 25.0, 1.15)
	assert_true(bool(r.ok))


func test_player_public_api() -> void:
	var p = load("res://scripts/player.gd").new()
	add_to_root(p)
	for m in ["request_dash", "request_parry", "is_parry_active", "cycle_weapon",
			"toss_coin", "try_fire", "take_damage", "horizontal_speed"]:
		assert_has_method(p, m, "player.%s" % m)
	assert_true(p.has_signal("fired"))
	assert_true(p.has_signal("player_died"))
	assert_true(p.has_signal("parried"))
	assert_true(p.has_signal("dashed"))
	assert_true(p.has_signal("slid"))
	assert_true(p.has_signal("coin_tossed"))


func test_enemy_public_api() -> void:
	var e = load("res://scripts/enemy.gd").new()
	add_to_root(e)
	for m in ["take_damage", "stagger", "horizontal_speed_v"]:
		assert_has_method(e, m, "enemy.%s" % m)
	assert_true(e.has_signal("died"))
	assert_true(e.has_signal("windup"))
	assert_true(e.has_signal("attacked"))
	assert_true(e.has_signal("volley"))


func test_companion_public_api() -> void:
	var c = load("res://scripts/companion.gd").new()
	add_to_root(c)
	assert_has_method(c, "vanish")
	assert_true(c.has_signal("shot"))


func test_shop_public_api() -> void:
	var s = load("res://scripts/shop_terminal.gd").new()
	add_to_root(s)
	assert_has_method(s, "setup_ui")
	assert_has_method(s, "refresh_panel")
	assert_has_method(s, "close")
	assert_true(s.has_signal("purchase_requested"))


func test_dialogue_files_exist() -> void:
	for path in [
		"res://dialogue/intro.dtl",
		"res://dialogue/quip1.dtl",
		"res://dialogue/betrayal.dtl",
		"res://dialogue/ending.dtl",
	]:
		assert_true(FileAccess.file_exists(path), "dialogue %s" % path)


func test_game_constants_sane() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_root(scene)
	assert_eq(scene.ROOMS.size(), 3, "three rooms")
	assert_eq(scene.ROOM_WAVES.size(), 3, "waves per room table")
	assert_eq(scene.DOOR_Z.size(), 5, "five door planes")
	assert_eq(scene.ROOM_WAVES[0], 2)
	assert_eq(scene.ROOM_WAVES[1], 2)
	assert_eq(scene.ROOM_WAVES[2], 3)
	var total := 0
	for w in scene.ROOM_WAVES:
		total += int(w)
	assert_eq(total, 7, "seven waves total")


func test_wave_clear_advances() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_root(scene)
	scene._start()
	assert_eq(scene.wave_in_room, 0)
	var foes: Array = scene.enemies.get_children()
	for e in foes:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999.0, Vector3.FORWARD, 0.0)
	assert_eq(scene.alive, 0, "wave wiped")
	assert_gt(scene.wave_delay, 0.0, "next wave scheduled")
	assert_eq(scene.wave_in_room, 1, "advanced to wave 2")
	scene.wave_delay = 0.001
	scene._process(0.02)
	assert_gt(float(scene.alive), 0.0, "wave 2 spawned")


func test_style_decay_over_time() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_root(scene)
	scene._start()
	scene.style = 100.0
	var before := scene.style
	scene._process(1.0)
	assert_lt(scene.style, before, "style decays while playing")
	assert_ge(scene.style, 0.0, "style never negative")


func test_on_attacked_null_enemy_safe() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_root(scene)
	scene._start()
	scene.player.request_parry()
	scene._on_attacked(null)
	scene.player.parry_age = -1.0
	scene._on_attacked(null)


func test_process_with_freed_projectile() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_to_root(scene)
	scene._start()
	var pr = load("res://scripts/projectile.gd").new()
	scene.add_child(pr)
	scene.projectiles.append(pr)
	pr.free()
	scene._process(0.016)
	assert_true(true, "scrubbed freed projectile")
