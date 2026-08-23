extends Area3D
## Enemy bullet-hell projectile. Dodge it — or parry it.

signal consumed(pos: Vector3, parried: bool)

var vel := Vector3.ZERO
var life := 4.0
var damage := 10.0


func _init() -> void:
	var mi := MeshInstance3D.new()
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
	var cs := CollisionShape3D.new()
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
