class_name WorldSky
extends Node
## Døgn og vejr. Styrer lyset (CanvasModulate), lanterner om natten, regn, tåge, storm og lyn.
## Tiden på døgnet ligger i Game.world_time (0 = midnat, 0.5 = middag) og gemmes med spillet.
## Andre systemer kan læse Game.night (0..1), Game.weather og Game.wind.

const DAY_LENGTH := 720.0 ## sekunder for et helt døgn (12 minutter)
const WEATHER_BLEND := 25.0 ## sekunder om at skifte vejr
const WEATHERS := {
	"clear": {"name": "Clear", "weight": 45.0, "rain": 0.0, "fog": 0.0, "storm": 0.0, "dark": 1.0},
	"rain": {"name": "Rain", "weight": 22.0, "rain": 0.55, "fog": 0.1, "storm": 0.2, "dark": 0.85},
	"fog": {"name": "Fog", "weight": 18.0, "rain": 0.0, "fog": 0.8, "storm": 0.0, "dark": 0.92},
	"storm": {"name": "Storm", "weight": 15.0, "rain": 1.0, "fog": 0.06, "storm": 1.0, "dark": 0.62},
}
const NIGHT_COLOR := Color(0.30, 0.36, 0.62)
const DUSK_COLOR := Color(1.0, 0.78, 0.62)
const THUNDER := "res://assets/audio/sfx/thunder.wav"
const RAIN_LOOP := "res://assets/audio/ambience/rain_loop.wav"

var _modulate: CanvasModulate
var _overlay: WeatherOverlay
var _weather_time: float = 0.0
var _current: Dictionary = {"rain": 0.0, "fog": 0.0, "storm": 0.0, "dark": 1.0}
var _lightning_timer: float = 8.0
var _rain_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _thunder_delay: float = -1.0
var _wind_angle: float = 0.0
static var _shared_texture: Texture2D = null
var _ocean: ShaderMaterial


func _ready() -> void:
	add_to_group("sky")
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_overlay = WeatherOverlay.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	_rain_player = _loop_player(RAIN_LOOP, "Ambience")
	_thunder_player = _loop_player(THUNDER, "SFX")
	_wind_angle = randf() * TAU
	Game.weather = "clear"
	_weather_time = randf_range(120.0, 240.0)
	_update_light(0.0)


func _loop_player(path: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	Game.world_time = fmod(Game.world_time + delta / DAY_LENGTH, 1.0)
	_update_weather(delta)
	_update_light(delta)


## Dagslys 0..1 ud fra tiden på døgnet (solen står højest ved 0.5).
static func daylight(t: float) -> float:
	var sun := -cos(t * TAU)
	return smoothstep(-0.3, 0.25, sun)


## Tidspunkt som tekst, f.eks. "14:30".
static func clock_text(t: float) -> String:
	var minutes := int(t * 24.0 * 60.0)
	return "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]


## 0..1: how deep in a pirate city's gloom the player is (see BigCity.gloom).
func city_gloom() -> float:
	var player := get_tree().get_first_node_in_group("player_character") as Node2D
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	var focus := player.global_position if player else (ship.global_position if ship else Vector2.ZERO)
	var g := 0.0
	for c in get_tree().get_nodes_in_group("big_cities"):
		if (c as Node2D).is_visible_in_tree():
			g = maxf(g, (c as BigCity).gloom(focus))
	return g


func _update_light(delta: float) -> void:
	var day := daylight(Game.world_time)
	Game.night = 1.0 - day
	var sun := -cos(Game.world_time * TAU)
	var dusk := clampf(1.0 - absf(sun) / 0.35, 0.0, 1.0) * 0.8 # orange skær ved solop- og nedgang
	var col := NIGHT_COLOR.lerp(Color.WHITE, day)
	col = col.lerp(col * DUSK_COLOR, dusk)
	var dark: float = _current["dark"]
	col = Color(col.r * dark, col.g * dark, col.b * lerpf(dark, 1.0, 0.3))
	# The pirate city lies in gloom, day and night: a cold, dim light and drifting fog
	var gloom := city_gloom()
	col = col.lerp(Color(col.r * 0.42, col.g * 0.4, col.b * 0.55), gloom)
	# Lyn
	if _overlay.flash > 0.0:
		col = col.lerp(Color(1.6, 1.6, 1.8), _overlay.flash * 0.6)
	_modulate.color = col
	_overlay.rain = _current["rain"]
	_overlay.fog = maxf(float(_current["fog"]), gloom * 0.45)
	_overlay.night = maxf(Game.night, gloom * 0.7)
	# Lanterner tændes i skumringen (and always in the gloom of the pirate city)
	var glow := maxf(smoothstep(0.25, 0.7, Game.night + (1.0 - dark) * 0.6), gloom)
	# Only lights on (or just off) the screen are switched on: each enabled light makes the
	# renderer draw everything it touches once more, and the world has 200+ lanterns.
	var vp := get_viewport()
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	view = view.grow(250.0)
	for l in get_tree().get_nodes_in_group("lanterns"):
		var light := l as PointLight2D
		light.enabled = glow > 0.02 and view.has_point(light.global_position)
		if not light.enabled:
			continue
		light.energy = glow * 0.32 * float(light.get_meta("max_energy", 1.0)) * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.008 + light.get_instance_id()))
	# Havet: selvlysende plankton om natten og større bølger i stormvejr
	if _ocean == null:
		var ocean := get_tree().get_first_node_in_group("ocean") as CanvasItem
		if ocean:
			_ocean = ocean.material as ShaderMaterial
	if _ocean:
		_ocean.set_shader_parameter("night", Game.night)
		_ocean.set_shader_parameter("storm", _current["storm"])
		_ocean.set_shader_parameter("light_comp", Vector3(1.0 / maxf(col.r, 0.2), 1.0 / maxf(col.g, 0.2), 1.0 / maxf(col.b, 0.2)))
	# Vind: kun mærkbar i stormvejr
	_wind_angle += delta * 0.02
	Game.wind = Vector2.from_angle(_wind_angle) * 22.0 * float(_current["storm"])


func _update_weather(delta: float) -> void:
	_weather_time -= delta
	if _weather_time <= 0.0:
		set_weather(_pick_weather())
	var target: Dictionary = WEATHERS[Game.weather]
	var k := 1.0 - exp(-delta * 3.0 / WEATHER_BLEND)
	for key in ["rain", "fog", "storm", "dark"]:
		_current[key] = lerpf(_current[key], target[key], k)
	# Lyd
	var rain: float = _current["rain"]
	_rain_player.volume_db = linear_to_db(maxf(rain * 0.7, 0.0001))
	if rain > 0.05 and not _rain_player.playing:
		_rain_player.play()
	elif rain <= 0.03 and _rain_player.playing:
		_rain_player.stop()
	# Lyn i stormvejr
	if _current["storm"] > 0.6:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_timer = randf_range(6.0, 16.0)
			_overlay.flash = 1.0
			_thunder_delay = randf_range(0.4, 1.6)
	if _thunder_delay >= 0.0:
		_thunder_delay -= delta
		if _thunder_delay < 0.0:
			_thunder_player.volume_db = randf_range(-8.0, -2.0)
			_thunder_player.pitch_scale = randf_range(0.85, 1.1)
			_thunder_player.play()


func _pick_weather() -> String:
	var total := 0.0
	for id in WEATHERS:
		total += float(WEATHERS[id]["weight"])
	var roll := randf() * total
	for id in WEATHERS:
		roll -= float(WEATHERS[id]["weight"])
		if roll <= 0.0:
			return id
	return "clear"


func set_weather(id: String) -> void:
	if not WEATHERS.has(id):
		return
	if id != Game.weather:
		Game.notify("The weather changes: %s" % WEATHERS[id]["name"].to_lower(), UiTheme.MUTED)
	Game.weather = id
	_weather_time = randf_range(150.0, 330.0) if id == "clear" else randf_range(90.0, 210.0)


## Sætter vejret med det samme (bruges af test og når spillet starter).
func snap_weather() -> void:
	var target: Dictionary = WEATHERS[Game.weather]
	for key in ["rain", "fog", "storm", "dark"]:
		_current[key] = target[key]
	_update_light(0.0)


## Lille lys (lanterne, fakkel, bål) der tændes om natten.
static func add_lantern(parent: Node2D, offset: Vector2, scale_px: float, color := Color(1.0, 0.72, 0.38), energy := 0.9, stretch := Vector2.ONE) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = offset
	light.scale = stretch
	light.color = color
	light.texture = _lantern_texture()
	light.texture_scale = scale_px / 64.0
	light.energy = 0.0
	light.enabled = false
	light.set_meta("max_energy", energy)
	light.add_to_group("lanterns")
	parent.add_child(light)
	return light


## Flere små, aflange lys langs et skib (agter, midtskibs og forude) i stedet for ét stort.
static func add_ship_lights(visual: Node2D, ship_length: float, color: Color, energy: float) -> void:
	var spots := [-0.42, -0.12, 0.2]
	for i in spots.size():
		var x: float = spots[i] * ship_length
		var size := 22.0 + ship_length * 0.12
		add_lantern(visual, Vector2(x, 0), size, color, energy * (1.0 if i == 0 else 0.7), Vector2(1.7, 1.0))


static func _lantern_texture() -> Texture2D:
	if _shared_texture:
		return _shared_texture
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	# Blød, næsten kvadratisk aftagning – ingen skarp kerne eller kant
	for i in range(1, 8):
		var t := i / 8.0
		grad.add_point(t, Color(1, 1, 1, pow(1.0 - t, 2.2)))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_shared_texture = tex
	return tex


## Regn, tåge og lynglimt tegnet oven på verden (i skærmkoordinater).
class WeatherOverlay extends Control:
	var rain: float = 0.0
	var fog: float = 0.0
	var night: float = 0.0
	var flash: float = 0.0
	var _drops: Array[Vector3] = [] ## x, y, fart
	var _time: float = 0.0
	var _fog_rect: ColorRect

	func _ready() -> void:
		for i in 320:
			_drops.append(Vector3(randf() * 700.0, randf() * 400.0, randf_range(0.8, 1.3)))
		_fog_rect = ColorRect.new()
		_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scenes/world/fog.gdshader") as Shader
		mat.set_shader_parameter("detail_tex", WaterNoise.detail_texture())
		_fog_rect.material = mat
		add_child(_fog_rect)

	func _process(delta: float) -> void:
		_time += delta
		flash = maxf(flash - delta * 2.5, 0.0)
		var paused := get_tree().paused
		if not paused:
			var wind_x := 60.0 + 60.0 * rain
			for i in _drops.size():
				var d := _drops[i]
				d.y += 420.0 * d.z * delta
				d.x -= wind_x * delta
				if d.y > 380.0 or d.x < -20.0:
					d = Vector3(randf() * 720.0, -10.0, d.z)
				_drops[i] = d
		var mat := _fog_rect.material as ShaderMaterial
		_fog_rect.visible = fog > 0.02
		if _fog_rect.visible:
			mat.set_shader_parameter("amount", fog)
			mat.set_shader_parameter("night", night)
		queue_redraw()

	func _draw() -> void:
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.35))
		if rain <= 0.02:
			return
		var count := int(_drops.size() * rain * (1.0 if Settings.effects else 0.4))
		var col := Color(0.8, 0.88, 1.0, 0.35 + 0.15 * rain).lerp(Color(0.6, 0.7, 0.9, 0.3), night)
		var slant := Vector2(-0.25 - 0.2 * rain, 1.0) * (7.0 + 5.0 * rain)
		for i in count:
			var d := _drops[i]
			draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y) + slant * d.z, col, 1.0)
		# Små ringe hvor dråberne rammer
		for i in mini(floori(count / 6.0), 40):
			var d := _drops[i * 6]
			var age := fmod(_time * 2.0 + d.z * 7.0, 1.0)
			draw_arc(Vector2(fmod(d.x * 1.7, size.x), fmod(d.y * 1.3 + 50.0, size.y)), 1.0 + age * 3.0, 0.0, TAU, 10, Color(1, 1, 1, 0.2 * (1.0 - age) * rain), 0.6)
