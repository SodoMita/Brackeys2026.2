extends Node3D
# ============================================================
#  NEON RUSH — synthwave 3D endless runner
#  Everything (world, sounds, textures) is generated in code.
# ============================================================

enum State { MENU, PLAYING, DEAD }

# ---------- tuning ----------
const LANES := [-3.2, 0.0, 3.2]
const SPAWN_Z := -175.0
const KILL_Z := 14.0
const GRAVITY := 26.0
const JUMP_VELOCITY := 9.8
const REST_Y := 0.55
const START_SPEED := 16.0
const MAX_SPEED := 46.0
const ACCEL := 0.42
const SEG_LEN := 48.0
const SEG_COUNT := 8
const BLD_COUNT := 26
const BLD_GAP := 14.0
const MUSIC_STEP := 60.0 / 138.0 / 2.0

# ---------- state ----------
var state: int = State.MENU
var speed := START_SPEED
var score := 0.0
var best := 0.0
var player_x := 0.0
var player_y := REST_Y
var player_vy := 0.0
var lane := 1
var distance := 0.0
var spawn_dist := 0.0
var next_gap := 24.0
var shake := 0.0
var dead_time := 0.0
var music_acc := 0.0
var music_step := 0
var time_alive := 0.0

# ---------- nodes ----------
var cam: Camera3D
var player: MeshInstance3D
var player_ring: MeshInstance3D
var player_light: OmniLight3D
var entities: Node3D
var floor_segs: Array = []
var buildings: Array = []
var building_mats: Array = []
var debris: Array = []
var hud_score: Label
var hud_best: Label
var hud_speed: Label
var menu_overlay: Label
var death_overlay: Label
var flash: ColorRect

# ---------- audio ----------
var sfx_pickup: AudioStreamPlayer
var sfx_jump: AudioStreamPlayer
var sfx_start: AudioStreamPlayer
var sfx_crash_noise: AudioStreamPlayer
var sfx_crash_thump: AudioStreamPlayer
var bass_p: AudioStreamPlayer
var hat_p: AudioStreamPlayer
var bass_streams := {}
var hat_stream: AudioStreamWAV
var bass_pattern := [55.0, 55.0, 0.0, 55.0, 65.41, 0.0, 73.42, 49.0]

# ============================================================
func _ready() -> void:
	randomize()
	_build_environment()
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	_build_floor(scenery)
	_build_buildings(scenery)
	_build_stars(scenery)
	_build_sun(scenery)
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	_build_player()
	_build_camera()
	_build_hud()
	_build_audio()
	_show_menu()

# ============================================================
#  WORLD BUILDING
# ============================================================
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.01, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.95)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.07, 0.32)
	env.fog_density = 0.0042
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36.0, -22.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.9)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)

func _make_grid_texture() -> ImageTexture:
	var img := Image.create_empty(256, 768, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.016, 0.06))
	var dim := Color(0.05, 0.32, 0.45)
	var bright := Color(0.12, 0.95, 1.0)
	var x := 0
	while x < 256:
		img.fill_rect(Rect2i(x, 0, 1, 768), dim)
		x += 64
	var y := 0
	while y < 768:
		img.fill_rect(Rect2i(0, y, 256, 1), dim)
		y += 64
	img.fill_rect(Rect2i(0, 0, 2, 768), bright)
	img.fill_rect(Rect2i(128, 0, 2, 768), bright)
	y = 0
	while y < 768:
		img.fill_rect(Rect2i(0, y, 256, 2), bright)
		y += 192
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_floor(scenery: Node3D) -> void:
	var tex := _make_grid_texture()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 0.75
	for i in SEG_COUNT:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(16.0, SEG_LEN)
		pm.material = mat
		mi.mesh = pm
		mi.position = Vector3(0.0, 0.0, 24.0 - float(i) * SEG_LEN)
		scenery.add_child(mi)
		floor_segs.append(mi)

func _build_buildings(scenery: Node3D) -> void:
	var palette := [
		Color(0.95, 0.2, 0.85), Color(0.2, 0.85, 1.0),
		Color(1.0, 0.55, 0.15), Color(0.55, 1.0, 0.45),
	]
	for c in palette:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.045, 0.03, 0.09)
		m.roughness = 0.7
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.22
		building_mats.append(m)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	for i in BLD_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		scenery.add_child(mi)
		buildings.append(mi)
		_reset_building(mi, 12.0 - float(i) * BLD_GAP)

func _reset_building(mi: MeshInstance3D, z: float) -> void:
	var side := -1.0 if fmod(float(buildings.find(mi)), 2.0) < 1.0 else 1.0
	if randf() < 0.5:
		side = -side
	var w := randf_range(2.0, 5.5)
	var h := randf_range(3.0, 15.0)
	var d := randf_range(4.0, 9.0)
	mi.scale = Vector3(w, h, d)
	mi.position = Vector3(side * randf_range(9.5, 15.5), h * 0.5, z)
	mi.material_override = building_mats[randi() % building_mats.size()]

func _build_stars(scenery: Node3D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.85, 1.0)
	sm.material = mat
	mm.mesh = sm
	mm.instance_count = 150
	for i in 150:
		var t := Transform3D()
		var ang := randf_range(-2.6, 2.6)
		var r := randf_range(110.0, 260.0)
		t.origin = Vector3(sin(ang) * r, randf_range(6.0, 110.0), -absf(cos(ang)) * r - 20.0)
		var s := randf_range(0.35, 1.0)
		t.basis = Basis().scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	scenery.add_child(mmi)

func _make_sun_texture() -> ImageTexture:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c := Vector2(128.0, 128.0)
	for y in 256:
		for x in 256:
			var d := Vector2(float(x), float(y)).distance_to(c)
			if d < 118.0:
				var t := 1.0 - d / 118.0
				var col := Color(1.0, 0.3, 0.75).lerp(Color(1.0, 0.85, 0.45), t * t)
				var a := clampf(t * 1.8, 0.0, 1.0)
				if y > 140 and int((y - 140) / 7) % 2 == 1:
					a = 0.0
				col.a = a
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _build_sun(scenery: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _make_sun_texture()
	var qm := QuadMesh.new()
	qm.size = Vector2(48.0, 48.0)
	qm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.position = Vector3(0.0, 17.0, -186.0)
	scenery.add_child(mi)

func _build_player() -> void:
	player = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	sm.radial_segments = 24
	sm.rings = 14
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.85, 1.0)
	mat.metallic = 0.35
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.95, 1.0)
	mat.emission_energy_multiplier = 1.8
	sm.material = mat
	player.mesh = sm
	add_child(player)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.25, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.2, 0.85)
	ring_mat.emission_energy_multiplier = 1.6
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.86
	tm.ring_segments = 28
	tm.material = ring_mat
	player_ring = MeshInstance3D.new()
	player_ring.mesh = tm
	player.add_child(player_ring)

	player_light = OmniLight3D.new()
	player_light.light_color = Color(0.25, 0.9, 1.0)
	player_light.light_energy = 2.6
	player_light.omni_range = 8.0
	player.add_child(player_light)
	player.position = Vector3(0.0, REST_Y, 0.0)

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 420.0
	cam.position = Vector3(0.0, 3.2, 6.4)
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.0, -8.0), Vector3.UP)

# ============================================================
#  HUD
# ============================================================
func _make_label_settings(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_color = Color(0.02, 0.05, 0.15)
	ls.outline_size = 6
	return ls

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	hud_score = Label.new()
	hud_score.position = Vector2(18, 12)
	hud_score.label_settings = _make_label_settings(30, Color(0.75, 1.0, 1.0))
	hud_score.text = "SCORE 000000"
	cl.add_child(hud_score)

	hud_best = Label.new()
	hud_best.position = Vector2(18, 52)
	hud_best.label_settings = _make_label_settings(18, Color(1.0, 0.55, 0.9))
	hud_best.text = "BEST 000000"
	cl.add_child(hud_best)

	hud_speed = Label.new()
	hud_speed.position = Vector2(18, 78)
	hud_speed.label_settings = _make_label_settings(18, Color(0.6, 0.95, 0.75))
	hud_speed.text = ""
	cl.add_child(hud_speed)

	menu_overlay = Label.new()
	menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_overlay.label_settings = _make_label_settings(30, Color(0.8, 1.0, 1.0))
	cl.add_child(menu_overlay)

	death_overlay = Label.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_overlay.label_settings = _make_label_settings(30, Color(1.0, 0.45, 0.55))
	death_overlay.visible = false
	cl.add_child(death_overlay)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.15, 0.25, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(flash)

func _show_menu() -> void:
	menu_overlay.text = "N E O N   R U S H\n\n\u25c4 \u25ba  /  A D  —  switch lanes\nSPACE / W  —  jump\n\npress any key or click to start"
	menu_overlay.visible = true
	death_overlay.visible = false

# ============================================================
#  AUDIO (all synthesized)
# ============================================================
func _tone(freq: float, dur: float, vol: float, type: String = "sine", freq2: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * float(rate))
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	var phase := 0.0
	var f2 := freq2 if freq2 > 0.0 else freq
	for i in n:
		var t := float(i) / float(rate)
		var k := float(i) / float(n)
		var f := lerpf(freq, f2, k)
		phase += TAU * f / float(rate)
		var s := 0.0
		match type:
			"sine":
				s = sin(phase)
			"square":
				s = 1.0 if fmod(phase, TAU) < PI else -1.0
			"noise":
				s = randf_range(-1.0, 1.0)
		var env := pow(1.0 - k, 2.0)
		buf.put_16(int(clampf(s * vol * env, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = buf.data_array
	return wav

func _make_player(stream: AudioStreamWAV, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	return p

func _build_audio() -> void:
	sfx_pickup = _make_player(_tone(880.0, 0.14, 0.5, "sine", 1760.0), -4.0)
	sfx_jump = _make_player(_tone(240.0, 0.2, 0.35, "sine", 540.0), -6.0)
	sfx_start = _make_player(_tone(523.0, 0.2, 0.4, "sine", 784.0), -5.0)
	sfx_crash_noise = _make_player(_tone(400.0, 0.55, 0.7, "noise"), -3.0)
	sfx_crash_thump = _make_player(_tone(110.0, 0.5, 0.8, "sine", 32.0), -2.0)
	for f in [55.0, 65.41, 73.42, 49.0]:
		bass_streams[f] = _tone(f * 2.0, 0.19, 0.22, "square")
	hat_stream = _tone(6000.0, 0.035, 0.14, "noise")
	bass_p = _make_player(bass_streams[55.0], -8.0)
	hat_p = _make_player(hat_stream, -16.0)

func _tick_music(dt: float) -> void:
	music_acc += dt
	while music_acc >= MUSIC_STEP:
		music_acc -= MUSIC_STEP
		var f: float = bass_pattern[music_step % bass_pattern.size()]
		if f > 0.0:
			bass_p.stream = bass_streams[f]
			bass_p.play()
		hat_p.volume_db = -14.0 if music_step % 2 == 0 else -20.0
		hat_p.play()
		music_step += 1

# ============================================================
#  SPAWNING
# ============================================================
func _neon_material(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.55)
	m.metallic = 0.2
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _add_pillar(lane_idx: int) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 3.4, 1.4)
	bm.material = _neon_material(Color(1.0, 0.18, 0.45), 1.6)
	mi.mesh = bm
	mi.position = Vector3(LANES[lane_idx], 1.7, SPAWN_Z)
	mi.set_meta("type", "pillar")
	entities.add_child(mi)

func _add_bar() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(11.5, 1.0, 1.1)
	bm.material = _neon_material(Color(1.0, 0.62, 0.12), 1.5)
	mi.mesh = bm
	mi.position = Vector3(0.0, 0.5, SPAWN_Z)
	mi.set_meta("type", "bar")
	entities.add_child(mi)

func _add_orb(lane_idx: int, dz: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	sm.radial_segments = 12
	sm.rings = 8
	sm.material = _neon_material(Color(0.55, 1.0, 0.35), 2.0)
	mi.mesh = sm
	mi.position = Vector3(LANES[lane_idx], 1.0, SPAWN_Z + dz)
	mi.set_meta("type", "orb")
	entities.add_child(mi)

func _spawn_row() -> void:
	var r := randf()
	if r < 0.5:
		var lanes := [0, 1, 2]
		lanes.shuffle()
		var count := 1 if randf() < 0.45 else 2
		for i in count:
			_add_pillar(lanes[i])
		if randf() < 0.5:
			_add_orb(lanes[count], 0.0)
	elif r < 0.78:
		_add_bar()
		if randf() < 0.6:
			_add_orb(randi() % 3, -9.0)
	else:
		var l := randi() % 3
		for i in 3 + randi() % 3:
			_add_orb(l, -float(i) * 3.0)

func _clear_entities() -> void:
	for e in entities.get_children():
		e.queue_free()
	for d in debris:
		if is_instance_valid(d.node):
			d.node.queue_free()
	debris.clear()

# ============================================================
#  GAME FLOW
# ============================================================
func _start_game() -> void:
	_clear_entities()
	score = 0.0
	speed = START_SPEED
	lane = 1
	player_x = 0.0
	player_y = REST_Y
	player_vy = 0.0
	spawn_dist = 0.0
	next_gap = 22.0
	music_step = 0
	music_acc = 0.0
	player.visible = true
	player_light.visible = true
	menu_overlay.visible = false
	death_overlay.visible = false
	state = State.PLAYING
	sfx_start.play()

func _die() -> void:
	state = State.DEAD
	dead_time = 0.0
	shake = 1.0
	best = maxf(best, score)
	sfx_crash_noise.play()
	sfx_crash_thump.play()
	var tw := create_tween()
	flash.color = Color(1.0, 0.15, 0.25, 0.55)
	tw.tween_property(flash, "color", Color(1.0, 0.15, 0.25, 0.0), 0.7)
	_spawn_debris(player.position)
	player.visible = false
	player_light.visible = false
	death_overlay.text = "W R E C K E D\n\nSCORE %06d   ·   BEST %06d\n\nENTER / CLICK — run it back" % [int(score), int(best)]
	death_overlay.visible = true

func _spawn_debris(at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, 0.22)
	for i in 18:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		var m := _neon_material([Color(0.2, 0.9, 1.0), Color(1.0, 0.25, 0.8), Color(1.0, 0.9, 0.3)][i % 3], 2.0)
		mi.material_override = m
		mi.position = at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		add_child(mi)
		debris.append({
			"node": mi,
			"vel": Vector3(randf_range(-7.0, 7.0), randf_range(2.0, 11.0), randf_range(-4.0, 9.0)),
			"life": randf_range(0.7, 1.3),
		})

func _update_debris(dt: float) -> void:
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
			d.node.rotation.x += 7.0 * dt
			d.node.rotation.y += 5.0 * dt
			var s := clampf(d.life, 0.0, 1.0)
			d.node.scale = Vector3(s, s, s)
		i -= 1

# ============================================================
#  INPUT
# ============================================================
func _try_jump() -> void:
	if state == State.PLAYING and player_y <= REST_Y + 0.02:
		player_vy = JUMP_VELOCITY
		sfx_jump.play()

func _steer(dir: int) -> void:
	if state == State.PLAYING:
		lane = GameLogic.clamp_lane(lane + dir)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		var pk: int = ev.physical_keycode
		match state:
			State.MENU:
				_start_game()
			State.PLAYING:
				if k in [KEY_LEFT, KEY_A] or pk in [KEY_LEFT, KEY_A]:
					_steer(-1)
				elif k in [KEY_RIGHT, KEY_D] or pk in [KEY_RIGHT, KEY_D]:
					_steer(1)
				elif k in [KEY_SPACE, KEY_UP, KEY_W] or pk in [KEY_SPACE, KEY_UP, KEY_W]:
					_try_jump()
			State.DEAD:
				if dead_time > 0.45:
					_start_game()
	elif ev is InputEventMouseButton and ev.pressed:
		if state == State.MENU or (state == State.DEAD and dead_time > 0.45):
			_start_game()
	elif ev is InputEventScreenTouch and ev.pressed:
		match state:
			State.MENU:
				_start_game()
			State.PLAYING:
				var w := get_viewport().get_visible_rect().size.x
				if ev.position.x < w / 3.0:
					_steer(-1)
				elif ev.position.x > w * 2.0 / 3.0:
					_steer(1)
				else:
					_try_jump()
			State.DEAD:
				if dead_time > 0.45:
					_start_game()

# ============================================================
#  MAIN LOOP
# ============================================================
func _scroll_world(dz: float) -> void:
	for seg in floor_segs:
		seg.position.z += dz
		if seg.position.z > 30.0:
			seg.position.z -= SEG_LEN * SEG_COUNT
	for b in buildings:
		b.position.z += dz
		if b.position.z > 20.0:
			b.position.z -= BLD_COUNT * BLD_GAP
			_reset_building(b, b.position.z)

func _update_entities(dz: float, dt: float) -> void:
	for e in entities.get_children():
		if not is_instance_valid(e):
			continue
		e.position.z += dz
		if e.position.z > KILL_Z:
			e.queue_free()
			continue
		var t: String = e.get_meta("type")
		if t == "orb":
			e.rotation.y += 3.5 * dt
			if state == State.PLAYING and absf(e.position.z) < 1.3 \
					and absf(e.position.x - player_x) < 1.35 \
					and absf(e.position.y - player_y) < 1.5:
				score += 50.0
				sfx_pickup.play()
				e.queue_free()
		elif state == State.PLAYING:
			if t == "pillar":
				if absf(e.position.z) < 1.25 and absf(e.position.x - player_x) < 1.75:
					_die()
			elif t == "bar":
				if absf(e.position.z) < 1.1 and not GameLogic.can_clear_bar(player_y):
					_die()

func _update_camera(dt: float) -> void:
	var target := Vector3(player_x * 0.55, 3.2 + player_y * 0.3, 6.4)
	if state == State.MENU:
		target = Vector3(sin(time_alive * 0.4) * 1.6, 3.4 + sin(time_alive * 0.63) * 0.3, 6.4)
	var k := 1.0 - pow(0.0001, dt)
	cam.position = cam.position.lerp(target, k)
	if shake > 0.001:
		cam.position += Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		) * shake * 0.35
		shake = maxf(shake - dt * 2.2, 0.0)
	cam.look_at(Vector3(player_x * 0.35, 1.0 + player_y * 0.2, -8.0), Vector3.UP)
	var sp := clampf((speed - START_SPEED) / (MAX_SPEED - START_SPEED), 0.0, 1.0)
	cam.fov = lerpf(70.0, 84.0, sp)

func _process(dt: float) -> void:
	time_alive += dt
	match state:
		State.MENU:
			speed = 8.0
			_scroll_world(speed * dt)
			player.position = Vector3(0.0, REST_Y + sin(time_alive * 2.2) * 0.08, 0.0)
			player.rotation.x -= speed * dt / 0.55
			player_ring.rotation.x += 1.6 * dt
			menu_overlay.modulate.a = 0.72 + sin(time_alive * 3.0) * 0.28
		State.PLAYING:
			speed = minf(speed + ACCEL * dt, MAX_SPEED)
			var dz := speed * dt
			distance += dz
			score += dz
			player_x = move_toward(player_x, LANES[lane], 14.0 * dt)
			player_vy -= GRAVITY * dt
			player_y += player_vy * dt
			if player_y < REST_Y:
				player_y = REST_Y
				player_vy = 0.0
			player.position = Vector3(player_x, player_y, 0.0)
			player.rotation.x -= dz / 0.55
			player.rotation.z = clampf((LANES[lane] - player_x) * -0.16, -0.45, 0.45)
			player_ring.rotation.x += (1.6 + speed * 0.06) * dt
			_scroll_world(dz)
			spawn_dist += dz
			if spawn_dist >= next_gap:
				spawn_dist = 0.0
				_spawn_row()
				next_gap = GameLogic.next_spawn_gap(speed) + randf_range(-3.0, 3.0)
			_update_entities(dz, dt)
			_tick_music(dt)
			hud_score.text = "SCORE %06d" % int(score)
			hud_best.text = "BEST %06d" % int(best)
			hud_speed.text = "×%.1f  ·  %d m/s" % [speed / START_SPEED, int(speed)]
		State.DEAD:
			dead_time += dt
			speed = lerpf(speed, 0.0, dt * 3.0)
			_scroll_world(speed * dt)
			_update_entities(speed * dt, dt)
			_update_debris(dt)
	_update_camera(dt)
