extends CharacterBody3D
## COLT — the colleague. Follows the player and lays down support fire.
## (Until he doesn't.)

signal shot

var fire_cd := 0.0
var hidden := false
var player_ref: Node3D = null
var enemy_pool: Node3D = null


func _init() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.6
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.75, 0.6, 0.35)
	bm.roughness = 0.7
	cm.material = bm
	body.mesh = cm
	body.position = Vector3(0.0, 0.8, 0.0)
	add_child(body)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.3, 0.08, 0.1)
	var vmat := StandardMaterial3D.new()
	vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vmat.albedo_color = Color(0.2, 0.9, 1.0)
	vm.material = vmat
	visor.mesh = vm
	visor.position = Vector3(0.0, 1.35, -0.35)
	add_child(visor)


func vanish() -> void:
	hidden = true
	visible = false


func _physics_process(dt: float) -> void:
	if hidden:
		return
	velocity.y -= Cfg.gravity * dt
	if player_ref and is_instance_valid(player_ref):
		var player: Node3D = player_ref
		var to := player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 4.0:
			var dir := to.normalized()
			velocity.x = move_toward(velocity.x, dir.x * 8.0, 40.0 * dt)
			velocity.z = move_toward(velocity.z, dir.z * 8.0, 40.0 * dt)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
		# support fire at nearest enemy
		fire_cd = maxf(fire_cd - dt, 0.0)
		if fire_cd <= 0.0:
			var best: Node3D = null
			var bd := 25.0
			var pool: Node3D = enemy_pool
			if pool:
				for en in pool.get_children():
					if is_instance_valid(en) and en.has_method("take_damage"):
						var ed: float = en.global_position.distance_to(global_position)
						if ed < bd:
							bd = ed
							best = en
			if best:
				fire_cd = Cfg.companion_fire_cd
				var dir := (best.global_position + Vector3(0, 1, 0) - global_position).normalized()
				best.take_damage(Cfg.companion_damage, dir, 1.0)
				shot.emit()
	move_and_slide()
