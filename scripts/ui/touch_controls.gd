class_name TouchControls
extends CanvasLayer
## Mobile gameplay controls: floating joystick (move), drag-to-look surface
## and thumb-reach action buttons.
##
## Self-contained on purpose. The previous build leaned on the Thumbstick
## Plugin scenes for the joystick and look surface; that made movement and
## aiming depend on a third-party addon whose behaviour could not be tuned
## from here, and the result was an unusable mobile HUD. Input is now owned
## by this layer:
##
##   - buttons are hit-tested first (topmost priority)
##   - a touch on the left ~42% of the screen spawns a floating joystick
##   - anything else on the right side drags the camera
##
## Every touch is consumed with set_input_as_handled() so the game under the
## layer never sees duplicate events, and each finger keeps ownership of the
## control it pressed (a held FIRE stays held while that finger wiggles).
##
## The layer is ONLY active in UIManager's GAMEPLAY state (set_active); while
## a dialogue or the pause menu is up it is hidden and receives nothing.

signal pause_pressed

## Radius of the joystick base ring, in canvas pixels.
const JOYSTICK_RADIUS := 84.0
## Fraction of the radius that must be exceeded before the player moves.
const JOYSTICK_DEADZONE := 0.16
## Multiplier on drag deltas before they reach player.touch_look (the player
## converts pixels to radians at 0.004 rad/px).
const LOOK_SENSITIVITY := 1.0
## Fraction of screen width reserved for the joystick zone.
const JOYSTICK_ZONE := 0.42
## Canvas size used when the layer is not inside a tree (unit tests).
const FALLBACK_CANVAS := Vector2(1280, 720)

var player: CharacterBody3D = null

## name -> {"node": TouchButton, "anchor": Vector2, "offset": Vector2, "size": Vector2}
var buttons := {}
## Flat list of buttons for release sweeps; also asserted by tests.
var _buttons: Array[TouchButton] = []

var _stick: StickSprite
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_fingers := {}   # finger index -> last position
var _touch_buttons := {}  # finger index -> button name
var _last_weapon := -1


## On-screen action button. A Control that owns exactly one touch at a time.
## Visuals are a rounded tinted panel that brightens while held and dims when
## the action is on cooldown (dash / parry).
class TouchButton extends Control:
	signal button_down
	signal button_up

	## Public accessor used by set_text(); kept public so the layer can update
	## the weapon label. gdtoolkit wants public members before private ones.
	var label: Label

	var _touch_index := -1
	var _held := false
	var _disabled := false
	var _panel: Panel
	var _tint: Color

	func _init(text: String, btn_size: Vector2, tint := Color(0.9, 0.9, 0.95),
			font_size := 16) -> void:
		size = btn_size
		custom_minimum_size = btn_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_tint = tint
		_panel = Panel.new()
		_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_panel)
		label = Label.new()
		var ls := LabelSettings.new()
		ls.font_size = font_size
		ls.font_color = Color(1, 1, 1, 0.92)
		ls.outline_size = 2
		ls.outline_color = Color(0, 0, 0, 0.9)
		label.label_settings = ls
		label.text = text
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_apply_visual()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _touch_index == -1:
				_touch_index = ev.index
				set_held(true)
			elif not ev.pressed and ev.index == _touch_index:
				_touch_index = -1
				set_held(false)
			accept_event()
		elif ev is InputEventScreenDrag and ev.index == _touch_index:
			# A held button stays held while its finger wiggles.
			accept_event()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT \
				and not Input.is_emulating_mouse_from_touch():
			# Real-mouse fallback for desktop debugging; emulated mouse events
			# are skipped or every touch would fire the button twice.
			set_held(ev.pressed)
			accept_event()

	## Press/release state change, emitted with button_down / button_up.
	func set_held(on: bool) -> void:
		if _held == on:
			return
		_held = on
		_apply_visual()
		if on:
			button_down.emit()
		else:
			button_up.emit()

	## Cooldown dim-out (no signal emission).
	func set_disabled(on: bool) -> void:
		if _disabled == on:
			return
		_disabled = on
		_apply_visual()

	func set_text(t: String) -> void:
		label.text = t

	func force_release() -> void:
		if _touch_index != -1 or _held:
			_touch_index = -1
			set_held(false)

	func _apply_visual() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 2.0
		sb.content_margin_right = 2.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 2.0
		if _disabled:
			var dim := Color(0.5, 0.5, 0.52)
			sb.bg_color = Color(dim, 0.10)
			sb.border_color = Color(dim, 0.30)
		elif _held:
			sb.bg_color = Color(_tint, 0.48)
			sb.border_color = Color(_tint, 1.0)
		else:
			sb.bg_color = Color(_tint, 0.16)
			sb.border_color = Color(_tint, 0.65)
		_panel.add_theme_stylebox_override("panel", sb)


## Drawn joystick: base ring + knob. Draws in viewport space because the layer
## spans the full canvas (anchors preset full-rect => local == viewport coords).
class StickSprite extends Control:
	var origin := Vector2.ZERO
	var knob := Vector2.ZERO
	var radius := 84.0
	var knob_radius := 34.0
	var active := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func show_at(p_origin: Vector2, p_knob: Vector2) -> void:
		origin = p_origin
		knob = p_knob
		active = true
		visible = true
		queue_redraw()

	func move_knob(p_knob: Vector2) -> void:
		knob = p_knob
		queue_redraw()

	func hide_stick() -> void:
		active = false
		visible = false
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		draw_circle(origin, radius, Color(1, 1, 1, 0.10))
		draw_arc(origin, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.40), 3.0)
		draw_circle(origin, 5.0, Color(1, 1, 1, 0.55))
		draw_circle(knob, knob_radius, Color(0.35, 0.9, 1.0, 0.50))
		draw_arc(knob, knob_radius, 0.0, TAU, 32, Color(0.35, 0.9, 1.0, 0.95), 3.0)


func _init() -> void:
	layer = UILayers.TOUCH


func setup(p: CharacterBody3D) -> void:
	player = p
	_build_stick()
	# Buttons are added AFTER the stick so they draw above it and win the
	# hit-test when a touch lands on both.
	_build_buttons()


func set_active(on: bool) -> void:
	## Called by UIManager on every state change. Hidden layers receive no
	## input and _input() also gates on visibility, so this both hides and
	## mutes the whole layer.
	if visible == on:
		return
	visible = on
	if not on:
		_release_everything()


func _release_everything() -> void:
	for b in _buttons:
		b.force_release()
	_touch_buttons.clear()
	_look_fingers.clear()
	_stop_stick()
	if player:
		player.touch_move = Vector2.ZERO
		player.touch_look = Vector2.ZERO
		player.touch_fire = false
		player.touch_jump = false
		player.touch_slide = false


func _process(_dt: float) -> void:
	if player == null or not visible or not is_instance_valid(player):
		return
	_update_cooldown_visuals()
	_update_weapon_label()


func _update_cooldown_visuals() -> void:
	# Dash / parry buttons dim while their cooldown is running.
	if buttons.has("dash"):
		buttons["dash"].node.set_disabled(player.dash_cd > 0.0)
	if buttons.has("parry"):
		buttons["parry"].node.set_disabled(player.parry_cd > 0.0)


func _update_weapon_label() -> void:
	if not buttons.has("wpn") or not ("weapon" in player):
		return
	var w := int(player.weapon)
	if w != _last_weapon:
		_last_weapon = w
		var names := ["1", "2", "3"]
		buttons["wpn"].node.set_text("WPN %s" % names[w] \
				if w >= 0 and w < names.size() else "WPN")


# --- input routing ----------------------------------------------------------


func _input(ev: InputEvent) -> void:
	if not visible or player == null:
		return
	if ev is InputEventScreenTouch:
		_handle_touch(ev)
	elif ev is InputEventScreenDrag:
		_handle_drag(ev)


func _handle_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		var button_name := _button_at(ev.position)
		if button_name != "":
			_touch_buttons[ev.index] = button_name
			buttons[button_name].node.set_held(true)
			_mark_handled()
			return
		if _stick_finger == -1 and ev.position.x < _joystick_zone_width():
			_start_stick(ev.index, ev.position)
			_mark_handled()
			return
		_look_fingers[ev.index] = ev.position
		_mark_handled()
		return
	# Released finger: route by whoever owned it.
	if _touch_buttons.has(ev.index):
		var name: String = _touch_buttons[ev.index]
		_touch_buttons.erase(ev.index)
		buttons[name].node.set_held(false)
		_mark_handled()
		return
	if ev.index == _stick_finger:
		_stop_stick()
		_mark_handled()
		return
	if _look_fingers.has(ev.index):
		_look_fingers.erase(ev.index)
		_mark_handled()


func _handle_drag(ev: InputEventScreenDrag) -> void:
	if _touch_buttons.has(ev.index):
		# A held button stays held while its finger wiggles.
		_mark_handled()
		return
	if ev.index == _stick_finger:
		_update_stick(ev.position)
		_mark_handled()
		return
	if _look_fingers.has(ev.index):
		player.touch_look += (ev.position - _look_fingers[ev.index]) * LOOK_SENSITIVITY
		_look_fingers[ev.index] = ev.position
		_mark_handled()


func _mark_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


# --- joystick ---------------------------------------------------------------


func _build_stick() -> void:
	_stick = StickSprite.new()
	_stick.name = "MoveStick"
	_stick.radius = JOYSTICK_RADIUS
	add_child(_stick)
	_stick.hide_stick()


func _start_stick(finger: int, pos: Vector2) -> void:
	_stick_finger = finger
	_stick_origin = pos
	_stick_pos = pos
	_stick.show_at(pos, pos)
	if player:
		player.touch_move = Vector2.ZERO


func _update_stick(pos: Vector2) -> void:
	var v := (pos - _stick_origin) / JOYSTICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	var len := v.length()
	if len < JOYSTICK_DEADZONE:
		v = Vector2.ZERO
	else:
		# Ramp from the deadzone edge to full deflection.
		v = v * ((len - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE))
	_stick_pos = _stick_origin + v * JOYSTICK_RADIUS
	_stick.move_knob(_stick_pos)
	if player:
		# addon/plugin convention: stick up (screen -y) = forward (+player y).
		player.touch_move = Vector2(v.x, -v.y)


func _stop_stick() -> void:
	if _stick_finger != -1:
		_stick_finger = -1
		_stick.hide_stick()
		if player:
			player.touch_move = Vector2.ZERO


# --- buttons ----------------------------------------------------------------


func _build_buttons() -> void:
	# name: [label, size, anchor, offset, tint, font size]
	var defs := {
		"fire": ["FIRE", Vector2(150, 150), Vector2(1, 1), Vector2(-168, -168),
				Color(1.0, 0.30, 0.32), 22],
		"dash": ["DASH", Vector2(112, 112), Vector2(1, 1), Vector2(-168, -288),
				Color(0.35, 0.95, 1.0), 16],
		"jump": ["JUMP", Vector2(112, 112), Vector2(1, 1), Vector2(-288, -168),
				Color(0.40, 0.90, 0.50), 16],
		"slide": ["SLIDE", Vector2(112, 112), Vector2(1, 1), Vector2(-288, -288),
				Color(1.0, 0.75, 0.30), 15],
		"wpn": ["WPN 1", Vector2(96, 64), Vector2(1, 1), Vector2(-176, -368),
				Color(0.85, 0.85, 0.90), 14],
		"parry": ["PARRY", Vector2(112, 112), Vector2(0, 1), Vector2(24, -144),
				Color(1.0, 0.85, 0.35), 15],
		"coin": ["COIN", Vector2(112, 112), Vector2(0, 1), Vector2(144, -144),
				Color(1.0, 0.72, 0.25), 15],
		"pause": ["II", Vector2(72, 56), Vector2(1, 0), Vector2(-96, 16),
				Color(0.80, 0.80, 0.85), 16],
	}
	for action in defs:
		var d: Array = defs[action]
		var b := TouchButton.new(d[0], d[1], d[4], d[5])
		b.name = "Btn_" + action
		b.anchor_left = d[2].x
		b.anchor_right = d[2].x
		b.anchor_top = d[2].y
		b.anchor_bottom = d[2].y
		b.offset_left = d[3].x
		b.offset_top = d[3].y
		b.offset_right = d[3].x + d[1].x
		b.offset_bottom = d[3].y + d[1].y
		b.button_down.connect(_on_action.bind(action, true))
		b.button_up.connect(_on_action.bind(action, false))
		add_child(b)
		_buttons.append(b)
		buttons[action] = {"node": b, "anchor": d[2], "offset": d[3], "size": d[1]}


func _on_action(action: String, on: bool) -> void:
	if action == "pause":
		if on:
			pause_pressed.emit()
		return
	if player == null:
		return
	match action:
		"fire":
			player.touch_fire = on
		"jump":
			player.touch_jump = on
		"slide":
			player.touch_slide = on
		"dash":
			if on:
				player.request_dash()
		"wpn":
			if on:
				player.cycle_weapon()
		"parry":
			if on:
				player.request_parry()
		"coin":
			if on:
				player.toss_coin()


# --- helpers ----------------------------------------------------------------


func _canvas_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else FALLBACK_CANVAS


func _joystick_zone_width() -> float:
	return _canvas_size().x * JOYSTICK_ZONE


## Global rect of a button (viewport coordinates), also used by tests.
func _button_rect(name: String) -> Rect2:
	var b: Dictionary = buttons[name]
	var sz := _canvas_size()
	return Rect2(Vector2(sz.x * b.anchor.x + b.offset.x,
			sz.y * b.anchor.y + b.offset.y), b.size)


func _button_at(pos: Vector2) -> String:
	for name in buttons:
		if _button_rect(name).grow(10.0).has_point(pos):
			return name
	return ""
