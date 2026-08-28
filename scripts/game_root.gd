extends Node3D
## Root of scenes/game.tscn.
##
## Deliberately thin about *rules* and thick about *wiring*: the numbers live
## in Cfg, the wave table in RoomPlan, the progression in LevelDirector, the
## scoreboard in RunStats and the pixels in HudController / UIManager. This
## file only connects them, which is what the deleted game.gd used to do all
## by itself.

signal run_ended(won: bool)

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var player: CharacterBody3D
var ui: UIManager
var director: LevelDirector
var combat: CombatDirector
var stats: RunStats
var hud_controller: HudController
var result_screen: ResultScreen

var _run_over := false
var _awaiting_ending := false


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody3D

	# Wire cross-references that the scene file cannot express.
	var enemies := get_node_or_null("Enemies") as Node3D
	if player != null and enemies != null:
		player.enemy_pool = enemies
	var companion := get_node_or_null("Companion")
	if companion != null and "player_ref" in companion:
		companion.player_ref = player
	var hud := get_node_or_null("HUD") as CanvasLayer
	var level := get_node_or_null("Level1")
	if level != null and hud != null and "terminals" in level:
		for terminal in level.terminals:
			if terminal == null:
				continue
			terminal.player_ref = player
			terminal.setup_ui(hud)
			if terminal.has_signal("purchase_requested"):
				terminal.purchase_requested.connect(_on_purchase)

	stats = RunStats.new()
	_configure_stats()

	combat = CombatDirector.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(player, enemies, stats)
	combat.player_hit.connect(_on_player_hit)
	combat.enemy_hit.connect(_on_enemy_hit)

	director = LevelDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(level, enemies, player)
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.room_started.connect(_on_room_started)
	director.room_cleared.connect(_on_room_cleared)
	director.level_complete.connect(_on_level_complete)

	hud_controller = HudController.new()
	hud_controller.name = "HUDController"
	add_child(hud_controller)
	hud_controller.bind(hud, player, stats, director)

	result_screen = ResultScreen.new()
	result_screen.name = "ResultScreen"
	add_child(result_screen)
	result_screen.retry_requested.connect(_retry)
	result_screen.menu_requested.connect(_quit_to_menu)

	_connect_player()

	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
	if player != null:
		ui.setup(player)

	_connect_dialogic_end()
	_play_intro()


func _process(dt: float) -> void:
	if _run_over or stats == null:
		return
	stats.tick(dt)


func _configure_stats() -> void:
	if Cfg == null:
		return
	if "decay_base" in Cfg and "decay_scale" in Cfg:
		stats.configure(float(Cfg.decay_base), float(Cfg.decay_scale))


func _connect_player() -> void:
	if player == null:
		return
	if player.has_signal("fired"):
		# Two independent listeners: CombatDirector applies the damage, this
		# script scores the style. Neither depends on the other's ordering.
		player.fired.connect(_on_player_fired)
		if combat != null:
			player.fired.connect(combat.on_player_fired)
	if player.has_signal("parried"):
		player.parried.connect(_on_player_parried)
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	# Movement/action feedback. These have no gameplay consequence, so the
	# sound hookup is the only listener they get.
	for sig in ["dashed", "slid", "coin_tossed"]:
		if player.has_signal(sig):
			player.connect(sig, _play.bind(sig if sig != "coin_tossed" else "coin"))


## Central sound entry point. `Sfx` is an autoload that no-ops when there is no
## audio driver, so callers never need to guard for headless or a missing node.
func _play(sound: String, pitch := 1.0) -> void:
	var bus := _sfx()
	if bus != null:
		bus.play(sound, pitch)


static func _sfx() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Sfx")


## A shotgun fires 7 pellets per trigger pull and `fired` reports every hit, so
## the pitch is jittered: identical samples stacked in phase read as one louder
## thud rather than a spread of shots.
func _play_shot() -> void:
	var sound := "shot"
	if player != null and is_instance_valid(player) and "weapon" in player:
		match int(player.weapon):
			1:
				sound = "shotgun"
			2:
				sound = "nailgun"
	_play(sound, randf_range(0.94, 1.06))


func _on_enemy_hit(_enemy: Node3D, _amount: float, headshot: bool) -> void:
	_play("headshot" if headshot else "hit", randf_range(0.96, 1.04))


func _on_enemy_died_sfx() -> void:
	_play("die", randf_range(0.9, 1.1))


## Bound to enemy.volley(dir, origin); only the sound is wanted here, the
## projectile spawning is CombatDirector's job.
func _on_volley_sfx(_dir: Vector3, _origin: Vector3) -> void:
	_play("spit", randf_range(0.92, 1.08))


func _on_player_hit(_amount: float) -> void:
	_play("hurt")
	if hud_controller != null:
		hud_controller.flash_hurt()


# --- style & scrap ---------------------------------------------------------


func _on_player_fired(enemy: Node3D, headshot: bool, airborne: bool,
		_damage: float, ricochet: bool) -> void:
	_play_shot()
	if stats == null:
		return
	stats.record_shot()
	# A shot into an already-defeated enemy scores nothing, matching
	# CombatDirector which also refuses to apply the damage.
	if enemy != null and is_instance_valid(enemy) and enemy.get("dead") == true:
		return
	if ricochet:
		stats.add_style(_cfg_float("style_ricochet", 18.0))
	elif airborne:
		stats.add_style(_cfg_float("style_airshot", 10.0))
	elif headshot:
		stats.add_style(_cfg_float("style_headshot", 12.0))
	else:
		stats.add_style(_cfg_float("style_hit", 5.0))


func _on_player_parried() -> void:
	_play("parry")
	if stats != null:
		stats.add_style(_cfg_float("style_parry", 25.0))


func _on_enemy_spawned(enemy: Node3D, _room_index: int) -> void:
	if enemy == null:
		return
	# Targeting + attack consequences live in CombatDirector; without this the
	# spawned enemy has no target and its AI block never runs.
	if combat != null:
		combat.register(enemy)
	if enemy.has_signal("windup"):
		enemy.windup.connect(_play.bind("windup"))
	if enemy.has_signal("volley"):
		enemy.volley.connect(_on_volley_sfx)
	if not enemy.has_signal("died"):
		return
	# Bound per-enemy so the kill can be scored against this enemy's own kind.
	enemy.died.connect(_on_enemy_killed.bind(enemy))


func _on_enemy_killed(_pos: Vector3, enemy: Node3D) -> void:
	_on_enemy_died_sfx()
	if stats == null:
		return
	var kind := "hound"
	if enemy != null and is_instance_valid(enemy) and "kind" in enemy:
		kind = String(enemy.kind)
	stats.record_kill(kind, _scrap_value(enemy, kind))

	if player != null and is_instance_valid(player):
		if "dash_t" in player and float(player.dash_t) > 0.0:
			stats.add_style(_cfg_float("style_dash_kill", 8.0))
		elif "sliding" in player and bool(player.sliding):
			stats.add_style(_cfg_float("style_slide_kill", 15.0))
		else:
			stats.add_style(_cfg_float("style_kill", 20.0))


func _scrap_value(enemy: Node3D, kind: String) -> int:
	if enemy != null and is_instance_valid(enemy) and enemy.has_meta("scrap"):
		return int(enemy.get_meta("scrap"))
	match kind:
		"boss":
			return _cfg_int("scrap_boss", 100)
		"spitter":
			return _cfg_int("scrap_spitter", 15)
	return _cfg_int("scrap_hound", 10)


# --- progression -----------------------------------------------------------


func _on_room_started(index: int) -> void:
	# The intro timeline already played at boot; a room opening only needs the
	# HUD callout, otherwise the two would talk over each other.
	if hud_controller != null:
		hud_controller.say("HOSTILES INBOUND — ROOM %d" % (index + 1))


func _on_room_cleared(index: int) -> void:
	if stats != null:
		stats.room_clear()
	if hud_controller != null:
		hud_controller.say("ROOM CLEAR")
	if not RoomPlan.is_boss_room(index):
		_say_timeline(_cfg_timeline("quip_timeline"))


func _on_level_complete() -> void:
	_end_run(true)


func _on_player_died() -> void:
	_end_run(false)


func _end_run(won: bool) -> void:
	if _run_over:
		return
	_run_over = true
	if hud_controller != null:
		hud_controller.flash_hurt(0.0)
	# Hand input back to the result card: un-pause, release the mouse, stop the
	# controller and the touch layer from fighting the buttons.
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	if player != null and is_instance_valid(player):
		player.disabled = true
	if ui != null and ui.touch_controls != null:
		ui.touch_controls.set_active(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play("victory" if won else "defeat")
	run_ended.emit(won)
	if won:
		# Let the ending play before the card covers it; the card waits for the
		# timeline to finish (or is shown straight away if none is configured).
		var timeline: Resource = _cfg_timeline("ending_timeline")
		if timeline != null and _say_timeline(timeline):
			_awaiting_ending = true
		else:
			result_screen.show_result(true, stats)
	else:
		result_screen.show_result(false, stats)


# --- shop ------------------------------------------------------------------


func _on_purchase(request: Variant) -> void:
	if stats == null or player == null or not is_instance_valid(player):
		return
	if request is int and int(request) < 0:
		return  # terminal only asked for a panel refresh
	var index := int(request)
	var cost := _purchase_cost(index)
	if stats.owns(index) and index == RunStats.Purchase.NAILGUN:
		return
	if not stats.spend(cost):
		return
	stats.mark_owned(index)
	_play("buy")
	match index:
		RunStats.Purchase.NAILGUN:
			if "weapons" in player and player.weapons.size() > 2:
				player.weapons[2] = true
		RunStats.Purchase.PLATING:
			if "hp" in player:
				player.hp = float(player.hp) + _cfg_float("plating_hp", 25.0)
		RunStats.Purchase.OVERCLOCK:
			if "damage_mult" in player:
				player.damage_mult = float(player.damage_mult) \
					* _cfg_float("overclock_mult", 1.15)


func _purchase_cost(index: int) -> int:
	match index:
		RunStats.Purchase.NAILGUN:
			return _cfg_int("nailgun_cost", 60)
		RunStats.Purchase.PLATING:
			return _cfg_int("plating_cost", 40)
		RunStats.Purchase.OVERCLOCK:
			return _cfg_int("overclock_cost", 50)
	return 0


# --- scene flow ------------------------------------------------------------


func _retry() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_run_over = false
	tree.paused = false
	tree.change_scene_to_file.call_deferred(GAME_SCENE)


func _quit_to_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_run_over = false
	_stop_dialogue()
	tree.paused = false
	tree.change_scene_to_file.call_deferred(MENU_SCENE)


func _stop_dialogue() -> void:
	var dialogic := _dialogic()
	if dialogic != null and dialogic.get("current_timeline") != null:
		dialogic.call("end_timeline")


## Dialogic fires this when any timeline finishes; only the ending one gates
## the victory card, everything else is left to UIManager's state machine.
func on_dialogue_ended() -> void:
	if not _awaiting_ending:
		return
	_awaiting_ending = false
	if _run_over and result_screen != null and not result_screen.visible:
		result_screen.show_result(true, stats)


func _connect_dialogic_end() -> void:
	var dialogic := _dialogic()
	if dialogic == null or not dialogic.has_signal("timeline_ended"):
		return
	if not dialogic.timeline_ended.is_connected(on_dialogue_ended):
		dialogic.timeline_ended.connect(on_dialogue_ended)


func _play_intro() -> void:
	_say_timeline(_cfg_timeline("intro_timeline"))


func _dialogic() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/Dialogic")


## Start a Dialogic timeline. Returns false when dialogue is unavailable, so
## callers can fall through to whatever they would do without it.
func _say_timeline(timeline: Resource) -> bool:
	if timeline == null:
		return false
	var dialogic := _dialogic()
	if dialogic == null:
		return false
	dialogic.call("start", timeline)
	return true


static func _cfg_timeline(prop: String) -> Resource:
	if Cfg == null or not (prop in Cfg):
		return null
	return Cfg.get(prop) as Resource


static func _cfg_float(prop: String, fallback: float) -> float:
	if Cfg != null and prop in Cfg:
		return float(Cfg.get(prop))
	return fallback


static func _cfg_int(prop: String, fallback: int) -> int:
	if Cfg != null and prop in Cfg:
		return int(Cfg.get(prop))
	return fallback
