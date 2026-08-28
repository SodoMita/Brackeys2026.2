extends TestBase
## Unit tests for the procedural SFX synthesis.
##
## The maths is a pure static (synth_pcm) precisely so it can be asserted
## without an audio driver — headless CI has none, and that is exactly where
## these need to run.

const RATE := 22050


func test_pcm_byte_count_matches_duration() -> void:
	# 16-bit mono: 2 bytes per sample, sample_rate samples per second.
	var pcm := Sfx.synth_pcm(440.0, 0.1, Sfx.Wave.SINE, 0.5, 6.0, RATE)
	assert_eq(float(pcm.size()), float(int(0.1 * RATE) * 2), "bytes = samples * 2")


func test_pcm_respects_sample_rate() -> void:
	var a := Sfx.synth_pcm(440.0, 0.05, Sfx.Wave.SINE, 0.5, 6.0, 22050)
	var b := Sfx.synth_pcm(440.0, 0.05, Sfx.Wave.SINE, 0.5, 6.0, 11025)
	assert_eq(float(a.size()), float(b.size()) * 2.0, "halving the rate halves the bytes")


func test_pcm_never_clips() -> void:
	for wave in [Sfx.Wave.SINE, Sfx.Wave.SQUARE, Sfx.Wave.SAW, Sfx.Wave.NOISE]:
		var pcm := Sfx.synth_pcm(440.0, 0.05, wave, 1.0, 0.0, RATE)
		assert_false(pcm.is_empty(), "waveform %d produced samples" % wave)
		for i in range(0, pcm.size() - 1, 2):
			var v := pcm[i] | (pcm[i + 1] << 8)
			if v >= 32768:
				v -= 65536
			assert_ge(float(v), -32768.0, "sample above the 16-bit floor")
			assert_le(float(v), 32767.0, "sample below the 16-bit ceiling")


func test_envelope_decays() -> void:
	var pcm := Sfx.synth_pcm(440.0, 0.2, Sfx.Wave.SINE, 0.8, 20.0, RATE)
	var head := _peak(pcm, 0, 200)
	var tail := _peak(pcm, pcm.size() - 400, pcm.size())
	assert_gt(head, tail, "the decay envelope reduces amplitude over time")
	assert_gt(head, 0.0, "and the start is audible")


func test_zero_decay_sustains() -> void:
	var pcm := Sfx.synth_pcm(440.0, 0.2, Sfx.Wave.SINE, 0.8, 0.0, RATE)
	var head := _peak(pcm, 0, 200)
	var tail := _peak(pcm, pcm.size() - 400, pcm.size())
	assert_near(head, tail, head * 0.01, "no decay means constant amplitude")


func test_volume_scales_amplitude() -> void:
	var quiet := _peak_all(Sfx.synth_pcm(440.0, 0.05, Sfx.Wave.SINE, 0.2, 0.0, RATE))
	var loud := _peak_all(Sfx.synth_pcm(440.0, 0.05, Sfx.Wave.SINE, 0.8, 0.0, RATE))
	assert_gt(loud, quiet * 3.0, "four times the volume is roughly four times the peak")


func test_invalid_duration_is_empty() -> void:
	assert_eq(float(Sfx.synth_pcm(440.0, 0.0, Sfx.Wave.SINE, 0.5, 6.0, RATE).size()), 0.0,
		"zero duration makes no samples")
	assert_eq(float(Sfx.synth_pcm(440.0, -1.0, Sfx.Wave.SINE, 0.5, 6.0, RATE).size()), 0.0,
		"negative duration is safe")


func test_bake_produces_a_playable_stream() -> void:
	var stream := Sfx.bake(440.0, 0.1, Sfx.Wave.SINE, 0.5, 6.0)
	assert_true(stream != null, "bake returns a stream")
	assert_eq(float(stream.format), float(AudioStreamWAV.FORMAT_16_BITS), "16-bit PCM")
	assert_eq(float(stream.mix_rate), float(Sfx.SAMPLE_RATE), "declared mix rate")
	assert_false(stream.stereo, "mono")
	assert_gt(float(stream.data.size()), 0.0, "carries sample data")


func test_bake_rejects_empty_input() -> void:
	assert_true(Sfx.bake(440.0, 0.0, Sfx.Wave.SINE, 0.5, 6.0) == null, "no samples, no stream")


func test_every_recipe_is_complete_and_sane() -> void:
	# A typo in this table would otherwise only surface as silence at runtime.
	for key in Sfx.RECIPES:
		var r: Dictionary = Sfx.RECIPES[key]
		for field in ["freq", "dur", "wave", "vol", "decay"]:
			assert_true(r.has(field), "'%s' declares %s" % [key, field])
		assert_gt(float(r.get("freq", 0.0)), 0.0, "'%s' has a positive frequency" % key)
		assert_gt(float(r.get("dur", 0.0)), 0.0, "'%s' has a positive duration" % key)
		assert_gt(float(r.get("vol", 0.0)), 0.0, "'%s' is audible" % key)
		assert_le(float(r.get("vol", 0.0)), 1.0, "'%s' volume is normalised" % key)
		assert_ge(float(r.get("decay", -1.0)), 0.0, "'%s' decay is not negative" % key)
		assert_true(float(r.get("wave", -1)) >= 0.0
			and float(r.get("wave", 99)) <= float(Sfx.Wave.NOISE),
			"'%s' uses a known waveform" % key)


func test_every_recipe_actually_synthesises() -> void:
	for key in Sfx.RECIPES:
		var r: Dictionary = Sfx.RECIPES[key]
		var pcm := Sfx.synth_pcm(float(r["freq"]), float(r["dur"]), int(r["wave"]),
			float(r["vol"]), float(r["decay"]), Sfx.SAMPLE_RATE)
		assert_gt(float(pcm.size()), 0.0, "'%s' produces audio" % key)
		assert_gt(_peak_all(pcm), 0.0, "'%s' is not silent" % key)


func test_recipe_lookup() -> void:
	assert_true(Sfx.has_recipe("shot"), "a documented sound exists")
	assert_true(Sfx.has_recipe("click"), "menu sounds exist")
	assert_false(Sfx.has_recipe("not_a_sound"), "unknown sounds report false")


func test_noise_is_deterministic() -> void:
	# Determinism is the point: no RNG, so synthesis is reproducible and the
	# two calls must be byte-identical.
	var a := Sfx.synth_pcm(0.0, 0.02, Sfx.Wave.NOISE, 0.5, 0.0, RATE)
	var b := Sfx.synth_pcm(0.0, 0.02, Sfx.Wave.NOISE, 0.5, 0.0, RATE)
	assert_eq(a, b, "same parameters, identical bytes")


func test_noise_stays_in_range() -> void:
	for i in range(64):
		assert_ge(Sfx._noise(i), -1.0, "noise floor")
		assert_le(Sfx._noise(i), 1.0, "noise ceiling")


func test_play_without_voices_is_safe() -> void:
	# Headless has no audio driver, so _ready() builds no voices; play() must
	# no-op rather than crash. This is how the suite itself runs.
	var s := Sfx.new()
	s.play("shot")
	s.play("not_a_sound")
	s.play("shot", 0.0)      # out-of-range pitch
	s.play("shot", 1.0, 0.0)  # out-of-range volume
	assert_true(s._voices.is_empty(), "no voices were built headless")
	s.free()


func test_mute_roundtrip() -> void:
	var s := Sfx.new()
	assert_false(s.is_muted(), "unmuted by default")
	s.set_muted(true)
	assert_true(s.is_muted(), "mute sticks")
	s.play("shot")  # must not crash while muted
	s.set_muted(false)
	assert_false(s.is_muted(), "unmute sticks")
	s.free()


## Peak absolute sample in a byte range (little-endian 16-bit mono).
func _peak(pcm: PackedByteArray, from: int, to: int) -> float:
	var best := 0.0
	var start := maxi(0, from)
	var end := mini(pcm.size(), to)
	for i in range(start, end - 1, 2):
		best = maxf(best, absf(_sample(pcm, i)))
	return best


func _peak_all(pcm: PackedByteArray) -> float:
	return _peak(pcm, 0, pcm.size())


func _sample(pcm: PackedByteArray, i: int) -> float:
	var v := pcm[i] | (pcm[i + 1] << 8)
	if v >= 32768:
		v -= 65536
	return float(v)
