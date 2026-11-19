extends Node
## The big cities: Port Aurel (royal) and Gallows Bay (pirate). Checks that they exist with a
## stone harbor and a town, that the docks are in open water (also the other mainland harbor,
## Valmar), that you can walk the quays and streets but not through houses, that ships are
## moored and sailing, that the pirate city is gloomy, and how fast it runs. Screenshots of the
## arrival from the sea, the streets, and the pirate city.
## Run: godot res://tests/city_check.tscn   (exits with code 1 on any failure)

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

	var cities := get_tree().get_nodes_in_group("big_cities")
	_check(cities.size() == 2, "two big cities (%d)" % cities.size())
	var royal: BigCity = null
	var pirate: BigCity = null
	for c in cities:
		if (c as BigCity).kind == "royal":
			royal = c
		else:
			pirate = c
	_check(royal != null and royal.harbor.harbor_name == "Port Aurel", "Port Aurel is the royal capital")
	_check(pirate != null and pirate.harbor.harbor_name == "Gallows Bay" and Game.faction_of("Gallows Bay") == "smugglers", "Gallows Bay is the Smugglers' pirate city")
	for h in get_tree().get_nodes_in_group("harbors"):
		var harbor := h as Harbor
		if harbor.harbor_name in ["Port Aurel", "Valmar", "Gallows Bay"]:
			_check(not Game.is_land(harbor.dock_position()), "%s: you dock in open water (was on land before)" % harbor.harbor_name)
	_check(Catalog.HARBOR_NAMES["smugglers"].size() == 9 and get_tree().get_nodes_in_group("harbors").filter(func(h): return Game.faction_of((h as Harbor).harbor_name) == "smugglers").size() == 9,
		"8 smugglers' harbors as before, plus Gallows Bay")

	for city in [royal, pirate]:
		if city == null:
			continue
		var c := city as BigCity
		var cname := c.harbor.harbor_name
		# Sail in from the sea
		var out := Vector2.from_angle(c.global_rotation)
		ship.place_at(c.to_global(Vector2(1700, 0)), (-out).angle())
		ship.set_controlled(true)
		ship.sail_level = 1
		Game.user_zoom = 0.45
		await _frames(150)
		print("     %s: %d houses, %d walk areas" % [cname, c.houses.size(), c.walk_polys.size()])
		_check(c.houses.size() >= 60, "%s: a big town (%d houses)" % [cname, c.houses.size()])
		_check(c.get("_moored").size() >= 6 and c.get("_traffic").size() == 2, "%s: ships moored at the quays and sailing in and out" % cname)
		var t0: Vector2 = (c.get("_traffic")[0] as Node2D).position
		await _frames(60)
		_check((c.get("_traffic")[0] as Node2D).position.distance_to(t0) > 10.0, "%s: the harbor ships move" % cname)
		ship.place_at(c.to_global(Vector2(1150, 0)), (-out).angle())
		ship.sail_level = 1
		await _frames(40)
		await _shot("c_%s_arrival" % c.kind)
		Game.user_zoom = 0.22
		await _frames(90)
		await _shot("c_%s_overview" % c.kind)
		Game.user_zoom = 0.45
		_check(c.covers(c.to_global(Vector2(300, -330) * BigCity.S)) and c.covers(c.to_global(Vector2(60, 0))), "%s: the mole and the pier can be walked on" % cname)
		_check(not c.covers(c.to_global(Vector2(250, 0) * BigCity.S)), "%s: the basin is water" % cname)

		# Dock: the harbor master welcomes you with a choice
		ship.sail_level = 0
		var dialog := main.get_node("QuestDialog") as QuestDialog
		main.call("_on_dock_requested", c.harbor)
		await _frames(4)
		var talk: Dictionary = dialog.get("_talk")
		_check(dialog.is_open() and talk.get("mode", "") == "choice" and talk["person"] == Catalog.BIG_CITY_WELCOME[c.kind]["person"],
			"%s: docking, %s welcomes you" % [cname, Catalog.QUEST_PEOPLE[talk.get("person", "maren")]["name"]])
		await _frames(150)
		await _shot("c_%s_welcome" % c.kind)
		if c.kind == "royal": # "Harbor business": the harbor menu as always
			dialog.call("_close", "business")
			await _frames(4)
			_check(main.get_node("HarborMenu").visible, "Harbor business opens the harbor menu")
			main.get_node("HarborMenu").call("close")
			await _frames(3)
			main.call("_on_dock_requested", c.harbor)
			await _frames(4)
		# "Explore the town": on your feet on the pier
		dialog.call("_close", "stroll")
		await _frames(6)
		var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
		_check(player != null and not get_tree().paused and not main.get_node("HarborMenu").visible, "%s: Explore the town puts you ashore, no menu" % cname)
		if player == null:
			continue
		_check(player.global_position.distance_to(c.harbor.to_global(Vector2(40, 0))) < 6.0 and not ship.controlled,
			"%s: you stand on the pier by your ship, which stays at its berth" % cname)
		_check(player.on_land, "%s: standing on the stone pier, not swimming" % cname)
		player.global_position = c.to_global(Vector2(-60, 0))
		player.set("_prev_pos", player.global_position)
		player.set("_curr_pos", player.global_position)
		Game.user_zoom = 1.0
		var walk_dir := -out
		await _walk(walk_dir, 240)
		_check(player.on_land and c.to_local(player.global_position).x < -150.0, "%s: walking up the avenue into the town (%d px in)" % [cname, int(-c.to_local(player.global_position).x)])
		await _shot("c_%s_street" % c.kind)
		# Walk at a house: it stops you
		var house: Rect2 = c.houses[c.houses.size() / 2]
		var side := Vector2(house.get_center().x, house.position.y - 14.0)
		player.global_position = c.to_global(side)
		await _frames(3)
		var before := c.to_local(player.global_position)
		await _walk((c.to_global(house.get_center()) - player.global_position).normalized(), 60)
		var inside := house.grow(-2.0).has_point(c.to_local(player.global_position))
		_check(not inside, "%s: houses are solid (moved %d px, stopped at the wall)" % [cname, int(before.distance_to(c.to_local(player.global_position)))])
		# Gloom
		var sky := main.get_node("Sky") as WorldSky
		await _frames(10)
		var gloom := sky.city_gloom()
		if c.kind == "pirate":
			_check(gloom > 0.8, "Gallows Bay is gloomy in daylight (%.2f)" % gloom)
			var col := (sky.get("_modulate") as CanvasModulate).color
			_check(col.v < 0.6, "the light is dim in Gallows Bay (brightness %.2f)" % col.v)
			await _frames(30)
			await _shot("c_pirate_gloom")
		else:
			_check(gloom < 0.05, "Port Aurel is bright (gloom %.2f)" % gloom)
		# Back aboard
		player.global_position = ship.global_position
		main.call("_on_board_requested")
		await _frames(5)
		ship.place_at(c.to_global(Vector2(-650, 0)), c.global_rotation) # the whole town from above
		Game.user_zoom = 0.2
		await _frames(60)
		await _shot("c_%s_town" % c.kind)
		Game.user_zoom = 0.45

	# How fast it runs with a city on screen
	if royal:
		ship.place_at(royal.to_global(Vector2(1200, 0)), PI)
		Game.user_zoom = 0.45
		await _frames(60)
		var with_city := await _frame_ms()
		royal.visible = false
		royal.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(30)
		var without := await _frame_ms()
		royal.visible = true
		royal.process_mode = Node.PROCESS_MODE_INHERIT
		print("     frame time at Port Aurel: %.2f ms with the city, %.2f ms without (cost %.2f ms)" % [with_city, without, with_city - without])
		_check(with_city - without < 4.0, "the city costs little (%.2f ms per frame, whole city on screen; budget 4 ms)" % (with_city - without))
		Game.world_time = 0.0
		await _frames(30)
		await _shot("c_royal_night")
	print("CITY CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frame_ms() -> float:
	var t := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / 120.0


func _walk(dir: Vector2, frames: int) -> void:
	var actions := []
	if dir.x > 0.3: actions.append("move_right")
	if dir.x < -0.3: actions.append("move_left")
	if dir.y > 0.3: actions.append("move_down")
	if dir.y < -0.3: actions.append("move_up")
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
	await _frames(2)
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
