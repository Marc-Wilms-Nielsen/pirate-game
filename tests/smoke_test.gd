extends Node
## Automatisk røgtest: starter spillet og prøver alle systemer igennem.
## Kør: godot res://tests/smoke_test.tscn  (screenshots gemmes i user://test_shots/)

var main: Node
var shots_dir := "user://test_shots"
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(shots_dir)
	Game.delete_save()
	Game.reset()
	Homestead.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(30)
	await _run()
	print("SMOKE TEST DONE. Failures: ", failures.size())
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit()


func _check(cond: bool, text: String) -> void:
	if not cond:
		failures.append(text)
	print(("OK   " if cond else "FAIL ") + text)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [shots_dir, name])


## Trykker på hver knap én gang (listen hentes på ny efter hvert tryk, da menuen genopbygges).
func _press_first_button(node: Node, starts_with: String) -> void:
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(starts_with) and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return


func _ship_view(pos: Vector2, zoom: float) -> void:
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	ship.place_at(pos + Vector2(120, 0), PI)
	Game.user_zoom = zoom


func _press_all_buttons(node: Node) -> int:
	var count := 0
	for i in 60:
		var buttons := node.find_children("*", "Button", true, false)
		if i >= buttons.size():
			break
		var b := buttons[i] as Button
		if not b.disabled:
			b.pressed.emit()
			count += 1
			await _frames(1)
	return count


func _count_balls() -> int:
	var n := 0
	for c in Game.world_root.get_children():
		if c is Cannonball:
			n += 1
	return n


## Et punkt på åbent, dybt hav (uden for alle laguner).
func _deep_spot() -> Vector2:
	for i in 400:
		var p := Vector2.from_angle(i * 2.4) * (2000.0 + i * 25.0)
		if Game.water_depth(p) >= 1.0 and Game.water_depth(p + Vector2(0, -400)) >= 1.0:
			return p
	return Vector2(-3000, 3000)


func _run() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	_check(get_tree().get_nodes_in_group("islands").size() >= 10, "mindst 10 øer")
	_check(get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind != "home").size() == 39, "39 havne fordelt på 5 fraktioner + hjemø")
	_check(get_tree().get_nodes_in_group("islands").size() >= 250 and get_tree().get_nodes_in_group("villages").size() >= 30, "10x verden: 250+ øer og 30+ fiskerlandsbyer")
	_check(get_tree().get_nodes_in_group("resources").size() > 10, "træer, klipper og urter på øerne")
	_check(get_tree().get_nodes_in_group("chests").size() > 3, "kister spawnet")
	var streamer := main.get_node("Streamer") as WorldStreamer
	var far_island: Island = null
	for isl in get_tree().get_nodes_in_group("islands"):
		if (isl as Island).global_position.distance_to(ship.global_position) > 15000.0:
			far_island = isl
			break
	_check(streamer.awake_count() > 0 and far_island != null and far_island.process_mode == Node.PROCESS_MODE_DISABLED and not far_island.visible, "øer langt væk sover (streaming)")
	_check(get_tree().get_nodes_in_group("creatures").size() > 5, "dyr spawnet (kun øerne tæt på bygges med det samme)")
	await _shot("01_start_harbor")

	# Sejl lidt
	ship.sail_level = 2
	await _frames(120)
	await _shot("02_sailing")

	# Havnemenu – alle faner, tryk på alle knapper med masser af guld
	Game.gold = 50000
	Game.add_item("stolen_cargo", 3)
	Game.add_item("rum", 4)
	var harbor := get_tree().get_first_node_in_group("harbors") as Harbor
	main.call("_on_dock_requested", harbor)
	await _frames(5)
	var menu := main.get_node("HarborMenu")
	_check(menu.visible, "havnemenu åbner")
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for t in tabs.get_tab_count():
		tabs.current_tab = t
		await _frames(3)
		await _shot("03_harbor_tab_%d" % t)
		var pressed: int = await _press_all_buttons(tabs.get_tab_control(t))
		await _frames(3)
		print("     tab %d: trykkede %d knapper" % [t, pressed])
	await _shot("04_harbor_after")
	_check(Game.owned_ships.size() >= 2, "købte skib(e)")
	menu.call("close")
	await _frames(10)
	_check(not get_tree().paused, "spillet kører igen efter havn")
	print("     aktivt skib: ", Game.active_ship()["name"], " kanoner: ", Game.active_ship()["cannons"])

	# Pausemenu og kort
	var pause := main.get_node("PauseMenu")
	pause.call("open", 0)
	await _frames(5)
	await _shot("05_map")
	for t in 6:
		pause.get("_tabs").current_tab = t
		await _frames(3)
	await _shot("06_pause_last")
	pause.call("close")
	await _frames(5)

	# Kamp: placér en pirat ved siden af skibet og skyd
	var enemy := EnemyShip.new()
	enemy.setup("pirate", "brig")
	enemy.global_position = ship.global_position + Vector2.DOWN.rotated(ship.rotation) * 200.0
	enemy.rotation = ship.rotation
	Game.world_root.add_child(enemy)
	await _frames(20)
	Game.cannonballs = 100
	ship.fire("right")
	ship.fire("left")
	await _frames(25)
	await _shot("07_cannons")
	await _frames(60)
	var hp_before := enemy.hp
	enemy.take_damage(9999.0, ship.global_position)
	await _frames(10)
	await _shot("08_enemy_sinking")
	await _frames(200)
	_check(not is_instance_valid(enemy), "fjendeskib sank og forsvandt")
	_check(get_tree().get_nodes_in_group("floating_loot").size() > 0, "vraggods flyder")
	print("     fjende-hp før: ", hp_before)

	# Saml vraggods op ved at flytte skibet hen over det
	var loot := get_tree().get_first_node_in_group("floating_loot") as Node2D
	var gold_before := Game.gold
	ship.global_position = loot.global_position
	await _frames(10)
	_check(Game.gold >= gold_before, "vraggods samlet op")

	# Til fods på en ø: find en ø uden havn, sæt skibet ved stranden og hop i land
	var island: Island
	for n in get_tree().get_nodes_in_group("islands"):
		if (n as Island).harbor_name == "":
			island = n
			break
	ship.place_at(island.global_position + Vector2.RIGHT * island.shore_radius(0.0) * 1.3, PI)
	await _frames(5)
	main.call("_on_disembark_requested")
	await _frames(5)
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	_check(player != null, "kaptajn hopper i vandet")
	player.global_position = island.global_position + Vector2.RIGHT * island.shore_radius(0.0) * 0.8
	await _frames(10)
	_check(player.on_land, "kaptajn står på land")
	# Åbn en kiste på øen
	var chest: Chest
	for c in get_tree().get_nodes_in_group("chests"):
		if (c as Chest).global_position.distance_to(island.global_position) < island.radius * 1.2:
			chest = c
			break
	if chest:
		player.global_position = chest.global_position + Vector2(8, 0)
		await _frames(5)
		_check(player.nearby_chest() == chest, "kiste i nærheden")
		chest.open()
		await _frames(5)
		_check(chest.opened, "kiste åbnet")
		await _shot("09_chest")
	# Slå et dyr
	var creature: Creature
	for c in get_tree().get_nodes_in_group("creatures"):
		if (c as Creature).home == island:
			creature = c
			break
	if creature:
		player.global_position = creature.global_position - Vector2(10, 0)
		player.set("_facing", Vector2.RIGHT)
		player.died.connect(func() -> void: print("     (kaptajn døde, hp=", player.hp, ")"))
		for i in 6:
			if not is_instance_valid(player):
				print("     kaptajn forsvandt i runde ", i)
				break
			print("     runde %d: kaptajn hp=%d, dyr=%s" % [i, player.hp, creature.get_class() if is_instance_valid(creature) else "væk"])
			player.call("_attack")
			await _frames(30)
		await _shot("10_fight")
		_check(not is_instance_valid(creature) or creature.hp < creature.max_hp, "dyr tog skade")
	# Våben: pistol-kugle, granat, brandbombe, giftbombe og blændgranat mod dyr
	var targets: Array[Creature] = []
	for c in get_tree().get_nodes_in_group("creatures"):
		if (c as Creature).home == island and is_instance_valid(c):
			targets.append(c)
	if targets.size() >= 2:
		var t1 := targets[0]
		t1.max_hp = 999.0
		t1.hp = 999.0
		var hp0 := t1.hp
		var b := Bullet.new()
		b.global_position = t1.global_position - Vector2(40, 0)
		b.direction = Vector2.RIGHT
		b.damage = 14.0
		b.max_distance = 100.0
		Game.world_root.add_child(b)
		await _frames(20)
		_check(t1.hp < hp0, "pistolkugle rammer dyr")
		if is_instance_valid(player):
			player.global_position = t1.global_position + Vector2(0, 160) # uden for sprængningen
		for kind in ["grenade", "firebomb", "poison", "flash"]:
			hp0 = t1.hp
			var g := Grenade.new()
			var target_pos := t1.global_position
			g.weapon_id = kind
			g.start = t1.global_position - Vector2(60, 0)
			g.target = t1.global_position
			Game.world_root.add_child(g)
			await get_tree().create_timer(Grenade.FLIGHT_TIME + 0.6).timeout
			if kind == "flash":
				print("     flash: afstand dyr-mål %.1f, stun %.2f, klasse %s" % [t1.global_position.distance_to(target_pos), t1._stun, t1.get_script().get_global_name()])
				_check(t1._stun > 0.0, "blændgranat lammer dyr")
			else:
				_check(t1.hp < hp0, "%s skader dyr" % kind)
			if kind == "firebomb":
				await _shot("09b_firebomb")
			if kind == "poison":
				await _shot("09c_poison")
		if is_instance_valid(player):
			player.global_position = t1.global_position - Vector2(30, 10)
		Game.selected_weapon = "pistol"
		Game.changed.emit()
		await _frames(5)
		await _shot("09d_weapon_bar")
	# Skyd ikke mens man svømmer
	var shot_before := Game.shot
	if is_instance_valid(player):
		player.global_position = island.global_position + Vector2.RIGHT * island.shore_radius(0.0) * 1.3
		await _frames(5)
		player.call("_shoot", "pistol", Catalog.WEAPONS["pistol"])
		_check(Game.shot == shot_before, "kan ikke skyde mens man svømmer")

	# Kaptajnen dør -> tilbage på skibet
	player = get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player:
		player.take_damage(999.0, player.global_position)
	await _frames(10)
	_check(get_tree().get_first_node_in_group("player_character") == null, "kaptajn tilbage på skibet efter død")

	# Skibet synker -> vågner i havnen
	ship.take_damage(99999.0, ship.global_position)
	await _frames(200)
	_check(ship.controlled and Game.active_ship()["hp"] > 0, "vågner i havn efter forlis")
	await _shot("11_respawn")

	# Pirat-AI: læg en pirat 380 px væk (på dybt vand) og se om den angriber af sig selv
	ship.place_at(_deep_spot(), 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var pirate := EnemyShip.new()
	pirate.setup("pirate", "sloop")
	pirate.global_position = ship.global_position + Vector2(0, -380)
	pirate.rotation = 0.0
	Game.world_root.add_child(pirate)
	var hp_start: float = Game.active_ship()["hp"]
	var max_frames := 1800
	for i in max_frames:
		await get_tree().process_frame
		if Game.active_ship()["hp"] < hp_start:
			print("     piraten ramte efter %d frames (state=%s)" % [i, pirate.state])
			break
	await _shot("11b_pirate_attack")
	_check(Game.active_ship()["hp"] < hp_start, "pirat angriber og rammer spilleren")
	if is_instance_valid(pirate):
		pirate.queue_free()
	Game.active_ship()["hp"] = Game.ship_stats(Game.active_ship())["max_hp"]

	# Entring: læg et handelsskib op ad os og entr
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	Game.crew = Game.max_crew()
	var merchant := EnemyShip.new()
	merchant.setup("merchant", "fluyt")
	merchant.global_position = ship.global_position + Vector2.DOWN.rotated(ship.rotation) * 30.0
	merchant.rotation = ship.rotation
	Game.world_root.add_child(merchant)
	await _frames(3)
	_check(ship.boardable_enemy() == merchant, "kan entre skib vi ligger op ad")
	await _shot("13_board_prompt")
	main.call("_on_boarding_requested", merchant)
	await _frames(5)
	var boarding := main.get_node("BoardingMenu")
	_check(boarding.visible and get_tree().paused, "entringsmenu åbner og pauser")
	await _shot("14_boarding_start")
	boarding.call("_fight_to_end")
	await _frames(3)
	await _shot("15_boarding_end")
	var owned_before := Game.owned_ships.size()
	if boarding.get("_their_crew") <= 0:
		boarding.call("_take_prize")
		await _frames(5)
		_check(Game.owned_ships.size() == owned_before + 1, "erobret skib tilføjet til flåden")
	else:
		boarding.call("close")
		print("     tabte entringen (det kan ske)")
	_check(not get_tree().paused, "spillet kører efter entring")
	# Slæb: vind en entring og tag skibet på slæb
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	Game.crew = Game.max_crew()
	var victim := EnemyShip.new()
	victim.setup("merchant", "dhow")
	victim.crew = 1
	victim.global_position = ship.global_position + Vector2.DOWN.rotated(ship.rotation) * 30.0
	Game.world_root.add_child(victim)
	await _frames(3)
	main.call("_on_boarding_requested", victim)
	await _frames(3)
	boarding.call("_fight_to_end")
	var towed_before := Game.towed.size()
	_check(Game.free_tow_slots() > 0, "har ledig slæbeplads")
	boarding.call("_take_in_tow")
	await _frames(30)
	_check(Game.towed.size() == towed_before + 1, "skib taget på slæb")
	ship.sail_level = 2
	await _frames(120)
	ship.sail_level = 0
	await _shot("15b_towing")
	var price := Game.towed_sell_price(Game.towed[0])
	_check(price > 0, "slæbt skib har salgspris (%d)" % price)

	# Kanonskud dræber besætning, og besætningen vises tæt på
	var target_ship := EnemyShip.new()
	target_ship.setup("pirate", "brig")
	target_ship.global_position = ship.global_position + Vector2(250, 0)
	Game.world_root.add_child(target_ship)
	await _frames(3)
	var crew_before := target_ship.crew
	target_ship.take_damage(40.0, ship.global_position)
	_check(target_ship.crew < crew_before, "kanonskud dræber besætning (%d -> %d)" % [crew_before, target_ship.crew])
	await _shot("15c_crew_label")

	# Pirater entrer dig
	Game.pirate_boarding.emit(target_ship)
	await _frames(5)
	_check(boarding.visible and boarding.get("defending"), "pirater kan entre spilleren")
	await _shot("15d_defending")
	boarding.call("_retreat")
	await _frames(3)
	target_ship.queue_free()

	# Gem og indlæs
	Game.gold = 2345678
	Game.save_game()
	Game.gold = 1
	Game.load_game()
	_check(Game.gold == 2345678, "gem og indlæs virker")

	# Statistisk tjek: flere folk = bedre chance
	var bm: Script = load("res://scenes/ui/boarding_menu.gd")
	var weak: float = bm.win_chance(5, 15, 1.15)
	var strong: float = bm.win_chance(30, 15, 1.15)
	print("     chance 5 mod 15 pirater: %d %%   30 mod 15: %d %%" % [roundi(weak * 100), roundi(strong * 100)])
	_check(strong > weak + 0.4, "besætningsstørrelse afgør entringschancen")

	# --- Hjemøen -------------------------------------------------------------
	var home: Harbor
	for h in get_tree().get_nodes_in_group("harbors"):
		if (h as Harbor).kind == "home":
			home = h
	_check(home != null, "hjemø findes")
	Game.gold = 20000
	main.call("_on_dock_requested", home)
	await _frames(5)
	var home_menu := main.get_node("HomeMenu")
	_check(home_menu.visible, "hjemmenu åbner ved molen")
	await _shot("18a_home_for_sale")
	_press_first_button(home_menu, "Buy the island")
	await _frames(3)
	_check(Homestead.claimed, "øen er købt")
	Homestead.upgrade_building("workshop")
	Homestead.upgrade_building("workshop")
	Homestead.upgrade_building("chickens")
	Homestead.upgrade_building("lumber")
	Homestead.upgrade_building("fields")
	_check(Homestead.plots.size() == Catalog.START_PLOTS + 2, "flere marker efter udvidelse")
	_check(Homestead.plant(0, "wheat"), "så hvede")
	Homestead.plant(1, "hemp")
	Homestead.plant(2, "tobacco")
	# Byggefelt: alt har fået et felt, og en ny bygning kan sættes på et valgt felt
	_check(Homestead.valid_cells.size() >= 40, "hjemøen har et stort byggefelt (%d felter)" % Homestead.valid_cells.size())
	_check(Homestead.building_cell("workshop") != "" and Homestead.building_cell("chickens") != "", "bygninger står på byggefeltet")
	var free_cell: Vector2i = Homestead.valid_cells.filter(func(c): return Homestead.is_free(c))[0]
	_check(Homestead.build_at("quarry", free_cell) and Homestead.building_cell("quarry") == Homestead.key(free_cell), "byg på et valgt felt")
	var free2: Vector2i = Homestead.valid_cells.filter(func(c): return Homestead.is_free(c))[0]
	_check(Homestead.move(Homestead.building_cell("quarry"), free2), "flyt en bygning")
	# Arbejdere: uden arbejdere ingen produktion
	Homestead.last_update -= 3600.0
	var idle := Homestead.update_production()
	_check(idle.get("wood", 0) == 0, "ingen produktion uden arbejdere")
	Homestead.upgrade_building("cottage")
	for i in 3:
		Homestead.hire_worker()
	_check(Homestead.workers == 3 and Homestead.working("chickens") == 1 and Homestead.working("lumber") == 1, "arbejdere ansat og sat i arbejde")
	Homestead.add_to_storage("food", 20)
	# Lad som om der er gået 2 timer (som hvis spillet havde været lukket)
	Homestead.plots[0]["planted"] -= 7200.0
	Homestead.last_update -= 7200.0
	var food_before := int(Homestead.storage.get("food", 0))
	var produced := Homestead.update_production()
	_check(produced.get("food", 0) >= 15 and produced.get("wood", 0) >= 10, "bygninger producerer mens man er væk (%s)" % str(produced))
	_check(float(Homestead.last_report.get("eaten", 0.0)) >= 11.0, "arbejderne spiser mad fra lageret (%.1f)" % float(Homestead.last_report.get("eaten", 0.0)))
	# Uden mad går det langsommere
	Homestead.storage.erase("food")
	Homestead.assign("chickens", -1)
	Homestead.last_update -= 7200.0
	var hungry := Homestead.update_production()
	_check(float(Homestead.last_report.get("hungry_hours", 0.0)) > 1.0, "sultne arbejdere (%.1f t)" % float(Homestead.last_report.get("hungry_hours", 0.0)))
	print("     med mad: %s  uden mad: %s  (mad før %d)" % [str(produced), str(hungry), food_before])
	Homestead.assign("chickens", 1)
	Homestead.harvest(0)
	_check(Homestead.storage.get("wheat", 0) >= 6, "høst lander på lageret")
	Homestead.add_to_storage("iron_ore", 10)
	Homestead.add_to_storage("stone", 10)
	Homestead.add_to_storage("snake_skin", 5)
	Homestead.add_to_storage("hemp", 5)
	var balls_before := Game.cannonballs
	Homestead.craft(Catalog.RECIPES[0])
	_check(Game.cannonballs == balls_before + 20, "værksted laver kanonkugler")
	for r in Catalog.RECIPES:
		if r.get("gear", "") == "leather":
			Homestead.craft(r)
	_check(Game.owned_gear.get("leather", false), "værksted smeder udstyr (læderfrakke)")
	var tabs3 := home_menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for t in tabs3.get_tab_count():
		tabs3.current_tab = t
		await _frames(3)
		await _shot("18b_home_tab_%d" % t)
	home_menu.call("close")
	await _frames(5)
	_ship_view(home.global_position, 0.6)
	await _frames(60)
	await _shot("18c_home_island")

	# --- Indsamling og fiskeri --------------------------------------------------
	main.call("_on_disembark_requested")
	await _frames(5)
	var captain := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	var tree_node: ResourceNode
	for n in get_tree().get_nodes_in_group("resources"):
		if (n as ResourceNode).kind == "tree":
			tree_node = n
			break
	captain.global_position = tree_node.global_position + Vector2(10, 0)
	captain.set("_curr_pos", captain.global_position)
	await _frames(3)
	var wood_before := Game.cargo_count("wood")
	captain.call("_start_gathering", tree_node)
	await get_tree().create_timer(1.6).timeout
	_check(Game.cargo_count("wood") > wood_before or Game.cargo_used() >= Game.cargo_capacity(), "fælder træ (træ i lastrummet)")
	await _shot("18d_gathering")
	# Udstyr på
	Game.owned_gear["captain_hat"] = true
	Game.owned_gear["admiral"] = true
	Game.owned_gear["gold_sabre"] = true
	Game.equip("captain_hat")
	Game.equip("admiral")
	Game.equip("gold_sabre")
	_check(Game.gear_stat("armor") > 0.25 and Game.gear_stat("luck") > 0.1, "udstyr giver stats")
	await _frames(5)
	await _shot("18e_gear")
	# Piratlejr: banditterne angriber, og kan nedkæmpes
	var camp := get_tree().get_first_node_in_group("camps") as Camp
	_check(camp != null and get_tree().get_nodes_in_group("camps").size() >= 3, "piratlejre findes")
	captain.hp = PlayerCharacter.MAX_HP
	captain.global_position = camp.global_position + Vector2(40, 30)
	captain.set("_curr_pos", captain.global_position)
	captain.set("_prev_pos", captain.global_position)
	var hp_start2 := captain.hp
	await get_tree().create_timer(3.0).timeout
	await _shot("19_camp_fight")
	_check(captain.hp < hp_start2, "banditter angriber kaptajnen (liv %d -> %d)" % [hp_start2, captain.hp])
	var band := camp.bandits()
	_check(band.size() >= 2, "lejren har banditter (%d)" % band.size())
	for b in band:
		(b as Bandit).take_damage(999.0, captain.global_position)
	await _frames(40)
	_check(camp.bandits().is_empty(), "banditterne kan nedkæmpes")
	if is_instance_valid(captain): # (store dyr i nærheden kan have nået at slå ham ned)
		captain.hp = PlayerCharacter.MAX_HP
		main.call("_on_board_requested")
	await _frames(5)
	# Fisk fra skibet
	var shoal := FishShoal.new()
	shoal.global_position = ship.global_position + Vector2(40, 0)
	Game.world_root.add_child(shoal)
	ship.speed = 0.0
	await _frames(3)
	_check(ship.nearby_shoal() == shoal, "skib kan fiske ved fiskestime")
	shoal.interact(ship)
	shoal.state = "bite"
	var fish_before := Game.cargo_count("fish")
	shoal.interact(ship)
	_check(Game.cargo_count("fish") > fish_before or Game.cargo_used() >= Game.cargo_capacity(), "fanger fisk")
	# Reparationssæt
	Game.active_ship()["hp"] = 10.0
	Game.repair_kits = 1
	ship.use_repair_kit()
	_check(Game.active_ship()["hp"] > 10.0 and Game.repair_kits == 0, "reparationssæt virker")

	# Indstillinger: vandkvalitet og lyd
	Settings.set_value("water_quality", 0)
	await _frames(5)
	await _shot("16a_water_low")
	Settings.set_value("water_quality", 1)
	await _frames(5)
	await _shot("16b_water_medium")
	Settings.set_value("water_quality", 2)
	Settings.set_value("sfx_volume", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.5)) < 0.01, "lydstyrke på SFX-kanal")
	Settings.reset_to_defaults()
	var pause2 := main.get_node("PauseMenu")
	pause2.call("open", 4)
	await _frames(5)
	await _shot("16c_settings")
	pause2.call("close")

	# Zoom langt ud
	Game.user_zoom = ZoomCamera.MIN_USER_ZOOM
	await _frames(90)
	await _shot("16_zoomed_out")
	Game.user_zoom = 1.0

	# Fastland
	var mainland: Island
	for n in get_tree().get_nodes_in_group("islands"):
		if (n as Island).coast_detail > 0.0:
			mainland = n
			break
	_check(mainland != null, "fastland findes")
	if mainland:
		print("     fastland radius: %d, lagune: %.1f" % [mainland.radius, mainland.lagoon_size])
		ship.place_at(mainland.global_position + Vector2.RIGHT * mainland.shore_radius(0.0) * 1.15, PI)
		Game.user_zoom = 0.35
		await _frames(90)
		await _shot("17_mainland")
		Game.user_zoom = 1.0
	_check(Catalog.SHIPS.size() >= 15, "mindst 15 skibstyper")

	# Lad havet leve lidt (spawner fjender, hajer, tønder)
	main.set("_elapsed", 100.0)
	ship.sail_level = 2
	await _frames(400)
	print("     fjender: %d  hajer: %d  tønder: %d" % [
		get_tree().get_nodes_in_group("enemies").size(),
		get_tree().get_nodes_in_group("sharks").size(),
		get_tree().get_nodes_in_group("floating_loot").size()])
	_check(get_tree().get_nodes_in_group("enemies").size() > 0, "fjendeskibe spawner")
	await _shot("12_open_sea")
	await _test_new_world(ship)
	await _test_fleet(ship)


## Kanoner, ankersving, venskab med havne, kasser, kaptajner og eskorteskibe.
func _test_fleet(ship: PlayerShip) -> void:
	_check(int(Catalog.SHIPS["dinghy"]["max_cannons"]) == 3 and int(Catalog.SHIPS["sloop"]["max_cannons"]) == 4, "+2 kanonpladser på skibene")
	# Ankersving: kast ankeret i fart og styr
	var spot := _deep_spot()
	ship.place_at(spot, 0.0)
	ship.set_controlled(true)
	await _frames(20) # lad verdenen omkring det nye sted blive bygget først
	ship.speed = float(ship.stats["speed"])
	ship.anchored = true
	var rot_before := ship.rotation
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	var turned := absf(angle_difference(rot_before, ship.rotation))
	print("     ankersving: drejede %.2f rad på 40 frames" % turned)
	_check(turned > 0.8, "ankersving: skibet kan styres og svinger hurtigt, mens ankeret kastes")
	ship.anchored = false

	# Venskab og kasser
	var harbor := get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind == "trade")[0] as Harbor
	var price0 := Game.price_at(harbor.harbor_name, harbor.kind, "silk", false)
	Game.add_harbor_rep(harbor.harbor_name, 10000.0)
	_check(Game.harbor_level(harbor.harbor_name) == 3, "venskab stiger med salg (niveau %d)" % Game.harbor_level(harbor.harbor_name))
	_check(Game.price_at(harbor.harbor_name, harbor.kind, "silk", false) > price0, "bedre salgspris som god ven")
	var faction := Game.faction_of(harbor.harbor_name)
	var sister: Array = get_tree().get_nodes_in_group("harbors").filter(func(h): return h != harbor and (h as Harbor).kind != "home" and Game.faction_of((h as Harbor).harbor_name) == faction)
	var other: Array = get_tree().get_nodes_in_group("harbors").filter(func(h): return (h as Harbor).kind != "home" and Game.faction_of((h as Harbor).harbor_name) != faction)
	_check(not sister.is_empty() and Game.harbor_level((sister[0] as Harbor).harbor_name) == 3 and Game.harbor_level((other[0] as Harbor).harbor_name) < 3,
		"omdømme deles af alle fraktionens havne (%s)" % faction)
	var crate: Dictionary = Catalog.CRATES[0]
	var balls := Game.cannonballs
	Game.gold = 100000
	_check(Game.buy_crate(harbor.harbor_name, harbor.kind, crate) and Game.cannonballs == balls + 50, "forsyningskasse giver mange ting på én gang")
	var menu := main.get_node("HarborMenu")
	menu.call("open", harbor)
	await _frames(5)
	await _shot("30_friendship")
	# Kaptajner
	Game.owned_ships.append(Game.new_ship_config("brig"))
	Game.owned_ships.append(Game.new_ship_config("schooner"))
	Game.captain_slots = 2
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Captains":
			tabs.current_tab = i
	await _frames(5)
	var cands: Array = menu.get("_candidates")
	_check(Game.hire_captain(cands[0]) and Game.hire_captain(cands[1]), "ansæt to kaptajner")
	_check(not Game.hire_captain(Game.random_captain_candidate()), "kan ikke ansætte flere end pladserne")
	var c1 := int(Game.captains[0]["id"])
	var c2 := int(Game.captains[1]["id"])
	Game.assign_captain(c1, Game.owned_ships.size() - 2)
	Game.assign_captain(c2, Game.owned_ships.size() - 1)
	Game.upgrade_captain(c1, "gunnery")
	_check(int(Game.captain_by_id(c1)["gunnery"]) >= 1, "kaptajnens evner kan opgraderes")
	await _frames(5)
	await _shot("31_captains")
	menu.call("close")
	await _frames(10)
	var escorts := get_tree().get_nodes_in_group("escorts")
	_check(escorts.size() == 2, "2 eskorteskibe sejler med (fandt %d)" % escorts.size())
	ship.place_at(spot, 0.0)
	ship.sail_level = 2
	await _frames(240)
	var close_count := escorts.filter(func(e): return (e as Node2D).global_position.distance_to(ship.global_position) < 400.0).size()
	_check(close_count == 2, "eskorterne følger dit skib i formation")
	await _shot("32_escort_formation")
	# Pirat i nærheden: eskorterne angriber
	ship.sail_level = 0
	var pirate := EnemyShip.new()
	pirate.setup("pirate", "brigantine")
	pirate.global_position = ship.global_position + Vector2(260, -200)
	pirate.state = "attack"
	Game.world_root.add_child(pirate)
	var hp0 := pirate.hp
	var fighting := false
	for i in 900:
		await get_tree().process_frame
		if escorts.any(func(e): return (e as EscortShip).state == "fight"):
			fighting = true
		if pirate.hp < hp0:
			break
	_check(fighting, "eskorterne går til angreb på piraten")
	_check(pirate.hp < hp0, "eskorterne rammer piraten")
	await _shot("33_escort_fight")
	if is_instance_valid(pirate):
		pirate.queue_free()
	# Eskorterne samler vraggods op
	var esc := escorts[0] as EscortShip
	var barrel := FloatingLoot.new()
	barrel.global_position = esc.global_position + Vector2.from_angle(esc.rotation) * 120.0
	Game.world_root.add_child(barrel)
	var picked := false
	for i in 600:
		await get_tree().process_frame
		if not is_instance_valid(barrel) or barrel.is_queued_for_deletion():
			picked = true
			break
	_check(picked, "kaptajnen samler vraggods op")
	# Folk på eskorteskibene går med i duellen mod et kongerige
	Game.crew = 10
	Game.move_crew_to_escort(escorts[0].config, 5)
	Game.hire_escort_crew(escorts[1].config, 6)
	_check(Game.escort_crew_total() == 11 and Game.crew == 5, "folk på eskorteskibene (%d)" % Game.escort_crew_total())
	var castle := get_tree().get_nodes_in_group("castles")[1] as Castle
	Game.kingdom_ready_at.erase(castle.kingdom()["id"])
	var duel := main.get_node("DuelMenu")
	duel.call("open", castle)
	_check(int(duel.get("_ours")) == 16, "eskorternes folk kæmper med i duellen (%d)" % int(duel.get("_ours")))
	duel.call("_surrender")
	await _frames(3)
	_check(Game.crew + Game.escort_crew_total() >= 14, "de overlevende fordeles tilbage på skibene")
	# Bredside: kanonerne går af én efter én
	ship.place_at(_deep_spot(), 0.0)
	Game.cannonballs = 50
	Game.active_ship()["cannons"] = 3
	ship.refresh_from_config()
	ship.reload_left["left"] = 0.0
	var t0 := Time.get_ticks_msec()
	ship.fire("left")
	var times: Array[int] = []
	var last := 0
	while Time.get_ticks_msec() - t0 < 1500:
		await get_tree().process_frame
		var n := _count_balls()
		if n > last:
			for k in n - last:
				times.append(Time.get_ticks_msec() - t0)
			last = n
	print("     bredside: kugler affyret efter %s ms" % str(times))
	_check(times.size() == 3 and times[0] >= 100 and times[-1] - times[0] >= 80, "kanonerne går af én efter én med forsinkelse")
	await _shot("34_broadside")
	_check(get_tree().get_nodes_in_group("seabed").size() == 1 and (get_tree().get_first_node_in_group("seabed") as Node).get_child_count() > 20, "havbund med sten og vrag under det åbne hav")
	_check(get_tree().get_nodes_in_group("seabed").size() == 1 and Game.world_root.get_children().any(func(n: Node) -> bool: return n is SmokeTrail), "kanonkuglerne trækker en røgstribe efter sig")
	# Sjældne og episke fund
	var rares := {"rare": 0, "epic": 0}
	for i in 300:
		var drop := Game.roll_rare_drop("kingdom_treasury")
		if drop != "":
			rares[Catalog.ITEMS[drop]["rarity"]] += 1
	_check(rares["rare"] > 100 and rares["epic"] > 40 and Game.roll_rare_drop("crab", 0.0) in ["", "ancient_coin", "golden_compass", "silver_chalice", "pearl_necklace", "jade_idol", "cursed_skull", "kraken_eye", "sun_crown"], "sjældne og episke fund (%s)" % str(rares))
	# Kasser med varer fra hjemøen
	Homestead.storage.erase("wood")
	Homestead.storage.erase("fish")
	Homestead.add_to_storage("wood", 30)
	Homestead.add_to_storage("fish", 10)
	Game.cargo.clear()
	var packed := Homestead.pack_box("medium_box", ["wood", "fish"])
	_check(packed == 40 and Game.boxes.size() == 1 and Game.cargo_used() == 12, "pak varer i en kasse (%d)" % packed)
	var harbor2 := get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind == "trade")[0] as Harbor
	var g0 := Game.gold
	Game.sell_all_boxes(harbor2.harbor_name, harbor2.kind)
	_check(Game.boxes.is_empty() and Game.gold > g0, "sælg alle kasser")
	# Et skib går ned med et brag
	var victim := EnemyShip.new()
	victim.setup("merchant", "brig")
	victim.global_position = ship.global_position + Vector2(200, 0)
	Game.world_root.add_child(victim)
	await _frames(5)
	victim.take_damage(9999.0, ship.global_position)
	await _frames(20)
	await _shot("35_ship_explodes")
	# Overtag et eskorteskib selv: kaptajnen går i land
	Game.set_active_ship(Game.owned_ships.size() - 1)
	await _frames(5)
	_check(get_tree().get_nodes_in_group("escorts").size() == 1, "skifter du til et eskorteskib, går kaptajnen i land")
	Game.set_active_ship(0)
	await _frames(5)


## Kongeriger, store dyr, opgraderinger, fredeligt vand, døgn og vejr.
func _test_new_world(ship: PlayerShip) -> void:
	_check(get_tree().get_nodes_in_group("islands").size() >= 25, "mindst 25 øer")
	var huge := get_tree().get_nodes_in_group("islands").filter(func(i): return (i as Island).radius > 1000.0)
	_check(huge.size() == 6, "6 kæmpe fastlande (fandt %d)" % huge.size())
	var castles := get_tree().get_nodes_in_group("castles")
	_check(castles.size() == 3, "3 slotte med kongeriger")
	var beasts := get_tree().get_nodes_in_group("creatures").filter(func(c): return c is Beast)
	_check(beasts.size() >= 40, "store dyr og monstre på fastlandene (%d)" % beasts.size())

	# Opgraderinger: 100 trin
	var config := Game.active_ship()
	_check(Catalog.upgrade_max("hull") == 100, "100 trin i opgraderinger")
	var p0 := Catalog.upgrade_price("hull", 0)
	var p99 := Catalog.upgrade_price("hull", 99)
	print("     skrog: trin 1 koster %d, trin 100 koster %d" % [p0, p99])
	_check(p0 > 0 and p99 > p0 * 10 and Catalog.upgrade_price("hull", 100) == -1, "opgraderingspriser stiger og stopper ved 100")
	var hp_before: float = Game.ship_stats(config)["max_hp"]
	config["upgrades"]["hull"] = 50
	_check(Game.ship_stats(config)["max_hp"] > hp_before * 1.5, "50 trin skrog giver mere liv")
	config["upgrades"]["hull"] = 0

	# Fredeligt strandvand: pirat skyder ikke på dig i lagunen
	var harbor_isl: Island = null
	for i in get_tree().get_nodes_in_group("islands"):
		if (i as Island).radius < 300.0:
			harbor_isl = i
			break
	var lagoon_pos := harbor_isl.global_position + Vector2.RIGHT * harbor_isl.shore_radius(0.0) * 1.4
	_check(Game.is_safe_water(lagoon_pos), "lagunen er fredeligt vand")
	ship.place_at(lagoon_pos, 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var pirate := EnemyShip.new()
	pirate.setup("pirate", "sloop")
	pirate.global_position = lagoon_pos + Vector2(0, -250)
	Game.world_root.add_child(pirate)
	var hp_start: float = Game.active_ship()["hp"]
	await _frames(400)
	_check(Game.active_ship()["hp"] >= hp_start and pirate.state != "attack", "pirater angriber ikke i strandvandet (state=%s)" % pirate.state)
	await _shot("20_safe_water")
	pirate.queue_free()

	# Kongerige og duel
	var castle := castles[0] as Castle
	ship.place_at(castle.gate_position() + Vector2.from_angle(castle.rotation) * 260.0, castle.rotation + PI)
	Game.user_zoom = 0.6
	await _frames(60)
	await _shot("21_castle")
	Game.user_zoom = 1.0
	Game.crew = 30
	Game.gold = 1000
	var duel := main.get_node("DuelMenu")
	Game.duel_requested.emit(castle)
	await _frames(5)
	_check(duel.visible and get_tree().paused, "duel-menu åbner ved slottet")
	_press_first_button(duel, "Charge")
	await _frames(40)
	await _shot("22_duel_fight")
	await _frames(80)
	_press_first_button(duel, "Fight to the end")
	for i in 900:
		await get_tree().process_frame
		if duel.get("_over"):
			break
	await _frames(40)
	await _shot("23_duel_end")
	_check(duel.get("_over"), "duellen slutter")
	var gold_before := Game.gold
	if duel.get("_won"):
		_press_first_button(duel, "Take")
		_check(Game.gold > gold_before, "sejr giver skatkammerets guld")
	else:
		_press_first_button(duel, "Leave")
	await _frames(5)
	_check(not duel.visible and not get_tree().paused, "duel-menu lukker")
	_check(Game.kingdom_wait(castle.kingdom_index) > 0.0, "kongeriget skal hvile efter duellen")
	print("     duel: vundet=%s, besætning nu %d" % [duel.get("_won"), Game.crew])
	# Statistisk tjek af duel-chancen
	var c_small := preload("res://scenes/ui/duel_menu.gd").win_chance(5, 30, 1.2, {"roll": 1.3, "our_loss": 1.5, "their_loss": 1.25}, 1.0, 300)
	var c_big := preload("res://scenes/ui/duel_menu.gd").win_chance(40, 14, 1.05, {"roll": 1.3, "our_loss": 1.5, "their_loss": 1.25}, 1.0, 300)
	print("     duel-chance 5 mod 30: %d %%   40 mod 14: %d %%" % [roundi(c_small * 100), roundi(c_big * 100)])
	_check(c_small < 0.2 and c_big > 0.8, "duel-chancen følger antallet af folk")

	# Store dyr: kig på et af hver slags
	var shown := {}
	for b in beasts:
		var beast := b as Beast
		if shown.has(beast.kind):
			continue
		shown[beast.kind] = true
	_check(shown.size() == 4, "4 slags store dyr")
	var golem: Beast = null
	for b in beasts:
		if (b as Beast).kind == "golem":
			golem = b
			break
	if golem:
		ship.place_at(golem.home.global_position + Vector2.RIGHT * golem.home.shore_radius(0.0) * 1.1, PI)
		golem.take_damage(9999.0, golem.global_position)
		await _frames(30)
		_check(not is_instance_valid(golem) or golem.is_queued_for_deletion() or golem.get("_dead"), "golem kan dræbes og giver bytte")

	# Døgn og vejr
	var sky := main.get_node("Sky") as WorldSky
	ship.place_at(castle.gate_position() + Vector2.from_angle(castle.rotation) * 300.0, castle.rotation + PI)
	Game.world_time = 0.0
	sky.set_weather("clear")
	sky.snap_weather()
	await _frames(30)
	_check(Game.night > 0.8, "midnat er mørkt (night=%.2f)" % Game.night)
	var lit := get_tree().get_nodes_in_group("lanterns").filter(func(l): return (l as PointLight2D).enabled)
	_check(lit.size() > 3, "lanterner tændt om natten (%d)" % lit.size())
	await _shot("24_night")
	Game.world_time = 0.5
	sky.set_weather("storm")
	sky.snap_weather()
	await _frames(30)
	_check(Game.night < 0.1 and Game.wind.length() > 5.0, "storm om dagen med vind")
	await _shot("25_storm")
	sky.set_weather("fog")
	sky.snap_weather()
	await _frames(20)
	await _shot("26_fog")
	Game.world_time = 0.78
	sky.set_weather("rain")
	sky.snap_weather()
	await _frames(20)
	await _shot("27_dusk_rain")
	sky.set_weather("clear")
	sky.snap_weather()
	Game.world_time = 0.4
	var music := main.get_node("Music") as MusicDirector
	await _frames(70)
	_check(music.current != "", "musik spiller (%s)" % music.current)
