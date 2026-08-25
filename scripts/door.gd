extends Node3D

@onready var static_body: StaticBody3D = $StaticBody3D
@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $StaticBody3D/MeshInstance3D



func door_set(closed: bool) -> void:
	# Toggle collision (Note: CollisionShape3D uses "disabled", or you can disable the StaticBody's layer)
	static_body.set_deferred("disabled", not closed)
	
	# Animate mesh position using a Tween
	var tw := create_tween()
	var target_y = 2.5 if closed else 6.5
	tw.tween_property(collision_shape, "position:y", target_y, 0.6)
	tw.tween_property(mesh_instance, "position:y", target_y, 0.6)
	
func set_width(width: float) -> void:
	collision_shape.shape.size = Vector3(width, 5.0, 1.0)
	mesh_instance.mesh.size = Vector3(width, 5.0, 1.0)
