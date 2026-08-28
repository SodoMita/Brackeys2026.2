extends TestBase
## Dialogue plumbing tests.
##
## These exist because of a real regression: Dialogic 2 ships
## DialogicTimelineFormatLoader but never registers it, and the deleted
## game.gd was what registered it at boot. With nothing registered,
## ResourceLoader cannot resolve res://**.dtl, so every timeline in the
## project is unloadable and not one line of dialogue plays — while every
## other test still passes, because nothing else touches a .dtl.
##
## The config script is instantiated directly rather than through the Cfg
## autoload so these run whether or not autoloads are up in the runner. Each
## test frees what it creates and unregisters the loader, so no test leaves
## state behind for the next one.

const CONFIG := "res://scripts/game_config.gd"
const INTRO := "res://dialogue/intro.dtl"
const ENDING := "res://dialogue/ending.dtl"
const QUIP := "res://dialogue/quip1.dtl"


## Create a config node, register the loader, run `body`, then always tear down.
func _with_loader(body: Callable) -> void:
	var cfg: Node = (load(CONFIG) as GDScript).new()
	cfg._register_dtl_loader()
	body.call(cfg)
	cfg._exit_tree()
	cfg.free()


func test_every_authored_timeline_file_exists() -> void:
	# Guard the premise of the rest of this suite.
	assert_true(ResourceLoader.exists(INTRO), "intro.dtl present")
	assert_true(ResourceLoader.exists(ENDING), "ending.dtl present")
	assert_true(ResourceLoader.exists(QUIP), "quip1.dtl present")


func test_registering_the_loader_makes_dtl_loadable() -> void:
	_with_loader(func(_cfg: Node) -> void:
		assert_true(ResourceLoader.exists(INTRO),
			"with the loader registered, ResourceLoader resolves .dtl")
		var timeline: Resource = load(INTRO)
		assert_true(timeline != null, "and the timeline actually loads"))


func test_registration_is_idempotent() -> void:
	_with_loader(func(cfg: Node) -> void:
		var first: ResourceFormatLoader = cfg._dtl_loader
		assert_true(first != null, "registration produced a loader")
		cfg._register_dtl_loader()
		assert_eq(cfg._dtl_loader, first, "second call does not register a duplicate"))


func test_timeline_by_name_resolves_authored_timelines() -> void:
	var script: GDScript = load(CONFIG)
	_with_loader(func(_cfg: Node) -> void:
		assert_true(script.timeline_by_name("intro") != null, "intro resolves")
		assert_true(script.timeline_by_name("quip1") != null, "quip1 resolves")
		assert_true(script.timeline_by_name("ending") != null, "ending resolves"))


func test_timeline_by_name_rejects_unknown_identifiers() -> void:
	var script: GDScript = load(CONFIG)
	_with_loader(func(_cfg: Node) -> void:
		assert_true(script.timeline_by_name("") == null, "empty identifier is null")
		assert_true(script.timeline_by_name("no_such_timeline") == null, "unknown is null"))


func test_defaults_match_authored_content() -> void:
	# The defaults on Cfg must name timelines that actually exist, otherwise
	# the game boots silently dialogue-free.
	var script: GDScript = load(CONFIG)
	_with_loader(func(cfg: Node) -> void:
		for prop in ["intro_timeline_name", "quip_timeline_name", "ending_timeline_name"]:
			var id: String = cfg.get(prop)
			assert_true(not id.is_empty(), "%s has a default" % prop)
			assert_true(script.timeline_by_name(id) != null,
				"%s default '%s' resolves to a real timeline" % [prop, id]))
