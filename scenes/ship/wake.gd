class_name Wake
extends Node2D
## Kølvand som et V i vandet: to bølgearme spreder sig skråt ud fra stævnen (som et rigtigt
## Kelvin-kølvand), og en blød stribe hvidt skumvand ligger bag agterstavnen.
## Tegnes i verdenskoordinater (top_level), så sporet bliver liggende, hvor skibet har været.

const LIFE := 3.2 ## sekunder et punkt lever
const STEP := 0.07 ## sekunder mellem punkterne
const SPREAD := 0.36 ## hvor hurtigt armene breder sig i forhold til farten (≈ 20° vinkel)

var length := 58.0
var beam := 20.0
var min_speed := 6.0

var _points: Array[Dictionary] = []
var _timer := 0.0
var _time := 0.0


func _ready() -> void:
	top_level = true
	z_index = -1
	global_position = Vector2.ZERO
	global_rotation = 0.0


## Kaldes hvert frame af ShipVisual. forward = skibets retning, speed i px/s.
func track(ship_pos: Vector2, forward: Vector2, speed: float, delta: float, active: bool) -> void:
	_time += delta
	for p in _points:
		p["age"] = float(p["age"]) + delta
	while not _points.is_empty() and float(_points[0]["age"]) > LIFE:
		_points.pop_front()
	_timer -= delta
	if active and speed > min_speed and _timer <= 0.0:
		_timer = STEP
		var side := Vector2(-forward.y, forward.x)
		_points.append({
			"bow": ship_pos + forward * length * 0.42,
			"stern": ship_pos - forward * length * 0.48,
			"side": side,
			"speed": speed,
			"age": 0.0,
			"seed": randf() * TAU,
		})
	if _points.is_empty():
		if visible:
			queue_redraw()
		return
	queue_redraw()


func clear() -> void:
	_points.clear()
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2 or not Settings.effects:
		return
	var n := _points.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var center := PackedVector2Array()
	var cols := PackedColorArray()
	var center_cols := PackedColorArray()
	for i in n:
		var p := _points[n - 1 - i] # nyeste først, så linjen starter ved skibet
		var age: float = p["age"]
		var k := age / LIFE
		var strength := clampf(float(p["speed"]) / 90.0, 0.25, 1.0)
		var wobble := sin(float(p["seed"]) + _time * 2.0 + age * 3.0) * (1.0 + age * 1.5)
		var out := beam * 0.45 + float(p["speed"]) * SPREAD * age + wobble
		var bow: Vector2 = p["bow"]
		var side: Vector2 = p["side"]
		left.append(bow + side * out)
		right.append(bow - side * out)
		center.append(p["stern"] as Vector2 + side * wobble * 0.4)
		var a := (1.0 - k) * (1.0 - k) * strength
		cols.append(Color(1, 1, 1, 0.75 * a))
		center_cols.append(Color(0.92, 0.98, 1.0, 0.28 * a))
	# Skumstriben bag skibet: bred og blød
	draw_polyline_colors(center, center_cols, beam * 0.9, true)
	draw_polyline_colors(center, center_cols, beam * 0.35, true)
	# De to arme i V'et: en bred svag bølge og en smal lys kam
	var faint := PackedColorArray()
	for c in cols:
		faint.append(Color(c, c.a * 0.35))
	for arm in [left, right]:
		draw_polyline_colors(arm, faint, 6.0, true)
		draw_polyline_colors(arm, cols, 2.0, true)
