extends CharacterBody2D
## Spillerens skib. W/S sætter sejl op/ned i trin, A/D drejer roret.
## Skibet har inerti: det accelererer langsomt og glider længe, når sejlet tages ned.

signal sail_level_changed(level: int)

const SAIL_FACTORS: Array[float] = [0.0, 0.5, 1.0]
const SAIL_NAMES: Array[String] = ["Nede", "Halv", "Fuld"]

@export_group("Sejlads")
@export var max_speed: float = 110.0 ## Pixels pr. sekund ved fulde sejl
@export var acceleration: float = 16.0 ## Hvor hurtigt farten stiger
@export var deceleration: float = 9.0 ## Hvor hurtigt farten falder (lav = lang glidning)
@export var turn_speed: float = 1.0 ## Radianer pr. sekund ved fuld fart
@export_range(0.0, 1.0) var min_turn_factor: float = 0.3 ## Drejeevne når skibet står stille
@export var turn_smoothing: float = 3.0 ## Hvor hurtigt roret reagerer

@export_group("Kamera")
@export var zoom_slow: float = 1.3
@export var zoom_fast: float = 1.0
@export var look_ahead: float = 0.5 ## Kameraet kigger lidt frem i sejlretningen

var sail_level: int = 0
var speed: float = 0.0

var _turn_velocity: float = 0.0
var _sail_visual: float = 0.0
var _time: float = 0.0
var _creak_timer: float = 5.0

@onready var _hull: Sprite2D = $Hull
@onready var _sail: Sprite2D = $Hull/Sail
@onready var _shadow: Sprite2D = $Shadow
@onready var _camera: Camera2D = $Camera2D

var _wake: CPUParticles2D
var _wind: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _flap: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player_ship")
	_wake = _create_wake()
	add_child(_wake)
	_wind = _create_player("res://assets/audio/ambience/wind_loop.wav", -30.0, true)
	_creak = _create_player("res://assets/audio/sfx/creak.wav", -12.0, false)
	_flap = _create_player("res://assets/audio/sfx/sail_flap.wav", -8.0, false)


func get_sail_name() -> String:
	return SAIL_NAMES[sail_level]


func _physics_process(delta: float) -> void:
	_handle_sail_input()

	var target_speed := max_speed * SAIL_FACTORS[sail_level]
	var rate := acceleration if speed < target_speed else deceleration
	speed = move_toward(speed, target_speed, rate * delta)

	# Roret virker bedre jo hurtigere man sejler, men man kan altid dreje lidt.
	var steer := Input.get_axis("move_left", "move_right")
	var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)
	var steer_factor := lerpf(min_turn_factor, 1.0, clampf(speed_ratio * 1.5, 0.0, 1.0))
	var target_turn := steer * turn_speed * steer_factor
	_turn_velocity = lerpf(_turn_velocity, target_turn, 1.0 - exp(-turn_smoothing * delta))
	rotation += _turn_velocity * delta

	velocity = Vector2.RIGHT.rotated(rotation) * speed
	move_and_slide()

	# Blød grundstødning: farten forsvinder roligt i stedet for et hårdt stop.
	if get_slide_collision_count() > 0:
		speed = move_toward(speed, 0.0, 80.0 * delta)


func _handle_sail_input() -> void:
	var new_level := sail_level
	if Input.is_action_just_pressed("move_up"):
		new_level = mini(sail_level + 1, SAIL_FACTORS.size() - 1)
	elif Input.is_action_just_pressed("move_down"):
		new_level = maxi(sail_level - 1, 0)

	if new_level != sail_level:
		sail_level = new_level
		sail_level_changed.emit(sail_level)
		_flap.pitch_scale = randf_range(0.9, 1.1)
		_flap.play()


func _process(delta: float) -> void:
	_time += delta
	var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)

	# Sejlet folder sig blødt ud og ind.
	_sail_visual = lerpf(_sail_visual, SAIL_FACTORS[sail_level], 1.0 - exp(-2.5 * delta))
	_sail.scale = Vector2(0.25 + 0.75 * _sail_visual, 0.55 + 0.45 * _sail_visual)

	# Skibet vugger i bølgerne og krænger lidt ind i sving.
	_hull.rotation = sin(_time * 1.3) * 0.025 + _turn_velocity * 0.06
	var bob := 1.0 + sin(_time * 1.7) * 0.012
	_hull.scale = Vector2(bob, bob)

	# Skyggen ligger altid i samme retning (solen står fast).
	_shadow.global_position = global_position + Vector2(3, 5)
	_shadow.global_rotation = _hull.global_rotation
	_shadow.scale = _hull.scale

	# Kameraet zoomer ud ved høj fart og kigger lidt frem.
	var target_zoom := lerpf(zoom_slow, zoom_fast, speed_ratio)
	_camera.zoom = _camera.zoom.lerp(Vector2(target_zoom, target_zoom), 1.0 - exp(-0.8 * delta))
	_camera.offset = _camera.offset.lerp(velocity * look_ahead, 1.0 - exp(-1.5 * delta))

	_wake.emitting = speed > 6.0

	# Vinden bliver højere, jo hurtigere man sejler.
	_wind.volume_db = linear_to_db(lerpf(0.04, 0.45, speed_ratio))

	_creak_timer -= delta
	if _creak_timer <= 0.0:
		if speed > 10.0 or absf(_turn_velocity) > 0.2:
			_creak.pitch_scale = randf_range(0.8, 1.15)
			_creak.volume_db = randf_range(-18.0, -10.0)
			_creak.play()
		_creak_timer = randf_range(4.0, 10.0)


func _create_player(path: String, volume: float, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.volume_db = volume
	add_child(player)
	if loop:
		player.finished.connect(player.play)
		player.play()
	return player


func _create_wake() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = Vector2(-27, 0)
	particles.z_index = -1
	particles.amount = 80
	particles.lifetime = 3.0
	particles.local_coords = false
	particles.emitting = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(1, 6)
	particles.direction = Vector2.LEFT
	particles.spread = 25.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.7))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = gradient
	return particles
