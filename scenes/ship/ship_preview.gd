class_name ShipPreview
extends Control
## A drawing of a ship for shops and menus. With `detailed` on (the Looks editor) it shows the
## whole style: deck, stripe, railing, cabin, emblem, flag and decorations, lantern glow, a
## wake in the chosen colour and the captain at the helm, gently rocking on the sea.

var type: String = "sloop"
var config: Dictionary = {}
var detailed := false
var _time: float = 0.0


func _init(ship_type := "sloop", ship_config := {}) -> void:
	type = ship_type
	config = ship_config
	custom_minimum_size = Vector2(130, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows these choices (the editor passes the options you are trying on).
func show_values(values: Dictionary) -> void:
	config = values
	type = String(values.get("type", type))
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.42, 0.6, 0.6) if not detailed else Color(0.07, 0.3, 0.46))
	var look: Dictionary = Catalog.SHIPS[type]["look"]
	var length: float = look["length"]
	var s := minf((size.x - 16.0) / length, (size.y - 6.0) / (look["beam"] * 2.6))
	var center := size * 0.5
	if detailed:
		# Room for the bowsprit and jib in front of the hull, which shifts the ship back a little
		s = minf((size.x - 16.0) / (length * 1.3), (size.y - 20.0) / (look["beam"] * 2.8))
		center.x -= length * 0.1 * s
	s = minf(s, 1.4 if not detailed else 5.0)
	var style := ShipDrawer.style_of(config)
	if detailed:
		_draw_sea(look, s, style, center)
	var rock := sin(_time * 1.3) * 0.025 if detailed else 0.0
	draw_set_transform(center, rock, Vector2(s, s))
	var decorations: Dictionary = config.get("decorations", {})
	if detailed:
		draw_colored_polygon(ShipDrawer.hull_points(look), Color(0, 0, 0, 0.25)) # shadow
	ShipDrawer.draw_hull(self, look, style["hull"], _time, 0.5, style)
	ShipDrawer.draw_cannons(self, look, int(config.get("cannons", Catalog.SHIPS[type]["max_cannons"])), {}, style["cannon"])
	if detailed:
		ShipDrawer.draw_decorations(self, look, decorations, style["flag"], _time, false, style["flag_style"], style["lantern"])
		ShipDrawer.draw_helm(self, look)
		var cap := CaptainDrawer.current()
		var facing := Vector2.RIGHT.rotated(sin(_time * 0.9) * 0.12)
		draw_set_transform(center + ShipDrawer.helm_position(look).rotated(rock) * s, rock, Vector2(s, s) * 0.72)
		CaptainDrawer.draw_body(self, cap, facing, 0.0)
		CaptainDrawer.draw_head(self, cap, facing * 0.7, facing, 1.0, _time)
		draw_set_transform(center, rock, Vector2(s, s))
	# Half sail in the editor, so the deck, the cabin and the captain stay in view
	ShipDrawer.draw_sails(self, look, style["sail"], 0.55 if detailed else 1.0, _time, style["emblem"], style["emblem_color"])
	if detailed:
		ShipDrawer.draw_decorations(self, look, decorations, style["flag"], _time, true, style["flag_style"], style["lantern"])
	draw_set_transform(Vector2.ZERO)


## Gentle waves and a wake trailing behind the ship, in the chosen wake colour.
func _draw_sea(look: Dictionary, s: float, style: Dictionary, center: Vector2) -> void:
	for i in 14:
		var y := fmod(i * 37.0 + _time * 6.0, size.y)
		var x := fmod(i * 71.0 + sin(_time * 0.7 + i) * 8.0, size.x)
		draw_line(Vector2(x, y), Vector2(x + 14.0, y + 1.0), Color(1, 1, 1, 0.08), 1.0, true)
	var wake: Color = style["wake"]
	var stern := center - Vector2(float(look["length"]) * 0.46 * s, 0)
	for k in 10:
		var t := k / 9.0
		var p := stern - Vector2(t * size.x * 0.42, sin(_time * 2.0 + t * 4.0) * 2.0)
		draw_circle(p, (2.0 + t * 5.0) * s * 0.35, Color(wake, 0.35 * (1.0 - t)), true, -1.0, true)
	if config.get("decorations", {}).get("lanterns", false): # their light on the water
		for y in [-1.0, 1.0]:
			var lp := center + Vector2(-float(look["length"]) * 0.45, float(look["beam"]) * 0.65 * y) * s
			draw_circle(lp, 9.0 * s, Color(style["lantern"], 0.12), true, -1.0, true)
