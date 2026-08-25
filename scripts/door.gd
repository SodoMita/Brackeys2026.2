extends Node3D

@onready var static_body: StaticBody3D = $StaticBody3D
@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $StaticBody3D/MeshInstance3D


func _resolve_nodes() -> void:
	# Door scenes made in the editor may use Body/Mesh while the reusable door
	# scene uses StaticBody3D/MeshInstance3D. Resolve lazily so direct scene
	# tests (which do not run _ready) are safe as well.
	if static_body == null:
		static_body = get_node_or_null("StaticBody3D") as StaticBody3D
		if static_body == null:
			static_body = get_node_or_null("Body") as StaticBody3D
	if collision_shape == null and static_body != null:
		collision_shape = static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if mesh_instance == null and static_body != null:
		mesh_instance = static_body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = static_body.get_node_or_null("Mesh") as MeshInstance3D


func door_set(closed: bool) -> void:
	_resolve_nodes()
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not closed)

	var target_y := 2.5 if closed else 6.5
	if mesh_instance != null:
		if is_inside_tree():
			var tw := create_tween()
			tw.tween_property(mesh_instance, "position:y", target_y, 0.6)
		else:
			mesh_instance.position.y = target_y


func set_width(width: float) -> void:
	_resolve_nodes()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		(collision_shape.shape as BoxShape3D).size = Vector3(width, 5.0, 1.0)
	if mesh_instance != null and mesh_instance.mesh is BoxMesh:
		(mesh_instance.mesh as BoxMesh).size = Vector3(width, 5.0, 1.0)
