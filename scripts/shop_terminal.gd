extends StaticBody3D
## Scrap terminal. E to open, 1/2/3 to buy, E to close.

signal purchase_requested(item: int)

var player_ref: Node3D = null
var open := false
var prompt: Label
var panel: Label


func _init() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.4, 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.08, 0.06)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.1)
	m.emission_energy_multiplier = 0.8
	bm.material = m
	mi.mesh = bm
	mi.position = Vector3(0.0, 0.7, 0.0)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 1.4, 0.4)
	cs.shape = bs
	add_child(cs)


func setup_ui(cl: CanvasLayer) -> void:
	prompt = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 10
	ls.font_color = Color(1.0, 0.8, 0.4)
	prompt.label_settings = ls
	prompt.position = Vector2(120, 100)
	prompt.text = "E — SHOP"
	prompt.visible = false
	cl.add_child(prompt)
	panel = Label.new()
	var ls2 := LabelSettings.new()
	ls2.font_size = 9
	ls2.font_color = Color(1.0, 0.9, 0.7)
	panel.label_settings = ls2
	panel.position = Vector2(90, 40)
	panel.visible = false
	cl.add_child(panel)


func refresh_panel(scrap: int, has_nailgun: bool) -> void:
	panel.text = "S C R A P   T E R M I N A L   [%d scrap]\n\n1 · NAILGUN ............ %d%s\n2 · REINFORCED PLATING . %d  (+%d HP)\n3 · OVERCLOCK .......... %d  (+15%% dmg)\n\nE — close" % [
		scrap, Cfg.nailgun_cost, " (owned)" if has_nailgun else "", Cfg.plating_cost, int(Cfg.plating_hp), Cfg.overclock_cost]


func _process(_dt: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		var near := global_position.distance_to(player_ref.global_position) < 2.6
		prompt.visible = near and not open
		if open:
			if Input.is_key_pressed(KEY_ESCAPE):
				close()
	elif prompt:
		prompt.visible = false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_E and prompt.visible or (open and ev.keycode == KEY_E):
			if open:
				close()
			else:
				open = true
				player_ref.disabled = true
				panel.visible = true
				purchase_requested.emit(-1)  # ask game to refresh the panel
		elif open and ev.keycode in [KEY_1, KEY_2, KEY_3]:
			purchase_requested.emit({KEY_1: 0, KEY_2: 1, KEY_3: 2}[ev.keycode])


func close() -> void:
	open = false
	panel.visible = false
	if player_ref:
		player_ref.disabled = false
