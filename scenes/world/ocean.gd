extends ColorRect
## Sender øernes form og position til hav-shaderen hvert frame,
## så shaderen kan tegne lavt, klart vand omkring dem.

const MAX_ISLANDS := 32


func _ready() -> void:
	add_to_group("ocean")
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("quality", Settings.water_quality)
		mat.set_shader_parameter("wave_tex", WaterNoise.wave_texture())
		mat.set_shader_parameter("detail_tex", WaterNoise.detail_texture())


var _last_center := Vector2.INF
var _last_extent := 0.0
var _refresh := 0.0


func _process(delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	# Kun øerne tæt på kameraet sendes til shaderen – færre øer pr. pixel = hurtigere hav,
	# og verdenen kan have mange flere øer end shaderen kan rumme.
	# Use the main window's camera: with a reduced water resolution this node lives inside an
	# off-screen SubViewport (see water_layers.gd), which has no camera of its own.
	var root := get_tree().root
	var cam := root.get_camera_2d()
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	var extent := (root.get_visible_rect().size / (cam.zoom if cam else Vector2.ONE)).length() * 0.5 + 200.0
	_refresh -= delta
	if _refresh > 0.0 and center.distance_to(_last_center) < 120.0 and absf(extent - _last_extent) < 100.0:
		return
	_refresh = 0.5
	_last_center = center
	_last_extent = extent
	var near: Array = []
	for island in get_tree().get_nodes_in_group("islands"):
		var isl := island as Island
		var reach := isl.radius * 1.47 * isl.lagoon_size
		var d := isl.global_position.distance_to(center) - reach
		if d < extent + 300.0:
			near.append([d, isl])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var data_a := PackedVector4Array()
	var data_b := PackedVector4Array()
	for entry in near:
		if data_a.size() >= MAX_ISLANDS:
			break
		var data: Array = (entry[1] as Island).get_shape_data()
		data_a.append(data[0])
		data_b.append(data[1])
	var count := data_a.size()
	while data_a.size() < MAX_ISLANDS:
		data_a.append(Vector4.ZERO)
		data_b.append(Vector4.ZERO)
	mat.set_shader_parameter("island_a", data_a)
	mat.set_shader_parameter("island_b", data_b)
	mat.set_shader_parameter("island_count", count)
