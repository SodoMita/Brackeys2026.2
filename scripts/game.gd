extends Node3D
## CRIMSON VELOCITY — root scene: arena, waves, HUD, style meter, audio.

enum State { MENU, PLAYING, DEAD }

const ARENA := 44.0

var state: int = State.MENU
var player: CharacterBody3D
var enemies: Node3D
var debris_root: Node3D
var debris: Array = []
var wave := 0
var style := 0.0
var time_alive := 0.0
var hitmarker_t := 0.0
var hurt_flash: ColorRect

var hud_hp: Label
var hud_rank: Label
var hud_wave: Label
var overlay: Label
var crosshair: Array = []

var sfx_shot: AudioStreamPlayer
var sfx_boom: AudioStreamPlayer
var sfx_hit: AudioStreamPlayer
var sfx_head: AudioStreamPlayer
var sfx_die: AudioStreamPlayer
var sfx_hurt: AudioStreamPlayer
var sfx_dash: AudioStreamPlayer
var sfx_slide: AudioStreamPlayer


func _ready() -> void:
	_build_environment()
	_build_arena()
	enemies = Node3D.new()
	add_child(enemies)
	debris_root = Node3D.new()
	add_child(debris_root)
	_build_player()
	_build_hud()
	_build_audio()
	if DisplayServer.is_touchscreen_available():
		Input.set_emulate_mouse_from_touch(false)
		var ts = load("res://scripts/touch_controls.gd").new()
		add_child(ts)
		ts.setup(player)
	_show_menu()


# ------------------------------------------------------------ world
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.03, 0.05)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.55, 0.5)
	sun.light_energy = 0.8
	add_child(sun)


func _make_floor_texture() -> ImageTexture:
	var img := Image.create_empty(128, 128, true, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var dark := ((x / 32) + (y / 32)) % 2 == 0
			var c := Color(0.16, 0.02, 0.03) if dark else Color(0.06, 0.01, 0.02)
			if x % 32 == 0 or y % 32 == 0:
				c = Color(0.55, 0.08, 0.1)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_arena() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = _make_floor_texture()
	floor_mat.roughness = 0.85
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA, ARENA)
	pm.material = floor_mat
	floor.mesh = pm
	add_child(floor)
	# static body so nothing falls through
	var sb := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	sb.add_child(shape)
	add_child(sb)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.1, 0.02, 0.03)
	wall_mat.emission_enabled = true
	wall_mat.emission = Color(0.9, 0.1, 0.15)
	wall_mat.emission_energy_multiplier = 0.25
	for i in 4:
		var w := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ARENA + 2.0, 6.0, 1.0)
		cs.shape = box
		w.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ARENA + 2.0, 6.0, 1.0)
		bm.material = wall_mat
		mi.mesh = bm
		w.add_child(mi)
		var ang := float(i) * PI / 2.0
		w.position = Vector3(sin(ang) * ARENA / 2.0, 3.0, cos(ang) * ARENA / 2.0)
		w.rotation.y = ang
		add_child(w)

	# pillars + platforms for verticality
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.2, 0.05, 0.07)
	for p in [Vector3(-10, 0, -10), Vector3(10, 0, 10), Vector3(-10, 0, 10), Vector3(10, 0, -10)]:
		var st := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.0, 3.0, 3.0)
		cs.shape = bs
		st.add_child(cs)
		st.position = p + Vector3(0, 1.5, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 3.0, 3.0)
		bm.material = pillar_mat
		mi.mesh = bm
		st.add_child(mi)
		add_child(st)
	for p in [Vector3(0, 2.0, -14), Vector3(-14, 2.5, 0), Vector3(14, 2.0, 4)]:
		var st := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6.0, 0.5, 6.0)
		cs.shape = bs
		st.add_child(cs)
		st.position = p
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.0, 0.5, 6.0)
		bm.material = pillar_mat
		mi.mesh = bm
		st.add_child(mi)
		add_child(st)


func _build_player() -> void:
	var ps := load("res://scripts/player.gd")
	player = ps.new()
	player.position = Vector3(0.0, 0.0, 8.0)
	add_child(player)
	player.fired.connect(_on_fired)
	player.player_died.connect(_on_player_died)
	player.dashed.connect(func(): _play(sfx_dash))
	player.slid.connect(func(): _play(sfx_slide))


# ------------------------------------------------------------ HUD
func _make_ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_color = Color(0.0, 0.0, 0.0)
	ls.outline_size = 3
	return ls


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud_hp = Label.new()
	hud_hp.position = Vector2(8, 128)
	hud_hp.label_settings = _make_ls(20, Color(1.0, 0.25, 0.3))
	hud_hp.text = "100"
	cl.add_child(hud_hp)
	hud_rank = Label.new()
	hud_rank.position = Vector2(272, 8)
	hud_rank.label_settings = _make_ls(26, Color(0.7, 0.7, 0.7))
	hud_rank.text = "D"
	cl.add_child(hud_rank)
	hud_wave = Label.new()
	hud_wave.position = Vector2(8, 8)
	hud_wave.label_settings = _make_ls(12, Color(0.9, 0.7, 0.6))
	hud_wave.text = "WAVE 1"
	cl.add_child(hud_wave)
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
	overlay.label_settings = _make_ls(14, Color(1.0, 0.3, 0.35))
	cl.add_child(overlay)


func _show_menu() -> void:
	overlay.text = "C R I M S O N   V E L O C I T Y\n\nKEYBOARD: WASD · SPACE jump · SHIFT dash · CTRL slide · LMB fire · 1/2 weapons\nGAMEPAD: sticks move/look · A jump · LB dash · RB slide · RT fire\nTOUCH: left stick move · right drag look · on-screen buttons\n\ndamage heals you. style is everything.\n\nclick / tap / A to start"
	overlay.visible = true


# ------------------------------------------------------------ audio
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
	sfx_shot = _make_p(_tone(900.0, 0.09, 0.5, "square", 140.0), -6.0)
	sfx_boom = _make_p(_tone(300.0, 0.25, 0.7, "noise"), -4.0)
	sfx_hit = _make_p(_tone(500.0, 0.06, 0.4, "sine", 700.0), -8.0)
	sfx_head = _make_p(_tone(1200.0, 0.1, 0.5, "sine", 1800.0), -6.0)
	sfx_die = _make_p(_tone(200.0, 0.35, 0.7, "noise"), -5.0)
	sfx_hurt = _make_p(_tone(140.0, 0.3, 0.7, "sine", 50.0), -4.0)
	sfx_dash = _make_p(_tone(300.0, 0.12, 0.3, "sine", 700.0), -10.0)
	sfx_slide = _make_p(_tone(600.0, 0.2, 0.25, "noise"), -14.0)


func _play(p: AudioStreamPlayer) -> void:
	if p:
		p.play()


# ------------------------------------------------------------ flow
func _unhandled_input(ev: InputEvent) -> void:
	if state == State.PLAYING:
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
		elif state == State.DEAD:
			get_tree().reload_current_scene()


func _start() -> void:
	state = State.PLAYING
	overlay.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_next_wave()


func _on_player_died() -> void:
	state = State.DEAD
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.text = "Y O U   D I E D\n\nwave %d · rank %s\n\nclick to retry" % [wave, CombatLogic.rank_for_points(style)]
	overlay.visible = true


func _next_wave() -> void:
	wave += 1
	hud_wave.text = "WAVE %d" % wave
	for i in 2 + wave:
		var es := load("res://scripts/enemy.gd")
		var e: CharacterBody3D = es.new()
		var ang := randf_range(0.0, TAU)
		var r := randf_range(12.0, ARENA / 2.0 - 3.0)
		e.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		e.target = player
		e.speed = 6.5 + wave * 0.5
		e.died.connect(_on_enemy_died)
		e.attacked.connect(_on_attacked)
		enemies.add_child(e)


func _on_fired(enemy: Node3D, headshot: bool, airborne: bool, damage: float) -> void:
	if state != State.PLAYING:
		return
	var dir := (enemy.global_position - player.global_position).normalized()
	enemy.take_damage(damage, dir, 4.0)
	player.hp = CombatLogic.heal_on_damage(player.hp, damage)
	hud_hp.text = "%d" % int(player.hp)
	var pts := CombatLogic.style_points("hit")
	if headshot:
		pts += CombatLogic.style_points("headshot")
	if airborne:
		pts += CombatLogic.style_points("airshot")
	style += pts
	hitmarker_t = 0.08
	_play(sfx_head if headshot else sfx_hit)


func _on_enemy_died(pos: Vector3) -> void:
	_play(sfx_die)
	style += CombatLogic.style_points("kill")
	if player.sliding:
		style += CombatLogic.style_points("slide_kill")
	_spawn_gibs(pos)
	if enemies.get_child_count() == 0:
		_next_wave()


func _on_attacked() -> void:
	if state != State.PLAYING:
		return
	player.take_damage(12.0)
	style = CombatLogic.on_hurt(style)
	hud_hp.text = "%d" % int(maxf(player.hp, 0.0))
	hurt_flash.color = Color(1.0, 0.0, 0.1, 0.45)
	var tw := create_tween()
	tw.tween_property(hurt_flash, "color", Color(1.0, 0.0, 0.1, 0.0), 0.4)
	_play(sfx_hurt)


func _spawn_gibs(at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.02, 0.04)
		mi.material_override = m
		mi.position = at + Vector3(0, 1.0, 0)
		debris_root.add_child(mi)
		debris.append({
			"node": mi,
			"vel": Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 9.0), randf_range(-6.0, 6.0)),
			"life": randf_range(0.5, 1.0),
		})


# ------------------------------------------------------------ loop
func _process(dt: float) -> void:
	time_alive += dt
	hitmarker_t = maxf(hitmarker_t - dt, 0.0)
	for c in crosshair:
		c.visible = hitmarker_t > 0.0
	if state == State.PLAYING:
		style = maxf(style - CombatLogic.decay_rate(style) * dt, 0.0)
		var rank := CombatLogic.rank_for_points(style)
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
	var i := debris.size() - 1
	while i >= 0:
		var d: Dictionary = debris[i]
		d.life -= dt
		if d.life <= 0.0 or not is_instance_valid(d.node):
			if is_instance_valid(d.node):
				d.node.queue_free()
			debris.remove_at(i)
		else:
			d.vel.y -= 24.0 * dt
			d.node.position += d.vel * dt
			var s := clampf(d.life, 0.0, 1.0)
			d.node.scale = Vector3(s, s, s)
		i -= 1
