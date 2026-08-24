extends CharacterBody3D
## COLT — the colleague. Follows the player and lays down support fire.
## (Until he doesn't.)
## Now with SpriteActor front/back (Seirin triangulation)
## Scene-friendly: works from .tscn or procedurally.

signal shot

var fire_cd := 0.0
var hidden := false
var shoot_t := 0.0
var sprite: Node3D = null # SpriteActor or AnimatedSprite3D
var player_ref: Node3D = null
var enemy_pool: Node3D = null


func _init() -> void:
	pass


func _ready() -> void:
	_ensure_collision()
	_ensure_visuals()


func _ensure_collision() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var caps := CapsuleShape3D.new()
		caps.radius = 0.4
		caps.height = 1.6
		col.shape = caps
		col.position = Vector3(0.0, 0.8, 0.0)
		add_child(col)


func _ensure_visuals() -> void:
	# Reuse existing sprite if scene provides one
	for child in get_children():
		if child is SpriteActor or child is AnimatedSprite3D:
			sprite = child
			return
	var actor = SpriteLib.build_actor("colt")
	if actor:
		sprite = actor
		add_child(actor)
	else:
		var legacy = SpriteLib.build("colt")
		if legacy:
			sprite = legacy
			add_child(legacy)
		else:
			var body := MeshInstance3D.new()
			body.name = "FallbackBody"
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


func _get_anim_sprite() -> AnimatedSprite3D:
	if sprite == null:
		return null
	if sprite is SpriteActor:
		return sprite.sprite
	if sprite is AnimatedSprite3D:
		return sprite
	return null


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
				shoot_t = 0.3
				shot.emit()
	if sprite and player_ref and is_instance_valid(player_ref):
		var to_player := player_ref.global_position - global_position
		var fwd := -global_transform.basis.z
		# if moving, forward is velocity dir
		var vel2 := Vector2(velocity.x, velocity.z)
		if vel2.length() > 0.5:
			fwd = Vector3(velocity.x, 0, velocity.z).normalized()
		else:
			# when idle, face player slightly
			fwd = -to_player
			if fwd.length_squared() < 0.001:
				fwd = Vector3(0, 0, -1)

		if sprite is SpriteActor:
			sprite.update_direction(to_player, fwd)
			if shoot_t > 0.0:
				sprite.play("act")
			elif vel2.length() > 0.5:
				sprite.play("walk")
			else:
				sprite.play("idle")
		else:
			var as3 := _get_anim_sprite()
			if as3:
				as3.flip_h = player_ref.global_position.x < global_position.x
				if shoot_t > 0.0:
					if as3.animation != &"act" and as3.sprite_frames.has_animation("act"):
						as3.play("act")
				elif vel2.length() > 0.5:
					if as3.animation != &"walk" and as3.sprite_frames.has_animation("walk"):
						as3.play("walk")
				elif as3.sprite_frames.has_animation("idle"):
					if as3.animation != &"idle":
						as3.play("idle")
	shoot_t = maxf(shoot_t - dt, 0.0)
	move_and_slide()
