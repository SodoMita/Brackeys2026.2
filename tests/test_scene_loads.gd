extends TestBase
## Tests that all .tscn scenes can be parsed and loaded.
## This catches errors like: Parse Error: Expected 4 arguments for constructor (Color with 3 args)
## Previously tests skipped this because main.tscn doesn't instance player.tscn directly.

const REQUIRED_SCENES := [
	"res://scenes/player.tscn",
	"res://scenes/companion.tscn",
	"res://scenes/enemy.tscn",
	"res://scenes/enemies/hound.tscn",
	"res://scenes/enemies/spitter.tscn",
	"res://scenes/enemies/boss.tscn",
	"res://scenes/projectile.tscn",
	"res://scenes/shop_terminal.tscn",
	"res://scenes/level.tscn",
	"res://scenes/hud.tscn",
	"res://scenes/environment.tscn",
	"res://scenes/game.tscn",
	"res://scenes/main.tscn",
	"res://scenes/main_menu.tscn",
	"res://scenes/coin.tscn",
	"res://scenes/spawn_point.tscn",
]

func test_required_scenes_exist() -> void:
	for path in REQUIRED_SCENES:
		assert_true(ResourceLoader.exists(path), "scene file should exist: %s" % path)


func test_required_scenes_load_as_packed_scene() -> void:
	for path in REQUIRED_SCENES:
		if not ResourceLoader.exists(path):
			assert_true(false, "cannot test load, missing: %s" % path)
			continue
		var res = load(path)
		# load() returns null and prints ERROR: Failed loading resource if parse error
		assert_true(res != null, "load() should not return null (parse error?) for %s" % path)
		if res != null:
			assert_true(res is PackedScene, "%s should be PackedScene, got %s" % [path, res.get_class() if res else "null"])


func test_required_scenes_instantiate() -> void:
	for path in REQUIRED_SCENES:
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		if res == null:
			assert_true(false, "cannot instantiate, load failed: %s" % path)
			continue
		if not (res is PackedScene):
			continue
		var ps: PackedScene = res as PackedScene
		var instance = ps.instantiate()
		assert_true(instance != null, "instantiate() should succeed for %s" % path)
		# Check that instance has expected structure, not just empty
		if instance != null:
			assert_true(instance is Node, "%s instance should be Node" % path)
			# Free to avoid leaking in headless runner
			instance.queue_free()


func test_player_scene_has_valid_material() -> void:
	# Specific regression for: res://scenes/player.tscn:10 - Parse Error: Expected 4 arguments for constructor (Color)
	# Color in Godot 4 requires 4 args: Color(r,g,b,a)
	var path := "res://scenes/player.tscn"
	if not ResourceLoader.exists(path):
		assert_true(false, "missing player.tscn")
		return
	var res = load(path)
	assert_true(res != null, "player.tscn must load, check Color() has 4 args")
	if res == null:
		return
	var ps: PackedScene = res as PackedScene
	var inst = ps.instantiate() as CharacterBody3D
	assert_true(inst != null, "player.tscn should instantiate as CharacterBody3D")
	if inst == null:
		return
	# Check that it has Head and Camera as per scene
	var head = inst.get_node_or_null("Head")
	assert_true(head != null, "player.tscn should have Head node (scene-based, not just _init fallback)")
	if head:
		var cam = head.get_node_or_null("Camera3D")
		assert_true(cam != null, "player.tscn Head should have Camera3D")
	# Check GunMesh material
	var gun = head.get_node_or_null("GunMesh") if head else null
	if gun and gun is MeshInstance3D:
		var mesh = (gun as MeshInstance3D).mesh
		if mesh and mesh is BoxMesh:
			var mat = (mesh as BoxMesh).material
			if mat and mat is StandardMaterial3D:
				var col = (mat as StandardMaterial3D).albedo_color
				# Just ensure color is valid (not causing parse error)
				assert_true(col is Color, "GunMesh material color should be valid Color")
	inst.queue_free()


func test_all_scenes_in_scenes_dir_load() -> void:
	# Discover all .tscn in res://scenes and res://scenes/enemies to avoid missing any
	var dirs := ["res://scenes", "res://scenes/enemies"]
	for dir_path in dirs:
		var files = DirAccess.get_files_at(dir_path)
		for fname in files:
			if fname.ends_with(".tscn"):
				var full_path = dir_path.path_join(fname)
				if not ResourceLoader.exists(full_path):
					assert_true(false, "DirAccess found but ResourceLoader missing: %s" % full_path)
				else:
					var res = load(full_path)
					assert_true(res != null, "Failed to load %s - parse error? Check Color() needs 4 args, Transform3D needs correct format, load_steps, missing SubResource" % full_path)
					if res != null:
						assert_true(res is PackedScene, "%s should be PackedScene" % full_path)
