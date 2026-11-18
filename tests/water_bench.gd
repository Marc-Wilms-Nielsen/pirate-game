extends Node2D
## Water shader benchmark: draws the full-screen water LAYERS times over and times it.
## A fast desktop GPU draws the water once in well under a millisecond, so frame times hide
## its cost; stacking it makes the GPU the bottleneck and the shader's cost measurable.
## Divide by LAYERS for the cost of one screen of water. Works on old and new versions:
## if the old separate seabed shader exists, each layer also draws it (as the game did).
## Run: godot --resolution 1920x1080 res://tests/water_bench.tscn
##
## Performance budget: the results are compared with tests/perf_budget.cfg (one section per
## graphics card, since every GPU has its own speed). If any setting got more than 10 % slower,
## it prints FAIL and exits with code 1. The first run on a new GPU saves its numbers.
## After an intended change in cost, save new numbers with:
##   godot --resolution 1920x1080 res://tests/water_bench.tscn -- --update-budget

const LAYERS := 40
const FRAMES := 120
const BUDGET_PATH := "res://tests/perf_budget.cfg"
const TOLERANCE := 1.10 ## fail when more than 10 % slower than the budget
const MIN_SLACK_MS := 0.01 ## per screen of water: ignore differences smaller than timer noise

var _ocean_mat: ShaderMaterial
var _seabed_mat: ShaderMaterial
var _results := {} ## "High day" -> ms per screen of water


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_ocean_mat = ShaderMaterial.new()
	_ocean_mat.shader = load("res://scenes/world/ocean.gdshader") as Shader
	if ResourceLoader.exists("res://scenes/world/water_noise.gd"):
		var noise: GDScript = load("res://scenes/world/water_noise.gd")
		_ocean_mat.set_shader_parameter("wave_tex", noise.call("wave_texture"))
		_ocean_mat.set_shader_parameter("detail_tex", noise.call("detail_texture"))
	if ResourceLoader.exists("res://scenes/world/seabed.gdshader"):
		_seabed_mat = ShaderMaterial.new()
		_seabed_mat.shader = load("res://scenes/world/seabed.gdshader") as Shader
	var size := get_viewport().get_visible_rect().size
	for i in LAYERS:
		if _seabed_mat:
			_add_rect(_seabed_mat, size)
		_add_rect(_ocean_mat, size)
	for i in 60: # let the noise textures finish baking and shaders compile
		await get_tree().process_frame
	print("water bench: %d layers at %s, seabed pass: %s" % [LAYERS, str(DisplayServer.window_get_size()), "yes" if _seabed_mat else "no (in water shader)"])
	for night in [0.0, 1.0]:
		for q in [0, 1, 2]:
			await _measure(q, night)
	get_tree().quit(_check_budget())


## Compares with the saved budget for this GPU. Returns the exit code (0 = ok, 1 = too slow).
func _check_budget() -> int:
	var gpu := RenderingServer.get_video_adapter_name()
	var cfg := ConfigFile.new()
	cfg.load(BUDGET_PATH)
	var update := OS.get_cmdline_user_args().has("--update-budget")
	if update or not cfg.has_section(gpu):
		for key in _results:
			cfg.set_value(gpu, key, snappedf(float(_results[key]), 0.001))
		cfg.save(BUDGET_PATH)
		print("budget saved for %s in %s" % [gpu, BUDGET_PATH])
		return 0
	var failed := false
	for key in _results:
		if not cfg.has_section_key(gpu, key):
			continue
		var budget: float = cfg.get_value(gpu, key)
		var now: float = _results[key]
		if now > maxf(budget * TOLERANCE, budget + MIN_SLACK_MS):
			print("FAIL %-14s %.3f ms, budget %.3f ms (+%d %%)" % [key, now, budget, roundi((now / budget - 1.0) * 100.0)])
			failed = true
	print("budget check (%s): %s" % [gpu, "FAIL – the water got slower" if failed else "ok"])
	return 1 if failed else 0


func _add_rect(mat: ShaderMaterial, size: Vector2) -> void:
	var r := ColorRect.new()
	r.size = size
	r.material = mat
	add_child(r)


func _measure(quality: int, night: float) -> void:
	_ocean_mat.set_shader_parameter("quality", quality)
	_ocean_mat.set_shader_parameter("night", night)
	if _seabed_mat:
		_seabed_mat.set_shader_parameter("quality", quality)
	for i in 10:
		await get_tree().process_frame
	var t := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / FRAMES
	_results["%s %s" % [["Low", "Medium", "High"][quality], "night" if night > 0.5 else "day"]] = ms / LAYERS
	print("%-6s %-6s  %6.2f ms/frame  =  %.3f ms per screen of water" % [["Low", "Medium", "High"][quality], "night" if night > 0.5 else "day", ms, ms / LAYERS])
