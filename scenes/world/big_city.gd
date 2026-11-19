class_name BigCity
extends Node2D
## Lanternmouth, the canal city (added by main.gd on its own big island near Sunhaven).
## Uses its own local space: +x points out to sea, x = 0 is the straight waterfront that the
## island is cut along (Island.front_dist), and the island's middle lies at (-FRONT_DIST, 0).
##
## - By the sea: a stone quay along the whole waterfront, a central pier (where you dock, as at
##   any harbor), two side piers and two breakwater moles that close the basin, with a lighthouse.
##   Moles and side piers are solid for ships; quay, piers and moles can be walked on (Game.walkways).
## - The canal quarter behind the quay: two canals run inland from the basin and a third joins
##   them, with promenades, bridges, streets and blocks of brick houses (style: seen from above,
##   terracotta and slate roofs over dark brick walls). Houses and canal water are solid for the
##   captain (BUILDING_LAYER); you cross the canals on the bridges.
## - The old town on the hill behind it: a ring wall with one gate up a stair from Lantern Square,
##   a ring lane and crooked old houses round the Old Market at the top.
## - The Chandlery on the quay is a real shop (F at its door opens the harbor menu); the saloons
##   are for the look and the noise. Lanterns on walls and posts glow at night (LanternGlow).
## - Life: ships moored and ships coming and going, rowboats, canal barges, townsfolk, smoke.
##
## Speed: the static town is drawn once (_draw and the chunk nodes, which Godot skips when they
## are off screen); only the moving parts are redrawn, every other frame.

const ISLAND_RADIUS := 1700.0 ## the city's island (main.gd places it)
const FRONT_DIST := 500.0 ## from the island's middle to the straight waterfront
const RADIUS := 3600.0 ## streaming radius: the city wakes up when you come this close
const HW := 1050.0 ## half the length of the waterfront quay
const BUILDING_LAYER := 8 ## physics layer 4: the captain bumps into houses and canal water
const QUAY_X := -70.0 ## the quay runs from here to the water's edge
const CANAL_Y := 420.0 ## the two canals from the basin run inland at y = -CANAL_Y and +CANAL_Y
const CANAL_HALF := 32.0
const PROM := 34.0 ## width of the promenades along the canals
const CANAL_END := -940.0
const CROSS_X := -620.0 ## the canal that joins the other two
const STREET_A := -300.0
const STREET_B := -820.0
const STREET_HALF := 32.0
const LANE_Y := 800.0
const LANE_HALF := 28.0
const BACK_X := -990.0 ## the back lane at the foot of the hill (x = BACK_X .. BACK_X + 50)
const SQUARE := Rect2(-1130, -150, 140, 300) ## Lantern Square, at the foot of the stair
const HILL := Vector2(-1500, 0) ## the middle of the old town
const PLATEAU_R := 290.0 ## the ring wall
const SLOPE_R := 420.0
const RING_R := 175.0 ## the ring lane
const RING_HALF := 22.0
const TOP_R := 70.0 ## the Old Market at the top
const GATE_HALF := 26.0
const MOLE_W := 40.0
const LIGHTHOUSE := Vector2(480, -330)
const BEACON := Vector2(480, 330)

const ROOFS: Array[Color] = [Color(0.58, 0.29, 0.19), Color(0.5, 0.24, 0.16), Color(0.63, 0.35, 0.21),
	Color(0.45, 0.27, 0.19), Color(0.34, 0.32, 0.34), Color(0.54, 0.31, 0.24)]
const OLD_ROOFS: Array[Color] = [Color(0.37, 0.35, 0.37), Color(0.42, 0.3, 0.22), Color(0.5, 0.26, 0.18), Color(0.39, 0.37, 0.31)]
const WALLS: Array[Color] = [Color(0.62, 0.34, 0.25), Color(0.52, 0.29, 0.22), Color(0.66, 0.48, 0.34), Color(0.48, 0.33, 0.27)]
const WATER := Color(0.16, 0.29, 0.32)
const STONE := Color(0.5, 0.47, 0.42)
const LAMP := Color(1.0, 0.72, 0.4)

var island: Island
var harbor: Harbor
var houses: Array[House] = []
var streets: Array[Rect2] = [] ## cobbled streets and promenades (local rects)
var canals: Array[Rect2] = [] ## canal water
var bridges: Array[Rect2] = [] ## over the canals (also how you get across)
var walk_polys: Array[PackedVector2Array] = [] ## local: quay, piers and moles you can walk on
var doors: Array = [] ## [local spot in front of the door, "shop" or "saloon", name]
var _moles: Array[PackedVector2Array] = []
var _piers: Array[Rect2] = []
var _land: PackedVector2Array ## the island's coast in city space (a little inside the beach)
var _ground: Array[PackedVector2Array] = [] ## the town's paved ground, clipped to the land
var _street_polys: Array[PackedVector2Array] = []
var _wall_lanterns: Array = [] ## [position on the wall, outward normal]
var _posts: Array[Vector2] = [] ## lamp posts
var _signs: Array = [] ## [position on the wall, outward normal, icon, board colour]
var _awnings: Array = [] ## [position on the wall, outward normal, width, colour]
var _plants: Array = [] ## [position, colour]
var _laundry: Array = [] ## [from, to]
var _boards: Array = [] ## [centre, text, kind] name boards over the shop and saloon doors
var _props: Array = [] ## [position, kind] barrels, crates, benches by the doors
var _trees: Array = [] ## [position, size, shade]
var _stalls: Array = [] ## [position, colour]
var _cranes: Array[Vector2] = []
var _chimneys: Array[Vector2] = []
var _routes: Array[PackedVector2Array] = [] ## where the townsfolk walk (along the streets)
var _barge_routes: Array[PackedVector2Array] = []
var _patrons: Array[Vector2] = [] ## people loitering by the saloon doors
var _moored: Array[ShipVisual] = []
var _boats: Array = [] ## [pos, target, angle]
var _time := 0.0
var _frame := 0
var _cobbles: ImageTexture
var _flags: ImageTexture
var _bricks: ImageTexture
var _roof_h: ImageTexture ## roof tiles in rows along x
var _roof_v: ImageTexture ## roof tiles in rows along y
var _details: Array[Node2D] = []
var _anim: Node2D
var _glow: Node2D
var _rng := RandomNumberGenerator.new()
var _walk_aabbs: Array[Rect2] = [] ## global bounding boxes of walk_polys (fast check)


## One house. Seen from above: dark brick walls, and a roof inset a little from them.
class House:
	var c := Vector2.ZERO ## centre (city space)
	var size := Vector2.ZERO ## x = along the street, y = depth (house space)
	var rot := 0.0
	var roof := Color.WHITE
	var wall := Color.WHITE
	var kind := 0 ## 0 gable, 1 hip, 2 courtyard, 3 flat with a roof terrace
	var chimney := Vector2.INF ## house space
	var old := false ## the old town: mossy and crooked
	var special := "" ## "shop" or "saloon"

	func rect() -> Rect2:
		return Rect2(-size * 0.5, size)

	func aabb() -> Rect2:
		var r := Rect2(c, Vector2.ZERO)
		for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			r = r.expand(c + (size * 0.5 * p).rotated(rot))
		return r


## The island seed (shape) whose sides and back are fullest, so the town and the hill fit.
## Same shape formula as Island.shore_radius (coast_detail 0).
static func roundest_seed(front_angle: float) -> int:
	var best := 1
	var best_min := -INF
	for s in range(1, 400):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var p := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var lowest := INF
		for k in 48:
			var a := TAU * k / 48.0
			if cos(a - front_angle) > 0.3:
				continue # the front is cut straight anyway
			var r := 1.0 + 0.16 * sin(2.0 * a + p.x) + 0.10 * sin(3.0 * a + p.y) + 0.05 * sin(5.0 * a + p.z)
			lowest = minf(lowest, r)
		if lowest > best_min:
			best_min = lowest
			best = s
	return best


func _ready() -> void:
	add_to_group("big_cities")
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED # the stone, brick and roof tiles repeat
	_rng.seed = hash(Catalog.CITY["name"])
	# Sit on the island's straight waterfront, and put the harbor (the dock) there too
	var out := Vector2.from_angle(island.front_angle)
	global_position = island.global_position + out * FRONT_DIST
	global_rotation = island.front_angle
	harbor.global_transform = global_transform
	for p in island.land_shape():
		_land.append(to_local(island.to_global(p * 0.985)))
	_cobbles = _stone_tile(Color(0.43, 0.39, 0.34), 9, 6, 0.0)
	_flags = _stone_tile(Color(0.47, 0.44, 0.4), 30, 20, 0.5)
	_bricks = _brick_tile()
	_roof_h = _roof_tile(false)
	_roof_v = _roof_tile(true)
	_build_harbor()
	_build_quarter()
	_build_hill()
	_build_outskirts()
	_build_bodies()
	_build_life()
	Game.walkways.append(self)


func _exit_tree() -> void:
	Game.walkways.erase(self)


# --- Layout -------------------------------------------------------------------

func _build_harbor() -> void:
	walk_polys.append(_rect_poly(_quay()))
	# The central pier keeps its length: the harbor's berth is at its end (Harbor.dock_position)
	_piers = [Rect2(0, -24, Harbor.PIER_LENGTH + 30, 48), Rect2(0, -782, 200, 44), Rect2(0, 738, 200, 44)]
	for p in _piers:
		walk_polys.append(_rect_poly(p))
	for side in [-1.0, 1.0]:
		var mole := _thick_path([Vector2(-20, side * HW), Vector2(330, side * HW), Vector2(480, side * 330)], MOLE_W)
		_moles.append(mole)
		walk_polys.append(mole)
	_cranes = [Vector2(-30, -620), Vector2(-30, 560), Vector2(-30, 230)]


func _build_quarter() -> void:
	# The canals: two from the basin inland, and the cross canal that joins them
	for s in [-1.0, 1.0]:
		canals.append(Rect2(CANAL_END, s * CANAL_Y - CANAL_HALF, -CANAL_END, CANAL_HALF * 2))
	canals.append(Rect2(CROSS_X - CANAL_HALF, -CANAL_Y + CANAL_HALF, CANAL_HALF * 2, (CANAL_Y - CANAL_HALF) * 2))
	# Streets: the avenue up from the quay, cross streets, promenades along the canals, lanes
	var inland := BACK_X + 50.0
	streets.append(Rect2(BACK_X, -40, QUAY_X - BACK_X, 80)) # the avenue
	for x in [STREET_A, STREET_B]:
		streets.append(Rect2(x - STREET_HALF, -HW, STREET_HALF * 2, HW * 2))
	streets.append(Rect2(BACK_X, -HW, 50, HW * 2)) # the back lane
	for s in [-1.0, 1.0]:
		var y0: float = s * CANAL_Y
		streets.append(Rect2(inland, y0 - CANAL_HALF - PROM, QUAY_X - inland, PROM)) # promenades
		streets.append(Rect2(inland, y0 + CANAL_HALF, QUAY_X - inland, PROM))
		streets.append(Rect2(inland, s * LANE_Y - LANE_HALF, QUAY_X - inland, LANE_HALF * 2))
	# Along the cross canal: promenades, and a street where the canal ends
	streets.append(Rect2(CROSS_X - CANAL_HALF - PROM, -HW, PROM * 2 + CANAL_HALF * 2, HW - CANAL_Y - CANAL_HALF))
	streets.append(Rect2(CROSS_X - CANAL_HALF - PROM, CANAL_Y + CANAL_HALF, PROM * 2 + CANAL_HALF * 2, HW - CANAL_Y - CANAL_HALF))
	for dx in [-CANAL_HALF - PROM, CANAL_HALF]:
		streets.append(Rect2(CROSS_X + dx, -CANAL_Y + CANAL_HALF, PROM, (CANAL_Y - CANAL_HALF) * 2))
	streets.append(SQUARE)
	streets.append(Rect2(SQUARE.position.x - 92, -GATE_HALF, 92, GATE_HALF * 2)) # the stair up the hill
	# Bridges: the quay over the canal mouths, the streets over the canals, footbridges
	for s in [-1.0, 1.0]:
		var y0: float = s * CANAL_Y - CANAL_HALF
		bridges.append(Rect2(QUAY_X, y0, -QUAY_X, CANAL_HALF * 2))
		for x in [STREET_A, STREET_B]:
			bridges.append(Rect2(x - STREET_HALF, y0, STREET_HALF * 2, CANAL_HALF * 2))
		var py: float = (CANAL_Y - CANAL_HALF - PROM) * s if s > 0.0 else -CANAL_Y + CANAL_HALF
		bridges.append(Rect2(CROSS_X - CANAL_HALF, py, CANAL_HALF * 2, PROM)) # the inner promenades
		bridges.append(Rect2(CROSS_X - CANAL_HALF, s * 220.0 - 18.0, CANAL_HALF * 2, 36)) # footbridges
	bridges.append(Rect2(CROSS_X - CANAL_HALF, -40, CANAL_HALF * 2, 80)) # the avenue
	for r in streets:
		_street_polys.append_array(_clip_land(_rect_poly(r)))
	_ground = _clip_land(_rect_poly(Rect2(BACK_X, -HW - 20, -BACK_X, HW * 2 + 40)))
	_ground.append_array(_clip_land(_rect_poly(SQUARE.grow(30))))
	# The shop and the saloons first, then houses block by block, their fronts on the streets
	_special(Rect2(-205, -160, 120, 112), "shop", Catalog.CITY["shop"], Vector2.DOWN, Color(0.22, 0.42, 0.3))
	_special(Rect2(-215, 48, 130, 110), "saloon", Catalog.CITY["saloons"][0], Vector2.UP, Color(0.55, 0.2, 0.16))
	_special(Rect2(-520, -600, 140, 108), "saloon", Catalog.CITY["saloons"][1], Vector2.DOWN, Color(0.3, 0.26, 0.4))
	var xs := [BACK_X + 50.0, STREET_B - STREET_HALF, STREET_B + STREET_HALF, CROSS_X - CANAL_HALF - PROM,
		CROSS_X + CANAL_HALF + PROM, STREET_A - STREET_HALF, STREET_A + STREET_HALF, QUAY_X]
	var ys := [-HW, -LANE_Y - LANE_HALF, -LANE_Y + LANE_HALF, -CANAL_Y - CANAL_HALF - PROM, -CANAL_Y + CANAL_HALF + PROM, -40.0,
		40.0, CANAL_Y - CANAL_HALF - PROM, CANAL_Y + CANAL_HALF + PROM, LANE_Y - LANE_HALF, LANE_Y + LANE_HALF, HW]
	for bx in range(0, xs.size() - 1, 2):
		for by in range(0, ys.size() - 1, 2):
			_fill_block(Rect2(xs[bx], ys[by], xs[bx + 1] - xs[bx], ys[by + 1] - ys[by]))
	_decorate_walls()
	# Lamp posts along the canals, the quay, the avenue and round the square
	for s in [-1.0, 1.0]:
		for x in range(-130, int(CANAL_END) + 40, -150):
			_posts.append(Vector2(x, s * (CANAL_Y + CANAL_HALF + 5)))
			_posts.append(Vector2(x - 75, s * (CANAL_Y - CANAL_HALF - 5)))
		for y in range(-140, -int(CANAL_Y) + 40, -130):
			_posts.append(Vector2(CROSS_X + s * (CANAL_HALF + 5), y * -s))
	for y in range(int(-HW) + 80, int(HW) - 40, 170):
		_posts.append(Vector2(QUAY_X + 6, y))
	for x in range(-150, int(BACK_X) + 40, -170):
		_posts.append(Vector2(x, -35))
		_posts.append(Vector2(x - 85, 35))
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_posts.append(SQUARE.get_center() + c * SQUARE.size * 0.44)
	var stall_cols := [Color(0.6, 0.22, 0.16), Color(0.22, 0.32, 0.5), Color(0.62, 0.5, 0.22), Color(0.26, 0.42, 0.28)]
	for i in 8:
		var y := SQUARE.position.y + 30.0 + i * 34.0
		_stalls.append([Vector2(SQUARE.position.x + 18.0 if i % 2 == 0 else SQUARE.end.x - 18.0, y), stall_cols[i % stall_cols.size()]])
	# Where the townsfolk walk
	_routes.append(PackedVector2Array([Vector2(-35, -HW + 40), Vector2(-35, HW - 40)]))
	_routes.append(PackedVector2Array([Vector2(-90, 0), Vector2(BACK_X + 25, 0)]))
	for x in [STREET_A, STREET_B, BACK_X + 25.0]:
		_routes.append(PackedVector2Array([Vector2(x, -HW + 60), Vector2(x, HW - 60)]))
	for s in [-1.0, 1.0]:
		for y in [s * CANAL_Y - CANAL_HALF - PROM * 0.5, s * CANAL_Y + CANAL_HALF + PROM * 0.5, s * LANE_Y]:
			_routes.append(PackedVector2Array([Vector2(-90, y), Vector2(BACK_X + 30, y)]))
	for x in [CROSS_X - CANAL_HALF - PROM * 0.5, CROSS_X + CANAL_HALF + PROM * 0.5]:
		_routes.append(PackedVector2Array([Vector2(x, -CANAL_Y + CANAL_HALF + 8), Vector2(x, CANAL_Y - CANAL_HALF - 8)]))
	for s in [-1.0, 1.0]:
		_barge_routes.append(PackedVector2Array([Vector2(-110, s * CANAL_Y), Vector2(CANAL_END + 40, s * CANAL_Y)]))
	_barge_routes.append(PackedVector2Array([Vector2(CROSS_X, -CANAL_Y + 40), Vector2(CROSS_X, CANAL_Y - 40)]))


## A shop or saloon: a bigger house with its door on the street, a name board and props.
func _special(r: Rect2, what: String, label: String, front: Vector2, board: Color) -> void:
	var h := House.new()
	h.c = r.get_center()
	h.size = r.size
	h.roof = Color(0.52, 0.26, 0.17) if what == "saloon" else Color(0.35, 0.33, 0.35)
	h.wall = WALLS[0]
	h.kind = 1
	h.special = what
	h.chimney = Vector2(r.size.x * 0.3, -r.size.y * 0.25)
	houses.append(h)
	var door := h.c + front * (r.size.y * 0.5)
	doors.append([door + front * 16.0, what, label])
	_boards.append([door - front * 4.0, label, what]) # on the wall over the door
	_awnings.append([door - front.orthogonal() * 34.0, front, 30.0, board])
	_wall_lanterns.append([door + front.orthogonal() * 24.0, front])
	_wall_lanterns.append([door - front.orthogonal() * 24.0, front])
	var side := front.orthogonal()
	if what == "saloon":
		_signs.append([door + side * 44.0, front, "mug", Color(0.5, 0.34, 0.2)])
		_props.append([door + front * 12.0 + side * 52.0, "barrel"])
		_props.append([door + front * 12.0 + side * 60.0, "barrel"])
		_props.append([door + front * 10.0 - side * 50.0, "bench"])
		for k in 3:
			_patrons.append(door + front * _rng.randf_range(18, 30) + side * _rng.randf_range(-40, -20))
	else:
		_signs.append([door + side * 44.0, front, "coin", Color(0.4, 0.32, 0.18)])
		_props.append([door + front * 12.0 + side * 52.0, "crates"])
		_props.append([door + front * 12.0 - side * 54.0, "rope"])


## Fills a block between streets with rows of houses, packed close like an old town: each row
## is split into houses that fill its width, with only narrow alleys between them and the rows.
func _fill_block(b: Rect2) -> void:
	var y := b.position.y + 4.0
	while y < b.end.y - 30.0:
		var depth := _rng.randf_range(44, 66)
		if b.end.y - 4.0 - (y + depth) < 34.0:
			depth = b.end.y - 4.0 - y # the last row sits flush with the street below
		var width := b.size.x - 8.0
		var count := maxi(1, roundi(width / _rng.randf_range(62.0, 90.0)))
		var gaps: Array[float] = []
		var free := width
		for k in count - 1:
			gaps.append(_rng.randf_range(2.0, 6.0))
			free -= gaps[k]
		# Uneven widths that add up to the row
		var weights: Array[float] = []
		var total := 0.0
		for k in count:
			weights.append(_rng.randf_range(0.75, 1.25))
			total += weights[k]
		var x := b.position.x + 4.0
		for k in count:
			var w := free * weights[k] / total
			_try_house(Rect2(x, y, w, depth))
			x += w + (gaps[k] if k < gaps.size() else 0.0)
		y += depth + _rng.randf_range(2.0, 8.0)


## Adds a house if it is on land and clear of the streets, canals and other houses.
func _try_house(r: Rect2) -> void:
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		if not Geometry2D.is_point_in_polygon(corner, _land):
			return
	for s in streets:
		if s.grow(3.0).intersects(r):
			return
	for c in canals:
		if c.grow(6.0).intersects(r):
			return
	for h in houses:
		if h.aabb().grow(1.0).intersects(r):
			return
	var h := House.new()
	h.c = r.get_center()
	h.size = r.size
	h.roof = ROOFS[_rng.randi() % ROOFS.size()]
	h.wall = WALLS[_rng.randi() % WALLS.size()]
	var roll := _rng.randf()
	h.kind = 0 if roll < 0.5 else (1 if roll < 0.8 else (2 if r.size.x > 70.0 and r.size.y > 58.0 else 3))
	if _rng.randf() < 0.6:
		h.chimney = Vector2(r.size.x * _rng.randf_range(-0.3, 0.3), r.size.y * (-0.3 if _rng.randf() < 0.5 else 0.3))
	houses.append(h)


## Lanterns on iron arms, hanging signs, awnings, flower pots and laundry lines on the walls
## that face a street.
func _decorate_walls() -> void:
	var icons := ["mug", "bread", "fish", "anchor", "key", "boot", "candle", "barrel"]
	var sign_cols := [Color(0.42, 0.28, 0.16), Color(0.34, 0.24, 0.15), Color(0.48, 0.34, 0.2)]
	var awning_cols := [Color(0.55, 0.2, 0.16), Color(0.22, 0.34, 0.26), Color(0.24, 0.28, 0.42), Color(0.58, 0.46, 0.2)]
	var plant_cols := [Color(0.65, 0.22, 0.26), Color(0.85, 0.7, 0.3), Color(0.55, 0.3, 0.55), Color(0.9, 0.88, 0.8)]
	for h in houses:
		if h.special != "" or h.old:
			continue
		for side in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var half: float = (h.size * 0.5).dot(side.abs())
			var mid: Vector2 = h.c + side * half
			if not streets.any(func(s: Rect2) -> bool: return s.has_point(mid + side * 12.0)):
				continue # this wall doesn't face a street
			var along: Vector2 = side.orthogonal() * (h.size * 0.5).dot(side.orthogonal().abs())
			var roll := _rng.randf()
			if roll < 0.4:
				_wall_lanterns.append([mid + along * _rng.randf_range(-0.6, 0.6), side])
			if roll > 0.72:
				_signs.append([mid + along * _rng.randf_range(-0.5, 0.5), side, icons[_rng.randi() % icons.size()], sign_cols[_rng.randi() % sign_cols.size()]])
			elif roll > 0.5:
				_awnings.append([mid + along * _rng.randf_range(-0.3, 0.3), side, _rng.randf_range(18, 30), awning_cols[_rng.randi() % awning_cols.size()]])
			if _rng.randf() < 0.3:
				var p: Vector2 = mid + side * 3.0 + along * _rng.randf_range(-0.8, 0.8)
				_plants.append([p, plant_cols[_rng.randi() % plant_cols.size()]])
				_plants.append([p + side.orthogonal() * 6.0, plant_cols[_rng.randi() % plant_cols.size()]])
	# Laundry across the narrow alleys between two houses in a row
	for i in houses.size():
		var a := houses[i]
		if a.old or _laundry.size() > 40 or _rng.randf() > 0.25:
			continue
		for j in range(i + 1, mini(i + 4, houses.size())):
			var b := houses[j]
			var gap := (b.c.x - b.size.x * 0.5) - (a.c.x + a.size.x * 0.5)
			if gap > 3.0 and gap < 14.0 and absf(a.c.y - b.c.y) < 10.0:
				var y := a.c.y + _rng.randf_range(-0.3, 0.3) * minf(a.size.y, b.size.y)
				_laundry.append([Vector2(a.c.x + a.size.x * 0.5 - 4, y), Vector2(b.c.x - b.size.x * 0.5 + 4, y + _rng.randf_range(-6, 6))])
				break


## The old town: a ring wall round the hilltop, a ring lane, crooked old houses in two rings,
## lanes up to the Old Market at the top, and the Gilded Gull saloon on the market.
func _build_hill() -> void:
	var lanes := [0.0] # one lane: from the gate up to the market
	# The Gilded Gull: on the market, facing it, behind the well (opposite the gate)
	var gull := House.new()
	gull.size = Vector2(86, RING_R - RING_HALF - TOP_R - 12)
	gull.c = HILL + Vector2.from_angle(PI) * (TOP_R + 6 + gull.size.y * 0.5)
	gull.rot = PI + PI * 0.5
	gull.roof = Color(0.48, 0.24, 0.16)
	gull.wall = WALLS[1]
	gull.kind = 1
	gull.special = "saloon"
	gull.old = true
	houses.append(gull)
	var inward := Vector2.from_angle(0.0) # from the saloon towards the market's middle
	var door := gull.c + inward * gull.size.y * 0.5
	doors.append([door + inward * 16.0, "saloon", Catalog.CITY["saloons"][2]])
	_boards.append([door - inward * 4.0, Catalog.CITY["saloons"][2], "saloon"])
	_wall_lanterns.append([door + Vector2(0, 26), inward])
	_wall_lanterns.append([door + Vector2(0, -26), inward])
	_signs.append([door + Vector2(0, 42), inward, "mug", Color(0.5, 0.34, 0.2)])
	_props.append([door + inward * 12.0 + Vector2(0, -44), "barrel"])
	_props.append([door + inward * 12.0 + Vector2(0, -52), "barrel"])
	for k in 3:
		_patrons.append(door + inward * _rng.randf_range(18, 28) + Vector2(0, _rng.randf_range(20, 40)))
	var taken := [[PI, (gull.size.x * 0.5 + 6.0) / (TOP_R + 8.0)]] # [angle, half angle] in the inner ring
	# Two rings of houses, each in two close rows (small old houses packed together), facing the
	# ring lane; [inner radius, outer radius, inner ring?, faces the ring lane?]
	var rows := [[TOP_R + 6.0, 110.0, true, false], [113.0, RING_R - RING_HALF - 3.0, true, true],
		[RING_R + RING_HALF + 3.0, 238.0, false, true], [241.0, PLATEAU_R - 9.0, false, false]]
	for row in rows:
		var r0: float = row[0]
		var r1: float = row[1]
		var inner: bool = row[2]
		var faces_lane: bool = row[3]
		var a := _rng.randf() * 0.2
		while a < TAU - 0.05:
			var w := _rng.randf_range(30, 50)
			var da := w / r0 * 1.04
			var mid := a + da * 0.5
			var clear := true
			for la in lanes:
				if absf(angle_difference(mid, la)) < da * 0.5 + 22.0 / r0:
					clear = false
			if inner:
				for t in taken:
					if absf(angle_difference(mid, t[0])) < da * 0.5 + float(t[1]):
						clear = false
			if clear:
				var depth := (r1 - r0) - _rng.randf_range(0.0, 4.0)
				var h := House.new()
				h.size = Vector2(w, depth)
				h.c = HILL + Vector2.from_angle(mid) * ((r0 + r1) * 0.5)
				h.rot = mid + PI * 0.5 + _rng.randf_range(-0.06, 0.06)
				h.roof = OLD_ROOFS[_rng.randi() % OLD_ROOFS.size()]
				h.wall = WALLS[_rng.randi() % WALLS.size()].darkened(0.1)
				h.kind = 0 if _rng.randf() < 0.75 else 1
				h.old = true
				if _rng.randf() < 0.45:
					h.chimney = Vector2(w * _rng.randf_range(-0.25, 0.25), 0.0)
				houses.append(h)
				# A lantern on the wall that faces the ring lane
				if faces_lane and _rng.randf() < 0.35:
					var n := Vector2.from_angle(mid) * (1.0 if inner else -1.0)
					_wall_lanterns.append([h.c + n * depth * 0.5, n])
			a += da + _rng.randf_range(1.5, 4.0) / r0
	# Lamp posts by the ring lane and the gate, and walking routes up the hill and round it
	for k in 10:
		_posts.append(HILL + Vector2.from_angle(TAU * k / 10.0 + 0.3) * (RING_R + RING_HALF - 3))
	_posts.append(HILL + Vector2(PLATEAU_R + 14, -GATE_HALF - 6))
	_posts.append(HILL + Vector2(PLATEAU_R + 14, GATE_HALF + 6))
	var ring := PackedVector2Array()
	for k in 41:
		ring.append(HILL + Vector2.from_angle(TAU * k / 40.0) * RING_R)
	_routes.append(ring)
	_routes.append(PackedVector2Array([Vector2(SQUARE.end.x - 10, 0), Vector2(SQUARE.get_center().x, -50), Vector2(SQUARE.position.x - 5, 0),
		HILL + Vector2(PLATEAU_R, 0), HILL + Vector2(TOP_R + 10, 0)])) # round the fountain and up the stair
	_routes.append(PackedVector2Array([HILL + Vector2(-40, -40), HILL + Vector2(40, -40), HILL + Vector2(40, 40), HILL + Vector2(-40, 40), HILL + Vector2(-40, -40)]))


## Trees on the island round the town (only for the look).
func _build_outskirts() -> void:
	var land := _scaled_land(0.93)
	var tries := 0
	while _trees.size() < 220 and tries < 3000:
		tries += 1
		var p := Vector2(_rng.randf_range(-FRONT_DIST - ISLAND_RADIUS, 0.0), _rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS))
		if not Geometry2D.is_point_in_polygon(p, land):
			continue
		if p.x > BACK_X - 30.0 and absf(p.y) < HW + 60.0: # the canal quarter
			continue
		if p.distance_to(HILL) < PLATEAU_R + 30.0 or SQUARE.grow(50.0).has_point(p):
			continue
		if absf(p.y) < GATE_HALF + 30.0 and p.x > HILL.x and p.x < SQUARE.end.x:
			continue # the way up to the gate
		_trees.append([p, _rng.randf_range(12.0, 24.0), _rng.randf_range(-0.06, 0.06)])


func _build_bodies() -> void:
	# Houses and canal water: solid for the captain (not for ships: they never get there)
	var body := StaticBody2D.new()
	body.collision_layer = BUILDING_LAYER
	body.collision_mask = 0
	add_child(body)
	for h in houses:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = h.size
		shape.shape = rect
		shape.position = h.c
		shape.rotation = h.rot
		body.add_child(shape)
	for c in canals: # the water between the bridges
		for piece in _minus_bridges(c):
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = piece.size
			shape.shape = rect
			shape.position = piece.get_center()
			body.add_child(shape)
	var fountain := CollisionShape2D.new() # the fountain on Lantern Square
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	fountain.shape = circle
	fountain.position = SQUARE.get_center()
	body.add_child(fountain)
	# The ring wall round the old town, open at the gate
	for k in 72:
		var a0 := TAU * k / 72.0
		var a1 := TAU * (k + 1) / 72.0
		if absf(angle_difference((a0 + a1) * 0.5, 0.0)) < (GATE_HALF + 6.0) / PLATEAU_R:
			continue
		var c := CollisionPolygon2D.new()
		c.polygon = PackedVector2Array([HILL + Vector2.from_angle(a0) * (PLATEAU_R - 6), HILL + Vector2.from_angle(a1) * (PLATEAU_R - 6),
			HILL + Vector2.from_angle(a1) * (PLATEAU_R + 6), HILL + Vector2.from_angle(a0) * (PLATEAU_R + 6)])
		body.add_child(c)
	# Moles and side piers: solid for ships (layer 1, like islands)
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


## The parts of a canal that are open water (not under a bridge).
func _minus_bridges(c: Rect2) -> Array[Rect2]:
	var along_x := c.size.x > c.size.y
	var cuts: Array = []
	for b in bridges:
		if b.intersects(c):
			cuts.append(Vector2(b.position.x, b.end.x) if along_x else Vector2(b.position.y, b.end.y))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array[Rect2] = []
	var start := c.position.x if along_x else c.position.y
	var stop := c.end.x if along_x else c.end.y
	for cut in cuts:
		if cut.x > start:
			out.append(Rect2(start, c.position.y, cut.x - start, c.size.y) if along_x else Rect2(c.position.x, start, c.size.x, cut.x - start))
		start = maxf(start, cut.y)
	if stop > start:
		out.append(Rect2(start, c.position.y, stop - start, c.size.y) if along_x else Rect2(c.position.x, start, c.size.x, stop - start))
	return out


## True if this global point is on the quay, a pier or a mole (for Game.is_walkable).
func covers(global_pos: Vector2) -> bool:
	for i in walk_polys.size():
		if _walk_aabbs[i].has_point(global_pos) and Geometry2D.is_point_in_polygon(to_local(global_pos), walk_polys[i]):
			return true
	return false


## The harbor, if this global point is at the shop's door (the captain can step in), else null.
func shop_at(global_pos: Vector2) -> Harbor:
	if not is_inside_tree() or global_pos.distance_squared_to(global_position) > RADIUS * RADIUS:
		return null
	var p := to_local(global_pos)
	for d in doors:
		if d[1] == "shop" and p.distance_to(d[0]) < 30.0:
			return harbor
	return null


## The name of the saloon whose door this global point is at, or "".
func saloon_at(global_pos: Vector2) -> String:
	if not is_inside_tree() or global_pos.distance_squared_to(global_position) > RADIUS * RADIUS:
		return ""
	var p := to_local(global_pos)
	for d in doors:
		if d[1] == "saloon" and p.distance_to(d[0]) < 34.0:
			return d[2]
	return ""


func _build_life() -> void:
	# Real lights: the lighthouse, the quay, the square and the saloon doors (the many wall
	# lanterns only glow – LanternGlow – which costs far less)
	WorldSky.add_lantern(self, LIGHTHOUSE, 320.0, Color(1.0, 0.92, 0.7), 1.3)
	for d in doors:
		WorldSky.add_lantern(self, d[0], 90.0, LAMP, 0.9)
	for i in _posts.size():
		if i % 4 == 0:
			WorldSky.add_lantern(self, _posts[i], 70.0, LAMP, 0.6)
	# Ships moored at the side piers and the quay, and two at anchor in the basin
	var spots := [[Vector2(90, -806), 0.0], [Vector2(210, -806), 0.0], [Vector2(210, -714), 0.0], [Vector2(40, -960), PI * 0.5],
		[Vector2(290, -560), 0.4], [Vector2(90, 806), 0.0], [Vector2(210, 806), 0.0], [Vector2(210, 714), 0.0], [Vector2(40, 960), -PI * 0.5],
		[Vector2(290, 580), -0.3]]
	var types := ["sloop", "schooner", "fluyt", "caravel", "brig", "cutter", "brigantine"]
	for s in spots:
		var v := ShipVisual.new()
		v.position = s[0]
		v.rotation = float(s[1])
		add_child(v)
		v.apply_config(_ship_config(types[_rng.randi() % types.size()]))
		_moored.append(v)
	# Ships that come in to a berth, stay a while, and sail away (and come back later)
	for side in [-1.0, 1.0]:
		var hs := HarborShip.new()
		hs.path = [Vector2(90, side * 712), Vector2(250, side * 560), Vector2(380, side * 220), Vector2(640, side * 60),
			Vector2(1300, side * 320), Vector2(2700, side * 950)]
		add_child(hs)
		hs.setup(_ship_config(types[(2 if side < 0.0 else 4)]), side > 0.0)
	for i in 6:
		_boats.append([Vector2(_rng.randf_range(60, 360), _rng.randf_range(-600, 600)), Vector2.ZERO, 0.0])
	# The static town in chunks of 700 px (Godot skips the ones that are off screen): houses and
	# trees always, the small wall details only close up
	var house_chunks := {}
	for h in houses:
		(_chunk_for(house_chunks, h.c, HouseChunk) as HouseChunk).houses.append(h)
	for t in _trees:
		(_chunk_for(house_chunks, t[0], HouseChunk) as HouseChunk).trees.append(t)
	var anim := CityAnim.new()
	anim.city = self
	add_child(anim)
	_anim = anim
	var over := Bridges.new()
	over.city = self
	add_child(over)
	for key in house_chunks:
		add_child(house_chunks[key])
	var detail_chunks := {}
	for l in _wall_lanterns:
		(_chunk_for(detail_chunks, l[0], DetailChunk) as DetailChunk).items.append(["lantern", l])
	for s in _signs:
		(_chunk_for(detail_chunks, s[0], DetailChunk) as DetailChunk).items.append(["sign", s])
	for a in _awnings:
		(_chunk_for(detail_chunks, a[0], DetailChunk) as DetailChunk).items.append(["awning", a])
	for p in _plants:
		(_chunk_for(detail_chunks, p[0], DetailChunk) as DetailChunk).items.append(["plant", p])
	for l in _laundry:
		(_chunk_for(detail_chunks, l[0], DetailChunk) as DetailChunk).items.append(["laundry", l])
	for b in _boards:
		(_chunk_for(detail_chunks, b[0], DetailChunk) as DetailChunk).items.append(["board", b])
	for p in _props:
		(_chunk_for(detail_chunks, p[0], DetailChunk) as DetailChunk).items.append(["prop", p])
	for p in _posts:
		(_chunk_for(detail_chunks, p, DetailChunk) as DetailChunk).items.append(["post", p])
	for key in detail_chunks:
		_details.append(detail_chunks[key])
		add_child(detail_chunks[key])
	var life := CityLife.new()
	life.city = self
	add_child(life)
	_glow = LanternGlow.new()
	_glow.city = self
	add_child(_glow)


func _ship_config(type: String) -> Dictionary:
	var cfg := Game.new_ship_config(type)
	cfg["sail"] = ["canvas", "sand", "crimson", "midnight", "forest"][_rng.randi() % 5]
	cfg["hull"] = ["oak", "dark", "red"][_rng.randi() % 3]
	cfg["decorations"] = {"flag": true, "lanterns": true}
	cfg["flag"] = ["red", "white", "gold", "blue"][_rng.randi() % 4]
	return cfg


# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	if _frame % 15 == 0: # the wall details only show close up (on foot, or sailing in close)
		var cam := get_viewport().get_camera_2d()
		var near := cam == null or cam.zoom.x > 0.8
		for d in _details:
			d.visible = near
	for i in _moored.size(): # bobbing at the quay, sails furled (a few each frame: cheaper)
		if (i + _frame) % 4 == 0:
			_moored[i].update_motion(0.0, 0.0, 0.0, delta * 4.0)
	for b in _boats:
		var to: Vector2 = (b[1] as Vector2) - (b[0] as Vector2)
		if to.length() < 4.0 or b[1] == Vector2.ZERO:
			b[1] = Vector2(_rng.randf_range(60, 380), _rng.randf_range(-680, 680))
		else:
			b[2] = lerp_angle(float(b[2]), to.angle(), 1.0 - exp(-2.0 * delta))
			b[0] = (b[0] as Vector2) + Vector2.from_angle(float(b[2])) * 14.0 * delta
	if _frame % 2 == 0:
		_anim.queue_redraw() # only the moving parts, every other frame; the town was drawn once
		_glow.queue_redraw()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	# The island's grass inside the beach: darker and earthier than the little islands
	var grass := Color(0.3, 0.42, 0.25)
	draw_colored_polygon(_scaled_land(0.93), grass)
	# The hill: a shadow to the lower right, the slope, and the paved hilltop inside the wall
	_circle_poly(HILL + Vector2(26, 34), SLOPE_R + 10.0, Color(0, 0, 0, 0.18))
	_circle_poly(HILL, SLOPE_R, Color(0.33, 0.45, 0.27))
	_circle_poly(HILL - Vector2(18, 22), SLOPE_R * 0.86, Color(0.36, 0.49, 0.29))
	_textured_circle(HILL, PLATEAU_R, _cobbles, Color(0.5, 0.44, 0.38)) # dark old cobbles between the houses
	# The canal quarter's paved ground (alleys and yards), then the streets on top
	for g in _ground:
		draw_colored_polygon(g, Color(0.5, 0.44, 0.38), _uvs(g, 64.0), _cobbles) # alleys and yards: darker
	for s in _street_polys:
		draw_colored_polygon(s, Color.WHITE, _uvs(s, 64.0), _cobbles)
	# Lantern Square: brick paving, and the stair up the hill
	draw_texture_rect(_bricks, SQUARE, true, Color(0.62, 0.42, 0.34))
	draw_rect(SQUARE, Color(0.25, 0.2, 0.17), false, 2.0)
	var stair := Rect2(SQUARE.position.x - 92, -GATE_HALF, 92, GATE_HALF * 2)
	draw_texture_rect(_flags, stair, true, Color(0.9, 0.88, 0.85))
	for x in range(int(stair.position.x) + 4, int(stair.end.x), 7):
		draw_line(Vector2(x, stair.position.y), Vector2(x, stair.end.y), Color(0.2, 0.18, 0.16, 0.6), 1.2)
	# The old town: ring lane, lanes up to the top, the Old Market and its well
	_textured_ring(HILL, RING_R - RING_HALF, RING_R + RING_HALF, _cobbles, Color(1.05, 1.03, 1.0))
	for la in [0.0]:
		var reach := PLATEAU_R if la == 0.0 else RING_R
		var lane := _thick_path([HILL + Vector2.from_angle(la) * (TOP_R - 4), HILL + Vector2.from_angle(la) * reach], 40.0)
		draw_colored_polygon(lane, Color.WHITE, _uvs(lane, 64.0), _cobbles)
	_textured_circle(HILL, TOP_R, _bricks, Color(0.6, 0.44, 0.36))
	draw_circle(HILL, 13.0, Color(0.32, 0.3, 0.28), true, -1.0, false) # the well
	draw_circle(HILL, 9.0, Color(0.1, 0.14, 0.16), true, -1.0, false)
	# The ring wall, with a gate where the stair comes up
	var gate := (GATE_HALF + 6.0) / PLATEAU_R
	draw_arc(HILL + Vector2(3, 4), PLATEAU_R, gate, TAU - gate, 96, Color(0, 0, 0, 0.3), 12.0, false)
	draw_arc(HILL, PLATEAU_R, gate, TAU - gate, 96, Color(0.4, 0.37, 0.33), 12.0, false)
	draw_arc(HILL, PLATEAU_R - 4.0, gate, TAU - gate, 96, Color(0.55, 0.52, 0.47), 3.0, false)
	for s in [-1.0, 1.0]:
		var tower := HILL + Vector2.from_angle(s * gate) * PLATEAU_R
		draw_circle(tower + Vector2(2, 3), 11.0, Color(0, 0, 0, 0.3), true, -1.0, false)
		draw_circle(tower, 11.0, Color(0.42, 0.39, 0.35), true, -1.0, false)
		draw_circle(tower, 7.0, Color(0.5, 0.26, 0.18), true, -1.0, false)
	# The canals: dark water between stone walls
	for c in canals:
		draw_rect(c, WATER)
		draw_rect(c, Color(0.1, 0.18, 0.2), false, 4.0)
	for s in [-1.0, 1.0]: # where a canal meets the cross canal, the stone wall is open
		draw_rect(Rect2(CROSS_X - CANAL_HALF + 2, s * CANAL_Y - CANAL_HALF + 2, CANAL_HALF * 2 - 4, CANAL_HALF * 2 - 4), WATER)
	draw_rect(Rect2(CROSS_X - CANAL_HALF + 2, -CANAL_Y, CANAL_HALF * 2 - 4, CANAL_Y * 2), WATER)
	for c in canals: # the stone kerb along the water
		if c.size.x > c.size.y:
			draw_line(c.position, Vector2(c.end.x, c.position.y), STONE, 3.0)
			draw_line(Vector2(c.position.x, c.end.y), c.end, STONE, 3.0)
	# Moles, quay and piers: big dressed stones, with an edge and a shadow
	for m in _moles:
		draw_colored_polygon(_offset(m, Vector2(3, 4)), Color(0, 0, 0, 0.22))
		draw_colored_polygon(m, Color.WHITE, _uvs(m, 128.0), _flags)
		draw_polyline(m + PackedVector2Array([m[0]]), STONE.darkened(0.35), 1.6, true)
	var quay := _quay()
	for part in _minus_canal_mouths(quay):
		draw_texture_rect(_flags, part, true)
	draw_line(Vector2(quay.end.x, quay.position.y), quay.end, STONE.darkened(0.35), 3.0) # quay edge
	for p in _piers:
		draw_rect(Rect2(p.position + Vector2(3, 4), p.size), Color(0, 0, 0, 0.2))
		draw_texture_rect(_flags, p, true, Color(1.05, 1.05, 1.05))
		draw_rect(p, STONE.darkened(0.35), false, 1.2)
	for y in range(int(-HW + 60), int(HW - 60), 55): # bollards along the quay
		if absf(absf(y) - CANAL_Y) > CANAL_HALF + 6.0:
			draw_circle(Vector2(4, y), 2.6, Color(0.14, 0.12, 0.11), true, -1.0, false)
	# Cranes and cargo on the quay
	for c in _cranes:
		draw_rect(Rect2(c - Vector2(9, 9) + Vector2(2, 3), Vector2(18, 18)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.36, 0.25, 0.16))
		draw_line(c, c + Vector2(44, -10), Color(0.3, 0.2, 0.12), 4.0)
		draw_line(c + Vector2(44, -10), c + Vector2(44, 2), Color(0.15, 0.13, 0.12), 1.0)
		for k in 4:
			var crate := c + Vector2(-38 + (k % 2) * 13, -18 + (k / 2) * 13)
			draw_rect(Rect2(crate, Vector2(11, 11)), Color(0.55, 0.4, 0.24))
			draw_rect(Rect2(crate, Vector2(11, 11)), Color(0.3, 0.2, 0.12), false, 1.0)
	# The lighthouse at the end of the north mole, a beacon on the south one
	draw_circle(LIGHTHOUSE + Vector2(5, 6), 26, Color(0, 0, 0, 0.25), true, -1.0, false)
	draw_circle(LIGHTHOUSE, 26, Color(0.6, 0.55, 0.5), true, -1.0, false)
	draw_arc(LIGHTHOUSE, 26, 0, TAU, 32, Color(0.55, 0.22, 0.17), 5.0, true)
	draw_circle(LIGHTHOUSE, 11, Color(1.0, 0.88, 0.55), true, -1.0, false)
	draw_circle(BEACON, 16, Color(0.45, 0.42, 0.38), true, -1.0, false)
	draw_circle(BEACON, 8, Color(0.3, 0.2, 0.14), true, -1.0, false)
	# Market stalls on Lantern Square
	for st in _stalls:
		var p: Vector2 = st[0]
		var col: Color = st[1]
		draw_rect(Rect2(p + Vector2(-9, -6) + Vector2(2, 3), Vector2(18, 12)), Color(0, 0, 0, 0.25))
		for k in 4:
			draw_rect(Rect2(p + Vector2(-9 + k * 4.5, -6), Vector2(4.5, 12)), col if k % 2 == 0 else Color(0.82, 0.78, 0.7))


## The quay without the canal mouths (where the quay is a bridge, drawn by Bridges).
func _minus_canal_mouths(q: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var y := q.position.y
	for cy in [-CANAL_Y, CANAL_Y]:
		out.append(Rect2(q.position.x, y, q.size.x, cy - CANAL_HALF - y))
		y = cy + CANAL_HALF
	out.append(Rect2(q.position.x, y, q.size.x, q.end.y - y))
	return out


## The moving parts, drawn every other frame by CityAnim: shimmer on the canals, the fountain on
## the square, the lighthouse beam, the barges on the canals and the rowboats in the basin.
func _draw_animated(ci: CanvasItem) -> void:
	for i in canals.size():
		var c := canals[i]
		var along_x := c.size.x > c.size.y
		for k in 7:
			var t := fposmod(k / 7.0 + _time * 0.015 * (1.0 if i % 2 == 0 else -1.0), 1.0)
			var off := sin(_time * 0.8 + k * 2.1) * c.size.y * 0.25 if along_x else sin(_time * 0.8 + k * 2.1) * c.size.x * 0.25
			var p := Vector2(c.position.x + c.size.x * t, c.get_center().y + off) if along_x else Vector2(c.get_center().x + off, c.position.y + c.size.y * t)
			var d := Vector2(10, 0) if along_x else Vector2(0, 10)
			ci.draw_line(p - d, p + d, Color(0.5, 0.65, 0.68, 0.22), 1.5)
	var mid := SQUARE.get_center()
	ci.draw_circle(mid, 30, Color(0.46, 0.43, 0.39), true, -1.0, false)
	ci.draw_circle(mid, 24, Color(0.2, 0.36, 0.42), true, -1.0, false)
	ci.draw_circle(mid, 7, Color(0.55, 0.52, 0.48), true, -1.0, false)
	for k in 6:
		var a := TAU * k / 6.0 + _time
		ci.draw_circle(mid + Vector2.from_angle(a) * (11 + sin(_time * 3.0 + k) * 3.0), 1.8, Color(0.75, 0.88, 0.95, 0.7), true, -1.0, false)
	if Game.night > 0.2: # a slow beam sweeping over the water
		var a := _time * 0.5
		var beam := PackedVector2Array([LIGHTHOUSE, LIGHTHOUSE + Vector2.from_angle(a - 0.1) * 1400, LIGHTHOUSE + Vector2.from_angle(a + 0.1) * 1400])
		ci.draw_colored_polygon(beam, Color(1.0, 0.95, 0.75, 0.1 * Game.night))
	for i in _barge_routes.size(): # barges punted slowly up and down the canals
		var route := _barge_routes[i]
		var u := 0.5 - 0.5 * cos(_time * 0.02 + i * 2.0)
		var p := route[0].lerp(route[1], u)
		var dir := (route[1] - route[0]).normalized() * (1.0 if sin(_time * 0.02 + i * 2.0) >= 0.0 else -1.0)
		ci.draw_set_transform(p, dir.angle())
		ci.draw_rect(Rect2(-17, -6, 34, 12), Color(0.36, 0.24, 0.14))
		ci.draw_rect(Rect2(-14, -4, 18, 8), Color(0.55, 0.42, 0.26))
		ci.draw_rect(Rect2(6, -4, 7, 8), Color(0.42, 0.45, 0.3))
		ci.draw_circle(Vector2(-12, 0), 2.6, Color(0.5, 0.25, 0.2), true, -1.0, false)
		ci.draw_line(Vector2(-12, 0), Vector2(-24, 6), Color(0.6, 0.45, 0.3), 1.0)
		ci.draw_set_transform(Vector2.ZERO)
	for b in _boats:
		ci.draw_set_transform(b[0], float(b[2]))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(2, -3), Vector2(-6, -2.6), Vector2(-6, 2.6), Vector2(2, 3)]), Color(0.4, 0.27, 0.16))
		var oar := sin(_time * 6.0) * 2.0
		ci.draw_line(Vector2(0, -2), Vector2(-1 + oar, -7), Color(0.6, 0.45, 0.3), 0.8)
		ci.draw_line(Vector2(0, 2), Vector2(-1 + oar, 7), Color(0.6, 0.45, 0.3), 0.8)
		ci.draw_circle(Vector2(-1, 0), 1.5, Color(0.55, 0.25, 0.2), true, -1.0, false)
		ci.draw_set_transform(Vector2.ZERO)


## Draws one house: shadow, brick walls, and a roof (gable, hip, courtyard or flat terrace).
func _draw_house(ci: CanvasItem, h: House) -> void:
	ci.draw_set_transform(h.c, h.rot)
	var r := h.rect()
	ci.draw_rect(Rect2(r.position + Vector2(4, 6).rotated(-h.rot), r.size), Color(0, 0, 0, 0.3))
	ci.draw_texture_rect(_bricks, r, true, h.wall)
	var rr := r.grow(-5.0) # the brick walls show round the roof
	var tint := h.roof * 1.15
	tint.a = 1.0
	match h.kind:
		0, 3: # gable: two halves, the ridge along the long side (3: a flat terrace on part of it)
			if rr.size.x >= rr.size.y:
				var top := Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.5))
				ci.draw_texture_rect(_roof_h, top, true, _shade(tint, 1.08))
				ci.draw_texture_rect(_roof_h, Rect2(top.position + Vector2(0, top.size.y), top.size), true, _shade(tint, 0.8))
				ci.draw_line(Vector2(rr.position.x, 0), Vector2(rr.end.x, 0), h.roof.darkened(0.45), 2.0)
			else:
				var left := Rect2(rr.position, Vector2(rr.size.x * 0.5, rr.size.y))
				ci.draw_texture_rect(_roof_v, left, true, _shade(tint, 1.04))
				ci.draw_texture_rect(_roof_v, Rect2(left.position + Vector2(left.size.x, 0), left.size), true, _shade(tint, 0.84))
				ci.draw_line(Vector2(0, rr.position.y), Vector2(0, rr.end.y), h.roof.darkened(0.45), 2.0)
			if h.kind == 3: # a little roof terrace with pots
				var t := Rect2(rr.position + rr.size * Vector2(0.55, 0.15), rr.size * Vector2(0.38, 0.7))
				ci.draw_texture_rect(_flags, t, true, Color(0.75, 0.68, 0.6))
				ci.draw_rect(t, Color(0.25, 0.18, 0.14), false, 1.5)
				ci.draw_circle(t.get_center() + Vector2(-3, -3), 3.0, Color(0.32, 0.48, 0.28), true, -1.0, false)
		1: # hip: four slopes meeting in a short ridge
			var d := minf(rr.size.x, rr.size.y) * 0.5
			var c := rr.get_center()
			var along_x := rr.size.x >= rr.size.y
			var ra := c - (Vector2(rr.size.x * 0.5 - d, 0) if along_x else Vector2(0, rr.size.y * 0.5 - d))
			var rb := c + (Vector2(rr.size.x * 0.5 - d, 0) if along_x else Vector2(0, rr.size.y * 0.5 - d))
			var tl := rr.position
			var tr := Vector2(rr.end.x, rr.position.y)
			var br := rr.end
			var bl := Vector2(rr.position.x, rr.end.y)
			var faces := [[PackedVector2Array([tl, tr, rb, ra]) if along_x else PackedVector2Array([tl, tr, ra]), 1.08],
				[PackedVector2Array([bl, br, rb, ra]) if along_x else PackedVector2Array([bl, br, rb]), 0.78],
				[PackedVector2Array([tl, ra, bl]) if along_x else PackedVector2Array([tl, ra, rb, bl]), 0.98],
				[PackedVector2Array([tr, rb, br]) if along_x else PackedVector2Array([tr, ra, rb, br]), 0.86]]
			for f in faces:
				var poly: PackedVector2Array = f[0]
				ci.draw_colored_polygon(poly, _shade(tint, float(f[1])), _uvs(poly, 42.0), _roof_h if along_x else _roof_v)
			ci.draw_line(ra, rb, h.roof.darkened(0.45), 2.0)
			for p in [tl, tr, br, bl]:
				ci.draw_line(p, ra if (p.x < c.x if along_x else p.y < c.y) else rb, h.roof.darkened(0.3), 1.0)
		2: # round a little courtyard with a tree
			var yard := rr.grow(-minf(rr.size.x, rr.size.y) * 0.3)
			for part in [Rect2(rr.position, Vector2(rr.size.x, yard.position.y - rr.position.y)),
					Rect2(Vector2(rr.position.x, yard.end.y), Vector2(rr.size.x, rr.end.y - yard.end.y))]:
				ci.draw_texture_rect(_roof_h, part, true, _shade(tint, 0.95))
			for part in [Rect2(Vector2(rr.position.x, yard.position.y), Vector2(yard.position.x - rr.position.x, yard.size.y)),
					Rect2(Vector2(yard.end.x, yard.position.y), Vector2(rr.end.x - yard.end.x, yard.size.y))]:
				ci.draw_texture_rect(_roof_v, part, true, _shade(tint, 0.88))
			ci.draw_texture_rect(_flags, yard, true, Color(0.62, 0.58, 0.52))
			ci.draw_rect(yard, h.wall.darkened(0.4), false, 1.5)
			ci.draw_circle(yard.get_center() + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.25), true, -1.0, false)
			ci.draw_circle(yard.get_center(), 7.0, Color(0.27, 0.42, 0.24), true, -1.0, false)
	if h.old: # moss and patches on the old town's roofs
		ci.draw_rect(Rect2(rr.position + rr.size * Vector2(0.15, 0.6), rr.size * Vector2(0.25, 0.25)), Color(0.28, 0.36, 0.2, 0.45))
	if h.chimney != Vector2.INF:
		ci.draw_rect(Rect2(h.chimney - Vector2(4, 4) + Vector2(2, 2), Vector2(8, 8)), Color(0, 0, 0, 0.3))
		ci.draw_texture_rect(_bricks, Rect2(h.chimney - Vector2(4, 4), Vector2(8, 8)), false, h.wall)
		ci.draw_rect(Rect2(h.chimney - Vector2(2, 2), Vector2(4, 4)), Color(0.1, 0.08, 0.07))
	ci.draw_set_transform(Vector2.ZERO)


func _draw_tree(ci: CanvasItem, t: Array) -> void:
	var p: Vector2 = t[0]
	var s: float = t[1]
	var shade: float = t[2]
	ci.draw_circle(p + Vector2(s * 0.3, s * 0.4), s, Color(0, 0, 0, 0.22), true, -1.0, false)
	ci.draw_circle(p, s, Color(0.2 + shade, 0.33 + shade, 0.19), true, -1.0, false)
	ci.draw_circle(p - Vector2(s * 0.25, s * 0.3), s * 0.6, Color(0.25 + shade, 0.4 + shade, 0.22), true, -1.0, false)


## The small things on the walls and in the streets (DetailChunk): lanterns on iron arms, signs
## with a painted symbol, awnings, flower pots, laundry, name boards, barrels, lamp posts.
func _draw_detail(ci: CanvasItem, kind: String, d: Variant) -> void:
	var iron := Color(0.1, 0.09, 0.08)
	match kind:
		"lantern":
			var p: Vector2 = d[0]
			var n: Vector2 = d[1]
			ci.draw_line(p, p + n * 7.0, iron, 1.4)
			ci.draw_line(p + n * 2.0, p + n * 4.0 + n.orthogonal() * 2.0, iron, 1.0)
			var c := p + n * 9.0
			ci.draw_rect(Rect2(c - Vector2(2.6, 2.6), Vector2(5.2, 5.2)), iron)
			ci.draw_rect(Rect2(c - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), Color(1.0, 0.78, 0.42))
		"post":
			var p: Vector2 = d
			ci.draw_circle(p + Vector2(2, 3), 3.0, Color(0, 0, 0, 0.3), true, -1.0, false)
			ci.draw_circle(p, 3.0, iron, true, -1.0, false)
			ci.draw_circle(p, 1.8, Color(1.0, 0.8, 0.45), true, -1.0, false)
		"sign":
			var p: Vector2 = d[0]
			var n: Vector2 = d[1]
			var t := n.orthogonal()
			ci.draw_line(p, p + n * 15.0, iron, 1.4)
			var c := p + n * 10.0
			var board := PackedVector2Array([c - t * 5.0 - n * 4.0, c + t * 5.0 - n * 4.0, c + t * 5.0 + n * 5.0, c - t * 5.0 + n * 5.0])
			ci.draw_colored_polygon(_offset(board, Vector2(2, 3)), Color(0, 0, 0, 0.25))
			ci.draw_colored_polygon(board, d[3])
			ci.draw_polyline(board + PackedVector2Array([board[0]]), (d[3] as Color).darkened(0.45), 1.0)
			_draw_icon(ci, c + n * 0.5, t, n, String(d[2]))
		"awning":
			var p: Vector2 = d[0]
			var n: Vector2 = d[1]
			var w: float = d[2]
			var t := n.orthogonal()
			var col: Color = d[3]
			ci.draw_colored_polygon(PackedVector2Array([p - t * w * 0.5 + n * 3.0, p + t * w * 0.5 + n * 3.0, p + t * w * 0.5 + n * 12.0, p - t * w * 0.5 + n * 12.0]), Color(0, 0, 0, 0.25))
			var stripes := int(w / 5.0)
			for k in stripes:
				var a := p - t * w * 0.5 + t * (w * k / stripes)
				var b := a + t * (w / stripes)
				ci.draw_colored_polygon(PackedVector2Array([a, b, b + n * 9.0, a + n * 9.0]), col if k % 2 == 0 else Color(0.78, 0.72, 0.62))
		"plant":
			ci.draw_circle(d[0], 2.6, Color(0.36, 0.24, 0.16), true, -1.0, false)
			ci.draw_circle(d[0], 2.0, Color(0.3, 0.45, 0.25), true, -1.0, false)
			ci.draw_circle(d[0] + Vector2(-0.6, -0.6), 1.0, d[1], true, -1.0, false)
		"laundry":
			var a: Vector2 = d[0]
			var b: Vector2 = d[1]
			ci.draw_line(a, b, Color(0.3, 0.28, 0.25), 0.7)
			var cols := [Color(0.85, 0.82, 0.75), Color(0.55, 0.62, 0.72), Color(0.72, 0.5, 0.45)]
			for k in 3:
				var p := a.lerp(b, (k + 0.5) / 3.0)
				ci.draw_rect(Rect2(p - Vector2(1.5, 2.0), Vector2(3.0, 4.0)), cols[k])
		"board":
			var c: Vector2 = d[0]
			var text: String = d[1]
			var font := UiTheme.title_font()
			var size := 11
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 10.0
			ci.draw_set_transform(c, -global_rotation) # upright on the screen, however the city lies
			var r := Rect2(-Vector2(w * 0.5, 7), Vector2(w, 13))
			ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(r, Color(0.24, 0.16, 0.1))
			ci.draw_rect(r, Color(0.6, 0.45, 0.22), false, 1.0)
			ci.draw_string(font, Vector2(r.position.x, r.end.y - 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0.95, 0.8, 0.45))
			ci.draw_set_transform(Vector2.ZERO)
		"prop":
			var p: Vector2 = d[0]
			match String(d[1]):
				"barrel":
					ci.draw_circle(p + Vector2(1.5, 2), 5.0, Color(0, 0, 0, 0.25), true, -1.0, false)
					ci.draw_circle(p, 5.0, Color(0.45, 0.3, 0.17), true, -1.0, false)
					ci.draw_arc(p, 3.5, 0, TAU, 12, Color(0.22, 0.2, 0.18), 1.0)
				"bench":
					ci.draw_rect(Rect2(p - Vector2(10, 3), Vector2(20, 6)), Color(0.4, 0.27, 0.15))
					ci.draw_rect(Rect2(p - Vector2(10, 3), Vector2(20, 6)), Color(0.22, 0.15, 0.09), false, 1.0)
				"crates":
					for k in 3:
						var q := p + Vector2((k % 2) * 9.0, (k / 2) * 9.0) - Vector2(5, 5)
						ci.draw_rect(Rect2(q, Vector2(8, 8)), Color(0.55, 0.4, 0.24))
						ci.draw_rect(Rect2(q, Vector2(8, 8)), Color(0.3, 0.2, 0.12), false, 1.0)
				"rope":
					ci.draw_arc(p, 4.0, 0, TAU, 14, Color(0.65, 0.55, 0.38), 2.0)
					ci.draw_arc(p, 1.8, 0, TAU, 10, Color(0.65, 0.55, 0.38), 1.5)


## A small painted symbol on a sign. t points across the board, n along it.
func _draw_icon(ci: CanvasItem, c: Vector2, t: Vector2, n: Vector2, icon: String) -> void:
	var gold := Color(0.95, 0.8, 0.35)
	var dark := Color(0.15, 0.1, 0.06)
	match icon:
		"mug":
			ci.draw_rect(Rect2(c - Vector2(2, 2.5), Vector2(4, 5)), gold)
			ci.draw_arc(c + t * 2.5, 1.4, 0, TAU, 8, gold, 0.9)
		"bread":
			ci.draw_circle(c, 3.0, Color(0.9, 0.7, 0.4), true, -1.0, false)
			ci.draw_line(c - t * 1.5, c + t * 1.5, dark, 0.7)
		"fish":
			ci.draw_colored_polygon(PackedVector2Array([c - t * 3.0, c + t * 1.5 - n * 1.6, c + t * 1.5 + n * 1.6]), Color(0.7, 0.8, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([c + t * 1.5, c + t * 3.5 - n * 1.6, c + t * 3.5 + n * 1.6]), Color(0.7, 0.8, 0.85))
		"anchor":
			ci.draw_line(c - n * 3.0, c + n * 3.0, dark, 1.0)
			ci.draw_line(c - n * 1.8 - t * 1.6, c - n * 1.8 + t * 1.6, dark, 0.9)
			ci.draw_arc(c + n * 1.0, 2.2, n.angle() - 1.3, n.angle() + 1.3, 8, dark, 1.0)
		"coin":
			ci.draw_circle(c, 2.8, gold, true, -1.0, false)
			ci.draw_circle(c, 1.4, gold.darkened(0.3), true, -1.0, false)
		"boot":
			ci.draw_rect(Rect2(c - Vector2(1.5, 3.0), Vector2(3.0, 4.5)), dark)
			ci.draw_rect(Rect2(c + Vector2(-1.5, 1.0), Vector2(4.0, 2.0)), dark)
		"key":
			ci.draw_arc(c - t * 2.0, 1.4, 0, TAU, 8, gold, 0.9)
			ci.draw_line(c - t * 0.6, c + t * 3.0, gold, 0.9)
		"candle":
			ci.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 4)), Color(0.92, 0.88, 0.78))
			ci.draw_circle(c - Vector2(0, 2), 1.2, gold, true, -1.0, false)
		"barrel":
			ci.draw_circle(c, 2.8, Color(0.6, 0.42, 0.24), true, -1.0, false)
			ci.draw_line(c - t * 2.8, c + t * 2.8, dark, 0.7)


# --- Small helpers -------------------------------------------------------------

## A seamless 128 x 128 tile of stones laid in rows with dark joints: small cobbles for the
## streets, big dressed flagstones for the quay and moles. Made once when the city is built.
func _stone_tile(base: Color, stone_w: int, stone_h: int, offset_frac: float) -> ImageTexture:
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var joint := base.darkened(0.42)
	img.fill(joint)
	var rows := N / stone_h
	for row in rows:
		var y0 := row * stone_h
		var shift := int(stone_w * (0.5 if row % 2 == 1 else offset_frac))
		var x := -shift
		while x < N:
			var w := stone_w + _rng.randi_range(-1, 2) if stone_w < 20 else stone_w
			var shade := _rng.randf_range(-0.07, 0.07)
			var col := Color(base.r + shade, base.g + shade, base.b + shade * 0.8)
			for yy in range(1, stone_h):
				for xx in range(1, w):
					var corner := (xx == 1 or xx == w - 1) and (yy == 1 or yy == stone_h - 1) # rounded corners
					if corner:
						continue
					var c := col
					if yy == 1 or xx == 1: # a lighter top-left edge: the light comes from there
						c = col.lightened(0.12)
					elif yy == stone_h - 1 or xx == w - 1:
						c = col.darkened(0.12)
					img.set_pixel(posmod(x + xx, N), y0 + yy, c)
			x += w
	return ImageTexture.create_from_image(img)


## Bricks in a running bond (light grey, tinted by each wall's colour when drawn).
func _brick_tile() -> ImageTexture:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.53, 0.5))
	for row in N / 4:
		var shift := 4 if row % 2 == 1 else 0
		for bx in range(-1, N / 8 + 1):
			var v := _rng.randf_range(0.78, 1.0)
			for yy in range(row * 4, row * 4 + 3):
				for xx in range(bx * 8 + shift, bx * 8 + shift + 7):
					if xx >= 0 and xx < N:
						img.set_pixel(xx, yy, Color(v, v * 0.97, v * 0.95))
	return ImageTexture.create_from_image(img)


## Roof tiles: rows of overlapping tiles with a dark lower lip (light, tinted when drawn).
func _roof_tile(vertical: bool) -> ImageTexture:
	const N := 42 # rows of 6 px, tiles of 7 px
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for row in N / 6:
		var shift := 3 if row % 2 == 1 else 0
		for i in N:
			for k in 6:
				var col := Color(0.92, 0.9, 0.88)
				if k == 5:
					col = Color(0.5, 0.48, 0.46) # the lip of the row below
				elif k < 2:
					col = Color(1.0, 0.98, 0.96)
				if posmod(i + shift, 7) == 0 and k < 5:
					col = Color(0.62, 0.6, 0.58) # the gap between two tiles
				var x := i
				var y := row * 6 + k
				img.set_pixel(y if vertical else x, x if vertical else y, col)
	return ImageTexture.create_from_image(img)


## The stone quay along the waterfront (x = 0 is the water's edge).
static func _quay() -> Rect2:
	return Rect2(QUAY_X, -HW, -QUAY_X + 8.0, HW * 2)


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A polygon of the given width round a path of points (a mole, a lane).
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


## A colour made darker or lighter, but never see-through (Color * float would change alpha too).
static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, 1.0)


static func _uvs(poly: PackedVector2Array, tile: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p / tile)
	return out


## The parts of a polygon that lie on the island (so streets end at the beach).
func _clip_land(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for piece in Geometry2D.intersect_polygons(poly, _land):
		out.append(piece)
	return out


## The island's coast in city space, shrunk towards the island's middle.
func _scaled_land(f: float) -> PackedVector2Array:
	var mid := Vector2(-FRONT_DIST, 0)
	var out := PackedVector2Array()
	for p in _land:
		out.append(mid + (p - mid) * f / 0.985)
	return out


func _circle_poly(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 48:
		pts.append(c + Vector2.from_angle(TAU * k / 48.0) * r * (1.0 + 0.03 * sin(k * 1.7)))
	draw_colored_polygon(pts, col)


func _textured_circle(c: Vector2, r: float, tex: Texture2D, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 64:
		pts.append(c + Vector2.from_angle(TAU * k / 64.0) * r)
	draw_colored_polygon(pts, col, _uvs(pts, 64.0), tex)


func _textured_ring(c: Vector2, r0: float, r1: float, tex: Texture2D, col: Color) -> void:
	for k in 32: # in pieces (a polygon can't have a hole)
		var a0 := TAU * k / 32.0
		var a1 := TAU * (k + 1) / 32.0
		var pts := PackedVector2Array([c + Vector2.from_angle(a0) * r0, c + Vector2.from_angle(a1) * r0,
			c + Vector2.from_angle(a1) * r1, c + Vector2.from_angle(a0) * r1])
		draw_colored_polygon(pts, col, _uvs(pts, 64.0), tex)


func _chunk_for(chunks: Dictionary, p: Vector2, script: Variant) -> Node2D:
	var key := Vector2i(floori(p.x / 700.0), floori(p.y / 700.0))
	if not chunks.has(key):
		var c: Node2D = script.new()
		c.set("city", self)
		chunks[key] = c
	return chunks[key]


## A piece of the town's houses and trees (drawn once).
class HouseChunk extends Node2D:
	var city: BigCity
	var houses: Array = []
	var trees: Array = []

	func _draw() -> void:
		for t in trees:
			city._draw_tree(self, t)
		for h in houses:
			city._draw_house(self, h)


## A piece of the town's small details (drawn once; hidden when zoomed far out).
class DetailChunk extends Node2D:
	var city: BigCity
	var items: Array = [] ## [kind, data]

	func _draw() -> void:
		for it in items:
			city._draw_detail(self, String(it[0]), it[1])


## The bridges over the canals: drawn over the barges that pass under them.
class Bridges extends Node2D:
	var city: BigCity

	func _draw() -> void:
		for b in city.bridges:
			# Over a canal that runs along x, you walk across it along y (and the other way round)
			var along_x := not city.canals.any(func(c: Rect2) -> bool: return c.size.x > c.size.y and c.intersects(b))
			var r := b.grow_individual(4 if along_x else 0, 0 if along_x else 4, 4 if along_x else 0, 0 if along_x else 4)
			draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.3))
			draw_texture_rect(city._flags, r, true, Color(0.95, 0.92, 0.88))
			var wall := Color(0.38, 0.35, 0.31)
			if along_x: # parapets along the bridge's two sides
				draw_line(r.position, Vector2(r.end.x, r.position.y), wall, 3.0)
				draw_line(Vector2(r.position.x, r.end.y), r.end, wall, 3.0)
			else:
				draw_line(r.position, Vector2(r.position.x, r.end.y), wall, 3.0)
				draw_line(Vector2(r.end.x, r.position.y), r.end, wall, 3.0)


## Draws the moving parts of the city (see BigCity._draw_animated).
class CityAnim extends Node2D:
	var city: BigCity

	func _draw() -> void:
		city._draw_animated(self)


## The glow of the lanterns: added light on top of the picture, not darkened by the night (an
## additive, unshaded layer). Only in the evening, and only for lanterns near the screen.
class LanternGlow extends Node2D:
	var city: BigCity

	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _draw() -> void:
		var glow := smoothstep(0.2, 0.6, Game.night)
		if glow < 0.02:
			return
		var cam := get_viewport().get_camera_2d()
		var focus := to_local(cam.get_screen_center_position()) if cam else Vector2.ZERO
		var flick := 0.9 + 0.1 * sin(city._time * 7.0)
		for l in city._wall_lanterns:
			var c: Vector2 = (l[0] as Vector2) + (l[1] as Vector2) * 9.0
			if c.distance_squared_to(focus) < 640000.0: # 800 px
				draw_circle(c, 22.0 * flick, Color(LAMP, 0.1 * glow), true, -1.0, false)
				draw_circle(c, 10.0 * flick, Color(LAMP, 0.18 * glow), true, -1.0, false)
		for p in city._posts:
			if p.distance_squared_to(focus) < 640000.0:
				draw_circle(p, 28.0 * flick, Color(LAMP, 0.09 * glow), true, -1.0, false)
				draw_circle(p, 9.0 * flick, Color(LAMP, 0.2 * glow), true, -1.0, false)
		for d in city.doors: # warm light spilling out of the saloon and shop doors
			var p: Vector2 = d[0]
			if p.distance_squared_to(focus) < 640000.0:
				draw_circle(p, 34.0, Color(LAMP, 0.12 * glow), true, -1.0, false)


## Townsfolk walking up and down the streets, people outside the saloons, and chimney smoke.
class CityLife extends Node2D:
	var city: BigCity
	var _people: Array = [] ## [route index, position along it (0..1), speed (+/-), colour, hat]
	var _lengths: Array[float] = []
	var _smoke: Array = []
	var _smoke_timer := 0.0
	var _time := 0.0

	func _ready() -> void:
		z_index = 2
		for r in city._routes:
			var length := 0.0
			for i in r.size() - 1:
				length += r[i].distance_to(r[i + 1])
			_lengths.append(maxf(length, 1.0))
		var cloth := [Color(0.45, 0.22, 0.18), Color(0.25, 0.3, 0.42), Color(0.55, 0.45, 0.25), Color(0.3, 0.38, 0.25),
			Color(0.4, 0.3, 0.38), Color(0.62, 0.58, 0.5), Color(0.28, 0.24, 0.22)]
		for i in 70:
			var route := randi() % city._routes.size()
			_people.append([route, randf(), randf_range(9.0, 15.0) * (1.0 if randf() < 0.5 else -1.0), cloth[i % cloth.size()], randf() < 0.3])
		for c in city.houses:
			if c.chimney != Vector2.INF:
				city._chimneys.append(c.c + c.chimney.rotated(c.rot))

	func _process(delta: float) -> void:
		_time += delta
		for p in _people:
			var length: float = _lengths[p[0]]
			p[1] = float(p[1]) + float(p[2]) * delta / length
			if p[1] > 1.0 or p[1] < 0.0: # turn round at the end of the street
				p[1] = clampf(p[1], 0.0, 1.0)
				p[2] = -float(p[2])
		_smoke_timer -= delta
		if _smoke_timer <= 0.0 and not city._chimneys.is_empty():
			_smoke_timer = 0.12
			_smoke.append([city._chimneys.pick_random(), 0.0])
		for sm in _smoke:
			sm[1] += delta
		_smoke = _smoke.filter(func(sm: Array) -> bool: return sm[1] < 3.0)
		if Engine.get_process_frames() % 2 == 1: # every other frame (on the frames the animation skips)
			queue_redraw()

	func _at(route: PackedVector2Array, length: float, u: float) -> Vector2:
		var want := u * length
		for i in route.size() - 1:
			var seg := route[i].distance_to(route[i + 1])
			if want <= seg:
				return route[i].lerp(route[i + 1], want / maxf(seg, 0.001))
			want -= seg
		return route[route.size() - 1]

	func _draw() -> void:
		var cam := get_viewport().get_camera_2d()
		var focus := to_local(cam.get_screen_center_position()) if cam else Vector2.ZERO
		for sm in _smoke:
			var age: float = sm[1]
			var pos: Vector2 = sm[0] + Vector2(-age * 6.0 + sin(age * 2.0) * 2.0, -age * 9.0)
			if pos.distance_squared_to(focus) < 1000000.0:
				draw_circle(pos, 2.0 + age * 2.2, Color(0.75, 0.74, 0.72, 0.3 * (1.0 - age / 3.0)), true, -1.0, false)
		for p in _people:
			var pos := _at(city._routes[p[0]], _lengths[p[0]], p[1])
			if pos.distance_squared_to(focus) > 1000000.0:
				continue
			_person(pos, p[3], p[4], sin(_time * 10.0 + pos.x))
		for i in city._patrons.size():
			var pos: Vector2 = city._patrons[i]
			_person(pos, [Color(0.4, 0.25, 0.2), Color(0.28, 0.3, 0.38), Color(0.5, 0.42, 0.28)][i % 3], i % 2 == 0, sin(_time * 2.0 + i) * 0.5)

	func _person(pos: Vector2, cloth: Color, hat: bool, bob: float) -> void:
		draw_circle(pos + Vector2(1, 1.5), 2.8, Color(0, 0, 0, 0.22), true, -1.0, false)
		draw_circle(pos, 2.8, cloth, true, -1.0, false)
		draw_circle(pos + Vector2(0, bob * 0.4 - 0.5), 1.5, Color(0.92, 0.76, 0.6), true, -1.0, false)
		if hat:
			draw_circle(pos + Vector2(0, bob * 0.4 - 0.7), 1.6, Color(0.18, 0.14, 0.12), true, -1.0, false)


## A ship that sails in to its berth, stays a while, sails out to sea and away, and comes back
## later (just for the look: no fighting). path[0] is the berth, the last point far out at sea.
class HarborShip extends Node2D:
	var path: Array = []
	var _i := 0
	var _dir := 1
	var _wait := 0.0
	var _speed := 0.0
	var _visual: ShipVisual
	const CRUISE := 36.0

	func setup(config: Dictionary, at_sea: bool) -> void:
		_visual = ShipVisual.new()
		add_child(_visual)
		_visual.apply_config(config)
		if at_sea: # starts far out, on its way in
			_i = path.size() - 2
			_dir = -1
			position = path[path.size() - 1]
		else: # starts at its berth
			_i = 1
			position = path[0]
			_wait = randf_range(8.0, 20.0)
			rotation = (path[1] - path[0]).angle()

	func _process(delta: float) -> void:
		if _visual == null:
			return
		var target: Vector2 = path[_i]
		var to := target - position
		var last := _i == path.size() - 1
		if _wait > 0.0:
			_wait -= delta
			_speed = lerpf(_speed, 0.0, 1.0 - exp(-1.5 * delta))
			position += Vector2.from_angle(rotation) * _speed * delta
			_visual.update_motion(_speed, 0.0, 0.0, delta)
			if _wait <= 0.0:
				visible = true
			return
		if to.length() < 26.0:
			if last and _dir == 1: # far out at sea: gone for a while, then on the way back
				_dir = -1
				_wait = randf_range(30.0, 60.0)
				visible = false
				_speed = 0.0
			elif _i == 0 and _dir == -1: # at the berth: stay a while
				_dir = 1
				_wait = randf_range(25.0, 45.0)
			_i = clampi(_i + _dir, 0, path.size() - 1)
			return
		var slow := clampf(to.length() / 160.0, 0.35, 1.0) if _i == 0 else 1.0 # ease in to the berth
		_speed = lerpf(_speed, CRUISE * slow, 1.0 - exp(-0.8 * delta))
		var before := rotation
		rotation = lerp_angle(rotation, to.angle(), 1.0 - exp(-0.9 * delta))
		var turn := angle_difference(before, rotation) / maxf(delta, 0.001)
		position += Vector2.from_angle(rotation) * _speed * delta
		_visual.update_motion(_speed, 1.0, turn, delta)
