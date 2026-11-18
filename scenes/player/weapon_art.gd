class_name WeaponArt
## Tegner nærkampsvåben (sabler, økser, køller, spyd ...) ud fra "look" i Catalog.GEAR.
## Bruges af kaptajnen, ikonerne og duel-arenaen, så våbnet ser ens ud overalt.
## hand: hvor hånden holder · dir: retning våbnet peger (enhedsvektor) · s: skala

const WOOD := Color(0.48, 0.32, 0.18)
const GRIP := Color(0.3, 0.2, 0.12)
const BRASS := Color(0.85, 0.66, 0.25)


static func draw(ci: CanvasItem, look: Dictionary, hand: Vector2, dir: Vector2, s := 1.0) -> void:
	var length: float = float(look.get("length", 10.0)) * s
	var width: float = float(look.get("width", 1.4)) * s
	var col: Color = look.get("color", Color(0.85, 0.87, 0.9))
	var side := dir.orthogonal()
	var tip := hand + dir * length
	match String(look.get("type", "saber")):
		"saber", "scimitar", "katana", "machete", "falchion":
			var curve := {"saber": 0.12, "scimitar": 0.22, "katana": 0.08, "machete": 0.05, "falchion": 0.14}[look.get("type", "saber")] as float
			var wide := {"machete": 1.6, "falchion": 1.5, "scimitar": 1.25}.get(look.get("type", "saber"), 1.0) as float
			var pts := PackedVector2Array()
			var back := PackedVector2Array()
			for i in 7:
				var t := i / 6.0
				var bend := side * (sin(t * PI * 0.5) * curve * length)
				var w := width * wide * (1.0 - t * 0.75)
				pts.append(hand + dir * length * t + bend + side * w * 0.5)
				back.append(hand + dir * length * t + bend - side * w * 0.5)
			back.reverse()
			_blade(ci, pts + back, col)
			_hilt(ci, hand, dir, side, s, look.get("type", "saber") != "machete")
		"rapier":
			_line(ci, hand, tip, col, width * 0.8)
			_shine(ci, hand + dir * 2.0 * s, tip - dir * 2.0 * s, side * 0.2)
			ci.draw_arc(hand + dir * 0.5 * s, 2.4 * s, dir.angle() + PI * 0.5, dir.angle() + PI * 1.5, 10, BRASS, 1.2 * s, true)
			_line(ci, hand, hand - dir * 3.0 * s, GRIP, 1.6 * s)
		"dagger":
			_blade(ci, PackedVector2Array([hand + side * width * 0.7, tip, hand - side * width * 0.7]), col)
			_hilt(ci, hand, dir, side, s * 0.7, true)
		"straight", "claymore":
			var w := width * (1.4 if look.get("type") == "claymore" else 1.0)
			_blade(ci, PackedVector2Array([hand + side * w * 0.5, tip - dir * w + side * w * 0.5, tip, tip - dir * w - side * w * 0.5, hand - side * w * 0.5]), col)
			_hilt(ci, hand, dir, side, s * (1.4 if look.get("type") == "claymore" else 1.0), true)
		"axe", "great_axe":
			_line(ci, hand - dir * 2.0 * s, tip, WOOD, 1.6 * s)
			var big := 1.6 if look.get("type") == "great_axe" else 1.0
			var head := tip - dir * 2.5 * s
			_blade(ci, PackedVector2Array([head + dir * 2.0 * s, head + side * 5.0 * s * big + dir * 3.0 * s * big, head + side * 5.5 * s * big - dir * 3.0 * s * big, head - dir * 2.0 * s]), col)
			if big > 1.2:
				_blade(ci, PackedVector2Array([head + dir * 2.0 * s, head - side * 5.0 * s * big + dir * 3.0 * s * big, head - side * 5.5 * s * big - dir * 3.0 * s * big, head - dir * 2.0 * s]), col)
		"mace", "morning_star":
			_line(ci, hand - dir * 2.0 * s, tip - dir * 2.0 * s, WOOD.darkened(0.2), 1.6 * s)
			var r := 2.6 * s
			if look.get("type") == "morning_star":
				for i in 8:
					var a := TAU * i / 8.0
					_line(ci, tip, tip + Vector2.from_angle(a) * r * 1.8, STEEL_DARK, 0.9 * s)
			ci.draw_circle(tip, r, col, true, -1.0, true)
			ci.draw_circle(tip - (dir + side) * r * 0.35, r * 0.35, Color(1, 1, 1, 0.55), true, -1.0, true)
		"hammer":
			_line(ci, hand - dir * 2.0 * s, tip, WOOD, 1.6 * s)
			var hp := tip - dir * 1.5 * s
			ci.draw_colored_polygon(PackedVector2Array([hp + side * 4.5 * s + dir * 2.0 * s, hp + side * 4.5 * s - dir * 2.0 * s, hp - side * 4.5 * s - dir * 2.0 * s, hp - side * 4.5 * s + dir * 2.0 * s]), col)
			_line(ci, hp + side * 4.0 * s + dir * 1.6 * s, hp - side * 4.0 * s + dir * 1.6 * s, Color(1, 1, 1, 0.45), 0.7 * s)
		"club":
			ci.draw_colored_polygon(PackedVector2Array([hand + side * 0.8 * s, tip + side * 2.2 * s, tip + dir * 1.5 * s, tip - side * 2.2 * s, hand - side * 0.8 * s]), col)
			_line(ci, hand + dir * 2.0 * s, tip, col.lightened(0.25), 0.6 * s)
		"spear", "harpoon", "trident":
			_line(ci, hand - dir * 6.0 * s, tip - dir * 3.0 * s, WOOD, 1.3 * s)
			if look.get("type") == "trident":
				for k in [-1.0, 0.0, 1.0]:
					var base: Vector2 = tip - dir * 4.0 * s + side * k * 2.2 * s
					_line(ci, base, base + dir * 5.0 * s, col, 0.9 * s)
				_line(ci, tip - dir * 4.0 * s + side * 2.4 * s, tip - dir * 4.0 * s - side * 2.4 * s, col, 1.0 * s)
			else:
				_blade(ci, PackedVector2Array([tip - dir * 4.5 * s + side * 1.6 * s, tip + dir * 1.5 * s, tip - dir * 4.5 * s - side * 1.6 * s]), col)
				if look.get("type") == "harpoon":
					_line(ci, tip - dir * 3.5 * s + side * 1.3 * s, tip - dir * 6.0 * s + side * 2.6 * s, col, 0.8 * s)
					_line(ci, tip - dir * 3.5 * s - side * 1.3 * s, tip - dir * 6.0 * s - side * 2.6 * s, col, 0.8 * s)
		"flail":
			_line(ci, hand - dir * 1.5 * s, hand + dir * 5.0 * s, WOOD, 1.6 * s)
			var chain_end := tip + side * sin(Time.get_ticks_msec() * 0.01) * 2.0 * s
			_line(ci, hand + dir * 5.0 * s, chain_end, Color(0.55, 0.55, 0.6), 0.7 * s)
			ci.draw_circle(chain_end, 2.4 * s, col, true, -1.0, true)
			for i in 6:
				var a := TAU * i / 6.0
				_line(ci, chain_end, chain_end + Vector2.from_angle(a) * 3.6 * s, STEEL_DARK, 0.8 * s)
		"hook":
			_line(ci, hand - dir * 2.0 * s, hand + dir * length * 0.5, col, 1.2 * s)
			ci.draw_arc(hand + dir * length * 0.5 + side * 2.0 * s, 2.0 * s, dir.angle() - PI * 0.5, dir.angle() + PI * 0.9, 10, col, 1.2 * s, true)
			ci.draw_circle(hand - dir * 2.0 * s, 2.2 * s, Color(0.35, 0.22, 0.12), true, -1.0, true)
		"anchor":
			_line(ci, hand - dir * 2.0 * s, tip, Color(0.4, 0.4, 0.44), 1.6 * s)
			ci.draw_arc(tip - dir * 2.0 * s, 4.0 * s, dir.angle() - PI * 0.5 - 1.2, dir.angle() - PI * 0.5 + 1.2, 12, col, 1.6 * s, true)
			ci.draw_arc(tip - dir * 2.0 * s, 4.0 * s, dir.angle() + PI * 0.5 - 1.2, dir.angle() + PI * 0.5 + 1.2, 12, col, 1.6 * s, true)
			_line(ci, hand + dir * 2.0 * s + side * 2.5 * s, hand + dir * 2.0 * s - side * 2.5 * s, col, 1.2 * s)
		_:
			_line(ci, hand, tip, col, width)
	if look.has("glow"):
		ci.draw_circle(tip - dir * length * 0.3, 2.5 * s, Color(look["glow"], 0.35), true, -1.0, true)


const STEEL_DARK := Color(0.45, 0.47, 0.52)


## Klinge med mørk kant og et lyst glimt langs midten – ser skarpere og blankere ud.
static func _blade(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, col.darkened(0.45), 0.5, true)
	if pts.size() >= 3:
		var a := (pts[0] + pts[pts.size() - 1]) * 0.5
		var b := pts[floori(pts.size() / 2.0)]
		ci.draw_line(a.lerp(b, 0.15), a.lerp(b, 0.75), Color(1, 1, 1, 0.65), 0.5, true)


static func _shine(ci: CanvasItem, a: Vector2, b: Vector2, offset: Vector2) -> void:
	ci.draw_line(a + offset, b + offset, Color(1, 1, 1, 0.6), 0.4, true)


static func _hilt(ci: CanvasItem, hand: Vector2, dir: Vector2, side: Vector2, s: float, guard: bool) -> void:
	if guard:
		_line(ci, hand - side * 2.2 * s, hand + side * 2.2 * s, BRASS, 1.2 * s)
	_line(ci, hand, hand - dir * 2.8 * s, GRIP, 1.5 * s)
	ci.draw_circle(hand - dir * 3.0 * s, 0.9 * s, BRASS, true, -1.0, true)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)
