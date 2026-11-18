class_name Beast
extends Creature
## Store dyr og monstre på de kæmpe fastlande: jaguar, vildsvin, krokodille og junglegolem.
## Sæt `kind` før dyret tilføjes til verden. Alle værdier ligger i KINDS herunder.

## aggro: hvor tæt kaptajnen må komme · reach: rækkevidde på angrebet · zone: hvor på øen dyret lever
## (0 = midten, 1 = stranden) · passive: angriber kun, hvis det selv bliver ramt
const KINDS := {
	"jaguar": {"hp": 55.0, "speed": 38.0, "chase": 92.0, "aggro": 130.0, "reach": 12.0, "damage": 12.0,
		"cooldown": 1.2, "radius": 8.0, "zone": [0.2, 0.8], "loot": "jaguar", "passive": false},
	"boar": {"hp": 70.0, "speed": 26.0, "chase": 105.0, "aggro": 160.0, "reach": 12.0, "damage": 15.0,
		"cooldown": 1.8, "radius": 9.0, "zone": [0.3, 0.75], "loot": "boar", "passive": true},
	"croc": {"hp": 90.0, "speed": 16.0, "chase": 62.0, "aggro": 70.0, "reach": 16.0, "damage": 20.0,
		"cooldown": 2.0, "radius": 10.0, "zone": [0.84, 0.97], "loot": "croc", "passive": false},
	"golem": {"hp": 260.0, "speed": 14.0, "chase": 30.0, "aggro": 115.0, "reach": 22.0, "damage": 28.0,
		"cooldown": 2.6, "radius": 15.0, "zone": [0.08, 0.4], "loot": "golem", "passive": false},
}

var kind: String = "jaguar"
var _cfg: Dictionary = {}
var _target := Vector2.ZERO
var _attack_timer: float = 0.0
var _attack_anim: float = 0.0 ## 1 lige efter et angreb, falder mod 0
var _angry: float = 0.0 ## sekunder dyret forfølger efter at være ramt
var _step: float = 0.0


func _ready() -> void:
	_cfg = KINDS[kind]
	max_hp = _cfg["hp"]
	speed = _cfg["speed"]
	radius = _cfg["radius"]
	loot_table = _cfg["loot"]
	super._ready()
	_target = global_position
	facing = Vector2.from_angle(randf() * TAU)


func _behave(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_anim = maxf(_attack_anim - delta * 2.5, 0.0)
	_angry = maxf(_angry - delta, 0.0)
	var player := player_character()
	var hunting := false
	if player and player.get("on_land") and home and home.is_on_land(player.global_position):
		var dist := player.global_position.distance_to(global_position)
		var aggro: float = _cfg["aggro"] * (2.0 if _angry > 0.0 else 1.0)
		if dist < aggro and (not _cfg["passive"] or _angry > 0.0):
			hunting = true
			var reach: float = _cfg["reach"] + radius
			if dist > reach:
				move_towards_point(player.global_position, _cfg["chase"], delta)
				_step += delta * _cfg["chase"] * 0.25
			else:
				facing = facing.slerp((player.global_position - global_position).normalized(), 1.0 - exp(-10.0 * delta))
				if _attack_timer <= 0.0:
					_attack_timer = _cfg["cooldown"]
					_attack_anim = 1.0
					player.call("take_damage", _cfg["damage"], global_position)
					if kind == "golem":
						Sfx.play_at("explosion", global_position, -14.0) # jordskælv-stamp
	if not hunting:
		if global_position.distance_to(_target) < 4.0 and home:
			var zone: Array = _cfg["zone"]
			_target = home.random_land_point(zone[0], zone[1])
		move_towards_point(_target, speed, delta)
		_step += delta * speed * 0.25
	# Bliv på øen
	if home and home.normalized_distance(global_position) > 0.97:
		global_position = home.global_position + (global_position - home.global_position) * 0.98


func _on_hurt(_from: Vector2) -> void:
	_angry = 12.0


# --- Tegning (set oppefra) ---------------------------------------------------------

func _draw_body() -> void:
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	draw_circle(Vector2(2, 3), radius * 0.95, Color(0, 0, 0, 0.18), true, -1.0, true) # skygge
	match kind:
		"jaguar":
			_draw_jaguar()
		"boar":
			_draw_boar()
		"croc":
			_draw_croc()
		"golem":
			_draw_golem()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _legs(points: Array, length: float, width: float, col: Color) -> void:
	for i in points.size():
		var p: Vector2 = points[i]
		var swing := sin(_step + (PI if i % 2 == 0 else 0.0)) * length * 0.5
		var side := signf(p.y)
		draw_line(p, p + Vector2(swing, side * length), col, width, true)


func _draw_jaguar() -> void:
	var fur := Color(0.92, 0.68, 0.28)
	var dark := Color(0.25, 0.17, 0.1)
	_legs([Vector2(5, -3), Vector2(5, 3), Vector2(-5, -3), Vector2(-5, 3)], 4.0, 2.0, fur.darkened(0.15))
	var tail_sway := sin(_time * 3.0) * 4.0
	draw_polyline(PackedVector2Array([Vector2(-8, 0), Vector2(-12, tail_sway * 0.5), Vector2(-16, tail_sway)]), fur.darkened(0.1), 1.8, true)
	_ellipse(Vector2.ZERO, 9.0, 4.2, fur)
	for spot in [Vector2(-4, -1.5), Vector2(-1, 1.8), Vector2(2, -1.2), Vector2(4.5, 1.2), Vector2(-6, 1.5)]:
		draw_circle(spot, 0.9, dark, true, -1.0, true)
	var head := Vector2(10.0 + _attack_anim * 3.0, 0)
	draw_circle(head, 3.6, fur.lightened(0.05), true, -1.0, true)
	draw_circle(head + Vector2(-1, -2.8), 1.1, fur.darkened(0.2), true, -1.0, true) # ører
	draw_circle(head + Vector2(-1, 2.8), 1.1, fur.darkened(0.2), true, -1.0, true)
	draw_circle(head + Vector2(1.4, -1.2), 0.6, Color(0.3, 0.8, 0.3), true, -1.0, true)
	draw_circle(head + Vector2(1.4, 1.2), 0.6, Color(0.3, 0.8, 0.3), true, -1.0, true)


func _draw_boar() -> void:
	var hide_col := Color(0.42, 0.3, 0.22)
	_legs([Vector2(4, -4), Vector2(4, 4), Vector2(-4, -4), Vector2(-4, 4)], 3.0, 2.4, hide_col.darkened(0.3))
	_ellipse(Vector2.ZERO, 9.0, 6.0, hide_col)
	draw_line(Vector2(-7, 0), Vector2(6, 0), hide_col.darkened(0.3), 2.0, true) # børster på ryggen
	var head := Vector2(9.0 + _attack_anim * 4.0, 0)
	_ellipse(head, 4.0, 3.6, hide_col.lightened(0.05))
	draw_circle(head + Vector2(3.6, 0), 1.8, Color(0.75, 0.5, 0.45), true, -1.0, true) # tryne
	draw_line(head + Vector2(2.5, -2.4), head + Vector2(5.5, -3.8), Color(0.98, 0.95, 0.85), 1.2, true) # stødtænder
	draw_line(head + Vector2(2.5, 2.4), head + Vector2(5.5, 3.8), Color(0.98, 0.95, 0.85), 1.2, true)
	draw_circle(head + Vector2(0.5, -1.8), 0.6, Color.BLACK, true, -1.0, true)
	draw_circle(head + Vector2(0.5, 1.8), 0.6, Color.BLACK, true, -1.0, true)


func _draw_croc() -> void:
	var skin := Color(0.3, 0.45, 0.25)
	_legs([Vector2(5, -4), Vector2(5, 4), Vector2(-5, -4), Vector2(-5, 4)], 3.5, 1.8, skin.darkened(0.2))
	var sway := sin(_time * 2.0 + _step) * 3.0
	var tail := PackedVector2Array([Vector2(-7, -3), Vector2(-14, -1.5 + sway * 0.5), Vector2(-22, sway), Vector2(-14, 1.5 + sway * 0.5), Vector2(-7, 3)])
	draw_colored_polygon(tail, skin.darkened(0.08))
	_ellipse(Vector2.ZERO, 9.0, 4.5, skin)
	for i in 5: # rygskæl
		draw_circle(Vector2(-6.0 + i * 3.0, 0), 0.9, skin.darkened(0.3), true, -1.0, true)
	var jaw := 0.4 + _attack_anim * 0.6
	var snout := Vector2(9, 0)
	draw_colored_polygon(PackedVector2Array([snout + Vector2(0, -3), snout + Vector2(10, -1.0 - jaw * 2.0), snout + Vector2(10, -0.2), snout + Vector2(0, 0)]), skin.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([snout + Vector2(0, 0), snout + Vector2(10, 0.2), snout + Vector2(10, 1.0 + jaw * 2.0), snout + Vector2(0, 3)]), skin.lightened(0.05))
	if _attack_anim > 0.1:
		draw_line(snout + Vector2(1, 0), snout + Vector2(9, 0), Color(0.75, 0.25, 0.25), 1.0, true) # gab
	draw_circle(snout + Vector2(0.5, -2.2), 0.8, Color(0.95, 0.85, 0.2), true, -1.0, true)
	draw_circle(snout + Vector2(0.5, 2.2), 0.8, Color(0.95, 0.85, 0.2), true, -1.0, true)


func _draw_golem() -> void:
	var rock := Color(0.52, 0.5, 0.47)
	var moss := Color(0.35, 0.55, 0.3)
	var arm_swing := sin(_step * 0.8) * 3.0
	var punch := _attack_anim * 8.0
	# Arme med store stenhænder
	draw_line(Vector2(0, -10), Vector2(6 + arm_swing + punch, -14), rock.darkened(0.15), 4.5, true)
	draw_line(Vector2(0, 10), Vector2(6 - arm_swing + punch, 14), rock.darkened(0.15), 4.5, true)
	draw_circle(Vector2(7 + arm_swing + punch, -14), 4.2, rock, true, -1.0, true)
	draw_circle(Vector2(7 - arm_swing + punch, 14), 4.2, rock, true, -1.0, true)
	# Krop af kantede sten
	var body := PackedVector2Array([Vector2(-11, -6), Vector2(-6, -12), Vector2(5, -11), Vector2(10, -4), Vector2(10, 5), Vector2(4, 12), Vector2(-7, 11), Vector2(-12, 4)])
	draw_colored_polygon(body, rock)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -5), Vector2(-3, -9), Vector2(3, -6), Vector2(-2, -1)]), rock.lightened(0.12))
	_ellipse(Vector2(-5, 4), 4.0, 2.5, moss)
	_ellipse(Vector2(2, -7), 3.0, 1.8, moss.darkened(0.1))
	# Glødende øjne og runer
	var glow := Color(0.4, 1.0, 0.85, 0.75 + 0.25 * sin(_time * 3.0))
	draw_circle(Vector2(7, -3), 1.4, glow, true, -1.0, true)
	draw_circle(Vector2(7, 3), 1.4, glow, true, -1.0, true)
	draw_line(Vector2(-4, 0), Vector2(2, 0), Color(glow, 0.5), 1.0, true)
	draw_line(Vector2(-1, -3), Vector2(-1, 3), Color(glow, 0.5), 1.0, true)
