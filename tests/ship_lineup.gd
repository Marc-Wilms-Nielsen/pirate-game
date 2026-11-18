extends Node2D
## Viser alle skibstyper side om side (til at tjekke udseendet). Gemmer user://test_shots/ship_lineup.png

var visuals: Array[ShipVisual] = []


func _ready() -> void:
	var ocean: Node = load("res://scenes/world/ocean.tscn").instantiate()
	add_child(ocean)
	var types := Catalog.SHIPS.keys()
	for i in types.size():
		var holder := Node2D.new()
		holder.position = Vector2((i % 4) * 150.0 - 225.0, floorf(i / 4.0) * 80.0 - 120.0)
		add_child(holder)
		var v := ShipVisual.new()
		holder.add_child(v)
		var config := Game.new_ship_config(types[i])
		config["cannons"] = Catalog.SHIPS[types[i]]["max_cannons"]
		config["decorations"] = {"flag": true}
		config["flag_style"] = Catalog.FLAG_STYLES[i % Catalog.FLAG_STYLES.size()]["id"]
		config["flag"] = ["black", "red", "gold", "green"][i % 4]
		v.apply_config(config)
		visuals.append(v)
		var label := Label.new()
		label.text = Catalog.SHIPS[types[i]]["name"]
		label.add_theme_font_size_override("font_size", 9)
		label.position = Vector2(-30, 22)
		holder.add_child(label)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)
	for f in 15:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/ship_lineup.png")
	get_tree().quit()


func _process(delta: float) -> void:
	for v in visuals:
		v.update_motion(0.0, 1.0, 0.0, delta)
