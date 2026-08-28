extends Node
## Cfg — designer-facing tuning values. Everything gameplay-relevant is
## exported so it can be edited from the editor inspector (autoload node).

@export_group("Player movement")
@export var walk_speed := 10.0
@export var jump_velocity := 9.5
@export var gravity := 22.0
@export var accel_ground := 90.0
@export var accel_air := 40.0
@export var friction := 10.0
@export var dash_speed := 24.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.9
@export var slide_max_speed := 17.0
@export var mouse_sensitivity := 0.0026
@export var stick_look_speed := 2.6
@export var invert_look := false

@export_group("Health")
@export var max_hp := 100.0
@export var heal_factor := 0.8          # fraction of dealt damage returned as HP
@export var enemy_damage := 12.0        # damage taken per enemy strike

@export_group("Parry")
@export var parry_active_window := 0.22 # seconds the parry stays active
@export var parry_cooldown := 0.5
@export var parry_heal_bonus := 15.0    # extra HP on successful parry
@export var parry_stagger := 1.2        # seconds the enemy is staggered

@export_group("Weapons")
@export var revolver_damage := 34.0
@export var revolver_cooldown := 0.26
@export var shotgun_damage := 12.0
@export var shotgun_cooldown := 0.75
@export var shotgun_pellets := 7
@export var shotgun_spread := 0.055
@export var coin_toss_velocity := 7.0
@export var coin_lifetime := 1.4
@export var ricochet_damage_mult := 1.5 # per-target damage when shooting the coin
@export var ricochet_targets := 3
@export var headshot_mult := 2.0        # damage multiplier on a headshot
@export var knockback_scale := 0.35     # impulse per point of damage

@export_group("Style")
@export var style_hit := 5.0
@export var style_headshot := 12.0
@export var style_airshot := 10.0
@export var style_slide_kill := 15.0
@export var style_kill := 20.0
@export var style_parry := 25.0
@export var style_ricochet := 18.0
@export var style_dash_kill := 8.0
@export var rank_thresholds: Array[float] = [0.0, 40.0, 100.0, 180.0, 280.0, 400.0, 550.0]
@export var ranks: PackedStringArray = ["D", "C", "B", "A", "S", "SS", "SSS"]
@export var decay_base := 6.0
@export var decay_scale := 0.04

@export_group("Enemies & waves")
@export var enemy_hp := 60.0
@export var enemy_speed := 7.5
@export var enemy_speed_per_wave := 0.5
@export var wave_base_count := 2       # count = base + wave
@export var enemy_windup := 0.45       # telegraph time before a strike (parry window)
@export var enemy_attack_range := 1.7
@export var enemy_strike_cooldown := 1.0

@export_group("Bullet hell & spitters")
@export var spitter_cd := 2.4
@export var spitter_volley := 3
@export var spitter_spread := 0.22
@export var projectile_speed := 12.0
@export var projectile_damage := 10.0
@export var projectile_radius := 0.18

@export_group("Scrap & shop")
@export var scrap_hound := 10
@export var scrap_spitter := 15
@export var scrap_boss := 100
@export var nailgun_cost := 60
@export var plating_cost := 40
@export var overclock_cost := 50
@export var plating_hp := 25.0
@export var overclock_mult := 1.15
@export var nailgun_damage := 8.0
@export var nailgun_cooldown := 0.09

@export_group("Companion & boss")
@export var companion_fire_cd := 1.2
@export var companion_damage := 6.0
@export var boss_hp := 400.0
@export var boss_speed := 9.0

@export_group("Dialogue")
## Explicit resources win; when left null the matching *_name identifier is
## resolved at runtime through Dialogic's own directory (project.godot's
## `directories/dtl_directory`). Names are the safe default because Dialogic
## registers its .dtl loader late, so a .tscn ext_resource to a .dtl can fail
## to parse before the addon is up.
@export var intro_timeline: Resource = null   # plays once on level start
@export var quip_timeline: Resource = null    # plays on room clear
@export var ending_timeline: Resource = null  # plays on victory, before the result card
@export var intro_timeline_name := "intro"
@export var quip_timeline_name := "quip1"
@export var ending_timeline_name := "ending"


var _dtl_loader: ResourceFormatLoader = null


func _enter_tree() -> void:
	# Earliest possible hook: Cfg is the first autoload in project.godot, so
	# this runs before anything can try to load a .dtl.
	_register_dtl_loader()


func _exit_tree() -> void:
	if _dtl_loader != null:
		ResourceLoader.remove_resource_format_loader(_dtl_loader)
		_dtl_loader = null


## Dialogic 2 ships `DialogicTimelineFormatLoader` but never registers it, so
## `ResourceLoader` cannot resolve `res://**.dtl` and every timeline in the
## project is unloadable. The deleted game.gd used to register it at boot; this
## restores that. Without it no dialogue plays — intro, cutscene, quips, ending.
func _register_dtl_loader() -> void:
	if _dtl_loader != null:
		return
	const LOADER := "res://addons/dialogic/Resources/TimelineResourceLoader.gd"
	if not ResourceLoader.exists(LOADER):
		return
	var script: GDScript = load(LOADER)
	if script == null:
		return
	_dtl_loader = script.new() as ResourceFormatLoader
	if _dtl_loader == null:
		return
	ResourceLoader.add_resource_format_loader(_dtl_loader)


func _ready() -> void:
	_register_dtl_loader()
	if intro_timeline == null:
		intro_timeline = timeline_by_name(intro_timeline_name)
	if quip_timeline == null:
		quip_timeline = timeline_by_name(quip_timeline_name)
	if ending_timeline == null:
		ending_timeline = timeline_by_name(ending_timeline_name)


## Resolve a Dialogic timeline identifier to its resource, or null when the
## addon (or that timeline) is unavailable. Never raises — a missing timeline
## must degrade to "no dialogue", not a boot failure.
static func timeline_by_name(identifier: String) -> Resource:
	if identifier.is_empty():
		return null
	if not DialogicResourceUtil.timeline_resource_exists(identifier):
		return null
	return DialogicResourceUtil.get_timeline_resource(identifier)


func heal_on_damage(current_hp: float, damage: float) -> float:
	return clampf(current_hp + damage * heal_factor, 0.0, max_hp)


func rank_for_points(points: float) -> String:
	var rank := String(ranks[0]) if ranks.size() > 0 else "D"
	for i in mini(rank_thresholds.size(), ranks.size()):
		if points >= rank_thresholds[i]:
			rank = String(ranks[i])
	return rank


func decay_rate(points: float) -> float:
	return decay_base + maxf(points, 0.0) * decay_scale
