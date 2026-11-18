class_name Wake
extends Node2D
## A discreet wake: a short, thin strip of foam right behind the stern that fades in about
## 1.5 s, and faint little ripples at the bow that only last a moment. It gets a little
## clearer at higher speed, but never strong (the old wide V-shaped wake was too loud).
## Drawn in world coordinates (top_level), so the trail stays where the ship has been.

const LIFE := 1.5 ## seconds a foam point lives
const STEP := 0.07 ## seconds between points
const RIPPLE_LIFE := 0.6 ## seconds a bow ripple lives
const RIPPLE_STEP := 0.35 ## seconds between bow ripples

var length := 58.0
var beam := 20.0
var min_speed := 6.0
var color := Color(0.92, 0.98, 1.0) ## the foam colour (a ship style choice)

var _points: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _timer := 0.0
var _ripple_timer := 0.0
var _time := 0.0


func _ready() -> void:
	top_level = true
	z_index = -1
	global_position = Vector2.ZERO
	global_rotation = 0.0


## Called every frame by ShipVisual. forward = the ship's heading, speed in px/s.
func track(ship_pos: Vector2, forward: Vector2, speed: float, delta: float, active: bool) -> void:
	_time += delta
	for p in _points:
		p["age"] = float(p["age"]) + delta
	while not _points.is_empty() and float(_points[0]["age"]) > LIFE:
		_points.pop_front()
	for r in _ripples:
		r["age"] = float(r["age"]) + delta
	while not _ripples.is_empty() and float(_ripples[0]["age"]) > RIPPLE_LIFE:
		_ripples.pop_front()
	_timer -= delta
	_ripple_timer -= delta
	var moving := active and speed > min_speed
	if moving and _timer <= 0.0:
		_timer = STEP
		var side := Vector2(-forward.y, forward.x)
		_points.append({"stern": ship_pos - forward * length * 0.46, "side": side, "speed": speed, "age": 0.0, "seed": randf() * TAU})
	if moving and _ripple_timer <= 0.0:
		_ripple_timer = RIPPLE_STEP
		_ripples.append({"pos": ship_pos + forward * length * 0.44, "dir": forward, "speed": speed, "age": 0.0})
	if not _points.is_empty() or not _ripples.is_empty() or visible:
		queue_redraw()


func clear() -> void:
	_points.clear()
	_ripples.clear()
	queue_redraw()


## 0.15 when slow, up to 0.35 at full speed: always discreet.
static func strength(speed: float) -> float:
	return lerpf(0.15, 0.35, clampf(speed / 90.0, 0.0, 1.0))


func _draw() -> void:
	if not Settings.effects:
		return
	# Foam strip behind the stern: thin, tapering, fading quickly
	var n := _points.size()
	if n >= 2:
		var line := PackedVector2Array()
		var cols := PackedColorArray()
		for i in n:
			var p := _points[n - 1 - i] # newest first, so the line starts at the ship
			var age: float = p["age"]
			var k := age / LIFE
			var wobble := sin(float(p["seed"]) + _time * 2.0 + age * 3.0) * (0.5 + age)
			line.append(p["stern"] as Vector2 + (p["side"] as Vector2) * wobble)
			cols.append(Color(color, (1.0 - k) * (1.0 - k) * strength(float(p["speed"]))))
		draw_polyline_colors(line, cols, beam * 0.3, true)
		var core := PackedColorArray()
		for c in cols:
			core.append(Color(color.lightened(0.5), c.a * 0.8))
		draw_polyline_colors(line, core, maxf(beam * 0.08, 1.0), true)
	# Small ripples at the bow: two short arcs that spread and fade
	for r in _ripples:
		var age: float = r["age"]
		var k := age / RIPPLE_LIFE
		var a := (1.0 - k) * strength(float(r["speed"])) * 0.9
		var dir: Vector2 = r["dir"]
		var radius := beam * (0.35 + k * 0.6)
		var ang := dir.angle()
		draw_arc(r["pos"] as Vector2 - dir * radius * 0.5, radius, ang + 0.7, ang + 1.6, 8, Color(color.lightened(0.5), a), 1.0, true)
		draw_arc(r["pos"] as Vector2 - dir * radius * 0.5, radius, ang - 1.6, ang - 0.7, 8, Color(color.lightened(0.5), a), 1.0, true)
