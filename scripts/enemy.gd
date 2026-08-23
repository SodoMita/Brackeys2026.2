extends CharacterBody3D
## "Hound": melee chaser with a telegraphed strike (parry-able).

signal died(pos: Vector3)
signal windup
signal attacked
signal volley(dir: Vector3, origin: Vector3)

var hp: float
var speed := 7.5
var atk_cd := 0.0
var windup_t := -1.0
var stagger_t := 0.0
var target: Node3D
var ranged := false
var eyes: Array = []


func _init() -> void:
	hp = Cfg.enemy_hp
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.45
	cm.height = 1.5
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.35, 0.03, 0.05)
	bm.roughness = 0.6
	bm.emission_enabled = true
	bm.emission = Color(0.8, 0.05, 0.1)
	bm.emission_energy_multiplier = 0.35
	cm.material = bm
	body.mesh = cm
	body.position = Vector3(0.0, 0.75, 0.0)
	add_child(body)
	for sx in [-0.16, 0.16]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.06
		em.height = 0.12
		em.radial_segments = 8
		em.rings = 4
		var emat := StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.albedo_color = Color(1.0, 0.9, 0.3)
		em.material = emat
		eye.mesh = em
		eye.position = Vector3(sx, 1.25, -0.38)
		add_child(eye)
		eyes.append(eye)


func stagger(t: float) -> void:
	stagger_t = maxf(stagger_t, t)
	windup_t = -1.0


func take_damage(d: float, dir: Vector3, knock: float) -> void:
	hp -= d
	velocity += dir * knock
	if hp <= 0.0:
		died.emit(global_position)
		queue_free()


func _set_telegraph(on: bool) -> void:
	var col := Color(1.0, 1.0, 1.0) if on else Color(1.0, 0.9, 0.3)
	for e in eyes:
		(e.mesh as SphereMesh).material.set("albedo_color", col)


func _physics_process(dt: float) -> void:
	velocity.y -= Cfg.gravity * dt
	atk_cd = maxf(atk_cd - dt, 0.0)
	if stagger_t > 0.0:
		stagger_t -= dt
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
		move_and_slide()
		return
	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if windup_t >= 0.0:
			# telegraphed strike in progress: stand still, then hit
			windup_t -= dt
			velocity.x = 0.0
			velocity.z = 0.0
			if windup_t <= 0.0:
				windup_t = -1.0
				_set_telegraph(false)
				if ranged:
					volley.emit((target.global_position - global_position).normalized(), global_position + Vector3(0, 1.2, 0))
					atk_cd = Cfg.spitter_cd
				elif d < Cfg.enemy_attack_range + 0.6:
					attacked.emit()
					atk_cd = Cfg.enemy_strike_cooldown
		elif ranged:
			# keep mid range and strafe
			var dir := to.normalized()
			var want := 13.0
			var move := 0.0
			if d > want + 3.0:
				move = 1.0
			elif d < want - 4.0:
				move = -1.0
			velocity.x = move_toward(velocity.x, dir.x * speed * move, 50.0 * dt)
			velocity.z = move_toward(velocity.z, dir.z * speed * move, 50.0 * dt)
			if d > 0.01:
				look_at(global_position + dir, Vector3.UP)
			if atk_cd <= 0.0:
				windup_t = Cfg.enemy_windup
				_set_telegraph(true)
				windup.emit()
		elif d > Cfg.enemy_attack_range:
			var dir := to.normalized()
			velocity.x = move_toward(velocity.x, dir.x * speed, 50.0 * dt)
			velocity.z = move_toward(velocity.z, dir.z * speed, 50.0 * dt)
			if d > 0.01:
				look_at(global_position + dir, Vector3.UP)
		elif atk_cd <= 0.0:
			windup_t = Cfg.enemy_windup
			_set_telegraph(true)
			windup.emit()
	move_and_slide()
