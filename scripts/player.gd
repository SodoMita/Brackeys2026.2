extends CharacterBody3D
## Fast FPS controller: run, jump (no fall damage), dash, slide, parry,
## coin toss + ricochet. Inputs: keyboard+mouse, gamepad, touchscreen.
## Now supports being instanced from a .tscn (editor-editable).
## If child nodes exist in the scene, they are reused; otherwise created procedurally.
## _init creates fallback nodes so headless tests work without _ready.

signal fired(enemy: Node3D, headshot: bool, airborne: bool, damage: float, ricochet: bool)
signal dashed
signal slid
signal parried
signal coin_tossed
signal player_died

const STICK_DEAD := 0.15

@export_group("References (auto-filled if empty)")
@export var head_path: NodePath
@export var camera_path: NodePath
@export var muzzle_path: NodePath

var yaw := 0.0
var pitch := 0.0
var head: Node3D
var cam: Camera3D
var muzzle: OmniLight3D
var hp: float = 100.0
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
var damage_mult := 1.0
var weapons := [true, true, false]
var disabled := false

# aggregated touch input
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_fire := false
var touch_jump := false
var touch_slide := false

var _prev_lt := false


func _init() -> void:
	# Create fallback nodes in _init so tests that call _ready manually or don't enter tree still have them.
	# If scene provides nodes, _ensure_nodes in _ready will dedupe.
	hp = Cfg.max_hp if Cfg and "max_hp" in Cfg else 100.0
	var pc := CollisionShape3D.new()
	pc.name = "CollisionShape3D"
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.6
	pc.shape = caps
	pc.position = Vector3(0.0, 0.8, 0.0)
	add_child(pc)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.6, 0.0)
	add_child(head)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 90.0
	cam.far = 200.0
	head.add_child(cam)
	muzzle = OmniLight3D.new()
	muzzle.name = "MuzzleLight"
	muzzle.light_color = Color(1.0, 0.75, 0.35)
	muzzle.light_energy = 0.0
	muzzle.omni_range = 7.0
	muzzle.position = Vector3(0.3, -0.25, -0.9)
	head.add_child(muzzle)
	var gun := MeshInstance3D.new()
	gun.name = "GunMesh"
	var gb := BoxMesh.new()
	gb.size = Vector3(0.07, 0.11, 0.55)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.12, 0.16)
	gb.material = gm
	gun.mesh = gb
	gun.position = Vector3(0.28, -0.24, -0.55)
	head.add_child(gun)


func _ready() -> void:
	# A level can be launched directly, bypassing the main menu. Initialize remappable actions here too.
	Settings.apply_saved()
	_ensure_nodes()
	hp = Cfg.max_hp if Cfg and "max_hp" in Cfg else hp


func _ensure_nodes() -> void:
	# Dedupe: if scene provides a node with same name but different instance, keep scene one.
	# CollisionShape3D
	var existing_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	# If we have multiple CollisionShape3D (fallback + scene), keep first scene-provided? Simplify: if more than 1, remove fallback.
	var cols: Array = []
	for c in get_children():
		if c is CollisionShape3D:
			cols.append(c)
	if cols.size() > 1:
		# Keep the one that is not the _init fallback? Heuristic: keep last (scene) and remove earlier
		# Our _init nodes are added first, scene nodes added after _init, so scene nodes are later in child list
		for i in range(cols.size() - 1):
			var to_remove = cols[i]
			if is_instance_valid(to_remove):
				if to_remove.is_inside_tree():
					to_remove.queue_free()
				else:
					to_remove.free()

	# Head dedupe
	var heads: Array = []
	for c in get_children():
		if c is Node3D and c.name == "Head":
			heads.append(c)
	if heads.size() > 1:
		# Keep the last one (scene), remove earlier fallback heads. Resolve the
		# reference directly because queued nodes still win get_node() lookups
		# until the end of the frame.
		head = heads[heads.size() - 1] as Node3D
		for i in range(heads.size() - 1):
			var h = heads[i]
			if is_instance_valid(h):
				if h.is_inside_tree():
					h.queue_free()
				else:
					h.free()

	# Resolve references via paths or names
	if head_path != NodePath():
		var np_head = get_node_or_null(head_path) as Node3D
		if np_head:
			head = np_head
	else:
		var h = get_node_or_null("Head") as Node3D
		if h:
			head = h

	if head == null:
		head = Node3D.new()
		head.name = "Head"
		head.position = Vector3(0.0, 1.6, 0.0)
		add_child(head)

	# Camera
	if camera_path != NodePath():
		cam = get_node_or_null(camera_path) as Camera3D
	else:
		if head:
			cam = head.get_node_or_null("Camera3D") as Camera3D
			if cam == null:
				cam = get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "Camera3D"
		cam.fov = 90.0
		cam.far = 200.0
		head.add_child(cam)
	cam.current = true

	# Muzzle
	if muzzle_path != NodePath():
		muzzle = get_node_or_null(muzzle_path) as OmniLight3D
	else:
		if head:
			muzzle = head.get_node_or_null("MuzzleLight") as OmniLight3D
			if muzzle == null:
				muzzle = head.get_node_or_null("Camera3D/MuzzleLight") as OmniLight3D
			if muzzle == null:
				for c in head.get_children():
					if c is OmniLight3D:
						muzzle = c
						break
	if muzzle == null:
		muzzle = OmniLight3D.new()
		muzzle.name = "MuzzleLight"
		muzzle.light_color = Color(1.0, 0.75, 0.35)
		muzzle.light_energy = 0.0
		muzzle.omni_range = 7.0
		muzzle.position = Vector3(0.3, -0.25, -0.9)
		head.add_child(muzzle)


func request_dash() -> void:
	_want_dash = true


func request_parry() -> void:
	if parry_cd <= 0.0:
		parry_age = 0.0
		parry_cd = Cfg.parry_cooldown


func is_parry_active() -> bool:
	return CombatLogic.parry_active(parry_age, Cfg.parry_active_window)


func cycle_weapon() -> void:
	# Cycle through weapons the player actually owns; newly purchased weapons
	# should not get skipped or leave the player on an unavailable slot.
	for step in range(1, weapons.size() + 1):
		var next := (weapon + step) % weapons.size()
		if weapons[next]:
			weapon = next
			return


func toss_coin() -> void:
	if coin and is_instance_valid(coin):
		return
	coin = RigidBody3D.new()
	var cmi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	cm.material = mat
	cmi.mesh = cm
	coin.add_child(cmi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.15
	coin.add_child(cs)
	cs.shape = ss
	coin.set_meta("coin", true)
	if cam == null:
		_ensure_nodes()
	coin.position = cam.global_position + (-cam.global_transform.basis.z) * 0.5
	var vel: Vector3 = -cam.global_transform.basis.z * float(Cfg.coin_toss_velocity)
	vel.y += Cfg.coin_toss_velocity * 0.6
	coin.linear_velocity = vel
	coin.angular_velocity = Vector3(20.0, 5.0, 20.0)
	add_child(coin)
	coin_age = 0.0
	coin_tossed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if dead or disabled:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-ev.relative.x * Cfg.mouse_sensitivity, -ev.relative.y * Cfg.mouse_sensitivity)
	if ev.is_action_pressed("dash"):
		_want_dash = true
	if ev.is_action_pressed("parry"):
		request_parry()
	if ev.is_action_pressed("weapon_1"):
		weapon = 0
	if ev.is_action_pressed("weapon_2"):
		weapon = 1
	if ev.is_action_pressed("weapon_3") and weapons[2]:
		weapon = 2
	if ev.is_action_pressed("coin"):
		toss_coin()


func _apply_look(dyaw: float, dpitch: float) -> void:
	if Cfg.invert_look:
		dpitch = -dpitch
	yaw += dyaw
	pitch = clampf(pitch + dpitch, -1.45, 1.45)
	rotation.y = yaw
	if head:
		head.rotation.x = pitch


func _gather_move() -> Vector2:
	if touch_move.length() > 0.05:
		return touch_move
	var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var deadzone := float(Settings.current.get("stick_deadzone", STICK_DEAD))
	if j.length() > deadzone:
		return Vector2(j.limit_length(1.0).x, -j.limit_length(1.0).y)
	return Input.get_vector("move_left", "move_right", "move_back", "move_forward")


func _physics_process(dt: float) -> void:
	if dead or disabled:
		return
	if cam == null or head == null or muzzle == null:
		_ensure_nodes()
		if cam == null:
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
			if coin.is_inside_tree():
				coin.queue_free()
			else:
				coin.free()
			coin = null

	# --- look: gamepad right stick + accumulated touch deltas
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var look_deadzone := float(Settings.current.get("stick_deadzone", STICK_DEAD))
	if rs.length() > look_deadzone:
		_apply_look(-rs.x * Cfg.stick_look_speed * dt, -rs.y * Cfg.stick_look_speed * dt)
	if touch_look.length() > 0.0:
		_apply_look(-touch_look.x * 0.004, -touch_look.y * 0.004)
		touch_look = Vector2.ZERO

	var m := _gather_move()
	var wish := (transform.basis * Vector3(m.x, 0.0, -m.y)).normalized()
	var grounded := is_on_floor()

	# --- jump (hold-to-bhop, no fall damage anywhere)
	var jump := Input.is_action_pressed("jump") or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or touch_jump
	if grounded and jump:
		velocity.y = Cfg.jump_velocity

	# --- slide
	var want_slide := Input.is_action_pressed("slide") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or touch_slide
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
		var target: Vector3 = wish * float(Cfg.walk_speed)
		var accel: float = float(Cfg.accel_ground) if grounded else float(Cfg.accel_air)
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
			or Input.is_action_pressed("fire") \
			or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	if firing:
		try_fire()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func try_fire() -> void:
	if fire_cd > 0.0:
		return
	match weapon:
		2:
			fire_cd = Cfg.nailgun_cooldown
		1:
			fire_cd = Cfg.shotgun_cooldown
		_:
			fire_cd = Cfg.revolver_cooldown
	var pellets: int = 1 if weapon == 0 else int(Cfg.shotgun_pellets)
	var spread: float = 0.0 if weapon == 0 else float(Cfg.shotgun_spread)
	var damage: float
	match weapon:
		1:
			damage = Cfg.shotgun_damage
		2:
			damage = Cfg.nailgun_damage
		_:
			damage = Cfg.revolver_damage
	damage *= damage_mult
	pellets = 1 if weapon == 2 else pellets
	spread = 0.015 if weapon == 2 else spread
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
		if coin.is_inside_tree():
			coin.queue_free()
		else:
			coin.free()
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
