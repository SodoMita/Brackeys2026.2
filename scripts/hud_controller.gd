class_name HudController
extends Node
## Binds the authored HUD (scenes/hud.tscn) to live run state.
##
## The HUD scene was authored with empty labels and nothing ever wrote to them
## once game.gd was removed. This is the only place that touches those nodes,
## so the scene stays designer-editable and the wiring stays reviewable.
##
## Every label is optional: a missing node is simply skipped, which keeps the
## controller usable with a partial or hand-built HUD.

const WEAPON_NAMES := ["REVOLVER", "SHOTGUN", "NAILGUN"]
const HURT_FLASH_COLOR := Color(0.75, 0.06, 0.06, 0.42)
const HURT_FLASH_DECAY := 2.6

var hud: CanvasLayer = null
var player: Node3D = null
var stats: RunStats = null
var director: LevelDirector = null

var _hp: Label
var _rank: Label
var _wave: Label
var _scrap: Label
var _weapon: Label
var _overlay: Label
var _crosshair: Control
var _hurt_flash: ColorRect
var _overlay_t := 0.0
var _flash := 0.0


func bind(p_hud: CanvasLayer, p_player: Node3D, p_stats: RunStats,
		p_director: LevelDirector) -> void:
	hud = p_hud
	player = p_player
	stats = p_stats
	director = p_director
	if hud == null:
		return
	_hp = _label("HP")
	_rank = _label("Rank")
	_wave = _label("Wave")
	_scrap = _label("Scrap")
	_weapon = _label("Weapon")
	_overlay = _label("Overlay")
	_crosshair = hud.get_node_or_null("Crosshair") as Control
	_hurt_flash = hud.get_node_or_null("HurtFlash") as ColorRect
	if _hurt_flash != null:
		_hurt_flash.color = HURT_FLASH_COLOR
		_hurt_flash.modulate.a = 0.0
	# The authored HUD ships with the title pre-typed in the overlay label; let
	# it act as a boot splash that clears itself instead of lingering forever.
	if _overlay != null and not _overlay.text.is_empty():
		_overlay_t = 3.0
	_refresh()


func _process(dt: float) -> void:
	if dt > 0.0:
		_tick_fx(dt)
	_refresh()


func _tick_fx(dt: float) -> void:
	if _flash > 0.0 and _hurt_flash != null:
		_flash = maxf(0.0, _flash - HURT_FLASH_DECAY * dt)
		_hurt_flash.modulate.a = _flash
	if _overlay_t > 0.0 and _overlay != null:
		_overlay_t -= dt
		if _overlay_t <= 0.0:
			_overlay.text = ""


func _refresh() -> void:
	if stats == null:
		return
	if _hp != null and player != null and "hp" in player:
		var hp := float(player.hp)
		var max_hp := _max_hp()
		_hp.text = "HP %d / %d" % [int(ceil(hp)), int(max_hp)]
	if _rank != null:
		_rank.text = stats.rank()
	if _scrap != null:
		_scrap.text = "SCRAP %d" % stats.scrap
	if _weapon != null and player != null and "weapon" in player:
		var idx := int(player.weapon)
		_weapon.text = WEAPON_NAMES[idx] if idx >= 0 and idx < WEAPON_NAMES.size() else "?"
	if _crosshair != null:
		# The reticle only exists while the player is in control — hidden by
		# the shop, dialogue, pause and the result card (all use `disabled`).
		_crosshair.visible = player == null or not bool(player.get("disabled"))
	if _wave != null and director != null:
		_wave.text = _wave_text()


func _wave_text() -> String:
	if director == null:
		return ""
	match director.phase:
		LevelDirector.Phase.IDLE:
			# room_index is -1 before the first room and points at the room
			# just cleared afterwards, so +2 (clamped) is the room to reach.
			var next := clampi(director.room_index + 2, 1, RoomPlan.room_count())
			return "ROOM %d / %d" % [next, RoomPlan.room_count()]
		LevelDirector.Phase.FIGHTING:
			return "HOSTILES %d" % director.alive
		LevelDirector.Phase.CLEARED:
			return "ROOM CLEAR"
		LevelDirector.Phase.FINISHED:
			return "SITE SECURED"
	return "..."


## Transient centred message (room cleared, boss incoming, ...).
func say(text: String, duration := 2.4) -> void:
	if _overlay == null:
		return
	_overlay.text = text
	_overlay_t = duration


func flash_hurt(strength := 1.0) -> void:
	_flash = clampf(strength, 0.0, 1.0)


func _label(node_name: String) -> Label:
	if hud == null:
		return null
	return hud.get_node_or_null(node_name) as Label


static func _max_hp() -> float:
	if Cfg != null and "max_hp" in Cfg:
		return float(Cfg.max_hp)
	return 100.0
