extends Node
## Måler billedhastighed og finder flaskehalse: slår ting fra én ad gangen og måler forskellen.
## Kør: godot res://tests/perf_check.tscn

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Game.delete_save()
	Game.reset()
	var t0 := Time.get_ticks_msec()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	print("world build ms: ", Time.get_ticks_msec() - t0)
	for i in 30:
		await get_tree().process_frame
	_census()
	var fcount := {}
	for h in get_tree().get_nodes_in_group("harbors"):
		var f := Game.faction_of((h as Harbor).harbor_name) if (h as Harbor).kind != "home" else "home"
		fcount[f] = int(fcount.get(f, 0)) + 1
	print("islands %d  harbors %s  villages %d  camps %d  castles %d  awake %d" % [get_tree().get_nodes_in_group("islands").size(), str(fcount),
		get_tree().get_nodes_in_group("villages").size(), get_tree().get_nodes_in_group("camps").size(), get_tree().get_nodes_in_group("castles").size(),
		(main.get_node("Streamer") as WorldStreamer).awake_count()])
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	ship.set("sail_level", 2)
	await _measure("baseline (water high)")
	Settings.water_quality = 1
	Settings.apply()
	await _measure("water medium")
	Settings.water_quality = 0
	Settings.apply()
	await _measure("water low")
	Settings.water_quality = 2
	Settings.apply()
	await _toggle_measure("ocean hidden", main.get_node("Ocean"))
	await _toggle_measure("seabed hidden", main.get_node("Seabed"))
	Game.world_time = 0.0
	await _measure("night")
	var lights := get_tree().get_nodes_in_group("lanterns")
	for n in lights: (n as Light2D).enabled = false
	await _measure("night, lights off (%d)" % lights.size())
	for n in lights: (n as Light2D).enabled = true
	get_tree().quit()


func _toggle_measure(label: String, n: CanvasItem) -> void:
	n.visible = false
	await _measure(label)
	n.visible = true


func _measure(label: String) -> void:
	for i in 5:
		await get_tree().process_frame
	var t := Time.get_ticks_usec()
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var frames := 30
	for i in frames:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / frames
	print("%-28s frame %.1f ms  process %.2f ms  physics %.2f ms  draws %d" % [label, ms, proc * 1000.0 / frames, phys * 1000.0 / frames, int(draws / frames)])


func _census() -> void:
	var counts := {}
	var processing := 0
	var stack: Array[Node] = [get_tree().root]
	var total := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		total += 1
		if n.is_processing() or n.is_physics_processing():
			processing += 1
		var key := n.get_class()
		var s := n.get_script() as Script
		if s:
			key = s.resource_path.get_file()
		counts[key] = int(counts.get(key, 0)) + 1
		for c in n.get_children():
			stack.append(c)
	print("nodes: ", total, "  processing: ", processing)
	var keys := counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	for k in keys.slice(0, 25):
		print("   ", k, ": ", counts[k])
