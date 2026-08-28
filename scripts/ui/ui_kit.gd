class_name UIKit
extends RefCounted
## Shared factory for the game's procedural UI (main menu, settings, pause).
## One place for colors, styleboxes and widget construction so every screen
## looks identical and style tweaks touch a single file.

const ACCENT := Color(1.0, 0.62, 0.2)
const CYAN := Color(0.4, 0.95, 1.0)
const PAPER := Color(0.92, 0.86, 0.85)
const MUTED := Color(0.66, 0.56, 0.56)
const DIM := Color(0.05, 0.03, 0.01, 0.88)


static func label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb


static func button(text: String, width := 128) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 18)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", stylebox(Color(0.07, 0.01, 0.02, 0.9), Color(0.5, 0.08, 0.12)))
	b.add_theme_stylebox_override("hover", stylebox(Color(0.17, 0.03, 0.05, 0.95), ACCENT))
	b.add_theme_stylebox_override("pressed", stylebox(Color(0.05, 0.01, 0.01, 0.95), CYAN))
	b.add_theme_stylebox_override("focus", stylebox(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.85)))
	# One place to give every screen in the game consistent menu feedback.
	b.focus_entered.connect(_ui_sound.bind("move"))
	b.pressed.connect(_ui_sound.bind("click"))
	return b


## UIKit is a static factory used by tests too, where the Sfx autoload may not
## exist — so the lookup is defensive and silently does nothing without it.
static func _ui_sound(sound: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var bus := tree.root.get_node_or_null("Sfx")
	if bus != null:
		bus.play(sound)


static func slider(minv: float, maxv: float, stepv: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = stepv
	s.custom_minimum_size = Vector2(120, 12)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_stylebox_override("slider", stylebox(Color(0.1, 0.02, 0.03, 0.9), Color(0.35, 0.06, 0.09)))
	s.add_theme_stylebox_override("grabber_area", stylebox(ACCENT, ACCENT))
	s.add_theme_stylebox_override("grabber_area_highlight", stylebox(CYAN, CYAN))
	return s


static func options(items: PackedStringArray) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(120, 18)
	for item in items: o.add_item(item)
	return o


static func toggle_button() -> Button:
	var b := button("OFF", 56)
	b.toggle_mode = true
	return b


static func resolution_box() -> SpinBox:
	var box := SpinBox.new()
	box.min_value = 320
	box.max_value = 7680
	box.step = 1
	box.allow_greater = true
	box.custom_minimum_size = Vector2(72, 18)
	return box


static func gap(height := 6.0) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, height)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func centered(container: Control) -> void:
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH


static func fullrect_dim(color := DIM) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: a dim behind a modal must eat clicks so gameplay/HUD under it
	# never receives them.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim
