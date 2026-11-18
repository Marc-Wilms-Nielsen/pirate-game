extends Node
## Plays the whole main quest line, "The Sun King's Crown", from start to finish:
## accepts each quest in the chat window, fulfils the goal (items, delivery, bosses, treasure),
## hands it in, and checks marks, rewards and saving along the way. Takes screenshots of the
## chat window, the marks in the world and on the map, a boss, and all quest-giver portraits.
## Run: godot res://tests/quest_check.tscn   (exits with code 1 on any failure)

var main: Node
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.use_test_files() # never touch the real save or settings
	Game.delete_save()
	Game.reset()
	Homestead.reset()
	Quests.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(40)
	Game.user_zoom = 0.8
	var dialog := main.get_node("QuestDialog") as QuestDialog

	# Places picked from the world
	var harbors_used := {}
	for q in Catalog.QUESTS:
		var giver := Quests.giver_harbor(q)
		var turn_in := Quests.turn_in_harbor(q)
		var target: Variant = Quests.spots.get(q["id"] + ".target", null)
		print("     %-9s giver %-18s turn in %-18s target %s" % [q["id"], giver, turn_in, str(target)])
		_check(giver != "" and Quests.harbor_position(giver) != Vector2.INF, "%s: giver harbor found" % q["id"])
		_check(turn_in != "" and Quests.harbor_position(turn_in) != Vector2.INF, "%s: hand-in harbor found" % q["id"])
		if q["type"] == "boss":
			_check(target != null, "%s: boss spot found" % q["id"])
		harbors_used[giver] = true
	_check(Quests.marker_at("Sunhaven") == "!", "a yellow ! waits at the start harbor")
	_check(Quests.objective_text().begins_with("Talk to Old Maren"), "HUD goal: talk to Old Maren")
	await _shot("q01_world_mark")

	var gold_start := Game.gold
	for i in Catalog.QUESTS.size():
		var q: Dictionary = Quests.current()
		# 1. Dock at the giver and accept
		await _dock(Quests.giver_harbor(q))
		_check(dialog.is_open() and dialog.get("_talk")["mode"] == "offer", "%s: chat window offers the quest" % q["id"])
		if i == 0 or i == 6:
			await _frames(300) # let the text finish typing
			await _shot("q%02d_offer_%s" % [i + 2, q["id"]])
		if i == 0: # Declining first: the "!" stays and nothing starts
			dialog.call("_close", "decline")
			await _frames(3)
			_close_harbor()
			_check(Quests.state == "offer" and Quests.marker_at(Quests.giver_harbor(q)) == "!", "declining keeps the ! so you can come back")
			await _dock(Quests.giver_harbor(q))
		dialog.call("_close", "accept")
		await _frames(3)
		_close_harbor()
		_check(Quests.state == "active", "%s: accepted" % q["id"])
		_check(not Quests.is_ready() or q["type"] == "delivery", "%s: not done right away" % q["id"])
		# 2. Fulfil the goal
		match q["type"]:
			"gather":
				Game.cargo.clear() # boss loot piles up during the test; make room
				Game.boxes.clear()
				for id in q["items"]:
					Game.add_item(id, int(q["items"][id]))
			"boss":
				await _beat_boss(q)
		_check(Quests.is_ready(), "%s: goal met (%s)" % [q["id"], Quests.objective_text()])
		_check(Quests.marker_at(Quests.turn_in_harbor(q)) == "?", "%s: a ? shows where to hand it in" % q["id"])
		if i == 2:
			await _open_map("q05_map_marks")
			# Saving and loading in the middle of the line keeps the progress
			Game.save_game()
			var before := [Quests.index, Quests.state, Quests.boss_down, Quests.spots.size()]
			Quests.reset()
			Game.load_game()
			_check([Quests.index, Quests.state, Quests.boss_down, Quests.spots.size()] == before, "quest progress survives save and load")
		# 3. Hand it in
		var gold_before := Game.gold
		await _dock(Quests.turn_in_harbor(q))
		_check(dialog.is_open() and dialog.get("_talk")["mode"] == "turn_in", "%s: chat window to hand in" % q["id"])
		if i == 0 or i == 9:
			await _frames(300)
			await _shot("q%02d_turn_in_%s" % [i + 10, q["id"]])
		dialog.call("_close", "turn_in")
		await _frames(3)
		# Handing in may chain into the next offer at the same harbor: leave that for the next loop
		if dialog.is_open():
			dialog.call("_close", "decline")
			await _frames(3)
		_close_harbor()
		_check(Game.gold - gold_before >= int(q["reward"]["gold"]), "%s: reward paid (+%d)" % [q["id"], Game.gold - gold_before])
		if q["type"] == "gather":
			for id in q["items"]:
				_check(Game.cargo_count(id) == 0, "%s: the %s were handed over" % [q["id"], Game.item_name(id)])
	_check(Quests.finished(), "the whole quest line is finished")
	_check(Game.cargo_count("sun_crown") == 1, "you carry the Crown of the Sun King")
	print("     gold earned on the quest line: %d" % (Game.gold - gold_start))
	await _portraits()
	print("QUEST CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _beat_boss(q: Dictionary) -> void:
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var target: Vector2 = Quests.spots[q["id"] + ".target"]
	# Sail close to the spot and wait for the boss to appear
	ship.place_at(target + Vector2(0, 500), 0.0)
	var boss: Node2D = null
	for i in 120:
		await get_tree().process_frame
		boss = (main.get_node("QuestWorld") as QuestWorld).current_boss()
		if is_instance_valid(boss):
			break
	_check(is_instance_valid(boss), "%s: the boss appears near its spot" % q["id"])
	if not is_instance_valid(boss):
		return
	if q["id"] == "gull" or q["id"] == "jungle":
		Game.user_zoom = 1.6 if q["id"] == "jungle" else 1.0
		ship.place_at(boss.global_position + Vector2(-140, 60), 0.0)
		await _frames(20)
		await _shot("q04_boss_%s" % q["id"] if q["id"] == "gull" else "q09_boss_%s" % q["id"])
		Game.user_zoom = 0.8
	if boss is EnemyShip:
		_check((boss as EnemyShip).stats["max_hp"] > Game.ship_stats((boss as EnemyShip).config)["max_hp"], "%s: boss ship is tougher than normal" % q["id"])
	else:
		_check((boss as Creature).max_hp >= 200.0, "%s: boss has lots of health (%d)" % [q["id"], int((boss as Creature).max_hp)])
	boss.call("take_damage", 99999.0, boss.global_position + Vector2(10, 0))
	await _frames(10)
	_check(Quests.boss_down, "%s: beating the boss counts" % q["id"])
	if q.get("treasure", false):
		_check(not Quests.is_ready(), "crown: after the boss, the treasure must be dug up")
		var dig: Vector2 = Quests.spots[q["id"] + ".dig"]
		ship.place_at(dig + Vector2(0, 600), 0.0)
		var chest: Chest = null
		for i in 120:
			await get_tree().process_frame
			chest = main.get_node("QuestWorld").get("_treasure")
			if is_instance_valid(chest):
				break
		_check(is_instance_valid(chest), "crown: the treasure chest appears on the island")
		if is_instance_valid(chest):
			_check(Game.is_land(chest.global_position), "crown: the treasure is on land")
			for k in 40: Game.add_item("stone", 1) # a full hold must not cost you the crown
			chest.open()
			await _frames(5)
		_check(Quests.treasure_found, "crown: treasure dug up")


func _dock(harbor_name: String) -> void:
	var h: Harbor = null
	for node in get_tree().get_nodes_in_group("harbors"):
		if (node as Harbor).harbor_name == harbor_name:
			h = node
	main.call("_on_dock_requested", h)
	await _frames(4)
	var dialog := main.get_node("QuestDialog") as QuestDialog
	if dialog.is_open():
		var r := (dialog.get("_panel") as Control).get_global_rect()
		_check(Rect2(0, 0, 640, 360).encloses(r), "chat window fits on screen (%d x %d at y %d)" % [int(r.size.x), int(r.size.y), int(r.position.y)])


func _close_harbor() -> void:
	var hm := main.get_node("HarborMenu")
	if hm.visible:
		hm.call("close")


func _open_map(shot_name: String) -> void:
	var pause := main.get_node("PauseMenu")
	pause.call("open", 0)
	await _frames(5)
	await _shot(shot_name)
	pause.call("close")
	await _frames(3)


func _portraits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.size = Vector2(640, 360)
	layer.add_child(bg)
	var x := 10.0
	for id in Catalog.QUEST_PEOPLE:
		var p := Portrait.new()
		p.look = Catalog.QUEST_PEOPLE[id]["look"]
		p.position = Vector2(x, 120)
		p.size = Vector2(96, 96)
		layer.add_child(p)
		var l := UiTheme.label(Catalog.QUEST_PEOPLE[id]["name"], 9, UiTheme.ACCENT)
		l.position = Vector2(x, 222)
		layer.add_child(l)
		x += 104.0
	await _frames(5)
	await _shot("q20_portraits")
	layer.queue_free()


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
