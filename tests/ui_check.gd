extends Node
## Skærmbilleder af HUD, butikker med ikoner, lastrum og kort med zoom (til visuelt tjek).
## Kør: godot res://tests/ui_check.tscn

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.delete_save()
	Game.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(30)
	for id in ["rum", "pearls", "jewels", "stolen_cargo", "wood", "iron_ore", "fish", "jaguar_pelt", "golem_core", "royal_seal"]:
		Game.add_item(id, 1)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	Game.give_loot("camp_chest", ship.global_position + Vector2(40, -20))
	await _wait(10)
	await _shot("u1_hud_loot")
	var harbor := get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind != "home")[0] as Harbor
	var menu := main.get_node("HarborMenu")
	menu.call("open", harbor)
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in [0, 1, 2, 3, 5]:
		tabs.current_tab = i
		await _wait(5)
		await _shot("u2_harbor_tab_%d" % i)
	menu.call("close")
	await _wait(5)
	var pause := main.get_node("PauseMenu")
	pause.call("open", 1)
	await _wait(5)
	await _shot("u3_cargo")
	pause.call("open", 0)
	await _wait(5)
	var map := pause.find_children("*", "MapView", true, false)[0] as MapView
	map.call("zoom_by", 1.25 * 1.25 * 1.25 * 1.25 * 1.25 * 1.25)
	map.set("_pan", ship.global_position)
	await _wait(5)
	await _shot("u4_map_zoom")
	pause.call("close")
	# Hjemøen: byggefelt, arbejdere og øen set udefra
	Homestead.claimed = true
	Homestead.ensure_layout()
	for id in ["workshop", "chickens", "lumber", "quarry", "fishery", "cottage", "cottage", "fields"]:
		Homestead.upgrade_building(id)
	for i in 5:
		Homestead.hire_worker()
	Homestead.add_to_storage("food", 40)
	Homestead.plant(0, "wheat")
	var home_menu := main.get_node("HomeMenu")
	home_menu.call("open")
	var htabs := home_menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in htabs.get_tab_count():
		htabs.current_tab = i
		await _wait(4)
		await _shot("u5_home_%s" % htabs.get_tab_title(i))
	home_menu.call("close")
	var home: Harbor = get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind == "home")[0]
	ship.place_at(home.get_parent().global_position + Vector2(0, 0), 0.0)
	Game.user_zoom = 0.5
	await _wait(90)
	await _shot("u6_home_island")
	Game.user_zoom = 1.0
	# NPC-skib med navn tæt på
	var e := EnemyShip.new()
	e.setup("pirate", "brig")
	e.global_position = ship.global_position + Vector2(160, 40)
	Game.world_root.add_child(e)
	ship.place_at(Vector2(-6000, 6000), 0.0)
	e.global_position = ship.global_position + Vector2(160, 40)
	await _wait(30)
	await _shot("u7_npc_name")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _wait(3)
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
