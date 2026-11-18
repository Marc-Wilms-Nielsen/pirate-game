class_name MapView
extends Control
## Kort over verden: øer, laguner, havne, kister, vraggods, fjender og dit skib.

const WORLD_RADIUS := 7200.0

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	clip_contents = true
	custom_minimum_size = Vector2(360, 240)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		if not _opened:
			# Verdenen er stor: start med at vise området omkring skibet
			_opened = true
			var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
			if ship:
				_pan = ship.global_position
				_zoom = 5.0
		queue_redraw()


var _world_radius: float = WORLD_RADIUS


## Kortet skaleres, så alle øer (inkl. navne) er med.
func _update_bounds() -> void:
	var r := 1000.0
	for node in get_tree().get_nodes_in_group("islands"):
		var island := node as Island
		r = maxf(r, island.global_position.length() + island.radius * 1.4 + 1100.0)
	_world_radius = r


# --- Zoom og træk -------------------------------------------------------------
# Scroll: zoom ind/ud omkring musen · Venstre museknap: træk kortet · Højreklik: centrér på skibet
# Dobbeltklik: vis hele verden igen

const LEGEND_WIDTH := 120.0
const MAX_ZOOM := 45.0
var _zoom: float = 1.0
var _opened := false
var _pan := Vector2.ZERO ## verdenspunktet i kortets midte
var _dragging := false


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mb.position, 1.25)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mb.position, 1.0 / 1.25)
			MOUSE_BUTTON_LEFT:
				if mb.double_click:
					_zoom = 1.0
					_pan = Vector2.ZERO
				else:
					_dragging = true
			MOUSE_BUTTON_RIGHT:
				var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
				if ship:
					_pan = ship.global_position
					_zoom = maxf(_zoom, 4.0)
		accept_event()
		queue_redraw()
	elif mb and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_pan -= motion.relative / _scale()
		accept_event()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("zoom_in"):
		zoom_by(1.25)
	elif event.is_action_pressed("zoom_out"):
		zoom_by(1.0 / 1.25)


## Zoom omkring et punkt på kortet, så punktet under musen bliver stående.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := _to_world(screen_pos)
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	_pan += before - _to_world(screen_pos)
	if _zoom <= 1.0:
		_pan = Vector2.ZERO


func zoom_by(factor: float) -> void:
	_zoom_at(_map_rect().get_center(), factor)
	queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(size.x - LEGEND_WIDTH, 50.0), size.y))


func _to_map(world: Vector2) -> Vector2:
	return _map_rect().get_center() + (world - _pan) * _scale()


func _to_world(screen: Vector2) -> Vector2:
	return _pan + (screen - _map_rect().get_center()) / _scale()


func _scale() -> float:
	var r := _map_rect()
	return minf(r.size.x, r.size.y) / (_world_radius * 2.0) * _zoom


func _draw() -> void:
	_update_bounds()
	var map_size := _map_rect().size.x
	draw_rect(_map_rect(), Color(0.10, 0.45, 0.68))
	var s := _scale()

	var islands: Array = []
	var view := _map_rect().grow(20.0)
	for node in get_tree().get_nodes_in_group("islands"):
		var island := node as Island
		var p := _to_map(island.global_position)
		var r := island.radius * island.lagoon_size * s
		if view.intersects(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
			islands.append(island)
	# Øernes former er gemt i verdenskoordinater – én transformation tegner dem alle
	draw_set_transform(_map_rect().get_center() - _pan * s, 0.0, Vector2(s, s))
	for island in islands: # laguner først, så øerne tegnes ovenpå
		draw_colored_polygon(_shape(island, 2), Color(0.45, 0.85, 0.85, 0.45))
	for island in islands:
		draw_colored_polygon(_shape(island, 0), Color(0.94, 0.85, 0.62))
		draw_colored_polygon(_shape(island, 1), Color(0.45, 0.68, 0.35))
	draw_set_transform(Vector2.ZERO)
	for island in islands:
		if island.harbor_name == "" and island.island_name != "" and island.radius * s > 5.0:
			_text(_to_map(island.global_position) + Vector2(0, island.radius * s + 9), island.island_name, 7, Color(1, 1, 1, 0.75))
	for node in get_tree().get_nodes_in_group("villages"):
		var vp := _to_map((node as Node2D).global_position)
		if view.has_point(vp):
			draw_rect(Rect2(vp - Vector2(2, 2), Vector2(4, 4)), Color(0.75, 0.55, 0.35))

	for node in get_tree().get_nodes_in_group("harbors"):
		var harbor := node as Harbor
		var p := _to_map(harbor.global_position)
		if not view.has_point(p):
			continue
		var col: Color = Color(0.35, 0.85, 0.4) if harbor.kind == "home" else Catalog.FACTIONS[Game.faction_of(harbor.harbor_name)]["color"]
		draw_circle(p, 4.5, Color(0.1, 0.1, 0.1), true, -1.0, true)
		draw_circle(p, 3.5, col, true, -1.0, true)
		if _zoom >= 2.0 or harbor.kind == "home":
			_text(p + Vector2(0, -7), ("Your home" if Homestead.claimed else "Deserted island (for sale)") if harbor.kind == "home" else harbor.harbor_name, 8, Color.WHITE)

	_draw_quest_marks(view)

	for node in get_tree().get_nodes_in_group("castles"):
		var castle := node as Castle
		var kp := _to_map(castle.global_position)
		var kc: Color = castle.kingdom()["color"]
		draw_rect(Rect2(kp - Vector2(5, 3), Vector2(10, 7)), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(kp - Vector2(4, 2), Vector2(8, 5)), kc)
		for x in [-4.0, 0.0, 3.0]:
			draw_rect(Rect2(kp + Vector2(x - 0.5, -4.5), Vector2(2, 2.5)), kc)
		_text(kp + Vector2(0, 10), castle.kingdom()["name"], 8, kc.lightened(0.4))

	for node in get_tree().get_nodes_in_group("camps"):
		var cp := _to_map((node as Node2D).global_position)
		draw_circle(cp, 3.5, Color(0.1, 0.1, 0.1), true, -1.0, true)
		draw_line(cp + Vector2(-2, -2), cp + Vector2(2, 2), Color(0.95, 0.3, 0.25), 1.2, true)
		draw_line(cp + Vector2(2, -2), cp + Vector2(-2, 2), Color(0.95, 0.3, 0.25), 1.2, true)
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as Chest
		if not chest.opened and _zoom >= 3.0:
			draw_rect(Rect2(_to_map(chest.global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.85, 0.2))
	for node in get_tree().get_nodes_in_group("floating_loot"):
		draw_circle(_to_map((node as Node2D).global_position), 1.5, Color(0.75, 0.5, 0.3), true, -1.0, true)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyShip
		var col := Color(0.95, 0.25, 0.2) if enemy.faction == "pirate" else Color(0.95, 0.95, 0.95)
		_arrow(_to_map(enemy.global_position), enemy.rotation, 4.0, col)

	for node in get_tree().get_nodes_in_group("escorts"):
		var escort := node as Node2D
		_arrow(_to_map(escort.global_position), escort.rotation, 4.5, Color(0.55, 0.9, 1.0))

	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	if ship:
		var p := _to_map(ship.global_position)
		draw_arc(p, 9.0 + sin(Time.get_ticks_msec() / 250.0) * 1.5, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.0, true)
		_arrow(p, ship.rotation, 6.0, Color(0.3, 1.0, 0.5))
	var player := get_tree().get_first_node_in_group("player_character") as Node2D
	if player:
		draw_circle(_to_map(player.global_position), 2.5, Color(0.3, 1.0, 0.5), true, -1.0, true)

	# Signaturforklaringen får sin egen baggrund, så et zoomet kort ikke tegner hen over den
	draw_rect(Rect2(map_size, 0, size.x - map_size, size.y), Color(0.12, 0.16, 0.2))
	_draw_legend(Vector2(map_size + 10.0, 10.0))
	draw_string(_font, Vector2(map_size + 10.0, size.y - 34.0), "Scroll: zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.MUTED)
	draw_string(_font, Vector2(map_size + 10.0, size.y - 22.0), "Drag: move the map", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.MUTED)
	draw_string(_font, Vector2(map_size + 10.0, size.y - 10.0), "Right-click: your ship", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.MUTED)


func _draw_legend(pos: Vector2) -> void:
	var rows := [
		[Color(0.3, 1.0, 0.5), "Your ship"],
		[Color(0.55, 0.9, 1.0), "Escort"],
		[Catalog.FACTIONS["aurelia"]["color"], "Aurelia harbor"],
		[Catalog.FACTIONS["valdora"]["color"], "Valdora harbor"],
		[Catalog.FACTIONS["nerath"]["color"], "Nerath harbor"],
		[Catalog.FACTIONS["free"]["color"], "Free Traders"],
		[Catalog.FACTIONS["smugglers"]["color"], "Smugglers (pirate)"],
		[Color(0.35, 0.85, 0.4), "Home Island"],
		[Color(0.75, 0.55, 0.35), "Fishing village"],
		[Color(1.0, 0.85, 0.2), "Treasure chest"],
		[Color(0.1, 0.1, 0.1), "Pirate camp"],
		[Color(0.75, 0.5, 0.3), "Flotsam"],
		[Color(0.95, 0.95, 0.95), "Merchant ship"],
		[Color(0.95, 0.25, 0.2), "Pirate ship"],
		[Color(1.0, 0.85, 0.15), "Quest  ! new  ? hand in"],
		[Color(0.85, 0.2, 0.22), "Castle (kingdom)"],
	]
	draw_string(_font, pos + Vector2(0, 8), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.ACCENT)
	for i in rows.size():
		var y := pos.y + 20.0 + i * 12.0
		draw_circle(Vector2(pos.x + 4, y - 3), 3.0, rows[i][0], true, -1.0, true)
		draw_string(_font, Vector2(pos.x + 12, y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.TEXT)


var _shapes: Dictionary = {} ## Island -> [kyst, indland, lagune] i verdenskoordinater (beregnes én gang)


func _shape(island: Island, which: int) -> PackedVector2Array:
	if not _shapes.has(island):
		var count := 220 if island.radius > 1000.0 else 64
		var all: Array[PackedVector2Array] = []
		for factor in [1.0, 0.6, island.lagoon_size * 0.75]:
			var pts := PackedVector2Array()
			for i in count:
				var a := TAU * i / count
				pts.append(island.global_position + Vector2.from_angle(a) * island.shore_radius(a) * float(factor))
			all.append(pts)
		_shapes[island] = all
	return (_shapes[island] as Array)[which]


func _arrow(p: Vector2, rot: float, length: float, col: Color) -> void:
	var f := Vector2.from_angle(rot)
	var side := f.orthogonal()
	var pts := PackedVector2Array([p + f * length, p - f * length * 0.6 + side * length * 0.6, p - f * length * 0.6 - side * length * 0.6])
	draw_colored_polygon(pts, col)


## Main quest: yellow "!" where a quest waits, "?" where one can be handed in, and a pulsing
## ring on the current target (a boss, a delivery harbor or the treasure).
func _draw_quest_marks(view: Rect2) -> void:
	var mark_col := Color(1.0, 0.85, 0.15)
	for node in get_tree().get_nodes_in_group("harbors"):
		var harbor := node as Harbor
		var mark := Quests.marker_at(harbor.harbor_name)
		if mark == "":
			continue
		var p := _to_map(harbor.global_position)
		# Off the edge of the view: pin it to the border so you can still see which way to sail
		var inner := _map_rect().grow(-10.0)
		var pinned := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		var w := _font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var at := pinned + Vector2(-w * 0.5, -17) # above the harbor's name
		draw_string_outline(_font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.15, 0.1, 0.0, 0.9))
		draw_string(_font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, mark_col)
	var target := Quests.target_position()
	if target != Vector2.INF:
		var tp := _to_map(target)
		if view.has_point(tp):
			var pulse := 6.0 + sin(Time.get_ticks_msec() / 200.0) * 2.0
			draw_arc(tp, pulse, 0.0, TAU, 24, mark_col, 1.5, true)
			draw_line(tp + Vector2(-3, -3), tp + Vector2(3, 3), mark_col, 1.5, true)
			draw_line(tp + Vector2(3, -3), tp + Vector2(-3, 3), mark_col, 1.5, true)


func _text(center: Vector2, text: String, font_size: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(_font, center - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(0, 0, 0, 0.6))
	draw_string(_font, center - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
