class_name ShipDrawer
## Tegner skibe ud fra en "look"-beskrivelse i Catalog.SHIPS (skrog, master, sejl, årer, kahyt).
## Bruges både af skibene i verden og af forhåndsvisningerne i værftets butik.
## Koordinater: stævnen peger mod +x, (0, 0) er skibets midte.

const OUTLINE := Color(0.18, 0.11, 0.06)


## Skrogets omrids som polygon. beam er den halve bredde.
static func hull_points(look: Dictionary, steps := 14) -> PackedVector2Array:
	var length: float = look["length"]
	var beam: float = look["beam"]
	var bow: float = look["bow"]
	var stern_w: float = beam * {"square": 0.85, "round": 0.6, "pointed": 0.12}.get(look["stern"], 0.8)
	var top := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(-length * 0.5, length * 0.5, t)
		var w: float
		if t < 0.55:
			var u := t / 0.55
			w = lerpf(stern_w, beam, smoothstep(0.0, 1.0, pow(u, 0.6)))
		else:
			var u := (t - 0.55) / 0.45
			w = beam * pow(maxf(1.0 - pow(u, 1.6 + bow * 1.4), 0.0), 0.5 + bow * 0.4)
		top.append(Vector2(x, -w))
	var pts := PackedVector2Array()
	for p in top:
		pts.append(p)
	for i in range(top.size() - 2, -1, -1): # spejlvend (spring stævnspidsen over)
		pts.append(Vector2(top[i].x, -top[i].y))
	if look["stern"] == "round":
		# Afrund agterspejlet med et par ekstra punkter
		pts.append(Vector2(-length * 0.5 - stern_w * 0.35, stern_w * 0.5))
		pts.append(Vector2(-length * 0.5 - stern_w * 0.45, 0.0))
		pts.append(Vector2(-length * 0.5 - stern_w * 0.35, -stern_w * 0.5))
	return pts


static func collision_polygon(look: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in hull_points(look, 6):
		out.append(p * 0.95)
	return out


static func scaled(points: PackedVector2Array, factor: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * factor)
	return out


## Skrog, dæk, planker, kahyt og årer.
## All the colours and shapes a ship's config has chosen (Catalog.SHIP_STYLE_PARTS), with
## "as built" parts left as null so the ship type's own look is used. Enemy ships have no style
## keys and get the defaults.
static func style_of(config: Dictionary) -> Dictionary:
	var pick := func(options: Array, key: String) -> Dictionary: return Catalog.style_option(options, String(config.get(key, "")))
	return {
		"sail": pick.call(Catalog.SAIL_COLORS, "sail")["color"],
		"hull": pick.call(Catalog.HULL_PAINTS, "hull")["color"],
		"flag": pick.call(Catalog.FLAG_COLORS, "flag")["color"],
		"flag_style": String(config.get("flag_style", "small")),
		"emblem": pick.call(Catalog.SAIL_EMBLEMS, "emblem").get("shape", ""),
		"emblem_color": pick.call(Catalog.EMBLEM_COLORS, "emblem_color")["color"],
		"stripe": pick.call(Catalog.HULL_STRIPES, "stripe").get("color", null),
		"deck": pick.call(Catalog.DECK_COLORS, "deck").get("color", null),
		"rail": pick.call(Catalog.RAIL_COLORS, "rail").get("color", null),
		"cabin": pick.call(Catalog.CABIN_COLORS, "cabin_color").get("color", null),
		"cannon": pick.call(Catalog.CANNON_COLORS, "cannon_color")["color"],
		"lantern": pick.call(Catalog.LANTERN_COLORS, "lantern")["color"],
		"wake": pick.call(Catalog.WAKE_COLORS, "wake")["color"],
	}


static func draw_hull(ci: CanvasItem, look: Dictionary, paint: Color, time: float, oar_speed: float, style := {}) -> void:
	var length: float = look["length"]
	var beam: float = look["beam"]
	var hull_col: Color = look["hull"] * paint
	var deck_col: Color = look["deck"] if style.get("deck") == null else style["deck"]
	var pts := hull_points(look)

	if look.get("oars", false):
		var count := maxi(3, int(length / 11.0))
		for i in count:
			var x := lerpf(-length * 0.32, length * 0.28, float(i) / (count - 1))
			var sweep := sin(time * 4.0 * oar_speed + i * 0.3) * 4.0 * minf(oar_speed, 1.0)
			for side in [-1.0, 1.0]:
				ci.draw_line(Vector2(x, side * beam * 0.8), Vector2(x - 3.0 + sweep, side * (beam + 7.0)), Color(0.45, 0.32, 0.2), 1.3, true)

	# Bovspryd (stang ud over stævnen) under skroget, så den ser ud til at sidde fast
	if look["masts"].size() >= 2 or look["sails"][0] == "square":
		ci.draw_line(Vector2(length * 0.42, 0), Vector2(length * 0.66, 0), OUTLINE, 1.6, true)
		ci.draw_line(Vector2(length * 0.42, 0), Vector2(length * 0.65, 0), Color(0.45, 0.32, 0.2), 0.9, true)
	ci.draw_colored_polygon(pts, OUTLINE)
	ci.draw_colored_polygon(scaled(pts, Vector2(0.95, 0.84)), hull_col)
	# Lys og skygge på skrogsiden: solen står oppe til venstre
	var lit := PackedVector2Array()
	for p in scaled(pts, Vector2(0.95, 0.84)):
		if p.y <= 0.0:
			lit.append(p)
	if lit.size() >= 3:
		ci.draw_polyline(lit, hull_col.lightened(0.22), 1.0, true)
	ci.draw_polyline(scaled(pts, Vector2(0.9, 0.75)), hull_col.darkened(0.3), 0.8, true) # bord/barkholt
	if style.get("stripe") != null: # a painted stripe along the hull side
		ci.draw_polyline(scaled(pts, Vector2(0.925, 0.795)), style["stripe"], 1.1, true)
	ci.draw_colored_polygon(scaled(pts, Vector2(0.86, 0.66)), deck_col)
	var rail: Color = Color(0.95, 0.85, 0.65, 0.5) if style.get("rail") == null else style["rail"]
	ci.draw_polyline(scaled(pts, Vector2(0.86, 0.66)), rail, 0.6 if style.get("rail") == null else 0.9, true) # ræling
	# Dækplanker med forskudte samlinger
	var plank := deck_col.darkened(0.15)
	var rows := 5
	for k in rows:
		var y: float = lerpf(-beam * 0.5, beam * 0.5, (k + 0.5) / rows)
		var reach := 1.0 - pow(absf(y) / (beam * 0.66), 2.0)
		var x0 := -length * 0.38 * reach
		var x1 := length * 0.3 * reach
		ci.draw_line(Vector2(x0, y), Vector2(x1, y), plank, 0.5, true)
		var seam := x0 + (k % 2) * 4.0 + 3.0
		while seam < x1 - 2.0:
			ci.draw_line(Vector2(seam, y - beam * 0.08), Vector2(seam, y + beam * 0.08), plank.darkened(0.15), 0.4)
			seam += 9.0
	# Luge/rist midtskibs og et par tønder
	if length > 40.0:
		var hatch := Rect2(-length * 0.08, -beam * 0.18, length * 0.1, beam * 0.36)
		ci.draw_rect(hatch.grow(0.6), OUTLINE)
		ci.draw_rect(hatch, deck_col.darkened(0.3))
		for gx in 3:
			ci.draw_line(Vector2(hatch.position.x + hatch.size.x * (gx + 0.5) / 3.0, hatch.position.y), Vector2(hatch.position.x + hatch.size.x * (gx + 0.5) / 3.0, hatch.end.y), deck_col.darkened(0.5), 0.5)
		for bx in [0.18, 0.22]:
			ci.draw_circle(Vector2(length * bx, beam * 0.42), 1.6, Color(0.5, 0.34, 0.2), true, -1.0, true)
			ci.draw_arc(Vector2(length * bx, beam * 0.42), 1.6, 0.0, TAU, 10, OUTLINE, 0.5, true)
	if look.get("cabin", false):
		var cw := beam * 1.1
		var r := Rect2(-length * 0.5 + 3.0, -cw * 0.5, length * 0.16, cw)
		var cabin_col: Color = hull_col.lightened(0.12) if style.get("cabin") == null else style["cabin"]
		ci.draw_rect(r.grow(1.0), OUTLINE)
		ci.draw_rect(r, cabin_col)
		ci.draw_line(Vector2(r.position.x, 0), Vector2(r.end.x, 0), cabin_col.darkened(0.25), 1.0, true)


## Where the captain stands: at the wheel, just in front of the cabin (or near the stern).
static func helm_position(look: Dictionary) -> Vector2:
	var length: float = look["length"]
	return Vector2(-length * (0.27 if look.get("cabin", false) else 0.36), 0)


## The ship's wheel at the helm (drawn under the captain).
static func draw_helm(ci: CanvasItem, look: Dictionary) -> void:
	var p := helm_position(look) + Vector2(4.5, 0)
	ci.draw_line(p + Vector2(0, -3.2), p + Vector2(0, 3.2), Color(0.32, 0.2, 0.1), 1.6, true)
	for k in [-3.4, -1.7, 0.0, 1.7, 3.4]:
		ci.draw_line(p + Vector2(-0.6, k), p + Vector2(0.9, k), Color(0.45, 0.3, 0.16), 0.6, true)


## Sejl. factor: 0 = sejlene er bjærget, 1 = fulde sejl.
static func draw_sails(ci: CanvasItem, look: Dictionary, sail_col: Color, factor: float, time: float, emblem := "", emblem_col := Color(0.12, 0.12, 0.13)) -> void:
	_draw_sails(ci, look, sail_col, factor, time)
	if emblem != "" and factor > 0.3:
		# In the middle of the first sail (no draw transform here: the caller's must be kept)
		var mx := float(look["masts"][0]) * float(look["length"])
		var bulge := (2.0 + 6.0 * factor) * 0.55
		draw_emblem(ci, Vector2(mx + bulge, 0), float(look["beam"]) * 0.36, emblem, Color(emblem_col, 0.85))


## A sail emblem of radius r. Shapes: skull, sun, compass, anchor, swords, star.
static func draw_emblem(ci: CanvasItem, c: Vector2, r: float, shape: String, col: Color) -> void:
	match shape:
		"skull":
			ci.draw_circle(c + Vector2(0, -r * 0.15), r * 0.62, col, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.35, r * 0.3), Vector2(r * 0.7, r * 0.35)), col)
			var hole := Color(1, 1, 1, 0.55)
			ci.draw_circle(c + Vector2(-r * 0.24, -r * 0.2), r * 0.16, hole, true, -1.0, true)
			ci.draw_circle(c + Vector2(r * 0.24, -r * 0.2), r * 0.16, hole, true, -1.0, true)
			for k in [-1.0, 1.0]: # crossbones
				ci.draw_line(c + Vector2(-r, r * k), c + Vector2(r, -r * k), col, r * 0.18, true)
		"sun":
			ci.draw_circle(c, r * 0.45, col, true, -1.0, true)
			for i in 10:
				var a := TAU * i / 10.0
				ci.draw_line(c + Vector2.from_angle(a) * r * 0.6, c + Vector2.from_angle(a) * r, col, r * 0.12, true)
		"compass":
			ci.draw_arc(c, r * 0.85, 0.0, TAU, 24, col, r * 0.1, true)
			for i in 4:
				var a := TAU * i / 4.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + 0.6) * r * 0.22,
					c + Vector2.from_angle(a - 0.6) * r * 0.22]), col)
		"anchor":
			ci.draw_line(c + Vector2(0, -r * 0.85), c + Vector2(0, r * 0.75), col, r * 0.16, true)
			ci.draw_line(c + Vector2(-r * 0.45, -r * 0.5), c + Vector2(r * 0.45, -r * 0.5), col, r * 0.14, true)
			ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.6, 0.15, PI - 0.15, 12, col, r * 0.16, true)
			ci.draw_arc(c + Vector2(0, -r * 0.95), r * 0.18, 0.0, TAU, 10, col, r * 0.1, true)
		"swords":
			for k in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(-r * 0.8 * k, r * 0.8), c + Vector2(r * 0.75 * k, -r * 0.85), col, r * 0.12, true)
				ci.draw_line(c + Vector2(-r * 0.5 * k - r * 0.25, r * 0.35), c + Vector2(-r * 0.5 * k + r * 0.25, r * 0.65), col, r * 0.12, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.42))
			ci.draw_colored_polygon(pts, col)


static func _draw_sails(ci: CanvasItem, look: Dictionary, sail_col: Color, factor: float, time: float) -> void:
	var length: float = look["length"]
	var beam: float = look["beam"]
	var masts: Array = look["masts"]
	var sails: Array = look["sails"]
	# Rigning: vanter fra masterne ud til rælingen og stag mellem masterne og bovsprydet
	var rig := Color(0.15, 0.1, 0.06, 0.55)
	for i in masts.size():
		var mx: float = masts[i] * length
		for side in [-1.0, 1.0]:
			for dx in [-3.0, 0.0, 3.0]:
				ci.draw_line(Vector2(mx, 0), Vector2(mx + dx - 2.0, side * beam * 0.82), rig, 0.4, true)
		if i + 1 < masts.size():
			ci.draw_line(Vector2(mx, 0), Vector2(float(masts[i + 1]) * length, 0), rig, 0.5, true)
	if masts.size() >= 2 or sails[0] == "square":
		ci.draw_line(Vector2(float(masts[masts.size() - 1]) * length, 0), Vector2(length * 0.66, 0), rig, 0.5, true)
		# Klyversejl (trekant) mellem forreste mast og bovsprydet
		if factor > 0.05:
			var fm := float(masts[masts.size() - 1]) * length
			var jib := PackedVector2Array([Vector2(fm + 4.0, 0), Vector2(length * 0.6, 0), Vector2(lerpf(fm, length * 0.6, 0.35), beam * (0.25 + 0.45 * factor))])
			ci.draw_colored_polygon(jib, Color(0.96, 0.92, 0.82) * sail_col)
			ci.draw_polyline(jib + PackedVector2Array([jib[0]]), (Color(0.96, 0.92, 0.82) * sail_col).darkened(0.25), 0.5, true)
	for i in masts.size():
		var mx: float = masts[i] * length
		var kind: String = sails[i] if i < sails.size() else "square"
		match kind:
			"lateen":
				_draw_lateen(ci, mx, length, beam, sail_col, factor, time, i)
			"junk":
				_draw_square(ci, mx, beam, sail_col * Color(0.95, 0.75, 0.55), factor, time, "junk")
			"viking":
				_draw_square(ci, mx, beam * 1.15, sail_col, factor, time, "viking")
			"tattered":
				_draw_square(ci, mx, beam, sail_col * Color(0.7, 0.75, 0.72), factor, time, "tattered")
			_:
				_draw_square(ci, mx, beam, sail_col, factor, time, "square")
		ci.draw_circle(Vector2(mx, 0), 1.8, OUTLINE, true, -1.0, true) # masten


static func _draw_square(ci: CanvasItem, mx: float, beam: float, col: Color, factor: float, time: float, style: String) -> void:
	var span := beam * 1.25
	var bulge := (2.0 + 6.0 * factor) * (1.0 + sin(time * 2.0) * 0.04)
	var steps := 10
	var pts := PackedVector2Array()
	for j in steps + 1:
		var y := lerpf(-span, span, float(j) / steps)
		pts.append(Vector2(mx + bulge * (1.0 - pow(y / span, 2.0)) * maxf(factor, 0.15), y))
	for j in range(steps, -1, -1):
		var y := lerpf(-span, span, float(j) / steps)
		pts.append(Vector2(mx - 1.0, y))
	var base := Color(0.96, 0.92, 0.82) * col
	if factor < 0.05:
		ci.draw_line(Vector2(mx, -span), Vector2(mx, span), base, 3.0, true) # bjærget sejl
	else:
		ci.draw_colored_polygon(pts, base)
		# Bugen fanger lyset, kanterne ligger i skygge
		var belly := PackedVector2Array()
		for j in steps + 1:
			var y := lerpf(-span * 0.75, span * 0.75, float(j) / steps)
			belly.append(Vector2(mx + bulge * 0.65 * (1.0 - pow(y / span, 2.0)) * maxf(factor, 0.15), y))
		ci.draw_polyline(belly, base.lightened(0.18), 1.6, true)
		for seam in [-0.5, 0.0, 0.5]:
			var y: float = span * seam
			ci.draw_line(Vector2(mx - 0.5, y), Vector2(mx + bulge * (1.0 - pow(y / span, 2.0)) * maxf(factor, 0.15), y), base.darkened(0.12), 0.4, true)
		ci.draw_polyline(pts, base.darkened(0.3), 0.8, true)
		match style:
			"viking":
				# Røde striber på tværs af sejlet
				for j in [-0.66, 0.0, 0.66]:
					var y0: float = span * (j - 0.16)
					var y1: float = span * (j + 0.16)
					var band := PackedVector2Array()
					for k in 5:
						var y := lerpf(y0, y1, k / 4.0)
						band.append(Vector2(mx + bulge * (1.0 - pow(y / span, 2.0)) * factor, y))
					band.append(Vector2(mx - 1.0, y1))
					band.append(Vector2(mx - 1.0, y0))
					ci.draw_colored_polygon(band, Color(0.75, 0.15, 0.12))
			"junk":
				for j in range(-3, 4):
					var y := span * j / 4.0
					ci.draw_line(Vector2(mx, y), Vector2(mx + bulge * (1.0 - pow(y / span, 2.0)) * factor, y), base.darkened(0.35), 0.8, true)
			"tattered":
				for j in [-0.5, 0.15, 0.6]:
					ci.draw_circle(Vector2(mx + bulge * 0.5 * factor, span * j), 1.6, Color(0.2, 0.3, 0.32, 0.8), true, -1.0, true)
	ci.draw_line(Vector2(mx, -span - 1.0), Vector2(mx, span + 1.0), OUTLINE.lightened(0.15), 1.4, true) # rå


static func _draw_lateen(ci: CanvasItem, mx: float, length: float, beam: float, col: Color, factor: float, time: float, index: int) -> void:
	# Latinersejl set oppefra: en lang skrå rå, og sejlet bugner ud til den ene side.
	var reach := length * 0.34
	var side := -1.0 if index % 2 == 0 else -0.8
	var a := Vector2(mx + reach * 0.35, beam * 0.25 * -side)
	var b := Vector2(mx - reach * 0.8, beam * (0.5 + 0.6 * factor) * side)
	var base := Color(0.96, 0.92, 0.82) * col
	if factor < 0.05:
		ci.draw_line(a, b, base, 3.0, true) # bjærget
		ci.draw_line(a, b, OUTLINE.lightened(0.15), 1.2, true)
		return
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	if normal.dot(Vector2(0, side)) < 0.0:
		normal = -normal
	var belly := beam * (0.35 + 0.55 * factor) * (1.0 + sin(time * 2.5 + index) * 0.04)
	var pts := PackedVector2Array()
	var steps := 10
	for j in steps + 1:
		var t := float(j) / steps
		# Trekantet profil: bredest tæt på masten, spids ude ved enderne
		var bulge := sin(PI * pow(t, 0.8)) * belly
		pts.append(a.lerp(b, t) + normal * bulge)
	pts.append(b)
	pts.append(a)
	ci.draw_colored_polygon(pts, base)
	ci.draw_polyline(pts, base.darkened(0.25), 0.8, true)
	ci.draw_line(a, b, OUTLINE.lightened(0.15), 1.4, true) # rå


## Kasser stablet på dækket: to rækker langs skibet, fra agter mod for.
static func draw_deck_boxes(ci: CanvasItem, look: Dictionary, types: Array) -> void:
	if types.is_empty():
		return
	var length: float = look["length"]
	var beam: float = look["beam"]
	var sizes := {"small_box": 3.2, "medium_box": 4.2, "large_box": 5.2}
	var x := -length * 0.3
	var row := 0
	for i in mini(types.size(), 18):
		var half: float = sizes.get(types[i], 4.0)
		var y := (-1.0 if row == 0 else 1.0) * beam * 0.28
		var c := Vector2(x, y)
		ci.draw_rect(Rect2(c - Vector2(half, half) + Vector2(1, 1.5), Vector2(half, half) * 2.0), Color(0, 0, 0, 0.3))
		ci.draw_rect(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), OUTLINE)
		ci.draw_rect(Rect2(c - Vector2(half, half) * 0.82, Vector2(half, half) * 1.64), Color(0.7, 0.5, 0.28))
		ci.draw_line(c - Vector2(half * 0.8, half * 0.8), c + Vector2(half * 0.8, half * 0.8), Color(0.45, 0.3, 0.15), 0.6, true)
		ci.draw_line(c + Vector2(-half * 0.8, half * 0.8), c + Vector2(half * 0.8, -half * 0.8), Color(0.45, 0.3, 0.15), 0.6, true)
		row += 1
		if row > 1:
			row = 0
			x += half * 2.2
			if x > length * 0.3:
				x = -length * 0.27 # flere kasser stables ovenpå de første


## Kanonernes positioner på én side.
static func cannon_positions(look: Dictionary, count: int, side: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var length: float = look["length"]
	var beam: float = look["beam"]
	var y := (-beam - 0.5) if side == "left" else (beam + 0.5)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / (count - 1)
		out.append(Vector2(lerpf(-length * 0.3, length * 0.22, t), y * 0.92))
	return out


static func draw_cannons(ci: CanvasItem, look: Dictionary, count: int, recoil: Dictionary, barrel := Color(0.15, 0.15, 0.17)) -> void:
	for side in ["left", "right"]:
		var out_dir := Vector2.UP if side == "left" else Vector2.DOWN
		for p in cannon_positions(look, count, side):
			var base: Vector2 = p - out_dir * float(recoil.get(side, 0.0)) * 2.0
			ci.draw_line(base, base + out_dir * 4.5, barrel, 2.6, true)
			ci.draw_line(base + out_dir * 1.0, base + out_dir * 4.0, barrel.lightened(0.25), 0.6, true) # shine
			ci.draw_circle(base, 1.8, Color(0.3, 0.22, 0.15), true, -1.0, true)


static func draw_decorations(ci: CanvasItem, look: Dictionary, decorations: Dictionary, flag_col: Color, time: float, over_sails: bool, flag_style := "small", lantern := Color(1.0, 0.8, 0.3)) -> void:
	var length: float = look["length"]
	var beam: float = look["beam"]
	var mast := Vector2(float(look["masts"][0]) * length, 0)
	if not over_sails:
		if decorations.get("figurehead", false):
			var bow := Vector2(length * 0.5, 0)
			ci.draw_colored_polygon(PackedVector2Array([bow + Vector2(5, 0), bow + Vector2(-1, -2.5), bow + Vector2(-1, 2.5)]), Color(0.95, 0.78, 0.25))
		if decorations.get("lanterns", false):
			var glow := 0.35 + 0.15 * sin(time * 3.0)
			for y in [-beam * 0.65, beam * 0.65]:
				var lp := Vector2(-length * 0.45, y)
				ci.draw_circle(lp, 3.5, Color(lantern, glow * 0.5), true, -1.0, true)
				ci.draw_circle(lp, 1.4, lantern.lightened(0.4), true, -1.0, true)
		return
	if decorations.get("crows_nest", false):
		ci.draw_circle(mast, 3.2, Color(0.45, 0.3, 0.18), true, -1.0, true)
		ci.draw_arc(mast, 3.2, 0.0, TAU, 20, OUTLINE, 0.8, true)
	if decorations.get("flag", false):
		draw_flag(ci, mast, flag_col, time, flag_style)


## Et bølgende flag der flagrer agterud fra masten. Formen afhænger af flagtypen.
static func draw_flag(ci: CanvasItem, mast: Vector2, col: Color, time: float, style_id: String) -> void:
	var style: Dictionary = Catalog.FLAG_STYLES[0]
	for st in Catalog.FLAG_STYLES:
		if st["id"] == style_id:
			style = st
	var length: float = style["length"]
	var width: float = style["width"]
	var shape: String = style["shape"]
	var segments := maxi(4, int(length / 3.0))
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var wave := sin(time * 5.0 - t * 5.0) * (0.6 + 2.2 * t) # mere bølge ude mod enden
		var half := width * 0.5
		match shape:
			"pennant", "legend":
				half *= lerpf(1.0, 0.15, t) # spids ende
			"royal":
				half *= 1.0
		var center := mast + Vector2(-length * t, 1.0 + wave)
		top.append(center + Vector2(0, -half))
		bottom.append(center + Vector2(0, half))
	if shape == "swallowtail":
		# V-formet hak i enden
		var end := (top[segments] + bottom[segments]) * 0.5
		top.append(end + Vector2(width * 0.5, 0))
	var pts := PackedVector2Array()
	pts.append_array(top)
	for i in range(bottom.size() - 1, -1, -1):
		pts.append(bottom[i])
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts, col.darkened(0.35), 0.6, true)
	match shape:
		"royal":
			# To lange vimpler under flaget
			for side in [-1.0, 1.0]:
				var tail := PackedVector2Array()
				for i in 9:
					var t := float(i) / 8
					tail.append(mast + Vector2(-length * (0.6 + 0.9 * t), side * width * 0.35 + sin(time * 6.0 - t * 6.0) * 2.5 * t))
				ci.draw_polyline(tail, Color(0.95, 0.8, 0.3), 1.2, true)
			ci.draw_circle(mast + Vector2(-length * 0.45, 1.0 + sin(time * 5.0 - 2.2) * 1.5), width * 0.25, Color(0.95, 0.8, 0.3), true, -1.0, true)
		"legend":
			# Guldkant og en midterstribe i en lysere farve
			ci.draw_polyline(top, Color(0.95, 0.8, 0.3), 1.0, true)
			ci.draw_polyline(bottom, Color(0.95, 0.8, 0.3), 1.0, true)
			var mid := PackedVector2Array()
			for i in top.size():
				mid.append((top[i] + bottom[i]) * 0.5)
			ci.draw_polyline(mid, col.lightened(0.45), 1.2, true)
		_:
			ci.draw_circle(mast + Vector2(-length * 0.45, 1.0 + sin(time * 5.0 - 2.2) * (0.6 + 1.0)), minf(width * 0.2, 1.2), Color(0.95, 0.95, 0.9), true, -1.0, true)
