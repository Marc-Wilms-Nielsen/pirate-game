class_name ResourceNode
extends Node2D
## Noget man kan samle: træ, klippe, malmåre eller urtebusk.
## Kaptajnen går hen til det og trykker F. Kræver evt. værktøj (økse/hakke).

const RANGE := 20.0

var kind: String = "tree"
var hits_left: int = 3
var _respawn: float = 0.0
var _shake: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	add_to_group("resources")
	hits_left = Catalog.RESOURCE_NODES[kind]["hits"]
	_seed = randf() * 100.0
	z_index = 1
	set_process(false)


func info() -> Dictionary:
	return Catalog.RESOURCE_NODES[kind]


func depleted() -> bool:
	return hits_left <= 0


func can_gather(pos: Vector2) -> bool:
	return not depleted() and pos.distance_to(global_position) < RANGE


func missing_tool() -> String:
	var tool: String = info()["tool"]
	if tool != "" and not Game.tools.get(tool, false):
		return Catalog.TOOLS[tool]["name"]
	return ""


## Kaldes når kaptajnen er færdig med at samle.
func gather() -> void:
	var data := info()
	var messages: Array[String] = []
	for y in data["yields"]:
		if randf() > float(y[3]):
			continue
		var got := Game.add_item(y[0], randi_range(y[1], y[2]))
		if got > 0:
			messages.append("+%d %s" % [got, Game.item_name(y[0])])
	if messages.is_empty():
		messages.append("The cargo hold is full!")
	for i in messages.size():
		Game.popup(messages[i], global_position + Vector2(0, -14 - 12 * i), Color(0.8, 1, 0.7))
	hits_left -= 1
	_shake = 1.0
	set_process(true)
	Sfx.play_at("hit" if kind in ["tree", "rock", "ore"] else "swing", global_position, -8.0)
	if depleted():
		_respawn = data["respawn"]


func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 4.0, 0.0)
	if depleted():
		_respawn -= delta
		if _respawn <= 0.0:
			hits_left = info()["hits"]
	queue_redraw()
	if _shake <= 0.0 and not depleted():
		set_process(false) # intet at animere – spar CPU


func _draw() -> void:
	var off := Vector2(sin(_shake * 30.0) * 1.5 * _shake, 0)
	match kind:
		"tree":
			if depleted():
				draw_circle(Vector2.ZERO, 3.0, Color(0.45, 0.3, 0.15), true, -1.0, true) # stub
				draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 12, Color(0.35, 0.22, 0.1), 0.8, true)
				return
			draw_circle(Vector2(5, 7), 11.0, Color(0, 0, 0, 0.2), true, -1.0, true)
			draw_circle(off, 11.0, Color(0.18, 0.42, 0.2), true, -1.0, true)
			for i in 5:
				var a := _seed + TAU * i / 5.0
				draw_circle(off + Vector2.from_angle(a) * 6.0, 5.5, Color(0.24, 0.52, 0.25), true, -1.0, true)
			draw_circle(off + Vector2(-2, -2), 4.0, Color(0.32, 0.6, 0.3), true, -1.0, true)
		"rock", "ore":
			var col := Color(0.55, 0.53, 0.5) if kind == "rock" else Color(0.45, 0.4, 0.42)
			var size := 7.0 if not depleted() else 3.5
			draw_circle(Vector2(3, 4), size, Color(0, 0, 0, 0.2), true, -1.0, true)
			draw_circle(off, size, col, true, -1.0, true)
			draw_circle(off + Vector2(-2, -2), size * 0.55, col.lightened(0.15), true, -1.0, true)
			if kind == "ore" and not depleted():
				for i in 4:
					var a := _seed + TAU * i / 4.0
					draw_circle(off + Vector2.from_angle(a) * 3.5, 1.2, Color(0.8, 0.5, 0.3) if i % 2 == 0 else Color(0.95, 0.8, 0.3), true, -1.0, true)
		"herb":
			if depleted():
				draw_circle(Vector2.ZERO, 2.0, Color(0.35, 0.45, 0.25), true, -1.0, true)
				return
			for i in 6:
				var a := _seed + TAU * i / 6.0
				draw_line(off, off + Vector2.from_angle(a) * 5.0, Color(0.35, 0.65, 0.3), 1.6, true)
			draw_circle(off, 1.8, Color(0.85, 0.5, 0.85), true, -1.0, true)
