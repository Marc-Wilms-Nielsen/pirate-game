extends Node
func _ready() -> void:
	var proc := 0.0
	var phys := 0.0
	for i in 300:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("EMPTY process %.2f ms physics %.2f ms fps %d" % [proc / 300, phys / 300, Engine.get_frames_per_second()])
	get_tree().quit()
