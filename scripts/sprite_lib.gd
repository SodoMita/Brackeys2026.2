class_name SpriteLib
## DOOM-style billboard sprites from assets/sprites
## Processed by tools/make_sprites.py via Seirin white/black triangulation:
##   B = F*a, W = F*a + (1-a) => a = 1 - (W-B), F = B/a
##
## Front / back views:
##   Expected files (all optional, fallback to non-directional):
##     <kind>_front_<action><idx>.webp  (e.g. colt_front_walk1.webp)
##     <kind>_back_<action><idx>.webp   (e.g. colt_back_walk1.webp)
##     <kind>_<action><idx>_front.webp  (alt naming)
##     <kind>_<action><idx>.webp        (legacy, used as both)
##
##   Actions: idle, walk, act (shoot/lunge)
##   Directions: front, back, side (side optional)
##
##   Generator workflow (Seirin):
##     1. Complex background reference for identity (optional)
##     2. White plate: figure on pure white #FFFFFF, e.g. colt_front_walk1_white.webp
##     3. Black plate: SAME pose over pure black #000000, e.g. colt_front_walk1_black.webp
##        Generate black as EDIT of white so they register pixel-perfect.
##     4. Triangulate: python3 tools/triangulate_matte.py white black out
##        Or batch: python3 tools/make_sprites.py
##
##   Sheets:
##     colt_front_walk_sheet.webp (or _white/_black pair) -> sliced to plates
##     python3 tools/slice_sheet.py colt_front_walk_sheet 5
##     python3 tools/slice_sheet.py --all

const BASE := "res://assets/sprites/"
const EXT := ".webp"  # lossy WebP as requested

# Helper to list expected files per kind. Each entry can have:
# - walk, idle, act as fallback
# - walk_front, walk_back, etc as directional overrides
const SETS := {
	"colt": {
		# Seirin triangulation: white+black pairs -> RGBA, front/back views, lossy WebP
		# 3-frame walk cycle, straight front/back, plus dead (single view lying)
		"walk_front": ["colt_front_walk1.webp", "colt_front_walk2.webp", "colt_front_walk3.webp"],
		"walk_back": ["colt_back_walk1.webp", "colt_back_walk2.webp", "colt_back_walk3.webp"],
		"idle_front": ["colt_front_idle.webp"],
		"idle_back": ["colt_back_idle.webp"],
		"act_front": ["colt_front_shoot.webp"],
		"act_back": ["colt_back_shoot.webp"],
		"dead": ["colt_dead.webp"],
		# fallback non-directional (legacy side view)
		"walk": ["colt_walk1.webp", "colt_walk2.webp", "colt_walk3.webp"],
		"idle": ["colt_idle.webp"],
		"act": ["colt_shoot.webp"],
		"h": 1.8,
	},
	"boss": {
		# Boss reuses COLT cyborg but corrupted - front/back with tint in game.gd
		"walk_front": ["colt_front_walk1.webp", "colt_front_walk2.webp", "colt_front_walk3.webp"],
		"walk_back": ["colt_back_walk1.webp", "colt_back_walk2.webp", "colt_back_walk3.webp"],
		"idle_front": ["colt_front_idle.webp"],
		"idle_back": ["colt_back_idle.webp"],
		"act_front": ["colt_front_shoot.webp"],
		"act_back": ["colt_back_shoot.webp"],
		"dead": ["colt_dead.webp"],
		"walk": ["colt_walk1.webp", "colt_walk2.webp", "colt_walk3.webp"],
		"idle": ["colt_idle.webp"],
		"act": ["colt_shoot.webp"],
		"h": 1.9,
	},
	"hound": {
		# 3-frame walk side-by-side sheets, front/back straight views, plus dead single view
		"walk_front": ["hound_front_walk1.webp", "hound_front_walk2.webp", "hound_front_walk3.webp"],
		"walk_back": ["hound_back_walk1.webp", "hound_back_walk2.webp", "hound_back_walk3.webp"],
		"idle_front": ["hound_front_idle.webp"],
		"idle_back": ["hound_back_idle.webp"],
		"act_front": ["hound_front_lunge.webp"],
		"act_back": ["hound_back_lunge.webp"],
		"dead": ["hound_dead.webp"],
		"walk": ["hound_front_walk1.webp", "hound_front_walk2.webp", "hound_front_walk3.webp"],
		"idle": ["hound_front_idle.webp"],
		"act": ["hound_front_lunge.webp"],
		"h": 1.7,
	},
	"spitter": {
		# Front view has back too in original idle sheet - sliced into front/back
		# 3-frame walk sheets side-by-side, straight back (not 3/4), plus dead single view
		"walk_front": ["spitter_front_walk1.webp", "spitter_front_walk2.webp", "spitter_front_walk3.webp"],
		"walk_back": ["spitter_back_walk1.webp", "spitter_back_walk2.webp", "spitter_back_walk3.webp"],
		"idle_front": ["spitter_front_idle.webp"],
		"idle_back": ["spitter_back_idle.webp"],
		"act_front": ["spitter_front_shoot.webp"],
		"act_back": ["spitter_back_shoot.webp"],
		"dead": ["spitter_dead.webp"],
		"walk": ["spitter_front_walk1.webp", "spitter_front_walk2.webp", "spitter_front_walk3.webp"],
		"idle": ["spitter_front_idle.webp"],
		"act": ["spitter_front_shoot.webp"],
		"h": 1.9,
	},
}


static func _load_textures(list: Array) -> Array:
	var out: Array = []
	for f in list:
		var path : String = BASE + f
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex:
				out.append(tex)
	return out


static func _build_frames(kind: String) -> SpriteFrames:
	if not SETS.has(kind):
		return null
	var s: Dictionary = SETS[kind]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var any := false

	# Order matters: try to load directional first, then fallback
	# All possible anim keys
	var anim_keys := ["idle_front", "idle_back", "idle",
					  "walk_front", "walk_back", "walk",
					  "act_front", "act_back", "act",
					  "dead", "dead_front", "dead_back",
					  "walk_side", "idle_side", "act_side", "dead_side"]

	for anim in anim_keys:
		if not s.has(anim):
			continue
		var texs := _load_textures(s[anim])
		if texs.is_empty():
			continue
		any = true
		sf.add_animation(anim)
		# loop everything except act
		var is_act := String(anim).begins_with("act")
		sf.set_animation_loop(anim, not is_act)
		sf.set_animation_speed(anim, 6.0 if not is_act else 8.0)
		for t in texs:
			sf.add_frame(anim, t)

	# If no directional loaded but fallback exists via alt naming, try alt discovery
	# (e.g., colt_walk1_front.webp)
	if not any:
		# fallback: scan BASE for any file starting with kind
		# This is handled in build() returning null -> capsule fallback
		pass

	if not any:
		return null
	return sf


static func build(kind: String) -> AnimatedSprite3D:
	# Legacy API — returns single AnimatedSprite3D with best available anims
	# For directional, it will pick front if available, else fallback
	var sf := _build_frames(kind)
	if sf == null:
		return null
	var h: float = float(SETS[kind].h) if SETS[kind].has("h") else 1.8
	var as3 := AnimatedSprite3D.new()
	as3.sprite_frames = sf
	as3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	as3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# pick first anim
	var first := ""
	for cand in ["walk_front", "walk", "idle_front", "idle", "act_front", "act"]:
		if sf.has_animation(cand):
			first = cand
			break
	if first == "":
		first = sf.get_animation_names()[0]
	var tex: Texture2D = sf.get_frame_texture(first, 0)
	if tex:
		as3.pixel_size = h / float(tex.get_height())
	as3.position.y = h / 2.0
	as3.play(first)
	return as3


static func build_actor(kind: String) -> SpriteActor:
	# New API — returns SpriteActor with front/back switching
	var sf := _build_frames(kind)
	if sf == null:
		return null
	var h: float = float(SETS[kind].h) if SETS[kind].has("h") else 1.8
	var actor := SpriteActor.new(sf, h)
	return actor


static func has_directional(kind: String) -> bool:
	if not SETS.has(kind):
		return false
	var s: Dictionary = SETS[kind]
	# check if any _front or _back texture exists
	for key in ["walk_front", "walk_back", "idle_front", "idle_back", "act_front", "act_back"]:
		if s.has(key):
			for f in s[key]:
				if ResourceLoader.exists(BASE + f):
					return true
	return false
