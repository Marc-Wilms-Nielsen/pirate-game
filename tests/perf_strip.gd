extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in 30:
		await get_tree().process_frame
	main.set("max_enemies", 0)
	main.set("max_sharks", 0)
	main.set("max_barrels", 0)
	main.set_process(false)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	ship.place_at(Vector2(1500, 1500), 0.3)
	ship.sail_level = 2
	await _measure("baseline")
	for c in get_tree().get_nodes_in_group("creatures"):
		c.set_process(false)
	await _measure("creatures no process")
	for c in get_tree().get_nodes_in_group("creatures"):
		c.set_process(true)
	for c in get_tree().get_nodes_in_group("sharks"):
		c.queue_free()
	await _measure("- sharks")
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Snake:
			c.queue_free()
	await _measure("- snakes")
	_free_group("floating_loot"); await _measure("- floating loot")
	_free_group("creatures"); await _measure("- creatures")
	_free_group("chests"); await _measure("- chests")
	for isl in get_tree().get_nodes_in_group("islands"):
		for ch in isl.get_children():
			if ch is CollisionPolygon2D:
				ch.queue_free()
	await _measure("- island collision")
	for h in get_tree().get_nodes_in_group("harbors"):
		for ch in h.get_children():
			if ch is Area2D:
				ch.queue_free()
	await _measure("- harbor areas")
	for isl in get_tree().get_nodes_in_group("islands"):
		isl.queue_free()
	await _measure("- islands entirely")
	var sh := Shark.new()
	sh.global_position = Vector2(1600, 1500)
	Game.world_root.add_child(sh)
	await _measure("+ 1 shark (no islands)")
	print("shark groups: ", sh.get_groups(), " children: ", sh.get_child_count())
	get_tree().quit()


func _free_group(g: String) -> void:
	for n in get_tree().get_nodes_in_group(g):
		n.queue_free()


func _measure(label: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var phys := 0.0
	var proc := 0.0
	var t0 := Time.get_ticks_usec()
	var ticks0 := Engine.get_physics_frames()
	for i in 120:
		await get_tree().process_frame
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / 120.0
	print("STRIP %-22s wall %.2f ms/frame  physics-ticks/frame %.2f  physics %.2f ms  process %.2f ms" % [label, wall, (Engine.get_physics_frames() - ticks0) / 120.0, phys / 120, proc / 120])
