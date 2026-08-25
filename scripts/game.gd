extends Node3D
## STEEL KNIFE — mission 1: room/wave director, desert arena, scrap economy,
## companion + betrayal boss. Gameplay-first, story on top (Dialogic).

enum State { MENU, PLAYING, BOSS, END, DEAD }

var doors: Array[Node3D] = []
var terminals: Array[Node3D] = []
var trigger_nodes: Array[Area3D] = []

const ROOMS := [Vector2(0.0, -28.0), Vector2(-36.0, -64.0), Vector2(-72.0, -100.0)]
const ROOM_WAVES := [2, 2, 3]

var state: int = State.MENU
var player: CharacterBody3D
var companion: CharacterBody3D
var enemies: Node3D
var projectiles: Array = []
var debris: Array = []


var room := 0
var wave_in_room := 0
var wave: int:
	get:
		return wave_in_room + 1
	set(value):
		wave_in_room = value - 1
var alive := 0
var wave_delay := -1.0
var boss_delay := -1.0
var scrap := 0
var style := 0.0
var hitmarker_t := 0.0
var hurt_flash: ColorRect

var hud_hp: Label
var hud_rank: Label
var hud_wave: Label
var hud_scrap: Label
var hud_wpn: Label
var overlay: Label
var crosshair: Array = []
var cl: CanvasLayer

var sfx_shot: AudioStreamPlayer
var sfx_hit: AudioStreamPlayer
var sfx_head: AudioStreamPlayer
var sfx_die: AudioStreamPlayer
var sfx_hurt: AudioStreamPlayer
var sfx_dash: AudioStreamPlayer
var sfx_slide: AudioStreamPlayer
var sfx_parry: AudioStreamPlayer
var sfx_coin: AudioStreamPlayer
var sfx_windup: AudioStreamPlayer
var sfx_spit: AudioStreamPlayer
var sfx_buy: AudioStreamPlayer
var sfx_door: AudioStreamPlayer


var _initialized := false
var _triggers_wired := false
var paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _initialized:
		return
	_initialized = true

	# Prefer the editor-authored level and entity nodes. The empty main.tscn
	# remains supported by instantiating the same level as a fallback.
	var level := get_node_or_null("Level") as Node3D
	if level == null:
		var level_scene: PackedScene = load("res://scenes/level.tscn")
		if level_scene != null:
			level = level_scene.instantiate() as Node3D
			if level != null:
				level.name = "Level"
				add_child(level)
	_collect_level(level)

	enemies = get_node_or_null("Enemies") as Node3D
	if enemies == null:
		enemies = Node3D.new()
		enemies.name = "Enemies"
		add_child(enemies)

	player = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_build_player()
	else:
		_wire_player()

	companion = get_node_or_null("Companion") as CharacterBody3D
	if companion == null:
		_build_companion()
	else:
		_wire_companion()

	_build_hud()
	_build_audio()
	_wire_triggers()
	_setup_touch_controls()
	_show_menu()


func _collect_level(level: Node3D) -> void:
	doors.clear()
	terminals.clear()
	trigger_nodes.clear()
	if level == null:
		return

	# level_1.tscn exposes typed arrays. Editor-authored level.tscn uses
	# containers instead, so discover the same objects when no arrays exist.
	var configured_doors = level.get("doors")
	if configured_doors is Array:
		for item in configured_doors:
			if item is Node3D:
				doors.append(item)
	if doors.is_empty():
		for item in level.find_children("*", "Node3D", true, false):
			if item is Node3D and (item.has_method("door_set") or
					String(item.name).begins_with("Door_") or
					String(item.name).begins_with("Door") and
					(item.get_node_or_null("Body") != null or item.get_node_or_null("StaticBody3D") != null)):
				doors.append(item)

	var configured_terminals = level.get("terminals")
	if configured_terminals is Array:
		for item in configured_terminals:
			if item is Node3D:
				terminals.append(item)
	if terminals.is_empty():
		for item in level.find_children("*", "Node", true, false):
			if item is Node3D and item.has_method("setup_ui"):
				terminals.append(item)

	var configured_triggers = level.get("trigger_nodes")
	if configured_triggers is Array:
		for item in configured_triggers:
			if item is Area3D:
				trigger_nodes.append(item)
	if trigger_nodes.is_empty():
		for item in level.find_children("*", "Area3D", true, false):
			if item is Area3D:
				trigger_nodes.append(item)


func _wire_triggers() -> void:
	if _triggers_wired:
		return
	_triggers_wired = true
	for i in trigger_nodes.size():
		var trigger := trigger_nodes[i]
		if trigger == null or not is_instance_valid(trigger):
			continue
		var handler := Callable(self, "_on_trigger_body").bind(i)
		if not trigger.body_entered.is_connected(handler):
			trigger.body_entered.connect(handler)


func _on_trigger_body(body: Node3D, index: int) -> void:
	if body != player:
		return
	var trigger_name := String(trigger_nodes[index].name).to_lower() if index < trigger_nodes.size() else ""
	if index == 0 or trigger_name.contains("room2"):
		_enter_room(1)
	elif index == 1 or trigger_name.contains("room3"):
		_enter_room(2)
	else:
		_betrayal()


func _setup_touch_controls() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	Input.set_emulate_mouse_from_touch(false)
	if get_node_or_null("TouchControls") == null:
		var ts = load("res://scripts/touch_controls.gd").new()
		ts.name = "TouchControls"
		add_child(ts)
		ts.setup(player)
		if ts.has_signal("pause_pressed"):
			ts.pause_pressed.connect(_toggle_pause)
	if get_node_or_null("MobileControls") == null:
		var mc = load("res://scripts/mobile_controls.gd").new()
		mc.name = "MobileControls"
		add_child(mc)
		mc.setup(player)


func _wire_player() -> void:
	if player == null:
		return
	player.enemy_pool = enemies
	if player.has_signal("fired") and not player.fired.is_connected(_on_fired):
		player.fired.connect(_on_fired)
	if player.has_signal("player_died") and not player.player_died.is_connected(_on_player_died):
		player.player_died.connect(_on_player_died)
	if player.has_signal("dashed") and not player.dashed.is_connected(_on_player_dashed):
		player.dashed.connect(_on_player_dashed)
	if player.has_signal("slid") and not player.slid.is_connected(_on_player_slid):
		player.slid.connect(_on_player_slid)
	if player.has_signal("parried") and not player.parried.is_connected(_on_player_parried):
		player.parried.connect(_on_player_parried)
	if player.has_signal("coin_tossed") and not player.coin_tossed.is_connected(_on_coin_tossed):
		player.coin_tossed.connect(_on_coin_tossed)


func _wire_companion() -> void:
	if companion == null:
		return
	companion.player_ref = player
	companion.enemy_pool = enemies
	if companion.has_signal("shot") and not companion.shot.is_connected(_on_companion_shot):
		companion.shot.connect(_on_companion_shot)


func _on_player_dashed() -> void:
	_play(sfx_dash)


func _on_player_slid() -> void:
	_play(sfx_slide)


func _on_player_parried() -> void:
	_play(sfx_parry)


func _on_coin_tossed() -> void:
	_play(sfx_coin)


func _on_companion_shot() -> void:
	_play(sfx_shot)


func door_set(d: Node3D, closed: bool) -> void:
	if d == null or not is_instance_valid(d):
		return
	if d.has_method("door_set"):
		d.door_set(closed)
	else:
		# Editor-authored levels use a plain Node3D with Body/Mesh children.
		var body := d.get_node_or_null("Body") as StaticBody3D
		if body == null:
			body = d.get_node_or_null("StaticBody3D") as StaticBody3D
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D if body else null
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D if body else null
		if mesh == null and body:
			mesh = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if shape:
			shape.set_deferred("disabled", not closed)
		if mesh:
			var target_y := 2.5 if closed else 6.5
			if is_inside_tree():
				var tw := create_tween()
				tw.tween_property(mesh, "position:y", target_y, 0.6)
			else:
				mesh.position.y = target_y
	_play(sfx_door)




func _build_player() -> void:
	player = load("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.0, -4.0)
	add_child(player)
	_wire_player()


func _build_companion() -> void:
	companion = load("res://scripts/companion.gd").new()
	companion.position = Vector3(2.0, 0.0, -2.0)
	add_child(companion)
	_wire_companion()


# ------------------------------------------------------------- HUD
func _make_ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_color = Color(0.0, 0.0, 0.0)
	ls.outline_size = 3
	return ls


func _collect_hud(existing: CanvasLayer) -> void:
	cl = existing
	hud_hp = existing.get_node_or_null("HP") as Label
	hud_rank = existing.get_node_or_null("Rank") as Label
	hud_wave = existing.get_node_or_null("Wave") as Label
	hud_scrap = existing.get_node_or_null("Scrap") as Label
	hud_wpn = existing.get_node_or_null("Weapon") as Label
	hurt_flash = existing.get_node_or_null("HurtFlash") as ColorRect
	overlay = existing.get_node_or_null("Overlay") as Label
	crosshair.clear()
	var crosshair_root := existing.get_node_or_null("Crosshair")
	if crosshair_root != null:
		for child in crosshair_root.get_children():
			if child is ColorRect:
				child.visible = true
				crosshair.append(child)


func _setup_terminals() -> void:
	for terminal in terminals:
		if terminal == null or not is_instance_valid(terminal):
			continue
		terminal.player_ref = player
		terminal.setup_ui(cl)
		if terminal.has_signal("purchase_requested") and not terminal.purchase_requested.is_connected(_on_purchase):
			terminal.purchase_requested.connect(_on_purchase)


func _build_hud() -> void:
	var existing := get_node_or_null("HUD") as CanvasLayer
	if existing != null:
		_collect_hud(existing)
		_setup_terminals()
		return

	cl = CanvasLayer.new()
	add_child(cl)
	hud_hp = Label.new()
	hud_hp.position = Vector2(8, 128)
	hud_hp.label_settings = _make_ls(20, Color(1.0, 0.7, 0.3))
	hud_hp.text = "%d" % int(Cfg.max_hp)
	cl.add_child(hud_hp)
	hud_rank = Label.new()
	hud_rank.position = Vector2(272, 8)
	hud_rank.label_settings = _make_ls(26, Color(0.7, 0.7, 0.7))
	hud_rank.text = "D"
	cl.add_child(hud_rank)
	hud_wave = Label.new()
	hud_wave.position = Vector2(8, 8)
	hud_wave.label_settings = _make_ls(12, Color(0.9, 0.8, 0.6))
	hud_wave.text = "ROOM 1"
	cl.add_child(hud_wave)
	hud_scrap = Label.new()
	hud_scrap.position = Vector2(130, 8)
	hud_scrap.label_settings = _make_ls(12, Color(1.0, 0.85, 0.4))
	hud_scrap.text = "SCRAP 0"
	cl.add_child(hud_scrap)
	hud_wpn = Label.new()
	hud_wpn.position = Vector2(8, 152)
	hud_wpn.label_settings = _make_ls(9, Color(0.8, 0.8, 0.8))
	hud_wpn.text = "REVOLVER"
	cl.add_child(hud_wpn)

	var crosshair_container := Control.new()
	crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	cl.add_child(crosshair_container)
	for r in [Rect2(-4, -6, 8, 2), Rect2(-4, 4, 8, 2), Rect2(-2, -8, 2, 6), Rect2(0, 2, 2, 6)]:
		var cr := ColorRect.new()
		cr.color = Color(1, 1, 1, 0.9)
		cr.position = r.position
		cr.size = r.size
		cr.visible = true
		crosshair_container.add_child(cr)
		crosshair.append(cr)
	hurt_flash = ColorRect.new()
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.color = Color(1.0, 0.0, 0.1, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hurt_flash)
	overlay = Label.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.label_settings = _make_ls(14, Color(1.0, 0.75, 0.4))
	cl.add_child(overlay)
	_setup_terminals()


func _show_menu() -> void:
	if player:
		player.disabled = true
	overlay.text = "S T E E L   K N I F E\n\nmission 1: clear the site with COLT.\nrooms lock when you cross the line. scrap buys upgrades.\n\nF parry · RMB coin · E shop · 1/2/3 weapons\n\nclick / tap / A to start"
	overlay.visible = true


# ------------------------------------------------------------- audio
func _tone(freq: float, dur: float, vol: float, type: String = "sine", freq2: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * float(rate))
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	var phase := 0.0
	var f2 := freq2 if freq2 > 0.0 else freq
	for i in n:
		var k := float(i) / float(n)
		phase += TAU * lerpf(freq, f2, k) / float(rate)
		var s := 0.0
		match type:
			"sine":
				s = sin(phase)
			"square":
				s = 1.0 if fmod(phase, TAU) < PI else -1.0
			"noise":
				s = randf_range(-1.0, 1.0)
		buf.put_16(int(clampf(s * vol * pow(1.0 - k, 2.0), -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = buf.data_array
	return wav


func _make_p(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


func _audio_child(root: Node, name: String) -> AudioStreamPlayer:
	if root == null:
		return null
	return root.get_node_or_null(name) as AudioStreamPlayer


func _build_audio() -> void:
	# Reuse optional editor-authored SFX players and synthesize only the
	# channels that are absent.
	var sfx_root := get_node_or_null("SFX")
	if sfx_root:
		sfx_shot = _audio_child(sfx_root, "Shot")
		sfx_hit = _audio_child(sfx_root, "Hit")
		sfx_head = _audio_child(sfx_root, "Headshot")
		sfx_die = _audio_child(sfx_root, "Die")
		sfx_hurt = _audio_child(sfx_root, "Hurt")
		sfx_dash = _audio_child(sfx_root, "Dash")
		sfx_slide = _audio_child(sfx_root, "Slide")
		sfx_parry = _audio_child(sfx_root, "Parry")
		sfx_coin = _audio_child(sfx_root, "Coin")
		sfx_windup = _audio_child(sfx_root, "Windup")
		sfx_spit = _audio_child(sfx_root, "Spit")
		sfx_buy = _audio_child(sfx_root, "Buy")
		sfx_door = _audio_child(sfx_root, "Door")
	if sfx_shot == null: sfx_shot = _make_p(_tone(900.0, 0.09, 0.5, "square", 140.0), -8.0)
	if sfx_hit == null: sfx_hit = _make_p(_tone(500.0, 0.06, 0.4, "sine", 700.0), -8.0)
	if sfx_head == null: sfx_head = _make_p(_tone(1200.0, 0.1, 0.5, "sine", 1800.0), -6.0)
	if sfx_die == null: sfx_die = _make_p(_tone(200.0, 0.35, 0.7, "noise"), -5.0)
	if sfx_hurt == null: sfx_hurt = _make_p(_tone(140.0, 0.3, 0.7, "sine", 50.0), -4.0)
	if sfx_dash == null: sfx_dash = _make_p(_tone(300.0, 0.12, 0.3, "sine", 700.0), -10.0)
	if sfx_slide == null: sfx_slide = _make_p(_tone(600.0, 0.2, 0.25, "noise"), -14.0)
	if sfx_parry == null: sfx_parry = _make_p(_tone(700.0, 0.18, 0.6, "sine", 1400.0), -5.0)
	if sfx_coin == null: sfx_coin = _make_p(_tone(1600.0, 0.08, 0.3, "sine", 2200.0), -10.0)
	if sfx_windup == null: sfx_windup = _make_p(_tone(220.0, 0.3, 0.4, "square", 110.0), -9.0)
	if sfx_spit == null: sfx_spit = _make_p(_tone(500.0, 0.15, 0.4, "square", 900.0), -9.0)
	if sfx_buy == null: sfx_buy = _make_p(_tone(800.0, 0.15, 0.4, "sine", 1200.0), -6.0)
	if sfx_door == null: sfx_door = _make_p(_tone(90.0, 0.5, 0.6, "noise"), -8.0)


func _play(p: AudioStreamPlayer) -> void:
	if p and p.is_inside_tree():
		p.play()


func _say(path: String) -> void:
	if not is_inside_tree():
		return
	var d := get_node_or_null("/root/Dialogic")
	if d == null or DisplayServer.get_name() == "headless":
		return
	if not _dtl_loader_added:
		_dtl_loader_added = true
		ResourceLoader.add_resource_format_loader(load("res://addons/dialogic/Resources/TimelineResourceLoader.gd").new())
	if ResourceLoader.exists(path):
		d.start(load(path))


var _dtl_loader_added := false


func _toggle_pause() -> void:
	if not is_inside_tree() or state not in [State.PLAYING, State.BOSS]:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		overlay.text = "P A U S E D\n\npress ESC or the pause button to resume"
		overlay.visible = true
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		overlay.visible = false
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------- flow
func _unhandled_input(ev: InputEvent) -> void:
	var cancel := ev.is_action_pressed("ui_cancel")
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		cancel = true
	if cancel:
		_toggle_pause()
		return
	if paused or state == State.PLAYING or state == State.BOSS:
		return
	var start := false
	if ev is InputEventMouseButton and ev.pressed:
		start = true
	elif ev is InputEventScreenTouch and ev.pressed:
		start = true
	elif ev is InputEventJoypadButton and ev.pressed \
			and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		start = true
	if start:
		if state == State.MENU:
			_start()
		elif state in [State.DEAD, State.END]:
			get_tree().reload_current_scene()


func _set_door(index: int, closed: bool) -> void:
	if index >= 0 and index < doors.size():
		door_set(doors[index], closed)


func _start() -> void:
	if player:
		player.disabled = false
	if paused and is_inside_tree():
		get_tree().paused = false
		paused = false
	state = State.PLAYING
	if overlay:
		overlay.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_door(0, true)
	_set_door(2, true)
	_set_door(4, true)
	_say("res://dialogue/intro.dtl")
	_spawn_wave()


func _enter_room(r: int) -> void:
	if state != State.PLAYING:
		return
	room = r
	wave_in_room = 0
	_set_door(1 if r == 1 else 3, true)
	hud_wave.text = "ROOM %d" % (r + 1)
	_spawn_wave()


func _room_bounds() -> Vector2:
	return ROOMS[room]


func _spawn_wave() -> void:
	var b := _room_bounds()
	var hounds := 3 + room + wave_in_room
	var spitters := 1 + wave_in_room if room + wave_in_room >= 2 else 0
	for i in hounds:
		_spawn_enemy(false)
	for i in spitters:
		_spawn_enemy(true)
	hud_wave.text = "ROOM %d · WAVE %d/%d" % [room + 1, wave_in_room + 1, ROOM_WAVES[room]]


func _spawn_enemy(ranged: bool, at := Vector3.ZERO, boss := false) -> CharacterBody3D:
	var e: CharacterBody3D = load("res://scripts/enemy.gd").new()
	e.kind = "boss" if boss else ("spitter" if ranged else "hound")
	if boss:
		e.modulate = Color(1.6, 0.5, 0.5)
	if at == Vector3.ZERO:
		var b := _room_bounds()
		var player_pos := player.global_position if player != null and player.is_inside_tree() else player.position
		for _t in 12:
			at = Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(b.y + 3.0, b.x - 3.0))
			if at.distance_to(player_pos) > 8.0:
				break
	e.position = at
	e.target = player
	e.ranged = ranged
	if boss:
		e.hp = Cfg.boss_hp
		e.speed = Cfg.boss_speed
		e.scale = Vector3(1.5, 1.5, 1.5)
		e.set_meta("scrap", Cfg.scrap_boss)
	elif ranged:
		e.set_meta("scrap", Cfg.scrap_spitter)
	else:
		e.speed = Cfg.enemy_speed + room * Cfg.enemy_speed_per_wave
		e.set_meta("scrap", Cfg.scrap_hound)
	e.died.connect(func(pos): _on_enemy_died(pos, e))
	e.attacked.connect(_on_attacked.bind(e))
	e.windup.connect(func(): _play(sfx_windup))
	e.volley.connect(_on_volley)
	enemies.add_child(e)
	alive += 1
	return e


func _betrayal() -> void:
	if state != State.PLAYING:
		return
	state = State.BOSS
	_set_door(4, true)
	if companion and is_instance_valid(companion):
		companion.vanish()
	_say("res://dialogue/betrayal.dtl")
	boss_delay = 3.5


func _on_volley(dir: Vector3, origin: Vector3) -> void:
	_play(sfx_spit)
	for i in Cfg.spitter_volley:
		var ang: float = (float(i) - float(Cfg.spitter_volley - 1) / 2.0) * float(Cfg.spitter_spread)
		var d := dir.rotated(Vector3.UP, ang)
		var pr = load("res://scripts/projectile.gd").new()
		pr.position = origin
		pr.vel = d * Cfg.projectile_speed
		pr.damage = Cfg.projectile_damage
		add_child(pr)
		projectiles.append(pr)


func _on_enemy_died(pos: Vector3, e: Node3D) -> void:
	_play(sfx_die)
	style += Cfg.style_kill
	if player.sliding:
		style += Cfg.style_slide_kill
	_add_scrap_for(e)
	_spawn_gibs(pos)
	_spawn_dead(pos, e.kind if e.get("kind") != null else "hound")
	alive -= 1
	if alive > 0:
		return
	if state == State.BOSS:
		_end_mission()
	elif state == State.PLAYING:
		if wave_in_room < ROOM_WAVES[room] - 1:
			wave_in_room += 1
			wave_delay = 1.2
		else:
			_room_cleared()


func _room_cleared() -> void:
	if room == 0:
		_say("res://dialogue/quip1.dtl")
		_set_door(0, false)
	elif room == 1:
		_set_door(2, false)
	elif room == 2:
		_set_door(4, false)


func _end_mission() -> void:
	state = State.END
	_say("res://dialogue/ending.dtl")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.text = "M I S S I O N   C O M P L E T E\n\nscrap banked: %d · final rank %s\n\nclick to replay" % [scrap, Cfg.rank_for_points(style)]
	overlay.visible = true


func _on_player_died() -> void:
	state = State.DEAD
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.text = "Y O U   D I E D\n\nscrap %d · rank %s\n\nclick to retry" % [scrap, Cfg.rank_for_points(style)]
	overlay.visible = true


func _on_fired(enemy: Node3D, headshot: bool, airborne: bool, damage: float, ricochet: bool) -> void:
	if state not in [State.PLAYING, State.BOSS]:
		return
	var dir := (enemy.global_position - player.global_position).normalized()
	enemy.take_damage(damage, dir, 4.0)
	player.hp = CombatLogic.heal_on_damage(player.hp, damage, Cfg.heal_factor, Cfg.max_hp)
	hud_hp.text = "%d" % int(player.hp)
	var pts: float = float(Cfg.style_hit)
	if headshot:
		pts += Cfg.style_headshot
	if airborne:
		pts += Cfg.style_airshot
	if ricochet:
		pts += Cfg.style_ricochet
	style += pts
	hitmarker_t = 0.08
	_play(sfx_head if headshot else sfx_hit)


func _add_scrap_for(e: Node3D) -> void:
	scrap += int(e.get_meta("scrap")) if e.has_meta("scrap") else Cfg.scrap_hound
	hud_scrap.text = "SCRAP %d" % scrap


func _on_attacked(e: Node3D) -> void:
	if state not in [State.PLAYING, State.BOSS]:
		return
	if player.is_parry_active():
		player.hp = CombatLogic.heal_on_damage(player.hp, Cfg.parry_heal_bonus, 1.0, Cfg.max_hp)
		hud_hp.text = "%d" % int(player.hp)
		style += Cfg.style_parry
		if e and is_instance_valid(e) and e.has_method("stagger"):
			e.stagger(Cfg.parry_stagger)
		player.parried.emit()
		hurt_flash.color = Color(0.3, 1.0, 1.0, 0.35)
		var tw := create_tween()
		tw.tween_property(hurt_flash, "color", Color(0.3, 1.0, 1.0, 0.0), 0.35)
	else:
		player.take_damage(Cfg.enemy_damage)
		style = CombatLogic.on_hurt(style)
		hud_hp.text = "%d" % int(maxf(player.hp, 0.0))
		hurt_flash.color = Color(1.0, 0.0, 0.1, 0.45)
		var tw := create_tween()
		tw.tween_property(hurt_flash, "color", Color(1.0, 0.0, 0.1, 0.0), 0.4)
		_play(sfx_hurt)


func _on_purchase(item: int) -> void:
	if item < -1 or item > 2 or player == null:
		return
	if item == -1:
		for t in terminals:
			t.refresh_panel(scrap, player.weapons[2])
		return
	var cost: int = [int(Cfg.nailgun_cost), int(Cfg.plating_cost), int(Cfg.overclock_cost)][item]
	if item == 0 and player.weapons[2]:
		return
	if scrap < cost:
		return
	scrap -= cost
	hud_scrap.text = "SCRAP %d" % scrap
	match item:
		0:
			player.weapons[2] = true
			player.weapon = 2
			hud_wpn.text = "NAILGUN"
		1:
			Cfg.max_hp += Cfg.plating_hp
			player.hp = minf(player.hp + Cfg.plating_hp, Cfg.max_hp)
			hud_hp.text = "%d" % int(player.hp)
		2:
			player.damage_mult *= Cfg.overclock_mult
	_play(sfx_buy)
	for t in terminals:
		t.refresh_panel(scrap, player.weapons[2])


func _spawn_gibs(at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.3, 0.05)
		mi.material_override = m
		mi.position = at + Vector3(0, 1.0, 0)
		add_child(mi)
		debris.append({
			"node": mi,
			"vel": Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 9.0), randf_range(-6.0, 6.0)),
			"life": randf_range(0.5, 1.0),
		})


func _spawn_dead(at: Vector3, kind: String) -> void:
	# Spawn dead billboard from triangulated WebP dead sprite (single view lying)
	var actor = SpriteLib.build_actor(kind)
	var dead_tex: Texture2D = null
	if actor and actor.frames:
		# try dead animation, then the best available idle frame
		if actor.frames.has_animation("dead"):
			dead_tex = actor.frames.get_frame_texture("dead", 0)
		elif actor.frames.has_animation("idle"):
			dead_tex = actor.frames.get_frame_texture("idle", 0)
	if actor != null:
		actor.free()
	# fallback: direct load of dead webp
	if dead_tex == null:
		var candidates := [
			"res://assets/sprites/%s_dead.webp" % kind,
			"res://assets/sprites/colt_dead.webp",
			"res://assets/sprites/hound_dead.webp",
			"res://assets/sprites/spitter_dead.webp",
		]
		for candidate in candidates:
			if ResourceLoader.exists(candidate):
				dead_tex = load(candidate)
				break
	if dead_tex == null:
		return
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("dead")
	sf.set_animation_loop("dead", false)
	sf.add_frame("dead", dead_tex)
	var as3 := AnimatedSprite3D.new()
	as3.sprite_frames = sf
	as3.billboard = 1
	as3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var h: float = 1.8
	if SpriteLib.SETS.has(kind):
		h = float(SpriteLib.SETS[kind].h) * 0.6  # lying, lower
	as3.pixel_size = h / float(dead_tex.get_height())
	as3.position = at + Vector3(0, h * 0.3, 0)
	# lay flat-ish by rotating? Keep billboard but lower
	as3.play("dead")
	add_child(as3)
	# fade out after some time via debris system
	debris.append({
		"node": as3,
		"vel": Vector3.ZERO,
		"life": 12.0,
	})


# ------------------------------------------------------------- loop
func _process(dt: float) -> void:
	hitmarker_t = maxf(hitmarker_t - dt, 0.0)
	for c in crosshair:
		c.color = Color(1, 0, 0, 0.8) if hitmarker_t > 0.0 else Color(1, 1, 1, 0.9)
	if wave_delay > 0.0:
		wave_delay -= dt
		if wave_delay <= 0.0:
			wave_delay = -1.0
			_spawn_wave()
	if boss_delay > 0.0:
		boss_delay -= dt
		if boss_delay <= 0.0:
			boss_delay = -1.0
			_spawn_enemy(true, Vector3(0, 0, -118), true)
			_spawn_enemy(false, Vector3(-8, 0, -115))
			_spawn_enemy(false, Vector3(8, 0, -115))
	if state in [State.PLAYING, State.BOSS]:
		style = maxf(style - Cfg.decay_rate(style) * dt, 0.0)
		var rank: String = str(Cfg.rank_for_points(style))
		hud_rank.text = rank
		var col := Color(0.7, 0.7, 0.7)
		match rank:
			"C": col = Color(0.5, 0.9, 1.0)
			"B": col = Color(0.4, 1.0, 0.5)
			"A": col = Color(1.0, 0.9, 0.3)
			"S": col = Color(1.0, 0.5, 0.2)
			"SS": col = Color(1.0, 0.2, 0.3)
			"SSS": col = Color(1.0, 0.05, 0.4)
		hud_rank.label_settings.font_color = col
		hud_wpn.text = ["REVOLVER", "SHOTGUN", "NAILGUN"][player.weapon]
	# projectiles vs player / parry
	for p in projectiles.duplicate():
		if not is_instance_valid(p):
			projectiles.erase(p)
			continue
		var d: float = p.position.distance_to(player.global_position + Vector3(0, 1.2, 0))
		if player.is_parry_active() and d < 2.6:
			style += Cfg.style_parry
			player.hp = CombatLogic.heal_on_damage(player.hp, Cfg.parry_heal_bonus, 1.0, Cfg.max_hp)
			hud_hp.text = "%d" % int(player.hp)
			player.parried.emit()
			p.queue_free()
			projectiles.erase(p)
		elif d < 0.8:
			player.take_damage(p.damage)
			style = CombatLogic.on_hurt(style)
			hud_hp.text = "%d" % int(maxf(player.hp, 0.0))
			_play(sfx_hurt)
			p.queue_free()
			projectiles.erase(p)
	var i := debris.size() - 1
	while i >= 0:
		var d: Dictionary = debris[i]
		d.life -= dt
		if d.life <= 0.0 or not is_instance_valid(d.node):
			if is_instance_valid(d.node):
				d.node.queue_free()
			debris.remove_at(i)
		else:
			d.vel.y -= Cfg.gravity * dt
			d.node.position += d.vel * dt
			var s := clampf(d.life, 0.0, 1.0)
			d.node.scale = Vector3(s, s, s)
		i -= 1
