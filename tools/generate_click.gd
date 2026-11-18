extends SceneTree
## Makes the button sound: a deep, soft wooden "tock", like a marimba bar.
## A low fundamental (G3) with two quiet overtones that die out faster, a 4 ms soft attack,
## and a tiny burst of filtered noise for the wood. Writes assets/audio/sfx/ui_click_soft.wav.
## Run: godot --headless --script res://tools/generate_click.gd

const RATE := 44100
const LENGTH := 0.32
const OUT := "res://assets/audio/sfx/ui_click_soft.wav"


func _initialize() -> void:
	var n := int(RATE * LENGTH)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noise_lp := 0.0
	var peak := 0.0
	for i in n:
		var t := float(i) / RATE
		var attack := minf(t / 0.004, 1.0)
		var v := 0.0
		v += sin(TAU * 196.0 * t) * exp(-t / 0.11) # fundamental, the warm body of the sound
		v += 0.30 * sin(TAU * 392.0 * t + 0.3) * exp(-t / 0.05)
		v += 0.10 * sin(TAU * 784.0 * t + 1.1) * exp(-t / 0.025)
		v += 0.35 * sin(TAU * 98.0 * t) * exp(-t / 0.04) # a soft thump below
		noise_lp += (rng.randf_range(-1.0, 1.0) - noise_lp) * 0.15 # low-passed noise: wood, not hiss
		v += noise_lp * 0.5 * exp(-t / 0.006)
		v *= attack
		samples[i] = v
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := int(clampf(samples[i] / peak * 0.6, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT))
	print("wrote %s (%d samples): %s" % [OUT, n, error_string(err)])
	quit()
