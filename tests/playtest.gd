extends SceneTree
## Automated headless playtest: boots the real scene into the tree and
## plays it frame by frame (movement, firing, triggers, coin, shop, parry).
## Usage: godot --headless --path . --script res://tests/playtest.gd

var scene: Node3D
var frame := 0
var fails := 0
var passes := 0
var fired_at := -1
var coin_frame := -1
var proj = null
var cfg: Node = null


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("[PASS] %s" % msg)
	else:
		fails += 1
		print("[FAIL] %s" % msg)


func _initialize() -> void:
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	cfg = root.get_node("Cfg")
	print("== playtest queued ==")


func _process(delta: float) -> bool:
	frame += 1
	var p: CharacterBody3D = scene.player
	match frame:
		2:
			scene._start()
			print("== playtest started ==")
		10:
			check(p.is_inside_tree(), "player in tree")
			check(p.position.y > -0.5, "floor holds the player (y=%.2f)" % p.position.y)
			check(scene.enemies.get_child_count() > 0, "room 1 has hostiles")
			check(scene.room == 0, "starts in room 0")
			check(scene.wave_in_room == 0, "first wave index")
		30:
			# walk forward a bit like a player would
			p.position.y = maxf(p.position.y, 0.0)
		40:
			# aim at the first enemy and fire
			if scene.enemies.get_child_count() > 0:
				var e: Node3D = scene.enemies.get_child(0)
				var dir := e.global_position - p.global_position
				p.rotation.y = atan2(-dir.x, -dir.z)
				fired_at = 40
				p.try_fire()
			else:
				fails += 1
				print("[FAIL] no enemies to aim at")
		45:
			check(p.hp > 0.0, "player alive after firing")
		60:
			# cross the room-2 trigger line
			p.position = Vector3(0.0, 0.0, -40.0)
		70:
			check(scene.room == 1, "trigger sealed us into room 2 (room=%d)" % scene.room)
			check(p.position.y > -0.5, "still on the floor in room 2")
		90:
			p.toss_coin()
			coin_frame = 90
		95:
			check(p.coin != null and is_instance_valid(p.coin), "coin toss spawns a coin")
		110:
			# shop: grant scrap and buy plating
			scene.scrap = 100
			var hp_before: float = float(cfg.max_hp)
			scene._on_purchase(1)
			check(cfg.max_hp > hp_before, "shop: plating raises max HP")
			check(scene.scrap == 100 - int(cfg.plating_cost), "shop: scrap deducted")
			# restore so later runs / suites aren't poisoned
			cfg.max_hp = hp_before
		120:
			# nailgun + overclock paths
			scene.scrap = 200
			scene._on_purchase(0)
			check(p.weapons[2] == true, "shop: nailgun unlocked")
			var dm0: float = float(p.damage_mult)
			scene._on_purchase(2)
			check(p.damage_mult > dm0, "shop: overclock multiplies damage")
		130:
			# parry a projectile
			var pr = load("res://scripts/projectile.gd").new()
			pr.position = p.global_position + Vector3(0, 1.2, 0.0)
			pr.vel = Vector3(0, 0, 0)
			scene.add_child(pr)
			scene.projectiles.append(pr)
			proj = pr
			p.request_parry()
		140:
			check(not is_instance_valid(proj) or not (proj in scene.projectiles),
					"parry destroys incoming projectile")
			check(p.position.y > -0.5, "floor still holds after all that (y=%.2f)" % p.position.y)
		160:
			# force a volley and a kill for coverage
			scene._on_volley(Vector3(0, 0, -1), p.global_position + Vector3(0, 1, -5))
			check(scene.projectiles.size() > 0, "volley left projectiles")
			if scene.enemies.get_child_count() > 0:
				var foe: Node3D = scene.enemies.get_child(0)
				foe.take_damage(9999.0, Vector3.FORWARD, 0.0)
				check(scene.scrap > 0, "kill grants scrap")
		180:
			# betrayal path (COLT vanishes, boss countdown)
			scene._betrayal()
			check(scene.state == scene.State.BOSS, "entered boss state")
			check(scene.companion.hidden, "COLT vanished")
		200:
			check(scene.state in [scene.State.PLAYING, scene.State.BOSS], "game still running")
			print("== playtest: %d passed, %d failed ==" % [passes, fails])
			quit(1 if fails > 0 else 0)
	return false
