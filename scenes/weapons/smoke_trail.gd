class_name SmokeTrail
extends Node2D
## Krudtrøg efter en kanonkugle: en tynd grå stribe, der bliver hængende lidt i luften,
## breder sig, driver med vinden og forsvinder langsomt. Lever videre efter kuglen er væk.

const LIFE := 1.8 ## sekunder et røgpunkt hænger i luften
const STEP := 7.0 ## px mellem røgpunkterne

var _points: Array[Dictionary] = []
var _attached := true
var _last := Vector2.INF


static func follow(ball: Node2D) -> SmokeTrail:
	if Game.world_root == null or not Settings.effects:
		return null
	var trail := SmokeTrail.new()
	trail.z_index = 6
	Game.world_root.add_child(trail)
	trail.add_point(ball.global_position)
	return trail


func add_point(pos: Vector2) -> void:
	if _last != Vector2.INF and pos.distance_to(_last) < STEP:
		return
	_last = pos
	_points.append({"pos": pos, "age": 0.0, "drift": Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0})


## Kuglen er væk – røgen hænger lidt endnu og forsvinder så.
func detach() -> void:
	_attached = false


func _process(delta: float) -> void:
	var wind: Vector2 = Game.wind * 0.08 + Vector2(2.0, -3.0)
	for p in _points:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + ((p["drift"] as Vector2) + wind) * delta
	while not _points.is_empty() and float(_points[0]["age"]) > LIFE:
		_points.pop_front()
	if not _attached and _points.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	# Tegnes i stykker, så bredden kan vokse med alderen (røgen breder sig)
	for i in range(1, _points.size()):
		var a := _points[i - 1]
		var b := _points[i]
		var age := (float(a["age"]) + float(b["age"])) * 0.5
		var k := clampf(age / LIFE, 0.0, 1.0)
		var alpha := 0.42 * (1.0 - k) * (1.0 - k) * clampf(age * 8.0, 0.0, 1.0)
		var width := 1.6 + k * 6.0
		var col := Color(0.86, 0.86, 0.84, alpha)
		draw_line(a["pos"], b["pos"], col, width, true)
