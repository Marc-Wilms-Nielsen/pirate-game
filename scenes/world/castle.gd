class_name Castle
extends Node2D
## Et kongeriges slot på et af de kæmpe fastlande. Porten vender ud mod havet (+x lokalt).
## Gå hen til porten og tryk F for at udfordre kongeriget til duel.

const HALF := 52.0 ## halv bredde af ringmuren
const INTERACT_RANGE := 46.0

var kingdom_index: int = 0
var island: Island
var _time: float = 0.0
var _guards: Array[float] = [] ## positioner (0..1) rundt langs muren
var _road_length: float = 200.0 ## vej fra porten ned til stranden


func _ready() -> void:
	add_to_group("castles")
	z_index = 1
	WorldSky.add_lantern(self, Vector2(HALF + 4, 0), 70.0, Color(1.0, 0.6, 0.3), 1.1)
	WorldSky.add_lantern(self, Vector2.ZERO, 120.0, Color(1.0, 0.8, 0.55), 0.6)
	for i in 5:
		_guards.append(randf())
	if island:
		var shore := island.global_position + Vector2.from_angle(rotation) * island.shore_radius(rotation)
		_road_length = clampf(global_position.distance_to(shore) / scale.x - HALF - 10.0, 40.0, 900.0)


func kingdom() -> Dictionary:
	return Catalog.KINGDOMS[kingdom_index]


func gate_position() -> Vector2:
	return to_global(Vector2(HALF + 14.0, 0.0))


func can_challenge(pos: Vector2) -> bool:
	return pos.distance_to(gate_position()) < INTERACT_RANGE


func _process(delta: float) -> void:
	_time += delta
	for i in _guards.size():
		_guards[i] = fmod(_guards[i] + delta * 0.012 * (1.0 if i % 2 == 0 else -1.0) + 1.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var k := kingdom()
	var banner: Color = k["color"]
	var accent: Color = k["accent"]
	var wall := Color(0.72, 0.68, 0.6)
	var wall_dark := wall.darkened(0.25)
	var h := HALF
	# Vej fra porten ned til stranden og en græsplæne rundt om slottet
	var road := PackedVector2Array()
	var road_end := h + 14.0 + _road_length
	for i in 13:
		var f := i / 12.0
		road.append(Vector2(lerpf(h + 10.0, road_end, f), sin(f * 5.0) * 10.0 * f - 8.0))
	for i in range(12, -1, -1):
		var f := i / 12.0
		road.append(Vector2(lerpf(h + 10.0, road_end, f), sin(f * 5.0) * 10.0 * f + 8.0))
	draw_circle(Vector2.ZERO, h * 1.55, Color(0.45, 0.66, 0.36, 0.9), true, -1.0, true)
	draw_circle(Vector2.ZERO, h * 1.4, Color(0.5, 0.7, 0.4), true, -1.0, true)
	draw_colored_polygon(road, Color(0.74, 0.64, 0.46))
	for i in 18:
		var f := (i + 0.5) / 18.0
		draw_circle(Vector2(lerpf(h + 14.0, road_end, f), sin(f * 5.0) * 10.0 * f + (3.0 if i % 2 else -3.0)), 1.6, Color(0.62, 0.55, 0.42), true, -1.0, true)
	# Skygge, voldgrav og gård
	draw_rect(Rect2(-h + 6, -h + 8, h * 2, h * 2), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-h - 7, -h - 7, h * 2 + 14, h * 2 + 14), Color(0.3, 0.55, 0.65, 0.55))
	draw_rect(Rect2(-h, -h, h * 2, h * 2), wall_dark)
	draw_rect(Rect2(-h + 7, -h + 7, h * 2 - 14, h * 2 - 14), Color(0.62, 0.6, 0.52))
	# Brosten i gården
	for x in range(-3, 4):
		for y in range(-3, 4):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * 12 - 5, y * 12 - 5, 10, 10), Color(0.66, 0.63, 0.55))
	# Murkrone (tinder) langs kanten
	for i in 14:
		var t := -h + 4 + i * (h * 2 - 8) / 13.0
		for p in [Vector2(t, -h + 3.5), Vector2(t, h - 3.5), Vector2(-h + 3.5, t), Vector2(h - 3.5, t)]:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), wall)
	# Port og vindebro
	draw_rect(Rect2(h - 8, -9, 10, 18), Color(0.35, 0.25, 0.16))
	draw_rect(Rect2(h + 2, -7, 12, 14), Color(0.5, 0.36, 0.22))
	for i in 4:
		draw_line(Vector2(h + 2 + i * 3.5, -7), Vector2(h + 2 + i * 3.5, 7), Color(0.38, 0.27, 0.17), 0.8)
	# Hovedtårn (keep) med tag
	draw_rect(Rect2(-22 + 4, -22 + 5, 44, 44), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-22, -22, 44, 44), wall.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(20, -20), Vector2(0, 0)]), banner.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(20, -20), Vector2(20, 20), Vector2(0, 0)]), banner.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(20, 20), Vector2(-20, 20), Vector2(0, 0)]), banner.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 20), Vector2(-20, -20), Vector2(0, 0)]), banner.darkened(0.05))
	_draw_banner(Vector2(0, 0), 16.0, banner, accent, 0.0)
	# Hjørnetårne med kegletag og bannere
	var corners := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	for i in corners.size():
		var c: Vector2 = corners[i]
		draw_circle(c + Vector2(4, 5), 13.0, Color(0, 0, 0, 0.22), true, -1.0, true)
		draw_circle(c, 13.0, wall_dark, true, -1.0, true)
		draw_circle(c, 11.0, banner.darkened(0.35), true, -1.0, true)
		draw_circle(c + Vector2(-2, -2), 6.5, banner.darkened(0.1), true, -1.0, true)
		draw_circle(c + Vector2(-3, -3), 2.5, banner.lightened(0.15), true, -1.0, true)
		_draw_banner(c, 11.0, banner, accent, i * 1.3)
	# Vagter der går på muren
	for g in _guards:
		var p := _wall_point(g)
		draw_circle(p + Vector2(1, 1), 2.2, Color(0, 0, 0, 0.25), true, -1.0, true)
		draw_circle(p, 2.2, banner, true, -1.0, true)
		draw_circle(p, 1.2, Color(0.85, 0.85, 0.9), true, -1.0, true) # hjelm
	# Fakler ved porten
	for side in [-1.0, 1.0]:
		var f := Vector2(h + 4, 12.0 * side)
		var flick := 0.8 + 0.2 * sin(_time * 11.0 + side * 3.0)
		draw_circle(f, 3.2 * flick, Color(1.0, 0.6, 0.2, 0.35), true, -1.0, true)
		draw_circle(f, 1.4, Color(1.0, 0.85, 0.4), true, -1.0, true)


func _wall_point(t: float) -> Vector2:
	var h := HALF - 3.5
	var side := int(t * 4.0)
	var f := fmod(t * 4.0, 1.0) * 2.0 - 1.0
	match side:
		0:
			return Vector2(f * h, -h)
		1:
			return Vector2(h, f * h)
		2:
			return Vector2(-f * h, h)
	return Vector2(-h, -f * h)


## Banner på en stang. Tegnes i verdensretning, så det altid blafrer "i vinden".
func _draw_banner(base: Vector2, height: float, col: Color, accent: Color, phase: float) -> void:
	var up := Vector2.UP.rotated(-global_rotation) * height
	var wind := Vector2.RIGHT.rotated(-global_rotation)
	var top := base + up
	draw_line(base, top, Color(0.3, 0.22, 0.15), 1.2, true)
	var pts := PackedVector2Array()
	var length := 14.0
	for i in 7:
		var f := i / 6.0
		var wave := sin(_time * 4.0 + phase - f * 4.0) * 1.6 * f
		pts.append(top + wind * length * f + up.normalized() * wave)
	for i in range(6, -1, -1):
		var f := i / 6.0
		var wave := sin(_time * 4.0 + phase - f * 4.0) * 1.6 * f
		pts.append(top + wind * length * f + up.normalized() * (wave - 6.0))
	draw_colored_polygon(pts, col)
	draw_line(top + wind * 2.0 - up.normalized() * 3.0, top + wind * 9.0 - up.normalized() * 3.0, accent, 1.2, true)
