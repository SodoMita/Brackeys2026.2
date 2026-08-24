class_name SpriteActor
extends Node3D
## Directional billboard actor with front/back views
## Seirin triangulation sprites: front when facing target, back when facing away
## Supports DOOM-style 2-direction (front/back) and optional side.
##
## Usage:
##   var actor = SpriteLib.build_actor("colt")
##   add_child(actor)
##   actor.play("walk")
##   actor.update_direction(to_target, forward)
##   actor.set_flip_h(...)

var sprite: AnimatedSprite3D
var frames: SpriteFrames
var base_anim: String = "walk"
var is_back: bool = false
var _flip_h: bool = false

# how much dot product threshold to switch to back
# dot = forward.dot(to_target_dir)
# >0 = target in front hemisphere => show front
# <0 = target behind => show back
var back_threshold: float = -0.1

func _init(sf: SpriteFrames, height: float) -> void:
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = sf
	sprite.billboard = 1 # BILLBOARD_ENABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frames = sf

	# pixel size from first available frame
	var first_anim: String = ""
	if sf.has_animation("walk_front"):
		first_anim = "walk_front"
	elif sf.has_animation("walk"):
		first_anim = "walk"
	elif sf.has_animation("idle_front"):
		first_anim = "idle_front"
	elif sf.has_animation("idle"):
		first_anim = "idle"
	else:
		# pick any
		for an in sf.get_animation_names():
			first_anim = an
			break

	if first_anim != "":
		var first: Texture2D = sf.get_frame_texture(first_anim, 0)
		if first:
			sprite.pixel_size = height / float(first.get_height())
	sprite.position.y = height / 2.0
	add_child(sprite)
	if first_anim != "":
		sprite.play(first_anim)
		base_anim = _strip_dir(first_anim)


func _strip_dir(anim: String) -> String:
	# walk_front -> walk, idle_back -> idle
	if anim.ends_with("_front"):
		return anim.substr(0, anim.length() - 6)
	if anim.ends_with("_back"):
		return anim.substr(0, anim.length() - 5)
	if anim.ends_with("_side"):
		return anim.substr(0, anim.length() - 5)
	return anim


func _choose_anim(base: String, back: bool) -> String:
	var back_name := base + "_back"
	var front_name := base + "_front"
	var side_name := base + "_side"
	# prefer requested direction
	if back:
		if frames.has_animation(back_name):
			return back_name
		# fallbacks: if no back, try side, then front, then base
		if frames.has_animation(side_name):
			return side_name
		if frames.has_animation(front_name):
			return front_name
		if frames.has_animation(base):
			return base
	else:
		if frames.has_animation(front_name):
			return front_name
		if frames.has_animation(side_name):
			return side_name
		if frames.has_animation(back_name):
			return back_name
		if frames.has_animation(base):
			return base
	# last resort: any animation starting with base
	for an in frames.get_animation_names():
		if String(an).begins_with(base):
			return an
	# absolute fallback: first animation
	if frames.get_animation_names().size() > 0:
		return frames.get_animation_names()[0]
	return ""


func play(base: String, keep_frame: bool = false) -> void:
	base_anim = base
	var want := _choose_anim(base, is_back)
	if want == "":
		return
	if sprite.animation == StringName(want) and keep_frame:
		return
	var frame_idx := sprite.frame if keep_frame else 0
	var prog := sprite.frame_progress if keep_frame else 0.0
	sprite.play(want)
	if keep_frame:
		sprite.frame = frame_idx
		sprite.frame_progress = prog


func update_direction(to_target: Vector3, forward: Vector3) -> void:
	# to_target: vector from self to target (player), y=0
	# forward: self forward dir (where enemy looks), y=0
	var to_dir := to_target
	to_dir.y = 0
	var fwd := forward
	fwd.y = 0
	if to_dir.length_squared() < 0.001 or fwd.length_squared() < 0.001:
		return
	to_dir = to_dir.normalized()
	fwd = fwd.normalized()
	var dot := fwd.dot(to_dir)
	var want_back := dot < back_threshold
	if want_back != is_back:
		is_back = want_back
		# switch anim preserving frame
		play(base_anim, true)


func set_flip_h(f: bool) -> void:
	_flip_h = f
	sprite.flip_h = f


func set_modulate(c: Color) -> void:
	sprite.modulate = c
