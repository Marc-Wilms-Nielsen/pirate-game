extends Node
## Skærmbilleder af det åbne hav: gennemsigtigt dybt vand, havbund med vrag, V-kølvand og kanonrøg.
## Kør: godot res://tests/sea_check.tscn

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.delete_save()
	Game.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in 30:
		await get_tree().process_frame
	var sky := main.get_node("Sky") as WorldSky
	sky.set_weather("clear")
	sky.snap_weather()
	Game.world_time = 0.45
	Game.user_zoom = 0.7
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var seabed := main.get_node("Seabed")
	# Find et vrag ude på dybt vand og sejl hen over det
	var wreck: Node2D = null
	for t in seabed.get_children():
		if t.get("kind") == "wreck":
			wreck = t
			break
	print("seabed things: ", seabed.get_child_count() - 1, " wreck at ", wreck.global_position if wreck else Vector2.ZERO)
	ship.place_at(wreck.position - Vector2(260, 0), 0.0)
	ship.sail_level = 2
	for i in 200:
		await get_tree().physics_frame
	await _shot("s1_wake_over_wreck")
	Game.cannonballs = 50
	Game.active_ship()["cannons"] = 4
	ship.refresh_from_config()
	ship.fire("left")
	for i in 40:
		await get_tree().physics_frame
	await _shot("s2_cannon_smoke")
	ship.sail_level = 1
	for i in 120:
		await get_tree().physics_frame
	await _shot("s3_slow")
	Game.world_time = 0.0
	for i in 30:
		await get_tree().process_frame
	await _shot("s4_night")
	Game.world_time = 0.4
	var village := get_tree().get_first_node_in_group("villages") as FishingVillage
	ship.place_at(village.global_position + Vector2.from_angle(village.rotation) * (village.pier_length + 140.0), village.rotation + PI * 0.5)
	ship.sail_level = 0
	Game.user_zoom = 0.45
	for i in 60:
		await get_tree().process_frame
	await _shot("s5_village")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://test_shots/%s.png" % shot_name)
