class_name PlayerShip
extends CharacterBody2D
## Spillerens skib.
## W/S: sejl op/ned · A/D: ror · Mellemrum: anker · Q/E: bredside bagbord/styrbord
## F: entr et skib du ligger op ad, læg til kaj (ved en havn) eller hop i vandet (når skibet ligger stille).
## Musehjul eller + / -: zoom.
## Fart, liv, kanoner osv. kommer fra den aktive skibskonfiguration i Game + opgraderinger.

signal sail_level_changed(level: int)
signal anchor_changed(is_anchored: bool)
signal disembark_requested
signal dock_requested(harbor: Harbor)
signal boarding_requested(enemy: EnemyShip)

const SAIL_FACTORS: Array[float] = [0.0, 0.5, 1.0]
const SAIL_NAMES: Array[String] = ["Furled", "Half", "Full"]
const FOOD_INTERVAL := 40.0 ## sekunders sejlads pr. mad-enhed
const HUNGRY_SPEED := 0.75 ## fart-faktor når maden er sluppet op

@export_group("Seamanship")
@export var deceleration: float = 9.0 ## Hvor hurtigt farten falder (lav = lang glidning)
@export_range(0.0, 1.0) var min_turn_factor: float = 0.3 ## Drejeevne når skibet står stille
@export var turn_smoothing: float = 3.0
@export var anchor_brake: float = 30.0
@export var disembark_max_speed: float = 2.0
@export var dock_max_speed: float = 35.0

@export_group("Camera")
@export var zoom_slow: float = 1.3
@export var zoom_fast: float = 1.0
@export var look_ahead: float = 0.5

var sail_level: int = 0
var speed: float = 0.0
var anchored: bool = false
var controlled: bool = true
var stats: Dictionary = {}
var reload_left := {"left": 0.0, "right": 0.0}
var sinking := false

var _turn_velocity: float = 0.0
var _move_dir := Vector2.RIGHT ## retningen skibet glider i (halter efter stævnen under et ankersving)
var _creak_timer: float = 5.0
var _input_cooldown: float = 0.0
var _anchor_point := Vector2.ZERO
var _chain_length := 0.0 ## how far the chain reaches from the anchor (set when it is dropped)
var _anchor_down := false ## the anchor lies on the seabed at _anchor_point (false = not placed yet)
const ANCHOR_SIDE_OFFSET := 18.0 ## the anchor goes over the side at the bow, not straight ahead
const CHAIN_SLACK := 30.0 ## px of chain that let the ship run on freely after the drop
const CHAIN_PER_SPEED := 0.9 ## more chain runs out the faster you are going
const DRAG_TURN := 2.6 ## how quickly the chain bends your course towards the anchor
const SWING_RATE := 1.3 ## how quickly the bow turns to face the anchor
const MAX_SWING := 1.1 ## rad/s: the fastest the chain may turn the ship (smooth, no jolt)
var _food_timer: float = 0.0
var _shake: float = 0.0
var _sink_progress: float = 0.0
var _collision_type: String = ""
var _auto_zoom: float = 1.3
# Glat bevægelse: fysikken kører 60 gange i sekundet, men skærmen kan opdatere oftere.
# Vi tegner skibet og flytter kameraet mellem den forrige og den nuværende fysik-position.
var _prev_xform := Transform2D()
var _curr_xform := Transform2D()

@onready var _camera: ZoomCamera = $Camera2D
@onready var _collision: CollisionPolygon2D = $CollisionPolygon2D
var visual: ShipVisual
var _rope: Line2D
var _buoy: Polygon2D
var _wind: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _flap: AudioStreamPlayer
var _chain: AudioStreamPlayer
var _anchor_bump: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player_ship")
	add_to_group("allies")
	collision_layer = 4
	collision_mask = 1 | 4
	visual = ShipVisual.new()
	visual.top_level = true
	add_child(visual)
	WorldSky.add_ship_lights(visual, 58.0, Color(1.0, 0.75, 0.42), 1.0)
	_camera.top_level = true
	_snap_interpolation()
	_create_anchor_visuals()
	_wind = _create_player("res://assets/audio/ambience/wind_loop.wav", -30.0, true)
	_creak = _create_player("res://assets/audio/sfx/creak.wav", -12.0, false)
	_flap = _create_player("res://assets/audio/sfx/sail_flap.wav", -8.0, false)
	_chain = _create_player("res://assets/audio/sfx/anchor_chain.wav", -16.0, false)
	_anchor_bump = _create_player("res://assets/audio/sfx/anchor_drop.wav", -3.0, false)
	Game.changed.connect(refresh_from_config)
	refresh_from_config()


## Henter værdier fra den aktive skibskonfiguration (kaldes når noget købes/opgraderes).
func refresh_from_config() -> void:
	var config := Game.active_ship()
	stats = Game.ship_stats(config)
	config["hp"] = clampf(config["hp"], 0.0, stats["max_hp"])
	visual.apply_config(config)
	visual.set_deck_boxes(Game.boxes.map(func(b: Dictionary) -> String: return b["type"]))
	if _collision_type != config["type"]:
		_collision_type = config["type"]
		_collision.set_deferred("polygon", ShipVisual.collision_for(config["type"]))


func hp() -> float:
	return Game.active_ship()["hp"]


func get_sail_name() -> String:
	return SAIL_NAMES[sail_level]


func can_disembark() -> bool:
	return controlled and not sinking and speed < disembark_max_speed and Game.current_harbor == null


## Fiskestime tæt på skibet (skibet skal næsten ligge stille).
func nearby_shoal() -> FishShoal:
	if not controlled or speed > 15.0:
		return null
	for s in get_tree().get_nodes_in_group("fish_shoals"):
		if (s as FishShoal).in_range(global_position, true):
			return s
	return null


func use_repair_kit() -> void:
	var config := Game.active_ship()
	if Game.repair_kits <= 0:
		Game.notify("No repair kits – craft them in the workshop on your home island", UiTheme.BAD)
		return
	if config["hp"] >= stats["max_hp"]:
		return
	Game.repair_kits -= 1
	config["hp"] = minf(config["hp"] + stats["max_hp"] * Catalog.REPAIR_KIT_HEAL, stats["max_hp"])
	Game.popup("Repaired!", global_position + Vector2(0, -24), UiTheme.GOOD)
	Sfx.play("hit", -10.0)
	Game.changed.emit()


func can_dock() -> bool:
	return controlled and not sinking and Game.current_harbor != null and speed < dock_max_speed


func is_hungry() -> bool:
	return Game.food <= 0 and not stats.get("no_food", false)


## Et fjendeskib vi ligger op ad og kan entre (eller null).
func boardable_enemy() -> EnemyShip:
	if not controlled or sinking:
		return null
	var my_len: float = Catalog.SHIPS[Game.active_ship()["type"]]["look"]["length"]
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyShip
		if not enemy.can_be_boarded():
			continue
		var reach := (my_len + enemy.length()) * 0.42 + 6.0
		if enemy.global_position.distance_to(global_position) < reach:
			return enemy
	return null


## Kaldes når spilleren går fra eller om bord, eller åbner/lukker en havnemenu.
func set_controlled(value: bool) -> void:
	controlled = value
	_input_cooldown = 0.3
	if controlled:
		_camera.make_current()
	elif not anchored and sail_level != 0:
		sail_level = 0
		sail_level_changed.emit(sail_level)


## Flytter skibet til en kaj (bruges ved tillægning og efter et forlis).
func place_at(pos: Vector2, rot: float) -> void:
	global_position = pos
	rotation = rot
	speed = 0.0
	velocity = Vector2.ZERO
	sail_level = 0
	anchored = false
	_move_dir = Vector2.RIGHT.rotated(rot)
	_snap_interpolation()
	_camera.reset_smoothing()


func _snap_interpolation() -> void:
	_prev_xform = global_transform
	_curr_xform = global_transform
	visual.global_transform = global_transform
	_camera.global_position = global_position


func _physics_process(delta: float) -> void:
	_prev_xform = _curr_xform
	if sinking:
		_update_sinking(delta)
		_curr_xform = global_transform
		return
	_input_cooldown = maxf(_input_cooldown - delta, 0.0)
	for side in reload_left:
		reload_left[side] = maxf(reload_left[side] - delta, 0.0)

	var has_input := controlled and _input_cooldown <= 0.0
	if has_input:
		_handle_sail_input()
		_handle_anchor_input()
		if Input.is_action_just_pressed("repair"):
			use_repair_kit()
		if Input.is_action_just_pressed("fire_left"):
			fire("left")
		if Input.is_action_just_pressed("fire_right"):
			fire("right")
		if Input.is_action_just_pressed("interact"):
			var target := boardable_enemy()
			var shoal := nearby_shoal()
			if target:
				boarding_requested.emit(target)
			elif shoal:
				shoal.interact(self)
			elif can_dock():
				dock_requested.emit(Game.current_harbor)
			elif can_disembark():
				disembark_requested.emit()

	var max_speed: float = stats["speed"] * (HUNGRY_SPEED if is_hungry() else 1.0) * Game.tow_speed_factor()
	var target_speed := 0.0 if anchored else max_speed * SAIL_FACTORS[sail_level]
	var rate: float = stats["acceleration"] if speed < target_speed else deceleration
	if anchored:
		rate = anchor_brake # a smooth, steady brake from the moment the anchor bites
	speed = move_toward(speed, target_speed, rate * delta)

	# Ankersving: kaster man ankeret i fart, kan man stadig styre – og skibet svinger
	# hurtigt rundt om ankeret, mens det glider videre i den gamle retning.
	var anchor_turn := anchored and speed > 4.0
	var steer := Input.get_axis("move_left", "move_right") if has_input and (not anchored or anchor_turn) else 0.0
	var speed_ratio := clampf(speed / stats["speed"], 0.0, 1.0)
	var steer_factor := lerpf(min_turn_factor, 1.0, clampf(speed_ratio * 1.5, 0.0, 1.0))
	if anchor_turn:
		steer_factor = 1.2 + 1.8 * speed_ratio
	var target_turn: float = steer * stats["turn"] * steer_factor
	_turn_velocity = lerpf(_turn_velocity, target_turn, 1.0 - exp(-(turn_smoothing * (2.0 if anchor_turn else 1.0)) * delta))
	rotation += _turn_velocity * delta

	var heading := Vector2.RIGHT.rotated(rotation)
	_move_dir = _move_dir.slerp(heading, 1.0 - exp(-(1.2 if anchored else 6.0) * delta)).normalized()
	velocity = _move_dir * speed
	if controlled and not anchored:
		velocity += Game.wind # stormen skubber skibet
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed = move_toward(speed, 0.0, 80.0 * delta)
	if anchored:
		_anchor_chain(delta)
	else:
		_anchor_down = false # weighed: the next drop places the anchor afresh
	_curr_xform = global_transform

	_consume_food(delta)


func _consume_food(delta: float) -> void:
	if speed < 5.0 or stats.get("no_food", false):
		return
	_food_timer += delta
	# Mad bruges hurtigere jo flere der er om bord (FOOD_INTERVAL gælder for 10 mand)
	if _food_timer >= FOOD_INTERVAL * 10.0 / maxf(Game.crew, 1.0):
		_food_timer = 0.0
		if Game.food > 0:
			Game.food -= 1
			Game.changed.emit()
			if Game.food == 0:
				Game.notify("The food has run out – the crew sails slower", Color(1, 0.6, 0.5))


func fire(side: String) -> void:
	if reload_left[side] > 0.0:
		return
	var count: int = stats["cannons"]
	if Game.cannonballs <= 0:
		Game.notify("No cannonballs! Buy more in a harbor", Color(1, 0.6, 0.5))
		return
	count = mini(count, Game.cannonballs)
	Game.cannonballs -= count
	Game.changed.emit()
	reload_left[side] = stats["reload"]
	visual.broadside(side, count, func(i: int) -> void:
		# Kuglen skydes fra kanonens position lige nu – skibet kan have flyttet sig siden tasten
		var normal := (Vector2.UP if side == "left" else Vector2.DOWN).rotated(rotation)
		var positions := visual.cannon_positions(side)
		var ball := Cannonball.new()
		ball.shooter = self
		ball.damage = stats["damage"]
		ball.max_distance = stats["range"]
		var dir := normal.rotated(randf_range(-0.06, 0.06))
		ball.velocity = dir * stats["ball_speed"] * randf_range(0.95, 1.05) + velocity * 0.6
		ball.global_position = to_global(positions[i]) + normal * 6.0
		Game.world_root.add_child(ball)
		_shake = maxf(_shake, 2.5), -2.0)


func take_damage(amount: float, _from: Vector2) -> void:
	if sinking:
		return
	var config := Game.active_ship()
	var dealt: float = amount * (1.0 - stats["armor"])
	config["hp"] = maxf(config["hp"] - dealt, 0.0)
	_shake = 6.0
	Game.popup("-%d" % int(dealt), global_position + Vector2(0, -20), Color(1, 0.5, 0.45))
	# Træffere kan koste besætning (aldrig den sidste mand)
	if Game.crew > 1 and randf() < dealt / 25.0:
		Game.crew -= 1
		Game.popup("-1 man", global_position + Vector2(0, -32), Color(1, 0.6, 0.5))
	Game.changed.emit()
	if config["hp"] <= 0.0:
		_start_sinking()


func _start_sinking() -> void:
	sinking = true
	controlled = false
	_sink_progress = 0.0
	Sfx.play_at("splash", global_position)
	Fx.ship_explodes(self, float(Catalog.SHIPS[Game.active_ship()["type"]]["look"]["length"]))
	_shake = 10.0
	Game.notify("Your ship is sinking!", Color(1, 0.5, 0.45))


func _update_sinking(delta: float) -> void:
	_sink_progress = minf(_sink_progress + delta / 2.5, 1.0)
	visual.set_sinking(_sink_progress)
	if _sink_progress >= 1.0:
		sinking = false
		visual.set_sinking(0.0)
		Game.player_ship_sunk.emit()


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
		_drop_anchor_here()
	if anchored:
		# Ankeret rammer: et dumpt bump i stedet for en lang kæde
		_anchor_bump.pitch_scale = randf_range(0.92, 1.05)
		_anchor_bump.play()
	else:
		_chain.pitch_scale = 1.2
		_chain.play()
	anchor_changed.emit(anchored)


## Puts the anchor on the seabed over the side at the bow: the side you are steering towards,
## otherwise starboard. The faster you go, the more chain runs out.
func _drop_anchor_here() -> void:
	var steer := Input.get_axis("move_left", "move_right")
	var side := signf(steer) if absf(steer) > 0.1 else 1.0
	_anchor_point = to_global(Vector2(30, side * ANCHOR_SIDE_OFFSET) * stats["size"])
	_chain_length = CHAIN_SLACK + speed * CHAIN_PER_SPEED
	_anchor_down = true


## The anchor lies on the seabed off one side of the bow. While the ship brakes smoothly, the
## chain drags it towards that side: the course bends towards the anchor (more the more the
## chain is stretched), and the bow slowly turns to face it, so the ship curves in towards the
## anchor instead of drifting straight on. The chain gives like a spring if you run far past it.
func _anchor_chain(delta: float) -> void:
	if not _anchor_down:
		_drop_anchor_here() # anchored some other way than the key: the anchor lands right here
	var bow := to_global(Vector2(34, 0) * stats["size"])
	var to_anchor := _anchor_point - bow
	var d := to_anchor.length()
	if d < 1.0:
		return
	var dir := to_anchor / d
	var stretch := clampf((d - CHAIN_SLACK) / maxf(_chain_length - CHAIN_SLACK, 1.0), 0.0, 1.5)
	if speed > 2.0:
		# The course is dragged towards the anchor's side: a little at once, much more as the
		# chain stretches
		var pull := 0.35 + stretch
		_move_dir = _move_dir.slerp(dir, 1.0 - exp(-DRAG_TURN * pull * delta)).normalized()
	# The bow turns to face the anchor once the chain is stretched – eased, and never faster
	# than MAX_SWING, so even passing right over the anchor stays smooth
	if stretch > 0.0:
		var diff := angle_difference(rotation, dir.angle())
		var turn := clampf(diff * SWING_RATE * minf(stretch, 1.0), -MAX_SWING, MAX_SWING)
		rotation += turn * delta
	# Past the end of the chain it holds you back softly, like a spring – never a hard jolt
	if d > _chain_length:
		global_position += dir * (d - _chain_length) * (1.0 - exp(-4.0 * delta))


func _process(delta: float) -> void:
	var smooth := _prev_xform.interpolate_with(_curr_xform, Engine.get_physics_interpolation_fraction())
	visual.global_transform = smooth
	_camera.global_position = smooth.origin
	if not sinking:
		visual.update_motion(speed, SAIL_FACTORS[sail_level], _turn_velocity, delta)
	var speed_ratio := clampf(speed / stats["speed"], 0.0, 1.0)

	var target_zoom := lerpf(zoom_slow, zoom_fast, speed_ratio) / lerpf(1.0, stats["size"], 0.5)
	_auto_zoom = lerpf(_auto_zoom, target_zoom, 1.0 - exp(-0.8 * delta))
	_camera.base_zoom = _auto_zoom
	_shake = maxf(_shake - delta * 12.0, 0.0)
	var shake_offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_camera.offset = _camera.offset.lerp(velocity * look_ahead, 1.0 - exp(-1.5 * delta)) + shake_offset

	_update_anchor_visuals()
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
	var from := to_global(Vector2(24, 0) * stats["size"])
	var span := from.distance_to(_anchor_point)
	var slack := maxf(_chain_length - span, 0.0)
	if slack > 2.0 and span > 1.0: # loose chain: it sags to one side until it is stretched
		var side := (_anchor_point - from).orthogonal().normalized()
		_rope.points = PackedVector2Array([from, (from + _anchor_point) * 0.5 + side * minf(slack * 0.4, 18.0), _anchor_point])
	else:
		_rope.points = PackedVector2Array([from, _anchor_point])
	_buoy.global_position = _anchor_point
	_buoy.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() / 500.0) * 0.08)


func _create_anchor_visuals() -> void:
	_rope = Line2D.new()
	_rope.top_level = true
	_rope.width = 1.2
	_rope.default_color = Color(0.35, 0.25, 0.15, 0.8)
	_rope.antialiased = true
	_rope.visible = false
	add_child(_rope)
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
	player.bus = "Ambience" if loop else "SFX"
	add_child(player)
	if loop:
		player.finished.connect(player.play)
		player.play()
	return player
