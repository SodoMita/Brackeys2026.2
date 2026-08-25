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
		if candidate == null or not is_instance_valid(candidate):
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
