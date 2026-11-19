class_name Harbor
extends Node2D
## En havn: mole, huse, flag og en kajzone. Sejl ind i zonen langsomt og tryk F for at lægge til.
## Lokalt koordinatsystem: +x peger ud mod havet.

const PIER_LENGTH := 110.0
const DOCK_RADIUS := 80.0

var harbor_name: String = "Harbor"
var kind: String = "trade" ## "trade" eller "pirate"
var city: String = "" ## "royal" or "pirate" when a BigCity is built round this harbor (it draws the quays)

var _flag_time: float = 0.0
var _flag: Polygon2D


func _ready() -> void:
	add_to_group("harbors")
	_build_visuals()
	WorldSky.add_lantern(self, Vector2(PIER_LENGTH, 0), 80.0)
	WorldSky.add_lantern(self, Vector2(-25, 0), 150.0, Color(1.0, 0.78, 0.5), 0.8)
	_build_dock_zone()
	var label := HarborLabel.new()
	label.text = harbor_name
	label.subtitle = "Pirate harbor" if kind == "pirate" else "Trade harbor"
	if city != "":
		label.subtitle = "Pirate city" if city == "pirate" else "Royal capital"
	if kind == "home":
		label.home = true
	label.position = Vector2(PIER_LENGTH * 0.5, 0)
	add_child(label)


func _process(delta: float) -> void:
	_flag_time += delta
	if _flag:
		_flag.skew = sin(_flag_time * 3.0) * 0.15


## Hvor skibet placeres, når det lægger til (eller vågner efter et forlis).
func dock_position() -> Vector2:
	return to_global(Vector2(PIER_LENGTH + 45.0, 28.0))


func dock_rotation() -> float:
	return global_rotation + PI * 0.5


func _build_dock_zone() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4 # skibe
	area.position = Vector2(PIER_LENGTH + 20.0, 0)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = DOCK_RADIUS
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player_ship"):
			Game.current_harbor = self)
	area.body_exited.connect(func(body: Node) -> void:
		if body.is_in_group("player_ship") and Game.current_harbor == self:
			Game.current_harbor = null)


func _build_visuals() -> void:
	if city != "": # BigCity draws the stone quays, moles and the town
		_build_flag()
		return
	var wood := Color(0.55, 0.38, 0.22)
	var dark_wood := Color(0.38, 0.25, 0.14)
	# Skygge + mole
	_rect(Rect2(-10, -9 + 4, PIER_LENGTH + 10, 18), Color(0, 0, 0, 0.18), 3)
	_rect(Rect2(-10, -9, PIER_LENGTH + 10, 18), wood)
	for i in range(0, int(PIER_LENGTH), 8):
		_rect(Rect2(i - 10, -9, 1.2, 18), dark_wood)
	# Pæle
	for x in [20.0, 55.0, 90.0, PIER_LENGTH - 2.0]:
		for y in [-10.0, 10.0]:
			_circle(Vector2(x, y), 2.5, dark_wood)
	# Tværmole for enden
	_rect(Rect2(PIER_LENGTH - 16, -26, 14, 52), wood)

	if kind == "home":
		_build_flag()
		return # hjemøens huse og marker tegnes af HomeSite
	# Huse inde på land (lokalt -x)
	var roof_colors := [Color(0.72, 0.30, 0.22), Color(0.55, 0.35, 0.25), Color(0.30, 0.45, 0.55)]
	if kind == "pirate":
		roof_colors = [Color(0.25, 0.22, 0.22), Color(0.40, 0.25, 0.20), Color(0.30, 0.28, 0.25)]
	var houses := [Rect2(-46, -34, 26, 20), Rect2(-50, 10, 30, 22), Rect2(-84, -14, 28, 26), Rect2(-80, 22, 22, 18)]
	for i in houses.size():
		var r: Rect2 = houses[i]
		_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.2))
		_rect(Rect2(r.position - Vector2(1, 1), r.size + Vector2(2, 2)), Color(0.85, 0.80, 0.70))
		_rect(r, roof_colors[i % roof_colors.size()])
		# Tagryg
		_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5 - 1), Vector2(r.size.x, 2)), roof_colors[i % roof_colors.size()].darkened(0.25))

	_build_flag()


func _build_flag() -> void:
	var dark_wood := Color(0.38, 0.25, 0.14)
	# Flagstang og flag
	_circle(Vector2(PIER_LENGTH - 9, -22), 1.8, dark_wood)
	_flag = Polygon2D.new()
	_flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(14, 9), Vector2(0, 9)])
	_flag.color = Color(0.1, 0.1, 0.1) if kind == "pirate" else (Color(0.3, 0.7, 0.35) if kind == "home" else Color(0.85, 0.85, 0.95))
	_flag.position = Vector2(PIER_LENGTH - 9, -22)
	_flag.antialiased = true
	add_child(_flag)
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([Vector2(0, 3), Vector2(14, 3), Vector2(14, 6), Vector2(0, 6)])
	stripe.color = Color(0.9, 0.9, 0.9) if kind == "pirate" else Color(0.2, 0.35, 0.7)
	_flag.add_child(stripe)


func _rect(r: Rect2, color: Color, z := 0) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	p.color = color
	p.antialiased = true
	p.z_index = z
	add_child(p)


func _circle(center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(center + Vector2.from_angle(TAU * i / 12.0) * r)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	p.antialiased = true
	add_child(p)


## Havnens navn – altid vandret, uanset hvordan havnen er drejet.
class HarborLabel extends Node2D:
	var text: String = ""
	var subtitle: String = ""
	var home := false

	func _process(_delta: float) -> void:
		global_rotation = 0.0
		if home:
			text = "Your home" if Homestead.claimed else "Deserted island – for sale"
			subtitle = "Fields, workshop and storage" if Homestead.claimed else "%d gold · dock here" % Catalog.HOME_PRICE
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string_outline(font, Vector2(-w * 0.5, -40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(-w * 0.5, -40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		var w2 := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string_outline(font, Vector2(-w2 * 0.5, -29), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(-w2 * 0.5, -29), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.8))
