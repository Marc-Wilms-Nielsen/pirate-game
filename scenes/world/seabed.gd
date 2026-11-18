class_name Seabed
extends Node2D
## Havbunden under det åbne hav: klitter, store sten og gamle skibsvrag.
## Ligger under hav-shaderen (som er let gennemsigtig på dybt vand), så man ser ned i dybet.
## Hele bunden skaleres en smule omkring kameraet (parallakse), så den føles langt nede.

const DEPTH_PARALLAX := 0.94 ## < 1: bunden bevæger sig lidt langsommere end overfladen
const SWAY_SHADER := """
shader_type canvas_item;
// Vandet over bunden bryder lyset: tingene dernede vugger en lille smule.
void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	VERTEX += vec2(sin(TIME * 0.8 + w.y * 0.04), cos(TIME * 0.65 + w.x * 0.04)) * 1.3;
}
"""

var world_seed: int = 1
var world_radius: float = 14000.0
const WRECK_CHANCE := 0.4 ## chance for et vrag i en celle (2000 x 2000 px)

var _floor: ColorRect


func _ready() -> void:
	z_index = -11
	z_as_relative = false
	add_to_group("seabed")
	_floor = ColorRect.new()
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.position = Vector2.ONE * -world_radius * 2.2
	_floor.size = Vector2.ONE * world_radius * 4.4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/seabed.gdshader") as Shader
	mat.set_shader_parameter("quality", Settings.water_quality)
	_floor.material = mat
	add_child(_floor)
	var sway := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	sway.shader = sh
	material = sway
	_floor.use_parent_material = false


## Spreder sten og vrag ud på det dybe vand i én verdenscelle (kaldes af WorldStreamer,
## første gang cellen kommer tæt på kameraet). Samme celle giver altid de samme ting.
func populate_cell(cell: Vector2i, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, world_seed))
	if rect.get_center().length() > world_radius * 1.1:
		return
	var count := rng.randi_range(4, 8)
	for i in count + (1 if rng.randf() < WRECK_CHANCE else 0):
		var pos := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		if Game.water_depth(pos) < 0.97:
			continue
		var thing := Thing.new()
		thing.position = pos
		thing.rotation = rng.randf() * TAU
		thing.seed_value = rng.randi()
		thing.kind = "wreck" if i >= count else "rocks"
		thing.use_parent_material = true
		add_child(thing)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	scale = Vector2.ONE * DEPTH_PARALLAX
	position = c * (1.0 - DEPTH_PARALLAX)


func set_quality(q: int) -> void:
	(_floor.material as ShaderMaterial).set_shader_parameter("quality", q)


## Én ting på bunden: en stenklynge eller et vrag. Tegnes én gang (statisk).
class Thing extends Node2D:
	var kind := "rocks"
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if kind == "wreck":
			_draw_wreck(rng)
		else:
			_draw_rocks(rng)

	func _blob(rng: RandomNumberGenerator, center: Vector2, r: float, points := 9, rough := 0.28) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var stretch := rng.randf_range(0.7, 1.3)
		for i in points:
			var a := TAU * i / points
			var rr := r * rng.randf_range(1.0 - rough, 1.0 + rough * 0.5)
			pts.append(center + Vector2(cos(a) * rr * stretch, sin(a) * rr))
		return pts

	## Lyst sand rundt om tingen, så den skiller sig ud fra den mørke bund.
	func _sand(rng: RandomNumberGenerator, r: float) -> void:
		for i in 6:
			var k := 1.0 - i * 0.13
			draw_colored_polygon(_blob(rng, Vector2.ZERO, r * k, 14, 0.12), Color(0.42, 0.42, 0.34, 0.07))

	func _draw_rocks(rng: RandomNumberGenerator) -> void:
		var size := rng.randf_range(18.0, 70.0) * (1.6 if rng.randf() < 0.12 else 1.0)
		_sand(rng, size * 1.7)
		var base := Color(0.38, 0.4, 0.37).lerp(Color(0.42, 0.36, 0.3), rng.randf())
		var count := rng.randi_range(2, 5)
		for i in count:
			var c := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * size * 0.7
			var r := size * rng.randf_range(0.35, 0.75)
			var shape := _blob(rng, c, r)
			draw_colored_polygon(_shifted(shape, Vector2(r * 0.15, r * 0.2)), Color(0, 0, 0, 0.25)) # skygge
			var col := base.darkened(rng.randf_range(0.0, 0.25))
			draw_colored_polygon(shape, col)
			draw_colored_polygon(_blob(rng, c + Vector2(-r * 0.2, -r * 0.25), r * 0.55, 7, 0.2), col.lightened(0.18))
		# Lidt tang og koraller
		for i in rng.randi_range(2, 6):
			var root := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * size
			var pts := PackedVector2Array()
			var ang := rng.randf() * TAU
			for j in 5:
				pts.append(root + Vector2.from_angle(ang) * j * size * 0.12 + Vector2.from_angle(ang + PI * 0.5) * sin(j * 1.3) * 3.0)
			draw_polyline(pts, Color(0.2, 0.42, 0.25, 0.8), 2.0, true)
		if rng.randf() < 0.5:
			var coral := [Color(0.75, 0.38, 0.4), Color(0.85, 0.55, 0.3), Color(0.6, 0.4, 0.7)].pick_random() as Color
			for i in rng.randi_range(2, 5):
				draw_circle(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * size, rng.randf_range(2.5, 5.0), coral, true, -1.0, true)

	func _draw_wreck(rng: RandomNumberGenerator) -> void:
		var ship_len := rng.randf_range(90.0, 160.0)
		var beam := ship_len * rng.randf_range(0.26, 0.32)
		_sand(rng, ship_len * 0.75)
		var wood := Color(0.36, 0.25, 0.16)
		var dark := wood.darkened(0.45)
		var hl := ship_len * 0.5
		var hb := beam * 0.5
		var hull := PackedVector2Array([
			Vector2(hl, 0), Vector2(hl * 0.6, -hb), Vector2(-hl * 0.75, -hb * 0.95),
			Vector2(-hl, -hb * 0.6), Vector2(-hl, hb * 0.6), Vector2(-hl * 0.75, hb * 0.95), Vector2(hl * 0.6, hb)])
		draw_colored_polygon(_shifted(hull, Vector2(5, 7)), Color(0, 0, 0, 0.3))
		draw_colored_polygon(hull, dark)
		# Brækket over på midten: forenden og agterenden ligger lidt skævt
		var gap := rng.randf_range(-0.2, 0.2) * hl
		var front := PackedVector2Array([Vector2(hl, 0), Vector2(hl * 0.6, -hb * 0.85), Vector2(gap + 6, -hb * 0.85), Vector2(gap + 12, hb * 0.85), Vector2(hl * 0.6, hb * 0.85)])
		draw_colored_polygon(front, wood)
		var back := PackedVector2Array([Vector2(gap - 6, -hb * 0.82), Vector2(-hl * 0.72, -hb * 0.8), Vector2(-hl * 0.9, 0), Vector2(-hl * 0.72, hb * 0.8), Vector2(gap - 12, hb * 0.82)])
		draw_colored_polygon(back, wood.darkened(0.1))
		# Spanter (ribbenene) der stikker frem hvor dækket er væk
		for i in 7:
			var x := lerpf(-hl * 0.65, hl * 0.5, i / 6.0)
			if absf(x - gap) < 14.0:
				continue
			draw_line(Vector2(x, -hb * 0.85), Vector2(x, hb * 0.85), dark, 2.5, true)
		draw_line(Vector2(-hl * 0.9, 0), Vector2(hl, 0), dark.lightened(0.1), 2.0, true) # kølen
		# Den væltede mast med rå
		var mast_from := Vector2(rng.randf_range(-0.2, 0.2) * hl, 0)
		var mast_dir := Vector2.from_angle(rng.randf_range(0.6, 2.4) * (1.0 if rng.randf() < 0.5 else -1.0))
		var mast_to := mast_from + mast_dir * ship_len * 0.7
		draw_line(mast_from, mast_to, Color(0.42, 0.3, 0.2), 4.0, true)
		var yard := mast_from.lerp(mast_to, 0.6)
		var perp := Vector2(-mast_dir.y, mast_dir.x)
		draw_line(yard - perp * beam * 0.6, yard + perp * beam * 0.6, Color(0.4, 0.28, 0.18), 2.5, true)
		# Spredte tønder, en kanon og måske en kiste
		for i in rng.randi_range(2, 5):
			var p := Vector2(rng.randf_range(-1.2, 1.2) * hl, rng.randf_range(-2.0, 2.0) * hb)
			draw_circle(p, 5.0, Color(0.4, 0.28, 0.16), true, -1.0, true)
			draw_arc(p, 5.0, 0.0, TAU, 12, Color(0.25, 0.25, 0.28), 1.2, true)
		var cannon := Vector2(rng.randf_range(-0.6, 0.6) * hl, hb * rng.randf_range(1.2, 1.8))
		draw_line(cannon, cannon + Vector2.from_angle(rng.randf() * TAU) * 14.0, Color(0.22, 0.23, 0.25), 5.0, true)
		if rng.randf() < 0.4:
			var chest := Vector2(rng.randf_range(-0.5, 0.5) * hl, -hb * rng.randf_range(1.3, 2.0))
			draw_rect(Rect2(chest - Vector2(7, 5), Vector2(14, 10)), Color(0.45, 0.3, 0.15))
			draw_line(chest - Vector2(7, 0), chest + Vector2(7, 0), Color(0.75, 0.6, 0.25), 1.5)
			draw_circle(chest + Vector2(9, 3), 1.6, Color(0.95, 0.8, 0.35), true, -1.0, true) # en enkelt guldmønt
		# Tang der er vokset på vraget
		for i in 4:
			var root := Vector2(rng.randf_range(-0.8, 0.8) * hl, rng.randf_range(-1, 1) * hb)
			draw_line(root, root + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 16.0), Color(0.2, 0.42, 0.25, 0.8), 2.0, true)

	func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p + by)
		return out
