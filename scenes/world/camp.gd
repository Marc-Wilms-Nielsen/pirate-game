class_name Camp
extends Node2D
## Piratlejr på en ø: telte, bål og en skattekiste vogtet af banditter.
## Banditterne kommer igen et stykke tid efter at lejren er ryddet.

const RESPAWN_TIME := 420.0

var island: Island
var _time: float = 0.0
var _respawn: float = 0.0
var _chest: Chest


func _ready() -> void:
	add_to_group("camps")
	z_index = 1
	WorldSky.add_lantern(self, Vector2(0, -6), 90.0, Color(1.0, 0.55, 0.25), 1.2)
	_chest = Chest.new()
	_chest.loot_table = "camp_chest"
	_chest.position = Vector2(0, 6)
	add_child(_chest)
	# Banditterne kommer først, når lejren "vågner" (spilleren er i nærheden) – se _process


var _bandits: Array = []
var _spawned_once := false


func bandits() -> Array:
	_bandits = _bandits.filter(func(b: Variant) -> bool: return is_instance_valid(b) and not (b as Node).is_queued_for_deletion())
	return _bandits


func _spawn_bandits() -> void:
	var count := randi_range(2, 4)
	for i in count:
		var b := Bandit.new()
		b.style = "gunner" if i % 2 == 1 else "melee"
		b.home = island
		b.camp_center = global_position
		b.global_position = global_position + Vector2.from_angle(TAU * i / count) * 22.0
		b.add_to_group("bandits")
		_bandits.append(b)
		Game.world_root.add_child.call_deferred(b)
		var streamer := get_tree().get_first_node_in_group("streamer") as WorldStreamer
		if streamer:
			streamer.add.call_deferred(b)


func _process(delta: float) -> void:
	_time += delta
	if not _spawned_once:
		_spawned_once = true
		_spawn_bandits()
	if bandits().is_empty():
		_respawn += delta
		if _respawn >= RESPAWN_TIME:
			_respawn = 0.0
			_spawn_bandits()
	queue_redraw()


func _draw() -> void:
	# Telte
	for t in [Vector2(-26, -14), Vector2(22, -18), Vector2(-4, -30)]:
		var tent := PackedVector2Array([t + Vector2(-10, 6), t + Vector2(0, -8), t + Vector2(10, 6)])
		draw_colored_polygon(PackedVector2Array([tent[0] + Vector2(3, 3), tent[1] + Vector2(3, 3), tent[2] + Vector2(3, 3)]), Color(0, 0, 0, 0.2))
		draw_colored_polygon(tent, Color(0.6, 0.5, 0.38))
		draw_line(t + Vector2(0, -8), t + Vector2(0, 6), Color(0.45, 0.35, 0.25), 1.0, true)
	# Bål
	for i in 6:
		var a := TAU * i / 6.0
		draw_circle(Vector2.from_angle(a) * 5.0 + Vector2(0, -6), 1.6, Color(0.5, 0.48, 0.45), true, -1.0, true)
	var flicker := 0.8 + 0.2 * sin(_time * 13.0)
	draw_circle(Vector2(0, -6), 4.5 * flicker, Color(1.0, 0.5, 0.15, 0.85), true, -1.0, true)
	draw_circle(Vector2(0, -7), 2.5 * flicker, Color(1.0, 0.9, 0.4), true, -1.0, true)
	draw_circle(Vector2(0, -6), 18.0, Color(1.0, 0.7, 0.3, 0.06 + 0.03 * sin(_time * 7.0)), true, -1.0, true)
	# Tønder og kasser
	draw_rect(Rect2(14, 2, 7, 6), Color(0.5, 0.33, 0.18))
	draw_circle(Vector2(-18, 6), 3.5, Color(0.45, 0.3, 0.16), true, -1.0, true)
