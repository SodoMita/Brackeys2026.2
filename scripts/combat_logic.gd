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
		return "D"
	var rank := String(ranks[0])
	for i in mini(thresholds.size(), ranks.size()):
		if points >= float(thresholds[i]):
			rank = String(ranks[i])
	return rank


## Points lost per second — higher ranks decay faster.
static func decay_rate(points: float, base: float = 6.0, scale: float = 0.04) -> float:
	return base + maxf(points, 0.0) * scale


## Getting hurt halves your style.
static func on_hurt(points: float) -> float:
	return maxf(points, 0.0) * 0.5


## A parry pressed `age` seconds ago is still inside the active window.
static func parry_active(age: float, active_window: float) -> bool:
	if active_window < 0.0:
		return false
	return age >= 0.0 and age <= active_window


## Ricochet picks the `count` nearest living enemies.
static func _pos(n: Node3D) -> Vector3:
	if n == null or not is_instance_valid(n):
		return Vector3.ZERO
	return n.global_position if n.is_inside_tree() else n.position


static func nearest_targets(from: Vector3, candidates: Array, count: int) -> Array:
	if count <= 0 or candidates.is_empty():
		return []
	var sorted: Array = []
	for c in candidates:
		if c != null and is_instance_valid(c) and c is Node3D:
			sorted.append(c)
	sorted.sort_custom(func(a, b):
		return _pos(a).distance_squared_to(from) < _pos(b).distance_squared_to(from))
	return sorted.slice(0, mini(count, sorted.size()))


## Wave composition used by the room director (pure, unit-testable).
static func wave_composition(room: int, wave_in_room: int) -> Dictionary:
	var hounds := maxi(0, 3 + room + wave_in_room)
	var spitters := 0
	if room + wave_in_room >= 2:
		spitters = maxi(0, 1 + wave_in_room)
	return {"hounds": hounds, "spitters": spitters}


## Shop purchase result: {ok, scrap, max_hp, damage_mult, weapons, weapon}.
static func apply_purchase(item: int, scrap: int, max_hp: float, hp: float,
		damage_mult: float, weapons: Array, costs: Array, plating_hp: float,
		overclock_mult: float) -> Dictionary:
	var out := {
		"ok": false,
		"scrap": scrap,
		"max_hp": max_hp,
		"hp": hp,
		"damage_mult": damage_mult,
		"weapons": weapons.duplicate(),
		"weapon": -1,
		"reason": "",
	}
	if item < 0 or item > 2 or costs.size() < 3:
		out.reason = "bad_item"
		return out
	var cost: int = int(costs[item])
	if item == 0 and bool(out.weapons[2]):
		out.reason = "owned"
		return out
	if scrap < cost:
		out.reason = "broke"
		return out
	out.scrap = scrap - cost
	out.ok = true
	match item:
		0:
			out.weapons[2] = true
			out.weapon = 2
		1:
			out.max_hp = max_hp + plating_hp
			out.hp = minf(hp + plating_hp, out.max_hp)
		2:
			out.damage_mult = damage_mult * overclock_mult
	return out
