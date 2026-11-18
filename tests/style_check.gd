extends Node
## Customization: the Looks (ship) and Tailor (captain) editors in a harbor. Tries on options
## (the model changes, the ship doesn't), buys them (gold paid, unlocked, applied), checks that
## the ship and captain out in the world use them, that the captain stands at the helm, and that
## it all survives saving. Takes screenshots of both editors and the styled ship at sea.
## Run: godot res://tests/style_check.tscn   (exits with code 1 on any failure)

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
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(40)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var harbor := get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind == "trade")[0] as Harbor
	var menu := main.get_node("HarborMenu")
	menu.call("open", harbor)
	await _frames(3)
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer

	# --- Looks: the ship ---
	_open_tab(tabs, "Looks")
	await _frames(4)
	var editor := _editor(menu)
	_check(editor != null, "the Looks tab has the style editor")
	_check(Catalog.SHIP_STYLE_PARTS.size() >= 13, "%d ship parts to customize" % Catalog.SHIP_STYLE_PARTS.size())
	var config := Game.active_ship()
	# Try on ebony deck planks: the model shows them, the real ship doesn't (yet)
	var deck_part := _part(editor, "deck")
	var ebony := Catalog.style_option(Catalog.DECK_COLORS, "ebony")
	_select(editor, "deck")
	editor.call("_pick", ebony)
	await _frames(3)
	var model := editor.preview as ShipPreview
	_check(model.config.get("deck", "") == "ebony", "trying on: the model shows the ebony deck")
	_check(config.get("deck", "natural") != "ebony", "trying on doesn't change your ship")
	var gold := Game.gold
	editor.call("_buy_trying")
	await _frames(3)
	editor = _editor(menu)
	_check(Game.gold == gold - int(ebony["price"]), "buying costs %d gold" % int(ebony["price"]))
	_check(config.get("deck", "") == "ebony" and Game.unlocked_cosmetics.get("deck:ebony", false), "bought: your ship gets the ebony deck")
	_check(editor.current_part()["key"] == "deck", "the editor stays on the part you were on after buying")
	# Try something on, then switch part: the model goes back
	editor.call("_pick", Catalog.style_option(Catalog.DECK_COLORS, "whitewashed"))
	await _frames(2)
	_select(editor, "sail")
	await _frames(2)
	_check((editor.preview as ShipPreview).config.get("deck", "") == "ebony", "switching part puts the model back to what you own")
	# Buy a whole look
	for pair in [["sail", "crimson"], ["emblem", "skull"], ["emblem_color", "white"], ["hull", "navy"], ["stripe", "gold"],
			["rail", "gold"], ["cannon_color", "bronze"], ["flag", "gold"], ["lantern", "blue"], ["wake", "turquoise"],
			["deco_lanterns", "on"], ["deco_flag", "on"], ["deco_figurehead", "on"]]:
		editor = _editor(menu)
		_select(editor, pair[0])
		var part: Dictionary = editor.current_part()
		var opt := Catalog.style_option(editor.options_of(part), pair[1])
		editor.call("_pick", opt)
		if not editor.is_owned(part, opt):
			editor.call("_buy_trying")
		await _frames(2)
	editor = _editor(menu)
	_check(editor.value_of(_part(editor, "wake")) == "turquoise" and editor.value_of(_part(editor, "deco_lanterns")) == "on", "a whole new look is bought and applied")
	_select(editor, "emblem")
	await _frames(20)
	await _shot("st1_looks")

	# --- Tailor: the captain ---
	_open_tab(tabs, "Tailor")
	await _frames(4)
	var tailor := _editor(menu)
	_check(tailor != null and tailor.preview is CaptainPreview, "the Tailor tab has the editor with the captain's model")
	for pair in [["skin", "tan"], ["hair", "braids"], ["hair_color", "red"], ["beard", "braided"], ["beard_color", "red"],
			["eyepatch", "left"], ["earring", "gold"], ["coat_color", "navy"], ["coat_accent", "gold"], ["sash", "red"],
			["trousers", "white"], ["boots", "black"], ["hat_color", "black"]]:
		tailor = _editor(menu)
		_select(tailor, pair[0])
		var part: Dictionary = tailor.current_part()
		var opt := Catalog.style_option(part["options"], pair[1])
		tailor.call("_pick", opt)
		if not tailor.is_owned(part, opt):
			tailor.call("_buy_trying")
		await _frames(2)
	_check(Game.captain_look.get("beard", "") == "braided" and Game.captain_look.get("sash", "") == "red", "the captain's new look is bought and applied")
	_check(Game.unlocked_cosmetics.get("cap_beard:braided", false), "captain unlocks are kept apart from the ship's")
	_select(_editor(menu), "beard")
	await _frames(20)
	await _shot("st2_tailor")
	menu.call("close")
	await _frames(5)

	# --- Out in the world ---
	_check(ship.visual.style.get("deck") == ebony["color"], "the ship at sea has the ebony deck")
	_check(ship.visual.style.get("emblem", "") == "skull", "the ship at sea shows the skull on its sail")
	_check(ship.visual.show_captain and ship.visual.captain_aboard(), "the captain stands at the helm while sailing")
	var look := CaptainDrawer.current()
	_check(look["beard"] == "braided" and look["eyepatch"] == "left", "the captain is drawn with the new look")
	var lights := ship.visual.find_children("*", "PointLight2D", true, false)
	_check(not lights.is_empty() and (lights[0] as PointLight2D).color == Catalog.style_option(Catalog.LANTERN_COLORS, "blue")["color"], "the ship's lanterns shine blue")
	Game.user_zoom = 1.8
	Game.world_time = 0.5
	ship.place_at(_deep_spot(), -0.5)
	ship.sail_level = 2
	await _frames(150)
	await _shot("st3_ship_at_sea")

	# --- Saving ---
	Game.save_game()
	var saved_look := Game.captain_look.duplicate()
	var saved_deck: String = config["deck"]
	Game.captain_look = {}
	Game.load_game()
	_check(Game.captain_look == saved_look and Game.active_ship().get("deck", "") == saved_deck, "the ship's and the captain's looks survive saving")
	print("STYLE CHECK DONE. Failures: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _editor(menu: Node) -> StyleEditor:
	for e in menu.find_children("*", "StyleEditor", true, false):
		if (e as Control).is_visible_in_tree() and not e.is_queued_for_deletion():
			return e
	return null


func _open_tab(tabs: TabContainer, title: String) -> void:
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == title:
			tabs.current_tab = i


func _part(editor: StyleEditor, key: String) -> Dictionary:
	for p in editor.parts:
		if p["key"] == key:
			return p
	return {}


func _select(editor: StyleEditor, key: String) -> void:
	for i in editor.parts.size():
		if editor.parts[i]["key"] == key:
			editor.call("_show_part", i)


func _deep_spot() -> Vector2:
	for i in 400:
		var p := Vector2.from_angle(i * 2.4) * (2500.0 + i * 40.0)
		if Game.water_depth(p) >= 1.0 and Game.water_depth(p + Vector2(600, 0)) >= 1.0 and Game.water_depth(p - Vector2(600, 0)) >= 1.0:
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
	await _frames(2)
	DirAccess.make_dir_recursive_absolute("user://test_shots")
	get_viewport().get_texture().get_image().save_png("user://test_shots/%s.png" % shot_name)
