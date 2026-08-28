extends Node
## Procedural sound effects.
##
## Deliberately NOT `class_name Sfx`: this script is the `Sfx` autoload, and a
## class_name that matches an autoload identifier is a hard parse error
## ("Class 'Sfx' hides an autoload singleton") — which silently failed the
## autoload and shipped the game with no audio at all. The autoload IS the
## global identifier.
##
## The game shipped with no audio at all — the tone synthesiser lived in the
## deleted procedural root and was never restored. Rather than block on art,
## this generates every effect at runtime from a small recipe table, so there
## are no binary assets to commit and every sound is tweakable in one place.
##
## Two deliberate separations:
##   * synth_pcm() is a pure function (no AudioServer, no RNG that varies run
##     to run) so the waveform maths is unit-testable headless.
##   * playback is a small voice pool, because a revolver firing 4x/second
##     would otherwise cut itself off on a single player node.
##
## Autoloaded as `Sfx` so the menus can use it too.

enum Wave { SINE, SQUARE, SAW, NOISE }

const SAMPLE_RATE := 22050
const VOICES := 8

## freq, seconds, waveform, volume, decay-per-second.
const RECIPES := {
	"shot": {"freq": 180.0, "dur": 0.10, "wave": Wave.SQUARE, "vol": 0.50, "decay": 26.0},
	"shotgun": {"freq": 96.0, "dur": 0.18, "wave": Wave.SQUARE, "vol": 0.60, "decay": 18.0},
	"nailgun": {"freq": 320.0, "dur": 0.04, "wave": Wave.SAW, "vol": 0.28, "decay": 40.0},
	"hit": {"freq": 420.0, "dur": 0.07, "wave": Wave.SINE, "vol": 0.34, "decay": 30.0},
	"headshot": {"freq": 880.0, "dur": 0.09, "wave": Wave.SINE, "vol": 0.42, "decay": 24.0},
	"die": {"freq": 140.0, "dur": 0.26, "wave": Wave.SAW, "vol": 0.46, "decay": 12.0},
	"hurt": {"freq": 110.0, "dur": 0.22, "wave": Wave.SQUARE, "vol": 0.50, "decay": 14.0},
	"dash": {"freq": 620.0, "dur": 0.12, "wave": Wave.SINE, "vol": 0.30, "decay": 20.0},
	"slide": {"freq": 240.0, "dur": 0.20, "wave": Wave.NOISE, "vol": 0.22, "decay": 12.0},
	"parry": {"freq": 1320.0, "dur": 0.16, "wave": Wave.SINE, "vol": 0.44, "decay": 16.0},
	"coin": {"freq": 1560.0, "dur": 0.14, "wave": Wave.SINE, "vol": 0.30, "decay": 14.0},
	"windup": {"freq": 300.0, "dur": 0.30, "wave": Wave.SAW, "vol": 0.20, "decay": 4.0},
	"spit": {"freq": 500.0, "dur": 0.10, "wave": Wave.NOISE, "vol": 0.26, "decay": 22.0},
	"buy": {"freq": 700.0, "dur": 0.12, "wave": Wave.SINE, "vol": 0.32, "decay": 18.0},
	"door": {"freq": 70.0, "dur": 0.50, "wave": Wave.SAW, "vol": 0.36, "decay": 6.0},
	"click": {"freq": 900.0, "dur": 0.05, "wave": Wave.SQUARE, "vol": 0.24, "decay": 34.0},
	"move": {"freq": 640.0, "dur": 0.04, "wave": Wave.SINE, "vol": 0.18, "decay": 40.0},
	"victory": {"freq": 520.0, "dur": 0.60, "wave": Wave.SINE, "vol": 0.40, "decay": 4.0},
	"defeat": {"freq": 80.0, "dur": 0.90, "wave": Wave.SAW, "vol": 0.44, "decay": 3.0},
}

var _voices: Array = []
var _cache: Dictionary = {}
var _muted := false


func _ready() -> void:
	if _audio_unavailable():
		return
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		p.bus = "Master"
		add_child(p)
		_voices.append(p)


## Godot's web export plays AudioStreamPlayer fine; only the headless server
## has no audio driver at all.
static func _audio_unavailable() -> bool:
	return DisplayServer.get_name() == "headless"


func play(sound: String, pitch := 1.0, volume_scale := 1.0) -> void:
	if _muted or _voices.is_empty():
		return
	var stream: AudioStreamWAV = _stream_for(sound)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.pitch_scale = clampf(pitch, 0.25, 4.0)
	voice.volume_db = linear_to_db(clampf(volume_scale, 0.0001, 1.0))
	voice.play()


func set_muted(m: bool) -> void:
	_muted = m
	if m:
		for v in _voices:
			if v != null and is_instance_valid(v):
				v.stop()


func is_muted() -> bool:
	return _muted


## Pick an idle voice, or steal the quietest one when all are busy — a machine
## gun should never go silent just because eight shots overlap.
func _free_voice() -> AudioStreamPlayer:
	if _voices.is_empty():
		return null
	var fallback: AudioStreamPlayer = null
	for v in _voices:
		if v == null or not is_instance_valid(v):
			continue
		if not v.playing:
			return v
		if fallback == null or v.volume_db < fallback.volume_db:
			fallback = v
	return fallback


func _stream_for(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var recipe: Dictionary = RECIPES.get(sound, {})
	if recipe.is_empty():
		return null
	var stream := bake(float(recipe["freq"]), float(recipe["dur"]),
		int(recipe["wave"]), float(recipe["vol"]), float(recipe["decay"]))
	if stream != null:
		_cache[sound] = stream
	return stream


# --- synthesis -------------------------------------------------------------


## Build a playable stream from synthesis parameters.
static func bake(freq: float, duration: float, wave: int, volume: float,
		decay: float, sample_rate: int = SAMPLE_RATE) -> AudioStreamWAV:
	var pcm := synth_pcm(freq, duration, wave, volume, decay, sample_rate)
	if pcm.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream


## Pure PCM generation: 16-bit signed mono with an exponential decay envelope.
## Deterministic (the noise waveform is a hash of the sample index, not RNG)
## so tests can assert exact byte counts and sample ranges.
static func synth_pcm(freq: float, duration: float, wave: int, volume: float,
		decay: float, sample_rate: int = SAMPLE_RATE) -> PackedByteArray:
	var out := PackedByteArray()
	var count := int(maxf(duration, 0.0) * float(sample_rate))
	if count <= 0:
		return out
	out.resize(count * 2)
	var amp := clampf(volume, 0.0, 1.0) * 32767.0
	var two_pi := TAU * maxf(freq, 0.0) / float(sample_rate)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var sample := _sample_at(wave, two_pi * float(i), i)
		sample *= exp(-maxf(decay, 0.0) * t) * amp
		var v := int(clampf(sample, -32768.0, 32767.0))
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


static func _sample_at(wave: int, phase: float, index: int) -> float:
	match wave:
		Wave.SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		Wave.SAW:
			return fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		Wave.NOISE:
			return _noise(index)
	return sin(phase)


## Deterministic value noise in -1..1 — a small integer hash of the sample
## index. Keeps synthesis reproducible without pulling in an RNG.
static func _noise(index: int) -> float:
	var h := (index * 1103515245 + 12345) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) * 1274126177
	h = h & 0x7FFFFFFF
	return (float(h) / float(0x7FFFFFFF)) * 2.0 - 1.0


static func has_recipe(sound: String) -> bool:
	return RECIPES.has(sound)
