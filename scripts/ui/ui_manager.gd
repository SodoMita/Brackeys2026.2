class_name UIManager
extends Node
## Single owner of in-game UI state. Fixes the old free-for-all where the
## touch layer, Dialogic and (nonexistent) pause menu all fought over input:
##
##  - one explicit state: GAMEPLAY / DIALOG / PAUSED
##  - touch controls exist ONLY in GAMEPLAY (hidden + muted otherwise)
##  - Dialogic timelines flip the state automatically via its signals
##  - pause works everywhere (ESC / START / touch pause button), including
##    over a running dialogue — Dialogic nodes pause with the tree while the
##    pause menu itself keeps processing
##  - all CanvasLayer numbers come from UILayers, nowhere else
##
## Add it under the game root:
##   var ui := UIManager.new()
##   add_child(ui)
##   ui.setup(player)

enum State { GAMEPLAY, DIALOG, PAUSED }

signal state_changed(state: State)

const MENU_SCENE := "res://scenes/main_menu.tscn"

var state: State = State.GAMEPLAY
var player: CharacterBody3D = null
var touch_controls: TouchControls = null
var pause_menu: PauseMenu = null

## What was on screen before pausing, so unpausing returns to it.
var _state_before_pause: State = State.GAMEPLAY


func _init() -> void:
	# The manager must keep processing input (ESC) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(p: CharacterBody3D) -> void:
	player = p

	if _touch_available():
		touch_controls = TouchControls.new()
		touch_controls.name = "TouchControls"
		add_child(touch_controls)
		touch_controls.setup(p)
		touch_controls.pause_pressed.connect(toggle_pause)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.resume_requested.connect(resume)
	pause_menu.quit_to_menu_requested.connect(_quit_to_menu)

	_connect_dialogic()
	_apply_state()


static func _touch_available() -> bool:
	return DisplayServer.get_name() != "headless" \
			and DisplayServer.is_touchscreen_available()


func _dialogic() -> Node:
	# Autoload lookup at runtime keeps this class loadable headless/testless
	# (absolute paths are only legal once inside the tree).
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/Dialogic")


func _connect_dialogic() -> void:
	var dialogic := _dialogic()
	if dialogic == null:
		return
	if dialogic.has_signal("timeline_started"):
		dialogic.timeline_started.connect(_on_timeline_started)
	if dialogic.has_signal("timeline_ended"):
		dialogic.timeline_ended.connect(_on_timeline_ended)


func _on_timeline_started() -> void:
	_raise_dialogic_layout()
	# The layout nodes that carry the text only exist once a timeline runs, so
	# the subtitles toggle is applied deferred, after they are in the tree.
	Settings.apply_subtitles.call_deferred()
	if state == State.GAMEPLAY:
		_set_state(State.DIALOG)


func _on_timeline_ended() -> void:
	if state == State.DIALOG:
		_set_state(State.GAMEPLAY)
	elif state == State.PAUSED and _state_before_pause == State.DIALOG:
		# Dialogue somehow ended while paused: resume into gameplay.
		_state_before_pause = State.GAMEPLAY


func _raise_dialogic_layout() -> void:
	# Dialogic's default layout ships with canvas_layer = 1, which would sit
	# UNDER the touch layer. Pin it to the slot our stack reserves for it.
	var dialogic := _dialogic()
	if dialogic == null:
		return
	var styles: Variant = dialogic.get("Styles")
	if styles == null or not styles.has_active_layout_node():
		return
	var layout: Node = styles.get_layout_node()
	if layout != null and "layer" in layout:
		layout.set("layer", UILayers.DIALOG)


# --- pause -----------------------------------------------------------------


func toggle_pause() -> void:
	if state == State.PAUSED:
		resume()
	else:
		pause()


func pause() -> void:
	if state == State.PAUSED:
		return
	_state_before_pause = state
	_set_state(State.PAUSED)


func resume() -> void:
	if state != State.PAUSED:
		return
	_set_state(_state_before_pause)


func _unhandled_input(ev: InputEvent) -> void:
	var esc: bool = ev is InputEventKey and ev.pressed and not ev.echo \
			and ev.keycode == KEY_ESCAPE
	var joy: InputEventJoypadButton = ev as InputEventJoypadButton
	var start: bool = joy != null and joy.pressed \
			and joy.button_index == JOY_BUTTON_START
	if not (esc or start):
		return
	# While paused, PauseMenu/SettingsPanel own ESC (resume / back / rebind).
	if state == State.PAUSED:
		return
	pause()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


# --- state machine ---------------------------------------------------------


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	_apply_state()
	state_changed.emit(state)


func _apply_state() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = state == State.PAUSED

	# Touch layer only exists during actual gameplay.
	if touch_controls != null:
		touch_controls.set_active(state == State.GAMEPLAY)

	if pause_menu != null:
		if state == State.PAUSED:
			pause_menu.open()
		else:
			pause_menu.close()

	# The FPS controller ignores input while any UI owns the screen.
	if player != null:
		player.disabled = state != State.GAMEPLAY

	_apply_mouse_mode()


func _apply_mouse_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _touch_available():
		return  # no captured mouse on touch devices
	if state == State.GAMEPLAY:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _quit_to_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	# End any running dialogue so the Dialogic autoload doesn't carry a
	# timeline (and its layout node) into the menu scene.
	var dialogic := _dialogic()
	if dialogic != null and dialogic.get("current_timeline") != null:
		dialogic.call("end_timeline")
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)
