class_name Crab
extends Creature
## Fredelig krabbe på stranden. Løber sidelæns og flygter fra kaptajnen. Giver mad.

var _target := Vector2.ZERO
var _wait: float = 0.0


func _init() -> void:
	max_hp = 8.0
	speed = 28.0
	loot_table = "crab"
	radius = 5.0


func _ready() -> void:
	super._ready()
	_target = global_position


func _behave(delta: float) -> void:
	var player := player_character()
	if player and player.global_position.distance_to(global_position) < 55.0:
		var away := (global_position - player.global_position).normalized()
		_try_move(global_position + away * 30.0, speed * 1.8, delta)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if global_position.distance_to(_target) < 3.0:
		_wait = randf_range(1.0, 4.0)
		if home:
			_target = home.random_land_point(0.72, 0.95)
		return
	_try_move(_target, speed, delta)


func _try_move(target: Vector2, spd: float, delta: float) -> void:
	var before := global_position
	move_towards_point(target, spd, delta)
	# Krabber bliver på stranden
	if home and (home.normalized_distance(global_position) > 0.98 or home.normalized_distance(global_position) < 0.6):
		global_position = before
		_target = home.random_land_point(0.72, 0.95) if home else before


func _draw_body() -> void:
	var walk := sin(_time * 18.0) * 1.2
	var side := facing.orthogonal()
	var shell := Color(0.85, 0.35, 0.25)
	draw_circle(Vector2(1.5, 2), 5.0, Color(0, 0, 0, 0.18), true, -1.0, true)
	for i in 3: # ben
		var off := (i - 1) * 2.2
		draw_line(side * 3.5 + facing * off, side * 7.0 + facing * (off + walk), shell.darkened(0.3), 1.0, true)
		draw_line(-side * 3.5 + facing * off, -side * 7.0 + facing * (off - walk), shell.darkened(0.3), 1.0, true)
	draw_circle(Vector2.ZERO, 4.2, shell, true, -1.0, true)
	draw_circle(facing * 4.5 + side * 2.5, 1.6, shell.lightened(0.15), true, -1.0, true) # klo
	draw_circle(facing * 4.5 - side * 2.5, 1.6, shell.lightened(0.15), true, -1.0, true)
	draw_circle(facing * 2.0 + side * 1.2, 0.7, Color.BLACK, true, -1.0, true) # øjne
	draw_circle(facing * 2.0 - side * 1.2, 0.7, Color.BLACK, true, -1.0, true)
