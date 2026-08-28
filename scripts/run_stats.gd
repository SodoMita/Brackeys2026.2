class_name RunStats
extends RefCounted
## Per-run scoreboard: scrap economy, style meter, kill/room counters.
##
## Node-free on purpose — this is the state the HUD renders and the result
## screen reports, and it needs to be assertable without booting a level.
## Style maths is delegated to CombatLogic so the rank thresholds stay defined
## in exactly one place.
##
## Costs are passed in rather than read from Cfg, matching CombatLogic's
## convention; the game root owns the Cfg read.

enum Purchase { NAILGUN, PLATING, OVERCLOCK }

var scrap := 0
var style := 0.0
var kills := 0
var boss_kills := 0
var rooms_cleared := 0
var shots_fired := 0
var purchases: Dictionary = {}

var _decay_base := 6.0
var _decay_scale := 0.04


func configure(decay_base: float, decay_scale: float) -> void:
	_decay_base = decay_base
	_decay_scale = decay_scale


func add_style(amount: float) -> void:
	style = maxf(0.0, style + amount)


## Style bleeds off over time so a rank has to be kept, not banked.
func tick(dt: float) -> void:
	if style <= 0.0 or dt <= 0.0:
		return
	style = maxf(0.0, style - CombatLogic.decay_rate(style, _decay_base, _decay_scale) * dt)


func on_hurt() -> void:
	style = CombatLogic.on_hurt(style)


func rank() -> String:
	return CombatLogic.rank_for_points(style)


func record_kill(kind: String, scrap_value: int) -> void:
	kills += 1
	if kind == "boss":
		boss_kills += 1
	scrap = maxi(0, scrap + int(scrap_value))


func record_shot() -> void:
	shots_fired += 1


func room_clear() -> void:
	rooms_cleared += 1


func can_afford(cost: int) -> bool:
	return cost <= 0 or scrap >= int(cost)


## Spend returns false when the player cannot pay; callers must not apply the
## upgrade in that case.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	scrap = maxi(0, scrap - int(cost))
	return true


func owns(index: int) -> bool:
	return bool(purchases.get(index, false))


func mark_owned(index: int) -> void:
	purchases[index] = true


## Accuracy as a 0..1 fraction; 0.0 when nothing was fired yet.
func accuracy() -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf(float(kills) / float(shots_fired), 0.0, 1.0)
