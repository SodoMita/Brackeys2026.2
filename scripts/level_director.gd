class_name LevelDirector
extends Node
## Room progression: the piece that was lost when scripts/game.gd was deleted.
##
## Owns the loop the level's authored geometry implies —
##   cross trigger  ->  seal the doors behind  ->  spawn the room's wave
##   clear the room ->  open the next doors     ->  next room / victory
##
## It deliberately knows nothing about damage or style; it only decides *when*
## a fight happens and *where*. Enemy stats stay in Cfg, geometry stays in
## scenes/level_1.tscn, wave composition stays in RoomPlan (unit-tested).
##
## Add under the game root:
##   var director := LevelDirector.new()
##   add_child(director)
##   director.setup(level, enemy_pool, player)

signal room_started(room_index: int)
signal room_cleared(room_index: int)
signal level_complete
signal enemy_spawned(enemy: Node3D, room_index: int)

enum Phase { IDLE, FIGHTING, CLEARED, FINISHED }

const ENEMY_SCENES := {
	"hound": "res://scenes/enemies/hound.tscn",
	"spitter": "res://scenes/enemies/spitter.tscn",
	"boss": "res://scenes/enemies/boss.tscn",
}
## Fallback so a missing variant still spawns something rather than nothing.
const FALLBACK_ENEMY := "res://scenes/enemy.tscn"

var phase: Phase = Phase.IDLE
var room_index := -1
var alive := 0
var spawned_total := 0

var level: Node3D = null
var enemy_pool: Node3D = null
var player: Node3D = null

var _doors: Array = []
var _triggers: Array = []
var _active: Array = []


func setup(p_level: Node3D, p_pool: Node3D, p_player: Node3D) -> void:
	level = p_level
	enemy_pool = p_pool
	player = p_player
	_collect_level_nodes()
	_connect_triggers()
	# The boss gate starts shut; everything else stays open so the player can
	# walk to the first trigger unimpeded.
	_set_door(RoomPlan.seal_doors(RoomPlan.room_count() - 1), true)


func _collect_level_nodes() -> void:
	_doors.clear()
	_triggers.clear()
	if level == null:
		return
	if "doors" in level:
		for d in level.doors:
			if d != null:
				_doors.append(d)
	if "trigger_nodes" in level:
		for t in level.trigger_nodes:
			if t != null:
				_triggers.append(t)


func _connect_triggers() -> void:
	for i in range(_triggers.size()):
		var trigger: Area3D = _triggers[i]
		# One-shot per room: disconnect immediately so a re-entry cannot
		# re-trigger a wave that is already running or already cleared.
		if not trigger.body_entered.is_connected(_on_trigger_body):
			trigger.body_entered.connect(_on_trigger_body.bind(i))


func _on_trigger_body(body: Node3D, index: int) -> void:
	if phase != Phase.IDLE:
		return
	if body != player:
		return
	if index != room_index + 1:
		return  # rooms must be taken in order
	start_room(index)


## Seal the room and spawn its wave. Callable directly (tests, debug warps).
func start_room(index: int) -> void:
	if index < 0 or index >= RoomPlan.room_count():
		return
	if phase == Phase.FIGHTING:
		return
	room_index = index
	phase = Phase.FIGHTING
	_set_door(RoomPlan.seal_doors(index), true)

	var base := _wave_base_count()
	var kinds: Array = RoomPlan.composition(index, base)
	var points: Array = RoomPlan.spawn_points(index, kinds.size())
	alive = 0
	for i in range(kinds.size()):
		var pos: Vector3 = points[i] if i < points.size() else Vector3.ZERO
		var enemy := _spawn(String(kinds[i]), pos)
		if enemy == null:
			continue
		alive += 1
		spawned_total += 1
		_active.append(enemy)
	room_started.emit(index)

	if alive == 0:
		# Nothing could be spawned (missing scenes): do not soft-lock the level.
		_on_room_cleared()


func _spawn(kind: String, pos: Vector3) -> Node3D:
	if enemy_pool == null:
		return null
	var path: String = ENEMY_SCENES.get(kind, FALLBACK_ENEMY)
	if not ResourceLoader.exists(path):
		path = FALLBACK_ENEMY
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var enemy: Node3D = packed.instantiate()
	enemy.global_position = pos
	enemy_pool.add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy, room_index)
	return enemy


func _on_enemy_died(_pos: Vector3) -> void:
	if phase != Phase.FIGHTING:
		return
	alive = maxi(0, alive - 1)
	if alive == 0:
		_on_room_cleared()


func _on_room_cleared() -> void:
	_active.clear()
	phase = Phase.CLEARED
	_set_door(RoomPlan.open_doors(room_index), false)
	room_cleared.emit(room_index)
	if RoomPlan.is_boss_room(room_index):
		phase = Phase.FINISHED
		level_complete.emit()
	else:
		phase = Phase.IDLE


func _set_door(indices: Array, closed: bool) -> void:
	for i in indices:
		var idx := int(i)
		if idx < 0 or idx >= _doors.size():
			continue
		var door: Node = _doors[idx]
		if door != null and door.has_method("door_set"):
			door.call("door_set", closed)


## Count of enemies still standing right now (ignores stale bookkeeping).
func living_enemies() -> int:
	var n := 0
	for e in _active:
		if e != null and is_instance_valid(e) and not bool(e.get("dead")):
			n += 1
	return n


static func _wave_base_count() -> int:
	if Cfg != null and "wave_base_count" in Cfg:
		return int(Cfg.wave_base_count)
	return 2
