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
