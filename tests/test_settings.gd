extends TestBase
## The `subtitles` option used to be stored and read by nothing. Its consumer
## now hides Dialogic's dialogue-text / name-label nodes; the visibility rule
## (apply_subtitles_to) is exercised directly so the test does not depend on
## the live SceneTree group registry (which is only populated once frames run,
## something the headless runner never does).


func test_subtitles_default_on() -> void:
	Settings.capture_defaults()
	assert_true(bool(Settings.default_value("subtitles")), "subtitles default to visible")


func test_apply_subtitles_hides_dialogue_nodes() -> void:
	var text_box := Label.new()
	var name_label := Label.new()
	Settings.current["subtitles"] = false
	Settings.apply_subtitles_to([text_box, name_label])
	assert_false(text_box.visible, "dialogue text hidden when subtitles off")
	assert_false(name_label.visible, "name label hidden when subtitles off")

	Settings.current["subtitles"] = true
	Settings.apply_subtitles_to([text_box, name_label])
	assert_true(text_box.visible, "dialogue text shown when subtitles on")
	assert_true(name_label.visible, "name label shown when subtitles on")
	text_box.free()
	name_label.free()


func test_apply_subtitles_touches_only_canvas_items() -> void:
	# Group lookups can return plain Nodes; the applier must skip them safely
	# rather than crash on a missing `visible` property.
	var plain := Node.new()
	Settings.current["subtitles"] = false
	Settings.apply_subtitles_to([plain])
	assert_true(true, "non-CanvasItem nodes are skipped safely")
	Settings.current["subtitles"] = true
	plain.free()
