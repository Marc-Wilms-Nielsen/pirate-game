class_name WorldZones
extends Node
## The world's named areas (added by main.gd once the world is built).
##
## Each area has a centre: Sunhaven, every mainland, and SEA_ZONES points out in the open sea,
## placed as far as possible from everything else. A spot belongs to the area whose centre is
## "nearest", where the home waters and the mainlands count a little nearer than they are
## (their weight), so their waters reach further out. The borders between areas are straight
## lines, so each area is a convex polygon that the map can draw exactly – and zone_at() uses
## the very same rule, so what you see on the map is what the game uses.
##
## When the player stays in a new area for a moment, ZoneBanner shows its name.

signal zone_entered(index: int)

const SEA_ZONES := 9
const HOME_WEIGHT := 3500.0 ## px: how far the home waters reach out round Sunhaven
const MAINLAND_WEIGHT := 1.8 ## x a mainland's radius
const SETTLE_TIME := 1.0 ## seconds inside a new area before its name is shown (no flicker at borders)
const WARP_BIG := 900.0 ## px: the long, gentle bends of a border
const WARP_SMALL := 260.0 ## px: the finer unevenness on top
const WARP_LONG := 9000.0 ## px between the long bends
const WARP_SHORT := 1900.0 ## px between the small wiggles
const OUTLINE_STEP := 250.0 ## px: how finely the uneven borders are drawn
const TINT_STEP := 1500.0 ## px: the coarser outline the tint on the map is filled with

var zones: Array[Dictionary] = [] ## {name, subtitle, kind, center, weight, color, polygon, label_at}
var current := -1 ## the area the player is in (after settling)
var bounds := 0.0 ## half the size of the square the area shapes are cut from
var _pending := -1
var _pending_time := 0.0
var _think := 0.0
var _banner: ZoneBanner


func _ready() -> void:
	add_to_group("world_zones")
	build()
	_banner = ZoneBanner.new()
	add_child(_banner)


## Works out the areas from the world (deterministic: the same world gives the same areas).
func build() -> void:
	zones.clear()
	var radius := 1000.0
	for node in get_tree().get_nodes_in_group("islands"):
		var island := node as Island
		radius = maxf(radius, island.global_position.length() + island.radius)
	zones.append({"name": Catalog.ZONE_HOME["name"], "subtitle": Catalog.ZONE_HOME["subtitle"], "kind": "home",
		"center": Vector2.ZERO, "weight": HOME_WEIGHT, "color": Catalog.ZONE_HOME["color"]})
	# The mainlands: kingdoms by their castle, the wild ones in order round the world
	var mainlands: Array = get_tree().get_nodes_in_group("islands").filter(func(n: Node) -> bool: return (n as Island).radius > 1000.0)
	mainlands.sort_custom(func(a: Island, b: Island) -> bool: return a.global_position.angle() < b.global_position.angle())
	var wild := 0
	for node in mainlands:
		var island := node as Island
		var kingdom := _kingdom_on(island)
		if not kingdom.is_empty():
			zones.append({"name": Catalog.ZONE_KINGDOM_NAMES.get(kingdom["id"], kingdom["name"]), "subtitle": kingdom["name"],
				"kind": "kingdom", "center": island.global_position, "weight": island.radius * MAINLAND_WEIGHT, "color": kingdom["color"]})
		else:
			zones.append({"name": Catalog.ZONE_WILD_NAMES[wild % Catalog.ZONE_WILD_NAMES.size()], "subtitle": "Wild waters",
				"kind": "wild", "center": island.global_position, "weight": island.radius * MAINLAND_WEIGHT, "color": Catalog.ZONE_WILD_COLOR})
			wild += 1
	# Open sea: the spots furthest from every area so far (a grid of candidates inside the world)
	var candidates: Array[Vector2] = []
	var step := radius / 9.0
	for gx in range(-9, 10):
		for gy in range(-9, 10):
			var c := Vector2(gx, gy) * step
			if c.length() < radius * 0.95:
				candidates.append(c)
	for k in SEA_ZONES:
		var best := Vector2.ZERO
		var best_score := -INF
		for c in candidates:
			var score := INF
			for z in zones:
				score = minf(score, c.distance_to(z["center"]) - float(z["weight"]))
			if score > best_score:
				best_score = score
				best = c
		zones.append({"name": Catalog.ZONE_SEA_NAMES[k % Catalog.ZONE_SEA_NAMES.size()], "subtitle": "Open sea", "kind": "sea",
			"center": best, "weight": 0.0, "color": Catalog.ZONE_SEA_COLORS[k % Catalog.ZONE_SEA_COLORS.size()]})
	# Each area's shape: the world's square cut by the border line to every other area
	var b := radius * 1.15
	bounds = b
	for i in zones.size():
		var poly := PackedVector2Array([Vector2(-b, -b), Vector2(b, -b), Vector2(b, b), Vector2(-b, b)])
		for j in zones.size():
			if i != j:
				poly = _clip(poly, i, j)
		zones[i]["polygon"] = poly
		zones[i]["label_at"] = unwarp(_label_spot(i, poly))
		# The uneven border as it lies in the world (see warp): each straight edge in many
		# small steps, moved back by the warp. "edges" leaves out the world's outer frame.
		var outline := PackedVector2Array()
		var edges: Array[PackedVector2Array] = []
		for k in poly.size():
			var a := poly[k]
			var bb := poly[(k + 1) % poly.size()]
			var frame := (absf(a.x) > b * 0.999 and absf(bb.x) > b * 0.999) or (absf(a.y) > b * 0.999 and absf(bb.y) > b * 0.999)
			var steps := maxi(1, ceili(a.distance_to(bb) / OUTLINE_STEP))
			var edge := PackedVector2Array()
			for s in steps + 1:
				var p := unwarp(a.lerp(bb, float(s) / steps))
				edge.append(p)
				if s < steps:
					outline.append(p)
			if not frame:
				edges.append(edge)
		zones[i]["outline"] = outline
		zones[i]["edges"] = edges
		# The tint needs a shape Godot can fill; where a bend makes the outline cross itself
		# (near a sharp corner), the tint uses the straight shape and only the line is uneven
		var coarse := _outline(poly, TINT_STEP) # fewer points: the fine outline has too many nearly straight ones to fill
		zones[i]["tint"] = coarse if not Geometry2D.triangulate_polygon(coarse).is_empty() else poly
	# Open sea is named after who trades there
	for z in zones:
		if z["kind"] == "sea":
			z["subtitle"] = _sea_subtitle(zones.find(z))
	# Names that promise something should keep it: Smuggler's Run goes to pirate waters
	_match_name("Smuggler's Run", "Pirate waters")


## The uneven outline of a straight-edged area, in steps of about `step` px.
func _outline(poly: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in poly.size():
		var a := poly[k]
		var bb := poly[(k + 1) % poly.size()]
		var steps := maxi(1, ceili(a.distance_to(bb) / step))
		for s in steps:
			out.append(unwarp(a.lerp(bb, float(s) / steps)))
	return out


## Swaps names so that `zone_name` ends up on an area with this subtitle (if there is one).
func _match_name(zone_name: String, subtitle: String) -> void:
	var holder := -1
	var fit := -1
	for i in zones.size():
		if zones[i]["kind"] != "sea":
			continue
		if zones[i]["name"] == zone_name:
			holder = i
		elif fit < 0 and zones[i]["subtitle"] == subtitle:
			fit = i
	if holder >= 0 and fit >= 0 and zones[holder]["subtitle"] != subtitle:
		var n: String = zones[fit]["name"]
		zones[fit]["name"] = zones[holder]["name"]
		zones[holder]["name"] = n


## The area at a world position (same rule as the borders on the map).
func zone_at(pos: Vector2) -> int:
	var q := pos + warp(pos) # the borders wander a little, like real ones
	var best := -1
	var best_d := INF
	for i in zones.size():
		var d := _power(q, i)
		if d < best_d:
			best_d = d
			best = i
	return best


func zone_name_at(pos: Vector2) -> String:
	var i := zone_at(pos)
	return "" if i < 0 else String(zones[i]["name"])


## Makes the borders uneven, like real ones: a spot is judged a little to one side of where it
## is, by two layers of gentle waves (one long and slow, one shorter and finer). Smooth and the
## same every time, so a border always runs the same way.
static func warp(p: Vector2) -> Vector2:
	var k1 := TAU / WARP_LONG
	var k2 := TAU / WARP_SHORT
	return Vector2(
		WARP_BIG * sin(p.y * k1 + 1.3) + WARP_SMALL * sin(p.y * k2 * 1.1 + p.x * k2 * 0.4 + 4.1),
		WARP_BIG * sin(p.x * k1 * 0.9 + 2.7) + WARP_SMALL * sin(p.x * k2 * 1.05 - p.y * k2 * 0.3 + 0.6))


## The world spot p whose warped position is q (so a straight border line, unwarped, gives the
## uneven border as it really lies). A few rounds of p = q - warp(p) settle on it.
static func unwarp(q: Vector2) -> Vector2:
	var p := q - warp(q)
	for i in 4:
		p = q - warp(p)
	return p


func _power(p: Vector2, i: int) -> float:
	var z: Dictionary = zones[i]
	return p.distance_squared_to(z["center"]) - pow(float(z["weight"]), 2.0)


## Keeps the part of the polygon that is nearer area i than area j: n·p <= c.
func _clip(poly: PackedVector2Array, i: int, j: int) -> PackedVector2Array:
	var si: Vector2 = zones[i]["center"]
	var sj: Vector2 = zones[j]["center"]
	var n := (sj - si) * 2.0
	var c := sj.length_squared() - si.length_squared() - pow(float(zones[j]["weight"]), 2.0) + pow(float(zones[i]["weight"]), 2.0)
	var out := PackedVector2Array()
	for k in poly.size():
		var a := poly[k]
		var bb := poly[(k + 1) % poly.size()]
		var da := n.dot(a) - c
		var db := n.dot(bb) - c
		if da <= 0.0:
			out.append(a)
		if (da <= 0.0) != (db <= 0.0):
			out.append(a.lerp(bb, da / (da - db)))
	return out


## Where to write the name: the middle of the area's sea part (its centre for small areas).
func _label_spot(i: int, poly: PackedVector2Array) -> Vector2:
	if poly.size() < 3:
		return zones[i]["center"]
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	var mid := sum / poly.size()
	if zones[i]["kind"] == "sea":
		return mid
	# Mainland (and home) names go out on the water, past the coast, so they don't cover the
	# island's own labels (the kingdom's castle, Sunhaven)
	var center: Vector2 = zones[i]["center"]
	if zones[i]["kind"] == "home": # the home waters lie all round Sunhaven: put the name south of it
		return center + Vector2(0, float(zones[i]["weight"]) * 1.3)
	var dir := (mid - center).normalized() if mid.distance_to(center) > 1.0 else Vector2.DOWN
	var out := maxf(mid.distance_to(center) * 0.9, float(zones[i]["weight"]) * 1.05)
	return center + dir * out


func _kingdom_on(island: Island) -> Dictionary:
	for node in get_tree().get_nodes_in_group("castles"):
		var castle := node as Castle
		if castle.global_position.distance_to(island.global_position) < island.radius * 1.2:
			return castle.kingdom()
	return {}


func _sea_subtitle(i: int) -> String:
	var counts := {}
	for node in get_tree().get_nodes_in_group("harbors"):
		var h := node as Harbor
		if h.kind != "home" and zone_at(h.global_position) == i:
			var f := Game.faction_of(h.harbor_name)
			counts[f] = int(counts.get(f, 0)) + 1
	if counts.is_empty():
		return "Open sea"
	var top := ""
	for f in counts:
		if top == "" or int(counts[f]) > int(counts[top]):
			top = f
	return {"smugglers": "Pirate waters", "free": "Free waters"}.get(top, "Royal waters")


# --- Following the player ----------------------------------------------------------

func _process(delta: float) -> void:
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.2
	var here := zone_at(_focus())
	if here == current:
		_pending = -1
		return
	if here != _pending:
		_pending = here
		_pending_time = 0.0
		return
	_pending_time += 0.2
	if _pending_time >= SETTLE_TIME and here >= 0:
		current = here
		_pending = -1
		zone_entered.emit(current)
		_banner.show_zone(zones[current])


## The captain on foot, or the ship.
func _focus() -> Vector2:
	var player := get_tree().get_first_node_in_group("player_character") as Node2D
	if player:
		return player.global_position
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	return ship.global_position if ship else Vector2.ZERO
