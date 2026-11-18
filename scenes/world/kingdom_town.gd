class_name KingdomTown
extends Node2D
## Byen rundt om et kongeriges slot: huse, markedsboder, brønd, haver, røg fra skorstene
## og indbyggere og vagter der går rundt. Lokal +x peger ud mod havet (ligesom slottet).

const INNER := 125.0 ## fri plads rundt om slottet (mur og voldgrav)
const OUTER := 320.0

var kingdom_index: int = 0
var road_length: float = 300.0
var _houses: Array = [] ## [Rect2 (lokalt), tagfarve, rotation]
var _stalls: Array = [] ## [Vector2, farve]
var _chimneys: Array[Vector2] = []
var _gardens: Array = [] ## [Rect2, farve]
var _life: TownLife


func _ready() -> void:
	z_index = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + kingdom_index * 77
	var roof_cols := [Color(0.72, 0.32, 0.2), Color(0.6, 0.28, 0.18), Color(0.5, 0.36, 0.25), Color(0.68, 0.45, 0.25), Color(0.42, 0.42, 0.5)]
	var tries := 0
	while _houses.size() < 34 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(INNER + 15.0, OUTER)
		var pos := Vector2.from_angle(a) * d
		if pos.x > 0.0 and absf(pos.y) < 32.0:
			continue # vejen ned til havnen
		var size := Vector2(rng.randf_range(16, 26), rng.randf_range(12, 18))
		var r := Rect2(pos - size * 0.5, size)
		var ok := true
		for h in _houses:
			if (h[0] as Rect2).grow(6.0).intersects(r):
				ok = false
				break
		if ok:
			_houses.append([r, roof_cols[rng.randi() % roof_cols.size()], a])
			if rng.randf() < 0.45:
				_chimneys.append(r.position + Vector2(size.x * 0.75, size.y * 0.3))
	# Markedsplads langs vejen
	for i in 6:
		var x := INNER + 40.0 + i * 26.0
		for side in [-1.0, 1.0]:
			_stalls.append([Vector2(x, side * 44.0), roof_cols[i % 2] if i % 3 == 0 else (Catalog.KINGDOMS[kingdom_index]["color"] as Color)])
	# Haver og små marker i udkanten
	for i in 8:
		var a := rng.randf() * TAU
		var pos := Vector2.from_angle(a) * rng.randf_range(OUTER - 20.0, OUTER + 40.0)
		if pos.x > 0.0 and absf(pos.y) < 40.0:
			continue
		_gardens.append([Rect2(pos - Vector2(20, 14), Vector2(40, 28)), Color(0.45, 0.6, 0.3) if i % 2 else Color(0.75, 0.68, 0.38)])
	_life = TownLife.new()
	_life.town = self
	for c in _chimneys:
		_life.chimneys.append(c)
	for h in _houses:
		_life.doors.append((h[0] as Rect2).get_center())
	add_child(_life)
	WorldSky.add_lantern(self, Vector2(INNER + 100.0, 0), 140.0, Color(1.0, 0.75, 0.45), 0.7)


func _draw() -> void:
	var k: Dictionary = Catalog.KINGDOMS[kingdom_index]
	# Græs og brostensplads
	draw_circle(Vector2.ZERO, OUTER + 30.0, Color(0.48, 0.66, 0.36, 0.55), true, -1.0, true)
	for g in _gardens:
		var r: Rect2 = g[0]
		draw_rect(r, (g[1] as Color).darkened(0.1))
		for i in 4:
			draw_line(r.position + Vector2(3, 4 + i * 6), r.position + Vector2(r.size.x - 3, 4 + i * 6), (g[1] as Color).lightened(0.15), 1.5)
	draw_rect(Rect2(INNER + 20.0, -60.0, 180.0, 120.0), Color(0.72, 0.66, 0.55, 0.85)) # torvet
	for i in 40:
		var p := Vector2(INNER + 25.0 + fmod(i * 37.0, 170.0), -55.0 + fmod(i * 23.0, 110.0))
		draw_circle(p, 1.2, Color(0.62, 0.57, 0.48), true, -1.0, true)
	# Brønd midt på torvet
	var well := Vector2(INNER + 110.0, 0)
	draw_circle(well + Vector2(2, 3), 8.0, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(well, 8.0, Color(0.55, 0.52, 0.48), true, -1.0, true)
	draw_circle(well, 5.0, Color(0.15, 0.3, 0.45), true, -1.0, true)
	# Huse med skygge, gavl og vindue
	for h in _houses:
		var r: Rect2 = h[0]
		var roof: Color = h[1]
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.22))
		draw_rect(r.grow(1.0), Color(0.88, 0.84, 0.74))
		draw_rect(r, roof)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), roof.lightened(0.12)) # lys tagflade
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), roof.darkened(0.35), 1.2)
		draw_rect(Rect2(r.get_center() + Vector2(-2, r.size.y * 0.5 - 1.0), Vector2(4, 2)), Color(0.35, 0.22, 0.12)) # dør
	for c in _chimneys:
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(0.45, 0.35, 0.3))
	# Markedsboder med stribede markiser
	for st in _stalls:
		var p: Vector2 = st[0]
		var col: Color = st[1]
		draw_rect(Rect2(p + Vector2(-8, -6) + Vector2(2, 3), Vector2(16, 12)), Color(0, 0, 0, 0.2))
		for i in 4:
			draw_rect(Rect2(p + Vector2(-8 + i * 4, -6), Vector2(4, 12)), col if i % 2 == 0 else Color(0.95, 0.92, 0.85))
	# Banner-stænger langs vejen i kongerigets farver
	for i in 4:
		var x := INNER + 20.0 + i * 55.0
		for side in [-1.0, 1.0]:
			var base := Vector2(x, side * 30.0)
			draw_line(base, base + Vector2(0, -12), Color(0.35, 0.25, 0.15), 1.0, true)
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -12), base + Vector2(8, -10), base + Vector2(0, -7)]), k["color"])


## Det levende: indbyggere der går mellem husene, vagter på vejen og røg fra skorstenene.
class TownLife extends Node2D:
	var town: KingdomTown
	var doors: Array[Vector2] = []
	var chimneys: Array[Vector2] = []
	var _people: Array = [] ## [pos, target, color, speed]
	var _guards: Array = [] ## [x, dir]
	var _smoke: Array = [] ## [pos, age]
	var _time: float = 0.0
	var _smoke_timer: float = 0.0

	func _ready() -> void:
		z_index = 2
		var cloth := [Color(0.75, 0.3, 0.25), Color(0.3, 0.45, 0.7), Color(0.85, 0.75, 0.4), Color(0.4, 0.6, 0.35), Color(0.6, 0.4, 0.6), Color(0.9, 0.9, 0.85)]
		for i in 22:
			var start: Vector2 = doors.pick_random() if not doors.is_empty() else Vector2(200, 0)
			_people.append([start, _new_target(), cloth[i % cloth.size()], randf_range(9.0, 15.0)])
		for i in 4:
			_guards.append([KingdomTown.INNER + randf() * 200.0, 1.0 if i % 2 == 0 else -1.0, -18.0 if i < 2 else 18.0])

	func _new_target() -> Vector2:
		if randf() < 0.45:
			return Vector2(KingdomTown.INNER + randf_range(30.0, 190.0), randf_range(-50.0, 50.0)) # torvet
		return doors.pick_random() if not doors.is_empty() else Vector2(200, 0)

	func _process(delta: float) -> void:
		_time += delta
		# Spar kræfter når ingen kigger
		var cam := get_viewport().get_camera_2d()
		if cam and cam.get_screen_center_position().distance_to(global_position) > 1400.0:
			return
		for p in _people:
			var to: Vector2 = p[1] - p[0]
			if to.length() < 2.0:
				p[1] = _new_target()
			else:
				p[0] += to.normalized() * float(p[3]) * delta
		for g in _guards:
			g[0] += g[1] * 10.0 * delta
			if g[0] > KingdomTown.INNER + town.road_length * 0.6 or g[0] < KingdomTown.INNER - 10.0:
				g[1] = -g[1]
		_smoke_timer -= delta
		if _smoke_timer <= 0.0 and not chimneys.is_empty():
			_smoke_timer = 0.35
			_smoke.append([chimneys.pick_random(), 0.0])
		for sm in _smoke:
			sm[1] += delta
		_smoke = _smoke.filter(func(sm: Array) -> bool: return sm[1] < 3.0)
		queue_redraw()

	func _draw() -> void:
		var k: Dictionary = Catalog.KINGDOMS[town.kingdom_index]
		for sm in _smoke:
			var age: float = sm[1]
			var pos: Vector2 = sm[0] + Vector2(-age * 6.0 + sin(age * 2.0) * 2.0, -age * 9.0)
			draw_circle(pos, 2.0 + age * 2.2, Color(0.85, 0.85, 0.85, 0.35 * (1.0 - age / 3.0)), true, -1.0, true)
		for p in _people:
			var pos: Vector2 = p[0]
			var bob := sin(_time * 10.0 + pos.x) * 0.4
			draw_circle(pos + Vector2(1, 1.5), 2.3, Color(0, 0, 0, 0.2), true, -1.0, true)
			draw_circle(pos, 2.3, p[2], true, -1.0, true)
			draw_circle(pos + Vector2(0, bob - 0.4), 1.3, Color(0.95, 0.8, 0.62), true, -1.0, true)
		for g in _guards:
			var pos := Vector2(g[0], g[2])
			draw_circle(pos + Vector2(1, 1.5), 2.6, Color(0, 0, 0, 0.2), true, -1.0, true)
			draw_circle(pos, 2.6, k["color"], true, -1.0, true)
			draw_circle(pos, 1.5, Color(0.82, 0.84, 0.9), true, -1.0, true)
			draw_line(pos + Vector2(2.5, 0), pos + Vector2(2.5 + g[1] * 2.0, -7), Color(0.5, 0.35, 0.2), 0.8, true)
