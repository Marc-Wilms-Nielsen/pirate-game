class_name Bandit
extends Creature
## Pirat på land, der vogter en lejr. "melee" angriber med sabel, "gunner" holder afstand og skyder.
## Angriber kun kaptajnen når han er til fods på samme ø og kommer for tæt på.

const AGGRO_RANGE := 150.0
const LEASH := 320.0 ## går tilbage til lejren hvis spilleren løber langt væk

var style: String = "melee"
var camp_center := Vector2.ZERO
var _attack_timer: float = 1.0
var _target := Vector2.ZERO
var _aggro := false
var _swing: float = 0.0


func _init() -> void:
	max_hp = 32.0
	speed = 38.0
	loot_table = "bandit"
	radius = 6.0


func _ready() -> void:
	super._ready()
	_target = global_position
	if style == "gunner":
		max_hp = 24.0
		hp = max_hp


func _on_hurt(_from: Vector2) -> void:
	_aggro = true


func _behave(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_swing = maxf(_swing - delta * 4.0, 0.0)
	var player := player_character() as PlayerCharacter
	var valid := player != null and player.on_land and home and home.is_on_land(player.global_position)
	if valid:
		if player.global_position.distance_to(global_position) < AGGRO_RANGE:
			_aggro = true
		if player.global_position.distance_to(camp_center) > LEASH:
			_aggro = false
	else:
		_aggro = false

	if not _aggro:
		# Slentre rundt i lejren
		if global_position.distance_to(_target) < 3.0:
			_target = camp_center + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		move_towards_point(_target, speed * 0.4, delta)
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	facing = facing.slerp(to_player.normalized(), 1.0 - exp(-10.0 * delta))
	if style == "gunner":
		if dist < 80.0:
			move_towards_point(global_position - to_player.normalized() * 20.0, speed, delta)
			facing = to_player.normalized()
		elif dist > 150.0:
			move_towards_point(player.global_position, speed, delta)
		if dist < 200.0 and _attack_timer <= 0.0:
			_attack_timer = randf_range(1.8, 2.6)
			var b := Bullet.new()
			b.hostile = true
			b.direction = to_player.normalized().rotated(randf_range(-0.12, 0.12))
			b.damage = 8.0
			b.max_distance = 230.0
			b.global_position = global_position + b.direction * 8.0
			Game.world_root.add_child(b)
			Sfx.play_at("gunshot", global_position, -10.0)
	else:
		if dist > 12.0:
			move_towards_point(player.global_position, speed, delta)
		elif _attack_timer <= 0.0:
			_attack_timer = 1.2
			_swing = 1.0
			player.take_damage(9.0, global_position)
			Sfx.play_at("swing", global_position, -6.0)
	# Bliv på øen
	if home and home.normalized_distance(global_position) > 0.95:
		global_position = home.global_position + (global_position - home.global_position) * 0.97


func _draw_body() -> void:
	var side := facing.orthogonal()
	draw_circle(Vector2(2, 3), 6.0, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color(0.25, 0.22, 0.25), true, -1.0, true) # mørk trøje
	draw_circle(facing * 1.0, 3.4, Color(0.85, 0.68, 0.52), true, -1.0, true) # hoved
	draw_circle(facing * 0.5, 3.4, Color(0.15, 0.15, 0.15), true, -1.0, true) # sort bandana
	draw_circle(facing * 2.2, 1.6, Color(0.85, 0.68, 0.52), true, -1.0, true)
	if style == "gunner":
		draw_line(side * 3.0, side * 3.0 + facing * 10.0, Color(0.35, 0.25, 0.15), 1.6, true)
	else:
		var a := facing.angle() + (lerpf(-1.2, 1.2, 1.0 - _swing) if _swing > 0.0 else 0.9)
		draw_line(Vector2.from_angle(a) * 5.0, Vector2.from_angle(a) * 14.0, Color(0.8, 0.8, 0.85), 1.3, true)
	if _aggro:
		draw_string(ThemeDB.fallback_font, Vector2(-2, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.4, 0.3))
