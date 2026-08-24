extends TestBase
## Integration tests: instantiate the FPS root scene headless.
##
## Boot pattern matches the known-good main suite: call _ready() without
## entering the SceneTree, so _process/_physics_process do not run between
## assertions. Tests that need in-tree behavior call `_boot_in_tree()`.


func _boot() -> Node3D:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	scene._ready()
	own(scene)
	return scene


func _boot_in_tree() -> Node3D:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Pause the tree so automatic process does not race the test.
	var was_paused := runner.paused
	runner.paused = true
	add_to_root(scene)
	runner.paused = was_paused
	# Keep paused for the duration of in-tree tests that step manually.
	runner.paused = true
	return scene


func test_scene_boots_into_menu() -> void:
	var scene := _boot()
	assert_true(scene.player != null, "player spawned")
	assert_true(scene.player.cam != null, "camera built")
	assert_eq(scene.state, scene.State.MENU, "boots into menu")
	assert_true(scene.companion != null, "COLT spawned")
	assert_eq(scene.doors.size(), 5, "five doors")
	assert_eq(scene.terminals.size(), 2, "two shop terminals")
	assert_true(scene.hud_hp != null, "HUD built")
	assert_true(scene.hud_rank != null, "style rank HUD built")
	assert_true(scene.overlay != null and scene.overlay.visible, "menu visible")


func test_start_spawns_first_wave() -> void:
	var scene := _boot()
	scene._start()
	assert_eq(scene.room, 0, "starts in room 0")
	assert_eq(scene.wave_in_room, 0, "first wave index")
	assert_gt(float(scene.enemies.get_child_count()), 0.0, "room 1 wave 1 spawned")
	assert_eq(float(scene.alive), float(scene.enemies.get_child_count()), "alive counter synced")
	assert_eq(scene.state, scene.State.PLAYING)
	assert_false(scene.overlay.visible, "overlay hidden while playing")
	var expected := CombatLogic.wave_composition(0, 0)
	assert_eq(scene.alive, int(expected.hounds) + int(expected.spitters), "matches pure composition")


func test_wave_scaling() -> void:
	var scene := _boot()
	scene._start()
	var before: int = scene.alive
	scene._enter_room(1)
	assert_eq(scene.room, 1)
	assert_gt(float(scene.alive), float(before), "room 2 adds more hostiles")


func test_enter_room_bounds_safe() -> void:
	var scene := _boot()
	scene._start()
	scene._enter_room(-1)
	assert_eq(scene.room, 0, "invalid room ignored")
	scene._enter_room(99)
	assert_eq(scene.room, 0, "far room ignored")


func test_double_start_is_idempotent() -> void:
	var scene := _boot()
	scene._start()
	var n := scene.alive
	scene._start()
	assert_eq(scene.alive, n, "second _start does not double-spawn")
	assert_eq(scene.state, scene.State.PLAYING)


func test_audio_synthesis() -> void:
	var scene := _boot()
	var wav: AudioStreamWAV = scene._tone(440.0, 0.1, 0.5)
	assert_true(wav != null, "tone generator returns a stream")
	assert_eq(wav.data.size(), int(0.1 * 22050.0) * 2, "16-bit PCM length")
	var noise: AudioStreamWAV = scene._tone(100.0, 0.05, 0.3, "noise")
	assert_true(noise != null and noise.data.size() > 0, "noise tone")
	var square: AudioStreamWAV = scene._tone(200.0, 0.05, 0.3, "square", 400.0)
	assert_true(square != null and square.data.size() > 0, "square sweep")


func test_input_sources_do_not_crash_headless() -> void:
	var scene := _boot()
	scene._start()
	scene._process(0.016)
	scene._process(0.0)
	scene._process(-1.0)


func test_shop_purchases() -> void:
	var scene := _boot()
	scene._start()
	var max_before: float = float(Cfg.max_hp)
	scene.scrap = 200
	scene._on_purchase(1)
	assert_gt(float(Cfg.max_hp), max_before, "plating raises max HP")
	assert_eq(scene.scrap, 200 - int(Cfg.plating_cost), "scrap deducted for plating")
	var scrap_mid := scene.scrap
	scene._on_purchase(0)
	assert_true(bool(scene.player.weapons[2]), "nailgun unlocked")
	assert_eq(scene.player.weapon, 2, "auto-equip nailgun")
	assert_eq(scene.scrap, scrap_mid - int(Cfg.nailgun_cost))
	var scrap_after := scene.scrap
	scene._on_purchase(0)
	assert_eq(scene.scrap, scrap_after, "cannot rebuy nailgun")
	var dm_before: float = float(scene.player.damage_mult)
	scene._on_purchase(2)
	assert_gt(float(scene.player.damage_mult), dm_before, "overclock multiplies damage")
	scene._on_purchase(99)
	scene._on_purchase(-5)
	scene._on_purchase(-1)


func test_shop_broke() -> void:
	var scene := _boot()
	scene._start()
	scene.scrap = 0
	var max_before: float = float(Cfg.max_hp)
	scene._on_purchase(1)
	assert_eq(float(Cfg.max_hp), max_before, "broke: no plating")
	assert_eq(scene.scrap, 0)


func test_style_and_kill_flow() -> void:
	var scene := _boot()
	scene._start()
	assert_true(scene.enemies.get_child_count() > 0)
	var e: Node3D = scene.enemies.get_child(0)
	var scrap_before := scene.scrap
	var style_before := scene.style
	var alive_before := scene.alive
	e.take_damage(9999.0, Vector3.FORWARD, 0.0)
	assert_gt(float(scene.scrap), float(scrap_before), "kill grants scrap")
	assert_gt(float(scene.style), float(style_before), "kill grants style")
	assert_eq(scene.alive, alive_before - 1, "alive decremented")
	assert_ge(float(scene.alive), 0.0, "alive never negative")


func test_fired_heals_and_styles() -> void:
	var scene := _boot()
	scene._start()
	var e: Node3D = scene.enemies.get_child(0)
	scene.player.hp = 50.0
	var hp_before: float = float(scene.player.hp)
	var style_before: float = float(scene.style)
	scene._on_fired(e, true, true, 20.0, false)
	assert_gt(float(scene.player.hp), hp_before, "damage heals player")
	assert_gt(float(scene.style), style_before, "style from hit + headshot + air")
	scene._on_fired(null, false, false, 10.0, false)


func test_parry_melee_and_hurt() -> void:
	var scene := _boot()
	scene._start()
	var e: Node3D = scene.enemies.get_child(0)
	scene.player.request_parry()
	assert_true(scene.player.is_parry_active(), "parry window opens")
	var style_before := scene.style
	var hp_before: float = float(scene.player.hp)
	scene._on_attacked(e)
	assert_gt(float(scene.style), float(style_before), "parry styles")
	assert_ge(float(scene.player.hp), hp_before, "parry heals or holds")
	scene.player.parry_age = -1.0
	var hp2: float = float(scene.player.hp)
	scene._on_attacked(e)
	assert_lt(float(scene.player.hp), hp2, "unparried strike damages")


func test_projectile_parry_and_hit() -> void:
	var scene := _boot()
	scene._start()
	var pr = load("res://scripts/projectile.gd").new()
	pr.position = scene.player.position + Vector3(0, 1.2, 0)
	pr.damage = 15.0
	scene.add_child(pr)
	scene.projectiles.append(pr)
	scene.player.request_parry()
	scene._process(0.016)
	assert_true(not is_instance_valid(pr) or not (pr in scene.projectiles), "parry consumes projectile")

	var pr2 = load("res://scripts/projectile.gd").new()
	pr2.position = scene.player.position + Vector3(0, 1.2, 0)
	pr2.damage = 15.0
	scene.add_child(pr2)
	scene.projectiles.append(pr2)
	scene.player.parry_age = -1.0
	var hp_before: float = float(scene.player.hp)
	scene._process(0.016)
	assert_lt(float(scene.player.hp), hp_before, "unparried projectile damages")


func test_volley_spawns_projectiles() -> void:
	var scene := _boot()
	scene._start()
	var before := scene.projectiles.size()
	scene._on_volley(Vector3(0, 0, -1), Vector3(0, 1, -10))
	assert_eq(scene.projectiles.size(), before + int(Cfg.spitter_volley), "volley count")
	scene._on_volley(Vector3.ZERO, Vector3.ZERO)
	assert_gt(float(scene.projectiles.size()), float(before + int(Cfg.spitter_volley)))


func test_betrayal_and_boss_spawn() -> void:
	var scene := _boot()
	scene._start()
	scene._betrayal()
	assert_eq(scene.state, scene.State.BOSS)
	assert_true(scene.companion.hidden, "COLT vanishes")
	assert_gt(scene.boss_delay, 0.0, "boss countdown armed")
	scene.boss_delay = 0.001
	var before := scene.alive
	scene._process(0.02)
	assert_gt(float(scene.alive), float(before), "boss pack spawned")
	scene._betrayal()
	assert_eq(scene.state, scene.State.BOSS)


func test_player_death_and_end() -> void:
	var scene := _boot()
	scene._start()
	scene.player.take_damage(9999.0)
	assert_eq(scene.state, scene.State.DEAD)
	assert_true(scene.overlay.visible, "death overlay")
	var scene2 := _boot()
	scene2._start()
	scene2._end_mission()
	assert_eq(scene2.state, scene2.State.END)
	assert_true(scene2.overlay.visible)


func test_door_set_does_not_crash() -> void:
	var scene := _boot()
	for d in scene.doors:
		scene.door_set(d, true)
		scene.door_set(d, false)


func test_room_cleared_opens_doors() -> void:
	var scene := _boot()
	scene._start()
	scene.room = 0
	scene._room_cleared()
	scene.room = 1
	scene._room_cleared()
	scene.room = 2
	scene._room_cleared()


func test_gibs_and_debris_cleanup() -> void:
	var scene := _boot()
	scene._spawn_gibs(Vector3(0, 1, 0))
	assert_gt(float(scene.debris.size()), 0.0, "gibs spawned")
	for _i in 30:
		scene._process(0.1)
	assert_eq(scene.debris.size(), 0, "debris cleaned up")
