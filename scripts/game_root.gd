extends Node3D
## Root of scenes/game.tscn. Deliberately thin: resolves node references and
## owns the UIManager (pause menu, touch controls, Dialogic coordination).
## Gameplay rules stay in the player/enemy/level scripts.

var player: CharacterBody3D
var ui: UIManager


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

	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
	if player != null:
		ui.setup(player)

	_play_intro()


func _play_intro() -> void:
	if Cfg == null or Cfg.intro_timeline == null:
		return
	var dialogic := get_node_or_null("/root/Dialogic") if is_inside_tree() else null
	if dialogic == null:
		return
	# UIManager listens to timeline_started/ended and flips to DIALOG state.
	dialogic.call("start", Cfg.intro_timeline)
