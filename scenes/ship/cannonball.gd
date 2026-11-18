class_name Cannonball
extends Area2D
## Kanonkugle. Flyver lige ud, rammer skibe og havdyr, og plasker i vandet ved max rækkevidde.

var velocity := Vector2.ZERO
var damage: float = 10.0
var max_distance: float = 380.0
var shooter: Node ## skibet der skød (rammer ikke sig selv)
var _travelled: float = 0.0
var _done := false
var _trail: SmokeTrail


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # skibe (væsner findes via afstand)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_hit)
	z_index = 6
	_trail = SmokeTrail.follow(self)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if _trail:
		_trail.add_point(global_position)
	for c in get_tree().get_nodes_in_group("creatures"):
		var creature := c as Creature
		if creature.global_position.distance_squared_to(global_position) < pow(creature.radius + 3.0, 2.0):
			_on_hit(creature)
			return
	if _travelled >= max_distance:
		_splash()
	elif Game.is_land(global_position):
		_finish()
	queue_redraw()


func _on_hit(target: Node) -> void:
	if _done or target == shooter or not target.has_method("take_damage"):
		return
	# Ingen vådeskud mellem dig og dine eskorteskibe
	if is_instance_valid(shooter) and shooter.is_in_group("allies") and target.is_in_group("allies"):
		return
	target.call("take_damage", damage, global_position)
	Sfx.play_at("hit", global_position, -2.0)
	Sfx.play_at("explosion", global_position, -16.0)
	Fx.hit(global_position, 1.0 if target is CharacterBody2D else 0.6)
	_finish()


func _splash() -> void:
	Sfx.play_at("splash", global_position, -14.0)
	_spawn_burst(Color(0.9, 0.97, 1.0), 10)
	_finish()


func _finish() -> void:
	_done = true
	if is_instance_valid(_trail):
		_trail.add_point(global_position)
		_trail.detach()
	queue_free()


func _spawn_burst(color: Color, count: int) -> void:
	if Game.world_root == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	p.global_position = global_position
	p.z_index = 6
	Game.world_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _draw() -> void:
	# Skygge længere nede på vandet, så kuglen ser ud til at flyve i en bue
	var t := clampf(_travelled / max_distance, 0.0, 1.0)
	var height := sin(t * PI) * 10.0
	draw_circle(Vector2(height * 0.4, height * 0.7), 2.2, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_circle(Vector2.ZERO, 2.4, Color(0.12, 0.12, 0.14), true, -1.0, true)
