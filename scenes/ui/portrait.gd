class_name Portrait
extends Control
## A quest giver's head and shoulders, drawn in code from a "look" dictionary
## (see Catalog.QUEST_PEOPLE): skin, hair, hair_style (short/long/bun/bald), hat
## (none/cap/bandana/hood/feather), hat_color, beard (none/mustache/full), beard_color,
## glasses, eyepatch, earring, coat.

var look: Dictionary = {}:
	set(value):
		look = value
		queue_redraw()

var _blink := 0.0
var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	process_mode = Node.PROCESS_MODE_ALWAYS # the game is paused while the chat window is open


func _process(delta: float) -> void:
	_time += delta
	# Blink now and then, so the portrait feels alive
	_blink = 1.0 if fmod(_time, 3.7) > 3.58 else 0.0
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 64.0
	draw_set_transform(size * 0.5 - Vector2(32, 32) * s, 0.0, Vector2(s, s))
	# Frame
	draw_rect(Rect2(0, 0, 64, 64), Color(0.16, 0.2, 0.26))
	draw_rect(Rect2(2, 2, 60, 60), Color(0.28, 0.36, 0.44))
	draw_circle(Vector2(32, 26), 24, Color(0.34, 0.44, 0.52), true, -1.0, true)
	var skin: Color = look.get("skin", Color(0.9, 0.72, 0.58))
	var hair: Color = look.get("hair", Color(0.3, 0.2, 0.12))
	var hat_col: Color = look.get("hat_color", Color(0.3, 0.2, 0.15))
	var coat: Color = look.get("coat", Color(0.3, 0.3, 0.35))
	var style: String = look.get("hair_style", "short")
	var hat: String = look.get("hat", "none")
	var head := Vector2(32, 30)

	# Hair behind the head (long hair, hood)
	if hat == "hood":
		_ellipse(head + Vector2(0, 4), 17, 20, hat_col.darkened(0.2))
	elif style == "long":
		_ellipse(head + Vector2(0, 7), 15, 17, hair.darkened(0.1))
	elif style == "curly":
		for i in 9:
			var a := PI + PI * i / 8.0
			draw_circle(head + Vector2(cos(a) * 12.5, sin(a) * 13.0 + 2.0), 4.0, hair.darkened(0.08), true, -1.0, true)
	# Shoulders and coat
	draw_colored_polygon(PackedVector2Array([Vector2(8, 64), Vector2(12, 50), Vector2(24, 45), Vector2(40, 45), Vector2(52, 50), Vector2(56, 64)]), coat)
	draw_colored_polygon(PackedVector2Array([Vector2(27, 45), Vector2(32, 54), Vector2(37, 45)]), coat.lightened(0.35)) # shirt collar
	if look.has("coat_accent"): # trim along the coat's front
		var trim: Color = look["coat_accent"]
		draw_line(Vector2(27, 46), Vector2(24, 64), trim, 1.4, true)
		draw_line(Vector2(37, 46), Vector2(40, 64), trim, 1.4, true)
		for y in [52.0, 57.0, 62.0]:
			draw_circle(Vector2(23.5 + (y - 46.0) * -0.05, y), 0.9, trim, true, -1.0, true)
	if look.get("sash") != null: # a sash across the chest
		draw_colored_polygon(PackedVector2Array([Vector2(14, 50), Vector2(19, 47), Vector2(52, 62), Vector2(50, 64), Vector2(44, 64)]), look["sash"])
	draw_rect(Rect2(28, 38, 8, 8), skin.darkened(0.12)) # neck
	if style == "braids": # two braids hanging over the shoulders
		for x in [-11.0, 11.0]:
			for k in 4:
				draw_circle(head + Vector2(x * (1.0 + k * 0.04), 6.0 + k * 4.0), 2.4, hair.darkened(0.05 * k), true, -1.0, true)
	# Ears and head
	draw_circle(head + Vector2(-12, 1), 3.2, skin.darkened(0.05), true, -1.0, true)
	draw_circle(head + Vector2(12, 1), 3.2, skin.darkened(0.05), true, -1.0, true)
	_ellipse(head, 12, 14, skin)
	if look.get("earring", false):
		draw_circle(head + Vector2(12.5, 5), 1.4, look.get("earring_color", Color(0.95, 0.8, 0.3)), true, -1.0, true)
	# Hair on top
	match style:
		"short", "ponytail", "braids", "curly":
			draw_colored_polygon(_arc_cap(head, 12.5, 14.5, -0.15), hair)
		"long":
			draw_colored_polygon(_arc_cap(head, 13, 15, 0.1), hair)
			draw_rect(Rect2(head.x - 13, head.y - 2, 3, 14), hair)
			draw_rect(Rect2(head.x + 10, head.y - 2, 3, 14), hair)
		"bun":
			draw_colored_polygon(_arc_cap(head, 12.5, 14.5, -0.2), hair)
			draw_circle(head + Vector2(0, -16), 5.5, hair, true, -1.0, true)
	# Face
	var eye_y := head.y + 1.0
	var eye_open := 1.0 - _blink
	var patch_x := -5.0 if look.get("eyepatch_side", "") == "right" else 5.0 # their right eye is on our left
	for x in [-5.0, 5.0]:
		if is_equal_approx(x, patch_x) and look.get("eyepatch", false):
			continue
		if eye_open > 0.5:
			draw_circle(Vector2(head.x + x, eye_y), 2.2, Color(0.97, 0.97, 0.95), true, -1.0, true)
			draw_circle(Vector2(head.x + x + 0.3, eye_y + 0.2), 1.4, Color(0.12, 0.1, 0.1), true, -1.0, true)
			draw_circle(Vector2(head.x + x + 0.8, eye_y - 0.5), 0.45, Color(1, 1, 1, 0.9), true, -1.0, true)
		else:
			draw_line(Vector2(head.x + x - 2, eye_y), Vector2(head.x + x + 2, eye_y), Color(0.12, 0.1, 0.1), 1.0, true)
		draw_line(Vector2(head.x + x - 2.5, eye_y - 4), Vector2(head.x + x + 2.5, eye_y - 4.5 if x > 0 else eye_y - 4), hair.darkened(0.2), 1.2, true)
	draw_line(head + Vector2(0, 2), head + Vector2(-1.5, 7), skin.darkened(0.25), 1.2, true) # nose
	var beard: String = look.get("beard", "none")
	var beard_col: Color = look.get("beard_color", hair)
	match beard:
		"full", "braided":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-11, 3), head + Vector2(-9, 13), head + Vector2(0, 18),
				head + Vector2(9, 13), head + Vector2(11, 3), head + Vector2(5, 8), head + Vector2(-5, 8)]), beard_col)
			if beard == "braided": # a braid with a gold bead
				for k in 3:
					draw_circle(head + Vector2(0, 19.0 + k * 3.2), 1.8, beard_col.darkened(0.08 * k), true, -1.0, true)
				draw_circle(head + Vector2(0, 28.5), 1.3, Color(0.95, 0.8, 0.3), true, -1.0, true)
		"stubble":
			for i in 14:
				var a := 0.35 + PI * 0.3 * (i % 7) / 6.0 + (0.0 if i < 7 else PI * 0.0)
				var r := 9.5 if i < 7 else 11.0
				var p := head + Vector2(cos(a + PI * 0.15) * r - 0.0, sin(a + PI * 0.15) * r * 0.9 + 2.0)
				draw_circle(p, 0.6, Color(beard_col, 0.55), true, -1.0, true)
		"goatee":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-3, 12), head + Vector2(3, 12), head + Vector2(0, 18)]), beard_col)
	draw_line(head + Vector2(-3, 10.5), head + Vector2(3, 10.5), Color(0.45, 0.2, 0.18), 1.4, true) # mouth
	if beard in ["mustache", "full", "braided", "goatee"]:
		draw_colored_polygon(PackedVector2Array([head + Vector2(-6, 9.5), head + Vector2(0, 7.5), head + Vector2(6, 9.5), head + Vector2(0, 9)]), beard_col.darkened(0.1))
	if look.get("glasses", false):
		for x in [-5.0, 5.0]:
			draw_arc(Vector2(head.x + x, eye_y), 3.6, 0.0, TAU, 16, Color(0.15, 0.12, 0.1), 1.1, true)
		draw_line(Vector2(head.x - 1.4, eye_y), Vector2(head.x + 1.4, eye_y), Color(0.15, 0.12, 0.1), 1.0, true)
	if look.get("eyepatch", false):
		draw_circle(Vector2(head.x + patch_x, eye_y), 3.4, Color(0.08, 0.08, 0.08), true, -1.0, true)
		draw_line(head + Vector2(-12, -5 if patch_x > 0 else -2), head + Vector2(12, -2 if patch_x > 0 else -5), Color(0.08, 0.08, 0.08), 1.2, true)
	# Hats
	match hat:
		"cap":
			draw_colored_polygon(_arc_cap(head + Vector2(0, -2), 13, 13, 0.0), hat_col)
			draw_rect(Rect2(head.x - 13, head.y - 6, 26, 3), hat_col.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([head + Vector2(-2, -6), head + Vector2(16, -5), head + Vector2(14, -3), head + Vector2(-2, -3)]), hat_col.darkened(0.35))
		"bandana":
			draw_colored_polygon(_arc_cap(head + Vector2(0, -1), 13, 14, -0.05), hat_col)
			for i in 4:
				draw_circle(head + Vector2(-7 + i * 5, -9), 0.9, Color(1, 1, 1, 0.8), true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([head + Vector2(11, -3), head + Vector2(18, 2), head + Vector2(15, 5), head + Vector2(11, 0)]), hat_col.darkened(0.15))
		"hood":
			# Stops above the eyebrows; the rest of the hood frames the face from behind
			draw_colored_polygon(_arc_cap(head + Vector2(0, -1), 15, 17, -0.3), hat_col)
		"feather":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-17, -8), head + Vector2(17, -8), head + Vector2(13, -12), head + Vector2(-13, -12)]), hat_col.darkened(0.2))
			draw_colored_polygon(_arc_cap(head + Vector2(0, -9), 10, 9, 0.0), hat_col)
			draw_colored_polygon(PackedVector2Array([head + Vector2(4, -16), head + Vector2(16, -30), head + Vector2(19, -27), head + Vector2(7, -14)]), look.get("hat_accent", Color(0.97, 0.95, 0.9)))
		"tricorn":
			draw_colored_polygon(_arc_cap(head + Vector2(0, -8), 10, 8, 0.0), hat_col)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-19, -6), head + Vector2(0, -12), head + Vector2(19, -6), head + Vector2(0, -9)]), hat_col.darkened(0.15))
			draw_line(head + Vector2(-18, -6), head + Vector2(0, -11), hat_col.lightened(0.3), 0.8, true)
			draw_line(head + Vector2(18, -6), head + Vector2(0, -11), hat_col.lightened(0.3), 0.8, true)
		"straw":
			_ellipse(head + Vector2(0, -8), 21, 4.5, hat_col.darkened(0.1))
			draw_colored_polygon(_arc_cap(head + Vector2(0, -9), 9, 9, 0.0), hat_col)
			draw_rect(Rect2(head.x - 9, head.y - 11, 18, 2.2), Color(0.7, 0.2, 0.15))
		"bicorne":
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append(head + Vector2(lerpf(-20, 20, t), -8.0 - sin(t * PI) * 12.0))
			for i in range(12, -1, -1):
				var t := i / 12.0
				pts.append(head + Vector2(lerpf(-20, 20, t) * 0.9, -7.0 - sin(t * PI) * 4.0))
			draw_colored_polygon(pts, hat_col)
			draw_circle(head + Vector2(0, -14), 1.8, Color(0.95, 0.8, 0.3), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## The top part of an ellipse, down to `low` (fraction of ry below the center; negative = above).
func _arc_cap(center: Vector2, rx: float, ry: float, low: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := asin(clampf(low, -0.99, 0.99))
	for i in 17:
		var a := lerpf(PI - a0, TAU + a0, i / 16.0)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
