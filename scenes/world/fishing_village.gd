class_name FishingVillage
extends Node2D
## En lille fiskerlandsby ved kysten: hytter med stråtag, en mole ud i vandet, robåde,
## fiskenet til tørre, et bål og et par landsbyboere der går rundt.
## Ligger med +x mod havet (rotation sættes af main.gd), og molen når ud forbi stranden.

var village_name := "Fisher's Nook"
var seed_value := 1
var pier_length := 120.0 ## fra landsbyens midte og ud til stranden (+40)

var _huts: Array = [] ## [Vector2 midte, Vector2 størrelse, tagfarve]
var _boats: Array = [] ## [Vector2, vinkel, farve]
var _people: Array = [] ## [pos, mål, farve, fart]
var _time := 0.0


func _ready() -> void:
	add_to_group("villages")
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shore_x := pier_length - 40.0
	var roofs := [Color(0.78, 0.66, 0.38), Color(0.7, 0.58, 0.32), Color(0.62, 0.5, 0.3)]
	var tries := 0
	while _huts.size() < rng.randi_range(4, 7) and tries < 60:
		tries += 1
		var size := Vector2(rng.randf_range(14, 20), rng.randf_range(11, 15))
		var pos := Vector2(rng.randf_range(-70.0, shore_x - 30.0), rng.randf_range(-65.0, 65.0))
		var ok := true
		for h in _huts:
			if (h[0] as Vector2).distance_to(pos) < 30.0:
				ok = false
				break
		if ok and absf(pos.y) > 14.0: # en sti ned til molen i midten
			_huts.append([pos, size, roofs.pick_random()])
	for i in rng.randi_range(2, 3):
		_boats.append([Vector2(shore_x + rng.randf_range(20.0, 60.0), (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(16.0, 26.0)),
			rng.randf_range(-0.4, 0.4), [Color(0.55, 0.38, 0.22), Color(0.35, 0.5, 0.6), Color(0.65, 0.3, 0.25)][i % 3]])
	var cloth := [Color(0.7, 0.35, 0.25), Color(0.3, 0.45, 0.65), Color(0.85, 0.8, 0.6), Color(0.45, 0.6, 0.4)]
	for i in rng.randi_range(3, 5):
		var start := _random_spot()
		_people.append([start, _random_spot(), cloth[i % cloth.size()], randf_range(7.0, 12.0)])
	WorldSky.add_lantern(self, Vector2(-10, 0), 70.0, Color(1.0, 0.6, 0.3), 0.8) # bålet
	WorldSky.add_lantern(self, Vector2(shore_x + 75.0, 0), 45.0, Color(1.0, 0.75, 0.4), 0.7) # lygten for enden af molen


func _random_spot() -> Vector2:
	if not _huts.is_empty() and randf() < 0.6:
		var h: Array = _huts.pick_random()
		return (h[0] as Vector2) + Vector2(0, (h[1] as Vector2).y * 0.6)
	return Vector2(randf_range(-40.0, pier_length + 10.0), randf_range(-12.0, 12.0)) # på stien eller molen


func _process(delta: float) -> void:
	_time += delta
	for p in _people:
		var to: Vector2 = p[1] - p[0]
		if to.length() < 2.0:
			p[1] = _random_spot()
		else:
			p[0] += to.normalized() * float(p[3]) * delta
	queue_redraw()


func _draw() -> void:
	var shore_x := pier_length - 40.0
	# Trampet sti ned til vandet og en lille plads med bålet
	draw_line(Vector2(-40, 0), Vector2(shore_x, 0), Color(0.72, 0.62, 0.42, 0.7), 12.0, true)
	draw_circle(Vector2(-10, 0), 18.0, Color(0.72, 0.62, 0.42, 0.7), true, -1.0, true)
	# Bål
	draw_circle(Vector2(-10, 0), 4.5, Color(0.35, 0.3, 0.28), true, -1.0, true)
	var flick := 0.7 + 0.3 * sin(_time * 9.0)
	draw_circle(Vector2(-10, -0.5), 2.8 * flick, Color(1.0, 0.55, 0.15), true, -1.0, true)
	draw_circle(Vector2(-10, -1.0), 1.4 * flick, Color(1.0, 0.9, 0.4), true, -1.0, true)
	# Molen: planker på pæle ud i vandet
	var pier_from := shore_x - 10.0
	var pier_to := shore_x + 75.0
	draw_rect(Rect2(pier_from + 2, -5 + 2, pier_to - pier_from, 10), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(pier_from, -5, pier_to - pier_from, 10), Color(0.55, 0.4, 0.25))
	var x := pier_from + 4.0
	while x < pier_to:
		draw_line(Vector2(x, -5), Vector2(x, 5), Color(0.42, 0.3, 0.18), 1.0)
		x += 5.0
	for px in [pier_from + 25.0, pier_from + 50.0, pier_to - 3.0]:
		draw_circle(Vector2(px, -6), 1.6, Color(0.35, 0.25, 0.15), true, -1.0, true)
		draw_circle(Vector2(px, 6), 1.6, Color(0.35, 0.25, 0.15), true, -1.0, true)
	# Robåde ved molen (vugger lidt)
	for b in _boats:
		var pos: Vector2 = b[0] + Vector2(0, sin(_time * 1.3 + (b[0] as Vector2).x) * 0.8)
		var hull := PackedVector2Array([Vector2(-9, 0), Vector2(-6, -3.5), Vector2(6, -3.5), Vector2(10, 0), Vector2(6, 3.5), Vector2(-6, 3.5)])
		var t := Transform2D(float(b[1]), pos)
		draw_colored_polygon(t * hull, Color(0, 0, 0, 0.2))
		draw_set_transform(pos, float(b[1]))
		draw_colored_polygon(hull, b[2])
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(8, 0), Vector2(6, 2), Vector2(-6, 2)]), (b[2] as Color).darkened(0.35))
		draw_line(Vector2(-2, -2), Vector2(-2, 2), (b[2] as Color).lightened(0.2), 1.2)
		draw_set_transform(Vector2.ZERO)
	# Fiskenet til tørre og et stativ med fisk
	var net_x := shore_x - 22.0
	draw_line(Vector2(net_x, -40), Vector2(net_x, -22), Color(0.4, 0.3, 0.2), 1.2)
	draw_line(Vector2(net_x + 14, -40), Vector2(net_x + 14, -22), Color(0.4, 0.3, 0.2), 1.2)
	for i in 5:
		draw_line(Vector2(net_x, -40 + i * 4), Vector2(net_x + 14, -40 + i * 4), Color(0.55, 0.6, 0.55, 0.7), 0.6)
		draw_line(Vector2(net_x + i * 3.5, -40), Vector2(net_x + i * 3.5, -24), Color(0.55, 0.6, 0.55, 0.7), 0.6)
	draw_line(Vector2(net_x, 26), Vector2(net_x + 16, 26), Color(0.4, 0.3, 0.2), 1.2)
	for i in 4:
		draw_colored_polygon(PackedVector2Array([Vector2(net_x + 2 + i * 4, 26), Vector2(net_x + 4 + i * 4, 26), Vector2(net_x + 3 + i * 4, 32)]), Color(0.6, 0.65, 0.7))
	# Hytter med stråtag
	for h in _huts:
		var c: Vector2 = h[0]
		var sz: Vector2 = h[1]
		var r := Rect2(c - sz * 0.5, sz)
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, Color(0.5, 0.36, 0.22))
		var roof: Color = h[2]
		draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(sz.x, 0), c + Vector2(sz.x * 0.5, 0), c - Vector2(sz.x * 0.5, 0)]), roof.lightened(0.08))
		draw_colored_polygon(PackedVector2Array([c - Vector2(sz.x * 0.5, 0), c + Vector2(sz.x * 0.5, 0), r.end, r.end - Vector2(sz.x, 0)]), roof.darkened(0.12))
		draw_line(c - Vector2(sz.x * 0.5, 0), c + Vector2(sz.x * 0.5, 0), roof.darkened(0.3), 1.0)
		draw_rect(Rect2(c + Vector2(-1.5, sz.y * 0.5 - 1), Vector2(3, 2)), Color(0.3, 0.2, 0.12))
	# Folk
	for p in _people:
		var pos: Vector2 = p[0]
		var bob := sin(_time * 9.0 + pos.x) * 0.4
		draw_circle(pos + Vector2(1, 1.5), 2.2, Color(0, 0, 0, 0.2), true, -1.0, true)
		draw_circle(pos, 2.2, p[2], true, -1.0, true)
		draw_circle(pos + Vector2(0, bob - 0.4), 1.2, Color(0.9, 0.75, 0.58), true, -1.0, true)
