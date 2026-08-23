extends CharacterBody3D
## "Hound": melee chaser. All visuals built in the constructor so the
## node is usable without entering the tree (headless tests).

signal died(pos: Vector3)
signal attacked

var hp := 60.0
var speed := 7.5
var atk_cd := 0.0
var target: Node3D


func _init() -> void:
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
	# glowing eyes
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


func take_damage(d: float, dir: Vector3, knock: float) -> void:
	hp -= d
	velocity += dir * knock
	if hp <= 0.0:
		died.emit(global_position)
		queue_free()


func _physics_process(dt: float) -> void:
	velocity.y -= 22.0 * dt
	atk_cd = maxf(atk_cd - dt, 0.0)
	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 1.7:
			var dir := to.normalized()
			velocity.x = move_toward(velocity.x, dir.x * speed, 50.0 * dt)
			velocity.z = move_toward(velocity.z, dir.z * speed, 50.0 * dt)
			if d > 0.01:
				look_at(global_position + dir, Vector3.UP)
		elif atk_cd <= 0.0:
			atk_cd = 1.0
			attacked.emit()
	move_and_slide()
