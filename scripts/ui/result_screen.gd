class_name ResultScreen
extends CanvasLayer
## Victory / game-over card. Same UIKit look as the main menu and pause menu.
##
## Emits intents only — the game root owns scene changes — and keeps
## processing while the tree is paused so the buttons still work if the run
## ends mid-pause.

signal retry_requested
signal menu_requested

const WIN_TITLE := "SITE SECURED"
const LOSE_TITLE := "YOU DIED"
const WIN_COLOR := Color(0.55, 1.0, 0.7)
const LOSE_COLOR := Color(1.0, 0.32, 0.28)

var _root: Control
var _box: Control
var _title: Label
var _summary: Label
var btn_retry: Button
var btn_menu: Button
var _won := false


func _init() -> void:
	layer = UILayers.RESULT
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(UIKit.fullrect_dim())

	_box = VBoxContainer.new()
	UIKit.centered(_box)
	_box.add_theme_constant_override("separation", 3)
	_root.add_child(_box)

	_title = UIKit.label(WIN_TITLE, 24, WIN_COLOR)
	_box.add_child(_title)

	_summary = UIKit.label("", 9, UIKit.PAPER)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_summary)

	_box.add_child(UIKit.gap())

	btn_retry = UIKit.button("RETRY")
	btn_retry.pressed.connect(func(): retry_requested.emit())
	_box.add_child(btn_retry)

	btn_menu = UIKit.button("MAIN MENU")
	btn_menu.pressed.connect(func(): menu_requested.emit())
	_box.add_child(btn_menu)


func show_result(won: bool, stats: RunStats) -> void:
	_won = won
	_title.text = WIN_TITLE if won else LOSE_TITLE
	_title.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_summary.text = _summarize(stats)
	visible = true
	if is_inside_tree():
		btn_retry.grab_focus()


func hide_result() -> void:
	visible = false


func is_won() -> bool:
	return _won


static func _summarize(stats: RunStats) -> String:
	if stats == null:
		return ""
	return "RANK %s    SCRAP %d    KILLS %d    ROOMS %d" % [
		stats.rank(), stats.scrap, stats.kills, stats.rooms_cleared,
	]


func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	var key_ok: bool = ev is InputEventKey and ev.pressed and not ev.echo \
		and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	var joy: InputEventJoypadButton = ev as InputEventJoypadButton
	var joy_ok: bool = joy != null and joy.pressed and joy.button_index == JOY_BUTTON_A
	if key_ok or joy_ok:
		retry_requested.emit()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
