extends Node
## Hurtige skærmbilleder af slotte, store dyr og duel-arenaen (til visuelt tjek).
## Kør: godot res://tests/visual_check.tscn

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
	var castle := get_tree().get_nodes_in_group("castles")[1] as Castle
	ship.disembark_requested.emit()
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	player.global_position = castle.gate_position() + Vector2.from_angle(castle.rotation) * 10.0
	for i in 60:
		await get_tree().process_frame
	await _shot("v1_castle")
	# Store dyr samlet foran kaptajnen
	var kinds := ["jaguar", "boar", "croc", "golem"]
	var placed := 0
	for b in get_tree().get_nodes_in_group("creatures"):
		if b is Beast and (b as Beast).kind == kinds[placed] and (b as Beast).home == castle.island:
			(b as Beast).global_position = player.global_position + Vector2(-60 + placed * 40, 50)
			(b as Beast).set_process(false)
			(b as Beast).queue_redraw()
			placed += 1
			if placed >= kinds.size():
				break
	player.global_position += Vector2(0, -20)
	for i in 20:
		await get_tree().process_frame
	await _shot("v2_beasts")
	Game.world_time = 0.0
	sky.snap_weather()
	for i in 20:
		await get_tree().process_frame
	await _shot("v3_castle_night")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://test_shots/%s.png" % shot_name)
