class_name EscortShip
extends CharacterBody2D
## Et af dine egne skibe, ført af en ansat kaptajn. Sejler i formation bag dig og
## angriber pirater, der angriber dig (eller skibe du selv skyder på).
## Skibets liv ligger i skibskonfigurationen (config["hp"]), så det huskes ved gem.

const FORMATION := [Vector2(-95, -75), Vector2(-95, 75), Vector2(-185, -35), Vector2(-185, 110)]
const ENGAGE_RANGE := 650.0 ## hvor langt fra eskorten den går efter fjender
const LEASH := 950.0 ## og max så langt fra dig
const TELEPORT_DIST := 1900.0 ## kommer den for langt væk (havn, forlis), sættes den i formation igen
const RESPAWN_TIME := 60.0 ## sekunder før et sænket eskorteskib er tilbage (repareret)

var config: Dictionary = {}
var slot: int = 0
var stats: Dictionary = {}
var speed: float = 0.0
var state: String = "follow" ## follow, fight, sunk
var target: EnemyShip = null
var loot_target: Node2D = null ## vraggods kaptajnen sejler hen og samler op
var _turn_velocity: float = 0.0
var _reload := {"left": 1.0, "right": 1.0}
var _think: float = 0.0
var _sink_progress: float = 0.0
var _sunk_timer: float = 0.0
var _visual: ShipVisual
var _bar: EscortBar
var _prev_xform := Transform2D()
var _curr_xform := Transform2D()
var _collision: CollisionPolygon2D


func _ready() -> void:
	add_to_group("escorts")
	add_to_group("allies")
	collision_layer = 4
	collision_mask = 1 # kun land – den skubber ikke til dit skib
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	refresh()
	_collision = CollisionPolygon2D.new()
	_collision.polygon = ShipVisual.collision_for(config["type"])
	add_child(_collision)
	_visual = ShipVisual.new()
	_visual.top_level = true
	add_child(_visual)
	WorldSky.add_ship_lights(_visual, float(Catalog.SHIPS[config["type"]]["look"]["length"]), Color(1.0, 0.75, 0.45), 0.8)
	_visual.apply_config(config)
	_bar = EscortBar.new()
	_bar.owner_ship = self
	add_child(_bar)
	_snap()


func refresh() -> void:
	stats = Game.escort_stats(config)
	config["hp"] = clampf(float(config["hp"]), 0.0, stats["max_hp"])
	if _visual:
		_visual.apply_config(config)


func captain() -> Dictionary:
	return Game.captain_by_id(int(config.get("captain", 0)))


func hp() -> float:
	return float(config["hp"])


func _snap() -> void:
	_prev_xform = global_transform
	_curr_xform = global_transform
	if _visual:
		_visual.global_transform = global_transform


func place_at(pos: Vector2, rot: float) -> void:
	global_position = pos
	rotation = rot
	speed = 0.0
	_snap()


func formation_point(player: Node2D) -> Vector2:
	var size_factor: float = clampf(float(Game.ship_stats(Game.active_ship())["size"]), 0.8, 2.0)
	return player.global_position + (FORMATION[slot % FORMATION.size()] as Vector2).rotated(player.rotation) * size_factor


func _physics_process(delta: float) -> void:
	_prev_xform = _curr_xform
	var player := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	if player == null:
		return
	if state == "sunk":
		_update_sunk(delta, player)
		_curr_xform = global_transform
		return
	for side in _reload:
		_reload[side] = maxf(_reload[side] - delta, 0.0)
	_think -= delta
	if _think <= 0.0:
		_think = 0.5
		_choose_target(player)
	if global_position.distance_to(player.global_position) > TELEPORT_DIST:
		_teleport_to_formation(player)

	var desired_dir := Vector2.from_angle(rotation)
	var target_speed := 0.0
	if state == "fight" and is_instance_valid(target):
		var r := _fight_direction(target)
		desired_dir = r[0]
		target_speed = r[1]
		_try_fire(target)
	elif is_instance_valid(loot_target):
		desired_dir = (loot_target.global_position - global_position).normalized()
		target_speed = float(stats["speed"]) * 0.85
	else:
		var spot := formation_point(player)
		var to_spot := spot - global_position
		var dist := to_spot.length()
		if dist > 30.0:
			desired_dir = to_spot.normalized()
			target_speed = minf(stats["speed"] * 1.15, player.speed + dist * 0.7)
		else:
			desired_dir = Vector2.from_angle(player.rotation)
			target_speed = player.speed
		# Langsom heling når der ikke er kamp
		config["hp"] = minf(float(config["hp"]) + stats["max_hp"] * 0.004 * delta, stats["max_hp"])

	desired_dir = _avoid_land(desired_dir)
	var angle_diff := angle_difference(rotation, desired_dir.angle())
	var target_turn: float = clampf(angle_diff * 2.0, -1.0, 1.0) * stats["turn"] * 1.1
	_turn_velocity = lerpf(_turn_velocity, target_turn, 1.0 - exp(-3.0 * delta))
	rotation += _turn_velocity * delta
	var rate: float = stats["acceleration"] * (1.0 if speed < target_speed else 1.6)
	speed = move_toward(speed, target_speed, rate * delta)
	velocity = Vector2.from_angle(rotation) * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed = move_toward(speed, 0.0, 80.0 * delta)
	_curr_xform = global_transform


func _process(delta: float) -> void:
	_visual.global_transform = _prev_xform.interpolate_with(_curr_xform, Engine.get_physics_interpolation_fraction())
	if state != "sunk":
		_visual.update_motion(speed, clampf(speed / maxf(float(stats["speed"]), 1.0), 0.0, 1.0), _turn_velocity, delta)


## Fjender eskorten må angribe: pirater der angriber dig, og skibe du selv er i kamp med.
func _choose_target(player: PlayerShip) -> void:
	var best: EnemyShip = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyShip
		if enemy.plundered:
			continue
		var hostile: bool = (enemy.faction == "pirate" and enemy.state == "attack") or float(enemy.get("_provoked")) > 0.0
		if not hostile:
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d < ENGAGE_RANGE and enemy.global_position.distance_to(player.global_position) < LEASH and d < best_d:
			best = enemy
			best_d = d
	target = best
	state = "fight" if best else "follow"
	# Ingen kamp? Så samler kaptajnen vraggods op i nærheden
	loot_target = null
	if state == "follow":
		var best_loot := INF
		for l in get_tree().get_nodes_in_group("floating_loot"):
			var loot := l as Node2D
			var d := loot.global_position.distance_to(global_position)
			if d < 380.0 and d < best_loot and loot.global_position.distance_to(player.global_position) < LEASH:
				best_loot = d
				loot_target = loot


## Læg sig på bredsiden af målet – samme taktik som piraterne bruger.
func _fight_direction(enemy: Node2D) -> Array:
	var to := enemy.global_position - global_position
	var dist := to.length()
	var ideal: float = stats["range"] * 0.65
	if dist > ideal * 1.3:
		return [to.normalized(), float(stats["speed"])]
	var tangent := to.orthogonal().normalized()
	if tangent.dot(Vector2.from_angle(rotation)) < 0.0:
		tangent = -tangent
	var correction := to.normalized() * clampf((dist - ideal) / ideal, -0.6, 0.6)
	return [(tangent + correction).normalized(), float(stats["speed"]) * 0.55]


func _try_fire(enemy: Node2D) -> void:
	var to := enemy.global_position - global_position
	if to.length() > stats["range"] * 0.95:
		return
	for side in ["left", "right"]:
		if _reload[side] > 0.0:
			continue
		var normal := (Vector2.UP if side == "left" else Vector2.DOWN).rotated(rotation)
		if normal.dot(to.normalized()) > 0.9:
			_fire(side, normal)


func _fire(side: String, _normal: Vector2) -> void:
	_reload[side] = stats["reload"] * 1.2
	var count := _visual.cannon_positions(side).size()
	_visual.broadside(side, count, func(i: int) -> void:
		if state == "sunk":
			return
		var normal := (Vector2.UP if side == "left" else Vector2.DOWN).rotated(rotation)
		var ball := Cannonball.new()
		ball.shooter = self
		ball.damage = stats["damage"] * 0.9
		ball.max_distance = stats["range"]
		ball.velocity = normal.rotated(randf_range(-0.07, 0.07)) * stats["ball_speed"] * randf_range(0.95, 1.05) + velocity * 0.6
		ball.global_position = to_global(_visual.cannon_positions(side)[i]) + normal * 6.0
		Game.world_root.add_child(ball), -7.0)


func take_damage(amount: float, _from: Vector2) -> void:
	if state == "sunk":
		return
	var dmg := amount * (1.0 - float(stats["armor"]))
	config["hp"] = float(config["hp"]) - dmg
	_bar.show_for(4.0)
	Game.popup("-%d" % int(dmg), global_position + Vector2(0, -22), Color(1, 0.85, 0.5))
	if float(config["hp"]) <= 0.0:
		_sink()


func _sink() -> void:
	state = "sunk"
	config["hp"] = 0.0
	_sink_progress = 0.0
	_sunk_timer = RESPAWN_TIME
	collision_layer = 0
	remove_from_group("allies")
	Sfx.play_at("splash", global_position)
	Fx.ship_explodes(self, float(Catalog.SHIPS[config["type"]]["look"]["length"]))
	var c := captain()
	Game.notify("%s was sunk! %s and the crew were rescued – the ship is back in %d sec." % [
		config["name"], c.get("name", "The captain"), int(RESPAWN_TIME)], UiTheme.BAD)


func _update_sunk(delta: float, player: PlayerShip) -> void:
	_sink_progress = minf(_sink_progress + delta / 2.5, 1.0)
	_visual.set_sinking(_sink_progress)
	_visual.visible = _sink_progress < 1.0
	_sunk_timer -= delta
	if _sunk_timer <= 0.0:
		state = "follow"
		config["hp"] = stats["max_hp"] * 0.4
		collision_layer = 4
		add_to_group("allies")
		_visual.set_sinking(0.0)
		_visual.visible = true
		_teleport_to_formation(player)
		Game.notify("%s is repaired and sailing with you again" % config["name"], UiTheme.GOOD)


func _teleport_to_formation(player: Node2D) -> void:
	var spot := formation_point(player)
	if Game.is_land(spot) or Game.water_depth(spot) < 0.05:
		spot = player.global_position - Vector2.from_angle(player.rotation) * 140.0
	place_at(spot, player.rotation)


## Kig fremad – er der land, så drej væk (samme som fjendeskibene).
func _avoid_land(dir: Vector2) -> Vector2:
	var look: Vector2 = global_position + Vector2.from_angle(rotation) * (90.0 * stats["size"])
	if Game.is_land(look) or Game.water_depth(look) < 0.03:
		for angle in [0.8, -0.8, 1.6, -1.6, 2.6]:
			var test := Vector2.from_angle(rotation + angle)
			if not Game.is_land(global_position + test * 120.0):
				return test
	return dir


## Navn på kaptajnen og livsbjælke over eskorteskibet.
class EscortBar extends Node2D:
	var owner_ship: EscortShip
	var _visible_time: float = 0.0

	func _ready() -> void:
		top_level = true
		z_index = 20

	func show_for(seconds: float) -> void:
		_visible_time = seconds

	func _process(delta: float) -> void:
		_visible_time = maxf(_visible_time - delta, 0.0)
		var ship_len: float = Catalog.SHIPS[owner_ship.config["type"]]["look"]["length"]
		global_position = owner_ship.global_position + Vector2(0, -12.0 - ship_len * 0.3)
		queue_redraw()

	func _draw() -> void:
		if owner_ship.state == "sunk":
			return
		var player := get_tree().get_first_node_in_group("player_ship") as Node2D
		var near := player != null and player.global_position.distance_to(global_position) < 450.0
		if not near and _visible_time <= 0.0:
			return
		var ratio := clampf(owner_ship.hp() / float(owner_ship.stats["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(-18, 0, 36, 3.5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-18, 0, 36 * ratio, 3.5), Color(0.45, 0.85, 0.5))
		if near:
			var font := ThemeDB.fallback_font
			var text: String = "%s · %d men" % [owner_ship.captain().get("name", ""), int(owner_ship.config.get("crew", 0))]
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string_outline(font, Vector2(-w * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(-w * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 1.0, 0.75))
