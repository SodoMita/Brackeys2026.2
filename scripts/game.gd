extends Node3D
## STEEL KNIFE — mission 1: room/wave director, desert arena, scrap economy,
## companion + betrayal boss. Gameplay-first, story on top (Dialogic).

enum State { MENU, PLAYING, BOSS, END, DEAD }

const ROOM_W := 28.0
const CORR_W := 8.0
const ROOMS := [Vector2(0.0, -28.0), Vector2(-36.0, -64.0), Vector2(-72.0, -100.0)]
const DOOR_Z := [-28.0, -36.0, -64.0, -72.0, -100.0]
const ROOM_WAVES := [2, 2, 3]

var state: int = State.MENU
var player: CharacterBody3D
var companion: CharacterBody3D
var enemies: Node3D
var projectiles: Array = []
var debris: Array = []
var doors: Array = []
var terminals: Array = []

var room := 0
var wave_in_room := 0
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


func _ready() -> void:
	_build_environment()
	_build_level()
	enemies = Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	_build_player()
	_build_companion()
	_build_hud()
	_build_audio()
	if DisplayServer.is_touchscreen_available():
		Input.set_emulate_mouse_from_touch(false)
		var ts = load("res://scripts/touch_controls.gd").new()
		add_child(ts)
		ts.setup(player)
	_show_menu()


# ------------------------------------------------------------- world
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.07, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.6, 0.4)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.3, 0.12)
	env.fog_density = 0.010
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 20.0, 0.0)
	sun.light_color = Color(1.0, 0.85, 0.6)
	sun.light_energy = 1.1
	add_child(sun)


func _sand_texture() -> ImageTexture:
	var img := Image.create_empty(128, 128, true, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var dark := ((x / 32) + (y / 32)) % 2 == 0
			var c := Color(0.45, 0.32, 0.16) if dark else Color(0.36, 0.25, 0.12)
			if x % 32 == 0 or y % 32 == 0:
				c = Color(0.9, 0.55, 0.2)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _wall_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.1, 0.06)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 0.2
	return m


func _segment(z0: float, z1: float, width: float) -> void:
	var length := absf(z1 - z0)
	var zc := (z0 + z1) / 2.0
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _sand_texture()
	fm.roughness = 0.9
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, length)
	pm.material = fm
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, 0, zc)
	add_child(floor_mi)
	var wm := _wall_mat()
	for sx in [-1.0, 1.0]:
		var w := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.0, 6.0, length)
		cs.shape = bs
		w.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 6.0, length)
		bm.material = wm
		mi.mesh = bm
		w.add_child(mi)
		w.position = Vector3(sx * (width / 2.0 + 0.5), 3.0, zc)
		add_child(w)


func _make_door(z: float, width: float) -> Node3D:
	var d := Node3D.new()
	d.position = Vector3(0, 0, z)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 5.0, 1.0)
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 5.0, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.12, 0.07)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.1)
	m.emission_energy_multiplier = 0.5
	bm.material = m
	mi.mesh = bm
	mi.position = Vector3(0, 2.5, 0)
	sb.add_child(mi)
	d.add_child(sb)
	add_child(d)
	d.set_meta("body", sb)
	d.set_meta("mesh", mi)
	return d


func door_set(d: Node3D, closed: bool) -> void:
	var sb: StaticBody3D = d.get_meta("body")
	var mi: MeshInstance3D = d.get_meta("mesh")
	sb.set_deferred("disabled", not closed)
	var tw := create_tween()
	tw.tween_property(mi, "position:y", 2.5 if closed else 6.5, 0.6)
	_play(sfx_door)


func _make_trigger(z: float, width: float, cb: Callable) -> void:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 4.0, 1.0)
	cs.shape = bs
	a.add_child(cs)
	a.position = Vector3(0, 2.0, z)
	a.body_entered.connect(func(b):
		if b == player:
			cb.call())
	add_child(a)


func _build_level() -> void:
	_segment(6.0, -28.0, ROOM_W)          # room 1
	_segment(-28.0, -36.0, CORR_W)        # corridor 1
	_segment(-36.0, -64.0, ROOM_W)        # room 2
	_segment(-64.0, -72.0, CORR_W)        # corridor 2
	_segment(-72.0, -100.0, ROOM_W)       # room 3
	_segment(-100.0, -130.0, ROOM_W)      # plaza
	# end walls
	var wm := _wall_mat()
	for z in [6.0, -130.0]:
		var w := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(ROOM_W + 2.0, 6.0, 1.0)
		cs.shape = bs
		w.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ROOM_W + 2.0, 6.0, 1.0)
		bm.material = wm
		mi.mesh = bm
		w.add_child(mi)
		w.position = Vector3(0, 3.0, z)
		add_child(w)
	for i in DOOR_Z.size():
		var width := ROOM_W if i == DOOR_Z.size() - 1 else CORR_W
		doors.append(_make_door(DOOR_Z[i], width))
	_make_trigger(-40.0, CORR_W, _enter_room.bind(1))
	_make_trigger(-76.0, CORR_W, _enter_room.bind(2))
	_make_trigger(-105.0, ROOM_W, _betrayal)
	# shop terminals in corridors
	var st1 = load("res://scripts/shop_terminal.gd").new()
	st1.position = Vector3(2.6, 0.0, -32.0)
	add_child(st1)
	var st2 = load("res://scripts/shop_terminal.gd").new()
	st2.position = Vector3(-2.6, 0.0, -68.0)
	add_child(st2)
	terminals = [st1, st2]


func _build_player() -> void:
	player = load("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.0, -4.0)
	add_child(player)
	player.enemy_pool = enemies
	player.fired.connect(_on_fired)
	player.player_died.connect(_on_player_died)
	player.dashed.connect(func(): _play(sfx_dash))
	player.slid.connect(func(): _play(sfx_slide))
	player.parried.connect(func(): _play(sfx_parry))
	player.coin_tossed.connect(func(): _play(sfx_coin))


func _build_companion() -> void:
	companion = load("res://scripts/companion.gd").new()
	companion.position = Vector3(2.0, 0.0, -2.0)
	add_child(companion)
	companion.player_ref = player
	companion.enemy_pool = enemies
	companion.shot.connect(func(): _play(sfx_shot))


# ------------------------------------------------------------- HUD
func _make_ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_color = Color(0.0, 0.0, 0.0)
	ls.outline_size = 3
	return ls


func _build_hud() -> void:
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
	for r in [Rect2(156, 84, 8, 2), Rect2(156, 94, 8, 2), Rect2(158, 82, 2, 6), Rect2(160, 92, 2, 6)]:
		var cr := ColorRect.new()
		cr.color = Color(1, 1, 1, 0.9)
		cr.position = r.position
		cr.size = r.size
		cr.visible = false
		cl.add_child(cr)
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
	for t in terminals:
		t.player_ref = player
		t.setup_ui(cl)
		t.purchase_requested.connect(_on_purchase)


func _show_menu() -> void:
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


func _build_audio() -> void:
	sfx_shot = _make_p(_tone(900.0, 0.09, 0.5, "square", 140.0), -8.0)
	sfx_hit = _make_p(_tone(500.0, 0.06, 0.4, "sine", 700.0), -8.0)
	sfx_head = _make_p(_tone(1200.0, 0.1, 0.5, "sine", 1800.0), -6.0)
	sfx_die = _make_p(_tone(200.0, 0.35, 0.7, "noise"), -5.0)
	sfx_hurt = _make_p(_tone(140.0, 0.3, 0.7, "sine", 50.0), -4.0)
	sfx_dash = _make_p(_tone(300.0, 0.12, 0.3, "sine", 700.0), -10.0)
	sfx_slide = _make_p(_tone(600.0, 0.2, 0.25, "noise"), -14.0)
	sfx_parry = _make_p(_tone(700.0, 0.18, 0.6, "sine", 1400.0), -5.0)
	sfx_coin = _make_p(_tone(1600.0, 0.08, 0.3, "sine", 2200.0), -10.0)
	sfx_windup = _make_p(_tone(220.0, 0.3, 0.4, "square", 110.0), -9.0)
	sfx_spit = _make_p(_tone(500.0, 0.15, 0.4, "square", 900.0), -9.0)
	sfx_buy = _make_p(_tone(800.0, 0.15, 0.4, "sine", 1200.0), -6.0)
	sfx_door = _make_p(_tone(90.0, 0.5, 0.6, "noise"), -8.0)


func _play(p: AudioStreamPlayer) -> void:
	if p:
		p.play()


func _say(path: String) -> void:
	var d := get_node_or_null("/root/Dialogic")
	if d == null or DisplayServer.get_name() == "headless":
		return
	if not _dtl_loader_added:
		_dtl_loader_added = true
		ResourceLoader.add_resource_format_loader(load("res://addons/dialogic/Resources/TimelineResourceLoader.gd").new())
	if ResourceLoader.exists(path):
		d.start(load(path))


var _dtl_loader_added := false


# ------------------------------------------------------------- flow
func _unhandled_input(ev: InputEvent) -> void:
	if state == State.PLAYING or state == State.BOSS:
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


func _start() -> void:
	state = State.PLAYING
	overlay.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	door_set(doors[0], true)
	door_set(doors[2], true)
	door_set(doors[4], true)
	_say("res://dialogue/intro.dtl")
	_spawn_wave()


func _enter_room(r: int) -> void:
	if state != State.PLAYING:
		return
	room = r
	wave_in_room = 0
	door_set(doors[1 if r == 1 else 3], true)
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
	if at == Vector3.ZERO:
		var b := _room_bounds()
		for _t in 12:
			at = Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(b.y + 3.0, b.x - 3.0))
			if at.distance_to(player.global_position) > 8.0:
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
	door_set(doors[4], true)
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
		door_set(doors[0], false)
	elif room == 1:
		door_set(doors[2], false)
	elif room == 2:
		door_set(doors[4], false)


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


# ------------------------------------------------------------- loop
func _process(dt: float) -> void:
	hitmarker_t = maxf(hitmarker_t - dt, 0.0)
	for c in crosshair:
		c.visible = hitmarker_t > 0.0
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
