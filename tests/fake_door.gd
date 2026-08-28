extends Node3D
## Door stand-in that records the last state it was told to take, so tests can
## assert sealing/opening without tweening a real mesh.

var closed := false
var set_calls := 0


func door_set(c: bool) -> void:
	closed = c
	set_calls += 1
