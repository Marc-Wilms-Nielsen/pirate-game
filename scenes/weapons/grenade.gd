class_name Grenade
extends Node2D
## Kastet granat. Flyver i en bue hen til målet og udløser sin effekt:
## "explosive" (sprængning), "fire" (brand), "poison" (giftsky) eller "flash" (blænder dyr).

const FLIGHT_TIME := 0.7

var weapon_id: String = "grenade"
var start := Vector2.ZERO
var target := Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	z_index = 9
	global_position = start


func _process(delta: float) -> void:
	_t += delta / FLIGHT_TIME
	global_position = start.lerp(target, minf(_t, 1.0))
	rotation += delta * 10.0
	if _t >= 1.0:
		_detonate()
		queue_free()
	queue_redraw()


func _draw() -> void:
	var height := sin(minf(_t, 1.0) * PI) * 26.0
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_circle(Vector2(height * 0.3, height * 0.5), 2.2, Color(0, 0, 0, 0.25), true, -1.0, true) # skygge
	var col: Color = {"grenade": Color(0.2, 0.2, 0.22), "firebomb": Color(0.75, 0.35, 0.15),
		"poison": Color(0.35, 0.6, 0.25), "flash": Color(0.85, 0.85, 0.9)}.get(weapon_id, Color.BLACK)
	draw_circle(Vector2(0, -height), 3.0, col, true, -1.0, true)
	draw_circle(Vector2(1.5, -height - 2.5), 1.0, Color(1, 0.8, 0.3), true, -1.0, true) # lunte


func _detonate() -> void:
	var w: Dictionary = Catalog.WEAPONS[weapon_id]
	var radius: float = w["radius"]
	match w["effect"]:
		"explosive":
			Sfx.play_at("explosion", target, 2.0)
			_burst(Color(1.0, 0.7, 0.3), 26, 90.0)
			_burst(Color(0.5, 0.5, 0.5), 18, 40.0)
			for c in get_tree().get_nodes_in_group("creatures"):
				var creature := c as Creature
				var d := creature.global_position.distance_to(target)
				if d < radius:
					creature.take_damage(w["damage"] * (1.0 - d / radius * 0.6), target)
			for e in get_tree().get_nodes_in_group("enemies"):
				var enemy := e as EnemyShip
				if enemy.global_position.distance_to(target) < radius + enemy.length() * 0.4:
					enemy.take_damage(w["damage"], target)
		"fire":
			Sfx.play_at("fire", target)
			_spawn_field(w, Color(1.0, 0.5, 0.15), "fire")
		"poison":
			Sfx.play_at("gas", target)
			_spawn_field(w, Color(0.45, 0.85, 0.3), "poison")
		"flash":
			Sfx.play_at("flash", target)
			_burst(Color(1, 1, 0.9), 30, 140.0)
			for c in get_tree().get_nodes_in_group("creatures"):
				var creature := c as Creature
				if creature.global_position.distance_to(target) < radius:
					creature.stun(w["stun"])
			var flash := FlashRing.new()
			flash.global_position = target
			flash.radius = radius
			Game.world_root.add_child(flash)


func _spawn_field(w: Dictionary, color: Color, kind: String) -> void:
	var field := EffectField.new()
	field.global_position = target
	field.radius = w["radius"]
	field.damage_per_second = w["damage"]
	field.duration = w["duration"]
	field.color = color
	field.kind = kind
	Game.world_root.add_child(field)


func _burst(color: Color, count: int, speed: float) -> void:
	if not Settings.effects:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 1.6
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	p.global_position = target
	p.z_index = 9
	Game.world_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Hvid ring der udvider sig fra en blændgranat.
class FlashRing extends Node2D:
	var radius: float = 70.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta * 2.5
		if _t >= 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius * _t, Color(1, 1, 0.9, 0.5 * (1.0 - _t)), true, -1.0, true)
