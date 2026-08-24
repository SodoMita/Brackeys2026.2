extends Area3D
## Enemy bullet-hell projectile. Dodge it — or parry it.

signal consumed(pos: Vector3, parried: bool)

var vel := Vector3.ZERO
var life := 4.0
var damage := 10.0
var radius := 0.18


func _init() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.1)
	sm.material = m
	mi.mesh = sm
	add_child(mi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	cs.shape = ss
	add_child(cs)
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


func _physics_process(dt: float) -> void:
	if dt < 0.0:
		dt = 0.0
	life -= dt
	position += vel * dt
	if life <= 0.0:
		consumed.emit(position, false)
		queue_free()
