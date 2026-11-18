class_name Icons
## Små, simple ikoner tegnet i kode til butikker, lastrum, bytte og HUD.
## Brug Icons.make("rum") for en lille Control, eller Icons.draw(canvas, "rum", centrum, størrelse).
## Ikonerne tegnes på et gitter fra -8 til 8 og skaleres til den ønskede størrelse.

const GOLD := Color(0.98, 0.8, 0.28)
const GOLD_DARK := Color(0.78, 0.55, 0.12)
const WOOD := Color(0.62, 0.42, 0.24)
const WOOD_DARK := Color(0.42, 0.27, 0.14)
const STEEL := Color(0.78, 0.8, 0.85)
const STONE := Color(0.6, 0.6, 0.62)
const OUTLINE := Color(0, 0, 0, 0.45)


## En lille Control med et ikon (til brug i menuer).
static func make(id: String, px := 14.0) -> Control:
	var c := IconRect.new()
	c.id = id
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Et ikon foran en tekst (en HBox med ikon + label).
static func labeled(id: String, text: String, font_size := 10, color := UiTheme.TEXT, px := 14.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(make(id, px))
	var l := UiTheme.label(text, font_size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


static func draw(ci: CanvasItem, id: String, center: Vector2, px: float) -> void:
	var s := px / 16.0
	ci.draw_set_transform(center, 0.0, Vector2(s, s))
	_draw_shape(ci, id)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _c(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p, r, col, true, -1.0, true)


static func _p(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


static func _r(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	ci.draw_rect(rect, col)


static func _l(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.5) -> void:
	ci.draw_line(a, b, col, w, true)


static func _draw_shape(ci: CanvasItem, id: String) -> void:
	if Catalog.GEAR.has(id):
		_gear(ci, id)
		return
	if Catalog.ITEMS.has(id) and Catalog.ITEMS[id].has("rarity"):
		var glow: Color = Catalog.RARITY_COLORS[Catalog.ITEMS[id]["rarity"]]
		_c(ci, Vector2.ZERO, 8.5, Color(glow, 0.22))
		ci.draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(glow, 0.7), 1.0, true)
	match id:
		"ancient_coin":
			_c(ci, Vector2(0.8, 0.8), 6.0, GOLD_DARK)
			_c(ci, Vector2(0, 0), 6.0, Color(0.86, 0.7, 0.3))
			ci.draw_arc(Vector2.ZERO, 4.3, 0.0, TAU, 8, GOLD_DARK, 1.0, true) # kantet, slidt mønt
			_l(ci, Vector2(0, -3), Vector2(0, 3), GOLD_DARK, 1.2)
			_l(ci, Vector2(-2.5, -1), Vector2(2.5, -1), GOLD_DARK, 1.2)
		"golden_compass":
			_c(ci, Vector2(0, 0), 6.5, GOLD_DARK)
			_c(ci, Vector2(0, 0), 5.5, Color(0.96, 0.92, 0.8))
			_p(ci, [Vector2(0, -5), Vector2(1.4, 0), Vector2(0, 5), Vector2(-1.4, 0)], Color(0.85, 0.2, 0.2))
			_p(ci, [Vector2(0, 5), Vector2(1.4, 0), Vector2(-1.4, 0)], Color(0.25, 0.25, 0.3))
			_c(ci, Vector2(0, -7), 1.4, GOLD)
		"silver_chalice":
			var silver := Color(0.82, 0.84, 0.9)
			_p(ci, [Vector2(-5, -6), Vector2(5, -6), Vector2(3.5, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-3.5, -1)], silver)
			_r(ci, Rect2(-0.8, 1, 1.6, 4), silver.darkened(0.2))
			_p(ci, [Vector2(-4, 7), Vector2(4, 7), Vector2(2, 5), Vector2(-2, 5)], silver)
			_l(ci, Vector2(-3.5, -5), Vector2(-2.5, -1.5), Color(1, 1, 1, 0.8), 1.0)
			_c(ci, Vector2(0, -3), 1.2, Color(0.9, 0.2, 0.3))
		"pearl_necklace":
			for i in 9:
				var ang := PI * 0.1 + PI * 0.8 * i / 8.0
				_c(ci, Vector2(cos(ang) * 6.0, sin(ang) * 5.0 - 2.0), 1.6, Color(0.22, 0.22, 0.3))
				_c(ci, Vector2(cos(ang) * 6.0 - 0.5, sin(ang) * 5.0 - 2.5), 0.6, Color(0.8, 0.85, 1.0))
		"jade_idol":
			var jade := Color(0.25, 0.7, 0.45)
			_p(ci, [Vector2(-4, 7), Vector2(4, 7), Vector2(4.5, -1), Vector2(3, -6), Vector2(-3, -6), Vector2(-4.5, -1)], jade)
			_r(ci, Rect2(-3, -3, 2, 1.5), jade.darkened(0.5))
			_r(ci, Rect2(1, -3, 2, 1.5), jade.darkened(0.5))
			_r(ci, Rect2(-2, 1.5, 4, 1.2), jade.darkened(0.5))
			_l(ci, Vector2(-3, -5.5), Vector2(-3.5, 4), jade.lightened(0.4), 0.8)
		"cursed_skull":
			_c(ci, Vector2(0, -1), 6.0, GOLD)
			_r(ci, Rect2(-3, 3, 6, 4), GOLD)
			_c(ci, Vector2(-2.3, -1), 1.8, Color(0.3, 0.05, 0.4))
			_c(ci, Vector2(2.3, -1), 1.8, Color(0.3, 0.05, 0.4))
			_c(ci, Vector2(-2.3, -1), 0.7, Color(0.7, 1.0, 0.5))
			_c(ci, Vector2(2.3, -1), 0.7, Color(0.7, 1.0, 0.5))
			_l(ci, Vector2(-1.5, 5), Vector2(-1.5, 7), GOLD_DARK, 0.8)
			_l(ci, Vector2(1.5, 5), Vector2(1.5, 7), GOLD_DARK, 0.8)
		"kraken_eye":
			_c(ci, Vector2(0, 0), 6.8, Color(0.25, 0.1, 0.35))
			_c(ci, Vector2(0, 0), 5.5, Color(0.95, 0.75, 0.2))
			_p(ci, [Vector2(0, -5), Vector2(1.3, 0), Vector2(0, 5), Vector2(-1.3, 0)], Color(0.08, 0.05, 0.1))
			_c(ci, Vector2(-2, -2.2), 1.1, Color(1, 1, 1, 0.9))
		"sun_crown":
			_p(ci, [Vector2(-7, 5), Vector2(-7, -4), Vector2(-3.5, 0), Vector2(0, -7), Vector2(3.5, 0), Vector2(7, -4), Vector2(7, 5)], GOLD)
			_r(ci, Rect2(-7, 3, 14, 3), GOLD_DARK)
			_c(ci, Vector2(0, 0.5), 1.6, Color(0.9, 0.2, 0.25))
			_c(ci, Vector2(-4.5, 1.5), 1.1, Color(0.25, 0.55, 0.95))
			_c(ci, Vector2(4.5, 1.5), 1.1, Color(0.25, 0.8, 0.45))
		"gold":
			_c(ci, Vector2(1.5, 2), 5.5, GOLD_DARK)
			_c(ci, Vector2(-1, 0), 6.0, OUTLINE)
			_c(ci, Vector2(-1, 0), 5.5, GOLD)
			ci.draw_arc(Vector2(-1, 0), 3.8, 0.0, TAU, 16, GOLD_DARK, 1.0, true)
			_c(ci, Vector2(-3, -2.5), 1.2, Color(1, 1, 0.85))
		"crew":
			_c(ci, Vector2(0, 6), 6.5, Color(0.25, 0.35, 0.65))
			_c(ci, Vector2(0, -2), 4.5, Color(0.95, 0.78, 0.6))
			_p(ci, [Vector2(-5, -3), Vector2(-4, -7), Vector2(4, -7), Vector2(5, -3)], Color(0.8, 0.18, 0.18))
		"cannonball", "cannons":
			_c(ci, Vector2(0, 0), 6.0, Color(0.15, 0.15, 0.17))
			_c(ci, Vector2(-2, -2), 1.8, Color(0.55, 0.55, 0.6))
		"shot":
			for p in [Vector2(-3, 2), Vector2(3, 2), Vector2(0, -3)]:
				_c(ci, p, 3.0, Color(0.35, 0.36, 0.4))
				_c(ci, p + Vector2(-0.8, -0.8), 0.9, Color(0.75, 0.75, 0.8))
		"food":
			_c(ci, Vector2(-1.5, -1.5), 5.0, Color(0.72, 0.38, 0.2))
			_c(ci, Vector2(-2.5, -2.5), 2.0, Color(0.85, 0.5, 0.3))
			_l(ci, Vector2(2, 2), Vector2(6, 6), Color(0.95, 0.92, 0.85), 2.2)
			_c(ci, Vector2(6.5, 5.5), 1.4, Color(0.95, 0.92, 0.85))
			_c(ci, Vector2(5.5, 6.8), 1.4, Color(0.95, 0.92, 0.85))
		"cargo", "stolen_cargo":
			_r(ci, Rect2(-6.5, -6.5, 13, 13), WOOD_DARK)
			_r(ci, Rect2(-5.5, -5.5, 11, 11), WOOD)
			_l(ci, Vector2(-5.5, -5.5), Vector2(5.5, 5.5), WOOD_DARK, 1.6)
			_l(ci, Vector2(-5.5, 0), Vector2(5.5, 0), WOOD_DARK, 1.0)
			if id == "stolen_cargo":
				_c(ci, Vector2(0, 0), 3.6, Color(0.95, 0.95, 0.9))
				_c(ci, Vector2(-1.3, -0.6), 0.9, Color(0.1, 0.1, 0.1))
				_c(ci, Vector2(1.3, -0.6), 0.9, Color(0.1, 0.1, 0.1))
		"rum":
			_r(ci, Rect2(-1.5, -8, 3, 4), Color(0.2, 0.4, 0.25))
			_r(ci, Rect2(-2, -8.5, 4, 1.5), Color(0.55, 0.35, 0.2))
			_p(ci, [Vector2(-1.5, -4), Vector2(1.5, -4), Vector2(4.5, -1), Vector2(4.5, 7), Vector2(-4.5, 7), Vector2(-4.5, -1)], Color(0.2, 0.45, 0.28))
			_r(ci, Rect2(-3.5, 0, 7, 4), Color(0.95, 0.88, 0.7))
			_l(ci, Vector2(-3, -1), Vector2(-3, 5), Color(1, 1, 1, 0.35), 1.0)
		"sugar":
			_p(ci, [Vector2(-5, -3), Vector2(5, -3), Vector2(6.5, 7), Vector2(-6.5, 7)], Color(0.9, 0.86, 0.75))
			_p(ci, [Vector2(-3, -3), Vector2(3, -3), Vector2(1, -6), Vector2(-1, -6)], Color(0.82, 0.78, 0.66))
			_l(ci, Vector2(-3, -3.5), Vector2(3, -3.5), Color(0.6, 0.45, 0.25), 1.2)
			_c(ci, Vector2(0, 2.5), 2.0, Color(1, 1, 1))
		"tobacco":
			_p(ci, [Vector2(0, -8), Vector2(5, -2), Vector2(3, 6), Vector2(0, 8), Vector2(-3, 6), Vector2(-5, -2)], Color(0.55, 0.38, 0.18))
			_l(ci, Vector2(0, -7), Vector2(0, 7), Color(0.38, 0.25, 0.1), 1.0)
		"spices":
			_p(ci, [Vector2(-6, 7), Vector2(6, 7), Vector2(4, -1), Vector2(-4, -1)], Color(0.55, 0.35, 0.2))
			_c(ci, Vector2(0, -1.5), 4.5, Color(0.88, 0.35, 0.15))
			_c(ci, Vector2(-1.5, -3), 1.5, Color(0.98, 0.65, 0.2))
		"silk":
			_r(ci, Rect2(-6, -4, 12, 8), Color(0.62, 0.3, 0.72))
			_c(ci, Vector2(6, 0), 4.0, Color(0.48, 0.2, 0.58))
			_c(ci, Vector2(6, 0), 1.5, Color(0.3, 0.1, 0.36))
			_l(ci, Vector2(-6, -1.5), Vector2(6, -1.5), Color(0.85, 0.6, 0.95), 1.0)
		"snake_skin":
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(Vector2(-7 + i * 1.75, sin(i * 1.2) * 3.5))
			ci.draw_polyline(pts, Color(0.35, 0.55, 0.2), 3.5, true)
			ci.draw_polyline(pts, Color(0.75, 0.85, 0.35), 1.0, true)
		"shark_tooth":
			_p(ci, [Vector2(-5, -6), Vector2(5, -6), Vector2(0, 7)], Color(0.97, 0.96, 0.9))
			_l(ci, Vector2(-5, -6), Vector2(5, -6), Color(0.75, 0.7, 0.65), 1.5)
		"jaguar_pelt":
			_p(ci, [Vector2(-7, -4), Vector2(-3, -6), Vector2(3, -6), Vector2(7, -4), Vector2(6, 5), Vector2(0, 7), Vector2(-6, 5)], Color(0.92, 0.66, 0.28))
			for p in [Vector2(-3, -2), Vector2(2, -3), Vector2(0, 2), Vector2(-4, 3), Vector2(4, 2)]:
				_c(ci, p, 1.1, Color(0.25, 0.17, 0.1))
		"boar_tusk":
			ci.draw_arc(Vector2(2, 4), 8.0, PI * 1.05, PI * 1.6, 12, Color(0.97, 0.94, 0.85), 3.0, true)
		"croc_leather":
			_r(ci, Rect2(-6.5, -5, 13, 10), Color(0.3, 0.45, 0.25))
			for x in [-4, 0, 4]:
				for y in [-2.5, 2.5]:
					_r(ci, Rect2(x - 1.3, y - 1.3, 2.6, 2.6), Color(0.22, 0.35, 0.18))
		"golem_core":
			_c(ci, Vector2(0, 0), 7.0, STONE.darkened(0.2))
			_p(ci, [Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)], Color(0.35, 1.0, 0.85))
			_c(ci, Vector2(-1, -1), 1.2, Color(0.9, 1, 1))
		"royal_seal":
			_c(ci, Vector2(0, 0), 7.0, Color(0.7, 0.12, 0.14))
			_c(ci, Vector2(0, 0), 5.0, Color(0.82, 0.2, 0.2))
			_p(ci, [Vector2(-3.5, 2), Vector2(-3.5, -2.5), Vector2(-1.7, -0.5), Vector2(0, -3.5), Vector2(1.7, -0.5), Vector2(3.5, -2.5), Vector2(3.5, 2)], GOLD)
		"pearls":
			for p in [Vector2(-3.5, 2), Vector2(3.5, 2), Vector2(0, -3)]:
				_c(ci, p, 3.4, Color(0.92, 0.92, 0.96))
				_c(ci, p + Vector2(-1, -1), 1.0, Color(1, 1, 1))
		"jewels", "stolen_jewels":
			if id == "stolen_jewels":
				ci.draw_arc(Vector2(0, -2), 6.0, 0.2, PI - 0.2, 14, GOLD, 1.3, true)
			var col := Color(0.25, 0.55, 0.95) if id == "jewels" else Color(0.9, 0.2, 0.3)
			_p(ci, [Vector2(-5, -1), Vector2(-2.5, -4), Vector2(2.5, -4), Vector2(5, -1), Vector2(0, 6)], col)
			_p(ci, [Vector2(-2.5, -4), Vector2(2.5, -4), Vector2(0, -1)], col.lightened(0.35))
		"wood":
			for p in [Vector2(-3, 3), Vector2(3, 3), Vector2(0, -2.5)]:
				_c(ci, p, 3.4, WOOD_DARK)
				_c(ci, p, 2.6, Color(0.85, 0.68, 0.45))
				ci.draw_arc(p, 1.3, 0.0, TAU, 10, WOOD, 0.7, true)
		"coconut":
			_c(ci, Vector2(0, 0), 6.0, Color(0.45, 0.3, 0.18))
			for p in [Vector2(-1.5, -2), Vector2(1.5, -2), Vector2(0, 0.5)]:
				_c(ci, p, 0.9, Color(0.25, 0.15, 0.08))
		"stone", "iron_ore", "gold_ore":
			_p(ci, [Vector2(-6, 3), Vector2(-5, -3), Vector2(-1, -6), Vector2(4, -4), Vector2(6, 1), Vector2(3, 6), Vector2(-3, 6)], STONE)
			_p(ci, [Vector2(-4, -2), Vector2(-1, -5), Vector2(2, -3), Vector2(-1, -1)], STONE.lightened(0.25))
			if id != "stone":
				var spec := Color(0.75, 0.42, 0.25) if id == "iron_ore" else GOLD
				for p in [Vector2(-2, 2), Vector2(2.5, -1), Vector2(1, 3.5)]:
					_c(ci, p, 1.3, spec)
		"fish", "rare_fish":
			var body := Color(0.45, 0.65, 0.85) if id == "fish" else Color(0.95, 0.65, 0.2)
			_p(ci, [Vector2(-7, -4), Vector2(-4, 0), Vector2(-7, 4)], body.darkened(0.2))
			_c(ci, Vector2(1, 0), 4.5, body)
			_c(ci, Vector2(-2, 0), 3.5, body)
			_c(ci, Vector2(3.5, -1), 0.9, Color(0.1, 0.1, 0.1))
			if id == "rare_fish":
				_c(ci, Vector2(0, 0), 1.2, Color(1, 1, 0.8))
		"wheat":
			_l(ci, Vector2(0, 8), Vector2(0, -6), Color(0.75, 0.6, 0.25), 1.2)
			for y in [-5.0, -2.0, 1.0]:
				_c(ci, Vector2(-1.8, y), 1.6, Color(0.95, 0.78, 0.35))
				_c(ci, Vector2(1.8, y), 1.6, Color(0.95, 0.78, 0.35))
			_c(ci, Vector2(0, -7), 1.4, Color(0.95, 0.78, 0.35))
		"hemp", "herbs":
			var leaf := Color(0.3, 0.62, 0.3) if id == "herbs" else Color(0.45, 0.6, 0.25)
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.55
				var tip := Vector2.from_angle(a) * 7.5 + Vector2(0, 3)
				_p(ci, [Vector2(0, 3), tip + Vector2.from_angle(a + 1.57) * 1.6, tip, tip - Vector2.from_angle(a + 1.57) * 1.6], leaf)
			_l(ci, Vector2(0, 3), Vector2(0, 8), leaf.darkened(0.3), 1.2)
		"rope":
			for r in [6.0, 4.0, 2.0]:
				ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0.78, 0.62, 0.38), 1.6, true)
		"canvas":
			_p(ci, [Vector2(-6, -5), Vector2(6, -5), Vector2(6, 5), Vector2(-6, 5)], Color(0.95, 0.93, 0.86))
			_l(ci, Vector2(-6, 0), Vector2(6, 0), Color(0.75, 0.72, 0.65), 1.0)
			_l(ci, Vector2(0, -5), Vector2(0, 5), Color(0.75, 0.72, 0.65), 1.0)
		"iron_bar", "gold_bar":
			var c1 := STEEL.darkened(0.15) if id == "iron_bar" else GOLD
			_p(ci, [Vector2(-7, 4), Vector2(-4, -3), Vector2(4, -3), Vector2(7, 4)], c1.darkened(0.2))
			_p(ci, [Vector2(-4, -3), Vector2(4, -3), Vector2(3, -1), Vector2(-3, -1)], c1.lightened(0.25))
		"grenade":
			_c(ci, Vector2(0, 2), 5.5, Color(0.2, 0.22, 0.2))
			_r(ci, Rect2(-1.5, -5, 3, 2.5), Color(0.5, 0.45, 0.4))
			_l(ci, Vector2(0, -5), Vector2(3, -8), Color(0.6, 0.5, 0.35), 1.0)
			_c(ci, Vector2(3, -8), 1.5, Color(1.0, 0.7, 0.2))
		"firebomb":
			_p(ci, [Vector2(-4, -1), Vector2(4, -1), Vector2(4, 7), Vector2(-4, 7)], Color(0.6, 0.35, 0.2))
			_r(ci, Rect2(-1.5, -4, 3, 3), Color(0.6, 0.35, 0.2))
			_p(ci, [Vector2(-2, -4), Vector2(0, -9), Vector2(2, -4)], Color(1.0, 0.55, 0.15))
		"poison":
			_c(ci, Vector2(0, 2.5), 5.0, Color(0.35, 0.75, 0.25))
			_r(ci, Rect2(-1.8, -6, 3.6, 4.5), Color(0.35, 0.75, 0.25))
			_r(ci, Rect2(-2.2, -7, 4.4, 1.5), WOOD)
			_c(ci, Vector2(-1.5, 1), 1.2, Color(0.8, 1, 0.6))
		"flash":
			for i in 8:
				var a := TAU * i / 8.0
				_l(ci, Vector2.ZERO, Vector2.from_angle(a) * (7.5 if i % 2 == 0 else 5.0), Color(1, 0.95, 0.6), 1.4)
			_c(ci, Vector2.ZERO, 3.2, Color(1, 1, 0.92))
		"pistol", "blunderbuss", "musket":
			var length := 6.0 if id == "pistol" else (7.5 if id == "blunderbuss" else 8.5)
			_l(ci, Vector2(-3, -1), Vector2(length, -1), Color(0.35, 0.36, 0.4), 2.2)
			if id == "blunderbuss":
				_c(ci, Vector2(length, -1), 2.0, Color(0.35, 0.36, 0.4))
			_p(ci, [Vector2(-3, -2.5), Vector2(-1, -2.5), Vector2(-4, 6), Vector2(-7, 5)], WOOD)
			if id == "musket":
				_p(ci, [Vector2(-8, -2), Vector2(-3, -2.5), Vector2(-3, 0.5), Vector2(-8, 1.5)], WOOD)
		"sword":
			_l(ci, Vector2(-6, 6), Vector2(6, -6), STEEL, 2.0)
			_l(ci, Vector2(-5, 2), Vector2(-2, 5), GOLD_DARK, 1.6)
		"axe":
			_l(ci, Vector2(-5, 7), Vector2(3, -5), WOOD, 1.8)
			_p(ci, [Vector2(1, -7), Vector2(7, -4), Vector2(5, 1), Vector2(2, -3)], STEEL)
		"pickaxe":
			_l(ci, Vector2(-4, 7), Vector2(2, -4), WOOD, 1.8)
			ci.draw_arc(Vector2(2, 1), 7.0, -PI * 0.95, -PI * 0.15, 12, STEEL, 2.0, true)
		"rod":
			_l(ci, Vector2(-6, 7), Vector2(5, -7), WOOD, 1.4)
			_l(ci, Vector2(5, -7), Vector2(6, 3), Color(0.9, 0.9, 0.9, 0.8), 0.7)
			_c(ci, Vector2(6, 4), 1.3, Color(0.9, 0.25, 0.2))
		"repair_kit":
			_r(ci, Rect2(-7, -1, 14, 7), Color(0.7, 0.2, 0.18))
			_r(ci, Rect2(-2, -4, 4, 3), Color(0.4, 0.12, 0.1))
			_r(ci, Rect2(-1, 0.5, 2, 4), Color(1, 1, 1))
			_r(ci, Rect2(-2.5, 1.8, 5, 1.4), Color(1, 1, 1))
		"ship":
			_p(ci, [Vector2(-7, 3), Vector2(7, 3), Vector2(5, 6), Vector2(-5, 6)], WOOD)
			_l(ci, Vector2(0, 3), Vector2(0, -8), WOOD_DARK, 1.2)
			_p(ci, [Vector2(0.5, -7), Vector2(6, 1), Vector2(0.5, 1)], Color(0.97, 0.95, 0.9))
			_p(ci, [Vector2(-0.5, -5), Vector2(-5, 1), Vector2(-0.5, 1)], Color(0.9, 0.88, 0.82))
		"hull", "armor":
			_p(ci, [Vector2(-6, -6), Vector2(6, -6), Vector2(6, 0), Vector2(0, 7), Vector2(-6, 0)], STEEL.darkened(0.15) if id == "armor" else WOOD)
			_p(ci, [Vector2(-4, -4), Vector2(4, -4), Vector2(4, -0.5), Vector2(0, 4.5), Vector2(-4, -0.5)], STEEL if id == "armor" else WOOD.lightened(0.15))
		"sails":
			_l(ci, Vector2(-4, 8), Vector2(-4, -8), WOOD_DARK, 1.3)
			_p(ci, [Vector2(-3, -7), Vector2(6, 0), Vector2(-3, 5)], Color(0.97, 0.95, 0.9))
		"cannon_power", "cannon_range":
			_p(ci, [Vector2(-6, -2.5), Vector2(5, -1.8), Vector2(5, 1.8), Vector2(-6, 2.5)], Color(0.25, 0.25, 0.28))
			_c(ci, Vector2(-6, 0), 2.8, Color(0.25, 0.25, 0.28))
			_c(ci, Vector2(-3, 4), 2.5, WOOD)
			if id == "cannon_power":
				_p(ci, [Vector2(5, -4), Vector2(8, 0), Vector2(5, 4)], Color(1.0, 0.6, 0.2))
			else:
				_l(ci, Vector2(6, -5), Vector2(8, -7), GOLD, 1.0)
				_l(ci, Vector2(6, 5), Vector2(8, 7), GOLD, 1.0)
		"reload":
			_p(ci, [Vector2(-5, -7), Vector2(5, -7), Vector2(0, 0)], Color(0.95, 0.85, 0.55))
			_p(ci, [Vector2(-5, 7), Vector2(5, 7), Vector2(0, 0)], Color(0.95, 0.85, 0.55))
			_p(ci, [Vector2(-2.5, 7), Vector2(2.5, 7), Vector2(0, 3)], Color(0.85, 0.65, 0.3))
			_l(ci, Vector2(-6, -7), Vector2(6, -7), WOOD_DARK, 1.5)
			_l(ci, Vector2(-6, 7), Vector2(6, 7), WOOD_DARK, 1.5)
		"tow":
			ci.draw_arc(Vector2(-3, 0), 4.0, 0.0, TAU, 14, Color(0.8, 0.65, 0.4), 1.8, true)
			ci.draw_arc(Vector2(3, 0), 4.0, 0.0, TAU, 14, Color(0.7, 0.55, 0.3), 1.8, true)
		"friend":
			_c(ci, Vector2(-3, -2), 3.8, Color(0.92, 0.3, 0.35))
			_c(ci, Vector2(3, -2), 3.8, Color(0.92, 0.3, 0.35))
			_p(ci, [Vector2(-6.6, -0.5), Vector2(6.6, -0.5), Vector2(0, 7)], Color(0.92, 0.3, 0.35))
			_c(ci, Vector2(-4, -3.5), 1.2, Color(1, 0.7, 0.7))
		"small_box", "medium_box", "large_box":
			var half := {"small_box": 4.5, "medium_box": 5.8, "large_box": 7.0}[id] as float
			_r(ci, Rect2(-half - 1, -half - 1, half * 2 + 2, half * 2 + 2), WOOD_DARK)
			_r(ci, Rect2(-half, -half, half * 2, half * 2), WOOD.lightened(0.1))
			_l(ci, Vector2(-half, -half * 0.3), Vector2(half, -half * 0.3), WOOD_DARK, 0.8)
			_l(ci, Vector2(-half, half * 0.35), Vector2(half, half * 0.35), WOOD_DARK, 0.8)
			_r(ci, Rect2(-1, -half, 2, half * 2), Color(0.75, 0.62, 0.35))
		"supply_crate", "big_supply_crate", "trade_crate":
			_draw_shape(ci, "cargo")
			var band := GOLD if id == "big_supply_crate" else (Color(0.3, 0.55, 0.85) if id == "trade_crate" else Color(0.85, 0.25, 0.2))
			_r(ci, Rect2(-6.5, -1.5, 13, 3), band)
			_r(ci, Rect2(-1.5, -6.5, 3, 13), band)
		"house", "cottage", "workshop", "fishery", "chickens", "lumber":
			var roof := {"house": Color(0.75, 0.32, 0.2), "cottage": Color(0.62, 0.42, 0.28), "workshop": Color(0.45, 0.3, 0.25),
				"fishery": Color(0.35, 0.5, 0.68), "chickens": Color(0.88, 0.74, 0.4), "lumber": Color(0.5, 0.35, 0.2)}[id] as Color
			_r(ci, Rect2(-6, -1, 12, 7), Color(0.9, 0.85, 0.74))
			_p(ci, [Vector2(-7.5, -0.5), Vector2(0, -7), Vector2(7.5, -0.5)], roof)
			_r(ci, Rect2(-1.2, 2, 2.4, 4), Color(0.4, 0.25, 0.12))
			match id:
				"workshop":
					_r(ci, Rect2(3, 2.5, 4, 2), Color(0.3, 0.3, 0.33))
				"fishery":
					_c(ci, Vector2(-4.5, 3.5), 1.2, Color(0.55, 0.75, 0.9))
				"chickens":
					_c(ci, Vector2(5.5, 5.5), 1.6, Color(1, 1, 0.95))
				"lumber":
					_c(ci, Vector2(5.5, 5.5), 1.8, Color(0.85, 0.7, 0.45))
				"house":
					_r(ci, Rect2(3, -6, 2, 3), Color(0.45, 0.35, 0.3))
		"quarry":
			_draw_shape(ci, "stone")
		"field", "fields":
			_r(ci, Rect2(-7, -5, 14, 10), Color(0.45, 0.32, 0.2))
			for x in 4:
				for y in 3:
					_c(ci, Vector2(-5 + x * 3.4, -2.8 + y * 2.9), 1.1, Color(0.5, 0.75, 0.35))
		"captain":
			_c(ci, Vector2(0, 6), 6.5, Color(0.15, 0.2, 0.45))
			_c(ci, Vector2(0, -1), 4.2, Color(0.95, 0.78, 0.6))
			_p(ci, [Vector2(-7.5, -2), Vector2(0, -9), Vector2(7.5, -2), Vector2(0, -4)], Color(0.12, 0.1, 0.1))
			_c(ci, Vector2(0, -5), 1.2, GOLD)
			_c(ci, Vector2(-2.5, 6), 0.8, GOLD)
			_c(ci, Vector2(2.5, 6), 0.8, GOLD)
		"sailing":
			_draw_shape(ci, "sails")
		"gunnery":
			_draw_shape(ci, "cannon_power")
		"courage":
			_draw_shape(ci, "armor")
		_:
			_draw_shape(ci, "cargo")


## Udstyr: hat, trøje/frakke eller sværd i udstyrets egen farve.
static func _gear(ci: CanvasItem, id: String) -> void:
	var g: Dictionary = Catalog.GEAR[id]
	var look: Dictionary = g["look"]
	var col: Color = look.get("color", Color.WHITE)
	var accent: Color = look.get("accent", col.darkened(0.3))
	match g["slot"]:
		"hat":
			if look.get("shape", "") == "straw":
				_c(ci, Vector2(0, 2), 7.5, col)
				_c(ci, Vector2(0, 0), 4.0, col.darkened(0.1))
				ci.draw_arc(Vector2(0, 1), 4.0, PI, TAU, 10, Color(0.7, 0.2, 0.15), 1.0, true)
			elif look.get("shape", "") == "bandana":
				_c(ci, Vector2(0, 0), 6.0, col)
				_p(ci, [Vector2(4, 2), Vector2(8, 6), Vector2(6, 7)], col.darkened(0.15))
				_c(ci, Vector2(-2, -1), 0.9, Color.WHITE)
				_c(ci, Vector2(2, 1), 0.9, Color.WHITE)
			else:
				_p(ci, [Vector2(-8, 3), Vector2(0, -6), Vector2(8, 3), Vector2(0, 1)], col)
				_r(ci, Rect2(-3.5, -3, 7, 3), col.lightened(0.08))
				if look.has("accent"):
					_l(ci, Vector2(1, -4), Vector2(6, -8), accent, 1.8)
				else:
					_l(ci, Vector2(-6, 2.5), Vector2(6, 2.5), GOLD, 0.8)
		"coat":
			_p(ci, [Vector2(-7, -4), Vector2(-3, -7), Vector2(3, -7), Vector2(7, -4), Vector2(5, -1), Vector2(5, 7), Vector2(-5, 7), Vector2(-5, -1)], col)
			_p(ci, [Vector2(-2, -7), Vector2(0, -3), Vector2(2, -7)], Color(0.95, 0.85, 0.75))
			if look.get("shape", "") == "striped":
				for y in [-2.0, 1.0, 4.0]:
					_l(ci, Vector2(-5, y), Vector2(5, y), accent, 1.0)
			elif look.get("shape", "") != "plain":
				_l(ci, Vector2(0, -3), Vector2(0, 7), accent, 1.0)
				for y in [-1.0, 2.0, 5.0]:
					_c(ci, Vector2(1.5, y), 0.7, GOLD)
				if look.get("shape", "") == "epaulettes":
					_r(ci, Rect2(-7.5, -5.5, 3.5, 2), GOLD)
					_r(ci, Rect2(4, -5.5, 3.5, 2), GOLD)
		"sword":
			var dir := Vector2(1, -1).normalized()
			var length: float = float(look.get("length", 10.0))
			var sc := clampf(13.0 / maxf(length + 3.0, 1.0), 0.45, 1.3)
			WeaponArt.draw(ci, look, -dir * length * sc * 0.5, dir, sc)


## Control der tegner ét ikon.
class IconRect extends Control:
	var id: String = "cargo":
		set(value):
			id = value
			queue_redraw()

	func _draw() -> void:
		Icons.draw(self, id, size * 0.5, minf(size.x, size.y))
