extends CharacterBody3D
## Fast FPS controller: run, jump (no fall damage), dash, slide.
## Input sources: keyboard+mouse, gamepad, touchscreen (virtual controls).
## Firing is hitscan; results reported via signals.

signal fired(enemy: Node3D, headshot: bool, airborne: bool, damage: float)
signal dashed
signal slid
signal player_died

const WALK := 10.0
const GRAVITY := 22.0
const JUMP_V := 9.5
const ACCEL_GROUND := 90.0
const ACCEL_AIR := 40.0
const FRICTION := 10.0
const DASH_SPEED := 24.0
const DASH_TIME := 0.18
const DASH_CD := 0.9
const SLIDE_MAX := 17.0
const MOUSE_SENS := 0.0026
const STICK_LOOK := 2.6
const STICK_DEAD := 0.15

var yaw := 0.0
var pitch := 0.0
var head: Node3D
var cam: Camera3D
var muzzle: OmniLight3D
var hp := CombatLogic.MAX_HP
var dead := false

var dash_cd := 0.0
var dash_t := 0.0
var sliding := false
var fire_cd := 0.0
var weapon := 0  # 0 = revolver, 1 = shotgun
var _want_dash := false
var _prev_joy_dash := false
var _prev_joy_wpn_l := false
var _prev_joy_wpn_r := false

# --- aggregated input written by keyboard/gamepad polling and touch events
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO  # accumulated pixels, consumed per frame
var touch_fire := false
var touch_jump := false
var touch_slide := false


func _init() -> void:
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	head.position = Vector3(0.0, 1.6, 0.0)
	cam = Camera3D.new()
	cam.fov = 90.0
	cam.far = 200.0
	head.add_child(cam)
	muzzle = OmniLight3D.new()
	muzzle.light_color = Color(1.0, 0.75, 0.35)
	muzzle.light_energy = 0.0
	muzzle.omni_range = 7.0
	muzzle.position = Vector3(0.3, -0.25, -0.9)
	head.add_child(muzzle)
	var gun := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.07, 0.11, 0.55)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.12, 0.16)
	gb.material = gm
	gun.mesh = gb
	gun.position = Vector3(0.28, -0.24, -0.55)
	head.add_child(gun)


func request_dash() -> void:
	_want_dash = true


func cycle_weapon() -> void:
	weapon = 0 if weapon == 1 else 1


func _unhandled_input(ev: InputEvent) -> void:
	if dead:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-ev.relative.x * MOUSE_SENS, -ev.relative.y * MOUSE_SENS)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SHIFT:
				_want_dash = true
			KEY_1:
				weapon = 0
			KEY_2:
				weapon = 1
	elif ev is InputEventJoypadButton and ev.pressed:
		match ev.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_want_dash = true
			JOY_BUTTON_DPAD_LEFT:
				weapon = 0
			JOY_BUTTON_DPAD_RIGHT:
				weapon = 1
			JOY_BUTTON_Y:
				cycle_weapon()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			touch_fire_mouse = true


var touch_fire_mouse := false


func _apply_look(dyaw: float, dpitch: float) -> void:
	yaw += dyaw
	pitch = clampf(pitch + dpitch, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch


func _gather_move() -> Vector2:
	# touchscreen > gamepad > keyboard
	if touch_move.length() > 0.05:
		return touch_move
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var j := Vector2(jx, jy)
	if j.length() > STICK_DEAD:
		return j.limit_length(1.0)
	var ix := 0.0
	var iy := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		iy += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		iy -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		ix -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		ix += 1.0
	return Vector2(ix, iy).normalized()


func _physics_process(dt: float) -> void:
	if dead:
		return
	dash_cd = maxf(dash_cd - dt, 0.0)
	fire_cd = maxf(fire_cd - dt, 0.0)
	muzzle.light_energy = maxf(muzzle.light_energy - dt * 120.0, 0.0)

	# --- look: gamepad right stick + accumulated touch deltas
	var lx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ly := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if Vector2(lx, ly).length() > STICK_DEAD:
		_apply_look(-lx * STICK_LOOK * dt, -ly * STICK_LOOK * dt)
	if touch_look.length() > 0.0:
		_apply_look(-touch_look.x * 0.004, -touch_look.y * 0.004)
		touch_look = Vector2.ZERO

	var wish := (transform.basis * Vector3(_gather_move().x, 0.0, _gather_move().y)).normalized()
	var grounded := is_on_floor()

	# --- jump (hold-to-bhop, no fall damage anywhere)
	var jump := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or touch_jump
	if grounded and jump:
		velocity.y = JUMP_V

	# --- slide
	var want_slide := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C) \
			or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or touch_slide
	if want_slide and grounded and horizontal_speed() > 5.0 and not sliding:
		sliding = true
		slid.emit()
	if not want_slide or not grounded:
		sliding = false
	head.position.y = lerpf(head.position.y, 0.95 if sliding else 1.6, 12.0 * dt)

	# --- gravity / dash
	if dash_t > 0.0:
		dash_t -= dt
	else:
		velocity.y -= GRAVITY * dt
	if _want_dash:
		_want_dash = false
		if dash_cd <= 0.0:
			var dir := wish if wish.length() > 0.1 else -transform.basis.z
			velocity.x = dir.x * DASH_SPEED
			velocity.z = dir.z * DASH_SPEED
			velocity.y = maxf(velocity.y, 0.0)
			dash_t = DASH_TIME
			dash_cd = DASH_CD
			dashed.emit()

	# --- horizontal accel (quake-style), slide keeps momentum
	if not sliding:
		var target := wish * WALK
		var accel := ACCEL_GROUND if grounded else ACCEL_AIR
		velocity.x = move_toward(velocity.x, target.x, accel * dt)
		velocity.z = move_toward(velocity.z, target.z, accel * dt)
		if grounded and wish.length() < 0.1:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * WALK * dt)
			velocity.z = move_toward(velocity.z, 0.0, FRICTION * WALK * dt)
	else:
		var sp := horizontal_speed()
		if sp > SLIDE_MAX or wish.length() < 0.1:
			velocity.x = move_toward(velocity.x, velocity.x * 0.98, 4.0 * dt)
			velocity.z = move_toward(velocity.z, velocity.z * 0.98, 4.0 * dt)

	move_and_slide()

	# --- fire
	var firing := touch_fire_mouse or touch_fire \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	if firing:
		try_fire()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func try_fire() -> void:
	if fire_cd > 0.0:
		return
	fire_cd = 0.26 if weapon == 0 else 0.75
	var pellets := 1 if weapon == 0 else 7
	var spread := 0.0 if weapon == 0 else 0.055
	var damage := 34.0 if weapon == 0 else 12.0
	for _i in pellets:
		var dir := -cam.global_transform.basis.z
		dir += cam.global_transform.basis.x * randf_range(-spread, spread)
		dir += cam.global_transform.basis.y * randf_range(-spread, spread)
		dir = dir.normalized()
		var from := cam.global_position
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 150.0)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit and hit.collider.has_method("take_damage"):
			var headshot: bool = hit.position.y > hit.collider.global_position.y + 0.55
			fired.emit(hit.collider, headshot, not is_on_floor(), damage)
	muzzle.light_energy = 7.0


func take_damage(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		dead = true
		player_died.emit()
