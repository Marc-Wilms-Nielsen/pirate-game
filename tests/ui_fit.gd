extends Node
## Checks that every menu tab fits inside the game's 640 x 360 layout (what every screen size is
## scaled from). A row of buttons that is too wide stretches its panel past the screen edge,
## and then part of the menu can't be reached on any screen, small or large.
## Prints one line per tab and exits with code 1 if anything sticks out.
## Run: godot res://tests/ui_fit.tscn

const SCREEN := Rect2(0, 0, 640, 360)

var main: Node
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.use_test_files() # never touch the real save or settings
	Game.delete_save()
	Game.reset()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(30)
	Game.gold = 1000000
	# The home island before you buy it (long description text)
	Homestead.claimed = false
	var home_menu := main.get_node("HomeMenu")
	home_menu.call("open")
	await _wait(4)
	_check_panels("home (not bought yet)", home_menu)
	get_viewport().get_texture().get_image().save_png("user://test_shots/fit_home_unclaimed.png")
	home_menu.call("close")
	await _wait(2)
	# Home island with everything unlocked, so the longest rows show up
	Homestead.claimed = true
	Homestead.ensure_layout()
	for id in Catalog.BUILDINGS:
		for n in 6:
			Homestead.upgrade_building(id)
	for i in 8:
		Homestead.hire_worker()
	Homestead.add_to_storage("food", 40)
	if not Homestead.plots.is_empty():
		Homestead.plots[0]["crop"] = "" # an empty field shows the widest row (a seed button per crop)
	for id in ["wood", "stone", "fish", "iron_ore", "wheat", "eggs"]:
		Homestead.add_to_storage(id, 25)
	home_menu.call("open")
	await _check_tabs("home", home_menu)
	home_menu.call("close")
	var harbor := get_tree().get_nodes_in_group("harbors").filter(func(h): return h.kind != "home")[0] as Harbor
	var harbor_menu := main.get_node("HarborMenu")
	harbor_menu.call("open", harbor)
	await _check_tabs("harbor", harbor_menu)
	harbor_menu.call("close")
	var pause := main.get_node("PauseMenu")
	for page in 4:
		pause.call("open", page)
		await _wait(4)
		_check_panels("pause page %d" % page, pause)
	pause.call("close")
	print("UI FIT DONE. Overflowing tabs: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check_tabs(menu_name: String, menu: Node) -> void:
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _wait(4)
		_check_panels("%s / %s" % [menu_name, tabs.get_tab_title(i)], menu)
		DirAccess.make_dir_recursive_absolute("user://test_shots")
		get_viewport().get_texture().get_image().save_png("user://test_shots/fit_%s_%d.png" % [menu_name, i])


func _check_panels(label: String, menu: Node) -> void:
	for p in menu.find_children("*", "PanelContainer", true, false):
		var panel := p as PanelContainer
		if not panel.is_visible_in_tree() or panel.get_parent() is PanelContainer:
			continue
		var r := panel.get_global_rect()
		var ok := SCREEN.encloses(r.grow(-0.5))
		if not ok:
			_failures += 1
		print("%-4s %-28s panel %4d x %3d at (%d, %d)%s" % ["OK" if ok else "OUT", label, int(r.size.x), int(r.size.y), int(r.position.x), int(r.position.y),
			"" if ok else "   <- sticks out by %d x %d" % [int(maxf(r.end.x - 640.0, 0.0)), int(maxf(r.end.y - 360.0, 0.0))]])
		break


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
