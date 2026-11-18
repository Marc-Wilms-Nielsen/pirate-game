class_name ShipVisual
extends Node2D
## Alt det visuelle ved et skib: skrog, sejl, skygge, kølvand, kanoner og pynt.
## Tegnes af ShipDrawer ud fra skibstypens "look" i Catalog.SHIPS.
## Bruges af både spillerens skib og fjendeskibe. Lokalt peger stævnen mod +x.

var look: Dictionary = {}
var size: float = 1.0 ## længde i forhold til en slup (bruges til kamera og effekter)
var cannons_per_side: int = 1
var sail_color := Color.WHITE
var hull_color := Color.WHITE
var flag_color := Color(0.12, 0.12, 0.12)
var flag_style: String = "small"
var decorations: Dictionary = {}
var deck_boxes: Array = [] ## kassetyper der står på dækket (vises oppefra)

var _time: float = 0.0
var _sail_visual: float = 0.0
var _speed: float = 0.0
var _body: Node2D
var _shadow: Layer
var _hull: Layer
var _sails: Layer
var _wake: Wake
var _soft_dot: GradientTexture2D
var _recoil := {"left": 0.0, "right": 0.0}


static func collision_for(type: String) -> PackedVector2Array:
	return ShipDrawer.collision_polygon(Catalog.SHIPS[type]["look"])


func _ready() -> void:
	if look.is_empty():
		look = Catalog.SHIPS["sloop"]["look"]
	_shadow = Layer.new()
	_shadow.top_level = true
	_shadow.z_index = -1
	_shadow.draw_fn = func(ci: Node2D) -> void:
		ci.draw_colored_polygon(ShipDrawer.hull_points(look), Color(0, 0, 0, 0.25))
	add_child(_shadow)

	_body = Node2D.new()
	add_child(_body)
	_hull = Layer.new()
	_hull.draw_fn = func(ci: Node2D) -> void:
		ShipDrawer.draw_hull(ci, look, hull_color, _time, _speed / 60.0)
		ShipDrawer.draw_cannons(ci, look, cannons_per_side, _recoil)
		ShipDrawer.draw_decorations(ci, look, decorations, flag_color, _time, false)
		ShipDrawer.draw_deck_boxes(ci, look, deck_boxes)
	_body.add_child(_hull)
	_sails = Layer.new()
	_sails.draw_fn = func(ci: Node2D) -> void:
		ShipDrawer.draw_sails(ci, look, sail_color, _sail_visual, _time)
		ShipDrawer.draw_decorations(ci, look, decorations, flag_color, _time, true, flag_style)
	_body.add_child(_sails)

	_soft_dot = _make_soft_dot()
	_wake = Wake.new()
	add_child(_wake)
	_place_wake()


## Sætter udseende ud fra en skibskonfiguration (se Game.new_ship_config).
func apply_config(config: Dictionary) -> void:
	var ship: Dictionary = Catalog.SHIPS[config["type"]]
	look = ship["look"]
	size = float(look["length"]) / 58.0
	cannons_per_side = config.get("cannons", 1)
	sail_color = _lookup(Catalog.SAIL_COLORS, config.get("sail", "canvas"))
	hull_color = _lookup(Catalog.HULL_PAINTS, config.get("hull", "oak"))
	flag_color = _lookup(Catalog.FLAG_COLORS, config.get("flag", "black"))
	decorations = config.get("decorations", {})
	flag_style = config.get("flag_style", "small")
	if _hull:
		_place_wake()
		_hull.queue_redraw()
		_shadow.queue_redraw()


func set_deck_boxes(types: Array) -> void:
	if types == deck_boxes:
		return
	deck_boxes = types
	if _hull:
		_hull.queue_redraw()


func _place_wake() -> void:
	var length: float = look["length"]
	var beam: float = look["beam"]
	_wake.length = length
	_wake.beam = beam


## Kaldes hvert frame af skibet, der ejer visual'et.
func update_motion(speed: float, sail_factor: float, turn_velocity: float, delta: float) -> void:
	_time += delta
	_speed = speed
	_sail_visual = lerpf(_sail_visual, sail_factor, 1.0 - exp(-2.5 * delta))
	_body.rotation = sin(_time * 1.3) * 0.025 + turn_velocity * 0.06
	_body.scale = Vector2.ONE * (1.0 + sin(_time * 1.7) * 0.012)

	_shadow.global_position = global_position + Vector2(3, 5) * size
	_shadow.global_rotation = _body.global_rotation
	_shadow.global_scale = _body.global_scale
	_shadow.visible = visible

	_wake.track(global_position, global_transform.x.normalized(), speed, delta, visible and _body.modulate.a > 0.9)
	for side in _recoil:
		_recoil[side] = maxf(_recoil[side] - delta * 3.0, 0.0)
	_sails.queue_redraw()
	if look.get("oars", false) or _recoil["left"] > 0.0 or _recoil["right"] > 0.0 or decorations.get("lanterns", false):
		_hull.queue_redraw()


func cannon_positions(side: String) -> Array[Vector2]:
	return ShipDrawer.cannon_positions(look, cannons_per_side, side)


func fire_effect(side: String) -> void:
	for p in cannon_positions(side):
		fire_effect_at(side, p)


## Bredside: kanonerne går af én efter én med små, ujævne mellemrum – som en rigtig bredside.
## spawn.call(index) laver selve kuglen for kanon nummer index.
func broadside(side: String, count: int, spawn: Callable, volume_db := -4.0) -> void:
	var delay := randf_range(0.12, 0.22) # lunten brænder lige et øjeblik
	var order: Array = range(count)
	order.shuffle() # kanonerne går af i tilfældig rækkefølge – ikke fra den ene ende til den anden
	for i in order:
		get_tree().create_timer(delay, false).timeout.connect(_fire_one.bind(side, i, spawn, volume_db))
		delay += randf_range(0.05, 0.16) + (0.12 if randf() < 0.15 else 0.0) # en enkelt kanon nøler af og til


func _fire_one(side: String, index: int, spawn: Callable, volume_db: float) -> void:
	var positions := cannon_positions(side)
	if index >= positions.size():
		return
	spawn.call(index)
	fire_effect_at(side, positions[index])
	Sfx.play_at("cannon", global_position, volume_db + randf_range(-4.0, 0.0))


## Røg, mundingsglimt og rekyl fra én kanon.
func fire_effect_at(side: String, p: Vector2) -> void:
	_recoil[side] = 1.0
	if not Settings.effects:
		return
	var dir := Vector2.UP if side == "left" else Vector2.DOWN
	Fx.muzzle_flash(self, p + dir * 4.0, dir)
	var smoke := CPUParticles2D.new()
	smoke.texture = _soft_dot
	smoke.one_shot = true
	smoke.amount = 10
	smoke.lifetime = 1.4
	smoke.explosiveness = 0.95
	smoke.local_coords = false
	smoke.direction = dir
	smoke.spread = 30.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 45.0
	smoke.damping_min = 25.0
	smoke.damping_max = 35.0
	smoke.scale_amount_min = 0.3
	smoke.scale_amount_max = 0.6
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.95, 0.9, 0.8))
	g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	smoke.color_ramp = g
	smoke.position = p + dir * 3.0
	smoke.z_index = 5
	add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)


## Synker skibet (0 = flyder, 1 = væk).
func set_sinking(progress: float) -> void:
	_body.modulate = Color(1, 1, 1, 1.0 - progress).lerp(Color(0.4, 0.5, 0.6, 1.0 - progress), progress)
	_body.scale = Vector2.ONE * (1.0 - progress * 0.3)
	_body.rotation = progress * 0.6
	_shadow.modulate.a = 1.0 - progress
	_wake.modulate.a = 1.0 - progress


func _lookup(list: Array, id: String) -> Color:
	for entry in list:
		if entry["id"] == id:
			return entry["color"]
	return list[0]["color"]


func _make_soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## Et lag der tegner med en funktion.
class Layer extends Node2D:
	var draw_fn: Callable

	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)
