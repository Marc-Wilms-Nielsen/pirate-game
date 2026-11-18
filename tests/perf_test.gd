extends Node
## Måler hvor meget CPU-tid spillet bruger pr. frame, mens skibet sejler.
## Kør: godot --headless res://tests/perf_test.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in 30:
		await get_tree().process_frame
	main.set("_elapsed", 100.0) # fjender må spawne
	var variant := OS.get_environment("PERF_VARIANT")
	if variant == "no_enemies":
		main.set("max_enemies", 0)
	elif variant == "no_creatures":
		for c in get_tree().get_nodes_in_group("creatures"):
			c.queue_free()
		main.set("max_sharks", 0)
	elif variant == "no_island_collision":
		for isl in get_tree().get_nodes_in_group("islands"):
			for ch in isl.get_children():
				if ch is CollisionPolygon2D:
					ch.queue_free()
	elif variant == "no_islands_process":
		for isl in get_tree().get_nodes_in_group("islands"):
			isl.set_process(false)
	print("variant: ", variant)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	ship.place_at(Vector2(1500, 1500), 0.3)
	ship.sail_level = 2
	var proc := 0.0
	var phys := 0.0
	var worst := 0.0
	var frames := 600
	for i in frames:
		await get_tree().process_frame
		ship.rotation += 0.002
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += p
		phys += ph
		worst = maxf(worst, p + ph)
	print("PERF process %.2f ms  physics %.2f ms  worst %.2f ms  nodes %d  enemies %d" % [
		proc / frames, phys / frames, worst, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().get_nodes_in_group("enemies").size()])
	get_tree().quit()
