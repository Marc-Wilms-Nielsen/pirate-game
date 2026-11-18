extends Node
## Finder hvilke dele af spillet der bruger CPU-tid: sætter én del på pause ad gangen.

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Settings.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Game.delete_save()
	Game.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in 40:
		await get_tree().process_frame
	(get_tree().get_first_node_in_group("player_ship") as Node2D).set("sail_level", 2)
	var base := await _measure()
	print("baseline: %.2f ms" % base)
	for path in ["Sky", "Music", "HUD", "Ocean", "Seabed", "Ship", "World", "Streamer", "PauseMenu", "HarborMenu", "HomeMenu", "DuelMenu"]:
		var n := main.get_node_or_null(path)
		if n == null:
			continue
		n.process_mode = Node.PROCESS_MODE_DISABLED
		var t := await _measure()
		n.process_mode = Node.PROCESS_MODE_INHERIT
		print("  without %-12s %.2f ms  (saves %.2f)" % [path, t, base - t])
	get_tree().quit()


func _measure() -> float:
	for i in 10:
		await get_tree().process_frame
	var t := Time.get_ticks_usec()
	for i in 200:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / 200.0
