class_name CombatLogic
extends RefCounted
## Pure combat math for the FPS: blood-healing, style scoring, ranks.
## No nodes, no RNG — fully unit-testable.

const MAX_HP := 100.0
const HEAL_FACTOR := 0.8

## Dealing damage restores health (blood mechanic).
static func heal_on_damage(current_hp: float, damage: float) -> float:
	return clampf(current_hp + damage * HEAL_FACTOR, 0.0, MAX_HP)


## Style points awarded per action.
static func style_points(action: String) -> float:
	match action:
		"hit":
			return 5.0
		"headshot":
			return 12.0
		"airshot":
			return 10.0
		"slide_kill":
			return 15.0
		"kill":
			return 20.0
		"dash_kill":
			return 8.0
		_:
			return 0.0


const RANKS := ["D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_THRESHOLDS := [0.0, 40.0, 100.0, 180.0, 280.0, 400.0, 550.0]

## Style rank letter for an accumulated score.
static func rank_for_points(points: float) -> String:
	var rank := RANKS[0]
	for i in RANK_THRESHOLDS.size():
		if points >= RANK_THRESHOLDS[i]:
			rank = RANKS[i]
	return rank


## Points lost per second — higher ranks decay faster.
static func decay_rate(points: float) -> float:
	return 6.0 + maxf(points, 0.0) * 0.04


## Getting hurt halves your style, ULTRAKILL-style.
static func on_hurt(points: float) -> float:
	return points * 0.5
