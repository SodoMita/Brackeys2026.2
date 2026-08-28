extends Node3D
## Minimal stand-in for scenes/level_1.tscn so LevelDirector can be tested
## without instantiating the whole level. Mirrors level_1.gd's export surface.

@export var doors: Array[Node3D] = []
@export var terminals: Array[Node3D] = []
@export var trigger_nodes: Array[Area3D] = []
