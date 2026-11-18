class_name HomeSite
extends Node2D
## Tegner hjemøens byggefelt: hus, marker og bygninger på de felter, du har valgt i hjemmenuen,
## plus arbejdere der går mellem huset og bygningerne. Ligger midt på øen, uden rotation.

const CELL := Catalog.HOME_CELL
const GRID := Catalog.HOME_GRID

var island: Island
var _time: float = 0.0
var _walkers: Array = [] ## [pos, mål-felt, farve]


func _ready() -> void:
	z_index = 1
	WorldSky.add_lantern(self, Vector2.ZERO, 160.0, Color(1.0, 0.8, 0.5), 0.7)
	Homestead.changed.connect(_on_home_changed)
	_compute_valid_cells()


func _on_home_changed() -> void:
	queue_redraw()


## Lokal position for midten af et felt.
static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) - Vector2(GRID - Vector2i.ONE) * 0.5) * CELL


## Felter der ligger på land og ikke i havnebyen.
func _compute_valid_cells() -> void:
	var cells: Array[Vector2i] = []
	var harbor_pos := Vector2.from_angle(island.harbor_angle) * island.shore_radius(island.harbor_angle) * 0.86 if island else Vector2(9999, 0)
	for x in GRID.x:
		for y in GRID.y:
			var c := Vector2i(x, y)
			var p := cell_center(c)
			if island and island.normalized_distance(to_global(p)) > 0.78:
				continue
			if p.distance_to(harbor_pos) < 115.0:
				continue
			cells.append(c)
	Homestead.set_valid_cells(cells)


func _process(delta: float) -> void:
	_time += delta
	if not Homestead.claimed:
		return
	var cam := get_viewport().get_camera_2d()
	if cam and cam.get_screen_center_position().distance_to(global_position) > 1100.0:
		return
	_update_walkers(delta)
	queue_redraw()


## Arbejderne går frem og tilbage mellem huset og bygningen de arbejder i.
func _update_walkers(delta: float) -> void:
	var wanted := mini(Homestead.workers, 14)
	var house := _house_cell_pos()
	var spots: Array[Vector2] = []
	for k in Homestead.layout:
		var item: Dictionary = Homestead.layout[k]
		if item["type"] == "building" and Homestead.working(item["id"]) > 0:
			spots.append(cell_center(Homestead.cell_of(k)))
	while _walkers.size() < wanted:
		_walkers.append([house, house, Color(randf_range(0.4, 0.9), randf_range(0.3, 0.7), randf_range(0.2, 0.6))])
	while _walkers.size() > wanted:
		_walkers.pop_back()
	for w in _walkers:
		var to: Vector2 = w[1] - w[0]
		if to.length() < 2.0:
			w[1] = (spots.pick_random() if not spots.is_empty() and randf() < 0.75 else house) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		else:
			w[0] += to.normalized() * 14.0 * delta


func _house_cell_pos() -> Vector2:
	for k in Homestead.layout:
		if Homestead.layout[k]["type"] == "house":
			return cell_center(Homestead.cell_of(k))
	return Vector2.ZERO


func _draw() -> void:
	if not Homestead.claimed:
		# Et skilt med "For sale"
		draw_rect(Rect2(8, -2, 1.5, 10), Color(0.4, 0.28, 0.15))
		draw_rect(Rect2(2, -8, 14, 8), Color(0.75, 0.6, 0.35))
		draw_rect(Rect2(4, -6, 10, 1.2), Color(0.35, 0.22, 0.1))
		draw_rect(Rect2(4, -3.5, 7, 1.2), Color(0.35, 0.22, 0.1))
		return
	# Stier mellem felterne (svagt lysere jord)
	for k in Homestead.layout:
		var p := cell_center(Homestead.cell_of(k))
		draw_circle(p, CELL * 0.62, Color(0.62, 0.55, 0.38, 0.35), true, -1.0, true)
	for k in Homestead.layout:
		var item: Dictionary = Homestead.layout[k]
		var p := cell_center(Homestead.cell_of(k))
		match String(item["type"]):
			"house":
				_house(Rect2(p - Vector2(15, 12), Vector2(30, 24)), Color(0.72, 0.32, 0.2), true)
			"field":
				var idx := int(item["plot"])
				if idx < Homestead.plots.size():
					_plot(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Homestead.plots[idx])
			"building":
				_building(item["id"], p, int(Homestead.buildings.get(item["id"], 1)))
	for w in _walkers:
		var pos: Vector2 = w[0]
		draw_circle(pos + Vector2(1, 1.5), 2.2, Color(0, 0, 0, 0.2), true, -1.0, true)
		draw_circle(pos, 2.2, w[2], true, -1.0, true)
		draw_circle(pos + Vector2(0, -0.6 + sin(_time * 10.0 + pos.x) * 0.3), 1.2, Color(0.95, 0.8, 0.62), true, -1.0, true)


func _building(id: String, p: Vector2, level: int) -> void:
	var s := 0.85 + 0.08 * level
	match id:
		"cottage":
			for i in mini(level, 3):
				var o := Vector2(-9 + i * 9, -4 + (i % 2) * 8) * s
				_house(Rect2(p + o - Vector2(6, 5), Vector2(12, 10)), Color(0.6, 0.42, 0.28), false)
		"chickens":
			_house(Rect2(p + Vector2(-14, -12) * s, Vector2(16, 12) * s), Color(0.85, 0.72, 0.4), false)
			draw_rect(Rect2(p + Vector2(-16, 2), Vector2(32, 12)), Color(0.55, 0.45, 0.3, 0.5), false, 1.0)
			for i in 3 + level:
				var c := p + Vector2(-12 + fmod(i * 7.3 + sin(_time * 2.0 + i) * 3.0, 24.0), 6 + fmod(i * 3.1, 6.0))
				draw_circle(c, 1.4, Color(0.98, 0.96, 0.9), true, -1.0, true)
				draw_circle(c + Vector2(1.2, -0.6), 0.5, Color(0.9, 0.3, 0.2), true, -1.0, true)
		"fishery":
			_house(Rect2(p + Vector2(-12, -10) * s, Vector2(20, 14) * s), Color(0.35, 0.5, 0.65), false)
			for i in 3:
				draw_line(p + Vector2(-14 + i * 6, 8), p + Vector2(-12 + i * 6, 14), Color(0.45, 0.35, 0.22), 1.0)
			draw_arc(p + Vector2(10, 9), 5.0, 0.0, PI, 8, Color(0.85, 0.82, 0.7), 1.0) # net
			for i in level:
				draw_circle(p + Vector2(8 + i * 3, 6), 1.0, Color(0.6, 0.75, 0.85), true, -1.0, true)
		"lumber":
			_house(Rect2(p + Vector2(-14, -12) * s, Vector2(14, 12) * s), Color(0.5, 0.35, 0.2), false)
			for i in 2 + level:
				var lp := p + Vector2(2 + (i % 3) * 4, -2 + floori(i / 3.0) * 4)
				draw_circle(lp, 2.0, Color(0.55, 0.38, 0.2), true, -1.0, true)
				draw_circle(lp, 1.2, Color(0.85, 0.7, 0.45), true, -1.0, true)
			var chop := absf(sin(_time * 3.0))
			draw_line(p + Vector2(-4, 8), p + Vector2(-4, 8) + Vector2.from_angle(-1.2 - chop) * 6.0, Color(0.6, 0.6, 0.65), 1.2, true)
		"quarry":
			for i in 3 + level:
				var rp := p + Vector2(-10 + fmod(i * 9.0, 22.0), -8 + floori(i / 3.0) * 7)
				draw_circle(rp + Vector2(1, 1.5), 4.0, Color(0, 0, 0, 0.2), true, -1.0, true)
				draw_circle(rp, 4.0, Color(0.55, 0.55, 0.58), true, -1.0, true)
				draw_circle(rp - Vector2(1, 1.2), 1.8, Color(0.7, 0.7, 0.72), true, -1.0, true)
		"workshop":
			_house(Rect2(p + Vector2(-14, -12) * s, Vector2(24, 18) * s), Color(0.45, 0.3, 0.25), true)
			draw_rect(Rect2(p + Vector2(8, 4), Vector2(7, 4)), Color(0.3, 0.3, 0.33)) # ambolt
			var glow := 0.5 + 0.5 * sin(_time * 4.0)
			draw_circle(p + Vector2(-8, 8), 2.0, Color(1.0, 0.55, 0.2, 0.5 + 0.4 * glow), true, -1.0, true)
			for i in 3:
				var age := fmod(_time * 0.6 + i * 0.33, 1.0)
				draw_circle(p + Vector2(4, -10) * s + Vector2(-age * 6.0, -age * 12.0), 1.5 + age * 2.5, Color(0.8, 0.8, 0.8, 0.4 * (1.0 - age)), true, -1.0, true)
		_:
			_house(Rect2(p - Vector2(10, 8), Vector2(20, 16)), Color(0.5, 0.5, 0.5), false)
	# Niveau-prikker
	for i in level:
		draw_circle(p + Vector2(-CELL * 0.4 + i * 4.0, CELL * 0.42), 1.3, Color(1, 0.85, 0.3), true, -1.0, true)


func _house(r: Rect2, roof: Color, chimney: bool) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.22))
	draw_rect(r.grow(1.0), Color(0.88, 0.83, 0.72))
	draw_rect(r, roof)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), roof.lightened(0.12))
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), roof.darkened(0.3), 1.2)
	if chimney:
		draw_rect(Rect2(r.end - Vector2(7, r.size.y - 2), Vector2(4, 4)), Color(0.45, 0.35, 0.3))


func _plot(r: Rect2, plot: Dictionary) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.15))
	draw_rect(r, Color(0.45, 0.32, 0.2))
	for k in 5:
		draw_line(r.position + Vector2(2, 2.5 + k * 4.6), r.position + Vector2(r.size.x - 2, 2.5 + k * 4.6), Color(0.38, 0.26, 0.16), 0.8)
	if plot["crop"] == "":
		return
	var g := Homestead.growth(plot)
	var ripe := g >= 1.0
	var crop_col := {"wheat": Color(0.9, 0.8, 0.35), "hemp": Color(0.4, 0.65, 0.3), "sugar": Color(0.55, 0.75, 0.4),
		"tobacco": Color(0.5, 0.6, 0.25), "herbs": Color(0.5, 0.75, 0.45)}.get(plot["crop"], Color.GREEN) as Color
	for x in 7:
		for y in 5:
			var p := r.position + Vector2(3.0 + x * 4.3, 3.0 + y * 4.5)
			draw_circle(p, 0.6 + 1.3 * g, crop_col if ripe else Color(0.35, 0.6, 0.3), true, -1.0, true)
	if ripe:
		var glint := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(r.position + Vector2(r.size.x - 2, 1), 1.5, Color(1, 1, 0.7, glint), true, -1.0, true)
