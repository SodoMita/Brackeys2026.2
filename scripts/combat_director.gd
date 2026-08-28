class_name CombatDirector
extends Node
## Damage resolution — the layer that turns "an event happened" into "hit
## points moved".
##
## Nothing else in the project calls `take_damage`: player.gd raycasts, finds
## a collider and only *emits* `fired`; enemy.gd telegraphs, then only *emits*
## `attacked`/`volley`. Without this node guns do no damage, enemies never
## acquire a target, and spitters fire nothing. This is the single place that
## connects those signals to consequences, so the rules are reviewable in one
## file and every number still comes from Cfg.
##
## Add under the game root:
##   var combat := CombatDirector.new()
##   add_child(combat)
##   combat.setup(player, enemy_pool)

signal enemy_hit(enemy: Node3D, amount: float, headshot: bool)
signal player_hit(amount: float)
signal parry_success

const PROJECTILE_SCENE := "res://scenes/projectile.tscn"
## Generous body radius for the projectile hit test (the capsule is 0.45 wide).
const TARGET_RADIUS := 0.55
const TARGET_HEIGHT := 1.6

var player: CharacterBody3D = null
var enemy_pool: Node3D = null
var stats: RunStats = null

## Live spitter rounds, hit-tested here because projectile.gd flies blind.
var _projectiles: Array = []


func setup(p_player: CharacterBody3D, p_pool: Node3D, p_stats: RunStats = null) -> void:
	player = p_player
	enemy_pool = p_pool
	stats = p_stats


## Point an enemy at the player and hook up its attack signals. Called by
## whoever spawns it (LevelDirector via game_root).
func register(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if "target" in enemy:
		enemy.target = player
	if enemy.has_signal("attacked") and not enemy.attacked.is_connected(_on_enemy_attacked):
		enemy.attacked.connect(_on_enemy_attacked.bind(enemy))
	if enemy.has_signal("volley") and not enemy.volley.is_connected(_on_enemy_volley):
		enemy.volley.connect(_on_enemy_volley)


# --- player -> enemy -------------------------------------------------------


func on_player_fired(enemy: Node3D, headshot: bool, _airborne: bool,
		damage: float, _ricochet: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("take_damage"):
		return
	if enemy.get("dead") == true:
		return
	var amount := CombatLogic.apply_headshot(damage, _cfg_float("headshot_mult", 2.0), headshot)
	var dir := _shot_direction(enemy)
	enemy.take_damage(amount, dir, CombatLogic.knockback(amount,
		_cfg_float("knockback_scale", 0.35)))
	enemy_hit.emit(enemy, amount, headshot)
	_heal_player(amount)


## Blood heals: ULTRAKILL's core loop, and the reason aggression is correct.
func _heal_player(amount: float) -> void:
	if player == null or not is_instance_valid(player) or not ("hp" in player):
		return
	player.hp = CombatLogic.heal_on_damage(float(player.hp), amount,
		_cfg_float("heal_factor", 0.8), _cfg_float("max_hp", 100.0))


func _shot_direction(enemy: Node3D) -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.FORWARD
	var d := _pos(enemy) - _pos(player)
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD


# --- enemy -> player -------------------------------------------------------


func _on_enemy_attacked(enemy: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _parrying():
		_on_parry_success(enemy)
		return
	player.take_damage(_cfg_float("enemy_damage", 12.0))
	player_hit.emit(_cfg_float("enemy_damage", 12.0))
	if stats != null:
		stats.on_hurt()


func _on_parry_success(enemy: Node3D) -> void:
	if enemy != null and is_instance_valid(enemy) and "stagger_t" in enemy:
		enemy.stagger_t = _cfg_float("parry_stagger", 1.2)
	if player != null and is_instance_valid(player) and "hp" in player:
		player.hp = CombatLogic.heal_on_damage(float(player.hp),
			_cfg_float("parry_heal_bonus", 15.0), 1.0, _cfg_float("max_hp", 100.0))
	# player.gd arms the parry window but never reports a landed one. Style is
	# NOT awarded here — game_root owns the scoreboard and listens for this.
	if player != null and is_instance_valid(player) and player.has_signal("parried"):
		player.parried.emit()
	parry_success.emit()


func _parrying() -> bool:
	return player != null and is_instance_valid(player) \
		and player.has_method("is_parry_active") and player.is_parry_active()


# --- bullet hell -----------------------------------------------------------


func _on_enemy_volley(dir: Vector3, origin: Vector3) -> void:
	if enemy_pool == null:
		return
	var count := _cfg_int("spitter_volley", 3)
	for d in CombatLogic.volley_dirs(dir, count, _cfg_float("spitter_spread", 0.22)):
		_spawn_projectile(d, origin)


func _spawn_projectile(dir: Vector3, origin: Vector3) -> Node3D:
	if enemy_pool == null or not ResourceLoader.exists(PROJECTILE_SCENE):
		return null
	var packed: PackedScene = load(PROJECTILE_SCENE)
	if packed == null:
		return null
	var proj: Node3D = packed.instantiate()
	proj.global_position = origin
	if "vel" in proj:
		proj.vel = dir.normalized() * _cfg_float("projectile_speed", 12.0)
	if "damage" in proj:
		proj.damage = _cfg_float("projectile_damage", 10.0)
	enemy_pool.add_child(proj)
	if proj.has_signal("consumed"):
		proj.consumed.connect(_on_projectile_consumed.bind(proj))
	_projectiles.append(proj)
	return proj


func _physics_process(_dt: float) -> void:
	if _projectiles.is_empty():
		return
	for i in range(_projectiles.size() - 1, -1, -1):
		var proj: Node3D = _projectiles[i]
		if proj == null or not is_instance_valid(proj):
			_projectiles.remove_at(i)
			continue
		if proj.get("reflected") == true:
			var victim := _enemy_hit_by(proj)
			if victim == null:
				continue
			_resolve_reflected_hit(proj, victim)
			if proj.is_inside_tree():
				proj.queue_free()
			else:
				proj.free()
			_projectiles.remove_at(i)
			continue
		if not _hits_player(proj):
			continue
		var parried_now := _parrying()
		# Consume it here rather than waiting for the lifetime to run out.
		if proj.has_signal("consumed"):
			proj.consumed.emit(_pos(proj), parried_now)
		if parried_now and proj.get("reflected") == true:
			# The parry sent the round back at an enemy; keep tracking it.
			continue
		if proj.is_inside_tree():
			proj.queue_free()
		_projectiles.remove_at(i)


func _hits_player(proj: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return CombatLogic.projectile_hits(_pos(proj), _pos(player),
		_cfg_float("projectile_radius", 0.18) + TARGET_RADIUS, TARGET_HEIGHT)


## First living enemy the (reflected) round has reached. null when there is
## nothing to hit — the round then keeps flying until its lifetime ends.
func _enemy_hit_by(proj: Node3D) -> Node3D:
	if enemy_pool == null:
		return null
	var radius := _cfg_float("projectile_radius", 0.18) + TARGET_RADIUS
	for child in enemy_pool.get_children():
		var enemy := child as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("dead") == true or not enemy.has_method("take_damage"):
			continue
		if CombatLogic.projectile_hits(_pos(proj), _pos(enemy), radius, TARGET_HEIGHT):
			return enemy
	return null


## A parried spit turns into the player's projectile: same damage, multiplied
## by Cfg, aimed at the nearest living enemy. Returns true when the round was
## reflected and must stay tracked (it is still flying).
func _reflect_at_nearest_enemy(proj: Node3D) -> bool:
	if proj == null or not is_instance_valid(proj) or enemy_pool == null:
		return false
	var candidates: Array = []
	for child in enemy_pool.get_children():
		var enemy := child as Node3D
		if enemy != null and is_instance_valid(enemy) and enemy.get("dead") != true \
				and enemy.has_method("take_damage"):
			candidates.append(enemy)
	var targets := CombatLogic.nearest_targets(_pos(proj), candidates, 1)
	if targets.is_empty():
		return false  # nothing to throw it at; the parry still healed and scored
	var target: Node3D = targets[0]
	proj.set("reflected", true)
	var dir := _pos(target) - _pos(proj)
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	var speed := _cfg_float("projectile_speed", 12.0) \
		* _cfg_float("reflect_speed_mult", 1.4)
	proj.set("vel", dir.normalized() * speed)
	return true


func _resolve_reflected_hit(proj: Node3D, enemy: Node3D) -> void:
	var damage := float(proj.get("damage")) * _cfg_float("reflect_damage_mult", 2.0)
	var dir := _shot_direction(enemy)
	enemy.take_damage(damage, dir, CombatLogic.knockback(damage,
		_cfg_float("knockback_scale", 0.35)))
	enemy_hit.emit(enemy, damage, false)


func _untrack(proj: Node3D) -> void:
	if proj == null:
		return
	var idx := _projectiles.find(proj)
	if idx >= 0:
		_projectiles.remove_at(idx)


func _on_projectile_consumed(_pos_hit: Vector3, parried: bool, proj: Node3D) -> void:
	if proj != null and is_instance_valid(proj) and proj.get("reflected") == true:
		# A reflected round that ran out of lifetime: it can never come back
		# to hurt the player.
		_untrack(proj)
		return
	if parried:
		_on_parry_success(null)
		if _reflect_at_nearest_enemy(proj):
			return  # round redirected at an enemy; keep tracking it
		_untrack(proj)
		return
	_untrack(proj)
	if player == null or not is_instance_valid(player):
		return
	# Expiry path (projectile.gd emits `consumed` when its lifetime ends):
	# a round that burned out far from the player was dodged, not landed.
	# The real-hit path already passed _hits_player before emitting.
	if proj != null and is_instance_valid(proj) and not _hits_player(proj):
		return
	var damage := _cfg_float("projectile_damage", 10.0)
	if proj != null and is_instance_valid(proj) and "damage" in proj:
		damage = float(proj.damage)
	player.take_damage(damage)
	player_hit.emit(damage)
	if stats != null:
		stats.on_hurt()


# --- helpers ---------------------------------------------------------------


static func _pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


static func _cfg_float(prop: String, fallback: float) -> float:
	if Cfg != null and prop in Cfg:
		return float(Cfg.get(prop))
	return fallback


static func _cfg_int(prop: String, fallback: int) -> int:
	if Cfg != null and prop in Cfg:
		return int(Cfg.get(prop))
	return fallback
