extends CharacterBody2D
## Spillerens skib. W/S sætter sejl op/ned i trin, A/D drejer roret,
## Mellemrum kaster/hæver ankeret, og F hopper i vandet, når skibet ligger stille.
## Skibet har inerti: det accelererer langsomt og glider længe, når sejlet tages ned.

signal sail_level_changed(level: int)
signal anchor_changed(is_anchored: bool)
signal disembark_requested

const SAIL_FACTORS: Array[float] = [0.0, 0.5, 1.0]
const SAIL_NAMES: Array[String] = ["Nede", "Halv", "Fuld"]

@export_group("Sejlads")
@export var max_speed: float = 110.0 ## Pixels pr. sekund ved fulde sejl
@export var acceleration: float = 16.0 ## Hvor hurtigt farten stiger
@export var deceleration: float = 9.0 ## Hvor hurtigt farten falder (lav = lang glidning)
@export var turn_speed: float = 1.0 ## Radianer pr. sekund ved fuld fart
@export_range(0.0, 1.0) var min_turn_factor: float = 0.3 ## Drejeevne når skibet står stille
@export var turn_smoothing: float = 3.0 ## Hvor hurtigt roret reagerer

@export_group("Anker")
@export var anchor_brake: float = 30.0 ## Hvor hurtigt ankeret stopper skibet
@export var disembark_max_speed: float = 2.0 ## Under denne fart kan man hoppe i vandet

@export_group("Kamera")
@export var zoom_slow: float = 1.3
@export var zoom_fast: float = 1.0
@export var look_ahead: float = 0.5 ## Kameraet kigger lidt frem i sejlretningen

var sail_level: int = 0
var speed: float = 0.0
var anchored: bool = false
var controlled: bool = true

var _turn_velocity: float = 0.0
var _sail_visual: float = 0.0
var _time: float = 0.0
var _creak_timer: float = 5.0
var _input_cooldown: float = 0.0
var _anchor_point := Vector2.ZERO
var _hull_base_scale := Vector2.ONE

@onready var _hull: Sprite2D = $Hull
@onready var _sail: Sprite2D = $Hull/Sail
@onready var _shadow: Sprite2D = $Shadow
@onready var _camera: Camera2D = $Camera2D

var _wake: CPUParticles2D
var _bow_left: CPUParticles2D
var _bow_right: CPUParticles2D
var _rope: Line2D
var _buoy: Polygon2D
var _wind: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _flap: AudioStreamPlayer
var _chain: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player_ship")
	_hull_base_scale = _hull.scale

	var foam := _make_soft_dot()
	_wake = _create_foam_emitter(foam, Vector2(-27, 0), Vector2.LEFT, 25.0, 90)
	_bow_left = _create_foam_emitter(foam, Vector2(20, -8), Vector2(-0.5, -1), 15.0, 40)
	_bow_right = _create_foam_emitter(foam, Vector2(20, 8), Vector2(-0.5, 1), 15.0, 40)
	_create_anchor_visuals()

	_wind = _create_player("res://assets/audio/ambience/wind_loop.wav", -30.0, true)
	_creak = _create_player("res://assets/audio/sfx/creak.wav", -12.0, false)
	_flap = _create_player("res://assets/audio/sfx/sail_flap.wav", -8.0, false)
	_chain = _create_player("res://assets/audio/sfx/anchor_chain.wav", -6.0, false)


func get_sail_name() -> String:
	return SAIL_NAMES[sail_level]


func can_disembark() -> bool:
	return controlled and speed < disembark_max_speed


## Kaldes når spilleren går fra eller om bord.
func set_controlled(value: bool) -> void:
	controlled = value
	_input_cooldown = 0.3 # så samme tastetryk ikke straks virker igen
	if controlled:
		_camera.make_current()
	elif not anchored and sail_level != 0:
		sail_level = 0 # besætningen tager sejlet ned, når kaptajnen går fra borde
		sail_level_changed.emit(sail_level)


func _physics_process(delta: float) -> void:
	_input_cooldown = maxf(_input_cooldown - delta, 0.0)
	var has_input := controlled and _input_cooldown <= 0.0
	if has_input:
		_handle_sail_input()
		_handle_anchor_input()
		if Input.is_action_just_pressed("interact") and can_disembark():
			disembark_requested.emit()

	var target_speed := 0.0 if anchored else max_speed * SAIL_FACTORS[sail_level]
	var rate := acceleration if speed < target_speed else deceleration
	if anchored:
		rate = anchor_brake
	speed = move_toward(speed, target_speed, rate * delta)

	# Roret virker bedre jo hurtigere man sejler, men man kan altid dreje lidt.
	var steer := Input.get_axis("move_left", "move_right") if has_input and not anchored else 0.0
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


func _handle_anchor_input() -> void:
	if not Input.is_action_just_pressed("anchor"):
		return
	anchored = not anchored
	if anchored:
		_anchor_point = to_global(Vector2(34, 0)) # ankeret falder lidt foran stævnen
	_chain.pitch_scale = 1.0 if anchored else 1.15
	_chain.play()
	anchor_changed.emit(anchored)


func _process(delta: float) -> void:
	_time += delta
	var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)

	# Sejlet folder sig blødt ud og ind.
	_sail_visual = lerpf(_sail_visual, SAIL_FACTORS[sail_level], 1.0 - exp(-2.5 * delta))
	_sail.scale = Vector2(0.25 + 0.75 * _sail_visual, 0.55 + 0.45 * _sail_visual)

	# Skibet vugger i bølgerne og krænger lidt ind i sving.
	_hull.rotation = sin(_time * 1.3) * 0.025 + _turn_velocity * 0.06
	var bob := 1.0 + sin(_time * 1.7) * 0.012
	_hull.scale = _hull_base_scale * bob

	# Skyggen ligger altid i samme retning (solen står fast).
	_shadow.global_position = global_position + Vector2(3, 5)
	_shadow.global_rotation = _hull.global_rotation
	_shadow.scale = _hull.scale

	# Kameraet zoomer ud ved høj fart og kigger lidt frem.
	var target_zoom := lerpf(zoom_slow, zoom_fast, speed_ratio)
	_camera.zoom = _camera.zoom.lerp(Vector2(target_zoom, target_zoom), 1.0 - exp(-0.8 * delta))
	_camera.offset = _camera.offset.lerp(velocity * look_ahead, 1.0 - exp(-1.5 * delta))

	_wake.emitting = speed > 6.0
	_bow_left.emitting = speed > 25.0
	_bow_right.emitting = speed > 25.0

	_update_anchor_visuals()

	# Vinden bliver højere, jo hurtigere man sejler.
	_wind.volume_db = linear_to_db(lerpf(0.04, 0.45, speed_ratio))

	_creak_timer -= delta
	if _creak_timer <= 0.0:
		if speed > 10.0 or absf(_turn_velocity) > 0.2 or anchored:
			_creak.pitch_scale = randf_range(0.8, 1.15)
			_creak.volume_db = randf_range(-18.0, -10.0)
			_creak.play()
		_creak_timer = randf_range(4.0, 10.0)


func _update_anchor_visuals() -> void:
	_rope.visible = anchored
	_buoy.visible = anchored
	if not anchored:
		return
	_rope.points = PackedVector2Array([to_global(Vector2(24, 0)), _anchor_point])
	_buoy.global_position = _anchor_point
	_buoy.scale = Vector2.ONE * (1.0 + sin(_time * 2.0) * 0.08)


func _create_anchor_visuals() -> void:
	_rope = Line2D.new()
	_rope.top_level = true
	_rope.width = 1.2
	_rope.default_color = Color(0.35, 0.25, 0.15, 0.8)
	_rope.antialiased = true
	_rope.visible = false
	add_child(_rope)

	# Et lille ringe-mærke i vandet, hvor ankeret ligger.
	_buoy = Polygon2D.new()
	_buoy.top_level = true
	_buoy.z_index = -1
	_buoy.antialiased = true
	var ring := PackedVector2Array()
	for i in 24:
		ring.append(Vector2.RIGHT.rotated(TAU * i / 24.0) * 4.0)
	_buoy.polygon = ring
	_buoy.color = Color(1, 1, 1, 0.35)
	_buoy.visible = false
	add_child(_buoy)


func _create_player(path: String, volume: float, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.volume_db = volume
	add_child(player)
	if loop:
		player.finished.connect(player.play)
		player.play()
	return player


## En blød, rund prik bruges til skum i stedet for firkantede pixels.
func _make_soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _create_foam_emitter(tex: Texture2D, pos: Vector2, dir: Vector2, spread: float, count: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = tex
	particles.position = pos
	particles.z_index = -1
	particles.amount = count
	particles.lifetime = 3.0
	particles.local_coords = false
	particles.emitting = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(1, 5)
	particles.direction = dir
	particles.spread = spread
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = fade
	add_child(particles)
	return particles
