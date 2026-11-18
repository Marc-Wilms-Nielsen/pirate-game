extends Node
## Changing a setting (here: the music volume) must not touch the window: a maximized window
## used to shrink, because every settings change set the window mode to "windowed" again.
## Also checks that switching fullscreen on and off still works.
## Run: godot res://tests/settings_check.tscn   (exits with code 1 on any failure)

var _failures := 0


func _ready() -> void:
	Game.use_test_files() # never touch the real save or settings
	await _frames(10)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await _frames(30)
	var mode := DisplayServer.window_get_mode()
	var size := DisplayServer.window_get_size()
	print("     maximized: mode %d, size %s" % [mode, size])
	for v in [0.4, 0.3, 0.2, 0.1]:
		Settings.set_value("music_volume", v) # like dragging the music slider down
		await _frames(5)
	await _frames(20)
	print("     after the music slider: mode %d, size %s" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()])
	_check(DisplayServer.window_get_mode() == mode, "lowering the music keeps the window maximized")
	_check(DisplayServer.window_get_size() == size, "lowering the music keeps the window size")
	Settings.set_value("fullscreen", true)
	await _frames(30)
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Display: Fullscreen still works")
	Settings.set_value("fullscreen", false)
	await _frames(30)
	_check(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN, "Display: Windowed still works")
	print("SETTINGS CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["OK  " if ok else "FAIL", text])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
