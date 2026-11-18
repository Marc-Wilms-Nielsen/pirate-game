extends CanvasLayer
## Hjemøens menu: køb øen, så og høst marker, byg og opgradér bygninger, lav ting i værkstedet
## og flyt varer mellem lastrum og lager. Åbnes når man lægger til ved hjemøens mole.

signal closed

var _root: Control
var _title: Label
var _purse: Label
var _tabs: TabContainer
var _pages: Dictionary = {}
var _produced_text := ""


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	Game.changed.connect(_refresh_if_open)
	Homestead.changed.connect(_refresh_if_open)


func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _process(_delta: float) -> void:
	# Afgrøderne vokser imens – opdater nedtællingen på markerne en gang i sekundet
	if visible and _tabs.get_current_tab_control().name == "Fields" and Engine.get_process_frames() % 60 == 0:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var produced := Homestead.update_production()
	_produced_text = ""
	if not produced.is_empty():
		var parts: Array[String] = []
		for id in produced:
			parts.append("%d %s" % [produced[id], Game.item_name(id)])
		_produced_text = "While you were away: " + ", ".join(PackedStringArray(parts))
	var report := Homestead.last_report
	if float(report.get("eaten", 0.0)) >= 1.0:
		_produced_text += ("\n" if _produced_text != "" else "") + "Your workers ate %d food." % int(report["eaten"])
	if float(report.get("hungry_hours", 0.0)) > 0.05:
		_produced_text += "\nThe workers went hungry for about %.1f hours – production slowed down. Store more food!" % float(report["hungry_hours"])
	visible = true
	get_tree().paused = true
	_tabs.current_tab = 0
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	Game.save_game()
	closed.emit()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 14)
	panel.size = Vector2(592, 332)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = UiTheme.label("Home Island", 14, UiTheme.ACCENT)
	titles.add_child(_title)
	_purse = UiTheme.label("", 9, UiTheme.MUTED)
	titles.add_child(_purse)
	header.add_child(UiTheme.button("Set sail (Esc)", close))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	for page_name in ["Home", "Build", "Fields", "Workers", "Workshop", "Storage"]:
		var content := VBoxContainer.new()
		var scroll := UiTheme.scroll(content)
		scroll.name = page_name
		_tabs.add_child(scroll)
		_pages[page_name] = content
	_tabs.tab_changed.connect(func(_t: int) -> void: _refresh())


func _refresh() -> void:
	_title.text = "Your home" if Homestead.claimed else "Deserted island"
	_purse.text = "Gold: %d    Cargo: %d/%d    Storage: %d items" % [Game.gold, Game.cargo_used(), Game.cargo_capacity(),
		Homestead.storage.values().reduce(func(a, b): return a + b, 0)]
	var page: String = _tabs.get_current_tab_control().name
	var box: VBoxContainer = _pages[page]
	UiTheme.clear(box)
	if not Homestead.claimed:
		_build_claim(box)
		return
	match page:
		"Home": _build_overview(box)
		"Fields": _build_fields(box)
		"Build": _build_build(box)
		"Workers": _build_workers(box)
		"Workshop": _build_workshop(box)
		"Storage": _build_storage(box)


func _build_claim(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("A deserted island with fertile soil and a good anchorage.", 11, UiTheme.TEXT))
	box.add_child(UiTheme.label("Buy the island and build your own home: grow fields, build a chicken coop, fishing hut, lumber camp and quarry,", 9, UiTheme.MUTED))
	box.add_child(UiTheme.label("and craft cannonballs, grenades, food and gear in the workshop. Everything keeps producing while the game is closed.", 9, UiTheme.MUTED))
	box.add_child(UiTheme.button("Buy the island (%d gold)" % Catalog.HOME_PRICE, func() -> void:
		if Game.spend(Catalog.HOME_PRICE):
			Homestead.claimed = true
			Homestead.last_update = Time.get_unix_time_from_system()
			Homestead.ensure_layout()
			Game.notify("The island is yours! Welcome home, captain.", UiTheme.GOOD)
			Sfx.play("coin")
			Homestead.changed.emit(), Game.gold >= Catalog.HOME_PRICE))


func _build_overview(box: VBoxContainer) -> void:
	if _produced_text != "":
		box.add_child(UiTheme.label(_produced_text, 10, UiTheme.GOOD))
	var ripe := 0
	var growing := 0
	for plot in Homestead.plots:
		if plot["crop"] != "":
			if Homestead.growth(plot) >= 1.0:
				ripe += 1
			else:
				growing += 1
	box.add_child(UiTheme.label("Fields: %d ready to harvest, %d growing, %d free" % [ripe, growing, Homestead.plots.size() - ripe - growing]))
	var mats := 0
	for id in Game.cargo:
		if Catalog.ITEMS[id]["category"] == "material":
			mats += Game.cargo[id]
	box.add_child(UiTheme.button("Move all materials from the cargo hold to storage (%d)" % mats, func() -> void:
		var moved := Homestead.store_all_materials()
		Game.notify("%d materials moved to storage" % moved, UiTheme.GOOD), mats > 0))
	if ripe > 0:
		box.add_child(UiTheme.button("Harvest all ripe fields", func() -> void:
			for i in Homestead.plots.size():
				Homestead.harvest(i)))
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Production per hour", 10, UiTheme.ACCENT))
	var any := false
	for id in Catalog.BUILDINGS:
		var level: int = Homestead.buildings.get(id, 0)
		var produce: Dictionary = Catalog.BUILDINGS[id]["produce"]
		if level > 0 and not produce.is_empty():
			any = true
			var parts: Array[String] = []
			var crew := Homestead.working(id)
			for item in produce:
				parts.append("%.0f %s" % [float(produce[item]) * crew, Game.item_name(item)])
			var row := HBoxContainer.new()
			box.add_child(row)
			row.add_child(Icons.make(id, 14.0))
			row.add_child(UiTheme.label("%s (level %d, %d/%d workers): %s" % [Catalog.BUILDINGS[id]["name"], level, crew, level, ", ".join(PackedStringArray(parts))], 9,
				UiTheme.TEXT if crew > 0 else UiTheme.BAD))
	if not any:
		box.add_child(UiTheme.label("  No buildings yet – see the Build tab.", 9, UiTheme.MUTED))
	box.add_child(UiTheme.label("Workers: %d / %d beds    Food in storage: %d (lasts %s)" % [Homestead.workers, Homestead.beds(),
		int(Homestead.storage.get("food", 0)), _hours_text(Homestead.food_hours())], 9, UiTheme.ACCENT))
	box.add_child(UiTheme.label("Production goes to storage, max %d hours at a time – drop by regularly." % int(Catalog.BUILDING_CAP_HOURS), 8, UiTheme.MUTED))


func _build_fields(box: VBoxContainer) -> void:
	for i in Homestead.plots.size():
		var plot: Dictionary = Homestead.plots[i]
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := UiTheme.label("Field %d" % (i + 1))
		l.custom_minimum_size = Vector2(50, 0)
		row.add_child(l)
		if plot["crop"] == "":
			for crop_id in Catalog.CROPS:
				var crop: Dictionary = Catalog.CROPS[crop_id]
				row.add_child(UiTheme.button("%s (%d g, %d min)" % [crop["name"], crop["seed_price"], int(crop["grow"])], func() -> void:
					Homestead.plant(i, crop_id), Game.gold >= crop["seed_price"]))
		else:
			var crop: Dictionary = Catalog.CROPS[plot["crop"]]
			var g := Homestead.growth(plot)
			var status := UiTheme.label("")
			status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(status)
			if g >= 1.0:
				status.text = "%s – ready to harvest!" % crop["name"]
				status.add_theme_color_override("font_color", UiTheme.GOOD)
				row.add_child(UiTheme.button("Harvest (%d %s)" % [crop["yield"][1], Game.item_name(crop["yield"][0])], func() -> void: Homestead.harvest(i)))
			else:
				var left := int(Homestead.seconds_left(plot))
				status.text = "%s – %d %%  (%d:%02d left)" % [crop["name"], int(g * 100.0), floori(left / 60.0), left % 60]
	box.add_child(UiTheme.label("Crops grow in real time – even while the game is closed. The harvest goes to storage.", 8, UiTheme.MUTED))


# --- Byggefelt ------------------------------------------------------------------

var _placing: String = "" ## bygning der er ved at blive placeret
var _moving: String = "" ## felt ("x,y") hvis indhold er ved at blive flyttet
var _hint: Label


func _build_build(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var grid := GridView.new()
	grid.menu = self
	grid.custom_minimum_size = Vector2(250, 220)
	row.add_child(grid)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	_hint = UiTheme.label(_hint_text(), 9, UiTheme.ACCENT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(200, 0)
	side.add_child(_hint)
	for id in Catalog.BUILDINGS:
		var b: Dictionary = Catalog.BUILDINGS[id]
		var level: int = Homestead.buildings.get(id, 0)
		var cost := Homestead.building_cost(id)
		var r := HBoxContainer.new()
		side.add_child(r)
		r.add_child(Icons.make(id, 16.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(info)
		info.add_child(UiTheme.label("%s – level %d / %d" % [b["name"], level, b["costs"].size()], 9))
		var desc := UiTheme.label(_building_desc(id), 7, UiTheme.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(150, 0)
		info.add_child(desc)
		if level == 0 and Homestead.placeable(id):
			r.add_child(UiTheme.button("Place (%d)" % cost, func() -> void:
				_placing = id
				_moving = ""
				_refresh(), cost >= 0 and Game.gold >= cost))
		else:
			r.add_child(UiTheme.button("Max" if cost < 0 else ("Build (%d)" % cost if level == 0 else "Upgrade (%d)" % cost),
				func() -> void: Homestead.upgrade_building(id), cost >= 0 and Game.gold >= cost))


func _building_desc(id: String) -> String:
	var b: Dictionary = Catalog.BUILDINGS[id]
	var desc: String = b["desc"]
	if not b["produce"].is_empty():
		var parts: Array[String] = []
		for item in b["produce"]:
			parts.append("%.0f %s/hour per worker" % [float(b["produce"][item]), Game.item_name(item)])
		desc += " · " + ", ".join(PackedStringArray(parts)) + " · 1 worker per level"
	return desc


func _hint_text() -> String:
	if _placing != "":
		return "Click a free square to place the %s. Right-click to cancel." % String(Catalog.BUILDINGS[_placing]["name"]).to_lower()
	if _moving != "":
		return "Click a free square to move it there. Right-click to cancel."
	return "Click a building or field on the map to move it. New buildings: press Place, then pick a square."


## Klik på kortet over byggefeltet.
func grid_clicked(cell: Vector2i, right: bool) -> void:
	if right:
		_placing = ""
		_moving = ""
	elif _placing != "":
		if Homestead.build_at(_placing, cell):
			_placing = ""
	elif _moving != "":
		if Homestead.move(_moving, cell):
			_moving = ""
	elif Homestead.layout.has(Homestead.key(cell)):
		_moving = Homestead.key(cell)
	_refresh()


# --- Arbejdere ------------------------------------------------------------------

func _build_workers(box: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(Icons.make("crew", 18.0))
	var l := UiTheme.label("Workers: %d / %d beds   ·   %d free" % [Homestead.workers, Homestead.beds(), Homestead.free_workers()], 11, UiTheme.ACCENT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	top.add_child(UiTheme.button("Hire worker (%d)" % Catalog.WORKER_PRICE, func() -> void: Homestead.hire_worker(),
		Homestead.workers < Homestead.beds() and Game.gold >= Catalog.WORKER_PRICE))
	top.add_child(UiTheme.button("Dismiss", func() -> void: Homestead.dismiss_worker(), Homestead.workers > 0))
	box.add_child(UiTheme.label("The house has %d beds. Each workers' cottage level adds %d more (see Build)." % [Catalog.HOUSE_BEDS, Catalog.BEDS_PER_COTTAGE], 8, UiTheme.MUTED))
	# Mad
	box.add_child(HSeparator.new())
	var food := int(Homestead.storage.get("food", 0))
	var food_row := HBoxContainer.new()
	box.add_child(food_row)
	food_row.add_child(Icons.make("food", 18.0))
	var fl := UiTheme.label("Food in storage: %d   ·   workers eat %.0f per hour   ·   lasts %s" % [food,
		Homestead.workers * Catalog.WORKER_FOOD_PER_HOUR, _hours_text(Homestead.food_hours())], 10,
		UiTheme.BAD if Homestead.workers > 0 and Homestead.food_hours() < 3.0 else UiTheme.TEXT)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_row.add_child(fl)
	for amount in [50, 200]:
		food_row.add_child(UiTheme.button("Bring %d from ship" % amount, func() -> void: Homestead.store_food(amount), Game.food > 0))
	box.add_child(UiTheme.label("Hungry workers work slower. The chicken coop makes food too (if someone works there).", 8, UiTheme.MUTED))
	# Fordeling
	box.add_child(HSeparator.new())
	var any := false
	for id in Catalog.BUILDINGS:
		var b: Dictionary = Catalog.BUILDINGS[id]
		var level: int = Homestead.buildings.get(id, 0)
		if b["produce"].is_empty() or level == 0:
			continue
		any = true
		var r := HBoxContainer.new()
		box.add_child(r)
		r.add_child(Icons.make(id, 16.0))
		var n := int(Homestead.assigned.get(id, 0))
		var parts: Array[String] = []
		for item in b["produce"]:
			parts.append("%.0f %s/h" % [float(b["produce"][item]) * Homestead.working(id), Game.item_name(item)])
		var bl := UiTheme.label("%s: %d / %d workers  →  %s" % [b["name"], n, level, ", ".join(PackedStringArray(parts))], 10,
			UiTheme.GOOD if n >= level else UiTheme.TEXT)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(bl)
		r.add_child(UiTheme.button(" – ", func() -> void: Homestead.assign(id, -1), n > 0))
		r.add_child(UiTheme.button(" + ", func() -> void: Homestead.assign(id, 1), n < level and Homestead.free_workers() > 0))
	if not any:
		box.add_child(UiTheme.label("Build a chicken coop, fishing hut, lumber camp or quarry first (Build tab).", 9, UiTheme.MUTED))


func _hours_text(h: float) -> String:
	if h == INF:
		return "–"
	if h >= 48.0:
		return "%d days" % floori(h / 24.0)
	return "%.1f hours" % h


func _build_workshop(box: VBoxContainer) -> void:
	var wl: int = Homestead.buildings.get("workshop", 0)
	if wl == 0:
		box.add_child(UiTheme.label("Build a workshop under Buildings to craft things.", 10, UiTheme.MUTED))
	box.add_child(UiTheme.label("Materials are taken from storage first, then from the cargo hold.", 8, UiTheme.MUTED))
	for recipe in Catalog.RECIPES:
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(Icons.make(recipe["gear"] if recipe.has("gear") else recipe["output"][0], 18.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var out_text: String
		if recipe.has("gear"):
			out_text = "%s (gear)" % Catalog.GEAR[recipe["gear"]]["name"]
		else:
			out_text = "%d %s" % [recipe["output"][1], Game.item_name(recipe["output"][0])]
		var locked: bool = wl < int(recipe["level"])
		info.add_child(UiTheme.label("%s → %s" % [recipe["name"], out_text], 10, UiTheme.MUTED if locked else UiTheme.TEXT))
		var parts: Array[String] = []
		for id in recipe["inputs"]:
			parts.append("%s %d/%d" % [Game.item_name(id), Homestead.total(id), recipe["inputs"][id]])
		var need := ", ".join(PackedStringArray(parts))
		if locked:
			need = "Requires workshop level %d · %s" % [recipe["level"], need]
		info.add_child(UiTheme.label(need, 8, UiTheme.MUTED))
		var owned_gear: bool = recipe.has("gear") and Game.owned_gear.get(recipe["gear"], false)
		row.add_child(UiTheme.button("Owned" if owned_gear else "Craft", func() -> void: Homestead.craft(recipe), Homestead.can_craft(recipe)))


var _marked: Dictionary = {} ## vare-id -> true: markeret til at blive pakket i kasser


func _build_storage(box: VBoxContainer) -> void:
	# Kasser: pak de markerede varer, så de fylder mindre og kan sælges samlet
	var packing := HBoxContainer.new()
	box.add_child(packing)
	var marked: Array = _marked.keys().filter(func(id: String) -> bool: return Homestead.storage.has(id))
	var marked_count := 0
	for id in marked:
		marked_count += int(Homestead.storage[id])
	packing.add_child(UiTheme.label("Pack %d marked:" % marked_count, 9, UiTheme.ACCENT))
	for box_type in Catalog.BOXES:
		var info: Dictionary = Catalog.BOXES[box_type]
		var b := UiTheme.button("%s (%d g)" % [info["name"], info["price"]], func() -> void:
			var n := Homestead.pack_box(box_type, marked)
			if n > 0:
				Game.log_line("Packed %d goods into a %s" % [n, String(info["name"]).to_lower()], UiTheme.GOOD, box_type), marked_count > 0 and Game.gold >= int(info["price"]))
		b.tooltip_text = "Holds %d goods, takes %d cargo space" % [info["capacity"], info["weight"]]
		packing.add_child(b)
	var box_row := HBoxContainer.new()
	box.add_child(box_row)
	var bl := UiTheme.label("Boxes on your ship: %d" % Game.boxes.size(), 9, UiTheme.MUTED)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_row.add_child(bl)
	box_row.add_child(UiTheme.button("Mark all", func() -> void:
		for id in Homestead.storage:
			_marked[id] = true
		_refresh(), not Homestead.storage.is_empty()))
	box_row.add_child(UiTheme.button("Unpack boxes here", func() -> void: Homestead.unpack_boxes(), not Game.boxes.is_empty()))
	box.add_child(HSeparator.new())
	if Homestead.storage.is_empty():
		box.add_child(UiTheme.label("Storage is empty. Harvest fields, build producing buildings or store materials.", 9, UiTheme.MUTED))
	for id in Homestead.storage.keys():
		var n: int = Homestead.storage[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var check := CheckBox.new()
		check.button_pressed = _marked.get(id, false)
		check.focus_mode = Control.FOCUS_NONE
		check.tooltip_text = "Mark for packing into a box"
		check.toggled.connect(func(on: bool) -> void:
			if on:
				_marked[id] = true
			else:
				_marked.erase(id)
			_refresh())
		row.add_child(check)
		var l := UiTheme.label("%d x %s" % [n, Game.item_name(id)])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(Icons.make(id))
		row.add_child(l)
		for amount in [1, 10]:
			row.add_child(UiTheme.button("Take %d" % amount, func() -> void: _take(id, amount)))
		row.add_child(UiTheme.button("Take all", func() -> void: _take(id, n)))
	box.add_child(UiTheme.label("Take goods into the cargo hold to sell them in a harbor.", 8, UiTheme.MUTED))


func _take(id: String, amount: int) -> void:
	if id == "food" or id == "cannonball" or id == "shot":
		Game.add_item(id, Homestead.take_from_storage(id, amount))
		return
	var weight: int = Catalog.ITEMS[id]["weight"] if Catalog.ITEMS.has(id) else 1
	var room := floori(float(Game.cargo_capacity() - Game.cargo_used()) / weight)
	var taken := Homestead.take_from_storage(id, mini(amount, room))
	if taken <= 0:
		Game.notify("Not enough room in the cargo hold", UiTheme.BAD)
		return
	Game.add_item(id, taken)


## Kort over hjemøens byggefelt: øens omrids, felterne og hvad der står på dem.
class GridView extends Control:
	var menu: Node
	var _hover := Vector2i(-1, -1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _island() -> Island:
		for h in get_tree().get_nodes_in_group("harbors"):
			if (h as Harbor).kind == "home":
				return (h as Node).get_parent() as Island
		return null

	func _cell_px() -> float:
		var g := Catalog.HOME_GRID
		return minf(size.x / g.x, size.y / g.y)

	func _origin() -> Vector2:
		var g := Vector2(Catalog.HOME_GRID)
		return (size - g * _cell_px()) * 0.5

	func _cell_at(pos: Vector2) -> Vector2i:
		var c := (pos - _origin()) / _cell_px()
		return Vector2i(floori(c.x), floori(c.y))

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion:
			_hover = _cell_at(motion.position)
			queue_redraw()
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			menu.call("grid_clicked", _cell_at(mb.position), mb.button_index == MOUSE_BUTTON_RIGHT)
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.42, 0.55))
		var cp := _cell_px()
		var o := _origin()
		var world_scale := cp / Catalog.HOME_CELL
		var center := o + Vector2(Catalog.HOME_GRID) * cp * 0.5
		var island := _island()
		if island:
			var pts := PackedVector2Array()
			for i in 64:
				var a := TAU * i / 64.0
				pts.append(center + Vector2.from_angle(a) * island.shore_radius(a) * world_scale)
			draw_colored_polygon(pts, Color(0.94, 0.85, 0.62))
			var grass := PackedVector2Array()
			for p in pts:
				grass.append(center + (p - center) * 0.8)
			draw_colored_polygon(grass, Color(0.45, 0.66, 0.35))
			var hp := center + Vector2.from_angle(island.harbor_angle) * island.shore_radius(island.harbor_angle) * 0.86 * world_scale
			draw_line(hp, hp + Vector2.from_angle(island.harbor_angle) * 30.0, Color(0.5, 0.35, 0.2), 4.0)
			draw_string(ThemeDB.fallback_font, hp + Vector2(-12, -6), "Pier", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.8))
		var placing: bool = menu.get("_placing") != "" or menu.get("_moving") != ""
		for c in Homestead.valid_cells:
			var r := Rect2(o + Vector2(c) * cp, Vector2(cp, cp)).grow(-1.0)
			var free := Homestead.is_free(c)
			var col := Color(1, 1, 1, 0.08)
			if placing and free:
				col = Color(0.5, 1.0, 0.6, 0.22)
			if c == _hover:
				col = Color(1, 1, 0.6, 0.35) if (free or not placing) else Color(1, 0.4, 0.3, 0.3)
			draw_rect(r, col)
		for k in Homestead.layout:
			var item: Dictionary = Homestead.layout[k]
			var c := Homestead.cell_of(k)
			var r := Rect2(o + Vector2(c) * cp, Vector2(cp, cp)).grow(-1.5)
			var id: String = "house" if item["type"] == "house" else ("field" if item["type"] == "field" else item["id"])
			var selected: bool = menu.get("_moving") == k
			draw_rect(r, Color(1, 0.85, 0.3, 0.6) if selected else Color(0, 0, 0, 0.25))
			Icons.draw(self, id, r.get_center(), cp * 0.8)
