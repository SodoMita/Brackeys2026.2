class_name SpriteLib
## DOOM-style billboard sprites from assets/sprites (processed by
## tools/make_sprites.py from generated white plates via the Seirin
## difference-matte triangulation).

const BASE := "res://assets/sprites/"

const SETS := {
	"colt": {
		"idle": ["colt_idle.png"],
		"walk": ["colt_walk1.png", "colt_walk2.png", "colt_walk3.png", "colt_walk4.png", "colt_walk5.png"],
		"act": ["colt_shoot.png"],
		"h": 1.8,
	},
	"boss": {
		"idle": ["colt_idle.png"],
		"walk": ["colt_walk1.png", "colt_walk2.png", "colt_walk3.png", "colt_walk4.png", "colt_walk5.png"],
		"act": ["colt_shoot.png"],
		"h": 1.9,
	},
	"hound": {
		"idle": [],
		"walk": ["hound_walk1.png", "hound_walk2.png", "hound_walk3.png", "hound_walk4.png", "hound_walk5.png"],
		"act": ["hound_lunge.png"],
		"h": 1.7,
	},
	"spitter": {
		"idle": [],
		"walk": ["spitter_walk1.png", "spitter_walk2.png", "spitter_walk3.png", "spitter_walk4.png", "spitter_walk5.png"],
		"act": ["spitter_shoot.png"],
		"h": 1.9,
	},
}


static func build(kind: String) -> AnimatedSprite3D:
	if not SETS.has(kind):
		return null
	var s: Dictionary = SETS[kind]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var any := false
	for anim in ["idle", "walk", "act"]:
		var got: Array = []
		for f in s[anim]:
			if ResourceLoader.exists(BASE + f):
				got.append(load(BASE + f))
		if got.is_empty():
			continue
		any = true
		sf.add_animation(anim)
		sf.set_animation_loop(anim, anim != "act")
		sf.set_animation_speed(anim, 6.0)
		for t in got:
			sf.add_frame(anim, t)
	if not any:
		return null
	var as3 := AnimatedSprite3D.new()
	as3.sprite_frames = sf
	as3.billboard = 1  # BILLBOARD_ENABLED
	as3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var first_anim := "walk" if sf.has_animation("walk") else "act"
	var first: Texture2D = sf.get_frame_texture(first_anim, 0)
	as3.pixel_size = float(s.h) / float(first.get_height())
	as3.position.y = float(s.h) / 2.0
	as3.play(first_anim)
	return as3
