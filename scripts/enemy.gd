extends CharacterBody3D
## "Hound": melee chaser with a telegraphed strike (parry-able).
## Now uses SpriteActor with front/back views (Seirin triangulation).
## Scene-friendly: works both procedurally and from .tscn.
## _init creates fallback collision so headless tests pass.

signal died(pos: Vector3)
signal windup
signal attacked
signal volley(dir: Vector3, origin: Vector3)

@export_enum("hound", "spitter", "boss", "colt") var kind := "hound"
@export var ranged := false
@export var custom_hp := -1.0
@export var custom_speed := -1.0
@export var is_boss := false

var hp: float = 60.0
var speed := 7.5
var dead := false
var atk_cd := 0.0
var windup_t := -1.0
var stagger_t := 0.0
var target: Node3D
var sprite: Node3D = null # can be SpriteActor or AnimatedSprite3D (legacy)
var eyes: Array = []


func _init() -> void:
	hp = Cfg.enemy_hp if Cfg and "enemy_hp" in Cfg else 60.0
	var pc := CollisionShape3D.new()
	pc.name = "CollisionShape3D"
	var caps := CapsuleShape3D.new()
	caps.radius = 0.45
	caps.height = 1.5
	pc.shape = caps
	pc.position = Vector3(0.0, 0.75, 0.0)
	add_child(pc)


func _ready() -> void:
	_ensure_collision()
	_ensure_visuals()
	# Apply config
	if custom_hp > 0:
		hp = custom_hp
	else:
		if is_boss or kind == "boss":
			hp = Cfg.boss_hp if Cfg and "boss_hp" in Cfg else 400.0
		else:
			hp = Cfg.enemy_hp if Cfg and "enemy_hp" in Cfg else 60.0

	if custom_speed > 0:
		speed = custom_speed
	else:
		if is_boss or kind == "boss":
			speed = Cfg.boss_speed if Cfg and "boss_speed" in Cfg else 9.0
		else:
			speed = Cfg.enemy_speed if Cfg and "enemy_speed" in Cfg else 7.5

	if is_boss or kind == "boss":
		scale = Vector3(1.5, 1.5, 1.5)
		if not has_meta("scrap"):
			set_meta("scrap", Cfg.scrap_boss if Cfg else 100)
	elif kind == "spitter":
		if not has_meta("scrap"):
			set_meta("scrap", Cfg.scrap_spitter if Cfg else 15)
	else:
		if not has_meta("scrap"):
			set_meta("scrap", Cfg.scrap_hound if Cfg else 10)


func _ensure_collision() -> void:
	var cols: Array = []
	for c in get_children():
		if c is CollisionShape3D:
			cols.append(c)
	if cols.size() > 1:
		for i in range(cols.size() - 1):
			if cols[i].is_inside_tree():
				cols[i].queue_free()
			else:
				cols[i].free()
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var caps := CapsuleShape3D.new()
		caps.radius = 0.45
		caps.height = 1.5
		col.shape = caps
		col.position = Vector3(0.0, 0.75, 0.0)
		add_child(col)


func _ensure_visuals() -> void:
	# If scene already has a SpriteActor or AnimatedSprite3D, keep it
	for child in get_children():
		if child is SpriteActor or child is AnimatedSprite3D:
			if sprite == null:
				sprite = child
			# If more than one visual, keep first
			continue
	if sprite != null:
		return
	# Try to build from SpriteLib
	var actor = SpriteLib.build_actor(kind)
	if actor:
		sprite = actor
		add_child(actor)
	else:
		var legacy = SpriteLib.build(kind)
		if legacy:
			sprite = legacy
			add_child(legacy)
		else:
			# fallback: solid capsule with eyes (frames not present)
			var body := MeshInstance3D.new()
			body.name = "FallbackBody"
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
				eye.name = "Eye%d" % (1 if sx < 0 else 2)
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
	if dead:
		return
	hp -= d
	velocity += dir * knock
	if hp <= 0.0:
		dead = true
		var death_position := global_position if is_inside_tree() else position
		died.emit(death_position)
		if is_inside_tree():
			queue_free()
		else:
			free()


func _set_telegraph(on: bool) -> void:
	if sprite:
		if sprite is SpriteActor:
			sprite.set_modulate(Color(3.0, 3.0, 3.0) if on else Color(1, 1, 1))
		elif sprite is AnimatedSprite3D:
			sprite.modulate = Color(3.0, 3.0, 3.0) if on else Color(1, 1, 1)
		return
	var col := Color(1.0, 1.0, 1.0) if on else Color(1.0, 0.9, 0.3)
	for e in eyes:
		if is_instance_valid(e):
			(e.mesh as SphereMesh).material.set("albedo_color", col)


func _get_anim_sprite() -> AnimatedSprite3D:
	if sprite == null:
		return null
	if sprite is SpriteActor:
		return sprite.sprite
	if sprite is AnimatedSprite3D:
		return sprite
	return null


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
			windup_t -= dt
			velocity.x = 0.0
			velocity.z = 0.0
			if windup_t <= 0.0:
				windup_t = -1.0
				_set_telegraph(false)
				if ranged:
					var volley_dir := to.normalized()
					if d > 0.01:
						volley.emit(volley_dir, global_position + Vector3(0.0, 1.0, 0.0))
					atk_cd = Cfg.spitter_cd
				else:
					if d < Cfg.enemy_attack_range + 0.6:
						attacked.emit()
					atk_cd = Cfg.enemy_strike_cooldown
		elif ranged:
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

	if sprite and target and is_instance_valid(target):
		var to_target := target.global_position - global_position
		# forward = where we look (-Z)
		var fwd := -global_transform.basis.z
		if sprite is SpriteActor:
			sprite.update_direction(to_target, fwd)
			# flip_h based on cross product for side readability
			var right := global_transform.basis.x
			var cross_dot := right.dot(to_target)
			# keep flip for left/right when front
			if not sprite.is_back:
				sprite.set_flip_h(cross_dot < 0)
		else:
			var as3 := _get_anim_sprite()
			if as3:
				as3.flip_h = target.global_position.x < global_position.x

		# animation selection
		if windup_t >= 0.0:
			if sprite is SpriteActor:
				if sprite.sprite.sprite_frames.has_animation("act_front") or sprite.sprite.sprite_frames.has_animation("act"):
					sprite.play("act")
			else:
				var as3 := _get_anim_sprite()
				if as3 and as3.sprite_frames.has_animation("act"):
					if as3.animation != &"act":
						as3.play("act")
		elif horizontal_speed_v() > 0.5:
			if sprite is SpriteActor:
				sprite.play("walk")
			else:
				var as3 := _get_anim_sprite()
				if as3 and as3.animation != &"walk" and (as3.sprite_frames.has_animation("walk") or as3.sprite_frames.has_animation("walk_front")):
					# choose best walk
					if as3.sprite_frames.has_animation("walk_front"):
						as3.play("walk_front")
					else:
						as3.play("walk")
	move_and_slide()


func horizontal_speed_v() -> float:
	return Vector2(velocity.x, velocity.z).length()
