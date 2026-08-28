extends Area3D
## Enemy bullet-hell projectile. Dodge it — or parry it.
## Scene-friendly: visual/collision can be provided by .tscn.
## _init creates fallback so headless tests work.

signal consumed(pos: Vector3, parried: bool)

@export var vel := Vector3.ZERO
@export var life := 4.0
@export var damage := 10.0
## Set by CombatDirector when the player parries the shot: from that moment
## the round flies at the nearest enemy and only ever hurts enemies.
@export var reflected := false


func _configured_radius() -> float:
	return float(Cfg.projectile_radius) if Cfg and "projectile_radius" in Cfg else 0.18


func _init() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var sm := SphereMesh.new()
	sm.radius = _configured_radius()
	sm.height = _configured_radius() * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.1)
	sm.material = m
	mi.mesh = sm
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var ss := SphereShape3D.new()
	ss.radius = _configured_radius()
	add_child(cs)
	cs.shape = ss
	monitoring = false


func _ready() -> void:
	_ensure_nodes()
	_apply_configured_radius()


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
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		sm.radial_segments = 8
		sm.rings = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.6, 0.1)
		sm.material = mat
		mi.mesh = sm
		add_child(mi)
	if not has_shape:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var ss := SphereShape3D.new()
		ss.radius = 0.25
		add_child(cs)
		cs.shape = ss
	monitoring = false


func _apply_configured_radius() -> void:
	var radius := _configured_radius()
	for child in get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			var mesh := child.mesh as SphereMesh
			mesh.radius = radius
			mesh.height = radius * 2.0
		elif child is CollisionShape3D and child.shape is SphereShape3D:
			(child.shape as SphereShape3D).radius = radius


func _physics_process(dt: float) -> void:
	life -= dt
	position += vel * dt
	if life <= 0.0:
		consumed.emit(position, false)
		if is_inside_tree():
			queue_free()
		else:
			free()
