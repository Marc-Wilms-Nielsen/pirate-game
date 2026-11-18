extends Node
## Grafik- og lydindstillinger (autoload "Settings"). Gemmes i user://settings.cfg.

signal changed

var config_path := "user://settings.cfg" ## tests switch to their own file (Game.use_test_files)
const BUSES := ["Ambience", "SFX", "Music"]
const FPS_OPTIONS := [30, 60, 120, 144, 0] ## 0 = ubegrænset

var master_volume: float = 0.8
var ambience_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.5
var fullscreen: bool = false
var vsync: bool = true
var max_fps: int = 60 ## 60 by default: less heat and fan noise on laptops
var water_quality: int = 2 ## 0 = low, 1 = medium, 2 = high
var render_scale: float = 1.0 ## the water is drawn at this fraction of the window resolution
var effects: bool = true ## kølvand og røg
var show_fps: bool = false
var auto_quality_done: bool = false ## set once AutoQuality has picked settings on first launch

const RENDER_SCALES := [0.5, 0.75, 1.0]

## True on the very first launch (no settings file yet): main.gd then runs AutoQuality.
var needs_auto_quality: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.install_default_font() # the game's book font for the HUD, map and everything else
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	load_settings()
	apply()
	_fit_window_to_screen.call_deferred()


## The game opens a 1280 x 720 window. On a small laptop screen (e.g. 1366 x 768) that window
## plus its title bar is taller than the space above the taskbar, so the bottom of the game
## (and of every menu) is hidden. Shrink it to fit, keeping 16:9; everything scales with it.
func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless" or fullscreen:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen) # excludes the taskbar
	var size := DisplayServer.window_get_size()
	var deco := DisplayServer.window_get_size_with_decorations() - size # title bar and borders
	var room := usable.size - deco
	if size.x <= room.x and size.y <= room.y:
		return
	var s := minf(float(room.x) / size.x, float(room.y) / size.y) * 0.97
	var new_size := Vector2i(floori(size.x * s), floori(size.y * s))
	DisplayServer.window_set_size(new_size)
	var outer := new_size + deco
	DisplayServer.window_set_position(usable.position + (usable.size - outer) / 2 + Vector2i(deco.x / 2, deco.y - deco.x / 2))


func apply() -> void:
	_set_volume("Master", master_volume)
	_set_volume("Ambience", ambience_volume)
	_set_volume("SFX", sfx_volume)
	_set_volume("Music", music_volume)
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	for ocean in get_tree().get_nodes_in_group("ocean"):
		var mat := (ocean as CanvasItem).material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("quality", water_quality)
	changed.emit()


func _set_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(index, value <= 0.001)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _keys():
		cfg.set_value("settings", key, get(key))
	cfg.save(config_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		needs_auto_quality = not auto_quality_done
		return
	for key in _keys():
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))


func reset_to_defaults() -> void:
	master_volume = 0.8
	ambience_volume = 0.8
	sfx_volume = 0.8
	music_volume = 0.5
	fullscreen = false
	vsync = true
	max_fps = 60
	water_quality = 2
	render_scale = 1.0
	effects = true
	show_fps = false
	apply()
	save_settings()


## Ændr én indstilling, anvend og gem.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()


func _keys() -> Array[String]:
	return ["master_volume", "ambience_volume", "sfx_volume", "music_volume", "fullscreen", "vsync", "max_fps", "water_quality", "render_scale", "effects", "show_fps", "auto_quality_done"]
