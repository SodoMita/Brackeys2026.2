class_name CombatLogic
extends RefCounted
## Pure combat math for the FPS: blood-healing, style scoring, ranks, parry.
## No nodes, no RNG — fully unit-testable. All tuning is passed in
## (the Cfg autoload owns the designer-editable values).


static func heal_on_damage(current_hp: float, damage: float,
		heal_factor: float, max_hp: float) -> float:
	return clampf(current_hp + damage * heal_factor, 0.0, max_hp)


const RANKS_DEFAULT := ["D", "C", "B", "A", "S", "SS", "SSS"]
const THRESHOLDS_DEFAULT := [0.0, 40.0, 100.0, 180.0, 280.0, 400.0, 550.0]

## Style rank letter for an accumulated score.
static func rank_for_points(points: float,
		thresholds: Array = THRESHOLDS_DEFAULT,
		ranks: Array = RANKS_DEFAULT) -> String:
	if ranks.is_empty():
		return ""
	var rank := String(ranks[0])
	for i in mini(thresholds.size(), ranks.size()):
		if points >= thresholds[i]:
			rank = String(ranks[i])
	return rank


## Points lost per second — higher ranks decay faster.
static func decay_rate(points: float, base: float = 6.0, scale: float = 0.04) -> float:
	return base + maxf(points, 0.0) * scale


## Getting hurt halves your style.
static func on_hurt(points: float) -> float:
	return points * 0.5


## Headshots multiply the rolled damage; everything else passes through.
static func apply_headshot(base_damage: float, mult: float, is_headshot: bool) -> float:
	return base_damage * mult if is_headshot else base_damage


## Knockback impulse along the shot direction, capped so a shotgun blast at
## point-blank cannot launch an enemy across the arena.
static func knockback(damage: float, scale: float = 0.35, cap: float = 9.0) -> float:
	return clampf(maxf(damage, 0.0) * scale, 0.0, cap)


## projectile.gd flies with `monitoring = false` and only reports expiry, so
## the combat director does the hit test itself. Kept here so the rule
## (combined radii, horizontal-ish, generous on Y for a capsule) is testable.
static func projectile_hits(proj_pos: Vector3, target_pos: Vector3,
		radius: float, target_height: float = 1.6) -> bool:
	var to_target := target_pos - proj_pos
	var half := target_height * 0.5
	# Treat the player as a vertical capsule: clamp the vertical offset into
	# the body's extent, then test the remaining distance against the radius.
	var dy := clampf(to_target.y, -half, half)
	var flat_sq := to_target.x * to_target.x + to_target.z * to_target.z
	var vert := to_target.y - dy
	return flat_sq + vert * vert <= radius * radius


## Fan `count` shot directions around `center` on the XZ plane, evenly spaced
## and symmetric, so a volley of 1 lines up with `center` and a volley of 3
## straddles it. Pure and RNG-free so the pattern is testable and readable.
static func volley_dirs(center: Vector3, count: int, spread: float) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var flat := Vector3(center.x, 0.0, center.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	if count == 1:
		out.append(flat)
		return out
	var right := flat.cross(Vector3.UP).normalized()
	for i in range(count):
		var t := (float(i) / float(count - 1)) * 2.0 - 1.0  # -1 .. 1
		var d := (flat + right * (t * spread)).normalized()
		out.append(d)
	return out


## A parry pressed `age` seconds ago is still inside the active window.
static func parry_active(age: float, active_window: float) -> bool:
	return age >= 0.0 and age <= active_window


## Ricochet picks the `count` nearest living enemies.
static func _pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


static func nearest_targets(from: Vector3, candidates: Array, count: int) -> Array:
	if count <= 0:
		return []
	var sorted: Array = []
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		# Enemy nodes expose either a dead flag or HP. Plain Node3D test
		# candidates have neither and are considered living by default.
		if candidate.get("dead") == true:
			continue
		var hp = candidate.get("hp")
		if (hp is float or hp is int) and float(hp) <= 0.0:
			continue
		sorted.append(candidate)
	sorted.sort_custom(func(a, b):
		return _pos(a).distance_squared_to(from) < _pos(b).distance_squared_to(from))
	return sorted.slice(0, mini(count, sorted.size()))
