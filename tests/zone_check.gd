extends Node
## The named areas of the sea: checks they cover the world, that the borders on the map match
## what the game uses, that the name shows once when you sail into a new area (and not when you
## wobble across a border), and takes screenshots of the map and of the name on screen.
## Run: godot res://tests/zone_check.tscn   (exits with code 1 on any failure)

var main: Node
var _failures := 0
var _entered: Array[int] = []


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
	await _frames(20)
	var zones := main.get_node("WorldZones") as WorldZones
	zones.zone_entered.connect(func(i: int) -> void: _entered.append(i))
	var banner := zones.get("_banner") as ZoneBanner
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip

	# The areas
	var names := {}
	for z in zones.zones:
		names[z["name"]] = true
		print("     %-24s %-18s %-8s %d corners" % [z["name"], z["subtitle"], z["kind"], (z["polygon"] as PackedVector2Array).size()])
	_check(zones.zones.size() == 1 + 6 + WorldZones.SEA_ZONES, "%d named areas: home, 6 mainlands, %d open sea" % [zones.zones.size(), WorldZones.SEA_ZONES])
	_check(names.size() == zones.zones.size(), "every area has its own name")
	var kinds := zones.zones.map(func(z: Dictionary) -> String: return z["kind"])
	_check(kinds.count("kingdom") == 3 and kinds.count("wild") == 3, "3 kingdom waters and 3 wild waters")
	var own := true
	for i in zones.zones.size():
		if (zones.zones[i]["polygon"] as PackedVector2Array).size() < 3 or zones.zone_at(zones.zones[i]["center"]) != i:
			own = false
	_check(own, "every area's centre lies in its own area")
	# The map's borders are the game's: random spots fall inside the polygon of their area
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var matches := 0
	for k in 500:
		var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 44000.0
		var i := zones.zone_at(p)
		if Geometry2D.is_point_in_polygon(p, zones.zones[i]["outline"]):
			matches += 1
	_check(matches >= 495, "the uneven borders on the map match the game (%d/500 spots)" % matches)
	_check(zones.zone_name_at(Vector2.ZERO) == "The Sunhaven Isles", "Sunhaven lies in The Sunhaven Isles")
	# The borders are uneven: a straight border line would put these two spots in the same area
	var wavy := 0
	for z in zones.zones:
		for e in z["edges"]:
			var edge: PackedVector2Array = e
			var mid_bend := edge[edge.size() / 2].distance_to(edge[0].lerp(edge[edge.size() - 1], 0.5))
			if mid_bend > 100.0:
				wavy += 1
	_check(wavy > 10, "the borders wander instead of running straight (%d bent edges)" % wavy)
	var filled := zones.zones.filter(func(z: Dictionary) -> bool: return z["tint"] != z["polygon"]).size()
	print("     %d of %d areas are tinted with their uneven outline" % [filled, zones.zones.size()])

	# The name shows at the start
	await _frames(90)
	_check(banner.is_showing() and banner.shown_name() == "The Sunhaven Isles", "the start area's name is shown (%s)" % banner.shown_name())
	await _shot("z1_banner")

	# Sail into another area: its name shows once
	var target := 1
	var spot: Vector2 = zones.zones[target]["label_at"]
	_entered.clear()
	ship.place_at(spot, 0.0)
	await _frames(100)
	_check(_entered == [target], "sailing into %s shows its name once" % zones.zones[target]["name"])
	_check(banner.shown_name() == zones.zones[target]["name"], "the banner shows the new area's name")
	await _shot("z2_banner_new_area")
	# Wobbling across a border quickly does not flash names
	_entered.clear()
	for k in 4:
		ship.place_at(Vector2.ZERO, 0.0)
		await _frames(20) # 1/3 s – less than the settle time
		ship.place_at(spot, 0.0)
		await _frames(20)
	_check(_entered.is_empty(), "wobbling across a border doesn't flash names")

	# The map
	var pause := main.get_node("PauseMenu")
	pause.call("open", 0)
	await _frames(5)
	var map := pause.find_children("*", "MapView", true, false)[0] as MapView
	map.set("_pan", Vector2.ZERO)
	map.set("_zoom", 1.0)
	await _frames(5)
	await _shot("z3_map_world")
	map.set("_zoom", 3.0)
	await _frames(5)
	await _shot("z4_map_zoomed")
	pause.call("close")
	print("ZONE CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
