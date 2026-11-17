extends CharacterBody2D
## Kaptajnen til fods. Går på øerne og svømmer i vandet (langsommere og mere "flydende").
## F tæt på skibet = gå om bord. Tegnes med kode som en placeholder-figur.

signal board_requested

@export var walk_speed: float = 60.0
@export var swim_speed: float = 28.0
@export var walk_responsiveness: float = 10.0 ## Høj = stopper og starter hurtigt
@export var swim_responsiveness: float = 2.5 ## Lav = glider i vandet
@export var board_distance: float = 40.0

var on_land: bool = false

var _facing := Vector2.RIGHT
var _time: float = 0.0
var _input_cooldown: float = 0.3
var _splash: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player_character")
	_splash = AudioStreamPlayer.new()
	_splash.stream = load("res://assets/audio/sfx/splash.wav") as AudioStream
	_splash.volume_db = -6.0
	add_child(_splash)
	on_land = _check_land()
	if not on_land:
		_splash.play() # plask, når man hopper i vandet


func _physics_process(delta: float) -> void:
	_input_cooldown = maxf(_input_cooldown - delta, 0.0)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed := walk_speed if on_land else swim_speed
	var responsiveness := walk_responsiveness if on_land else swim_responsiveness
	velocity = velocity.lerp(dir * target_speed, 1.0 - exp(-responsiveness * delta))
	move_and_slide()

	if dir.length() > 0.1:
		_facing = _facing.slerp(dir.normalized(), 1.0 - exp(-12.0 * delta))

	var now_on_land := _check_land()
	if now_on_land != on_land:
		on_land = now_on_land
		_splash.volume_db = -14.0
		_splash.pitch_scale = randf_range(1.1, 1.3)
		_splash.play()

	if _input_cooldown <= 0.0 and Input.is_action_just_pressed("interact") and can_board():
		board_requested.emit()


func can_board() -> bool:
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	return ship != null and global_position.distance_to(ship.global_position) < board_distance


func _check_land() -> bool:
	for island in get_tree().get_nodes_in_group("islands"):
		if island.has_method("is_on_land") and island.call("is_on_land", global_position):
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var moving := clampf(velocity.length() / walk_speed, 0.0, 1.0)
	var angle := _facing.angle()

	if on_land:
		var step := sin(_time * 14.0) * moving
		draw_circle(Vector2(2, 3), 6.0, Color(0, 0, 0, 0.2), true, -1.0, true) # skygge
		# Fødder, der skiftes til at træde frem
		var side := _facing.orthogonal() * 2.5
		draw_circle(side + _facing * step * 2.5, 1.8, Color(0.25, 0.18, 0.12), true, -1.0, true)
		draw_circle(-side - _facing * step * 2.5, 1.8, Color(0.25, 0.18, 0.12), true, -1.0, true)
		draw_circle(Vector2.ZERO, 5.0, Color(0.72, 0.20, 0.20), true, -1.0, true) # skjorte
		_draw_head(_facing * 1.0, angle, 1.0)
	else:
		# Ringe i vandet omkring svømmeren
		for i in 3:
			var r := fmod(_time * 6.0 + i * 5.0, 15.0) + 4.0
			var alpha := 0.35 * (1.0 - (r - 4.0) / 15.0)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 1, 1, alpha), 1.0, true)
		draw_circle(Vector2.ZERO, 6.0, Color(0.05, 0.25, 0.40, 0.35), true, -1.0, true) # krop under vand
		var bob := sin(_time * 3.0) * 0.4
		_draw_head(Vector2(0, bob), angle, 0.9)


func _draw_head(pos: Vector2, angle: float, size: float) -> void:
	draw_circle(pos, 3.5 * size, Color(0.95, 0.78, 0.60), true, -1.0, true)
	# Trekantet pirathat, der peger i gå-retningen
	var hat := PackedVector2Array([Vector2(5, 0), Vector2(-3, -4.5), Vector2(-3, 4.5)])
	var transformed := PackedVector2Array()
	for p in hat:
		transformed.append(pos + (p * size).rotated(angle))
	draw_colored_polygon(transformed, Color(0.15, 0.12, 0.10))
