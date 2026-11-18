class_name FastTravel
extends Node2D
## Fast travel to a harbor you have docked at before (pick it on the map, see MapView).
## Costs a little gold by distance. The transition: your ship, your captains' ships and the
## ships in tow sink below the surface in a swirl of bubbles, the screen fades to deep blue,
## and you all rise up through the water next to the destination's pier.

const SINK_TIME := 1.4
const FADE_TIME := 0.35
const RISE_TIME := 1.4
const ARRIVAL_MIN := 250.0 ## px out from the pier where you surface (see arrival_spot)
const ARRIVAL_MAX := 1400.0
const PIRATE_RANGE := 700.0 ## no fast travel with an attacking pirate this close

var busy := false
var _bubbles: Array[Vector4] = [] ## x, y, age, size (world space)
var _fade: ColorRect


func _ready() -> void:
	add_to_group("fast_travel")
	z_index = 30
	z_as_relative = false
	var layer := CanvasLayer.new()
	layer.layer = 15 # over the world and the HUD, under menus
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.08, 0.16, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Gold for a trip: a small base price plus a little per distance (rounded to 5).
static func cost(from: Vector2, to: Vector2) -> int:
	return int(snappedf(20.0 + from.distance_to(to) * 0.008, 5.0))


## Why you can't travel there right now ("" = you can).
func blocked_reason(harbor: Harbor) -> String:
	var s := _player_ship()
	if s == null or busy:
		return "Already travelling"
	if not Game.visited_harbors.has(harbor.harbor_name):
		return "Not visited yet – dock there once first"
	if harbor.kind == "home" and not Homestead.claimed:
		return "Buy the island first"
	if s.global_position.distance_to(harbor.dock_position()) < 300.0:
		return "You are already here"
	if get_tree().get_first_node_in_group("player_character") != null:
		return "Your captain is ashore – return to the ship"
	if s.sinking:
		return "Your ship is sinking!"
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as EnemyShip
		if e.faction == "pirate" and e.state == "attack" and e.global_position.distance_to(s.global_position) < PIRATE_RANGE:
			return "Pirates are attacking – get away first"
	if Game.gold < cost(s.global_position, harbor.global_position):
		return "Not enough gold"
	return ""


func travel(harbor: Harbor) -> bool:
	if blocked_reason(harbor) != "":
		return false
	var s := _player_ship()
	var price := cost(s.global_position, harbor.global_position)
	Game.spend(price)
	busy = true
	s.set_controlled(false)
	var fleet := _fleet_visuals(s)
	# 1. Sink, in a swirl of bubbles
	Sfx.play_at("splash", s.global_position)
	await _animate(SINK_TIME, func(t: float) -> void:
		for v in fleet:
			(v as ShipVisual).set_sinking(t)
		_spawn_bubbles(fleet, 1))
	# 2. Fade to deep blue and move everyone
	await _animate(FADE_TIME, func(t: float) -> void: _fade.color.a = t)
	# You arrive out at sea, under full sail, heading for the pier: lower the sails and
	# dock yourself (the harbor's local +x points out to sea).
	var arrival := arrival_spot(harbor)
	s.place_at(arrival, (harbor.dock_position() - arrival).angle())
	for escort in get_tree().get_nodes_in_group("escorts"):
		escort.call("_teleport_to_formation", s)
	var tow := get_tree().get_first_node_in_group("tow_train")
	if tow:
		tow.set("_positions", [] as Array[Vector2])
		tow.set("_count_key", "") # rebuilds the tow line behind the ship at its new spot
	_bubbles.clear()
	fleet = _fleet_visuals(s)
	for v in fleet:
		(v as ShipVisual).set_sinking(1.0)
		var wake: Variant = (v as ShipVisual).get("_wake")
		if wake:
			(wake as Wake).clear() # no foam trail across the whole world
	await get_tree().process_frame
	await _animate(FADE_TIME, func(t: float) -> void: _fade.color.a = 1.0 - t)
	# 3. Rise up through the water, already sailing at full speed – the wheel is yours
	s.set_controlled(true)
	s.sail_level = PlayerShip.SAIL_FACTORS.size() - 1
	s.sail_level_changed.emit(s.sail_level)
	s.speed = float(s.stats["speed"]) * Game.tow_speed_factor()
	Sfx.play_at("splash", s.global_position)
	await _animate(RISE_TIME, func(t: float) -> void:
		for v in fleet:
			if is_instance_valid(v):
				(v as ShipVisual).set_sinking(1.0 - t)
		_spawn_bubbles(fleet, 1))
	for v in fleet:
		if is_instance_valid(v):
			(v as ShipVisual).set_sinking(0.0)
	busy = false
	Game.notify("You surface off %s under full sail (%d gold). Lower the sails and dock!" % [harbor.harbor_name, price], UiTheme.ACCENT)
	Game.changed.emit()
	Game.save_game()
	return true


## Where you surface: open water straight out from the pier. The distance is worked out from
## this ship's speed and how it glides: take in the sails the moment you are up, and you coast
## to a stop right at the pier. React late and you need the anchor, or must steer away.
func arrival_spot(harbor: Harbor) -> Vector2:
	var s := _player_ship()
	var dock := harbor.dock_position()
	var out := Vector2.from_angle(harbor.global_rotation)
	var v := float(s.stats["speed"]) * Game.tow_speed_factor() if s else 100.0
	var glide := v * v / (2.0 * (s.deceleration if s else 9.0))
	var dist := clampf(v * RISE_TIME + glide, ARRIVAL_MIN, ARRIVAL_MAX)
	for k in [1.0, 0.8, 0.6, 0.4]:
		var p: Vector2 = dock + out * dist * float(k)
		if not Game.is_land(p) and not Game.is_land(dock + out * dist * float(k) * 0.5):
			return p
	return dock + out * ARRIVAL_MIN


func _player_ship() -> PlayerShip:
	return get_tree().get_first_node_in_group("player_ship") as PlayerShip


## The player ship's visual plus every escort's and towed ship's visual.
func _fleet_visuals(s: PlayerShip) -> Array:
	var list: Array = [s.visual]
	for escort in get_tree().get_nodes_in_group("escorts"):
		var v: Variant = escort.get("_visual")
		if v:
			list.append(v)
	var tow := get_tree().get_first_node_in_group("tow_train")
	if tow:
		list.append_array(tow.get("_visuals") as Array)
	return list


func _animate(seconds: float, step: Callable) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		step.call(clampf(t / seconds, 0.0, 1.0))


func _spawn_bubbles(fleet: Array, per_ship: int) -> void:
	for v in fleet:
		if not is_instance_valid(v):
			continue
		var c := (v as Node2D).global_position
		for i in per_ship:
			if randf() < 0.35:
				var p := c + Vector2(randf_range(-22, 22), randf_range(-12, 12))
				_bubbles.append(Vector4(p.x, p.y, 0.0, randf_range(1.0, 2.6)))


func _process(delta: float) -> void:
	if _bubbles.is_empty():
		return
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.z += delta
		b.y -= delta * 14.0 # drift up the screen as they "rise"
		if b.z > 1.1:
			_bubbles.remove_at(i)
		else:
			_bubbles[i] = b
	queue_redraw()


func _draw() -> void:
	for b in _bubbles:
		var a := 1.0 - b.z / 1.1
		draw_arc(Vector2(b.x, b.y), b.w * (1.0 + b.z), 0.0, TAU, 10, Color(0.9, 0.97, 1.0, 0.45 * a), 0.7, true)
