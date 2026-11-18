class_name ShipPreview
extends Control
## Lille tegning af et skib til butikker og menuer.

var type: String = "sloop"
var config: Dictionary = {}
var _time: float = 0.0


func _init(ship_type := "sloop", ship_config := {}) -> void:
	type = ship_type
	config = ship_config
	custom_minimum_size = Vector2(130, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.42, 0.6, 0.6))
	var look: Dictionary = Catalog.SHIPS[type]["look"]
	var length: float = look["length"]
	var s := minf((size.x - 16.0) / length, (size.y - 6.0) / (look["beam"] * 2.6))
	s = minf(s, 1.4)
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var paint := Color.WHITE
	var sail := Color.WHITE
	if not config.is_empty():
		paint = _find(Catalog.HULL_PAINTS, config.get("hull", "oak"))
		sail = _find(Catalog.SAIL_COLORS, config.get("sail", "canvas"))
	ShipDrawer.draw_hull(self, look, paint, _time, 0.5)
	ShipDrawer.draw_cannons(self, look, int(config.get("cannons", Catalog.SHIPS[type]["max_cannons"])), {})
	ShipDrawer.draw_sails(self, look, sail, 1.0, _time)
	draw_set_transform(Vector2.ZERO)


func _find(list: Array, id: String) -> Color:
	for e in list:
		if e["id"] == id:
			return e["color"]
	return Color.WHITE
