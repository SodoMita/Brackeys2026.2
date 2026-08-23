class_name DialogicNode_Input
extends Control

## A node that handles mouse input. This allows limiting mouse input to a
## specific region and avoiding conflicts with other UI elements.
## If no Input node is used, the input subsystem will handle mouse input instead.

func _ready() -> void:
	add_to_group('dialogic_input')
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		DialogicUtil.autoload().Inputs.handle_node_gui_input(event)
