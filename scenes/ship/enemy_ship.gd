class_name EnemyShip
extends CharacterBody2D
## Computerstyret skib.
## "merchant": handelsskib – fredeligt, flygter når det bliver angrebet. Giver tyvegods.
## "pirate": sørøver – angriber spilleren, når han kommer tæt på.

const AGGRO_RANGE := 520.0
const GIVE_UP_RANGE := 1100.0

var faction: String = "merchant"
var ship_name: String = "" ## tilfældigt navn, vises når man er tæt på
var config: Dictionary = {}
var stats: Dictionary = {}
var hp: float = 100.0
var speed: float = 0.0
var state: String = "wander" ## wander, attack, flee
var crew: int = 8
var plundered := false ## overgivet efter en entring – kan ikke entres igen
var _provoked: float = 0.0 ## skudt på: slår igen, også i strandvandet
var _board_cooldown: float = 8.0 ## pirater venter lidt før de forsøger at entre
const CREW_LOSS_PER_DAMAGE := 1.0 / 12.0 ## kanonskud dræber også besætning

var _target := Vector2.ZERO
var _sail: float = 0.5
var _turn_velocity: float = 0.0
var _reload := {"left": 1.5, "right": 1.5}
var _think: float = 0.0
var _sinking := false
var _sink_progress: float = 0.0
var _visual: ShipVisual
var _bar: HealthBar
var _prev_xform := Transform2D()
var _curr_xform := Transform2D()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if config.is_empty():
		setup("merchant", "")
	stats = Game.ship_stats(config)
	hp = stats["max_hp"]
	var collision := CollisionPolygon2D.new()
	collision.polygon = ShipVisual.collision_for(config["type"])
	add_child(collision)
	_visual = ShipVisual.new()
	_visual.top_level = true
	add_child(_visual)
	WorldSky.add_ship_lights(_visual, length(), Color(1.0, 0.7, 0.4) if faction == "merchant" else Color(1.0, 0.45, 0.3), 0.8)
	_prev_xform = global_transform
	_curr_xform = global_transform
	_visual.global_transform = global_transform
	_visual.apply_config(config)
	_bar = HealthBar.new()
	_bar.owner_ship = self
	add_child(_bar)
	_pick_wander_target()


## Vælg fraktion og skibstype før skibet tilføjes til verden. Tom type = tilfældig passende type.
func setup(new_faction: String, type: String) -> void:
	faction = new_faction
	ship_name = Catalog.random_ship_name(faction)
	if type == "":
		type = (Catalog.PIRATE_SHIPS if faction == "pirate" else Catalog.MERCHANT_SHIPS).pick_random()
	config = Game.new_ship_config(type)
	var max_crew: int = Catalog.SHIPS[type]["crew"]
	crew = maxi(2, int(max_crew * (randf_range(0.6, 0.95) if faction == "pirate" else randf_range(0.35, 0.65))))
	if faction == "pirate":
		config["sail"] = "black"
		config["hull"] = "dark"
		config["decorations"] = {"flag": true}
		config["cannons"] = maxi(1, int(Catalog.SHIPS[type]["max_cannons"] * 0.6))
		config["upgrades"]["cannon_power"] = 0
	else:
		config["sail"] = ["canvas", "sun", "ocean"].pick_random()
		config["cannons"] = 1
		config["decorations"] = {"lanterns": true}


func _physics_process(delta: float) -> void:
	_prev_xform = _curr_xform
	_curr_xform = global_transform
	if _sinking:
		_sink_progress = minf(_sink_progress + delta / 2.5, 1.0)
		_visual.set_sinking(_sink_progress)
		if _sink_progress >= 1.0:
			queue_free()
		return

	for side in _reload:
		_reload[side] = maxf(_reload[side] - delta, 0.0)
	_board_cooldown = maxf(_board_cooldown - delta, 0.0)
	_provoked = maxf(_provoked - delta, 0.0)
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		_update_state()

	var player := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var desired_dir := Vector2.from_angle(rotation)
	match state:
		"wander":
			_sail = 0.5
			desired_dir = (_target - global_position).normalized()
			if global_position.distance_to(_target) < 80.0:
				_pick_wander_target()
		"flee":
			_sail = 1.0
			if player:
				desired_dir = (global_position - player.global_position).normalized()
		"attack":
			if player:
				desired_dir = _attack_direction(player)
				if _provoked > 0.0 or not Game.is_safe_water(player.global_position):
					_try_fire(player)
					_try_board(player)

	desired_dir = _avoid_land(desired_dir)
	var angle_diff := angle_difference(rotation, desired_dir.angle())
	var target_turn: float = clampf(angle_diff * 2.0, -1.0, 1.0) * stats["turn"]
	_turn_velocity = lerpf(_turn_velocity, target_turn, 1.0 - exp(-3.0 * delta))
	rotation += _turn_velocity * delta

	var target_speed: float = stats["speed"] * _sail * 0.85
	speed = move_toward(speed, target_speed, stats["acceleration"] * delta)
	velocity = Vector2.from_angle(rotation) * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed = move_toward(speed, 0.0, 80.0 * delta)
		_pick_wander_target()
	_curr_xform = global_transform


func _process(delta: float) -> void:
	_visual.global_transform = _prev_xform.interpolate_with(_curr_xform, Engine.get_physics_interpolation_fraction())
	if not _sinking:
		_visual.update_motion(speed, _sail, _turn_velocity, delta)


func _update_state() -> void:
	if plundered:
		state = "flee"
		return
	var player := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	if player == null or player.sinking:
		state = "wander"
		return
	var dist := global_position.distance_to(player.global_position)
	if faction == "pirate":
		if _provoked <= 0.0 and Game.is_safe_water(player.global_position):
			state = "wander" # ingen angriber i det fredelige strandvand
		elif hp < stats["max_hp"] * 0.25:
			state = "flee"
		elif dist < AGGRO_RANGE or (state == "attack" and dist < GIVE_UP_RANGE):
			state = "attack"
		else:
			state = "wander"
	else:
		if state == "flee" and dist > GIVE_UP_RANGE:
			state = "wander"


## Pirater forsøger at lægge sig parallelt med spilleren, så bredsiden peger mod ham.
func _attack_direction(player: Node2D) -> Vector2:
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var ideal: float = stats["range"] * 0.7
	if dist > ideal * 1.3:
		_sail = 1.0
		return to_player.normalized()
	_sail = 0.5
	var tangent := to_player.orthogonal().normalized()
	if tangent.dot(Vector2.from_angle(rotation)) < 0.0:
		tangent = -tangent
	var correction := to_player.normalized() * clampf((dist - ideal) / ideal, -0.6, 0.6)
	return (tangent + correction).normalized()


## Pirater med flere folk end spilleren prøver at lægge sig op ad og entre.
func _try_board(player: PlayerShip) -> void:
	if _board_cooldown > 0.0 or crew <= Game.crew * 0.8 or not player.controlled:
		return
	var player_len: float = Catalog.SHIPS[Game.active_ship()["type"]]["look"]["length"]
	if global_position.distance_to(player.global_position) < (player_len + length()) * 0.45 + 8.0:
		_board_cooldown = 25.0
		Game.pirate_boarding.emit(self)


func _try_fire(player: Node2D) -> void:
	var to_player := player.global_position - global_position
	if to_player.length() > stats["range"] * 0.95:
		return
	for side in ["left", "right"]:
		if _reload[side] > 0.0:
			continue
		var normal := (Vector2.UP if side == "left" else Vector2.DOWN).rotated(rotation)
		if normal.dot(to_player.normalized()) > 0.92:
			_fire(side, normal)


func _fire(side: String, _normal: Vector2) -> void:
	_reload[side] = stats["reload"] * 1.3
	var count := _visual.cannon_positions(side).size()
	_visual.broadside(side, count, func(i: int) -> void:
		if _sinking:
			return
		var normal := (Vector2.UP if side == "left" else Vector2.DOWN).rotated(rotation)
		var ball := Cannonball.new()
		ball.shooter = self
		ball.damage = stats["damage"] * 0.8
		ball.max_distance = stats["range"]
		ball.velocity = normal.rotated(randf_range(-0.08, 0.08)) * stats["ball_speed"] * randf_range(0.95, 1.05) + velocity * 0.6
		ball.global_position = to_global(_visual.cannon_positions(side)[i]) + normal * 6.0
		Game.world_root.add_child(ball), -6.0)


## Kig fremad – er der land, så drej væk.
func _avoid_land(dir: Vector2) -> Vector2:
	var look: Vector2 = global_position + Vector2.from_angle(rotation) * (110.0 * stats["size"])
	if Game.is_land(look) or Game.water_depth(look) < 0.05:
		for angle in [0.8, -0.8, 1.6, -1.6, 2.6]:
			var test := Vector2.from_angle(rotation + angle)
			if not Game.is_land(global_position + test * 140.0):
				return test
	return dir


func _pick_wander_target() -> void:
	for i in 10:
		var candidate := global_position + Vector2.from_angle(randf() * TAU) * randf_range(500.0, 1200.0)
		if Game.water_depth(candidate) > 0.5:
			_target = candidate
			return
	_target = global_position - Vector2.from_angle(rotation) * 400.0


func length() -> float:
	return float(Catalog.SHIPS[config["type"]]["look"]["length"])


func can_be_boarded() -> bool:
	return not _sinking and not plundered


func type_name() -> String:
	return Catalog.SHIPS[config["type"]]["name"]


## Efter en tabt entring: stryger flaget og sejler væk.
func surrender() -> void:
	plundered = true
	faction = "merchant"
	state = "flee"
	config["decorations"] = {}
	_visual.apply_config(config)
	remove_from_group("enemies")
	add_to_group("surrendered")


func take_damage(amount: float, _from: Vector2) -> void:
	if _sinking:
		return
	hp -= amount
	_provoked = 20.0
	_bar.show_for(4.0)
	Game.popup("-%d" % int(amount), global_position + Vector2(0, -22), Color(1, 0.85, 0.5))
	# Kanonskud koster også liv om bord
	var loss_f := amount * CREW_LOSS_PER_DAMAGE
	var lost := int(loss_f) + (1 if randf() < fmod(loss_f, 1.0) else 0)
	lost = mini(lost, crew - 1)
	if lost > 0:
		crew -= lost
		Game.popup("-%d men" % lost, global_position + Vector2(0, -34), Color(1, 0.6, 0.5))
	if faction == "merchant":
		state = "flee"
	elif state == "wander":
		state = "attack"
	if hp <= 0.0:
		_sink()


func _sink() -> void:
	_sinking = true
	remove_from_group("enemies")
	collision_layer = 0
	Sfx.play_at("splash", global_position)
	Fx.ship_explodes(self, length())
	var name_text := "Merchant ship" if faction == "merchant" else "Pirate ship"
	Game.notify("%s sunk!" % name_text, Color(0.7, 1, 0.7))
	# Vraggods flyder op
	var count := randi_range(2, 4)
	for i in count:
		var loot := FloatingLoot.new()
		loot.loot_table = "merchant_wreck" if faction == "merchant" else "pirate_wreck"
		loot.lifetime = 120.0
		loot.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		Game.world_root.add_child.call_deferred(loot)


## Livsbjælke over skibet (vises kun når det er ramt).
class HealthBar extends Node2D:
	var owner_ship: EnemyShip
	var _visible_time: float = 0.0

	func _ready() -> void:
		top_level = true
		z_index = 20

	func show_for(seconds: float) -> void:
		_visible_time = seconds

	func _process(delta: float) -> void:
		_visible_time = maxf(_visible_time - delta, 0.0)
		global_position = owner_ship.global_position + Vector2(0, -12.0 - owner_ship.length() * 0.3)
		queue_redraw()

	func _draw() -> void:
		var near := false
		var player := get_tree().get_first_node_in_group("player_ship") as Node2D
		if player and player.global_position.distance_to(global_position) < 450.0:
			near = true
		if _visible_time <= 0.0 and not near:
			return
		var ratio := clampf(owner_ship.hp / owner_ship.stats["max_hp"], 0.0, 1.0)
		var col := Color(0.9, 0.3, 0.25) if owner_ship.faction == "pirate" else Color(0.95, 0.85, 0.4)
		draw_rect(Rect2(-18, 0, 36, 3.5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-18, 0, 36 * ratio, 3.5), col)
		if near:
			# Besætningen vises, når man er tæt på – vigtigt før en entring
			var font := ThemeDB.fallback_font
			var text := "%d men" % owner_ship.crew
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string_outline(font, Vector2(-w * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(-w * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col.lightened(0.3))
			var title := owner_ship.ship_name
			var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string_outline(font, Vector2(-tw * 0.5, -13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(-tw * 0.5, -13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.95, 0.85))
