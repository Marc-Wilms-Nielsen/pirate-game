class_name Fx
## Små effekter: mundingsglimt, træfninger med træsplinter og eksplosioner når skibe går ned.
## Alt laves med CPUParticles2D og en lille tegnet "ildkugle", så det er billigt at vise.


## Kort, gult glimt ud af kanonmundingen.
static func muzzle_flash(parent: Node2D, pos: Vector2, dir: Vector2) -> void:
	var f := Blast.new()
	f.position = pos
	f.radius = 5.0
	f.duration = 0.12
	f.direction = dir
	f.ring = false
	parent.add_child(f)


## Kanonkugle rammer: ildglimt, træsplinter, lidt røg.
static func hit(pos: Vector2, scale := 1.0) -> void:
	if Game.world_root == null:
		return
	var f := Blast.new()
	f.global_position = pos
	f.radius = 9.0 * scale
	f.duration = 0.3
	Game.world_root.add_child(f)
	if Settings.effects:
		_particles(pos, 14, Color(0.55, 0.36, 0.18), Color(0.4, 0.26, 0.12, 0.0), 60.0, 140.0, 0.8, 1.2, 2.2, 140.0) # splinter
		_particles(pos, 8, Color(0.4, 0.38, 0.36, 0.7), Color(0.6, 0.6, 0.6, 0.0), 10.0, 30.0, 1.4, 2.5, 4.5, 0.0) # røg


## Stor eksplosion (krudtkammeret springer).
static func explosion(pos: Vector2, scale := 1.0) -> void:
	if Game.world_root == null:
		return
	var f := Blast.new()
	f.global_position = pos
	f.radius = 26.0 * scale
	f.duration = 0.6
	Game.world_root.add_child(f)
	Sfx.play_at("explosion", pos, -2.0)
	if Settings.effects:
		_particles(pos, 30, Color(1.0, 0.75, 0.3), Color(0.5, 0.1, 0.05, 0.0), 40.0, 110.0, 0.7, 2.0, 4.0, 0.0) # ild
		_particles(pos, 26, Color(0.5, 0.33, 0.16), Color(0.35, 0.22, 0.1, 0.0), 80.0, 200.0, 1.2, 1.4, 2.8, 160.0) # planker og splinter
		_particles(pos, 18, Color(0.25, 0.24, 0.23, 0.8), Color(0.5, 0.5, 0.5, 0.0), 15.0, 45.0, 2.6, 4.0, 8.0, 0.0) # sort røg


## Et skib går ned: en stor eksplosion og et par mindre efter hinanden langs skroget.
static func ship_explodes(ship: Node2D, ship_length: float) -> void:
	explosion(ship.global_position, clampf(ship_length / 60.0, 0.8, 2.2))
	for i in 3:
		var t := ship.get_tree().create_timer(0.25 + i * randf_range(0.2, 0.35), false)
		var offset := Vector2.from_angle(ship.rotation) * randf_range(-0.4, 0.4) * ship_length + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var pos := ship.global_position + offset
		t.timeout.connect(func() -> void: explosion(pos, randf_range(0.5, 0.9)))


static func _particles(pos: Vector2, amount: int, from: Color, to: Color, vmin: float, vmax: float, life: float,
		smin: float, smax: float, damping: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.92
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.damping_min = damping * 0.7 if damping > 0.0 else vmin * 0.6
	p.damping_max = damping if damping > 0.0 else vmax * 0.6
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	p.color_ramp = g
	p.global_position = pos
	p.z_index = 7
	Game.world_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Ildkugle der vokser og falmer, med en trykbølge-ring på vandet.
class Blast extends Node2D:
	var radius: float = 10.0
	var duration: float = 0.3
	var direction := Vector2.ZERO
	var ring := true
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var c := direction * radius * 0.8 * k
		var r := radius * (0.4 + 0.8 * k)
		draw_circle(c, r * 1.25, Color(1.0, 0.45, 0.1, 0.35 * (1.0 - k)), true, -1.0, true)
		draw_circle(c, r, Color(1.0, 0.75, 0.3, 0.8 * (1.0 - k)), true, -1.0, true)
		draw_circle(c, r * 0.5, Color(1.0, 0.97, 0.8, 1.0 - k), true, -1.0, true)
		if ring:
			draw_arc(Vector2.ZERO, radius * (0.6 + 2.0 * k), 0.0, TAU, 32, Color(1, 1, 1, 0.45 * (1.0 - k)), 1.5, true)
