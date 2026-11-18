class_name Shark
extends Creature
## Haj på dybt vand. Cirkler rundt og angriber kaptajnen, hvis han svømmer for langt ud.

const CHASE_RANGE := 220.0
const BITE_RANGE := 13.0
const BITE_DAMAGE := 14.0
const BITE_COOLDOWN := 1.6
const MIN_DEPTH := 0.35

var _center := Vector2.ZERO
var _angle: float = 0.0
var _orbit: float = 80.0
var _bite_timer: float = 0.0


func _init() -> void:
	max_hp = 40.0
	speed = 45.0
	loot_table = "shark"
	radius = 8.0


func _ready() -> void:
	super._ready()
	_center = global_position
	_angle = randf() * TAU
	_orbit = randf_range(60.0, 120.0)


func _behave(delta: float) -> void:
	_bite_timer = maxf(_bite_timer - delta, 0.0)
	var player := player_character()
	if player and not player.get("on_land"):
		var dist := player.global_position.distance_to(global_position)
		if dist < CHASE_RANGE and Game.water_depth(player.global_position) > MIN_DEPTH * 0.5:
			if dist > BITE_RANGE:
				_move_in_water(player.global_position, speed * 1.5, delta)
			elif _bite_timer <= 0.0:
				_bite_timer = BITE_COOLDOWN
				player.call("take_damage", BITE_DAMAGE, global_position)
			return
	_angle += delta * speed / _orbit
	_move_in_water(_center + Vector2.from_angle(_angle) * _orbit, speed, delta)


func _move_in_water(target: Vector2, spd: float, delta: float) -> void:
	var before := global_position
	move_towards_point(target, spd, delta)
	if Game.water_depth(global_position) < MIN_DEPTH:
		global_position = before # hajer bliver på dybt vand
		_angle += PI * 0.5


func _draw_body() -> void:
	var back := -facing
	var side := facing.orthogonal()
	var sway := sin(_time * 6.0) * 2.0
	var body := Color(0.35, 0.42, 0.50, 0.75) # halvt under vandet
	draw_circle(facing * 2.0, 5.0, body, true, -1.0, true)
	draw_circle(back * 4.0, 4.0, body, true, -1.0, true)
	var tail := PackedVector2Array([back * 8.0, back * 13.0 + side * (4.0 + sway), back * 12.0 - side * (4.0 - sway)])
	draw_colored_polygon(tail, body)
	# Rygfinne over vandet
	var fin := PackedVector2Array([facing * 2.0, back * 4.0 + side * 0.8, back * 3.0 - side * 0.8])
	draw_colored_polygon(fin, Color(0.25, 0.30, 0.36))
	draw_arc(Vector2.ZERO, 9.0 + sin(_time * 3.0), 0.0, TAU, 24, Color(1, 1, 1, 0.25), 1.0, true)
