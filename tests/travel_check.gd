extends Node
## Fast travel and the discreet wake: travels from Sunhaven to another harbor with an escort
## and a ship in tow, checks where everyone ends up and what it cost, tries the blocked cases,
## and takes screenshots of the map bar, the sinking/rising transition and the wake.
## Run: godot res://tests/travel_check.tscn   (exits with code 1 on any failure)

var main: Node
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.use_test_files() # never touch the real save or settings
	Game.delete_save()
	Game.reset()
	Homestead.reset()
	Quests.reset()
	Quests.index = Catalog.QUESTS.size() # no quest chats when docking
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(40)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var travel := main.get_node("FastTravel") as FastTravel
	Game.user_zoom = 2.2 # close enough to see the wake and the bubbles
	var start := _harbor("Sunhaven")
	ship.place_at(start.dock_position(), start.dock_rotation())
	await _frames(5)
	_check(Game.visited_harbors.has("Sunhaven"), "the start harbor counts as visited")

	# The wake: sail at full speed for a moment
	ship.place_at(start.dock_position() + Vector2(-900, 300), PI)
	ship.sail_level = 2
	await _frames(150)
	await _shot("t1_wake")
	ship.sail_level = 0
	ship.place_at(start.dock_position(), start.dock_rotation())

	# A destination a fair way off
	var dest: Harbor = null
	for node in get_tree().get_nodes_in_group("harbors"):
		var h := node as Harbor
		if h.kind != "home" and h != start and (dest == null or absf(h.global_position.distance_to(start.global_position) - 3000.0) < absf(dest.global_position.distance_to(start.global_position) - 3000.0)):
			dest = h
	print("     destination: %s, %d px away, %d gold" % [dest.harbor_name, int(dest.global_position.distance_to(start.global_position)), FastTravel.cost(ship.global_position, dest.global_position)])
	_check(travel.blocked_reason(dest).begins_with("Not visited"), "unvisited harbors can't be travelled to")
	Game.visited_harbors[dest.harbor_name] = true
	_check(travel.blocked_reason(dest) == "", "a visited harbor can be travelled to")
	_check(travel.blocked_reason(start) == "You are already here", "no trip to where you already are")

	# Blocked: captain ashore, pirates attacking, no gold
	var fake_player := Node2D.new()
	fake_player.add_to_group("player_character")
	add_child(fake_player)
	_check(travel.blocked_reason(dest).contains("ashore"), "blocked while the captain is ashore")
	fake_player.queue_free()
	await _frames(2)
	var pirate := EnemyShip.new()
	pirate.setup("pirate", "sloop")
	pirate.global_position = ship.global_position + Vector2(300, 0)
	Game.world_root.add_child(pirate)
	pirate.state = "attack"
	_check(travel.blocked_reason(dest).contains("Pirates"), "blocked while pirates attack")
	pirate.queue_free()
	await _frames(2)
	var gold := Game.gold
	Game.gold = 0
	_check(travel.blocked_reason(dest) == "Not enough gold", "blocked without enough gold")
	Game.gold = gold

	# An escort with a captain, and a ship in tow
	Game.owned_ships.append(Game.new_ship_config("schooner"))
	Game.captain_slots = 2
	Game.hire_captain(Game.random_captain_candidate())
	Game.assign_captain(int(Game.captains[0]["id"]), Game.owned_ships.size() - 1)
	Game.towed.append(Game.new_ship_config("sloop"))
	Game.changed.emit()
	await _frames(30)
	_check(get_tree().get_nodes_in_group("escorts").size() == 1, "an escort sails with you")

	# Pick the harbor on the map and press Fast travel
	var pause := main.get_node("PauseMenu")
	pause.call("open", 0)
	await _frames(5)
	var map := pause.find_children("*", "MapView", true, false)[0] as MapView
	map.set("_pan", (start.global_position + dest.global_position) * 0.5)
	map.set("_zoom", 6.0)
	await _frames(3)
	map.select_harbor_at(map.call("_to_map", dest.global_position))
	await _frames(3)
	_check(map.selected_harbor() == dest, "clicking a harbor on the map picks it")
	var bar := map.get("_bar") as Control
	_check(bar.visible and not (map.get("_bar_button") as Button).disabled, "the fast travel bar shows with the button enabled")
	await _shot("t2_map_bar")
	var cost := FastTravel.cost(ship.global_position, dest.global_position)
	gold = Game.gold
	map.call("_on_fast_travel")
	await _frames(2)
	_check(not pause.visible and travel.busy, "the menu closes and the trip starts")
	await _frames(40)
	await _shot("t3_sinking")
	var waited := 0
	while travel.busy and waited < 900:
		await get_tree().process_frame
		waited += 1
		if waited == 150:
			await _shot("t4_rising")
	_check(not travel.busy, "the trip finishes (%d frames)" % waited)
	var to_dock := dest.dock_position() - ship.global_position
	_check(to_dock.length() > 150.0 and to_dock.length() < 650.0, "you surface out at sea off %s (%d px from the pier)" % [dest.harbor_name, int(to_dock.length())])
	_check(ship.sail_level == PlayerShip.SAIL_FACTORS.size() - 1 and ship.speed > 10.0, "you arrive under full sail and moving (%.0f px/s)" % ship.speed)
	_check(Vector2.from_angle(ship.rotation).dot(to_dock.normalized()) > 0.9, "heading straight for the pier")
	_check(Game.gold == gold - cost, "the trip cost %d gold" % cost)
	_check(ship.controlled, "you can sail again")
	_check(is_equal_approx((ship.visual.get("_body") as Node2D).modulate.a, 1.0), "your ship is fully above water again")
	for escort in get_tree().get_nodes_in_group("escorts"):
		_check((escort as Node2D).global_position.distance_to(ship.global_position) < 400.0, "your captain's ship came along")
	await _frames(10)
	var tow_visuals: Array = get_tree().get_first_node_in_group("tow_train").get("_visuals")
	_check(tow_visuals.size() == 1 and (tow_visuals[0] as Node2D).global_position.distance_to(ship.global_position) < 200.0, "the ship in tow came along")
	# Taking in the sails right away lets you coast to a stop at the pier
	ship.sail_level = 0
	var glide_frames := 0
	while ship.speed > 3.0 and glide_frames < 3000:
		await get_tree().process_frame
		glide_frames += 1
	var left := ship.global_position.distance_to(dest.dock_position())
	_check(ship.speed <= 3.0 and left < Harbor.DOCK_RADIUS + 40.0, "sails down at once: you coast to a stop at the pier (%d px left)" % int(left))
	await _shot("t5_arrived")

	# A new voyage starts with no gold (tests get their own start gold)
	_check(Game.START_GOLD == 0, "a new voyage starts with 0 gold")

	# On foot you can't zoom out as far as at sea
	var cam := ZoomCamera.new()
	cam.min_user_zoom = ZoomCamera.ON_FOOT_MIN_ZOOM
	Game.user_zoom = ZoomCamera.MIN_USER_ZOOM
	_check(is_equal_approx(cam.effective_user_zoom(), ZoomCamera.ON_FOOT_MIN_ZOOM), "on foot the view stays close even if you zoomed far out at sea")
	cam.free()
	print("TRAVEL CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _harbor(harbor_name: String) -> Harbor:
	for node in get_tree().get_nodes_in_group("harbors"):
		if (node as Harbor).harbor_name == harbor_name:
			return node
	return null


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["OK  " if ok else "FAIL", text])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(2)
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
