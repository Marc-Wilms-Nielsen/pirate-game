extends Node
## The anchor: dropped at full speed it brakes the ship smoothly, and the chain drags the ship
## towards the side the anchor went over (starboard by default, or the side you steer to),
## instead of drifting straight on. No sudden jolt. Dropped at rest, nothing happens.
## Run: godot res://tests/anchor_check.tscn   (exits with code 1 on any failure)

var main: Node
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.use_test_files() # never touch the real save or settings
	Game.delete_save()
	Game.reset()
	Homestead.reset()
	Quests.reset()
	Quests.index = Catalog.QUESTS.size()
	Settings.max_fps = 60
	Engine.max_fps = 60
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(40)
	Game.user_zoom = 1.0
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var spot := _deep_spot()

	# 1. Full speed, no steering: the anchor goes over starboard (to the right of the heading)
	var r := await _drop_at_speed(ship, spot, "", "a1")
	_check(r["lateral"] > 25.0, "the ship is dragged towards the anchor's side (starboard), %d px off a straight line" % int(r["lateral"]))
	_check(r["max_brake"] < ship.anchor_brake * 1.5, "smooth braking: at most %.0f px/s² (no sudden stop)" % r["max_brake"])
	_check(r["max_turn"] < 2.0, "smooth turn: at most %.2f rad/s (no jolt)" % r["max_turn"])
	_check(r["end_speed"] < 6.0, "the anchor stops the ship (%.0f px/s left)" % r["end_speed"])
	_check(r["facing"] > 0.5, "the ship ends up with its bow towards the anchor")

	# 2. Steering left while dropping: the anchor goes over port, and the ship is dragged left
	var l := await _drop_at_speed(ship, spot + Vector2(0, 1200), "move_left", "a2")
	_check(l["lateral"] < -25.0, "steering left drops it to port: dragged left, %d px" % int(l["lateral"]))

	# 3. At rest: nothing happens
	ship.place_at(spot + Vector2(0, 2400), 0.0)
	ship.set_controlled(true)
	await _frames(30)
	var p0 := ship.global_position
	var rot0 := ship.rotation
	await _press_anchor()
	await _frames(120)
	_check(ship.global_position.distance_to(p0) < 8.0 and absf(angle_difference(rot0, ship.rotation)) < 0.3,
		"dropped at rest, the ship stays put")
	# 4. Anchored without the key (code sets it directly): the anchor lands right there, and the
	# ship is not dragged off towards some old spot (it used to be pulled towards 0,0)
	ship.place_at(spot + Vector2(0, 3600), 0.0)
	ship.set_controlled(true)
	await _frames(20)
	ship.speed = float(ship.stats["speed"])
	var here := ship.global_position
	ship.anchored = true
	await _frames(60)
	_check(ship.global_position.distance_to(here) < 150.0, "anchored by code, the ship stays near where it was (%d px)" % int(ship.global_position.distance_to(here)))
	ship.anchored = false
	print("ANCHOR CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Sails at full speed heading east, drops the anchor (optionally while holding a steering
## key) and measures what happens. lateral > 0 = dragged to starboard (south).
func _drop_at_speed(ship: PlayerShip, spot: Vector2, steer: String, shot: String) -> Dictionary:
	ship.place_at(spot, 0.0)
	ship.set_controlled(true)
	ship.sail_level = 2
	await _frames(240) # up to full speed, heading east
	var start := ship.global_position
	var v0 := ship.speed
	if steer != "":
		Input.action_press(steer)
	await _press_anchor()
	if steer != "":
		Input.action_release(steer)
	var anchor: Vector2 = ship.get("_anchor_point")
	var max_brake := 0.0
	var max_turn := 0.0
	var last_speed := ship.speed
	var last_rot := ship.rotation
	for i in 300: # 5 s
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		max_brake = maxf(max_brake, (last_speed - ship.speed) / dt)
		max_turn = maxf(max_turn, absf(angle_difference(last_rot, ship.rotation)) / dt)
		last_speed = ship.speed
		last_rot = ship.rotation
		if i == 90:
			await _shot(shot + "_dragged")
	var lateral := ship.global_position.y - start.y
	var facing := Vector2.from_angle(ship.rotation).dot((anchor - ship.global_position).normalized())
	print("     %s: %.0f px/s → %.0f, lateral %d px, max brake %.0f, max turn %.2f rad/s" % [
		"steer " + steer if steer != "" else "straight", v0, ship.speed, int(lateral), max_brake, max_turn])
	await _press_anchor() # weigh anchor again
	return {"lateral": lateral, "max_brake": max_brake, "max_turn": max_turn, "end_speed": ship.speed, "facing": facing}


func _press_anchor() -> void:
	Input.action_press("anchor")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("anchor")
	await get_tree().physics_frame


## Open water with room to swing in every direction.
func _deep_spot() -> Vector2:
	for i in 400:
		var p := Vector2.from_angle(i * 2.4) * (2500.0 + i * 40.0)
		var ok := true
		for k in 8:
			for dist in [600.0, 1800.0, 3000.0]:
				if Game.water_depth(p + Vector2.from_angle(k * TAU / 8.0) * float(dist)) < 1.0:
					ok = false
		if ok and Game.water_depth(p) >= 1.0:
			return p
	return Vector2(0, 4000)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["OK  " if ok else "FAIL", text])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
