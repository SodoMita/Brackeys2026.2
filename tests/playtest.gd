extends SceneTree
## Automated headless playtest: boots the real game scene into the tree and
## plays it frame by frame (movement, firing, coin, pause/resume via UIManager).
## Usage: godot --headless --path . --script res://tests/playtest.gd
## (Rewritten after game.gd was removed — waves/shop moved out of the root.)

var scene: Node3D
var frame := 0
var fails := 0
var passes := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("[PASS] %s" % msg)
	else:
		fails += 1
		print("[FAIL] %s" % msg)


func _initialize() -> void:
	scene = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	print("== playtest queued ==")


func _process(_delta: float) -> bool:
	frame += 1
	var p: CharacterBody3D = scene.player
	match frame:
		10:
			check(p != null and p.is_inside_tree(), "player in tree")
			check(p.position.y > -0.5, "floor holds the player (y=%.2f)" % p.position.y)
			check(scene.ui != null, "UIManager attached")
		30:
			p.position.y = maxf(p.position.y, 0.0)
			p.try_fire()
		35:
			check(p.hp > 0.0, "player alive after firing")
		50:
			p.toss_coin()
		55:
			check(p.coin != null and is_instance_valid(p.coin), "coin toss spawns a coin")
		80:
			scene.ui.pause()
		85:
			check(paused, "UIManager pauses the tree")
			check(p.disabled, "player input disabled while paused")
			check(scene.ui.pause_menu.visible, "pause menu on screen")
			scene.ui.resume()
		90:
			check(not paused, "resume unpauses the tree")
			check(not p.disabled, "player input restored")
			check(p.position.y > -0.5, "floor still holds after all that (y=%.2f)" % p.position.y)
		120:
			print("== playtest: %d passed, %d failed ==" % [passes, fails])
			quit(1 if fails > 0 else 0)
	return false
