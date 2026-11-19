@tool
class_name Island
extends StaticBody2D
## Procedurelt genereret ø med strand, græs, palmer og evt. en havn.
## Lagunen (det lave, klare vand) tegnes af hav-shaderen ud fra get_shape_data().
## Justér radius, seed og antal palmer i Inspector – øen opdateres direkte i editoren.

const GullScript := preload("res://scenes/world/gull.gd")
const GULL_SOUNDS: Array[String] = [
	"res://assets/audio/sfx/gull_1.wav",
	"res://assets/audio/sfx/gull_2.wav",
	"res://assets/audio/sfx/gull_3.wav",
]
const MIN_POINTS := 64
const SHORE_FADE := 22.0 ## pixels hvor sandet toner ud i vandet

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
@export var island_name: String = ""
@export_group("Harbor")
@export var harbor_name: String = "" ## Tom = ingen havn
@export_enum("trade", "pirate", "home") var harbor_kind: String = "trade"
@export var harbor_angle: float = 0.0 ## Retning fra øens midte, hvor molen ligger
var harbor_city: String = "" ## "royal" or "pirate": a big city (BigCity) is built round this harbor
@export_group("")
## 0 = rund lille ø, 1 = fastland med bugter og halvøer
@export_range(0.0, 1.0) var coast_detail: float = 0.0:
	set(value):
		coast_detail = value
		_regenerate()
## Hvor langt det lyse lavvande går ud fra stranden
@export_range(1.2, 12.0) var lagoon_size: float = 6.3:
	set(value):
		lagoon_size = value
		_regenerate()

var _land_shape := PackedVector2Array()
var _phases := Vector3.ZERO
var _time: float = 0.0
var _gull_timer: float = 3.0
var _gull_player: AudioStreamPlayer2D
var _gull_streams: Array[AudioStream] = []
var harbor: Harbor


func _ready() -> void:
	add_to_group("islands")
	_generate()
	if not Engine.is_editor_hint():
		Game.register_island(self, radius * 1.5 * maxf(lagoon_size, 1.0))
	if not Engine.is_editor_hint():
		_spawn_gulls()
		_setup_audio()
		if harbor_name != "":
			_create_harbor()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Game.unregister_island(self)


func _process(delta: float) -> void:
	_time += delta

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

	# Stranden går blødt over i vandet: fast sand inderst og en ring, der toner ud.
	# (Tidligere lå en skumlinje i 3 % af radius – på de store øer var den langt ude i vandet.)
	var sand := Color(0.94, 0.85, 0.62)
	var inner := _offset(shape, -SHORE_FADE * 0.6)
	_add_polygon(inner, sand)
	_add_fade_ring(inner, _offset(shape, SHORE_FADE * 0.4), sand, Color(sand.r, sand.g, sand.b, 0.0))
	_add_polygon(_scaled(shape, 0.62), Color(0.45, 0.68, 0.35)) # græs
	_add_polygon(_scaled(shape, 0.40), Color(0.38, 0.60, 0.30)) # tæt græs
	if radius > 300.0 and harbor_kind != "home": # hjemøen holdes ryddet til byggeri
		_add_mainland_details(rng)

	for i in palm_count:
		var a := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius * 0.45
		if harbor_name != "" and absf(angle_difference(a, harbor_angle)) < 0.7 and dist > radius * 0.2:
			continue # ingen palmer midt i havnebyen
		_add_palm(Vector2(cos(a), sin(a)) * dist, rng)

	var collision := CollisionPolygon2D.new()
	collision.polygon = _scaled(shape, 0.96)
	_tag(collision)


func _make_shape(rng: RandomNumberGenerator) -> PackedVector2Array:
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	_phases = Vector3(p1, p2, p3)
	var pts := PackedVector2Array()
	var count := clampi(int(radius / 4.0), MIN_POINTS, 260)
	for i in count:
		var a := TAU * i / count
		pts.append(Vector2(cos(a), sin(a)) * shore_radius(a))
	return pts


## Skov, bakker og klipper på de store øer.
func _add_mainland_details(rng: RandomNumberGenerator) -> void:
	for i in int(radius / 45.0):
		var a := rng.randf() * TAU
		var center := Vector2.from_angle(a) * shore_radius(a) * sqrt(rng.randf()) * 0.5
		var size := rng.randf_range(25.0, 75.0)
		_add_polygon(_blob(rng, size), Color(0.26, 0.48, 0.25, 0.85), center)
		_add_polygon(_blob(rng, size * 0.6), Color(0.22, 0.42, 0.22, 0.8), center + Vector2(-size * 0.1, -size * 0.1))
	if radius > 1000.0:
		_add_mountains(rng)
	for i in int(radius / 120.0):
		var a := rng.randf() * TAU
		var center := Vector2.from_angle(a) * shore_radius(a) * rng.randf_range(0.65, 0.9)
		var size := rng.randf_range(6.0, 16.0)
		_add_polygon(_blob(rng, size), Color(0, 0, 0, 0.2), center + Vector2(3, 4))
		_add_polygon(_blob(rng, size), Color(0.55, 0.53, 0.50), center)
		_add_polygon(_blob(rng, size * 0.55), Color(0.66, 0.64, 0.60), center - Vector2(size * 0.15, size * 0.2))


## Bjergkæde midt på de kæmpe fastlande: brune skråninger, grå klipper og lyse toppe.
func _add_mountains(rng: RandomNumberGenerator) -> void:
	var dir := Vector2.from_angle(rng.randf() * TAU)
	for i in 9:
		var t := (i - 4) / 4.0
		var center := dir * radius * 0.32 * t + dir.orthogonal() * rng.randf_range(-60.0, 60.0)
		var size := rng.randf_range(70.0, 120.0) * (1.0 - absf(t) * 0.35)
		_add_polygon(_blob(rng, size * 1.15), Color(0.36, 0.42, 0.28, 0.9), center + Vector2(10, 14))
		_add_polygon(_blob(rng, size), Color(0.50, 0.44, 0.36), center)
		_add_polygon(_blob(rng, size * 0.68), Color(0.58, 0.55, 0.52), center - Vector2(size * 0.08, size * 0.1))
		_add_polygon(_blob(rng, size * 0.32), Color(0.78, 0.76, 0.74), center - Vector2(size * 0.16, size * 0.2))
		_add_polygon(_blob(rng, size * 0.12), Color(0.95, 0.95, 0.96), center - Vector2(size * 0.2, size * 0.25))


func _blob(rng: RandomNumberGenerator, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ph := rng.randf() * TAU
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(Vector2.from_angle(a) * size * (1.0 + 0.18 * sin(3.0 * a + ph) + 0.08 * sin(5.0 * a + ph * 2.0)))
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


## Data til hav-shaderen: [position + radius + lagune, formfaser].
func get_shape_data() -> Array:
	return [
		Vector4(global_position.x, global_position.y, radius, lagoon_size),
		Vector4(_phases.x, _phases.y, _phases.z, coast_detail),
	]


func is_on_land(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	if local.length() > radius * 1.5: # hurtig afvisning før den dyre polygon-test
		return false
	return Geometry2D.is_point_in_polygon(local, _land_shape)


## Afstand fra øens midte til stranden i en given retning (samme formel som formen).
func shore_radius(angle: float) -> float:
	var p := _phases
	var r := 1.0 + 0.16 * sin(2.0 * angle + p.x) + 0.10 * sin(3.0 * angle + p.y) + 0.05 * sin(5.0 * angle + p.z)
	if coast_detail > 0.0:
		r += coast_detail * (0.08 * sin(4.0 * angle + p.x * 1.7 + p.y) + 0.05 * sin(7.0 * angle + p.z * 2.3 + p.x) + 0.03 * sin(11.0 * angle + p.y * 3.1))
	return radius * r


## 0 = midten, 1 = strandkanten, >1 = ude i vandet.
func normalized_distance(global_point: Vector2) -> float:
	var d := global_point - global_position
	return d.length() / shore_radius(d.angle())


## Vanddybde 0..1 – præcis samme beregning som i ocean.gdshader.
func depth_at(global_point: Vector2) -> float:
	if global_point.distance_squared_to(global_position) > pow(radius * 1.47 * lagoon_size, 2.0):
		return 1.0 # langt ude: åbent hav (samme hurtige afvisning som shaderen)
	var t := clampf((normalized_distance(global_point) - 1.0) / (lagoon_size - 1.0), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Tilfældigt punkt på øen. min_f/max_f: 0 = midten, 1 = strandkanten.
func random_land_point(min_f := 0.15, max_f := 0.85) -> Vector2:
	var a := randf() * TAU
	if harbor_name != "":
		for i in 6: # undgå havnebyen
			if absf(angle_difference(a, harbor_angle)) > 0.6:
				break
			a = randf() * TAU
	return global_position + Vector2.from_angle(a) * shore_radius(a) * randf_range(min_f, max_f)


func _create_harbor() -> void:
	harbor = Harbor.new()
	harbor.harbor_name = harbor_name
	harbor.kind = harbor_kind
	harbor.city = harbor_city
	harbor.position = Vector2.from_angle(harbor_angle) * shore_radius(harbor_angle) * 0.86
	harbor.rotation = harbor_angle
	add_child(harbor)
	if harbor_kind == "home":
		var site := HomeSite.new()
		site.island = self
		add_child(site) # midt på øen, uden rotation – byggefeltet er et almindeligt gitter


## Flyt hvert punkt et fast antal pixels ud (+) eller ind (-) fra midten.
func _offset(points: PackedVector2Array, px: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + p.normalized() * px)
	return out


## Ring mellem to kurver med farveovergang (bruges til den bløde strandkant).
func _add_fade_ring(inner: PackedVector2Array, outer: PackedVector2Array, inner_col: Color, outer_col: Color) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := inner.size()
	pts.append_array(inner)
	pts.append_array(outer)
	for i in n:
		cols.append(inner_col)
	for i in n:
		cols.append(outer_col)
	var polys: Array = []
	for i in n:
		var j := (i + 1) % n
		polys.append(PackedInt32Array([i, j, n + j, n + i]))
	poly.polygon = pts
	poly.vertex_colors = cols
	poly.polygons = polys
	poly.antialiased = false
	_tag(poly)


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
	_gull_player.bus = "Ambience"
	add_child(_gull_player)
	_gull_timer = randf_range(1.0, 6.0)
