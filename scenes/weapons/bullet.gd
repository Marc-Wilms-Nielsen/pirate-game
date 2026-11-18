class_name Bullet
extends Node2D
## Kugle fra kaptajnens skydevåben. Flyver lige ud og rammer dyr (og skibe) på vejen.

const SPEED := 650.0

var direction := Vector2.RIGHT
var damage: float = 10.0
var max_distance: float = 200.0
var hostile := false ## true = affyret af en bandit, rammer kaptajnen
var _travelled: float = 0.0
var _trail_start := Vector2.ZERO


func _ready() -> void:
	z_index = 8
	_trail_start = global_position


func _physics_process(delta: float) -> void:
	var step := direction * SPEED * delta
	global_position += step
	_travelled += step.length()
	if hostile:
		var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
		if player and player.global_position.distance_to(global_position) < 7.0:
			player.take_damage(damage, global_position - direction * 10.0)
			queue_free()
			return
		if _travelled >= max_distance:
			queue_free()
		queue_redraw()
		return
	for c in get_tree().get_nodes_in_group("creatures"):
		var creature := c as Creature
		if creature.global_position.distance_squared_to(global_position) < pow(creature.radius + 2.0, 2.0):
			creature.take_damage(damage, global_position - direction * 10.0)
			queue_free()
			return
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyShip
		if enemy.global_position.distance_to(global_position) < enemy.length() * 0.35:
			enemy.take_damage(damage * 0.3, global_position)
			queue_free()
			return
	if _travelled >= max_distance:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var tail := -direction * minf(_travelled, 14.0)
	draw_line(tail, Vector2.ZERO, Color(1, 0.95, 0.7, 0.6), 1.2, true)
	draw_circle(Vector2.ZERO, 1.1, Color(0.2, 0.2, 0.2), true, -1.0, true)
