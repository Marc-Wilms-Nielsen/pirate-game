class_name EffectField
extends Node2D
## Brand eller giftsky der ligger et stykke tid og skader dyr indenfor.

var radius: float = 40.0
var damage_per_second: float = 6.0
var duration: float = 4.0
var color := Color(1, 0.5, 0.15)
var kind: String = "fire"
var _age: float = 0.0
var _tick: float = 0.0
var _blobs: Array[Vector3] = [] ## x, y, størrelse


func _ready() -> void:
	z_index = 4
	for i in 14:
		var a := randf() * TAU
		_blobs.append(Vector3(cos(a) * radius * sqrt(randf()), sin(a) * radius * sqrt(randf()), randf_range(5.0, 11.0)))


func _process(delta: float) -> void:
	_age += delta
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		for c in get_tree().get_nodes_in_group("creatures"):
			var creature := c as Creature
			if creature.global_position.distance_to(global_position) < radius:
				creature.take_damage(damage_per_second * 0.5, global_position)
				if kind == "poison":
					creature.slow(0.4, 2.0)
	if _age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var life := 1.0 - _age / duration
	var fade := minf(life * 3.0, 1.0) * minf(_age * 4.0, 1.0)
	for i in _blobs.size():
		var b := _blobs[i]
		var wobble := sin(_age * (6.0 if kind == "fire" else 1.5) + i) * 2.0
		var size := b.z + wobble
		if kind == "fire":
			draw_circle(Vector2(b.x, b.y), size, Color(color, 0.35 * fade), true, -1.0, true)
			draw_circle(Vector2(b.x, b.y - 2.0), size * 0.5, Color(1.0, 0.9, 0.4, 0.5 * fade), true, -1.0, true)
		else:
			var drift := Vector2(sin(_age * 0.7 + i), cos(_age * 0.5 + i)) * _age * 3.0
			draw_circle(Vector2(b.x, b.y) + drift, size * 1.4, Color(color, 0.22 * fade), true, -1.0, true)
