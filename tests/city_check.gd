extends Node
## Lanternmouth, the canal city: checks that it stands on its own big island near Sunhaven with
## a straight waterfront, that you dock in open water and the harbourmaster welcomes you, that
## you can walk the quay, the streets and the bridges but not through houses, canals or the old
## town's wall, that the shop's door opens the market, that ships come and go, and how fast it
## runs. Screenshots: arriving from the sea, the town from above, streets, canals, the old town,
## the shop, and the town at night.
## Run: godot res://tests/city_check.tscn   (exits with code 1 on any failure)

var main: Node
var _failures := 0
var city: BigCity
var player: PlayerCharacter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.use_test_files() # never touch the real save or settings
	Game.delete_save()
	Game.reset()
	Homestead.reset()
	Quests.reset()
	Quests.index = Catalog.QUESTS.size() # no quest chat when docking
	Settings.max_fps = 0
	Settings.vsync = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(30)
	Game.world_time = 0.45
	(main.get_node("Sky") as WorldSky).set_weather("clear")
	(main.get_node("Sky") as WorldSky).snap_weather()
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip

	# --- The island and the harbor ---
	var cities := get_tree().get_nodes_in_group("big_cities")
	_check(cities.size() == 1, "one big city (%d)" % cities.size())
	if cities.is_empty():
		_finish()
		return
	city = cities[0]
	var isl := city.island
	print("     %s: island at %s, %d px from Sunhaven, radius %d; %d houses" % [Catalog.CITY["name"], str(isl.global_position.round()), int(isl.global_position.length()), int(isl.radius), city.houses.size()])
	_check(city.harbor.harbor_name == Catalog.CITY["name"] and isl.island_name == Catalog.CITY["name"], "the city is %s" % Catalog.CITY["name"])
	_check(isl.global_position.length() < 8000.0, "a short sail from Sunhaven (%d px)" % int(isl.global_position.length()))
	_check(not isl.is_mainland() and get_tree().get_nodes_in_group("islands").filter(func(i): return (i as Island).is_mainland()).size() == 6, "its own big island, not one of the 6 mainlands")
	var to_sunhaven := (-isl.global_position).normalized()
	_check(Vector2.from_angle(city.global_rotation).dot(to_sunhaven) > 0.99, "the waterfront faces Sunhaven")
	_check(not Game.is_land(city.harbor.dock_position()), "you dock in open water")
	var straight := true
	for y in range(-900, 901, 100):
		if Game.is_land(city.to_global(Vector2(14, y))) or not Game.is_land(city.to_global(Vector2(-30, y))):
			straight = false
	_check(straight, "the island's coast runs straight along the quay")
	var depth_ok := Game.water_depth(city.to_global(Vector2(40, 300))) > 0.95 and Game.water_depth(city.to_global(Vector2(40, -300))) > 0.95
	_check(depth_ok, "deep water right off the stone quay (the water shader knows the straight coast)")
	_check(Game.is_land(city.to_global(BigCity.HILL)) and Game.is_land(city.to_global(BigCity.HILL - Vector2(BigCity.SLOPE_R, 0))), "the hill and the old town fit on the island")
	var old := city.houses.filter(func(h): return h.old).size()
	_check(city.houses.size() >= 160 and old >= 30, "a big town: %d houses, %d of them in the old town" % [city.houses.size(), old])
	_check(city.doors.filter(func(d): return d[1] == "shop").size() == 1 and city.doors.filter(func(d): return d[1] == "saloon").size() == 3, "a shop and three saloons")
	var zones := main.get_node("WorldZones") as WorldZones
	_check(String(zones.zones[zones.zone_at(city.to_global(Vector2(300, 0)))]["name"]) == Catalog.CITY["zone"], "its waters are %s" % Catalog.CITY["zone"])
	_check(Game.faction_of(Catalog.CITY["name"]) == "free" and not Catalog.QUESTS.any(func(q): return Quests.giver_harbor(q) == Catalog.CITY["name"] or Quests.turn_in_harbor(q) == Catalog.CITY["name"]),
		"a free harbor, and the quest line stays where it was")

	# --- Sailing in ---
	var out := Vector2.from_angle(city.global_rotation)
	ship.place_at(city.to_global(Vector2(1800, 0)), (-out).angle())
	ship.set_controlled(true)
	ship.sail_level = 1
	Game.user_zoom = 0.45
	await _frames(120)
	var moored: Array = city.get("_moored")
	var traffic := city.get_children().filter(func(n): return n is BigCity.HarborShip)
	_check(moored.size() >= 8 and traffic.size() == 2, "ships moored at the piers (%d) and ships coming and going (%d)" % [moored.size(), traffic.size()])
	var starts := traffic.map(func(t): return (t as Node2D).position)
	await _frames(90)
	var moved := 0.0
	for i in traffic.size():
		moved = maxf(moved, (traffic[i] as Node2D).position.distance_to(starts[i]))
	_check(moved > 5.0, "a ship sails in or out (%d px)" % int(moved))
	ship.place_at(city.to_global(Vector2(420, 150)), (-out).angle())
	Game.user_zoom = 0.3
	ship.sail_level = 1
	await _frames(40)
	await _shot("c01_arrival")
	ship.place_at(city.to_global(Vector2(-700, 0)), city.global_rotation)
	Game.user_zoom = 0.17
	await _frames(90)
	await _shot("c02_overview")
	Game.user_zoom = 0.45
	_check(city.covers(city.to_global(Vector2(200, -BigCity.HW))) and city.covers(city.to_global(Vector2(60, 0))), "the mole and the pier can be walked on")
	_check(not city.covers(city.to_global(Vector2(300, 0))) and not Game.is_land(city.to_global(Vector2(300, 0))), "the basin is water")

	# --- Docking: the harbourmaster's welcome ---
	ship.place_at(city.harbor.dock_position(), city.harbor.dock_rotation())
	ship.sail_level = 0
	await _frames(10)
	var dialog := main.get_node("QuestDialog") as QuestDialog
	main.call("_on_dock_requested", city.harbor)
	await _frames(4)
	var talk: Dictionary = dialog.get("_talk")
	_check(dialog.is_open() and talk.get("mode", "") == "choice" and talk["person"] == Catalog.CITY["person"], "docking, the harbourmaster welcomes you with a choice")
	await _frames(200)
	await _shot("c03_welcome")
	dialog.call("_close", "business")
	await _frames(4)
	var menu := main.get_node("HarborMenu")
	_check(menu.visible, "Harbor business opens the harbor menu")
	menu.call("close")
	await _frames(3)
	main.call("_on_dock_requested", city.harbor)
	await _frames(4)
	dialog.call("_close", "stroll")
	await _frames(6)
	player = get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	_check(player != null and not get_tree().paused and not menu.visible and not ship.controlled, "Stroll ashore: on your feet on the pier, your ship stays at its berth")
	if player == null:
		_finish()
		return
	_check(player.on_land, "standing on the stone pier, not swimming")
	Game.user_zoom = 1.0

	# --- Walking the town ---
	await _put(Vector2(-50, 0))
	await _walk(-out, 200)
	var p := _local()
	_check(player.on_land and p.x < -200.0 and absf(p.y) < 45.0, "walking up the avenue into town (%d px in)" % int(-p.x))
	await _put(Vector2(-130, -5))
	await _shot("c04_avenue_shop")
	# The shop: F at its door opens the market; you stay ashore afterwards
	var shop_door: Vector2 = city.doors.filter(func(d): return d[1] == "shop")[0][0]
	await _put(shop_door)
	_check(player.nearby_shop() == city.harbor, "at the Chandlery's door, F would step in")
	await _shot("c05_shop_door")
	Game.shop_requested.emit(player.nearby_shop())
	await _frames(4)
	_check(menu.visible and String(menu.get("_leave_button").text).begins_with("Leave"), "the shop opens the harbor menu (Leave the shop)")
	menu.call("close")
	await _frames(4)
	_check(is_instance_valid(player) and not ship.controlled and not get_tree().paused, "leaving the shop, you are still ashore")
	# A saloon: just noise
	var saloon: Array = city.doors.filter(func(d): return d[1] == "saloon")[1]
	await _put(saloon[0])
	_check(city.saloon_at(player.global_position) == saloon[2], "outside %s" % saloon[2])
	await _shot("c06_saloon_canal")
	# A house stops you
	var house: BigCity.House = city.houses.filter(func(h): return not h.old and h.special == "")[40]
	await _put(house.c + Vector2(0, -house.size.y * 0.5 - 14))
	await _walk(city.to_global(house.c) - player.global_position, 60)
	_check(not house.rect().grow(-2).has_point(_local() - house.c), "houses are solid (stopped at the wall, %d px from its middle)" % int(_local().distance_to(house.c)))
	# The canal stops you, the bridge takes you across
	await _put(Vector2(-560, -BigCity.CANAL_Y - BigCity.CANAL_HALF - 14))
	await _walk(_dir_local(Vector2.DOWN), 90)
	_check(_local().y < -BigCity.CANAL_Y - BigCity.CANAL_HALF + 2, "you can't walk into a canal (y %d)" % int(_local().y))
	await _put(Vector2(BigCity.STREET_A, -BigCity.CANAL_Y - BigCity.CANAL_HALF - 14))
	await _walk(_dir_local(Vector2.DOWN), 110)
	_check(_local().y > -BigCity.CANAL_Y + BigCity.CANAL_HALF, "over the bridge to the other side of the canal (y %d)" % int(_local().y))
	await _put(Vector2(BigCity.STREET_A, -BigCity.CANAL_Y - 10))
	await _shot("c07_bridge")
	await _put(Vector2(BigCity.CROSS_X - 60, 120))
	await _shot("c08_cross_canal")
	# Up the stair to the old town; the wall stops you elsewhere
	await _put(BigCity.SQUARE.get_center())
	await _shot("c09_square")
	await _walk(_dir_local(Vector2.LEFT), 260)
	_check(_local().distance_to(BigCity.HILL) < BigCity.PLATEAU_R - 10.0, "up the stair and through the gate into the old town (%d px from the top)" % int(_local().distance_to(BigCity.HILL)))
	await _put(BigCity.HILL + Vector2(BigCity.RING_R, 0))
	await _shot("c10_old_town")
	await _put(BigCity.HILL + Vector2(0, BigCity.PLATEAU_R + 30))
	await _walk(_dir_local(Vector2.UP), 90)
	_check(_local().distance_to(BigCity.HILL) > BigCity.PLATEAU_R - 2.0, "the ring wall stops you away from the gate")
	var gull: Array = city.doors.filter(func(d): return d[1] == "saloon")[2]
	await _put(gull[0])
	await _shot("c11_old_market")

	# --- Back aboard, and how fast it runs ---
	player.global_position = ship.global_position
	main.call("_on_board_requested")
	await _frames(5)
	ship.place_at(city.to_global(Vector2(1100, 0)), (-out).angle())
	Game.user_zoom = 0.45
	await _frames(60)
	var with_city := await _frame_ms()
	city.visible = false
	city.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	var without := await _frame_ms()
	city.visible = true
	city.process_mode = Node.PROCESS_MODE_INHERIT
	print("     frame time off Lanternmouth: %.2f ms with the city, %.2f ms without (cost %.2f ms)" % [with_city, without, with_city - without])
	_check(with_city - without < 4.0, "the city costs little (%.2f ms per frame; budget 4 ms)" % (with_city - without))
	Game.world_time = 0.0
	ship.place_at(city.to_global(Vector2(260, 0)), (-out).angle())
	Game.user_zoom = 0.3
	await _frames(40)
	await _shot("c12_night_harbor")
	ship.place_at(city.to_global(Vector2(-430, -330)), (-out).angle()) # over the rooftops, for the look
	Game.user_zoom = 0.8
	await _frames(40)
	await _shot("c13_night_canal")
	_finish()


func _finish() -> void:
	print("CITY CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Puts the captain at a spot in the city (city space).
func _put(local: Vector2) -> void:
	var g := city.to_global(local)
	player.global_position = g
	player.velocity = Vector2.ZERO
	player.set("_prev_pos", g)
	player.set("_curr_pos", g)
	await _frames(2)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _frames(6)


func _local() -> Vector2:
	return city.to_local(player.global_position)


func _dir_local(d: Vector2) -> Vector2:
	return d.rotated(city.global_rotation)


func _frame_ms() -> float:
	var t := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / 120.0


## Holds the movement keys for a direction (in the world), for some physics frames.
func _walk(dir: Vector2, frames: int) -> void:
	dir = dir.normalized()
	var actions := []
	if dir.x > 0.38: actions.append("move_right")
	if dir.x < -0.38: actions.append("move_left")
	if dir.y > 0.38: actions.append("move_down")
	if dir.y < -0.38: actions.append("move_up")
	for a in actions:
		Input.action_press(a)
	for i in frames:
		await get_tree().physics_frame
	for a in actions:
		Input.action_release(a)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["OK  " if ok else "FAIL", text])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
