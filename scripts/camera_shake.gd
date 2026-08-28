class_name CameraShake
extends Node
## Trauma-based camera shake.
##
## The `screen_shake` setting in the options menu had no consumer anywhere in
## the project — the slider did nothing. This is that consumer, and it reads
## the setting on every kick so toggling it off silences shake immediately
## without needing a notification path.
##
## It offsets the camera's *local* transform, which the FPS controller never
## writes per frame (player.gd drives head.rotation and leaves cam.position
## alone), so the two do not fight over the same values.

const DECAY := 1.6
const MAX_OFFSET := 0.34
const MAX_ROLL := 0.035

var camera: Camera3D = null
var trauma := 0.0


func setup(cam: Camera3D) -> void:
	camera = cam


## Add shake. Clamped so a shotgun blast cannot launch the view off-screen.
func add(amount: float) -> void:
	if not enabled():
		return
	trauma = clampf(trauma + maxf(amount, 0.0), 0.0, 1.0)


func reset() -> void:
	trauma = 0.0
	if camera != null and is_instance_valid(camera):
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO


func _process(dt: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if trauma <= 0.0:
		# Snap back exactly once rather than every frame at rest.
		if camera.position != Vector3.ZERO or not camera.rotation.is_equal_approx(Vector3.ZERO):
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO
		return
	trauma = maxf(0.0, trauma - DECAY * dt)
	_apply()


## Quadratic falloff: small hits barely register, big ones really move.
## Scaled by the options-menu intensity so the slider is a real control.
func _apply() -> void:
	var s := trauma * trauma * intensity()
	var offset := Vector3(
		randf_range(-MAX_OFFSET, MAX_OFFSET) * s,
		randf_range(-MAX_OFFSET, MAX_OFFSET) * s,
		0.0)
	camera.position = offset
	camera.rotation = Vector3(0.0, 0.0, randf_range(-MAX_ROLL, MAX_ROLL) * s)


## The options menu stores screen_shake as a 0..1 intensity.
static func enabled() -> bool:
	return intensity() > 0.0


static func intensity() -> float:
	if Settings == null or not ("current" in Settings):
		return 1.0
	return clampf(float(Settings.current.get("screen_shake", 1.0)), 0.0, 1.0)
