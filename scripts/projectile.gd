extends Area3D
## Enemy bullet-hell projectile. Dodge it — or parry it.
## Scene-friendly: visual/collision can be provided by .tscn.

signal consumed(pos: Vector3, parried: bool)

@export var vel := Vector3.ZERO
@export var life := 4.0
@export var damage := 10.0


func _init() -> void:
	pass


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
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
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.6, 0.1)
		sm.material = m
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


func _physics_process(dt: float) -> void:
	life -= dt
	position += vel * dt
	if life <= 0.0:
		consumed.emit(position, false)
		queue_free()
