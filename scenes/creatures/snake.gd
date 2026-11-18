class_name Snake
extends Creature
## Slange i junglen. Angriber kaptajnen, hvis han kommer for tæt på. Giver slangeskind.

const AGGRO_RANGE := 70.0
const BITE_RANGE := 11.0
const BITE_DAMAGE := 6.0
const BITE_COOLDOWN := 1.8

var _target := Vector2.ZERO
var _bite_timer: float = 0.0
var _trail: Array[Vector2] = []


func _init() -> void:
	max_hp = 18.0
	speed = 32.0
	loot_table = "snake"
	radius = 5.0


func _ready() -> void:
	super._ready()
	_target = global_position
	for i in 8:
		_trail.append(global_position)


func _behave(delta: float) -> void:
	_bite_timer = maxf(_bite_timer - delta, 0.0)
	var player := player_character()
	var chasing := false
	if player and player.get("on_land") and home and home.is_on_land(player.global_position):
		var dist := player.global_position.distance_to(global_position)
		if dist < AGGRO_RANGE:
			chasing = true
			if dist > BITE_RANGE:
				move_towards_point(player.global_position, speed * 1.4, delta)
			elif _bite_timer <= 0.0:
				_bite_timer = BITE_COOLDOWN
				player.call("take_damage", BITE_DAMAGE, global_position)
	if not chasing:
		if global_position.distance_to(_target) < 3.0 and home:
			_target = home.random_land_point(0.1, 0.6)
		move_towards_point(_target, speed * 0.6, delta)
	if home and home.normalized_distance(global_position) > 0.9:
		global_position = home.global_position + (global_position - home.global_position) * 0.98
	# Hale der følger hovedet
	if _trail[0].distance_to(global_position) > 2.0:
		_trail.insert(0, global_position)
		_trail.resize(8)


func _draw_body() -> void:
	var col := Color(0.35, 0.55, 0.20)
	var pts := PackedVector2Array()
	for p in _trail:
		pts.append(to_local(p))
	for i in range(pts.size() - 1, 0, -1):
		draw_line(pts[i], pts[i - 1], col.darkened(0.1 * (i % 2)), lerpf(3.5, 1.5, float(i) / pts.size()), true)
	draw_circle(Vector2.ZERO, 3.0, col.lightened(0.1), true, -1.0, true)
	var side := facing.orthogonal()
	draw_circle(facing * 1.5 + side * 1.2, 0.6, Color(0.9, 0.8, 0.1), true, -1.0, true)
	draw_circle(facing * 1.5 - side * 1.2, 0.6, Color(0.9, 0.8, 0.1), true, -1.0, true)
	if fmod(_time, 1.2) < 0.25: # tunge
		draw_line(facing * 3.0, facing * 6.0, Color(0.85, 0.2, 0.25), 0.7, true)
