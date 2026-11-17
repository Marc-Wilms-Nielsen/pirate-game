@tool
extends StaticBody2D
## Procedurelt genereret ø med en stor, rolig lagune, skum, strand, græs og palmer.
## Justér radius, seed og antal palmer i Inspector – øen opdateres direkte i editoren.

const GullScript := preload("res://scenes/world/gull.gd")
const GULL_SOUNDS: Array[String] = [
	"res://assets/audio/sfx/gull_1.wav",
	"res://assets/audio/sfx/gull_2.wav",
	"res://assets/audio/sfx/gull_3.wav",
]
const POINTS := 64

@export var radius: float = 120.0:
	set(value):
		radius = value
		_regenerate()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		_regenerate()
@export_range(0, 12) var palm_count: int = 4:
	set(value):
		palm_count = value
		_regenerate()
@export_range(0, 4) var gull_count: int = 2
## Hvor langt det lyse lavvande går ud fra stranden
@export_range(1.2, 3.0) var lagoon_size: float = 2.2:
	set(value):
		lagoon_size = value
		_regenerate()

var _foam: Line2D
var _land_shape := PackedVector2Array()
var _time: float = 0.0
var _gull_timer: float = 3.0
var _gull_player: AudioStreamPlayer2D
var _gull_streams: Array[AudioStream] = []


func _ready() -> void:
	_generate()
	if not Engine.is_editor_hint():
		add_to_group("islands")
		_spawn_gulls()
		_setup_audio()


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_foam):
		var wave := sin(_time * 1.1)
		_foam.scale = Vector2.ONE * (1.0 + 0.025 * wave)
		_foam.modulate.a = 0.55 + 0.35 * wave

	if Engine.is_editor_hint() or _gull_streams.is_empty():
		return
	_gull_timer -= delta
	if _gull_timer <= 0.0:
		_gull_player.stream = _gull_streams.pick_random()
		_gull_player.pitch_scale = randf_range(0.9, 1.12)
		_gull_player.play()
		_gull_timer = randf_range(3.0, 9.0)


func _regenerate() -> void:
	if is_inside_tree():
		_generate()


func _generate() -> void:
	for child in get_children():
		if child.has_meta("generated"):
			remove_child(child)
			child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shape := _make_shape(rng)

	_land_shape = shape

	# Lagunen: mange halvgennemsigtige lag giver en blød overgang
	# fra dybt hav til lyst, stille vand ved stranden.
	var layers := 8
	for i in layers:
		var k := float(i) / (layers - 1)
		var size := lerpf(lagoon_size, 1.06, k)
		var color := Color(0.30, 0.72, 0.80).lerp(Color(0.66, 0.93, 0.88), k)
		color.a = lerpf(0.10, 0.38, k)
		_add_polygon(_scaled(shape, size), color)

	_foam = Line2D.new()
	_foam.points = _scaled(shape, 1.08)
	_foam.closed = true
	_foam.width = 3.0
	_foam.default_color = Color(1, 1, 1, 0.5)
	_foam.antialiased = true
	_foam.joint_mode = Line2D.LINE_JOINT_ROUND
	_tag(_foam)

	_add_polygon(_scaled(shape, 1.04), Color(0.78, 0.70, 0.50)) # våd sand
	_add_polygon(shape, Color(0.94, 0.85, 0.62)) # sand
	_add_polygon(_scaled(shape, 0.62), Color(0.45, 0.68, 0.35)) # græs
	_add_polygon(_scaled(shape, 0.40), Color(0.38, 0.60, 0.30)) # tæt græs

	for i in palm_count:
		var a := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius * 0.45
		_add_palm(Vector2(cos(a), sin(a)) * dist, rng)

	var collision := CollisionPolygon2D.new()
	collision.polygon = _scaled(shape, 0.96)
	_tag(collision)


func _make_shape(rng: RandomNumberGenerator) -> PackedVector2Array:
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in POINTS:
		var a := TAU * i / POINTS
		var r := radius * (1.0 + 0.16 * sin(2.0 * a + p1) + 0.10 * sin(3.0 * a + p2) + 0.05 * sin(5.0 * a + p3))
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _add_palm(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var rot := rng.randf() * TAU
	_add_polygon(_star(6, 13.0, 3.0, rot), Color(0, 0, 0, 0.22), pos + Vector2(5, 7)) # skygge
	_add_polygon(_star(6, 13.0, 3.0, rot), Color(0.20, 0.50, 0.25), pos)
	_add_polygon(_star(6, 9.0, 2.5, rot + 0.3), Color(0.32, 0.64, 0.32), pos)
	_add_polygon(_star(8, 2.5, 2.5, 0.0), Color(0.45, 0.30, 0.15), pos) # kokosnødder


func _star(leaves: int, outer: float, inner: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in leaves * 2:
		var r := outer if i % 2 == 0 else inner
		var a := rot + PI * i / leaves
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _add_polygon(points: PackedVector2Array, color: Color, pos: Vector2 = Vector2.ZERO) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.position = pos
	poly.antialiased = true
	_tag(poly)


func is_on_land(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(global_point), _land_shape)


func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * factor)
	return out


func _tag(node: Node) -> void:
	# Genererede noder markeres, så de kan fjernes igen og ikke gemmes i scenefilen.
	node.set_meta("generated", true)
	add_child(node)


func _spawn_gulls() -> void:
	for i in gull_count:
		var gull = GullScript.new() # utypet, så vi kan sætte gull.gd-egenskaber
		gull.orbit_radius = radius * randf_range(1.1, 1.8)
		gull.angular_speed = randf_range(0.25, 0.5) * (1.0 if randf() < 0.5 else -1.0)
		gull.angle = randf() * TAU
		add_child(gull)


func _setup_audio() -> void:
	for path in GULL_SOUNDS:
		var stream := load(path) as AudioStream
		if stream:
			_gull_streams.append(stream)
	_gull_player = AudioStreamPlayer2D.new()
	_gull_player.max_distance = 700.0
	_gull_player.attenuation = 1.5
	_gull_player.volume_db = -6.0
	add_child(_gull_player)
	_gull_timer = randf_range(1.0, 6.0)
