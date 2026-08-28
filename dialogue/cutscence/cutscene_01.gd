extends Control
## Intro cutscene — plays the authored `cutscene_01` timeline, then hands over
## to the game.
##
## This scene used to be orphaned: it started the timeline and then just sat
## there with an empty _process, so nothing ever advanced. It is now the step
## between the main menu and gameplay, and it is defensive on purpose — a
## missing Dialogic autoload or timeline must still get the player into the
## game rather than soft-locking them on a black screen.
##
## Skippable: any key, mouse click or gamepad A/START jumps straight to the
## game, because a repeat player has already seen this.

const NEXT_SCENE := "res://scenes/game.tscn"
const FALLBACK_SCENE := "res://scenes/main.tscn"
const TIMELINE := "cutscene_01"

var _advancing := false
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_hint()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dialogic := _dialogic()
	if dialogic == null:
		_advance.call_deferred()
		return
	if dialogic.has_signal("timeline_ended"):
		dialogic.timeline_ended.connect(_on_timeline_ended)
	if _has_timeline():
		dialogic.call("start", TIMELINE)
		# The layout nodes that carry the subtitles only exist once the
		# timeline starts; apply the toggle after they are in the tree.
		Settings.apply_subtitles.call_deferred()
	else:
		# No timeline authored yet: do not strand the player.
		_advance.call_deferred()


func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = "press any key to skip"
	var ls := LabelSettings.new()
	ls.font_size = 10
	ls.font_color = Color(1.0, 1.0, 1.0, 0.45)
	_hint.label_settings = ls
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-170, -30)
	add_child(_hint)


func _dialogic() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/Dialogic")


## Dialogic registers authored timelines by short name in its `.dtl` directory
## (see the `directories/dtl_directory` map in project.godot). Asking its own
## resource util is the only reliable check — a bare ResourceLoader.exists()
## misses timelines whose runtime loader the addon registers lazily.
##
## The util is loaded at RUNTIME, not referenced statically: its class load
## runs `update_directory()`, and if that ever happens before the .dtl loader
## is registered the whole directory is erased. Loading it here keeps the
## check safe in any boot order.
static func _has_timeline() -> bool:
	const UTIL := "res://addons/dialogic/Core/DialogicResourceUtil.gd"
	var util: GDScript = load(UTIL) as GDScript
	if util != null and util.timeline_resource_exists(TIMELINE):
		return true
	return ResourceLoader.exists("res://dialogue/cutscence/cutscene_01.dtl")


func _on_timeline_ended() -> void:
	_advance()


func _unhandled_input(ev: InputEvent) -> void:
	var skip := false
	if ev is InputEventKey and ev.pressed and not ev.echo:
		skip = true
	elif ev is InputEventMouseButton and ev.pressed:
		skip = true
	elif ev is InputEventScreenTouch and ev.pressed:
		skip = true
	elif ev is InputEventJoypadButton and ev.pressed:
		skip = ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]
	if not skip:
		return
	_stop_timeline()
	_advance()


func _stop_timeline() -> void:
	var dialogic := _dialogic()
	if dialogic == null or dialogic.get("current_timeline") == null:
		return
	dialogic.call("end_timeline")


## Idempotent: a skip pressed on the same frame the timeline ends must not
## change scene twice.
func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	var tree := get_tree()
	if tree == null:
		return
	var target := NEXT_SCENE if ResourceLoader.exists(NEXT_SCENE) else FALLBACK_SCENE
	tree.change_scene_to_file.call_deferred(target)
