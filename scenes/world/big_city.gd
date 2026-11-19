class_name BigCity
extends Node2D
## A big harbor city round a Harbor (added by main.gd): Port Aurel (royal) and Gallows Bay
## (pirate). Uses the harbor's local space: +x points out to sea, x = 0 is the waterfront.
##
## - The stone harbor: a quay along the waterfront, a wide central pier (where you dock, as at
##   any harbor), two side piers, and two breakwater moles that close the basin round, with a
##   lighthouse and a gun battery at their ends. Moles and piers are solid for ships and can be
##   walked on (Game.walkways).
## - The town on land behind it: a main avenue from the quay up to a square with a fountain and
##   market stalls, cross streets, and blocks of houses that are solid (you walk the streets).
## - Life: people and guards in the streets, chimney smoke, ships moored at the quays, ships
##   sailing in and out, rowboats crossing the basin, a lighthouse beam at night.
## - The pirate city is tarred timber with black flags, and it is gloomy: WorldSky darkens the
##   light and adds fog near it (gloom()), with braziers and lanterns burning in the streets.

const RADIUS := 1300.0 ## streaming radius: the city wakes up when you come this close
const LAND_DEPTH := 560.0 ## how far the town reaches inland
const HALF_WIDTH := 400.0
const MOLE_W := 24.0
const BUILDING_LAYER := 8 ## physics layer 4: the captain bumps into houses (PlayerCharacter)
const GLOOM_INNER := 650.0
const GLOOM_OUTER := 1150.0

var harbor: Harbor
var kind := "royal" ## "royal" or "pirate"
var houses: Array[Rect2] = [] ## local rects of the solid houses
var walk_polys: Array[PackedVector2Array] = [] ## local: quay, piers and moles you can walk on
var _moles: Array[PackedVector2Array] = []
var _piers: Array[Rect2] = []
var _streets: Array[Rect2] = []
var _square := Rect2(-330, -95, 150, 190)
var _house_cols: Array[Color] = []
var _stalls: Array = [] ## [pos, colour]
var _gardens: Array[Rect2] = []
var _chimneys: Array[Vector2] = []
var _lamps: Array[Vector2] = []
var _waypoints: Array[Vector2] = []
var _moored: Array[ShipVisual] = []
var _traffic: Array[HarborShip] = []
var _boats: Array = [] ## [pos, target, angle]
var _time := 0.0
var _frame := 0
var _anim: Node2D
var _rng := RandomNumberGenerator.new()
var _walk_aabbs: Array[Rect2] = [] ## global bounding boxes of walk_polys (fast check)


func _ready() -> void:
	add_to_group("big_cities")
	z_index = 1
	_rng.seed = hash(harbor.harbor_name if harbor else name)
	_build_harbor()
	_build_town()
	_build_bodies()
	_build_life()
	Game.walkways.append(self)


func _exit_tree() -> void:
	Game.walkways.erase(self)


# --- Layout -------------------------------------------------------------------

func _build_harbor() -> void:
	# The quay along the waterfront, and the piers (the central one is where you dock)
	walk_polys.append(_rect_poly(Rect2(-34, -HALF_WIDTH + 40, 46, HALF_WIDTH * 2 - 80)))
	_piers = [Rect2(0, -14, Harbor.PIER_LENGTH + 30, 28), Rect2(0, -190, 120, 18), Rect2(0, 172, 120, 18)]
	for p in _piers:
		walk_polys.append(_rect_poly(p))
	# Two breakwaters: out from the shore, then bending in to close the basin
	for side in [-1.0, 1.0]:
		var pts := [Vector2(-20, side * 330), Vector2(300, side * 330), Vector2(430, side * 180)]
		var mole := _thick_path(pts, MOLE_W)
		_moles.append(mole)
		walk_polys.append(mole)


func _build_town() -> void:
	# Streets: the avenue up from the quay, two cross streets and lanes along the quay
	_streets = [Rect2(-LAND_DEPTH, -17, LAND_DEPTH, 34), Rect2(-150, -HALF_WIDTH, 26, HALF_WIDTH * 2),
		Rect2(-430, -HALF_WIDTH, 26, HALF_WIDTH * 2), Rect2(-LAND_DEPTH, -230, LAND_DEPTH - 34, 22),
		Rect2(-LAND_DEPTH, 208, LAND_DEPTH - 34, 22), _square]
	var cols: Array[Color] = [Color(0.72, 0.32, 0.2), Color(0.62, 0.28, 0.18), Color(0.68, 0.42, 0.24), Color(0.5, 0.36, 0.28), Color(0.45, 0.46, 0.55)]
	if kind == "pirate":
		cols = [Color(0.24, 0.2, 0.18), Color(0.32, 0.24, 0.18), Color(0.2, 0.22, 0.24), Color(0.36, 0.28, 0.2)]
	# Warehouses along the quay, then houses in rows filling the blocks between the streets
	for y0 in range(int(-HALF_WIDTH + 50), int(HALF_WIDTH - 50), 70):
		_try_house(Rect2(-100, y0, 52, 56), cols)
	var x := -LAND_DEPTH + 10.0
	while x < -110.0:
		var y := -HALF_WIDTH
		var w := _rng.randf_range(26, 38)
		while y < HALF_WIDTH:
			var h := _rng.randf_range(20, 32)
			_try_house(Rect2(x, y, w, h), cols)
			y += h + _rng.randf_range(6, 12)
		x += w + _rng.randf_range(8, 14)
	# The square: a fountain (or a fire pit) and market stalls round it
	var stall_cols := [Color(0.85, 0.25, 0.2), Color(0.25, 0.45, 0.8), Color(0.9, 0.75, 0.3), Color(0.3, 0.6, 0.35)]
	if kind == "pirate":
		stall_cols = [Color(0.45, 0.15, 0.15), Color(0.25, 0.25, 0.3), Color(0.4, 0.3, 0.15)]
	for i in 10:
		var a := TAU * i / 10.0
		_stalls.append([_square.get_center() + Vector2(cos(a) * 62, sin(a) * 78), stall_cols[i % stall_cols.size()]])
	# Street lamps (braziers in the pirate city), the places people walk between
	for px in [-60.0, -200.0, -310.0, -480.0]:
		for py in [-30.0, 30.0]:
			_lamps.append(Vector2(px, py))
	for p in [Vector2(-140, -240), Vector2(-140, 240), Vector2(-420, -240), Vector2(-420, 240), Vector2(-10, -250), Vector2(-10, 250)]:
		_lamps.append(p)
	for s in _streets:
		for k in 3:
			var p := s.position + Vector2(s.size.x * (k + 0.5) / 3.0, s.size.y * 0.5)
			if Game.is_land(to_global(p)):
				_waypoints.append(p)
	for p in [Vector2(60, 0), Vector2(110, 0), Vector2(40, -180), Vector2(40, 180), Vector2(-10, -120), Vector2(-10, 120)]:
		_waypoints.append(p)


## Adds a house if it is on land and clear of the streets and other houses.
func _try_house(r: Rect2, cols: Array[Color]) -> void:
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		if not Game.is_land(to_global(corner)):
			return
	for s in _streets:
		if s.grow(4.0).intersects(r):
			return
	for h in houses:
		if h.grow(4.0).intersects(r):
			return
	houses.append(r)
	_house_cols.append(cols[_rng.randi() % cols.size()])
	if _rng.randf() < 0.5:
		_chimneys.append(r.position + r.size * Vector2(0.75, 0.3))
	elif _rng.randf() < 0.25 and kind == "royal":
		_gardens.append(Rect2(r.position + Vector2(0, r.size.y + 2), Vector2(r.size.x, 6)))


func _build_bodies() -> void:
	# Houses: solid for the captain (layer 4), not for ships
	var body := StaticBody2D.new()
	body.collision_layer = BUILDING_LAYER
	body.collision_mask = 0
	add_child(body)
	for r in houses:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
	# Moles and piers: solid for ships (layer 1, like islands)
	var stone := StaticBody2D.new()
	stone.collision_layer = 1
	stone.collision_mask = 0
	add_child(stone)
	for m in _moles:
		var c := CollisionPolygon2D.new()
		c.polygon = m
		stone.add_child(c)
	for p in _piers.slice(1):
		var c := CollisionPolygon2D.new()
		c.polygon = _rect_poly(p)
		stone.add_child(c)
	for poly in walk_polys:
		var aabb := Rect2(to_global(poly[0]), Vector2.ZERO)
		for p in poly:
			aabb = aabb.expand(to_global(p))
		_walk_aabbs.append(aabb.grow(2.0))


## True if this global point is on the quay, a pier or a mole (for Game.is_walkable).
func covers(global_pos: Vector2) -> bool:
	for i in walk_polys.size():
		if _walk_aabbs[i].has_point(global_pos) and Geometry2D.is_point_in_polygon(to_local(global_pos), walk_polys[i]):
			return true
	return false


func _build_life() -> void:
	var lamp_col := Color(1.0, 0.55, 0.25) if kind == "pirate" else Color(1.0, 0.8, 0.5)
	for p in _lamps:
		WorldSky.add_lantern(self, p, 90.0 if kind == "pirate" else 70.0, lamp_col, 1.1 if kind == "pirate" else 0.7)
	WorldSky.add_lantern(self, Vector2(430, -180), 220.0, Color(1.0, 0.92, 0.7), 1.2) # the lighthouse
	# Ships moored at the quays and piers
	var spots := [[Vector2(60, -168), 0.0], [Vector2(60, 194), 0.0], [Vector2(70, -214), 0.0], [Vector2(70, 150), 0.0],
		[Vector2(200, -260), 0.4], [Vector2(230, 250), -0.3], [Vector2(40, -330 + 50), PI * 0.5], [Vector2(300, 60), 1.4]]
	var types := ["sloop", "schooner", "fluyt", "caravel", "brig", "galleon"] if kind == "royal" else ["sloop", "cutter", "brig", "brigantine", "longship"]
	for s in spots:
		var v := ShipVisual.new()
		v.position = s[0]
		v.rotation = float(s[1])
		add_child(v)
		v.apply_config(_ship_config(types[_rng.randi() % types.size()]))
		_moored.append(v)
	# Ships sailing in and out, along a loop out of the basin and back
	for i in 2:
		var hs := HarborShip.new()
		hs.city = self
		hs.path = [Vector2(150, 90 - i * 180), Vector2(380, 0 - i * 40), Vector2(700, -160 + i * 320), Vector2(1100, -40 + i * 80),
			Vector2(700, 200 - i * 400), Vector2(380, 40 - i * 80)]
		hs.at = i * 3
		add_child(hs)
		hs.setup(_ship_config(types[(i + 2) % types.size()]))
		_traffic.append(hs)
	for i in 4:
		_boats.append([Vector2(_rng.randf_range(60, 350), _rng.randf_range(-250, 250)), Vector2.ZERO, 0.0])
	_anim = CityAnim.new()
	_anim.city = self
	add_child(_anim)
	var life := CityLife.new()
	life.city = self
	add_child(life)


func _ship_config(type: String) -> Dictionary:
	var cfg := Game.new_ship_config(type)
	if kind == "pirate":
		cfg["sail"] = "black"
		cfg["hull"] = "dark"
		cfg["decorations"] = {"flag": true, "lanterns": true}
	else:
		cfg["sail"] = ["canvas", "sand", "ocean", "crimson"][_rng.randi() % 4]
		cfg["decorations"] = {"flag": true}
		cfg["flag"] = "red"
	return cfg


# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	for i in _moored.size(): # bobbing at the quay, sails furled (a few each frame: cheaper)
		if (i + _frame) % 4 == 0:
			_moored[i].update_motion(0.0, 0.0, 0.0, delta * 4.0)
	for b in _boats:
		var to: Vector2 = (b[1] as Vector2) - (b[0] as Vector2)
		if to.length() < 4.0 or b[1] == Vector2.ZERO:
			b[1] = Vector2(_rng.randf_range(60, 380), _rng.randf_range(-280, 280))
		else:
			b[2] = lerp_angle(float(b[2]), to.angle(), 1.0 - exp(-2.0 * delta))
			b[0] = (b[0] as Vector2) + Vector2.from_angle(float(b[2])) * 14.0 * delta
	if _frame % 2 == 0:
		_anim.queue_redraw() # only the moving parts, every other frame; the town itself was drawn once


## How gloomy it is round here (0 = not at all, 1 = deep in the pirate city). Read by WorldSky.
func gloom(focus: Vector2) -> float:
	if kind != "pirate" or not is_inside_tree():
		return 0.0
	var d := focus.distance_to(to_global(Vector2(-200, 0)))
	return 1.0 - smoothstep(GLOOM_INNER, GLOOM_OUTER, d)


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var pirate := kind == "pirate"
	var stone := Color(0.42, 0.34, 0.26) if pirate else Color(0.66, 0.63, 0.57)
	var stone_dark := stone.darkened(0.3)
	var paving := Color(0.36, 0.3, 0.24) if pirate else Color(0.72, 0.68, 0.6)
	# Streets and the square (cobbles)
	for s in _streets:
		draw_rect(s, paving)
	for i in 260:
		var s: Rect2 = _streets[i % _streets.size()]
		var p := s.position + Vector2(fmod(i * 37.3, s.size.x), fmod(i * 19.7, s.size.y))
		draw_rect(Rect2(p, Vector2(2.2, 1.6)), paving.darkened(0.12)) # a cobble
	draw_rect(_square, paving.lightened(0.06))
	# Moles, quay and piers: stone with an edge and blocks (tarred planks in the pirate city)
	for m in _moles:
		draw_colored_polygon(_offset(m, Vector2(3, 4)), Color(0, 0, 0, 0.22))
		draw_colored_polygon(m, stone)
		draw_polyline(m + PackedVector2Array([m[0]]), stone_dark, 1.2, true)
	draw_rect(Rect2(-34, -HALF_WIDTH + 40, 46, HALF_WIDTH * 2 - 80), stone)
	draw_line(Vector2(12, -HALF_WIDTH + 40), Vector2(12, HALF_WIDTH - 40), stone_dark, 2.0) # quay edge
	for p in _piers:
		draw_rect(Rect2(p.position + Vector2(3, 4), p.size), Color(0, 0, 0, 0.2))
		draw_rect(p, stone.lightened(0.05))
		for k in range(int(p.position.x) + 8, int(p.end.x), 12):
			draw_line(Vector2(k, p.position.y), Vector2(k, p.end.y), stone_dark, 0.6)
	# Bollards along the quay
	for y in range(int(-HALF_WIDTH + 60), int(HALF_WIDTH - 60), 40):
		draw_circle(Vector2(8, y), 2.0, Color(0.15, 0.13, 0.12), true, -1.0, false)
	# Gun battery at the end of the south mole, lighthouse at the end of the north one
	var bat := Vector2(430, 180)
	draw_circle(bat, 22, stone.darkened(0.1), true, -1.0, false)
	for k in 4:
		var a := -0.6 + k * 0.4
		draw_line(bat + Vector2.from_angle(a) * 10, bat + Vector2.from_angle(a) * 26, Color(0.12, 0.12, 0.14), 3.0, true)
	var lh := Vector2(430, -180)
	draw_circle(lh + Vector2(3, 4), 15, Color(0, 0, 0, 0.25), true, -1.0, false)
	draw_circle(lh, 15, Color(0.92, 0.9, 0.85) if not pirate else Color(0.45, 0.4, 0.36), true, -1.0, false)
	draw_arc(lh, 15, 0, TAU, 24, Color(0.75, 0.2, 0.18), 3.0, true)
	draw_circle(lh, 7, Color(1.0, 0.9, 0.55), true, -1.0, false)
	# Gardens, houses with shadows, roofs and ridges
	for g in _gardens:
		draw_rect(g, Color(0.42, 0.58, 0.3))
	for i in houses.size():
		var r := houses[i]
		var roof := _house_cols[i]
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r.grow(1.0), Color(0.85, 0.8, 0.7) if not pirate else Color(0.15, 0.12, 0.1))
		draw_rect(r, roof)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), roof.lightened(0.1))
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), roof.darkened(0.35), 1.2)
		if pirate and i % 3 == 0: # patched, sagging roofs
			draw_rect(Rect2(r.position + r.size * 0.2, r.size * 0.25), roof.darkened(0.25))
	for c in _chimneys:
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(0.4, 0.32, 0.28))
	for st in _stalls:
		var p: Vector2 = st[0]
		var col: Color = st[1]
		draw_rect(Rect2(p + Vector2(-7, -5) + Vector2(2, 3), Vector2(14, 10)), Color(0, 0, 0, 0.2))
		for k in 4:
			draw_rect(Rect2(p + Vector2(-7 + k * 3.5, -5), Vector2(3.5, 10)), col if k % 2 == 0 else Color(0.95, 0.92, 0.85))
## The parts that move, drawn every frame by a child node (CityAnim): the lighthouse beam, the
## fountain or fire pit, the lamps, the quay banners and the rowboats. Everything else is drawn
## once in _draw, so the city costs almost nothing per frame.
func _draw_animated(ci: CanvasItem) -> void:
	var pirate := kind == "pirate"
	var lh := Vector2(430, -180)
	var mid := _square.get_center()
	if Game.night > 0.2: # a slow beam sweeping over the water
		var a := _time * 0.6
		var beam := PackedVector2Array([lh, lh + Vector2.from_angle(a - 0.12) * 700, lh + Vector2.from_angle(a + 0.12) * 700])
		ci.draw_colored_polygon(beam, Color(1.0, 0.95, 0.75, 0.12 * Game.night))
	# The square: a fountain (royal) or a fire pit with a gallows (pirate)
	if pirate:
		ci.draw_circle(mid, 14, Color(0.25, 0.2, 0.17), true, -1.0, false)
		var flick := 0.8 + 0.2 * sin(_time * 11.0)
		ci.draw_circle(mid, 9 * flick, Color(1.0, 0.45, 0.15, 0.9), true, -1.0, false)
		ci.draw_circle(mid, 5 * flick, Color(1.0, 0.85, 0.4), true, -1.0, false)
		var g := mid + Vector2(0, -60)
		ci.draw_line(g, g + Vector2(0, -24), Color(0.3, 0.2, 0.12), 2.5, true)
		ci.draw_line(g + Vector2(0, -24), g + Vector2(14, -24), Color(0.3, 0.2, 0.12), 2.5, true)
		ci.draw_line(g + Vector2(12, -24), g + Vector2(12, -16), Color(0.5, 0.45, 0.35), 0.8, true)
	else:
		ci.draw_circle(mid, 22, Color(0.6, 0.58, 0.55), true, -1.0, false)
		ci.draw_circle(mid, 17, Color(0.3, 0.55, 0.72), true, -1.0, false)
		ci.draw_circle(mid, 5, Color(0.75, 0.72, 0.68), true, -1.0, false)
		for k in 6: # splashes
			var a := TAU * k / 6.0 + _time
			ci.draw_circle(mid + Vector2.from_angle(a) * (7 + sin(_time * 3.0 + k) * 2.0), 1.4, Color(0.85, 0.95, 1.0, 0.8), true, -1.0, false)
	# Lamps (braziers in the pirate city)
	for p in _lamps:
		if pirate:
			var f := 0.75 + 0.25 * sin(_time * 9.0 + p.x)
			ci.draw_circle(p, 3.5, Color(0.2, 0.17, 0.15), true, -1.0, false)
			ci.draw_circle(p, 2.5 * f, Color(1.0, 0.55, 0.2), true, -1.0, false)
		else:
			ci.draw_circle(p, 1.8, Color(0.2, 0.2, 0.22), true, -1.0, false)
			ci.draw_circle(p, 1.1, Color(1.0, 0.9, 0.6, 0.4 + 0.6 * Game.night), true, -1.0, false)
	# Banners on the quay: the kingdom's colours, or black flags
	for y in [-120.0, -60.0, 60.0, 120.0]:
		var base := Vector2(-14, y)
		ci.draw_line(base, base + Vector2(0, -16), Color(0.3, 0.22, 0.14), 1.2, true)
		var wave := sin(_time * 3.0 + y) * 1.5
		var flag_col := Color(0.08, 0.08, 0.08) if pirate else Color(0.85, 0.2, 0.22)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -16), base + Vector2(10, -14 + wave), base + Vector2(0, -10)]), flag_col)
	# Rowboats crossing the basin
	for b in _boats:
		var p: Vector2 = b[0]
		var a: float = b[2]
		ci.draw_set_transform(p, a)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(2, -2.5), Vector2(-5, -2.2), Vector2(-5, 2.2), Vector2(2, 2.5)]), Color(0.45, 0.3, 0.18))
		var oar := sin(_time * 6.0) * 2.0
		ci.draw_line(Vector2(0, -2), Vector2(-1 + oar, -6), Color(0.6, 0.45, 0.3), 0.7, true)
		ci.draw_line(Vector2(0, 2), Vector2(-1 + oar, 6), Color(0.6, 0.45, 0.3), 0.7, true)
		ci.draw_circle(Vector2(-1, 0), 1.3, Color(0.75, 0.3, 0.25), true, -1.0, false)
		ci.draw_set_transform(Vector2.ZERO)




# --- Small helpers -------------------------------------------------------------

static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A polygon of the given width round a path of points (a mole).
static func _thick_path(pts: Array, width: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var n := (b - a).normalized().orthogonal() * width * 0.5
		left.append((pts[i] as Vector2) + n)
		right.append((pts[i] as Vector2) - n)
	right.reverse()
	left.append_array(right)
	return left


static func _offset(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out


## Draws the moving parts of the city every frame (see BigCity._draw_animated).
class CityAnim extends Node2D:
	var city: BigCity

	func _draw() -> void:
		city._draw_animated(self)


## People and guards walking the streets, and smoke from the chimneys (drawn over the houses).
class CityLife extends Node2D:
	var city: BigCity
	var _people: Array = [] ## [pos, target, colour, speed, guard]
	var _smoke: Array = []
	var _smoke_timer := 0.0
	var _time := 0.0

	func _ready() -> void:
		z_index = 2
		var cloth := [Color(0.75, 0.3, 0.25), Color(0.3, 0.45, 0.7), Color(0.85, 0.75, 0.4), Color(0.4, 0.6, 0.35), Color(0.6, 0.4, 0.6), Color(0.9, 0.9, 0.85)]
		if city.kind == "pirate":
			cloth = [Color(0.25, 0.22, 0.2), Color(0.45, 0.15, 0.15), Color(0.3, 0.3, 0.35), Color(0.5, 0.4, 0.25)]
		for i in 26:
			var start: Vector2 = city._waypoints.pick_random()
			_people.append([start, city._waypoints.pick_random(), cloth[i % cloth.size()], randf_range(9.0, 16.0), i < 6])

	func _process(delta: float) -> void:
		_time += delta
		for p in _people:
			var to: Vector2 = p[1] - p[0]
			if to.length() < 2.0:
				p[1] = city._waypoints.pick_random()
			else:
				# Walk along the streets: first across, then along (no cutting through houses)
				var step: Vector2 = Vector2(signf(to.x), 0.0) if absf(to.x) > 1.5 and absf(to.y) > 1.5 and int(p[3] * 10) % 2 == 0 else to.normalized()
				p[0] += step * float(p[3]) * delta
		_smoke_timer -= delta
		if _smoke_timer <= 0.0 and not city._chimneys.is_empty():
			_smoke_timer = 0.25
			_smoke.append([city._chimneys.pick_random(), 0.0])
		for sm in _smoke:
			sm[1] += delta
		_smoke = _smoke.filter(func(sm: Array) -> bool: return sm[1] < 3.0)
		if Engine.get_process_frames() % 2 == 1: # every other frame (on the frames the animation skips)
			queue_redraw()

	func _draw() -> void:
		var guard_col := Color(0.85, 0.2, 0.22) if city.kind == "royal" else Color(0.15, 0.15, 0.15)
		for sm in _smoke:
			var age: float = sm[1]
			var pos: Vector2 = sm[0] + Vector2(-age * 6.0 + sin(age * 2.0) * 2.0, -age * 9.0)
			draw_circle(pos, 2.0 + age * 2.2, Color(0.8, 0.8, 0.8, 0.3 * (1.0 - age / 3.0)), true, -1.0, false)
		for p in _people:
			var pos: Vector2 = p[0]
			var bob := sin(_time * 10.0 + pos.x) * 0.4
			draw_circle(pos + Vector2(1, 1.5), 2.4, Color(0, 0, 0, 0.2), true, -1.0, false)
			draw_circle(pos, 2.4, guard_col if p[4] else p[2], true, -1.0, false)
			draw_circle(pos + Vector2(0, bob - 0.4), 1.3, Color(0.95, 0.8, 0.62), true, -1.0, false)
			if p[4]: # a guard's spear
				draw_line(pos + Vector2(2.5, 0), pos + Vector2(3.5, -7), Color(0.5, 0.35, 0.2), 0.8, true)


## A ship sailing in and out of the harbor along a loop (just for the look: no fighting).
class HarborShip extends Node2D:
	var city: BigCity
	var path: Array = []
	var at := 0
	var _visual: ShipVisual
	var _turn := 0.0
	const SPEED := 32.0

	func setup(config: Dictionary) -> void:
		_visual = ShipVisual.new()
		add_child(_visual)
		_visual.apply_config(config)
		position = path[at % path.size()]

	func _process(delta: float) -> void:
		if _visual == null:
			return
		var target: Vector2 = path[(at + 1) % path.size()]
		var to := target - position
		if to.length() < 20.0:
			at += 1
			return
		var before := rotation
		rotation = lerp_angle(rotation, to.angle(), 1.0 - exp(-0.8 * delta))
		_turn = angle_difference(before, rotation) / maxf(delta, 0.001)
		position += Vector2.from_angle(rotation) * SPEED * delta
		_visual.update_motion(SPEED, 1.0, _turn, delta)
