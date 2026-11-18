class_name AutoQuality
extends Node
## Runs once, on the very first launch (no settings file yet): watches the frame rate for
## 10 seconds of play and then picks graphics settings that the computer can keep up with.
## The player can change them later under Settings; this never runs again after that.

const WARMUP := 3.0 ## seconds to ignore while the world loads and shaders compile
const MEASURE := 10.0

var _time := 0.0
var _frames := 0
var _measured := 0.0


## Water quality and render scale for an average frame rate. Assumes the 60 FPS cap.
static func decide(avg_fps: float) -> Dictionary:
	if avg_fps >= 55.0:
		return {"water_quality": 2, "render_scale": 1.0, "name": "High"}
	if avg_fps >= 40.0:
		return {"water_quality": 1, "render_scale": 0.75, "name": "Medium"}
	return {"water_quality": 0, "render_scale": 0.5, "name": "Low"}


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_time += delta
	if _time < WARMUP:
		return
	_frames += 1
	_measured += delta
	if _measured < MEASURE:
		return
	var choice := decide(_frames / _measured)
	Settings.water_quality = choice["water_quality"]
	Settings.render_scale = choice["render_scale"]
	Settings.auto_quality_done = true
	Settings.needs_auto_quality = false
	Settings.apply()
	Settings.save_settings()
	Game.notify("Graphics set to %s for this computer (change it in Settings)" % choice["name"])
	queue_free()
