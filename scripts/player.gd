extends CharacterBody3D
## Fast FPS controller: run, jump (no fall damage), dash, slide, parry,
## coin toss + ricochet. Inputs: keyboard+mouse, gamepad, touchscreen.

signal fired(enemy: Node3D, headshot: bool, airborne: bool, damage: float, ricochet: bool)
signal dashed
signal slid
signal parried
signal coin_tossed
signal player_died

const STICK_DEAD := 0.15

var yaw := 0.0
var pitch := 0.0
var head: Node3D
var cam: Camera3D
var muzzle: OmniLight3D
var hp: float
var dead := false
var enemy_pool: Node3D = null

var dash_cd := 0.0
var dash_t := 0.0
var sliding := false
var fire_cd := 0.0
var weapon := 0  # 0 = revolver, 1 = shotgun
var _want_dash := false

# parry
var parry_age := -1.0   # <0 when not pressed
var parry_cd := 0.0

# coin
var coin: RigidBody3D = null
var coin_age := 0.0
var touch_fire_mouse := false

# aggregated touch input
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_fire := false
var touch_jump := false
var touch_slide := false


func _init() -> void:
	hp = Cfg.max_hp
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


func request_parry() -> void:
	if parry_cd <= 0.0:
		parry_age = 0.0
		parry_cd = Cfg.parry_cooldown


func is_parry_active() -> bool:
	return CombatLogic.parry_active(parry_age, Cfg.parry_active_window)


func cycle_weapon() -> void:
	weapon = 0 if weapon == 1 else 1


func toss_coin() -> void:
	if coin and is_instance_valid(coin):
		return
	coin = RigidBody3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	cm.material = mat
	coin.mesh = cm
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.15
	coin.add_child(cs)
	cs.shape = ss
	coin.set_meta("coin", true)
	coin.position = cam.global_position + (-cam.global_transform.basis.z) * 0.5
	var vel := -cam.global_transform.basis.z * Cfg.coin_toss_velocity
	vel.y += Cfg.coin_toss_velocity * 0.6
	coin.linear_velocity = vel
	coin.angular_velocity = Vector3(20.0, 5.0, 20.0)
	add_child(coin)
	coin_age = 0.0
	coin_tossed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if dead:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-ev.relative.x * Cfg.mouse_sensitivity, -ev.relative.y * Cfg.mouse_sensitivity)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SHIFT:
				_want_dash = true
			KEY_F, KEY_V:
				request_parry()
			KEY_1:
				weapon = 0
			KEY_2:
				weapon = 1
	elif ev is InputEventJoypadButton and ev.pressed:
		match ev.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_want_dash = true
			JOY_BUTTON_X:
				request_parry()
			JOY_BUTTON_DPAD_LEFT:
				weapon = 0
			JOY_BUTTON_DPAD_RIGHT:
				weapon = 1
			JOY_BUTTON_Y:
				cycle_weapon()
	elif ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				touch_fire_mouse = true
			MOUSE_BUTTON_RIGHT:
				toss_coin()


func _apply_look(dyaw: float, dpitch: float) -> void:
	yaw += dyaw
	pitch = clampf(pitch + dpitch, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch


func _gather_move() -> Vector2:
	if touch_move.length() > 0.05:
		return touch_move
	var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
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
	parry_cd = maxf(parry_cd - dt, 0.0)
	if parry_age >= 0.0:
		parry_age += dt
		if parry_age > Cfg.parry_active_window * 2.0:
			parry_age = -1.0
	fire_cd = maxf(fire_cd - dt, 0.0)
	muzzle.light_energy = maxf(muzzle.light_energy - dt * 120.0, 0.0)
	if coin and is_instance_valid(coin):
		coin_age += dt
		if coin_age > Cfg.coin_lifetime:
			coin.queue_free()
			coin = null

	# --- look: gamepad right stick + accumulated touch deltas
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > STICK_DEAD:
		_apply_look(-rs.x * Cfg.stick_look_speed * dt, -rs.y * Cfg.stick_look_speed * dt)
	if touch_look.length() > 0.0:
		_apply_look(-touch_look.x * 0.004, -touch_look.y * 0.004)
		touch_look = Vector2.ZERO

	var wish := (transform.basis * Vector3(_gather_move().x, 0.0, _gather_move().y)).normalized()
	var grounded := is_on_floor()

	# --- jump (hold-to-bhop, no fall damage anywhere)
	var jump := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or touch_jump
	if grounded and jump:
		velocity.y = Cfg.jump_velocity

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
		velocity.y -= Cfg.gravity * dt
	if _want_dash:
		_want_dash = false
		if dash_cd <= 0.0:
			var dir := wish if wish.length() > 0.1 else -transform.basis.z
			velocity.x = dir.x * Cfg.dash_speed
			velocity.z = dir.z * Cfg.dash_speed
			velocity.y = maxf(velocity.y, 0.0)
			dash_t = Cfg.dash_time
			dash_cd = Cfg.dash_cooldown
			dashed.emit()

	# --- horizontal accel (quake-style), slide keeps momentum
	if not sliding:
		var target := wish * Cfg.walk_speed
		var accel := Cfg.accel_ground if grounded else Cfg.accel_air
		velocity.x = move_toward(velocity.x, target.x, accel * dt)
		velocity.z = move_toward(velocity.z, target.z, accel * dt)
		if grounded and wish.length() < 0.1:
			velocity.x = move_toward(velocity.x, 0.0, Cfg.friction * Cfg.walk_speed * dt)
			velocity.z = move_toward(velocity.z, 0.0, Cfg.friction * Cfg.walk_speed * dt)
	else:
		var sp := horizontal_speed()
		if sp > Cfg.slide_max_speed or wish.length() < 0.1:
			velocity.x = move_toward(velocity.x, velocity.x * 0.98, 4.0 * dt)
			velocity.z = move_toward(velocity.z, velocity.z * 0.98, 4.0 * dt)

	move_and_slide()

	# --- fire
	var coin_btn := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.4
	if coin_btn and not _prev_lt:
		toss_coin()
	_prev_lt = coin_btn
	var firing := touch_fire_mouse or touch_fire \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	if firing:
		try_fire()


var _prev_lt := false


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func try_fire() -> void:
	if fire_cd > 0.0:
		return
	fire_cd = Cfg.revolver_cooldown if weapon == 0 else Cfg.shotgun_cooldown
	var pellets := 1 if weapon == 0 else Cfg.shotgun_pellets
	var spread := 0.0 if weapon == 0 else Cfg.shotgun_spread
	var damage := Cfg.revolver_damage if weapon == 0 else Cfg.shotgun_damage
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
		if not hit:
			continue
		if hit.collider.has_meta("coin"):
			_ricochet(damage)
			return
		if hit.collider.has_method("take_damage"):
			var headshot: bool = hit.position.y > hit.collider.global_position.y + 0.55
			fired.emit(hit.collider, headshot, not is_on_floor(), damage, false)
	muzzle.light_energy = 7.0


func _ricochet(base_damage: float) -> void:
	if coin and is_instance_valid(coin):
		coin.queue_free()
		coin = null
	var targets := CombatLogic.nearest_targets(global_position,
			_get_enemies(), Cfg.ricochet_targets)
	for e in targets:
		if is_instance_valid(e):
			fired.emit(e, false, not is_on_floor(), base_damage * Cfg.ricochet_damage_mult, true)
	muzzle.light_energy = 9.0


func _get_enemies() -> Array:
	var out: Array = []
	if enemy_pool:
		for c in enemy_pool.get_children():
			if c.has_method("take_damage"):
				out.append(c)
	return out


func take_damage(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		dead = true
		player_died.emit()
