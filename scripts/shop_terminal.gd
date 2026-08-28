extends StaticBody3D
## Scrap terminal. E to open, 1/2/3 to buy, E to close.
## Scene-friendly: mesh/collision can be provided by .tscn, fallback created if missing.
## _init creates fallback for headless tests.

signal purchase_requested(item: int)

var player_ref: Node3D = null
var open := false
var prompt: Label
var panel: Label


func _init() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
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
	cs.name = "CollisionShape3D"
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 1.4, 0.4)
	add_child(cs)
	cs.shape = bs


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	var meshes: Array = []
	var shapes: Array = []
	for child in get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		if child is CollisionShape3D:
			shapes.append(child)
	if meshes.size() > 1:
		for i in range(meshes.size() - 1):
			if meshes[i].is_inside_tree():
				meshes[i].queue_free()
			else:
				meshes[i].free()
	if shapes.size() > 1:
		for i in range(shapes.size() - 1):
			if shapes[i].is_inside_tree():
				shapes[i].queue_free()
			else:
				shapes[i].free()
	var has_mesh := false
	var has_shape := false
	for child in get_children():
		if child is MeshInstance3D:
			has_mesh = true
		if child is CollisionShape3D:
			has_shape = true
	if not has_mesh:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
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
	if not has_shape:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 1.4, 0.4)
		add_child(cs)
		cs.shape = bs


func setup_ui(cl: CanvasLayer) -> void:
	# Avoid duplicate UI if called twice
	if prompt and is_instance_valid(prompt):
		return
	prompt = Label.new()
	prompt.name = "ShopPrompt"
	var ls := LabelSettings.new()
	ls.font_size = 10
	ls.font_color = Color(1.0, 0.8, 0.4)
	prompt.label_settings = ls
	prompt.position = Vector2(120, 100)
	prompt.text = "E — SHOP"
	prompt.visible = false
	cl.add_child(prompt)
	panel = Label.new()
	panel.name = "ShopPanel"
	var ls2 := LabelSettings.new()
	ls2.font_size = 9
	ls2.font_color = Color(1.0, 0.9, 0.7)
	panel.label_settings = ls2
	panel.position = Vector2(90, 40)
	panel.visible = false
	cl.add_child(panel)


func refresh_panel(scrap: int, has_nailgun: bool) -> void:
	if panel == null:
		return
	panel.text = "S C R A P   T E R M I N A L   [%d scrap]\n\n1 · NAILGUN ............ %d%s\n2 · REINFORCED PLATING . %d  (+%d HP)\n3 · OVERCLOCK .......... %d  (+15%% dmg)\n\nE — close" % [
		scrap, Cfg.nailgun_cost, " (owned)" if has_nailgun else "", Cfg.plating_cost, int(Cfg.plating_hp), Cfg.overclock_cost]


func _process(_dt: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		var near := global_position.distance_to(player_ref.global_position) < 2.6
		if prompt:
			prompt.visible = near and not open
		# Walking out of reach closes the shop, so it can never stay open
		# behind the player (e.g. after a pause/resume cleared `disabled`).
		if open and not near:
			close()
	elif prompt:
		prompt.visible = false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var e_pressed := ev.keycode == KEY_E
		if (e_pressed and prompt != null and prompt.visible) or (open and e_pressed):
			if open:
				close()
			else:
				open = true
				if player_ref:
					player_ref.disabled = true
				if panel:
					panel.visible = true
				purchase_requested.emit(-1)  # ask game to refresh the panel
		elif open and ev.keycode in [KEY_1, KEY_2, KEY_3]:
			purchase_requested.emit({KEY_1: 0, KEY_2: 1, KEY_3: 2}[ev.keycode])


func close() -> void:
	open = false
	if panel:
		panel.visible = false
	if player_ref:
		player_ref.disabled = false
