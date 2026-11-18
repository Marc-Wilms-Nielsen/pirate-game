extends Node
## The anchor: dropped at full speed, the ship runs on until the chain is out, then the chain
## snaps tight and yanks the ship around the anchor. Dropped at rest, nothing dramatic happens.
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
	ship.place_at(spot, 0.0)
	ship.set_controlled(true)
	ship.sail_level = 2
	await _frames(240) # up to full speed
	var v0 := ship.speed
	var rot0 := ship.rotation
	print("     speed before the anchor: %.0f px/s" % v0)
	await _press_anchor()
	_check(ship.anchored, "the anchor is down")
	var chain: float = ship.get("_chain_length")
	var anchor: Vector2 = ship.get("_anchor_point")
	var taut_at := -1
	var max_spin := 0.0
	var max_over := 0.0
	var shots := 0
	for i in 420: # 7 s
		await get_tree().physics_frame
		if taut_at < 0 and ship.get("_chain_taut"):
			taut_at = i
		max_spin = maxf(max_spin, absf(float(ship.get("_yank_spin"))))
		var bow := ship.to_global(Vector2(34, 0) * float(ship.stats["size"]))
		max_over = maxf(max_over, bow.distance_to(anchor) - chain)
		if taut_at >= 0 and shots < 3 and i == taut_at + 15 + shots * 30:
			await _shot("a%d_swing" % (shots + 1))
			shots += 1
	var turned := absf(rad_to_deg(angle_difference(rot0, ship.rotation)))
	print("     chain %.0f px, snapped tight after %.2f s, max spin %.2f rad/s, turned %.0f°" % [chain, taut_at / 60.0, max_spin, turned])
	_check(taut_at > 3, "the ship runs on a moment before the chain snaps tight")
	_check(max_spin > 1.0, "the chain yanks the ship into a hard spin")
	_check(turned > 60.0, "the ship is pulled around (%d°)" % int(turned))
	_check(max_over < 3.0, "the chain holds the bow (at most %.1f px past it)" % max_over)
	_check(ship.speed < 12.0, "the anchor stops the ship (%.0f px/s left)" % ship.speed)
	var bow_dir := (anchor - ship.global_position).normalized()
	_check(Vector2.from_angle(ship.rotation).dot(bow_dir) > 0.5, "the ship ends up with its bow towards the anchor")
	await _press_anchor()
	_check(not ship.anchored, "the anchor comes up again")

	# At rest: no jolt
	ship.place_at(spot + Vector2(0, 600), 0.0)
	ship.set_controlled(true)
	await _frames(30)
	await _press_anchor()
	var calm_spin := 0.0
	for i in 120:
		await get_tree().physics_frame
		calm_spin = maxf(calm_spin, absf(float(ship.get("_yank_spin"))))
	_check(calm_spin < 0.3, "dropped at rest, the anchor doesn't yank (spin %.2f)" % calm_spin)
	print("ANCHOR CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
			if Game.water_depth(p + Vector2.from_angle(k * TAU / 8.0) * 500.0) < 1.0:
				ok = false
				break
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
