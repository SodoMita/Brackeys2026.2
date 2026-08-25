extends TestBase
## Dialogic textures were recompressed as WebP; they must load from .webp paths.


const SAMPLES := [
	"res://addons/dialogic/Example Assets/next-indicator/next-indicator.webp",
	"res://addons/dialogic/Modules/Jump/icon_label.webp",
	"res://addons/dialogic/Modules/Jump/icon_jump.webp",
	"res://addons/dialogic/Modules/Audio/icon_music.webp",
	"res://addons/dialogic/Modules/Background/icon.webp",
	"res://addons/dialogic/Editor/HomePage/icon_bg.webp",
	"res://addons/dialogic/Editor/Images/preview_character.webp",
	"res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/preview.webp",
	"res://addons/dialogic/Example Assets/portraits/Antonio/pl5.webp",
	"res://addons/dialogic/Example Assets/portraits/Princess/smile.webp",
]


func test_webp_assets_exist() -> void:
	for path in SAMPLES:
		assert_true(ResourceLoader.exists(path), "missing %s" % path)


func test_old_png_paths_are_gone() -> void:
	for path in SAMPLES:
		var png_path: String = path.trim_suffix(".webp") + ".webp"
		assert_false(ResourceLoader.exists(png_path), "stale png still present: %s" % png_path)


func test_webp_assets_load_as_textures() -> void:
	for path in SAMPLES:
		if not ResourceLoader.exists(path):
			assert_true(false, "cannot load missing %s" % path)
			continue
		var res: Resource = load(path)
		assert_true(res is Texture2D, "%s should load as Texture2D" % path)
		if res is Texture2D:
			var tex: Texture2D = res
			assert_gt(float(tex.get_width()), 0.0, "%s has width" % path)
			assert_gt(float(tex.get_height()), 0.0, "%s has height" % path)


func test_event_icon_convention_prefers_webp() -> void:
	var icon_dir := "res://addons/dialogic/Modules/Background"
	assert_true(ResourceLoader.exists(icon_dir.path_join("icon.webp")), "module icon.webp")
	assert_false(ResourceLoader.exists(icon_dir.path_join("icon.webp")), "module icon.webp removed")
	var icon: Resource = load(icon_dir.path_join("icon.webp"))
	assert_true(icon is Texture2D, "Background icon.webp is a texture")
