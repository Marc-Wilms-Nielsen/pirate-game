extends SceneTree
## Makes the sound for entering a new area of the sea: a soft, low bell that rings out slowly.
## Two notes a fifth apart (C5 then G5), each a sine with two quiet overtones and a gentle attack.
## Writes assets/audio/sfx/zone_chime.wav.
## Run: godot --headless --script res://tools/generate_chime.gd

const RATE := 44100
const LENGTH := 2.2
const OUT := "res://assets/audio/sfx/zone_chime.wav"


func _initialize() -> void:
	var n := int(RATE * LENGTH)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var peak := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := _bell(t, 523.25) + _bell(t - 0.22, 783.99) * 0.7
		samples[i] = v
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.45, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT))
	print("wrote %s (%d samples): %s" % [OUT, n, error_string(err)])
	quit()


func _bell(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	var attack := minf(t / 0.012, 1.0)
	var v := sin(TAU * f * t) * exp(-t / 0.9)
	v += 0.25 * sin(TAU * f * 2.0 * t) * exp(-t / 0.45)
	v += 0.08 * sin(TAU * f * 3.01 * t) * exp(-t / 0.25)
	return v * attack
