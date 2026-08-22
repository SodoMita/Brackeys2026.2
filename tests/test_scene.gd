extends TestBase
## Integration tests: instantiate the real main scene headless and exercise it.

const MAIN_SCENE := "res://scenes/main.tscn"


func test_scene_loads() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	assert_true(packed != null, "main scene resource loads")
	var scene: Node3D = packed.instantiate()
	assert_true(scene != null, "main scene instantiates")
	scene.free()


func test_scene_bootstraps_world() -> void:
	var scene: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_to_tree(scene)
	# _ready has run; the world builder should have populated structures.
	assert_true(scene.player != null, "player was built")
	assert_true(scene.cam != null, "camera was built")
	assert_gt(scene.floor_segs.size(), 0.0, "floor segments exist")
	assert_gt(scene.buildings.size(), 0.0, "buildings exist")
	assert_eq(scene.state, scene.State.MENU, "boots into menu")
	scene.queue_free()


func test_spawn_creates_entities() -> void:
	var scene: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_to_tree(scene)
	var before: int = scene.entities.get_child_count()
	scene._spawn_row()
	var after: int = scene.entities.get_child_count()
	assert_gt(after, float(before), "spawning a row adds entities")
	scene.queue_free()


func test_audio_synthesis_size() -> void:
	var scene: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_to_tree(scene)
	var wav: AudioStreamWAV = scene._tone(440.0, 0.1, 0.5)
	assert_true(wav != null, "tone generator returns a stream")
	# 16-bit mono @ 22050 Hz for 0.1s -> ~2205 samples * 2 bytes.
	var expected := int(0.1 * 22050.0) * 2
	assert_near(float(wav.data.size()), float(expected), 4.0, "PCM byte count")
	scene.queue_free()


# --- helpers ---------------------------------------------------------------

func add_child_to_tree(node: Node) -> void:
	# Boot the scene outside the tree: run _ready() directly. Parenting to the
	# tree root is avoided because the runner quits before deferred calls run.
	node._ready()
