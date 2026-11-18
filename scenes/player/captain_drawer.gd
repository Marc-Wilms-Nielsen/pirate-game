class_name CaptainDrawer
## Draws the captain seen from above, from the player's chosen look (Game.captain_look, see
## Catalog.CAPTAIN_STYLE_PARTS) and the equipped hat and coat. Used on land (PlayerCharacter),
## standing at the helm (ShipVisual) and in the Tailor preview, so he looks the same everywhere.
## Local space: the captain faces `facing`; one unit is one pixel at size 1.

const OUTLINE := Color(0.08, 0.06, 0.05, 0.75)


## Turns part ids into the colours and shapes to draw. look_ids: part key -> option id.
static func resolve(look_ids: Dictionary, equipped: Dictionary) -> Dictionary:
	var hat: Dictionary = Catalog.GEAR[equipped.get("hat", "tricorn")]["look"]
	var coat: Dictionary = Catalog.GEAR[equipped.get("coat", "shirt")]["look"]
	var s := {}
	for part in Catalog.CAPTAIN_STYLE_PARTS:
		s[part["key"]] = Catalog.style_option(part["options"], String(look_ids.get(part["key"], "")))
	var hat_opt: Dictionary = s["hat_color"]
	var coat_opt: Dictionary = s["coat_color"]
	var accent_opt: Dictionary = s["coat_accent"]
	return {
		"skin": s["skin"]["color"],
		"hair_style": s["hair"].get("shape", "short"),
		"hair": s["hair_color"]["color"],
		"beard": s["beard"].get("shape", "none"),
		"beard_color": s["beard_color"]["color"],
		"eyepatch": s["eyepatch"].get("shape", "none"),
		"earring": s["earring"].get("color", null),
		"earring_double": s["earring"].get("shape", "") == "double",
		"hat_shape": hat["shape"],
		"hat": hat_opt.get("color", hat["color"]),
		"hat_accent": hat.get("accent", Color(0.95, 0.3, 0.3)),
		"coat_shape": coat["shape"],
		"coat": coat_opt.get("color", coat["color"]),
		"coat_accent": accent_opt.get("color", coat.get("accent", Color(0.95, 0.8, 0.3))),
		"sash": s["sash"].get("color", null),
		"trousers": s["trousers"]["color"],
		"boots": s["boots"]["color"],
	}


## The current player's look, ready to draw.
static func current() -> Dictionary:
	return resolve(Game.captain_look, Game.equipped)


## Legs, boots, coat and sash. step: -1..1 walking phase (0 = standing still).
static func draw_body(ci: CanvasItem, s: Dictionary, facing: Vector2, step: float, size := 1.0) -> void:
	var f := facing.normalized() * size
	var side := f.orthogonal()
	ci.draw_circle(Vector2(2, 3) * size, 6.0 * size, Color(0, 0, 0, 0.2), true, -1.0, true) # shadow
	# Legs (trousers) with boots at the ends, stepping in turn
	for k in [1.0, -1.0]:
		var foot: Vector2 = side * 2.5 * k + f * step * 2.5 * k
		ci.draw_circle(foot * 0.6, 2.2 * size, s["trousers"], true, -1.0, true)
		ci.draw_circle(foot, 1.8 * size, s["boots"], true, -1.0, true)
	# The coat (body)
	var col: Color = s["coat"]
	var accent: Color = s["coat_accent"]
	ci.draw_circle(Vector2.ZERO, 5.7 * size, OUTLINE, true, -1.0, true)
	ci.draw_circle(Vector2.ZERO, 5.0 * size, col, true, -1.0, true)
	ci.draw_arc(Vector2.ZERO, 4.2 * size, PI * 1.05, PI * 1.6, 8, Color(1, 1, 1, 0.3), 1.0 * size, true) # sheen
	match s["coat_shape"]:
		"striped":
			for k in [-2.5, 0.0, 2.5]:
				ci.draw_line(side * k - f * 3.5, side * k + f * 1.0, accent, 1.0 * size, true)
		"coat":
			ci.draw_circle(-f * 1.0, 5.4 * size, accent, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 4.6 * size, col, true, -1.0, true)
			ci.draw_line(f * 1.5 + side * 1.5, f * 4.0, accent, 0.9 * size, true)
			ci.draw_line(f * 1.5 - side * 1.5, f * 4.0, accent, 0.9 * size, true)
		"buttons", "epaulettes":
			for k in [-1.6, 1.6]:
				ci.draw_circle(f * 2.5 + side * k, 0.6 * size, accent, true, -1.0, true)
				ci.draw_circle(f * 0.5 + side * k, 0.6 * size, accent, true, -1.0, true)
			if s["coat_shape"] == "epaulettes":
				ci.draw_circle(side * 4.6, 1.6 * size, accent, true, -1.0, true)
				ci.draw_circle(-side * 4.6, 1.6 * size, accent, true, -1.0, true)
	if s["sash"] != null: # a sash across the chest, knotted at the hip
		var sash: Color = s["sash"]
		ci.draw_line(side * 4.2 + f * 2.0, -side * 4.2 - f * 1.5, sash, 1.6 * size, true)
		ci.draw_line(-side * 4.0 - f * 1.5, -side * 5.2 - f * 3.5, sash, 1.1 * size, true)


## Hair, head, beard, eye patch, earrings and hat.
static func draw_head(ci: CanvasItem, s: Dictionary, pos: Vector2, facing: Vector2, size: float, time: float) -> void:
	var f := facing.normalized() * size
	var side := f.orthogonal()
	var hair: Color = s["hair"]
	# Hair that shows around and behind the hat
	match s["hair_style"]:
		"long":
			ci.draw_circle(pos - f * 1.6, 4.2 * size, hair, true, -1.0, true)
		"ponytail":
			ci.draw_line(pos - f * 2.5, pos - f * 6.5, hair, 1.6 * size, true)
			ci.draw_circle(pos - f * 6.5, 1.1 * size, hair, true, -1.0, true)
		"braids":
			for k in [1.0, -1.0]:
				ci.draw_line(pos - f * 1.5 + side * 2.6 * k, pos - f * 6.0 + side * 3.0 * k, hair, 1.2 * size, true)
				ci.draw_circle(pos - f * 6.0 + side * 3.0 * k, 0.7 * size, hair.darkened(0.2), true, -1.0, true)
		"curly":
			for i in 7:
				var a := TAU * i / 7.0
				ci.draw_circle(pos + Vector2.from_angle(a) * 3.6 * size - f * 0.5, 1.4 * size, hair, true, -1.0, true)
	ci.draw_circle(pos, 3.5 * size + 0.6, OUTLINE, true, -1.0, true)
	ci.draw_circle(pos, 3.5 * size, s["skin"], true, -1.0, true)
	if s["hair_style"] == "short":
		ci.draw_arc(pos - f * 0.4, 3.3 * size, f.angle() + PI * 0.55, f.angle() + PI * 1.45, 10, hair, 1.4 * size, true)
	# Beard on the front of the face
	var beard: Color = s["beard_color"]
	match s["beard"]:
		"stubble":
			for k in [-1.6, 0.0, 1.6]:
				ci.draw_circle(pos + f * 2.6 + side * k, 0.5 * size, Color(beard, 0.6), true, -1.0, true)
		"mustache":
			ci.draw_line(pos + f * 2.4 - side * 1.8, pos + f * 2.4 + side * 1.8, beard, 1.0 * size, true)
		"goatee":
			ci.draw_circle(pos + f * 3.2, 1.1 * size, beard, true, -1.0, true)
		"full":
			ci.draw_arc(pos, 3.2 * size, f.angle() - 0.9, f.angle() + 0.9, 10, beard, 1.8 * size, true)
		"braided":
			ci.draw_arc(pos, 3.2 * size, f.angle() - 0.8, f.angle() + 0.8, 10, beard, 1.6 * size, true)
			ci.draw_line(pos + f * 3.2, pos + f * 6.0, beard, 1.2 * size, true)
			ci.draw_circle(pos + f * 6.0, 0.7 * size, Color(0.95, 0.8, 0.3), true, -1.0, true)
	# Eye patch: the patch on one eye and the strap round the head
	if s["eyepatch"] != "none":
		var k := 1.0 if s["eyepatch"] == "right" else -1.0
		ci.draw_arc(pos, 3.3 * size, f.angle() + k * 0.5, f.angle() + k * 0.5 + PI, 10, Color(0.05, 0.05, 0.05), 0.6 * size, true)
		ci.draw_circle(pos + f * 2.0 + side * 1.4 * k, 1.0 * size, Color(0.05, 0.05, 0.05), true, -1.0, true)
	if s["earring"] != null:
		ci.draw_circle(pos + side * 3.6, 0.6 * size, s["earring"], true, -1.0, true)
		if s["earring_double"]:
			ci.draw_circle(pos - side * 3.6, 0.6 * size, s["earring"], true, -1.0, true)
	draw_hat(ci, s, pos, f, side, size, time)
	# Sheen on the hat (the light comes from the top left)
	ci.draw_circle(pos + Vector2(-1.4, -1.6) * size, 1.1 * size, Color(1, 1, 1, 0.28), true, -1.0, true)


static func draw_hat(ci: CanvasItem, s: Dictionary, pos: Vector2, f: Vector2, side: Vector2, size: float, time: float) -> void:
	var col: Color = s["hat"]
	match s["hat_shape"]:
		"straw":
			ci.draw_circle(pos, 6.0 * size, col, true, -1.0, true)
			ci.draw_arc(pos, 6.0 * size, 0.0, TAU, 24, col.darkened(0.25), 0.8 * size, true)
			ci.draw_circle(pos, 3.0 * size, col.darkened(0.08), true, -1.0, true)
			ci.draw_arc(pos, 3.0 * size, 0.0, TAU, 20, Color(0.7, 0.2, 0.15), 0.9 * size, true)
		"bandana":
			ci.draw_circle(pos - f * 0.5, 3.4 * size, col, true, -1.0, true)
			ci.draw_line(pos - f * 3.0, pos - f * 6.0 + side * 1.5, col, 1.4 * size, true) # knot
			ci.draw_line(pos - f * 3.0, pos - f * 6.0 - side * 1.5, col, 1.4 * size, true)
			ci.draw_circle(pos - f * 0.5 + side * 1.6, 0.6 * size, Color.WHITE, true, -1.0, true)
		"bicorne":
			var pts := PackedVector2Array([pos + side * 6.5, pos + f * 2.0, pos - side * 6.5, pos - f * 1.5])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 0.6 * size, true)
			ci.draw_circle(pos + f * 1.0, 0.9 * size, Color(0.95, 0.8, 0.3), true, -1.0, true)
		_:
			# Tricorn (with a plume on the captain's hat)
			var tri := PackedVector2Array([pos + f * 3.5, pos - f * 2.5 - side * 3.8, pos - f * 1.2, pos - f * 2.5 + side * 3.8])
			ci.draw_colored_polygon(tri, col)
			ci.draw_polyline(tri + PackedVector2Array([tri[0]]), OUTLINE, 0.6 * size, true)
			ci.draw_line(pos + f * 3.0, pos - f * 2.2 - side * 3.3, col.lightened(0.3), 0.5 * size, true)
			if s["hat_shape"] == "feather":
				var plume := PackedVector2Array()
				for i in 6:
					var t := i / 5.0
					plume.append(pos - f * (1.0 + t * 6.0) + side * (2.0 + sin(time * 3.0 + t * 3.0) * 0.8))
				ci.draw_polyline(plume, s["hat_accent"], 2.0 * size, true)
				ci.draw_circle(pos + f * 0.5, 0.9 * size, Color(0.95, 0.8, 0.3), true, -1.0, true)


## The same look as a Portrait (head and shoulders), for the Tailor preview.
static func portrait_look(s: Dictionary) -> Dictionary:
	var hat := {"straw": "straw", "bandana": "bandana", "bicorne": "bicorne", "feather": "feather"}.get(s["hat_shape"], "tricorn") as String
	var beard := {"stubble": "stubble", "mustache": "mustache", "goatee": "goatee", "full": "full", "braided": "braided"}.get(s["beard"], "none") as String
	var hair := {"long": "long", "ponytail": "ponytail", "braids": "braids", "curly": "curly", "bald": "bald"}.get(s["hair_style"], "short") as String
	return {"skin": s["skin"], "hair": s["hair"], "hair_style": hair, "hat": hat, "hat_color": s["hat"],
		"hat_accent": s["hat_accent"], "beard": beard, "beard_color": s["beard_color"],
		"eyepatch": s["eyepatch"] != "none", "eyepatch_side": s["eyepatch"], "earring": s["earring"] != null,
		"earring_color": s["earring"] if s["earring"] != null else Color(0.95, 0.8, 0.3),
		"coat": s["coat"], "coat_accent": s["coat_accent"], "sash": s["sash"]}
