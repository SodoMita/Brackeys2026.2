extends CharacterBody3D
## COLT — the colleague. Follows the player and lays down support fire.
## (Until he doesn't.)

signal shot

var fire_cd := 0.0
var hidden := false
var shoot_t := 0.0
var sprite: AnimatedSprite3D = null
var player_ref: Node3D = null
var enemy_pool: Node3D = null


func _init() -> void:
	var pc := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.6
	pc.shape = caps
	pc.position = Vector3(0.0, 0.8, 0.0)
	add_child(pc)


func _ready() -> void:
	sprite = SpriteLib.build("colt")
	if sprite:
		add_child(sprite)
	else:
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


func vanish() -> void:
	hidden = true
	visible = false
	set_physics_process(false)


func _physics_process(dt: float) -> void:
	if hidden:
		return
	if dt < 0.0:
		dt = 0.0
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
		if fire_cd <= 0.0 and enemy_pool and is_instance_valid(enemy_pool):
			var best: Node3D = null
			var bd := 25.0
			for en in enemy_pool.get_children():
				if is_instance_valid(en) and en.has_method("take_damage"):
					var ed: float = en.global_position.distance_to(global_position)
					if ed < bd:
						bd = ed
						best = en
			if best:
				fire_cd = Cfg.companion_fire_cd
				var aim := best.global_position + Vector3(0, 1, 0) - global_position
				var dir := aim.normalized() if aim.length_squared() > 0.0001 else Vector3.FORWARD
				best.take_damage(Cfg.companion_damage, dir, 1.0)
				shoot_t = 0.3
				shot.emit()
	if sprite and is_instance_valid(sprite) and player_ref and is_instance_valid(player_ref):
		sprite.flip_h = player_ref.global_position.x < global_position.x
		if sprite.sprite_frames == null:
			pass
		elif shoot_t > 0.0 and sprite.sprite_frames.has_animation("act"):
			if sprite.animation != &"act":
				sprite.play("act")
		elif Vector2(velocity.x, velocity.z).length() > 0.5 and sprite.sprite_frames.has_animation("walk"):
			if sprite.animation != &"walk":
				sprite.play("walk")
		elif sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != &"idle":
				sprite.play("idle")
	shoot_t = maxf(shoot_t - dt, 0.0)
	move_and_slide()
