extends ColorRect
## Sender øernes form og position til hav-shaderen hvert frame,
## så shaderen kan tegne lavt, klart vand omkring dem.

const MAX_ISLANDS := 16


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	var data_a := PackedVector4Array()
	var data_b := PackedVector4Array()
	for island in get_tree().get_nodes_in_group("islands"):
		if data_a.size() >= MAX_ISLANDS:
			break
		if island.has_method("get_shape_data"):
			var data: Array = island.call("get_shape_data")
			data_a.append(data[0])
			data_b.append(data[1])
	var count := data_a.size()
	while data_a.size() < MAX_ISLANDS:
		data_a.append(Vector4.ZERO)
		data_b.append(Vector4.ZERO)
	mat.set_shader_parameter("island_a", data_a)
	mat.set_shader_parameter("island_b", data_b)
	mat.set_shader_parameter("island_count", count)
