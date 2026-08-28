extends TestBase
## Integration tests: instantiate the game root scene headless.
## (Rewritten after game.gd was removed — the old suite tested its dead API.)


func _boot() -> Node3D:
	var scene: Node3D = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	return scene


func test_game_scene_structure() -> void:
	var scene := _boot()
	assert_true(scene.get_node_or_null("Player") != null, "player in scene")
	assert_true(scene.get_node_or_null("Companion") != null, "COLT in scene")
	assert_true(scene.get_node_or_null("Enemies") != null, "enemy pool in scene")
	assert_true(scene.get_node_or_null("Level1") != null, "level in scene")
	assert_true(scene.get_node_or_null("HUD") != null, "HUD in scene")
	scene.free()


func test_game_root_wires_references() -> void:
	var scene := _boot()
	scene._ready()
	assert_true(scene.player != null, "root resolved the player")
	assert_true(scene.player.enemy_pool != null, "player got the enemy pool")
	var companion: Node = scene.get_node("Companion")
	assert_eq(companion.player_ref, scene.player, "COLT follows the player")
	assert_true(scene.ui != null, "UIManager created")
	scene.free()


func test_main_scene_instances_game() -> void:
	var scene: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	assert_true(scene.get_node_or_null("Game") != null, "main.tscn wraps game.tscn")
	assert_true(scene.get_node_or_null("Game/Player") != null, "player reachable")
	scene.free()


func test_game_root_builds_the_run_systems() -> void:
	# The piece that was missing after game.gd was deleted: progression,
	# scoreboard, HUD binding and the end-of-run card must all exist.
	var scene := _boot()
	scene._ready()
	assert_true(scene.stats != null, "RunStats created")
	assert_true(scene.director != null, "LevelDirector created")
	assert_true(scene.hud_controller != null, "HUD controller created")
	assert_true(scene.result_screen != null, "result screen created")
	assert_eq(scene.director.level, scene.get_node("Level1"), "director got the level")
	assert_eq(scene.director.enemy_pool, scene.get_node("Enemies"), "director got the pool")
	assert_eq(scene.director.player, scene.player, "director got the player")
	scene.free()


func test_director_collects_authored_level_nodes() -> void:
	# Door sealing itself is covered in test_level_director.gd with stand-ins;
	# here we assert the real level actually feeds the director.
	var scene := _boot()
	scene._ready()
	var level := scene.get_node("Level1")
	assert_eq(float(scene.director._doors.size()), float(level.doors.size()),
		"director picked up every authored door")
	assert_eq(float(scene.director._triggers.size()), float(level.trigger_nodes.size()),
		"director picked up every authored trigger")
	assert_gt(float(scene.director._doors.size()), 0.0, "level has doors")
	assert_gt(float(scene.director._triggers.size()), 0.0, "level has triggers")
	scene.free()


func test_death_ends_the_run() -> void:
	var scene := _boot()
	scene._ready()
	var result := ["pending"]
	scene.run_ended.connect(func(won: bool): result[0] = won)
	scene._on_player_died()
	assert_eq(result[0], false, "dying reports a loss")
	assert_true(scene.result_screen.visible, "result card shown")
	assert_false(scene.result_screen.is_won(), "card is the defeat variant")
	assert_true(scene.player.disabled, "player input released")
	scene.free()


func test_level_complete_ends_the_run() -> void:
	var scene := _boot()
	scene._ready()
	var result := ["pending"]
	scene.run_ended.connect(func(won: bool): result[0] = won)
	scene._on_level_complete()
	assert_eq(result[0], true, "clearing the boss room reports a win")
	assert_true(scene.result_screen.visible or scene._awaiting_ending,
		"either the card shows or the ending dialogue is playing")
	scene.free()


func test_end_of_run_is_idempotent() -> void:
	var scene := _boot()
	scene._ready()
	var count := [0]
	scene.run_ended.connect(func(_w: bool): count[0] += 1)
	scene._on_player_died()
	scene._on_level_complete()
	scene._on_player_died()
	assert_eq(float(count[0]), 1.0, "run ends exactly once")
	scene.free()


func test_scrap_and_style_are_awarded() -> void:
	var scene := _boot()
	scene._ready()
	var enemy: Node3D = (load("res://scenes/enemies/hound.tscn") as PackedScene).instantiate()
	scene.director.enemy_pool.add_child(enemy)
	scene.director._on_enemy_spawned(enemy, 0)
	scene._on_enemy_killed(Vector3.ZERO, enemy)
	assert_gt(float(scene.stats.kills), 0.0, "kill recorded")
	assert_gt(float(scene.stats.scrap), 0.0, "scrap awarded")
	assert_gt(scene.stats.style, 0.0, "style awarded for the kill")
	enemy.free()
	scene.free()


func test_style_events_feed_the_meter() -> void:
	var scene := _boot()
	scene._ready()
	scene._on_player_fired(null, true, false, 10.0, false)
	var headshot: float = float(scene.stats.style)
	assert_gt(headshot, 0.0, "headshot scored")
	scene.stats.style = 0.0
	scene._on_player_parried()
	assert_gt(float(scene.stats.style), headshot, "parry outscores a headshot")
	scene.free()


func test_shop_purchase_spends_scrap() -> void:
	var scene := _boot()
	scene._ready()
	scene.stats.scrap = 1000
	scene._on_purchase(RunStats.Purchase.PLATING)
	assert_lt(float(scene.stats.scrap), 1000.0, "scrap spent")
	assert_true(scene.stats.owns(RunStats.Purchase.PLATING), "purchase recorded")
	var dmg := float(scene.player.damage_mult)
	scene._on_purchase(RunStats.Purchase.OVERCLOCK)
	assert_gt(float(scene.player.damage_mult), dmg, "overclock raises damage")
	scene.free()


func test_purchase_blocked_without_scrap() -> void:
	var scene := _boot()
	scene._ready()
	scene.stats.scrap = 0
	scene._on_purchase(RunStats.Purchase.NAILGUN)
	assert_false(scene.stats.owns(RunStats.Purchase.NAILGUN), "cannot buy with no scrap")
	assert_false(scene.player.weapons[2], "nailgun not granted")
	scene.free()


func test_refresh_request_is_not_a_purchase() -> void:
	var scene := _boot()
	scene._ready()
	scene.stats.scrap = 500
	scene._on_purchase(-1)
	assert_eq(float(scene.stats.scrap), 500.0, "terminal refresh spends nothing")
	scene.free()


func test_hud_labels_are_bound() -> void:
	var scene := _boot()
	scene._ready()
	var hud: CanvasLayer = scene.get_node("HUD")
	var hp: Label = hud.get_node_or_null("HP")
	scene.stats.scrap = 42
	scene.hud_controller._refresh()
	assert_true(hp != null, "HP label exists")
	assert_true(hp.text.length() > 0, "HP label was written")
	var scrap: Label = hud.get_node_or_null("Scrap")
	assert_true(scrap.text.find("42") >= 0, "scrap rendered from RunStats")
	scene.free()
