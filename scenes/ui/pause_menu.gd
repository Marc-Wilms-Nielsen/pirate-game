extends CanvasLayer
## ESC-menu (M åbner direkte på kortet). Pauser spillet.
## Faner: Kort, Last, Skib, Udstyr, Indstillinger, Styring.

var harbor_menu_open := false ## sættes af main, så ESC lukker havnemenuen i stedet

var _root: Control
var _tabs: TabContainer
var _cargo_box: VBoxContainer
var _ship_box: VBoxContainer
var _settings_box: VBoxContainer
var _gear_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if harbor_menu_open:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle(0 if not visible else -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		toggle(0)
		get_viewport().set_input_as_handled()


func toggle(tab: int) -> void:
	if visible and (tab == -1 or _tabs.current_tab == tab):
		close()
	else:
		open(maxi(tab, 0))


func open(tab := 0) -> void:
	visible = true
	get_tree().paused = true
	_tabs.current_tab = tab
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(30, 18)
	panel.size = Vector2(580, 324)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiTheme.label("Pause", 14, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.button("Resume (Esc)", close))
	var new_game := UiTheme.button("New voyage", func() -> void: pass)
	new_game.pressed.connect(func() -> void:
		if new_game.text == "New voyage":
			new_game.text = "Sure? Everything is deleted"
			return
		Game.delete_save()
		Game.reset()
		Homestead.reset()
		Quests.reset()
		get_tree().paused = false
		get_tree().reload_current_scene())
	header.add_child(new_game)
	header.add_child(UiTheme.button("Save and quit", func() -> void:
		Game.save_game()
		get_tree().quit()))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)

	var map := MapView.new()
	map.name = "Map"
	_tabs.add_child(map)

	_cargo_box = VBoxContainer.new()
	var cargo_scroll := UiTheme.scroll(_cargo_box)
	cargo_scroll.name = "Cargo"
	_tabs.add_child(cargo_scroll)

	_ship_box = VBoxContainer.new()
	var ship_scroll := UiTheme.scroll(_ship_box)
	ship_scroll.name = "Ship"
	_tabs.add_child(ship_scroll)

	_gear_box = VBoxContainer.new()
	var gear_scroll := UiTheme.scroll(_gear_box)
	gear_scroll.name = "Gear"
	_tabs.add_child(gear_scroll)
	Game.changed.connect(func() -> void:
		if visible and _tabs.get_current_tab_control() == gear_scroll:
			GearList.build(_gear_box, false))

	_settings_box = VBoxContainer.new()
	var settings_scroll := UiTheme.scroll(_settings_box)
	settings_scroll.name = "Settings"
	_tabs.add_child(settings_scroll)

	var help := VBoxContainer.new()
	help.name = "Controls"
	for line in [
		"At sea",
		"  W / S – raise and lower sails (furled, half, full)",
		"  A / D – turn the helm",
		"  Q / E – fire cannons to port / starboard",
		"  Space – drop or raise the anchor (steer while it drops for an anchor turn)",
		"  F – board a ship alongside, dock or jump overboard",
		"  Mouse wheel or + / – – zoom in and out",
		"On foot",
		"  WASD – walk or swim",
		"  Space – melee attack",
		"  1-8 – pick weapon (melee, pistol, blunderbuss, musket, 4 kinds of grenades)",
		"  Left-click – use the selected weapon toward the mouse (shoot / throw)",
		"  F – open chests, chop trees, mine rocks, fish from the beach or go aboard",
		"  R (at sea) – use a repair kit",
		"Always",
		"  Esc – menu    M – map    L – log",
	]:
		var is_header: bool = not line.begins_with(" ")
		help.add_child(UiTheme.label(line, 10 if is_header else 9, UiTheme.ACCENT if is_header else UiTheme.TEXT))
	_tabs.add_child(help)
	_tabs.tab_changed.connect(func(_t: int) -> void: _refresh())


func _refresh() -> void:
	_build_settings()
	GearList.build(_gear_box, false)
	UiTheme.clear(_cargo_box)
	_cargo_box.add_child(Icons.labeled("gold", "Gold: %d" % Game.gold, 11, UiTheme.ACCENT, 16.0))
	var supplies := HBoxContainer.new()
	_cargo_box.add_child(supplies)
	for entry in [["cannonball", "Cannonballs: %d" % Game.cannonballs], ["food", "Food: %d" % Game.food], ["shot", "Powder and shot: %d" % Game.shot], ["repair_kit", "Repair kits: %d" % Game.repair_kits]]:
		supplies.add_child(Icons.labeled(entry[0], entry[1]))
	_cargo_box.add_child(Icons.labeled("cargo", "Cargo: %d / %d" % [Game.cargo_used(), Game.cargo_capacity()]))
	for b in Game.boxes:
		_cargo_box.add_child(Icons.labeled(b["type"], "%s with %d goods" % [Catalog.BOXES[b["type"]]["name"], Game.box_item_count(b)]))
	if Game.cargo.is_empty():
		_cargo_box.add_child(UiTheme.label("The cargo hold is empty. Find chests, flotsam and merchant ships.", 9, UiTheme.MUTED))
	for id in Game.cargo:
		var item: Dictionary = Catalog.ITEMS[id]
		var rarity: String = item.get("rarity", "")
		var tag := "  (stolen)" if item["category"] == "stolen" else ("  (%s)" % rarity if rarity != "" else "")
		_cargo_box.add_child(Icons.labeled(id, "%d x %s%s" % [Game.cargo[id], item["name"], tag], 10,
			UiTheme.BAD if item["category"] == "stolen" else Catalog.RARITY_COLORS.get(rarity, UiTheme.TEXT)))

	UiTheme.clear(_ship_box)
	var config := Game.active_ship()
	var stats := Game.ship_stats(config)
	_ship_box.add_child(UiTheme.label("%s (%s)" % [config["name"], Catalog.SHIPS[config["type"]]["name"]], 11, UiTheme.ACCENT))
	for line in [
		"Hull: %d / %d" % [int(config["hp"]), int(stats["max_hp"])],
		"Speed: %.1f knots" % (stats["speed"] / 10.0),
		"Armor: %d %%" % int(stats["armor"] * 100.0),
		"Cannons: %d per side (max %d)" % [stats["cannons"], stats["max_cannons"]],
		"Damage: %d    Range: %d    Reload: %.1f s" % [int(stats["damage"]), int(stats["range"]), stats["reload"]],
		"Cargo: %d" % int(stats["cargo"]),
		"Crew: %d / %d" % [Game.crew, stats["max_crew"]],
	]:
		_ship_box.add_child(UiTheme.label(line))
	_ship_box.add_child(UiTheme.label("Upgrades and new ships are bought at a harbor's shipyard.", 9, UiTheme.MUTED))
	_ship_box.add_child(UiTheme.label("Your ships: " + ", ".join(PackedStringArray(Game.owned_ships.map(func(c: Dictionary) -> String: return c["name"]))), 9, UiTheme.MUTED))


# --- Indstillinger --------------------------------------------------------------

func _build_settings() -> void:
	UiTheme.clear(_settings_box)
	_settings_box.add_child(UiTheme.label("Sound", 11, UiTheme.ACCENT))
	_slider_row("Master volume", "master_volume")
	_slider_row("Sea, wind and gulls", "ambience_volume")
	_slider_row("Effects (cannons, coins ...)", "sfx_volume")
	_slider_row("Music", "music_volume")
	_settings_box.add_child(HSeparator.new())
	_settings_box.add_child(UiTheme.label("Graphics", 11, UiTheme.ACCENT))
	_option_row("Display", "fullscreen", ["Windowed", "Fullscreen"], [false, true])
	_option_row("V-Sync (prevents tearing)", "vsync", ["Off", "On"], [false, true])
	_option_row("Max frames per second", "max_fps", ["30", "60", "120", "144", "Unlimited"], Settings.FPS_OPTIONS)
	_option_row("Water quality", "water_quality", ["Low (fastest)", "Medium", "High"], [0, 1, 2])
	_option_row("Water resolution", "render_scale", ["50% (fastest)", "75%", "100% (sharpest)"], Settings.RENDER_SCALES)
	_option_row("Wakes and gun smoke", "effects", ["Off", "On"], [false, true])
	_option_row("Show FPS counter", "show_fps", ["No", "Yes"], [false, true])
	_settings_box.add_child(UiTheme.label("Is the game stuttering? Lower the water resolution or quality and turn on the FPS counter.", 9, UiTheme.MUTED))
	_settings_box.add_child(UiTheme.button("Reset to defaults", func() -> void:
		Settings.reset_to_defaults()
		_build_settings()))


func _slider_row(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	_settings_box.add_child(row)
	var l := UiTheme.label(title)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(float(Settings.get(key)) * 100.0)
	slider.custom_minimum_size = Vector2(200, 16)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var value_label := UiTheme.label("%d %%" % int(slider.value))
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d %%" % int(v)
		Settings.set_value(key, v / 100.0))


func _option_row(title: String, key: String, labels: Array, values: Array) -> void:
	var row := HBoxContainer.new()
	_settings_box.add_child(row)
	var l := UiTheme.label(title)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	for i in labels.size():
		option.add_item(labels[i], i)
	option.selected = maxi(values.find(Settings.get(key)), 0)
	row.add_child(option)
	option.item_selected.connect(func(index: int) -> void:
		Settings.set_value(key, values[index]))
